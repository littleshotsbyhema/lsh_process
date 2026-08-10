import { createFileRoute } from "@tanstack/react-router";
import { useCallback, useEffect, useState, type FormEvent } from "react";
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
  const [loadError, setLoadError] = useState<string | null>(null);

  const [showCreate, setShowCreate] = useState(false);
  const [showArchived, setShowArchived] = useState(false);

  const [displayName, setDisplayName] = useState("");
  const [sortName, setSortName] = useState("");
  const [creating, setCreating] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);
  const [createSuccess, setCreateSuccess] = useState<string | null>(null);

  const [changingFamilyId, setChangingFamilyId] = useState<string | null>(null);
  const [lifecycleError, setLifecycleError] = useState<string | null>(null);
  const [lifecycleSuccess, setLifecycleSuccess] = useState<string | null>(null);

  const loadFamilies = useCallback(async () => {
    setLoading(true);
    setLoadError(null);

    const { data, error } = await db
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

    if (error) {
      console.error("[families] load failed", error);
      setFamilies([]);
      setLoadError(error.message ?? "Could not load family records.");
      setLoading(false);
      return;
    }

    setFamilies((data ?? []) as FamilyRow[]);
    setLoading(false);
  }, []);

  useEffect(() => {
    void loadFamilies();
  }, [loadFamilies]);

  const currentFamilies = families.filter(
    (family) => family.status !== "archived" && family.status !== "merged",
  );

  const archivedFamilies = families.filter(
    (family) => family.status === "archived",
  );

  const mergedFamilies = families.filter(
    (family) => family.status === "merged",
  );

  const clearMessages = () => {
    setCreateError(null);
    setCreateSuccess(null);
    setLifecycleError(null);
    setLifecycleSuccess(null);
  };

  const submitCreateFamily = async (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();

    const cleanDisplayName = displayName.trim();
    const cleanSortName = sortName.trim();

    if (!cleanDisplayName) {
      setCreateError("Family name is required.");
      return;
    }

    if (!cleanSortName) {
      setCreateError("Sort name is required.");
      return;
    }

    setCreating(true);
    clearMessages();

    const { data, error } = await supabase.rpc("create_family", {
      p_organization_id: ORGANIZATION_ID,
      p_display_name: cleanDisplayName,
      p_sort_name: cleanSortName,
      p_branch_id: null,
      p_assigned_owner_member_id: null,
    });

    if (error) {
      console.error("[families] create_family failed", error);
      setCreateError(error.message ?? "Could not create family.");
      setCreating(false);
      return;
    }

    const created = data as FamilyRow | FamilyRow[] | null;
    const createdFamily = Array.isArray(created) ? created[0] : created;

    setCreateSuccess(
      createdFamily?.family_code
        ? `Family created successfully · ${createdFamily.family_code}`
        : "Family created successfully.",
    );

    setDisplayName("");
    setSortName("");
    setCreating(false);

    await loadFamilies();
  };

  const archiveFamily = async (family: FamilyRow) => {
    const confirmed = window.confirm(
      `Archive ${family.display_name}?\n\nThe family record will remain preserved and can be reactivated later.`,
    );

    if (!confirmed) {
      return;
    }

    setChangingFamilyId(family.id);
    clearMessages();

    const { error } = await db
      .from("families")
      .update({
        status: "archived",
      })
      .eq("id", family.id)
      .eq("organization_id", ORGANIZATION_ID);

    if (error) {
      console.error("[families] archive failed", error);
      setLifecycleError(error.message ?? "Could not archive family.");
      setChangingFamilyId(null);
      return;
    }

    setLifecycleSuccess(
      `${family.display_name} archived successfully.`,
    );

    setChangingFamilyId(null);
    await loadFamilies();
  };

  const reactivateFamily = async (family: FamilyRow) => {
    const confirmed = window.confirm(
      `Reactivate ${family.display_name}?\n\nThe family will return to the active client list.`,
    );

    if (!confirmed) {
      return;
    }

    setChangingFamilyId(family.id);
    clearMessages();

    const { error } = await db
      .from("families")
      .update({
        status: "active",
      })
      .eq("id", family.id)
      .eq("organization_id", ORGANIZATION_ID);

    if (error) {
      console.error("[families] reactivate failed", error);
      setLifecycleError(error.message ?? "Could not reactivate family.");
      setChangingFamilyId(null);
      return;
    }

    setLifecycleSuccess(
      `${family.display_name} reactivated successfully.`,
    );

    setChangingFamilyId(null);
    await loadFamilies();
  };

  return (
    <AppShell>
      <PageHeader
        eyebrow="Families"
        title="Clients"
        subtitle="Families we are walking with — across pregnancy, newborn, milestones, and beyond."
        quote="A client is not a booking. It is a relationship that can last a generation."
      />

      <div className="mb-5 flex flex-wrap items-center gap-3">
        <button
          type="button"
          onClick={() => {
            setShowCreate((current) => !current);
            clearMessages();
          }}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
        >
          {showCreate ? "Close form" : "Create family"}
        </button>

        <span className="text-xs text-muted-foreground">
          New families are created through the controlled family workflow.
        </span>
      </div>

      {showCreate && (
        <Card className="mb-6 max-w-2xl p-6">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
              New family
            </div>

            <h2 className="mt-1 font-serif text-2xl text-primary">
              Begin a family record
            </h2>

            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
              Create the household record first. Contact details, family
              members, children, notes and milestones will be added through
              their dedicated modules.
            </p>
          </div>

          <form
            onSubmit={submitCreateFamily}
            className="mt-6 space-y-4"
          >
            <label className="block">
              <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Family display name
              </span>

              <input
                type="text"
                value={displayName}
                onChange={(event) => {
                  const value = event.target.value;
                  setDisplayName(value);

                  if (!sortName) {
                    setSortName(value);
                  }
                }}
                placeholder="Example: Mehta Family"
                required
                maxLength={160}
                className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary outline-none focus:ring-1 focus:ring-primary"
              />
            </label>

            <label className="block">
              <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Sort name
              </span>

              <input
                type="text"
                value={sortName}
                onChange={(event) =>
                  setSortName(event.target.value)
                }
                placeholder="Example: Mehta Family"
                required
                maxLength={160}
                className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary outline-none focus:ring-1 focus:ring-primary"
              />

              <span className="mt-1 block text-xs text-muted-foreground">
                Used to alphabetize the family list.
              </span>
            </label>

            {createError && (
              <div className="rounded-lg border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
                {createError}
              </div>
            )}

            {createSuccess && (
              <div className="rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary">
                {createSuccess}
              </div>
            )}

            <button
              type="submit"
              disabled={creating}
              className="rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
            >
              {creating ? "Creating family…" : "Create family"}
            </button>
          </form>
        </Card>
      )}

      {lifecycleError && (
        <Card className="mb-5 border-destructive/30 p-4">
          <p className="text-sm text-destructive">
            {lifecycleError}
          </p>
        </Card>
      )}

      {lifecycleSuccess && (
        <Card className="mb-5 p-4">
          <p className="text-sm text-primary">
            {lifecycleSuccess}
          </p>
        </Card>
      )}

      {loading && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">
            Opening the family records…
          </p>

          <p className="mt-2 text-sm text-muted-foreground">
            Gathering the families entrusted to the studio.
          </p>
        </Card>
      )}

      {!loading && loadError && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">
            We couldn&apos;t open the family records
          </p>

          <p className="mt-2 text-sm text-muted-foreground">
            {loadError}
          </p>
        </Card>
      )}

      {!loading && !loadError && (
        <>
          <section>
            <div className="mb-4 flex items-end justify-between gap-4">
              <div>
                <div className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
                  Current families
                </div>

                <h2 className="mt-1 font-serif text-2xl text-primary">
                  Families in our care
                </h2>
              </div>

              <div className="text-xs text-muted-foreground">
                {currentFamilies.length}{" "}
                {currentFamilies.length === 1 ? "family" : "families"}
              </div>
            </div>

            {currentFamilies.length > 0 ? (
              <div className="grid gap-5 lg:grid-cols-2">
                {currentFamilies.map((family) => (
                  <FamilyCard
                    key={family.id}
                    family={family}
                    busy={changingFamilyId === family.id}
                    onArchive={archiveFamily}
                  />
                ))}
              </div>
            ) : (
              <Card className="p-10 text-center">
                <p className="font-serif text-xl text-primary">
                  No active families yet.
                </p>

                <p className="mt-2 text-sm text-muted-foreground">
                  Create a family above to begin a new relationship record.
                </p>
              </Card>
            )}
          </section>

          <section className="mt-8">
            <button
              type="button"
              onClick={() =>
                setShowArchived((current) => !current)
              }
              className="flex w-full items-center justify-between rounded-xl border border-border bg-card px-5 py-4 text-left hover:bg-muted/40"
            >
              <div>
                <div className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
                  Historical records
                </div>

                <div className="mt-1 font-serif text-xl text-primary">
                  Archived families
                </div>
              </div>

              <div className="flex items-center gap-3">
                <span className="text-xs text-muted-foreground">
                  {archivedFamilies.length}
                </span>

                <span className="text-sm text-primary">
                  {showArchived ? "Hide" : "View"}
                </span>
              </div>
            </button>

            {showArchived && (
              <div className="mt-5">
                {archivedFamilies.length > 0 ? (
                  <div className="grid gap-5 lg:grid-cols-2">
                    {archivedFamilies.map((family) => (
                      <ArchivedFamilyCard
                        key={family.id}
                        family={family}
                        busy={changingFamilyId === family.id}
                        onReactivate={reactivateFamily}
                      />
                    ))}
                  </div>
                ) : (
                  <Card className="p-8 text-center">
                    <p className="font-serif text-lg text-primary">
                      No archived families.
                    </p>

                    <p className="mt-2 text-sm text-muted-foreground">
                      Archived family records will remain preserved here.
                    </p>
                  </Card>
                )}
              </div>
            )}
          </section>

          {mergedFamilies.length > 0 && (
            <section className="mt-8">
              <div className="mb-4">
                <div className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
                  Protected history
                </div>

                <h2 className="mt-1 font-serif text-xl text-primary">
                  Merged family records
                </h2>

                <p className="mt-1 text-xs text-muted-foreground">
                  Merged records are terminal and retained for historical
                  continuity.
                </p>
              </div>

              <div className="grid gap-5 lg:grid-cols-2">
                {mergedFamilies.map((family) => (
                  <MergedFamilyCard
                    key={family.id}
                    family={family}
                  />
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </AppShell>
  );
}

function FamilyCard({
  family,
  busy,
  onArchive,
}: {
  family: FamilyRow;
  busy: boolean;
  onArchive: (family: FamilyRow) => Promise<void>;
}) {
  return (
    <Card className="p-6">
      <FamilyHeader family={family} />

      <FamilyDetails family={family} />

      <div className="mt-5 border-t border-border pt-4">
        <p className="text-xs leading-relaxed text-muted-foreground">
          Contact details, family members, children, notes, milestones and
          booking history will appear here as their rebuilt modules are
          connected.
        </p>
      </div>

      <div className="mt-4 border-t border-border pt-4">
        <button
          type="button"
          onClick={() => void onArchive(family)}
          disabled={busy}
          className="rounded-lg border border-border bg-card px-3 py-1.5 text-xs font-medium text-primary hover:bg-muted disabled:opacity-60"
        >
          {busy ? "Archiving…" : "Archive family"}
        </button>
      </div>
    </Card>
  );
}

function ArchivedFamilyCard({
  family,
  busy,
  onReactivate,
}: {
  family: FamilyRow;
  busy: boolean;
  onReactivate: (family: FamilyRow) => Promise<void>;
}) {
  return (
    <Card className="p-6">
      <FamilyHeader family={family} />

      <FamilyDetails family={family} />

      <div className="mt-5 border-t border-border pt-4">
        <p className="text-xs italic leading-relaxed text-muted-foreground">
          This family is archived. Its history has been preserved.
        </p>
      </div>

      <div className="mt-4 border-t border-border pt-4">
        <button
          type="button"
          onClick={() => void onReactivate(family)}
          disabled={busy}
          className="rounded-lg border border-border bg-card px-3 py-1.5 text-xs font-medium text-primary hover:bg-muted disabled:opacity-60"
        >
          {busy ? "Reactivating…" : "Reactivate family"}
        </button>
      </div>
    </Card>
  );
}

function MergedFamilyCard({
  family,
}: {
  family: FamilyRow;
}) {
  return (
    <Card className="p-6">
      <FamilyHeader family={family} />

      <FamilyDetails family={family} />

      <div className="mt-5 border-t border-border pt-4">
        <p className="text-xs italic leading-relaxed text-muted-foreground">
          This family record has been merged and is preserved as terminal
          history.
        </p>
      </div>
    </Card>
  );
}

function FamilyHeader({
  family,
}: {
  family: FamilyRow;
}) {
  return (
    <div className="flex items-start justify-between gap-4">
      <div>
        <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
          {family.family_code}
        </div>

        <h3 className="mt-1 font-serif text-xl text-primary">
          {family.display_name}
        </h3>
      </div>

      <StatusPill tone={family.status === "active" ? "gold" : "muted"}>
        {family.status}
      </StatusPill>
    </div>
  );
}

function FamilyDetails({
  family,
}: {
  family: FamilyRow;
}) {
  return (
    <div className="mt-5 grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
      <Field
        label="Family code"
        value={family.family_code}
      />

      <Field
        label="Status"
        value={family.status}
      />

      <Field
        label="Created"
        value={formatDate(family.created_at)}
      />

      <Field
        label="Last updated"
        value={formatDate(family.updated_at)}
      />
    </div>
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

      <div className="mt-0.5 text-primary">
        {value || "—"}
      </div>
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