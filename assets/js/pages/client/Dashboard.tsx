import { usePage } from '@inertiajs/react';
import { useTranslation } from 'react-i18next';
import AppLayout from '../../layouts/AppLayout.tsx';
import type { CurrentUser } from '../../types.ts';

export default function Dashboard() {
  const { current_user } = usePage<{ current_user: CurrentUser }>().props;
  const { t } = useTranslation();

  return (
    <AppLayout title={t('dashboard.title')}>
      <div className="max-w-xl space-y-6">
        <header>
          <h1 className="font-semibold text-2xl">{t('dashboard.title')}</h1>
          <p className="text-gray-600 text-sm dark:text-gray-400">
            {t('dashboard.signedInAs')} <span className="font-medium">{current_user.email}</span>
          </p>
        </header>

        <section className="rounded border border-gray-200 p-6 dark:border-gray-800">
          <p className="text-gray-600 text-sm dark:text-gray-400">{t('dashboard.placeholder')}</p>
        </section>
      </div>
    </AppLayout>
  );
}
