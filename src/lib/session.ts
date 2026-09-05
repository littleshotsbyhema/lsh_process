import { useEffect, useState } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";

export const appRoles = [
  "founder",
  "studio_manager",
  "client_coordinator",
  "sales_head",
  "sales",
  "photographer",
  "assistant",
  "stylist",
  "videographer",
  "editor",
  "album_coordinator",
  "marketing",
  "accounts",
] as const;

export type AppRole = (typeof appRoles)[number];

export const roleLabels: Record<AppRole, string> = {
  founder: "Founder / Brand Owner / Studio Head",
  studio_manager: "Studio Manager",
  client_coordinator: "Client Coordinator",
  sales_head: "Brand Sales Head",
  sales: "Sales Team Member",
  photographer: "Photographer",
  assistant: "Assistant",
  stylist: "Stylist",
  videographer: "Videographer",
  editor: "Editor",
  album_coordinator: "Album Coordinator",
  marketing: "Marketing",
  accounts: "Accounts",
};

export const ORGANIZATION_ID = "590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc";

type SessionState = {
  loading: boolean;
  session: Session | null;
  user: User | null;
  roles: AppRole[];
  displayName: string;
};

type MembershipResult = {
  organization_id: string;
  organization_name: string;
  member_status: string;
  display_name: string | null;
  email: string | null;
  phone: string | null;
  joined_at: string;
  assigned_role_keys: string[] | null;
  assigned_role_labels: string[] | null;
  branch_names: string[] | null;
  organization_wide: boolean;
};

function isAppRole(value: string): value is AppRole {
  return appRoles.includes(value as AppRole);
}

export function useSession(): SessionState {
  const [session, setSession] = useState<Session | null>(null);
  const [roles, setRoles] = useState<AppRole[]>([]);
  const [membershipName, setMembershipName] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;

    const clearMembership = () => {
      if (!active) return;

      setRoles([]);
      setMembershipName(null);
    };

    const loadMembership = async (userId: string | undefined) => {
      if (!userId) {
        clearMembership();
        return;
      }

      const { data, error } = await supabase.rpc("my_membership", {
        p_organization_id: ORGANIZATION_ID,
      });

      if (error) {
        console.error("Failed to load studio membership:", error);
        clearMembership();
        return;
      }

      const rows = (data ?? []) as unknown as MembershipResult[];
      const membership = rows[0];

      if (!membership || membership.member_status !== "active") {
        clearMembership();
        return;
      }

      const resolvedRoles = (membership.assigned_role_keys ?? []).filter(isAppRole);

      if (!active) return;

      setRoles([...new Set(resolvedRoles)]);
      setMembershipName(membership.display_name);
    };

    const { data: authListener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (!active) return;

      setSession(nextSession);
      setLoading(true);

      void loadMembership(nextSession?.user?.id).finally(() => {
        if (active) {
          setLoading(false);
        }
      });
    });

    void supabase.auth.getSession().then(async ({ data, error }) => {
      if (!active) return;

      if (error) {
        console.error("Failed to load Supabase session:", error);
        setSession(null);
        clearMembership();
        setLoading(false);
        return;
      }

      setSession(data.session);
      await loadMembership(data.session?.user?.id);

      if (active) {
        setLoading(false);
      }
    });

    return () => {
      active = false;
      authListener.subscription.unsubscribe();
    };
  }, []);

  const user = session?.user ?? null;

  const displayName =
    membershipName ||
    (user?.user_metadata?.full_name as string | undefined) ||
    (user?.user_metadata?.name as string | undefined) ||
    user?.email ||
    "Team member";

  return {
    loading,
    session,
    user,
    roles,
    displayName,
  };
}
