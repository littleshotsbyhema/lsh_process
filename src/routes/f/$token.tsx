import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/f/$token")({
  head: () => ({
    meta: [
      {
        title: "Family link · Little Shots by Hema",
      },
      {
        name: "description",
        content: "A private family link from Little Shots by Hema.",
      },
      {
        property: "og:title",
        content: "Family link · Little Shots by Hema",
      },
      {
        property: "og:description",
        content: "Because these little moments become everything.",
      },
      {
        property: "og:type",
        content: "website",
      },
      {
        name: "twitter:card",
        content: "summary",
      },
      {
        name: "robots",
        content: "noindex",
      },
    ],
  }),
  component: FamilyLinkUnavailablePage,
});

function Shell({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--gradient-warm)] px-5 py-16">
      <div className="w-full max-w-lg rounded-2xl border border-border bg-card p-8 shadow-[var(--shadow-soft)]">
        <div className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
          Little Shots by Hema
        </div>

        <h1 className="mt-2 font-serif text-3xl leading-tight text-primary">{title}</h1>

        <div className="mt-5 text-sm leading-relaxed text-foreground/90">{children}</div>

        <p className="mt-8 border-t border-border pt-5 text-center text-xs italic text-muted-foreground">
          “Because these little moments become everything.”
        </p>
      </div>
    </div>
  );
}

function FamilyLinkUnavailablePage() {
  return (
    <Shell title="This family link is temporarily unavailable">
      <p>
        We are updating our private family-link experience so your information, choices, and
        responses are recorded through the same trusted system used by the studio.
      </p>

      <p className="mt-4">
        Please contact the Little Shots by Hema team and we will guide you personally.
      </p>

      <p className="mt-4 text-xs text-muted-foreground">
        No response has been recorded from this page.
      </p>
    </Shell>
  );
}
