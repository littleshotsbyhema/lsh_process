import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { appRoles, ORGANIZATION_ID, type AppRole } from "@/lib/session";

const inviteRoleEnum = z.enum(appRoles);

const invitationTokenSchema = z
  .string()
  .trim()
  .regex(/^[0-9a-f]{64}$/i, "Invalid invitation token.");

export type StudioInvite = {
  id: string;
  email: string;
  fullName: string | null;
  roles: string[];
  roleLabels: string[];
  status: string;
  expiresAt: string;
  createdAt: string;
};

export type CreatedStudioInvite = {
  email: string;
  fullName: string | null;
  roles: AppRole[];
  expiresAt: string;
  token: string;
};

export type InvitePreview = {
  email: string;
  fullName: string | null;
  organizationName: string;
  roles: string[];
  roleLabels: string[];
  expiresAt: string;
};

export const listInvites = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<StudioInvite[]> => {
    const { data, error } = await context.supabase.rpc("team_invitation_directory", {
      p_organization_id: ORGANIZATION_ID,
    });

    if (error) {
      throw new Error(error.message);
    }

    return (data ?? []).map((row) => ({
      id: row.invitation_id,
      email: row.email,
      fullName: row.full_name ?? null,
      roles: row.role_keys ?? [],
      roleLabels: row.role_labels ?? [],
      status: row.invitation_status,
      expiresAt: row.expires_at,
      createdAt: row.created_at,
    }));
  });

export const createInvite = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        email: z.string().trim().email().max(255),
        fullName: z.string().trim().max(160).optional(),
        roles: z.array(inviteRoleEnum).default([]),
      })
      .parse(input),
  )
  .handler(async ({ data, context }): Promise<CreatedStudioInvite> => {
    const { data: rows, error } = await context.supabase.rpc("create_organization_invitation", {
      p_organization_id: ORGANIZATION_ID,
      p_email: data.email.toLowerCase(),
      p_full_name: data.fullName || undefined,
      p_role_keys: data.roles,
    });

    if (error) {
      throw new Error(error.message);
    }

    const invitation = rows?.[0];

    if (!invitation) {
      throw new Error("The invitation could not be created.");
    }

    return {
      email: invitation.email,
      fullName: invitation.full_name ?? null,
      roles: (invitation.role_keys ?? []) as AppRole[],
      expiresAt: invitation.expires_at,
      token: invitation.invite_token,
    };
  });

export const revokeInvite = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        id: z.string().uuid(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { data: revoked, error } = await context.supabase.rpc("revoke_organization_invitation", {
      p_organization_id: ORGANIZATION_ID,
      p_invitation_id: data.id,
      p_reason: "Invitation revoked from Team",
    });

    if (error) {
      throw new Error(error.message);
    }

    return { ok: Boolean(revoked) };
  });

/**
 * Public bearer-token preview.
 *
 * This intentionally uses the publishable-key client without a service-role
 * bypass. The canonical preview RPC owns the safe public projection.
 */
export const getInvite = createServerFn({ method: "GET" })
  .inputValidator((input) =>
    z
      .object({
        token: invitationTokenSchema,
      })
      .parse(input),
  )
  .handler(async ({ data }): Promise<InvitePreview | null> => {
    const { supabase } = await import("@/integrations/supabase/client");

    const { data: rows, error } = await supabase.rpc("preview_organization_invitation", {
      p_token: data.token,
    });

    if (error) {
      throw new Error(error.message);
    }

    const invitation = rows?.[0];

    if (!invitation) {
      return null;
    }

    return {
      email: invitation.email,
      fullName: invitation.full_name ?? null,
      organizationName: invitation.organization_name,
      roles: invitation.role_keys ?? [],
      roleLabels: invitation.role_labels ?? [],
      expiresAt: invitation.expires_at,
    };
  });

export const acceptInvite = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        token: invitationTokenSchema,
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { data: rows, error } = await context.supabase.rpc("accept_organization_invitation", {
      p_token: data.token,
    });

    if (error) {
      throw new Error(error.message);
    }

    const accepted = rows?.[0];

    if (!accepted) {
      throw new Error("The invitation could not be accepted.");
    }

    return {
      ok: true,
      memberId: accepted.member_id,
      roles: accepted.assigned_role_keys ?? [],
    };
  });
