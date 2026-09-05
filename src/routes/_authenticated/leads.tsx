import { useState, type FormEvent } from "react";
import {
  createFileRoute,
  Link,
} from "@tanstack/react-router";
import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import {
  ArrowRight,
  Loader2,
  UserPlus,
} from "lucide-react";

import {
  AppShell,
  Card,
  PageHeader,
  StatusPill,
} from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";
import { ORGANIZATION_ID } from "@/lib/session";
import {
  convertLeadToFamily,
  createLead,
  leadStatuses,
  listLeads,
  privacyPreferences,
  updateLead,
  type LeadRow,
  type LeadStatus,
  type PrivacyPreference,
} from "@/lib/leads.functions";

export const Route = createFileRoute(
  "/_authenticated/leads",
)({
  head: () => ({
    meta: [
      {
        title:
          "Leads & Inquiries · Little Moments OS",
      },
      {
        name: "description",
        content:
          "Capture inquiries with their memory goals and move them gently towards a booking.",
      },
      {
        property: "og:title",
        content:
          "Leads & Inquiries · Little Moments OS",
      },
      {
        property: "og:description",
        content:
          "Capture inquiries with their memory goals and move them gently towards a booking.",
      },
      {
        property: "og:type",
        content: "website",
      },
      {
        name: "twitter:card",
        content: "summary",
      },
    ],
  }),
  component: LeadsPage,
});

const statusLabels: Record<LeadStatus, string> = {
  new_inquiry: "New Inquiry",
  contacted: "Contacted",
  qualified: "Qualified",
  consultation_scheduled:
    "Consultation Scheduled",
  quote_ready: "Quote Ready",
  quote_sent: "Quote Sent",
  follow_up_needed: "Follow-Up Needed",
  converted: "Converted",
  lost: "Lost",
  archived: "Archived",
};

const privacyLabels: Record<
  PrivacyPreference,
  string
> = {
  full_privacy: "Full privacy",
  selective_sharing: "Selective sharing",
  anonymous_sharing: "Anonymous sharing",
  portfolio_release: "Portfolio release",
  decide_later: "Decide later",
};

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

  const branches = (data ?? []) as AccessibleBranchOption[];

  const authorizedBranches = await Promise.all(
    branches.map(async (branch) => {
      const { data: allowed, error: permissionError } = await supabase.rpc(
        "has_permission",
        {
          p_organization_id: ORGANIZATION_ID,
          p_permission_key: "lead.write",
          p_branch_id: branch.branch_id,
        },
      );

      if (permissionError) {
        throw new Error(permissionError.message);
      }

      return allowed ? branch : null;
    }),
  );

  return {
    mode: "catalogue",
    branches: authorizedBranches.filter(
      (branch): branch is AccessibleBranchOption => branch !== null,
    ),
  };
}

const emptyLeadForm = {
  parentName: "",
  source: "",
  phone: "",
  email: "",
  city: "",
  sessionType: "",
  babyAgeOrPregnancy: "",
  preferredDate: "",
  locationPreference: "",
  memoryGoal: "",
  privacyPreference:
    "" as "" | PrivacyPreference,
  followUpAt: "",
};

function toneFor(status: LeadStatus) {
  if (status === "converted") {
    return "good";
  }

  if (status === "lost") {
    return "bad";
  }

  if (
    status === "new_inquiry" ||
    status === "follow_up_needed"
  ) {
    return "warn";
  }

  return "neutral";
}

function nullable(value: string | null) {
  return value ?? "";
}

function formatDate(value: string | null) {
  if (!value) {
    return "—";
  }

  const date = new Date(
    value.includes("T")
      ? value
      : `${value}T00:00:00`,
  );

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
}

