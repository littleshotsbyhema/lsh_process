import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore, alignmentDimensions, bookingAlignment } from "@/store/useStore";
import { governanceChecklists, type GovernanceCadence } from "@/lib/mock-data";
import { toast } from "sonner";
import { CheckCircle2 } from "lucide-react";

export const Route = createFileRoute("/_authenticated/governance")({
  head: () => ({
    meta: [
      { title: "Governance · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Daily, weekly, monthly and quarterly governance runs plus philosophy alignment scoring.",
      },
      { property: "og:title", content: "Governance · LittleShots by Hema OS" },
      {
        property: "og:description",
        content:
          "Daily, weekly, monthly and quarterly governance runs plus philosophy alignment scoring.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: GovernancePage,
});

const cadences: GovernanceCadence[] = ["daily", "weekly", "monthly", "quarterly"];

function GovernancePage() {
  const { bookings, alignment, governance, saveGovernanceRun, setAlignmentScore } = useStore();
  const [state, setState] = useState<Record<string, Record<string, boolean>>>({});

  const monthlyAvg = (() => {
    if (!alignment.length) return 0;
    const sums = alignment.map((a) => bookingAlignment(a.bookingId, alignment));
    return Math.round((sums.reduce((a, b) => a + b, 0) / sums.length) * 10) / 10;
  })();

  return (
    <AppShell>
      <PageHeader
        eyebrow="Phase 8 · Governance & Philosophy Alignment"
        title="Governance Dashboard"
        subtitle="Rhythms that keep the studio aligned with the families we serve."
        quote="Discipline is how love stays consistent."
      />

      <section className="grid md:grid-cols-2 gap-5 mb-8">
        {cadences.map((cad) => {
          const items = governanceChecklists[cad];
          const local = state[cad] ?? {};
          const done = Object.values(local).filter(Boolean).length;
          const lastRun = governance.find((g) => g.cadence === cad);
          return (
            <Card key={cad} className="p-5">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                    {cad} checklist
                  </div>
                  <h3 className="font-serif text-xl text-primary capitalize mt-1">{cad}</h3>
                </div>
                <StatusPill tone={done === items.length ? "good" : "warn"}>
                  {done}/{items.length}
                </StatusPill>
              </div>
              <ul className="mt-4 space-y-2">
                {items.map((it) => (
                  <li key={it} className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={!!local[it]}
                      onChange={(e) =>
                        setState((s) => ({ ...s, [cad]: { ...s[cad], [it]: e.target.checked } }))
                      }
                    />
                    <span className="text-foreground/85">{it}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-4 flex items-center justify-between">
                <p className="text-[11px] text-muted-foreground">
                  {lastRun
                    ? `Last run: ${lastRun.date} by ${lastRun.completedBy}`
                    : "No run logged yet"}
                </p>
                <button
                  onClick={() => {
                    const r = saveGovernanceRun(cad, local);
                    if (r.ok) toast.success(r.message);
                  }}
                  className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground hover:opacity-90 inline-flex items-center gap-1.5"
                >
                  <CheckCircle2 className="h-3.5 w-3.5" /> Save run
                </button>
              </div>
            </Card>
          );
        })}
      </section>

      <Card className="p-6">
        <div className="flex items-end justify-between mb-5">
          <div>
            <h2 className="font-serif text-xl text-primary">Philosophy Alignment Score</h2>
            <p className="text-sm text-muted-foreground">
              Score each booking 1–5 across six dimensions.
            </p>
          </div>
          <div>
            <div className="text-[11px] uppercase tracking-wider text-muted-foreground text-right">
              Studio average
            </div>
            <div className="font-serif text-3xl text-primary">{monthlyAvg || "—"} / 5</div>
          </div>
        </div>

        {bookings.length === 0 ? (
          <p className="text-sm italic text-muted-foreground">No bookings yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-[11px] uppercase tracking-wider text-muted-foreground border-b border-border">
                  <th className="py-2 pr-3">Booking</th>
                  {alignmentDimensions.map((d) => (
                    <th key={d} className="py-2 px-2">
                      {d}
                    </th>
                  ))}
                  <th className="py-2 pl-2 text-right">Avg</th>
                </tr>
              </thead>
              <tbody>
                {bookings.map((b) => {
                  const rec = alignment.find((a) => a.bookingId === b.id);
                  const avg = bookingAlignment(b.id, alignment);
                  return (
                    <tr key={b.id} className="border-b border-border/60">
                      <td className="py-2 pr-3">
                        <div className="font-medium text-primary">{b.client}</div>
                        <div className="text-[11px] text-muted-foreground">
                          {b.id} · {b.category}
                        </div>
                      </td>
                      {alignmentDimensions.map((d) => (
                        <td key={d} className="py-2 px-2">
                          <select
                            value={rec?.scores[d] ?? ""}
                            onChange={(e) => {
                              if (e.target.value)
                                setAlignmentScore(b.id, d, Number(e.target.value));
                            }}
                            className="w-16 rounded border border-border bg-card px-1.5 py-1 text-xs"
                          >
                            <option value="">—</option>
                            {[1, 2, 3, 4, 5].map((n) => (
                              <option key={n} value={n}>
                                {n}
                              </option>
                            ))}
                          </select>
                        </td>
                      ))}
                      <td className="py-2 pl-2 text-right">
                        <StatusPill
                          tone={avg >= 4 ? "good" : avg >= 3 ? "warn" : avg ? "bad" : "neutral"}
                        >
                          {avg || "—"}
                        </StatusPill>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </AppShell>
  );
}
