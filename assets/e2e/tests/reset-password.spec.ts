import { expect, test } from '../fixtures';
import { fetchEmailLink, loginAs, provisionUser } from '../helpers';

test('a user resets their password via the email link and logs in with the new one', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'reset' });
  const newPassword = 'brand-new-password-456';

  // Request a reset link.
  await page.goto('/forgot-password');
  await page.getByLabel('Email').fill(user.email);
  await page.getByRole('button', { name: 'Send reset link' }).click();
  await expect(page).toHaveURL('/login');

  // Follow the reset link from the mailbox and choose a new password.
  const link = await fetchEmailLink(page.request, user.email, '/reset-password');
  await page.goto(link);
  await expect(page).toHaveURL(/\/reset-password/);
  await page.getByLabel('New password').fill(newPassword);
  await page.getByRole('button', { name: 'Set password' }).click();
  await expect(page).toHaveURL('/login');

  // The new password now works end-to-end.
  await loginAs(page, { email: user.email, password: newPassword });
});
