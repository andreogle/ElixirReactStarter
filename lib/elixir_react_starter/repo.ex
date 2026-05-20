defmodule ElixirReactStarter.Repo do
  use Ecto.Repo,
    otp_app: :elixir_react_starter,
    adapter: Ecto.Adapters.Postgres

  use ElixirReactStarter.Ecto.OKRepo
end
