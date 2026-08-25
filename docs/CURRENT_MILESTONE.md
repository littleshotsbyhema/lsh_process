# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released.

Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slices 1 through 10 are implemented, fully validated locally, committed, governance closed and pushed. Slice 10 implementation `a058a36827eed5c9b4a1388109760082bcad5f48` — `feat: add full-balance settlement read authority` and governance closeout `e481d1a70640913362953a4970e445755352e408` — `docs: close sprint 11 slice 10` are independently confirmed on `origin/architecture-rebuild`; this checkpoint records the reconciled remote state. Remote Supabase remains HOLD. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 10 — **Current Full-Balance Settlement Read Authority Foundation** is implemented, fully validated locally, committed, governance closed, pushed and independently verified on the remote branch. This two-document checkpoint records the reconciled remote state.

Technical-design freeze:

`ef6874576643ea6df107e3dc14e5366f1f2aed9a` — `docs: freeze sprint 11 slice 10`

Implementation:

`a058a36827eed5c9b4a1388109760082bcad5f48` — `feat: add full-balance settlement read authority`

Implementation parent:

`ef6874576643ea6df107e3dc14e5366f1f2aed9a`

Exact implementation artifacts:

1. `supabase/migrations/20260826020000_sprint11_full_balance_settlement_read_authority_foundation.sql`;
2. `supabase/tests/sprint11_full_balance_settlement_read_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

Implementation diff:

- migration: 549 insertions;
- dedicated pgTAP: 1422 insertions;
- generated Supabase types: 20 insertions;
- total implementation commit: 1991 insertions / 0 deletions.

Validation evidence:

- clean local database reset: PASS;
- local database lint: PASS with no schema errors;
- dedicated Slice 10 pgTAP: 60 / 60 PASS;
- full local pgTAP regression: 27 files / 1750 tests PASS;
- canonical permission count: 68;
- canonical role-permission mapping count: 241;
- clean post-test authority rows: payment requirements 0 / reconciliations 0 / adjusted obligations 0 / payments 0 / reversals 0;
- exact RPC `public.get_booking_full_balance_summary(uuid)` present;
- exact 15-field result contract validated;
- `SECURITY DEFINER` with empty search path validated;
- authenticated execution allowed;
- anon execution denied;
- service_role execution denied;
- aggregate authorization requires existing `finance.read` plus booking branch scope;
- existing raw payment-ledger authorization remains unchanged;
- exact target rule `reconciled_accepted_or_adjusted_total_v1` validated;
- exact collection rule `non_reversed_booking_payments_v1` validated;
- zero-excess target resolves to immutable accepted quotation total;
- zero-excess plus adjusted-obligation coexistence fails closed;
- positive excess requires exact Slice 9 adjusted-obligation authority;
- missing positive-excess obligation fails closed;
- adjusted-obligation lineage mismatch fails closed;
- zero-payment current state validated;
- under-target collection behavior validated;
- exact-target collection behavior validated;
- over-target coverage satisfaction validated;
- reversed payments contribute zero to valid collections;
- later reversal deterministically changes current balance satisfaction;
- full-balance summary remains readable after later Stage 13 progression;
- Founder / Accounts / Sales / Studio Manager `finance.read` topology validated;
- no audit event is created by the read;
- no payment or reversal row is created by the read;
- no adjusted-obligation evidence is mutated by the read;
- no journey-state version is mutated by the read;
- no journey transition is created by the read;
- no settlement, full-balance or refund-due persistence relation exists;
- freshly generated local Supabase types include the Slice 10 RPC;
- generated-type Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS with existing non-blocking TanStack deprecation, dependency, bundle-size and Wrangler/Nitro warnings only;
- SQL/file hygiene and `git diff --check`: PASS;
- implementation commit contains exactly the three frozen artifacts;
- post-implementation-commit worktree: clean.

Canonical current full-balance rule:

`full_balance_satisfied =
 valid_collected_inr >= settlement_target_inr`

with:

`full_balance_outstanding_inr =
 GREATEST(settlement_target_inr - valid_collected_inr, 0)`

Slice 10 intentionally remains a deterministic current-state read authority only. It creates no persistent settlement evidence, no overpayment/refund classification, no payment mutation and no Stage 12 -> 13 transition.

Implementation `a058a36827eed5c9b4a1388109760082bcad5f48` and governance closeout `e481d1a70640913362953a4970e445755352e408` are independently confirmed on `origin/architecture-rebuild`, with exact local/remote parity `0 0` confirmed before this reconciliation edit. This two-document checkpoint records that reconciled remote state.

Remote Supabase remains HOLD.

Production remains HOLD.

Previous Slice 8 technical-design freeze:

`2e2fa624c1b2106fceeb0c46ca4a579d693f4d48` — `docs: freeze sprint 11 slice 8`

Frozen baseline:

`e02e81aacb77b2d9dbcffe8267c2e5fe55ee20a6` — `docs: reconcile sprint 11 slice 7 remote state`

Implementation:

`8ab0ab4e6fe0d3bae4084a66ab2999fed03abace` — `feat: add additional image pricing basis authority`

The implementation commit has exact parent `2e2fa624c1b2106fceeb0c46ca4a579d693f4d48` and contains exactly the three frozen implementation artifacts:

1. `supabase/migrations/20260825220600_sprint11_additional_image_pricing_basis_authority_foundation.sql`;
2. `supabase/tests/sprint11_additional_image_pricing_basis_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

Validation evidence:

- clean local migration/reset contract: PASS;
- dedicated Slice 8 pgTAP: 103 / 103 PASS;
- full local pgTAP regression: 25 files / 1614 tests PASS;
- local database lint: PASS with no schema errors;
- canonical permission count: 68;
- canonical role-permission mapping count: 241;
- canonical image-entitlement count: 13;
- canonical package additional-image term count: 12;
- persisted booking pricing-basis rows after clean reset: 0;
- all 12 protected package terms resolve package v1 -> `additional_image` v1 -> INR 500 -> one retouched image per unit;
- generated Supabase types: 211 additions / 0 deletions;
- generated-type Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS with existing non-blocking dependency, deprecation, bundle and Wrangler warnings only;
- `git diff --check`: PASS;
- implementation commit contains exactly three frozen artifacts and 4963 insertions / 0 deletions;
- post-implementation-commit worktree: clean.

The founder-approved commercial rule remains `client_favorable_quote_or_selection_v1`: accepted-booking A is the protected ceiling; an explicitly supplied valid selection-time B may improve the rate; lower B wins; equal or higher B resolves to A.

Slice 8 establishes immutable commercial package/additional-image term authority and immutable booking-level per-unit pricing-basis evidence only. It does not create an excess-image charge total, adjusted financial obligation, amount due, balance due, settlement result or Stage 12 -> 13 transition.

Slice 8 is implemented, fully validated locally, committed, governance closed, pushed and remotely reconciled. Implementation `8ab0ab4e6fe0d3bae4084a66ab2999fed03abace`, governance closeout `376304bcaa23535fc2ca1efa436811f7f4268b51`, and remote-state reconciliation `38b0d5c93d88a21d641f988d75054e178269926e` are confirmed on `origin/architecture-rebuild`, with local/remote parity at divergence `0 0`.

Current remote-state checkpoint:

Sprint 11 Slice 9 — **Booking Adjusted Financial Obligation Authority Foundation** — is implemented, fully validated locally, committed, governance closed, pushed and remotely reconciled.

Implementation:

`80822a81a087fb0225338466b077ec0e01ce4bd5` — `feat: add adjusted financial obligation authority`

Governance closeout:

`6527abb047ba003e9a253f5598ce018d9697b35a` — `docs: close sprint 11 slice 9`

Canonical rule:

`accepted_quote_plus_excess_image_charge_v1`

