import { createFileRoute, useNavigate, useSearch } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/auth")({
  validateSearch: (search: Record<string, unknown>) => ({
    redirect: typeof search.redirect === "string" ? search.redirect : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Studio Sign In · Little Moments OS" },
      {
        name: "description",
        content:
          "Sign in to Little Moments OS — the internal control room for Little Shots by Hema.",
      },
      { property: "og:title", content: "Studio Sign In · Little Moments OS" },
      {
        property: "og:description",
        content: "Private studio workspace for the Little Shots by Hema team.",
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
  const [mode, setMode] = useState<"signin" | "signup">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void supabase.auth.getSession().then(({ data }) => {
      if (data.session) navigate({ to: safePath(search.redirect), replace: true });
    });
  }, [navigate, search.redirect]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      if (mode === "signup") {
        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            emailRedirectTo: window.location.origin,
            data: { full_name: name },
          },
        });
        if (error) throw error;
        toast.success("Welcome to the studio. Signing you in…");
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
      }
      const { data } = await supabase.auth.getSession();
      if (data.session) navigate({ to: safePath(search.redirect), replace: true });
      else toast.success("Check your inbox to confirm your email, then sign in.");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  };

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
            {mode === "signin" ? "Welcome back" : "Join the studio"}
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            {mode === "signin"
              ? "Sign in to continue caring for our families."
              : "Create your team account. A Founder will assign your role."}
          </p>

          <form onSubmit={submit} className="mt-7 space-y-4">
            {mode === "signup" && (
              <label className="block">
                <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  Full name
                </span>
                <input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
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
                className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
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
                minLength={6}
                className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
              />
            </label>
            <button
              type="submit"
              disabled={busy}
              className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
            >
              {busy ? "Please wait…" : mode === "signin" ? "Sign in" : "Create account"}
            </button>
          </form>

          <button
            onClick={() => setMode(mode === "signin" ? "signup" : "signin")}
            className="mt-5 text-xs text-muted-foreground hover:text-primary"
          >
            {mode === "signin"
              ? "New to the studio? Create an account"
              : "Already have an account? Sign in"}
          </button>
        </div>
      </div>
    </div>
  );
}