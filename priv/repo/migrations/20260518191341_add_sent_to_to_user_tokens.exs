defmodule ElixirReactStarter.Repo.Migrations.AddSentToToUserTokens do
  use Ecto.Migration

  # `sent_to` holds the pending new address for an "email_change" token.
  # The user's `email` column isn't touched until they click the link in
  # the new inbox, so the target has to live somewhere in the meantime.
  # Nullable because every other token context (session, confirmation,
  # reset) leaves it blank.
  def change do
    alter table(:user_tokens) do
      add :sent_to, :string
    end
  end
end
