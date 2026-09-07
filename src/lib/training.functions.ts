import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import type { Database, Json } from "@/integrations/supabase/types";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { ORGANIZATION_ID } from "@/lib/session";

export type TrainingGateMode = Database["public"]["Enums"]["training_gate_mode"];

export type TrainingProfileStatus = Database["public"]["Enums"]["training_profile_status"];

export type TrainingStepEventType = Database["public"]["Enums"]["training_step_event_type"];

export type TrainingStepEventResult = Database["public"]["Enums"]["training_step_event_result"];

export type TrainingContextRow = {
  memberId: string;
  displayName: string | null;

  roleKeys: string[];
  roleLabels: string[];

  branchIds: string[];
  branchCodes: string[];
  branchNames: string[];

  organizationWide: boolean;

  gateMode: TrainingGateMode;

  moduleId: string;
  moduleKey: string;
  moduleRoleKey: string | null;
  moduleVersion: number;
  moduleTitle: string;
  moduleRequired: boolean;

  trainingStatus: TrainingProfileStatus;
  currentStepKey: string | null;

  startedAt: string | null;
  completedAt: string | null;
  workReadyAt: string | null;
};

export type TrainingDirectoryRow = {
  memberId: string;
  displayName: string | null;
  email: string | null;

  roleKeys: string[];
  branchNames: string[];
  organizationWide: boolean;

  moduleKey: string;
  moduleRoleKey: string | null;
  moduleVersion: number;
  moduleTitle: string;

  trainingStatus: TrainingProfileStatus;
  currentStepKey: string | null;
  completedAt: string | null;
  workReadyAt: string | null;
};

const moduleKeySchema = z
  .string()
  .trim()
  .regex(/^[a-z][a-z0-9_-]*$/, "Invalid training module key.");

const moduleIdentitySchema = z.object({
  moduleKey: moduleKeySchema,
  version: z.number().int().positive().max(10000),
});

const genericTrainingEventTypeSchema = z.enum([
  "step_viewed",
  "step_completed",
  "action_attempted",
  "action_failed",
  "hint_opened",
  "training_step_broken",
]);

const trainingEventResultSchema = z.enum(["pass", "fail", "info"]);

const trainingStepKeySchema = z
  .string()
  .trim()
  .min(1, "Training step key is required.")
  .max(120, "Training step key is too long.");

const trainingMetadataValueSchema = z.union([
  z.string().max(1000),
  z.number().finite(),
  z.boolean(),
  z.null(),
]);

const trainingMetadataSchema = z
  .record(z.string().trim().min(1).max(80), trainingMetadataValueSchema)
  .refine((value) => Object.keys(value).length <= 24, "Training metadata contains too many fields.")
  .refine(
    (value) => new TextEncoder().encode(JSON.stringify(value)).length <= 4096,
    "Training metadata exceeds the allowed size.",
  );

const recordTrainingStepSchema = moduleIdentitySchema.extend({
  stepKey: trainingStepKeySchema,
  eventType: genericTrainingEventTypeSchema,
  result: trainingEventResultSchema,
  metadata: trainingMetadataSchema.default({}),
});

function mapTrainingContextRow(
  row: Database["public"]["Functions"]["my_training_context"]["Returns"][number],
): TrainingContextRow {
  return {
    memberId: row.organization_member_id,
    displayName: row.display_name ?? null,

    roleKeys: row.assigned_role_keys ?? [],
    roleLabels: row.assigned_role_labels ?? [],

    branchIds: row.assigned_branch_ids ?? [],
    branchCodes: row.assigned_branch_codes ?? [],
    branchNames: row.assigned_branch_names ?? [],

    organizationWide: row.organization_wide,

    gateMode: row.gate_mode,

    moduleId: row.training_module_id,
    moduleKey: row.module_key,
    moduleRoleKey: row.module_role_key ?? null,
    moduleVersion: row.module_version,
    moduleTitle: row.module_title,
    moduleRequired: row.module_required,

    trainingStatus: row.training_status,
    currentStepKey: row.current_step_key ?? null,

    startedAt: row.started_at ?? null,
    completedAt: row.completed_at ?? null,
    workReadyAt: row.work_ready_at ?? null,
  };
}

function mapTrainingDirectoryRow(
  row: Database["public"]["Functions"]["training_directory"]["Returns"][number],
): TrainingDirectoryRow {
  return {
    memberId: row.organization_member_id,
    displayName: row.display_name ?? null,
    email: row.email ?? null,

    roleKeys: row.assigned_role_keys ?? [],
    branchNames: row.assigned_branch_names ?? [],
    organizationWide: row.organization_wide,

    moduleKey: row.module_key,
    moduleRoleKey: row.module_role_key ?? null,
    moduleVersion: row.module_version,
    moduleTitle: row.module_title,

    trainingStatus: row.training_status,
    currentStepKey: row.current_step_key ?? null,
    completedAt: row.completed_at ?? null,
    workReadyAt: row.work_ready_at ?? null,
  };
}

export const getMyTrainingContext = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<TrainingContextRow[]> => {
    const { data, error } = await context.supabase.rpc("my_training_context", {
      p_organization_id: ORGANIZATION_ID,
    });

    if (error) {
      throw new Error(error.message);
    }

    return (data ?? []).map(mapTrainingContextRow);
  });

export const startTrainingModule = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(moduleIdentitySchema)
  .handler(async ({ data, context }): Promise<string> => {
    const args = {
      p_organization_id: ORGANIZATION_ID,
      p_module_key: data.moduleKey,
      p_version: data.version,
    } satisfies Database["public"]["Functions"]["start_my_training_module"]["Args"];

    const { data: profileId, error } = await context.supabase.rpc("start_my_training_module", args);

    if (error) {
      throw new Error(error.message);
    }

    if (!profileId) {
      throw new Error("Training profile was not created or resumed.");
    }

    return profileId;
  });

export const recordTrainingStep = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(recordTrainingStepSchema)
  .handler(async ({ data, context }): Promise<string> => {
    const metadata: Json = data.metadata;

    const args = {
      p_organization_id: ORGANIZATION_ID,
      p_module_key: data.moduleKey,
      p_version: data.version,
      p_step_key: data.stepKey,
      p_event_type: data.eventType,
      p_result: data.result,
      p_metadata: metadata,
    } satisfies Database["public"]["Functions"]["record_my_training_step"]["Args"];

    const { data: eventId, error } = await context.supabase.rpc("record_my_training_step", args);

    if (error) {
      throw new Error(error.message);
    }

    if (!eventId) {
      throw new Error("Training progress was not recorded.");
    }

    return eventId;
  });

export const completeTrainingModule = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(moduleIdentitySchema)
  .handler(async ({ data, context }): Promise<string> => {
    const args = {
      p_organization_id: ORGANIZATION_ID,
      p_module_key: data.moduleKey,
      p_version: data.version,
    } satisfies Database["public"]["Functions"]["complete_my_training_module"]["Args"];

    const { data: profileId, error } = await context.supabase.rpc(
      "complete_my_training_module",
      args,
    );

    if (error) {
      throw new Error(error.message);
    }

    if (!profileId) {
      throw new Error("Training module was not completed.");
    }

    return profileId;
  });

export const getFounderTrainingDirectory = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<TrainingDirectoryRow[]> => {
    const { data, error } = await context.supabase.rpc("training_directory", {
      p_organization_id: ORGANIZATION_ID,
    });

    if (error) {
      throw new Error(error.message);
    }

    return (data ?? []).map(mapTrainingDirectoryRow);
  });
