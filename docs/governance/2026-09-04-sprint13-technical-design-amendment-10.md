# Sprint 13 Technical Design Amendment 10

Date: 2026-09-04

Status: APPROVED

Approved human gate:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 10`

## Reason

Fresh Codex review of Sprint 13 head
`8843f804a68cf1ac96548e2a87ded2d50dd70942` identified one P2
credential-validation gap in selected-image immutable evidence.

The selected-image credential predicates reject the `Bearer` authentication
scheme but do not reject the `Basic` authentication scheme.

A Basic authentication value can therefore pass the selected-image evidence
validation when no other existing rejection rule matches it.

The external-reference path already rejects both `Bearer` and `Basic`
authentication schemes and requires no Amendment 10 correction.

## Authorized correction

Amendment 10 extends only the selected-image authentication-scheme protection.

The following two selected-image boundaries must reject both `Bearer` and
`Basic` authentication schemes case-insensitively:

1. `booking_selected_images_image_key_chk`;
2. selected-image-key validation inside
   `record_booking_selection_completion(uuid,text[],text,text)`.

The structural protection is:

`(bearer|basic)[[:space:]]+`

The existing case-insensitive PostgreSQL regex operators remain authoritative.

## External-reference invariant

Amendment 10 does not modify external-reference validation.

The existing external-reference table constraint and authoritative RPC already
reject both authentication schemes using the same structural form.

Those existing guards must remain unchanged.

## Regression requirements

The Sprint 13 dedicated pgTAP suite must prove:

- a `Basic ...` selected-image key is rejected;
- Basic authentication rejection is case-insensitive;
- `booking_selected_images_image_key_chk` contains the protection;
- `record_booking_selection_completion(...)` contains the corresponding
  selected-image protection;
- invalid Basic credential attempts create no new selection completion
  evidence;
- invalid Basic credential attempts create no new selected-image evidence;
- invalid Basic credential attempts create no new
  `booking.selection_completed` audit event;
- invalid Basic credential attempts do not mutate journey state;
- invalid Basic credential attempts do not create an `editing_pending`
  transition.

The focused Sprint 13 test plan increases from 71 to 75 assertions.

## Authorized paths

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`
3. `docs/governance/2026-09-04-sprint13-technical-design-amendment-10.md`

## Required validation

- pristine local Supabase reset / migration replay
- Sprint 13 dedicated pgTAP: 75 / 75
- targeted affected database regression
- full database pgTAP regression suite
- `supabase db lint --local`
- `supabase db advisors --local`
- generated Supabase type byte-equivalence
- canonical role-permission count remains 260
- governance Prettier
- TypeScript validation
- production build
- `git diff --check`
- exact three-path Amendment 10 boundary
- selected-image `Bearer` and `Basic` protection mirrored between RPC and table
  constraint
- existing external-reference Basic protection remains unchanged
- Sprint 13 introduces no new Stage 14 implementation or Stage 13 -> 14
  transition

## Preserved Sprint 13 contracts

Amendment 10 does not change:

- Stage 12 `selection_pending` -> Stage 13 `editing_pending`;
- evidence-table immutability;
- RPC signatures;
- replay and idempotency semantics;
- RLS;
- booking branch-scope enforcement;
- role grants;
- permission mappings;
- canonical role-permission count 260;
- source-type bounds;
- manifest bounds;
- selected-image pagination behavior;
- external-reference validation;
- provider-neutral architecture.

## Explicit non-authorization

This amendment does not authorize:

- application-layer changes
- external-reference changes
- new schema objects
- new RPCs
- new read models
- role changes
- permission changes
- Stage 14
- Stage 13 -> 14 transitions
- editing execution
- provider integration
- provider coupling
- migration rename
- Production or linked Supabase mutation
- `main` mutation
- commit
- push
- merge
- force push
- history rewrite
- unrelated refactoring
