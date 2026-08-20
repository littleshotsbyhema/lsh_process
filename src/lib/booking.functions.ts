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

export type BookingShootScheduleRow =
  Database["public"]["Tables"]["booking_shoot_schedules"]["Row"];

export type BookingPaymentRow = Database["public"]["Tables"]["booking_payments"]["Row"];

export type BookingPreparationRow = Database["public"]["Tables"]["booking_preparations"]["Row"];

export type BookingPreparationItemRow =
  Database["public"]["Tables"]["booking_preparation_items"]["Row"];

export type BookingPaymentMethod = Database["public"]["Enums"]["booking_payment_method"];

export type BookingPaymentSummary =
  Database["public"]["Functions"]["get_booking_payment_summary"]["Returns"][number];

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

export type BookingWorkspaceData = {
  bookings: BookingRow[];
  quotations: BookingQuotationSummary[];
  quotationLines: BookingQuotationLine[];
  journeyStates: BookingJourneyStateRow[];
  journeyStages: BookingJourneyStageRow[];
  transitions: BookingStageTransitionRow[];
  schedules: BookingShootScheduleRow[];
  leads: BookingLeadSummary[];
  families: BookingFamilySummary[];
  paymentSummaries: BookingPaymentSummary[];
  bookingPreparations: BookingPreparationRow[];
  bookingPreparationItems: BookingPreparationItemRow[];
  bookingTeamAssignmentHistory: BookingTeamAssignmentHistoryRow[];
  canReadPayment: boolean;
  canRecordPayment: boolean;
  canConfirmBooking: boolean;
  canReadPreparation: boolean;
  canWritePreparation: boolean;
  canAdvanceBookingStage: boolean;
  canSchedule: boolean;
  canAssignBookingTeam: boolean;
};

function throwIfError(error: { message: string } | null) {
  if (error) {
    throw new Error(error.message);
  }
}

const proposeShootScheduleSchema = z.object({
  bookingId: z.string().uuid(),
  scheduledStartAt: z.string().datetime({ offset: true }),
  scheduledEndAt: z.string().datetime({ offset: true }),
  timezone: z.string().trim().min(1),
  locationType: z.string().trim().min(1),
  locationDetails: z.string().trim().min(1).optional(),
});

const rescheduleShootSchema = z.object({
  bookingId: z.string().uuid(),
  scheduledStartAt: z.string().datetime({ offset: true }),
  scheduledEndAt: z.string().datetime({ offset: true }),
  timezone: z.string().trim().min(1),
  locationType: z.string().trim().min(1),
  rescheduleReason: z.string().trim().min(1),
  locationDetails: z.string().trim().min(1).optional(),
});

const recordBookingPaymentSchema = z.object({
  bookingId: z.string().uuid(),
  amountInr: z.number().int().positive(),
  paymentMethod: z.enum(["cash", "upi", "bank_transfer", "card", "other"]),
  receivedAt: z.string().datetime({ offset: true }),
  externalReference: z.string().trim().min(1).optional(),
  note: z.string().trim().min(1).optional(),
});

const confirmBookingAfterAdvanceSchema = z.object({
  bookingId: z.string().uuid(),
});

const startPreShootPreparationSchema = z.object({
  bookingId: z.string().uuid(),
});

const updatePreShootPreparationItemSchema = z.object({
  preparationItemId: z.string().uuid(),
  satisfied: z.boolean(),
});

const bookingTeamAssignmentCandidatesSchema = z.object({
  bookingId: z.string().uuid(),
});

