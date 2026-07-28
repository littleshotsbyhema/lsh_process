import { createFileRoute } from "@tanstack/react-router";
import { Check, Minus } from "lucide-react";
import { AppShell, Card, PageHeader } from "@/components/AppShell";
import { useSession, roleLabels } from "@/lib/session";
import { can, permissions, visibleNav, type Action } from "@/lib/access";

export const Route = createFileRoute("/_authenticated/settings")({
  head: () => ({
    meta: [
      { title: "Settings · Little Moments OS" },
      {
        name: "description",
        content: "Studio preferences, philosophy statements and workspace configuration.",
      },
      { property: "og:title", content: "Settings · Little Moments OS" },
      {
        property: "og:description",
        content: "Studio preferences, philosophy statements and workspace configuration.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SettingsPage,
});

function SettingsPage() {
  const { roles } = useSession();
  const rooms = visibleNav(roles);
  const actions = Object.keys(permissions) as Action[];
  return (
    <AppShell>
      <PageHeader
        eyebrow="Studio Settings"
        title="Settings"
        subtitle="Preferences, defaults, and the rules of this house."
        quote="The way we work, written down — so care stays consistent."
      />
      <div className="grid lg:grid-cols-2 gap-6">
        <Card className="p-6 space-y-3">
          <h2 className="font-serif text-lg text-primary">Studio identity</h2>
          <Row label="Studio">Little Shots by Hema</Row>
          <Row label="Founder">Hema</Row>
          <Row label="Operating philosophy">“Because these little moments become everything.”</Row>
        </Card>
        <Card className="p-6 space-y-3">
          <h2 className="font-serif text-lg text-primary">Defaults</h2>
          <Row label="Currency">INR (₹)</Row>
          <Row label="Delivery window">10–14 days</Row>
          <Row label="Review request">After delivery, with gentle pacing</Row>
          <Row label="Privacy default">Full Privacy — until consent recorded</Row>
        </Card>
      </div>

      <Card className="mt-6 p-6">
        <h2 className="font-serif text-lg text-primary">Your access</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Signed in as {roles.length ? roles.map((r) => roleLabels[r]).join(" · ") : "Role pending"}
          . This is exactly what you can open and change.
        </p>

        <div className="mt-5">
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            Rooms you can open
          </div>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {rooms.map((r) => (
              <span
                key={r.to}
                className="rounded-full border border-gold/70 bg-accent/50 px-2.5 py-1 text-[11px] text-primary"
              >
                {r.label}
              </span>
            ))}
          </div>
        </div>

        <div className="mt-6">
          <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
            What you can change
          </div>
          <ul className="mt-2 grid sm:grid-cols-2 gap-x-6">
            {actions.map((a) => {
              const allowed = can(a, roles);
              return (
                <li
                  key={a}
                  className="flex items-start gap-2 border-b border-border/60 py-2 text-sm last:border-0"
                >
                  {allowed ? (
                    <Check className="mt-0.5 h-3.5 w-3.5 shrink-0 text-gold" />
                  ) : (
                    <Minus className="mt-0.5 h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                  )}
                  <span className={allowed ? "text-foreground/85" : "text-muted-foreground"}>
                    {permissions[a].label}
                  </span>
                </li>
              );
            })}
          </ul>
        </div>
      </Card>
    </AppShell>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-3 text-sm border-b border-border/60 pb-2 last:border-0">
      <span className="text-muted-foreground">{label}</span>
      <span className="text-right text-foreground/85">{children}</span>
    </div>
  );
}
