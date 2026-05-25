import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { leads, leadStatuses } from "@/lib/mock-data";

export const Route = createFileRoute("/leads")({
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
          </Card>
        ))}
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