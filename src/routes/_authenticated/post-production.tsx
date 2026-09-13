import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";

import { AppShell, PageHeader } from "@/components/AppShell";
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
  formatDateTime,
  latestBy,
  rowsFor,
  useBookingsAtStages,
  useChainedAction,
  useDeliveryWorkspace,
  type BookingView,
} from "@/components/DeliveryBoard";
import {
  assignEditing,
  markEditingInProgress,
  markEditingRework,
  markGalleryReady,
  markQcPending,
  recordEditingCompletion,
  recordQcReview,
  recordVideoState,
  videoStates,
  type DeliveryWorkspaceData,
  type VideoState,
} from "@/lib/delivery.functions";

export const Route = createFileRoute("/_authenticated/post-production")({
  head: () => ({
    meta: [
      { title: "Post Production · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Editing rounds, the video track and quality control, from the first assignment to a gallery that is ready to send.",
      },
      { property: "og:title", content: "Post Production · LittleShots by Hema OS" },
    ],
  }),
  component: PostProductionPage,
});

const POST_PRODUCTION_STAGES = [13, 14, 15];

const videoStateLabels: Record<VideoState, string> = {
  not_applicable: "No video on this booking",
  in_progress: "Video being edited",
  complete: "Video finished",
};

function PostProductionPage() {
  const { query, refresh } = useDeliveryWorkspace();
  const action = useChainedAction(refresh);
  const bookings = useBookingsAtStages(query.data, POST_PRODUCTION_STAGES);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Post Production"
        subtitle="Photo editing, the video track and quality control in one place. Work moves editor to reviewer and back again, and every round is recorded, so a job that bounced twice is visible as such."
        quote="Care is the method. Nothing reaches a family until someone has looked at it properly."
      />

      <ErrorNote message={action.error} />

      <BoardState
        query={query}
        count={bookings.length}
        emptyTitle="Nothing waiting on post production"
        emptyBody="When a family finishes choosing their images, the booking arrives here for editing."
      />

      <div className="mt-6">
        <BreachSummary bookings={bookings} />
      </div>

      <div className="space-y-4">
        {query.data &&
          bookings.map((booking) => (
            <PostProductionBookingCard
              key={booking.id}
              booking={booking}
              data={query.data}
              action={action}
            />
          ))}
      </div>
    </AppShell>
  );
}

type ChainedAction = ReturnType<typeof useChainedAction>;

function PostProductionBookingCard({
  booking,
  data,
  action,
}: {
  booking: BookingView;
  data: DeliveryWorkspaceData;
  action: ChainedAction;
}) {
  const assignments = rowsFor(data.editingAssignments, booking.id);
  const completions = rowsFor(data.editingCompletions, booking.id);
  const reviews = rowsFor(data.qcReviews, booking.id);
  const video = latestBy(rowsFor(data.videoWork, booking.id), (row) => row.round);

  const latestAssignment = latestBy(assignments, (row) => row.round);
  const latestCompletion = latestBy(completions, (row) => row.round);
  const latestReview = latestBy(reviews, (row) => row.round);

  const memberName = (memberId: string | null) => {
    if (!memberId) return "Unassigned";
    const member = data.members.find((candidate) => candidate.id === memberId);
    return member?.display_name || member?.email || "Team member";
  };

  const busy = action.isBusy(booking.id);
  const reworkCount = reviews.filter((review) => review.outcome === "rework").length;
  const videoInProgress = video?.state === "in_progress";

  return (
    <BookingCard booking={booking}>
      <div className="grid gap-1">
        {latestAssignment && (
          <EvidenceLine>
            Editor: {memberName(latestAssignment.editor_member_id)} · round{" "}
            {latestAssignment.round}
          </EvidenceLine>
        )}
        {latestCompletion && (
          <EvidenceLine>
            Last submitted: {latestCompletion.edited_image_count} images,{" "}
            {formatDateTime(latestCompletion.completed_at)}
          </EvidenceLine>
        )}
        {latestReview?.outcome === "rework" && latestReview.review_note && (
          <EvidenceLine>Rework asked for: {latestReview.review_note}</EvidenceLine>
        )}
        {reworkCount > 0 && (
          <EvidenceLine>
            Sent back {reworkCount} {reworkCount === 1 ? "time" : "times"} so far
          </EvidenceLine>
        )}
      </div>

      {booking.stageOrder === 13 && (
        <AssignPanel booking={booking} data={data} action={action} busy={busy} />
      )}

      {booking.stageOrder === 14 && (
        <CompletePanel booking={booking} action={action} busy={busy} />
      )}

      {booking.stageOrder === 15 && (
        <QcPanel
          booking={booking}
          action={action}
          busy={busy}
          videoInProgress={videoInProgress}
        />
      )}

      <VideoPanel booking={booking} action={action} busy={busy} current={video?.state ?? null} />
    </BookingCard>
  );
}

