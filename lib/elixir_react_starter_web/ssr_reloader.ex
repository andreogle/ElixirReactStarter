defmodule ElixirReactStarterWeb.SSRReloader do
  @moduledoc """
  Development only: restarts the server-rendering workers when the SSR
  bundle (`priv/ssr.js`) is rebuilt, so a change shows up on the next page
  load.

  The workers run with `NODE_ENV=production` in development (set at boot
  when `:reload_ssr` is on). Otherwise the `nodejs`
  package loads the whole bundle again on every render to pick up changes,
  keeping several MB of heap each time, and a worker dies of a full heap
  after a few hundred renders: a 500, since development raises on a failed
  server render. That is what made long E2E runs fail at random. In
  production the bundle never changes; here this module picks the new one
  up instead, by restarting the pool once.

  It checks the bundle's modification time and size every second, and
  restarts once they have stopped moving, so a bundle still being written
  is never loaded. Started only when `:reload_ssr` is set (`config/dev.exs`).
  """

  use GenServer

  require Logger

  @interval 1_000

  @doc """
  Options: `:path` of the bundle, and optionally `:interval` (ms) and
  `:restart`, the function that reloads the workers (tests replace it).
  """
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))

  @impl true
  def init(opts) do
    path = Keyword.fetch!(opts, :path)

    state = %{
      path: path,
      interval: Keyword.get(opts, :interval, @interval),
      restart: Keyword.get(opts, :restart, &restart_workers/0),
      loaded: stamp(path),
      seen: stamp(path)
    }

    schedule(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:check, %{path: path, loaded: loaded, seen: seen} = state) do
    schedule(state)
    now = stamp(path)

    if now == loaded or now != seen do
      # Unchanged since the workers last loaded it, or still being written.
      {:noreply, %{state | seen: now}}
    else
      state.restart.()
      {:noreply, %{state | loaded: now, seen: now}}
    end
  end

  defp restart_workers do
    Logger.info("SSR bundle rebuilt; restarting the server-rendering workers")

    with :ok <- Supervisor.terminate_child(ElixirReactStarter.Supervisor, Inertia.SSR),
         {:ok, _pid} <- Supervisor.restart_child(ElixirReactStarter.Supervisor, Inertia.SSR) do
      :ok
    else
      error -> Logger.warning("Could not restart the server-rendering workers: #{inspect(error)}")
    end
  end

  defp stamp(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mtime: mtime, size: size}} -> {mtime, size}
      {:error, _reason} -> nil
    end
  end

  defp schedule(state), do: Process.send_after(self(), :check, state.interval)
end
