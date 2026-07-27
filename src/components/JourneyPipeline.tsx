import { useStore } from "@/store/useStore";
import { journeyStages, type JourneyStage } from "@/lib/mock-data";
import { handle } from "@/lib/handle";
import { can } from "@/lib/access";
import { useSession } from "@/lib/session";
import { Check, Circle } from "lucide-react";

export function JourneyPipeline({ bookingId }: { bookingId: string }) {
  const booking = useStore((s) => s.bookings.find((b) => b.id === bookingId));
  const setJourneyStage = useStore((s) => s.setJourneyStage);
  const requestReview = useStore((s) => s.requestReview);
  const skipAftercare = useStore((s) => s.skipAftercare);
  const { roles } = useSession();
  const mayAdvance = can("pipeline.advance", roles);
  if (!booking) return null;

  const currentIdx = journeyStages.indexOf(booking.journeyStage);

  return (
    <div className="mt-5 rounded-xl border border-border bg-[var(--gradient-warm)]/60 px-4 py-4">
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <div>
          <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
            Client Journey Pipeline
          </div>
          <div className="font-serif text-base text-primary mt-0.5">
            {booking.journeyStage}{" "}
            <span className="text-xs text-muted-foreground">
              · {currentIdx + 1}/{journeyStages.length}
            </span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <select
            value={booking.journeyStage}
            disabled={!mayAdvance}
            onChange={(e) => handle(setJourneyStage(bookingId, e.target.value as JourneyStage))}
            className="text-xs bg-card text-primary border border-gold rounded-lg px-2.5 py-1.5 disabled:opacity-50"
          >
            {journeyStages.map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
          {mayAdvance && currentIdx < journeyStages.length - 1 && (
            <button
              onClick={() =>
                handle(setJourneyStage(bookingId, journeyStages[currentIdx + 1]))
              }
              className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground"
            >
              Advance →
            </button>
          )}
        </div>
      </div>

      {!mayAdvance && (
        <p className="mb-3 text-[11px] italic text-muted-foreground">
          Only a Founder or Client Coordinator can move a family's journey stage.
        </p>
      )}

      <ol className="flex flex-wrap gap-1.5">
        {journeyStages.map((s, i) => {
          const done = i < currentIdx;
          const current = i === currentIdx;
          return (
            <li
              key={s}
              className={`flex items-center gap-1.5 text-[10.5px] px-2 py-1 rounded-full border ${
                current
                  ? "bg-[var(--gradient-gold)] text-primary border-gold"
                  : done
                    ? "bg-card text-primary/80 border-border"
                    : "bg-transparent text-muted-foreground border-border/60"
              }`}
              title={s}
            >
              {done ? (
                <Check className="h-2.5 w-2.5" />
              ) : (
                <Circle className={`h-2 w-2 ${current ? "fill-gold text-gold" : ""}`} />
              )}
              <span>{s}</span>
            </li>
          );
        })}
      </ol>

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <button
          onClick={() => handle(requestReview(bookingId))}
          disabled={booking.reviewRequested || !can("reviews.write", roles)}
          className="text-[11px] px-3 py-1.5 rounded-lg border border-border bg-card text-primary disabled:opacity-40"
        >
          {booking.reviewRequested ? "Review requested ✓" : "Request review"}
        </button>
        <button
          onClick={() => {
            const reason = window.prompt(
              "Reason to intentionally skip aftercare for this family?",
            );
            if (reason) handle(skipAftercare(bookingId, reason));
          }}
          disabled={!!booking.aftercareSkipReason || !mayAdvance}
          className="text-[11px] px-3 py-1.5 rounded-lg border border-border bg-card text-primary disabled:opacity-40"
        >
          {booking.aftercareSkipReason
            ? `Aftercare skipped: ${booking.aftercareSkipReason}`
            : "Skip aftercare with reason"}
        </button>
      </div>
    </div>
  );
}