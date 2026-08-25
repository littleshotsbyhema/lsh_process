# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation, Slice 2 — Controlled Stage 10 -> 11 / `shoot_completed` Advancement Gate, and Slice 3 — Authenticated `/bookings` Shoot Completion Integration are implemented, validated, pushed to `origin/architecture-rebuild`, and governance closed. Slice 3 implementation is remotely landed at `0dfa357630be8714759d4663e00259b18dafe2bb`. Sprint 11 Slice 4 — Controlled Stage 11 -> 12 / `selection_pending` Advancement Gate is implemented, fully validated locally, pushed to `origin/architecture-rebuild` at `312e7a94ff4dfc47b0924ec0b9ce71c8413f534a`, and governance closed. The exact frozen three-artifact boundary was preserved. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 4 — **Controlled Stage 11 -> 12 / `selection_pending` Advancement Gate** is implemented, fully validated locally, and remotely landed.

`d99e639c871a7aa11757f3b785c7bd33ed2de9f7` — `docs: close sprint 11 slice 3`

Fresh read-only post-shoot discovery established:

- canonical Stage 11 `shoot_completed` and Stage 12 `selection_pending` already exist and are active;
- four current canonical bookings are at Stage 11, journey version 5;
- the only existing post-shoot transition is Stage 10 -> 11 / `shoot_completed`;
- no function references `selection_pending` or `editing_pending`;
- no canonical selection, editing, gallery or delivery table exists;
- no canonical Stage 11 -> 12 transition authority exists;
- `booking.stage.advance` remains granted to Founder, Studio Manager and Client Coordinator;
- editing/delivery permissions already exist as future-domain vocabulary but do not provide journey-stage authority;
- current Stage-11 fixtures contain the required 50% advance only, not full accepted-quotation payment;
- legacy `/editing` and `/pixieset` surfaces remain mock/Zustand-backed and unavailable as canonical operational systems;
- no canonical privacy/image-use table exists in the current post-shoot boundary.

The next bounded implementation is therefore a journey-state gate only.

### Frozen Slice 4 operation

Slice 4 will add exactly one dedicated RPC:

`public.mark_booking_selection_pending(uuid)`

It will:

- require a non-null booking id;
- require an authenticated actor;
- lock the booking as the synchronization root;
- require active organization membership;
- require existing `booking.stage.advance`;
- require booking branch scope where applicable;
- require exactly one current journey state;
- require exact active current Stage 11 / `shoot_completed` for first advancement;
- require exactly one canonical `booking_shoot_completions` row;
- require exactly one canonical Stage 10 `shoot_scheduled` -> Stage 11 `shoot_completed` transition with transition key `shoot_completed`;
- resolve exact active Stage 12 / `selection_pending`;
- append exactly one Stage 11 -> 12 transition with transition key `selection_pending`;
- advance the journey state through optimistic exact-state/version matching;
- increment journey version exactly once;
- emit exactly one structural, non-sensitive `booking.selection_pending` audit event;
- return the canonical booking row.

Exact Stage-12 replay will be idempotent.

Replay will require:

- exact current Stage 12 / `selection_pending`;
- exactly one canonical completion row;
- exactly one canonical Stage 10 -> 11 `shoot_completed` transition;
- exactly one canonical Stage 11 -> 12 `selection_pending` transition.

Valid replay performs no new transition, journey mutation or audit.

Slice 4 does not re-run Stage 9 preparation, staffing or Safety readiness.

Slice 4 does not re-run the Stage 10 reserved-schedule gate. Canonical shoot completion already established that condition, and completion evidence makes subsequent shoot-schedule mutation terminal.

### Selection semantics

Entering `selection_pending` means selection is awaited.

Slice 4 must not assert or fabricate:

- selected image ids;
- selected-image counts;
- selection timestamps;
- client-selection confirmation;
- gallery evidence;
- proofing evidence.

Canonical selection evidence requires a later separately frozen slice.

### Payment boundary

Slice 4 introduces no new payment prerequisite.

Existing Stage-11 fixtures have satisfied the canonical advance requirement but do not represent full accepted-quotation settlement.

The legacy rule that editing begins only after selection and balance payment is not promoted into the Stage 11 -> 12 gate.

Any full-balance prerequisite belongs to later discovery for the transition into editing, not entry into `selection_pending`.

