import { createFileRoute } from "@tanstack/react-router";
import { Link } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import {
  bookings,
  leads,
  philosophyScore,
  todayShoots,
  privacyRecords,
  editingJobs,
  heirloomJobs,
} from "@/lib/mock-data";
import { CalendarHeart, Heart, ShieldCheck, ClipboardCheck, Image as ImageIcon, Frame, MessageCircle, Clock, AlertCircle, Star } from "lucide-react";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Philosophy Command Center · Little Moments OS" },
      { name: "description", content: "Internal operating system for Little Shots by Hema — preserving family memories with care, trust, and heirloom value." },
    ],
  }),
  component: Index,
});

function Index() {
  const newInquiries = leads.filter((l) => l.status === "New Inquiry").length;
  const followUps = leads.filter((l) => l.status === "Follow-Up Needed" || l.status === "Contacted").length;
  const pendingBookings = bookings.filter((b) => b.status === "Tentative" || b.status === "Advance Pending").length;
  const pendingPrivacy = bookings.filter((b) => !privacyRecords.find((p) => p.booking === b.id)).length;
  const pendingSafety = bookings.filter((b) => b.safety === "Pending").length;
  const editingDue = editingJobs.filter((e) => e.status !== "Delivered").length;
  const heirloomPending = heirloomJobs.filter((h) => !h.delivered).length;
  const delayed = 1;
  const reviewRequests = 3;

  const tiles = [
    { label: "Today's shoots", value: todayShoots.length, icon: CalendarHeart, to: "/bookings", tone: "gold" as const },
    { label: "New inquiries", value: newInquiries, icon: Heart, to: "/leads", tone: "good" as const },
    { label: "Pending follow-ups", value: followUps, icon: MessageCircle, to: "/leads", tone: "warn" as const },
    { label: "Pending bookings", value: pendingBookings, icon: Clock, to: "/bookings", tone: "warn" as const },
    { label: "Pending privacy consents", value: pendingPrivacy, icon: ShieldCheck, to: "/privacy", tone: "bad" as const },
    { label: "Pending safety checklists", value: pendingSafety, icon: ClipboardCheck, to: "/safety", tone: "bad" as const },
    { label: "Editing deadlines", value: editingDue, icon: ImageIcon, to: "/editing", tone: "warn" as const },
    { label: "Album / frame pending", value: heirloomPending, icon: Frame, to: "/heirloom", tone: "warn" as const },
    { label: "Delayed deliveries", value: delayed, icon: AlertCircle, to: "/editing", tone: "bad" as const },
    { label: "Review requests", value: reviewRequests, icon: Star, to: "/kpi", tone: "gold" as const },
  ];

  return (
    <AppShell>
      <PageHeader
        eyebrow="Today · Monday, 25 May 2026"
        title="Philosophy Command Center"
        subtitle="A calm overview of every moment we are protecting today."
        quote="Every task today protects a memory that will matter forever."
      />

      <section className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-4 mb-10">
        {tiles.map(({ label, value, icon: Icon, to, tone }) => (
          <Link key={label} to={to}>
            <Card className="p-5 h-full hover:-translate-y-0.5 transition-transform">
              <div className="flex items-start justify-between">
                <div>
                  <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                    {label}
                  </div>
                  <div className="mt-2 font-serif text-3xl text-primary">{value}</div>
                </div>
                <span className={`rounded-full p-2 ${tone === "gold" ? "bg-[oklch(0.93_0.07_80)]" : tone === "good" ? "bg-[oklch(0.92_0.05_150)]" : tone === "bad" ? "bg-[oklch(0.92_0.06_25)]" : "bg-muted"}`}>
                  <Icon className="h-4 w-4 text-primary/70" />
                </span>
              </div>
            </Card>
          </Link>
        ))}
      </section>

      <section className="grid lg:grid-cols-3 gap-6">
        <Card className="p-6 lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-serif text-xl text-primary">Today's shoots</h2>
            <Link to="/bookings" className="text-xs text-muted-foreground hover:text-primary">View all →</Link>
          </div>
          {todayShoots.length === 0 ? (
            <p className="text-sm text-muted-foreground">A quiet day. Use it to protect tomorrow's memories.</p>
          ) : (
            <ul className="divide-y divide-border">
              {todayShoots.map((b) => (
                <li key={b.id} className="py-4 flex flex-col sm:flex-row sm:items-center gap-2">
                  <div className="flex-1">
                    <div className="font-medium text-primary">{b.client}</div>
                    <div className="text-xs text-muted-foreground">{b.category} · {b.locationType} · {b.locationDetails}</div>
                  </div>
                  <div className="text-sm text-muted-foreground">{b.date.split(" ")[1]}</div>
                  <div className="flex gap-1.5">
                    <StatusPill tone={b.safety === "Completed" ? "good" : "bad"}>Safety: {b.safety}</StatusPill>
                    <StatusPill tone="gold">{b.photographer}</StatusPill>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="p-6 bg-[var(--gradient-warm)] border-0">
          <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
            Monthly Philosophy Alignment
          </div>
          <div className="mt-3 flex items-end gap-2">
            <span className="font-serif text-6xl text-primary leading-none">{philosophyScore}</span>
            <span className="text-sm text-muted-foreground mb-2">/ 100</span>
          </div>
          <div className="mt-4 h-2 rounded-full bg-card overflow-hidden">
            <div className="h-full bg-[var(--gradient-gold)]" style={{ width: `${philosophyScore}%` }} />
          </div>
          <p className="mt-5 text-sm italic text-primary/80 leading-relaxed">
            “We are protecting memories with care this month. Two safety checklists and one consent recording were missed — let's bring it to 100.”
          </p>
        </Card>
      </section>
    </AppShell>
  );
}
