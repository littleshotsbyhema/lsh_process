import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Heart } from "lucide-react";
import {
  AppShell,
  Card,
  PageHeader,
} from "@/components/AppShell";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/memory")({
  head: () => ({
    meta: [
      {
        title: "Memory Profiles · Little Moments OS",
      },
      {
        name: "description",
        content:
          "Emotional memory goals, family stories and milestone context for the studio team.",
      },
      {
        property: "og:title",
        content: "Memory Profiles · Little Moments OS",
      },
      {
        property: "og:description",
        content:
          "Emotional memory goals, family stories and milestone context for the studio team.",
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
  component: MemoryProfilesPage,
});

const ORGANIZATION_ID =
  "590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc";

const MEMORY_QUERY_KEY = [
  "memory-profiles",
  ORGANIZATION_ID,
] as const;

type FamilyStatus =
  | "active"
  | "inactive"
  | "archived"
  | "merged";

type ChildStage =
  | "expected"
  | "newborn"
  | "baby"
  | "sitter"
  | "toddler"
  | "child";

type FamilyRow = {
  id: string;
  organization_id: string;
  family_code: string;
  display_name: string;
  status: FamilyStatus;
};

type ChildRow = {
  id: string;
  organization_id: string;
  family_id: string;
  child_reference: string;
  first_name: string | null;
  current_stage: ChildStage | null;
  status: "active" | "archived";
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
  updated_at: string;
};

type MemoryFamily = FamilyRow & {
  familyMemoryProfile: MemoryProfileRow | null;

  children: Array<
    ChildRow & {
      memoryProfile: MemoryProfileRow | null;
    }
  >;
};

const db = supabase as any;

async function fetchMemoryFamilies(): Promise<
  MemoryFamily[]
> {
  const [
    familiesResult,
    childrenResult,
    profilesResult,
  ] = await Promise.all([
    db
      .from("families")
      .select(
        [
          "id",
          "organization_id",
          "family_code",
          "display_name",
          "status",
        ].join(","),
      )
      .eq("organization_id", ORGANIZATION_ID)
      .order("sort_name", { ascending: true }),

    db
      .from("children")
      .select(
        [
          "id",
          "organization_id",
          "family_id",
          "child_reference",
          "first_name",
          "current_stage",
          "status",
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
          "updated_at",
        ].join(","),
      )
      .eq("organization_id", ORGANIZATION_ID)
      .eq("is_active", true)
      .order("updated_at", { ascending: false }),
  ]);

  if (familiesResult.error) {
    throw new Error(
      familiesResult.error.message ??
        "Could not load families.",
    );
  }

  if (childrenResult.error) {
    throw new Error(
      childrenResult.error.message ??
        "Could not load children.",
    );
  }

  if (profilesResult.error) {
    throw new Error(
      profilesResult.error.message ??
        "Could not load memory profiles.",
    );
  }

  const families =
    (familiesResult.data ?? []) as FamilyRow[];

  const children =
    (childrenResult.data ?? []) as ChildRow[];

  const profiles =
    (profilesResult.data ??
      []) as MemoryProfileRow[];

  return families.map((family) => ({
    ...family,

    familyMemoryProfile:
      profiles.find(
        (profile) =>
          profile.family_id === family.id &&
          profile.child_id === null,
      ) ?? null,

    children: children
      .filter(
        (child) =>
          child.family_id === family.id &&
          child.status === "active",
      )
      .map((child) => ({
        ...child,

        memoryProfile:
          profiles.find(
            (profile) =>
              profile.family_id === family.id &&
              profile.child_id === child.id,
          ) ?? null,
      })),
  }));
}

function MemoryProfilesPage() {
  const memoryQuery = useQuery({
    queryKey: MEMORY_QUERY_KEY,
    queryFn: fetchMemoryFamilies,
    staleTime: 5 * 60 * 1000,
    gcTime: 30 * 60 * 1000,
    refetchOnWindowFocus: false,
    retry: 1,
  });

  const families = memoryQuery.data ?? [];

  const currentFamilies = families.filter(
    (family) =>
      family.status !== "archived" &&
      family.status !== "merged",
  );

  const totalPossibleProfiles =
    currentFamilies.reduce(
      (total, family) =>
        total + 1 + family.children.length,
      0,
    );

  const capturedProfiles =
    currentFamilies.reduce(
      (total, family) => {
        const familyProfile =
          family.familyMemoryProfile ? 1 : 0;

        const childProfiles =
          family.children.filter(
            (child) => child.memoryProfile,
          ).length;

        return (
          total +
          familyProfile +
          childProfiles
        );
      },
      0,
    );

  const coveragePct =
    totalPossibleProfiles > 0
      ? Math.round(
          (capturedProfiles /
            totalPossibleProfiles) *
            100,
        )
      : 0;

  const familiesWithMemory =
    currentFamilies.filter(
      (family) =>
        family.familyMemoryProfile ||
        family.children.some(
          (child) => child.memoryProfile,
        ),
    );

  const familiesMissingMemory =
    currentFamilies.filter(
      (family) =>
        !family.familyMemoryProfile ||
        family.children.some(
          (child) => !child.memoryProfile,
        ),
    );

  return (
    <AppShell>
      <PageHeader
        eyebrow="The story behind the shoot"
        title="Memory Profiles"
        subtitle="The emotional brief for every family — so the photographer, editor, and album designer protect the right moments."
        quote="What moment do they want to preserve?"
      />

      <Card className="mb-6 border-0 bg-[var(--gradient-warm)] p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <span className="rounded-full bg-card p-2.5">
              <Heart className="h-4 w-4 text-gold" />
            </span>

            <div>
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Memory coverage
              </div>

              <div className="font-serif text-2xl text-primary">
                {capturedProfiles} of{" "}
                {totalPossibleProfiles} captured ·{" "}
                {coveragePct}%
              </div>
            </div>
          </div>

          <p className="max-w-md text-xs italic text-primary/70">
            Every captured profile gives the team
            stronger emotional context for the next
            meaningful moment.
          </p>
        </div>
      </Card>

      {memoryQuery.isPending && (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">
            Opening memory profiles…
          </p>

          <p className="mt-2 text-sm text-muted-foreground">
            Gathering the stories and milestones already
            entrusted to the studio.
          </p>
        </Card>
      )}

      {!memoryQuery.isPending &&
        memoryQuery.isError && (
          <Card className="p-10 text-center">
            <p className="font-serif text-xl text-primary">
              We couldn&apos;t open the memory profiles
            </p>

            <p className="mt-2 text-sm text-muted-foreground">
              {getErrorMessage(memoryQuery.error)}
            </p>

            <button
              type="button"
              onClick={() =>
                void memoryQuery.refetch()
              }
              className="mt-4 rounded-lg border border-border px-3 py-2 text-xs text-primary"
            >
              Try again
            </button>
          </Card>
        )}

      {!memoryQuery.isPending &&
        !memoryQuery.isError && (
          <div className="space-y-8">
            <section>
              <SectionHeading
                eyebrow="Captured"
                title="Families with memory context"
                count={familiesWithMemory.length}
              />

              {familiesWithMemory.length > 0 ? (
                <div className="mt-4 space-y-5">
                  {familiesWithMemory.map(
                    (family) => (
                      <MemoryFamilyCard
                        key={family.id}
                        family={family}
                      />
                    ),
                  )}
                </div>
              ) : (
                <Card className="mt-4 p-8 text-center">
                  <p className="font-serif text-lg text-primary">
                    No memory profiles captured yet.
                  </p>

                  <p className="mt-2 text-sm text-muted-foreground">
                    Memory profiles can be created from
                    the Clients page.
                  </p>
                </Card>
              )}
            </section>

            <section>
              <SectionHeading
                eyebrow="Needs attention"
                title="Incomplete memory coverage"
                count={familiesMissingMemory.length}
              />

              {familiesMissingMemory.length >
              0 ? (
                <div className="mt-4 grid gap-4 lg:grid-cols-2">
                  {familiesMissingMemory.map(
                    (family) => (
                      <MissingMemoryCard
                        key={family.id}
                        family={family}
                      />
                    ),
                  )}
                </div>
              ) : (
                <Card className="mt-4 p-8 text-center">
                  <p className="font-serif text-lg text-primary">
                    Memory coverage is complete.
                  </p>
                </Card>
              )}
            </section>
          </div>
        )}
    </AppShell>
  );
}

function MemoryFamilyCard({
  family,
}: {
  family: MemoryFamily;
}) {
  return (
    <Card className="p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
            {family.family_code}
          </div>

          <h2 className="mt-1 font-serif text-xl text-primary">
            {family.display_name}
          </h2>
        </div>

        <Link
          to="/clients"
          className="rounded-lg border border-border px-3 py-1.5 text-xs text-primary hover:bg-muted"
        >
          Open client
        </Link>
      </div>

      <div className="mt-5">
        <ProfileBlock
          title="Family memory profile"
          profile={family.familyMemoryProfile}
        />
      </div>

      {family.children.length > 0 && (
        <div className="mt-5 space-y-4">
          {family.children.map((child) => (
            <div
              key={child.id}
              className="rounded-xl border border-border bg-muted/20 p-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                    {child.child_reference}
                  </div>

                  <div className="mt-1 font-medium text-primary">
                    {child.first_name ||
                      "Child record"}
                  </div>
                </div>

                {child.current_stage && (
                  <span className="rounded-full border border-border px-2 py-0.5 text-[10px] uppercase tracking-wider text-primary">
                    {humanize(
                      child.current_stage,
                    )}
                  </span>
                )}
              </div>

              <div className="mt-4">
                <ProfileBlock
                  title="Child memory profile"
                  profile={child.memoryProfile}
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}

function ProfileBlock({
  title,
  profile,
}: {
  title: string;
  profile: MemoryProfileRow | null;
}) {
  return (
    <div className="rounded-xl border border-border bg-card p-4">
      <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
        {title}
      </div>

      {profile ? (
        <div className="mt-4 space-y-4">
          <MemoryField
            label="Memory goal"
            value={profile.memory_goal}
          />

          <MemoryField
            label="Story notes"
            value={profile.story_notes}
          />

          <MemoryField
            label="Milestone notes"
            value={profile.milestone_notes}
          />

          <MemoryField
            label="Future memory notes"
            value={
              profile.future_memory_notes
            }
          />

          <div>
            <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Emotional tags
            </div>

            {profile.emotional_tags.length >
            0 ? (
              <div className="mt-2 flex flex-wrap gap-2">
                {profile.emotional_tags.map(
                  (tag) => (
                    <span
                      key={tag}
                      className="rounded-full border border-border px-2 py-1 text-[10px] text-primary"
                    >
                      {humanize(tag)}
                    </span>
                  ),
                )}
              </div>
            ) : (
              <div className="mt-1 text-sm text-muted-foreground">
                —
              </div>
            )}
          </div>

          <div className="border-t border-border pt-3 text-[10px] text-muted-foreground">
            Updated{" "}
            {formatDate(profile.updated_at)}
          </div>
        </div>
      ) : (
        <p className="mt-3 text-sm text-muted-foreground">
          No memory profile recorded yet.
        </p>
      )}
    </div>
  );
}

function MissingMemoryCard({
  family,
}: {
  family: MemoryFamily;
}) {
  const missingItems: string[] = [];

  if (!family.familyMemoryProfile) {
    missingItems.push(
      "Family memory profile",
    );
  }

  family.children.forEach((child) => {
    if (!child.memoryProfile) {
      missingItems.push(
        `${child.first_name || child.child_reference} child profile`,
      );
    }
  });

  return (
    <Card className="p-5">
      <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
        {family.family_code}
      </div>

      <h3 className="mt-1 font-serif text-lg text-primary">
        {family.display_name}
      </h3>

      <div className="mt-4 space-y-2">
        {missingItems.map((item) => (
          <div
            key={item}
            className="rounded-lg border border-border bg-muted/20 px-3 py-2 text-sm text-primary"
          >
            {item}
          </div>
        ))}
      </div>

      <Link
        to="/clients"
        className="mt-4 inline-flex rounded-lg border border-border px-3 py-1.5 text-xs text-primary hover:bg-muted"
      >
        Complete in Clients
      </Link>
    </Card>
  );
}

function MemoryField({
  label,
  value,
}: {
  label: string;
  value: string | null;
}) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
        {label}
      </div>

      <div className="mt-1 whitespace-pre-wrap text-sm leading-6 text-primary">
        {value || "—"}
      </div>
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
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div>
        <div className="text-[10px] uppercase tracking-[0.18em] text-muted-foreground">
          {eyebrow}
        </div>

        <h2 className="mt-1 font-serif text-2xl text-primary">
          {title}
        </h2>
      </div>

      <div className="text-xs text-muted-foreground">
        {count}{" "}
        {count === 1 ? "family" : "families"}
      </div>
    </div>
  );
}

function humanize(value: string) {
  return value
    .replaceAll("_", " ")
    .replace(/\b\w/g, (character) =>
      character.toUpperCase(),
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

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  return "Something went wrong.";
}
