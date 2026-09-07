import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { Check, ChevronRight, CircleHelp, ShieldCheck } from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  completeTrainingModule,
  getFounderTrainingDirectory,
  recordTrainingStep,
  startTrainingModule,
  type TrainingDirectoryRow,
} from "@/lib/training.functions";
import { commonOrientationSteps } from "@/lib/training/common-tour";
import { GuidedInterfaceTour } from "@/components/training/GuidedInterfaceTour";
import { useTraining } from "@/lib/training/use-training";

export const Route = createFileRoute("/_authenticated/training")({
  head: () => ({
    meta: [
      {
        title: "Help & Training · Little Moments OS",
      },
      {
        name: "description",
        content: "Role-aware onboarding and training for Little Shots by Hema.",
      },
    ],
  }),
  component: TrainingPage,
});

function getErrorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "Training could not be updated. Please try again.";
}

function TrainingPage() {
  const { rows, gateMode, loading, error, errorMessage, refresh } = useTraining();

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [tourOpen, setTourOpen] = useState(false);

  const isFounder = useMemo(() => rows.some((row) => row.roleKeys.includes("founder")), [rows]);

  const founderDirectoryQuery = useQuery({
    queryKey: ["founder-training-directory"],
    queryFn: () => getFounderTrainingDirectory(),
    enabled: !loading && !error && isFounder,
    retry: 1,
    staleTime: 30_000,
    refetchOnWindowFocus: false,
  });

  const module = useMemo(
    () => rows.find((row) => row.moduleKey === "common-orientation") ?? null,
    [rows],
  );

  const currentStepIndex = useMemo(() => {
    if (!module) return 0;

    if (module.trainingStatus === "complete") {
      return commonOrientationSteps.length;
    }

    if (!module.currentStepKey) {
      return 0;
    }

    const completedIndex = commonOrientationSteps.findIndex(
      (step) => step.key === module.currentStepKey,
    );

    if (completedIndex < 0) {
      return 0;
    }

    return Math.min(completedIndex + 1, commonOrientationSteps.length);
  }, [module]);

  const started = module?.trainingStatus !== "not_started";

  const completed = module?.trainingStatus === "complete";

  const currentStep =
    currentStepIndex < commonOrientationSteps.length
      ? commonOrientationSteps[currentStepIndex]
      : null;

  const progressPercent = completed
    ? 100
    : Math.round((currentStepIndex / commonOrientationSteps.length) * 100);

  async function refreshTrainingViews() {
    await refresh();

    if (isFounder) {
      await founderDirectoryQuery.refetch();
    }
  }

  async function startOrientation() {
    if (!module || busy) return;

    setBusy(true);
    setActionError(null);

    try {
      await startTrainingModule({
        data: {
          moduleKey: module.moduleKey,
          version: module.moduleVersion,
        },
      });

      await refreshTrainingViews();
    } catch (nextError) {
      setActionError(getErrorMessage(nextError));
    } finally {
      setBusy(false);
    }
  }

  async function completeCurrentStep() {
    if (!module || !currentStep || busy) {
      return;
    }

    setBusy(true);
    setActionError(null);

    try {
      await recordTrainingStep({
        data: {
          moduleKey: module.moduleKey,
          version: module.moduleVersion,
          stepKey: currentStep.key,
          eventType: "step_completed",
          result: "pass",
          metadata: {
            source: "common-orientation-ui",
          },
        },
      });

      if (currentStepIndex === commonOrientationSteps.length - 1) {
        await completeTrainingModule({
          data: {
            moduleKey: module.moduleKey,
            version: module.moduleVersion,
          },
        });
      }

      await refreshTrainingViews();
    } catch (nextError) {
      setActionError(getErrorMessage(nextError));
    } finally {
      setBusy(false);
    }
  }

  async function completeGuidedNavigation(): Promise<boolean> {
    if (!module || !currentStep || currentStep.key !== "navigation" || busy) {
      return false;
    }

    setBusy(true);
    setActionError(null);

    try {
      await recordTrainingStep({
        data: {
          moduleKey: module.moduleKey,
          version: module.moduleVersion,
          stepKey: currentStep.key,
          eventType: "step_completed",
          result: "pass",
          metadata: {
            source: "guided-interface-tour",
          },
        },
      });

      await refreshTrainingViews();

      return true;
    } catch (nextError) {
      setActionError(getErrorMessage(nextError));
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function finishOrientation() {
    if (!module || busy) return;

    setBusy(true);
    setActionError(null);

    try {
      await completeTrainingModule({
        data: {
          moduleKey: module.moduleKey,
          version: module.moduleVersion,
        },
      });

      await refreshTrainingViews();
    } catch (nextError) {
      setActionError(getErrorMessage(nextError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <AppShell>
      <PageHeader
        eyebrow="Help & Training"
        title="Learn Little Moments OS safely"
        subtitle="Start with the common studio orientation. Role-specific guided practice will build on this foundation without using real client records as training material."
        quote="Care in the system protects trust in the experience."
      />

      <div className="mb-6 flex flex-wrap items-center gap-2">
        <StatusPill tone="gold">
          {module ? `Common Orientation v${module.moduleVersion}` : "Common Orientation"}
        </StatusPill>

        <StatusPill tone={completed ? "good" : started ? "warn" : "neutral"}>
          {completed ? "Training complete" : started ? "In progress" : "Not started"}
        </StatusPill>

        <StatusPill tone="neutral">Gate: {gateMode}</StatusPill>
      </div>

      {loading && (
        <Card className="p-6">
          <div className="font-serif text-lg text-primary">Preparing your training…</div>
          <p className="mt-2 text-sm text-muted-foreground">
            Reading your current studio role, branch scope, and training state.
          </p>
        </Card>
      )}

      {!loading && error && (
        <Card className="p-6">
          <div className="font-serif text-lg text-primary">Training is temporarily unavailable</div>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
            {errorMessage ??
              "Your normal studio access remains unchanged. Please try training again later."}
          </p>

          <Link
            to="/"
            className="mt-5 inline-flex rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground"
          >
            Back to the control room
          </Link>
        </Card>
      )}

      {!loading && !error && !module && (
        <Card className="p-6">
          <div className="font-serif text-lg text-primary">
            No training module is published for this account yet
          </div>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
            Your normal role access remains available. Training will appear here when an applicable
            module is published.
          </p>

          <Link
            to="/"
            className="mt-5 inline-flex rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground"
          >
            Back to the control room
          </Link>
        </Card>
      )}

      {!loading && !error && module && !started && (
        <div className="grid gap-5 lg:grid-cols-[1.25fr_0.75fr]">
          <Card className="p-6 sm:p-8">
            <div className="flex h-11 w-11 items-center justify-center rounded-full bg-accent">
              <ShieldCheck className="h-5 w-5 text-primary" />
            </div>

            <h2 className="mt-5 font-serif text-2xl text-primary">
              Before you work with real families
            </h2>

            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              This orientation teaches the shared operating rules every Little Shots by Hema team
              member must understand: role scope, evidence, privacy, escalation, and where to find
              help.
            </p>

            <button
              type="button"
              onClick={startOrientation}
              disabled={busy}
              className="mt-6 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground disabled:opacity-50"
            >
              {busy ? "Starting…" : "Start orientation"}
              {!busy && <ChevronRight className="h-4 w-4" />}
            </button>
          </Card>

          <RoleScopeCard module={module} />
        </div>
      )}

      {!loading && !error && module && started && !completed && currentStep && (
        <div className="grid gap-5 lg:grid-cols-[1.35fr_0.65fr]">
          <Card className="p-6 sm:p-8" data-tour="training-step">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
                Step {currentStepIndex + 1} of {commonOrientationSteps.length}
              </div>

              <div className="text-xs text-muted-foreground">{progressPercent}% complete</div>
            </div>

            <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-muted">
              <div
                className="h-full rounded-full bg-primary transition-[width]"
                style={{
                  width: `${progressPercent}%`,
                }}
              />
            </div>

            <div className="mt-8 text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
              {currentStep.eyebrow}
            </div>

            <h2 className="mt-2 max-w-2xl font-serif text-2xl text-primary">{currentStep.title}</h2>

            <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              {currentStep.body}
            </p>

            {currentStep.key === "role-scope" && (
              <div className="mt-6">
                <RoleScopeDetails module={module} />
              </div>
            )}

            {currentStep.key === "help" && (
              <div className="mt-6 flex items-start gap-3 rounded-xl border border-border bg-muted/40 p-4">
                <CircleHelp className="mt-0.5 h-5 w-5 shrink-0 text-primary" />
                <p className="text-sm leading-relaxed text-muted-foreground">
                  Use <span className="font-medium text-primary">Help & Training</span> from the
                  studio shell whenever you need to return here.
                </p>
              </div>
            )}

            {actionError && (
              <div
                role="alert"
                className="mt-5 rounded-xl border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive"
              >
                {actionError}
              </div>
            )}

            {currentStep.key === "navigation" ? (
              <button
                type="button"
                onClick={() => {
                  setActionError(null);
                  setTourOpen(true);
                }}
                disabled={busy}
                className="mt-7 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground disabled:opacity-50"
              >
                Start guided interface tour
                <ChevronRight className="h-4 w-4" />
              </button>
            ) : (
              <button
                type="button"
                onClick={completeCurrentStep}
                disabled={busy}
                className="mt-7 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground disabled:opacity-50"
              >
                {busy ? "Saving…" : "I understand — continue"}

                {!busy && <ChevronRight className="h-4 w-4" />}
              </button>
            )}
          </Card>

          <Card className="p-5">
            <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
              Orientation
            </div>

            <div className="mt-4 space-y-3">
              {commonOrientationSteps.map((step, index) => {
                const isDone = index < currentStepIndex;
                const isCurrent = index === currentStepIndex;

                return (
                  <div key={step.key} className="flex items-start gap-3">
                    <div
                      className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border text-[10px] ${
                        isDone
                          ? "border-primary bg-primary text-primary-foreground"
                          : isCurrent
                            ? "border-primary text-primary"
                            : "border-border text-muted-foreground"
                      }`}
                    >
                      {isDone ? <Check className="h-3 w-3" /> : index + 1}
                    </div>

                    <div
                      className={`text-sm ${
                        isCurrent ? "font-medium text-primary" : "text-muted-foreground"
                      }`}
                    >
                      {step.title}
                    </div>
                  </div>
                );
              })}
            </div>
          </Card>
        </div>
      )}

      {!loading && !error && module && started && !completed && !currentStep && (
        <Card className="p-6 sm:p-8">
          <h2 className="font-serif text-2xl text-primary">Your orientation steps are recorded</h2>

          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Finish the database-validated module completion check.
          </p>

          {actionError && (
            <div
              role="alert"
              className="mt-5 rounded-xl border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive"
            >
              {actionError}
            </div>
          )}

          <button
            type="button"
            onClick={finishOrientation}
            disabled={busy}
            className="mt-6 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground disabled:opacity-50"
          >
            {busy ? "Checking…" : "Finish orientation"}
          </button>
        </Card>
      )}

      {!loading && !error && module && completed && (
        <div className="grid gap-5 lg:grid-cols-[1.25fr_0.75fr]">
          <Card className="p-6 sm:p-8">
            <div className="flex h-11 w-11 items-center justify-center rounded-full bg-accent">
              <Check className="h-5 w-5 text-primary" />
            </div>

            <h2 className="mt-5 font-serif text-2xl text-primary">Common orientation complete</h2>

            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              Your completion is recorded in the training evidence trail. Role-specific training and
              final Work Ready sign-off are separate steps and are not granted by this orientation.
            </p>

            {module.workReadyAt === null && (
              <div className="mt-5 rounded-xl border border-border bg-muted/40 p-4 text-sm leading-relaxed text-muted-foreground">
                <span className="font-medium text-primary">Work Ready:</span> not yet signed off.
              </div>
            )}

            {gateMode !== "required" && (
              <Link
                to="/"
                className="mt-6 inline-flex rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground"
              >
                Back to the control room
              </Link>
            )}
          </Card>

          <RoleScopeCard module={module} />
        </div>
      )}
      {!loading && !error && isFounder && (
        <FounderTrainingDirectory
          rows={founderDirectoryQuery.data ?? []}
          loading={founderDirectoryQuery.isPending}
          errorMessage={
            founderDirectoryQuery.isError ? getErrorMessage(founderDirectoryQuery.error) : null
          }
        />
      )}

      {module && currentStep?.key === "navigation" && tourOpen && (
        <GuidedInterfaceTour
          moduleKey={module.moduleKey}
          version={module.moduleVersion}
          stepKey={currentStep.key}
          onComplete={completeGuidedNavigation}
          onClose={() => setTourOpen(false)}
        />
      )}
    </AppShell>
  );
}

function FounderTrainingDirectory({
  rows,
  loading,
  errorMessage,
}: {
  rows: TrainingDirectoryRow[];
  loading: boolean;
  errorMessage: string | null;
}) {
  return (
    <Card className="mt-6 p-6 sm:p-8">
      <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
        Founder oversight
      </div>

      <h2 className="mt-2 font-serif text-2xl text-primary">Team training directory</h2>

      <p className="mt-3 max-w-3xl text-sm leading-relaxed text-muted-foreground">
        Read-only training progress across currently eligible team members. Training completion does
        not grant role authority, branch authority, Founder sign-off, or Work Ready status.
      </p>

      {loading && (
        <div className="mt-5 rounded-xl border border-border bg-muted/40 p-4 text-sm text-muted-foreground">
          Loading team training progress…
        </div>
      )}

      {!loading && errorMessage && (
        <div
          role="alert"
          className="mt-5 rounded-xl border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive"
        >
          Founder training oversight is temporarily unavailable: {errorMessage}
        </div>
      )}

      {!loading && !errorMessage && rows.length === 0 && (
        <div className="mt-5 rounded-xl border border-border bg-muted/40 p-4 text-sm text-muted-foreground">
          No currently applicable team training rows are available.
        </div>
      )}

      {!loading && !errorMessage && rows.length > 0 && (
        <div className="mt-6 space-y-3">
          {rows.map((row) => {
            const roleText = row.roleKeys.length > 0 ? row.roleKeys.join(" · ") : "No live role";

            const branchText = row.organizationWide
              ? "Organization-wide"
              : row.branchNames.length > 0
                ? row.branchNames.join(" · ")
                : "No live branch scope";

            const statusTone =
              row.trainingStatus === "complete"
                ? "good"
                : row.trainingStatus === "in_progress"
                  ? "warn"
                  : "neutral";

            const statusText = row.trainingStatus.replace(/_/g, " ");

            return (
              <div
                key={`${row.memberId}:${row.moduleKey}:${row.moduleVersion}`}
                className="rounded-xl border border-border p-4"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-medium text-primary">
                      {row.displayName ?? row.email ?? "Team member"}
                    </div>

                    {row.email && (
                      <div className="mt-1 text-xs text-muted-foreground">{row.email}</div>
                    )}
                  </div>

                  <StatusPill tone={statusTone}>{statusText}</StatusPill>
                </div>

                <div className="mt-4 grid gap-3 text-xs text-muted-foreground sm:grid-cols-3">
                  <div>
                    <div className="uppercase tracking-[0.16em]">Role</div>
                    <div className="mt-1 text-sm text-primary">{roleText}</div>
                  </div>

                  <div>
                    <div className="uppercase tracking-[0.16em]">Scope</div>
                    <div className="mt-1 text-sm text-primary">{branchText}</div>
                  </div>

                  <div>
                    <div className="uppercase tracking-[0.16em]">Module</div>
                    <div className="mt-1 text-sm text-primary">
                      {row.moduleTitle} · v{row.moduleVersion}
                    </div>
                  </div>
                </div>

                {row.completedAt && (
                  <div className="mt-3 text-xs text-muted-foreground">
                    Completion evidence recorded.
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </Card>
  );
}

function RoleScopeDetails({
  module,
}: {
  module: NonNullable<ReturnType<typeof useTraining>["rows"][number]>;
}) {
  const roleText = module.roleLabels.length > 0 ? module.roleLabels.join(" · ") : "No active role";

  const branchText = module.organizationWide
    ? "Organization-wide"
    : module.branchNames.length > 0
      ? module.branchNames.join(" · ")
      : "No active branch scope";

  return (
    <div className="grid gap-3 sm:grid-cols-2" data-tour="training-role-scope">
      <div className="rounded-xl border border-border p-4">
        <div className="text-[10px] uppercase tracking-[0.2em] text-muted-foreground">
          Your role
        </div>
        <div className="mt-2 text-sm font-medium text-primary">{roleText}</div>
      </div>

      <div className="rounded-xl border border-border p-4">
        <div className="text-[10px] uppercase tracking-[0.2em] text-muted-foreground">
          Your studios
        </div>
        <div className="mt-2 text-sm font-medium text-primary">{branchText}</div>
      </div>
    </div>
  );
}

function RoleScopeCard({
  module,
}: {
  module: NonNullable<ReturnType<typeof useTraining>["rows"][number]>;
}) {
  return (
    <Card className="p-5">
      <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
        Current access
      </div>

      <div className="mt-4">
        <RoleScopeDetails module={module} />
      </div>

      <p className="mt-4 text-xs leading-relaxed text-muted-foreground">
        Training reads this scope from your live authorization. Training itself cannot add a role or
        widen a branch.
      </p>
    </Card>
  );
}
