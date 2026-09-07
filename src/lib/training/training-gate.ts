import type { TrainingContextRow, TrainingGateMode } from "@/lib/training.functions";

export const TRAINING_ROUTE = "/training" as const;

export type TrainingGateDecision =
  | {
      action: "allow";
      reason:
        | "training-route"
        | "context-loading"
        | "context-error"
        | "gate-off"
        | "no-required-training"
        | "training-complete";
    }
  | {
      action: "soft-reminder";
      reason: "training-incomplete";
      incompleteModules: TrainingContextRow[];
    }
  | {
      action: "redirect";
      reason: "training-required";
      to: typeof TRAINING_ROUTE;
      incompleteModules: TrainingContextRow[];
    };

export type ResolveTrainingGateInput = {
  pathname: string;
  loading: boolean;
  error: boolean;
  rows: readonly TrainingContextRow[];
};

const gateRank: Record<TrainingGateMode, number> = {
  off: 0,
  soft: 1,
  required: 2,
};

export function deriveTrainingGateMode(rows: readonly TrainingContextRow[]): TrainingGateMode {
  let mode: TrainingGateMode = "off";

  for (const row of rows) {
    if (gateRank[row.gateMode] > gateRank[mode]) {
      mode = row.gateMode;
    }
  }

  return mode;
}

export function getRequiredTrainingModules(
  rows: readonly TrainingContextRow[],
): TrainingContextRow[] {
  return rows.filter((row) => row.moduleRequired);
}

export function getIncompleteRequiredTrainingModules(
  rows: readonly TrainingContextRow[],
): TrainingContextRow[] {
  return getRequiredTrainingModules(rows).filter(
    (row) => row.trainingStatus !== "complete" || row.completedAt === null,
  );
}

export function resolveTrainingGate({
  pathname,
  loading,
  error,
  rows,
}: ResolveTrainingGateInput): TrainingGateDecision {
  if (pathname === TRAINING_ROUTE || pathname.startsWith(`${TRAINING_ROUTE}/`)) {
    return {
      action: "allow",
      reason: "training-route",
    };
  }

  // Fail open while training context is loading.
  // Existing authorization remains authoritative.
  if (loading) {
    return {
      action: "allow",
      reason: "context-loading",
    };
  }

  // Training must never become a second authentication/authorization
  // failure path. If training context cannot be resolved, preserve the
  // existing application access decision and surface the training error
  // separately.
  if (error) {
    return {
      action: "allow",
      reason: "context-error",
    };
  }

  const gateMode = deriveTrainingGateMode(rows);

  if (gateMode === "off") {
    return {
      action: "allow",
      reason: "gate-off",
    };
  }

  const requiredModules = getRequiredTrainingModules(rows);

  // Staged rollout safety:
  // a role with no published applicable required module must never
  // become locked out.
  if (requiredModules.length === 0) {
    return {
      action: "allow",
      reason: "no-required-training",
    };
  }

  const incompleteModules = getIncompleteRequiredTrainingModules(rows);

  if (incompleteModules.length === 0) {
    return {
      action: "allow",
      reason: "training-complete",
    };
  }

  if (gateMode === "soft") {
    return {
      action: "soft-reminder",
      reason: "training-incomplete",
      incompleteModules,
    };
  }

  return {
    action: "redirect",
    reason: "training-required",
    to: TRAINING_ROUTE,
    incompleteModules,
  };
}
