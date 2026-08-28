# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released.

Sprint 11 (Shoot Completion & Post-Session Handoff) is the active programme. Sprint 11 Slices 1 through 15 are implemented, fully validated locally, committed, governance closed, pushed and independently verified on `origin/architecture-rebuild`. Slice 15 technical-design freeze is `0e6accc7dc3bd69c80becd3e4db626a688b0d971` — `docs: freeze sprint 11 slice 15`; implementation is `67746d3063c5f029c374d3700f2dd94d65d51756` — `feat: add qc pending advancement gate`; governance closeout is `e4863b00c0b1c59a191d6b0afb762f980603bb29` — `docs: close sprint 11 slice 15`; remote-state reconciliation is `83692ed04a22ef8bf1a2e1a9336e4f043d5a3266` — `docs: reconcile sprint 11 slice 15 remote state`. Slice 16 is the active technical-design checkpoint and remains unimplemented. Remote Supabase remains HOLD. Production remains HOLD.

## Current Verified Checkpoint

Sprint 11 Slice 15 — **Controlled Stage 14 -> 15 / QC Pending Advancement Gate** — is implemented, fully validated locally, committed, governance closed, pushed and remotely reconciled.

Exact authority chain:

- technical-design freeze `0e6accc7dc3bd69c80becd3e4db626a688b0d971`;
- implementation `67746d3063c5f029c374d3700f2dd94d65d51756`;
- governance closeout `e4863b00c0b1c59a191d6b0afb762f980603bb29`;
- remote-state reconciliation `83692ed04a22ef8bf1a2e1a9336e4f043d5a3266`.

Accepted Slice 15 validation:

- clean local database reset PASS;
- local DB lint PASS;
- dedicated Slice 15 pgTAP 38 / 38 PASS;
- Slice 11 compatibility 59 / 59 PASS;
- Slice 12 compatibility 63 / 63 PASS;
- Slice 13 compatibility 53 / 53 PASS;
- Slice 14 compatibility 42 / 42 PASS unchanged;
- full local pgTAP regression 32 files / 2005 tests PASS;
- permissions 68;
- role-permission mappings 241;
- exact `public.mark_booking_qc_pending(uuid)` authority;
- exact Stage 14 `editing_in_progress` -> Stage 15 `qc_pending`;
- no Stage 15 -> 16 authority.

Remote Supabase remains HOLD.

Production remains HOLD.

### Prior remotely reconciled Slice 14 checkpoint

Sprint 11 Slice 14 — **Editing Completion Evidence Foundation** — is implemented, fully validated locally, committed, governance closed, pushed and independently verified on `origin/architecture-rebuild`. Governance closeout `473428daf3036b14584ebbfe8e69fa2a5d48b6b6` — `docs: close sprint 11 slice 14` is independently confirmed with exact parent `a2d4f4f4462a715d75add6b9e0ebb286d0b5f336`. This two-document checkpoint records the reconciled remote state.

Exact authority chain:

- technical-design freeze `f367973df24edca781c95695dbb93db7538e157f` — `docs: freeze sprint 11 slice 14`;
- implementation `a2d4f4f4462a715d75add6b9e0ebb286d0b5f336` — `feat: add editing completion evidence foundation`.

The implementation is independently confirmed on `origin/architecture-rebuild` with exact parent `f367973df24edca781c95695dbb93db7538e157f`.

Freeze -> implementation is exactly one commit ahead / zero behind.

Accepted validation:

- dedicated Slice 14 pgTAP: 42 / 42 PASS;
- full local pgTAP regression: 31 files / 1967 tests PASS;
- clean local database reset: PASS;
- local database lint: PASS with no schema errors;
- Slice 11 compatibility: PASS;
- Slice 12 compatibility: PASS;
- Slice 13 compatibility: PASS;
- permissions: 68;
- role-permission mappings: 241;
- structural fingerprint: `68:241:1:1:6`;
- exact six-column `public.booking_editing_completions` relation validated;
- exact RPC `public.record_booking_editing_completion(uuid)` validated;
- generated Supabase types freshly regenerated from the clean local database;
- generated-types semantic delta limited to `booking_editing_completions` and `record_booking_editing_completion`;
- generated-types diff: 66 insertions / 0 deletions;
- Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS;
- `git diff --check`: PASS.

Exact implementation boundary:

1. `src/integrations/supabase/types.ts` — 66 insertions / 0 deletions;
2. `supabase/migrations/20260827150000_sprint11_editing_completion_evidence_foundation.sql`
   — 926 insertions / 0 deletions;
3. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
   — 1520 insertions / 0 deletions;
4. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   — 5 insertions / 2 deletions;
5. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`
   — 4 insertions / 1 deletion;
6. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   — 8 insertions / 2 deletions.

Total implementation diff:

- 6 files;
- 2529 insertions;
- 5 deletions.

Slice 14 establishes immutable editing-domain completion evidence while the booking remains exactly at Stage 14 `editing_in_progress`.

It does not advance the booking journey to Stage 15.

The governance closeout is now committed and pushed, and is independently verified on
`origin/architecture-rebuild` at `473428daf3036b14584ebbfe8e69fa2a5d48b6b6`.

Remote Supabase remains HOLD.

Production remains HOLD.

### Prior remotely reconciled Slice 13 checkpoint

Sprint 11 Slice 13 — **Controlled Stage 13 -> 14 / Editing In Progress Advancement Gate** — is implemented, fully validated locally, committed, governance closed, pushed and independently verified on `origin/architecture-rebuild`. Governance closeout `a911c6f1c2c2f85e69b9df347dad8650fd25f5db` — `docs: close sprint 11 slice 13` is independently confirmed with exact parent `597f8de641fd3a73426061b9ecc793922be43354`. This two-document checkpoint records the reconciled remote state.

Exact authority chain:

- technical-design freeze `efef811dfebec9b49c784ce96bdda4c4ade54e78` — `docs: freeze sprint 11 slice 13`;
- implementation `597f8de641fd3a73426061b9ecc793922be43354` — `feat: add editing in progress advancement gate`.

Accepted validation:

- clean local database reset: PASS;
- local database lint: PASS with no schema errors;
- Slice 12 compatibility pgTAP: 63 / 63 PASS;
- Slice 13 dedicated pgTAP: 53 / 53 PASS;
- full local pgTAP regression: 30 files / 1925 tests PASS;
- permissions: 68;
- role-permission mappings: 241;
- canonical post-regression residue:
  `68:241:0:0:0:0:0:0:0:0`;
- generated Supabase type delta: exactly
  `mark_booking_editing_in_progress`;
- Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS.

Exact implementation boundary:

1. `src/integrations/supabase/types.ts` — 22 insertions;
2. `supabase/migrations/20260827140000_sprint11_stage13_14_editing_in_progress_gate_foundation.sql`
   — 914 insertions;
3. `supabase/tests/sprint11_editing_start_evidence_test.sql` — 2 insertions;
4. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   — 1754 insertions.

Total implementation diff: 2692 insertions / 0 deletions.

The governance closeout is now committed and pushed, and is independently verified on
`origin/architecture-rebuild` at `a911c6f1c2c2f85e69b9df347dad8650fd25f5db`.

Remote Supabase remains HOLD.

Production remains HOLD.

### Prior remotely reconciled Slice 12 checkpoint

Sprint 11 Slice 12 — **Editing Start Evidence Foundation** is implemented, fully validated locally, committed, governance closed, pushed and independently verified on the remote branch. Governance closeout `7250e920d46c4a2819c82b6136e349ef65310806` — `docs: close sprint 11 slice 12` is independently confirmed on `origin/architecture-rebuild`, with exact parent `c5b51ab7001443b2adc0eaa7a9728a9b20b33870`. This two-document checkpoint records the reconciled remote state.

Exact implementation artifacts:

1. `supabase/migrations/20260827130000_sprint11_editing_start_evidence_foundation.sql`;
2. `supabase/tests/sprint11_editing_start_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`.

Exact implementation diff:

- generated Supabase types: 66 insertions;
- editing-start migration: 851 insertions;
- dedicated Slice 12 pgTAP: 1965 insertions;
- authorized Slice 11 compatibility hardening: 8 insertions;
- total: 2890 insertions / 0 deletions.

Validation evidence:

- clean local database reset: PASS;
- local DB lint: PASS with no schema errors;
- Slice 11 compatibility pgTAP: 59 / 59 PASS;
- dedicated Slice 12 pgTAP: 63 / 63 PASS;
- full local pgTAP regression: 29 files / 1872 tests PASS;
- canonical permissions: 68;
- canonical role-permission mappings: 241;
- canonical post-regression residue: `68:241:0:0:0:0:0:0:0`;
- exact six-column `public.booking_editing_starts` relation validated;
- row immutability validated;
- RLS enabled and forced;
- authenticated SELECT remains governed by existing `editing.read` plus branch scope;
- direct authenticated table mutation unavailable;
- exact RPC `public.record_booking_editing_start(uuid)` validated;
- return type `public.booking_editing_starts`;
- SECURITY DEFINER with empty search path;
- authenticated EXECUTE allowed;
- PUBLIC / anon / service_role EXECUTE denied;
- existing `editing.write` remains the mutation authority;
- Editor / Founder / Studio Manager remain the exact editing-write roles;
- Client Coordinator rejected despite `booking.stage.advance`;
- exact Stage 13 `editing_pending` containment validated;
- exact Stage 12 -> 13 source transition lineage validated;
- source transition id is snapshotted;
- server-authoritative `started_at` validated;
- strict idempotent replay validated;
- one first-success `booking.editing_started` non-sensitive audit validated;
- no second row or audit on replay;
- no booking-stage transition created;
- journey stage/version remains unchanged;
- no Stage 13 -> 14 authority introduced;
- no selection/reconciliation/financial/payment authority imported;
- no editor assignment introduced;
- no priority-editing SLA introduced;
- no QC/Pixieset/delivery authority introduced;
- historical Slice 11 compatibility assertion hardened only by relation-kind filtering and exact `booking_editing_starts` exclusion;
- generated types are deterministic fresh local generation;
- generated-types semantic delta is exactly `booking_editing_starts` plus `record_booking_editing_start`;
- generated-types Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS with pre-existing non-blocking TanStack/Nitro/Rollup/Wrangler/bundle warnings only;
- final implementation diff hygiene PASS;
- exact amended four-artifact implementation boundary retained;
- implementation commit worktree clean;
- implementation push landed at the exact SHA;
- post-push local/remote parity `0 0`;
- implementation independently verified on the remote branch.

Slice 12 therefore establishes immutable editing-start evidence at canonical Stage 13 under `editing.write` only.

It does not implement:

- Stage 13 -> 14 / `editing_in_progress`;
- mutable editing-job workflow;
- editor assignment;
- editing SLA/deadline;
- priority-editing state;
- retouching/QC;
- Pixieset/gallery;
- delivery;
- payment/refund mutation;
- UI/runtime integration;
- Remote Supabase deployment;
- Production deployment.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 12 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

### Previous verified checkpoint — Sprint 11 Slice 11

Sprint 11 Slice 11 — **Controlled Stage 12 -> 13 / Editing Pending Advancement Gate** is implemented, fully validated locally, committed, governance closed, pushed and independently verified on the remote branch. Governance closeout `e9d355238915f99a8f08f912282b1ece9ad90f0e` — `docs: close sprint 11 slice 11` is independently confirmed on `origin/architecture-rebuild`. This two-document checkpoint records the reconciled remote state.

Technical-design freeze:

`fd321e570f128e92777d662836c0b4b206012fa3` — `docs: freeze sprint 11 slice 11`

Implementation:

`1486c36c8b13e228a0bca9b498ec6f9ea51fb958` — `feat: add editing pending advancement gate`

Implementation parent:

`fd321e570f128e92777d662836c0b4b206012fa3`

Exact implementation artifacts:

1. `supabase/migrations/20260826030000_sprint11_stage12_13_editing_pending_gate_foundation.sql`;
2. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`;
3. `src/integrations/supabase/types.ts`.

Implementation diff:

- generated Supabase types: 22 insertions;
- migration: 993 insertions;
- dedicated pgTAP: 1822 insertions;
- total implementation commit: 2837 insertions / 0 deletions.

Validation evidence:

- clean local database reset: PASS;
- local database lint: PASS with no schema errors;
- dedicated Slice 11 pgTAP: 59 / 59 PASS;
- full local pgTAP regression: 28 files / 1809 tests PASS;
- canonical permission count: 68;
- canonical role-permission mapping count: 241;
- post-regression Slice 11 authority residue: zero;
- exact RPC `public.mark_booking_editing_pending(uuid)` present;
- return type `public.bookings` validated;
- `SECURITY DEFINER` with empty search path validated;
- authenticated execution allowed;
- PUBLIC execution denied;
- anon execution denied;
- service_role execution denied;
- existing `booking.stage.advance` remains the journey-transition authority;
- Client Coordinator / Founder / Studio Manager remain the exact Stage-advance roles;
- Editor remains rejected despite `editing.write`;
- Client Coordinator remains eligible without `editing.write` or `finance.read`;
- booking branch containment validated;
- exact Stage 12 `selection_pending` first-execution boundary validated;
- exact Stage 11 -> 12 `selection_pending` history prerequisite validated;
- exact immutable selection-confirmation prerequisite validated;
- exact immutable selection-reconciliation lineage validated;
- zero-excess accepted-total settlement target validated;
- zero-excess adjusted-obligation conflict fails closed;
- positive excess requires exact adjusted financial obligation;
- corrupt adjusted-obligation lineage fails closed;
- non-reversed payment collection rule validated;
- under-target collection rejected;
- exact-target collection accepted;
- over-target collection accepted without refund/overpayment semantics;
- successful first execution appends exactly one Stage 12 -> 13 `editing_pending` transition;
- journey version increments exactly once;
- first execution creates exactly one non-sensitive `booking.editing_pending` audit event;
- transition audit exposes no financial amount/payment/refund semantics;
- strict Stage 13 replay creates no second transition, audit or journey mutation;
- payment reversal after historical advancement can make current Slice 10 summary unsatisfied without rewinding Stage 13;
- Stage 13 replay after that reversal does not re-evaluate current full-balance satisfaction;
- later Stage 14 progression is not accepted as Slice 11 replay;
- no payment or reversal mutation by the gate;
- no selection/reconciliation/adjusted-obligation mutation by the gate;
- no settlement persistence;
- no refund-due persistence;
- no editing-job persistence;
- no Stage 13 -> 14 implementation;
- no new permission or role grant;
- freshly generated local Supabase types exactly equal the checked types under the repository Prettier configuration;
- generated-types semantic diff is exactly one Slice 11 RPC block;
- generated-types Prettier: PASS;
- targeted generated-types ESLint: PASS;
- TypeScript `--noEmit`: PASS;
- production build: PASS with pre-existing non-blocking TanStack/Nitro/Wrangler/bundle warnings only;
- SQL/file hygiene and `git diff --check`: PASS;
- implementation commit contains exactly the three frozen artifacts;
- post-implementation-commit worktree: clean;
- implementation push landed at the exact SHA;
- post-push local/remote parity: `0 0`.

Slice 11 therefore establishes only the controlled journey gate from Stage 12 `selection_pending` to Stage 13 `editing_pending`.

It does not introduce:

- editing-job creation;
- editor assignment;
- Stage 13 -> 14 / `editing_in_progress`;
- retouching or QC workflow;
- delivery or Pixieset authority;
- persistent settlement state;
- refund or overpayment workflow;
- remote-Supabase deployment;
- Production deployment.

The implementation and governance closeout are pushed and independently verified. The exact remote closeout is `e9d355238915f99a8f08f912282b1ece9ad90f0e` — `docs: close sprint 11 slice 11`, with exact parent `1486c36c8b13e228a0bca9b498ec6f9ea51fb958`. This checkpoint records the reconciled remote state.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 11 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

### Previous verified checkpoint — Sprint 11 Slice 10

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



## Sprint 11 Slice 11 Technical Design Freeze — 2026-08-26

### Checkpoint

**Sprint 11 Slice 11 — Controlled Stage 12 -> 13 / Editing Pending Advancement Gate**

Exact baseline:

`2c08d7aab5f5003098d2042d69316c0d2a4a631f` — `docs: reconcile sprint 11 slice 10 remote state`

Remote Supabase remains HOLD.

Production remains HOLD.

### Discovery conclusion

Read-only discovery establishes:

- Stage 12 is active `selection_pending`;
- Stage 13 is active `editing_pending`;
- no existing public function implements or can create Stage 13;
- no existing Stage 13 transition authority exists;
- finalized selection confirmation and reconciliation are immutable canonical evidence;
- current full-balance authority is Slice 10 `get_booking_full_balance_summary(uuid)`;
- all mutable selection, obligation, payment and reversal operations serialize through the booking row with `FOR UPDATE`;
- `booking.stage.advance` is the canonical 21-stage journey-transition permission;
- `editing.write` is an editing-job permission, not a booking-journey transition permission;
- existing pgTAP precedent explicitly rejects an Editor attempting journey advancement through `editing.write`;
- `finance.read` is an aggregate financial-read permission and must not be silently imported into journey advancement;
- Stage 7 -> 8 precedent already proves that a controlled journey transition may evaluate protected financial evidence internally without requiring the caller to hold the corresponding payment-read permission;
- canonical permission totals remain 68 permissions / 241 role-permission mappings.

### Authorization decision

Slice 11 requires existing:

`booking.stage.advance`

plus booking branch scope.

Current Stage-advance roles remain:

- Client Coordinator;
- Founder;
- Studio Manager.

No new permission is introduced.

No role-permission grant is changed.

Slice 11 does not require:

- `editing.read`;
- `editing.write`;
- `finance.read`;
- `finance.write`;
- `payment.read`;
- `payment.record`;
- `payment.reverse`.

An Editor holding `editing.write` but lacking `booking.stage.advance` must be rejected.

A Client Coordinator holding `booking.stage.advance` but lacking `editing.write` and `finance.read` remains eligible to perform the transition when all canonical evidence and the internal full-balance predicate are satisfied.

### Canonical RPC

Introduce exactly one browser-callable mutation RPC:

`public.mark_booking_editing_pending(uuid)`

Input:

- booking id only.

Return:

`public.bookings`

The function must be `SECURITY DEFINER` with:

`SET search_path = ''`

Execution boundary:

- authenticated: allowed;
- PUBLIC: denied;
- anon: denied;
- service_role: denied.

### Synchronization boundary

The booking row is the synchronization root.

The function must lock the canonical booking with `FOR UPDATE` before evaluating mutable financial evidence.

This lock is required before reading:

- current journey state;
- current payment evidence;
- current reversal evidence.

Existing selection confirmation, reconciliation, pricing-basis, adjusted-obligation, payment-record and payment-reversal mutation paths already serialize on the same booking row.

Therefore the Stage 12 -> 13 financial decision is transactionally stable against concurrent canonical mutation.

### First-execution stage containment

First execution is allowed only when the booking is exactly:

Stage 12 / `selection_pending`.

The function must require exactly one current canonical journey state.

It must require exact canonical Stage 11 -> 12 transition lineage:

- source Stage 11 / `shoot_completed`;
- destination Stage 12 / `selection_pending`;
- transition key `selection_pending`.

Any other current stage must fail closed except the strict Stage 13 replay defined below.

### Selection evidence prerequisite

First execution requires exactly one immutable:

`booking_selection_confirmations`

row for the same organization and booking.

First execution also requires exactly one immutable:

`booking_selection_reconciliations`

row for the same organization and booking.

The reconciliation must retain exact canonical lineage to:

- the booking source quotation;
- the selection confirmation;
- the frozen calculation rule
  `accepted_quote_version_entitlement_v1`.

The gate does not create, repair or modify selection evidence.

### Internal full-balance predicate

The gate must NOT require the caller to execute or possess authorization for the public:

`get_booking_full_balance_summary(uuid)`

because that public read surface intentionally requires `finance.read`.

Instead, while holding the booking synchronization lock, the gate must evaluate the exact same frozen Slice 10 settlement semantics internally.

Canonical target rule:

`reconciled_accepted_or_adjusted_total_v1`

Canonical collection rule:

`non_reversed_booking_payments_v1`

#### Zero-excess branch

If:

`booking_selection_reconciliations.excess_image_count = 0`

then the settlement target is exactly:

`booking_payment_requirements.accepted_quotation_total_inr`

Requirements include:

- exact canonical payment requirement;
- exact booking source quotation;
- INR;
- positive accepted quotation total;
- exact canonical reconciliation;
- no adjusted financial obligation may coexist.

A zero-excess reconciliation with an adjusted-obligation row fails closed.

#### Positive-excess branch

If:

`booking_selection_reconciliations.excess_image_count > 0`

then exactly one canonical:

`booking_adjusted_financial_obligations`

row is required.

The settlement target is exactly:

`booking_adjusted_financial_obligations.adjusted_total_inr`

The obligation must match the Slice 10 lineage contract, including:

- organization;
- booking;
- source payment requirement;
- source quotation;
- source reconciliation;
- accepted-total snapshot;
- excess-image-count snapshot;
- INR;
- calculation rule
  `accepted_quote_plus_excess_image_charge_v1`.

Missing or inconsistent positive-excess obligation authority fails closed.

### Current collection rule

Current valid collection is:

`SUM(booking_payments.amount_inr WHERE no canonical reversal exists)`

using bigint arithmetic and zero when no valid payments exist.

A reversed payment contributes zero.

The gate condition is:

`valid_collected_inr >= settlement_target_inr`

Exact equality is not required.

Collections above target satisfy the gate but create no:

- overpayment classification;
- refund-due state;
- refund workflow.

If the predicate is false, Stage 12 -> 13 must not occur.

### Canonical transition

First successful execution appends exactly one transition:

Stage 12 `selection_pending`
->
Stage 13 `editing_pending`

with:

`transition_key = 'editing_pending'`

It then advances the one canonical `booking_journey_states` row using exact current-stage and version containment.

No generic journey-advance API is introduced.

No Stage 13 -> 14 transition is introduced.

### Strict Stage 13 replay

If the booking is exactly Stage 13 / `editing_pending`, replay is allowed only when exactly one canonical historical Stage 12 -> 13 `editing_pending` transition exists.

Replay performs no new:

- transition;
- journey-state mutation;
- audit event;
- financial mutation.

Critically, replay must not re-evaluate current full-balance satisfaction.

A payment reversal recorded after the historical Stage 12 -> 13 transition may make the current Slice 10 financial summary unsatisfied, but must never automatically rewind or invalidate the historical journey transition.

Calls after later journey progression are not Slice 11 replay and must fail the operation-stage boundary.

### Audit

First successful advancement appends one structural non-sensitive audit event:

`booking.editing_pending`

The audit may record:

- booking id;
- transition key;
- prior and resulting journey stage;
- prior and resulting journey version;
- canonical selection/reconciliation evidence identifiers.

The audit must not expose:

- settlement target amount;
- collected amount;
- payment references;
- payment methods;
- payment notes;
- refund or overpayment semantics.

### Editing-domain containment

Slice 11 does not create an editing job.

It does not modify the current mock editing tracker.

It does not consume `editing.write` as journey authority.

It does not implement:

- editor assignment;
- editing-job creation;
- Stage 13 -> 14 / `editing_in_progress`;
- retouching workflow;
- QC;
- delivery;
- Pixieset.

Those remain separately governed downstream editing-domain work.

### Frozen implementation boundary

Exactly three implementation artifacts are authorized only after a separate implementation-authorization checkpoint:

1. one new migration whose filename ends in `sprint11_stage12_13_editing_pending_gate_foundation.sql`;
2. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is authorized without governance amendment.

No application route, server-function file, store file or UI file is authorized.

No new permission migration is authorized.

No compatibility/regression test modification is pre-authorized.

### Validation contract

Implementation acceptance must prove at minimum:

- exact three-artifact implementation boundary;
- exact RPC name/signature/return type;
- authenticated-only execution boundary;
- active membership requirement;
- `booking.stage.advance` requirement;
- branch containment;
- Editor rejected despite `editing.write`;
- Client Coordinator allowed without `editing.write` or `finance.read`;
- Founder allowed;
- Studio Manager allowed;
- exact Stage 12 first-execution containment;
- strict Stage 13 replay;
- later-stage rejection;
- exact Stage 11 -> 12 lineage;
- exact selection-confirmation cardinality;
- exact reconciliation cardinality and lineage;
- zero-excess accepted-total target;
- zero-excess adjusted-obligation coexistence fails closed;
- positive-excess exact adjusted-obligation requirement;
- missing positive-excess obligation fails closed;
- exact adjusted-obligation lineage;
- non-reversed payment aggregation;
- under-target rejection;
- exact-target success;
- over-target success;
- later reversal does not rewind historical Stage 12 -> 13 evidence;
- Stage 13 replay does not re-evaluate the later current shortfall;
- transition key exactly `editing_pending`;
- journey version increments exactly once;
- replay creates no second transition;
- first execution creates one structural audit event;
- replay creates no second audit event;
- no financial amount leakage in the transition audit;
- no payment/reversal mutation;
- no selection/reconciliation mutation;
- no obligation mutation;
- no settlement persistence;
- no editing-job persistence;
- no Stage 13 -> 14 transition;
- no new permission;
- permission totals remain 68 / 241;
- clean local database reset;
- dedicated Slice 11 pgTAP PASS;
- full local pgTAP regression PASS;
- local database lint PASS;
- freshly generated local Supabase types with narrow semantic diff;
- generated-type Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

