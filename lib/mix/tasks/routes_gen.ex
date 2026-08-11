defmodule Mix.Tasks.Routes.Gen do
  @shortdoc "Generates the typed frontend route table (assets/js/routes.ts) from the Phoenix router"
  @moduledoc """
  Introspects `ElixirReactStarterWeb.Router` and writes a typed TypeScript
  path-builder module to `assets/js/routes.ts`, so the frontend can never
  drift from the server's routes.

  Phoenix 1.7+ dropped named route helpers in favour of the `~p` sigil, so
  `~p` itself can't be exported. What is exported instead is the route
  *table* `~p` validates against: one typed builder per distinct
  browser-facing path, with `:param` segments becoming required typed
  arguments and an optional query object.

      mix routes.gen          # regenerate assets/js/routes.ts
      mix routes.gen --check  # fail (non-zero exit) if the file is stale; writes nothing

  `--check` is wired into `mix precommit`; plain generation is wired into
  `mix assets.build` / `mix assets.deploy` and the dev watcher
  (`assets/build/watch-routes.cjs`), so the file stays in sync automatically.

  ## Scope

  Only browser-facing routes reach the React frontend, so JSON-only
  endpoints and dev-only tooling are excluded:

    * `@excluded_plugs` — controllers that only speak JSON
    * `@excluded_path_prefixes` — dev-only mount points

  Adjust those module attributes if the surface changes. Route *names* are
  derived from the static path segments (`/settings/email/apply-change` →
  `settingsEmailApplyChange`); if two paths collapse to the same name the
  task raises rather than emit a silently-shadowed builder.
  """

  use Mix.Task

  @router ElixirReactStarterWeb.Router
  @output "assets/js/routes.ts"

  # JSON-only endpoints — never navigated to from the React app.
  @excluded_plugs [
    ElixirReactStarterWeb.HealthController,
    ElixirReactStarterWeb.DevE2EController
  ]

  # Dev-only tooling (LiveDashboard, Swoosh mailbox) — not part of the app UI.
  @excluded_path_prefixes ["/dev"]

  @impl true
  def run(args) do
    Mix.Task.run("compile")

    content = build_module()
    path = Path.join(File.cwd!(), @output)

    if "--check" in args do
      run_check(path, content)
    else
      write(path, content)
    end
  end

  # =============================================================================
  # Output handling
  # =============================================================================
  defp write(path, content) do
    if File.exists?(path) and File.read!(path) == content do
      Mix.shell().info("routes.gen: #{@output} already up to date")
    else
      File.write!(path, content)
      Mix.shell().info("routes.gen: wrote #{@output}")
    end
  end

  defp run_check(path, content) do
    cond do
      not File.exists?(path) ->
        Mix.raise(
          "routes.gen --check: #{@output} is missing. Run `mix routes.gen` and commit it."
        )

      File.read!(path) == content ->
        Mix.shell().info("routes.gen --check: #{@output} is up to date")

      true ->
        Mix.raise(
          "routes.gen --check: #{@output} is stale. Run `mix routes.gen` and commit the result."
        )
    end
  end

  # =============================================================================
  # Route extraction
  # =============================================================================
  defp build_module do
    entries =
      @router
      |> Phoenix.Router.routes()
      |> Enum.filter(&included?/1)
      |> Enum.map(& &1.path)
      |> Enum.uniq()
      |> Enum.map(&route_entry/1)
      |> ensure_unique_names!()
      |> Enum.sort_by(& &1.name)

    render(entries)
  end

  defp included?(%{plug: plug, path: path}) do
    plug not in @excluded_plugs and
      not Enum.any?(@excluded_path_prefixes, &String.starts_with?(path, &1))
  end

  defp route_entry(path) do
    segments = String.split(path, "/", trim: true)

    params =
      segments
      |> Enum.filter(&param_segment?/1)
      |> Enum.map(&String.trim_leading(&1, ":"))

    %{path: path, name: route_name(segments), params: params}
  end

  defp param_segment?(seg), do: String.starts_with?(seg, ":")

  # Name from the static segments; fall back to the param names only if a
  # path is entirely dynamic (e.g. "/:id"). Root is "root".
  defp route_name([]), do: "root"

  defp route_name(segments) do
    static = Enum.reject(segments, &param_segment?/1)
    source = if static == [], do: segments, else: static

    source
    |> Enum.flat_map(&segment_words/1)
    |> camelize()
  end

  defp ensure_unique_names!(entries) do
    dupes =
      entries
      |> Enum.group_by(& &1.name)
      |> Enum.filter(fn {_name, group} -> length(group) > 1 end)

    if dupes != [] do
      detail =
        Enum.map_join(dupes, "\n", fn {name, group} ->
          "  #{name}: #{Enum.map_join(group, ", ", & &1.path)}"
        end)

      Mix.raise(
        "routes.gen: distinct paths collapsed to the same name:\n#{detail}\n" <>
          "Disambiguate the paths or extend the naming in Mix.Tasks.Routes.Gen."
      )
    end

    entries
  end

  # =============================================================================
  # Rendering
  # =============================================================================
  defp render(entries) do
    builders = Enum.map_join(entries, "\n", &render_entry/1)

    """
    // Auto-generated by `mix routes.gen` — do not edit manually.
    //
    // Typed path builders mirroring the browser-facing routes in
    // ElixirReactStarterWeb.Router. Phoenix 1.7+ has no named route helpers
    // (the ~p sigil replaced them), so what is exported is the route *table*
    // ~p validates against: one builder per distinct path, with :param
    // segments as required typed args and an optional query object.
    //
    // Regenerated on `mix assets.build` / `assets.deploy` and the dev watcher;
    // `mix routes.gen --check` (in `mix precommit`) fails the build if this
    // file ever drifts from the router.

    type QueryValue = string | number | boolean | null | undefined;
    type QueryParams = Record<string, QueryValue | QueryValue[]>;

    function query(params?: QueryParams): string {
      if (!params) return '';
      const search = new URLSearchParams();
      for (const [key, value] of Object.entries(params)) {
        if (value === null || value === undefined) continue;
        if (Array.isArray(value)) {
          for (const item of value) {
            if (item !== null && item !== undefined) search.append(key, String(item));
          }
        } else {
          search.append(key, String(value));
        }
      }
      const qs = search.toString();
      return qs ? `?${qs}` : '';
    }

    export const routes = {
    #{builders}
    } as const;

    export type RouteName = keyof typeof routes;
    """
  end

  defp render_entry(%{name: name, path: path, params: []}) do
    ~s/  #{name}: (q?: QueryParams) => `#{path}${query(q)}`,/
  end

  defp render_entry(%{name: name, path: path, params: params}) do
    type = Enum.map_join(params, "; ", &"#{js_name(&1)}: string | number")
    tpath = ts_path(path, params)
    ~s/  #{name}: (params: { #{type} }, q?: QueryParams) => `#{tpath}${query(q)}`,/
  end

  # Replace `:param` with `${params.paramName}`. Longest param first so a
  # shorter name can't match inside a longer one (`:id` vs `:identifier`).
  defp ts_path(path, params) do
    params
    |> Enum.sort_by(&String.length/1, :desc)
    |> Enum.reduce(path, fn p, acc ->
      String.replace(acc, ":#{p}", "${params.#{js_name(p)}}")
    end)
  end

  # =============================================================================
  # Word helpers
  # =============================================================================
  defp segment_words(seg) do
    seg
    |> String.trim_leading(":")
    |> String.split(["-", "_"], trim: true)
  end

  defp js_name(param), do: param |> segment_words() |> camelize()

  defp camelize([]), do: "route"

  defp camelize([first | rest]) do
    String.downcase(first) <> Enum.map_join(rest, &String.capitalize/1)
  end
end
