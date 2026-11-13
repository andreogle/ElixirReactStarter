import Config

# Configure your database
#
# Each linked Git worktree (`wt switch --create`) tests against a database
# of its own, named after its directory, so test runs in several worktrees at
# once (the pre-commit hook's included) never share rows. The main checkout,
# whose `.git` is a directory rather than a file, keeps the plain name. The
# slug is capped so the name stays under Postgres's 63-character limit.
# MIX_TEST_PARTITION (`mix test --partitions`) splits it further. The
# post-remove hook in .config/wt.toml derives the same name to drop it, so
# change both together.
root = Path.expand("..", __DIR__)

worktree =
  if File.regular?(Path.join(root, ".git")) do
    slug = root |> Path.basename() |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")
    "_" <> String.slice(slug, 0, 30)
  else
    ""
  end

config :elixir_react_starter, ElixirReactStarter.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elixir_react_starter_test#{worktree}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :elixir_react_starter, ElixirReactStarterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "KsgZWbuwrS5Cm+BzSXFR0V5tOLLdCWM+VQbjxPIQoHuTQ5sExs2PS5IIE+6MwVo4",
  server: false

# In test we don't send emails
config :elixir_react_starter, ElixirReactStarter.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Disable auth rate limiting in tests so repeated requests from 127.0.0.1
# don't trip the limiter. The limiter logic is covered by rate_limit_test.
config :elixir_react_starter, rate_limit_enabled: false

# Skip SSR in tests — no Node.js worker pool is started under MIX_ENV=test,
# and Inertia's controller would block trying to call into it. Tests assert
# on the JSON page payload embedded in the HTML response, not on rendered
# React output.
config :inertia, ssr: false

# Use fast hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8

# Run Oban in manual testing mode — jobs are enqueued but not executed
# automatically. Tests assert on the job queue or drain explicitly.
config :elixir_react_starter, Oban, testing: :manual

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
