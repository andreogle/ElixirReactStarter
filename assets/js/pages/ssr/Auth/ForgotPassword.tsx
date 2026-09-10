import { useForm } from '@inertiajs/react';
import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button.tsx';
import Link from '../../../components/Link.tsx';
import { inputClass } from '../../../components/ui.ts';
import AuthLayout from '../../../layouts/AuthLayout.tsx';
import { routes } from '../../../routes.ts';

export default function ForgotPassword() {
  const { t } = useTranslation();
  const id = useId();
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
        </div>

        <Button type="submit" disabled={processing} className="w-full">
          {t('auth.forgotPassword.submit')}
        </Button>

        <p className="text-center text-sm">
          <Link href={routes.login()} className="text-primary hover:underline">
            {t('auth.backToLogin')}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
