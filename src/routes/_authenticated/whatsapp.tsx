import { useMemo, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ExternalLink, Loader2, MessageSquareHeart, Plus } from "lucide-react";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  communicationDirections,
  communicationStatuses,
  listAllLeadCommunications,
  recordLeadCommunication,
  type CommunicationDirection,
  type CommunicationStatus,
} from "@/lib/lead-workspace.functions";

export const Route = createFileRoute("/_authenticated/whatsapp")({
  head: () => ({
    meta: [
      { title: "WhatsApp & Communication · LittleShots by Hema OS" },
      {
        name: "description",
        content: "Provider-safe WhatsApp outreach and communication metadata for leads.",
      },
    ],
  }),
  component: WhatsappPage,
});

const transientTemplates = {
  inquiry: (name: string) =>
    `Hi ${name}, thank you for reaching out to Little Shots by Hema. This stage is so special, and we would love to help you preserve it beautifully. Could you share your preferred session type, baby’s age or pregnancy month, preferred location, approximate shoot date, and the moment you most want to remember from this stage?`,
  consultation: (name: string) =>
    `Hi ${name}, just a gentle note from Little Shots by Hema about your consultation. We’re looking forward to understanding the chapter you want to preserve and guiding you clearly through the right memory journey.`,
  follow_up: (name: string) =>
    `Hi ${name}, checking in gently from Little Shots by Hema. If this chapter is still something you would love to preserve, we’re here to guide you through the next step whenever it feels right.`,
} as const;

type TemplateKey = keyof typeof transientTemplates;

