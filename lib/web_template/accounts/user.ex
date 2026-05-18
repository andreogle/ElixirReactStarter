defmodule WebTemplate.Accounts.User do
  @moduledoc """
  Schema for users. Minimal by design — email, hashed password,
  confirmation timestamp. Add profile / preference fields per-project.
  Passwords are pre-hashed with SHA3-256 before being passed to Argon2
  so we never hit Argon2's 72-byte input limit regardless of how long
  a chosen password is.
  """

  use Ecto.Schema

  import Ecto.Changeset

  use Gettext, backend: WebTemplateWeb.Gettext

  @type t :: %__MODULE__{}

  @primary_key {:id, WebTemplate.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type WebTemplate.Ecto.UUIDv7

  schema "users" do
    field :email, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a user with email and password.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_email()
    |> validate_password()
  end

  @doc """
  Changeset for updating only the password (used in password reset).
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
  end

  @doc """
  Changeset for updating only the email. Validates format and
  uniqueness; does not change `confirmed_at`.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_email()
  end

  @doc """
  Changeset that marks the user as confirmed.
  """
  def confirm_changeset(user) do
    change(user, confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Returns true if the user has confirmed their email.
  """
  def confirmed?(%__MODULE__{confirmed_at: confirmed_at}), do: confirmed_at != nil

  @doc """
  Constant-time password verification. Runs an Argon2 no-op when
  there's no user so failed lookups take the same time as failed
  password comparisons.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(prehash_password(password), hashed_password)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end

  @doc """
  Pre-hashes a password with SHA3-256 so the input to Argon2 is always
  32 bytes. Sidesteps Argon2's 72-byte input limit without truncating
  long passwords.
  """
  def prehash_password(password) do
    :crypto.hash(:sha3_256, password) |> Base.encode64()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
      message: dgettext("errors", "must be a valid email address")
    )
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 8, max: 256)
    |> hash_password()
  end

  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(prehash_password(password)))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
