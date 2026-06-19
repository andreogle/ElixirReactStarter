defmodule ElixirReactStarter.Sentry do
  @moduledoc """
  Sentry glue that enforces the project's no-PII rule on everything that
  leaves the system.

  Two hooks:

    * `before_send/1` — the last gate every event passes through. It strips
      the user's email (we keep the user *id* for correlation, never the
      address) so a misconfigured call site can't leak one into Sentry.
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
  `before_send` callback. Drops the email from the event's user context;
  returns the event otherwise unchanged so it still ships.
  """
  def before_send(%Sentry.Event{user: user} = event) when is_map(user) do
    %{event | user: Map.drop(user, [:email, "email"])}
  end

  def before_send(%Sentry.Event{} = event), do: event

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
