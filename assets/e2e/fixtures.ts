import { test as base, expect, type Page } from '@playwright/test';

/**
 * Suite-wide Playwright fixtures.
 *
 * Specs `import { expect, test } from '../fixtures'` (never directly from
 * `@playwright/test`). The custom `page` fixture wraps `page.goto` so that
 * every navigation auto-waits for client-side hydration to finish — the
 * single most common cause of flake in an SSR + React app.
 *
 * Why this exists (see assets/js/app-providers.tsx for the matching signal):
 * every page is server-rendered. Until React parses, mounts, and runs its
 * effects, controlled inputs haven't reconciled with SSR markup and form
 * `onSubmit` handlers aren't attached. A `fill` + submit-click in that
 * window quietly hits the native path: the value gets blown away when
 * React mounts with `value=""`, and the submit either does nothing or
 * fires as a native GET to the current URL with empty fields → server
 * validation fails → redirect back to the form. The symptom is "the form
 * did nothing." Wrapping `goto` here means every spec is safe by default
 * — you can't forget. Subsequent intra-app navigation goes through
 * Inertia (no full reload) with AppProviders still mounted, so the
 * hydration flag remains set and no further waits are needed.
 */

async function waitForHydration(page: Page): Promise<void> {
  await page.waitForSelector('html[data-hydrated="true"]', { state: 'attached' });
}

export const test = base.extend({
  page: async ({ page }, use) => {
    const originalGoto = page.goto.bind(page);
    page.goto = async (url, opts) => {
      const response = await originalGoto(url, opts);
      await waitForHydration(page);
      return response;
    };
    await use(page);
  },
});

export { expect };
