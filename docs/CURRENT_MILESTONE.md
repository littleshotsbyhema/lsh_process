# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released.

Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slices 1 through 5 are implemented, fully validated locally, committed, pushed to `origin/architecture-rebuild`, and remotely reconciled. Sprint 11 Slice 6 is implemented, fully validated locally, and committed locally at `fc96e30f261bca291ebbec4805fd7dbc9cfe20db`; governance closeout is being recorded by the current documentation checkpoint. Slice 6 has not yet been pushed or remotely reconciled. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 6 — **Version-Bound Machine-Readable Image Entitlement Authority Foundation** is implemented, fully validated locally and committed.

Technical-design freeze:

`96df8c22adce666cfa0be9518532f181942e1164` — `docs: freeze sprint 11 slice 6`

Implementation:

`fc96e30f261bca291ebbec4805fd7dbc9cfe20db` — `feat: add image entitlement authority foundation`

The implementation commit contains exactly the three frozen implementation artifacts. This documentation checkpoint records the local governance closeout. Remote push and remote reconciliation remain pending explicit release.

Remote Supabase remains HOLD.

Production remains HOLD.

## Sprint 11 Slice 6 Technical Design Freeze

### Checkpoint

**Sprint 11 Slice 6 — Version-Bound Machine-Readable Image Entitlement Authority Foundation**

Exact baseline:

`90d52a3482bc81aaf946487145dc8e59a33a820e` — `docs: close sprint 11 slice 5`

Production remains HOLD.

### Discovery conclusion

Fresh post-Slice-5 read-only discovery established:

- all 12 approved Maternity/Newborn/Sitter package versions contain a sourced retouched-image allowance;
- the approved package-inclusion rows currently express those allowances only through human-readable labels;
- `commercial_package_inclusions.quantity` and `.unit` exist but are null for every current approved inclusion;
- approved package versions and their inclusion rows are immutable;
- therefore historical approved inclusion rows must not be rewritten to add machine-readable quantities;
- `commercial_operational_requirements` establishes an existing version-bound sidecar-authority pattern;
- accepted quotation package/add-on lines retain exact `source_package_version_id`, `source_addon_version_id` and quantity;
- the approved `additional_image` add-on v1 is fixed at INR 500 and represents an additional retouched image beyond package inclusions;
- no canonical post-booking commercial adjustment, charge, invoice, obligation, reconciliation or settlement relation exists;
- existing booking payments are generic booking payment evidence, while the existing booking payment requirement remains an immutable accepted-quotation/advance snapshot;
- no canonical function references Stage 13 / `editing_pending`.

### Design conclusion

Slice 6 establishes machine-readable image entitlement authority only.

It does not reconcile a booking.

It does not create a financial obligation.

It does not determine settlement.

It does not advance the journey.

### Canonical entitlement relation

Introduce:

`public.commercial_image_entitlements`

Canonical structural fields:

- `id`;
- `organization_id`;
- `package_version_id` nullable;
- `addon_version_id` nullable;
- `retouched_image_count_per_unit`;
- `created_at`.

Exactly one commercial source must be present:

- package version; or
- add-on version.

Never both.

`retouched_image_count_per_unit` must be a positive integer.

Source identity is canonical and unique:

- at most one entitlement row may reference a given organization + package version;
- at most one entitlement row may reference a given organization + add-on version.

Package-version and add-on-version references must use tenant-safe organization-scoped foreign keys.

On creation, the referenced commercial version must already exist in the same organization and have `approval_status = 'approved'`.

An entitlement must never be attached to a draft or otherwise unapproved commercial version.

Once created, entitlement identity, source and quantity are immutable.

A package entitlement row represents the included retouched-image quantity for one quoted package unit.

An add-on entitlement row represents the included retouched-image quantity for one quoted add-on unit.

### Initial authoritative mapping

The migration will seed exactly 13 entitlement rows:

| Commercial source | Images per unit |
| --- | ---: |
| maternity_bronze | 15 |
| maternity_gold | 20 |
| maternity_diamond | 25 |
| maternity_emerald | 35 |
| newborn_bronze | 12 |
| newborn_gold | 18 |
| newborn_diamond | 24 |
| newborn_emerald | 30 |
| sitter_bronze | 12 |
| sitter_gold | 18 |
| sitter_diamond | 25 |
| sitter_emerald | 30 |
| additional_image v1 | 1 |

