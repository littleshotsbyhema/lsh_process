# Sprint 13 Technical Design Freeze

## Status

FINAL FROZEN / MIGRATION FILENAME LOCK PENDING / IMPLEMENTATION HOLD

## Milestone

**Sprint 13 — Editing Pending**

Exact journey boundary:

`Stage 12 selection_pending -> Stage 13 editing_pending`

Sprint 13 must stop at exact Stage 13. Stage 13 -> Stage 14 is not authorized by this design.

## Authority

This design is subordinate to:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`
- `docs/governance/2026-09-02-sprint13-scope-freeze.md`

Canonical authority chain:

`Auth -> Org Membership -> Role -> Permission -> RLS -> Approved RPC -> Validation -> Transaction -> Audit`

Browser/UI state and external-provider state are never authoritative for journey advancement.

## Product interpretation of Stage 13

`editing_pending` means the authoritative client-selection decision is complete, the canonical selected-image set is locked, and the booking has been accepted into the editing queue.

It does **not** mean:

- editing has started;
- an editor has been assigned;
- retouching is in progress;
- QC has begun;
- a gallery has been published;
- final delivery is available.

The frozen Stage 13 functional truth is:

`Selection completed + canonical selected-image set locked + editing handoff accepted`

This preserves the exact distinction between:

- Stage 12 `selection_pending`: waiting for selection activity;
- Stage 13 `editing_pending`: selection complete and waiting to enter editing;
- Stage 14 `editing_in_progress`: editing has actually begun.

## Core design decision — canonical selection evidence

Sprint 13 introduces deterministic internal selection evidence rather than inferring completion from browser state, a gallery-provider selected count, a webhook, a gallery URL, WhatsApp confirmation, or any other external/client signal.

The canonical model consists of exactly two new relations:

### `public.booking_selection_completions`

One immutable completion record per booking.

Minimum structural fields:

- `id uuid primary key`;
- `organization_id uuid not null`;
- `booking_id uuid not null`;
- `completed_at timestamptz not null`;
- `source_type text not null`;
- `external_reference text null`;
- `recorded_by uuid not null`;
- `created_at timestamptz not null`;
- `created_by uuid not null`.

The table must enforce one canonical completion record per booking.

### `public.booking_selected_images`

Immutable manifest rows belonging to one canonical selection completion.

Minimum structural fields:

- `id uuid primary key`;
- `selection_completion_id uuid not null`;
- `booking_id uuid not null`;
- `image_key text not null`;
- `ordinal integer null`;
- `created_at timestamptz not null`.

The table must enforce uniqueness of `image_key` within one selection completion.

`image_key` is a booking-scoped opaque operational identifier only. It must not be a signed URL, gallery token, access credential, image binary, EXIF payload, or a media-custody/DAM contract.

## No draft-selection workflow

Sprint 13 does not implement partial selection persistence.

The following are explicitly outside the Sprint 13 data model:

- autosaved client favourites;
- selection-progress counts;
- draft manifests;
- gallery interaction history;
- client browsing telemetry;
- partial handoff readiness.

The Sprint 13 recording RPC accepts only a finalized selection.

## Non-empty finalized selection rule

A finalized selection must contain at least one selected image.

Zero selected images cannot satisfy the Stage 13 gate because there is no editing work to queue.

A zero-image commercial or client outcome must be governed by a separate cancellation, exception, or remediation workflow rather than weakening the meaning of `editing_pending`.

## Immutability contract

Once canonical selection completion is recorded:

- the completion header is immutable;
- the selected-image manifest is immutable;
- authenticated direct INSERT/UPDATE/DELETE is denied on both relations;
- a conflicting later selection may not overwrite or silently repair the first finalized selection.

A future correction, reopen, supersession, or dispute workflow requires separate governance.

## Permission and authority model

### Selection-confirmation authority

Sprint 13 introduces exactly one narrow permission:

`selection.confirm`

Expected grants:

- Founder
- Studio Manager
- Client Coordinator

A Photographer does not receive this permission by default.

The recording RPC must authorize by permission, not by hard-coded role names.

### Journey advancement authority

Stage 12 -> 13 advancement continues to use the existing permission:

`booking.stage.advance`

No `editing.pending`, `selection.advance`, or equivalent stage-specific journey permission is introduced.

The existing canonical journey-advancement role boundary remains authoritative and must be verified at implementation time.

### Authority separation

`selection.confirm` records deterministic finalized-selection evidence.

`booking.stage.advance` authorizes the journey transition into `editing_pending`.

Possessing one authority does not implicitly grant the other.

## Compatibility-count rule

Sprint 13 introduces one permission with exactly three expected role grants.

The canonical role-permission compatibility count is therefore expected to move from:

`233 -> 236`

If implementation produces any other count, STOP and perform governance review before continuing.

## Controlled selection-completion RPC

Create exactly one evidence-recording mutation RPC:

`public.record_booking_selection_completion(
  p_booking_id uuid,
  p_selected_image_keys text[],
  p_source_type text,
  p_external_reference text default null
)`

Return type:

`public.booking_selection_completions`

Required properties:

- PL/pgSQL;
- `SECURITY DEFINER` only because the function performs controlled writes behind RLS;
- `SET search_path = ''`;
- explicit `auth.uid()` validation;
- explicit active organization-membership validation;
- explicit `selection.confirm` permission validation;
- explicit branch-scope validation;
- exact Stage 12 / `selection_pending` requirement;
- exact canonical Stage 11 -> 12 `selection_pending` lineage requirement;
- non-empty selected-image array;
- individual keys normalized/trimmed and required non-empty;
- duplicate selected-image keys rejected;
- source type treated as structural provenance only;
- external reference optional and non-secret;
- `PUBLIC`, `anon`, and `service_role` execution denied;
- `authenticated` execution granted;
- no browser-side direct evidence-table mutation.

The function must not rely on JWT user metadata for authorization.

## Selection-completion transaction contract

The first-success transaction must use the booking as the synchronization root.

Frozen lock/validation order:

1. target `bookings` row `FOR UPDATE`;
2. exactly one `booking_journey_states` row `FOR UPDATE`;
3. validate current Stage 12 / `selection_pending`;
4. validate canonical Stage 11 -> 12 transition lineage;
5. validate absence of existing canonical selection completion;
6. validate normalized non-empty unique image-key manifest;
7. insert one selection-completion row;
8. insert the complete immutable selected-image manifest;
9. append one structural audit event;
10. return the completion row.

The exact lock sequence may not be expanded to unrelated tables without a governance amendment.

## Selection replay/idempotency contract

Selection-completion replay is strict.

If a canonical completion already exists, replay succeeds only when the normalized submitted image-key set exactly matches the stored canonical manifest and the relevant structural provenance remains compatible.

A valid exact replay:

- returns the existing completion row;
- creates no new completion row;
- creates no new selected-image rows;
- appends no additional audit event.

A conflicting manifest must reject rather than overwrite or repair history.

## Selection-completion audit contract

First successful finalization appends exactly one structural audit event:

`booking.selection_completed`

Audit entity:

`booking`

Safe metadata may include:

- booking ID;
- selection completion ID;
- selected-image count;
- completion timestamp;
- source type.

Audit metadata must not contain:

- selected image keys;
- image URLs or image content;
- gallery access credentials/tokens;
- private family notes;
- child-sensitive content;
- Safety or medical details.

Replay must not duplicate this audit event.

## Controlled Stage 12 -> 13 RPC

Create exactly one journey-advancement RPC:

`public.mark_booking_editing_pending(p_booking_id uuid)`

Return type:

`public.bookings`

Required properties:

- PL/pgSQL;
- `SECURITY DEFINER`;
- `SET search_path = ''`;
- explicit authentication validation;
- explicit active organization-membership validation;
- explicit `booking.stage.advance` permission validation;
- explicit branch-scope validation;
- explicit execute ACL;
- `PUBLIC`, `anon`, and `service_role` execution denied;
- `authenticated` execution granted;
- no browser-side direct journey mutation.

## First-execution Stage 12 -> 13 validation contract

For first advancement, `mark_booking_editing_pending(uuid)` must validate all of the following:

1. `p_booking_id` is non-null;
2. `auth.uid()` is present;
3. the target booking exists;
4. the authenticated actor maps to one active organization member for the booking organization;
5. the actor has `booking.stage.advance` for the booking branch context;
6. branch scope is satisfied where the booking is branch-scoped;
7. exactly one current `booking_journey_states` row exists;
8. current stage is exactly Stage 12 / `selection_pending`;
9. exactly one canonical Stage 11 `shoot_completed` -> Stage 12 `selection_pending` transition exists with transition key `selection_pending`;
10. exactly one canonical `booking_selection_completions` row exists;
11. at least one corresponding `booking_selected_images` row exists;
12. manifest cardinality/uniqueness remains internally valid;
13. the active canonical Stage 13 destination exists as stage order 13 / key `editing_pending`.

The operation must not create or alter client selection evidence.

## Stage-advancement locking and transaction order

Frozen order:

1. target `bookings` row `FOR UPDATE`;
2. exactly one `booking_journey_states` row `FOR UPDATE`;
3. exactly one canonical selection-completion row `FOR UPDATE`;
4. validate non-empty immutable selected-image manifest;
5. validate canonical Stage 11 -> 12 transition lineage;
6. resolve canonical Stage 13 destination;
7. insert Stage 12 -> 13 transition;
8. advance journey state with optimistic exact-state/version predicates;
9. append structural audit evidence;
10. return booking.

No Stage 14 transition or state mutation is permitted.

## Stage transition contract

First success must create exactly one `booking_stage_transitions` row with:

- source: Stage 12 / `selection_pending`;
- destination: Stage 13 / `editing_pending`;
- transition key: `editing_pending`;
- `transitioned_at`: one database-generated transaction timestamp used consistently for transition and journey-state entry time;
- `transitioned_by`: the current authorized organization member.

The matching `booking_journey_states` update must:

- move `current_stage_id` to canonical Stage 13;
- set `stage_entered_at` to the same transition timestamp;
- increment `version` by exactly one;
- set `updated_at` to the same timestamp;
- set `updated_by` to the authorized actor;
- use optimistic predicates against the previously locked current stage and version;
- require exactly one updated row.

## Stage 13 replay contract

Replay at exact Stage 13 is strict and mutation-free.

A replay succeeds only when all of the following remain true:

1. exactly one canonical selection-completion row exists;
2. the immutable selected-image manifest is non-empty and internally valid;
3. exactly one canonical Stage 11 -> 12 `selection_pending` transition exists;
4. exactly one canonical Stage 12 -> 13 `editing_pending` transition exists.

A valid replay:

- returns the booking;
- does not insert another transition;
- does not increment journey version;
- does not append another audit event.

Conflicting or incomplete lineage must reject rather than silently repair history.

## Stage-advancement audit contract

First successful advancement appends exactly one structural audit event:

`booking.editing_pending`

Audit entity:

`booking`

Safe metadata may include:

- booking ID;
- selection completion ID;
- selected-image count;
- transition key;
- prior journey version;
- resulting journey version.

Audit metadata must not contain the selected image keys themselves or any sensitive/client-private/gallery credential data.

## RLS and direct data access

Both new relations must have RLS enabled and forced.

Authenticated SELECT is allowed only through the existing booking-read authority plus organization and branch containment.

Authenticated direct INSERT/UPDATE/DELETE must be denied on both relations.

The two `SECURITY DEFINER` RPCs must independently enforce authentication, active membership, permission and branch scope because privileged execution cannot rely on RLS for authorization.

No service-role execution is granted for these application mutation RPCs.

## External-provider authority rule

Sprint 13 remains provider-neutral.

An optional `external_reference` may record where a finalized selection originated, but an external provider never becomes journey authority.

Sprint 13 does not require or authorize:

- Pixieset API integration;
- webhook ingestion;
- gallery creation/publication;
- gallery polling;
- provider credentials;
- provider-specific schema;
- image downloading;
- synchronization of later gallery changes.

If an external gallery changes after Stage 13, canonical Memory Keeper OS selection evidence is not silently rewritten. Any correction/reconciliation workflow requires separate governance.

## Read model

The Bookings workspace may read canonical selection-completion provenance and selected-image manifest/count using safe authenticated reads protected by RLS and existing booking-read authority.

No additional per-booking read RPC is authorized unless implementation proves it is technically necessary and a governance amendment explicitly approves it.

The implementation should batch selection evidence reads rather than introduce avoidable per-row N+1 queries.

## Application server boundary

Application changes are limited to existing:

`src/lib/booking.functions.ts`

Required server-layer additions:

- validator and server wrapper for `record_booking_selection_completion`;
- validator and server wrapper for `mark_booking_editing_pending`;
- no caller-supplied organization ID;
- no caller-supplied branch ID;
- no caller-supplied actor/member ID;
- no caller-supplied stage IDs;
- no caller-supplied journey version;
- no caller-supplied selected-image count;
- no caller-supplied audit payload or authorization data.

## Bookings UI boundary

Application UI changes are limited to existing:

`src/routes/_authenticated/bookings.tsx`

### Stage 12 presentation

When a booking is exactly Stage 12 / `selection_pending`, the UI may show a tightly bounded finalized-selection surface containing:

- finalized image-key input;
- optional source/provenance field;
- optional non-secret external reference;
- `Record Final Selection` action only when the actor has selection-confirmation capability;
- immutable completion provenance after recording;
- selected-image count;
- `Move to Editing Pending` only when canonical selection evidence exists and the actor has journey-advancement capability.

The UI must not represent draft selection state as canonical truth.

### Stage 13 presentation

At exact Stage 13 / `editing_pending`, Sprint 13 UI is read-only historical/status presentation.

It may show:

- selection completion provenance;
- selected-image count;
- that the booking is waiting to enter editing.

It must not show or enable:

- Stage 13 -> 14 advancement;
- Start Editing;
- editor assignment;
- editing or retouching controls;
- QC controls;
- gallery publication;
- delivery controls.

The UI is presentation only; database RPCs remain authoritative.

## Legacy-reference rule

The frozen `architecture-rebuild` branch may be used only as selective reference material.

Any historical selection, image-entitlement, pricing, editing, QC, Pixieset or media-custody implementation must not be cherry-picked or merged wholesale.

Any reused idea must be re-authored and revalidated against current canonical `main`, the frozen Sprint 13 functional scope, and current Production contracts.

## Database migration design

Exactly one new migration is expected.

Logical migration name:

`sprint13_selection_completion_stage12_13_editing_pending_foundation`

The exact timestamped filename is **not yet locked** by this document.

It must be generated from the canonical Sprint 13 implementation branch using the currently installed Supabase CLI only after this technical design is reviewed/committed and the filename-lock checkpoint is separately authorized.

Once generated, the exact timestamped filename must be recorded in a governance checkpoint before any migration SQL is written.

The migration may contain only:

- the two Sprint 13 evidence relations and constraints;
- RLS/ACL surfaces required by this design;
- `selection.confirm` and its exact role grants;
- `record_booking_selection_completion`;
- `mark_booking_editing_pending`;
- migration-time assertions needed to prove the frozen contract.

It must not introduce Stage 14 behavior, editing task models, QC models, gallery-publication models, pricing/entitlement systems, or media-custody architecture.

## Test contract

Dedicated pgTAP file:

`supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`

At minimum the suite must verify:

- both new relations exist with expected constraints;
- RLS enabled and forced;
- authenticated direct DML denied;
- `selection.confirm` exists with exactly the expected three role grants;
- compatibility count is exactly `236`;
- recording RPC exact signature/result;
- recording RPC `SECURITY DEFINER` and fixed empty `search_path`;
- PUBLIC/anon/service-role execute denied, authenticated granted;
- unauthenticated/inactive/non-member/missing-permission/wrong-branch rejection;
- exact Stage 12 requirement for selection recording;
- canonical Stage 11 -> 12 lineage requirement;
- zero-image rejection;
- empty/blank image-key rejection;
- duplicate image-key rejection;
- first selection success writes exactly one completion and exact manifest cardinality;
- selection audit created exactly once;
- exact selection replay mutation-free;
- conflicting selection replay rejected;
- journey-advancement RPC exact signature/result;
- journey RPC ACL/security/search-path contract;
- missing `booking.stage.advance` rejection;
- exact Stage 12 requirement for first advancement;
- canonical selection completion required;
- non-empty valid manifest required;
- first advancement creates exactly one Stage 12 -> 13 transition;
- transition key exactly `editing_pending`;
- journey state advances to exact Stage 13;
- journey version increments exactly once;
- transition and stage-entry timestamps match;
- actor identity fields are correct;
- `booking.editing_pending` audit created exactly once;
- valid Stage 13 replay mutation-free;
- invalid replay rejected;
- Stage 11 or earlier invocation rejects;
- Stage 14 or later invocation rejects;
- no Stage 13 -> 14 transition is created.

Full database regression, DB lint, DB advisors, generated types verification, application validation/build, and end-to-end validation remain required before implementation merge/release.

## Generated types

`src/integrations/supabase/types.ts` is in scope only for deterministic regeneration after the new database objects exist locally.

No hand-authored generated-type edits are permitted.

Generation must preserve the complete exposed schema surface and must not accidentally drop unrelated generated schemas.

## Frozen implementation boundary

After migration filename lock, the implementation boundary is exactly six paths:

1. the locked Sprint 13 migration;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint10_extended_creative_assignments_test.sql` only for the canonical role-permission compatibility-count update from `233` to `236`;
5. `src/lib/booking.functions.ts`;
6. `src/routes/_authenticated/bookings.tsx`.

