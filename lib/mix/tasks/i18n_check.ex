defmodule Mix.Tasks.I18n.Check do
  @shortdoc "Checks i18n coverage and sync between backend and frontend"
  @moduledoc """
  Validates that:

  1. All backend Gettext strings have translations in every locale
  2. All frontend locale files have the same set of keys
  3. No hardcoded user-facing strings in controllers, plugs, or email modules

      mix i18n.check
  """

  use Mix.Task

  @locales ["en", "es"]
  @gettext_domains ["app", "errors"]

  @backend_scan_paths [
    "lib/web_template_web/controllers/**/*.ex",
    "lib/web_template_web/plugs/**/*.ex",
    "lib/web_template_web/email.ex"
  ]

  @hardcoded_patterns [
    {~r/put_flash\(:(info|error),\s*"[^"]+"\)/, "put_flash with hardcoded string (use dgettext)"},
    {~r/\|>\s*subject\("[^"]+"\)/, "email subject with hardcoded string (use dgettext)"}
  ]

  @impl true
  def run(_args) do
    errors =
      check_gettext_coverage() ++
        check_frontend_locale_parity() ++
        check_hardcoded_strings()

    if errors == [] do
      Mix.shell().info("i18n check passed: all translations present, no hardcoded strings found.")
    else
      Mix.shell().error("i18n check failed:\n")
      Enum.each(errors, &Mix.shell().error("  - #{&1}"))
      Mix.raise("i18n check failed with #{length(errors)} issue(s)")
    end
  end

  # =============================================================================
  # Check 1: Gettext coverage (non-English locales only)
  # =============================================================================
  defp check_gettext_coverage do
    gettext_dir = Path.join(File.cwd!(), "priv/gettext")

    for domain <- @gettext_domains,
        pot_path = Path.join(gettext_dir, "#{domain}.pot"),
        File.exists?(pot_path),
        locale <- @locales -- ["en"],
        error <- check_locale_coverage(gettext_dir, domain, locale, pot_path) do
      error
    end
  end

  defp check_locale_coverage(gettext_dir, domain, locale, pot_path) do
    po_path = Path.join([gettext_dir, locale, "LC_MESSAGES", "#{domain}.po"])

    if File.exists?(po_path) do
      pot_msgids = extract_msgids(pot_path)
      po_translations = extract_translations(po_path)

      for msgid <- pot_msgids,
          Map.get(po_translations, msgid, "") == "" do
        "[#{locale}/#{domain}] Missing translation for: \"#{msgid}\""
      end
    else
      ["[#{locale}/#{domain}] Missing .po file: #{po_path}"]
    end
  end

  # =============================================================================
  # Check 2: Frontend locale parity
  # =============================================================================
  defp check_frontend_locale_parity do
    locales_dir = Path.join(File.cwd!(), "assets/js/i18n/locales")
    locale_keys = load_frontend_locale_keys(locales_dir)

    case Map.get(locale_keys, "en") do
      nil -> ["[frontend] Missing locale file: en.ts"]
      en_keys -> compare_frontend_locales(locale_keys, en_keys)
    end
  end

  defp load_frontend_locale_keys(locales_dir) do
    Map.new(@locales, fn locale ->
      path = Path.join(locales_dir, "#{locale}.ts")
      {locale, if(File.exists?(path), do: extract_ts_keys(path))}
    end)
  end

  defp compare_frontend_locales(locale_keys, en_keys) do
    for locale <- @locales -- ["en"],
        error <- compare_locale_to_en(locale, Map.get(locale_keys, locale), en_keys) do
      error
    end
  end

  defp compare_locale_to_en(locale, nil, _en_keys) do
    ["[frontend] Missing locale file: #{locale}.ts"]
  end

  defp compare_locale_to_en(locale, other_keys, en_keys) do
    missing_in_other = MapSet.difference(en_keys, other_keys)
    missing_in_en = MapSet.difference(other_keys, en_keys)

    Enum.map(missing_in_other, &"[frontend/#{locale}] Missing key: #{&1}") ++
      Enum.map(missing_in_en, &"[frontend/en] Missing key: #{&1} (present in #{locale})")
  end

  # =============================================================================
  # Check 3: Hardcoded strings
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
  # Gettext PO/POT parsing
  # =============================================================================
  defp extract_msgids(pot_path) do
    lines = pot_path |> File.read!() |> String.split("\n")

    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _i} -> String.starts_with?(line, "msgid \"") end)
    |> Enum.reject(fn {_line, i} -> plural_entry?(lines, i) end)
    |> Enum.map(fn {line, _i} -> extract_quoted_string(line) end)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_translations(po_path) do
    lines = po_path |> File.read!() |> String.split("\n")

    lines
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {line, i}, acc ->
      if String.starts_with?(line, "msgid \"") do
        parse_msgid_entry(lines, line, i, acc)
      else
        acc
      end
    end)
  end

  defp parse_msgid_entry(lines, line, i, acc) do
    next = Enum.at(lines, i + 1, "")

    cond do
      plural_entry?(lines, i) -> acc
      String.starts_with?(next, "msgstr \"") -> put_translation(acc, line, next)
      true -> acc
    end
  end

  defp plural_entry?(lines, i) do
    next = Enum.at(lines, i + 1, "")
    String.starts_with?(next, "msgid_plural")
  end

  defp put_translation(acc, msgid_line, msgstr_line) do
    msgid = extract_quoted_string(msgid_line)
    msgstr = extract_quoted_string(msgstr_line)
    if msgid != "", do: Map.put(acc, msgid, msgstr), else: acc
  end

  defp extract_quoted_string(line) do
    case Regex.run(~r/"(.*)"/, line) do
      [_, content] -> content
      _ -> ""
    end
  end

  # =============================================================================
  # Frontend TS key extraction
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
