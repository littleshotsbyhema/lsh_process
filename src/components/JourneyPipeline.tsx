import { Check, Circle } from "lucide-react";

import type { BookingJourneyStageRow } from "@/lib/booking.functions";

export function JourneyPipeline({
  stages,
  currentStageId,
  version,
}: {
  stages: BookingJourneyStageRow[];
  currentStageId: string | null;
  version?: number | null;
}) {
  const orderedStages = [...stages].sort((a, b) => a.stage_order - b.stage_order);

  const currentStage = orderedStages.find((stage) => stage.id === currentStageId) ?? null;

  const currentOrder = currentStage?.stage_order ?? 0;

  return (
    <div className="rounded-xl border border-border bg-[var(--gradient-warm)]/60 px-4 py-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Client Journey
          </div>

          <div className="mt-1 font-serif text-base text-primary">
            {currentStage?.label ?? "Journey state unavailable"}

            {currentStage ? (
              <span className="ml-2 font-sans text-xs text-muted-foreground">
                {currentStage.stage_order}/{orderedStages.length}
              </span>
            ) : null}
          </div>

          {version ? (
            <div className="mt-1 text-[11px] text-muted-foreground">Journey version {version}</div>
          ) : null}
        </div>

        <p className="max-w-lg text-[11px] leading-5 text-muted-foreground">
          This journey is read-only. Stage changes require an authoritative backend transition path
          and are not simulated in the browser.
        </p>
      </div>

      <ol className="mt-4 flex flex-wrap gap-1.5">
        {orderedStages.map((stage) => {
          const done = stage.stage_order < currentOrder;
          const current = stage.id === currentStageId;

          return (
            <li
              key={stage.id}
              className={`flex items-center gap-1.5 rounded-full border px-2 py-1 text-[10.5px] ${
                current
                  ? "border-gold bg-[var(--gradient-gold)] text-primary"
                  : done
                    ? "border-border bg-card text-primary/80"
                    : "border-border/60 bg-transparent text-muted-foreground"
              }`}
              title={`${stage.stage_order}. ${stage.label}`}
            >
              {done ? (
                <Check className="h-2.5 w-2.5" />
              ) : (
                <Circle className={`h-2 w-2 ${current ? "fill-gold text-gold" : ""}`} />
              )}

              <span>
                {stage.stage_order}. {stage.label}
              </span>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
