import { useForm, usePage } from '@inertiajs/react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  AlertDialog,
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
        <ChangeEmailSection />
        <ChangePasswordSection />
        <DeleteAccountSection />
      </div>
    </AppLayout>
  );
}

function ChangeEmailSection() {
  const { t } = useTranslation();
  const currentEmail = usePage().props.current_user?.email ?? '';
  const { data, setData, put, processing, errors, reset } = useForm({
    current_password: '',
    email: '',
  });

  return (
    <section className="space-y-4">
      <header>
        <h2 className="text-lg font-medium">{t('settings.changeEmail.title')}</h2>
        <p className="text-sm text-gray-600 dark:text-gray-400">
          {t('settings.changeEmail.current', { email: currentEmail })}
        </p>
      </header>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          put('/settings/email', { onSuccess: () => reset() });
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor="new_email" className="block text-sm mb-1">
            {t('settings.changeEmail.newEmail')}
          </label>
          <input
            id="new_email"
            type="email"
            autoComplete="email"
            value={data.email}
            onChange={(e) => setData('email', e.target.value)}
            className={inputClass}
            required
          />
          {errors.email && <p className="mt-1 text-sm text-red-600">{errors.email}</p>}
        </div>

        <div>
          <label htmlFor="email_current_password" className="block text-sm mb-1">
            {t('settings.changeEmail.currentPassword')}
          </label>
          <input
            id="email_current_password"
            type="password"
            autoComplete="current-password"
            value={data.current_password}
            onChange={(e) => setData('current_password', e.target.value)}
            className={inputClass}
            required
          />
          {errors.current_password && <p className="mt-1 text-sm text-red-600">{errors.current_password}</p>}
        </div>

        <Button type="submit" disabled={processing}>
          {t('settings.changeEmail.submit')}
        </Button>
      </form>
    </section>
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
          <Button type="button" variant="dangerOutline">
            {t('settings.deleteAccount.button')}
          </Button>
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
              {/*
                A plain submit button — NOT AlertDialogAction. Radix's
                Action closes the dialog the instant it's clicked, and
                React 18 flushes that unmount synchronously during the
                click, tearing down this <form> before the browser fires
                its submit. The result is a confirm button that closes the
                dialog without ever deleting. Letting the form own
                submission fixes that: a successful destroy() redirects to
                "/" (dialog goes with the page); a failed one redirects
                back to /settings and the dialog stays open to show the
                error.
              */}
              <Button type="submit" variant="danger" disabled={processing}>
                {t('settings.deleteAccount.confirm')}
              </Button>
            </AlertDialogFooter>
          </form>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}
