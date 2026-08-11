import assert from 'node:assert/strict';
import test from 'node:test';
import { go, goSync } from './result.ts';

test('go returns an error-first tuple for resolved and rejected operations', async () => {
  const success = await go(() => Promise.resolve('ready'));
  const failure = await go(() => Promise.reject(new Error('offline')));

  assert.deepEqual(success, [undefined, 'ready']);
  assert.equal(failure[0]?.message, 'offline');
  assert.equal(failure[1], undefined);
});

test('goSync normalizes thrown non-Error values', () => {
  const [error, value] = goSync(() => {
    throw 'broken';
  });

  assert.equal(error?.message, 'broken');
  assert.equal(error?.cause, 'broken');
  assert.equal(value, undefined);
});
