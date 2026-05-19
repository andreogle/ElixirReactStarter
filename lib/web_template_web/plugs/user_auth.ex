defmodule WebTemplateWeb.UserAuth do
  @moduledoc """
  Plugs and helpers for user authentication via session tokens.
  """

  import Plug.Conn
  import Phoenix.Controller

  use Gettext, backend: WebTemplateWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: WebTemplateWeb.Endpoint,
    router: WebTemplateWeb.Router

  alias WebTemplate.Accounts

  @session_key "user_token"
  # Where we stash the URL the user was trying to reach when we bounced
  # them to /login. Read once by `log_in_user/2`, then cleared by
  # `renew_session/1` (which wipes the whole session).
  @return_to_key "user_return_to"
  @supported_locales Application.compile_env(:web_template, :supported_locales, ["en"])
  @default_locale Application.compile_env(:web_template, :default_locale, "en")

  # =============================================================================
  # Plugs
  # =============================================================================
  @doc """
  Reads the session token and assigns the current user (or nil) to the
  conn. Also resolves the request locale from `Accept-Language` and
  hands it to Gettext.
  """
  def fetch_current_user(conn, _opts) do
    token = get_session(conn, @session_key)
    user = token && Accounts.get_user_by_session_token(token)
    locale = request_locale(conn)
    Gettext.put_locale(WebTemplateWeb.Gettext, locale)

    conn
    |> assign(:current_user, user)
    |> assign(:locale, locale)
  end

  # Precedence:
  #   1. session — set by `SettingsController.update_locale`, survives
  #      across tabs but clears on logout.
  #   2. Accept-Language header — first match against supported locales.
  #   3. @default_locale fallback.
  defp request_locale(conn) do
    case get_session(conn, "locale") do
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
