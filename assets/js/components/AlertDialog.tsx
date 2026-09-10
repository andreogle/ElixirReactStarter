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
        className={`-translate-1/2 fixed top-1/2 left-1/2 z-50 w-full max-w-sm rounded border border-gray-200 bg-white p-6 focus:outline-none dark:border-gray-800 dark:bg-gray-900 ${className}`}
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
  return <RadixAlertDialog.Title className={`font-medium text-lg ${className}`} {...props} />;
}

export function AlertDialogDescription({
  className = '',
  ...props
}: ComponentPropsWithoutRef<typeof RadixAlertDialog.Description>) {
  return (
    <RadixAlertDialog.Description className={`mt-2 text-gray-600 text-sm dark:text-gray-400 ${className}`} {...props} />
  );
}

export function AlertDialogFooter({ className = '', ...props }: ComponentPropsWithoutRef<'div'>) {
  return <div className={`mt-6 flex justify-end gap-3 ${className}`} {...props} />;
}
