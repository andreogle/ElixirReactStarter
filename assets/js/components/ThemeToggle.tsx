import type { TFunction } from 'i18next';
import { Check, Monitor, Moon, Sun } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getTheme, setTheme, type Theme } from '../theme';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from './DropdownMenu';

const ICONS: Record<Theme, typeof Sun> = {
  light: Sun,
  dark: Moon,
  system: Monitor,
};

// Literal translate-calls per branch so the i18n key-usage check
// can find each key statically.
function labelFor(theme: Theme, t: TFunction): string {
  switch (theme) {
    case 'light':
      return t('common.themeLight');
    case 'dark':
      return t('common.themeDark');
    case 'system':
      return t('common.themeSystem');
  }
}

export default function ThemeToggle({ className = '' }: { className?: string }) {
  const { t } = useTranslation();
  // SSR-safe: getTheme reads document.cookie. During SSR, default to
  // 'system' and let the client effect resync on mount.
  const [theme, setThemeState] = useState<Theme>('system');

  useEffect(() => {
    setThemeState(getTheme());
  }, []);

  const Current = ICONS[theme];
  const options: Theme[] = ['light', 'dark', 'system'];

  function handleSelect(next: Theme) {
    setTheme(next);
    setThemeState(next);
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        aria-label={t('common.theme')}
        className={`flex items-center justify-center rounded p-1.5 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary ${className}`}
      >
        <Current className="w-4 h-4" aria-hidden="true" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-40">
        {options.map((value) => {
          const Icon = ICONS[value];
          return (
            <DropdownMenuItem key={value} onSelect={() => handleSelect(value)}>
              <Icon className="w-4 h-4" aria-hidden="true" />
              <span className="flex-1">{labelFor(value, t)}</span>
              {theme === value && <Check className="w-4 h-4 text-primary" aria-hidden="true" />}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