The migration must validate the exact approved package/add-on version identities and their existing sourced evidence.

The migration must not parse numeric entitlement from labels at runtime.

No generic `item_XX` inclusion key may be interpreted as entitlement.

### Accepted-quotation compatibility

Existing accepted quotation line items already retain:

- exact package-version source;
- exact add-on-version source;
- line quantity.

A later separately frozen reconciliation checkpoint may calculate total included retouched-image entitlement using exact version-bound entitlement rows and accepted quotation quantities.

Slice 6 itself performs no booking calculation.

### Historical catalogue preservation

Slice 6 must not update, delete, backfill or replace approved:

- `commercial_package_versions`;
- `commercial_package_inclusions`;
- `commercial_addon_versions`.

The current null `quantity` / `unit` values on approved package inclusions remain historical truth.

### Security and access

No new permission is introduced.

No role-permission mapping changes.

Authenticated reads require existing `org.read` through forced RLS, matching the established version-bound commercial-semantics authority pattern.

Authenticated direct INSERT, UPDATE and DELETE remain unavailable.

No application mutation RPC is introduced.

Entitlement rows are immutable.

### Frozen implementation boundary

Exactly three implementation artifacts:

1. one new migration whose filename ends in `sprint11_image_entitlement_authority_foundation.sql`;
2. `supabase/tests/sprint11_image_entitlement_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is authorized without governance amendment.

Canonical permission totals remain:

- permissions: 68;
- role-permission mappings: 241.

### Explicit exclusions

Slice 6 does not implement or modify:

- approved package inclusion quantity/unit backfill;
- package-version mutation;
- add-on-version mutation;
- runtime label parsing;
- booking selection evidence;
- booking-level entitlement reconciliation;
- additional-image excess calculation;
- INR 500 charge creation;
- post-booking financial adjustment;
- supplemental quotation;
- invoice;
- accepted quotation mutation;
- settlement/full-balance calculation;
- payment ledger behavior;
- payment requirement behavior;
- Stage 12 -> 13 / `editing_pending`;
- editing jobs;
- QC;
- delivery;
- Pixieset;
- privacy or consent;
- application routes/UI;
- remote Supabase;
- Production migration;
- Production deployment;
- release.

### Validation contract

Implementation acceptance requires:

- exact three-artifact boundary;
- exactly 13 canonical entitlement rows;
- exact 12 package-version entitlement mappings;
- exact one approved `additional_image` v1 entitlement mapping;
- exact expected quantities for all 13 mappings;
- positive integer entitlement quantity;
- exactly-one-source XOR enforcement;
- tenant-safe version foreign keys;
- unique organization + package-version entitlement mapping;
- unique organization + add-on-version entitlement mapping;
- creation restricted to already-approved commercial versions;
- immutable evidence;
- forced RLS;
- authenticated `org.read` read containment;
- direct authenticated INSERT/UPDATE/DELETE denial;
- no new permission;
- permission count remains exactly 68;
- role-permission mapping count remains exactly 241;
- no approved catalogue mutation;
- no runtime label parsing;
- no booking reconciliation;
- no charge/payment/settlement behavior;
- no Stage 12 -> 13 behavior;
- clean local database reset;
- dedicated Slice 6 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- freshly regenerated Supabase types with narrow semantic diff;
- generated-type Prettier PASS;
- TypeScript PASS;
- production build PASS;
- `git diff --check` PASS.

### Implementation closeout — 2026-08-25

Technical-design freeze:

`96df8c22adce666cfa0be9518532f181942e1164` — `docs: freeze sprint 11 slice 6`

Implementation:

`fc96e30f261bca291ebbec4805fd7dbc9cfe20db` — `feat: add image entitlement authority foundation`

Implementation parent:

`96df8c22adce666cfa0be9518532f181942e1164`

Exact implementation artifacts:

1. `supabase/migrations/20260825135328_sprint11_image_entitlement_authority_foundation.sql`;
2. `supabase/tests/sprint11_image_entitlement_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

Delivered authority:

