import { useEffect, useMemo, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  AlertTriangle,
  ArrowLeft,
  CalendarClock,
  CheckCircle2,
  Clock3,
  ExternalLink,
  Loader2,
  LockKeyhole,
  MessageSquareHeart,
  Phone,
  Plus,
  RotateCcw,
  ShieldCheck,
} from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  consultationOutcomes,
  createConsultationBlackout,
  createLeadSlaOverride,
  createLeadWorkspaceTask,
  getConsultationPrivateNotes,
  getLeadWorkspace,
  leadTaskPriorities,
  leadTaskStatuses,
  leadTaskTypes,
  markLeadConsultationMissed,
  recordLeadCommunication,
  rescheduleLeadConsultation,
  retryLeadNotification,
  saveConsultationAvailability,
  scheduleLeadConsultation,
  setLeadNextAction,
  updateLeadWorkspaceTask,
  cancelLeadConsultation,
  completeLeadConsultation,
  communicationChannels,
  communicationDirections,
  communicationStatuses,
  type ConsultationOutcome,
  type ConsultationPrivateNoteRow,
  type ConsultationRow,
  type LeadTaskPriority,
  type LeadTaskStatus,
  type LeadTaskType,
  type LeadWorkspaceData,
} from "@/lib/lead-workspace.functions";
import {
  leadStatuses,
  updateLead,
  type LeadRow,
  type LeadStatus,
} from "@/lib/leads.functions";

export const Route = createFileRoute("/_authenticated/leads_/$leadId")({
  head: () => ({
    meta: [
      { title: "Lead Workspace · Little Moments OS" },
      {
        name: "description",
        content:
          "One operational workspace for the enquiry, next action, tasks, communications, consultation and SLA state.",
      },
    ],
  }),
  component: LeadWorkspacePage,
});

const statusLabels: Record<LeadStatus, string> = {
  new_inquiry: "New Inquiry",
  contacted: "Contacted",
  qualified: "Qualified",
  consultation_scheduled: "Consultation Scheduled",
  quote_ready: "Quote Ready",
  quote_sent: "Quote Sent",
  follow_up_needed: "Follow-Up Needed",
  converted: "Converted",
  lost: "Lost",
  archived: "Archived",
};

