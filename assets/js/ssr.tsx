import './i18n';
import { go } from '@api3/promise-utils';
import { createInertiaApp } from '@inertiajs/react';
import * as Sentry from '@sentry/node';
import { createElement } from 'react';
import ReactDOMServer from 'react-dom/server';
import pages, { ssrClientOnly } from './_ssr_pages.ts';
import { AppProviders } from './app-providers';
import Toaster from './components/Toaster';
import i18n from './i18n';

// Sentry for the SSR Node workers (errors only — no tracing). The DSN is
// inherited from the BEAM's environment; falls back to the frontend DSN
// since SSR runs the same React code. No-op unless a DSN is set.
const sentryDsn = process.env.SENTRY_DSN_SSR || process.env.SENTRY_DSN_FRONTEND;
if (sentryDsn) {
  Sentry.init({
    dsn: sentryDsn,
    environment: process.env.DEPLOY_ENV || 'production',
    release: process.env.SENTRY_RELEASE || process.env.RENDER_GIT_COMMIT,
  });
}

// Called by Elixir's Inertia.SSR Node.js worker pool with the page
// protocol payload. The shape varies per page and is supplied by
// Inertia itself, not by our own code, so it's opaque on the Node side.
// biome-ignore lint/suspicious/noExplicitAny: protocol-level payload from Inertia
export async function render(page: any) {
  // Sync locale before rendering so SSR output matches
  const locale = page.props?.locale as string | undefined;
  if (locale && locale !== i18n.language) {
    void go(() => i18n.changeLanguage(locale));
  }

  const renderApp = () => {
    return createInertiaApp({
      page,
      render: ReactDOMServer.renderToString,
      resolve: (name) => {
        const component = pages[name];
        if (component) return component;
        // Client-only pages (pages/client/*) aren't in the SSR bundle. Render
        // nothing server-side and let the client take over, rather than failing
        // the render. A genuinely unknown name still throws.
        if (ssrClientOnly.has(name)) return () => null;
        throw new Error(`SSR page not found: ${name}`);
      },
      // Mirror the client wrapping (see app.tsx): page components are
      // rendered inside AppProviders so context-dependent components
      // (Tooltip, etc.) work during SSR. Side-effect providers like
      // RealtimeProvider are safe — their useEffect doesn't run server-side.
      //
      // `Toaster` is here for hydration, not for output: it renders an empty
      // Radix viewport element, and the client hydrates rather than rebuilds,
      // so anything the client renders at the root must exist here too or
      // React finds unexpected DOM and discards the subtree. Toasts are
      // always client-side — the store is empty server-side, so this emits
      // the viewport and nothing else.
      setup: ({ App, props }) => (
        <>
          <App {...props}>
            {({ Component, props: pageProps, key }) => (
              <AppProviders>{createElement(Component, { key: key ?? undefined, ...pageProps })}</AppProviders>
            )}
          </App>
          <Toaster />
        </>
      ),
    });
  };

  const result = await go(renderApp);

  // Report the failure, then re-raise so Inertia's own SSR-failure handling
  // runs unchanged (graceful client-side fallback in prod, raise in dev per
  // `raise_on_ssr_failure`).
  if (!result.success) {
    if (sentryDsn) Sentry.captureException(result.error);
    throw result.error;
  }

  return result.data;
}
