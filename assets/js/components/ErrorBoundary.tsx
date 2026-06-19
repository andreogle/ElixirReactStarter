import { Component, type ErrorInfo, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { captureException } from '../sentry';
import Button from './Button';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
}

/**
 * Top-level client error boundary. Catches render-time exceptions
 * thrown by a page (or anything below it) so a single broken component
 * shows a branded fallback instead of a blank white screen.
 *
 * In `app.tsx` it's keyed on the Inertia page key, so navigating to a
 * different page remounts it and clears the error automatically — the
 * user can recover by clicking a link without a full reload.
 *
 * This is the one place the project's "no raw try/catch" rule doesn't
 * apply: React error boundaries are the supported synchronous catch-all
 * for the render tree, with no Promise to route through `go()`.
 */
export default class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Surface to the console in every environment, and report to Sentry
    // (no-op unless configured) with the component stack for context.
    console.error('Unhandled render error:', error, info.componentStack);
    captureException(error, { componentStack: info.componentStack });
  }

  render() {
    if (this.state.hasError) return <ErrorFallback />;
    return this.props.children;
  }
}

function ErrorFallback() {
  const { t } = useTranslation();

  return (
    <div role="alert" className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
      <h1 className="text-2xl font-semibold">{t('error.title')}</h1>
      <p className="max-w-md text-sm text-gray-600 dark:text-gray-400">{t('error.body')}</p>
      <Button type="button" onClick={() => window.location.reload()}>
        {t('error.reload')}
      </Button>
    </div>
  );
}
