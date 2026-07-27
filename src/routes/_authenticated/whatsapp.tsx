import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore, renderTemplate, buildPlaceholders } from "@/store/useStore";
import { handle } from "@/lib/handle";
import {
  whatsappMessageTypes,
  whatsappTemplates,
  whatsappPlaceholders,
  followUpStatuses,
  type WhatsappMessageType,
  type FollowUpStatus,
} from "@/lib/mock-data";
import { MessageSquareHeart, Copy, Send, CalendarClock, ExternalLink } from "lucide-react";

export const Route = createFileRoute("/_authenticated/whatsapp")({
  head: () => ({ meta: [{ title: "WhatsApp Follow-Ups · Little Moments OS" }] }),
  component: WhatsappPage,
});

function WhatsappPage() {
  const bookings = useStore((s) => s.bookings);
  const leads = useStore((s) => s.leads);
  const followUps = useStore((s) => s.followUps);
  const create = useStore((s) => s.createFollowUp);
  const update = useStore((s) => s.updateFollowUp);
  const snapshot = useStore((s) => ({
    bookings: s.bookings,
    leads: s.leads,
    pixieset: s.pixieset,
    memoryProfiles: s.memoryProfiles,
  }));

  type Target = { kind: "lead" | "booking"; id: string; label: string; phone?: string };
  const targets: Target[] = useMemo(
    () => [
      ...bookings.map<Target>((b) => ({ kind: "booking", id: b.id, label: `${b.client} · ${b.id}` })),
      ...leads.map<Target>((l) => ({ kind: "lead", id: l.id, label: `${l.parent} · ${l.id}`, phone: l.phone })),
    ],
    [bookings, leads],
  );

  const [targetIdx, setTargetIdx] = useState(0);
  const [type, setType] = useState<WhatsappMessageType>("New Inquiry");
  const [draft, setDraft] = useState("");
  const [scheduled, setScheduled] = useState("");
  const [edited, setEdited] = useState(false);

  const target = targets[targetIdx];
  const context = useMemo(() => {
    if (!target) return { client: "", phone: "" };
    if (target.kind === "lead") {
      const l = leads.find((x) => x.id === target.id);
      return { client: l?.parent ?? "", phone: l?.phone ?? "", leadId: target.id };
    }
    const b = bookings.find((x) => x.id === target.id);
    const c = b?.clientId ? snapshot : undefined;
    void c;
    return { client: b?.client ?? "", phone: "", bookingId: target.id };
  }, [target, leads, bookings, snapshot]);

  const generated = useMemo(() => {
    const vars = buildPlaceholders(snapshot, {
      client: context.client,
      bookingId: (context as { bookingId?: string }).bookingId,
      leadId: (context as { leadId?: string }).leadId,
    });
    return renderTemplate(whatsappTemplates[type], vars);
  }, [snapshot, context, type]);

  const message = edited ? draft : generated;

  const waLink = `https://wa.me/?text=${encodeURIComponent(message)}`;

  function save(status: FollowUpStatus) {
    if (!target) return;
    handle(
      create({
        client: context.client,
        bookingId: target.kind === "booking" ? target.id : undefined,
        leadId: target.kind === "lead" ? target.id : undefined,
        messageType: type,
        message,
        scheduledDate: scheduled || new Date().toISOString().slice(0, 10),
        status,
        sentBy: "Hema",
        notes: "",
      }),
    );
  }

  return (
    <AppShell>
      <PageHeader
        eyebrow="Calm, philosophy-aligned outreach"
        title="WhatsApp Follow-Ups"
        subtitle="Warm templates with placeholders — never pressure-selling."
        quote="Every message is a hand we extend, not a sale we push."
      />

      <div className="grid lg:grid-cols-3 gap-5">
        <Card className="p-5 lg:col-span-2 space-y-4">
          <div className="grid sm:grid-cols-2 gap-3">
            <L label="Recipient">
              <select
                value={targetIdx}
                onChange={(e) => setTargetIdx(Number(e.target.value))}
                className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
              >
                {targets.map((t, i) => (
                  <option key={`${t.kind}:${t.id}`} value={i}>
                    {t.kind === "lead" ? "Lead" : "Booking"} · {t.label}
                  </option>
                ))}
              </select>
            </L>
            <L label="Message type">
              <select
                value={type}
                onChange={(e) => {
                  setType(e.target.value as WhatsappMessageType);
                  setEdited(false);
                }}
                className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
              >
                {whatsappMessageTypes.map((t) => <option key={t}>{t}</option>)}
              </select>
            </L>
          </div>

          <L label="Message">
            <textarea
              value={message}
              onChange={(e) => {
                setEdited(true);
                setDraft(e.target.value);
              }}
              rows={8}
              maxLength={1500}
              className="w-full rounded-lg border border-gold/40 bg-[var(--gradient-warm)] px-3 py-3 text-sm text-primary font-serif italic leading-relaxed"
            />
          </L>

          <div className="flex items-center justify-between flex-wrap gap-3">
            <div className="flex items-center gap-2">
              <L label="Schedule for">
                <input
                  type="date"
                  value={scheduled}
                  onChange={(e) => setScheduled(e.target.value)}
                  className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
                />
              </L>
            </div>
            <div className="flex flex-wrap gap-2">
              <a
                href={waLink}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-[var(--gradient-gold)] text-primary border border-gold"
              >
                <MessageSquareHeart className="h-3 w-3" /> Generate WhatsApp message
                <ExternalLink className="h-3 w-3" />
              </a>
              <button
                onClick={() => {
                  navigator.clipboard.writeText(message);
                  handle({ ok: true, message: "Copied." });
                }}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border border-border bg-card text-primary"
              >
                <Copy className="h-3 w-3" /> Copy
              </button>
              <button
                onClick={() => save("Sent")}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground"
              >
                <Send className="h-3 w-3" /> Mark as Sent
              </button>
              <button
                onClick={() => save("Scheduled")}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg border border-border bg-muted text-primary"
              >
                <CalendarClock className="h-3 w-3" /> Schedule
              </button>
            </div>
          </div>

          <p className="text-[11px] text-muted-foreground">
            Placeholders: {whatsappPlaceholders.join(" · ")}
          </p>
        </Card>

        <Card className="p-5">
          <div className="font-serif text-lg text-primary mb-3">Follow-up log</div>
          {followUps.length === 0 ? (
            <p className="text-sm italic text-muted-foreground">No follow-ups yet — every kind word starts here.</p>
          ) : (
            <ul className="space-y-3 max-h-[480px] overflow-auto pr-1">
              {followUps.map((f) => (
                <li key={f.id} className="border border-border rounded-xl p-3">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                        {f.messageType}
                      </div>
                      <div className="text-sm text-primary mt-0.5">{f.client}</div>
                    </div>
                    <select
                      value={f.status}
                      onChange={(e) => handle(update(f.id, { status: e.target.value as FollowUpStatus }))}
                      className="text-[11px] rounded-full border border-border bg-card px-2 py-0.5 text-primary"
                    >
                      {followUpStatuses.map((s) => <option key={s}>{s}</option>)}
                    </select>
                  </div>
                  <p className="text-xs italic text-primary/80 mt-2 line-clamp-3">{f.message}</p>
                  <div className="mt-2 flex items-center gap-2 text-[10px] text-muted-foreground">
                    <StatusPill tone={f.status === "Sent" ? "good" : f.status === "Scheduled" ? "warn" : "neutral"}>
                      {f.status}
                    </StatusPill>
                    <span>{f.scheduledDate}</span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </AppShell>
  );
}

function L({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="block text-[10px] uppercase tracking-wider text-muted-foreground mb-1">{label}</span>
      {children}
    </label>
  );
}