### Permission boundary

Slice 4 introduces no permission and changes no role grant.

Journey advancement continues to use only:

`booking.stage.advance`

Existing editing/delivery permissions do not authorize this transition.

### Security contract

`mark_booking_selection_pending(uuid)` will:

- be `SECURITY DEFINER`;
- use `SET search_path = ''`;
- revoke default/PUBLIC execution;
- deny `anon`;
- deny application execution to `service_role`;
- grant execution only to `authenticated`;
- retain database-side membership, permission and branch enforcement.

### Frozen implementation boundary

Exactly three implementation artifacts:

1. one new migration with logical suffix `sprint11_stage11_12_gate_foundation.sql`;
2. `supabase/tests/sprint11_stage11_12_gate_test.sql`;
3. `src/integrations/supabase/types.ts`.

The migration filename timestamp will be generated locally after implementation authorization.

Any fourth implementation file requires a governance amendment.

### Explicit exclusions

Slice 4 does not implement or modify:

- selection evidence schema;
- image/proof/culling schema;
- editing jobs;
- delivery records;
- Pixieset/gallery records;
- heirloom production;
- privacy/consent schema;
- marketing approval behavior;
- payment ledger behavior;
- full-balance enforcement;
- existing shoot-completion evidence;
- existing shoot-schedule schema;
- Stage 12 -> 13 / `editing_pending`;
- application routes;
- `/bookings` UI;
- `/editing`;
- `/pixieset`;
- remote Supabase;
- `--linked`;
- Production database state;
- Production deployment or release.

### Validation contract

Implementation acceptance will require:

- exact three-artifact implementation boundary;
- clean local database reset;
- dedicated Slice 4 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- regenerated Supabase types with a narrow semantic function addition;
- generated-type Prettier PASS;
- TypeScript PASS;
- production build PASS;
- `git diff --check` PASS;
- explicit scan proving no selection/editing/delivery schema or Stage 12 -> 13 implementation;
- authorized Founder / Studio Manager / Client Coordinator advancement;
- Photographer and Editor denial through absence of `booking.stage.advance`;
- branch-scope denial;
- suspended/inactive actor denial;
- exact Stage-11-only first advancement;
- canonical completion-lineage validation;
- exact Stage-12 replay validation;
- no duplicate transition;
- no duplicate audit;
- no full-payment prerequisite;
- no selection evidence fabricated by advancement.

Implementation completed within the exact frozen three-artifact boundary.

Implementation commit:

`312e7a94ff4dfc47b0924ec0b9ce71c8413f534a` — `feat: gate stage 11 to selection pending`

Validation evidence:

- clean local database reset: PASS;
- dedicated Slice 4 pgTAP: 43/43 PASS;
- full local pgTAP regression: 1304/1304 PASS across 21 files;
- local public-schema DB lint: PASS with no schema errors;
- regenerated Supabase types exactly matched fresh local generation;
- generated-type Prettier: PASS;
- TypeScript: PASS;
- production build: PASS;
- forbidden later-domain table scan: zero rows;
- forbidden later-stage function scan: zero rows;
- migration forbidden-scope scan: clean;
- `git diff --check`: PASS;
- exact implementation boundary: three artifacts only;
- remote branch verification: exact SHA parity with divergence `0 0`.

No remote Supabase migration or Production deployment was performed.

Production remains HOLD.

## Immediate Product Sequence

Sprint 11 Slice 1 provides canonical immutable Shoot Completion evidence.

Sprint 11 Slice 2 provides the controlled Stage 10 -> 11 / `shoot_completed` database advancement gate.

Sprint 11 Slice 3 provides authenticated `/bookings` integration for completion recording and Stage 10 -> 11 advancement.

Sprint 11 Slice 4 is implemented, locally validated, and remotely landed as the controlled Stage 11 -> 12 / `selection_pending` database gate.

The intended sequence is now:

1. perform fresh read-only discovery before defining any canonical selection-evidence model;
2. separately discover the prerequisites for Stage 12 -> 13 / `editing_pending`, including selection evidence and any balance-payment rule;
3. freeze any future selection-evidence or editing boundary independently;
4. integrate Stage 11 -> 12 into the application only under a separately frozen application checkpoint if required.

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
