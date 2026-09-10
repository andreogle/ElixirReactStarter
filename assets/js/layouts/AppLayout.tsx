import { Head, router, usePage } from '@inertiajs/react';
import type { TFunction } from 'i18next';
import { ChevronDown, CircleUserRound, LogOut, Settings } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import ConnectionIndicator from '../components/ConnectionIndicator';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '../components/DropdownMenu';
import Link from '../components/Link';
import LocaleSelector from '../components/LocaleSelector';
import ThemeToggle from '../components/ThemeToggle';
import { routes } from '../routes';
import type { CurrentUser } from '../types';

interface AppLayoutProps {
  title: string;
  children: React.ReactNode;
}

interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<React.SVGProps<SVGSVGElement>>;
}

// One container width across the whole app so switching pages (or
// in-page views) never reflows the chrome. Pages that want narrower
// content can constrain their own inner sections.
const containerClass = 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8';

const BRAND = 'ElixirReactStarter';

export default function AppLayout({ title, children }: AppLayoutProps) {
  const { current_user } = usePage<{ current_user: CurrentUser }>().props;
  const { url } = usePage();
  const { t } = useTranslation();

  const displayName = current_user.email;
  const items = navItemsFor(t);
  const [currentPath] = url.split('?');

  return (
    <>
      <Head title={title} />
      <div className="min-h-screen">
        <header className="border-gray-200 border-b dark:border-gray-800">
          <div className={`${containerClass} flex items-center justify-between gap-3 py-3`}>
            <div className="flex min-w-0 items-center gap-6">
              <Link href={routes.dashboard()} className="shrink-0 font-semibold text-base">
                {BRAND}
              </Link>
              <nav aria-label={t('common.mainNav')} className="hidden items-center gap-1 md:flex">
                {items.map((item) => (
                  <PrimaryNavLink key={item.href} item={item} active={isActive(currentPath, item.href)} />
                ))}
              </nav>
            </div>

            <div className="flex items-center gap-3">
              <ConnectionIndicator />
              <ThemeToggle />
              <LocaleSelector />
              <UserMenu displayName={displayName} mobileNavItems={items} t={t} />
            </div>
          </div>
        </header>

        <main className="py-6 sm:py-10">
          <div className={containerClass}>{children}</div>
        </main>
      </div>
    </>
  );
}

function navItemsFor(_t: TFunction): NavItem[] {
  // Add nav items as the app grows. Returning an empty list collapses
  // the header into just the brand + user menu.
  return [];
}

function isActive(currentPath: string, itemHref: string): boolean {
  return currentPath === itemHref || currentPath.startsWith(`${itemHref}/`);
}

function PrimaryNavLink({ item, active }: { item: NavItem; active: boolean }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      aria-current={active ? 'page' : undefined}
      className={`inline-flex items-center gap-1.5 rounded px-3 py-1.5 text-sm focus-visible:outline-2 focus-visible:outline-primary focus-visible:outline-offset-2 ${
        active ? 'bg-gray-100 font-medium dark:bg-gray-800' : 'hover:bg-gray-50 dark:hover:bg-gray-900'
      }`}
    >
      <Icon className="size-4" aria-hidden="true" />
      <span>{item.label}</span>
    </Link>
  );
}

function UserMenu({
  displayName,
  mobileNavItems,
  t,
}: {
  displayName: string;
  mobileNavItems: NavItem[];
  t: TFunction;
}) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        aria-label={t('common.userMenu')}
        className="flex cursor-pointer items-center gap-1.5 rounded px-2 py-1.5 text-sm focus-visible:outline-2 focus-visible:outline-primary focus-visible:outline-offset-2"
      >
        <CircleUserRound className="size-5" aria-hidden="true" />
        <span className="sr-only max-w-40 truncate sm:not-sr-only">{displayName}</span>
        <ChevronDown className="size-4" aria-hidden="true" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-56">
        <div className="border-gray-200 border-b px-3 py-2 dark:border-gray-800">
          <p className="truncate font-medium text-sm">{displayName}</p>
        </div>

        {/* Primary nav fallback — only visible when the desktop nav is hidden. */}
        <div className="md:hidden">
          {mobileNavItems.map((item) => {
            const Icon = item.icon;
            return (
              <DropdownMenuItem key={item.href} onSelect={() => router.visit(item.href)}>
                <Icon className="size-4" aria-hidden="true" />
                <span className="flex-1">{item.label}</span>
              </DropdownMenuItem>
            );
          })}
          <DropdownMenuSeparator className="my-1 h-px bg-gray-200 dark:bg-gray-800" />
        </div>

        <DropdownMenuItem onSelect={() => router.visit(routes.settings())}>
          <Settings className="size-4" aria-hidden="true" />
          <span className="flex-1">{t('common.settings')}</span>
        </DropdownMenuItem>
        <DropdownMenuSeparator className="my-1 h-px bg-gray-200 dark:bg-gray-800" />
        <DropdownMenuItem onSelect={() => router.delete(routes.logout())}>
          <LogOut className="size-4" aria-hidden="true" />
          <span className="flex-1">{t('common.logout')}</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
