import { expect, test } from '../fixtures';
import { fetchEmailLink, provisionUser } from '../helpers';

test('clicking a confirmation link a second time keeps an already-confirmed user on the dashboard', async ({
  page,
  request,
}) => {
  // Start unconfirmed and mint a real confirmation link via the resend flow.
  const user = await provisionUser(request, { label: 'confirm-twice', confirmed: false });

  await page.goto('/resend-confirmation');
  await page.getByLabel('Email').fill(user.email);
  await page.getByRole('button', { name: 'Send confirmation link' }).click();
  await expect(page).toHaveURL('/login');

  const link = await fetchEmailLink(page.request, user.email, '/confirm-email');

  // First click confirms and logs in.
  await page.goto(link);
  await expect(page).toHaveURL('/dashboard');

  // Second click — the single-use token is gone, but the visitor is
  // already confirmed and signed in, so they should land on the dashboard
  // rather than the confusing "invalid link" + resend page.
  await page.goto(link);
  await expect(page).toHaveURL('/dashboard');
});

test('an invalid confirmation link signed out sends the visitor to resend confirmation', async ({ page }) => {
  await page.goto('/confirm-email?token=not-a-real-token');
  await expect(page).toHaveURL('/resend-confirmation');
  // .first(): flash toasts are mirrored into an aria-live region.
  await expect(page.getByText(/invalid or expired/i).first()).toBeVisible();
});
