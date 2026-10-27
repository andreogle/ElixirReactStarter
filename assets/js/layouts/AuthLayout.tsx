import { Head } from '@inertiajs/react';
import GuestTopBar from '../components/GuestTopBar';

interface AuthLayoutProps {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}

export default function AuthLayout({ title, subtitle, children }: AuthLayoutProps) {
  return (
    <>
      <Head title={title} />
      <div className="flex min-h-screen flex-col">
        <GuestTopBar />

        <div className="flex flex-1 items-center justify-center px-4 pb-16">
          <div className="w-full max-w-sm">
            <h1 className="mb-3 text-center text-2xl font-semibold">{title}</h1>
            {subtitle ? <p className="mb-8 text-center text-sm text-gray-600 dark:text-gray-400">{subtitle}</p> : null}
            {children}
          </div>
        </div>
      </div>
    </>
  );
}
