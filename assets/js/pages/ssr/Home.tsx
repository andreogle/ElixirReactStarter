import { Head, router, usePage } from '@inertiajs/react';
import { useTranslation } from 'react-i18next';
import Button from '../../components/Button';
import GuestTopBar from '../../components/GuestTopBar';
import Link from '../../components/Link';
import { routes } from '../../routes';
import type { CurrentUser } from '../../types';

export default function Home() {
  const { current_user } = usePage<{ current_user: CurrentUser | null }>().props;
  const { t } = useTranslation();

  return (
    <>
      <Head title={t('home.welcome')} />
      <main className="flex min-h-screen flex-col">
        <GuestTopBar />

        <div className="flex flex-1 items-center justify-center px-4 pb-16">
          <div className="max-w-xl space-y-6 text-center">
            <h1 className="font-bold text-4xl tracking-tight">{t('home.welcome')}</h1>
            <p className="text-base text-gray-600 dark:text-gray-400">{t('home.stack')}</p>

            {current_user ? (
              <div className="space-y-3 pt-2">
                <p className="text-gray-600 text-sm dark:text-gray-400">
                  {t('home.signedInAs')} <span className="font-medium">{current_user.email}</span>
                </p>
                <div className="flex items-center justify-center gap-3">
                  <Link
                    href={routes.dashboard()}
                    className="inline-flex items-center justify-center rounded bg-primary px-4 py-2 font-medium text-sm text-white hover:opacity-90 focus-visible:outline-2 focus-visible:outline-primary focus-visible:outline-offset-2"
                  >
                    {t('home.goToDashboard')}
                  </Link>
                  <Button variant="secondary" onClick={() => router.delete(routes.logout())}>
                    {t('common.logout')}
                  </Button>
                </div>
              </div>
            ) : (
              <div className="flex items-center justify-center gap-3 pt-2">
                <Link
                  href={routes.login()}
                  className="inline-flex items-center justify-center rounded bg-primary px-4 py-2 font-medium text-sm text-white hover:opacity-90 focus-visible:outline-2 focus-visible:outline-primary focus-visible:outline-offset-2"
                >
                  {t('home.login')}
                </Link>
                <Link
                  href={routes.register()}
                  className="inline-flex items-center justify-center rounded border border-gray-300 px-4 py-2 font-medium text-sm hover:bg-gray-50 focus-visible:outline-2 focus-visible:outline-gray-500 focus-visible:outline-offset-2 dark:border-gray-700 dark:hover:bg-gray-800"
                >
                  {t('home.createAccount')}
                </Link>
              </div>
            )}
          </div>
        </div>
      </main>
    </>
  );
}
