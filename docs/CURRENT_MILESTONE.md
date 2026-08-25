# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released.

Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slices 1 through 7 are implemented, fully validated locally and committed. Slice 7 implementation `8930475cdb2b3bd374c973f4d615f9e99eea64e9` and governance closeout `3fd398aababf846b1beda06c1bd9e74e71f8dfbd` are pushed to `origin/architecture-rebuild` and first remote reconciliation is confirmed at the closeout SHA with divergence `0 0`. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 7 — **Booking-Level Selection Entitlement Reconciliation Evidence Foundation** is implemented, fully validated locally and committed.

Technical-design freeze:

`ed1118130acbf12c9cafbd1a7acbe78453c00270` — `docs: freeze sprint 11 slice 7`

Frozen baseline:

`6e37919e207ddfc629373ee6dbe38c80459aa3a0` — `docs: reconcile sprint 11 slice 6 remote state`

Implementation:

`8930475cdb2b3bd374c973f4d615f9e99eea64e9` — `feat: add selection entitlement reconciliation foundation`

The implementation commit contains exactly the three frozen implementation artifacts. Clean local reset, dedicated Slice 7 pgTAP, full local regression, database lint, generated types, TypeScript and production build validation all passed.

Governance closeout:

`3fd398aababf846b1beda06c1bd9e74e71f8dfbd` — `docs: close sprint 11 slice 7`

The implementation and governance-closeout commits are pushed to `origin/architecture-rebuild`. First local/remote reconciliation is confirmed at `3fd398aababf846b1beda06c1bd9e74e71f8dfbd` with divergence `0 0`.

Next discovery checkpoint:

Perform fresh read-only discovery for adjusted financial-obligation semantics governing a positive reconciled `excess_image_count`. No additional-image price-version rule, adjusted financial obligation, full-settlement model or Stage 12 -> 13 gate is yet technically frozen or authorized.

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

Slice 6 is therefore **implemented, fully validated locally, governance closed, pushed and remotely reconciled**. `origin/architecture-rebuild` is confirmed at `fea4f34e54543ebf057b8c2278c49e9aa54c3c05` with local/remote divergence `0 0`.

Remote Supabase remains HOLD.

Production remains HOLD.

## Sprint 11 Slice 7 Technical Design Freeze

### Checkpoint

**Sprint 11 Slice 7 — Booking-Level Selection Entitlement Reconciliation Evidence Foundation**

Exact baseline:

`6e37919e207ddfc629373ee6dbe38c80459aa3a0` — `docs: reconcile sprint 11 slice 6 remote state`

Remote Supabase remains HOLD.

Production remains HOLD.

### Discovery conclusion

Fresh post-Slice-6 read-only discovery established:

- `bookings.source_quotation_id` retains the exact accepted quotation used to create the booking;
- accepted quotation line items retain exact `source_package_version_id`, `source_addon_version_id`, quantity, catalogue price, quoted price and pricing source;
- quotation line items are immutable once the quotation leaves draft;
- accepted quotations are immutable;
- approved commercial package/add-on versions are immutable;
- commercial add-on versioning has explicit version identity but no effective-date interval, supersession pointer or canonical "current approved version" field;
- `commercial_image_entitlements` supplies immutable machine-readable retouched-image entitlement per exact package/add-on version;
- `booking_selection_confirmations` supplies one immutable confirmed selected-image count per booking;
- selection confirmation is permitted only at exact active Stage 12 / `selection_pending` and is anchored to the canonical Stage 11 -> 12 transition;
- no canonical booking commercial-reconciliation relation or function currently exists;
- no canonical post-booking adjustment, invoice, adjusted-obligation or settlement relation currently exists;
- `booking_payment_requirements` remains the immutable accepted-quotation 50%-advance snapshot;
- `record_booking_payment(...)` accepts generic positive INR booking payment evidence and has no advance-total ceiling, accepted-quotation-total ceiling or journey-stage restriction;
- therefore the existing booking payment ledger remains suitable for later final-balance collection;
- `get_booking_payment_summary(uuid)` derives advance satisfaction only and does not represent full settlement;
- the approved `additional_image` v1 commercial source is currently fixed at INR 500 per additional retouched image;
- source doctrine states that additional images beyond package inclusions are chargeable and image processing begins after full payment;
- no source or schema authority defines whether a future additional-image price change should apply retrospectively to an already-selected booking.

