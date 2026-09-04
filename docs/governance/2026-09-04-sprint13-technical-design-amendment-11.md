# Sprint 13 Technical Design Amendment 11

Date: 2026-09-04

Status: APPROVED

Approved human gate:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 11`

## Reason

Fresh Codex review of Sprint 13 head
`9ed442b327a349a23fa8ed1e7fe4b6c29f45f425` identified two P2
selected-image evidence validation gaps.

First, a `data:` URI such as
`data:image/png;base64,iVBORw0KGgo` does not contain `://` and can avoid
the existing query/credential rejection predicates. It can therefore enter
immutable selected-image evidence despite the frozen opaque operational
identifier contract.

Second, PostgreSQL's ordinary `btrim(text)` trims ordinary space by default
but does not remove all Unicode White_Space characters. A selected-image key
consisting only of characters such as NO-BREAK SPACE (`U+00A0`) can therefore
pass the existing non-empty validation.

## Authorized correction

Amendment 11 changes only selected-image evidence validation.

The following selected-image boundaries are authoritative:

1. `booking_selected_images_image_key_chk`;
2. selected-image validation inside
   `record_booking_selection_completion(uuid,text[],text,text)`.

Both boundaries must reject:

- `data:` URI schemes case-insensitively;
- values consisting entirely of Unicode White_Space characters.

## Data URI contract

Selected-image evidence must reject values beginning case-insensitively with:

`data:`

The existing provider-neutral opaque identifier model remains unchanged.

No provider-specific interpretation is introduced.

## Unicode White_Space contract

Ordinary `btrim(...)` remains the canonical normalization behavior for valid
selected-image identifiers.

Amendment 11 does not silently change canonical storage by Unicode-trimming
otherwise-valid identifiers.

A separate defensive emptiness guard must reject a value when it consists
entirely of characters from the Unicode White_Space set:

- `U+0009` through `U+000D`
- `U+0020`
- `U+0085`
- `U+00A0`
- `U+1680`
- `U+2000` through `U+200A`
- `U+2028`
- `U+2029`
- `U+202F`
- `U+205F`
- `U+3000`

The implementation uses an explicit PostgreSQL Unicode character set rather
than depending on locale-sensitive or incomplete default whitespace behavior.

## External-reference invariant

Amendment 11 does not modify `external_reference` validation.

All existing external-reference bounds and credential protections remain
unchanged.

## Regression requirements

The focused Sprint 13 pgTAP plan increases from 75 to 82 assertions.

The additional assertions must prove:

- lowercase `data:` URI selected-image evidence is rejected;
- mixed/uppercase `DATA:` URI selected-image evidence is rejected;
- an NBSP-only selected-image key is rejected;
- a mixed Unicode-White_Space-only selected-image key is rejected;
- the selected-image table constraint and authoritative RPC both carry
  `data:` protection;
- the selected-image table constraint and authoritative RPC both carry the
  explicit Unicode-whitespace-only protection;
- all Amendment 11 rejected attempts remain mutation-free:
  - no new selection completion;
  - no new selected image;
  - no new `booking.selection_completed` audit event;
  - journey remains Stage 12 `selection_pending`;
  - no `editing_pending` transition is created.

## Authorized paths

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`
3. `docs/governance/2026-09-04-sprint13-technical-design-amendment-11.md`

## Required validation

- pristine local Supabase reset / migration replay
- Sprint 13 dedicated pgTAP: 82 / 82
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
- exact three-path Amendment 11 boundary
- selected-image `data:` protection mirrored between RPC and table constraint
- selected-image Unicode-whitespace-only protection mirrored between RPC and
  table constraint
- external-reference validation remains unchanged
- Sprint 13 introduces no new Stage 14 implementation or Stage 13 -> 14
  transition

## Preserved Sprint 13 contracts

Amendment 11 does not change:

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
- provider-neutral architecture;
- canonical ordinary-`btrim` storage behavior for valid image keys.

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
- staging
- commit
- push
- merge
- force push
- history rewrite
- unrelated refactoring
