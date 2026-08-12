import { createClient } from "@supabase/supabase-js";
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { ORGANIZATION_ID } from "@/lib/session";

export type MemoryGuidePackageSnapshot = {
  package_key: string;
  tier: "bronze" | "gold" | "diamond" | "emerald";
  public_name: string;
  list_price_inr: number;
  public_offer_enabled: boolean;
  summary: string;
  inclusions: string[];
};

export type MemoryGuideDecision = {
  id: string;
  primary_package: MemoryGuidePackageSnapshot | null;
  alternative_package: MemoryGuidePackageSnapshot | null;
  reasons: string[];
  explanation: string;
  confidence: "high" | "medium" | "review_required";
  assumptions: string[];
  privacy_note: string;
  review_required: boolean;
  review_codes: string[];
  future_milestone: string | null;
  next_actions: string[];
  decision_input_version: number;
  versions: { guide: string; scoring: string; catalogue: string };
};

export type MemoryGuideState = {
  session: {
    id: string;
    reference: string;
    version: number;
    status: string;
    current_stage: string;
    progress_percent: number;
    expires_at: string;
    source_page: string | null;
    service_preselection: string | null;
    next_action: string | null;
  };
  answers: Record<string, string | string[] | boolean>;
  contact: null | {
    contact_name: string;
    contact_phone: string;
    contact_email: string | null;
    contact_permission: boolean;
    preferred_contact: string;
  };
  decision: MemoryGuideDecision | null;
};

export type MemoryGuideReviewRow = {
  review_id: string | null;
  session_id: string;
  session_reference: string;
  session_status: string;
  review_type: string;
  trigger_code: string;
  visibility: "open" | "restricted" | "blocked";
  review_status: "open" | "in_progress" | "resolved" | "dismissed";
  owner_member_id: string;
  due_at: string;
  created_at: string;
  service_category: string | null;
  confidence: string | null;
  primary_package: MemoryGuidePackageSnapshot | null;
  contact: null | {
    name: string;
    phone: string;
    email: string | null;
    preferred_contact: string;
    permission: boolean;
  };
  lead_id: string | null;
  crm_status: string | null;
  next_action: string | null;
};

const answerValueSchema = z.union([
  z.string().max(500),
  z.array(z.string().max(100)).max(8),
  z.boolean(),
]);

function anonSupabase() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Supabase public server configuration is missing.");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

function throwIfError(error: { message: string } | null) {
  if (error) throw new Error(error.message);
}

export const startMemoryGuide = createServerFn({ method: "POST" })
  .validator((input) =>
    z
      .object({
        sourcePage: z.string().trim().max(120).optional().nullable(),
        servicePreselection: z
          .enum([
            "maternity",
            "newborn",
            "sitter",
            "baby",
            "birthday",
            "child",
            "family",
            "generational",
          ])
          .optional()
          .nullable(),
        campaignId: z.string().trim().max(120).optional().nullable(),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "start_memory_guide" as never,
      {
        p_organization_id: ORGANIZATION_ID,
        p_source_page: data.sourcePage ?? null,
        p_service_preselection: data.servicePreselection ?? null,
        p_campaign_id: data.campaignId ?? null,
      } as never,
    );
    throwIfError(result.error);
    const row = (result.data as unknown as Array<Record<string, unknown>> | null)?.[0];
    if (!row) throw new Error("Memory Guide could not start.");
    return row as {
      session_id: string;
      session_reference: string;
      access_token: string;
      session_version: number;
      current_stage: string;
      progress_percent: number;
      expires_at: string;
    };
  });

export const getMemoryGuideState = createServerFn({ method: "GET" })
  .validator((input) => z.object({ accessToken: z.string().min(32).max(200) }).parse(input))
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "get_memory_guide_state" as never,
      {
        p_access_token: data.accessToken,
      } as never,
    );
    throwIfError(result.error);
    return result.data as unknown as MemoryGuideState;
  });

export const saveMemoryGuideAnswers = createServerFn({ method: "POST" })
  .validator((input) =>
    z
      .object({
        accessToken: z.string().min(32).max(200),
        expectedVersion: z.number().int().positive(),
        stageId: z.string().regex(/^STG-\d{2}$/),
        answers: z.record(answerValueSchema),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "save_memory_guide_answers" as never,
      {
        p_access_token: data.accessToken,
        p_expected_version: data.expectedVersion,
        p_stage_id: data.stageId,
        p_answers: data.answers,
      } as never,
    );
    throwIfError(result.error);
    const row = (result.data as unknown as Array<Record<string, unknown>> | null)?.[0];
    if (!row) throw new Error("Memory Guide answers were not saved.");
    return row as {
      session_version: number;
      current_stage: string;
      progress_percent: number;
      last_saved_at: string;
    };
  });

