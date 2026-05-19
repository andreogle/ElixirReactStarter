import { Head, router, usePage } from '@inertiajs/react';
import { useTranslation } from 'react-i18next';
import Button from '../components/Button';
import Link from '../components/Link';
import type { CurrentUser } from '../types';

export default function Home() {
  const { current_user } = usePage<{ current_user: CurrentUser | null }>().props;
  const { t } = useTranslation();

  return (
    <>
      <Head title={t('home.welcome')} />
      <main className="min-h-screen flex items-center justify-center p-8">
        <div className="max-w-xl text-center space-y-6">
          <h1 className="text-4xl font-bold tracking-tight">{t('home.welcome')}</h1>
          <p className="text-base text-gray-600 dark:text-gray-400">{t('home.stack')}</p>

          {current_user ? (
            <div className="space-y-3 pt-2">
              <p className="text-sm text-gray-600 dark:text-gray-400">
                {t('home.signedInAs')} <span className="font-medium">{current_user.email}</span>
              </p>
              <div className="flex items-center justify-center gap-3">
                <Link
                  href="/dashboard"
                  className="inline-flex items-center justify-center rounded px-4 py-2 text-sm font-medium bg-primary text-white hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
                >
                  {t('home.goToDashboard')}
                </Link>
                <Button variant="secondary" onClick={() => router.delete('/logout')}>
                  {t('common.logout')}
                </Button>
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-center gap-3 pt-2">
              <Link
                href="/login"
                className="inline-flex items-center justify-center rounded px-4 py-2 text-sm font-medium bg-primary text-white hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
              >
                {t('home.login')}
              </Link>
              <Link
                href="/register"
                className="inline-flex items-center justify-center rounded px-4 py-2 text-sm font-medium border border-gray-300 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-500"
              >
                {t('home.createAccount')}
              </Link>
            </div>
          )}
        </div>
      </main>
    </>
  );
}
