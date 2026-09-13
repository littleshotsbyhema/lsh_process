import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { ExternalLink } from "lucide-react";

import { AppShell, PageHeader, StatusPill } from "@/components/AppShell";
import {
  ActionButton,
  Blocked,
  BoardState,
  BookingCard,
  Checkbox,
  ErrorNote,
  EvidenceLine,
  Field,
  TextInput,
  formatDate,
  formatInr,
  latestBy,
  rowsFor,
  useBookingsAtStages,
  useChainedAction,
  useDeliveryWorkspace,
  type BookingView,
} from "@/components/DeliveryBoard";
import {
  markAlbumFrameProduction,
  markDelivered,
  recordDeliveryConfirmation,
  recordGallery,
  type DeliveryWorkspaceData,
} from "@/lib/delivery.functions";

export const Route = createFileRoute("/_authenticated/pixieset")({
  head: () => ({
    meta: [
      { title: "Gallery & Delivery · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Record the client gallery and confirm delivery to the family, with the outstanding balance checked first.",
      },
      { property: "og:title", content: "Gallery & Delivery · LittleShots by Hema OS" },
    ],
  }),
  component: DeliveryPage,
});

const DELIVERY_STAGES = [16, 17];

function DeliveryPage() {
  const { query, refresh } = useDeliveryWorkspace();
  const action = useChainedAction(refresh);
  const bookings = useBookingsAtStages(query.data, DELIVERY_STAGES);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Gallery & Delivery"
        subtitle="The gallery address and its access settings are recorded here. Passwords are not — those go to the family directly and never sit in the system."
        quote="Delivery waits on the balance being settled, unless you decide otherwise and say why."
      />

      <ErrorNote message={action.error} />

      <BoardState
        query={query}
        count={bookings.length}
        emptyTitle="No galleries waiting"
        emptyBody="Once a batch clears quality control, the booking arrives here ready for its gallery."
      />

      <div className="mt-6 space-y-4">
        {query.data &&
          bookings.map((booking) => (
            <DeliveryBookingCard
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

function DeliveryBookingCard({
  booking,
  data,
  action,
}: {
  booking: BookingView;
  data: DeliveryWorkspaceData;
  action: ChainedAction;
}) {
  const gallery = latestBy(rowsFor(data.galleries, booking.id), (row) => row.round);
  const confirmation = rowsFor(data.deliveryConfirmations, booking.id)[0];
  const balance = data.balances[booking.id];
  const busy = action.isBusy(booking.id);

  const outstanding = balance?.outstandingInr ?? 0;

  return (
    <BookingCard
      booking={booking}
      aside={
        balance ? (
          <StatusPill tone={outstanding > 0 ? "warn" : "good"}>
            {outstanding > 0 ? `${formatInr(outstanding)} outstanding` : "Paid in full"}
          </StatusPill>
        ) : undefined
      }
    >
      {gallery && (
        <div className="grid gap-1">
          <a
            href={gallery.gallery_url}
            target="_blank"
            rel="noreferrer noopener"
            className="inline-flex items-center gap-1.5 text-sm text-primary underline underline-offset-4"
          >
            {gallery.gallery_url}
            <ExternalLink className="h-3 w-3" />
          </a>
          <EvidenceLine>
            {gallery.password_protected ? "Password protected" : "No password"} ·{" "}
            {gallery.downloads_enabled ? "Downloads on" : "Downloads off"} ·{" "}
            {gallery.expires_at ? `Expires ${formatDate(gallery.expires_at)}` : "No expiry"}
          </EvidenceLine>
        </div>
      )}

      {confirmation && (
        <EvidenceLine>
          Delivered with {formatInr(confirmation.outstanding_inr)} outstanding
          {confirmation.balance_override_reason ? ` — ${confirmation.balance_override_reason}` : ""}
        </EvidenceLine>
      )}

      {booking.stageOrder === 16 && !gallery && (
        <GalleryForm booking={booking} action={action} busy={busy} />
      )}

      {booking.stageOrder === 16 && gallery && (
        <ConfirmPanel booking={booking} action={action} busy={busy} outstanding={outstanding} />
      )}

      {booking.stageOrder === 17 && (
        <div>
          {booking.capabilities.canAdvanceStage ? (
            <ActionButton
              busy={busy}
              onClick={() =>
                action.run(booking.id, [
                  () => markAlbumFrameProduction({ data: { bookingId: booking.id } }),
                ])
              }
            >
              Start album & frame production
            </ActionButton>
          ) : (
            <Blocked reason="Moving this booking on needs the booking.stage.advance permission." />
          )}
        </div>
      )}
    </BookingCard>
  );
}

function GalleryForm({
  booking,
  action,
  busy,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
}) {
  const [url, setUrl] = useState("");
  const [passwordProtected, setPasswordProtected] = useState(true);
  const [downloadsEnabled, setDownloadsEnabled] = useState(true);
  const [expiresOn, setExpiresOn] = useState("");
  const [note, setNote] = useState("");

  if (!booking.capabilities.canConfirmDelivery) {
    return <Blocked reason="Recording a gallery needs the delivery.confirm permission." />;
  }

  const valid = url.trim().startsWith("https://") && url.trim().length > 10;

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <div className="sm:col-span-2">
        <Field label="Gallery address">
          <TextInput
            id={`url-${booking.id}`}
            value={url}
            onChange={(event) => setUrl(event.target.value)}
            placeholder="https://littleshots.pixieset.com/family/"
            maxLength={500}
          />
        </Field>
      </div>

      <Field label="Expires on (optional)">
        <TextInput
          id={`expiry-${booking.id}`}
          type="date"
          value={expiresOn}
          onChange={(event) => setExpiresOn(event.target.value)}
        />
      </Field>

      <Field label="Note (optional)">
        <TextInput
          id={`gallery-note-${booking.id}`}
          value={note}
          onChange={(event) => setNote(event.target.value)}
          maxLength={500}
        />
      </Field>

      <div className="flex flex-wrap items-center gap-4 sm:col-span-2">
        <Checkbox
          id={`pw-${booking.id}`}
          label="Password protected"
          checked={passwordProtected}
          onChange={setPasswordProtected}
        />
        <Checkbox
          id={`dl-${booking.id}`}
          label="Downloads enabled"
          checked={downloadsEnabled}
          onChange={setDownloadsEnabled}
        />
      </div>

      <div className="sm:col-span-2">
        <ActionButton
          busy={busy}
          disabled={!valid}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordGallery({
                  data: {
                    bookingId: booking.id,
                    galleryUrl: url.trim(),
                    passwordProtected,
                    downloadsEnabled,
                    expiresAt: expiresOn ? new Date(`${expiresOn}T23:59:00`).toISOString() : null,
                    note: note.trim() || undefined,
                  },
                }),
            ])
          }
        >
          Save gallery
        </ActionButton>
        <p className="mt-2 text-xs text-muted-foreground">
          The password itself is never stored. Send it to the family the way you always have.
        </p>
      </div>
    </div>
  );
}

