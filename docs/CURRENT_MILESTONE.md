# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation, Slice 2 — Controlled Stage 10 -> 11 / `shoot_completed` Advancement Gate, and Slice 3 — Authenticated `/bookings` Shoot Completion Integration are implemented, validated, pushed to `origin/architecture-rebuild`, and governance closed. Slice 3 implementation is remotely landed at `0dfa357630be8714759d4663e00259b18dafe2bb`. The next bounded checkpoint is fresh read-only repository/database discovery from canonical Stage 11 before defining any Stage 11 -> 12 or selection-workflow technical boundary. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 3 — **Authenticated `/bookings` Shoot Completion Integration** is implemented, fully validated locally, pushed to `origin/architecture-rebuild`, and governance closed.

Implementation commit:

`0dfa357630be8714759d4663e00259b18dafe2bb` — `feat: integrate shoot completion workflow`

The frozen implementation boundary remained exact:

1. `src/lib/booking.functions.ts`
2. `src/routes/_authenticated/bookings.tsx`

Delivered application integration:

- canonical `booking_shoot_completions` evidence is loaded through ordinary authenticated Supabase access and existing RLS;
- `canRecordShootCompletion` derives only from existing `shoot.complete`;
- authenticated server wrappers call only the existing `record_booking_shoot_completion(uuid,timestamptz)` and `mark_booking_shoot_completed(uuid)` RPCs;
- canonical completion evidence is displayed as immutable read-only evidence;
- completion recording is exposed only at exact Stage 10 / `shoot_scheduled`, only where `shoot.complete` is present, and only before canonical completion evidence exists;
- controlled Stage 10 -> 11 advancement is exposed only after canonical completion evidence exists and where `booking.stage.advance` is present;
- workspace refetch and mutation feedback are integrated;
- Stage 11 preserves completion evidence but exposes neither completion replay nor repeated `shoot_completed` advancement;
- no general journey-stage mutation control was introduced.

No database migration, database function, RLS policy, permission catalogue, role grant, completion schema, shoot-schedule schema, or generated Supabase type changed in Slice 3.

Local role/capability browser validation proved the intended separation of duties:

- Founder: completion recording available before evidence; advancement unavailable until evidence exists;
- Studio Manager: completion recording available before evidence; advancement unavailable until evidence exists;
- Photographer: completion recording available; no `booking.stage.advance` control;
- Client Coordinator: completion recording unavailable; controlled advancement becomes available only after canonical completion evidence exists;
- Stylist: neither completion recording nor advancement control is available.

Canonical end-to-end fixture validation on `LSH-BK-F3E6566E` proved:

- Stage 10 began at `shoot_scheduled`, journey version 4, authoritative schedule `reserved`, and zero completion rows;
- Photographer member `b0758201-5c12-4392-b99b-938066750a2e` recorded exactly one canonical completion row;
- completion recording did not advance the journey and left version 4 unchanged;
- exactly one `booking.shoot_completion_recorded` audit was emitted with the Photographer actor;
- Client Coordinator member `39cbe79e-2009-4648-a816-05f0c2087345` performed the dedicated advancement;
- the journey advanced exactly Stage 10 `shoot_scheduled` -> Stage 11 `shoot_completed`;
- journey version advanced exactly 4 -> 5;
- the original completion id, completed timestamp and Photographer recorder remained unchanged;
- exactly one `booking.shoot_completed` audit was emitted with the Client Coordinator actor;
- exactly one canonical `shoot_completed` transition row exists with the Client Coordinator actor;
- four Stage-11 regression fixtures each remain at Stage 11, version 5, `reserved` schedule tip, and exactly one completion row.

Final validation passed:

- exact two-file implementation boundary;
- `npm run build`;
- `npx tsc -p tsconfig.json --noEmit`;
- targeted ESLint;
- targeted Prettier;
- `git diff HEAD^ HEAD --check`;
- clean worktree;
- local/remote branch parity after push.

Remote verification confirmed `origin/architecture-rebuild` at:

`0dfa357630be8714759d4663e00259b18dafe2bb`

Production migration, deployment and release remain unauthorized. Production remains HOLD.

## Immediate Product Sequence

Sprint 11 Slice 1 provides canonical immutable Shoot Completion evidence.

Sprint 11 Slice 2 provides the controlled Stage 10 -> 11 / `shoot_completed` database advancement gate and completion-terminal schedule boundary.

Sprint 11 Slice 3 provides the authenticated `/bookings` integration for canonical completion evidence and controlled Stage 10 -> 11 advancement.

The next sequence is:

1. governance-close Slice 3 documentation;
2. perform fresh read-only repository and local-database discovery from canonical Stage 11;
3. identify the actual next post-shoot dependency from existing authority;
4. define a separate Technical Design Freeze only after discovery.

No Stage 11 -> 12 / `selection_pending`, selection, editing, QC, gallery, delivery, shoot-day Safety incident, or post-session restricted Safety-note implementation is authorized by this closeout.

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
