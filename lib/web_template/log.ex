defmodule WebTemplate.Log do
  @moduledoc """
  Safe logging helpers. Redacts PII to prevent
  email addresses from appearing in production logs.
  """

  @doc """
  Redacts an email address for safe logging.

      iex> WebTemplate.Log.redact_email("jane@example.com")
      "j***@example.com"

      iex> WebTemplate.Log.redact_email("a@b.co")
      "a***@b.co"

      iex> WebTemplate.Log.redact_email(nil)
      "***"

  """
  def redact_email(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, domain] ->
        "#{String.first(local)}***@#{domain}"

      _ ->
        "***"
    end
  end

  def redact_email(_), do: "***"
end
