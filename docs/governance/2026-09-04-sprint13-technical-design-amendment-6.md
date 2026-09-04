# Sprint 13 Technical Design Amendment 6

Status: APPROVED / ACTIVE

Date: 2026-09-04

## Human approval

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 6`

## Reason

Fresh Codex review of Sprint 13 head
`285adf15abe24286974544fc8fadc277ddb72551` identified one remaining P2 gap:
fine-grained GitHub tokens beginning with `github_pat_` were rejected from
`external_reference` but not from immutable selected-image keys.

## Authorized correction

Amendment 6 authorizes only:

1. adding `github_pat_` rejection to
   `booking_selected_images_image_key_chk`;
2. adding matching rejection to image-key validation inside
   `record_booking_selection_completion(...)`;
3. focused regression coverage proving rejection, mutation-free behavior,
   and protection in both authoritative server-side boundaries.

## Preserved invariants

This amendment does not alter:

- Stage 12 `selection_pending` to Stage 13 `editing_pending`;
- immutable evidence structure;
- RPC signatures;
- authorization order;
- 500-image manifest ceiling;
- 255-character image-key bound;
- permissions or role mappings;
- canonical role-permission count 260;
- replay/idempotency semantics;
- provider neutrality;
- audit sensitivity boundaries;
- Migration A reconciliation.

## Authorized implementation paths

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`
3. `docs/governance/2026-09-04-sprint13-technical-design-amendment-6.md`

## Explicit non-authorization

This amendment does not authorize Stage 14, editing execution, new schema
objects, new RPCs, permission changes, provider integration, migration rename,
Production or linked Supabase mutation, `main` mutation, commit, push, merge,
force-push, or history rewrite.
