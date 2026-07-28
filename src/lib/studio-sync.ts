import { useEffect, useRef, useState } from "react";
import { create } from "zustand";
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
const db = supabase as unknown as { from: (table: string) => any };

const collections = Object.keys(collectionTables) as (keyof StoreData)[];

/* ───────────── Save status (shown in the app header) ───────────── */

type SaveState = {
  status: "idle" | "saving" | "saved" | "error";
  lastSavedAt: number | null;
  pending: number;
  retry: () => void;
  setRetry: (fn: () => void) => void;
};

export const useSaveStatus = create<SaveState>((set) => ({
  status: "idle",
  lastSavedAt: null,
  pending: 0,
  retry: () => {},
  setRetry: (fn) => set({ retry: fn }),
}));

/* ───────────── Change tracking ───────────── */

function snapshot(state: StoreData) {
  const map = {} as Record<keyof StoreData, Map<string, string>>;
  for (const c of collections) {
    const m = new Map<string, string>();
    for (const row of state[c] as AnyRecord[]) m.set(recordKey(c, row), JSON.stringify(row));
    map[c] = m;
  }
  return map;
}

type Queue = Record<string, { upserts: Map<string, AnyRecord>; deletes: Set<string> }>;

function emptyQueue(): Queue {
  const q: Queue = {};
  for (const c of collections) q[c] = { upserts: new Map(), deletes: new Set() };
  return q;
}

async function flushQueue(queue: Queue) {
  for (const c of collections) {
    const table = collectionTables[c];
    const { upserts, deletes } = queue[c];
    if (upserts.size) {
      const rows = [...upserts.entries()].map(([id, data]) => ({ id, data }));
      const { error } = await db.from(table).upsert(rows);
      if (error) throw new Error(`${table}: ${error.message}`);
      upserts.clear();
    }
    if (deletes.size) {
      const ids = [...deletes];
      const { error } = await db.from(table).delete().in("id", ids);
      if (error) throw new Error(`${table}: ${error.message}`);
      deletes.clear();
    }
  }
}

function queueSize(queue: Queue) {
  return collections.reduce((n, c) => n + queue[c].upserts.size + queue[c].deletes.size, 0);
}

/* ───────────── Setup marker (so starter records seed only once) ───────────── */

async function hasSeeded() {
  const { data } = await db.from("studio_meta").select("key").eq("key", "seeded").maybeSingle();
  return Boolean(data);
}

async function markSeeded() {
  await db.from("studio_meta").upsert({ key: "seeded", value: { at: new Date().toISOString() } });
}

async function pullAll() {
  const results = await Promise.all(
    collections.map(async (c) => {
      const { data, error } = await db.from(collectionTables[c]).select("data");
      if (error) throw new Error(error.message);
      return [c, (data ?? []).map((r: { data: AnyRecord }) => r.data)] as const;
    }),
  );
  return Object.fromEntries(results) as Record<keyof StoreData, AnyRecord[]>;
}

async function pushAll(state: StoreData) {
  const queue = emptyQueue();
  for (const c of collections) {
    for (const row of state[c] as AnyRecord[]) queue[c].upserts.set(recordKey(c, row), row);
  }
  await flushQueue(queue);
}

export function useStudioSync(enabled: boolean) {
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const started = useRef(false);

  useEffect(() => {
    if (!enabled || started.current) return;
    started.current = true;

    const queue = emptyQueue();
    let flushing = false;
    let previous = snapshot(useStore.getState() as unknown as StoreData);
    let suspended = false;

    const report = () => useSaveStatus.setState({ pending: queueSize(queue) });

    const flush = async () => {
      if (flushing || !queueSize(queue)) return;
      flushing = true;
      useSaveStatus.setState({ status: "saving" });
      try {
        await flushQueue(queue);
        useSaveStatus.setState({ status: "saved", lastSavedAt: Date.now(), pending: 0 });
      } catch (error) {
        console.error("[studio-sync] save failed", error);
        useSaveStatus.setState({ status: "error", pending: queueSize(queue) });
      } finally {
        flushing = false;
      }
    };

    useSaveStatus.getState().setRetry(() => void flush());

    const watch = () =>
      useStore.subscribe((state) => {
        if (suspended) return;
        const next = snapshot(state as unknown as StoreData);
        for (const c of collections) {
          const before = previous[c];
          const after = next[c];
          after.forEach((json, key) => {
            if (before.get(key) !== json) {
              queue[c].upserts.set(key, JSON.parse(json));
              queue[c].deletes.delete(key);
            }
          });
          before.forEach((_json, key) => {
            if (!after.has(key)) {
              queue[c].deletes.add(key);
              queue[c].upserts.delete(key);
            }
          });
        }
        previous = next;
        report();
        void flush();
      });

    let unsubscribe: (() => void) | undefined;

    const refresh = async () => {
      if (queueSize(queue) || flushing) return;
      try {
        const fetched = await pullAll();
        suspended = true;
        useStore.getState().hydrateFromDb(fetched as unknown as Partial<StoreData>);
        previous = snapshot(useStore.getState() as unknown as StoreData);
        suspended = false;
      } catch (error) {
        console.error("[studio-sync] refresh failed", error);
      }
    };

    const onFocus = () => void refresh();

    (async () => {
      try {
        const seeded = await hasSeeded();
        const fetched = await pullAll();
        const total = collections.reduce((n, c) => n + fetched[c].length, 0);

        if (!seeded && total === 0) {
          // First run for this studio — save the starter records so they persist.
          await pushAll(useStore.getState() as unknown as StoreData);
          await markSeeded();
        } else {
          if (!seeded) await markSeeded();
          suspended = true;
          useStore.getState().hydrateFromDb(fetched as unknown as Partial<StoreData>);
          suspended = false;
        }

        previous = snapshot(useStore.getState() as unknown as StoreData);
        useSaveStatus.setState({ status: "saved", lastSavedAt: Date.now(), pending: 0 });
        setStatus("ready");

        unsubscribe = watch();
        window.addEventListener("focus", onFocus);
      } catch (error) {
        console.error("[studio-sync]", error);
        setStatus("error");
      }
    })();

    return () => {
      unsubscribe?.();
      window.removeEventListener("focus", onFocus);
    };
  }, [enabled]);

  return status;
}
