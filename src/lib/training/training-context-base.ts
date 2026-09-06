import { createContext } from "react";

import type { TrainingContextRow, TrainingGateMode } from "@/lib/training.functions";
import type { TrainingGateDecision } from "@/lib/training/training-gate";

export type TrainingContextValue = {
  rows: TrainingContextRow[];

  gateMode: TrainingGateMode;

  requiredModules: TrainingContextRow[];
  incompleteRequiredModules: TrainingContextRow[];

  hasApplicableTraining: boolean;

  loading: boolean;
  error: boolean;
  errorMessage: string | null;

  resolveGate: (pathname: string) => TrainingGateDecision;

  refresh: () => Promise<void>;
};

export const TrainingContext = createContext<TrainingContextValue | null>(null);
