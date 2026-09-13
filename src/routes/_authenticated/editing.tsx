import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { editingStatuses } from "@/lib/mock-data";
import { useStore } from "@/store/useStore";
import { handle } from "@/lib/handle";

export const Route = createFileRoute("/_authenticated/editing")({
  head: () => ({
    meta: [
      { title: "Editing & Delivery · LittleShots by Hema OS" },
      {
        name: "description",
        content:
          "Track culling, editing, retouching and delivery for every shoot, with guards before work starts.",
      },
      { property: "og:title", content: "Editing & Delivery · LittleShots by Hema OS" },
      {
        property: "og:description",
        content:
          "Track culling, editing, retouching and delivery for every shoot, with guards before work starts.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: EditingPage,
});

function EditingPage() {
  const editing = useStore((s) => s.editing);
  const advance = useStore((s) => s.advanceEditing);
  return (
    <AppShell>
      <PageHeader
        eyebrow="Post-production"
        title="Editing & Delivery Tracker"
        subtitle="Every day a gallery is late, a family waits. Protect the deadline."
        quote="A gallery delivered on time is a promise kept."
      />

      <div className="flex flex-wrap gap-2 mb-6">
        {editingStatuses.map((s) => (
          <span
            key={s}
            className="text-xs px-3 py-1.5 rounded-full bg-muted text-muted-foreground border border-border"
          >
            {s}
          </span>
        ))}
      </div>

      {editing.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="font-serif text-xl text-primary">No editing jobs yet.</p>
          <p className="text-sm text-muted-foreground mt-2">
            Start one from a booking once selection + payment are confirmed.
          </p>
        </Card>
      ) : (
        <Card className="p-0 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted text-muted-foreground text-[11px] uppercase tracking-wider">
                <tr>
                  <Th>Job</Th>
                  <Th>Client</Th>
                  <Th>Status</Th>
                  <Th>Editor</Th>
                  <Th>Edited</Th>
                  <Th>Selection rcvd</Th>
                  <Th>Deadline</Th>
                  <Th>QC</Th>
                  <Th>Delivery</Th>
                  <Th></Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {editing.map((e) => (
                  <tr key={e.id} className="hover:bg-muted/40">
                    <Td>
                      <span className="font-medium text-primary">{e.id}</span>
                      <div className="text-[10px] text-muted-foreground">{e.bookingId}</div>
                    </Td>
                    <Td>{e.client}</Td>
                    <Td>
                      <StatusPill tone={e.status === "Delivered" ? "good" : "warn"}>
                        {e.status}
                      </StatusPill>
                    </Td>
                    <Td>{e.editor}</Td>
                    <Td>{e.editedCount}</Td>
                    <Td>{e.selectionDate}</Td>
                    <Td>{e.deadline}</Td>
                    <Td>{e.qc}</Td>
                    <Td>
                      {e.deliveryLink}
                      <div className="text-[10px] text-muted-foreground">{e.deliveryDate}</div>
                    </Td>
                    <Td>
                      <button
                        onClick={() => handle(advance(e.id))}
                        disabled={e.status === "Delivered"}
                        className="text-xs px-2.5 py-1 rounded-lg bg-primary text-primary-foreground disabled:opacity-40"
                      >
                        Advance →
                      </button>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </AppShell>
  );
}

function Th({ children }: { children?: React.ReactNode }) {
  return <th className="text-left font-medium px-4 py-3">{children}</th>;
}
function Td({ children }: { children: React.ReactNode }) {
  return <td className="px-4 py-3 text-primary align-top">{children}</td>;
}
