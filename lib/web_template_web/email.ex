defmodule WebTemplateWeb.Email do
  @moduledoc """
  Email composition. Builds Swoosh emails with both HTML and plain-text
  bodies. Content is translated via Gettext based on the recipient's
  locale.

  ## Adding a new email

  1. Add a function here that returns a `%Swoosh.Email{}`. Use
     `dgettext("app", ...)` for every user-visible string and call
     `Gettext.put_locale/2` once at the top so all subsequent
     translations resolve in the recipient's language.
  2. Add matching `email_html/<name>.html.heex` and
     `email_text/<name>.text.heex` templates under the controllers
     directory. The HTML version uses the `<.email_layout>` slot
     component from `WebTemplateWeb.EmailHTML`.
  3. Reference the templates as `EmailHTML.<name>(assigns)` and
     `EmailText.<name>(assigns)` and pipe each through `render_to_string/1`.
  4. Run `mix gettext.extract --merge` to pick up the new strings.

  ## Why both HTML and plain text

  Spam filters score multipart messages higher than HTML-only ones.
  Some clients (notifications, terminal-based readers) also display
  the text part by preference.

  ## Security

  Never put codes or tokens in the subject line — they show on lock
  screens. Body only.
  """

  import Swoosh.Email

  require Logger

  use Gettext, backend: WebTemplateWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: WebTemplateWeb.Endpoint,
    router: WebTemplateWeb.Router

  alias Phoenix.HTML.Safe
  alias WebTemplate.Log
  alias WebTemplateWeb.EmailHTML
  alias WebTemplateWeb.EmailText

  @from {"WebTemplate", "noreply@example.com"}

  @doc """
  Builds a welcome email for a newly registered user. Demonstrates the
  full pattern: locale switching, dgettext lookups, matched HTML and
  text bodies.

  `recipient` is anything with `:name`, `:email`, and `:locale` keys —
  typically a user struct but a plain map works too (handy from tests).
  """
  def welcome_email(%{name: name, email: email, locale: locale}) do
    Gettext.put_locale(WebTemplateWeb.Gettext, locale || "en")

    assigns = %{
      heading: dgettext("app", "Welcome!"),
      greeting:
        dgettext(
          "app",
          "Hi %{name}, thanks for signing up. We're glad you're here.",
          name: name
        ),
      body:
        dgettext(
          "app",
          "Your account is ready. Sign in any time to get started."
        ),
      closing: dgettext("app", "Talk soon.")
    }

    Logger.info("Sending welcome email to #{Log.redact_email(email)}")

    new()
    |> to({name, email})
    |> from(@from)
    |> subject(dgettext("app", "Welcome to WebTemplate"))
    |> html_body(render_to_string(EmailHTML.welcome(assigns)))
    |> text_body(render_to_string(EmailText.welcome(assigns)))
  end

  defp render_to_string(template) do
    template
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
