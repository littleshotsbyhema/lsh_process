# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation is implemented, validated and remotely closed. Sprint 11 Slice 2 — Controlled Stage 10 -> 11 / `shoot_completed` Advancement Gate is now Technical Design Frozen only; implementation is not yet authorized. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 2 — **Controlled Stage 10 -> 11 / `shoot_completed` Advancement Gate** is Technical Design Frozen from exact baseline `b2b016a3e0464d90b0c14cbb72453e0412a02f7e`.

Fresh repository discovery after the remotely closed Slice 1 confirmed:

- canonical Stage 10 is `shoot_scheduled`;
- canonical Stage 11 is `shoot_completed`;
- canonical Stage 12 is `selection_pending`;
- Slice 1 provides one immutable `booking_shoot_completions` row per booking;
- `record_booking_shoot_completion(uuid,timestamptz)` records evidence at exact Stage 10 but intentionally performs no journey advancement;
- no Stage 10 -> 11 RPC, migration, generated API surface or dedicated pgTAP suite currently exists;
- `booking.stage.advance` remains the canonical journey-advancement permission;
- `shoot.complete` remains independently granted to Founder, Studio Manager and Photographer;
- Photographer therefore records canonical completion evidence but does not gain generic journey-advancement authority;
- Client Coordinator retains journey-advancement authority without gaining `shoot.complete`;
- existing shoot rescheduling remains legal through exact Stage 10;
- Slice 1 completion evidence is booking-level and does not bind a `shoot_schedule_id`.

The frozen Slice 2 design resolves that final schedule ambiguity by making canonical completion evidence terminal for future shoot-schedule evidence. Once `booking_shoot_completions` exists for a booking, no new `booking_shoot_schedules` row may be appended. Existing immutable schedule history remains unchanged, and exact RPC replay that performs no new schedule insert remains outside that prohibition.

Slice 2 will introduce one controlled authenticated `mark_booking_shoot_completed(uuid)` RPC. It will consume Slice 1 completion evidence, require exact Stage 10 for first advancement, append the canonical `shoot_completed` transition, advance the canonical journey state to exact Stage 11 with optimistic version enforcement, emit one structural audit event, and support strict Stage 11 replay.

The advancing actor must hold `booking.stage.advance`; the actor is not required to hold `shoot.complete` and is not required to be the member who recorded completion evidence.

Slice 2 will not re-run Stage 9 preparation, staffing, safety-readiness or signoff gates. It will not modify Slice 1 completion evidence, introduce shoot-day Safety evidence, expose application UI, or advance Stage 11 -> 12.

Implementation is not yet authorized.

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
