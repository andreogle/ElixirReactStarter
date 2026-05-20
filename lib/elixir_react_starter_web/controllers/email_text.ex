defmodule ElixirReactStarterWeb.EmailText do
  @moduledoc """
  Plain-text email templates.

  Mirrors `ElixirReactStarterWeb.EmailHTML`. Spam filters score messages with
  both bodies higher than HTML-only ones, so every email function in
  `ElixirReactStarterWeb.Email` ships a matching `*.text.heex` template here.
  """

  use ElixirReactStarterWeb, :html

  embed_templates "email_text/*"
end
