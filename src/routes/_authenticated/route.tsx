import { createFileRoute, Outlet, redirect } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useSession } from "@/lib/session";
import { useStudioSync } from "@/lib/studio-sync";

export const Route = createFileRoute("/_authenticated")({
  ssr: false,
  beforeLoad: async ({ location }) => {
    const { data, error } = await supabase.auth.getUser();
    if (error || !data.user) {
      throw redirect({ to: "/auth", search: { redirect: location.href } });
    }
    if (data.user.user_metadata?.must_change_password === true) {
      throw redirect({ to: "/change-password" });
    }
    return { user: data.user };
  },
  component: AuthenticatedLayout,
});

function Centered({ title, body }: { title: string; body: string }) {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-6">
      <div className="max-w-md text-center">
        <h1 className="font-serif text-2xl text-primary">{title}</h1>
        <p className="mt-3 text-sm italic text-muted-foreground leading-relaxed">{body}</p>
      </div>
    </div>
  );
}

function AuthenticatedLayout() {
  const { loading, roles } = useSession();
  const hasRole = roles.length > 0;
  const status = useStudioSync(!loading && hasRole);

  if (loading) {
    return <Centered title="Opening the studio…" body="Gathering today's little moments." />;
  }

  if (!hasRole) {
    return (
      <Centered
        title="Waiting for your studio role"
        body="Your account is created. A Founder needs to assign your role before the control room opens."
      />
    );
  }

  if (status === "loading") {
    return <Centered title="Opening the studio…" body="Gathering today's little moments." />;
  }

  if (status === "error") {
    return (
      <Centered
        title="We couldn't reach the studio records"
        body="Please refresh in a moment — nothing has been lost."
      />
    );
  }

  return <Outlet />;
}