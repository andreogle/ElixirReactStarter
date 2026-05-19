import { Head } from '@inertiajs/react';
import LocaleSelector from '../components/LocaleSelector';

interface AuthLayoutProps {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}

export default function AuthLayout({ title, subtitle, children }: AuthLayoutProps) {
  return (
    <>
      <Head title={title} />
      <div className="min-h-screen flex flex-col px-4">
        {/* Top-right locale toggle so anonymous users on the auth pages
            can switch language before signing in. */}
        <div className="self-end pt-4">
          <LocaleSelector />
        </div>

        <div className="flex-1 flex items-center justify-center">
          <div className="w-full max-w-sm">
            <h1 className="text-2xl font-semibold text-center mb-3">{title}</h1>
            {subtitle && <p className="text-sm text-gray-600 dark:text-gray-400 text-center mb-8">{subtitle}</p>}
            {children}
          </div>
        </div>
      </div>
    </>
  );
}
