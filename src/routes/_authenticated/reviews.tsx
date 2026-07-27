import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { toast } from "sonner";
import {
  reviewPlatforms,
  reviewRequestStatuses,
  issueCategories,
  issueStatuses,
  reviewRequestMessage,
  type ReviewPlatform,
  type ReviewRequestStatus,
  type IssueCategory,
  type IssueStatus,
} from "@/lib/mock-data";
import { Star, Sparkles } from "lucide-react";

export const Route = createFileRoute("/reviews")({
  head: () => ({ meta: [{ title: "Reviews & Aftercare · Little Moments OS" }] }),
  component: ReviewsPage,
});

function ReviewsPage() {
  const { bookings, reviews, upsertReview } = useStore();
  const [openId, setOpenId] = useState<string | null>(null);
  const eligible = bookings.filter((b) => ["Delivered", "Album/Frame Pending", "Completed"].includes(b.status));

  const handle = (bookingId: string, patch: Parameters<typeof upsertReview>[1]) => {
    const r = upsertReview(bookingId, patch);
    if (r.ok) toast.success(r.message);
    else toast.error(r.message);
  };

  return (
    <AppShell>
      <PageHeader
        eyebrow="Phase 7 · Reviews & Reputation"
        title="Reviews & Aftercare"
        subtitle="Every delivery is followed by a warm request — never pressure. Track reviews, testimonials, and the milestones still waiting to be honoured."
        quote="A review is the family's thank-you. We treat it as a gift, not a goal."
      />

      <Card className="p-5 mb-6 bg-[var(--gradient-warm)] border-0">
        <div className="flex items-start gap-3">
          <Sparkles className="h-4 w-4 text-gold mt-1 shrink-0" />
          <div>
            <div className="text-[11px] uppercase tracking-wider text-muted-foreground">Warm review request message</div>
            <p className="mt-2 text-sm italic text-primary/85 leading-relaxed">“{reviewRequestMessage}”</p>
          </div>
        </div>
      </Card>

      {eligible.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">No deliveries waiting for a review yet.</p>
          <p className="mt-2 text-sm italic text-primary/70">Stories will be ready soon — and so will our gratitude.</p>
        </Card>
      ) : (
        <div className="space-y-4">
          {eligible.map((b) => {
            const r = reviews.find((x) => x.bookingId === b.id);
            const open = openId === b.id;
            return (
              <Card key={b.id} className="p-5">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <div className="font-medium text-primary">{b.client}</div>
                    <div className="text-xs text-muted-foreground">{b.category} · {b.id} · {b.date}</div>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    <StatusPill tone={r?.requestStatus === "Received" ? "good" : r?.requestStatus === "Requested" ? "gold" : "warn"}>
                      {r?.requestStatus ?? "Pending"}
                    </StatusPill>
                    {r?.rating && (
                      <StatusPill tone="gold"><Star className="h-3 w-3 inline mr-0.5" />{r.rating}/5</StatusPill>
                    )}
                    {r?.issueRaised && <StatusPill tone="bad">Issue: {r.issueStatus ?? "Open"}</StatusPill>}
                  </div>
                  <div className="flex gap-2">
                    <button
                      onClick={() => handle(b.id, { requestStatus: "Requested" })}
                      className="text-xs px-3 py-1.5 rounded-lg border border-gold bg-card text-primary hover:bg-accent"
                    >Send request</button>
                    <button
                      onClick={() => setOpenId(open ? null : b.id)}
                      className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground hover:opacity-90"
                    >{open ? "Close" : "Open"}</button>
                  </div>
                </div>
                {open && (
                  <div className="mt-5 grid md:grid-cols-2 gap-4 text-sm">
                    <Field label="Request status">
                      <select
                        value={r?.requestStatus ?? "Pending"}
                        onChange={(e) => handle(b.id, { requestStatus: e.target.value as ReviewRequestStatus })}
                        className="input"
                      >
                        {reviewRequestStatuses.map((s) => <option key={s}>{s}</option>)}
                      </select>
                    </Field>
                    <Field label="Platform">
                      <select
                        value={r?.platform ?? ""}
                        onChange={(e) => handle(b.id, { platform: (e.target.value || undefined) as ReviewPlatform | undefined })}
                        className="input"
                      >
                        <option value="">—</option>
                        {reviewPlatforms.map((p) => <option key={p}>{p}</option>)}
                      </select>
                    </Field>
                    <Field label="Rating (1–5)">
                      <input
                        type="number" min={1} max={5}
                        defaultValue={r?.rating ?? ""}
                        onBlur={(e) => handle(b.id, { rating: e.target.value ? Number(e.target.value) : undefined })}
                        className="input"
                      />
                    </Field>
                    <Field label="Permission to use testimonial">
                      <label className="inline-flex items-center gap-2 text-sm">
                        <input
                          type="checkbox"
                          defaultChecked={r?.permissionToUse ?? false}
                          onChange={(e) => handle(b.id, { permissionToUse: e.target.checked })}
                        />
                        Yes — written permission on file
                      </label>
                    </Field>
                    <Field label="Testimonial text" full>
                      <textarea
                        defaultValue={r?.testimonial ?? ""}
                        onBlur={(e) => handle(b.id, { testimonial: e.target.value })}
                        rows={3}
                        className="input"
                      />
                    </Field>
                    <Field label="Consent proof reference">
                      <input
                        defaultValue={r?.consentProof ?? ""}
                        onBlur={(e) => handle(b.id, { consentProof: e.target.value })}
                        className="input" placeholder="WhatsApp screenshot ref / email"
                      />
                    </Field>
                    <Field label="Issue raised?">
                      <label className="inline-flex items-center gap-2 text-sm">
                        <input
                          type="checkbox"
                          defaultChecked={r?.issueRaised ?? false}
                          onChange={(e) => handle(b.id, { issueRaised: e.target.checked })}
                        />
                        Family raised a concern
                      </label>
                    </Field>
                    {r?.issueRaised && (
                      <>
                        <Field label="Issue category">
                          <select
                            defaultValue={r?.issueCategory ?? ""}
                            onChange={(e) => handle(b.id, { issueCategory: (e.target.value || undefined) as IssueCategory | undefined })}
                            className="input"
                          >
                            <option value="">—</option>
                            {issueCategories.map((c) => <option key={c}>{c}</option>)}
                          </select>
                        </Field>
                        <Field label="Issue status">
                          <select
                            defaultValue={r?.issueStatus ?? "Open"}
                            onChange={(e) => handle(b.id, { issueStatus: e.target.value as IssueStatus })}
                            className="input"
                          >
                            {issueStatuses.map((s) => <option key={s}>{s}</option>)}
                          </select>
                        </Field>
                        <Field label="Resolution notes" full>
                          <textarea
                            defaultValue={r?.resolutionNotes ?? ""}
                            onBlur={(e) => handle(b.id, { resolutionNotes: e.target.value })}
                            rows={2} className="input"
                          />
                        </Field>
                      </>
                    )}
                    <Field label="Repeat milestone opportunity?">
                      <label className="inline-flex items-center gap-2 text-sm">
                        <input
                          type="checkbox"
                          defaultChecked={r?.repeatOpportunity ?? false}
                          onChange={(e) => handle(b.id, { repeatOpportunity: e.target.checked })}
                        />
                        Yes — invite back for next milestone
                      </label>
                    </Field>
                    <Field label="Next milestone reminder date">
                      <input
                        type="date"
                        defaultValue={r?.nextMilestoneDate ?? ""}
                        onBlur={(e) => handle(b.id, { nextMilestoneDate: e.target.value })}
                        className="input"
                      />
                    </Field>
                  </div>
                )}
              </Card>
            );
          })}
        </div>
      )}
    </AppShell>
  );
}

function Field({ label, children, full = false }: { label: string; children: React.ReactNode; full?: boolean }) {
  return (
    <label className={`block ${full ? "md:col-span-2" : ""}`}>
      <span className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</span>
      <div className="mt-1.5">{children}</div>
      <style>{`.input{width:100%;border:1px solid var(--border);border-radius:0.5rem;background:var(--card);padding:0.5rem 0.75rem;font-size:0.875rem;color:var(--foreground);}`}</style>
    </label>
  );
}