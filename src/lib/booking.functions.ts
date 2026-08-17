import { createServerFn } from "@tanstack/react-start";

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
};

function throwIfError(error: { message: string } | null) {
  if (error) {
    throw new Error(error.message);
  }
}

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
        schedules: [],
        leads: [],
        families: [],
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
    };
  });
