defmodule ElixirReactStarterWeb.UserAuth do
  @moduledoc """
  Session-based authentication: the browser-pipeline plugs plus the
  log-in/log-out helpers controllers call.

  ## Plugs

    * `fetch_current_user/2` — resolves the session token to a user
      (sliding the 60-day expiry forward on activity) and assigns
      `:current_user` and `:locale`.
    * `require_authenticated_user/2` — gate for authenticated routes;
      redirects to `/login`, stashing the requested GET path so log-in
      can return the user there afterwards.
    * `redirect_if_user_is_authenticated/2` — gate for guest-only routes
      (login, register, …); bounces signed-in users to `/dashboard`.

  ## Session handling

  `log_in_user/2` reads any stored return-to path, then renews the
  session (a fresh session id — fixation defence) before storing the new
  token; `log_out_user/1` deletes the token and renews again. Stored
  return-to paths are validated as local (`/…`, never `//…`) to prevent
  open redirects, and only GET requests are stored so a redirect can't
  replay a state-changing action.

  ## Locale precedence

  `fetch_current_user/2` resolves the request locale as: `user.locale`
  (authenticated) → `locale` cookie → first supported `Accept-Language`
  match → the configured default, then hands it to Gettext.
  """

  import Plug.Conn
  import Phoenix.Controller

  use Gettext, backend: ElixirReactStarterWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: ElixirReactStarterWeb.Endpoint,
    router: ElixirReactStarterWeb.Router

  alias ElixirReactStarter.Accounts

  @session_key "user_token"
  # Where we stash the URL the user was trying to reach when we bounced
  # them to /login. Read once by `log_in_user/2`, then cleared by
  # `renew_session/1` (which wipes the whole session).
  @return_to_key "user_return_to"
  @supported_locales Application.compile_env(:elixir_react_starter, :supported_locales, ["en"])
  @default_locale Application.compile_env(:elixir_react_starter, :default_locale, "en")

  # =============================================================================
  # Plugs
  # =============================================================================
  @doc """
  Reads the session token and assigns the current user (or nil) to the
  conn. Resolves the request locale and hands it to Gettext.
  """
  def fetch_current_user(conn, _opts) do
    token = get_session(conn, @session_key)
    user = token && Accounts.get_user_by_session_token(token)
    conn = fetch_cookies(conn)
    locale = request_locale(conn, user)
    _ = Gettext.put_locale(ElixirReactStarterWeb.Gettext, locale)

    conn
    |> assign(:current_user, user)
    |> assign(:locale, locale)
  end

  # Precedence:
  #   1. user.locale — persisted preference, follows authenticated
  #      users across devices and sessions.
  #   2. "locale" cookie — anonymous users' last choice; also persists
  #      across logout so the next visit honours it.
  #   3. Accept-Language header — first supported-locale match.
  #   4. @default_locale fallback.
  defp request_locale(_conn, %{locale: locale}) when locale in @supported_locales, do: locale

  defp request_locale(conn, _user) do
    case conn.cookies["locale"] do
      locale when locale in @supported_locales ->
        locale

      _ ->
        case get_req_header(conn, "accept-language") do
          [header | _] -> parse_accept_language(header)
          _ -> @default_locale
        end
    end
  end

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn tag -> tag |> String.split(";") |> List.first() |> String.slice(0, 2) end)
    |> Enum.find(@default_locale, &(&1 in @supported_locales))
  end

  @doc """
  Requires the user to be authenticated. Redirects to /login otherwise.

  Stashes the requested path in the session as `user_return_to` so
  `log_in_user/2` can bounce the user there after a successful login.
  Only GET requests are saved — re-issuing a POST/PUT/DELETE after
  login would replay state-changing actions silently. Only local paths
  are saved (open-redirect guard).
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> put_flash(:error, dgettext("app", "You must log in to access this page."))
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  defp maybe_store_return_to(%Plug.Conn{method: "GET"} = conn) do
    path = current_path(conn)
    if local_path?(path), do: put_session(conn, @return_to_key, path), else: conn
  end

  defp maybe_store_return_to(conn), do: conn

  # Local paths only: must start with "/" but not "//" (protocol-relative
  # URLs like "//evil.com/path" parse as the host "evil.com", which the
  # browser would treat as an external redirect).
  defp local_path?("//" <> _), do: false
  defp local_path?("/" <> _), do: true
  defp local_path?(_), do: false

  @doc """
  Redirects authenticated users away from guest-only pages (login,
  register).
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/dashboard")
      |> halt()
    else
      conn
    end
  end

  # =============================================================================
  # Helpers for controllers
  # =============================================================================
  @doc """
  Logs the user in by generating a session token, renewing the session,
  and redirecting either to `user_return_to` (if `require_authenticated_user`
  stored one) or to /dashboard.

  Reads `user_return_to` BEFORE `renew_session/1`, which clears the
  whole session, including that key.
  """
  def log_in_user(conn, user) do
    token = Accounts.generate_user_session_token(user)
    return_to = get_session(conn, @return_to_key)

    conn
    |> renew_session()
    |> put_session(@session_key, token)
    |> redirect(to: return_to || ~p"/dashboard")
  end

  @doc """
  Logs the user out by deleting the token from the database and
  clearing the session.
  """
  def log_out_user(conn) do
    token = get_session(conn, @session_key)
    token && Accounts.delete_user_session_token(token)

    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  @doc """
  Renews the session by deleting the CSRF token, renewing the session
  ID, and clearing all session data.
  """
  def renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
