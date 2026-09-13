import { useMemo, useState, type ReactNode } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";

import { Card, StatusPill } from "@/components/AppShell";
import {
  listDeliveryWorkspace,
  type DeliveryCapabilities,
  type DeliveryWorkspaceData,
} from "@/lib/delivery.functions";

export const DELIVERY_QUERY_KEY = ["delivery-workspace"] as const;

export function useDeliveryWorkspace() {
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: DELIVERY_QUERY_KEY,
    queryFn: () => listDeliveryWorkspace(),
  });

  const refresh = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: DELIVERY_QUERY_KEY }),
      queryClient.invalidateQueries({ queryKey: ["booking-workspace"] }),
    ]);
  };

  return { query, refresh };
}

export type BookingView = {
  id: string;
  reference: string;
  familyName: string;
  stageOrder: number;
  stageLabel: string;
  capabilities: DeliveryCapabilities;
};

const noCapabilities: DeliveryCapabilities = {
  canAssignEditing: false,
  canCompleteEditing: false,
  canReviewQc: false,
  canConfirmDelivery: false,
  canOverrideBalance: false,
  canManageProduction: false,
  canRequestReview: false,
  canPlanMilestone: false,
  canAdvanceStage: false,
};

/** Bookings currently sitting in the given journey stages, newest first. */
export function useBookingsAtStages(
  data: DeliveryWorkspaceData | undefined,
  stageOrders: number[],
): BookingView[] {
  return useMemo(() => {
    if (!data) return [];

    const stageById = new Map(data.journeyStages.map((stage) => [stage.id, stage]));
    const familyById = new Map(data.families.map((family) => [family.id, family]));
    const stateByBooking = new Map(data.journeyStates.map((state) => [state.booking_id, state]));

    return data.bookings
      .map((booking) => {
        const state = stateByBooking.get(booking.id);
        const stage = state ? stageById.get(state.current_stage_id) : undefined;
        if (!stage) return null;

        const family = booking.family_id ? familyById.get(booking.family_id) : undefined;

        return {
          id: booking.id,
          reference: booking.booking_reference,
          familyName: family?.display_name ?? "Family not linked",
          stageOrder: stage.stage_order,
          stageLabel: stage.label,
          capabilities: data.capabilities[booking.id] ?? noCapabilities,
        } satisfies BookingView;
      })
      .filter((view): view is BookingView => view !== null && stageOrders.includes(view.stageOrder))
      .sort((a, b) => a.stageOrder - b.stageOrder || a.reference.localeCompare(b.reference));
  }, [data, stageOrders]);
}

export function rowsFor<T extends { booking_id: string }>(rows: T[], bookingId: string): T[] {
  return rows.filter((row) => row.booking_id === bookingId);
}

export function latestBy<T>(rows: T[], key: (row: T) => number): T | undefined {
  return rows.reduce<T | undefined>(
    (best, row) => (best === undefined || key(row) > key(best) ? row : best),
    undefined,
  );
}

export function formatDate(value: string | null) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
}

export function formatDateTime(value: string | null) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

export function formatInr(paise: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(paise);
}

/* ───────────── Form primitives, matching the studio look ───────────── */

const fieldBase =
  "mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm disabled:opacity-60";

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</span>
      {children}
    </label>
  );
}

export function TextInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  const { className = "", ...rest } = props;
  return <input {...rest} className={`${fieldBase} ${className}`} />;
}

export function Select(props: React.SelectHTMLAttributes<HTMLSelectElement>) {
  const { className = "", children, ...rest } = props;
  return (
    <select {...rest} className={`${fieldBase} ${className}`}>
      {children}
    </select>
  );
}

export function Checkbox({
  label,
  checked,
  onChange,
  id,
}: {
  label: string;
  checked: boolean;
  onChange: (next: boolean) => void;
  id: string;
}) {
  return (
    <label htmlFor={id} className="flex items-center gap-2 text-sm text-foreground">
      <input
        id={id}
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
        className="h-4 w-4 rounded border-border"
      />
      {label}
    </label>
  );
}

export function ActionButton({
  children,
  onClick,
  disabled,
  busy,
  tone = "primary",
  type = "button",
}: {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  busy?: boolean;
  tone?: "primary" | "quiet";
  type?: "button" | "submit";
}) {
  const tones = {
    primary: "bg-primary text-primary-foreground hover:opacity-90",
    quiet: "border border-border bg-background text-foreground hover:bg-accent/50",
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || busy}
      className={`inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium disabled:opacity-60 ${tones[tone]}`}
    >
      {busy && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
      {children}
    </button>
  );
}

export function BookingCard({
  booking,
  children,
  aside,
}: {
  booking: BookingView;
  children: ReactNode;
  aside?: ReactNode;
}) {
  return (
    <Card className="p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="font-serif text-lg text-primary">{booking.familyName}</div>
          <div className="mt-0.5 text-xs text-muted-foreground">{booking.reference}</div>
        </div>
        <div className="flex items-center gap-2">
          {aside}
          <StatusPill tone="gold">{booking.stageLabel}</StatusPill>
        </div>
      </div>
      <div className="mt-4 space-y-4">{children}</div>
    </Card>
  );
}

export function EvidenceLine({ children }: { children: ReactNode }) {
  return <div className="text-xs text-muted-foreground">{children}</div>;
}

export function Blocked({ reason }: { reason: string }) {
  return (
    <div className="rounded-lg border border-border bg-muted/40 px-3 py-2 text-xs text-muted-foreground">
      {reason}
    </div>
  );
}

export function ErrorNote({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <div className="rounded-lg border border-border bg-[oklch(0.96_0.03_25)] px-3 py-2 text-xs text-[oklch(0.4_0.12_25)]">
      {message}
    </div>
  );
}

export function BoardState({
  query,
  emptyTitle,
  emptyBody,
  count,
}: {
  query: { isLoading: boolean; isError: boolean; error: unknown };
  emptyTitle: string;
  emptyBody: string;
  count: number;
}) {
  if (query.isLoading) {
    return (
      <Card className="p-8 text-center text-sm text-muted-foreground">
        <Loader2 className="mx-auto mb-3 h-5 w-5 animate-spin" />
        Opening the studio records…
      </Card>
    );
  }

  if (query.isError) {
    return (
      <Card className="p-8 text-center text-sm text-muted-foreground">
        {query.error instanceof Error ? query.error.message : "This room could not be loaded."}
      </Card>
    );
  }

  if (count === 0) {
    return (
      <Card className="p-8 text-center">
        <div className="font-serif text-lg text-primary">{emptyTitle}</div>
        <p className="mx-auto mt-2 max-w-md text-sm italic text-muted-foreground">{emptyBody}</p>
      </Card>
    );
  }

  return null;
}

/** Runs a sequence of server calls as one studio action. */
export function useChainedAction(refresh: () => Promise<void>) {
  const [error, setError] = useState<string | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: async ({ steps }: { id: string; steps: Array<() => Promise<unknown>> }) => {
      for (const step of steps) {
        await step();
      }
    },
    onMutate: ({ id }) => {
      setError(null);
      setActiveId(id);
    },
    onError: (cause) => {
      setError(cause instanceof Error ? cause.message : "That action could not be completed.");
    },
    onSettled: async () => {
      setActiveId(null);
      await refresh();
    },
  });

  return {
    error,
    clearError: () => setError(null),
    isBusy: (id: string) => mutation.isPending && activeId === id,
    run: (id: string, steps: Array<() => Promise<unknown>>) => mutation.mutate({ id, steps }),
  };
}
