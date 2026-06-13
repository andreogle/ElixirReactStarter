import { useForm } from '@inertiajs/react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button';
import Link from '../../../components/Link';
import { inputClass } from '../../../components/ui';
import AuthLayout from '../../../layouts/AuthLayout';

export default function Login() {
  const { t } = useTranslation();
  const { data, setData, post, processing, errors } = useForm({
    email: '',
    password: '',
  });

  return (
    <AuthLayout title={t('auth.login.title')}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post('/login');
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor="email" className="block text-sm mb-1">
            {t('auth.email')}
          </label>
          <input
            id="email"
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
          <label htmlFor="password" className="block text-sm mb-1">
            {t('auth.password')}
          </label>
          <input
            id="password"
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
          <Link href="/register" className="text-primary hover:underline">
            {t('auth.login.createAccount')}
          </Link>
          <Link href="/forgot-password" className="text-primary hover:underline">
            {t('auth.login.forgotPassword')}
          </Link>
        </div>

        <p className="text-center text-sm">
          <Link href="/resend-confirmation" className="text-primary hover:underline">
            {t('auth.login.resendConfirmation')}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
