import { useContext } from "react";

import { TrainingContext, type TrainingContextValue } from "@/lib/training/training-context-base";

export function useTraining(): TrainingContextValue {
  const context = useContext(TrainingContext);

  if (!context) {
    throw new Error("useTraining must be used inside TrainingProvider.");
  }

  return context;
}
