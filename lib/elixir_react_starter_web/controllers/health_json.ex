defmodule ElixirReactStarterWeb.HealthJSON do
  @moduledoc """
  JSON view for the liveness endpoint.
  """

  def show(_assigns) do
    %{status: "ok"}
  end
end