The implementation remains obligation-authority-only. Settlement, amount due, balance due, overpayment, refund state and Stage 12 -> 13 remain outside the Slice 9 boundary.

Implementation and governance closeout are confirmed on `origin/architecture-rebuild`, with parity `0 0` confirmed before this reconciliation edit. Remote Supabase remains HOLD. Production remains HOLD.

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

## Sprint 11 Slice 8 Technical Design Freeze — 2026-08-25

### Checkpoint

**Sprint 11 Slice 8 — Client-Favorable Additional-Image Pricing Basis Authority Foundation**

Exact baseline:

`e02e81aacb77b2d9dbcffe8267c2e5fe55ee20a6` — `docs: reconcile sprint 11 slice 7 remote state`

Remote Supabase remains HOLD.

Production remains HOLD.

### Discovery conclusion

Post-Slice-7 read-only discovery established:

- `booking_selection_reconciliations` supplies immutable positive or zero excess-image quantity evidence;
- no adjusted-obligation, invoice, balance-due or settlement relation currently exists;
- `booking_payment_requirements` remains the immutable accepted-quotation 50%-advance snapshot and must not be repurposed;
- the append-only `booking_payments` ledger can later capture further valid INR payment evidence without changing its current semantics;
- `get_booking_payment_summary(uuid)` remains advance-oriented and does not represent full settlement;
- approved commercial add-on versions are immutable;
- `commercial_addon_versions` has explicit version identity but no `effective_from`, `effective_until`, supersession pointer or canonical current-version marker;
- multiple approved add-on versions are structurally possible even though all current add-ons presently have exactly one approved v1;
- the canonical `additional_image` v1 is active, approved, fixed-amount INR 500 and has exact image-entitlement authority of one retouched image per unit;
- quotation add-on pricing requires the caller to supply an exact add-on version id;
- that exact quotation add-on version must be approved;
- quotation lines snapshot exact source version, catalogue unit price, quoted unit price and pricing source;
- quotation pricing never requires runtime "latest approved version" resolution;
- current package v1 records and `additional_image` v1 share source revision `2026-06-client-pdfs`;
- every current package v1 therefore has exactly one matching current INR 500 `additional_image` v1 provenance source;
- `source_revision` is provenance text rather than a relational commercial binding and must not become a runtime join rule;
- `booking_selection_confirmations.confirmed_at` is immutable selection-event timestamp authority;
- an add-on version's `approved_at` can prove that an explicitly chosen version was already approved by selection confirmation time, but must not be treated as an automatic commercial-effective-from rule;
- `payment.record`, `payment.read` and `commercial.price.override` already exist;
- current grants make those financial/commercial authorities Founder-controlled;
- no new permission is required for this checkpoint.

### Founder commercial policy

The approved pricing doctrine is:

`client_favorable_quote_or_selection_v1`

It combines two commercial bases.

**A — accepted-booking protected basis**

The commercial additional-image rate bound to the booking's exact accepted package version is the protected ceiling.

A later catalogue change must never retrospectively increase that booking's additional-image unit price.

**B — optional selection-time favorable basis**

At selection confirmation, an exact approved `additional_image` commercial version may be explicitly selected as a client-favorable concession.

B is optional.

B must never be resolved implicitly from:

- highest version number;
- latest approval timestamp;
- latest creation timestamp;
- current database row order;
- matching source-revision text;
- a future "current" catalogue assumption.

If B is supplied, it must be an exact approved commercial version that was already approved no later than the immutable selection-confirmation timestamp.

### Applied pricing rule

Canonical pricing rule:

`client_favorable_quote_or_selection_v1`

Applied unit price:

- if B is absent -> A;
- if B unit price is lower than A -> B;
- if B equals A -> A;
- if B is higher than A -> A.

Therefore B can improve the client's price but can never increase the protected accepted-booking price.

The applied source version and price become immutable evidence once recorded.

### Canonical package additional-image term authority

Introduce:

`public.commercial_package_additional_image_terms`

Canonical fields:

- `id` uuid;
- `organization_id` uuid;
- `package_version_id` uuid;
- `additional_image_addon_version_id` uuid;
- `currency` text;
- `unit_price_inr` integer;
- `binding_rule` text;
- `created_at` timestamptz.

Canonical binding rule:

`explicit_package_additional_image_term_v1`

Exactly one row may exist per organization + package version.

Tenant-safe organization-scoped foreign keys must bind:

- exact commercial package version;
- exact commercial add-on version.

A valid term row must require:

- exact package version exists in the same organization;
- package version is approved;
- exact add-on version exists in the same organization;
- its parent add-on key is exactly `additional_image`;
- the add-on is active at authority creation;
- the add-on version is approved;
- pricing type is exactly `fixed_amount`;
- currency is exactly `INR`;
- `amount_inr` is positive;
- snapshotted `unit_price_inr` exactly equals the add-on version's immutable `amount_inr`;
- the exact add-on version has `commercial_image_entitlements` authority;
- that entitlement is exactly one retouched image per unit;
- the package service category is supported by the `additional_image` add-on.

The authority is immutable.

No runtime matching by `source_revision` is permitted.

### Canonical current authority seed

The Slice 8 migration must establish exactly 12 current package-version bindings:

- maternity_bronze v1 -> additional_image v1 -> INR 500;
- maternity_gold v1 -> additional_image v1 -> INR 500;
- maternity_diamond v1 -> additional_image v1 -> INR 500;
- maternity_emerald v1 -> additional_image v1 -> INR 500;
- newborn_bronze v1 -> additional_image v1 -> INR 500;
- newborn_gold v1 -> additional_image v1 -> INR 500;
- newborn_diamond v1 -> additional_image v1 -> INR 500;
- newborn_emerald v1 -> additional_image v1 -> INR 500;
- sitter_bronze v1 -> additional_image v1 -> INR 500;
- sitter_gold v1 -> additional_image v1 -> INR 500;
- sitter_diamond v1 -> additional_image v1 -> INR 500;
- sitter_emerald v1 -> additional_image v1 -> INR 500.

The migration may use the currently established shared source revision as a fail-closed migration precondition/provenance check.

The persisted bindings must resolve by stable natural commercial identity:

- organization;
- package key;
- package version number;
- add-on key;
- add-on version number.

Reset-generated UUID values must never be hardcoded.

After authority creation, runtime code must use exact relational ids and must never perform a `source_revision` join.

No application mutation RPC for this global authority is introduced by Slice 8.

Future package/add-on commercial generations require separately governed exact bindings rather than runtime inference.

### Canonical booking pricing-basis evidence

Introduce:

`public.booking_additional_image_pricing_bases`

Canonical fields:

- `id` uuid;
- `organization_id` uuid;
- `booking_id` uuid;
- `source_reconciliation_id` uuid;
- `source_quotation_id` uuid;
- `source_selection_confirmation_id` uuid;
- `source_package_version_id` uuid;
- `source_package_additional_image_term_id` uuid;
- `quote_acceptance_addon_version_id` uuid;
- `quote_acceptance_unit_price_inr` integer;
- `selection_addon_version_id` uuid nullable;
- `selection_unit_price_inr` integer nullable;
- `applied_addon_version_id` uuid;
- `applied_unit_price_inr` integer;
- `currency` text;
- `pricing_rule` text;
- `recorded_at` timestamptz;
- `recorded_by` uuid.

Exactly one pricing-basis row may exist per organization + booking.

A pricing-basis row is permitted only when the canonical Slice 7 reconciliation has:

`excess_image_count > 0`

Zero-excess bookings must not create pricing-basis evidence because no additional-image commercial obligation can arise from that reconciliation.

Tenant-safe organization-scoped foreign keys must bind:

