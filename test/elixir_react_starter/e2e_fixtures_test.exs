defmodule ElixirReactStarter.E2EFixturesTest do
  use ElixirReactStarter.DataCase, async: true

  import ElixirReactStarter.Factory

  alias ElixirReactStarter.Accounts.User
  alias ElixirReactStarter.E2EFixtures

  @password "playwright-secret-1234"

  describe "create_user/2" do
    test "creates a confirmed account by default" do
      attrs = %{"email" => "e2e-test-a@example.com", "password" => @password}

      assert {:ok, %User{confirmed_at: %DateTime{}}} = E2EFixtures.create_user(attrs)
    end

    test "leaves the account unconfirmed when asked" do
      attrs = %{"email" => "e2e-test-b@example.com", "password" => @password}

      assert {:ok, %User{confirmed_at: nil}} = E2EFixtures.create_user(attrs, false)
    end

    test "refuses an email outside the E2E pattern" do
      attrs = %{"email" => "someone@example.com", "password" => @password}

      assert {:error, :invalid_email} = E2EFixtures.create_user(attrs)
      refute Repo.get_by(User, email: "someone@example.com")
    end
  end

  describe "delete_users/1" do
    test "deletes only the listed E2E accounts" do
      gone = insert(:user, email: "e2e-test-gone@example.com")
      kept = insert(:user, email: "e2e-test-kept@example.com")
      real = insert(:user)

      assert 1 =
               E2EFixtures.delete_users([gone.email, real.email, "e2e-test-none@example.com"])

      refute Repo.get(User, gone.id)
      assert Repo.get(User, kept.id)
      assert Repo.get(User, real.id)
    end
  end

  describe "reset/0" do
    test "removes every E2E account and nothing else" do
      leftover = insert(:user, email: "e2e-test-leftover@example.com")
      real = insert(:user)

      assert E2EFixtures.reset() >= 1

      refute Repo.get(User, leftover.id)
      assert Repo.get(User, real.id)
    end
  end
end
