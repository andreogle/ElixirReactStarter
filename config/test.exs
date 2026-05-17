import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :web_template, WebTemplate.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "web_template_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :web_template, WebTemplateWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "KsgZWbuwrS5Cm+BzSXFR0V5tOLLdCWM+VQbjxPIQoHuTQ5sExs2PS5IIE+6MwVo4",
  server: false

# In test we don't send emails
config :web_template, WebTemplate.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Skip SSR in tests — no Node.js worker pool is started under MIX_ENV=test,
# and Inertia's controller would block trying to call into it. Tests assert
# on the JSON page payload embedded in the HTML response, not on rendered
# React output.
config :inertia, ssr: false

# Use fast hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8

# Run Oban in manual testing mode — jobs are enqueued but not executed
# automatically. Tests assert on the job queue or drain explicitly.
config :web_template, Oban, testing: :manual

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