At the technical-freeze checkpoint implementation was not yet authorized.

Implementation was subsequently authorized only after the freeze was pushed and independently verified.

The exact authorized implementation is now complete:

`1486c36c8b13e228a0bca9b498ec6f9ea51fb958` — `feat: add editing pending advancement gate`

with exact parent:

`fd321e570f128e92777d662836c0b4b206012fa3` — `docs: freeze sprint 11 slice 11`

The implementation passed the complete frozen validation contract and is independently confirmed on `origin/architecture-rebuild`.

Remote Supabase remains HOLD.

Production remains HOLD.


## Immediate Product Sequence

1. governance-commit the Sprint 11 Slice 12 Editing Start Evidence Foundation technical-design freeze as an exact two-document docs-only commit;
2. independently verify the exact freeze commit and remote baseline;
3. push the exact freeze SHA only under separate one-shot authorization;
4. independently verify the pushed freeze on `origin/architecture-rebuild`;
5. authorize implementation only after that remote freeze verification;
6. implement only the frozen immutable editing-start evidence boundary;
7. keep Stage 13 -> 14 / `editing_in_progress`, editor assignment, mutable editing workflow, priority-editing SLA, retouching/QC, Pixieset/delivery and all later journey stages separately governed.

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

## Sprint 11 Slice 11 Governance Closeout — 2026-08-27

### Exact authority

Technical-design freeze:

`fd321e570f128e92777d662836c0b4b206012fa3` — `docs: freeze sprint 11 slice 11`

Implementation:

`1486c36c8b13e228a0bca9b498ec6f9ea51fb958` — `feat: add editing pending advancement gate`

The implementation is independently confirmed on `origin/architecture-rebuild` with exact parent `fd321e570f128e92777d662836c0b4b206012fa3`.

### Delivered boundary

Exactly three implementation artifacts:

1. `supabase/migrations/20260826030000_sprint11_stage12_13_editing_pending_gate_foundation.sql`;
2. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact was introduced.

### Validation closeout

- dedicated Slice 11 pgTAP: 59 / 59 PASS;
- full local pgTAP regression: 28 files / 1809 tests PASS;
- clean local DB reset: PASS;
- local DB lint: PASS;
- permissions: 68;
- role-permission mappings: 241;
- post-regression Slice 11 residue: zero;
- exact authenticated-only RPC ACL validated;
- `booking.stage.advance` authorization and branch containment validated;
- Editor denied through `editing.write`;
- Client Coordinator allowed without `editing.write` or `finance.read`;
- zero/positive excess settlement-target semantics validated;
- under/exact/over collection behavior validated;
- strict Stage 13 replay validated;
- later reversal does not rewind historical Stage 13 entry;
- transition/audit cardinality validated;
- non-sensitive audit boundary validated;
- no payment/reversal/selection/reconciliation/obligation mutation;
- no settlement or refund persistence;
- no editing-job persistence;
- no Stage 13 -> 14 authority;
- generated local types exactly match checked types;
- generated-types diff is exactly the Slice 11 RPC;
- Prettier / targeted ESLint / TypeScript / production build PASS;
- exact three-artifact implementation commit boundary validated;
- implementation push independently verified.

### Governance conclusion

Sprint 11 Slice 11 is implemented and its implementation is remotely verified.

This closeout records that the frozen Stage 12 `selection_pending` -> Stage 13 `editing_pending` advancement gate has been delivered without expanding into the editing-job domain or settlement/refund workflow.

The closeout commit was subsequently pushed under separate one-shot authorization and independently verified on `origin/architecture-rebuild` at `e9d355238915f99a8f08f912282b1ece9ad90f0e`.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 11 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

## Sprint 11 Slice 11 Remote-State Reconciliation — 2026-08-27

### Exact remote authority

Technical-design freeze:

`fd321e570f128e92777d662836c0b4b206012fa3` — `docs: freeze sprint 11 slice 11`

Implementation:

`1486c36c8b13e228a0bca9b498ec6f9ea51fb958` — `feat: add editing pending advancement gate`

Governance closeout:

`e9d355238915f99a8f08f912282b1ece9ad90f0e` — `docs: close sprint 11 slice 11`

Exact chain:

`e9d355238915f99a8f08f912282b1ece9ad90f0e`
->
`1486c36c8b13e228a0bca9b498ec6f9ea51fb958`
->
`fd321e570f128e92777d662836c0b4b206012fa3`

The governance closeout is independently confirmed on `origin/architecture-rebuild`.

### Remote verification

Independent remote verification confirms:

- `architecture-rebuild` points exactly to `e9d355238915f99a8f08f912282b1ece9ad90f0e`;
- closeout subject is exactly `docs: close sprint 11 slice 11`;
- closeout parent is exactly `1486c36c8b13e228a0bca9b498ec6f9ea51fb958`;
- closeout contains only:
  - `docs/CURRENT_MILESTONE.md`;
  - `docs/SPRINT_MASTER_REGISTER.md`;
- implementation remains exactly `1486c36c8b13e228a0bca9b498ec6f9ea51fb958`;
- implementation parent remains exactly `fd321e570f128e92777d662836c0b4b206012fa3`;
- no additional implementation commit exists between implementation and closeout.

### Delivered Slice 11 authority

The delivered backend authority remains exactly:

`public.mark_booking_editing_pending(uuid)`

with:

- authenticated active-member execution;
- existing `booking.stage.advance`;
- booking branch containment;
- exact Stage 12 `selection_pending` first-execution boundary;
- exact Stage 11 -> 12 lineage;
- immutable selection confirmation/reconciliation prerequisites;
- internal Slice 10 full-balance predicate;
- non-reversed payment coverage;
- exact Stage 12 -> 13 `editing_pending` transition;
- strict Stage 13 replay;
- one non-sensitive first-execution audit event;
- no financial re-evaluation on historical replay.

### Validation retained

The reconciled implementation evidence remains:

- clean local DB reset PASS;
- local DB lint PASS;
- dedicated Slice 11 pgTAP 59 / 59 PASS;
- full local pgTAP 28 files / 1809 tests PASS;
- permissions 68;
- role-permission mappings 241;
- governed post-test residue zero;
- generated local Supabase types exactly equal checked types;
- generated-types semantic diff exactly one Slice 11 RPC;
- generated-types Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- exact three-artifact implementation boundary;
- exact two-document governance-closeout boundary.

### Scope containment retained

Slice 11 still does not introduce:

- editing-job creation;
- editor assignment;
- Stage 13 -> 14 / `editing_in_progress`;
- retouching;
- QC;
- delivery;
- Pixieset;
- persistent settlement state;
- overpayment or refund-due classification;
- refund workflow;
- Remote Supabase deployment;
- Production deployment.

### Reconciliation conclusion

Sprint 11 Slice 11 implementation and governance closeout are pushed and independently verified.

This two-document checkpoint records that exact remote state.

The reconciliation artifact was subsequently pushed under separate one-shot authorization and independently verified on `origin/architecture-rebuild` at `83d5a365da177dcaa23a5a501219d85860dd91f1`. It is the exact remote baseline for Slice 12.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 11 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

## Sprint 11 Slice 12 Technical Design Freeze — 2026-08-27

### Frozen baseline

Exact remotely reconciled parent:

`83d5a365da177dcaa23a5a501219d85860dd91f1` — `docs: reconcile sprint 11 slice 11 remote state`

Slice 12 may not be implemented against any other parent without a governance amendment.

### Slice name

**Sprint 11 Slice 12 — Editing Start Evidence Foundation**

### Architectural purpose

Slice 11 established canonical Stage 13 `editing_pending`.

Slice 12 establishes only immutable backend evidence that authorized editing work has actually started for a booking already at that canonical stage.

The evidence is deliberately separate from journey advancement.

The later Stage 13 -> 14 / `editing_in_progress` journey gate is not part of Slice 12.

### Frozen persistence authority

Create exactly one new canonical relation:

`public.booking_editing_starts`

Exact columns:

1. `id uuid`;
2. `organization_id uuid`;
3. `booking_id uuid`;
4. `source_editing_pending_transition_id uuid`;
5. `started_at timestamptz`;
6. `started_by uuid`.

Required semantics:

- `id` is the immutable primary key;
- `organization_id` + `booking_id` identify the canonical booking;
- exactly one editing-start row may exist per organization + booking;
- `source_editing_pending_transition_id` snapshots the exact canonical Stage 12 -> 13 `editing_pending` transition consumed at first recording;
- `started_at` is server-authoritative and is generated by the recording operation;
- `started_by` is the current active organization member performing the editing-domain action;
- the row is immutable after insertion;
- UPDATE is forbidden;
- DELETE is forbidden;
- no mutable status column exists in this slice.

The relation must not contain:

- editor assignment;
- external creative assignment;
- editing status;
- edited-image count;
- selection date duplication;
- deadline;
- SLA;
- priority-editing classification;
- QC status;
- gallery URL;
- delivery link;
- delivery date;
- payment amount or status;
- refund or overpayment state.

### Frozen recording RPC

Create exactly one browser-callable mutation RPC:

`public.record_booking_editing_start(uuid)`

Exact argument:

`p_booking_id uuid`

Return type:

`public.booking_editing_starts`

The RPC is the sole authenticated application write authority for the new relation.

It must be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated`;
- not executable by PUBLIC;
- not executable by `anon`;
- not executable by `service_role`.

### Frozen authorization contract

First execution requires:

- authenticated actor;
- active organization membership;
- existing `editing.write`;
- booking branch scope.

No new permission is introduced.

Canonical permission totals remain:

- permissions: 68;
- role-permission mappings: 241.

Current `editing.write` role topology remains exact:

- `editor`;
- `founder`;
- `studio_manager`.

Therefore:

- Editor may record editing start;
- Founder may record editing start;
- Studio Manager may record editing start;
- Client Coordinator may not record editing start merely because they hold `booking.stage.advance`;
- `booking.team.assign` is not editing-start authority;
- `booking.stage.advance` is not editing-start authority;
- `finance.read` is not editing-start authority;
- `payment.read` is not editing-start authority;
- `delivery.write` is not required.

### Frozen journey containment

The booking row is the synchronization root and must be locked before mutable-state evaluation.

First execution requires exactly one current canonical journey state.

The current stage must be exactly:

- order 13;
- key `editing_pending`;
- active.

The RPC must require exactly one canonical historical transition:

- source stage 12 `selection_pending`;
- destination stage 13 `editing_pending`;
- transition key `editing_pending`.

The exact transition row used by the operation is snapshotted in:

`source_editing_pending_transition_id`

The recording operation must not:

- append a new booking-stage transition;
- mutate `booking_journey_states`;
- increment journey version;
- advance to Stage 14;
- create Stage 14 history.

### Frozen upstream-authority rule

Slice 12 trusts successful canonical Stage 13 entry as the upstream readiness authority.

It must not re-evaluate:

- selection confirmation;
- selection reconciliation;
- image entitlement;
- additional-image pricing;
- adjusted financial obligation;
- booking payment requirement;
- booking payments;
- payment reversals;
- full-balance summary.

This prevents `editing.write` from importing selection or finance authority.

A later payment reversal does not invalidate historical Stage 13 entry and is not reinterpreted by the editing-start recorder.

### Frozen idempotence rule

The booking lock serializes concurrent first-record attempts.

At exact Stage 13:

- if no editing-start evidence exists, append exactly one row;
- if the exact existing row already references the same canonical Stage 13 transition, return that row without mutation;
- malformed or inconsistent pre-existing evidence fails closed.

Replay creates:

- no second editing-start row;
- no second audit event;
- no journey mutation.

Recording from Stage 12 or any stage other than exact Stage 13 is rejected.

Later-stage replay behavior is intentionally not introduced by this slice; later stages may read canonical evidence through the read authority instead.

### Frozen read / RLS contract

`booking_editing_starts` must:

- enable RLS;
- force RLS;
- deny direct INSERT / UPDATE / DELETE to authenticated application callers;
- expose authenticated SELECT only through existing `editing.read`;
- enforce booking branch scope.

Existing `editing.read` topology remains unchanged:

- Client Coordinator;
- Editor;
- Founder;
- Studio Manager.

No new permission or role grant is created.

### Frozen audit contract

First successful recording appends exactly one non-sensitive audit event:

`booking.editing_started`

Audit entity:

- entity type: `booking`;
- entity id: booking id.

Structural audit metadata may contain:

- booking id;
- editing-start evidence id;
- source Editing Pending transition id;
- started-at timestamp.

The audit must not contain:

- payment amounts;
- payment identifiers;
- payment methods;
- selection counts;
- financial-obligation values;
- editor assignment;
- external creative identity;
- priority-editing interpretation;
- deadline/SLA;
- QC;
- gallery/delivery data;
- free-text notes.

Replay must append no second audit event.

### Frozen editor-assignment decision

Editor assignment is explicitly excluded.

Evidence supporting the exclusion:

- canonical `booking_team_assignments` is a shoot-side subsystem whose mutation authority is `booking.team.assign`;
- its supported roles are photographer / assistant / stylist / videographer roles;
- its assignment lifecycle is constrained to booking stages 8 through 10;
- it does not currently support `editor`;
- the mock editing-start behavior itself begins with editor = `Unassigned`.

Slice 12 therefore must not:

- add `editor` to `booking_team_assignments`;
- expand the booking-team stage window;
- create an editor-assignment RPC;
- require an assigned editor before editing start;
- interpret `external_creatives` as editor identities.

Any canonical editor-assignment authority requires separate discovery and governance.

### Frozen priority-editing / SLA decision

`priority editing` is not machine-readable operational authority today.

The phrase exists in commercial/source text, but the structured
`commercial_operational_requirements` relation currently permits only:

`lead_videographer`

Therefore Slice 12 must not infer or persist:

- priority-editing boolean/status;
- editing deadline;
- turnaround days;
- due date;
- expedited-delivery SLA.

`organization_settings.delivery_link_expiry_days` is delivery-link expiry configuration, not editing turnaround authority, and must not be reused as one.

### Frozen mock-data interpretation

The Zustand/mock editing workflow remains non-authoritative product reference only.

Slice 12 does not canonicalize its internal states:

- Shoot Uploaded;
- Backup Completed;
- Preview Gallery Sent;
- Client Selection Pending;
- Selection Received;
- Full Payment Pending;
- Editing Started;
- Editing Completed;
- Photographer QC;
- Final Export;
- Delivered.

It also does not canonicalize mock fields:

- `editedCount`;
- `selectionDate`;
- `deadline`;
- `editor`;
- `qc`;
- `deliveryLink`;
- `deliveryDate`.

No UI or mock-store rewrite belongs to Slice 12.

### Frozen two-authority handshake

The architecture after Slice 12 is intentionally:

1. `editing.write` records immutable editing-start evidence at Stage 13;
2. a separately governed future journey gate may consume that evidence to advance Stage 13 -> 14 under `booking.stage.advance`.

The two operations must not be collapsed in Slice 12.

Consequently:

- Editor may create editing-start evidence but cannot gain journey-stage authority;
- Client Coordinator may retain journey-stage authority but cannot manufacture editing evidence;
- Founder / Studio Manager may possess both permissions, but the authorities remain structurally separate.

### Explicit exclusions

Slice 12 does not implement:

- Stage 13 -> 14 / `editing_in_progress`;
- mutable editing-job lifecycle;
- editor assignment;
- booking-team editor role;
- external-editor/freelancer semantics;
- edited-image progress count;
- priority editing;
- editing SLA/deadline;
- retouching workflow;
- Stage 14 -> 15;
- QC;
- Stage 15 -> 16;
- Pixieset;
- gallery readiness;
- Stage 16 -> 17;
- delivery;
- client delivery messaging;
- payment/refund workflow;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Frozen implementation artifact boundary

Implementation may modify exactly three artifacts:

1. `supabase/migrations/20260827130000_sprint11_editing_start_evidence_foundation.sql`;
2. `supabase/tests/sprint11_editing_start_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is permitted without governance amendment.

In particular, implementation must not modify:

- route/UI files;
- Zustand/mock-data files;
- server routes;
- existing compatibility tests;
- access-control migration;
- existing team-assignment migrations;
- governance documents during the implementation commit.

### Frozen validation contract

Implementation validation must prove at minimum:

- clean local database reset PASS;
- local DB lint PASS;
- dedicated pgTAP PASS;
- full local pgTAP regression PASS;
- permissions remain 68;
- role-permission mappings remain 241;
- table exists with exactly the six frozen columns;
- exactly one organization + booking editing-start row is possible;
- row is immutable;
- RLS enabled and forced;
- authenticated SELECT requires `editing.read` plus branch scope;
- direct authenticated table mutation is unavailable;
- RPC signature is exactly `record_booking_editing_start(uuid)`;
- RPC returns `booking_editing_starts`;
- RPC is SECURITY DEFINER with empty search path;
- PUBLIC / anon / service_role execute denied;
- authenticated execute allowed;
- unauthenticated actor rejected;
- inactive/suspended member rejected;
- Editor allowed through `editing.write`;
- Founder allowed through `editing.write`;
- Studio Manager allowed through `editing.write`;
- Client Coordinator rejected despite `booking.stage.advance`;
- branch mismatch rejected;
- Stage 12 rejected;
- exact Stage 13 accepted;
- Stage 14 rejected;
- missing or malformed Stage 12 -> 13 lineage rejected;
- source transition id snapshots the exact canonical `editing_pending` transition;
- started timestamp is server-generated and cannot precede the source Stage 13 transition;
- first execution creates exactly one evidence row;
- exact Stage 13 replay returns the same row;
- replay creates no duplicate audit;
- one first-execution `booking.editing_started` audit exists;
- audit is non-sensitive and contains no forbidden financial/assignment/SLA/delivery data;
- no booking-stage transition is created;
- journey state/version remains unchanged;
- no selection/reconciliation/financial/payment authority is mutated;
- no editor assignment is created;
- no additional editing/QC/delivery table is created;
- generated Supabase types contain exactly the new table and RPC schema changes expected from the migration;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- exact three-artifact implementation boundary retained;
- diff hygiene PASS.

### Freeze conclusion

The evidence is sufficient to freeze immutable Editing Start authority without guessing a mutable editing workflow.

Implementation remains unauthorized until this exact technical-design freeze is committed, pushed and independently verified.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 12 — TECHNICALLY FROZEN / IMPLEMENTATION NOT AUTHORIZED / PRODUCTION HOLD**

## Sprint 11 Slice 12 Compatibility Boundary Amendment — 2026-08-27

### Exact authority

Remotely verified Slice 12 technical-design freeze:

`0089d9b29b99ba8f5dea39087bf651f47962bd3a` — `docs: freeze sprint 11 slice 12`

The frozen Slice 12 persistence authority remains unchanged:

`public.booking_editing_starts`

The frozen recording RPC remains unchanged:

`public.record_booking_editing_start(uuid)`

The migration itself is not amended by this checkpoint.

### Compatibility defect discovered during validation

The existing Slice 11 dedicated test:

`supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`

contains a structural assertion whose predicate counts every public relation whose name matches:

`%editing%`

and requires that count to equal zero.

That assertion was valid while Slice 11 itself introduced no editing persistence, but it is not future-compatible with the separately governed Slice 12 relation:

`public.booking_editing_starts`

The Slice 12 relation is explicitly authorized by the later technical-design freeze and therefore must not be interpreted as a regression of Slice 11.

This is a compatibility-test defect, not an Editing Start migration or domain-design defect.

### Exact amendment

The previously frozen three-artifact implementation boundary is amended to exactly four artifacts:

1. `supabase/migrations/20260827130000_sprint11_editing_start_evidence_foundation.sql`;
2. `supabase/tests/sprint11_editing_start_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`.

The fourth artifact is authorized only for one narrow compatibility hardening:

- retain the Slice 11 pgTAP plan at exactly 59;
- retain the meaning that Slice 11 itself introduced no editing-job persistence;
- change only the legacy structural assertion so the later-governed relation
  `booking_editing_starts` is excluded from its `%editing%` zero-count check;
- do not whitelist any other editing relation;
- do not alter Slice 11 authorization, fixture, journey, settlement, replay, audit or mutation tests;
- do not weaken any Slice 12 assertion.

No other pre-existing test file is authorized for modification.

### Validation after amendment

After the exact compatibility repair, validation must still prove:

- Slice 11 dedicated pgTAP: 59 / 59 PASS;
- Slice 12 dedicated pgTAP: 63 / 63 PASS;
- full local pgTAP regression PASS;
- clean transaction residue;
- canonical permissions remain 68;
- canonical role-permission mappings remain 241;
- generated local Supabase types exactly represent the Slice 12 schema;
- generated-types semantic diff contains only the expected Slice 12 table and RPC additions;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- exact amended four-artifact implementation boundary.

### Scope unchanged

This amendment does not authorize:

- Stage 13 -> 14;
- mutable editing jobs;
- editor assignment;
- priority-editing SLA;
- QC;
- Pixieset;
- delivery;
- additional relations;
- additional permissions;
- UI/runtime changes;
- Remote Supabase deployment;
- Production deployment.

### Amendment conclusion

The Slice 12 domain design is unchanged.

Only the stale Slice 11 future-compatibility assertion is added to the implementation artifact boundary.

The compatibility test must not be modified until this amendment commit is separately pushed and independently verified.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 12 — TECHNICALLY FROZEN / IMPLEMENTATION AUTHORIZED / COMPATIBILITY AMENDMENT PENDING REMOTE VERIFICATION / PRODUCTION HOLD**

## Sprint 11 Slice 12 Governance Closeout — 2026-08-27

### Exact authority chain

Technical-design freeze:

`0089d9b29b99ba8f5dea39087bf651f47962bd3a` — `docs: freeze sprint 11 slice 12`

Compatibility-boundary amendment:

`e6afc35ee85c0b2e001536c95d4a32c962873962` — `docs: amend sprint 11 slice 12 compatibility boundary`

Implementation:

`c5b51ab7001443b2adc0eaa7a9728a9b20b33870` — `feat: add editing start evidence`

Implementation parent:

`e6afc35ee85c0b2e001536c95d4a32c962873962`

### Delivered boundary

Slice 12 delivers only:

- immutable `public.booking_editing_starts`;
- exact six-column evidence shape;
- one `public.record_booking_editing_start(uuid)` recorder;
- existing `editing.write` mutation authority;
- existing `editing.read` read authority;
- branch-scoped Stage 13 containment;
- exact Stage 12 -> 13 `editing_pending` lineage snapshot;
- strict idempotent replay;
- one non-sensitive `booking.editing_started` audit;
- no journey mutation.

Exact implementation artifacts:

1. `supabase/migrations/20260827130000_sprint11_editing_start_evidence_foundation.sql`;
2. `supabase/tests/sprint11_editing_start_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`.

Exact implementation statistics:

- 4 files;
- 2890 insertions;
- 0 deletions.

### Validation accepted

- migration reset PASS;
- DB lint PASS;
- Slice 11 compatibility pgTAP 59 / 59 PASS;
- Slice 12 dedicated pgTAP 63 / 63 PASS;
- full local pgTAP 29 files / 1872 tests PASS;
- permissions 68;
- role-permission mappings 241;
- canonical post-regression residue `68:241:0:0:0:0:0:0:0`;
- generated-types semantic delta exactly Slice 12 table + RPC;
- Prettier PASS;
- targeted ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- exact four-artifact implementation boundary;
- implementation commit and push exact;
- implementation independently verified on `origin/architecture-rebuild`.

### Governance conclusion

Slice 12 implementation is complete within the amended frozen scope.

The implementation does not authorize Stage 13 -> 14 or any downstream editing/QC/delivery workflow.

The governance closeout was subsequently committed, pushed under separate one-shot authorization, and independently verified on `origin/architecture-rebuild` at `7250e920d46c4a2819c82b6136e349ef65310806`.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 12 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

## Sprint 11 Slice 12 Remote-State Reconciliation — 2026-08-27

### Reconciled authority chain

Technical-design freeze:

`0089d9b29b99ba8f5dea39087bf651f47962bd3a` — `docs: freeze sprint 11 slice 12`

Compatibility-boundary amendment:

`e6afc35ee85c0b2e001536c95d4a32c962873962` — `docs: amend sprint 11 slice 12 compatibility boundary`

Implementation:

`c5b51ab7001443b2adc0eaa7a9728a9b20b33870` — `feat: add editing start evidence`

Governance closeout:

`7250e920d46c4a2819c82b6136e349ef65310806` — `docs: close sprint 11 slice 12`

Closeout parent:

`c5b51ab7001443b2adc0eaa7a9728a9b20b33870`

### Independent remote verification

Independent remote verification confirms:

- `architecture-rebuild` points exactly to `7250e920d46c4a2819c82b6136e349ef65310806`;
- remote closeout subject is exactly `docs: close sprint 11 slice 12`;
- remote closeout parent is exactly `c5b51ab7001443b2adc0eaa7a9728a9b20b33870`;
- implementation -> closeout is exactly one commit ahead and zero behind;
- the closeout contains exactly `docs/CURRENT_MILESTONE.md` and
  `docs/SPRINT_MASTER_REGISTER.md`;
- closeout diff is exactly 247 insertions / 1 deletion across those two documents;
- local and remote branch parity after the closeout push is `0 0`.

This reconciliation records remote governance state only.

It does not re-run or alter Slice 12 implementation.

