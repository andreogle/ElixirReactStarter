defmodule Mix.Tasks.Routes.GenTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Routes.Gen

  defmodule ResourceRouter do
    use Phoenix.Router

    get "/", ElixirReactStarterWeb.PageController, :home
    get "/items", ElixirReactStarterWeb.PageController, :home
    post "/items", ElixirReactStarterWeb.PageController, :home
    get "/items/:id", ElixirReactStarterWeb.PageController, :home
    get "/items/:id/edit", ElixirReactStarterWeb.PageController, :home
  end

  defmodule FileRouter do
    use Phoenix.Router

    get "/calendar.ics", ElixirReactStarterWeb.PageController, :home
  end

  defmodule CollisionRouter do
    use Phoenix.Router

    get "/some-path", ElixirReactStarterWeb.PageController, :home
    get "/some_path", ElixirReactStarterWeb.PageController, :home
  end

  test "collection and detail paths have distinct typed builders" do
    content = Gen.build_module(ResourceRouter)

    assert content =~ "root: (q?: QueryParams) => `/${query(q)}`"
    assert content =~ "items: (q?: QueryParams) => `/items${query(q)}`"
    assert content =~ "itemsId: (params: { id: string | number }, q?: QueryParams)"
    assert content =~ "itemsIdEdit: (params: { id: string | number }, q?: QueryParams)"
    assert content =~ "/items/${params.id}/edit${query(q)}"
    assert [["  items: "]] = Regex.scan(~r/  items: /, content)
  end

  test "file extensions produce valid builder names" do
    assert Gen.build_module(FileRouter) =~
             "calendarIcs: (q?: QueryParams) => `/calendar.ics${query(q)}`"
  end

  test "ambiguous names still fail explicitly" do
    assert_raise Mix.Error, ~r/distinct paths collapsed to the same name/, fn ->
      Gen.build_module(CollisionRouter)
    end
  end

  test "existing routes and exclusions remain unchanged" do
    content = Gen.build_module()
    assert content == File.read!("assets/js/routes.ts")
    refute content =~ "/health"
    refute content =~ "/dev/"
  end
end
