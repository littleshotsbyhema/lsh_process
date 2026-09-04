import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { Database } from "@/integrations/supabase/types";
import { ORGANIZATION_ID } from "@/lib/session";

export type BookingRow = Database["public"]["Tables"]["bookings"]["Row"];

export type BookingJourneyStateRow = Database["public"]["Tables"]["booking_journey_states"]["Row"];

export type BookingJourneyStageRow = Database["public"]["Tables"]["booking_journey_stages"]["Row"];

export type BookingStageTransitionRow =
  Database["public"]["Tables"]["booking_stage_transitions"]["Row"];

export type BookingQuotationSummary = {
  id: string;
  quotation_reference: string;
  status: Database["public"]["Enums"]["quotation_status"];
  currency: string;
  quoted_total_inr: number;
  accepted_at: string | null;
};

export type BookingQuotationLine = {
  quotation_id: string;
  line_type: Database["public"]["Enums"]["quotation_line_type"];
  item_name: string;
  line_total_inr: number;
  pricing_source: Database["public"]["Enums"]["quotation_pricing_source"];
  sort_order: number;
};

export type BookingLeadSummary = {
  id: string;
  lead_reference: string;
  parent_name: string;
  session_type: string | null;
};

export type BookingFamilySummary = {
  id: string;
  family_code: string;
  display_name: string;
};

export type BookingCapabilities = {
  canReadBookingTeam: boolean;
  canReadPreparation: boolean;
  canWritePreparation: boolean;
  canAdvanceBookingStage: boolean;
  canAssignBookingTeam: boolean;
  canReadSafety: boolean;
  canWriteSafety: boolean;
  canSignoffSafety: boolean;
  canCompleteShoot: boolean;
  canConfirmSelection: boolean;
};

export type BookingWorkspaceData = {
  bookings: BookingRow[];
  quotations: BookingQuotationSummary[];
  quotationLines: BookingQuotationLine[];
  journeyStates: BookingJourneyStateRow[];
  journeyStages: BookingJourneyStageRow[];
  transitions: BookingStageTransitionRow[];
  leads: BookingLeadSummary[];
  families: BookingFamilySummary[];
  bookingPreparations: BookingPreparationRow[];
  bookingPreparationItems: BookingPreparationItemRow[];
  bookingSafetyReadiness: BookingSafetyReadinessRow[];
  bookingSafetySignoffs: BookingSafetySignoffRow[];
  bookingShootCompletions: BookingShootCompletionRow[];
  bookingSelectionCompletions: BookingSelectionCompletionRow[];
  bookingSelectedImages: BookingSelectedImageRow[];
  bookingTeamAssignmentHistory: BookingTeamAssignmentHistoryRow[];
  bookingServiceCategories: Record<string, string | null>;
  bookingSafetySignoffAuthorities: Record<string, BookingSafetySignoffAuthority | null>;
  bookingCapabilities: Record<string, BookingCapabilities>;
};

export type BookingPaymentSummary =
  Database["public"]["Functions"]["get_booking_payment_summary"]["Returns"][number];

export type BookingPaymentRow = Database["public"]["Tables"]["booking_payments"]["Row"];

export type BookingShootScheduleRow =
  Database["public"]["Tables"]["booking_shoot_schedules"]["Row"];

export type BookingShootCompletionRow =
  Database["public"]["Tables"]["booking_shoot_completions"]["Row"];

export type BookingSelectionCompletionRow =
  Database["public"]["Tables"]["booking_selection_completions"]["Row"];

export type BookingSelectedImageRow =
  Database["public"]["Tables"]["booking_selected_images"]["Row"];

export type BookingTeamAssignmentRow =
  Database["public"]["Tables"]["booking_team_assignments"]["Row"];

export type BookingPreparationRow = Database["public"]["Tables"]["booking_preparations"]["Row"];

export type BookingPreparationItemRow =
  Database["public"]["Tables"]["booking_preparation_items"]["Row"];

export type BookingSafetyReadinessRow =
  Database["public"]["Tables"]["booking_safety_readiness"]["Row"];

export type BookingSafetySignoffRow =
  Database["public"]["Tables"]["booking_safety_signoffs"]["Row"];