### Accepted implementation state

The remotely closed Slice 12 remains validated by:

- clean local reset PASS;
- local DB lint PASS;
- Slice 11 compatibility pgTAP 59 / 59 PASS;
- Slice 12 dedicated pgTAP 63 / 63 PASS;
- full local pgTAP 29 files / 1872 tests PASS;
- permissions 68;
- role-permission mappings 241;
- canonical post-regression residue `68:241:0:0:0:0:0:0:0`;
- immutable six-column `public.booking_editing_starts`;
- exact `public.record_booking_editing_start(uuid)` recorder;
- existing `editing.write` mutation authority;
- existing `editing.read` read authority;
- exact Stage 13 `editing_pending` containment;
- exact Stage 12 -> 13 transition-lineage snapshot;
- strict idempotent replay;
- one non-sensitive `booking.editing_started` first-success audit;
- no booking-stage advancement;
- generated-types semantic delta exactly the Slice 12 table + RPC;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- exact amended four-artifact implementation boundary.

### Boundary remains closed

Slice 12 does not authorize:

- Stage 13 -> 14 / `editing_in_progress`;
- mutable editing-job workflow;
- editor assignment;
- editing SLA/deadline or priority-editing operational state;
- retouching/QC;
- Pixieset/gallery;
- delivery;
- payment/refund mutation;
- UI/runtime integration;
- Remote Supabase deployment;
- Production deployment.

No database or implementation mutation belongs to this reconciliation checkpoint.

### Reconciliation conclusion

Sprint 11 Slice 12 is now governance closed and its exact pushed remote state has been reconciled.

This reconciliation commit remains local until separately pushed under one-shot authorization and independently verified.

Only after that separate reconciliation push/verification may the next downstream boundary enter fresh read-only discovery.

No Stage 13 -> 14, editing-job, editor-assignment, QC, Pixieset, delivery or other downstream slice is pre-authorized by this checkpoint.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 12 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

## Sprint 11 Slice 13 Technical Design Freeze — 2026-08-27

### Frozen baseline

Exact remotely reconciled parent:

`81032eccef5c5cb872adce403768c84948e988c1` — `docs: reconcile sprint 11 slice 12 remote state`

Slice 13 may not be implemented against any other parent without a governance amendment.

### Slice name

**Sprint 11 Slice 13 — Controlled Stage 13 -> 14 / Editing In Progress Advancement Gate**

### Architectural purpose

Slice 12 established immutable Editing Start evidence while keeping journey authority separate.

Slice 13 completes only the second half of that two-authority handshake:

1. `editing.write` has already produced immutable canonical Editing Start evidence at Stage 13;
2. existing `booking.stage.advance` may consume that evidence to advance the journey from
   Stage 13 `editing_pending` to Stage 14 `editing_in_progress`.

The authorities remain structurally separate.

### Frozen journey transition

Create exactly one controlled mutation RPC:

`public.mark_booking_editing_in_progress(uuid)`

Exact argument:

`p_booking_id uuid`

Return type:

`public.bookings`

First successful execution performs exactly one canonical transition:

- source order 13 / key `editing_pending`;
- destination order 14 / key `editing_in_progress`;
- transition key `editing_in_progress`.

It updates the canonical booking journey state and increments journey version exactly once.

No new persistence relation is created.

### Frozen authorization contract

First execution requires:

- authenticated actor;
- active organization membership;
- existing `booking.stage.advance`;
- booking branch scope.

Current `booking.stage.advance` topology remains:

- Client Coordinator;
- Founder;
- Studio Manager.

The gate must not require:

- `editing.write`;
- `editing.read`;
- `delivery.write`;
- `finance.read`;
- `payment.read`;
- `booking.team.assign`.

Consequently:

- Client Coordinator may advance after valid Editing Start evidence exists;
- Founder may advance;
- Studio Manager may advance;
- Editor may create Editing Start evidence under `editing.write` but may not advance the
  journey merely because they are an Editor.

No new permission or role grant is introduced.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

### Frozen synchronization and current-stage rule

The booking row remains the synchronization root and is locked before mutable-state evaluation.

Exactly one current journey state is required.

First execution requires exactly:

- Stage 13;
- key `editing_pending`;
- active stage.

Stage 12 is rejected.

Stage 15 or any other later stage is rejected as replay.

### Frozen Editing Start evidence prerequisite

First execution requires exactly one canonical:

`public.booking_editing_starts`

row for the same organization + booking.

The gate must prove:

- exactly one immutable Editing Start row exists;
- its `source_editing_pending_transition_id` identifies the exact canonical
  Stage 12 `selection_pending` -> Stage 13 `editing_pending` transition;
- the source transition itself has exact transition key `editing_pending`;
- Editing Start `started_at` does not precede that source transition.

The gate trusts this immutable evidence as historical editing-domain authority.

It must not re-authorize the historical `started_by` actor.

Later suspension, exit or role changes of the member who originally created valid Editing Start
evidence must not invalidate historical evidence.

### Frozen upstream-authority containment

The Stage 13 -> 14 gate must not re-evaluate or import:

- selection confirmation;
- selection reconciliation;
- image entitlement;
- additional-image pricing;
- adjusted financial obligation;
- payment requirement;
- payments;
- payment reversals;
- full-balance summary;
- `editing.write`.

Those authorities were consumed by earlier governed operations.

### Frozen first-execution consistency

While current state remains Stage 13, first execution must reject malformed state including:

- missing Editing Start evidence;
- duplicate/inconsistent Editing Start evidence;
- malformed Editing Start source-transition lineage;
- pre-existing canonical Stage 13 -> 14 history;
- missing or duplicate canonical Stage 12 -> 13 history.

### Frozen transition mutation

First success must:

- resolve exactly one active Stage 14 `editing_in_progress`;
- append exactly one `booking_stage_transitions` row;
- use transition key `editing_in_progress`;
- move journey current stage from Stage 13 to Stage 14;
- increment journey version exactly once;
- update normal journey attribution consistently with existing journey-gate precedent;
- return the booking.

It must not mutate `booking_editing_starts`.

### Frozen replay rule

Exact Stage 14 is the only accepted replay state.

Replay must prove exactly one canonical historical transition:

Stage 13 `editing_pending`
->
Stage 14 `editing_in_progress`

with transition key `editing_in_progress`.

Successful replay:

- returns the booking;
- appends no second transition;
- increments no journey version;
- appends no second audit;
- performs no upstream evidence re-evaluation.

Stage 15 or later progression is not accepted as Slice 13 replay.

### Frozen audit contract

First successful advancement appends exactly one non-sensitive audit event:

`booking.editing_in_progress`

Entity:

- entity type `booking`;
- entity id booking id.

Structural metadata may include:

- booking id;
- Editing Start evidence id;
- source Editing Pending transition id;
- Stage 13 -> 14 transition id/key;
- prior/resulting journey stage;
- prior/resulting journey version;
- transition timestamp.

Audit metadata must not contain:

- financial values;
- payment identifiers or methods;
- selection counts;
- editor assignment;
- external creative identity;
- priority-editing interpretation;
- deadline/SLA;
- QC;
- gallery/delivery data;
- free-text notes.

Replay appends no second audit event.

### Frozen editor-assignment decision

Editor assignment remains excluded.

Canonical `booking_team_assignments` still permits only shoot-side assignment roles and does not
permit `editor`.

Slice 13 must not:

- add `editor` to booking-team assignments;
- expand booking-team lifecycle windows;
- create editor-assignment persistence;
- create editor-assignment RPCs;
- require editor assignment before Stage 14;
- treat `started_by` as canonical editor assignment;
- infer editor assignment from external creatives.

### Frozen priority-editing / SLA decision

Priority editing remains outside machine-readable operational authority.

`commercial_operational_requirements.requirement_key` remains constrained to:

`lead_videographer`

Slice 13 therefore must not introduce:

- priority-editing state;
- deadline;
- turnaround days;
- editing SLA;
- due date;
- expedited-delivery interpretation.

### Frozen downstream containment

Slice 13 does not implement:

- mutable editing-job lifecycle;
- edited-image progress;
- editor assignment;
- Stage 14 -> 15 / QC Pending;
- retouching workflow;
- QC persistence;
- Stage 15 -> 16;
- Pixieset/gallery authority;
- Stage 16 -> 17;
- delivery authority;
- client delivery messaging;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Frozen Slice 12 compatibility hardening

Existing Slice 12 pgTAP test #25 historically asserts zero public functions whose definition
contains `editing_in_progress`.

That assertion is valid for Slice 12 itself but is not future-compatible with the separately
governed Slice 13 advancement gate.

Therefore the Slice 13 implementation boundary explicitly includes:

`supabase/tests/sprint11_editing_start_evidence_test.sql`

Only test #25 may be changed, and only to:

- keep `SELECT plan(63);` unchanged;
- exclude exactly the later-governed `mark_booking_editing_in_progress` function from its
  Stage-14 zero-count predicate;
- whitelist no other Stage-14 function;
- change no fixture, authorization, evidence, audit, RLS or mutation behavior in the
  Slice 12 test.

This is compatibility hardening, not a Slice 12 domain-design change.

### Frozen implementation artifact boundary

Implementation may modify exactly four artifacts:

1. `supabase/migrations/20260827140000_sprint11_stage13_14_editing_in_progress_gate_foundation.sql`;
2. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_editing_start_evidence_test.sql`.

No fifth implementation artifact is permitted without governance amendment.

No route, UI, Zustand store, mock-data, permission migration, team-assignment migration or other
existing test file is authorized.

### Frozen generated-types expectation

Fresh local Supabase types may change only by the schema effect of the new RPC:

`mark_booking_editing_in_progress`

No new table/type persistence block is expected.

### Frozen validation contract

Implementation acceptance must prove at minimum:

- clean local database reset PASS;
- local DB lint PASS;
- existing Slice 12 dedicated pgTAP remains PASS with plan exactly 63;
- new Slice 13 dedicated pgTAP PASS;
- full local pgTAP regression PASS;
- permissions remain 68;
- role-permission mappings remain 241;
- exact RPC signature and return type;
- SECURITY DEFINER with empty search path;
- authenticated EXECUTE only;
- PUBLIC / anon / service_role EXECUTE denied;
- active membership requirement;
- exact `booking.stage.advance` authorization;
- branch containment;
- Editor rejected despite `editing.write`;
- Client Coordinator accepted when canonical Editing Start evidence exists;
- Founder accepted;
- Studio Manager accepted;
- exact Stage 13 first execution;
- Stage 12 rejected;
- Stage 15 rejected;
- missing Editing Start evidence rejected;
- malformed Editing Start lineage rejected;
- exact immutable Editing Start evidence accepted;
- no re-evaluation of selection or finance authority;
- exact Stage 13 -> 14 transition appended once;
- journey version increments once;
- one `booking.editing_in_progress` first-success audit;
- replay at exact Stage 14 is idempotent;
- replay creates no second transition/audit/version mutation;
- no Editing Start evidence mutation;
- no editor assignment;
- no new persistence relation;
- no QC/gallery/delivery authority;
- Slice 12 compatibility modification is confined exactly to test #25;
- generated types are fresh deterministic local generation;
- generated-types semantic delta is exactly the new RPC block;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- exact four-artifact implementation boundary;
- diff hygiene PASS.

### Freeze conclusion

The evidence is sufficient to freeze a journey-only Stage 13 -> 14 gate consuming immutable
Editing Start evidence.

The freeze does not authorize implementation until this exact governance commit is separately
pushed and independently verified.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 13 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

## Sprint 11 Slice 13 Governance Closeout — 2026-08-27

### Authority chain

Technical-design freeze:

`efef811dfebec9b49c784ce96bdda4c4ade54e78` — `docs: freeze sprint 11 slice 13`

Implementation:

`597f8de641fd3a73426061b9ecc793922be43354` — `feat: add editing in progress advancement gate`

The implementation is independently confirmed on `origin/architecture-rebuild` with exact parent
`efef811dfebec9b49c784ce96bdda4c4ade54e78`.

Freeze -> implementation is exactly one commit ahead / zero behind.

### Exact implementation boundary

1. `src/integrations/supabase/types.ts` — 22 insertions / 0 deletions;
2. `supabase/migrations/20260827140000_sprint11_stage13_14_editing_in_progress_gate_foundation.sql`
   — 914 insertions / 0 deletions;
3. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   — 2 insertions / 0 deletions;
4. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   — 1754 insertions / 0 deletions.

Total:

- 4 files;
- 2692 insertions;
- 0 deletions.

No fifth implementation artifact exists.

### Accepted database and behavioral validation

Accepted evidence:

- clean local database reset PASS;
- local DB lint PASS;
- RPC identity:
  `mark_booking_editing_in_progress(p_booking_id uuid) -> bookings`;
- SECURITY DEFINER: true;
- empty `search_path`;
- authenticated EXECUTE: true;
- anon EXECUTE: false;
- service_role EXECUTE: false;
- PUBLIC EXECUTE: false;
- `booking.stage.advance` retained as journey authority;
- Editing Start evidence retained as prerequisite;
- no `editing.write` requirement in the Stage 13 -> 14 gate;
- Editor rejected for journey advancement;
- Client Coordinator accepted with canonical evidence;
- Founder accepted;
- Studio Manager accepted;
- branch containment proven;
- Stage 12 rejected;
- Stage 15 rejected;
- missing Editing Start evidence rejected;
- malformed lineage rejected;
- duplicate Stage 12 -> 13 lineage rejected;
- pre-existing Stage 13 -> 14 history rejected;
- exact Stage 14 replay idempotent;
- one first-success Stage 13 -> 14 transition;
- one first-success `booking.editing_in_progress` audit;
- no replay transition/audit/version duplication;
- historical Editing Start evidence survives later starter suspension;
- no Editing Start mutation;
- no editor assignment;
- no new editing persistence;
- no QC/gallery/delivery authority.

### Accepted regression state

- Slice 12 compatibility suite: 63 / 63 PASS;
- Slice 13 dedicated suite: 53 / 53 PASS;
- full local regression: 30 files / 1925 tests PASS;
- permissions: 68;
- role-permission mappings: 241;
- canonical residue:
  `68:241:0:0:0:0:0:0:0:0`.

### Accepted generated-types and application validation

- fresh local Supabase generation completed;
- raw-generator formatting discrepancy was classified as validation-script sequencing only;
- generated types were normalized with repository Prettier;
- semantic delta proved exactly one
  `mark_booking_editing_in_progress` RPC block;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

Known build warnings remain non-fatal and outside this slice:

- TanStack `inputValidator()` deprecations;
- large client chunk warning;
- unused TanStack dependency imports;
- Nitro/Rollup unknown `platform` option warning;
- dependency-level `"use client"` directives ignored during bundling;
- Wrangler `main` override warning.

### Scope containment

Slice 13 closes only the controlled Stage 13
`editing_pending`
->
Stage 14
`editing_in_progress`
journey gate consuming immutable Editing Start evidence.

Still excluded:

- mutable editing-job lifecycle;
- editor assignment;
- priority editing;
- editing SLA/deadline;
- retouching;
- Stage 14 -> 15;
- QC persistence;
- Pixieset/gallery authority;
- Stage 15 -> 16;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Closeout state

The Slice 13 implementation is pushed and independently verified.

This two-document governance closeout is now committed and pushed, and is independently verified on
`origin/architecture-rebuild` at `a911c6f1c2c2f85e69b9df347dad8650fd25f5db`.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 13 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

## Sprint 11 Slice 13 Remote-State Reconciliation — 2026-08-27

### Reconciled authority chain

Technical-design freeze:

`efef811dfebec9b49c784ce96bdda4c4ade54e78` — `docs: freeze sprint 11 slice 13`

Implementation:

`597f8de641fd3a73426061b9ecc793922be43354` — `feat: add editing in progress advancement gate`

Governance closeout:

`a911c6f1c2c2f85e69b9df347dad8650fd25f5db` — `docs: close sprint 11 slice 13`

Exact closeout parent:

`597f8de641fd3a73426061b9ecc793922be43354`

### Independent remote verification

The pushed Slice 13 closeout is independently verified:

- `architecture-rebuild` points exactly to `a911c6f1c2c2f85e69b9df347dad8650fd25f5db`;
- closeout subject is exactly `docs: close sprint 11 slice 13`;
- closeout parent is exactly `597f8de641fd3a73426061b9ecc793922be43354`;
- implementation -> closeout is exactly one commit ahead / zero behind;
- the closeout modifies exactly two governance documents;
- `docs/CURRENT_MILESTONE.md`: 196 insertions / 2 deletions;
- `docs/SPRINT_MASTER_REGISTER.md`: 68 insertions / 1 deletion;
- total closeout diff: 264 insertions / 3 deletions.

### Reconciled accepted implementation state

Accepted Slice 13 validation remains:

- clean local database reset PASS;
- local DB lint PASS;
- Slice 12 compatibility pgTAP 63 / 63 PASS;
- Slice 13 dedicated pgTAP 53 / 53 PASS;
- full local pgTAP regression 30 files / 1925 tests PASS;
- permissions 68;
- role-permission mappings 241;
- canonical residue `68:241:0:0:0:0:0:0:0:0`;
- exact RPC `mark_booking_editing_in_progress(p_booking_id uuid) -> bookings`;
- SECURITY DEFINER with empty `search_path`;
- authenticated EXECUTE only;
- exact `booking.stage.advance` journey authority;
- immutable `booking_editing_starts` prerequisite;
- exact Stage 13 `editing_pending` -> Stage 14 `editing_in_progress`;
- strict Stage 14 replay;
- one first-success `booking.editing_in_progress` audit;
- Editor does not gain journey advancement;
- no new permission;
- no new editing persistence;
- generated-types semantic delta exactly one
  `mark_booking_editing_in_progress` RPC block;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- diff hygiene PASS.

### Reconciled scope containment

Still excluded:

- mutable editing jobs;
- editor assignment;
- priority editing / SLA;
- retouching;
- Stage 14 -> 15 / QC;
- QC persistence;
- Pixieset/gallery authority;
- Stage 15 -> 16;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Reconciliation conclusion

Sprint 11 Slice 13 governance closeout is pushed and its remote state is reconciled by this
two-document checkpoint.

This reconciliation commit remains local until separately pushed and independently verified.

No downstream implementation boundary is authorized by this reconciliation.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 13 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / PRODUCTION HOLD**

## Sprint 11 Slice 14 Technical Design Freeze — 2026-08-27

### Frozen baseline

Exact remotely reconciled parent:

`245d528ddcbe7921956634f583ca1c2ead5896c5` — `docs: reconcile sprint 11 slice 13 remote state`

Slice 14 may not be implemented against any other parent without a governance amendment.

### Slice name

**Sprint 11 Slice 14 — Editing Completion Evidence Foundation**

### Architectural purpose

Slice 13 established canonical Stage 14 `editing_in_progress` journey state after immutable Editing Start evidence had already been recorded.

Slice 14 establishes only immutable editing-domain evidence that editing work has completed while the booking remains at canonical Stage 14.

The authority separation remains:

1. `editing.write` records immutable Editing Completion evidence;
2. no journey transition is performed by Slice 14;
3. a later separately governed slice may consume that evidence under `booking.stage.advance` to advance Stage 14 `editing_in_progress` -> Stage 15 `qc_pending`.

### Frozen persistence

Create exactly one immutable relation:

`public.booking_editing_completions`

Exact six-column contract:

1. `id uuid`
2. `organization_id uuid`
3. `booking_id uuid`
4. `source_editing_in_progress_transition_id uuid`
5. `completed_at timestamptz`
6. `completed_by uuid`

Required invariants:

- exactly one completion row per organization + booking;
- one canonical source Editing In Progress transition may be consumed only once;
- booking, transition and actor references remain organization-safe;
- evidence is immutable after insertion;
- `completed_at` cannot precede the canonical Stage 13 -> 14 transition;
- no free-text operational data is stored.

### Frozen mutation RPC

Create exactly one application mutation RPC:

`public.record_booking_editing_completion(uuid)`

Exact argument:

`p_booking_id uuid`

Return type:

`public.booking_editing_completions`

The function must be `SECURITY DEFINER` with empty `search_path`.

Application EXECUTE authority:

- authenticated: allowed;
- PUBLIC: denied;
- anon: denied;
- service_role: denied.

### Frozen authorization

First execution requires:

- authenticated actor;
- active organization membership;
- existing `editing.write`;
- booking branch scope.

Current `editing.write` topology remains exactly:

- Editor;
- Founder;
- Studio Manager.

No new permission or role mapping is introduced.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

The RPC must not require:

- `booking.stage.advance`;
- `editing.read`;
- `delivery.write`;
- `finance.read`;
- `payment.read`;
- `booking.team.assign`.

Client Coordinator therefore does not receive editing-completion mutation authority merely because Client Coordinator has journey-advance authority.

### Frozen current-stage rule

The booking row remains the synchronization root.

Exactly one current canonical journey state is required.

First execution and idempotent replay both require exactly:

- Stage 14;
- key `editing_in_progress`;
- active stage.

Stage 13 is rejected.

Stage 15 or any later stage is rejected.

### Frozen source-transition lineage

Exactly one canonical source transition must exist for the same organization + booking:

Stage 13 `editing_pending`
->
Stage 14 `editing_in_progress`

with transition key:

`editing_in_progress`

The transition must identify the booking's current Stage 14 as its destination.

Slice 14 trusts the already-governed Stage 13 -> 14 transition as historical journey authority.

It must not re-evaluate historical selection, finance or Editing Start authorities already consumed by earlier governed operations.

### Frozen immutable guard

Direct UPDATE and DELETE of completion evidence are rejected.

Insert guard must verify:

- complete attribution;
- same organization + booking;
- exact canonical Stage 13 -> 14 source-transition lineage;
- `completed_at >= source transition transitioned_at`;
- when an authenticated identity exists, `completed_by` equals the current active organization member.

### Frozen RLS/read boundary

`booking_editing_completions` must enable and force RLS.

Authenticated users receive SELECT only.

Authenticated direct INSERT / UPDATE / DELETE remain unavailable.

Read access uses existing:

`editing.read`

plus booking branch scope.

Existing `editing.read` topology remains unchanged.

### Frozen idempotency

If one valid completion row already exists while the booking remains exactly Stage 14:

- return that row;
- create no second row;
- create no second audit;
- perform no journey mutation.

If existing evidence is inconsistent with canonical lineage, fail closed.

Later Stage 15+ progression is not accepted as Slice 14 replay.

### Frozen audit

First successful insertion appends exactly one non-sensitive audit event:

`booking.editing_completed`

Entity:

- type `booking`;
- id booking id.

Structural audit metadata may contain:

- booking id;
- Editing Completion evidence id;
- source Editing In Progress transition id;
- completion timestamp.

Audit metadata must not contain:

- image counts;
- financial amounts;
- payment identifiers;
- editor assignment semantics;
- external-creative identity;
- priority-editing interpretation;
- SLA/deadline;
- retouching notes;
- QC result/status;
- Pixieset/gallery information;
- delivery information;
- free-text notes.

Replay creates no second audit event.

### Frozen journey containment

Slice 14 does not mutate:

- `booking_journey_states`;
- `booking_stage_transitions`.

It does not create Stage 14 -> 15 authority.

Stage 15 `qc_pending` remains a later separately governed transition.

### Frozen scope exclusions

Slice 14 does not implement:

- mutable editing-job lifecycle;
- edited-image progress counts;
- editor assignment;
- external-editor/freelancer semantics;
- priority editing;
- editing SLA/deadline;
- retouching workflow/state;
- QC persistence;
- QC result;
- Stage 14 -> 15 / `qc_pending`;
- Stage 15 -> 16;
- Pixieset/gallery authority;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Frozen compatibility boundary

Historical tests may be amended only where their earlier downstream-zero assertions become stale because of this later-governed Slice 14 authority.

Authorized compatibility amendments are limited to:

1. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`
   - exclude exactly `booking_editing_completions` from the historical no-editing-persistence predicate;

2. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   - exclude only exact Slice 14 completion functions from the historical no-later-Stage-14-function predicate;

3. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   - exclude exactly `booking_editing_completions` from the historical no-new-editing-persistence predicate;
   - exclude only exact Slice 14 completion functions from the historical only-Stage-14-function predicate.

These amendments must not weaken any other historical assertion.

### Frozen implementation artifact boundary

Authorized implementation artifacts are exactly:

