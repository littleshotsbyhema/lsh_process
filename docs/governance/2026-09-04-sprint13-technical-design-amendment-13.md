# Sprint 13 Technical Design Amendment 13

**Status:** APPROVED
**Purpose:** Final Unicode edge-whitespace closure for immutable selection evidence

## Authority

Human authorization:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 13`

This amendment is approved for design and local implementation only.

It does not authorize staging, commit, push, merge, `main` mutation,
linked/Production Supabase mutation, force push, or history rewrite.

## Reason

The final exact-head Codex review of
`cfec04b31c66d54f04fce6a1886d659a5f4a0d4f`
identified a P2 boundary gap.

Amendment 12 rejects values consisting entirely of the explicit Unicode
White_Space set, but ordinary PostgreSQL `btrim(...)` does not remove all
Unicode White_Space characters.

A value such as an NBSP-prefixed credential can therefore remain non-empty
while hiding an otherwise anchored secret or credential prefix.

The same residual Unicode-edge condition is homologous across the immutable
`image_key`, `source_type`, and `external_reference` textual evidence
boundaries.

## Frozen implementation scope

Only these paths may change:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`
3. `docs/governance/2026-09-04-sprint13-technical-design-amendment-13.md`

No application path is authorized.

## Explicit Unicode White_Space set

The explicit set remains exactly:

- U+0009 through U+000D
- U+0020
- U+0085
- U+00A0
- U+1680
- U+2000 through U+200A
- U+2028
- U+2029
- U+202F
- U+205F
- U+3000

No global Unicode normalization is introduced.

## Canonicalization rule

Existing ordinary `btrim(...)` normalization remains authoritative.

After ordinary normalization, any residual leading or trailing character from
the explicit Unicode White_Space set must be rejected.

The RPC must not silently Unicode-trim otherwise-valid identifiers into a new
canonical value.

This preserves existing ASCII-edge trimming behavior and exact replay
semantics while preventing invisible Unicode-edge ambiguity.

## Selected-image contract

`image_key` keeps all existing constraints:

- required
- non-empty
- explicit Unicode-whitespace-only rejection
- maximum 255 characters
- control-character rejection
- URI/URL rejection
- `data:` rejection
- query/credential-delimiter rejection
- Bearer/Basic and known secret-prefix rejection
- provider-neutral opaque identifier semantics

Amendment 13 additionally requires both the authoritative RPC and immutable
table constraint to reject residual Unicode edge whitespace after ordinary
normalization.

## Source-type contract

`source_type` keeps:

- ordinary `btrim(...)` canonical normalization
- required/non-empty semantics
- explicit Unicode-whitespace-only rejection
- maximum 64 characters
- control-character rejection

Amendment 13 additionally rejects residual Unicode edge whitespace at both the
RPC and table boundaries.

## External-reference contract

`external_reference` remains:

- optional
- provider-neutral
- non-secret
- maximum 255 characters
- protected against URI/query/credential shapes
- ordinary empty input normalizes to NULL
- all-Unicode-White-Space-only input normalizes to NULL

Amendment 13 additionally rejects residual Unicode edge whitespace for non-null
values at both the RPC and table boundaries.

This ensures Unicode edge whitespace cannot hide anchored credential or secret
prefixes.

## Regression contract

Sprint 13 pgTAP plan changes from 88 to 98.

Tests 89 through 98 must prove:

- NBSP-prefixed credential-shaped image key rejection
- Unicode-trailing image-key rejection
- NBSP-prefixed credential-shaped external-reference rejection
- Unicode-trailing external-reference rejection
- leading Unicode-edge source-type rejection
- trailing Unicode-edge source-type rejection
- ordinary ASCII edge trimming remains valid
- canonical exact replay remains valid
- table/RPC edge protections are structurally mirrored
- invalid attempts remain mutation-free
- no Stage 13 to Stage 14 transition is introduced

Expected full database suite after the ten new assertions:

`23 files / 1487 tests`

## Preserved Sprint 13 boundaries

This amendment does not change:

- `selection.confirm`
- role grants
- role-permission count 260
- RPC signatures
- evidence-table ownership model
- RLS model
- Stage 12 `selection_pending` to Stage 13 `editing_pending`
- immutable replay semantics
- app pagination architecture
- provider neutrality
- the locked Sprint 13 migration filename

Sprint 13 introduces no new Stage 14 implementation and no Stage 13 to Stage
14 transition.

## Explicit non-authorization

Amendment 13 does not authorize:

- application changes
- new schema objects
- new RPCs
- new roles or permissions
- provider integration
- editing execution
- Stage 14 implementation
- staging
- commit
- push
- merge
- `main` mutation
- linked or Production Supabase mutation
- force push
- history rewrite
