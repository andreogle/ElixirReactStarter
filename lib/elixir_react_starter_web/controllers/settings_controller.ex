defmodule ElixirReactStarterWeb.SettingsController do
  @moduledoc """
  Authenticated account settings: changing the email, changing the
  password, and deleting the account. All three re-verify the current
  password before acting.

  Email changes are link-confirmed: `update_email` mails a single-use
  link to the *new* address and a heads-up to the *old* one, but doesn't
  touch the record until the link is opened (`confirm_email`).

  Changing the password invalidates every session token for the user
  (signing out other devices), so this controller immediately issues a
  fresh session for the current browser to keep it logged in. Deleting
  the account cascades to its tokens and clears the session.
  """
  use ElixirReactStarterWeb, :controller

  alias ElixirReactStarter.Accounts
  alias ElixirReactStarter.Mailer
  alias ElixirReactStarterWeb.Email
  alias ElixirReactStarterWeb.UserAuth

  action_fallback ElixirReactStarterWeb.FallbackController

  def show(conn, _params) do
    render_inertia(conn, "Settings")
  end

  # =============================================================================
  # Change email (link-confirmed)
  # =============================================================================
  def update_email(conn, %{"current_password" => current_password, "email" => new_email}) do
    user = conn.assigns.current_user

    case Accounts.request_email_change(user, current_password, new_email) do
      {:ok, raw_token} ->
        # Confirmation goes to the new address (proves ownership); the
        # old address gets a heads-up so the owner is alerted to the
        # change even if they never see the new inbox.
        _ = Email.email_change_confirmation(new_email, raw_token) |> Mailer.deliver()
        _ = Email.email_change_notification(user.email, new_email) |> Mailer.deliver()

        conn
        |> put_flash(
          :info,
          dgettext("app", "Check your new inbox — we've sent a link to confirm the change.")
        )
        |> redirect(to: ~p"/settings")

      {:error, :invalid_password} ->
        conn
        |> assign_errors(%{current_password: dgettext("app", "Incorrect password")})
        |> redirect(to: ~p"/settings")

      {:error, changeset} ->
        conn
        |> assign_errors(changeset)
        |> redirect(to: ~p"/settings")
    end
  end

  def update_email(conn, _params) do
    message = dgettext("app", "Current password and new email are required")

    conn
    |> assign_errors(%{current_password: message, email: message})
    |> redirect(to: ~p"/settings")
  end

  # Opened from the link in the new inbox while signed in. The token is
  # scoped to the current user, so a stale or foreign token just fails.
  #
  # This is *not* the same as AuthController.confirm_email (the public
  # /confirm-email route): that one activates a brand-new account and
  # starts a session. This applies a pending change to an already-active,
  # signed-in account — hence the distinct /settings/email/apply-change
  # route and the user-scoped "email_change" token.
  def confirm_email(conn, %{"token" => raw_token}) do
    case Accounts.apply_email_change(conn.assigns.current_user, raw_token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, dgettext("app", "Your email address has been updated."))
        |> redirect(to: ~p"/settings")

      {:error, _reason} ->
        conn
        |> put_flash(:error, dgettext("app", "That email change link is invalid or has expired."))
        |> redirect(to: ~p"/settings")
    end
  end

  def confirm_email(conn, _params) do
    conn
    |> put_flash(:error, dgettext("app", "That email change link is invalid or has expired."))
    |> redirect(to: ~p"/settings")
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
    message = dgettext("app", "Current and new password are required")

    conn
    |> assign_errors(%{current_password: message, password: message})
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
