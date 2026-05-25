import { useState } from "react";
import { useStore } from "@/store/useStore";
import type { MemoryProfileOwner } from "@/store/useStore";
import { handle } from "@/lib/handle";
import { legacyInterestOptions, emotionalPriorityOptions } from "@/lib/mock-data";
import { Heart, ChevronDown, ChevronUp, Save } from "lucide-react";

export function MemoryProfileCard({
  ownerType,
  ownerId,
  defaultGoal,
  startOpen = false,
}: {
  ownerType: MemoryProfileOwner;
  ownerId: string;
  defaultGoal?: string;
  startOpen?: boolean;
}) {
  const existing = useStore((s) =>
    s.memoryProfiles.find((p) => p.ownerType === ownerType && p.ownerId === ownerId),
  );
  const upsert = useStore((s) => s.upsertMemoryProfile);
  const [open, setOpen] = useState(startOpen || !!existing);
  const [draft, setDraft] = useState({
    memoryGoal: existing?.memoryGoal ?? defaultGoal ?? "",
    familyStory: existing?.familyStory ?? "",
    importantPeople: existing?.importantPeople ?? "",
    mustCaptureMoments: existing?.mustCaptureMoments ?? "",
    comfortNeeds: existing?.comfortNeeds ?? "",
    sensitivities: existing?.sensitivities ?? "",
    legacyInterest: existing?.legacyInterest ?? ("None" as const),
    emotionalPriority: existing?.emotionalPriority ?? ("Simple Memory" as const),
    notesPhotographer: existing?.notesPhotographer ?? "",
    notesEditor: existing?.notesEditor ?? "",
    notesAlbumDesigner: existing?.notesAlbumDesigner ?? "",
  });

  const set = <K extends keyof typeof draft>(k: K, v: (typeof draft)[K]) =>
    setDraft((d) => ({ ...d, [k]: v }));

  return (
    <div className="mt-4 rounded-xl border border-gold/40 bg-[var(--gradient-warm)]">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-start gap-3 px-4 py-3 text-left"
      >
        <span className="mt-0.5 rounded-full bg-card p-1.5">
          <Heart className="h-3.5 w-3.5 text-gold" />
        </span>
        <span className="flex-1 min-w-0">
          <span className="block text-[10px] uppercase tracking-wider text-muted-foreground">
            Memory Profile {existing ? "· on record" : "· not captured yet"}
          </span>
          <span className="block font-serif text-base text-primary italic truncate">
            {draft.memoryGoal
              ? `“${draft.memoryGoal}”`
              : "What moment do they want to preserve?"}
          </span>
        </span>
        {open ? (
          <ChevronUp className="h-4 w-4 text-muted-foreground shrink-0" />
        ) : (
          <ChevronDown className="h-4 w-4 text-muted-foreground shrink-0" />
        )}
      </button>

      {open && (
        <div className="px-4 pb-4 space-y-3 border-t border-gold/30 pt-3">
          <Field label="Emotional memory goal (what they want to preserve)" highlight>
            <textarea
              value={draft.memoryGoal}
              onChange={(e) => set("memoryGoal", e.target.value)}
              rows={2}
              className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm font-serif italic text-primary"
              placeholder="e.g. Her giggles when she sees her dad"
            />
          </Field>

          <div className="grid sm:grid-cols-2 gap-3">
            <Field label="Family story notes">
              <Area v={draft.familyStory} on={(v) => set("familyStory", v)} />
            </Field>
            <Field label="Most important people">
              <Area v={draft.importantPeople} on={(v) => set("importantPeople", v)} />
            </Field>
            <Field label="Must-capture moments">
              <Area v={draft.mustCaptureMoments} on={(v) => set("mustCaptureMoments", v)} />
            </Field>
            <Field label="Comfort needs">
              <Area v={draft.comfortNeeds} on={(v) => set("comfortNeeds", v)} />
            </Field>
            <Field label="Sensitivities">
              <Area v={draft.sensitivities} on={(v) => set("sensitivities", v)} />
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <Field label="Legacy interest">
                <select
                  value={draft.legacyInterest}
                  onChange={(e) => set("legacyInterest", e.target.value as typeof draft.legacyInterest)}
                  className="w-full rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary"
                >
                  {legacyInterestOptions.map((o) => <option key={o}>{o}</option>)}
                </select>
              </Field>
              <Field label="Emotional priority">
                <select
                  value={draft.emotionalPriority}
                  onChange={(e) => set("emotionalPriority", e.target.value as typeof draft.emotionalPriority)}
                  className="w-full rounded-lg border border-border bg-card px-2 py-2 text-sm text-primary"
                >
                  {emotionalPriorityOptions.map((o) => <option key={o}>{o}</option>)}
                </select>
              </Field>
            </div>
          </div>

          <div className="grid sm:grid-cols-3 gap-3">
            <Field label="Notes for photographer">
              <Area v={draft.notesPhotographer} on={(v) => set("notesPhotographer", v)} />
            </Field>
            <Field label="Notes for editor">
              <Area v={draft.notesEditor} on={(v) => set("notesEditor", v)} />
            </Field>
            <Field label="Notes for album designer">
              <Area v={draft.notesAlbumDesigner} on={(v) => set("notesAlbumDesigner", v)} />
            </Field>
          </div>

          <div className="flex items-center justify-end gap-2 pt-1">
            <button
              type="button"
              onClick={() => handle(upsert(ownerType, ownerId, draft))}
              className="inline-flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground"
            >
              <Save className="h-3 w-3" /> Save Memory Profile
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Field({
  label,
  children,
  highlight,
}: {
  label: string;
  children: React.ReactNode;
  highlight?: boolean;
}) {
  return (
    <label className="block">
      <span
        className={`block text-[10px] uppercase tracking-wider mb-1 ${
          highlight ? "text-gold font-medium" : "text-muted-foreground"
        }`}
      >
        {label}
      </span>
      {children}
    </label>
  );
}

function Area({ v, on }: { v: string; on: (v: string) => void }) {
  return (
    <textarea
      value={v}
      onChange={(e) => on(e.target.value)}
      rows={2}
      className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-primary"
    />
  );
}