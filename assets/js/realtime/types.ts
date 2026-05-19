import type { Channel } from 'phoenix';

/**
 * Connection-level state for the underlying Phoenix.Socket.
 *
 * - `idle`: no socket exists yet (e.g. unauthenticated, SSR).
 * - `connecting`: socket created but WebSocket not yet open, or
 *   reconnecting after a drop.
 * - `connected`: WebSocket open and ready for channel joins.
 * - `disconnected`: socket exists but WebSocket is closed
 *   (typically transient while Phoenix's auto-reconnect backs off).
 * - `errored`: terminal failure, usually because the auth token was
 *   rejected. The provider only retries when a fresh token arrives
 *   via Inertia props.
 */
export type ConnectionStatus = 'idle' | 'connecting' | 'connected' | 'disconnected' | 'errored';

/**
 * Per-channel join state, mirrored to consumers via `useChannel`.
 */
export type ChannelStatus = 'joining' | 'joined' | 'errored' | 'left';

export interface ChannelError {
  reason: string;
}

export interface ChannelEntry {
  channel: Channel;
  status: ChannelStatus;
  error: ChannelError | null;
}
