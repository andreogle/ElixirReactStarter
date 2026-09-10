import { type ReactNode, useEffect } from 'react';
import { TooltipProvider } from './components/Tooltip';
import { RealtimeProvider } from './realtime/provider';

// =============================================================================
// App-wide React context providers.
//
// Mounted *inside* Inertia's `<App>` from `app.tsx` because every provider
// in here is allowed to consume page context via `usePage()`. The wrapper
// itself stays mounted across page navigations — only the inner page
// `<Component>` swaps — so anything that holds a long-lived resource (a
// Phoenix socket, a query cache, a theme listener, …) survives navigation.
//
// New providers go here, not in layouts. Layouts unmount on layout
// transitions (e.g. AuthLayout → AppLayout on login), which would tear
// down whatever they wrap; pages without a layout would also miss out.
// Keeping the provider stack here keeps it global, page-context-aware,
// and visible in one place — so when this list grows, the order and
// boundaries stay obvious.
// =============================================================================

export function AppProviders({ children }: { children: ReactNode }) {
  // Hydration signal for the Playwright E2E suite. AppProviders mounts once
  // and stays mounted across Inertia navigations, so this effect fires
  // exactly when client-side hydration completes. Specs poll for
  // `html[data-hydrated="true"]` before interacting with forms — pre-hydration,
  // controlled inputs haven't reconciled with SSR markup and onSubmit
  // handlers aren't attached, so any fill+click against them is a race.
  // useEffect doesn't run during SSR, so this is purely a client-side flag.
  useEffect(() => {
    document.documentElement.dataset.hydrated = 'true';
  }, []);

  return (
    <RealtimeProvider>
      <TooltipProvider delayDuration={200}>{children}</TooltipProvider>
    </RealtimeProvider>
  );
}
