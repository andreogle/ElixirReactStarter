import { router } from '@inertiajs/react';
import i18n from '../i18n';

/**
 * Sets i18next language from initial page props and keeps it in sync
 * on subsequent Inertia navigations. Call once during app setup.
 */
export function syncLocale(initialProps: Record<string, unknown>) {
  applyLocale(initialProps);

  router.on('navigate', (event) => {
    applyLocale(event.detail.page.props);
  });
}

function applyLocale(props: Record<string, unknown>) {
  const locale = props.locale as string | undefined;

  if (locale && locale !== i18n.language) {
    i18n.changeLanguage(locale);
  }
}
