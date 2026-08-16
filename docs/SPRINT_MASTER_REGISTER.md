# Little Shots by Hema OS — Sprint Master Register

**Project:** LSH - Active / Memory Keeper OS
**Repository:** `Little-Shots-by-Hema-OS/memory-keeper-os`
**Primary release branch:** `architecture-rebuild`
**Register version:** 1.0
**Last updated:** 2026-08-14

---

## 1. Purpose

This register is the canonical sprint history for the Little Shots by Hema operating-system rebuild.

It records:

- the normalized sprint sequence;
- what each sprint owns;
- the database migrations associated with each sprint;
- release/commit evidence where known;
- Production status;
- important validation evidence;
- known debt that remains outside the sprint's acceptance boundary;
- the dependency boundary for the next sprint.

### Important historical note

**Sprints 1–5 were not originally executed under formal frozen sprint workbooks in the same way as Sprint 7.** Their names below are a retrospective normalization of the architecture waves and delivered module foundations. They should not be represented later as if these exact titles had been formally approved at the time.

Sprint 6 and Sprint 7 have stronger explicit sprint/release boundaries in the implementation history.

---

## 2. Sprint Register — Executive View

| Sprint    | Normalized title                                                      | Current status             | Production status |
| --------- | --------------------------------------------------------------------- | -------------------------- | ----------------- |
| Sprint 1  | Core Platform, Organization & Security                                | Complete                   | Released          |
| Sprint 2  | Families Foundation & Audit                                           | Complete                   | Released          |
| Sprint 3  | Family Contacts & Communication Controls                              | Complete                   | Released          |
| Sprint 4  | Children & Memory Profiles                                            | Complete                   | Released          |
| Sprint 5  | Leads & CRM Foundation                                                | Complete                   | Released          |
| Sprint 6  | Lead Workspace & Sales Operations                                     | Complete                   | Released          |
| Sprint 7  | AI Memory Guide Core Flow & Recommendation Engine                     | Complete                   | Released          |
| Sprint 8  | Packages, Quotations & Booking Conversion Foundation                  | Complete                   | Released          |
| Sprint 9  | Advance Payment, Booking Confirmation & KPI Foundation                | Complete                   | Released          |
| Sprint 10 | Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation | Implementation in progress | Not released      |

Current position: **Sprint 9 remains the latest closed Production sprint. Sprint 10 scope is frozen and implementation is in progress. Slice 1 — Shoot Scheduling Evidence + Confirmation Reservation Gate — has been implemented, validated, pushed and migrated to the Production database. Slice 2 — Pre-Shoot Preparation Instance + Controlled Stage 8 -> 9 Gate — has been implemented, fully validated locally, pushed and migrated to the Production database, with post-rollout static security/invariant validation complete. Slice 3 — Preparation Checklist Foundation — has been implemented, fully validated locally, pushed and migrated to the Production database, with post-rollout static security/invariant validation complete. Sprint 10 as a whole is not released.**

---

# Sprint 1 — Core Platform, Organization & Security

## Objective

Establish the secure multi-tenant application foundation so every later module can be organization-scoped and permission-aware.

## Delivered scope

- canonical organization baseline;
- organization lifecycle/status;
- organization settings and bootstrap support;
- members and organization membership;
- roles, grants and permissions;
- permission helpers;
- branch-aware access foundations;
- RLS foundations;
- authenticated organization context;
- founder bootstrap path.

## Primary migrations

- `20260802211242_core_organization_baseline.sql`
- `20260802232838_organization_access_control.sql`
- `20260803094728_organization_bootstrap.sql`

## Acceptance state

- multi-tenant organization boundary established;
- authenticated access resolves through organization membership;
- permission checks are database-backed rather than UI-only;
- later domain modules can rely on the same authorization model.

## Status

**COMPLETE / RELEASED**

---

# Sprint 2 — Families Foundation & Audit

## Objective

Create the authoritative family record and immutable audit foundation.

## Delivered scope

- typed family records;
- family organization ownership;
- family lifecycle/status;
- family create/archive/reactivate workflows;
- tenant-scoped family access;
- immutable audit foundation;
- audit event ownership and actor context.

## Primary migrations

- `20260803111933_families_foundation.sql`
- `20260803124119_audit_foundation.sql`

## Status

**COMPLETE / RELEASED**

---

# Sprint 3 — Family Contacts & Communication Controls

## Objective

Model how a family may be contacted without treating contactability, privacy and marketing consent as the same concept.

## Delivered scope

- family contacts;
- contact channels;
- preferred contact channel;
- phone / WhatsApp / email contact handling;
- contactability status;
- do-not-contact controls;
- do-not-contact reason;
- quiet-hours controls;
- communication preference foundation.

## Primary migration

- `20260803130210_family_contacts_foundation.sql`

## Status

**COMPLETE / RELEASED**

---

# Sprint 4 — Children & Memory Profiles

## Objective

Represent children and the memory/story context that makes the operating system family-centered rather than transaction-centered.

## Delivered scope

- child records;
- child stage/lifecycle;
- birth date / expected due date support;
- privacy restrictions/preferences;
- family-level Memory Profiles;
- child-level Memory Profiles;
- memory goals;
- story and milestone context;
- Clients integration;
- organization-wide Memory Profiles surface.

## Primary migration

- `20260811001307_children_memory_profiles_foundation.sql`

## Status

**COMPLETE / RELEASED**

---

# Sprint 5 — Leads & CRM Foundation

## Objective

Replace the legacy lead mock with a real organization-scoped CRM foundation and establish Lead-to-Family conversion.

## Delivered scope

- authoritative Leads table/model;
- create/update Lead RPCs;
- Lead status lifecycle;
- source, contact and session-interest fields;
- follow-up timing;
- branch/owner assignment;
- privacy and memory-goal context;
- lost reason handling;
- Lead-to-Family conversion;
- real `/leads` integration.

## Primary migration

- `20260811023855_leads_foundation.sql`

## Known debt carried forward

- Lead conversion does not yet transfer every family-contact / memory-goal concept automatically;
- some older TypeScript/global lint debt remains outside this sprint's acceptance boundary.

## Status

**COMPLETE / RELEASED**

---

# Sprint 6 — Lead Workspace & Sales Operations

## Objective

Turn the Lead foundation into a usable internal sales workspace with tasks, next actions and communication/consultation support.

## Delivered scope

- Lead Workspace/detail;
- lead task foundation;
- lead next-action foundation;
- consultation/review operational support;
- Tasks workspace;
- WhatsApp / communication-log operational metadata;
- permission-aware Lead operations.

## Primary migration

- `20260811054500_sprint6_lead_workspace_foundation.sql`

## Release evidence

- Commit: `a69dc3179728a66fc7f939ba88bda39dd6a02aa7`
- Commit message: `feat: add sprint 6 lead workspace`

## Production validation

Authenticated Production smoke passed for:

- `/leads`
- `/tasks`
- `/whatsapp`

## Known debt carried forward

- Bookings/Pipeline remained legacy/mock architecture;
- repository-wide ESLint/TypeScript baseline debt pre-existed Sprint 7;
- some old `.inputValidator()` usage remains deprecated but non-blocking.

## Status

**COMPLETE / RELEASED**

---

# Sprint 7 — AI Memory Guide Core Flow & Recommendation Engine

## Objective

Create the consent-first anonymous Memory Guide and deterministic recommendation engine, with safe human review and controlled CRM handoff.

## Delivered scope

### Public Memory Guide

- anonymous guide start;
- guided stage/question flow;
- service categories including Maternity, Newborn, Sitter and unsupported/custom categories;
- sitter-readiness handling;
- emotional/memory-goal questions;
- broad location preference;
- privacy preference separated from image-use consent;
- contact permission separated from marketing consent;
- restricted free-text separation;
- deterministic scoring;
- eligibility-before-ranking;
- human review path for unsupported/custom/risky cases;
- approved catalogue recommendations only;
- no automatic upsell objective;
- save/resume with strong token handling;
- single-use resume-token rotation;
- no raw resume-token storage;
- organization lifecycle guard for suspended/deleted organizations.

### Review and CRM integration

- Memory Guide review requests;
- authenticated Review Center;
- controlled CRM outbox;
- idempotent CRM sync;
- duplicate contact handling;
- generic review tasks;
- restricted answers excluded from Lead/summary/task surfaces;
- package offer-price metadata removed from CRM-facing summaries.

### Security

- constrained `SECURITY DEFINER` RPC boundary;
- safe `search_path=""` on guide boundary functions;
- restricted tables inaccessible directly to `anon` and `authenticated`;
- `sync_memory_guide_to_crm` unavailable to `anon`;
- internal organization-active helper unavailable directly;
- Production `rls_auto_enable()` execution revoked from `anon` and `authenticated`;
- Supabase leaked-password protection enabled after Pro upgrade.

## Primary migration

- `20260811150000_sprint7_ai_memory_guide_foundation.sql`

## Test suite

- `supabase/tests/sprint7_memory_guide.sql`
- pgTAP: **38/38 PASS**

## Founder Decision Freeze

Approved values:

- `high_confidence_margin = 5`
- `review_margin = 1`
- margin `0–1` => human review required
- margin `2–4` => medium confidence
- margin `5+` => high confidence
- exact tie => lower tier deterministically + mandatory human review
- anonymous session TTL = `7 days`
- resume TTL = `24 hours`
- linked-session TTL = `30 days`

Approved policy:

- privacy preference does not equal image-use consent;
- contact permission is enquiry permission, not marketing consent;
- privacy/image-use consent must not alter package ranking, eligibility, list price or discount eligibility;
- promotional offers require separate explicit catalogue approval.

## Release evidence

- Commit: `578024e5dc932f33b16b221da411192d8362a025`
- Commit message: `feat: add sprint 7 AI memory guide`
- Branch: `architecture-rebuild`
- Vercel Production deployment: exact Sprint 7 SHA, `READY`
- Production migration applied successfully.

## Final local validation

- clean DB reset: PASS
- DB lint: PASS (`No schema errors found`)
- pgTAP: **38/38 PASS**
- targeted Prettier: PASS
- targeted ESLint: PASS
- production build: PASS
- `git diff --check`: PASS
- local schema drift: `No schema changes found`

## Production security validation

- Security Advisor errors: `0`
- leaked-password protection: enabled
- `rls_auto_enable()` anon EXECUTE: `false`
- `rls_auto_enable()` authenticated EXECUTE: `false`
- `memory_guide_sensitive_answers` direct SELECT for anon/authenticated: `false`
- `memory_guide_resume_tokens` direct SELECT for anon/authenticated: `false`
- `memory_guide_analytics_events` direct SELECT for anon/authenticated: `false`
- public guide RPC ACL/search-path boundary verified in Production.

## Production functional smoke

Public Memory Guide:

- anonymous session start: PASS
- navigation/stage progression: PASS
- supported Maternity recommendation: PASS
- standard approved catalogue pricing: PASS
- privacy ≠ image-use consent messaging: PASS
- no consent-derived offer/discount: PASS
- no-contact path produced:
  - `lead_id = NULL`
  - `permitted_contact_rows = 0`
  - `crm_outbox_rows = 0`
  - `lead_summary_rows = 0`
  - `review_rows = 0`

Authenticated regression smoke:

- Leads: PASS
- Lead Workspace: PASS
- Tasks: PASS
- WhatsApp: PASS
- Clients: PASS
- Memory Profiles: PASS
- Memory Guide Review Center: PASS

Vercel runtime check after smoke:

- no Production runtime errors found.

## Status

**COMPLETE / PRODUCTION RELEASED / CLOSED**

---

# Sprint 8 — Packages, Quotations & Booking Conversion Foundation

## Status

**COMPLETE / PRODUCTION RELEASED / CLOSED**

## Objective

Create the authoritative commercial layer that turns an approved package recommendation or staff-selected package into a versioned quotation and, after explicit acceptance, into exactly one tentative booking shell with an authoritative journey state.

Sprint 8 establishes commercial truth and booking conversion without pretending that quotation acceptance proves payment or confirms a session date.

## Founder / preflight freeze

The following decisions were frozen before implementation:

1. The canonical journey contains 21 typed stages, with `Advance Pending` at Stage 7 between `Follow-Up Pending` and `Booking Confirmed`. Current state is typed and transition history is append-only.
2. Quotation lifecycle is `draft`, `ready`, `sent`, `accepted`, `declined`, `expired`, `superseded`. Accepted quotations are immutable; commercial revisions require a new/superseding quotation rather than rewriting accepted history.
3. Accepting a quotation creates exactly one tentative booking shell and places its journey at `Advance Pending`. Quotation acceptance does not reserve a date and does not create `Booking Confirmed`.
4. Sprint 8 is not a payment ledger. It does not invent payment totals, balances, receipts, refunds or transaction history.
5. Sprint 7 `memory_guide_packages` remain recommendation/source evidence. Sprint 8 owns the authoritative commercial catalogue with stable package identity and versioned definitions. Historical quotation pricing is snapshotted.
6. Only approved Maternity, Newborn and Sitter catalogue data is seeded. No pricing is invented for unsupported categories.
7. Source-document Offer Price values are retained only as promotional metadata. They are not automatically applied. Privacy preference, image-use consent and contact permission cannot affect package eligibility, recommendation ranking, list price or discount.
8. Add-ons are structured, versioned and category-scoped. Quotation line items snapshot the exact commercial name, quantity and price used at the time.
9. New commercial permissions include `package.catalogue.manage` and `commercial.price.override`; founder access is the initial authority boundary.
10. Legacy mock/Zustand booking, quotation and pipeline records are not migrated into canonical truth. Demo booking state is discarded rather than promoted into Production authority.

## Delivered scope

### Commercial catalogue

- authoritative commercial packages and package versions;
- versioned package inclusions;
- structured add-ons and add-on versions;
- category-scoped commercial definitions;
- approved Maternity/Newborn/Sitter catalogue only;
- 12 seeded packages;
- 16 seeded add-ons;
- 95 seeded package inclusions;
- List Price is authoritative;
- historical catalogue/version preservation;
- authenticated reads through user-scoped Supabase access;
- no normal commercial path uses service-role bypass.

### Quotations

- authoritative `quotations`;
- authoritative `quotation_line_items`;
- immutable commercial snapshots;
- human-readable quotation references;
- package, add-on, custom and discount line support;
- quotation lifecycle RPCs;
- dedicated quotation acceptance RPC;
- accepted quotation immutability;
- superseding/revision model instead of rewriting accepted history;
- `approved_offer` is reserved at the database layer but automatic Offer Price execution remains blocked;
- consent cannot act as a commercial eligibility or discount rule.

### Booking conversion

- authoritative `bookings`;
- authoritative `booking_journey_states`;
- append-only `booking_stage_transitions`;
- human-readable booking references;
- no fake booking payment/reservation fields;
- journey state, not a legacy booking-status enum, is authoritative;
- `accept_quotation(uuid)` performs atomic conversion;
- acceptance requires active organization membership and `quote.write`;
- a sent quotation can create at most one booking;
- idempotent replay returns the same booking instead of creating duplicates;
- initial journey state is `Advance Pending`;
- initial transition is recorded with actor provenance;
- `Booking Confirmed` is intentionally not created by quotation acceptance and requires a later authoritative advance condition.

### Application cutover

The live commercial surfaces were cut over from legacy/mock state:

- `/packages` -> authoritative commercial catalogue;
- `/quote` -> persistent quotation workflow;
- `/bookings` -> canonical booking and journey state;
- `/pipeline` -> read-only canonical 21-stage journey.

The quotation acceptance UI uses the dedicated `acceptQuotation` server function -> `accept_quotation` RPC boundary.

The Booking and Pipeline surfaces do not expose fake payment, arbitrary journey mutation or legacy status controls.

### Legacy containment

Legacy state that belongs to later sprints was not rebuilt inside Sprint 8.

The obsolete family-link commercial workflow was contained:

- public `/f/$token` legacy mutation flow replaced with a temporary unavailable surface;
- legacy client-link server/function modules removed;
- legacy client-share mutation controls removed.

Booking-dependent later-sprint rooms that still depend on seeded Zustand/mock booking truth are temporarily unavailable:

- `/prep`;
- `/safety`;
- `/privacy`;
- `/editing`;
- `/pixieset`;
- `/heirloom`;
- `/marketing`;
- `/reviews`;
- `/governance`;
- `/reports`;
- `/kpi`.

Those rooms are removed from navigation and denied on typed/direct URL access until their own canonical domain work is implemented.

The dormant legacy studio-sync engine was removed. It was not active at the time of removal and is not represented as having corrupted canonical data.

The authenticated dashboard was replaced with a canonical-safe control room and no longer calculates fake booking, revenue, payment, safety, consent, editing, delivery, review or production metrics from legacy demo data.

## Primary migrations

- `20260812122822_sprint8_commercial_foundation.sql`
- `20260812125649_sprint8_quotations_foundation.sql`
- `20260812131648_sprint8_booking_conversion_foundation.sql`

## Database validation evidence

Final local release-candidate database gate:

- local Supabase development environment: operational;
- `supabase db lint --local`: **No schema errors found**;
- pgTAP suites: **4 files / 149 tests / PASS**;
- Sprint 7 Memory Guide regression suite: PASS;
- Sprint 8 commercial foundation suite: PASS;
- Sprint 8 quotations suite: PASS;
- Sprint 8 booking conversion suite: PASS;
- shadow-database migration replay through all Sprint 8 migrations: PASS;
- `supabase db diff --local`: **No schema changes found**.

## Application / repository validation evidence

Final release-candidate application gate:

- canonical commercial-path legacy guard: clean;
- removed legacy infrastructure guard: clean;
- quotation acceptance authority verified as `acceptQuotation` -> `accept_quotation`;
- Production build: PASS;
- post-build `npx tsc --noEmit`: PASS;
- `git diff --check`: PASS;
- generated `src/routeTree.gen.ts` restored and excluded from the release diff;
- final worktree after validation: clean.

Build warnings remain non-blocking known debt:

- older `.inputValidator()` usages are deprecated;
- main client chunk exceeds the current 500 kB warning threshold;
- Cloudflare/Nitro emits the existing `platform` option warning;
- dependency-level module `"use client"` directives are ignored during bundling.

## Runtime acceptance evidence

Authenticated local runtime smoke passed for the Sprint 8 release candidate:

- Studio Control Room renders without legacy fake booking/revenue/safety/consent KPIs;
- contained legacy rooms are absent from navigation;
- direct access to a contained room renders the temporary rebuild notice instead of the legacy workflow;
- `/packages` renders the canonical catalogue;
- `/quote` renders the persisted accepted quotation and associated booking reference;
- `/bookings` renders the canonical booking at `Advance Pending` and explicitly distinguishes quote total from payment status;
- `/pipeline` renders the canonical Stage 7 booking and the complete 21-stage journey;
- no arbitrary commercial/journey mutation controls are exposed by the read-only Booking/Pipeline cutover.

## Local Sprint 8 implementation commit stack

- `53db7cf` — `feat: add sprint 8 commercial booking foundation`
- `ce1d5d1` — `chore: refresh supabase types for sprint 8`
- `ea9c814` — `feat: cut over packages to commercial catalogue`
- `062e8b3` — `feat: cut over quotations to canonical workflow`
- `f2a5aa0` — `feat: cut over bookings to canonical journey`
- `b7225c0` — `feat: cut over pipeline to canonical journey`
- `f35bcfb` — `chore: contain legacy family link workflow`
- `0bd8f09` — `chore: contain legacy booking-dependent workflows`

`ce1d5d1` was re-audited before release. Its large apparent diffs in Clients and Lead Workspace were primarily formatting; normalized comparison showed only two substantive compatibility adjustments:

- `StatusPill` legacy `muted` tone -> supported `neutral` tone;
- Lead activity metadata `Record<string, unknown>` -> recursive serializable JSON typing compatible with refreshed Supabase JSON types.

No unrelated Clients or Lead Workspace business-logic change was found.

