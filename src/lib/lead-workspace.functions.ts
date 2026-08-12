import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { ORGANIZATION_ID } from "@/lib/session";
import type { LeadRow } from "@/lib/leads.functions";

export const leadTaskStatuses = [
  "open",
  "in_progress",
  "snoozed",
  "completed",
  "cancelled",
] as const;
export type LeadTaskStatus = (typeof leadTaskStatuses)[number];

export const leadTaskPriorities = ["low", "normal", "high", "urgent"] as const;
export type LeadTaskPriority = (typeof leadTaskPriorities)[number];

export const leadTaskTypes = [
  "first_response",
  "follow_up",
  "consultation",
  "quote",
  "privacy_review",
  "safety_review",
  "stale_lead",
  "reminder_recovery",
  "assignment",
  "document",
  "internal_review",
  "other",
] as const;
export type LeadTaskType = (typeof leadTaskTypes)[number];

export const communicationChannels = [
  "whatsapp",
  "email",
  "sms",
  "phone",
  "portal",
  "in_person",
  "manual",
] as const;
export type CommunicationChannel = (typeof communicationChannels)[number];

export const communicationDirections = ["inbound", "outbound", "internal"] as const;
export type CommunicationDirection = (typeof communicationDirections)[number];

export const communicationStatuses = [
  "queued",
  "accepted",
  "delivered",
  "read",
  "failed",
  "unknown",
  "manual_confirmed",
] as const;
export type CommunicationStatus = (typeof communicationStatuses)[number];

export const consultationStatuses = [
  "pending_confirmation",
  "tentative",
  "scheduled",
  "completed",
  "missed",
  "cancelled",
  "rescheduled",
] as const;
export type ConsultationStatus = (typeof consultationStatuses)[number];

export const consultationOutcomes = [
  "quote_ready",
  "needs_follow_up",
  "future_milestone",
  "not_a_fit",
  "no_response",
  "privacy_review",
  "safety_review",
  "reschedule_requested",
] as const;
export type ConsultationOutcome = (typeof consultationOutcomes)[number];

export type LeadNextActionRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  lead_id: string;
  action_text: string | null;
  due_at: string | null;
  exception_reason: string | null;
  source: string;
  created_at: string;
  created_by: string;
  updated_at: string;
  updated_by: string;
};

export type LeadTaskRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  lead_id: string;
  task_type: LeadTaskType;
  title: string;
  safe_summary: string | null;
  owner_member_id: string | null;
  status: LeadTaskStatus;
  priority: LeadTaskPriority;
  due_at: string | null;
  snoozed_until: string | null;
  source: string;
  idempotency_key: string | null;
  escalated_at: string | null;
  completed_at: string | null;
  completed_by: string | null;
  created_at: string;
  created_by: string;
  updated_at: string;
  updated_by: string;
};

export type LeadCommunicationRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  lead_id: string;
  consultation_id: string | null;
  channel: CommunicationChannel;
  direction: CommunicationDirection;
  occurred_at: string;
  owner_member_id: string | null;
  business_purpose: string;
  provider_identifier: string | null;
  status: CommunicationStatus;
  template_key: string | null;
  template_version: string | null;
  safe_summary: string;
  created_at: string;
  created_by: string;
};

export type ConsultationRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  lead_id: string;
  owner_member_id: string;
  status: ConsultationStatus;
  scheduled_start_at: string;
  scheduled_end_at: string;
  timezone: string;
  duration_minutes: number;
  buffer_before_minutes: number;
  buffer_after_minutes: number;
  schedule_version: number;
  rescheduled_from_id: string | null;
  cancellation_reason: string | null;
  outcome: ConsultationOutcome | null;
  business_summary: string | null;
  confirmed_emotional_goal: string | null;
  timing_fit: string | null;
  package_fit: string | null;
  objections: string | null;
  next_step: string | null;
  privacy_clarification: string | null;
  safety_review: string | null;
  client_shareable_recap: string | null;
  completed_at: string | null;
  cancelled_at: string | null;
  missed_at: string | null;
  created_at: string;
  created_by: string;
  updated_at: string;
  updated_by: string;
};

