defmodule WebTemplate.AccountsTest do
  use WebTemplate.DataCase, async: true

  # Several tests exercise failure paths that intentionally emit
  # Logger.warning. Capture them — ExUnit still attaches captured
  # output to any failing test for debugging.
  @moduletag :capture_log

  import WebTemplate.Factory

  alias WebTemplate.Accounts
  alias WebTemplate.Accounts.User
  alias WebTemplate.Accounts.UserToken

  describe "create_user/1" do
    test "inserts a user with valid email + password" do
      assert {:ok, %User{} = user} =
               Accounts.create_user(%{"email" => "a@example.com", "password" => "valid_password"})

      assert user.email == "a@example.com"
      assert user.hashed_password
      refute user.password
      refute user.confirmed_at
    end

    test "rejects a missing email" do
      assert {:error, changeset} = Accounts.create_user(%{"password" => "valid_password"})
      assert "can't be blank" in errors_on(changeset).email
    end

    test "rejects a malformed email" do
      assert {:error, changeset} =
               Accounts.create_user(%{"email" => "not-an-email", "password" => "valid_password"})

      assert "must be a valid email address" in errors_on(changeset).email
    end

    test "rejects a short password" do
      assert {:error, changeset} =
               Accounts.create_user(%{"email" => "a@example.com", "password" => "short"})

      assert ["should be at least 8 character(s)"] = errors_on(changeset).password
    end

    test "rejects a duplicate email" do
      insert(:user, email: "taken@example.com")

      assert {:error, changeset} =
               Accounts.create_user(%{
                 "email" => "taken@example.com",
                 "password" => "valid_password"
               })

      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "get_user_by_email/1" do
    test "returns the user when found" do
      user = insert(:user, email: "x@example.com")
      assert %User{id: id} = Accounts.get_user_by_email("x@example.com")
      assert id == user.id
    end

    test "returns nil when not found" do
      refute Accounts.get_user_by_email("nope@example.com")
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns the user with valid credentials" do
      user = insert(:user, email: "y@example.com")

      assert %User{id: id} =
               Accounts.get_user_by_email_and_password("y@example.com", "valid_password123")

      assert id == user.id
    end

    test "returns nil with the wrong password" do
      insert(:user, email: "y@example.com")
      refute Accounts.get_user_by_email_and_password("y@example.com", "wrong_password")
    end

    test "returns nil when no user matches the email (constant-time check)" do
      refute Accounts.get_user_by_email_and_password("none@example.com", "valid_password123")
    end
  end

  describe "session tokens" do
    setup do
      %{user: :user |> build() |> confirmed() |> insert()}
    end

    test "generate + get returns the user", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert %User{id: id} = Accounts.get_user_by_session_token(token)
      assert id == user.id
    end

    test "get returns nil for a random token", _ctx do
      refute Accounts.get_user_by_session_token(:crypto.strong_rand_bytes(32))
    end

    test "delete removes the token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert :ok = Accounts.delete_user_session_token(token)
      refute Accounts.get_user_by_session_token(token)
    end

    test "expired tokens are rejected", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      # Slide refreshed_at back 61 days — beyond the 60-day validity window.
      sixty_one_days_ago =
        DateTime.utc_now() |> DateTime.add(-61, :day) |> DateTime.truncate(:second)

      WebTemplate.Repo.update_all(
        UserToken.delete_user_tokens_by_context_query(user.id, "session"),
        set: [refreshed_at: sixty_one_days_ago]
      )

      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "link tokens" do
    setup do
      %{user: :user |> build() |> confirmed() |> insert()}
    end

    test "generate + verify returns the user", %{user: user} do
      token = Accounts.generate_user_link_token(user, "email_confirmation")
      assert %User{id: id} = Accounts.verify_user_link_token(token, "email_confirmation")
      assert id == user.id
    end

    test "verifying with the wrong context returns nil", %{user: user} do
      token = Accounts.generate_user_link_token(user, "email_confirmation")
      refute Accounts.verify_user_link_token(token, "password_reset")
    end

    test "verifying a random token returns nil", _ctx do
      refute Accounts.verify_user_link_token("garbage", "email_confirmation")
    end

    test "expired tokens are rejected", %{user: user} do
      token = Accounts.generate_user_link_token(user, "email_confirmation")

      # Slide inserted_at back 2 hours — beyond the 1-hour validity window.
      two_hours_ago = DateTime.utc_now() |> DateTime.add(-2, :hour) |> DateTime.truncate(:second)

      WebTemplate.Repo.update_all(
        UserToken.delete_user_tokens_by_context_query(user.id, "email_confirmation"),
        set: [inserted_at: two_hours_ago]
      )

      refute Accounts.verify_user_link_token(token, "email_confirmation")
    end

    test "generating a new token invalidates the previous one", %{user: user} do
      first = Accounts.generate_user_link_token(user, "email_confirmation")
      _second = Accounts.generate_user_link_token(user, "email_confirmation")

      refute Accounts.verify_user_link_token(first, "email_confirmation")
    end
  end

  describe "confirm_user/1" do
    test "sets confirmed_at and deletes confirmation tokens" do
      user = insert(:user)
      _token = Accounts.generate_user_link_token(user, "email_confirmation")

      assert {:ok, confirmed_user} = Accounts.confirm_user(user)
      assert confirmed_user.confirmed_at

      # No confirmation tokens remain.
      assert WebTemplate.Repo.aggregate(
               UserToken.delete_user_tokens_by_context_query(user.id, "email_confirmation"),
               :count,
               :id
             ) == 0
    end
  end

  describe "update_user_locale/2" do
    setup do
      %{user: :user |> build() |> confirmed() |> insert()}
    end

    test "updates the locale to a supported value", %{user: user} do
      assert {:ok, updated} = Accounts.update_user_locale(user, %{locale: "es"})
      assert updated.locale == "es"
    end

    test "rejects an unsupported locale", %{user: user} do
      assert {:error, changeset} = Accounts.update_user_locale(user, %{locale: "fr"})
      assert "is not a supported locale" in errors_on(changeset).locale
    end
  end

  describe "change_user_password/3" do
    setup do
      %{user: :user |> build() |> confirmed() |> insert()}
    end

    test "updates the password and wipes all sessions", %{user: user} do
      _session1 = Accounts.generate_user_session_token(user)
      _session2 = Accounts.generate_user_session_token(user)

      assert {:ok, updated} =
               Accounts.change_user_password(user, "valid_password123", %{
                 password: "fresh_password"
               })

      assert updated.hashed_password != user.hashed_password

      assert WebTemplate.Repo.aggregate(
               UserToken.delete_user_tokens_by_context_query(user.id, "session"),
               :count,
               :id
             ) == 0

      assert Accounts.get_user_by_email_and_password(updated.email, "fresh_password")
      refute Accounts.get_user_by_email_and_password(updated.email, "valid_password123")
    end

    test "rejects an incorrect current password", %{user: user} do
      _session = Accounts.generate_user_session_token(user)

      assert {:error, changeset} =
               Accounts.change_user_password(user, "wrong_password", %{password: "fresh_password"})

      assert "is incorrect" in errors_on(changeset).current_password

      # Sessions NOT wiped on a failed attempt.
      assert WebTemplate.Repo.aggregate(
               UserToken.delete_user_tokens_by_context_query(user.id, "session"),
               :count,
               :id
             ) == 1
    end
  end

  describe "delete_user_account/2" do
    setup do
      %{user: :user |> build() |> confirmed() |> insert()}
    end

    test "deletes the user with a valid password", %{user: user} do
      assert {:ok, _user} = Accounts.delete_user_account(user, "valid_password123")
      refute Accounts.get_user_by_email(user.email)
    end

    test "cascades the user_tokens delete", %{user: user} do
      _session = Accounts.generate_user_session_token(user)
      _link = Accounts.generate_user_link_token(user, "password_reset")

      {:ok, _} = Accounts.delete_user_account(user, "valid_password123")

      # All tokens for the user are gone via FK cascade.
      assert WebTemplate.Repo.aggregate(
               UserToken.delete_user_tokens_by_context_query(user.id, "session"),
               :count,
               :id
             ) == 0
    end

    test "rejects an incorrect password", %{user: user} do
      assert {:error, :invalid_password} = Accounts.delete_user_account(user, "wrong")
      assert Accounts.get_user_by_email(user.email)
    end
  end

  describe "reset_user_password/2" do
    test "updates the password and wipes session + reset tokens" do
      user = :user |> build() |> confirmed() |> insert()
      _session = Accounts.generate_user_session_token(user)
      _reset = Accounts.generate_user_link_token(user, "password_reset")

      assert {:ok, updated} =
               Accounts.reset_user_password(user, %{password: "brand_new_password"})

      assert updated.hashed_password != user.hashed_password

      # Both contexts wiped.
      assert WebTemplate.Repo.aggregate(
               UserToken.delete_user_tokens_by_context_query(user.id, "session"),
               :count,
               :id
             ) == 0

      assert WebTemplate.Repo.aggregate(
               UserToken.delete_user_tokens_by_context_query(user.id, "password_reset"),
               :count,
               :id
             ) == 0

      # The new password works.
      assert Accounts.get_user_by_email_and_password(updated.email, "brand_new_password")
    end
  end
end
