'use strict';

const fs = require('node:fs');
const path = require('node:path');

// Keep the temporary file on the same filesystem so rename is atomic.
// Replacing the directory entry also avoids following an output symlink.
module.exports = function writeFileAtomically(file, content) {
  const dir = fs.mkdtempSync(path.join(path.dirname(file), '.asset-write-'));
  const temporary = path.join(dir, 'output');
  try {
    const fd = fs.openSync(temporary, 'wx');
    try {
      fs.writeFileSync(fd, content);
    } finally {
      fs.closeSync(fd);
    }
    fs.renameSync(temporary, file);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
};
