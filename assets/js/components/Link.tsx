// biome-ignore lint/style/noRestrictedImports: this wrapper IS the sanctioned entrypoint; the rule forbids the import everywhere else.
import { Link as InertiaLink } from '@inertiajs/react';
import type { ComponentProps } from 'react';

type InertiaLinkProps = ComponentProps<typeof InertiaLink>;

/**
 * Project-wide wrapper around Inertia's `<Link>` that turns on
 * `prefetch="mount"` by default so every navigation warms its target's
 * chunk + props cache. Opt out with `prefetch={false}` on rare links
 * where prefetching is wasteful (e.g. destructive actions).
 *
 * **Why `"mount"` and not `"hover"` (or `true`, which Inertia treats as
 * hover):** Inertia's hover-prefetch starts a `setTimeout` on
 * `onMouseEnter` and does *not* cancel it on `onClick`. A user (or
 * Playwright) who clicks before the hover delay elapses ends up firing
 * two XHRs to the same URL — a regular visit from the click AND a
 * separate prefetch from the still-pending timer. When the late
 * prefetch response arrives, Inertia re-applies it to the active page,
 * remounting the page component with fresh props and silently wiping
 * controlled-form state mid-typing. Mount-prefetch sidesteps this: the
 * prefetch is in flight as soon as the Link renders, so on click
 * Inertia's `prefetchedRequests.use()` adopts the in-flight request
 * instead of starting a second one. One request, one mount.
 *
 * All other props pass through unchanged. A Biome `noRestrictedImports`
 * rule blocks direct `Link` imports from `@inertiajs/react`, so new code
 * can't accidentally skip the default.
 */
export default function Link({ prefetch = 'mount', ...rest }: InertiaLinkProps) {
  return <InertiaLink prefetch={prefetch} {...rest} />;
}
