import { router } from '@inertiajs/react';
import i18n from '../i18n';

/**
 * Sets i18next language and `<html lang>` from initial page props, and keeps
 * both in sync on subsequent Inertia navigations. Call once during app setup.
 *
 * `<html lang>` needs syncing here because Inertia only swaps the page
 * component — the root layout that server-rendered the attribute is never
 * re-rendered, so after a locale change it would otherwise go stale.
 */
export function syncLocale(initialProps: Record<string, unknown>) {
  applyLocale(initialProps);

  router.on('navigate', (event) => {
    applyLocale(event.detail.page.props);
  });
}

function applyLocale(props: Record<string, unknown>) {
  const locale = props.locale as string | undefined;
  if (!locale) return;

  if (locale !== i18n.language) {
    i18n.changeLanguage(locale);
  }

  if (locale !== document.documentElement.lang) {
    document.documentElement.lang = locale;
  }
}