### Design conclusion

Slice 7 records only the deterministic booking-level reconciliation between:

1. immutable accepted-quotation image entitlement; and
2. immutable confirmed selected-image count.

Slice 7 does not price an excess.

Slice 7 does not create a financial obligation.

Slice 7 does not determine settlement.

Slice 7 does not advance the booking journey.

Pricing-timing semantics are deliberately deferred to a separately discovered and frozen adjusted-financial-obligation checkpoint.

### Canonical reconciliation relation

Introduce:

`public.booking_selection_reconciliations`

Canonical fields:

- `id` uuid;
- `organization_id` uuid;
- `booking_id` uuid;
- `source_quotation_id` uuid;
- `source_selection_confirmation_id` uuid;
- `selected_image_count` integer;
- `included_image_count` integer;
- `excess_image_count` integer;
- `calculation_rule` text;
- `recorded_at` timestamptz;
- `recorded_by` uuid.

Exactly one reconciliation row may exist per organization + booking.

Tenant-safe organization-scoped foreign keys must bind:

- booking;
- source quotation;
- source selection confirmation;
- recording organization member.

The source quotation must be exactly:

`bookings.source_quotation_id`

and must remain an accepted quotation.

The source selection confirmation must be exactly the one immutable canonical `booking_selection_confirmations` row for the same organization + booking.

### Frozen calculation rule

The canonical calculation rule string is:

`accepted_quote_version_entitlement_v1`

`selected_image_count` must exactly snapshot:

`booking_selection_confirmations.selected_image_count`

`included_image_count` must be calculated only from the booking's exact accepted quotation line items and exact version-bound entitlement authority.

For each accepted quotation line:

- package line:
  - join `source_package_version_id` to its exact `commercial_image_entitlements.package_version_id`;
  - contribution =
    `quotation_line_items.quantity * retouched_image_count_per_unit`;
- add-on line:
  - if its exact `source_addon_version_id` has a `commercial_image_entitlements` row, contribution =
    `quotation_line_items.quantity * retouched_image_count_per_unit`;
  - if no image-entitlement authority exists for that add-on version, contribution = zero;
- custom line:
  - contribution = zero.

The canonical total is therefore the sum of exact entitlement-bearing accepted quotation lines.

The calculation must never:

- parse human-readable inclusion labels;
- infer entitlement from `item_key`;
- resolve a newer package/add-on version;
- resolve a "latest" approved commercial version;
- infer image entitlement from price;
- infer image entitlement from free text.

The accepted quotation must contain valid package entitlement authority.

If its package source has no exact machine-readable entitlement row, reconciliation must fail closed.

### No-overage and overage semantics

A reconciliation row is mandatory even when no additional images are owed.

Canonical excess calculation:

`excess_image_count = GREATEST(selected_image_count - included_image_count, 0)`

Therefore:

- selected below entitlement -> excess `0`;
- selected exactly at entitlement -> excess `0`;
- selected above entitlement -> positive excess count.

Absence of a reconciliation row must never mean "no overage".

The persisted zero-excess row is canonical evidence that reconciliation occurred and found no excess.

### Pre-purchased additional-image compatibility

If the accepted quotation already contains an entitlement-bearing `additional_image` add-on line, its exact accepted quantity contributes to `included_image_count`.

Example:

- package entitlement: 20;
- accepted `additional_image` quantity: 3;
- add-on entitlement per unit: 1;
- total included entitlement: 23.

This remains bound to the exact accepted quotation source version and quantity.

No new additional-image line is created during reconciliation.

### Pricing containment

Slice 7 must not resolve or persist:

