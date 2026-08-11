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

ARG ELIXIR_VERSION=1.20.0
ARG OTP_VERSION=29.0.1
ARG DEBIAN_VERSION=trixie-20260518-slim
ARG NODE_VERSION=26.2.0

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# Alias the pinned Node image as a build stage. BuildKit forbids variable
# expansion in `COPY --from=<image>`, but `FROM <image> AS <name>` supports
# it — so this is the canonical way to actually pin NODE_VERSION. Without
# the stage alias, `COPY --from=node:26-trixie-slim` would silently roll
# forward to whatever the major tag points at.
FROM node:${NODE_VERSION}-trixie-slim AS node_src

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
#
# Source maps: assets.deploy runs build/upload-sourcemaps.cjs, which ships
# maps to Sentry only when SENTRY_AUTH_TOKEN/SENTRY_ORG/SENTRY_PROJECT are
# set in the build env, and otherwise skips (so local/CI builds without
# Sentry creds still succeed). These are declared as ARGs so Render's build
# environment populates them, and passed only to this RUN so the auth token
# is never ENV-persisted into an image layer (the builder stage is
# discarded in the final image regardless).
#
# RENDER_GIT_COMMIT is Render's commit SHA; it tags the upload with the
# same release runtime events report. Nothing to set by hand.
ARG RENDER_GIT_COMMIT=""
ARG SENTRY_ORG=""
ARG SENTRY_PROJECT=""
ARG SENTRY_AUTH_TOKEN=""
RUN RENDER_GIT_COMMIT="${RENDER_GIT_COMMIT}" \
    SENTRY_ORG="${SENTRY_ORG}" \
    SENTRY_PROJECT="${SENTRY_PROJECT}" \
    SENTRY_AUTH_TOKEN="${SENTRY_AUTH_TOKEN}" \
    mix assets.deploy
RUN mix compile

# Package the app's source so Sentry can show source context on backend
# stack traces. Writes into the :sentry dep's priv dir, which the release
# bundles; loaded when the :sentry app starts. Must run before mix release.
RUN mix sentry.package_source_code

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
# `libatomic1` is required by the copied Node binary (used for Inertia SSR
# and the HEALTHCHECK below) — without it `node` fails on first invocation
# with "libatomic.so.1: cannot open shared object file".
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates libatomic1 tini \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# UTF-8 locale. `C.UTF-8` ships with glibc, so we skip the `locales`
# package and `locale-gen` entirely. Elixir/OTP only need *a* UTF-8
# locale — string handling uses Elixir's own Unicode tables, not libc.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Node binary for Inertia SSR (`priv/ssr.js`). Sourced from the `node_src`
# stage above, which is `node:${NODE_VERSION}-trixie-slim` — this is a real
# pin; without the stage alias the COPY would silently roll forward as new
# 26.x patches ship under the major tag. Same Debian base as the builder,
# so the binary's shared-lib deps resolve.
COPY --from=node_src /usr/local/bin/node /usr/local/bin/node

WORKDIR /app

# Run as a non-root user.
RUN useradd --create-home --uid 1000 app
USER app

ENV MIX_ENV="prod"
# `bin/server` (from rel/overlays) sets PHX_SERVER=true and boots the
# endpoint. PORT is read in runtime.exs; default matches EXPOSE.
ENV PORT=4000
# Cap each Inertia SSR Node worker's V8 heap. The BEAM spawns these node
# processes (and the HEALTHCHECK below) and they inherit NODE_OPTIONS, so
# this bounds the Node side of memory alongside SSR_POOL_SIZE. Override in
# the deploy env if a heavier SSR page needs more headroom.
ENV NODE_OPTIONS="--max-old-space-size=160"
EXPOSE 4000

COPY --from=builder --chown=app:app /app/_build/prod/rel/elixir_react_starter ./

# Liveness probe against the public /health endpoint. Reuses the Node
# binary that's already here for SSR — no curl/wget needed. Node 26
# ships a global fetch.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://localhost:'+(process.env.PORT||4000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/bin/server"]
