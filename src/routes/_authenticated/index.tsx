import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { visibleNav } from "@/lib/access";
import { getFounderBookingStageKpis, getFounderKpiSummary } from "@/lib/kpi.functions";
import { useSession } from "@/lib/session";

export const Route = createFileRoute("/_authenticated/")({
  head: () => ({
    meta: [
      { title: "Studio Control Room · Little Moments OS" },
      {
        name: "description",
        content: "Canonical operating rooms for Little Shots by Hema.",
      },
      {
        property: "og:title",
        content: "Studio Control Room · Little Moments OS",
      },
      {
        property: "og:description",
        content: "Because these little moments become everything.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Index,
});

const canonicalRoomPaths = new Set([
  "/leads",
  "/guide-reviews",
  "/clients",
  "/memory",
  "/packages",
  "/quote",
  "/bookings",
  "/pipeline",
  "/whatsapp",
]);

const canonicalStageLabels = [
  "New Inquiry",
  "Details Collected",
  "Memory Goal Captured",
  "Package Recommended",
  "Quote Sent",
  "Follow-Up Pending",
  "Advance Pending",
  "Booking Confirmed",
  "Pre-Shoot Preparation",
  "Shoot Scheduled",
  "Shoot Completed",
  "Selection Pending",
  "Editing Pending",
  "Editing in Progress",
  "QC Pending",
  "Pixieset Gallery Ready",
  "Delivered",
  "Album / Frame Production",
  "Review Requested",
  "Milestone Follow-Up",
  "Completed / Relationship Active",
] as const;

const inrFormatter = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

function formatInr(value: number) {
  return inrFormatter.format(value);
}

function formatRate(value: number | null) {
  if (value === null) return "—";

  return `${value.toLocaleString("en-IN", {
    maximumFractionDigits: 1,
  })}%`;
}

function formatStageAge(seconds: number | null) {
  if (seconds === null) return "—";

  const totalHours = Math.max(0, Math.round(seconds / 3600));

  if (totalHours < 24) {
    return `${totalHours}h`;
  }

  const days = Math.floor(totalHours / 24);
  const hours = totalHours % 24;

  return hours === 0 ? `${days}d` : `${days}d ${hours}h`;
}

function formatReportingDate(value: string) {
  return new Date(value).toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

function Index() {
  const { roles } = useSession();
  const isFounder = roles.includes("founder");

  const rooms = visibleNav(roles).filter((item) => canonicalRoomPaths.has(item.to));

  const reportingWindow = useMemo(() => {
    const periodEnd = new Date();
    const periodStart = new Date(periodEnd.getTime() - 30 * 24 * 60 * 60 * 1000);

    return {
      periodStart: periodStart.toISOString(),
      periodEnd: periodEnd.toISOString(),
    };
  }, []);

  const founderSummary = useQuery({
    queryKey: ["founder-kpi-summary", reportingWindow.periodStart, reportingWindow.periodEnd],
    queryFn: () =>
      getFounderKpiSummary({
        data: {
          periodStart: reportingWindow.periodStart,
          periodEnd: reportingWindow.periodEnd,
        },
      }),
    enabled: isFounder,
    retry: 1,
  });

  const founderStages = useQuery({
    queryKey: ["founder-booking-stage-kpis", reportingWindow.periodEnd],
    queryFn: () =>
      getFounderBookingStageKpis({
        data: {
          asOf: reportingWindow.periodEnd,
        },
      }),
    enabled: isFounder,
    retry: 1,
  });

  const founderKpisLoading = founderSummary.isPending || founderStages.isPending;

  const founderKpisFailed = founderSummary.isError || founderStages.isError;

  const summary = founderSummary.data;
  const stages = founderStages.data ?? [];

  return (
    <AppShell>
      <PageHeader
        eyebrow="Little Shots Studio OS"
        title="Studio Control Room"
        subtitle="A calm starting point for the studio records that are connected to the canonical operating system."
        quote="Because these little moments become everything."
      />

      <Card className="mb-8 bg-[var(--gradient-warm)] p-6">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Current operating boundary
        </div>

        <h2 className="mt-2 font-serif text-xl text-primary">Canonical records only</h2>

        <p className="mt-3 max-w-3xl text-sm leading-relaxed text-muted-foreground">
          Packages, quotations, bookings, advance-payment evidence, and the family journey now use
          the rebuilt studio records. Later workflow rooms remain unavailable until they are
          connected to the same source of truth.
        </p>

        <p className="mt-3 max-w-3xl text-xs leading-relaxed text-muted-foreground">
          Founder commercial and booking indicators are shown only to authorized Founders and are
          read from the canonical database. Safety, consent, editing, delivery, review, and
          production indicators are not calculated from legacy demonstration data.
        </p>
      </Card>

      {isFounder && (
        <section className="mb-10">
          <div className="mb-4">
            <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
              Founder view
            </div>
            <h2 className="mt-1 font-serif text-2xl text-primary">Canonical studio indicators</h2>
            <p className="mt-2 max-w-3xl text-sm leading-relaxed text-muted-foreground">
              Organization-wide commercial, booking, and advance-payment indicators from the
              canonical studio records.
            </p>
          </div>

          {founderKpisLoading && (
            <Card className="p-6">
              <p className="text-sm text-muted-foreground">
                Gathering the current studio indicators…
              </p>
            </Card>
          )}

          {founderKpisFailed && !founderKpisLoading && (
            <Card className="p-6">
              <div className="font-serif text-lg text-primary">
                Studio indicators are temporarily unavailable
              </div>
              <p className="mt-2 max-w-2xl text-sm leading-relaxed text-muted-foreground">
                The canonical KPI read could not be completed. No fallback or demonstration values
                are being shown.
              </p>
            </Card>
          )}

          {summary && !founderKpisFailed && (
            <>
              <Card className="mb-4 p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
                      Reporting period
                    </div>
                    <div className="mt-1 text-sm font-medium text-primary">
                      {formatReportingDate(summary.period_start)} —{" "}
                      {formatReportingDate(summary.period_end)}
                    </div>
                  </div>

                  <div className="text-xs text-muted-foreground">Organization-wide</div>
                </div>
              </Card>

              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                {[
                  {
                    label: "New Inquiries",
                    value: summary.new_inquiries_count,
                  },
                  {
                    label: "Quotations Sent",
                    value: summary.quotations_sent_count,
                  },
                  {
                    label: "Quotations Accepted",
                    value: summary.quotations_accepted_count,
                  },
                  {
                    label: "Bookings Created",
                    value: summary.bookings_created_count,
                  },
                  {
                    label: "Bookings Confirmed",
                    value: summary.bookings_confirmed_count,
                  },
                  {
                    label: "Advance Pending",
                    value: summary.advance_pending_stage_as_of_end_count,
                  },
                  {
                    label: "Booking Confirmed Stage",
                    value: summary.booking_confirmed_stage_as_of_end_count,
                  },
                  {
                    label: "Advance Satisfied",
                    value: summary.advance_satisfied_bookings_as_of_end_count,
                  },
                ].map((item) => (
                  <Card key={item.label} className="p-5">
                    <div className="text-xs text-muted-foreground">{item.label}</div>
                    <div className="mt-2 font-serif text-3xl text-primary">
                      {item.value.toLocaleString("en-IN")}
                    </div>
                  </Card>
                ))}
              </div>

              <div className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                {[
                  {
                    label: "Quoted Value",
                    value: formatInr(summary.quoted_value_inr),
                  },
                  {
                    label: "Accepted Value",
                    value: formatInr(summary.accepted_value_inr),
                  },
                  {
                    label: "Payments Collected",
                    value: formatInr(summary.payments_collected_inr),
                  },
                  {
                    label: "Required Advance",
                    value: formatInr(summary.required_advance_as_of_end_inr),
                  },
                  {
                    label: "Valid Collected",
                    value: formatInr(summary.valid_collected_as_of_end_inr),
                  },
                  {
                    label: "Outstanding Advance",
                    value: formatInr(summary.advance_outstanding_as_of_end_inr),
                  },
                ].map((item) => (
                  <Card key={item.label} className="p-5">
                    <div className="text-xs text-muted-foreground">{item.label}</div>
                    <div className="mt-2 font-serif text-2xl text-primary">{item.value}</div>
                  </Card>
                ))}
              </div>

              <div className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                {[
                  {
                    label: "Sent Quote → Accepted",
                    value: formatRate(summary.sent_quote_acceptance_rate_pct),
                  },
                  {
                    label: "Inquiry → Accepted Quote",
                    value: formatRate(summary.inquiry_to_accepted_quote_rate_pct),
                  },
                  {
                    label: "Accepted Quote → Booking",
                    value: formatRate(summary.accepted_quote_to_booking_rate_pct),
                  },
                  {
                    label: "Booking → Confirmed",
                    value: formatRate(summary.booking_to_confirmed_rate_pct),
                  },
                ].map((item) => (
                  <Card key={item.label} className="p-5">
                    <div className="text-xs text-muted-foreground">{item.label}</div>
                    <div className="mt-2 font-serif text-2xl text-primary">{item.value}</div>
                  </Card>
                ))}
              </div>

              {summary.confirmed_with_advance_shortfall_as_of_end_count > 0 && (
                <Card className="mt-4 p-5">
                  <div className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
                    Payment attention
                  </div>
                  <div className="mt-2 font-serif text-xl text-primary">
                    {summary.confirmed_with_advance_shortfall_as_of_end_count} confirmed booking
                    {summary.confirmed_with_advance_shortfall_as_of_end_count === 1 ? "" : "s"}{" "}
                    currently below the required advance.
                  </div>
                  <p className="mt-2 text-xs leading-relaxed text-muted-foreground">
                    Historical booking confirmation is preserved. This indicator reflects the
                    current valid collection position after payment reversals.
                  </p>
                </Card>
              )}

              <div className="mt-8">
                <div className="mb-4">
                  <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
                    Journey snapshot
                  </div>
                  <h3 className="mt-1 font-serif text-xl text-primary">Booking stages</h3>
                  <p className="mt-2 text-sm text-muted-foreground">
                    Current booking position across the canonical 21-stage journey as of the
                    reporting-period end.
                  </p>
                </div>

                <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                  {stages.map((stage) => {
                    const stageLabel =
                      canonicalStageLabels[stage.stage_order - 1] ?? stage.stage_key;

                    return (
                      <Card key={stage.stage_key} className="p-4">
                        <div className="flex items-start justify-between gap-4">
                          <div>
                            <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
                              Stage {String(stage.stage_order).padStart(2, "0")}
                            </div>
                            <div className="mt-1 font-serif text-base text-primary">
                              {stageLabel}
                            </div>
                          </div>

                          <div className="font-serif text-2xl text-primary">
                            {stage.booking_count.toLocaleString("en-IN")}
                          </div>
                        </div>

                        <div className="mt-3 grid grid-cols-2 gap-3 border-t border-border pt-3 text-xs">
                          <div>
                            <div className="text-muted-foreground">Average age</div>
                            <div className="mt-0.5 text-primary">
                              {formatStageAge(stage.average_stage_age_seconds)}
                            </div>
                          </div>
                          <div>
                            <div className="text-muted-foreground">Oldest age</div>
                            <div className="mt-0.5 text-primary">
                              {formatStageAge(stage.oldest_stage_age_seconds)}
                            </div>
                          </div>
                        </div>
                      </Card>
                    );
                  })}
                </div>
              </div>
            </>
          )}
        </section>
      )}

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {rooms.map(({ to, label, icon: Icon }) => (
          <Link key={to} to={to}>
            <Card className="h-full p-5 transition-transform hover:-translate-y-0.5">
              <div className="flex items-start gap-4">
                <div className="rounded-full bg-accent p-2.5">
                  <Icon className="h-4 w-4 text-primary" />
                </div>

                <div>
                  <div className="font-serif text-lg text-primary">{label}</div>
                  <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                    Open the current studio record.
                  </p>
                </div>
              </div>
            </Card>
          </Link>
        ))}
      </section>
    </AppShell>
  );
}