export const listBookingWorkspace = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<BookingWorkspaceData> => {
    const [bookingsResult, permissionResult] = await Promise.all([
      context.supabase
        .from("bookings")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .order("created_at", {
          ascending: false,
        })
        .limit(100),

      context.supabase.rpc("effective_permissions", {
        p_organization_id: ORGANIZATION_ID,
      }),
    ]);

    throwIfError(bookingsResult.error);
    throwIfError(permissionResult.error);

    const bookings = bookingsResult.data ?? [];
    const permissions = new Set(permissionResult.data ?? []);
    const canReadPayment = permissions.has("payment.read");
    const canRecordPayment = permissions.has("payment.record");
    const canConfirmBooking = permissions.has("booking.confirm");
    const canReadPreparation = permissions.has("prep.read");
    const canWritePreparation = permissions.has("prep.write");
    const canAdvanceBookingStage = permissions.has("booking.stage.advance");
    const canSchedule = permissions.has("shoot.schedule");
    const canAssignBookingTeam = permissions.has("booking.team.assign");

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
        schedules: [],
        leads: [],
        families: [],
        paymentSummaries: [],
        bookingPreparations: [],
        bookingPreparationItems: [],
        bookingTeamAssignmentHistory: [],
        canReadPayment,
        canRecordPayment,
        canConfirmBooking,
        canReadPreparation,
        canWritePreparation,
        canAdvanceBookingStage,
        canSchedule,
        canAssignBookingTeam,
      };
    }

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

    const [
      quotationsResult,
      quotationLinesResult,
      statesResult,
      stagesResult,
      transitionsResult,
      schedulesResult,
    ] = await Promise.all([
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

      context.supabase
        .from("booking_shoot_schedules")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds)
        .order("schedule_version", {
          ascending: true,
        }),
    ]);

    throwIfError(quotationsResult.error);
    throwIfError(quotationLinesResult.error);
    throwIfError(statesResult.error);
    throwIfError(stagesResult.error);
    throwIfError(transitionsResult.error);
    throwIfError(schedulesResult.error);

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

    const paymentSummaries: BookingPaymentSummary[] = [];

    if (canReadPayment) {
      const paymentSummaryResults = await Promise.all(
        bookingIds.map((bookingId) =>
          context.supabase.rpc("get_booking_payment_summary", {
            p_booking_id: bookingId,
          }),
        ),
      );

      for (const summaryResult of paymentSummaryResults) {
        throwIfError(summaryResult.error);

        const rows = summaryResult.data ?? [];
        const summary = rows[0];

        if (rows.length !== 1 || !summary) {
          throw new Error("Booking payment summary returned an unexpected row count.");
        }

        paymentSummaries.push(summary);
      }
    }

    let bookingPreparations: BookingPreparationRow[] = [];
    let bookingPreparationItems: BookingPreparationItemRow[] = [];

    if (canReadPreparation) {
      const preparationsResult = await context.supabase
        .from("booking_preparations")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("booking_id", bookingIds)
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

    const bookingTeamAssignmentHistory: BookingTeamAssignmentHistoryRow[] = [];

    const bookingTeamHistoryResults = await Promise.all(
      bookingIds.map((bookingId) =>
        context.supabase.rpc("get_booking_team_assignment_history", {
          p_booking_id: bookingId,
        }),
      ),
    );

    for (const historyResult of bookingTeamHistoryResults) {
      throwIfError(historyResult.error);
      bookingTeamAssignmentHistory.push(...(historyResult.data ?? []));
    }

    return {
      bookings,
      quotations: quotationsResult.data ?? [],
      quotationLines: quotationLinesResult.data ?? [],
      journeyStates: statesResult.data ?? [],
      journeyStages: stagesResult.data ?? [],
      transitions: transitionsResult.data ?? [],
      schedules: schedulesResult.data ?? [],
      leads,
      families,
      paymentSummaries,
      bookingPreparations,
      bookingPreparationItems,
      bookingTeamAssignmentHistory,
      canReadPayment,
      canRecordPayment,
      canConfirmBooking,
      canReadPreparation,
      canWritePreparation,
      canAdvanceBookingStage,
      canSchedule,
      canAssignBookingTeam,
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

export const proposeShootSchedule = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(proposeShootScheduleSchema)
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
      throw new Error("Schedule proposal returned no row.");
    }

    return result.data;
  });

export const rescheduleShoot = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(rescheduleShootSchema)
  .handler(async ({ context, data }): Promise<BookingShootScheduleRow> => {
    const result = await context.supabase.rpc("reschedule_booking_shoot", {
      p_booking_id: data.bookingId,
      p_scheduled_start_at: data.scheduledStartAt,
      p_scheduled_end_at: data.scheduledEndAt,
      p_timezone: data.timezone,
      p_location_type: data.locationType,
      p_reschedule_reason: data.rescheduleReason,
      p_location_details: data.locationDetails,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Reschedule returned no row.");
    }

    return result.data;
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

export const confirmBookingAfterAdvance = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(confirmBookingAfterAdvanceSchema)
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