export type ConsultationScheduleHistoryRow = {
  id: string;
  organization_id: string;
  consultation_id: string;
  event_type: string;
  previous_start_at: string | null;
  previous_end_at: string | null;
  new_start_at: string | null;
  new_end_at: string | null;
  reason_recorded: boolean;
  notification_effect: string | null;
  actor_member_id: string;
  created_at: string;
};

export type ConsultationPrivateNoteRow = {
  id: string;
  consultation_id: string;
  note_text: string;
  created_at: string;
  created_by: string;
};

export type SerializableJson =
  string | number | boolean | null | SerializableJson[] | { [key: string]: SerializableJson };

export type LeadActivityRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  lead_id: string;
  event_type: string;
  entity_type: string;
  entity_id: string | null;
  summary: string;
  metadata: SerializableJson;
  actor_member_id: string | null;
  created_at: string;
};

export type NotificationOutboxRow = {
  id: string;
  organization_id: string;
  lead_id: string;
  consultation_id: string;
  kind: string;
  channel: CommunicationChannel;
  message_key: string;
  scheduled_for: string;
  status: "queued" | "processing" | "sent" | "failed" | "superseded" | "manual_action_required";
  attempt_count: number;
  max_attempts: number;
  last_attempt_at: string | null;
  last_error_code: string | null;
  provider_identifier: string | null;
  superseded_at: string | null;
  created_at: string;
  created_by: string;
  updated_at: string;
  updated_by: string;
};

export type AvailabilityWindowRow = {
  id: string;
  organization_id: string;
  owner_member_id: string;
  weekday: number;
  local_start: string;
  local_end: string;
  timezone: string;
  duration_minutes: number;
  buffer_before_minutes: number;
  buffer_after_minutes: number;
  capacity: number;
  minimum_notice_minutes: number;
  booking_horizon_days: number;
  is_bookable: boolean;
  created_at: string;
  created_by: string;
  updated_at: string;
  updated_by: string;
};

export type BlackoutRow = {
  id: string;
  organization_id: string;
  owner_member_id: string | null;
  starts_at: string;
  ends_at: string;
  safe_reason: string;
  created_at: string;
  created_by: string;
};

export type SlaSnapshotRow = {
  sla_key: string;
  status: "ok" | "due" | "breached" | "overridden" | "not_applicable";
  elapsed_business_minutes: number;
  threshold_business_minutes: number;
  detail: string;
  override_until: string | null;
};

export type LeadWorkspaceData = {
  lead: LeadRow;
  currentMemberId: string | null;
  nextAction: LeadNextActionRow | null;
  tasks: LeadTaskRow[];
  communications: LeadCommunicationRow[];
  consultations: ConsultationRow[];
  scheduleHistory: ConsultationScheduleHistoryRow[];
  activity: LeadActivityRow[];
  notifications: NotificationOutboxRow[];
  availability: AvailabilityWindowRow[];
  blackouts: BlackoutRow[];
  sla: SlaSnapshotRow[];
};

const uuid = z.string().uuid();
const nullableUuid = z
  .string()
  .uuid()
  .optional()
  .nullable()
  .transform((v) => v || null);
const optionalText = (max = 2000) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .nullable()
    .transform((v) => v || null);
const requiredText = (max = 2000) => z.string().trim().min(1).max(max);
const nullableTimestamp = z
  .string()
  .optional()
  .nullable()
  .transform((v) => v || null)
  .refine((v) => v === null || !Number.isNaN(Date.parse(v)), "Invalid date and time.");
const requiredTimestamp = z
  .string()
  .refine((v) => !Number.isNaN(Date.parse(v)), "Invalid date and time.");

function throwIfError(error: { message: string } | null) {
  if (error) throw new Error(error.message);
}

async function selectLead(context: { supabase: any }, leadId: string) {
  const { data, error } = await context.supabase
    .from("leads" as never)
    .select("*" as never)
    .eq("organization_id" as never, ORGANIZATION_ID as never)
    .eq("id" as never, leadId as never)
    .maybeSingle();

  throwIfError(error);
  if (!data) throw new Error("Lead not found or unavailable.");
  return data as unknown as LeadRow;
}