const taskTypeLabels: Record<LeadTaskType, string> = {
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

const outcomeLabels: Record<ConsultationOutcome, string> = {
  quote_ready: "Quote Ready",
  needs_follow_up: "Needs Follow-Up",
  future_milestone: "Future Milestone",
  not_a_fit: "Not a Fit",
  no_response: "No Response",
  privacy_review: "Privacy Review",
  safety_review: "Safety Review",
  reschedule_requested: "Reschedule Requested",
};

const weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function fmt(value: string | null | undefined) {
  if (!value) return "—";
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

function toInputDateTime(value: string | null | undefined) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

function toIso(value: string) {
  return value ? new Date(value).toISOString() : null;
}

function leadUpdatePayload(lead: LeadRow, status: LeadStatus, lostReason: string | null) {
  return {
    leadId: lead.id,
    parentName: lead.parent_name,
    source: lead.source,
    phone: lead.phone,
    email: lead.email,
    city: lead.city,
    sessionType: lead.session_type,
    babyAgeOrPregnancy: lead.baby_age_or_pregnancy,
    preferredDate: lead.preferred_date,
    locationPreference: lead.location_preference,
    packageInterest: lead.package_interest,
    budgetComfort: lead.budget_comfort,
    memoryGoal: lead.memory_goal,
    privacyPreference: lead.privacy_preference,
    followUpAt: lead.follow_up_at,
    status,
    lostReason,
    branchId: lead.branch_id,
    assignedOwnerMemberId: lead.assigned_owner_member_id,
  };
}

function LeadWorkspacePage() {
  const { leadId } = Route.useParams();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);

  const workspaceQuery = useQuery({
    queryKey: ["lead-workspace", leadId],
    queryFn: () => getLeadWorkspace({ data: { leadId } }),
  });

  const refresh = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ["lead-workspace", leadId] }),
      queryClient.invalidateQueries({ queryKey: ["leads"] }),
      queryClient.invalidateQueries({ queryKey: ["lead-task-center"] }),
      queryClient.invalidateQueries({ queryKey: ["lead-communication-center"] }),
    ]);
  };

  const statusMutation = useMutation({
    mutationFn: async ({ lead, status }: { lead: LeadRow; status: LeadStatus }) => {
      let lostReason: string | null = null;
      if (status === "lost") {
        const reason = window.prompt("Why was this inquiry lost?", lead.lost_reason ?? "");
        if (reason === null) throw new Error("Status change cancelled.");
        if (!reason.trim()) throw new Error("A reason is required when an inquiry is marked lost.");
        lostReason = reason.trim();
      }
      if (status === "converted") throw new Error("Use Lead → Family conversion from the Leads page.");
      return updateLead({ data: leadUpdatePayload(lead, status, lostReason) });
    },
    onSuccess: refresh,
  });

  const data = workspaceQuery.data;
  const lead = data?.lead;

  if (workspaceQuery.isLoading) {
    return (
      <AppShell>
        <Card className="p-12 text-center">
          <Loader2 className="mx-auto h-5 w-5 animate-spin text-muted-foreground" />
          <p className="mt-3 font-serif text-xl text-primary">Opening the family’s enquiry story…</p>
        </Card>
      </AppShell>
    );
  }

  if (workspaceQuery.isError || !data || !lead) {
    return (
      <AppShell>
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">We couldn’t open this lead workspace.</p>
          <p className="mt-2 text-sm text-muted-foreground">
            {workspaceQuery.error instanceof Error ? workspaceQuery.error.message : "Lead unavailable."}
          </p>
          <Link to="/leads" className="mt-5 inline-flex rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground">
            Back to Leads
          </Link>
        </Card>
      </AppShell>
    );
  }

  const activeConsultations = data.consultations.filter((c) =>
    ["pending_confirmation", "tentative", "scheduled"].includes(c.status),
  );
  const terminal = lead.status === "converted" || lead.status === "archived";

  return (
    <AppShell>
      <div className="mb-5">
        <Link to="/leads" className="inline-flex items-center gap-1.5 text-xs text-muted-foreground hover:text-primary">
          <ArrowLeft className="h-3.5 w-3.5" /> Back to Leads & Inquiries
        </Link>
      </div>

      <PageHeader
        eyebrow={`${lead.lead_reference} · ${lead.source}`}
        title={lead.parent_name}
        subtitle="One calm operating view for the enquiry, the promise we made, and the next responsible action."
        quote="Understand the family before moving the workflow."
      />

      {error && (
        <div className="mb-5 rounded-xl border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          {error}
        </div>
      )}

      <Card className="mb-6 p-5">
        <div className="flex flex-wrap items-start gap-4">
          <div className="min-w-0 flex-1">
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Identity & contact</div>
            <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-sm text-primary">
              <span>{lead.city || "City not recorded"}</span>
              <span>{lead.phone || "Phone not recorded"}</span>
              <span>{lead.email || "Email not recorded"}</span>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              {lead.phone && (
                <a href={`tel:${lead.phone}`} className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-xs text-primary">
                  <Phone className="h-3 w-3" /> Call
                </a>
              )}
              {lead.phone && (
                <a
                  href={`https://wa.me/${lead.phone.replace(/[^0-9]/g, "")}`}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1.5 rounded-lg border border-gold bg-accent px-3 py-1.5 text-xs text-primary"
                >
                  <MessageSquareHeart className="h-3 w-3" /> WhatsApp <ExternalLink className="h-3 w-3" />
                </a>
              )}
              {lead.email && (
                <a href={`mailto:${lead.email}`} className="rounded-lg border border-border px-3 py-1.5 text-xs text-primary">
                  Email
                </a>
              )}
            </div>
          </div>

          <div className="min-w-[220px]">
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Lead status</div>
            <select
              value={lead.status}
              disabled={terminal || statusMutation.isPending}
              onChange={async (event) => {
                setError(null);
                try {
                  await statusMutation.mutateAsync({ lead, status: event.target.value as LeadStatus });
                } catch (e) {
                  const message = e instanceof Error ? e.message : "Unable to update lead status.";
                  if (message !== "Status change cancelled.") setError(message);
                }
              }}
              className="mt-2 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary disabled:opacity-60"
            >
              {leadStatuses.filter((s) => s !== "converted").map((status) => (
                <option key={status} value={status}>{statusLabels[status]}</option>
              ))}
              {lead.status === "converted" && <option value="converted">Converted</option>}
            </select>
            <div className="mt-2 text-xs text-muted-foreground">
              Owner: {lead.assigned_owner_member_id ? "Assigned" : "Unassigned"}
            </div>
          </div>
        </div>
      </Card>

      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-6">
          <NextActionCard
            leadId={lead.id}
            nextAction={data.nextAction}
            terminal={terminal}
            onSaved={refresh}
            onError={setError}
          />

          <Card className="p-5">
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Family context" value={lead.baby_age_or_pregnancy || "Not captured yet"} />
              <Field label="Session type" value={lead.session_type || "Not captured yet"} />
              <Field label="Preferred timing" value={lead.preferred_date ? fmt(lead.preferred_date) : "Not captured yet"} />
              <Field label="Location preference" value={lead.location_preference || "Not captured yet"} />
              <Field label="Package signal" value={lead.package_interest || "Not captured yet"} />
              <Field label="Budget comfort" value={lead.budget_comfort || "Not captured yet"} />
              <Field label="Privacy state" value={lead.privacy_preference?.replaceAll("_", " ") || "No preference recorded"} />
              <Field label="Follow-up" value={fmt(lead.follow_up_at)} />
            </div>
            <div className="mt-5 rounded-xl bg-[var(--gradient-warm)] p-4">
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground">The moment they want to preserve</div>
              <p className="mt-1 font-serif text-lg italic text-primary">{lead.memory_goal ? `“${lead.memory_goal}”` : "Not captured yet."}</p>
            </div>
          </Card>

          <TasksCard
            leadId={lead.id}
            tasks={data.tasks}
            terminal={terminal}
            onSaved={refresh}
            onError={setError}
          />

          <CommunicationsCard
            leadId={lead.id}
            communications={data.communications}
            activeConsultationId={activeConsultations[0]?.id ?? null}
            terminal={terminal}
            onSaved={refresh}
            onError={setError}
          />

          <ConsultationsCard
            leadId={lead.id}
            consultations={data.consultations}
            scheduleHistory={data.scheduleHistory}
            terminal={terminal}
            onSaved={refresh}
            onError={setError}
          />
        </div>

        <div className="space-y-6">
          <SlaCard
            leadId={lead.id}
            rows={data.sla}
            onSaved={refresh}
            onError={setError}
          />

          <NotificationCard
            rows={data.notifications}
            onSaved={refresh}
            onError={setError}
          />

          <AvailabilityCard
            currentMemberId={data.currentMemberId}
            rows={data.availability}
            blackouts={data.blackouts}
            onSaved={refresh}
            onError={setError}
          />

          <TimelineCard rows={data.activity} />
        </div>
      </div>
    </AppShell>
  );
}

