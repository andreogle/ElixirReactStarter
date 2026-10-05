defmodule ElixirReactStarter.E2EFixtures do
  @moduledoc """
  Test data for the Playwright suite (`assets/e2e/`), in dev and test only.

  Every account the suite makes has an `e2e-test-…` email, and nothing here
  touches any other account, so ordinary dev data survives. The suite mints
  accounts through `ElixirReactStarterWeb.DevE2EController` and, after each
  test, pass or fail, deletes the accounts that test made (`delete_users/1`).
  `reset/0`, run before each suite (`priv/repo/e2e.exs`), removes whatever a
  crashed or interrupted run left behind.

  Raises outside dev and test.
  """

  import Ecto.Query

  alias ElixirReactStarter.Accounts
  alias ElixirReactStarter.Accounts.User
  alias ElixirReactStarter.Repo

  @email_regex ~r/^e2e-test-[a-z0-9-]+@/i
  @email_like "e2e-test-%@%"

  # `Mix.env/0` is captured at compile time, so this burns the build-time
  # environment into the binary — exactly what dev-only fixtures want.
  @dev_env? Mix.env() in [:dev, :test]

  @doc """
  Creates an account with an E2E email, confirmed unless `confirmed?` is
  false (for the resend-confirmation flow).
  """
  @spec create_user(map(), boolean()) :: {:ok, User.t()} | {:error, term()}
  def create_user(attrs, confirmed? \\ true) do
    ensure_enabled!()

    with :ok <- ensure_e2e_email(attrs["email"]),
         {:ok, user} <- Accounts.create_user(attrs) do
      if confirmed?, do: Accounts.confirm_user(user), else: {:ok, user}
    end
  end

  @doc """
  Deletes the accounts with these emails, skipping any outside the E2E
  pattern. Deleting a user cascades to their tokens. Returns how many went.
  """
  @spec delete_users([String.t()]) :: non_neg_integer()
  def delete_users(emails) when is_list(emails) do
    ensure_enabled!()
    emails = Enum.filter(emails, &(ensure_e2e_email(&1) == :ok))
    {count, _} = Repo.delete_all(from u in User, where: u.email in ^emails)
    count
  end

  @doc "Removes every E2E account a previous run left behind."
  @spec reset() :: non_neg_integer()
  def reset do
    ensure_enabled!()
    {count, _} = Repo.delete_all(from u in User, where: like(u.email, ^@email_like))
    count
  end

  defp ensure_e2e_email(email) when is_binary(email) do
    if Regex.match?(@email_regex, email), do: :ok, else: {:error, :invalid_email}
  end

  defp ensure_e2e_email(_email), do: {:error, :invalid_email}

  # Dialyzer runs in :test (where @dev_env? is true) and sees the prod
  # branch as dead. It IS dead in dev/test — and intentionally live in prod.
  @dialyzer {:nowarn_function, ensure_enabled!: 0}
  defp ensure_enabled! do
    if @dev_env?, do: :ok, else: raise("E2E fixtures are dev/test only")
  end
end
