// Watches assets/js/pages/ for added/removed .tsx files and regenerates the
// SSR pages registry. Used as a Phoenix dev watcher.

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const PAGES_DIR = path.join(__dirname, '..', 'js', 'pages');
const GENERATE = path.join(__dirname, 'generate-ssr-pages.js');

function regenerate() {
  try {
    execFileSync(process.execPath, [GENERATE], { stdio: 'inherit' });
  } catch (_) {
    // errors already printed by the child process
  }
}

// Initial generation
regenerate();

// Watch for changes (recursive)
fs.watch(PAGES_DIR, { recursive: true }, (_event, filename) => {
  if (filename?.endsWith('.tsx')) {
    regenerate();
  }
});

// Keep process alive
process.stdin.resume();