1. `supabase/migrations/<timestamp>_sprint11_editing_completion_evidence_foundation.sql`;
2. `supabase/tests/sprint11_editing_completion_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`;
5. `supabase/tests/sprint11_editing_start_evidence_test.sql`;
6. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`.

No other implementation artifact is authorized without a governance amendment.

### Validation contract

Before Slice 14 implementation may close, require:

- clean local database reset PASS;
- local DB lint PASS;
- Slice 11 compatibility PASS;
- Slice 12 compatibility PASS;
- Slice 13 compatibility PASS;
- dedicated Slice 14 pgTAP PASS;
- full local pgTAP regression PASS;
- permissions exactly 68;
- role-permission mappings exactly 241;
- no unauthorized residue;
- generated types freshly regenerated;
- generated-types semantic delta limited to `booking_editing_completions` and `record_booking_editing_completion`;
- Prettier PASS;
- targeted ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS;
- exact frozen artifact boundary.

### Freeze conclusion

Sprint 11 Slice 14 is technically frozen as **Editing Completion Evidence Foundation**.

Implementation remains unauthorized until this exact technical-design freeze is committed, pushed and independently verified.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 14 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**
## Sprint 11 Slice 14 Governance Closeout — 2026-08-27

### Authority chain

Technical-design freeze:

`f367973df24edca781c95695dbb93db7538e157f` — `docs: freeze sprint 11 slice 14`

Implementation:

`a2d4f4f4462a715d75add6b9e0ebb286d0b5f336` — `feat: add editing completion evidence foundation`

The implementation is independently confirmed on `origin/architecture-rebuild` with exact parent `f367973df24edca781c95695dbb93db7538e157f`.

Freeze -> implementation is exactly one commit ahead / zero behind.

### Exact implementation boundary

1. `src/integrations/supabase/types.ts` — 66 insertions / 0 deletions;
2. `supabase/migrations/20260827150000_sprint11_editing_completion_evidence_foundation.sql`
   — 926 insertions / 0 deletions;
3. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
   — 1520 insertions / 0 deletions;
4. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   — 5 insertions / 2 deletions;
5. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`
   — 4 insertions / 1 deletion;
6. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   — 8 insertions / 2 deletions.

Total:

- 6 files;
- 2529 insertions;
- 5 deletions.

No seventh implementation artifact exists.

### Accepted database and behavioral validation

Accepted evidence:

- clean local database reset PASS;
- local DB lint PASS with no schema errors;
- dedicated Slice 14 pgTAP 42 / 42 PASS;
- full local pgTAP regression 31 files / 1967 tests PASS;
- historical Slice 11 compatibility PASS;
- historical Slice 12 compatibility PASS;
- historical Slice 13 compatibility PASS;
- permissions remain exactly 68;
- role-permission mappings remain exactly 241;
- structural fingerprint exactly `68:241:1:1:6`;
- `booking_editing_completions` exists with exactly six columns;
- RLS is enabled and forced;
- authenticated direct mutation remains unavailable;
- authenticated read remains governed by existing `editing.read` plus branch scope;
- exact RPC `record_booking_editing_completion(p_booking_id uuid)` exists;
- RPC returns `booking_editing_completions`;
- RPC is SECURITY DEFINER with empty `search_path`;
- authenticated EXECUTE allowed;
- PUBLIC / anon / service_role EXECUTE denied;
- existing `editing.write` remains the mutation authority;
- Editor / Founder / Studio Manager retain exact editing-completion mutation authority;
- Client Coordinator does not gain editing-completion mutation authority;
- exact Stage 14 `editing_in_progress` containment validated;
- exact Stage 13 `editing_pending` -> Stage 14 `editing_in_progress` source lineage validated;
- Stage 13 rejected;
- Stage 15 rejected;
- missing canonical lineage rejected;
- duplicate canonical lineage rejected;
- immutable UPDATE and DELETE rejection validated;
- completion timestamp cannot precede Stage 14 entry;
- authenticated `completed_by` attribution must match current active member;
- first success creates exactly one immutable completion row;
- first success creates exactly one non-sensitive `booking.editing_completed` audit;
- exact Stage 14 replay is idempotent;
- replay creates no second evidence row;
- replay creates no second audit;
- replay performs no journey mutation;
- malformed pre-existing evidence fails closed;
- later Stage 15 progression is not accepted as Slice 14 replay;
- no Stage 14 -> 15 authority introduced;
- no QC, gallery or delivery authority introduced;
- no new permission or role mapping introduced.

### Accepted generated-types and application validation

- fresh local Supabase type generation completed after clean reset;
- generated types normalized with repository Prettier;
- generated-types diff exactly 66 insertions / 0 deletions;
- semantic delta is exactly `booking_editing_completions` plus `record_booking_editing_completion`;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

Known build warnings remain non-fatal and outside Slice 14:

- TanStack `inputValidator()` deprecations;
- large client chunk warning;
- dependency-level unused-import warnings;
- Nitro/Rollup unknown `platform` option warning;
- dependency-level `"use client"` directives ignored during bundling;
- Wrangler `main` override warning.

### Scope containment

Slice 14 closes only immutable Editing Completion evidence while the booking remains:

Stage 14 `editing_in_progress`.

Still excluded:

- Stage 14 -> 15 / `qc_pending`;
- mutable editing-job lifecycle;
- edited-image progress counts;
- editor assignment;
- external-editor/freelancer semantics;
- priority editing;
- editing SLA/deadline;
- retouching workflow/state;
- QC persistence;
- QC result;
- Stage 15 -> 16;
- Pixieset/gallery authority;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Closeout state

The Slice 14 implementation is pushed and independently verified.

This two-document governance closeout is now committed and pushed, and is independently verified on
`origin/architecture-rebuild` at `473428daf3036b14584ebbfe8e69fa2a5d48b6b6`.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 14 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 14 Remote-State Reconciliation — 2026-08-27

### Reconciled authority chain

Technical-design freeze:

`f367973df24edca781c95695dbb93db7538e157f` — `docs: freeze sprint 11 slice 14`

Implementation:

`a2d4f4f4462a715d75add6b9e0ebb286d0b5f336` — `feat: add editing completion evidence foundation`

Governance closeout:

`473428daf3036b14584ebbfe8e69fa2a5d48b6b6` — `docs: close sprint 11 slice 14`

Exact closeout parent:

`a2d4f4f4462a715d75add6b9e0ebb286d0b5f336`

### Independent remote verification

The pushed Slice 14 closeout is independently verified:

- `architecture-rebuild` points exactly to `473428daf3036b14584ebbfe8e69fa2a5d48b6b6`;
- closeout subject is exactly `docs: close sprint 11 slice 14`;
- closeout parent is exactly `a2d4f4f4462a715d75add6b9e0ebb286d0b5f336`;
- implementation -> closeout is exactly one commit ahead / zero behind;
- the closeout modifies exactly two governance documents;
- `docs/CURRENT_MILESTONE.md`: 212 insertions / 2 deletions;
- `docs/SPRINT_MASTER_REGISTER.md`: 89 insertions / 1 deletion;
- total closeout diff: 301 insertions / 3 deletions.

### Reconciled accepted implementation state

Accepted Slice 14 validation remains:

- clean local database reset PASS;
- local DB lint PASS with no schema errors;
- dedicated Slice 14 pgTAP 42 / 42 PASS;
- full local pgTAP regression 31 files / 1967 tests PASS;
- Slice 11 compatibility PASS;
- Slice 12 compatibility PASS;
- Slice 13 compatibility PASS;
- permissions 68;
- role-permission mappings 241;
- structural fingerprint `68:241:1:1:6`;
- exact six-column `booking_editing_completions`;
- exact `record_booking_editing_completion(uuid)` RPC;
- SECURITY DEFINER with empty `search_path`;
- authenticated EXECUTE only;
- existing `editing.write` mutation authority;
- existing `editing.read` plus branch-scope read authority;
- exact Stage 14 `editing_in_progress` containment;
- exact Stage 13 -> 14 source-transition lineage;
- strict Stage-14-only replay;
- one first-success `booking.editing_completed` audit;
- no journey mutation;
- no new permission;
- no Stage 14 -> 15 authority;
- generated-types semantic delta exactly `booking_editing_completions`
  plus `record_booking_editing_completion`;
- generated-types diff 66 insertions / 0 deletions;
- Prettier PASS;
- targeted ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- diff hygiene PASS.

### Reconciled scope containment

Still excluded:

- Stage 14 -> 15 / `qc_pending`;
- mutable editing jobs;
- edited-image progress counts;
- editor assignment;
- external-editor/freelancer semantics;
- priority editing / SLA;
- retouching;
- QC persistence or result;
- Pixieset/gallery authority;
- Stage 15 -> 16;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Reconciliation conclusion

Sprint 11 Slice 14 governance closeout is pushed and its remote state is reconciled by this
two-document checkpoint.

This reconciliation commit remains local until separately pushed and independently verified.

No downstream implementation boundary is authorized by this reconciliation.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 14 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 15 Technical Design Freeze — 2026-08-27

### Frozen baseline

Exact remotely reconciled parent:

`2e2e37c872f37037a417a8f61b62160a9ea4c21e` — `docs: reconcile sprint 11 slice 14 remote state`

Slice 15 may not be implemented against any other parent without a governance amendment.

### Slice name

**Sprint 11 Slice 15 — Controlled Stage 14 -> 15 / QC Pending Advancement Gate**

### Architectural purpose

Slice 14 established immutable Editing Completion evidence while the booking remained exactly at
Stage 14 `editing_in_progress`.

Slice 15 may consume that evidence only under existing journey authority and advance the booking
to Stage 15 `qc_pending`.

The authority separation remains exact:

1. `editing.write` records immutable Editing Completion evidence;
2. `booking.stage.advance` performs the journey transition;
3. the journey advancer must not create, rewrite or infer Editing Completion evidence;
4. Stage 15 means only QC Pending and does not represent a QC result.

### Frozen mutation RPC

Create exactly one application mutation RPC:

`public.mark_booking_qc_pending(uuid)`

Exact argument:

`p_booking_id uuid`

Return type:

`public.bookings`

The function must be:

- `SECURITY DEFINER`;
- empty `search_path`;
- callable by authenticated application actors only.

Application EXECUTE authority:

- authenticated: allowed;
- PUBLIC: denied;
- anon: denied;
- service_role: denied.

### Frozen authorization

First execution requires:

- authenticated actor;
- active organization membership;
- existing `booking.stage.advance`;
- booking branch scope.

Existing `booking.stage.advance` topology remains exactly:

- Client Coordinator;
- Founder;
- Studio Manager.

Editor does not gain journey-advance authority.

No new permission or role mapping is introduced.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

The RPC must not require:

- `editing.write`;
- `editing.read`;
- `delivery.write`;
- `finance.read`;
- `payment.read`;
- `booking.team.assign`.

The RPC must not call `record_booking_editing_completion(uuid)` and must not insert or mutate
`booking_editing_completions`.

### Frozen synchronization and current-stage rule

The booking row remains the canonical synchronization root and is locked before advancement.

Exactly one current canonical journey state is required.

First execution requires exactly:

- Stage 14;
- key `editing_in_progress`;
- active stage.

The gate may accept exact Stage 15 `qc_pending` only as strict replay.

Stage 13 or any earlier stage is rejected.

Stage 16 or any later stage is rejected.

### Frozen Stage 14 lineage

First execution must prove exactly one canonical transition for the same organization + booking:

Stage 13 `editing_pending`
->
Stage 14 `editing_in_progress`

with transition key:

`editing_in_progress`

The transition must identify the booking's current Stage 14 as its destination.

No historical selection, finance, payment or Editing Start authority is re-evaluated.

### Frozen Editing Completion prerequisite

First execution requires exactly one immutable row in:

`public.booking_editing_completions`

for the same organization + booking.

The evidence must satisfy:

- its `source_editing_in_progress_transition_id` equals the exact canonical Stage 13 -> 14
  transition used by this gate;
- `completed_at >= source transition transitioned_at`.

The gate consumes historical evidence only.

It must not require the historical `completed_by` actor to remain active or currently authorized.

A later suspension, role change or branch change of the completion actor does not invalidate
already-valid immutable completion evidence.

### Frozen pre-existing-transition guard

While the booking is still current Stage 14, there must be zero existing canonical:

Stage 14 `editing_in_progress`
->
Stage 15 `qc_pending`

transitions for that booking.

Any pre-existing destination transition while current state remains Stage 14 is inconsistent and
must fail closed.

### Frozen destination

Exactly one active canonical destination must exist:

- Stage 15;
- key `qc_pending`.

First success appends exactly one transition:

Stage 14 `editing_in_progress`
->
Stage 15 `qc_pending`

with transition key:

`qc_pending`

and the current authenticated organization member as `transitioned_by`.

### Frozen state advancement

The gate updates exactly one `booking_journey_states` row.

The advancement must be optimistic against the exact locked source state and version.

First success:

- sets `current_stage_id` to canonical Stage 15;
- sets `stage_entered_at` to the transition timestamp;
- increments journey version exactly once;
- attributes the update to the current authorized actor.

A concurrent or inconsistent state change must fail closed.

### Frozen replay

Exact Stage 15 `qc_pending` is the only valid replay state.

Replay must prove exactly one historical canonical transition:

Stage 14 `editing_in_progress`
->
Stage 15 `qc_pending`

with transition key `qc_pending` and destination equal to the current Stage 15 state.

Valid replay:

- returns the same booking;
- creates no second transition;
- creates no second audit;
- does not increment journey version;
- does not mutate Editing Completion evidence.

Replay proves historical journey advancement only.

It does not re-evaluate historical Editing Completion actor authority or any earlier editing,
selection, finance or payment authority.

### Frozen audit

First successful advancement appends exactly one non-sensitive audit event:

`booking.qc_pending`

Entity:

- type `booking`;
- id booking id.

Structural audit metadata may contain only journey/evidence identifiers such as:

- booking id;
- Editing Completion evidence id;
- source Editing In Progress transition id;
- transition key `qc_pending`;
- prior journey version;
- resulting journey version;
- Editing Completion timestamp.

Audit metadata must not contain:

- image counts;
- QC result/pass/fail;
- QC reviewer assignment;
- free-text QC notes;
- retouching notes;
- editor assignment semantics;
- external-creative identity;
- priority/SLA interpretation;
- financial amounts;
- payment identifiers;
- Pixieset/gallery information;
- delivery information.

Replay creates no second audit event.

### Frozen journey containment

Slice 15 may mutate only the canonical journey structures required for this exact advancement:

- append one `booking_stage_transitions` row;
- update one `booking_journey_states` row.

Slice 15 creates no new persistence relation.

Slice 15 does not mutate `booking_editing_completions`.

Slice 15 does not create Stage 15 -> 16 authority.

### Frozen scope exclusions

Slice 15 does not implement:

- QC persistence;
- QC pass/fail/result;
- QC reviewer assignment;
- QC comments or free text;
- retouching/rework workflow;
- mutable editing-job lifecycle;
- edited-image progress counts;
- editor assignment;
- external-editor/freelancer semantics;
- priority editing;
- editing SLA/deadline;
- Stage 15 -> 16;
- Pixieset/gallery authority;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Frozen compatibility boundary

Historical tests may be amended only where their earlier downstream-zero assertions become stale
because of this later-governed Stage 15 gate.

Authorized compatibility amendments are exactly:

1. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   - the historical function predicate mentioning `editing_in_progress` may additionally exclude
     exactly `mark_booking_qc_pending`;
   - no other function may be added to that exclusion;

2. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   - the historical only-Stage-14-function predicate may additionally exclude exactly
     `mark_booking_qc_pending`;
   - no other assertion may be weakened.

`supabase/tests/sprint11_editing_completion_evidence_test.sql` is not authorized for amendment and
must continue to pass unchanged.

No other historical test amendment is authorized without a governance amendment.

### Frozen implementation artifact boundary

Authorized implementation artifacts are exactly:

1. `supabase/migrations/<timestamp>_sprint11_stage14_15_qc_pending_gate_foundation.sql`;
2. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_editing_start_evidence_test.sql`;
5. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`.

No sixth implementation artifact is authorized without a governance amendment.

### Validation contract

Before Slice 15 implementation may close, require:

- clean local database reset PASS;
- local DB lint PASS;
- Slice 11 compatibility PASS;
- Slice 12 compatibility PASS;
- Slice 13 compatibility PASS;
- Slice 14 compatibility PASS;
- dedicated Slice 15 pgTAP PASS;
- full local pgTAP regression PASS;
- permissions exactly 68;
- role-permission mappings exactly 241;
- no unauthorized QC/gallery/delivery persistence residue;
- generated Supabase types freshly regenerated;
- generated-types semantic delta limited to `mark_booking_qc_pending`;
- Prettier PASS;
- targeted ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS;
- exact five-artifact implementation boundary.

### Freeze conclusion

Sprint 11 Slice 15 is technically frozen as
**Controlled Stage 14 -> 15 / QC Pending Advancement Gate**.

Implementation remains unauthorized until this exact technical-design freeze is committed, pushed
and independently verified.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 15 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**
## Sprint 11 Slice 15 Governance Closeout — 2026-08-28

### Authority chain

Technical-design freeze:

`0e6accc7dc3bd69c80becd3e4db626a688b0d971` — `docs: freeze sprint 11 slice 15`

Implementation:

`67746d3063c5f029c374d3700f2dd94d65d51756` — `feat: add qc pending advancement gate`

Exact implementation parent:

`0e6accc7dc3bd69c80becd3e4db626a688b0d971`

Freeze -> implementation is exactly one local commit.

The implementation is fully validated locally and committed.

Remote implementation verification remains pending until the local implementation and governance
closeout chain is pushed to `origin/architecture-rebuild`.

### Exact implementation boundary

1. `src/integrations/supabase/types.ts`
   — 22 insertions / 0 deletions;
2. `supabase/migrations/20260828010000_sprint11_stage14_15_qc_pending_gate_foundation.sql`
   — 885 insertions / 0 deletions;
3. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   — 1 insertion / 0 deletions;
4. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   — 1 insertion / 0 deletions;
5. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`
   — 1405 insertions / 0 deletions.

Total:

- 5 files;
- 2314 insertions;
- 0 deletions.

No sixth implementation artifact exists.

### Accepted database and behavioral validation

Accepted evidence:

- clean local database reset PASS;
- local DB lint PASS with no schema errors;
- dedicated Slice 15 pgTAP 38 / 38 PASS;
- historical Slice 11 compatibility 59 / 59 PASS;
- historical Slice 12 compatibility 63 / 63 PASS;
- historical Slice 13 compatibility 53 / 53 PASS;
- historical Slice 14 compatibility 42 / 42 PASS unchanged;
- full local pgTAP regression 32 files / 2005 tests PASS;
- permissions remain exactly 68;
- role-permission mappings remain exactly 241;
- exact RPC `public.mark_booking_qc_pending(uuid)` exists;
- RPC is SECURITY DEFINER with empty `search_path`;
- authenticated EXECUTE allowed;
- anon EXECUTE denied;
- service_role EXECUTE denied;
- existing `booking.stage.advance` remains the journey mutation authority;
- no new permission or role mapping was introduced;
- canonical Stage 14 `editing_in_progress` remains active;
- canonical Stage 15 `qc_pending` remains active;
- exact Stage 14 -> 15 advancement is validated;
- exact Stage 13 -> 14 `editing_in_progress` source-transition lineage is required;
- exactly one immutable Editing Completion prerequisite is required on first execution;
- completion source-transition lineage must match the exact canonical Stage 13 -> 14 transition;
- completion timestamp may not precede the source transition;
- historical completion-actor suspension does not invalidate already-valid immutable evidence;
- Editor does not gain journey advancement authority;
- Client Coordinator / Founder / Studio Manager retain journey advancement authority;
- the gate does not require `editing.write`;
- the gate does not create or mutate Editing Completion evidence;
- zero pre-existing Stage 14 -> 15 transition history is required while current state remains Stage 14;
- first success appends exactly one canonical Stage 14 -> 15 transition with key `qc_pending`;
- first success advances exactly one journey-state row;
- journey version increments exactly once;
- first success attributes transition and state mutation to the current authorized actor;
- first success appends exactly one non-sensitive `booking.qc_pending` audit;
- exact Stage 15 `qc_pending` replay is idempotent;
- valid replay creates no second transition;
- valid replay creates no second audit;
- valid replay creates no second journey-version increment;
- valid replay does not mutate Editing Completion evidence;
- invalid Stage 15 history fails closed;
- Stage 13 and earlier states are rejected;
- Stage 16 and later states are rejected;
- missing canonical lineage fails closed;
- duplicate canonical lineage fails closed;
- missing Editing Completion evidence fails closed;
- malformed Editing Completion evidence fails closed;
- inconsistent pre-existing Stage 14 -> 15 history fails closed;
- no Stage 15 -> 16 authority was introduced;
- no unauthorized QC, Pixieset/gallery or delivery persistence relation exists.

### Accepted generated-types and application validation

- fresh local Supabase type generation completed after clean reset;
- generated output normalized with the repository Prettier configuration;
- generated-types diff exactly 22 insertions / 0 deletions;
- generated-types semantic delta is exactly `mark_booking_qc_pending`;
- generated RPC argument is exactly `p_booking_id: string`;
- generated RPC return is the canonical `bookings` row shape;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS;
- exact five-artifact implementation containment PASS.

Known build warnings remain non-fatal and outside Slice 15:

- TanStack `inputValidator()` deprecations;
- large client chunk warning;
- dependency-level unused-import warnings;
- Nitro/Rollup unknown `platform` option warning;
- dependency-level `"use client"` directives ignored during bundling;
- Wrangler `main` override warning.

### Delivered authority

Slice 15 closes only the controlled journey advancement:

Stage 14 `editing_in_progress`
->
Stage 15 `qc_pending`

under existing `booking.stage.advance`.

The gate consumes immutable Editing Completion evidence created under separate `editing.write`
authority.

Authority separation remains exact:

- Editing Completion creation remains an editing-domain authority;
- Stage 14 -> 15 advancement remains a journey-domain authority;
- historical completion evidence is consumed, not recreated;
- historical completion-actor authority is not re-evaluated;
- replay proves journey history only.

### Scope containment

Slice 15 does not establish:

- QC persistence;
- QC pass/fail/result;
- QC reviewer assignment;
- QC comments or free text;
- retouching/rework workflow;
- mutable editing-job lifecycle;
- edited-image progress counts;
- editor assignment;
- external-editor/freelancer semantics;
- priority editing;
- editing SLA/deadline;
- Stage 15 -> 16;
- Pixieset/gallery authority;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Closeout state

The Slice 15 implementation is fully validated locally and committed at:

`67746d3063c5f029c374d3700f2dd94d65d51756`

This two-document governance closeout is now committed and pushed, and is independently verified on `origin/architecture-rebuild` at `e4863b00c0b1c59a191d6b0afb762f980603bb29`.

Remote implementation and closeout verification are complete. `origin/architecture-rebuild` points exactly to `e4863b00c0b1c59a191d6b0afb762f980603bb29`.

No Stage 15 -> 16 implementation authority is granted by this closeout.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 15 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**
## Sprint 11 Slice 15 Remote-State Reconciliation — 2026-08-28

### Reconciled authority chain

Technical-design freeze:

`0e6accc7dc3bd69c80becd3e4db626a688b0d971` — `docs: freeze sprint 11 slice 15`

Implementation:

`67746d3063c5f029c374d3700f2dd94d65d51756` — `feat: add qc pending advancement gate`

Governance closeout:

`e4863b00c0b1c59a191d6b0afb762f980603bb29` — `docs: close sprint 11 slice 15`

Exact implementation parent:

`0e6accc7dc3bd69c80becd3e4db626a688b0d971`

Exact closeout parent:

`67746d3063c5f029c374d3700f2dd94d65d51756`

### Independent remote verification

The pushed Slice 15 chain is independently verified:

- `architecture-rebuild` points exactly to `e4863b00c0b1c59a191d6b0afb762f980603bb29`;
- closeout subject is exactly `docs: close sprint 11 slice 15`;
- closeout parent is exactly `67746d3063c5f029c374d3700f2dd94d65d51756`;
- implementation parent is exactly `0e6accc7dc3bd69c80becd3e4db626a688b0d971`;
- freeze -> implementation is exactly one commit ahead / zero behind;
- implementation -> closeout is exactly one commit ahead / zero behind;
- implementation modifies exactly five frozen artifacts;
- implementation diff is exactly 2314 insertions / 0 deletions;
- closeout modifies exactly two governance documents;
- `docs/CURRENT_MILESTONE.md`: 189 insertions / 1 deletion;
- `docs/SPRINT_MASTER_REGISTER.md`: 112 insertions / 1 deletion;
- total closeout diff: 301 insertions / 2 deletions.

### Reconciled accepted implementation state

Accepted Slice 15 validation remains:

- clean local database reset PASS;
- local DB lint PASS with no schema errors;
- dedicated Slice 15 pgTAP 38 / 38 PASS;
- Slice 11 compatibility 59 / 59 PASS;
- Slice 12 compatibility 63 / 63 PASS;
- Slice 13 compatibility 53 / 53 PASS;
- Slice 14 compatibility 42 / 42 PASS unchanged;
- full local pgTAP regression 32 files / 2005 tests PASS;
- permissions 68;
- role-permission mappings 241;
- exact `public.mark_booking_qc_pending(uuid)` RPC;
- SECURITY DEFINER with empty `search_path`;
- authenticated EXECUTE allowed;
- anon EXECUTE denied;
- service_role EXECUTE denied;
- existing `booking.stage.advance` remains the journey authority;
- exact Stage 14 `editing_in_progress` -> Stage 15 `qc_pending`;
- immutable Editing Completion prerequisite;
- exact Stage 13 -> 14 source-transition lineage;
- optimistic exact-state/version advancement;
- strict Stage-15-only replay;
- one first-success `booking.qc_pending` audit;
- no Editing Completion mutation;
- no new persistence;
- no new permission;
- no Stage 15 -> 16 authority;
- no unauthorized QC/gallery/delivery persistence;
- generated-types semantic delta exactly `mark_booking_qc_pending`;
- generated-types diff 22 insertions / 0 deletions;
- Prettier PASS;
- targeted ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- diff hygiene PASS.

### Reconciled scope containment

Slice 15 closes only:

Stage 14 `editing_in_progress`
->
Stage 15 `qc_pending`

Still excluded:

- QC persistence/result/pass/fail;
- QC reviewer assignment;
- retouching/rework;
- mutable editing jobs;
- editor assignment;
- priority editing / SLA;
- Stage 15 -> 16;
- Pixieset/gallery authority;
- Stage 16 -> 17;
- delivery authority;
- payment/refund mutation;
- settlement persistence;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Reconciliation conclusion

Sprint 11 Slice 15 implementation and governance closeout are pushed and independently verified.

This two-document checkpoint records the reconciled remote state.

This reconciliation commit remains local until separately pushed and independently verified.

No Stage 15 -> 16 implementation boundary is authorized by this reconciliation.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 15 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 16 Technical Design Freeze — 2026-08-28

### Frozen baseline

Exact remotely reconciled parent:

`83692ed04a22ef8bf1a2e1a9336e4f043d5a3266` — `docs: reconcile sprint 11 slice 15 remote state`

Slice 16 may not be implemented against any other parent without a governance amendment.

### Slice name

**Sprint 11 Slice 16 — QC Pass Evidence Foundation**

### Architectural purpose

Slice 15 establishes exact Stage 15 `qc_pending`.

Slice 16 establishes immutable evidence that QC has passed while the booking remains exactly at Stage 15.

The authority separation is:

1. existing `editing.write` records immutable QC Pass evidence;
2. Slice 16 performs no journey advancement;
3. a later separately governed `booking.stage.advance` gate may consume the immutable pass evidence;
4. Stage 16 `pixieset_gallery_ready` remains outside Slice 16.

### Frozen persistence

Create exactly one relation:

`public.booking_qc_passes`

Exact columns:

1. `id uuid`;
2. `organization_id uuid`;
3. `booking_id uuid`;
4. `source_qc_pending_transition_id uuid`;
5. `passed_at timestamptz`;
6. `passed_by uuid`.

No seventh column is authorized.

Row existence represents an affirmative QC pass.

Slice 16 does not persist:

- fail/result/status enums;
- QC score;
- free-text QC notes;
- reviewer assignment;
- rework/retouch instructions;
- image-level QC;
- Pixieset/gallery data;
- delivery data.

### Frozen invariants

The relation must enforce:

- tenant-safe organization ownership;
- one QC Pass evidence row per organization + booking;
- one consumption of a source QC Pending transition;
- exact organization-safe booking reference;
- exact organization-safe source-transition reference;
- immutable evidence after insert;
- `passed_at >=` source transition timestamp.

Update and delete are forbidden.

### Frozen mutation RPC

Create exactly one mutation RPC:

`public.record_booking_qc_pass(uuid)`

Exact argument:

`p_booking_id uuid`

Return type:

`public.booking_qc_passes`

The RPC must be:

- `SECURITY DEFINER`;
- empty `search_path`;
- authenticated application actors only.

PUBLIC, anon and service_role EXECUTE remain denied.

### Frozen authorization

First execution requires:

- authenticated actor;
- active organization membership;
- existing `editing.write`;
- booking branch scope.

Existing `editing.write` topology remains exactly:

- Editor;
- Founder;
- Studio Manager.

No new permission or role mapping is introduced.

Canonical totals remain:

- permissions 68;
- role-permission mappings 241.

The RPC must not require or import:

- `booking.stage.advance`;
- `delivery.read`;
- `delivery.write`;
- `review.read`;
- `review.write`;
- `finance.read`;
- `payment.read`;
- `booking.team.assign`.

### Frozen read authority

Forced RLS authenticated SELECT uses existing:

`editing.read`

plus booking branch scope.

Existing `editing.read` topology remains exactly:

- Client Coordinator;
- Editor;
- Founder;
- Studio Manager.

No QC-specific read permission is introduced.

### Frozen current-stage rule

The booking row is the synchronization root and is locked before first insert.

Exactly one current canonical journey state is required.

First execution requires exactly:

Stage 15 `qc_pending`

and the stage must be active.

Stage 14 or earlier is rejected.

Stage 16 or later is rejected.

### Frozen QC Pending lineage

First execution must prove exactly one canonical transition for the same organization + booking:

Stage 14 `editing_in_progress`
->
Stage 15 `qc_pending`

with transition key:

`qc_pending`

The transition destination must equal the booking's current Stage 15 state.

The exact transition id is stored as:

`source_qc_pending_transition_id`

Slice 16 trusts this already-governed journey provenance.

It must not re-evaluate or mutate:

- `booking_editing_completions`;
- Editing Completion actor authority;
- Editing Start evidence;
- selection evidence;
- finance authority;
- payment authority.

### Frozen first success

First success inserts exactly one immutable QC Pass evidence row.

`passed_by` is the current authorized organization member.

`passed_at` is the authoritative pass timestamp.

The booking remains exactly Stage 15 `qc_pending`.

No `booking_stage_transitions` row is appended.

No `booking_journey_states` row is updated.

### Frozen replay

Valid replay is allowed only while the booking remains exact Stage 15 `qc_pending`.

Replay must prove exactly one existing evidence row whose:

- organization matches;
- booking matches;
- source transition equals the exact canonical Stage 14 -> 15 `qc_pending` transition;
- `passed_at` is not earlier than the source transition.

Valid replay:

- returns the same evidence row;
- creates no second evidence;
- creates no second audit;
- performs no journey mutation.

Invalid or inconsistent evidence fails closed.

### Frozen audit

First success appends exactly one non-sensitive audit event:

`booking.qc_passed`

Structural metadata may contain only identifiers and timestamps required to prove the pass lineage, including:

- booking id;
- QC Pass evidence id;
- source QC Pending transition id;
- Stage 15 identifier;
- pass timestamp.

Audit metadata must not contain:

- free-text QC notes;
- QC failure reasons;
- image-level findings;
- editor notes;
- reviewer assignment;
- financial information;
- Pixieset/gallery information;
- delivery information.

Replay creates no second audit.

### Frozen journey and downstream containment

Slice 16 creates no journey authority.

It must not:

- append Stage 15 -> 16;
- mutate `booking_journey_states`;
- create Pixieset/gallery persistence;
- create delivery persistence;
- call a Stage 15 -> 16 journey RPC;
- import `delivery.write`.

Stage 16 `pixieset_gallery_ready` remains later-governed.

### Frozen scope exclusions

Slice 16 does not implement:

- QC fail persistence;
- generic QC result lifecycle;
- QC reviewer assignment;
- QC comments/free text;
- retouching/rework workflow;
- image-level QC;
- mutable editing-job lifecycle;
- priority/SLA;
- Stage 15 -> 16;
- Pixieset integration;
- gallery persistence;
- gallery URLs;
- gallery status;
- Stage 16 -> 17;
- delivery persistence;
- payment/refund mutation;
- settlement;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Frozen compatibility boundary

Exactly two historical tests may be amended because their historical downstream-zero relation assertions become stale once the later-governed QC Pass relation exists.

Authorized amendments are exactly:

1. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
   - its historical QC/gallery/delivery zero-persistence predicate may exclude exactly `booking_qc_passes`;
   - no other assertion may be weakened;

2. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`
   - its historical QC/gallery/delivery zero-persistence predicate may exclude exactly `booking_qc_passes`;
   - no other assertion may be weakened.

