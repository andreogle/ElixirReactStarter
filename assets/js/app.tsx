import './i18n';
import { go } from '@api3/promise-utils';
import { createInertiaApp, router } from '@inertiajs/react';
import { createElement, StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { AppProviders } from './app-providers';
import { syncLocale } from './components/LocaleSync';
import Toaster from './components/Toaster';
import { toast } from './components/toast';
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

createInertiaApp({
  resolve: async (name) => {
    const result = await go(() => import(`./pages/${name}.tsx`));
    if (!result.success) {
      console.error(`Failed to load page "${name}":`, result.error);
      throw result.error;
    }
    return result.data;
  },
  setup({ App, el, props }) {
    syncLocale(props.initialPage.props);
    startThemeWatcher();

    // Initial page load: the server embeds flash directly in initialPage props.
    applyFlash(props.initialPage.props.flash as Flash | undefined);

    // Client-initiated visits: `success` fires for every successful visit,
    // including same-URL POST → redirect flows (where `navigate` is skipped
    // because Inertia treats same-URL responses as history replace).
    router.on('success', (event) => {
      applyFlash(event.detail.page.props.flash as Flash | undefined);
    });

    createRoot(el).render(
      <StrictMode>
        {/* AppProviders lives INSIDE Inertia's <App> because the providers
            it wraps consume page context (usePage). Using App's children
            render prop keeps the provider tree mounted across page
            navigations — only the inner <Component> swaps — so anything
            long-lived (sockets, caches, listeners) survives route changes. */}
        <App {...props}>
          {({ Component, props: pageProps, key }) => (
            <AppProviders>{createElement(Component, { key: key ?? undefined, ...pageProps })}</AppProviders>
          )}
        </App>
        <Toaster />
      </StrictMode>
    );
  },
  http: {
    xsrfHeaderName: 'x-csrf-token',
  },
});
