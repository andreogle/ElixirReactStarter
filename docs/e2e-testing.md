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
| `login.spec.ts` | Log in; reject bad credentials; an unconfirmed login re-sends the confirmation link instead of starting a session |
| `logout.spec.ts` | Log out from the header menu → protected pages bounce to `/login` |
| `resend-confirmation.spec.ts` | Unconfirmed user requests a fresh link from `/login` → confirms |
| `email-confirmation.spec.ts` | Re-clicking a used link keeps an already-confirmed user on the dashboard; a stale link signed out → resend page |
| `reset-password.spec.ts` | Request a reset link → set a new password → log in with it |
| `change-email.spec.ts` | Change email → confirm via the link to the new inbox → log in with it (+ wrong-password rejection) |
| `change-password.spec.ts` | Change password → old one fails, new one works (+ wrong-password rejection) |
| `delete-account.spec.ts` | Delete the account behind a password-confirm dialog → can no longer sign in (+ wrong-password rejection) |
| `auth-guards.spec.ts` | Pipeline redirects: anonymous → `/login`, already signed-in → `/dashboard` |
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

### Isolation

Every test that creates data generates a unique `e2e-test-…@example.com`
email (`uniqueEmail/1` in `helpers.ts`), so tests never collide on the
unique email index or see each other's accounts. Each test also runs in its
own browser context, so cookies (locale, session) don't leak between tests.

When a test ends, pass or fail, the auto `cleanup` fixture (`fixtures.ts`)
deletes every account behind the emails that test generated — provisioned,
registered through the UI, or changed to — via `DELETE /dev/e2e/users`. A
clean run leaves nothing behind. Before the suite runs, `global-setup.ts`
executes `priv/repo/e2e.exs`, which removes whatever a crashed or
interrupted run left (deleting a user cascades to their tokens).

Auth **rate limiting is disabled in dev** (`config/dev.exs`), since the
suite drives the dev server and makes many auth requests from one IP. The
limiter is a production concern and is covered separately by
`rate_limit_test.exs`.

### Parallelism and timing

- **Workers:** half the cores, at most 3 locally, 2 on CI. The limit is
  the one dev server every browser drives — overloading it turns
  slow-but-correct into timeouts. `E2E_WORKERS=1` rules load out when
  chasing a failure.
- **Files run in parallel; tests inside a file run in order**, which
  spreads load evenly.
- **Retries:** one on CI (a test that only passes on retry is still
  reported as flaky — fix it), none locally so flakiness shows.
- **Timeouts:** actions and navigations have their own bounds, shorter than
  the test timeout, so a stuck click fails with a clear message.
- **No fixed sleeps.** Wait on something observable (`expect(...)`, a URL,
  the hydration flag) — a sleep is too short on a slow machine and wasted
  time on a fast one.
- **Hydration:** the wrapped `page.goto` waits for `html[data-hydrated]`.
  A page that never hydrates fails with what it reported while loading
  (script errors, failed requests, 5xx responses) instead of a bare
  timeout. A second page (another tab or browser context) calls
  `waitForHydration(page)` after navigating; `loginAs` already does.

### Server rendering in dev

The dev server runs its SSR Node workers with `NODE_ENV=production` (the
`:reload_ssr` flag in `config/dev.exs`). Without it, the `nodejs` package
reloads `priv/ssr.js` on every render and a worker runs out of heap after a
few hundred renders — a random 500 midway through a long run.
`ElixirReactStarterWeb.SSRReloader` restarts the workers when the bundle is
rebuilt, so SSR changes still show up on the next page load.

### Fixtures and provisioning

Tests that need an *existing* account call the dev-only fixture endpoint
`POST /dev/e2e/users`, which mints a **confirmed** user and skips the
email-confirmation round-trip. The registration spec is the exception — it
drives the real sign-up and clicks the confirmation link.

The endpoints and the cleanup script go through
`ElixirReactStarter.E2EFixtures`, are gated to `:dev` / `:test` with
`:dev_routes` enabled, and only ever touch `e2e-test-…` accounts — they are
unreachable in production and cannot affect real data.

### Link-based flows

Authentication here is link-based, so the link-driven specs (sign-up,
password reset, email change, resend confirmation) read the single-click
URL out of the dev mailbox JSON (`/dev/mailbox/json`) via
`fetchEmailLink/3` and navigate to it.

## Writing a new test

1. Add a `*.spec.ts` under `assets/e2e/tests/`.
2. Generate any users with `uniqueEmail/1` or `provisionUser/2` from
   `helpers.ts` — never hard-code an email, or parallel runs will clash
   and the account won't be cleaned up.
3. If the flow needs an authenticated session, prefer `provisionUser`
   over walking the whole sign-up UI; reserve the full journey for the
   spec that's actually testing it.

## File layout

```
assets/
  playwright.config.ts      # base URL, workers, retries, timeouts, global setup
  tsconfig.e2e.json         # node-typed TS project for the suite
  e2e/
    fixtures.ts             # per-test account cleanup, hydration wait + diagnostics
    global-setup.ts         # runs priv/repo/e2e.exs before the suite
    helpers.ts              # uniqueEmail, provisionUser, loginAs, logoutViaMenu, gotoSettingsViaMenu, fetchEmailLink
    tests/                  # one spec per flow
priv/repo/e2e.exs           # removes leftovers of an interrupted run (dev/test only)
lib/elixir_react_starter/e2e_fixtures.ex                        # create/delete/reset E2E accounts
lib/elixir_react_starter_web/controllers/dev_e2e_controller.ex  # POST/DELETE /dev/e2e/users
lib/elixir_react_starter_web/ssr_reloader.ex                    # dev: restart SSR workers on rebuild
```
