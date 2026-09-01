# Sprint 12 Technical Design Freeze

## Status

FINAL FROZEN / MIGRATION FILENAME LOCK PENDING / IMPLEMENTATION HOLD

## Milestone

**Sprint 12 — Selection Pending**

Exact journey boundary:

`Stage 11 shoot_completed -> Stage 12 selection_pending`

Sprint 12 must stop at exact Stage 12. Stage 12 -> Stage 13 is not authorized by this design.

## Authority

This design is subordinate to:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`
- `docs/governance/2026-09-01-sprint12-scope-freeze.md`

Canonical authority chain:

`Auth -> Org Membership -> Role -> Permission -> RLS -> Approved RPC -> Validation -> Transaction -> Audit`

Browser/UI state is never authoritative for journey advancement.

## Product interpretation of Stage 12

`selection_pending` means the completed photography session has been formally handed into the client-selection phase and is now waiting for selection activity.

It does **not** mean:

- client selections have been made;
- selected image identifiers exist;
- proofs have been published;
- a Pixieset or other gallery is ready;
- culling or editing is complete;
- editing may begin;
- final delivery is available.

Sprint 12 therefore models the operational handoff into selection, not the selection decision itself.

## Core design decision — no new readiness evidence table

Sprint 12 introduces **no new selection-readiness evidence table**.

The minimum authoritative evidence required to enter Stage 12 is the already-released Sprint 11 lineage:

1. exactly one immutable `booking_shoot_completions` row for the booking; and
2. exactly one canonical Stage 10 -> Stage 11 `shoot_completed` transition for that booking.

This is sufficient because Stage 12 represents a journey handoff/waiting state, not a client decision, gallery-publication state, editing state, or asset-custody state.

The Stage 11 -> 12 operation consumes this established evidence without rewriting it.

## Explicit non-requirements at Stage 12 entry

The following must **not** be required to enter `selection_pending`:

- gallery URL;
- provider identifier;
- Pixieset collection identifier;
- proof count;
- image count;
- selected-image IDs;
- selected-image count;
- culling result;
- editing assignment;
- editing readiness;
- editing start evidence;
- QC evidence;
- delivery evidence;
- media-card or DAM custody evidence;
- free-text selection notes.

These belong to later milestones or separately governed domains.

## Permission and authority model

### Journey advancement authority

Sprint 12 reuses the existing permission:

`booking.stage.advance`

No new `selection.*`, `selection.pending`, `booking.selection.pending`, or equivalent stage-specific permission is introduced.

The existing canonical role boundary remains authoritative. The Stage 11 -> 12 RPC must authorize by permission, not by hard-coded role names.

Current expected grant boundary remains:

- Founder
- Studio Manager
- Client Coordinator

Any future RBAC change must occur through separate governance and must not be embedded in this Sprint 12 gate.

### Separation from shoot-completion authority

`shoot.complete` does not authorize Stage 11 -> 12 advancement.

A Photographer may have authority to record canonical shoot completion without having authority to advance the booking into Selection Pending.

Sprint 12 preserves the separation between evidence-recording authority and journey-advancement authority.

## Controlled RPC

Create exactly one new application mutation RPC:

`public.mark_booking_selection_pending(p_booking_id uuid)`

Return type:

`public.bookings`

Required properties:

- PL/pgSQL;
- `SECURITY DEFINER` only because the function performs controlled server-side journey mutation;
- `SET search_path = ''`;
- explicit authentication validation inside the function;
- explicit active organization-membership validation;
- explicit `booking.stage.advance` permission validation;
- explicit branch-scope validation;
- explicit execute ACL;
- `PUBLIC`, `anon`, and `service_role` execution denied;
- `authenticated` execution granted;
- no browser-side direct journey mutation.

The function must not rely on JWT user metadata for authorization.

## First-execution validation contract

For first advancement, `mark_booking_selection_pending(uuid)` must validate all of the following:

1. `p_booking_id` is non-null;
2. `auth.uid()` is present;
3. the target booking exists;
4. the authenticated actor maps to one active organization member for the booking organization;
5. the actor has `booking.stage.advance` for the booking branch context;
6. the actor satisfies branch scope where the booking is branch-scoped;
7. exactly one current `booking_journey_states` row exists for the booking;
8. the current stage is exactly Stage 11 / `shoot_completed`;
9. exactly one `booking_shoot_completions` row exists for the booking;
10. exactly one canonical Stage 10 `shoot_scheduled` -> Stage 11 `shoot_completed` transition exists with transition key `shoot_completed`;
11. the active canonical Stage 12 destination exists as stage order 12 / key `selection_pending`.

The operation must not re-run Sprint 10 preparation, staffing, Safety, scheduling, or Sprint 11 shoot-completion recording gates.

## Locking and transaction order

The first-success transaction must use the booking as the synchronization root.

Frozen lock/validation order:

1. target `bookings` row `FOR UPDATE`;
2. exactly one `booking_journey_states` row `FOR UPDATE`;
3. exactly one `booking_shoot_completions` row `FOR UPDATE`;
4. validate canonical Stage 10 -> 11 transition lineage;
5. resolve canonical Stage 12 destination;
6. insert Stage 11 -> 12 transition;
7. advance journey state with optimistic exact-state/version predicates;
8. append audit evidence;
9. return booking.

The exact lock sequence may not be expanded to unrelated tables without a governance amendment.

## Stage transition contract

First success must create exactly one `booking_stage_transitions` row with:

- source: Stage 11 / `shoot_completed`;
- destination: Stage 12 / `selection_pending`;
- transition key: `selection_pending`;
- `transitioned_at`: one database-generated transaction timestamp used consistently for the transition and journey-state entry time;
- `transitioned_by`: the current authorized organization member.

The matching `booking_journey_states` update must:

- move `current_stage_id` to canonical Stage 12;
- set `stage_entered_at` to the same transition timestamp;
- increment `version` by exactly one;
- set `updated_at` to the same transition timestamp;
- set `updated_by` to the authorized actor;
- use optimistic predicates against the previously locked `current_stage_id` and `version`;
- require exactly one updated row.

No Stage 13 transition or state mutation is permitted.

## Replay and idempotency contract

Stage 12 replay is strict and mutation-free.

If the booking is already exactly Stage 12 / `selection_pending`, replay succeeds only when all of the following remain true:

1. exactly one canonical shoot-completion row exists;
2. exactly one canonical Stage 10 -> 11 `shoot_completed` transition exists;
3. exactly one canonical Stage 11 -> 12 `selection_pending` transition exists.

A valid replay:

- returns the booking;
- does not insert another transition;
- does not increment journey version;
- does not append another audit event.

Any conflicting or incomplete replay lineage must reject rather than silently repair history.

## Audit contract

First successful advancement appends exactly one structural audit event:

`booking.selection_pending`

Audit entity:

`booking`

Audit metadata may include structural identifiers/timestamps required to prove the transition, including:

- booking ID;
- completion evidence ID;
- completion timestamp;
- transition key;
- prior journey version;
- resulting journey version.

Audit payload must not contain:

- selected image identifiers;
- image content;
- proofing content;
- gallery credentials/tokens;
- private family notes;
- child-sensitive content;
- Safety or medical details.

Replay must not duplicate this audit event.

## RLS and data-access model

Sprint 12 creates no new table and therefore no new RLS policy surface.

Existing RLS/ACL protection for:

- `bookings`;
- `booking_journey_states`;
- `booking_stage_transitions`;
- `booking_shoot_completions`;

remains authoritative.

The RPC must independently enforce active membership, permission, and branch scope because `SECURITY DEFINER` bypasses RLS.

No direct authenticated table mutation is added by Sprint 12.

## Read model

No new per-booking read RPC is authorized.

The Bookings workspace should reuse its existing workspace data, including Sprint 11 shoot-completion evidence and journey state, to derive the Stage 11 handoff presentation.

If implementation proves an additional read is technically necessary, that is a governance change and must be approved before adding another path or RPC.

## Application server boundary

Application changes are limited to existing:

`src/lib/booking.functions.ts`

Required server-layer additions:

- controlled server function wrapper for `mark_booking_selection_pending`;
- validation schema containing only the booking identifier required by the RPC;
- no caller-supplied organization ID;
- no caller-supplied branch ID;
- no caller-supplied actor/member ID;
- no caller-supplied source/destination stage;
- no caller-supplied journey version;
- no gallery/provider/selection payload.

Capabilities continue to derive journey advancement from the existing `booking.stage.advance` permission. No new Sprint 12 capability backed by a new database permission is required.

## Bookings UI boundary

Application UI changes are limited to existing:

`src/routes/_authenticated/bookings.tsx`

### Stage 11 presentation

When a booking is exactly Stage 11 / `shoot_completed`, the UI may show:

- immutable shoot-completion provenance already available from Sprint 11;
- clear explanation that the next operational state is Selection Pending;
- a distinct `Move to Selection Pending` action only when the current actor has journey-advancement capability.

### Stage 12 presentation

When a booking is exactly Stage 12 / `selection_pending`, Sprint 12 UI is read-only historical/status presentation.

It may show that the booking is waiting for the selection phase.

It must not show or enable:

- Stage 12 -> 13 advancement;
- image selection controls;
- editing controls;
- Pixieset publication controls;
- delivery controls.

The UI is presentation only; the RPC remains authoritative.

## Gallery/provider decision

No gallery/provider reference is part of Stage 12 entry.

Pixieset or another gallery provider becomes relevant only when a later milestone explicitly governs proof/gallery readiness or publication.

Sprint 12 must not create coupling between journey Stage 12 and an external gallery provider.

## Legacy-reference rule

The frozen `architecture-rebuild` branch may be used only as selective reference material.

The historical Stage 11 -> 12 gate provides useful reference semantics for:

- exact Stage 11 -> 12 containment;
- reuse of `booking.stage.advance`;
- completion-lineage validation;
- strict Stage 12 replay;
- audit shape;
- denial of new selection-specific permissions.

It must not be cherry-picked wholesale or merged into `main`.

Later legacy selection confirmation, image entitlement, pricing, editing, QC, Pixieset, and media-custody migrations are outside Sprint 12.

Any reused logic must be re-authored/revalidated against current canonical `main` and current Production contracts.

## Database migration design

Exactly one new migration is expected.

Logical migration name:

`sprint12_stage11_12_selection_pending_gate_foundation`

The exact timestamped filename is **not yet locked** by this document.

It must be generated from the canonical Sprint 12 implementation branch using the currently installed Supabase CLI only after this technical design is reviewed/committed and the filename-lock checkpoint is authorized.

Once generated, the exact timestamped filename must be recorded in a governance amendment/checkpoint before any migration SQL is written.

The migration must contain only the Stage 11 -> 12 controlled gate and supporting migration-time assertions required by this design.

It must not introduce later-stage tables, permissions, selected-image models, gallery models, editing models, or media-custody models.

## Test contract

Dedicated pgTAP file:

`supabase/tests/sprint12_stage11_12_gate_test.sql`

At minimum the suite must verify:

- RPC exists with exact signature/result;
- `SECURITY DEFINER` and fixed empty `search_path`;
- PUBLIC/anon/service-role execute denied;
- authenticated execute granted;
- unauthenticated rejection;
- inactive/non-member rejection;
- missing `booking.stage.advance` rejection;
- wrong-branch rejection;
- exact Stage 11 requirement;
- exactly one completion evidence row required;
- exact canonical Stage 10 -> 11 lineage required;
- first success creates exactly one Stage 11 -> 12 transition;
- transition key is exactly `selection_pending`;
- journey state advances to exact Stage 12;
- journey version increments exactly once;
- transition and `stage_entered_at` timestamps match;
- `updated_by` / `transitioned_by` actor correctness;
- first success creates exactly one `booking.selection_pending` audit event;
- valid Stage 12 replay is mutation-free;
- invalid Stage 12 replay is rejected;
- Stage 10 or earlier invocation rejects;
- Stage 13 or later invocation rejects;
- no Stage 12 -> 13 transition is created;
- no new selection-specific permission is introduced;
- canonical `booking.stage.advance` role boundary is unchanged.

Full database regression, DB lint, DB advisors, generated types verification, application build, scoped application checks, and end-to-end validation remain required before merge/release.

## Generated types

`src/integrations/supabase/types.ts` is in scope only for deterministic regeneration after the new RPC exists locally.

No hand-authored generated-type edits are permitted.

Generation must preserve the repository's complete exposed schema surface and must not accidentally drop unrelated generated schemas.

## Frozen implementation boundary

After filename lock, the implementation boundary is exactly five paths:

1. the locked Sprint 12 Stage 11 -> 12 migration;
2. `supabase/tests/sprint12_stage11_12_gate_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `src/lib/booking.functions.ts`;
5. `src/routes/_authenticated/bookings.tsx`.

