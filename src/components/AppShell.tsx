import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { LogOut, Menu, X } from "lucide-react";
import type { ReactNode } from "react";
import { supabase } from "@/integrations/supabase/client";
import { roleLabels, useSession } from "@/lib/session";
import { visibleNav } from "@/lib/access";

export { visibleNav } from "@/lib/access";

export function AppShell({ children }: { children: ReactNode }) {
  const { location } = useRouterState();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { roles, displayName } = useSession();
  const [open, setOpen] = useState(false);
  const items = visibleNav(roles);
  const roleLine = roles.length ? roles.map((r) => roleLabels[r]).join(" · ") : "Role pending";

  const signOut = async () => {
    await queryClient.cancelQueries();
    queryClient.clear();
    await supabase.auth.signOut();
    navigate({ to: "/auth", search: { redirect: "/", invite: undefined }, replace: true });
  };

  const navList = (
    <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
      {items.map(({ to, label, icon: Icon }) => {
        const active = location.pathname === to;
        return (
          <Link
            key={to}
            to={to}
            onClick={() => setOpen(false)}
            className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-all ${
              active
                ? "bg-accent text-sidebar-primary shadow-[var(--shadow-soft)]"
                : "text-sidebar-foreground hover:bg-sidebar-accent/60"
            }`}
          >
            <Icon className={`h-4 w-4 ${active ? "text-gold" : "opacity-70"}`} />
            <span className="leading-tight">{label}</span>
          </Link>
        );
      })}
    </nav>
  );

  const footerBlock = (
    <div className="px-5 py-4 border-t border-sidebar-border text-[11px] text-muted-foreground">
      <div className="font-medium text-sidebar-foreground">Signed in as</div>
      <div className="truncate">{displayName}</div>
      <div className="mt-0.5 truncate">{roleLine}</div>
      <button
        onClick={signOut}
        className="mt-3 inline-flex items-center gap-1.5 rounded-lg border border-border px-2.5 py-1.5 text-[11px] text-sidebar-foreground hover:bg-sidebar-accent/60"
      >
        <LogOut className="h-3 w-3" /> Sign out
      </button>
    </div>
  );

  return (
    <div className="min-h-screen flex bg-background">
      <aside className="hidden lg:flex w-72 shrink-0 flex-col border-r border-border bg-sidebar">
        <div className="px-6 pt-7 pb-5 border-b border-sidebar-border">
          <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
            Little Shots by Hema
          </div>
          <div className="mt-2 font-serif text-2xl text-sidebar-primary leading-tight">
            Little Moments OS
          </div>
          <p className="mt-3 text-xs italic text-muted-foreground leading-relaxed">
            “Because these little moments become everything.”
          </p>
        </div>
        {navList}
        {footerBlock}
      </aside>

      {open && (
        <div className="lg:hidden fixed inset-0 z-50 flex">
          <div className="absolute inset-0 bg-black/40" onClick={() => setOpen(false)} />
          <div className="relative flex w-72 max-w-[85vw] flex-col border-r border-border bg-sidebar">
            <div className="flex items-center justify-between px-5 pt-5 pb-4 border-b border-sidebar-border">
              <div className="font-serif text-lg text-sidebar-primary">Little Moments OS</div>
              <button onClick={() => setOpen(false)} aria-label="Close menu">
                <X className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
            {navList}
            {footerBlock}
          </div>
        </div>
      )}

      <main className="flex-1 min-w-0">
        <div className="lg:hidden flex items-center justify-between px-5 py-4 border-b border-border bg-sidebar">
          <div>
            <div className="text-[10px] uppercase tracking-[0.22em] text-muted-foreground">
              Little Shots by Hema
            </div>
            <div className="font-serif text-lg text-primary">Little Moments OS</div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setOpen(true)}
              aria-label="Open menu"
              className="rounded-lg border border-border p-2 text-primary"
            >
              <Menu className="h-5 w-5" />
            </button>
          </div>
        </div>
        <div className="px-5 sm:px-8 lg:px-12 py-8 lg:py-10 max-w-[1400px] mx-auto">{children}</div>
        <footer className="px-5 sm:px-8 lg:px-12 py-6 border-t border-border bg-sidebar/40">
          <p className="text-center text-xs italic text-muted-foreground">
            Little Moments OS — Built to protect the memories that become everything.
          </p>
        </footer>
      </main>
    </div>
  );
}

export function PageHeader({
  eyebrow,
  title,
  subtitle,
  quote,
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  quote?: string;
}) {
  return (
    <header className="mb-8">
      {eyebrow && (
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground mb-2">
          {eyebrow}
        </div>
      )}
      <h1 className="font-serif text-3xl sm:text-4xl text-primary leading-tight">{title}</h1>
      {subtitle && <p className="mt-2 text-sm text-muted-foreground max-w-2xl">{subtitle}</p>}
      {quote && (
        <p className="mt-4 italic text-sm text-primary/80 max-w-2xl border-l-2 border-gold pl-4">
          {quote}
        </p>
      )}
    </header>
  );
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-2xl border border-border bg-card shadow-[var(--shadow-soft)] ${className}`}
    >
      {children}
    </div>
  );
}

export function StatusPill({
  children,
  tone = "neutral",
}: {
  children: ReactNode;
  tone?: "neutral" | "good" | "warn" | "bad" | "gold";
}) {
  const tones: Record<string, string> = {
    neutral: "bg-muted text-muted-foreground",
    good: "bg-[oklch(0.92_0.05_150)] text-[oklch(0.32_0.08_150)]",
    warn: "bg-[oklch(0.94_0.07_85)] text-[oklch(0.38_0.08_60)]",
    bad: "bg-[oklch(0.92_0.06_25)] text-[oklch(0.4_0.12_25)]",
    gold: "bg-[oklch(0.93_0.07_80)] text-[oklch(0.38_0.08_60)]",
  };
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-medium ${tones[tone]}`}
    >
      {children}
    </span>
  );
}
