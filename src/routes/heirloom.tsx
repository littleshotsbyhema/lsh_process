import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { heirloomJobs } from "@/lib/mock-data";
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

export const Route = createFileRoute("/heirloom")({
  head: () => ({ meta: [{ title: "Heirloom Production · Little Moments OS" }] }),
  component: () => (
    <AppShell>
      <PageHeader
        eyebrow="Heirloom"
        title="Heirloom Production"
        subtitle="Not albums. Not frames. Heirlooms — objects this family will hold for thirty years."
        quote="If it isn't worthy of a shelf in their home, it isn't ready to leave ours."
      />

      <div className="grid lg:grid-cols-3 gap-5 mb-8">
        {heirloomJobs.map((h) => {
          const steps = [
            ["Album proof sent", h.proof !== "—"],
            ["Client approved", h.approved],
            ["Sent to production", h.sentToProduction],
            ["Production completed", h.produced],
            ["QC completed", h.qc === "Passed"],
            ["Packed", h.packed],
            ["Ready for collection", h.ready],
            ["Delivered / collected", h.delivered],
          ] as const;
          return (
            <Card key={h.id} className="p-6">
              <div className="flex items-start justify-between">
                <div>
                  <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{h.id} · {h.booking}</div>
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
                {steps.map(([label, done]) => (
                  <li key={label} className="flex items-center gap-2 text-sm">
                    {done ? (
                      <Check className="h-4 w-4 text-gold" />
                    ) : (
                      <Circle className="h-4 w-4 text-muted-foreground/40" />
                    )}
                    <span className={done ? "text-primary" : "text-muted-foreground"}>{label}</span>
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
  ),
});

function Mini({ k, v }: { k: string; v: string }) {
  return (
    <div className="rounded-lg bg-muted/60 px-3 py-2">
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{k}</div>
      <div className="text-primary">{v}</div>
    </div>
  );
}