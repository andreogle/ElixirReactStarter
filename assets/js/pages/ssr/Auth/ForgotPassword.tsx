import { useForm } from '@inertiajs/react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button';
import Link from '../../../components/Link';
import { inputClass } from '../../../components/ui';
import AuthLayout from '../../../layouts/AuthLayout';
import { routes } from '../../../routes';

export default function ForgotPassword() {
  const { t } = useTranslation();
  const { data, setData, post, processing } = useForm({
    email: '',
  });

  return (
    <AuthLayout title={t('auth.forgotPassword.title')} subtitle={t('auth.forgotPassword.subtitle')}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post(routes.forgotPassword());
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
        </div>

        <Button type="submit" disabled={processing} className="w-full">
          {t('auth.forgotPassword.submit')}
        </Button>

        <p className="text-sm text-center">
          <Link href={routes.login()} className="text-primary hover:underline">
            {t('auth.backToLogin')}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
