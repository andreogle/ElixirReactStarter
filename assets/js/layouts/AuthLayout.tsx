import { Head } from '@inertiajs/react';

interface AuthLayoutProps {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}

export default function AuthLayout({ title, subtitle, children }: AuthLayoutProps) {
  return (
    <>
      <Head title={title} />
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800 px-4">
        <div className="w-full max-w-sm">
          <h1 className="text-3xl font-bold text-slate-900 dark:text-white text-center mb-3">{title}</h1>
          {subtitle && <p className="text-sm text-slate-500 dark:text-slate-400 text-center mb-8">{subtitle}</p>}
          {children}
        </div>
      </div>
    </>
  );
}
