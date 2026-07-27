import { createFileRoute, Link } from "@tanstack/react-router";
import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { MemoryProfileCard } from "@/components/MemoryProfileCard";
import { Heart } from "lucide-react";

export const Route = createFileRoute("/_authenticated/memory")({
  head: () => ({ meta: [{ title: "Memory Profiles · Little Moments OS" }] }),
  component: MemoryProfilesPage,
});

function MemoryProfilesPage() {
  const leads = useStore((s) => s.leads);
  const bookings = useStore((s) => s.bookings);
  const profiles = useStore((s) => s.memoryProfiles);

  const captured = profiles.length;
  const total = leads.length + bookings.length;
  const pct = total ? Math.round((captured / total) * 100) : 0;

  return (
    <AppShell>
      <PageHeader
        eyebrow="The story behind the shoot"
        title="Memory Profiles"
        subtitle="The emotional brief for every family — so the photographer, editor, and album designer protect the right moments."
        quote="What moment do they want to preserve?"
      />

      <Card className="p-5 mb-6 bg-[var(--gradient-warm)] border-0">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-3">
            <span className="rounded-full bg-card p-2.5">
              <Heart className="h-4 w-4 text-gold" />
            </span>
            <div>
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Memory coverage
              </div>
              <div className="font-serif text-2xl text-primary">
                {captured} of {total} captured · {pct}%
              </div>
            </div>
          </div>
          <p className="text-xs italic text-primary/70 max-w-md">
            Every captured profile is a promise the team can keep.
          </p>
        </div>
      </Card>

      <section className="space-y-6">
        <div>
          <h2 className="font-serif text-xl text-primary mb-3">From Leads</h2>
          <div className="grid lg:grid-cols-2 gap-4">
            {leads.map((l) => (
              <Card key={l.id} className="p-5">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                      {l.id} · {l.sessionType}
                    </div>
                    <Link
                      to="/leads"
                      className="font-serif text-lg text-primary hover:underline"
                    >
                      {l.parent}
                    </Link>
                  </div>
                </div>
                <MemoryProfileCard
                  ownerType="lead"
                  ownerId={l.id}
                  defaultGoal={l.memoryGoal}
                />
              </Card>
            ))}
          </div>
        </div>

        <div>
          <h2 className="font-serif text-xl text-primary mb-3">From Bookings</h2>
          <div className="grid lg:grid-cols-2 gap-4">
            {bookings.map((b) => (
              <Card key={b.id} className="p-5">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                      {b.id} · {b.category}
                    </div>
                    <Link
                      to="/bookings"
                      className="font-serif text-lg text-primary hover:underline"
                    >
                      {b.client}
                    </Link>
                  </div>
                </div>
                <MemoryProfileCard ownerType="booking" ownerId={b.id} />
              </Card>
            ))}
          </div>
        </div>
      </section>
    </AppShell>
  );
}