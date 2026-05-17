// biome-ignore lint/style/noRestrictedImports: this wrapper IS the sanctioned entrypoint; the rule forbids the import everywhere else.
import { Link as InertiaLink } from '@inertiajs/react';
import type { ComponentProps } from 'react';

type InertiaLinkProps = ComponentProps<typeof InertiaLink>;

/**
 * Project-wide wrapper around Inertia's `<Link>` that turns on
 * `prefetch="hover"` by default so every navigation warms its target's
 * chunk + props cache. Opt out with `prefetch={false}` on rare links
 * where prefetching is wasteful (e.g. destructive actions).
 *
 * All other props pass through unchanged. A Biome `noRestrictedImports`
 * rule blocks direct `Link` imports from `@inertiajs/react`, so new code
 * can't accidentally skip the default.
 */
export default function Link({ prefetch = true, ...rest }: InertiaLinkProps) {
  return <InertiaLink prefetch={prefetch} {...rest} />;
}
