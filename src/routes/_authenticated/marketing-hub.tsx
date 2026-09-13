import { useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { CalendarHeart, Star } from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  ActionButton,
  Blocked,
  BoardState,
  BookingCard,
  BreachSummary,
  ErrorNote,
  EvidenceLine,
  Field,
  Select,
  TextInput,
  formatDate,
  latestBy,
  rowsFor,
  useBookingsAtStages,
  useChainedAction,
  useDeliveryWorkspace,
  type BookingView,
} from "@/components/DeliveryBoard";
import { availableModuleLinks } from "@/lib/access";
import {
  markCompleted,
  markMilestoneFollowUp,
  milestoneCategories,
  recordMilestonePlan,
  recordReviewRequest,
  reviewChannels,
  type DeliveryWorkspaceData,
  type MilestoneCategory,
  type ReviewChannel,
} from "@/lib/delivery.functions";

export const Route = createFileRoute("/_authenticated/marketing-hub")({
  head: () => ({
    meta: [
      { title: "Marketing · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Ask for a review after handover, plan when the family should next be invited back, and close the booking.",
      },
      { property: "og:title", content: "Marketing · LittleShots by Hema OS" },
    ],
  }),
  component: MarketingHubPage,
});

const MARKETING_STAGES = [19, 20, 21];

const channelLabels: Record<ReviewChannel, string> = {
  google: "Google",
  instagram: "Instagram",
  whatsapp: "WhatsApp",
  in_person: "In person",
  other: "Other",
};

const categoryLabels: Record<MilestoneCategory, string> = {
  maternity: "Maternity",
  newborn: "Newborn",
  sitter: "Sitter",
  birthday: "Birthday",
  family: "Family",
  other: "Other",
};

function MarketingHubPage() {
  const { query, refresh } = useDeliveryWorkspace();
  const action = useChainedAction(refresh);
  const bookings = useBookingsAtStages(query.data, MARKETING_STAGES);
  const links = availableModuleLinks("/marketing-hub");

  return (
    <AppShell>
      <PageHeader
        eyebrow="Family relationship"
        title="Marketing"
        subtitle="A booking does not close until the next milestone has a date on it. Newborn becomes sitter becomes first birthday."
        quote="Memory is the outcome. The relationship outlives the booking."
      />

      <ErrorNote message={action.error} />

      <BoardState
        query={query}
        count={bookings.length}
        emptyTitle="No families in aftercare"
        emptyBody="Once a gallery or an album has reached a family, the booking arrives here to ask for a review and plan what comes next."
      />

      <div className="mt-6">
        <BreachSummary bookings={bookings} />
      </div>

      <div className="space-y-4">
        {query.data &&
          bookings.map((booking) => (
            <MarketingCard key={booking.id} booking={booking} data={query.data} action={action} />
          ))}
      </div>

      {links.length > 0 && (
        <Card className="mt-8 p-5">
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Related screens
          </div>
          <ul className="mt-3 space-y-2">
            {links.map((link) => (
              <li key={link.to}>
                <Link to={link.to} className="text-sm text-primary underline underline-offset-4">
                  {link.label}
                </Link>
                <span className="text-xs text-muted-foreground"> — {link.description}</span>
              </li>
            ))}
          </ul>
        </Card>
      )}
    </AppShell>
  );
}

type ChainedAction = ReturnType<typeof useChainedAction>;

function MarketingCard({
  booking,
  data,
  action,
}: {
  booking: BookingView;
  data: DeliveryWorkspaceData;
  action: ChainedAction;
}) {
  const requests = rowsFor(data.reviewRequests, booking.id);
  const plan = rowsFor(data.milestonePlans, booking.id)[0];
  const latestRequest = latestBy(requests, (row) => row.round);
  const busy = action.isBusy(booking.id);

  return (
    <BookingCard
      booking={booking}
      aside={
        booking.stageOrder === 21 ? (
          <StatusPill tone="good">Relationship active</StatusPill>
        ) : undefined
      }
    >
      <div className="grid gap-1">
        {latestRequest && (
          <EvidenceLine>
            Review asked via{" "}
            {channelLabels[latestRequest.channel as ReviewChannel] ?? latestRequest.channel}
            {requests.length > 1 ? ` · ${requests.length} asks` : ""} ·{" "}
            {formatDate(latestRequest.requested_at)}
          </EvidenceLine>
        )}
        {plan && (
          <EvidenceLine>
            Next:{" "}
            {categoryLabels[plan.next_session_category as MilestoneCategory] ??
              plan.next_session_category}{" "}
            session, due {formatDate(plan.due_on)}
            {plan.offer_note ? ` — ${plan.offer_note}` : ""}
          </EvidenceLine>
        )}
      </div>

      {booking.stageOrder === 19 && (
        <ReviewPanel
          booking={booking}
          action={action}
          busy={busy}
          hasRequest={requests.length > 0}
        />
      )}

      {booking.stageOrder === 20 && (
        <MilestonePanel booking={booking} action={action} busy={busy} hasPlan={Boolean(plan)} />
      )}

      {booking.stageOrder === 21 && (
        <CompletedSummary
          askedVia={
            latestRequest
              ? (channelLabels[latestRequest.channel as ReviewChannel] ?? latestRequest.channel)
              : null
          }
          askCount={requests.length}
          nextCategory={
            plan
              ? (categoryLabels[plan.next_session_category as MilestoneCategory] ??
                plan.next_session_category)
              : null
          }
          nextDueOn={plan ? plan.due_on : null}
        />
      )}
    </BookingCard>
  );
}

