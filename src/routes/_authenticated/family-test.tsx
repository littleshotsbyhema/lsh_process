import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { AppShell, Card, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/_authenticated/family-test")({
  component: FamilyTestPage,
});

const ORGANIZATION_ID = "590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc";

function FamilyTestPage() {
  const [message, setMessage] = useState("Ready");
  const [busy, setBusy] = useState(false);

  const createFamily = async () => {
    setBusy(true);
    setMessage("Creating family...");

    const { data, error } = await supabase.rpc("create_family", {
      p_organization_id: ORGANIZATION_ID,
      p_display_name: "Test Family",
      p_sort_name: "Test Family",
      p_branch_id: null,
      p_assigned_owner_member_id: null,
    });

    if (error) {
      console.error("[family-test] create_family failed", error);
      setMessage(`Error: ${error.message}`);
      setBusy(false);
      return;
    }

    console.log("[family-test] family created", data);
    setMessage("Family created successfully.");
    setBusy(false);
  };

  return (
    <AppShell>
      <PageHeader
        eyebrow="Families"
        title="Family RPC Test"
        subtitle="Temporary test page for controlled family creation."
        quote="This page will be removed after verification."
      />

      <Card className="p-6 max-w-xl">
        <p className="text-sm text-muted-foreground">{message}</p>

        <button
          type="button"
          onClick={createFamily}
          disabled={busy}
          className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground disabled:opacity-60"
        >
          {busy ? "Creating..." : "Create Test Family"}
        </button>
      </Card>
    </AppShell>
  );
}