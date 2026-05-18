defmodule WebTemplate.Factory do
  @moduledoc """
  ExMachina factory. Individual factories live in
  `test/support/factories/` and compose here via `use`.
  """

  use ExMachina.Ecto, repo: WebTemplate.Repo
  use WebTemplate.UserFactory
end
