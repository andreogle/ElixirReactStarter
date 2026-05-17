/**
 * Common date/time/timezone helpers.
 *
 * Conventions used across the app:
 *  - The server sends dates as ISO `YYYY-MM-DD`, times as ISO `HH:MM:SS`,
 *    and datetimes as UTC ISO-8601 strings.
 *  - The user's canonical timezone lives on `current_user.timezone` and is
 *    shared via Inertia props — don't read `Intl.DateTimeFormat().resolvedOptions()`
 *    to infer it; read the prop. `browserTimezone()` is only for detecting
 *    a sensible default during onboarding.
 *  - All formatting is locale-aware via `Intl` — never hand-roll strings.
 */

// -----------------------------------------------------------------------------
// Time strings
// -----------------------------------------------------------------------------

/**
 * Trim a server-formatted time string to `HH:MM`.
 *
 *     trimSeconds("09:00:00") // "09:00"
 *     trimSeconds("09:00")    // "09:00"
 */
export function trimSeconds(time: string): string {
  return time.slice(0, 5);
}

/**
 * Format a start/end pair (each `HH:MM` or `HH:MM:SS`) as `HH:MM – HH:MM`.
 * Uses an en-dash surrounded by hair spaces for visual balance.
 */
export function formatTimeRange(start: string, end: string): string {
  return `${trimSeconds(start)} – ${trimSeconds(end)}`;
}

// -----------------------------------------------------------------------------
// Dates
// -----------------------------------------------------------------------------

/**
 * Parse an ISO date (`YYYY-MM-DD`) into a local `Date` at midnight.
 *
 * `new Date("2026-05-01")` is interpreted as UTC midnight by the spec, so
 * in negative-offset timezones it reads as the previous day — this helper
 * avoids that trap by constructing the date explicitly in local time.
 */
export function parseLocalDate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/**
 * Format an ISO date (`YYYY-MM-DD`) using the browser's locale.
 * Defaults to `{ weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' }`.
 */
export function formatDate(
  iso: string,
  options: Intl.DateTimeFormatOptions = {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  },
  locale?: string
): string {
  return parseLocalDate(iso).toLocaleDateString(locale, options);
}

/**
 * Format a UTC ISO-8601 datetime string (e.g. `2026-05-01T13:30:00Z`) in the
 * target timezone. Pass the user's timezone from Inertia props, not a
 * locally-detected value, so users see the zone they actually chose.
 */
export function formatDateTime(
  iso: string,
  timezone: string,
  options: Intl.DateTimeFormatOptions = {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  },
  locale?: string
): string {
  return new Date(iso).toLocaleString(locale, { ...options, timeZone: timezone });
}

/**
 * Short-form datetime for list rows — `Tue, Feb 3, 14:30`. Thin wrapper
 * around `formatDateTime` so list pages don't repeat the options map.
 */
export function formatShortDateTime(iso: string, timezone: string, locale?: string): string {
  return formatDateTime(iso, timezone, undefined, locale);
}

/**
 * Long-form datetime for confirmation UIs — `Tuesday, February 3, 14:30`.
 */
export function formatLongDateTime(iso: string, timezone: string, locale?: string): string {
  return formatDateTime(
    iso,
    timezone,
    {
      weekday: 'long',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    },
    locale
  );
}

/**
 * Time-only formatting in the viewer's timezone — `14:30`. Useful for
 * compact slot pickers where the date is provided by a surrounding heading.
 */
export function formatTimeInZone(iso: string, timezone: string, locale?: string): string {
  return new Date(iso).toLocaleTimeString(locale, {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: timezone,
  });
}

/**
 * Long weekday + month + day from a plain ISO date (`YYYY-MM-DD`) — e.g.
 * `Monday, February 3`. Used for day headings over lists of same-day
 * items.
 */
export function formatWeekdayDate(isoDate: string, locale?: string): string {
  return formatDate(
    isoDate,
    {
      weekday: 'long',
      month: 'long',
      day: 'numeric',
    },
    locale
  );
}

// -----------------------------------------------------------------------------
// Timezone
// -----------------------------------------------------------------------------

/**
 * The browser's IANA timezone (e.g. "Europe/London"), for onboarding
 * defaults only. Prefer `current_user.timezone` from Inertia props for
 * all display.
 */
export function browserTimezone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
}
