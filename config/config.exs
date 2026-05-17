# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :inertia,
  endpoint: WebTemplateWeb.Endpoint,
  history: [encrypt: true],
  ssr: true,
  raise_on_ssr_failure: true

config :web_template,
  ecto_repos: [WebTemplate.Repo],
  generators: [timestamp_type: :utc_datetime],
  supported_locales: ~w(en es),
  default_locale: "en"

# Use Tzdata as the IANA time-zone database. Required for
# DateTime.shift_zone/2 to work with named zones (e.g. "Europe/London",
# "America/Sao_Paulo").
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Oban powers background jobs. Add per-app cron entries under
# Oban.Plugins.Cron when workers are introduced.
config :web_template, Oban,
  repo: WebTemplate.Repo,
  engine: Oban.Engines.Basic,
  queues: [default: 10],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ]

# Configure the endpoint
config :web_template, WebTemplateWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WebTemplateWeb.ErrorHTML, json: WebTemplateWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WebTemplate.PubSub,
  live_view: [signing_salt: "c16iCWOT"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :web_template, WebTemplate.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.28.0",
  web_template: [
    # --conditions=production picks the "production" branch of every
    # subpath in package.json `exports` blocks. Some packages gate
    # their dist files behind development/production conditions —
    # without this, esbuild errors on subpath imports.
    #
    # --loader:.woff2=file copies any bundled font files into
    # priv/static/assets and rewrites their CSS URLs to point at them.
    # --asset-names puts them in chunks/ alongside lazy chunks so the
    # directory layout stays predictable.
    args:
      ~w(js/app.tsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm  --target=es2020 --conditions=production --loader:.woff2=file --asset-names=chunks/[name]-[hash] --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  web_template_ssr: [
    # SSR is Node-side; it never executes React.lazy callbacks, so
    # any CSS / fonts that those chunks pull in are dead weight here.
    # The empty loaders short-circuit them so esbuild can still
    # statically trace the dynamic imports without choking on assets
    # it would otherwise need a browser-loader for.
    args:
      ~w(js/ssr.tsx --bundle --platform=node --format=cjs --conditions=production --loader:.css=empty --loader:.woff2=empty --outdir=../priv),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  web_template: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
