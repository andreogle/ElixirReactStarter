defmodule WebTemplate.Accounts.UserToken do
  @moduledoc """
  Schema for user tokens. Handles two token shapes:

    * Session tokens — 32 random bytes; the raw bytes go in the session
      cookie, the SHA3-256 hash is stored in the database. Sliding
      window of 60 days via `refreshed_at`.
    * Link tokens — 32 random bytes encoded as URL-safe base64; the
      raw string goes in an email link's query param, the SHA3-256
      hash of the raw string is stored in the database. Used for email
      confirmation and password reset. Expires after 1 hour.

  Tokens are never stored raw — only their hashes — so a database
  read can't be replayed against the application.
  """

  use Ecto.Schema

  import Ecto.Query

  @primary_key {:id, WebTemplate.Ecto.UUIDv7, autogenerate: true}
  @foreign_key_type WebTemplate.Ecto.UUIDv7

  @rand_size 32
  @session_validity_in_days 60
  @session_refresh_after_days 1
  @link_validity_in_hours 1

  schema "user_tokens" do
    field :token, :binary, redact: true
    field :context, :string
    field :refreshed_at, :utc_datetime

    belongs_to :user, WebTemplate.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  # =============================================================================
  # Session tokens
  # =============================================================================
  @doc """
  Builds a session token for the given user. Returns
  `{raw_token, %UserToken{}}` — the raw token goes in the session
  cookie; the struct (with SHA3-256 hash) is inserted into the DB.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {token,
     %__MODULE__{
       token: :crypto.hash(:sha3_256, token),
       context: "session",
       user_id: user.id,
       refreshed_at: now
     }}
  end

  @doc """
  Query that finds the user for the given session token, provided the
  token is still valid (within #{@session_validity_in_days} days).
  """
  def verify_session_token_query(token) do
    hashed = :crypto.hash(:sha3_256, token)

    from t in __MODULE__,
      where: t.token == ^hashed and t.context == "session",
      where: t.refreshed_at > ago(^@session_validity_in_days, "day"),
      join: u in assoc(t, :user),
      select: u
  end

  @doc """
  Update query that slides the session's `refreshed_at` forward — but
  only if it hasn't been refreshed in the last
  #{@session_refresh_after_days} day(s). Active users stay logged in;
  inactive sessions expire after #{@session_validity_in_days} days.
  """
  def refresh_session_token_query(token) do
    hashed = :crypto.hash(:sha3_256, token)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from t in __MODULE__,
      where: t.token == ^hashed and t.context == "session",
      where: t.refreshed_at <= ago(^@session_refresh_after_days, "day"),
      update: [set: [refreshed_at: ^now]]
  end

  # =============================================================================
  # Email-link tokens (confirmation, password reset)
  # =============================================================================
  @doc """
  Builds a URL-safe link token for the given user and context. Returns
  `{raw_token, %UserToken{}}` — the raw string goes in the email link
  (e.g. `https://app.example/confirm-email?token=...`), the struct
  (with SHA3-256 hash) is inserted into the DB.

  Context should be `"email_confirmation"` or `"password_reset"`.
  """
  def build_link_token(user, context) do
    raw_token = @rand_size |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    hashed = :crypto.hash(:sha3_256, raw_token)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {raw_token,
     %__MODULE__{
       token: hashed,
       context: context,
       user_id: user.id,
       refreshed_at: now
     }}
  end

  @doc """
  Query that finds the user for the given raw link token + context,
  provided the token is still valid (within
  #{@link_validity_in_hours} hour).
  """
  def verify_link_token_query(raw_token, context) when is_binary(raw_token) do
    hashed = :crypto.hash(:sha3_256, raw_token)

    from t in __MODULE__,
      where: t.token == ^hashed and t.context == ^context,
      where: t.inserted_at > ago(^@link_validity_in_hours, "hour"),
      join: u in assoc(t, :user),
      select: u
  end

  @doc """
  Query matching every token for a given user and context. Used to
  invalidate previous tokens before issuing a new one, and to consume
  the token after a successful verification.
  """
  def delete_user_tokens_by_context_query(user_id, context) do
    from t in __MODULE__,
      where: t.user_id == ^user_id and t.context == ^context
  end
end
