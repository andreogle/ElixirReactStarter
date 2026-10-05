defmodule ElixirReactStarter.SSRRuntimeTest do
  @moduledoc """
  The production image must run the SSR Node workers with
  `NODE_ENV=production`. Without it the `nodejs` package's server reloads
  the SSR bundle on every render (its development hot reload), each reload
  keeps several megabytes of heap, and a worker aborts after a few dozen
  renders under the image's heap cap.
  """

  use ExUnit.Case, async: true

  test "the release image runs Node in production mode" do
    dockerfile = File.read!(Path.expand("../../Dockerfile", __DIR__))
    assert dockerfile =~ ~r/^ENV NODE_ENV=production$/m
  end
end
