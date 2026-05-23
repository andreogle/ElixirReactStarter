import { expect, test } from '../fixtures';
import { fetchEmailLink, provisionUser } from '../helpers';

test('an unconfirmed user resends the confirmation email from /login and confirms', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'resend', confirmed: false });

  // The resend page is reached from the login page link.
  await page.goto('/login');
  await page.getByRole('link', { name: 'Resend confirmation email' }).click();
  await expect(page).toHaveURL('/resend-confirmation');

  // Request a fresh confirmation link.
  await page.getByLabel('Email').fill(user.email);
  await page.getByRole('button', { name: 'Send confirmation link' }).click();
  await expect(page).toHaveURL('/login');

  // Follow the link from the mailbox → account confirmed → dashboard.
  const link = await fetchEmailLink(page.request, user.email, '/confirm-email');
  await page.goto(link);
  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByRole('main').getByText(user.email)).toBeVisible();
});
