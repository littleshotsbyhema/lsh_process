# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation is implemented, validated and remotely closed. Sprint 11 Slice 2 — Controlled Stage 10 -> 11 / `shoot_completed` Advancement Gate is implemented, fully validated locally and pushed to `origin/architecture-rebuild`. It remains not released. The next bounded checkpoint is Sprint 11 Slice 3 — authenticated `/bookings` application integration, which requires fresh discovery and a separate Technical Design Freeze. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 2 — **Controlled Stage 10 -> 11 / `shoot_completed` Advancement Gate** is implemented, fully validated locally and pushed to `origin/architecture-rebuild`.

Governance freeze:

- `067a6a6b4f54a8acd0a12c66c36d4bb42072266b` — `docs: freeze sprint 11 slice 2`

Implementation:

- `aa4a1985a6cb3d1074b764a9a33a6e258c1d10de` — `feat: add shoot completed advancement gate`

Delivered Slice 2 behavior:

- canonical completion evidence now terminalizes future shoot-schedule inserts;
- immutable historical shoot-schedule evidence remains unchanged;
- exact existing reschedule replay that performs no new insert remains valid;
- no `shoot_schedule_id` was added to Slice 1 completion evidence;
- no timestamp heuristic was introduced to bind completion to a schedule version;
- `public.mark_booking_shoot_completed(uuid)` is the controlled authenticated Stage 10 -> 11 operation;
- first advancement requires exact Stage 10 / `shoot_scheduled`;
- exactly one canonical `booking_shoot_completions` row is required;
- the current authoritative shoot-schedule tip must remain `reserved`;
- the advancing actor must hold `booking.stage.advance`;
- the advancing actor does not need `shoot.complete`;
- Photographer therefore remains able to record completion evidence without gaining journey-advance authority;
- Client Coordinator remains able to advance valid completion evidence without gaining `shoot.complete`;
- first success appends exactly one `shoot_completed` transition;
- canonical journey state advances to exact Stage 11 / `shoot_completed`;
- journey version increments exactly once under optimistic identity/version enforcement;
- first success emits one structural `booking.shoot_completed` audit event;
- exact Stage 11 replay succeeds only with canonical completion evidence and exactly one valid Stage 10 -> 11 transition;
- valid replay creates no additional transition, journey update or audit event;
- Stage 9 readiness, staffing, Safety Readiness and signoff gates are not re-run;
- Stage 11 -> 12 / `selection_pending` remains unimplemented.

Frozen implementation files:

1. `supabase/migrations/20260824234000_sprint11_stage10_11_gate_foundation.sql`
2. `supabase/tests/sprint11_stage10_11_gate_test.sql`
3. `src/integrations/supabase/types.ts`

Validation evidence:

- clean local database reset: PASS;
- dedicated Sprint 11 Slice 2 pgTAP: **52/52 PASS**;
- complete local pgTAP regression: **20 files / 1261 tests PASS**;
- `npx supabase db lint --local`: PASS — `No schema errors found`;
- generated Supabase types: exactly **22 insertions / 0 deletions**, limited to `mark_booking_shoot_completed`;
- generated-types Prettier check: PASS;
- `npx tsc --noEmit`: PASS;
- production build: PASS;
- `git diff --check`: PASS;
- explicit Stage 11 -> 12 / later-stage implementation scan: PASS;
- exact implementation-boundary review: PASS.

Known build warnings remain pre-existing and non-blocking:

- deprecated TanStack `createServerFn().inputValidator()` usage in older modules;
- client chunk larger than 500 kB;
- module-level `"use client"` directives ignored by Rollup in dependencies;
- unknown Rollup `platform` input option warning;
- Wrangler `main` override warning.

No new permission or role grant was introduced.

Slice 1 completion evidence schema was not changed.

No application/UI code was changed in Slice 2.

No remote Supabase migration, `--linked` operation, Production migration or Production deployment was performed.

The next checkpoint is Sprint 11 Slice 3 — authenticated `/bookings` integration for the existing completion-recording operation and the new Stage 10 -> 11 advancement operation. Slice 3 requires fresh repository discovery and its own Technical Design Freeze before implementation.

Production remains HOLD.

## Immediate Product Sequence

Sprint 11 Slice 1 provides canonical immutable Shoot Completion evidence.

Sprint 11 Slice 2 now provides the controlled Stage 10 -> 11 / `shoot_completed` advancement gate consuming that evidence, together with the completion-terminal shoot-schedule boundary. Slice 2 is implemented, fully validated locally and pushed, but remains not released.

The intended next sequence is:

1. fresh discovery for Sprint 11 Slice 3;
2. Sprint 11 Slice 3 Technical Design Freeze;
3. authenticated `/bookings` application integration for completion recording and Stage 10 -> 11 advancement;
4. separate later discovery for any Stage 11 -> 12 / selection workflow.

Shoot-day Safety incidents, post-session restricted Safety notes, Stage 11 -> 12, selection, editing, QC, delivery, `/safety` release, `/prep` release, legacy-store reconciliation, Production migration and deployment remain outside the current checkpoint.

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