- booking;
- source reconciliation;
- accepted source quotation;
- source selection confirmation;
- accepted source package version;
- source package additional-image term;
- A-side add-on version;
- optional B-side add-on version;
- applied add-on version;
- recording organization member.

### A-side protected-basis resolution

A must be resolved only through this exact chain:

booking
-> exact `bookings.source_quotation_id`
-> accepted quotation
-> exact package quotation line
-> exact `source_package_version_id`
-> exact `commercial_package_additional_image_terms` row
-> exact bound `additional_image` add-on version and snapshotted unit price.

Requirements:

- source quotation must remain accepted;
- the quotation must contain exactly one canonical package line;
- package line source version must exactly match the persisted source package version;
- exactly one package additional-image term must exist;
- term currency must be INR;
- term unit price must remain positive;
- term add-on source must remain the exact immutable approved `additional_image` version.

Missing or ambiguous A authority fails closed.

No latest-version lookup is permitted.

No source-revision lookup is permitted at runtime.

### B-side optional favorable-basis resolution

The caller may supply one nullable exact commercial add-on version id.

If null:

- no B basis exists;
- selection version and price fields remain null;
- A is applied.

If non-null, the exact B version must:

- belong to the same organization;
- belong to add-on key `additional_image`;
- have an active parent add-on;
- be approved;
- be `fixed_amount`;
- use currency `INR`;
- have positive `amount_inr`;
- have exact image-entitlement authority of one retouched image per unit;
- support the accepted package's service category;
- have non-null `approved_at`;
- satisfy:
  `approved_at <= booking_selection_confirmations.confirmed_at`.

The B price is always the exact immutable catalogue `amount_inr` of the supplied version.

Slice 8 does not permit a caller-entered arbitrary unit price.

Supplying B requires existing:

`commercial.price.override`

This permission authorizes the discretionary client-favorable commercial choice; it does not authorize a free-form monetary value.

### Controlled recording RPC

Introduce:

`public.record_booking_additional_image_pricing_basis(uuid, uuid)`

Inputs:

- `p_booking_id uuid`;
- `p_selection_addon_version_id uuid` nullable.

The RPC must:

1. reject null booking id;
2. require an authenticated actor;
3. lock the canonical booking as synchronization root;
4. require active organization membership;
5. require existing `payment.record`;
6. require booking branch scope where the booking has a branch;
7. require exactly one canonical current journey state;
8. require exact active Stage 12:
   - `stage_order = 12`;
   - `stage_key = 'selection_pending'`;
9. require exactly one canonical immutable selection confirmation;
10. require exactly one canonical immutable Slice 7 reconciliation;
11. require the reconciliation to belong to the same organization + booking;
12. require `excess_image_count > 0`;
13. require the exact accepted source quotation;
14. require exactly one accepted package line;
15. resolve exact A authority only through the package-term binding;
16. validate optional exact B authority when supplied;
17. require `commercial.price.override` when B is supplied;
18. apply `client_favorable_quote_or_selection_v1`;
19. persist exactly one immutable pricing-basis row;
20. append one structural audit event;
21. leave `booking_selection_reconciliations` unchanged;
22. leave accepted quotation and quotation lines unchanged;
23. leave `booking_payment_requirements` unchanged;
24. create no `booking_payments`;
25. create no financial obligation/charge total;
26. leave journey state unchanged;
27. create no Stage 12 -> 13 transition.

### Replay and conflict semantics

The booking lock serializes competing pricing-basis attempts.

If pricing-basis evidence already exists:

- recompute A from immutable accepted-booking sources;
- recompute/validate B from the supplied exact optional version;
- recompute the applied source and unit price;
- if every persisted source and derived value matches exactly, return the existing row idempotently;
- otherwise fail closed as structural/commercial inconsistency.

No update or correction path is introduced.

If a basis is originally recorded without B, replay with a later B is a conflict rather than a correction.

The commercial decision must therefore be complete when immutable pricing-basis evidence is first recorded.

### Audit semantics

Append one structural financial audit event:

`booking.additional_image_pricing_basis_recorded`

The audit may include:

- booking id;
- pricing-basis id;
- reconciliation id;
- source quotation id;
- package version id;
- A-side add-on version id;
- A-side unit price;
- optional B-side add-on version id;
- optional B-side unit price;
- applied add-on version id;
- applied unit price;
- pricing rule;
- actor.

The audit must not contain:

- image identifiers;
- gallery/proof contents;
- filenames;
- free-text selection notes;
- payment credentials;
- arbitrary invented prices;
- privacy/consent content.

### Security and access

No new permission is introduced.

No role-permission mappings change.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

`commercial_package_additional_image_terms`:

- forced RLS;
- authenticated SELECT requires existing `payment.read`;
- authenticated direct INSERT / UPDATE / DELETE denied;
- no application mutation RPC;
- no service-role application mutation path.

`booking_additional_image_pricing_bases`:

- forced RLS;
- authenticated SELECT requires existing `payment.read`;
- booking branch scope enforced for reads;
- authenticated direct INSERT / UPDATE / DELETE denied.

Controlled recording requires:

`payment.record`

When B is supplied it additionally requires:

`commercial.price.override`

The recording RPC must be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated` only;
- not executable by `PUBLIC`;
- not executable by `anon`;
- not executable by `service_role`.

No service-role application mutation path is introduced.

### Immutability

Both Slice 8 relations are append-once immutable authority.

After insertion:

- UPDATE is rejected;
- DELETE is rejected.

Commercial source ids, prices, rule, actor and timestamps must never be rewritten.

Approved package/add-on catalogue versions remain untouched.

### Pricing containment

Slice 8 records only per-unit commercial pricing basis.

It must not calculate or persist:

- `excess_charge_inr`;
- `adjusted_total_inr`;
- `amount_due`;
- `balance_due`;
- `settlement_status`;
- full-settlement result.

In particular, Slice 8 must not perform:

`excess_image_count * applied_unit_price_inr`

as a persisted financial obligation.

That multiplication belongs to the separately discovered and frozen adjusted-financial-obligation checkpoint that follows this authority foundation.

### Frozen implementation boundary

Exactly three implementation artifacts are authorized by this technical freeze:

1. one new migration whose filename ends in
   `sprint11_additional_image_pricing_basis_authority_foundation.sql`;
2. `supabase/tests/sprint11_additional_image_pricing_basis_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is authorized without a governance amendment.

No existing compatibility/regression test file is pre-authorized for modification.

If full regression exposes a genuinely stale repository-global assertion, stop and govern that compatibility change separately.

No application route or UI is authorized.

### Explicit exclusions

Slice 8 does not implement or modify:

