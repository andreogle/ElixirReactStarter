defmodule WebTemplateWeb.ChannelCase do
  @moduledoc """
  Test case for channels. Imports `Phoenix.ChannelTest` so suites can
  use `connect/2`, `subscribe_and_join/3`, `assert_push/2`, etc.

  Async-safe because the SQL sandbox isolates each test.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import WebTemplateWeb.ChannelCase
      import WebTemplate.Factory

      @endpoint WebTemplateWeb.Endpoint
    end
  end

  setup tags do
    WebTemplate.DataCase.setup_sandbox(tags)
    :ok
  end
end
