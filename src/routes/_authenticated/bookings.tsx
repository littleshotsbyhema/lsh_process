import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Check, Circle, Loader2 } from "lucide-react";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import {
  confirmBookingAfterAdvance,
  getBookingConfirmationWorkspace,
  listBookingWorkspace,
  proposeBookingShootSchedule,
  recordBookingPayment,
  type BookingJourneyStageRow,
  type BookingStageTransitionRow,
} from "@/lib/booking.functions";
import { useSession } from "@/lib/session";

export const Route = createFileRoute("/_authenticated/bookings")({
  head: () => ({
    meta: [
      {
        title: "Bookings · Little Moments OS",
      },
      {
        name: "description",
        content:
          "Canonical booking records, advance payment, shoot proposal and booking confirmation.",
      },
      {
        property: "og:title",
        content: "Bookings · Little Moments OS",
      },
      {
        property: "og:description",
        content:
          "Canonical booking records, advance payment, shoot proposal and booking confirmation.",
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

const fieldClass =
  "w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-foreground";

const primaryButtonClass =
  "inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity disabled:cursor-not-allowed disabled:opacity-50";

const secondaryButtonClass =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-border bg-card px-4 py-2 text-sm font-medium text-primary transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50";

type PaymentMethod = "cash" | "upi" | "bank_transfer" | "card" | "other";

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

function errorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  return "Something went wrong.";
}

function toLocalDateTimeInput(date: Date) {
  const offsetMilliseconds = date.getTimezoneOffset() * 60_000;

  return new Date(date.getTime() - offsetMilliseconds).toISOString().slice(0, 16);
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

function BookingConfirmationPanel({
  bookingId,
  confirmed,
}: {
  bookingId: string;
  confirmed: boolean;
}) {
  const queryClient = useQueryClient();

  const confirmationQuery = useQuery({
    queryKey: ["booking-confirmation", bookingId],
    queryFn: () =>
      getBookingConfirmationWorkspace({
        data: {
          bookingId,
        },
      }),
  });

  const [paymentAmount, setPaymentAmount] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("upi");
  const [receivedAt, setReceivedAt] = useState(() => toLocalDateTimeInput(new Date()));
  const [externalReference, setExternalReference] = useState("");
  const [paymentNote, setPaymentNote] = useState("");

  const [shootStart, setShootStart] = useState("");
  const [shootEnd, setShootEnd] = useState("");
  const [timezone, setTimezone] = useState("Asia/Kolkata");
  const [locationType, setLocationType] = useState("studio");
  const [locationDetails, setLocationDetails] = useState("");

  const refreshConfirmation = async () => {
    await Promise.all([
      queryClient.invalidateQueries({
        queryKey: ["booking-confirmation", bookingId],
      }),
      queryClient.invalidateQueries({
        queryKey: ["booking-workspace"],
      }),
    ]);
  };

  const paymentMutation = useMutation({
    mutationFn: async () => {
      const amountInr = Number(paymentAmount);

      if (!Number.isInteger(amountInr) || amountInr <= 0) {
        throw new Error("Enter a positive whole-INR payment amount.");
      }

      if (!receivedAt) {
        throw new Error("Payment received time is required.");
      }

      return recordBookingPayment({
        data: {
          bookingId,
          amountInr,
          paymentMethod,
          receivedAt: new Date(receivedAt).toISOString(),
          externalReference: externalReference.trim() || undefined,
          note: paymentNote.trim() || undefined,
        },
      });
    },
    onSuccess: async () => {
      setPaymentAmount("");
      setExternalReference("");
      setPaymentNote("");
      setReceivedAt(toLocalDateTimeInput(new Date()));

      await refreshConfirmation();
    },
  });

  const scheduleMutation = useMutation({
    mutationFn: async () => {
      if (!shootStart || !shootEnd) {
        throw new Error("Shoot start and end times are required.");
      }

      const start = new Date(shootStart);
      const end = new Date(shootEnd);

      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
        throw new Error("Enter valid shoot start and end times.");
      }

      if (end <= start) {
        throw new Error("Shoot end time must be after the start time.");
      }

      return proposeBookingShootSchedule({
        data: {
          bookingId,
          scheduledStartAt: start.toISOString(),
          scheduledEndAt: end.toISOString(),
          timezone,
          locationType,
          locationDetails: locationDetails.trim() || undefined,
        },
      });
    },
    onSuccess: refreshConfirmation,
  });

  const confirmMutation = useMutation({
    mutationFn: () =>
      confirmBookingAfterAdvance({
        data: {
          bookingId,
        },
      }),
    onSuccess: refreshConfirmation,
  });

  if (confirmationQuery.isPending) {
    return (
      <Card className="mt-6 p-5">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          Loading authoritative booking confirmation state…
        </div>
      </Card>
    );
  }

  if (confirmationQuery.isError) {
    return (
      <Card className="mt-6 p-5">
        <p className="text-sm text-destructive">
          Unable to load booking confirmation authority: {errorMessage(confirmationQuery.error)}
        </p>
      </Card>
    );
  }

  const confirmation = confirmationQuery.data;
  const paymentSummary = confirmation?.paymentSummary ?? null;
  const currentSchedule = confirmation?.currentSchedule ?? null;

  const advanceSatisfied = paymentSummary?.advance_satisfied ?? false;

  const proposedScheduleReady = currentSchedule?.schedule_state === "proposed";

  const reservedSchedule = currentSchedule?.schedule_state === "reserved";

  const confirmationReady = advanceSatisfied && proposedScheduleReady;

  const mutationError = paymentMutation.error ?? scheduleMutation.error ?? confirmMutation.error;

  return (
    <Card className="mt-6 p-5">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Booking confirmation
          </div>

          <h3 className="mt-1 font-serif text-xl text-primary">Advance + shoot reservation</h3>

          <p className="mt-2 max-w-3xl text-xs leading-5 text-muted-foreground">
            Booking confirmation is controlled by the authoritative payment and scheduling rules.
            The UI cannot bypass those database gates.
          </p>
        </div>

        <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
          {confirmed
            ? "Booking confirmed"
            : confirmationReady
              ? "Ready to confirm"
              : "Conditions pending"}
        </span>
      </div>

      {paymentSummary ? (
        <div className="mt-5 grid gap-3 sm:grid-cols-3">
          <div className="rounded-lg border border-border bg-muted/40 p-4">
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Required advance
            </div>
            <div className="mt-1 font-serif text-xl text-primary">
              {formatInr(Number(paymentSummary.required_advance_inr))}
            </div>
          </div>

          <div className="rounded-lg border border-border bg-muted/40 p-4">
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Valid collected
            </div>
            <div className="mt-1 font-serif text-xl text-primary">
              {formatInr(Number(paymentSummary.valid_collected_inr))}
            </div>
          </div>

          <div className="rounded-lg border border-border bg-muted/40 p-4">
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Outstanding
            </div>
            <div className="mt-1 font-serif text-xl text-primary">
              {formatInr(Number(paymentSummary.advance_outstanding_inr))}
            </div>
          </div>
        </div>
      ) : (
        <p className="mt-5 text-sm text-muted-foreground">
          Authoritative payment summary is unavailable.
        </p>
      )}

      {currentSchedule ? (
        <div className="mt-5 rounded-lg border border-border bg-muted/40 p-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                Current shoot plan
              </div>

              <div className="mt-1 text-sm font-medium text-primary">
                {formatDateTime(currentSchedule.scheduled_start_at)} →{" "}
                {formatDateTime(currentSchedule.scheduled_end_at)}
              </div>

              <div className="mt-1 text-xs text-muted-foreground">
                {currentSchedule.timezone} · {currentSchedule.location_type}
                {currentSchedule.location_details ? ` · ${currentSchedule.location_details}` : ""}
              </div>
            </div>

            <span className="rounded-full border border-border bg-card px-2.5 py-1 text-[10px] uppercase tracking-wider text-primary">
              {currentSchedule.schedule_state} · v{currentSchedule.schedule_version}
            </span>
          </div>
        </div>
      ) : (
        <div className="mt-5 rounded-lg border border-dashed border-border p-4 text-sm text-muted-foreground">
          No proposed shoot plan has been recorded yet.
        </div>
      )}

      {confirmed ? (
        <div className="mt-5 rounded-lg border border-border bg-muted/40 p-4">
          <div className="flex items-start gap-3">
            <Check className="mt-0.5 h-4 w-4 text-primary" />

            <div>
              <div className="text-sm font-medium text-primary">
                Booking confirmation is authoritative
              </div>

              <p className="mt-1 text-xs leading-5 text-muted-foreground">
                Stage 8 has been reached. The shoot schedule is{" "}
                {reservedSchedule ? "reserved" : "recorded in the scheduling authority"}. This CRM
                release stops here.
              </p>

              {paymentSummary?.confirmed_with_advance_shortfall ? (
                <p className="mt-2 text-xs text-destructive">
                  Current payment evidence now shows an advance shortfall after historical
                  confirmation. The journey is not automatically rewound.
                </p>
              ) : null}
            </div>
          </div>
        </div>
      ) : (
        <>
          <div className="mt-6 grid gap-5 xl:grid-cols-2">
            <div className="rounded-lg border border-border p-4">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                1 · Advance payment
              </div>

              <h4 className="mt-1 font-serif text-lg text-primary">Record payment evidence</h4>

              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                <label className="block">
                  <span className="text-xs text-muted-foreground">Amount INR</span>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    className={`${fieldClass} mt-1`}
                    value={paymentAmount}
                    onChange={(event) => setPaymentAmount(event.target.value)}
                    placeholder={
                      paymentSummary ? String(paymentSummary.advance_outstanding_inr) : "Amount"
                    }
                  />
                </label>

                <label className="block">
                  <span className="text-xs text-muted-foreground">Method</span>
                  <select
                    className={`${fieldClass} mt-1`}
                    value={paymentMethod}
                    onChange={(event) => setPaymentMethod(event.target.value as PaymentMethod)}
                  >
                    <option value="upi">UPI</option>
                    <option value="bank_transfer">Bank transfer</option>
                    <option value="card">Card</option>
                    <option value="cash">Cash</option>
                    <option value="other">Other</option>
                  </select>
                </label>

                <label className="block sm:col-span-2">
                  <span className="text-xs text-muted-foreground">Received at</span>
                  <input
                    type="datetime-local"
                    className={`${fieldClass} mt-1`}
                    value={receivedAt}
                    onChange={(event) => setReceivedAt(event.target.value)}
                  />
                </label>

                <label className="block sm:col-span-2">
                  <span className="text-xs text-muted-foreground">External reference</span>
                  <input
                    type="text"
                    className={`${fieldClass} mt-1`}
                    value={externalReference}
                    onChange={(event) => setExternalReference(event.target.value)}
                    placeholder="UPI / bank / receipt reference"
                  />
                </label>

                <label className="block sm:col-span-2">
                  <span className="text-xs text-muted-foreground">Note</span>
                  <textarea
                    rows={2}
                    className={`${fieldClass} mt-1`}
                    value={paymentNote}
                    onChange={(event) => setPaymentNote(event.target.value)}
                    placeholder="Optional operational note"
                  />
                </label>
              </div>

              <button
                type="button"
                className={`${primaryButtonClass} mt-4`}
                disabled={paymentMutation.isPending}
                onClick={() => paymentMutation.mutate()}
              >
                {paymentMutation.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                Record payment
              </button>
            </div>

            <div className="rounded-lg border border-border p-4">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                2 · Shoot proposal
              </div>

              <h4 className="mt-1 font-serif text-lg text-primary">Propose the shoot date</h4>

              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                <label className="block">
                  <span className="text-xs text-muted-foreground">Start</span>
                  <input
                    type="datetime-local"
                    className={`${fieldClass} mt-1`}
                    value={shootStart}
                    onChange={(event) => setShootStart(event.target.value)}
                  />
                </label>

                <label className="block">
                  <span className="text-xs text-muted-foreground">End</span>
                  <input
                    type="datetime-local"
                    className={`${fieldClass} mt-1`}
                    value={shootEnd}
                    onChange={(event) => setShootEnd(event.target.value)}
                  />
                </label>

                <label className="block">
                  <span className="text-xs text-muted-foreground">Timezone</span>
                  <input
                    type="text"
                    className={`${fieldClass} mt-1`}
                    value={timezone}
                    onChange={(event) => setTimezone(event.target.value)}
                  />
                </label>

                <label className="block">
                  <span className="text-xs text-muted-foreground">Location type</span>
                  <select
                    className={`${fieldClass} mt-1`}
                    value={locationType}
                    onChange={(event) => setLocationType(event.target.value)}
                  >
                    <option value="studio">Studio</option>
                    <option value="client_home">Client home</option>
                    <option value="outdoor">Outdoor</option>
                    <option value="other">Other</option>
                  </select>
                </label>

                <label className="block sm:col-span-2">
                  <span className="text-xs text-muted-foreground">Location details</span>
                  <input
                    type="text"
                    className={`${fieldClass} mt-1`}
                    value={locationDetails}
                    onChange={(event) => setLocationDetails(event.target.value)}
                    placeholder="Optional address / studio / landmark"
                  />
                </label>
              </div>

              <button
                type="button"
                className={`${secondaryButtonClass} mt-4`}
                disabled={scheduleMutation.isPending}
                onClick={() => scheduleMutation.mutate()}
              >
                {scheduleMutation.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                {currentSchedule?.schedule_state === "proposed"
                  ? "Update proposal"
                  : "Record shoot proposal"}
              </button>
            </div>
          </div>

          <div className="mt-5 rounded-lg border border-border bg-muted/30 p-4">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  3 · Final confirmation
                </div>

                <div className="mt-1 text-sm font-medium text-primary">
                  {confirmationReady
                    ? "Advance and shoot proposal are ready."
                    : "Both authoritative conditions must be satisfied."}
                </div>

                <div className="mt-1 text-xs text-muted-foreground">
                  Advance: {advanceSatisfied ? "satisfied" : "pending"} · Shoot plan:{" "}
                  {proposedScheduleReady ? "proposed" : "required"}
                </div>
              </div>

              <button
                type="button"
                className={primaryButtonClass}
                disabled={!confirmationReady || confirmMutation.isPending}
                onClick={() => confirmMutation.mutate()}
              >
                {confirmMutation.isPending ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Check className="h-4 w-4" />
                )}
                Confirm booking
              </button>
            </div>
          </div>
        </>
      )}

      {mutationError ? (
        <div className="mt-4 rounded-lg border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">
          {errorMessage(mutationError)}
        </div>
      ) : null}
    </Card>
  );
}

function BookingsPage() {
  const { roles } = useSession();

  const workspaceQuery = useQuery({
    queryKey: ["booking-workspace"],
    queryFn: () => listBookingWorkspace(),
  });

  const data = workspaceQuery.data;
  const isFounder = roles.includes("founder");

  return (
    <AppShell>
      <PageHeader
        eyebrow="Canonical bookings"
        title="Bookings"
        subtitle="Accepted quotations become canonical bookings. Advance evidence and the proposed shoot date complete the controlled confirmation journey."
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
            Unable to load bookings: {errorMessage(workspaceQuery.error)}
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

            const showConfirmationAuthority =
              isFounder && (currentOrder === 7 || currentOrder === 8);

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
                    <div className="mt-1 text-xs text-muted-foreground">Commercial snapshot</div>
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
                          <span className="ml-2 font-sans text-sm text-muted-foreground">
                            {currentStage.stage_order}/{data.journeyStages.length}
                          </span>
                        ) : null}
                      </h3>
                    </div>

                    <p className="max-w-xl text-xs leading-5 text-muted-foreground">
                      Journey state remains database-authoritative. This release exposes only the
                      controlled Advance Pending → Booking Confirmed path.
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

                {showConfirmationAuthority ? (
                  <BookingConfirmationPanel bookingId={booking.id} confirmed={currentOrder === 8} />
                ) : null}

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
                    This CRM release ends at Booking Confirmed. Shoot preparation, staffing, safety
                    readiness, shoot execution, media custody, editing and delivery remain outside
                    this release boundary.
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
