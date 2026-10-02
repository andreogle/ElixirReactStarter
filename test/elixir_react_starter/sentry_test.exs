defmodule ElixirReactStarter.SentryTest do
  use ExUnit.Case, async: true

  alias ElixirReactStarter.Sentry, as: SentryGlue

  describe "before_send/1" do
    test "keeps only the id from the user context" do
      event =
        build_event(
          user: %{id: 42, email: "jane@example.com", username: "Jane", ip_address: "192.0.2.1"}
        )

      assert %Sentry.Event{user: user} = SentryGlue.before_send(event)
      assert user == %{id: 42}
    end

    test "keeps only the id with string keys too" do
      event =
        build_event(
          user: %{"id" => 42, "email" => "jane@example.com", "ip_address" => "192.0.2.1"}
        )

      assert %Sentry.Event{user: user} = SentryGlue.before_send(event)
      assert user == %{"id" => 42}
    end

    test "passes through an event with no user context unchanged" do
      event = build_event(user: nil)

      assert SentryGlue.before_send(event) == event
    end

    test "keeps the request location but drops request data and IP addresses" do
      event =
        build_event(
          request: %Sentry.Interfaces.Request{
            method: "POST",
            url: "https://user:password@example.com/login?email=jane@example.com#secret",
            query_string: "email=jane@example.com",
            data: %{"name" => "Jane"},
            cookies: %{"session" => "secret"},
            headers: %{"x-forwarded-for" => "192.0.2.1"},
            env: %{"REMOTE_ADDR" => "192.0.2.1"}
          }
        )

      assert SentryGlue.before_send(event).request == %Sentry.Interfaces.Request{
               method: "POST",
               url: "https://example.com/login"
             }
    end

    test "preserves errors outside a request" do
      event = build_event(request: nil, user: nil)
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
