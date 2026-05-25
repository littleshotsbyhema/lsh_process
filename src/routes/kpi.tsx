import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { kpis } from "@/lib/mock-data";

export const Route = createFileRoute("/kpi")({
  head: () => ({ meta: [{ title: "KPI Dashboard · Little Moments OS" }] }),
  component: () => (
    <AppShell>
      <PageHeader
        eyebrow="Measurement"
        title="KPI Dashboard"
        subtitle="We measure what we promised: speed, trust, safety, on-time delivery, and joy."
        quote="If a number doesn't protect a memory, it doesn't belong on this dashboard."
      />

      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {kpis.map((k) => (
          <Card key={k.label} className="p-5">
            <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{k.label}</div>
            <div className="mt-2 flex items-end justify-between gap-2">
              <div className="font-serif text-3xl text-primary">{k.value}</div>
              <StatusPill tone={k.good ? "good" : "warn"}>{k.good ? "On target" : "Below target"}</StatusPill>
            </div>
            <div className="text-xs text-muted-foreground mt-2">Target: {k.target}</div>
          </Card>
        ))}
      </div>

      <Card className="p-6 mt-8">
        <div className="text-[11px] uppercase tracking-wider text-muted-foreground mb-3">Role-based access</div>
        <div className="flex flex-wrap gap-2">
          {[
            "Founder / Admin",
            "Studio Manager",
            "Client Coordinator",
            "Photographer",
            "Assistant",
            "Editor",
            "Album Coordinator",
            "Marketing Team",
            "Accounts",
          ].map((r) => (
            <span key={r} className="text-xs px-3 py-1.5 rounded-full bg-muted text-primary border border-border">
              {r}
            </span>
          ))}
        </div>
      </Card>
    </AppShell>
  ),
});