- existing approved package versions;
- existing approved add-on versions;
- package inclusion rows;
- `commercial_image_entitlements`;
- selection-confirmation evidence;
- selection-reconciliation evidence;
- accepted quotation contents;
- quotation totals;
- supplemental quotations;
- invoices;
- arbitrary/custom additional-image prices;
- adjusted financial obligation;
- excess-image charge total;
- `booking_payment_requirements`;
- booking payment ledger behavior;
- payment-summary semantics;
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
- exactly 12 canonical current package additional-image term rows;
- exact one term per current approved package v1;
- every current term resolves `additional_image` v1;
- every current term snapshots INR 500;
- every bound add-on version has exact image entitlement one;
- stable natural-identity seeding with no hardcoded reset-generated UUIDs;
- `source_revision` used only as migration provenance/precondition, never runtime commercial resolution;
- unique organization + package-version term;
- tenant-safe package/add-on FKs;
- package-term immutability;
- exactly one booking pricing basis per organization + booking;
- pricing basis requires positive canonical Slice 7 excess;
- zero excess rejected;
- exact accepted quotation lineage;
- exact package-version lineage;
- exact selection-confirmation lineage;
- exact reconciliation lineage;
- exact A-side package-term resolution;
- missing A authority fails closed;
- ambiguous A authority fails closed;
- B absent -> A applied;
- B lower than A -> B applied;
- B equal to A -> A applied;
- B higher than A -> A applied;
- wrong add-on B rejected;
- unapproved B rejected;
- non-fixed-amount B rejected;
- non-INR B rejected;
- B without one-image entitlement rejected;
- B approved after selection confirmation rejected;
- B selection requires `commercial.price.override`;
- A-only recording requires `payment.record`;
- exact `client_favorable_quote_or_selection_v1` rule;
- persisted applied version matches applied price source;
- pricing-basis immutability;
- exact replay idempotent;
- conflicting replay fails closed;
- forced RLS on both relations;
- authenticated `payment.read` containment;
- booking branch scope containment;
- authenticated direct INSERT / UPDATE / DELETE denial;
- recording RPC executable by authenticated only;
- no service-role application mutation path;
- structural audit event recorded;
- no runtime latest-version lookup;
- no runtime maximum-version-number selection;
- no runtime source-revision matching;
- no catalogue mutation;
- no accepted-quotation mutation;
- no payment-requirement mutation;
- no booking-payment mutation;
- no excess-charge multiplication/persistence;
- no adjusted financial obligation;
- no settlement determination;
- no journey-state mutation;
- no Stage 12 -> 13 transition;
- zero pricing-basis rows after clean reset;
- dedicated Slice 8 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- freshly generated Supabase types with narrow semantic diff;
- generated-type Prettier PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

## Sprint 11 Slice 8 Implementation Verification and Governance Closeout — 2026-08-25

### Implementation commit

`8ab0ab4e6fe0d3bae4084a66ab2999fed03abace` — `feat: add additional image pricing basis authority`

Exact parent:

`2e2fa624c1b2106fceeb0c46ca4a579d693f4d48` — `docs: freeze sprint 11 slice 8`

The implementation commit contains exactly the three frozen artifacts and no fourth implementation artifact:

1. `supabase/migrations/20260825220600_sprint11_additional_image_pricing_basis_authority_foundation.sql`;
2. `supabase/tests/sprint11_additional_image_pricing_basis_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

Commit delta is exactly 4963 insertions / 0 deletions.

### Delivered authority

Slice 8 delivers:

- immutable `public.commercial_package_additional_image_terms`;
- exactly one explicit additional-image commercial term per organization + package version;
- exactly 12 current package-v1 bindings;
- exact `additional_image` v1 authority at INR 500 for all 12 current package versions;
- exact one-retouched-image-per-unit add-on entitlement compatibility;
- immutable `public.booking_additional_image_pricing_bases`;
- exactly one pricing-basis row per organization + booking;
- exact accepted quotation, package version, selection confirmation and Slice 7 reconciliation provenance;
- exact protected A authority through the explicit package-term binding;
- optional exact selection-time B authority;
- B approval-time containment against immutable selection confirmation;
- B requires approved, active-parent, fixed-amount, INR, positive-price, one-image-entitlement commercial authority;
- B requires `commercial.price.override`;
- recording requires `payment.record`;
- authenticated reads require `payment.read`;
- exact `client_favorable_quote_or_selection_v1`;
- B absent -> A;
- B lower than A -> B;
- B equal to A -> A;
- B higher than A -> A;
- exact replay idempotence;
- conflicting immutable evidence fails closed;
- structural `booking.additional_image_pricing_basis_recorded` audit evidence;
- no caller-entered arbitrary monetary value;
- no runtime `source_revision` or latest/current-version inference.

### Local validation evidence

- clean local migration/reset contract: PASS;
- canonical counts after reset: permissions 68, role-permission mappings 241, image entitlements 13, package terms 12, booking pricing bases 0;
- dedicated Slice 8 pgTAP: 103 / 103 PASS;
- full local pgTAP regression: 25 files / 1614 tests PASS;
- local database lint: PASS with no schema errors;
- both Slice 8 relations: RLS enabled and forced;
- authenticated direct INSERT / UPDATE / DELETE denied;
- controlled RPC: `SECURITY DEFINER`, empty `search_path`, authenticated execution only;
- PUBLIC, anon and service_role RPC execution denied;
- generated Supabase types: 211 additions / 0 deletions;
- generated-type Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS with existing non-blocking warnings only;
- `git diff --check`: PASS;
- implementation commit boundary: exact three artifacts;
- post-implementation-commit worktree: clean.

### Containment preserved

Slice 8 creates no:

- accepted-quotation mutation;
- quotation-line mutation;
- payment-requirement mutation;
- booking-payment mutation;
- excess-image charge multiplication;
- excess-image charge total;
- adjusted booking total;
- adjusted financial obligation;
- amount-due or balance-due authority;
- settlement/full-balance determination;
- journey-state mutation;
- Stage 12 -> 13 / `editing_pending` transition;
- editing, QC, delivery or Pixieset behavior;
- application route or UI;
- remote Supabase mutation;
- Production migration, deployment or release.

Slice 8 is therefore **implemented, fully validated locally, committed, governance closed, pushed and remotely reconciled**.

Implementation `8ab0ab4e6fe0d3bae4084a66ab2999fed03abace` and governance closeout `376304bcaa23535fc2ca1efa436811f7f4268b51` are confirmed on `origin/architecture-rebuild`. First local/remote reconciliation is confirmed at the closeout SHA with divergence `0 0`.

Remote Supabase remains HOLD.

Production remains HOLD.

## Sprint 11 Slice 9 Technical Design Freeze — 2026-08-26

### Checkpoint

**Sprint 11 Slice 9 — Booking Adjusted Financial Obligation Authority Foundation**

Exact baseline:

`38b0d5c93d88a21d641f988d75054e178269926e` — `docs: reconcile sprint 11 slice 8 remote state`

Remote Supabase remains HOLD.

Production remains HOLD.

### Discovery conclusion

Fresh post-Slice-8 read-only discovery established:

- `booking_payment_requirements` is the immutable accepted-booking financial-principal authority and snapshots the exact `source_quotation_id` plus `accepted_quotation_total_inr`;
- `booking_selection_reconciliations` is the immutable booking-level selected/included/excess quantity authority;
- `booking_additional_image_pricing_bases` is the immutable booking-level applied additional-image unit-price authority;
- Slice 8 pricing basis carries exact reconciliation, quotation, package/add-on-version and applied-unit-price provenance;
- `booking_payments` is a generic booking-wide collection ledger rather than an advance-only ledger;
- `get_booking_payment_summary(uuid)` sums all non-reversed booking payments and currently interprets them only against the advance requirement;
- no canonical adjusted-obligation, invoice, charge-total, amount-due, balance-due or settlement relation exists;
- no canonical financial view provides adjusted-obligation or settlement authority;
- no function implements adjusted obligation or Stage 12 -> 13 settlement semantics;
- Stage 12 `selection_pending` and Stage 13 `editing_pending` exist in the journey catalogue, but no Stage 12 -> 13 financial gate is implemented;
- existing `finance.write` is server-enforced and granted exactly to Accounts, Founder and Studio Manager;
- existing `finance.read` is granted to Accounts, Founder, Sales and Studio Manager;
- no current canonical function consumes `finance.read` or `finance.write`;
- no new permission or role-permission mapping is required.

### Design conclusion

Slice 9 establishes immutable booking-level adjusted financial-obligation authority only.

It does not establish settlement.

It does not mutate payment collections.

It does not determine amount due, balance due, overpayment or refund state.

It does not advance Stage 12 -> 13.

### Canonical adjusted-obligation relation

Introduce:

`public.booking_adjusted_financial_obligations`

Canonical structural fields:

- `id uuid`;
- `organization_id uuid`;
- `booking_id uuid`;
- `source_payment_requirement_id uuid`;
- `source_quotation_id uuid`;
- `source_reconciliation_id uuid`;
- `source_pricing_basis_id uuid`;
- `accepted_quotation_total_inr integer`;
- `excess_image_count integer`;
- `applied_unit_price_inr integer`;
- `excess_image_charge_inr bigint`;
- `adjusted_total_inr bigint`;
- `currency text`;
- `calculation_rule text`;
- `recorded_at timestamptz`;
- `recorded_by uuid`.

Exactly one immutable adjusted-obligation row may exist per organization + booking.

A row may exist only when the exact canonical Slice 7 reconciliation has:

`excess_image_count > 0`

Zero-excess bookings do not receive a Slice 9 row. For those bookings, the existing immutable accepted quotation / payment requirement remains the unadjusted principal authority.

### Canonical calculation rule

The exact rule is:

`accepted_quote_plus_excess_image_charge_v1`

Canonical arithmetic:

`excess_image_charge_inr = excess_image_count * applied_unit_price_inr`

`adjusted_total_inr = accepted_quotation_total_inr + excess_image_charge_inr`

The multiplication and total calculation must use `bigint` arithmetic.

`excess_image_charge_inr` and `adjusted_total_inr` are persisted as `bigint`.

No caller-supplied monetary amount is permitted.

### Exact principal authority

`accepted_quotation_total_inr` must come only from the booking's exact immutable:

`public.booking_payment_requirements`

The future operation must not reconstruct the accepted-booking principal from quotation-line arithmetic.

The payment requirement must:

- belong to the same organization + booking;
- reference the exact `bookings.source_quotation_id`;
- use INR;
- carry a positive accepted quotation total;
- remain unchanged by Slice 9.

### Exact quantity authority

`excess_image_count` must come only from the exact canonical:

`public.booking_selection_reconciliations`

The reconciliation must:

- belong to the same organization + booking;
- reference the exact booking source quotation;
- have `excess_image_count > 0`;
- remain unchanged by Slice 9.

### Exact price authority

`applied_unit_price_inr` must come only from the exact canonical:

`public.booking_additional_image_pricing_bases`

The pricing basis must:

- belong to the same organization + booking;
- reference the exact Slice 7 reconciliation used by the obligation;
- reference the exact booking source quotation;
- use INR;
- carry a positive `applied_unit_price_inr`;
- remain unchanged by Slice 9.

### Cross-authority lineage

All source authorities must agree exactly on:

- organization;
- booking;
- accepted source quotation.

The pricing basis must reference the exact reconciliation used by the obligation.

Any missing, duplicate, ambiguous or inconsistent source authority fails closed.

Runtime calculation must never infer:

- a different quotation;
- a latest/current commercial version;
- a replacement reconciliation;
- an alternative price;
- an arbitrary amount.

### Required supporting composite identities

The migration may add supporting unique indexes required for tenant-safe composite source foreign keys:

`booking_payment_requirements (organization_id, booking_id, id)`

`booking_additional_image_pricing_bases (organization_id, booking_id, id)`

The existing canonical Slice 7 index:

`booking_selection_reconciliations (organization_id, booking_id, id)`

remains authoritative.

These indexes do not alter domain semantics.

### Controlled recording RPC

Introduce:

`public.record_booking_adjusted_financial_obligation(uuid)`

Input:

- booking id only.

The RPC must not accept:

- amount;
- unit price;
- excess quantity;
- discount;
- override;
- adjustment value;
- settlement value;
- note;
- free text;
- arbitrary JSON.

Canonical operation:

1. reject null booking id;
2. require authenticated actor;
3. lock the booking;
4. require active organization membership;
5. require existing `finance.write`;
6. require booking branch scope;
7. require exactly one current booking journey state;
8. require exact Stage 12 / `selection_pending`;
9. require exactly one canonical booking payment requirement;
10. validate exact accepted-quotation principal lineage;
11. require exactly one canonical Slice 7 reconciliation;
12. require positive reconciled excess;
13. require exactly one canonical Slice 8 pricing basis;
14. require pricing basis to reference that exact reconciliation;
15. validate organization + booking + quotation lineage across all authorities;
16. validate INR source authorities;
17. calculate the excess-image charge using bigint arithmetic;
18. calculate the adjusted total using bigint arithmetic;
19. persist exactly one immutable obligation row;
20. append one structural audit event;
21. leave all source authorities unchanged;
22. leave booking payments and reversals unchanged;
23. leave journey state and transitions unchanged;
24. create no settlement state;
25. create no Stage 12 -> 13 transition.

### Replay semantics

The booking must be locked before replay resolution.

If an adjusted-obligation row already exists, the operation must recompute all immutable source authorities and calculations.

If every persisted source id, source snapshot, calculated amount, currency and rule matches exactly, return the existing row.

Any mismatch must fail closed as conflicting immutable financial-obligation evidence.

No UPDATE path is permitted.

### Authorization

No new permission is introduced.

No role-permission mapping changes are introduced.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

Controlled mutation requires:

`finance.write`

Current grant topology remains unchanged:

- Accounts;
- Founder;
- Studio Manager.

Authenticated reads require:

`finance.read`

plus booking branch scope.

Current `finance.read` grants remain unchanged:

- Accounts;
- Founder;
- Sales;
- Studio Manager.

`finance.write` authorizes materializing the deterministic financial obligation only.

It does not authorize arbitrary price or amount selection because the RPC accepts no monetary input.

### RLS / ACL / security

The new relation must enable and force RLS.

Authenticated SELECT requires:

- active organization membership through existing permission helpers;
- `finance.read`;
- booking branch scope.

Authenticated direct INSERT, UPDATE and DELETE are denied.

The controlled RPC must be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated`;
- unavailable to PUBLIC;
- unavailable to `anon`;
- unavailable to `service_role`.

