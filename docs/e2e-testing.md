# End-to-End Testing

Browser-level tests driven by [Playwright](https://playwright.dev). They
exercise the critical user journeys end to end — through real HTTP, the
rendered React UI, the database, and the dev mailbox.

They live under `assets/` so they reuse the existing `package.json`, Node
toolchain, and TypeScript setup (`assets/tsconfig.e2e.json`) rather than a
separate project.

## What's covered

| Spec | Flow |
| --- | --- |
| `registration.spec.ts` | Sign up → confirm via the emailed link → land on the dashboard |
| `login.spec.ts` | Log in to the dashboard; reject bad credentials with a visible error |
| `reset-password.spec.ts` | Request a reset link → set a new password → log in with it |
| `locale.spec.ts` | Switch the interface language (English → Spanish) |

## Prerequisites

1. The toolchain (Erlang, Elixir, Node) installed via mise — see the
   [README](readme.html).
2. The Playwright browser, installed once:

   ```bash
   npm --prefix assets run e2e:install
   ```

## Running

The suite drives a **running dev server** — it does not boot one. Start the
server in one terminal:

```bash
mix phx.server
```

Then run the suite in another:

```bash
npm --prefix assets run e2e          # headless
npm --prefix assets run e2e:ui       # Playwright UI mode (watch + time travel)
npm --prefix assets run e2e:headed   # headed browser
```

Point the suite at a different server with `E2E_BASE_URL` (defaults to
`http://localhost:4000`).

## How it works

### Parallel safety

The suite runs `fullyParallel`. Every test that creates data generates a
unique `e2e-test-…@example.com` email (`uniqueEmail/1` in `helpers.ts`), so
parallel workers never collide on the unique email index. Each test also
runs in its own browser context, so cookies (locale, session) don't leak
between tests.

### Fixtures and provisioning

Tests that need an *existing* account call the dev-only fixture endpoint
`POST /dev/e2e/users`, which mints a **confirmed** user and skips the
email-confirmation round-trip. The registration spec is the exception — it
drives the real sign-up and clicks the confirmation link.

Before the suite runs, `global-setup.ts` executes `priv/repo/e2e.exs`,
which deletes per-run users left over from earlier runs (deleting a user
cascades to their tokens), so every run starts clean.

Both the endpoint and the cleanup script are gated to `:dev` / `:test`
with `:dev_routes` enabled, and only ever touch `e2e-test-…` accounts —
they are unreachable in production and cannot affect real data.

### Link-based flows

Authentication here is link-based, so the registration and reset specs
read the single-click URL out of the dev mailbox JSON
(`/dev/mailbox/json`) via `fetchEmailLink/3` and navigate to it.

## Writing a new test

1. Add a `*.spec.ts` under `assets/e2e/tests/`.
2. Generate any users with `uniqueEmail/1` or `provisionUser/2` from
   `helpers.ts` — never hard-code an email, or parallel runs will clash.
3. If the flow needs an authenticated session, prefer `provisionUser`
   over walking the whole sign-up UI; reserve the full journey for the
   spec that's actually testing it.

## File layout

```
assets/
  playwright.config.ts      # base URL, parallelism, global setup
  tsconfig.e2e.json         # node-typed TS project for the suite
  e2e/
    global-setup.ts         # runs priv/repo/e2e.exs before the suite
    helpers.ts              # uniqueEmail, provisionUser, loginAs, fetchEmailLink
    tests/                  # one spec per flow
priv/repo/e2e.exs           # destructive per-run cleanup (dev/test only)
lib/web_template_web/controllers/dev_e2e_controller.ex  # POST /dev/e2e/users
```
