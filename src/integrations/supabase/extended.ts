/**
 * Typed access to database objects added after the last types.ts generation.
 *
 * `types.ts` is generated from the database and is large enough that it is
 * regenerated deliberately rather than on every migration. Until the next
 * regeneration, the tables, views and functions below are described here
 * by hand so the rest of the codebase can use them with real types instead
 * of scattering `any` across call sites.
 *
 * When types.ts is next regenerated, delete this file and let the generated
 * types take over.
 */

import type { SupabaseClient } from "@supabase/supabase-js";

/* ───────────────────────── Rows ───────────────────────── */

export type StageSlaRow = {
  id: string;
  organization_id: string;
  stage_key: string;
  target_hours: number;
  created_at: string;
  created_by: string;
  updated_at: string;
  updated_by: string;
};

export const videoStates = ["not_applicable", "in_progress", "complete"] as const;
export type VideoState = (typeof videoStates)[number];

export type BookingVideoWorkRow = {
  id: string;
  organization_id: string;
  booking_id: string;
  round: number;
  state: VideoState;
  video_note: string | null;
  recorded_at: string;
  recorded_by: string;
  created_at: string;
  created_by: string;
};

export type BookingStageSlaStatusRow = {
  organization_id: string;
  booking_id: string;
  stage_key: string;
  stage_order: number;
  stage_entered_at: string;
  target_hours: number | null;
  hours_in_stage: number;
  due_at: string | null;
  is_breached: boolean;
};

/* ──────────────────────── Access ──────────────────────── */

type AnyClient = SupabaseClient<never>;

/** Read a table or view that the generated types do not know about yet. */
export function extendedFrom(client: unknown, relation: string) {
  return (client as AnyClient).from(relation as never);
}

/** Call an RPC that the generated types do not know about yet. */
export function extendedRpc(
  client: unknown,
  fn: string,
  args: Record<string, unknown>,
): Promise<{ data: unknown; error: { message: string } | null }> {
  return (client as AnyClient).rpc(fn as never, args as never) as unknown as Promise<{
    data: unknown;
    error: { message: string } | null;
  }>;
}