No service-role application mutation path is introduced.

### Immutability

The adjusted-obligation relation is append-once immutable authority.

After insertion:

- UPDATE is rejected;
- DELETE is rejected.

Source ids, source monetary snapshots, calculated amounts, rule, actor and timestamps must never be rewritten.

### Audit

Canonical audit key:

`booking.adjusted_financial_obligation_recorded`

Audit evidence may contain structural:

- booking id;
- source payment-requirement id;
- source quotation id;
- source reconciliation id;
- source pricing-basis id;
- accepted quotation total;
- excess image count;
- applied unit price;
- excess image charge;
- adjusted total;
- currency;
- calculation rule;
- actor.

Audit must not contain unrelated family/private content, payment credentials or arbitrary free-form adjustment text.

### Settlement containment

Slice 9 creates financial-obligation authority only.

It must not calculate or persist:

- `valid_collected_inr`;
- `amount_paid`;
- `amount_due`;
- `balance_due`;
- `outstanding_inr`;
- `overpayment`;
- `refund_due`;
- `settlement_status`;
- `paid_in_full`.

The Slice 9 recording operation must not read booking collections to decide the obligation.

A later separately governed settlement checkpoint may compare the immutable adjusted obligation against valid non-reversed `booking_payments`.

### Source immutability / no mutation

Slice 9 must not update, delete or replace:

- `quotations`;
- `quotation_line_items`;
- `booking_payment_requirements`;
- `booking_payments`;
- `booking_payment_reversals`;
- `booking_selection_confirmations`;
- `booking_selection_reconciliations`;
- `booking_additional_image_pricing_bases`;
- `commercial_package_additional_image_terms`;
- `commercial_image_entitlements`;
- `booking_journey_states`;
- `booking_stage_transitions`.

### Frozen implementation boundary

Exactly three implementation artifacts are authorized after a separate implementation-authorization checkpoint:

