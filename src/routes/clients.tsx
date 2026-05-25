import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { clients } from "@/lib/mock-data";

export const Route = createFileRoute("/clients")({
  head: () => ({ meta: [{ title: "Clients · Little Moments OS" }] }),
  component: () => (
    <AppShell>
      <PageHeader
        eyebrow="Families"
        title="Clients"
        subtitle="Families we are walking with — across pregnancy, newborn, milestones, and beyond."
        quote="A client is not a booking. It is a relationship that can last a generation."
      />
      <div className="grid lg:grid-cols-2 gap-5">
        {clients.map((c) => (
          <Card key={c.id} className="p-6">
            <div className="flex items-start justify-between">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{c.id}</div>
                <h3 className="font-serif text-xl text-primary mt-1">{c.name}</h3>
                <div className="text-xs text-muted-foreground mt-0.5">{c.city} · {c.phone}</div>
              </div>
              <StatusPill tone="gold">{c.pastSessions} past sessions</StatusPill>
            </div>
            <div className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
              <F k="Family" v={c.family} />
              <F k="Child / baby" v={c.childName} />
              <F k="DOB" v={c.dob} />
              <F k="Pregnancy stage" v={c.pregnancy} />
              <F k="Email" v={c.email} />
            </div>
            <div className="mt-4 pt-4 border-t border-border">
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Notes</div>
              <p className="text-sm text-primary/80 mt-1">{c.notes}</p>
            </div>
            <div className="mt-3 flex items-center gap-2 text-xs">
              <span className="text-muted-foreground">Next milestone reminder:</span>
              <span className="text-primary font-medium">{c.nextMilestone}</span>
            </div>
          </Card>
        ))}
      </div>
    </AppShell>
  ),
});

function F({ k, v }: { k: string; v: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{k}</div>
      <div className="text-primary">{v}</div>
    </div>
  );
}