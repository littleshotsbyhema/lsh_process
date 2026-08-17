import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import { toast } from "sonner";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  getTeamCapabilities,
  getTeamRoleAdministration,
  grantTeamRole,
  listTeam,
  revokeTeamRole,
  type TeamRoleGrantRow,
  type TeamRoleScopeRow,
} from "@/lib/team.functions";
import { createInvite, listInvites, revokeInvite } from "@/lib/invites.functions";
import { appRoles, roleLabels, type AppRole } from "@/lib/session";

const ORGANIZATION_WIDE_SCOPE = "__organization_wide__";

export const Route = createFileRoute("/_authenticated/team")({
  head: () => ({
    meta: [
      { title: "Team · Little Moments OS" },
      {
        name: "description",
        content: "Canonical studio membership, access roles, and private invitations.",
      },
      { property: "og:title", content: "Team · Little Moments OS" },
      {
        property: "og:description",
        content: "Every role exists to protect a memory.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: TeamPage,
});

function displayRoleLabels(keys: string[], labels: string[]) {
  if (labels.length === keys.length && labels.length > 0) {
    return labels;
  }

  return keys.map((key) => roleLabels[key as AppRole] ?? key);
}

function scopeValue(scope: TeamRoleScopeRow) {
  return scope.organizationWide ? ORGANIZATION_WIDE_SCOPE : (scope.branchId ?? "");
}

function grantScopeLabel(grant: TeamRoleGrantRow) {
  if (grant.organizationWide || !grant.branchId) {
    return "Organization-wide";
  }

  if (grant.branchName) {
    return grant.branchCode ? `${grant.branchName} (${grant.branchCode})` : grant.branchName;
  }

  if (grant.branchCode) {
    return grant.branchCode;
  }

  return `Branch ${grant.branchId.slice(0, 8)}`;
}

function TeamPage() {
  const fetchCapabilities = useServerFn(getTeamCapabilities);
  const fetchTeam = useServerFn(listTeam);
  const fetchRoleAdministration = useServerFn(getTeamRoleAdministration);
  const assignRole = useServerFn(grantTeamRole);
  const removeRole = useServerFn(revokeTeamRole);
  const fetchInvites = useServerFn(listInvites);
  const sendInvite = useServerFn(createInvite);
  const cancelInvite = useServerFn(revokeInvite);
  const queryClient = useQueryClient();

  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteName, setInviteName] = useState("");
  const [inviteRoles, setInviteRoles] = useState<AppRole[]>([]);
  const [roleSelections, setRoleSelections] = useState<Record<string, string>>({});
  const [scopeSelections, setScopeSelections] = useState<Record<string, string>>({});

  const capabilities = useQuery({
    queryKey: ["team-capabilities"],
    queryFn: () => fetchCapabilities(),
  });

  const canRead = capabilities.data?.canRead === true;
  const canInvite = capabilities.data?.canInvite === true;
  const canAssignRoles = capabilities.data?.canAssignRoles === true;

  const members = useQuery({
    queryKey: ["team"],
    enabled: canRead,
    queryFn: () => fetchTeam(),
  });

  const roleAdministration = useQuery({
    queryKey: ["team-role-admin"],
    enabled: canRead && canAssignRoles,
    queryFn: () => fetchRoleAdministration(),
  });

  const invites = useQuery({
    queryKey: ["invites"],
    enabled: canInvite,
    queryFn: () => fetchInvites(),
  });

  const refreshRoleState = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ["team-role-admin"] }),
      queryClient.invalidateQueries({ queryKey: ["team"] }),
      queryClient.invalidateQueries({ queryKey: ["team-capabilities"] }),
    ]);
  };

  const grantMutation = useMutation({
    mutationFn: (vars: { memberId: string; roleKey: string; branchId: string | null }) =>
      assignRole({ data: vars }),
    onSuccess: async (_grantId, vars) => {
      toast.success("Role assigned.");
      await refreshRoleState();

      if (vars.memberId === capabilities.data?.actorMemberId) {
        window.location.reload();
      }
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not assign the role."),
  });

  const roleRevokeMutation = useMutation({
    mutationFn: (vars: { memberId: string; roleKey: string; branchId: string | null }) =>
      removeRole({ data: vars }),
    onSuccess: async (_result, vars) => {
      toast.success("Role removed.");
      await refreshRoleState();

      if (vars.memberId === capabilities.data?.actorMemberId) {
        window.location.reload();
      }
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not remove the role."),
  });

  const inviteMutation = useMutation({
    mutationFn: (vars: { email: string; fullName?: string; roles: AppRole[] }) =>
      sendInvite({ data: vars }),
    onSuccess: async (invite) => {
      const url = `${window.location.origin}/auth?invite=${invite.token}`;
      let copied = false;

      try {
        if (navigator.clipboard) {
          await navigator.clipboard.writeText(url);
          copied = true;
        }
      } catch {
        copied = false;
      }

      if (!copied) {
        window.prompt(
          "Copy this invitation link now. For security, it will not appear in invitation history.",
          url,
        );
      }

      toast.success(
        copied
          ? "Invitation created — the one-time link was copied."
          : "Invitation created — copy the one-time link before closing the prompt.",
      );

      setInviteEmail("");
      setInviteName("");
      setInviteRoles([]);

      await queryClient.invalidateQueries({ queryKey: ["invites"] });
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not create the invitation."),
  });

  const revokeMutation = useMutation({
    mutationFn: async (id: string) => {
      const result = await cancelInvite({ data: { id } });

      if (!result.ok) {
        throw new Error("This invitation is no longer pending.");
      }

      return result;
    },
    onSuccess: async () => {
      toast.success("Invitation revoked.");
      await queryClient.invalidateQueries({ queryKey: ["invites"] });
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not revoke the invitation."),
  });

  return (
    <AppShell>
      <PageHeader
        eyebrow="The Studio"
        title="Team"
        subtitle="Canonical membership and invitation access."
        quote="We are a small team because care does not scale carelessly."
      />

      {capabilities.isLoading ? (
        <Card className="p-6 mb-8">
          <p className="text-sm italic text-muted-foreground">Checking Team access…</p>
        </Card>
      ) : capabilities.isError ? (
        <Card className="p-6 mb-8">
          <p className="text-sm text-muted-foreground">
            Team access could not be resolved from your current membership.
          </p>
        </Card>
      ) : !canRead ? (
        <Card className="p-6 mb-8">
          <p className="text-sm text-muted-foreground">
            Your current studio membership does not include Team directory access.
          </p>
        </Card>
      ) : (
        <>
          {canInvite && (
            <Card className="p-6 mb-8">
              <h2 className="font-serif text-lg text-primary">Invite a teammate</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Create a private invitation. The invitation link is shown only once when it is
                created.
              </p>

              <form
                className="mt-4 space-y-4"
                onSubmit={(event) => {
                  event.preventDefault();

                  inviteMutation.mutate({
                    email: inviteEmail.trim(),
                    fullName: inviteName.trim() || undefined,
                    roles: canAssignRoles ? inviteRoles : [],
                  });
                }}
              >
                <div className="grid gap-4 sm:grid-cols-2">
                  <label className="block">
                    <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                      Email
                    </span>
                    <input
                      type="email"
                      required
                      maxLength={255}
                      value={inviteEmail}
                      onChange={(event) => setInviteEmail(event.target.value)}
                      className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                    />
                  </label>

                  <label className="block">
                    <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                      Full name (optional)
                    </span>
                    <input
                      maxLength={160}
                      value={inviteName}
                      onChange={(event) => setInviteName(event.target.value)}
                      className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                    />
                  </label>
                </div>

                {canAssignRoles ? (
                  <div>
                    <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                      Preassigned roles (optional)
                    </span>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {appRoles.map((role) => {
                        const selected = inviteRoles.includes(role);

                        return (
                          <button
                            type="button"
                            key={role}
                            onClick={() =>
                              setInviteRoles((current) =>
                                selected
                                  ? current.filter((candidate) => candidate !== role)
                                  : [...current, role],
                              )
                            }
                            className={`rounded-full border px-2.5 py-1 text-[11px] transition ${
                              selected
                                ? "border-gold bg-accent text-primary"
                                : "border-border text-muted-foreground hover:bg-accent/50"
                            }`}
                          >
                            {roleLabels[role]}
                          </button>
                        );
                      })}
                    </div>
                    <p className="mt-2 text-xs text-muted-foreground">
                      You may also create the invitation without preassigning a role.
                    </p>
                  </div>
                ) : (
                  <div className="rounded-xl border border-border bg-background/40 p-4">
                    <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                      Role assignment
                    </div>
                    <p className="mt-1 text-sm text-muted-foreground">
                      You can invite this teammate now. A teammate with role-assignment permission
                      can assign access separately.
                    </p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={inviteMutation.isPending}
                  className="rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
                >
                  {inviteMutation.isPending ? "Creating…" : "Create invitation & copy link"}
                </button>
              </form>

              <div className="mt-6 border-t border-border pt-5">
                <h3 className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  Invitation history
                </h3>

                {invites.isLoading ? (
                  <p className="mt-3 text-sm italic text-muted-foreground">
                    Looking for invitations…
                  </p>
                ) : invites.isError ? (
                  <p className="mt-3 text-sm text-muted-foreground">
                    Invitation history could not be loaded.
                  </p>
                ) : !invites.data?.length ? (
                  <p className="mt-3 text-sm italic text-muted-foreground">No invitations yet.</p>
                ) : (
                  <div className="mt-3 space-y-3">
                    {invites.data.map((invitation) => {
                      const labels = displayRoleLabels(invitation.roles, invitation.roleLabels);

                      return (
                        <div
                          key={invitation.id}
                          className="rounded-xl border border-border p-4 flex flex-wrap items-start justify-between gap-3"
                        >
                          <div className="min-w-0">
                            <div className="font-medium text-primary break-all">
                              {invitation.email}
                            </div>

                            {invitation.fullName && (
                              <div className="text-sm text-muted-foreground">
                                {invitation.fullName}
                              </div>
                            )}

                            <div className="mt-1 text-xs text-muted-foreground">
                              {labels.length ? labels.join(" · ") : "No roles preassigned"}
                            </div>

                            <div className="mt-1 text-xs text-muted-foreground">
                              Created {invitation.createdAt.slice(0, 10)} · expires{" "}
                              {invitation.expiresAt.slice(0, 10)}
                            </div>
                          </div>

                          <div className="flex items-center gap-2">
                            <StatusPill
                              tone={
                                invitation.status === "accepted"
                                  ? "good"
                                  : invitation.status === "pending"
                                    ? "warn"
                                    : "neutral"
                              }
                            >
                              {invitation.status}
                            </StatusPill>

                            {invitation.status === "pending" && (
                              <button
                                type="button"
                                disabled={revokeMutation.isPending}
                                onClick={() => revokeMutation.mutate(invitation.id)}
                                className="rounded-full border border-border px-2.5 py-1 text-[11px] text-muted-foreground hover:bg-accent/50 disabled:opacity-60"
                              >
                                Revoke
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </Card>
          )}

          <Card className="p-6 mb-8">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 className="font-serif text-lg text-primary">Studio access</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Canonical membership, role grants, and exact access scopes.
                </p>
              </div>

              {canAssignRoles && (
                <StatusPill tone="good">Exact role administration enabled</StatusPill>
              )}
            </div>

            {members.isLoading ? (
              <p className="mt-4 text-sm italic text-muted-foreground">Gathering the team…</p>
            ) : members.isError ? (
              <p className="mt-4 text-sm text-muted-foreground">
                The canonical Team directory could not be loaded.
              </p>
            ) : !members.data?.length ? (
              <p className="mt-4 text-sm italic text-muted-foreground">
                No active or suspended studio memberships were found.
              </p>
            ) : (
              <div className="mt-4 space-y-4">
                {members.data.map((member) => {
                  const labels = Array.from(
                    new Set(displayRoleLabels(member.roles, member.roleLabels)),
                  );
                  const exactGrants =
                    roleAdministration.data?.grants.filter(
                      (grant) => grant.memberId === member.memberId,
                    ) ?? [];

                  const roleOptions = roleAdministration.data?.roles ?? [];
                  const allScopes = roleAdministration.data?.scopes ?? [];

                  const selectedRole = roleSelections[member.memberId] ?? "";

                  const eligibleScopes =
                    selectedRole === "founder"
                      ? allScopes.filter((scope) => scope.organizationWide)
                      : allScopes;

                  const requestedScopeValue = scopeSelections[member.memberId] ?? "";

                  const selectedScope = eligibleScopes.find(
                    (scope) => scopeValue(scope) === requestedScopeValue,
                  );

                  const selectedScopeValue = selectedScope ? scopeValue(selectedScope) : "";
                  const selectedBranchId = selectedScope?.branchId ?? null;

                  const duplicateGrant =
                    selectedRole.length > 0 &&
                    Boolean(selectedScope) &&
                    exactGrants.some(
                      (grant) =>
                        grant.roleKey === selectedRole &&
                        (grant.branchId ?? null) === selectedBranchId,
                    );

                  const selectedRoleOption = roleOptions.find((role) => role.key === selectedRole);

                  const assignmentDisabled =
                    member.status !== "active" ||
                    !selectedRole ||
                    !selectedScope ||
                    duplicateGrant ||
                    grantMutation.isPending;

                  return (
                    <div key={member.memberId} className="rounded-xl border border-border p-4">
                      <div className="flex flex-wrap items-start justify-between gap-3">
                        <div className="min-w-0">
                          <div className="font-medium text-primary">
                            {member.displayName || member.email || "Team member"}
                          </div>

                          {member.email && (
                            <div className="text-xs text-muted-foreground break-all">
                              {member.email}
                            </div>
                          )}

                          {member.phone && (
                            <div className="text-xs text-muted-foreground">{member.phone}</div>
                          )}
                        </div>

                        <StatusPill tone={member.status === "active" ? "good" : "warn"}>
                          {member.status}
                        </StatusPill>
                      </div>

                      <div className="mt-3 flex flex-wrap gap-1.5">
                        {labels.length ? (
                          labels.map((label, index) => (
                            <span
                              key={`${member.memberId}-role-${index}`}
                              className="rounded-full border border-gold bg-accent px-2.5 py-1 text-[11px] text-primary"
                            >
                              {label}
                            </span>
                          ))
                        ) : (
                          <span className="text-xs italic text-muted-foreground">
                            No active role grants
                          </span>
                        )}
                      </div>

                      <div className="mt-3 text-xs leading-relaxed text-muted-foreground">
                        {member.organizationWide && <div>Organization-wide access is present.</div>}

                        {member.branchNames.length > 0 && (
                          <div>Active branch scopes: {member.branchNames.join(" · ")}</div>
                        )}

                        <div>Joined {member.joinedAt.slice(0, 10)}</div>
                      </div>

                      {canAssignRoles && (
                        <div className="mt-5 border-t border-border pt-4">
                          <div className="flex flex-wrap items-center justify-between gap-2">
                            <div>
                              <h3 className="text-[11px] uppercase tracking-wider text-muted-foreground">
                                Exact role grants
                              </h3>
                              <p className="mt-1 text-xs text-muted-foreground">
                                Each role and scope is an independent canonical grant.
                              </p>
                            </div>

                            {member.memberId === capabilities.data?.actorMemberId && (
                              <StatusPill tone="neutral">Your membership</StatusPill>
                            )}
                          </div>

                          {roleAdministration.isLoading ? (
                            <p className="mt-3 text-sm italic text-muted-foreground">
                              Loading exact role grants…
                            </p>
                          ) : roleAdministration.isError ? (
                            <div className="mt-3 rounded-xl border border-border bg-background/40 p-4">
                              <p className="text-sm text-muted-foreground">
                                Exact role-administration state could not be loaded. The ordinary
                                Team directory remains available.
                              </p>
                            </div>
                          ) : (
                            <>
                              <div className="mt-3 space-y-2">
                                {exactGrants.length ? (
                                  exactGrants.map((grant) => {
                                    const currentAssignmentScope =
                                      grant.organizationWide ||
                                      allScopes.some(
                                        (scope) =>
                                          !scope.organizationWide &&
                                          scope.branchId === grant.branchId,
                                      );

                                    return (
                                      <div
                                        key={grant.grantId}
                                        className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border bg-background/30 px-3 py-2.5"
                                      >
                                        <div className="min-w-0">
                                          <div className="text-sm font-medium text-primary">
                                            {grant.roleLabel}
                                          </div>

                                          <div className="text-xs text-muted-foreground">
                                            {grantScopeLabel(grant)}
                                            {!currentAssignmentScope &&
                                              " · historical / non-assignable scope"}
                                          </div>
                                        </div>

                                        <button
                                          type="button"
                                          disabled={roleRevokeMutation.isPending}
                                          onClick={() =>
                                            roleRevokeMutation.mutate({
                                              memberId: grant.memberId,
                                              roleKey: grant.roleKey,
                                              branchId: grant.branchId,
                                            })
                                          }
                                          className="rounded-full border border-border px-2.5 py-1 text-[11px] text-muted-foreground hover:bg-accent/50 disabled:opacity-60"
                                        >
                                          {roleRevokeMutation.isPending ? "Removing…" : "Remove"}
                                        </button>
                                      </div>
                                    );
                                  })
                                ) : (
                                  <p className="text-xs italic text-muted-foreground">
                                    No exact live grants.
                                  </p>
                                )}
                              </div>

                              <div className="mt-4 rounded-xl border border-border bg-background/40 p-4">
                                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                                  Assign exact access
                                </div>

                                {member.status !== "active" && (
                                  <p className="mt-2 text-xs text-muted-foreground">
                                    New role grants are disabled while this membership is{" "}
                                    {member.status}. Existing grants remain individually removable.
                                  </p>
                                )}

                                <div className="mt-3 grid gap-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto] sm:items-end">
                                  <label className="block">
                                    <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                                      Role
                                    </span>

                                    <select
                                      value={selectedRole}
                                      disabled={
                                        member.status !== "active" ||
                                        grantMutation.isPending ||
                                        roleOptions.length === 0
                                      }
                                      onChange={(event) => {
                                        const nextRole = event.target.value;

                                        setRoleSelections((current) => ({
                                          ...current,
                                          [member.memberId]: nextRole,
                                        }));

                                        setScopeSelections((current) => ({
                                          ...current,
                                          [member.memberId]:
                                            nextRole === "founder" ? ORGANIZATION_WIDE_SCOPE : "",
                                        }));
                                      }}
                                      className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                                    >
                                      <option value="" disabled>
                                        Choose a role
                                      </option>

                                      {roleOptions.map((role) => (
                                        <option key={role.key} value={role.key}>
                                          {role.label}
                                        </option>
                                      ))}
                                    </select>
                                  </label>

                                  <label className="block">
                                    <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                                      Scope
                                    </span>

                                    <select
                                      value={selectedScopeValue}
                                      disabled={
                                        member.status !== "active" ||
                                        !selectedRole ||
                                        grantMutation.isPending ||
                                        eligibleScopes.length === 0
                                      }
                                      onChange={(event) =>
                                        setScopeSelections((current) => ({
                                          ...current,
                                          [member.memberId]: event.target.value,
                                        }))
                                      }
                                      className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                                    >
                                      <option value="" disabled>
                                        Choose a scope
                                      </option>

                                      {eligibleScopes.map((scope) => (
                                        <option key={scopeValue(scope)} value={scopeValue(scope)}>
                                          {scope.organizationWide
                                            ? "Organization-wide"
                                            : scope.branchCode
                                              ? `${scope.branchName} (${scope.branchCode})`
                                              : scope.branchName}
                                        </option>
                                      ))}
                                    </select>
                                  </label>

                                  <button
                                    type="button"
                                    disabled={assignmentDisabled}
                                    onClick={() => {
                                      if (!selectedScope) {
                                        return;
                                      }

                                      grantMutation.mutate({
                                        memberId: member.memberId,
                                        roleKey: selectedRole,
                                        branchId: selectedScope.branchId,
                                      });
                                    }}
                                    className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
                                  >
                                    {grantMutation.isPending
                                      ? "Assigning…"
                                      : duplicateGrant
                                        ? "Already assigned"
                                        : "Assign"}
                                  </button>
                                </div>

                                {selectedRoleOption?.description && (
                                  <p className="mt-2 text-xs text-muted-foreground">
                                    {selectedRoleOption.description}
                                  </p>
                                )}

                                {selectedRole === "founder" && (
                                  <p className="mt-2 text-xs text-muted-foreground">
                                    Founder access is organization-wide only. Final-Founder safety
                                    remains enforced by the canonical database guard.
                                  </p>
                                )}
                              </div>
                            </>
                          )}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </Card>
        </>
      )}
    </AppShell>
  );
}