Current local Sprint 8 implementation head before this register update: `0bd8f09`.

The Production release commit is intentionally not recorded yet because Sprint 8 has not been pushed/deployed to Production.

## Production state

**PRODUCTION RELEASED / CLOSED**

Production rollout completed on 2026-08-13.

Database release:

- `20260812122822_sprint8_commercial_foundation.sql` applied;
- `20260812125649_sprint8_quotations_foundation.sql` applied;
- `20260812131648_sprint8_booking_conversion_foundation.sql` applied;
- linked Production migration history verified Local = Remote through all three Sprint 8 migrations;
- Production database invariants verified after migration:
  - 12 commercial packages;
  - 12 commercial package versions;
  - 16 commercial add-ons;
  - 16 commercial add-on versions;
  - 95 package inclusions;
  - 21 canonical booking journey stages;
  - 0 quotations and quotation line items at release;
  - 0 bookings, journey states and booking transitions at release;
- RLS and FORCE RLS verified on the new commercial, quotation and booking tables;
- `create_quotation`, `transition_quotation` and dedicated `accept_quotation(uuid)` functions verified in Production.

Application release:

- Production application release commit: `73d12bf070a3148f624598b1c124f1b33f700da4`;
- Vercel Production deployment reached `READY`;
- Production aliases were attached successfully;
- Production root returned HTTP 200;
- authenticated Production smoke passed for:
  - Studio Control Room;
  - Packages;
  - Quote Builder;
  - Bookings;
  - Pipeline;
  - direct contained `/privacy` route;
- no Production runtime error clusters were found after deployment and authenticated smoke.

Production smoke confirmed that no Sprint 8 quotation or booking test data was created during release validation.

The Quote Builder subject selector exposed two historical test/demo-named CRM records (`Sprint 6 E2E Parent` and `Demo Sharma Family`). These pre-existing lead records are separate Production data-hygiene debt and are not Sprint 8 quotation or booking records.

---

# Sprint 9 — Advance Payment, Booking Confirmation & KPI Foundation

## Status

**COMPLETE / RELEASED**

## Objective

Create authoritative advance-payment evidence, make the `Advance Pending` -> `Booking Confirmed` transition dependent on verified payment evidence, and establish the first trustworthy KPI/read-model foundation without reviving legacy mock metrics.

Sprint 9 is not a full accounting system. It establishes payment evidence required for booking confirmation and management KPIs whose source data is already authoritative.

## Frozen commercial rules

1. Required advance is **50% of the final accepted quotation value**.
2. The accepted quotation's immutable `quoted_total_inr` is the authoritative calculation basis.
3. All commercial/payment values use **whole INR only**.
4. If 50% produces exactly ₹0.50, round upward to the next whole rupee.
5. Example: ₹15,001 accepted quotation total -> ₹7,501 required advance.
6. Catalogue changes after quotation acceptance cannot change the required advance.
7. Offer Price metadata is not automatically applied.
8. Privacy preference, image-use consent, contact permission and marketing consent cannot affect pricing or required advance.
9. Partial payments are allowed.
10. Multiple valid payments may cumulatively satisfy the advance.
11. Overpayment may be recorded but does not alter the required advance.
12. Payment mistakes must be corrected through reversal/correction evidence rather than silent historical edits.
13. Quotation acceptance continues to create exactly one booking at `Advance Pending`.
14. Quotation acceptance does not itself prove payment or confirm a booking.
15. `Booking Confirmed` requires valid collected payment greater than or equal to the required advance.
16. Booking confirmation does not mean full payment has been received.
17. Full payment before editing remains a separate later workflow condition.

## Final finance design decisions

The following implementation decisions are frozen:

- payment-method vocabulary is `cash`, `upi`, `bank_transfer`, `card`, `other`;
- payment external/reference identifier is optional because cash payments may legitimately have no external transaction reference;
- payment receipts are immutable evidence;
- reversals are separate immutable evidence referencing the original payment rather than mutable `reversed_at` state on the payment row;
- a payment may be reversed at most once;
- a corrected payment is represented as original payment -> reversal -> new payment;
- recording payment evidence does not itself confirm a booking;
- booking confirmation remains a separate controlled operation;
- if a valid payment is reversed after the booking has already been validly confirmed, the historical booking journey is not moved backwards;
- the original `Advance Pending` -> `Booking Confirmed` transition remains historical truth;
- current derived payment state must expose the resulting advance shortfall for operational attention;
- no generic booking-stage mutation may bypass these rules.

The initial authoritative finance concepts are frozen as:

- `booking_payment_requirements`;
- `booking_payments`;
- `booking_payment_reversals`;
- permission-aware derived payment summary;
- controlled `record_booking_payment(...)`;
- controlled `reverse_booking_payment(...)`;
- controlled `confirm_booking_after_advance(uuid)`.

## Finance architecture freeze

Sprint 9 must use append-only financial/payment evidence rather than mutable financial truth on `bookings`.

The implementation should establish authoritative concepts equivalent to:

- booking advance/payment requirement;
- payment receipt/evidence;
- payment reversal/correction evidence;
- derived valid collected amount;
- derived advance outstanding amount;
- derived advance-satisfied state.

Mutable legacy fields such as `advance`, `balance`, `paid`, `payment_status`, or similar values must not become authoritative booking columns.

The intended authority chain is:

`accepted quotation`
-> `booking at Advance Pending`
-> authoritative payment evidence
-> required advance satisfied
-> controlled booking-confirmation RPC
-> `Booking Confirmed`
-> append-only journey transition
-> audit evidence.

No UI action or generic journey mutation may bypass the financial condition.

## Booking confirmation boundary

The controlled confirmation operation must require, at minimum:

- active organization membership;
- appropriate booking/payment permission;
- booking currently at canonical Stage 7 `Advance Pending`;
- authoritative accepted quotation linkage;
- valid required-advance calculation;
- valid non-reversed collected payment greater than or equal to required advance.

Successful confirmation must:

- transition only from `Advance Pending` to `Booking Confirmed`;
- increment current journey-state version exactly once;
- update `stage_entered_at`;
- append exactly one canonical stage-transition record;
- preserve actor provenance;
- append audit evidence;
- remain idempotent against duplicate/replayed confirmation attempts.

A general unrestricted booking-stage mutation RPC is not part of this freeze.

## KPI Foundation v1

Sprint 9 should establish a typed KPI semantic/read-model layer.

Only metrics backed by authoritative domain data may be exposed.

### Sales KPIs

- new inquiries;
- quotations sent;
- accepted quotations;
- quoted value;
- accepted quotation value;
- quotation acceptance conversion.

### Booking KPIs

- canonical bookings;
- Advance Pending count;
- Booking Confirmed count;
- bookings by canonical journey stage;
- journey/stage aging where source timestamps support it.

### Payment KPIs

- required advance;
- advance collected;
- advance outstanding;
- advance satisfaction rate;
- valid payments collected.

### Conversion KPIs

- inquiry -> accepted quotation;
- accepted quotation -> booking;
- booking -> confirmed booking.

## KPI naming rules

Financial labels must reflect the underlying evidence precisely.

The following concepts must remain distinct:

- accepted quotation value;
- booked/commercial value;
- payments collected;
- advance outstanding;
- accounting revenue.

Sprint 9 must not label accepted quotation value or cash collected as accounting `Revenue` unless a later approved revenue-recognition rule establishes that meaning.

## KPI domains intentionally unavailable

The KPI dictionary may reserve future definitions, but Sprint 9 must not manufacture metrics for domains that are not yet canonical, including:

- safety completion;
- privacy/consent compliance;
- shoot preparation completion;
- editing turnaround;
- QC performance;
- Pixieset/delivery performance;
- review performance;
- album/frame production;
- aftercare/milestone follow-up.

Those metrics become displayable only when their authoritative domain workflows are implemented.

## Frozen permissions

Sprint 9 implementation will establish these narrowly scoped permissions:

- `payment.read`;
- `payment.record`;
- `payment.reverse`;
- `booking.confirm`;
- `kpi.read`.

Founder receives the initial grants.

`booking.confirm` authorizes execution of the confirmation operation but must never bypass the required-advance condition.

## Required validation coverage

Sprint 9 acceptance testing must cover, at minimum:

- exact 50% advance calculation;
- odd-rupee `.50` rounding upward;
- partial payment;
- multiple cumulative payments;
- exact-threshold satisfaction;
- overpayment;
- payment reversal/correction;
- insufficient advance rejection;
- exact `Advance Pending` -> `Booking Confirmed` transition;
- booking journey-state version increment;
- append-only transition history;
- duplicate/replayed confirmation idempotency;
- direct authenticated table-write denial;
- anonymous-access denial;
- cross-organization isolation;
- permission enforcement;
- audit actor provenance;
- Sprint 8 booking/quotation regression;
- KPI calculations derived only from authoritative records.

## Explicitly out of scope

Unless separately approved during implementation, Sprint 9 does not include:

- GST invoice generation;
- accounting invoices;
- expense accounting;
- P&L;
- revenue recognition;
- payroll;
- tax accounting;
- bank reconciliation;
- refund workflow;
- credit notes;
- payment gateway integration;
- automated WhatsApp payment collection;
- arbitrary booking-stage advancement beyond Booking Confirmed;
- shoot preparation;
- safety;
- editing;
- delivery/Pixieset;
- reviews;
- album/frame production.

## Pre-implementation gate — COMPLETE

The Sprint 9 pre-implementation gate was completed on 2026-08-13 before the first migration was written.

The completed gate required:

1. inspect all surviving legacy payment/KPI implementation;
2. freeze exact payment/reversal data model;
3. freeze booking-confirmation RPC semantics and idempotency;
4. freeze permissions;
5. freeze KPI query/read-model ownership;
6. define database tests before implementation;
7. confirm no legacy financial values are promoted to canonical truth;
8. confirm no Production write occurs before local validation passes.

## Local release-candidate implementation evidence

Sprint 9 implementation is complete locally and is ready for Production rollout review. It is not yet a Production release.

### Primary migrations

- `20260813160413_sprint9_advance_payment_evidence_foundation.sql`
- `20260813164041_sprint9_booking_confirmation_foundation.sql`
- `20260813170101_sprint9_kpi_read_model_foundation.sql`

### Advance-payment evidence foundation

Implemented authoritative append-only concepts:

- `booking_payment_requirements`;
- `booking_payments`;
- `booking_payment_reversals`;
- derived valid collected amount;
- derived outstanding advance;
- derived advance-satisfied state.

The required advance is snapshotted from the immutable accepted quotation total and remains **50% of final accepted `quoted_total_inr`**, using whole INR with an odd-rupee half rounded upward.

Partial payments, cumulative payments and overpayment are supported.

Corrections do not rewrite payment history. They are represented by immutable reversal evidence followed by corrected payment evidence where required.

Privacy preference, image-use consent, contact permission and marketing consent do not affect package pricing, quotation value or required advance.

### Booking-confirmation gate

Implemented the controlled `confirm_booking_after_advance(uuid)` boundary.

`Booking Confirmed` is permitted only when:

- the booking is at canonical Stage 7 `Advance Pending`;
- the accepted quotation linkage is authoritative;
- the required advance exists;
- valid non-reversed collections meet or exceed the required advance;
- the actor has the required organization membership and permission.

Successful confirmation performs the exact canonical Stage 7 -> Stage 8 transition and preserves append-only transition/audit evidence.

Recording a payment does not itself confirm the booking.

A payment reversal after historical confirmation does not rewrite the journey backward. The derived payment summary instead exposes `confirmed_with_advance_shortfall` when current valid collections fall below the required advance.

### Permissions

Sprint 9 established the narrow permission vocabulary:

- `payment.read`
- `payment.record`
- `payment.reverse`
- `booking.confirm`
- `kpi.read`

Founder receives the initial grants. Server-side permission enforcement remains authoritative.

### Founder KPI read model

Implemented permission-aware aggregate RPCs:

- `get_founder_kpi_summary(uuid,timestamptz,timestamptz,uuid)`
- `get_founder_booking_stage_kpis(uuid,timestamptz,uuid)`

The KPI source chain is authoritative PostgreSQL domain data -> permission-aware aggregate RPC -> authenticated user-scoped Supabase client -> TanStack server function -> Founder Studio Control Room.

No raw browser-table aggregation is used for canonical Founder KPIs.

Sprint 9 exposes only metrics backed by authoritative Leads, Quotations, Bookings, booking journey state/history and Sprint 9 payment evidence.

Unsupported later domains remain unavailable rather than being represented with legacy demonstration metrics.

Accepted quotation value, payments collected and accounting revenue remain distinct concepts. Sprint 9 does not introduce a revenue-recognition rule.

### Application integration

Implemented typed authenticated TanStack server functions in `src/lib/kpi.functions.ts`.

The normal KPI path uses `requireSupabaseAuth` and the request-scoped user Supabase client. It does not use the service-role client.

The existing Studio Control Room at `/` now contains the canonical Founder KPI surface.

The legacy `/kpi` and `/reports` routes remain temporarily unavailable and are not treated as authoritative reporting systems.

The Founder Control Room presents:

- 30-day inquiry, quotation and booking event metrics;
- quoted and accepted values;
- payments collected;
- required, valid-collected and outstanding advance;
- conversion rates with `—` when the denominator is zero;
- all 21 canonical booking stages;
- current stage counts and stage aging where evidence exists;
- confirmed-booking advance-shortfall attention when applicable.

### Authenticated local runtime validation

A disposable local-only Founder identity was used to validate the complete authenticated runtime boundary.

Founder validation passed through:

`browser session -> TanStack server function -> bearer-token auth middleware -> user-scoped Supabase client -> permission-aware KPI RPC -> Studio Control Room`

With an empty canonical data surface:

- KPI summary RPC returned HTTP 200 and exactly one aggregate row;
- count and monetary metrics correctly returned zero;
- undefined conversion rates correctly returned `null` and displayed as `—`;
- booking-stage RPC returned all 21 canonical stages;
- all empty-stage counts returned zero;
- empty-stage age values returned `null` and displayed as `—`;
- no fallback demonstration KPI values were shown.

A separate active Photographer identity verified the negative UI boundary:

- the Studio Control Room remained available;
- the Founder KPI section was not rendered;
- Founder KPI React Query reads were disabled for the non-Founder role.

Manual `/kpi` and `/reports` access continued to return the temporary-rebuild containment screen.

The disposable local runtime identities were removed by the subsequent authoritative local database reset.

### Release-candidate technical validation

Final local release-candidate gate completed on 2026-08-14:

- local database reset: PASS;
- database lint: PASS, no schema errors;
- full pgTAP regression: **361/361 PASS** across 7 test files;
- local migration/schema drift: **none**;
- Production application build: PASS;
- post-build TypeScript: PASS;
- targeted Sprint 9 ESLint: PASS;
- targeted Sprint 9 Prettier: PASS;
- Git diff check: PASS;
- service-role / legacy KPI-source safety check: clean;
- canonical KPI financial-terminology safety check: clean;
- legacy `/kpi` and `/reports` containment: preserved.

Existing TanStack `inputValidator()` deprecation notices, bundle-size warnings and Nitro/Rollup warnings remain non-blocking baseline warnings because the Production build completes successfully.

### Local Sprint 9 implementation commit stack

- `5a461df` — `feat: add sprint 9 advance payment foundation`
- `f160e5a` — `feat: add sprint 9 advance-gated booking confirmation`
- `6633fc0` — `feat: add sprint 9 founder kpi read model`
- `3d0a9eb` — `feat: add sprint 9 authenticated founder kpi server functions`
- `89956ae` — `feat: add sprint 9 founder control room kpis`

Supporting scope/design commits:

- `5110afd` — `docs: freeze sprint 9 scope`
- `8829496` — `docs: start sprint 9 implementation`

Current Sprint 9 application/implementation head before this register update: `89956ae`.

### Production release

**RELEASED / CLOSED**

Production rollout completed on 2026-08-14.

Database release evidence:

- linked migration history was verified Local = Remote through the Sprint 8 baseline before rollout;
- Sprint 9 dry-run proposed exactly the three intended migrations and no others;
- the Production pre-migration integrity gate returned `production_ready_for_sprint9 = true`;
- `20260813160413_sprint9_advance_payment_evidence_foundation.sql` applied successfully;
- `20260813164041_sprint9_booking_confirmation_foundation.sql` applied successfully;
- `20260813170101_sprint9_kpi_read_model_foundation.sql` applied successfully;
- linked migration history was then verified Local = Remote through `20260813170101`;
- the Production post-migration static gate returned `post_migration_static_ok = true`;
- all three Sprint 9 payment tables were present with forced RLS;
- anonymous payment-table privileges remained zero;
- authenticated direct payment-table write privileges remained zero;
- all five Sprint 9 permissions existed with the initial Founder grants;
- all six Sprint 9 payment, booking-confirmation and KPI RPCs were present as `SECURITY DEFINER` functions with safe search paths;
- authenticated RPC execution was enabled and anonymous execution remained denied.

Authenticated Production KPI validation:

- the existing active organization-wide Founder account authenticated successfully;
- `get_founder_kpi_summary(...)` returned HTTP 200 and exactly one aggregate row;
- `get_founder_booking_stage_kpis(...)` returned HTTP 200 and all 21 canonical stages;
- canonical stage ordering 1 through 21 passed;
- the Production KPI smoke returned `FOUNDER KPI PRODUCTION SMOKE: PASS`;
- the canonical 30-day summary showed two real inquiries and no quotations, bookings or payment collections;
- zero-denominator conversion rates remained `null` and were rendered as `—`;
- inquiry-to-accepted-quote conversion correctly rendered `0%` because the inquiry denominator was non-zero.

Application release evidence:

- Git release branch `architecture-rebuild` was pushed successfully;
- local and `origin/architecture-rebuild` converged with divergence `0 / 0`;
- exact Production deployment SHA: `633c318baf0a1985c17d364f3ab043f442b69332`;
- release commit: `633c318` — `docs: record sprint 9 release candidate`;
- Sprint 9 application implementation head: `89956ae` — `feat: add sprint 9 founder control room kpis`;
- Vercel Production deployment: `dpl_42g4mxYsVLwZQeEfpayhokCiatXp`;
- Vercel deployment state reached `READY`;
- Production aliases were attached successfully;
- Production root returned HTTP 200;
- the checked release window contained no Vercel error/fatal runtime logs.

Authenticated Production browser smoke passed:

- the Founder Studio Control Room rendered the canonical Founder view;
- `New Inquiries` displayed `2`;
- quotation, booking and advance-payment indicators matched the authoritative Production KPI RPC results;
- zero-denominator conversion cards displayed `—` rather than invented percentages;
- all 21 canonical booking stages rendered;
- all current stage counts were zero and empty age values displayed as `—`;
- `/kpi` remained contained behind the rebuild screen;
- `/reports` remained contained behind the rebuild screen;
- no visible fallback/demo KPI values or broken KPI cards were present.

Sprint 9 is therefore accepted as **Complete / Released**.

---

# Sprint 10 — Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation

## Status

**SCOPE FROZEN / IMPLEMENTATION IN PROGRESS / NOT RELEASED**

## Objective

Turn an authoritative `Booking Confirmed` booking into an operationally ready scheduled shoot through canonical shoot scheduling, structured pre-shoot preparation, restricted safety/comfort readiness evidence, team assignment and tightly controlled journey advancement through Stage 10.

Sprint 10 must preserve the Sprint 9 advance-payment confirmation invariant and must not create a generic unrestricted booking-stage mutation path.

## Frozen journey boundary

Sprint 10 owns only this journey boundary:

- Stage 7 — `Advance Pending`
- Stage 8 — `Booking Confirmed`
- Stage 9 — `Pre-Shoot Preparation`
- Stage 10 — `Shoot Scheduled`

A proposed shoot plan may exist at Stage 7, but it does not reserve the date.

`Advance Pending` -> `Booking Confirmed` continues to require the Sprint 9 advance-payment condition and additionally requires a valid current proposed shoot plan.