export const getLeadWorkspace = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => z.object({ leadId: uuid }).parse(input))
  .handler(async ({ data, context }): Promise<LeadWorkspaceData> => {
    const lead = await selectLead(context, data.leadId);

    const [
      currentMember,
      nextAction,
      tasks,
      communications,
      consultations,
      scheduleHistory,
      activity,
      notifications,
      availability,
      blackouts,
      sla,
    ] = await Promise.all([
      context.supabase.rpc(
        "current_organization_member" as never,
        {
          p_organization_id: ORGANIZATION_ID,
        } as never,
      ),
      context.supabase
        .from("lead_next_actions" as never)
        .select("*" as never)
        .eq("lead_id" as never, lead.id as never)
        .maybeSingle(),
      context.supabase
        .from("lead_tasks" as never)
        .select("*" as never)
        .eq("lead_id" as never, lead.id as never)
        .order("created_at" as never, { ascending: false }),
      context.supabase
        .from("lead_communications" as never)
        .select("*" as never)
        .eq("lead_id" as never, lead.id as never)
        .order("occurred_at" as never, { ascending: false }),
      context.supabase
        .from("consultations" as never)
        .select("*" as never)
        .eq("lead_id" as never, lead.id as never)
        .order("scheduled_start_at" as never, { ascending: false }),
      context.supabase
        .from("consultation_schedule_history" as never)
        .select("*" as never)
        .eq("organization_id" as never, ORGANIZATION_ID as never)
        .order("created_at" as never, { ascending: false }),
      context.supabase
        .from("lead_activity_events" as never)
        .select("*" as never)
        .eq("lead_id" as never, lead.id as never)
        .order("created_at" as never, { ascending: false }),
      context.supabase
        .from("notification_outbox" as never)
        .select("*" as never)
        .eq("lead_id" as never, lead.id as never)
        .order("scheduled_for" as never, { ascending: true }),
      context.supabase
        .from("consultation_availability_windows" as never)
        .select("*" as never)
        .eq("organization_id" as never, ORGANIZATION_ID as never)
        .order("weekday" as never, { ascending: true }),
      context.supabase
        .from("consultation_blackouts" as never)
        .select("*" as never)
        .eq("organization_id" as never, ORGANIZATION_ID as never)
        .gte("ends_at" as never, new Date().toISOString() as never)
        .order("starts_at" as never, { ascending: true }),
      context.supabase.rpc(
        "lead_sla_snapshot" as never,
        {
          p_lead_id: lead.id,
        } as never,
      ),
    ]);

    [
      currentMember.error,
      nextAction.error,
      tasks.error,
      communications.error,
      consultations.error,
      scheduleHistory.error,
      activity.error,
      notifications.error,
      availability.error,
      blackouts.error,
      sla.error,
    ].forEach(throwIfError);

    const consultationIds = new Set(
      ((consultations.data ?? []) as unknown as ConsultationRow[]).map((row) => row.id),
    );

    return {
      lead,
      currentMemberId: (currentMember.data as string | null) ?? null,
      nextAction: (nextAction.data as unknown as LeadNextActionRow | null) ?? null,
      tasks: (tasks.data ?? []) as unknown as LeadTaskRow[],
      communications: (communications.data ?? []) as unknown as LeadCommunicationRow[],
      consultations: (consultations.data ?? []) as unknown as ConsultationRow[],
      scheduleHistory: (
        (scheduleHistory.data ?? []) as unknown as ConsultationScheduleHistoryRow[]
      ).filter((row) => consultationIds.has(row.consultation_id)),
      activity: (activity.data ?? []) as unknown as LeadActivityRow[],
      notifications: (notifications.data ?? []) as unknown as NotificationOutboxRow[],
      availability: (availability.data ?? []) as unknown as AvailabilityWindowRow[],
      blackouts: (blackouts.data ?? []) as unknown as BlackoutRow[],
      sla: (sla.data ?? []) as unknown as SlaSnapshotRow[],
    };
  });

export const listAllLeadTasks = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<{ tasks: LeadTaskRow[]; leads: LeadRow[] }> => {
    const [tasks, leads] = await Promise.all([
      context.supabase
        .from("lead_tasks" as never)
        .select("*" as never)
        .eq("organization_id" as never, ORGANIZATION_ID as never)
        .order("due_at" as never, { ascending: true, nullsFirst: false }),
      context.supabase
        .from("leads" as never)
        .select("*" as never)
        .eq("organization_id" as never, ORGANIZATION_ID as never)
        .order("created_at" as never, { ascending: false }),
    ]);
    throwIfError(tasks.error);
    throwIfError(leads.error);
    return {
      tasks: (tasks.data ?? []) as unknown as LeadTaskRow[],
      leads: (leads.data ?? []) as unknown as LeadRow[],
    };
  });

