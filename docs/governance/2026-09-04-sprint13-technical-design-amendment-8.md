# Sprint 13 Technical Design Amendment 8

Date: 2026-09-04

Status: APPROVED

Approved human gate:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 8`

## Reason

Fresh Codex review of Sprint 13 head
`d0c1105c9c4769a32d87dcd84babd0e08c51d310` identified one P2
concurrency-consistency gap in the Amendment 7 selected-image pagination.

Amendment 7 correctly removed the single-response PostgREST truncation risk,
but the paginated queries still use the mutable set of visible booking IDs.

Because offset-based pages execute as separate database requests, a new
selection completion committed between page requests can introduce selected
image rows earlier in the ordered result. That can shift offsets and cause
rows from the original logical result set to be skipped or duplicated.

## Authorized correction

The selected-image pagination must be anchored to the immutable
selection-completion records captured by the immediately preceding workspace
query.

The application must:

- retain the existing maximum of 100 visible bookings;
- capture the returned `booking_selection_completions` rows once;
- derive their immutable completion IDs before selected-image pagination;
- query `booking_selected_images` using only those captured
  `selection_completion_id` values;
- skip selected-image queries when no completion IDs were captured;
- preserve the existing 1,000-row page size;
- preserve deterministic ordering across pages;
- accumulate all rows from the captured completion set before returning;
- return the same captured completion-row snapshot used to derive the IDs.

A later selection completion committed after the completion snapshot must not
be allowed to enter the in-progress selected-image pagination result.

The existing query architecture is preserved. No new RPC, database read
model, schema object, or transaction boundary is authorized.

## Concurrency invariant

For one `listBookingWorkspace` execution, the selected-image result is defined
by the immutable completion IDs captured by its preceding
`booking_selection_completions` read.

Concurrent finalization of another visible booking after that capture may be
visible on a later workspace refresh, but must not shift, duplicate, or remove
rows belonging to the captured completion set during the current paginated
read.

## Regression requirements

Application validation must prove:

- selected-image retrieval remains complete below 1,000 rows;
- selected-image retrieval remains complete at exactly 1,000 rows;
- selected-image retrieval remains complete above 1,000 rows;
- insertion of rows belonging to a newly created, uncaptured completion
  between page requests does not change membership of the captured result;
- captured rows are neither skipped nor duplicated under that modeled
  concurrent-finalization condition;
- no selected-image query is issued when no completion IDs are captured;
- the returned selection-completion rows are the same captured snapshot used
  to derive pagination membership.

The repository has no existing JavaScript/TypeScript application test runner
or application test-file convention at this amendment boundary. Amendment 8
does not authorize creating a committed test framework or test surface.
Concurrency behavior may be validated with a temporary, non-committed model
plus source inspection, TypeScript, ESLint, Prettier, build, and diff checks.

## Authorized paths

1. `src/lib/booking.functions.ts`
2. `docs/governance/2026-09-04-sprint13-technical-design-amendment-8.md`

## Required validation

- temporary concurrency pagination model
- selected-image pagination validation below 1,000 rows
- selected-image pagination validation at 1,000 rows
- selected-image pagination validation above 1,000 rows
- targeted ESLint
- Prettier
- TypeScript
- production build
- `git diff --check`
- exact two-path Amendment 8 boundary
- existing Sprint 13 database implementation remains untouched
- Sprint 13 introduces no new Stage 14 implementation or Stage 13 -> 14
  transition

## Explicit non-authorization

This amendment does not authorize:

- database migration changes
- database test changes
- new schema objects
- new RPCs or read models
- permission or role-grant changes
- Stage 14
- editing execution
- provider coupling
- new application test framework
- commit
- push
- merge
- `main` mutation
- Production or linked Supabase mutation
- force push or history rewrite
- unrelated refactoring
