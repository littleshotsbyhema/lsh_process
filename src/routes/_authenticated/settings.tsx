import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/settings")({
  head: () => ({ meta: [{ title: "Settings · Little Moments OS" }] }),
  component: SettingsPage,
});

function SettingsPage() {
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