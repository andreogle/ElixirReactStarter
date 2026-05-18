/**
 * App-wide TypeScript types shared across pages, components, and
 * layouts. Module augmentation for third-party libraries (e.g.
 * `@inertiajs/core`) lives in `types/*.d.ts` and imports its concrete
 * types from here.
 */

export interface CurrentUser {
  id: string;
  email: string;
}

export interface Flash {
  info?: string;
  error?: string;
}
