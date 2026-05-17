import '@inertiajs/core';
import type { CurrentMembership, CurrentUser, Flash } from '../types';

declare module '@inertiajs/core' {
  interface InertiaConfig {
    sharedPageProps: {
      current_user: CurrentUser | null;
      current_membership: CurrentMembership | null;
      socket_token: string | null;
      locale: string;
      flash: Flash;
    };
  }
}
