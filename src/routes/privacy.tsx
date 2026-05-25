import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { privacyOptions, privacyRecords } from "@/lib/mock-data";
import { ShieldAlert } from "lucide-react";

export const Route = createFileRoute("/privacy")({
  head: () => ({ meta: [{ title: "Privacy & Consent · Little Moments OS" }] }),
  component: () => (
    <AppShell>
      <PageHeader
        eyebrow="Trust"
        title="Privacy & Consent Tracker"
        subtitle="Trust is the most valuable thing a family gives us. We protect it before we use a single frame."
        quote="No image leaves this studio without written consent."
      />

      <Card className="p-5 mb-6 border-l-4 border-[oklch(0.7_0.18_25)] bg-[oklch(0.96_0.03_25)]">
        <div className="flex gap-3">
          <ShieldAlert className="h-5 w-5 text-[oklch(0.5_0.18_25)] mt-0.5" />
          <div>
            <div className="text-sm font-medium text-primary">Marketing rule</div>
            <p className="text-sm text-primary/80">
              Marketing use is <strong>blocked</strong> on every booking unless written consent is recorded here.
            </p>
          </div>
        </div>
      </Card>

      <Card className="p-6 mb-6">
        <div className="text-[11px] uppercase tracking-wider text-muted-foreground mb-3">Consent options</div>
        <div className="grid sm:grid-cols-2 gap-2">
          {privacyOptions.map((o) => (
            <div key={o} className="rounded-lg border border-border px-3 py-2 text-sm text-primary bg-muted/40">
              {o}
            </div>
          ))}
        </div>
      </Card>

      <div className="space-y-4">
        {privacyRecords.map((p) => (
          <Card key={p.id} className="p-5">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{p.id} · Booking {p.booking}</div>
                <h3 className="font-serif text-lg text-primary mt-1">{p.client}</h3>
              </div>
              <StatusPill tone={p.confirmed ? "good" : "bad"}>{p.confirmed ? "Confirmed in writing" : "Not confirmed"}</StatusPill>
            </div>
            <div className="mt-4 grid md:grid-cols-2 gap-3 text-sm">
              <F k="Consent type" v={p.consent} />
              <F k="Date of consent" v={p.date} />
              <F k="Approved platforms" v={p.platforms} />
              <F k="Approved images / notes" v={p.images} />
              <F k="Recorded by" v={p.recordedBy} />
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