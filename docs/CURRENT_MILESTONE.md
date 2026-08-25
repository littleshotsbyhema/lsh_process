# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released.

Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slices 1 through 5 are implemented, fully validated locally, committed, pushed to `origin/architecture-rebuild`, and remotely reconciled. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 5 — **Canonical Client Image Selection Confirmation Evidence Foundation** is implemented, validated and remotely landed.

Technical Design Freeze:

`049050859b237439dfd9debb8d80fedddb06a72e` — `docs: freeze sprint 11 slice 5`

Implementation:

`ba488ad6a2eae07f2f4e06f384a934ab3941deda` — `feat: add selection confirmation evidence foundation`

Remote reconciliation:

- local HEAD = `ba488ad6a2eae07f2f4e06f384a934ab3941deda`;
- `origin/architecture-rebuild` = `ba488ad6a2eae07f2f4e06f384a934ab3941deda`;
- divergence = `0 / 0`;
- worktree clean.

### Delivered canonical fact

Slice 5 establishes one missing canonical fact:

**the client has confirmed a final image selection, with an authoritative selected-image count and confirmation timestamp.**

Delivered database authority includes:

- `public.booking_selection_confirmations`;
- `public.record_booking_selection_confirmation(uuid, integer, timestamptz)`;
- `selection.read`;
- `selection.record`;
- authenticated branch-aware RLS reads;
- RPC-only evidence recording;
- immutable confirmation evidence;
- exact Stage 12 / `selection_pending` containment;
- exact canonical Stage 11 `shoot_completed` -> Stage 12 `selection_pending` lineage validation;
- exact replay idempotency;
- conflicting replay rejection;
- one structural, non-sensitive `booking.selection_confirmed` audit event.

Slice 5 does not advance the booking journey.

Stage 12 remains `selection_pending` after selection confirmation is recorded.

### Validation evidence

Final local acceptance completed successfully:

- clean local database reset: PASS;
- dedicated Slice 5 pgTAP: **76/76 PASS**;
- full local pgTAP regression: **1380/1380 PASS** across 22 files;
- local database lint: PASS (`No schema errors found`);
- generated Supabase types: narrow **67 additions / 0 deletions**;
- generated-type Prettier: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS;
- `git diff --check`: PASS;
- canonical permissions: **68**;
- canonical role-permission mappings: **241**;
- post-test persisted selection confirmations: **0**;
- `selection.read.requires_server_enforcement = false`;
- `selection.record.requires_server_enforcement = true`;
- exact frozen five-artifact implementation boundary: PASS.

### Containment preserved

Slice 5 does not introduce or modify:

- individual selected-image identifiers or assets;
- gallery/Pixieset/proofing/culling authority;
- package-entitlement interpretation;
- package-inclusion restructuring or backfill;
- additional-image billing;
- the approved INR 500 additional-image commercial rule execution;
- post-booking commercial adjustments;
- accepted quotation mutation;
- supplemental quotation or invoice behavior;
- full-settlement calculation;
- payment ledger behavior;
- privacy or consent authority;
- Stage 12 -> 13 / `editing_pending`;
- editing jobs, QC, delivery or heirloom production;
- application routes or UI;
- remote Supabase;
- Production deployment or release.

## Immediate Product Sequence

Sprint 11 Slice 5 governance is closed by this checkpoint.

The next checkpoint is **fresh read-only discovery**, not implementation.

Discovery must establish the authoritative boundary for:

1. machine-readable package image entitlement;
2. post-selection commercial reconciliation;
3. additional-image obligation semantics;
4. post-booking financial obligation and settlement state;
5. the prerequisites that would eventually permit Stage 12 -> 13 / `editing_pending`.

No next implementation slice is named or frozen until that discovery establishes a defensible boundary.

Remote Supabase remains HOLD.

Production remains HOLD.

## Known Debt Outside This Checkpoint's Boundary

Repository-wide ESLint/Prettier formatting debt exists in pre-Sprint-10 files (concentrated in `src/lib/leads.functions.ts`, `src/lib/lead-workspace.functions.ts`, and several `src/routes/_authenticated/*.tsx` files). This debt is acknowledged and tracked but remains outside every Sprint 10 slice's acceptance boundary. It must not be expanded into a repository-wide cleanup without a separately authorized checkpoint.

## Sprint 11 Slice 1 Regression Boundary Amendment — 2026-08-24

Full local pgTAP regression after the dedicated Sprint 11 Slice 1 suite passed 54/54 exposed one stale pre-existing global catalogue-count assertion in `supabase/tests/sprint10_extended_creative_assignments_test.sql`.

That Sprint 10 assertion expects exactly 230 `role_permissions` rows. Sprint 11 Slice 1 intentionally adds exactly three new `shoot.complete` grants — Founder, Studio Manager and Photographer — so the canonical total is now 233. The full regression result was 1208 passing assertions out of 1209, with this count assertion as the sole failure.

The Slice 1 implementation boundary is therefore amended by exactly one compatibility-regression file:

- `supabase/tests/sprint10_extended_creative_assignments_test.sql`

The permitted change in that file is limited to:

- changing the global canonical role-permission mapping expectation from 230 to 233;
- updating that assertion's description so it no longer represents the historical Slice 6A total as the current repository-wide total.

This amendment does not authorize:

- any change to the pgTAP plan count;
- any other Sprint 10 test behavior or fixture;
- any additional permission or role grant;
- any migration behavior change;
- any application/runtime/UI change;
- any Stage 10 -> 11 implementation;
- any remote Supabase or Production mutation.

The original Slice 1 migration, dedicated pgTAP suite and generated Supabase types remain the canonical implementation artifacts. Generated types remain deferred until the complete local regression is green.

Production remains HOLD.

## Completion Report Required

For each checkpoint report:
- what existed before
- what changed
- database migrations/functions/policies changed
- routes/components changed
- tests run and results
- manual verification performed
- security/tenant isolation checks
- unresolved issues
- recommended next checkpoint