export type BookingSafetyState = "pending" | "ready" | "not_ready" | "not_applicable";

export type BookingSafetySignoffAuthority = "founder" | "studio_manager" | "lead_photographer";

type GeneratedBookingTeamAssignmentHistoryRow =
  Database["public"]["Functions"]["get_booking_team_assignment_history"]["Returns"][number];

export type BookingTeamAssignmentHistoryRow = Omit<
  GeneratedBookingTeamAssignmentHistoryRow,
  "ended_at" | "end_reason" | "subject_display_name" | "subject_id"
> & {
  ended_at: string | null;
  end_reason: string | null;
  subject_display_name: string | null;
  subject_id: string | null;
};

type GeneratedBookingTeamAssignmentCandidateRow =
  Database["public"]["Functions"]["get_booking_team_assignment_candidates"]["Returns"][number];

export type BookingTeamAssignmentCandidateRow = Omit<
  GeneratedBookingTeamAssignmentCandidateRow,
  "subject_display_name"
> & {
  subject_display_name: string | null;
};

export type BookingConfirmationWorkspace = {
  paymentSummary: BookingPaymentSummary | null;
  currentSchedule: BookingShootScheduleRow | null;
};

function throwIfError(error: { message: string } | null) {
  if (error) {
    throw new Error(error.message);
  }
}

function isBookingSafetySignoffAuthority(value: string): value is BookingSafetySignoffAuthority {
  return value === "founder" || value === "studio_manager" || value === "lead_photographer";
}

function bookingCapabilitiesFromPermissions(permissions: Set<string>): BookingCapabilities {
  return {
    canReadBookingTeam: permissions.has("booking.read"),
    canReadPreparation: permissions.has("prep.read"),
    canWritePreparation: permissions.has("prep.write"),
    canAdvanceBookingStage: permissions.has("booking.stage.advance"),
    canAssignBookingTeam: permissions.has("booking.team.assign"),
    canReadSafety: permissions.has("safety.read"),
    canWriteSafety: permissions.has("safety.write"),
    canSignoffSafety: permissions.has("safety.signoff"),
    canCompleteShoot: permissions.has("shoot.complete"),
    canConfirmSelection: permissions.has("selection.confirm"),
  };
}

const bookingIdSchema = z.object({
  bookingId: z.string().uuid(),
});

const recordBookingPaymentSchema = z.object({
  bookingId: z.string().uuid(),
  amountInr: z.number().int().positive(),
  paymentMethod: z.enum(["cash", "upi", "bank_transfer", "card", "other"]),
  receivedAt: z.string().datetime(),
  externalReference: z.string().trim().min(1).max(160).optional(),
  note: z.string().trim().min(1).max(1000).optional(),
});

const proposeBookingShootScheduleSchema = z.object({
  bookingId: z.string().uuid(),
  scheduledStartAt: z.string().datetime(),
  scheduledEndAt: z.string().datetime(),
  timezone: z.string().trim().min(1),
  locationType: z.string().trim().min(1),
  locationDetails: z.string().trim().min(1).optional(),
});

const startPreShootPreparationSchema = z.object({
  bookingId: z.string().uuid(),
});

const updatePreShootPreparationItemSchema = z.object({
  preparationItemId: z.string().uuid(),
  satisfied: z.boolean(),
});

const recordBookingSafetyReadinessSchema = z.object({
  bookingId: z.string().uuid(),
  safetyState: z.enum(["pending", "ready", "not_ready", "not_applicable"]),
  comfortState: z.enum(["pending", "ready", "not_ready", "not_applicable"]),
});

const signoffBookingSafetyReadinessSchema = z.object({
  bookingId: z.string().uuid(),
});

const markBookingShootScheduledSchema = z.object({
  bookingId: z.string().uuid(),
});

const recordBookingShootCompletionSchema = z.object({
  bookingId: z.string().uuid(),
  completedAt: z.string().datetime(),
});

const markBookingShootCompletedSchema = z.object({
  bookingId: z.string().uuid(),
});

const markBookingSelectionPendingSchema = z.object({
  bookingId: z.string().uuid(),
});

