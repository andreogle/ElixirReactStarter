import { useForm } from '@inertiajs/react';
import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button';
import Link from '../../../components/Link';
import { inputClass } from '../../../components/ui';
import AuthLayout from '../../../layouts/AuthLayout';
import { routes } from '../../../routes';

export default function Login() {
  const { t } = useTranslation();
  const id = useId();
  const { data, setData, post, processing, errors } = useForm({
    email: '',
    password: '',
  });

  return (
    <AuthLayout title={t('auth.login.title')}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post(routes.login());
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor={`${id}-email`} className="mb-1 block text-sm">
            {t('auth.email')}
          </label>
          <input
            id={`${id}-email`}
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
          <label htmlFor={`${id}-password`} className="mb-1 block text-sm">
            {t('auth.password')}
          </label>
          <input
            id={`${id}-password`}
            type="password"
            autoComplete="current-password"
            value={data.password}
            onChange={(e) => setData('password', e.target.value)}
            className={inputClass}
            required
          />
        </div>

        <Button type="submit" disabled={processing} className="w-full">
          {t('auth.login.submit')}
        </Button>

        <div className="flex justify-between text-sm">
          <Link href={routes.register()} className="text-primary hover:underline">
            {t('auth.login.createAccount')}
          </Link>
          <Link href={routes.forgotPassword()} className="text-primary hover:underline">
            {t('auth.login.forgotPassword')}
          </Link>
        </div>

        <p className="text-center text-sm">
          <Link href={routes.resendConfirmation()} className="text-primary hover:underline">
            {t('auth.login.resendConfirmation')}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
