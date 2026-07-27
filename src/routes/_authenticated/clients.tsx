import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";
import { CalendarHeart } from "lucide-react";

export const Route = createFileRoute("/_authenticated/clients")({
  head: () => ({ meta: [{ title: "Clients · Little Moments OS" }] }),
  component: ClientsPage,
});

function ClientsPage() {
  const clients = useStore((s) => s.clients);
  const bookings = useStore((s) => s.bookings);
  const createBookingForClient = useStore((s) => s.createBookingForClient);
  const navigate = useNavigate();
  return (
    <AppShell>
      <PageHeader
        eyebrow="Families"
        title="Clients"
        subtitle="Families we are walking with — across pregnancy, newborn, milestones, and beyond."
        quote="A client is not a booking. It is a relationship that can last a generation."
      />
      <div className="grid lg:grid-cols-2 gap-5">
        {clients.map((c) => {
          const clientBookings = bookings.filter((b) => b.clientId === c.id || b.client === c.name);
          return (
          <Card key={c.id} className="p-6">
            <div className="flex items-start justify-between">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{c.id}</div>
                <h3 className="font-serif text-xl text-primary mt-1">{c.name}</h3>
                <div className="text-xs text-muted-foreground mt-0.5">{c.city} · {c.phone}</div>
              </div>
              <StatusPill tone="gold">{clientBookings.length || c.pastSessions} bookings</StatusPill>
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
            <div className="mt-4 pt-4 border-t border-border flex items-center justify-between">
              <div className="text-xs text-muted-foreground">
                {clientBookings.length
                  ? clientBookings.map((b) => b.id).join(" · ")
                  : "No bookings yet."}
              </div>
              <button
                onClick={() => {
                  const r = createBookingForClient(c.id);
                  handle(r);
                  if (r.ok) navigate({ to: "/bookings" });
                }}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground hover:opacity-90"
              >
                <CalendarHeart className="h-3 w-3" /> New booking
              </button>
            </div>
          </Card>
        );})}
        {clients.length === 0 && (
          <Card className="p-10 text-center col-span-full">
            <p className="font-serif text-xl text-primary">No clients yet.</p>
            <p className="text-sm text-muted-foreground mt-2">Convert a lead to begin a family's story.</p>
          </Card>
        )}
      </div>
    </AppShell>
  );
}

function F({ k, v }: { k: string; v: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{k}</div>
      <div className="text-primary">{v}</div>
    </div>
  );
}