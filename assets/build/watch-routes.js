// Watches the Phoenix router for changes and regenerates the typed frontend
// route table (assets/js/routes.ts) via `mix routes.gen`. Used as a Phoenix
// dev watcher so routes.ts can't go stale while the dev server is running.
//
// Router edits are rare, so shelling out to `mix` (which boots a second BEAM)
// on change is an acceptable cost — and it reuses the exact same generator
// that assets.build and precommit use, so there's only one source of truth.

const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ROOT = path.join(__dirname, '..', '..');
const ROUTER = path.join(ROOT, 'lib', 'elixir_react_starter_web', 'router.ex');

function regenerate() {
  try {
    execFileSync('mix', ['routes.gen'], { cwd: ROOT, stdio: 'inherit' });
  } catch (_) {
    // errors already printed by the child process
  }
}

// Initial generation so a freshly-started server is always in sync.
regenerate();

// fs.watch on the single router file is enough — every route lives there.
require('node:fs').watch(ROUTER, () => regenerate());

// Keep process alive
process.stdin.resume();
