import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";
import { Check, Circle } from "lucide-react";

const qcChecklist = [
  "Correct images",
  "Correct album size",
  "Correct page count",
  "Correct frame size",
  "Print quality checked",
  "Damage check completed",
  "Packaging completed",
];

export const Route = createFileRoute("/_authenticated/heirloom")({
  head: () => ({
    meta: [
      { title: "Heirloom Production · LittleShots by Hema OS" },
      {
        name: "description",
        content: "Album and frame production tracking from selection approval to hand-over.",
      },
      { property: "og:title", content: "Heirloom Production · LittleShots by Hema OS" },
      {
        property: "og:description",
        content: "Album and frame production tracking from selection approval to hand-over.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: HeirloomPage,
});

function HeirloomPage() {
  const heirloom = useStore((s) => s.heirloom);
  const advance = useStore((s) => s.advanceHeirloom);
  const passQC = useStore((s) => s.passHeirloomQC);
  return (
    <AppShell>
      <PageHeader
        eyebrow="Heirloom"
        title="Heirloom Production"
        subtitle="Not albums. Not frames. Heirlooms — objects this family will hold for thirty years."
        quote="If it isn't worthy of a shelf in their home, it isn't ready to leave ours."
      />

      {heirloom.length === 0 && (
        <Card className="p-10 text-center mb-8">
          <p className="font-serif text-xl text-primary">No heirlooms in production.</p>
          <p className="text-sm text-muted-foreground mt-2">
            Start one from a booking once album / frame selections are confirmed.
          </p>
        </Card>
      )}

      <div className="grid lg:grid-cols-3 gap-5 mb-8">
        {heirloom.map((h) => {
          const steps = [
            ["proofSent", "Album proof sent", h.proofSent],
            ["approved", "Client approved", h.approved],
            ["sentToProduction", "Sent to production", h.sentToProduction],
            ["produced", "Production completed", h.produced],
            ["qc", "QC completed", h.qc === "Passed"],
            ["packed", "Packed", h.packed],
            ["ready", "Ready for collection", h.ready],
            ["delivered", "Delivered / collected", h.delivered],
          ] as const;
          return (
            <Card key={h.id} className="p-6">
              <div className="flex items-start justify-between">
                <div>
                  <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                    {h.id} · {h.bookingId}
                  </div>
                  <h3 className="font-serif text-lg text-primary mt-1">{h.client}</h3>
                </div>
                <StatusPill tone={h.delivered ? "good" : h.ready ? "gold" : "warn"}>
                  {h.delivered ? "Delivered" : h.ready ? "Ready" : "In production"}
                </StatusPill>
              </div>

              <div className="mt-4 grid grid-cols-2 gap-2 text-xs">
                <Mini k="Album" v={`${h.albumSize} · ${h.pages}pg`} />
                <Mini k="Cover" v={h.cover} />
                <Mini k="Frame" v={h.frame} />
                <Mini k="Selected" v={h.selected} />
              </div>

              <ol className="mt-5 space-y-2">
                {steps.map(([key, label, done]) => (
                  <li key={key} className="flex items-center gap-2 text-sm">
                    {done ? (
                      <Check className="h-4 w-4 text-gold" />
                    ) : (
                      <Circle className="h-4 w-4 text-muted-foreground/40" />
                    )}
                    <span className={done ? "text-primary" : "text-muted-foreground"}>{label}</span>
                    {!done && (
                      <button
                        onClick={() =>
                          handle(key === "qc" ? passQC(h.id) : advance(h.id, key as never))
                        }
                        className="ml-auto text-[10px] px-2 py-0.5 rounded-full border border-border bg-muted text-primary hover:bg-accent"
                      >
                        Mark done
                      </button>
                    )}
                  </li>
                ))}
              </ol>
            </Card>
          );
        })}
      </div>

      <Card className="p-6">
        <h3 className="font-serif text-xl text-primary mb-3">QC checklist (every heirloom)</h3>
        <ul className="grid sm:grid-cols-2 gap-2.5">
          {qcChecklist.map((q) => (
            <li key={q} className="flex items-start gap-2.5 text-sm text-primary">
              <input type="checkbox" className="mt-0.5 accent-[var(--gold)]" />
              <span>{q}</span>
            </li>
          ))}
        </ul>
      </Card>
    </AppShell>
  );
}

function Mini({ k, v }: { k: string; v: string }) {
  return (
    <div className="rounded-lg bg-muted/60 px-3 py-2">
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{k}</div>
      <div className="text-primary">{v}</div>
    </div>
  );
}
