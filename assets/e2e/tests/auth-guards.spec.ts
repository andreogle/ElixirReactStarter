import { expect, test } from '../fixtures';
import { loginAs, provisionUser } from '../helpers';

// The router splits routes into public, guest-only
// (redirect_if_user_is_authenticated), and authenticated
// (require_authenticated_user) pipelines. These specs prove the guards
// fire from a real browser, not just in controller tests.

test.describe('anonymous visitors are kept out of authenticated pages', () => {
  for (const path of ['/dashboard', '/settings']) {
    test(`visiting ${path} signed out redirects to /login`, async ({ page }) => {
      await page.goto(path);
      await expect(page).toHaveURL('/login');
    });
  }
});

test.describe('signed-in users are kept out of guest-only pages', () => {
  for (const path of ['/login', '/register', '/forgot-password']) {
    test(`visiting ${path} while signed in redirects to /dashboard`, async ({ page, request }) => {
      const user = await provisionUser(request, { label: 'guard' });
      await loginAs(page, user);

      await page.goto(path);
      await expect(page).toHaveURL('/dashboard');
    });
  }
});
