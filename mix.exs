defmodule WebTemplate.MixProject do
  use Mix.Project

  def project do
    [
      app: :web_template,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
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
      name: "WebTemplate",
      main: "readme",
      # Drop the epub formatter (default `[:html, :epub, :markdown]`).
      # `:html` is what `/dev/docs` serves; `:markdown` produces the
      # llms.txt dump useful for feeding into LLM context windows.
      formatters: ["html", "markdown"],
      extras: ["README.md", "CLAUDE.md"],
      groups_for_modules: [
        Web: ~r/^WebTemplateWeb($|\.)/,
        Ecto: ~r/^WebTemplate\.Ecto\./,
        "Mix Tasks": ~r/^Mix\.Tasks\./
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {WebTemplate.Application, []},
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
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.5"},
      {:swoosh, "~> 1.16"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tzdata, "~> 1.1"},
      {:uniq, "~> 0.6"},

      # Dev/test
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
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
        "tailwind web_template",
        "cmd rm -rf priv/static/assets/chunks",
        "esbuild web_template",
        "cmd node assets/build/generate-ssr-pages.js",
        "esbuild web_template_ssr"
      ],
      "assets.deploy": [
        "tailwind web_template --minify",
        "cmd rm -rf priv/static/assets/chunks",
        "esbuild web_template --minify",
        "cmd node assets/build/generate-ssr-pages.js",
        "esbuild web_template_ssr",
        "phx.digest",
        # phx.digest writes `.gz` next to every asset; this step writes the
        # brotli sibling so Plug.Static can serve whichever the request
        # accepts. Keep it last so it sees both the hashed and plain files.
        "cmd node assets/build/compress-assets.js"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "git.hooks": ["cmd git config core.hooksPath scripts/hooks"],
      precommit: [
        "compile --warnings-as-errors",
        "lint",
        "i18n.check",
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