- `unit_price_inr`;
- `catalogue_unit_price_inr` for a new charge;
- `quoted_unit_price_inr` for a new charge;
- `additional_image_price`;
- `excess_charge_inr`;
- `adjusted_total_inr`;
- `amount_due`;
- `balance_due`;
- `settlement_status`.

The currently approved INR 500 `additional_image` v1 source remains historical commercial evidence only.

Slice 7 must not assume that INR 500 governs every future reconciliation.

A later adjusted-financial-obligation checkpoint must separately establish and snapshot the exact commercial version and price authority governing any positive `excess_image_count`.

Historical obligations must never be dynamically recalculated from whichever commercial add-on version happens to be approved later.

### Controlled recording RPC

Introduce:

`public.record_booking_selection_reconciliation(uuid)`

Input:

- `p_booking_id uuid`.

The RPC must:

1. reject null booking id;
2. require an authenticated actor;
3. lock the canonical booking as the synchronization root;
4. require active organization membership;
5. require existing `selection.record` permission for the booking branch;
6. require branch scope where the booking has a branch;
7. require exactly one current canonical booking journey state;
8. require exact active Stage 12:
   - `stage_order = 12`;
   - `stage_key = 'selection_pending'`;
9. require exactly one immutable booking selection confirmation;
10. require the confirmation to belong to the same organization + booking;
11. require the booking's source quotation to exist and remain `accepted`;
12. require exact accepted quotation/package commercial lineage;
13. calculate `included_image_count` only through exact version-bound `commercial_image_entitlements`;
14. require positive included package entitlement;
15. calculate non-negative `excess_image_count`;
16. insert exactly one immutable reconciliation row;
17. append one structural audit event;
18. leave `booking_journey_states` unchanged;
19. create no `booking_stage_transitions`;
20. create no financial/payment/quotation mutation.

### Replay and conflict semantics

The booking lock serializes competing reconciliation attempts.

If a reconciliation already exists for the booking:

- recompute the canonical immutable inputs;
- if the existing row exactly matches:
  - source quotation;
  - source selection confirmation;
  - selected count;
  - included count;
  - excess count;
  - calculation rule;
  then return the existing row idempotently;
- otherwise fail closed as structural inconsistency.

No correction/update path is introduced.

Reconciliation evidence is immutable.

### Audit semantics

Append one structural audit event:

`booking.selection_reconciled`

The audit may include:

- booking id;
- reconciliation id;
- source quotation id;
- source selection confirmation id;
- selected image count;
- included image count;
- excess image count;
- calculation rule;
- recorded-by actor.

The audit must not contain:

- image identifiers;
- proof/gallery contents;
- filenames;
- free-text image-selection notes;
- newly invented commercial prices;
- payment credentials;
- privacy/consent content.

### Security and access

No new permission is introduced.

No role-permission mapping changes.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

Controlled reconciliation mutation requires existing:

`selection.record`

Authenticated read containment requires existing:

`selection.read`

Authenticated direct INSERT / UPDATE / DELETE must remain unavailable.

The recording RPC must be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated` only;
- not executable by `PUBLIC`;
- not executable by `anon`;
- not executable by `service_role`.

No service-role application mutation path is introduced.

The reconciliation relation must use forced RLS.

### Immutability

`booking_selection_reconciliations` is append-once immutable evidence.

After insertion:

- UPDATE is rejected;
- DELETE is rejected.

Identity, sources, counts, calculation rule, timestamps and actor must never be mutated.

### Frozen implementation boundary

Exactly three implementation artifacts are authorized by the freeze:

1. one new migration whose filename ends in
   `sprint11_selection_entitlement_reconciliation_foundation.sql`;
2. `supabase/tests/sprint11_selection_entitlement_reconciliation_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is authorized without a governance amendment.

No existing compatibility/regression test file is pre-authorized for modification.

If full regression exposes a genuinely stale repository-global count assertion, stop and govern that compatibility change separately.

### Explicit exclusions

Slice 7 does not implement or modify:

