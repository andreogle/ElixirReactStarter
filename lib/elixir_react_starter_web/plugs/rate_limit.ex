defmodule ElixirReactStarterWeb.Plugs.RateLimit do
  @moduledoc """
  Throttles abuse-prone requests (the auth form posts) via
  `ElixirReactStarter.RateLimit`. When the limit is exceeded it sets a
  `Retry-After` header, flashes an error, and redirects back — matching
  the app's redirect-on-error pattern so it works cleanly over Inertia.

  Apply as a controller plug scoped to the relevant actions:

      plug ElixirReactStarterWeb.Plugs.RateLimit,
             [bucket: "auth_ip", limit: 30, scale: :timer.minutes(1)]
           when action in [:login, :register, ...]

  Options:

    * `:bucket` (required) — namespace for this limit.
    * `:limit`  (required) — max requests per window.
    * `:scale`  (required) — window length in milliseconds.
    * `:by` — `:ip` (default) or `:email`. Email-keyed limits are
      proxy-independent and stop targeted abuse such as password-reset
      email bombing; IP-keyed limits guard against broad brute-forcing.

  Disabled when `:rate_limit_enabled` config is `false` — off in dev and
  test (so the Playwright suite isn't throttled), on in prod.

  > #### Behind a proxy {: .warning}
  > `:ip` keying uses `conn.remote_ip`. Behind a load balancer, populate
  > it from the forwarded header (e.g. the `remote_ip` plug) — otherwise
  > every client shares one bucket. The `:email` limits are unaffected.
  """

  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  use Gettext, backend: ElixirReactStarterWeb.Gettext

  alias ElixirReactStarter.RateLimit

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    if Application.get_env(:elixir_react_starter, :rate_limit_enabled, true) do
      throttle(conn, opts)
    else
      conn
    end
  end

  defp throttle(conn, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    limit = Keyword.fetch!(opts, :limit)
    scale = Keyword.fetch!(opts, :scale)
    key = "#{bucket}:#{identifier(conn, Keyword.get(opts, :by, :ip))}"

    case RateLimit.hit(key, scale, limit) do
      {:allow, _count} ->
        conn

      {:deny, retry_after_ms} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(div(retry_after_ms, 1000)))
        |> put_flash(:error, dgettext("app", "Too many attempts. Please try again in a bit."))
        |> redirect(to: conn.request_path)
        |> halt()
    end
  end

  defp identifier(conn, :ip), do: conn.remote_ip |> :inet.ntoa() |> to_string()

  defp identifier(conn, :email) do
    (conn.params["email"] || "") |> to_string() |> String.trim() |> String.downcase()
  end
end
