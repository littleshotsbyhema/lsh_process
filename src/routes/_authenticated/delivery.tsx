import { useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { Check, ExternalLink, Package, Send } from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  ActionButton,
  Blocked,
  BoardState,
  BookingCard,
  BreachSummary,
  Checkbox,
  ErrorNote,
  EvidenceLine,
  Field,
  Select,
  TextInput,
  formatDate,
  formatDateTime,
  formatInr,
  latestBy,
  rowsFor,
  useBookingsAtStages,
  useChainedAction,
  useDeliveryWorkspace,
  type BookingView,
} from "@/components/DeliveryBoard";
import { availableModuleLinks } from "@/lib/access";
import {
  markAlbumFrameProduction,
  markDelivered,
  markReviewRequested,
  productionItemTypes,
  proofOutcomes,
  recordDeliveryConfirmation,
  recordGallery,
  recordProductionItem,
  recordProductionMilestone,
  recordProductionNotApplicable,
  recordProductionProof,
  recordProofResponse,
  type DeliveryWorkspaceData,
  type ProductionItemType,
  type ProofOutcome,
} from "@/lib/delivery.functions";

export const Route = createFileRoute("/_authenticated/delivery")({
  head: () => ({
    meta: [
      { title: "Delivery · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Send the gallery, settle the balance and run album or frame production through to studio handover.",
      },
      { property: "og:title", content: "Delivery · LittleShots by Hema OS" },
    ],
  }),
  component: DeliveryModulePage,
});

const DELIVERY_STAGES = [16, 17, 18];

const itemTypeLabels: Record<ProductionItemType, string> = {
  album: "Album",
  frame: "Frame",
  other: "Other",
};

function DeliveryModulePage() {
  const { query, refresh } = useDeliveryWorkspace();
  const action = useChainedAction(refresh);
  const bookings = useBookingsAtStages(query.data, DELIVERY_STAGES);
  const links = availableModuleLinks("/delivery");

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Delivery"
        subtitle="The gallery, the balance and anything printed. A gallery link can go out at any balance, but downloads only switch on once the family has paid in full."
        quote="Delivery is the promise kept. Nothing printed until the family has approved it."
      />

      <ErrorNote message={action.error} />

      <BoardState
        query={query}
        count={bookings.length}
        emptyTitle="Nothing waiting on delivery"
        emptyBody="Once a batch clears quality control, the booking arrives here ready for its gallery."
      />

      <div className="mt-6">
        <BreachSummary bookings={bookings} />
      </div>

      <div className="space-y-4">
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
  const items = rowsFor(data.productionItems, booking.id);
  const balance = data.balances[booking.id];
  const busy = action.isBusy(booking.id);

  const outstanding = balance?.outstandingInr ?? 0;
  const paidInFull = outstanding <= 0;

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
          Sent with {formatInr(confirmation.outstanding_inr)} outstanding
          {confirmation.balance_override_reason ? ` — ${confirmation.balance_override_reason}` : ""}
        </EvidenceLine>
      )}

      {booking.stageOrder === 16 && !gallery && (
        <GalleryForm booking={booking} action={action} busy={busy} outstanding={outstanding} />
      )}

      {booking.stageOrder === 16 && gallery && (
        <SendPanel booking={booking} action={action} busy={busy} outstanding={outstanding} />
      )}

      {booking.stageOrder === 17 && (
        <DeliveredPanel
          booking={booking}
          action={action}
          busy={busy}
          outstanding={outstanding}
          downloadsEnabled={gallery?.downloads_enabled ?? false}
          galleryUrl={gallery?.gallery_url ?? ""}
          hasItems={items.length > 0}
        />
      )}

      {booking.stageOrder === 18 && (
        <ProductionPanel
          booking={booking}
          data={data}
          action={action}
          busy={busy}
          paidInFull={paidInFull}
          outstanding={outstanding}
        />
      )}
    </BookingCard>
  );
}

