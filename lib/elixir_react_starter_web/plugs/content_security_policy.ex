defmodule ElixirReactStarterWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Sets a `content-security-policy` header on browser responses and a
  per-request nonce that inline `<script>` tags carry.

  ## Profiles

  Two profiles, selected by the `:content_security_policy` app config
  (defaults to `:relaxed`; prod sets `:strict` in config/prod.exs):

    * `:strict` — nonce + `strict-dynamic` for scripts. Only the inline
      scripts we emit (with the nonce) and what they load can run; an
      injected `<script>` without the nonce is blocked. Production
      posture.
    * `:relaxed` — allows `unsafe-inline`/`unsafe-eval` and localhost
      websockets so dev tooling (LiveReload, LiveDashboard) keeps
      working. Used in dev/test.

  Both forbid framing (`frame-ancestors 'none'`), plugins
  (`object-src 'none'`), and base-tag hijacking (`base-uri 'self'`).

  ## Portability

  Every directive is built from `'self'`, so the policy follows the
  deploy origin and works on any domain unchanged — as long as
  everything is first-party (this template bundles all JS/CSS/fonts into
  `priv/static`). The socket is same-origin, which `'self'` covers.

  ## Allowing third-party origins

  Adding something served from another origin (a CDN, Google Fonts,
  Stripe.js, an analytics or error-monitoring SDK, an external image
  bucket) means widening the matching directive. Do it without touching
  this module via app config — a keyword list of directive => sources,
  merged into both profiles:

      config :elixir_react_starter, :csp_extra_sources,
        script_src: ["https://js.stripe.com"],
        connect_src: ["https://api.stripe.com"],
        img_src: ["https://cdn.example.com"],
        font_src: ["https://fonts.gstatic.com"],
        style_src: ["https://fonts.googleapis.com"]

  Recognised keys: `:default_src`, `:script_src`, `:style_src`,
  `:img_src`, `:font_src`, `:connect_src`, `:frame_ancestors`,
  `:object_src`, `:base_uri`, `:form_action`.

  ## Nonce

  Exposed as `conn.assigns.csp_nonce`; `root.html.heex` stamps it onto
  the theme-bootstrap script and the app bundle tag. Under
  `strict-dynamic` an un-nonced `<script src>` would be blocked, so both
  must carry it.
  """

  @behaviour Plug

  import Plug.Conn

  @directive_names %{
    default_src: "default-src",
    script_src: "script-src",
    style_src: "style-src",
    img_src: "img-src",
    font_src: "font-src",
    connect_src: "connect-src",
    frame_ancestors: "frame-ancestors",
    object_src: "object-src",
    base_uri: "base-uri",
    form_action: "form-action"
  }

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(mode(), nonce))
  end

  defp mode do
    Application.get_env(:elixir_react_starter, :content_security_policy, :relaxed)
  end

  defp generate_nonce do
    16 |> :crypto.strong_rand_bytes() |> Base.encode64()
  end

  # Builds the header string: base sources per directive, with any
  # per-app `:csp_extra_sources` appended to the matching directive.
  defp policy(mode, nonce) do
    extra = Application.get_env(:elixir_react_starter, :csp_extra_sources, [])

    mode
    |> base_directives(nonce)
    |> Enum.map_join("; ", fn {key, sources} ->
      sources = sources ++ List.wrap(extra[key])
      "#{Map.fetch!(@directive_names, key)} #{Enum.join(sources, " ")}"
    end)
  end

  defp base_directives(:strict, nonce) do
    [
      {:default_src, ["'self'"]},
      # strict-dynamic: trust scripts the nonced bundle loads (its
      # dynamic import() chunks) and ignore host-list/'unsafe-inline'.
      # 'unsafe-inline' + https: are fallbacks for browsers that don't
      # understand strict-dynamic; compliant browsers ignore them.
      {:script_src, ["'nonce-#{nonce}'", "'strict-dynamic'", "'unsafe-inline'", "https:"]},
      # React/Radix set inline style attributes; allow inline styles but
      # keep everything else same-origin.
      {:style_src, ["'self'", "'unsafe-inline'"]},
      {:img_src, ["'self'", "data:"]},
      {:font_src, ["'self'"]},
      # 'self' covers same-origin wss:// for Phoenix channels; wss: keeps
      # it working if the socket is served from another host.
      {:connect_src, ["'self'", "wss:"]},
      {:frame_ancestors, ["'none'"]},
      {:object_src, ["'none'"]},
      {:base_uri, ["'self'"]},
      {:form_action, ["'self'"]}
    ]
  end

  defp base_directives(_relaxed, nonce) do
    [
      {:default_src, ["'self'"]},
      # unsafe-eval for dev tooling; the nonce is still emitted so the
      # same markup works under :strict without changes.
      {:script_src, ["'self'", "'nonce-#{nonce}'", "'unsafe-inline'", "'unsafe-eval'"]},
      {:style_src, ["'self'", "'unsafe-inline'"]},
      {:img_src, ["'self'", "data:"]},
      {:font_src, ["'self'", "data:"]},
      # ws:/wss: + localhost for LiveReload and the LiveDashboard socket.
      {:connect_src, ["'self'", "ws:", "wss:", "http://localhost:*", "http://127.0.0.1:*"]},
      {:frame_ancestors, ["'none'"]},
      {:object_src, ["'none'"]},
      {:base_uri, ["'self'"]},
      {:form_action, ["'self'"]}
    ]
  end
end
