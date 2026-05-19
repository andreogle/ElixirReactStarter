import { Socket } from 'phoenix';

/**
 * Builds (but does not yet connect) a Phoenix.Socket for the app.
 * The provider owns the connect/disconnect lifecycle; this is just
 * the factory.
 */
export function createSocket(token: string): Socket {
  return new Socket('/socket', {
    params: { token },
    // Phoenix's default reconnect backoff is fine: 1s, 2s, 5s, 10s,
    // then 10s forever. If the auth token is bad we don't want to
    // retry — the provider tears the socket down on `errored` and
    // waits for a new token from the next page load.
  });
}
