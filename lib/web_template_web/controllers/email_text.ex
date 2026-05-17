defmodule WebTemplateWeb.EmailText do
  @moduledoc """
  Plain-text email templates.

  Mirrors `WebTemplateWeb.EmailHTML`. Spam filters score messages with
  both bodies higher than HTML-only ones, so every email function in
  `WebTemplateWeb.Email` ships a matching `*.text.heex` template here.
  """

  use WebTemplateWeb, :html

  embed_templates "email_text/*"
end
