// Walks priv/static and writes a `.br` (Brotli) sibling next to every
// compressible text asset. `phx.digest` already writes the `.gz` siblings;
// this script adds the brotli half so `Plug.Static` can pick whichever the
// request accepts.
//
// Only run as part of `mix assets.deploy` — dev builds don't need
// pre-compression because `code_reloading?` skips encoding selection.

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const ROOT = path.join(__dirname, '..', '..', 'priv', 'static');
const COMPRESSIBLE = new Set(['.js', '.css', '.svg', '.json', '.txt', '.html', '.xml', '.map']);
// Quality 11 is the max. Slower at build time but a one-time cost per
// deploy, and users pay the cost on every request in payload bytes.
const QUALITY = 11;
// Skip files smaller than ~1 KiB — the brotli header overhead makes them
// larger than the original in many cases.
const MIN_SIZE = 1024;

let compressed = 0;
let skipped = 0;
let savedBytes = 0;

function walk(dir) {
  if (!fs.existsSync(dir)) return;

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full);
    } else {
      maybeCompress(full);
    }
  }
}

function maybeCompress(file) {
  if (file.endsWith('.gz') || file.endsWith('.br')) return;

  const ext = path.extname(file);
  if (!COMPRESSIBLE.has(ext)) return;

  const stat = fs.statSync(file);
  if (stat.size < MIN_SIZE) {
    skipped++;
    return;
  }

  const outPath = `${file}.br`;

  // Skip if an up-to-date `.br` already exists.
  if (fs.existsSync(outPath)) {
    const outStat = fs.statSync(outPath);
    if (outStat.mtimeMs >= stat.mtimeMs) {
      skipped++;
      return;
    }
  }

  const input = fs.readFileSync(file);
  const br = zlib.brotliCompressSync(input, {
    params: {
      [zlib.constants.BROTLI_PARAM_QUALITY]: QUALITY,
      [zlib.constants.BROTLI_PARAM_SIZE_HINT]: input.length,
    },
  });

  fs.writeFileSync(outPath, br);
  compressed++;
  savedBytes += input.length - br.length;
}

walk(ROOT);

const savedKb = (savedBytes / 1024).toFixed(1);
process.stdout.write(`brotli: compressed ${compressed} file(s), skipped ${skipped}, saved ${savedKb} KB\n`);