const recordBookingSelectionCompletionSchema = z.object({
  bookingId: z.string().uuid(),
  selectedImageKeys: z.array(z.string().trim().min(1)).min(1),
  sourceType: z.string().trim().min(1),
  externalReference: z.string().trim().min(1).optional(),
});

const markBookingEditingPendingSchema = z.object({
  bookingId: z.string().uuid(),
});

const bookingTeamAssignmentCandidatesSchema = z.object({
  bookingId: z.string().uuid(),
});

const assignLeadPhotographerSchema = z.object({
  bookingId: z.string().uuid(),
  subjectType: z.enum(["internal_member", "external_creative"]),
  subjectId: z.string().uuid(),
});

const assignStylistSchema = z.object({
  bookingId: z.string().uuid(),
  subjectType: z.enum(["internal_member", "external_creative"]),
  subjectId: z.string().uuid(),
});

const assignLeadVideographerSchema = z.object({
  bookingId: z.string().uuid(),
  subjectType: z.enum(["internal_member", "external_creative"]),
  subjectId: z.string().uuid(),
});

export const listBookingWorkspace = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<BookingWorkspaceData> => {
    const bookingsResult = await context.supabase
      .from("bookings")
      .select("*")
      .eq("organization_id", ORGANIZATION_ID)
      .order("created_at", {
        ascending: false,
      })
      .limit(100);

    throwIfError(bookingsResult.error);

    const bookings = bookingsResult.data ?? [];

    if (bookings.length === 0) {
      const stagesResult = await context.supabase
        .from("booking_journey_stages")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .eq("is_active", true)
        .order("stage_order", {
          ascending: true,
        });

      throwIfError(stagesResult.error);

      return {
        bookings: [],
        quotations: [],
        quotationLines: [],
        journeyStates: [],
        journeyStages: stagesResult.data ?? [],
        transitions: [],
        leads: [],
        families: [],
        bookingPreparations: [],
        bookingPreparationItems: [],
        bookingSafetyReadiness: [],
        bookingSafetySignoffs: [],
        bookingShootCompletions: [],
        bookingSelectionCompletions: [],
        bookingSelectedImages: [],
        bookingTeamAssignmentHistory: [],
        bookingServiceCategories: {},
        bookingSafetySignoffAuthorities: {},
        bookingCapabilities: {},
      };
    }

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

    const bookingCapabilities: Record<string, BookingCapabilities> = Object.fromEntries(
      bookings.map((booking) => {
        const permissions = permissionsByBranch.get(booking.branch_id) ?? new Set<string>();
        return [booking.id, bookingCapabilitiesFromPermissions(permissions)];
      }),
    );

    const bookingIds = bookings.map((booking) => booking.id);
    const quotationIds = bookings.map((booking) => booking.source_quotation_id);

    const leadIds = Array.from(
      new Set(bookings.map((booking) => booking.lead_id).filter((id): id is string => Boolean(id))),
    );

    const familyIds = Array.from(
      new Set(
        bookings.map((booking) => booking.family_id).filter((id): id is string => Boolean(id)),
      ),
    );

    const [quotationsResult, quotationLinesResult, statesResult, stagesResult, transitionsResult] =
      await Promise.all([
        context.supabase
          .from("quotations")
          .select("id, quotation_reference, status, currency, quoted_total_inr, accepted_at")
          .eq("organization_id", ORGANIZATION_ID)
          .in("id", quotationIds),

        context.supabase
          .from("quotation_line_items")
          .select("quotation_id, line_type, item_name, line_total_inr, pricing_source, sort_order")
          .eq("organization_id", ORGANIZATION_ID)
          .in("quotation_id", quotationIds)
          .order("sort_order", {
            ascending: true,
          }),

        context.supabase
          .from("booking_journey_states")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .in("booking_id", bookingIds),

        context.supabase
          .from("booking_journey_stages")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .eq("is_active", true)
          .order("stage_order", {
            ascending: true,
          }),

        context.supabase
          .from("booking_stage_transitions")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .in("booking_id", bookingIds)
          .order("transitioned_at", {
            ascending: true,
          }),
      ]);

    throwIfError(quotationsResult.error);
    throwIfError(quotationLinesResult.error);
    throwIfError(statesResult.error);
    throwIfError(stagesResult.error);
    throwIfError(transitionsResult.error);

    let leads: BookingLeadSummary[] = [];

    if (leadIds.length > 0) {
      const leadsResult = await context.supabase
        .from("leads")
        .select("id, lead_reference, parent_name, session_type")
        .eq("organization_id", ORGANIZATION_ID)
        .in("id", leadIds);

      throwIfError(leadsResult.error);

      leads = leadsResult.data ?? [];
    }

    let families: BookingFamilySummary[] = [];

    if (familyIds.length > 0) {
      const familiesResult = await context.supabase
        .from("families")
        .select("id, family_code, display_name")
        .eq("organization_id", ORGANIZATION_ID)
        .in("id", familyIds);

      throwIfError(familiesResult.error);

      families = familiesResult.data ?? [];
    }

    let bookingPreparations: BookingPreparationRow[] = [];
    let bookingPreparationItems: BookingPreparationItemRow[] = [];

    const preparationReadableBookingIds = bookings
      .filter((booking) => bookingCapabilities[booking.id].canReadPreparation)
      .map((booking) => booking.id);

    if (preparationReadableBookingIds.length > 0) {
      const preparationsResult = await context.supabase
        .from("booking_preparations")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", preparationReadableBookingIds)
        .order("started_at", {
          ascending: true,
        });

      throwIfError(preparationsResult.error);

      bookingPreparations = preparationsResult.data ?? [];

      const preparationIds = bookingPreparations.map((preparation) => preparation.id);

      if (preparationIds.length > 0) {
        const preparationItemsResult = await context.supabase
          .from("booking_preparation_items")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .in("preparation_id", preparationIds)
          .order("sort_order", {
            ascending: true,
          });

        throwIfError(preparationItemsResult.error);

        bookingPreparationItems = preparationItemsResult.data ?? [];
      }
    }

    let bookingSafetyReadiness: BookingSafetyReadinessRow[] = [];
    let bookingSafetySignoffs: BookingSafetySignoffRow[] = [];

    const safetyReadableBookingIds = bookings
      .filter((booking) => bookingCapabilities[booking.id].canReadSafety)
      .map((booking) => booking.id);

    const bookingServiceCategories: Record<string, string | null> = Object.fromEntries(
      bookings.map((booking) => [booking.id, null]),
    );

    const bookingSafetySignoffAuthorities: Record<string, BookingSafetySignoffAuthority | null> =
      Object.fromEntries(bookings.map((booking) => [booking.id, null]));

    const signoffAuthorityReadableBookingIds = safetyReadableBookingIds.filter(
      (bookingId) => bookingCapabilities[bookingId].canSignoffSafety,
    );

    if (safetyReadableBookingIds.length > 0) {
      const serviceCategoryResults = await Promise.all(
        safetyReadableBookingIds.map(async (bookingId) => ({
          bookingId,
          result: await context.supabase.rpc("get_booking_safety_service_category", {
            p_booking_id: bookingId,
          }),
        })),
      );

      for (const { bookingId, result } of serviceCategoryResults) {
        throwIfError(result.error);
        bookingServiceCategories[bookingId] = result.data ?? null;
      }

      if (signoffAuthorityReadableBookingIds.length > 0) {
        const signoffAuthorityResults = await Promise.all(
          signoffAuthorityReadableBookingIds.map(async (bookingId) => ({
            bookingId,
            result: await context.supabase.rpc("get_booking_safety_signoff_authority", {
              p_booking_id: bookingId,
            }),
          })),
        );

        for (const { bookingId, result } of signoffAuthorityResults) {
          throwIfError(result.error);

          const authority = result.data ?? null;

          if (authority !== null && !isBookingSafetySignoffAuthority(authority)) {
            throw new Error(
              `Unexpected Safety Readiness sign-off authority for booking ${bookingId}.`,
            );
          }

          bookingSafetySignoffAuthorities[bookingId] = authority;
        }
      }

      const readinessResult = await context.supabase
        .from("booking_safety_readiness")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", safetyReadableBookingIds)
        .is("superseded_at", null)
        .order("revision_number", {
          ascending: true,
        });

      throwIfError(readinessResult.error);

      bookingSafetyReadiness = readinessResult.data ?? [];

      const readinessIds = bookingSafetyReadiness.map((readiness) => readiness.id);

      if (readinessIds.length > 0) {
        const signoffsResult = await context.supabase
          .from("booking_safety_signoffs")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .in("booking_id", bookingIds)
          .in("readiness_id", readinessIds)
          .order("signed_at", {
            ascending: true,
          });

        throwIfError(signoffsResult.error);

        bookingSafetySignoffs = signoffsResult.data ?? [];
      }
    }

    const bookingShootCompletionsResult = await context.supabase
      .from("booking_shoot_completions")
      .select("*")
      .eq("organization_id", ORGANIZATION_ID)
      .in("booking_id", bookingIds)
      .order("completed_at", {
        ascending: true,
      });

    throwIfError(bookingShootCompletionsResult.error);

    const bookingSelectionCompletionsResult = await context.supabase
      .from("booking_selection_completions")
      .select("*")
      .eq("organization_id", ORGANIZATION_ID)
      .in("booking_id", bookingIds)
      .order("completed_at", {
        ascending: true,
      });

    throwIfError(bookingSelectionCompletionsResult.error);

    const bookingSelectionCompletions = bookingSelectionCompletionsResult.data ?? [];
    const selectionCompletionIds = bookingSelectionCompletions.map((completion) => completion.id);

    const bookingSelectedImages: BookingSelectedImageRow[] = [];
    const selectedImagesPageSize = 1000;

    if (selectionCompletionIds.length > 0) {
      for (let from = 0; ; from += selectedImagesPageSize) {
        const selectedImagesPageResult = await context.supabase
          .from("booking_selected_images")
          .select("*")
          .in("selection_completion_id", selectionCompletionIds)
          .order("booking_id", {
            ascending: true,
          })
          .order("ordinal", {
            ascending: true,
            nullsFirst: true,
          })
          .order("created_at", {
            ascending: true,
          })
          .order("id", {
            ascending: true,
          })
          .range(from, from + selectedImagesPageSize - 1);

        throwIfError(selectedImagesPageResult.error);

        const selectedImagesPage = selectedImagesPageResult.data ?? [];
        bookingSelectedImages.push(...selectedImagesPage);

        if (selectedImagesPage.length < selectedImagesPageSize) {
          break;
        }
      }
    }

    const bookingTeamAssignmentHistory: BookingTeamAssignmentHistoryRow[] = [];

    const teamReadableBookingIds = bookings
      .filter((booking) => bookingCapabilities[booking.id].canReadBookingTeam)
      .map((booking) => booking.id);

    if (teamReadableBookingIds.length > 0) {
      const historyResults = await Promise.all(
        teamReadableBookingIds.map((bookingId) =>
          context.supabase.rpc("get_booking_team_assignment_history", {
            p_booking_id: bookingId,
          }),
        ),
      );

      for (const historyResult of historyResults) {
        throwIfError(historyResult.error);
        bookingTeamAssignmentHistory.push(...(historyResult.data ?? []));
      }
    }

    return {
      bookings,
      quotations: quotationsResult.data ?? [],
      quotationLines: quotationLinesResult.data ?? [],
      journeyStates: statesResult.data ?? [],
      journeyStages: stagesResult.data ?? [],
      transitions: transitionsResult.data ?? [],
      leads,
      families,
      bookingPreparations,
      bookingPreparationItems,
      bookingSafetyReadiness,
      bookingSafetySignoffs,
      bookingShootCompletions: bookingShootCompletionsResult.data ?? [],
      bookingSelectionCompletions,
      bookingSelectedImages,
      bookingTeamAssignmentHistory,
      bookingServiceCategories,
      bookingSafetySignoffAuthorities,
      bookingCapabilities,
    };
  });

