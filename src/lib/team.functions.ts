import { createServerFn } from "@tanstack/react-start";
import type { Database } from "@/integrations/supabase/types";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { ORGANIZATION_ID } from "@/lib/session";

export type TeamMemberRow = {
  memberId: string;
  status: Database["public"]["Enums"]["member_status"];
  displayName: string | null;
  email: string | null;
  phone: string | null;
  joinedAt: string;
  roles: string[];
  roleLabels: string[];
  branchNames: string[];
  organizationWide: boolean;
};

export type TeamCapabilities = {
  canRead: boolean;
  canInvite: boolean;
  canAssignRoles: boolean;
  canSuspend: boolean;
};

export const getTeamCapabilities = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<TeamCapabilities> => {
    const { data, error } = await context.supabase.rpc("effective_permissions", {
      p_organization_id: ORGANIZATION_ID,
    });

    if (error) {
      throw new Error(error.message);
    }

    const permissions = new Set(data ?? []);

    return {
      canRead: permissions.has("team.read"),
      canInvite: permissions.has("team.invite"),
      canAssignRoles: permissions.has("team.role.assign"),
      canSuspend: permissions.has("team.suspend"),
    };
  });

export const listTeam = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<TeamMemberRow[]> => {
    const { data, error } = await context.supabase.rpc("team_access_directory", {
      p_organization_id: ORGANIZATION_ID,
    });

    if (error) {
      throw new Error(error.message);
    }

    return (data ?? []).map((row) => ({
      memberId: row.member_id,
      status: row.member_status,
      displayName: row.display_name ?? null,
      email: row.email ?? null,
      phone: row.phone ?? null,
      joinedAt: row.joined_at,
      roles: row.assigned_role_keys ?? [],
      roleLabels: row.assigned_role_labels ?? [],
      branchNames: row.assigned_branch_names ?? [],
      organizationWide: row.organization_wide,
    }));
  });
