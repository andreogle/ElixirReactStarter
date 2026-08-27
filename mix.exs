defmodule ElixirReactStarter.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_react_starter,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      test_coverage: test_coverage(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Coverage scope. We exclude code with no meaningful runtime branches
  # to test, so the percentage reflects real logic:
  #
  #   * Framework boilerplate — supervision tree, Endpoint, Repo, Mailer,
  #     Gettext backend, Telemetry metric defs, generated release tasks,
  #     and the Layouts / ErrorHTML shells.
  #   * Template-/macro-only modules — `Context` and `EmailText` are just
  #     a macro call (`embed_templates` / `__using__`), so they have no
  #     trackable source lines and always read 0% even though their
  #     behaviour is exercised (context_test, email_test).
  #   * Pure tooling — the custom mix tasks (exercised by CI/precommit).
  #   * Test-support helpers (`*Case`, `*Factory`) and derived protocol
  #     impls (the redacted-field `Inspect.*`).
  defp test_coverage do
    [
      summary: [threshold: 90],
      ignore_modules: [
        ElixirReactStarter.Application,
        ElixirReactStarter.Context,
        ElixirReactStarter.Mailer,
        ElixirReactStarter.RateLimit,
        ElixirReactStarter.Release,
        ElixirReactStarter.Repo,
        ElixirReactStarterWeb.DevE2EController,
        ElixirReactStarterWeb.Endpoint,
        ElixirReactStarterWeb.EmailText,
        ElixirReactStarterWeb.ErrorHTML,
        ElixirReactStarterWeb.Gettext,
        ElixirReactStarterWeb.Layouts,
        ElixirReactStarterWeb.Telemetry,
        Mix.Tasks.Lint,
        Mix.Tasks.I18n.Check,
        Mix.Tasks.Routes.Gen,
        ~r/^Inspect\./,
        ~r/Case$/,
        ~r/Factory$/
      ]
    ]
  end

  # PLT cache lives under `priv/plts/` and is keyed on `Mix.env()` so
  # dev and test don't trample each other. CI restores from cache to
  # avoid the multi-minute first build.
  defp dialyzer do
    [
      plt_core_path: "priv/plts/core.plt",
      plt_local_path: "priv/plts/#{Mix.env()}.plt",
      plt_add_apps: [:ex_unit, :mix],
      ignore_warnings: ".dialyzer_ignore.exs",
      flags: [:error_handling, :underspecs, :unmatched_returns]
    ]
  end

  # Local-only ex_doc config. `mix docs` writes HTML to `doc/`, which is
  # gitignored; in dev the endpoint serves it at /dev/docs/index.html.
  # ex_doc's HTML ships with full-text search built in.
  defp docs do
    [
      name: "ElixirReactStarter",
      main: "readme",
      # Drop the epub formatter (default `[:html, :epub, :markdown]`).
      # `:html` is what `/dev/docs` serves; `:markdown` produces the
      # llms.txt dump useful for feeding into LLM context windows.
      formatters: ["html", "markdown"],
      # README is the landing page (getting started). Developer guides live
      # in docs/ and are picked up automatically — drop a new `.md` there and
      # it shows up under "Guides".
      extras: ["README.md", "CLAUDE.md"] ++ Path.wildcard("docs/*.md"),
      groups_for_extras: [
        Guides: ~r"docs/"
      ],
      groups_for_modules: [
        Web: ~r/^ElixirReactStarterWeb($|\.)/,
        Ecto: ~r/^ElixirReactStarter\.Ecto\./,
        "Mix Tasks": ~r/^Mix\.Tasks\./
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ElixirReactStarter.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:argon2_elixir, "~> 4.1"},
      {:inertia, "~> 2.0"},
      {:bandit, "~> 1.5"},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_sql, "~> 3.13"},
      {:exflect, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:hammer, "~> 7.0"},
      {:jason, "~> 1.2"},
      {:oban, "~> 2.19"},
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.9.0"},
      {:phoenix_live_view, "~> 1.2.0"},
      {:postgrex, ">= 0.0.0"},
      {:remote_ip, "~> 1.2"},
      {:req, "~> 0.5"},
      {:sentry, "~> 13.2"},
      {:swoosh, "~> 1.16"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tzdata, "~> 1.1"},

      # Dev/test
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      # esbuild's --splitting writes content-hashed chunk filenames without
      # cleaning stale ones. Wipe the chunks dir first so the only files left
      # after a build are the ones the current bundle actually references.
      "assets.build": [
        "compile",
        "tailwind elixir_react_starter",
        "cmd rm -rf priv/static/assets/chunks",
        # Generate the page registries (_pages.ts + _ssr_pages.ts) before
        # either esbuild run: the client bundle imports _pages.ts and the
        # SSR bundle imports _ssr_pages.ts.
        "cmd node assets/build/generate-ssr-pages.cjs",
        # Generate the typed frontend route table (routes.ts) from the router
        # so the two can't drift. Guarded by `routes.gen --check` in precommit.
        "routes.gen",
        ~s(esbuild elixir_react_starter --define:process.env.NODE_ENV='"development"'),
        "esbuild elixir_react_starter_ssr"
      ],
      "assets.deploy": [
        "tailwind elixir_react_starter --minify",
        "cmd rm -rf priv/static/assets/chunks",
        # Generate the page registries before either esbuild run (see
        # assets.build above).
        "cmd node assets/build/generate-ssr-pages.cjs",
        # Generate the typed frontend route table (see assets.build above).
        "routes.gen",
        # External source maps so Sentry can de-minify production stack
        # traces. upload-sourcemaps.cjs ships them to Sentry and deletes the
        # .map files before phx.digest runs, so they're never served.
        ~s(esbuild elixir_react_starter --minify --sourcemap=external --define:process.env.NODE_ENV='"production"'),
        "esbuild elixir_react_starter_ssr",
        "cmd node assets/build/upload-sourcemaps.cjs",
        "phx.digest",
        # phx.digest writes `.gz` next to every asset; this step writes the
        # brotli sibling so Plug.Static can serve whichever the request
        # accepts. Keep it last so it sees both the hashed and plain files.
        "cmd node assets/build/compress-assets.cjs"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "git.hooks": ["cmd git config core.hooksPath scripts/hooks"],
      precommit: [
        "cmd ./scripts/check-tool-versions.sh",
        "compile --warnings-as-errors",
        "lint",
        "i18n.check",
        # Fail if assets/js/routes.ts has drifted from the router (someone
        # changed a route without regenerating the frontend table).
        "routes.gen --check",
        "deps.unlock --unused",
        "format",
        "test",
        "docs",
        # ex_doc's HTML references `docs_config.js` (intended for the
        # multi-version switcher) but never generates it. Write a stub
        # so every page load doesn't 404 when self-served at /dev/docs.
        &write_docs_config_stub/1
      ],
      # `precommit` stays fast (no dialyzer). CI runs `precommit.full`
      # so PRs still get static-analysis coverage; the PLT cache makes
      # repeat runs cheap.
      "precommit.full": ["precommit", "dialyzer"],
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build", "git.hooks"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp write_docs_config_stub(_args) do
    File.write!("doc/docs_config.js", "var versionNodes = [];\n")
  end
end
