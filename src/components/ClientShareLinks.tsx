import { ShieldAlert } from "lucide-react";

export function ClientShareLinks({
  bookingId,
  payload,
}: {
  bookingId: string;
  payload: Record<string, string | number | boolean>;
}) {
  void bookingId;
  void payload;

  return (
    <div className="mt-4 rounded-xl border border-border bg-card px-4 py-4">
      <div className="flex items-start gap-3">
        <ShieldAlert className="mt-0.5 h-4 w-4 flex-none text-gold" />

        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Family-facing links
          </div>

          <p className="mt-1 text-xs leading-5 text-muted-foreground">
            Family share links are temporarily unavailable while they are rebuilt on the canonical
            privacy, quotation, booking, and delivery records.
          </p>

          <p className="mt-2 text-xs leading-5 text-muted-foreground">
            No proposal acceptance, consent choice, review, or journey state is written from this
            control.
          </p>
        </div>
      </div>
    </div>
  );
}
