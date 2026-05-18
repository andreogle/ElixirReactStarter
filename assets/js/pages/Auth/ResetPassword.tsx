import { useForm } from '@inertiajs/react';
import Button from '../../components/Button';
import { inputClass } from '../../components/ui';
import AuthLayout from '../../layouts/AuthLayout';

interface ResetPasswordProps {
  token: string;
}

export default function ResetPassword({ token }: ResetPasswordProps) {
  const { data, setData, post, processing, errors } = useForm({
    token,
    password: '',
  });

  return (
    <AuthLayout title="Set a new password">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post('/reset-password');
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor="password" className="block text-sm mb-1">
            New password
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
          Set password
        </Button>
      </form>
    </AuthLayout>
  );
}
