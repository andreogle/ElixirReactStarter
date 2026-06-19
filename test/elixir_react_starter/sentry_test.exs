defmodule ElixirReactStarter.SentryTest do
  use ExUnit.Case, async: true

  alias ElixirReactStarter.Sentry, as: SentryGlue

  describe "before_send/1" do
    test "drops the email from the user context but keeps the id" do
      event = build_event(user: %{id: 42, email: "jane@example.com"})

      assert %Sentry.Event{user: user} = SentryGlue.before_send(event)
      assert user == %{id: 42}
    end

    test "drops a string-keyed email too" do
      event = build_event(user: %{"id" => 42, "email" => "jane@example.com"})

      assert %Sentry.Event{user: user} = SentryGlue.before_send(event)
      assert user == %{"id" => 42}
    end

    test "passes through an event with no user context unchanged" do
      event = build_event(user: nil)

      assert SentryGlue.before_send(event) == event
    end
  end

  # Sentry.Event enforces :event_id and :timestamp; the values are
  # irrelevant to before_send, so any placeholders do.
  defp build_event(fields) do
    struct!(Sentry.Event, [event_id: "test-event", timestamp: "1970-01-01T00:00:00Z"] ++ fields)
  end

  describe "scrub_params/1" do
    test "drops PII/secret params while keeping benign ones" do
      conn = %Plug.Conn{
        params: %{
          "email" => "jane@example.com",
          "new_email" => "jane2@example.com",
          "password" => "hunter2",
          "current_password" => "hunter1",
          "token" => "abc",
          "code" => "123456",
          "secret" => "shh",
          "name" => "Jane"
        }
      }

      scrubbed = SentryGlue.scrub_params(conn)

      for key <- ~w(email new_email password current_password token code secret) do
        refute Map.has_key?(scrubbed, key), "expected #{key} to be scrubbed"
      end

      assert scrubbed["name"] == "Jane"
    end
  end
end
