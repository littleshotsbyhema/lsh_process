import { useEffect, useRef, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useStore, type StoreData } from "@/store/useStore";

/* Each studio module has its own table; records are stored as { id, data }. */
export const collectionTables: Record<keyof StoreData, string> = {
  leads: "leads",
  clients: "clients",
  bookings: "bookings",
  privacy: "privacy_records",
  safety: "safety_submissions",
  editing: "editing_jobs",
  heirloom: "heirloom_jobs",
  memoryProfiles: "memory_profiles",
  pixieset: "pixieset_records",
  followUps: "follow_ups",
  tasks: "tasks",
  reviews: "reviews",
  alignment: "alignment_scores",
  governance: "governance_runs",
};

type AnyRecord = Record<string, unknown>;

export function recordKey(collection: keyof StoreData, row: AnyRecord): string {
  if (collection === "memoryProfiles") return `${row.ownerType}:${row.ownerId}`;
  if (collection === "safety" || collection === "alignment") return String(row.bookingId);
  return String(row.id);
}

// The generated table types are not needed here — rows are opaque JSON documents.
const db = supabase as unknown as {
  from: (table: string) => any;
};

const collections = Object.keys(collectionTables) as (keyof StoreData)[];

function snapshot(state: StoreData) {
  const map = {} as Record<keyof StoreData, Map<string, string>>;
  for (const c of collections) {
    const m = new Map<string, string>();
    for (const row of state[c] as AnyRecord[]) m.set(recordKey(c, row), JSON.stringify(row));
    map[c] = m;
  }
  return map;
}

async function pushAll(state: StoreData) {
  await Promise.all(
    collections.map(async (c) => {
      const rows = (state[c] as AnyRecord[]).map((row) => ({ id: recordKey(c, row), data: row }));
      if (!rows.length) return;
      await db.from(collectionTables[c]).upsert(rows);
    }),
  );
}

export function useStudioSync(enabled: boolean) {
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const started = useRef(false);

  useEffect(() => {
    if (!enabled || started.current) return;
    started.current = true;

    (async () => {
      try {
        const results = await Promise.all(
          collections.map(async (c) => {
            const { data, error } = await db.from(collectionTables[c]).select("data");
            if (error) throw error;
            return [c, (data ?? []).map((r: { data: AnyRecord }) => r.data)] as const;
          }),
        );

        const fetched = Object.fromEntries(results) as Record<keyof StoreData, AnyRecord[]>;
        const total = results.reduce((n, [, rows]) => n + rows.length, 0);

        if (total === 0) {
          // First run for this studio — save the starter records so they persist.
          await pushAll(useStore.getState() as unknown as StoreData);
        } else {
          useStore.getState().hydrateFromDb(fetched as unknown as Partial<StoreData>);
        }

        let previous = snapshot(useStore.getState() as unknown as StoreData);
        setStatus("ready");

        useStore.subscribe((state) => {
          const next = snapshot(state as unknown as StoreData);
          for (const c of collections) {
            const before = previous[c];
            const after = next[c];
            const changed: AnyRecord[] = [];
            after.forEach((json, key) => {
              if (before.get(key) !== json) changed.push({ id: key, data: JSON.parse(json) });
            });
            const removed: string[] = [];
            before.forEach((_json, key) => {
              if (!after.has(key)) removed.push(key);
            });
            if (changed.length) void db.from(collectionTables[c]).upsert(changed);
            if (removed.length) void db.from(collectionTables[c]).delete().in("id", removed);
          }
          previous = next;
        });
      } catch (error) {
        console.error("[studio-sync]", error);
        setStatus("error");
      }
    })();
  }, [enabled]);

  return status;
}