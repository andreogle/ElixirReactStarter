import os from 'node:os';
import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.E2E_BASE_URL ?? 'http://localhost:4000';
const CI = Boolean(process.env.CI);

// How many browsers drive the one dev server at once. Every test mints its
// own accounts (see e2e/helpers.ts), so tests can't collide whatever this
// is. The limit is the server: every worker adds a browser, server renders
// and database work on the same machine, and an overloaded server is what
// turns slow-but-correct into timeouts. Half the cores, at most 3, leaves
// the server room on a laptop. CI's runners are small and also host
// Postgres and Phoenix, so 2. Set E2E_WORKERS to override, e.g. 1 to rule
// load out when chasing a failure.
const defaultWorkers = CI ? 2 : Math.min(3, Math.max(1, Math.floor(os.cpus().length / 2)));
const workers = Number(process.env.E2E_WORKERS) || defaultWorkers;

export default defineConfig({
  testDir: './e2e/tests',
  // Files run in parallel; the tests inside a file run one after another.
  // That spreads load evenly instead of starting every test at once.
  fullyParallel: false,
  workers,
  // One retry on CI, so a rare infrastructure hiccup doesn't fail a build.
  // A test that only passes on retry is reported as flaky, not hidden: fix
  // it, don't rely on the retry. None locally, so flakiness shows.
  retries: CI ? 1 : 0,
  // Generous enough for a slow machine; a hung test still fails well within
  // a run, since actions and navigations have their own, shorter bounds.
  timeout: CI ? 120_000 : 60_000,
  expect: { timeout: CI ? 15_000 : 10_000 },
  // Wipes accounts an interrupted earlier run left behind (priv/repo/e2e.exs).
  globalSetup: './e2e/global-setup.ts',
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: BASE_URL,
    // Navigation and actions get their own bound, so a stuck click fails
    // with a clear message instead of eating the whole test timeout.
    actionTimeout: CI ? 30_000 : 15_000,
    navigationTimeout: CI ? 45_000 : 30_000,
    trace: CI ? 'on-first-retry' : 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
