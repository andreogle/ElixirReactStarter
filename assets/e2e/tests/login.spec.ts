import { expect, test } from '../fixtures';
import { loginAs, provisionUser } from '../helpers';

test('a confirmed user logs in and reaches the dashboard', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'login' });

  await loginAs(page, user);

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  // Email also appears in the header user menu — scope to the page body.
  await expect(page.getByRole('main').getByText(user.email)).toBeVisible();
});

test('the login form rejects bad credentials with a visible error', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'badcreds' });

  await page.goto('/login');
  await page.getByLabel('Email').fill(user.email);
  await page.getByLabel('Password').fill('definitely-wrong-password');
  await page.getByRole('button', { name: 'Log in' }).click();

  // Stays on /login with an error rendered next to the form.
  await expect(page).toHaveURL('/login');
  await expect(page.getByText(/invalid email or password/i)).toBeVisible();
});
