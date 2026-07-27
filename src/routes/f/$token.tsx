import { createFileRoute, useLoaderData } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";
import { useServerFn } from "@tanstack/react-start";
import { getClientLink, submitClientResponse } from "@/lib/client-links.functions";

export const Route = createFileRoute("/f/$token")({
  loader: ({ params }) => getClientLink({ data: { token: params.token } }),
  head: () => ({
    meta: [
      { title: "Your session with Little Shots by Hema" },
      {
        name: "description",
        content:
          "A private page from Little Shots by Hema — your session details, consent and delivery, all in one warm place.",
      },
      { property: "og:title", content: "Your session with Little Shots by Hema" },
      {
        property: "og:description",
        content: "Because these little moments become everything.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ClientLinkPage,
  errorComponent: () => <Shell title="This link couldn't be opened">Please ask the studio for a fresh link.</Shell>,
  notFoundComponent: () => <Shell title="Link not found">Please ask the studio for a fresh link.</Shell>,
});

function Shell({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-[var(--gradient-warm)] flex items-center justify-center px-5 py-16">
      <div className="w-full max-w-lg rounded-2xl border border-border bg-card p-8 shadow-[var(--shadow-soft)]">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Little Shots by Hema
        </div>
        <h1 className="mt-2 font-serif text-3xl text-primary leading-tight">{title}</h1>
        <div className="mt-5 text-sm text-foreground/90 leading-relaxed">{children}</div>
        <p className="mt-8 border-t border-border pt-5 text-center text-xs italic text-muted-foreground">
          “Because these little moments become everything.”
        </p>
      </div>
    </div>
  );
}

function str(payload: Record<string, unknown>, key: string, fallback = "") {
  const v = payload[key];
  return typeof v === "string" || typeof v === "number" ? String(v) : fallback;
}

function ClientLinkPage() {
  const link = useLoaderData({ from: "/f/$token" });
  const submit = useServerFn(submitClientResponse);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState("");
  const [name, setName] = useState("");
  const [agreed, setAgreed] = useState(false);
  const [marketing, setMarketing] = useState(false);
  const [rating, setRating] = useState(5);

  if (!link) return <Shell title="Link not found">Please ask the studio for a fresh link.</Shell>;
  if (link.expired)
    return <Shell title="This link has gently expired">Message the studio and we'll send a new one right away.</Shell>;

  const payload = link.payload as Record<string, unknown>;
  const family = str(payload, "client", "Dear family");

  const send = async (body: Record<string, string | boolean | number>) => {
    setBusy(true);
    try {
      await submit({ data: { token: link.token, payload: body } });
      setDone(true);
      toast.success("Thank you — the studio has your response.");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  };

  if (done || link.responded) {
    return (
      <Shell title="Thank you">
        We have your response safely. Hema and the team will be in touch shortly.
      </Shell>
    );
  }

  if (link.kind === "proposal") {
    return (
      <Shell title={`A session made for you, ${family}`}>
        <dl className="space-y-3">
          <Row label="Recommended package" value={str(payload, "package", "—")} />
          <Row label="Session" value={str(payload, "category", "—")} />
          <Row label="Investment" value={str(payload, "price", "—")} />
          <Row label="What's included" value={str(payload, "inclusions", "—")} />
        </dl>
        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          rows={3}
          placeholder="Anything you'd love us to know?"
          className="mt-5 w-full rounded-lg border border-border bg-background px-3 py-2 text-sm"
        />
        <button
          disabled={busy}
          onClick={() => void send({ accepted: true, note })}
          className="mt-4 w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
        >
          Yes — I'd love this session
        </button>
      </Shell>
    );
  }

  if (link.kind === "consent") {
    return (
      <Shell title="Your privacy, your choice">
        <p>
          Your photographs belong to your family first. Nothing is ever shared publicly without your
          written permission — and you can change your mind at any time.
        </p>
        <label className="mt-5 flex items-start gap-2 text-sm">
          <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} className="mt-1" />
          <span>I consent to Little Shots by Hema photographing and editing our session.</span>
        </label>
        <label className="mt-3 flex items-start gap-2 text-sm">
          <input type="checkbox" checked={marketing} onChange={(e) => setMarketing(e.target.checked)} className="mt-1" />
          <span>You may also share selected images on your website and social channels.</span>
        </label>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Type your full name to sign"
          className="mt-5 w-full rounded-lg border border-border bg-background px-3 py-2 text-sm"
        />
        <button
          disabled={busy || !agreed || name.trim().length < 2}
          onClick={() => void send({ consent: true, marketingConsent: marketing, signedBy: name })}
          className="mt-4 w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
        >
          Sign and send
        </button>
      </Shell>
    );
  }

  return (
    <Shell title="Your story is ready">
      <dl className="space-y-3">
        <Row label="Gallery" value={str(payload, "galleryLink", "Your gallery link will arrive shortly")} />
        <Row label="Gallery password" value={str(payload, "galleryPassword", "—")} />
        <Row label="Album / frame" value={str(payload, "heirloomStatus", "—")} />
      </dl>
      <p className="mt-5">If these images made you feel something, we'd be so grateful to hear it.</p>
      <div className="mt-3 flex gap-2">
        {[1, 2, 3, 4, 5].map((n) => (
          <button
            key={n}
            onClick={() => setRating(n)}
            className={`h-9 w-9 rounded-full border text-sm ${
              rating >= n ? "border-gold bg-accent text-primary" : "border-border text-muted-foreground"
            }`}
          >
            {n}
          </button>
        ))}
      </div>
      <textarea
        value={note}
        onChange={(e) => setNote(e.target.value)}
        rows={3}
        placeholder="Your words (optional)"
        className="mt-4 w-full rounded-lg border border-border bg-background px-3 py-2 text-sm"
      />
      <button
        disabled={busy}
        onClick={() => void send({ rating, testimonial: note })}
        className="mt-4 w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
      >
        Send to the studio
      </button>
    </Shell>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-wrap justify-between gap-2 border-b border-border pb-2">
      <dt className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</dt>
      <dd className="text-sm text-primary text-right max-w-[60%]">{value}</dd>
    </div>
  );
}