1. one new migration whose filename ends in `sprint11_adjusted_financial_obligation_authority_foundation.sql`;
2. `supabase/tests/sprint11_adjusted_financial_obligation_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is authorized without governance amendment.

No application route, server-function file or UI is authorized.

No permission migration is authorized.

No compatibility/regression file modification is pre-authorized.

### Explicit exclusions

Slice 9 does not implement or modify:

- accepted quotation contents;
- quotation line items;
- package/add-on catalogue authority;
- image entitlement authority;
- selection confirmation;
- selection reconciliation;
- additional-image pricing-basis policy;
- caller-entered adjustments;
- discounts;
- supplemental quotation;
- invoice workflow;
- payment recording behavior;
- payment reversal behavior;
- payment requirement behavior;
- payment-summary behavior;
- settlement/full-balance semantics;
- amount-due semantics;
- balance-due semantics;
- overpayment/refund semantics;
- Stage 12 -> 13 / `editing_pending`;
- editing;
- QC;
- delivery;
- Pixieset;
- privacy/consent;
- application routes/UI;
- remote Supabase;
- Production migration/deployment/release.

### Validation contract

Implementation acceptance requires:

- exact three-artifact implementation boundary;
- exactly one adjusted-obligation row per organization + booking;
- positive-excess-only creation;
- zero-excess rejection / no row;
- exact payment-requirement principal provenance;
- exact source quotation provenance;
- exact reconciliation provenance;
- exact pricing-basis provenance;
- exact pricing-basis-to-reconciliation linkage;
- exact organization + booking + quotation agreement;
- exact persisted principal snapshot;
- exact persisted excess quantity snapshot;
- exact persisted applied-unit-price snapshot;
- bigint multiplication;
- exact excess-image charge calculation;
- exact adjusted-total calculation;
- exact `accepted_quote_plus_excess_image_charge_v1`;
- INR-only authority;
- no caller-supplied amount;
- missing source authority fails closed;
- duplicate/ambiguous source authority fails closed;
- lineage mismatch fails closed;
- exact replay idempotent;
- conflicting replay fails closed;
- immutable UPDATE / DELETE rejection;
- forced RLS;
- authenticated `finance.read` read containment;
- booking branch-scope containment;
- controlled mutation requires `finance.write`;
- Accounts / Founder / Studio Manager write behavior consistent with current grants;
- Sales read-but-not-write behavior consistent with current grants;
- direct authenticated INSERT / UPDATE / DELETE denied;
- RPC authenticated-only;
- PUBLIC / anon / service_role execution denied;
- no service-role application mutation path;
- structural audit evidence;
- no source-table mutation;
- no booking-payment mutation;
- no booking-payment-reversal mutation;
- no collection-dependent obligation calculation;
- no settlement fields;
- no amount-due or balance-due fields;
- no journey-state mutation;
- no Stage 12 -> 13 transition;
- canonical permission totals remain 68 / 241;
- zero adjusted-obligation rows after clean reset;
- dedicated Slice 9 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- freshly generated local Supabase types with narrow semantic diff;
- generated-type Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

Implementation authorization was granted after the technical freeze.

### Implementation closeout — 2026-08-26

Technical-design freeze:

`cb5462b1f662ee4eb218182558a4206231d78175` — `docs: freeze sprint 11 slice 9`

Frozen baseline:

`38b0d5c93d88a21d641f988d75054e178269926e` — `docs: reconcile sprint 11 slice 8 remote state`

Implementation:

`80822a81a087fb0225338466b077ec0e01ce4bd5` — `feat: add adjusted financial obligation authority`

Implementation parent:

`cb5462b1f662ee4eb218182558a4206231d78175`

Exact implementation artifacts:

1. `supabase/migrations/20260826010000_sprint11_adjusted_financial_obligation_authority_foundation.sql`;
2. `supabase/tests/sprint11_adjusted_financial_obligation_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

Delivered authority:

- canonical `public.booking_adjusted_financial_obligations`;
- exactly one immutable adjusted-obligation row per organization + booking;
- positive-excess-only obligation materialization;
- zero-excess bookings create no Slice 9 row;
- accepted principal comes only from the exact immutable booking payment requirement;
- excess quantity comes only from the exact canonical Slice 7 reconciliation;
- applied unit price comes only from the exact canonical Slice 8 pricing basis;
- exact organization + booking + source-quotation lineage across all authorities;
- pricing basis must reference the exact reconciliation used by the obligation;
- deterministic `bigint` calculation of excess-image charge and adjusted total;
- canonical rule `accepted_quote_plus_excess_image_charge_v1`;
- INR-only authority;
- exact replay returns the existing immutable row;
- conflicting immutable replay fails closed;
- no caller-supplied amount, quantity, price, adjustment, note or arbitrary JSON input.

Security and authorization:

- no new permission;
- no role-permission mapping change;
- canonical totals remain 68 permissions / 241 role-permission mappings;
- controlled mutation requires existing `finance.write`;
- Accounts, Founder and Studio Manager retain write authority through the existing grant topology;
- authenticated reads require existing `finance.read` plus booking branch scope;
- Accounts, Founder, Sales and Studio Manager retain read authority through the existing grant topology;
- relation RLS is enabled and forced;
- authenticated direct INSERT / UPDATE / DELETE is denied;
- controlled RPC is `SECURITY DEFINER` with empty search path;
- authenticated RPC execution is allowed;
- PUBLIC / anon / service_role execution is denied;
- no service-role application mutation path is introduced.

Audit:

- canonical event `booking.adjusted_financial_obligation_recorded`;
- structural source and calculation provenance only;
- audit evidence is non-sensitive;
- no unrelated private content or arbitrary financial-adjustment free text.

Validation evidence:

- clean local database reset: PASS;
- local database lint: PASS — no schema errors;
- dedicated Slice 9 pgTAP: 76 / 76 PASS;
- full local pgTAP regression: 26 files / 1690 tests PASS;
- canonical permissions: 68;
- canonical role-permission mappings: 241;
- clean-reset adjusted-obligation rows: 0;
- exact adjusted-obligation columns: 16;
- forced RLS: PASS;
- authenticated SELECT-only table privilege contract: PASS;
- authenticated-only controlled RPC contract: PASS;
- generated Supabase types: 127 additions / 0 deletions;
- generated-type Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS with existing non-blocking dependency, deprecation, bundle and Wrangler warnings only;
- file hygiene / `git diff --check`: PASS;
- implementation commit contains exactly three frozen artifacts;
- implementation commit stat: 3166 insertions;
- implementation parent is exactly the Slice 9 technical freeze;
- post-implementation-commit worktree: clean.

Containment preserved:

- no accepted-quotation mutation;
- no quotation-line mutation;
- no payment-requirement mutation;
- no payment or payment-reversal mutation;
- no selection-confirmation mutation;
- no Slice 7 reconciliation mutation;
- no Slice 8 pricing-basis mutation;
- no commercial-authority mutation;
- no collection-dependent obligation calculation;
- no settlement result;
- no amount-due or balance-due result;
- no overpayment or refund result;
- no paid-in-full state;
- no journey-state mutation;
- no booking-stage-transition mutation;
- no Stage 12 -> 13 / `editing_pending`;
- no UI, route or server-function implementation;
- no remote Supabase operation;
- no Production migration, deployment or release.

Implementation is fully validated locally, committed and pushed.

Governance closeout `6527abb047ba003e9a253f5598ce018d9697b35a` is confirmed on `origin/architecture-rebuild`.

Implementation `80822a81a087fb0225338466b077ec0e01ce4bd5` and governance closeout `6527abb047ba003e9a253f5598ce018d9697b35a` were independently confirmed at local/remote divergence `0 0` before this reconciliation edit.

Remote-state reconciliation is recorded by this two-document checkpoint.

Remote Supabase remains HOLD.

Production remains HOLD.