- package/add-on catalogue versions;
- package inclusion rows;
- commercial image entitlement authority;
- selection-confirmation evidence;
- accepted quotation contents;
- quotation totals;
- supplemental quotation;
- invoice;
- post-booking charge rows;
- additional-image pricing resolution;
- additional-image price-version choice;
- INR 500 charge creation;
- adjusted financial obligation;
- booking payment requirements;
- booking payment ledger behavior;
- payment summary semantics;
- settlement/full-balance determination;
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

Implementation acceptance will require:

- exact three-artifact implementation boundary;
- clean local database reset;
- canonical permission count remains exactly 68;
- canonical role-permission mapping count remains exactly 241;
- exactly one reconciliation row per organization + booking;
- tenant-safe booking FK;
- tenant-safe accepted-quotation FK;
- tenant-safe selection-confirmation FK;
- tenant-safe actor FK;
- immutable evidence;
- exact `accepted_quote_version_entitlement_v1` calculation rule;
- exact selected-count snapshot;
- exact package entitlement calculation;
- exact accepted image-entitlement add-on quantity contribution;
- unrelated add-on contributes zero;
- custom line contributes zero;
- no-overage persists explicit excess `0`;
- exact-boundary persists excess `0`;
- positive overage calculated exactly;
- missing package entitlement fails closed;
- missing selection confirmation fails closed;
- non-Stage-12 reconciliation fails closed;
- invalid journey-state cardinality fails closed;
- wrong-organization source identity fails closed;
- unauthorized actor rejected;
- branch-scope containment enforced;
- exact replay idempotent;
- conflicting persisted evidence fails closed;
- forced RLS;
- authenticated `selection.read` read containment;
- authenticated direct INSERT / UPDATE / DELETE denial;
- recording RPC executable by authenticated only;
- no service-role application mutation path;
- structural audit event recorded;
- no quotation mutation;
- no catalogue mutation;
- no payment requirement mutation;
- no booking payment mutation;
- no price lookup for a new excess charge;
- no financial-obligation creation;
- no journey-state mutation;
- no Stage 12 -> 13 transition;
- dedicated Slice 7 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- freshly generated Supabase types with narrow semantic diff;
- generated-type Prettier PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

Implementation was separately authorized after the technical-design freeze and is now complete.

### Implementation closeout — 2026-08-25

Technical-design freeze:

`ed1118130acbf12c9cafbd1a7acbe78453c00270` — `docs: freeze sprint 11 slice 7`

Frozen baseline:

`6e37919e207ddfc629373ee6dbe38c80459aa3a0` — `docs: reconcile sprint 11 slice 6 remote state`

Implementation:

`8930475cdb2b3bd374c973f4d615f9e99eea64e9` — `feat: add selection entitlement reconciliation foundation`

Implementation parent:

`ed1118130acbf12c9cafbd1a7acbe78453c00270`

Exact implementation artifacts:

1. `supabase/migrations/20260825162200_sprint11_selection_entitlement_reconciliation_foundation.sql`;
2. `supabase/tests/sprint11_selection_entitlement_reconciliation_test.sql`;
3. `src/integrations/supabase/types.ts`.

Delivered authority:

- immutable `public.booking_selection_reconciliations`;
- exactly one reconciliation row per organization + booking;
- tenant-safe booking, accepted-quotation, selection-confirmation and recording-member provenance;
- canonical calculation rule `accepted_quote_version_entitlement_v1`;
- `selected_image_count` snapshotted from immutable canonical selection confirmation;
- `included_image_count` derived only from exact accepted quotation line quantities and exact version-bound `commercial_image_entitlements`;
- package lines contribute through exact package-version entitlement authority;
- entitlement-bearing accepted add-on lines contribute through their exact accepted add-on version and quantity;
- unrelated add-ons contribute zero;
- custom quotation lines contribute zero;
- missing exact accepted package-version entitlement fails closed;
- canonical `excess_image_count = GREATEST(selected_image_count - included_image_count, 0)`;
- below-entitlement and exact-entitlement selections persist explicit zero-excess reconciliation evidence;
- positive excess persists quantity evidence only;
- accepted pre-purchased `additional_image` quantity increases included entitlement without creating a new quotation line;
- exact reconciliation replay is idempotent;
- structurally conflicting persisted reconciliation evidence fails closed;
- one structural `booking.selection_reconciled` audit event per real reconciliation;
- no runtime human-readable package-label parsing;
- no latest-version or price inference.

