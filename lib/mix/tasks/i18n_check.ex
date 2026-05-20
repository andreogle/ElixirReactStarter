defmodule Mix.Tasks.I18n.Check do
  @shortdoc "Checks i18n coverage and sync between backend and frontend"
  @moduledoc """
  Validates that:

  1. Every backend Gettext msgid in every `.pot` file has a non-empty
     translation in every locale `.po`
  2. Translations preserve every `%{interpolation}` placeholder present
     in the source msgid
  3. No translations are marked `#, fuzzy` (mix gettext.extract --merge
     flags ambiguous merges that need human review)
  4. Frontend locale files have identical key shapes across locales
  5. Every `t('key.path')` call in `assets/js/**/*.{ts,tsx}` (excluding
     test files) resolves to a key in the default locale, and every
     defined key is used somewhere
  6. No hardcoded user-facing strings sneak into controllers, plugs, or
     the email composition module
  7. No hardcoded prose lives in HEEx templates (email + root layout) —
     they must flow through assigns from a dgettext'd composition module
  8. The frontend i18next runtime config (`lng:` / `fallbackLng:` in
     `assets/js/i18n/index.ts`) matches the backend `:default_locale`

  Run with:

      mix i18n.check

  Locales, default locale, and pot domains are discovered automatically:
    * locales: `Application.fetch_env!(:elixir_react_starter, :supported_locales)`
    * default locale: `Application.fetch_env!(:elixir_react_starter, :default_locale)`
    * pot domains: every `priv/gettext/*.pot` file
  """

  use Mix.Task

  alias Expo.Message
  alias Expo.PO

  @otp_app :elixir_react_starter

  @hardcoded_patterns [
    {~r/put_flash\(:(info|error),\s*"[^"]+"\)/, "put_flash with hardcoded string (use dgettext)"},
    {~r/\|>\s*subject\("[^"]+"\)/, "email subject with hardcoded string (use dgettext)"},
    {~r/add_error\(\s*[^,]+,\s*:\w+,\s*"[^"]+"/,
     "add_error with hardcoded string (use dgettext on the message arg)"}
  ]

  @backend_scan_paths [
    "lib/elixir_react_starter_web/controllers/**/*.ex",
    "lib/elixir_react_starter_web/plugs/**/*.ex",
    "lib/elixir_react_starter_web/email.ex"
  ]

  # HEEx templates scanned for hardcoded user-facing prose. Component sigil
  # heredocs inside .ex files are not scanned — keep prose out of those.
  @heex_scan_paths [
    "lib/elixir_react_starter_web/components/layouts/*.html.heex",
    "lib/elixir_react_starter_web/controllers/email_html/*.html.heex",
    "lib/elixir_react_starter_web/controllers/email_text/*.text.heex"
  ]

  @impl true
  def run(_args) do
    Mix.Task.run("loadconfig")

    locales = locales!()
    default_locale = default_locale!()
    domains = discover_pot_domains()
    non_default_locales = locales -- [default_locale]

    errors =
      check_gettext_coverage(non_default_locales, domains) ++
        check_interpolation_parity(non_default_locales, domains) ++
        check_fuzzy_translations(non_default_locales, domains) ++
        check_frontend_locale_parity(locales, default_locale) ++
        check_frontend_key_usage(default_locale) ++
        check_frontend_i18n_config(default_locale) ++
        check_hardcoded_strings() ++
        check_heex_hardcoded_strings()

    if errors == [] do
      Mix.shell().info("i18n check passed: all translations present, no hardcoded strings found.")
    else
      Mix.shell().error("i18n check failed:\n")
      Enum.each(errors, &Mix.shell().error("  - #{&1}"))
      Mix.raise("i18n check failed with #{length(errors)} issue(s)")
    end
  end

  # =============================================================================
  # Config
  # =============================================================================
  defp locales! do
    Application.fetch_env!(@otp_app, :supported_locales)
  end

  defp default_locale! do
    Application.fetch_env!(@otp_app, :default_locale)
  end

  defp gettext_dir, do: Path.join(File.cwd!(), "priv/gettext")

  defp discover_pot_domains do
    gettext_dir()
    |> Path.join("*.pot")
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".pot"))
    |> Enum.sort()
  end

  defp pot_path(domain), do: Path.join(gettext_dir(), "#{domain}.pot")

  defp po_path(locale, domain),
    do: Path.join([gettext_dir(), locale, "LC_MESSAGES", "#{domain}.po"])

  # =============================================================================
  # Check 1: Gettext coverage
  # =============================================================================
  defp check_gettext_coverage(non_default_locales, domains) do
    for domain <- domains,
        locale <- non_default_locales,
        error <- check_locale_coverage(domain, locale) do
      error
    end
  end

  defp check_locale_coverage(domain, locale) do
    po_path = po_path(locale, domain)

    if File.exists?(po_path) do
      pot_msgids = pot_path(domain) |> parse_po!() |> all_msgids()
      translations = po_path |> parse_po!() |> translation_map()

      for msgid <- pot_msgids,
          empty?(Map.get(translations, msgid)) do
        "[#{locale}/#{domain}] Missing translation for: \"#{truncate(msgid)}\""
      end
    else
      ["[#{locale}/#{domain}] Missing .po file: #{po_path}"]
    end
  end

  # =============================================================================
  # Check 2: Interpolation parity
  # %{var} in msgid must appear in msgstr; otherwise the rendered string
  # is broken at runtime.
  # =============================================================================
  defp check_interpolation_parity(non_default_locales, domains) do
    for domain <- domains,
        locale <- non_default_locales,
        po_path = po_path(locale, domain),
        File.exists?(po_path),
        message <- parse_po!(po_path).messages,
        error <- check_message_interpolation(message, locale, domain) do
      error
    end
  end

  defp check_message_interpolation(
         %Message.Singular{msgid: msgid, msgstr: msgstr},
         locale,
         domain
       ) do
    placeholders_match(join(msgid), join(msgstr), locale, domain)
  end

  defp check_message_interpolation(
         %Message.Plural{msgid: msgid, msgid_plural: msgid_plural, msgstr: msgstr_map},
         locale,
         domain
       ) do
    singular = join(msgid)
    plural = join(msgid_plural)

    msgstr_map
    |> Enum.flat_map(fn {index, parts} ->
      translated = join(parts)
      # Index 0 must preserve singular placeholders; all others must
      # preserve plural placeholders.
      source = if index == 0, do: singular, else: plural
      placeholders_match(source, translated, locale, domain)
    end)
    |> Enum.uniq()
  end

  defp placeholders_match(_msgid, "", _locale, _domain), do: []

  defp placeholders_match(msgid, msgstr, locale, domain) do
    expected = MapSet.new(placeholders(msgid))
    actual = MapSet.new(placeholders(msgstr))
    missing = MapSet.difference(expected, actual)

    if MapSet.size(missing) == 0 do
      []
    else
      vars =
        missing
        |> MapSet.to_list()
        |> Enum.sort()
        |> Enum.map_join(", ", &"%{#{&1}}")

      [
        "[#{locale}/#{domain}] Translation drops interpolation #{vars} from: \"#{truncate(msgid)}\""
      ]
    end
  end

  defp placeholders(s) do
    ~r/%\{(\w+)\}/
    |> Regex.scan(s, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end

  # =============================================================================
  # Check 3: Fuzzy translations
  # mix gettext.extract --merge marks ambiguous merges `#, fuzzy`. They
  # render but were never verified by a translator.
  # =============================================================================
  defp check_fuzzy_translations(non_default_locales, domains) do
    for domain <- domains,
        locale <- non_default_locales,
        po_path = po_path(locale, domain),
        File.exists?(po_path),
        message <- parse_po!(po_path).messages,
        fuzzy?(message) do
      "[#{locale}/#{domain}] Fuzzy translation (needs review): \"#{truncate(msgid_of(message))}\""
    end
  end

  defp fuzzy?(%{flags: flags}) when is_list(flags) do
    Enum.any?(flags, &Enum.member?(&1, "fuzzy"))
  end

  defp fuzzy?(_), do: false

  # =============================================================================
  # Check 4: Frontend locale parity
  # =============================================================================
  defp check_frontend_locale_parity(locales, default_locale) do
    locales_dir = Path.join(File.cwd!(), "assets/js/i18n/locales")
    locale_keys = load_frontend_locale_keys(locales, locales_dir)

    case Map.get(locale_keys, default_locale) do
      nil ->
        ["[frontend] Missing locale file: #{default_locale}.ts"]

      default_keys ->
        for locale <- locales -- [default_locale],
            error <-
              compare_locale_to_default(
                locale,
                Map.get(locale_keys, locale),
                default_keys,
                default_locale
              ) do
          error
        end
    end
  end

  defp load_frontend_locale_keys(locales, locales_dir) do
    Map.new(locales, fn locale ->
      path = Path.join(locales_dir, "#{locale}.ts")
      {locale, if(File.exists?(path), do: extract_ts_keys(path))}
    end)
  end

  defp compare_locale_to_default(locale, nil, _default_keys, _default_locale) do
    ["[frontend] Missing locale file: #{locale}.ts"]
  end

  defp compare_locale_to_default(locale, other_keys, default_keys, default_locale) do
    missing_in_other = MapSet.difference(default_keys, other_keys)
    missing_in_default = MapSet.difference(other_keys, default_keys)

    Enum.map(missing_in_other, &"[frontend/#{locale}] Missing key: #{&1}") ++
      Enum.map(
        missing_in_default,
        &"[frontend/#{default_locale}] Missing key: #{&1} (present in #{locale})"
      )
  end

  # =============================================================================
  # Check 5: Frontend key usage cross-check
  # Every `t('key.path')` in .ts/.tsx must exist in the default locale.
  # Every key in the default locale must be referenced somewhere.
  #
  # Two patterns are recognised beyond plain string literals:
  #
  #   1. i18next plural suffixes — `t('foo.bar', { count })` resolves to
  #      `foo.bar_one` / `foo.bar_other` at runtime. We treat suffixed
  #      keys as used if the base key is used, and we treat the base key
  #      as defined if any plural form of it is defined.
  #
  #   2. Dynamic template-literal keys — `t(\`prefix.${var}.suffix\`)`
  #      can't be statically resolved. We extract the static prefix
  #      ("prefix.") and treat every defined key starting with that
  #      prefix as potentially used so the dead-key check doesn't
  #      flag every branch of the dispatch table.
  # =============================================================================
  @plural_suffixes ~w(_zero _one _two _few _many _other)

  defp check_frontend_key_usage(default_locale) do
    en_path = Path.join([File.cwd!(), "assets/js/i18n/locales/#{default_locale}.ts"])

    if File.exists?(en_path) do
      default_keys = extract_ts_keys(en_path)
      {static_used, dynamic_prefixes} = scan_t_calls()

      undefined =
        static_used
        |> Enum.reject(&defined_directly_or_via_plural?(&1, default_keys))
        |> Enum.sort()

      unused =
        default_keys
        |> Enum.reject(&used_directly_or_via_plural_or_prefix?(&1, static_used, dynamic_prefixes))
        |> Enum.sort()

      Enum.map(
        undefined,
        &"[frontend] t('#{&1}') referenced in code but not defined in #{default_locale}.ts"
      ) ++
        Enum.map(
          unused,
          &"[frontend] Defined in #{default_locale}.ts but never used: #{&1}"
        )
    else
      []
    end
  end

  defp defined_directly_or_via_plural?(key, default_keys) do
    MapSet.member?(default_keys, key) or
      Enum.any?(@plural_suffixes, &MapSet.member?(default_keys, key <> &1))
  end

  defp used_directly_or_via_plural_or_prefix?(key, static_used, dynamic_prefixes) do
    MapSet.member?(static_used, key) or
      plural_base_used?(key, static_used) or
      Enum.any?(dynamic_prefixes, &String.starts_with?(key, &1 <> "."))
  end

  defp plural_base_used?(key, static_used) do
    Enum.any?(@plural_suffixes, fn suffix ->
      String.ends_with?(key, suffix) and
        MapSet.member?(static_used, String.replace_suffix(key, suffix, ""))
    end)
  end

  # Production .ts/.tsx files only. Locale files and test files are
  # excluded because their `t()` calls (if any) would skew dead-key
  # detection in either direction.
  defp scan_t_calls do
    files =
      "assets/js/**/*.{ts,tsx}"
      |> Path.wildcard()
      |> Enum.reject(&excluded_t_call_source?/1)

    static = files |> Enum.flat_map(&extract_t_keys_from_file/1) |> MapSet.new()
    dynamic = files |> Enum.flat_map(&extract_t_dynamic_prefixes_from_file/1) |> Enum.uniq()

    {static, dynamic}
  end

  defp excluded_t_call_source?(path) do
    String.contains?(path, "/i18n/locales/") or
      Regex.match?(~r/\.(test|spec)\.tsx?$/, path)
  end

  defp extract_t_keys_from_file(path) do
    content = File.read!(path)

    ~r/\bt\(\s*['"]([\w.]+)['"]/
    |> Regex.scan(content, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end

  # Captures the static prefix before the first `${...}` in a
  # backtick-quoted `t()` key, e.g. `t(\`admin.members.roles.${role}\`)`
  # yields "admin.members.roles".
  defp extract_t_dynamic_prefixes_from_file(path) do
    content = File.read!(path)

    ~r/\bt\(\s*`([\w.]+)\.\$\{/
    |> Regex.scan(content, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end

  # =============================================================================
  # Check 6: Hardcoded strings in .ex files
  # =============================================================================
  defp check_hardcoded_strings do
    for path <- Enum.flat_map(@backend_scan_paths, &Path.wildcard/1),
        error <- scan_file_for_hardcoded(path) do
      error
    end
  end

  defp scan_file_for_hardcoded(path) do
    content = File.read!(path)
    relative = Path.relative_to_cwd(path)

    for {pattern, message} <- @hardcoded_patterns,
        Regex.match?(pattern, content) do
      "[#{relative}] #{message}"
    end
  end

  # =============================================================================
  # Check 7: Hardcoded prose in HEEx templates
  #
  # Heuristic — flag text nodes that look like English prose (≥3 letter
  # sequences, at least one ≥4 chars, at least one lowercase letter).
  # Brand strings ("ElixirReactStarter"), single-word labels, and pure
  # interpolated content (`{@assigns}`) are deliberately not flagged.
  # =============================================================================
  defp check_heex_hardcoded_strings do
    for path <- Enum.flat_map(@heex_scan_paths, &Path.wildcard/1),
        error <- scan_heex_for_prose(path) do
      error
    end
  end

  defp scan_heex_for_prose(path) do
    relative = Path.relative_to_cwd(path)

    path
    |> File.read!()
    |> strip_interpolations()
    |> extract_text_nodes()
    |> Enum.filter(&prose?/1)
    |> Enum.map(&"[#{relative}] Hardcoded prose (use dgettext via assigns): \"#{truncate(&1)}\"")
  end

  # Drops `{...}`, `<% ... %>`, `<%= ... %>`, `<%! ... %>`, `<%# ... %>`
  # so what remains is the static text the template would emit verbatim.
  defp strip_interpolations(content) do
    content
    |> String.replace(~r/\{[^{}]*\}/, " ")
    |> String.replace(~r/<%[!=#]?.*?%>/s, " ")
  end

  # Pull text nodes — anything between `>` and `<` for tagged templates,
  # plus raw lines for tag-less text templates like `welcome.text.heex`.
  defp extract_text_nodes(content) do
    has_tags? = Regex.match?(~r/<\/?[a-zA-Z]/, content)

    if has_tags? do
      ~r/>([^<]+)</
      |> Regex.scan(content, capture: :all_but_first)
      |> Enum.map(&hd/1)
    else
      String.split(content, "\n")
    end
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp prose?(text) do
    words = Regex.scan(~r/[A-Za-z]{2,}/, text) |> Enum.map(&hd/1)

    length(words) >= 3 and
      Enum.any?(words, &(String.length(&1) >= 4)) and
      Regex.match?(~r/[a-z]/, text)
  end

  # =============================================================================
  # Check 8: Frontend i18next runtime config
  # `assets/js/i18n/index.ts` declares the runtime `lng:` / `fallbackLng:`.
  # If those drift from the backend `:default_locale`, the frontend will
  # render the wrong locale for anonymous traffic.
  # =============================================================================
  defp check_frontend_i18n_config(default_locale) do
    path = Path.join(File.cwd!(), "assets/js/i18n/index.ts")

    if File.exists?(path) do
      content = File.read!(path)

      check_i18n_key(content, "lng", default_locale) ++
        check_i18n_key(content, "fallbackLng", default_locale)
    else
      []
    end
  end

  defp check_i18n_key(content, key, expected) do
    case Regex.run(~r/#{key}:\s*['"]([^'"]+)['"]/, content) do
      [_, ^expected] ->
        []

      [_, actual] ->
        [
          "[frontend] i18n/index.ts #{key}: '#{actual}' does not match backend :default_locale '#{expected}'"
        ]

      nil ->
        ["[frontend] i18n/index.ts is missing #{key}: '...' — expected '#{expected}'"]
    end
  end

  # =============================================================================
  # PO helpers (Expo-backed)
  # =============================================================================
  defp parse_po!(path) do
    PO.parse_file!(path)
  end

  defp all_msgids(%Expo.Messages{messages: messages}) do
    messages
    |> Enum.flat_map(fn
      %Message.Singular{msgid: msgid} -> [join(msgid)]
      %Message.Plural{msgid: msgid, msgid_plural: plural} -> [join(msgid), join(plural)]
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp translation_map(%Expo.Messages{messages: messages}) do
    Enum.reduce(messages, %{}, fn
      %Message.Singular{msgid: msgid, msgstr: msgstr}, acc ->
        Map.put(acc, join(msgid), join(msgstr))

      %Message.Plural{msgid: msgid, msgid_plural: plural, msgstr: msgstr_map}, acc ->
        acc
        |> Map.put(join(msgid), msgstr_map |> Map.get(0, []) |> join())
        |> Map.put(join(plural), msgstr_map |> Map.get(1, []) |> join())
    end)
  end

  defp msgid_of(%Message.Singular{msgid: msgid}), do: join(msgid)
  defp msgid_of(%Message.Plural{msgid: msgid}), do: join(msgid)

  defp join(parts) when is_list(parts), do: Enum.join(parts, "")
  defp join(nil), do: ""

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?(_), do: false

  defp truncate(s, n \\ 80) do
    if String.length(s) > n, do: String.slice(s, 0..(n - 1)) <> "…", else: s
  end

  # =============================================================================
  # Frontend TS key extraction (kept for the flat locale-file shape)
  # =============================================================================
  defp extract_ts_keys(path) do
    path
    |> File.read!()
    |> extract_leaf_key_paths()
    |> MapSet.new()
  end

  defp extract_leaf_key_paths(content) do
    {keys, _stack} =
      content
      |> String.split("\n")
      |> Enum.reduce({[], []}, &classify_ts_line/2)

    Enum.reverse(keys)
  end

  defp classify_ts_line(line, {keys, stack}) do
    trimmed = String.trim(line)

    cond do
      Regex.match?(~r/^(\w+)\s*:\s*\{/, trimmed) ->
        [_, key] = Regex.run(~r/^(\w+)\s*:/, trimmed)
        {keys, stack ++ [key]}

      Regex.match?(~r/^(\w+)\s*:\s*['"]/, trimmed) ->
        {add_leaf_key(keys, stack, trimmed), stack}

      Regex.match?(~r/^(\w+)\s*:$/, trimmed) ->
        {add_leaf_key(keys, stack, trimmed), stack}

      trimmed == "}," or trimmed == "}" ->
        {keys, Enum.drop(stack, -1)}

      true ->
        {keys, stack}
    end
  end

  defp add_leaf_key(keys, stack, trimmed) do
    [_, key] = Regex.run(~r/^(\w+)\s*:/, trimmed)
    [Enum.join(stack ++ [key], ".") | keys]
  end
end
