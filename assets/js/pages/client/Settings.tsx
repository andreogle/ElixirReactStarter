import { useForm, usePage } from '@inertiajs/react';
import { useId, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '../../components/AlertDialog.tsx';
import Button from '../../components/Button.tsx';
import { inputClass } from '../../components/ui.ts';
import AppLayout from '../../layouts/AppLayout.tsx';
import { routes } from '../../routes.ts';

export default function Settings() {
  const { t } = useTranslation();

  return (
    <AppLayout title={t('settings.title')}>
      <div className="max-w-xl space-y-12">
        <h1 className="font-semibold text-2xl">{t('settings.title')}</h1>
        <ChangeEmailSection />
        <ChangePasswordSection />
        <DeleteAccountSection />
      </div>
    </AppLayout>
  );
}

function ChangeEmailSection() {
  const { t } = useTranslation();
  const id = useId();
  const currentEmail = usePage().props.current_user?.email ?? '';
  const { data, setData, put, processing, errors, reset } = useForm({
    current_password: '',
    email: '',
  });

  return (
    <section className="space-y-4">
      <header>
        <h2 className="font-medium text-lg">{t('settings.changeEmail.title')}</h2>
        <p className="text-gray-600 text-sm dark:text-gray-400">
          {t('settings.changeEmail.current', { email: currentEmail })}
        </p>
      </header>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          put(routes.settingsEmail(), { onSuccess: () => reset() });
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor={`${id}-new_email`} className="mb-1 block text-sm">
            {t('settings.changeEmail.newEmail')}
          </label>
          <input
            id={`${id}-new_email`}
            type="email"
            autoComplete="email"
            value={data.email}
            onChange={(e) => setData('email', e.target.value)}
            className={inputClass}
            required
          />
          {errors.email ? <p className="mt-1 text-red-600 text-sm">{errors.email}</p> : null}
        </div>

        <div>
          <label htmlFor={`${id}-email_current_password`} className="mb-1 block text-sm">
            {t('settings.changeEmail.currentPassword')}
          </label>
          <input
            id={`${id}-email_current_password`}
            type="password"
            autoComplete="current-password"
            value={data.current_password}
            onChange={(e) => setData('current_password', e.target.value)}
            className={inputClass}
            required
          />
          {errors.current_password ? <p className="mt-1 text-red-600 text-sm">{errors.current_password}</p> : null}
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
  const id = useId();
  const { data, setData, put, processing, errors, reset } = useForm({
    current_password: '',
    password: '',
  });

  return (
    <section className="space-y-4">
      <header>
        <h2 className="font-medium text-lg">{t('settings.changePassword.title')}</h2>
        <p className="text-gray-600 text-sm dark:text-gray-400">{t('settings.changePassword.warning')}</p>
      </header>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          put(routes.settingsPassword(), { onSuccess: () => reset() });
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor={`${id}-current_password`} className="mb-1 block text-sm">
            {t('settings.changePassword.currentPassword')}
          </label>
          <input
            id={`${id}-current_password`}
            type="password"
            autoComplete="current-password"
            value={data.current_password}
            onChange={(e) => setData('current_password', e.target.value)}
            className={inputClass}
            required
          />
          {errors.current_password ? <p className="mt-1 text-red-600 text-sm">{errors.current_password}</p> : null}
        </div>

        <div>
          <label htmlFor={`${id}-password`} className="mb-1 block text-sm">
            {t('settings.changePassword.newPassword')}
          </label>
          <input
            id={`${id}-password`}
            type="password"
            autoComplete="new-password"
            value={data.password}
            onChange={(e) => setData('password', e.target.value)}
            className={inputClass}
            required
            minLength={8}
          />
          {errors.password ? <p className="mt-1 text-red-600 text-sm">{errors.password}</p> : null}
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
        <h2 className="font-medium text-lg">{t('settings.deleteAccount.title')}</h2>
        <p className="text-gray-600 text-sm dark:text-gray-400">{t('settings.deleteAccount.warning')}</p>
      </header>

      <AlertDialog
        open={open}
        onOpenChange={(next) => {
          setOpen(next);
          if (!next) {
            reset();
          }
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
              destroy(routes.settingsAccount());
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
            {errors.password ? <p className="text-red-600 text-sm">{errors.password}</p> : null}

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
