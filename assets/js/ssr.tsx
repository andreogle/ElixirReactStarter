import './i18n';
import { createInertiaApp } from '@inertiajs/react';
import ReactDOMServer from 'react-dom/server';
import pages from './_ssr_pages.ts';
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
    setup: ({ App, props }) => <App {...props} />,
  });
}