Confirmation must atomically convert that proposal into the authoritative reserved shoot schedule.

Stage 8 -> 9 and Stage 9 -> 10 must each use dedicated permission-aware operations.

Sprint 10 must not create a Stage 10 -> 11 transition.

Rescheduling must not move the journey backward.

## Scheduling model

Sprint 10 distinguishes a proposed shoot plan from a reserved shoot schedule.

Before `Booking Confirmed`, date, time and location may be proposed but are not reserved.

At confirmation, the current valid proposal becomes the reserved schedule.

After confirmation, rescheduling creates a new schedule version. Previous versions remain historical evidence and cannot be silently rewritten or deleted.

A reschedule reason is required.

Sprint 10 does not impose studio-capacity, photographer-capacity or overlap rules because no authoritative capacity policy has been approved.

## Canonical data concepts

Sprint 10 will introduce these authoritative concepts:

### `booking_shoot_schedules`

Versioned shoot scheduling evidence containing booking identity, organization and branch scope, scheduled start/end, timezone, location, schedule state, version, predecessor/reschedule lineage, reason where applicable, actor and timestamps.

Historical versions must be immutable through normal application paths.

### `booking_preparations`

One authoritative pre-shoot preparation instance for a booking.

### `booking_preparation_items`

Structured preparation evidence for approved applicable pre-shoot requirements.

Restricted safety/comfort details must not be copied into broad preparation summaries.

### `booking_team_assignments`

Authoritative operational booking-team assignments, including the assigned Lead Photographer used by the Newborn safety authorization rule.

### `booking_safety_readiness`

Restricted pre-shoot safety/comfort readiness evidence.

This represents readiness before the shoot. It is not proof that shoot-day actions actually occurred.

### `booking_safety_signoffs`

Immutable formal readiness approval evidence where a separate sign-off is required.

## Safety semantics

Newborn requires completed applicable safety readiness plus formal sign-off before Stage 10.

An ordinary Photographer may perform Newborn sign-off only when that member is the booking's assigned Lead Photographer.

Founder and Studio Manager retain administrative sign-off authority.

Maternity requires completed comfort readiness before Stage 10 but does not require the separate Newborn formal sign-off.

Sitter / Baby / Child requires completed safety/comfort readiness before Stage 10 but does not require the separate Newborn formal sign-off.

Shoot-day actions, stop rules, real-time comfort checks and post-session safety evidence remain outside Sprint 10.

## Permission boundary

Sprint 10 introduces these permission concepts:

- `prep.read`
- `prep.write`
- `shoot.schedule`
- `booking.team.assign`

Existing relevant permissions remain authoritative:

- `booking.read`
- `booking.write`
- `booking.stage.advance`
- `safety.read`
- `safety.write`
- `safety.signoff`

The approved authorization change is to grant `safety.signoff` to the Photographer role.

The database must enforce that an ordinary Photographer can use that permission for Newborn sign-off only when assigned as that booking's Lead Photographer.

Founder and Studio Manager retain administrative sign-off authority.

All Sprint 10 operational tables must enable and force RLS.

`anon` receives no Sprint 10 table or RPC access.

Authenticated direct writes to canonical Sprint 10 tables remain revoked. Mutations occur through permission-aware RPCs.

Restricted safety/comfort information requires `safety.read` and must not leak into broad CRM, booking-list, preparation or KPI surfaces.

Exact least-privilege initial role grants for the new non-safety permission keys must be documented and tested during implementation preflight.

For Slice 2, the approved initial grants for both `prep.read` and `prep.write` are exactly:

- Founder (`founder`);
- Studio Manager (`studio_manager`);
- Client Coordinator (`client_coordinator`).

No other role receives either preparation permission in the initial Slice 2 grant set. Broader operational access is deferred until a later preparation-item workflow establishes an approved need.

## Frozen public RPC boundary

The intended public mutation boundary is:

- `propose_booking_shoot_schedule(...)`
- `reschedule_booking_shoot(...)`
- `start_pre_shoot_preparation(...)`
- `update_pre_shoot_preparation_item(...)`
- `assign_booking_team_member(...)`
- `record_booking_safety_readiness(...)`
- `signoff_booking_safety_readiness(...)`
- `mark_booking_shoot_scheduled(...)`

The existing `confirm_booking_after_advance(uuid)` operation must be extended without weakening the Sprint 9 advance gate.

Internal helpers may be added, but Sprint 10 must not expose a second generic journey-mutation path.

## Stage 7 -> 8 invariant

`Advance Pending` -> `Booking Confirmed` requires:

- current stage exactly `Advance Pending`;
- authoritative required-advance evidence;
- valid non-reversed collections greater than or equal to required advance;
- valid current proposed shoot plan;
- booking-confirm permission.

The operation must atomically reserve the proposed shoot plan, create exactly one Stage 7 -> 8 transition and update current journey state.

Accepted quotation and advance snapshots remain historical truth.

## Stage 8 -> 9 invariant

`Booking Confirmed` -> `Pre-Shoot Preparation` requires:

- current stage exactly `Booking Confirmed`;
- active reserved shoot schedule;
- permitted actor.

It must create or resolve exactly one authoritative preparation instance and be safe for idempotent retry.

## Stage 9 -> 10 invariant

`Pre-Shoot Preparation` -> `Shoot Scheduled` requires:

- current stage exactly `Pre-Shoot Preparation`;
- active reserved shoot schedule;
- all applicable required preparation items satisfied;
- required team assignments present;
- applicable safety/comfort readiness completed;
- valid Newborn formal sign-off when the session is Newborn;
- permitted actor.

No Sprint 10 operation may create Stage 10 -> 11.

## UI scope

Sprint 10 may modify only the canonical surfaces required by this workflow:

- `/bookings`
- `/prep`
- `/safety`

`/bookings` may expose current proposed/reserved scheduling, schedule history, team assignments and Stage 8–10 readiness.

`/prep` must be rebuilt against canonical Sprint 10 preparation data.

`/safety` must be rebuilt against canonical restricted safety-readiness data.

`/prep` and `/safety` remain contained until their canonical database, server-function and authenticated browser paths pass validation.

Legacy Zustand/mock data remains non-authoritative.

`/kpi`, `/reports` and later contained workflows remain unchanged.

## Explicitly out of scope

Sprint 10 does not include Stage 10 -> 11 / `Shoot Completed`, shoot-completion evidence, shoot-day safety-event evidence, post-session safety notes, editing, selection, QC, Pixieset, delivery, heirloom production, reviews, marketing, revenue recognition, new KPI calculations, refunds, payment gateways, automatic WhatsApp messaging, automatic client reminders, booking cancellation workflow, client self-service scheduling, external calendar-provider integration, capacity optimisation, generic arbitrary journey advancement, or consent/privacy/marketing changes.

## Minimum acceptance tests

Sprint 10 implementation must prove:

1. proposed scheduling is permitted only in the approved booking lifecycle;
2. a proposed schedule is not treated as reserved before booking confirmation;
3. advance evidence alone cannot confirm when the required shoot plan is absent;
4. valid advance plus valid plan confirms atomically;
5. the reserved schedule is snapshotted;
6. historical schedule versions cannot be updated or deleted normally;
7. rescheduling requires a reason;
8. rescheduling creates a new version and preserves history;
9. rescheduling does not move the journey backward;
10. Stage 8 -> 9 occurs only through its dedicated operation;
11. Stage 9 -> 10 fails without an active reserved schedule;
12. Stage 9 -> 10 fails with incomplete applicable preparation;
13. Stage 9 -> 10 fails without required safety/comfort readiness;
14. Newborn Stage 9 -> 10 fails without valid formal sign-off;
15. an unassigned ordinary Photographer cannot sign Newborn readiness;
16. the assigned Lead Photographer with `safety.signoff` can sign;
17. Founder and Studio Manager administrative sign-off remains valid;
18. Maternity does not require the separate Newborn sign-off;
19. Sitter / Baby / Child does not require the separate Newborn sign-off;
20. restricted safety reads require `safety.read`;
21. safety readiness writes require `safety.write`;
22. formal sign-off requires `safety.signoff`;
23. preparation writes require `prep.write`;
24. scheduling mutation requires `shoot.schedule`;
25. team assignment requires `booking.team.assign`;
26. journey advancement requires the approved booking-stage permission;
27. anonymous execution is denied;
28. direct authenticated writes are denied;
29. organization and branch isolation are enforced;
30. required retry/idempotency behavior is verified;
31. no Sprint 10 operation creates Stage 10 -> 11;
32. the existing Sprint 9 payment, confirmation and KPI regression remains green.

## Release gate

Before Sprint 10 can become a release candidate, local database reset, database lint, complete pgTAP regression, empty local schema drift, application build, authoritative post-build TypeScript validation, targeted ESLint, Prettier, legacy-authority checks and restricted-safety leakage checks must pass.

No unsupported revenue or KPI logic may be introduced.

`/prep` and `/safety` may leave containment only after canonical runtime validation.

Before Production rollout, migration history must match the released baseline, relevant Production anomalies must be checked read-only, linked migration dry-run must contain only intended Sprint 10 migrations, Production migration requires separate approval, post-migration RLS/ACL/RPC invariants must pass, and authenticated Production RPC and browser smoke tests must pass.

Only then may Sprint 10 be marked Complete / Released.

## Founder decision record

Approved on 2026-08-14:

Grant `safety.signoff` to the Photographer role, but permit an ordinary Photographer to sign Newborn readiness only when that member is the booking's assigned Lead Photographer. Founder and Studio Manager retain administrative sign-off capability.

This decision is part of the frozen Sprint 10 authorization boundary.

Additional Slice 2 authorization decision approved on 2026-08-14:

Initial `prep.read` and `prep.write` grants are limited to Founder, Studio Manager and Client Coordinator. `start_pre_shoot_preparation(...)` additionally requires the existing `booking.stage.advance` permission. No other role receives either preparation permission in the initial Slice 2 grant set.

Additional Slice 3 preparation-checklist decision approved on 2026-08-15:

The canonical pre-shoot preparation taxonomy is founder-approved as follows.

Common to all supported service categories:

| Item key | Label | Requirement |
| --- | --- | --- |
| `session_brief_reviewed` | Session brief reviewed | Required |
| `preparation_guidance_shared` | Client preparation guidance shared | Required |
| `participant_plan_confirmed` | Participant plan confirmed | Required |
| `wardrobe_styling_plan_confirmed` | Wardrobe and styling plan confirmed | Required |
| `set_prop_plan_confirmed` | Set / prop plan confirmed | Required |
| `location_arrival_plan_confirmed` | Location and arrival plan confirmed | Required |
| `inspiration_references_reviewed` | Inspiration / reference preferences reviewed | Optional |
| `special_requests_reviewed` | Non-safety special requests reviewed | Optional |

Maternity-specific:

| Item key | Label | Requirement |
| --- | --- | --- |
| `maternity_wardrobe_selection_confirmed` | Maternity wardrobe selection confirmed | Required |
| `maternity_session_style_confirmed` | Maternity session style / mood confirmed | Required |
| `maternity_partner_family_plan_reviewed` | Partner / family participation plan reviewed | Optional |

Newborn-specific:

| Item key | Label | Requirement |
| --- | --- | --- |
| `newborn_styling_palette_confirmed` | Newborn styling / colour palette confirmed | Required |
| `newborn_family_inclusion_plan_confirmed` | Parent / sibling inclusion plan confirmed | Required |
| `newborn_keepsake_prop_requests_reviewed` | Keepsake / personal prop requests reviewed | Optional |

Sitter-specific:

| Item key | Label | Requirement |
| --- | --- | --- |
| `sitter_outfit_plan_confirmed` | Sitter outfit plan confirmed | Required |
| `sitter_set_style_confirmed` | Sitter set / styling direction confirmed | Required |
| `sitter_theme_palette_reviewed` | Theme / colour palette reviewed | Optional |
| `sitter_cake_smash_plan_reviewed` | Cake-smash plan reviewed, when relevant | Optional |

Checklist scope rules:

- this taxonomy contains operational preparation evidence only;
- it must not contain medical, feeding, sleep, temperature, handling, posing-safety, health, comfort-readiness or formal safety-signoff data;
- Newborn formal safety readiness/sign-off remains a separate restricted safety concern;
- optional preparation items do not become Stage 9 -> 10 blockers merely because they are unsatisfied;
- future service categories without an explicitly approved preparation taxonomy must not silently inherit category-specific requirements;
- Stage 9 -> 10 behavior is not implemented merely by approving this checklist.

This approval freezes the business taxonomy and required/optional classifications only. The Slice 3 storage model, item-instantiation semantics, mutation/audit contract, authorization details and RPC behavior remain subject to a separate implementation-design freeze before coding.

Additional Slice 3 technical design freeze approved on 2026-08-15:

Slice 3 is named **Preparation Checklist Foundation**.

The Slice 3 implementation boundary is limited to:

- canonical `booking_preparation_items`;
- approved checklist instantiation inside the existing `start_pre_shoot_preparation(uuid)` operation;
- controlled `update_pre_shoot_preparation_item(...)` mutation;
- preparation-item RLS, ACL, integrity guards, audit evidence and pgTAP coverage.

Slice 3 explicitly does not implement:

- booking team assignments;
- safety/comfort readiness;
- Newborn formal safety sign-off;
- any `safety.signoff` role change;
- Stage 9 -> 10;
- Stage 10 -> 11;
- `/prep` UI release or canonical application integration;
- Production migration or runtime rollout.

The canonical `booking_preparation_items` row shape is frozen as:

- generated item ID;
- organization ID;
- preparation ID;
- snapshotted `service_category`;
- `taxonomy_version`;
- `item_key`;
- `item_label`;
- `is_required`;
- `sort_order`;
- current `is_satisfied`;
- `satisfied_at`;
- `satisfied_by`;
- `created_at`;
- `created_by`;
- `updated_at`;
- `updated_by`.

The table must not duplicate `booking_id` or `branch_id`. Booking and branch scope are derived through the authoritative preparation and booking relationship.

The table must not contain free-form notes, generic JSON, arbitrary checklist text, medical content, safety content, comfort-readiness content or formal sign-off content.

The following fields are immutable taxonomy/identity evidence after row creation:

- organization ID;
- preparation ID;
- snapshotted service category;
- taxonomy version;
- item key;
- item label;
- required/optional classification;
- sort order;
- creation actor/time.

Only current satisfaction state and update attribution may change through the controlled RPC.

Tenant/integrity requirements are frozen as follows:

- tenant-safe uniqueness for `(organization_id, id)`;
- exactly one row per `(organization_id, preparation_id, item_key)`;
- preparation membership must be organization-safe;
- actor references must be organization-safe;
- item keys use the canonical lowercase key format;
- item labels are nonblank and bounded;
- sort order is positive;
- `is_satisfied = true` requires both `satisfied_at` and `satisfied_by`;
- `is_satisfied = false` requires both `satisfied_at` and `satisfied_by` to be NULL.

Taxonomy version 1 is the founder-approved checklist recorded above.

For taxonomy version 1:

- Maternity instantiates exactly 11 preparation items;
- Newborn instantiates exactly 11 preparation items;
- Sitter instantiates exactly 12 preparation items;
- each supported category has exactly 8 required items;
- the eight common items use stable sort orders 10 through 80;
- category-specific items begin at sort order 110 and retain their approved order;
- no staff-created or ad-hoc checklist item is permitted.

Preparation applicability is derived from the authoritative commercial chain:

`booking -> source quotation -> single package line -> commercial package version -> commercial package.service_category`.

The category is not duplicated onto `bookings` or `booking_preparations`.

Taxonomy version 1 supports exactly:

- `maternity`;
- `newborn`;
- `sitter`.

If the authoritative accepted package resolves to any service category without an approved preparation taxonomy, preparation start must fail closed before creating preparation evidence, preparation items, journey transition evidence or audit evidence.

The existing `start_pre_shoot_preparation(uuid)` operation is extended within Slice 3 while retaining all Slice 2 authorization and lifecycle gates.

First-time execution must continue to require:

- authenticated active organization membership;
- `prep.write`;
- `booking.stage.advance`;
- current stage exactly Booking Confirmed / Stage 8;
- latest authoritative shoot schedule state `reserved`.

After those existing gates pass, first-time execution must:

1. derive the authoritative service category from the accepted quotation package;
2. validate that an approved taxonomy exists for that category;
3. create the one canonical preparation instance;
4. insert the exact taxonomy-version-1 preparation-item snapshot for that category;
5. append the existing dedicated Stage 8 -> 9 transition;
6. update the journey state using the existing optimistic-version/concurrency guard;
7. append the preparation-start audit event;
8. return the authoritative preparation instance.

Preparation creation, checklist instantiation, transition evidence, journey update and audit evidence remain one atomic transaction.

The preparation-start audit may additionally record:

- service category;
- taxonomy version;
- preparation-item count.

Checklist instantiation does not append one audit event per individual item.

Exact Stage 9 replay remains authorization-first and idempotent.

An authorized exact Stage 9 replay must:

- return the same authoritative preparation instance;
- create no additional preparation;
- create no additional preparation items;
- create no additional journey transition;
- create no additional audit event;
- leave the journey version unchanged.

Replay must also verify that the existing preparation contains the exact taxonomy-version-1 structural snapshot expected for its snapshotted category. Missing, duplicate or structurally mismatched checklist evidence is an integrity failure and must not be silently repaired.

Existing satisfaction values do not make replay structurally invalid because checklist work may legitimately have progressed after preparation start.

The only new public mutation RPC in Slice 3 is:

`update_pre_shoot_preparation_item(p_preparation_item_id uuid, p_satisfied boolean)`

The RPC returns the authoritative `booking_preparation_items` row.

The RPC must be:

- `SECURITY DEFINER`;
- configured with empty `search_path`;
- executable by `authenticated`;
- unavailable to `anon`.

A checklist-item mutation requires:

- authenticated active organization membership;
- `prep.write` for the derived booking organization/branch;
- the booking journey to be exactly `pre_shoot_preparation` / Stage 9.

`booking.stage.advance` is not required for checklist-item mutation because this RPC does not move the booking journey.

The mutation must use the authoritative booking/journey/item locking order needed to serialize safely with the later Stage 9 -> 10 gate.

No Slice 3 checklist mutation may advance or regress the journey.

Satisfaction mutation semantics are frozen as follows:

- unsatisfied -> satisfied sets `is_satisfied = true`;
- it records one operation timestamp in `satisfied_at`;
- it records the authenticated organization member in `satisfied_by`;
- it updates normal update actor/time attribution;
- satisfied -> unsatisfied sets `is_satisfied = false`;
- clearing satisfaction sets both `satisfied_at` and `satisfied_by` to NULL;
- it updates normal update actor/time attribution.

An authorized request asking for the item's already-current boolean state is an idempotent replay:

- return the same authoritative row;
- do not perform an UPDATE;
- do not change timestamps or actors;
- do not append another audit event.

Every real satisfaction-state change appends exactly one non-sensitive audit event with action:

`booking.preparation_item_updated`

The audit must record the old and new satisfaction state and metadata sufficient to identify:

- booking;
- preparation;
- preparation item key;
- service category;
- taxonomy version;
- required/optional classification.

The preparation-item table must enable and force RLS.

Authenticated reads require `prep.read` using booking-derived organization and branch scope.

Authenticated direct INSERT, UPDATE and DELETE remain revoked. Mutations occur only through the approved RPC.

`anon` receives no table access.

A database guard must prevent deletion and prevent mutation of taxonomy/identity fields outside the controlled contract.

The initial Slice 3 role grants remain unchanged:

- Founder: `prep.read`, `prep.write`;
- Studio Manager: `prep.read`, `prep.write`;
- Client Coordinator: `prep.read`, `prep.write`.

No Photographer, Assistant, Stylist or other role receives preparation permission in Slice 3.

Slice 3 pgTAP coverage must prove at minimum:

