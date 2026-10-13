import '@inertiajs/core';
import type { CurrentUser, Flash } from '../types';

declare module '@inertiajs/core' {
  interface InertiaConfig {
    // Flash is a top-level page key (`page.flash`), not a prop.
    flashDataType: Flash;
    sharedPageProps: {
      current_user: CurrentUser | null;
      locale: string;
      socket_token: string | null;
    };
  }
}
