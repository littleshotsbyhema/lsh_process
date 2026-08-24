# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is now the active programme. Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation has been implemented, fully validated locally, and pushed to `origin/architecture-rebuild`. It remains not released and Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation is implemented, validated and remotely landed.

Implementation evidence:

- Technical Design Freeze commit: `ee2ad819472657a35142cfb22a8bafa2e12999ce`;
- regression-boundary amendment commit: `2a44d67d393d5703d087b26aa43d694f0cce59e6`;
- implementation commit: `ba07f6d7717e8bcf9c8e1ff8a17fe24ae2231c02`;
- migration: `20260824223000_sprint11_shoot_completion_evidence_foundation.sql`;
- dedicated pgTAP: `sprint11_shoot_completion_evidence_test.sql`;
- generated Supabase types synchronized locally;
- canonical `shoot.complete` permission granted exactly to Founder, Studio Manager and Photographer;
- immutable `booking_shoot_completions` evidence;
- controlled authenticated `record_booking_shoot_completion(uuid,timestamptz)` RPC;
- forced-RLS authenticated read containment through canonical booking access;
- exact Stage 10 / `shoot_scheduled` recording gate;
- current authoritative reserved-schedule requirement;
- exact replay idempotency and conflicting replay rejection;
- one structural audit event on first success;
- no booking journey advancement and no Stage 10 -> 11 transition.

Validation evidence:

- clean local database reset: PASS;
- dedicated Sprint 11 Slice 1 pgTAP: 54/54 PASS;
- amended Sprint 10 compatibility pgTAP: 85/85 PASS;
- complete local pgTAP regression: 1209/1209 PASS across 19 files;
- local database lint: PASS with no schema errors;
- generated-type synchronization and targeted Prettier check: PASS;
- `npx tsc --noEmit`: PASS;
- production build: PASS with only known non-blocking pre-existing warnings;
- `git diff --check`: PASS;
- Stage 10 -> 11 / later-slice containment check: PASS;
- remote branch reconciliation: exact implementation SHA `ba07f6d7717e8bcf9c8e1ff8a17fe24ae2231c02`.

The full-regression compatibility amendment changed only the stale repository-wide role-permission count assertion from 230 to 233, reflecting the three intentional `shoot.complete` grants. No other Sprint 10 test behavior changed.

Slice 1 records completion evidence only. It does not move a booking to Stage 11, expose an application control, create shoot-day Safety evidence, or change team/schedule mutation semantics.

The next checkpoint is Sprint 11 Slice 2 — separately frozen controlled Stage 10 -> 11 / `shoot_completed` advancement consuming the canonical Slice 1 completion evidence.

Production remains HOLD.

## Immediate Product Sequence

Sprint 10 Slice 7R ends at exact Stage 10 / `shoot_scheduled`. Fresh repository discovery has now established the next dependency boundary.

Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation is implemented, fully validated locally and pushed. It introduces completion evidence only and remains not released. It does not move a booking from Stage 10 to Stage 11 and it does not expose a browser control.

The intended sequence is:

1. Sprint 11 Slice 1 — canonical immutable Shoot Completion evidence;
2. Sprint 11 Slice 2 — separately frozen controlled Stage 10 -> 11 / `shoot_completed` gate consuming that evidence;
3. Sprint 11 Slice 3 — separately frozen authenticated `/bookings` integration.

Shoot-day Safety incidents, post-session restricted Safety notes, Stage 11 -> 12, selection, editing, QC, delivery, `/safety` release, `/prep` release, legacy-store reconciliation, Production migration and deployment remain outside Slice 1.

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
