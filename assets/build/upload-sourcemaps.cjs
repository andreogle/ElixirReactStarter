// Uploads the built browser source maps to Sentry, then deletes every
// `.map` file so they're never digested by `phx.digest` or served by
// Plug.Static (publishing them would leak source). `sourcemaps inject`
// stamps a debug ID into each .js and its .map, so Sentry pairs minified
// frames with the original source regardless of the later phx.digest rename.
//
// Runs inside `mix assets.deploy`, after the minified esbuild build and
// before `phx.digest`.
//
// Resilience: the upload is best-effort. If credentials are missing it's
// skipped, and if the upload errors it warns but does NOT fail the build —
// a source-map hiccup shouldn't block a deploy (the app ships fine, you
// just get minified stack traces). Either way the `.map` files are removed
// so they never reach the served bundle.

const fs = require('node:fs');
const path = require('node:path');
const { SentryCli } = require('@sentry/cli');

const ASSETS_DIR = path.join(__dirname, '..', '..', 'priv', 'static', 'assets');

const authToken = process.env.SENTRY_AUTH_TOKEN;
const org = process.env.SENTRY_ORG;
const project = process.env.SENTRY_PROJECT;
// Tag the upload with the deploy's commit SHA (Render's RENDER_GIT_COMMIT)
// so it matches the release runtime events report. Source maps still
// resolve without it — the injected debug IDs are what Sentry matches on.
const release = process.env.SENTRY_RELEASE || process.env.RENDER_GIT_COMMIT;

async function uploadSourceMaps() {
  const cli = new SentryCli(null, { authToken });

  // Inject must run before upload: it stamps a debug ID into each .js and
  // its .map so Sentry can pair minified frames with the original source.
  await cli.execute(['sourcemaps', 'inject', ASSETS_DIR], true);

  const uploadArgs = ['sourcemaps', 'upload', '--org', org, '--project', project];
  if (release) uploadArgs.push('--release', release);
  uploadArgs.push(ASSETS_DIR);
  await cli.execute(uploadArgs, true);
}

function deleteSourceMaps(dir) {
  let deleted = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      deleted += deleteSourceMaps(full);
    } else if (entry.name.endsWith('.map')) {
      fs.rmSync(full);
      deleted++;
    }
  }
  return deleted;
}

async function main() {
  if (authToken && org && project) {
    // Build scripts run outside the app's `go()` convention; a try/catch at
    // this top-level boundary keeps an upload failure from failing the build.
    try {
      await uploadSourceMaps();
      process.stdout.write('sentry: uploaded source maps\n');
    } catch (error) {
      process.stderr.write(`sentry: source map upload failed (continuing): ${error?.message || error}\n`);
    }
  } else {
    process.stdout.write('sentry: SENTRY_AUTH_TOKEN/ORG/PROJECT not set — skipping source map upload\n');
  }

  // Always remove the .map files so they're never digested or served,
  // whether the upload ran, was skipped, or failed.
  const deleted = deleteSourceMaps(ASSETS_DIR);
  process.stdout.write(`sentry: removed ${deleted} .map file(s) from the served bundle\n`);
}

main();