function VideoPanel({
  booking,
  action,
  busy,
  current,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  current: VideoState | null;
}) {
  const [state, setState] = useState<VideoState>(current ?? "in_progress");

  return (
    <div className="rounded-lg border border-border bg-background/60 p-3">
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">Video</div>

      <p className="mt-1 text-xs text-muted-foreground">
        {current
          ? videoStateLabels[current]
          : "Video is optional. Most sessions are photo only, and a booking with nothing recorded here needs no decision."}
      </p>

      {booking.capabilities.canCompleteEditing ? (
        <div className="mt-3 flex flex-wrap items-end gap-3">
          <Field label="Where the video stands">
            <Select
              id={`video-state-${booking.id}`}
              value={state}
              onChange={(event) => setState(event.target.value as VideoState)}
            >
              {videoStates.map((value) => (
                <option key={value} value={value}>
                  {videoStateLabels[value]}
                </option>
              ))}
            </Select>
          </Field>

          <ActionButton
            tone="quiet"
            busy={busy}
            onClick={() =>
              action.run(booking.id, [
                () => recordVideoState({ data: { bookingId: booking.id, state } }),
              ])
            }
          >
            Save video state
          </ActionButton>
        </div>
      ) : (
        <div className="mt-3">
          <Blocked reason="Recording where the video stands needs the editing.complete permission." />
        </div>
      )}
    </div>
  );
}

function AssignPanel({
  booking,
  data,
  action,
  busy,
}: {
  booking: BookingView;
  data: DeliveryWorkspaceData;
  action: ChainedAction;
  busy: boolean;
}) {
  const [editorId, setEditorId] = useState("");
  const [note, setNote] = useState("");

  if (!booking.capabilities.canAssignEditing) {
    return <Blocked reason="Assigning editing needs the editing.assign permission." />;
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <Field label="Editor">
        <Select
          id={`editor-${booking.id}`}
          value={editorId}
          onChange={(event) => setEditorId(event.target.value)}
        >
          <option value="">Choose a team member…</option>
          {data.members.map((member) => (
            <option key={member.id} value={member.id}>
              {member.display_name || member.email || member.id}
            </option>
          ))}
        </Select>
      </Field>

      <Field label="Note (optional)">
        <TextInput
          id={`assign-note-${booking.id}`}
          value={note}
          onChange={(event) => setNote(event.target.value)}
          maxLength={500}
          placeholder="Anything the editor should know"
        />
      </Field>

      <div className="sm:col-span-2">
        <ActionButton
          busy={busy}
          disabled={!editorId}
          onClick={() =>
            action.run(booking.id, [
              () =>
                assignEditing({
                  data: {
                    bookingId: booking.id,
                    editorMemberId: editorId,
                    note: note.trim() || undefined,
                  },
                }),
              () => markEditingInProgress({ data: { bookingId: booking.id } }),
            ])
          }
        >
          Assign &amp; start editing
        </ActionButton>
      </div>
    </div>
  );
}

function CompletePanel({
  booking,
  action,
  busy,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
}) {
  const [count, setCount] = useState("");
  const [note, setNote] = useState("");

  if (!booking.capabilities.canCompleteEditing) {
    return <Blocked reason="Submitting edited work needs the editing.complete permission." />;
  }

  const parsed = Number.parseInt(count, 10);
  const valid = Number.isFinite(parsed) && parsed >= 1 && parsed <= 100000;

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <Field label="Edited images">
        <TextInput
          id={`count-${booking.id}`}
          value={count}
          onChange={(event) => setCount(event.target.value.replace(/\D/g, "").slice(0, 6))}
          inputMode="numeric"
          placeholder="How many finished frames"
        />
      </Field>

      <Field label="Note (optional)">
        <TextInput
          id={`complete-note-${booking.id}`}
          value={note}
          onChange={(event) => setNote(event.target.value)}
          maxLength={500}
          placeholder="Anything the reviewer should know"
        />
      </Field>

      <div className="sm:col-span-2">
        <ActionButton
          busy={busy}
          disabled={!valid}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordEditingCompletion({
                  data: {
                    bookingId: booking.id,
                    editedImageCount: parsed,
                    note: note.trim() || undefined,
                  },
                }),
              () => markQcPending({ data: { bookingId: booking.id } }),
            ])
          }
        >
          Mark complete &amp; send to QC
        </ActionButton>
      </div>
    </div>
  );
}

function QcPanel({
  booking,
  action,
  busy,
  videoInProgress,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  videoInProgress: boolean;
}) {
  const [note, setNote] = useState("");

  if (!booking.capabilities.canReviewQc) {
    return <Blocked reason="Approving or returning work needs the qc.review permission." />;
  }

  if (videoInProgress) {
    return (
      <Blocked reason="Quality control is waiting because the video is still in progress. Mark the video finished, or say it does not apply, and this opens up." />
    );
  }

  return (
    <div className="space-y-3">
      <Field label="What needs changing (required to send back)">
        <TextInput
          id={`qc-note-${booking.id}`}
          value={note}
          onChange={(event) => setNote(event.target.value)}
          maxLength={1000}
          placeholder="e.g. skin tones too warm on the last twelve frames"
        />
      </Field>

      <div className="flex flex-wrap gap-2">
        <ActionButton
          busy={busy}
          onClick={() =>
            action.run(booking.id, [
              () => recordQcReview({ data: { bookingId: booking.id, outcome: "approved" } }),
              () => markGalleryReady({ data: { bookingId: booking.id } }),
            ])
          }
        >
          Approve &amp; prepare gallery
        </ActionButton>

        <ActionButton
          tone="quiet"
          busy={busy}
          disabled={note.trim().length === 0}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordQcReview({
                  data: { bookingId: booking.id, outcome: "rework", note: note.trim() },
                }),
              () => markEditingRework({ data: { bookingId: booking.id } }),
            ])
          }
        >
          Send back for rework
        </ActionButton>
      </div>
    </div>
  );
}
