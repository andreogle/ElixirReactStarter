// biome-ignore-all lint/style/noDoneCallback: node:test passes a TestContext, not a done callback.
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const { createRequire } = require('node:module');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const zlib = require('node:zlib');
const writeFileAtomically = require('./write-file-atomically.cjs');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'asset-race-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const staticDir = path.join(root, 'priv/static');
  const jsDir = path.join(root, 'assets/js');
  fs.mkdirSync(staticDir, { recursive: true });
  fs.mkdirSync(jsDir, { recursive: true });
  return { root, staticDir, jsDir };
}

// Execute the real scripts against isolated files. Hooks exchange paths at
// precisely the check/use boundary, making the races deterministic.
function runScript(root, name, hooks = {}) {
  const script = path.join(__dirname, name);
  const localRequire = createRequire(script);
  const output = [];
  vm.runInNewContext(fs.readFileSync(script, 'utf8'), {
    // biome-ignore lint/style/useNamingConvention: CommonJS global supplied to the script.
    __dirname: path.join(root, 'assets/build'),
    require: (id) => (id === 'node:fs' ? { ...fs, ...hooks } : localRequire(id)),
    console: { log: (message) => output.push(message) },
    process: { stdout: { write: (message) => output.push(message) } },
  });
  return output.join('\n');
}

test('compression preserves size, extension, freshness and stale-output behavior', (t) => {
  const { root, staticDir } = fixture(t);
  const input = 'console.log("asset");\n'.repeat(100);
  const asset = path.join(staticDir, 'app.js');
  fs.writeFileSync(asset, input);
  fs.writeFileSync(path.join(staticDir, 'small.css'), 'body {}');
  fs.writeFileSync(path.join(staticDir, 'image.png'), input);
  assert.match(runScript(root, 'compress-assets.cjs'), /compressed 1 file\(s\), skipped 1/);
  assert.equal(zlib.brotliDecompressSync(fs.readFileSync(`${asset}.br`)).toString(), input);
  const original = fs.statSync(`${asset}.br`);
  assert.match(runScript(root, 'compress-assets.cjs'), /compressed 0 file\(s\), skipped 2/);
  assert.equal(fs.statSync(`${asset}.br`).mtimeMs, original.mtimeMs);
  fs.utimesSync(`${asset}.br`, 1, 1);
  assert.match(runScript(root, 'compress-assets.cjs'), /compressed 1 file\(s\), skipped 1/);
  assert.deepEqual(fs.readdirSync(staticDir).sort(), ['app.js', 'app.js.br', 'image.png', 'small.css']);
});

test('compression reads the inspected file when its path is replaced', (t) => {
  const { root, staticDir } = fixture(t);
  const asset = path.join(staticDir, 'app.js');
  const input = 'original asset\n'.repeat(100);
  fs.writeFileSync(asset, input);
  function replaceAsset(stat) {
    fs.renameSync(asset, `${asset}.old`);
    fs.writeFileSync(asset, 'replacement asset\n'.repeat(100));
    return stat;
  }
  runScript(root, 'compress-assets.cjs', {
    statSync(file) {
      const stat = fs.statSync(file);
      return file === asset ? replaceAsset(stat) : stat;
    },
    fstatSync(fd) {
      return replaceAsset(fs.fstatSync(fd));
    },
  });
  assert.equal(zlib.brotliDecompressSync(fs.readFileSync(`${asset}.br`)).toString(), input);
});

