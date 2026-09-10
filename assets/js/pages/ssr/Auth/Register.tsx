import { useForm } from '@inertiajs/react';
import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button.tsx';
import Link from '../../../components/Link.tsx';
import { inputClass } from '../../../components/ui.ts';
import AuthLayout from '../../../layouts/AuthLayout.tsx';
import { routes } from '../../../routes.ts';

export default function Register() {
  const { t } = useTranslation();
  const id = useId();
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
            autoComplete="new-password"
            value={data.password}
            onChange={(e) => setData('password', e.target.value)}
            className={inputClass}
            required
            minLength={8}
          />
          {errors.password ? <p className="mt-1 text-red-600 text-sm">{errors.password}</p> : null}
        </div>

        <Button type="submit" disabled={processing} className="w-full">
          {t('auth.register.submit')}
        </Button>

        <p className="text-center text-sm">
          {t('auth.register.alreadyHaveAccount')}{' '}
          <Link href={routes.login()} className="text-primary hover:underline">
            {t('auth.register.logIn')}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
