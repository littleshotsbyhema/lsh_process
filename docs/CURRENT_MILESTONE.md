# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation is implemented, validated and remotely closed. Sprint 11 Slice 2 — Controlled Stage 10 -> 11 / `shoot_completed` Advancement Gate is implemented, fully validated locally and pushed to `origin/architecture-rebuild`. It remains not released. The next bounded checkpoint is Sprint 11 Slice 3 — authenticated `/bookings` application integration, which requires fresh discovery and a separate Technical Design Freeze. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 3 — **Authenticated `/bookings` Shoot Completion Integration** is Technical Design Frozen from exact baseline `8b1e9527a20962904962f890d746afbd5f0ccdb7`.

Fresh repository discovery after the remotely closed Slice 2 confirmed:

- `public.record_booking_shoot_completion(uuid,timestamptz)` already exists and records canonical immutable completion evidence at exact Stage 10;
- `public.mark_booking_shoot_completed(uuid)` already exists and performs the controlled exact Stage 10 -> 11 advancement;
- generated Supabase types already contain `booking_shoot_completions`, `record_booking_shoot_completion` and `mark_booking_shoot_completed`;
- `/bookings` currently exposes neither canonical completion evidence nor either Sprint 11 mutation;
- `BookingWorkspaceData` currently exposes `canAdvanceBookingStage` but no `shoot.complete` capability;
- authenticated `booking_shoot_completions` SELECT is already protected by canonical `booking.read` and branch-scope RLS;
- the existing Stage 9 -> 10 application pattern uses a dedicated authenticated server wrapper, dedicated route control, mutation feedback and workspace refetch;
- there is no existing source-level application test suite covering `/bookings`;
- no database or generated-type change is required for Slice 3.

The frozen Slice 3 implementation boundary is exactly:

1. `src/lib/booking.functions.ts`
2. `src/routes/_authenticated/bookings.tsx`

Any third implementation file requires a governance amendment before implementation.

`src/lib/booking.functions.ts` will:

- add `BookingShootCompletionRow` from existing generated table types;
- add `shootCompletions` to `BookingWorkspaceData`;
- add `canRecordShootCompletion`, derived only from existing `shoot.complete`;
- load visible `booking_shoot_completions` rows through ordinary authenticated Supabase SELECT/RLS;
- return an empty `shootCompletions` array on the empty-bookings path;
- add a narrow validated `recordBookingShootCompletion` server function calling `record_booking_shoot_completion`;
- add a narrow validated `markBookingShootCompleted` server function calling `mark_booking_shoot_completed`;
- preserve `requireSupabaseAuth` on both operations;
- surface canonical RPC errors rather than translating database authorization or journey rules into browser logic.

`src/routes/_authenticated/bookings.tsx` will:

- read the canonical completion row for each booking from workspace data;
- display existing completion evidence as immutable read-only evidence;
- expose completion recording only at exact Stage 10 / `shoot_scheduled`, to actors whose workspace capability includes `shoot.complete`, and only while no canonical completion row is already visible;
- accept a required local date/time input for the actual completion time and convert the parsed value to ISO before calling the server function;
- perform only basic input parsing in the browser;
- not duplicate the database future-time, branch-scope, reserved-schedule, exact-stage, idempotency or evidence-integrity gates;
- refresh the booking workspace after successful recording;
- expose controlled Stage 10 -> 11 advancement only through the dedicated `markBookingShootCompleted` server function;
- use existing `canAdvanceBookingStage` as the application capability for advancement;
- sequence advancement from canonical completion evidence without reproducing the RPC's schedule, completion-cardinality, replay-history, optimistic-version or audit gates;
- refresh the booking workspace after successful advancement;
- expose useful mutation success/error feedback;
- keep completion evidence visible as historical read-only evidence at Stage 11 and later;
- expose no repeated Stage 11 replay button;
- expose no general journey-stage mutation control.

Separation of duties remains unchanged:

- Founder and Studio Manager may record completion through their existing `shoot.complete` grant and may advance through their existing `booking.stage.advance` grant;
- Photographer may record canonical completion evidence but does not gain `booking.stage.advance`;
- Client Coordinator may advance valid canonical completion evidence through existing `booking.stage.advance` but does not gain `shoot.complete`;
- Slice 3 introduces no permission and changes no role grant.

Slice 3 does not authorize:

- any Supabase migration;
- any generated Supabase type change;
- any permission or role-grant mutation;
- any RLS change;
- any completion-schema change;
- any `shoot_schedule_id`;
- any timestamp-based schedule inference;
- any Stage 11 -> 12 / `selection_pending` implementation;
- any shoot-day Safety incident model;
- any post-session restricted Safety-note model;
- any selection, editing, QC, gallery or delivery workflow;
- any remote Supabase operation;
- `--linked`;
- any Production database mutation;
- any Production deployment or release.

Frozen validation boundary:

- exact two-file implementation diff;
- targeted Prettier check for both files;
- targeted ESLint for both files, with any pre-existing baseline issue distinguished from Slice 3 regressions;
- `npx tsc --noEmit`;
- `npm run build`;
- `git diff --check`;
- explicit scan proving no database, generated-type or Stage 11 -> 12 implementation change;
- local authenticated browser validation across the role/capability split and Stage 10 -> 11 flow.

Implementation is not yet authorized.

Production remains HOLD.

## Immediate Product Sequence

Sprint 11 Slice 1 provides canonical immutable Shoot Completion evidence.

Sprint 11 Slice 2 provides the controlled Stage 10 -> 11 / `shoot_completed` database advancement gate and completion-terminal schedule boundary.

Sprint 11 Slice 3 is now separately Technical Design Frozen for authenticated `/bookings` integration only.

The intended sequence is:

1. implement the frozen two-file Slice 3 application boundary;
2. validate authenticated completion recording and Stage 10 -> 11 advancement locally;
3. close Slice 3 separately after implementation evidence is reconciled;
4. perform fresh discovery before any Stage 11 -> 12 / selection workflow.

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
