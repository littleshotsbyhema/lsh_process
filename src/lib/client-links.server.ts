/**
 * Server-only: applies a family's response from a share link back into the
 * studio records. Records are stored as `{ id, data }` JSON documents.
 */
import { journeyStages } from "@/lib/mock-data";

type AnyRecord = Record<string, unknown>;
type Payload = Record<string, string | number | boolean>;

function stageIndex(stage: unknown) {
  return journeyStages.indexOf(stage as (typeof journeyStages)[number]);
}

export async function applyClientResponse(opts: {
  kind: string;
  bookingId: string | null;
  payload: Payload;
}) {
  const { kind, bookingId, payload } = opts;
  if (!bookingId) return;
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const admin = supabaseAdmin as unknown as { from: (t: string) => any };

  const { data: bookingRow } = await admin
    .from("bookings")
    .select("id, data")
    .eq("id", bookingId)
    .maybeSingle();
  if (!bookingRow) return;
  const booking = { ...((bookingRow.data ?? {}) as AnyRecord) };
  const today = new Date().toISOString().slice(0, 10);
  const client = String(booking.client ?? "");

  if (kind === "proposal" && payload.accepted) {
    // Family said yes — move them forward, but never past the payment guard.
    if (stageIndex(booking.journeyStage) < stageIndex("Follow-Up Pending")) {
      booking.journeyStage = "Follow-Up Pending";
    }
    booking.proposalAcceptedAt = today;
    if (typeof payload.note === "string" && payload.note.trim()) {
      booking.familyNote = payload.note.trim();
    }
    await admin.from("bookings").upsert({ id: bookingId, data: booking });
    return;
  }

  if (kind === "consent") {
    const marketing = payload.marketingConsent === true;
    const consent = marketing
      ? "Portfolio Release — Approved Images May Be Used"
      : "Full Privacy — Do Not Share";
    const signedBy = String(payload.signedBy ?? client);

    await admin.from("privacy_records").upsert({
      id: `P-${bookingId}`,
      data: {
        id: `P-${bookingId}`,
        bookingId,
        client,
        consent,
        date: today,
        platforms: marketing ? "Portfolio, Instagram, Website" : "None — internal use only",
        images: marketing ? "Approved images only" : "All images private",
        confirmed: true,
        recordedBy: `Signed by ${signedBy} (family link)`,
      },
    });

    booking.privacy = marketing ? "Portfolio Release" : "Full Privacy";
    booking.consentSignedBy = signedBy;
    booking.consentSignedAt = today;
    await admin.from("bookings").upsert({ id: bookingId, data: booking });
    return;
  }

  if (kind === "delivery") {
    booking.galleryOpenedAt = today;
    await admin.from("bookings").upsert({ id: bookingId, data: booking });

    const rating = typeof payload.rating === "number" ? payload.rating : undefined;
    const testimonial = typeof payload.testimonial === "string" ? payload.testimonial : "";
    if (rating || testimonial.trim()) {
      const id = `R-${bookingId}`;
      await admin.from("reviews").upsert({
        id,
        data: {
          id,
          bookingId,
          client,
          sessionType: booking.category ?? "Family",
          requestStatus: "Received",
          rating,
          testimonial,
          permissionToUse: false,
          consentProof: "Shared via family delivery link",
          issueRaised: typeof rating === "number" && rating <= 3,
          resolutionNotes: "",
          repeatOpportunity: false,
          nextMilestoneDate: "",
        },
      });
      booking.reviewRequested = true;
      await admin.from("bookings").upsert({ id: bookingId, data: booking });
    }
  }
}