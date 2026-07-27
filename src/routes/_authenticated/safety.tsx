import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { safetyChecklists } from "@/lib/mock-data";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";
import { ShieldCheck } from "lucide-react";
import { useMemo, useState } from "react";

export const Route = createFileRoute("/_authenticated/safety")({
  head: () => ({
    meta: [
      { title: "Safety & Comfort · Little Moments OS" },
      { name: "description", content: "Newborn, maternity and sitter safety and comfort checklists completed before every shoot." },
      { property: "og:title", content: "Safety & Comfort · Little Moments OS" },
      { property: "og:description", content: "Newborn, maternity and sitter safety and comfort checklists completed before every shoot." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SafetyPage,
});

type Category = keyof typeof safetyChecklists;

function categoryFor(sessionType: string): Category {
  if (sessionType === "Newborn") return "Newborn";
  if (sessionType === "Maternity") return "Maternity";
  return "Sitter / Baby / Child";
}

function SafetyPage() {
  const bookings = useStore((s) => s.bookings);
  const submitSafety = useStore((s) => s.submitSafety);
  const pending = bookings.filter((b) => b.safety === "Pending");

  return (
    <AppShell>
      <PageHeader
        eyebrow="Comfort & care"
        title="Safety & Comfort Checklists"
        subtitle="No shoot can be marked complete until the relevant safety checklist is submitted."
        quote="A child's comfort is never traded for a better frame."
      />

      <h2 className="font-serif text-xl text-primary mb-3">Bookings awaiting safety sign-off</h2>
      {pending.length === 0 ? (
        <Card className="p-8 text-center mb-8">
          <p className="text-sm text-muted-foreground">All current bookings have a completed safety checklist. Beautifully done.</p>
        </Card>
      ) : (
        <div className="space-y-5 mb-10">
          {pending.map((b) => (
            <ChecklistCard
              key={b.id}
              bookingId={b.id}
              client={b.client}
              category={categoryFor(b.category)}
              onSubmit={(items) =>
                handle(submitSafety({ bookingId: b.id, category: categoryFor(b.category), items, submittedBy: "Hema" }))
              }
            />
          ))}
        </div>
      )}

      <h2 className="font-serif text-xl text-primary mb-3">Checklist templates</h2>
      <div className="grid lg:grid-cols-3 gap-5">
        {(Object.entries(safetyChecklists) as [Category, readonly string[]][]).map(([category, items]) => (
          <Card key={category} className="p-6">
            <div className="flex items-center gap-2 mb-3">
              <ShieldCheck className="h-4 w-4 text-gold" />
              <h3 className="font-serif text-xl text-primary">{category}</h3>
            </div>
            <ul className="space-y-2 text-sm text-primary">
              {items.map((i) => (
                <li key={i} className="flex items-start gap-2">
                  <span className="text-gold">•</span>
                  <span>{i}</span>
                </li>
              ))}
            </ul>
          </Card>
        ))}
      </div>
    </AppShell>
  );
}

function ChecklistCard({
  bookingId,
  client,
  category,
  onSubmit,
}: {
  bookingId: string;
  client: string;
  category: Category;
  onSubmit: (items: Record<string, boolean>) => void;
}) {
  const items = safetyChecklists[category];
  const [state, setState] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(items.map((i) => [i, false])),
  );
  const done = useMemo(() => Object.values(state).filter(Boolean).length, [state]);

  return (
    <Card className="p-6">
      <div className="flex items-start justify-between mb-4">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">Booking {bookingId} · {category}</div>
          <h3 className="font-serif text-lg text-primary mt-1">{client}</h3>
        </div>
        <StatusPill tone={done === items.length ? "good" : "warn"}>{done} / {items.length}</StatusPill>
      </div>
      <ul className="space-y-2.5">
        {items.map((i) => (
          <li key={i} className="flex items-start gap-2.5 text-sm text-primary">
            <input
              type="checkbox"
              checked={state[i] ?? false}
              onChange={(e) => setState((s) => ({ ...s, [i]: e.target.checked }))}
              className="mt-0.5 accent-[var(--gold)]"
            />
            <span>{i}</span>
          </li>
        ))}
      </ul>
      <button
        onClick={() => onSubmit(state)}
        className="mt-5 w-full rounded-lg bg-primary text-primary-foreground text-sm py-2.5 hover:opacity-90 transition"
      >
        Submit checklist
      </button>
    </Card>
  );
}