1. exact table surface and tenant-safe constraints;
2. forced RLS;
3. authenticated SELECT-only direct table access;
4. anon denial;
5. exact taxonomy-version-1 item keys, labels, sort order and required flags;
6. exact 11-item Maternity snapshot;
7. exact 11-item Newborn snapshot;
8. exact 12-item Sitter snapshot;
9. exactly 8 required items for each supported category;
10. unsupported service category fails closed;
11. first preparation start atomically creates the preparation and exact checklist snapshot;
12. failure during checklist instantiation leaves no preparation, items, transition, journey movement or audit evidence;
13. exact Stage 9 replay creates no duplicate checklist evidence;
14. structurally incomplete or mismatched Stage 9 checklist evidence is an integrity failure rather than an implicit repair;
15. item update requires `prep.write`;
16. item mutation is permitted only at exact Stage 9;
17. item mutation does not move the journey;
18. false -> true records the current actor/time;
19. true -> false clears satisfaction attribution;
20. same-state retry is idempotent with no timestamp churn or audit duplication;
21. real state changes append exactly one preparation-item audit event;
22. direct authenticated mutation is denied;
23. organization and branch isolation are enforced;
24. no safety-sensitive payload exists in the preparation-item surface;
25. no Slice 3 operation creates Stage 10 or Stage 10 -> 11;
26. the existing Slice 2 71/71 regression remains green;
27. the complete database regression remains green.

Slice 3 does not introduce a blind backfill for preparation rows that may already exist before Production rollout.

Before any eventual Production migration, `booking_preparations` must be checked read-only. If any preparation row exists without canonical checklist evidence, Production rollout is HOLD until an explicit controlled migration/backfill design is approved.

The last Slice 2 Production static validation observed zero `booking_preparations` rows, but that fact must be re-verified immediately before any Slice 3 Production migration.

This technical freeze intentionally does not implement or freeze the later Stage 9 -> 10 RPC. A future Stage 9 -> 10 gate may consume the canonical preparation evidence by requiring every applicable `is_required = true` preparation item to be currently satisfied, together with the separately implemented team-assignment and safety-readiness invariants.

## Implementation state

Sprint 10 implementation preflight is complete.

**Slice 1 complete at database foundation checkpoint:** Shoot Scheduling Evidence + Confirmation Reservation Gate.

Slice 1 introduced authoritative append-only shoot-schedule evidence, the `shoot.schedule` permission, controlled proposal/reschedule RPCs, and the proposed-plan reservation requirement inside the existing `confirm_booking_after_advance(uuid)` transaction.

Primary migration:

- `20260814120719_sprint10_shoot_schedule_foundation.sql`

Implementation commit:

- `5cfbf36` — `feat: add sprint 10 shoot scheduling foundation`

Local validation evidence:

- clean local database reset through the Sprint 10 migration;
- database lint PASS with no schema errors;
- Sprint 9 booking-confirmation regression: 65/65 PASS;
- Sprint 9 KPI regression: 68/68 PASS;
- Sprint 10 shoot-scheduling suite: 111/111 PASS;
- complete local pgTAP regression: 472/472 PASS across 8 files;
- local schema drift: none;
- `git diff --check`: PASS.

Production database rollout evidence:

- linked Production project verified as `fqsdmurrzlqtkfzbwszp`;
- migration history aligned through Sprint 9 before rollout;
- Production dry run contained only `20260814120719_sprint10_shoot_schedule_foundation.sql`;
- Production migration applied successfully;
- post-rollout migration history Local = Remote through `20260814120719`;
- post-rollout dry run reported the remote database up to date;
- linked Production database lint PASS;
- Production schema dump verified forced/enabled RLS, authenticated SELECT-only table access, no authenticated direct schedule mutation grants, and `SECURITY DEFINER` plus empty `search_path` on the proposal, reschedule and confirmation RPCs.

Slice 1 does not complete Sprint 10. Pre-shoot preparation, preparation items, team assignment, restricted safety readiness/sign-off, dedicated Stage 8 -> 9 and Stage 9 -> 10 operations, application/runtime integration and remaining authenticated Production validation are still outstanding.

### Approved Slice 2 freeze — Pre-Shoot Preparation Instance + Controlled Stage 8 -> 9 Gate

Approved on 2026-08-14.

Slice 2 is limited to the authoritative preparation instance and the dedicated transition from `Booking Confirmed` to `Pre-Shoot Preparation`.

The canonical data boundary for this slice is one new `booking_preparations` table with:

- generated preparation ID;
- organization ID;
- booking ID;
- `started_at`;
- `started_by`;
- exactly one authoritative preparation row per booking;
- tenant-safe uniqueness for `(organization_id, id)` and `(organization_id, booking_id)`.

`branch_id` is not duplicated on the preparation row. Branch scope is derived from the authoritative booking.

The preparation instance is immutable evidence that canonical pre-shoot preparation has started. Slice 2 does not add a mutable preparation status, generic preparation JSON, checklist payload, safety payload or team-assignment payload.

The table must enable and force RLS. `anon` receives no access. Authenticated users may read through `prep.read` with booking-derived organization and branch scope. Authenticated direct INSERT, UPDATE and DELETE remain revoked.

The only new public mutation RPC in this slice is:

- `start_pre_shoot_preparation(p_booking_id uuid)`

The RPC must be `SECURITY DEFINER` with an empty `search_path`.

A first-time Stage 8 -> 9 execution requires:

- an authenticated active organization member;
- `prep.write` for the booking organization/branch;
- `booking.stage.advance` for the booking organization/branch;
- exactly one canonical current journey state;
- current stage exactly `booking_confirmed` / stage order 8;
- the latest authoritative shoot-schedule version to be `reserved`.

`prep.write` does not substitute for `booking.stage.advance`, and `booking.stage.advance` does not substitute for `prep.write`.

The first successful transaction must:

1. lock the authoritative booking and journey state using existing concurrency conventions;
2. validate actor and both required permissions;
3. validate Stage 8;
4. validate the latest authoritative reserved shoot schedule;
5. create the one canonical preparation instance;
6. append one Stage 8 -> 9 transition with transition key `pre_shoot_preparation_started`;
7. advance the current journey state to `pre_shoot_preparation` with exactly one version increment;
8. append audit action `booking.pre_shoot_preparation_started`;
9. return the authoritative preparation instance.

The journey update must retain the existing optimistic version check. If the captured journey state changes concurrently, the operation must fail using the existing serialization/concurrency failure pattern rather than silently retrying a different state.

Retry behavior is frozen as follows:

- an authorized retry when the booking is already exactly at Stage 9 and the one authoritative preparation instance exists returns that same instance;
- replay must not append another preparation row, transition row or audit event;
- Stage 8 with a pre-existing preparation instance is an integrity failure rather than a successful replay;
- Stage 10 or any other stage is not treated as a Stage 8 -> 9 replay.

Slice 2 explicitly does not implement:

- `booking_preparation_items`;
- `update_pre_shoot_preparation_item(...)`;
- preparation checklist taxonomy or completion semantics;
- team assignment;
- safety/comfort readiness;
- Newborn safety sign-off;
- Stage 9 -> 10;
- Stage 10 -> 11;
- `/prep` release or canonical UI integration.

Those concerns remain for later bounded Sprint 10 slices.

### Slice 2 implementation checkpoint — local validation complete

Slice 2 has now been implemented locally within the frozen boundary.

Implementation evidence:

- migration: `20260814172955_sprint10_pre_shoot_preparation_foundation.sql`;
- dedicated pgTAP suite: `sprint10_pre_shoot_preparation_test.sql`;
- implementation commit: `69aa978` (`feat: add sprint 10 pre-shoot preparation foundation`);
- canonical immutable `booking_preparations` evidence implemented;
- `prep.read` and `prep.write` granted exactly to Founder, Studio Manager and Client Coordinator;
- `start_pre_shoot_preparation(uuid)` implemented as `SECURITY DEFINER` with empty `search_path`;
- first execution requires both `prep.write` and `booking.stage.advance`;
- Stage 8 -> 9 requires the latest authoritative shoot schedule to be `reserved`;
- exact authorized Stage 9 replay returns the same preparation instance without duplicate preparation, transition or audit evidence;
- Stage 8 with pre-existing preparation evidence is rejected as an integrity failure;
- Stage 10 is not treated as replay;
- journey advancement retains the optimistic version/concurrency guard;
- authenticated direct writes to `booking_preparations` remain revoked and RLS is enabled and forced.

Local validation evidence:

- clean local database reset: PASS;
- database lint: PASS with no schema errors;
- dedicated Slice 2 pgTAP: 71/71 PASS;
- complete local pgTAP regression: 543/543 PASS across 9 files;
- local schema drift: none;
- `git diff --check`: PASS;
- no preparation-item, team-assignment, safety-readiness/sign-off, Stage 9 -> 10 or Stage 10 -> 11 production objects were introduced.

Slice 2 implementation commit `69aa978` and its checkpoint stack through `195fc2b` were pushed to `origin/architecture-rebuild`. Migration `20260814172955_sprint10_pre_shoot_preparation_foundation.sql` has been applied to the Production database.

Production rollout and static-validation evidence:

- linked Production project identity `fqsdmurrzlqtkfzbwszp`: PASS;
- pre-rollout migration history showed only `20260814172955_sprint10_pre_shoot_preparation_foundation.sql` pending;
- pre-rollout Production schema contained no Slice 2 preparation table or start-preparation RPC;
- pre-rollout linked database lint: PASS;
- pre-rollout `db push --dry-run` proposed exactly the Slice 2 migration;
- Production migration rollout: PASS;
- post-rollout migration history Local = Remote through `20260814172955`;
- post-rollout `db push --dry-run`: remote database up to date;
- post-rollout linked database lint: PASS with no schema errors;
- Production `booking_preparations` has exactly `id`, `organization_id`, `booking_id`, `started_at`, `started_by`;
- Production `booking_preparations` has RLS enabled and forced;
- authenticated access is SELECT-only and direct INSERT, UPDATE and DELETE remain denied;
- `anon` has no table read access;
- immutable preparation guard exists and is not directly executable by `anon` or `authenticated`;
- `prep.read` and `prep.write` each remain granted exactly to Founder, Studio Manager and Client Coordinator and require server enforcement;
- authenticated SELECT policy uses `prep.read` with booking-derived permission and branch scope;
- `start_pre_shoot_preparation(uuid)` is `SECURITY DEFINER` with empty `search_path`;
- authenticated may execute `start_pre_shoot_preparation(uuid)` and `anon` may not;
- deployed RPC retains the dual permission checks, reserved-schedule gate, booking/journey locking, dedicated transition/audit evidence and `40001` concurrency protection;
- Production `booking_preparations` contained zero rows at static validation time, so no real Production Stage 8 -> 9 preparation mutation was performed as part of rollout validation.

Slice 2 does not complete Sprint 10. Preparation-item workflow, team assignment, safety readiness/sign-off, the dedicated Stage 9 -> 10 gate, application/runtime integration and later Production/runtime validation remain outstanding.

### Slice 3 implementation checkpoint — local validation complete

Slice 3 — **Preparation Checklist Foundation** — has now been implemented locally within the frozen boundary.

Implementation artifacts:

- migration: `20260814191047_sprint10_preparation_checklist_foundation.sql`;
- dedicated pgTAP suite: `sprint10_preparation_items_test.sql`;
- implementation commit: `691b708` (`feat: add sprint 10 preparation checklist foundation`);
- canonical `booking_preparation_items` evidence with the frozen 16-column surface;
- internal immutable taxonomy-v1 source supporting exactly Maternity, Newborn and Sitter;
- extended `start_pre_shoot_preparation(uuid)` with authoritative category derivation, atomic taxonomy snapshot creation and strict Stage 9 structural replay validation;
- controlled `update_pre_shoot_preparation_item(uuid, boolean)` with exact Stage 9 gating, `prep.write`, same-state idempotency and one audit event per real satisfaction-state change.

Local validation evidence:

- fresh local database reset through `20260814191047_sprint10_preparation_checklist_foundation.sql`: PASS;
- database lint: PASS with no schema errors;
- dedicated Slice 3 pgTAP: 83/83 PASS;
- complete local pgTAP regression: 626/626 PASS across 10 files;
- existing Slice 2 pgTAP remains 71/71 PASS;
- local schema drift: none;
- `git diff --check`: PASS;
- refined out-of-scope leak check: empty.

Behavioral and integrity evidence:

- exact taxonomy snapshots proven for Maternity 11 items, Newborn 11 items and Sitter 12 items;
- exactly 8 required items proven for every supported category;
- unsupported categories fail closed;
- exact Stage 8 -> 9 preparation start creates one preparation instance, the exact checklist snapshot, one dedicated transition and one start audit atomically;
- exact Stage 9 replay is idempotent and permits legitimate satisfaction-state differences;
- structurally damaged Stage 9 checklist evidence fails closed without repair or journey movement;
- checklist-instantiation failure rolls back preparation, checklist, transition, journey and audit evidence atomically;
- `false -> true`, same-state replay and `true -> false` item mutations are validated with correct satisfaction attribution and audit cardinality;
- checklist mutation never advances, regresses or versions the booking journey;
- authenticated direct preparation-item INSERT, UPDATE and DELETE are denied;
- missing `prep.write`, wrong-stage mutation, branch-scope violation and cross-organization mutation are denied without evidence mutation;
- forced RLS read isolation is validated for branch-scoped and foreign-organization actors.

Authorization remains unchanged:

- `prep.read` and `prep.write` remain limited to Founder, Studio Manager and Client Coordinator;
- no Photographer, Assistant, Stylist or other role receives preparation permission in Slice 3;
- `start_pre_shoot_preparation(...)` retains the Slice 2 `booking.stage.advance` requirement;
- `update_pre_shoot_preparation_item(...)` requires `prep.write` but does not require or perform journey advancement.

Slice 3 containment remains intact:

- no team-assignment implementation;
- no safety-readiness or formal safety-signoff implementation;
- no `safety.signoff` role-grant change;
- no Stage 9 -> 10 operation;
- no Stage 10 -> 11 operation;
- no `/prep` runtime/UI release;
- no Production migration or runtime rollout.

Production status at this checkpoint:

- implementation commit `691b708` is local-only and has not yet been pushed to `origin/architecture-rebuild`;
- migration `20260814191047_sprint10_preparation_checklist_foundation.sql` has not been applied to Production;
- latest Production DB migration remains `20260814172955_sprint10_pre_shoot_preparation_foundation.sql`;
- no blind preparation-item backfill exists;
- immediately before any Slice 3 Production migration, `booking_preparations` must be re-checked read-only and any unmatched existing preparation row places rollout on HOLD pending an explicit controlled design.

Slice 3 does not complete Sprint 10. Team assignment, restricted safety readiness/sign-off, the dedicated Stage 9 -> 10 gate, application/runtime integration and later Production/runtime validation remain outstanding.

### Slice 3 Production checkpoint — database + static validation complete

Slice 3 implementation commit `691b708` and local-checkpoint commit `63ef223` were pushed to `origin/architecture-rebuild`. Migration `20260814191047_sprint10_preparation_checklist_foundation.sql` has been applied to the Production database.

Production rollout evidence:

- pre-rollout linked migration history matched Production through `20260814172955_sprint10_pre_shoot_preparation_foundation.sql`;
- mandatory just-in-time read-only `booking_preparations` anomaly check returned zero rows;
- pre-rollout Production had no `booking_preparation_items` table and no `update_pre_shoot_preparation_item(uuid, boolean)` RPC;
- linked `db push --dry-run` proposed exactly `20260814191047_sprint10_preparation_checklist_foundation.sql`;
- Production migration rollout: PASS;
- post-rollout migration history Local = Remote through `20260814191047`;
- post-rollout linked dry run reports the remote database up to date;
- linked database lint: PASS with no schema errors.

Production static security and invariant evidence:

- `booking_preparation_items` has exactly the frozen 16-column surface;
- `booking_preparation_items` has RLS enabled and forced;
- `anon` has no table SELECT, INSERT, UPDATE or DELETE access;
- `authenticated` has SELECT access only and no direct INSERT, UPDATE or DELETE access;
- the authenticated SELECT policy requires `prep.read` and the derived booking branch-scope boundary;
- the canonical preparation-item guard trigger is enabled for INSERT, UPDATE and DELETE;
- organization-safe preparation/member foreign keys, tenant uniqueness, item-key, label, taxonomy-version, sort-order and satisfaction-state constraints are present;
- `start_pre_shoot_preparation(uuid)` remains `SECURITY DEFINER`, uses empty `search_path`, is authenticated-executable and anon-inaccessible;
- `update_pre_shoot_preparation_item(uuid, boolean)` is `SECURITY DEFINER`, uses empty `search_path`, is authenticated-executable and anon-inaccessible;
- the internal taxonomy helper is not executable by `anon` or `authenticated`;
- `prep.read` and `prep.write` remain granted exactly to Founder, Studio Manager and Client Coordinator;
- Production function definitions retain the approved Maternity, Newborn and Sitter taxonomy markers, unsupported-category fail-closed guard, strict Stage 9 structural replay guard, exact Stage 9 checklist-mutation gate and preparation-item update audit;
- the successful Production migration necessarily passed its embedded taxonomy cardinality/integrity assertions.

Production data state at static validation time:

- `booking_preparations`: zero rows;
- `booking_preparation_items`: zero rows;
- no artificial Production booking/preparation mutation was created solely for rollout validation.

Vercel deployment evidence:

- Production deployment `dpl_Fv9XHo9N7Yo1YWRyxHaitsSSUiGi`: READY;
- deployed Git commit: `63ef223263b29bafb281d02ec3efaf7b6a33c463`;
- deployed Git branch: `architecture-rebuild`.

Slice 3 remains contained at its approved database-foundation boundary. No team assignment, safety readiness/sign-off, `safety.signoff` role change, Stage 9 -> 10 transition, Stage 10 -> 11 transition or `/prep` runtime/UI release is included.

Slice 3 does not complete Sprint 10. Team assignment, restricted safety readiness/sign-off, the dedicated Stage 9 -> 10 gate, application/runtime integration and remaining Sprint 10 validation remain outstanding.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 4 founder decision freeze — Booking Team Assignment Foundation

Founder business decisions approved on 2026-08-15.

Slice 4 establishes canonical booking-scoped operational team-assignment evidence. It does not redefine organization membership or organization role grants.

Approved founder decisions:

1. Canonical booking-team evidence will use the concept `booking_team_assignments`.

2. Organization roles and booking assignments are separate facts. An organization role establishes operational eligibility; it does not itself mean that member is assigned to a specific booking.

3. Initial booking-assignment roles are exactly:
   - `lead_photographer`
   - `assistant`
   - `stylist`

   Editor, Album / Print Coordinator, Marketing, Accounts, Client Coordinator and later-production responsibilities are not booking-assignment roles in Slice 4.

4. Current-assignment cardinality:
   - exactly one current `lead_photographer` per booking;
   - multiple current `assistant` assignments are permitted;
   - multiple current `stylist` assignments are permitted.

   Singular Lead Photographer semantics are required because later Newborn safety authorization depends on identifying the booking's assigned Lead Photographer unambiguously.

5. Assignment eligibility:
   - `lead_photographer` requires an active `photographer` organization-role grant;
   - `assistant` requires an active `assistant` organization-role grant;
   - `stylist` requires an active `stylist` organization-role grant.

   Founder or Studio Manager authority alone does not make a member operationally eligible for one of these assignment roles. A member must hold the corresponding operational role.

6. Branch eligibility:
   - for a branch-scoped booking, the assignee's qualifying organization-role grant must be organization-wide or scoped to that booking's branch;
   - a role scoped only to another branch is insufficient;
   - for a booking with no branch, the qualifying role must be organization-wide.

7. Slice 4 introduces the dedicated permission `booking.team.assign` with server-side enforcement required.

   Initial role grants for `booking.team.assign` are exactly:
   - Founder (`founder`);
   - Studio Manager (`studio_manager`);
   - Client Coordinator (`client_coordinator`).

   Photographer, Assistant and Stylist roles do not receive self-assignment authority merely because they are eligible to be assigned.