function formatDateTime(value: string | null) {
  if (!value) {
    return "—";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

function updatePayload(
  lead: LeadRow,
  status: LeadStatus,
  lostReason: string | null,
) {
  return {
    leadId: lead.id,
    parentName: lead.parent_name,
    source: lead.source,
    phone: lead.phone,
    email: lead.email,
    city: lead.city,
    sessionType: lead.session_type,
    babyAgeOrPregnancy:
      lead.baby_age_or_pregnancy,
    preferredDate: lead.preferred_date,
    locationPreference:
      lead.location_preference,
    packageInterest: lead.package_interest,
    budgetComfort: lead.budget_comfort,
    memoryGoal: lead.memory_goal,
    privacyPreference:
      lead.privacy_preference,
    followUpAt: lead.follow_up_at,
    status,
    lostReason,
    branchId: lead.branch_id,
    assignedOwnerMemberId:
      lead.assigned_owner_member_id,
  };
}

function LeadsPage() {
  const queryClient = useQueryClient();

  const [showCreateForm, setShowCreateForm] =
    useState(false);
  const [newLead, setNewLead] =
    useState(emptyLeadForm);
  const [newLeadBranchId, setNewLeadBranchId] =
    useState("");
  const [actionError, setActionError] =
    useState<string | null>(null);

  const leadsQuery = useQuery({
    queryKey: ["leads"],
    queryFn: () => listLeads(),
  });

  const branchAccessQuery = useQuery({
    queryKey: ["accessible-branches", ORGANIZATION_ID],
    queryFn: loadAccessibleBranches,
    retry: false,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      createLead({
        data: {
          parentName: newLead.parentName,
          source: newLead.source,
          phone: newLead.phone || null,
          email: newLead.email || null,
          city: newLead.city || null,
          sessionType:
            newLead.sessionType || null,
          babyAgeOrPregnancy:
            newLead.babyAgeOrPregnancy || null,
          preferredDate:
            newLead.preferredDate || null,
          locationPreference:
            newLead.locationPreference || null,
          packageInterest: null,
          budgetComfort: null,
          memoryGoal:
            newLead.memoryGoal || null,
          privacyPreference:
            newLead.privacyPreference || null,
          followUpAt: newLead.followUpAt
            ? new Date(
                newLead.followUpAt,
              ).toISOString()
            : null,
          branchId:
            branchAccessQuery.data?.mode === "catalogue"
              ? newLeadBranchId || null
              : null,
          assignedOwnerMemberId: null,
        },
      }),
    onSuccess: async () => {
      setNewLead(emptyLeadForm);
      setNewLeadBranchId("");
      setShowCreateForm(false);

      await queryClient.invalidateQueries({
        queryKey: ["leads"],
      });
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({
      lead,
      status,
      lostReason,
    }: {
      lead: LeadRow;
      status: LeadStatus;
      lostReason: string | null;
    }) =>
      updateLead({
        data: updatePayload(
          lead,
          status,
          lostReason,
        ),
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: ["leads"],
      });
    },
  });

  const convertMutation = useMutation({
    mutationFn: (lead: LeadRow) =>
      convertLeadToFamily({
        data: {
          leadId: lead.id,
          familyDisplayName: null,
          familySortName: null,
        },
      }),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({
          queryKey: ["leads"],
        }),
        queryClient.invalidateQueries({
          queryKey: ["clients"],
        }),
      ]);
    },
  });

  const submitNewLead = async (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();

    if (branchAccessQuery.isPending) {
      setActionError("Branch access is still loading. Try again in a moment.");
      return;
    }

    if (branchAccessQuery.isError) {
      setActionError(
        branchAccessQuery.error instanceof Error
          ? branchAccessQuery.error.message
          : "Unable to resolve your authorized branches.",
      );
      return;
    }

    if (branchAccessQuery.data?.mode === "catalogue") {
      if (branchAccessQuery.data.branches.length === 0) {
        setActionError(
          "No active branch is available in your current studio access.",
        );
        return;
      }

      if (!newLeadBranchId) {
        setActionError("Choose the branch that owns this inquiry.");
        return;
      }
    }

    if (
      !newLead.phone.trim() &&
      !newLead.email.trim()
    ) {
      setActionError(
        "Add a phone number or email address before saving the inquiry.",
      );
      return;
    }

    setActionError(null);

    try {
      await createMutation.mutateAsync();
    } catch (error) {
      setActionError(
        error instanceof Error
          ? error.message
          : "Unable to save this inquiry.",
      );
    }
  };

  const changeStatus = async (
    lead: LeadRow,
    nextStatus: LeadStatus,
  ) => {
    if (nextStatus === "converted") {
      return;
    }

    let lostReason: string | null = null;

    if (nextStatus === "lost") {
      const reason = window.prompt(
        "Why was this inquiry lost?",
        lead.lost_reason ?? "",
      );

      if (reason === null) {
        return;
      }

      if (!reason.trim()) {
        setActionError(
          "A reason is required when an inquiry is marked lost.",
        );
        return;
      }

      lostReason = reason.trim();
    }

    setActionError(null);

    try {
      await updateMutation.mutateAsync({
        lead,
        status: nextStatus,
        lostReason,
      });
    } catch (error) {
      setActionError(
        error instanceof Error
          ? error.message
          : "Unable to update this inquiry.",
      );
    }
  };

  const convert = async (lead: LeadRow) => {
    setActionError(null);

    try {
      await convertMutation.mutateAsync(lead);
    } catch (error) {
      setActionError(
        error instanceof Error
          ? error.message
          : "Unable to convert this inquiry.",
      );
    }
  };

  const leads = leadsQuery.data ?? [];

  return (
    <AppShell>
      <PageHeader
        eyebrow="Inquiries"
        title="Leads & Inquiries"
        subtitle="Every inquiry is a family hoping someone will care about their moment. Respond with warmth."
        quote="What moment do they want to preserve?"
      />

      <div className="mb-5 flex justify-end">
        <button
          type="button"
          onClick={() => {
            setActionError(null);
            setShowCreateForm((open) => !open);
          }}
          className="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground hover:opacity-90"
        >
          <UserPlus className="h-4 w-4" />
          {showCreateForm
            ? "Close inquiry form"
            : "New inquiry"}
        </button>
      </div>

      {showCreateForm && (
        <Card className="mb-6 p-6">
          <div className="mb-5">
            <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
              New inquiry
            </div>

            <h2 className="mt-1 font-serif text-2xl text-primary">
              Begin with the family, not the package.
            </h2>

            <p className="mt-2 max-w-2xl text-sm text-muted-foreground">
              Capture enough to respond with care.
              Details can grow as the conversation
              continues.
            </p>
          </div>

          <form
            onSubmit={submitNewLead}
            className="grid gap-4 md:grid-cols-2"
          >
            {branchAccessQuery.data?.mode === "catalogue" && (
              <label className="text-sm text-primary">
                <span className="mb-1.5 block text-xs text-muted-foreground">
                  Branch *
                </span>
                <select
                  required
                  value={newLeadBranchId}
                  onChange={(event) =>
                    setNewLeadBranchId(event.target.value)
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

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Parent / contact name *
              </span>
              <input
                required
                value={newLead.parentName}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    parentName:
                      event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="Parent or primary contact"
              />
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Inquiry source *
              </span>
              <input
                required
                value={newLead.source}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    source: event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="WhatsApp, Instagram, website, referral…"
              />
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Phone
              </span>
              <input
                type="tel"
                value={newLead.phone}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    phone: event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="+919876543210"
              />
              <span className="mt-1 block text-[11px] text-muted-foreground">
                Use international format.
              </span>
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Email
              </span>
              <input
                type="email"
                value={newLead.email}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    email: event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="parent@example.com"
              />
              <span className="mt-1 block text-[11px] text-muted-foreground">
                Phone or email is required.
              </span>
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                City
              </span>
              <input
                value={newLead.city}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    city: event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="City"
              />
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Session type
              </span>
              <input
                value={newLead.sessionType}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    sessionType:
                      event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="Maternity, newborn, sitter, family…"
              />
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Baby age / pregnancy stage
              </span>
              <input
                value={
                  newLead.babyAgeOrPregnancy
                }
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    babyAgeOrPregnancy:
                      event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="For example: 32 weeks or 6 months"
              />
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Preferred date
              </span>
              <input
                type="date"
                value={newLead.preferredDate}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    preferredDate:
                      event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
              />
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Location preference
              </span>
              <input
                value={
                  newLead.locationPreference
                }
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    locationPreference:
                      event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="Studio, home, outdoor…"
              />
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Privacy preference
              </span>
              <select
                value={
                  newLead.privacyPreference
                }
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    privacyPreference:
                      event.target
                        .value as
                        | ""
                        | PrivacyPreference,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
              >
                <option value="">
                  Not recorded yet
                </option>

                {privacyPreferences.map(
                  (preference) => (
                    <option
                      key={preference}
                      value={preference}
                    >
                      {
                        privacyLabels[
                          preference
                        ]
                      }
                    </option>
                  ),
                )}
              </select>
            </label>

            <label className="text-sm text-primary">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                Follow-up
              </span>
              <input
                type="datetime-local"
                value={newLead.followUpAt}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    followUpAt:
                      event.target.value,
                  }))
                }
                className="w-full rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
              />
            </label>

            <label className="text-sm text-primary md:col-span-2">
              <span className="mb-1.5 block text-xs text-muted-foreground">
                What moment do they want to
                preserve?
              </span>
              <textarea
                rows={4}
                value={newLead.memoryGoal}
                onChange={(event) =>
                  setNewLead((current) => ({
                    ...current,
                    memoryGoal:
                      event.target.value,
                  }))
                }
                className="w-full resize-y rounded-lg border border-border bg-background px-3 py-2.5 outline-none focus:border-primary"
                placeholder="Capture the feeling, stage, expression or family connection that matters to them."
              />
            </label>

            <div className="flex flex-wrap justify-end gap-2 border-t border-border pt-4 md:col-span-2">
              <button
                type="button"
                disabled={
                  createMutation.isPending
                }
                onClick={() => {
                  setNewLead(emptyLeadForm);
                  setActionError(null);
                  setShowCreateForm(false);
                }}
                className="rounded-lg border border-border px-4 py-2 text-sm text-primary disabled:opacity-50"
              >
                Cancel
              </button>

              <button
                type="submit"
                disabled={
                  createMutation.isPending
                }
                className="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground hover:opacity-90 disabled:opacity-50"
              >
                {createMutation.isPending && (
                  <Loader2 className="h-4 w-4 animate-spin" />
                )}

                {createMutation.isPending
                  ? "Saving inquiry…"
                  : "Save inquiry"}
              </button>
            </div>
          </form>
        </Card>
      )}

      <div className="mb-6 flex flex-wrap gap-2">
        {leadStatuses.map((status) => (
          <span
            key={status}
            className="rounded-full border border-border bg-muted px-3 py-1.5 text-xs text-muted-foreground"
          >
            {statusLabels[status]}
          </span>
        ))}
      </div>

      {actionError && (
        <div className="mb-5 rounded-xl border border-destructive/30 bg-destructive/5 px-4 py-3 text-sm text-destructive">
          {actionError}
        </div>
      )}

      {leadsQuery.isLoading && (
        <Card className="p-10 text-center">
          <Loader2 className="mx-auto h-5 w-5 animate-spin text-muted-foreground" />
          <p className="mt-3 font-serif text-xl text-primary">
            Opening the inquiry book…
          </p>
          <p className="mt-2 text-sm text-muted-foreground">
            Gathering the families waiting to
            be heard.
          </p>
        </Card>
      )}

      {leadsQuery.isError && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">
            We couldn&apos;t open the inquiry
            book.
          </p>

          <p className="mt-2 text-sm text-muted-foreground">
            {leadsQuery.error instanceof Error
              ? leadsQuery.error.message
              : "Something went wrong while loading inquiries."}
          </p>

          <button
            type="button"
            onClick={() => leadsQuery.refetch()}
            className="mt-5 rounded-lg bg-primary px-4 py-2 text-xs text-primary-foreground"
          >
            Try again
          </button>
        </Card>
      )}

      {!leadsQuery.isLoading &&
        !leadsQuery.isError && (
          <div className="grid gap-5 lg:grid-cols-2">
            {leads.map((lead) => {
              const terminal =
                lead.status === "converted" ||
                lead.status === "archived";

              const updating =
                updateMutation.isPending &&
                updateMutation.variables?.lead.id ===
                  lead.id;

              const converting =
                convertMutation.isPending &&
                convertMutation.variables?.id ===
                  lead.id;

              return (
                <Card
                  key={lead.id}
                  className="p-6"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                        {lead.lead_reference} ·{" "}
                        {lead.source}
                      </div>

                      <h3 className="mt-1 font-serif text-xl text-primary">
                        {lead.parent_name}
                      </h3>

                      <div className="mt-0.5 text-xs text-muted-foreground">
                        {[
                          lead.city,
                          lead.phone,
                          lead.email,
                        ]
                          .filter(Boolean)
                          .join(" · ") || "No contact details"}
                      </div>
                    </div>

                    <StatusPill
                      tone={
                        toneFor(
                          lead.status,
                        ) as never
                      }
                    >
                      {statusLabels[lead.status]}
                    </StatusPill>
                  </div>

                  <div className="mt-4 rounded-xl bg-[var(--gradient-warm)] px-4 py-3">
                    <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                      The moment they want to
                      preserve
                    </div>

                    <p className="mt-1 font-serif text-base italic text-primary">
                      {lead.memory_goal
                        ? `“${lead.memory_goal}”`
                        : "Not captured yet."}
                    </p>
                  </div>

                  <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                    <Field
                      k="Session type"
                      v={nullable(
                        lead.session_type,
                      )}
                    />
                    <Field
                      k="Baby age / pregnancy"
                      v={nullable(
                        lead.baby_age_or_pregnancy,
                      )}
                    />
                    <Field
                      k="Preferred date"
                      v={formatDate(
                        lead.preferred_date,
                      )}
                    />
                    <Field
                      k="Location"
                      v={nullable(
                        lead.location_preference,
                      )}
                    />
                    <Field
                      k="Package interest"
                      v={nullable(
                        lead.package_interest,
                      )}
                    />
                    <Field
                      k="Budget comfort"
                      v={nullable(
                        lead.budget_comfort,
                      )}
                    />
                    <Field
                      k="Follow-up"
                      v={formatDateTime(
                        lead.follow_up_at,
                      )}
                    />
                    <Field
                      k="Privacy"
                      v={
                        lead.privacy_preference
                          ? lead.privacy_preference.replaceAll(
                              "_",
                              " ",
                            )
                          : ""
                      }
                    />

                    {lead.status === "lost" &&
                      lead.lost_reason && (
                        <div className="col-span-2">
                          <Field
                            k="Lost reason"
                            v={lead.lost_reason}
                          />
                        </div>
                      )}
                  </dl>

                  <div className="mt-5 flex flex-wrap items-center gap-2 border-t border-border pt-4">
                    {!terminal && (
                      <select
                        value={lead.status}
                        disabled={
                          updating || converting
                        }
                        onChange={(event) =>
                          void changeStatus(
                            lead,
                            event.target
                              .value as LeadStatus,
                          )
                        }
                        className="rounded-lg border border-border bg-muted px-2.5 py-1.5 text-xs text-primary disabled:opacity-50"
                      >
                        {leadStatuses
                          .filter(
                            (status) =>
                              status !==
                              "converted",
                          )
                          .map((status) => (
                            <option
                              key={status}
                              value={status}
                            >
                              {
                                statusLabels[
                                  status
                                ]
                              }
                            </option>
                          ))}
                      </select>
                    )}

                    {updating && (
                      <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
                        <Loader2 className="h-3 w-3 animate-spin" />
                        Saving…
                      </span>
                    )}

                    <Link
                      to="/leads/$leadId"
                      params={{ leadId: lead.id }}
                      className="ml-auto inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-3 py-1.5 text-xs text-primary"
                    >
                      Open workspace
                      <ArrowRight className="h-3 w-3" />
                    </Link>

                    {lead.converted_family_id ? (
                      <Link
                        to="/clients"
                        className="inline-flex items-center gap-1.5 rounded-lg border border-gold bg-accent px-3 py-1.5 text-xs text-primary"
                      >
                        Open family
                        <ArrowRight className="h-3 w-3" />
                      </Link>
                    ) : lead.status !==
                      "archived" ? (
                      <button
                        type="button"
                        disabled={
                          converting || updating
                        }
                        onClick={() =>
                          void convert(lead)
                        }
                        className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-xs text-primary-foreground hover:opacity-90 disabled:opacity-50"
                      >
                        {converting ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <UserPlus className="h-3 w-3" />
                        )}

                        {converting
                          ? "Converting…"
                          : "Convert to family"}
                      </button>
                    ) : null}
                  </div>
                </Card>
              );
            })}

            {leads.length === 0 && (
              <Card className="col-span-full p-10 text-center">
                <p className="font-serif text-xl text-primary">
                  No inquiries yet.
                </p>

                <p className="mt-2 text-sm text-muted-foreground">
                  The next message could be a
                  memory in waiting.
                </p>
              </Card>
            )}
          </div>
        )}
    </AppShell>
  );
}

function Field({
  k,
  v,
}: {
  k: string;
  v: string;
}) {
  return (
    <div>
      <dt className="text-[10px] uppercase tracking-wider text-muted-foreground">
        {k}
      </dt>

      <dd className="text-primary">
        {v || "—"}
      </dd>
    </div>
  );
}
