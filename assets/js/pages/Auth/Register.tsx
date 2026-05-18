import { useForm } from '@inertiajs/react';
import Button from '../../components/Button';
import Link from '../../components/Link';
import { inputClass } from '../../components/ui';
import AuthLayout from '../../layouts/AuthLayout';

export default function Register() {
  const { data, setData, post, processing, errors } = useForm({
    email: '',
    password: '',
  });

  return (
    <AuthLayout title="Create account">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post('/register');
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
          {errors.email && <p className="mt-1 text-sm text-red-600">{errors.email}</p>}
        </div>

        <div>
          <label htmlFor="password" className="block text-sm mb-1">
            Password
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
          Create account
        </Button>

        <p className="text-sm text-center">
          Already have an account?{' '}
          <Link href="/login" className="text-primary hover:underline">
            Log in
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
