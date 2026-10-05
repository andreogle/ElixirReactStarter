defmodule ElixirReactStarterWeb.SSRReloaderTest do
  use ExUnit.Case, async: true

  alias ElixirReactStarterWeb.SSRReloader

  setup do
    path = Path.join(System.tmp_dir!(), "ssr-#{System.unique_integer([:positive])}.js")
    File.write!(path, "first")
    on_exit(fn -> File.rm(path) end)
    test = self()

    start_supervised!(
      {SSRReloader, path: path, interval: 20, restart: fn -> send(test, :restarted) end}
    )

    %{path: path}
  end

  test "an unchanged bundle never restarts the workers" do
    refute_receive :restarted, 150
  end

  test "a rebuilt bundle restarts them once, after it stops changing", %{path: path} do
    File.write!(path, "second, longer")

    assert_receive :restarted, 500
    refute_receive :restarted, 150
  end
end
