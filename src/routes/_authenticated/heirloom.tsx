import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { Check, Package, Send } from "lucide-react";

import { AppShell, PageHeader, StatusPill } from "@/components/AppShell";
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
  formatDate,
  formatDateTime,
  latestBy,
  rowsFor,
  useBookingsAtStages,
  useChainedAction,
  useDeliveryWorkspace,
  type BookingView,
} from "@/components/DeliveryBoard";
import {
  markReviewRequested,
  productionItemTypes,
  proofOutcomes,
  recordProductionItem,
  recordProductionMilestone,
  recordProductionProof,
  recordProofResponse,
  type DeliveryWorkspaceData,
  type ProductionItemType,
  type ProofOutcome,
} from "@/lib/delivery.functions";

export const Route = createFileRoute("/_authenticated/heirloom")({
  head: () => ({
    meta: [
      { title: "Heirloom Production · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Albums and frames from layout proof through production to studio handover, with the family approving before anything prints.",
      },
      { property: "og:title", content: "Heirloom Production · LittleShots by Hema OS" },
    ],
  }),
  component: HeirloomPage,
});

const PRODUCTION_STAGES = [18];

const itemTypeLabels: Record<ProductionItemType, string> = {
  album: "Album",
  frame: "Frame",
  other: "Other",
};

function HeirloomPage() {
  const { query, refresh } = useDeliveryWorkspace();
  const action = useChainedAction(refresh);
  const bookings = useBookingsAtStages(query.data, PRODUCTION_STAGES);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Heirloom Production"
        subtitle="Albums and frames, from layout proof to the moment a family carries them out of the studio. Nothing prints before the family has approved the layout."
        quote="Heirloom value is the point. A reprint is expensive; an unapproved album is worse."
      />

      <ErrorNote message={action.error} />

      <BoardState
        query={query}
        count={bookings.length}
        emptyTitle="Nothing in production"
        emptyBody="Once a gallery is delivered, the booking arrives here for its album and frames."
      />

      <div className="mt-6 space-y-4">
        {query.data &&
          bookings.map((booking) => (
            <ProductionCard key={booking.id} booking={booking} data={query.data} action={action} />
          ))}
      </div>
    </AppShell>
  );
}

type ChainedAction = ReturnType<typeof useChainedAction>;

