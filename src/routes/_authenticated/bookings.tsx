import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Check, Circle, Loader2 } from "lucide-react";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import {
  listBookingWorkspace,
  type BookingJourneyStageRow,
  type BookingStageTransitionRow,
} from "@/lib/booking.functions";

export const Route = createFileRoute("/_authenticated/bookings")({
  head: () => ({
    meta: [
      {
        title: "Bookings · Little Moments OS",
      },
      {
        name: "description",
        content: "Canonical booking records and their authoritative client journey state.",
      },
      {
        property: "og:title",
        content: "Bookings · Little Moments OS",
      },
      {
        property: "og:description",
        content: "Canonical booking records and their authoritative client journey state.",
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
  component: BookingsPage,
});

function formatInr(value: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(value);
}

function formatDateTime(value: string | null) {
  if (!value) {
    return "—";
  }

  return new Intl.DateTimeFormat("en-IN", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function stageById(stages: BookingJourneyStageRow[], id: string | null) {
  if (!id) {
    return null;
  }

  return stages.find((stage) => stage.id === id) ?? null;
}

function TransitionHistory({
  transitions,
  stages,
}: {
  transitions: BookingStageTransitionRow[];
  stages: BookingJourneyStageRow[];
}) {
  if (transitions.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">No journey transition history is available.</p>
    );
  }

  return (
    <div className="space-y-3">
      {transitions.map((transition) => {
        const fromStage = stageById(stages, transition.from_stage_id);
        const toStage = stageById(stages, transition.to_stage_id);

        return (
          <div key={transition.id} className="rounded-lg border border-border bg-card px-4 py-3">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-sm font-medium text-primary">
                  {fromStage?.label ?? "Booking created"} → {toStage?.label ?? "Unknown stage"}
                </div>

                <div className="mt-1 text-xs text-muted-foreground">
                  {transition.transition_key}
                </div>
              </div>

              <div className="text-xs text-muted-foreground">
                {formatDateTime(transition.transitioned_at)}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function BookingsPage() {
  const workspaceQuery = useQuery({
    queryKey: ["booking-workspace"],
    queryFn: () => listBookingWorkspace(),
  });

  const data = workspaceQuery.data;

  return (
    <AppShell>
      <PageHeader
        eyebrow="Canonical bookings"
        title="Bookings"
        subtitle="Booking identity and client journey state come from the authoritative Sprint 8 records."
        quote="A booking begins with trust. Confirmation comes only when its real conditions are met."
      />

      {workspaceQuery.isPending ? (
        <Card className="p-8">
          <div className="flex items-center gap-3 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            Loading canonical bookings…
          </div>
        </Card>
      ) : workspaceQuery.isError ? (
        <Card className="p-8">
          <p className="text-sm text-destructive">
            Unable to load bookings:{" "}
            {workspaceQuery.error instanceof Error ? workspaceQuery.error.message : "Unknown error"}
          </p>
        </Card>
      ) : !data || data.bookings.length === 0 ? (
        <Card className="p-8">
          <p className="text-sm text-muted-foreground">
            No canonical bookings exist yet. A booking is created only by accepting an eligible sent
            quotation.
          </p>
        </Card>
      ) : (
        <div className="space-y-6">
          {data.bookings.map((booking) => {
            const quotation =
              data.quotations.find((item) => item.id === booking.source_quotation_id) ?? null;

            const currentState =
              data.journeyStates.find((state) => state.booking_id === booking.id) ?? null;

            const currentStage = currentState
              ? stageById(data.journeyStages, currentState.current_stage_id)
              : null;

            const lead = booking.lead_id
              ? (data.leads.find((item) => item.id === booking.lead_id) ?? null)
              : null;

            const family = booking.family_id
              ? (data.families.find((item) => item.id === booking.family_id) ?? null)
              : null;

            const packageLine =
              data.quotationLines.find(
                (line) =>
                  line.quotation_id === booking.source_quotation_id && line.line_type === "package",
              ) ?? null;

            const transitions = data.transitions.filter(
              (transition) => transition.booking_id === booking.id,
            );

            const currentOrder = currentStage?.stage_order ?? 0;

            return (
              <Card key={booking.id} className="p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                      Booking
                    </div>

                    <h2 className="mt-1 font-serif text-2xl text-primary">
                      {booking.booking_reference}
                    </h2>

                    <p className="mt-1 text-sm text-muted-foreground">
                      {family
                        ? `${family.family_code} · ${family.display_name}`
                        : lead
                          ? `${lead.lead_reference} · ${lead.parent_name}${
                              lead.session_type ? ` · ${lead.session_type}` : ""
                            }`
                          : "Booking subject unavailable"}
                    </p>
                  </div>

                  <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
                    {currentStage?.label ?? "Journey state unavailable"}
                  </span>
                </div>

                <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                      Source quotation
                    </div>
                    <div className="mt-1 text-sm font-medium text-primary">
                      {quotation?.quotation_reference ?? booking.source_quotation_id}
                    </div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      {quotation
                        ? `${quotation.status} · accepted ${formatDateTime(quotation.accepted_at)}`
                        : "Quotation details are not visible to this role."}
                    </div>
                  </div>

                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                      Package snapshot
                    </div>
                    <div className="mt-1 text-sm font-medium text-primary">
                      {packageLine?.item_name ?? "Unavailable"}
                    </div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      Historical quotation line
                    </div>
                  </div>

                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                      Accepted quote total
                    </div>
                    <div className="mt-1 font-serif text-xl text-primary">
                      {quotation ? formatInr(quotation.quoted_total_inr) : "Unavailable"}
                    </div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      Commercial snapshot only — not payment status.
                    </div>
                  </div>

                  <div>
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                      Journey version
                    </div>
                    <div className="mt-1 font-serif text-xl text-primary">
                      {currentState?.version ?? "—"}
                    </div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      Entered {formatDateTime(currentState?.stage_entered_at ?? null)}
                    </div>
                  </div>
                </div>

                <div className="mt-7 border-t border-border pt-6">
                  <div className="flex flex-wrap items-end justify-between gap-4">
                    <div>
                      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                        Client journey
                      </div>

                      <h3 className="mt-1 font-serif text-xl text-primary">
                        {currentStage?.label ?? "State unavailable"}
                        {currentStage ? (
                          <span className="ml-2 text-sm font-sans text-muted-foreground">
                            {currentStage.stage_order}/{data.journeyStages.length}
                          </span>
                        ) : null}
                      </h3>
                    </div>

                    <p className="max-w-xl text-xs leading-5 text-muted-foreground">
                      Journey advancement is read-only here. Sprint 8 does not yet expose a general
                      authoritative stage-transition RPC, so this screen does not invent one.
                    </p>
                  </div>

                  <ol className="mt-5 flex flex-wrap gap-2">
                    {data.journeyStages.map((stage) => {
                      const done = stage.stage_order < currentOrder;
                      const current = stage.id === currentState?.current_stage_id;

                      return (
                        <li
                          key={stage.id}
                          className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10.5px] ${
                            current
                              ? "border-gold bg-[var(--gradient-gold)] text-primary"
                              : done
                                ? "border-border bg-card text-primary/80"
                                : "border-border/60 bg-transparent text-muted-foreground"
                          }`}
                          title={`${stage.stage_order}. ${stage.label}`}
                        >
                          {done ? (
                            <Check className="h-3 w-3" />
                          ) : (
                            <Circle
                              className={`h-2.5 w-2.5 ${current ? "fill-gold text-gold" : ""}`}
                            />
                          )}

                          <span>
                            {stage.stage_order}. {stage.label}
                          </span>
                        </li>
                      );
                    })}
                  </ol>
                </div>

                <div className="mt-7 border-t border-border pt-6">
                  <div className="mb-4">
                    <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                      Journey history
                    </div>
                    <h3 className="mt-1 font-serif text-xl text-primary">Recorded transitions</h3>
                  </div>

                  <TransitionHistory transitions={transitions} stages={data.journeyStages} />
                </div>

                <Card className="mt-6 p-5">
                  <p className="text-xs leading-5 text-muted-foreground">
                    Advance Pending is a workflow state, not proof of payment. Sprint 8 does not
                    maintain a payment ledger, balance, receipt, refund, or date-reservation state
                    on this booking shell. Booking Confirmed requires a separate authoritative
                    advance condition.
                  </p>
                </Card>
              </Card>
            );
          })}
        </div>
      )}
    </AppShell>
  );
}