export const listBookingTeamAssignmentCandidates = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .validator(bookingTeamAssignmentCandidatesSchema)
  .handler(async ({ context, data }): Promise<BookingTeamAssignmentCandidateRow[]> => {
    const result = await context.supabase.rpc("get_booking_team_assignment_candidates", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    return result.data ?? [];
  });

export const assignLeadPhotographer = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(assignLeadPhotographerSchema)
  .handler(async ({ context, data }): Promise<BookingTeamAssignmentRow> => {
    const result =
      data.subjectType === "internal_member"
        ? await context.supabase.rpc("assign_booking_team_member", {
            p_booking_id: data.bookingId,
            p_assignment_role: "lead_photographer",
            p_member_id: data.subjectId,
            p_is_assigned: true,
            p_change_reason: undefined,
          })
        : await context.supabase.rpc("assign_booking_external_creative", {
            p_booking_id: data.bookingId,
            p_assignment_role: "lead_photographer",
            p_external_creative_id: data.subjectId,
            p_is_assigned: true,
            p_change_reason: undefined,
          });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Lead Photographer assignment returned no row.");
    }

    return result.data;
  });

export const assignStylist = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(assignStylistSchema)
  .handler(async ({ context, data }): Promise<BookingTeamAssignmentRow> => {
    const result =
      data.subjectType === "internal_member"
        ? await context.supabase.rpc("assign_booking_team_member", {
            p_booking_id: data.bookingId,
            p_assignment_role: "stylist",
            p_member_id: data.subjectId,
            p_is_assigned: true,
            p_change_reason: undefined,
          })
        : await context.supabase.rpc("assign_booking_external_creative", {
            p_booking_id: data.bookingId,
            p_assignment_role: "stylist",
            p_external_creative_id: data.subjectId,
            p_is_assigned: true,
            p_change_reason: undefined,
          });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Stylist assignment returned no row.");
    }

    return result.data;
  });

