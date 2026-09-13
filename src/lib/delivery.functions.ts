import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { Database } from "@/integrations/supabase/types";
import { ORGANIZATION_ID } from "@/lib/session";

type Tables = Database["public"]["Tables"];

export type BookingRow = Tables["bookings"]["Row"];
export type JourneyStateRow = Tables["booking_journey_states"]["Row"];
export type JourneyStageRow = Tables["booking_journey_stages"]["Row"];
export type EditingAssignmentRow = Tables["booking_editing_assignments"]["Row"];
export type EditingCompletionRow = Tables["booking_editing_completions"]["Row"];
export type QcReviewRow = Tables["booking_qc_reviews"]["Row"];
export type GalleryRow = Tables["booking_galleries"]["Row"];
export type DeliveryConfirmationRow = Tables["booking_delivery_confirmations"]["Row"];
export type ProductionItemRow = Tables["booking_production_items"]["Row"];
export type ProductionProofRow = Tables["booking_production_proofs"]["Row"];
export type ProofResponseRow = Tables["booking_production_proof_responses"]["Row"];
export type ProductionMilestoneRow = Tables["booking_production_milestones"]["Row"];
export type ReviewRequestRow = Tables["booking_review_requests"]["Row"];
export type MilestonePlanRow = Tables["booking_milestone_plans"]["Row"];

export type FamilySummary = {
  id: string;
  family_code: string;
  display_name: string;
};

export type MemberSummary = {
  id: string;
  display_name: string | null;
  email: string | null;
};

export type BookingBalance = {
  quotationTotalInr: number;
  collectedInr: number;
  outstandingInr: number;
};

export type DeliveryCapabilities = {
  canAssignEditing: boolean;
  canCompleteEditing: boolean;
  canReviewQc: boolean;
  canConfirmDelivery: boolean;
  canOverrideBalance: boolean;
  canManageProduction: boolean;
  canRequestReview: boolean;
  canPlanMilestone: boolean;
  canAdvanceStage: boolean;
};

export type DeliveryWorkspaceData = {
  bookings: BookingRow[];
  journeyStates: JourneyStateRow[];
  journeyStages: JourneyStageRow[];
  families: FamilySummary[];
  members: MemberSummary[];
  editingAssignments: EditingAssignmentRow[];
  editingCompletions: EditingCompletionRow[];
  qcReviews: QcReviewRow[];
  galleries: GalleryRow[];
  deliveryConfirmations: DeliveryConfirmationRow[];
  productionItems: ProductionItemRow[];
  productionProofs: ProductionProofRow[];
  proofResponses: ProofResponseRow[];
  productionMilestones: ProductionMilestoneRow[];
  reviewRequests: ReviewRequestRow[];
  milestonePlans: MilestonePlanRow[];
  balances: Record<string, BookingBalance>;
  capabilities: Record<string, DeliveryCapabilities>;
};

/** Journey stages this workspace covers: Editing Pending through Completed. */
export const DELIVERY_STAGE_ORDERS = [13, 14, 15, 16, 17, 18, 19, 20, 21] as const;

export const qcOutcomes = ["approved", "rework"] as const;
export type QcOutcome = (typeof qcOutcomes)[number];

export const proofOutcomes = ["approved", "changes_requested"] as const;
export type ProofOutcome = (typeof proofOutcomes)[number];

export const productionItemTypes = ["album", "frame", "other"] as const;
export type ProductionItemType = (typeof productionItemTypes)[number];

export const productionMilestoneTypes = ["dispatched", "received", "handed_over"] as const;
export type ProductionMilestoneType = (typeof productionMilestoneTypes)[number];

export const reviewChannels = ["google", "instagram", "whatsapp", "in_person", "other"] as const;
export type ReviewChannel = (typeof reviewChannels)[number];

export const milestoneCategories = [
  "maternity",
  "newborn",
  "sitter",
  "birthday",
  "family",
  "other",
] as const;
export type MilestoneCategory = (typeof milestoneCategories)[number];

function throwIfError(error: { message: string } | null) {
  if (error) {
    throw new Error(error.message);
  }
}

