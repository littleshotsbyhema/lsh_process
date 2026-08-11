import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { ORGANIZATION_ID } from "@/lib/session";

export const leadStatuses = [
  "new_inquiry",
  "contacted",
  "qualified",
  "consultation_scheduled",
  "quote_ready",
  "quote_sent",
  "follow_up_needed",
  "converted",
  "lost",
  "archived",
] as const;

export type LeadStatus = (typeof leadStatuses)[number];

export const privacyPreferences = [
  "full_privacy",
  "selective_sharing",
  "anonymous_sharing",
  "portfolio_release",
  "decide_later",
] as const;

export type PrivacyPreference =
  (typeof privacyPreferences)[number];

export type LeadRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  lead_reference: string;

  source: string;
  parent_name: string;

  phone: string | null;
  email: string | null;
  city: string | null;

  session_type: string | null;
  baby_age_or_pregnancy: string | null;
  preferred_date: string | null;
  location_preference: string | null;

  package_interest: string | null;
  budget_comfort: string | null;

  memory_goal: string | null;
  privacy_preference: PrivacyPreference | null;

  status: LeadStatus;
  follow_up_at: string | null;

  assigned_owner_member_id: string | null;

  converted_family_id: string | null;
  converted_at: string | null;
  converted_by: string | null;

  lost_reason: string | null;
  internal_notes: string | null;

  created_at: string;
  created_by: string;

  updated_at: string;
  updated_by: string;

  archived_at: string | null;
  archived_by: string | null;
};

export type ConvertedFamilyRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  family_code: string;
  display_name: string;
  sort_name: string;
  status: string;
  assigned_owner_member_id: string | null;
  created_at: string;
  updated_at: string;
};

const nullableText = z
  .string()
  .trim()
  .max(1000)
  .optional()
  .nullable()
  .transform((value) => {
    if (value == null || value === "") {
      return null;
    }

    return value;
  });

const nullableUuid = z
  .string()
  .uuid()
  .optional()
  .nullable()
  .transform((value) => value || null);

const nullableDate = z
  .string()
  .optional()
  .nullable()
  .transform((value) => value || null)
  .refine(
    (value) =>
      value === null ||
      /^\d{4}-\d{2}-\d{2}$/.test(value),
    "Date must use YYYY-MM-DD format.",
  );

const nullableTimestamp = z
  .string()
  .optional()
  .nullable()
  .transform((value) => value || null)
  .refine(
    (value) =>
      value === null ||
      !Number.isNaN(Date.parse(value)),
    "Invalid date and time.",
  );

const nullableEmail = z
  .string()
  .trim()
  .optional()
  .nullable()
  .transform((value) => {
    if (value == null || value === "") {
      return null;
    }

    return value.toLowerCase();
  })
  .refine(
    (value) =>
      value === null ||
      z.string().email().safeParse(value).success,
    "Enter a valid email address.",
  );

const nullablePhone = z
  .string()
  .trim()
  .optional()
  .nullable()
  .transform((value) => {
    if (value == null || value === "") {
      return null;
    }

    return value;
  })
  .refine(
    (value) =>
      value === null ||
      /^\+[0-9]{8,15}$/.test(value),
    "Phone must use international format, for example +919876543210.",
  );

const privacyPreferenceSchema = z
  .enum(privacyPreferences)
  .optional()
  .nullable();

const createLeadSchema = z
  .object({
    parentName: z.string().trim().min(
      1,
      "Parent name is required.",
    ).max(200),

    source: z.string().trim().min(
      1,
      "Lead source is required.",
    ).max(120),

    phone: nullablePhone,
    email: nullableEmail,
    city: nullableText,

    sessionType: nullableText,
    babyAgeOrPregnancy: nullableText,
    preferredDate: nullableDate,
    locationPreference: nullableText,

    packageInterest: nullableText,
    budgetComfort: nullableText,

    memoryGoal: nullableText,
    privacyPreference: privacyPreferenceSchema,

    followUpAt: nullableTimestamp,

    branchId: nullableUuid,
    assignedOwnerMemberId: nullableUuid,
  })
  .refine(
    (data) => Boolean(data.phone || data.email),
    {
      message:
        "A phone number or email address is required.",
      path: ["phone"],
    },
  );

const updateLeadSchema = z
  .object({
    leadId: z.string().uuid(),

    parentName: z.string().trim().min(
      1,
      "Parent name is required.",
    ).max(200),

    source: z.string().trim().min(
      1,
      "Lead source is required.",
    ).max(120),

    phone: nullablePhone,
    email: nullableEmail,
    city: nullableText,

    sessionType: nullableText,
    babyAgeOrPregnancy: nullableText,
    preferredDate: nullableDate,
    locationPreference: nullableText,

    packageInterest: nullableText,
    budgetComfort: nullableText,

    memoryGoal: nullableText,
    privacyPreference: privacyPreferenceSchema,

    followUpAt: nullableTimestamp,

    status: z.enum(leadStatuses),
    lostReason: nullableText,

    branchId: nullableUuid,
    assignedOwnerMemberId: nullableUuid,
  })
  .refine(
    (data) => Boolean(data.phone || data.email),
    {
      message:
        "A phone number or email address is required.",
      path: ["phone"],
    },
  )
  .refine(
    (data) =>
      data.status !== "lost" ||
      Boolean(data.lostReason),
    {
      message:
        "A reason is required when an inquiry is marked lost.",
      path: ["lostReason"],
    },
  )
  .refine(
    (data) => data.status !== "converted",
    {
      message:
        "Converted status may only be set through lead conversion.",
      path: ["status"],
    },
  );

