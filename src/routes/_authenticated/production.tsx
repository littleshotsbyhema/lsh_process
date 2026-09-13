import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { availableModuleLinks } from "@/lib/access";
import { listBookingWorkspace } from "@/lib/booking.functions";

export const Route = createFileRoute("/_authenticated/production")({
  head: () => ({
    meta: [
      { title: "Production · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "A confirmed booking through preparation, the shoot itself and the family's selection.",
      },
      { property: "og:title", content: "Production · LittleShots by Hema OS" },
    ],
  }),
  component: ProductionPage,
});

/**
 * Production owns journey stages 8 to 12 — booking confirmed, pre-shoot
 * preparation, shoot scheduled, shoot completed, selection pending.
 *
 * The delivery workspace does not reach back this far: `DELIVERY_STAGE_ORDERS`
 * covers 13 to 21 only. So the counts below are read from the booking
 * workspace instead, and there is no stage board here yet.
 */
const PRODUCTION_STAGE_ORDERS = [8, 9, 10, 11, 12];

function ProductionPage() {
  const query = useQuery({
    queryKey: ["booking-workspace"],
    queryFn: () => listBookingWorkspace(),
  });

  const stages = useMemo(() => {
    const data = query.data;
    if (!data) return [];

    const stageById = new Map(data.journeyStages.map((stage) => [stage.id, stage]));

    const counts = new Map<number, number>();
    for (const state of data.journeyStates) {
      const stage = stageById.get(state.current_stage_id);
      if (!stage) continue;
      counts.set(stage.stage_order, (counts.get(stage.stage_order) ?? 0) + 1);
    }

    return PRODUCTION_STAGE_ORDERS.map((order) => {
      const stage = data.journeyStages.find((candidate) => candidate.stage_order === order);
      return {
        order,
        label: stage?.label ?? `Stage ${order}`,
        count: counts.get(order) ?? 0,
      };
    });
  }, [query.data]);

  const inProduction = stages.reduce((sum, stage) => sum + stage.count, 0);
  const links = availableModuleLinks("/production");

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Production"
        subtitle="A confirmed booking through preparation, the shoot itself and the family choosing their images."
        quote="The session is the one part of this that cannot be done again."
      />

      <Card className="mb-8 p-6">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          What this module covers
        </div>

        <p className="mt-2 max-w-3xl text-sm leading-relaxed text-muted-foreground">
          Journey stages 8 to 12: the booking is confirmed, the studio prepares, the shoot is
          scheduled and photographed, and the family finishes choosing. Editing picks up from there
          in Post Production.
        </p>

        {query.isLoading && (
          <p className="mt-4 text-sm text-muted-foreground">Opening the studio records…</p>
        )}

        {query.isError && (
          <p className="mt-4 text-sm text-muted-foreground">
            The booking records could not be read just now, so no counts are shown. Nothing is
            estimated in their place.
          </p>
        )}

        {query.data && (
          <>
            <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {stages.map((stage) => (
                <div key={stage.order} className="rounded-xl border border-border p-4">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
                        Stage {String(stage.order).padStart(2, "0")}
                      </div>
                      <div className="mt-1 font-serif text-base text-primary">{stage.label}</div>
                    </div>
                    <div className="font-serif text-2xl text-primary">{stage.count}</div>
                  </div>
                </div>
              ))}
            </div>

            <p className="mt-4 text-xs leading-relaxed text-muted-foreground">
              {inProduction} booking{inProduction === 1 ? "" : "s"} sitting in production, counted
              from the hundred most recent bookings the workspace reads.
            </p>
          </>
        )}

        <p className="mt-4 max-w-3xl text-xs leading-relaxed text-muted-foreground">
          These are counts only. The stage board for this module — cards you can act on, the way
          Editing and Delivery work — is not built yet, so the day-to-day work still happens on the
          screens below.
        </p>
      </Card>

      <section>
        <div className="mb-4">
          <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
            Screens in this module
          </div>
          <h2 className="mt-1 font-serif text-2xl text-primary">Where the work is done</h2>
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          {links.map((link) => (
            <Link key={link.to} to={link.to}>
              <Card className="h-full p-5 transition-transform hover:-translate-y-0.5">
                <div className="font-serif text-lg text-primary">{link.label}</div>
                <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                  {link.description}
                </p>
              </Card>
            </Link>
          ))}
        </div>
      </section>
    </AppShell>
  );
}
