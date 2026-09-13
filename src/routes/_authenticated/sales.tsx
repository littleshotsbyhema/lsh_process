import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";

import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { availableModuleLinks } from "@/lib/access";
import { listLeads, type LeadStatus } from "@/lib/leads.functions";

export const Route = createFileRoute("/_authenticated/sales")({
  head: () => ({
    meta: [
      { title: "Sales · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Where every enquiry stands, from first message through to an accepted quotation and a confirmed booking.",
      },
      { property: "og:title", content: "Sales · LittleShots by Hema OS" },
    ],
  }),
  component: SalesPage,
});

/**
 * The studio thinks in four sales stages — Enquiry, Hot Lead, Advance
 * Requested, Booked — and any of the first three can be archived instead.
 *
 * The database records a finer `lead_status`, so each studio stage is a
 * group of lead statuses. A booking does not exist until a quotation has
 * been accepted, which is why "Booked" here counts converted enquiries
 * rather than reading the bookings table.
 */
type SalesStage = {
  key: string;
  label: string;
  blurb: string;
  statuses: LeadStatus[];
  tone: "neutral" | "good" | "warn" | "gold";
};

const SALES_STAGES: SalesStage[] = [
  {
    key: "enquiry",
    label: "Enquiry",
    blurb: "A family has been in touch and someone is getting back to them.",
    statuses: ["new_inquiry", "contacted"],
    tone: "neutral",
  },
  {
    key: "hot_lead",
    label: "Hot Lead",
    blurb: "The session is understood and a quotation is being prepared or chased.",
    statuses: ["qualified", "consultation_scheduled", "quote_ready", "follow_up_needed"],
    tone: "gold",
  },
  {
    key: "advance_requested",
    label: "Advance Requested",
    blurb: "The quotation is with the family and we are waiting on their yes.",
    statuses: ["quote_sent"],
    tone: "warn",
  },
  {
    key: "booked",
    label: "Booked",
    blurb: "The quotation was accepted and the family now has a booking.",
    statuses: ["converted"],
    tone: "good",
  },
];

const CLOSED_STATUSES: LeadStatus[] = ["lost", "archived"];

function SalesPage() {
  const query = useQuery({
    queryKey: ["leads"],
    queryFn: () => listLeads(),
  });

  const leads = useMemo(() => query.data ?? [], [query.data]);

  const counts = useMemo(() => {
    const byStatus = new Map<string, number>();
    for (const lead of leads) {
      byStatus.set(lead.status, (byStatus.get(lead.status) ?? 0) + 1);
    }

    const total = (statuses: LeadStatus[]) =>
      statuses.reduce((sum, status) => sum + (byStatus.get(status) ?? 0), 0);

    return {
      stages: SALES_STAGES.map((stage) => ({ ...stage, count: total(stage.statuses) })),
      lost: byStatus.get("lost") ?? 0,
      archived: byStatus.get("archived") ?? 0,
      open: leads.length - total(CLOSED_STATUSES) - total(["converted"]),
    };
  }, [leads]);

  const links = availableModuleLinks("/sales");

  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio operations"
        title="Sales"
        subtitle="Everything from a family's first message through to an accepted quotation and a confirmed booking."
        quote="An enquiry is a family hoping we will look after something they cannot repeat."
      />

      <Card className="mb-8 p-6">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Where enquiries stand
        </div>

        <p className="mt-2 max-w-3xl text-sm leading-relaxed text-muted-foreground">
          Enquiry, then Hot Lead, then Advance Requested, then Booked. Any of the first three can be
          archived instead. A booking only exists once a quotation has been accepted.
        </p>

        {query.isLoading && (
          <p className="mt-4 text-sm text-muted-foreground">Opening the studio records…</p>
        )}

        {query.isError && (
          <p className="mt-4 text-sm text-muted-foreground">
            The enquiry records could not be read just now, so no counts are shown. Nothing is
            estimated in their place.
          </p>
        )}

        {query.data && (
          <>
            <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              {counts.stages.map((stage) => (
                <div key={stage.key} className="rounded-xl border border-border p-4">
                  <div className="flex items-start justify-between gap-3">
                    <StatusPill tone={stage.tone}>{stage.label}</StatusPill>
                    <div className="font-serif text-3xl leading-none text-primary">
                      {stage.count}
                    </div>
                  </div>
                  <p className="mt-3 text-xs leading-relaxed text-muted-foreground">{stage.blurb}</p>
                </div>
              ))}
            </div>

            <div className="mt-4 flex flex-wrap gap-x-6 gap-y-1 text-xs text-muted-foreground">
              <span>{counts.open} still open before a booking</span>
              <span>{counts.lost} closed as lost</span>
              <span>{counts.archived} archived</span>
            </div>
          </>
        )}
      </Card>

      <section>
        <div className="mb-4">
          <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
            Screens in this module
          </div>
          <h2 className="mt-1 font-serif text-2xl text-primary">Where the work is done</h2>
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          {links.map((link) => (
            <Link key={link.to} to={link.to}>
              <Card className="h-full p-5 transition-transform hover:-translate-y-0.5">
                <div className="font-serif text-lg text-primary">{link.label}</div>
                <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                  {link.description}
                </p>
              </Card>
            </Link>
          ))}
        </div>
      </section>
    </AppShell>
  );
}
