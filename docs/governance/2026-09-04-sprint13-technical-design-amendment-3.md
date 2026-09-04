# Sprint 13 Technical Design Amendment 3

## Status

APPROVED / ACTIVE

## Milestone

Sprint 13 — Editing Pending

## Approval

Explicit governance approval received on 2026-09-04:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 3`

Separate remediation commit authorization was also received:

`APPROVE SPRINT 13 REMEDIATION COMMIT`

## Reason

Two post-Amendment-2 security review findings require tighter server-side
control over caller-supplied finalized-selection image manifests.

## Authorized image-key safety contract

`image_key` remains a provider-neutral, booking-scoped opaque operational
identifier only.

Amendment 3 authorizes:

- maximum normalized image-key length: 255 characters;
- rejection of URL-shaped values;
- rejection of URL query/credential delimiters;
- rejection of obvious credential/token-shaped values;
- rejection of control-character payloads;
- preservation of normalized, immutable, unique manifest semantics.

No gallery-provider schema or Pixieset-specific contract is introduced.

## Authorized manifest resource bound

A finalized-selection RPC call may contain at most 500 selected image keys.

This is a resource-safety bound only. It does not alter commercial package
entitlements or introduce draft-selection persistence.

## Authorized evaluation order

`record_booking_selection_completion(...)` must perform:

1. booking ID validation;
2. authenticated-user validation;
3. target booking resolution and row lock;
4. active organization-membership authorization;
5. `selection.confirm` authorization;
6. booking branch-scope authorization;
7. bounded finalized-manifest validation and normalization;
8. the previously frozen Stage 12 lineage/evidence/replay transaction.

This preserves the existing booking synchronization root and does not expand
locking to unrelated relations.

## Authorized implementation paths

Corrective implementation remains limited to:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`;
3. this Amendment 3 governance evidence document.

## Preserved authority

Amendment 3 does not authorize:

- Stage 14;
- editing execution;
- RPC signature changes;
- new database tables or columns;
- new permissions or role grants;
- provider-specific media custody;
- Production or linked Supabase mutation;
- mutation of `main`;
- force push or history rewriting.

The canonical final role-permission count with Migration A present remains 260.
