import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { teamRoles } from "@/lib/mock-data";

export const Route = createFileRoute("/team")({
  head: () => ({ meta: [{ title: "Team · Little Moments OS" }] }),
  component: TeamPage,
});

function TeamPage() {
  const { tasks } = useStore();
  return (
    <AppShell>
      <PageHeader
        eyebrow="The Studio"
        title="Team"
        subtitle="Every role exists to protect a memory."
        quote="We are a small team because care does not scale carelessly."
      />
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