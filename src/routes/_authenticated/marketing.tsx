import { createFileRoute, Link } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore, bookingFlags } from "@/store/useStore";
import { toast } from "sonner";

export const Route = createFileRoute("/_authenticated/marketing")({
  head: () => ({
    meta: [
      { title: "Marketing Approvals · LittleShots by Hema OS" },
      {
        name: "description",
        content: "Approve marketing use of images only where written family consent is recorded.",
      },
      { property: "og:title", content: "Marketing Approvals · LittleShots by Hema OS" },
      {
        property: "og:description",
        content: "Approve marketing use of images only where written family consent is recorded.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: MarketingPage,
});

function MarketingPage() {
  const { bookings, tasks, updateTask } = useStore();
  const marketingTasks = tasks.filter((t) => t.role === "Marketing Team");
  const approved = bookings.filter((b) => bookingFlags(b).marketingAllowed);
  const blocked = bookings.filter(
    (b) => !bookingFlags(b).marketingAllowed && bookingFlags(b).consentRecorded === false,
  );

  return (
    <AppShell>
      <PageHeader
        eyebrow="Phase 7 · Marketing Approvals"
        title="Marketing Approvals"
        subtitle="Nothing public without written permission. The portfolio is built on trust."
        quote="A frame shared without consent is a memory borrowed without asking."
      />

      <div className="grid lg:grid-cols-2 gap-6 mb-8">
        <Card className="p-6">
          <h2 className="font-serif text-lg text-primary mb-3">Approved for marketing</h2>
          {approved.length === 0 ? (
            <p className="text-sm italic text-muted-foreground">
              Every shared memory is protected with consent.
            </p>
          ) : (
            <ul className="divide-y divide-border">
              {approved.map((b) => (
                <li key={b.id} className="py-3 flex items-center justify-between">
                  <div>
                    <div className="font-medium text-primary">{b.client}</div>
                    <div className="text-xs text-muted-foreground">{b.privacy}</div>
                  </div>
                  <StatusPill tone="good">Approved</StatusPill>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="p-6">
          <h2 className="font-serif text-lg text-primary mb-3">Blocked — consent missing</h2>
          {blocked.length === 0 ? (
            <p className="text-sm italic text-muted-foreground">
              All bookings have a consent decision recorded.
            </p>
          ) : (
            <ul className="divide-y divide-border">
              {blocked.map((b) => (
                <li key={b.id} className="py-3 flex items-center justify-between">
                  <div>
                    <div className="font-medium text-primary">{b.client}</div>
                    <div className="text-xs text-muted-foreground">
                      {b.id} · {b.category}
                    </div>
                  </div>
                  <Link
                    to="/privacy"
                    className="text-xs px-3 py-1.5 rounded-lg border border-border bg-card hover:bg-accent"
                  >
                    Record consent
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <Card className="p-6">
        <h2 className="font-serif text-lg text-primary mb-3">Marketing review tasks</h2>
        {marketingTasks.length === 0 ? (
          <p className="text-sm italic text-muted-foreground">No marketing reviews pending.</p>
        ) : (
          <ul className="divide-y divide-border">
            {marketingTasks.map((t) => (
              <li key={t.id} className="py-3 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="font-medium text-primary truncate">{t.title}</div>
                  <div className="text-xs text-muted-foreground">
                    {t.relatedLabel ?? "—"} · due {t.dueDate}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <StatusPill
                    tone={t.status === "Done" ? "good" : t.status === "Blocked" ? "bad" : "warn"}
                  >
                    {t.status}
                  </StatusPill>
                  {t.status !== "Done" && (
                    <button
                      onClick={() => {
                        const r = updateTask(t.id, { status: "Done" });
                        if (r.ok) toast.success(r.message);
                      }}
                      className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground hover:opacity-90"
                    >
                      Approve
                    </button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </AppShell>
  );
}
