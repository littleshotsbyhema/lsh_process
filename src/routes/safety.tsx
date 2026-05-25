import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { safetyChecklists } from "@/lib/mock-data";
import { ShieldCheck } from "lucide-react";

export const Route = createFileRoute("/safety")({
  head: () => ({ meta: [{ title: "Safety & Comfort · Little Moments OS" }] }),
  component: () => (
    <AppShell>
      <PageHeader
        eyebrow="Comfort & care"
        title="Safety & Comfort Checklists"
        subtitle="No shoot can be marked complete until the relevant safety checklist is submitted."
        quote="A child's comfort is never traded for a better frame."
      />

      <div className="grid lg:grid-cols-3 gap-5">
        {(Object.entries(safetyChecklists) as [keyof typeof safetyChecklists, readonly string[]][]).map(
          ([category, items]) => (
            <Card key={category} className="p-6">
              <div className="flex items-center gap-2 mb-3">
                <ShieldCheck className="h-4 w-4 text-gold" />
                <h3 className="font-serif text-xl text-primary">{category}</h3>
              </div>
              <ul className="space-y-2.5">
                {items.map((i) => (
                  <li key={i} className="flex items-start gap-2.5 text-sm text-primary">
                    <input type="checkbox" className="mt-0.5 accent-[var(--gold)]" />
                    <span>{i}</span>
                  </li>
                ))}
              </ul>
              <button className="mt-5 w-full rounded-lg bg-primary text-primary-foreground text-sm py-2.5 hover:opacity-90 transition">
                Submit checklist
              </button>
            </Card>
          ),
        )}
      </div>
    </AppShell>
  ),
});
