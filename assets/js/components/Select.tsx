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
        className={`flex w-full cursor-pointer items-center justify-between gap-2 rounded border border-gray-300 bg-white px-3 py-2 text-left text-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:cursor-not-allowed disabled:opacity-50 data-[placeholder]:text-gray-400 dark:border-gray-700 dark:bg-gray-900 ${className}`}
        {...ariaProps}
      >
        <RadixSelect.Value placeholder={placeholder} />
        <RadixSelect.Icon asChild>
          <ChevronDown className="size-4 shrink-0 text-gray-500" />
        </RadixSelect.Icon>
      </RadixSelect.Trigger>
      <RadixSelect.Portal>
        <RadixSelect.Content
          position="popper"
          sideOffset={4}
          className="z-50 max-h-(--radix-select-content-available-height) min-w-(--radix-select-trigger-width) overflow-hidden rounded border border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900"
        >
          <RadixSelect.ScrollUpButton className="flex items-center justify-center py-1 text-gray-500">
            <ChevronUp className="size-4" />
          </RadixSelect.ScrollUpButton>
          <RadixSelect.Viewport className="p-1">
            {options.map((opt) => (
              <RadixSelect.Item
                key={opt.value}
                value={opt.value}
                className="flex cursor-pointer select-none items-center justify-between gap-2 rounded px-3 py-2 text-sm outline-none data-[highlighted]:bg-gray-100 data-[state=checked]:font-medium dark:data-[highlighted]:bg-gray-800"
              >
                <RadixSelect.ItemText>{opt.label}</RadixSelect.ItemText>
                <RadixSelect.ItemIndicator>
                  <Check className="size-4 text-primary" />
                </RadixSelect.ItemIndicator>
              </RadixSelect.Item>
            ))}
          </RadixSelect.Viewport>
          <RadixSelect.ScrollDownButton className="flex items-center justify-center py-1 text-gray-500">
            <ChevronDown className="size-4" />
          </RadixSelect.ScrollDownButton>
        </RadixSelect.Content>
      </RadixSelect.Portal>
    </RadixSelect.Root>
  );
}