const convertLeadSchema = z.object({
  leadId: z.string().uuid(),

  familyDisplayName: z
    .string()
    .trim()
    .max(200)
    .optional()
    .nullable()
    .transform((value) => value || null),

  familySortName: z
    .string()
    .trim()
    .max(200)
    .optional()
    .nullable()
    .transform((value) => value || null),
});

export const listLeads = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .handler(
    async ({ context }): Promise<LeadRow[]> => {
      const { data, error } = await context.supabase
        .from("leads" as never)
        .select(
          [
            "id",
            "organization_id",
            "branch_id",
            "lead_reference",
            "source",
            "parent_name",
            "phone",
            "email",
            "city",
            "session_type",
            "baby_age_or_pregnancy",
            "preferred_date",
            "location_preference",
            "package_interest",
            "budget_comfort",
            "memory_goal",
            "privacy_preference",
            "status",
            "follow_up_at",
            "assigned_owner_member_id",
            "converted_family_id",
            "converted_at",
            "converted_by",
            "lost_reason",
            "internal_notes",
            "created_at",
            "created_by",
            "updated_at",
            "updated_by",
            "archived_at",
            "archived_by",
          ].join(","),
        )
        .eq(
          "organization_id" as never,
          ORGANIZATION_ID as never,
        )
        .order("created_at" as never, {
          ascending: false,
        });

      if (error) {
        throw new Error(error.message);
      }

      return (data ?? []) as unknown as LeadRow[];
    },
  );

export const createLead = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    createLeadSchema.parse(input),
  )
  .handler(
    async ({ data, context }): Promise<LeadRow> => {
      const { data: row, error } =
        await context.supabase.rpc(
          "create_lead" as never,
          {
            p_organization_id: ORGANIZATION_ID,
            p_parent_name: data.parentName,
            p_source: data.source,
            p_phone: data.phone,
            p_email: data.email,
            p_city: data.city,
            p_session_type: data.sessionType,
            p_baby_age_or_pregnancy:
              data.babyAgeOrPregnancy,
            p_preferred_date: data.preferredDate,
            p_location_preference:
              data.locationPreference,
            p_package_interest:
              data.packageInterest,
            p_budget_comfort: data.budgetComfort,
            p_memory_goal: data.memoryGoal,
            p_privacy_preference:
              data.privacyPreference,
            p_follow_up_at: data.followUpAt,
            p_branch_id: data.branchId,
            p_assigned_owner_member_id:
              data.assignedOwnerMemberId,
          } as never,
        );

      if (error) {
        throw new Error(error.message);
      }

      if (!row) {
        throw new Error(
          "Lead creation did not return an inquiry.",
        );
      }

      return row as unknown as LeadRow;
    },
  );

export const updateLead = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    updateLeadSchema.parse(input),
  )
  .handler(
    async ({ data, context }): Promise<LeadRow> => {
      const { data: row, error } =
        await context.supabase.rpc(
          "update_lead" as never,
          {
            p_lead_id: data.leadId,
            p_parent_name: data.parentName,
            p_source: data.source,
            p_phone: data.phone,
            p_email: data.email,
            p_city: data.city,
            p_session_type: data.sessionType,
            p_baby_age_or_pregnancy:
              data.babyAgeOrPregnancy,
            p_preferred_date: data.preferredDate,
            p_location_preference:
              data.locationPreference,
            p_package_interest:
              data.packageInterest,
            p_budget_comfort: data.budgetComfort,
            p_memory_goal: data.memoryGoal,
            p_privacy_preference:
              data.privacyPreference,
            p_follow_up_at: data.followUpAt,
            p_status: data.status,
            p_lost_reason: data.lostReason,
            p_branch_id: data.branchId,
            p_assigned_owner_member_id:
              data.assignedOwnerMemberId,
          } as never,
        );

      if (error) {
        throw new Error(error.message);
      }

      if (!row) {
        throw new Error(
          "Lead update did not return an inquiry.",
        );
      }

      return row as unknown as LeadRow;
    },
  );

export const convertLeadToFamily = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    convertLeadSchema.parse(input),
  )
  .handler(
    async ({
      data,
      context,
    }): Promise<ConvertedFamilyRow> => {
      const { data: row, error } =
        await context.supabase.rpc(
          "convert_lead_to_family" as never,
          {
            p_lead_id: data.leadId,
            p_family_display_name:
              data.familyDisplayName,
            p_family_sort_name:
              data.familySortName,
          } as never,
        );

      if (error) {
        throw new Error(error.message);
      }

      if (!row) {
        throw new Error(
          "Lead conversion did not return a family.",
        );
      }

      return row as unknown as ConvertedFamilyRow;
    },
  );
