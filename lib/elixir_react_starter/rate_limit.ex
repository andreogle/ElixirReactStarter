defmodule ElixirReactStarter.RateLimit do
  @moduledoc """
  ETS-backed rate limiter ([Hammer](https://hexdocs.pm/hammer)).

  Backs `ElixirReactStarterWeb.Plugs.RateLimit`, which throttles
  abuse-prone endpoints (the auth form posts). Started in the
  application supervision tree; counters live in an ETS table local to
  the node.
  """
  use Hammer, backend: :ets
end
