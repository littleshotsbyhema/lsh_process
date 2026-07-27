import { createFileRoute, Link, Outlet, redirect, useRouterState } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useSession } from "@/lib/session";
import { useStudioSync } from "@/lib/studio-sync";
import { canView, visibleNav } from "@/lib/access";

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
  const { location } = useRouterState();
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

  if (!canView(location.pathname, roles)) {
    const home = visibleNav(roles)[0]?.to ?? "/";
    return (
      <div className="min-h-screen flex items-center justify-center bg-background px-6">
        <div className="max-w-md text-center">
          <h1 className="font-serif text-2xl text-primary">This room isn&apos;t yours to open</h1>
          <p className="mt-3 text-sm italic text-muted-foreground leading-relaxed">
            Your studio role doesn&apos;t include this part of the house. If you need it, ask a
            Founder to widen your access on the Team page.
          </p>
          <Link
            to={home}
            className="mt-6 inline-block rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground"
          >
            Back to your rooms
          </Link>
        </div>
      </div>
    );
  }

  return <Outlet />;
}