import { useMemo, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";

import { ORGANIZATION_ID } from "@/lib/session";
import { getMyTrainingContext } from "@/lib/training.functions";
import { TrainingContext, type TrainingContextValue } from "@/lib/training/training-context-base";
import {
  deriveTrainingGateMode,
  getIncompleteRequiredTrainingModules,
  getRequiredTrainingModules,
  resolveTrainingGate,
} from "@/lib/training/training-gate";

export type TrainingProviderProps = {
  children: ReactNode;

  /**
   * Authenticated Supabase user ID.
   *
   * This value is used only to isolate the React Query cache key.
   * Database authorization independently resolves auth.uid().
   */
  userId: string | null;

  /**
   * Load training only after normal session and organization-role
   * resolution has succeeded.
   */
  enabled: boolean;
};

export function TrainingProvider({ children, userId, enabled }: TrainingProviderProps) {
  const queryEnabled = enabled && Boolean(userId);

  const trainingQuery = useQuery({
    queryKey: ["training-context", ORGANIZATION_ID, userId],
    queryFn: () => getMyTrainingContext(),
    enabled: queryEnabled,
    retry: 1,
    staleTime: 30_000,
    refetchOnWindowFocus: false,
  });

  const rows = useMemo(() => trainingQuery.data ?? [], [trainingQuery.data]);

  const gateMode = useMemo(() => deriveTrainingGateMode(rows), [rows]);

  const requiredModules = useMemo(() => getRequiredTrainingModules(rows), [rows]);

  const incompleteRequiredModules = useMemo(
    () => getIncompleteRequiredTrainingModules(rows),
    [rows],
  );

  const loading = queryEnabled && trainingQuery.isPending;

  const error = queryEnabled && trainingQuery.isError;

  const errorMessage =
    trainingQuery.error instanceof Error
      ? trainingQuery.error.message
      : trainingQuery.error
        ? "Training context could not be loaded."
        : null;

  const value = useMemo<TrainingContextValue>(
    () => ({
      rows,

      gateMode,

      requiredModules,
      incompleteRequiredModules,

      hasApplicableTraining: rows.length > 0,

      loading,
      error,
      errorMessage,

      resolveGate: (pathname: string) =>
        resolveTrainingGate({
          pathname,
          loading,
          error,
          rows,
        }),

      refresh: async () => {
        await trainingQuery.refetch();
      },
    }),
    [
      rows,
      gateMode,
      requiredModules,
      incompleteRequiredModules,
      loading,
      error,
      errorMessage,
      trainingQuery,
    ],
  );

  return <TrainingContext.Provider value={value}>{children}</TrainingContext.Provider>;
}
