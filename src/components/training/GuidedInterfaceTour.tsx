import { useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ChevronLeft, ChevronRight, RotateCcw, X } from "lucide-react";

import { recordTrainingStep } from "@/lib/training.functions";
import { guidedInterfaceTourSteps, TRAINING_NAVIGATION_EVENT } from "@/lib/training/interface-tour";

type TargetRect = {
  top: number;
  left: number;
  width: number;
  height: number;
};

const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  '[tabindex]:not([tabindex="-1"])',
].join(",");

type GuidedInterfaceTourProps = {
  moduleKey: string;
  version: number;
  stepKey: string;
  onComplete: () => Promise<boolean>;
  onClose: () => void;
};

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "The guided tour could not continue.";
}

function findVisibleTarget(target: string): HTMLElement | null {
  const candidates = Array.from(document.querySelectorAll<HTMLElement>(`[data-tour="${target}"]`));

  return (
    candidates.find((element) => {
      const rect = element.getBoundingClientRect();
      const style = window.getComputedStyle(element);

      return (
        rect.width > 0 &&
        rect.height > 0 &&
        style.display !== "none" &&
        style.visibility !== "hidden"
      );
    }) ?? null
  );
}

function measureTarget(element: HTMLElement): TargetRect {
  const rect = element.getBoundingClientRect();

  return {
    top: rect.top,
    left: rect.left,
    width: rect.width,
    height: rect.height,
  };
}

function dispatchNavigation(open: boolean) {
  window.dispatchEvent(
    new CustomEvent(TRAINING_NAVIGATION_EVENT, {
      detail: { open },
    }),
  );
}

function delay(milliseconds: number) {
  return new Promise<void>((resolve) => {
    window.setTimeout(resolve, milliseconds);
  });
}

