import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";
import {
  pixiesetGalleryStatuses,
  pixiesetOrderStatuses,
  pixiesetPriceSheets,
  type PixiesetGalleryStatus,
  type PixiesetOrderStatus,
  type PixiesetPriceSheet,
} from "@/lib/mock-data";
import type { PixiesetRecord } from "@/store/useStore";
import { Camera, Save, ExternalLink } from "lucide-react";

export const Route = createFileRoute("/_authenticated/pixieset")({
  head: () => ({ meta: [{ title: "Pixieset Control · Little Moments OS" }] }),
  component: PixiesetPage,
});

function PixiesetPage() {
  const bookings = useStore((s) => s.bookings);
  const pixieset = useStore((s) => s.pixieset);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Gallery & store"
        title="Pixieset Control Center"
        subtitle="Manual + semi-automated tracker for every Pixieset gallery, favourite, and order."
        quote="A gallery is the first place the family sees what we protected for them."
      />

      <div className="space-y-5">
        {bookings.length === 0 && (
          <Card className="p-10 text-center">
            <p className="font-serif text-xl text-primary">No bookings yet.</p>
          </Card>
        )}
        {bookings.map((b) => {
          const rec = pixieset.find((p) => p.bookingId === b.id);
          return <PixiesetForm key={b.id} bookingId={b.id} client={b.client} category={b.category} rec={rec} />;
        })}
      </div>
    </AppShell>
  );
}

