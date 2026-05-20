defmodule ElixirReactStarter.Accounts.UserTest do
  use ElixirReactStarter.DataCase, async: true

  alias ElixirReactStarter.Accounts.User

  describe "registration_changeset/2" do
    test "is valid with an email and a long-enough password" do
      changeset =
        User.registration_changeset(%User{}, %{
          email: "new@example.com",
          password: "valid_password123"
        })

      assert changeset.valid?
      # Password is hashed (and the virtual field cleared) on a valid changeset.
      assert get_change(changeset, :hashed_password)
    end

    test "requires a well-formed email" do
      changeset =
        User.registration_changeset(%User{}, %{email: "nope", password: "valid_password123"})

      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end

    test "rejects a short password" do
      changeset =
        User.registration_changeset(%User{}, %{email: "new@example.com", password: "short"})

      refute changeset.valid?
      assert errors_on(changeset)[:password]
    end
  end

  describe "email_changeset/2" do
    test "is valid for a well-formed email" do
      changeset = User.email_changeset(%User{}, %{email: "changed@example.com"})
      assert changeset.valid?
    end

    test "rejects a malformed email" do
      changeset = User.email_changeset(%User{}, %{email: "missing-at-sign"})
      refute changeset.valid?
      assert errors_on(changeset)[:email]
    end
  end

  describe "locale_changeset/2" do
    test "accepts a supported locale" do
      assert User.locale_changeset(%User{}, %{locale: "es"}).valid?
    end

    test "rejects an unsupported locale" do
      changeset = User.locale_changeset(%User{}, %{locale: "fr"})
      refute changeset.valid?
      assert errors_on(changeset)[:locale]
    end
  end

  describe "valid_password?/2" do
    test "is false for a nil user (constant-time no-op)" do
      refute User.valid_password?(nil, "anything")
    end

    test "is true only for the matching password" do
      user = %User{hashed_password: Argon2.hash_pwd_salt(User.prehash_password("correct horse"))}
      assert User.valid_password?(user, "correct horse")
      refute User.valid_password?(user, "wrong")
    end
  end
end