## Sprint 11 Slice 10 Technical Design Freeze — 2026-08-26

### Checkpoint

**Sprint 11 Slice 10 — Current Full-Balance Settlement Read Authority Foundation**

Exact baseline:

`18f42662a2d89760ba20e51683b43723fdabce20` — `docs: reconcile sprint 11 slice 9 remote state`

Remote Supabase remains HOLD.

Production remains HOLD.

### Discovery conclusion

Post-Slice-9 read-only discovery establishes:

- `booking_payment_requirements` remains the immutable accepted-booking principal authority;
- `booking_selection_reconciliations` establishes whether finalized selection excess is exactly zero or positive;
- `booking_adjusted_financial_obligations` exists only for positive excess and carries the exact immutable adjusted booking total;
- no current settlement, amount-due, balance-due, overpayment, refund-due or paid-in-full field/relation exists;
- `booking_payments` is a generic positive-INR whole-booking collection ledger;
- payment recording is intentionally uncapped and does not inspect required advance, accepted total or adjusted total;
- `booking_payment_reversals` reverses an exact whole payment and permits at most one reversal per payment;
- existing `get_booking_payment_summary(uuid)` already derives valid non-reversed collections, but compares them only against `required_advance_inr`;
- existing payment summary does not read the Slice 9 adjusted obligation and does not derive full settlement, overpayment or refund semantics;
- Stage 12 `selection_pending` and Stage 13 `editing_pending` are both active;
- no current function references `editing_pending`;
- therefore no Stage 12 -> 13 implementation exists;
- canonical permission totals remain 68 permissions / 241 role-permission mappings.

### Founder policy decision

Current full-balance satisfaction follows **coverage settlement**:

`valid_collected_inr >= settlement_target_inr`

is satisfied.

Exact equality is not required.

If collections exceed the target:

- full balance is satisfied;
- outstanding is zero;
- Slice 10 does not label the difference as overpayment;
- Slice 10 does not create `refund_due`;
- Slice 10 does not initiate a refund workflow.

A later payment reversal may make the current full-balance summary unsatisfied.

A future historical journey transition must not be silently rolled back merely because a later reversal changes the current financial position.

That historical-transition rule is frozen as forward policy only; Slice 10 itself creates no journey transition.

### Design conclusion

Slice 10 creates a deterministic **current-state read authority only**.

It does not create a persistent settlement row.

It does not create an immutable settlement event.

It does not mutate payment evidence.

It does not mutate the adjusted obligation.

It does not advance Stage 12 -> 13.

### Canonical RPC

Introduce:

`public.get_booking_full_balance_summary(uuid)`

Input:

- booking id only.

Canonical result fields:

- `booking_id uuid`;
- `source_quotation_id uuid`;
- `source_payment_requirement_id uuid`;
- `source_reconciliation_id uuid`;
- `source_adjusted_obligation_id uuid` nullable;
- `excess_image_count integer`;
- `currency text`;
- `settlement_target_inr bigint`;
- `target_rule text`;
- `valid_collected_inr bigint`;
- `collection_rule text`;
- `full_balance_outstanding_inr bigint`;
- `full_balance_satisfied boolean`;
- `payment_count bigint`;
- `reversal_count bigint`.

No free text or arbitrary JSON output is required.

### Exact settlement-target authority

The canonical target rule is:

`reconciled_accepted_or_adjusted_total_v1`

The RPC must first require exactly one canonical Slice 7 reconciliation for the booking.

Absence of a Slice 9 adjusted-obligation row must never by itself imply that the accepted quotation total is the settlement target.

#### Zero-excess branch

If:

`booking_selection_reconciliations.excess_image_count = 0`

then:

`settlement_target_inr =
 booking_payment_requirements.accepted_quotation_total_inr`

Requirements:

- exactly one canonical payment requirement;
- same organization + booking;
- exact booking source quotation;
- INR;
- positive accepted quotation total;
- exact canonical reconciliation;
- reconciliation uses the exact same source quotation;
- no Slice 9 adjusted-obligation row may exist for that booking.

If a zero-excess reconciliation and adjusted-obligation row coexist, fail closed as inconsistent authority.

`source_adjusted_obligation_id` is NULL.

#### Positive-excess branch

If:

`booking_selection_reconciliations.excess_image_count > 0`

then exactly one canonical Slice 9 adjusted obligation is required.

The target is:

`settlement_target_inr =
 booking_adjusted_financial_obligations.adjusted_total_inr`

The obligation must match exactly:

- organization;
- booking;
- source payment requirement;
- source quotation;
- source reconciliation;
- accepted quotation total snapshot;
- excess-image-count snapshot;
- INR;
- canonical Slice 9 calculation rule
  `accepted_quote_plus_excess_image_charge_v1`.

Missing, duplicate or inconsistent adjusted-obligation authority fails closed.

`source_adjusted_obligation_id` is the exact Slice 9 row id.

### Canonical collection authority

The collection rule is:

`non_reversed_booking_payments_v1`

Current valid collections are:

`SUM(booking_payments.amount_inr WHERE no canonical reversal exists)`

with zero when no valid payments exist.

A reversed payment contributes zero to current valid collections.

Because each payment may have at most one canonical reversal, no partial-reversal arithmetic is introduced.

`payment_count` is the total number of booking payment rows.

`reversal_count` is the total number of canonical booking payment reversal rows.

Slice 10 does not reinterpret payment method, external reference or note content.

### Canonical balance calculation

Use `bigint` arithmetic.

`full_balance_outstanding_inr =
 GREATEST(settlement_target_inr - valid_collected_inr, 0)`

`full_balance_satisfied =
 valid_collected_inr >= settlement_target_inr`

Examples:

- target 10,000 / collected 8,000 -> outstanding 2,000 / not satisfied;
- target 10,000 / collected 10,000 -> outstanding 0 / satisfied;
- target 10,000 / collected 12,000 -> outstanding 0 / satisfied.

The extra 2,000 in the third example receives no refund or overpayment business classification in Slice 10.

### Reversal semantics

The RPC always computes current state from current non-reversed payment evidence.

Therefore a later reversal can change:

- `valid_collected_inr`;
- `full_balance_outstanding_inr`;
- `full_balance_satisfied`;
- payment/reversal counts.

No historical row is rewritten because Slice 10 persists no settlement state.

A later separately governed Stage 12 -> 13 transition may snapshot or reference satisfaction at transition time, but a later reversal must not automatically delete or reverse that historical transition.

### Authorization

No new permission is introduced.

No role-permission mapping changes are introduced.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

The aggregate full-balance summary requires existing:

`finance.read`

plus booking branch scope.

Current `finance.read` grant topology remains unchanged:

- Accounts;
- Founder;
- Sales;
- Studio Manager.

This is intentionally an aggregate finance-read surface.

It does not grant those roles raw `booking_payments` or `booking_payment_reversals` table access.

Existing raw payment-ledger access and existing `get_booking_payment_summary(uuid)` authorization remain unchanged.

### RPC security

The RPC must:

- reject null booking id;
- require authenticated actor;
- require active organization membership;
- require `finance.read`;
- require booking branch scope;
- be `SECURITY DEFINER`;
- use `SET search_path = ''`;
- be executable by `authenticated`;
- be unavailable to PUBLIC;
- be unavailable to `anon`;
- be unavailable to `service_role`.

No service-role application path is introduced.

### Current-state behavior

The RPC is not restricted to current Stage 12.

It derives financial current state from canonical immutable commercial/selection authorities plus current payment/reversal evidence.

This is deliberate so the same read authority can remain meaningful after later journey progression.

Slice 10 must not inspect or mutate the current journey state to determine settlement.

### No persistence / no audit mutation

Slice 10 introduces no settlement table.

It introduces no settlement-status column.

It appends no audit event merely for reading the summary.

