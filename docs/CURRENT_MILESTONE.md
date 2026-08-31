# Current Milestone

## Authority

This file is the mutable execution pointer for canonical Memory Keeper OS development.

Update it when an approved checkpoint changes the active programme, repository operating model, release state, or next authorized milestone.

Durable product and engineering authority lives in:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`

Release and reconciliation evidence lives in:

- `docs/releases/2026-09-01-sprint-10-production-release.md`
- `docs/governance/2026-09-01-sprint10-post-release-reconciliation.md`
- `docs/governance/2026-09-01-sprint11-scope-freeze.md`

## Canonical repository state

`main` is the single canonical source-of-truth branch for Memory Keeper OS and the Vercel Production Git branch.

Current `main` head at this checkpoint:

`8befb64fb51bfd637c79c1a86b903471d5b91016`

That commit records the completed Sprint 10 Production release.

`architecture-rebuild` remains frozen legacy reference history at:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new commits to `architecture-rebuild` and do not merge it wholesale into `main`.

## Current governance branch

Current branch:

`chore/sprint10-post-release-reconciliation`

Purpose:

- close the post-release Team contract reconciliation;
- replace the stale pre-release milestone pointer;
- freeze the functional boundary for Sprint 11 before any implementation begins.

This branch is governance-only. Sprint 11 implementation must not begin on this branch.

## Production release state

Sprint 10 is COMPLETE, RELEASED and CLOSED through exact Stage 10:

`shoot_scheduled`

The released operational journey currently reaches:

Enquiry -> CRM -> Consultation -> Package -> Quotation -> Booking -> Advance Payment -> Booking Confirmed -> Pre-Shoot Preparation -> Team Assignment -> Safety Readiness -> Shoot Scheduled

The Sprint 10 application release was merged through Production commit:

`3a65cadf35abbfd3541859adf3946c47c0924ea3`

The formal release-record commit on `main` is:

`8befb64fb51bfd637c79c1a86b903471d5b91016`

## Team contract reconciliation

The post-release application/database mismatch for the authenticated Team workspace is CLOSED.

The following canonical migrations are now deployed to Production and recorded in the Production migration ledger:

- `20260816221825_sprint10_canonical_team_access_foundation.sql`
- `20260817042405_sprint10_team_role_admin_read_model.sql`

Production verification confirmed:

- all ten Team RPCs are present;
- expected RPC ACLs are in place;
- `PUBLIC` execution is denied for all ten Team RPCs;
- anonymous execution is limited to the intentionally token-gated `preview_organization_invitation(text)` endpoint;
- invitation tables have RLS enabled and forced;
- `anon` and `authenticated` have no direct table DML privileges;
- the Founder Team permission contract remains `team.read`, `team.invite`, `team.role.assign`, `team.suspend`;
- the canonical organization remains active with one active organization-wide Founder grant;
- no synthetic Production invitation data was introduced.

The generic Supabase SECURITY DEFINER advisor warnings remain review items, not evidence of a release invariant violation by themselves. Exact ACL and internal authorization checks remain authoritative for these deliberate RPC surfaces.

## Canonical journey boundary

The Production journey-stage catalogue confirms:

- Stage 10: `shoot_scheduled` — Shoot Scheduled
- Stage 11: `shoot_completed` — Shoot Completed
- Stage 12: `selection_pending` — Selection Pending

No Stage 11 or later operational advancement is currently released.

## Current programme

The next programme milestone is **Sprint 11 — Shoot Completion**.

Functional scope is frozen in:

`docs/governance/2026-09-01-sprint11-scope-freeze.md`

Exact authorized journey boundary:

`Stage 10 shoot_scheduled -> Stage 11 shoot_completed`

Sprint 11 must stop at exact Stage 11. Stage 11 -> Stage 12 is not authorized.

## Sprint 11 status

Functional scope: FROZEN.

Technical design: NEXT GATE.

Implementation: HOLD until a technical design freeze explicitly defines the evidence model, controlled RPC contract, authorization and branch-scope rules, audit/journey semantics, read model, exact file/migration boundary and acceptance tests.

Production deployment: NOT AUTHORIZED.

## Sprint 11 functional boundary

Sprint 11 may cover only the minimum canonical capability required to record that a scheduled photography session has been completed and to expose that evidence safely in the authenticated studio application.

Permitted areas are:

- authoritative shoot-completion evidence;
- exact Stage 10 -> Stage 11 server-controlled advancement;
- safe authenticated completion read model;
- Bookings UI completion action and historical completion rendering;
- canonical audit and journey evidence;
- dedicated database/application/E2E verification.

The implementation must preserve all released Stage 10 authority, including booking confirmation, payment, scheduling, pre-shoot preparation, team assignment and Safety Readiness controls.

## Explicitly out of scope

The current milestone does not authorize:

- Stage 11 -> Stage 12 `selection_pending` advancement;
- client selection/proofing workflow;
- editing or retouching workflow;
- QC progression;
- Pixieset gallery readiness/publication;
- final delivery;
- album/frame production;
- review or milestone-follow-up workflow;
- AI culling/editing or later creative-intelligence features;
- unrelated Team/RBAC redesign;
- unrelated CRM, quotations, packages or payment redesign;
- public website changes;
- wholesale legacy-branch migration;
- Production database mutation or Production deployment for Sprint 11 without a separate explicit release approval.

## Branch model for Sprint 11

Before Sprint 11 implementation begins:

1. integrate the governance closeout and scope-freeze documents into current `main` through an explicit reviewed repository change;
2. verify the resulting `main` head;
3. create a new short-lived Sprint 11 implementation branch from that exact `main` head;
4. perform technical design freeze on that branch or in a dedicated governance branch before implementation;
5. do not reuse `feature/pre-shoot-operations` or `architecture-rebuild` as the implementation base.

## Current next action

Prepare and review the Sprint 11 technical design freeze for exact Stage 10 -> Stage 11 Shoot Completion.

No implementation code, migration, Production mutation or Stage 12 work is authorized until that design freeze is accepted.