- `public.commercial_image_entitlements`;
- exactly one package-version or add-on-version source per row;
- positive integer `retouched_image_count_per_unit`;
- tenant-safe organization-scoped source foreign keys;
- one entitlement row at most per organization + package version;
- one entitlement row at most per organization + add-on version;
- creation restricted to already-approved source versions;
- immutable entitlement evidence;
- exactly 12 approved package-version entitlement rows;
- exactly one approved `additional_image` v1 entitlement row;
- `additional_image` remains sourced from approved INR 500 fixed-amount v1 commercial evidence;
- no runtime numeric parsing of human-readable package inclusion labels.

Canonical seeded authority:

- maternity_bronze: 15;
- maternity_gold: 20;
- maternity_diamond: 25;
- maternity_emerald: 35;
- newborn_bronze: 12;
- newborn_gold: 18;
- newborn_diamond: 24;
- newborn_emerald: 30;
- sitter_bronze: 12;
- sitter_gold: 18;
- sitter_diamond: 25;
- sitter_emerald: 30;
- additional_image v1: 1.

Security and tenancy validation:

- RLS enabled and forced;
- authenticated SELECT only;
- authenticated read containment uses existing `org.read`;
- authenticated direct INSERT / UPDATE / DELETE unavailable;
- no application mutation RPC introduced;
- no service-role application grant introduced;
- immutable lifecycle guard validated;
- draft/unapproved package and add-on versions rejected;
- cross-organization source identity protected by tenant-safe composite foreign keys.

Historical commercial preservation:

- no approved `commercial_package_versions` mutation;
- no approved `commercial_package_inclusions` mutation;
- no approved `commercial_addon_versions` mutation;
- historical approved image-inclusion `quantity` / `unit` null values remain unchanged;
- no permission or role-permission mutation.

Validation evidence:

- migration-order correction: PASS — Slice 6 follows Slice 5 canonically;
- clean local database reset: PASS;
- canonical entitlement rows: 13 total / 12 package / 1 add-on;
- canonical permissions: 68;
- canonical role-permission mappings: 241;
- dedicated Slice 6 pgTAP: 49/49 PASS;
- full local pgTAP regression: 23 files / 1429 tests PASS;
- local database lint: PASS — no schema errors;
- generated Supabase types: exact `49` additions / `0` deletions;
- generated type semantic diff limited to `commercial_image_entitlements`;
- generated-type Prettier: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS with existing non-blocking dependency/deprecation warnings only;
- final forbidden-surface audit: PASS;
- `git diff --check`: PASS;
- implementation worktree after commit: clean.

Containment preserved:

- no booking-level entitlement reconciliation;
- no excess-image calculation;
- no INR 500 booking charge creation;
- no adjusted financial obligation;
- no supplemental quotation or invoice;
- no accepted quotation mutation;
- no settlement/full-balance calculation;
- no payment-ledger or payment-requirement behavior change;
- no Stage 12 -> 13 / `editing_pending`;
- no editing, QC, delivery or Pixieset behavior;
- no privacy/consent change;
- no application route/UI implementation;
- no remote Supabase mutation;
- no Production migration or deployment.

Slice 6 is therefore **implemented and fully validated locally**. Governance is closed locally by this documentation checkpoint. Remote branch reconciliation remains pending explicit push authorization.

Remote Supabase remains HOLD.

Production remains HOLD.

## Immediate Product Sequence

1. commit the Slice 6 governance closeout documentation;
2. after separate explicit release, push the Slice 6 implementation and closeout commits and reconcile `origin/architecture-rebuild`;
3. perform fresh read-only discovery for booking-level post-selection commercial reconciliation;
4. establish and separately freeze the canonical reconciliation boundary only after discovery resolves source-version quantities, no-overage evidence, additional-image overage semantics and applicable pricing-timing rules;
5. separately establish immutable adjusted financial-obligation semantics;
6. separately establish full-settlement semantics using the canonical booking payment ledger;
7. only then design Stage 12 -> 13 / `editing_pending`.

No booking-commercial reconciliation implementation, adjusted financial obligation, settlement model or Stage 13 gate is authorized by the Slice 6 closeout. Fresh read-only discovery is the next product step after remote reconciliation.

Remote Supabase remains HOLD.

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
