import { router, usePage } from '@inertiajs/react';
import { Check } from 'lucide-react';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from './DropdownMenu';

interface LocaleSelectorProps {
  className?: string;
}

const locales = [
  { code: 'en', label: 'English', flag: FlagGB },
  { code: 'es', label: 'Español', flag: FlagES },
];

export default function LocaleSelector({ className = '' }: LocaleSelectorProps) {
  const { locale } = usePage().props;
  const current = locales.find((l) => l.code === locale) || locales[0];

  function handleSelect(code: string) {
    if (code !== locale) {
      router.put(
        '/settings/locale',
        { locale: code },
        {
          preserveScroll: true,
          onSuccess: () => window.location.reload(),
        }
      );
    }
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        aria-label="Change language"
        className={`flex items-center gap-1.5 rounded px-1.5 py-1 text-sm cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary ${className}`}
      >
        <current.flag className="w-5 h-4 rounded-sm" />
        <ChevronDown className="w-3.5 h-3.5" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-40">
        {locales.map(({ code, label, flag: Flag }) => (
          <DropdownMenuItem
            key={code}
            onSelect={() => handleSelect(code)}
            className={code === locale ? 'text-primary font-medium' : ''}
          >
            <Flag className="w-5 h-4 rounded-sm shrink-0" />
            <span className="flex-1">{label}</span>
            {code === locale && <Check className="w-4 h-4 text-primary" aria-hidden="true" />}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

// =============================================================================
// Inline flag SVGs
// =============================================================================
function FlagGB({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 640 480" className={className} aria-hidden="true">
      <path fill="#012169" d="M0 0h640v480H0z" />
      <path fill="#fff" d="m75 0 244 181L562 0h78v62L400 241l240 178v61h-80L320 301 81 480H0v-60l239-178L0 64V0z" />
      <path
        fill="#C8102E"
        d="m424 281 216 159v40L369 281zm-184 20 6 35L54 480H0zM640 0v3L391 191l2-44L590 0zM0 0l239 176h-60L0 42z"
      />
      <path fill="#fff" d="M241 0v480h160V0zM0 160v160h640V160z" />
      <path fill="#C8102E" d="M0 193v96h640v-96zM273 0v480h96V0z" />
    </svg>
  );
}

function FlagES({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 640 480" className={className} aria-hidden="true">
      <path fill="#c60b1e" d="M0 0h640v480H0z" />
      <path fill="#ffc400" d="M0 120h640v240H0z" />
    </svg>
  );
}

function ChevronDown({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" fill="currentColor" className={className} aria-hidden="true">
      <path
        fillRule="evenodd"
        d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
        clipRule="evenodd"
      />
    </svg>
  );
}
