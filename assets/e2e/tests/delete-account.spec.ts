import { expect, test } from '../fixtures';
import { gotoSettingsViaMenu, loginAs, logoutViaMenu, provisionUser } from '../helpers';

test('a user deletes their account and can no longer sign in', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'delete-account' });

  await loginAs(page, user);
  await gotoSettingsViaMenu(page);

  // Deletion is guarded by a confirmation dialog that re-checks the password.
  await page.getByRole('button', { name: 'Delete my account' }).click();
  const dialog = page.getByRole('alertdialog');
  await dialog.getByLabel('Password', { exact: true }).fill(user.password);
  await dialog.getByRole('button', { name: 'Delete account' }).click();

  // The session is cleared and the visitor lands back on the marketing home.
  await expect(page).toHaveURL('/');
  // .first(): flash toasts are mirrored into an aria-live region.
  await expect(page.getByText('Your account has been deleted.').first()).toBeVisible();

  // The account is gone: the old credentials no longer authenticate, and
  // protected pages bounce to /login.
  await page.goto('/login');
  await page.getByLabel('Email').fill(user.email);
  await page.getByLabel('Password').fill(user.password);
  await page.getByRole('button', { name: 'Log in' }).click();
  await expect(page).toHaveURL('/login');
  await expect(page.getByText(/invalid email or password/i)).toBeVisible();

  await page.goto('/dashboard');
  await expect(page).toHaveURL('/login');
});

test('deleting with the wrong password is rejected and leaves the account intact', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'delete-account-badpw' });

  await loginAs(page, user);
  await gotoSettingsViaMenu(page);

  await page.getByRole('button', { name: 'Delete my account' }).click();
  const dialog = page.getByRole('alertdialog');
  await dialog.getByLabel('Password', { exact: true }).fill('not-my-password');
  await dialog.getByRole('button', { name: 'Delete account' }).click();

  // The dialog stays open with the error; nothing was deleted.
  await expect(page).toHaveURL('/settings');
  await expect(dialog.getByText('Incorrect password')).toBeVisible();
  await dialog.getByRole('button', { name: 'Cancel' }).click();

  // Account survived: sign out and back in with the original credentials.
  await logoutViaMenu(page);
  await loginAs(page, user);
});
