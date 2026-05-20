import * as RadixPopover from '@radix-ui/react-popover';
import { Check, ChevronDown, Search } from 'lucide-react';
import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';

export interface TimezoneOption {
  value: string;
  label: string;
}

interface TimezoneSelectProps {
  id?: string;
  value: string;
  onValueChange: (value: string) => void;
  options: TimezoneOption[];
  placeholder?: string;
  disabled?: boolean;
  'aria-label'?: string;
  'aria-labelledby'?: string;
  className?: string;
}

/**
 * Searchable combobox for IANA timezone selection. Built on Radix
 * Popover for floating behaviour + outside-click; the combobox ARIA
 * pattern is implemented by hand (Radix ships a Select but not a
 * Combobox, and we deliberately avoid pulling in a heavier library
 * like cmdk or react-aria-components for one field).
 *
 * Keyboard:
 *   - ↓ / ↑ moves `aria-activedescendant` through filtered options
 *   - Enter selects the highlighted option
 *   - Escape closes the popover (returns focus to the trigger)
 *   - Typing filters the list; clearing the query restores the full list
 *
 * Matches the call-site shape of `<Select>` (same props) so consumers
 * can swap in place.
 */
export default function TimezoneSelect({
  id,
  value,
  onValueChange,
  options,
  placeholder,
  disabled,
  className = '',
  ...ariaProps
}: TimezoneSelectProps) {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [activeIndex, setActiveIndex] = useState(0);

  const listboxId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const activeOptionRef = useRef<HTMLDivElement>(null);

  const filtered = useMemo(() => filterOptions(options, query), [options, query]);
  const selected = useMemo(() => options.find((o) => o.value === value), [options, value]);

  // Scroll the active option into view when the highlight moves.
  useEffect(() => {
    if (open && activeOptionRef.current) {
      activeOptionRef.current.scrollIntoView({ block: 'nearest' });
    }
  }, [open]);

  // When the popover opens, put focus in the search field and preselect
  // the currently-chosen value (so ↓ moves from "today's zone" rather
  // than from the top of the alphabet).
  function handleOpenChange(nextOpen: boolean) {
    setOpen(nextOpen);
    if (nextOpen) {
      setQuery('');
      const preselectIndex = selected ? options.findIndex((o) => o.value === selected.value) : 0;
      setActiveIndex(Math.max(preselectIndex, 0));
      // Focus the input after the popover has mounted.
      requestAnimationFrame(() => inputRef.current?.focus());
    }
  }

  function commit(option: TimezoneOption) {
    onValueChange(option.value);
    setOpen(false);
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActiveIndex((i) => Math.min(i + 1, filtered.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActiveIndex((i) => Math.max(i - 1, 0));
    } else if (e.key === 'Home') {
      e.preventDefault();
      setActiveIndex(0);
    } else if (e.key === 'End') {
      e.preventDefault();
      setActiveIndex(Math.max(filtered.length - 1, 0));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      const option = filtered[activeIndex];
      if (option) commit(option);
    } else if (e.key === 'Escape') {
      e.preventDefault();
      setOpen(false);
    }
  }

  const triggerLabel = selected?.label ?? placeholder ?? t('common.select');

  return (
    <RadixPopover.Root open={open} onOpenChange={handleOpenChange}>
      <RadixPopover.Trigger
        id={id}
        type="button"
        role="combobox"
        aria-expanded={open}
        aria-haspopup="listbox"
        aria-controls={open ? listboxId : undefined}
        disabled={disabled}
        className={`w-full flex items-center justify-between gap-2 rounded border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-900 px-3 py-2 text-sm text-left cursor-pointer focus:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50 disabled:cursor-not-allowed ${selected ? '' : 'text-gray-400'} ${className}`}
        {...ariaProps}
      >
        <span className="truncate">{triggerLabel}</span>
        <ChevronDown className="w-4 h-4 text-gray-500 shrink-0" aria-hidden="true" />
      </RadixPopover.Trigger>
      <RadixPopover.Portal>
        <RadixPopover.Content
          align="start"
          sideOffset={4}
          collisionPadding={8}
          className="z-50 w-[var(--radix-popover-trigger-width)] max-h-[min(24rem,var(--radix-popover-content-available-height))] overflow-hidden rounded border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900"
          onOpenAutoFocus={(e) => e.preventDefault()}
        >
          <div className="flex items-center gap-2 border-b border-gray-200 dark:border-gray-800 px-3 py-2">
            <Search className="w-4 h-4 text-gray-500 shrink-0" aria-hidden="true" />
            <input
              ref={inputRef}
              type="text"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                // Reset the highlight so ArrowDown starts from the top
                // of the newly filtered list instead of pointing past
                // the end.
                setActiveIndex(0);
              }}
              onKeyDown={handleKeyDown}
              aria-label={t('common.searchTimezones')}
              aria-controls={listboxId}
              aria-activedescendant={filtered[activeIndex] ? optionId(listboxId, activeIndex) : undefined}
              placeholder={t('common.searchTimezonesPlaceholder')}
              className="flex-1 bg-transparent text-sm outline-none"
              autoComplete="off"
              spellCheck={false}
            />
          </div>
          <div
            id={listboxId}
            // WAI-ARIA combobox pattern: listbox + options have the
            // roles, but focus stays on the input (navigation via
            // aria-activedescendant), so <div> here is cleaner than
            // <ul>/<li> with biome-ignore for unfocusable options.
            role="listbox"
            aria-label={t('common.timezones')}
            className="max-h-80 overflow-y-auto p-1"
          >
            {filtered.length === 0 ? (
              <div className="px-3 py-2 text-sm italic text-gray-500">{t('common.noResults')}</div>
            ) : (
              filtered.map((opt, i) => {
                const isActive = i === activeIndex;
                const isSelected = opt.value === value;
                return (
                  // biome-ignore lint/a11y/useFocusableInteractive: combobox options are intentionally unfocusable — nav is via aria-activedescendant on the input.
                  // biome-ignore lint/a11y/useKeyWithClickEvents: keyboard handling lives on the input (Enter commits the aria-activedescendant).
                  <div
                    key={opt.value}
                    ref={isActive ? activeOptionRef : undefined}
                    id={optionId(listboxId, i)}
                    role="option"
                    aria-selected={isSelected}
                    onMouseEnter={() => setActiveIndex(i)}
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={() => commit(opt)}
                    className={`flex items-center justify-between gap-2 px-3 py-2 rounded text-sm cursor-pointer select-none ${isActive ? 'bg-gray-100 dark:bg-gray-800' : ''} ${isSelected ? 'font-medium' : ''}`}
                  >
                    <span className="truncate">{opt.label}</span>
                    {isSelected && <Check className="w-4 h-4 text-primary shrink-0" aria-hidden="true" />}
                  </div>
                );
              })
            )}
          </div>
        </RadixPopover.Content>
      </RadixPopover.Portal>
    </RadixPopover.Root>
  );
}

function filterOptions(options: TimezoneOption[], query: string): TimezoneOption[] {
  if (!query.trim()) return options;
  const q = query.toLowerCase();
  return options.filter((o) => o.label.toLowerCase().includes(q));
}

function optionId(listboxId: string, index: number): string {
  return `${listboxId}-opt-${index}`;
}