function ConfirmPanel({
  booking,
  action,
  busy,
  outstanding,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  outstanding: number;
}) {
  const [reason, setReason] = useState("");

  if (!booking.capabilities.canConfirmDelivery) {
    return <Blocked reason="Confirming delivery needs the delivery.confirm permission." />;
  }

  const needsOverride = outstanding > 0;
  const canOverride = booking.capabilities.canOverrideBalance;

  if (needsOverride && !canOverride) {
    return (
      <Blocked
        reason={`${formatInr(outstanding)} is still outstanding. Delivering anyway needs the delivery.balance_override permission, which only the Founder holds.`}
      />
    );
  }

  return (
    <div className="space-y-3">
      {needsOverride && (
        <Field label={`Why deliver with ${formatInr(outstanding)} outstanding?`}>
          <TextInput
            id={`override-${booking.id}`}
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            maxLength={500}
            placeholder="e.g. balance being settled at album handover, agreed with the family"
          />
        </Field>
      )}

      <ActionButton
        busy={busy}
        disabled={needsOverride && reason.trim().length === 0}
        onClick={() =>
          action.run(booking.id, [
            () =>
              recordDeliveryConfirmation({
                data: {
                  bookingId: booking.id,
                  balanceOverrideReason: needsOverride ? reason.trim() : undefined,
                },
              }),
            () => markDelivered({ data: { bookingId: booking.id } }),
          ])
        }
      >
        {needsOverride ? "Deliver with balance outstanding" : "Confirm delivery"}
      </ActionButton>

      {needsOverride && (
        <p className="text-xs text-muted-foreground">
          Your reason and the {formatInr(outstanding)} owed are both recorded against this booking.
        </p>
      )}
    </div>
  );
}
