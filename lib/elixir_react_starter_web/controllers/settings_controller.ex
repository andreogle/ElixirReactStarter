defmodule ElixirReactStarterWeb.SettingsController do
  @moduledoc """
  Authenticated account settings: changing the password and deleting the
  account. Both re-verify the current password before acting.

  Changing the password invalidates every session token for the user
  (signing out other devices), so this controller immediately issues a
  fresh session for the current browser to keep it logged in. Deleting
  the account cascades to its tokens and clears the session.
  """
  use ElixirReactStarterWeb, :controller

  alias ElixirReactStarter.Accounts
  alias ElixirReactStarterWeb.UserAuth

  action_fallback ElixirReactStarterWeb.FallbackController

  def show(conn, _params) do
    render_inertia(conn, "Settings")
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
