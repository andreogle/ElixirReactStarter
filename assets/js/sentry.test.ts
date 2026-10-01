import assert from 'node:assert/strict';
import test, { after, mock } from 'node:test';
import * as Sentry from '@sentry/react';
import { userFromProps } from './sentry-config.ts';

after(async () => {
  await Sentry.close();
  Reflect.deleteProperty(globalThis, 'document');
  Reflect.deleteProperty(globalThis, 'location');
  for (const name of ['addEventListener', 'removeEventListener', 'requestIdleCallback']) {
    Reflect.deleteProperty(globalThis, name);
  }
});

test('browser initialization limits collection and tracks only the current user ID', async () => {
  for (const name of ['addEventListener', 'removeEventListener', 'requestIdleCallback']) {
    Object.defineProperty(globalThis, name, { configurable: true, value: mock.fn() });
  }
  Object.defineProperty(globalThis, 'location', {
    configurable: true,
    value: { href: 'https://example.com/login?email=private@example.com' },
  });
  // Minimal document for the meta-tag reader and SDK's visibility listener.
  Object.defineProperty(globalThis, 'document', {
    configurable: true,
    value: {
      querySelector: (selector: string) =>
        selector === 'meta[name="sentry-dsn"]' ? { content: 'https://key@example.com/1' } : null,
      addEventListener: mock.fn(),
      referrer: 'https://example.com/confirm-email?token=private-token',
    },
  });
  const { identifyViewer, captureException } = await import('./sentry.ts');
  const options = Sentry.getClient()?.getOptions();
  assert.equal(options?.dataCollection?.userInfo, false);
  assert.equal(options?.dataCollection?.cookies, false);
  assert.equal(options?.dataCollection?.httpHeaders, false);
  assert.equal(options?.dataCollection?.urlQueryParams, false);
  assert.deepEqual(options?.dataCollection?.httpBodies, []);
  assert.equal(options?.dataCollection?.stackFrameVariables, false);
  assert.equal(options?.tracesSampleRate, undefined);

  identifyViewer({ current_user: { id: 'user-1', email: 'private@example.com', name: 'Private' } });
  assert.deepEqual(Sentry.getIsolationScope().getUser(), { id: 'user-1' });

  const transport = Sentry.getClient()?.getTransport();
  assert.ok(transport);
  const send = mock.method(transport, 'send', async () => ({ statusCode: 200 }));
  captureException(new Error('test failure'));
  await Sentry.flush();
  assert.equal(send.mock.callCount(), 1);
  const payload = JSON.stringify(send.mock.calls[0].arguments);
  assert.ok(payload.includes('user-1'));
  assert.ok(payload.includes('test failure'));
  assert.ok(!payload.includes('private@example.com'));
  assert.ok(!payload.includes('private-token'));

  identifyViewer({ flash: {} });
  assert.deepEqual(Sentry.getIsolationScope().getUser(), { id: 'user-1' });

  identifyViewer({ current_user: { id: 'user-2' } });
  assert.deepEqual(Sentry.getIsolationScope().getUser(), { id: 'user-2' });

  identifyViewer({ current_user: null });
  assert.equal(Sentry.getIsolationScope().getUser().id, undefined);
});

test('SSR identity is derived independently for each page without other user fields', () => {
  assert.deepEqual(userFromProps({ current_user: { id: 'user-1', email: 'private@example.com' } }), { id: 'user-1' });
  assert.equal(userFromProps({ current_user: null }), null);
  assert.equal(userFromProps({}), undefined);
  assert.deepEqual(userFromProps({ current_user: { id: 'user-2' } }), { id: 'user-2' });
});
