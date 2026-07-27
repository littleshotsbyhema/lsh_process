import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import { toast } from "sonner";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { teamRoles } from "@/lib/mock-data";
import { listTeam, setTeamRole } from "@/lib/team.functions";
import { createInvite, listInvites, revokeInvite } from "@/lib/invites.functions";
import { appRoles, roleLabels, useSession, type AppRole } from "@/lib/session";

export const Route = createFileRoute("/_authenticated/team")({
  head: () => ({
    meta: [
      { title: "Team · Little Moments OS" },
      {
        name: "description",
        content: "Studio roles, open tasks per role, and who can access which part of Little Moments OS.",
      },
      { property: "og:title", content: "Team · Little Moments OS" },
      { property: "og:description", content: "Every role exists to protect a memory." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: TeamPage,
});

function TeamPage() {
  const { tasks } = useStore();
  const { roles } = useSession();
  const isFounder = roles.includes("founder");
  const fetchTeam = useServerFn(listTeam);
  const saveRole = useServerFn(setTeamRole);
  const fetchInvites = useServerFn(listInvites);
  const sendInvite = useServerFn(createInvite);
  const cancelInvite = useServerFn(revokeInvite);
  const queryClient = useQueryClient();

  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteName, setInviteName] = useState("");
  const [inviteRoles, setInviteRoles] = useState<AppRole[]>([]);

  const invites = useQuery({
    queryKey: ["invites"],
    enabled: isFounder,
    queryFn: () => fetchInvites(),
  });

  const inviteMutation = useMutation({
    mutationFn: (vars: { email: string; fullName?: string; roles: AppRole[] }) =>
      sendInvite({ data: vars }),
    onSuccess: (invite) => {
      const url = `${window.location.origin}/auth?invite=${invite.token}`;
      void navigator.clipboard?.writeText(url).catch(() => undefined);
      toast.success("Invitation created — link copied to your clipboard.");
      setInviteEmail("");
      setInviteName("");
      setInviteRoles([]);
      void queryClient.invalidateQueries({ queryKey: ["invites"] });
    },
    onError: (e: unknown) =>
      toast.error(e instanceof Error ? e.message : "Could not create the invitation."),
  });

  const revokeMutation = useMutation({
    mutationFn: (id: string) => cancelInvite({ data: { id } }),
    onSuccess: () => {
      toast.success("Invitation revoked.");
      void queryClient.invalidateQueries({ queryKey: ["invites"] });
    },
    onError: (e: unknown) => toast.error(e instanceof Error ? e.message : "Could not revoke."),
  });

  const members = useQuery({ queryKey: ["team"], queryFn: () => fetchTeam() });
  const mutate = useMutation({
    mutationFn: (vars: { userId: string; role: AppRole; grant: boolean }) => saveRole({ data: vars }),
    onSuccess: () => {
      toast.success("Studio access updated.");
      void queryClient.invalidateQueries({ queryKey: ["team"] });
    },
    onError: (e: unknown) => toast.error(e instanceof Error ? e.message : "Could not update access."),
  });

  return (
    <AppShell>
      <PageHeader
        eyebrow="The Studio"
        title="Team"
        subtitle="Every role exists to protect a memory."
        quote="We are a small team because care does not scale carelessly."
      />

      {isFounder && (
        <Card className="p-6 mb-8">
          <h2 className="font-serif text-lg text-primary">Invite a teammate</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Add their email, choose the rooms they'll work in, and share the private link. Studio
            access is invitation-only.
          </p>
          <form
            className="mt-4 space-y-4"
            onSubmit={(e) => {
              e.preventDefault();
              if (!inviteRoles.length) {
                toast.error("Choose at least one role.");
                return;
              }
              inviteMutation.mutate({
                email: inviteEmail.trim(),
                fullName: inviteName.trim() || undefined,
                roles: inviteRoles,
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
                  onChange={(e) => setInviteEmail(e.target.value)}
                  className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                />
              </label>
              <label className="block">
                <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  Full name (optional)
                </span>
                <input
                  maxLength={120}
                  value={inviteName}
                  onChange={(e) => setInviteName(e.target.value)}
                  className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                />
              </label>
            </div>
            <div>
              <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Roles
              </span>
              <div className="mt-2 flex flex-wrap gap-1.5">
                {appRoles.map((role) => {
                  const on = inviteRoles.includes(role);
                  return (
                    <button
                      type="button"
                      key={role}
                      onClick={() =>
                        setInviteRoles((prev) =>
                          on ? prev.filter((r) => r !== role) : [...prev, role],
                        )
                      }
                      className={`rounded-full border px-2.5 py-1 text-[11px] transition ${
                        on
                          ? "border-gold bg-accent text-primary"
                          : "border-border text-muted-foreground hover:bg-accent/50"
                      }`}
                    >
                      {roleLabels[role]}
                    </button>
                  );
                })}
              </div>
            </div>
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
              Invitations
            </h3>
            {invites.isLoading ? (
              <p className="mt-3 text-sm italic text-muted-foreground">Looking for invitations…</p>
            ) : !invites.data?.length ? (
              <p className="mt-3 text-sm italic text-muted-foreground">No invitations yet.</p>
            ) : (
              <div className="mt-3 space-y-3">
                {invites.data.map((inv) => (
                  <div
                    key={inv.id}
                    className="rounded-xl border border-border p-4 flex flex-wrap items-start justify-between gap-3"
                  >
                    <div className="min-w-0">
                      <div className="font-medium text-primary break-all">{inv.email}</div>
                      <div className="text-xs text-muted-foreground">
                        {inv.roles.map((r) => roleLabels[r as AppRole] ?? r).join(" · ")}
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <StatusPill
                        tone={
                          inv.status === "accepted"
                            ? "good"
                            : inv.status === "pending"
                              ? "warn"
                              : "muted"
                        }
                      >
                        {inv.status}
                      </StatusPill>
                      {inv.status === "pending" && (
                        <>
                          <button
                            onClick={() => {
                              void navigator.clipboard?.writeText(
                                `${window.location.origin}/auth?invite=${inv.token}`,
                              );
                              toast.success("Invite link copied.");
                            }}
                            className="rounded-full border border-border px-2.5 py-1 text-[11px] text-primary hover:bg-accent/50"
                          >
                            Copy link
                          </button>
                          <button
                            disabled={revokeMutation.isPending}
                            onClick={() => revokeMutation.mutate(inv.id)}
                            className="rounded-full border border-border px-2.5 py-1 text-[11px] text-muted-foreground hover:bg-accent/50"
                          >
                            Revoke
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </Card>
      )}

      <Card className="p-6 mb-8">
        <h2 className="font-serif text-lg text-primary">Studio access</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          {isFounder
            ? "Assign roles so each person sees only the rooms they work in."
            : "Only a Founder can change studio access."}
        </p>
        {members.isLoading ? (
          <p className="mt-4 text-sm italic text-muted-foreground">Gathering the team…</p>
        ) : !members.data?.length ? (
          <p className="mt-4 text-sm italic text-muted-foreground">No one has signed in yet.</p>
        ) : (
          <div className="mt-4 space-y-4">
            {members.data.map((m) => (
              <div key={m.id} className="rounded-xl border border-border p-4">
                <div className="font-medium text-primary">{m.full_name || m.email || "Team member"}</div>
                <div className="text-xs text-muted-foreground">{m.email}</div>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {appRoles.map((role) => {
                    const has = m.roles.includes(role);
                    return (
                      <button
                        key={role}
                        disabled={!isFounder || mutate.isPending}
                        onClick={() => mutate.mutate({ userId: m.id, role, grant: !has })}
                        className={`rounded-full border px-2.5 py-1 text-[11px] transition ${
                          has
                            ? "border-gold bg-accent text-primary"
                            : "border-border text-muted-foreground hover:bg-accent/50"
                        } ${isFounder ? "" : "cursor-not-allowed opacity-70"}`}
                      >
                        {roleLabels[role]}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        {teamRoles.map((role) => {
          const open = tasks.filter((t) => t.role === role && t.status !== "Done" && t.status !== "Skipped").length;
          return (
            <Card key={role} className="p-5">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">Role</div>
              <h3 className="font-serif text-lg text-primary mt-1">{role}</h3>
              <div className="mt-3 flex items-center justify-between text-sm">
                <span className="text-muted-foreground">Open tasks</span>
                <StatusPill tone={open ? "warn" : "good"}>{open}</StatusPill>
              </div>
            </Card>
          );
        })}
      </div>
    </AppShell>
  );
}