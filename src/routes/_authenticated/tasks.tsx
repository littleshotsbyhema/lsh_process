import { useMemo, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, ListChecks, Loader2, Plus } from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  createLeadWorkspaceTask,
  leadTaskPriorities,
  leadTaskStatuses,
  leadTaskTypes,
  listAllLeadTasks,
  updateLeadWorkspaceTask,
  type LeadTaskPriority,
  type LeadTaskStatus,
  type LeadTaskType,
} from "@/lib/lead-workspace.functions";

export const Route = createFileRoute("/_authenticated/tasks")({
  head: () => ({
    meta: [
      { title: "Lead Tasks · LittleShots by Hema OS" },
      {
        name: "description",
        content: "Owned lead follow-up work, due dates, escalation and completion state.",
      },
    ],
  }),
  component: TasksPage,
});

const typeLabels: Record<LeadTaskType, string> = {
  first_response: "First response",
  follow_up: "Follow-up",
  consultation: "Consultation",
  quote: "Quote",
  privacy_review: "Privacy review",
  safety_review: "Safety review",
  stale_lead: "Stale lead",
  reminder_recovery: "Reminder recovery",
  assignment: "Assignment",
  document: "Document",
  internal_review: "Internal review",
  other: "Other",
};

function fmt(value: string | null) {
  if (!value) return "No due time";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

function toIso(value: string) {
  return value ? new Date(value).toISOString() : null;
}

function TasksPage() {
  const queryClient = useQueryClient();
  const [statusFilter, setStatusFilter] = useState<LeadTaskStatus | "active" | "all">("active");
  const [leadId, setLeadId] = useState("");
  const [title, setTitle] = useState("");
  const [taskType, setTaskType] = useState<LeadTaskType>("follow_up");
  const [priority, setPriority] = useState<LeadTaskPriority>("normal");
  const [dueAt, setDueAt] = useState("");
  const [error, setError] = useState<string | null>(null);

  const centerQuery = useQuery({
    queryKey: ["lead-task-center"],
    queryFn: () => listAllLeadTasks(),
  });

  const refresh = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ["lead-task-center"] }),
      queryClient.invalidateQueries({ queryKey: ["lead-workspace"] }),
    ]);
  };

  const createMutation = useMutation({
    mutationFn: () => createLeadWorkspaceTask({
      data: {
        leadId,
        taskType,
        title,
        safeSummary: null,
        ownerMemberId: null,
        priority,
        dueAt: toIso(dueAt),
        source: "task_center",
        idempotencyKey: null,
      },
    }),
    onSuccess: async () => {
      setTitle("");
      setDueAt("");
      await refresh();
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({
      taskId,
      status,
      currentPriority,
      currentDue,
      ownerMemberId,
      escalate,
    }: {
      taskId: string;
      status: LeadTaskStatus;
      currentPriority: LeadTaskPriority;
      currentDue: string | null;
      ownerMemberId: string | null;
      escalate: boolean;
    }) =>
      updateLeadWorkspaceTask({
        data: {
          taskId,
          status,
          priority: currentPriority,
          dueAt: currentDue,
          snoozedUntil:
            status === "snoozed"
              ? new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
              : null,
          ownerMemberId,
          escalate,
        },
      }),
    onSuccess: refresh,
  });

  const tasks = centerQuery.data?.tasks ?? [];
  const leads = centerQuery.data?.leads ?? [];
  const leadById = useMemo(() => new Map(leads.map((lead) => [lead.id, lead])), [leads]);

  const visible = useMemo(
    () =>
      tasks.filter((task) => {
        if (statusFilter === "all") return true;
        if (statusFilter === "active") return !["completed", "cancelled"].includes(task.status);
        return task.status === statusFilter;
      }),
    [tasks, statusFilter],
  );

  const overdue = tasks.filter(
    (task) =>
      task.due_at &&
      new Date(task.due_at) < new Date() &&
      !["completed", "cancelled"].includes(task.status),
  ).length;

  return (
    <AppShell>
      <PageHeader
        eyebrow="Operations, gently coordinated"
        title="Lead Task Center"
        subtitle="Every active enquiry should have owned work, a due time, or an explicit exception."
        quote="Care becomes reliable when the next action has an owner."
      />

      {(error || centerQuery.error) && (
        <Card className="mb-5 border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">
          {error ?? (centerQuery.error instanceof Error ? centerQuery.error.message : "Unable to load tasks.")}
        </Card>
      )}

      <section className="mb-5 grid gap-3 sm:grid-cols-3">
        <Card className="p-4">
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Active tasks</div>
          <div className="mt-1 font-serif text-2xl text-primary">{tasks.filter((t) => !["completed", "cancelled"].includes(t.status)).length}</div>
        </Card>
        <Card className="p-4">
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Overdue</div>
          <div className="mt-1 flex items-center gap-2 font-serif text-2xl text-primary">
            {overdue > 0 && <AlertTriangle className="h-4 w-4 text-destructive" />}{overdue}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Leads in view</div>
          <div className="mt-1 font-serif text-2xl text-primary">{leads.length}</div>
        </Card>
      </section>

      <Card className="mb-5 p-5">
        <div className="mb-3 flex items-center gap-2">
          <Plus className="h-4 w-4 text-gold" />
          <div className="font-serif text-base text-primary">Create lead task</div>
        </div>
        <div className="grid gap-2 md:grid-cols-6">
          <select value={leadId} onChange={(e) => setLeadId(e.target.value)} className="md:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary">
            <option value="">Choose lead</option>
            {leads.filter((lead) => !["converted", "archived"].includes(lead.status)).map((lead) => (
              <option key={lead.id} value={lead.id}>{lead.parent_name} · {lead.lead_reference}</option>
            ))}
          </select>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Task title" maxLength={200} className="md:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <select value={taskType} onChange={(e) => setTaskType(e.target.value as LeadTaskType)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {leadTaskTypes.map((type) => <option key={type} value={type}>{typeLabels[type]}</option>)}
          </select>
          <select value={priority} onChange={(e) => setPriority(e.target.value as LeadTaskPriority)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {leadTaskPriorities.map((value) => <option key={value}>{value}</option>)}
          </select>
          <input type="datetime-local" value={dueAt} onChange={(e) => setDueAt(e.target.value)} className="md:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <button
            type="button"
            disabled={!leadId || !title.trim() || createMutation.isPending}
            onClick={async () => {
              setError(null);
              try { await createMutation.mutateAsync(); }
              catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to create task."); }
            }}
            className="md:col-span-2 inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground disabled:opacity-50"
          >
            {createMutation.isPending && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
            Add task
          </button>
        </div>
      </Card>

      <div className="mb-3 flex flex-wrap items-center gap-2">
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as LeadTaskStatus | "active" | "all")} className="rounded-lg border border-border bg-card px-2 py-1.5 text-xs text-primary">
          <option value="active">Active</option>
          <option value="all">All</option>
          {leadTaskStatuses.map((status) => <option key={status} value={status}>{status.replaceAll("_", " ")}</option>)}
        </select>
        <span className="ml-auto text-xs text-muted-foreground">{visible.length} task{visible.length === 1 ? "" : "s"}</span>
      </div>

      <Card className="overflow-hidden p-0">
        {centerQuery.isLoading ? (
          <div className="p-10 text-center text-sm text-muted-foreground"><Loader2 className="mx-auto mb-2 h-5 w-5 animate-spin" />Loading owned work…</div>
        ) : visible.length === 0 ? (
          <div className="p-10 text-center">
            <ListChecks className="mx-auto h-5 w-5 text-gold" />
            <p className="mt-3 font-serif text-lg text-primary">No tasks here.</p>
            <p className="text-xs italic text-muted-foreground">A calm board is useful only when every active lead still has a clear next action.</p>
          </div>
        ) : (
          <ul className="divide-y divide-border">
            {visible.map((task) => {
              const lead = leadById.get(task.lead_id);
              const isOverdue = Boolean(task.due_at && new Date(task.due_at) < new Date() && !["completed", "cancelled"].includes(task.status));
              return (
                <li key={task.id} className="flex flex-wrap items-start gap-3 px-5 py-4">
                  <div className="min-w-0 flex-1">
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{typeLabels[task.task_type]} · {task.source}</div>
                    <div className="mt-0.5 font-medium text-primary">{task.title}</div>
                    <div className={`mt-1 text-xs ${isOverdue ? "text-destructive" : "text-muted-foreground"}`}>{fmt(task.due_at)}{task.escalated_at ? " · Escalated" : ""}</div>
                    {lead && (
                      <Link to="/leads/$leadId" params={{ leadId: lead.id }} className="mt-1 inline-block text-xs text-muted-foreground underline underline-offset-2">
                        {lead.parent_name} · {lead.lead_reference}
                      </Link>
                    )}
                  </div>
                  <StatusPill tone={task.priority === "urgent" ? "bad" : task.priority === "high" ? "warn" : "neutral"}>{task.priority}</StatusPill>
                  <select
                    value={task.status}
                    disabled={updateMutation.isPending}
                    onChange={async (e) => {
                      setError(null);
                      try {
                        await updateMutation.mutateAsync({
                          taskId: task.id,
                          status: e.target.value as LeadTaskStatus,
                          currentPriority: task.priority,
                          currentDue: task.due_at,
                          ownerMemberId: task.owner_member_id,
                          escalate: false,
                        });
                      } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to update task."); }
                    }}
                    className="rounded-lg border border-border bg-card px-2 py-1 text-xs text-primary disabled:opacity-50"
                  >
                    {leadTaskStatuses.map((status) => <option key={status} value={status}>{status.replaceAll("_", " ")}</option>)}
                  </select>
                  {!task.escalated_at && !["completed", "cancelled"].includes(task.status) && (
                    <button
                      type="button"
                      disabled={updateMutation.isPending}
                      onClick={async () => {
                        setError(null);
                        try {
                          await updateMutation.mutateAsync({
                            taskId: task.id,
                            status: task.status,
                            currentPriority: task.priority,
                            currentDue: task.due_at,
                            ownerMemberId: task.owner_member_id,
                            escalate: true,
                          });
                        } catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to escalate task."); }
                      }}
                      className="rounded-lg border border-border px-2 py-1 text-[11px] text-primary"
                    >Escalate</button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </Card>
    </AppShell>
  );
}