const bookingIdSchema = z.object({ bookingId: z.string().uuid() });

function emptyWorkspace(journeyStages: JourneyStageRow[]): DeliveryWorkspaceData {
  return {
    bookings: [],
    journeyStates: [],
    journeyStages,
    families: [],
    members: [],
    editingAssignments: [],
    editingCompletions: [],
    qcReviews: [],
    galleries: [],
    deliveryConfirmations: [],
    productionItems: [],
    productionProofs: [],
    proofResponses: [],
    productionMilestones: [],
    reviewRequests: [],
    milestonePlans: [],
    balances: {},
    capabilities: {},
  };
}

export const listDeliveryWorkspace = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<DeliveryWorkspaceData> => {
    const stagesResult = await context.supabase
      .from("booking_journey_stages")
      .select("*")
      .eq("organization_id", ORGANIZATION_ID)
      .eq("is_active", true)
      .order("stage_order", { ascending: true });

    throwIfError(stagesResult.error);

    const journeyStages = stagesResult.data ?? [];

    const stageIdsInScope = journeyStages
      .filter((stage) => (DELIVERY_STAGE_ORDERS as readonly number[]).includes(stage.stage_order))
      .map((stage) => stage.id);

    if (stageIdsInScope.length === 0) {
      return emptyWorkspace(journeyStages);
    }

    const statesResult = await context.supabase
      .from("booking_journey_states")
      .select("*")
      .eq("organization_id", ORGANIZATION_ID)
      .in("current_stage_id", stageIdsInScope);

    throwIfError(statesResult.error);

    const journeyStates = statesResult.data ?? [];
    const bookingIds = journeyStates.map((state) => state.booking_id);

    if (bookingIds.length === 0) {
      return emptyWorkspace(journeyStages);
    }

    const bookingsResult = await context.supabase
      .from("bookings")
      .select("*")
      .eq("organization_id", ORGANIZATION_ID)
      .in("id", bookingIds);

    throwIfError(bookingsResult.error);

    const bookings = bookingsResult.data ?? [];

    const [
      assignmentsResult,
      completionsResult,
      qcResult,
      galleriesResult,
      confirmationsResult,
      itemsResult,
      proofsResult,
      responsesResult,
      milestonesResult,
      reviewsResult,
      plansResult,
      requirementsResult,
      paymentsResult,
      reversalsResult,
      membersResult,
    ] = await Promise.all([
      context.supabase
        .from("booking_editing_assignments")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_editing_completions")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_qc_reviews")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_galleries")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_delivery_confirmations")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_production_items")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_production_proofs")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_production_proof_responses")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_production_milestones")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_review_requests")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_milestone_plans")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_payment_requirements")
        .select("booking_id, accepted_quotation_total_inr")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_payments")
        .select("id, booking_id, amount_inr")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("booking_payment_reversals")
        .select("payment_id")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds),
      context.supabase
        .from("organization_members")
        .select("id, display_name, email")
        .eq("organization_id", ORGANIZATION_ID)
        .eq("status", "active"),
    ]);

    throwIfError(assignmentsResult.error);
    throwIfError(completionsResult.error);
    throwIfError(qcResult.error);
    throwIfError(galleriesResult.error);
    throwIfError(confirmationsResult.error);
    throwIfError(itemsResult.error);
    throwIfError(proofsResult.error);
    throwIfError(responsesResult.error);
    throwIfError(milestonesResult.error);
    throwIfError(reviewsResult.error);
    throwIfError(plansResult.error);
    throwIfError(requirementsResult.error);
    throwIfError(paymentsResult.error);
    throwIfError(reversalsResult.error);
    throwIfError(membersResult.error);

    const familyIds = Array.from(
      new Set(
        bookings.map((booking) => booking.family_id).filter((id): id is string => Boolean(id)),
      ),
    );

    let families: FamilySummary[] = [];

    if (familyIds.length > 0) {
      const familiesResult = await context.supabase
        .from("families")
        .select("id, family_code, display_name")
        .eq("organization_id", ORGANIZATION_ID)
        .in("id", familyIds);

      throwIfError(familiesResult.error);
      families = familiesResult.data ?? [];
    }

    const reversedPaymentIds = new Set(
      (reversalsResult.data ?? []).map((reversal) => reversal.payment_id),
    );

    const collectedByBooking = new Map<string, number>();

    for (const payment of paymentsResult.data ?? []) {
      if (reversedPaymentIds.has(payment.id)) continue;
      collectedByBooking.set(
        payment.booking_id,
        (collectedByBooking.get(payment.booking_id) ?? 0) + payment.amount_inr,
      );
    }

    const balances: Record<string, BookingBalance> = {};

    for (const requirement of requirementsResult.data ?? []) {
      const total = requirement.accepted_quotation_total_inr;
      const collected = collectedByBooking.get(requirement.booking_id) ?? 0;
      balances[requirement.booking_id] = {
        quotationTotalInr: total,
        collectedInr: collected,
        outstandingInr: Math.max(total - collected, 0),
      };
    }

    // Permission probe per distinct branch, mirroring the booking workspace.
    const distinctBranchIds = Array.from(new Set(bookings.map((booking) => booking.branch_id)));

    const branchPermissionResults = await Promise.all(
      distinctBranchIds.map(async (branchId) => ({
        branchId,
        result: await context.supabase.rpc("effective_permissions", {
          p_organization_id: ORGANIZATION_ID,
          ...(branchId ? { p_branch_id: branchId } : {}),
        }),
      })),
    );

    const permissionsByBranch = new Map<string | null, Set<string>>();

    for (const { branchId, result } of branchPermissionResults) {
      throwIfError(result.error);
      permissionsByBranch.set(branchId, new Set(result.data ?? []));
    }

    const capabilities: Record<string, DeliveryCapabilities> = Object.fromEntries(
      bookings.map((booking) => {
        const granted = permissionsByBranch.get(booking.branch_id) ?? new Set<string>();

        return [
          booking.id,
          {
            canAssignEditing: granted.has("editing.assign"),
            canCompleteEditing: granted.has("editing.complete"),
            canReviewQc: granted.has("qc.review"),
            canConfirmDelivery: granted.has("delivery.confirm"),
            canOverrideBalance: granted.has("delivery.balance_override"),
            canManageProduction: granted.has("production.manage"),
            canRequestReview: granted.has("review.request"),
            canPlanMilestone: granted.has("milestone.plan"),
            canAdvanceStage: granted.has("booking.stage.advance"),
          } satisfies DeliveryCapabilities,
        ];
      }),
    );

    return {
      bookings,
      journeyStates,
      journeyStages,
      families,
      members: membersResult.data ?? [],
      editingAssignments: assignmentsResult.data ?? [],
      editingCompletions: completionsResult.data ?? [],
      qcReviews: qcResult.data ?? [],
      galleries: galleriesResult.data ?? [],
      deliveryConfirmations: confirmationsResult.data ?? [],
      productionItems: itemsResult.data ?? [],
      productionProofs: proofsResult.data ?? [],
      proofResponses: responsesResult.data ?? [],
      productionMilestones: milestonesResult.data ?? [],
      reviewRequests: reviewsResult.data ?? [],
      milestonePlans: plansResult.data ?? [],
      balances,
      capabilities,
    };
  });

