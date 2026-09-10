import * as RadixToast from '@radix-ui/react-toast';
import { CircleAlert, CircleCheck, Info, X } from 'lucide-react';
import type { ComponentType, SVGProps } from 'react';
import { dismissToast, type ToastVariant, useToasts } from './toast.ts';

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
              if (!open) {
                dismissToast(id);
              }
            }}
            className="pointer-events-auto flex items-start gap-3 rounded border border-gray-200 bg-white p-4 dark:border-gray-800 dark:bg-gray-900"
          >
            <Icon className={`mt-0.5 size-5 shrink-0 ${iconColor[variant]}`} aria-hidden="true" />
            <RadixToast.Description className="flex-1 text-sm">{description}</RadixToast.Description>
            <RadixToast.Close
              aria-label="Dismiss"
              className="shrink-0 cursor-pointer rounded p-0.5 text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800"
            >
              <X className="size-4" aria-hidden="true" />
            </RadixToast.Close>
          </RadixToast.Root>
        );
      })}
      {/* biome-ignore lint/nursery/noTailwindArbitraryValue: viewport-relative cap has no utility form. */}
      <RadixToast.Viewport className="fixed right-4 bottom-4 z-50 flex w-96 max-w-[calc(100vw-2rem)] flex-col gap-2 outline-none" />
    </RadixToast.Provider>
  );
}