No other historical test amendment is authorized.

### Frozen implementation artifact boundary

Authorized implementation artifacts are exactly:

1. `supabase/migrations/<timestamp>_sprint11_qc_pass_evidence_foundation.sql`;
2. `supabase/tests/sprint11_qc_pass_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_editing_completion_evidence_test.sql`;
5. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`.

No sixth implementation artifact is authorized without a governance amendment.

### Validation contract

Before Slice 16 implementation may close, require:

- clean local database reset PASS;
- local DB lint PASS;
- dedicated Slice 16 pgTAP PASS;
- Slice 14 compatibility 42 / 42 PASS;
- Slice 15 compatibility 38 / 38 PASS;
- all earlier focused compatibility suites PASS;
- full local pgTAP regression PASS;
- permissions exactly 68;
- role-permission mappings exactly 241;
- exact six-column `booking_qc_passes`;
- exact `record_booking_qc_pass(uuid)` RPC;
- no unauthorized Pixieset/gallery/delivery persistence;
- generated Supabase types freshly regenerated;
- generated-types semantic delta limited to `booking_qc_passes` and `record_booking_qc_pass`;
- Prettier PASS;
- targeted ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS;
- exact five-artifact implementation boundary.

### Freeze conclusion

Sprint 11 Slice 16 is technically frozen as:

**QC Pass Evidence Foundation**

Implementation remains unauthorized until this exact freeze is committed, pushed and independently verified.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 16 — TECHNICAL DESIGN FROZEN / IMPLEMENTATION NOT STARTED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

### Sprint 11 Slice 16 Governance Amendment 1 — Historical Stage-14 Compatibility

This amendment is additive and does not rewrite the original Slice 16
technical-design freeze.

During local Slice 16 validation, after:

- clean local database reset PASS;
- local database lint PASS;
- dedicated Slice 16 pgTAP 42 / 42 PASS;
- Slice 14 compatibility 42 / 42 PASS;
- Slice 15 compatibility 38 / 38 PASS;
- Slice 11 compatibility 59 / 59 PASS;

the historical Slice 12 compatibility suite exposed one compatibility-only
failure:

`Slice 12 introduces no Stage 14 function`

The assertion returned exactly two later authorized functions.

Direct catalogue inspection proved those functions are exactly:

- `public.lsh_booking_qc_pass_guard()`;
- `public.record_booking_qc_pass(uuid)`.

Both are legitimate Slice 16 functions and necessarily reference
`editing_in_progress` only to prove the frozen canonical Stage 14
`editing_in_progress` -> Stage 15 `qc_pending` source-transition lineage.

This does not introduce Stage 13 -> 14 authority, Stage 15 -> 16 authority,
or any new journey mutation.

The original Slice 16 compatibility authorization is therefore amended by
adding exactly two historical test artifacts:

3. `supabase/tests/sprint11_editing_start_evidence_test.sql` may add exactly
   `lsh_booking_qc_pass_guard` and `record_booking_qc_pass` to the
   `procedure.proname NOT IN (...)` exclusion list of its historical
   Stage-14-function compatibility assertion only;

4. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   may add exactly `lsh_booking_qc_pass_guard` and
   `record_booking_qc_pass` to the `procedure.proname NOT IN (...)`
   exclusion list of its historical Stage-14-function compatibility
   assertion only.

No other assertion in either historical test may be changed under this
amendment.

The amended Slice 16 implementation boundary is exactly seven artifacts:

1. `supabase/migrations/<timestamp>_sprint11_qc_pass_evidence_foundation.sql`;
2. `supabase/tests/sprint11_qc_pass_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_editing_completion_evidence_test.sql`;
5. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`;
6. `supabase/tests/sprint11_editing_start_evidence_test.sql`;
7. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`.

No eighth implementation artifact is authorized.

This amendment changes no Slice 16 domain authority, persistence model,
permission topology, RLS authority, replay semantics, audit semantics,
journey containment or downstream exclusion.

Remote Supabase remains HOLD.

Production remains HOLD.

Stage 15 -> 16 remains unauthorized.

**SPRINT 11 SLICE 16 — GOVERNANCE AMENDED FOR EXACT HISTORICAL COMPATIBILITY / LOCAL IMPLEMENTATION CONTINUES / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

### Sprint 11 Slice 16 Governance Closeout

Sprint 11 Slice 16 — **QC Pass Evidence Foundation** — is implemented,
fully validated locally, pushed and independently verified on
`origin/architecture-rebuild`.

Exact authority chain:

- technical-design freeze:
  `f492e50d5a70591c09f197157e02db305f33cace`
  — `docs: freeze sprint 11 slice 16`;
- historical-compatibility governance amendment:
  `0b6296fdceffb0fdc12743129d2c467bc4f55c05`
  — `docs: amend sprint 11 slice 16 compatibility`;
- implementation:
  `8bc1cfcf78ecad23ec4537b27948f85f2d77f552`
  — `feat: add qc pass evidence foundation`.

The implementation parent is exactly:

`0b6296fdceffb0fdc12743129d2c467bc4f55c05`.

Independent remote comparison confirms the amendment -> implementation
relationship is exactly one commit ahead / zero behind.

Accepted Slice 16 validation:

- clean local database reset PASS;
- local database lint PASS with no schema errors;
- dedicated Slice 16 pgTAP 42 / 42 PASS;
- Slice 11 compatibility 59 / 59 PASS;
- Slice 12 compatibility 63 / 63 PASS;
- Slice 13 compatibility 53 / 53 PASS;
- Slice 14 compatibility 42 / 42 PASS;
- Slice 15 compatibility 38 / 38 PASS;
- focused Sprint 11 Slice 11 through 16 validation 297 / 297 PASS;
- full local pgTAP regression 33 files / 2047 tests PASS;
- canonical permissions 68;
- canonical role-permission mappings 241;
- exact six-column `public.booking_qc_passes` relation;
- exact `public.record_booking_qc_pass(uuid)` RPC;
- unauthorized additional QC / Pixieset / delivery persistence count 0;
- immutable QC Pass evidence validated;
- exact canonical Stage 14 `editing_in_progress` -> Stage 15 `qc_pending`
  source-transition lineage validated;
- strict Stage-15-only replay validated;
- first success records exactly one structural `booking.qc_passed` audit;
- booking remains exactly Stage 15 `qc_pending`;
- no Stage 15 -> 16 authority introduced;
- existing `editing.write` remains the mutation authority;
- existing `editing.read` remains the read authority;
- permissions remain 68 and role-permission mappings remain 241;
- generated Supabase types freshly regenerated from the clean local database;
- generated-types semantic delta limited exactly to
  `booking_qc_passes` and `record_booking_qc_pass`;
- generated-types diff 66 insertions / 0 deletions;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS with non-blocking pre-existing dependency,
  deprecation and bundle-size warnings only;
- `git diff --check` PASS.

Exact amended implementation boundary:

1. `src/integrations/supabase/types.ts` — 66 insertions / 0 deletions;
2. `supabase/migrations/20260828150000_sprint11_qc_pass_evidence_foundation.sql`
   — 930 insertions / 0 deletions;
3. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
   — 2 insertions / 1 deletion;
4. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   — 3 insertions / 1 deletion;
5. `supabase/tests/sprint11_qc_pass_evidence_test.sql`
   — 1552 insertions / 0 deletions;
6. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   — 3 insertions / 1 deletion;
7. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`
   — 1 insertion / 0 deletions.

Total implementation diff:

- 7 files;
- 2557 insertions;
- 3 deletions.

Slice 16 therefore establishes immutable affirmative QC Pass evidence while
the booking remains exactly at Stage 15 `qc_pending`.

Slice 16 does not implement:

- QC failure/result lifecycle;
- mutable QC workflow;
- reviewer assignment;
- QC notes or scores;
- rework/retouch workflow;
- image-level QC;
- Stage 15 -> 16;
- Pixieset/gallery persistence;
- gallery URLs or synchronization;
- delivery persistence;
- Stage 16 -> 17;
- payment/refund mutation;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

Remote Supabase remains HOLD.

Production remains HOLD.

Stage 15 -> 16 remains separately governed and unauthorized.

**SPRINT 11 SLICE 16 — IMPLEMENTED / FULLY VALIDATED LOCALLY / IMPLEMENTATION PUSHED AND INDEPENDENTLY VERIFIED / GOVERNANCE CLOSEOUT PENDING COMMIT / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 16 Remote-State Reconciliation — 2026-08-28

### Reconciled authority chain

Technical-design freeze:

`f492e50d5a70591c09f197157e02db305f33cace`
— `docs: freeze sprint 11 slice 16`

Historical-compatibility governance amendment:

`0b6296fdceffb0fdc12743129d2c467bc4f55c05`
— `docs: amend sprint 11 slice 16 compatibility`

Implementation:

`8bc1cfcf78ecad23ec4537b27948f85f2d77f552`
— `feat: add qc pass evidence foundation`

Governance closeout:

`9a42ac72086125e572b8a2c5561c455fc09c58d8`
— `docs: close sprint 11 slice 16`

Exact governance-amendment parent:

`f492e50d5a70591c09f197157e02db305f33cace`

Exact implementation parent:

`0b6296fdceffb0fdc12743129d2c467bc4f55c05`

Exact closeout parent:

`8bc1cfcf78ecad23ec4537b27948f85f2d77f552`

### Independent remote verification

The pushed Slice 16 chain is independently verified:

- `architecture-rebuild` points exactly to
  `9a42ac72086125e572b8a2c5561c455fc09c58d8`;
- closeout subject is exactly `docs: close sprint 11 slice 16`;
- closeout parent is exactly
  `8bc1cfcf78ecad23ec4537b27948f85f2d77f552`;
- implementation subject is exactly
  `feat: add qc pass evidence foundation`;
- implementation parent is exactly
  `0b6296fdceffb0fdc12743129d2c467bc4f55c05`;
- governance-amendment subject is exactly
  `docs: amend sprint 11 slice 16 compatibility`;
- governance-amendment parent is exactly
  `f492e50d5a70591c09f197157e02db305f33cace`;
- amendment -> implementation is exactly one commit ahead / zero behind;
- implementation -> closeout is exactly one commit ahead / zero behind;
- implementation modifies exactly seven amended implementation artifacts;
- implementation diff is exactly 2557 insertions / 3 deletions;
- closeout modifies exactly two governance documents;
- `docs/CURRENT_MILESTONE.md`: 115 insertions / 0 deletions;
- `docs/SPRINT_MASTER_REGISTER.md`: 115 insertions / 0 deletions;
- total closeout diff: 230 insertions / 0 deletions.

### Reconciled accepted implementation state

Accepted Slice 16 validation remains:

- clean local database reset PASS;
- local database lint PASS with no schema errors;
- dedicated Slice 16 pgTAP 42 / 42 PASS;
- Slice 11 compatibility 59 / 59 PASS;
- Slice 12 compatibility 63 / 63 PASS;
- Slice 13 compatibility 53 / 53 PASS;
- Slice 14 compatibility 42 / 42 PASS;
- Slice 15 compatibility 38 / 38 PASS;
- focused Sprint 11 Slice 11 through 16 validation 297 / 297 PASS;
- full local pgTAP regression 33 files / 2047 tests PASS;
- canonical permissions 68;
- canonical role-permission mappings 241;
- exact six-column `public.booking_qc_passes` relation;
- exact `public.record_booking_qc_pass(uuid)` RPC;
- unauthorized additional QC / Pixieset / delivery persistence count 0;
- existing `editing.write` remains the QC-pass mutation authority;
- existing `editing.read` remains the QC-pass read authority;
- immutable affirmative QC Pass evidence validated;
- exact canonical Stage 14 `editing_in_progress` -> Stage 15 `qc_pending`
  source-transition lineage validated;
- source transition identifier is snapshotted;
- strict Stage-15-only idempotent replay validated;
- one first-success `booking.qc_passed` structural audit validated;
- current Stage 15 identifier is recorded in audit metadata;
- no second evidence or audit on valid replay;
- no booking journey transition is created;
- booking remains exactly Stage 15 `qc_pending`;
- no Stage 15 -> 16 authority introduced;
- no QC fail/result lifecycle introduced;
- no Pixieset/gallery persistence introduced;
- no delivery persistence introduced;
- generated Supabase types freshly regenerated locally;
- generated-types semantic delta exactly
  `booking_qc_passes` plus `record_booking_qc_pass`;
- generated-types diff 66 insertions / 0 deletions;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS with non-blocking pre-existing dependency,
  deprecation and bundle-size warnings only;
- diff hygiene PASS.

### Reconciled implementation boundary

Exact Slice 16 implementation boundary:

1. `src/integrations/supabase/types.ts`
   — 66 insertions / 0 deletions;
2. `supabase/migrations/20260828150000_sprint11_qc_pass_evidence_foundation.sql`
   — 930 insertions / 0 deletions;
3. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
   — 2 insertions / 1 deletion;
4. `supabase/tests/sprint11_editing_start_evidence_test.sql`
   — 3 insertions / 1 deletion;
5. `supabase/tests/sprint11_qc_pass_evidence_test.sql`
   — 1552 insertions / 0 deletions;
6. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
   — 3 insertions / 1 deletion;
7. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`
   — 1 insertion / 0 deletions.

Total implementation diff:

- 7 files;
- 2557 insertions;
- 3 deletions.

### Reconciled scope containment

Slice 16 closes only:

Stage 15 `qc_pending`
->
immutable affirmative QC Pass evidence
->
booking remains Stage 15 `qc_pending`

Still excluded:

- QC failure/result lifecycle;
- mutable QC workflow;
- reviewer assignment;
- QC notes or scores;
- rework/retouch workflow;
- image-level QC;
- Stage 15 -> 16;
- Pixieset/gallery persistence;
- gallery URL or synchronization authority;
- delivery persistence;
- Stage 16 -> 17;
- payment/refund mutation;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Reconciliation conclusion

Sprint 11 Slice 16 implementation and governance closeout are pushed and
independently verified.

This two-document checkpoint records the reconciled remote state.

This reconciliation commit remains local until separately pushed and
independently verified.

No Stage 15 -> 16 implementation boundary is authorized by this
reconciliation.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 16 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 17 Technical Design Freeze — 2026-08-28

### Slice title

**Sprint 11 Slice 17 — Controlled Stage 15 -> 16 / Pixieset Gallery Ready Advancement Gate**

### Frozen baseline

Exact remotely reconciled parent:

`455593af7c4b322188bc929441e18df219d09730`

— `docs: reconcile sprint 11 slice 16 remote state`

The canonical journey catalogue currently contains exactly:

- Stage 15 — `qc_pending` — active;
- Stage 16 — `pixieset_gallery_ready` — active.

The canonical relevant authority topology remains:

- `booking.stage.advance`
  — `client_coordinator`, `founder`, `studio_manager`;
- `editing.read`
  — `client_coordinator`, `editor`, `founder`, `studio_manager`;
- `editing.write`
  — `editor`, `founder`, `studio_manager`;
- `delivery.read`
  — `album_coordinator`, `client_coordinator`, `editor`,
    `founder`, `photographer`, `studio_manager`;
- `delivery.write`
  — `editor`, `founder`, `studio_manager`.

Canonical permission totals remain:

- permissions: 68;
- role-permission mappings: 241.

The corrected local baseline probe confirms:

- zero public functions whose name contains `gallery` or `pixieset`;
- zero existing public function definitions containing
  `pixieset_gallery_ready`;
- zero public persistence relations whose name contains
  `gallery`, `pixieset` or `delivery`.

The immutable Slice 16 prerequisite already exists:

`public.booking_qc_passes`

with exact affirmative QC Pass lineage.

### Frozen architectural purpose

Slice 17 introduces the single controlled journey authority required to move
a booking from exact Stage 15 `qc_pending` to exact Stage 16
`pixieset_gallery_ready`.

Slice 17 is a journey-advancement gate only.

The authoritative manual invocation of this gate means the authorized journey
actor is declaring that the booking may enter the Pixieset Gallery Ready
journey stage after canonical QC Pass evidence exists.

The Stage 16 name does not create or imply a persisted Pixieset integration
object, gallery URL, synchronization record, delivery record, API call or
external-system authority.

### Frozen authority model

Journey mutation authority remains the existing:

`booking.stage.advance`

No new permission is introduced.

No new role-permission mapping is introduced.

Exact journey-authorized role topology remains:

- `client_coordinator`;
- `founder`;
- `studio_manager`.

Editor does not receive journey advancement.

Photographer does not receive journey advancement.

Album Coordinator does not receive journey advancement.

Marketing does not receive journey advancement.

Slice 17 does not require:

- `editing.write`;
- `editing.read`;
- `delivery.write`;
- `delivery.read`;
- `review.write`;
- `review.read`;
- `finance.read`;
- `payment.read`;
- `booking.team.assign`.

### Frozen RPC contract

Slice 17 introduces exactly one application RPC:

`public.mark_booking_pixieset_gallery_ready(p_booking_id uuid)`

Return type:

`public.bookings`

The RPC must be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated`;
- not executable by `PUBLIC`;
- not executable by `anon`;
- not executable by `service_role`.

The RPC requires the current actor to be:

- authenticated;
- an active member of the booking organization;
- authorized by `booking.stage.advance`;
- within the booking branch scope when the booking has a branch.

### Frozen synchronization root

The booking row remains the canonical synchronization root.

The RPC must lock the booking before resolving journey state and prerequisite
evidence.

Exactly one current `booking_journey_states` row must exist for the booking.

### Frozen first-execution source state

First execution is permitted only when the current journey stage is exactly:

Stage 15 — `qc_pending`

The current Stage 15 catalogue row must be active.

Any earlier stage is rejected.

Any later stage other than the exact valid Stage 16 replay state is rejected.

### Frozen QC Pass prerequisite

First execution requires exactly one immutable:

`public.booking_qc_passes`

row for the same organization and booking.

The gate consumes the QC Pass evidence; it does not create, update, delete or
re-record QC Pass evidence.

The QC Pass row's:

`source_qc_pending_transition_id`

must resolve to the same organization and booking and must identify the
historical `qc_pending` transition whose destination is the booking's current
Stage 15 journey state.

The source transition must have:

`transition_key = 'qc_pending'`

and:

`to_stage_id = current Stage 15 id`.

The QC Pass timestamp must not precede that transition timestamp.

