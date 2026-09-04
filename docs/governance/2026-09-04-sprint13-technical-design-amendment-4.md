# Sprint 13 Technical Design Amendment 4

## Status

APPROVED / ACTIVE

## Milestone

Sprint 13 — Editing Pending

## Approval

Explicit governance approval received on 2026-09-04:

`APPROVE SPRINT 13 TECHNICAL DESIGN AMENDMENT 4`

## Reason

A fresh Codex review on corrective head
`239648744f06ea2f076b06a22b3b9c0c3cf86638` identified one remaining P2:
`external_reference` was trimmed but not constrained strongly enough to prevent
signed URLs, tokens, credentials, or other secret-shaped values from entering
immutable selection-completion evidence.

## Authorized external-reference contract

`external_reference` remains optional, provider-neutral, and non-secret
operational evidence only.

Amendment 4 authorizes:

- trim before validation;
- empty input normalizes to NULL;
- maximum normalized length: 255 characters;
- reject control-character payloads;
- reject URL/URI-shaped values including `http:`, `https:`, `www.`, and `://`;
- reject query/fragment-shaped values containing `?` or `#`;
- reject obvious bearer/basic, token, secret, password, API-key,
  access-token, signature, access-key, JWT, and known credential-prefix forms;
- enforce the contract in both the authoritative recording RPC and immutable
  evidence-table constraint;
- preserve valid provider-neutral opaque references such as `EXT-REF-123`.

## Preserved semantics

This amendment does not change:

- the RPC signature;
- immutable evidence semantics;
- finalized-selection replay/idempotency;
- selected-image manifest semantics;
- the exact Stage 12 `selection_pending` -> Stage 13 `editing_pending` boundary;
- permissions or role grants;
- canonical role-permission count 260 with Migration A present.

## Authorized implementation paths

Implementation is limited to:

1. `supabase/migrations/20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`;
3. this Amendment 4 governance evidence document.

## Explicit non-authorization

Amendment 4 does not authorize:

- Stage 14;
- editing execution;
- provider/Pixieset integration;
- new database tables or columns;
- RPC signature changes;
- new permissions or role grants;
- Production or linked Supabase mutation;
- mutation of `main`;
- force push or history rewriting;
- commit, push, or merge without a separate explicit authorization.
