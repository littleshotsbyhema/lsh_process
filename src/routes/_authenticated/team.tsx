import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { teamRoles } from "@/lib/mock-data";
import { listTeam, setTeamRole } from "@/lib/team.functions";
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
  const queryClient = useQueryClient();

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