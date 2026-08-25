# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slices 1 through 4 are implemented, validated, pushed to `origin/architecture-rebuild`, and governance closed. Slice 4 governance is remotely landed at `054120ddc1e34eb6f0f2f40332528be318c1370d`. Fresh post-Stage-12 discovery is complete. Sprint 11 Slice 5 — Canonical Client Image Selection Confirmation Evidence Foundation is Technical Design Frozen from that exact baseline. Slice 5 implementation is not yet authorized. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 5 — **Canonical Client Image Selection Confirmation Evidence Foundation** is Technical Design Frozen from exact baseline:

`054120ddc1e34eb6f0f2f40332528be318c1370d` — `docs: close sprint 11 slice 4`

Production remains HOLD.

### Discovery findings

Fresh read-only post-Stage-12 discovery established:

- canonical Stage 12 is active `selection_pending`;
- canonical Stage 13 is active `editing_pending`;
- no canonical selection, selected-image, proof, gallery, editing or delivery relation currently exists;
- no function references `editing_pending`;
- `mark_booking_selection_pending(uuid)` is the only function referencing Stage 12;
- legacy `/editing` and `/pixieset` remain mock/Zustand-backed and are not canonical operational systems;
- legacy behavior states that editing starts only after selection and payment are confirmed, but this is not yet canonical database authority;
- approved commercial package inclusions contain retouched-image entitlements in human-readable labels;
- `commercial_package_inclusions` has `quantity` and `unit` columns, but the current approved package seed does not populate those fields for image entitlements;
- the approved `additional_image` add-on exists at INR 500 per additional retouched image;
- accepted quotations are immutable;
- each booking remains anchored to exactly one accepted `source_quotation_id`;
- no post-booking adjustment, charge, supplemental invoice or selection-commercial-reconciliation relation currently exists;
- `get_booking_payment_summary(uuid)` derives advance state from the immutable accepted-quotation payment requirement and does not represent post-selection adjusted settlement;
- privacy preference and image-use/marketing consent remain separate concepts and no canonical post-shoot privacy/image-use ledger currently exists.

### Design conclusion

Slice 5 establishes one missing canonical fact only:

**the client has confirmed a final image selection, with an authoritative selected-image count and confirmation timestamp.**

Slice 5 does not decide whether the selection exceeds a package entitlement.

Slice 5 does not calculate additional-image charges.

Slice 5 does not determine whether the booking is financially settled for editing.

Those are later commercial-reconciliation concerns.

### Canonical evidence relation

Slice 5 will introduce:

`public.booking_selection_confirmations`

The relation will contain canonical structural fields including:

- organization id;
- booking id;
- selected image count;
- client-selection confirmation timestamp;
- recording timestamp;
- recording organization-member actor.

Exactly one canonical selection-confirmation row may exist per organization + booking.

The evidence is immutable after creation.

No individual image identifiers are stored because no canonical image-asset model exists yet.

No gallery URL, proofing URL, free-text selection notes or privacy/consent content belong in this relation.

### Canonical record operation

Slice 5 will introduce:

`public.record_booking_selection_confirmation(uuid, integer, timestamptz)`

Return type:

`public.booking_selection_confirmations`

The operation will:

- reject a null booking id;
- require a positive integer selected-image count;
- require a non-null confirmation timestamp;
- reject future confirmation timestamps;
- require an authenticated actor;
- lock the booking as the synchronization root;
- require active organization membership;
- require `selection.record`;
- enforce booking branch scope where applicable;
- require exactly one current journey state;
- require exact active Stage 12 / `selection_pending`;
- require exactly one canonical Stage 11 `shoot_completed` -> Stage 12 `selection_pending` transition;
- require the client-selection confirmation timestamp not to precede the canonical Stage 12 entry;
- append exactly one immutable canonical selection-confirmation row;
- emit exactly one structural, non-sensitive `booking.selection_confirmed` audit event;
- return the canonical evidence row.

### Replay contract

Exact replay at Stage 12 will be idempotent.

Replay requires the same:

- booking;
- selected-image count;
- client-selection confirmation timestamp.

Valid exact replay returns the existing canonical row and performs no new insert or audit.

A conflicting replay with a different count or confirmation timestamp is rejected.

Replay is not a mechanism for correcting canonical evidence.

Any future correction model requires separate discovery and design.

### Permission boundary

Slice 5 introduces two selection-domain capabilities:

`selection.read`

- `requires_server_enforcement = false`

