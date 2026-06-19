import { useForm } from '@inertiajs/react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button';
import Link from '../../../components/Link';
import { inputClass } from '../../../components/ui';
import AuthLayout from '../../../layouts/AuthLayout';
import { routes } from '../../../routes';

export default function Register() {
  const { t } = useTranslation();
  const { data, setData, post, processing, errors } = useForm({
    email: '',
    password: '',
  });

  return (
    <AuthLayout title={t('auth.register.title')}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post(routes.register());
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
            autoComplete="new-password"
            value={data.password}
            onChange={(e) => setData('password', e.target.value)}
            className={inputClass}
            required
            minLength={8}
          />
          {errors.password && <p className="mt-1 text-sm text-red-600">{errors.password}</p>}
        </div>

        <Button type="submit" disabled={processing} className="w-full">
          {t('auth.register.submit')}
        </Button>

        <p className="text-sm text-center">
          {t('auth.register.alreadyHaveAccount')}{' '}
          <Link href={routes.login()} className="text-primary hover:underline">
            {t('auth.register.logIn')}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
