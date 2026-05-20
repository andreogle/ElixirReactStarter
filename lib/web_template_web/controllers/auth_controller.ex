defmodule WebTemplateWeb.AuthController do
  use WebTemplateWeb, :controller

  require Logger

  alias WebTemplate.Accounts
  alias WebTemplate.Accounts.User
  alias WebTemplate.Accounts.UserToken
  alias WebTemplate.Log
  alias WebTemplate.Repo
  alias WebTemplateWeb.Email
  alias WebTemplateWeb.UserAuth

  action_fallback WebTemplateWeb.FallbackController

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
  # =============================================================================
  def confirm_email(conn, %{"token" => raw_token}) do
    case Accounts.verify_user_link_token(raw_token, "email_confirmation") do
      nil ->
        conn
        |> put_flash(:error, dgettext("app", "Invalid or expired confirmation link."))
        |> redirect(to: ~p"/resend-confirmation")

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

  def confirm_email(conn, _params) do
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
        Email.password_reset_email(user, raw_token) |> WebTemplate.Mailer.deliver()
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
            # Consume the reset token so the same link can't be reused.
            Repo.delete_all(
              UserToken.delete_user_tokens_by_context_query(user.id, "password_reset")
            )

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
    _ = Email.confirmation_email(user, raw_token) |> WebTemplate.Mailer.deliver()
    :ok
  end
end
