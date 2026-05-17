defmodule WebTemplateWeb.EmailHTML do
  @moduledoc """
  HTML email templates.

  Templates live in `email_html/*.html.heex` and embed via
  `embed_templates/1`. The `email_layout/1` slot component below wraps
  every template with a table-based shell that renders consistently
  across mail clients (max-width 600px, inline styles, no media
  queries, no flexbox).
  """

  use WebTemplateWeb, :html

  embed_templates "email_html/*"

  @doc """
  Email layout wrapper. Table-based, 600px max-width.

  `current_year` is computed here rather than threaded through every
  builder's assigns map.
  """
  def email_layout(assigns) do
    assigns = Map.put_new_lazy(assigns, :current_year, fn -> DateTime.utc_now().year end)

    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>WebTemplate</title>
        <style type="text/css">
          body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
          table { border-collapse: collapse !important; }
          body { margin: 0; padding: 0; width: 100% !important; background-color: #f7f7f7; }
        </style>
      </head>
      <body style="margin: 0; padding: 0; background-color: #f7f7f7;">
        <table
          role="presentation"
          cellpadding="0"
          cellspacing="0"
          style="width: 100%; background-color: #f7f7f7;"
        >
          <tr>
            <td>
              <table
                role="presentation"
                cellpadding="0"
                cellspacing="0"
                style="width: 100%; max-width: 600px; margin: 40px auto; background-color: #ffffff; border-radius: 8px; overflow: hidden;"
              >
                <tr>
                  <td style="padding: 48px 40px; text-align: center; border-bottom: 1px solid #e8e7ed;">
                    <h1 style="margin: 0; font-size: 28px; font-weight: 600; color: #1e1b4b; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
                      WebTemplate
                    </h1>
                  </td>
                </tr>
                {render_slot(@inner_block)}
                <tr>
                  <td style="padding: 32px 40px; text-align: center; background-color: #fafafa; border-top: 1px solid #e8e7ed;">
                    <p style="margin: 0; font-size: 12px; color: #bbbbbb; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
                      &copy; {@current_year} WebTemplate. All rights reserved.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end
end
