import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";
import {
  teamRoles,
  taskPriorities,
  taskStatuses,
  type TeamRole,
  type TaskPriority,
  type TaskStatus,
} from "@/lib/mock-data";
import { ListChecks, Plus } from "lucide-react";

export const Route = createFileRoute("/_authenticated/tasks")({
  head: () => ({ meta: [{ title: "Team Tasks · Little Moments OS" }] }),
  component: TasksPage,
});

function TasksPage() {
  const tasks = useStore((s) => s.tasks);
  const create = useStore((s) => s.createTask);
  const update = useStore((s) => s.updateTask);
  const [filter, setFilter] = useState<TeamRole | "All">("All");
  const [statusFilter, setStatusFilter] = useState<TaskStatus | "All">("All");
  const [draft, setDraft] = useState({
    title: "",
    role: "Client Coordinator" as TeamRole,
    assignee: "",
    dueDate: "",
    priority: "Medium" as TaskPriority,
    notes: "",
  });

  const visible = tasks.filter(
    (t) => (filter === "All" || t.role === filter) && (statusFilter === "All" || t.status === statusFilter),
  );

  const counts = teamRoles.map((r) => ({ role: r, n: tasks.filter((t) => t.role === r && t.status !== "Done" && t.status !== "Skipped").length }));

  return (
    <AppShell>
      <PageHeader
        eyebrow="Operations, gently coordinated"
        title="Team Task Center"
        subtitle="Every promise broken into a calm, owned next action."
        quote="Care is operational — done quietly, on time, with love."
      />

      <section className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-2 mb-6">
        {counts.map(({ role, n }) => (
          <button
            key={role}
            onClick={() => setFilter(role)}
            className={`text-left rounded-xl border px-3 py-2.5 ${filter === role ? "bg-[var(--gradient-warm)] border-gold" : "bg-card border-border"}`}
          >
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground truncate">{role}</div>
            <div className="font-serif text-xl text-primary mt-0.5">{n}</div>
          </button>
        ))}
      </section>

      <Card className="p-5 mb-5">
        <div className="flex items-center gap-2 mb-3">
          <Plus className="h-4 w-4 text-gold" />
          <div className="font-serif text-base text-primary">Create task</div>
        </div>
        <div className="grid sm:grid-cols-6 gap-2">
          <input
            value={draft.title}
            onChange={(e) => setDraft({ ...draft, title: e.target.value })}
            placeholder="Task title"
            maxLength={200}
            className="sm:col-span-2 rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
          <select
            value={draft.role}
            onChange={(e) => setDraft({ ...draft, role: e.target.value as TeamRole })}
            className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary"
          >
            {teamRoles.map((r) => <option key={r}>{r}</option>)}
          </select>
          <input
            value={draft.assignee}
            onChange={(e) => setDraft({ ...draft, assignee: e.target.value })}
            placeholder="Assignee"
            maxLength={100}
            className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
          <input
            type="date"
            value={draft.dueDate}
            onChange={(e) => setDraft({ ...draft, dueDate: e.target.value })}
            className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
          <select
            value={draft.priority}
            onChange={(e) => setDraft({ ...draft, priority: e.target.value as TaskPriority })}
            className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary"
          >
            {taskPriorities.map((p) => <option key={p}>{p}</option>)}
          </select>
        </div>
        <div className="mt-3 flex justify-end">
          <button
            onClick={() => {
              if (!draft.title.trim()) {
                handle({ ok: false, message: "A task needs a title." });
                return;
              }
              handle(create(draft));
              setDraft({ ...draft, title: "", assignee: "", notes: "" });
            }}
            className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground"
          >
            Add task
          </button>
        </div>
      </Card>

      <div className="flex flex-wrap items-center gap-2 mb-3">
        <select value={filter} onChange={(e) => setFilter(e.target.value as TeamRole | "All")} className="text-xs rounded-lg border border-border bg-card px-2 py-1.5 text-primary">
          <option value="All">All roles</option>
          {teamRoles.map((r) => <option key={r}>{r}</option>)}
        </select>
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as TaskStatus | "All")} className="text-xs rounded-lg border border-border bg-card px-2 py-1.5 text-primary">
          <option value="All">All statuses</option>
          {taskStatuses.map((s) => <option key={s}>{s}</option>)}
        </select>
        <span className="text-xs text-muted-foreground ml-auto">{visible.length} task{visible.length === 1 ? "" : "s"}</span>
      </div>

      <Card className="p-0 overflow-hidden">
        {visible.length === 0 ? (
          <div className="p-10 text-center">
            <ListChecks className="h-5 w-5 text-gold mx-auto" />
            <p className="font-serif text-lg text-primary mt-3">No tasks here.</p>
            <p className="text-xs italic text-muted-foreground">A calm board is a kept promise.</p>
          </div>
        ) : (
          <ul className="divide-y divide-border">
            {visible.map((t) => (
              <li key={t.id} className="px-5 py-4 flex flex-wrap items-start gap-3">
                <div className="flex-1 min-w-0">
                  <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                    {t.role} {t.sop && `· ${t.sop}`}
                  </div>
                  <div className="font-medium text-primary mt-0.5">{t.title}</div>
                  {t.relatedLabel && (
                    <div className="text-xs text-muted-foreground mt-0.5">
                      Linked to {t.relatedType} · {t.relatedLabel}
                    </div>
                  )}
                </div>
                <div className="flex flex-wrap items-center gap-1.5">
                  <StatusPill tone={t.priority === "Urgent" ? "bad" : t.priority === "High" ? "warn" : "neutral"}>
                    {t.priority}
                  </StatusPill>
                  <select
                    value={t.status}
                    onChange={(e) => handle(update(t.id, { status: e.target.value as TaskStatus }))}
                    className="text-[11px] rounded-full border border-gold bg-[var(--gradient-warm)] px-2 py-0.5 text-primary"
                  >
                    {taskStatuses.map((s) => <option key={s}>{s}</option>)}
                  </select>
                  <input
                    value={t.assignee}
                    onChange={(e) => handle(update(t.id, { assignee: e.target.value }))}
                    className="text-[11px] w-28 rounded-lg border border-border bg-card px-2 py-1 text-primary"
                  />
                  <input
                    type="date"
                    value={t.dueDate}
                    onChange={(e) => handle(update(t.id, { dueDate: e.target.value }))}
                    className="text-[11px] rounded-lg border border-border bg-card px-2 py-1 text-primary"
                  />
                </div>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </AppShell>
  );
}