Any seventh implementation path requires an explicit governance amendment before modification.

`src/routeTree.gen.ts` is not an authorized Sprint 13 implementation path.

## Explicitly out of scope

Sprint 13 does not authorize:

- Stage 13 -> Stage 14 `editing_in_progress`;
- actual editing/retouching workflow;
- editor assignment/task allocation unless separately governed;
- AI culling, AI editing or creative judgment;
- QC progression;
- gallery publication or final delivery;
- additional-image pricing or entitlement authority;
- album/frame production;
- review/follow-up automation;
- media-file custody/DAM redesign;
- broad Pixieset integration;
- unrelated Team/RBAC redesign;
- unrelated CRM, quotation, payment, package or public-website changes;
- wholesale `architecture-rebuild` migration;
- Production mutation without separate explicit release approval.

## Verification gates before implementation merge

Sprint 13 implementation cannot be considered merge-ready until all applicable gates pass:

1. filename-lock checkpoint matches the exact CLI-generated migration filename;
2. fresh local Supabase reset passes;
3. dedicated Sprint 13 pgTAP suite passes;
4. full local database regression passes;
5. `supabase db lint --local` reports no Sprint 13 schema errors;
6. `supabase db advisors --local` is reviewed and any Sprint 13 security issue is resolved or explicitly justified;
7. role-permission count is exactly `236` and grant boundary is exact;
8. RLS and direct-DML containment are verified;
9. generated types contain only expected semantic additions;
10. scoped application checks pass;
11. application Production build passes;
12. `git diff --check` passes;
13. changed-file boundary is exactly the frozen implementation paths;
14. local end-to-end finalized-selection record + exact Stage 12 -> 13 first-success and replay behavior is verified;
15. Stage 14 remains absent/unreachable from Sprint 13 UI and RPC behavior.

No destructive or synthetic client-booking tests are authorized against Production.

## Governance state after this freeze

Functional scope: **FROZEN**.

Technical design: **FINAL FROZEN**.

Migration logical name: **FROZEN**.

Exact timestamped migration filename: **PENDING FILENAME-LOCK CHECKPOINT**.

Implementation: **HOLD** pending filename lock and separate explicit implementation authorization.

Production deployment: **NOT AUTHORIZED**.

## Next gate

Commit and merge this governance-only technical-design freeze to canonical `main`.

After that merge, create the Sprint 13 implementation branch from the exact resulting `main` SHA, generate the migration using the installed Supabase CLI, record the exact filename in a filename-lock checkpoint, and request separate implementation authorization.
