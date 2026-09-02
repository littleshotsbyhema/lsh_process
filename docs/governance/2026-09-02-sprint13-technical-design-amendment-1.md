# Sprint 13 Technical Design Amendment 1

## Status

APPROVED / ACTIVE

## Milestone

**Sprint 13 — Editing Pending**

## Approval

Explicit approval received:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 1`

## Reason for amendment

The frozen Sprint 13 technical design correctly requires the canonical repository-wide role-permission compatibility count to move from `233` to `236` because Sprint 13 introduces the `selection.confirm` permission with exactly three role grants.

During the required full local database regression, one historical Sprint 11 pgTAP assertion remained coupled to the former repository-wide compatibility count of `233`:

`supabase/tests/sprint11_stage10_11_gate_test.sql`

That assertion is not a Sprint 11 behavioral invariant. It is a repository-wide compatibility-count assertion and must track the canonical current mapping count after authorized RBAC evolution.

The frozen Sprint 13 implementation boundary originally authorized the compatibility-count update only in:

`supabase/tests/sprint10_extended_creative_assignments_test.sql`

Therefore changing the corresponding historical Sprint 11 compatibility assertion would otherwise create an unauthorized seventh implementation path.

## Narrow amendment

This amendment authorizes exactly one additional compatibility-only implementation path:

`supabase/tests/sprint11_stage10_11_gate_test.sql`

The only authorized change in that file is:

- repository-wide role-permission compatibility expectation `233 -> 236`;
- matching assertion description text may be updated from `233` to `236`.

No other change in that file is authorized.

## Explicit non-authorization

This amendment does **not** authorize any change to Sprint 11:

- journey semantics;
- Stage 10 -> 11 behavior;
- permissions or role grants;
- RPC signatures, ACLs, RLS, validation or replay behavior;
- shoot-completion evidence contracts;
- fixtures or test setup;
- transition lineage rules;
- audit behavior;
- any assertion other than the repository-wide role-permission compatibility count.

## Amended implementation boundary

Sprint 13 implementation is now limited to exactly seven implementation paths:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint10_extended_creative_assignments_test.sql` only for the canonical compatibility-count update `233 -> 236`;
5. `src/lib/booking.functions.ts`;
6. `src/routes/_authenticated/bookings.tsx`;
7. `supabase/tests/sprint11_stage10_11_gate_test.sql` only for the canonical compatibility-count update `233 -> 236`.

The governance amendment document itself is governance evidence and is not an implementation path.

`src/routeTree.gen.ts` remains excluded.

Any eighth implementation path requires another explicit governance amendment before modification.

## Authority preserved

All other frozen Sprint 13 technical-design requirements remain unchanged, including:

- exact Stage 12 `selection_pending` -> Stage 13 `editing_pending` boundary;
- Stage 14 prohibition;
- provider-neutral canonical selection evidence;
- `selection.confirm` exact grant boundary;
- canonical role-permission count exactly `236`;
- full regression, lint, advisors, generated-type, application, E2E and file-boundary verification gates;
- no Production mutation without separate explicit release authorization.
