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
- `docs/governance/2026-09-01-sprint12-technical-design-freeze.md`
- `docs/governance/2026-09-02-sprint12-post-release-reconciliation.md`

## Canonical repository state

`main` is the single canonical source-of-truth branch and the Vercel Production Git branch.

Current released `main` head:

`ec05bba81d19fed31cdf0d8ff9e42ac8a713099e`

This commit merged PR #14 and released Sprint 12 application code.

`architecture-rebuild` remains frozen legacy reference history at:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new work to `architecture-rebuild` and do not merge it wholesale into `main`.

## Current governance branch

Current branch:

`chore/sprint12-post-release-reconciliation`

Purpose:

- record the completed Sprint 12 Production release;
- reconcile repository, application, database and migration-history state;
- close Sprint 12;
- correct the mutable milestone pointer to the actual released state;
- hold any Stage 12 -> Stage 13 implementation until a new milestone is explicitly frozen and authorized.

This branch is governance-only.

## Production release state

Sprint 12 is COMPLETE, RELEASED, VERIFIED and CLOSED through exact Stage 12:

`selection_pending`

Released journey boundary:

`Stage 11 shoot_completed -> Stage 12 selection_pending`

Production application SHA:

`ec05bba81d19fed31cdf0d8ff9e42ac8a713099e`

Canonical Sprint 12 Production migration:

- `20260901180856_sprint12_stage11_12_selection_pending_gate_foundation.sql`

Production migration history is aligned with this exact repository version.

## Sprint 12 released contract

Production verification confirms:

- controlled `mark_booking_selection_pending(uuid)`;
- `SECURITY DEFINER` execution with empty search path;
- reuse of the existing `booking.stage.advance` permission;
- exact journey-advancement role boundary of Founder, Studio Manager and Client Coordinator;
- canonical shoot-completion evidence required before Stage 12 entry;
- canonical Stage 10 -> Stage 11 completion lineage required;
- exact Stage 11 -> Stage 12 advancement;
- strict mutation-free Stage 12 replay;
- no new selection-specific permission or role grant;
- no Stage 12 -> Stage 13 action;
- Stage 12 application surface remains read-only after advancement.

Sprint 12 post-release reconciliation is CLOSED.

## Canonical journey boundary

The canonical journey-stage catalogue includes:

- Stage 10: `shoot_scheduled` — Shoot Scheduled
- Stage 11: `shoot_completed` — Shoot Completed
- Stage 12: `selection_pending` — Selection Pending
- Stage 13: `editing_pending` — Editing Pending

Production is released through Stage 12 only.

Stage 12 means the completed session has been formally handed into the selection phase and is waiting for selection activity. It does not mean selections are complete, proofs are ready, editing has started, a gallery has been published, or delivery is complete.

## Sprint 12 validation state

Release validation completed with:

- dedicated Sprint 12 pgTAP: `43/43` PASS;
- full local DB regression: `1311/1311` PASS;
- local DB lint: PASS;
- local DB advisors: PASS;
- canonical role-permission count unchanged at `233` before release;
- scoped ESLint: PASS;
- Production build: PASS;
- `git diff --check`: PASS;
- exact five-file implementation boundary preserved;
- Vercel success on the exact merged `main` SHA;
- Production migration dry run identified exactly one pending migration;
- Production migration applied successfully;
- final local/remote migration ledger aligned;
- Production performance advisor: no issues;
- Production security advisor: WARN-level authenticated `SECURITY DEFINER` notices, consistent with the intentional controlled-RPC architecture and with no blocking error identified.

Known repository-wide route-tree TypeScript issues remain pre-existing and unrelated to Sprint 12.

## Next programme state

No Sprint 13 functional scope is frozen by this closeout.

The next journey catalogue boundary is:

`Stage 12 selection_pending -> Stage 13 editing_pending`

That catalogue adjacency does not itself authorize implementation.

Any Sprint 13 work must begin with a new functional scope freeze that defines what authoritative evidence, client-selection state, operational readiness and permissions are actually required before a booking may enter `editing_pending`.

## Explicitly not authorized

This closeout does not authorize:

- Stage 12 -> Stage 13 implementation;
- client-selection data structures or decision capture;
- proofing workflow;
- editing or retouching workflow;
- QC progression;
- gallery publication;
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

Repository-wide authenticated `SECURITY DEFINER` advisor warnings should be handled through separately scoped architecture/security hardening rather than opportunistic changes inside a completed journey-stage sprint.

Previously recorded route-tree typing issues and database performance-hardening candidates remain separately governed technical debt.

## Current next action

Review and merge the Sprint 12 post-release reconciliation governance change.

After Sprint 12 closeout is merged to `main`, prepare a separate Sprint 13 functional scope proposal for the exact Stage 12 -> Stage 13 boundary. Do not create Sprint 13 migrations, modify Sprint 13 implementation code, or mutate Production until that new scope and technical design are explicitly authorized.
