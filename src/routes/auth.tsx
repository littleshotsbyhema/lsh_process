import { createFileRoute, useNavigate, useSearch } from "@tanstack/react-router";
import { useCallback, useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { acceptInvite, getInvite } from "@/lib/invites.functions";

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

function isEmailNotConfirmed(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "email_not_confirmed"
  );
}

function AuthPage() {
  const navigate = useNavigate();
  const search = useSearch({ from: "/auth" });
  const token = search.invite;
  const fetchInvite = useServerFn(getInvite);
  const claimInvite = useServerFn(acceptInvite);

  const invite = useQuery({
    queryKey: ["invite-preview", token],
    enabled: Boolean(token),
    queryFn: () => fetchInvite({ data: { token: token as string } }),
    retry: false,
  });

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [resendBusy, setResendBusy] = useState(false);
  const [confirmationCode, setConfirmationCode] = useState("");
  const [confirmationPending, setConfirmationPending] = useState(false);
  const [signedInEmailMismatch, setSignedInEmailMismatch] = useState<string | null>(null);
  const [inviteMode, setInviteMode] = useState<"create" | "sign-in">("create");
  const inviteSessionCheckStarted = useRef(false);
  const inviteAcceptanceAttempted = useRef(false);

  const invited = Boolean(token) && Boolean(invite.data);

  useEffect(() => {
    inviteSessionCheckStarted.current = false;
    inviteAcceptanceAttempted.current = false;
    setConfirmationCode("");
    setConfirmationPending(false);
    setSignedInEmailMismatch(null);
  }, [token]);

  useEffect(() => {
    if (invite.data) {
      setEmail(invite.data.email);
      setName((current) => current || invite.data?.fullName || "");
    }
  }, [invite.data]);

  useEffect(() => {
    void supabase.auth.getSession().then(({ data }) => {
      if (data.session && !token) {
        void navigate({
          to: safePath(search.redirect),
          replace: true,
        });
      }
    });
  }, [navigate, search.redirect, token]);

  const finish = useCallback(async () => {
    if (token) {
      try {
        const accepted = await claimInvite({ data: { token } });

        toast.success(
          accepted.roles.length
            ? "Your studio access is ready. Welcome in."
            : "Your studio membership is ready. Welcome in.",
        );
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Could not accept the invitation.");
        return false;
      }
    }

    await navigate({
      to: safePath(search.redirect),
      replace: true,
    });

    return true;
  }, [claimInvite, navigate, search.redirect, token]);

  useEffect(() => {
    if (!token || !invite.data || inviteSessionCheckStarted.current) {
      return;
    }

    inviteSessionCheckStarted.current = true;
    let cancelled = false;

    void supabase.auth.getUser().then(async ({ data, error }) => {
      if (cancelled || error || !data.user) {
        return;
      }

      const authenticatedEmail = data.user.email?.trim().toLowerCase();
      const invitedEmail = invite.data.email.trim().toLowerCase();

      if (!authenticatedEmail) {
        return;
      }

      if (authenticatedEmail !== invitedEmail) {
        setConfirmationPending(false);
        setSignedInEmailMismatch(data.user.email ?? "another account");
        return;
      }

      if (!data.user.email_confirmed_at) {
        setConfirmationPending(true);
        return;
      }

      if (inviteAcceptanceAttempted.current) {
        return;
      }

      inviteAcceptanceAttempted.current = true;
      setBusy(true);

      try {
        await finish();
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    });

    return () => {
      cancelled = true;
    };
  }, [finish, invite.data, token]);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);

    try {
      if (invited && inviteMode === "create") {
        const { data, error } = await supabase.auth.signUp({
          email: invite.data!.email,
          password,
          options: {
            data: { full_name: name },
          },
        });

        if (error) {
          throw error;
        }

        if (data.session) {
          inviteAcceptanceAttempted.current = true;
          await finish();
        } else {
          setConfirmationCode("");
          setConfirmationPending(true);
          toast.success("We sent a six-digit confirmation code to your invited email.");
        }

        return;
      }

      if (invited) {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: invite.data!.email,
          password,
        });

        if (error) {
          if (isEmailNotConfirmed(error)) {
            setConfirmationCode("");
            setConfirmationPending(true);
            toast.error("Confirm your email before joining. You can resend a fresh code below.");
            return;
          }

          throw error;
        }

        if (!data.session) {
          throw new Error("A signed-in session could not be established.");
        }

        inviteAcceptanceAttempted.current = true;
        await finish();
        return;
      }

      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        throw error;
      }

      if (!data.session) {
        throw new Error("A signed-in session could not be established.");
      }

      await finish();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  };

  const confirmEmail = async (event: React.FormEvent) => {
    event.preventDefault();

    if (!invite.data) {
      return;
    }

    const code = confirmationCode.trim();

    if (!/^\d{6}$/.test(code)) {
      toast.error("Enter the six-digit confirmation code from your email.");
      return;
    }

    setBusy(true);

    try {
      const { data, error } = await supabase.auth.verifyOtp({
        email: invite.data.email,
        token: code,
        type: "email",
      });

      if (error) {
        throw error;
      }

      if (!data.session) {
        throw new Error("Email confirmation succeeded without a signed-in session.");
      }

      inviteAcceptanceAttempted.current = true;
      await finish();
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "The confirmation code could not be verified. Request a fresh code if needed.",
      );
    } finally {
      setBusy(false);
    }
  };

  const resendConfirmationCode = async () => {
    if (!invite.data) {
      return;
    }

    setResendBusy(true);

    try {
      const { error } = await supabase.auth.resend({
        type: "signup",
        email: invite.data.email,
      });

      if (error) {
        throw error;
      }

      setConfirmationCode("");
      toast.success("A fresh six-digit confirmation code is on its way.");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Could not resend the confirmation code.");
    } finally {
      setResendBusy(false);
    }
  };

  const signOutMismatchedAccount = async () => {
    setBusy(true);

    try {
      const { error } = await supabase.auth.signOut();

      if (error) {
        throw error;
      }

      setSignedInEmailMismatch(null);
      setPassword("");
      toast.success("Signed out. Continue with the email on this studio invitation.");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Could not sign out.");
    } finally {
      setBusy(false);
    }
  };

  const inviteInvalid = Boolean(token) && !invite.isLoading && (invite.isError || !invite.data);

  const previewLabels = invite.data
    ? invite.data.roleLabels.length === invite.data.roles.length
      ? invite.data.roleLabels
      : invite.data.roles
    : [];

  const heading = signedInEmailMismatch
    ? "Use the invited account"
    : confirmationPending
      ? "Confirm your email"
      : invited
        ? "Accept your invitation"
        : "Welcome back";

  const description = signedInEmailMismatch
    ? "This studio invitation can only be accepted by the email address it was issued to."
    : confirmationPending && invite.data
      ? `Enter the six-digit code sent to ${invite.data.email}.`
      : invited
        ? inviteMode === "create"
          ? `Create your account to join ${invite.data!.organizationName}.`
          : `Sign in to your existing account to join ${invite.data!.organizationName}.`
        : "Sign in to continue caring for our families.";

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

          <h2 className="mt-2 font-serif text-3xl text-primary">{heading}</h2>

          <p className="mt-2 text-sm text-muted-foreground">{description}</p>

          {invite.isLoading && (
            <p className="mt-5 text-sm italic text-muted-foreground">Opening your invitation…</p>
          )}

          {inviteInvalid && (
            <div className="mt-5 rounded-xl border border-border bg-card p-4 text-sm text-muted-foreground">
              This invitation is no longer valid — it may have been used, revoked, expired, or
              replaced. Ask the studio for a fresh invitation if you still need access.
            </div>
          )}

          {invited && (
            <div className="mt-5 rounded-xl border border-gold/60 bg-accent/50 p-4">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Invitation
              </div>

              <div className="mt-1 text-sm font-medium text-primary">{invite.data!.email}</div>

              <div className="mt-1 text-xs text-muted-foreground">
                {invite.data!.organizationName}
              </div>

              {previewLabels.length ? (
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {previewLabels.map((label, index) => (
                    <span
                      key={`${invite.data!.roles[index] ?? label}-${index}`}
                      className="rounded-full border border-gold bg-card px-2.5 py-1 text-[11px] text-primary"
                    >
                      {label}
                    </span>
                  ))}
                </div>
              ) : (
                <p className="mt-3 text-xs leading-relaxed text-muted-foreground">
                  No role is preassigned. Your studio membership can be assigned access separately
                  after you join.
                </p>
              )}
            </div>
          )}

          {signedInEmailMismatch && invite.data && (
            <div className="mt-6 rounded-xl border border-border bg-card p-4">
              <p className="text-sm leading-relaxed text-muted-foreground">
                You&apos;re signed in as <span className="font-medium text-primary">{signedInEmailMismatch}</span>,
                but this invitation belongs to{" "}
                <span className="font-medium text-primary">{invite.data.email}</span>. Sign out before
                continuing with the invited email.
              </p>

              <button
                type="button"
                onClick={() => void signOutMismatchedAccount()}
                disabled={busy}
                className="mt-4 w-full rounded-lg border border-border bg-background px-4 py-2.5 text-sm font-medium text-primary hover:bg-accent/50 disabled:opacity-60"
              >
                {busy ? "Signing out…" : "Sign out & continue"}
              </button>
            </div>
          )}

          {invited && !confirmationPending && !signedInEmailMismatch && (
            <div className="mt-6 grid grid-cols-2 gap-2 rounded-xl border border-border bg-card p-1.5">
              <button
                type="button"
                onClick={() => setInviteMode("create")}
                className={`rounded-lg px-3 py-2 text-xs font-medium transition ${
                  inviteMode === "create"
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:bg-accent/50"
                }`}
              >
                Create account
              </button>

              <button
                type="button"
                onClick={() => setInviteMode("sign-in")}
                className={`rounded-lg px-3 py-2 text-xs font-medium transition ${
                  inviteMode === "sign-in"
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:bg-accent/50"
                }`}
              >
                I already have an account
              </button>
            </div>
          )}

          {confirmationPending && invite.data && !signedInEmailMismatch ? (
            <form onSubmit={confirmEmail} className="mt-7 space-y-4">
              <label className="block">
                <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  Confirmation code
                </span>
                <input
                  value={confirmationCode}
                  onChange={(event) =>
                    setConfirmationCode(event.target.value.replace(/\D/g, "").slice(0, 6))
                  }
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  pattern="[0-9]{6}"
                  maxLength={6}
                  required
                  autoFocus
                  placeholder="000000"
                  className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-3 text-center text-lg tracking-[0.35em]"
                />
              </label>

              <button
                type="submit"
                disabled={busy || confirmationCode.length !== 6}
                className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
              >
                {busy ? "Confirming…" : "Confirm email & join studio"}
              </button>

              <button
                type="button"
                onClick={() => void resendConfirmationCode()}
                disabled={busy || resendBusy}
                className="w-full rounded-lg border border-border bg-card px-4 py-2.5 text-sm font-medium text-primary hover:bg-accent/50 disabled:opacity-60"
              >
                {resendBusy ? "Sending…" : "Resend confirmation code"}
              </button>

              <button
                type="button"
                onClick={() => {
                  setConfirmationCode("");
                  setConfirmationPending(false);
                }}
                disabled={busy || resendBusy}
                className="w-full px-4 py-2 text-xs text-muted-foreground hover:text-primary disabled:opacity-60"
              >
                Back to account details
              </button>
            </form>
          ) : !signedInEmailMismatch ? (
            <form onSubmit={submit} className="mt-7 space-y-4">
              {invited && inviteMode === "create" && (
                <label className="block">
                  <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                    Full name
                  </span>
                  <input
                    value={name}
                    onChange={(event) => setName(event.target.value)}
                    required
                    maxLength={160}
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
                  onChange={(event) => setEmail(event.target.value)}
                  required
                  readOnly={invited}
                  className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm read-only:text-muted-foreground"
                />
              </label>

              <label className="block">
                <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                  Password
                </span>
                <input
                  type="password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  required
                  minLength={8}
                  className="mt-1.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm"
                />
              </label>

              <button
                type="submit"
                disabled={busy || invite.isLoading || inviteInvalid}
                className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-60"
              >
                {busy
                  ? "Please wait…"
                  : invited
                    ? inviteMode === "create"
                      ? "Create account & continue"
                      : "Sign in & accept invitation"
                    : "Sign in"}
              </button>
            </form>
          ) : null}

          <p className="mt-6 text-xs leading-relaxed text-muted-foreground">
            Little Moments OS is invitation-only. If you need access, ask a teammate with invitation
            permission to invite you from the Team page.
          </p>
        </div>
      </div>
    </div>
  );
}