export function GuidedInterfaceTour({
  moduleKey,
  version,
  stepKey,
  onComplete,
  onClose,
}: GuidedInterfaceTourProps) {
  const [index, setIndex] = useState(0);
  const [targetRect, setTargetRect] = useState<TargetRect | null>(null);
  const [status, setStatus] = useState<"resolving" | "ready" | "broken">("resolving");
  const [message, setMessage] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);
  const [finishing, setFinishing] = useState(false);

  const viewedTargets = useRef(new Set<string>());
  const brokenTargets = useRef(new Set<string>());

  const dialogRef = useRef<HTMLElement | null>(null);
  const portalRootRef = useRef<HTMLDivElement | null>(null);
  const onCloseRef = useRef(onClose);

  const tourStep = guidedInterfaceTourSteps[index];

  const isLast = index === guidedInterfaceTourSteps.length - 1;

  const progress = useMemo(
    () => Math.round(((index + 1) / guidedInterfaceTourSteps.length) * 100),
    [index],
  );

  useEffect(() => {
    if (!tourStep) return;

    let cancelled = false;

    const resolveTarget = async () => {
      setStatus("resolving");
      setMessage(null);
      setTargetRect(null);

      if (tourStep.openNavigation) {
        dispatchNavigation(true);
      }

      await delay(140);

      if (cancelled) return;

      let target = findVisibleTarget(tourStep.target);

      if (target) {
        target.scrollIntoView({
          behavior: "smooth",
          block: "center",
          inline: "nearest",
        });

        await delay(180);

        if (cancelled) return;

        target = findVisibleTarget(tourStep.target);
      }

      if (!target) {
        setStatus("broken");

        const brokenMessage =
          `The guided tour could not find the required interface target "${tourStep.target}". ` +
          "Nothing was skipped or marked complete.";

        setMessage(brokenMessage);

        if (!brokenTargets.current.has(tourStep.target)) {
          brokenTargets.current.add(tourStep.target);

          try {
            await recordTrainingStep({
              data: {
                moduleKey,
                version,
                stepKey,
                eventType: "training_step_broken",
                result: "fail",
                metadata: {
                  source: "guided-interface-tour",
                  tourStep: tourStep.key,
                  tourTarget: tourStep.target,
                },
              },
            });
          } catch (error) {
            if (!cancelled) {
              setMessage(
                `${brokenMessage} The failure evidence also could not be recorded: ${getErrorMessage(
                  error,
                )}`,
              );
            }
          }
        }

        return;
      }

      const measured = measureTarget(target);

      if (!cancelled) {
        setTargetRect(measured);
      }

      if (!viewedTargets.current.has(tourStep.target)) {
        try {
          await recordTrainingStep({
            data: {
              moduleKey,
              version,
              stepKey,
              eventType: "step_viewed",
              result: "info",
              metadata: {
                source: "guided-interface-tour",
                tourStep: tourStep.key,
                tourTarget: tourStep.target,
              },
            },
          });

          viewedTargets.current.add(tourStep.target);
        } catch (error) {
          if (!cancelled) {
            setStatus("broken");
            setMessage(
              `The interface target was found, but the tour view evidence could not be recorded: ${getErrorMessage(
                error,
              )}`,
            );
          }

          return;
        }
      }

      if (!cancelled) {
        setStatus("ready");
      }
    };

    void resolveTarget();

    return () => {
      cancelled = true;
    };
  }, [moduleKey, retryKey, stepKey, tourStep, version]);

  useEffect(() => {
    if (!tourStep) return;

    const updatePosition = () => {
      const target = findVisibleTarget(tourStep.target);

      if (target) {
        setTargetRect(measureTarget(target));
      }
    };

    window.addEventListener("resize", updatePosition);

    window.addEventListener("scroll", updatePosition, true);

    return () => {
      window.removeEventListener("resize", updatePosition);

      window.removeEventListener("scroll", updatePosition, true);
    };
  }, [tourStep]);

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (typeof document === "undefined") {
      return;
    }

    const dialog = dialogRef.current;
    const portalRoot = portalRootRef.current;

    if (!dialog || !portalRoot) {
      return;
    }

    const previousFocus =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;

    const backgroundElements = Array.from(document.body.children).filter(
      (element): element is HTMLElement => element instanceof HTMLElement && element !== portalRoot,
    );

    const backgroundState = backgroundElements.map((element) => ({
      element,
      inert: element.inert,
      ariaHidden: element.getAttribute("aria-hidden"),
    }));

    const getFocusableElements = () =>
      Array.from(dialog.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter(
        (element) =>
          !element.hasAttribute("hidden") && element.getAttribute("aria-hidden") !== "true",
      );

    const initialTarget = getFocusableElements()[0] ?? dialog;

    initialTarget.focus();

    for (const element of backgroundElements) {
      element.inert = true;
      element.setAttribute("aria-hidden", "true");
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        dispatchNavigation(false);
        onCloseRef.current();
        return;
      }

      if (event.key !== "Tab") {
        return;
      }

      const focusable = getFocusableElements();

      if (focusable.length === 0) {
        event.preventDefault();
        dialog.focus();
        return;
      }

      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      const active = document.activeElement;

      if (event.shiftKey && (active === first || !dialog.contains(active))) {
        event.preventDefault();
        last.focus();
        return;
      }

      if (!event.shiftKey && (active === last || !dialog.contains(active))) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown, true);

    return () => {
      document.removeEventListener("keydown", handleKeyDown, true);

      for (const { element, inert, ariaHidden } of backgroundState) {
        element.inert = inert;

        if (ariaHidden === null) {
          element.removeAttribute("aria-hidden");
        } else {
          element.setAttribute("aria-hidden", ariaHidden);
        }
      }

      if (previousFocus?.isConnected) {
        previousFocus.focus();
      }
    };
  }, []);

  useEffect(
    () => () => {
      dispatchNavigation(false);
    },
    [],
  );

  if (typeof document === "undefined" || !tourStep) {
    return null;
  }

  async function handleNext() {
    if (status !== "ready" || finishing) {
      return;
    }

    if (!isLast) {
      setIndex((current) => current + 1);
      return;
    }

    setFinishing(true);
    setMessage(null);

    try {
      const completed = await onComplete();

      if (!completed) {
        setMessage(
          "The interface tour was viewed, but the training step could not be completed. Nothing was silently advanced. Please retry.",
        );
        return;
      }

      dispatchNavigation(false);
      onClose();
    } finally {
      setFinishing(false);
    }
  }

  function handleClose() {
    dispatchNavigation(false);
    onClose();
  }

  return createPortal(
    <div ref={portalRootRef}>
      <div className="fixed inset-0 z-[65]" aria-hidden="true" />

      {targetRect && (
        <div
          aria-hidden="true"
          className="pointer-events-none fixed z-[70] rounded-xl border-2 border-primary transition-all duration-200"
          style={{
            top: Math.max(targetRect.top - 8, 8),
            left: Math.max(targetRect.left - 8, 8),
            width: targetRect.width + 16,
            height: targetRect.height + 16,
            boxShadow: "0 0 0 9999px rgb(31 22 18 / 0.42)",
          }}
        />
      )}

      <section
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        tabIndex={-1}
        aria-labelledby="guided-tour-title"
        className="fixed inset-x-0 bottom-0 z-[80] rounded-t-2xl border border-border bg-card p-5 shadow-2xl lg:inset-x-auto lg:bottom-6 lg:right-6 lg:w-[390px] lg:rounded-2xl"
      >
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="text-[10px] uppercase tracking-[0.22em] text-muted-foreground">
              {tourStep.eyebrow}
            </div>

            <h2 id="guided-tour-title" className="mt-2 font-serif text-xl text-primary">
              {tourStep.title}
            </h2>
          </div>

          <button
            type="button"
            onClick={handleClose}
            aria-label="Close guided tour"
            className="rounded-lg border border-border p-2 text-muted-foreground hover:bg-muted"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <p className="mt-3 text-sm leading-relaxed text-muted-foreground">{tourStep.body}</p>

        <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-muted">
          <div
            className="h-full rounded-full bg-primary transition-[width]"
            style={{
              width: `${progress}%`,
            }}
          />
        </div>

        <div className="mt-2 text-xs text-muted-foreground">
          Tour step {index + 1} of {guidedInterfaceTourSteps.length}
        </div>

        {status === "resolving" && (
          <div className="mt-4 rounded-xl border border-border bg-muted/40 p-3 text-sm text-muted-foreground">
            Locating this part of the interface…
          </div>
        )}

        {status === "broken" && (
          <div
            role="alert"
            className="mt-4 rounded-xl border border-destructive/30 bg-destructive/5 p-4"
          >
            <div className="text-sm font-medium text-destructive">Guided tour stopped safely</div>

            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{message}</p>

            <button
              type="button"
              onClick={() => setRetryKey((current) => current + 1)}
              className="mt-3 inline-flex items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm text-primary hover:bg-muted"
            >
              <RotateCcw className="h-4 w-4" />
              Retry target
            </button>
          </div>
        )}

        {status === "ready" && message && (
          <div
            role="alert"
            className="mt-4 rounded-xl border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive"
          >
            {message}
          </div>
        )}

        <div className="mt-5 flex items-center justify-between gap-3">
          <button
            type="button"
            onClick={() => setIndex((current) => Math.max(0, current - 1))}
            disabled={index === 0 || status === "resolving" || finishing}
            className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-2 text-sm text-primary disabled:opacity-40"
          >
            <ChevronLeft className="h-4 w-4" />
            Back
          </button>

          <button
            type="button"
            onClick={handleNext}
            disabled={status !== "ready" || finishing}
            className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground disabled:opacity-50"
          >
            {finishing ? "Saving…" : isLast ? "Finish tour" : "Next"}

            {!finishing && <ChevronRight className="h-4 w-4" />}
          </button>
        </div>
      </section>
    </div>,
    document.body,
  );
}