function fmt(value: string) {
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

function WhatsappPage() {
  const queryClient = useQueryClient();
  const [leadId, setLeadId] = useState("");
  const [template, setTemplate] = useState<TemplateKey>("inquiry");
  const [direction, setDirection] = useState<CommunicationDirection>("outbound");
  const [status, setStatus] = useState<CommunicationStatus>("manual_confirmed");
  const [businessPurpose, setBusinessPurpose] = useState("Inquiry follow-up");
  const [safeSummary, setSafeSummary] = useState("Warm WhatsApp follow-up completed outside the OS.");
  const [error, setError] = useState<string | null>(null);

  const centerQuery = useQuery({
    queryKey: ["lead-communication-center"],
    queryFn: () => listAllLeadCommunications(),
  });

  const communications = centerQuery.data?.communications ?? [];
  const leads = centerQuery.data?.leads ?? [];
  const leadById = useMemo(() => new Map(leads.map((lead) => [lead.id, lead])), [leads]);
  const selectedLead = leadById.get(leadId);
  const message = selectedLead ? transientTemplates[template](selectedLead.parent_name) : "";
  const phoneDigits = selectedLead?.phone?.replace(/\D/g, "") ?? "";
  const waLink = phoneDigits
    ? `https://wa.me/${phoneDigits}?text=${encodeURIComponent(message)}`
    : `https://wa.me/?text=${encodeURIComponent(message)}`;

  const recordMutation = useMutation({
    mutationFn: () => recordLeadCommunication({
      data: {
        leadId,
        channel: "whatsapp",
        direction,
        businessPurpose,
        status,
        safeSummary,
        occurredAt: new Date().toISOString(),
        providerIdentifier: null,
        templateKey: template,
        templateVersion: "sprint6-v1",
        consultationId: null,
      },
    }),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["lead-communication-center"] }),
        queryClient.invalidateQueries({ queryKey: ["lead-workspace", leadId] }),
      ]);
    },
  });

  const safeStatuses = communicationStatuses.filter((value) =>
    ["unknown", "manual_confirmed", "failed"].includes(value),
  );

  return (
    <AppShell>
      <PageHeader
        eyebrow="Calm, consent-aware outreach"
        title="WhatsApp & Communication Log"
        subtitle="Open WhatsApp manually, then record safe metadata — never the message body and never a fake delivery state."
        quote="Every message is guidance, not pressure."
      />

      {(error || centerQuery.error) && (
        <Card className="mb-5 border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">
          {error ?? (centerQuery.error instanceof Error ? centerQuery.error.message : "Unable to load communication history.")}
        </Card>
      )}

      <div className="grid gap-5 lg:grid-cols-3">
        <Card className="space-y-4 p-5 lg:col-span-2">
          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">Manual WhatsApp handoff</div>
            <h2 className="mt-1 font-serif text-xl text-primary">Prepare the conversation</h2>
            <p className="mt-1 text-xs text-muted-foreground">The message below exists only in the browser. Sprint 6 stores safe operational metadata, not communication bodies.</p>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <label className="text-sm text-primary">
              <span className="mb-1 block text-[10px] uppercase tracking-wider text-muted-foreground">Lead</span>
              <select value={leadId} onChange={(e) => setLeadId(e.target.value)} className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary">
                <option value="">Choose lead</option>
                {leads.filter((lead) => !["archived"].includes(lead.status)).map((lead) => (
                  <option key={lead.id} value={lead.id}>{lead.parent_name} · {lead.lead_reference}</option>
                ))}
              </select>
            </label>
            <label className="text-sm text-primary">
              <span className="mb-1 block text-[10px] uppercase tracking-wider text-muted-foreground">Template</span>
              <select value={template} onChange={(e) => setTemplate(e.target.value as TemplateKey)} className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary">
                <option value="inquiry">Inquiry reply</option>
                <option value="consultation">Consultation note</option>
                <option value="follow_up">Gentle follow-up</option>
              </select>
            </label>
          </div>

          <div className="rounded-xl border border-gold/30 bg-[var(--gradient-warm)] p-4 font-serif text-sm italic leading-relaxed text-primary">
            {message || "Choose a lead to prepare a transient WhatsApp message."}
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="text-xs text-muted-foreground">
              {selectedLead?.phone ? `WhatsApp target: ${selectedLead.phone}` : selectedLead ? "No phone is stored for this lead." : ""}
            </div>
            <a
              href={message ? waLink : undefined}
              target="_blank"
              rel="noreferrer"
              aria-disabled={!message}
              className={`inline-flex items-center gap-2 rounded-lg border border-gold bg-[var(--gradient-gold)] px-3 py-2 text-xs text-primary ${!message ? "pointer-events-none opacity-50" : ""}`}
            >
              <MessageSquareHeart className="h-3.5 w-3.5" /> Open WhatsApp <ExternalLink className="h-3 w-3" />
            </a>
          </div>

          <div className="border-t border-border pt-4">
            <div className="mb-2 font-serif text-base text-primary">Record safe metadata after the interaction</div>
            <div className="grid gap-2 sm:grid-cols-2">
              <select value={direction} onChange={(e) => setDirection(e.target.value as CommunicationDirection)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
                {communicationDirections.filter((value) => value !== "internal").map((value) => <option key={value}>{value}</option>)}
              </select>
              <select value={status} onChange={(e) => setStatus(e.target.value as CommunicationStatus)} className="rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary">
                {safeStatuses.map((value) => <option key={value}>{value.replaceAll("_", " ")}</option>)}
              </select>
              <input value={businessPurpose} onChange={(e) => setBusinessPurpose(e.target.value)} maxLength={160} placeholder="Business purpose" className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
              <input value={safeSummary} onChange={(e) => setSafeSummary(e.target.value)} maxLength={500} placeholder="Safe summary — no message body" className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary" />
            </div>
            <div className="mt-3 flex justify-end">
              <button
                type="button"
                disabled={!leadId || !businessPurpose.trim() || !safeSummary.trim() || recordMutation.isPending}
                onClick={async () => {
                  setError(null);
                  try { await recordMutation.mutateAsync(); }
                  catch (cause) { setError(cause instanceof Error ? cause.message : "Unable to record communication metadata."); }
                }}
                className="inline-flex items-center gap-2 rounded-lg bg-primary px-3 py-2 text-xs text-primary-foreground disabled:opacity-50"
              >
                {recordMutation.isPending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Plus className="h-3.5 w-3.5" />}
                Record interaction
              </button>
            </div>
          </div>
        </Card>

        <Card className="p-5">
          <div className="font-serif text-lg text-primary">Communication log</div>
          <p className="mt-1 text-xs text-muted-foreground">Safe summaries only. Provider delivery is not inferred.</p>
          <div className="mt-4 max-h-[620px] space-y-3 overflow-auto pr-1">
            {centerQuery.isLoading && <p className="text-sm text-muted-foreground"><Loader2 className="mr-2 inline h-4 w-4 animate-spin" />Loading…</p>}
            {!centerQuery.isLoading && communications.length === 0 && <p className="text-sm italic text-muted-foreground">No communication metadata yet.</p>}
            {communications.map((item) => {
              const lead = leadById.get(item.lead_id);
              return (
                <div key={item.id} className="rounded-xl border border-border p-3">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{item.channel} · {item.direction}</div>
                      <div className="mt-0.5 text-sm text-primary">{lead?.parent_name ?? "Lead"}</div>
                    </div>
                    <StatusPill tone={item.status === "failed" ? "bad" : item.status === "manual_confirmed" ? "good" : "neutral"}>{item.status.replaceAll("_", " ")}</StatusPill>
                  </div>
                  <div className="mt-2 text-xs text-primary">{item.safe_summary}</div>
                  <div className="mt-1 text-[10px] text-muted-foreground">{item.business_purpose} · {fmt(item.occurred_at)}</div>
                  {lead && (
                    <Link to="/leads/$leadId" params={{ leadId: lead.id }} className="mt-2 inline-block text-[11px] text-muted-foreground underline underline-offset-2">Open lead workspace</Link>
                  )}
                </div>
              );
            })}
          </div>
        </Card>
      </div>
    </AppShell>
  );
}
