defmodule WebTemplateWeb.SettingsController do
  use WebTemplateWeb, :controller

  alias WebTemplate.Accounts
  alias WebTemplateWeb.UserAuth

  action_fallback WebTemplateWeb.FallbackController

  @supported_locales Application.compile_env(:web_template, :supported_locales, ["en"])

  def show(conn, _params) do
    render_inertia(conn, "Settings")
  end

  # =============================================================================
  # Change locale
  #
  # Persisted on the user row so the preference follows them across
  # devices and sessions. UserAuth.fetch_current_user reads user.locale
  # for every authenticated request.
  # =============================================================================
  def update_locale(conn, %{"locale" => locale}) when locale in @supported_locales do
    user = conn.assigns.current_user

    case Accounts.update_user_locale(user, %{locale: locale}) do
      {:ok, _user} ->
        redirect(conn, to: safe_referer(List.first(get_req_header(conn, "referer"))))

      {:error, _changeset} ->
        {:error, {:bad_request, dgettext("app", "Unsupported locale")}}
    end
  end

  def update_locale(_conn, _params) do
    {:error, {:bad_request, dgettext("app", "Unsupported locale")}}
  end

  defp safe_referer(nil), do: ~p"/dashboard"

  defp safe_referer(referer) do
    case URI.parse(referer) do
      %URI{path: "/" <> _ = path} -> path
      _ -> ~p"/dashboard"
    end
  end

  # =============================================================================
  # Change password
  # =============================================================================
  def update_password(conn, %{
        "current_password" => current_password,
        "password" => new_password
      }) do
    user = conn.assigns.current_user

    case Accounts.change_user_password(user, current_password, %{password: new_password}) do
      {:ok, updated_user} ->
        # change_user_password wipes every session for this user. Issue
        # a fresh one for the current browser so they stay logged in;
        # other devices are signed out as intended.
        conn
        |> UserAuth.renew_session()
        |> put_session("user_token", Accounts.generate_user_session_token(updated_user))
        |> put_flash(:info, dgettext("app", "Password updated."))
        |> redirect(to: ~p"/settings")

      {:error, changeset} ->
        conn
        |> assign_errors(changeset)
        |> redirect(to: ~p"/settings")
    end
  end

  def update_password(conn, _params) do
    conn
    |> assign_errors(%{password: dgettext("app", "Current and new password are required")})
    |> redirect(to: ~p"/settings")
  end

  # =============================================================================
  # Delete account
  # =============================================================================
  def delete_account(conn, %{"password" => password}) do
    user = conn.assigns.current_user

    case Accounts.delete_user_account(user, password) do
      {:ok, _user} ->
        conn
        |> UserAuth.renew_session()
        |> put_flash(:info, dgettext("app", "Your account has been deleted."))
        |> redirect(to: ~p"/")

      {:error, :invalid_password} ->
        conn
        |> assign_errors(%{password: dgettext("app", "Incorrect password")})
        |> redirect(to: ~p"/settings")
    end
  end

  def delete_account(conn, _params) do
    conn
    |> assign_errors(%{password: dgettext("app", "Password is required")})
    |> redirect(to: ~p"/settings")
  end
end
