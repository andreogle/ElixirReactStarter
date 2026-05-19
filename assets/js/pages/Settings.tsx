import { useForm } from '@inertiajs/react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '../components/AlertDialog';
import Button from '../components/Button';
import { inputClass } from '../components/ui';
import AppLayout from '../layouts/AppLayout';

export default function Settings() {
  const { t } = useTranslation();

  return (
    <AppLayout title={t('settings.title')}>
      <div className="max-w-xl space-y-12">
        <h1 className="text-2xl font-semibold">{t('settings.title')}</h1>
        <ChangePasswordSection />
        <DeleteAccountSection />
      </div>
    </AppLayout>
  );
}

function ChangePasswordSection() {
  const { t } = useTranslation();
  const { data, setData, put, processing, errors, reset } = useForm({
    current_password: '',
    password: '',
  });

  return (
    <section className="space-y-4">
      <header>
        <h2 className="text-lg font-medium">{t('settings.changePassword.title')}</h2>
        <p className="text-sm text-gray-600 dark:text-gray-400">{t('settings.changePassword.warning')}</p>
      </header>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          put('/settings/password', { onSuccess: () => reset() });
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor="current_password" className="block text-sm mb-1">
            {t('settings.changePassword.currentPassword')}
          </label>
          <input
            id="current_password"
            type="password"
            autoComplete="current-password"
            value={data.current_password}
            onChange={(e) => setData('current_password', e.target.value)}
            className={inputClass}
            required
          />
          {errors.current_password && <p className="mt-1 text-sm text-red-600">{errors.current_password}</p>}
        </div>

        <div>
          <label htmlFor="password" className="block text-sm mb-1">
            {t('settings.changePassword.newPassword')}
          </label>
          <input
            id="password"
            type="password"
            autoComplete="new-password"
            value={data.password}
            onChange={(e) => setData('password', e.target.value)}
            className={inputClass}
            required
            minLength={8}
          />
          {errors.password && <p className="mt-1 text-sm text-red-600">{errors.password}</p>}
        </div>

        <Button type="submit" disabled={processing}>
          {t('settings.changePassword.submit')}
        </Button>
      </form>
    </section>
  );
}

function DeleteAccountSection() {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  const {
    data,
    setData,
    delete: destroy,
    processing,
    errors,
    reset,
  } = useForm({
    password: '',
  });

  return (
    <section className="space-y-4">
      <header>
        <h2 className="text-lg font-medium">{t('settings.deleteAccount.title')}</h2>
        <p className="text-sm text-gray-600 dark:text-gray-400">{t('settings.deleteAccount.warning')}</p>
      </header>

      <AlertDialog
        open={open}
        onOpenChange={(next) => {
          setOpen(next);
          if (!next) reset();
        }}
      >
        <AlertDialogTrigger asChild>
          <button
            type="button"
            className="inline-flex items-center justify-center rounded px-4 py-2 text-sm font-medium border border-red-300 text-red-700 dark:border-red-700 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-500"
          >
            {t('settings.deleteAccount.button')}
          </button>
        </AlertDialogTrigger>

        <AlertDialogContent>
          <AlertDialogTitle>{t('settings.deleteAccount.confirmTitle')}</AlertDialogTitle>
          <AlertDialogDescription>{t('settings.deleteAccount.confirmBody')}</AlertDialogDescription>

          <form
            onSubmit={(e) => {
              e.preventDefault();
              destroy('/settings/account');
            }}
            className="mt-4 space-y-3"
          >
            <input
              type="password"
              autoComplete="current-password"
              value={data.password}
              onChange={(e) => setData('password', e.target.value)}
              className={inputClass}
              placeholder={t('settings.deleteAccount.passwordPlaceholder')}
              required
              aria-label={t('settings.deleteAccount.passwordPlaceholder')}
            />
            {errors.password && <p className="text-sm text-red-600">{errors.password}</p>}

            <AlertDialogFooter>
              <AlertDialogCancel asChild>
                <Button type="button" variant="secondary">
                  {t('settings.deleteAccount.cancel')}
                </Button>
              </AlertDialogCancel>
              <AlertDialogAction asChild>
                <button
                  type="submit"
                  disabled={processing}
                  className="inline-flex items-center justify-center rounded px-4 py-2 text-sm font-medium bg-red-600 text-white hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-500"
                >
                  {t('settings.deleteAccount.confirm')}
                </button>
              </AlertDialogAction>
            </AlertDialogFooter>
          </form>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}
