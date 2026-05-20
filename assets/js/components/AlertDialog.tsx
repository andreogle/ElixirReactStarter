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
      <RadixAlertDialog.Overlay className="fixed inset-0 z-50 bg-black/50" />
      <RadixAlertDialog.Content
        className={`fixed left-1/2 top-1/2 z-50 w-full max-w-sm -translate-x-1/2 -translate-y-1/2 rounded border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-6 focus:outline-none ${className}`}
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
  return <RadixAlertDialog.Title className={`text-lg font-medium ${className}`} {...props} />;
}

export function AlertDialogDescription({
  className = '',
  ...props
}: ComponentPropsWithoutRef<typeof RadixAlertDialog.Description>) {
  return (
    <RadixAlertDialog.Description className={`mt-2 text-sm text-gray-600 dark:text-gray-400 ${className}`} {...props} />
  );
}

export function AlertDialogFooter({ className = '', ...props }: ComponentPropsWithoutRef<'div'>) {
  return <div className={`mt-6 flex justify-end gap-3 ${className}`} {...props} />;
}
