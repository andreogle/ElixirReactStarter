defmodule ElixirReactStarter.Repo.Migrations.AddObanJobsTables do
  use Ecto.Migration

  # Creates the `oban_jobs` table (and supporting types/triggers) that
  # the Oban supervisor in the application tree reads and writes. Without
  # this, enqueuing a job raises because the table doesn't exist.
  def up do
    Oban.Migration.up(version: 14)
  end

  # `version: 1` rolls the schema all the way back so a full `down`
  # leaves no Oban tables behind.
  def down do
    Oban.Migration.down(version: 1)
  end
end
