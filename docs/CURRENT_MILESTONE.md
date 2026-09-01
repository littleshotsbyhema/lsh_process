# Current Milestone

## Authority

This file is the mutable execution pointer for canonical Memory Keeper OS development.

Durable product and engineering authority lives in:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`

Current release and governance evidence includes:

- `docs/releases/2026-09-01-sprint-10-production-release.md`
- `docs/governance/2026-09-01-sprint10-post-release-reconciliation.md`
- `docs/governance/2026-09-01-sprint11-scope-freeze.md`
- `docs/governance/2026-09-01-sprint11-technical-design-freeze.md`
- `docs/releases/2026-09-01-sprint-11-production-release.md`
- `docs/governance/2026-09-01-sprint11-post-release-reconciliation.md`
- `docs/governance/2026-09-01-sprint12-scope-freeze.md`

## Canonical repository state

`main` is the single canonical source-of-truth branch and the Vercel Production Git branch.

Current released `main` head:

`8ca0b8ff64ece7a579540e9bae0ef708c77bc8d5`

This commit merged PR #11 and released Sprint 11 application code.

`architecture-rebuild` remains frozen legacy reference history at:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new work to `architecture-rebuild` and do not merge it wholesale into `main`.

## Current governance branch

Current branch:

`chore/sprint11-post-release-reconciliation`

Purpose:

- record the completed Sprint 11 Production release;
- reconcile repository, application, database and migration-history state;
- close Sprint 11;
- freeze the next functional journey boundary;
- keep Sprint 12 implementation on HOLD pending technical design and explicit authorization.

This branch is governance-only.

## Production release state

Sprint 11 is COMPLETE, RELEASED, VERIFIED and CLOSED through exact Stage 11:

`shoot_completed`

Released journey boundary:

`Stage 10 shoot_scheduled -> Stage 11 shoot_completed`

Production application deployment:

`dpl_G3PGcySexqXS1W7mAG3GX4md87HT`

Production application SHA:

`8ca0b8ff64ece7a579540e9bae0ef708c77bc8d5`

Canonical Sprint 11 Production migrations:

- `20260901160123_sprint11_shoot_completion_evidence_foundation.sql`
- `20260901160125_sprint11_stage10_11_gate_foundation.sql`

Production migration history has been reconciled to these exact repository versions.

## Sprint 11 released contract

Production verification confirms:

- immutable `booking_shoot_completions` evidence;
- narrow `shoot.complete` permission;
- exact grants to Founder, Studio Manager and Photographer;
- canonical role-permission count `233`;
- controlled `record_booking_shoot_completion(uuid,timestamptz)`;
- controlled `mark_booking_shoot_completed(uuid)`;
- forced RLS and authenticated read containment;
- no authenticated direct completion-table mutation;
- explicit separation between completion-recording and journey-advancement authority;
- exact Stage 10 -> Stage 11 advancement;
- completion-terminal shoot scheduling;
- strict Stage 11 replay;
- structural audit evidence;
- no Stage 12 action.

Sprint 11 post-release reconciliation is CLOSED.

## Canonical journey boundary

The canonical journey-stage catalogue includes:

- Stage 10: `shoot_scheduled` — Shoot Scheduled
- Stage 11: `shoot_completed` — Shoot Completed
- Stage 12: `selection_pending` — Selection Pending

Production is released through Stage 11 only.

## Current programme

The next programme milestone is:

**Sprint 12 — Selection Pending**

Frozen functional boundary:

`Stage 11 shoot_completed -> Stage 12 selection_pending`

Functional scope is frozen in:

`docs/governance/2026-09-01-sprint12-scope-freeze.md`

## Sprint 12 status

Functional scope: **FROZEN**.

Technical design: **NOT YET FROZEN**.

Migration filenames: **NOT YET AUTHORIZED OR LOCKED**.

Implementation: **NOT AUTHORIZED**.

Production deployment: **NOT AUTHORIZED**.

Sprint 12 must stop at exact Stage 12. No Stage 12 -> Stage 13 work is authorized.

## Sprint 12 design gate

Before implementation, the technical-design phase must explicitly resolve:

- the minimum authoritative evidence required to enter Selection Pending;
- whether that evidence is internal readiness, client-facing proof readiness or another narrower concept;
- whether any gallery/provider reference belongs at Stage 12;
- exact recording and advancement authorities;
- permission and branch-scope enforcement;
- RLS and RPC ACLs;
- replay/idempotency behavior;
- evidence lifecycle semantics;
- structural audit events;
- exact application read/write boundary;
- exact migration filenames and implementation paths.

No implementation assumption may substitute for this design gate.

## Explicitly out of scope at this checkpoint

The current milestone does not authorize:

- Stage 12 -> Stage 13 or later advancement;
- client selection decisions unless proven necessary for Stage 12 entry;
- editing or retouching workflow;
- QC progression;
- gallery publication beyond any minimum evidence explicitly frozen by the technical design;
- final delivery;
- album/frame production;
- review or milestone-follow-up workflow;
- AI culling/editing or automated creative judgment;
- media custody/DAM redesign;
- unrelated Team/RBAC redesign;
- unrelated CRM, quotation, payment, package or public-website changes;
- wholesale legacy-branch migration;
- Production mutation without separate explicit approval.

## Deferred non-blocking technical debt

Production advisors identify an INFO-level performance item for `booking_shoot_completions_recorded_by_fkey` lacking a dedicated covering index, alongside pre-existing repository-wide advisory notices.

These are not authorized for modification by the current governance branch and must be handled through separately scoped hardening work.

## Current next action

Prepare and review the Sprint 12 technical-design freeze for the exact Stage 11 -> Stage 12 boundary.

Do not create Sprint 12 migrations, modify implementation code, or mutate Production until the technical design is frozen and explicit implementation authorization is granted.
