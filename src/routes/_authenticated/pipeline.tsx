import { createFileRoute, Link } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { journeyStages } from "@/lib/mock-data";

export const Route = createFileRoute("/_authenticated/pipeline")({
  head: () => ({ meta: [{ title: "Pipeline · Little Moments OS" }] }),
  component: PipelinePage,
});

function PipelinePage() {
  const { bookings } = useStore();
  const grouped = journeyStages.map((stage) => ({
    stage,
    items: bookings.filter((b) => b.journeyStage === stage),
  }));

  return (
    <AppShell>
      <PageHeader
        eyebrow="Client Journey"
        title="Pipeline"
        subtitle="Every booking, gently progressing through its stage."
        quote="A journey honoured well becomes a relationship that lasts."
      />

      <div className="flex gap-4 overflow-x-auto pb-4">
        {grouped.map(({ stage, items }) => (
          <div key={stage} className="min-w-[260px] flex-shrink-0">
            <Card className="p-4 h-full">
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-serif text-sm text-primary">{stage}</h3>
                <StatusPill tone={items.length ? "gold" : "neutral"}>{items.length}</StatusPill>
              </div>
              {items.length === 0 ? (
                <p className="text-xs italic text-muted-foreground">Empty</p>
              ) : (
                <ul className="space-y-2">
                  {items.map((b) => (
                    <li key={b.id}>
                      <Link to="/bookings" className="block rounded-lg border border-border bg-card p-3 hover:bg-accent">
                        <div className="text-sm font-medium text-primary truncate">{b.client}</div>
                        <div className="text-[11px] text-muted-foreground">{b.category} · {b.date}</div>
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </div>
        ))}
      </div>
    </AppShell>
  );
}