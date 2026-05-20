defmodule ElixirReactStarter.Factory do
  @moduledoc """
  ExMachina factory. Individual factories live in
  `test/support/factories/` and compose here via `use`.
  """

  use ExMachina.Ecto, repo: ElixirReactStarter.Repo
  use ElixirReactStarter.UserFactory
end