test('compression cannot overwrite a symlink target swapped in after the cache check', (t) => {
  const { root, staticDir } = fixture(t);
  const asset = path.join(staticDir, 'app.js');
  const victim = path.join(root, 'victim');
  fs.writeFileSync(asset, 'asset\n'.repeat(300));
  fs.writeFileSync(`${asset}.br`, 'stale');
  fs.utimesSync(`${asset}.br`, 1, 1);
  fs.writeFileSync(victim, 'untouched');
  function replaceOutput(file, stat) {
    if (file === `${asset}.br`) {
      fs.unlinkSync(file);
      fs.symlinkSync(victim, file);
    }
    return stat;
  }
  runScript(root, 'compress-assets.cjs', {
    statSync(file) {
      return replaceOutput(file, fs.statSync(file));
    },
    lstatSync(file) {
      return replaceOutput(file, fs.lstatSync(file));
    },
  });
  assert.equal(fs.readFileSync(victim, 'utf8'), 'untouched');
  assert.equal(fs.lstatSync(`${asset}.br`).isFile(), true);
});

test('registries are created, unchanged files are preserved, and changed pages are regenerated', (t) => {
  const { root, jsDir } = fixture(t);
  fs.mkdirSync(path.join(jsDir, 'pages/ssr'), { recursive: true });
  fs.writeFileSync(path.join(jsDir, 'pages/ssr/Home.tsx'), 'export default () => null;');
  runScript(root, 'generate-ssr-pages.cjs');
  const client = path.join(jsDir, '_pages.ts');
  const ssr = path.join(jsDir, '_ssr_pages.ts');
  assert.match(fs.readFileSync(client, 'utf8'), /Home: \(\) => import/);
  assert.match(fs.readFileSync(ssr, 'utf8'), /Home: Page0/);
  const original = fs.statSync(client);
  assert.equal(runScript(root, 'generate-ssr-pages.cjs'), '');
  assert.equal(fs.statSync(client).mtimeMs, original.mtimeMs);
  fs.unlinkSync(path.join(jsDir, 'pages/ssr/Home.tsx'));
  runScript(root, 'generate-ssr-pages.cjs');
  assert.doesNotMatch(fs.readFileSync(client, 'utf8'), /Home/);
  assert.doesNotMatch(fs.readFileSync(ssr, 'utf8'), /Home/);
});

test('registry writes cannot follow a symlink swapped in after reading existing content', (t) => {
  const { root, jsDir } = fixture(t);
  const client = path.join(jsDir, '_pages.ts');
  const victim = path.join(root, 'victim');
  fs.writeFileSync(client, 'stale');
  fs.writeFileSync(victim, 'untouched');
  runScript(root, 'generate-ssr-pages.cjs', {
    readFileSync(file, options) {
      const content = fs.readFileSync(file, options);
      if (file === client) {
        fs.unlinkSync(file);
        fs.symlinkSync(victim, file);
      }
      return content;
    },
  });
  assert.equal(fs.readFileSync(victim, 'utf8'), 'untouched');
  assert.equal(fs.lstatSync(client).isFile(), true);
});

test('missing directories are tolerated but other filesystem errors propagate', (t) => {
  const { root, staticDir } = fixture(t);
  fs.rmdirSync(staticDir);
  assert.match(runScript(root, 'compress-assets.cjs'), /compressed 0/);
  runScript(root, 'generate-ssr-pages.cjs');
  const denied = Object.assign(new Error('denied'), { code: 'EACCES' });
  for (const name of ['compress-assets.cjs', 'generate-ssr-pages.cjs']) {
    assert.throws(
      () =>
        runScript(root, name, {
          readdirSync: () => {
            throw denied;
          },
        }),
      denied
    );
  }
  assert.throws(
    () =>
      runScript(root, 'generate-ssr-pages.cjs', {
        readFileSync: () => {
          throw denied;
        },
      }),
    denied
  );
});

test('failed atomic replacement preserves the destination and cleans temporary files', (t) => {
  const { staticDir } = fixture(t);
  const destination = path.join(staticDir, 'destination');
  fs.mkdirSync(destination);
  fs.writeFileSync(path.join(destination, 'keep'), 'untouched');
  assert.throws(() => writeFileAtomically(destination, 'replacement'));
  assert.equal(fs.readFileSync(path.join(destination, 'keep'), 'utf8'), 'untouched');
  assert.deepEqual(fs.readdirSync(staticDir), ['destination']);
});
