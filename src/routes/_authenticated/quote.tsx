import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { packageTiers } from "@/lib/mock-data";

export const Route = createFileRoute("/_authenticated/quote")({
  head: () => ({
    meta: [
      { title: "Quote Builder · Little Moments OS" },
      {
        name: "description",
        content: "Build warm, clear quotes with packages, add-ons and advance payment terms.",
      },
      { property: "og:title", content: "Quote Builder · Little Moments OS" },
      {
        property: "og:description",
        content: "Build warm, clear quotes with packages, add-ons and advance payment terms.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: QuoteBuilder,
});

function QuoteBuilder() {
  const [client, setClient] = useState("");
  const [tier, setTier] = useState(packageTiers[1].tier);
  const [price, setPrice] = useState(49500);
  const [offer, setOffer] = useState(49500);
  const [addOns, setAddOns] = useState("");
  const selected = packageTiers.find((p) => p.tier === tier)!;

  return (
    <AppShell>
      <PageHeader
        eyebrow="Quote Builder"
        title="Build a warm, clear quote"
        subtitle="Premium without pressure. Every line item earns its place."
        quote="A quote is a promise of care, written in numbers."
      />

      <div className="grid lg:grid-cols-2 gap-6">
        <Card className="p-6 space-y-4">
          <Field label="Client name">
            <input value={client} onChange={(e) => setClient(e.target.value)} className="input" />
          </Field>
          <Field label="Package">
            <select
              value={tier}
              onChange={(e) => setTier(e.target.value as typeof tier)}
              className="input"
            >
              {packageTiers.map((p) => (
                <option key={p.tier} value={p.tier}>
                  {p.tier} — {p.name}
                </option>
              ))}
            </select>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="List price (₹)">
              <input
                type="number"
                value={price}
                onChange={(e) => setPrice(Number(e.target.value))}
                className="input"
              />
            </Field>
            <Field label="Offer price (₹)">
              <input
                type="number"
                value={offer}
                onChange={(e) => setOffer(Number(e.target.value))}
                className="input"
              />
            </Field>
          </div>
          <Field label="Add-ons">
            <input
              value={addOns}
              onChange={(e) => setAddOns(e.target.value)}
              placeholder="Album, frame, reel…"
              className="input"
            />
          </Field>
        </Card>

        <Card className="p-6 bg-[var(--gradient-warm)] border-0">
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Quote preview
          </div>
          <h3 className="mt-2 font-serif text-2xl text-primary">{selected.name}</h3>
          <p className="text-sm italic text-primary/80 mt-1">{selected.blurb}</p>
          <ul className="mt-4 space-y-1.5 text-sm">
            {selected.includes.map((i) => (
              <li key={i}>· {i}</li>
            ))}
            {addOns && <li>· {addOns}</li>}
          </ul>
          <div className="mt-6 border-t border-border pt-4 flex items-end justify-between">
            <div>
              <div className="text-xs text-muted-foreground line-through">
                ₹{price.toLocaleString("en-IN")}
              </div>
              <div className="font-serif text-3xl text-primary">
                ₹{offer.toLocaleString("en-IN")}
              </div>
            </div>
            <div className="text-xs text-muted-foreground italic">
              For {client || "your family"}
            </div>
          </div>
        </Card>
      </div>
    </AppShell>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</span>
      <div className="mt-1.5">{children}</div>
      <style>{`.input{width:100%;border:1px solid var(--border);border-radius:0.5rem;background:var(--card);padding:0.5rem 0.75rem;font-size:0.875rem;color:var(--foreground);}`}</style>
    </label>
  );
}
