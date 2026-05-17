import * as RadixSelect from '@radix-ui/react-select';
import { Check, ChevronDown, ChevronUp } from 'lucide-react';
import type { ReactNode } from 'react';

export interface SelectOption {
  value: string;
  label: ReactNode;
}

interface SelectProps {
  id?: string;
  value: string;
  onValueChange: (value: string) => void;
  options: SelectOption[];
  placeholder?: string;
  disabled?: boolean;
  'aria-label'?: string;
  'aria-labelledby'?: string;
  className?: string;
}

export default function Select({
  id,
  value,
  onValueChange,
  options,
  placeholder,
  disabled,
  className = '',
  ...ariaProps
}: SelectProps) {
  return (
    <RadixSelect.Root value={value} onValueChange={onValueChange} disabled={disabled}>
      <RadixSelect.Trigger
        id={id}
        className={[
          'w-full flex items-center justify-between gap-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 px-3.5 py-2.5 text-sm text-left text-slate-900 dark:text-white data-[placeholder]:text-slate-400 cursor-pointer',
          'focus:outline-none focus-visible:ring-2 focus-visible:ring-coral focus-visible:border-transparent',
          'disabled:opacity-50 disabled:cursor-not-allowed transition',
          className,
        ]
          .filter(Boolean)
          .join(' ')}
        {...ariaProps}
      >
        <RadixSelect.Value placeholder={placeholder} />
        <RadixSelect.Icon asChild>
          <ChevronDown className="w-4 h-4 text-slate-400 shrink-0" />
        </RadixSelect.Icon>
      </RadixSelect.Trigger>
      <RadixSelect.Portal>
        <RadixSelect.Content
          position="popper"
          sideOffset={4}
          className="z-50 overflow-hidden rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 shadow-lg min-w-[var(--radix-select-trigger-width)] max-h-[var(--radix-select-content-available-height)]"
        >
          <RadixSelect.ScrollUpButton className="flex items-center justify-center py-1 text-slate-400 bg-white dark:bg-slate-800">
            <ChevronUp className="w-4 h-4" />
          </RadixSelect.ScrollUpButton>
          <RadixSelect.Viewport className="p-1">
            {options.map((opt) => (
              <RadixSelect.Item
                key={opt.value}
                value={opt.value}
                className="relative flex items-center justify-between gap-2 px-3 py-2 rounded-md text-sm text-slate-700 dark:text-slate-200 outline-none cursor-pointer select-none data-[highlighted]:bg-coral/10 data-[highlighted]:text-coral data-[state=checked]:font-medium"
              >
                <RadixSelect.ItemText>{opt.label}</RadixSelect.ItemText>
                <RadixSelect.ItemIndicator>
                  <Check className="w-4 h-4 text-coral" />
                </RadixSelect.ItemIndicator>
              </RadixSelect.Item>
            ))}
          </RadixSelect.Viewport>
          <RadixSelect.ScrollDownButton className="flex items-center justify-center py-1 text-slate-400 bg-white dark:bg-slate-800">
            <ChevronDown className="w-4 h-4" />
          </RadixSelect.ScrollDownButton>
        </RadixSelect.Content>
      </RadixSelect.Portal>
    </RadixSelect.Root>
  );
}