Security and tenancy validation:

- RLS enabled and forced;
- authenticated read containment uses existing `selection.read`;
- controlled mutation uses existing `selection.record`;
- booking-derived branch scope enforced;
- authenticated direct INSERT / UPDATE / DELETE unavailable;
- `record_booking_selection_reconciliation(uuid)` is `SECURITY DEFINER`;
- RPC uses empty `search_path`;
- authenticated RPC execution enabled;
- PUBLIC, anon and service_role RPC execution denied;
- no service-role application mutation path introduced;
- immutable lifecycle guard validated;
- canonical permission count remains 68;
- canonical role-permission mapping count remains 241.

Validation evidence:

- clean local database reset: PASS;
- Slice 7 migration applied last in canonical local migration order;
- dedicated Slice 7 pgTAP: 82/82 PASS;
- full local pgTAP regression: 24 files / 1511 tests PASS;
- local database lint: PASS — no schema errors;
- canonical image-entitlement rows after reset: 13;
- persisted reconciliation rows after reset: 0;
- generated Supabase types: exact 93 additions / 0 deletions after repository formatting;
- generated type surface includes `booking_selection_reconciliations` and `record_booking_selection_reconciliation`;
- generated-type Prettier: PASS;
- targeted ESLint for changed generated `types.ts`: PASS;
- repository-wide lint remains failing on acknowledged pre-existing formatting debt, with zero references to the changed generated `types.ts`;
- TypeScript `--noEmit`: PASS;
- production build: PASS with existing non-blocking dependency/deprecation/bundle warnings only;
- SQL trailing-whitespace check: PASS;
- SQL carriage-return check: PASS;
- SQL final-newline check: PASS;
- `git diff --check`: PASS;
- implementation commit contains exactly three frozen artifacts;
- implementation worktree after commit: clean.

Containment preserved:

- no package/add-on catalogue mutation;
- no `commercial_image_entitlements` mutation;
- no selection-confirmation mutation;
- no accepted-quotation mutation;
- no supplemental quotation or invoice;
- no excess-image price resolution;
- no additional-image price-version selection;
- no INR 500 booking charge creation;
- no adjusted financial obligation;
- no payment-requirement mutation;
- no booking-payment behavior change;
- no full-settlement determination;
- no journey-state mutation;
- no Stage 12 -> 13 / `editing_pending`;
- no editing, QC, delivery or Pixieset behavior;
- no privacy/consent change;
- no application route/UI implementation;
- no remote Supabase mutation;
- no Production migration or deployment.

Slice 7 is therefore **implemented, fully validated locally, committed, governance closed, pushed and remotely reconciled**.

Implementation `8930475cdb2b3bd374c973f4d615f9e99eea64e9` and governance closeout `3fd398aababf846b1beda06c1bd9e74e71f8dfbd` are confirmed on `origin/architecture-rebuild`. First local/remote reconciliation is confirmed at the closeout SHA with divergence `0 0`.

Remote Supabase remains HOLD.

Production remains HOLD.

## Immediate Product Sequence

1. perform fresh read-only discovery for adjusted financial-obligation semantics governing any positive reconciled `excess_image_count`;
2. only if discovery establishes sufficient authority, separately freeze the exact immutable commercial version/price rule governing that obligation;
3. separately establish full-settlement semantics using the existing canonical booking payment ledger;
4. only then design Stage 12 -> 13 / `editing_pending`.

No adjusted financial obligation, excess-image price resolution, settlement model or Stage 13 gate is authorized by the Slice 7 implementation or closeout.

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
