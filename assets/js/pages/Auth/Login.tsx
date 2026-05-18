import { useForm } from '@inertiajs/react';
import Button from '../../components/Button';
import Link from '../../components/Link';
import { inputClass } from '../../components/ui';
import AuthLayout from '../../layouts/AuthLayout';

export default function Login() {
  const { data, setData, post, processing, errors } = useForm({
    email: '',
    password: '',
  });

  return (
    <AuthLayout title="Log in">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          post('/login');
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
            autoComplete="current-password"
            value={data.password}
            onChange={(e) => setData('password', e.target.value)}
            className={inputClass}
            required
          />
        </div>

        <Button type="submit" disabled={processing} className="w-full">
          Log in
        </Button>

        <div className="flex justify-between text-sm">
          <Link href="/register" className="text-primary hover:underline">
            Create account
          </Link>
          <Link href="/forgot-password" className="text-primary hover:underline">
            Forgot password?
          </Link>
        </div>
      </form>
    </AuthLayout>
  );
}
