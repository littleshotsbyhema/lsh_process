import { createFileRoute } from "@tanstack/react-router";
import { AppShell, Card, PageHeader, StatusPill } from "@/components/AppShell";
import { editingJobs, editingStatuses } from "@/lib/mock-data";

export const Route = createFileRoute("/editing")({
  head: () => ({ meta: [{ title: "Editing & Delivery · Little Moments OS" }] }),
  component: () => (
    <AppShell>
      <PageHeader
        eyebrow="Post-production"
        title="Editing & Delivery Tracker"
        subtitle="Every day a gallery is late, a family waits. Protect the deadline."
      />

      <div className="flex flex-wrap gap-2 mb-6">
        {editingStatuses.map((s) => (
          <span key={s} className="text-xs px-3 py-1.5 rounded-full bg-muted text-muted-foreground border border-border">{s}</span>
        ))}
      </div>

      <Card className="p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted text-muted-foreground text-[11px] uppercase tracking-wider">
              <tr>
                <Th>Job</Th><Th>Client</Th><Th>Status</Th><Th>Editor</Th><Th>Edited</Th>
                <Th>Selection rcvd</Th><Th>Deadline</Th><Th>QC</Th><Th>Delivery</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {editingJobs.map((e) => (
                <tr key={e.id} className="hover:bg-muted/40">
                  <Td><span className="font-medium text-primary">{e.id}</span><div className="text-[10px] text-muted-foreground">{e.booking}</div></Td>
                  <Td>{e.client}</Td>
                  <Td><StatusPill tone={e.status === "Delivered" ? "good" : "warn"}>{e.status}</StatusPill></Td>
                  <Td>{e.editor}</Td>
                  <Td>{e.editedCount}</Td>
                  <Td>{e.selectionDate}</Td>
                  <Td>{e.deadline}</Td>
                  <Td>{e.qc}</Td>
                  <Td>{e.deliveryLink}<div className="text-[10px] text-muted-foreground">{e.deliveryDate}</div></Td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </AppShell>
  ),
});

function Th({ children }: { children: React.ReactNode }) {
  return <th className="text-left font-medium px-4 py-3">{children}</th>;
}
function Td({ children }: { children: React.ReactNode }) {
  return <td className="px-4 py-3 text-primary align-top">{children}</td>;
}