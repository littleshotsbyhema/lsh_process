import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/clients")({
  head: () => ({
    meta: [
      { title: "Clients · Little Moments OS" },
      {
        name: "description",
        content:
          "Every family we care for, their bookings, milestones and long-term relationship history.",
      },
      { property: "og:title", content: "Clients · Little Moments OS" },
      {
        property: "og:description",
        content:
          "Every family we care for, their bookings, milestones and long-term relationship history.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ClientsPage,
});

const ORGANIZATION_ID = "590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc";

type FamilyRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  family_code: string;
  display_name: string;
  sort_name: string;
  status: string;
  assigned_owner_member_id: string | null;
  created_at: string;
  updated_at: string;
};

const db = supabase as unknown as {
  from: (table: string) => any;
};

function ClientsPage() {
  const [families, setFamilies] = useState<FamilyRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    const loadFamilies = async () => {
      setLoading(true);
      setError(null);

      const { data, error: queryError } = await db
        .from("families")
        .select(
          [
            "id",
            "organization_id",
            "branch_id",
            "family_code",
            "display_name",
            "sort_name",
            "status",
            "assigned_owner_member_id",
            "created_at",
            "updated_at",
          ].join(","),
        )
        .eq("organization_id", ORGANIZATION_ID)
        .order("sort_name", { ascending: true });

      if (!active) return;

      if (queryError) {
        console.error("[families] load failed", queryError);
        setFamilies([]);
        setError(queryError.message ?? "Could not load family records.");
        setLoading(false);
        return;
      }

      setFamilies((data ?? []) as FamilyRow[]);
      setLoading(false);
    };

    void loadFamilies();

    return () => {
      active = false;
    };
  }, []);

  return (
    <AppShell>
      <PageHeader
        eyebrow="Families"
        title="Clients"
        subtitle="Families we are walking with — across pregnancy, newborn, milestones, and beyond."
        quote="A client is not a booking. It is a relationship that can last a generation."
      />

      {loading && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">Opening the family records…</p>
          <p className="text-sm text-muted-foreground mt-2">
            Gathering the families entrusted to the studio.
          </p>
        </Card>
      )}

      {!loading && error && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">
            We couldn&apos;t open the family records
          </p>
          <p className="text-sm text-muted-foreground mt-2">{error}</p>
        </Card>
      )}

      {!loading && !error && (
        <div className="grid lg:grid-cols-2 gap-5">
          {families.map((family) => (
            <Card key={family.id} className="p-6">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                    {family.family_code}
                  </div>

                  <h3 className="font-serif text-xl text-primary mt-1">
                    {family.display_name}
                  </h3>
                </div>

                <StatusPill tone={family.status === "active" ? "gold" : "muted"}>
                  {family.status}
                </StatusPill>
              </div>

              <div className="mt-5 grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                <Field label="Family code" value={family.family_code} />
                <Field label="Status" value={family.status} />
                <Field
                  label="Created"
                  value={formatDate(family.created_at)}
                />
                <Field
                  label="Last updated"
                  value={formatDate(family.updated_at)}
                />
              </div>

              <div className="mt-5 pt-4 border-t border-border">
                <p className="text-xs text-muted-foreground leading-relaxed">
                  Contact details, family members, children, notes, milestones and booking
                  history will appear here as their rebuilt modules are connected.
                </p>
              </div>
            </Card>
          ))}

          {families.length === 0 && (
            <Card className="p-10 text-center col-span-full">
              <p className="font-serif text-xl text-primary">No families yet.</p>
              <p className="text-sm text-muted-foreground mt-2">
                New family records will appear here once they are created in the rebuilt
                family system.
              </p>
            </Card>
          )}
        </div>
      )}
    </AppShell>
  );
}

function Field({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
        {label}
      </div>
      <div className="text-primary mt-0.5">{value || "—"}</div>
    </div>
  );
}

function formatDate(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "—";
  }

  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);
}