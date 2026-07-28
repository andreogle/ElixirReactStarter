defmodule ElixirReactStarterWeb.Plugs.ClientIp do
  @moduledoc """
  Rewrites `conn.remote_ip` from forwarding headers when the app runs behind
  a trusted proxy, so that anything keyed on the client IP — auth rate
  limiting (`ElixirReactStarterWeb.Plugs.RateLimit`), request logs, Sentry
  request context — sees the real caller rather than the load balancer.

  Wraps `RemoteIp`, which walks the forwarding chain **right-to-left** and
  stops at the first address that isn't a known proxy. That direction is what
  makes it safe: a proxy appends the peer it received the request from, so
  anything a client puts in the header itself ends up to the *left* of the
  real value and is never chosen.

  ## Off by default

  The plug is inert unless `:trust_proxy_headers` is true, and that is
  deliberate. Forwarding headers are trustworthy only when a proxy in front
  of the app overwrites (or appends to) them on every request. Honouring them
  on a directly-exposed server would let any caller set `X-Forwarded-For` and
  mint a fresh identity per request — which would turn IP rate limiting from
  merely coarse into trivially bypassable.

  So: enable it when, and only when, traffic reaches the app through a proxy
  (Render, Fly, an ALB, a k8s ingress, Cloudflare). See the deployment section
  of the README for the environment variables.

  ## Configuration

    * `:trust_proxy_headers` — master switch (default `false`). Set from
      `TRUST_PROXY_HEADERS` in `config/runtime.exs`.

    * `:trusted_proxies` — extra proxy CIDRs, as strings (default `[]`). Set
      from `TRUSTED_PROXIES`. Loopback and the RFC1918 / reserved ranges are
      *always* treated as proxies by `RemoteIp`, so a load balancer that
      reaches the app over a private network needs nothing here. Add public
      ranges only — e.g. Cloudflare's published egress blocks.

    * `:client_ip_headers` — headers to read, lowercase (default
      `#{inspect(["x-forwarded-for"])}`). Set from `CLIENT_IP_HEADERS`. A
      single header is the safe choice: with several enabled, a caller can
      add one the proxy doesn't overwrite and interfere with parsing.

      Behind Cloudflare, set this to `cf-connecting-ip`. Cloudflare's edge
      terminates on a *public* address, so the default `x-forwarded-for`
      walk stops there and reports the edge as the caller — every visitor
      arriving through the same edge then shares one rate-limit bucket.
      `cf-connecting-ip` holds the address Cloudflare already resolved, so
      there is no chain to walk. Listing Cloudflare's published ranges in
      `:trusted_proxies` also works, but that list has to be kept current.
  """

  @behaviour Plug

  @default_headers ["x-forwarded-for"]

  @impl true
  def init(_opts) do
    # MFA options are re-evaluated by RemoteIp on every call, which is what
    # lets a single release read its proxy configuration from the environment
    # at boot — `init/1` runs at compile time in prod, long before
    # runtime.exs has been loaded.
    RemoteIp.init(
      headers: {__MODULE__, :headers, []},
      proxies: {__MODULE__, :proxies, []}
    )
  end

  @impl true
  def call(conn, opts), do: RemoteIp.call(conn, opts)

  @doc false
  # Returning no headers is how the plug switches itself off: with nothing to
  # parse, RemoteIp falls back to `conn.remote_ip` untouched.
  def headers do
    if Application.get_env(:elixir_react_starter, :trust_proxy_headers, false) do
      Application.get_env(:elixir_react_starter, :client_ip_headers, @default_headers)
    else
      []
    end
  end

  @doc false
  def proxies do
    Application.get_env(:elixir_react_starter, :trusted_proxies, [])
  end
end
