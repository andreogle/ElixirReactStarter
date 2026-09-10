import { useForm } from '@inertiajs/react';
import { useId } from 'react';
import { useTranslation } from 'react-i18next';
import Button from '../../../components/Button.tsx';
import { inputClass } from '../../../components/ui.ts';
import AuthLayout from '../../../layouts/AuthLayout.tsx';
import { routes } from '../../../routes.ts';

interface ResetPasswordProps {
  token: string;
}

export default function ResetPassword({ token }: ResetPasswordProps) {
  const { t } = useTranslation();
  const id = useId();
  const { data, setData, post, processing, errors } = useForm({
    token,
    password: '',
  });

  return (
    <AuthLayout title={t('auth.resetPassword.title')}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post(routes.resetPassword());
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor={`${id}-password`} className="mb-1 block text-sm">
            {t('auth.resetPassword.newPassword')}
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
          {t('auth.resetPassword.submit')}
        </Button>
      </form>
    </AuthLayout>
  );
}
