/**
 * Single source of truth for app-wide TypeScript types shared across pages,
 * components, and layouts. Domain-specific types (auth, scheduling, …) live
 * here under clearly marked sections so future-you doesn't end up with the
 * same `Lesson` interface declared in three places.
 *
 * Module-augmentation for third-party libraries (e.g. `@inertiajs/core`)
 * stays in `types/*.d.ts` files but imports its concrete types from here.
 */

// =============================================================================
// Auth / session
// =============================================================================
export interface CurrentUser {
  id: string;
  email: string;
  name: string | null;
  locale: string;
}

export interface Flash {
  info?: string;
  error?: string;
}

export interface CurrentMembership {
  role: 'owner' | 'admin' | 'teacher' | 'student' | 'member';
  tenant: { id: string; name: string };
}

// =============================================================================
// Scheduling — lessons & participants
// =============================================================================
export interface LessonParticipant {
  id: string;
  name: string | null;
}

export type LessonKind = 'scheduled' | 'drop_in';

export interface Lesson {
  id: string;
  starts_at: string;
  duration_minutes: number;
  status: 'scheduled' | 'cancelled' | 'completed' | 'no_show';
  /** `scheduled` lessons are booked ahead of time. `drop_in` lessons are
   * started by a teacher right now and joined via a shared link by any
   * tenant member. */
  kind: LessonKind;
  language: string | null;
  language_name: string | null;
  notes: string | null;
  viewer_role: 'teacher' | 'student';
  teacher: { id: string; name: string | null };
  participants: LessonParticipant[];
}

export type MembershipRole = CurrentMembership['role'];

// =============================================================================
// App-wide runtime config — single source of truth lives on the server in
// `WebTemplateWeb.Plugs.SharedData.app_config/0`. Every page receives this
// prop; component code reads from `usePage().props.app_config` rather than
// hard-coding any of these numbers.
// =============================================================================
export interface AppConfig {
  /** Live-classroom join window expressed as seconds before/after the
   * lesson's scheduled start/end. Mirrors `WebTemplate.Classroom`. */
  join_window_seconds: {
    pre: number;
    post: number;
  };
}
