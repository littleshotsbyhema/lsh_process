import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState, type FormEvent } from "react";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/clients")({
  head: () => ({
    meta: [
      { title: "Clients · Little Moments OS" },
      {
        name: "description",
        content: "Families, relationships, contact channels and communication preferences.",
      },
      {
        property: "og:title",
        content: "Clients · Little Moments OS",
      },
      {
        property: "og:description",
        content: "Families, relationships, contact channels and communication preferences.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ClientsPage,
});

const ORGANIZATION_ID = "590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc";

const FAMILY_QUERY_KEY = ["families", ORGANIZATION_ID] as const;

type AccessibleBranchOption = {
  branch_id: string;
  branch_name: string;
  branch_code: string;
};

type BranchAccessResult = {
  mode: "legacy" | "catalogue";
  branches: AccessibleBranchOption[];
};

function isMissingAccessibleBranchCatalogueRpc(
  error: { code?: string; message?: string } | null,
): boolean {
  if (!error) return false;

  return (
    error.code === "PGRST202" ||
    (error.message?.includes("Could not find the function") === true &&
      error.message.includes("accessible_branch_catalogue"))
  );
}

async function loadAccessibleBranches(): Promise<BranchAccessResult> {
  const { data, error } = await supabase.rpc("accessible_branch_catalogue", {
    p_organization_id: ORGANIZATION_ID,
  });

  if (error) {
    if (isMissingAccessibleBranchCatalogueRpc(error)) {
      return { mode: "legacy", branches: [] };
    }

    throw new Error(error.message);
  }

  return {
    mode: "catalogue",
    branches: (data ?? []) as AccessibleBranchOption[],
  };
}

type FamilyStatus = "active" | "inactive" | "archived" | "merged";

type ContactChannelType = "phone" | "email" | "whatsapp" | "other";

type ContactabilityStatus = "contactable" | "limited" | "do_not_contact";

type ChildStage = "expected" | "newborn" | "baby" | "sitter" | "toddler" | "child";

type ChildStatus = "active" | "archived";

type PrivacyPreferenceType =
  "full_privacy" | "selective_sharing" | "anonymous_sharing" | "portfolio_release" | "decide_later";

type ChildRow = {
  id: string;
  organization_id: string;
  family_id: string;
  child_reference: string;
  first_name: string | null;
  birth_date: string | null;
  expected_due_date: string | null;
  current_stage: ChildStage | null;
  privacy_restriction: PrivacyPreferenceType | null;
  status: ChildStatus;
  created_at: string;
  updated_at: string;
  archived_at: string | null;
};

type MemoryProfileRow = {
  id: string;
  organization_id: string;
  family_id: string;
  child_id: string | null;
  memory_goal: string | null;
  story_notes: string | null;
  emotional_tags: string[];
  milestone_notes: string | null;
  future_memory_notes: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  archived_at: string | null;
};

type FamilyRow = {
  id: string;
  organization_id: string;
  branch_id: string | null;
  family_code: string;
  display_name: string;
  sort_name: string;
  status: FamilyStatus;
  assigned_owner_member_id: string | null;
  created_at: string;
  updated_at: string;
};

type FamilyContactRow = {
  id: string;
  organization_id: string;
  family_id: string;
  full_name: string;
  relationship_label: string;
  is_primary: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deactivated_at: string | null;
};

type FamilyContactChannelRow = {
  id: string;
  organization_id: string;
  family_contact_id: string;
  channel_type: ContactChannelType;
  channel_value: string;
  normalized_value: string;
  is_preferred: boolean;
  is_verified: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deactivated_at: string | null;
};

type FamilyCommunicationControlRow = {
  id: string;
  organization_id: string;
  family_id: string;
  contactability_status: ContactabilityStatus;
  preferred_channel_type: ContactChannelType | null;
  do_not_contact: boolean;
  do_not_contact_reason: string | null;
  quiet_hours_start: string | null;
  quiet_hours_end: string | null;
  timezone: string;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

type FamilyRecord = FamilyRow & {
  contacts: Array<
    FamilyContactRow & {
      channels: FamilyContactChannelRow[];
    }
  >;

  communicationControls: FamilyCommunicationControlRow | null;

  children: Array<
    ChildRow & {
      memoryProfile: MemoryProfileRow | null;
    }
  >;

  familyMemoryProfile: MemoryProfileRow | null;
};

const db = supabase as any;

async function fetchFamilies(): Promise<FamilyRecord[]> {
  const [
    familiesResult,
    contactsResult,
    channelsResult,
    controlsResult,
    childrenResult,
    memoryProfilesResult,
  ] = await Promise.all([
    db
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
      .order("sort_name", { ascending: true }),

    db
      .from("family_contacts")
      .select(
        [
          "id",
          "organization_id",
          "family_id",
          "full_name",
          "relationship_label",
          "is_primary",
          "is_active",
          "created_at",
          "updated_at",
          "deactivated_at",
        ].join(","),
      )
      .eq("organization_id", ORGANIZATION_ID)
      .order("is_primary", { ascending: false })
      .order("full_name", { ascending: true }),

    db
      .from("family_contact_channels")
      .select(
        [
          "id",
          "organization_id",
          "family_contact_id",
          "channel_type",
          "channel_value",
          "normalized_value",
          "is_preferred",
          "is_verified",
          "is_active",
          "created_at",
          "updated_at",
          "deactivated_at",
        ].join(","),
      )
      .eq("organization_id", ORGANIZATION_ID)
      .order("is_preferred", { ascending: false })
      .order("channel_type", { ascending: true }),

    db
      .from("family_communication_controls")
      .select(
        [
          "id",
          "organization_id",
          "family_id",
          "contactability_status",
          "preferred_channel_type",
          "do_not_contact",
          "do_not_contact_reason",
          "quiet_hours_start",
          "quiet_hours_end",
          "timezone",
          "notes",
          "created_at",
          "updated_at",
        ].join(","),
      )
      .eq("organization_id", ORGANIZATION_ID),

    db
      .from("children")
      .select(
        [
          "id",
          "organization_id",
          "family_id",
          "child_reference",
          "first_name",
          "birth_date",
          "expected_due_date",
          "current_stage",
          "privacy_restriction",
          "status",
          "created_at",
          "updated_at",
          "archived_at",
        ].join(","),
      )
      .eq("organization_id", ORGANIZATION_ID)
      .order("created_at", { ascending: true }),

    db
      .from("memory_profiles")
      .select(
        [
          "id",
          "organization_id",
          "family_id",
          "child_id",
          "memory_goal",
          "story_notes",
          "emotional_tags",
          "milestone_notes",
          "future_memory_notes",
          "is_active",
          "created_at",
          "updated_at",
          "archived_at",
        ].join(","),
      )
      .eq("organization_id", ORGANIZATION_ID)
      .eq("is_active", true)
      .order("created_at", { ascending: true }),
  ]);

  if (familiesResult.error) {
    throw new Error(familiesResult.error.message ?? "Could not load family records.");
  }

  if (contactsResult.error) {
    throw new Error(contactsResult.error.message ?? "Could not load family contacts.");
  }

  if (channelsResult.error) {
    throw new Error(channelsResult.error.message ?? "Could not load family contact channels.");
  }

  if (controlsResult.error) {
    throw new Error(
      controlsResult.error.message ?? "Could not load family communication controls.",
    );
  }

  if (childrenResult.error) {
    throw new Error(childrenResult.error.message ?? "Could not load child records.");
  }

  if (memoryProfilesResult.error) {
    throw new Error(memoryProfilesResult.error.message ?? "Could not load memory profiles.");
  }

  const families = (familiesResult.data ?? []) as FamilyRow[];

  const contacts = (contactsResult.data ?? []) as FamilyContactRow[];

  const channels = (channelsResult.data ?? []) as FamilyContactChannelRow[];

  const controls = (controlsResult.data ?? []) as FamilyCommunicationControlRow[];

  const children = (childrenResult.data ?? []) as ChildRow[];

  const memoryProfiles = (memoryProfilesResult.data ?? []) as MemoryProfileRow[];

  return families.map((family) => ({
    ...family,

    contacts: contacts
      .filter((contact) => contact.family_id === family.id)
      .map((contact) => ({
        ...contact,
        channels: channels.filter((channel) => channel.family_contact_id === contact.id),
      })),

    communicationControls: controls.find((control) => control.family_id === family.id) ?? null,

    children: children
      .filter((child) => child.family_id === family.id)
      .map((child) => ({
        ...child,

        memoryProfile:
          memoryProfiles.find(
            (profile) => profile.family_id === family.id && profile.child_id === child.id,
          ) ?? null,
      })),

    familyMemoryProfile:
      memoryProfiles.find(
        (profile) => profile.family_id === family.id && profile.child_id === null,
      ) ?? null,
  }));
}

function ClientsPage() {
  const queryClient = useQueryClient();

  const [showCreate, setShowCreate] = useState(false);
  const [showArchived, setShowArchived] = useState(false);

  const [displayName, setDisplayName] = useState("");
  const [sortName, setSortName] = useState("");
  const [createBranchId, setCreateBranchId] = useState("");

  const [createMessage, setCreateMessage] = useState<string | null>(null);

  const [lifecycleMessage, setLifecycleMessage] = useState<string | null>(null);

  const [lifecycleError, setLifecycleError] = useState<string | null>(null);

  const familiesQuery = useQuery({
    queryKey: FAMILY_QUERY_KEY,
    queryFn: fetchFamilies,
    staleTime: 5 * 60 * 1000,
    gcTime: 30 * 60 * 1000,
    refetchOnWindowFocus: false,
    retry: 1,
  });

  const branchAccessQuery = useQuery({
    queryKey: ["accessible-branches", ORGANIZATION_ID],
    queryFn: loadAccessibleBranches,
    retry: false,
  });

  const refreshFamilies = async () => {
    await queryClient.invalidateQueries({
      queryKey: FAMILY_QUERY_KEY,
    });
  };

  const createFamilyMutation = useMutation({
    mutationFn: async ({
      displayName,
      sortName,
      branchId,
    }: {
      displayName: string;
      sortName: string;
      branchId: string | null;
    }) => {
      const { data, error } = await db.rpc("create_family", {
        p_organization_id: ORGANIZATION_ID,
        p_display_name: displayName,
        p_sort_name: sortName,
        p_branch_id: branchId,
        p_assigned_owner_member_id: null,
      });

      if (error) {
        throw new Error(error.message ?? "Could not create family.");
      }

      const created = data as FamilyRow | FamilyRow[] | null;

      return Array.isArray(created) ? (created[0] ?? null) : created;
    },

    onSuccess: async (createdFamily) => {
      setCreateMessage(
        createdFamily?.family_code
          ? `Family created successfully · ${createdFamily.family_code}`
          : "Family created successfully.",
      );

      setDisplayName("");
      setSortName("");
      setCreateBranchId("");

      await refreshFamilies();
    },
  });

  const archiveFamilyMutation = useMutation({
    mutationFn: async (family: FamilyRecord) => {
      const { error } = await db
        .from("families")
        .update({ status: "archived" })
        .eq("id", family.id)
        .eq("organization_id", ORGANIZATION_ID);

      if (error) {
        throw new Error(error.message ?? "Could not archive family.");
      }

      return family;
    },

    onSuccess: async (family) => {
      setLifecycleError(null);
      setLifecycleMessage(`${family.display_name} archived successfully.`);

      await refreshFamilies();
    },

    onError: (error) => {
      setLifecycleMessage(null);
      setLifecycleError(getErrorMessage(error));
    },
  });

  const reactivateFamilyMutation = useMutation({
    mutationFn: async (family: FamilyRecord) => {
      const { error } = await db
        .from("families")
        .update({ status: "active" })
        .eq("id", family.id)
        .eq("organization_id", ORGANIZATION_ID);

      if (error) {
        throw new Error(error.message ?? "Could not reactivate family.");
      }

      return family;
    },

    onSuccess: async (family) => {
      setLifecycleError(null);
      setLifecycleMessage(`${family.display_name} reactivated successfully.`);

      await refreshFamilies();
    },

    onError: (error) => {
      setLifecycleMessage(null);
      setLifecycleError(getErrorMessage(error));
    },
  });

  const families = familiesQuery.data ?? [];

  const currentFamilies = families.filter(
    (family) => family.status !== "archived" && family.status !== "merged",
  );

  const archivedFamilies = families.filter((family) => family.status === "archived");

  const mergedFamilies = families.filter((family) => family.status === "merged");

  const clearMessages = () => {
    setCreateMessage(null);
    setLifecycleMessage(null);
    setLifecycleError(null);
  };

  const submitCreateFamily = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (branchAccessQuery.isPending) {
      setCreateMessage(null);
      setLifecycleError("Branch access is still loading. Try again in a moment.");
      return;
    }

    if (branchAccessQuery.isError) {
      setCreateMessage(null);
      setLifecycleError(
        branchAccessQuery.error instanceof Error
          ? branchAccessQuery.error.message
          : "Unable to resolve your authorized branches.",
      );
      return;
    }

    if (branchAccessQuery.data?.mode === "catalogue") {
      if (branchAccessQuery.data.branches.length === 0) {
        setCreateMessage(null);
        setLifecycleError(
          "No active branch is available in your current studio access.",
        );
        return;
      }

      if (!createBranchId) {
        setCreateMessage(null);
        setLifecycleError("Choose the branch that owns this family record.");
        return;
      }
    }

    const cleanDisplayName = displayName.trim();
    const cleanSortName = sortName.trim();

    if (!cleanDisplayName || !cleanSortName) {
      return;
    }

    clearMessages();

    try {
      await createFamilyMutation.mutateAsync({
        displayName: cleanDisplayName,
        sortName: cleanSortName,
        branchId:
          branchAccessQuery.data?.mode === "catalogue"
            ? createBranchId || null
            : null,
      });
    } catch {
      // Mutation state renders the error.
    }
  };

  const archiveFamily = (family: FamilyRecord) => {
    const confirmed = window.confirm(
      `Archive ${family.display_name}?\n\nThe family record and contact history will remain preserved and can be reactivated later.`,
    );

    if (!confirmed) {
      return;
    }

    clearMessages();
    archiveFamilyMutation.mutate(family);
  };

  const reactivateFamily = (family: FamilyRecord) => {
    const confirmed = window.confirm(
      `Reactivate ${family.display_name}?\n\nThe family will return to the active client list.`,
    );

    if (!confirmed) {
      return;
    }

    clearMessages();
    reactivateFamilyMutation.mutate(family);
  };

  const changingFamilyId = archiveFamilyMutation.isPending
    ? (archiveFamilyMutation.variables?.id ?? null)
    : reactivateFamilyMutation.isPending
      ? (reactivateFamilyMutation.variables?.id ?? null)
      : null;

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
          Family and contact information is protected by organisation permissions and audit
          controls.
        </span>

        {familiesQuery.isFetching && !familiesQuery.isPending && (
          <span className="text-xs italic text-muted-foreground">Refreshing…</span>
        )}
      </div>

      {showCreate && (
        <Card className="mb-6 max-w-2xl p-6">
          <div className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
            New family
          </div>

          <h2 className="mt-1 font-serif text-2xl text-primary">Begin a family record</h2>

          <form onSubmit={submitCreateFamily} className="mt-6 space-y-4">
            {branchAccessQuery.data?.mode === "catalogue" && (
              <label className="block text-sm text-primary">
                <span className="mb-1.5 block text-xs text-muted-foreground">
                  Branch *
                </span>
                <select
                  required
                  value={createBranchId}
                  onChange={(event) =>
                    setCreateBranchId(event.target.value)
                  }
                  disabled={branchAccessQuery.data.branches.length === 0}
                  className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary disabled:opacity-60"
                >
                  <option value="">Select an authorized branch</option>
                  {branchAccessQuery.data.branches.map((branch) => (
                    <option
                      key={branch.branch_id}
                      value={branch.branch_id}
                    >
                      {branch.branch_name}
                    </option>
                  ))}
                </select>
                <span className="mt-1 block text-[11px] text-muted-foreground">
                  Only branches available to your current studio membership are shown.
                </span>
              </label>
            )}

            <InputField
              label="Family display name"
              value={displayName}
              onChange={(value) => {
                setDisplayName(value);

                if (!sortName) {
                  setSortName(value);
                }
              }}
              placeholder="Example: Mehta Family"
            />

            <InputField
              label="Sort name"
              value={sortName}
              onChange={setSortName}
              placeholder="Example: Mehta Family"
            />

            {createFamilyMutation.isError && (
              <ErrorBox>{getErrorMessage(createFamilyMutation.error)}</ErrorBox>
            )}

            {createMessage && <SuccessBox>{createMessage}</SuccessBox>}

            <button
              type="submit"
              disabled={createFamilyMutation.isPending}
              className="rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground disabled:opacity-60"
            >
              {createFamilyMutation.isPending ? "Creating family…" : "Create family"}
            </button>
          </form>
        </Card>
      )}

      {lifecycleError && <ErrorBox className="mb-5">{lifecycleError}</ErrorBox>}

      {lifecycleMessage && <SuccessBox className="mb-5">{lifecycleMessage}</SuccessBox>}

      {familiesQuery.isPending && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">Opening the family records…</p>

          <p className="mt-2 text-sm text-muted-foreground">
            Gathering the families entrusted to the studio.
          </p>
        </Card>
      )}

      {!familiesQuery.isPending && familiesQuery.isError && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">
            We couldn&apos;t open the family records
          </p>

          <p className="mt-2 text-sm text-muted-foreground">
            {getErrorMessage(familiesQuery.error)}
          </p>

          <button
            type="button"
            onClick={() => void familiesQuery.refetch()}
            className="mt-4 rounded-lg border border-border px-3 py-2 text-xs text-primary"
          >
            Try again
          </button>
        </Card>
      )}

      {!familiesQuery.isPending && !familiesQuery.isError && (
        <>
          <section>
            <SectionHeading
              eyebrow="Current families"
              title="Families in our care"
              count={currentFamilies.length}
            />

            {currentFamilies.length > 0 ? (
              <div className="space-y-6">
                {currentFamilies.map((family) => (
                  <FamilyCard
                    key={family.id}
                    family={family}
                    busy={changingFamilyId === family.id}
                    onArchive={archiveFamily}
                    onRefresh={refreshFamilies}
                  />
                ))}
              </div>
            ) : (
              <Card className="p-10 text-center">
                <p className="font-serif text-xl text-primary">No active families yet.</p>

                <p className="mt-2 text-sm text-muted-foreground">
                  Create a family above to begin a new relationship record.
                </p>
              </Card>
            )}
          </section>

          <section className="mt-8">
            <button
              type="button"
              onClick={() => setShowArchived((current) => !current)}
              className="flex w-full items-center justify-between rounded-xl border border-border bg-card px-5 py-4 text-left hover:bg-muted/40"
            >
              <div>
                <div className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
                  Historical records
                </div>

                <div className="mt-1 font-serif text-xl text-primary">Archived families</div>
              </div>

              <div className="flex items-center gap-3">
                <span className="text-xs text-muted-foreground">{archivedFamilies.length}</span>

                <span className="text-sm text-primary">{showArchived ? "Hide" : "View"}</span>
              </div>
            </button>

            {showArchived && (
              <div className="mt-5 space-y-5">
                {archivedFamilies.length > 0 ? (
                  archivedFamilies.map((family) => (
                    <ArchivedFamilyCard
                      key={family.id}
                      family={family}
                      busy={changingFamilyId === family.id}
                      onReactivate={reactivateFamily}
                    />
                  ))
                ) : (
                  <Card className="p-8 text-center">
                    <p className="font-serif text-lg text-primary">No archived families.</p>
                  </Card>
                )}
              </div>
            )}
          </section>

          {mergedFamilies.length > 0 && (
            <section className="mt-8">
              <SectionHeading
                eyebrow="Protected history"
                title="Merged family records"
                count={mergedFamilies.length}
              />

              <div className="space-y-5">
                {mergedFamilies.map((family) => (
                  <HistoricalFamilyCard key={family.id} family={family} />
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
  onRefresh,
}: {
  family: FamilyRecord;
  busy: boolean;
  onArchive: (family: FamilyRecord) => void;
  onRefresh: () => Promise<void>;
}) {
  return (
    <Card className="p-6">
      <FamilyHeader family={family} />

      <FamilyDetails family={family} />

      <ChildrenMemorySection family={family} editable onRefresh={onRefresh} />

      <FamilyContactsSection family={family} editable onRefresh={onRefresh} />

      <CommunicationControlsSection family={family} editable onRefresh={onRefresh} />

      <div className="mt-6 border-t border-border pt-4">
        <button
          type="button"
          onClick={() => onArchive(family)}
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
  family: FamilyRecord;
  busy: boolean;
  onReactivate: (family: FamilyRecord) => void;
}) {
  return (
    <Card className="p-6">
      <FamilyHeader family={family} />
      <FamilyDetails family={family} />

      <ChildrenMemorySection family={family} editable={false} />

      <FamilyContactsSection family={family} editable={false} />

      <CommunicationControlsSection family={family} editable={false} />

      <div className="mt-5 border-t border-border pt-4">
        <p className="text-xs italic text-muted-foreground">
          This family is archived. Its relationship and communication history remains preserved.
        </p>

        <button
          type="button"
          onClick={() => onReactivate(family)}
          disabled={busy}
          className="mt-3 rounded-lg border border-border bg-card px-3 py-1.5 text-xs font-medium text-primary hover:bg-muted disabled:opacity-60"
        >
          {busy ? "Reactivating…" : "Reactivate family"}
        </button>
      </div>
    </Card>
  );
}

function HistoricalFamilyCard({ family }: { family: FamilyRecord }) {
  return (
    <Card className="p-6">
      <FamilyHeader family={family} />
      <FamilyDetails family={family} />

      <ChildrenMemorySection family={family} editable={false} />

      <FamilyContactsSection family={family} editable={false} />

      <CommunicationControlsSection family={family} editable={false} />

      <p className="mt-5 border-t border-border pt-4 text-xs italic text-muted-foreground">
        This merged family record is terminal historical data.
      </p>
    </Card>
  );
}

function ChildrenMemorySection({
  family,
  editable,
  onRefresh,
}: {
  family: FamilyRecord;
  editable: boolean;
  onRefresh?: () => Promise<void>;
}) {
  const [showAddChild, setShowAddChild] = useState(false);

  const activeChildren = family.children.filter((child) => child.status === "active");

  const archivedChildren = family.children.filter((child) => child.status === "archived");

  return (
    <section className="mt-6 border-t border-border pt-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
            Growing together
          </div>

          <h4 className="mt-1 font-serif text-lg text-primary">Children & memory profiles</h4>

          <p className="mt-1 max-w-2xl text-xs text-muted-foreground">
            Keep only the child and memory information that helps the studio care for this family
            across meaningful milestones.
          </p>
        </div>

        {editable && onRefresh && (
          <button
            type="button"
            onClick={() => setShowAddChild((current) => !current)}
            className="rounded-lg border border-border px-3 py-1.5 text-xs text-primary hover:bg-muted"
          >
            {showAddChild ? "Close" : "Add child"}
          </button>
        )}
      </div>

      {showAddChild && editable && onRefresh && (
        <AddChildForm family={family} onRefresh={onRefresh} onDone={() => setShowAddChild(false)} />
      )}

      <div className="mt-5">
        <MemoryProfileEditor
          family={family}
          child={null}
          profile={family.familyMemoryProfile}
          editable={editable}
          onRefresh={onRefresh}
        />
      </div>

      <div className="mt-5 space-y-4">
        {activeChildren.length > 0 ? (
          activeChildren.map((child) => (
            <ChildCard
              key={child.id}
              family={family}
              child={child}
              editable={editable}
              onRefresh={onRefresh}
            />
          ))
        ) : (
          <div className="rounded-xl border border-border bg-muted/20 p-4">
            <p className="text-sm text-muted-foreground">No active child records yet.</p>
          </div>
        )}
      </div>

      {archivedChildren.length > 0 && (
        <div className="mt-5">
          <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
            Archived child records
          </div>

          <div className="mt-3 space-y-3">
            {archivedChildren.map((child) => (
              <ChildCard key={child.id} family={family} child={child} editable={false} />
            ))}
          </div>
        </div>
      )}
    </section>
  );
}

function AddChildForm({
  family,
  onRefresh,
  onDone,
}: {
  family: FamilyRecord;
  onRefresh: () => Promise<void>;
  onDone: () => void;
}) {
  const [firstName, setFirstName] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [expectedDueDate, setExpectedDueDate] = useState("");
  const [stage, setStage] = useState<ChildStage | "">("");
  const [privacy, setPrivacy] = useState<PrivacyPreferenceType | "">("");
  const [message, setMessage] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: async () => {
      const cleanName = firstName.trim();

      const { error } = await db.rpc("create_child", {
        p_family_id: family.id,
        p_first_name: cleanName || null,
        p_birth_date: birthDate || null,
        p_expected_due_date: expectedDueDate || null,
        p_current_stage: stage || null,
        p_privacy_restriction: privacy || null,
      });

      if (error) {
        throw new Error(error.message ?? "Could not create child record.");
      }
    },

    onSuccess: async () => {
      await onRefresh();

      setMessage("Child record created successfully.");
      setFirstName("");
      setBirthDate("");
      setExpectedDueDate("");
      setStage("");
      setPrivacy("");
    },
  });

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setMessage(null);

    try {
      await mutation.mutateAsync();
    } catch {
      // Mutation state renders the error.
    }
  };

  return (
    <form onSubmit={submit} className="mt-4 rounded-xl border border-border bg-card p-4">
      <div className="grid gap-4 md:grid-cols-2">
        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            First name
          </span>

          <input
            type="text"
            value={firstName}
            onChange={(event) => setFirstName(event.target.value)}
            placeholder="Optional"
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary outline-none focus:ring-1 focus:ring-primary"
          />
        </label>

        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Current stage
          </span>

          <select
            value={stage}
            onChange={(event) => setStage(event.target.value as ChildStage | "")}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          >
            <option value="">Not set</option>
            <option value="expected">Expected</option>
            <option value="newborn">Newborn</option>
            <option value="baby">Baby</option>
            <option value="sitter">Sitter</option>
            <option value="toddler">Toddler</option>
            <option value="child">Child</option>
          </select>
        </label>

        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Birth date
          </span>

          <input
            type="date"
            value={birthDate}
            onChange={(event) => setBirthDate(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
        </label>

        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Expected due date
          </span>

          <input
            type="date"
            value={expectedDueDate}
            onChange={(event) => setExpectedDueDate(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
        </label>

        <label className="block md:col-span-2">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Child-specific privacy preference
          </span>

          <select
            value={privacy}
            onChange={(event) => setPrivacy(event.target.value as PrivacyPreferenceType | "")}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          >
            <option value="">No child-specific preference recorded</option>

            <option value="full_privacy">Full privacy</option>

            <option value="selective_sharing">Selective sharing</option>

            <option value="anonymous_sharing">Anonymous sharing</option>

            <option value="portfolio_release">Portfolio release</option>

            <option value="decide_later">Decide later</option>
          </select>

          <p className="mt-1 text-xs text-muted-foreground">
            Leaving this unset does not imply consent.
          </p>
        </label>
      </div>

      {mutation.isError && <ErrorBox className="mt-4">{getErrorMessage(mutation.error)}</ErrorBox>}

      {message && <SuccessBox className="mt-4">{message}</SuccessBox>}

      <div className="mt-4 flex gap-2">
        <button
          type="submit"
          disabled={mutation.isPending}
          className="rounded-lg bg-primary px-3 py-2 text-xs font-medium text-primary-foreground disabled:opacity-60"
        >
          {mutation.isPending ? "Creating…" : "Create child"}
        </button>

        <button
          type="button"
          onClick={onDone}
          disabled={mutation.isPending}
          className="rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-60"
        >
          Done
        </button>
      </div>
    </form>
  );
}

function ChildCard({
  family,
  child,
  editable,
  onRefresh,
}: {
  family: FamilyRecord;
  child: FamilyRecord["children"][number];
  editable: boolean;
  onRefresh?: () => Promise<void>;
}) {
  return (
    <div className="rounded-xl border border-border bg-muted/20 p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            {child.child_reference}
          </div>

          <h5 className="mt-1 font-medium text-primary">{child.first_name || "Child record"}</h5>
        </div>

        <div className="flex flex-wrap gap-2">
          {child.current_stage && (
            <span className="rounded-full border border-border px-2 py-0.5 text-[10px] uppercase tracking-wider text-primary">
              {humanize(child.current_stage)}
            </span>
          )}

          {child.status === "archived" && (
            <span className="rounded-full border border-border px-2 py-0.5 text-[10px] uppercase tracking-wider text-muted-foreground">
              Archived
            </span>
          )}
        </div>
      </div>

      <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Field label="Birth date" value={child.birth_date ? formatDate(child.birth_date) : "—"} />

        <Field
          label="Expected due date"
          value={child.expected_due_date ? formatDate(child.expected_due_date) : "—"}
        />

        <Field label="Stage" value={child.current_stage ? humanize(child.current_stage) : "—"} />

        <Field
          label="Privacy"
          value={
            child.privacy_restriction
              ? humanize(child.privacy_restriction)
              : "No child-specific preference"
          }
        />
      </div>

      <div className="mt-4">
        <MemoryProfileEditor
          family={family}
          child={child}
          profile={child.memoryProfile}
          editable={editable && child.status === "active"}
          onRefresh={onRefresh}
        />
      </div>
    </div>
  );
}

function MemoryProfileEditor({
  family,
  child,
  profile,
  editable,
  onRefresh,
}: {
  family: FamilyRecord;
  child: FamilyRecord["children"][number] | null;
  profile: MemoryProfileRow | null;
  editable: boolean;
  onRefresh?: () => Promise<void>;
}) {
  const [editing, setEditing] = useState(false);

  const [memoryGoal, setMemoryGoal] = useState(profile?.memory_goal ?? "");

  const [storyNotes, setStoryNotes] = useState(profile?.story_notes ?? "");

  const [emotionalTags, setEmotionalTags] = useState((profile?.emotional_tags ?? []).join(", "));

  const [milestoneNotes, setMilestoneNotes] = useState(profile?.milestone_notes ?? "");

  const [futureMemoryNotes, setFutureMemoryNotes] = useState(profile?.future_memory_notes ?? "");

  const mutation = useMutation({
    mutationFn: async () => {
      const tags = emotionalTags
        .split(",")
        .map((tag) => tag.trim())
        .filter(Boolean);

      const { error } = await db.rpc("upsert_memory_profile", {
        p_family_id: family.id,
        p_child_id: child?.id ?? null,
        p_memory_goal: memoryGoal.trim() || null,
        p_story_notes: storyNotes.trim() || null,
        p_emotional_tags: tags,
        p_milestone_notes: milestoneNotes.trim() || null,
        p_future_memory_notes: futureMemoryNotes.trim() || null,
      });

      if (error) {
        throw new Error(error.message ?? "Could not save memory profile.");
      }
    },

    onSuccess: async () => {
      if (onRefresh) {
        await onRefresh();
      }

      setEditing(false);
    },
  });

  const startEditing = () => {
    setMemoryGoal(profile?.memory_goal ?? "");
    setStoryNotes(profile?.story_notes ?? "");
    setEmotionalTags((profile?.emotional_tags ?? []).join(", "));
    setMilestoneNotes(profile?.milestone_notes ?? "");
    setFutureMemoryNotes(profile?.future_memory_notes ?? "");
    setEditing(true);
  };

  if (!editing) {
    return (
      <div className="rounded-xl border border-border bg-card p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
              {child ? "Child memory profile" : "Family memory profile"}
            </div>

            <h5 className="mt-1 font-serif text-base text-primary">
              {child
                ? child.first_name
                  ? `${child.first_name}'s story`
                  : "Child story"
                : "Family story & memory goals"}
            </h5>
          </div>

          {editable && onRefresh && (
            <button
              type="button"
              onClick={startEditing}
              className="rounded-lg border border-border px-3 py-1.5 text-xs text-primary hover:bg-muted"
            >
              {profile ? "Edit" : "Add profile"}
            </button>
          )}
        </div>

        {profile ? (
          <div className="mt-4 space-y-4">
            <MemoryTextBlock label="Memory goal" value={profile.memory_goal} />

            <MemoryTextBlock label="Story notes" value={profile.story_notes} />

            <MemoryTextBlock label="Milestone notes" value={profile.milestone_notes} />

            <MemoryTextBlock label="Future memory notes" value={profile.future_memory_notes} />

            <div>
              <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                Emotional tags
              </div>

              {profile.emotional_tags.length > 0 ? (
                <div className="mt-2 flex flex-wrap gap-2">
                  {profile.emotional_tags.map((tag) => (
                    <span
                      key={tag}
                      className="rounded-full border border-border px-2 py-1 text-[10px] text-primary"
                    >
                      {humanize(tag)}
                    </span>
                  ))}
                </div>
              ) : (
                <div className="mt-1 text-sm text-muted-foreground">—</div>
              )}
            </div>
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">No memory profile recorded yet.</p>
        )}
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-border bg-card p-4">
      <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
        {child ? "Child memory profile" : "Family memory profile"}
      </div>

      <div className="mt-4 space-y-4">
        <MemoryTextarea
          label="Memory goal"
          value={memoryGoal}
          onChange={setMemoryGoal}
          placeholder="What does this family most want to remember?"
          rows={3}
        />

        <MemoryTextarea
          label="Story notes"
          value={storyNotes}
          onChange={setStoryNotes}
          placeholder="Meaningful context, relationships or story details relevant to future sessions."
          rows={4}
        />

        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Emotional tags
          </span>

          <input
            type="text"
            value={emotionalTags}
            onChange={(event) => setEmotionalTags(event.target.value)}
            placeholder="gentle, playful, sentimental"
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary outline-none focus:ring-1 focus:ring-primary"
          />

          <p className="mt-1 text-xs text-muted-foreground">Separate tags with commas.</p>
        </label>

        <MemoryTextarea
          label="Milestone notes"
          value={milestoneNotes}
          onChange={setMilestoneNotes}
          placeholder="Upcoming or meaningful milestones relevant to future photography."
          rows={3}
        />

        <MemoryTextarea
          label="Future memory notes"
          value={futureMemoryNotes}
          onChange={setFutureMemoryNotes}
          placeholder="Ideas or moments worth remembering for later."
          rows={3}
        />
      </div>

      {mutation.isError && <ErrorBox className="mt-4">{getErrorMessage(mutation.error)}</ErrorBox>}

      <div className="mt-4 flex gap-2">
        <button
          type="button"
          onClick={() => mutation.mutate()}
          disabled={mutation.isPending}
          className="rounded-lg bg-primary px-3 py-2 text-xs font-medium text-primary-foreground disabled:opacity-60"
        >
          {mutation.isPending ? "Saving…" : "Save memory profile"}
        </button>

        <button
          type="button"
          onClick={() => setEditing(false)}
          disabled={mutation.isPending}
          className="rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-60"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

function MemoryTextarea({
  label,
  value,
  onChange,
  placeholder,
  rows,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  rows: number;
}) {
  return (
    <label className="block">
      <span className="text-[10px] uppercase tracking-wider text-muted-foreground">{label}</span>

      <textarea
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        rows={rows}
        className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary outline-none focus:ring-1 focus:ring-primary"
      />
    </label>
  );
}

function MemoryTextBlock({ label, value }: { label: string; value: string | null }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{label}</div>

      <div className="mt-1 whitespace-pre-wrap text-sm leading-6 text-primary">{value || "—"}</div>
    </div>
  );
}

function FamilyContactsSection({
  family,
  editable,
  onRefresh,
}: {
  family: FamilyRecord;
  editable: boolean;
  onRefresh?: () => Promise<void>;
}) {
  const [showAddContact, setShowAddContact] = useState(false);

  return (
    <section className="mt-6 border-t border-border pt-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
            Relationships
          </div>

          <h4 className="mt-1 font-serif text-lg text-primary">Family contacts</h4>
        </div>

        {editable && onRefresh && (
          <button
            type="button"
            onClick={() => setShowAddContact((current) => !current)}
            className="rounded-lg border border-border px-3 py-1.5 text-xs text-primary hover:bg-muted"
          >
            {showAddContact ? "Close" : "Add contact"}
          </button>
        )}
      </div>

      {showAddContact && editable && onRefresh && (
        <AddContactForm
          family={family}
          onRefresh={onRefresh}
          onDone={() => setShowAddContact(false)}
        />
      )}

      <div className="mt-4 space-y-4">
        {family.contacts.length > 0 ? (
          family.contacts.map((contact) => (
            <ContactCard
              key={contact.id}
              contact={contact}
              editable={editable}
              onRefresh={onRefresh}
            />
          ))
        ) : (
          <p className="text-sm text-muted-foreground">No family contacts recorded yet.</p>
        )}
      </div>
    </section>
  );
}

function ContactCard({
  contact,
  editable,
  onRefresh,
}: {
  contact: FamilyRecord["contacts"][number];
  editable: boolean;
  onRefresh?: () => Promise<void>;
}) {
  const [showChannelForm, setShowChannelForm] = useState(false);

  return (
    <div className="rounded-xl border border-border bg-muted/20 p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h5 className="font-medium text-primary">{contact.full_name}</h5>

            {contact.is_primary && (
              <span className="rounded-full border border-border px-2 py-0.5 text-[10px] uppercase tracking-wider text-primary">
                Primary
              </span>
            )}

            {!contact.is_active && (
              <span className="rounded-full border border-border px-2 py-0.5 text-[10px] uppercase tracking-wider text-muted-foreground">
                Inactive
              </span>
            )}
          </div>

          <div className="mt-1 text-xs capitalize text-muted-foreground">
            {contact.relationship_label}
          </div>
        </div>

        {editable && contact.is_active && onRefresh && (
          <button
            type="button"
            onClick={() => setShowChannelForm((current) => !current)}
            className="rounded-lg border border-border px-3 py-1.5 text-xs text-primary hover:bg-muted"
          >
            {showChannelForm ? "Close" : "Add channel"}
          </button>
        )}
      </div>

      {showChannelForm && editable && contact.is_active && onRefresh && (
        <AddChannelForm
          contact={contact}
          onRefresh={onRefresh}
          onDone={() => setShowChannelForm(false)}
        />
      )}

      <div className="mt-4 space-y-2">
        {contact.channels.length > 0 ? (
          contact.channels.map((channel) => (
            <div
              key={channel.id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-card px-3 py-2"
            >
              <div>
                <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                  {channel.channel_type}
                </div>

                <div className="mt-0.5 text-sm text-primary">{channel.channel_value}</div>
              </div>

              <div className="flex items-center gap-2 text-[10px] uppercase tracking-wider">
                {channel.is_preferred && <span className="text-primary">Preferred</span>}

                <span className="text-muted-foreground">
                  {channel.is_verified ? "Verified" : "Unverified"}
                </span>

                {!channel.is_active && <span className="text-muted-foreground">Inactive</span>}
              </div>
            </div>
          ))
        ) : (
          <p className="text-xs text-muted-foreground">No phone, WhatsApp or email channels yet.</p>
        )}
      </div>
    </div>
  );
}

function AddContactForm({
  family,
  onRefresh,
  onDone,
}: {
  family: FamilyRecord;
  onRefresh: () => Promise<void>;
  onDone: () => void;
}) {
  const [fullName, setFullName] = useState("");
  const [relationship, setRelationship] = useState("");
  const [isPrimary, setIsPrimary] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: async () => {
      const cleanName = fullName.trim();
      const cleanRelationship = relationship.trim().toLowerCase();

      if (!cleanName) {
        throw new Error("Full name is required.");
      }

      if (!cleanRelationship) {
        throw new Error("Relationship is required.");
      }

      const { error } = await db.rpc("create_family_contact", {
        p_family_id: family.id,
        p_full_name: cleanName,
        p_relationship_label: cleanRelationship,
        p_is_primary: isPrimary,
      });

      if (error) {
        throw new Error(error.message ?? "Could not create family contact.");
      }
    },

    onSuccess: async () => {
      await onRefresh();
      setMessage("Contact added successfully.");
      setFullName("");
      setRelationship("");
      setIsPrimary(false);
    },
  });

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setMessage(null);

    try {
      await mutation.mutateAsync();
    } catch {
      // Rendered below.
    }
  };

  return (
    <form onSubmit={submit} className="mt-4 rounded-xl border border-border bg-card p-4">
      <div className="grid gap-4 md:grid-cols-2">
        <InputField
          label="Full name"
          value={fullName}
          onChange={setFullName}
          placeholder="Example: Priya Mehta"
        />

        <InputField
          label="Relationship"
          value={relationship}
          onChange={setRelationship}
          placeholder="Example: mother"
        />
      </div>

      <label className="mt-4 flex items-center gap-2 text-sm text-primary">
        <input
          type="checkbox"
          checked={isPrimary}
          onChange={(event) => setIsPrimary(event.target.checked)}
        />
        Primary family contact
      </label>

      <p className="mt-1 text-xs text-muted-foreground">
        Making this person primary will replace the current active primary contact.
      </p>

      {mutation.isError && <ErrorBox className="mt-4">{getErrorMessage(mutation.error)}</ErrorBox>}

      {message && <SuccessBox className="mt-4">{message}</SuccessBox>}

      <div className="mt-4 flex gap-2">
        <button
          type="submit"
          disabled={mutation.isPending}
          className="rounded-lg bg-primary px-3 py-2 text-xs font-medium text-primary-foreground disabled:opacity-60"
        >
          {mutation.isPending ? "Adding…" : "Add contact"}
        </button>

        <button
          type="button"
          onClick={onDone}
          className="rounded-lg border border-border px-3 py-2 text-xs text-primary"
        >
          Done
        </button>
      </div>
    </form>
  );
}

function AddChannelForm({
  contact,
  onRefresh,
  onDone,
}: {
  contact: FamilyRecord["contacts"][number];
  onRefresh: () => Promise<void>;
  onDone: () => void;
}) {
  const [channelType, setChannelType] = useState<ContactChannelType>("whatsapp");

  const [channelValue, setChannelValue] = useState("");

  const [isPreferred, setIsPreferred] = useState(false);

  const [message, setMessage] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: async () => {
      const cleanValue = channelValue.trim();

      if (!cleanValue) {
        throw new Error("Channel value is required.");
      }

      if (
        (channelType === "phone" || channelType === "whatsapp") &&
        !/^\+[0-9]+$/.test(cleanValue)
      ) {
        throw new Error(
          "Phone and WhatsApp numbers must use international format, for example +919876543210.",
        );
      }

      const { error } = await db.rpc("add_family_contact_channel", {
        p_family_contact_id: contact.id,
        p_channel_type: channelType,
        p_channel_value: cleanValue,
        p_is_preferred: isPreferred,
      });

      if (error) {
        throw new Error(error.message ?? "Could not add contact channel.");
      }
    },

    onSuccess: async () => {
      await onRefresh();
      setMessage("Channel added successfully.");
      setChannelValue("");
      setIsPreferred(false);
    },
  });

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setMessage(null);

    try {
      await mutation.mutateAsync();
    } catch {
      // Rendered below.
    }
  };

  return (
    <form onSubmit={submit} className="mt-4 rounded-xl border border-border bg-card p-4">
      <div className="grid gap-4 md:grid-cols-[180px_1fr]">
        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Channel
          </span>

          <select
            value={channelType}
            onChange={(event) => setChannelType(event.target.value as ContactChannelType)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          >
            <option value="whatsapp">WhatsApp</option>
            <option value="phone">Phone</option>
            <option value="email">Email</option>
            <option value="other">Other</option>
          </select>
        </label>

        <InputField
          label="Value"
          value={channelValue}
          onChange={setChannelValue}
          placeholder={
            channelType === "email"
              ? "name@example.com"
              : channelType === "phone" || channelType === "whatsapp"
                ? "+919876543210"
                : "Contact detail"
          }
        />
      </div>

      {(channelType === "phone" || channelType === "whatsapp") && (
        <p className="mt-2 text-xs text-muted-foreground">
          Use international format with + and digits only, for example +919876543210.
        </p>
      )}

      <label className="mt-4 flex items-center gap-2 text-sm text-primary">
        <input
          type="checkbox"
          checked={isPreferred}
          onChange={(event) => setIsPreferred(event.target.checked)}
        />
        Preferred channel for this person
      </label>

      {mutation.isError && <ErrorBox className="mt-4">{getErrorMessage(mutation.error)}</ErrorBox>}

      {message && <SuccessBox className="mt-4">{message}</SuccessBox>}

      <div className="mt-4 flex gap-2">
        <button
          type="submit"
          disabled={mutation.isPending}
          className="rounded-lg bg-primary px-3 py-2 text-xs font-medium text-primary-foreground disabled:opacity-60"
        >
          {mutation.isPending ? "Adding…" : "Add channel"}
        </button>

        <button
          type="button"
          onClick={onDone}
          className="rounded-lg border border-border px-3 py-2 text-xs text-primary"
        >
          Done
        </button>
      </div>
    </form>
  );
}

function CommunicationControlsSection({
  family,
  editable,
  onRefresh,
}: {
  family: FamilyRecord;
  editable: boolean;
  onRefresh?: () => Promise<void>;
}) {
  const controls = family.communicationControls;

  const [editing, setEditing] = useState(false);

  const [status, setStatus] = useState<ContactabilityStatus>(
    controls?.contactability_status ?? "contactable",
  );

  const [preferredChannel, setPreferredChannel] = useState<ContactChannelType | "">(
    controls?.preferred_channel_type ?? "",
  );

  const [reason, setReason] = useState(controls?.do_not_contact_reason ?? "");

  const [quietStart, setQuietStart] = useState(toTimeInputValue(controls?.quiet_hours_start));

  const [quietEnd, setQuietEnd] = useState(toTimeInputValue(controls?.quiet_hours_end));

  const mutation = useMutation({
    mutationFn: async () => {
      if (status === "do_not_contact" && !reason.trim()) {
        throw new Error("A reason is required when a family must not be contacted.");
      }

      if (Boolean(quietStart) !== Boolean(quietEnd)) {
        throw new Error("Quiet hours require both a start and an end time.");
      }

      const { error } = await db.rpc("update_family_communication_controls", {
        p_family_id: family.id,
        p_contactability_status: status,
        p_do_not_contact: status === "do_not_contact",
        p_do_not_contact_reason: status === "do_not_contact" ? reason.trim() : null,
        p_preferred_channel_type: preferredChannel || null,
        p_quiet_hours_start: quietStart || null,
        p_quiet_hours_end: quietEnd || null,
      });

      if (error) {
        throw new Error(error.message ?? "Could not update communication controls.");
      }
    },

    onSuccess: async () => {
      if (onRefresh) {
        await onRefresh();
      }

      setEditing(false);
    },
  });

  if (!editing) {
    return (
      <section className="mt-6 border-t border-border pt-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
              Careful communication
            </div>

            <h4 className="mt-1 font-serif text-lg text-primary">Communication preferences</h4>
          </div>

          {editable && onRefresh && (
            <button
              type="button"
              onClick={() => setEditing(true)}
              className="rounded-lg border border-border px-3 py-1.5 text-xs text-primary hover:bg-muted"
            >
              {controls ? "Edit" : "Set preferences"}
            </button>
          )}
        </div>

        {controls ? (
          <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Field label="Contactability" value={humanize(controls.contactability_status)} />

            <Field
              label="Preferred channel"
              value={
                controls.preferred_channel_type ? humanize(controls.preferred_channel_type) : "—"
              }
            />

            <Field
              label="Quiet hours"
              value={
                controls.quiet_hours_start && controls.quiet_hours_end
                  ? `${formatTime(controls.quiet_hours_start)} – ${formatTime(
                      controls.quiet_hours_end,
                    )}`
                  : "—"
              }
            />

            <Field label="Timezone" value={controls.timezone} />

            {controls.do_not_contact && (
              <div className="sm:col-span-2 lg:col-span-4">
                <div className="rounded-lg border border-destructive/30 bg-destructive/5 px-3 py-2">
                  <div className="text-[10px] uppercase tracking-wider text-destructive">
                    Do not contact
                  </div>

                  <div className="mt-1 text-sm text-destructive">
                    {controls.do_not_contact_reason}
                  </div>
                </div>
              </div>
            )}
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">
            No explicit communication preferences have been recorded yet.
          </p>
        )}
      </section>
    );
  }

  return (
    <section className="mt-6 border-t border-border pt-5">
      <div>
        <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
          Careful communication
        </div>

        <h4 className="mt-1 font-serif text-lg text-primary">Communication preferences</h4>
      </div>

      <div className="mt-4 grid gap-4 md:grid-cols-2">
        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Contactability
          </span>

          <select
            value={status}
            onChange={(event) => setStatus(event.target.value as ContactabilityStatus)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          >
            <option value="contactable">Contactable</option>
            <option value="limited">Limited</option>
            <option value="do_not_contact">Do not contact</option>
          </select>
        </label>

        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Preferred channel
          </span>

          <select
            value={preferredChannel}
            onChange={(event) => setPreferredChannel(event.target.value as ContactChannelType | "")}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          >
            <option value="">No preference</option>
            <option value="whatsapp">WhatsApp</option>
            <option value="phone">Phone</option>
            <option value="email">Email</option>
            <option value="other">Other</option>
          </select>
        </label>

        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Quiet hours start
          </span>

          <input
            type="time"
            value={quietStart}
            onChange={(event) => setQuietStart(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
        </label>

        <label className="block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Quiet hours end
          </span>

          <input
            type="time"
            value={quietEnd}
            onChange={(event) => setQuietEnd(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
        </label>
      </div>

      {status === "do_not_contact" && (
        <label className="mt-4 block">
          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Do not contact reason
          </span>

          <textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            rows={3}
            placeholder="Record the family's request or reason."
            className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
          />
        </label>
      )}

      <p className="mt-3 text-xs text-muted-foreground">
        Quiet hours are stored in Asia/Kolkata by the backend. Both start and end are required when
        quiet hours are used.
      </p>

      {mutation.isError && <ErrorBox className="mt-4">{getErrorMessage(mutation.error)}</ErrorBox>}

      <div className="mt-4 flex gap-2">
        <button
          type="button"
          onClick={() => mutation.mutate()}
          disabled={mutation.isPending}
          className="rounded-lg bg-primary px-3 py-2 text-xs font-medium text-primary-foreground disabled:opacity-60"
        >
          {mutation.isPending ? "Saving…" : "Save preferences"}
        </button>

        <button
          type="button"
          onClick={() => setEditing(false)}
          disabled={mutation.isPending}
          className="rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-60"
        >
          Cancel
        </button>
      </div>
    </section>
  );
}

function FamilyHeader({ family }: { family: FamilyRecord }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <div>
        <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
          {family.family_code}
        </div>

        <h3 className="mt-1 font-serif text-xl text-primary">{family.display_name}</h3>
      </div>

      <StatusPill tone={family.status === "active" ? "gold" : "neutral"}>
        {family.status}
      </StatusPill>
    </div>
  );
}

function FamilyDetails({ family }: { family: FamilyRecord }) {
  return (
    <div className="mt-5 grid grid-cols-2 gap-x-4 gap-y-3 text-sm lg:grid-cols-4">
      <Field label="Family code" value={family.family_code} />

      <Field label="Status" value={humanize(family.status)} />

      <Field label="Created" value={formatDate(family.created_at)} />

      <Field label="Last updated" value={formatDate(family.updated_at)} />
    </div>
  );
}

function SectionHeading({
  eyebrow,
  title,
  count,
}: {
  eyebrow: string;
  title: string;
  count: number;
}) {
  return (
    <div className="mb-4 flex items-end justify-between gap-4">
      <div>
        <div className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">
          {eyebrow}
        </div>

        <h2 className="mt-1 font-serif text-2xl text-primary">{title}</h2>
      </div>

      <div className="text-xs text-muted-foreground">
        {count} {count === 1 ? "family" : "families"}
      </div>
    </div>
  );
}

function InputField({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}) {
  return (
    <label className="block">
      <span className="text-[10px] uppercase tracking-wider text-muted-foreground">{label}</span>

      <input
        type="text"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        required
        className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary outline-none focus:ring-1 focus:ring-primary"
      />
    </label>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{label}</div>

      <div className="mt-0.5 text-primary">{value || "—"}</div>
    </div>
  );
}

function ErrorBox({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-lg border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive ${className}`}
    >
      {children}
    </div>
  );
}

function SuccessBox({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary ${className}`}
    >
      {children}
    </div>
  );
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  return "Something went wrong.";
}

function humanize(value: string) {
  return value.replaceAll("_", " ").replace(/\b\w/g, (character) => character.toUpperCase());
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

function formatTime(value: string) {
  return value.slice(0, 5);
}

function toTimeInputValue(value: string | null | undefined) {
  if (!value) {
    return "";
  }

  return value.slice(0, 5);
}
