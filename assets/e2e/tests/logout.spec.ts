import { expect, test } from '../fixtures';
import { loginAs, logoutViaMenu, provisionUser } from '../helpers';

test('a signed-in user logs out from the header menu and loses access to the dashboard', async ({ page, request }) => {
  const user = await provisionUser(request, { label: 'logout' });
  await loginAs(page, user);

  await logoutViaMenu(page);

  // The session is gone: a protected page now bounces to /login.
  await page.goto('/dashboard');
  await expect(page).toHaveURL('/login');
});
