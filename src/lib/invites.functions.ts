import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const roleEnum = z.enum([
  "founder",
  "coordinator",
  "sales",
  "photographer",
  "assistant",
  "stylist",
  "editor",
  "album",
  "marketing",
  "accounts",
]);

export type StudioInvite = {
  id: string;
  email: string;
  full_name: string | null;
  roles: string[];
  token: string;
  status: string;
  expires_at: string;
  created_at: string;
};

async function assertFounder(context: { supabase: any; userId: string }) {
  const { data: isFounder } = await context.supabase.rpc("has_role" as never, {
    _user_id: context.userId,
    _role: "founder",
  } as never);
  if (!isFounder) throw new Error("Only a Founder can manage studio invitations.");
}

export const listInvites = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<StudioInvite[]> => {
    await assertFounder(context as never);
    const { data, error } = await context.supabase
      .from("studio_invites" as never)
      .select("id, email, full_name, roles, token, status, expires_at, created_at")
      .order("created_at", { ascending: false });
    if (error) throw new Error(error.message);
    return (data ?? []) as unknown as StudioInvite[];
  });

export const createInvite = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        email: z.string().trim().email().max(255),
        fullName: z.string().trim().max(120).optional(),
        roles: z.array(roleEnum).min(1, "Choose at least one role."),
      })
      .parse(input),
  )
  .handler(async ({ data, context }): Promise<StudioInvite> => {
    await assertFounder(context as never);
    const email = data.email.toLowerCase();

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await supabaseAdmin
      .from("studio_invites" as never)
      .update({ status: "revoked" } as never)
      .eq("status", "pending")
      .ilike("email", email);

    const { data: row, error } = await supabaseAdmin
      .from("studio_invites" as never)
      .insert({
        email,
        full_name: data.fullName || null,
        roles: data.roles,
        invited_by: context.userId,
      } as never)
      .select("id, email, full_name, roles, token, status, expires_at, created_at")
      .single();
    if (error) throw new Error(error.message);
    return row as unknown as StudioInvite;
  });

export const revokeInvite = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => z.object({ id: z.string().uuid() }).parse(input))
  .handler(async ({ data, context }) => {
    await assertFounder(context as never);
    const { error } = await context.supabase
      .from("studio_invites" as never)
      .update({ status: "revoked" } as never)
      .eq("id", data.id);
    if (error) throw new Error(error.message);
    return { ok: true };
  });

export type InvitePreview = { email: string; fullName: string | null; roles: string[] };

/** Public, token-gated preview so an invited teammate can create their account. */
export const getInvite = createServerFn({ method: "GET" })
  .inputValidator((input) => z.object({ token: z.string().min(10).max(200) }).parse(input))
  .handler(async ({ data }): Promise<InvitePreview | null> => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: row } = await supabaseAdmin
      .from("studio_invites" as never)
      .select("email, full_name, roles, status, expires_at")
      .eq("token", data.token)
      .maybeSingle();
    const invite = row as unknown as
      | { email: string; full_name: string | null; roles: string[]; status: string; expires_at: string }
      | null;
    if (!invite) return null;
    if (invite.status !== "pending") return null;
    if (new Date(invite.expires_at).getTime() < Date.now()) return null;
    return { email: invite.email, fullName: invite.full_name, roles: invite.roles };
  });

/** Called right after the invited teammate signs in; grants the pre-assigned roles. */
export const acceptInvite = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => z.object({ token: z.string().min(10).max(200) }).parse(input))
  .handler(async ({ data, context }) => {
    const email = (context.claims as { email?: string } | undefined)?.email?.toLowerCase();
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

    const { data: row } = await supabaseAdmin
      .from("studio_invites" as never)
      .select("id, email, roles, status, expires_at")
      .eq("token", data.token)
      .maybeSingle();
    const invite = row as unknown as
      | { id: string; email: string; roles: string[]; status: string; expires_at: string }
      | null;

    if (!invite || invite.status !== "pending") throw new Error("This invitation is no longer valid.");
    if (new Date(invite.expires_at).getTime() < Date.now()) throw new Error("This invitation has expired.");
    if (!email || email !== invite.email.toLowerCase()) {
      throw new Error("This invitation was sent to a different email address.");
    }

    const { error: roleError } = await supabaseAdmin
      .from("user_roles" as never)
      .upsert(
        invite.roles.map((role) => ({ user_id: context.userId, role })) as never,
        { onConflict: "user_id,role" },
      );
    if (roleError) throw new Error(roleError.message);

    await supabaseAdmin
      .from("studio_invites" as never)
      .update({ status: "accepted", accepted_at: new Date().toISOString(), accepted_by: context.userId } as never)
      .eq("id", invite.id);

    return { ok: true, roles: invite.roles };
  });
