import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore, bookingAlignment } from "@/store/useStore";

export const Route = createFileRoute("/_authenticated/reports")({
  head: () => ({
    meta: [
      { title: "Reports · Little Moments OS" },
      {
        name: "description",
        content: "Founder view of revenue, conversion, package split and operational health.",
      },
      { property: "og:title", content: "Reports · Little Moments OS" },
      {
        property: "og:description",
        content: "Founder view of revenue, conversion, package split and operational health.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ReportsPage,
});

function ReportsPage() {
  const { bookings, leads, privacy, editing, heirloom, reviews, alignment, tasks } = useStore();
  const todayDate = new Date().toISOString().slice(0, 10);

  const revenue = bookings.reduce(
    (sum, b) => sum + (b.payment === "Paid" ? b.offer : b.advance),
    0,
  );
  const bySource: Record<string, number> = {};
  leads.forEach((l) => {
    bySource[l.source] = (bySource[l.source] ?? 0) + 1;
  });
  const conversion = leads.length
    ? Math.round((leads.filter((l) => l.status === "Booked").length / leads.length) * 100)
    : 0;
  const packageCounts: Record<string, number> = {};
  bookings.forEach((b) => {
    packageCounts[b.package] = (packageCounts[b.package] ?? 0) + 1;
  });
  const tiers = ["Bronze", "Gold", "Diamond", "Emerald"].map((tier) => ({
    tier,
    count: bookings.filter((b) => b.package.startsWith(tier)).length,
  }));

  const pendingPrivacy = bookings.filter((b) => !privacy.find((p) => p.bookingId === b.id)).length;
  const safetyPct = bookings.length
    ? Math.round((bookings.filter((b) => b.safety === "Completed").length / bookings.length) * 100)
    : 100;
  const editingDelays = editing.filter(
    (e) => e.deadline !== "—" && e.deadline < todayDate && e.status !== "Delivered",
  ).length;
  const heirloomDelays = heirloom.filter((h) => !h.delivered).length;
  const reviewsPending = reviews.filter(
    (r) => r.requestStatus === "Pending" || r.requestStatus === "Requested",
  ).length;
  const reviewsReceived = reviews.filter((r) => r.requestStatus === "Received").length;
  const csat = (() => {
    const rated = reviews.filter((r) => typeof r.rating === "number");
    if (!rated.length) return "—";
    return (rated.reduce((s, r) => s + (r.rating ?? 0), 0) / rated.length).toFixed(1);
  })();
  const repeatOpps = reviews.filter((r) => r.repeatOpportunity).length;
  const alignmentAvg = (() => {
    if (!bookings.length) return 0;
    const vals = bookings.map((b) => bookingAlignment(b.id, alignment)).filter(Boolean);
    if (!vals.length) return 0;
    return Math.round((vals.reduce((a, b) => a + b, 0) / vals.length) * 10) / 10;
  })();
  const marketingPending = tasks.filter(
    (t) => t.role === "Marketing Team" && t.status === "Pending",
  ).length;

  const cards = [
    { label: "Monthly revenue (collected)", value: `₹${revenue.toLocaleString("en-IN")}` },
    { label: "Booking conversion", value: `${conversion}%` },
    {
      label: "Pending privacy issues",
      value: pendingPrivacy,
      tone: pendingPrivacy ? "bad" : "good",
    },
    {
      label: "Safety checklist completion",
      value: `${safetyPct}%`,
      tone: safetyPct >= 95 ? "good" : "warn",
    },
    { label: "Editing delays", value: editingDelays, tone: editingDelays ? "warn" : "good" },
    {
      label: "Album / frame delays",
      value: heirloomDelays,
      tone: heirloomDelays ? "warn" : "good",
    },
    {
      label: "Review requests pending",
      value: reviewsPending,
      tone: reviewsPending ? "warn" : "good",
    },
    { label: "Reviews received", value: reviewsReceived, tone: "good" },
    { label: "Client satisfaction (avg)", value: csat, tone: "gold" },
    { label: "Repeat milestone opportunities", value: repeatOpps, tone: "gold" },
    {
      label: "Philosophy Alignment Score",
      value: alignmentAvg ? `${alignmentAvg}/5` : "—",
      tone: "gold",
    },
    {
      label: "Marketing content pending approval",
      value: marketingPending,
      tone: marketingPending ? "warn" : "good",
    },
  ] as const;

  return (
    <AppShell>
      <PageHeader
        eyebrow="Phase 9 · Founder & Admin View"
        title="Reports / KPIs"
        subtitle="The studio's monthly health — read with care, not pressure."
        quote="Numbers are the echo of the memories we protected this month."
      />

      <section className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4 mb-8">
        {cards.map((c) => (
          <Card key={c.label} className="p-5">
            <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
              {c.label}
            </div>
            <div className="mt-2 font-serif text-2xl text-primary">{c.value}</div>
            {"tone" in c && c.tone && (
              <div className="mt-2">
                <StatusPill tone={c.tone as "good" | "warn" | "bad" | "gold"}>
                  {String(c.value)}
                </StatusPill>
              </div>
            )}
          </Card>
        ))}
      </section>

      <div className="grid lg:grid-cols-2 gap-6">
        <Card className="p-6">
          <h2 className="font-serif text-lg text-primary mb-4">Inquiries by source</h2>
          {Object.keys(bySource).length === 0 ? (
            <p className="text-sm italic text-muted-foreground">No inquiries yet.</p>
          ) : (
            <ul className="space-y-2">
              {Object.entries(bySource).map(([k, v]) => (
                <li key={k} className="flex items-center justify-between text-sm">
                  <span>{k}</span>
                  <StatusPill tone="neutral">{v}</StatusPill>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="p-6">
          <h2 className="font-serif text-lg text-primary mb-4">Package split</h2>
          <ul className="space-y-2">
            {tiers.map((t) => (
              <li key={t.tier} className="flex items-center justify-between text-sm">
                <span>{t.tier}</span>
                <StatusPill tone="gold">{t.count}</StatusPill>
              </li>
            ))}
          </ul>
          <div className="mt-5 border-t border-border pt-4">
            <h3 className="text-xs uppercase tracking-wider text-muted-foreground mb-2">
              Top packages
            </h3>
            <ul className="space-y-1.5">
              {Object.entries(packageCounts)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 4)
                .map(([k, v]) => (
                  <li key={k} className="flex items-center justify-between text-sm">
                    <span className="truncate pr-2">{k}</span>
                    <span className="text-muted-foreground">{v}</span>
                  </li>
                ))}
            </ul>
          </div>
        </Card>
      </div>
    </AppShell>
  );
}