function CompletedSummary({
  askedVia,
  askCount,
  nextCategory,
  nextDueOn,
}: {
  askedVia: string | null;
  askCount: number;
  nextCategory: string | null;
  nextDueOn: string | null;
}) {
  return (
    <div className="rounded-lg border border-border bg-background/60 p-3">
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
        How this one finished
      </div>

      <ul className="mt-2 space-y-1 text-sm text-foreground">
        <li>
          {askedVia
            ? `Review asked via ${askedVia}${askCount > 1 ? `, ${askCount} times in all` : ""}.`
            : "No review was asked for."}
        </li>
        <li>
          {nextCategory && nextDueOn
            ? `Next session planned: ${nextCategory}, around ${formatDate(nextDueOn)}.`
            : "No next session was planned."}
        </li>
      </ul>

      <p className="mt-2 text-xs text-muted-foreground">
        This booking is closed. Nothing more is asked of the studio here.
      </p>
    </div>
  );
}

function ReviewPanel({
  booking,
  action,
  busy,
  hasRequest,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  hasRequest: boolean;
}) {
  const [channel, setChannel] = useState<ReviewChannel>("google");
  const [note, setNote] = useState("");

  if (!booking.capabilities.canRequestReview) {
    return <Blocked reason="Recording a review request needs the review.request permission." />;
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <Field label="Where did you ask?">
        <Select
          id={`channel-${booking.id}`}
          value={channel}
          onChange={(event) => setChannel(event.target.value as ReviewChannel)}
        >
          {reviewChannels.map((value) => (
            <option key={value} value={value}>
              {channelLabels[value]}
            </option>
          ))}
        </Select>
      </Field>

      <Field label="Note (optional)">
        <TextInput
          id={`review-note-${booking.id}`}
          value={note}
          onChange={(event) => setNote(event.target.value)}
          maxLength={500}
          placeholder="e.g. asked at handover"
        />
      </Field>

      <div className="flex flex-wrap gap-2 sm:col-span-2">
        <ActionButton
          tone={hasRequest ? "quiet" : "primary"}
          busy={busy}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordReviewRequest({
                  data: { bookingId: booking.id, channel, note: note.trim() || undefined },
                }),
            ])
          }
        >
          <Star className="h-3.5 w-3.5" />{" "}
          {hasRequest ? "Record a follow-up ask" : "Record review request"}
        </ActionButton>

        {hasRequest &&
          (booking.capabilities.canAdvanceStage ? (
            <ActionButton
              busy={busy}
              onClick={() =>
                action.run(booking.id, [
                  () => markMilestoneFollowUp({ data: { bookingId: booking.id } }),
                ])
              }
            >
              Plan the next session
            </ActionButton>
          ) : (
            <Blocked reason="Moving this booking on needs the booking.stage.advance permission." />
          ))}
      </div>
    </div>
  );
}

function MilestonePanel({
  booking,
  action,
  busy,
  hasPlan,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  hasPlan: boolean;
}) {
  const [category, setCategory] = useState<MilestoneCategory>("sitter");
  const [dueOn, setDueOn] = useState("");
  const [offer, setOffer] = useState("");

  if (!booking.capabilities.canPlanMilestone && !hasPlan) {
    return <Blocked reason="Planning the next session needs the milestone.plan permission." />;
  }

  const today = new Date().toISOString().slice(0, 10);
  const valid = dueOn > today;

  return (
    <div className="space-y-3">
      {!hasPlan && (
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="What comes next?">
            <Select
              id={`cat-${booking.id}`}
              value={category}
              onChange={(event) => setCategory(event.target.value as MilestoneCategory)}
            >
              {milestoneCategories.map((value) => (
                <option key={value} value={value}>
                  {categoryLabels[value]}
                </option>
              ))}
            </Select>
          </Field>

          <Field label="Approach the family around">
            <TextInput
              id={`due-${booking.id}`}
              type="date"
              min={today}
              value={dueOn}
              onChange={(event) => setDueOn(event.target.value)}
            />
          </Field>

          <div className="sm:col-span-2">
            <Field label="What to offer (optional)">
              <TextInput
                id={`offer-${booking.id}`}
                value={offer}
                onChange={(event) => setOffer(event.target.value)}
                maxLength={500}
                placeholder="e.g. sitter session around seven months"
              />
            </Field>
          </div>

          <div className="sm:col-span-2">
            <ActionButton
              busy={busy}
              disabled={!valid}
              onClick={() =>
                action.run(booking.id, [
                  () =>
                    recordMilestonePlan({
                      data: {
                        bookingId: booking.id,
                        nextSessionCategory: category,
                        dueOn,
                        offerNote: offer.trim() || undefined,
                      },
                    }),
                ])
              }
            >
              <CalendarHeart className="h-3.5 w-3.5" /> Save the plan
            </ActionButton>
            <p className="mt-2 text-xs text-muted-foreground">
              This is a note to the studio, not a booking. Nobody is contacted automatically.
            </p>
          </div>
        </div>
      )}

      {hasPlan &&
        (booking.capabilities.canAdvanceStage ? (
          <ActionButton
            busy={busy}
            onClick={() =>
              action.run(booking.id, [() => markCompleted({ data: { bookingId: booking.id } })])
            }
          >
            Close this booking
          </ActionButton>
        ) : (
          <Blocked reason="Closing a booking needs the booking.stage.advance permission." />
        ))}
    </div>
  );
}