/* ─────────────── Stage 13 → 14: editing assignment ─────────────── */

export const assignEditing = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        editorMemberId: z.string().uuid(),
        note: z.string().trim().max(500).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("assign_booking_editing", {
      p_booking_id: data.bookingId,
      p_editor_member_id: data.editorMemberId,
      p_note: data.note || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const markEditingInProgress = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_editing_in_progress", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

/* ─────────────── Stage 14 → 15: editing completion ─────────────── */

export const recordEditingCompletion = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        editedImageCount: z.number().int().min(1).max(100000),
        note: z.string().trim().max(500).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_editing_completion", {
      p_booking_id: data.bookingId,
      p_edited_image_count: data.editedImageCount,
      p_note: data.note || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const markQcPending = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_qc_pending", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

/* ─────────────── Stage 15: QC review, approve or rework ─────────────── */

export const recordQcReview = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        outcome: z.enum(qcOutcomes),
        note: z.string().trim().max(1000).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_qc_review", {
      p_booking_id: data.bookingId,
      p_outcome: data.outcome,
      p_note: data.note || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const markGalleryReady = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_gallery_ready", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

export const markEditingRework = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_editing_rework", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

/* ─────────────── Stage 16 → 17: gallery and delivery ─────────────── */

export const recordGallery = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        galleryUrl: z.string().trim().url().startsWith("https://").max(500),
        passwordProtected: z.boolean(),
        downloadsEnabled: z.boolean(),
        expiresAt: z.string().datetime().nullable().optional(),
        note: z.string().trim().max(500).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_gallery", {
      p_booking_id: data.bookingId,
      p_gallery_url: data.galleryUrl,
      p_password_protected: data.passwordProtected,
      p_downloads_enabled: data.downloadsEnabled,
      p_expires_at: data.expiresAt ?? undefined,
      p_note: data.note || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const recordDeliveryConfirmation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        balanceOverrideReason: z.string().trim().max(500).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_delivery_confirmation", {
      p_booking_id: data.bookingId,
      p_balance_override_reason: data.balanceOverrideReason || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const markDelivered = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_delivered", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

/* ─────────────── Stage 17 → 18: album and frame production ─────────────── */

export const markAlbumFrameProduction = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_album_frame_production", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

export const recordProductionItem = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        itemType: z.enum(productionItemTypes),
        description: z.string().trim().min(1).max(300),
        quantity: z.number().int().min(1).max(100),
        vendorName: z.string().trim().max(160).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_production_item", {
      p_booking_id: data.bookingId,
      p_item_type: data.itemType,
      p_description: data.description,
      p_quantity: data.quantity,
      p_vendor_name: data.vendorName || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const recordProductionProof = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        proofReference: z.string().trim().min(1).max(500),
        note: z.string().trim().max(500).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_production_proof", {
      p_booking_id: data.bookingId,
      p_proof_reference: data.proofReference,
      p_note: data.note || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const recordProofResponse = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        outcome: z.enum(proofOutcomes),
        note: z.string().trim().max(1000).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_proof_response", {
      p_booking_id: data.bookingId,
      p_outcome: data.outcome,
      p_note: data.note || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const recordProductionMilestone = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        milestoneType: z.enum(productionMilestoneTypes),
        vendorName: z.string().trim().max(160).optional(),
        expectedAt: z.string().datetime().nullable().optional(),
        detailNote: z.string().trim().max(500).optional(),
        collectedByName: z.string().trim().max(160).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_production_milestone", {
      p_booking_id: data.bookingId,
      p_milestone_type: data.milestoneType,
      p_vendor_name: data.vendorName || undefined,
      p_expected_at: data.expectedAt ?? undefined,
      p_detail_note: data.detailNote || undefined,
      p_collected_by_name: data.collectedByName || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

/* ─────────────── Stages 18 → 21: review, milestone, completion ─────────────── */

export const markReviewRequested = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_review_requested", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

export const recordReviewRequest = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        channel: z.enum(reviewChannels),
        note: z.string().trim().max(500).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_review_request", {
      p_booking_id: data.bookingId,
      p_channel: data.channel,
      p_note: data.note || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const markMilestoneFollowUp = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_milestone_follow_up", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });

export const recordMilestonePlan = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        bookingId: z.string().uuid(),
        nextSessionCategory: z.enum(milestoneCategories),
        dueOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Use a YYYY-MM-DD date."),
        offerNote: z.string().trim().max(500).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("record_booking_milestone_plan", {
      p_booking_id: data.bookingId,
      p_next_session_category: data.nextSessionCategory,
      p_due_on: data.dueOn,
      p_offer_note: data.offerNote || undefined,
    });

    throwIfError(error);
    return { ok: true };
  });

export const markCompleted = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => bookingIdSchema.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc("mark_booking_completed", {
      p_booking_id: data.bookingId,
    });

    throwIfError(error);
    return { ok: true };
  });
