import { usePage } from '@inertiajs/react';
import type { Channel, Socket } from 'phoenix';
import { createContext, type ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import { createSocket } from './socket';
import type { ChannelEntry, ChannelStatus, ConnectionStatus } from './types';

export interface RealtimeContextValue {
  socket: Socket | null;
  status: ConnectionStatus;
  /** Auto-joined `global` channel — non-null while connected. */
  globalChannel: Channel | null;
  /** Auto-joined `user:<own_id>` channel — non-null while connected and authed. */
  userChannel: Channel | null;
  /** Snapshot of ad-hoc channels managed by `useChannel(topic)`. */
  channels: Record<string, ChannelEntry>;
  joinChannel: (topic: string) => void;
  leaveChannel: (topic: string) => void;
}

export const RealtimeContext = createContext<RealtimeContextValue | undefined>(undefined);

/**
 * Owns the single Phoenix.Socket the React tree shares.
 *
 * Lifecycle:
 *  1. Reads `socket_token` and `current_user.id` from the latest
 *     Inertia page.
 *  2. When the token or user-id changes, tears down the existing
 *     socket and starts fresh. Handles login, logout, account switch.
 *  3. Auto-joins `global` and `user:<id>` while connected.
 *
 * SSR safety: every side effect is inside `useEffect`, which doesn't
 * run on the server. The provider renders an empty default context
 * during SSR; consumer hooks branch on null.
 */
export function RealtimeProvider({ children }: { children: ReactNode }) {
  const { current_user, socket_token } = usePage().props;

  const userId = current_user?.id ?? null;
  const token = socket_token;

  const [socket, setSocket] = useState<Socket | null>(null);
  const [status, setStatus] = useState<ConnectionStatus>('idle');
  const [globalChannel, setGlobalChannel] = useState<Channel | null>(null);
  const [userChannel, setUserChannel] = useState<Channel | null>(null);
  const [channels, setChannels] = useState<Record<string, ChannelEntry>>({});

  // Ref counts for ad-hoc channels — bookkeeping kept out of state.
  const refCountsRef = useRef<Record<string, number>>({});

  // ===========================================================================
  // Socket lifecycle — keyed on userId only.
  //
  // SharedData mints a fresh socket_token on every page response, so
  // depending on `token` here would tear down and re-create the socket
  // on every Inertia navigation. Instead the effect captures the
  // token-at-login from the closure and reuses it for the life of the
  // session. The token is valid for 7 days (see UserSocket @max_age),
  // well past any normal browsing session. If a user logs out and
  // back in, userId flips through null and the socket is re-created
  // with the fresh token at that point.
  // ===========================================================================
  // biome-ignore lint/correctness/useExhaustiveDependencies: token intentionally excluded — see comment above
  useEffect(() => {
    if (!token || !userId) {
      setStatus('idle');
      return;
    }

    const next = createSocket(token);
    setStatus('connecting');

    next.onOpen(() => setStatus('connected'));
    next.onClose(() => setStatus('disconnected'));
    next.onError(() => setStatus('errored'));

    next.connect();
    setSocket(next);

    return () => {
      next.disconnect();
      setSocket(null);
      setStatus('idle');
      refCountsRef.current = {};
      setChannels({});
      setGlobalChannel(null);
      setUserChannel(null);
    };
  }, [userId]);

  // ===========================================================================
  // Auto-join `global`
  // ===========================================================================
  useEffect(() => {
    if (!socket) {
      setGlobalChannel(null);
      return;
    }

    const channel = socket.channel('global');
    channel.join();
    setGlobalChannel(channel);

    return () => {
      channel.leave();
      setGlobalChannel(null);
    };
  }, [socket]);

  // ===========================================================================
  // Auto-join `user:<id>`
  // ===========================================================================
  useEffect(() => {
    if (!socket || !userId) {
      setUserChannel(null);
      return;
    }

    const channel = socket.channel(`user:${userId}`);
    channel.join();
    setUserChannel(channel);

    return () => {
      channel.leave();
      setUserChannel(null);
    };
  }, [socket, userId]);

  // ===========================================================================
  // Ad-hoc channels via useChannel(topic) — ref-counted join/leave so
  // two components asking for the same topic share one Phoenix Channel.
  // ===========================================================================
  const updateChannelStatus = useCallback((topic: string, nextStatus: ChannelStatus, error: ChannelEntry['error']) => {
    setChannels((prev) => {
      const entry = prev[topic];
      if (!entry) return prev;
      return { ...prev, [topic]: { ...entry, status: nextStatus, error } };
    });
  }, []);

  const joinChannel = useCallback(
    (topic: string) => {
      if (!socket) return;

      const current = refCountsRef.current[topic] ?? 0;
      refCountsRef.current[topic] = current + 1;
      if (current > 0) return;

      const channel = socket.channel(topic);
      setChannels((prev) => ({
        ...prev,
        [topic]: { channel, status: 'joining', error: null },
      }));

      channel
        .join()
        .receive('ok', () => updateChannelStatus(topic, 'joined', null))
        .receive('error', (reply: { reason?: string }) => {
          return updateChannelStatus(topic, 'errored', { reason: reply.reason ?? 'unknown' });
        });
    },
    [socket, updateChannelStatus]
  );

  const leaveChannel = useCallback((topic: string) => {
    const current = refCountsRef.current[topic] ?? 0;
    if (current <= 0) return;

    const next = current - 1;
    refCountsRef.current[topic] = next;
    if (next > 0) return;

    delete refCountsRef.current[topic];

    setChannels((prev) => {
      const entry = prev[topic];
      entry?.channel.leave();
      const { [topic]: _removed, ...rest } = prev;
      return rest;
    });
  }, []);

  const value: RealtimeContextValue = {
    socket,
    status,
    globalChannel,
    userChannel,
    channels,
    joinChannel,
    leaveChannel,
  };

  return <RealtimeContext.Provider value={value}>{children}</RealtimeContext.Provider>;
}
