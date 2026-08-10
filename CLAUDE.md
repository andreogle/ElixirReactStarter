# Phoenix + Inertia.js (React, SSR) — Web App Template

A Phoenix 1.8 web app template. The frontend is Inertia.js + React with SSR (not LiveView).

This file documents the critical invariants that must never be missed and the project-specific modules/helpers shipped with the template.

## Critical invariants (never skip)

These are the rules that must not be forgotten or looked up — they're the ones that cause security bugs, data loss, or broken requests if violated.

**Security**
- Hashing: **SHA3-256** (`:sha3_256`). Passwords: **Argon2**. Never SHA-1, SHA-256, or MD5
- Never log PII. Use `ElixirReactStarter.Log.redact_email/1` when an email must appear; prefer user IDs
- Never put security codes/tokens in email **subjects** (they show on lock screens). Body only
- On sensitive account changes (email, password, 2FA), notify the **old** email too
- Never trust user-controlled redirect targets (e.g. `Referer`) without validating the path starts with `/`
- Content-Security-Policy ships **strict** in prod (per-request nonce + `strict-dynamic`, via `Plugs.ContentSecurityPolicy` in the `:csp` pipeline). Add third-party origins through the `:csp_extra_sources` config — never by loosening the plug. Inline `<script>` tags must carry `@csp_nonce`. Dev-only routes (`/dev/*`) deliberately skip `:csp` so tooling (the Swoosh mailbox iframe, LiveDashboard) keeps working

**Error handling**
- Always handle both `{:ok, _}` and `{:error, _}` from context calls — never `{:ok, x} = SomeContext.foo()`
- Consider TOCTOU in multi-step flows: re-validate in step 2 what you checked in step 1

**Database**
- New columns: `null: false` unless there's a specific reason otherwise. Prefer defaults over nullable
- Generate migrations with `mix ecto.gen.migration snake_case_name`
- Mark sensitive schema fields with `redact: true`; use `:utc_datetime` for timestamps