export const listAllLeadCommunications = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(
    async ({ context }): Promise<{ communications: LeadCommunicationRow[]; leads: LeadRow[] }> => {
      const [communications, leads] = await Promise.all([
        context.supabase
          .from("lead_communications" as never)
          .select("*" as never)
          .eq("organization_id" as never, ORGANIZATION_ID as never)
          .order("occurred_at" as never, { ascending: false }),
        context.supabase
          .from("leads" as never)
          .select("*" as never)
          .eq("organization_id" as never, ORGANIZATION_ID as never)
          .order("created_at" as never, { ascending: false }),
      ]);
      throwIfError(communications.error);
      throwIfError(leads.error);
      return {
        communications: (communications.data ?? []) as unknown as LeadCommunicationRow[],
        leads: (leads.data ?? []) as unknown as LeadRow[],
      };
    },
  );

const nextActionSchema = z
  .object({
    leadId: uuid,
    actionText: optionalText(500),
    dueAt: nullableTimestamp,
    exceptionReason: optionalText(500),
    source: z.string().trim().min(1).max(80).default("manual"),
  })
  .refine((v) => Boolean(v.actionText || v.exceptionReason), {
    message: "A next action or approved exception is required.",
    path: ["actionText"],
  });

export const setLeadNextAction = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => nextActionSchema.parse(input))
  .handler(async ({ data, context }): Promise<LeadNextActionRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "set_lead_next_action" as never,
      {
        p_lead_id: data.leadId,
        p_action_text: data.actionText,
        p_due_at: data.dueAt,
        p_exception_reason: data.exceptionReason,
        p_source: data.source,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Next action was not returned.");
    return row as unknown as LeadNextActionRow;
  });

const createTaskSchema = z.object({
  leadId: uuid,
  taskType: z.enum(leadTaskTypes),
  title: requiredText(200),
  safeSummary: optionalText(1000),
  ownerMemberId: nullableUuid,
  priority: z.enum(leadTaskPriorities).default("normal"),
  dueAt: nullableTimestamp,
  source: z.string().trim().min(1).max(80).default("manual"),
  idempotencyKey: optionalText(200),
});

export const createLeadWorkspaceTask = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => createTaskSchema.parse(input))
  .handler(async ({ data, context }): Promise<LeadTaskRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "create_lead_task" as never,
      {
        p_lead_id: data.leadId,
        p_task_type: data.taskType,
        p_title: data.title,
        p_safe_summary: data.safeSummary,
        p_owner_member_id: data.ownerMemberId,
        p_priority: data.priority,
        p_due_at: data.dueAt,
        p_source: data.source,
        p_idempotency_key: data.idempotencyKey,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Task was not returned.");
    return row as unknown as LeadTaskRow;
  });

const updateTaskSchema = z.object({
  taskId: uuid,
  status: z.enum(leadTaskStatuses),
  priority: z.enum(leadTaskPriorities),
  dueAt: nullableTimestamp,
  snoozedUntil: nullableTimestamp,
  ownerMemberId: nullableUuid,
  escalate: z.boolean().default(false),
});

export const updateLeadWorkspaceTask = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => updateTaskSchema.parse(input))
  .handler(async ({ data, context }): Promise<LeadTaskRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "update_lead_task" as never,
      {
        p_task_id: data.taskId,
        p_status: data.status,
        p_priority: data.priority,
        p_due_at: data.dueAt,
        p_snoozed_until: data.snoozedUntil,
        p_owner_member_id: data.ownerMemberId,
        p_escalate: data.escalate,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Task update was not returned.");
    return row as unknown as LeadTaskRow;
  });

