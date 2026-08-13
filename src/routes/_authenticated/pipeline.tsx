import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { listBookingWorkspace } from "@/lib/booking.functions";

export const Route = createFileRoute("/_authenticated/pipeline")({
  head: () => ({
    meta: [
      {
        title: "Pipeline · Little Moments OS",
      },
      {
        name: "description",
        content: "The authoritative 21-stage client journey for canonical bookings.",
      },
      {
        property: "og:title",
        content: "Pipeline · Little Moments OS",
      },
      {
        property: "og:description",
        content: "The authoritative 21-stage client journey for canonical bookings.",
      },
      {
        property: "og:type",
        content: "website",
      },
      {
        name: "twitter:card",
        content: "summary",
      },
    ],
  }),
  component: PipelinePage,
});

function PipelinePage() {
  const workspaceQuery = useQuery({
    queryKey: ["booking-workspace"],
    queryFn: () => listBookingWorkspace(),
  });

  const data = workspaceQuery.data;

  return (
    <AppShell>
      <PageHeader
        eyebrow="Canonical client journey"
        title="Pipeline"
        subtitle="Every booking is grouped by its authoritative Sprint 8 journey state."
        quote="A journey honoured well becomes a relationship that lasts."
      />

      {workspaceQuery.isPending ? (
        <Card className="p-8">
          <div className="flex items-center gap-3 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            Loading canonical pipeline…
          </div>
        </Card>
      ) : workspaceQuery.isError ? (
        <Card className="p-8">
          <p className="text-sm text-destructive">
            Unable to load pipeline:{" "}
            {workspaceQuery.error instanceof Error ? workspaceQuery.error.message : "Unknown error"}
          </p>
        </Card>
      ) : !data ? null : (
        <>
          <Card className="mb-5 p-4">
            <p className="text-xs leading-5 text-muted-foreground">
              Pipeline state is read-only. Little Moments OS does not currently expose a general
              authoritative booking-stage transition RPC, so this screen does not provide arbitrary
              stage movement.
            </p>
          </Card>

          <div className="flex gap-4 overflow-x-auto pb-5">
            {data.journeyStages.map((stage) => {
              const statesForStage = data.journeyStates.filter(
                (state) => state.current_stage_id === stage.id,
              );

              const bookingsForStage = statesForStage
                .map((state) => {
                  const booking =
                    data.bookings.find((item) => item.id === state.booking_id) ?? null;

                  return booking
                    ? {
                        booking,
                        state,
                      }
                    : null;
                })
                .filter(
                  (
                    item,
                  ): item is {
                    booking: (typeof data.bookings)[number];
                    state: (typeof data.journeyStates)[number];
                  } => item !== null,
                );

              return (
                <div key={stage.id} className="min-w-[280px] flex-shrink-0">
                  <Card className="h-full p-4">
                    <div className="mb-4 flex items-start justify-between gap-3">
                      <div>
                        <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                          Stage {stage.stage_order}
                        </div>

                        <h3 className="mt-1 font-serif text-sm text-primary">{stage.label}</h3>
                      </div>

                      <StatusPill tone={bookingsForStage.length ? "gold" : "neutral"}>
                        {bookingsForStage.length}
                      </StatusPill>
                    </div>

                    {bookingsForStage.length === 0 ? (
                      <p className="text-xs italic text-muted-foreground">Empty</p>
                    ) : (
                      <ul className="space-y-2">
                        {bookingsForStage.map(({ booking, state }) => {
                          const lead = booking.lead_id
                            ? (data.leads.find((item) => item.id === booking.lead_id) ?? null)
                            : null;

                          const family = booking.family_id
                            ? (data.families.find((item) => item.id === booking.family_id) ?? null)
                            : null;

                          const quotation =
                            data.quotations.find(
                              (item) => item.id === booking.source_quotation_id,
                            ) ?? null;

                          const packageLine =
                            data.quotationLines.find(
                              (line) =>
                                line.quotation_id === booking.source_quotation_id &&
                                line.line_type === "package",
                            ) ?? null;

                          const subject = family
                            ? `${family.family_code} · ${family.display_name}`
                            : lead
                              ? `${lead.lead_reference} · ${lead.parent_name}`
                              : "Booking subject unavailable";

                          return (
                            <li key={booking.id}>
                              <Link
                                to="/bookings"
                                className="block rounded-lg border border-border bg-card p-3 transition-colors hover:bg-accent"
                              >
                                <div className="text-sm font-medium text-primary">
                                  {booking.booking_reference}
                                </div>

                                <div className="mt-1 truncate text-[11px] text-muted-foreground">
                                  {subject}
                                </div>

                                {packageLine ? (
                                  <div className="mt-2 text-xs text-primary">
                                    {packageLine.item_name}
                                  </div>
                                ) : null}

                                <div className="mt-1 text-[10.5px] text-muted-foreground">
                                  {quotation?.quotation_reference ?? "Quotation unavailable"}
                                  {" · "}
                                  journey v{state.version}
                                </div>
                              </Link>
                            </li>
                          );
                        })}
                      </ul>
                    )}
                  </Card>
                </div>
              );
            })}
          </div>
        </>
      )}
    </AppShell>
  );
}
