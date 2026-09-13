import { useEffect } from "react";
import {
  createFileRoute,
  Link,
  Outlet,
  redirect,
  useNavigate,
  useRouterState,
} from "@tanstack/react-router";

import { supabase } from "@/integrations/supabase/client";
import { type AppRole, useSession } from "@/lib/session";
import { canView, isTemporarilyUnavailable, visibleNav } from "@/lib/access";
import { TrainingProvider } from "@/lib/training/training-context";
import { TRAINING_ROUTE } from "@/lib/training/training-gate";
import { useTraining } from "@/lib/training/use-training";

export const Route = createFileRoute("/_authenticated")({
  ssr: false,
  beforeLoad: async ({ location }) => {
    const { data, error } = await supabase.auth.getUser();

    if (error || !data.user) {
      throw redirect({
        to: "/auth",
        search: {
          redirect: location.href,
          invite: undefined,
        },
      });
    }

    if (data.user.user_metadata?.must_change_password === true) {
      throw redirect({
        to: "/change-password",
      });
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
  const { loading, roles, user } = useSession();
  const { location } = useRouterState();

  const hasRole = roles.length > 0;

  if (loading) {
    return <Centered title="Opening the studio…" body="Gathering today's little moments." />;
  }

  if (!hasRole) {
    return (
      <Centered
        title="Studio access is not ready yet"
        body="Your account is signed in, but no active studio role is available yet. If you joined through a studio invitation, reopen that invitation to finish acceptance. If the invitation had no preassigned role, an authorized teammate can assign access from Team."
      />
    );
  }

  return (
    <TrainingProvider userId={user?.id ?? null} enabled={hasRole}>
      <AuthenticatedTrainingBoundary roles={roles} pathname={location.pathname} />
    </TrainingProvider>
  );
}

function AuthenticatedTrainingBoundary({
  roles,
  pathname,
}: {
  roles: AppRole[];
  pathname: string;
}) {
  const navigate = useNavigate();
  const { resolveGate } = useTraining();

  const decision = resolveGate(pathname);

  const redirectTo = decision.action === "redirect" ? decision.to : null;

  useEffect(() => {
    if (!redirectTo) return;

    void navigate({
      to: redirectTo,
      replace: true,
    });
  }, [navigate, redirectTo]);

  if (redirectTo) {
    return (
      <Centered
        title="Opening your training…"
        body="Your required training needs attention before normal studio work continues."
      />
    );
  }

  const isTrainingRoute = pathname === TRAINING_ROUTE || pathname.startsWith(`${TRAINING_ROUTE}/`);

  if (!isTrainingRoute && isTemporarilyUnavailable(pathname)) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background px-6">
        <div className="max-w-md text-center">
          <h1 className="font-serif text-2xl text-primary">This room is being rebuilt</h1>

          <p className="mt-3 text-sm italic text-muted-foreground leading-relaxed">
            This module is temporarily unavailable while it is connected to the canonical studio
            records. Nothing entered here will be treated as live booking or journey state.
          </p>

          <Link
            to="/"
            className="mt-6 inline-block rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground"
          >
            Back to the control room
          </Link>
        </div>
      </div>
    );
  }

  if (!isTrainingRoute && !canView(pathname, roles)) {
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

  return (
    <>
      {decision.action === "soft-reminder" && (
        <div className="border-b border-border bg-accent/50 px-5 py-2.5 text-sm text-primary">
          <div className="mx-auto flex max-w-[1400px] flex-wrap items-center justify-between gap-2">
            <span>Your LittleShots by Hema OS training is ready to continue.</span>

            <Link to="/training" className="font-medium underline underline-offset-4">
              Open training
            </Link>
          </div>
        </div>
      )}

      <Outlet />
    </>
  );
}