/* ───────────────── Stage 16 · gallery ready ───────────────── */

function GalleryForm({
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
  const [url, setUrl] = useState("");
  const [passwordProtected, setPasswordProtected] = useState(true);
  const [downloadsEnabled, setDownloadsEnabled] = useState(outstanding <= 0);

  if (!booking.capabilities.canConfirmDelivery) {
    return <Blocked reason="Recording a gallery needs the delivery.confirm permission." />;
  }

  const owed = outstanding > 0;
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

      <div className="flex flex-wrap items-center gap-4 sm:col-span-2">
        <Checkbox
          id={`pw-${booking.id}`}
          label="Password protected"
          checked={passwordProtected}
          onChange={setPasswordProtected}
        />
        {owed ? (
          <span className="text-sm text-muted-foreground">
            Downloads stay off while {formatInr(outstanding)} is owed
          </span>
        ) : (
          <Checkbox
            id={`dl-${booking.id}`}
            label="Downloads enabled"
            checked={downloadsEnabled}
            onChange={setDownloadsEnabled}
          />
        )}
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
                    downloadsEnabled: downloadsEnabled && !owed,
                  },
                }),
            ])
          }
        >
          Save the gallery
        </ActionButton>
        <p className="mt-2 text-xs text-muted-foreground">
          {owed
            ? `${formatInr(outstanding)} is still owed, so downloads stay off. The family can view the gallery now, and downloads can be switched on here once the balance is settled.`
            : "The balance is settled, so downloads can be switched on."}{" "}
          The password itself is never stored. Send it to the family the way you always have.
        </p>
      </div>
    </div>
  );
}

