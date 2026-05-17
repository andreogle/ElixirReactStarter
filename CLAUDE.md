# Phoenix + Inertia.js (React, SSR) — Web App Template

A Phoenix 1.8 web app template. The frontend is Inertia.js + React with SSR (not LiveView).

This file documents the critical invariants that must never be missed and the project-specific modules/helpers shipped with the template.

## Critical invariants (never skip)

These are the rules that must not be forgotten or looked up — they're the ones that cause security bugs, data loss, or broken requests if violated.

**Security**
- Hashing: **SHA3-256** (`:sha3_256`). Passwords: **Argon2**. Never SHA-1, SHA-256, or MD5
- Never log PII. Use `WebTemplate.Log.redact_email/1` when an email must appear; prefer user IDs
- Never put security codes/tokens in email **subjects** (they show on lock screens). Body only
- On sensitive account changes (email, password, 2FA), notify the **old** email too
- Never trust user-controlled redirect targets (e.g. `Referer`) without validating the path starts with `/`

**Error handling**
- Always handle both `{:ok, _}` and `{:error, _}` from context calls — never `{:ok, x} = SomeContext.foo()`
- Consider TOCTOU in multi-step flows: re-validate in step 2 what you checked in step 1

**Database**
- New columns: `null: false` unless there's a specific reason otherwise. Prefer defaults over nullable
- Generate migrations with `mix ecto.gen.migration snake_case_name`
- Mark sensitive schema fields with `redact: true`; use `:utc_datetime` for timestamps

**Inertia (this project's frontend)**
- Use `render_inertia/2|3`, never `render/3`, for Inertia pages. Don't use LiveView for Inertia pages
- Page components are **always** `.tsx` (TypeScript), in `assets/js/pages/`
- Layout components live in `assets/js/layouts/` (e.g. `AppLayout`, `AuthLayout`)
- Reusable UI primitives live flat in `assets/js/components/` (`Button`, `Spinner`, `Select`, `DropdownMenu`, `AlertDialog`, …) — no sub-folders
- Forms use Inertia's `useForm` hook; errors come from `assign_errors(conn, changeset)` on the server
- **No raw `try/catch` for async work — wrap every Promise in `go()` from `@api3/promise-utils`** (sync work uses `goSync`). It returns `{ success, data, error }`, which forces every call site to acknowledge the failure path explicitly and prevents the "swallow the error and move on" pattern that hides real bugs. The same applies to dynamic `import()`, `fetch()`, JSON parsing, and any vendor SDK call (`livekit-client`, etc.). The only acceptable exception is at top-level error boundaries that genuinely *do* need to catch everything synchronously
- Never edit `assets/js/_ssr_pages.ts` — it's auto-generated
- **Validation errors must redirect, not re-render.** On `{:error, changeset}` always use `conn |> assign_errors(changeset) |> redirect(to: ~p"/current-page")`. Do **not** use `put_status(:unprocessable_entity) |> render_inertia(...)` — Inertia updates the browser URL to the POST/PUT target when you re-render, which is both wrong UX and a regression risk. The Inertia plug flashes errors through the session across the redirect, so the form still shows them
- Use the `~p"/..."` sigil (verified routes) for every internal URL — in controllers, tests, and anywhere else in Elixir. Never write raw route strings; compile-time verification catches typos and broken links
- **JSON serialisation goes through `*_json.ex` view modules**, never ad-hoc serializer modules (no `*Props`, `*Serializer`, or per-controller helpers). One module per resource at `lib/web_template_web/controllers/<resource>_json.ex` (e.g. `WebTemplateWeb.LessonJSON`) exposes `index/1` and `show/1` (the Phoenix 1.8 equivalents of `render_many`/`render_one`) that both delegate to a single `data/2`. Inertia callers use `MyJSON.data(record, viewer)` directly inside `assign_prop`; JSON API endpoints use `index`/`show` via `render`. This keeps the wire shape for a resource in one place so multiple callers can't drift

**Accessibility (non-negotiable)**
- Every interactive component must support full keyboard navigation, visible focus (`focus-visible` rings), proper ARIA roles/state, and screen-reader labels. No exceptions
- Prefer Radix primitives (`@radix-ui/react-*`) for anything interactive (Select, DropdownMenu, AlertDialog, Dialog, Tabs, etc.) — they ship correct a11y by default. Don't hand-roll dropdowns, modals, or popovers
- Icon-only buttons **must** have `aria-label`. Form inputs **must** have associated `<label>` (or `aria-labelledby`)
- Don't use `@radix-ui/themes` — it conflicts with the custom Tailwind design system. Wrap primitives with Tailwind classes instead

**Phoenix**
- Wrap every LiveView template with `<Layouts.app flash={@flash} current_scope={@current_scope} ...>`
- Access the user as `@current_scope.user` — never `@current_user` in templates/LiveViews
- `<.flash_group>` only in `layouts.ex` (Phoenix 1.8 moved it there)
- Always use `<.form for={@form}>` and `<.input field={@form[:field]}>` — never access the changeset in templates

**Elixir style**
- Each `<-` clause in a `with` must fit on a single line. If the right-hand side is a multi-line pipe, a multi-line function call with an inline map, or a multi-line `Ecto.Query.from` — **pre-bind it** to a named variable above the `with` and reference that name. Keep the `with` header scannable: every clause should read as "call this → match that"
- Same rule applies to the body / `else` branches — pull long pipes out into helpers or bindings rather than letting them bloat the `with`

**Workflow**
- Run `mix precommit` when done; fix anything it flags
- Never add a `Co-Authored-By` line to commit messages

## Project modules and helpers

### `WebTemplate.Context` macro

Use it in every context module to get generated CRUD helpers (`list_*`, `get_*`, `get_*!`, `delete_*`, `change_*`, `count_*`, `filter_*`). Custom functions live alongside.

```elixir
use WebTemplate.Context,
  repo: WebTemplate.Repo,
  schema: WebTemplate.Accounts.User,
  changeset: :registration_changeset
```

### `WebTemplate.Log.redact_email/1`

Use this when an email must appear in a log line. Prefer logging user IDs over emails.

### `WebTemplate.Factory` (ex_machina)

**Always** use the factory for test data — never call `Accounts.create_user`, `Scheduling.create_availability_rule`, or similar **from tests as setup** (unless the function itself is what's under test). Factories live in `test/support/factories/`. Compose with modifier functions:

```elixir
:user |> build(email: "test@example.com") |> confirmed() |> insert()
insert(:tenant)
insert(:membership, tenant: tenant, user: user, role: "teacher")
insert(:availability_rule, user: teacher, day_of_week: 1)
```

**New schemas must ship a factory alongside them.** Put the factory in `test/support/factories/<schema>_factory.ex` and `use` it from `WebTemplate.Factory`. Parent associations are passed explicitly (no implicit parent creation) so test data stays intentional and unique constraints don't collide under async.

For authenticated controller tests, use `@tag :authenticated` (or `@describetag`/`@moduletag` at the block level). It creates a confirmed user, logs them in, and puts `%{conn: conn, user: user}` into the test context.

## Esbuild profiles

- `web_template` → `js/app.tsx` → `priv/static/assets/` (ESM, browser, `--splitting`)
- `web_template_ssr` → `js/ssr.tsx` → `priv/ssr.js` (CJS, Node)

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

## UI/UX bar

- World-class UI: usability, aesthetics, modern design
- Subtle micro-interactions (hover, focus, smooth transitions)
- Clean typography, spacing, layout balance
- Delightful details: hover effects, loading states, page transitions
