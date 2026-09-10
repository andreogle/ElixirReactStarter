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
        className={`z-50 min-w-40 overflow-hidden rounded border border-gray-200 bg-white py-1 dark:border-gray-800 dark:bg-gray-900 ${className}`}
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
      className={`flex cursor-pointer select-none items-center gap-2 px-3 py-2 text-sm outline-none data-[disabled]:pointer-events-none data-[highlighted]:bg-gray-100 data-[disabled]:opacity-50 dark:data-[highlighted]:bg-gray-800 ${className}`}
      {...props}
    />
  );
}
