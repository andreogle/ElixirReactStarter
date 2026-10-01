defmodule ElixirReactStarter.Sentry do
  @moduledoc """
  Limits structured user and request data sent to Sentry.

  Two hooks:

    * `before_send/1` — keeps only the user's ID and the request method/URL
      without its query string. Drops bodies, cookies, headers and IPs.
    * `scrub_params/1` — a `Sentry.PlugContext` body scrubber. It extends
      the SDK default (which masks `password`/`secret`/…) to also drop the
      email/token/code params that flow through auth and account routes.

  Wired in `config/config.exs` (`before_send`) and on the endpoint's
  `Sentry.PlugContext` plug (`scrub_params`).
  """

  # Request params that can carry PII or secrets and must never reach Sentry.
  # Kept as strings because `Sentry.PlugContext.default_body_scrubber/1`
  # returns a string-keyed map of the parsed body.
  @pii_params ~w(email new_email current_password password password_confirmation token code secret)

  @doc """
  Keeps user IDs and request locations while limiting personal data.
  """
  def before_send(%Sentry.Event{} = event) do
    user = if is_map(event.user), do: Map.take(event.user, [:id, "id"]), else: event.user
    %{event | user: user, request: scrub_request(event.request)}
  end

  defp scrub_request(nil), do: nil

  defp scrub_request(request) do
    url =
      if request.url do
        request.url
        |> URI.parse()
        |> Map.merge(%{query: nil, fragment: nil, userinfo: nil})
        |> URI.to_string()
      end

    %Sentry.Interfaces.Request{method: request.method, url: url}
  end

  @doc """
  `Sentry.PlugContext` body scrubber. Runs the SDK default scrubber, then
  drops the project's additional PII/secret params.
  """
  def scrub_params(conn) do
    conn
    |> Sentry.PlugContext.default_body_scrubber()
    |> Map.drop(@pii_params)
  end
end