export const assignLeadVideographer = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(assignLeadVideographerSchema)
  .handler(async ({ context, data }): Promise<BookingTeamAssignmentRow> => {
    const result =
      data.subjectType === "internal_member"
        ? await context.supabase.rpc("assign_booking_team_member", {
            p_booking_id: data.bookingId,
            p_assignment_role: "lead_videographer",
            p_member_id: data.subjectId,
            p_is_assigned: true,
            p_change_reason: undefined,
          })
        : await context.supabase.rpc("assign_booking_external_creative", {
            p_booking_id: data.bookingId,
            p_assignment_role: "lead_videographer",
            p_external_creative_id: data.subjectId,
            p_is_assigned: true,
            p_change_reason: undefined,
          });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Lead Videographer assignment returned no row.");
    }

    return result.data;
  });

export const getBookingConfirmationWorkspace = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .validator(bookingIdSchema)
  .handler(async ({ context, data }): Promise<BookingConfirmationWorkspace> => {
    const paymentResult = await context.supabase.rpc("get_booking_payment_summary", {
      p_booking_id: data.bookingId,
    });

    throwIfError(paymentResult.error);

    const scheduleResult = await context.supabase
      .from("booking_shoot_schedules")
      .select("*")
      .eq("organization_id", ORGANIZATION_ID)
      .eq("booking_id", data.bookingId)
      .order("schedule_version", {
        ascending: false,
      })
      .limit(1)
      .maybeSingle();

    throwIfError(scheduleResult.error);

    return {
      paymentSummary: paymentResult.data?.[0] ?? null,
      currentSchedule: scheduleResult.data,
    };
  });

