# LittleShots by Hema OS — Repository Working Agreement

## What this product is

LittleShots by Hema OS is the studio operating system for Little Shots by
Hema: a memory-preservation business, not a generic CRM.

Brand truth:

**Because these little moments become everything.**

Operating principle:

**Emotion is the heart. Care is the method. Trust is the standard. Memory is
the outcome.**

Every implementation decision must protect emotion-led memory preservation,
gentle care and safety, consent-first trust, timeless artistic quality,
heirloom keepsake value, and clarity for the families we serve.

Do not implement a technically convenient solution that weakens trust,
privacy, safety, clarity, historical integrity, or long-term architecture.

## Read before material work

- `docs/README.md` — what is current and what is frozen history
- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/CURRENT_MILESTONE.md`
- `docs/DEFINITION_OF_DONE.md`

`docs/CURRENT_MILESTONE.md` is the mutable execution pointer. If a requested
task conflicts with it or with durable architecture, stop the conflicting
part and say so.

## Product model

One application, six domains: Studio OS, Family OS, Memory OS, Business OS,
AI OS, Founder OS. Do not reduce the system to a lead tracker.

## Repository and production

`main` is the single source of truth and the Vercel production branch.
Updating `main` deploys to production.

Do normal work on a short-lived branch from current `main`
(`feature/...`, `fix/...`, `chore/...`, `release/...`, `hotfix/...`), then
open a pull request. Do not create a second long-lived branch competing with
`main`.

A green build or a successful Preview deployment does not by itself authorize
merging to `main`.

## Architecture authority

The database and server layer enforce business truth. The browser must never
be trusted to enforce authorization, financial truth, consent truth, or
lifecycle transitions.

Required foundations:

- organization isolation on tenant-owned entities
- role-based access control
- PostgreSQL row-level security, forced
- mutations through controlled server functions and RPCs
- append-only or immutable audit history where appropriate
- lifecycle state instead of destructive deletion for business history
- server-side secrets only; no service-role credential in browser code

These are authoritative unless the current milestone explicitly approves a
change.

## Engineering rules

1. Inspect existing code, migrations, tests and authority paths before
   changing architecture.
2. Extend established patterns rather than introducing parallel ones.
3. Database invariants belong in constraints, RLS, functions/RPCs, or
   approved server-side domain services.
4. UI state must never be the only enforcement of a business rule.
5. Critical lifecycle transitions must be server-controlled.
6. Every cross-organization query and write must remain tenant-safe.
7. Every sensitive mutation must be permission-checked and auditable.
8. Financial, booking, consent, privacy, safety and audit history must remain
   reconstructable.
9. AI may propose; deterministic rules and authorized humans decide
   high-impact actions.
10. Do not invent pricing, packages, consent, availability, medical guidance,
    or business policy.
11. Do not opportunistically migrate frameworks or add unrelated
    infrastructure.
12. Preserve backward compatibility unless the approved work explicitly
    allows a breaking change.

## Stop at these gates

Ask for explicit confirmation before:

- merging into `main` (this deploys to production)
- applying migrations to the remote Supabase project, or any linked
  `supabase db push`, migration repair, or reset
- mutating production data
- promoting or rolling back a Vercel deployment
- force-pushing any shared branch

Everything else — reading, local edits, branch commits, pushing a feature
branch, opening a pull request, running type/lint/build/tests — proceeds
normally without a separate approval each time.

Earlier approval for one gated action never carries to the next one. "Looks
good" on an implementation is not permission to merge or to touch production.

## Supabase trust boundaries

Local Supabase and the remote project are separate boundaries. Permission to
use local Supabase never implies permission to use `--linked`, deploy remote
migrations, merge a Supabase branch, or alter production schema or data.

Local fixture or E2E data must never be described as production data.

## Migration discipline

Before adding a migration:

1. inspect current migrations and the live schema
2. check whether the capability already exists
3. define forward-only compatibility
4. verify permissions, RLS, audit, lifecycle and recovery implications
5. add database tests under `supabase/tests/`
6. run the relevant historical compatibility tests

Adapt application code to the authoritative database contract; do not weaken
a newer contract to make older code work.

`supabase/legacy-migrations/` is pre-rebuild reference only. Never apply it.

## Generated files

Generated files are outputs of validated source state, not authority.

- `src/integrations/supabase/types.ts` — regenerate from the applicable schema
  after a validated schema change; inspect the semantic delta rather than
  accepting whatever compiles.
- `src/routeTree.gen.ts` — produce through normal TanStack tooling; never
  hand-edit a stale route tree to satisfy type checking.

## Secrets

Never print or expose service-role keys, private API keys, access tokens,
passwords, secret environment values, or signing material. Prefer commands
that pass secrets without echoing them.

Public URLs, project refs, commit SHAs and non-secret identifiers are fine to
show.

## Verification

Do not push while a required verification is failing. Classify a failure
before reporting it: implementation regression, contaminated local fixture,
pre-existing debt, non-fatal warning, or environmental/tooling failure.

A warning is not a failure. A nonzero exit is not "clean".

## Change control

Do not silently change the tenant model, organization isolation,
role/permission semantics, package or quotation semantics, the booking state
machine, privacy/consent semantics, the audit model, financial or safety
authority, naming conventions, or public RPC contracts.

If a required change conflicts with approved architecture: stop that part,
describe the conflict, propose the smallest safe change, and continue with
the non-conflicting work.

## Historical data

Prefer lifecycle and supersession semantics — active/inactive, `archived_at`,
`cancelled_at`, `exited_at`, `superseded_by`, versioning — over destructive
deletion for business history. Hard deletion is for explicitly disposable
data only.

## AI features

AI capabilities follow: user/context → policy/permission → deterministic
eligibility rules → model → validated tool/action → audit.

AI must not mutate critical state without a validated server action, must not
infer consent, must not invent prices, discounts, packages or availability,
and must escalate uncertainty on privacy, safety, payment, booking readiness
or legal matters.

## Public website boundary

The Little Shots public website is operationally separate from this
application. Do not alter it, its hosting, or its domain while working here
unless that scope is explicitly requested.

## Reporting

At meaningful checkpoints, report: branch, base commit, files changed,
migrations added, tests run, build/type/lint status, known warnings,
unresolved risks, and any remote or production changes made. Distinguish
local evidence from production evidence.

## Working style

Make the smallest coherent change that completes the current piece of work.
Don't jump ahead to later roadmap domains. Don't add speculative
abstractions. Prefer explicit names over clever ones. Preserve audit
integrity. Keep notes concise and evidence-based. Stop at trust boundaries
instead of quietly crossing them.

A rendered UI is not evidence of completion. `docs/DEFINITION_OF_DONE.md` is.
