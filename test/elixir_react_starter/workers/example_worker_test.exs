defmodule ElixirReactStarter.Workers.ExampleWorkerTest do
  use ElixirReactStarter.DataCase, async: true

  # Oban runs in :manual mode under test (config/test.exs), so jobs are
  # enqueued but not executed until we drain them.
  use Oban.Testing, repo: ElixirReactStarter.Repo

  alias ElixirReactStarter.Workers.ExampleWorker

  @moduletag :capture_log

  test "enqueues onto the default queue with the given args" do
    assert {:ok, _job} = Oban.insert(ExampleWorker.new(%{user_id: "abc"}))
    assert_enqueued(worker: ExampleWorker, args: %{user_id: "abc"}, queue: :default)
  end

  test "perform/1 succeeds" do
    assert :ok = perform_job(ExampleWorker, %{user_id: "abc"})
  end
end
