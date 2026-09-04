# Sprint 13 Technical Design Amendment 12

**Status:** APPROVED
**Purpose:** Sprint 13 closure hardening
**Authority:** Human approval — `APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 12`

## Reason

Fresh Codex review on exact Sprint 13 head
`191f514955fc95c15372e18ad4343dab31fd3b6a`
identified a P2 boundary gap: `source_type` values consisting entirely of
Unicode White_Space can bypass ordinary PostgreSQL `btrim(...)` emptiness
checks.

The Sprint 13 closure audit identified the homologous remaining gap in
`external_reference`: Unicode-White-Space-only input can remain non-empty
under ordinary `btrim(...)`.

Amendment 12 closes both equivalent provenance boundaries in one final
Sprint 13 closure pass rather than continuing serial field-by-field
remediation.

## Authorized scope

Only these repository paths may change:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`
3. `docs/governance/2026-09-04-sprint13-technical-design-amendment-12.md`

## Unicode White_Space contract

The explicit all-whitespace detection set is:

- U+0009–U+000D
- U+0020
- U+0085
- U+00A0
- U+1680
- U+2000–U+200A
- U+2028
- U+2029
- U+202F
- U+205F
- U+3000

This amendment does not introduce general Unicode normalization.

Ordinary PostgreSQL `btrim(...)` remains the canonical normalization behavior
for otherwise-valid persisted provenance values.

## Authorized correction A — source_type

`source_type` must continue to:

- normalize using ordinary `btrim(...)`;
- be required;
- remain bounded to 64 characters;
- reject control characters.

Additionally, the authoritative recording RPC and
`booking_selection_completions_source_type_chk` must reject a value that,
after testing against the explicit Unicode White_Space set, contains no
non-whitespace character.

## Authorized correction B — external_reference

`external_reference` remains:

- optional;
- provider-neutral;
- non-secret;
- bounded to 255 characters;
- protected by the existing URI/query/credential rejection contract.

Ordinary `btrim(...)` remains its canonical normalization.

If a non-null input consists entirely of the explicit Unicode White_Space
set, the authoritative RPC must normalize it to `NULL`.

The immutable table constraint must independently reject a non-null
`external_reference` consisting entirely of that Unicode White_Space set.

No other external-reference semantics are changed.

## Required regressions

Sprint 13 pgTAP expands from 82 to 88 assertions.

The new assertions must prove:

- NBSP-only `source_type` rejection;
- mixed Unicode-White-Space-only `source_type` rejection;
- NBSP-only `external_reference` normalization to NULL;
- mixed Unicode-White-Space-only external-reference exact replay;
- mirrored RPC/table structural enforcement for both provenance fields;
- invalid source-type attempts remain mutation-free;
- external-reference NULL normalization remains replay-safe;
- Stage 12 remains `selection_pending`;
- no Stage 13 -> 14 transition is introduced.

## Preserved contracts

Amendment 12 does not alter:

- Sprint 13 RPC signatures;
- selection-completion evidence schema;
- selected-image hardening from Amendments 3–11;
- 500-image manifest ceiling;
- selected-image 255-character bound;
- `source_type` 64-character bound;
- `external_reference` 255-character bound;
- immutable evidence behavior;
- exact replay/conflicting replay semantics;
- audit privacy contract;
- `selection.confirm` role grants;
- canonical role-permission count 260;
- branch-scope enforcement;
- Stage 12 `selection_pending` -> Stage 13 `editing_pending`;
- provider neutrality.

Sprint 13 introduces no new Stage 14 implementation and no Stage 13 -> 14
transition.

## Explicit non-authorization

This approval does **not** authorize:

- application changes;
- additional schema objects;
- new RPCs;
- new permissions or role grants;
- provider integration;
- Stage 14 implementation;
- editing execution;
- staging;
- commit;
- push;
- merge;
- `main` mutation;
- linked/Production Supabase mutation;
- force push;
- history rewrite.

All repository and Production mutations remain separately gated.
