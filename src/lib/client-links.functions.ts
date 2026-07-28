import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

type Json = string | number | boolean | null | Json[] | { [key: string]: Json };

export type ClientLinkView = {
  token: string;
  kind: "proposal" | "consent" | "delivery";
  payload: Record<string, Json>;
  expired: boolean;
  responded: boolean;
};

/** Public: read one share link by its secret token. No studio data beyond this link. */
export const getClientLink = createServerFn({ method: "GET" })
  .inputValidator((input) => z.object({ token: z.string().min(8).max(80) }).parse(input))
  .handler(async ({ data }): Promise<ClientLinkView | null> => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: link } = await supabaseAdmin
      .from("client_links" as never)
      .select("token, kind, payload, expires_at")
      .eq("token", data.token)
      .maybeSingle();
    if (!link) return null;
    const row = link as unknown as {
      token: string;
      kind: ClientLinkView["kind"];
      payload: Record<string, Json>;
      expires_at: string | null;
    };
    const { count } = await supabaseAdmin
      .from("client_submissions" as never)
      .select("id", { count: "exact", head: true })
      .eq("token", data.token);
    return {
      token: row.token,
      kind: row.kind,
      payload: row.payload ?? {},
      expired: !!row.expires_at && new Date(row.expires_at) < new Date(),
      responded: (count ?? 0) > 0,
    };
  });

/** Public: a family sends their response back to the studio. */
export const submitClientResponse = createServerFn({ method: "POST" })
  .inputValidator((input) =>
    z
      .object({
        token: z.string().min(8).max(80),
        payload: z.record(z.union([z.string().max(4000), z.boolean(), z.number()])),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: link } = await supabaseAdmin
      .from("client_links" as never)
      .select("token, kind, expires_at, booking_id")
      .eq("token", data.token)
      .maybeSingle();
    if (!link) throw new Error("This link is no longer available.");
    const row = link as unknown as {
      kind: string;
      expires_at: string | null;
      booking_id: string | null;
    };
    if (row.expires_at && new Date(row.expires_at) < new Date()) {
      throw new Error("This link has expired. Please ask the studio for a fresh one.");
    }
    const { error } = await supabaseAdmin.from("client_submissions" as never).insert({
      token: data.token,
      kind: row.kind,
      payload: data.payload,
    } as never);
    if (error) throw new Error(error.message);

    // Fold the family's answer straight back into the studio records.
    try {
      const { applyClientResponse } = await import("@/lib/client-links.server");
      await applyClientResponse({
        kind: row.kind,
        bookingId: row.booking_id,
        payload: data.payload,
      });
    } catch (effectError) {
      console.error("[client-links] could not apply response", effectError);
    }
    return { ok: true };
  });

/** Staff: create a share link for a booking. */
export const createClientLink = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        kind: z.enum(["proposal", "consent", "delivery"]),
        bookingId: z.string().max(60).optional(),
        leadId: z.string().max(60).optional(),
        payload: z.record(z.any()).default({}),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const token = crypto.randomUUID().replace(/-/g, "");
    const { error } = await context.supabase.from("client_links" as never).insert({
      token,
      kind: data.kind,
      booking_id: data.bookingId ?? null,
      lead_id: data.leadId ?? null,
      payload: data.payload,
      expires_at: new Date(Date.now() + 1000 * 60 * 60 * 24 * 45).toISOString(),
    } as never);
    if (error) throw new Error(error.message);
    return { token };
  });

/** Staff: read every family response for a booking. */
export const listClientResponses = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => z.object({ bookingId: z.string().max(60) }).parse(input))
  .handler(async ({ data, context }) => {
    const { data: links } = await context.supabase
      .from("client_links" as never)
      .select("token, kind, created_at, expires_at")
      .eq("booking_id", data.bookingId);
    const tokens = ((links ?? []) as unknown as { token: string }[]).map((l) => l.token);
    if (!tokens.length) return { links: [], responses: [] };
    const { data: responses } = await context.supabase
      .from("client_submissions" as never)
      .select("token, kind, payload, created_at")
      .in("token", tokens);
    return { links: links ?? [], responses: responses ?? [] };
  });
