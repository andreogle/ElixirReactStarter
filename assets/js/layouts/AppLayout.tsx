import { Head, router, usePage } from '@inertiajs/react';
import type { TFunction } from 'i18next';
import {
  CalendarDays,
  ChevronDown,
  CircleUserRound,
  GraduationCap,
  LayoutDashboard,
  LogOut,
  Settings,
  ShieldCheck,
  UsersRound,
} from 'lucide-react';
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

// The shell uses one container width across the whole app so switching
// pages (or in-page views) never reflows the chrome. Pages that want
// narrower content can constrain their own inner sections — don't add
// per-page overrides here.
const navContainerClass = 'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8';
const mainContainerClass = 'max-w-6xl mx-auto px-4 sm:px-6 lg:px-8';

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
      <div className="min-h-screen text-charcoal-blue-900 dark:text-charcoal-blue-50">
        <header className="border-b border-blaze-orange-500/15 dark:border-blaze-orange-500/20 bg-page/80 dark:bg-charcoal-blue-950/80 backdrop-blur sticky top-0 z-30">
          <div className={`${navContainerClass} py-3 sm:py-4 flex items-center justify-between gap-3`}>
            <div className="flex items-center gap-6 min-w-0">
              <Link
                href="/dashboard"
                className="text-lg font-bold text-charcoal-blue-900 dark:text-charcoal-blue-50 hover:text-blaze-orange-500 transition shrink-0 tracking-tight"
              >
                WebTemplate
              </Link>
              {/* Desktop nav — collapsed into the avatar dropdown on small screens. */}
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
          <div className={mainContainerClass}>{children}</div>
        </main>
      </div>
    </>
  );
}

// =============================================================================
// Nav items per role
// =============================================================================

/**
 * Role-aware top-nav items. Dashboard is always present; other items only
 * surface when the user has the membership / role to act on them. Admins
 * also see Availability because in small schools (e.g. Ubuntu) the owner
 * usually teaches as well.
 */
function navItemsFor(membership: CurrentMembership | null, t: TFunction): NavItem[] {
  const dashboard: NavItem = { href: '/dashboard', label: t('common.dashboard'), icon: LayoutDashboard };
  if (!membership) return [dashboard];

  const lessons: NavItem = { href: '/lessons', label: t('common.lessons'), icon: GraduationCap };
  const availability: NavItem = {
    href: '/availability',
    label: t('common.availability'),
    icon: CalendarDays,
  };
  const teachers: NavItem = { href: '/teachers', label: t('common.teachers'), icon: UsersRound };
  const members: NavItem = { href: '/admin/members', label: t('common.admin'), icon: ShieldCheck };

  switch (membership.role) {
    case 'owner':
    case 'admin':
      return [dashboard, lessons, members, availability];
    case 'teacher':
      return [dashboard, lessons, availability];
    default: // student, member
      return [dashboard, lessons, teachers];
  }
}

function isActive(currentPath: string, itemHref: string): boolean {
  if (itemHref === '/dashboard') return currentPath === '/dashboard';
  return currentPath === itemHref || currentPath.startsWith(`${itemHref}/`);
}

// =============================================================================
// Desktop primary nav link
// =============================================================================
function PrimaryNavLink({ item, active }: { item: NavItem; active: boolean }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      aria-current={active ? 'page' : undefined}
      className={[
        'inline-flex items-center gap-1.5 rounded-full px-3.5 py-1.5 text-sm font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blaze-orange-500',
        active
          ? 'bg-blaze-orange-500 text-white shadow-sm'
          : 'text-charcoal-blue-700 dark:text-charcoal-blue-50/70 hover:bg-blaze-orange-100/40 dark:hover:bg-blaze-orange-500/15 hover:text-charcoal-blue-900 dark:hover:text-charcoal-blue-50',
      ].join(' ')}
    >
      <Icon className="w-4 h-4" aria-hidden="true" />
      <span>{item.label}</span>
    </Link>
  );
}

// =============================================================================
// Avatar dropdown — Settings + Logout always; primary nav items added on
// small screens so the dropdown stays a complete fallback when the
// horizontal nav is hidden.
// =============================================================================
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
        className="flex items-center gap-1.5 rounded-full px-2 py-1.5 text-sm font-semibold text-charcoal-blue-700 dark:text-charcoal-blue-50/80 hover:bg-blaze-orange-100/40 dark:hover:bg-blaze-orange-500/15 hover:text-charcoal-blue-900 dark:hover:text-charcoal-blue-50 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blaze-orange-500 transition"
      >
        <CircleUserRound className="w-5 h-5 text-blaze-orange-500" aria-hidden="true" />
        <span className="sr-only sm:not-sr-only truncate max-w-[10rem]">{displayName}</span>
        <ChevronDown className="w-4 h-4 text-charcoal-blue-700 dark:text-charcoal-blue-50/70" aria-hidden="true" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-56">
        <div className="px-3 py-2 border-b border-blaze-orange-500/15 dark:border-blaze-orange-500/20">
          <p className="text-sm font-semibold text-charcoal-blue-900 dark:text-charcoal-blue-50 truncate">
            {displayName}
          </p>
        </div>

        {/* Primary nav fallback — only visible when the desktop nav is hidden. */}
        <div className="md:hidden">
          {mobileNavItems.map((item) => {
            const Icon = item.icon;
            return (
              <DropdownMenuItem key={item.href} onSelect={() => router.visit(item.href)}>
                <Icon className="w-4 h-4 text-blaze-orange-500" aria-hidden="true" />
                <span className="flex-1">{item.label}</span>
              </DropdownMenuItem>
            );
          })}
          <DropdownMenuSeparator className="my-1 h-px bg-blaze-orange-500/15 dark:bg-blaze-orange-500/20" />
        </div>

        <DropdownMenuItem onSelect={() => router.visit('/settings')}>
          <Settings className="w-4 h-4 text-blaze-orange-500" aria-hidden="true" />
          <span className="flex-1">{t('common.settings')}</span>
        </DropdownMenuItem>
        <DropdownMenuSeparator className="my-1 h-px bg-blaze-orange-500/15 dark:bg-blaze-orange-500/20" />
        <DropdownMenuItem onSelect={() => router.delete('/logout')}>
          <LogOut className="w-4 h-4 text-blaze-orange-500" aria-hidden="true" />
          <span className="flex-1">{t('common.logout')}</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
