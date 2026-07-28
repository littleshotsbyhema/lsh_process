import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import { Share2 } from "lucide-react";
import { createClientLink, listClientResponses } from "@/lib/client-links.functions";

type Kind = "proposal" | "consent" | "delivery";

const labels: Record<Kind, string> = {
  proposal: "Proposal",
  consent: "Consent form",
  delivery: "Delivery & review",
};

export function ClientShareLinks({
  bookingId,
  payload,
}: {
  bookingId: string;
  payload: Record<string, string | number | boolean>;
}) {
  const create = useServerFn(createClientLink);
  const list = useServerFn(listClientResponses);
  const queryClient = useQueryClient();

  const data = useQuery({
    queryKey: ["client-links", bookingId],
    queryFn: () => list({ data: { bookingId } }),
  });

  const make = useMutation({
    mutationFn: (kind: Kind) => create({ data: { kind, bookingId, payload } }),
    onSuccess: async ({ token }) => {
      const url = `${window.location.origin}/f/${token}`;
      try {
        await navigator.clipboard.writeText(url);
        toast.success("Link copied — ready to send to the family.");
      } catch {
        toast.success(`Link ready: ${url}`);
      }
      void queryClient.invalidateQueries({ queryKey: ["client-links", bookingId] });
    },
    onError: (e: unknown) => toast.error(e instanceof Error ? e.message : "Could not create link."),
  });

  const links = (data.data?.links ?? []) as { token: string; kind: Kind }[];
  const responses = (data.data?.responses ?? []) as { token: string; kind: string }[];

  return (
    <div className="mt-4 rounded-xl border border-border bg-card px-4 py-3">
      <div className="flex items-center gap-2">
        <Share2 className="h-3.5 w-3.5 text-gold" />
        <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
          Family-facing links
        </div>
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        {(Object.keys(labels) as Kind[]).map((kind) => {
          const existing = links.find((l) => l.kind === kind);
          const answered = existing && responses.some((r) => r.token === existing.token);
          return (
            <div key={kind} className="flex items-center gap-1.5">
              <button
                disabled={make.isPending}
                onClick={() => make.mutate(kind)}
                className="text-[11px] px-3 py-1.5 rounded-lg border border-gold bg-card text-primary hover:bg-accent disabled:opacity-50"
              >
                {existing
                  ? `New ${labels[kind].toLowerCase()} link`
                  : `Share ${labels[kind].toLowerCase()}`}
              </button>
              {existing && (
                <button
                  onClick={() => {
                    void navigator.clipboard.writeText(
                      `${window.location.origin}/f/${existing.token}`,
                    );
                    toast.success("Link copied.");
                  }}
                  className="text-[11px] text-muted-foreground underline"
                >
                  copy
                </button>
              )}
              {answered && <span className="text-[10px] text-gold">answered</span>}
            </div>
          );
        })}
      </div>
      {responses.length > 0 && (
        <p className="mt-2 text-[11px] text-muted-foreground">
          {responses.length} family response{responses.length > 1 ? "s" : ""} received.
        </p>
      )}
    </div>
  );
}
