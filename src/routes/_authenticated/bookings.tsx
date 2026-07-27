import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { bookingStatuses, type BookingStatus } from "@/lib/mock-data";
import { useStore, bookingFlags } from "@/store/useStore";
import { handle } from "@/lib/handle";
import { MemoryProfileCard } from "@/components/MemoryProfileCard";
import { JourneyPipeline } from "@/components/JourneyPipeline";
import { ShieldCheck, ClipboardCheck, ImageIcon, Frame, CheckCircle2, AlertTriangle, Lock, Unlock, Camera } from "lucide-react";

export const Route = createFileRoute("/_authenticated/bookings")({
  head: () => ({ meta: [{ title: "Bookings · Little Moments OS" }] }),
  component: BookingsPage,
});

function BookingsPage() {
  const bookings = useStore((s) => s.bookings);
  const pixieset = useStore((s) => s.pixieset);
  const setBookingStatus = useStore((s) => s.setBookingStatus);
  const markShootCompleted = useStore((s) => s.markShootCompleted);
  const confirmSelection = useStore((s) => s.confirmSelection);
  const confirmAlbumSelection = useStore((s) => s.confirmAlbumSelection);
  const markPaymentPaid = useStore((s) => s.markPaymentPaid);
  const startEditing = useStore((s) => s.startEditing);
  const startHeirloom = useStore((s) => s.startHeirloom);
  const navigate = useNavigate();

  return (
    <AppShell>
      <PageHeader
        eyebrow="Sessions"
        title="Bookings"
        subtitle="Every booking is a promise. Protect it with privacy, safety, and on-time delivery."
        quote="A booking is a family trusting us with a chapter of their life."
      />

      <div className="flex flex-wrap gap-2 mb-6">
        {bookingStatuses.map((s) => (
          <span key={s} className="text-xs px-3 py-1.5 rounded-full bg-muted text-muted-foreground border border-border">{s}</span>
        ))}
      </div>

      <div className="space-y-5">
        {bookings.length === 0 && (
          <Card className="p-10 text-center">
            <p className="font-serif text-xl text-primary">No bookings yet.</p>
            <p className="text-sm text-muted-foreground mt-2">Create one from a client to begin the flow.</p>
          </Card>
        )}
        {bookings.map((b) => {
          const flags = bookingFlags(b);
          const pix = pixieset.find((p) => p.bookingId === b.id);
          return (
          <Card key={b.id} className="p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{b.id} · {b.category}</div>
                <h3 className="font-serif text-xl text-primary mt-1">{b.client}</h3>
                <div className="text-xs text-muted-foreground mt-0.5">{b.date} · {b.city} · {b.locationType}</div>
              </div>
              <div className="flex flex-wrap gap-1.5">
                <select
                  value={b.status}
                  onChange={(e) => handle(setBookingStatus(b.id, e.target.value as BookingStatus))}
                  className="text-[11px] bg-[var(--gradient-warm)] text-primary border border-gold rounded-full px-2.5 py-1 font-medium"
                >
                  {bookingStatuses.map((s) => <option key={s}>{s}</option>)}
                </select>
                <StatusPill tone={b.payment === "Paid" ? "good" : "warn"}>{b.payment}</StatusPill>
                <StatusPill tone={b.safety === "Completed" ? "good" : "bad"}>Safety: {b.safety}</StatusPill>
                <StatusPill tone={flags.consentRecorded ? "good" : "bad"}>{b.privacy}</StatusPill>
                <StatusPill tone={flags.marketingAllowed ? "good" : "neutral"}>
                  {flags.marketingAllowed ? <Unlock className="h-3 w-3 inline mr-1" /> : <Lock className="h-3 w-3 inline mr-1" />}
                  Marketing {flags.marketingAllowed ? "allowed" : "blocked"}
                </StatusPill>
              </div>
            </div>

            <div className="mt-5 grid md:grid-cols-3 gap-5">
              <div>
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Production</div>
                <Row k="Package" v={b.package} />
                <Row k="Photographer" v={b.photographer} />
                <Row k="Assistant" v={b.assistant} />
                <Row k="Styling" v={b.styling} />
                <Row k="Add-ons" v={b.addOns} />
                <Row k="Location" v={b.locationDetails} />
              </div>
              <div>
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Payment</div>
                <Row k="Package price" v={`₹${b.price.toLocaleString("en-IN")}`} />
                <Row k="Offer price" v={`₹${b.offer.toLocaleString("en-IN")}`} />
                <Row k="Advance paid" v={`₹${b.advance.toLocaleString("en-IN")}`} />
                <Row k="Balance due" v={`₹${b.balance.toLocaleString("en-IN")}`} />
              </div>
              <div>
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Promises</div>
                <Row k="Delivery deadline" v={b.deadline} />
                <Row k="Privacy consent" v={b.privacy} />
                <Row k="Safety checklist" v={b.safety} />
                <Row k="Booking status" v={b.status} />
              </div>
            </div>

            {/* Connected actions */}
            <div className="mt-5 pt-5 border-t border-border">
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground mb-3">Connected actions</div>
              <div className="flex flex-wrap gap-2">
                <Link
                  to="/privacy"
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border border-border bg-muted text-primary hover:bg-accent"
                >
                  <ShieldCheck className="h-3 w-3" /> {flags.consentRecorded ? "View consent" : "Record consent"}
                </Link>
                <Link
                  to="/safety"
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border border-border bg-muted text-primary hover:bg-accent"
                >
                  <ClipboardCheck className="h-3 w-3" /> {b.safety === "Completed" ? "Safety done" : "Submit safety checklist"}
                </Link>
                <button
                  onClick={() => handle(markShootCompleted(b.id))}
                  disabled={!flags.canCompleteShoot || b.status === "Shoot Completed"}
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground disabled:opacity-40 disabled:cursor-not-allowed"
                  title={!flags.canCompleteShoot ? "Safety checklist required" : ""}
                >
                  <CheckCircle2 className="h-3 w-3" /> Mark shoot completed
                </button>
                <button
                  onClick={() => handle(confirmSelection(b.id))}
                  disabled={b.selectionConfirmed}
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border border-border bg-muted text-primary disabled:opacity-40"
                >
                  {b.selectionConfirmed ? "Selection confirmed ✓" : "Confirm image selection"}
                </button>
                <button
                  onClick={() => handle(markPaymentPaid(b.id))}
                  disabled={b.payment === "Paid"}
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border border-border bg-muted text-primary disabled:opacity-40"
                >
                  {b.payment === "Paid" ? "Payment received ✓" : "Mark full payment received"}
                </button>
                <button
                  onClick={() => {
                    const r = startEditing(b.id);
                    handle(r);
                    if (r.ok) navigate({ to: "/editing" });
                  }}
                  disabled={!flags.canStartEditing}
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-[var(--gradient-gold)] text-primary disabled:opacity-40 disabled:cursor-not-allowed"
                  title={!flags.canStartEditing ? "Needs confirmed selection + full payment" : ""}
                >
                  <ImageIcon className="h-3 w-3" /> Start editing
                </button>
                <button
                  onClick={() => handle(confirmAlbumSelection(b.id))}
                  disabled={b.albumSelectionConfirmed}
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border border-border bg-muted text-primary disabled:opacity-40"
                >
                  {b.albumSelectionConfirmed ? "Album choices ✓" : "Confirm album / frame choices"}
                </button>
                <button
                  onClick={() => {
                    const r = startHeirloom(b.id, {
                      albumSize: "12×12",
                      pages: 20,
                      cover: "Linen, ivory",
                      frame: "—",
                      selected: "To be tagged",
                    });
                    handle(r);
                    if (r.ok) navigate({ to: "/heirloom" });
                  }}
                  disabled={!flags.canStartHeirloom}
                  className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-[var(--gradient-gold)] text-primary disabled:opacity-40 disabled:cursor-not-allowed"
                  title={!flags.canStartHeirloom ? "Confirm album/frame selections first" : ""}
                >
                  <Frame className="h-3 w-3" /> Start heirloom production
                </button>
              </div>

              {(!flags.consentRecorded || b.safety === "Pending") && (
                <div className="mt-3 flex items-start gap-2 text-xs text-[oklch(0.45_0.14_30)] bg-[oklch(0.96_0.04_30)] border border-[oklch(0.85_0.06_30)] rounded-lg px-3 py-2">
                  <AlertTriangle className="h-3.5 w-3.5 mt-0.5 shrink-0" />
                  <span>
                    {!flags.consentRecorded && "Privacy consent is not on file — marketing use is blocked. "}
                    {b.safety === "Pending" && "Safety checklist still pending — shoot cannot be marked complete."}
                  </span>
                </div>
              )}
            </div>

            <MemoryProfileCard ownerType="booking" ownerId={b.id} />
            <div className="mt-4 rounded-xl border border-border bg-card px-4 py-3 flex items-center gap-3 flex-wrap">
              <span className="rounded-full bg-[var(--gradient-warm)] p-1.5">
                <Camera className="h-3.5 w-3.5 text-gold" />
              </span>
              <div className="flex-1 min-w-0">
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Pixieset</div>
                <div className="text-sm text-primary">
                  {pix
                    ? `${pix.collectionName} · Gallery ${pix.galleryStatus} · Order ${pix.orderStatus}`
                    : "Not set up yet"}
                </div>
              </div>
              <Link to="/pixieset" className="text-[11px] px-3 py-1.5 rounded-lg border border-gold bg-card text-primary">
                {pix ? "Manage" : "Set up"} →
              </Link>
            </div>
            <JourneyPipeline bookingId={b.id} />
            <ClientShareLinks
              bookingId={b.id}
              payload={{
                client: b.client,
                category: b.category,
                package: b.package,
                price: `₹${b.offer.toLocaleString("en-IN")}`,
                galleryLink: pix?.galleryLink ?? "",
                galleryPassword: pix?.galleryPassword ?? "",
                heirloomStatus: b.status,
              }}
            />
          </Card>
          );
        })}
      </div>
    </AppShell>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between gap-3 py-1 text-sm border-b border-dashed border-border last:border-0">
      <span className="text-muted-foreground">{k}</span>
      <span className="text-primary text-right">{v}</span>
    </div>
  );
}