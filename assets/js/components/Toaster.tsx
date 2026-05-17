import * as RadixToast from '@radix-ui/react-toast';
import { CircleAlert, CircleCheck, Info, X } from 'lucide-react';
import type { ComponentType, SVGProps } from 'react';
import { dismissToast, type ToastVariant, useToasts } from './toast';

const variantClasses: Record<ToastVariant, string> = {
  info: 'border-slate-200 dark:border-slate-700',
  success: 'border-emerald-200 dark:border-emerald-800',
  error: 'border-red-200 dark:border-red-800',
};

const iconFor: Record<ToastVariant, ComponentType<SVGProps<SVGSVGElement>>> = {
  info: Info,
  success: CircleCheck,
  error: CircleAlert,
};

const iconColor: Record<ToastVariant, string> = {
  info: 'text-slate-400',
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
            className={[
              'group pointer-events-auto flex items-start gap-3 rounded-lg border bg-white dark:bg-slate-800 p-4 shadow-lg',
              'data-[state=open]:animate-toast-in',
              'data-[state=closed]:animate-toast-out',
              'data-[swipe=move]:translate-x-(--radix-toast-swipe-move-x) data-[swipe=move]:transition-none',
              'data-[swipe=cancel]:translate-x-0 data-[swipe=cancel]:transition-transform data-[swipe=cancel]:duration-200',
              'data-[swipe=end]:animate-toast-swipe-out',
              variantClasses[variant],
            ].join(' ')}
          >
            <Icon className={`w-5 h-5 shrink-0 mt-0.5 ${iconColor[variant]}`} aria-hidden="true" />
            <RadixToast.Description className="flex-1 text-sm text-slate-700 dark:text-slate-200">
              {description}
            </RadixToast.Description>
            <RadixToast.Close
              aria-label="Dismiss"
              className="shrink-0 rounded-md p-0.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700 dark:hover:bg-slate-700/50 dark:hover:text-slate-200 cursor-pointer transition"
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