8. Read access to booking-team assignments follows `booking.read` plus the booking-derived branch-scope boundary. `team.role.assign` is not required merely to view booking staffing.

9. Team assignments may be created, replaced or removed only while the booking is in one of these canonical stages:
   - Stage 8 — `booking_confirmed`;
   - Stage 9 — `pre_shoot_preparation`;
   - Stage 10 — `shoot_scheduled`.

   Team assignment mutation never advances or rewinds the booking journey.

10. Assignment replacement/removal must preserve historical evidence. Normal application behavior must not silently overwrite or delete prior assignment history.

    - first assignment does not require a replacement reason;
    - replacement or removal requires a nonblank reason;
    - an exact replay of the current assignment state must be idempotent;
    - an idempotent replay must not create duplicate assignment history or duplicate audit evidence.

11. Slice 4 does not freeze category-specific Stage 9 -> 10 team requirements. The later dedicated Stage 9 -> 10 gate will determine which assignment roles are mandatory for each applicable service category using the canonical assignment evidence created here.

12. The public mutation boundary remains the previously frozen `assign_booking_team_member(...)` concept. Exact parameters, return type, locking, replacement semantics, history representation, RLS policy shape and audit payload remain subject to a separate Slice 4 technical design freeze.

13. Slice 4 containment is explicit:
    - no `safety.signoff` role-grant change;
    - no safety or comfort-readiness data;
    - no Newborn safety-signoff implementation;
    - no Stage 9 -> 10 transition;
    - no Stage 10 -> 11 transition;
    - no photographer-capacity, studio-capacity, scheduling-overlap or availability engine;
    - no `/bookings`, `/prep` or `/safety` UI implementation;
    - no Production database migration.

The approved business source remains aligned with the studio operating model: booking confirmation includes team assignment, while shoot responsibilities are booking/session-specific, including Lead Photographer + Assistant / Baby Care Support for Newborn work and Lead Photographer + Stylist / Makeup Artist for Maternity work.

This founder freeze approves the operational semantics only. Database shape, assignment-history model, RPC contract, locking order, security policies, direct-write denial, audit payloads, exact idempotency mechanics and pgTAP coverage are frozen below before implementation.

### Slice 4 technical design freeze — Booking Team Assignment Foundation

Technical design approved on 2026-08-15.

The Slice 4 implementation must remain bounded to canonical booking-scoped operational assignment evidence and its controlled mutation boundary.

#### Canonical table and lifecycle model

The canonical table is:

- `public.booking_team_assignments`

The table uses a controlled lifecycle-row model rather than a booking-wide immutable version chain.

Each row represents one historical period during which one organization member held one booking assignment.

A row:

- is inserted as active;
- may later be closed exactly once;
- must never be deleted through the normal domain path;
- must never be reopened;
- must never be reassigned to another member;
- must never have its original booking, assignment role, assignment timestamp or assigning actor rewritten.

This lifecycle model deliberately mirrors the active/revoked historical pattern already used by organization role grants while supporting multiple simultaneous Assistants and Stylists.

#### Exact table surface

`booking_team_assignments` contains exactly these domain columns:

1. `id uuid`
2. `organization_id uuid`
3. `booking_id uuid`
4. `assignment_role text`
5. `assigned_member_id uuid`
6. `assigned_at timestamptz`
7. `assigned_by uuid`
8. `ended_at timestamptz NULL`
9. `ended_by uuid NULL`
10. `end_reason text NULL`

Slice 4 must not add redundant booking branch, service category, organization-role ID, journey-stage snapshot, safety-readiness data or general metadata JSON to this table.

#### Assignment-role taxonomy

`assignment_role` is constrained text, not a PostgreSQL enum.

Allowed values are exactly:

- `lead_photographer`
- `assistant`
- `stylist`

No additional assignment role is introduced by Slice 4.

#### Referential and state integrity

The table must use tenant-safe foreign keys to:

- the authoritative booking;
- the assigned organization member;
- the assigning organization member;
- the ending organization member when a row is closed.

The table must expose tenant-safe composite assignment identity sufficient for later booking-specific references.

Ending state is all-or-nothing:

- active row: `ended_at`, `ended_by` and `end_reason` are all NULL;
- closed row: `ended_at`, `ended_by` and nonblank `end_reason` are all present.

`ended_at` must not precede `assigned_at`.

#### Current-assignment uniqueness

Current assignments are rows where `ended_at IS NULL`.

Partial uniqueness must enforce:

1. exactly one current `lead_photographer` per booking;

2. no duplicate current assignment of the same member to the same booking assignment role.

The second invariant must still permit multiple distinct current Assistants and multiple distinct current Stylists for one booking.

#### Controlled row guard

A dedicated normal trigger function:

- `public.lsh_booking_team_assignment_guard()`

must use an empty `search_path`.

Its domain rules are:

- DELETE is rejected;
- INSERT must create an active assignment;
- UPDATE may only close one previously active row;
- immutable identity and original assignment evidence may not change;
- a closed row may not be modified again;
- authenticated actor attribution must resolve to the current active organization member.

The guard itself is not a client mutation API.

#### Permission boundary

Slice 4 introduces exactly:

- `booking.team.assign`

with domain `bookings` and server-side enforcement required.

Its initial grants are exactly:

- `founder`
- `studio_manager`
- `client_coordinator`

There must be exactly three role grants for this permission.

It is not granted to:

- `photographer`
- `assistant`
- `stylist`

and `team.role.assign` is not reused as a booking-staffing permission.

#### RLS and table ACL boundary

`booking_team_assignments` must have:

- RLS enabled;
- FORCE RLS enabled;
- exactly the intended authenticated SELECT policy for the Slice 4 table.

Authenticated read access derives through the authoritative booking and requires:

- `booking.read`;
- booking-derived branch scope when the booking has a branch.

`team.role.assign` is not required to read booking staffing.

Table privileges must preserve the Sprint 10 pattern:

- `anon`: no table access;
- `authenticated`: SELECT only;
- no authenticated direct INSERT;
- no authenticated direct UPDATE;
- no authenticated direct DELETE;
- trusted `service_role` administration remains outside the normal domain path.

#### Public mutation RPC

The frozen public mutation boundary is:

`assign_booking_team_member(uuid,text,uuid,boolean,text)`

with the logical signature:

- `p_booking_id uuid`
- `p_assignment_role text`
- `p_member_id uuid`
- `p_is_assigned boolean`
- `p_change_reason text DEFAULT NULL`

and return type:

- `public.booking_team_assignments`

