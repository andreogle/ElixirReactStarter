import { usePage } from '@inertiajs/react';
import ConnectionIndicator from '../components/ConnectionIndicator';
import AppLayout from '../layouts/AppLayout';
import type { CurrentUser } from '../types';

export default function Dashboard() {
  const { current_user } = usePage<{ current_user: CurrentUser }>().props;

  return (
    <AppLayout title="Dashboard">
      <div className="max-w-xl space-y-6">
        <header className="flex items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-semibold">Dashboard</h1>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              Signed in as <span className="font-medium">{current_user.email}</span>
            </p>
          </div>
          <ConnectionIndicator />
        </header>

        <section className="rounded border border-gray-200 dark:border-gray-700 p-6">
          <p className="text-sm text-gray-600 dark:text-gray-400">
            This is your dashboard. Replace this card with whatever the post-login landing should show — recent
            activity, quick actions, KPIs, etc.
          </p>
        </section>
      </div>
    </AppLayout>
  );
}
