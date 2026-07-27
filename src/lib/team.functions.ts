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

export type TeamMemberRow = {
  id: string;
  full_name: string | null;
  email: string | null;
  roles: string[];
};

export const listTeam = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<TeamMemberRow[]> => {
    const [{ data: profiles }, { data: roles }] = await Promise.all([
      context.supabase.from("profiles" as never).select("id, full_name, email"),
      context.supabase.from("user_roles" as never).select("user_id, role"),
    ]);
    const byUser = new Map<string, string[]>();
    for (const r of (roles ?? []) as unknown as { user_id: string; role: string }[]) {
      byUser.set(r.user_id, [...(byUser.get(r.user_id) ?? []), r.role]);
    }
    return ((profiles ?? []) as unknown as Omit<TeamMemberRow, "roles">[]).map((p) => ({
      ...p,
      roles: byUser.get(p.id) ?? [],
    }));
  });

export const setTeamRole = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({ userId: z.string().uuid(), role: roleEnum, grant: z.boolean() })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { data: isFounder } = await context.supabase.rpc("has_role" as never, {
      _user_id: context.userId,
      _role: "founder",
    } as never);
    if (!isFounder) throw new Error("Only a Founder can change studio roles.");

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    if (data.grant) {
      const { error } = await supabaseAdmin
        .from("user_roles" as never)
        .upsert({ user_id: data.userId, role: data.role } as never, {
          onConflict: "user_id,role",
        });
      if (error) throw new Error(error.message);
    } else {
      const { error } = await supabaseAdmin
        .from("user_roles" as never)
        .delete()
        .eq("user_id", data.userId)
        .eq("role", data.role);
      if (error) throw new Error(error.message);
    }
    return { ok: true };
  });