const communicationSchema = z.object({
  leadId: uuid,
  channel: z.enum(communicationChannels),
  direction: z.enum(communicationDirections),
  businessPurpose: requiredText(160),
  status: z.enum(communicationStatuses),
  safeSummary: requiredText(500),
  occurredAt: requiredTimestamp,
  providerIdentifier: optionalText(255),
  templateKey: optionalText(120),
  templateVersion: optionalText(80),
  consultationId: nullableUuid,
});

export const recordLeadCommunication = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => communicationSchema.parse(input))
  .handler(async ({ data, context }): Promise<LeadCommunicationRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "record_lead_communication" as never,
      {
        p_lead_id: data.leadId,
        p_channel: data.channel,
        p_direction: data.direction,
        p_business_purpose: data.businessPurpose,
        p_status: data.status,
        p_safe_summary: data.safeSummary,
        p_occurred_at: data.occurredAt,
        p_provider_identifier: data.providerIdentifier,
        p_template_key: data.templateKey,
        p_template_version: data.templateVersion,
        p_consultation_id: data.consultationId,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Communication record was not returned.");
    return row as unknown as LeadCommunicationRow;
  });

const scheduleSchema = z.object({
  leadId: uuid,
  startsAt: requiredTimestamp,
  durationMinutes: z.number().int().min(10).max(240).default(30),
  timezone: z.string().trim().min(1).max(80).default("Asia/Kolkata"),
  ownerMemberId: nullableUuid,
});

export const scheduleLeadConsultation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => scheduleSchema.parse(input))
  .handler(async ({ data, context }): Promise<ConsultationRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "schedule_consultation" as never,
      {
        p_lead_id: data.leadId,
        p_starts_at: data.startsAt,
        p_duration_minutes: data.durationMinutes,
        p_timezone: data.timezone,
        p_owner_member_id: data.ownerMemberId,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Consultation was not returned.");
    return row as unknown as ConsultationRow;
  });

export const rescheduleLeadConsultation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        consultationId: uuid,
        startsAt: requiredTimestamp,
        reason: requiredText(500),
        durationMinutes: z.number().int().min(10).max(240).optional().nullable(),
      })
      .parse(input),
  )
  .handler(async ({ data, context }): Promise<ConsultationRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "reschedule_consultation" as never,
      {
        p_consultation_id: data.consultationId,
        p_new_starts_at: data.startsAt,
        p_reason: data.reason,
        p_duration_minutes: data.durationMinutes ?? null,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Rescheduled consultation was not returned.");
    return row as unknown as ConsultationRow;
  });

export const cancelLeadConsultation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z.object({ consultationId: uuid, reason: requiredText(500) }).parse(input),
  )
  .handler(async ({ data, context }): Promise<ConsultationRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "cancel_consultation" as never,
      {
        p_consultation_id: data.consultationId,
        p_reason: data.reason,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Cancelled consultation was not returned.");
    return row as unknown as ConsultationRow;
  });

export const markLeadConsultationMissed = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => z.object({ consultationId: uuid }).parse(input))
  .handler(async ({ data, context }): Promise<ConsultationRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "mark_consultation_missed" as never,
      {
        p_consultation_id: data.consultationId,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Missed consultation was not returned.");
    return row as unknown as ConsultationRow;
  });

const completionSchema = z.object({
  consultationId: uuid,
  outcome: z.enum(consultationOutcomes),
  businessSummary: optionalText(2000),
  confirmedEmotionalGoal: optionalText(1200),
  timingFit: optionalText(800),
  packageFit: optionalText(800),
  objections: optionalText(1200),
  nextStep: requiredText(800),
  privacyClarification: optionalText(800),
  safetyReview: optionalText(800),
  clientShareableRecap: optionalText(1600),
  nextAction: requiredText(500),
  nextActionDueAt: requiredTimestamp,
  privateNote: optionalText(4000),
});

export const completeLeadConsultation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => completionSchema.parse(input))
  .handler(async ({ data, context }): Promise<ConsultationRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "complete_consultation" as never,
      {
        p_consultation_id: data.consultationId,
        p_outcome: data.outcome,
        p_business_summary: data.businessSummary,
        p_confirmed_emotional_goal: data.confirmedEmotionalGoal,
        p_timing_fit: data.timingFit,
        p_package_fit: data.packageFit,
        p_objections: data.objections,
        p_next_step: data.nextStep,
        p_privacy_clarification: data.privacyClarification,
        p_safety_review: data.safetyReview,
        p_client_shareable_recap: data.clientShareableRecap,
        p_next_action: data.nextAction,
        p_next_action_due_at: data.nextActionDueAt,
        p_private_note: data.privateNote,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Completed consultation was not returned.");
    return row as unknown as ConsultationRow;
  });