Slice 17 trusts the deeper immutable Slice 16 provenance guarantee that this
stored source transition is the canonical Stage 14 -> 15 transition.

Slice 17 therefore does not independently reopen or restate the upstream
Stage 14 `editing_in_progress` source-stage predicate.

Slice 17 does not require the historical QC Pass actor or historical
`qc_pending` transition actor to remain active.

Only the current journey actor must satisfy current authorization.

### Frozen pre-advancement uniqueness

While the booking is still at exact Stage 15, there must be zero existing
canonical Stage 15 -> 16 transitions for that booking with:

`transition_key = 'pixieset_gallery_ready'`.

A pre-existing destination transition while the current state remains
Stage 15 is corruption and must be rejected.

### Frozen Stage 16 destination

Exactly one active destination stage must exist for the organization with:

- `stage_order = 16`;
- `stage_key = 'pixieset_gallery_ready'`;
- `is_active = true`.

No alternate Stage 16 destination may be selected.

### Frozen first-success journey mutation

First successful execution performs exactly:

1. one append to `public.booking_stage_transitions`;
2. one optimistic update to `public.booking_journey_states`;
3. one structural audit append.

The journey transition must be:

Stage 15 `qc_pending`
->
Stage 16 `pixieset_gallery_ready`

with exact:

`transition_key = 'pixieset_gallery_ready'`.

The transition actor must be the current authorized journey actor.

The journey-state update must change only the canonical journey progression
fields required by the existing journey model, including:

- `current_stage_id`;
- `stage_entered_at`;
- `version`;
- `updated_at`;
- `updated_by`.

The update must prove the expected current Stage 15 identifier and expected
journey-state version.

Exactly one row must update.

Journey-state version increments by exactly one.

### Frozen audit contract

First success appends exactly one audit event:

`booking.pixieset_gallery_ready`

The audit is structural only.

No free-text operational note is introduced.

Audit values/metadata may contain only structural identifiers and timestamps
required to prove the advancement, including:

- booking identifier;
- QC Pass evidence identifier;
- stored source `qc_pending` transition identifier;
- Stage 15 source identifier;
- Stage 16 destination identifier;
- transition timestamp.

The audit must not introduce gallery URLs, client-visible secrets,
credentials, arbitrary notes or external Pixieset payloads.

### Frozen replay contract

Idempotent replay is allowed only when the booking is already at exact:

Stage 16 — `pixieset_gallery_ready`.

Replay must prove exactly one historical canonical transition for the same
organization and booking with:

- source Stage 15 `qc_pending`;
- destination equal to the current Stage 16 state;
- `transition_key = 'pixieset_gallery_ready'`.

Valid replay returns the booking without creating:

- a second journey transition;
- a second audit event;
- a second version increment;
- a QC Pass mutation;
- any gallery or delivery persistence.

Replay trusts the already-created canonical journey transition and does not
re-execute the first-success QC Pass prerequisite workflow.

A Stage 16 current state without exact canonical transition history is
rejected.

Stage 17 or later is rejected.

### Frozen persistence boundary

Slice 17 introduces no new business persistence relation.

In particular, Slice 17 introduces no:

- Pixieset gallery relation;
- gallery URL relation;
- gallery synchronization relation;
- delivery relation;
- QC result relation;
- mutable QC job relation;
- reviewer assignment relation.

The only durable business mutation is the existing journey transition/state
model plus existing audit infrastructure.

### Frozen upstream containment

Slice 17 must not mutate or recreate:

- `booking_qc_passes`;
- `booking_editing_completions`;
- `booking_editing_starts`;
- selection evidence;
- image entitlement;
- finance or payment state;
- team assignments.

Slice 17 must not call:

- `record_booking_qc_pass`;
- `record_booking_editing_completion`;
- `record_booking_editing_start`;
- `mark_booking_qc_pending`;
- `mark_booking_editing_in_progress`.

Existing immutable prerequisite records are consumed as evidence only.

### Frozen downstream containment

Slice 17 does not implement:

- Pixieset API integration;
- Pixieset credentials;
- external API calls;
- gallery creation;
- gallery identifiers;
- gallery URLs;
- gallery synchronization;
- client gallery access;
- delivery persistence;
- final delivery evidence;
- Stage 16 -> 17;
- review requests;
- payment/refund mutation;
- UI/runtime integration;
- mock-store replacement.

### Frozen generated-types expectation

Generated Supabase types may change only as required to expose the new RPC:

`mark_booking_pixieset_gallery_ready`

No new table type is expected because Slice 17 introduces no relation.

### Frozen implementation boundary

Implementation is initially restricted to exactly three artifacts:

1. `supabase/migrations/<timestamp>_sprint11_stage15_16_pixieset_gallery_ready_gate_foundation.sql`;
2. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`;
3. `src/integrations/supabase/types.ts`.

No fourth implementation artifact is authorized by this freeze.

Historical Sprint 11 test files are not authorized for modification by this
freeze.

If focused or full regression later proves that a historical assertion
legitimately requires a narrow compatibility exclusion because of the new
canonical Slice 17 authority, implementation must STOP.

The historical test must not be modified until a separate governance
compatibility amendment explicitly authorizes:

- the exact historical test file;
- the exact assertion;
- the exact compatibility exclusion;
- the amended implementation-artifact boundary.

### Frozen validation contract

Before any implementation commit, Slice 17 must prove locally:

- clean local database reset PASS;
- local database lint PASS;
- dedicated Slice 17 pgTAP PASS;
- focused Sprint 11 historical compatibility PASS;
- full local pgTAP regression PASS;
- permissions remain exactly 68;
- role-permission mappings remain exactly 241;
- exact RPC signature exists;
- RPC uses `SECURITY DEFINER`;
- RPC uses empty `search_path`;
- authenticated EXECUTE allowed;
- PUBLIC EXECUTE denied;
- anon EXECUTE denied;
- service_role EXECUTE denied;
- exact `booking.stage.advance` topology unchanged;
- Editor cannot invoke the gate;
- branch scope enforced;
- missing QC Pass evidence rejected;
- inconsistent QC Pass/current-Stage-15 lineage rejected;
- exact Stage 15 -> 16 first success validated;
- transition key exact;
- version increments exactly once;
- one first-success audit exact;
- exact Stage 16 replay validated;
- replay creates no second transition/audit/version mutation;
- corrupt Stage 16 replay lineage rejected;
- earlier-stage invocation rejected;
- Stage 17-or-later invocation rejected;
- no QC Pass mutation;
- no new persistence relation;
- zero gallery/Pixieset/delivery persistence remains true;
- generated types freshly regenerated from the clean local database;
- generated-types semantic delta limited to the new RPC;
- Prettier PASS;
- targeted ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- `git diff --check` PASS.

### Remote-state restrictions

Remote Supabase remains HOLD.

Production remains HOLD.

No remote migration is authorized by this freeze.

No Stage 16 -> 17 authority is authorized by this freeze.

### Freeze conclusion

Sprint 11 Slice 17 is technically frozen as one controlled
Stage 15 `qc_pending`
->
Stage 16 `pixieset_gallery_ready`
journey gate consuming immutable QC Pass evidence.

Implementation has not started.

**SPRINT 11 SLICE 17 — TECHNICAL DESIGN FROZEN / IMPLEMENTATION NOT STARTED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 17 Governance Closeout — 2026-08-28

### Exact authority chain

Technical-design freeze:

`c36c6bb1583f6eff0c5fe985fa7f9668d4685913`
— `docs: freeze sprint 11 slice 17`

Implementation:

`757e364c2a73faaec342bd9d0dbdea5da2165810`
— `feat: add pixieset gallery ready advancement gate`

Implementation parent:

`c36c6bb1583f6eff0c5fe985fa7f9668d4685913`

No compatibility governance amendment was required.

Focused regression initially exposed two historical Stage-14 function-scan
false positives caused only by the literal `editing_in_progress` token inside
a Slice 17 function comment.

The Slice 17 migration comment was narrowed without changing runtime authority,
and both historical assertions then passed unchanged.

### Delivered Slice 17 boundary

Slice 17 delivers exactly one controlled journey gate:

Stage 15 `qc_pending`
->
Stage 16 `pixieset_gallery_ready`

through:

`public.mark_booking_pixieset_gallery_ready(p_booking_id uuid)`

The RPC returns:

`public.bookings`

Journey mutation authority remains the existing:

`booking.stage.advance`

with exact role topology:

- `client_coordinator`;
- `founder`;
- `studio_manager`.

No new permission or role-permission mapping was introduced.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

### Accepted first-success contract

First execution requires:

- authenticated actor;
- active organization membership;
- `booking.stage.advance`;
- booking branch scope;
- exactly one current journey state;
- exact active Stage 15 `qc_pending`;
- exactly one immutable `public.booking_qc_passes` row;
- QC Pass source transition belonging to the same organization and booking;
- source transition key exactly `qc_pending`;
- source transition destination equal to current Stage 15;
- QC Pass timestamp not earlier than that source transition;
- zero pre-existing canonical Stage 15 -> 16 transition.

First success performs exactly:

1. one Stage 15 -> 16 `booking_stage_transitions` append;
2. one optimistic `booking_journey_states` progression update;
3. one structural `booking.pixieset_gallery_ready` audit.

Journey-state version increments exactly once.

The current authorized journey actor is attributed to the transition and state
update.

### Accepted replay contract

Exact Stage 16 `pixieset_gallery_ready` replay is idempotent.

Replay proves exactly one canonical historical:

Stage 15 `qc_pending`
->
Stage 16 `pixieset_gallery_ready`

transition with exact transition key:

`pixieset_gallery_ready`

Valid replay creates:

- no second transition;
- no second audit;
- no second version increment;
- no QC Pass mutation;
- no gallery or delivery persistence.

Stage 16 without valid canonical history fails closed.

Earlier stages fail closed.

Stage 17 or later fails closed.

### Persistence and authority containment

Slice 17 introduces no new business relation.

It introduces no:

- Pixieset gallery relation;
- gallery URL persistence;
- gallery synchronization persistence;
- delivery persistence;
- QC-result persistence;
- reviewer assignment;
- mutable QC workflow.

The immutable QC Pass prerequisite is consumed as evidence only.

Slice 17 does not call or recreate:

- `record_booking_qc_pass`;
- `record_booking_editing_completion`;
- `record_booking_editing_start`;
- `mark_booking_qc_pending`;
- `mark_booking_editing_in_progress`.

It imports no `editing.*`, `delivery.*`, review, finance, payment or
team-assignment mutation authority.

Stage 16 -> 17 remains outside Slice 17.

### Accepted validation

Slice 17 validation is accepted as:

- clean local database reset PASS;
- local database lint PASS with no schema errors;
- permissions exactly 68;
- role-permission mappings exactly 241;
- exact active Stage 15 `qc_pending`;
- exact active Stage 16 `pixieset_gallery_ready`;
- authenticated RPC EXECUTE allowed;
- PUBLIC EXECUTE denied;
- anon EXECUTE denied;
- service_role EXECUTE denied;
- downstream gallery/Pixieset/delivery persistence count 0;
- dedicated Slice 17 pgTAP 38 / 38 PASS;
- focused Sprint 11 regression 16 files / 930 tests PASS;
- full local pgTAP regression 34 files / 2085 tests PASS;
- historical Slice 12 and Slice 13 compatibility assertions PASS unchanged;
- generated Supabase types freshly regenerated locally;
- generated-types semantic delta limited exactly to
  `mark_booking_pixieset_gallery_ready`;
- generated-types diff 22 insertions / 0 deletions;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS with non-blocking existing dependency,
  deprecation and bundle-size warnings only;
- `git diff --check` PASS.

### Exact implementation boundary

Implementation commit contains exactly:

1. `src/integrations/supabase/types.ts`
   — 22 insertions / 0 deletions;
2. `supabase/migrations/20260828154710_sprint11_stage15_16_pixieset_gallery_ready_gate_foundation.sql`
   — 929 insertions / 0 deletions;
3. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`
   — 1472 insertions / 0 deletions.

Total implementation diff:

- 3 files;
- 2423 insertions;
- 0 deletions.

### Independent remote verification

Independent GitHub verification confirms:

- `architecture-rebuild` points exactly to
  `757e364c2a73faaec342bd9d0dbdea5da2165810`;
- remote implementation subject is exactly
  `feat: add pixieset gallery ready advancement gate`;
- remote implementation parent is exactly
  `c36c6bb1583f6eff0c5fe985fa7f9668d4685913`;
- freeze -> implementation is exactly one commit ahead / zero behind;
- the implementation contains exactly the three authorized artifacts;
- the remote implementation diff is exactly 2423 insertions / 0 deletions.

### Governance conclusion

Sprint 11 Slice 17 is implemented within the exact frozen authority boundary,
fully validated locally, committed, pushed and independently verified.

This closeout modifies governance documentation only.

The closeout remains local until separately committed, pushed and independently
verified.

No Pixieset external integration, gallery persistence, delivery persistence or
Stage 16 -> 17 authority is authorized by this closeout.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 17 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / PUSHED / IMPLEMENTATION REMOTELY VERIFIED / GOVERNANCE CLOSEOUT PENDING COMMIT / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 17 Remote-State Reconciliation — 2026-08-28

### Reconciled authority chain

Technical-design freeze:

`c36c6bb1583f6eff0c5fe985fa7f9668d4685913`
— `docs: freeze sprint 11 slice 17`

Implementation:

`757e364c2a73faaec342bd9d0dbdea5da2165810`
— `feat: add pixieset gallery ready advancement gate`

Governance closeout:

`76fedeaecd728706a8c9f0d97ab0e96d2abbd822`
— `docs: close sprint 11 slice 17`

Closeout parent:

`757e364c2a73faaec342bd9d0dbdea5da2165810`

No Slice 17 compatibility-governance amendment was required.

### Independent remote verification

Independent GitHub verification confirms:

- `architecture-rebuild` points exactly to
  `76fedeaecd728706a8c9f0d97ab0e96d2abbd822`;
- remote closeout subject is exactly
  `docs: close sprint 11 slice 17`;
- remote closeout parent is exactly
  `757e364c2a73faaec342bd9d0dbdea5da2165810`;
- implementation -> closeout is exactly one commit ahead / zero behind;
- the closeout modifies exactly two governance documents;
- `docs/CURRENT_MILESTONE.md` contains 225 insertions / 0 deletions;
- `docs/SPRINT_MASTER_REGISTER.md` contains 225 insertions / 0 deletions;
- total closeout diff is exactly 450 insertions / 0 deletions;
- local and remote branch parity after the closeout push is exactly `0 0`;
- the local worktree is clean.

This reconciliation records pushed remote governance state only.

It does not re-run or alter Slice 17 implementation.

### Reconciled accepted implementation state

Accepted Slice 17 validation remains:

- clean local database reset PASS;
- local database lint PASS with no schema errors;
- permissions exactly 68;
- role-permission mappings exactly 241;
- exact active Stage 15 `qc_pending`;
- exact active Stage 16 `pixieset_gallery_ready`;
- exact `public.mark_booking_pixieset_gallery_ready(uuid)` RPC;
- authenticated RPC EXECUTE allowed;
- PUBLIC EXECUTE denied;
- anon EXECUTE denied;
- service_role EXECUTE denied;
- existing `booking.stage.advance` authority retained;
- exact journey-authorized role topology retained:
  `client_coordinator`, `founder`, `studio_manager`;
- immutable `public.booking_qc_passes` prerequisite consumed without mutation;
- exact QC Pass/current-Stage-15 lineage validated;
- first success appends exactly one Stage 15 -> 16 transition;
- transition key exactly `pixieset_gallery_ready`;
- journey-state version increments exactly once;
- one first-success `booking.pixieset_gallery_ready` structural audit;
- exact Stage 16 idempotent replay validated;
- replay creates no second transition, audit or version increment;
- corrupt Stage 16 replay lineage rejected;
- earlier-stage invocation rejected;
- Stage 17-or-later invocation rejected;
- no QC Pass mutation;
- no new business persistence relation;
- gallery/Pixieset/delivery persistence count remains zero;
- dedicated Slice 17 pgTAP 38 / 38 PASS;
- focused Sprint 11 regression 16 files / 930 tests PASS;
- full local pgTAP regression 34 files / 2085 tests PASS;
- historical Slice 12 and Slice 13 compatibility assertions PASS unchanged;
- generated Supabase types semantic delta limited exactly to
  `mark_booking_pixieset_gallery_ready`;
- generated-types diff 22 insertions / 0 deletions;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS with non-blocking existing dependency,
  deprecation and bundle-size warnings only;
- diff hygiene PASS.

### Reconciled implementation boundary

Exact Slice 17 implementation boundary remains:

1. `src/integrations/supabase/types.ts`
   — 22 insertions / 0 deletions;
2. `supabase/migrations/20260828154710_sprint11_stage15_16_pixieset_gallery_ready_gate_foundation.sql`
   — 929 insertions / 0 deletions;
3. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`
   — 1472 insertions / 0 deletions.

Total implementation diff:

- 3 files;
- 2423 insertions;
- 0 deletions.

### Reconciled scope containment

Slice 17 closes only:

Stage 15 `qc_pending`
->
controlled `booking.stage.advance`
->
Stage 16 `pixieset_gallery_ready`

with immutable QC Pass evidence as the prerequisite.

Still excluded:

- Pixieset API integration;
- Pixieset credentials;
- external gallery creation;
- gallery identifier persistence;
- gallery URL persistence;
- gallery synchronization persistence;
- client gallery-access persistence;
- delivery persistence;
- final-delivery evidence;
- Stage 16 -> 17;
- review-request workflow;
- payment/refund mutation;
- UI/runtime integration;
- mock-store replacement;
- Remote Supabase deployment;
- Production deployment.

### Reconciliation conclusion

Sprint 11 Slice 17 implementation and governance closeout are pushed and
independently verified.

This two-document checkpoint records the reconciled remote state.

This reconciliation commit remains local until separately committed, pushed
and independently verified.

No Stage 16 -> 17, delivery, external Pixieset integration or other downstream
authority is authorized by this reconciliation.

Only after this reconciliation is separately pushed and independently verified
may the next downstream boundary enter fresh read-only discovery.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 17 — IMPLEMENTED / FULLY VALIDATED LOCALLY / COMMITTED / GOVERNANCE CLOSED / PUSHED / REMOTELY RECONCILED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Sprint 11 Slice 18 Technical-Design Freeze — 2026-08-28

### Slice title

**Sprint 11 Slice 18 — Delivery Confirmation Evidence Foundation**

### Discovery baseline

Read-only discovery established:

- exact active Stage 16 `pixieset_gallery_ready`;
- exact active Stage 17 `delivered`;
- no existing public delivery-confirmation persistence relation;
- no existing `record_booking_delivery_confirmation(uuid)` RPC;
- no existing gallery/Pixieset/delivery business persistence;
- no existing canonical delivery function;
- no existing `booking.delivery_confirmed` audit event;
- no existing `booking.delivered` audit event;
- permissions remain exactly 68;
- role-permission mappings remain exactly 241.

Existing authority remains:

`delivery.write`
- `editor`;
- `founder`;
- `studio_manager`.

Existing read authority remains:

`delivery.read`.

Existing journey mutation authority remains separately:

`booking.stage.advance`
- `client_coordinator`;
- `founder`;
- `studio_manager`.

The difference between delivery-operation authority and journey-advance
authority is intentional and preserved.

### Architectural decision

Slice 18 does not advance Stage 16 to Stage 17.

Slice 18 introduces immutable canonical evidence that authorized delivery work
has been confirmed while the booking remains at exact Stage 16
`pixieset_gallery_ready`.

A later separately governed slice may consume this evidence under
`booking.stage.advance` to authorize Stage 16 -> 17.

### Canonical relation

Slice 18 introduces exactly:

`public.booking_delivery_confirmations`

with exactly six columns:

1. `id uuid`;
2. `organization_id uuid`;
3. `booking_id uuid`;
4. `source_pixieset_gallery_ready_transition_id uuid`;
5. `delivered_at timestamptz`;
6. `delivered_by uuid`.

The relation is immutable.

There is at most one canonical delivery-confirmation evidence row per
organization and booking.

The source transition is also uniquely attributable within the organization.

### Canonical source lineage

Delivery confirmation is valid only at exact active Stage 16
`pixieset_gallery_ready`.

Its source transition must resolve for the same organization and booking to
exact canonical immediate lineage:

Stage 15 `qc_pending`
->
Stage 16 `pixieset_gallery_ready`

with transition key exactly:

`pixieset_gallery_ready`

and destination equal to the booking's current Stage 16 journey state.

The source transition actor does not need to remain an active organization
member.

Slice 18 validates only its immediate Stage 15 -> 16 lineage.

It does not reopen or independently reconstruct QC Pass, Editing Completion,
Editing Start, selection, entitlement, finance or other deeper prerequisites.

`delivered_at` must not precede the canonical Stage 16 source-transition
timestamp.

### Canonical recorder

Slice 18 introduces exactly:

`public.record_booking_delivery_confirmation(p_booking_id uuid)`

returning:

`public.booking_delivery_confirmations`

The RPC must be:

- `SECURITY DEFINER`;
- empty `search_path`;
- executable only by `authenticated`;
- denied to PUBLIC;
- denied to anon;
- denied to service_role.

### Mutation authority

Recording delivery confirmation requires existing:

`delivery.write`

No new permission is introduced.

No role-permission mapping is introduced.

Canonical totals remain:

- permissions: 68;
- role-permission mappings: 241.

Exact `delivery.write` role topology remains:

- `editor`;
- `founder`;
- `studio_manager`.

The RPC also requires:

- authenticated actor;
- active organization membership;
- booking branch scope.

The booking row is the canonical synchronization root and is locked first.

### First-record contract

First execution requires:

- non-null booking id;
- existing booking;
- authenticated actor;
- active organization membership;
- `delivery.write`;
- booking branch scope;
- exactly one current journey state;
- exact active Stage 16 `pixieset_gallery_ready`;
- exactly one canonical Stage 15 -> 16
  `pixieset_gallery_ready` source transition;
- source transition belonging to the same organization and booking;
- source transition destination equal to current Stage 16;
- delivery-confirmation timestamp not earlier than source transition;
- zero existing delivery-confirmation evidence for the booking.

First success performs exactly:

1. one immutable `booking_delivery_confirmations` insert;
2. one structural `booking.delivery_confirmed` audit.

It performs no journey-state update.

It appends no booking-stage transition.

It does not move the booking to Stage 17.

### Replay contract

Replay is strict Stage-16-only idempotency.

If canonical delivery-confirmation evidence already exists while the booking
remains exact Stage 16, replay validates that:

- evidence belongs to the same organization and booking;
- stored source transition equals the canonical current Stage-16 entry
  transition;
- `delivered_at` is not earlier than the source transition.

Valid replay returns the same immutable evidence row.

Valid replay creates:

- no second evidence row;
- no second audit;
- no journey mutation;
- no version increment;
- no gallery/Pixieset persistence.

Existing inconsistent evidence fails closed.

Earlier-stage invocation fails closed.

Stage 17 or later invocation fails closed.

### Immutable lifecycle

Authenticated clients receive no direct INSERT, UPDATE or DELETE authority on
`booking_delivery_confirmations`.

The evidence relation uses forced RLS.

Authenticated SELECT is governed by existing:

`delivery.read`

plus booking branch scope.

The canonical mutation path is the recorder RPC.

Evidence UPDATE and DELETE are forbidden.

### Audit contract

First success appends exactly:

`booking.delivery_confirmed`

The audit is structural only.

Allowed audit context is limited to identifiers and timestamps such as:

- booking id;
- delivery-confirmation evidence id;
- source Pixieset Gallery Ready transition id;
- Stage 16 id;
- delivered-at timestamp.

The audit must not contain:

- gallery URL;
- password;
- PIN;
- credentials;
- API tokens;
- download URL;
- client-access secrets;
- Pixieset payloads;
- external response payloads;
- invoice or contract links;
- free-text delivery notes.

`booking.delivered` is not introduced by Slice 18 and remains available for a
future separately governed Stage 16 -> 17 journey gate.

### Persistence containment

Slice 18 introduces no Pixieset integration persistence.

It introduces no:

- gallery relation;
- Pixieset gallery identifier;
- gallery URL;
- password or PIN;
- Pixieset API credential;
- external synchronization state;
- download URL;
- download expiry;
- store/order persistence;
- favorites persistence;
- client-access persistence;
- invoice/contract-link persistence;
- mutable delivery workflow;
- delivery job relation.

The only new business persistence is the immutable six-column
`booking_delivery_confirmations` evidence relation.

### Authority containment

Slice 18 does not require or import:

- `booking.stage.advance`;
- `editing.read`;
- `editing.write`;
- `review.read`;
- `review.write`;
- finance authority;
- payment authority;
- team-assignment authority.

Slice 18 does not call or recreate:

- `mark_booking_pixieset_gallery_ready`;
- `record_booking_qc_pass`;
- `mark_booking_qc_pending`;
- `record_booking_editing_completion`;
- `record_booking_editing_start`;
- `mark_booking_editing_in_progress`.

### Explicitly excluded downstream scope

Slice 18 does not authorize:

- Stage 16 -> 17;
- `delivered` journey transition;
- `booking.delivered` audit;
- final-delivery journey gate;
- Pixieset API integration;
- Pixieset credentials;
- gallery creation;
- external gallery synchronization;
- UI/runtime integration;
- mock-store replacement;
- review-request workflow;
- heirloom workflow;
- payment/refund mutation;
- Remote Supabase deployment;
- Production deployment.

### Historical-test compatibility boundary

Read-only discovery identified exactly four historical pgTAP files whose
current-schema future-zero persistence scans would otherwise classify the new
canonical delivery evidence as a historical-slice regression:

1. `supabase/tests/sprint11_editing_completion_evidence_test.sql`;
2. `supabase/tests/sprint11_qc_pass_evidence_test.sql`;
3. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`;
4. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`.

Slice 18 authorizes one narrow compatibility edit in each listed file:

exclude exact relation:

`booking_delivery_confirmations`

from the historical global gallery/Pixieset/delivery persistence-count scan.

No historical test may:

- delete the assertion;
- skip the assertion;
- comment it out;
- replace the expected zero with a non-zero count;
- broaden the exclusion to arbitrary future relations;
- weaken unrelated authority checks;
- alter historical runtime semantics.

No other historical test modification is authorized by this freeze.

Because this compatibility requirement is discovered and explicitly frozen
before implementation, no separate compatibility-governance amendment is
currently required.

### Expected implementation artifact boundary

Slice 18 implementation is expected to modify exactly seven artifacts:

1. one new Slice 18 delivery-confirmation-evidence migration;
2. `supabase/tests/sprint11_delivery_confirmation_evidence_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint11_editing_completion_evidence_test.sql`;
5. `supabase/tests/sprint11_qc_pass_evidence_test.sql`;
6. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`;
7. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`.

No eighth implementation artifact is authorized without a new governance
decision.

Generated Supabase types may change semantically only for:

- `booking_delivery_confirmations`;
- `record_booking_delivery_confirmation`.

Exact generated-types line counts are not frozen in advance.

### Required validation

Implementation acceptance will require at minimum:

- clean local database reset PASS;
- local database lint PASS with no schema errors;
- permissions exactly 68;
- role-permission mappings exactly 241;
- relation exactly six columns;
- forced RLS;
- authenticated SELECT governed by `delivery.read`;
- authenticated direct mutation denied;
- evidence UPDATE and DELETE denied;
- authenticated RPC EXECUTE allowed;
- PUBLIC RPC EXECUTE denied;
- anon RPC EXECUTE denied;
- service_role RPC EXECUTE denied;
- exact active Stage 16 requirement;
- exact Stage 15 -> 16 source lineage;
- timestamp ordering enforced;
- `delivery.write` required;
- exact delivery-write role topology retained;
- Editor can record delivery confirmation without receiving journey authority;
- Client Coordinator cannot record delivery confirmation merely from
  `booking.stage.advance`;
- first record creates exactly one evidence row;
- first record creates exactly one `booking.delivery_confirmed` audit;
- replay returns the same evidence row;
- replay creates no second audit;
- no journey transition created;
- no journey-state version change;
- malformed source lineage rejected;
- earlier-stage invocation rejected;
- Stage 17-or-later invocation rejected;
- no external gallery/Pixieset persistence;
- four authorized historical compatibility assertions PASS;
- dedicated Slice 18 pgTAP PASS;
- focused Sprint 11 regression PASS;
- full local pgTAP regression PASS;
- generated Supabase types freshly regenerated;
- generated-types semantic delta constrained to the frozen boundary;
- Prettier PASS;
- targeted generated-types ESLint PASS;
- TypeScript `--noEmit` PASS;
- production build PASS;
- diff hygiene PASS.

### Governance conclusion

Sprint 11 Slice 18 is frozen as an immutable Delivery Confirmation Evidence
Foundation only.

The booking remains at exact Stage 16 after delivery confirmation is recorded.

Stage 16 -> 17 requires a later separately governed journey gate consuming this
evidence under `booking.stage.advance`.

This technical-design freeze modifies governance documentation only.

Implementation has not started.

Remote Supabase remains HOLD.

Production remains HOLD.

**SPRINT 11 SLICE 18 — TECHNICAL DESIGN FROZEN / IMPLEMENTATION NOT STARTED / REMOTE SUPABASE HOLD / PRODUCTION HOLD**

## Programme Authority Reconciliation and Sprint 11 Slice 18 Governance Amendment — 2026-08-29

### Governance Status

**APPROVED — PROGRAMME AUTHORITY RECONCILIATION**

**HOLD — SPRINT 11 SLICE 18 IMPLEMENTATION**

This amendment was created after a full review of the available Little Shots planning and operational authority library against the current repository architecture.

It does not roll back any previously completed engineering slice.

It does not authorize any database, application, integration, remote Supabase, or production change.

---

### 1. One Product, Multiple Product Surfaces

Little Shots is one connected product architecture.

The intended final production line is not a permanent separation between a website branch and a Studio OS branch.

The product may expose multiple surfaces, including:

- public Little Shots website and brand experience;
- AI Memory Guide;
- CRM and sales workflows;
- client-facing experiences;
- authenticated Studio OS;
- production, editing, QC, delivery, heirloom, team, and reporting workflows.

These surfaces may be deployed or routed separately while sharing governed domain truth where appropriate.

`main` is the eventual trusted production line.

`architecture-rebuild` is the controlled development and architecture-validation branch.

The branch name does not define a separate product.

---

### 2. Programme Phase Classification

The current production, shoot, selection, editing, QC, gallery, delivery, and heirloom work belongs to:

**Phase 2 — Studio Operations / Internal Studio Operating System**

Phase 1 remains the website, AI sales, CRM, commercial, booking, payment, privacy, consent, client-service, and related foundation.

Existing Phase 1 foundations remain valid dependencies of Phase 2.

Phase 2 work must not be represented as though it were part of the original Phase 1 sales sprint sequence.

---

### 3. Sprint Namespace Reconciliation

The planning library contains more than one sprint numbering sequence.

For governance and traceability, unqualified sprint numbers must not be assumed to refer to the same programme sequence.

The repository's current operational work shall be interpreted as:

**Phase 2 Studio Operations — Operational Sprint 11**

when referring to shoot/post-production operational work.

This is distinct from the earlier Phase 1 delivery backlog in which Sprint 11 and Sprint 12 refer to quotation work.

Future governance records must identify the programme/phase context whenever sprint numbering could be ambiguous.

---

### 4. Existing Completed Engineering Remains Preserved

Previously completed and validated slices remain historical approved implementation.

This reconciliation does not invalidate:

- shoot-completion evidence;
- controlled journey advancement already implemented;
- selection confirmation evidence;
- image-entitlement authority;
- selection/entitlement reconciliation;
- additional-image pricing authority;
- adjusted financial obligation authority;
- full-balance settlement authority;
- editing-start evidence;
- editing-in-progress advancement;
- editing-completion evidence;
- QC-pending advancement;
- QC-pass evidence;
- Pixieset-gallery-ready advancement;
- the existing RLS, RBAC, audit, idempotency, lineage, and least-privilege architecture.

No rollback or destructive rewrite is authorized by this amendment.

---

### 5. Upstream Operational Requirement Gap

The operational source material requires a post-shoot chain that includes, at minimum:

1. media-card custody and shot accounting;
2. controlled media ingestion;
3. deterministic file/count/checksum verification;
4. missing, duplicate, and corruption handling;
5. verified encrypted redundant backup;
6. controlled media-card release;
7. verified privacy-labelled handover to editing.

The current canonical Stage 11 -> 12 implementation consumes shoot-completion evidence but does not currently consume formal evidence for this entire operational chain.

Therefore:

**the shoot-to-selection lifecycle must not be declared operationally complete until this requirement gap is reconciled.**

This amendment does not yet prescribe the database shape.

A separate read-only discovery and technical-design checkpoint must determine whether these requirements need:

- new immutable evidence relations;
- a production-project or media-ingestion domain;
- additional controlled gates;
- integration-owned evidence;
- or another architecture consistent with the repository's domain rules.

No such implementation is authorized here.

---

### 6. Culling and Image-Lineage Requirement Gap

The operational editing specification also requires concepts including:

- verified-media production intake;
- human-led culling;
- source-preserving image lineage;
- derived-version integrity;
- privacy exclusions;
- controlled client proofing;
- immutable submitted selection versions;
- revision governance;
- QC and export readiness.

Existing selection, editing, entitlement, finance, and QC foundations remain valid sub-capabilities.

However, they must not be interpreted as proving that all upstream media, culling, image-lineage, proofing, and production requirements are already implemented.

These requirements require separate governed reconciliation.

---

### 7. Stage 17 Delivery Semantics

The existing canonical journey currently places:

- Stage 16 — `pixieset_gallery_ready`;
- Stage 17 — `delivered`;
- Stage 18 — `album_frame_production`.

Because physical album/frame production occurs after Stage 17 in the current canonical ordering, Stage 17 must not be interpreted as proof that the entire booking, including all physical products, has been finally delivered.

Until separately governed otherwise, the intended business interpretation of the Stage 16 -> 17 boundary is:

**digital gallery delivery / digital delivery completion**

rather than complete final project handover.

The existing database key `delivered` is not renamed by this governance-only amendment.

Any schema-key, label, UI, audit-action, or downstream journey change requires a separately frozen technical design.

---

### 8. Sprint 11 Slice 18 Amendment

The previously frozen Sprint 11 Slice 18 design remains part of the historical governance record.

However, its implementation authorization is now **SUSPENDED**.

The generic concepts:

- `booking_delivery_confirmations`;
- `record_booking_delivery_confirmation(...)`;
- `booking.delivery_confirmed`;

must not be implemented from the previous freeze until delivery semantics are re-frozen with an unambiguous digital-gallery boundary.

The evidence-first architecture itself remains approved in principle:

operational authority -> immutable evidence -> separate journey authority.

The authority separation between operational delivery work and journey advancement also remains approved in principle.

What is on HOLD is the current generic delivery naming and implementation boundary, not the least-privilege evidence pattern.

---

### 9. Required Next Checkpoint

Before Slice 18 implementation resumes, the next checkpoint is:

**Phase 2 Studio Operations — Post-Shoot Authority Reconciliation / Read-Only Discovery**

It must determine:

1. the correct media-custody domain boundary;
2. ingestion and checksum evidence requirements;
3. backup and redundancy evidence requirements;
4. editing-handover requirements;
5. culling and image-lineage requirements;
6. whether any existing journey gates require later compatibility amendments;
7. the exact meaning of Stage 17;
8. the exact digital-gallery delivery evidence name and audit contract;
9. how later physical-product delivery and final handover remain distinct;
10. the smallest safe implementation order.

Only after that checkpoint is frozen may Slice 18 or any prerequisite implementation resume.

---

### 10. Environment and Deployment Boundary

The following remain unchanged:

- Local development and read-only discovery: **AUTHORIZED**
- `architecture-rebuild`: **AUTHORIZED development branch**
- `main`: **NO CHANGE AUTHORIZED by this amendment**
- Remote Supabase mutation/deployment: **HOLD**
- Production deployment: **HOLD**

---

### Formal Checkpoint

**APPROVE — PROGRAMME / PHASE / SPRINT AUTHORITY RECONCILED**

**APPROVE — EXISTING COMPLETED ENGINEERING PRESERVED**

**REVISE — POST-SHOOT MEDIA / HANDOVER REQUIREMENTS REQUIRE RECONCILIATION**

**REVISE — STAGE 17 REQUIRES DIGITAL-DELIVERY SEMANTIC PRECISION**

**HOLD — SPRINT 11 SLICE 18 IMPLEMENTATION**

**NEXT — PHASE 2 STUDIO OPERATIONS POST-SHOOT READ-ONLY DISCOVERY**

## Phase 2 Studio Operations — Corrective Slice A Technical-Design Freeze — 2026-08-29

### Status

**APPROVED — TECHNICAL DESIGN FROZEN**

**IMPLEMENTATION NOT STARTED**

**REMOTE SUPABASE HOLD**

**PRODUCTION HOLD**

This slice is the first prerequisite correction identified by the Phase 2 Studio Operations post-shoot authority reconciliation.

It establishes the canonical approved media-card inventory required before custody, ingestion, checksum verification, backup, card release, editing handover, or strengthened Stage 11 -> 12 gating can be implemented.

---

### 1. Authority Boundary

Operational Sprint 11 requires an approved media-card inventory with unique IDs before the media-custody workflow begins.

The repository currently has no reusable equipment, asset, inventory, device, or media-card registry.

Therefore this slice introduces the smallest canonical inventory authority required to eliminate anonymous media cards.

This slice does not claim to complete US-125 Media-Card Custody and Shot Accounting.

---

### 2. Permission

Introduce exactly one permission:

`media.inventory.register`

Permission contract:

- domain: `media`
- label: `Register media cards`
- purpose: register approved physical media cards into the canonical studio inventory
- `requires_server_enforcement = true`

Grant exactly to:

- `founder`
- `studio_manager`

Do not grant this permission to:

- photographer
- assistant
- stylist
- editor
- client_coordinator
- sales
- album_coordinator
- marketing
- accounts

Photographer custody authority is a later separately governed boundary.

---

### 3. Canonical Relation

Create exactly one new canonical relation:

`public.media_cards`

Exact columns:

1. `id uuid`
2. `organization_id uuid`
3. `card_code text`
4. `registered_at timestamptz`
5. `registered_by uuid`

Required invariants:

- `id` is the primary key;
- `organization_id` is required;
- `card_code` is required;
- stored `card_code` has no leading or trailing whitespace;
- `card_code` length is between 1 and 120 characters;
- physical card identity is organization-scoped;
- card identity is case-insensitively unique inside one organization;
- the same textual card code may exist in a different organization;
- `registered_at` is required and server-generated;
- `registered_by` is required and references an organization member in the same organization;
- the registered identity row is immutable after creation.

Registration means the card is part of the approved inventory for this foundation.

Card retirement, loss, quarantine, destruction, replacement, secure-reuse state, or other later lifecycle state is not introduced in this slice.

---

### 4. Registration RPC

Create exactly one application mutation RPC:

`public.register_media_card(uuid,text)`

Logical arguments:

- organization ID;
- media-card code.

The function must:

- be `SECURITY DEFINER`;
- use an empty `search_path`;
- require an authenticated actor;
- reject a null organization ID;
- reject a null, empty, or whitespace-only card code;
- reject a normalized card code longer than 120 characters;
- normalize surrounding whitespace before persistence;
- require active membership in the target organization;
- require exact `media.inventory.register` authority;
- create no organization membership or role state;
- create no booking state;
- create no journey transition;
- create no custody state.

The inventory is organization-level, so this RPC has no booking branch scope.

---

### 5. Replay and Identity Semantics

Registration must be idempotent for the same physical-card identity.

For the same organization:

- `CARD-001`
- `card-001`
- ` CARD-001 `

resolve to the same case-insensitive card identity.

If the canonical row already exists, the RPC returns that existing row.

Replay must not:

- create a duplicate row;
- change the original stored card-code casing;
- change `registered_at`;
- change `registered_by`;
- append another first-success audit event.

The same normalized code in a different organization remains a separate valid identity.

---

### 6. Immutability

Authenticated application actors must not directly insert, update, or delete `public.media_cards`.

The registration RPC is the only application mutation surface authorized by this slice.

After creation, the five frozen identity fields are immutable.

Any later retirement, loss, quarantine, replacement, or operational state model requires separate governance rather than rewriting historical registration truth.

---

### 7. RLS and ACL Boundary

`public.media_cards` must:

- enable RLS;
- force RLS;
- revoke direct mutation privileges from application roles;
- expose authenticated SELECT only through a governed policy;
- deny anonymous access.

For this slice, authenticated read access requires:

- active membership in the organization; and
- `media.inventory.register`.

Broader custody/operator read access may be introduced only by a later governed slice.

The registration function must:

- revoke execution from `PUBLIC`;
- revoke execution from `anon`;
- revoke execution from `service_role`;
- grant execution only to `authenticated`.

---

### 8. Audit Contract

First successful registration appends exactly one non-sensitive structural audit event:

`media.card_registered`

Audit entity type:

`media_card`

The audit event may contain structural identifiers including:

- organization ID;
- media-card ID;
- canonical card code;
- registering member ID.

Replay does not create another registration audit event.

No client imagery, file contents, family information, credentials, storage secrets, or arbitrary free-text notes belong in this audit event.

---

### 9. Canonical Permission Totals

Before this slice:

- permissions: 68
- role-permission mappings: 241

After this slice:

- permissions: 69
- role-permission mappings: 243

Reason:

- one new permission;
- two new role mappings:
  - founder;
  - studio_manager.

Historical migration assertions remain historical and must not be rewritten.

---

### 10. Compatibility-Test Boundary

The following existing test files are authorized for narrow compatibility edits only where they assert repository-wide final permission or role-permission totals:

1. `supabase/tests/sprint10_extended_creative_assignments_test.sql`
2. `supabase/tests/sprint11_additional_image_pricing_basis_authority_test.sql`
3. `supabase/tests/sprint11_adjusted_financial_obligation_authority_test.sql`
4. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
5. `supabase/tests/sprint11_editing_start_evidence_test.sql`
6. `supabase/tests/sprint11_full_balance_settlement_read_authority_test.sql`
7. `supabase/tests/sprint11_image_entitlement_authority_test.sql`
8. `supabase/tests/sprint11_qc_pass_evidence_test.sql`
9. `supabase/tests/sprint11_selection_confirmation_evidence_test.sql`
10. `supabase/tests/sprint11_selection_entitlement_reconciliation_test.sql`
11. `supabase/tests/sprint11_stage10_11_gate_test.sql`
12. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`
13. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
14. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`
15. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`

Authorized compatibility change:

- repository-final permission assertions: `68 -> 69`;
- repository-final mapping assertions: `241 -> 243`.

Do not mechanically replace unrelated numeric values.

In particular:

- pgTAP `plan(...)` counts are not permission counts;
- historical migration assertions are not changed;
- unrelated behavioral expectations are not changed.

---

### 11. New Implementation Artifacts

Implementation is authorized later to create exactly:

1. `supabase/migrations/20260829011200_sprint11_media_card_inventory_authority_foundation.sql`
2. `supabase/tests/sprint11_media_card_inventory_authority_test.sql`

And to update:

3. `src/integrations/supabase/types.ts`

plus only the 15 compatibility-test files listed above where live repository-total assertions require adjustment.

The Supabase TypeScript type file must represent the resulting local schema, including `media_cards` and `register_media_card`.

---

### 12. Dedicated Validation Contract

The dedicated pgTAP coverage must validate at minimum:

- permission existence and exact domain;
- exact founder/studio-manager grant topology;
- absence of unauthorized grants;
- exact `media_cards` column contract;
- organization/member foreign-key containment;
- normalized card-code validation;
- case-insensitive organization-scoped uniqueness;
- authenticated successful registration;
- inactive/non-member rejection;
- unauthorized-role rejection;
- anonymous rejection;
- direct INSERT denial;
- direct UPDATE denial;
- direct DELETE denial;
- immutability;
- exact replay identity;
- case-insensitive replay;
- cross-organization independence;
- one first-success audit event;
- no duplicate audit on replay;
- no booking/journey mutation;
- final canonical totals of 69 permissions / 243 mappings.

Full repository validation remains required after implementation.

---

### 13. Explicitly Out of Scope

This slice does not implement:

- booking-to-card assignment;
- card allocation to photographers;
- shot accounting;
- expected image counts;
- actual image counts;
- seal IDs;
- custody transfers;
- dual custody acknowledgement;
- media ingestion;
- project-folder structure;
- file manifests;
- byte-count reconciliation;
- SHA-256 hashes;
- missing-file detection;
- duplicate-file detection;
- corrupt-file detection;
- quarantine;
- encrypted storage;
- backup copies;
- restore evidence;
- card release;
- secure card reuse;
- editing handover;
- culling;
- image lineage;
- Stage 11 -> 12 compatibility strengthening;
- any other journey-stage change;
- application UI;
- external integrations.

---

### 14. Next Boundary

After this slice is implemented, fully validated, committed, pushed, and remotely reconciled, the next design checkpoint is the media-card custody boundary.

That later checkpoint must separately govern assignment, seal/custody transfer, dual acknowledgement, and subsequent dependency on ingestion/backup before card release.

No later media workflow is pre-authorized by this freeze.

---

### Environment Boundary

- Local implementation after freeze: **AUTHORIZED**
- `architecture-rebuild`: **AUTHORIZED development branch**
- `main`: **NO CHANGE AUTHORIZED**
- Remote Supabase mutation/deployment: **HOLD**
- Production deployment: **HOLD**

---

### Formal Checkpoint

**APPROVE — CORRECTIVE SLICE A TECHNICAL DESIGN FROZEN**

**APPROVE — MEDIA CARD INVENTORY IS THE FIRST POST-SHOOT PREREQUISITE**

**APPROVE — NEW `media` AUTHORITY DOMAIN**

**APPROVE — EXPECTED AUTHORITY TOTALS 69 / 243**

**HOLD — IMPLEMENTATION UNTIL THIS FREEZE IS COMMITTED AND REMOTELY VERIFIED**

**HOLD — REMOTE SUPABASE**

**HOLD — PRODUCTION**


---

## Corrective Slice B0 — Capture Device Identity Foundation

### Governance Status

**Technical-design freeze only. No implementation is authorized until this governance checkpoint is committed, pushed to `architecture-rebuild`, and independently remote-verified.**

### 1. Why B0 Exists

Post-Shoot Authority Reconciliation established that Operational Sprint 11 requires canonical media-card custody with no anonymous card or custody gap.

Corrective Slice A created the approved media-card inventory prerequisite.

Subsequent read-only discovery established that the repository has no canonical camera, equipment, or capture-device identity relation.

The Sprint 11 operational source nevertheless requires the first custody step to record:

- card ID;
- camera ID;
- seal status.

The same source models card allocation against concrete capture-device identities such as Camera A, Camera A Backup, Camera B, and Camera B Backup.

Therefore card assignment cannot safely be implemented against free-text camera labels.

B0 introduces only the minimum canonical capture-device identity required before card assignment authority can be frozen.

It does not implement US-125 Media-Card Custody and Shot Accounting.

### 2. Narrow Registration Authority

B0 introduces exactly one new permission:

`media.device.register`

Contract:

- domain: `media`
- label: `Register capture devices`
- purpose: register approved physical capture-device identities into canonical studio inventory
- `requires_server_enforcement = true`

Exact role grants:

- `founder`
- `studio_manager`

No other canonical role receives this permission in B0.

In particular:

- `photographer` does not receive capture-device registration authority;
- an operational photographer must not be able to manufacture a new device identity while performing card assignment;
- no Ingestion Operator or Technical Owner role is invented by this slice.

Expected canonical authority totals after B0:

- permissions: `70`
- role-permission mappings: `245`

The migration must precondition against the currently established totals:

- permissions: `69`
- role-permission mappings: `243`

### 3. Canonical Capture-Device Relation

B0 introduces exactly one canonical relation:

`public.capture_devices`

The relation contains exactly five columns:

1. `id uuid`
2. `organization_id uuid`
3. `device_code text`
4. `registered_at timestamptz`
5. `registered_by uuid`

Required invariants:

- `id` is the primary key;
- `organization_id` is required;
- `device_code` is required;
- `device_code` is stored trimmed;
- trimmed `device_code` length is between 1 and 120 characters;
- `device_code` is case-insensitively unique within an organization;
- the same logical device code may exist independently in different organizations;
- `registered_at` is server-generated;
- `registered_by` references an organization member in the same organization;
- registered capture-device identity is immutable after creation.

Registration means only that an approved canonical capture-device identity exists.

Registration does not prove:

- availability;
- assignment;
- physical presence;
- safety inspection;
- maintenance state;
- ownership;
- custody;
- booking use;
- camera configuration.

B0 does not add model, manufacturer, serial number, asset tag, capacity, maintenance, lifecycle, assignment, or location fields.

### 4. Controlled Registration RPC

B0 introduces exactly one controlled mutation surface:

`public.register_capture_device(uuid,text)`

Inputs:

- organization ID;
- capture-device code.

The RPC must:

- be `SECURITY DEFINER`;
- use `SET search_path = ''`;
- require an authenticated actor;
- reject null organization ID;
- reject null device code;
- trim the supplied device code;
- reject blank device code;
- reject device code longer than 120 characters;
- require active membership in the target organization;
- require `media.device.register`;
- create no booking state;
- create no custody state;
- create no card assignment;
- create no journey mutation.

The authority boundary is organization-level.

No branch scope is introduced by B0.

### 5. Replay and Logical Identity

Within one organization, these values represent the same logical capture-device identity:

- `CAM-A`
- `cam-a`
- ` CAM-A `

A replay against an existing logical identity must:

- return the existing canonical row;
- preserve the original stored casing;
- preserve the original `registered_at`;
- preserve the original `registered_by`;
- create no duplicate row;
- create no duplicate audit event.

The same logical code in a different organization represents a separate valid capture-device identity.

### 6. Immutability, RLS, and ACL

`public.capture_devices` must enable and force Row Level Security.

Authenticated SELECT authority requires both:

- active membership in the capture device's organization;
- `media.device.register` for that organization.

B0 deliberately uses the narrow registration authority for initial inventory read access.

Broader operational read access for card-assignment or custody actors is not introduced by this slice and must be separately governed later.

Authenticated application actors must not receive direct:

- `INSERT`;
- `UPDATE`;
- `DELETE`

authority on `public.capture_devices`.

Anonymous access is denied.

