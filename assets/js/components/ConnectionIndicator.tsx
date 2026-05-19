import { useConnectionStatus } from '../realtime/hooks';

/**
 * Status dot for the realtime socket.
 *
 *  - `connected` → slow-pulsing green (the app is live)
 *  - anything else → steady red (the app can't reach the server)
 *
 * Use anywhere inside `RealtimeProvider`. Pair with a screen-reader
 * label so the colour isn't the only signal.
 */
export default function ConnectionIndicator() {
  const status = useConnectionStatus();
  const connected = status === 'connected';

  return (
    <span
      role="status"
      aria-label={connected ? 'Connected' : 'Disconnected'}
      title={connected ? 'Connected' : 'Disconnected'}
      className="inline-flex items-center gap-2 text-xs text-gray-600 dark:text-gray-400"
    >
      <span
        aria-hidden="true"
        className={`inline-block w-2.5 h-2.5 rounded-full ${
          connected ? 'bg-green-500 animate-slow-pulse' : 'bg-red-500'
        }`}
      />
      <span>{connected ? 'Live' : 'Offline'}</span>
    </span>
  );
}
