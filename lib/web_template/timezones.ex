defmodule WebTemplate.Timezones do
  @moduledoc """
  Single source of truth for the timezones offered on WebTemplate.

  Delegates to the `tzdata` package's full zone list (including linked
  aliases) so users can search for any place in the IANA database —
  `America/Cayman`, `America/Montreal`, `Africa/Accra` and their
  canonical counterparts all appear.

  What we exclude:

    * `Etc/GMT+N` / `Etc/GMT-N` meta-zones — sign is historically
      inverted (`Etc/GMT+5` is actually UTC-5) and they duplicate real
      zones.
    * Zones without a `Region/City` structure — three-letter country
      aliases (`EST`, `GMT`, `Cuba`, `Japan`) that would pollute search.

  What we add back manually:

    * `UTC` — so users can explicitly opt into UTC without knowing its
      IANA canonical form (`Etc/UTC`).

  The list is computed at call time rather than at compile time because
  tzdata's ETS store isn't available until the app has booted. The
  lookup is O(n) (n ≈ 550) and cheap enough that caching wouldn't earn
  its keep.
  """

  @extra_codes ["UTC"]

  @doc """
  Returns the supported IANA timezone identifiers, sorted alphabetically.

      iex> "UTC" in WebTemplate.Timezones.codes()
      true

      iex> "America/New_York" in WebTemplate.Timezones.codes()
      true

      iex> "America/Cayman" in WebTemplate.Timezones.codes()
      true

      iex> "Etc/GMT+5" in WebTemplate.Timezones.codes()
      false

  """
  def codes do
    Tzdata.zone_list()
    |> Enum.filter(fn code ->
      String.contains?(code, "/") and not String.starts_with?(code, "Etc/")
    end)
    |> Kernel.++(@extra_codes)
    |> Enum.sort()
  end

  @doc """
  Returns `true` when `tz` is one of the supported codes.

      iex> WebTemplate.Timezones.valid?("Europe/London")
      true

      iex> WebTemplate.Timezones.valid?("Mars/Olympus_Mons")
      false

      iex> WebTemplate.Timezones.valid?(nil)
      false

  """
  def valid?(tz) when is_binary(tz), do: tz in codes()
  def valid?(_), do: false

  @doc """
  Returns every timezone as `{code, display_label}` tuples in the same
  alphabetical order as `codes/0`. The label is the IANA identifier with
  underscores replaced by spaces, followed by the zone's current UTC
  offset.

  The offset is computed against the moment of the call, so it reflects
  whether the zone is currently in DST or on its standard offset. For a
  static picker this is accurate; callers can invalidate any caching on
  a twice-yearly basis if it matters.

      iex> WebTemplate.Timezones.list() |> List.keyfind("UTC", 0)
      {"UTC", "UTC (UTC+0)"}

      iex> match?({"Asia/Kolkata", "Asia/Kolkata (UTC+5:30)"},
      ...>        List.keyfind(WebTemplate.Timezones.list(), "Asia/Kolkata", 0))
      true

  """
  def list do
    Enum.map(codes(), fn code ->
      {code, "#{format_display(code)} (#{format_offset(current_offset_minutes(code))})"}
    end)
  end

  @doc """
  Returns the zone's current UTC offset in minutes, or `nil` when the
  code is unknown. Includes DST adjustment if the zone is currently
  observing it.

      iex> WebTemplate.Timezones.offset_minutes("UTC")
      0

      iex> WebTemplate.Timezones.offset_minutes("Asia/Kolkata")
      330

      iex> WebTemplate.Timezones.offset_minutes("Mars/Olympus_Mons")
      nil

  """
  def offset_minutes(code) when is_binary(code) do
    if valid?(code), do: current_offset_minutes(code), else: nil
  end

  def offset_minutes(_), do: nil

  defp current_offset_minutes(code) do
    case DateTime.now(code) do
      {:ok, dt} -> div(dt.utc_offset + dt.std_offset, 60)
      _ -> 0
    end
  end

  defp format_display(tz), do: String.replace(tz, "_", " ")

  defp format_offset(minutes) do
    sign = if minutes < 0, do: "-", else: "+"
    abs_minutes = abs(minutes)
    hours = div(abs_minutes, 60)
    mins = rem(abs_minutes, 60)

    if mins == 0 do
      "UTC#{sign}#{hours}"
    else
      "UTC#{sign}#{hours}:#{String.pad_leading(Integer.to_string(mins), 2, "0")}"
    end
  end
end