function ProductionCard({
  booking,
  data,
  action,
}: {
  booking: BookingView;
  data: DeliveryWorkspaceData;
  action: ChainedAction;
}) {
  const items = rowsFor(data.productionItems, booking.id);
  const proofs = rowsFor(data.productionProofs, booking.id);
  const responses = rowsFor(data.proofResponses, booking.id);
  const milestones = rowsFor(data.productionMilestones, booking.id);

  const busy = action.isBusy(booking.id);
  const allowed = booking.capabilities.canManageProduction;

  const openProof = proofs.find(
    (proof) => !responses.some((response) => response.proof_id === proof.id),
  );
  const approved = responses.some((response) => response.outcome === "approved");
  const latestResponse = latestBy(responses, (row) => row.round);

  const milestoneOf = (type: string) =>
    milestones.find((milestone) => milestone.milestone_type === type);

  const dispatched = milestoneOf("dispatched");
  const received = milestoneOf("received");
  const handedOver = milestoneOf("handed_over");

  return (
    <BookingCard
      booking={booking}
      aside={
        handedOver ? (
          <StatusPill tone="good">Handed over</StatusPill>
        ) : dispatched ? (
          <StatusPill tone="warn">In production</StatusPill>
        ) : approved ? (
          <StatusPill tone="gold">Proof approved</StatusPill>
        ) : (
          <StatusPill tone="neutral">Proofing</StatusPill>
        )
      }
    >
      {items.length > 0 && (
        <div className="rounded-lg border border-border bg-background/60 p-3">
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            To produce
          </div>
          <ul className="mt-2 space-y-1">
            {items.map((item) => (
              <li key={item.id} className="text-sm text-foreground">
                {item.quantity} ×{" "}
                {itemTypeLabels[item.item_type as ProductionItemType] ?? item.item_type} —{" "}
                {item.description}
                <span className="text-muted-foreground">
                  {" "}
                  · {item.vendor_name ? item.vendor_name : "in-house"}
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <div className="grid gap-1">
        {proofs.length > 0 && (
          <EvidenceLine>
            {proofs.length} proof {proofs.length === 1 ? "round" : "rounds"} sent
            {latestResponse
              ? ` · last answer: ${latestResponse.outcome === "approved" ? "approved" : "changes requested"}`
              : " · awaiting the family"}
          </EvidenceLine>
        )}
        {latestResponse?.outcome === "changes_requested" && latestResponse.response_note && (
          <EvidenceLine>Family asked for: {latestResponse.response_note}</EvidenceLine>
        )}
        {dispatched && (
          <EvidenceLine>
            Dispatched {formatDateTime(dispatched.occurred_at)} ·{" "}
            {dispatched.vendor_name ?? "in-house"}
            {dispatched.expected_at ? ` · expected ${formatDate(dispatched.expected_at)}` : ""}
          </EvidenceLine>
        )}
        {received && <EvidenceLine>Received {formatDateTime(received.occurred_at)}</EvidenceLine>}
        {handedOver && (
          <EvidenceLine>
            Collected by {handedOver.collected_by_name} on {formatDateTime(handedOver.occurred_at)}
          </EvidenceLine>
        )}
      </div>

      {!allowed && <Blocked reason="Running production needs the production.manage permission." />}

      {allowed && !dispatched && <ItemForm booking={booking} action={action} busy={busy} />}

      {allowed && !approved && !openProof && (
        <ProofForm booking={booking} action={action} busy={busy} hasItems={items.length > 0} />
      )}

      {allowed && openProof && <ResponseForm booking={booking} action={action} busy={busy} />}

      {allowed && approved && !dispatched && (
        <DispatchForm booking={booking} action={action} busy={busy} />
      )}

      {allowed && dispatched && !received && (
        <ActionButton
          busy={busy}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordProductionMilestone({
                  data: { bookingId: booking.id, milestoneType: "received" },
                }),
            ])
          }
        >
          <Package className="h-3.5 w-3.5" /> Mark received from production
        </ActionButton>
      )}

      {allowed && received && !handedOver && (
        <HandoverForm booking={booking} action={action} busy={busy} />
      )}

      {handedOver && (
        <div>
          {booking.capabilities.canAdvanceStage ? (
            <ActionButton
              busy={busy}
              onClick={() =>
                action.run(booking.id, [
                  () => markReviewRequested({ data: { bookingId: booking.id } }),
                ])
              }
            >
              Move to review & aftercare
            </ActionButton>
          ) : (
            <Blocked reason="Moving this booking on needs the booking.stage.advance permission." />
          )}
        </div>
      )}
    </BookingCard>
  );
}

function ItemForm({
  booking,
  action,
  busy,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
}) {
  const [itemType, setItemType] = useState<ProductionItemType>("frame");
  const [description, setDescription] = useState("");
  const [quantity, setQuantity] = useState("1");
  const [vendor, setVendor] = useState("");

  const qty = Number.parseInt(quantity, 10);
  const valid = description.trim().length > 0 && Number.isFinite(qty) && qty >= 1 && qty <= 100;

  return (
    <details className="rounded-lg border border-border bg-background/60 p-3">
      <summary className="cursor-pointer text-sm text-primary">Add an item to produce</summary>

      <div className="mt-3 grid gap-3 sm:grid-cols-2">
        <Field label="Type">
          <Select
            id={`item-type-${booking.id}`}
            value={itemType}
            onChange={(event) => setItemType(event.target.value as ProductionItemType)}
          >
            {productionItemTypes.map((type) => (
              <option key={type} value={type}>
                {itemTypeLabels[type]}
              </option>
            ))}
          </Select>
        </Field>

        <Field label="Quantity">
          <TextInput
            id={`item-qty-${booking.id}`}
            value={quantity}
            onChange={(event) => setQuantity(event.target.value.replace(/\D/g, "").slice(0, 3))}
            inputMode="numeric"
          />
        </Field>

        <div className="sm:col-span-2">
          <Field label="Description">
            <TextInput
              id={`item-desc-${booking.id}`}
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              maxLength={300}
              placeholder="e.g. 10x10 Premium Album (15 Sheets / 30 Pages)"
            />
          </Field>
        </div>

        <div className="sm:col-span-2">
          <Field label="Vendor (leave blank if made in-house)">
            <TextInput
              id={`item-vendor-${booking.id}`}
              value={vendor}
              onChange={(event) => setVendor(event.target.value)}
              maxLength={160}
            />
          </Field>
        </div>

        <div className="sm:col-span-2">
          <ActionButton
            tone="quiet"
            busy={busy}
            disabled={!valid}
            onClick={() =>
              action.run(booking.id, [
                () =>
                  recordProductionItem({
                    data: {
                      bookingId: booking.id,
                      itemType,
                      description: description.trim(),
                      quantity: qty,
                      vendorName: vendor.trim() || undefined,
                    },
                  }),
              ])
            }
          >
            Add item
          </ActionButton>
        </div>
      </div>
    </details>
  );
}

function ProofForm({
  booking,
  action,
  busy,
  hasItems,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  hasItems: boolean;
}) {
  const [reference, setReference] = useState("");
  const [note, setNote] = useState("");

  if (!hasItems) {
    return <Blocked reason="Add the items being produced before sending a proof to the family." />;
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <div className="sm:col-span-2">
        <Field label="Proof reference sent to the family">
          <TextInput
            id={`proof-ref-${booking.id}`}
            value={reference}
            onChange={(event) => setReference(event.target.value)}
            maxLength={500}
            placeholder="Link or description of the layout you sent"
          />
        </Field>
      </div>

      <div className="sm:col-span-2">
        <Field label="Note (optional)">
          <TextInput
            id={`proof-note-${booking.id}`}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            maxLength={500}
          />
        </Field>
      </div>

      <div className="sm:col-span-2">
        <ActionButton
          busy={busy}
          disabled={reference.trim().length === 0}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordProductionProof({
                  data: {
                    bookingId: booking.id,
                    proofReference: reference.trim(),
                    note: note.trim() || undefined,
                  },
                }),
            ])
          }
        >
          <Send className="h-3.5 w-3.5" /> Record proof sent
        </ActionButton>
      </div>
    </div>
  );
}

