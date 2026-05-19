import './i18n';
import { createInertiaApp } from '@inertiajs/react';
import { createElement } from 'react';
import ReactDOMServer from 'react-dom/server';
import pages from './_ssr_pages.ts';
import { AppProviders } from './app-providers';
import i18n from './i18n';

// Called by Elixir's Inertia.SSR Node.js worker pool with the page
// protocol payload. The shape varies per page and is supplied by
// Inertia itself, not by our own code, so it's opaque on the Node side.
// biome-ignore lint/suspicious/noExplicitAny: protocol-level payload from Inertia
export function render(page: any) {
  // Sync locale before rendering so SSR output matches
  const locale = page.props?.locale as string | undefined;
  if (locale && locale !== i18n.language) {
    i18n.changeLanguage(locale);
  }

  return createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    resolve: (name) => {
      const component = pages[name];
      if (!component) {
        throw new Error(`SSR page not found: ${name}`);
      }
      return component;
    },
    // Mirror the client wrapping (see app.tsx): page components are
    // rendered inside AppProviders so context-dependent components
    // (Tooltip, etc.) work during SSR. Side-effect providers like
    // RealtimeProvider are safe — their useEffect doesn't run server-side.
    setup: ({ App, props }) => (
      <App {...props}>
        {({ Component, props: pageProps, key }) => (
          <AppProviders>{createElement(Component, { key: key ?? undefined, ...pageProps })}</AppProviders>
        )}
      </App>
    ),
  });
}