function NextActionCard({
  leadId,
  nextAction,
  terminal,
  onSaved,
  onError,
}: {
  leadId: string;
  nextAction: LeadWorkspaceData["nextAction"];
  terminal: boolean;
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const [actionText, setActionText] = useState("");
  const [dueAt, setDueAt] = useState("");
  const [exceptionReason, setExceptionReason] = useState("");

  useEffect(() => {
    setActionText(nextAction?.action_text ?? "");
    setDueAt(toInputDateTime(nextAction?.due_at));
    setExceptionReason(nextAction?.exception_reason ?? "");
  }, [nextAction]);

  const mutation = useMutation({
    mutationFn: () => setLeadNextAction({
      data: {
        leadId,
        actionText: actionText || null,
        dueAt: toIso(dueAt),
        exceptionReason: exceptionReason || null,
        source: "manual",
      },
    }),
    onSuccess: onSaved,
  });

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Next action discipline</div>
          <h2 className="mt-1 font-serif text-xl text-primary">What must happen next?</h2>
        </div>
        {nextAction ? <StatusPill tone="gold">Owned next step</StatusPill> : <StatusPill tone="warn">Needs next action</StatusPill>}
      </div>
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <label className="sm:col-span-2">
          <span className="mb-1 block text-[10px] uppercase tracking-wider text-muted-foreground">Next action</span>
          <input
            value={actionText}
            onChange={(e) => setActionText(e.target.value)}
            disabled={terminal}
            placeholder="Call, confirm consultation, prepare quote, follow up…"
            className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary disabled:opacity-50"
          />
        </label>
        <label>
          <span className="mb-1 block text-[10px] uppercase tracking-wider text-muted-foreground">Due</span>
          <input
            type="datetime-local"
            value={dueAt}
            onChange={(e) => setDueAt(e.target.value)}
            disabled={terminal}
            className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary disabled:opacity-50"
          />
        </label>
        <label>
          <span className="mb-1 block text-[10px] uppercase tracking-wider text-muted-foreground">Approved exception</span>
          <input
            value={exceptionReason}
            onChange={(e) => setExceptionReason(e.target.value)}
            disabled={terminal}
            placeholder="Only when a normal next action is not appropriate"
            className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary disabled:opacity-50"
          />
        </label>
      </div>
      {!terminal && (
        <div className="mt-3 flex justify-end">
          <button
            type="button"
            disabled={mutation.isPending}
            onClick={async () => {
              onError(null);
              try { await mutation.mutateAsync(); }
              catch (e) { onError(e instanceof Error ? e.message : "Unable to save next action."); }
            }}
            className="inline-flex items-center gap-2 rounded-lg bg-primary px-3 py-1.5 text-xs text-primary-foreground disabled:opacity-50"
          >
            {mutation.isPending && <Loader2 className="h-3 w-3 animate-spin" />}
            Save next action
          </button>
        </div>
      )}
    </Card>
  );
}

