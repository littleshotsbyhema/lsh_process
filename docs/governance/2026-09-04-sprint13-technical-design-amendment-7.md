# Sprint 13 Technical Design Amendment 7

Date: 2026-09-04

Status: APPROVED

Approved human gate:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 7`

## Reason

Fresh Codex review of Sprint 13 head
`63e5980fac8c1ada8d0cdb4a7f6a3394e824d2b7` identified two P2
correctness and resilience gaps:

1. selected-image workspace reads can silently truncate when the rows for the
   visible booking set exceed the PostgREST response limit;
2. immutable `source_type` evidence is non-empty but otherwise structurally
   unbounded.

This amendment authorizes only the narrow remediation of those findings.

## Authorized correction A — bounded source_type

The authoritative normalized `source_type` contract is:

- trim before validation and persistence;
- require a non-empty normalized value;
- maximum normalized length: 64 characters;
- reject control characters;
- preserve the normalized value as canonical immutable evidence;
- enforce the same structural boundary in both
  `record_booking_selection_completion(...)` and
  `booking_selection_completions_source_type_chk`.

Existing replay, immutability, audit, authorization, and Stage 12 -> 13
semantics remain unchanged.

## Authorized correction B — complete selected-image workspace reads

`listBookingWorkspace` must no longer derive workspace selected-image state
from a single potentially truncated PostgREST response.

The existing read architecture is preserved. No new RPC or read-model schema
is authorized.

The application must:

- retain the existing maximum of 100 visible bookings;
- paginate `booking_selected_images`;
- use a page size no greater than 1,000;
- use deterministic ordering across pages;
- continue until a page contains fewer rows than the page size;
- accumulate all returned rows before exposing workspace selected-image data.

The implementation uses `booking_id`, `ordinal`, `created_at`, and `id` as
deterministic ordering keys.

## Regression requirements

Database regression must prove:

- valid source types continue to succeed;
- empty source types continue to fail;
- source types over 64 characters fail;
- control-character source types fail;
- invalid source-type attempts create no completion evidence, selected-image
  evidence, audit event, or journey transition;
- the immutable table constraint mirrors the authoritative RPC protection;
- existing replay behavior remains unchanged;
- Stage 12 -> 13 semantics remain unchanged;
- Sprint 13 introduces no new Stage 14 implementation or Stage 13 -> 14 transition.

Application validation must prove that selected-image retrieval remains
correct when the result contains more than 1,000 rows and remains correct
below the pagination threshold.

The repository has no existing JavaScript/TypeScript application test runner
or application test-file convention at this amendment boundary. Amendment 7
therefore does not authorize creating a new committed test framework or test
surface. The pagination behavior may be proven with a temporary,
non-committed validation harness plus TypeScript, ESLint, build, and source
inspection.

## Authorized paths

1. `src/lib/booking.functions.ts`
2. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
3. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`
4. `docs/governance/2026-09-04-sprint13-technical-design-amendment-7.md`

## Required validation

- pristine local database replay/reset
- Sprint 13 dedicated pgTAP
- targeted affected database regression
- full database pgTAP suite
- Supabase DB lint
- Supabase DB advisors
- generated Supabase type verification
- selected-image pagination validation above 1,000 rows
- targeted ESLint
- Prettier
- TypeScript
- production build
- `git diff --check`
- canonical role-permission count remains 260
- Sprint 13 introduces no new Stage 14 implementation or Stage 13 -> 14 transition

## Explicit non-authorization

This amendment does not authorize:

- commit
- push
- merge
- `main` mutation
- Production or linked Supabase mutation
- migration rename or regeneration
- new schema objects
- new RPCs or read models
- new permissions or role grants
- Stage 14
- editing execution
- provider coupling
- new application test framework
- force push or history rewrite
- unrelated refactoring
