import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";

import { AppShell, PageHeader } from "@/components/AppShell";
import {
  ActionButton,
  Blocked,
  BoardState,
  BookingCard,
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
  type DeliveryWorkspaceData,
} from "@/lib/delivery.functions";

export const Route = createFileRoute("/_authenticated/editing")({
  head: () => ({
    meta: [
      { title: "Editing & QC · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Assign editing rounds, record finished work and run quality control before a gallery reaches a family.",
      },
      { property: "og:title", content: "Editing & QC · LittleShots by Hema OS" },
    ],
  }),
  component: EditingPage,
});

const EDITING_STAGES = [13, 14, 15];

function EditingPage() {
  const { query, refresh } = useDeliveryWorkspace();
  const action = useChainedAction(refresh);
  const bookings = useBookingsAtStages(query.data, EDITING_STAGES);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Editing & QC"
        subtitle="Work moves editor to reviewer and back again. Every round is recorded, so a job that bounced twice is visible as such."
        quote="Care is the method. Nothing reaches a family until someone has looked at it properly."
      />

      <ErrorNote message={action.error} />

      <BoardState
        query={query}
        count={bookings.length}
        emptyTitle="Nothing waiting on editing"
        emptyBody="When a family finishes choosing their images, the booking arrives here for editing."
      />

      <div className="mt-6 space-y-4">
        {query.data &&
          bookings.map((booking) => (
            <EditingBookingCard
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

function EditingBookingCard({
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

  return (
    <BookingCard booking={booking}>
      <div className="grid gap-1">
        {latestAssignment && (
          <EvidenceLine>
            Editor: {memberName(latestAssignment.editor_member_id)} · round {latestAssignment.round}
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

      {booking.stageOrder === 14 && <CompletePanel booking={booking} action={action} busy={busy} />}

      {booking.stageOrder === 15 && <QcPanel booking={booking} action={action} busy={busy} />}
    </BookingCard>
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
          Assign & start editing
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
          Mark complete & send to QC
        </ActionButton>
      </div>
    </div>
  );
}

function QcPanel({
  booking,
  action,
  busy,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
}) {
  const [note, setNote] = useState("");

  if (!booking.capabilities.canReviewQc) {
    return <Blocked reason="Approving or returning work needs the qc.review permission." />;
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
          Approve & prepare gallery
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
