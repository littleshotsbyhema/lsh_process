import { createFileRoute, Link } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";

export const Route = createFileRoute("/_authenticated/prep")({
  head: () => ({
    meta: [
      { title: "Shoot Prep · LittleShots by Hema OS" },
      {
        name: "description",
        content: "Shoot-day preparation: props, styling, comfort plans and the team call sheet.",
      },
      { property: "og:title", content: "Shoot Prep · LittleShots by Hema OS" },
      {
        property: "og:description",
        content: "Shoot-day preparation: props, styling, comfort plans and the team call sheet.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: PrepPage,
});

function PrepPage() {
  const { bookings, memoryProfiles } = useStore();
  const upcoming = bookings
    .filter((b) => ["Confirmed", "Pre-Shoot Prep"].includes(b.status))
    .sort((a, b) => a.date.localeCompare(b.date));

  return (
    <AppShell>
      <PageHeader
        eyebrow="Pre-Shoot Preparation"
        title="Shoot Prep"
        subtitle="Every shoot begins calm. Comfort is the first frame."
        quote="What we prepare the night before becomes the joy of the morning."
      />
      {upcoming.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">No shoots in prep right now.</p>
          <p className="mt-2 text-sm italic text-primary/70">A quiet moment to refine our craft.</p>
        </Card>
      ) : (
        <div className="space-y-4">
          {upcoming.map((b) => {
            const mp = memoryProfiles.find(
              (m) =>
                (m.ownerType === "booking" && m.ownerId === b.id) ||
                (b.clientId && m.ownerType === "client" && m.ownerId === b.clientId),
            );
            return (
              <Card key={b.id} className="p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="font-medium text-primary">{b.client}</div>
                    <div className="text-xs text-muted-foreground">
                      {b.category} · {b.date} · {b.locationType} · {b.locationDetails}
                    </div>
                  </div>
                  <div className="flex gap-1.5">
                    <StatusPill tone={b.safety === "Completed" ? "good" : "warn"}>
                      Safety: {b.safety}
                    </StatusPill>
                    <StatusPill tone={mp ? "good" : "bad"}>
                      Memory: {mp ? "Captured" : "Missing"}
                    </StatusPill>
                  </div>
                </div>
                <ul className="mt-4 grid md:grid-cols-2 gap-1.5 text-sm">
                  <li>· Confirm location & timing 48h before</li>
                  <li>· Confirm comfort needs with family</li>
                  <li>· Review Memory Profile aloud with team</li>
                  <li>· Print safety checklist for {b.category}</li>
                  {b.category === "Newborn" && <li>· Spotter assigned + sanitised wraps</li>}
                  {b.category === "Maternity" && <li>· Confirm makeup sensitivities</li>}
                </ul>
                <div className="mt-4 flex gap-2">
                  <Link
                    to="/safety"
                    className="text-xs px-3 py-1.5 rounded-lg border border-gold bg-card text-primary hover:bg-accent"
                  >
                    Safety checklist →
                  </Link>
                  <Link
                    to="/memory"
                    className="text-xs px-3 py-1.5 rounded-lg border border-border bg-card text-primary hover:bg-accent"
                  >
                    Memory profile →
                  </Link>
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </AppShell>
  );
}
