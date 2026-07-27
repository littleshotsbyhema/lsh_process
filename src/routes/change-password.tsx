import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/change-password")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Set a New Password · Little Moments OS" },
      {
        name: "description",
        content:
          "Replace your temporary studio password with a private one before entering Little Moments OS.",
      },
      { property: "og:title", content: "Set a New Password · Little Moments OS" },
      {
        property: "og:description",
        content: "Secure your Little Shots by Hema studio account with a new password.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ChangePasswordPage,
});

function ChangePasswordPage() {
  const navigate = useNavigate();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void supabase.auth.getUser().then(({ data }) => {
      if (!data.user) navigate({ to: "/auth", replace: true });
    });
  }, [navigate]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password !== confirm) {
      toast.error("Both passwords need to match.");
      return;
    }
    setBusy(true);
    try {
      const { error } = await supabase.auth.updateUser({
        password,
        data: { must_change_password: false, password_changed_at: new Date().toISOString() },
      });
      if (error) throw error;
      toast.success("Your new password is saved. Welcome in.");
      navigate({ to: "/", replace: true });
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Could not update your password.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-6 py-16">
      <div className="w-full max-w-sm">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Studio access
        </div>
        <h1 className="mt-2 font-serif text-3xl text-primary">Set a new password</h1>
        <p className="mt-2 text-sm text-muted-foreground leading-relaxed">
          Your account is still on a temporary password. Please choose a private one before opening
          the control room.
        </p>

        <form onSubmit={submit} className="mt-7 space-y-4">
          <label className="block">
            <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
              New password
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
          <label className="block">
            <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
              Confirm new password
            </span>
            <input
              type="password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              required
              minLength={8}
              className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
            />
          </label>
          <button
            type="submit"
            disabled={busy}
            className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
          >
            {busy ? "Saving…" : "Save password and continue"}
          </button>
        </form>

        <p className="mt-8 text-xs text-muted-foreground">
          Little Moments OS — Built to protect the memories that become everything.
        </p>
      </div>
    </div>
  );
}