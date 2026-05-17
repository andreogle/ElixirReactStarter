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
          // Prevent the trigger from getting a visible focus ring after the
          // menu closes (Radix's default is to return focus to it). Keyboard
          // users can still Tab to the trigger; callers can override by
          // passing their own handler.
          event.preventDefault();
          onCloseAutoFocus?.(event);
        }}
        className={[
          'z-50 min-w-[10rem] overflow-hidden rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 shadow-lg py-1',
          className,
        ]
          .filter(Boolean)
          .join(' ')}
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
      className={[
        'flex items-center gap-2.5 px-3 py-2 text-sm text-slate-700 dark:text-slate-300 outline-none cursor-pointer select-none',
        'data-[highlighted]:bg-slate-100 dark:data-[highlighted]:bg-slate-700/50 data-[highlighted]:text-slate-900 dark:data-[highlighted]:text-white',
        'data-[disabled]:opacity-50 data-[disabled]:pointer-events-none',
        className,
      ]
        .filter(Boolean)
        .join(' ')}
      {...props}
    />
  );
}
