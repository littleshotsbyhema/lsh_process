import { useMemo, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Eye, Loader2, RefreshCw, ShieldCheck } from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  getMemoryGuideSensitiveAnswers,
  listMemoryGuideReviewCenter,
  syncMemoryGuideToCrm,
  updateMemoryGuideReview,
  type MemoryGuideReviewRow,
} from "@/lib/memory-guide.functions";

export const Route = createFileRoute("/_authenticated/guide-reviews")({
  head: () => ({
    meta: [
      { title: "Memory Guide Reviews · Little Moments OS" },
      {
        name: "description",
        content: "Owned Memory Guide reviews, contact handoffs, restricted reads and CRM sync.",
      },
    ],
  }),
  component: MemoryGuideReviewCenter,
});

function fmt(value: string | null | undefined) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

function toneFor(row: MemoryGuideReviewRow): "neutral" | "good" | "warn" | "bad" | "gold" {
  if (row.visibility === "blocked" || row.crm_status === "dead_letter") return "bad";
  if (row.visibility === "restricted" || row.crm_status === "manual_action_required") return "warn";
  if (row.review_status === "resolved" || row.crm_status === "synced") return "good";
  if (new Date(row.due_at).getTime() < Date.now()) return "warn";
  return "neutral";
}

function MemoryGuideReviewCenter() {
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<"active" | "all" | "restricted">("active");
  const [error, setError] = useState<string | null>(null);
  const [sensitiveBySession, setSensitiveBySession] = useState<
    Record<string, Record<string, unknown>>
  >({});

  const centerQuery = useQuery({
    queryKey: ["memory-guide-review-center"],
    queryFn: () => listMemoryGuideReviewCenter(),
  });

  const refresh = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ["memory-guide-review-center"] }),
      queryClient.invalidateQueries({ queryKey: ["lead-task-center"] }),
      queryClient.invalidateQueries({ queryKey: ["lead-workspace"] }),
    ]);
  };

  const syncMutation = useMutation({
    mutationFn: (sessionId: string) => syncMemoryGuideToCrm({ data: { sessionId } }),
    onSuccess: refresh,
  });

  const reviewMutation = useMutation({
    mutationFn: ({
      reviewId,
      status,
    }: {
      reviewId: string;
      status: "in_progress" | "resolved" | "dismissed";
    }) => updateMemoryGuideReview({ data: { reviewId, status } }),
    onSuccess: refresh,
  });

  const sensitiveMutation = useMutation({
    mutationFn: (sessionId: string) => getMemoryGuideSensitiveAnswers({ data: { sessionId } }),
    onSuccess: (data, sessionId) =>
      setSensitiveBySession((previous) => ({ ...previous, [sessionId]: data })),
  });

  const rows = useMemo(() => {
    const source = centerQuery.data ?? [];
    if (filter === "restricted") return source.filter((row) => row.visibility === "restricted");
    if (filter === "active")
      return source.filter(
        (row) =>
          row.review_status === "open" ||
          row.review_status === "in_progress" ||
          (row.crm_status && row.crm_status !== "synced"),
      );
    return source;
  }, [centerQuery.data, filter]);

  const activeCount = (centerQuery.data ?? []).filter(
    (row) =>
      row.review_status === "open" ||
      row.review_status === "in_progress" ||
      (row.crm_status && row.crm_status !== "synced"),
  ).length;
  const restrictedCount = (centerQuery.data ?? []).filter(
    (row) => row.visibility === "restricted" && row.review_status !== "resolved",
  ).length;
  const overdueCount = (centerQuery.data ?? []).filter(
    (row) => row.review_status !== "resolved" && new Date(row.due_at).getTime() < Date.now(),
  ).length;
  const anyError =
    error ||
    (centerQuery.error instanceof Error ? centerQuery.error.message : null) ||
    (syncMutation.error instanceof Error ? syncMutation.error.message : null) ||
    (reviewMutation.error instanceof Error ? reviewMutation.error.message : null) ||
    (sensitiveMutation.error instanceof Error ? sensitiveMutation.error.message : null);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Memory Guide · human care"
        title="Memory Guide Review Center"
        subtitle="Low-confidence, privacy, safety, location and CRM handoffs stay owned. Restricted answers are never copied into general task summaries."
        quote="When certainty is low, care means bringing in a person."
      />

      {anyError && (
        <Card className="mb-5 border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">
          {anyError}
        </Card>
      )}

      <div className="mb-5 grid gap-3 sm:grid-cols-3">
        <Metric label="Active / handoff" value={activeCount} />
        <Metric label="Restricted" value={restrictedCount} />
        <Metric label="Overdue" value={overdueCount} />
      </div>

      <Card className="mb-5 p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-2">
            {(["active", "restricted", "all"] as const).map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => setFilter(value)}
                className={`rounded-lg border px-3 py-1.5 text-xs ${filter === value ? "border-primary bg-accent text-primary" : "border-border text-muted-foreground"}`}
              >
                {value.replaceAll("_", " ")}
              </button>
            ))}
          </div>
          <button
            type="button"
            onClick={() => void refresh()}
            disabled={centerQuery.isFetching}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-xs text-primary disabled:opacity-50"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${centerQuery.isFetching ? "animate-spin" : ""}`} />{" "}
            Refresh
          </button>
        </div>
      </Card>

      <div className="space-y-4">
        {centerQuery.isLoading && (
          <Card className="p-5 text-sm text-muted-foreground">
            <Loader2 className="mr-2 inline h-4 w-4 animate-spin" />
            Loading guide handoffs…
          </Card>
        )}
        {!centerQuery.isLoading && rows.length === 0 && (
          <Card className="p-6 text-sm italic text-muted-foreground">
            No Memory Guide items match this view.
          </Card>
        )}
        {rows.map((row) => {
          const sensitive = sensitiveBySession[row.session_id];
          const canSync = Boolean(
            row.contact?.permission && row.crm_status && row.crm_status !== "synced",
          );
          return (
            <Card key={`${row.review_id ?? "handoff"}-${row.session_id}`} className="p-5">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                    {row.session_reference} · {row.service_category ?? "service pending"}
                  </div>
                  <div className="mt-1 font-serif text-xl text-primary">{row.review_type}</div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    {row.trigger_code.replaceAll("_", " ")} · due {fmt(row.due_at)}
                  </div>
                </div>
                <div className="flex flex-wrap gap-2">
                  <StatusPill tone={toneFor(row)}>{row.visibility}</StatusPill>
                  <StatusPill
                    tone={
                      row.crm_status === "synced"
                        ? "good"
                        : row.crm_status === "dead_letter"
                          ? "bad"
                          : "neutral"
                    }
                  >
                    {row.crm_status ?? row.review_status}
                  </StatusPill>
                </div>
              </div>

              <div className="mt-4 grid gap-3 rounded-xl border border-border bg-background p-4 text-xs sm:grid-cols-3">
                <div>
                  <span className="text-muted-foreground">Recommendation</span>
                  <div className="mt-1 text-primary">
                    {row.primary_package?.public_name ?? "Human guidance / no package"}
                  </div>
                </div>
                <div>
                  <span className="text-muted-foreground">Confidence</span>
                  <div className="mt-1 text-primary">
                    {row.confidence?.replaceAll("_", " ") ?? "—"}
                  </div>
                </div>
                <div>
                  <span className="text-muted-foreground">Next action</span>
                  <div className="mt-1 text-primary">
                    {row.next_action?.replaceAll("_", " ") ?? "Not selected"}
                  </div>
                </div>
              </div>

              {row.contact && (
                <div className="mt-3 rounded-xl border border-border p-4 text-xs text-muted-foreground">
                  <span className="font-medium text-primary">{row.contact.name}</span> ·{" "}
                  {row.contact.phone}
                  {row.contact.email ? ` · ${row.contact.email}` : ""} · prefers{" "}
                  {row.contact.preferred_contact}
                </div>
              )}

              {sensitive && (
                <div className="mt-3 rounded-xl border border-amber-300 bg-background p-4">
                  <div className="flex items-center gap-2 text-xs font-medium text-primary">
                    <ShieldCheck className="h-4 w-4" /> Restricted details — audited access
                  </div>
                  <dl className="mt-3 grid gap-2 text-xs sm:grid-cols-2">
                    {Object.entries(sensitive).map(([key, value]) => (
                      <div key={key}>
                        <dt className="text-muted-foreground">{key.replaceAll("_", " ")}</dt>
                        <dd className="mt-0.5 whitespace-pre-wrap text-primary">
                          {Array.isArray(value) ? value.join(", ") : String(value)}
                        </dd>
                      </div>
                    ))}
                  </dl>
                </div>
              )}

              <div className="mt-4 flex flex-wrap gap-2">
                {canSync && (
                  <button
                    type="button"
                    disabled={syncMutation.isPending}
                    onClick={() => {
                      setError(null);
                      syncMutation.mutate(row.session_id);
                    }}
                    className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground disabled:opacity-50"
                  >
                    {syncMutation.isPending ? (
                      <Loader2 className="h-3.5 w-3.5 animate-spin" />
                    ) : null}{" "}
                    Sync to CRM
                  </button>
                )}
                {row.visibility === "restricted" && !sensitive && (
                  <button
                    type="button"
                    disabled={sensitiveMutation.isPending}
                    onClick={() => {
                      setError(null);
                      sensitiveMutation.mutate(row.session_id);
                    }}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-50"
                  >
                    <Eye className="h-3.5 w-3.5" /> Open restricted details
                  </button>
                )}
                {row.review_id && row.review_status === "open" && (
                  <button
                    type="button"
                    disabled={reviewMutation.isPending}
                    onClick={() =>
                      reviewMutation.mutate({ reviewId: row.review_id!, status: "in_progress" })
                    }
                    className="rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-50"
                  >
                    Start review
                  </button>
                )}
                {row.review_id && ["open", "in_progress"].includes(row.review_status) && (
                  <button
                    type="button"
                    disabled={reviewMutation.isPending}
                    onClick={() =>
                      reviewMutation.mutate({ reviewId: row.review_id!, status: "resolved" })
                    }
                    className="rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-50"
                  >
                    Resolve
                  </button>
                )}
                {row.lead_id && (
                  <Link
                    to="/leads/$leadId"
                    params={{ leadId: row.lead_id }}
                    className="rounded-lg border border-border px-3 py-2 text-xs text-primary"
                  >
                    Open lead workspace
                  </Link>
                )}
              </div>
              {row.crm_status === "manual_action_required" && (
                <p className="mt-3 text-xs text-muted-foreground">
                  CRM sync stopped safely for a duplicate/terminal identity case. Review before
                  linking or creating anything.
                </p>
              )}
              {row.crm_status === "retry" && (
                <p className="mt-3 text-xs text-muted-foreground">
                  The last CRM attempt rolled back and is safe to retry; no partial lead effect was
                  committed.
                </p>
              )}
            </Card>
          );
        })}
      </div>
    </AppShell>
  );
}

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <Card className="p-4">
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{label}</div>
      <div className="mt-1 font-serif text-2xl text-primary">{value}</div>
    </Card>
  );
}
