# syntax=docker/dockerfile:1

# Multi-stage build for a Phoenix + Inertia (React, SSR) release.
#
# Versions are pinned via ARGs so they're easy to bump and match
# `mise.toml` (the dev/CI toolchain). Keep BUILDER_IMAGE, RUNNER_IMAGE,
# and the Node image on the same Debian release (trixie) so the Node
# binary copied into the runner is ABI-compatible.
#
# The runner needs a Node binary because Inertia server-side rendering
# runs `priv/ssr.js` in a Node worker pool. We copy just the `node`
# binary from the official Node image — no npm/build toolchain ships
# in the final image.

ARG ELIXIR_VERSION=1.19.5
# Dev/CI run Erlang 28.5 (via mise); hexpm has no 28.5 image yet, so the
# release builds on 28.4 — a single OTP patch behind, ABI-compatible.
ARG OTP_VERSION=28.4
ARG DEBIAN_VERSION=trixie-20260518-slim
ARG NODE_VERSION=26.2.0

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# =============================================================================
# Build stage
# =============================================================================
FROM ${BUILDER_IMAGE} AS builder

# Build deps + Node (for the asset/SSR build).
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
  && curl -fsSL https://deb.nodesource.com/setup_26.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex + rebar.
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Install mix deps first (better layer caching).
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Compile-time config — copied before the rest so a code change doesn't
# bust the dep-compilation cache.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# JS deps (cached on the lockfile).
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix assets ci

COPY priv priv
COPY lib lib
COPY assets assets

# Build browser bundle + SSR bundle + digest, then compile the app.
RUN mix assets.deploy
RUN mix compile

# Runtime config + release assembly.
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# =============================================================================
# Runtime stage
# =============================================================================
FROM ${RUNNER_IMAGE} AS runner

# Runtime libs + tini (PID 1 / signal handling). No build toolchain.
# `--no-install-recommends` keeps suggested extras (gpm, l10n data) out.
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates tini \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# UTF-8 locale. `C.UTF-8` ships with glibc, so we skip the `locales`
# package and `locale-gen` entirely. Elixir/OTP only need *a* UTF-8
# locale — string handling uses Elixir's own Unicode tables, not libc.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Node binary for Inertia SSR (`priv/ssr.js`). Same Debian base as the
# builder, so the binary's shared-lib deps resolve.
COPY --from=node:26-trixie-slim /usr/local/bin/node /usr/local/bin/node

WORKDIR /app

# Run as a non-root user.
RUN useradd --create-home --uid 1000 app
USER app

ENV MIX_ENV="prod"
# `bin/server` (from rel/overlays) sets PHX_SERVER=true and boots the
# endpoint. PORT is read in runtime.exs; default matches EXPOSE.
ENV PORT=4000
EXPOSE 4000

COPY --from=builder --chown=app:app /app/_build/prod/rel/web_template ./

# Liveness probe against the public /health endpoint. Reuses the Node
# binary that's already here for SSR — no curl/wget needed. Node 26
# ships a global fetch.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://localhost:'+(process.env.PORT||4000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/bin/server"]
