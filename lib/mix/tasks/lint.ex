defmodule Mix.Tasks.Lint do
  @shortdoc "Runs Elixir (credo) and frontend (biome + tsc) lints"
  @moduledoc """
  Runs all linting checks for both Elixir and frontend code.

      mix lint

  This runs:
  - `mix credo` for Elixir static analysis
  - `npm run lint` (biome) for TypeScript/CSS linting
  - `npm run test:unit` for frontend utility contract tests
  - `npm run typecheck` (tsc) for TypeScript type checking, covering both
    the app (`tsconfig.json`) and the Playwright suite (`tsconfig.e2e.json`)

  Biome lints but does not type-check, so `tsc --noEmit` is what actually
  catches type errors. The typecheck script regenerates the page registries
  (`_pages.ts` / `_ssr_pages.ts`) first — they're gitignored build artefacts,
  so they may not exist yet in a fresh clone or on CI.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("credo")

    npm("run lint")
    npm("run test:unit")
    npm("run typecheck")
  end

  # `Mix.shell().cmd/2` returns the exit status instead of raising, and Mix
  # discards a task's return value — so calling it without checking silently
  # swallows every frontend failure. Raise so `mix lint` (and with it
  # `mix precommit` and CI) fails on a non-zero status.
  defp npm(args) do
    case Mix.shell().cmd("npm #{args}", cd: "assets") do
      0 -> :ok
      status -> Mix.raise("`npm #{args}` failed with exit status #{status}")
    end
  end
end
