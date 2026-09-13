# Current Milestone

Last updated: 13 September 2026

This file is the mutable execution pointer. Durable authority lives in
`AGENTS.md`, `PRODUCT_CONSTITUTION.md`, `ARCHITECTURE.md`, `DOMAIN_RULES.md`,
`IMPLEMENTATION_ROADMAP.md` and `DEFINITION_OF_DONE.md`.

## Where this runs

| | |
|---|---|
| Repository | `littleshotsbyhema/lsh_process`, branch `main` |
| Database | Supabase project `lsh-process` (`itnwhzhntzqgpnrjdzbd`), Mumbai |
| Hosting | Vercel project `lsh-process` → https://lsh-process.vercel.app |
| Organization | Little Shots by Hema, `590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc`, active |

The application is single-tenant in practice: `ORGANIZATION_ID` is a constant
in `src/lib/session.ts`, though the schema is multi-tenant.

Access is invitation-only. There is no public sign-up. The first Founder was
bootstrapped directly through `lsh_bootstrap_canonical_founder`; everyone else
joins from the Team page.

## Handover status

This repository was imported from a previous owner's organization in
September 2026. The code, all branches and all tags came across; pull request
history did not, so any PR number in a historical document refers to the
previous repository and cannot be opened here.

The database was rebuilt from scratch: all 36 migrations replayed onto a new,
empty Supabase project. No data was carried over. The replay produced 81
tables and 261 role-permission mappings, matching the expected clean-build
count.

## What is actually built

Working against live data: leads and lead workspace, consultations, families
and children, memory profiles, package catalogue, quotations through
acceptance, bookings through stage 12 (selection complete / editing pending)
including advance payment, confirmation, shoot scheduling, pre-shoot
preparation, safety readiness, team assignment and shoot completion; the
public Memory Guide; team invitations and role administration; role-aware
training (one module: common orientation); Founder KPIs.

Not built. Eleven screens — prep, safety, privacy, editing, pixieset,
heirloom, marketing, reviews, governance, reports, kpi — still run on an
in-memory mock store from the pre-rebuild application and are blocked by
`temporarilyUnavailablePaths` in `src/lib/access.ts`. The family-facing route
`/f/$token` and `ClientShareLinks` are stubs. The booking journey has no
stages past 12.

Missing from the database entirely: the Trust domain
(`consent_records`, `privacy_preferences`, `terms_acceptances`), a payments
ledger and refunds, notifications, the client portal, and the Production and
Heirloom domains described in `ARCHITECTURE.md`.

## Next up

No milestone is currently in flight. The intended order, from the September
2026 handover audit:

1. Housekeeping — config, naming, branch pruning, regenerate Supabase types.
2. Put the sales half into real daily use: real packages and prices, real
   team members, real enquiries. Let that surface the true priorities.
3. Consent and privacy. `DOMAIN_RULES.md` treats consent as central and the
   tables do not exist — the highest-risk gap for a studio that publishes
   client work.
4. Delivery pipeline: editing → QC → gallery delivery → handover, as booking
   stages 13 onward, replacing four of the mock screens and unlocking the
   family-facing link.
5. Payments ledger with balances and refunds, then revenue reporting.
6. Heirloom, reviews, marketing, WhatsApp automation.

## Standing constraints

Production database mutation requires explicit confirmation at the time, per
`AGENTS.md`. Merging to `main` deploys to production.

Work Ready sign-off is defined in the schema but deliberately not
implemented: training completion grants no role, no branch authority and no
Work Ready state.
