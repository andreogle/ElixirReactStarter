<p align="center">
  <img src=".github/logo.png" alt="ElixirReactStarter" width="220" />
</p>

<h1 align="center">ElixirReactStarter</h1>

<p align="center">
  A production-ready Phoenix + Inertia.js (React, SSR) starter — authentication,
  real-time, i18n, theming, testing, CI, and Docker, already wired and tested.
</p>

<p align="center">
  <a href="https://github.com/andreogle/ElixirReactStarter/actions/workflows/ci.yml">
    <img src="https://github.com/andreogle/ElixirReactStarter/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
</p>

## Why this exists

Every new Phoenix app starts by rebuilding the same foundation — authentication,
internationalization, real-time, theming, email, and the testing/CI/deployment
plumbing around them — usually under time pressure and rarely the same way twice.
ElixirReactStarter ships that foundation already built, wired together, and tested,
with secure and accessible defaults, so you can start on your actual product instead
of boilerplate. It deliberately pairs [Phoenix][phoenix] with **[Inertia.js][inertia]
+ [React][react] (with SSR)** rather than [LiveView][liveview]: you get React's
component ecosystem and rich client-side interactions while keeping Phoenix's
server-side routing, controllers, and auth — without maintaining a separate API and
single-page-app build.

## Features

- **Authentication** — email + password with link-based confirmation and password reset, [Argon2][argon2] hashing, sliding sessions, account management, and no email enumeration.
- **Real-time** — token-authenticated [Phoenix Channels][channels] with React hooks that survive [Inertia][inertia] navigation.
- **Internationalization** — [gettext][gettext] on the server and [react-i18next][react-i18next] on the client; English + Spanish with locale detection.
- **Theming** — light / dark / system with no flash of the wrong theme.
- **Accessibility** — [Radix UI][radix] primitives, [Biome][biome] a11y linting in CI, and [axe-core][axe] auditing in dev.
- **Email** — [Swoosh][swoosh] (HTML + text) via [Mailjet][mailjet] in production, with an in-browser mailbox in dev.
- **Security** — rate-limited auth endpoints, Secure cookies, CSRF protection, and HTTPS/HSTS in production.
- **Background jobs** — [Oban][oban], configured and ready.
- **Testing** — [ExUnit][exunit] with a coverage gate, [ex_machina][exmachina] factories, and a [Playwright][playwright] E2E suite.
- **Tooling & CI** — [mise][mise]-pinned toolchain, [Biome][biome] / [Credo][credo] / [Dialyzer][dialyxir], and [GitHub Actions][gha].
- **Deployment** — multi-stage [Docker][docker] release with server-side rendering.
- **Documentation** — [ex_doc][exdoc] guides and module reference.

## Tech stack

- **Backend** — [Elixir][elixir] · [Phoenix][phoenix] ([Bandit][bandit]) · [Ecto][ecto] + [PostgreSQL][postgresql] · [Oban][oban] · [Swoosh][swoosh] · [gettext][gettext]
- **Frontend** — [Inertia.js][inertia] · [React][react] (SSR) · [Tailwind CSS][tailwind] · [Radix UI][radix] · [esbuild][esbuild] · [TypeScript][typescript] · [Biome][biome]
- **Tooling** — [mise][mise] · [Credo][credo] · [Dialyzer][dialyxir] · [ex_doc][exdoc] · [ExUnit][exunit] + [ex_machina][exmachina] · [Playwright][playwright] · [GitHub Actions][gha] · [Docker][docker]

## Getting started

**Prerequisites:** [mise][mise] (pins the toolchain) and a running [PostgreSQL][postgresql].

> **Starting a new project from this template?** Rename it to your own name first:
>
> ```bash
> scripts/rename_project.sh YourAppName   # PascalCase
> ```
>
> It rewrites every module, the OTP app name, file/directory paths, and configs
> (both `PascalCase` and `snake_case` forms), then rebuilds and runs `mix precommit`
> to verify. Use `--dry-run` to preview the changes first.

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

See the [End-to-End Testing guide](docs/e2e-testing.md) for the [Playwright][playwright] setup.

## Documentation

Searchable developer guides and the full module reference are generated with [ex_doc][exdoc]:

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
docker build -t elixir_react_starter .
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  -e DATABASE_URL="ecto://USER:PASS@HOST/DB" \
  -e PHX_HOST="example.com" \
  elixir_react_starter
```

Database migrations run via the release: `bin/migrate`. See Phoenix's
[deployment guides](https://hexdocs.pm/phoenix/deployment.html) for hosting specifics.

## Conventions

Project architecture, invariants, and coding conventions are documented in
[`CLAUDE.md`](CLAUDE.md) — start there before making changes.

## License

Released under the **WTFPL** (see the `LICENSE` file) — do what the fuck you want.

[phoenix]: https://www.phoenixframework.org/
[inertia]: https://inertiajs.com/
[react]: https://react.dev/
[liveview]: https://hexdocs.pm/phoenix_live_view/
[argon2]: https://github.com/riverrun/argon2_elixir
[channels]: https://hexdocs.pm/phoenix/channels.html
[gettext]: https://hexdocs.pm/gettext/
[react-i18next]: https://react.i18next.com/
[tailwind]: https://tailwindcss.com/
[radix]: https://www.radix-ui.com/primitives
[biome]: https://biomejs.dev/
[axe]: https://github.com/dequelabs/axe-core
[swoosh]: https://hexdocs.pm/swoosh/
[mailjet]: https://www.mailjet.com/
[oban]: https://hexdocs.pm/oban/
[exunit]: https://hexdocs.pm/ex_unit/
[exmachina]: https://hexdocs.pm/ex_machina/
[playwright]: https://playwright.dev/
[mise]: https://mise.jdx.dev
[credo]: https://hexdocs.pm/credo/
[dialyxir]: https://github.com/jeremyjh/dialyxir
[exdoc]: https://hexdocs.pm/ex_doc/
[gha]: https://docs.github.com/en/actions
[docker]: https://www.docker.com/
[elixir]: https://elixir-lang.org/
[ecto]: https://hexdocs.pm/ecto/
[postgresql]: https://www.postgresql.org/
[bandit]: https://hexdocs.pm/bandit/
[typescript]: https://www.typescriptlang.org/
[esbuild]: https://esbuild.github.io/
