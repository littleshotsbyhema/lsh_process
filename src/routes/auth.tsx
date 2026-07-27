import { createFileRoute, useNavigate, useSearch } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { acceptInvite, getInvite } from "@/lib/invites.functions";
import { roleLabels, type AppRole } from "@/lib/session";

export const Route = createFileRoute("/auth")({
  validateSearch: (search: Record<string, unknown>) => ({
    redirect: typeof search.redirect === "string" ? search.redirect : undefined,
    invite: typeof search.invite === "string" ? search.invite : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Studio Sign In · Little Moments OS" },
      {
        name: "description",
        content:
          "Sign in to Little Moments OS — the internal control room for Little Shots by Hema. Access is by studio invitation only.",
      },
      { property: "og:title", content: "Studio Sign In · Little Moments OS" },
      {
        property: "og:description",
        content: "Private, invitation-only workspace for the Little Shots by Hema team.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: AuthPage,
});

function safePath(path: string | undefined) {
  return path && path.startsWith("/") && !path.startsWith("//") ? path : "/";
}

function AuthPage() {
  const navigate = useNavigate();
  const search = useSearch({ from: "/auth" });
  const token = search.invite;
  const fetchInvite = useServerFn(getInvite);
  const claimInvite = useServerFn(acceptInvite);

  const invite = useQuery({
    queryKey: ["invite", token],
    enabled: Boolean(token),
    queryFn: () => fetchInvite({ data: { token: token as string } }),
  });

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);

  const invited = Boolean(token) && Boolean(invite.data);

  useEffect(() => {
    if (invite.data) {
      setEmail(invite.data.email);
      setName((prev) => prev || invite.data?.fullName || "");
    }
  }, [invite.data]);

  useEffect(() => {
    void supabase.auth.getSession().then(({ data }) => {
      if (data.session && !token) navigate({ to: safePath(search.redirect), replace: true });
    });
  }, [navigate, search.redirect, token]);

  const finish = async () => {
    if (token) {
      try {
        await claimInvite({ data: { token } });
        toast.success("Your studio role is ready. Welcome in.");
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Could not accept the invitation.");
      }
    }
    navigate({ to: safePath(search.redirect), replace: true });
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      if (invited) {
        const { error } = await supabase.auth.signUp({
          email: invite.data!.email,
          password,
          options: { emailRedirectTo: window.location.href, data: { full_name: name } },
        });
        if (error && !/already registered/i.test(error.message)) throw error;
        if (error) {
          const { error: signInError } = await supabase.auth.signInWithPassword({
            email: invite.data!.email,
            password,
          });
          if (signInError) throw signInError;
        }
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
      }
      const { data } = await supabase.auth.getSession();
      if (data.session) await finish();
      else toast.success("Check your inbox to confirm your email, then open your invite link again.");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  };

  const inviteInvalid = Boolean(token) && !invite.isLoading && !invite.data;

  return (
    <div className="min-h-screen grid lg:grid-cols-2 bg-background">
      <div className="hidden lg:flex flex-col justify-between p-12 bg-[var(--gradient-warm)]">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Little Shots by Hema
        </div>
        <div>
          <h1 className="font-serif text-5xl text-primary leading-tight">Little Moments OS</h1>
          <p className="mt-6 italic text-primary/80 max-w-md leading-relaxed">
            “Because these little moments become everything.”
          </p>
        </div>
        <p className="text-xs text-muted-foreground">
          Built to protect the memories that become everything.
        </p>
      </div>

      <div className="flex items-center justify-center px-6 py-16">
        <div className="w-full max-w-sm">
          <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
            Studio access
          </div>
          <h2 className="mt-2 font-serif text-3xl text-primary">
            {invited ? "Accept your invitation" : "Welcome back"}
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            {invited
              ? "Set a password to open your studio account. Your roles are already waiting."
              : "Sign in to continue caring for our families."}
          </p>

          {invite.isLoading && (
            <p className="mt-5 text-sm italic text-muted-foreground">Opening your invitation…</p>
          )}

          {inviteInvalid && (
            <div className="mt-5 rounded-xl border border-border bg-card p-4 text-sm text-muted-foreground">
              This invitation is no longer valid — it may have been used, revoked, or expired. Please
              ask a Founder for a fresh link, or sign in below.
            </div>
          )}

          {invited && (
            <div className="mt-5 rounded-xl border border-gold/60 bg-accent/50 p-4">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Invited as
              </div>
              <div className="mt-1 text-sm font-medium text-primary">{invite.data!.email}</div>
              <div className="mt-2 flex flex-wrap gap-1.5">
                {invite.data!.roles.map((role) => (
                  <span
                    key={role}
                    className="rounded-full border border-gold bg-card px-2.5 py-1 text-[11px] text-primary"
                  >
                    {roleLabels[role as AppRole] ?? role}
                  </span>
                ))}
              </div>
            </div>
          )}

          <form onSubmit={submit} className="mt-7 space-y-4">
            {invited && (
              <label className="block">
                <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  Full name
                </span>
                <input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  maxLength={120}
                  className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                />
              </label>
            )}
            <label className="block">
              <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Email
              </span>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                readOnly={invited}
                className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm disabled:opacity-70 read-only:text-muted-foreground"
              />
            </label>
            <label className="block">
              <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Password
              </span>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={8}
                className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
              />
            </label>
            <button
              type="submit"
              disabled={busy || invite.isLoading}
              className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
            >
              {busy ? "Please wait…" : invited ? "Create my studio account" : "Sign in"}
            </button>
          </form>

          <p className="mt-6 text-xs leading-relaxed text-muted-foreground">
            Little Moments OS is invitation-only. If you need access, ask a Founder to invite you
            from the Team page.
          </p>
        </div>
      </div>
    </div>
  );
}
