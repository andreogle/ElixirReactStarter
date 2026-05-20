defmodule ElixirReactStarterWeb.LocaleController do
  @moduledoc """
  Changes the request locale for both anonymous and authenticated
  users.

  Storage:
    * Always sets a 1-year `locale` cookie. This makes anonymous users'
      choice persist across visits, and gives authenticated users a
      fallback if they later log out.
    * If a user is signed in, also writes `user.locale` so the
      preference follows them across devices and sessions.

  The route lives outside `:require_authenticated_user` so the auth
  pages (Login, Register, ForgotPassword, etc.) can switch locale too.
  """

  use ElixirReactStarterWeb, :controller

  alias ElixirReactStarter.Accounts

  action_fallback ElixirReactStarterWeb.FallbackController

  @supported_locales Application.compile_env(:elixir_react_starter, :supported_locales, ["en"])
  # 1 year, in seconds.
  @cookie_max_age 60 * 60 * 24 * 365

  def update(conn, %{"locale" => locale}) when locale in @supported_locales do
    case maybe_update_user(conn.assigns[:current_user], locale) do
      :ok ->
        conn
        |> put_resp_cookie("locale", locale,
          max_age: @cookie_max_age,
          http_only: false,
          same_site: "Lax"
        )
        |> redirect(to: safe_referer(List.first(get_req_header(conn, "referer"))))

      {:error, _changeset} ->
        {:error, {:bad_request, dgettext("app", "Unsupported locale")}}
    end
  end

  def update(_conn, _params) do
    {:error, {:bad_request, dgettext("app", "Unsupported locale")}}
  end

  defp maybe_update_user(nil, _locale), do: :ok

  defp maybe_update_user(user, locale) do
    case Accounts.update_user_locale(user, %{locale: locale}) do
      {:ok, _user} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp safe_referer(nil), do: ~p"/"

  defp safe_referer(referer) do
    case URI.parse(referer) do
      %URI{path: "/" <> _ = path} -> path
      _ -> ~p"/"
    end
  end
end
