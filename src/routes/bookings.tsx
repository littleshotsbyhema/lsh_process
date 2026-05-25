import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { bookings, bookingStatuses } from "@/lib/mock-data";

export const Route = createFileRoute("/bookings")({
  head: () => ({ meta: [{ title: "Bookings · Little Moments OS" }] }),
  component: () => (
    <AppShell>
      <PageHeader
        eyebrow="Sessions"
        title="Bookings"
        subtitle="Every booking is a promise. Protect it with privacy, safety, and on-time delivery."
      />

      <div className="flex flex-wrap gap-2 mb-6">
        {bookingStatuses.map((s) => (
          <span key={s} className="text-xs px-3 py-1.5 rounded-full bg-muted text-muted-foreground border border-border">{s}</span>
        ))}
      </div>

      <div className="space-y-5">
        {bookings.map((b) => (
          <Card key={b.id} className="p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{b.id} · {b.category}</div>
                <h3 className="font-serif text-xl text-primary mt-1">{b.client}</h3>
                <div className="text-xs text-muted-foreground mt-0.5">{b.date} · {b.city} · {b.locationType}</div>
              </div>
              <div className="flex flex-wrap gap-1.5">
                <StatusPill tone="gold">{b.status}</StatusPill>
                <StatusPill tone={b.payment === "Paid" ? "good" : "warn"}>{b.payment}</StatusPill>
                <StatusPill tone={b.safety === "Completed" ? "good" : "bad"}>Safety: {b.safety}</StatusPill>
                <StatusPill tone="neutral">{b.privacy}</StatusPill>
              </div>
            </div>

            <div className="mt-5 grid md:grid-cols-3 gap-5">
              <div>
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Production</div>
                <Row k="Package" v={b.package} />
                <Row k="Photographer" v={b.photographer} />
                <Row k="Assistant" v={b.assistant} />
                <Row k="Styling" v={b.styling} />
                <Row k="Add-ons" v={b.addOns} />
                <Row k="Location" v={b.locationDetails} />
              </div>
              <div>
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Payment</div>
                <Row k="Package price" v={`₹${b.price.toLocaleString("en-IN")}`} />
                <Row k="Offer price" v={`₹${b.offer.toLocaleString("en-IN")}`} />
                <Row k="Advance paid" v={`₹${b.advance.toLocaleString("en-IN")}`} />
                <Row k="Balance due" v={`₹${b.balance.toLocaleString("en-IN")}`} />
              </div>
              <div>
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Promises</div>
                <Row k="Delivery deadline" v={b.deadline} />
                <Row k="Privacy consent" v={b.privacy} />
                <Row k="Safety checklist" v={b.safety} />
                <Row k="Booking status" v={b.status} />
              </div>
            </div>
          </Card>
        ))}
      </div>
    </AppShell>
  ),
});

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between gap-3 py-1 text-sm border-b border-dashed border-border last:border-0">
      <span className="text-muted-foreground">{k}</span>
      <span className="text-primary text-right">{v}</span>
    </div>
  );
}