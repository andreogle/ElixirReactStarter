defmodule WebTemplate.LogTest do
  use ExUnit.Case, async: true

  doctest WebTemplate.Log

  describe "redact_email/1" do
    test "redacts a normal address to its first letter" do
      assert WebTemplate.Log.redact_email("jane@example.com") == "j***@example.com"
    end

    test "returns *** for a string with no @" do
      assert WebTemplate.Log.redact_email("not-an-email") == "***"
    end

    test "returns *** for non-binary input" do
      assert WebTemplate.Log.redact_email(nil) == "***"
      assert WebTemplate.Log.redact_email(:not_a_string) == "***"
    end
  end
end
