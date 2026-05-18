import '@inertiajs/core';
import type { CurrentUser, Flash } from '../types';

declare module '@inertiajs/core' {
  interface InertiaConfig {
    sharedPageProps: {
      current_user: CurrentUser | null;
      locale: string;
      flash: Flash;
    };
  }
}
