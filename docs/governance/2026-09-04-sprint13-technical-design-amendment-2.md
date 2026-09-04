Sprint 13 Technical Design Amendment 2
======================================

Status
------

APPROVED / ACTIVE

Milestone
---------

Sprint 13 — Editing Pending

Approval
--------

Explicit governance approval received on 2026-09-04 for the reconciled Migration A role-permission chronology and the selection-completed audit-metadata safety correction.

Reason for amendment
--------------------

Sprint 13 Technical Design Amendment 1 was approved before reconciliation with Migration A and therefore records the historical repository-wide role-permission compatibility movement as `233 -> 236`, with `236` described as the canonical count.

Migration A subsequently introduced the approved four-branch role-scope and Brand Owner foundation. After that reconciliation, the repository supports two legitimate chronology baselines:

- clean historical replay: pre-Sprint 13 `233`, Sprint 13 adds exactly three `selection.confirm` grants to reach `236`, then Migration A produces the canonical final count `260`;
- Migration-A-present / production-history replay: pre-Sprint 13 `257`, Sprint 13 adds exactly three `selection.confirm` grants to reach the canonical final count `260`.

The implementation already validated both paths successfully. This amendment supplies the explicit governance authority required for that reconciled chronology.

This amendment also addresses the frozen non-sensitive audit contract for `booking.selection_completed`. `source_type` remains canonical immutable selection-completion evidence, but an unrestricted structural source descriptor must not be copied into the non-sensitive immutable audit metadata.

Supersession boundary
---------------------

Amendment 1 remains historical governance evidence.

Amendment 2 supersedes Amendment 1 only where Amendment 1 describes:

- `233 -> 236` as the only supported compatibility-count transition;
- `236` as the final canonical repository-wide role-permission count;
- the Sprint 10 and Sprint 11 reconciled compatibility assertions as requiring `236`.

All other Amendment 1 authority remains unchanged.

Authorized role-permission chronology
-------------------------------------

The approved Sprint 13 compatibility chronology is now:

- clean replay: `233 -> 236 -> 260`;
- Migration-A-present replay: `257 -> 260`;
- canonical final role-permission mapping count with Migration A present: exactly `260`.

Sprint 13 still introduces exactly one permission, `selection.confirm`, with exactly three role grants.

This amendment does not authorize any additional permission, grant, role-scope, Brand Owner, branch, or RBAC semantic change.

Historical compatibility assertions
-----------------------------------

The already-reconciled compatibility assertions in:

- `supabase/tests/sprint10_extended_creative_assignments_test.sql`;
- `supabase/tests/sprint11_stage10_11_gate_test.sql`;

are explicitly authorized to reflect the Migration-A-present baseline `257 -> 260`.

No additional behavioral or fixture change in those files is authorized by this amendment.

Audit-metadata safety correction
--------------------------------

For the `booking.selection_completed` audit event:

- `source_type` remains required canonical evidence on `booking_selection_completions`;
- replay comparison of canonical `source_type` remains unchanged;
- `source_type` must be omitted from non-sensitive audit metadata;
- selected image keys, image URLs or content, credentials or tokens, private family notes, child-sensitive content, Safety data, and medical details remain prohibited from audit metadata.

The structural audit metadata may retain:

- booking ID;
- selection completion ID;
- selected-image count;
- completion timestamp.

No `source_type` allowlist is introduced by this amendment.

Regression authority
--------------------

Sprint 13 regression coverage is authorized to prove that the `booking.selection_completed` audit event does not contain a `source_type` metadata key while preserving the existing evidence-row and replay behavior.

Implementation boundary
-----------------------

This amendment authorizes corrective edits only to:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`.

This Amendment 2 document is governance evidence and is not an implementation path.

The existing Sprint 13 implementation-path boundary otherwise remains unchanged. No eighth implementation path is authorized.

Explicit non-authorization
--------------------------

This amendment does not authorize:

- Stage 14 implementation;
- editing execution;
- RPC signature changes;
- new tables or columns;
- generated Supabase type changes;
- UI changes;
- application service changes;
- additional permissions or role grants;
- Brand Owner or branch-scope changes;
- production Supabase mutation;
- remote migration application;
- staging, commit, push or merge;
- history rewriting or force push.

Authority preserved
-------------------

All remaining frozen Sprint 13 technical-design requirements stay in force, including the exact Stage 12 `selection_pending` -> Stage 13 `editing_pending` boundary, provider-neutral selection evidence, immutable completion evidence, exact permission boundary, replay guarantees, audit safety requirements, and separate human-controlled release gates.
