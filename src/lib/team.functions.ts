import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
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
  actorMemberId: string | null;
};

export type TeamRoleOption = {
  key: string;
  label: string;
  description: string | null;
  sortOrder: number;
};

export type TeamRoleGrantRow = {
  grantId: string;
  memberId: string;
  roleKey: string;
  roleLabel: string;
  branchId: string | null;
  branchName: string | null;
  branchCode: string | null;
  organizationWide: boolean;
  grantedAt: string;
  grantedByMemberId: string | null;
};

export type TeamRoleScopeRow = {
  branchId: string | null;
  branchName: string;
  branchCode: string | null;
  organizationWide: boolean;
};

export type TeamRoleAdministration = {
  roles: TeamRoleOption[];
  grants: TeamRoleGrantRow[];
  scopes: TeamRoleScopeRow[];
};

const roleKeySchema = z
  .string()
  .trim()
  .regex(/^[a-z][a-z0-9_]*$/, "Invalid role key.");

const roleMutationSchema = z.object({
  memberId: z.string().uuid(),
  roleKey: roleKeySchema,
  branchId: z.string().uuid().nullable(),
});

function isMissingLiveScopePermissionRpc(
  error: {
    code?: string;
    message: string;
  } | null,
): boolean {
  if (!error) return false;

  return (
    error.code === "PGRST202" ||
    (error.message.includes("Could not find the function") &&
      error.message.includes("has_permission_in_any_live_scope"))
  );
}

export const getTeamCapabilities = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<TeamCapabilities> => {
    const [readResult, inviteResult, assignResult, suspendResult, memberResult] = await Promise.all(
      [
        context.supabase.rpc("has_permission_in_any_live_scope", {
          p_organization_id: ORGANIZATION_ID,
          p_permission_key: "team.read",
        }),
        context.supabase.rpc("has_permission_in_any_live_scope", {
          p_organization_id: ORGANIZATION_ID,
          p_permission_key: "team.invite",
        }),
        context.supabase.rpc("has_permission_in_any_live_scope", {
          p_organization_id: ORGANIZATION_ID,
          p_permission_key: "team.role.assign",
        }),
        context.supabase.rpc("has_permission_in_any_live_scope", {
          p_organization_id: ORGANIZATION_ID,
          p_permission_key: "team.suspend",
        }),
        context.supabase.rpc("current_organization_member", {
          p_organization_id: ORGANIZATION_ID,
        }),
      ],
    );

    if (memberResult.error) {
      throw new Error(memberResult.error.message);
    }

    const liveScopeResults = [readResult, inviteResult, assignResult, suspendResult];

    const liveScopePermissionRpcUnavailable = liveScopeResults.every((result) =>
      isMissingLiveScopePermissionRpc(result.error),
    );

    if (liveScopePermissionRpcUnavailable) {
      const permissionResult = await context.supabase.rpc("effective_permissions", {
        p_organization_id: ORGANIZATION_ID,
      });

      if (permissionResult.error) {
        throw new Error(permissionResult.error.message);
      }

      const permissions = new Set(permissionResult.data ?? []);

      return {
        canRead: permissions.has("team.read"),
        canInvite: permissions.has("team.invite"),
        canAssignRoles: permissions.has("team.role.assign"),
        canSuspend: permissions.has("team.suspend"),
        actorMemberId: memberResult.data ?? null,
      };
    }

    for (const result of liveScopeResults) {
      if (result.error) {
        throw new Error(result.error.message);
      }
    }

    return {
      canRead: readResult.data === true,
      canInvite: inviteResult.data === true,
      canAssignRoles: assignResult.data === true,
      canSuspend: suspendResult.data === true,
      actorMemberId: memberResult.data ?? null,
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

export const getTeamRoleAdministration = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<TeamRoleAdministration> => {
    const [roleResult, grantResult, scopeResult] = await Promise.all([
      context.supabase.rpc("role_catalogue"),
      context.supabase.rpc("team_role_grant_directory", {
        p_organization_id: ORGANIZATION_ID,
      }),
      context.supabase.rpc("team_role_scope_catalogue", {
        p_organization_id: ORGANIZATION_ID,
      }),
    ]);

    if (roleResult.error) {
      throw new Error(roleResult.error.message);
    }

    if (grantResult.error) {
      throw new Error(grantResult.error.message);
    }

    if (scopeResult.error) {
      throw new Error(scopeResult.error.message);
    }

    return {
      roles: (roleResult.data ?? []).map((row) => ({
        key: row.key,
        label: row.label,
        description: row.description ?? null,
        sortOrder: row.sort_order,
      })),
      grants: (grantResult.data ?? []).map((row) => ({
        grantId: row.grant_id,
        memberId: row.member_id,
        roleKey: row.role_key,
        roleLabel: row.role_label,
        branchId: row.branch_id ?? null,
        branchName: row.branch_name ?? null,
        branchCode: row.branch_code ?? null,
        organizationWide: row.organization_wide,
        grantedAt: row.granted_at,
        grantedByMemberId: row.granted_by_member_id ?? null,
      })),
      scopes: (scopeResult.data ?? []).map((row) => ({
        branchId: row.branch_id ?? null,
        branchName: row.branch_name ?? (row.organization_wide ? "Organization-wide" : "Branch"),
        branchCode: row.branch_code ?? null,
        organizationWide: row.organization_wide,
      })),
    };
  });

export const grantTeamRole = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator(roleMutationSchema)
  .handler(async ({ data, context }): Promise<string> => {
    const args: Database["public"]["Functions"]["grant_organization_member_role"]["Args"] = {
      p_organization_id: ORGANIZATION_ID,
      p_member_id: data.memberId,
      p_role_key: data.roleKey,
    };

    if (data.branchId) {
      args.p_branch_id = data.branchId;
    }

    const { data: grantId, error } = await context.supabase.rpc(
      "grant_organization_member_role",
      args,
    );

    if (error) {
      throw new Error(error.message);
    }

    return grantId;
  });

export const revokeTeamRole = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator(roleMutationSchema)
  .handler(async ({ data, context }): Promise<{ ok: true }> => {
    const args: Database["public"]["Functions"]["revoke_organization_member_role"]["Args"] = {
      p_organization_id: ORGANIZATION_ID,
      p_member_id: data.memberId,
      p_role_key: data.roleKey,
      p_reason: "Role removed from Team role administration",
    };

    if (data.branchId) {
      args.p_branch_id = data.branchId;
    }

    const { data: revoked, error } = await context.supabase.rpc(
      "revoke_organization_member_role",
      args,
    );

    if (error) {
      throw new Error(error.message);
    }

    if (!revoked) {
      throw new Error("This role grant is no longer active.");
    }

    return { ok: true };
  });
