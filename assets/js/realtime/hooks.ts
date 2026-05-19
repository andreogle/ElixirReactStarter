import type { Channel, Socket } from 'phoenix';
import { useContext, useEffect, useRef } from 'react';
import { RealtimeContext } from './provider';
import type { ChannelEntry, ChannelStatus, ConnectionStatus } from './types';

function useRealtime() {
  return useContext(RealtimeContext);
}

/** Underlying Phoenix.Socket, or null when not connected / during SSR. */
export function useSocket(): Socket | null {
  return useRealtime()?.socket ?? null;
}

/** Connection status — drive 'Reconnecting...' banners or indicator dots. */
export function useConnectionStatus(): ConnectionStatus {
  return useRealtime()?.status ?? 'idle';
}

/** Auto-joined `global` channel — null until joined / during SSR. */
export function useGlobalChannel(): Channel | null {
  return useRealtime()?.globalChannel ?? null;
}

/** Auto-joined `user:<own_id>` channel — null until joined / during SSR. */
export function useUserChannel(): Channel | null {
  return useRealtime()?.userChannel ?? null;
}

/**
 * Joins `topic` for the lifetime of the calling component. Multiple
 * components asking for the same topic share a single Phoenix.Channel
 * (ref-counted by the provider) — the channel only leaves when the
 * last consumer unmounts.
 *
 * Pass `null` to opt out (e.g. while waiting for an id to load).
 */
export function useChannel(topic: string | null): {
  channel: Channel | null;
  status: ChannelStatus;
  error: ChannelEntry['error'];
} {
  const ctx = useRealtime();
  const joinChannel = ctx?.joinChannel;
  const leaveChannel = ctx?.leaveChannel;

  useEffect(() => {
    if (!joinChannel || !leaveChannel || !topic) return;
    joinChannel(topic);
    return () => leaveChannel(topic);
  }, [joinChannel, leaveChannel, topic]);

  if (!ctx || !topic) return { channel: null, status: 'left', error: null };
  const entry = ctx.channels[topic];
  if (!entry) return { channel: null, status: 'joining', error: null };
  return { channel: entry.channel, status: entry.status, error: entry.error };
}

/**
 * Subscribes `handler` to `event` on `channel`. Auto-unsubscribes on
 * unmount or when the channel changes. Handler is held in a ref so
 * passing a freshly-created arrow function on each render doesn't
 * resubscribe.
 */
export function useChannelEvent<T = unknown>(
  channel: Channel | null,
  event: string,
  handler: (payload: T) => void
): void {
  const handlerRef = useRef(handler);
  useEffect(() => {
    handlerRef.current = handler;
  });

  useEffect(() => {
    if (!channel) return;
    const ref = channel.on(event, (payload: T) => handlerRef.current(payload));
    return () => channel.off(event, ref);
  }, [channel, event]);
}

/** Convenience over `useChannelEvent` for the auto-joined `global` channel. */
export function useGlobalEvent<T = unknown>(event: string, handler: (payload: T) => void): void {
  useChannelEvent<T>(useGlobalChannel(), event, handler);
}

/** Convenience over `useChannelEvent` for the auto-joined `user:` channel. */
export function useUserEvent<T = unknown>(event: string, handler: (payload: T) => void): void {
  useChannelEvent<T>(useUserChannel(), event, handler);
}

/**
 * Promisified `channel.push(...)`. Phoenix's native API uses a chained
 * `.receive("ok"|"error"|"timeout")` builder; this wraps it so callers
 * can `await` the reply.
 */
export function pushChannel<T = unknown>(
  channel: Channel,
  event: string,
  payload: object = {},
  timeout?: number
): Promise<T> {
  return new Promise((resolve, reject) => {
    const push = timeout === undefined ? channel.push(event, payload) : channel.push(event, payload, timeout);

    push
      .receive('ok', (response: T) => resolve(response))
      .receive('error', (reply: { reason?: string }) => reject(new Error(reply.reason ?? 'channel push failed')))
      .receive('timeout', () => reject(new Error('channel push timed out')));
  });
}
