import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { privacyOptions } from "@/lib/mock-data";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";
import { ShieldAlert } from "lucide-react";
import { useState } from "react";

export const Route = createFileRoute("/_authenticated/privacy")({
  head: () => ({
    meta: [
      { title: "Privacy & Consent · Little Moments OS" },
      { name: "description", content: "Written consent tracking so no family image is ever shared without permission." },
      { property: "og:title", content: "Privacy & Consent · Little Moments OS" },
      { property: "og:description", content: "Written consent tracking so no family image is ever shared without permission." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: PrivacyPage,
});

function PrivacyPage() {
  const bookings = useStore((s) => s.bookings);
  const privacy = useStore((s) => s.privacy);
  const recordPrivacy = useStore((s) => s.recordPrivacy);
  const pending = bookings.filter((b) => !privacy.find((p) => p.bookingId === b.id));

  return (
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

      {pending.length > 0 && (
        <>
          <h2 className="font-serif text-xl text-primary mb-3">Bookings awaiting consent</h2>
          <div className="space-y-4 mb-8">
            {pending.map((b) => (
              <RecordForm key={b.id} bookingId={b.id} client={b.client} onSave={(rec) => handle(recordPrivacy(rec))} />
            ))}
          </div>
        </>
      )}

      <h2 className="font-serif text-xl text-primary mb-3">Recorded consents</h2>
      <div className="space-y-4">
        {privacy.length === 0 && (
          <Card className="p-8 text-center">
            <p className="text-sm text-muted-foreground">No consents recorded yet.</p>
          </Card>
        )}
        {privacy.map((p) => (
          <Card key={p.id} className="p-5">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{p.id} · Booking {p.bookingId}</div>
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
  );
}

function RecordForm({
  bookingId,
  client,
  onSave,
}: {
  bookingId: string;
  client: string;
  onSave: (rec: {
    bookingId: string;
    client: string;
    consent: string;
    date: string;
    platforms: string;
    images: string;
    confirmed: boolean;
    recordedBy: string;
  }) => void;
}) {
  const [consent, setConsent] = useState<string>(privacyOptions[0]);
  const [platforms, setPlatforms] = useState("");
  const [images, setImages] = useState("");
  const [confirmed, setConfirmed] = useState(false);
  const [recordedBy, setRecordedBy] = useState("Hema");

  return (
    <Card className="p-5">
      <div className="flex items-start justify-between mb-3">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">Booking {bookingId}</div>
          <h3 className="font-serif text-lg text-primary mt-1">{client}</h3>
        </div>
        <StatusPill tone="bad">Awaiting consent</StatusPill>
      </div>
      <div className="grid md:grid-cols-2 gap-3">
        <label className="text-xs">
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-1">Consent type</div>
          <select value={consent} onChange={(e) => setConsent(e.target.value)} className="w-full border border-border rounded-lg bg-card px-3 py-2 text-sm text-primary">
            {privacyOptions.map((o) => <option key={o}>{o}</option>)}
          </select>
        </label>
        <label className="text-xs">
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-1">Approved platforms</div>
          <input value={platforms} onChange={(e) => setPlatforms(e.target.value)} placeholder="Instagram, Portfolio…" className="w-full border border-border rounded-lg bg-card px-3 py-2 text-sm text-primary" />
        </label>
        <label className="text-xs md:col-span-2">
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-1">Approved image IDs / notes</div>
          <input value={images} onChange={(e) => setImages(e.target.value)} placeholder="e.g. frames 04, 11, 23 — or 'all images private'" className="w-full border border-border rounded-lg bg-card px-3 py-2 text-sm text-primary" />
        </label>
        <label className="text-xs">
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-1">Recorded by</div>
          <input value={recordedBy} onChange={(e) => setRecordedBy(e.target.value)} className="w-full border border-border rounded-lg bg-card px-3 py-2 text-sm text-primary" />
        </label>
        <label className="text-xs flex items-center gap-2 mt-5">
          <input type="checkbox" checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} className="accent-[var(--gold)]" />
          <span className="text-primary">Parent confirmed consent in writing</span>
        </label>
      </div>
      <button
        onClick={() =>
          onSave({
            bookingId,
            client,
            consent,
            date: new Date().toISOString().slice(0, 10),
            platforms: platforms || "—",
            images: images || "—",
            confirmed,
            recordedBy,
          })
        }
        className="mt-4 inline-flex text-sm px-4 py-2 rounded-lg bg-primary text-primary-foreground hover:opacity-90"
      >
        Save consent
      </button>
    </Card>
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