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
- `docs/governance/2026-09-02-sprint13-scope-freeze.md`

## Canonical repository state

`main` is the single canonical source-of-truth branch and the Vercel Production Git branch.

Current canonical `main` head before this Sprint 13 governance branch:

`622e09ea7d19dbd7acfd9df044a037caaf87f0cf`

This commit merged PR #15 and closed Sprint 12 governance.

The released Sprint 12 application SHA remains:

`ec05bba81d19fed31cdf0d8ff9e42ac8a713099e`

`architecture-rebuild` remains frozen legacy reference history at:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new work to `architecture-rebuild` and do not merge it wholesale into `main`.

## Current governance branch

Current branch:

`chore/sprint13-functional-scope-freeze`

Purpose:

- freeze the Sprint 13 functional boundary;
- define the business meaning of Stage 13 `editing_pending`;
- preserve Sprint 12 as the released Production boundary;
- hold technical design, migration creation, implementation and Production mutation until separately authorized.

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

## Canonical journey boundary

The canonical journey-stage catalogue includes:

- Stage 11: `shoot_completed` — Shoot Completed
- Stage 12: `selection_pending` — Selection Pending
- Stage 13: `editing_pending` — Editing Pending
- Stage 14: `editing_in_progress` — Editing In Progress

Production is released through Stage 12 only.

Stage 12 means the completed session has been formally handed into the selection phase and is waiting for selection activity. It does not mean selections are complete or editing has started.

## Current programme

The current programme milestone is:

**Sprint 13 — Editing Pending**

Frozen functional boundary:

`Stage 12 selection_pending -> Stage 13 editing_pending`

Functional scope is frozen in:

`docs/governance/2026-09-02-sprint13-scope-freeze.md`

Stage 13 means the authoritative client selection is complete, the canonical selected-image set is stable/locked according to the future technical design, and the booking has been accepted into the editing queue. It does not mean editing has started.

Functional truth:

`Selection completed + canonical selected-image set locked + editing handoff accepted`

## Sprint 13 status

Functional scope: **FROZEN**.

Technical design: **NOT YET AUTHORIZED OR FROZEN**.

Migration filenames: **NOT YET AUTHORIZED OR LOCKED**.

Implementation: **NOT AUTHORIZED**.

Production deployment: **NOT AUTHORIZED**.

Sprint 13 must stop at exact Stage 13. No Stage 13 -> Stage 14 work is authorized.

## Sprint 13 technical-design gate

Before implementation, the technical-design phase must explicitly resolve:

- the exact authoritative evidence for `selection complete`;
- minimum selection cardinality, if any;
- partial-save versus finalization semantics;
- revision rules and the point at which selection becomes immutable;
- the canonical selection data model, including whether individual selected-image records, a selection-set record or both are required;
- whether any external provider is required for the narrow boundary;
- validation and reconciliation of provider identifiers if external evidence is accepted;
- exact recording and advancement authorities;
- whether `booking.stage.advance` remains sufficient or a narrower permission is justified;
- organization membership, branch-scope, RLS and RPC ACL enforcement;
- replay/idempotency behavior;
- behavior if external selection data changes after Stage 13;
- structural audit events;
- exact application read/write boundary;
- exact migration filenames and implementation paths.

A Pixieset checkbox, webhook, gallery URL, provider selected-count, browser state or any other external/client signal may provide evidence but must never become authoritative journey truth by itself.

The canonical authority chain remains:

`Auth -> Org Membership -> Role -> Permission -> RLS -> Approved RPC -> Validation -> Transaction -> Audit`

## Explicitly out of scope

The current milestone does not authorize:

- Stage 13 -> Stage 14 `editing_in_progress` or later advancement;
- actual editing or retouching workflow;
- editor task allocation unless proven indispensable to Stage 13 entry;
- AI culling, AI editing or automated creative judgment;
- creative QC progression;
- gallery publication beyond minimum selection evidence proven necessary by technical design;
- final delivery;
- album/frame production;
- review or milestone-follow-up workflow;
- media custody/DAM redesign;
- broad Pixieset integration unrelated to the narrow Stage 12 -> 13 contract;
- unrelated Team/RBAC redesign;
- unrelated CRM, quotation, payment, package or public-website changes;
- wholesale legacy-branch migration;
- Production mutation without separate explicit approval.

## Deferred non-blocking technical debt

Repository-wide authenticated `SECURITY DEFINER` advisor warnings remain separately governed architecture/security hardening work.

Previously recorded route-tree typing issues and database performance-hardening candidates remain separately governed technical debt.

## Current next action

Prepare and review the Sprint 13 technical-design freeze for the exact Stage 12 -> Stage 13 boundary.

Do not create Sprint 13 migrations, modify Sprint 13 implementation code, or mutate Production until the technical design is explicitly authorized and frozen and later implementation authorization is granted.
