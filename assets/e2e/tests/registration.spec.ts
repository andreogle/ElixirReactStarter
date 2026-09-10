import { expect, test } from '../fixtures';
import { fetchEmailLink, uniqueEmail } from '../helpers';

test('a visitor registers, confirms via the email link, and lands on the dashboard', async ({ page }) => {
  const email = uniqueEmail('registration');
  const password = 'playwright-password-123';

  // Enter the auth flow from the marketing home.
  await page.goto('/');
  await page.getByRole('link', { name: 'Create account' }).click();
  await expect(page).toHaveURL('/register');

  // Sign-up is email + password only (the User schema is minimal).
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password').fill(password);
  await page.getByRole('button', { name: 'Create account' }).click();

  // Registration sends a confirmation link and bounces to /login.
  await expect(page).toHaveURL('/login');

  // Pull the confirmation link out of the dev mailbox and follow it.
  const link = await fetchEmailLink(page.request, email, '/confirm-email');
  await page.goto(link);

  // Confirming logs the user in and drops them on the dashboard.
  await expect(page).toHaveURL('/dashboard');
  // Email also appears in the header user menu — scope to the page body.
  await expect(page.getByRole('main').getByText(email)).toBeVisible();
});
