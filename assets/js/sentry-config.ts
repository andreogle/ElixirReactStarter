import type { BrowserOptions } from '@sentry/react';

// Shared by browser and SSR. Sentry 11 collects more data by default;
// keep error stacks and an explicit user ID without automatic personal data.
export const dataCollection = {
  userInfo: false,
  cookies: false,
  httpHeaders: false,
  httpBodies: [],
  urlQueryParams: false,
  genAI: { inputs: false, outputs: false },
  databaseQueryData: false,
  queues: false,
  graphQL: { document: false, variables: false },
  stackFrameVariables: false,
} satisfies BrowserOptions['dataCollection'];

/** Missing props mean a partial reload; null means the user signed out. */
export function userFromProps(props: Record<string, unknown>): { id: string } | null | undefined {
  if (!('current_user' in props)) {
    return undefined;
  }
  const user = props.current_user as { id: string } | null;
  return user ? { id: user.id } : null;
}
