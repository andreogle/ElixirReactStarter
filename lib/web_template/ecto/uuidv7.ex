defmodule WebTemplate.Ecto.UUIDv7 do
  @moduledoc """
  An Ecto type for UUID v7 primary keys.

  UUID v7 values are time-sortable, making them suitable for primary keys
  where chronological ordering is beneficial. Delegates storage and casting
  to `Ecto.UUID` while generating v7 values via `Uniq.UUID.uuid7/0`.

  ## Usage

      @primary_key {:id, WebTemplate.Ecto.UUIDv7, autogenerate: true}
      @foreign_key_type WebTemplate.Ecto.UUIDv7
  """

  use Ecto.Type

  @impl true
  def type, do: :uuid

  @impl true
  def cast(value), do: Ecto.UUID.cast(value)

  @impl true
  def dump(value), do: Ecto.UUID.dump(value)

  @impl true
  def load(value), do: Ecto.UUID.load(value)

  @impl true
  def autogenerate, do: Uniq.UUID.uuid7()
end