`selection.record`

- `requires_server_enforcement = true`

Initial role grants are frozen as:

- Founder: read + record;
- Studio Manager: read + record;
- Client Coordinator: read + record;
- Editor: read + record.

No other role receives a Slice 5 selection capability.

`booking.stage.advance` does not authorize selection evidence recording.

`editing.write` does not authorize selection evidence recording.

### Read / write containment

Authenticated direct reads of canonical confirmation evidence will require `selection.read` and applicable branch scope through RLS.

Authenticated direct INSERT, UPDATE and DELETE remain unavailable.

Recording occurs only through the dedicated permission-aware RPC.

The evidence table remains immutable.

### Security contract

`record_booking_selection_confirmation(uuid,integer,timestamptz)` will:

- be `SECURITY DEFINER`;
- use `SET search_path = ''`;
- revoke default/PUBLIC execution;
- deny `anon`;
- deny application execution to `service_role`;
- grant execution only to `authenticated`;
- retain database-side membership, permission, branch, exact-stage and lineage enforcement.

### Privacy boundary

Selection confirmation is not image-use consent.

Selected-image count must not:

- widen public usage;
- imply marketing approval;
- create portfolio permission;
- alter family privacy posture;
- identify individual selected images.

No privacy or consent schema is introduced or modified by Slice 5.

### Commercial boundary

Slice 5 records the selected-image count but performs no entitlement interpretation.

It must not parse package inclusion labels such as `15 Premium Retouched Images` at runtime.

It must not infer a package allowance from generic `item_XX` inclusion keys.

It must not mutate existing approved catalogue data to manufacture structured image entitlement.

It must not calculate or append the INR 500 `additional_image` charge.

It must not modify or supersede the accepted quotation.

It must not create a post-booking commercial adjustment.

A later separately frozen commercial-reconciliation checkpoint must establish authoritative machine-readable entitlement and any post-selection financial obligation.

### Payment boundary

Slice 5 introduces no payment prerequisite.

Recording client selection does not prove:

- full accepted-quotation settlement;
- payment of additional-image charges;
- financial readiness to begin editing.

No payment table, payment summary or payment permission changes are authorized.

### Journey boundary

Slice 5 records evidence only.

It does not advance the journey.

Stage 12 remains `selection_pending` after confirmation evidence is recorded.

Stage 12 -> 13 / `editing_pending` requires a later separately frozen gate after selection and commercial/payment prerequisites are canonical.

### Frozen implementation boundary

Exactly five implementation artifacts are authorized after a separate implementation release:

1. one new migration with logical suffix `sprint11_selection_confirmation_evidence_foundation.sql`;
2. `supabase/tests/sprint11_selection_confirmation_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_stage10_11_gate_test.sql`;
5. `supabase/tests/sprint10_extended_creative_assignments_test.sql`.

Artifacts 4 and 5 are compatibility-regression files only.

Their permitted change is strictly limited to:

- updating the canonical repository-wide `role_permissions` expectation from 233 to 241;
- updating the corresponding assertion description so it reflects the new canonical repository-wide total.

They may not change:

- pgTAP plan counts;
- fixture behavior;
- authorization behavior;
- journey behavior;
- any other assertion.

The migration timestamp will be generated locally only after implementation authorization.

No sixth implementation artifact is authorized without a governance amendment.

### Explicit exclusions

Slice 5 does not implement or modify:

- individual image assets or selected-image ids;
- preview-gallery records;
- Pixieset integration;
- proofing;
- culling;
- editing jobs;
- QC;
- delivery;
- heirloom production;
- package entitlement restructuring;
- package-inclusion backfill;
- additional-image billing;
- post-booking commercial adjustments;
- supplemental quotations or invoices;
- full-settlement calculation;
- payment ledger behavior;
- privacy or consent ledger;
- marketing approval;
- Stage 12 -> 13 / `editing_pending`;
- application routes;
- `/bookings` UI;
- `/editing`;
- `/pixieset`;
- remote Supabase;
- `--linked`;
- Production migration;
- Production deployment;
- release.

### Validation contract

Implementation acceptance will require:

- exact five-artifact implementation boundary;
- canonical permission total becomes exactly 68;
- canonical role-permission mapping total becomes exactly 241;
- the two compatibility-regression files change only the frozen 233 -> 241 expectation and matching assertion wording;
- clean local database reset;
- dedicated Slice 5 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- regenerated Supabase types with narrow semantic additions only;
- generated-type Prettier PASS;
- TypeScript PASS;
- production build PASS;
- `git diff --check` PASS;
- `selection.read` and `selection.record` exact permission/grant assertions;
- `selection.read.requires_server_enforcement = false`;
- `selection.record.requires_server_enforcement = true`;
- direct authenticated DML denial;
- Founder / Studio Manager / Client Coordinator / Editor authorized recording;
- unauthorized-role denial;
- inactive/suspended membership denial;
- branch-scope denial;
- exact Stage-12-only recording;
- exact Stage 11 -> 12 lineage validation;
- positive selected-image count validation;
- non-future timestamp validation;
- confirmation timestamp not preceding Stage-12 entry;
- exactly-one-row evidence cardinality;
- exact replay idempotency;
- conflicting replay rejection;
- no duplicate audit;
- evidence immutability;
- no individual image identifiers;
- no package-entitlement interpretation;
- no additional-image billing;
- no payment mutation;
- no Stage 12 -> 13 implementation;
- no privacy/consent mutation.

Implementation is not yet authorized.

Production remains HOLD.

## Immediate Product Sequence

Sprint 11 Slice 1 provides canonical immutable Shoot Completion evidence.

Sprint 11 Slice 2 provides the controlled Stage 10 -> 11 / `shoot_completed` database advancement gate.

Sprint 11 Slice 3 provides authenticated `/bookings` integration for completion recording and Stage 10 -> 11 advancement.

Sprint 11 Slice 4 provides the controlled Stage 11 -> 12 / `selection_pending` database gate.

Sprint 11 Slice 5 is now separately Technical Design Frozen for canonical client image-selection confirmation evidence only.

The intended sequence is now:

1. validate and governance-commit the Slice 5 Technical Design Freeze;
2. implement the exact frozen three-artifact evidence boundary only after explicit authorization;
3. validate and governance-close Slice 5 independently;
4. perform fresh discovery for structured image entitlement and post-booking commercial reconciliation;
5. establish canonical adjusted financial obligation and settlement semantics before designing Stage 12 -> 13;
6. freeze any Stage 12 -> 13 / `editing_pending` gate separately;
7. freeze application integration separately when its canonical database prerequisites exist.

Production remains HOLD.

## Known Debt Outside This Checkpoint's Boundary

Repository-wide ESLint/Prettier formatting debt exists in pre-Sprint-10 files (concentrated in `src/lib/leads.functions.ts`, `src/lib/lead-workspace.functions.ts`, and several `src/routes/_authenticated/*.tsx` files). This debt is acknowledged and tracked but remains outside every Sprint 10 slice's acceptance boundary. It must not be expanded into a repository-wide cleanup without a separately authorized checkpoint.

## Sprint 11 Slice 1 Regression Boundary Amendment — 2026-08-24

Full local pgTAP regression after the dedicated Sprint 11 Slice 1 suite passed 54/54 exposed one stale pre-existing global catalogue-count assertion in `supabase/tests/sprint10_extended_creative_assignments_test.sql`.

That Sprint 10 assertion expects exactly 230 `role_permissions` rows. Sprint 11 Slice 1 intentionally adds exactly three new `shoot.complete` grants — Founder, Studio Manager and Photographer — so the canonical total is now 233. The full regression result was 1208 passing assertions out of 1209, with this count assertion as the sole failure.

The Slice 1 implementation boundary is therefore amended by exactly one compatibility-regression file:

- `supabase/tests/sprint10_extended_creative_assignments_test.sql`

The permitted change in that file is limited to:

- changing the global canonical role-permission mapping expectation from 230 to 233;
- updating that assertion's description so it no longer represents the historical Slice 6A total as the current repository-wide total.

This amendment does not authorize:

- any change to the pgTAP plan count;
- any other Sprint 10 test behavior or fixture;
- any additional permission or role grant;
- any migration behavior change;
- any application/runtime/UI change;
- any Stage 10 -> 11 implementation;
- any remote Supabase or Production mutation.

The original Slice 1 migration, dedicated pgTAP suite and generated Supabase types remain the canonical implementation artifacts. Generated types remain deferred until the complete local regression is green.

Production remains HOLD.

## Completion Report Required

For each checkpoint report:
- what existed before
- what changed
- database migrations/functions/policies changed
- routes/components changed
- tests run and results
- manual verification performed
- security/tenant isolation checks
- unresolved issues
- recommended next checkpoint