function TasksCard({ leadId, tasks, terminal, onSaved, onError }: {
  leadId: string;
  tasks: LeadWorkspaceData["tasks"];
  terminal: boolean;
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const [title, setTitle] = useState("");
  const [taskType, setTaskType] = useState<LeadTaskType>("follow_up");
  const [priority, setPriority] = useState<LeadTaskPriority>("normal");
  const [dueAt, setDueAt] = useState("");

  const createMutation = useMutation({
    mutationFn: () => createLeadWorkspaceTask({ data: {
      leadId,
      taskType,
      title,
      safeSummary: null,
      ownerMemberId: null,
      priority,
      dueAt: toIso(dueAt),
      source: "manual",
      idempotencyKey: null,
    } }),
    onSuccess: async () => {
      setTitle(""); setDueAt("");
      await onSaved();
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ taskId, status, currentPriority, currentDue, ownerMemberId, escalate }: {
      taskId: string;
      status: LeadTaskStatus;
      currentPriority: LeadTaskPriority;
      currentDue: string | null;
      ownerMemberId: string | null;
      escalate: boolean;
    }) => updateLeadWorkspaceTask({ data: {
      taskId,
      status,
      priority: currentPriority,
      dueAt: currentDue,
      snoozedUntil: status === "snoozed" ? new Date(Date.now() + 86400000).toISOString() : null,
      ownerMemberId,
      escalate,
    } }),
    onSuccess: onSaved,
  });

  return (
    <Card className="p-5">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Owned work</div>
          <h2 className="mt-1 font-serif text-xl text-primary">Follow-up tasks</h2>
        </div>
        <StatusPill tone={tasks.some((t) => t.due_at && new Date(t.due_at) < new Date() && !["completed", "cancelled"].includes(t.status)) ? "warn" : "neutral"}>
          {tasks.filter((t) => !["completed", "cancelled"].includes(t.status)).length} active
        </StatusPill>
      </div>

      {!terminal && (
        <div className="mt-4 grid gap-2 sm:grid-cols-4">
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Task title" className="sm:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <select value={taskType} onChange={(e) => setTaskType(e.target.value as LeadTaskType)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {leadTaskTypes.map((type) => <option key={type} value={type}>{taskTypeLabels[type]}</option>)}
          </select>
          <select value={priority} onChange={(e) => setPriority(e.target.value as LeadTaskPriority)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {leadTaskPriorities.map((p) => <option key={p}>{p}</option>)}
          </select>
          <input type="datetime-local" value={dueAt} onChange={(e) => setDueAt(e.target.value)} className="sm:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <button
            type="button"
            disabled={!title.trim() || createMutation.isPending}
            onClick={async () => {
              onError(null);
              try { await createMutation.mutateAsync(); }
              catch (e) { onError(e instanceof Error ? e.message : "Unable to create task."); }
            }}
            className="sm:col-span-2 inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground disabled:opacity-50"
          >
            <Plus className="h-3.5 w-3.5" /> Add task
          </button>
        </div>
      )}

      <div className="mt-4 divide-y divide-border">
        {tasks.length === 0 && <p className="py-5 text-sm italic text-muted-foreground">No tasks yet.</p>}
        {tasks.map((task) => (
          <div key={task.id} className="py-3 first:pt-0 last:pb-0">
            <div className="flex flex-wrap items-start gap-2">
              <div className="min-w-0 flex-1">
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{taskTypeLabels[task.task_type]} · {task.source}</div>
                <div className="mt-0.5 text-sm font-medium text-primary">{task.title}</div>
                <div className="mt-1 text-xs text-muted-foreground">Due {fmt(task.due_at)}{task.escalated_at ? " · Escalated" : ""}</div>
              </div>
              <StatusPill tone={task.priority === "urgent" ? "bad" : task.priority === "high" ? "warn" : "neutral"}>{task.priority}</StatusPill>
              <select
                value={task.status}
                disabled={terminal || updateMutation.isPending}
                onChange={async (e) => {
                  onError(null);
                  try {
                    await updateMutation.mutateAsync({
                      taskId: task.id,
                      status: e.target.value as LeadTaskStatus,
                      currentPriority: task.priority,
                      currentDue: task.due_at,
                      ownerMemberId: task.owner_member_id,
                      escalate: false,
                    });
                  } catch (err) { onError(err instanceof Error ? err.message : "Unable to update task."); }
                }}
                className="rounded-lg border border-border bg-card px-2 py-1 text-xs text-primary disabled:opacity-50"
              >
                {leadTaskStatuses.map((s) => <option key={s} value={s}>{s.replaceAll("_", " ")}</option>)}
              </select>
              {!terminal && !task.escalated_at && !["completed", "cancelled"].includes(task.status) && (
                <button
                  type="button"
                  disabled={updateMutation.isPending}
                  onClick={async () => {
                    try {
                      await updateMutation.mutateAsync({
                        taskId: task.id,
                        status: task.status,
                        currentPriority: task.priority,
                        currentDue: task.due_at,
                        ownerMemberId: task.owner_member_id,
                        escalate: true,
                      });
                    } catch (err) { onError(err instanceof Error ? err.message : "Unable to escalate task."); }
                  }}
                  className="rounded-lg border border-border px-2 py-1 text-[11px] text-primary"
                >Escalate</button>
              )}
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}

function CommunicationsCard({ leadId, communications, activeConsultationId, terminal, onSaved, onError }: {
  leadId: string;
  communications: LeadWorkspaceData["communications"];
  activeConsultationId: string | null;
  terminal: boolean;
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const [channel, setChannel] = useState<(typeof communicationChannels)[number]>("whatsapp");
  const [direction, setDirection] = useState<(typeof communicationDirections)[number]>("outbound");
  const [purpose, setPurpose] = useState("follow_up");
  const [status, setStatus] = useState<(typeof communicationStatuses)[number]>("manual_confirmed");
  const [summary, setSummary] = useState("Manual interaction recorded in Little Moments OS.");

  const mutation = useMutation({
    mutationFn: () => recordLeadCommunication({ data: {
      leadId,
      channel,
      direction,
      businessPurpose: purpose,
      status,
      safeSummary: summary,
      occurredAt: new Date().toISOString(),
      providerIdentifier: null,
      templateKey: null,
      templateVersion: null,
      consultationId: activeConsultationId,
    } }),
    onSuccess: onSaved,
  });

  return (
    <Card className="p-5">
      <div>
        <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Communication history</div>
        <h2 className="mt-1 font-serif text-xl text-primary">Safe interaction log</h2>
        <p className="mt-1 text-xs text-muted-foreground">Only metadata and a safe summary are stored. Message bodies are deliberately excluded.</p>
      </div>

      {!terminal && (
        <div className="mt-4 grid gap-2 sm:grid-cols-4">
          <select value={channel} onChange={(e) => setChannel(e.target.value as typeof channel)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {communicationChannels.map((c) => <option key={c}>{c}</option>)}
          </select>
          <select value={direction} onChange={(e) => setDirection(e.target.value as typeof direction)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {communicationDirections.map((d) => <option key={d}>{d}</option>)}
          </select>
          <input value={purpose} onChange={(e) => setPurpose(e.target.value)} placeholder="Business purpose" className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <select value={status} onChange={(e) => setStatus(e.target.value as typeof status)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {communicationStatuses.map((s) => <option key={s}>{s}</option>)}
          </select>
          <input value={summary} onChange={(e) => setSummary(e.target.value)} className="sm:col-span-3 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <button
            type="button"
            disabled={mutation.isPending || !purpose.trim() || !summary.trim()}
            onClick={async () => {
              onError(null);
              try { await mutation.mutateAsync(); }
              catch (e) { onError(e instanceof Error ? e.message : "Unable to record communication."); }
            }}
            className="rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground disabled:opacity-50"
          >Record interaction</button>
        </div>
      )}

      <div className="mt-4 space-y-2">
        {communications.length === 0 && <p className="text-sm italic text-muted-foreground">No communication metadata recorded yet.</p>}
        {communications.map((item) => (
          <div key={item.id} className="rounded-xl border border-border p-3">
            <div className="flex flex-wrap items-center gap-2 text-[10px] uppercase tracking-wider text-muted-foreground">
              <span>{item.channel}</span><span>·</span><span>{item.direction}</span><span>·</span><span>{item.business_purpose}</span>
              <StatusPill tone={item.status === "failed" ? "bad" : item.status === "delivered" || item.status === "read" || item.status === "manual_confirmed" ? "good" : "neutral"}>{item.status.replaceAll("_", " ")}</StatusPill>
            </div>
            <p className="mt-1 text-sm text-primary">{item.safe_summary}</p>
            <div className="mt-1 text-[11px] text-muted-foreground">{fmt(item.occurred_at)}</div>
          </div>
        ))}
      </div>
    </Card>
  );
}

function ConsultationsCard({ leadId, consultations, scheduleHistory, terminal, onSaved, onError }: {
  leadId: string;
  consultations: LeadWorkspaceData["consultations"];
  scheduleHistory: LeadWorkspaceData["scheduleHistory"];
  terminal: boolean;
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const [startsAt, setStartsAt] = useState("");
  const [duration, setDuration] = useState(30);
  const scheduleMutation = useMutation({
    mutationFn: () => scheduleLeadConsultation({ data: {
      leadId,
      startsAt: new Date(startsAt).toISOString(),
      durationMinutes: duration,
      timezone: "Asia/Kolkata",
      ownerMemberId: null,
    } }),
    onSuccess: async () => { setStartsAt(""); await onSaved(); },
  });
  const rescheduleMutation = useMutation({ mutationFn: (variables: Parameters<typeof rescheduleLeadConsultation>[0]) => rescheduleLeadConsultation(variables), onSuccess: onSaved });
  const cancelMutation = useMutation({ mutationFn: (variables: Parameters<typeof cancelLeadConsultation>[0]) => cancelLeadConsultation(variables), onSuccess: onSaved });
  const missedMutation = useMutation({ mutationFn: (variables: Parameters<typeof markLeadConsultationMissed>[0]) => markLeadConsultationMissed(variables), onSuccess: onSaved });

  const historyByConsultation = useMemo(() => {
    const map = new Map<string, typeof scheduleHistory>();
    for (const row of scheduleHistory) {
      map.set(row.consultation_id, [...(map.get(row.consultation_id) ?? []), row]);
    }
    return map;
  }, [scheduleHistory]);

  return (
    <Card className="p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Consultation foundation</div>
          <h2 className="mt-1 font-serif text-xl text-primary">Schedule, conduct, decide</h2>
        </div>
        <StatusPill tone="neutral">Asia/Kolkata</StatusPill>
      </div>

      {!terminal && (
        <div className="mt-4 grid gap-2 sm:grid-cols-[1fr_120px_auto]">
          <input type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <select value={duration} onChange={(e) => setDuration(Number(e.target.value))} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
            {[20,30,45,60,90].map((n) => <option key={n} value={n}>{n} min</option>)}
          </select>
          <button
            type="button"
            disabled={!startsAt || scheduleMutation.isPending}
            onClick={async () => {
              onError(null);
              try { await scheduleMutation.mutateAsync(); }
              catch (e) { onError(e instanceof Error ? e.message : "Unable to schedule consultation."); }
            }}
            className="inline-flex items-center justify-center gap-1.5 rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground disabled:opacity-50"
          ><CalendarClock className="h-3.5 w-3.5" /> Schedule</button>
        </div>
      )}

      <div className="mt-5 space-y-4">
        {consultations.length === 0 && <p className="text-sm italic text-muted-foreground">No consultation scheduled yet.</p>}
        {consultations.map((c) => {
          const active = ["pending_confirmation", "tentative", "scheduled"].includes(c.status);
          return (
            <div key={c.id} className="rounded-xl border border-border p-4">
              <div className="flex flex-wrap items-start gap-2">
                <div className="min-w-0 flex-1">
                  <div className="font-medium text-primary">{fmt(c.scheduled_start_at)}</div>
                  <div className="mt-0.5 text-xs text-muted-foreground">{c.duration_minutes} min · v{c.schedule_version} · {c.timezone}</div>
                </div>
                <StatusPill tone={c.status === "completed" ? "good" : c.status === "cancelled" || c.status === "missed" ? "warn" : "gold"}>{c.status.replaceAll("_", " ")}</StatusPill>
              </div>

              {c.outcome && (
                <div className="mt-3 rounded-lg bg-muted px-3 py-2 text-xs text-primary">Outcome: {outcomeLabels[c.outcome]}</div>
              )}

              {active && !terminal && (
                <div className="mt-3 flex flex-wrap gap-2">
                  <button
                    type="button"
                    disabled={rescheduleMutation.isPending}
                    onClick={async () => {
                      const next = window.prompt("New consultation date/time (YYYY-MM-DDTHH:mm)", toInputDateTime(c.scheduled_start_at));
                      if (!next) return;
                      const reason = window.prompt("Why is this consultation being rescheduled?");
                      if (!reason?.trim()) { onError("A reason is required to reschedule."); return; }
                      try {
                        await rescheduleMutation.mutateAsync({ data: {
                          consultationId: c.id,
                          startsAt: new Date(next).toISOString(),
                          reason: reason.trim(),
                          durationMinutes: c.duration_minutes,
                        } });
                      } catch (e) { onError(e instanceof Error ? e.message : "Unable to reschedule."); }
                    }}
                    className="rounded-lg border border-border px-2.5 py-1.5 text-xs text-primary"
                  >Reschedule</button>
                  <button
                    type="button"
                    disabled={cancelMutation.isPending}
                    onClick={async () => {
                      const reason = window.prompt("Why is this consultation being cancelled?");
                      if (!reason?.trim()) { onError("A reason is required to cancel."); return; }
                      try { await cancelMutation.mutateAsync({ data: { consultationId: c.id, reason: reason.trim() } }); }
                      catch (e) { onError(e instanceof Error ? e.message : "Unable to cancel."); }
                    }}
                    className="rounded-lg border border-border px-2.5 py-1.5 text-xs text-primary"
                  >Cancel</button>
                  <button
                    type="button"
                    disabled={missedMutation.isPending}
                    onClick={async () => {
                      try { await missedMutation.mutateAsync({ data: { consultationId: c.id } }); }
                      catch (e) { onError(e instanceof Error ? e.message : "Unable to mark missed."); }
                    }}
                    className="rounded-lg border border-border px-2.5 py-1.5 text-xs text-primary"
                  >Mark missed</button>
                </div>
              )}

              {active && !terminal && (
                <ConsultationCompletionForm consultation={c} onSaved={onSaved} onError={onError} />
              )}

              <PrivateNotes consultation={c} />

              {(historyByConsultation.get(c.id)?.length ?? 0) > 0 && (
                <details className="mt-3">
                  <summary className="cursor-pointer text-xs text-muted-foreground">Schedule history</summary>
                  <div className="mt-2 space-y-2">
                    {historyByConsultation.get(c.id)?.map((h) => (
                      <div key={h.id} className="rounded-lg bg-muted px-3 py-2 text-xs text-primary">
                        {h.event_type.replaceAll("_", " ")} · {fmt(h.created_at)}
                        {h.notification_effect && <div className="mt-0.5 text-muted-foreground">{h.notification_effect}</div>}
                      </div>
                    ))}
                  </div>
                </details>
              )}
            </div>
          );
        })}
      </div>
    </Card>
  );
}

function ConsultationCompletionForm({ consultation, onSaved, onError }: {
  consultation: ConsultationRow;
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const [outcome, setOutcome] = useState<ConsultationOutcome>("needs_follow_up");
  const [businessSummary, setBusinessSummary] = useState("");
  const [emotionalGoal, setEmotionalGoal] = useState("");
  const [timingFit, setTimingFit] = useState("");
  const [packageFit, setPackageFit] = useState("");
  const [objections, setObjections] = useState("");
  const [nextStep, setNextStep] = useState("");
  const [privacy, setPrivacy] = useState("");
  const [safety, setSafety] = useState("");
  const [recap, setRecap] = useState("");
  const [privateNote, setPrivateNote] = useState("");
  const [nextAction, setNextAction] = useState("");
  const [nextActionDue, setNextActionDue] = useState("");

  const mutation = useMutation({
    mutationFn: () => completeLeadConsultation({ data: {
      consultationId: consultation.id,
      outcome,
      businessSummary: businessSummary || null,
      confirmedEmotionalGoal: emotionalGoal || null,
      timingFit: timingFit || null,
      packageFit: packageFit || null,
      objections: objections || null,
      nextStep,
      privacyClarification: privacy || null,
      safetyReview: safety || null,
      clientShareableRecap: recap || null,
      nextAction,
      nextActionDueAt: new Date(nextActionDue).toISOString(),
      privateNote: privateNote || null,
    } }),
    onSuccess: onSaved,
  });

  return (
    <details className="mt-4 rounded-xl bg-muted/60 p-3">
      <summary className="cursor-pointer text-xs font-medium text-primary">Complete consultation with structured outcome</summary>
      <div className="mt-3 grid gap-2 sm:grid-cols-2">
        <select value={outcome} onChange={(e) => setOutcome(e.target.value as ConsultationOutcome)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
          {consultationOutcomes.map((o) => <option key={o} value={o}>{outcomeLabels[o]}</option>)}
        </select>
        <input type="datetime-local" value={nextActionDue} onChange={(e) => setNextActionDue(e.target.value)} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <input value={nextAction} onChange={(e) => setNextAction(e.target.value)} placeholder="Required next action" className="sm:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <textarea value={businessSummary} onChange={(e) => setBusinessSummary(e.target.value)} placeholder="Business summary" rows={2} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <textarea value={emotionalGoal} onChange={(e) => setEmotionalGoal(e.target.value)} placeholder="Confirmed emotional goal" rows={2} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <input value={timingFit} onChange={(e) => setTimingFit(e.target.value)} placeholder="Timing fit" className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <input value={packageFit} onChange={(e) => setPackageFit(e.target.value)} placeholder="Package fit" className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <textarea value={objections} onChange={(e) => setObjections(e.target.value)} placeholder="Objections / hesitations" rows={2} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <textarea value={nextStep} onChange={(e) => setNextStep(e.target.value)} placeholder="Required structured next step" rows={2} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <textarea value={privacy} onChange={(e) => setPrivacy(e.target.value)} placeholder="Privacy clarification" rows={2} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <textarea value={safety} onChange={(e) => setSafety(e.target.value)} placeholder="Safety review summary" rows={2} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <textarea value={recap} onChange={(e) => setRecap(e.target.value)} placeholder="Explicitly client-shareable recap" rows={2} className="sm:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        <label className="sm:col-span-2 rounded-lg border border-gold/40 bg-[var(--gradient-warm)] p-3">
          <span className="flex items-center gap-1.5 text-[10px] uppercase tracking-wider text-muted-foreground"><LockKeyhole className="h-3 w-3" /> Restricted private note</span>
          <textarea value={privateNote} onChange={(e) => setPrivateNote(e.target.value)} placeholder="Founder-restricted operational note. Never copied to timeline, analytics or client recap." rows={3} className="mt-2 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
        </label>
        <button
          type="button"
          disabled={mutation.isPending || !nextStep.trim() || !nextAction.trim() || !nextActionDue}
          onClick={async () => {
            onError(null);
            try { await mutation.mutateAsync(); }
            catch (e) { onError(e instanceof Error ? e.message : "Unable to complete consultation."); }
          }}
          className="sm:col-span-2 inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground disabled:opacity-50"
        ><CheckCircle2 className="h-3.5 w-3.5" /> Complete consultation</button>
      </div>
    </details>
  );
}

function PrivateNotes({ consultation }: { consultation: ConsultationRow }) {
  const [notes, setNotes] = useState<ConsultationPrivateNoteRow[] | null>(null);
  const mutation = useMutation({
    mutationFn: () => getConsultationPrivateNotes({ data: { consultationId: consultation.id } }),
    onSuccess: setNotes,
  });

  return (
    <div className="mt-3">
      <button
        type="button"
        disabled={mutation.isPending}
        onClick={() => mutation.mutate()}
        className="inline-flex items-center gap-1.5 text-[11px] text-muted-foreground hover:text-primary"
      ><LockKeyhole className="h-3 w-3" /> Load restricted private notes</button>
      {mutation.isError && <div className="mt-2 text-xs text-muted-foreground">Restricted notes are not available for this role.</div>}
      {notes && (
        <div className="mt-2 space-y-2">
          {notes.length === 0 && <p className="text-xs text-muted-foreground">No private notes recorded.</p>}
          {notes.map((n) => <div key={n.id} className="rounded-lg border border-gold/30 bg-accent p-3 text-xs text-primary"><div>{n.note_text}</div><div className="mt-1 text-[10px] text-muted-foreground">{fmt(n.created_at)}</div></div>)}
        </div>
      )}
    </div>
  );
}

function SlaCard({ leadId, rows, onSaved, onError }: {
  leadId: string;
  rows: LeadWorkspaceData["sla"];
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const mutation = useMutation({ mutationFn: (variables: Parameters<typeof createLeadSlaOverride>[0]) => createLeadSlaOverride(variables), onSuccess: onSaved });
  const breached = rows.filter((r) => r.status === "breached").length;
  return (
    <Card className="p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Business-hours discipline</div>
          <h2 className="mt-1 font-serif text-xl text-primary">SLA health</h2>
        </div>
        <StatusPill tone={breached ? "bad" : "good"}>{breached ? `${breached} breached` : "On watch"}</StatusPill>
      </div>
      <div className="mt-4 space-y-2">
        {rows.map((row) => (
          <div key={row.sla_key} className="rounded-xl border border-border p-3">
            <div className="flex items-center gap-2">
              {row.status === "breached" ? <AlertTriangle className="h-4 w-4 text-destructive" /> : row.status === "ok" ? <ShieldCheck className="h-4 w-4 text-gold" /> : <Clock3 className="h-4 w-4 text-muted-foreground" />}
              <div className="min-w-0 flex-1 text-xs font-medium text-primary">{row.sla_key.replaceAll("_", " ")}</div>
              <StatusPill tone={row.status === "breached" ? "bad" : row.status === "due" ? "warn" : row.status === "overridden" ? "gold" : "neutral"}>{row.status.replaceAll("_", " ")}</StatusPill>
            </div>
            <p className="mt-1 text-[11px] text-muted-foreground">{row.detail}</p>
            <div className="mt-1 text-[10px] text-muted-foreground">{row.elapsed_business_minutes} / {row.threshold_business_minutes} business min</div>
            {row.status === "breached" && (
              <button
                type="button"
                disabled={mutation.isPending}
                onClick={async () => {
                  const reason = window.prompt(`Override ${row.sla_key}: reason`);
                  if (!reason?.trim()) return;
                  const review = window.prompt("Review date/time (YYYY-MM-DDTHH:mm)");
                  if (!review) return;
                  onError(null);
                  try {
                    await mutation.mutateAsync({ data: {
                      leadId,
                      slaKey: row.sla_key,
                      reason: reason.trim(),
                      expiresAt: null,
                      reviewAt: new Date(review).toISOString(),
                    } });
                  } catch (e) { onError(e instanceof Error ? e.message : "Unable to create SLA override."); }
                }}
                className="mt-2 text-[11px] text-muted-foreground underline underline-offset-2"
              >Authorised override</button>
            )}
          </div>
        ))}
      </div>
    </Card>
  );
}

function NotificationCard({ rows, onSaved, onError }: {
  rows: LeadWorkspaceData["notifications"];
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const mutation = useMutation({ mutationFn: (variables: Parameters<typeof retryLeadNotification>[0]) => retryLeadNotification(variables), onSuccess: onSaved });
  return (
    <Card className="p-5">
      <div>
        <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Reminder reliability</div>
        <h2 className="mt-1 font-serif text-xl text-primary">Notification outbox</h2>
        <p className="mt-1 text-xs text-muted-foreground">Jobs are durable and idempotent. Provider delivery is not claimed until a real adapter confirms it.</p>
      </div>
      <div className="mt-4 space-y-2">
        {rows.length === 0 && <p className="text-sm italic text-muted-foreground">No reminder jobs yet.</p>}
        {rows.map((row) => (
          <div key={row.id} className="rounded-xl border border-border p-3">
            <div className="flex items-center gap-2">
              <div className="min-w-0 flex-1 text-xs font-medium text-primary">{row.kind.replaceAll("_", " ")}</div>
              <StatusPill tone={row.status === "failed" || row.status === "manual_action_required" ? "warn" : row.status === "sent" ? "good" : "neutral"}>{row.status.replaceAll("_", " ")}</StatusPill>
            </div>
            <div className="mt-1 text-[11px] text-muted-foreground">Scheduled {fmt(row.scheduled_for)} · {row.channel}</div>
            {["failed", "manual_action_required"].includes(row.status) && (
              <button
                type="button"
                disabled={mutation.isPending}
                onClick={async () => {
                  onError(null);
                  try { await mutation.mutateAsync({ data: { notificationId: row.id } }); }
                  catch (e) { onError(e instanceof Error ? e.message : "Unable to request recovery."); }
                }}
                className="mt-2 inline-flex items-center gap-1 text-[11px] text-primary"
              ><RotateCcw className="h-3 w-3" /> Retry / manual recovery</button>
            )}
          </div>
        ))}
      </div>
    </Card>
  );
}

function AvailabilityCard({ currentMemberId, rows, blackouts, onSaved, onError }: {
  currentMemberId: string | null;
  rows: LeadWorkspaceData["availability"];
  blackouts: LeadWorkspaceData["blackouts"];
  onSaved: () => Promise<void>;
  onError: (message: string | null) => void;
}) {
  const [weekday, setWeekday] = useState(1);
  const [start, setStart] = useState("09:00");
  const [end, setEnd] = useState("18:00");
  const [capacity, setCapacity] = useState(1);
  const ownRows = rows.filter((r) => !currentMemberId || r.owner_member_id === currentMemberId);
  const availabilityMutation = useMutation({ mutationFn: (variables: Parameters<typeof saveConsultationAvailability>[0]) => saveConsultationAvailability(variables), onSuccess: onSaved });
  const blackoutMutation = useMutation({ mutationFn: (variables: Parameters<typeof createConsultationBlackout>[0]) => createConsultationBlackout(variables), onSuccess: onSaved });

  return (
    <Card className="p-5">
      <div>
        <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Availability rules</div>
        <h2 className="mt-1 font-serif text-xl text-primary">Consultation windows</h2>
      </div>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {ownRows.filter((r) => r.is_bookable).map((r) => (
          <span key={r.id} className="rounded-full border border-border bg-muted px-2.5 py-1 text-[11px] text-primary">{weekdayLabels[r.weekday]} {r.local_start.slice(0,5)}–{r.local_end.slice(0,5)} · cap {r.capacity}</span>
        ))}
      </div>
      <details className="mt-4">
        <summary className="cursor-pointer text-xs text-muted-foreground">Adjust my working window</summary>
        <div className="mt-3 grid grid-cols-2 gap-2">
          <select value={weekday} onChange={(e) => setWeekday(Number(e.target.value))} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">{weekdayLabels.map((label,i) => <option key={label} value={i}>{label}</option>)}</select>
          <input type="number" min={1} max={20} value={capacity} onChange={(e) => setCapacity(Number(e.target.value))} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <input type="time" value={start} onChange={(e) => setStart(e.target.value)} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <input type="time" value={end} onChange={(e) => setEnd(e.target.value)} className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
          <button
            type="button"
            disabled={availabilityMutation.isPending}
            onClick={async () => {
              onError(null);
              try { await availabilityMutation.mutateAsync({ data: {
                weekday, localStart: start, localEnd: end, timezone: "Asia/Kolkata",
                durationMinutes: 30, bufferBeforeMinutes: 10, bufferAfterMinutes: 10,
                capacity, minimumNoticeMinutes: 120, bookingHorizonDays: 90, isBookable: true,
              } }); }
              catch (e) { onError(e instanceof Error ? e.message : "Unable to save availability."); }
            }}
            className="col-span-2 rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground"
          >Save working window</button>
        </div>
      </details>
      <details className="mt-3">
        <summary className="cursor-pointer text-xs text-muted-foreground">Add a blackout</summary>
        <button
          type="button"
          disabled={blackoutMutation.isPending}
          onClick={async () => {
            const from = window.prompt("Blackout start (YYYY-MM-DDTHH:mm)");
            const to = window.prompt("Blackout end (YYYY-MM-DDTHH:mm)");
            const reason = window.prompt("Safe reason (for example: studio closed)");
            if (!from || !to || !reason?.trim()) return;
            try { await blackoutMutation.mutateAsync({ data: {
              startsAt: new Date(from).toISOString(),
              endsAt: new Date(to).toISOString(),
              safeReason: reason.trim(),
            } }); }
            catch (e) { onError(e instanceof Error ? e.message : "Unable to add blackout."); }
          }}
          className="mt-2 rounded-lg border border-border px-3 py-1.5 text-xs text-primary"
        >Add blackout period</button>
      </details>
      {blackouts.length > 0 && (
        <div className="mt-3 space-y-1 text-[11px] text-muted-foreground">
          {blackouts.slice(0,5).map((b) => <div key={b.id}>{fmt(b.starts_at)} → {fmt(b.ends_at)} · {b.safe_reason}</div>)}
        </div>
      )}
    </Card>
  );
}

function TimelineCard({ rows }: { rows: LeadWorkspaceData["activity"] }) {
  return (
    <Card className="p-5">
      <div>
        <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Immutable operational history</div>
        <h2 className="mt-1 font-serif text-xl text-primary">Activity timeline</h2>
      </div>
      <div className="mt-4 space-y-3">
        {rows.length === 0 && <p className="text-sm italic text-muted-foreground">Sprint 6 activity will appear here as the team works the enquiry.</p>}
        {rows.map((row) => (
          <div key={row.id} className="relative border-l border-gold/40 pl-4">
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{row.event_type.replaceAll("_", " ")} · {fmt(row.created_at)}</div>
            <p className="mt-0.5 text-sm text-primary">{row.summary}</p>
          </div>
        ))}
      </div>
    </Card>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{label}</div>
      <div className="mt-0.5 text-sm text-primary">{value}</div>
    </div>
  );
}