Capture-device registration occurs only through the controlled RPC.

The registered capture-device identity is immutable.

A privileged or accidental direct UPDATE or DELETE must be rejected by an immutable-identity trigger rather than relying only on RLS or table ACL.

The immutable trigger function itself must not be executable by:

- `PUBLIC`;
- `anon`;
- `authenticated`;
- `service_role`.

### 7. Registration RPC ACL

Execution authority for:

`public.register_capture_device(uuid,text)`

must be:

- revoked from `PUBLIC`;
- revoked from `anon`;
- revoked from `service_role`;
- granted to `authenticated`.

The function must independently enforce active organization membership and `media.device.register`.

RPC executability alone must not grant registration authority.

### 8. Audit Contract

The first successful creation of a canonical capture-device identity emits exactly one audit event:

`media.capture_device_registered`

Audit entity type:

`capture_device`

Audit entity ID:

- canonical capture-device ID.

The audit event is non-sensitive structural evidence.

It must not store the user-supplied `device_code` in:

- `old_values`;
- `new_values`;
- metadata;
- any other free-text audit field.

`old_values` must be `NULL`.

`new_values` must be `NULL`.

Audit metadata may contain only structural identifiers required for accountability, including:

- organization ID;
- capture-device ID;
- registering organization-member ID.

A logical replay must emit no additional registration audit event.

### 9. Frozen Implementation Artifacts

After this governance freeze is committed, pushed, and independently remote-verified, local implementation is authorized only within the following frozen artifact boundary.

Create:

1. `supabase/migrations/20260829030000_sprint11_capture_device_identity_foundation.sql`
2. `supabase/tests/sprint11_capture_device_identity_test.sql`

Update:

3. `src/integrations/supabase/types.ts`

The generated Supabase TypeScript representation must include:

- `capture_devices`;
- `register_capture_device`.

No application UI or integration surface is authorized by B0.

### 10. Compatibility-Test Boundary

Because B0 adds exactly:

- one permission;
- two role-permission mappings;

the live canonical authority totals change from:

- `69` permissions to `70`;
- `243` role-permission mappings to `245`.

Only existing tests that assert the live current totals may be updated for this compatibility change.

The exact existing compatibility-test boundary is:

1. `supabase/tests/sprint10_extended_creative_assignments_test.sql`
2. `supabase/tests/sprint11_additional_image_pricing_basis_authority_test.sql`
3. `supabase/tests/sprint11_adjusted_financial_obligation_authority_test.sql`
4. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
5. `supabase/tests/sprint11_editing_start_evidence_test.sql`
6. `supabase/tests/sprint11_full_balance_settlement_read_authority_test.sql`
7. `supabase/tests/sprint11_image_entitlement_authority_test.sql`
8. `supabase/tests/sprint11_media_card_inventory_authority_test.sql`
9. `supabase/tests/sprint11_qc_pass_evidence_test.sql`
10. `supabase/tests/sprint11_selection_confirmation_evidence_test.sql`
11. `supabase/tests/sprint11_selection_entitlement_reconciliation_test.sql`
12. `supabase/tests/sprint11_stage10_11_gate_test.sql`
13. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`
14. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
15. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`
16. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`

These compatibility edits are limited to assertions of the live current authority totals.

Historical migration assertions must not be rewritten.

In particular, Corrective Slice A's migration remains historically correct at its own final state of `69 / 243`.

### 11. Dedicated Validation Boundary

The dedicated B0 test must validate at minimum:

- exact permission key, domain, label, and server-enforcement contract;
- exact Founder + Studio Manager grant topology;
- absence of Photographer registration authority;
- exact five-column `capture_devices` contract;
- organization foreign-key containment;
- registering-member organization containment;
- trimmed and bounded device-code validation;
- case-insensitive uniqueness within organization;
- cross-organization code independence;
- successful authenticated Founder registration;
- successful authenticated organization-wide Studio Manager registration;
- inactive-member rejection;
- non-member rejection;
- unauthorized-role rejection;
- anonymous rejection;
- direct authenticated INSERT denial;
- direct authenticated UPDATE denial;
- direct authenticated DELETE denial;
- privileged UPDATE and DELETE immutability rejection;
- exact replay preservation;
- case-insensitive replay preservation;
- exactly one first-success audit event;
- no replay audit duplication;
- absence of `device_code` from audit payloads;
- no booking mutation;
- no journey mutation;
- no media-card mutation;
- final authority totals of `70 / 245`.

Full repository validation remains required after implementation.

### 12. Explicitly Out of Scope

B0 does not implement:

- media-card assignment;
- booking-to-card assignment;
- capture-device assignment to a booking;
- capture-device assignment to a photographer;
- photographer custody;
- external-creative custody;
- camera configuration;
- shot accounting;
- expected image counts;
- actual image counts;
- card removal evidence;
- write-protection evidence;
- seal IDs;
- seal verification;
- custody transfers;
- dual custody acknowledgement;
- Ingestion Operator identity;
- Technical Owner identity;
- ingestion workstations;
- media ingestion;
- manifests;
- file counts;
- byte reconciliation;
- SHA-256;
- missing-file detection;
- duplicate-file detection;
- corruption detection;
- quarantine;
- encrypted storage;
- backup;
- restore evidence;
- card release;
- secure card reuse;
- editing handover;
- culling;
- image lineage;
- Stage 11 -> 12 strengthening;
- any other journey-stage change;
- application UI;
- external integrations.

### 13. Next Boundary

After B0 is implemented, fully validated, committed, pushed, and remotely reconciled, the next design checkpoint is:

**Corrective Slice B1 — Media Card Assignment Authority**

B1 must separately govern the relationship among:

- a booking;
- an approved media card;
- an approved capture-device identity;
- an eligible authenticated custodian;
- the canonical Lead Photographer assignment boundary.

B1 must not silently invent Ingestion Operator or Technical Owner roles.

B1 must also resolve the external-creative authentication limitation before external creatives can provide authenticated custody evidence.

Card removal, shot accounting, sealing, custody transfer, and dual acknowledgement remain later separately governed boundaries.

No later custody workflow is pre-authorized by this freeze.

### Environment Boundary

- Local implementation after governance freeze: **AUTHORIZED**
- `architecture-rebuild`: **AUTHORIZED development branch**
- `main`: **NO CHANGE AUTHORIZED**
- Remote Supabase mutation/deployment: **HOLD**
- Production deployment: **HOLD**

### Formal Checkpoint

**APPROVE — CORRECTIVE SLICE B0 TECHNICAL DESIGN FROZEN**

**APPROVE — CAPTURE-DEVICE IDENTITY IS A REQUIRED CARD-ASSIGNMENT PREREQUISITE**

**APPROVE — EXACT B0 AUTHORITY TOTALS 70 / 245**

**APPROVE — EXACT IMPLEMENTATION BOUNDARY: 19 FILES**

**HOLD — IMPLEMENTATION UNTIL THIS FREEZE IS COMMITTED AND REMOTELY VERIFIED**

**HOLD — CORRECTIVE SLICE B1 UNTIL B0 IS CLOSED**

**HOLD — REMOTE SUPABASE**

**HOLD — PRODUCTION**


## Corrective Slice B1 - Media Card Assignment Authority - Technical Design Freeze

### Governance Position

Corrective Slice B0 - Capture Device Identity Foundation is closed.

The earlier B0 statement holding B1 until B0 closure was a historical
conditional hold and remains unchanged in the B0 record.

This B1 freeze supersedes that prospective hold from this point forward.

B1 implements the CUS-501 media-card-to-capture-device assignment authority
only.

B1 does not complete the wider media-custody workflow.

Card removal, shot accounting, write protection, seal evidence, custody
transfer, dual acknowledgement, ingestion, checksum verification, backup,
card release, editing handover, culling, and image lineage remain separately
governed later boundaries.

### Precondition Authority

Canonical authority before B1:

- permissions: 70
- role_permissions: 245

B1 adds exactly:

- one permission
- one role-permission mapping

Canonical authority after B1:

- permissions: 71
- role_permissions: 246

Historical migrations retain the authority totals that were correct at their
own migration point and MUST NOT be rewritten.

### Permission Contract

B1 introduces exactly one permission:

- key: `media.card.assign`
- domain: `media`
- label: `Assign media cards`
- description: `Assign registered media cards to registered capture devices for the current booking Lead Photographer.`
- requires_server_enforcement: `true`

Exactly one canonical role receives this permission:

- `photographer`

B1 does NOT grant `media.card.assign` to:

- `founder`
- `studio_manager`
- any other existing canonical role

Founder or Studio Manager status is not an administrative bypass for CUS-501.

An actor holding some other administrative permission is not thereby entitled
to assign a media card.

The source workbook also identifies an Ingestion Operator capability, but the
canonical repository currently contains no authenticated
`ingestion_operator` role or equivalent approved identity.

B1 MUST NOT invent, alias, or substitute:

- `ingestion_operator`
- `technical_owner`
- `operations_manager`
- any other ungoverned operational role

Ingestion-side assignment authority remains deferred until a separately
governed authenticated ingestion actor exists.

### Canonical Actor Contract

B1 assignment is authorization-first.

The caller MUST:

1. be authenticated;
2. resolve through `auth.uid()` to an active organization member;
3. hold `media.card.assign` for the booking's canonical branch scope;
4. be the current INTERNAL Lead Photographer assignment for that booking.

The authoritative Lead Photographer relation is
`public.booking_team_assignments`.

The qualifying current assignment MUST satisfy:

- same `organization_id`;
- same `booking_id`;
- `assignment_role = 'lead_photographer'`;
- `ended_at IS NULL`;
- `assigned_member_id` equals the current authenticated organization member;
- `assigned_external_creative_id IS NULL`.

Holding the canonical `photographer` role without being the booking's current
Lead Photographer is insufficient.

The current Lead Photographer assignment is booking-specific authority.

### External Creative Boundary

An external Lead Photographer is a canonical booking-team subject through
`assigned_external_creative_id`.

`public.external_creatives` currently has no authenticated-user or
organization-member binding.

Therefore an external Lead Photographer cannot currently produce
self-authenticated B1 custody evidence.

B1 MUST explicitly reject an external current Lead Photographer.

B1 MUST NOT create an external-authentication mapping.

Any future external-custody identity mechanism requires a separately frozen
foundation.

### Journey Gate

B1 assignment may occur only when the booking has exactly one canonical
current journey state and that state resolves to:

- `stage_order = 10`
- `stage_key = 'shoot_scheduled'`

B1 MUST reject assignment before Stage 10.

B1 MUST reject new assignment after Stage 10, including:

- Stage 11 `shoot_completed`
- Stage 12 `selection_pending`
- all later stages

B1 does not modify the Stage 10 -> Stage 11 gate.

Any later requirement preventing shoot completion while custody remains open
must be separately frozen.

### Canonical Relation

B1 introduces exactly one new canonical relation:

`public.media_card_assignments`

The relation contains exactly these eleven columns:

1. `id uuid`
2. `organization_id uuid`
3. `booking_id uuid`
4. `media_card_id uuid`
5. `capture_device_id uuid`
6. `lead_photographer_assignment_id uuid`
7. `custodian_member_id uuid`
8. `assigned_at timestamptz`
9. `assigned_by uuid`
10. `ended_at timestamptz`
11. `ended_by uuid`

Column invariants:

- `id` is the primary key with default `gen_random_uuid()`;
- `organization_id` is required;
- `booking_id` is required;
- `media_card_id` is required;
- `capture_device_id` is required;
- `lead_photographer_assignment_id` is required;
- `custodian_member_id` is required;
- `assigned_at` is required with default `now()`;
- `assigned_by` is required;
- `ended_at` is nullable;
- `ended_by` is nullable.

B1 initial assignment requires:

- `ended_at IS NULL`;
- `ended_by IS NULL`;
- `custodian_member_id = assigned_by`.

Lifecycle structural integrity requires:

- `ended_at` and `ended_by` are either both NULL or both non-NULL;
- if populated, `ended_at >= assigned_at`.

B1 exposes no controlled close mutation.

All B1-created rows therefore remain active until a later separately governed
slice introduces the authorized removal/closure mechanism.

### Tenant-Safe Foreign-Key Lineage

B1 MUST use canonical organization-safe foreign keys.

Booking:

`(organization_id, booking_id)`
-> `public.bookings(organization_id, id)`

Media card:

`(organization_id, media_card_id)`
-> `public.media_cards(organization_id, id)`

Capture device:

`(organization_id, capture_device_id)`
-> `public.capture_devices(organization_id, id)`

Lead Photographer assignment:

`(lead_photographer_assignment_id, organization_id, booking_id)`
-> `public.booking_team_assignments(id, organization_id, booking_id)`

Initial custodian:

`(custodian_member_id, organization_id)`
-> `public.organization_members(id, organization_id)`

Assignment actor:

`(assigned_by, organization_id)`
-> `public.organization_members(id, organization_id)`

Future closure actor:

`(ended_by, organization_id)`
-> `public.organization_members(id, organization_id)`

The relation MUST also expose:

`UNIQUE (id, organization_id, booking_id)`

to provide tenant-safe lineage for later separately governed custody evidence.

### Historical Identity

`lead_photographer_assignment_id` records the exact canonical booking-team
assignment that existed when CUS-501 succeeded.

That value is historical evidence.

A later Lead Photographer replacement MUST NOT rewrite the B1 assignment row.

`custodian_member_id` records the initial authenticated internal custodian.

`assigned_by` records the authenticated actor who performed the assignment.

For B1 first assignment those two member IDs are the same actor.

### Active-Assignment Collision Contract

A registered media card may have at most one active assignment within its
organization.

B1 MUST enforce the equivalent of:

`UNIQUE (organization_id, media_card_id) WHERE ended_at IS NULL`

One capture device MAY have multiple active media cards.

B1 MUST NOT create a uniqueness constraint that limits a capture device to one
active card.

One booking MAY use multiple cards.

One booking MAY use multiple capture devices.

A card may be reused only after a later authorized B2 closure has ended its
previous assignment.

### Assignment RPC

B1 introduces exactly one controlled mutation RPC:

`public.assign_media_card(uuid, uuid, uuid)`

Canonical argument order:

1. `p_booking_id uuid`
2. `p_media_card_id uuid`
3. `p_capture_device_id uuid`

Return type:

`public.media_card_assignments`

The caller MUST NOT provide:

- organization ID;
- custodian member ID;
- assigned-by member ID;
- Lead Photographer assignment ID;
- assignment timestamp;
- closure fields.

The RPC derives those values from canonical authenticated state.

The RPC MUST be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- authenticated-only.

The RPC MUST revoke execute from:

- PUBLIC
- anon
- service_role

The RPC MUST grant execute only to:

- authenticated

### Assignment RPC Validation

The RPC MUST:

1. reject NULL required inputs;
2. require `auth.uid()`;
3. resolve and lock the authoritative booking;
4. derive the booking organization and branch;
5. require active organization membership;
6. require `media.card.assign` at the booking branch scope;
7. require exactly one canonical journey state;
8. require Stage 10 `shoot_scheduled`;
9. resolve the current Lead Photographer booking-team assignment;
10. reject no current Lead Photographer;
11. reject an external Lead Photographer;
12. require the current Lead Photographer member to equal the authenticated actor;
13. require the media card to exist in the same organization;
14. require the capture device to exist in the same organization;
15. prevent more than one active assignment for the same media card;
16. insert only canonical derived identity and attribution.

The implementation MUST serialize competing assignment attempts so concurrent
requests cannot create two active rows for one card.

### Replay Contract

Replay is authorization-first.

An existing active assignment is an exact replay only when all of the following
still match:

- same organization;
- same booking;
- same media card;
- same capture device;
- same current Lead Photographer assignment;
- same custodian member;
- same assigning member.

An exact active replay:

- returns the original assignment row;
- preserves the original ID;
- preserves `assigned_at`;
- preserves `assigned_by`;
- creates no second assignment row;
- creates no duplicate audit event.

If the same card is already active with a different:

- booking;
- capture device;
- Lead Photographer assignment;
- custodian;

the request MUST fail.

A Lead Photographer replacement while a card remains active does not transfer
custody.

The replacement Lead Photographer cannot reassign that card through B1.

Later custody/removal controls must resolve the existing assignment first.

### Relation Mutation Guard

B1 assignment identity and original attribution are immutable.

Direct DELETE is forbidden.

Direct UPDATE is forbidden during B1.

INSERT with pre-populated `ended_at` or `ended_by` is forbidden.

Authenticated clients have no direct INSERT, UPDATE, or DELETE authority.

Service-role table mutation is not an application mutation surface.

A privileged database mutation attempt must still be rejected by the B1
relation guard for UPDATE and DELETE.

B2 may later replace or evolve this guard only through a separately frozen
migration that introduces controlled removal/closure evidence.

### RLS and ACL Boundary

`public.media_card_assignments` MUST:

- enable RLS;
- force RLS.

Authenticated SELECT is permitted only through a B1-specific policy requiring:

- active organization membership;
- `media.card.assign` for the assignment booking's branch scope;
- valid booking branch scope where applicable.

`booking.read` alone is insufficient to read B1 custody-assignment evidence.

No authenticated direct INSERT, UPDATE, or DELETE privilege is permitted.

No anonymous access is permitted.

The application mutation surface is the controlled
`assign_media_card(...)` RPC only.

### Audit Contract

First successful assignment emits exactly one audit event:

- event_type: `media.card_assigned`
- entity_type: `media_card_assignment`
- entity_id: the canonical `media_card_assignments.id`
- sensitive: `false`
- old_values: NULL
- new_values: NULL
- source: `application`
- request_id: NULL

Audit metadata contains structural IDs only:

- `organization_id`
- `booking_id`
- `media_card_assignment_id`
- `media_card_id`
- `capture_device_id`
- `lead_photographer_assignment_id`
- `custodian_member_id`
- `assigned_by`

The audit record MUST NOT contain:

- `card_code`
- `device_code`
- display names
- email addresses
- phone numbers
- free-text descriptions
- seal data
- shot-count data

Exact replay creates no second audit event.

### CUS-501 / Later Custody Boundary

B1 establishes:

- booking;
- registered media card;
- registered capture device;
- canonical internal Lead Photographer assignment;
- initial authenticated custodian;
- assignment timestamp and attribution.

B1 does NOT introduce:

- card removal;
- expected shot count;
- actual shot count;
- removal timestamp;
- write-protection evidence;
- seal ID;
- seal condition;
- seal status;
- transfer state;
- sender acknowledgement;
- recipient acknowledgement;
- ingestion custodian;
- ingestion workstation;
- ingest batch;
- manifest;
- SHA-256;
- backup state;
- card release;
- editing handover.

Those remain B2, B3, and later separately governed slices.

### Runtime Non-Mutation Boundary

A successful B1 RPC may mutate only:

- `public.media_card_assignments`;
- canonical audit storage through the existing audit append authority.

It MUST NOT mutate:

- `public.media_cards`;
- `public.capture_devices`;
- `public.bookings`;
- `public.booking_team_assignments`;
- `public.booking_journey_states`;
- `public.booking_stage_transitions`;
- family/client records;
- quotations;
- payments;
- editing state;
- gallery state.

### Exact Implementation Boundary

After this governance freeze is committed and remotely verified, local B1
implementation is limited to exactly twenty files.

CREATE:

1. `supabase/migrations/20260829040000_sprint11_media_card_assignment_authority_foundation.sql`
2. `supabase/tests/sprint11_media_card_assignment_authority_test.sql`

UPDATE:

3. `src/integrations/supabase/types.ts`
4. `supabase/tests/sprint10_extended_creative_assignments_test.sql`
5. `supabase/tests/sprint11_additional_image_pricing_basis_authority_test.sql`
6. `supabase/tests/sprint11_adjusted_financial_obligation_authority_test.sql`
7. `supabase/tests/sprint11_capture_device_identity_test.sql`
8. `supabase/tests/sprint11_editing_completion_evidence_test.sql`
9. `supabase/tests/sprint11_editing_start_evidence_test.sql`
10. `supabase/tests/sprint11_full_balance_settlement_read_authority_test.sql`
11. `supabase/tests/sprint11_image_entitlement_authority_test.sql`
12. `supabase/tests/sprint11_media_card_inventory_authority_test.sql`
13. `supabase/tests/sprint11_qc_pass_evidence_test.sql`
14. `supabase/tests/sprint11_selection_confirmation_evidence_test.sql`
15. `supabase/tests/sprint11_selection_entitlement_reconciliation_test.sql`
16. `supabase/tests/sprint11_stage10_11_gate_test.sql`
17. `supabase/tests/sprint11_stage12_13_editing_pending_gate_test.sql`
18. `supabase/tests/sprint11_stage13_14_editing_in_progress_gate_test.sql`
19. `supabase/tests/sprint11_stage14_15_qc_pending_gate_test.sql`
20. `supabase/tests/sprint11_stage15_16_pixieset_gallery_ready_gate_test.sql`

No other implementation file is authorized by this freeze.

Governance documentation belongs to the separate governance-freeze commit and
is not part of the twenty-file implementation commit.

### Compatibility Total Boundary

Exactly seventeen existing live-current test files currently contain the
`70 / 245` authority contract.

Across those seventeen files there are exactly thirty-eight matching live-total
occurrences.

Only those live-current assertions may advance to:

- 71 permissions
- 246 role-permission mappings
- combined text `71:246` where the test uses the combined representation

Historical migration assertions MUST NOT be edited.

Comments, UUIDs, plan counts, historical totals, and unrelated numeric literals
MUST NOT be changed merely because they contain similar numbers.

The new B1 dedicated test asserts the final B1 authority contract of `71 / 246`.

### Required Dedicated B1 Validation

The dedicated B1 pgTAP test MUST prove at minimum:

- exact permission key, domain, label, description, and server-enforcement flag;
- exactly one role grant and that role is `photographer`;
- no Founder or Studio Manager grant;
- exact eleven-column relation shape;
- all tenant-safe foreign keys;
- closure-pair structural check;
- assignment time structural check;
- initial custodian / assigned-by equality;
- active-card uniqueness;
- absence of capture-device active uniqueness;
- forced RLS;
- direct authenticated DML denial;
- anonymous denial;
- service-role application-surface denial;
- RPC signature;
- SECURITY DEFINER;
- empty search path;
- RPC ACL;
- authenticated current internal Lead Photographer success;
- organization-wide qualifying photographer success where canonically assigned;
- branch-scoped qualifying photographer success where canonically assigned;
- photographer who is not the current Lead Photographer rejection;
- Founder without the canonical Lead Photographer/photographer authority rejection;
- Studio Manager without the canonical Lead Photographer/photographer authority rejection;
- inactive member rejection;
- non-member rejection;
- anonymous rejection;
- external current Lead Photographer rejection;
- Stage 9 rejection;
- exact Stage 10 success;
- Stage 11 rejection;
- same-organization media-card requirement;
- same-organization capture-device requirement;
- exact replay;
- replay preserves original identity and attribution;
- replay creates no duplicate audit;
- active-card different-device collision rejection;
- active-card different-booking collision rejection;
- active-card different-current-custodian rejection;
- multiple different cards on the same capture device are allowed;
- first success emits exactly one `media.card_assigned` audit event;
- exact structural audit metadata;
- card and device codes absent from audit;
- booking, journey, media-card, capture-device, and booking-team state remain unchanged;
- privileged UPDATE rejection;
- privileged DELETE rejection;
- final authority totals exactly `71 / 246`.

### Repository Validation Required Before B1 Commit

Before the B1 implementation commit is authorized, local validation MUST
include:

- `git diff --check`;
- local Supabase database reset;
- local Supabase database lint;
- dedicated B1 pgTAP test;
- all seventeen frozen compatibility tests;
- full Supabase database test suite;
- targeted lint for the modified generated TypeScript type artifact;
- production application build;
- repository-wide lint reconciliation against the established baseline;
- exact twenty-file implementation-boundary audit.

Any new regression introduced by B1 requires revision.

The existing repository-wide lint baseline may be treated separately only if
its final error/warning totals remain unchanged and the B1-touched TypeScript
artifact has no new lint diagnostic.

### Environment Boundary

- B1 governance/design: **APPROVED**
- Local B1 implementation after governance freeze commit and remote verification: **AUTHORIZED**
- Corrective Slice B2 implementation: **HOLD**
- `architecture-rebuild`: **AUTHORIZED development branch**
- `main`: **NO CHANGE AUTHORIZED**
- Remote Supabase mutation/deployment: **HOLD**
- Production deployment: **HOLD**

### Formal Checkpoint

**APPROVE - CORRECTIVE SLICE B1 TECHNICAL DESIGN FROZEN**

**APPROVE - MEDIA CARD ASSIGNMENT IS BOUND TO THE CURRENT INTERNAL BOOKING LEAD PHOTOGRAPHER**

**APPROVE - EXACT B1 AUTHORITY TOTALS 71 / 246**

**APPROVE - EXACT B1 COMPATIBILITY SURFACE: 17 FILES / 38 LIVE-TOTAL OCCURRENCES**

**APPROVE - EXACT B1 IMPLEMENTATION BOUNDARY: 20 FILES**

**HOLD - IMPLEMENTATION UNTIL THIS FREEZE IS COMMITTED AND REMOTELY VERIFIED**

**HOLD - CORRECTIVE SLICE B2**

**HOLD - REMOTE SUPABASE**

**HOLD - PRODUCTION**