It creates no payment or reversal row.

It creates no obligation row.

It changes no existing source authority.

### Frozen implementation boundary

Exactly three implementation artifacts are authorized after a separate implementation-authorization checkpoint:

1. one new migration whose filename ends in `sprint11_full_balance_settlement_read_authority_foundation.sql`;
2. `supabase/tests/sprint11_full_balance_settlement_read_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is authorized without governance amendment.

No application route, server-function file or UI is authorized.

No new permission migration is authorized.

No compatibility/regression test modification is pre-authorized.

### Explicit exclusions

Slice 10 does not implement or modify:

- payment recording;
- payment reversal;
- payment caps;
- partial reversals;
- accepted quotation;
- quotation line items;
- booking payment requirement;
- selection confirmation;
- selection reconciliation;
- additional-image pricing basis;
- adjusted financial obligation;
- settlement persistence;
- settlement-history rows;
- invoice workflow;
- receipt workflow;
- caller-entered financial adjustment;
- overpayment business classification;
- refund-due calculation;
- refund workflow;
- credit-note workflow;
- Stage 12 -> 13 / `editing_pending`;
- any journey transition;
- editing;
- QC;
- delivery;
- Pixieset;
- privacy/consent;
- application routes/UI;
- remote Supabase;
- Production migration/deployment/release.

### Validation contract

Implementation acceptance requires:

- exact three-artifact implementation boundary;
- exact `get_booking_full_balance_summary(uuid)` result shape;
- exact `reconciled_accepted_or_adjusted_total_v1` target rule;
- exact `non_reversed_booking_payments_v1` collection rule;
- exact payment-requirement provenance;
- exact reconciliation provenance;
- zero-excess accepted-total target;
- zero-excess adjusted-obligation coexistence fails closed;
- positive-excess exact adjusted-obligation requirement;
- positive-excess missing obligation fails closed;
- exact adjusted-obligation lineage validation;
- INR-only target and collections;
- zero-payment behavior;
- multiple-payment aggregation;
- reversed payments excluded completely;
- payment/reversal counts exact;
- under-target calculation;
- exact-target calculation;
- over-target coverage satisfaction;
- no refund or overpayment classification;
- later reversal changes current summary deterministically;
- no persistent settlement row;
- no audit mutation for reads;
- no payment/reversal mutation;
- no obligation mutation;
- no journey-state mutation;
- no Stage 12 -> 13 transition;
- no current-stage dependency;
- authenticated `finance.read` authorization;
- booking branch containment;
- raw payment-ledger permissions unchanged;
- PUBLIC / anon / service_role execution denied;
- no new permission;
- permission totals remain 68 / 241;
- clean local database reset;
- dedicated Slice 10 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- freshly generated local Supabase types with narrow semantic diff;
- generated-type Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

Implementation is not yet authorized.

Remote Supabase remains HOLD.

Production remains HOLD.


## Sprint 11 Slice 10 Governance Closeout — 2026-08-26

### Checkpoint

**Sprint 11 Slice 10 — Current Full-Balance Settlement Read Authority Foundation**

Technical-design freeze:

`ef6874576643ea6df107e3dc14e5366f1f2aed9a` — `docs: freeze sprint 11 slice 10`

Implementation:

`a058a36827eed5c9b4a1388109760082bcad5f48` — `feat: add full-balance settlement read authority`

Implementation parent:

`ef6874576643ea6df107e3dc14e5366f1f2aed9a`

### Delivered authority

Slice 10 introduces exactly one canonical aggregate read RPC:

`public.get_booking_full_balance_summary(uuid)`

The target authority is selected from the exact finalized reconciliation:

- zero excess -> immutable accepted quotation total from `booking_payment_requirements`;
- positive excess -> exact immutable Slice 9 `booking_adjusted_financial_obligations.adjusted_total_inr`.

Absence of an adjusted-obligation row alone never implies zero excess.

Canonical target rule:

`reconciled_accepted_or_adjusted_total_v1`

Canonical collection rule:

`non_reversed_booking_payments_v1`

Current valid collections are the sum of non-reversed booking payment amounts.

Current full-balance satisfaction uses coverage settlement:

`valid_collected_inr >= settlement_target_inr`

Collections above target satisfy the current balance without creating overpayment or refund-due business semantics.

### Security and containment

- existing `finance.read` is reused;
- booking branch scope is required;
- permission catalogue remains 68;
- role-permission mappings remain 241;
- authenticated execution is allowed;
- PUBLIC / anon / service_role execution remains denied;
- raw payment-ledger access is not broadened;
- no persistent settlement relation is created;
- no audit write occurs merely for reading;
- no payment/reversal evidence is mutated;
- no adjusted obligation is mutated;
- no current-stage dependency is introduced;
- no Stage 12 -> 13 transition is introduced.

### Validation

- dedicated pgTAP: 60 / 60 PASS;
- full pgTAP: 27 files / 1750 tests PASS;
- clean local reset: PASS;
- local DB lint: PASS;
- generated local Supabase types: PASS;
- generated-type Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS;
- diff/file hygiene: PASS.

### Exact implementation boundary

1. `supabase/migrations/20260826020000_sprint11_full_balance_settlement_read_authority_foundation.sql`;
2. `supabase/tests/sprint11_full_balance_settlement_read_authority_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact was introduced.

### Closeout state

**SPRINT 11 SLICE 10 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / NOT YET PUSHED / PRODUCTION HOLD**

Remote Supabase remains HOLD.

Production remains HOLD.



## Sprint 11 Slice 10 Remote-State Reconciliation — 2026-08-26

### Checkpoint

**Sprint 11 Slice 10 — Current Full-Balance Settlement Read Authority Foundation**

Technical-design freeze:

`ef6874576643ea6df107e3dc14e5366f1f2aed9a` — `docs: freeze sprint 11 slice 10`

Implementation:

`a058a36827eed5c9b4a1388109760082bcad5f48` — `feat: add full-balance settlement read authority`

Governance closeout:

`e481d1a70640913362953a4970e445755352e408` — `docs: close sprint 11 slice 10`

Exact pushed chain:

`e481d1a70640913362953a4970e445755352e408`
-> `a058a36827eed5c9b4a1388109760082bcad5f48`
-> `ef6874576643ea6df107e3dc14e5366f1f2aed9a`

Independent GitHub verification confirms:

- `origin/architecture-rebuild` is exactly `e481d1a70640913362953a4970e445755352e408`;
- the closeout parent is exactly `a058a36827eed5c9b4a1388109760082bcad5f48`;
- the implementation commit is present with the exact subject `feat: add full-balance settlement read authority`;
- the closeout commit is present with the exact subject `docs: close sprint 11 slice 10`;
- the implementation contains the frozen Slice 10 RPC/types/migration/test authority;
- local and remote parity was confirmed at `0 0` before this reconciliation edit.

Slice 10 is therefore implemented, fully validated locally, committed, governance closed, pushed and remotely reconciled.

The delivered authority remains a deterministic current-state full-balance read only.

It does not introduce:

- persistent settlement evidence;
- overpayment or refund-due classification;
- payment or reversal mutation;
- Stage 12 -> 13 / `editing_pending`;
- any production or remote-Supabase deployment.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 10 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**


## Immediate Product Sequence

1. perform fresh read-only discovery for the Stage 12 -> 13 / `editing_pending` transition boundary;
2. do not name or freeze that next slice until discovery establishes the exact evidence, authorization and transition contract;
3. keep refund/overpayment workflow and historical settlement-event persistence separately governed unless later evidence proves they are required;
4. keep Remote Supabase and Production on HOLD.

Slice 10 remains a current-state read authority only. It does not itself authorize a Stage 12 -> 13 transition, persistent settlement evidence, refund obligation or payment mutation.

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
