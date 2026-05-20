import { go } from '@api3/promise-utils';
import { router } from '@inertiajs/react';
import axe from 'axe-core';

/**
 * Development-only accessibility auditing with axe-core.
 *
 * Scans the rendered DOM on first paint and after every Inertia
 * navigation, logging WCAG violations to the browser console. This
 * catches issues static analysis (Biome's `a11y` rules) cannot see:
 * colour contrast, the computed ARIA tree, focus order, duplicate ids,
 * and label/control association across components.
 *
 * This module is only ever imported from the `process.env.NODE_ENV !==
 * 'production'` branch in `app.tsx`. esbuild replaces that define and
 * dead-code-eliminates the branch in the production build, so neither
 * this module nor axe-core ships in prod.
 */
export function startA11yAudit() {
  const scan = async () => {
    const result = await go(() => axe.run(document));
    if (!result.success) {
      console.error('[a11y] axe scan failed:', result.error);
      return;
    }

    const { violations } = result.data;
    if (violations.length === 0) return;

    console.warn(`[a11y] ${violations.length} issue(s) on ${window.location.pathname}`);
    for (const v of violations) {
      console.warn(
        `  [${v.impact ?? 'n/a'}] ${v.id}: ${v.help}\n  ${v.helpUrl}`,
        v.nodes.map((node) => node.target)
      );
    }
  };

  // Debounce: a burst of DOM updates after navigation triggers one scan.
  let timer: ReturnType<typeof setTimeout> | undefined;
  const schedule = () => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => void scan(), 500);
  };

  router.on('finish', schedule);
  schedule();
}
