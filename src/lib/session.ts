import { useEffect, useState } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";

export const appRoles = [
  "founder",
  "coordinator",
  "sales",
  "photographer",
  "assistant",
  "stylist",
  "editor",
  "album",
  "marketing",
  "accounts",
] as const;
export type AppRole = (typeof appRoles)[number];

export const roleLabels: Record<AppRole, string> = {
  founder: "Founder / Studio Head",
  coordinator: "Client Coordinator",
  sales: "Sales Lead",
  photographer: "Photographer",
  assistant: "Assistant / Baby Care Support",
  stylist: "Stylist / Makeup Artist",
  editor: "Editor / Retoucher",
  album: "Album / Print Coordinator",
  marketing: "Marketing Team",
  accounts: "Accounts",
};

export type SessionState = {
  loading: boolean;
  session: Session | null;
  user: User | null;
  roles: AppRole[];
  displayName: string;
};

export function useSession(): SessionState {
  const [session, setSession] = useState<Session | null>(null);
  const [roles, setRoles] = useState<AppRole[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;

    const loadRoles = async (userId: string | undefined) => {
      if (!userId) {
        if (active) setRoles([]);
        return;
      }
      const { data } = await supabase.from("user_roles").select("role").eq("user_id", userId);
      if (active) setRoles(((data ?? []) as { role: AppRole }[]).map((r) => r.role));
    };

    const { data: sub } = supabase.auth.onAuthStateChange((_event, next) => {
      if (!active) return;
      setSession(next);
      void loadRoles(next?.user?.id);
    });

    void supabase.auth.getSession().then(async ({ data }) => {
      if (!active) return;
      setSession(data.session);
      await loadRoles(data.session?.user?.id);
      if (active) setLoading(false);
    });

    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, []);

  const user = session?.user ?? null;
  const displayName =
    (user?.user_metadata?.full_name as string | undefined) ||
    (user?.user_metadata?.name as string | undefined) ||
    user?.email ||
    "Team member";

  return { loading, session, user, roles, displayName };
}