function ResponseForm({
  booking,
  action,
  busy,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
}) {
  const [outcome, setOutcome] = useState<ProofOutcome>("approved");
  const [note, setNote] = useState("");

  const needsNote = outcome === "changes_requested";

  return (
    <div className="rounded-lg border border-gold/60 bg-accent/40 p-3">
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
        Awaiting the family
      </div>

      <div className="mt-3 grid gap-3 sm:grid-cols-2">
        <Field label="What did they say?">
          <Select
            id={`resp-outcome-${booking.id}`}
            value={outcome}
            onChange={(event) => setOutcome(event.target.value as ProofOutcome)}
          >
            {proofOutcomes.map((value) => (
              <option key={value} value={value}>
                {value === "approved" ? "Approved the layout" : "Asked for changes"}
              </option>
            ))}
          </Select>
        </Field>

        <Field label={needsNote ? "What they want changed (required)" : "Note (optional)"}>
          <TextInput
            id={`resp-note-${booking.id}`}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            maxLength={1000}
          />
        </Field>

        <div className="sm:col-span-2">
          <ActionButton
            busy={busy}
            disabled={needsNote && note.trim().length === 0}
            onClick={() =>
              action.run(booking.id, [
                () =>
                  recordProofResponse({
                    data: {
                      bookingId: booking.id,
                      outcome,
                      note: note.trim() || undefined,
                    },
                  }),
              ])
            }
          >
            <Check className="h-3.5 w-3.5" /> Record their response
          </ActionButton>
        </div>
      </div>
    </div>
  );
}

function DispatchForm({
  booking,
  action,
  busy,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
}) {
  const [vendor, setVendor] = useState("");
  const [expected, setExpected] = useState("");
  const [note, setNote] = useState("");

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <Field label="Vendor (leave blank if in-house)">
        <TextInput
          id={`disp-vendor-${booking.id}`}
          value={vendor}
          onChange={(event) => setVendor(event.target.value)}
          maxLength={160}
        />
      </Field>

      <Field label="Expected back (optional)">
        <TextInput
          id={`disp-expected-${booking.id}`}
          type="date"
          value={expected}
          onChange={(event) => setExpected(event.target.value)}
        />
      </Field>

      <div className="sm:col-span-2">
        <Field label="Note (optional)">
          <TextInput
            id={`disp-note-${booking.id}`}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            maxLength={500}
          />
        </Field>
      </div>

      <div className="sm:col-span-2">
        <ActionButton
          busy={busy}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordProductionMilestone({
                  data: {
                    bookingId: booking.id,
                    milestoneType: "dispatched",
                    vendorName: vendor.trim() || undefined,
                    expectedAt: expected ? new Date(`${expected}T12:00:00`).toISOString() : null,
                    detailNote: note.trim() || undefined,
                  },
                }),
            ])
          }
        >
          Send to production
        </ActionButton>
      </div>
    </div>
  );
}

function HandoverForm({
  booking,
  action,
  busy,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
}) {
  const [collectedBy, setCollectedBy] = useState("");
  const [note, setNote] = useState("");

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <Field label="Who collected it?">
        <TextInput
          id={`hand-by-${booking.id}`}
          value={collectedBy}
          onChange={(event) => setCollectedBy(event.target.value)}
          maxLength={160}
          placeholder="Name of the person collecting"
        />
      </Field>

      <Field label="Note (optional)">
        <TextInput
          id={`hand-note-${booking.id}`}
          value={note}
          onChange={(event) => setNote(event.target.value)}
          maxLength={500}
        />
      </Field>

      <div className="sm:col-span-2">
        <ActionButton
          busy={busy}
          disabled={collectedBy.trim().length === 0}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordProductionMilestone({
                  data: {
                    bookingId: booking.id,
                    milestoneType: "handed_over",
                    collectedByName: collectedBy.trim(),
                    detailNote: note.trim() || undefined,
                  },
                }),
            ])
          }
        >
          Record studio handover
        </ActionButton>
      </div>
    </div>
  );
}
