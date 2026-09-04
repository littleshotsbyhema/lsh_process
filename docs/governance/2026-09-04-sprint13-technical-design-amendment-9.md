# Sprint 13 Technical Design Amendment 9

Date: 2026-09-04

Status: APPROVED

Approved human gate:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 9`

## Reason

Fresh Codex review of Sprint 13 head
`78f5a387950537dcf7fed22fde21742c86c44338` identified one P2
credential-validation gap in immutable selection evidence.

The existing Sprint 13 credential predicates reject `sk-...` secret-shaped
values but do not reject underscore-form secret prefixes such as:

- `sk_live_...`
- `sk_test_...`

Those values could otherwise enter immutable selection evidence and become
readable through the existing `booking.read` evidence policies.

## Authorized correction

Amendment 9 adds provider-neutral structural rejection for secret-shaped
values beginning with:

- `sk_live_`
- `sk_test_`

The rejection must be case-insensitive.

The same protection must exist at all four authoritative evidence boundaries:

1. `booking_selected_images_image_key_chk`;
2. selected-image-key validation inside
   `record_booking_selection_completion(uuid,text[],text,text)`;
3. `booking_selection_completions_external_reference_chk`;
4. external-reference validation inside
   `record_booking_selection_completion(uuid,text[],text,text)`.

This amendment extends the existing structural credential protections only.
It does not change valid opaque operational identifier semantics.

## Regression requirements

The Sprint 13 dedicated pgTAP suite must prove:

- lowercase `sk_live_...` image keys are rejected;
- case-variant `sk_test_...` image keys are rejected;
- case-variant `sk_live_...` external references are rejected;
- lowercase `sk_test_...` external references are rejected;
- both immutable evidence constraints contain the Amendment 9 protection;
- the authoritative RPC contains the same protection;
- invalid Amendment 9 attempts create no new selection completion evidence;
- invalid Amendment 9 attempts create no new selected-image evidence;
- invalid Amendment 9 attempts create no new selection-completed audit event;
- invalid Amendment 9 attempts do not mutate journey state;
- invalid Amendment 9 attempts do not create an editing-pending transition.

The focused Sprint 13 test plan increases from 65 to 71 assertions.

## Authorized paths

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`
3. `docs/governance/2026-09-04-sprint13-technical-design-amendment-9.md`

## Required validation

- pristine local Supabase reset / migration replay
- Sprint 13 dedicated pgTAP: 71 / 71
- targeted affected database regression
- full database pgTAP regression suite
- `supabase db lint --local`
- `supabase db advisors --local`
- generated Supabase type byte-equivalence
- canonical role-permission count remains 260
- targeted Prettier where applicable
- TypeScript validation
- production build
- `git diff --check`
- exact three-path Amendment 9 boundary
- Sprint 13 introduces no new Stage 14 implementation or Stage 13 -> 14
  transition

## Preserved Sprint 13 contracts

Amendment 9 does not change:

- the Stage 12 `selection_pending` -> Stage 13 `editing_pending` boundary;
- evidence-table immutability;
- RPC signatures;
- replay / idempotency semantics;
- existing RLS or permission enforcement;
- `selection.confirm` role grants;
- canonical role-permission count 260 with Migration A present;
- source-type Amendment 7 bounds;
- selected-image pagination Amendments 7 and 8;
- provider-neutral architecture.

## Explicit non-authorization

This amendment does not authorize:

- application-layer changes
- new schema objects
- new RPCs
- role or permission changes
- Stage 14
- Stage 13 -> 14 transitions
- editing execution
- provider integration or provider coupling
- migration rename or regeneration
- Production or linked Supabase mutation
- `main` mutation
- commit
- push
- merge
- force push
- history rewrite
- unrelated refactoring
