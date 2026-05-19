defmodule WebTemplateWeb.AuthControllerTest do
  use WebTemplateWeb.ConnCase, async: true

  # The failure-path tests (bad password, etc.) intentionally emit
  # Logger.warning. Capture them — ExUnit still attaches captured
  # output to any failing test for debugging.
  @moduletag :capture_log

  import Swoosh.TestAssertions

  alias WebTemplate.Accounts
  alias WebTemplate.Accounts.User

  # =============================================================================
  # Register
  # =============================================================================
  describe "GET /register" do
    test "renders the Inertia Register page", %{conn: conn} do
      conn = get(conn, ~p"/register")
      assert html_response(conn, 200) =~ ~s(&quot;component&quot;:&quot;Auth/Register&quot;)
    end
  end

  describe "POST /register" do
    test "creates a user, sends a confirmation email, redirects to /login", %{conn: conn} do
      conn = post(conn, ~p"/register", %{email: "new@example.com", password: "valid_password"})

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "confirmation link"
      assert Accounts.get_user_by_email("new@example.com")

      assert_email_sent(fn email ->
        assert email.subject == "Confirm your email"
        assert {_, "new@example.com"} = email.to |> List.first()
        # The link must contain a token query param.
        assert email.text_body =~ ~r{/confirm-email\?token=[\w-]+}
      end)
    end

    test "renders errors on an invalid email", %{conn: conn} do
      conn = post(conn, ~p"/register", %{email: "not-an-email", password: "valid_password"})
      assert redirected_to(conn) == ~p"/register"
      refute Accounts.get_user_by_email("not-an-email")
    end

    test "rejects missing params", %{conn: conn} do
      conn = post(conn, ~p"/register", %{})
      # action_fallback {:bad_request, ...} redirects to /
      assert redirected_to(conn) == ~p"/"
    end
  end

  # =============================================================================
  # Login
  # =============================================================================
  describe "POST /login" do
    setup do
      %{user: :user |> build() |> confirmed() |> insert()}
    end

    test "logs in with valid credentials and redirects to /dashboard", %{conn: conn, user: user} do
      conn = post(conn, ~p"/login", %{email: user.email, password: "valid_password123"})

      assert redirected_to(conn) == ~p"/dashboard"
      assert get_session(conn, "user_token")
    end

    test "rejects an invalid password", %{conn: conn, user: user} do
      conn = post(conn, ~p"/login", %{email: user.email, password: "wrong"})

      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, "user_token")
    end

    test "an unconfirmed user gets a fresh confirmation email", %{conn: conn} do
      unconfirmed = insert(:user)

      conn =
        post(conn, ~p"/login", %{email: unconfirmed.email, password: "valid_password123"})

      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, "user_token")
      assert_email_sent(subject: "Confirm your email")
    end
  end

  # =============================================================================
  # Logout
  # =============================================================================
  describe "DELETE /logout" do
    @tag :authenticated
    test "clears the session and redirects to /", %{conn: conn} do
      conn = delete(conn, ~p"/logout")
      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, "user_token") == nil
    end
  end

  # =============================================================================
  # Email confirmation (link-click)
  # =============================================================================
  describe "GET /confirm-email" do
    test "confirms the user and logs them in", %{conn: conn} do
      user = insert(:user)
      token = Accounts.generate_user_link_token(user, "email_confirmation")

      conn = get(conn, ~p"/confirm-email?token=#{token}")

      assert redirected_to(conn) == ~p"/dashboard"
      assert get_session(conn, "user_token")
      assert Accounts.get_user_by_email(user.email) |> User.confirmed?()
    end

    test "rejects an invalid token", %{conn: conn} do
      conn = get(conn, ~p"/confirm-email?token=garbage")

      assert redirected_to(conn) == ~p"/resend-confirmation"
      refute get_session(conn, "user_token")
    end

    test "rejects a missing token", %{conn: conn} do
      conn = get(conn, ~p"/confirm-email")
      assert redirected_to(conn) == ~p"/resend-confirmation"
    end
  end

  # =============================================================================
  # Resend confirmation — no enumeration leak
  # =============================================================================
  describe "POST /resend-confirmation" do
    test "sends a fresh link for an unconfirmed user", %{conn: conn} do
      user = insert(:user)
      conn = post(conn, ~p"/resend-confirmation", %{email: user.email})

      assert redirected_to(conn) == ~p"/login"
      assert_email_sent(subject: "Confirm your email")
    end

    test "does not send mail for an unknown email but responds identically", %{conn: conn} do
      conn = post(conn, ~p"/resend-confirmation", %{email: "unknown@example.com"})

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If that email is registered"
      assert_no_email_sent()
    end

    test "does not send mail for an already-confirmed user", %{conn: conn} do
      user = :user |> build() |> confirmed() |> insert()
      conn = post(conn, ~p"/resend-confirmation", %{email: user.email})

      assert redirected_to(conn) == ~p"/login"
      assert_no_email_sent()
    end
  end

  # =============================================================================
  # Forgot password
  # =============================================================================
  describe "POST /forgot-password" do
    test "sends a reset link for a confirmed user", %{conn: conn} do
      user = :user |> build() |> confirmed() |> insert()
      conn = post(conn, ~p"/forgot-password", %{email: user.email})

      assert redirected_to(conn) == ~p"/login"
      assert_email_sent(subject: "Reset your password")
    end

    test "does not send mail for an unconfirmed user but responds identically", %{conn: conn} do
      user = insert(:user)
      conn = post(conn, ~p"/forgot-password", %{email: user.email})

      assert redirected_to(conn) == ~p"/login"
      assert_no_email_sent()
    end

    test "does not send mail for an unknown email but responds identically", %{conn: conn} do
      conn = post(conn, ~p"/forgot-password", %{email: "unknown@example.com"})

      assert redirected_to(conn) == ~p"/login"
      assert_no_email_sent()
    end
  end

  # =============================================================================
  # Reset password
  # =============================================================================
  describe "GET /reset-password" do
    test "renders the Inertia page with a valid token", %{conn: conn} do
      user = :user |> build() |> confirmed() |> insert()
      token = Accounts.generate_user_link_token(user, "password_reset")

      conn = get(conn, ~p"/reset-password?token=#{token}")

      body = html_response(conn, 200)
      assert body =~ ~s(&quot;component&quot;:&quot;Auth/ResetPassword&quot;)
    end

    test "redirects on an invalid token", %{conn: conn} do
      conn = get(conn, ~p"/reset-password?token=garbage")
      assert redirected_to(conn) == ~p"/forgot-password"
    end
  end

  describe "POST /reset-password" do
    setup do
      user = :user |> build() |> confirmed() |> insert()
      token = Accounts.generate_user_link_token(user, "password_reset")
      %{user: user, token: token}
    end

    test "updates the password and redirects to /login", %{conn: conn, user: user, token: token} do
      conn =
        post(conn, ~p"/reset-password", %{token: token, password: "brand_new_password"})

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password reset"
      assert Accounts.get_user_by_email_and_password(user.email, "brand_new_password")
    end

    test "consumes the reset token after a successful reset", %{conn: conn, token: token} do
      post(conn, ~p"/reset-password", %{token: token, password: "brand_new_password"})

      # Same token should no longer verify.
      refute Accounts.verify_user_link_token(token, "password_reset")
    end

    test "rejects an invalid token", %{conn: conn} do
      conn = post(conn, ~p"/reset-password", %{token: "garbage", password: "any_password_123"})
      assert redirected_to(conn) == ~p"/forgot-password"
    end

    test "rejects a short password and keeps the token", %{conn: conn, token: token, user: user} do
      conn = post(conn, ~p"/reset-password", %{token: token, password: "short"})

      assert redirected_to(conn) =~ "/reset-password?token="
      # Original password still works (no update happened).
      assert Accounts.get_user_by_email_and_password(user.email, "valid_password123")
    end
  end
end
