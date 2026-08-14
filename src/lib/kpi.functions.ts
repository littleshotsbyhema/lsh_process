import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { Database } from "@/integrations/supabase/types";
import { ORGANIZATION_ID } from "@/lib/session";

type FounderKpiSummaryRpcRow =
  Database["public"]["Functions"]["get_founder_kpi_summary"]["Returns"][number];

type FounderBookingStageKpiRpcRow =
  Database["public"]["Functions"]["get_founder_booking_stage_kpis"]["Returns"][number];

export type FounderKpiSummary = {
  organization_id: string;
  branch_id: string | null;
  period_start: string;
  period_end: string;

  new_inquiries_count: number;

  quotations_sent_count: number;
  quoted_value_inr: number;

  quotations_accepted_count: number;
  accepted_value_inr: number;

  bookings_created_count: number;
  bookings_confirmed_count: number;

  payments_collected_inr: number;

  sent_quote_cohort_accepted_count: number;
  sent_quote_acceptance_rate_pct: number | null;

  inquiry_cohort_accepted_count: number;
  inquiry_to_accepted_quote_rate_pct: number | null;

  accepted_quote_cohort_booked_count: number;
  accepted_quote_to_booking_rate_pct: number | null;

  booking_cohort_confirmed_count: number;
  booking_to_confirmed_rate_pct: number | null;

  required_advance_as_of_end_inr: number;
  valid_collected_as_of_end_inr: number;
  advance_outstanding_as_of_end_inr: number;

  advance_satisfied_bookings_as_of_end_count: number;
  advance_pending_stage_as_of_end_count: number;
  booking_confirmed_stage_as_of_end_count: number;
  confirmed_with_advance_shortfall_as_of_end_count: number;
};

export type FounderBookingStageKpi = {
  stage_order: number;
  stage_key: string;
  booking_count: number;
  average_stage_age_seconds: number | null;
  oldest_stage_age_seconds: number | null;
};

const timestampSchema = z
  .string()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), "Expected a valid timestamp");

const branchIdSchema = z.string().uuid().nullable().optional();

const founderKpiSummaryInputSchema = z
  .object({
    periodStart: timestampSchema,
    periodEnd: timestampSchema,
    branchId: branchIdSchema,
  })
  .refine(({ periodStart, periodEnd }) => Date.parse(periodStart) < Date.parse(periodEnd), {
    message: "periodStart must be earlier than periodEnd",
    path: ["periodEnd"],
  });

const founderBookingStageKpiInputSchema = z.object({
  asOf: timestampSchema,
  branchId: branchIdSchema,
});

function throwIfError(error: { message: string } | null) {
  if (error) {
    throw new Error(error.message);
  }
}

function normalizeFounderKpiSummary(row: FounderKpiSummaryRpcRow): FounderKpiSummary {
  return {
    organization_id: row.organization_id,
    branch_id: row.branch_id ?? null,
    period_start: row.period_start,
    period_end: row.period_end,

    new_inquiries_count: row.new_inquiries_count,

    quotations_sent_count: row.quotations_sent_count,
    quoted_value_inr: row.quoted_value_inr,

    quotations_accepted_count: row.quotations_accepted_count,
    accepted_value_inr: row.accepted_value_inr,

    bookings_created_count: row.bookings_created_count,
    bookings_confirmed_count: row.bookings_confirmed_count,

    payments_collected_inr: row.payments_collected_inr,

    sent_quote_cohort_accepted_count: row.sent_quote_cohort_accepted_count,
    sent_quote_acceptance_rate_pct: row.sent_quote_acceptance_rate_pct ?? null,

    inquiry_cohort_accepted_count: row.inquiry_cohort_accepted_count,
    inquiry_to_accepted_quote_rate_pct: row.inquiry_to_accepted_quote_rate_pct ?? null,

    accepted_quote_cohort_booked_count: row.accepted_quote_cohort_booked_count,
    accepted_quote_to_booking_rate_pct: row.accepted_quote_to_booking_rate_pct ?? null,

    booking_cohort_confirmed_count: row.booking_cohort_confirmed_count,
    booking_to_confirmed_rate_pct: row.booking_to_confirmed_rate_pct ?? null,

    required_advance_as_of_end_inr: row.required_advance_as_of_end_inr,
    valid_collected_as_of_end_inr: row.valid_collected_as_of_end_inr,
    advance_outstanding_as_of_end_inr: row.advance_outstanding_as_of_end_inr,

    advance_satisfied_bookings_as_of_end_count: row.advance_satisfied_bookings_as_of_end_count,
    advance_pending_stage_as_of_end_count: row.advance_pending_stage_as_of_end_count,
    booking_confirmed_stage_as_of_end_count: row.booking_confirmed_stage_as_of_end_count,
    confirmed_with_advance_shortfall_as_of_end_count:
      row.confirmed_with_advance_shortfall_as_of_end_count,
  };
}

function normalizeFounderBookingStageKpi(
  row: FounderBookingStageKpiRpcRow,
): FounderBookingStageKpi {
  return {
    stage_order: row.stage_order,
    stage_key: row.stage_key,
    booking_count: row.booking_count,
    average_stage_age_seconds: row.average_stage_age_seconds ?? null,
    oldest_stage_age_seconds: row.oldest_stage_age_seconds ?? null,
  };
}

export const getFounderKpiSummary = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .validator((input) => founderKpiSummaryInputSchema.parse(input))
  .handler(async ({ data, context }): Promise<FounderKpiSummary> => {
    const args: Database["public"]["Functions"]["get_founder_kpi_summary"]["Args"] = {
      p_organization_id: ORGANIZATION_ID,
      p_period_start: data.periodStart,
      p_period_end: data.periodEnd,
    };

    if (data.branchId) {
      args.p_branch_id = data.branchId;
    }

    const result = await context.supabase.rpc("get_founder_kpi_summary", args);

    throwIfError(result.error);

    const row = result.data?.[0];

    if (!row) {
      throw new Error("Founder KPI summary returned no row");
    }

    return normalizeFounderKpiSummary(row);
  });

export const getFounderBookingStageKpis = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .validator((input) => founderBookingStageKpiInputSchema.parse(input))
  .handler(async ({ data, context }): Promise<FounderBookingStageKpi[]> => {
    const args: Database["public"]["Functions"]["get_founder_booking_stage_kpis"]["Args"] = {
      p_organization_id: ORGANIZATION_ID,
      p_as_of: data.asOf,
    };

    if (data.branchId) {
      args.p_branch_id = data.branchId;
    }

    const result = await context.supabase.rpc("get_founder_booking_stage_kpis", args);

    throwIfError(result.error);

    return (result.data ?? []).map(normalizeFounderBookingStageKpi);
  });
