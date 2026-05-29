import type { ButtonHTMLAttributes } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'dangerOutline';
}

const base =
  'inline-flex items-center justify-center rounded px-4 py-2 text-sm font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 disabled:opacity-50 disabled:cursor-not-allowed';

const variants: Record<NonNullable<ButtonProps['variant']>, string> = {
  primary: 'bg-primary text-white hover:opacity-90 focus-visible:outline-primary',
  secondary:
    'border border-gray-300 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 focus-visible:outline-gray-500',
  danger: 'bg-red-600 text-white hover:bg-red-700 focus-visible:outline-red-500',
  dangerOutline:
    'border border-red-300 text-red-700 dark:border-red-700 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 focus-visible:outline-red-500',
};

export default function Button({ variant = 'primary', className = '', type = 'button', ...rest }: ButtonProps) {
  return <button type={type} className={`${base} ${variants[variant]} ${className}`} {...rest} />;
}
