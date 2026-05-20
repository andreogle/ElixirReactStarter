import { type APIRequestContext, expect, type Page } from '@playwright/test';

/**
 * Helpers shared across the Playwright suite.
 *
 * Tests run in parallel, so every helper that creates data must produce
 * unique identifiers per call — workers must never collide on the unique
 * email index. Anything that talks to the dev mailbox or the `/dev/e2e/*`
 * fixture endpoint lives here so specs read like scenarios, not glue.
 */

// =============================================================================
// Unique identifiers
// =============================================================================

/**
 * Build an email guaranteed to be unique within the run. The `e2e-test-`
 * prefix matches the cleanup pattern in `priv/repo/e2e.exs`, so anything
 * provisioned this way is wiped before the next run.
 */
export function uniqueEmail(label: string): string {
  const slug = label.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const stamp = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  return `e2e-test-${slug}-${stamp}@example.com`;
}

// =============================================================================
// User provisioning — mints a confirmed user via the dev-only fixture
// endpoint. Use this when a test isn't about registration itself; the
// registration spec exercises the real sign-up path.
// =============================================================================

export interface ProvisionedUser {
  id: string;
  email: string;
  password: string;
}

export async function provisionUser(
  request: APIRequestContext,
  options: { label: string; password?: string; confirmed?: boolean }
): Promise<ProvisionedUser> {
  const email = uniqueEmail(options.label);
  const password = options.password ?? 'playwright-secret-1234';
  const data: Record<string, unknown> = { email, password };
  // Confirmed by default; pass `confirmed: false` for the resend flow.
  if (options.confirmed === false) data.confirmed = false;

  const response = await request.post('/dev/e2e/users', { data });
  expect(
    response.ok(),
    `POST /dev/e2e/users failed: ${response.status()} ${await response.text()}`
  ).toBeTruthy();

  const body = (await response.json()) as { id: string };
  return { id: body.id, email, password };
}

// =============================================================================
// Auth flows
// =============================================================================

/**
 * Log in via the /login form. Asserts the redirect to /dashboard so callers
 * don't repeat it in every spec.
 */
export async function loginAs(page: Page, user: { email: string; password: string }): Promise<void> {
  await page.goto('/login');
  await page.getByLabel('Email').fill(user.email);
  await page.getByLabel('Password').fill(user.password);
  await page.getByRole('button', { name: 'Log in' }).click();
  await expect(page).toHaveURL('/dashboard');
}

// =============================================================================
// Mailbox — auth here is link-based, so flows fetch a single-click URL from
// the dev mailbox rather than a code.
// =============================================================================

interface MailboxEmail {
  subject?: string;
  text_body?: string | null;
  html_body?: string | null;
}

/**
 * Poll the dev mailbox for the newest link sent to `email` whose path
 * matches `route` (e.g. `/confirm-email` or `/reset-password`), returned as
 * a baseURL-relative path so `page.goto` stays environment-agnostic.
 */
export async function fetchEmailLink(
  request: APIRequestContext,
  email: string,
  route: '/confirm-email' | '/reset-password',
  { timeoutMs = 5_000, intervalMs = 250 }: { timeoutMs?: number; intervalMs?: number } = {}
): Promise<string> {
  const pattern = new RegExp(`${route}\\?token=[A-Za-z0-9_-]+`);
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    const resp = await request.get('/dev/mailbox/json');
    expect(resp.ok(), 'dev mailbox JSON endpoint must be reachable').toBeTruthy();

    const { data } = (await resp.json()) as { data: MailboxEmail[] };

    const links = data
      // Match by recipient without depending on Swoosh's exact `to` shape.
      .filter((mail) => JSON.stringify(mail).includes(email))
      .map((mail) => (mail.text_body ?? mail.html_body ?? '').match(pattern)?.[0])
      .filter((link): link is string => Boolean(link));

    // Newest link last — return the most recent.
    if (links.length > 0) return links[links.length - 1];
    await sleep(intervalMs);
  }

  throw new Error(`Timed out waiting for a ${route} link addressed to ${email}.`);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
