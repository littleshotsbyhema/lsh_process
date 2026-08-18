import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { Check, Circle, Loader2 } from "lucide-react";
import { toast } from "sonner";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import {
  listBookingWorkspace,
  proposeShootSchedule,
  rescheduleShoot,
  type BookingJourneyStageRow,
  type BookingShootScheduleRow,
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

  const refreshBookingWorkspace = async () => {
    setActiveForm(null);
    await queryClient.invalidateQueries({ queryKey: ["booking-workspace"] });
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

            const currentOrder = currentStage?.stage_order ?? 0;

            const canPropose =
              data.canSchedule &&
              currentOrder === 7 &&
              (!currentSchedule || currentSchedule.schedule_state === "proposed");

            const canReschedule =
              data.canSchedule &&
              currentOrder >= 8 &&
              currentOrder <= 10 &&
              currentSchedule?.schedule_state === "reserved";

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
                    Advance Pending is a workflow state, not proof of payment. A proposed shoot plan
                    is not a reservation. Shoot schedule proposal and reschedule are available above
                    through the authoritative server-enforced RPC boundary where eligible. Booking
                    confirmation, payment, preparation, safety, team assignment and general journey
                    advancement remain controlled by separate authoritative gates and are not
                    exposed on this screen.
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
