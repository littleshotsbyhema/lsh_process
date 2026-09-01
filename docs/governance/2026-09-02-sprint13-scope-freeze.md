# Sprint 13 Functional Scope Freeze

## Status

FUNCTIONAL SCOPE FROZEN / TECHNICAL DESIGN NOT YET AUTHORIZED

## Milestone

**Sprint 13 — Editing Pending**

Exact journey boundary:

`Stage 12 selection_pending -> Stage 13 editing_pending`

Sprint 13 must stop at exact Stage 13. Stage 13 -> Stage 14 is not authorized by this freeze.

## Product intent

Sprint 13 establishes the controlled operational handoff from completed client selection into the editing queue while preserving Little Shots by Hema's Memory Preservation Operating System authority model.

Stage 13 `editing_pending` means the authoritative selection decision is complete and sufficiently stable for the studio to begin post-production work. It does not mean editing has started.

The functional truth for Stage 13 is therefore:

`Selection completed + canonical selected-image set locked + editing handoff accepted`

This preserves a clean distinction between:

- Stage 12 `selection_pending`: waiting for selection activity;
- Stage 13 `editing_pending`: selection complete and waiting to enter editing;
- Stage 14 `editing_in_progress`: editing has actually begun.

## Authorized functional areas

Sprint 13 may design and, only after separate implementation authorization, implement:

1. a canonical selection-completion concept associated with a booking;
2. the minimum stable selected-image manifest or equivalent authoritative selection record required to prove client selection is complete;
3. the exact server-controlled Stage 12 -> Stage 13 advancement contract;
4. safe authenticated read surfaces for selection-completion provenance and editing-handoff readiness;
5. the minimum Bookings workspace presentation and action required for the exact Stage 12 -> 13 boundary;
6. structural audit evidence and canonical journey-transition evidence;
7. required pgTAP, generated types, application validation, build and end-to-end verification;
8. only the minimum supporting database/application changes demonstrated by the frozen technical design.

## Mandatory design questions before implementation

The Sprint 13 technical-design phase must resolve, explicitly and before any implementation:

- what exact evidence constitutes `selection complete`;
- whether at least one image must be selected;
- whether a selection may be partially saved before finalization;
- whether a finalized selection can be revised, and until what journey point;
- whether selection evidence becomes immutable once Stage 13 is reached;
- whether the canonical model requires individual selected-image records, a selection-set record, or both;
- whether external-provider identifiers may be accepted as evidence and how they are validated and reconciled;
- whether Pixieset or another provider is needed at all for the narrow Stage 12 -> 13 boundary;
- which roles may record or confirm selection completion;
- which roles may advance the booking to Editing Pending;
- whether existing `booking.stage.advance` authority is sufficient or a narrower permission is justified;
- how organization membership, branch scope, RLS and RPC ACLs apply;
- replay/idempotency behavior;
- what happens if an external gallery or selection later changes after Stage 13;
- required structural audit events;
- exact browser/server/database authority split;
- exact migration filenames and implementation paths.

No answer to these technical questions is implied beyond the functional truths frozen here.

## External-provider authority rule

A Pixieset checkbox, webhook, gallery URL, provider selected-count, browser-side state or any other external/client signal must never become authoritative journey truth by itself.

External provider data may be accepted only as evidence that the Memory Keeper OS validates and records through the canonical authority chain:

`Auth -> Org Membership -> Role -> Permission -> RLS -> Approved RPC -> Validation -> Transaction -> Audit`

Browser/UI state must never become the authority for journey advancement.

## Explicitly out of scope

This milestone does not authorize:

- Stage 13 -> Stage 14 `editing_in_progress` or any later journey advancement;
- actual editing or retouching workflow;
- editor task allocation unless the technical design proves it is indispensable to Stage 13 entry;
- AI culling, AI editing or automated creative judgment;
- creative QC progression;
- gallery publication beyond the minimum selection evidence, if any, proven necessary for Stage 13 entry;
- final gallery delivery;
- album/frame production;
- review or milestone-follow-up automation;
- media-file custody architecture or DAM redesign;
- broad Pixieset integration unrelated to the narrow Stage 12 -> 13 contract;
- Team/RBAC redesign unrelated to the narrow boundary;
- CRM, quotation, payment, package or public-website changes;
- wholesale migration of `architecture-rebuild`;
- Production mutation without separate explicit release authorization.

## Authority and safety constraints

All Sprint 13 design must preserve the canonical authority chain:

`Auth -> Org Membership -> Role -> Permission -> RLS -> Approved RPC -> Validation -> Transaction -> Audit`

The selected-image record must represent deterministic operational truth, not creative judgment generated by AI.

Sensitive family, child, Safety or private-note data must remain outside structural audit payloads unless separately justified and governed.

## Implementation status

Functional scope: **FROZEN**.

Technical design: **NOT YET AUTHORIZED OR FROZEN**.

Migration creation: **NOT AUTHORIZED** until the technical design defines the required database boundary.

Implementation: **NOT AUTHORIZED**.

Production deployment: **NOT AUTHORIZED**.

## Next gate

Prepare and review a Sprint 13 technical-design freeze that resolves the mandatory design questions, defines the exact evidence model and authority boundary, and locks any required migration filenames and implementation paths.

Only after that reviewed technical design is frozen may explicit Sprint 13 implementation authorization be requested.
