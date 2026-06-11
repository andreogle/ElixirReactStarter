defmodule ElixirReactStarter.Accounts do
  @moduledoc """
  Accounts context: users, password authentication, and the link-based
  email-confirmation and password-reset flows.

  Tokens are **link-based**, not codes. Confirmation and reset tokens are
  32 random bytes; only their SHA3-256 hash is stored, while the raw
  token rides in a single-click email URL and expires after one hour.
  Session tokens use a 60-day sliding window.

  Generated CRUD helpers come from `use ElixirReactStarter.Context`. The custom
  functions here cover registration, the session lifecycle, email
  confirmation, password reset, the link-confirmed email change, the
  authenticated password change, and account deletion (the last three
  re-verify the current password).

  The `User` schema is deliberately minimal — email, hashed password,
  locale, confirmed_at. Add profile fields (name, avatar, …) per project.
  """

  use ElixirReactStarter.Context,
    repo: ElixirReactStarter.Repo,
    schema: ElixirReactStarter.Accounts.User,
    changeset: :registration_changeset

  require Logger

  alias ElixirReactStarter.Accounts.{User, UserToken}
  alias ElixirReactStarter.Repo

  # =============================================================================
  # Registration
  # =============================================================================
  @doc """
  Creates a new user with the given attributes.
  """
  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> log_result("User registered")
  end

  # =============================================================================
  # Authentication
  # =============================================================================
  @doc """
  Returns the user matching the given email, or `nil`.
  """
  def get_user_by_email(email) when is_binary(email) do
    get_user_by(email: email)
  end

  @doc """
  Returns the user matching the given email and password, or `nil`.
  Runs a constant-time no-op when no user is found to prevent timing
  attacks.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by(email: email)
    if User.valid_password?(user, password), do: user
  end

  # =============================================================================
  # Session tokens
  # =============================================================================
  @doc """
  Generates a session token for the user, inserts the hashed token into
  the database, and returns the raw token for the session cookie.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Returns the user for the given session token, or `nil` if the token
  is invalid or expired. Slides the token's `refreshed_at` forward so
  active sessions stay alive.
  """
  def get_user_by_session_token(token) do
    user =
      token
      |> UserToken.verify_session_token_query()
      |> Repo.one()

    if user do
      Repo.update_all(UserToken.refresh_session_token_query(token), [])
    end

    user
  end

  @doc """
  Deletes the session token matching the given raw token.
  """
  def delete_user_session_token(token) do
    token
    |> UserToken.verify_session_token_query()
    |> Repo.delete_all()

    :ok
  end

  # =============================================================================
  # Email-link tokens (confirmation, password reset)
  # =============================================================================
  @doc """
  Generates a URL-safe link token for the given user and context.
  Invalidates any previous tokens for the same user + context so a
  resend doesn't accumulate active tokens.
  """
  def generate_user_link_token(user, context) do
    Repo.delete_all(UserToken.delete_user_tokens_by_context_query(user.id, context))

    {raw_token, user_token} = UserToken.build_link_token(user, context)
    Repo.insert!(user_token)
    raw_token
  end

  @doc """
  Verifies a raw link token for the given context. Returns the user
  if the token is valid (and not expired), or `nil` otherwise.
  """
  def verify_user_link_token(raw_token, context) when is_binary(raw_token) do
    raw_token
    |> UserToken.verify_link_token_query(context)
    |> Repo.one()
  end

  def verify_user_link_token(_, _), do: nil

  # =============================================================================
  # Locale
  # =============================================================================
  @doc """
  Updates the user's preferred locale. Rejects values that aren't in
  `:supported_locales`.
  """
  def update_user_locale(user, attrs) do
    user
    |> User.locale_changeset(attrs)
    |> Repo.update()
  end

  # =============================================================================
  # Email confirmation
  # =============================================================================
  @doc """
  Confirms the user's email by setting `confirmed_at` and deleting all
  email confirmation tokens.
  """
  def confirm_user(user) do
    Repo.delete_all(UserToken.delete_user_tokens_by_context_query(user.id, "email_confirmation"))

    user
    |> User.confirm_changeset()
    |> Repo.update()
    |> log_result("Email confirmed for user #{user.id}")
  end

  # =============================================================================
  # Email change (authenticated, link-confirmed)
  # =============================================================================
  @doc """
  Starts an email change after re-verifying the current password.

  Validates the new address (format, length, not unchanged, not already
  taken) and, on success, issues a single-use `email_change` token whose
  `sent_to` holds the pending address. Returns `{:ok, raw_token}` — the
  caller mails the confirmation link to the *new* address and notifies
  the *old* one. The user's email isn't touched until they click the
  link (`apply_email_change/2`).

  Returns `{:error, :invalid_password}` or `{:error, changeset}`.
  """
  def request_email_change(user, current_password, new_email) do
    if User.valid_password?(user, current_password) do
      user
      |> User.email_changeset(%{email: new_email})
      |> validate_email_change()
      |> case do
        %{valid?: true} ->
          Repo.delete_all(UserToken.delete_user_tokens_by_context_query(user.id, "email_change"))
          {raw_token, user_token} = UserToken.build_email_change_token(user, new_email)
          Repo.insert!(user_token)
          Logger.info("Email change requested for user #{user.id}")
          {:ok, raw_token}

        changeset ->
          {:error, %{changeset | action: :update}}
      end
    else
      Logger.warning("Failed email change attempt for user #{user.id}: incorrect password")
      {:error, :invalid_password}
    end
  end

  @doc """
  Applies a pending email change. Verifies the `email_change` token
  belongs to `user` and hasn't expired, then swaps in the address it
  was issued for. The DB unique index is the final guard against the
  address being claimed between request and click (TOCTOU). Consumes
  every email-change token for the user on success.

  Returns `{:ok, user}`, `{:error, :invalid_token}`, or
  `{:error, changeset}`.
  """
  def apply_email_change(user, raw_token) do
    query = UserToken.verify_email_change_token_query(raw_token, user.id)

    case Repo.one(query) do
      %UserToken{sent_to: new_email} ->
        user
        |> User.email_changeset(%{email: new_email})
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            Repo.delete_all(
              UserToken.delete_user_tokens_by_context_query(user.id, "email_change")
            )

            Logger.info("Email changed for user #{user.id}")
            {:ok, updated}

          {:error, _changeset} = error ->
            error
        end

      nil ->
        {:error, :invalid_token}
    end
  end

  # Layers the checks `User.email_changeset/2` can't express on its own:
  # the address must actually differ and must not already belong to
  # another account.
  defp validate_email_change(changeset) do
    cond do
      not changeset.valid? ->
        changeset

      Ecto.Changeset.get_change(changeset, :email) == nil ->
        Ecto.Changeset.add_error(changeset, :email, "is the same as your current email")

      get_user_by(email: Ecto.Changeset.get_change(changeset, :email)) ->
        Ecto.Changeset.add_error(changeset, :email, "has already been taken")

      true ->
        changeset
    end
  end

  # =============================================================================
  # Password change (authenticated)
  # =============================================================================
  @doc """
  Changes the user's password after verifying the current one.
  Invalidates every session token — the caller should reissue a fresh
  session for the current browser to keep it logged in.
  """
  def change_user_password(user, current_password, new_password_attrs) do
    if User.valid_password?(user, current_password) do
      Repo.delete_all(UserToken.delete_user_tokens_by_context_query(user.id, "session"))

      user
      |> User.password_changeset(new_password_attrs)
      |> Repo.update()
      |> log_result("Password changed for user #{user.id}")
    else
      Logger.warning(
        "Failed password change attempt for user #{user.id}: incorrect current password"
      )

      changeset =
        user
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:current_password, "is incorrect")

      {:error, changeset}
    end
  end

  # =============================================================================
  # Account deletion
  # =============================================================================
  @doc """
  Deletes the user after verifying their password. The `:delete_all`
  cascade on `user_tokens` removes every token for the user as a side
  effect.
  """
  def delete_user_account(user, password) do
    if User.valid_password?(user, password) do
      Logger.info("Account deleted for user #{user.id}")
      Repo.delete(user)
    else
      Logger.warning("Failed account deletion attempt for user #{user.id}: incorrect password")
      {:error, :invalid_password}
    end
  end

  # =============================================================================
  # Password reset (unauthenticated)
  # =============================================================================
  @doc """
  Resets the user's password. Deletes all password-reset tokens and all
  session tokens (forcing re-login on every device).
  """
  def reset_user_password(user, attrs) do
    Repo.delete_all(UserToken.delete_user_tokens_by_context_query(user.id, "password_reset"))
    Repo.delete_all(UserToken.delete_user_tokens_by_context_query(user.id, "session"))

    user
    |> User.password_changeset(attrs)
    |> Repo.update()
    |> log_result("Password reset for user #{user.id}")
  end

  # =============================================================================
  # Private
  # =============================================================================
  defp log_result({:ok, _} = result, message) do
    Logger.info(message)
    result
  end

  defp log_result(result, _message), do: result
end
