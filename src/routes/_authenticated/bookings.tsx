import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { Check, Circle, Loader2 } from "lucide-react";
import { toast } from "sonner";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import {
  assignLeadPhotographer,
  assignLeadVideographer,
  assignStylist,
  confirmBookingAfterAdvance,
  getBookingConfirmationWorkspace,
  listBookingTeamAssignmentCandidates,
  listBookingWorkspace,
  markBookingShootScheduled,
  proposeBookingShootSchedule,
  recordBookingPayment,
  recordBookingSafetyReadiness,
  signoffBookingSafetyReadiness,
  startPreShootPreparation,
  updatePreShootPreparationItem,
  type BookingJourneyStageRow,
  type BookingPreparationItemRow,
  type BookingPreparationRow,
  type BookingSafetyReadinessRow,
  type BookingSafetySignoffRow,
  type BookingSafetyState,
  type BookingStageTransitionRow,
  type BookingTeamAssignmentCandidateRow,
  type BookingTeamAssignmentHistoryRow,
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

function bookingTeamRoleLabel(role: string) {
  switch (role) {
    case "lead_photographer":
      return "Lead Photographer";
    case "assistant":
      return "Assistant";
    case "stylist":
      return "Stylist";
    case "lead_videographer":
      return "Lead Videographer";
    case "supporting_videographer":
      return "Supporting Videographer";
    default:
      return role;
  }
}

function isBookingSafetyState(value: string | null | undefined): value is BookingSafetyState {
  return (
    value === "pending" || value === "ready" || value === "not_ready" || value === "not_applicable"
  );
}

function safetyStateLabel(state: string) {
  switch (state) {
    case "pending":
      return "Pending";
    case "ready":
      return "Ready";
    case "not_ready":
      return "Not ready";
    case "not_applicable":
      return "Not applicable";
    default:
      return state;
  }
}

function safetySignoffAuthorityLabel(authority: string) {
  switch (authority) {
    case "founder":
      return "Founder";
    case "studio_manager":
      return "Studio Manager";
    case "lead_photographer":
      return "Lead Photographer";
    default:
      return authority;
  }
}

function isSafetyServiceCategory(
  value: string | null,
): value is "newborn" | "maternity" | "sitter" | "baby" | "child" {
  return (
    value === "newborn" ||
    value === "maternity" ||
    value === "sitter" ||
    value === "baby" ||
    value === "child"
  );
}

const editableSafetyStates: BookingSafetyState[] = ["pending", "ready", "not_ready"];

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
                {reservedSchedule ? "reserved" : "recorded in the scheduling authority"}. Authorized
                pre-shoot operations continue below.
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

function ShootScheduledAdvancementControl({
  bookingId,
  onSuccess,
}: {
  bookingId: string;
  onSuccess: () => Promise<void>;
}) {
  const markShootScheduledFn = useServerFn(markBookingShootScheduled);

  const markShootScheduledMutation = useMutation({
    mutationFn: () =>
      markShootScheduledFn({
        data: {
          bookingId,
        },
      }),
    onSuccess: async () => {
      toast.success("Shoot marked scheduled.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not mark the shoot scheduled."),
  });

  return (
    <div className="mt-7 border-t border-border pt-6">
      <div className="rounded-lg border border-border bg-card p-5">
        <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
          Controlled journey advancement
        </div>

        <h3 className="mt-1 font-serif text-xl text-primary">Mark shoot scheduled</h3>

        <p className="mt-2 text-xs leading-5 text-muted-foreground">
          This dedicated action attempts only the canonical Stage 9 to Stage 10 transition. The
          database revalidates the complete shoot-readiness gate, including the reserved schedule,
          required preparation, required staffing, commercial Video/Reels requirements, applicable
          Safety Readiness and qualifying Newborn sign-off when required. It does not advance beyond
          Stage 10.
        </p>

        <button
          type="button"
          onClick={() => markShootScheduledMutation.mutate()}
          disabled={markShootScheduledMutation.isPending}
          className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
        >
          {markShootScheduledMutation.isPending ? "Checking readiness..." : "Mark shoot scheduled"}
        </button>
      </div>
    </div>
  );
}

function PreparationReadSurface({
  bookingId,
  preparation,
  items,
  canStart,
  canMutateItems,
  isHistorical,
  onSuccess,
}: {
  bookingId: string;
  preparation: BookingPreparationRow | null;
  items: BookingPreparationItemRow[];
  canStart: boolean;
  canMutateItems: boolean;
  isHistorical: boolean;
  onSuccess: () => Promise<void>;
}) {
  const startPreparationFn = useServerFn(startPreShootPreparation);
  const updatePreparationItemFn = useServerFn(updatePreShootPreparationItem);

  const startPreparationMutation = useMutation({
    mutationFn: () =>
      startPreparationFn({
        data: {
          bookingId,
        },
      }),
    onSuccess: async () => {
      toast.success("Pre-shoot preparation started.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(
        error instanceof Error ? error.message : "Could not start pre-shoot preparation.",
      ),
  });

  const updatePreparationItemMutation = useMutation({
    mutationFn: ({
      preparationItemId,
      satisfied,
    }: {
      preparationItemId: string;
      satisfied: boolean;
    }) =>
      updatePreparationItemFn({
        data: {
          preparationItemId,
          satisfied,
        },
      }),
    onSuccess: async () => {
      toast.success("Preparation item updated.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not update preparation item."),
  });

  return (
    <div className="mt-7 border-t border-border pt-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Canonical pre-shoot preparation
          </div>
          <h3 className="mt-1 font-serif text-xl text-primary">Preparation checklist</h3>
        </div>

        {preparation ? (
          <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
            Preparation started
          </span>
        ) : null}
      </div>

      {!preparation ? (
        <Card className="mt-5 p-5">
          <p className="text-sm font-medium text-primary">Pre-shoot preparation has not started.</p>

          <p className="mt-1 text-xs leading-5 text-muted-foreground">
            No canonical preparation instance is currently visible for this booking. Client-visible
            state does not independently establish mutation eligibility; the canonical database
            operation re-checks all preparation-start gates.
          </p>

          {canStart ? (
            <>
              <button
                type="button"
                onClick={() => startPreparationMutation.mutate()}
                disabled={startPreparationMutation.isPending}
                className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
              >
                {startPreparationMutation.isPending
                  ? "Starting preparation..."
                  : "Start pre-shoot preparation"}
              </button>

              <p className="mt-2 text-xs leading-5 text-muted-foreground">
                This dedicated operation delegates preparation creation, checklist instantiation and
                the exact Stage 8 -&gt; 9 transition to canonical server authority. It does not mark
                the shoot scheduled or advance beyond Stage 9.
              </p>
            </>
          ) : null}
        </Card>
      ) : (
        <>
          <div className="mt-5 grid gap-4 md:grid-cols-2">
            <div>
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                Preparation started
              </div>
              <div className="mt-1 text-sm font-medium text-primary">
                {formatDateTime(preparation.started_at)}
              </div>
            </div>

            <div>
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                Canonical checklist items
              </div>
              <div className="mt-1 font-serif text-xl text-primary">{items.length}</div>
            </div>
          </div>

          {items.length === 0 ? (
            <Card className="mt-5 p-5">
              <p className="text-sm font-medium text-primary">
                No canonical preparation checklist items are visible.
              </p>
              <p className="mt-1 text-xs leading-5 text-muted-foreground">
                Checklist evidence is shown only when authoritative preparation-item rows are
                returned.
              </p>
            </Card>
          ) : (
            <div className="mt-5 space-y-3">
              {items.map((item) => {
                const isUpdatingThisItem =
                  updatePreparationItemMutation.isPending &&
                  updatePreparationItemMutation.variables?.preparationItemId === item.id;

                return (
                  <div key={item.id} className="rounded-lg border border-border bg-card px-4 py-3">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-medium text-primary">{item.item_label}</div>

                        <div className="mt-1 flex flex-wrap gap-2 text-xs text-muted-foreground">
                          <span>{item.is_required ? "Required" : "Optional"}</span>
                          <span>·</span>
                          <span>{item.is_satisfied ? "Satisfied" : "Unsatisfied"}</span>
                        </div>
                      </div>

                      <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
                        {item.is_satisfied ? "Satisfied" : "Outstanding"}
                      </span>
                    </div>

                    <p className="mt-2 text-xs leading-5 text-muted-foreground">
                      {item.is_satisfied && item.satisfied_at
                        ? `Satisfied ${formatDateTime(item.satisfied_at)}`
                        : "No canonical satisfaction evidence recorded."}
                    </p>

                    {canMutateItems ? (
                      <button
                        type="button"
                        onClick={() =>
                          updatePreparationItemMutation.mutate({
                            preparationItemId: item.id,
                            satisfied: !item.is_satisfied,
                          })
                        }
                        disabled={updatePreparationItemMutation.isPending}
                        className="mt-3 rounded-lg border border-border px-3 py-1.5 text-xs font-medium text-primary hover:bg-muted disabled:opacity-60"
                      >
                        {isUpdatingThisItem
                          ? "Updating..."
                          : item.is_satisfied
                            ? "Mark outstanding"
                            : "Mark satisfied"}
                      </button>
                    ) : null}
                  </div>
                );
              })}
            </div>
          )}

          <p className="mt-4 text-xs leading-5 text-muted-foreground">
            {isHistorical
              ? "This is historical, read-only canonical preparation evidence. Journey, scheduling, safety and team state do not make historical preparation mutable."
              : canMutateItems
                ? "Canonical checklist identity and taxonomy remain read-only. At exact Stage 9, only satisfaction state may change through the controlled preparation-item operation."
                : "This canonical preparation evidence is read-only for the current actor and journey state. Journey, scheduling, safety and team state do not substitute for checklist evidence."}
          </p>
        </>
      )}
    </div>
  );
}

function SafetyReadinessSurface({
  bookingId,
  serviceCategory,
  currentReadiness,
  currentSignoffs,
  canWrite,
  canSignoff,
  onSuccess,
}: {
  bookingId: string;
  serviceCategory: string | null;
  currentReadiness: BookingSafetyReadinessRow | null;
  currentSignoffs: BookingSafetySignoffRow[];
  canWrite: boolean;
  canSignoff: boolean;
  onSuccess: () => Promise<void>;
}) {
  const initialSafetyState: BookingSafetyState =
    serviceCategory === "maternity"
      ? "not_applicable"
      : isBookingSafetyState(currentReadiness?.safety_state) &&
          currentReadiness?.safety_state !== "not_applicable"
        ? currentReadiness.safety_state
        : "pending";

  const initialComfortState: BookingSafetyState =
    isBookingSafetyState(currentReadiness?.comfort_state) &&
    currentReadiness?.comfort_state !== "not_applicable"
      ? currentReadiness.comfort_state
      : "pending";

  const [safetyState, setSafetyState] = useState<BookingSafetyState>(initialSafetyState);
  const [comfortState, setComfortState] = useState<BookingSafetyState>(initialComfortState);

  const recordSafetyFn = useServerFn(recordBookingSafetyReadiness);
  const signoffSafetyFn = useServerFn(signoffBookingSafetyReadiness);

  const effectiveSafetyState: BookingSafetyState =
    serviceCategory === "maternity" ? "not_applicable" : safetyState;

  const recordMutation = useMutation({
    mutationFn: () =>
      recordSafetyFn({
        data: {
          bookingId,
          safetyState: effectiveSafetyState,
          comfortState,
        },
      }),
    onSuccess: async () => {
      toast.success("Safety & comfort readiness recorded.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not record Safety Readiness."),
  });

  const signoffMutation = useMutation({
    mutationFn: () =>
      signoffSafetyFn({
        data: {
          bookingId,
        },
      }),
    onSuccess: async () => {
      toast.success("Newborn Safety Readiness signed off.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not sign off Safety Readiness."),
  });

  const canRecord = canWrite && isSafetyServiceCategory(serviceCategory);

  const canCreateNewbornSignoff =
    canSignoff &&
    serviceCategory === "newborn" &&
    currentReadiness?.safety_state === "ready" &&
    currentReadiness.comfort_state === "ready";

  return (
    <div className="mt-7 border-t border-border pt-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Restricted canonical evidence
          </div>

          <h3 className="mt-1 font-serif text-xl text-primary">Safety & comfort readiness</h3>
        </div>

        <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
          {serviceCategory ? serviceCategory.replaceAll("_", " ") : "Category unavailable"}
        </span>
      </div>

      {currentReadiness ? (
        <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Revision
            </div>

            <div className="mt-1 font-serif text-xl text-primary">
              {currentReadiness.revision_number}
            </div>
          </div>

          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Safety</div>

            <div className="mt-1 text-sm font-medium text-primary">
              {safetyStateLabel(currentReadiness.safety_state)}
            </div>
          </div>

          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Comfort
            </div>

            <div className="mt-1 text-sm font-medium text-primary">
              {safetyStateLabel(currentReadiness.comfort_state)}
            </div>
          </div>

          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Recorded
            </div>

            <div className="mt-1 text-sm font-medium text-primary">
              {formatDateTime(currentReadiness.recorded_at)}
            </div>
          </div>
        </div>
      ) : (
        <Card className="mt-5 p-5">
          <p className="text-sm font-medium text-primary">
            No current canonical Safety Readiness revision is recorded.
          </p>

          <p className="mt-1 text-xs leading-5 text-muted-foreground">
            Readiness is not inferred from legacy safety state, preparation completion, or staffing.
          </p>
        </Card>
      )}

      {canRecord ? (
        <div className="mt-5 rounded-lg border border-border bg-card p-4">
          <div className="text-sm font-medium text-primary">
            {currentReadiness ? "Record revised readiness" : "Record readiness"}
          </div>

          <div className="mt-4 grid gap-4 md:grid-cols-2">
            <label className="text-xs text-muted-foreground">
              Safety state
              {serviceCategory === "maternity" ? (
                <div className="mt-2 rounded-lg border border-border bg-muted px-3 py-2 text-sm text-primary">
                  Not applicable
                </div>
              ) : (
                <select
                  value={safetyState}
                  onChange={(event) => setSafetyState(event.target.value as BookingSafetyState)}
                  className="mt-2 w-full rounded-lg border border-border bg-background px-3 py-2 text-sm text-primary"
                >
                  {editableSafetyStates.map((state) => (
                    <option key={state} value={state}>
                      {safetyStateLabel(state)}
                    </option>
                  ))}
                </select>
              )}
            </label>

            <label className="text-xs text-muted-foreground">
              Comfort state
              <select
                value={comfortState}
                onChange={(event) => setComfortState(event.target.value as BookingSafetyState)}
                className="mt-2 w-full rounded-lg border border-border bg-background px-3 py-2 text-sm text-primary"
              >
                {editableSafetyStates.map((state) => (
                  <option key={state} value={state}>
                    {safetyStateLabel(state)}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <button
            type="button"
            onClick={() => recordMutation.mutate()}
            disabled={recordMutation.isPending}
            className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
          >
            {recordMutation.isPending
              ? "Recording..."
              : currentReadiness
                ? "Record revised readiness"
                : "Record readiness"}
          </button>

          <p className="mt-2 text-xs leading-5 text-muted-foreground">
            Saving changed values creates the next canonical revision. Exact replay remains a
            server-governed no-op.
          </p>
        </div>
      ) : canWrite ? (
        <Card className="mt-5 p-5">
          <p className="text-xs leading-5 text-muted-foreground">
            Canonical service category could not be resolved unambiguously, so readiness mutation is
            unavailable.
          </p>
        </Card>
      ) : null}

      {serviceCategory === "newborn" ? (
        <div className="mt-5 rounded-lg border border-border bg-card p-4">
          <div className="text-sm font-medium text-primary">Newborn formal sign-off</div>

          {currentSignoffs.length === 0 ? (
            <p className="mt-2 text-xs leading-5 text-muted-foreground">
              No formal sign-off is recorded for the current readiness revision.
            </p>
          ) : (
            <div className="mt-3 space-y-2">
              {currentSignoffs.map((signoff) => (
                <div
                  key={signoff.id}
                  className="rounded-lg border border-border bg-muted px-3 py-2 text-xs text-primary"
                >
                  {safetySignoffAuthorityLabel(signoff.signoff_authority)}
                  {" · "}
                  {formatDateTime(signoff.signed_at)}
                </div>
              ))}
            </div>
          )}

          {canCreateNewbornSignoff ? (
            <button
              type="button"
              onClick={() => signoffMutation.mutate()}
              disabled={signoffMutation.isPending}
              className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
            >
              {signoffMutation.isPending ? "Signing off..." : "Sign off Newborn readiness"}
            </button>
          ) : null}

          <p className="mt-3 text-xs leading-5 text-muted-foreground">
            Formal sign-off is accepted only through canonical server authority. Founder, Studio
            Manager and qualifying current internal Lead Photographer eligibility is revalidated by
            the RPC.
          </p>
        </div>
      ) : (
        <p className="mt-4 text-xs leading-5 text-muted-foreground">
          Formal Safety Readiness sign-off is Newborn-only.
        </p>
      )}

      <p className="mt-4 text-xs leading-5 text-muted-foreground">
        This restricted evidence does not independently authorize Stage 9 to Stage 10 advancement.
        The final journey gate remains a separate canonical operation.
      </p>
    </div>
  );
}

function BookingTeamReadSurface({
  assignments,
}: {
  assignments: BookingTeamAssignmentHistoryRow[];
}) {
  return (
    <div className="mt-7 border-t border-border pt-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Canonical booking team
          </div>
          <h3 className="mt-1 font-serif text-xl text-primary">Assignment history</h3>
        </div>

        <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
          Read-only
        </span>
      </div>

      {assignments.length === 0 ? (
        <Card className="mt-5 p-5">
          <p className="text-sm font-medium text-primary">
            No canonical booking-team assignments are recorded.
          </p>

          <p className="mt-1 text-xs leading-5 text-muted-foreground">
            This is a neutral absence of assignment evidence. It does not by itself establish team
            readiness, staffing incompleteness, or journey eligibility.
          </p>
        </Card>
      ) : (
        <div className="mt-5 space-y-3">
          {assignments.map((assignment) => (
            <div
              key={assignment.assignment_id}
              className="rounded-lg border border-border bg-card px-4 py-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                    {bookingTeamRoleLabel(assignment.assignment_role)}
                  </div>

                  <div className="mt-1 text-sm font-medium text-primary">
                    {assignment.subject_display_name ?? "Display name unavailable"}
                  </div>

                  <div className="mt-1 text-xs text-muted-foreground">
                    {assignment.subject_type === "internal_member"
                      ? "Internal team member"
                      : assignment.subject_type === "external_creative"
                        ? "External creative"
                        : assignment.subject_type}
                  </div>
                </div>

                <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
                  {assignment.is_current ? "Current" : "Historical"}
                </span>
              </div>

              <div className="mt-4 grid gap-4 md:grid-cols-3">
                <div>
                  <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                    Assigned
                  </div>
                  <div className="mt-1 text-xs text-primary">
                    {formatDateTime(assignment.assigned_at)}
                  </div>
                </div>

                <div>
                  <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                    Ended
                  </div>
                  <div className="mt-1 text-xs text-primary">
                    {assignment.ended_at ? formatDateTime(assignment.ended_at) : "—"}
                  </div>
                </div>

                <div>
                  <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                    End reason
                  </div>
                  <div className="mt-1 text-xs text-primary">{assignment.end_reason ?? "—"}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <p className="mt-4 text-xs leading-5 text-muted-foreground">
        This surface reports canonical booking-scoped assignment history only. Assignment evidence
        does not independently establish shoot readiness or authorize journey advancement.
      </p>
    </div>
  );
}

function BookingTeamCandidatePicker({
  bookingId,
  assignmentHistory,
  onClose,
  onAssigned,
}: {
  bookingId: string;
  assignmentHistory: BookingTeamAssignmentHistoryRow[];
  onClose: () => void;
  onAssigned: () => Promise<void>;
}) {
  const listCandidatesFn = useServerFn(listBookingTeamAssignmentCandidates);
  const assignLeadPhotographerFn = useServerFn(assignLeadPhotographer);
  const assignStylistFn = useServerFn(assignStylist);
  const assignLeadVideographerFn = useServerFn(assignLeadVideographer);

  const candidatesQuery = useQuery({
    queryKey: ["booking-team-candidates", bookingId],
    queryFn: () => listCandidatesFn({ data: { bookingId } }),
  });

  const candidates = candidatesQuery.data ?? [];

  const rolesRequiringChangeReason = new Set(candidates[0]?.roles_requiring_change_reason ?? []);

  const canAssignLeadPhotographer = !rolesRequiringChangeReason.has("lead_photographer");

  const canAssignLeadVideographer = !rolesRequiringChangeReason.has("lead_videographer");

  const isCurrentStylistSubject = (candidate: BookingTeamAssignmentCandidateRow) =>
    assignmentHistory.some(
      (assignment) =>
        assignment.assignment_role === "stylist" &&
        assignment.is_current &&
        assignment.subject_type === candidate.subject_type &&
        assignment.subject_id === candidate.subject_id,
    );

  const assignLeadPhotographerMutation = useMutation({
    mutationFn: (memberId: string) =>
      assignLeadPhotographerFn({
        data: {
          bookingId,
          memberId,
        },
      }),
    onSuccess: async () => {
      toast.success("Lead Photographer assigned.");
      await onAssigned();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not assign Lead Photographer."),
  });

  const assignStylistMutation = useMutation({
    mutationFn: (vars: {
      subjectType: "internal_member" | "external_creative";
      subjectId: string;
    }) =>
      assignStylistFn({
        data: {
          bookingId,
          subjectType: vars.subjectType,
          subjectId: vars.subjectId,
        },
      }),
    onSuccess: async () => {
      toast.success("Stylist assigned.");
      await onAssigned();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not assign Stylist."),
  });

  const assignLeadVideographerMutation = useMutation({
    mutationFn: (vars: {
      subjectType: "internal_member" | "external_creative";
      subjectId: string;
    }) =>
      assignLeadVideographerFn({
        data: {
          bookingId,
          subjectType: vars.subjectType,
          subjectId: vars.subjectId,
        },
      }),
    onSuccess: async () => {
      toast.success("Lead Videographer assigned.");
      await onAssigned();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not assign Lead Videographer."),
  });

  return (
    <div className="mt-5 rounded-lg border border-border bg-card p-5">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Candidate directory
          </div>
          <h4 className="mt-1 font-serif text-lg text-primary">Eligible for this booking</h4>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="rounded-lg border border-border px-3 py-1.5 text-xs font-medium text-primary hover:bg-muted"
        >
          Close
        </button>
      </div>

      {candidatesQuery.isPending ? (
        <div className="mt-4 flex items-center gap-3 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          Loading candidates…
        </div>
      ) : candidatesQuery.isError ? (
        <p className="mt-4 text-sm text-destructive">
          Unable to load candidates:{" "}
          {candidatesQuery.error instanceof Error ? candidatesQuery.error.message : "Unknown error"}
        </p>
      ) : candidates.length === 0 ? (
        <Card className="mt-4 p-5">
          <p className="text-sm font-medium text-primary">
            No eligible candidates were found for this booking.
          </p>
        </Card>
      ) : (
        <div className="mt-4 space-y-3">
          {candidates.map((candidate) => (
            <div
              key={candidate.subject_id}
              className="rounded-lg border border-border bg-background px-4 py-4"
            >
              <div className="text-sm font-medium text-primary">
                {candidate.subject_display_name ?? "Display name unavailable"}
              </div>

              <div className="mt-1 text-xs text-muted-foreground">
                {candidate.subject_type === "internal_member"
                  ? "Internal team member"
                  : candidate.subject_type === "external_creative"
                    ? "External creative"
                    : candidate.subject_type}
              </div>

              <div className="mt-3 flex flex-wrap gap-2">
                {candidate.eligible_assignment_roles.map((role) => (
                  <span
                    key={role}
                    className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary"
                  >
                    {bookingTeamRoleLabel(role)}
                  </span>
                ))}
              </div>

              {candidate.eligible_assignment_roles.some((role) =>
                rolesRequiringChangeReason.has(role),
              ) ? (
                <p className="mt-3 text-xs leading-5 text-muted-foreground">
                  Replacing the current{" "}
                  {candidate.eligible_assignment_roles
                    .filter((role) => rolesRequiringChangeReason.has(role))
                    .map((role) => bookingTeamRoleLabel(role))
                    .join(" or ")}{" "}
                  requires a change reason.
                </p>
              ) : null}

              {candidate.subject_type === "internal_member" &&
              candidate.eligible_assignment_roles.includes("lead_photographer") &&
              canAssignLeadPhotographer ? (
                <button
                  type="button"
                  onClick={() => assignLeadPhotographerMutation.mutate(candidate.subject_id)}
                  disabled={assignLeadPhotographerMutation.isPending}
                  className="mt-3 rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
                >
                  {assignLeadPhotographerMutation.isPending &&
                  assignLeadPhotographerMutation.variables === candidate.subject_id
                    ? "Assigning…"
                    : "Assign as Lead Photographer"}
                </button>
              ) : null}

              {(candidate.subject_type === "internal_member" ||
                candidate.subject_type === "external_creative") &&
              candidate.eligible_assignment_roles.includes("stylist") &&
              !isCurrentStylistSubject(candidate) ? (
                <button
                  type="button"
                  onClick={() =>
                    assignStylistMutation.mutate({
                      subjectType: candidate.subject_type as
                        "internal_member" | "external_creative",
                      subjectId: candidate.subject_id,
                    })
                  }
                  disabled={assignStylistMutation.isPending}
                  className="mt-3 ml-2 rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
                >
                  {assignStylistMutation.isPending &&
                  assignStylistMutation.variables?.subjectType === candidate.subject_type &&
                  assignStylistMutation.variables?.subjectId === candidate.subject_id
                    ? "Assigning…"
                    : "Assign as Stylist"}
                </button>
              ) : null}

              {(candidate.subject_type === "internal_member" ||
                candidate.subject_type === "external_creative") &&
              candidate.eligible_assignment_roles.includes("lead_videographer") &&
              canAssignLeadVideographer ? (
                <button
                  type="button"
                  onClick={() =>
                    assignLeadVideographerMutation.mutate({
                      subjectType: candidate.subject_type as
                        "internal_member" | "external_creative",
                      subjectId: candidate.subject_id,
                    })
                  }
                  disabled={assignLeadVideographerMutation.isPending}
                  className="mt-3 ml-2 rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
                >
                  {assignLeadVideographerMutation.isPending &&
                  assignLeadVideographerMutation.variables?.subjectType ===
                    candidate.subject_type &&
                  assignLeadVideographerMutation.variables?.subjectId === candidate.subject_id
                    ? "Assigning…"
                    : "Assign as Lead Videographer"}
                </button>
              ) : null}
            </div>
          ))}
        </div>
      )}

      <p className="mt-4 text-xs leading-5 text-muted-foreground">
        This directory reports eligibility only. Assigning a candidate is a separate action
        performed through the canonical assignment RPCs.
      </p>
    </div>
  );
}

function BookingsPage() {
  const { roles } = useSession();
  const queryClient = useQueryClient();

  const [activeTeamPickerBookingId, setActiveTeamPickerBookingId] = useState<string | null>(null);

  const workspaceQuery = useQuery({
    queryKey: ["booking-workspace"],
    queryFn: () => listBookingWorkspace(),
  });

  const data = workspaceQuery.data;
  const isFounder = roles.includes("founder");

  const refreshBookingWorkspace = async () => {
    await queryClient.invalidateQueries({
      queryKey: ["booking-workspace"],
    });
  };

  const refreshBookingTeamAssignment = async (bookingId: string) => {
    await Promise.all([
      queryClient.invalidateQueries({
        queryKey: ["booking-workspace"],
      }),
      queryClient.invalidateQueries({
        queryKey: ["booking-team-candidates", bookingId],
      }),
    ]);
  };

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

            const preparation =
              data.bookingPreparations.find((item) => item.booking_id === booking.id) ?? null;

            const preparationItems = preparation
              ? data.bookingPreparationItems
                  .filter((item) => item.preparation_id === preparation.id)
                  .sort((left, right) => left.sort_order - right.sort_order)
              : [];

            const currentSafetyReadiness =
              data.bookingSafetyReadiness.find(
                (readiness) =>
                  readiness.booking_id === booking.id && readiness.superseded_at === null,
              ) ?? null;

            const preparationServiceCategories = Array.from(
              new Set(preparationItems.map((item) => item.service_category)),
            );

            const safetyServiceCategory =
              currentSafetyReadiness?.service_category ??
              (preparationServiceCategories.length === 1 ? preparationServiceCategories[0] : null);

            const currentSafetySignoffs = currentSafetyReadiness
              ? data.bookingSafetySignoffs.filter(
                  (signoff) =>
                    signoff.booking_id === booking.id &&
                    signoff.readiness_id === currentSafetyReadiness.id,
                )
              : [];

            const bookingTeamAssignmentHistory = data.bookingTeamAssignmentHistory.filter(
              (assignment) => assignment.booking_id === booking.id,
            );

            const capabilities = data.bookingCapabilities[booking.id];

            const currentOrder = currentStage?.stage_order ?? 0;

            const showConfirmationAuthority =
              isFounder && (currentOrder === 7 || currentOrder === 8);

            const canStartPreparation =
              currentStage?.stage_key === "booking_confirmed" &&
              currentOrder === 8 &&
              preparation === null &&
              capabilities.canWritePreparation &&
              capabilities.canAdvanceBookingStage;

            const canMutatePreparationItems =
              currentStage?.stage_key === "pre_shoot_preparation" &&
              currentOrder === 9 &&
              preparation !== null &&
              capabilities.canWritePreparation;

            const canMarkShootScheduled =
              currentStage?.stage_key === "pre_shoot_preparation" &&
              currentOrder === 9 &&
              capabilities.canAdvanceBookingStage;

            const canManageBookingTeam =
              capabilities.canAssignBookingTeam && currentOrder >= 8 && currentOrder <= 10;

            const showPreparation =
              capabilities.canReadPreparation && (currentOrder >= 8 || preparation !== null);

            const showBookingTeam = currentOrder >= 8 || bookingTeamAssignmentHistory.length > 0;

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
                      Journey state remains database-authoritative. This branch exposes only
                      dedicated controlled operations through Stage 10 and never a general
                      stage-transition control.
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

                {showPreparation ? (
                  <PreparationReadSurface
                    bookingId={booking.id}
                    preparation={preparation}
                    items={preparationItems}
                    canStart={canStartPreparation}
                    canMutateItems={canMutatePreparationItems}
                    isHistorical={currentOrder > 9}
                    onSuccess={refreshBookingWorkspace}
                  />
                ) : null}

                {capabilities.canReadSafety &&
                currentOrder === 9 &&
                currentStage?.stage_key === "pre_shoot_preparation" ? (
                  <SafetyReadinessSurface
                    key={currentSafetyReadiness?.id ?? `${booking.id}-none`}
                    bookingId={booking.id}
                    serviceCategory={safetyServiceCategory}
                    currentReadiness={currentSafetyReadiness}
                    currentSignoffs={currentSafetySignoffs}
                    canWrite={capabilities.canWriteSafety}
                    canSignoff={capabilities.canSignoffSafety}
                    onSuccess={refreshBookingWorkspace}
                  />
                ) : null}

                {showBookingTeam ? (
                  <BookingTeamReadSurface assignments={bookingTeamAssignmentHistory} />
                ) : null}

                {canManageBookingTeam && activeTeamPickerBookingId !== booking.id ? (
                  <button
                    type="button"
                    onClick={() => setActiveTeamPickerBookingId(booking.id)}
                    className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
                  >
                    Manage team assignments
                  </button>
                ) : null}

                {canManageBookingTeam && activeTeamPickerBookingId === booking.id ? (
                  <BookingTeamCandidatePicker
                    bookingId={booking.id}
                    assignmentHistory={bookingTeamAssignmentHistory}
                    onClose={() => setActiveTeamPickerBookingId(null)}
                    onAssigned={() => refreshBookingTeamAssignment(booking.id)}
                  />
                ) : null}

                {canMarkShootScheduled ? (
                  <ShootScheduledAdvancementControl
                    bookingId={booking.id}
                    onSuccess={refreshBookingWorkspace}
                  />
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
                    This pre-shoot slice extends the controlled booking journey through preparation,
                    staffing, Safety Readiness and the exact Stage 9 → Stage 10 shoot-scheduled
                    transition. Shoot completion, post-shoot handoff, selection, financial
                    authority, editing, gallery delivery and media custody remain outside this
                    slice.
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
