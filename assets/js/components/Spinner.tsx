type Size = 'xs' | 'sm' | 'md' | 'lg';

interface SpinnerProps {
  size?: Size;
  label?: string;
  className?: string;
}

const sizeClasses: Record<Size, string> = {
  xs: 'w-3 h-3',
  sm: 'w-4 h-4',
  md: 'w-5 h-5',
  lg: 'w-8 h-8',
};

export default function Spinner({ size = 'sm', label, className = '' }: SpinnerProps) {
  return (
    <svg
      role={label ? 'status' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      className={['animate-spin shrink-0', sizeClasses[size], className].filter(Boolean).join(' ')}
      viewBox="0 0 24 24"
      fill="none"
    >
      {label && <title>{label}</title>}
      <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" opacity="0.25" />
      <path fill="currentColor" d="M4 12a8 8 0 0 1 8-8v4a4 4 0 0 0-4 4H4z" opacity="0.75" />
    </svg>
  );
}
