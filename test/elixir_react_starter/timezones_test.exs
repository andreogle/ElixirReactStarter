defmodule ElixirReactStarter.TimezonesTest do
  use ExUnit.Case, async: true

  alias ElixirReactStarter.Timezones

  doctest ElixirReactStarter.Timezones

  describe "offset_minutes/1" do
    test "returns the current offset in minutes for a valid zone" do
      assert Timezones.offset_minutes("UTC") == 0
      assert is_integer(Timezones.offset_minutes("America/New_York"))
    end

    test "returns nil for an unknown zone" do
      assert Timezones.offset_minutes("Not/AZone") == nil
    end

    test "returns nil for non-binary input" do
      assert Timezones.offset_minutes(nil) == nil
      assert Timezones.offset_minutes(123) == nil
    end
  end
end
