defmodule ElixirReactStarter.UserFactory do
  @moduledoc """
  Factory for User records. Provides a minimal `user_factory/0` plus
  the `confirmed/1` modifier so most tests can compose as:

      :user |> build() |> confirmed() |> insert()
  """

  alias ElixirReactStarter.Accounts.User

  defmacro __using__(_opts) do
    quote do
      def user_factory do
        %User{
          email: sequence(:email, &"user-#{&1}@example.com"),
          hashed_password: Argon2.hash_pwd_salt(User.prehash_password("valid_password123"))
        }
      end

      def confirmed(user) do
        %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      end
    end
  end
end
