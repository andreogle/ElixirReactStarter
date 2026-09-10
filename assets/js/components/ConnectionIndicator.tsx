import { useTranslation } from 'react-i18next';
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
  const { t } = useTranslation();
  const label = connected ? t('common.connected') : t('common.disconnected');

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span
          role="status"
          aria-label={label}
          className={`inline-block size-2.5 rounded-full ${
            connected ? 'animate-slow-pulse bg-green-500' : 'bg-red-500'
          }`}
        />
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}
