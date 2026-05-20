import * as RadixToast from '@radix-ui/react-toast';
import { CircleAlert, CircleCheck, Info, X } from 'lucide-react';
import type { ComponentType, SVGProps } from 'react';
import { dismissToast, type ToastVariant, useToasts } from './toast';

const iconFor: Record<ToastVariant, ComponentType<SVGProps<SVGSVGElement>>> = {
  info: Info,
  success: CircleCheck,
  error: CircleAlert,
};

const iconColor: Record<ToastVariant, string> = {
  info: 'text-gray-500',
  success: 'text-emerald-500',
  error: 'text-red-500',
};

export default function Toaster() {
  const items = useToasts();

  return (
    <RadixToast.Provider swipeDirection="right" duration={5000}>
      {items.map(({ id, description, variant }) => {
        const Icon = iconFor[variant];
        return (
          <RadixToast.Root
            key={id}
            onOpenChange={(open) => {
              if (!open) dismissToast(id);
            }}
            className="pointer-events-auto flex items-start gap-3 rounded border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-4"
          >
            <Icon className={`w-5 h-5 shrink-0 mt-0.5 ${iconColor[variant]}`} aria-hidden="true" />
            <RadixToast.Description className="flex-1 text-sm">{description}</RadixToast.Description>
            <RadixToast.Close
              aria-label="Dismiss"
              className="shrink-0 rounded p-0.5 text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
            >
              <X className="w-4 h-4" aria-hidden="true" />
            </RadixToast.Close>
          </RadixToast.Root>
        );
      })}
      <RadixToast.Viewport className="fixed bottom-4 right-4 z-50 flex w-96 max-w-[calc(100vw-2rem)] flex-col gap-2 outline-none" />
    </RadixToast.Provider>
  );
}
