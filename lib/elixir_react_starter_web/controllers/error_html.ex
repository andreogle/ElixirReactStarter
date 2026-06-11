defmodule ElixirReactStarterWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use ElixirReactStarterWeb, :html

  # Branded full-page error documents. `404.html.heex` and `500.html.heex`
  # are self-contained (inline styles, no external assets) so they render
  # even when the JS/CSS bundle is what failed. They're served with
  # `layout: false` (see the endpoint's :render_errors config).
  embed_templates "error_html/*"

  # Fallback for any status without a dedicated template (403, 422, …):
  # render the plain status message. For example, "401.html" becomes
  # "Unauthorized".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
