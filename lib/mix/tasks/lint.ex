defmodule Mix.Tasks.Lint do
  @shortdoc "Runs Elixir (credo) and frontend (biome) lints"
  @moduledoc """
  Runs all linting checks for both Elixir and frontend code.

      mix lint

  This runs:
  - `mix credo` for Elixir static analysis
  - `npm run lint` (biome) for TypeScript/CSS linting
  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("credo")
    Mix.shell().cmd("npm run lint", cd: "assets")
  end
end
