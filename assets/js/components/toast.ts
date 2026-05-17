import { useSyncExternalStore } from 'react';

export type ToastVariant = 'info' | 'success' | 'error';

export interface ToastItem {
  id: string;
  description: string;
  variant: ToastVariant;
}

const listeners = new Set<() => void>();
let items: ToastItem[] = [];

function emit() {
  items = [...items];
  for (const fn of listeners) fn();
}

function subscribe(fn: () => void) {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}

function getSnapshot() {
  return items;
}

function push(item: Omit<ToastItem, 'id'>) {
  items.push({ ...item, id: crypto.randomUUID() });
  emit();
}

export function dismissToast(id: string) {
  items = items.filter((t) => t.id !== id);
  emit();
}

export const toast = {
  info: (description: string) => push({ description, variant: 'info' }),
  success: (description: string) => push({ description, variant: 'success' }),
  error: (description: string) => push({ description, variant: 'error' }),
};

export function useToasts(): ToastItem[] {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot);
}
