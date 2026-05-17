defmodule WebTemplate.Repo do
  use Ecto.Repo,
    otp_app: :web_template,
    adapter: Ecto.Adapters.Postgres

  use WebTemplate.Ecto.OKRepo
end
