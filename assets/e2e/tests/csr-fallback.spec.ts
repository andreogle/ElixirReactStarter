import { expect, test } from '../fixtures';

test('an SSR fallback mounts the login page without hydration errors', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') {
      errors.push(message.text());
    }
  });

  // Preserve the real page JSON and its nonce, but replace the rendered
  // body with the empty container sent when production SSR fails.
  await page.route('**/login', async (route) => {
    const response = await route.fetch();
    const body = await response.text();
    const data = body.match(/<script[^>]*data-page="app"[^>]*>[\s\S]*?<\/script>/);
    const rendered = /<div data-server-rendered="true" id="app">[\s\S]*<\/div>(?=\s*(?:<iframe|<\/body>))/;
    expect(data, 'the response carries its page data').not.toBeNull();
    expect(body, 'the response is server-rendered').toMatch(rendered);
    if (!data) {
      throw new Error('Missing Inertia page data');
    }
    const fallback = body.replace(data[0], '').replace(rendered, `<div id="app"></div>${data[0]}`);
    await route.fulfill({ response, body: fallback });
  });

  await page.goto('/login');
  await expect(page.locator('#app')).not.toHaveAttribute('data-server-rendered');
  await expect(page.getByRole('button', { name: 'Log in' })).toBeVisible();
  await page.getByLabel('Email').fill('fallback@example.com');
  await expect(page.getByLabel('Email')).toHaveValue('fallback@example.com');
  expect(errors).toEqual([]);
});
