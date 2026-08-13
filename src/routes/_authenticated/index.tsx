import { createFileRoute, Link } from "@tanstack/react-router";
import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { visibleNav } from "@/lib/access";
import { useSession } from "@/lib/session";

export const Route = createFileRoute("/_authenticated/")({
  head: () => ({
    meta: [
      { title: "Studio Control Room · Little Moments OS" },
      {
        name: "description",
        content: "Canonical operating rooms for Little Shots by Hema.",
      },
      {
        property: "og:title",
        content: "Studio Control Room · Little Moments OS",
      },
      {
        property: "og:description",
        content: "Because these little moments become everything.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Index,
});

const canonicalRoomPaths = new Set([
  "/leads",
  "/guide-reviews",
  "/clients",
  "/memory",
  "/packages",
  "/quote",
  "/bookings",
  "/pipeline",
  "/whatsapp",
]);

function Index() {
  const { roles } = useSession();

  const rooms = visibleNav(roles).filter((item) => canonicalRoomPaths.has(item.to));

  return (
    <AppShell>
      <PageHeader
        eyebrow="Little Shots Studio OS"
        title="Studio Control Room"
        subtitle="A calm starting point for the studio records that are connected to the canonical operating system."
        quote="Because these little moments become everything."
      />

      <Card className="mb-8 p-6 bg-[var(--gradient-warm)]">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Current operating boundary
        </div>

        <h2 className="mt-2 font-serif text-xl text-primary">Canonical records only</h2>

        <p className="mt-3 max-w-3xl text-sm leading-relaxed text-muted-foreground">
          Packages, quotations, bookings, and the family journey now use the rebuilt studio records.
          Later workflow rooms remain unavailable until they are connected to the same source of
          truth.
        </p>

        <p className="mt-3 max-w-3xl text-xs leading-relaxed text-muted-foreground">
          This dashboard intentionally does not calculate revenue, payment, safety, consent,
          delivery, review, or production metrics from legacy demonstration data.
        </p>
      </Card>

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {rooms.map(({ to, label, icon: Icon }) => (
          <Link key={to} to={to}>
            <Card className="h-full p-5 transition-transform hover:-translate-y-0.5">
              <div className="flex items-start gap-4">
                <div className="rounded-full bg-accent p-2.5">
                  <Icon className="h-4 w-4 text-primary" />
                </div>

                <div>
                  <div className="font-serif text-lg text-primary">{label}</div>
                  <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                    Open the current studio record.
                  </p>
                </div>
              </div>
            </Card>
          </Link>
        ))}
      </section>
    </AppShell>
  );
}