function SendPanel({
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
  if (!booking.capabilities.canConfirmDelivery) {
    return <Blocked reason="Sending the gallery needs the delivery.confirm permission." />;
  }

  const owed = outstanding > 0;

  return (
    <div className="space-y-3">
      <ActionButton
        busy={busy}
        onClick={() =>
          action.run(booking.id, [
            () => recordDeliveryConfirmation({ data: { bookingId: booking.id } }),
            () => markDelivered({ data: { bookingId: booking.id } }),
          ])
        }
      >
        <Send className="h-3.5 w-3.5" /> Send the gallery
      </ActionButton>

      {owed && (
        <p className="text-xs text-muted-foreground">
          {formatInr(outstanding)} is still owed. The gallery can go out anyway — only downloads
          and album or frame production wait on the balance.
        </p>
      )}
    </div>
  );
}

/* ───────────────── Stage 17 · delivered ───────────────── */

function DeliveredPanel({
  booking,
  action,
  busy,
  outstanding,
  downloadsEnabled,
  galleryUrl,
  hasItems,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  outstanding: number;
  downloadsEnabled: boolean;
  galleryUrl: string;
  hasItems: boolean;
}) {
  const [note, setNote] = useState("");

  const owed = outstanding > 0;
  const canReissue =
    booking.capabilities.canConfirmDelivery && !owed && !downloadsEnabled && galleryUrl.length > 0;

  return (
    <div className="space-y-4">
      {canReissue && (
        <div className="rounded-lg border border-gold/60 bg-accent/40 p-3">
          <div className="text-sm text-foreground">
            The balance is now clear, and this gallery still has downloads switched off.
          </div>
          <div className="mt-3">
            <ActionButton
              busy={busy}
              onClick={() =>
                action.run(booking.id, [
                  () =>
                    recordGallery({
                      data: {
                        bookingId: booking.id,
                        galleryUrl,
                        passwordProtected: true,
                        downloadsEnabled: true,
                        note: "Downloads opened after the balance was settled",
                      },
                    }),
                ])
              }
            >
              Re-issue the gallery with downloads on
            </ActionButton>
          </div>
        </div>
      )}

      {booking.capabilities.canAdvanceStage ? (
        <div className="space-y-3">
          <div className="rounded-lg border border-border bg-background/60 p-3">
            <div className="text-sm text-foreground">
              Is there an album or a frame for this family?
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              Most newborn sessions sell nothing physical. If this one does not, say so here and
              the booking moves straight to the review.
            </p>

            <div className="mt-3">
              <Field label="Note (optional)">
                <TextInput
                  id={`na-note-${booking.id}`}
                  value={note}
                  onChange={(event) => setNote(event.target.value)}
                  maxLength={500}
                  placeholder="e.g. digital only package"
                />
              </Field>
            </div>

            <div className="mt-3 flex flex-wrap gap-2">
              <ActionButton
                busy={busy}
                disabled={hasItems}
                onClick={() =>
                  action.run(booking.id, [
                    () =>
                      recordProductionNotApplicable({
                        data: { bookingId: booking.id, note: note.trim() || undefined },
                      }),
                    () => markReviewRequested({ data: { bookingId: booking.id } }),
                  ])
                }
              >
                No album or frame for this booking
              </ActionButton>

              <ActionButton
                tone="quiet"
                busy={busy}
                onClick={() =>
                  action.run(booking.id, [
                    () => markAlbumFrameProduction({ data: { bookingId: booking.id } }),
                  ])
                }
              >
                Start album &amp; frame production
              </ActionButton>
            </div>

            {hasItems && (
              <div className="mt-3">
                <Blocked reason="Items have already been added for this booking, so it has to go through production." />
              </div>
            )}
          </div>
        </div>
      ) : (
        <Blocked reason="Moving this booking on needs the booking.stage.advance permission." />
      )}
    </div>
  );
}

/* ───────────────── Stage 18 · album and frame production ───────────────── */

function ProductionPanel({
  booking,
  data,
  action,
  busy,
  paidInFull,
  outstanding,
}: {
  booking: BookingView;
  data: DeliveryWorkspaceData;
  action: ChainedAction;
  busy: boolean;
  paidInFull: boolean;
  outstanding: number;
}) {
  const items = rowsFor(data.productionItems, booking.id);
  const proofs = rowsFor(data.productionProofs, booking.id);
  const responses = rowsFor(data.proofResponses, booking.id);
  const milestones = rowsFor(data.productionMilestones, booking.id);

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
    <div className="space-y-4">
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

      {allowed && !dispatched && (
        <ItemForm
          booking={booking}
          action={action}
          busy={busy}
          paidInFull={paidInFull}
          outstanding={outstanding}
        />
      )}

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

      {handedOver &&
        (booking.capabilities.canAdvanceStage ? (
          <ActionButton
            busy={busy}
            onClick={() =>
              action.run(booking.id, [
                () => markReviewRequested({ data: { bookingId: booking.id } }),
              ])
            }
          >
            Move to the review
          </ActionButton>
        ) : (
          <Blocked reason="Moving this booking on needs the booking.stage.advance permission." />
        ))}
    </div>
  );
}

function ItemForm({
  booking,
  action,
  busy,
  paidInFull,
  outstanding,
}: {
  booking: BookingView;
  action: ChainedAction;
  busy: boolean;
  paidInFull: boolean;
  outstanding: number;
}) {
  const [itemType, setItemType] = useState<ProductionItemType>("frame");
  const [description, setDescription] = useState("");
  const [quantity, setQuantity] = useState("1");
  const [vendor, setVendor] = useState("");

  const canOverride = booking.capabilities.canOverrideBalance;

  if (!paidInFull && !canOverride) {
    return (
      <Blocked
        reason={`${formatInr(outstanding)} is still owed, so nothing can be ordered for this booking yet. Once the family has paid in full, items can be added here. Only the Founder can order against an open balance.`}
      />
    );
  }

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
        <ActionButton
          busy={busy}
          disabled={reference.trim().length === 0}
          onClick={() =>
            action.run(booking.id, [
              () =>
                recordProductionProof({
                  data: { bookingId: booking.id, proofReference: reference.trim() },
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
                    data: { bookingId: booking.id, outcome, note: note.trim() || undefined },
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
