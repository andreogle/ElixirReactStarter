import * as RadixAlertDialog from '@radix-ui/react-alert-dialog';
import type { ComponentPropsWithoutRef } from 'react';

export const AlertDialog = RadixAlertDialog.Root;
export const AlertDialogTrigger = RadixAlertDialog.Trigger;
export const AlertDialogCancel = RadixAlertDialog.Cancel;
export const AlertDialogAction = RadixAlertDialog.Action;

export function AlertDialogContent({
  className = '',
  children,
  ...props
}: ComponentPropsWithoutRef<typeof RadixAlertDialog.Content>) {
  return (
    <RadixAlertDialog.Portal>
      <RadixAlertDialog.Overlay className="fixed inset-0 z-50 bg-black/50 backdrop-blur-sm" />
      <RadixAlertDialog.Content
        className={[
          'fixed left-1/2 top-1/2 z-50 w-full max-w-sm -translate-x-1/2 -translate-y-1/2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-6 shadow-xl focus:outline-none',
          className,
        ]
          .filter(Boolean)
          .join(' ')}
        {...props}
      >
        {children}
      </RadixAlertDialog.Content>
    </RadixAlertDialog.Portal>
  );
}

export function AlertDialogTitle({
  className = '',
  ...props
}: ComponentPropsWithoutRef<typeof RadixAlertDialog.Title>) {
  return (
    <RadixAlertDialog.Title
      className={['text-lg font-semibold text-slate-900 dark:text-white', className].filter(Boolean).join(' ')}
      {...props}
    />
  );
}

export function AlertDialogDescription({
  className = '',
  ...props
}: ComponentPropsWithoutRef<typeof RadixAlertDialog.Description>) {
  return (
    <RadixAlertDialog.Description
      className={['text-sm text-slate-500 dark:text-slate-400 mt-2', className].filter(Boolean).join(' ')}
      {...props}
    />
  );
}

export function AlertDialogFooter({ className = '', ...props }: ComponentPropsWithoutRef<'div'>) {
  return <div className={['mt-6 flex justify-end gap-3', className].filter(Boolean).join(' ')} {...props} />;
}