function PixiesetForm({
  bookingId,
  client,
  category,
  rec,
}: {
  bookingId: string;
  client: string;
  category: string;
  rec?: PixiesetRecord;
}) {
  const upsert = useStore((s) => s.upsertPixieset);
  const [d, setD] = useState({
    pixiesetClientName: rec?.pixiesetClientName ?? client,
    collectionName: rec?.collectionName ?? `${client} — ${category}`,
    galleryLink: rec?.galleryLink ?? "",
    password: rec?.password ?? "",
    galleryStatus: rec?.galleryStatus ?? ("Not Created" as PixiesetGalleryStatus),
    watermark: rec?.watermark ?? ("Not Needed" as const),
    favoritesEnabled: rec?.favoritesEnabled ?? true,
    favoritesStatus: rec?.favoritesStatus ?? ("Pending" as const),
    downloadEnabled: rec?.downloadEnabled ?? false,
    downloadExpiry: rec?.downloadExpiry ?? "",
    storeEnabled: rec?.storeEnabled ?? false,
    priceSheet: rec?.priceSheet ?? ("None" as PixiesetPriceSheet),
    invoiceLink: rec?.invoiceLink ?? "",
    contractLink: rec?.contractLink ?? "",
    orderStatus: rec?.orderStatus ?? ("No Order" as PixiesetOrderStatus),
    syncNotes: rec?.syncNotes ?? "",
  });
  const set = <K extends keyof typeof d>(k: K, v: (typeof d)[K]) =>
    setD((s) => ({ ...s, [k]: v }));

  return (
    <Card className="p-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            {bookingId} · {category}
          </div>
          <h3 className="font-serif text-xl text-primary mt-1 flex items-center gap-2">
            <Camera className="h-4 w-4 text-gold" /> {client}
          </h3>
        </div>
        <div className="flex flex-wrap gap-1.5">
          <StatusPill tone={d.galleryStatus === "Delivered" ? "good" : d.galleryStatus === "Not Created" ? "bad" : "warn"}>
            Gallery: {d.galleryStatus}
          </StatusPill>
          <StatusPill tone={d.orderStatus === "Fulfilled" || d.orderStatus === "Paid" ? "good" : "neutral"}>
            Order: {d.orderStatus}
          </StatusPill>
          {d.galleryLink && (
            <a
              href={d.galleryLink}
              target="_blank"
              rel="noreferrer"
              className="text-[11px] inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-card border border-gold text-primary"
            >
              Open <ExternalLink className="h-3 w-3" />
            </a>
          )}
        </div>
      </div>

      <div className="mt-4 grid sm:grid-cols-2 gap-3">
        <L label="Pixieset client name">
          <I v={d.pixiesetClientName} on={(v) => set("pixiesetClientName", v)} />
        </L>
        <L label="Collection name">
          <I v={d.collectionName} on={(v) => set("collectionName", v)} />
        </L>
        <L label="Gallery link">
          <I v={d.galleryLink} on={(v) => set("galleryLink", v)} placeholder="https://littleshots.pixieset.com/..." />
        </L>
        <L label="Password / PIN">
          <I v={d.password} on={(v) => set("password", v)} />
        </L>
        <L label="Gallery status">
          <Sel v={d.galleryStatus} on={(v) => set("galleryStatus", v as PixiesetGalleryStatus)} opts={[...pixiesetGalleryStatuses]} />
        </L>
        <L label="Watermark">
          <Sel v={d.watermark} on={(v) => set("watermark", v as "Applied" | "Not Needed")} opts={["Applied", "Not Needed"]} />
        </L>
        <L label="Favorites enabled">
          <Sel v={d.favoritesEnabled ? "Yes" : "No"} on={(v) => set("favoritesEnabled", v === "Yes")} opts={["Yes", "No"]} />
        </L>
        <L label="Client favorites status">
          <Sel v={d.favoritesStatus} on={(v) => set("favoritesStatus", v as "Pending" | "Received")} opts={["Pending", "Received"]} />
        </L>
        <L label="Download enabled">
          <Sel v={d.downloadEnabled ? "Yes" : "No"} on={(v) => set("downloadEnabled", v === "Yes")} opts={["Yes", "No"]} />
        </L>
        <L label="Download expiry">
          <I type="date" v={d.downloadExpiry} on={(v) => set("downloadExpiry", v)} />
        </L>
        <L label="Store enabled">
          <Sel v={d.storeEnabled ? "Yes" : "No"} on={(v) => set("storeEnabled", v === "Yes")} opts={["Yes", "No"]} />
        </L>
        <L label="Price sheet applied">
          <Sel v={d.priceSheet} on={(v) => set("priceSheet", v as PixiesetPriceSheet)} opts={[...pixiesetPriceSheets]} />
        </L>
        <L label="Invoice link">
          <I v={d.invoiceLink} on={(v) => set("invoiceLink", v)} />
        </L>
        <L label="Contract link">
          <I v={d.contractLink} on={(v) => set("contractLink", v)} />
        </L>
        <L label="Order status">
          <Sel v={d.orderStatus} on={(v) => set("orderStatus", v as PixiesetOrderStatus)} opts={[...pixiesetOrderStatuses]} />
        </L>
      </div>

      <L label="Manual sync notes" className="mt-3">
        <textarea
          value={d.syncNotes}
          onChange={(e) => set("syncNotes", e.target.value)}
          rows={2}
          maxLength={500}
          className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
        />
      </L>

      <div className="mt-4 flex justify-end">
        <button
          onClick={() => handle(upsert(bookingId, d))}
          className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground"
        >
          <Save className="h-3 w-3" /> Save Pixieset record
        </button>
      </div>
    </Card>
  );
}

function L({ label, children, className = "" }: { label: string; children: React.ReactNode; className?: string }) {
  return (
    <label className={`block ${className}`}>
      <span className="block text-[10px] uppercase tracking-wider text-muted-foreground mb-1">{label}</span>
      {children}
    </label>
  );
}
function I({ v, on, type = "text", placeholder }: { v: string; on: (v: string) => void; type?: string; placeholder?: string }) {
  return (
    <input
      type={type}
      value={v}
      placeholder={placeholder}
      maxLength={300}
      onChange={(e) => on(e.target.value)}
      className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
    />
  );
}
function Sel({ v, on, opts }: { v: string; on: (v: string) => void; opts: string[] }) {
  return (
    <select value={v} onChange={(e) => on(e.target.value)} className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary">
      {opts.map((o) => <option key={o}>{o}</option>)}
    </select>
  );
}