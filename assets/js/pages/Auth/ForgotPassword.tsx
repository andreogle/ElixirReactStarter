import { useForm } from '@inertiajs/react';
import Button from '../../components/Button';
import Link from '../../components/Link';
import { inputClass } from '../../components/ui';
import AuthLayout from '../../layouts/AuthLayout';

export default function ForgotPassword() {
  const { data, setData, post, processing } = useForm({
    email: '',
  });

  return (
    <AuthLayout title="Reset password" subtitle="Enter your email and we'll send you a reset link.">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post('/forgot-password');
        }}
        className="space-y-4"
      >
        <div>
          <label htmlFor="email" className="block text-sm mb-1">
            Email
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
          Send reset link
        </Button>

        <p className="text-sm text-center">
          <Link href="/login" className="text-primary hover:underline">
            Back to log in
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
