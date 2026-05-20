/**
 * Theme persistence + application.
 *
 * Modes:
 *  - 'light'  → force light mode
 *  - 'dark'   → force dark mode
 *  - 'system' → follow the OS `prefers-color-scheme` and react to changes
 *
 * Storage: a `theme` cookie (1-year). Cookie is the right primitive
 * (not localStorage) so the root layout's inline bootstrap script can
 * read it on first paint and avoid a flash of the wrong theme.
 */

export type Theme = 'light' | 'dark' | 'system';

const COOKIE_NAME = 'theme';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 365; // 1 year

export function getTheme(): Theme {
  const match = document.cookie.match(/(?:^|;\s*)theme=(light|dark|system)/);
  return (match?.[1] as Theme | undefined) ?? 'system';
}

export function setTheme(theme: Theme) {
  // biome-ignore lint/suspicious/noDocumentCookie: document.cookie is intentional — the CookieStore API is async and not universally supported, and the root-layout bootstrap reads this cookie synchronously before paint.
  document.cookie = `${COOKIE_NAME}=${theme}; path=/; max-age=${COOKIE_MAX_AGE}; SameSite=Lax`;
  applyTheme(theme);
}

/**
 * Apply the resolved theme to `<html>` by toggling the `dark` class.
 * For `system`, reads `prefers-color-scheme` at call time — the
 * media-query listener below keeps it live as the OS preference
 * changes.
 */
export function applyTheme(theme: Theme) {
  const dark = theme === 'dark' || (theme === 'system' && prefersDark());
  document.documentElement.classList.toggle('dark', dark);
}

function prefersDark(): boolean {
  return window.matchMedia('(prefers-color-scheme: dark)').matches;
}

/**
 * Wire up the OS preference listener once on app start. Only reacts
 * while the user has the `system` mode chosen.
 */
export function startThemeWatcher() {
  const mq = window.matchMedia('(prefers-color-scheme: dark)');
  mq.addEventListener('change', () => {
    if (getTheme() === 'system') applyTheme('system');
  });
}
