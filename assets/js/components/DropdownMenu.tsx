import * as RadixDropdownMenu from '@radix-ui/react-dropdown-menu';
import type { ComponentPropsWithoutRef } from 'react';

export const DropdownMenu = RadixDropdownMenu.Root;
export const DropdownMenuTrigger = RadixDropdownMenu.Trigger;
export const DropdownMenuSeparator = RadixDropdownMenu.Separator;

export function DropdownMenuContent({
  className = '',
  sideOffset = 4,
  align = 'end',
  onCloseAutoFocus,
  ...props
}: ComponentPropsWithoutRef<typeof RadixDropdownMenu.Content>) {
  return (
    <RadixDropdownMenu.Portal>
      <RadixDropdownMenu.Content
        sideOffset={sideOffset}
        align={align}
        onCloseAutoFocus={(event) => {
          // Suppress Radix's default focus-ring on the trigger after the
          // menu closes. Keyboard users can still Tab to it.
          event.preventDefault();
          onCloseAutoFocus?.(event);
        }}
        className={`z-50 min-w-[10rem] overflow-hidden rounded border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 py-1 ${className}`}
        {...props}
      />
    </RadixDropdownMenu.Portal>
  );
}

export function DropdownMenuItem({
  className = '',
  ...props
}: ComponentPropsWithoutRef<typeof RadixDropdownMenu.Item>) {
  return (
    <RadixDropdownMenu.Item
      className={`flex items-center gap-2 px-3 py-2 text-sm outline-none cursor-pointer select-none data-[highlighted]:bg-gray-100 dark:data-[highlighted]:bg-gray-800 data-[disabled]:opacity-50 data-[disabled]:pointer-events-none ${className}`}
      {...props}
    />
  );
}
