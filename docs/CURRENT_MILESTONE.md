# Current Milestone

## Authority

This file is the mutable execution pointer for canonical Memory Keeper OS development.

Durable product and engineering authority lives in:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`

Sprint 13 durable governance authority includes:

- `docs/governance/2026-09-02-sprint13-scope-freeze.md`
- `docs/governance/2026-09-02-sprint13-technical-design-freeze.md`
- `docs/governance/2026-09-02-sprint13-migration-filename-lock.md`
- approved Sprint 13 Technical Design Amendments 2 through 13

Initial go-live release-candidate authority:

- `docs/governance/2026-09-04-initial-production-go-live-release-candidate-closeout.md`

## Canonical repository state

`main` is the single canonical source-of-truth branch and the Vercel Production Git branch.

Canonical merged `main` SHA:

`71630cb426590e1bbc97aa2a8bdb7fa657933c21`

This commit merged PR #23:

`feat(sprint13): selection completion and editing-pending foundation`

Sprint 13 final implementation head:

`275efc6d403315de381fda0cb1783d3e90051d86`

`architecture-rebuild` remains frozen legacy reference history at:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new work to `architecture-rebuild` and do not merge it wholesale into `main`.

## Current execution branch

Current release-closeout branch:

`chore/phase1-release-candidate-closeout`

Purpose:

- reconcile post-Sprint-13 governance state;
- run the Initial Production Go-Live Release Candidate verification;
- verify the Phase 1 operational journey through exact Stage 13;
- identify only material P1/P2 release blockers;
- prepare the separately gated Production database release;
- prepare Production smoke verification and role-based go-live operating guidance.

This branch must not introduce Sprint 14 functionality.

## Current programme milestone

Current milestone:

**Initial Production Go-Live Release Candidate — Stage 13 operational boundary**

The release-candidate operational journey is:

`Lead -> Family -> Memory Guide -> Quotation -> Payment evidence -> Booking -> Preparation -> Team assignment -> Shoot -> Shoot completion -> Selection -> Editing Pending`

The exact final journey boundary is:

`Stage 12 selection_pending -> Stage 13 editing_pending`

Stage 13 means:

`Selection completed + canonical selected-image set locked + editing handoff accepted`

Stage 13 does not mean editing has started.

## Sprint 13 repository state

Sprint 13 implementation is complete and merged into canonical `main`.

Canonical Sprint 13 migration:

`20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`

Canonical Sprint 13 evidence model:

- `public.booking_selection_completions`
- `public.booking_selected_images`

Canonical Sprint 13 RPCs:

- `public.record_booking_selection_completion(uuid,text[],text,text)`
- `public.mark_booking_editing_pending(uuid)`

Canonical selection authority:

`selection.confirm`

Expected grants:

- Founder
- Studio Manager
- Client Coordinator

Journey advancement continues to use:

`booking.stage.advance`

## Sprint 13 final validation state

Final Sprint 13 release-candidate evidence before merge:

- Sprint 13 dedicated pgTAP: `98/98` PASS
- full database suite: `23 files / 1,487 tests` PASS
- local database reset/replay: PASS
- Supabase DB lint: PASS
- Supabase DB advisors: PASS
- generated Supabase types byte-equivalent after fresh regeneration
- canonical final role-permission count with Migration A present: `260`
- TypeScript: PASS
- Production build: PASS
- `git diff --check`: PASS
- Vercel exact-head Preview deployment: SUCCESS
- final Codex exact-head review: COMPLETED with no new material P1/P2 finding

## Vercel Production state

PR #23 was merged to `main` at:

`71630cb426590e1bbc97aa2a8bdb7fa657933c21`

The Vercel Production deployment for that exact merge commit succeeded.

Application code is therefore deployed from the Sprint 13 merged `main` state.

This does not imply that the corresponding Production Supabase migrations have been applied.

## Production Supabase state

Production database mutation remains separately gated.

Verified Production migration tip before the pending release:

`20260901180856_sprint12_stage11_12_selection_pending_gate_foundation.sql`

Verified Production role-permission count:

`233`

Verified pre-Sprint-13 Production state:

- `public.booking_selection_completions` absent
- `public.booking_selected_images` absent
- `public.record_booking_selection_completion(uuid,text[],text,text)` absent
- `public.mark_booking_editing_pending(uuid)` absent

Verified Production journey catalogue includes:

- Stage 12: `selection_pending`
- Stage 13: `editing_pending`
- Stage 14: `editing_in_progress`

Stage 14 pre-exists Sprint 13 and is not evidence of Sprint 13 implementing a Stage 13 -> 14 transition.

## Pending Production migration chronology

Exactly two repository migrations are pending after the verified Production Sprint 12 tip:

1. `20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `20260903084543_lsh_four_branch_role_scope_brand_owner_foundation.sql`