The function must be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated`;
- inaccessible to `anon`.

It requires:

- authenticated user identity;
- active organization membership;
- `booking.team.assign`;
- booking-derived branch scope.

It does not require:

- `team.role.assign`;
- `booking.write`;
- `booking.stage.advance`.

#### Canonical locking order

Booking-team mutation uses the canonical booking serialization boundary:

1. authoritative booking;
2. authoritative current booking journey state;
3. relevant current `booking_team_assignments` evidence.

For assignment creation or replacement, the implementation must additionally lock or otherwise serialize the target organization-member and qualifying live role-grant eligibility sufficiently to prevent a concurrent suspension or role revocation from invalidating the assignment during creation.

Unassignment must remain possible when a previously assigned member has subsequently become suspended or has lost the qualifying operational role.

#### Journey-stage boundary

Exactly one canonical booking journey state must exist.

The active current stage must be exactly one of:

- Stage 8 — `booking_confirmed`;
- Stage 9 — `pre_shoot_preparation`;
- Stage 10 — `shoot_scheduled`.

The assignment RPC must not:

- insert booking journey transitions;
- update `booking_journey_states`;
- advance the journey;
- rewind the journey.

#### Assignment eligibility

When `p_is_assigned = true`, the target organization member must currently be active and have an unrevoked qualifying organization role:

- `lead_photographer` -> `photographer`
- `assistant` -> `assistant`
- `stylist` -> `stylist`

For a branch-scoped booking:

- an organization-wide qualifying grant is valid;
- a qualifying grant for the same booking branch is valid;
- a qualifying grant only for another branch is invalid.

For a branchless booking:

- only an organization-wide qualifying role grant is valid.

Assignment evidence does not permanently guarantee future operational eligibility. Later safety and Stage 9 -> 10 logic must independently verify whatever eligibility remains required at that later boundary.

#### Mutation semantics and idempotency

First assignment:

- inserts one active assignment row;
- does not require a change reason.

Exact current-state assignment replay:

- is a true no-op;
- returns existing authoritative evidence;
- creates no new assignment history;
- creates no audit event.

Lead Photographer replacement:

- requires a nonblank change reason;
- atomically closes the current Lead Photographer row;
- inserts the replacement active Lead Photographer row;
- must roll back completely if replacement creation fails.

Assistant and Stylist assignment:

- may add another distinct eligible current member;
- does not replace other current members;
- does not require a change reason when adding a new member.

Unassignment:

- closes the exact current assignment row;
- requires a nonblank change reason;
- does not delete history.

Successful unassignment replay:

- may return the latest already-closed matching assignment evidence;
- must not create another mutation;
- must not create another audit event.

Attempting to unassign a member who has never held that assignment role for the booking must fail rather than silently succeed.

#### Audit contract

Each real RPC state change creates exactly one non-sensitive audit event.

Frozen action keys are:

- `booking.team_member_assigned`
- `booking.team_member_replaced`
- `booking.team_member_unassigned`

Entity type is:

- `booking_team_assignment`

Lead Photographer replacement produces one replacement audit event rather than separate unassignment and assignment audit events.

Exact idempotent replay produces zero additional audit events.

Audit values contain structural assignment identifiers, role and state information only. The canonical free-text replacement/removal reason remains on the assignment evidence rather than being unnecessarily duplicated into broad audit payloads.

#### Dedicated pgTAP acceptance matrix

The Slice 4 dedicated pgTAP suite must prove at minimum:

- exact table surface;
- tenant-safe foreign keys;
- role and lifecycle checks;
- current Lead Photographer singularity;
- duplicate-current-member prevention;
- multiple distinct Assistants;
- multiple distinct Stylists;
- exact `booking.team.assign` permission creation;
- exact three permission grants;
- FORCE RLS;
- authenticated SELECT-only table access;
- anon denial;
- direct authenticated INSERT denial;
- direct authenticated UPDATE denial;
- direct authenticated DELETE denial;
- RPC SECURITY DEFINER state;
- RPC empty `search_path`;
- authenticated-only RPC execution;
- Stage 8 assignment;
- Stage 9 assignment;
- Stage 10 assignment;
- wrong-stage denial;
- Founder assignment authority;
- Studio Manager assignment authority;
- Client Coordinator assignment authority;
- Photographer self-assignment denial without `booking.team.assign`;
- Lead Photographer eligibility mapping;
- Assistant eligibility mapping;
- Stylist eligibility mapping;
- suspended-member assignment denial;
- revoked-role assignment denial;
- organization-wide role eligibility;
- same-branch role eligibility;
- wrong-branch role denial;
- branchless-booking organization-wide requirement;
- first assignment;
- exact assignment replay;
- Lead Photographer replacement;
- Lead replacement reason requirement;
- atomic rollback on failed Lead replacement;
- Assistant addition without replacement;
- Stylist addition without replacement;
- unassignment;
- unassignment reason requirement;
- unassignment idempotent replay;
- never-assigned unassignment failure;
- one audit event per real state change;
- zero duplicate audit events for replay;
- no booking journey movement;
- cross-organization isolation.

#### Slice 4 implementation containment

Slice 4 technical approval does not authorize:

- any `safety.signoff` role-grant change;
- safety-readiness data;
- Newborn formal safety sign-off;
- Stage 9 -> 10 advancement;
- Stage 10 -> 11 advancement;
- photographer-capacity rules;
- studio-capacity rules;
- scheduling-overlap rules;
- availability optimization;
- `/bookings` team-assignment UI;
- `/prep` runtime/UI release;
- `/safety` runtime/UI release;
- Production rollout.

The next implementation slice is limited to the Slice 4 database foundation and dedicated local pgTAP coverage defined by this technical freeze.

### Slice 4 local implementation checkpoint — Booking Team Assignment Foundation

Slice 4 database-foundation implementation completed and locally validated on 2026-08-15.

Implementation evidence:

- migration: `20260814214746_sprint10_booking_team_assignment_foundation.sql`;
- dedicated pgTAP: `supabase/tests/sprint10_booking_team_assignments_test.sql`;
- implementation commit: `b579635e1bdd23264c5c9f400892b837761b7abd`;
- implementation commit pushed to `origin/architecture-rebuild`;
- implementation boundary is exactly the migration plus the dedicated pgTAP file;
- no application/runtime/UI file is included.

Canonical database evidence implemented:

- `public.booking_team_assignments` with exactly 10 frozen domain columns;
- lifecycle-row history model with active rows closed exactly once and historical rows preserved;
- tenant-safe booking/member/actor foreign-key boundaries;
- singular current `lead_photographer`;
- multiple distinct current `assistant` and `stylist` assignments permitted;
- duplicate current member-role assignments prevented;
- normal lifecycle guard `public.lsh_booking_team_assignment_guard()`;
- RLS enabled and FORCE RLS enabled;
- authenticated SELECT-only table access;
- no authenticated direct INSERT, UPDATE or DELETE;
- dedicated `booking.team.assign` permission;
- exact permission grants to Founder, Studio Manager and Client Coordinator;
- controlled authenticated-only `SECURITY DEFINER` RPC `assign_booking_team_member(uuid,text,uuid,boolean,text)` with empty `search_path`;
- Stage 8 / Stage 9 / Stage 10 assignment mutation boundary;
- no journey advancement or rewind;
- operational-role and branch eligibility enforcement;
- historical removal remains possible after later suspension or operational-role revocation;
- one audit event per real assignment, replacement or unassignment state change;
- exact replay produces no duplicate history or audit event.

Local validation evidence:

- clean local DB reset through migration `20260814214746`: PASS;
- local DB lint: PASS with `No schema errors found`;
- dedicated Slice 4 pgTAP: 75 / 75 PASS;
- complete local pgTAP regression: 701 / 701 PASS across 11 files;
- local schema diff: exit 0;
- local schema drift: none / 0 bytes;
- static assignment table column count: 10;
- static assignment RLS-policy count: 1;
- `booking.team.assign` role-grant count: 3;
- out-of-scope implementation leak check: none;
- whitespace / staged diff hygiene: PASS;
- local/remote branch divergence after implementation push: 0 / 0.

Validated behavioral boundaries include:

- assignment denied before Stage 8;
- Founder assignment at Stage 8;
- Studio Manager assignment at Stage 9;
- Client Coordinator assignment at Stage 10;
- ordinary Photographer cannot self-assign without `booking.team.assign`;
- Lead Photographer replacement requires a nonblank reason;
- failed Lead replacement rolls back closure, replacement insert and audit atomically;
- multiple Assistants are permitted;
- suspended members cannot receive new assignments;
- revoked operational-role grants cannot satisfy new-assignment eligibility;
- branchless bookings require organization-wide operational eligibility;
- same-branch operational grants qualify for branch bookings;
- wrong-branch-only operational grants fail closed;
- unassignment remains permitted after later role revocation or member suspension;
- cross-organization mutation and read isolation are enforced;
- direct authenticated DML is denied;
- trusted direct mutation remains constrained by the lifecycle guard.

Slice 4 remains contained. This checkpoint does not include or authorize:

- any `safety.signoff` role-grant change;
- safety-readiness or comfort-readiness evidence;
- Newborn formal safety sign-off;
- Stage 9 -> 10 advancement;
- Stage 10 -> 11 advancement;
- category-specific required-team Stage 9 -> 10 rules;
- capacity, overlap or availability logic;
- `/bookings` team-assignment UI;
- `/prep` runtime/UI release;
- `/safety` runtime/UI release;
- any Production database migration.

### Slice 4 Production checkpoint

Slice 4 database migration `20260814214746_sprint10_booking_team_assignment_foundation.sql` has been applied to Production.

Production rollout evidence:

- pre-rollout Local / Remote migration history aligned through `20260814191047`;
- exactly one migration was pending before rollout: `20260814214746_sprint10_booking_team_assignment_foundation.sql`;
- pre-rollout linked DB lint: PASS with `No schema errors found`;
- pre-rollout migration dry run: exactly the approved Slice 4 migration;
- Production migration push: PASS;
- post-rollout Local / Remote migration history aligned through `20260814214746`;
- post-rollout linked DB lint: PASS with `No schema errors found`;
- post-rollout migration dry run: remote database up to date.

Production collision / no-backfill evidence:

- no pre-existing `public.booking_team_assignments` relation was present before rollout;
- no pre-existing `assign_booking_team_member(uuid,text,uuid,boolean,text)` RPC was present before rollout;
- no pre-existing `booking.team.assign` permission was present before rollout;
- no legacy mock photographer value, booking owner, organization role or other existing field was inferred or backfilled;
- `booking_team_assignments` contains zero rows at the Production static-validation checkpoint.

Production static security / invariant evidence:

- `public.booking_team_assignments` has exactly the frozen 10-column surface;
- RLS enabled: PASS;
- FORCE RLS enabled: PASS;
- exactly one authenticated SELECT policy: PASS;
- authenticated table access is SELECT-only;
- anon table access denied;
- trusted `service_role` table privileges preserved;
- `booking.team.assign` exists exactly once;
- `booking.team.assign` grants are exactly Founder, Studio Manager and Client Coordinator;
- current Lead Photographer uniqueness index present;
- current member-role uniqueness index present;
- lifecycle guard trigger present;
- tenant-safe booking/member/actor foreign keys present;
- assignment-role, lifecycle, end-reason and end-time constraints present;
- `assign_booking_team_member(uuid,text,uuid,boolean,text)` is `SECURITY DEFINER`;
- assignment RPC has empty `search_path`;
- assignment RPC is authenticated-executable and anon-denied;
- lifecycle guard is not `SECURITY DEFINER`, has empty `search_path`, and is not authenticated/anon executable;
- function invariants retain the exact Stage 8 / Stage 9 / Stage 10 mutation boundary;
- function invariants require `booking.team.assign`;
- function invariants do not require `booking.stage.advance`, `booking.write` or `team.role.assign`;
- function invariants retain Lead Photographer / Photographer / Assistant / Stylist eligibility semantics;
- assignment, replacement and unassignment audit-event paths are present;
- locking path is present;
- no booking-journey mutation is performed;
- no assignment DELETE path is performed.

No artificial Production assignment mutation was exercised because the canonical booking-team assignment table contained zero rows at static validation time.

Slice 4 Production remains contained. This checkpoint does not release or implement:

- safety-readiness or comfort-readiness evidence;
- any `safety.signoff` role-grant change;
- Newborn formal safety sign-off;
- Stage 9 -> 10 advancement;
- Stage 10 -> 11 advancement;
- category-specific required-team Stage 9 -> 10 rules;
- capacity, overlap or availability logic;
- `/bookings` team-assignment UI;
- `/prep` runtime/UI release;
- `/safety` runtime/UI release.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 5 founder decision checkpoint — Restricted Safety/Comfort Readiness + Newborn Formal Sign-off Foundation

Founder decisions approved on 2026-08-15.

Slice 5 is a separately bounded evidence foundation. These business decisions are frozen before technical design.

#### 1. Evidence-only Slice 5 boundary

Slice 5 may introduce canonical restricted safety/comfort readiness evidence, immutable formal sign-off evidence, and the already-approved Photographer `safety.signoff` grant.

Slice 5 does not implement or release:

- Stage 9 -> 10 advancement;
- Stage 10 -> 11 advancement;
- `/safety` runtime/UI;
- shoot-day safety evidence;
- capacity, overlap or availability logic.

#### 2. Safety/comfort readiness is booking-scoped restricted evidence

Safety/comfort readiness is canonical booking-scoped restricted evidence.

It remains separate from ordinary preparation checklist evidence and must not be copied into broad booking, CRM, KPI, reporting or other unrestricted operational surfaces.

#### 3. Readiness remains structured and operational

Slice 5 readiness evidence records controlled operational readiness states only.

It must not become:

- medical history;
- diagnosis;
- treatment advice;
- feeding or sleep records;
- temperature records;
- posing logs;
- shoot-day incident records;
- arbitrary free-form medical or safety notes.

#### 4. Applicability follows the authoritative booking service category

Category behavior is frozen as follows:

- **Newborn:** applicable safety/comfort readiness must be complete and formal sign-off is required;
- **Maternity:** applicable comfort readiness must be complete; no separate formal sign-off;
- **Sitter / Baby / Child:** applicable safety/comfort readiness must be complete; no separate formal sign-off;
- unsupported or unmapped categories fail closed rather than being inferred.

#### 5. Readiness mutation is exact Stage 9 only

`record_booking_safety_readiness(...)` may mutate canonical pre-shoot readiness only while the booking is exactly:

- Stage 9;
- `pre_shoot_preparation`.

Stage 8 is too early for canonical readiness mutation.

Stage 10 is beyond the pre-shoot readiness-preparation mutation boundary.

The readiness RPC does not move the booking journey.

#### 6. `safety.write` is the readiness-recording authority

An active organization member with:

- `safety.write`; and
- valid booking-derived branch scope

may record readiness.

A booking-team assignment is not additionally required merely to record readiness.

Existing `safety.write` role grants remain unchanged.

#### 7. Formal sign-off is Newborn-only

`signoff_booking_safety_readiness(...)` is valid only for a booking category that requires formal Newborn safety sign-off.

A formal sign-off attempt for a category that does not require separate formal sign-off must fail closed.

#### 8. Sign-off requires complete current readiness

A Newborn formal sign-off may occur only after the currently applicable readiness evidence is complete and ready.

Missing, pending, explicitly not-ready, malformed or unsupported readiness evidence cannot be formally signed.

#### 9. Formal sign-off authority

Formal sign-off authorization is exactly:

- Founder;
- Studio Manager;
- Photographer only when that Photographer is the booking's current canonical Lead Photographer.

Client Coordinator, Assistant and Stylist do not receive `safety.signoff`.

The existing Founder and Studio Manager `safety.signoff` grants remain.

Slice 5 adds `safety.signoff` to Photographer, with server-side Lead Photographer enforcement.

#### 10. Photographer eligibility is checked at sign-off time

For an ordinary Photographer to sign Newborn readiness, the signer must at sign-off time:

- be an active organization member;
- retain an active, unrevoked qualifying Photographer role grant for the booking scope;
- be the booking's current canonical `lead_photographer` assignment.

A historical or ended Lead Photographer assignment is insufficient.

#### 11. Readiness revisions preserve history

A real readiness change after formal sign-off creates new readiness revision/current evidence.

Existing formal sign-offs remain immutable historical evidence but do not satisfy the new current readiness revision.

The current Newborn readiness revision must be formally signed again.

#### 12. Lead replacement and Photographer sign-off validity

If the current qualifying Newborn sign-off was made by an ordinary Photographer and that Photographer is later replaced as Lead before Stage 9 -> 10:

- the sign-off remains immutable historical evidence;
- that Photographer sign-off no longer satisfies the future advancement gate;
- the new current Lead Photographer or Founder / Studio Manager must sign the current readiness.

A valid Founder or Studio Manager administrative sign-off is not invalidated merely because the Lead Photographer changes.

#### 13. Later suspension or role loss does not rewrite history

A signer who was authorized at signing time remains recorded as the historical signer.

Later member suspension, role revocation or assignment change does not mutate or delete the historical sign-off.

Current assignment and operational eligibility are separately revalidated by later journey-gate logic where required.

#### 14. Multiple immutable sign-offs and replay semantics

Multiple immutable sign-offs may exist for one readiness revision.

Each signer may sign a readiness revision at most once.

An exact same-signer replay is idempotent and creates:

- no duplicate sign-off;
- no duplicate audit event.

The future Stage 9 -> 10 gate will require at least one currently valid qualifying Newborn sign-off.

#### 15. Readiness replay and revision semantics

Re-recording exactly the same controlled readiness state is an idempotent no-op.

It creates:

- no new readiness revision;
- no duplicate audit event.

A real readiness-state change creates new historical/current evidence rather than silently rewriting previously signed evidence in place.

#### 16. Restricted audit boundary

Audit events may contain structural evidence only, including:

- booking identifier;
- readiness revision identifier;
- controlled readiness state transition;
- signer identifier;
- sign-off authorization type.

Audit payloads must not contain private safety/comfort details, medical content or arbitrary sensitive free text.

#### 17. No blind backfill

Slice 5 must not infer safety/comfort readiness or formal sign-off from:

- preparation instances;
- preparation checklist items;
- booking owner fields;
- Lead records;
- organization roles alone;
- booking-team history alone;
- legacy or mock safety values.

Any future Production rollout requires a fresh read-only anomaly/collision preflight immediately before migration.

At this founder-decision checkpoint, Production prerequisite evidence remains intentionally unmodified.

#### Public mutation concepts retained

The approved public mutation concepts remain:

- `record_booking_safety_readiness(...)`;
- `signoff_booking_safety_readiness(...)`.

Exact signatures, table shapes, revision mechanics, locking order, RLS policy definitions, audit event names and pgTAP implementation details remain subject to a separate Slice 5 technical design freeze.

#### Slice 5 containment

This founder-decision checkpoint does not authorize:

- creation of `booking_safety_readiness`;
- creation of `booking_safety_signoffs`;
- modification of `safety.signoff`;
- implementation of either safety mutation RPC;
- Stage 9 -> 10 implementation;
- Stage 10 -> 11 implementation;
- `/safety` runtime/UI work;
- Production migration.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 5 technical design freeze — Restricted Safety/Comfort Readiness + Newborn Formal Sign-off Foundation

Technical design approved on 2026-08-15.

This freeze translates the approved Slice 5 founder decisions into the exact database implementation boundary. Implementation remains unauthorized until this technical-freeze checkpoint is reviewed, committed and pushed.

#### 1. Canonical evidence tables

Slice 5 introduces exactly two canonical evidence concepts:

- `public.booking_safety_readiness`;
- `public.booking_safety_signoffs`.

Readiness evidence must not be embedded into:

- `booking_preparations`;
- `booking_preparation_items`;
- `bookings`;
- `booking_team_assignments`.

#### 2. `booking_safety_readiness` exact domain surface

`booking_safety_readiness` uses a controlled revision lifecycle and contains exactly these 11 domain columns:

1. `id uuid`;
2. `organization_id uuid`;
3. `booking_id uuid`;
4. `service_category text`;
5. `revision_number integer`;
6. `safety_state text`;
7. `comfort_state text`;
8. `recorded_at timestamptz`;
9. `recorded_by uuid`;
10. `superseded_at timestamptz NULL`;
11. `superseded_by uuid NULL`.

A row is current only when both supersession fields are NULL.

A historical revision has both supersession fields populated.

Historical readiness state is never rewritten.

#### 3. Controlled readiness-state vocabulary

Both `safety_state` and `comfort_state` use text CHECK constraints with exactly:

- `pending`;
- `ready`;
- `not_ready`;
- `not_applicable`.

Slice 5 does not introduce:

- JSON readiness payloads;
- arbitrary metadata;
- unrestricted note fields;
- medical-detail fields;
- free-text safety reasons.

#### 4. Category applicability matrix

The readiness RPC resolves service category server-side from the authoritative accepted quotation/package source already used by the preparation foundation.

The caller does not supply service category.

Supported normalized categories are exactly:

- `newborn`;
- `maternity`;
- `sitter`;
- `baby`;
- `child`.

Enforcement is:

- `newborn`: safety and comfort are applicable; neither may be `not_applicable`;
- `maternity`: safety must be `not_applicable`; comfort is applicable;
- `sitter`, `baby`, `child`: safety and comfort are applicable;
- unsupported or unmapped categories fail closed.

A readiness revision is complete and ready only when every applicable state is exactly `ready`.

#### 5. Readiness identity and uniqueness

Required uniqueness boundaries are:

- `UNIQUE (organization_id, booking_id, revision_number)`;
- `UNIQUE (id, organization_id, booking_id)` for tenant-safe downstream references;
- exactly one current revision per booking through a partial unique index on `(organization_id, booking_id)` where `superseded_at IS NULL`.

Revision numbers are positive and monotonically increase per booking.

#### 6. Readiness lifecycle guard

Slice 5 introduces normal trigger function:

`public.lsh_booking_safety_readiness_guard()`

with empty `search_path`.

The guard enforces:

- DELETE always fails;
- INSERT must create an unsuperseded revision;
- authenticated actor attribution must match the current active organization member;
- UPDATE may only close a current revision exactly once;
- identity, tenant, booking, category, revision, readiness states, original recorder and original recorded timestamp are immutable;
- closed revisions are immutable;
- reopening is impossible;
- `superseded_at >= recorded_at`;
- direct authenticated mutation remains denied at the table ACL boundary.

#### 7. Readiness RPC signature

The public readiness mutation signature is frozen exactly as:

`record_booking_safety_readiness(p_booking_id uuid, p_safety_state text, p_comfort_state text) RETURNS public.booking_safety_readiness`

It is:

- `SECURITY DEFINER`;
- empty `search_path`;
- executable by `authenticated`;
- not executable by `anon`.

#### 8. Readiness authorization and stage gate

`record_booking_safety_readiness(...)` requires:

- active organization membership;
- `safety.write`;
- booking-derived branch scope;
- exactly one canonical journey state;
- active current stage exactly Stage 9 / `pre_shoot_preparation`.

It does not require:

- booking-team assignment;
- `safety.signoff`;
- `booking.write`;
- `booking.stage.advance`;
- `booking.team.assign`.

It never advances, rewinds or otherwise mutates the booking journey.

#### 9. Readiness revision semantics

The readiness RPC locks the booking before resolving current readiness.

Mutation semantics are exactly:

- no current readiness -> insert revision `1`;
- exact same authoritative category + safety state + comfort state -> return the current row as an idempotent no-op;
- real state change -> close the current revision and insert revision `N + 1` atomically;
- no readiness-state rewrite in place;
- exact replay creates no new revision and no audit event;
- failure while creating the replacement revision or audit must roll back closure of the previous revision.

#### 10. Readiness audit boundary

Real readiness changes use exactly:

- `booking.safety_readiness_recorded`;
- `booking.safety_readiness_revised`.

Audit entity:

`booking_safety_readiness`

Audit payload may contain only structural and controlled evidence such as:

- booking ID;
- previous/current readiness IDs;
- revision numbers;
- service category;
- controlled readiness-state transitions.

Audit must not contain unrestricted private safety/comfort notes or medical information.

#### 11. `booking_safety_signoffs` exact domain surface

`booking_safety_signoffs` is fully append-only and contains exactly these 8 domain columns:

1. `id uuid`;
2. `organization_id uuid`;
3. `booking_id uuid`;
4. `readiness_id uuid`;
5. `signed_at timestamptz`;
6. `signed_by uuid`;
7. `signoff_authority text`;
8. `lead_assignment_id uuid NULL`.

There is no update lifecycle for sign-offs.

Once inserted, a sign-off cannot be updated or deleted.

#### 12. Sign-off authority snapshot

`signoff_authority` permits exactly:

- `founder`;
- `studio_manager`;
- `lead_photographer`.

Structural rules are:

- Founder authority -> `lead_assignment_id IS NULL`;
- Studio Manager authority -> `lead_assignment_id IS NULL`;
- Lead Photographer authority -> `lead_assignment_id IS NOT NULL`.

For an ordinary Photographer, persisting the exact Lead assignment interval prevents an old sign-off from becoming currently valid merely because the same member is later assigned as Lead again after an intervening replacement.

#### 13. Sign-off tenant-safe references

Required foreign-key boundaries include:

- `(organization_id, booking_id)` -> booking;
- `(readiness_id, organization_id, booking_id)` -> exact readiness revision;
- `(signed_by, organization_id)` -> organization member;
- `(lead_assignment_id, organization_id, booking_id)` -> canonical booking-team assignment when present.

The readiness table must expose the matching composite unique identity required by the sign-off FK.

#### 14. Sign-off uniqueness

A signer may sign one readiness revision at most once.

Required uniqueness:

`UNIQUE (organization_id, readiness_id, signed_by)`

Different authorized signers may sign the same readiness revision.

#### 15. Immutable sign-off guard

Slice 5 introduces normal trigger function:

`public.lsh_booking_safety_signoff_guard()`

with empty `search_path`.

The guard enforces:

- INSERT-only lifecycle;
- UPDATE always fails;
- DELETE always fails;
- authenticated signer attribution matches the current active organization member;
- authority / Lead-assignment structural shape is valid;
- direct authenticated mutation remains denied at the table ACL boundary.

#### 16. Sign-off RPC signature

The public formal-sign-off mutation signature is frozen exactly as:

`signoff_booking_safety_readiness(p_booking_id uuid) RETURNS public.booking_safety_signoffs`

It is:

- `SECURITY DEFINER`;
- empty `search_path`;
- executable by `authenticated`;
- not executable by `anon`.

The caller does not provide:

- readiness ID;
- category;
- signer ID;
- sign-off authority;
- Lead assignment ID.

All are resolved and locked server-side.

#### 17. Formal sign-off category and readiness gate

`signoff_booking_safety_readiness(...)` requires:

- exactly one canonical journey state;
- exact Stage 9 / `pre_shoot_preparation`;
- authoritative category exactly `newborn`;
- exactly one current readiness revision;
- current readiness category matching the authoritative booking category;
- `safety_state = 'ready'`;
- `comfort_state = 'ready'`.

Formal sign-off attempts for Maternity, Sitter, Baby, Child or unsupported categories fail closed.

#### 18. Exact `safety.signoff` permission change

Slice 5 does not create a new safety permission.

The migration adds Photographer to the existing `safety.signoff` permission.

After migration the exact `safety.signoff` role-grant set must be:

- Founder;
- Studio Manager;
- Photographer.

Client Coordinator, Assistant and Stylist remain without `safety.signoff`.

The migration must assert this exact three-role grant boundary.

#### 19. Signer authority resolution

Formal sign-off requires:

- active organization membership;
- `safety.signoff`;
- booking-derived branch scope.

Server-side authority resolution follows deterministic priority:

1. Founder;
2. Studio Manager;
3. qualifying current Lead Photographer.

A Founder or Studio Manager who is also operationally a Photographer signs using administrative authority rather than creating a Lead-dependent sign-off.

#### 20. Photographer sign-off eligibility

For `lead_photographer` authority, at sign-off time the RPC must verify and sufficiently lock:

- signer organization membership is active;
- signer has an active, unrevoked Photographer role grant valid for booking scope;
- exactly one current canonical Lead Photographer assignment exists;
- that assignment's `assigned_member_id` equals the signer;
- that assignment has `ended_at IS NULL`.

The exact current assignment ID is persisted as `lead_assignment_id`.

A historical or ended Lead assignment is insufficient.

#### 21. Administrative sign-off eligibility

Founder and Studio Manager authority must also be backed at sign-off time by an active, unrevoked qualifying role grant valid for booking scope.

Possession of `safety.signoff` alone must not permit creation of an unsupported `signoff_authority` snapshot.

#### 22. Sign-off replay semantics

Authorization and current-readiness validation occur before replay resolution.

If the same signer has already signed the same current readiness revision:

- return the existing sign-off;
- create no duplicate sign-off;
- create no duplicate audit event.

Otherwise insert exactly one immutable sign-off.

#### 23. Sign-off audit boundary

A real formal sign-off creates exactly one:

`booking.safety_readiness_signed_off`

Audit entity:

`booking_safety_signoff`

Audit payload may contain structural evidence only, including:

- booking ID;
- readiness ID;
- revision number;
- signer ID;
- sign-off authority;
- Lead assignment ID when applicable.

No private medical or unrestricted safety/comfort content may enter the audit payload.

#### 24. Readiness revision invalidates old sign-offs structurally

Sign-offs bind to the exact `readiness_id`.

When readiness revision `N` is superseded by revision `N + 1`:

- sign-offs on revision `N` remain immutable historical evidence;
- those sign-offs do not sign revision `N + 1`;
- no old sign-off row is updated, deleted or marked invalid.

The current revision must receive a new qualifying Newborn sign-off.

#### 25. Lead replacement remains historical, not destructive

A Photographer sign-off records the exact Lead assignment interval used at signing time.

If that assignment later ends:

- the sign-off remains immutable history;
- Slice 5 does not rewrite or delete it;
- a later Stage 9 -> 10 gate may determine that the Lead-dependent approval is no longer currently qualifying.

Slice 5 itself does not implement that journey gate.

#### 26. RLS and table ACLs

Both Slice 5 tables must have:

- RLS enabled;
- FORCE RLS enabled;
- exactly one authenticated SELECT policy each;
- read authorization through `safety.read` plus booking-derived branch scope;
- authenticated table SELECT only;
- no authenticated INSERT, UPDATE or DELETE;
- no anon table privileges;
- trusted `service_role` privileges available subject to lifecycle guards.

Restricted safety evidence must not become readable through ordinary `booking.read` alone.

#### 27. RPC and guard ACLs

Both public mutation RPCs are:

- authenticated EXECUTE only;
- anon denied;
- `SECURITY DEFINER`;
- empty `search_path`.

Lifecycle guard helpers are not public mutation APIs and are not executable by authenticated or anon.

#### 28. Lock order

Readiness RPC lock order is:

1. booking;
2. canonical journey state;
3. current readiness revision.

Sign-off RPC lock order is:

1. booking;
2. canonical journey state;
3. current readiness revision;
4. relevant current Lead assignment when Photographer authority is required;
5. signer organization member;
6. qualifying live role grant.

The booking lock serializes readiness and sign-off mutations for that booking and prevents a stale readiness revision from being signed concurrently with a readiness revision change.

#### 29. No automatic readiness instantiation

Slice 5 does not modify `start_pre_shoot_preparation(...)`.

Starting preparation does not automatically create safety readiness evidence.

The first explicit successful `record_booking_safety_readiness(...)` call creates readiness revision `1`.

No blind or inferred readiness backfill is permitted.

#### 30. Dedicated pgTAP acceptance boundary

Slice 5 dedicated database tests use:

`supabase/tests/sprint10_safety_readiness_test.sql`

Required coverage includes at minimum:

- exact readiness table schema;
- exact sign-off table schema;
- tenant-safe FKs;
- CHECK constraints;
- uniqueness and partial-current indexes;
- exact `safety.signoff` grants;
- FORCE RLS;
- authenticated SELECT-only ACLs;
- anon denial;
- RPC SECURITY DEFINER and empty `search_path`;
- guard ACLs;
- exact Stage 9 mutation boundary;
- wrong-stage denial;
- supported category matrix;
- unsupported-category fail-closed behavior;
- first readiness revision;
- exact readiness replay;
- real readiness revision;
- failed-revision rollback atomicity;
- `safety.write` authorization;
- booking-derived branch scope;
- organization isolation;
- readiness recording without booking-team assignment;
- Newborn-only formal sign-off;
- incomplete-readiness sign-off denial;
- Founder sign-off;
- Studio Manager sign-off;
- current-Lead Photographer sign-off;
- non-Lead Photographer denial;
- ended-Lead denial;
- suspended Photographer denial;
- revoked Photographer-role denial;
- wrong-branch Photographer denial;
- exact Lead-assignment snapshot;
- multiple authorized signers;
- same-signer replay;
- readiness revision after sign-off;
- immutable historical sign-offs;
- direct authenticated DML denial;
- trusted guard enforcement;
- audit cardinality;
- restricted audit-content boundary;
- no booking-journey movement.

#### 31. Explicit Slice 5 containment

Slice 5 implementation must not include:

- Stage 9 -> 10 advancement;
- Stage 10 -> 11 advancement;
- category-specific required-team advancement rules;
- `/safety` runtime/UI release;
- `/prep` runtime/UI release;
- shoot-day safety evidence;
- medical or sensitive free-text fields;
- capacity, overlap or availability logic;
- Production migration before complete independent local validation and a separate read-only Production preflight.

The next implementation slice is limited to this frozen Slice 5 database foundation and dedicated pgTAP coverage.

### Slice 5 implementation and Production checkpoint

Slice 5 database foundation implementation is complete in commit `443c0a22fe5ba96fc84f7cfe0e23b84650d0cfe9` (`feat: add sprint 10 safety readiness foundation`).

Primary migration:

`20260814223449_sprint10_safety_readiness_foundation.sql`

Local validation evidence:

- clean local migration/reset execution: PASS;
- local DB lint: PASS with `No schema errors found`;
- dedicated Slice 5 pgTAP: 142/142 PASS;
- complete local pgTAP regression: 843/843 PASS across 12 files;
- local schema drift against migrations: none;
- committed migration contains exactly the two frozen evidence tables, two public mutation RPCs and two lifecycle guards;
- committed Slice 5 implementation boundary: exactly the migration and dedicated pgTAP file;
- committed patch hygiene: PASS;
- implementation commit pushed to `origin/architecture-rebuild`;
- local / remote branch divergence after implementation push: 0 / 0.

Validated readiness boundaries include:

- exact Stage 9 readiness mutation boundary;
- supported Newborn, Maternity, Sitter, Baby and Child applicability behavior;
- unsupported categories fail closed;
- first readiness revision, exact replay and real revision semantics;
- failed revision replacement rolls back atomically;
- `safety.write`, booking-derived branch scope and organization isolation are enforced;
- readiness recording does not require a booking-team assignment;
- readiness recording never moves the booking journey.

Validated formal sign-off boundaries include:

- formal sign-off is Newborn-only;
- current readiness must exist and be complete / ready;
- Founder administrative sign-off;
- Studio Manager administrative sign-off;
- current canonical Lead Photographer sign-off;
- non-Lead, ended-Lead, suspended, revoked-role and wrong-branch Photographer denial;
- deterministic Founder -> Studio Manager -> Lead Photographer authority priority;
- exact Lead-assignment snapshot persisted for Photographer sign-off;
- multiple qualifying signers may sign one readiness revision;
- same-signer replay is idempotent;
- readiness revisions do not rewrite historical sign-offs;
- old sign-offs do not sign a later readiness revision;
- authenticated direct DML is denied;
- trusted direct mutation remains constrained by lifecycle guards;
- formal sign-off audit cardinality and restricted-content boundaries are enforced;
- sign-off operations never move the booking journey.

Validated restricted-read boundaries include:

- both safety evidence tables use FORCE RLS;
- same-branch `safety.read` access succeeds;
- wrong-branch access is hidden;
- branch-scoped readers cannot read branchless safety evidence;
- ordinary `booking.read` without `safety.read` exposes no readiness or sign-off evidence;
- cross-organization reads are hidden;
- organization-wide authorized readers retain permitted visibility.

### Slice 5 Production checkpoint

Slice 5 database migration `20260814223449_sprint10_safety_readiness_foundation.sql` has been applied to Production.

Production rollout evidence:

- pre-rollout Local / Remote migration history aligned through `20260814214746`;
- exactly one migration was pending before rollout: `20260814223449_sprint10_safety_readiness_foundation.sql`;
- pre-rollout linked DB lint: PASS with `No schema errors found`;
- pre-rollout migration dry run identified exactly the approved Slice 5 migration;
- Production migration push: PASS;
- post-rollout Local / Remote migration history aligned through `20260814223449`;
- post-rollout linked DB lint: PASS with `No schema errors found`;
- post-rollout migration dry run reports the remote database up to date.

Production collision / no-backfill evidence:

- `public.booking_team_assignments` existed as the required Slice 4 dependency before rollout;
- no pre-existing `public.booking_safety_readiness` relation was present before rollout;
- no pre-existing `public.booking_safety_signoffs` relation was present before rollout;
- no pre-existing `record_booking_safety_readiness(uuid,text,text)` RPC was present before rollout;
- no pre-existing `signoff_booking_safety_readiness(uuid)` RPC was present before rollout;
- pre-rollout `safety.signoff` grants were exactly Founder and Studio Manager;
- no readiness or formal sign-off evidence was inferred or blindly backfilled.

Production static security / invariant evidence:

- `public.booking_safety_readiness` has exactly the frozen 11-column domain surface;
- `public.booking_safety_signoffs` has exactly the frozen 8-column domain surface;
- RLS enabled on both tables: PASS;
- FORCE RLS enabled on both tables: PASS;
- exactly one authenticated SELECT policy exists on each evidence table;
- restricted reads require `safety.read` plus booking-derived branch scope;
- authenticated table access is SELECT-only;
- anon table access is denied;
- trusted `service_role` privileges remain subject to lifecycle guards;
- `record_booking_safety_readiness(uuid,text,text)` is `SECURITY DEFINER`, has empty `search_path` and authenticated-only EXECUTE;
- `signoff_booking_safety_readiness(uuid)` is `SECURITY DEFINER`, has empty `search_path` and authenticated-only EXECUTE;
- both lifecycle guards have empty `search_path` and are not authenticated/anon public mutation APIs;
- post-migration `safety.signoff` grants are exactly Founder, Studio Manager and Photographer;
- Photographer sign-off retains server-side current-Lead and live-role eligibility enforcement;
- no booking-journey mutation is introduced by either Slice 5 RPC.

Production data state at static validation:

- `booking_safety_readiness`: zero rows;
- `booking_safety_signoffs`: zero rows.

No artificial Production readiness or formal-sign-off mutation was exercised because both canonical Slice 5 evidence tables contained zero rows at the Production static-validation checkpoint.

Slice 5 Production remains contained. This checkpoint does not release or implement:

- Stage 9 -> 10 advancement;
- Stage 10 -> 11 advancement;
- category-specific required-team Stage 9 -> 10 rules;
- `/safety` runtime/UI release;
- `/prep` runtime/UI release;
- shoot-day safety evidence;
- medical or unrestricted sensitive free text;
- capacity, overlap or availability logic;
- Sprint 10 application release.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

# Cross-Sprint Architecture Rules

These rules remain binding unless explicitly superseded by a higher-authority project decision:

1. Browser/server function -> authenticated/user-scoped Supabase client -> RLS / permission-aware RPC.
2. Service-role bypass is restricted to trusted administrative operations; never normal domain paths.
3. Family memories are private by default.
4. Privacy preference, image-use consent, contact permission and marketing consent are distinct concepts.
5. AI recommendations must remain explainable, deterministic where required and subject to human review when confidence or eligibility is insufficient.
6. Historical commercial facts must be snapshotted/versioned; later catalogue changes must not rewrite historical quotations or bookings.
7. No automatic upsell objective.
8. No invented pricing for categories without an approved catalogue source.
9. Restricted family/story/safety information must not leak into broad CRM surfaces.
10. Production approval requires explicit validation evidence, not merely a successful build.

---

# Known Cross-Sprint Debt / Future Work

The following items remain known cross-sprint debt. They are **not blockers to the accepted Sprint 9 Production release**, but they remain subject to future bounded remediation:

- legacy mock/Zustand implementations remain in later-sprint domains; affected routes remain temporarily contained and are not authoritative canonical booking, journey, KPI or financial truth;
- repository-wide TypeScript debt predates the rebuilt sprint boundaries; the Sprint 9 authoritative post-build `npx tsc -p tsconfig.json` gate is clean, and TanStack route generation must precede the final typecheck;
- repository-wide ESLint baseline debt predates Sprint 7 and requires a separate cleanup initiative;
- older `.inputValidator()` usages are deprecated and should be modernized in a bounded refactor;
- Lead-to-Family conversion does not yet transfer every family-contact / memory-goal field automatically;
- Supabase Security Advisor warnings around intentional authenticated/public `SECURITY DEFINER` RPC patterns must continue to be evaluated function-by-function rather than dismissed wholesale.

---

# Register Maintenance Rules

For every future sprint:

1. Update this register **before implementation** with the proposed objective and scope.
2. Mark the sprint `IN PROGRESS` only after preflight/scope freeze.
3. Record every primary migration filename.
4. Record the final release commit SHA.
5. Record Production migration/deployment state.
6. Record local and Production validation evidence.
7. Record accepted founder/policy decisions that affect deterministic behavior.
8. Record known debt separately from release blockers.
9. Do not rewrite historical sprint facts to make the history look cleaner.
10. If a retrospective title is used, label it explicitly as retrospective.

---

# Current Release Marker

As of 2026-08-15:

- **Latest closed Production sprint:** Sprint 9 — Advance Payment, Booking Confirmation & KPI Foundation
- **Sprint 9 Production application release SHA:** `633c318baf0a1985c17d364f3ab043f442b69332`
- **Sprint 9 Production closeout commit:** `eb784f4bfe7606e13d20e36ad6bb4e9338ef81db`
- **Sprint 9 application implementation head:** `89956ae`
- **Latest Production DB migration:** `20260814223449_sprint10_safety_readiness_foundation.sql` (Sprint 10 Slice 5 database foundation; Sprint 10 not released)
- **Sprint 9 Production state:** Released / Closed
- **Current sprint:** Sprint 10 — Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation
- **Sprint 10 state:** Scope frozen / implementation in progress / not released
- **Sprint 10 journey boundary:** extend the authoritative Stage 7 -> 8 confirmation gate with proposed-shoot-plan reservation, then implement dedicated Stage 8 -> 9 and Stage 9 -> 10 transitions; no Stage 10 -> 11
- **Sprint 10 Newborn safety rule:** formal readiness sign-off is required before Stage 10
- **Sprint 10 Photographer sign-off rule:** an ordinary Photographer may sign Newborn readiness only when assigned as that booking's Lead Photographer; Founder and Studio Manager retain administrative sign-off authority
- **Sprint 10 containment:** `/prep` and `/safety` remain unavailable until canonical runtime validation passes
- **Sprint 9 advance rule:** 50% of final accepted quotation value, whole-INR, half-rupee rounded upward
- **Sprint 9 local regression:** 361/361 pgTAP PASS; DB lint PASS; schema drift none; build/typecheck/targeted lint/format PASS
- **Sprint 9 Production database gates:** pre-migration readiness PASS; migration rollout PASS; post-migration static security/invariant gate PASS
- **Sprint 9 Production authenticated KPI smoke:** PASS
- **Sprint 9 Production authenticated browser smoke:** PASS
- **Legacy `/kpi` and `/reports` containment:** preserved
- **Sprint 10 Slice 2:** Production DB + static security validated — Pre-Shoot Preparation Instance + Controlled Stage 8 -> 9 Gate
- **Slice 2 migration:** `20260814172955_sprint10_pre_shoot_preparation_foundation.sql`
- **Slice 2 implementation commit:** `69aa978`; pushed in the branch stack through `195fc2b`
- **Slice 2 local validation:** clean DB reset PASS; DB lint PASS; dedicated pgTAP 71/71 PASS; complete regression 543/543 PASS across 9 files; schema drift none
- **Slice 2 preparation permission grants:** `prep.read` and `prep.write` -> Founder, Studio Manager, Client Coordinator only
- **Slice 2 stage authorization:** `start_pre_shoot_preparation(...)` requires both `prep.write` and `booking.stage.advance`
- **Slice 2 Production database state:** migration applied; Local = Remote through `20260814172955`; linked lint PASS; post-rollout dry run reports remote database up to date
- **Slice 2 Production static security:** forced RLS PASS; authenticated SELECT-only table ACL PASS; anon denial PASS; exact preparation permission grants PASS; immutable guard boundary PASS; RPC SECURITY DEFINER / empty search_path / authenticated-only execution PASS
- **Slice 2 Production runtime mutation:** intentionally not exercised against a real booking; `booking_preparations` contained zero rows at static validation time
- **Sprint 10 Slice 3 checklist:** founder-approved on 2026-08-15 — canonical common, Maternity, Newborn and Sitter preparation taxonomy with required/optional classifications frozen
- **Sprint 10 Slice 3 technical design:** frozen on 2026-08-15 — Preparation Checklist Foundation
- **Slice 3 implementation:** complete in commit `691b708` (`feat: add sprint 10 preparation checklist foundation`); pushed in the branch stack through checkpoint commit `63ef223`
- **Slice 3 migration:** `20260814191047_sprint10_preparation_checklist_foundation.sql`; applied to Production
- **Slice 3 data boundary:** `booking_preparation_items` plus taxonomy-v1 instantiation inside `start_pre_shoot_preparation(uuid)`
- **Slice 3 mutation boundary:** `update_pre_shoot_preparation_item(uuid, boolean)`; `prep.write` required; exact Stage 9 only; no journey movement
- **Slice 3 taxonomy boundary:** Maternity 11 items / Newborn 11 items / Sitter 12 items; exactly 8 required items per supported category; unsupported categories fail closed
- **Slice 3 authorization:** existing Founder, Studio Manager and Client Coordinator `prep.read` / `prep.write` grants remain unchanged
- **Slice 3 local validation:** fresh DB reset PASS; DB lint PASS; dedicated pgTAP 83/83 PASS; complete regression 626/626 PASS across 10 files; schema drift none
- **Slice 3 integrity validation:** atomic first start PASS; exact Stage 9 replay/idempotency PASS; malformed replay fail-closed PASS; item set/clear/idempotency PASS; direct-write denial PASS; organization/branch isolation PASS; forced-instantiation rollback PASS
- **Slice 3 containment:** no team assignment, safety readiness/sign-off, Stage 9 -> 10, Stage 10 -> 11, or `/prep` runtime/UI release
- **Slice 3 Production safeguard:** no blind backfill; pre-rollout `booking_preparations` anomaly check is mandatory and any unmatched existing preparation row places rollout on HOLD
- **Slice 3 Production state:** migration applied; Local = Remote through `20260814191047`; linked lint PASS; post-rollout dry run reports remote database up to date
- **Slice 3 Production static security:** exact 16-column table surface PASS; forced RLS PASS; authenticated SELECT-only table ACL PASS; anon denial PASS; exact preparation permission grants PASS; guard-trigger/integrity boundary PASS; RPC SECURITY DEFINER / empty search_path / authenticated-only execution PASS
- **Slice 3 Production runtime mutation:** intentionally not exercised because `booking_preparations` and `booking_preparation_items` both contained zero rows at static validation time
- **Slice 3 Vercel deployment:** `dpl_Fv9XHo9N7Yo1YWRyxHaitsSSUiGi` READY at exact branch checkpoint SHA `63ef223263b29bafb281d02ec3efaf7b6a33c463`
- **Slice 4:** Booking Team Assignment Foundation — founder decisions approved; technical design frozen; database foundation implemented, fully validated locally and pushed
- **Slice 4 implementation commit:** `b579635e1bdd23264c5c9f400892b837761b7abd`
- **Slice 4 migration:** `20260814214746_sprint10_booking_team_assignment_foundation.sql`; applied to Production
- **Slice 4 technical boundary:** `booking_team_assignments` lifecycle evidence + controlled `assign_booking_team_member(uuid,text,uuid,boolean,text)` RPC + dedicated `booking.team.assign` permission; no journey movement
- **Slice 4 local validation:** clean DB reset PASS; DB lint PASS with no schema errors; dedicated pgTAP 75/75 PASS; complete regression 701/701 PASS across 11 files; schema drift none
- **Slice 4 Production database state:** migration applied; Local = Remote through `20260814214746`; linked lint PASS; post-rollout dry run reports remote database up to date
- **Slice 4 Production static security:** exact 10-column table surface PASS; forced RLS PASS; authenticated SELECT-only table ACL PASS; anon denial PASS; exact `booking.team.assign` grants PASS; lifecycle/uniqueness/integrity boundary PASS; RPC SECURITY DEFINER / empty search_path / authenticated-only execution PASS
- **Slice 4 Production runtime mutation:** intentionally not exercised because `booking_team_assignments` contained zero rows at static validation time
- **Slice 4 containment:** no safety-readiness/sign-off, `safety.signoff` grant change, Stage 9 -> 10, Stage 10 -> 11, category-specific required-team gate, capacity/availability logic or `/bookings`/`/prep`/`/safety` UI release
- **Sprint 10 Slice 5:** Restricted Safety/Comfort Readiness + Newborn Formal Sign-off Foundation — founder decisions approved; technical design frozen; database foundation implemented, fully validated locally, pushed and applied to Production
- **Slice 5 implementation commit:** `443c0a22fe5ba96fc84f7cfe0e23b84650d0cfe9` (`feat: add sprint 10 safety readiness foundation`)
- **Slice 5 migration:** `20260814223449_sprint10_safety_readiness_foundation.sql`; applied to Production
- **Slice 5 readiness table:** `booking_safety_readiness` — exactly 11 domain columns; controlled revision lifecycle; one current revision per booking
- **Slice 5 sign-off table:** `booking_safety_signoffs` — exactly 8 domain columns; immutable append-only formal Newborn sign-off evidence
- **Slice 5 controlled states:** `pending`, `ready`, `not_ready`, `not_applicable`; no unrestricted safety/medical free text
- **Slice 5 category rule:** Newborn safety+comfort; Maternity comfort with safety not applicable; Sitter/Baby/Child safety+comfort; unsupported categories fail closed
- **Slice 5 readiness RPC:** `record_booking_safety_readiness(uuid,text,text)`; `safety.write`; exact Stage 9; no booking-team requirement; no journey movement
- **Slice 5 sign-off RPC:** `signoff_booking_safety_readiness(uuid)`; Newborn-only; current readiness must be complete and ready
- **Slice 5 sign-off grants:** `safety.signoff` exactly Founder, Studio Manager and Photographer; Photographer use requires current canonical Lead assignment and live Photographer eligibility
- **Slice 5 sign-off snapshot:** Lead Photographer sign-offs persist the exact `lead_assignment_id`; Founder/Studio Manager sign-offs remain administrative
- **Slice 5 history rule:** readiness revisions preserve history; sign-offs bind to exact readiness revisions and remain immutable; exact replays create no duplicate evidence or audit
- **Slice 5 security:** FORCE RLS; restricted reads require `safety.read` plus booking-derived branch scope; authenticated table access SELECT-only; mutation through authenticated SECURITY DEFINER RPCs only
- **Slice 5 local validation:** local DB lint PASS; dedicated pgTAP 142/142 PASS; complete regression 843/843 PASS across 12 files; schema drift none
- **Slice 5 Production database state:** migration applied; Local = Remote through `20260814223449`; linked lint PASS; post-rollout dry run reports remote database up to date
- **Slice 5 Production static security:** exact 11/8-column table surfaces PASS; forced RLS PASS; authenticated SELECT-only ACL PASS; anon denial PASS; exact `safety.signoff` grants PASS; RPC SECURITY DEFINER / empty search_path / authenticated-only execution PASS; lifecycle-guard boundary PASS
- **Slice 5 Production runtime mutation:** intentionally not exercised because `booking_safety_readiness` and `booking_safety_signoffs` both contained zero rows at static validation time
- **Slice 5 implementation test boundary:** dedicated `supabase/tests/sprint10_safety_readiness_test.sql`
- **Slice 5 containment:** no Stage 9 -> 10, Stage 10 -> 11, `/safety` or `/prep` runtime/UI release, shoot-day safety evidence, sensitive free text, capacity/availability logic or Sprint 10 release
- **Next action:** separately freeze and validate the next Sprint 10 boundary before any Stage 9 -> 10 implementation; Slice 5 does not authorize journey advancement or Sprint 10 release.

### Slice 6 founder decision checkpoint — Stage 9 -> 10 Journey Advancement Gate

Founder decisions approved on 2026-08-16.

Slice 6 is the dedicated Stage 9 -> 10 gate that turns a booking in `Pre-Shoot Preparation` into `Shoot Scheduled` only after all required Sprint 10 operational evidence is complete.

This checkpoint freezes founder-level business behavior only. Exact SQL shape, canonical freelancer representation, quotation-line detection, role-validation helpers, locking implementation, return shape, audit event name and pgTAP structure remain subject to the separate Slice 6 technical design freeze.

#### 1. Gate-only boundary

Stage 9 -> 10 requires all of the following:

- current journey stage exactly `Pre-Shoot Preparation`;
- current authoritative shoot schedule reserved;
- every applicable required preparation item satisfied;
- required booking-team composition present for the accepted booking scope;
- applicable safety/comfort readiness complete;
- qualifying formal Newborn sign-off when the booking is Newborn;
- permitted actor holds the existing `booking.stage.advance` authority for the booking scope.

Slice 6 does not authorize Stage 10 -> 11, shoot completion, UI/runtime release, capacity/availability logic or unrelated workflow changes.

#### 2. Reserved schedule requirement

The current authoritative shoot-schedule tip must be in `reserved` state.

Cancelled, superseded, missing or otherwise non-reserved schedule evidence does not satisfy Stage 9 -> 10.

No additional capacity, overlap, future-time or external-calendar checks are introduced by this gate.

#### 3. Preparation completeness

Every applicable preparation item where `is_required = true` must currently be satisfied.

Optional preparation items remain non-blocking.

Missing, malformed or unsupported preparation structure fails closed.

#### 4. Mandatory photography/styling composition for every service category

Every supported service category requires:

- one current Lead Photographer;
- one current Stylist.

These two roles are mandatory for Stage 9 -> 10 for all supported booking categories.

Additional photography, styling or general assistants may be assigned when operationally needed but are optional and do not independently block Stage 9 -> 10.

#### 5. Video / Reels assignment rule

When the accepted quotation includes a client-facing Reels or Video deliverable:

- one Lead Videographer is required before Stage 9 -> 10;
- Supporting Videographer assignment is optional.

When Video/Reels is not included in the client quotation, Lead and/or Supporting Videographers may still be assigned optionally for studio promotional, behind-the-scenes or marketing coverage.

Promotional-only video coverage does not make videographer assignment mandatory for Stage 9 -> 10.

#### 6. Internal and freelance creatives

A booking may assign internal organization creatives or approved freelancers/contractors, including freelance photographers and videographers.

A freelancer does not need an OS account or organization-membership record merely to be assigned operationally to a booking.

Freelancer assignment does not grant application access, permissions, branch scope or organization roles.

If a freelancer later requires OS access, that access must be onboarded separately through the normal organization-member and permission model.

The later technical design must represent freelancer identity and booking-specific approval without falsely treating every freelancer as an internal organization member.

#### 7. Required-assignment operational validity

A required assignment must be operationally valid at Stage 9 -> 10.

For an internal assignee, the later gate must confirm the assignee remains active and retains the live, unrevoked qualifying operational role needed for that assignment.

For a freelancer/contractor, the later gate must confirm the booking-specific freelance assignment remains current and approved.

Historical, ended, superseded or otherwise inactive assignments do not satisfy the gate.

#### 8. Supported-category and quotation scope

The accepted booking/quotation remains the authoritative source for determining the service category and whether a client Video/Reels deliverable has actually been booked.

Unsupported, unmapped or structurally ambiguous categories fail closed.

Video/Reels must not be inferred merely because a videographer happens to be assigned for promotional coverage.

#### 9. Safety / comfort readiness

Readiness remains category-specific:

- Newborn: safety `ready` and comfort `ready`;
- Maternity: safety `not_applicable` and comfort `ready`;
- Sitter / Baby / Child: safety `ready` and comfort `ready`.

Missing, pending, not-ready, malformed or category-mismatched current readiness evidence blocks Stage 9 -> 10.

#### 10. Newborn formal sign-off

Newborn requires at least one qualifying sign-off bound to the current readiness revision.

A sign-off on a superseded readiness revision never satisfies the current gate.

Photographer and administrative sign-offs have different current-qualification rules.

#### 11. Photographer sign-off current qualification

A Newborn sign-off made by an ordinary Photographer qualifies at Stage 9 -> 10 only while that signer:

- remains the booking's current Lead Photographer;
- remains operationally eligible as a Photographer for that booking scope.

If that Photographer is replaced as Lead before Stage 9 -> 10, the historical sign-off remains immutable evidence but no longer satisfies the advancement gate.

The new current Lead Photographer, Founder or Studio Manager must then provide a qualifying sign-off on the current readiness revision.

#### 12. Founder / Studio Manager administrative sign-off persistence

A Founder or Studio Manager sign-off that was validly authorized when created remains qualifying historical approval for that readiness revision.

It is not invalidated merely because:

- the Lead Photographer later changes;
- the Founder or Studio Manager later loses that administrative role;
- the signer later leaves or loses active organization membership.

The historical sign-off remains immutable and continues to satisfy the current readiness revision unless that readiness revision itself is superseded.

This administrative persistence rule does not apply to ordinary Photographer sign-offs, whose current Lead Photographer qualification must be revalidated at Stage 9 -> 10.

#### 13. Advancement permission

The actor invoking Stage 9 -> 10 requires the existing `booking.stage.advance` permission and booking-derived branch scope.

The actor does not additionally need `prep.write`, `safety.write`, `safety.signoff` or `booking.team.assign` merely to evaluate and consume evidence created under those permissions.

No new Stage 9 -> 10 permission key is introduced.

#### 14. Transition-only mutation

The public Stage 9 -> 10 operation remains conceptually `mark_booking_shoot_scheduled(uuid)`.

It may:

- evaluate the frozen gate;
- append exactly one Stage 9 -> 10 transition;
- update the authoritative current journey state;
- write structural audit evidence.

It must not create, modify, repair or backfill preparation, schedule, team, freelancer, readiness or sign-off evidence as a side effect.

#### 15. Replay semantics

An authorized replay against the exact already-reached `Shoot Scheduled` state is idempotent only when the canonical Stage 9 -> 10 transition already exists.

Replay creates no duplicate stage transition, journey-version increment or audit event.

Any other journey stage fails closed.

#### 16. Structural audit boundary

Audit evidence may record structural transition outcomes only.

It must not expose:

- preparation-item content;
- detailed team/freelancer personal information;
- restricted safety/comfort content;
- medical or unrestricted sensitive free text.

#### 17. Slice 6 containment

This founder checkpoint does not authorize:

- Slice 6 SQL implementation;
- modification of existing Slice 4 team-assignment schema;
- creation of freelancer or videographer schema;
- execution of Stage 9 -> 10;
- Production database migration;
- Stage 10 -> 11;
- `/bookings`, `/prep` or `/safety` runtime/UI release;
- capacity/availability/calendar-provider work;
- Sprint 10 release.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 6A technical design freeze — Extended Creative Assignment Foundation

Technical design frozen on 2026-08-16.

Slice 6A is a prerequisite foundation required by the corrected Slice 6 Stage 9 -> 10 founder decisions.

It extends the existing Slice 4 booking-team model only as far as necessary to represent:

- internal Videographers;
- Lead and Supporting Videographer booking assignments;
- booking-scoped freelance / external creative assignments without requiring an OS account;
- structured commercial evidence that an accepted quotation includes a client Video/Reels deliverable.

Slice 6A does not implement Stage 9 -> 10 itself.

#### 1. Existing Slice 4 assignment history remains canonical

`public.booking_team_assignments` remains the single canonical booking-scoped assignment lifecycle table.

Slice 6A must not create a second parallel team-assignment truth.

Existing assignment history remains valid and must not be rewritten or backfilled destructively.

#### 2. Expanded assignment-role vocabulary

`booking_team_assignments.assignment_role` expands from:

- `lead_photographer`;
- `assistant`;
- `stylist`;

to exactly:

- `lead_photographer`;
- `assistant`;
- `stylist`;
- `lead_videographer`;
- `supporting_videographer`.

Existing role meanings remain unchanged.

#### 3. Lead-role cardinality

Current assignment cardinality is:

- at most one current `lead_photographer` per booking;
- at most one current `lead_videographer` per booking;
- multiple current `assistant` assignments permitted;
- multiple current `stylist` assignments permitted;
- multiple current `supporting_videographer` assignments permitted.

The existing partial singular-current-Lead-Photographer invariant remains.

A parallel singular-current-Lead-Videographer invariant is added.

#### 4. Internal and external assignment subjects

An assignment may represent exactly one of:

- an internal `organization_member`; or
- an external/freelance creative.

`assigned_member_id` therefore becomes nullable.

Slice 6A adds:

- `assigned_external_creative_id uuid`.

Exactly one assignment subject must be present:

- internal assignment -> `assigned_member_id IS NOT NULL` and `assigned_external_creative_id IS NULL`;
- external assignment -> `assigned_member_id IS NULL` and `assigned_external_creative_id IS NOT NULL`.

An assignment may never contain both subject forms and may never contain neither.

Current duplicate-subject protection must operate independently for internal and external subjects so exact assignment replay remains idempotent while distinct freelancers with identical display names remain representable.

#### 5. External creative identity boundary

Slice 6A introduces a minimal organization-scoped identity registry:

`public.external_creatives`

Its purpose is only to provide stable operational identity for a freelancer/contractor who may be assigned to bookings without receiving an OS account.

Minimum canonical fields:

- `id uuid`;
- `organization_id uuid`;
- `display_name text`;
- `created_at timestamptz`;
- `created_by uuid`.

The identity row is immutable and undeletable after creation.

`display_name` must be nonblank and bounded to the normal practical person-display-name limit.

Two external creatives may legitimately have the same display name. Identity is determined by UUID, never name matching.

The table does not create or imply:

- an auth user;
- an organization membership;
- a role grant;
- application permissions;
- branch permissions;
- contact CRM;
- payroll/employment status.

The current booking assignment remains the booking-specific operational approval.

A minimal controlled creation RPC is permitted so an authorized booking-team manager can register an external creative before assignment.

This registry is not a broad freelancer CRM or staffing directory.

#### 6. Assignment subject immutability

For every assignment row, the following original evidence remains immutable after insert:

- organization;
- booking;
- assignment role;
- internal member identifier when present;
- external creative identifier when present;
- original assignment timestamp;
- assigning actor.

An active assignment may only transition to the existing complete ended lifecycle state.

Closed historical assignment evidence remains immutable and undeletable.

Changing subject identity or assignment role requires ending the old assignment and creating new assignment evidence.

#### 7. Internal-member assignment RPC compatibility

Existing:

`assign_booking_team_member(uuid,text,uuid,boolean,text)`

remains the canonical internal-member assignment RPC.

Its accepted assignment roles expand to all five Slice 6A roles.

Operational-role mapping becomes:

- `lead_photographer` -> `photographer`;
- `assistant` -> `assistant`;
- `stylist` -> `stylist`;
- `lead_videographer` -> `videographer`;
- `supporting_videographer` -> `videographer`.

Existing authorization, branch scope, Stage 8/9/10 mutation boundary, lifecycle, replay and audit behavior remain.

Lead Videographer replacement mirrors Lead Photographer replacement:

- replacement requires a nonblank reason;
- current Lead Videographer closes atomically;
- replacement assignment inserts atomically;
- failure rolls the complete replacement back.

#### 8. External/freelance identity and assignment RPCs

Slice 6A adds:

`create_external_creative(uuid,text)`

with parameters conceptually:

- booking id, used to resolve organization and authorization scope;
- external creative display name.

It returns `external_creatives`.

The actor must:

- be authenticated;
- resolve to a current active organization member;
- hold `booking.team.assign`;
- have booking-derived branch scope.

Creation grants the external creative no OS access or permissions.

Slice 6A also adds:

`assign_booking_external_creative(uuid,text,uuid,boolean,text)`

with parameters conceptually:

- booking id;
- assignment role;
- external creative id;
- assigned/unassigned state;
- optional change reason.

It returns `booking_team_assignments`.

The external creative must belong to the booking organization.

Assignment uses stable external creative UUID identity, never display-name matching.

The existing Stage 8/9/10 assignment boundary, authorization, lifecycle and replay semantics remain.

Exact current assignment replay is idempotent.

Unassignment requires the existing complete ending evidence.

Lead Photographer and Lead Videographer replacement semantics apply across internal and external subjects.

#### 9. External Lead Photographer and Newborn sign-off

A freelance/external Lead Photographer may satisfy the Stage 9 -> 10 staffing requirement when the booking assignment is current.

A freelance Lead Photographer without an OS account cannot execute `signoff_booking_safety_readiness(...)`.

That external Lead Photographer therefore cannot create a database Photographer Newborn sign-off merely from the external assignment.

For such a Newborn booking, qualifying formal sign-off must be supplied by:

- Founder; or
- Studio Manager;

unless the freelancer is separately onboarded as an organization member with valid Photographer eligibility and subsequently assigned through the internal-member path.

#### 10. Internal Videographer organization role

Slice 6A adds the canonical organization role:

`videographer`

The role is eligible for both:

- `lead_videographer`;
- `supporting_videographer`.

Initial permissions are exactly:

- `org.read`;
- `booking.read`.

Videographer does not receive merely by virtue of that role:

- `safety.read`;
- `safety.write`;
- `safety.signoff`;
- `booking.team.assign`;
- `booking.stage.advance`;
- finance permissions;
- organization administration permissions.

A person performing both photography and videography may hold both `photographer` and `videographer` role grants.

After Slice 6A, the canonical access-control catalogue becomes 12 roles and 141 role-permission mappings.

#### 11. Current operational eligibility remains a later gate concern

Assignment-time validation is not permanent proof of later eligibility.

At Stage 9 -> 10:

For an internal required assignment:

- member must still be active;
- qualifying role grant must still be live and unrevoked for the booking scope;
- assignment itself must still be current.

For an external required assignment:

- assignment itself must still be current;
- `assigned_external_creative_id` must still resolve to the immutable external identity in the same organization.

The external identity row itself grants no operational permission; the current booking assignment is the booking-specific approval.

Ending a freelancer assignment withdraws that booking-specific operational approval.

#### 12. Structured Video/Reels commercial requirement

Runtime Stage 9 -> 10 logic must never determine a client Video/Reels obligation using:

- package-inclusion label text;
- quotation item name;
- quotation description;
- substring matching for `video`, `reel` or similar words;
- presence of a Videographer assignment.

The existing `commercial_package_inclusions.inclusion_key` values are ordinal keys such as `item_01` and are not semantically sufficient for this purpose.

Slice 6A therefore introduces structured commercial operational-requirement evidence tied to exact commercial catalogue versions.

#### 13. Commercial operational-requirement table

Slice 6A introduces:

`public.commercial_operational_requirements`

Each row binds exactly one immutable commercial source version to one controlled operational requirement.

The source is exactly one of:

- `commercial_package_versions`;
- `commercial_addon_versions`.

The initial controlled requirement key is:

`lead_videographer`

The table must enforce:

- organization-scoped foreign keys;
- exactly one package-version or add-on-version source;
- nonblank controlled requirement key;
- uniqueness of requirement per exact source version;
- append-only/immutable requirement identity;
- no unrestricted free-text operational condition.

Stage 9 -> 10 will later query this structured table through the accepted quotation's snapshotted `source_package_version_id` and `source_addon_version_id`.

#### 14. Initial Lead Videographer commercial mappings

Slice 6A seeds `lead_videographer` requirement evidence for the existing version-1 package versions whose founder-approved inclusions contain client Video/Reels deliverables:

- `maternity_diamond`;
- `maternity_emerald`;
- `newborn_emerald`;
- `sitter_diamond`;
- `sitter_emerald`.

Slice 6A also seeds the same requirement for the existing version-1 add-on:

- `cinematic_reel`.

The migration resolves these rows structurally through package/add-on keys plus exact version number when inserting the new requirement evidence.

Runtime journey logic does not use those package names as a hard-coded gate; it consumes the resulting version-bound requirement rows.

Future commercial versions must explicitly receive their own operational-requirement evidence when applicable.

#### 15. Quotation interpretation

The accepted quotation remains immutable and authoritative.

Lead Videographer becomes mandatory when any accepted quotation line references a package or add-on version carrying the structured `lead_videographer` requirement.

A Videographer assigned only for promotional, BTS or studio-marketing coverage does not create a client commercial requirement.

Free-form custom quotation text does not create a Video/Reels requirement in Slice 6A.

Video/Reels sold to a client within the current supported catalogue must use structured package or canonical `cinematic_reel` add-on evidence.

Slice 6A introduces no free-text inference fallback.

#### 16. RLS and ACL boundary

`booking_team_assignments` retains its existing forced-RLS and authenticated SELECT-only table boundary.

Direct authenticated INSERT/UPDATE/DELETE remains prohibited.

Mutation remains RPC-only.

`external_creatives` is operational identity data.

It must use forced RLS and expose no direct authenticated mutation path.

Creation occurs only through the controlled RPC authorized through `booking.team.assign` plus booking-derived branch scope.

No external creative receives application permissions merely because an identity row exists.

`commercial_operational_requirements` is structural catalogue evidence.

Normal authenticated clients receive no direct mutation authority over it.

#### 17. Audit boundary

Assignment audit remains structural.

For external assignments, broad audit payloads may include:

- assignment id;
- assignment role;
- internal/external subject type;
- external creative id when applicable;
- current/ended state;
- booking id.

Broad audit payloads must not copy external creative display names or other freelancer personal information unnecessarily.

External-identity creation audit may identify the external creative id structurally but must not propagate display names into unrelated broad audit surfaces.

Commercial operational-requirement seed evidence requires no sensitive audit payload.

#### 18. Existing Slice 4 test evolution

The existing Slice 4 test file currently freezes:

- exactly 10 `booking_team_assignments` columns;
- exactly three assignment roles;
- mandatory `assigned_member_id`.

Those assertions become intentionally outdated after the approved Slice 6A schema extension.

The canonical assignment table adds `assigned_external_creative_id`, making the subject model internal-or-external rather than internal-only.

Slice 6A implementation must update the existing booking-team test expectations while preserving every still-valid Slice 4 lifecycle, authorization, branch-isolation, replay and history invariant.

Historical Git evidence remains the record of the original Slice 4 schema.

Tests must validate the current canonical schema rather than obsolete column-count assertions.

#### 19. Dedicated Slice 6A pgTAP boundary

Slice 6A adds dedicated coverage for at least:

- five-role assignment vocabulary;
- singular current Lead Photographer across internal/external subjects;
- singular current Lead Videographer across internal/external subjects;
- multiple Supporting Videographers;
- internal/external subject XOR;
- stable external creative UUID identity;
- duplicate external display names permitted;
- external identity immutability;
- controlled external identity creation authorization;
- internal Videographer role eligibility;
- internal Lead/Supporting Videographer assignment;
- external Lead Photographer assignment;
- external Lead Videographer assignment;
- external Supporting Videographer assignment;
- external assignment/unassignment/replay;
- external subject receives no organization membership or application permission;
- exact Videographer permission grants;
- commercial operational-requirement table integrity;
- exact initial package-version requirement seed;
- exact `cinematic_reel` add-on requirement seed;
- no free-text Video/Reels inference;
- direct-write denial;
- organization/branch isolation;
- lifecycle guard integrity.

#### 20. Slice 6A containment

Slice 6A does not authorize:

- Stage 9 -> 10 implementation;
- Stage 10 -> 11 implementation;
- Newborn sign-off by unauthenticated freelancers;
- application access for freelancers;
- generic freelancer account creation;
- a broad freelancer CRM/directory;
- free-text Video/Reels detection;
- shoot-day runtime/UI;
- capacity/availability/calendar-provider logic;
- Production migration;
- Sprint 10 release.

After Slice 6A technical implementation and validation, the dedicated Slice 6 Stage 9 -> 10 technical design must consume this extended canonical evidence.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.
