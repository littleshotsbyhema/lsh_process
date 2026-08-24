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
  listBookingTeamAssignmentCandidates,
  listBookingWorkspace,
  proposeShootSchedule,
  recordBookingPayment,
  rescheduleShoot,
  startPreShootPreparation,
  updatePreShootPreparationItem,
  type BookingJourneyStageRow,
  type BookingPaymentMethod,
  type BookingPaymentSummary,
  type BookingPreparationItemRow,
  type BookingPreparationRow,
  type BookingShootScheduleRow,
  type BookingStageTransitionRow,
  type BookingTeamAssignmentCandidateRow,
  type BookingTeamAssignmentHistoryRow,
} from "@/lib/booking.functions";

export const Route = createFileRoute("/_authenticated/bookings")({
  head: () => ({
    meta: [
      {
        title: "Bookings · Little Moments OS",
      },
      {
        name: "description",
        content:
          "Canonical booking records, authoritative client journey state and immutable shoot schedule evidence.",
      },
      {
        property: "og:title",
        content: "Bookings · Little Moments OS",
      },
      {
        property: "og:description",
        content:
          "Canonical booking records, authoritative client journey state and immutable shoot schedule evidence.",
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

function stageById(stages: BookingJourneyStageRow[], id: string | null) {
  if (!id) {
    return null;
  }

  return stages.find((stage) => stage.id === id) ?? null;
}

function formatScheduleDateTime(value: string, timeZone: string) {
  try {
    return new Intl.DateTimeFormat("en-IN", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone,
    }).format(new Date(value));
  } catch {
    return `${new Date(value).toISOString()} (${timeZone})`;
  }
}

function scheduleStateLabel(state: BookingShootScheduleRow["schedule_state"]) {
  return state === "reserved" ? "Reserved" : "Proposed · not reserved";
}

function ScheduleHistory({ schedules }: { schedules: BookingShootScheduleRow[] }) {
  if (schedules.length === 0) {
    return null;
  }

  return (
    <div className="space-y-3">
      {schedules.map((schedule) => (
        <div key={schedule.id} className="rounded-lg border border-border bg-card px-4 py-3">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <div className="text-sm font-medium text-primary">
                Version {schedule.schedule_version} · {scheduleStateLabel(schedule.schedule_state)}
              </div>

              <div className="mt-1 text-xs text-muted-foreground">
                {formatScheduleDateTime(schedule.scheduled_start_at, schedule.timezone)} →{" "}
                {formatScheduleDateTime(schedule.scheduled_end_at, schedule.timezone)}
              </div>
            </div>

            <div className="text-xs text-muted-foreground">
              Recorded {formatDateTime(schedule.recorded_at)}
            </div>
          </div>

          <div className="mt-3 grid gap-2 text-xs text-muted-foreground md:grid-cols-2">
            <div>
              Location: {schedule.location_type}
              {schedule.location_details ? ` · ${schedule.location_details}` : ""}
            </div>

            <div>Timezone: {schedule.timezone}</div>

            <div className="break-all">
              {schedule.predecessor_schedule_id
                ? `Predecessor: ${schedule.predecessor_schedule_id}`
                : "Initial schedule evidence"}
            </div>

            <div className="break-all">Recorded by: {schedule.recorded_by}</div>
          </div>

          {schedule.reschedule_reason ? (
            <div className="mt-3 rounded-md border border-border bg-muted px-3 py-2 text-xs text-primary">
              Reschedule reason: {schedule.reschedule_reason}
            </div>
          ) : null}
        </div>
      ))}
    </div>
  );
}

function paymentMethodLabel(method: BookingPaymentMethod) {
  switch (method) {
    case "cash":
      return "Cash";
    case "upi":
      return "UPI";
    case "bank_transfer":
      return "Bank transfer";
    case "card":
      return "Card";
    case "other":
      return "Other";
  }
}

function PaymentSummary({ summary }: { summary: BookingPaymentSummary }) {
  return (
    <div className="mt-5">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Accepted quotation total
          </div>
          <div className="mt-1 font-serif text-xl text-primary">
            {formatInr(summary.accepted_quotation_total_inr)}
          </div>
        </div>

        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Required advance
          </div>
          <div className="mt-1 font-serif text-xl text-primary">
            {formatInr(summary.required_advance_inr)}
          </div>
        </div>

        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Valid collected
          </div>
          <div className="mt-1 font-serif text-xl text-primary">
            {formatInr(summary.valid_collected_inr)}
          </div>
        </div>

        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Advance outstanding
          </div>
          <div className="mt-1 font-serif text-xl text-primary">
            {formatInr(summary.advance_outstanding_inr)}
          </div>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap gap-2 text-xs">
        <span className="rounded-full border border-border bg-muted px-3 py-1 font-medium text-primary">
          {summary.advance_satisfied ? "Advance satisfied" : "Advance outstanding"}
        </span>

        <span className="rounded-full border border-border bg-card px-3 py-1 text-muted-foreground">
          {summary.payment_count} payment{summary.payment_count === 1 ? "" : "s"}
        </span>

        {summary.reversal_count > 0 ? (
          <span className="rounded-full border border-border bg-card px-3 py-1 text-muted-foreground">
            {summary.reversal_count} reversal{summary.reversal_count === 1 ? "" : "s"}
          </span>
        ) : null}
      </div>

      {summary.confirmed_with_advance_shortfall ? (
        <p className="mt-4 rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-xs leading-5 text-destructive">
          Canonical records report that this booking was confirmed with an advance shortfall.
        </p>
      ) : null}

      {summary.advance_satisfied ? (
        <p className="mt-4 text-xs leading-5 text-muted-foreground">
          The financial advance requirement is satisfied. This does not confirm the booking, reserve
          a proposed shoot plan, or advance the client journey.
        </p>
      ) : null}
    </div>
  );
}

function PaymentRecordForm({
  bookingId,
  onCancel,
  onSuccess,
}: {
  bookingId: string;
  onCancel: () => void;
  onSuccess: () => Promise<void>;
}) {
  const [amount, setAmount] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<BookingPaymentMethod>("upi");
  const [receivedAt, setReceivedAt] = useState("");
  const [externalReference, setExternalReference] = useState("");
  const [note, setNote] = useState("");

  const recordPaymentFn = useServerFn(recordBookingPayment);

  const recordPaymentMutation = useMutation({
    mutationFn: (vars: {
      bookingId: string;
      amountInr: number;
      paymentMethod: BookingPaymentMethod;
      receivedAt: string;
      externalReference?: string;
      note?: string;
    }) => recordPaymentFn({ data: vars }),
    onSuccess: async () => {
      toast.success("Payment evidence recorded.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not record payment evidence."),
  });

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const amountInr = Number(amount);

    if (!Number.isInteger(amountInr) || amountInr <= 0) {
      toast.error("Enter a positive whole-INR payment amount.");
      return;
    }

    if (!receivedAt) {
      toast.error("Received time is required.");
      return;
    }

    const receivedDate = new Date(receivedAt);

    if (Number.isNaN(receivedDate.getTime())) {
      toast.error("Enter a valid received time.");
      return;
    }

    const trimmedReference = externalReference.trim();
    const trimmedNote = note.trim();

    recordPaymentMutation.mutate({
      bookingId,
      amountInr,
      paymentMethod,
      receivedAt: receivedDate.toISOString(),
      externalReference: trimmedReference.length > 0 ? trimmedReference : undefined,
      note: trimmedNote.length > 0 ? trimmedNote : undefined,
    });
  };

  return (
    <form onSubmit={handleSubmit} className="mt-5 rounded-lg border border-border bg-card p-4">
      <p className="text-sm font-medium text-primary">Record advance payment evidence</p>

      <p className="mt-1 text-xs leading-5 text-muted-foreground">
        This appends immutable payment evidence. Recording sufficient advance does not confirm the
        booking or reserve its proposed shoot plan.
      </p>

      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Amount · INR
          </span>
          <input
            type="number"
            min="1"
            step="1"
            inputMode="numeric"
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
            required
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>

        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Payment method
          </span>
          <select
            value={paymentMethod}
            onChange={(event) => setPaymentMethod(event.target.value as BookingPaymentMethod)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          >
            {(["cash", "upi", "bank_transfer", "card", "other"] as BookingPaymentMethod[]).map(
              (method) => (
                <option key={method} value={method}>
                  {paymentMethodLabel(method)}
                </option>
              ),
            )}
          </select>
        </label>

        <label className="block sm:col-span-2">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Received at
          </span>
          <input
            type="datetime-local"
            value={receivedAt}
            onChange={(event) => setReceivedAt(event.target.value)}
            required
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>

        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            External reference (optional)
          </span>
          <input
            type="text"
            value={externalReference}
            onChange={(event) => setExternalReference(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>

        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Note (optional)
          </span>
          <input
            type="text"
            value={note}
            onChange={(event) => setNote(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>
      </div>

      <div className="mt-4 flex flex-wrap gap-3">
        <button
          type="submit"
          disabled={recordPaymentMutation.isPending}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
        >
          {recordPaymentMutation.isPending ? "Recording…" : "Record payment"}
        </button>

        <button
          type="button"
          onClick={onCancel}
          disabled={recordPaymentMutation.isPending}
          className="rounded-lg border border-border px-4 py-2 text-sm font-medium text-primary hover:bg-muted disabled:opacity-60"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}

function resolveBrowserTimezone(): string | null {
  try {
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return timeZone && timeZone.length > 0 ? timeZone : null;
  } catch {
    return null;
  }
}

type ScheduleMutationMode = "propose" | "reschedule";

function ScheduleMutationForm({
  mode,
  bookingId,
  onCancel,
  onSuccess,
}: {
  mode: ScheduleMutationMode;
  bookingId: string;
  onCancel: () => void;
  onSuccess: () => Promise<void>;
}) {
  const [timezone] = useState(resolveBrowserTimezone);

  const [scheduledStart, setScheduledStart] = useState("");
  const [scheduledEnd, setScheduledEnd] = useState("");
  const [locationType, setLocationType] = useState("");
  const [locationDetails, setLocationDetails] = useState("");
  const [rescheduleReason, setRescheduleReason] = useState("");

  const proposeFn = useServerFn(proposeShootSchedule);
  const rescheduleFn = useServerFn(rescheduleShoot);

  const proposeMutation = useMutation({
    mutationFn: (vars: {
      bookingId: string;
      scheduledStartAt: string;
      scheduledEndAt: string;
      timezone: string;
      locationType: string;
      locationDetails?: string;
    }) => proposeFn({ data: vars }),
    onSuccess: async () => {
      toast.success("Shoot schedule proposed.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not propose the shoot schedule."),
  });

  const rescheduleMutation = useMutation({
    mutationFn: (vars: {
      bookingId: string;
      scheduledStartAt: string;
      scheduledEndAt: string;
      timezone: string;
      locationType: string;
      rescheduleReason: string;
      locationDetails?: string;
    }) => rescheduleFn({ data: vars }),
    onSuccess: async () => {
      toast.success("Shoot rescheduled.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not reschedule the shoot."),
  });

  const mutation = mode === "propose" ? proposeMutation : rescheduleMutation;

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!timezone) {
      toast.error("A browser timezone could not be resolved. Scheduling is unavailable.");
      return;
    }

    if (!scheduledStart || !scheduledEnd) {
      toast.error("Start and end times are required.");
      return;
    }

    const startDate = new Date(scheduledStart);
    const endDate = new Date(scheduledEnd);

    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
      toast.error("Enter valid start and end times.");
      return;
    }

    if (endDate <= startDate) {
      toast.error("The scheduled end must be after the scheduled start.");
      return;
    }

    if (!locationType.trim()) {
      toast.error("Location type is required.");
      return;
    }

    const trimmedDetails = locationDetails.trim();

    if (mode === "propose") {
      proposeMutation.mutate({
        bookingId,
        scheduledStartAt: startDate.toISOString(),
        scheduledEndAt: endDate.toISOString(),
        timezone,
        locationType: locationType.trim(),
        locationDetails: trimmedDetails.length > 0 ? trimmedDetails : undefined,
      });
      return;
    }

    if (!rescheduleReason.trim()) {
      toast.error("A reschedule reason is required.");
      return;
    }

    rescheduleMutation.mutate({
      bookingId,
      scheduledStartAt: startDate.toISOString(),
      scheduledEndAt: endDate.toISOString(),
      timezone,
      locationType: locationType.trim(),
      rescheduleReason: rescheduleReason.trim(),
      locationDetails: trimmedDetails.length > 0 ? trimmedDetails : undefined,
    });
  };

  return (
    <form onSubmit={handleSubmit} className="mt-5 rounded-lg border border-border bg-card p-4">
      <p className="text-sm font-medium text-primary">
        {mode === "propose" ? "Propose shoot schedule" : "Reschedule shoot"}
      </p>

      <p className="mt-1 text-xs leading-5 text-muted-foreground">
        {mode === "propose"
          ? "Proposing a schedule does not reserve a date or confirm this booking."
          : "Rescheduling replaces the current reserved schedule with another reserved version. It does not confirm the booking or advance the journey."}
      </p>

      {!timezone ? (
        <p className="mt-3 rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-xs text-destructive">
          The browser timezone could not be resolved. Scheduling cannot be submitted.
        </p>
      ) : null}

      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Scheduled start
          </span>
          <input
            type="datetime-local"
            value={scheduledStart}
            onChange={(event) => setScheduledStart(event.target.value)}
            required
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>

        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Scheduled end
          </span>
          <input
            type="datetime-local"
            value={scheduledEnd}
            onChange={(event) => setScheduledEnd(event.target.value)}
            required
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>

        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Timezone
          </span>
          <input
            type="text"
            value={timezone ?? "Unavailable"}
            readOnly
            disabled
            className="mt-1.5 w-full rounded-lg border border-border bg-muted px-3 py-2 text-sm text-muted-foreground"
          />
        </label>

        <label className="block">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Location type
          </span>
          <input
            type="text"
            value={locationType}
            onChange={(event) => setLocationType(event.target.value)}
            required
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>

        <label className="block sm:col-span-2">
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Location details (optional)
          </span>
          <input
            type="text"
            value={locationDetails}
            onChange={(event) => setLocationDetails(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>

        {mode === "reschedule" ? (
          <label className="block sm:col-span-2">
            <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
              Reschedule reason
            </span>
            <textarea
              value={rescheduleReason}
              onChange={(event) => setRescheduleReason(event.target.value)}
              required
              rows={2}
              className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
            />
          </label>
        ) : null}
      </div>

      <div className="mt-4 flex flex-wrap gap-3">
        <button
          type="submit"
          disabled={mutation.isPending || !timezone}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
        >
          {mutation.isPending
            ? mode === "propose"
              ? "Proposing…"
              : "Rescheduling…"
            : mode === "propose"
              ? "Propose schedule"
              : "Confirm reschedule"}
        </button>

        <button
          type="button"
          onClick={onCancel}
          disabled={mutation.isPending}
          className="rounded-lg border border-border px-4 py-2 text-sm font-medium text-primary hover:bg-muted disabled:opacity-60"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}

function BookingConfirmationControl({
  bookingId,
  onSuccess,
}: {
  bookingId: string;
  onSuccess: () => Promise<void>;
}) {
  const confirmBookingFn = useServerFn(confirmBookingAfterAdvance);

  const confirmBookingMutation = useMutation({
    mutationFn: () =>
      confirmBookingFn({
        data: {
          bookingId,
        },
      }),
    onSuccess: async () => {
      toast.success("Booking confirmed and shoot reserved.");
      await onSuccess();
    },
    onError: (error: unknown) =>
      toast.error(error instanceof Error ? error.message : "Could not confirm the booking."),
  });

  return (
    <div className="mt-4 rounded-lg border border-border bg-card p-4">
      <p className="text-sm font-medium text-primary">Confirm booking & reserve shoot</p>

      <p className="mt-1 text-xs leading-5 text-muted-foreground">
        This dedicated action confirms the booking, reserves the current proposed shoot plan and
        advances the client journey exactly from Stage 7 to Stage 8. It does not start pre-shoot
        preparation, complete preparation, mark safety readiness, assign team members, mark the
        shoot scheduled, or advance beyond Stage 8.
      </p>

      <button
        type="button"
        onClick={() => confirmBookingMutation.mutate()}
        disabled={confirmBookingMutation.isPending}
        className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
      >
        {confirmBookingMutation.isPending ? "Confirming…" : "Confirm booking & reserve shoot"}
      </button>
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
  const queryClient = useQueryClient();

  const workspaceQuery = useQuery({
    queryKey: ["booking-workspace"],
    queryFn: () => listBookingWorkspace(),
  });

  const data = workspaceQuery.data;

  const [activeForm, setActiveForm] = useState<{
    bookingId: string;
    mode: ScheduleMutationMode;
  } | null>(null);

  const [activePaymentBookingId, setActivePaymentBookingId] = useState<string | null>(null);

  const [activeTeamPickerBookingId, setActiveTeamPickerBookingId] = useState<string | null>(null);

  const refreshBookingWorkspace = async () => {
    setActiveForm(null);
    setActivePaymentBookingId(null);
    setActiveTeamPickerBookingId(null);
    await queryClient.invalidateQueries({ queryKey: ["booking-workspace"] });
  };

  const refreshBookingTeamAssignment = async (bookingId: string) => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ["booking-team-candidates", bookingId] }),
      queryClient.invalidateQueries({ queryKey: ["booking-workspace"] }),
    ]);
  };

  return (
    <AppShell>
      <PageHeader
        eyebrow="Canonical bookings"
        title="Bookings"
        subtitle="Booking identity, client journey state and recorded shoot plans come from canonical studio records."
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

            const scheduleHistory = data.schedules
              .filter((schedule) => schedule.booking_id === booking.id)
              .sort((left, right) => left.schedule_version - right.schedule_version);

            const currentSchedule = scheduleHistory[scheduleHistory.length - 1] ?? null;

            const paymentSummary =
              data.paymentSummaries.find((summary) => summary.booking_id === booking.id) ?? null;

            const preparation =
              data.bookingPreparations.find((item) => item.booking_id === booking.id) ?? null;

            const preparationItems = preparation
              ? data.bookingPreparationItems
                  .filter((item) => item.preparation_id === preparation.id)
                  .sort((left, right) => left.sort_order - right.sort_order)
              : [];

            const bookingTeamAssignmentHistory = data.bookingTeamAssignmentHistory.filter(
              (assignment) => assignment.booking_id === booking.id,
            );

            const currentOrder = currentStage?.stage_order ?? 0;

            const canRecordPayment =
              currentOrder === 7 &&
              data.canReadPayment &&
              data.canRecordPayment &&
              paymentSummary !== null &&
              !paymentSummary.advance_satisfied;

            const canConfirmBooking =
              currentOrder === 7 &&
              currentStage?.stage_key === "advance_pending" &&
              data.canConfirmBooking &&
              data.canReadPayment &&
              paymentSummary !== null &&
              paymentSummary.advance_satisfied &&
              currentSchedule?.schedule_state === "proposed";

            const canPropose =
              data.canSchedule &&
              currentOrder === 7 &&
              (!currentSchedule || currentSchedule.schedule_state === "proposed");

            const canReschedule =
              data.canSchedule &&
              currentOrder >= 8 &&
              currentOrder <= 10 &&
              currentSchedule?.schedule_state === "reserved";

            const canStartPreparation =
              currentStage?.stage_key === "booking_confirmed" &&
              currentOrder === 8 &&
              preparation === null &&
              currentSchedule?.schedule_state === "reserved" &&
              data.canWritePreparation &&
              data.canAdvanceBookingStage;

            const canMutatePreparationItems =
              currentStage?.stage_key === "pre_shoot_preparation" &&
              currentOrder === 9 &&
              preparation !== null &&
              data.canWritePreparation;

            const canManageBookingTeam =
              data.canAssignBookingTeam && currentOrder >= 8 && currentOrder <= 10;

            const isActiveForm = (mode: ScheduleMutationMode) =>
              activeForm?.bookingId === booking.id && activeForm.mode === mode;

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

                {data.canReadPayment && paymentSummary ? (
                  <div className="mt-7 border-t border-border pt-6">
                    <div className="flex flex-wrap items-start justify-between gap-4">
                      <div>
                        <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                          Canonical advance evidence
                        </div>
                        <h3 className="mt-1 font-serif text-xl text-primary">Advance payment</h3>
                      </div>

                      <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
                        {paymentSummary.advance_satisfied
                          ? "Advance satisfied"
                          : "Advance outstanding"}
                      </span>
                    </div>

                    <PaymentSummary summary={paymentSummary} />

                    {canRecordPayment && activePaymentBookingId !== booking.id ? (
                      <button
                        type="button"
                        onClick={() => setActivePaymentBookingId(booking.id)}
                        className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
                      >
                        Record advance payment
                      </button>
                    ) : null}

                    {canRecordPayment && activePaymentBookingId === booking.id ? (
                      <PaymentRecordForm
                        bookingId={booking.id}
                        onCancel={() => setActivePaymentBookingId(null)}
                        onSuccess={refreshBookingWorkspace}
                      />
                    ) : null}
                  </div>
                ) : null}

                <div className="mt-7 border-t border-border pt-6">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                        Canonical shoot schedule
                      </div>
                      <h3 className="mt-1 font-serif text-xl text-primary">Shoot plan</h3>
                    </div>

                    {currentSchedule ? (
                      <span className="rounded-full border border-border bg-muted px-3 py-1 text-[10px] uppercase tracking-wider text-primary">
                        {scheduleStateLabel(currentSchedule.schedule_state)}
                      </span>
                    ) : null}
                  </div>

                  {!currentSchedule ? (
                    <Card className="mt-5 p-5">
                      <p className="text-sm font-medium text-primary">
                        No canonical shoot plan recorded
                      </p>
                      <p className="mt-1 text-xs leading-5 text-muted-foreground">
                        No date is inferred from legacy booking state. Shoot timing appears here
                        only when authoritative schedule evidence exists.
                      </p>

                      {canPropose && !isActiveForm("propose") ? (
                        <button
                          type="button"
                          onClick={() => setActiveForm({ bookingId: booking.id, mode: "propose" })}
                          className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
                        >
                          Propose shoot schedule
                        </button>
                      ) : null}

                      {canPropose && isActiveForm("propose") ? (
                        <ScheduleMutationForm
                          mode="propose"
                          bookingId={booking.id}
                          onCancel={() => setActiveForm(null)}
                          onSuccess={refreshBookingWorkspace}
                        />
                      ) : null}
                    </Card>
                  ) : (
                    <>
                      <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                        <div>
                          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                            Scheduled start
                          </div>
                          <div className="mt-1 text-sm font-medium text-primary">
                            {formatScheduleDateTime(
                              currentSchedule.scheduled_start_at,
                              currentSchedule.timezone,
                            )}
                          </div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                            Scheduled end
                          </div>
                          <div className="mt-1 text-sm font-medium text-primary">
                            {formatScheduleDateTime(
                              currentSchedule.scheduled_end_at,
                              currentSchedule.timezone,
                            )}
                          </div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                            Location
                          </div>
                          <div className="mt-1 text-sm font-medium text-primary">
                            {currentSchedule.location_type}
                          </div>
                          <div className="mt-1 text-xs text-muted-foreground">
                            {currentSchedule.location_details ?? "No additional location details"}
                          </div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                            Schedule version
                          </div>
                          <div className="mt-1 font-serif text-xl text-primary">
                            {currentSchedule.schedule_version}
                          </div>
                          <div className="mt-1 text-xs text-muted-foreground">
                            {currentSchedule.timezone}
                          </div>
                        </div>
                      </div>

                      <Card className="mt-5 p-4">
                        <p className="text-xs leading-5 text-muted-foreground">
                          {currentSchedule.schedule_state === "proposed"
                            ? "This shoot plan is proposed only. It does not reserve or confirm the date."
                            : "This is the current authoritative reserved shoot schedule."}
                        </p>

                        {canConfirmBooking && !isActiveForm("propose") ? (
                          <BookingConfirmationControl
                            bookingId={booking.id}
                            onSuccess={refreshBookingWorkspace}
                          />
                        ) : null}

                        {canPropose && !isActiveForm("propose") ? (
                          <button
                            type="button"
                            onClick={() =>
                              setActiveForm({ bookingId: booking.id, mode: "propose" })
                            }
                            className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
                          >
                            Propose changed schedule
                          </button>
                        ) : null}

                        {canReschedule && !isActiveForm("reschedule") ? (
                          <button
                            type="button"
                            onClick={() =>
                              setActiveForm({ bookingId: booking.id, mode: "reschedule" })
                            }
                            className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
                          >
                            Reschedule
                          </button>
                        ) : null}

                        {canPropose && isActiveForm("propose") ? (
                          <ScheduleMutationForm
                            mode="propose"
                            bookingId={booking.id}
                            onCancel={() => setActiveForm(null)}
                            onSuccess={refreshBookingWorkspace}
                          />
                        ) : null}

                        {canReschedule && isActiveForm("reschedule") ? (
                          <ScheduleMutationForm
                            mode="reschedule"
                            bookingId={booking.id}
                            onCancel={() => setActiveForm(null)}
                            onSuccess={refreshBookingWorkspace}
                          />
                        ) : null}
                      </Card>

                      <div className="mt-6">
                        <div className="mb-4">
                          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                            Immutable schedule history
                          </div>
                          <h4 className="mt-1 font-serif text-lg text-primary">
                            Recorded schedule lineage
                          </h4>
                        </div>

                        <ScheduleHistory schedules={scheduleHistory} />
                      </div>
                    </>
                  )}
                </div>

                {data.canReadPreparation ? (
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

                <BookingTeamReadSurface assignments={bookingTeamAssignmentHistory} />

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
                      Journey advancement remains controlled by dedicated server-enforced
                      operations. This screen does not expose a general stage-transition control.
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
                    Advance Pending is a workflow state, not proof of payment. Authorized users can
                    read canonical advance evidence and record new immutable payment evidence above
                    while the Stage 7 advance remains outstanding. A proposed shoot plan is not a
                    reservation. When the Stage 7 advance is satisfied and a proposed shoot plan
                    exists, an actor with booking.confirm can use the dedicated confirmation control
                    above. That operation confirms the booking, reserves the current proposal and
                    advances exactly to Stage 8. Authorized users may read canonical pre-shoot
                    preparation evidence above when it exists. Preparation mutation, payment
                    reversal, safety, team assignment and general journey advancement remain
                    controlled by separate authoritative gates and are not exposed on this screen.
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
