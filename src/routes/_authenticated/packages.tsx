import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { packageTiers, sessionTypes } from "@/lib/mock-data";
import { useMemo, useState } from "react";

export const Route = createFileRoute("/_authenticated/packages")({
  head: () => ({ meta: [{ title: "Package Recommender · Little Moments OS" }] }),
  component: PackagesPage,
});

const goalOptions = [
  { id: "simple", label: "A simple, treasured memory" },
  { id: "connection", label: "Baby / mother + family connection" },
  { id: "album", label: "Album or fuller story to keep on the shelf" },
  { id: "legacy", label: "Cinematic reel, album, frame — full legacy" },
] as const;

function recommend(goal: string) {
  if (goal === "legacy") return "Emerald";
  if (goal === "album") return "Diamond";
  if (goal === "connection") return "Gold";
  return "Bronze";
}

function PackagesPage() {
  const [session, setSession] = useState<string>("Newborn");
  const [goal, setGoal] = useState<string>("connection");
  const recommended = useMemo(() => recommend(goal), [goal]);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Recommendation"
        title="Package Recommender"
        subtitle="Help families find the package that protects the moment they actually want to keep."
        quote="Sell the memory, never the megapixel."
      />

      <Card className="p-6 mb-8">
        <div className="grid md:grid-cols-2 gap-6">
          <div>
            <div className="text-[11px] uppercase tracking-wider text-muted-foreground mb-2">Session category</div>
            <div className="flex flex-wrap gap-2">
              {(["Maternity", "Newborn", "Sitter"] as const).map((s) => (
                <button
                  key={s}
                  onClick={() => setSession(s)}
                  className={`px-4 py-2 rounded-full text-sm border transition-all ${
                    session === s
                      ? "bg-primary text-primary-foreground border-primary"
                      : "bg-card text-primary border-border hover:bg-muted"
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              Categories shown: Maternity, Newborn, Sitter (also available for Baby, Child, Family).
            </p>
          </div>
          <div>
            <div className="text-[11px] uppercase tracking-wider text-muted-foreground mb-2">What does this family want to keep?</div>
            <div className="space-y-2">
              {goalOptions.map((g) => (
                <label
                  key={g.id}
                  className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm border cursor-pointer transition-all ${
                    goal === g.id ? "bg-accent border-gold" : "border-border hover:bg-muted"
                  }`}
                >
                  <input type="radio" name="goal" checked={goal === g.id} onChange={() => setGoal(g.id)} className="accent-[var(--gold)]" />
                  <span className="text-primary">{g.label}</span>
                </label>
              ))}
            </div>
          </div>
        </div>
      </Card>

      <div className="grid md:grid-cols-2 xl:grid-cols-4 gap-5">
        {packageTiers.map((p) => {
          const isRec = p.tier === recommended;
          return (
            <Card
              key={p.tier}
              className={`p-6 relative ${isRec ? "border-gold ring-2 ring-[oklch(0.85_0.08_80)] bg-[var(--gradient-warm)]" : ""}`}
            >
              {isRec && (
                <span className="absolute -top-3 left-6 bg-[var(--gradient-gold)] text-primary text-[10px] uppercase tracking-wider px-3 py-1 rounded-full shadow-[var(--shadow-soft)]">
                  Recommended
                </span>
              )}
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{p.tier}</div>
              <h3 className="font-serif text-2xl text-primary mt-1">{p.name}</h3>
              <p className="text-sm text-primary/80 italic mt-2">{p.blurb}</p>
              <p className="text-xs text-muted-foreground mt-3">Best for: {p.fitFor}</p>
              <ul className="mt-4 space-y-1.5 text-sm text-primary">
                {p.includes.map((i) => (
                  <li key={i} className="flex gap-2"><span className="text-gold">•</span>{i}</li>
                ))}
              </ul>
              <div className="mt-4 pt-4 border-t border-border text-[10px] uppercase tracking-wider text-muted-foreground">
                Available for {session}
              </div>
            </Card>
          );
        })}
      </div>

      <p className="text-[11px] text-muted-foreground mt-6">
        Session categories supported in the engine: {sessionTypes.join(" · ")}.
      </p>
    </AppShell>
  );
}