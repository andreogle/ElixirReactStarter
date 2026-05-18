import { Head, router, usePage } from '@inertiajs/react';
import type { TFunction } from 'i18next';
import { ChevronDown, CircleUserRound, LayoutDashboard, LogOut, Settings } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '../components/DropdownMenu';
import Link from '../components/Link';
import LocaleSelector from '../components/LocaleSelector';
import type { CurrentMembership, CurrentUser } from '../types';

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

export default function AppLayout({ title, children }: AppLayoutProps) {
  const { current_user, current_membership } = usePage<{
    current_user: CurrentUser;
    current_membership: CurrentMembership | null;
  }>().props;
  const { url } = usePage();
  const { t } = useTranslation();

  const displayName = current_user.name || current_user.email;
  const items = navItemsFor(current_membership, t);
  const currentPath = url.split('?')[0];

  return (
    <>
      <Head title={title} />
      <div className="min-h-screen">
        <header className="border-b border-gray-200 dark:border-gray-800">
          <div className={`${containerClass} py-3 flex items-center justify-between gap-3`}>
            <div className="flex items-center gap-6 min-w-0">
              <Link href="/dashboard" className="text-base font-semibold shrink-0">
                WebTemplate
              </Link>
              <nav aria-label={t('common.mainNav')} className="hidden md:flex items-center gap-1">
                {items.map((item) => (
                  <PrimaryNavLink key={item.href} item={item} active={isActive(currentPath, item.href)} />
                ))}
              </nav>
            </div>

            <div className="flex items-center gap-2">
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

/**
 * Top-nav items. Extend this with role-aware items as the app grows —
 * gate visibility on `membership.role` (passed in from `usePage`) and
 * add entries to the returned list.
 */
function navItemsFor(_membership: CurrentMembership | null, t: TFunction): NavItem[] {
  return [{ href: '/dashboard', label: t('common.dashboard'), icon: LayoutDashboard }];
}

function isActive(currentPath: string, itemHref: string): boolean {
  if (itemHref === '/dashboard') return currentPath === '/dashboard';
  return currentPath === itemHref || currentPath.startsWith(`${itemHref}/`);
}

function PrimaryNavLink({ item, active }: { item: NavItem; active: boolean }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      aria-current={active ? 'page' : undefined}
      className={`inline-flex items-center gap-1.5 rounded px-3 py-1.5 text-sm focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary ${
        active ? 'bg-gray-100 dark:bg-gray-800 font-medium' : 'hover:bg-gray-50 dark:hover:bg-gray-900'
      }`}
    >
      <Icon className="w-4 h-4" aria-hidden="true" />
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
        className="flex items-center gap-1.5 rounded px-2 py-1.5 text-sm cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
      >
        <CircleUserRound className="w-5 h-5" aria-hidden="true" />
        <span className="sr-only sm:not-sr-only truncate max-w-[10rem]">{displayName}</span>
        <ChevronDown className="w-4 h-4" aria-hidden="true" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-56">
        <div className="px-3 py-2 border-b border-gray-200 dark:border-gray-700">
          <p className="text-sm font-medium truncate">{displayName}</p>
        </div>

        {/* Primary nav fallback — only visible when the desktop nav is hidden. */}
        <div className="md:hidden">
          {mobileNavItems.map((item) => {
            const Icon = item.icon;
            return (
              <DropdownMenuItem key={item.href} onSelect={() => router.visit(item.href)}>
                <Icon className="w-4 h-4" aria-hidden="true" />
                <span className="flex-1">{item.label}</span>
              </DropdownMenuItem>
            );
          })}
          <DropdownMenuSeparator className="my-1 h-px bg-gray-200 dark:bg-gray-700" />
        </div>

        <DropdownMenuItem onSelect={() => router.visit('/settings')}>
          <Settings className="w-4 h-4" aria-hidden="true" />
          <span className="flex-1">{t('common.settings')}</span>
        </DropdownMenuItem>
        <DropdownMenuSeparator className="my-1 h-px bg-gray-200 dark:bg-gray-700" />
        <DropdownMenuItem onSelect={() => router.delete('/logout')}>
          <LogOut className="w-4 h-4" aria-hidden="true" />
          <span className="flex-1">{t('common.logout')}</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
