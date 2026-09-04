# Sprint 13 Migration Filename Lock

## Status

LOCKED / IMPLEMENTATION HOLD

## Milestone

**Sprint 13 — Editing Pending**

Exact journey boundary:

`Stage 12 selection_pending -> Stage 13 editing_pending`

## Authority

This checkpoint is subordinate to:

- `docs/governance/2026-09-02-sprint13-scope-freeze.md`
- `docs/governance/2026-09-02-sprint13-technical-design-freeze.md`

The technical design is already frozen on canonical `main`.

## Canonical implementation base

Sprint 13 implementation branch:

`feature/sprint13-editing-pending`

Canonical base commit:

`265d197bfbe191a4cf99f64af1475d21da50bd7f`

## Supabase CLI evidence

CLI version used to generate the migration filename:

`2.114.0`

The filename was generated with the Supabase CLI using the frozen logical migration name:

`sprint13_selection_completion_stage12_13_editing_pending_foundation`

## Locked migration filename

The exact Sprint 13 migration filename is now frozen as:

`20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`

This filename must not be renamed, replaced, regenerated, or duplicated during Sprint 13 implementation without an explicit governance amendment.

## Filename-lock boundary

At this checkpoint:

- the locked migration file exists;
- the migration file contains no implementation SQL;
- no schema change has been applied;
- no local or Production database mutation is authorized by this checkpoint;
- no application implementation is authorized by this checkpoint;
- Stage 13 -> Stage 14 remains out of scope.

## Frozen implementation boundary

After separate Sprint 13 implementation authorization, work remains limited to the six paths frozen by the technical design:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint10_extended_creative_assignments_test.sql` only for the compatibility-count update `233 -> 236` if required;
5. `src/lib/booking.functions.ts`;
6. `src/routes/_authenticated/bookings.tsx`.

Any seventh implementation path requires explicit governance amendment.

`src/routeTree.gen.ts` is not an authorized Sprint 13 implementation path.

## Next gate

Implementation remains **HOLD**.

No SQL or application code may be written under this checkpoint alone.

The next required approval is:

`APPROVE SPRINT 13 IMPLEMENTATION`
