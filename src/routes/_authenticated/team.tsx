import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import { toast } from "sonner";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { getTeamCapabilities, listTeam } from "@/lib/team.functions";
import { createInvite, listInvites, revokeInvite } from "@/lib/invites.functions";
import { appRoles, roleLabels, type AppRole } from "@/lib/session";

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

function TeamPage() {
  const fetchCapabilities = useServerFn(getTeamCapabilities);
  const fetchTeam = useServerFn(listTeam);
  const fetchInvites = useServerFn(listInvites);
  const sendInvite = useServerFn(createInvite);
  const cancelInvite = useServerFn(revokeInvite);
  const queryClient = useQueryClient();

  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteName, setInviteName] = useState("");
  const [inviteRoles, setInviteRoles] = useState<AppRole[]>([]);

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

  const invites = useQuery({
    queryKey: ["invites"],
    enabled: canInvite,
    queryFn: () => fetchInvites(),
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
                  Current canonical roles are shown read-only in this slice.
                </p>
              </div>

              {capabilities.data?.canAssignRoles && (
                <StatusPill tone="neutral">Role editing intentionally contained</StatusPill>
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
                  const labels = displayRoleLabels(member.roles, member.roleLabels);

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
