import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.E2E_BASE_URL ?? 'http://localhost:4000';

export default defineConfig({
  testDir: './e2e/tests',
  // Specs mint their own users with unique emails (see e2e/helpers.ts), so
  // the suite is safe to run in parallel. Cap workers so the dev DB and the
  // in-memory mailbox don't get hammered.
  fullyParallel: true,
  workers: process.env.CI ? 2 : 4,
  retries: 0,
  timeout: 30_000,
  // Wipes per-run users from prior runs via priv/repo/e2e.exs.
  globalSetup: './e2e/global-setup.ts',
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
