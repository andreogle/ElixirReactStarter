<p align="center">
  <img src=".github/logo.png" alt="WebTemplate" width="220" />
</p>

<h1 align="center">WebTemplate</h1>

<p align="center">
  A production-ready Phoenix + Inertia.js (React, SSR) starter — authentication,
  real-time, i18n, theming, testing, CI, and Docker, already wired and tested.
</p>

<p align="center">
  <a href="https://github.com/andreogle/WebTemplate/actions/workflows/ci.yml">
    <img src="https://github.com/andreogle/WebTemplate/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
</p>

## Why this exists

Every new Phoenix app starts by rebuilding the same foundation — authentication,
internationalization, real-time, theming, email, and the testing/CI/deployment
plumbing around them — usually under time pressure and rarely the same way twice.
WebTemplate ships that foundation already built, wired together, and tested, with
secure and accessible defaults, so you can start on your actual product instead of
boilerplate. It deliberately pairs Phoenix with **Inertia.js + React (with SSR)**
rather than LiveView: you get React's component ecosystem and rich client-side
interactions while keeping Phoenix's server-side routing, controllers, and auth —
and without maintaining a separate API and single-page-app build.

## Features

**Authentication & accounts**
- Email + password registration with **link-based** email confirmation (no codes).
- Password reset via single-use email links — 1-hour expiry, SHA3-256-hashed tokens, raw token only ever in the URL.
- Argon2 password hashing (with a SHA3-256 prehash); 60-day sliding session window.
- Account settings: change password (signs out other devices) and delete account, both re-verifying the current password.
- No account enumeration — confirmation/reset endpoints respond identically for unknown emails.

**Real-time**
- Token-authenticated Phoenix Channels; a React provider auto-joins a global and a per-user channel and survives Inertia navigation.
- Connection-status indicator and hooks (`useChannel`, `useGlobalChannel`, `useUserChannel`, `useConnectionStatus`, …).

**Internationalization**
- gettext on the server, react-i18next on the client; English and Spanish out of the box.
- Locale precedence: signed-in preference → cookie → `Accept-Language` → default. `mix i18n.check` guards translation coverage.

**Theming**
- Light / dark / system, persisted in a cookie and applied before first paint (no flash). Class-based dark mode with Tailwind CSS v4.

**Accessibility**
- Radix UI primitives for every interactive component, the full Biome `a11y` rule set enforced in CI, and axe-core auditing in development.

**Email**
- Swoosh with paired HTML + plain-text bodies; Mailjet in production and an in-browser mailbox in development.

**Jobs & clustering**
- Oban configured for background jobs (pruner enabled, manual mode in tests); DNSCluster for multi-node deployments.

**Testing**
- ExUnit with a 94% coverage gate and ex_machina factories.
- Playwright end-to-end suite (registration, login, password reset, resend confirmation, locale) under `assets/`.

**Tooling & CI**
- mise pins the entire toolchain (Erlang / Elixir / Node).
- Biome, Credo, and Dialyzer; one-command `mix precommit` (and `mix precommit.full` with Dialyzer).
- GitHub Actions CI (mise-action, Postgres service, coverage gate, SHA-pinned actions).

**Deployment**
- Multi-stage `Dockerfile` producing a slim release (Debian trixie, bundled Node for SSR, non-root, tini) plus release migration tasks.

**Documentation**
- ex_doc with developer guides (`docs/`) and the full module reference, served at `/dev/docs` in development.

## Tech stack

- **Backend** — Elixir 1.19 · Phoenix 1.8 (Bandit) · Ecto + PostgreSQL · Oban · Swoosh · gettext
- **Frontend** — Inertia.js 2 · React 19 + SSR · Tailwind CSS v4 · Radix UI · esbuild · TypeScript · Biome
- **Tooling** — mise · Credo · Dialyzer · ex_doc · ExUnit + ex_machina · Playwright · GitHub Actions · Docker

## Getting started

**Prerequisites:** [mise](https://mise.jdx.dev) (pins the toolchain) and a running PostgreSQL.

```bash
# 1. Install the pinned Erlang, Elixir, and Node (versions live in mise.toml)
mise trust && mise install

# 2. Install deps, create + migrate the database, build assets
mix setup

# 3. Start the server
mix phx.server   # or: iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000). With shell activation enabled
(`eval "$(mise activate zsh)"` in `~/.zshrc`), mise switches to the project's
toolchain automatically when you `cd` in.

## Testing

```bash
mix test                       # unit + integration, with coverage gate (mix test --cover)
mix precommit                  # format, credo, biome, i18n, tests — run before every commit
npm --prefix assets run e2e    # Playwright E2E (needs a running server; see the guide)
```

See the [End-to-End Testing guide](docs/e2e-testing.md) for the Playwright setup.

## Documentation

Searchable developer guides and the full module reference are generated with ex_doc:

```bash
mix docs
```

In development they're also served at
[`/dev/docs`](http://localhost:4000/dev/docs/index.html). Topic guides live in
`docs/` — e.g. the [End-to-End Testing guide](docs/e2e-testing.md).

## Deployment

`SECRET_KEY_BASE` must be generated **once** and kept stable across restarts — a
changing value invalidates every session and signed cookie. Generate it a single
time with `mix phx.gen.secret` and store it in your secrets manager or host config,
then build and run the release image (reading the stored value from the environment):

```bash
docker build -t web_template .
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  -e DATABASE_URL="ecto://USER:PASS@HOST/DB" \
  -e PHX_HOST="example.com" \
  web_template
```

Database migrations run via the release: `bin/migrate`. See Phoenix's
[deployment guides](https://hexdocs.pm/phoenix/deployment.html) for hosting specifics.

## Conventions

Project architecture, invariants, and coding conventions are documented in
[`CLAUDE.md`](CLAUDE.md) — start there before making changes.

## License

Released under the **WTFPL** (see the `LICENSE` file) — do what the fuck you want.
