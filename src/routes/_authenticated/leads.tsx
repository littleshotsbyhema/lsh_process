import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { leadStatuses, type LeadStatus } from "@/lib/mock-data";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";
import { MemoryProfileCard } from "@/components/MemoryProfileCard";
import { UserPlus, ArrowRight } from "lucide-react";

export const Route = createFileRoute("/_authenticated/leads")({
  head: () => ({ meta: [{ title: "Leads & Inquiries · Little Moments OS" }] }),
  component: LeadsPage,
});

function toneFor(status: string) {
  if (status === "Booked") return "good";
  if (status === "Lost") return "bad";
  if (status === "Follow-Up Needed" || status === "New Inquiry") return "warn";
  return "neutral";
}

function LeadsPage() {
  const leads = useStore((s) => s.leads);
  const convertLeadToClient = useStore((s) => s.convertLeadToClient);
  const createBookingForClient = useStore((s) => s.createBookingForClient);
  const setLeadStatus = useStore((s) => s.setLeadStatus);
  const navigate = useNavigate();
  return (
    <AppShell>
      <PageHeader
        eyebrow="Inquiries"
        title="Leads & Inquiries"
        subtitle="Every inquiry is a family hoping someone will care about their moment. Respond with warmth."
        quote="What moment do they want to preserve?"
      />

      <div className="flex flex-wrap gap-2 mb-6">
        {leadStatuses.map((s) => (
          <span key={s} className="text-xs px-3 py-1.5 rounded-full bg-muted text-muted-foreground border border-border">
            {s}
          </span>
        ))}
      </div>

      <div className="grid lg:grid-cols-2 gap-5">
        {leads.map((l) => (
          <Card key={l.id} className="p-6">
            <div className="flex items-start justify-between gap-3">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{l.id} · {l.source}</div>
                <h3 className="font-serif text-xl text-primary mt-1">{l.parent}</h3>
                <div className="text-xs text-muted-foreground mt-0.5">{l.city} · {l.phone} · {l.email}</div>
              </div>
              <StatusPill tone={toneFor(l.status) as never}>{l.status}</StatusPill>
            </div>

            <div className="mt-4 rounded-xl bg-[var(--gradient-warm)] px-4 py-3">
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground">The moment they want to preserve</div>
              <p className="font-serif text-base text-primary mt-1 italic">“{l.memoryGoal}”</p>
            </div>

            <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
              <Field k="Session type" v={l.sessionType} />
              <Field k="Baby age / pregnancy" v={l.babyAge} />
              <Field k="Preferred date" v={l.preferredDate} />
              <Field k="Location" v={l.location} />
              <Field k="Package interest" v={l.package} />
              <Field k="Budget comfort" v={l.budget} />
              <Field k="Follow-up date" v={l.followUp} />
            </dl>

            <MemoryProfileCard ownerType="lead" ownerId={l.id} defaultGoal={l.memoryGoal} />

            <div className="mt-5 pt-4 border-t border-border flex flex-wrap items-center gap-2">
              <select
                value={l.status}
                onChange={(e) => handle(setLeadStatus(l.id, e.target.value as LeadStatus))}
                className="text-xs bg-muted text-primary border border-border rounded-lg px-2.5 py-1.5"
              >
                {leadStatuses.map((s) => <option key={s}>{s}</option>)}
              </select>

              {l.convertedClientId ? (
                <button
                  onClick={() => navigate({ to: "/clients" })}
                  className="ml-auto inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-accent text-primary border border-gold"
                >
                  Linked → {l.convertedClientId} <ArrowRight className="h-3 w-3" />
                </button>
              ) : (
                <>
                  <button
                    onClick={() => {
                      const r = convertLeadToClient(l.id);
                      handle(r);
                    }}
                    className="ml-auto inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground hover:opacity-90"
                  >
                    <UserPlus className="h-3 w-3" /> Convert to client
                  </button>
                  <button
                    onClick={() => {
                      const r = convertLeadToClient(l.id);
                      if (r.ok && r.clientId) {
                        const b = createBookingForClient(r.clientId, {
                          category: l.sessionType,
                          city: l.city,
                          locationType: l.location,
                          date: `${l.preferredDate} 10:00`,
                          package: l.package,
                        });
                        handle(b);
                        if (b.ok) navigate({ to: "/bookings" });
                      } else handle(r);
                    }}
                    className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-[var(--gradient-gold)] text-primary"
                  >
                    Convert + book
                  </button>
                </>
              )}
            </div>
          </Card>
        ))}
        {leads.length === 0 && (
          <Card className="p-10 text-center col-span-full">
            <p className="font-serif text-xl text-primary">No inquiries yet.</p>
            <p className="text-sm text-muted-foreground mt-2">The next message could be a memory in waiting.</p>
          </Card>
        )}
      </div>
    </AppShell>
  );
}

function Field({ k, v }: { k: string; v: string }) {
  return (
    <div>
      <dt className="text-[10px] uppercase tracking-wider text-muted-foreground">{k}</dt>
      <dd className="text-primary">{v}</dd>
    </div>
  );
}