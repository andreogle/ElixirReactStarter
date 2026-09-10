import { expect, test } from '../fixtures';
import { gotoSettingsViaMenu, loginAs, logoutViaMenu, provisionUser } from '../helpers';

function passwordSection(page: import('@playwright/test').Page) {
  return page.locator('section').filter({ has: page.getByRole('heading', { name: 'Change password' }) });
}

test('a user changes their password and can log in with the new one', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'change-password' });
  const newPassword = 'rotated-password-789';

  await loginAs(page, user);
  await gotoSettingsViaMenu(page);

  const section = passwordSection(page);
  await section.getByLabel('Current password').fill(user.password);
  await section.getByLabel('New password').fill(newPassword);
  await section.getByRole('button', { name: 'Update password' }).click();

  // Stays on settings (the current browser keeps its session) with a flash.
  await expect(page).toHaveURL('/settings');
  // .first(): flash toasts are mirrored into an aria-live region.
  await expect(page.getByText('Password updated.').first()).toBeVisible();

  // Old password no longer works; the new one does.
  await logoutViaMenu(page);
  await page.goto('/login');
  await page.getByLabel('Email').fill(user.email);
  await page.getByLabel('Password').fill(user.password);
  await page.getByRole('button', { name: 'Log in' }).click();
  await expect(page).toHaveURL('/login');
  await expect(page.getByText(/invalid email or password/i)).toBeVisible();

  await loginAs(page, { email: user.email, password: newPassword });
});

test('changing the password with the wrong current password is rejected', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'change-password-badpw' });

  await loginAs(page, user);
  await gotoSettingsViaMenu(page);

  const section = passwordSection(page);
  await section.getByLabel('Current password').fill('wrong-current-password');
  await section.getByLabel('New password').fill('whatever-new-password-1');
  await section.getByRole('button', { name: 'Update password' }).click();

  await expect(page).toHaveURL('/settings');
  await expect(section.getByText('is incorrect')).toBeVisible();

  // Original password still logs in — nothing changed.
  await logoutViaMenu(page);
  await loginAs(page, user);
});
