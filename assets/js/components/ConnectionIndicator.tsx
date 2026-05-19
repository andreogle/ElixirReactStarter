import { useConnectionStatus } from '../realtime/hooks';
import { Tooltip, TooltipContent, TooltipTrigger } from './Tooltip';

/**
 * Status dot for the realtime socket. Slow-pulsing green when
 * connected, steady red otherwise. The colour state is mirrored in
 * the tooltip and the `aria-label` so the indicator works without
 * vision or pointer hover.
 */
export default function ConnectionIndicator() {
  const status = useConnectionStatus();
  const connected = status === 'connected';
  const label = connected ? 'Connected' : 'Disconnected';

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span
          role="status"
          aria-label={label}
          className={`inline-block w-2.5 h-2.5 rounded-full ${
            connected ? 'bg-green-500 animate-slow-pulse' : 'bg-red-500'
          }`}
        />
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}
