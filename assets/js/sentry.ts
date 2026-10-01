import * as Sentry from '@sentry/react';
import { dataCollection, userFromProps } from './sentry-config.ts';

// Read config the server stamped into <head> (see root.html.heex). The
// tags are absent unless SENTRY_DSN_FRONTEND is set, so dev and any
// unconfigured deploy skip init and the SDK stays a no-op.
function metaContent(name: string): string | undefined {
  return document.querySelector<HTMLMetaElement>(`meta[name="${name}"]`)?.content || undefined;
}

const dsn = metaContent('sentry-dsn');

// Errors only: no `tracesSampleRate`, no replay integration. init()
// auto-registers the global `window.onerror` / `unhandledrejection`
// handlers, so uncaught errors and rejected promises are captured without
// further wiring; ErrorBoundary reports the render-tree errors it catches.
if (dsn) {
  Sentry.init({
    dsn,
    environment: metaContent('sentry-environment'),
    release: metaContent('sentry-release'),
    dataCollection,
  });
}

export const sentryEnabled = dsn !== undefined;

/** Follow the current page's user without copying email or other props. */
export function identifyViewer(props: Record<string, unknown>): void {
  if (!sentryEnabled) {
    return;
  }
  const user = userFromProps(props);
  if (user !== undefined) {
    Sentry.setUser(user);
  }
}

/** Report a caught exception. No-op when Sentry isn't configured. */
export function captureException(error: unknown, context?: Record<string, unknown>): void {
  if (sentryEnabled) {
    Sentry.captureException(error, context ? { extra: context } : undefined);
  }
}
