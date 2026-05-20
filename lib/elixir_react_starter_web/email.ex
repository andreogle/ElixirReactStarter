defmodule ElixirReactStarterWeb.Email do
  @moduledoc """
  Email composition. Builds Swoosh emails with both HTML and plain-text
  bodies. Content is translated via Gettext based on the request locale
  (which the auth plug resolves from `Accept-Language`).

  ## Adding a new email

  1. Add a function here that returns a `%Swoosh.Email{}`. Use
     `dgettext("app", ...)` for every user-visible string.
  2. Add matching `email_html/<name>.html.heex` and
     `email_text/<name>.text.heex` templates under the controllers
     directory. The HTML version uses the `<.email_layout>` slot
     component from `ElixirReactStarterWeb.EmailHTML`.
  3. Reference the templates as `EmailHTML.<name>(assigns)` and
     `EmailText.<name>(assigns)` and pipe each through
     `render_to_string/1`.
  4. Run `mix gettext.extract --merge` to pick up the new strings.

  ## Why both HTML and plain text

  Spam filters score multipart messages higher than HTML-only ones.
  Some clients (notifications, terminal-based readers) also display
  the text part by preference.

  ## Security

  Never put tokens in the subject line — they show on lock screens.
  Body only.
  """

  import Swoosh.Email

  require Logger

  use Gettext, backend: ElixirReactStarterWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: ElixirReactStarterWeb.Endpoint,
    router: ElixirReactStarterWeb.Router

  alias ElixirReactStarter.Log
  alias ElixirReactStarterWeb.EmailHTML
  alias ElixirReactStarterWeb.EmailText
  alias ElixirReactStarterWeb.Endpoint
  alias Phoenix.HTML.Safe

  @from {"ElixirReactStarter", "noreply@example.com"}

  @doc """
  Builds the email-confirmation message. The `raw_token` is embedded in
  a single-click URL the recipient opens to confirm.
  """
  def confirmation_email(%{email: email}, raw_token) do
    url = Endpoint.url() <> ~p"/confirm-email?token=#{raw_token}"

    assigns = %{
      url: url,
      heading: dgettext("app", "Confirm your email"),
      greeting:
        dgettext("app", "Welcome — click the button below to confirm your email address."),
      button_label: dgettext("app", "Confirm email"),
      paste_url_label: dgettext("app", "Or copy and paste this URL into your browser:"),
      expiry: dgettext("app", "This link expires in 1 hour."),
      ignore:
        dgettext("app", "If you didn't create this account, you can safely ignore this email.")
    }

    Logger.info("Sending confirmation email to #{Log.redact_email(email)}")

    new()
    |> to(email)
    |> from(@from)
    |> subject(dgettext("app", "Confirm your email"))
    |> html_body(render_to_string(EmailHTML.confirm_email(assigns)))
    |> text_body(render_to_string(EmailText.confirm_email(assigns)))
  end

  @doc """
  Builds the password-reset message. The `raw_token` is embedded in a
  single-click URL that lands the recipient on the reset-password page.
  """
  def password_reset_email(%{email: email}, raw_token) do
    url = Endpoint.url() <> ~p"/reset-password?token=#{raw_token}"

    assigns = %{
      url: url,
      heading: dgettext("app", "Reset your password"),
      greeting: dgettext("app", "Click the button below to choose a new password."),
      button_label: dgettext("app", "Reset password"),
      paste_url_label: dgettext("app", "Or copy and paste this URL into your browser:"),
      expiry:
        dgettext(
          "app",
          "This link expires in 1 hour. If you didn't request a reset, you can safely ignore this email."
        ),
      security: dgettext("app", "For your security, never share this link with anyone.")
    }

    Logger.info("Sending password reset email to #{Log.redact_email(email)}")

    new()
    |> to(email)
    |> from(@from)
    |> subject(dgettext("app", "Reset your password"))
    |> html_body(render_to_string(EmailHTML.password_reset(assigns)))
    |> text_body(render_to_string(EmailText.password_reset(assigns)))
  end

  defp render_to_string(template) do
    template
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
