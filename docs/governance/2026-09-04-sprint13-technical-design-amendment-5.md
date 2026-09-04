# Sprint 13 Technical Design Amendment 5

## Status

APPROVED / ACTIVE

## Milestone

Sprint 13 — Editing Pending

## Approval

Explicit governance approval received on 2026-09-04:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 5`

## Reason

The final fresh Codex review on corrective head
`c94ccb82667f191484a7c326122fc90b7dc65431` identified two remaining P2
hardening gaps.

First, the opaque `image_key` contract rejected HTTP(S) and `www.` values but
did not reject general URI-shaped values such as `s3://` or `ftp://`.

Second, the non-secret `external_reference` contract rejected classic GitHub
token prefixes such as `ghp_` but did not explicitly reject the fine-grained
GitHub token prefix `github_pat_`.

## Authorized correction A — image-key URI rejection

Amendment 5 authorizes the existing opaque image-key boundary to additionally
reject any normalized value containing `://`.

This applies identically to:

- the authoritative `record_booking_selection_completion(...)` RPC; and
- the immutable `booking_selected_images.image_key` table constraint.

This is a provider-neutral structural rule. It does not introduce provider
interpretation or provider integration.

## Authorized correction B — fine-grained GitHub token rejection

Amendment 5 authorizes explicit rejection of values beginning with
`github_pat_` from `external_reference`.

This applies identically to:

- the authoritative `record_booking_selection_completion(...)` RPC; and
- the immutable `booking_selection_completions.external_reference` table
  constraint.

## Required regression coverage

Regression evidence must prove:

1. a non-HTTP URI-shaped image key such as `s3://bucket/family.jpg` is rejected;
2. a `github_pat_...` external reference is rejected;
3. the immutable table constraints mirror both Amendment 5 protections;
4. all prior valid opaque image-key and external-reference behavior remains
   unchanged;
5. role-permission count remains 260;
6. Stage 14 remains absent.

## Preserved invariants

Amendment 5 does not change:

- RPC signatures;
- schema object inventory;
- permissions or role grants;
- immutable evidence semantics;
- replay/idempotency semantics;
- manifest cardinality or key-length bounds;
- the exact Stage 12 `selection_pending` -> Stage 13 `editing_pending` boundary;
- canonical role-permission count 260;
- provider-neutrality.

## Authorized implementation paths

Implementation is limited to:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`;
3. this Amendment 5 governance evidence document.

## Explicit non-authorization

Amendment 5 does not authorize:

- Stage 14;
- editing execution;
- Pixieset or other provider integration;
- new tables, columns, RPCs, permissions, or role grants;
- migration rename or regeneration;
- Production or linked Supabase mutation;
- mutation of `main`;
- force push or history rewriting;
- commit, push, PR approval, or merge without separate explicit authorization.
