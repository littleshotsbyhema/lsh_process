import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { ActionButton, ErrorNote, TextInput } from "@/components/DeliveryBoard";
import { availableModuleLinks } from "@/lib/access";
import {
  clearStageSla,
  listStageSlas,
  setStageSla,
  type StageSlaSummary,
} from "@/lib/delivery.functions";

export const Route = createFileRoute("/_authenticated/admin")({
  head: () => ({
    meta: [
      { title: "Admin · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Stage targets, permissions, team and catalogue — the settings behind how the studio runs.",
      },
      { property: "og:title", content: "Admin · LittleShots by Hema OS" },
    ],
  }),
  component: AdminPage,
});

const STAGE_SLA_QUERY_KEY = ["stage-slas"];

/** "48h — 2 days", so nobody has to do the division in their head. */
function describeHours(hours: number) {
  if (hours < 24) return `${hours}h — under a day`;

  const days = Math.floor(hours / 24);
  const rest = hours % 24;
  const dayText = `${days} day${days === 1 ? "" : "s"}`;

  if (rest === 0) return `${hours}h — ${dayText}`;
  return `${hours}h — ${dayText} and ${rest}h`;
}

function AdminPage() {
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);

  const query = useQuery({
    queryKey: STAGE_SLA_QUERY_KEY,
    queryFn: () => listStageSlas(),
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: STAGE_SLA_QUERY_KEY });

  const save = useMutation({
    mutationFn: (input: { stageKey: string; targetHours: number }) =>
      setStageSla({ data: input }),
    onMutate: () => setError(null),
    onError: (cause) =>
      setError(cause instanceof Error ? cause.message : "That target could not be saved."),
    onSuccess: invalidate,
  });

  const clear = useMutation({
    mutationFn: (input: { stageKey: string }) => clearStageSla({ data: input }),
    onMutate: () => setError(null),
    onError: (cause) =>
      setError(cause instanceof Error ? cause.message : "That target could not be removed."),
    onSuccess: invalidate,
  });

  const links = availableModuleLinks("/admin");
  const busyStage = save.isPending || clear.isPending;

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Admin"
        subtitle="Stage targets, people and the settings that decide how the studio runs."
        quote="Targets are there to tell us when something is waiting, not to hurry anyone."
      />

      <ErrorNote message={error} />

      <Card className="mb-8 mt-4 p-6">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Stage targets
        </div>

        <h2 className="mt-1 font-serif text-2xl text-primary">How long a stage should take</h2>

        <p className="mt-2 max-w-3xl text-sm leading-relaxed text-muted-foreground">
          A booking past its stage target turns red on the boards and sorts to the top, and that is
          all it ever does — it never blocks anyone from doing the work.
        </p>

        {query.isLoading && (
          <p className="mt-5 text-sm text-muted-foreground">Opening the studio records…</p>
        )}

        {query.isError && (
          <p className="mt-5 text-sm text-muted-foreground">
            The stage targets could not be read just now. Nothing is shown in their place.
          </p>
        )}

        {query.data && (
          <div className="mt-5 divide-y divide-border">
            {query.data.map((stage) => (
              <StageSlaRow
                key={stage.stageKey}
                stage={stage}
                busy={busyStage}
                onSave={(targetHours) => save.mutate({ stageKey: stage.stageKey, targetHours })}
                onClear={() => clear.mutate({ stageKey: stage.stageKey })}
              />
            ))}
          </div>
        )}
      </Card>

      <section>
        <div className="mb-4">
          <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
            Screens in this module
          </div>
          <h2 className="mt-1 font-serif text-2xl text-primary">Where the settings live</h2>
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          {links.map((link) => (
            <Link key={link.to} to={link.to}>
              <Card className="h-full p-5 transition-transform hover:-translate-y-0.5">
                <div className="font-serif text-lg text-primary">{link.label}</div>
                <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                  {link.description}
                </p>
              </Card>
            </Link>
          ))}
        </div>
      </section>
    </AppShell>
  );
}

function StageSlaRow({
  stage,
  busy,
  onSave,
  onClear,
}: {
  stage: StageSlaSummary;
  busy: boolean;
  onSave: (targetHours: number) => void;
  onClear: () => void;
}) {
  const [hours, setHours] = useState(stage.targetHours === null ? "" : String(stage.targetHours));

  const parsed = Number.parseInt(hours, 10);
  const valid = Number.isFinite(parsed) && parsed >= 1 && parsed <= 8760;
  const changed = valid && parsed !== stage.targetHours;

  return (
    <div className="grid gap-3 py-4 sm:grid-cols-[1fr_auto] sm:items-center">
      <div>
        <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
          Stage {String(stage.stageOrder).padStart(2, "0")}
        </div>
        <div className="mt-1 font-serif text-base text-primary">{stage.stageLabel}</div>
        <div className="mt-1 text-xs text-muted-foreground">
          {stage.targetHours === null
            ? "No target — nothing on this stage is ever marked late"
            : `Now ${describeHours(stage.targetHours)}`}
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <TextInput
          id={`sla-${stage.stageKey}`}
          className="w-28"
          value={hours}
          inputMode="numeric"
          aria-label={`Target in hours for ${stage.stageLabel}`}
          placeholder="Hours"
          onChange={(event) => setHours(event.target.value.replace(/\D/g, "").slice(0, 4))}
        />

        <span className="min-w-[9rem] text-xs text-muted-foreground">
          {valid ? describeHours(parsed) : "Between 1 and 8760 hours"}
        </span>

        <ActionButton busy={busy} disabled={!changed} onClick={() => onSave(parsed)}>
          Set target
        </ActionButton>

        {stage.targetHours !== null && (
          <ActionButton
            tone="quiet"
            busy={busy}
            onClick={() => {
              setHours("");
              onClear();
            }}
          >
            Remove target
          </ActionButton>
        )}
      </div>
    </div>
  );
}