**Inertia (this project's frontend)**
- Use `render_inertia/2|3`, never `render/3`, for Inertia pages. Don't use LiveView for Inertia pages
- Page components are **always** `.tsx` (TypeScript), under `assets/js/pages/` in one of two strategy dirs: **`pages/ssr/`** (server-rendered: public / SEO / first-paint pages) or **`pages/client/`** (client-only: authenticated, interactive, heavy pages — kept out of the Node SSR bundle). The strategy dir is stripped from the Inertia page name, so `render_inertia("Dashboard")` maps to `pages/client/Dashboard.tsx`. The `_pages.ts` / `_ssr_pages.ts` registries are auto-generated from these dirs by `build/generate-ssr-pages.js` — never edit them by hand. New public page → `ssr/`; new authed page → `client/`
- Layout components live in `assets/js/layouts/` (e.g. `AppLayout`, `AuthLayout`)
- Reusable UI primitives live flat in `assets/js/components/` (`Button`, `Spinner`, `Select`, `DropdownMenu`, `AlertDialog`, …) — no sub-folders
- Forms use Inertia's `useForm` hook; errors come from `assign_errors(conn, changeset)` on the server
- **No raw `try/catch` for application async work — wrap every Promise in `go()` from `assets/js/errgo.ts`** (sync work uses `goSync`). It returns an error-first tuple, `[error, value]`, which forces every call site to acknowledge the failure path explicitly and prevents the "swallow the error and move on" pattern that hides real bugs. The same applies to dynamic `import()`, `fetch()`, JSON parsing, and vendor SDK calls. Raw catches are limited to Errgo's own implementation, React error boundaries, and CommonJS build-tool process boundaries that cannot import the TypeScript utility without a runtime transpiler
- `assets/js/errgo.ts` is vendored byte-for-byte from `andreogle/errgo` at commit `aaa1d5153a270cde4aa808369bd486ddbe263a38`. Update it by copying that source file, not by installing a package or editing the vendored implementation locally
- **Don't inline a multi-line function into `go(...)` / `goSync(...)`** — extract it to a named function above the call and pass it by name (`const [error, value] = await go(renderApp)`), so the call site stays a scannable one-liner. Small one-line callbacks (`go(() => i18n.changeLanguage(locale))`) are fine to inline. Mirrors the Elixir `with`-clause rule below
- **Multi-line arrow/function bodies use explicit braces and `return`** — never a multi-line implicit return (it's too easy to lose track of what's returned, or drop the `return` when editing, and get weird behaviour). When you convert an implicit return to a block body, **keep the `return`** so the returned value is preserved — only drop it when the value is genuinely unused. And if the body fits on one line within the 120-col width, prefer collapsing to a single-line implicit return rather than a block. Single-line implicit returns (`(x) => x.id`) and idiomatic multi-line JSX render-props wrapped in parens (`({ Component }) => ( <Foo /> )`) are fine
- Never edit `assets/js/_pages.ts`, `assets/js/_ssr_pages.ts`, or `assets/js/routes.ts` — they're auto-generated
- **Frontend paths come from the `routes` helper, never string literals.** `assets/js/routes.ts` is generated from the Phoenix router by `mix routes.gen` (run in `assets.build`/`assets.deploy` + the dev watcher; `mix routes.gen --check` in `precommit` fails the build on drift). Use `routes.login()`, `routes.settingsEmail()`, etc. for every internal URL on the frontend (`<Link href>`, `useForm().post(...)`, `router.visit/delete(...)`) — the TS path-builder is the frontend counterpart to the server's `~p` sigil and keeps the two in sync. Names are the camelCased path (`/settings/email/apply-change` → `settingsEmailApplyChange`, `/` → `root`); `:param` segments become typed args and every builder takes an optional query object (`routes.confirmEmail({ token })`). Adding/removing a route + rebuilding regenerates the file; never hand-edit it
- **Validation errors must redirect, not re-render.** On `{:error, changeset}` always use `conn |> assign_errors(changeset) |> redirect(to: ~p"/current-page")`. Do **not** use `put_status(:unprocessable_entity) |> render_inertia(...)` — Inertia updates the browser URL to the POST/PUT target when you re-render, which is both wrong UX and a regression risk. The Inertia plug flashes errors through the session across the redirect, so the form still shows them
- Use the `~p"/..."` sigil (verified routes) for every internal URL — in controllers, tests, and anywhere else in Elixir. Never write raw route strings; compile-time verification catches typos and broken links
- **JSON serialisation goes through `*_json.ex` view modules**, never ad-hoc serializer modules (no `*Props`, `*Serializer`, or per-controller helpers). One module per resource at `lib/elixir_react_starter_web/controllers/<resource>_json.ex` (e.g. `ElixirReactStarterWeb.PostJSON`) exposes `index/1` and `show/1` (the Phoenix 1.8 equivalents of `render_many`/`render_one`) that both delegate to a single `data/2`. Inertia callers use `MyJSON.data(record, viewer)` directly inside `assign_prop`; JSON API endpoints use `index`/`show` via `render`. This keeps the wire shape for a resource in one place so multiple callers can't drift

**Accessibility (non-negotiable)**
- Every interactive component must support full keyboard navigation, visible focus (`focus-visible` rings), proper ARIA roles/state, and screen-reader labels. No exceptions
- Prefer Radix primitives (`@radix-ui/react-*`) for anything interactive (Select, DropdownMenu, AlertDialog, Dialog, Tabs, etc.) — they ship correct a11y by default. Don't hand-roll dropdowns, modals, or popovers
- Icon-only buttons **must** have `aria-label`. Form inputs **must** have associated `<label>` (or `aria-labelledby`)
- Don't use `@radix-ui/themes` — it conflicts with the custom Tailwind design system. Wrap primitives with Tailwind classes instead

**Phoenix**
- This is an **Inertia-only** app — there are no LiveViews. The only HEEx that ships is `root.html.heex` (the Inertia shell). Don't reach for `Layouts.app`, `<.flash_group>`, `@current_scope`, `<.form for={@form}>`, or `CoreComponents` — none of that exists here. Build UI as React pages
- The current user is on `conn.assigns.current_user` (set by `ElixirReactStarterWeb.UserAuth.fetch_current_user`) and reaches the frontend as the `current_user` Inertia prop via `ElixirReactStarterWeb.Plugs.SharedData`
- Auth routes are split into pipelines in `router.ex`: public, guest-only (`redirect_if_user_is_authenticated`), and authenticated (`require_authenticated_user`)

**Elixir style**
- Each `<-` clause in a `with` must fit on a single line. If the right-hand side is a multi-line pipe, a multi-line function call with an inline map, or a multi-line `Ecto.Query.from` — **pre-bind it** to a named variable above the `with` and reference that name. Keep the `with` header scannable: every clause should read as "call this → match that"
- Same rule applies to the body / `else` branches — pull long pipes out into helpers or bindings rather than letting them bloat the `with`

**Workflow**
- Run `mix precommit` when done; fix anything it flags
- Never add a `Co-Authored-By` line to commit messages

## Project modules and helpers

### `ElixirReactStarter.Context` macro

Use it in every context module to get generated CRUD helpers (`list_*`, `get_*`, `get_*!`, `delete_*`, `count_*`, `filter_*`). Custom functions live alongside.

```elixir
use ElixirReactStarter.Context,
  repo: ElixirReactStarter.Repo,
  schema: ElixirReactStarter.Accounts.User
```

### `ElixirReactStarter.Log.redact_email/1`

Use this when an email must appear in a log line. Prefer logging user IDs over emails.

### `ElixirReactStarter.Factory` (ex_machina)

**Always** use the factory for test data — never call `Accounts.create_user` or similar **from tests as setup** (unless the function itself is what's under test). Factories live in `test/support/factories/`. Compose with modifier functions:

```elixir
:user |> build() |> confirmed() |> insert()
:user |> build(email: "test@example.com", locale: "es") |> insert()
```

**New schemas must ship a factory alongside them.** Put the factory in `test/support/factories/<schema>_factory.ex` and `use` it from `ElixirReactStarter.Factory`. Parent associations are passed explicitly (no implicit parent creation) so test data stays intentional and unique constraints don't collide under async.

For authenticated controller tests, use `@tag :authenticated` (or `@describetag`/`@moduletag` at the block level). It creates a confirmed user, logs them in, and puts `%{conn: conn, user: user}` into the test context. For tests that exercise failure paths emitting `Logger.warning`, add `@moduletag :capture_log`.

For channel tests use `ElixirReactStarterWeb.ChannelCase` (`connect/2`, `subscribe_and_join/3`, …).

## Esbuild profiles

- `elixir_react_starter` → `js/app.tsx` → `priv/static/assets/` (ESM, browser, `--splitting`)
- `elixir_react_starter_ssr` → `js/ssr.tsx` → `priv/ssr.js` (CJS, Node)

Both are already wired into `assets.build`, `assets.deploy`, and the dev watcher in `dev.exs`. They can't be merged — the browser bundle and the Node SSR bundle need different formats and targets.

## Brand colors (Tailwind theme tokens)

Define your project's brand colors in `assets/css/app.css` as Tailwind theme tokens (e.g. a `primary` and `secondary` token). Use the resulting Tailwind classes (`bg-primary`, `text-secondary`, `focus-visible:ring-primary`, etc.) for primary buttons, focus rings, and accent elements. Don't reach for arbitrary hex values in component code.

## Project rules

- Run `mix precommit` when done; fix anything it flags
- **Never** add a `Co-Authored-By` line to commit messages
- **No LiveView pages** — every UI page is Inertia + React. The only HEEx template that ships is `root.html.heex`, the Inertia shell. If you ever reintroduce LiveView, re-add `Layouts.app` / `<.flash_group>` / `CoreComponents` rather than assuming they already exist
- For React pages, use `lucide-react` (imported as `Check`, `CalendarDays`, `GraduationCap`, etc. — no `Icon` suffix). Don't add `@heroicons/react` back; heroicons is effectively unmaintained
- Inertia `<Link>` is imported from `components/Link.tsx` (our wrapper that defaults `prefetch="hover"`), never from `@inertiajs/react` directly — a Biome rule enforces this
- No daisyUI. Plain Tailwind for markup; Radix UI for interactive components

## What's shipped

The template already includes these — extend them, don't rebuild them.

**Auth** (`ElixirReactStarter.Accounts`, `ElixirReactStarterWeb.{AuthController, UserAuth}`)
- Email + password registration, **link-based** email confirmation and password reset (1-hour `UserToken`s; the raw token rides in the email URL, only its SHA3-256 hash is stored). Session tokens use a 60-day sliding window
- The `User` schema is deliberately minimal: `email`, `hashed_password`, `locale`, `confirmed_at`. Add profile fields (name, avatar, …) per project — there's no `name` column yet
- Endpoint responses don't leak which emails are registered (resend-confirmation / forgot-password reply identically either way)
- Account settings (`SettingsController`): link-confirmed **email change** (the link hits `/settings/email/apply-change`; the old address is notified — distinct from the public `/confirm-email` account-activation route), **password change** (invalidates the user's other sessions), and **account deletion**. All three re-verify the current password first

**Realtime** (`ElixirReactStarterWeb.{UserSocket, GlobalChannel, UserChannel}` + `assets/js/realtime/`)
- Token-authed socket at `/socket`. The provider (mounted in `app-providers.tsx`) auto-joins `global` and `user:<id>` and survives Inertia navigation (keyed on user id, not the rotating token). Hooks: `useConnectionStatus`, `useGlobalChannel`, `useUserChannel`, `useChannel`, `use{Global,User}Event`, `pushChannel`

**Locale** (`ElixirReactStarterWeb.LocaleController`, `PUT /locale`)
- Precedence: `user.locale` (authed) → `locale` cookie (anonymous, 1-year) → `Accept-Language` → `:default_locale`. The public endpoint sets the cookie and, when signed in, also writes `user.locale`. Frontend strings go through `react-i18next` (`useTranslation`); locale files are `assets/js/i18n/locales/{en,es}.ts`

**Theme** (`assets/js/theme.ts`, `ThemeToggle`)
- light / dark / system, stored in a `theme` cookie. An inline bootstrap in `root.html.heex` applies the `dark` class before first paint (no flash). Dark mode is class-based (`@custom-variant dark`)

**Static analysis** — `mix precommit` stays fast; CI runs `mix precommit.full` which adds dialyzer.

## UI/UX bar

- World-class UI: usability, aesthetics, modern design
- Subtle micro-interactions (hover, focus, smooth transitions)
- Clean typography, spacing, layout balance
- Delightful details: hover effects, loading states, page transitions
