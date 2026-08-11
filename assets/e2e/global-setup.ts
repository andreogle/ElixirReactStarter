import { execSync } from 'node:child_process';
import path from 'node:path';

/**
 * Reset E2E fixtures before the suite runs.
 *
 * `priv/repo/e2e.exs` is the destructive cleanup script — it wipes
 * per-run `e2e-test-*` users left over from earlier runs so the suite
 * always starts clean. `seeds.exs` is deliberately left alone so it
 * stays safe to run in any environment.
 *
 * Run from the project root, which is two levels up from this file
 * (assets/e2e -> repo root).
 */
export default function globalSetup() {
  const projectRoot = path.resolve(import.meta.dirname, '..', '..');
  execSync('mix run priv/repo/e2e.exs', { cwd: projectRoot, stdio: 'inherit' });
}
