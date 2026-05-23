import { expect, test } from '../fixtures';

test('a visitor can switch the interface language to Spanish', async ({ page }) => {
  await page.goto('/login');

  // English to start: the submit button reads "Log in".
  await expect(page.getByRole('button', { name: 'Log in' })).toBeVisible();

  // Switch via the guest top-bar language menu.
  await page.getByRole('button', { name: 'Change language' }).click();
  await page.getByRole('menuitem', { name: 'Español' }).click();

  // The page reloads in Spanish — the same button now reads "Iniciar sesión".
  await expect(page.getByRole('button', { name: 'Iniciar sesión' })).toBeVisible();
});
