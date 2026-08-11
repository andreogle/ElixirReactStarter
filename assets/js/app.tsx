// Init Sentry first so its global error handlers are installed before any
// other module can throw. No-op unless a DSN was stamped into <head>.
import './sentry';
import './i18n';
import { createInertiaApp, router } from '@inertiajs/react';
import { createElement, StrictMode, useEffect } from 'react';
import { createRoot, hydrateRoot } from 'react-dom/client';
import pages, { serverRenderedPages } from './_pages';
import { AppProviders } from './app-providers';
import ErrorBoundary from './components/ErrorBoundary';
import { syncLocale } from './components/LocaleSync';
import Toaster from './components/Toaster';
import { toast } from './components/toast';
import { go } from './result';
import { startThemeWatcher } from './theme';

interface Flash {
  info?: string;
  error?: string;
}

function applyFlash(flash?: Flash) {
  if (!flash) return;
  if (flash.info) toast.success(flash.info);
  if (flash.error) toast.error(flash.error);
}

// Guards against StrictMode's deliberate double-invocation of effects in
// dev, which would otherwise raise the same flash twice.
let initialFlashApplied = false;

/**
 * Raises the flash from the *initial* page load, from an effect.
 *
 * Toasts live in a store outside React, so queueing one before the first
 * render would put a toast in the client's tree that the server never
 * rendered — a hydration mismatch, and React would discard the
 * server-rendered DOM it was meant to adopt. Effects run after the
 * hydration commit, so the toast arrives in a follow-up render instead.
 *
 * Renders nothing, so it costs no DOM on either side.
 */
function InitialFlash({ flash }: { flash?: Flash }) {
  useEffect(() => {
    if (initialFlashApplied) return;
    initialFlashApplied = true;
    applyFlash(flash);
  }, [flash]);

  return null;
}

const startApp = () => {
  return createInertiaApp({
    resolve: async (name) => {
      const loader = pages[name];
      if (!loader) {
        const error = new Error(`Page not found: ${name}`);
        console.error(error);
        throw error;
      }

      const [error, page] = await go(loader);
      if (error) {
        console.error(`Failed to load page "${name}":`, error);
        throw error;
      }
      return page.default;
    },
    setup({ App, el, props }) {
      syncLocale(props.initialPage.props);
      startThemeWatcher();

      // Dev-only accessibility auditing. The whole branch — and axe-core —
      // is tree-shaken from the production bundle via the NODE_ENV define.
      if (process.env.NODE_ENV !== 'production') {
        void go(() => import('./a11y-audit')).then(([error, audit]) => {
          if (error) {
            console.error('Failed to load the accessibility audit:', error);
            return;
          }
          audit.startA11yAudit();
        });
      }

      // Client-initiated visits: `success` fires for every successful visit,
      // including same-URL POST → redirect flows (where `navigate` is skipped
      // because Inertia treats same-URL responses as history replace).
      router.on('success', (event) => {
        applyFlash(event.detail.page.props.flash as Flash | undefined);
      });

      const tree = (
        <StrictMode>
          {/* AppProviders lives INSIDE Inertia's <App> because the providers
            it wraps consume page context (usePage). Using App's children
            render prop keeps the provider tree mounted across page
            navigations — only the inner <Component> swaps — so anything
            long-lived (sockets, caches, listeners) survives route changes. */}
          <App {...props}>
            {({ Component, props: pageProps, key }) => (
              <AppProviders>
                {/* Keyed on the page key so navigation remounts the boundary
                  and clears any caught error — long-lived providers above
                  stay mounted. */}
                <ErrorBoundary key={key ?? undefined}>{createElement(Component, pageProps)}</ErrorBoundary>
              </AppProviders>
            )}
          </App>
          <InitialFlash flash={props.initialPage.props.flash as Flash | undefined} />
          <Toaster />
        </StrictMode>
      );

      // Match the mount to how the page was actually produced.
      //
      // For a `pages/ssr/` page the server sent real markup, which the browser
      // has already parsed and painted; `hydrateRoot` adopts it, where
      // `createRoot` clears the container and builds the whole tree again. It
      // also surfaces divergence between the two renders, which the silent
      // rebuild never did.
      //
      // A `pages/client/` page is deliberately absent from the SSR bundle and
      // renders as a server-side no-op, so there is nothing to adopt. Hydrating
      // one fails the match on every load and pushes React through its recovery
      // path to reach the same result `createRoot` reaches directly.
      //
      // Both branches render the identical tree — only the mount differs. This
      // is also why `ssr.tsx` renders `<Toaster />`: anything at the root on one
      // side but not the other is a mismatch.
      if (serverRenderedPages.has(props.initialPage.component)) {
        hydrateRoot(el, tree);
      } else {
        createRoot(el).render(tree);
      }
    },
    http: {
      xsrfHeaderName: 'x-csrf-token',
    },
  });
};

void go(startApp).then(([error]) => {
  if (error) console.error('Failed to start the application:', error);
});