Any sixth implementation path requires an explicit governance amendment before modification.

`src/routeTree.gen.ts` is not an authorized Sprint 12 implementation path unless a separately approved routing change becomes genuinely necessary.

## Compatibility-count rule

Sprint 12 introduces no permission or role grant.

Therefore no repository-wide role-permission compatibility-count update is expected.

If implementation changes the canonical role-permission count, STOP: that indicates design drift and requires governance review.

## Explicitly out of scope

Sprint 12 does not authorize:

- Stage 12 -> Stage 13 advancement;
- selection-confirmation evidence;
- selected-image persistence;
- image entitlement authority;
- additional-image pricing;
- adjusted financial obligations;
- editing start/completion;
- QC progression;
- Pixieset/gallery publication;
- final delivery;
- album/frame production;
- review/follow-up automation;
- AI culling/editing or creative judgment;
- DAM/media-card/capture-device custody architecture;
- new Team/RBAC redesign;
- CRM, quotation, payment, package, or public-website changes;
- wholesale `architecture-rebuild` migration;
- Production mutation without separate explicit release approval.

## Verification gates before implementation merge

Sprint 12 implementation cannot be considered merge-ready until all applicable gates pass:

1. filename-lock checkpoint matches the exact CLI-generated migration filename;
2. fresh local Supabase reset passes;
3. dedicated Sprint 12 pgTAP suite passes;
4. full local database regression passes;
5. `supabase db lint --local` reports no schema errors attributable to Sprint 12;
6. `supabase db advisors --local` is reviewed and any Sprint 12 security issue is resolved;
7. generated types contain only expected semantic additions;
8. scoped application checks pass;
9. application production build passes;
10. `git diff --check` passes;
11. changed-file boundary is exactly the frozen implementation paths;
12. end-to-end Stage 11 -> 12 first-success and replay behavior is verified;
13. Stage 13 remains absent/unreachable from Sprint 12 UI and RPC behavior.

## Governance state after this freeze

Functional scope: **FROZEN**.

Technical design: **FINAL FROZEN**.

Migration logical name: **FROZEN**.

Exact timestamped migration filename: **PENDING FILENAME-LOCK CHECKPOINT**.

Implementation: **HOLD** pending filename lock and separate explicit implementation authorization.

Production deployment: **NOT AUTHORIZED**.

## Next gate

1. review this governance-only technical-design commit;
2. create the Sprint 12 implementation branch from the exact approved canonical `main` head;
3. generate the single migration filename using the current Supabase CLI;
4. record and commit that exact filename as the Sprint 12 filename-lock checkpoint;
5. obtain explicit `APPROVE SPRINT 12 IMPLEMENTATION` authorization;
6. only then write migration SQL or application implementation.