export const recordBookingPayment = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(recordBookingPaymentSchema)
  .handler(async ({ context, data }): Promise<BookingPaymentRow> => {
    const result = await context.supabase.rpc("record_booking_payment", {
      p_booking_id: data.bookingId,
      p_amount_inr: data.amountInr,
      p_payment_method: data.paymentMethod,
      p_received_at: data.receivedAt,
      p_external_reference: data.externalReference,
      p_note: data.note,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Payment recording returned no row.");
    }

    return result.data;
  });

export const proposeBookingShootSchedule = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(proposeBookingShootScheduleSchema)
  .handler(async ({ context, data }): Promise<BookingShootScheduleRow> => {
    const result = await context.supabase.rpc("propose_booking_shoot_schedule", {
      p_booking_id: data.bookingId,
      p_scheduled_start_at: data.scheduledStartAt,
      p_scheduled_end_at: data.scheduledEndAt,
      p_timezone: data.timezone,
      p_location_type: data.locationType,
      p_location_details: data.locationDetails,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Shoot schedule proposal returned no row.");
    }

    return result.data;
  });

export const confirmBookingAfterAdvance = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(bookingIdSchema)
  .handler(async ({ context, data }): Promise<BookingRow> => {
    const result = await context.supabase.rpc("confirm_booking_after_advance", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Booking confirmation returned no row.");
    }

    return result.data;
  });

export const startPreShootPreparation = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(startPreShootPreparationSchema)
  .handler(async ({ context, data }): Promise<BookingPreparationRow> => {
    const result = await context.supabase.rpc("start_pre_shoot_preparation", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Pre-shoot preparation start returned no row.");
    }

    return result.data;
  });

export const updatePreShootPreparationItem = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(updatePreShootPreparationItemSchema)
  .handler(async ({ context, data }): Promise<BookingPreparationItemRow> => {
    const result = await context.supabase.rpc("update_pre_shoot_preparation_item", {
      p_preparation_item_id: data.preparationItemId,
      p_satisfied: data.satisfied,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Preparation item update returned no row.");
    }

    return result.data;
  });

export const recordBookingSafetyReadiness = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(recordBookingSafetyReadinessSchema)
  .handler(async ({ context, data }): Promise<BookingSafetyReadinessRow> => {
    const result = await context.supabase.rpc("record_booking_safety_readiness", {
      p_booking_id: data.bookingId,
      p_safety_state: data.safetyState,
      p_comfort_state: data.comfortState,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Safety readiness recording returned no row.");
    }

    return result.data;
  });

export const signoffBookingSafetyReadiness = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(signoffBookingSafetyReadinessSchema)
  .handler(async ({ context, data }): Promise<BookingSafetySignoffRow> => {
    const result = await context.supabase.rpc("signoff_booking_safety_readiness", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Safety readiness sign-off returned no row.");
    }

    return result.data;
  });

export const markBookingShootScheduled = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(markBookingShootScheduledSchema)
  .handler(async ({ context, data }): Promise<BookingRow> => {
    const result = await context.supabase.rpc("mark_booking_shoot_scheduled", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Shoot scheduled advancement returned no row.");
    }

    return result.data;
  });

export const recordBookingShootCompletion = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(recordBookingShootCompletionSchema)
  .handler(async ({ context, data }): Promise<BookingShootCompletionRow> => {
    const result = await context.supabase.rpc("record_booking_shoot_completion", {
      p_booking_id: data.bookingId,
      p_completed_at: data.completedAt,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Shoot completion recording returned no row.");
    }

    return result.data;
  });

export const markBookingShootCompleted = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(markBookingShootCompletedSchema)
  .handler(async ({ context, data }): Promise<BookingRow> => {
    const result = await context.supabase.rpc("mark_booking_shoot_completed", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Shoot completed advancement returned no row.");
    }

    return result.data;
  });

export const markBookingSelectionPending = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(markBookingSelectionPendingSchema)
  .handler(async ({ context, data }): Promise<BookingRow> => {
    const result = await context.supabase.rpc("mark_booking_selection_pending", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Selection pending advancement returned no row.");
    }

    return result.data;
  });

export const recordBookingSelectionCompletion = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(recordBookingSelectionCompletionSchema)
  .handler(async ({ context, data }): Promise<BookingSelectionCompletionRow> => {
    const result = await context.supabase.rpc("record_booking_selection_completion", {
      p_booking_id: data.bookingId,
      p_selected_image_keys: data.selectedImageKeys,
      p_source_type: data.sourceType,
      p_external_reference: data.externalReference,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Selection completion recording returned no row.");
    }

    return result.data;
  });

export const markBookingEditingPending = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(markBookingEditingPendingSchema)
  .handler(async ({ context, data }): Promise<BookingRow> => {
    const result = await context.supabase.rpc("mark_booking_editing_pending", {
      p_booking_id: data.bookingId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Editing pending advancement returned no row.");
    }

    return result.data;
  });