export const saveMemoryGuideContact = createServerFn({ method: "POST" })
  .validator((input) =>
    z
      .object({
        accessToken: z.string().min(32).max(200),
        contactName: z.string().trim().max(80),
        contactPhone: z.string().trim().max(30),
        contactEmail: z.string().trim().max(160).optional().nullable(),
        contactPermission: z.boolean(),
        preferredContact: z.enum(["whatsapp", "phone", "email", "no_preference"]),
      })
      .superRefine((value, ctx) => {
        if (!value.contactPermission) return;
        if (!value.contactName)
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["contactName"],
            message: "Contact name is required.",
          });
        if (!/^\+[0-9]{8,15}$/.test(value.contactPhone))
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["contactPhone"],
            message: "Use an international mobile number.",
          });
        if (value.contactEmail && !z.string().email().safeParse(value.contactEmail).success)
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["contactEmail"],
            message: "Invalid email address.",
          });
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "save_memory_guide_contact" as never,
      {
        p_access_token: data.accessToken,
        p_contact_name: data.contactName,
        p_contact_phone: data.contactPhone,
        p_contact_email: data.contactEmail ?? null,
        p_contact_permission: data.contactPermission,
        p_preferred_contact: data.preferredContact,
      } as never,
    );
    throwIfError(result.error);
    return Boolean(result.data);
  });

export const createMemoryGuideResume = createServerFn({ method: "POST" })
  .validator((input) => z.object({ accessToken: z.string().min(32).max(200) }).parse(input))
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "create_memory_guide_resume" as never,
      {
        p_access_token: data.accessToken,
      } as never,
    );
    throwIfError(result.error);
    const row = (result.data as unknown as Array<Record<string, unknown>> | null)?.[0];
    if (!row) throw new Error("A resume link could not be created.");
    return row as { resume_token: string; resume_expires_at: string };
  });

export const resumeMemoryGuide = createServerFn({ method: "POST" })
  .validator((input) => z.object({ resumeToken: z.string().min(32).max(200) }).parse(input))
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "resume_memory_guide_session" as never,
      {
        p_resume_token: data.resumeToken,
      } as never,
    );
    throwIfError(result.error);
    const row = (result.data as unknown as Array<Record<string, unknown>> | null)?.[0] as
      | {
          ok: boolean;
          error_code: string | null;
          access_token: string | null;
          session_version: number | null;
        }
      | undefined;
    if (!row?.ok || !row.access_token)
      throw new Error("This resume link is unavailable or has already been used.");
    return { accessToken: row.access_token, sessionVersion: row.session_version };
  });

export const processMemoryGuideDecision = createServerFn({ method: "POST" })
  .validator((input) =>
    z
      .object({
        accessToken: z.string().min(32).max(200),
        expectedVersion: z.number().int().positive(),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "process_memory_guide_decision" as never,
      {
        p_access_token: data.accessToken,
        p_expected_version: data.expectedVersion,
      } as never,
    );
    throwIfError(result.error);
    return result.data as unknown as MemoryGuideDecision;
  });

export const recordMemoryGuideNextAction = createServerFn({ method: "POST" })
  .validator((input) =>
    z
      .object({
        accessToken: z.string().min(32).max(200),
        nextAction: z.enum([
          "book_consultation",
          "request_quote",
          "whatsapp",
          "save_for_later",
          "human_review",
        ]),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const client = anonSupabase();
    const result = await client.rpc(
      "record_memory_guide_next_action" as never,
      {
        p_access_token: data.accessToken,
        p_next_action: data.nextAction,
      } as never,
    );
    throwIfError(result.error);
    return Boolean(result.data);
  });

export const listMemoryGuideReviewCenter = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const result = await context.supabase.rpc(
      "list_memory_guide_review_center" as never,
      {
        p_organization_id: ORGANIZATION_ID,
      } as never,
    );
    throwIfError(result.error);
    return (result.data ?? []) as unknown as MemoryGuideReviewRow[];
  });

export const syncMemoryGuideToCrm = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((input) => z.object({ sessionId: z.string().uuid() }).parse(input))
  .handler(async ({ data, context }) => {
    const result = await context.supabase.rpc(
      "sync_memory_guide_to_crm" as never,
      {
        p_session_id: data.sessionId,
      } as never,
    );
    throwIfError(result.error);
    return result.data as unknown as {
      status: "synced" | "retry" | "dead_letter" | "manual_action_required" | "not_queued";
      lead_id?: string;
      reason?: string;
      error_code?: string;
      idempotent?: boolean;
    };
  });

export const updateMemoryGuideReview = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((input) =>
    z
      .object({
        reviewId: z.string().uuid(),
        status: z.enum(["open", "in_progress", "resolved", "dismissed"]),
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const result = await context.supabase.rpc(
      "update_memory_guide_review" as never,
      {
        p_review_id: data.reviewId,
        p_status: data.status,
      } as never,
    );
    throwIfError(result.error);
    return result.data as unknown as { review_id: string; status: string };
  });

export const getMemoryGuideSensitiveAnswers = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .validator((input) => z.object({ sessionId: z.string().uuid() }).parse(input))
  .handler(async ({ data, context }) => {
    const result = await context.supabase.rpc(
      "get_memory_guide_sensitive_answers" as never,
      {
        p_session_id: data.sessionId,
      } as never,
    );
    throwIfError(result.error);
    return (result.data ?? {}) as unknown as Record<string, string | string[] | boolean>;
  });
