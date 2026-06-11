defmodule ElixirReactStarter.Workers.ExampleWorker do
  @moduledoc """
  Reference Oban worker — copy this when you add real background work.

  Enqueue it from anywhere (a context function, a controller action)
  with a JSON-serialisable args map:

      %{user_id: user.id}
      |> ElixirReactStarter.Workers.ExampleWorker.new()
      |> Oban.insert()

  Oban runs `perform/1` on a worker in the `:default` queue. Returning
  `:ok` (or `{:ok, _}`) marks the job complete; returning `{:error, _}`
  or raising marks it failed and Oban retries with backoff up to
  `max_attempts`.

  Keep workers idempotent — a job can run more than once (retries,
  at-least-once delivery), so performing it twice must be safe.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("ExampleWorker ran with args: #{inspect(args)}")
    :ok
  end
end
