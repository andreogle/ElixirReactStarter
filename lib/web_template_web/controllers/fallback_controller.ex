defmodule WebTemplateWeb.FallbackController do
  @moduledoc """
  Default action result handler for controllers that declare
  `action_fallback WebTemplateWeb.FallbackController`. Catches the
  common `{:error, _}` shapes returned by context modules so each
  controller action doesn't have to.
  """

  use WebTemplateWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    # Per CLAUDE.md, validation errors should redirect — this fallback
    # only fires when the action forgot to handle it explicitly.
    back = referer_path(conn) || ~p"/"

    conn
    |> assign_errors(changeset)
    |> redirect(to: back)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: WebTemplateWeb.ErrorHTML)
    |> render("404.html")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_flash(:error, dgettext("app", "Unauthorized."))
    |> redirect(to: ~p"/login")
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_flash(:error, dgettext("app", "Bad request."))
    |> redirect(to: ~p"/")
  end

  def call(conn, {:error, {:bad_request, message}}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/")
  end

  # Trust only same-host paths starting with `/` (see CLAUDE.md security
  # rules on user-controlled redirect targets).
  defp referer_path(conn) do
    with [referer | _] <- get_req_header(conn, "referer"),
         %URI{path: "/" <> _ = path} <- URI.parse(referer) do
      path
    else
      _ -> nil
    end
  end
end
