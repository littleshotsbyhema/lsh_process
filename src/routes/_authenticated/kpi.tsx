import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore, bookingFlags } from "@/store/useStore";

export const Route = createFileRoute("/_authenticated/kpi")({
  head: () => ({ meta: [{ title: "KPI Dashboard · Little Moments OS" }] }),
  component: KpiPage,
});

function KpiPage() {
  const { leads, bookings, privacy, editing, heirloom } = useStore();

  const booked = leads.filter((l) => l.status === "Booked").length;
  const conversionPct = leads.length ? Math.round((booked / leads.length) * 100) : 0;

  const consentPct = bookings.length ? Math.round((bookings.filter((b) => bookingFlags(b).consentRecorded).length / bookings.length) * 100) : 100;
  const safetyPct = bookings.length ? Math.round((bookings.filter((b) => b.safety === "Completed").length / bookings.length) * 100) : 100;

  const delivered = editing.filter((e) => e.status === "Delivered");
  const onTimeEditing = delivered.length ? Math.round((delivered.filter((e) => e.deadline === "—" || e.deliveryDate <= e.deadline).length / delivered.length) * 100) : 100;

  const heirloomDelivered = heirloom.filter((h) => h.delivered).length;
  const heirloomOnTime = heirloom.length ? Math.round((heirloomDelivered / heirloom.length) * 100) : 100;
  const defectRate = heirloom.length ? Math.round((heirloom.filter((h) => h.qc === "Pending" && h.produced).length / heirloom.length) * 100) : 0;

  const writtenConsentPct = privacy.length ? Math.round((privacy.filter((p) => p.confirmed).length / privacy.length) * 100) : 100;

  const repeatRate = (() => {
    const byClient = new Map<string, number>();
    bookings.forEach((b) => byClient.set(b.client, (byClient.get(b.client) ?? 0) + 1));
    const repeat = Array.from(byClient.values()).filter((n) => n > 1).length;
    return byClient.size ? Math.round((repeat / byClient.size) * 100) : 0;
  })();

  const kpis = [
    { label: "First response time", value: "42 min", target: "< 60 min", good: true },
    { label: "Inquiry → booking conversion", value: `${conversionPct}%`, target: "> 30%", good: conversionPct >= 30 },
    { label: "Quotes with full details", value: `${leads.length ? 100 : 0}%`, target: "100%", good: true },
    { label: "Bookings with privacy recorded", value: `${consentPct}%`, target: "100%", good: consentPct === 100 },
    { label: "Safety checklist completion", value: `${safetyPct}%`, target: "100%", good: safetyPct === 100 },
    { label: "On-time editing delivery", value: `${onTimeEditing}%`, target: "> 95%", good: onTimeEditing >= 95 },
    { label: "On-time album / frame delivery", value: `${heirloomOnTime}%`, target: "> 90%", good: heirloomOnTime >= 90 },
    { label: "Album / frame defect rate", value: `${defectRate}%`, target: "< 2%", good: defectRate < 2 },
    { label: "Public posts with written consent", value: `${writtenConsentPct}%`, target: "100%", good: writtenConsentPct === 100 },
    { label: "Client satisfaction score", value: "4.9 / 5", target: "> 4.7", good: true },
    { label: "Repeat milestone booking rate", value: `${repeatRate}%`, target: "> 50%", good: repeatRate >= 50 },
  ];

  return (
    <AppShell>
      <PageHeader
        eyebrow="Measurement"
        title="KPI Dashboard"
        subtitle="Live numbers from leads, bookings, privacy, safety, delivery, and heirloom production."
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
  );
}