defmodule ElixirReactStarterWeb.AuthController do
  @moduledoc """
  HTTP entrypoint for authentication: registration, login/logout, email
  confirmation, and password reset. Renders the Inertia auth pages and
  handles their form submissions.

  Two rules run throughout:

    * **Link-based, single-use tokens.** Confirmation and reset links
      carry a raw token (only its SHA3-256 hash is stored) and are
      consumed on use. Confirming an email or completing a reset logs
      the user in.
    * **No account enumeration.** Resend-confirmation and forgot-password
      respond identically whether or not the email is registered, so the
      endpoints never reveal which addresses have accounts.

  Logging in with an unconfirmed account (and the correct password)
  re-sends a fresh confirmation link instead of starting a session.
  """
  use ElixirReactStarterWeb, :controller

  require Logger

  alias ElixirReactStarter.Accounts
  alias ElixirReactStarter.Accounts.User
  alias ElixirReactStarter.Log
  alias ElixirReactStarterWeb.Email
  alias ElixirReactStarterWeb.UserAuth

  action_fallback ElixirReactStarterWeb.FallbackController

  alias ElixirReactStarterWeb.Plugs.RateLimit

  # Per-IP throttle across all auth form posts — blunts brute-forcing.
  plug RateLimit,
       [bucket: "auth_ip", limit: 30, scale: :timer.minutes(1)]
       when action in [:login, :register, :forgot_password, :resend_confirmation, :reset_password]

  # Per-email throttle on the endpoints that send mail — stops password-reset
  # / confirmation email bombing regardless of source IP.
  plug RateLimit,
       [bucket: "auth_email", by: :email, limit: 5, scale: :timer.hours(1)]
       when action in [:forgot_password, :resend_confirmation]

  # =============================================================================
  # Registration
  # =============================================================================
  def register_page(conn, _params) do
    render_inertia(conn, "Auth/Register")
  end

  def register(conn, %{"email" => _, "password" => _} = params) do
    case Accounts.create_user(params) do
      {:ok, user} ->
        send_confirmation_link(user)

        conn
        |> put_flash(
          :info,
          dgettext("app", "We've sent you a confirmation link. Check your inbox.")
        )
        |> redirect(to: ~p"/login")

      {:error, changeset} ->
        conn
        |> assign_errors(changeset)
        |> redirect(to: ~p"/register")
    end
  end

  def register(_conn, _params) do
    {:error, {:bad_request, dgettext("app", "Email and password are required")}}
  end

  # =============================================================================
  # Login
  # =============================================================================
  def login_page(conn, _params) do
    render_inertia(conn, "Auth/Login")
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        Logger.warning("Failed login attempt for #{Log.redact_email(email)}")

        conn
        |> assign_errors(%{email: dgettext("app", "Invalid email or password")})
        |> redirect(to: ~p"/login")

      %User{confirmed_at: nil} = user ->
        send_confirmation_link(user)

        conn
        |> put_flash(
          :info,
          dgettext("app", "Please confirm your email — we've sent you a new link.")
        )
        |> redirect(to: ~p"/login")

      user ->
        Logger.info("User logged in: #{user.id}")
        UserAuth.log_in_user(conn, user)
    end
  end

  def login(_conn, _params) do
    {:error, {:bad_request, dgettext("app", "Email and password are required")}}
  end

  # =============================================================================
  # Logout
  # =============================================================================
  def logout(conn, _params) do
    UserAuth.log_out_user(conn)
  end

  # =============================================================================
  # Email confirmation — single GET handler, link from email
  #
  # This activates a brand-new account (sets confirmed_at) and logs the
  # user in. It's public: the visitor isn't signed in yet. Changing the
  # email on an *existing* signed-in account is a separate flow —
  # SettingsController.confirm_email via /settings/email/apply-change.
  # =============================================================================
  def confirm_email(conn, %{"token" => raw_token}) do
    case Accounts.verify_user_link_token(raw_token, "email_confirmation") do
      nil ->
        confirm_email_failed(conn)

      user ->
        case Accounts.confirm_user(user) do
          {:ok, user} ->
            UserAuth.log_in_user(conn, user)

          {:error, _changeset} ->
            conn
            |> put_flash(
              :error,
              dgettext("app", "Could not confirm your account. Please try again.")
            )
            |> redirect(to: ~p"/resend-confirmation")
        end
    end
  end

  def confirm_email(conn, _params), do: confirm_email_failed(conn)

  # Confirmation links are single-use, so a consumed/expired/missing
  # token isn't always an error. If the visitor is already signed in and
  # confirmed, they most likely clicked the link a second time — send
  # them to the dashboard instead of the confusing "invalid link" +
  # resend page. Genuinely-stale links (no confirmed session) still land
  # on resend.
  defp confirm_email_failed(%{assigns: %{current_user: %User{confirmed_at: %DateTime{}}}} = conn) do
    redirect(conn, to: ~p"/dashboard")
  end

  defp confirm_email_failed(conn) do
    conn
    |> put_flash(:error, dgettext("app", "Invalid or expired confirmation link."))
    |> redirect(to: ~p"/resend-confirmation")
  end

  # =============================================================================
  # Resend confirmation
  # =============================================================================
  def resend_confirmation_page(conn, _params) do
    render_inertia(conn, "Auth/ResendConfirmation")
  end

  def resend_confirmation(conn, %{"email" => email}) do
    user = Accounts.get_user_by_email(email)

    if user && !User.confirmed?(user), do: send_confirmation_link(user)

    # Always claim success — don't leak which addresses are registered.
    conn
    |> put_flash(
      :info,
      dgettext("app", "If that email is registered, we've sent a new confirmation link.")
    )
    |> redirect(to: ~p"/login")
  end

  def resend_confirmation(_conn, _params) do
    {:error, {:bad_request, dgettext("app", "Email is required")}}
  end

  # =============================================================================
  # Forgot password
  # =============================================================================
  def forgot_password_page(conn, _params) do
    render_inertia(conn, "Auth/ForgotPassword")
  end

  def forgot_password(conn, %{"email" => email}) do
    user = Accounts.get_user_by_email(email)

    _ =
      if user && User.confirmed?(user) do
        raw_token = Accounts.generate_user_link_token(user, "password_reset")
        Email.password_reset_email(user, raw_token) |> ElixirReactStarter.Mailer.deliver()
      end

    # Always claim success — don't leak which addresses are registered.
    conn
    |> put_flash(
      :info,
      dgettext("app", "If that email is registered, we've sent a password reset link.")
    )
    |> redirect(to: ~p"/login")
  end

  def forgot_password(_conn, _params) do
    {:error, {:bad_request, dgettext("app", "Email is required")}}
  end

  # =============================================================================
  # Reset password — GET from the email link, POST with the new password
  # =============================================================================
  def reset_password_page(conn, %{"token" => raw_token}) do
    case Accounts.verify_user_link_token(raw_token, "password_reset") do
      nil ->
        conn
        |> put_flash(:error, dgettext("app", "Invalid or expired reset link."))
        |> redirect(to: ~p"/forgot-password")

      _user ->
        render_inertia(conn, "Auth/ResetPassword", %{token: raw_token})
    end
  end

  def reset_password_page(conn, _params) do
    conn
    |> put_flash(:error, dgettext("app", "Invalid or expired reset link."))
    |> redirect(to: ~p"/forgot-password")
  end

  def reset_password(conn, %{"token" => raw_token, "password" => password}) do
    # Re-verify the token at submit time — the page render might have
    # happened up to an hour ago.
    case Accounts.verify_user_link_token(raw_token, "password_reset") do
      nil ->
        conn
        |> put_flash(:error, dgettext("app", "Invalid or expired reset link."))
        |> redirect(to: ~p"/forgot-password")

      user ->
        case Accounts.reset_user_password(user, %{password: password}) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, dgettext("app", "Password reset successfully. Please log in."))
            |> redirect(to: ~p"/login")

          {:error, changeset} ->
            conn
            |> assign_errors(changeset)
            |> redirect(to: ~p"/reset-password?token=#{raw_token}")
        end
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_flash(:error, dgettext("app", "Token and password are required"))
    |> redirect(to: ~p"/forgot-password")
  end

  # =============================================================================
  # Private
  # =============================================================================
  defp send_confirmation_link(user) do
    raw_token = Accounts.generate_user_link_token(user, "email_confirmation")
    # Fire-and-forget: a delivery error must not stall the auth flow.
    # The mailer logs failures; callers don't need to react.
    _ = Email.confirmation_email(user, raw_token) |> ElixirReactStarter.Mailer.deliver()
    :ok
  end
end
