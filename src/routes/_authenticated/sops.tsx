import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { sops } from "@/lib/mock-data";
import { BookOpen } from "lucide-react";

export const Route = createFileRoute("/_authenticated/sops")({
  head: () => ({
    meta: [
      { title: "SOP Center · Little Moments OS" },
      { name: "description", content: "Read-only standard operating procedures that keep studio care consistent." },
      { property: "og:title", content: "SOP Center · Little Moments OS" },
      { property: "og:description", content: "Read-only standard operating procedures that keep studio care consistent." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SOPsPage,
});

function SOPsPage() {
  return (
    <AppShell>
      <PageHeader
        eyebrow="How we hold every family"
        title="SOP Center"
        subtitle="Read-only standard operating practices for every chapter of the journey."
        quote="Process is how love becomes reliable."
      />

      <div className="grid md:grid-cols-2 gap-5">
        {sops.map((s) => (
          <Card key={s.id} className="p-6">
            <div className="flex items-start gap-3">
              <span className="mt-1 rounded-full bg-[var(--gradient-warm)] p-2">
                <BookOpen className="h-4 w-4 text-gold" />
              </span>
              <div className="flex-1 min-w-0">
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{s.id}</div>
                <h3 className="font-serif text-xl text-primary mt-0.5">{s.title}</h3>
                <p className="text-sm italic text-primary/80 mt-1">{s.summary}</p>
                <ol className="mt-3 space-y-1.5 list-decimal list-inside text-sm text-primary/90">
                  {s.steps.map((step) => (
                    <li key={step}>{step}</li>
                  ))}
                </ol>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </AppShell>
  );
}