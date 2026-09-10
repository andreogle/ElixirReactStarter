import { useForm } from '@inertiajs/react';
import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button';
import Link from '../../../components/Link';
import { inputClass } from '../../../components/ui';
import AuthLayout from '../../../layouts/AuthLayout';
import { routes } from '../../../routes';

export default function ResendConfirmation() {
  const { t } = useTranslation();
  const id = useId();
  const { data, setData, post, processing } = useForm({
    email: '',
  });

  return (
    <AuthLayout title={t('auth.resendConfirmation.title')} subtitle={t('auth.resendConfirmation.subtitle')}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post(routes.resendConfirmation());
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
          {t('auth.resendConfirmation.submit')}
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
