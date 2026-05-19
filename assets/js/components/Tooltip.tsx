import * as RadixTooltip from '@radix-ui/react-tooltip';
import type { ComponentPropsWithoutRef, ReactNode } from 'react';

export const TooltipProvider = RadixTooltip.Provider;
export const Tooltip = RadixTooltip.Root;
export const TooltipTrigger = RadixTooltip.Trigger;

export function TooltipContent({
  className = '',
  sideOffset = 6,
  children,
  ...props
}: ComponentPropsWithoutRef<typeof RadixTooltip.Content> & { children: ReactNode }) {
  return (
    <RadixTooltip.Portal>
      <RadixTooltip.Content
        sideOffset={sideOffset}
        className={`z-50 rounded bg-gray-900 dark:bg-gray-100 px-2 py-1 text-xs text-white dark:text-gray-900 ${className}`}
        {...props}
      >
        {children}
      </RadixTooltip.Content>
    </RadixTooltip.Portal>
  );
}