The validated clean chronology is:

`233 -> Sprint 13 -> 236 -> Migration A -> 260`

The Production release must preserve that canonical order.

Do not manually force role-permission counts or selectively recreate migration effects.

## Production authorization state

Production Supabase migrations are:

**HOLD — NOT YET AUTHORIZED**

No `supabase db push`, linked migration execution, manual migration SQL, migration repair, Production reset, or other Production database mutation is authorized by this release-candidate milestone.

Production database execution requires a separate exact human authorization.

## Release Candidate verification boundary

The current release-candidate closeout must verify:

- pristine local database replay from canonical migrations;
- full pgTAP regression;
- Sprint 13 dedicated regression;
- database lint and advisors;
- canonical role-permission count `260` after full local replay;
- active role and permission boundaries;
- branch-scope containment;
- generated Supabase type integrity;
- TypeScript;
- production build;
- `git diff --check`;
- primary Phase 1 operational journey through Stage 13;
- permission-negative paths;
- cross-tenant or cross-branch containment where applicable.

Only genuine material P1/P2 release blockers may interrupt go-live closure.

P3, cosmetic work and non-critical technical debt must be deferred rather than expanding the release boundary.

## Go-live documentation requirement

Before Initial Production Go-Live, prepare the final role-based operating material from the actual verified production system.

Required deliverables:

- Little Shots by Hema OS — Role-Based Go-Live Playbook
- one-page Quick Playbook for every active production role
- Founder / management Go-Live Control Playbook
- tomorrow-morning launch sequence

Per-role guidance must cover access, morning checks, exact screens, allowed and forbidden actions, evidence requirements, handoffs, escalation, notifications, end-of-day checks, recovery guidance, privacy/security, device guidance and first-day quick start.

The role registry and permissions used in these documents must be derived from the final verified system, not assumptions.

## Tomorrow launch sequence

The controlled launch sequence is:

`Founder check -> Team login verification -> Role access verification -> Live booking walkthrough -> First real transaction -> Monitor -> End-of-day review`

## Stage 14 boundary

Sprint 13 introduces:

- no new Stage 14 implementation;
- no Stage 13 -> Stage 14 transition;
- no editing-execution workflow.

Do not begin `editing_in_progress`, editor assignment, retouching execution, QC progression, gallery delivery or later-stage workflow under this milestone.

Any such work requires separately governed scope.

## Roadmap reconciliation note

`docs/IMPLEMENTATION_ROADMAP.md` remains durable programme taxonomy and is not rewritten during release closeout.

The Initial Production Go-Live Release Candidate records the approved operational release boundary actually implemented through Stage 13 without silently redefining the long-term roadmap.

Any durable roadmap restructuring must be separately governed.

## Deferred non-blocking technical debt

Do not expand this release candidate to opportunistically fix:

- repository-wide authenticated `SECURITY DEFINER` advisor warnings;
- TanStack `createServerFn().inputValidator()` deprecation warnings;
- unrelated unused dependency/import warnings;
- dependency `"use client"` build notices;
- existing large-chunk build notice;
- builder architecture notices;
- unrelated route-tree or framework technical debt;
- Sprint 14 or later workflow.

These items may be separately governed after go-live unless a release-candidate test proves one is a material P1/P2 blocker.

## Current status

Sprint 13 code integration: **COMPLETE**

PR #23 merge: **COMPLETE**

Vercel Production deployment of merged application: **SUCCESS**

Production Supabase Sprint 13 / Migration A deployment: **HOLD / NOT AUTHORIZED**

Initial Production Go-Live Release Candidate verification: **READY TO EXECUTE**

Initial Production Go-Live: **NOT YET APPROVED**

## Current next action

Run the Initial Production Go-Live Release Candidate verification from:

`chore/phase1-release-candidate-closeout`

After the release candidate passes:

1. reconcile any material P1/P2 blocker if one exists;
2. request the exact Production Supabase migration authorization;
3. apply the two pending migrations in canonical order only after approval;
4. verify Production database state;
5. run Production application smoke tests;
6. finalize role-based go-live playbooks from the verified production system;
7. execute the controlled Initial Production Go-Live sequence.

Do not begin Sprint 14 during this closeout.
