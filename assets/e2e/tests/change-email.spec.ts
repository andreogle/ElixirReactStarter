import { expect, test } from '../fixtures';
import { fetchEmailLink, gotoSettingsViaMenu, loginAs, logoutViaMenu, provisionUser, uniqueEmail } from '../helpers';

test('a user changes their email, confirms via the link to the new inbox, and logs in with it', async ({
  page,
  request,
}) => {
  const user = await provisionUser(request, { label: 'change-email' });
  const newEmail = uniqueEmail('change-email-new');

  await loginAs(page, user);
  await gotoSettingsViaMenu(page);

  // Request the change — the record isn't touched until the link is opened.
  const emailSection = page.locator('section').filter({ has: page.getByRole('heading', { name: 'Change email' }) });
  await emailSection.getByLabel('New email').fill(newEmail);
  await emailSection.getByLabel('Current password').fill(user.password);
  await emailSection.getByRole('button', { name: 'Send confirmation link' }).click();

  await expect(page).toHaveURL('/settings');
  // .first(): the flash renders as a toast, which Radix mirrors into an
  // aria-live region, so the text appears twice in the DOM.
  await expect(page.getByText(/Check your new inbox/).first()).toBeVisible();

  // The confirmation link goes to the NEW address. Open it while still
  // signed in to apply the change.
  const link = await fetchEmailLink(page.request, newEmail, '/settings/email/apply-change');
  await page.goto(link);
  await expect(page).toHaveURL('/settings');
  await expect(page.getByText('Your email address has been updated.').first()).toBeVisible();

  // The new address is now the account email end-to-end: it shows on the
  // settings page and logs in (sign out first — the session is still live).
  await expect(page.getByRole('main').getByText(newEmail)).toBeVisible();
  await logoutViaMenu(page);
  await loginAs(page, { email: newEmail, password: user.password });
});

test('changing email with the wrong current password is rejected', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'change-email-badpw' });
  const newEmail = uniqueEmail('change-email-badpw-new');

  await loginAs(page, user);
  await gotoSettingsViaMenu(page);

  const emailSection = page.locator('section').filter({ has: page.getByRole('heading', { name: 'Change email' }) });
  await emailSection.getByLabel('New email').fill(newEmail);
  await emailSection.getByLabel('Current password').fill('not-the-real-password');
  await emailSection.getByRole('button', { name: 'Send confirmation link' }).click();

  // Inline field error (not a toast) — the change never took effect.
  await expect(page).toHaveURL('/settings');
  await expect(emailSection.getByText('Incorrect password')).toBeVisible();

  // The original email still logs in (sign out first — still authenticated).
  await logoutViaMenu(page);
  await loginAs(page, user);
});