export const getConsultationPrivateNotes = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => z.object({ consultationId: uuid }).parse(input))
  .handler(async ({ data, context }): Promise<ConsultationPrivateNoteRow[]> => {
    const { data: rows, error } = await context.supabase.rpc(
      "get_consultation_private_notes" as never,
      {
        p_consultation_id: data.consultationId,
      } as never,
    );
    throwIfError(error);
    return (rows ?? []) as unknown as ConsultationPrivateNoteRow[];
  });

export const retryLeadNotification = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => z.object({ notificationId: uuid }).parse(input))
  .handler(async ({ data, context }): Promise<NotificationOutboxRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "retry_notification" as never,
      {
        p_notification_id: data.notificationId,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Notification recovery row was not returned.");
    return row as unknown as NotificationOutboxRow;
  });

export const saveConsultationAvailability = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        weekday: z.number().int().min(0).max(6),
        localStart: z.string().regex(/^\d{2}:\d{2}$/),
        localEnd: z.string().regex(/^\d{2}:\d{2}$/),
        timezone: z.string().trim().min(1).max(80).default("Asia/Kolkata"),
        durationMinutes: z.number().int().min(10).max(240).default(30),
        bufferBeforeMinutes: z.number().int().min(0).max(120).default(10),
        bufferAfterMinutes: z.number().int().min(0).max(120).default(10),
        capacity: z.number().int().min(1).max(20).default(1),
        minimumNoticeMinutes: z.number().int().min(0).max(43200).default(120),
        bookingHorizonDays: z.number().int().min(1).max(730).default(90),
        isBookable: z.boolean().default(true),
      })
      .parse(input),
  )
  .handler(async ({ data, context }): Promise<AvailabilityWindowRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "upsert_consultation_availability" as never,
      {
        p_weekday: data.weekday,
        p_local_start: data.localStart,
        p_local_end: data.localEnd,
        p_timezone: data.timezone,
        p_duration_minutes: data.durationMinutes,
        p_buffer_before_minutes: data.bufferBeforeMinutes,
        p_buffer_after_minutes: data.bufferAfterMinutes,
        p_capacity: data.capacity,
        p_minimum_notice_minutes: data.minimumNoticeMinutes,
        p_booking_horizon_days: data.bookingHorizonDays,
        p_is_bookable: data.isBookable,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Availability row was not returned.");
    return row as unknown as AvailabilityWindowRow;
  });

export const createConsultationBlackout = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        startsAt: requiredTimestamp,
        endsAt: requiredTimestamp,
        safeReason: requiredText(300),
      })
      .parse(input),
  )
  .handler(async ({ data, context }): Promise<BlackoutRow> => {
    const { data: row, error } = await context.supabase.rpc(
      "create_consultation_blackout" as never,
      {
        p_starts_at: data.startsAt,
        p_ends_at: data.endsAt,
        p_safe_reason: data.safeReason,
      } as never,
    );
    throwIfError(error);
    if (!row) throw new Error("Blackout row was not returned.");
    return row as unknown as BlackoutRow;
  });

export const createLeadSlaOverride = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) =>
    z
      .object({
        leadId: uuid,
        slaKey: requiredText(80),
        reason: requiredText(1000),
        expiresAt: nullableTimestamp,
        reviewAt: nullableTimestamp,
      })
      .refine((v) => Boolean(v.expiresAt || v.reviewAt), {
        message: "An expiry or review date is required.",
        path: ["expiresAt"],
      })
      .parse(input),
  )
  .handler(async ({ data, context }) => {
    const { data: row, error } = await context.supabase.rpc(
      "create_lead_sla_override" as never,
      {
        p_lead_id: data.leadId,
        p_sla_key: data.slaKey,
        p_reason: data.reason,
        p_expires_at: data.expiresAt,
        p_review_at: data.reviewAt,
      } as never,
    );
    throwIfError(error);
    return row;
  });
