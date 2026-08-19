# Little Shots by Hema OS — Sprint Master Register

**Project:** LSH - Active / Memory Keeper OS
**Repository:** `Little-Shots-by-Hema-OS/memory-keeper-os`
**Primary release branch:** `architecture-rebuild`
**Register version:** 1.0
**Last updated:** 2026-08-17

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

At the Slice 6A application boundary, the canonical access-control catalogue moves from the current 11 roles / 228 role-permission mappings to 12 roles / 230 role-permission mappings by adding only the `videographer` role with `org.read` and `booking.read`.

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

### Slice 6A implementation checkpoint — Extended Creative Assignment Foundation

Slice 6A database-foundation implementation completed, fully validated and pushed to `origin/architecture-rebuild` on 2026-08-16.

Implementation evidence:

- migration: `20260816113000_sprint10_extended_creative_assignment_foundation.sql`;
- dedicated pgTAP: `supabase/tests/sprint10_extended_creative_assignments_test.sql`;
- existing canonical booking-team pgTAP evolved in `supabase/tests/sprint10_booking_team_assignments_test.sql`;
- implementation commit: `e45662c7a59eaef865b80b0738cde39386271105` (`feat: implement sprint 10 slice 6a creative assignment foundation`);
- implementation commit pushed to `origin/architecture-rebuild`;
- implementation boundary is exactly one migration plus the two approved pgTAP files;
- no application/runtime/UI file is included.

Canonical database evidence implemented:

- stable organization-scoped `public.external_creatives` identity registry;
- immutable and undeletable external creative identity rows;
- duplicate external creative display names permitted while UUID remains canonical identity;
- external creatives receive no authentication user, organization membership, role grant or application permission merely from registration;
- `booking_team_assignments` extended with nullable `assigned_external_creative_id`;
- assignment subject is exactly one of internal organization member or external creative;
- canonical assignment vocabulary expanded to `lead_photographer`, `assistant`, `stylist`, `lead_videographer` and `supporting_videographer`;
- singular current Lead Photographer remains enforced across internal and external subjects;
- singular current Lead Videographer enforced across internal and external subjects;
- multiple Assistants, Stylists and Supporting Videographers remain permitted subject to current-assignment uniqueness rules;
- internal-member assignment RPC evolved without creating a parallel staffing truth;
- controlled `create_external_creative(uuid,text)` RPC added;
- controlled `assign_booking_external_creative(uuid,text,uuid,boolean,text)` RPC added;
- cross-subject Lead replacement retains atomic close-and-replace semantics;
- new canonical organization role `videographer`;
- Videographer receives exactly `org.read` and `booking.read`;
- application access-control catalogue is now exactly 12 roles / 230 role-permission mappings;
- new immutable `public.commercial_operational_requirements` structured evidence;
- exact `lead_videographer` requirement mapping seeded for version-1 `maternity_diamond`, `maternity_emerald`, `newborn_emerald`, `sitter_diamond`, `sitter_emerald` and version-1 `cinematic_reel`;
- no package-label, description, free-text or assigned-videographer inference is introduced.

Security and authorization evidence:

- `external_creatives` uses forced RLS with no authenticated direct table mutation path;
- `commercial_operational_requirements` uses forced RLS and authenticated read-only access under the existing organization-read boundary;
- authenticated direct INSERT, UPDATE and DELETE remain denied where required;
- trusted-role mutation remains constrained by immutable/lifecycle guards;
- `assign_booking_team_member(...)`, `create_external_creative(...)` and `assign_booking_external_creative(...)` are authenticated-executable, anon-denied `SECURITY DEFINER` RPCs with empty `search_path`;
- external creative creation and assignment require active organization membership, `booking.team.assign` and booking-derived branch scope;
- internal Videographer assignment requires live operational Videographer eligibility;
- foreign-organization external creative identities cannot cross tenant boundaries;
- branch-scoped Client Coordinator access cannot cross booking branches;
- broad assignment audit payloads use structural identity and do not propagate external creative display names.

Local validation evidence:

- clean local database reset through migration `20260816113000`: PASS;
- database lint before and after complete regression: PASS with `No schema errors found`;
- dedicated Slice 6A pgTAP: 85 / 85 PASS;
- evolved existing booking-team pgTAP: 75 / 75 PASS;
- complete local pgTAP regression: 928 / 928 PASS across 13 files;
- migration-to-schema diff: `No schema changes found`;
- post-reset canonical database state: 12 roles / 230 role-permission mappings / 6 `lead_videographer` requirement rows / zero booking-team rows / zero external-creative rows;
- exact Videographer permission boundary: `booking.read` + `org.read`;
- implementation file fingerprints reconciled before commit and before push;
- local, tracking and actual GitHub branch heads reconciled to implementation commit `e45662c7a59eaef865b80b0738cde39386271105`;
- final implementation-push divergence: 0 / 0.

Validated behavioral and integrity boundaries include:

- internal Videographer may become Lead or Supporting Videographer only with valid operational-role eligibility;
- ordinary Photographer cannot satisfy Videographer assignment eligibility merely through Photographer role;
- external creatives may satisfy Lead Photographer, Lead Videographer and Supporting Videographer staffing assignments without gaining application access;
- Lead replacement across internal/external subjects requires a nonblank change reason;
- exact assignment replay returns existing evidence without duplicate assignment or audit rows;
- unassignment replay remains idempotent;
- duplicate-name external creative identities remain distinct UUID subjects;
- external identity mutation and deletion are blocked even through trusted direct database access;
- booking-team historical subject identity cannot be rewritten;
- commercial operational requirement evidence is append-only and immutable;
- forced cross-subject Lead replacement failure rolls back closure, replacement insertion and audit atomically;
- branch authorization and cross-organization isolation fail closed;
- all Slice 6A staffing operations leave booking journey stage, version and transition evidence unchanged.

Slice 6A remains contained. This checkpoint does not include or authorize:

- Stage 9 -> 10 implementation;
- Stage 10 -> 11 implementation;
- Newborn formal safety sign-off by unauthenticated freelancers;
- application access or organization membership for external creatives;
- generic freelancer account creation;
- a broad freelancer CRM or payroll directory;
- free-text Video/Reels requirement inference;
- shoot-day runtime/UI;
- capacity, overlap, availability or calendar-provider logic;
- any Production database migration;
- Sprint 10 release.

Production remains unchanged by Slice 6A at this checkpoint.

The latest Production database migration remains `20260814223449_sprint10_safety_readiness_foundation.sql`. Migration `20260816113000_sprint10_extended_creative_assignment_foundation.sql` has not been applied to Production.

Before any Slice 6A Production migration, a separate read-only Production preflight is mandatory. It must reconcile migration history and verify the expected pre-Slice-6A canonical baseline, including absence of `external_creatives`, absence of `commercial_operational_requirements`, absence of the `videographer` role, the existing internal-only booking-team assignment shape and the current 11-role / 228-role-permission application boundary. Any unexpected collision, drift or pre-existing canonical external staffing evidence places rollout on HOLD.

The next technical step after this checkpoint is the dedicated Slice 6 Stage 9 -> 10 technical design. That design must consume the canonical Slice 6A internal/external staffing evidence and structured commercial operational requirements rather than introducing another staffing representation or free-text Video/Reels inference. Neither this checkpoint nor that future design authorizes Production rollout or Sprint 10 release.

### Slice 6 technical design freeze — Stage 9 -> 10 Journey Advancement Gate

Technical design frozen on 2026-08-16.

This freeze translates the corrected Slice 6 founder decisions and completed Slice 6A foundation into the exact implementation contract for the sole Stage 9 -> 10 operation.

Implementation remains unauthorized until this technical-design checkpoint is independently reviewed, committed and pushed.

#### 1. Transition-only implementation boundary

Slice 6 introduces no new:

- canonical evidence table;
- canonical evidence column;
- organization role;
- permission key;
- role-permission grant;
- freelancer representation;
- commercial requirement representation.

The gate consumes existing canonical evidence from:

- `public.bookings`;
- `public.booking_journey_states`;
- `public.booking_journey_stages`;
- `public.booking_stage_transitions`;
- `public.booking_shoot_schedules`;
- `public.booking_preparations`;
- `public.booking_preparation_items`;
- `public.booking_team_assignments`;
- `public.external_creatives`;
- `public.booking_safety_readiness`;
- `public.booking_safety_signoffs`;
- `public.quotation_line_items`;
- `public.commercial_operational_requirements`;
- existing organization membership / role-grant evidence.

The operation writes only:

- one canonical Stage 9 -> 10 `booking_stage_transitions` row;
- the one authoritative `booking_journey_states` row;
- one structural audit event.

It must never repair, backfill, create, revise, end or otherwise mutate schedule, preparation, team, external-creative, readiness, sign-off or commercial-requirement evidence.

#### 2. Exact public RPC contract

The public operation is frozen exactly as:

`mark_booking_shoot_scheduled(p_booking_id uuid) RETURNS public.bookings`

It is:

- `LANGUAGE plpgsql`;
- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated`;
- not executable by `anon`;
- not a service-role-only administrative path.

The booking identifier is the only caller-supplied domain input.

The function returns the canonical booking row, following the existing controlled booking-transition convention used by `confirm_booking_after_advance(uuid)`.

#### 3. Actor and authorization boundary

Authorization occurs before any advancement.

The function requires:

- authenticated `auth.uid()`;
- active current organization membership for the booking organization;
- existing `booking.stage.advance` permission for the booking scope;
- booking-derived branch scope when the booking is branch-scoped.

The invoking actor does not additionally require:

- `prep.read`;
- `prep.write`;
- `safety.read`;
- `safety.write`;
- `safety.signoff`;
- `booking.team.assign`;
- `shoot.schedule`.

Those permissions govern creation or visibility of their own evidence domains; they do not substitute for or supplement `booking.stage.advance` at this transition boundary.

No new Stage 9 -> 10 permission is introduced.

#### 4. Transaction synchronization and lock order

The booking row is the synchronization root.

The transaction must lock in deterministic order:

1. target `bookings` row `FOR UPDATE`;
2. the one canonical `booking_journey_states` row `FOR UPDATE`;
3. current authoritative shoot-schedule tip;
4. canonical preparation instance and its preparation-item rows;
5. current booking-team assignment rows, ordered deterministically;
6. current safety-readiness revision;
7. required current internal-assignee membership / qualifying role-grant rows when internal staffing eligibility must be revalidated.

Existing schedule, preparation, team, readiness and sign-off mutation RPCs already serialize their booking-scoped mutations through the booking boundary. Slice 6 must preserve that ordering rather than introducing a conflicting lock hierarchy.

Sign-off rows are append-only. External creative identity rows are immutable.

The gate must evaluate one transactionally coherent booking snapshot and must never perform evidence repair while holding these locks.

#### 5. Journey-state and replay integrity

Normal advancement is legal only from:

- `stage_order = 9`;
- `stage_key = 'pre_shoot_preparation'`;
- active canonical Stage 9.

Canonical destination is exactly:

- `stage_order = 10`;
- `stage_key = 'shoot_scheduled'`;
- active canonical Stage 10.

An authorized Stage 10 replay is idempotent only when exactly one canonical historical Stage 9 -> 10 transition already exists for that booking with:

- source Stage 9;
- destination Stage 10;
- transition key `shoot_scheduled`.

A Stage 10 state without the matching canonical historical transition is an integrity failure, not a replay.

Replay does not re-evaluate staffing or other mutable Stage 9 evidence after the booking has already reached Stage 10.

Replay creates:

- no transition;
- no journey-version increment;
- no audit event.

Every journey stage other than valid Stage 9 or valid canonical Stage 10 replay fails closed.

#### 6. Authoritative service-category resolution

The booking's immutable `source_quotation_id` is authoritative.

The service category is resolved from the accepted quotation's structured package line through:

`quotation_line_items.source_package_version_id`
-> `commercial_package_versions`
-> `commercial_packages.service_category`.

The gate must resolve one structurally unambiguous authoritative package category.

Missing, ambiguous or unsupported category evidence fails closed.

Slice 6 does not expand the existing Slice 3 preparation taxonomy.

A category must therefore also have a valid existing canonical preparation taxonomy/snapshot capable of reaching Stage 9.

At the current Slice 6 boundary this means the advancement path remains operationally supported only where the existing preparation foundation can produce and validate the Stage 9 checklist.

Baby / Child safety-readiness support does not by itself authorize Slice 6 to invent or backfill Baby / Child preparation taxonomy.

#### 7. Reserved shoot-schedule gate

The authoritative shoot schedule is the latest schedule tip by canonical `schedule_version`.

It must exist and have:

`schedule_state = 'reserved'`.

A missing, proposed, cancelled, superseded or otherwise non-reserved authoritative tip blocks advancement.

Slice 6 adds no:

- capacity calculation;
- overlap detection;
- availability check;
- future-time validation;
- calendar-provider validation.

#### 8. Preparation structural-validity gate

Exactly one canonical preparation instance must exist for the booking.

The existing checklist must match the canonical Slice 3 structural snapshot for the authoritative service category.

Slice 6 reuses the structural contract already enforced by Stage 9 replay, including:

- canonical category;
- taxonomy version;
- expected item keys;
- expected labels;
- required/optional classification;
- sort-order structure;
- exact expected item cardinality.

The gate must not merely count satisfied rows while ignoring malformed checklist structure.

Missing, extra, duplicated, category-mismatched or structurally damaged preparation evidence fails closed.

Slice 6 performs no checklist repair.

#### 9. Required preparation satisfaction

After structural validation, every current checklist row with:

`is_required = true`

must have:

`is_satisfied = true`.

Optional checklist rows do not block advancement.

The gate does not modify preparation-item satisfaction state.

#### 10. Structured client Video/Reels requirement

Whether a Lead Videographer is required is derived only from immutable accepted-quotation source-version evidence.

`lead_videographer` is required when at least one accepted quotation line references either:

- `source_package_version_id`; or
- `source_addon_version_id`;

that is mapped by `public.commercial_operational_requirements` to:

`requirement_key = 'lead_videographer'`.

The gate must not infer a client Video/Reels requirement from:

- package labels;
- quotation labels;
- quotation descriptions;
- custom/free-form text;
- substring matching;
- inclusion ordinal keys;
- presence of a Lead or Supporting Videographer assignment.

Promotional or BTS video staffing therefore remains non-blocking when no structured client requirement exists.

#### 11. Mandatory staffing composition

For every booking that can validly reach this gate, staffing requires:

- exactly one current `lead_photographer` assignment, using the existing singular-current invariant;
- at least one current `stylist` assignment.

Assistant assignments are optional and never independently block Stage 9 -> 10.

If the accepted quotation structurally requires `lead_videographer`, the gate additionally requires:

- exactly one current `lead_videographer` assignment, using the existing singular-current invariant.

`supporting_videographer` remains optional.

The presence of optional Assistants or Supporting Videographers neither creates nor removes any gate requirement.

#### 12. Required internal-assignment eligibility

For a required current assignment whose subject is internal:

- `assigned_member_id IS NOT NULL`;
- `assigned_external_creative_id IS NULL`;
- assignment `ended_at IS NULL`;
- organization member must still be active;
- qualifying operational role grant must still be live and unrevoked;
- qualifying role grant must be valid for the booking scope.

Required role mapping is exactly:

- `lead_photographer` -> `photographer`;
- `stylist` -> `stylist`;
- `lead_videographer` -> `videographer`.

Assignment-time eligibility is not permanent proof of Stage 9 -> 10 eligibility.

A later suspension, role revocation or wrong-scope state blocks the gate without rewriting assignment history.

#### 13. Required external-assignment eligibility

For a required current assignment whose subject is external:

- `assigned_member_id IS NULL`;
- `assigned_external_creative_id IS NOT NULL`;
- assignment `ended_at IS NULL`;
- referenced `external_creatives` identity must still exist;
- external identity must belong to the same organization;
- the canonical current booking assignment itself is the booking-specific operational approval.

External creatives do not require:

- auth users;
- organization membership;
- organization roles;
- branch grants;
- application permissions.

Ended external assignments do not satisfy the gate.

Duplicate display names are irrelevant to qualification because stable UUID identity is authoritative.

#### 14. Current safety-readiness gate

Exactly one current readiness revision must exist:

`superseded_at IS NULL`.

Its:

- booking;
- organization;
- service category;

must match the authoritative booking/category context.

Current readiness must satisfy the exact Slice 5 applicability matrix:

- Newborn: `safety_state = 'ready'` and `comfort_state = 'ready'`;
- Maternity: `safety_state = 'not_applicable'` and `comfort_state = 'ready'`;
- Sitter: `safety_state = 'ready'` and `comfort_state = 'ready'`.

Baby / Child readiness semantics remain historically valid Slice 5 evidence but do not cause Slice 6 to broaden the current preparation taxonomy.

Missing, pending, `not_ready`, malformed or category-mismatched current readiness blocks advancement.

#### 15. Newborn current-readiness sign-off gate

Only Newborn requires formal sign-off.

At least one qualifying immutable sign-off must bind to the exact current readiness ID.

A sign-off attached to a superseded readiness revision never qualifies.

Administrative and Photographer sign-offs have deliberately different current-qualification rules.

A sign-off with authority:

- `founder`; or
- `studio_manager`

continues to qualify for that same current readiness revision if it was validly created under the Slice 5 RPC, even if the signer later:

- loses that role;
- loses membership;
- leaves the organization;
- or the Lead Photographer changes.

The gate does not re-authorize administrative sign-offs retrospectively.

A sign-off with authority:

`lead_photographer`

qualifies only when all of the following remain true at Stage 9 -> 10:

- sign-off `readiness_id` is the exact current readiness ID;
- sign-off `lead_assignment_id` equals the exact current canonical Lead Photographer assignment ID;
- that Lead assignment is still current;
- that Lead assignment is internal;
- `signed_by` equals that assignment's `assigned_member_id`;
- signer remains an active organization member;
- signer still has a live, unrevoked Photographer role grant valid for the booking scope.

A historical Photographer sign-off never becomes valid again merely because the same member is later reassigned as Lead under a different assignment interval.

If the current Lead Photographer is external, that external staffing assignment may satisfy staffing but cannot itself create or satisfy a Photographer-authority database sign-off. A qualifying Founder or Studio Manager sign-off is therefore required unless the person was separately onboarded and signed through the internal-member path.

#### 16. Stage 9 -> 10 transition mutation

After every gate passes, the function:

1. resolves the canonical active Stage 10 ID;
2. inserts exactly one `booking_stage_transitions` row with:
   - source = current Stage 9;
   - destination = canonical Stage 10;
   - `transition_key = 'shoot_scheduled'`;
   - current authenticated actor;
   - one transition timestamp;
3. updates the one `booking_journey_states` row:
   - `current_stage_id = Stage 10`;
   - `stage_entered_at = transition timestamp`;
   - `version = previous version + 1`;
   - `updated_by = actor`;
4. includes the captured previous journey `version` in the UPDATE predicate.

If the optimistic version UPDATE affects no row, the transaction raises a `40001` concurrency failure.

Transition insert, state update and audit append are one transaction. Failure of any step rolls the entire advancement back.

#### 17. Structural audit contract

A successful real advancement appends exactly one audit event:

`booking.shoot_scheduled`

Audit entity:

`booking`

The event is non-sensitive structural workflow evidence.

`old_values` and `new_values` are limited to structural journey state, such as:

- stage key;
- journey version.

Metadata may include structural identifiers or controlled booleans such as:

- booking ID;
- `transition_key`;
- source quotation ID;
- authoritative schedule version;
- authoritative service category;
- whether structured Lead Videographer requirement applied.

The audit must not contain:

- preparation-item labels/content;
- external creative display names;
- detailed assignment/member data;
- readiness states beyond what is required for structural workflow evidence;
- unrestricted safety/comfort content;
- medical information;
- sensitive free text.

Failed gate evaluations create no audit event.

#### 18. Exception and fail-closed convention

The RPC uses distinct structural failure messages prefixed:

`mark_booking_shoot_scheduled:`

Error classes follow existing conventions:

- `42501` for authentication / membership / permission / branch authorization failures;
- `22023` for unmet controlled business-gate conditions or unsupported transition state;
- `P0001` for malformed / contradictory canonical evidence and integrity failures;
- `40001` for optimistic journey-state concurrency failure.

The operation returns the first structural failure and performs no partial advancement.

Restricted safety detail must never be embedded in error text.

#### 19. Dedicated pgTAP implementation boundary

Slice 6 implementation adds one dedicated test file:

`supabase/tests/sprint10_stage9_10_gate_test.sql`

The implementation must cover at least:

- RPC existence, return type, `SECURITY DEFINER`, empty `search_path`, authenticated execution and anon denial;
- exact Stage 9 -> 10 success;
- exactly one transition row with `shoot_scheduled`;
- exactly one journey-version increment;
- exactly one structural audit event;
- valid Stage 10 replay with no new transition/version/audit;
- Stage 10 without canonical transition history fails as integrity corruption;
- every other journey stage fails closed;
- missing/non-reserved schedule blocks;
- missing/malformed preparation instance or checklist blocks;
- unsatisfied required preparation item blocks;
- optional preparation item remains non-blocking;
- missing Lead Photographer blocks;
- missing Stylist blocks;
- missing Assistant does not block;
- internal Lead Photographer live Photographer-role eligibility is revalidated;
- internal Stylist live Stylist-role eligibility is revalidated;
- conditional internal Lead Videographer live Videographer-role eligibility is revalidated;
- suspended/revoked/wrong-branch required internal creative blocks;
- current external Lead Photographer satisfies staffing;
- current external Stylist satisfies staffing;
- conditional current external Lead Videographer satisfies staffing;
- ended external required assignment blocks;
- external identity organization mismatch fails closed;
- duplicate external display names have no semantic effect;
- no video requirement means Videographer staffing is optional;
- package-version `lead_videographer` requirement makes Lead Videographer mandatory;
- add-on-version `lead_videographer` requirement makes Lead Videographer mandatory;
- promotional Videographer assignment alone never creates the commercial requirement;
- free-form quotation text never creates the commercial requirement;
- missing/current-readiness mismatch blocks;
- Newborn exact ready readiness requires qualifying current-revision sign-off;
- Maternity requires exact `not_applicable` safety + ready comfort and no formal sign-off;
- Sitter requires ready safety + ready comfort and no formal sign-off;
- superseded-readiness sign-off never qualifies;
- Founder administrative sign-off persists for the same readiness revision after later role/member loss;
- Studio Manager administrative sign-off persists for the same readiness revision after later role/member loss;
- Photographer sign-off becomes non-qualifying after Lead replacement;
- Photographer sign-off becomes non-qualifying after member suspension;
- Photographer sign-off becomes non-qualifying after Photographer-role revocation;
- old Photographer sign-off does not regain validity after later reassignment under a different Lead assignment ID;
- external Lead Photographer requires Founder/Studio Manager formal sign-off for Newborn unless separately onboarded and signed through the internal path;
- `booking.stage.advance` is required;
- `prep.write`, `safety.write`, `safety.signoff` and `booking.team.assign` do not substitute for `booking.stage.advance`;
- organization isolation;
- branch isolation;
- forced transition-insert or journey-update failure rolls back the complete advancement;
- successful advancement mutates no schedule, preparation, team, external-creative, readiness, sign-off or commercial requirement evidence;
- audit payload contains no restricted safety or external-creative personal content.

The existing 928-test regression remains the pre-Slice-6 baseline and must remain green when the new dedicated suite is added.

#### 20. Implementation file boundary

The later Slice 6 implementation is limited to exactly:

- one new Stage 9 -> 10 migration;
- `supabase/tests/sprint10_stage9_10_gate_test.sql`.

No existing Slice 6A schema migration is rewritten.

No existing canonical evidence table is redesigned.

Any required correction outside this two-file boundary requires a new explicit design gate before implementation continues.

#### 21. Slice 6 containment

This technical freeze does not authorize:

- writing or executing the Stage 9 -> 10 migration yet;
- Stage 10 -> 11;
- shoot-completion workflow;
- shoot-day safety evidence;
- UI/runtime release;
- `/bookings`, `/prep` or `/safety` application changes;
- capacity/availability/overlap logic;
- external calendar-provider integration;
- freelancer CRM/payroll functionality;
- permission or role-grant expansion;
- Production migration;
- Sprint 10 release.

### Slice 6 implementation checkpoint — Stage 9 -> 10 Journey Advancement Gate

Slice 6 Stage 9 -> 10 database implementation completed, fully validated and pushed to `origin/architecture-rebuild` on 2026-08-17.

Implementation evidence:

- migration: `20260816161000_sprint10_stage9_10_gate_foundation.sql`;
- dedicated pgTAP: `supabase/tests/sprint10_stage9_10_gate_test.sql`;
- implementation commit: `e0e9ff9e7ccd2bcaa983af8ddbae1f4e674f8d4b` (`feat: add sprint 10 stage 9->10 gate foundation`);
- implementation parent / frozen technical-design checkpoint: `2cac45c358adf16cf396e535d2c30237f44dd564`;
- implementation boundary is exactly the one new migration and one dedicated pgTAP file frozen by Slice 6;
- no Slice 6A migration, application/runtime/UI file or unrelated canonical evidence file was modified;
- migration SHA-256: `cace5e812835d3449c000a3d1719feff801bd582f8a1d7879e0cb64cfec8a187`;
- dedicated pgTAP SHA-256: `c793c60a0f0455260d1fff2c5cacb4a55716f21d8b913f5a8e5e44840e5d2173`;
- implementation commit pushed to `origin/architecture-rebuild`;
- local, tracking and actual remote branch refs were reconciled to the exact implementation commit with final divergence `0 / 0`.

Canonical Stage 9 -> 10 behavior implemented:

- public `mark_booking_shoot_scheduled(uuid)` is the sole Stage 9 -> 10 operation;
- RPC is `SECURITY DEFINER`, uses empty `search_path`, is executable by `authenticated`, and denies `anon` and direct `service_role` execution;
- authorization requires authenticated actor, active organization membership, existing `booking.stage.advance` and booking-derived branch scope;
- normal advancement is restricted to exact active Stage 9 / `pre_shoot_preparation`;
- exact authorized Stage 10 / `shoot_scheduled` replay is idempotent only when the one canonical historical `shoot_scheduled` Stage 9 -> 10 transition already exists;
- malformed Stage 10 replay history fails closed rather than repairing history;
- authoritative service category is resolved only from accepted-quotation structured source package-version evidence;
- the authoritative latest shoot-schedule tip must be `reserved`;
- exactly one canonical preparation instance and structurally valid Slice 3 checklist snapshot are required;
- every required preparation item must be satisfied while optional items remain non-blocking;
- exactly one current Lead Photographer and at least one current Stylist are mandatory;
- Assistant remains optional;
- Lead Videographer is mandatory only when immutable accepted-quotation package/add-on source-version evidence maps to `lead_videographer` in `commercial_operational_requirements`;
- Supporting Videographer remains optional and promotional/BTS staffing does not itself create a client Video/Reels requirement;
- required internal Lead Photographer, Stylist and Lead Videographer assignments are revalidated against current active membership, live unrevoked qualifying role and booking scope;
- current same-organization external creative assignments may satisfy required staffing without receiving authentication users, organization membership or application permissions;
- current safety-readiness evidence must match the authoritative booking category and frozen readiness matrix;
- Newborn requires a qualifying current formal sign-off;
- Founder and Studio Manager administrative Newborn sign-offs remain qualifying for the same readiness revision after later signer role/member loss;
- ordinary Photographer Newborn sign-off remains qualifying only while bound to the exact current internal Lead Photographer assignment and current operational Photographer eligibility;
- an external Lead Photographer can satisfy staffing but cannot by itself satisfy the database Photographer formal-sign-off path;
- successful advancement writes only the canonical Stage 9 -> 10 transition, the authoritative journey-state mutation and one structural `booking.shoot_scheduled` audit event;
- schedule, preparation, checklist, team, external-creative, readiness, sign-off and commercial-requirement evidence remain read-only to the advancement operation;
- audit evidence excludes restricted safety content and external-creative personal content.

Local validation evidence:

- clean local reset applied all migrations through `20260816161000_sprint10_stage9_10_gate_foundation.sql`: PASS;
- database lint: PASS with `No schema errors found`;
- dedicated Stage 9 -> 10 pgTAP: 92 / 92 PASS;
- complete local pgTAP regression: 1020 / 1020 PASS across 14 files;
- post-rollback canonical state: 12 roles / 230 role-permission mappings / 6 `lead_videographer` operational-requirement rows / zero booking-stage-transition rows / zero booking-team rows / zero external-creative rows / zero safety-readiness rows / zero safety-sign-off rows / zero `booking.shoot_scheduled` audit rows;
- authorization, permission, branch and tenant isolation paths fail closed without advancement mutation;
- latest non-reserved schedule evidence blocks advancement;
- invalid Stage 10 replay history fails closed without repair;
- live internal Photographer, Stylist and Videographer role eligibility is revalidated at advancement time;
- direct authenticated writes to journey-state, transition and audit evidence remain denied;
- migration remained byte-identical throughout all behavioral validation.

Native two-session serialization evidence:

- two independent PostgreSQL sessions invoked `mark_booking_shoot_scheduled(uuid)` against the same ready Stage 9 booking;
- Session A held the canonical booking-row lock while Session B invoked the same RPC;
- PostgreSQL reported Session B actively waiting with `wait_event_type = 'Lock'` and Session A as its blocker;
- both callers completed successfully after serialization;
- final journey state was exactly `shoot_scheduled`;
- journey version incremented exactly once from `3` to `4`;
- exactly one `shoot_scheduled` transition existed;
- exactly one `booking.shoot_scheduled` audit event existed;
- the second caller resolved through the exact Stage 10 replay path without a duplicate transition, version increment or audit event;
- the committed local-only concurrency fixture was fully removed by a clean local database reset;
- post-reset dedicated pgTAP remained 92 / 92 PASS;
- post-reset complete regression remained 1020 / 1020 PASS;
- post-reset database lint remained clean;
- post-reset canonical operational evidence returned to zero rows.

Slice 6 remains contained. This checkpoint does not include or authorize:

- Stage 10 -> 11 / `Shoot Completed`;
- shoot-completion evidence or shoot-day safety-event workflow;
- `/bookings`, `/prep` or `/safety` runtime/UI release;
- application/runtime integration;
- capacity, availability or overlap logic;
- external calendar-provider integration;
- freelancer CRM, payroll or generic freelancer account creation;
- any new role, permission key or role-permission expansion;
- free-text Video/Reels requirement inference;
- mutation or redesign of existing Slice 6A canonical evidence;
- any Production database migration;
- Sprint 10 release.

Production remains unchanged by this implementation checkpoint.

This checkpoint does not apply either `20260816113000_sprint10_extended_creative_assignment_foundation.sql` or `20260816161000_sprint10_stage9_10_gate_foundation.sql` to Production.

Before any Production rollout, a separate read-only Production preflight is mandatory. That preflight must reconcile actual Production migration history and schema state, verify the prerequisite Slice 6A dependency order before the Stage 9 -> 10 migration, confirm the expected access-control and canonical-evidence baseline, and place rollout on HOLD for any unexpected collision or drift.

No Production migration is authorized by this checkpoint.

### Slice 6 Production rollout checkpoint — Stage 9 -> 10 Journey Advancement Gate

Sprint 10 Slice 6 Production database rollout completed and was independently post-validated on 2026-08-17.

Production target:

- Supabase project: `memory-keeper-os`;
- approved Production project ref: `fqsdmurrzlqtkfzbwszp`;
- deployment was performed only after a read-only Production preflight proved the expected pre-Slice-6 baseline and exact migration dependency order.

Production migrations applied, in canonical order:

1. `20260816113000_sprint10_extended_creative_assignment_foundation.sql`;
2. `20260816161000_sprint10_stage9_10_gate_foundation.sql`.

Migration identity:

- Slice 6A SHA-256: `84576bd1663f3facefbe84cb6980f690bc477b0fe94f7db374680fddb61a69e6`;
- Stage 9 -> 10 SHA-256: `cace5e812835d3449c000a3d1719feff801bd582f8a1d7879e0cb64cfec8a187`;
- dedicated Stage 9 -> 10 pgTAP SHA-256: `c793c60a0f0455260d1fff2c5cacb4a55716f21d8b913f5a8e5e44840e5d2173`.

Pre-rollout Production evidence:

- remote migration history ended at `20260814223449`;
- exactly `20260816113000` and `20260816161000` were pending;
- Production access-control baseline was exactly 11 roles / 228 role-permission mappings;
- `videographer` was absent;
- Slice 6A tables, external-assignment column and RPCs were absent;
- `mark_booking_shoot_scheduled(uuid)` was absent;
- existing internal booking-team RPC had not already evolved to Slice 6A semantics;
- booking-team, safety-readiness, safety-sign-off, `shoot_scheduled` transition and `booking.shoot_scheduled` audit evidence counts were zero;
- decisive pre-rollout collision verdict was fully green.

Production deployment evidence:

- `supabase db push --linked --dry-run` identified exactly the two approved migrations and no seed data;
- dry-run ordering was Slice 6A first, then Stage 9 -> 10;
- the explicit Production write boundary was confirmed before deployment;
- both approved migrations applied successfully;
- no migration repair, linked reset or seed push was used.

Post-rollout Production canonical state:

- Production migration history records both `20260816113000` and `20260816161000`;
- role count is exactly 12;
- role-permission mapping count is exactly 230;
- exactly one `videographer` role exists;
- Videographer receives exactly `booking.read` and `org.read`;
- `external_creatives` exists with the intended hardened access model;
- `commercial_operational_requirements` exists with the intended hardened access model;
- exactly six structured `lead_videographer` operational requirements exist;
- `booking_team_assignments.assigned_external_creative_id` exists;
- internal and external booking-team subjects use the frozen subject-XOR model;
- the five-role booking-team assignment vocabulary is active;
- `create_external_creative(uuid,text)` exists;
- `assign_booking_external_creative(uuid,text,uuid,boolean,text)` exists;
- both external-creative RPCs are `SECURITY DEFINER`, use empty `search_path`, deny `anon`, and allow the committed `authenticated` plus `service_role` execution boundary;
- `mark_booking_shoot_scheduled(uuid)` exists with the validated authenticated-only application contract and direct `service_role` execution denied;
- Stage 9 -> 10 remains the sole implemented journey advancement in Slice 6;
- no Stage 10 -> 11 behavior was introduced.

A first post-rollout validator incorrectly expected `service_role` to lack `EXECUTE` on the two Slice 6A external-creative RPCs. That assertion was rejected after read-only diagnosis demonstrated that:

- the committed Slice 6A migration explicitly grants those two RPCs to `authenticated, service_role`;
- the dedicated Slice 6A pgTAP contract permits that boundary;
- local and Production ACL state matched exactly;
- both RPCs continue to enforce authenticated actor identity, active organization membership, `booking.team.assign`, booking branch scope and organization-safe resource checks internally.

No Production ACL hotfix, rollback, migration repair or repeat deployment was performed. The validator was corrected instead.

Corrected post-rollout verification:

- both Production migrations recorded remotely: PASS;
- corrected static Production contract: PASS;
- Production database lint: PASS with `No schema errors found`;
- remote database dry-run reports `upToDate: true`;
- no migrations remain pending;
- no seed data is pending;
- booking-team assignment rows: 0;
- external-creative rows: 0;
- safety-readiness rows: 0;
- safety-sign-off rows: 0;
- `shoot_scheduled` transition rows: 0;
- `booking.shoot_scheduled` audit rows: 0;
- corrected validation continuation was read-only and executed no Production DDL/DML.

Repository state remained unchanged throughout Production verification:

- pre-checkpoint Git HEAD: `6dc9ae3e3fde1d4b0b3183473dd40432deaa90b9`;
- local and `origin/architecture-rebuild` remained reconciled at `0 / 0`;
- validated migration and test files remained byte-identical.

Slice 6 Production rollout is therefore technically complete.

This Production checkpoint does not authorize or include:

- Stage 10 -> 11 / `Shoot Completed`;
- shoot-completion evidence;
- shoot-day safety-event workflow;
- `/bookings`, `/prep` or `/safety` runtime/UI release;
- application/runtime integration for the new Stage 9 -> 10 RPC;
- capacity, overlap or advanced availability logic;
- external calendar-provider integration;
- freelancer CRM/payroll or freelancer application accounts;
- additional role or permission expansion;
- Sprint 10 release.

Sprint 10 remains an implementation programme with later separately governed slices still required.

### Slice 7A technical design freeze — Runtime Contract Reconciliation

Slice 7A is the first post-Slice-6 application/runtime reconciliation slice.

Its purpose is to align the TypeScript application contract with the canonical Sprint 10 database contract before any `/bookings`, `/prep` or `/safety` runtime expansion.

#### 1. Discovery basis

Read-only application and local-database discovery established that:

- `/bookings` already reads canonical Supabase booking, quotation and journey records;
- `/prep` still reads the legacy Zustand booking store;
- `/safety` still reads legacy mock/Zustand state and uses the legacy `submitSafety` mutation;
- `/prep` and `/safety` remain correctly blocked by `temporarilyUnavailablePaths`;
- all required Sprint 10 database tables and public RPCs exist locally;
- local Sprint 10 operational evidence tables are currently empty;
- generated `src/integrations/supabase/types.ts` does not yet contain the Sprint 10 tables or RPCs;
- the frontend role catalogue does not match the canonical database role-key vocabulary.

No Production query or database write was required for this discovery.

#### 2. Canonical role-key authority

`public.roles.key` is the sole authoritative application role vocabulary.

`public.my_membership(uuid)` returns assigned role keys directly from the canonical `public.roles` catalogue. The frontend must consume those keys without inventing a second naming system.

The canonical Slice 7A role vocabulary is exactly:

- `founder`;
- `studio_manager`;
- `client_coordinator`;
- `sales`;
- `photographer`;
- `assistant`;
- `stylist`;
- `editor`;
- `album_coordinator`;
- `marketing`;
- `accounts`;
- `videographer`.

Legacy frontend aliases including:

- `coordinator`;
- `album`;

must not remain application role identities after Slice 7A.

No compatibility alias mapper is introduced. Maintaining two role vocabularies would preserve an avoidable authorization ambiguity and could silently discard canonical membership roles.

#### 3. Frontend role reconciliation

Slice 7A may update only the application role contract required to consume canonical database role keys.

The intended implementation files are:

- `src/lib/session.ts`;
- `src/lib/access.ts`;
- `src/lib/invites.functions.ts`;
- `src/lib/team.functions.ts`;
- `src/integrations/supabase/types.ts`.

The generated type file is regenerated from the local Supabase database rather than hand-edited.

`src/routeTree.gen.ts` may be regenerated temporarily by the normal build process but is not part of the Slice 7A authored implementation and must be restored unless a genuine route-definition change unexpectedly requires it. Slice 7A does not authorize a route-definition change.

#### 4. Session role contract

`AppRole` must represent the canonical database role keys exactly.

`useSession()` continues to obtain membership through the authenticated `my_membership(uuid)` RPC.

`assigned_role_keys` must be filtered only against the canonical twelve-role frontend catalogue.

The session layer must therefore recognize:

- Studio Manager;
- Client Coordinator;
- Album Coordinator;
- Videographer;

using their canonical database keys.

No role may gain a database permission merely because the frontend displays or recognizes that role.

Database permission checks and permission-aware RPCs remain authoritative for domain mutations.

#### 5. Access-layer reconciliation

`src/lib/access.ts` must use canonical role keys.

Existing navigation and action intent may be translated to canonical names where equivalent, but Slice 7A must not widen a route or mutation beyond the authoritative database permission model.

In particular:

- legacy `coordinator` references become `client_coordinator` where they represent the existing Client Coordinator role;
- legacy `album` references become `album_coordinator`;
- `studio_manager` is recognized as a first-class application role;
- `videographer` is recognized as a first-class application role;
- Founder behavior remains unchanged;
- route containment remains unchanged in Slice 7A.

`/prep` and `/safety` remain in `temporarilyUnavailablePaths`.

Slice 7A does not release either route.

#### 6. Invite and team role reconciliation

Application-side invite and team role catalogues must use the canonical database role keys.

No new database role is created by Slice 7A.

No role grant, permission grant, organization-member record or invitation is created as part of technical reconciliation itself.

Any future runtime action remains subject to the existing database role-assignment and authorization RPC boundaries.

#### 7. Generated Supabase type reconciliation

`src/integrations/supabase/types.ts` must be regenerated from the local database with the supported Supabase CLI type-generation path.

The generated contract must include the current public-schema representations for at least:

Tables:

- `booking_shoot_schedules`;
- `booking_preparations`;
- `booking_preparation_items`;
- `booking_team_assignments`;
- `external_creatives`;
- `commercial_operational_requirements`;
- `booking_safety_readiness`;
- `booking_safety_signoffs`.

RPCs:

- `propose_booking_shoot_schedule`;
- `reschedule_booking_shoot`;
- `start_pre_shoot_preparation`;
- `update_pre_shoot_preparation_item`;
- `assign_booking_team_member`;
- `create_external_creative`;
- `assign_booking_external_creative`;
- `record_booking_safety_readiness`;
- `signoff_booking_safety_readiness`;
- `mark_booking_shoot_scheduled`.

Type generation must use the local development database for Slice 7A. No linked Production type generation is required.

#### 8. Validation boundary

Slice 7A implementation is complete only when all of the following are proven:

- canonical twelve-role frontend vocabulary is present exactly once;
- legacy application role identities `coordinator` and `album` are absent from role catalogues and authorization arrays;
- unrelated domain text such as the keepsake value `album` is not incorrectly treated as a role defect;
- `my_membership` remains the authenticated membership source;
- generated Supabase types contain every frozen Sprint 10 table marker;
- generated Supabase types contain every frozen Sprint 10 RPC marker;
- `/prep` remains contained;
- `/safety` remains contained;
- no legacy route is released;
- targeted Prettier passes;
- targeted ESLint passes;
- TypeScript passes after normal route generation;
- production build passes;
- `git diff --check` passes;
- local database schema is unchanged;
- no migration file is created or modified;
- final worktree contains only the explicitly authorized Slice 7A application/type files before commit.

#### 9. Explicit containment

Slice 7A does not authorize:

- `/bookings` scheduling/team/safety mutation UI;
- `/prep` runtime cutover;
- `/safety` runtime cutover;
- removal of `/prep` containment;
- removal of `/safety` containment;
- Stage 10 -> 11 / `Shoot Completed`;
- shoot-day safety-event evidence;
- privacy, editing, delivery, Pixieset or heirloom runtime release;
- new database tables;
- new database RPCs;
- new permissions;
- new roles;
- changed role-permission mappings;
- a Supabase migration;
- Production database queries or writes;
- Production rollout;
- Sprint 10 release.

#### 10. Next implementation boundary

After this technical freeze is committed and pushed, the next implementation gate is restricted to the five authorized Slice 7A application/type paths.

Only after Slice 7A is independently validated and checkpointed may Sprint 10 proceed to the separately governed `/bookings` operational runtime slice.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 7B implementation checkpoint — Canonical Team Access Mutation Foundation

Sprint 10 Slice 7B canonical Team access database foundation was implemented and fully validated locally on 2026-08-17.

Slice 7B establishes the authoritative organization-invitation and role-mutation boundary required before any Team UI migration.

#### Implementation boundary

Implementation is limited to:

- migration `20260816221825_sprint10_canonical_team_access_foundation.sql`;
- dedicated pgTAP `supabase/tests/sprint10_canonical_team_access_test.sql`;
- regenerated `src/integrations/supabase/types.ts`.

No Team UI, Team server-function cutover, legacy Team deletion, Stage 10 -> 11 implementation, or Production database mutation is included.

#### Canonical invitation foundation

Implemented:

- `organization_invitations`;
- `organization_invitation_roles`;
- invitation lifecycle `pending`, `accepted`, `revoked`;
- expiry derived from pending status plus `expires_at`;
- normalized invitation email;
- SHA-256 token-hash persistence only;
- raw bearer invitation tokens are never stored;
- accepted/revoked invitation states are terminal;
- invitation identity evidence is immutable;
- historical revoked invitations are preserved;
- invitation-role evidence is controlled and organization-safe;
- Founder invitation roles remain organization-wide only.

Both canonical invitation tables:

- enable RLS;
- force RLS;
- expose no authenticated direct INSERT, UPDATE or DELETE path;
- expose no anonymous table access;
- retain trusted service-role administration outside the normal application boundary.

#### Canonical invitation RPC boundary

Implemented:

- `create_organization_invitation(uuid,text,text,text[],integer)`;
- `revoke_organization_invitation(uuid,uuid,text)`;
- `preview_organization_invitation(text)`;
- `accept_organization_invitation(text)`.

Creation requires:

- current active organization membership;
- `team.invite`;
- `team.role.assign` when invitation roles are preassigned.

Studio Manager may therefore create a role-less invitation under `team.invite`, but may not preassign roles without `team.role.assign`.

Invitation preview:

- is bearer-token gated;
- exposes only the safe invitation projection needed before authentication;
- does not expose invitation IDs, token hashes or internal role/member identifiers;
- returns only pending, unexpired invitations for active organizations.

Invitation acceptance:

- requires authenticated `auth.uid()`;
- requires confirmed authenticated email;
- requires exact case-insensitive match to the invited email;
- creates or resolves the canonical active `organization_members` membership;
- rejects existing non-active membership state;
- creates canonical live role grants from invitation-role evidence;
- marks the invitation accepted atomically;
- rejects replay after acceptance.

Authorization does not rely on user-editable `user_metadata`.

#### Canonical Team read and role-mutation boundary

Implemented:

- `team_access_directory(uuid)`;
- `team_invitation_directory(uuid)`;
- `grant_organization_member_role(uuid,uuid,text,uuid)`;
- `revoke_organization_member_role(uuid,uuid,text,uuid,text)`.

Role grant/revoke requires:

- current active organization membership;
- `team.role.assign`;
- target membership in the same organization;
- valid canonical role;
- valid branch scope where applicable.

Role revocation preserves historical grant evidence rather than deleting it.

The existing deferred Founder-coverage protections remain authoritative, including protection against removal of the final active organization-wide Founder.

#### Permission behavior frozen by implementation

The locally verified Team permission matrix remains:

- Founder: `team.invite`, `team.read`, `team.role.assign`, `team.suspend`;
- Studio Manager: `team.invite`, `team.read`, `team.suspend`;
- Client Coordinator: `team.read`.

Studio Manager does not receive `team.role.assign`.

Client Coordinator does not receive `team.invite`, `team.role.assign` or `team.suspend`.

#### Security boundary

All ten Slice 7B SECURITY DEFINER/read-boundary functions were verified with an empty `search_path`.

Sensitive Team invitation and role mutations append sensitive audit evidence.

Raw invitation bearer tokens are excluded from persistent invitation storage and audit payloads.

Authenticated direct writes to canonical membership/grant tables remain blocked.

No legacy browser direct-write path becomes authoritative through Slice 7B.

#### Local database validation

Validation evidence:

- migration dry-run inside rollback transaction: PASS;
- local migration application: PASS;
- `supabase db lint --local`: PASS with no schema errors;
- Supabase security advisor WARN/ERROR findings attributable to Slice 7B: 0;
- Supabase performance advisor WARN/ERROR findings: 0;
- dedicated Slice 7B pgTAP: 42 / 42 PASS;
- complete local regression before clean rebuild: 1062 / 1062 PASS across 15 files;
- clean `supabase db reset --local --no-seed`: PASS;
- complete post-reset regression: 1062 / 1062 PASS across 15 files;
- post-reset canonical contract: both invitation tables present;
- post-reset canonical contract: all eight public Slice 7B read/mutation functions present;
- post-reset migration history contains `20260816221825`.

Behavioral validation includes:

- Client Coordinator Team read access;
- Client Coordinator invite/role-mutation denial;
- Studio Manager role-less invitation creation;
- Studio Manager role-bearing invitation denial;
- invitation revoke and revoke replay;
- safe token preview;
- invitation supersession;
- invalid-token denial;
- unconfirmed-email acceptance denial;
- wrong-email acceptance denial;
- successful confirmed-email acceptance;
- canonical membership creation;
- invitation-role assignment;
- acceptance replay denial;
- role grant idempotency;
- role revoke/history preservation;
- regrant with new historical evidence;
- cross-organization mutation denial;
- sensitive Team audit enforcement;
- raw bearer-token audit exclusion;
- final-Founder revocation protection and rollback.

#### Generated Supabase type synchronization

Generated TypeScript was produced from the clean rebuilt local database using the canonical `public,graphql_public` schema set and normalized with the repository Prettier configuration before replacement.

The generated refresh includes:

- `organization_invitations`;
- `organization_invitation_roles`;
- `organization_invitation_status`;
- all eight Slice 7B public functions;
- previously stale generated Sprint 10 schema/RPC definitions.

The apparent `notification_outbox` deletion diff was audited against the rebuilt database and proved to be diff alignment only; its 19-column schema and foreign-key type contract remain preserved.

Final generated-type SHA-256:

`dd271203855aa94aca197184b7b45c055714eb440fefa51f14f68a2b2bbb6c73`

Migration SHA-256:

`8726d585268c9254f13d553f90a2772c259b36bf3dbdf5c6a58fb60e7bd216f4`

Dedicated pgTAP SHA-256:

`5005a34b1aa06f158bc8251c6cf2c184d3f316804fb20831afd70dd7158525db`

#### Application / repository validation

Application validation:

- Production build: PASS;
- targeted ESLint for refreshed Supabase types: PASS;
- generated Supabase types Prettier: PASS;
- `git diff --check`: PASS;
- generated type file exactly matches the audited temporary artifact.

Repository-wide TypeScript remains on the pre-existing stale TanStack route-tree baseline:

- pre-Slice-7B generated Supabase types: `tsc` exit 2;
- Slice 7B generated Supabase types: `tsc` exit 2;
- exact TypeScript error-set comparison: identical;
- Slice 7B introduces zero TypeScript error-set changes.

Repository-wide ESLint remains known pre-existing baseline debt and is not introduced by Slice 7B. Targeted lint for the only modified application/type file passes.

Existing non-blocking build warnings remain unchanged, including legacy `inputValidator()` deprecations, bundle-size warnings, dependency-level `"use client"` notices, Nitro/Rollup warnings and Wrangler configuration notices.

#### Slice 7B containment

Slice 7B does not authorize:

- Team UI cutover;
- replacement of legacy `team.functions.ts`;
- replacement of legacy `invites.functions.ts`;
- legacy `studio_invites` deletion;
- legacy `user_roles` deletion;
- direct browser writes to canonical access-control tables;
- `/prep` or `/safety` release;
- `/bookings` Team mutation UI;
- Stage 10 -> 11 / `Shoot Completed`;
- new payment, KPI, privacy, consent or marketing behavior;
- Production database migration;
- Sprint 10 release.

The next Team-access implementation boundary must consume these canonical invitation, membership and role-mutation RPCs rather than adding another authorization source of truth.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 7C technical design freeze — Canonical Team Runtime Cutover

Sprint 10 Slice 7C is the application/runtime cutover from the legacy Team and invitation authority paths to the canonical access-control foundation established by Slice 7B.

This technical freeze was approved for implementation on 2026-08-17.

Slice 7C deliberately separates canonical Team runtime cutover from canonical role-administration UI. Current canonical role assignments will be visible but read-only in this slice because the Slice 7B Team directory exposes aggregate role and branch information rather than the exact scope of each individual role grant.

#### 1. Relationship to Slice 7A and Slice 7B

The historical Slice 7A Runtime Contract Reconciliation freeze remains part of the project record.

Its unexecuted application implementation boundary is superseded by this narrower and safer runtime cutover because Slice 7B now provides the canonical Team invitation, membership and role-mutation database foundation.

Slice 7C consumes Slice 7B rather than creating a second Team authority model.

Slice 7C does not modify the Slice 7B database migration or pgTAP suite.

#### 2. Exact authored file boundary

Slice 7C implementation may modify exactly:

- `src/lib/session.ts`;
- `src/lib/access.ts`;
- `src/lib/team.functions.ts`;
- `src/lib/invites.functions.ts`;
- `src/routes/_authenticated/team.tsx`;
- `src/routes/auth.tsx`.

`src/routeTree.gen.ts` may be regenerated temporarily by the normal TanStack build process but is not an authored Slice 7C file and must be restored before the final implementation commit because Slice 7C does not change route definitions.

No Supabase migration is authorized.

No generated Supabase type change is expected because Slice 7B already synchronized the required canonical RPC contracts.

Any required file outside this six-file boundary requires a new explicit design decision before implementation continues.

#### 3. Canonical application role vocabulary

`public.roles.key` remains the authoritative role-key vocabulary.

The application role vocabulary must be exactly:

- `founder`;
- `studio_manager`;
- `client_coordinator`;
- `sales`;
- `photographer`;
- `assistant`;
- `stylist`;
- `editor`;
- `album_coordinator`;
- `marketing`;
- `accounts`;
- `videographer`.

Legacy application identities:

- `coordinator`;
- `album`;

must be removed from role catalogues and authorization arrays.

No compatibility alias layer is introduced.

`useSession()` continues to obtain authoritative membership and assigned role keys through `my_membership(uuid)`.

User-editable auth metadata must not be used for authorization.

Profile/name metadata may remain display fallback only.

#### 4. Access-layer reconciliation

`src/lib/access.ts` must use canonical role keys.

Existing route intent may be translated to canonical names where equivalent without widening database authority.

At minimum:

- `coordinator` becomes `client_coordinator`;
- `album` becomes `album_coordinator`;
- `studio_manager` is recognized as a first-class application role;
- `videographer` is recognized as a first-class application role.

The Team route may be visible to the canonical roles that currently hold `team.read`:

- Founder;
- Studio Manager;
- Client Coordinator.

Server-side permission-aware RPCs remain authoritative even when route visibility is role-based for navigation convenience.

`/prep` and `/safety` remain contained.

No currently contained legacy route is released.

#### 5. Team capability source

The Team page must not infer mutation authority merely from `roles.includes("founder")` or another frontend role test.

A Team capability server function must resolve the authenticated actor's effective canonical permissions using the existing permission-aware database contract.

The UI may derive controlled capability booleans from canonical effective permissions such as:

- `team.read`;
- `team.invite`;
- `team.role.assign`;
- `team.suspend`.

Those capability values are for presentation and control availability only.

Every database operation remains independently authorized by its canonical RPC.

#### 6. Canonical Team directory

Legacy reads from:

- `profiles`;
- `user_roles`;

must be removed from the live Team runtime.

The Team member directory must use:

`team_access_directory(uuid)`

through the authenticated request-scoped Supabase client.

The Team UI may display canonical information returned by that RPC, including:

- member ID;
- member status;
- display name;
- email;
- phone where present;
- joined timestamp;
- assigned canonical role keys and labels;
- active assigned branch names;
- whether at least one organization-wide grant exists.

Canonical organization-member IDs, not auth user IDs, are the Team domain identity.

#### 7. Role administration containment

Slice 7C does not expose role grant or revoke controls in the Team UI.

Current role assignments are read-only.

The existing legacy `setTeamRole` path must be removed from the live runtime.

No normal Team runtime path may write:

- `user_roles`;
- `member_role_grants`;
- `organization_members`.

The Slice 7B RPCs:

- `grant_organization_member_role(...)`;
- `revoke_organization_member_role(...)`;

remain the future canonical mutation boundary but are not surfaced through the Slice 7C UI.

Reason:

`team_access_directory(uuid)` exposes aggregate `assigned_role_keys`, aggregate active `assigned_branch_names`, and a general `organization_wide` flag. It does not expose an exact role-key -> branch-scope mapping.

Slice 7C must therefore not infer that a displayed role is organization-wide merely because some organization-wide grant exists.

A later separately governed role-administration slice must expose or otherwise resolve exact current grant scope before interactive role toggles are released.

#### 8. Canonical invitation directory

Legacy reads from and writes to:

`studio_invites`

must be removed from the live Team/invite runtime.

Authenticated invitation history must use:

`team_invitation_directory(uuid)`.

The directory may display:

- invitation email;
- invited full name;
- invitation status;
- expiry;
- creation timestamp;
- canonical role keys and labels.

The derived `expired` invitation state must be presented as returned by the canonical RPC.

Invitation history must never expose or attempt to reconstruct a raw invitation token.

#### 9. Canonical invitation creation

Invitation creation must use:

`create_organization_invitation(...)`

through the authenticated request-scoped Supabase client.

The server/runtime contract must allow an empty role array.

Canonical permission behavior remains:

- `team.invite` is required to create an invitation;
- any supplied role assignment additionally requires `team.role.assign`.

Therefore:

- Founder may create role-bearing or role-less invitations;
- Studio Manager may create role-less invitations;
- Studio Manager may not create role-bearing invitations;
- Client Coordinator may not create invitations.

These rules are database-enforced and must not be weakened by frontend controls.

The Team UI should show role selection only when the authenticated actor has `team.role.assign`.

When the actor has `team.invite` but not `team.role.assign`, invitation creation remains available without preassigned roles.

#### 10. One-time invitation token handling

The raw invitation token returned by `create_organization_invitation(...)` exists only in that successful creation response.

The Team UI may build and copy:

`/auth?invite=<raw token>`

immediately after successful invitation creation.

The raw token must not be stored in application state longer than required for that response interaction.

The raw token must not be persisted to another application table, local storage, audit payload or invitation-history record.

Invitation history must not offer a later "Copy link" action because canonical storage retains only the SHA-256 token hash.

If a pending link is lost, staff must create a fresh invitation; the canonical creation operation controls supersession of the prior pending invitation.

#### 11. Canonical invitation revocation

Invitation revocation must use:

`revoke_organization_invitation(...)`

through the authenticated request-scoped Supabase client.

No direct table update is permitted.

Only pending invitations should expose the revoke control.

Expired, accepted or revoked invitation history remains non-mutable from the UI except through behavior explicitly permitted by the canonical RPC.

#### 12. Public invitation preview

The public invitation preview must use:

`preview_organization_invitation(text)`.

The preview path must not use:

- `supabaseAdmin`;
- service-role table reads;
- direct `studio_invites` access;
- direct canonical invitation-table access.

The public preview is bearer-token gated and consumes only the safe canonical projection returned by the Slice 7B RPC.

The auth screen may display:

- invited email;
- invited full name;
- organization name;
- canonical role keys and labels;
- invitation expiry where useful.

It must not expose invitation IDs, token hashes, internal member IDs or other hidden access-control evidence.

A role-less invitation is valid and must render correctly without claiming that roles are already assigned.

#### 13. Authenticated invitation acceptance

Invitation acceptance must use:

`accept_organization_invitation(text)`

through the authenticated request-scoped Supabase client.

The application must not:

- write `user_roles`;
- write `organization_members`;
- write `member_role_grants`;
- update invitation state directly;
- use service-role bypass;
- decide acceptance from user-editable metadata.

The database remains authoritative for:

- authenticated user identity;
- confirmed email requirement;
- invited-email match;
- organization state;
- existing membership state;
- canonical membership creation;
- canonical invitation role grants;
- invitation acceptance state;
- audit evidence.

The auth flow must navigate into the application only after successful canonical invite acceptance.

If acceptance fails, the user remains on the auth/invitation surface and sees the failure instead of being navigated into an apparently successful state.

When signup requires email confirmation and no authenticated session exists yet, the user is instructed to confirm the email and reopen the invitation link.

#### 14. Legacy authority removal from live runtime

After Slice 7C, the six authored runtime files must contain no live Team/invitation authority path using:

- `profiles` for Team membership;
- `user_roles`;
- `studio_invites`;
- `has_role`;
- `supabaseAdmin`.

The legacy database objects themselves are not deleted by Slice 7C.

They remain historical/contained infrastructure until a separate cleanup decision confirms no remaining runtime dependency.

#### 15. Team page presentation boundary

The Team page becomes a canonical access-management surface rather than a hybrid legacy/mock workspace.

The page must remove the legacy/mock Team-role task cards that derive from the Zustand/mock task store.

The canonical Team page may contain:

- Team member directory;
- current canonical role labels;
- branch-scope summary;
- member status;
- invitation creation when `team.invite` is available;
- invitation history when `team.invite` is available;
- invitation revocation when permitted.

Role changes remain visibly read-only in this slice.

The page must not imply that absence of an editable role toggle means the user lacks a canonical role.

#### 16. No database or Production mutation

Slice 7C is application/runtime reconciliation only.

It must not:

- create a migration;
- alter an existing migration;
- alter role-permission mappings;
- write local database fixtures merely to complete the source-code cutover;
- query Production;
- write Production;
- deploy a Production database migration.

Local authenticated runtime fixtures may be used later only under an explicit validation plan and must be disposable.

#### 17. Static acceptance checks

Implementation validation must prove:

- canonical twelve-role `AppRole` vocabulary;
- no role identity `coordinator`;
- no role identity `album`;
- `my_membership` remains the session membership source;
- `/prep` remains contained;
- `/safety` remains contained;
- Team route visibility uses canonical roles;
- Team capability presentation derives from canonical effective permissions;
- Team directory uses `team_access_directory`;
- invitation history uses `team_invitation_directory`;
- invitation creation uses `create_organization_invitation`;
- invitation revocation uses `revoke_organization_invitation`;
- public preview uses `preview_organization_invitation`;
- acceptance uses `accept_organization_invitation`;
- no live runtime reference to `studio_invites`;
- no live runtime reference to `user_roles`;
- no live Team membership read from `profiles`;
- no live Team/invitation `supabaseAdmin`;
- no live Team/invitation `has_role`;
- no Team role-grant toggle UI;
- no invitation-history raw-token copy action;
- no legacy/mock Team-role task cards.

Unrelated domain uses of words such as "album" must not be treated as role-identity defects.

#### 18. Application validation gate

Before Slice 7C may be checkpointed:

- targeted Prettier on the six authored files: PASS;
- targeted ESLint on the six authored files: PASS;
- Production build: PASS;
- TypeScript after normal TanStack route generation: PASS or proven non-regression against the exact pre-Slice-7C baseline if unrelated pre-existing route-generation debt still exists;
- `git diff --check`: PASS;
- authored implementation diff contains only the six approved files;
- `src/routeTree.gen.ts` is restored before commit;
- no migration file is added or modified;
- local database migration history is unchanged.

#### 19. Runtime acceptance gate

Before Slice 7C may be considered fully validated locally, authenticated local runtime behavior should prove the canonical capability boundary where practical.

At minimum:

Founder:

- can read Team directory;
- can read invitation history;
- can create a role-bearing invitation;
- receives the raw token only from successful creation;
- can revoke a pending invitation.

Studio Manager:

- can read Team directory;
- can read invitation history;
- can create a role-less invitation;
- role-bearing invitation attempt remains database-denied;
- no role administration controls are exposed.

Client Coordinator:

- can read Team directory;
- cannot create or revoke invitations;
- no role administration controls are exposed.

Invitation/auth flow:

- valid public token preview succeeds;
- invalid/revoked/accepted/expired token does not produce a valid preview;
- confirmed matching authenticated user can accept;
- wrong/unconfirmed user cannot accept;
- successful acceptance resolves canonical membership;
- no legacy role/invite table mutation occurs.

Disposable local validation evidence must be removed or reset after the runtime smoke.

#### 20. Explicit containment

Slice 7C does not authorize:

- canonical role grant/revoke UI;
- per-role branch-scope editor;
- member suspension/reinstatement UI;
- legacy table deletion;
- `/bookings` scheduling/team/safety mutation UI;
- `/prep` runtime release;
- `/safety` runtime release;
- Stage 10 -> 11 / `Shoot Completed`;
- shoot-day safety evidence;
- payment/KPI changes;
- privacy/consent changes;
- Production database rollout;
- Sprint 10 release.

#### 21. Next boundary

After Slice 7C is implemented, validated and checkpointed, the next Team-access slice may address canonical role administration only after exact role-grant scope can be represented safely.

That later boundary must not infer per-role grant scope from the aggregate Slice 7B Team directory.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 7C implementation checkpoint — Canonical Team Runtime Cutover

Sprint 10 Slice 7C was implemented, locally validated and checkpointed on 2026-08-17.

Implementation commit:

`bc0436817455473f88a6ec04fe37547ef80f67f9` — `feat: cut over team access runtime`

The implementation commit was pushed directly to `architecture-rebuild` and reconciled exactly across local HEAD, `origin/architecture-rebuild` and the actual remote branch.

#### Authored implementation boundary

The Slice 7C implementation commit contains exactly the six files authorized by the technical freeze:

- `src/lib/session.ts`;
- `src/lib/access.ts`;
- `src/lib/team.functions.ts`;
- `src/lib/invites.functions.ts`;
- `src/routes/_authenticated/team.tsx`;
- `src/routes/auth.tsx`.

No Supabase migration was added or modified.

No generated Supabase type file was modified.

`src/routeTree.gen.ts` was generated transiently by the normal TanStack runtime/build process and restored to the pre-Slice-7C checked-in artifact before commit.

#### Canonical runtime cutover completed

The live Team/invitation runtime now consumes the Slice 7B canonical access-control foundation.

Implemented runtime behavior includes:

- canonical twelve-role application vocabulary;
- `client_coordinator` replacing the legacy `coordinator` role identity;
- `album_coordinator` replacing the legacy `album` role identity;
- first-class `studio_manager` and `videographer` application roles;
- authenticated membership resolution through `my_membership(uuid)`;
- Team navigation visibility for Founder, Studio Manager and Client Coordinator;
- Team presentation capabilities derived from canonical effective permissions;
- Team directory reads through `team_access_directory(uuid)`;
- invitation history through `team_invitation_directory(uuid)`;
- invitation creation through `create_organization_invitation(...)`;
- invitation revocation through `revoke_organization_invitation(...)`;
- public bearer-token preview through `preview_organization_invitation(text)`;
- authenticated invitation acceptance through `accept_organization_invitation(text)`;
- one-time raw invitation-link handling only from the successful creation response;
- role-less invitation support;
- read-only canonical role presentation;
- removal of the legacy/mock Team-role task surface.

The six authored runtime files contain no live Team/invitation authority path using:

- `studio_invites`;
- `user_roles`;
- Team membership reads from `profiles`;
- `has_role`;
- `supabaseAdmin`.

Canonical role grant/revoke UI remains intentionally contained.

#### Application validation

Static/application validation passed before checkpointing:

- targeted Prettier on all six authored files: PASS;
- targeted ESLint on all six authored files: PASS;
- Production build: PASS;
- TypeScript after normal TanStack route generation: PASS;
- `git diff --check`: PASS;
- authored implementation boundary: exactly six files;
- no migration change;
- no generated Supabase type change;
- checked-in `src/routeTree.gen.ts` restored before commit.

The implementation commit contains:

- 6 files changed;
- 793 insertions;
- 519 deletions.

#### Authenticated local runtime acceptance

Disposable authenticated local fixtures were used under the explicit Slice 7C runtime validation plan.

Founder validation proved:

- Team navigation and canonical Team directory access;
- invitation-history access;
- all canonical invitation role choices available;
- role-less invitation creation;
- role-bearing Editor invitation creation;
- one-time invitation URL behavior;
- canonical invitation revocation;
- no role-editing controls;
- accepted role-less membership materializes with zero active role grants;
- accepted Editor invitation materializes exactly one active organization-wide `editor` grant.

Studio Manager validation proved:

- Team navigation and canonical Team directory access;
- invitation-history access;
- role-less invitation creation;
- no role selector exposed;
- no role-administration controls exposed;
- canonical invitation revocation;
- revocation records the Studio Manager canonical organization-member ID;
- manager-created invitation retained zero preauthorized roles.

Client Coordinator validation proved:

- Team navigation is visible;
- canonical Team directory is readable;
- no invitation creation surface is exposed;
- no invitation history is exposed;
- no revoke control is exposed;
- no role-administration controls are exposed.

Photographer validation additionally proved:

- Team is absent from navigation;
- direct `/team` access is contained;
- no Team directory or invitation data is disclosed.

#### Invitation and authorization contract validation

The canonical Slice 7B Team pgTAP contract was rerun against the clean post-runtime local database:

- files: 1;
- tests: 42;
- result: PASS.

That regression proves, among other canonical negative cases:

- Client Coordinator invitation denial;
- Client Coordinator role-assignment denial;
- Studio Manager role-bearing invitation denial;
- revoked invitation preview denial;
- unknown-token preview denial;
- unconfirmed-email acceptance denial;
- wrong-email acceptance denial;
- accepted-token replay denial;
- cross-organization mutation denial;
- raw bearer-token audit exclusion;
- final-Founder protection.

A separate transaction-only invitation-preview lifecycle check additionally proved:

- accepted invitation token preview rows: 0;
- expired pending invitation token preview rows: 0;
- valid pending control preview rows: 1.

The lifecycle test rolled back completely.

#### Runtime cleanup and local baseline restoration

All disposable runtime evidence was removed after acceptance.

A full explicit local-only:

`npx supabase db reset --local`

completed successfully and replayed the entire migration chain through:

`20260816221825_sprint10_canonical_team_access_foundation.sql`.

Final local baseline after reset:

- Auth users: 0;
- organization members: 0;
- live role grants: 0;
- organization invitations: 0;
- canonical Little Shots by Hema organization status: `suspended`;
- canonical role catalogue: 12 roles.

The canonical Team pgTAP rerun and the transaction-only lifecycle test both left this clean baseline unchanged.

#### Repository checkpoint

Implementation commit:

`bc0436817455473f88a6ec04fe37547ef80f67f9`

Remote reconciliation after push:

- local HEAD: `bc0436817455473f88a6ec04fe37547ef80f67f9`;
- tracking branch: `bc0436817455473f88a6ec04fe37547ef80f67f9`;
- actual remote branch: `bc0436817455473f88a6ec04fe37547ef80f67f9`;
- divergence: `0 0`.

The implementation worktree was clean before this documentation checkpoint was authored.

#### Production containment

Slice 7C performed no Production database query, write or migration deployment.

No Production application deployment is authorized by this checkpoint.

Legacy database objects remain present and contained; Slice 7C removes them only from the live Team/invitation application authority path.

Canonical role administration remains deferred until exact role-key-to-grant-scope representation can be exposed safely.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 7D technical design freeze — Canonical Role Administration Read Model

Sprint 10 Slice 7D establishes the exact canonical read contract required before interactive Team role administration may be released.

This technical freeze was approved for implementation on 2026-08-17.

Slice 7D is intentionally a database/read-model foundation slice.

It does not release role-administration UI.

#### 1. Relationship to Slice 7B and Slice 7C

Slice 7B established the canonical membership, invitation and role-grant mutation foundation.

Slice 7C cut the Team runtime over to that canonical foundation but deliberately left role assignments read-only because:

`team_access_directory(uuid)`

returns aggregate role keys, aggregate branch names and a general organization-wide indicator.

That aggregate projection does not encode the exact relationship:

`member -> role -> branch scope`.

Slice 7D resolves that ambiguity before any interactive role editor is authorized.

The existing canonical mutation RPCs remain authoritative:

- `grant_organization_member_role(uuid, uuid, text, uuid)`;
- `revoke_organization_member_role(uuid, uuid, text, uuid, text)`.

Slice 7D does not replace or weaken them.

#### 2. Discovery evidence

Canonical `member_role_grants` already stores exact scope at the required grain:

- grant ID;
- organization ID;
- organization-member ID;
- role ID;
- nullable branch ID;
- grant timestamp and grant actor;
- revocation timestamp, actor and reason.

Exact scope semantics are:

- `branch_id IS NULL` = organization-wide grant;
- non-null `branch_id` = grant scoped to that exact branch.

The existing live uniqueness contracts permit:

- one live organization-wide grant for a member/role pair;
- one live grant for each member/role/branch tuple.

An organization-wide grant and branch-scoped grants for the same role may therefore coexist.

Slice 7D must represent the database truth exactly and must not normalize, collapse or infer those grants into a different state.

#### 3. Existing direct-table security boundary remains unchanged

`member_role_grants` remains closed to direct authenticated access.

It retains:

- Row Level Security enabled;
- FORCE ROW LEVEL SECURITY;
- no authenticated table privileges;
- service-role access only.

Slice 7D must not grant authenticated users direct `SELECT`, `INSERT`, `UPDATE` or `DELETE` access to `member_role_grants`.

All role-administration reads introduced by this slice must occur through permission-aware canonical RPCs.

#### 4. Existing role mutation authority remains unchanged

Both existing role-mutation RPCs are `SECURITY DEFINER` functions and independently enforce canonical authorization.

`grant_organization_member_role(...)` already enforces:

- active canonical organization membership;
- `team.role.assign`;
- target active membership in the same organization;
- canonical role existence;
- Founder grants must be organization-wide;
- branch access when branch scoped;
- active/non-deleted branch validity;
- live-grant idempotency;
- sensitive audit evidence.

`revoke_organization_member_role(...)` already enforces:

- active canonical organization membership;
- `team.role.assign`;
- target organization containment;
- canonical role existence;
- exact role/branch live-grant selection;
- revocation reason validation;
- historical grant preservation;
- sensitive audit evidence.

The existing deferred final-Founder protection remains the final database authority.

Slice 7D does not alter these mutation semantics.

#### 5. Current role-assignment permission boundary

The canonical permission matrix currently grants:

`team.role.assign`

only to:

- Founder.

Studio Manager, Client Coordinator and all other canonical roles do not currently hold this permission.

Slice 7D does not alter the role-permission matrix.

No role receives new authority in this slice.

#### 6. Exact live role-grant directory

Slice 7D must introduce:

`team_role_grant_directory(
  p_organization_id uuid,
  p_member_id uuid DEFAULT NULL
)`

The function must be `SECURITY DEFINER` with an empty controlled `search_path`.

It must require:

- an active canonical organization membership for the authenticated actor;
- organization-wide `team.role.assign`.

Failure to satisfy the administrative permission boundary must raise an authorization error rather than silently exposing grant detail.

The function returns live grants only.

Its canonical projection must contain:

- `grant_id uuid`;
- `member_id uuid`;
- `role_key text`;
- `role_label text`;
- `branch_id uuid`;
- `branch_name text`;
- `branch_code text`;
- `organization_wide boolean`;
- `granted_at timestamptz`;
- `granted_by_member_id uuid`.

Projection rules:

- `organization_wide` is true exactly when `branch_id IS NULL`;
- `branch_name` and `branch_code` are null for organization-wide grants;
- branch-scoped grants expose the exact active or historical branch identity referenced by that live grant;
- each live grant is returned as its own row;
- no aggregation of different scopes is permitted.

When `p_member_id` is supplied, the target member must belong to `p_organization_id`.

Cross-organization member IDs must not disclose grant information.

When `p_member_id` is null, all live grant rows within the authorized organization may be returned.

Revoked grants are not part of this operational directory.

Historical role evidence remains available through canonical audit/history mechanisms and is not expanded by this slice.

#### 7. Canonical role-assignment scope catalogue

The existing `role_catalogue()` remains the canonical safe role vocabulary source and is not replaced.

Slice 7D must introduce:

`team_role_scope_catalogue(
  p_organization_id uuid
)`

for the future role-administration UI.

The function must be `SECURITY DEFINER` with an empty controlled `search_path`.

It must require:

- an active canonical organization membership;
- organization-wide `team.role.assign`.

The projection must contain:

- `branch_id uuid`;
- `branch_name text`;
- `branch_code text`;
- `organization_wide boolean`.

The result must contain one synthetic organization-wide option:

- `branch_id = NULL`;
- `branch_name = 'Organization-wide'`;
- `branch_code = NULL`;
- `organization_wide = true`.

It may additionally return only branches that:

- belong to the requested organization;
- are active;
- are not deleted;
- are within the actor's canonical branch scope.

Branch rows use:

- the exact branch ID;
- canonical branch name;
- canonical branch code;
- `organization_wide = false`.

The current canonical Little Shots by Hema local baseline contains zero branch rows.

Slice 7D must not create persistent branches merely to populate this catalogue.

Branch-scoped behavior must be validated using transaction-local test fixtures.

#### 8. Existing branches table access is not widened

The canonical `branches` table currently permits authenticated `SELECT` subject to:

`has_branch_scope(organization_id, id)`.

Slice 7D does not need to remove that existing access contract.

However, future Team role-administration runtime must consume the new role-scope catalogue rather than constructing an administrative scope model from arbitrary direct branch-table reads.

This gives role administration a stable permission-aware server contract without changing unrelated branch consumers.

#### 9. Public RPC privileges

Both new Slice 7D RPCs must explicitly:

- revoke execution from `PUBLIC`;
- revoke execution from `anon`;
- revoke inherited/default authenticated execution before the explicit grant;
- grant `EXECUTE` only to `authenticated` and `service_role`.

Database authorization inside each RPC remains authoritative even though `authenticated` receives execute privilege.

No service-role bypass may be introduced into application runtime code.

#### 10. No schema-table redesign

Slice 7D must not:

- add columns to `member_role_grants`;
- modify its unique indexes;
- rewrite existing historical grants;
- collapse organization-wide and branch grants;
- modify the canonical role catalogue;
- alter permission mappings;
- change Founder coverage triggers;
- modify invitation behavior;
- modify Team membership lifecycle behavior.

The existing exact grant rows remain the source of truth.

#### 11. Migration implementation boundary

Slice 7D may add exactly one new timestamped Supabase migration containing:

- `team_role_grant_directory(...)`;
- `team_role_scope_catalogue(...)`;
- explicit function privileges;
- migration-local validation guards.

No existing migration may be edited.

#### 12. pgTAP implementation boundary

Slice 7D must add one dedicated pgTAP test file:

`supabase/tests/sprint10_team_role_admin_read_model_test.sql`

The dedicated suite must be transaction-local and roll back all fixtures.

At minimum it must prove:

- Founder can read the exact grant directory;
- Founder can read the role-assignment scope catalogue;
- Studio Manager cannot read exact role-grant administration detail;
- Client Coordinator cannot read exact role-grant administration detail;
- organization-wide grant projection is exact;
- branch-scoped grant projection is exact;
- two scopes of the same role remain two independent rows when both exist;
- revoked grants are omitted;
- member filtering returns only the requested same-organization member;
- cross-organization member filtering does not leak grant data;
- active branches are available as assignment scopes;
- inactive/deleted branches are absent from assignment choices;
- the organization-wide synthetic scope is always available to an authorized actor;
- direct authenticated access to `member_role_grants` remains unavailable;
- function execution privileges match the freeze;
- no role-permission mapping changes occur.

#### 13. Generated Supabase types

After the clean local migration is validated, generated Supabase TypeScript must be refreshed.

Expected generated additions are the two new RPC contracts only, subject to generator ordering and any pre-existing stale generated definitions.

The generated file remains:

`src/integrations/supabase/types.ts`.

The generated artifact must be normalized with the repository formatting configuration and audited before replacement.

#### 14. Exact authored implementation boundary

Slice 7D implementation may modify exactly:

- one new timestamped migration under `supabase/migrations/`;
- `supabase/tests/sprint10_team_role_admin_read_model_test.sql`;
- `src/integrations/supabase/types.ts`.

The Sprint Master Register freeze/checkpoint documentation is committed separately from the implementation boundary.

No application runtime file is authorized in Slice 7D.

In particular, Slice 7D must not modify:

- `src/lib/team.functions.ts`;
- `src/routes/_authenticated/team.tsx`;
- `src/lib/access.ts`;
- `src/lib/session.ts`;
- invitation runtime files.

Any additional implementation file requires a new explicit design decision.

#### 15. Validation gate

Before Slice 7D may be checkpointed:

- clean local migration application: PASS;
- dedicated Slice 7D pgTAP: PASS;
- existing Slice 7B canonical Team pgTAP: PASS;
- complete local database regression: PASS;
- `supabase db lint --local`: PASS;
- relevant local security/performance advisor review: no new blocking issue;
- clean `supabase db reset --local`: PASS;
- post-reset dedicated Slice 7D pgTAP: PASS;
- generated Supabase types synchronized from the rebuilt local database;
- generated type formatting: PASS;
- targeted generated-type lint: PASS;
- Production build: PASS;
- TypeScript: PASS or proven exact non-regression if unrelated baseline debt reappears;
- `git diff --check`: PASS;
- implementation diff restricted exactly to the authorized boundary.

#### 16. Security invariants

Slice 7D must preserve:

- server-side permission enforcement;
- organization containment;
- branch containment;
- direct-table denial for canonical role grants;
- final-Founder protection;
- sensitive role-change audit behavior;
- invitation token secrecy;
- no client-controlled authorization metadata;
- no Production mutation.

The new read functions must not return:

- auth-user IDs unless separately authorized by an existing contract;
- token material;
- audit payloads;
- revoked-grant reasons;
- unrelated organization data.

#### 17. Explicit containment

Slice 7D does not authorize:

- interactive role grant UI;
- interactive role revoke UI;
- role scope switching UI;
- bulk role mutation;
- member suspension/reinstatement UI;
- permission-matrix editing;
- branch creation/editing;
- invitation changes;
- legacy table deletion;
- Production database migration;
- Production application deployment;
- Sprint 10 release.

#### 18. Next boundary

After Slice 7D is implemented, validated and checkpointed, a separately frozen Slice 7E may consume:

- `team_access_directory(uuid)`;
- `role_catalogue()`;
- `team_role_grant_directory(...)`;
- `team_role_scope_catalogue(...)`;
- `grant_organization_member_role(...)`;
- `revoke_organization_member_role(...)`

to build the canonical role-administration runtime.

Slice 7E must treat each exact live grant as an independent database fact.

It must not infer role scope from the aggregate Team directory.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.


### Slice 7D implementation checkpoint — Canonical Role Administration Read Model

Sprint 10 Slice 7D is implemented, locally validated, committed and pushed.

Implementation commit:

`bd5bbcfd54abdb26072db5716d618a1576ada81f`

Commit message:

`feat: add canonical role admin read model`

The implementation commit was independently resolved on GitHub after push reconciliation.

#### 1. Scope delivered

Slice 7D establishes the exact canonical read model required before interactive Team role administration may be implemented.

The slice adds:

- an exact live member-role-scope read RPC;
- a permission-aware role-assignment scope catalogue;
- dedicated transaction-local pgTAP coverage;
- synchronized generated Supabase TypeScript definitions.

Slice 7D does not add role-administration UI.

The existing canonical role mutation RPCs remain authoritative and unchanged.

#### 2. Exact implementation boundary

The implementation commit contains exactly three authored files:

- `supabase/migrations/20260817042405_sprint10_team_role_admin_read_model.sql`;
- `supabase/tests/sprint10_team_role_admin_read_model_test.sql`;
- `src/integrations/supabase/types.ts`.

No Team runtime file was modified.

In particular, Slice 7D did not modify:

- `src/lib/team.functions.ts`;
- `src/routes/_authenticated/team.tsx`;
- `src/lib/access.ts`;
- `src/lib/session.ts`;
- invitation runtime files;
- checked-in route-tree source.

#### 3. Canonical exact live role-grant directory

Slice 7D introduces:

`team_role_grant_directory(
  p_organization_id uuid,
  p_member_id uuid DEFAULT NULL
)`

The RPC is:

- `STABLE`;
- `SECURITY DEFINER`;
- configured with `search_path = ''`;
- executable by `authenticated` and `service_role`;
- not executable by `anon` or `PUBLIC`;
- internally authorized using canonical active membership and `team.role.assign`.

The exact live grant projection contains:

- `grant_id`;
- `member_id`;
- `role_key`;
- `role_label`;
- `branch_id`;
- `branch_name`;
- `branch_code`;
- `organization_wide`;
- `granted_at`;
- `granted_by_member_id`.

The projection preserves exact database truth.

Organization-wide and branch-scoped grants for the same role remain independent live rows.

Revoked grants are excluded from the operational directory.

Optional member filtering is organization-contained.

A cross-organization member ID does not disclose grant information.

#### 4. Canonical role-assignment scope catalogue

Slice 7D introduces:

`team_role_scope_catalogue(
  p_organization_id uuid
)`

The RPC is:

- `STABLE`;
- `SECURITY DEFINER`;
- configured with `search_path = ''`;
- executable by `authenticated` and `service_role`;
- not executable by `anon` or `PUBLIC`;
- internally authorized using canonical active membership and `team.role.assign`.

The catalogue returns one synthetic organization-wide scope:

- `branch_id = NULL`;
- `branch_name = 'Organization-wide'`;
- `branch_code = NULL`;
- `organization_wide = true`.

It additionally exposes only assignment-eligible branch scopes that are:

- in the requested organization;
- active;
- not deleted;
- within canonical actor branch scope.

The canonical local Little Shots by Hema baseline remains branchless.

Branch behavior was proven using transaction-local fixtures rather than persistent local branch data.

#### 5. Existing role authority preserved

The canonical permission matrix remains unchanged.

`team.role.assign` remains granted only to:

- Founder.

Studio Manager, Client Coordinator and all other canonical roles remain without role-assignment authority.

Slice 7D introduces no permission widening.

#### 6. Direct role-grant table containment preserved

`member_role_grants` remains inaccessible to authenticated application users through direct table operations.

Local security verification confirmed:

- RLS enabled;
- FORCE RLS enabled;
- authenticated `SELECT` unavailable;
- authenticated `INSERT` unavailable;
- authenticated `UPDATE` unavailable;
- authenticated `DELETE` unavailable.

Role administration continues to cross canonical server-side function boundaries only.

#### 7. Existing mutation semantics preserved

Slice 7D does not alter:

- `grant_organization_member_role(...)`;
- `revoke_organization_member_role(...)`.

Existing mutation semantics remain authoritative for:

- active organization membership;
- `team.role.assign`;
- target organization containment;
- exact branch scope;
- Founder organization-wide constraints;
- active branch validation;
- historical grant retention;
- sensitive audit evidence;
- deferred final-Founder protection.

#### 8. Dedicated Slice 7D pgTAP evidence

Dedicated test file:

`supabase/tests/sprint10_team_role_admin_read_model_test.sql`

Final plan:

`21`

Final result:

`Files=1, Tests=21, Result: PASS`

The suite proves at minimum:

- Founder can read exact live role grants;
- Founder can read assignment scopes;
- Studio Manager cannot read role-administration detail;
- Client Coordinator cannot read role-administration detail;
- organization-wide grant representation is exact;
- branch-scoped grant representation is exact;
- organization-wide and branch-scoped instances of the same role remain independent;
- revoked grants are excluded;
- same-organization member filtering is exact;
- cross-organization member filtering does not leak;
- active branches are eligible scopes;
- inactive branches are excluded;
- deleted branches are excluded;
- the organization-wide synthetic scope is present;
- authenticated direct grant-table reads remain unavailable;
- RPC ACLs match the freeze;
- both new functions remain `STABLE SECURITY DEFINER`;
- `team.role.assign` remains Founder-only.

All dedicated fixtures are transaction-local and roll back.

#### 9. Existing canonical Team regression

Existing canonical Team access suite:

`supabase/tests/sprint10_canonical_team_access_test.sql`

Final result:

`Files=1, Tests=42, Result: PASS`

Slice 7D therefore preserves the Slice 7B invitation, acceptance, role mutation and Founder safety contracts.

#### 10. Complete database regression

The full local database test suite completed successfully after Slice 7D:

`Files=16, Tests=1083, Result: PASS`

No local database regression was introduced.

#### 11. Database lint

Pre-reset local database lint:

`PASS`

Post-reset local database lint:

`PASS`

Observed result:

`No schema errors found`

No Slice 7D PL/pgSQL typing or parser error remains.

#### 12. Local security and performance review

Because Slice 7D explicitly prohibits Production database access, remote Supabase project advisors were not queried.

Equivalent relevant checks were performed against the rebuilt local PostgreSQL schema.

Security verification confirmed:

- both RPCs are `SECURITY DEFINER`;
- both RPCs are `STABLE`;
- both RPCs use an empty controlled `search_path`;
- `PUBLIC` execute is revoked;
- `anon` execute is revoked;
- `authenticated` execute is present;
- `service_role` execute is present;
- direct authenticated role-grant table mutation/read remains closed;
- `team.role.assign` remains Founder-only.

Supporting indexes remain present for:

- live member grant lookup;
- organization-wide live grant uniqueness;
- branch-scoped live grant uniqueness;
- grant primary-key lookup;
- branch organization lookup;
- branch primary-key lookup;
- organization-member organization/status/user lookup.

No new blocking local security or performance issue was identified.

#### 13. Clean rebuild evidence

A complete:

`supabase db reset --local`

successfully rebuilt the local database from zero through the Slice 7D migration.

The only reset warning was the established missing optional:

`supabase/seed.sql`

warning.

After the clean rebuild:

- Slice 7D dedicated pgTAP: `21/21 PASS`;
- Slice 7B canonical Team pgTAP: `42/42 PASS`;
- database lint: `PASS`.

The final canonical local baseline remained:

- auth users: `0`;
- organization members: `0`;
- live role grants: `0`;
- invitations: `0`;
- canonical organization branches: `0`;
- canonical organization status: `suspended`.

#### 14. Generated Supabase TypeScript synchronization

`src/integrations/supabase/types.ts`

was regenerated from the rebuilt local Supabase database.

A semantic comparison proved that the regenerated public function contract:

- added `team_role_grant_directory`;
- added `team_role_scope_catalogue`;
- removed no existing public RPC;
- changed no existing public RPC contract.

The apparent whole-file generator formatting churn was audited and proven to be formatting-only.

The final committed generated-type diff was deliberately reduced to the exact synchronized RPC additions:

`24 insertions, 0 deletions`

The final generated type SHA256 before commit was:

`c331d8c9849f89730516574683d98fb222a69ad000c8985aa43f15b75100245c`

#### 15. Application validation

Targeted generated-type ESLint:

`PASS`

Production build:

`PASS`

TypeScript:

`PASS`

`git diff --check`:

`PASS`

Observed final status codes:

- targeted ESLint: `0`;
- Production build: `0`;
- TypeScript: `0`;
- diff integrity: `0`.

The production build emitted existing TanStack/Nitro dependency and deprecation warnings, including existing `createServerFn().inputValidator()` deprecation notices.

Those warnings were non-blocking and outside the Slice 7D authored boundary.

The build completed successfully.

#### 16. Route-tree containment

The production build transiently regenerated:

`src/routeTree.gen.ts`

The generated route tree was not authored as part of Slice 7D.

It was restored after TypeScript validation.

Final frozen route-tree SHA256:

`f47247f5c4e45f1ab228320898c49aa4952e8ee95044130baed6e7267b982302`

The final Slice 7D implementation commit therefore contains no route-tree modification.

#### 17. Git implementation checkpoint

Technical freeze commit:

`aaaa722fae9e93746dc87d2dd93a3509e5602148`

`docs: freeze sprint 10 slice 7d`

Implementation commit:

`bd5bbcfd54abdb26072db5716d618a1576ada81f`

`feat: add canonical role admin read model`

Implementation push reconciliation proved:

- expected SHA = implementation SHA;
- local SHA = implementation SHA;
- tracking SHA = implementation SHA;
- actual remote SHA = implementation SHA;
- divergence = `0 0`;
- worktree clean.

The implementation commit was independently resolved through the GitHub connector after push.

#### 18. Production containment

Slice 7D performed no:

- Production Supabase migration;
- Production database read;
- Production database write;
- Production advisor query;
- Production application deployment;
- service-role application bypass.

All database implementation and acceptance evidence was local.

#### 19. Slice 7D completion boundary

Slice 7D establishes the exact role-administration read-model foundation only.

It does not release:

- interactive role grant controls;
- interactive role revoke controls;
- role-scope switching UI;
- member suspension/reinstatement UI;
- permission-matrix editing;
- branch administration.

The existing Team runtime remains read-only for canonical role assignment.

#### 20. Next governed boundary

A separately frozen Slice 7E may now consume:

- `team_access_directory(uuid)`;
- `role_catalogue()`;
- `team_role_grant_directory(...)`;
- `team_role_scope_catalogue(...)`;
- `grant_organization_member_role(...)`;
- `revoke_organization_member_role(...)`

to implement canonical Team role administration.

Slice 7E must continue to treat each live member-role-scope grant as an independent database fact.

It must not infer exact role scope from aggregate Team-directory arrays.

Founder safety, organization containment, branch containment, permission enforcement and audit invariants remain authoritative.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.


### Slice 7E technical design freeze — Canonical Role Administration Runtime

Sprint 10 Slice 7E releases the first governed interactive runtime for canonical Team role administration.

This technical design was frozen on 2026-08-17.

Slice 7E consumes the canonical database contracts established by Slice 7B and Slice 7D.

It does not redesign role storage, permissions, membership lifecycle or invitation semantics.

#### 1. Relationship to prior Team slices

Slice 7B established:

- canonical organization membership;
- canonical invitation lifecycle;
- exact member-role-grant storage;
- role grant mutation;
- role revoke mutation;
- Founder coverage protection;
- role-change audit evidence.

Slice 7C cut the Team application runtime over to canonical membership and invitations.

Slice 7C deliberately kept current role assignments read-only.

Slice 7D then established the missing exact administrative read model:

- `team_role_grant_directory(...)`;
- `team_role_scope_catalogue(...)`.

Slice 7E may now expose interactive grant and revoke controls because the runtime no longer needs to infer exact role scope from aggregate Team-directory arrays.

#### 2. Discovery evidence

The current Team server runtime exposes only:

- `getTeamCapabilities`;
- `listTeam`.

`listTeam` consumes:

`team_access_directory(uuid)`

and therefore returns aggregate:

- role keys;
- role labels;
- branch names;
- organization-wide presence.

The current Team route consumes that aggregate projection for read-only display.

No application runtime currently invokes:

- `team_role_grant_directory(...)`;
- `team_role_scope_catalogue(...)`;
- `grant_organization_member_role(...)`;
- `revoke_organization_member_role(...)`.

The current Team route explicitly labels role editing as contained.

Slice 7E removes that intentional UI containment only for an actor who possesses canonical:

`team.role.assign`.

#### 3. Database authority remains unchanged

Slice 7E introduces no new database authorization rule.

The following existing RPCs remain authoritative:

`team_role_grant_directory(
  p_organization_id uuid,
  p_member_id uuid DEFAULT NULL
)`

`team_role_scope_catalogue(
  p_organization_id uuid
)`

`grant_organization_member_role(
  p_organization_id uuid,
  p_member_id uuid,
  p_role_key text,
  p_branch_id uuid DEFAULT NULL
)`

`revoke_organization_member_role(
  p_organization_id uuid,
  p_member_id uuid,
  p_role_key text,
  p_branch_id uuid DEFAULT NULL,
  p_reason text DEFAULT 'Role removed'
)`

The application must not duplicate these RPCs' security decisions as trusted client authorization.

Client-side capability checks are presentation controls only.

Database authorization remains final.

#### 4. Existing role-assignment authority remains unchanged

The canonical permission matrix currently grants:

`team.role.assign`

only to:

- Founder.

Slice 7E does not grant Studio Manager, Client Coordinator or any other role new role-administration authority.

The Team route may show role-administration controls only when:

`getTeamCapabilities().canAssignRoles === true`.

A client-side control being hidden or visible is not itself authorization.

Every administrative database read and mutation remains protected independently by the canonical RPC.

#### 5. Existing authenticated server boundary remains authoritative

All new Slice 7E Team server functions must continue to use:

`requireSupabaseAuth`

and the request-scoped authenticated Supabase client.

They must continue to use the configured publishable key plus the authenticated user's bearer token.

Slice 7E must not introduce:

- a service-role application client;
- a secret-key browser client;
- direct Postgres credentials;
- client-controlled authorization metadata.

The organization identifier remains server-owned:

`ORGANIZATION_ID`.

No Slice 7E server function may accept an organization ID from browser input.

#### 6. Team capability contract extension

Slice 7E may extend:

`TeamCapabilities`

with:

`actorMemberId: string | null`

The existing booleans remain unchanged:

- `canRead`;
- `canInvite`;
- `canAssignRoles`;
- `canSuspend`.

`getTeamCapabilities` may resolve the actor's canonical member ID through:

`current_organization_member(ORGANIZATION_ID)`.

This value exists only to keep the current browser session coherent when an authorized Founder modifies their own role grants.

It is not used to authorize role mutation.

#### 7. Canonical role-administration read bundle

`src/lib/team.functions.ts`

must introduce one authenticated GET server function:

`getTeamRoleAdministration`

It returns one normalized object containing:

- canonical role vocabulary;
- exact live role grants;
- currently assignable scopes.

The server function must consume:

`role_catalogue()`

`team_role_grant_directory(ORGANIZATION_ID)`

`team_role_scope_catalogue(ORGANIZATION_ID)`

The two administrative read RPCs remain responsible for enforcing `team.role.assign`.

If the actor is not authorized, the server function must fail rather than return partial administrative state.

#### 8. Runtime role vocabulary type

Slice 7E must define a runtime role option projection equivalent to:

`TeamRoleOption`

with:

- `key: string`;
- `label: string`;
- `description: string | null`;
- `sortOrder: number`.

The role-administration editor must consume this canonical `role_catalogue()` projection.

It must not derive its editable role vocabulary from:

- aggregate member role arrays;
- `roleLabels`;
- `appRoles`;
- hard-coded UI role lists.

The existing invitation UI may continue using its existing role vocabulary in this slice.

Invitation behavior is not part of Slice 7E.

#### 9. Exact live grant runtime type

Slice 7E must define a normalized exact grant projection equivalent to:

`TeamRoleGrantRow`

with:

- `grantId: string`;
- `memberId: string`;
- `roleKey: string`;
- `roleLabel: string`;
- `branchId: string | null`;
- `branchName: string | null`;
- `branchCode: string | null`;
- `organizationWide: boolean`;
- `grantedAt: string`;
- `grantedByMemberId: string | null`.

The runtime must normalize nullable database values defensively.

Each returned row is one independent live grant fact.

No grouping may convert several exact grants into one mutation target.

#### 10. Assignment-scope runtime type

Slice 7E must define a normalized scope projection equivalent to:

`TeamRoleScopeRow`

with:

- `branchId: string | null`;
- `branchName: string`;
- `branchCode: string | null`;
- `organizationWide: boolean`.

The assignment UI must consume this projection directly.

It must not construct administrative scope choices from:

- `member.branchNames`;
- aggregate Team-directory state;
- arbitrary client branch assumptions.

#### 11. Grant server function

`src/lib/team.functions.ts`

must introduce one authenticated POST server function:

`grantTeamRole`

Its browser input contract is:

- `memberId: uuid`;
- `roleKey: canonical-format role key`;
- `branchId: uuid | null`.

The server function must use the current TanStack Start:

`.validator(...)`

API.

It must not introduce new `.inputValidator(...)` usage.

The validator may reject malformed transport input.

It must not decide whether:

- the actor is allowed to assign roles;
- the target member belongs to the organization;
- the target member is active;
- the role exists canonically;
- the requested branch is assignable;
- Founder may receive the requested scope.

Those decisions remain database-authoritative.

The handler calls:

`grant_organization_member_role(...)`.

For organization-wide assignment:

`p_branch_id`

must resolve to SQL `NULL` / the existing default-null contract.

The handler returns the canonical grant ID.

#### 12. Revoke server function

`src/lib/team.functions.ts`

must introduce one authenticated POST server function:

`revokeTeamRole`.

It uses the same exact mutation identity:

- member ID;
- role key;
- nullable branch ID.

It must use:

`.validator(...)`.

The handler calls:

`revoke_organization_member_role(...)`.

The revocation reason must be server-owned rather than browser-controlled.

Slice 7E freezes the application reason as:

`Role removed from Team role administration`

If the canonical revoke RPC returns false because the exact live grant no longer exists, the server wrapper must return a controlled failure such as:

`This role grant is no longer active.`

The application must not silently report success for a stale revoke.

#### 13. No optimistic authorization state

Role grant and revoke mutations must not optimistically rewrite canonical role state in the browser.

After successful mutation, the runtime must refetch authoritative server state.

This prevents the UI from temporarily representing a grant state that:

- failed database validation;
- violated Founder protection;
- raced another administrator action;
- referenced a stale exact scope.

Canonical database state wins.

#### 14. Query model

Slice 7E may add a React Query entry:

`["team-role-admin"]`

enabled only when:

- Team read access is present; and
- `canAssignRoles === true`.

The query consumes:

`getTeamRoleAdministration`.

The existing:

`["team"]`

query remains the normal aggregate Team directory.

The aggregate directory remains useful for compact member summaries.

It must not be used as the mutation source of truth.

#### 15. Post-mutation invalidation

After a successful role grant or revoke, the client must invalidate at least:

- `["team-role-admin"]`;
- `["team"]`;
- `["team-capabilities"]`.

This ensures:

- exact live grants refresh;
- aggregate role/branch summary refreshes;
- actor permissions refresh if the current actor changed their own role.

No invitation query invalidation is required solely because a member role grant changed.

#### 16. Self-role mutation coherence

When the mutation target:

`memberId`

equals:

`actorMemberId`

the client must refresh the browser session after the successful authoritative mutation.

A full page reload is authorized for this narrow case.

The purpose is to refresh application-level role-derived navigation and session presentation that otherwise may remain stale until the next authentication state transition.

This reload is a consistency mechanism.

It is not an authorization mechanism.

#### 17. Team route placement

Slice 7E must modify only the existing:

`Studio access`

member area for role administration.

The existing invitation section remains structurally separate.

The existing aggregate member summary remains visible.

For an authorized role administrator, each member card may additionally render an exact role-administration section.

For actors without `canAssignRoles`, the member cards remain read-only.

#### 18. Exact-grant display rule

The administrative section must render live grants from:

`team_role_grant_directory(...)`.

It must not create revoke buttons from:

`member.roles`

or:

`member.branchNames`.

Each grant row must have a stable key:

`grantId`.

Each row must display:

- canonical role label;
- exact scope;
- an explicit remove action.

Organization-wide scope must display as:

`Organization-wide`.

A branch grant should display canonical branch name and code when available.

#### 19. Independent-scope invariant

An organization-wide grant and a branch-scoped grant for the same member and role are independent facts.

Slice 7E must therefore allow the UI to display both simultaneously.

Adding organization-wide access must not automatically delete branch grants.

Adding branch access must not automatically replace organization-wide access.

Removing one scope must not remove another.

There is no synthetic:

`change scope`

mutation in Slice 7E.

Changing scope is represented by explicit canonical grant/revoke operations.

#### 20. Assignment interaction

For an active target member, the role-administration section may expose:

- one role selector;
- one scope selector;
- one Assign action.

The role selector must use the canonical role catalogue.

The scope selector must use the canonical role-scope catalogue.

The scope selector must preserve the distinction between:

- organization-wide;
- exact branch ID.

The browser may use an internal non-UUID sentinel to represent the synthetic organization-wide select value.

That sentinel must be converted to:

`branchId: null`

before crossing the server-function boundary.

#### 21. Exact duplicate handling

Before submitting an assignment, the client may detect whether the exact tuple already exists:

`memberId + roleKey + branchId`.

If the exact live tuple already exists, the Assign control may be disabled and labelled as already assigned.

This is a user-experience optimization only.

The database's live unique indexes and grant RPC remain authoritative for concurrency and idempotency.

A different scope for the same role must not be treated as a duplicate.

#### 22. Founder assignment scope

The canonical Founder role is organization-wide only.

When:

`roleKey === 'founder'`

the UI must offer only the synthetic organization-wide assignment scope.

The client may automatically reset a previously selected branch scope to organization-wide when Founder is chosen.

The canonical grant RPC remains the final enforcement authority.

No client behavior may weaken or replace the Founder database guard.

#### 23. Final-Founder revoke protection

The UI must not attempt to calculate whether a Founder grant is the last live Founder grant.

The deferred database Founder-coverage guard remains authoritative.

If an authorized user attempts to revoke the final Founder grant:

- the database must reject it;
- the client must show the returned error;
- no optimistic grant removal may occur;
- authoritative role state must remain visible after refetch.

This preserves the existing safety invariant without duplicating it in client state.

#### 24. Suspended membership behavior

Canonical new role grants require an active target membership.

The UI must therefore disable new assignment controls when:

`member.status !== 'active'`.

The UI may explain that suspended memberships cannot receive new grants.

Existing exact live grants for a suspended member must still be displayed.

Exact existing grants may still expose their revoke action because canonical revoke semantics operate on the exact same-organization grant record rather than requiring an active target.

Database authority remains final.

#### 25. Active and historical branch behavior

New assignment choices come only from:

`team_role_scope_catalogue(...)`.

Therefore inactive or deleted branches must not appear as assignable choices.

Existing exact live grants may reference a branch that later became inactive or logically deleted.

Those grants remain valid database facts until explicitly revoked.

The UI must still display the exact branch identity returned by:

`team_role_grant_directory(...)`.

If an existing branch-scoped grant's branch ID is absent from the current assignment-scope catalogue, the UI may identify it as a historical/non-assignable branch scope.

It must not silently discard the grant.

#### 26. Role-administration loading and error containment

Failure to load role-administration state must not hide the ordinary Team directory from an actor who still possesses `team.read`.

The normal Team directory and invitation sections retain their existing error boundaries.

The role-administration subsection may show its own localized loading or error state.

Administrative mutation controls must not render against unknown exact grant state.

#### 27. Mutation feedback

Successful grant:

- show a concise success toast;
- refresh authoritative queries.

Successful revoke:

- show a concise success toast;
- refresh authoritative queries.

Failed grant or revoke:

- show the server/database error in the existing controlled toast pattern;
- retain the previously confirmed canonical UI state;
- do not synthesize success.

#### 28. Invitation containment

Slice 7E must not alter:

- invitation creation;
- invitation revocation;
- invitation acceptance;
- invitation token handling;
- invitation one-time link behavior;
- preassigned invitation role behavior.

The existing invitation runtime remains a separate canonical workflow.

No role-administration mutation may be implemented by rewriting invitation records.

#### 29. Static application-role containment

Slice 7E does not redesign:

`src/lib/session.ts`

or the application-wide `AppRole` union.

Existing session/navigation role state remains as-is.

The role editor itself must use canonical role-catalogue data rather than treating the static `AppRole` list as its database authority.

No global role/navigation refactor is authorized in this slice.

#### 30. Access navigation containment

Slice 7E does not modify:

`src/lib/access.ts`.

Existing Team navigation visibility remains unchanged.

Founder retains the existing Founder bypass.

Studio Manager and Client Coordinator retain their existing Team route visibility.

Role-administration controls are independently gated by canonical `team.role.assign`.

#### 31. Exact implementation boundary

After the Slice 7E technical freeze is committed separately, the runtime implementation may modify exactly:

- `src/lib/team.functions.ts`;
- `src/routes/_authenticated/team.tsx`.

No new migration is authorized.

No generated Supabase type change is authorized.

No test file is authorized as an authored implementation file unless a later explicit design decision expands this boundary.

No change is authorized to:

- `src/lib/access.ts`;
- `src/lib/session.ts`;
- `src/lib/invites.functions.ts`;
- `src/routes/auth.tsx`;
- `src/integrations/supabase/auth-middleware.ts`;
- `src/integrations/supabase/types.ts`;
- existing migrations;
- database permission mappings.

`src/routeTree.gen.ts` may be transiently regenerated by the production build but must not remain in the implementation commit unless an explicit route change is separately approved.

#### 32. No database migration or generated-type work

Slice 7E consumes existing database contracts only.

Therefore implementation must not:

- create a Supabase migration;
- edit a Supabase migration;
- regenerate `src/integrations/supabase/types.ts`;
- modify role tables;
- modify member-role-grant tables;
- modify function ACLs;
- alter RLS;
- alter Founder triggers.

Any need for a database change stops Slice 7E and requires a new technical decision.

#### 33. TanStack server-function convention

New Slice 7E server functions must use the current:

`.validator(...)`

server-function validation API.

Slice 7E must not add new:

`.inputValidator(...)`

usage.

Existing deprecated `.inputValidator(...)` calls elsewhere in the application are unrelated baseline debt and are not refactored in this slice.

#### 34. Local runtime acceptance — Founder

With controlled local canonical fixtures, Founder acceptance must prove:

- Team directory loads;
- role administration is visible;
- canonical role options load from `role_catalogue()`;
- canonical scope choices load;
- current exact live grants load;
- one active member can receive an organization-wide role;
- the exact new grant appears after authoritative refetch;
- the aggregate Team summary also reflects the successful grant;
- the exact grant can be revoked;
- the revoked grant disappears after authoritative refetch.

The canonical branchless baseline should expose only:

`Organization-wide`

until branch fixtures are deliberately introduced.

#### 35. Local runtime acceptance — exact branch scope

Using controlled local branch fixtures, acceptance must prove:

- an active, non-deleted branch appears as an assignment choice;
- a branch-scoped role can be granted;
- the exact branch name/code appears on the live grant;
- the same role may coexist organization-wide and branch-scoped;
- both rows remain separately visible;
- revoking the branch-scoped tuple leaves the organization-wide tuple intact.

#### 36. Local runtime acceptance — branch lifecycle

Controlled local acceptance must additionally prove:

- inactive branch choices are not offered for new assignment;
- deleted branch choices are not offered for new assignment;
- an existing live grant referencing a now non-assignable branch remains visible until explicitly revoked.

The runtime must not infer historical grant deletion from scope-catalogue absence.

#### 37. Local runtime acceptance — permission boundaries

Acceptance must prove:

Founder:

- can read exact grants;
- can assign;
- can revoke.

Studio Manager:

- retains ordinary Team directory access;
- retains existing invitation capability;
- does not receive role-administration controls.

Client Coordinator:

- retains ordinary Team directory access;
- does not receive role-administration controls.

A non-Team role must not gain role-administration authority through Slice 7E.

Direct server-function invocation remains protected by the database even if a client attempts to bypass presentation gating.

#### 38. Local runtime acceptance — suspended member

Acceptance must prove for a suspended Team member:

- current exact live grants remain visible to Founder;
- new assignment control is disabled;
- existing live grant removal remains possible where the canonical revoke RPC permits it.

#### 39. Local runtime acceptance — Founder safety

Acceptance must prove:

- Founder role assignment is organization-wide only in the UI;
- a branch-scoped Founder assignment is not offered;
- an attempt to revoke the final Founder is rejected by the database;
- the rejected mutation does not disappear optimistically;
- the final Founder grant remains present after refetch.

#### 40. Local runtime acceptance — self mutation

When an authorized actor mutates a role grant belonging to their own organization-member ID:

- the mutation must complete through the canonical RPC first;
- the browser must then refresh;
- session-derived role/navigation state must be rebuilt from canonical membership.

The browser refresh must never occur before mutation success.

#### 41. Database regression gate

Although Slice 7E authors no SQL, its runtime depends on existing canonical database behavior.

Before checkpointing Slice 7E:

- dedicated Slice 7D read-model pgTAP: PASS;
- existing Slice 7B canonical Team pgTAP: PASS;
- complete local database regression: PASS;
- local database lint: PASS.

If local browser acceptance creates persistent fixtures, a final clean local reset is required.

After the clean reset:

- Slice 7D dedicated pgTAP must still PASS;
- Slice 7B canonical Team pgTAP must still PASS;
- canonical baseline must be restored.

#### 42. Application quality gate

Before Slice 7E implementation may be checkpointed:

- targeted Prettier check for both authored runtime files: PASS;
- targeted ESLint for both authored runtime files: PASS;
- TypeScript `--noEmit`: PASS;
- Production build: PASS;
- no new Slice 7E `inputValidator()` deprecation usage;
- `git diff --check`: PASS;
- generated route-tree changes restored unless separately authorized;
- implementation diff restricted exactly to the two frozen runtime files.

Existing unrelated TanStack/Nitro build warnings may remain only if proven unchanged/non-blocking.

#### 43. No optimistic or bulk role mutation

Slice 7E does not authorize:

- optimistic role mutation;
- bulk role grant;
- bulk role revoke;
- replace-all-roles semantics;
- implicit scope conversion;
- automatic branch-grant cleanup;
- automatic organization-wide-grant cleanup.

Every mutation represents one exact canonical database fact.

#### 44. Security invariants

Slice 7E must preserve:

- authenticated request identity;
- server-owned organization identity;
- organization containment;
- branch containment;
- database `team.role.assign` enforcement;
- direct-table denial;
- Founder organization-wide rule;
- final-Founder protection;
- sensitive role-change audit behavior;
- no service-role browser/runtime bypass;
- no client-controlled authorization claims;
- no role scope inferred from aggregates.

#### 45. Production containment

Slice 7E does not authorize:

- Production database reads for acceptance;
- Production database writes;
- Production database migration;
- Production Supabase advisor queries;
- Production role mutation;
- Production application deployment.

All implementation and acceptance work remains local until a separately governed release boundary.

#### 46. Commit discipline

Slice 7E follows the established three-stage Git discipline:

1. technical design freeze documentation commit;
2. exact two-file runtime implementation commit;
3. implementation checkpoint documentation commit.

Each commit is pushed and reconciled independently.

No pull request is required for the current `architecture-rebuild` branch workflow.

#### 47. Slice 7E completion definition

Slice 7E is complete only when:

- exact canonical live grants are visible to authorized role administrators;
- active members can receive exact canonical role/scope grants;
- exact grants can be revoked independently;
- same-role multi-scope grants remain independent;
- branch assignment choices come only from the canonical scope catalogue;
- suspended members cannot receive new grants;
- Founder safety remains database-authoritative;
- unauthorized Team viewers receive no administrative controls;
- all local regression and application gates pass;
- implementation and checkpoint commits are pushed and reconciled.

Slice 7E does not itself release Sprint 10.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 7E implementation checkpoint — Canonical Role Administration Runtime

Sprint 10 Slice 7E canonical role-administration runtime implementation completed locally and was pushed/reconciled on 2026-08-17.

Implementation commit:

`7384f923e17c918ed6328914ff38bec86434522f`

Commit message:

`feat: add canonical role administration runtime`

The implementation commit directly follows the Slice 7E technical design freeze:

`b7cda8da91ce08b93d5cf12fdd23efba87c5f025`

#### Checkpoint implementation boundary

The runtime implementation modified exactly:

- `src/lib/team.functions.ts`;
- `src/routes/_authenticated/team.tsx`.

Implementation diff:

- `src/lib/team.functions.ts`: 172 additions / 6 deletions;
- `src/routes/_authenticated/team.tsx`: 341 additions / 5 deletions;
- total: 513 additions / 11 deletions.

The reviewed implementation patch SHA-256 was:

`e9c6bd3f8767ab4fea21554c8c6cc780013cae32a86f60aa7b7968197f159539`

The staged implementation patch matched that reviewed patch exactly before commit.

No Slice 7E implementation change was made to:

- `src/lib/session.ts`;
- `src/lib/access.ts`;
- `src/lib/invites.functions.ts`;
- Supabase migrations;
- generated Supabase types;
- database authorization contracts;
- `src/routeTree.gen.ts`.

#### Implemented canonical Team capability extension

`TeamCapabilities` now includes:

`actorMemberId: string | null`

`getTeamCapabilities` resolves the actor member ID through:

`current_organization_member(ORGANIZATION_ID)`

The value is used only for post-success self-role-mutation session coherence.

Canonical permission evaluation remains sourced from:

`effective_permissions(ORGANIZATION_ID)`

No client-provided organization identifier or authorization claim was introduced.

#### Implemented canonical role-administration read bundle

The authenticated Team runtime now exposes:

`getTeamRoleAdministration`

It reads the existing canonical database contracts:

- `role_catalogue()`;
- `team_role_grant_directory(ORGANIZATION_ID)`;
- `team_role_scope_catalogue(ORGANIZATION_ID)`.

The runtime normalizes:

- canonical role options;
- exact live role grants;
- currently assignable canonical scopes.

Administrative reads fail as a complete bundle on an RPC error rather than returning partial role-administration state.

#### Implemented exact role mutations

The authenticated runtime now exposes:

- `grantTeamRole`;
- `revokeTeamRole`.

Both functions use the current TanStack Start:

`.validator(...)`

API.

No new Slice 7E `.inputValidator(...)` usage was introduced.

The browser supplies only transport values:

- member ID;
- role key;
- nullable branch ID.

The server continues to own:

`ORGANIZATION_ID`

and canonical database RPCs remain authoritative for:

- actor authorization;
- organization containment;
- target membership validity;
- canonical role validity;
- branch assignability;
- Founder organization-wide scope;
- final-Founder coverage protection.

The revoke wrapper owns the audit reason:

`Role removed from Team role administration`

A stale exact revoke returns the controlled failure:

`This role grant is no longer active.`

#### Implemented Team role-administration query model

The Team route now loads canonical administrative state through:

`["team-role-admin"]`

only when both:

- Team read access exists; and
- `canAssignRoles === true`.

The ordinary aggregate Team directory remains:

`["team"]`

and remains available independently from the administrative read model.

After a successful exact grant or revoke, authoritative invalidation covers:

- `["team-role-admin"]`;
- `["team"]`;
- `["team-capabilities"]`.

No optimistic canonical role mutation was introduced.

#### Implemented exact-grant interaction semantics

Authorized role administrators can now view each exact live grant independently.

Each administrative grant row is keyed by its canonical:

`grantId`

and preserves its exact scope.

Organization-wide and branch-scoped grants for the same member and role remain independent facts.

The runtime does not introduce:

- replace-all-role semantics;
- synthetic scope conversion;
- automatic branch-grant cleanup;
- automatic organization-wide-grant cleanup;
- bulk role grant or revoke.

Exact duplicate assignment detection is presentation-only; canonical database uniqueness remains authoritative.

The compact aggregate role badge display was deduplicated for presentation only and does not merge or alter exact administrative grant facts.

#### Implemented Founder and membership lifecycle behavior

Founder assignment is presented as organization-wide only.

Selecting Founder constrains assignment to the synthetic organization-wide scope.

The UI does not calculate final-Founder safety.

Final-Founder revocation remains database-authoritative.

Suspended members:

- cannot receive new grants through the assignment controls;
- retain visible exact live grants;
- may have an existing exact grant revoked where the canonical database RPC permits it.

#### Implemented active and historical branch behavior

New branch assignment choices come only from:

`team_role_scope_catalogue(...)`

Inactive or otherwise non-assignable branches therefore do not appear as new assignment choices.

An existing live grant referencing a branch that later becomes non-assignable remains visible from the exact grant directory.

Such a grant is identified in the UI as:

`historical / non-assignable scope`

and remains independently removable through its exact canonical tuple.

#### Invitation and non-administrator containment

Invitation creation, revocation, one-time-link handling and existing invitation-role behavior remain a separate workflow.

Studio Manager retains:

- Team directory access;
- existing invitation capability;
- no role-administration controls.

Client Coordinator retains:

- Team directory access;
- no role-administration controls.

No role-administration authority was granted through static application roles or navigation logic.

#### Local runtime acceptance evidence

Controlled local browser acceptance passed for:

- Founder canonical role and scope reads;
- organization-wide role assignment;
- branch-scoped role assignment;
- same-role organization-wide and branch-scope coexistence;
- exact branch-scope revocation without affecting organization-wide access;
- historical/non-assignable branch-grant visibility and revocation;
- suspended-member assignment containment and exact revoke;
- Studio Manager role-control containment;
- Client Coordinator role-control containment;
- actor self-grant followed by full browser reload;
- actor self-revoke followed by full browser reload;
- successful removal of a non-final Founder;
- database rejection of attempted final-Founder removal with no optimistic disappearance.

The final-Founder rejection left the canonical Founder grant present and the organization valid.

#### Database regression evidence

The final Slice 7E database regression gate passed:

- Slice 7D role-administration read-model pgTAP: 21 tests;
- Slice 7B canonical Team-access pgTAP: 42 tests;
- complete local database suite: 16 files / 1083 tests;
- database lint at warning failure level: PASS.

After regression testing, the local database was reset to the canonical baseline.

The restored baseline contained:

- organization status: `suspended`;
- auth users: 0;
- organization members: 0;
- member-role-grant rows: 0;
- live member-role grants: 0;
- organization invitations: 0;
- branches: 0.

#### Application quality evidence

The corrected final application gate passed:

- targeted Prettier: PASS;
- targeted ESLint: PASS;
- production build: PASS;
- TypeScript `--noEmit` against the build-generated current route tree: PASS;
- no Slice 7E `.inputValidator(...)` usage;
- exactly two Slice 7E `.validator(...)` mutation contracts;
- semantic contract guards: PASS;
- `git diff --check`: PASS;
- exact two-file implementation boundary: PASS.

The production build transiently regenerated:

`src/routeTree.gen.ts`

TypeScript validation passed against that generated route tree.

The generated route tree was then restored exactly to the frozen SHA-256:

`f47247f5c4e45f1ab228320898c49aa4952e8ee95044130baed6e7267b982302`

before implementation commit creation.

Existing unrelated TanStack `.inputValidator(...)`, Rollup/Nitro and chunk-size warnings remained non-blocking baseline warnings outside the Slice 7E implementation boundary.

#### Git reconciliation evidence

The implementation commit was pushed directly to:

`origin/architecture-rebuild`

Post-push reconciliation confirmed:

- local HEAD: `7384f923e17c918ed6328914ff38bec86434522f`;
- local tracking ref: `7384f923e17c918ed6328914ff38bec86434522f`;
- remote branch ref: `7384f923e17c918ed6328914ff38bec86434522f`;
- branch divergence: 0 / 0.

The remote implementation commit contains exactly the two frozen runtime files.

No pull request is required by the current `architecture-rebuild` workflow.

#### Slice 7E checkpoint status

Sprint 10 Slice 7E canonical role-administration runtime is now implemented, locally accepted, regression-tested, quality-gated, committed and remotely reconciled.

This checkpoint does not authorize or record a Production deployment.

No Production database read, write, migration or role mutation was performed as part of Slice 7E acceptance.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Governance correction — Slice 7E deployment containment

This append-only correction was recorded on 2026-08-17 after deployment-containment reconciliation.

The earlier Slice 7E checkpoint correctly states that Slice 7E did not authorize a Production application release and that no Production database read, write, migration or role mutation was performed as part of Slice 7E acceptance.

However, subsequent infrastructure audit established that Git pushes from `architecture-rebuild`, including the Slice 7E commit stack, were automatically deployed by Vercel as Production application deployments because the Vercel project's Production Branch Tracking was configured to `architecture-rebuild` at that time.

No manual `vercel --prod` deployment command was performed as part of Slice 7E acceptance.

The latest automatically created Production deployment from that stack was associated with checkpoint commit:

`e570da0b7715f992edd4cd870437d3dbbaf7324a`

Vercel deployment:

`dpl_varrdvzMrBSfnNVjhwNnF4mrSzAL`

This automatic Vercel application deployment did not constitute approval or closure of Sprint 10 and did not authorize a Production Supabase migration for the later Team-access database work.

Containment was corrected on 2026-08-17:

- Vercel Production Branch Tracking was changed from `architecture-rebuild` to `main`;
- the corrected Production Branch value `main` was independently verified through the Vercel project API;
- `architecture-rebuild` received branch-specific Vercel Preview environment overrides for `SUPABASE_PROJECT_ID`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`;
- those branch-specific Preview variables target the isolated Supabase `architecture-rebuild` Preview project `hincwmxebwfpoijzwyfz`;
- the Vercel configuration correction itself triggered no deployment;
- the existing Vercel Production deployment was not redeployed or replaced as part of containment;
- Git `main` was not merged or modified;
- Supabase Production was not merged or mutated as part of this containment work.

The isolated Supabase Preview branch was independently reconciled for the Team-access database foundation before application Preview deployment testing. Production Supabase remained separately contained.

This correction supersedes only the earlier deployment-occurrence wording. It does not change the Slice 7E implementation acceptance result, does not convert Sprint 10 into a Production release, and does not authorize a Git-main or Supabase-main merge.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

### Slice 7F technical design freeze — Canonical Booking Schedule Read Surface

Sprint 10 Slice 7F is a deliberately narrow application read-surface slice.

Its purpose is to bring authoritative Sprint 10 shoot-schedule evidence into the existing canonical `/bookings` workspace without introducing scheduling mutation controls or widening any database authorization boundary.

#### 1. Discovery basis

Read-only discovery on 2026-08-17 established that:

- `/bookings` already reads canonical `bookings`, accepted quotation evidence, booking journey state and transition history;
- the current Bookings runtime does not read any Sprint 10 operational table;
- the current `/bookings` copy still describes the older Sprint 8 read-only boundary;
- generated Supabase types already contain all Sprint 10 schedule table and RPC contracts;
- local Supabase migration history is current through `20260817042405_sprint10_team_role_admin_read_model.sql`;
- `/prep` and `/safety` remain deliberately contained and still depend on legacy/mock runtime state;
- the repository worktree was clean before this freeze.

#### 2. Exact Slice 7F implementation boundary

Slice 7F implementation may modify exactly:

- `src/lib/booking.functions.ts`;
- `src/routes/_authenticated/bookings.tsx`.

No other authored application file is part of Slice 7F.

`src/routeTree.gen.ts` may be regenerated transiently by normal TanStack build tooling but must be restored before commit unless an independently approved route-definition change is required.

#### 3. Canonical scheduling evidence

The existing authoritative scheduling source remains:

`public.booking_shoot_schedules`

The runtime must not introduce:

- a parallel booking date field;
- mutable booking schedule state;
- legacy Zustand schedule truth;
- inferred reservation status;
- client-computed schedule versioning.

Every schedule row remains immutable canonical evidence.

The current authoritative schedule for a booking is the row with the highest canonical `schedule_version`.

Historical schedule rows remain visible as immutable lineage.

#### 4. Schedule read authorization

Slice 7F introduces no new database permission.

Direct authenticated schedule reads continue to rely on the existing database boundary:

- `booking.read`;
- booking-derived branch scope;
- forced RLS on `booking_shoot_schedules`.

The application must not use:

- service-role access;
- secret-key access;
- direct Postgres credentials;
- client-owned authorization claims.

The request-scoped authenticated Supabase client remains authoritative.

#### 5. Booking workspace server contract

`listBookingWorkspace()` may be extended to include canonical:

`booking_shoot_schedules`

for the bookings already visible through the existing workspace query.

The server function must continue to:

- use `requireSupabaseAuth`;
- use server-owned `ORGANIZATION_ID`;
- query only booking IDs already resolved through the canonical booking read path;
- preserve existing booking, quotation, journey, lead and family behavior.

The schedule query must not call a mutation RPC.

#### 6. Schedule runtime projection

The application may consume the generated canonical schedule row type directly or expose an equivalent normalized runtime projection.

At minimum the UI may represent:

- schedule ID;
- booking ID;
- schedule version;
- predecessor schedule ID;
- schedule state;
- scheduled start;
- scheduled end;
- timezone;
- location type;
- location details;
- reschedule reason;
- recorded timestamp;
- recording member identifier.

No additional derived scheduling fact becomes canonical merely because it is displayed.

#### 7. Current schedule semantics

For each booking:

- zero schedule rows means no canonical shoot plan exists;
- the highest schedule version is the current authoritative schedule tip;
- `proposed` means the date/time is proposed and is not reserved;
- `reserved` means the schedule is authoritative/reserved;
- a later reserved schedule with a predecessor represents immutable reschedule evidence.

The UI must not label a `proposed` schedule as confirmed or reserved.

#### 8. Schedule-history semantics

The Bookings workspace may render complete visible schedule history ordered by canonical schedule version.

History must preserve:

- version order;
- proposal/reservation state;
- predecessor lineage;
- scheduled times;
- location evidence;
- reschedule reason where canonically present;
- recorded time.

The UI must not silently collapse historical schedule rows into one mutable event.

#### 9. No scheduling mutations in Slice 7F

Although the database already exposes:

- `propose_booking_shoot_schedule(...)`;
- `reschedule_booking_shoot(...)`;

Slice 7F must not invoke either RPC.

Slice 7F introduces no:

- proposal form;
- reschedule form;
- schedule edit control;
- client-side scheduling permission model;
- optimistic schedule mutation.

A later separately frozen slice may expose those mutations.

#### 10. No journey mutations in Slice 7F

Slice 7F must not invoke:

- `confirm_booking_after_advance(...)`;
- `start_pre_shoot_preparation(...)`;
- `mark_booking_shoot_scheduled(...)`;
- any booking-team mutation;
- any preparation-item mutation;
- any safety-readiness mutation;
- any safety sign-off mutation.

The journey remains read-only in Slice 7F.

#### 11. Preparation containment

Slice 7F must not add `booking_preparations` or `booking_preparation_items` to the generic Booking workspace.

Preparation evidence remains governed by `prep.read`, which is narrower than ordinary `booking.read`.

The `/prep` route remains contained.

#### 12. Safety containment

Slice 7F must not read or display:

- `booking_safety_readiness`;
- `booking_safety_signoffs`;
- safety-state details;
- comfort-state details;
- formal sign-off details.

Restricted safety/comfort evidence must not leak into the broad Booking workspace.

The `/safety` route remains contained.

#### 13. Team-assignment containment

Slice 7F must not add booking-team assignment UI or external-creative presentation.

Canonical booking staffing remains a separate later runtime boundary.

No booking-team assignment mutation is authorized.

#### 14. Existing Bookings copy correction

The current `/bookings` runtime contains explanatory wording tied to the older Sprint 8 boundary.

Slice 7F may update that copy only as needed to accurately describe the current canonical state.

Updated wording must preserve these truths:

- booking and journey evidence are canonical;
- schedule evidence is canonical when present;
- `Advance Pending` is not proof of payment;
- a proposed schedule is not a reservation;
- journey advancement remains controlled by dedicated database operations;
- Slice 7F itself exposes no journey or schedule mutation.

#### 15. Empty-state behavior

The existing no-booking empty state remains valid.

For a booking with no schedule evidence, the Bookings UI must show an explicit neutral state equivalent to:

`No canonical shoot plan recorded`

rather than inventing a date or falling back to legacy booking data.

#### 16. Application validation gate

Before Slice 7F implementation may be checkpointed:

- targeted Prettier on the two authored files: PASS;
- targeted ESLint on the two authored files: PASS;
- production build: PASS;
- TypeScript `--noEmit`: PASS after normal route generation;
- `git diff --check`: PASS;
- implementation diff restricted exactly to the two frozen authored files;
- no migration file added or modified;
- generated Supabase types unchanged;
- checked-in route tree restored before commit.

#### 17. Runtime acceptance gate

Controlled local authenticated acceptance must prove at minimum:

- `/bookings` still renders canonical booking and journey data;
- a booking with no schedule shows the explicit no-schedule state;
- a Stage 7 proposed schedule is displayed as proposed / not reserved;
- a reserved schedule is displayed as reserved;
- schedule version history renders in canonical order;
- reschedule lineage remains visible rather than overwritten;
- no scheduling mutation control is exposed;
- no journey mutation control is exposed;
- no preparation evidence is exposed;
- no restricted safety evidence is exposed;
- no legacy Zustand booking schedule becomes authoritative.

Disposable local runtime evidence must be removed or reset after acceptance.

#### 18. Database regression boundary

Slice 7F authors no SQL.

Before checkpointing:

- existing Sprint 10 scheduling pgTAP remains PASS;
- complete local database regression remains PASS;
- local database lint remains PASS;
- local migration history remains unchanged.

If runtime fixtures are created, the final local baseline must be restored.

#### 19. Preview-only deployment boundary

Slice 7F remains non-Production.

After the implementation and checkpoint commits are pushed to `architecture-rebuild`:

- Vercel must create Preview deployments only;
- `architecture-rebuild` must continue using its branch-specific isolated Supabase Preview configuration;
- no Vercel Production deployment is authorized;
- no Production Supabase read, write or migration is authorized;
- Git `main` is not modified;
- Supabase `main` is not merged.

#### 20. Explicit Slice 7F containment

Slice 7F does not authorize:

- schedule proposal or reschedule UI;
- booking confirmation UI;
- payment mutation;
- preparation runtime cutover;
- safety runtime cutover;
- booking-team runtime cutover;
- Stage 8 -> 9 mutation UI;
- Stage 9 -> 10 mutation UI;
- Stage 10 -> 11 implementation;
- capacity or overlap logic;
- external calendar integration;
- any database schema change;
- Sprint 10 release.

#### 21. Commit discipline

Slice 7F follows the established three-stage discipline:

1. technical design freeze documentation commit;
2. exact two-file implementation commit;
3. implementation checkpoint documentation commit.

Each commit is pushed and reconciled independently.

Every `architecture-rebuild` push must be verified as a Vercel Preview deployment before proceeding to the next governed step.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

## Sprint 10 Slice 7F — Canonical Booking Schedule Read Surface — Implementation Checkpoint

### Implementation evidence

Slice 7F implementation is complete and remains non-Production.

- Freeze commit: `cf2f620875883131a94a0a5eef600bbf1c813386`
- Implementation commit: `f834979359d16ae087c25ca29f8cba3fd3e021f4`
- Implementation commit message: `feat: add canonical booking schedule read surface`
- Implementation parent: `cf2f620875883131a94a0a5eef600bbf1c813386`
- Branch: `architecture-rebuild`

GitHub reconciliation confirmed the implementation is exactly one commit ahead of the Slice 7F freeze and contains only:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

No migration, generated Supabase type, access-control, preparation, safety, team-assignment or generated route-tree file is part of the implementation commit.

### Delivered runtime scope

`listBookingWorkspace()` now includes canonical `booking_shoot_schedules` rows for the visible canonical booking IDs.

The authenticated `/bookings` surface now:

- treats the highest canonical `schedule_version` as the current schedule tip;
- renders `proposed` explicitly as proposed / not reserved;
- renders `reserved` as authoritative reserved schedule evidence;
- shows complete immutable schedule history ordered by canonical version;
- preserves predecessor lineage;
- preserves reschedule reason where present;
- shows the explicit neutral empty state `No canonical shoot plan recorded`;
- does not infer a shoot date from legacy booking state;
- corrects stale Sprint 8 explanatory copy without introducing a new journey mutation model.

Slice 7F adds no schedule proposal, reschedule, payment, booking-confirmation, journey-transition, preparation, safety, team-assignment or external-creative mutation UI.

### Controlled authenticated runtime acceptance

Disposable local authenticated fixtures covered all required schedule states.

Acceptance proved:

1. No-schedule booking:
   - canonical booking and journey rendered;
   - zero schedule rows;
   - explicit `No canonical shoot plan recorded` state;
   - no legacy date inference.

2. Proposed-only booking:
   - canonical proposal version 1 rendered;
   - state displayed as proposed / not reserved;
   - proposed state did not imply reservation or booking confirmation.

3. Reserved/history booking:
   - proposal v1 preserved;
   - changed proposal v2 preserved with predecessor lineage to v1;
   - booking confirmation appended reserved v3 with predecessor lineage to v2;
   - reschedule appended reserved v4 with predecessor lineage to v3;
   - current authoritative tip rendered as reserved v4;
   - reschedule reason `Client requested date change` remained visible;
   - earlier schedule evidence remained immutable.

Authenticated visual acceptance also confirmed:

- no schedule mutation control;
- no general journey-transition control;
- no preparation evidence leakage;
- no restricted safety evidence leakage;
- no booking-team or external-creative runtime leakage;
- no legacy Zustand schedule promoted to canonical truth.

Result: **PASS**

### Disposable fixture cleanup

After authenticated acceptance:

- the Vite development process was stopped;
- generated `src/routeTree.gen.ts` output was restored and excluded from authored changes;
- local Supabase database reset completed successfully;
- disposable fixture counts returned to zero for:
  - `auth.users`;
  - `organization_members`;
  - `families`;
  - `quotations`;
  - `bookings`;
  - `booking_shoot_schedules`.

Result: **PASS**

### Database regression gate

Slice 7F authored no SQL.

Validation against the unchanged local migration chain completed successfully:

- dedicated `supabase/tests/sprint10_shoot_schedule_test.sql`: **111/111 PASS**;
- complete local database suite: **1083/1083 PASS** across 16 files;
- `npx supabase db lint --local`: **PASS — No schema errors found**;
- local database reset reapplied the existing migration chain through `20260817042405_sprint10_team_role_admin_read_model.sql`;
- no migration file was added or modified by Slice 7F.

Result: **PASS**

### Application validation gate

Final application validation completed successfully:

- targeted Prettier on the two authored files: PASS;
- targeted ESLint on the two authored files: PASS;
- production build: PASS;
- TypeScript `--noEmit`: PASS after normal TanStack route generation;
- generated `src/routeTree.gen.ts` restored before commit;
- `git diff --check`: PASS;
- implementation boundary restricted exactly to the two frozen authored files;
- generated Supabase types unchanged;
- migration files unchanged.

Result: **PASS**

### Git implementation reconciliation

Controlled push of implementation commit `f834979359d16ae087c25ca29f8cba3fd3e021f4` completed as a fast-forward:

- pre-push remote: `cf2f620875883131a94a0a5eef600bbf1c813386`;
- post-push local HEAD: `f834979359d16ae087c25ca29f8cba3fd3e021f4`;
- post-push tracking ref: `f834979359d16ae087c25ca29f8cba3fd3e021f4`;
- post-push remote ref: `f834979359d16ae087c25ca29f8cba3fd3e021f4`;
- post-push divergence: `0 / 0`;
- post-push worktree: clean.

GitHub independently confirmed the freeze-to-implementation comparison is one commit ahead, zero behind, with exactly the two frozen implementation files changed.

Result: **PASS**

### Vercel Preview reconciliation

The implementation push produced the expected branch deployment:

- deployment ID: `dpl_FqkhMumVjzUeKUqsURWNhUyUJGG8`;
- deployment SHA: `f834979359d16ae087c25ca29f8cba3fd3e021f4`;
- Git branch: `architecture-rebuild`;
- state: `READY`;
- Vercel target field: `null`;
- branch alias: `memory-keeper-os-git-architecture-rebuild-team1996.vercel.app`;
- build completed successfully.

The `target: null` deployment together with the `architecture-rebuild` Git metadata and branch alias is the expected Preview/non-Production routing.

No Production deployment was created by the Slice 7F implementation push.

The latest deployment carrying Vercel `target: production` remains the previously recorded accidental architecture deployment:

- deployment ID: `dpl_varrdvzMrBSfnNVjhwNnF4mrSzAL`;
- SHA: `e570da0b7715f992edd4cd870437d3dbbaf7324a`.

Slice 7F did not replace or redeploy Production.

Result: **PASS**

### Production and merge containment

Slice 7F implementation performed no:

- Production Supabase migration;
- Production Supabase data mutation;
- Production Vercel deployment;
- Production environment-variable change;
- Git merge into `main`;
- Supabase branch merge;
- schedule mutation UI release;
- preparation or safety runtime release;
- booking-team runtime release;
- Sprint 10 release.

The existing containment gates therefore remain:

- Git `main` merge: **HOLD**
- Supabase branch merge: **HOLD**
- Production database mutation: **HOLD**
- Production redeploy / restore: **HOLD pending separate release-source reconciliation**

### Slice 7F checkpoint status

**IMPLEMENTATION VALIDATED / PUSHED / PREVIEW VERIFIED / NOT PRODUCTION RELEASED**

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

## Sprint 10 Slice 7G — Controlled Shoot Scheduling Mutations — Technical Design Freeze

Governed base commit: `f787c5c427372885bc1165bc1922a667ef9edc0a` (Slice 7F checkpoint). Branch: `architecture-rebuild`. Preview-only; Production and `main` remain untouched by this freeze.

#### 1. Discovery basis

Slice 7F's own freeze (§9, "No scheduling mutations in Slice 7F") explicitly deferred exposing `propose_booking_shoot_schedule(...)` and `reschedule_booking_shoot(...)` to "a later separately frozen slice." Both RPCs, the `booking_shoot_schedules` table, and the `shoot.schedule` permission were introduced and frozen at the database layer in Slice 1 (migration `20260814120719_sprint10_shoot_schedule_foundation.sql`) and are covered by the existing `sprint10_shoot_schedule_test.sql` pgTAP suite (111/111 PASS as of the Slice 7F checkpoint). Both RPCs and the `booking_shoot_schedules` table are already present in generated Supabase types (`src/integrations/supabase/types.ts`). Slice 7G authors no SQL and requires no new migration or type regeneration.

#### 2. Exact Slice 7G implementation boundary

Implementation is restricted to exactly two files, extending the Slice 7F boundary:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

No other file may change in the implementation commit. No migration file is added or modified. No generated Supabase type file changes.

#### 3. Existing database guarantees consumed as-is

Slice 7G authorizes no new database behavior; it exposes exactly the following existing, already-tested guarantees:

`propose_booking_shoot_schedule(p_booking_id, p_scheduled_start_at, p_scheduled_end_at, p_timezone, p_location_type, p_location_details DEFAULT NULL)`:

- valid only when the booking's current journey stage is exactly Stage 7 / `advance_pending` (else `22023`);
- valid only when the current schedule tip, if any, is `proposed` (rejects over a `reserved` tip);
- requires `shoot.schedule` permission and branch scope, enforced inside the `SECURITY DEFINER` function (else `42501`);
- exact-value replay is idempotent — returns the existing tip row, does not append a new version;
- on a genuine change, appends a new row: `schedule_state = 'proposed'`, version = tip + 1, predecessor = tip.id, `reschedule_reason = NULL`.

`reschedule_booking_shoot(p_booking_id, p_scheduled_start_at, p_scheduled_end_at, p_timezone, p_location_type, p_reschedule_reason, p_location_details DEFAULT NULL)`:

- valid only when the booking's current journey stage is Stage 8, 9 or 10 (`booking_confirmed`, `pre_shoot_preparation`, `shoot_scheduled`) (else `22023`);
- valid only when the current schedule tip is `reserved` (else `22023`);
- `p_reschedule_reason` is mandatory and non-blank (else `22023`);
- requires `shoot.schedule` permission and branch scope (else `42501`);
- exact-value-and-reason replay is idempotent;
- on a genuine change, appends a new row: `schedule_state = 'reserved'` (never reverts to proposed), version = tip + 1, predecessor = tip.id, reason recorded.

The append-only guard trigger on `booking_shoot_schedules` makes direct UPDATE/DELETE impossible, and no INSERT/UPDATE/DELETE grant exists on the table for `authenticated` — the two RPCs are the sole write path. Authorization is enforced inside each RPC; a caller lacking `shoot.schedule` already receives a database-level `42501` regardless of any client-side state, independently proven by existing pgTAP coverage.

#### 4. Authorization model

Client-side authorization is limited to UX visibility only, using the existing authoritative capability-read pattern already established in `src/lib/team.functions.ts` (`getTeamCapabilities`), not a new or invented model. That function calls `context.supabase.rpc("effective_permissions", { p_organization_id: ORGANIZATION_ID })`, collects the returned permission keys into a `Set`, and derives boolean capability flags via `.has(...)`.

Slice 7G reuses this exact pattern inside `src/lib/booking.functions.ts`: `listBookingWorkspace()` (or a narrowly scoped addition to its returned shape) calls the same `effective_permissions` RPC and exposes `canSchedule: permissions.has("shoot.schedule")` (or an equivalently narrow capability) to the client. No role name (`founder`, `studio_manager`, `client_coordinator`) is hard-coded in React, and `src/lib/access.ts`'s legacy role-array model is not extended or consulted for this feature.

`canSchedule` is UX visibility only. It does not replace or weaken database enforcement: `propose_booking_shoot_schedule` and `reschedule_booking_shoot` remain the sole authorization boundary, independently re-checking `shoot.schedule` inside each `SECURITY DEFINER` function on every call. A caller whose `canSchedule` is stale or who reaches the RPC despite it being false still receives a database-level `42501`, surfaced as an error — never a silent failure or a fabricated success.

#### 5. Stage/state eligibility and capability visibility (UI control visibility only, not security)

A scheduling mutation control renders only when **both** of the following hold:

- canonical stage/schedule-state eligibility passes:
  - "Propose" — `currentStage.stage_order === 7` and (`currentSchedule` is absent or `currentSchedule.schedule_state === "proposed"`);
  - "Reschedule" — `currentStage.stage_order` is 8, 9 or 10 and `currentSchedule?.schedule_state === "reserved"`;
- **and** `canSchedule === true` (from §4).

In every other combination, no scheduling mutation control renders at all. This is a UX/workflow gate; the RPC boundary in §3 remains the actual authorization enforcement regardless of what the UI shows.

#### 6. Form/input validation

- Timezone: **not editable**. Slice 7G constrains scheduling input to exactly the browser-resolved IANA timezone, read via `Intl.DateTimeFormat().resolvedOptions().timeZone` at form-open time, and displayed read-only in the form (not as an editable text input). If a usable IANA timezone cannot be resolved from the browser, the form refuses submission and shows an explicit error rather than guessing or falling back to a default. Arbitrary/cross-timezone scheduling input (an editable timezone selector) is explicitly deferred to a later, separately frozen slice. No timezone library is added; no change to `package.json` or lockfiles.
- Start/end: paired `datetime-local` inputs. Because the browser's `datetime-local` value is inherently wall-clock-in-local-timezone, and the resolved timezone in this same form is that same browser timezone, the wall-clock value is interpreted in that timezone when converting to the ISO-8601-with-offset instant submitted as `p_scheduled_start_at`/`p_scheduled_end_at`, and the exact same resolved IANA string is submitted as `p_timezone` — so the submitted timezone always correctly describes the timezone used to interpret the submitted wall-clock input. Client-side check that end is after start, purely as UX to avoid an avoidable round trip — the database's `booking_shoot_schedules_time_range_chk` remains authoritative.
- Location type: required non-blank text input. Location details: optional text input.
- Reschedule reason: required non-blank textarea, present only on the reschedule form. Client-side non-blank check is UX only — the database rejects a blank reason with `22023` regardless.

#### 7. Timezone behavior

Scheduling input in Slice 7G is constrained to the single browser-resolved IANA timezone described in §6 — read-only in the form, not user-editable, and used consistently to interpret the wall-clock `datetime-local` input and as the `p_timezone` value submitted to the RPC. The proposed/reserved schedule is stored and displayed using that IANA timezone string (matching Slice 7F's existing `formatScheduleDateTime` rendering, unchanged). No timezone conversion, normalization, or arbitrary-timezone selection is performed by the application in this slice; that capability is explicitly deferred to a later, separately frozen slice.

#### 8. Proposal semantics

A proposal is explicitly not a reservation and does not confirm the booking. Existing copy and the `scheduleStateLabel()` helper (`"Reserved"` / `"Proposed · not reserved"`) are reused unchanged. Additional static copy adjacent to the propose control states plainly that proposing a schedule does not itself reserve a date or confirm the booking.

#### 9. Reschedule semantics

Reschedule is only offered once a reserved schedule tip exists (Stage 8–10), and it replaces that already-reserved canonical schedule with another reserved version — the resulting schedule remains `reserved`, never `proposed`. Rescheduling does not itself confirm the booking or advance the journey stage. Additional static copy adjacent to the reschedule control must not describe the outcome as "not reserved" — a successful reschedule keeps the schedule authoritative and reserved, it only changes which version is current. The reschedule reason is mandatory and is always displayed against its version in the existing `ScheduleHistory` component, unchanged from Slice 7F.

#### 10. Immutable-history behavior

No historical schedule row is ever mutated by the application. The existing `ScheduleHistory` component is reused as-is. After any successful mutation, the client invalidates the `["booking-workspace"]` query (`queryClient.invalidateQueries`) and refetches authoritative data from `listBookingWorkspace()` rather than performing any optimistic local update or array splicing. Predecessor lineage (`predecessor_schedule_id`) remains visible exactly as Slice 7F rendered it.

#### 11. Empty/error/loading states

- Loading: mutation buttons reflect `mutation.isPending` via a text swap (e.g. "Proposing…" / "Rescheduling…"), matching the existing convention in `src/routes/_authenticated/team.tsx`.
- Error: all RPC/validation errors (`42501`, `22023`, `P0001`) are surfaced identically via `sonner` `toast.error(error instanceof Error ? error.message : "<fallback>")`, matching the existing convention. No error-code-specific UI branching.
- Success: `toast.success(...)`, the active form closes, and authoritative data is refetched.
- Empty state (no schedule yet): unchanged from Slice 7F — "No canonical shoot plan recorded" — with the propose control now available beneath it when both stage/state eligibility and `canSchedule` hold.
- Timezone-unresolvable state: if the browser cannot resolve a usable IANA timezone (§6), the form shows an explicit error and refuses submission rather than guessing.

#### 12. Runtime acceptance cases

Controlled disposable local authenticated fixtures must prove:

A. Stage 7 booking, no schedule: a user with `canSchedule = true` proposes; result renders as "Proposed · not reserved"; history contains canonical v1.
B. Stage 7 booking, existing proposal: changed proposal appends v2 with predecessor v1; v1 remains immutable in history; exact-value replay does not duplicate.
C. Reserved booking (Stage 8–10): a user with `canSchedule = true` reschedules, creating a new reserved version; predecessor lineage and reschedule reason are visible; prior reserved history remains immutable; the schedule remains reserved throughout, never rendered as unreserved.
D. Unauthorized/ineligible cases: UI does not render a control when stage/schedule-state eligibility fails, or when `canSchedule` is false; where a control is technically reachable but the RPC rejects the call (e.g. a stale `canSchedule` or a direct/forced call), the UI surfaces the database error and never fabricates success; no direct-write fallback exists anywhere in the code.
E. No preparation, safety, team-assignment or general journey-transition control is introduced anywhere on the page.

After runtime acceptance: stop the dev server, run `npx supabase db reset --local --yes`, and confirm disposable evidence created by the canonical acceptance flow returns to zero, including as applicable:

- `auth.users`;
- `organization_members`;
- `families`;
- `quotations`;
- `quotation_line_items`;
- `bookings`;
- `booking_payments`;
- `booking_journey_states`;
- `booking_stage_transitions`;
- `booking_shoot_schedules`;
- disposable audit evidence produced by the fixture flow.

Seeded/static catalogue tables such as `booking_journey_stages` are not required to be zero — they hold reference data reapplied by the migration chain, not disposable fixtures.

#### 13. Database regression gates

Local only, `--local` explicit, no Production access. Three independent commands, recorded as separate gates:

- targeted scheduling pgTAP: `npx supabase test db --local supabase/tests/sprint10_shoot_schedule_test.sql` — expected 111/111 PASS (unchanged, since no migration changes);
- complete local database suite: `npx supabase test db --local supabase/tests` — expected 1083/1083 PASS across 16 files (unchanged);
- lint: `npx supabase db lint --local` — expected clean, no schema errors.

#### 14. Application validation gates

- targeted Prettier on the two authored files;
- targeted ESLint on the two authored files;
- production build;
- `tsc --noEmit`, after normal TanStack route generation, with generated `src/routeTree.gen.ts` restored before commit;
- `git diff --check`;
- exact implementation file-boundary verification (only the two frozen files changed);
- confirmation generated Supabase types are unchanged;
- confirmation no migration file is added or modified.

#### 15. Preview-only deployment boundary

After each of the three governed commits (freeze, implementation, checkpoint) is pushed to `architecture-rebuild`, the Preview verification gate is explicit and evidence-based, not assumed. Authenticated read-only Vercel verification must prove, for the exact pushed commit:

- the deployment's Git commit SHA matches the exact pushed SHA;
- the deployment's Git branch is `architecture-rebuild`;
- deployment state is `READY`;
- the deployment is Preview / non-Production (Vercel `target` is not `production`);
- the deployment resolves under the expected `architecture-rebuild` branch alias/routing;
- the latest deployment carrying Vercel `target: production` was NOT replaced or superseded by this push.

If authenticated read-only Vercel access capable of proving all of the above is not available at push time, work stops immediately after Git push reconciliation and reports:

`HOLD — EXTERNAL VERCEL VERIFICATION REQUIRED`

Preview PASS is never assumed or declared without this evidence. In addition:

- `architecture-rebuild` continues using its existing isolated Supabase Preview configuration;
- no Vercel Production deployment is authorized;
- no Production Supabase read, write or migration is authorized;
- Git `main` is not modified;
- Supabase `main` is not merged.

#### 16. Explicit Slice 7G exclusions

Slice 7G does not authorize:

- booking confirmation UI;
- payment mutation;
- arbitrary or general journey advancement UI;
- preparation runtime mutation;
- safety runtime mutation;
- booking-team mutation;
- external-creative mutation;
- capacity or overlap logic;
- external calendar integration;
- any database schema change or new migration;
- unlocking `/prep` or `/safety`;
- Sprint 10 release.

The RPC contract for this slice is explicit:

- the only scheduling **mutation** RPCs authorized by Slice 7G are `propose_booking_shoot_schedule` and `reschedule_booking_shoot`;
- the existing read-only `effective_permissions` RPC is explicitly permitted, solely for deriving `canSchedule` / scheduling-control UX visibility per §4, and confers no additional mutation authorization;
- no other mutation RPC is authorized by this slice;
- `confirm_booking_after_advance` and `mark_booking_shoot_scheduled` remain explicitly excluded and untouched.

If discovery during implementation proves any of the above is unavoidably required, implementation stops and the finding is reported rather than expanding scope.

#### 17. Commit discipline

Slice 7G follows the established three-stage discipline:

1. technical design freeze documentation commit (this section);
2. exact two-file implementation commit;
3. implementation checkpoint documentation commit.

Each commit is pushed and reconciled independently. Every `architecture-rebuild` push must be verified as a Vercel Preview deployment before proceeding to the next governed step.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

## Sprint 10 Slice 7G - Controlled Shoot Scheduling Mutations - Implementation Checkpoint

### Implementation evidence

Sprint 10 Slice 7G controlled shoot-scheduling mutation runtime implementation completed locally, was fully validated, committed, pushed and reconciled on 2026-08-18.

- Freeze commit: `61e253c033da5f3c8cc8b774b095535d0201a8ff`
- Implementation commit: `3a24874d92eab3ecd5fd450a7837439647a98a89`
- Implementation commit message: `feat: add controlled booking schedule mutations`
- Implementation parent: `61e253c033da5f3c8cc8b774b095535d0201a8ff`
- Branch: `architecture-rebuild`

The implementation commit contains exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

Implementation diff:

- `src/lib/booking.functions.ts`: 89 additions / 8 deletions;
- `src/routes/_authenticated/bookings.tsx`: 356 additions / 4 deletions;
- total: 445 additions / 12 deletions.

No migration, generated Supabase type, generated route-tree, package, lockfile, access-control, preparation, safety, team-assignment or external-creative file is part of the implementation commit.

### Delivered scheduling capability model

`listBookingWorkspace()` now resolves canonical effective permissions through:

`effective_permissions(ORGANIZATION_ID)`

and exposes:

`canSchedule`

derived only from:

`permissions.has("shoot.schedule")`

No React role-name authorization model was introduced.

`canSchedule` remains presentation-only authority.

The canonical database RPCs continue to re-authorize every scheduling mutation independently.

### Delivered scheduling mutation boundary

The authenticated runtime now exposes exactly two scheduling mutation server functions:

- `proposeShootSchedule`;
- `rescheduleShoot`.

They call only the frozen canonical RPCs:

- `propose_booking_shoot_schedule(...)`;
- `reschedule_booking_shoot(...)`.

Both server functions:

- use `requireSupabaseAuth`;
- use validated server-function input;
- preserve server-owned organization/authentication context;
- surface database errors rather than fabricating success;
- return the authoritative schedule row returned by the database.

No direct INSERT, UPDATE or DELETE path against `booking_shoot_schedules` was introduced.

No other mutation RPC was added to the Slice 7G runtime.

### Delivered controlled scheduling UI

The `/bookings` runtime now exposes scheduling controls only when both canonical workflow eligibility and `canSchedule` allow them.

Proposal controls are limited to:

- canonical Stage 7 / `advance_pending`;
- no schedule tip or an existing `proposed` tip;
- `canSchedule === true`.

Reschedule controls are limited to:

- canonical Stage 8, 9 or 10;
- a current `reserved` schedule tip;
- `canSchedule === true`.

The UI does not treat those visibility rules as the security boundary.

The database remains authoritative for every mutation.

### Delivered form and timezone behavior

Scheduling forms use paired `datetime-local` inputs.

At form-open time the browser resolves its timezone through:

`Intl.DateTimeFormat().resolvedOptions().timeZone`

The resolved timezone:

- is captured once for the form instance;
- is shown read-only;
- is submitted with the interpreted schedule instants;
- has no application fallback;
- cannot be arbitrarily edited.

If the browser cannot resolve a usable timezone, scheduling submission is disabled and an explicit error is displayed.

Client UX validation also requires:

- start and end values;
- end after start;
- non-blank location type;
- non-blank reschedule reason for rescheduling;
- optional location details.

Database validation remains authoritative.

### Proposal and reschedule semantics

Proposal behavior preserves the canonical distinction:

`Proposed · not reserved`

A proposal does not reserve the date and does not confirm the booking.

Rescheduling is available only over an existing reserved schedule and produces another reserved schedule version.

A reschedule:

- does not revert the booking to proposed;
- does not confirm the booking;
- does not advance the booking journey;
- requires a reschedule reason.

After successful mutations the runtime invalidates:

`["booking-workspace"]`

and refetches authoritative canonical state.

No optimistic schedule-history rewrite was introduced.

### Controlled local runtime acceptance

Disposable authenticated local fixtures exercised all frozen Slice 7G acceptance cases.

#### Case A - Stage 7 initial proposal

A Stage 7 booking with no schedule was proposed successfully by an authorized Founder fixture.

Result:

- canonical schedule v1 created;
- state was `proposed`;
- UI rendered `Proposed · not reserved`;
- no reservation or booking-confirmation semantics were implied.

Result: **PASS**

#### Case B - proposal idempotency and immutable history

Exact replay of the v1 proposal returned the same canonical tip without creating another schedule row.

A changed proposal appended canonical v2:

- v1 remained unchanged;
- v2 referenced v1 as predecessor;
- both versions remained visible in immutable history.

Result: **PASS**

#### Case C - reserved reschedule and idempotency

Existing canonical local payment and booking-confirmation operations were used only as controlled fixture setup to advance the disposable booking to Stage 8 and create the canonical reserved schedule.

Those operations were not added to the Slice 7G UI or implementation surface.

The Stage 8 fixture then contained reserved v3.

A changed reschedule created reserved v4:

- v4 referenced v3;
- state remained `reserved`;
- reschedule reason `Client requested date change` was recorded;
- all earlier versions remained immutable.

Exact replay of the v4 values and reason:

- returned the existing canonical tip;
- did not create v5;
- left total schedule count at four.

Result: **PASS**

#### Case D1 - unauthorized Sales actor

The Sales fixture retained canonical booking/schedule read visibility but received:

- no proposal control;
- no Reschedule control;
- no scheduling mutation form.

A forced otherwise-valid reschedule RPC invocation was rejected by the database with:

`SQLSTATE 42501`

and:

`reschedule_booking_shoot: shoot.schedule permission required`

The canonical schedule count remained four.

Result: **PASS**

#### Case D2 - authorized but ineligible Founder actor

A Founder fixture with scheduling permission directly attempted a proposal after the booking had reached canonical Stage 8.

The database rejected the operation with:

`SQLSTATE 22023`

and:

`propose_booking_shoot_schedule: booking must be at Advance Pending`

Journey state remained:

- `booking_confirmed`;
- stage order 8;
- journey version 2.

Canonical schedule count remained four.

Result: **PASS**

#### Case E - runtime containment

Authenticated visual acceptance confirmed that Slice 7G introduced no:

- payment mutation UI;
- booking-confirmation UI;
- arbitrary/general journey advancement UI;
- preparation mutation UI;
- safety mutation UI;
- booking-team mutation UI;
- external-creative mutation UI.

Result: **PASS**

### Disposable fixture cleanup

After local runtime acceptance:

- the development server was stopped;
- temporary fixture scripts were removed;
- `npx supabase db reset --local --yes` completed successfully;
- the complete local migration chain reapplied through `20260817042405_sprint10_team_role_admin_read_model.sql`;
- generated `src/routeTree.gen.ts` output was restored and excluded from authored changes.

Post-reset disposable evidence returned to zero for all explicitly checked tables:

- `auth.users`;
- `organization_members`;
- `member_role_grants`;
- `families`;
- `quotations`;
- `quotation_line_items`;
- `bookings`;
- `booking_payments`;
- `booking_journey_states`;
- `booking_stage_transitions`;
- `booking_shoot_schedules`;
- `audit_events`.

Result: **PASS**

### Database regression gate

Slice 7G authored no SQL.

Post-cleanup validation completed successfully:

- dedicated `supabase/tests/sprint10_shoot_schedule_test.sql`: **111/111 PASS**;
- complete local pgTAP regression: **1083/1083 PASS** across 16 files;
- `npx supabase db lint --local`: **PASS - No schema errors found**;
- no migration was added or modified.

Result: **PASS**

### Application validation gate

Final application validation completed successfully:

- targeted Prettier for both authored runtime files: PASS;
- targeted ESLint for both authored runtime files: PASS with zero errors/warnings;
- production build: PASS;
- TypeScript `npx tsc --noEmit`: PASS;
- generated `src/routeTree.gen.ts` restored after tooling regeneration;
- `git diff --check`: PASS;
- final implementation boundary contained exactly the two frozen runtime files.

No generated Supabase type change was required.

Result: **PASS**

### Git implementation reconciliation

Implementation commit:

`3a24874d92eab3ecd5fd450a7837439647a98a89`

was created directly on top of the Slice 7G freeze:

`61e253c033da5f3c8cc8b774b095535d0201a8ff`

Pre-push divergence was:

- remote-only commits: 0;
- local-only commits: 1.

The implementation push completed as the expected fast-forward:

`61e253c..3a24874`

Post-push:

- local HEAD = `3a24874d92eab3ecd5fd450a7837439647a98a89`;
- tracking ref = `3a24874d92eab3ecd5fd450a7837439647a98a89`;
- worktree = clean.

GitHub independently confirmed:

- branch `architecture-rebuild` points to the exact implementation SHA;
- the implementation is one commit directly above the freeze;
- only the two frozen implementation files changed.

Result: **PASS**

### Vercel Preview reconciliation

The implementation push produced the expected Vercel deployment:

- deployment ID: `dpl_6WWJKUob22LeGWFPVELx2vEkydwx`;
- Git SHA: `3a24874d92eab3ecd5fd450a7837439647a98a89`;
- Git branch: `architecture-rebuild`;
- state: `READY`;
- target: `null`;
- source: `git`;
- branch alias: `memory-keeper-os-git-architecture-rebuild-team1996.vercel.app`.

The exact SHA, branch, READY state and non-Production target were independently reconciled through authenticated read-only Vercel project/deployment metadata.

The previously recorded Production deployment remains:

- deployment ID: `dpl_varrdvzMrBSfnNVjhwNnF4mrSzAL`;
- Git SHA: `e570da0b7715f992edd4cd870437d3dbbaf7324a`;
- target: `production`;
- state: `READY`.

The Slice 7G implementation push therefore did not replace that Production deployment.

Result: **PASS**

### Preview application authentication observation

The branch Preview successfully rendered the application authentication surface.

An authenticated `/bookings` Preview smoke test could not be completed without creating remote authentication/business state because the Supabase environment inspected during login diagnosis contained:

- zero `auth.users` rows;
- no organization membership;
- no Founder grant;
- canonical organization status `suspended`.

No remote user, membership, role grant, schedule, booking or other business fixture was created merely to manufacture a Preview login.

This absence of remote authentication state is recorded as an environment limitation rather than a Slice 7G application failure.

A read-only Supabase dashboard diagnostic was used during that login investigation. No Supabase write or migration was performed. The exact dashboard branch/environment identity was not independently captured as acceptance evidence, so that diagnostic is not treated as Production validation and authorizes no further remote database activity.

### Production and merge containment

Slice 7G implementation performed no:

- Production Vercel deployment;
- Production Supabase write;
- Production Supabase migration;
- remote scheduling mutation;
- Git merge into `main`;
- Supabase branch merge;
- booking-confirmation UI release;
- payment UI release;
- preparation or safety runtime release;
- booking-team mutation runtime release;
- external-creative mutation runtime release;
- Sprint 10 release.

The existing containment gates remain:

- Git `main` merge: **HOLD**
- Supabase branch merge: **HOLD**
- Production database mutation: **HOLD**
- Production application release/redeployment: **HOLD**

### Slice 7G checkpoint status

**IMPLEMENTATION VALIDATED / PUSHED / PREVIEW DEPLOYMENT VERIFIED / AUTHENTICATED PREVIEW APP SMOKE BLOCKED BY EMPTY REMOTE AUTH BASELINE / NOT PRODUCTION RELEASED**

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

## Sprint 10 Slice 7H — Controlled Advance Payment Evidence — Technical Design Freeze

Governed base commit: `7e2fe98053f9c43a9a5c1e37fbe21ec23fadc9d0` (Slice 7G checkpoint).

Branch: `architecture-rebuild`.

Slice 7H remains Preview-only. Production, Git `main`, and the Production Supabase environment remain outside this slice.

### 1. Discovery basis

Post-Slice-7G read-only discovery established that the next canonical workflow dependency is advance-payment evidence rather than booking confirmation.

The database already provides the complete controlled payment foundation introduced in Sprint 9:

- `booking_payment_requirements`;
- `booking_payments`;
- `booking_payment_reversals`;
- `payment.read`;
- `payment.record`;
- `payment.reverse`;
- `record_booking_payment(...)`;
- `reverse_booking_payment(...)`;
- `get_booking_payment_summary(uuid)`.

The generated Supabase application contract already contains the payment tables, payment method enum and RPC signatures required for runtime integration.

No Supabase type regeneration is required for Slice 7H.

Current application discovery established that:

- `/bookings` does not currently read canonical payment summary state;
- no application server function currently calls `record_booking_payment(...)`;
- no application server function currently calls `get_booking_payment_summary(...)`;
- no application server function currently calls `reverse_booking_payment(...)`;
- no application server function currently calls `confirm_booking_after_advance(...)`;
- Slice 7G exposes only controlled shoot proposal and reschedule mutations.

Canonical booking confirmation cannot succeed until valid non-reversed payment evidence satisfies the frozen advance requirement.

Sprint 10 additionally requires the current shoot schedule tip to be a `proposed` schedule before first-time confirmation.

Therefore booking confirmation is deferred to a later separately frozen slice.

Slice 7H exists only to make the canonical advance-payment prerequisite visible and recordable through the application without releasing confirmation itself.

### 2. Exact Slice 7H implementation boundary

Slice 7H implementation is restricted to exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

No other implementation file may change.

In particular Slice 7H does not authorize changes to:

- `src/integrations/supabase/types.ts`;
- `src/lib/access.ts`;
- `/prep`;
- `/safety`;
- generated route definitions;
- migrations;
- pgTAP test files;
- package metadata;
- lockfiles.

`src/routeTree.gen.ts` may be regenerated temporarily by normal application tooling but must be restored before commit because Slice 7H introduces no route-definition change.

### 3. Existing canonical payment guarantees consumed as-is

Slice 7H authors no SQL and creates no new payment behavior.

The existing canonical RPC:

`record_booking_payment(
  uuid,
  integer,
  booking_payment_method,
  timestamptz,
  text,
  text
)`

remains the sole Slice 7H payment mutation authority.

The RPC already owns:

- booking existence validation;
- positive whole-INR payment validation;
- authenticated active-member resolution;
- `payment.record` authorization;
- booking branch-scope authorization;
- canonical payment-requirement linkage;
- immutable payment evidence creation;
- canonical payment reference generation;
- payment audit evidence.

The frozen payment-method vocabulary remains exactly:

- `cash`;
- `upi`;
- `bank_transfer`;
- `card`;
- `other`.

Slice 7H does not reproduce those database rules in a second business-authority layer.

Client validation exists for UX only.

The database remains authoritative.

### 4. Canonical payment summary authority

Payment state displayed by Slice 7H must come from:

`get_booking_payment_summary(uuid)`

rather than from client-side arithmetic over raw payment rows.

The canonical derived summary exposes:

- `booking_id`;
- `source_quotation_id`;
- `accepted_quotation_total_inr`;
- `required_advance_inr`;
- `valid_collected_inr`;
- `advance_outstanding_inr`;
- `advance_satisfied`;
- `payment_count`;
- `reversal_count`;
- `confirmed_with_advance_shortfall`.

The application must not independently recalculate the 50% advance requirement.

The database's frozen rule remains authoritative:

`required advance = 50% of final accepted quotation value`

using the canonical whole-INR rounding rule already implemented in Sprint 9.

Slice 7H does not read raw payment or reversal rows merely to recreate the summary.

### 5. Payment capability model

`listBookingWorkspace()` may extend its existing `effective_permissions(ORGANIZATION_ID)` result into two explicit presentation capabilities:

`canReadPayment`

derived only from:

`permissions.has("payment.read")`

and:

`canRecordPayment`

derived only from:

`permissions.has("payment.record")`.

No hard-coded React role-name authorization is permitted.

The application must not infer payment authority from:

- Founder identity;
- Sales identity;
- Accounts identity;
- navigation roles;
- legacy `bookings.finance`;
- any other frontend role list.

Permission-derived capability controls are presentation/UX gates only.

The payment RPCs continue to re-authorize every operation independently.

### 6. Payment-summary workspace extension

When `canReadPayment === true`, `listBookingWorkspace()` may call:

`get_booking_payment_summary(uuid)`

for the canonical bookings already resolved through the existing workspace.

The server function must:

- continue to use `requireSupabaseAuth`;
- continue to use server-owned `ORGANIZATION_ID`;
- request summaries only for bookings already visible through the canonical booking query;
- surface canonical RPC errors;
- preserve existing booking, quotation, journey, schedule, lead and family behavior.

When `canReadPayment === false`:

- the application must not invoke the payment-summary RPC for that user;
- payment totals must not be exposed;
- required advance must not be exposed;
- collected payment value must not be exposed;
- payment counts and reversal counts must not be exposed.

Payment information must not leak through the broad `booking.read` capability.

### 7. Controlled payment-recording mutation

Slice 7H may add exactly one new application payment mutation server function:

`recordBookingPayment`

It must call only:

`record_booking_payment(...)`.

The server function must:

- use `requireSupabaseAuth`;
- accept validated input;
- keep organization and authenticated actor authority server-owned;
- surface database errors rather than fabricate success;
- return the canonical payment row returned by the RPC.

The application must not directly INSERT, UPDATE or DELETE:

- `booking_payments`;
- `booking_payment_reversals`;
- `booking_payment_requirements`.

No other payment mutation RPC is authorized in Slice 7H.

### 8. Payment input contract

The controlled payment form may collect only:

- amount in whole INR;
- payment method;
- received timestamp;
- optional external reference;
- optional note.

Client validation must require:

- amount is an integer;
- amount is greater than zero;
- payment method is one of the canonical enum values;
- received timestamp resolves to a valid instant;
- optional textual values are normalized so blank optional input is not represented as meaningful evidence.

The database remains authoritative for payment validity.

No floating-point currency model may be introduced.

No alternate currency is introduced.

Slice 7H remains INR-only because the canonical booking-payment foundation is INR-only.

### 9. Payment evidence is append-only

Every successful `record_booking_payment(...)` invocation represents new immutable payment evidence.

Slice 7H must not describe the operation as idempotent.

The application must not assume that replaying the same payment payload returns the original payment.

A repeated successful invocation may represent another payment and therefore may create another canonical payment row.

The submit control must be disabled while the current mutation request is pending to reduce accidental duplicate submission.

No application-level payment deduplication rule is invented.

Correction of an incorrectly recorded payment remains:

original payment -> immutable reversal -> new payment

but Slice 7H does not expose the reversal operation.

### 10. Payment presentation boundary

For a user with `canReadPayment === true`, the Booking workspace may display the canonical derived payment summary.

At minimum the UI may show:

- accepted quotation total;
- required advance;
- valid collected amount;
- outstanding advance;
- whether the advance requirement is satisfied;
- payment count;
- reversal count where non-zero;
- confirmed-with-shortfall warning where canonically returned.

The UI must clearly distinguish:

- `Advance outstanding`;
- `Advance satisfied`.

`advance_satisfied === true` is financial evidence only.

It must not be presented as:

- Booking Confirmed;
- shoot reserved;
- preparation started;
- shoot scheduled.

Journey state and schedule state remain separate canonical facts.

### 11. Narrow payment-recording UI gate

Slice 7H payment recording is intended only to satisfy the controlled Stage 7 advance prerequisite.

The record-payment control may render only when all of the following are true:

- canonical journey stage is Stage 7 / `advance_pending`;
- `canReadPayment === true`;
- `canRecordPayment === true`;
- a canonical payment summary exists;
- `advance_satisfied === false`.

This is deliberately narrower than the underlying database RPC.

It is a Slice 7H product/UX containment rule, not an authorization boundary.

The database remains authoritative for permission and booking integrity.

A successful payment that satisfies or exceeds the outstanding advance causes the refreshed summary to report `advance_satisfied === true`, after which the Slice 7H payment-recording control is no longer presented.

Slice 7H does not introduce a client-side rule that payment amount must be less than or equal to the current outstanding amount.

If a valid real payment exceeds the outstanding advance, the canonical RPC remains capable of recording the actual received amount.

### 12. Mutation refresh behavior

After a successful payment mutation the application must invalidate:

`["booking-workspace"]`

and refetch canonical state.

The UI must not optimistically modify:

- collected totals;
- outstanding totals;
- payment counts;
- journey state;
- schedule state.

The database-returned and subsequently refetched canonical evidence remains authoritative.

Mutation failures must be visibly surfaced.

### 13. Booking confirmation remains excluded

Slice 7H must not call:

`confirm_booking_after_advance(uuid)`.

Slice 7H introduces no:

- Confirm Booking button;
- automatic confirmation after advance satisfaction;
- automatic Stage 7 -> 8 transition;
- automatic schedule reservation.

Even when:

`advance_satisfied === true`

the booking remains at its existing canonical journey stage until the separately governed confirmation RPC is explicitly invoked in a later slice.

If a current Stage 7 schedule tip is `proposed`, recording sufficient payment must not convert it to `reserved`.

Only `confirm_booking_after_advance(...)` owns that future atomic reservation-and-confirmation behavior.

### 14. Payment reversal remains excluded

Although the database exposes:

`reverse_booking_payment(uuid,text)`

Slice 7H must not invoke it.

Slice 7H introduces no:

- payment reversal button;
- delete-payment action;
- edit-payment action;
- correction workflow;
- refund workflow.

Historical payment correction remains a later separately governed runtime boundary.

No existing immutable payment evidence may be rewritten.

### 15. Preparation, safety and later journey containment

Slice 7H must not invoke:

- `start_pre_shoot_preparation(...)`;
- `mark_booking_shoot_scheduled(...)`;
- any preparation mutation;
- any preparation-item mutation;
- any booking-team mutation;
- any external-creative mutation;
- any safety-readiness mutation;
- any safety-signoff mutation;
- any generic journey-advance operation.

`/prep` remains contained.

`/safety` remains contained.

No Stage 8 -> 9 runtime cutover is authorized.

No Stage 9 -> 10 runtime cutover is authorized.

No Stage 10 -> 11 implementation is authorized.

### 16. Scheduling containment

Slice 7H preserves the existing Slice 7G scheduling runtime unchanged.

The existing controlled RPCs remain:

- `propose_booking_shoot_schedule(...)`;
- `reschedule_booking_shoot(...)`.

Slice 7H must not widen their eligibility, permissions or semantics.

Payment satisfaction must not itself:

- reserve a proposed schedule;
- reschedule a booking;
- create schedule history;
- alter schedule history.

### 17. Controlled local runtime acceptance

Slice 7H implementation must be validated with disposable authenticated local fixtures.

Acceptance must prove at minimum:

#### Case A — canonical unpaid summary

An authorized payment reader views a canonical Stage 7 booking with:

- accepted quotation;
- frozen payment requirement;
- zero valid collected payment.

The application must render canonical summary values including:

- required advance;
- zero collected;
- full advance outstanding;
- `advance_satisfied === false`.

Result required: **PASS**

#### Case B — partial advance payment

An authorized payment recorder submits a valid partial payment.

The database must append one canonical payment row.

After authoritative refetch:

- collected value increases by exactly the recorded amount;
- outstanding advance decreases accordingly;
- `advance_satisfied` remains false;
- booking remains Stage 7;
- no booking-confirmation transition is created.

Result required: **PASS**

#### Case C — advance threshold satisfied without confirmation

A subsequent valid payment brings valid non-reversed collected INR to at least the required advance.

After authoritative refetch:

- `advance_satisfied === true`;
- `advance_outstanding_inr === 0`;
- payment count reflects the canonical payment evidence;
- booking remains Stage 7 / `advance_pending`;
- no Stage 7 -> 8 transition exists.

For this controlled fixture a proposed shoot plan may already exist.

If so, after payment satisfaction:

- the schedule must remain `proposed`;
- no `reserved` schedule version may appear merely because payment was satisfied.

This proves that Slice 7H does not silently perform booking confirmation.

Result required: **PASS**

#### Case D — unauthorized payment mutation

An authenticated actor without `payment.record` must receive no payment-recording control.

A forced otherwise-valid direct invocation of:

`record_booking_payment(...)`

must be rejected by the database with the canonical authorization error.

Canonical payment state must remain unchanged.

Result required: **PASS**

#### Case E — payment-read containment

An authenticated actor without `payment.read` must receive no payment summary.

The application must not expose:

- required advance;
- collected payment value;
- outstanding value;
- payment counts;
- reversal counts.

A forced direct payment-summary invocation must remain subject to the canonical database `payment.read` authorization boundary.

Result required: **PASS**

#### Case F — runtime containment

Authenticated visual acceptance must confirm that Slice 7H introduces no:

- payment reversal UI;
- booking-confirmation UI;
- preparation mutation UI;
- safety mutation UI;
- booking-team mutation UI;
- external-creative mutation UI;
- arbitrary journey-transition UI.

Result required: **PASS**

### 18. Disposable fixture cleanup

All local authentication and business fixtures created for Slice 7H acceptance are disposable.

After acceptance:

- development processes used for fixture validation must be stopped;
- temporary fixture scripts must be removed;
- local Supabase must be reset to the canonical migration baseline;
- generated route-tree output must be restored if tooling changed it.

Explicit post-reset zero-count evidence must include at least the disposable tables touched by acceptance, including:

- `auth.users`;
- `organization_members`;
- `member_role_grants`;
- `families`;
- `quotations`;
- `quotation_line_items`;
- `bookings`;
- `booking_payment_requirements`;
- `booking_payments`;
- `booking_payment_reversals`;
- `booking_journey_states`;
- `booking_stage_transitions`;
- `booking_shoot_schedules`;
- `audit_events`.

### 19. Database regression gate

Slice 7H authors no SQL.

Before the implementation may be checkpointed:

- `supabase/tests/sprint9_advance_payments_test.sql` must PASS;
- `supabase/tests/sprint9_booking_confirmation_test.sql` must PASS;
- `supabase/tests/sprint10_shoot_schedule_test.sql` must PASS;
- the complete local pgTAP suite must PASS;
- `npx supabase db lint --local` must PASS;
- the canonical local migration chain must remain unchanged.

Actual test totals must be recorded from the validation run rather than invented in advance.

### 20. Application validation gate

Before Slice 7H implementation may be checkpointed:

- targeted Prettier on the two authored files: PASS;
- targeted ESLint on the two authored files: PASS;
- TypeScript `npx tsc --noEmit`: PASS;
- production application build: PASS;
- `git diff --check`: PASS;
- implementation diff restricted exactly to the two frozen authored files;
- no migration file added or modified;
- generated Supabase types unchanged;
- generated route tree restored before commit.

### 21. Preview-only deployment boundary

Every governed Slice 7H push to:

`architecture-rebuild`

must be independently reconciled to a Vercel Preview deployment.

Required evidence for each push:

- exact Git SHA;
- exact Git branch `architecture-rebuild`;
- Vercel state `READY`;
- deployment target is not Production;
- branch Preview alias is present.

No manual Production deployment is authorized.

The previously existing Production deployment must not be replaced by Slice 7H.

### 22. Preview authentication boundary

Controlled authenticated functional acceptance for Slice 7H is performed locally with disposable fixtures.

The absence of usable remote Preview authentication state must not be "fixed" merely to manufacture a Preview smoke test.

Slice 7H does not authorize creating remote:

- Auth users;
- organization memberships;
- role grants;
- bookings;
- payment evidence;
- schedule evidence;
- business fixtures

solely for Preview acceptance.

If a valid pre-existing isolated Preview authentication environment is unavailable, Preview application verification is limited to deployment/build reconciliation and any unauthenticated surface that can be observed without remote state mutation.

### 23. Production and merge containment

Slice 7H authorizes no:

- Production Supabase read;
- Production Supabase write;
- Production Supabase migration;
- remote payment mutation;
- Production Vercel deployment;
- Git merge into `main`;
- Supabase branch merge;
- payment reversal release;
- booking-confirmation release;
- preparation runtime release;
- safety runtime release;
- Stage 8 -> 9 runtime release;
- Stage 9 -> 10 runtime release;
- Stage 10 -> 11 implementation;
- Sprint 10 release.

Existing containment remains:

- Git `main` merge: **HOLD**
- Supabase branch merge: **HOLD**
- Production database mutation: **HOLD**
- Production application release/redeployment: **HOLD**

### 24. Commit discipline

Slice 7H follows the established three-stage governed commit discipline:

1. technical-design freeze documentation commit;
2. exact two-file implementation commit;
3. implementation checkpoint documentation commit.

Each commit is pushed and reconciled independently.

Every `architecture-rebuild` push must be verified as a Vercel Preview deployment before proceeding to the next governed commit.

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

## Sprint 10 Slice 7H - Controlled Advance Payment Evidence - Implementation Checkpoint

### Implementation evidence

Sprint 10 Slice 7H controlled advance-payment evidence runtime implementation completed locally, was fully validated, committed, pushed and Preview-reconciled on 2026-08-18.

- Freeze commit: `65e51b134143a2810069982173e34b64454be3ca`
- Implementation commit: `811aa2cf2fe13571708c0795f7b636fc084e0834`
- Implementation commit message: `feat: add controlled advance payment evidence`
- Implementation parent: `65e51b134143a2810069982173e34b64454be3ca`
- Branch: `architecture-rebuild`

The implementation commit contains exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

Implementation diff:

- `src/lib/booking.functions.ts`: 76 additions / 0 deletions;
- `src/routes/_authenticated/bookings.tsx`: 323 additions / 6 deletions;
- total: 399 additions / 6 deletions.

No migration, generated Supabase type, generated route-tree, package, lockfile, access-control, preparation, safety, team-assignment or external-creative file is part of the implementation commit.

### Delivered payment capability model

`listBookingWorkspace()` continues to resolve canonical effective permissions through:

`effective_permissions(ORGANIZATION_ID)`

and now derives:

- `canReadPayment` from `permissions.has("payment.read")`;
- `canRecordPayment` from `permissions.has("payment.record")`.

No hard-coded role-name payment authorization model was introduced.

These booleans are presentation/read-containment signals only.

Canonical database RPC authorization remains authoritative.

### Delivered canonical payment read model

When `canReadPayment === true`, the booking workspace calls:

`get_booking_payment_summary(uuid)`

only for bookings already present in the canonical visible booking workspace.

The application does not calculate the required advance or financial totals itself.

Rendered financial truth comes from the canonical summary fields:

- accepted quotation total;
- required advance;
- valid collected amount;
- outstanding advance;
- advance-satisfied state;
- payment count;
- reversal count;
- confirmed-with-advance-shortfall signal.

When `canReadPayment === false`:

- the summary RPC is not called by the workspace;
- payment amounts are not rendered;
- payment counts are not rendered;
- payment controls are not rendered.

### Delivered payment mutation boundary

Slice 7H adds exactly one new payment mutation server function:

`recordBookingPayment`

It calls only:

`record_booking_payment(...)`

The server function:

- uses `requireSupabaseAuth`;
- validates booking UUID;
- validates positive whole-INR amount;
- validates the canonical payment-method enum;
- validates an offset-aware received timestamp;
- normalizes blank optional reference/note values;
- surfaces database errors;
- returns the authoritative payment row.

No direct INSERT, UPDATE or DELETE path against `booking_payments` was introduced.

No reversal RPC and no booking-confirmation RPC were exposed by Slice 7H.

### Delivered controlled payment UI

The `/bookings` runtime now displays canonical advance evidence only for actors with payment-read capability.

The record-payment control is additionally contained to:

- canonical Stage 7 / `advance_pending`;
- payment-read capability;
- payment-record capability;
- an available canonical payment summary;
- `advance_satisfied === false`.

The record-payment form accepts exactly:

- whole-INR amount;
- payment method;
- received timestamp;
- optional external reference;
- optional note.

Canonical payment methods are:

- `cash`;
- `upi`;
- `bank_transfer`;
- `card`;
- `other`.

The UI does not block overpayment.

Payment evidence remains append-only and intentionally non-idempotent.

Submit is disabled while a mutation is pending, but no fake client-side deduplication was introduced.

### Advance satisfaction containment

Payment satisfaction is explicitly not treated as:

- booking confirmation;
- shoot reservation;
- preparation start;
- safety readiness;
- team assignment;
- arbitrary journey advancement.

After successful payment recording, the runtime invalidates:

`["booking-workspace"]`

and refetches canonical state.

No optimistic financial totals, journey movement or scheduling state are fabricated client-side.

### Controlled local runtime acceptance

Disposable authenticated local fixtures exercised all frozen Slice 7H acceptance cases.

#### Case A - unpaid canonical summary

A canonical Stage 7 booking with a proposed, unreserved shoot plan was rendered for an authorized Founder.

The UI and database showed:

- accepted quotation total: INR 30,000;
- required advance: INR 15,000;
- valid collected: INR 0;
- outstanding advance: INR 15,000;
- advance satisfied: false;
- payment count: 0;
- reversal count: 0;
- journey stage: `advance_pending`;
- journey version: 1;
- schedule version: 1;
- schedule state: `proposed`.

The record-payment control was available.

Result: **PASS**

#### Case B - partial payment

The Founder recorded one INR 5,000 Cash payment through the Slice 7H UI.

Canonical state refreshed to:

- valid collected: INR 5,000;
- outstanding advance: INR 10,000;
- advance satisfied: false;
- payment count: 1.

The booking remained:

- `advance_pending`;
- journey version 1;
- schedule version 1;
- schedule state `proposed`.

No booking confirmation or reservation occurred.

Result: **PASS**

#### Case C - threshold satisfaction without confirmation

The Founder recorded a second INR 10,000 UPI payment with external reference:

`S7H-UPI-THRESHOLD`

Canonical state became:

- valid collected: INR 15,000;
- outstanding advance: INR 0;
- advance satisfied: true;
- payment count: 2;
- reversal count: 0.

The record-payment control disappeared after authoritative refresh.

The booking still remained:

- `advance_pending`;
- journey version 1;
- schedule version 1;
- schedule state `proposed`;
- reserved schedule rows: 0.

No automatic booking confirmation or reservation occurred.

Result: **PASS**

#### Case D - actor without payment.record

A Photographer fixture without `payment.record` received no payment mutation control.

A forced direct RPC attempt was rejected with SQLSTATE `42501` and:

`record_booking_payment: payment.record permission required`

The permission-test booking remained at zero payment rows.

Result: **PASS**

#### Case E - actor without payment.read

The same Photographer fixture also lacked `payment.read`.

The booking UI exposed no canonical payment summary, amounts, counts or payment controls.

A forced direct summary RPC attempt was rejected with SQLSTATE `42501` and:

`get_booking_payment_summary: payment.read permission required`

The canonical booking/payment state remained unchanged.

Result: **PASS**

#### Case F - runtime containment

Runtime source inspection confirmed the Bookings module exposes only:

- canonical workspace read;
- canonical payment-summary read when authorized;
- schedule proposal;
- schedule reschedule;
- payment recording.

No runtime reference exists in the Slice 7H implementation to:

- `reverse_booking_payment`;
- `confirm_booking_after_advance`;
- `start_pre_shoot_preparation`;
- `mark_booking_shoot_scheduled`;
- generic journey advancement;
- preparation mutation;
- safety mutation;
- team-assignment mutation;
- external-creative mutation.

Authenticated visual acceptance also confirmed those controls are not exposed.

Result: **PASS**

### Database regression gate

Slice 7H authored no SQL.

Dedicated regression validation completed successfully:

- Sprint 9 advance-payment evidence pgTAP: PASS;
- Sprint 9 booking-confirmation pgTAP: PASS;
- Sprint 10 shoot-schedule pgTAP: PASS;
- combined dedicated gate: **255/255 PASS**.

Complete local database regression:

- **1083/1083 PASS** across 16 pgTAP files.

Database lint:

`npx supabase db lint --local`

Result:

`No schema errors found`

Result: **PASS**

### Application validation gate

Application validation completed successfully:

- targeted Prettier: PASS;
- targeted ESLint: PASS;
- production build: PASS;
- TypeScript `npx tsc --noEmit`: PASS;
- `git diff --check`: PASS;
- generated `src/routeTree.gen.ts` restored after tooling regeneration;
- final implementation boundary contained exactly the two frozen runtime files.

Result: **PASS**

### Disposable fixture cleanup

After local acceptance:

- the development server was stopped;
- generated route-tree output was restored;
- `npx supabase db reset --local --yes` completed successfully;
- the complete migration chain reapplied successfully.

Post-reset disposable evidence returned to zero for all checked acceptance tables, including:

- `auth.users`;
- `organization_members`;
- `member_role_grants`;
- `families`;
- `quotations`;
- `bookings`;
- `booking_payment_requirements`;
- `booking_payments`;
- `booking_payment_reversals`;
- `booking_shoot_schedules`;
- `booking_journey_states`;
- `booking_stage_transitions`.

Result: **PASS**

### Git implementation reconciliation

Implementation commit:

`811aa2cf2fe13571708c0795f7b636fc084e0834`

was created directly on top of the Slice 7H freeze:

`65e51b134143a2810069982173e34b64454be3ca`

Pre-push divergence was:

- remote-only commits: 0;
- local-only commits: 1.

The implementation push completed as the expected fast-forward:

`65e51b1..811aa2c`

Post-push:

- local HEAD = `811aa2cf2fe13571708c0795f7b636fc084e0834`;
- tracking ref = `811aa2cf2fe13571708c0795f7b636fc084e0834`;
- divergence = 0 / 0;
- worktree = clean.

GitHub independently confirmed:

- branch `architecture-rebuild` points to the exact implementation SHA;
- the implementation is exactly one commit above the freeze;
- exactly the two frozen implementation files changed.

Result: **PASS**

### Vercel Preview reconciliation

The implementation push produced the expected Vercel Preview deployment:

- deployment ID: `dpl_DQj9T9PHMHoypvT9UKQQeaN17DkG`;
- Git SHA: `811aa2cf2fe13571708c0795f7b636fc084e0834`;
- Git branch: `architecture-rebuild`;
- state: `READY`;
- target: `null`;
- source: `git`;
- branch alias: `memory-keeper-os-git-architecture-rebuild-team1996.vercel.app`.

The exact SHA, branch, READY state and non-Production target were independently reconciled through authenticated read-only Vercel metadata.

The previously recorded Production deployment remains:

- deployment ID: `dpl_varrdvzMrBSfnNVjhwNnF4mrSzAL`;
- Git SHA: `e570da0b7715f992edd4cd870437d3dbbaf7324a`;
- target: `production`;
- state: `READY`.

The Slice 7H implementation push did not replace Production.

Result: **PASS**

### Production and merge containment

Slice 7H implementation performed no:

- Production Vercel deployment;
- Production Supabase write;
- Production Supabase migration;
- remote payment mutation;
- booking confirmation;
- payment reversal;
- Git merge into `main`;
- Supabase branch merge;
- preparation, safety, team-assignment or external-creative runtime release;
- Sprint 10 release.

The containment gates remain:

- Git `main` merge: **HOLD**
- Supabase branch merge: **HOLD**
- Production database mutation: **HOLD**
- Production application release/redeployment: **HOLD**

### Slice 7H checkpoint status

**IMPLEMENTATION VALIDATED / PUSHED / PREVIEW DEPLOYMENT VERIFIED / NOT PRODUCTION RELEASED**

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

## Sprint 10 Slice 7I - Controlled Booking Confirmation & Schedule Reservation - Technical Design Freeze

### Status

**TECHNICAL DESIGN FROZEN / IMPLEMENTATION NOT STARTED / NOT PRODUCTION RELEASED**

### Objective

Expose the existing canonical advance-satisfied booking-confirmation operation through the authenticated Bookings workspace without creating any alternative journey, financial or scheduling authority.

Slice 7I will allow an authorized actor to deliberately confirm an eligible Stage 7 booking only through:

`confirm_booking_after_advance(uuid)`

The canonical database RPC remains the sole authority for confirmation eligibility, schedule reservation and Stage 7 -> Stage 8 advancement.

### Existing canonical database authority

Slice 7I authors no new SQL.

The existing canonical confirmation RPC already enforces:

- authenticated actor;
- active organization membership;
- `booking.confirm` permission;
- branch scope;
- exactly one canonical journey state;
- exact Stage 7 / `advance_pending` first-time confirmation state;
- accepted quotation integrity;
- immutable booking payment-requirement integrity;
- satisfied required advance;
- a current authoritative proposed shoot plan;
- append-only conversion of that proposal into reserved schedule evidence;
- authoritative Stage 7 -> Stage 8 journey advancement;
- canonical `advance_satisfied` transition evidence;
- audit evidence;
- idempotent replay after successful confirmation.

The application must not reproduce those invariants as an alternative source of truth.

### Frozen implementation boundary

Implementation is limited to exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

No migration is expected.

No generated Supabase type change is expected.

No package, lockfile, route-tree, access-control, preparation, safety, team-assignment or external-creative change is expected.

### Permission model

`listBookingWorkspace()` will continue resolving canonical effective permissions through:

`effective_permissions(ORGANIZATION_ID)`

and will additionally derive:

`canConfirmBooking`

from:

`booking.confirm`

This boolean is a presentation-containment signal only.

The database RPC remains authoritative for actual authorization.

No hard-coded role-name authorization may be introduced.

### Server mutation boundary

Add exactly one booking-confirmation server function:

`confirmBookingAfterAdvance`

Input:

- `bookingId`: valid UUID

The server function must:

- use `requireSupabaseAuth`;
- validate the booking UUID;
- call only `confirm_booking_after_advance(...)`;
- surface canonical database errors;
- return the authoritative booking row.

It must not directly mutate:

- `bookings`;
- `booking_journey_states`;
- `booking_stage_transitions`;
- `booking_shoot_schedules`;
- payment evidence;
- preparation evidence;
- safety evidence;
- team assignments.

### Controlled UI eligibility

The confirmation control may be rendered only when all presentation evidence currently available to the Bookings workspace indicates:

- current canonical journey stage is exactly Stage 7 / `advance_pending`;
- actor has `booking.confirm`;
- actor has payment-read capability;
- one canonical payment summary is available;
- `advance_satisfied === true`;
- one current shoot schedule exists;
- current shoot schedule state is `proposed`.

The UI eligibility check is containment only.

It must not be treated as authoritative validation.

A forced or stale request must still rely on the database RPC to reject invalid confirmation.

The confirmation control must not require `shoot.schedule` permission because the canonical confirmation RPC authorizes through `booking.confirm`.

### Confirmation interaction

The action must clearly communicate its coupled canonical effect.

Preferred control label:

`Confirm booking & reserve shoot`

Before mutation, the UI must make clear that confirmation will:

- confirm the booking;
- reserve the current proposed shoot plan;
- advance the booking from Stage 7 to Stage 8.

The UI must not imply that confirmation:

- starts pre-shoot preparation;
- completes preparation;
- marks safety readiness;
- assigns team members;
- marks the shoot scheduled;
- advances beyond Stage 8.

While confirmation is pending, duplicate submission must be disabled.

No optimistic journey or schedule mutation may be fabricated client-side.

### Successful confirmation refresh

After successful confirmation:

`["booking-workspace"]`

must be invalidated/refetched.

The refreshed canonical state should then expose:

- Stage 8 / `booking_confirmed`;
- reserved schedule evidence;
- preserved historical proposed schedule evidence;
- canonical transition history;
- canonical payment summary.

The confirmation control must disappear because the booking is no longer Stage 7.

### Explicit non-goals

Slice 7I does not expose:

- payment reversal;
- generic journey advancement;
- `start_pre_shoot_preparation`;
- `mark_booking_shoot_scheduled`;
- preparation checklist mutation;
- safety-readiness mutation;
- safety signoff;
- team assignment;
- external creative assignment;
- post-confirmation rescheduling beyond the already-existing controlled schedule surface;
- Stage 8 -> Stage 9 advancement;
- Stage 9 -> Stage 10 advancement.

### Runtime acceptance cases

#### Case A - eligible confirmation

Given:

- Stage 7 / `advance_pending`;
- canonical advance satisfied;
- current schedule state `proposed`;
- actor has `booking.confirm`;
- actor can read payment evidence;

the UI must expose:

`Confirm booking & reserve shoot`

Result expected: **PASS**

#### Case B - successful confirmation

Confirmation through the UI must result in canonical database state showing:

- booking remains the same canonical booking;
- journey advances exactly Stage 7 -> Stage 8;
- canonical confirmation transition exists exactly once;
- current schedule becomes authoritative reserved evidence through append-only lineage;
- original proposed schedule remains immutable history;
- no preparation start occurs;
- no Stage 9 or Stage 10 advancement occurs.

Result expected: **PASS**

#### Case C - unsatisfied advance

For zero or partial valid collection:

- confirmation control is absent;
- forced direct confirmation RPC is rejected by the canonical financial gate;
- journey and schedule remain unchanged.

Result expected: **PASS**

#### Case D - proposed schedule missing

With satisfied advance but no current proposed shoot plan:

- confirmation control is absent;
- forced direct confirmation RPC is rejected;
- no Stage 8 transition occurs.

Result expected: **PASS**

#### Case E - actor without booking.confirm

An actor lacking `booking.confirm`:

- receives no confirmation control;
- direct RPC confirmation is rejected;
- canonical booking state remains unchanged.

Result expected: **PASS**

#### Case F - replay containment

After successful confirmation:

- confirmation control is absent;
- direct canonical replay remains idempotent;
- no duplicate confirmation transition is created;
- no duplicate reserved schedule evidence is created.

Result expected: **PASS**

#### Case G - runtime containment

The Slice 7I implementation must introduce no runtime reference to:

- `reverse_booking_payment`;
- `start_pre_shoot_preparation`;
- `mark_booking_shoot_scheduled`;
- generic journey advancement;
- preparation mutation;
- safety mutation;
- team-assignment mutation;
- external-creative mutation.

Result expected: **PASS**

### Validation gate

Before implementation commit:

Application:

- targeted Prettier;
- targeted ESLint;
- `npm run build`;
- `npx tsc --noEmit`;
- `git diff --check`.

Database regression:

- Sprint 9 booking-confirmation pgTAP;
- Sprint 10 shoot-schedule pgTAP;
- complete local database regression;
- `npx supabase db lint --local`.

Runtime acceptance:

- controlled authenticated local fixtures covering Cases A-G;
- fixture cleanup with local database reset afterward.

### Commit containment

Technical-design freeze must be committed separately from implementation.

Expected freeze commit subject:

`docs: freeze sprint 10 slice 7i booking confirmation`

Implementation must not begin until the freeze commit is:

- reviewed;
- committed;
- pushed;
- Git/GitHub reconciled;
- verified as an exact READY Vercel Preview deployment.

### Production containment

Still HOLD:

- Git `main` merge;
- Supabase branch merge;
- Production database mutation;
- Production application release/redeployment.

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**

---

## Sprint 10 Slice 7I - Controlled Booking Confirmation & Schedule Reservation - Implementation Checkpoint

### Status

**IMPLEMENTATION VALIDATED / PUSHED / PREVIEW DEPLOYMENT VERIFIED / NOT PRODUCTION RELEASED**

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**

### Implementation commit

The frozen Slice 7I implementation was committed as:

`4b2a72843eb4a9c1a96db61f3a6a4f546f931d90`

Subject:

`feat: add controlled booking confirmation`

Parent:

`85101977129714e5a56b58eee9ecb6a880d903df`

The implementation changed exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

No migration, generated Supabase type, package, lockfile, route-tree, access-control, preparation, safety, team-assignment or external-creative source change was committed.

### Implemented authority boundary

The authenticated Bookings workspace now exposes the existing canonical:

`confirm_booking_after_advance(uuid)`

through one controlled application server mutation:

`confirmBookingAfterAdvance`

The server mutation:

- requires authenticated Supabase context;
- validates the booking UUID;
- calls only the canonical `confirm_booking_after_advance(...)` RPC;
- surfaces canonical database errors;
- returns the authoritative booking row;
- performs no direct booking, journey, transition, schedule, payment, preparation, safety or team-assignment table writes.

`listBookingWorkspace()` now derives the presentation-only:

`canConfirmBooking`

signal from canonical effective permission:

`booking.confirm`

No role-name authorization was introduced.

### UI containment

The dedicated:

`Confirm booking & reserve shoot`

control is rendered only when presentation evidence shows:

- exact Stage 7 / `advance_pending`;
- actor has `booking.confirm`;
- actor can read canonical payment evidence;
- canonical payment summary exists;
- `advance_satisfied === true`;
- current authoritative shoot schedule exists;
- current schedule state is `proposed`.

The UI does not require `shoot.schedule` permission for confirmation.

The control explicitly communicates that the operation:

- confirms the booking;
- reserves the current proposed shoot plan;
- advances exactly Stage 7 -> Stage 8.

It explicitly does not claim to:

- start or complete pre-shoot preparation;
- mark safety readiness;
- assign team members;
- mark the shoot scheduled;
- advance beyond Stage 8.

Duplicate submission is disabled while the confirmation mutation is pending.

After success, `["booking-workspace"]` is invalidated/refetched and no optimistic journey or schedule state is fabricated.

### Application validation

Targeted formatting:

- Prettier: **PASS**

Targeted lint:

- ESLint: **PASS**

Application build:

- `npm run build`: **PASS**
- client build: **PASS**
- SSR build: **PASS**
- Nitro build: **PASS**

The build emitted only previously observed non-blocking warnings.

TypeScript validation:

- `npx tsc --noEmit` passed after TanStack regenerated the route tree during the application build;
- after restoring the frozen checked-in `src/routeTree.gen.ts`, the same command exposed 12 unrelated route-registration errors across six pre-existing route source files;
- none of those six files changed in Slice 7I;
- the missing route registrations are absent from the frozen checked-in route tree;
- this is classified as a **PRE-EXISTING GENERATED-ROUTE BASELINE DEFECT / NOT A SLICE 7I REGRESSION**.

Source diff validation:

- `git diff --check`: **PASS**

### Database regression

Sprint 9 booking-confirmation pgTAP:

- files: 1
- tests: 65
- result: **PASS**

Sprint 10 shoot-schedule pgTAP:

- files: 1
- tests: 111
- result: **PASS**

Targeted database tests:

- total: 176
- result: **PASS**

Complete local database regression:

- files: 16
- tests: 1083 / 1083
- result: **PASS**

Local database lint:

- `npx supabase db lint --local`
- result: **PASS**
- schema errors: none.

### Runtime acceptance

#### Case A - eligible confirmation

Eligible Stage 7 booking with:

- satisfied canonical advance;
- proposed current schedule;
- `booking.confirm`;
- payment-read capability

displayed:

`Confirm booking & reserve shoot`

Result: **PASS**

#### Case B - successful confirmation

Confirmation through the authenticated UI produced:

- same canonical booking;
- exact Stage 7 -> Stage 8 advancement;
- Stage 8 / `booking_confirmed`;
- exactly one canonical `advance_satisfied` transition;
- immutable proposed schedule version 1 preserved;
- append-only reserved schedule version 2 created;
- reserved version 2 linked to proposed version 1;
- confirmation control removed after authoritative refetch;
- no Stage 9 or Stage 10 advancement exposed.

Result: **PASS**

#### Case C - unsatisfied advance

Zero and partial advance fixtures:

- displayed no confirmation control;
- forced canonical RPC calls were rejected with the required-advance-unsatisfied gate;
- remained Stage 7;
- created no confirmation transition;
- retained the existing proposed schedule unchanged.

Result: **PASS**

#### Case D - proposed schedule missing

Satisfied-advance fixture without a current proposed shoot plan:

- displayed no confirmation control;
- forced canonical RPC was rejected with:
  `confirm_booking_after_advance: current proposed shoot plan required`;
- remained Stage 7;
- created no confirmation transition;
- had no schedule mutation.

Result: **PASS**

#### Case E - actor without booking.confirm

A controlled local actor with:

- `booking.read = true`;
- `payment.read = true`;
- `shoot.schedule = true`;
- `booking.confirm = false`

could read the otherwise eligible Stage 7 booking, payment evidence and proposed schedule but received no confirmation control.

Forced canonical RPC was rejected with:

`confirm_booking_after_advance: booking.confirm permission required`

The booking remained:

- Stage 7 / `advance_pending`;
- advance satisfied;
- zero confirmation transitions;
- one unchanged proposed schedule row.

Result: **PASS**

#### Case F - replay containment

Direct canonical replay after successful confirmation:

- returned the same booking;
- remained Stage 8 / `booking_confirmed`;
- retained exactly one confirmation transition;
- retained exactly two schedule rows;
- retained exactly one reserved schedule row;
- retained latest schedule version 2;
- created no duplicate reservation or transition.

Result: **PASS**

#### Case G - runtime source containment

The implementation introduced no forbidden runtime mutation reference and no direct table mutation for:

- payment reversal;
- generic journey advancement;
- pre-shoot preparation;
- mark-shoot-scheduled;
- preparation mutation;
- safety mutation;
- team-assignment mutation;
- external-creative mutation.

Result: **PASS**

### Runtime fixture cleanup

All Slice 7I runtime fixtures were local-only.

After acceptance:

`npx supabase db reset --local`

replayed the complete migration chain and restored the canonical local baseline.

Post-reset verification confirmed:

- canonical organization returned to `suspended`;
- fixture Auth users: 0;
- fixture custom roles: 0;
- fixture organization members: 0;
- fixture families: 0;
- fixture bookings: 0.

A transient local Storage health warning occurred during container restart.

Subsequent:

`npx supabase status`

confirmed the local development stack was running with the required API, Auth and database services available.

Result: **PASS**

### Git reconciliation

Before push:

- local implementation SHA = `4b2a72843eb4a9c1a96db61f3a6a4f546f931d90`;
- remote branch SHA = `85101977129714e5a56b58eee9ecb6a880d903df`;
- divergence = 0 / 1;
- merge base = exact Slice 7I freeze SHA;
- worktree = clean.

The implementation push completed as the expected fast-forward:

`8510197..4b2a728`

Post-push:

- local HEAD = `4b2a72843eb4a9c1a96db61f3a6a4f546f931d90`;
- tracking ref = `4b2a72843eb4a9c1a96db61f3a6a4f546f931d90`;
- divergence = 0 / 0;
- worktree = clean.

GitHub independently confirmed:

- branch `architecture-rebuild` points to the exact implementation SHA;
- parent is the exact Slice 7I freeze SHA;
- subject is `feat: add controlled booking confirmation`;
- exactly the two frozen implementation files changed.

Result: **PASS**

### Vercel Preview reconciliation

The implementation push produced the expected Vercel Preview deployment:

- deployment ID: `dpl_CJpvrxBVUFGJt9jos7qEKEdS11XE`;
- Git SHA: `4b2a72843eb4a9c1a96db61f3a6a4f546f931d90`;
- Git branch: `architecture-rebuild`;
- Git subject: `feat: add controlled booking confirmation`;
- state: `READY`;
- target: `null`;
- source: GitHub;
- branch alias: `memory-keeper-os-git-architecture-rebuild-team1996.vercel.app`.

The exact SHA, branch, READY state and non-Production target were independently reconciled through authenticated read-only Vercel metadata.

The previously recorded Production deployment remains:

- deployment ID: `dpl_varrdvzMrBSfnNVjhwNnF4mrSzAL`;
- Git SHA: `e570da0b7715f992edd4cd870437d3dbbaf7324a`;
- target: `production`;
- state: `READY`.

The Slice 7I implementation push did not replace Production.

Result: **PASS**

### Production and merge containment

Slice 7I implementation performed no:

- Production Vercel deployment;
- Production Supabase write;
- Production Supabase migration;
- remote booking mutation;
- Git merge into `main`;
- Supabase branch merge;
- preparation, safety, team-assignment or external-creative runtime release;
- Sprint 10 release.

The containment gates remain:

- Git `main` merge: **HOLD**
- Supabase branch merge: **HOLD**
- Production database mutation: **HOLD**
- Production application release/redeployment: **HOLD**

### Slice 7I checkpoint status

**IMPLEMENTATION VALIDATED / PUSHED / PREVIEW DEPLOYMENT VERIFIED / NOT PRODUCTION RELEASED**

Sprint 10 remains **IMPLEMENTATION IN PROGRESS / NOT RELEASED**.

---

## Sprint 10 Slice 7J - Canonical Pre-Shoot Preparation Read Surface - Technical Design Freeze

### Status

**TECHNICAL DESIGN FROZEN / IMPLEMENTATION NOT STARTED / NOT PRODUCTION RELEASED**

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**

### Objective

Expose existing canonical pre-shoot preparation evidence through the authenticated Bookings workspace without introducing any preparation mutation or journey-advancement authority.

Slice 7J is read-only.

The application will expose canonical evidence already governed by:

- `booking_preparations`;
- `booking_preparation_items`;
- canonical `prep.read` permission;
- existing row-level security and branch scope.

The database remains the sole authority for preparation visibility and preparation evidence integrity.

### Existing canonical database authority

Slice 7J authors no new SQL.

Canonical preparation evidence already exists in:

`booking_preparations`

with authoritative fields including:

- preparation identity;
- booking identity;
- preparation start timestamp;
- preparation actor.

Canonical preparation checklist evidence already exists in:

`booking_preparation_items`

with authoritative fields including:

- service category;
- taxonomy version;
- item key;
- item label;
- required / optional classification;
- canonical sort order;
- satisfied / unsatisfied state;
- satisfaction timestamp;
- satisfaction actor;
- creation and update attribution.

Authenticated SELECT access to both preparation surfaces is controlled through canonical:

`prep.read`

and existing booking / branch scope enforcement.

The application must not recreate those authorization rules as an alternative source of truth.

### Generated type evidence

The existing generated Supabase type file already contains canonical table types for:

- `booking_preparations`;
- `booking_preparation_items`.

Slice 7J therefore expects no generated type change.

### Frozen implementation boundary

Implementation is limited to exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

No migration is expected.

No generated Supabase type change is expected.

No package change is expected.

No lockfile change is expected.

No route-tree change is expected.

No role, permission or ACL migration is expected.

No preparation mutation is expected.

No safety mutation is expected.

No team-assignment mutation is expected.

No external-creative mutation is expected.

### Permission model

`listBookingWorkspace()` will continue resolving canonical effective permissions through:

`effective_permissions(ORGANIZATION_ID)`

and will additionally derive:

`canReadPreparation`

from:

`prep.read`

This boolean is a presentation-containment signal only.

Canonical database RLS remains authoritative for actual preparation-row visibility.

No hard-coded role-name authorization may be introduced.

### Canonical workspace read model

Add canonical preparation evidence to `BookingWorkspaceData`.

Expected additions:

- `bookingPreparations`
- `bookingPreparationItems`
- `canReadPreparation`

Preparation rows must use the already-generated canonical table row types.

No manually duplicated preparation domain model should be introduced when the generated table types already represent the canonical schema.

### Preparation loading boundary

When:

`canReadPreparation === true`

and visible bookings exist, `listBookingWorkspace()` may read canonical preparation evidence for those visible booking IDs.

Expected read sequence:

1. read `booking_preparations` scoped to the visible booking IDs;
2. collect the returned canonical preparation IDs;
3. if preparation IDs exist, read `booking_preparation_items` scoped to those preparation IDs;
4. preserve canonical checklist ordering by `sort_order`.

When:

`canReadPreparation === false`

the workspace must return:

- no preparation rows;
- no preparation item rows.

The application must not attempt to infer hidden preparation evidence.

### Read authority containment

Slice 7J must not:

- infer that preparation exists merely because a booking is Stage 9 or later;
- fabricate a preparation start timestamp;
- fabricate checklist items from UI taxonomy constants;
- fabricate required / optional classification;
- infer satisfaction from journey stage;
- infer satisfaction from safety or scheduling state;
- expose preparation evidence when canonical rows are absent;
- bypass canonical RLS.

Only canonical rows returned by Supabase may be displayed.

### Read-only UI surface

The authenticated Bookings workspace may display a dedicated canonical pre-shoot preparation section only when:

- actor has `prep.read`;
- canonical preparation evidence exists for the booking.

The section may display:

- preparation started timestamp;
- checklist item label;
- required / optional status;
- satisfied / unsatisfied status;
- satisfaction timestamp when present.

The checklist must render in canonical `sort_order`.

The UI may identify the evidence as canonical pre-shoot preparation.

The UI must not expose a preparation mutation control in Slice 7J.

### No-evidence state

For an actor with `prep.read`, a booking without canonical preparation evidence may display an explicit read-only no-evidence state such as:

`Pre-shoot preparation has not started.`

This message is permitted only as a statement that no canonical preparation row is currently visible.

It must not imply that the booking is eligible to start preparation.

Eligibility remains controlled by the separate canonical mutation RPC.

### Stage semantics

Stage 8 / `booking_confirmed` with no preparation row:

- preparation evidence must not be fabricated;
- no Stage 8 -> 9 control is introduced in Slice 7J.

Stage 9 / `pre_shoot_preparation` with canonical preparation evidence:

- the authoritative preparation instance may be displayed;
- canonical checklist items may be displayed.

Later stages with preserved canonical preparation evidence:

- the historical preparation evidence may remain visible;
- the UI must not imply that preparation state is currently mutable.

Journey stage is context only.

Preparation evidence comes from preparation tables.

### Explicit non-goals

Slice 7J does not expose:

- `start_pre_shoot_preparation`;
- preparation-item satisfaction mutation;
- preparation-item unsatisfaction or reversal;
- generic journey advancement;
- Stage 8 -> Stage 9 mutation;
- Stage 9 -> Stage 10 mutation;
- `mark_booking_shoot_scheduled`;
- safety-readiness mutation;
- safety signoff;
- team assignment;
- external creative assignment;
- payment mutation;
- booking confirmation;
- schedule mutation.

### Runtime acceptance cases

#### Case A - authorized preparation read

Given:

- actor has `prep.read`;
- booking has one canonical preparation instance;
- canonical preparation items exist;

the Bookings workspace must display the canonical preparation evidence.

Result expected: **PASS**

#### Case B - canonical checklist fidelity

For visible preparation items, the UI must preserve:

- canonical item labels;
- required / optional classification;
- satisfied / unsatisfied state;
- satisfaction timestamp when present;
- canonical `sort_order`.

No checklist item may be synthesized client-side.

Result expected: **PASS**

#### Case C - no preparation evidence

For a visible booking with:

- actor has `prep.read`;
- no canonical preparation row;

the workspace must:

- display no fabricated checklist;
- display no fabricated preparation timestamp;
- avoid implying that preparation has already started.

A read-only canonical no-evidence message is permitted.

Result expected: **PASS**

#### Case D - actor without prep.read

An actor lacking:

`prep.read`

must receive:

- no preparation section containing canonical preparation evidence;
- no preparation rows in the application workspace model;
- no preparation item rows in the application workspace model.

Canonical database authorization remains authoritative.

Result expected: **PASS**

#### Case E - historical preparation visibility

For a later-stage booking that retains canonical preparation evidence:

- the historical preparation instance remains readable when authorized;
- checklist evidence remains canonical;
- the UI does not imply that preparation is currently mutable.

Result expected: **PASS**

#### Case F - no mutation surface

The Slice 7J UI must expose no control that invokes:

- `start_pre_shoot_preparation`;
- preparation-item mutation;
- Stage 8 -> 9 advancement;
- Stage 9 -> 10 advancement.

Result expected: **PASS**

#### Case G - source containment

The Slice 7J implementation must introduce no runtime reference to:

- `start_pre_shoot_preparation`;
- preparation-item mutation RPCs;
- `mark_booking_shoot_scheduled`;
- safety mutation;
- team-assignment mutation;
- external-creative mutation;
- generic journey advancement.

The committed implementation must remain limited to exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

Result expected: **PASS**

### Validation gate

Before implementation commit:

Application:

- targeted Prettier;
- targeted ESLint;
- `npm run build`;
- `npx tsc --noEmit`;
- `git diff --check`.

The known checked-in TanStack generated-route baseline defect must continue to be classified separately if reproduced unchanged and unrelated to Slice 7J.

Database regression:

- `supabase/tests/sprint10_pre_shoot_preparation_test.sql`;
- `supabase/tests/sprint10_preparation_items_test.sql`;
- complete local database regression;
- `npx supabase db lint --local`.

Current dedicated pgTAP plans:

- pre-shoot preparation: 71 tests;
- preparation items: 83 tests.

Runtime acceptance:

- authenticated local fixtures covering Cases A-G;
- fixture cleanup with local database reset afterward.

### Commit containment

The technical-design freeze must be committed separately from implementation.

Expected freeze commit subject:

`docs: freeze sprint 10 slice 7j preparation read surface`

Implementation must not begin until the freeze commit is:

- reviewed;
- committed;
- pushed;
- Git / GitHub reconciled;
- verified as an exact READY Vercel Preview deployment.

### Production containment

Still HOLD:

- Git `main` merge;
- Supabase branch merge;
- Production database mutation;
- Production application release/redeployment.

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**

---

## Sprint 10 Slice 7J - Canonical Pre-Shoot Preparation Read Surface - Implementation Checkpoint

### Implementation evidence

Sprint 10 Slice 7J canonical pre-shoot preparation read-surface implementation completed locally, was fully validated, committed, pushed and Preview-reconciled on 2026-08-19.

- Freeze commit: `6c9e40ca157e71876be989584f20ff97a66ab7bd`
- Implementation commit: `5769188463e1fb4111add329dc6cc20a79f22d7f`
- Implementation commit message: `feat: add canonical preparation read surface`
- Implementation parent: `6c9e40ca157e71876be989584f20ff97a66ab7bd`
- Branch: `architecture-rebuild`

The implementation commit contains exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

Implementation diff:

- `src/lib/booking.functions.ts`: 50 additions / 0 deletions;
- `src/routes/_authenticated/bookings.tsx`: 121 net additions across 124 changed lines;
- total: 171 additions / 3 deletions.

No migration, generated Supabase type, generated route-tree, package, lockfile, role/permission ACL, preparation mutation, safety, team-assignment or external-creative file is part of the implementation commit.

### Delivered canonical preparation read model

`listBookingWorkspace()` continues to resolve canonical effective permissions through:

`effective_permissions(ORGANIZATION_ID)`

and now additionally derives:

`canReadPreparation`

from:

`permissions.has("prep.read")`

This remains a presentation-containment signal only.

Canonical database RLS and branch scope remain authoritative for actual preparation-row visibility.

No role-name authorization was introduced.

The workspace now exposes canonical generated table row types for:

- `booking_preparations`;
- `booking_preparation_items`.

`BookingWorkspaceData` now includes:

- `bookingPreparations`;
- `bookingPreparationItems`;
- `canReadPreparation`.

No manually duplicated preparation-domain schema was introduced.

### Canonical preparation loading behavior

When `canReadPreparation === true`, the workspace:

1. reads `booking_preparations` only for already-visible booking IDs;
2. collects only the returned canonical preparation IDs;
3. reads `booking_preparation_items` only for those preparation IDs;
4. preserves canonical checklist ordering through `sort_order`.

When the actor lacks `prep.read`:

- `bookingPreparations` remains empty;
- `bookingPreparationItems` remains empty;
- no preparation query result is inferred or fabricated;
- the preparation UI surface is not rendered.

The application does not infer preparation existence from journey stage.

The application does not infer checklist satisfaction from:

- journey stage;
- schedule state;
- safety state;
- team state.

### Delivered read-only Bookings UI

The authenticated Bookings workspace now exposes a dedicated section labelled:

`Canonical pre-shoot preparation`

with the title:

`Preparation checklist`

for actors authorized through canonical `prep.read`.

When canonical preparation exists, the surface displays database-backed evidence including:

- preparation start timestamp;
- canonical checklist item count;
- item label;
- required / optional classification;
- satisfied / unsatisfied state;
- satisfaction timestamp when present.

Canonical item ordering is preserved.

The read surface explicitly identifies the evidence as read-only and states that journey, scheduling, safety and team state do not substitute for canonical preparation checklist evidence.

No preparation mutation control was introduced.

### Canonical no-evidence behavior

For an authorized actor when no canonical preparation row is visible, the UI displays:

`Pre-shoot preparation has not started.`

The accompanying copy explicitly states that:

- no canonical preparation instance is currently visible;
- this read-only state does not determine eligibility to start preparation.

No start timestamp is fabricated.

No checklist is synthesized.

No Stage 8 -> 9 action is exposed.

### Source-containment validation

Final source validation confirmed that Slice 7J added no application call to:

- `.rpc(...)`;
- `.insert(...)`;
- `.update(...)`;
- `.delete(...)`;
- `.upsert(...)`.

No implementation reference was added to mutation RPCs including:

- `start_pre_shoot_preparation`;
- `update_pre_shoot_preparation_item`;
- `mark_booking_shoot_scheduled`.

Final implementation boundary remained exactly:

- `src/lib/booking.functions.ts`;
- `src/routes/_authenticated/bookings.tsx`.

`src/routeTree.gen.ts` was transiently regenerated by development/build tooling and restored to the frozen HEAD before commit.

Result: **PASS**

### Application validation

Targeted formatting:

- Prettier on the two implementation files: **PASS**

Targeted lint:

- ESLint on the two implementation files: **PASS**

Diff integrity:

- `git diff --check`: **PASS**

Production application build:

- `npm run build`: **PASS**
- build completed successfully;
- generated application output completed normally;
- only the previously known Nitro warning remained.

TypeScript validation requires explicit baseline attribution.

With the build-generated route tree:

- `npx tsc --noEmit`: exit `0`;
- no TypeScript diagnostics.

After restoring the frozen checked-in `src/routeTree.gen.ts`:

- `npx tsc --noEmit`: exit `2`;
- exactly 12 diagnostics reproduced;
- diagnostics were confined to six pre-existing route files:
  - `src/routes/_authenticated/guide-reviews.tsx`;
  - `src/routes/_authenticated/leads.tsx`;
  - `src/routes/_authenticated/leads_.$leadId.tsx`;
  - `src/routes/_authenticated/tasks.tsx`;
  - `src/routes/_authenticated/whatsapp.tsx`;
  - `src/routes/memory-guide.tsx`;
- no diagnostic referenced either Slice 7J implementation file;
- the diagnostics reproduce the known checked-in route-tree registration baseline defect.

Classification:

**TypeScript baseline attribution PASS / Slice 7J regression NO**

The frozen-tree raw TypeScript invocation is not represented as a raw pass.

### Database validation

Slice 7J authors no SQL.

Dedicated canonical preparation foundation pgTAP:

- `sprint10_pre_shoot_preparation_test.sql`
- Files: 1
- Tests: 71
- Result: **PASS**

Dedicated canonical preparation-item pgTAP:

- `sprint10_preparation_items_test.sql`
- Files: 1
- Tests: 83
- Result: **PASS**

Complete local database regression:

- Files: 16
- Tests: 1083
- Result: **PASS**

Database lint:

- `npx supabase db lint --local`
- `No schema errors found`
- Result: **PASS**

No migration was created or modified.

No generated Supabase type was changed.

### Runtime acceptance - Case A

Authorized canonical preparation read:

- Founder authenticated through the local Supabase runtime;
- both controlled Slice 7J bookings were visible;
- the prepared booking exposed the canonical preparation section;
- preparation start evidence was visible;
- canonical checklist count was 11.

Result: **PASS**

### Runtime acceptance - Case B

Canonical checklist fidelity:

The prepared Maternity booking displayed the canonical taxonomy in authoritative order, including:

- Session brief reviewed;
- Client preparation guidance shared;
- Participant plan confirmed;
- Wardrobe and styling plan confirmed;
- Set / prop plan confirmed;
- Location and arrival plan confirmed;
- Inspiration / reference preferences reviewed;
- Non-safety special requests reviewed;
- Maternity wardrobe selection confirmed;
- Maternity session style / mood confirmed;
- Partner / family participation plan reviewed.

Runtime evidence confirmed:

- exact canonical item labels;
- required / optional classification;
- canonical sort order;
- one satisfied required item;
- satisfied timestamp preserved;
- remaining items unsatisfied;
- no satisfaction evidence synthesized for unsatisfied rows.

Result: **PASS**

### Runtime acceptance - Case C

Authorized booking with no canonical preparation:

- Stage 8 `booking_confirmed` booking remained visible;
- preparation read section was visible because the Founder possessed `prep.read`;
- the surface displayed `Pre-shoot preparation has not started.`;
- no preparation start timestamp was fabricated;
- no checklist was fabricated;
- no preparation-start control was exposed;
- the no-evidence copy did not represent eligibility.

Result: **PASS**

### Runtime acceptance - Case D

Actor without `prep.read`:

The Accounts fixture actor retained canonical booking visibility through existing booking-read authority but possessed no `prep.read`.

Runtime evidence confirmed:

- both controlled bookings remained visible;
- no canonical pre-shoot preparation section rendered;
- no checklist evidence rendered;
- workspace preparation arrays remain empty unless `canReadPreparation` is true;
- canonical database authorization remains authoritative.

Result: **PASS**

### Runtime acceptance - Case E

Later-stage retained historical preparation evidence:

A controlled local fixture-only journey-state construction moved the prepared booking from Stage 9 to Stage 10 solely to validate historical read behavior.

The fixture construction intentionally did not call canonical:

`mark_booking_shoot_scheduled(...)`

and intentionally did not fabricate canonical Stage 9 -> 10 provenance.

Containment evidence after fixture construction:

- booking stage: Stage 10 / `shoot_scheduled`;
- journey-state version: 4;
- retained preparation count: 1;
- retained checklist item count: 11;
- retained satisfied count: 1;
- fixture transition `slice7j_case_e_fixture`: exactly 1;
- canonical `shoot_scheduled` transition: 0;
- canonical `booking.shoot_scheduled` audit event: 0.

Founder runtime evidence then confirmed:

- Stage 10 / Shoot Scheduled was visible;
- canonical preparation evidence remained visible;
- original preparation start evidence remained unchanged;
- all 11 checklist items remained visible;
- original satisfaction evidence remained unchanged;
- the surface remained explicitly read-only;
- later journey stage did not imply preparation mutability.

Result: **PASS**

### Runtime acceptance - Case F

Mutation containment:

Across Stage 8, Stage 9 and controlled Stage 10 runtime states, Slice 7J exposed no:

- preparation-start action;
- preparation checklist satisfaction mutation;
- preparation unsatisfaction/reversal action;
- Stage 8 -> 9 action;
- Stage 9 -> 10 action;
- generic journey-advance action.

Static source containment independently confirmed no newly added mutation call.

Result: **PASS**

### Runtime acceptance - Case G

Final implementation containment after runtime testing:

- development server stopped;
- generated route tree restored from frozen HEAD;
- final workspace contained exactly the two frozen implementation files before commit;
- mutation grep returned no added database mutation call;
- preparation-specific mutation grep returned no result;
- `git diff --check` remained clean;
- HEAD remained the technical-freeze commit until the controlled implementation commit.

Result: **PASS**

### Disposable runtime fixture cleanup

All runtime fixtures were local-only and disposable.

After runtime acceptance:

`npx supabase db reset --local`

completed successfully.

Cleanup verification confirmed:

- Slice 7J Auth users: 0;
- Slice 7J fixture families: 0;
- bookings: 0;
- booking preparations: 0;
- preparation items: 0;
- canonical organization returned to migration baseline `suspended`.

No remote Auth, organization, booking, preparation, schedule, payment or journey fixture was created for Slice 7J runtime acceptance.

Result: **PASS**

### Git reconciliation

Controlled implementation push advanced:

`architecture-rebuild`

from:

`6c9e40ca157e71876be989584f20ff97a66ab7bd`

to:

`5769188463e1fb4111add329dc6cc20a79f22d7f`

Post-push reconciliation confirmed:

- local HEAD = exact implementation SHA;
- remote HEAD = exact implementation SHA;
- divergence = `0 / 0`;
- workspace = clean.

GitHub independently confirmed:

- branch `architecture-rebuild` points to `5769188463e1fb4111add329dc6cc20a79f22d7f`;
- parent is `6c9e40ca157e71876be989584f20ff97a66ab7bd`;
- subject is `feat: add canonical preparation read surface`;
- commit contains exactly the two frozen implementation files.

Result: **PASS**

### Vercel Preview reconciliation

The implementation push produced the expected Vercel Preview deployment:

- deployment ID: `dpl_7HE3FioCWbNfoS4EmPRUCDxCfq8h`;
- deployment URL: `memory-keeper-qk676a8os-team1996.vercel.app`;
- Git SHA: `5769188463e1fb4111add329dc6cc20a79f22d7f`;
- Git branch: `architecture-rebuild`;
- Git subject: `feat: add canonical preparation read surface`;
- state: `READY`;
- target: `null`;
- source: GitHub;
- branch alias: `memory-keeper-os-git-architecture-rebuild-team1996.vercel.app`.

The exact SHA, branch, READY state and non-Production target were independently reconciled through authenticated read-only Vercel metadata.

The previously recorded Production deployment remains:

- deployment ID: `dpl_varrdvzMrBSfnNVjhwNnF4mrSzAL`;
- Git SHA: `e570da0b7715f992edd4cd870437d3dbbaf7324a`;
- target: `production`;
- state: `READY`.

The Slice 7J implementation push did not replace Production.

Result: **PASS**

### Production and merge containment

Slice 7J implementation performed no:

- Production Vercel deployment;
- Production Supabase write;
- Production Supabase migration;
- remote preparation mutation;
- remote journey mutation;
- Git merge into `main`;
- Supabase branch merge;
- preparation mutation runtime release;
- safety runtime release;
- team-assignment runtime release;
- Stage 8 -> 9 runtime release;
- Stage 9 -> 10 runtime release;
- Sprint 10 release.

The containment gates remain:

- Git `main` merge: **HOLD**
- Supabase branch merge: **HOLD**
- Production database mutation: **HOLD**
- Production application release/redeployment: **HOLD**

### Slice 7J implementation checkpoint status

**IMPLEMENTATION VALIDATED / PUSHED / GITHUB VERIFIED / PREVIEW DEPLOYMENT VERIFIED / NOT PRODUCTION RELEASED**

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**

---

## Sprint 10 Slice 7K - Controlled Pre-Shoot Preparation Mutations - Technical Design Freeze

### Status

**TECHNICAL DESIGN FROZEN / IMPLEMENTATION NOT STARTED / NOT PRODUCTION RELEASED**

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**

### Objective

Expose the existing canonical pre-shoot preparation mutations through the authenticated Bookings workspace without introducing new database authority or exposing Stage 9 -> 10 progression.

Slice 7K consumes exactly two existing canonical mutation RPCs:

- `start_pre_shoot_preparation(uuid)`;
- `update_pre_shoot_preparation_item(uuid, boolean)`.

The database remains the sole authority for:

- mutation authorization;
- branch scope;
- journey-state eligibility;
- authoritative reserved-schedule eligibility;
- preparation creation;
- canonical checklist instantiation;
- checklist satisfaction evidence;
- actor attribution;
- audit evidence;
- journey transition evidence.

### Existing canonical database authority

Slice 7K authors no new SQL.

`start_pre_shoot_preparation(uuid)` already requires:

- authenticated actor;
- active organization membership;
- `prep.write`;
- `booking.stage.advance`;
- booking branch scope when applicable;
- exactly one canonical journey state;
- exact Stage 8 / `booking_confirmed` for first execution;
- latest authoritative shoot schedule in `reserved` state;
- authoritative supported service category;
- canonical Stage 9 / `pre_shoot_preparation`.

First execution atomically:

- creates the one canonical `booking_preparations` row;
- snapshots the canonical taxonomy-v1 preparation checklist;
- appends `pre_shoot_preparation_started` transition evidence;
- advances journey state exactly Stage 8 -> 9;
- increments journey version exactly once;
- appends `booking.pre_shoot_preparation_started` audit evidence.

Exact Stage 9 replay remains server-side idempotent when the authoritative preparation/checklist structure is valid.

`update_pre_shoot_preparation_item(uuid, boolean)` already requires:

- authenticated actor;
- active organization membership;
- `prep.write`;
- booking branch scope when applicable;
- exactly one canonical journey state;
- exact Stage 9 / `pre_shoot_preparation`;
- canonical item ownership by the booking preparation.

The RPC permits only satisfaction-state mutation.

Same-state retry is a true server-side no-op.

A real satisfaction-state change canonically owns:

- `is_satisfied`;
- `satisfied_at`;
- `satisfied_by`;
- `updated_at`;
- `updated_by`;
- one `booking.preparation_item_updated` audit event.

### Generated type evidence

Existing generated Supabase types already contain:

`start_pre_shoot_preparation`

with:

`Args: { p_booking_id: string }`

and canonical `booking_preparations` return shape.

Existing generated Supabase types already contain:

`update_pre_shoot_preparation_item`

with:

`Args: { p_preparation_item_id: string; p_satisfied: boolean }`

and canonical `booking_preparation_items` return shape.

Slice 7K therefore authorizes no generated Supabase type change.

### Exact implementation boundary

Implementation is restricted exactly to:

- `src/lib/booking.functions.ts`;
- `src/routes/_authenticated/bookings.tsx`.

No migration is authorized.

No generated Supabase type change is authorized.

No package or lockfile change is authorized.

No role or permission migration is authorized.

No route change is authorized.

`src/routeTree.gen.ts` may be transiently regenerated by development/build tooling but must not remain in the implementation commit.

### Permission presentation model

`listBookingWorkspace()` will continue resolving canonical effective permissions through:

`effective_permissions(ORGANIZATION_ID)`.

Slice 7K may additionally expose:

`canWritePreparation`

from:

`permissions.has("prep.write")`

and:

`canAdvanceBookingStage`

from:

`permissions.has("booking.stage.advance")`.

These booleans are presentation-containment signals only.

The database RPCs remain authoritative.

No hard-coded role-name authorization is permitted.

### Controlled preparation-start server function

Slice 7K may add one authenticated POST server function:

`startPreShootPreparation`

validated with exactly one booking UUID input.

It invokes only:

`start_pre_shoot_preparation`

with:

`p_booking_id`.

The application must not directly:

- insert `booking_preparations`;
- insert `booking_preparation_items`;
- insert journey transitions;
- update journey state;
- append preparation-start audit events.

After successful RPC completion, the UI must refresh authoritative workspace state.

No optimistic preparation/checklist/journey fabrication is permitted.

### Preparation-start UI containment

A Start pre-shoot preparation control may render only when client-visible state indicates all of:

- current stage key = `booking_confirmed`;
- current stage order = 8;
- no canonical preparation row is visible;
- latest authoritative visible schedule has state `reserved`;
- `canWritePreparation === true`;
- `canAdvanceBookingStage === true`.

These checks do not independently prove eligibility.

The action must remain described as a dedicated controlled Stage 8 -> 9 preparation-start operation.

The UI must not expose preparation start:

- before Stage 8;
- at Stage 9;
- after Stage 9;
- when the current visible schedule is absent;
- when the current visible schedule is only proposed;
- when either required presentation permission is absent.

Canonical RPC rejection remains final.

### Controlled preparation-item server function

Slice 7K may add one authenticated POST server function:

`updatePreShootPreparationItem`

validated with:

- preparation-item UUID;
- boolean satisfied state.

It invokes only:

`update_pre_shoot_preparation_item`.

The application must not directly update `booking_preparation_items`.

After successful RPC completion the application must refresh authoritative workspace state.

No optimistic mutation is permitted.

### Checklist mutation UI containment

Per-item mutation controls may render only when:

- a canonical preparation row is visible;
- the canonical preparation item row is visible;
- current stage key = `pre_shoot_preparation`;
- current stage order = 9;
- `canWritePreparation === true`.

For an unsatisfied canonical item, the UI may expose:

`Mark satisfied`

For a satisfied canonical item, the UI may expose:

`Mark outstanding`

No other preparation-item mutation is authorized.

The application must not permit editing:

- `service_category`;
- `taxonomy_version`;
- `item_key`;
- `item_label`;
- `is_required`;
- `sort_order`;
- `created_at`;
- `created_by`;
- satisfaction actor attribution;
- satisfaction timestamp directly.

Those remain canonical database evidence.

### Evidence-copy semantics

Slice 7J's canonical preparation evidence remains the read foundation.

When exact Stage 9 mutation authority is available, the UI must clearly distinguish:

- immutable canonical checklist identity/taxonomy;
- the one controlled mutable field: satisfaction state.

The UI must not continue describing currently mutable Stage 9 satisfaction state as wholly read-only.

For Stage 10 or any later stage, retained preparation evidence must again be explicitly historical/read-only.

Journey stage remains context.

Preparation evidence remains sourced only from canonical preparation tables.

### Explicit non-goals

Slice 7K does not expose:

- `mark_booking_shoot_scheduled`;
- Stage 9 -> Stage 10 mutation;
- generic journey advancement;
- preparation bulk-complete action;
- preparation deletion;
- preparation-instance editing;
- checklist taxonomy editing;
- checklist deletion;
- safety readiness mutation;
- safety signoff;
- team assignment;
- external creative assignment;
- payment mutation;
- booking confirmation mutation beyond already existing Slice 7I behavior;
- new shoot-schedule mutation beyond existing governed scheduling behavior.

### Runtime acceptance cases

#### Case A - authorized controlled preparation start

Given:

- actor has required canonical mutation permissions;
- booking is exact Stage 8 / `booking_confirmed`;
- latest authoritative schedule is reserved;
- no preparation exists;

the UI exposes the dedicated start control.

After success, authoritative refresh must show:

- one canonical preparation;
- canonical checklist items;
- exact Stage 9 / `pre_shoot_preparation`;
- journey version incremented once;
- canonical preparation-start transition/audit evidence.

Result expected: **PASS**

#### Case B - preparation-start control containment

The start control must not render when any client-visible prerequisite is absent, including:

- wrong journey stage;
- no reserved authoritative schedule;
- preparation already exists;
- no `prep.write`;
- no `booking.stage.advance`.

Database rejection remains final authority.

Result expected: **PASS**

#### Case C - canonical checklist satisfaction

At exact Stage 9, an authorized actor may mark one visible canonical unsatisfied item satisfied.

After authoritative refresh:

- that exact item is satisfied;
- canonical satisfaction timestamp is visible;
- canonical satisfaction actor attribution remains database-owned;
- unrelated items remain unchanged.

Result expected: **PASS**

#### Case D - canonical checklist reversal

At exact Stage 9, an authorized actor may mark the same satisfied item outstanding.

After authoritative refresh:

- that exact item is unsatisfied;
- canonical satisfaction timestamp is cleared;
- canonical satisfaction actor is cleared;
- unrelated items remain unchanged.

Result expected: **PASS**

#### Case E - later-stage historical containment

For a booking later than Stage 9 that retains canonical preparation evidence:

- preparation evidence remains readable when authorized;
- checklist evidence remains canonical;
- no item satisfaction mutation control renders;
- no preparation-start control renders.

Result expected: **PASS**

#### Case F - permission containment

An actor without preparation mutation authority must receive no Slice 7K preparation mutation controls.

Existing read visibility remains independently governed by `prep.read`.

Result expected: **PASS**

#### Case G - no Stage 9 -> 10 mutation

Slice 7K exposes no control invoking:

- `mark_booking_shoot_scheduled`;
- generic journey advancement;
- any Stage 9 -> 10 operation.

Result expected: **PASS**

#### Case H - source containment

The implementation commit must remain limited exactly to:

- `src/lib/booking.functions.ts`;
- `src/routes/_authenticated/bookings.tsx`.

New Slice 7K database mutation references must be restricted exactly to:

- `start_pre_shoot_preparation`;
- `update_pre_shoot_preparation_item`.

No new direct table write may be introduced.

Result expected: **PASS**

### Validation gate

Before implementation commit:

Application validation:

- targeted Prettier;
- targeted ESLint;
- `npm run build`;
- `npx tsc --noEmit`;
- `git diff --check`;
- exact two-file source containment.

The known checked-in TanStack route-tree TypeScript baseline defect must continue to be attributed separately if reproduced unchanged and unrelated to Slice 7K.

Database regression:

- `supabase/tests/sprint10_pre_shoot_preparation_test.sql`;
- `supabase/tests/sprint10_preparation_items_test.sql`;
- complete local pgTAP suite;
- `npx supabase db lint --local`.

Current dedicated test plans are:

- preparation start: 71;
- preparation checklist: 83.

Actual complete-suite totals must be recorded from the validation run.

Runtime acceptance:

- controlled authenticated local fixtures covering Cases A-H;
- no remote business fixture required;
- local fixture cleanup with database reset after acceptance evidence is captured.

### Commit discipline

Slice 7K follows the governed three-commit sequence:

1. technical-design freeze documentation commit;
2. exact two-file implementation commit;
3. implementation checkpoint documentation commit.

Implementation must not begin until this technical freeze has been:

- reviewed;
- committed;
- pushed;
- Git/GitHub reconciled;
- independently reconciled to an exact READY non-Production Vercel Preview deployment.

### Production containment

Still HOLD:

- Git `main` merge;
- Supabase branch merge;
- Production database mutation;
- Production application release/redeployment.

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**

## Sprint 10 Slice 7K - Controlled Pre-Shoot Preparation Mutations - Implementation Checkpoint

**Status:** IMPLEMENTATION VALIDATED / PUSHED / GITHUB VERIFIED / IMPLEMENTATION PREVIEW VERIFIED / NOT PRODUCTION RELEASED

### Governed identities

- Technical design freeze:
  `ac45ce1b421ab6c3c8787899af76f52239d81cb3`
- Implementation:
  `b6f0f7aa34afa078eed6cc41f9c2ba00b7b8b1ce`
- Implementation parent:
  `ac45ce1b421ab6c3c8787899af76f52239d81cb3`
- Implementation subject:
  `feat: add controlled pre-shoot preparation mutations`
- Working branch:
  `architecture-rebuild`

### Exact implementation boundary

The Slice 7K implementation commit changes exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

No migration, generated Supabase type, package manifest, lockfile,
permission migration, role migration, route definition, safety surface,
team-assignment surface, external-creative surface, or Stage 9 -> 10
implementation is part of Slice 7K.

`src/routeTree.gen.ts` was regenerated transiently by TanStack tooling during
build/runtime validation and was restored to the frozen checked-in version.
It is not part of the implementation commit.

### Implemented controlled mutation surface

Slice 7K adds exactly two application RPC integrations:

1. `start_pre_shoot_preparation`
   - exposed through `startPreShootPreparation`
   - accepts only canonical booking UUID input
   - performs no direct preparation, checklist, journey, transition, or audit
     table writes from application code
   - delegates final authorization and state-transition authority to the
     canonical database RPC

2. `update_pre_shoot_preparation_item`
   - exposed through `updatePreShootPreparationItem`
   - accepts only canonical preparation-item UUID plus boolean satisfaction
     state
   - performs no direct checklist table writes from application code
   - delegates final authorization, attribution, timestamp ownership and audit
     evidence to the canonical database RPC

No Slice 7K application reference to `mark_booking_shoot_scheduled` was added.

### Workspace permission presentation flags

The booking workspace now independently derives:

- `canWritePreparation` from `prep.write`
- `canAdvanceBookingStage` from `booking.stage.advance`

These are UI presentation-containment flags only. They do not replace
canonical database authorization.

No role-name authorization was introduced.

### Start-preparation presentation containment

The `Start pre-shoot preparation` control is rendered only when all visible
presentation conditions are true:

- current canonical stage key is `booking_confirmed`
- current canonical stage order is `8`
- no canonical preparation row is visible
- latest authoritative visible schedule state is `reserved`
- `canWritePreparation` is true
- `canAdvanceBookingStage` is true

The database RPC remains final authority and independently re-checks all
canonical gates.

### Checklist satisfaction presentation containment

Preparation-item mutation controls are rendered only when:

- a canonical preparation exists
- canonical checklist items exist
- current stage key is `pre_shoot_preparation`
- current stage order is `9`
- `canWritePreparation` is true

The only exposed state changes are:

- unsatisfied -> `Mark satisfied`
- satisfied -> `Mark outstanding`

Checklist taxonomy identity remains immutable from this application surface.

### Later-stage preparation behavior

At Stage 10 and later, canonical preparation evidence remains readable for an
actor with `prep.read`, but Slice 7K item mutation controls are absent.

The UI explicitly distinguishes historical/read-only preparation evidence from
the controlled mutable satisfaction state available only at exact Stage 9.

### Source-quality validation

- targeted Prettier:
  PASS
- targeted ESLint:
  PASS
- `git diff --check`:
  PASS
- production application build:
  PASS
- restored source boundary after build:
  exactly the two Slice 7K implementation files

### TypeScript baseline attribution

TanStack build regeneration produced a current generated route tree.

With the generated route tree:

- `npx tsc --noEmit` exit:
  `0`
- generated-tree diagnostics:
  none

After restoring the frozen checked-in route tree:

- raw `npx tsc --noEmit` exit:
  `2`
- diagnostics:
  `12`
- diagnostic files:
  - `src/routes/_authenticated/guide-reviews.tsx`
  - `src/routes/_authenticated/leads.tsx`
  - `src/routes/_authenticated/leads_.$leadId.tsx`
  - `src/routes/_authenticated/tasks.tsx`
  - `src/routes/_authenticated/whatsapp.tsx`
  - `src/routes/memory-guide.tsx`
- Slice 7K authored-file diagnostics:
  none

Classification:

**TypeScript baseline attribution PASS / Slice 7K regression NO**

The frozen-tree raw TypeScript invocation is not recorded as a raw TypeScript
PASS.

### Database regression validation

Dedicated canonical preparation-start pgTAP:

- files:
  `1`
- tests:
  `71`
- result:
  PASS

Dedicated canonical preparation-item pgTAP:

- files:
  `1`
- tests:
  `83`
- result:
  PASS

Complete local database regression:

- files:
  `16`
- tests:
  `1083`
- result:
  PASS

Local database lint:

- schema errors:
  none
- result:
  PASS

### Authenticated local runtime validation

Controlled local runtime fixtures used:

- Founder actor with canonical preparation permissions
- Accounts actor without `prep.read` / `prep.write`
- eligible Stage 8 booking with latest reserved schedule
- blocked Stage 8 booking with latest proposed schedule

Runtime evidence established:

#### Case A - authorized preparation start

PASS.

The eligible Stage 8 booking:

- exposed `Start pre-shoot preparation`
- created exactly one canonical preparation
- instantiated the exact maternity taxonomy-v1 checklist
- created `11` items
- created `8` required items
- began with `0` satisfied items
- advanced exactly to Stage 9 `pre_shoot_preparation`
- incremented journey version `2 -> 3`
- appended exactly one
  `pre_shoot_preparation_started` transition
- appended exactly one
  `booking.pre_shoot_preparation_started` audit event
- did not create an application Stage 10 transition

#### Case B - start containment / database final authority

PASS for the exercised runtime denial paths.

The proposed-only Stage 8 booking:

- did not render the start-preparation control
- direct authenticated RPC invocation was denied with:
  `current authoritative reserved schedule required`
- remained Stage 8
- retained zero preparations

The remaining canonical negative authorization/state branches are covered by
the dedicated `71`-test preparation-start pgTAP contract, including the
independent permission and exact-stage rules.

#### Case C - item satisfaction at Stage 9

PASS.

For canonical item `session_brief_reviewed`:

- `Mark satisfied` succeeded
- canonical `is_satisfied` became true
- `satisfied_at` was database-owned and populated
- `satisfied_by` resolved to the authenticated Founder member
- unrelated checklist items remained unchanged
- checklist containment became:
  `11 total / 1 satisfied / 10 outstanding`
- journey remained Stage 9 / version 3
- exactly one item-level
  `booking.preparation_item_updated` audit event existed
- no Stage 10 transition occurred

#### Case D - controlled reversal

PASS.

For the same canonical item:

- `Mark outstanding` succeeded
- `is_satisfied` returned to false
- `satisfied_at` cleared
- `satisfied_by` cleared
- `updated_by` remained canonical Founder attribution
- checklist containment returned to:
  `11 total / 0 satisfied / 11 outstanding`
- item-level audit count became exactly `2`
- journey remained Stage 9 / version 3
- no application Stage 10 transition occurred

#### Case E - later-stage historical/read-only preparation

PASS.

A fixture-only Stage 9 -> 10 transition with key
`slice7k_fixture_later_stage_read` was used solely to validate historical
read behavior.

At Stage 10:

- canonical preparation remained visible
- all `11` canonical checklist items remained visible
- no `Mark satisfied` control was exposed
- no `Mark outstanding` control was exposed
- no `Start pre-shoot preparation` control was exposed
- UI copy identified the evidence as historical/read-only

This fixture transition is not an application Slice 7K Stage 9 -> 10
implementation.

#### Case F - permission containment

PASS.

The Accounts actor:

- retained booking visibility through `booking.read`
- did not receive canonical preparation visibility because `prep.read` was
  absent
- received no Slice 7K preparation mutation controls

A direct authenticated item-update RPC attempt was denied with:

`update_pre_shoot_preparation_item: prep.write permission required`

The denial was a no-op.

#### Case G - no Stage 9 -> 10 Slice 7K operation

PASS.

Slice 7K adds:

- no `mark_booking_shoot_scheduled` invocation
- no generic journey-advance control
- no preparation-complete operation
- no Stage 9 -> 10 application mutation

#### Case H - exact source and mutation containment

PASS.

The implementation commit contains exactly two source files.

The only new Slice 7K database mutation references are:

- `start_pre_shoot_preparation`
- `update_pre_shoot_preparation_item`

No direct application table writes were added.

### Runtime cleanup

After authenticated local runtime validation:

- `npx supabase db reset --local`:
  PASS
- Slice 7K Auth fixture users:
  `0`
- Slice 7K families:
  `0`
- bookings:
  `0`
- booking preparations:
  `0`
- booking preparation items:
  `0`
- canonical organization restored to:
  `suspended`
- transient generated route tree restored:
  PASS

### Git / GitHub reconciliation

The implementation commit was pushed to:

`architecture-rebuild`

GitHub branch head independently reconciled to:

`b6f0f7aa34afa078eed6cc41f9c2ba00b7b8b1ce`

Implementation parent independently reconciled to:

`ac45ce1b421ab6c3c8787899af76f52239d81cb3`

The remote implementation contains exactly:

- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`

### Implementation Preview reconciliation

Vercel independently produced a non-Production Preview:

- deployment:
  `dpl_8KiSGfXEjZbkEgYv53hRAzYwthYW`
- commit:
  `b6f0f7aa34afa078eed6cc41f9c2ba00b7b8b1ce`
- branch:
  `architecture-rebuild`
- state:
  `READY`
- target:
  `null`
- URL:
  `memory-keeper-h0rt2o6us-team1996.vercel.app`

### Production containment

Production remains unchanged:

- deployment:
  `dpl_varrdvzMrBSfnNVjhwNnF4mrSzAL`
- commit:
  `e570da0b7715f992edd4cd870437d3dbbaf7324a`
- target:
  `production`
- state:
  `READY`

Slice 7K does not authorize:

- merge to Git `main`
- Supabase branch merge
- production database mutation
- production deployment
- production promotion
- production release

### Checkpoint discipline

The next governed commit is documentation-only.

Expected checkpoint commit subject:

`docs: checkpoint sprint 10 slice 7k`

The checkpoint commit must contain only:

`docs/SPRINT_MASTER_REGISTER.md`

Production containment remains HOLD after checkpoint creation.

## Sprint 10 Slice 7L - Canonical Booking Team Assignment Read Model and Read Surface - Technical Design Freeze

**Status:** TECHNICAL DESIGN FROZEN / IMPLEMENTATION NOT STARTED / NOT PRODUCTION RELEASED

### 1. Governed implementation base

Slice 7L begins from exact checkpoint:

`4532f01d3adbe68e702634174b94dd59ce82b243`

Branch:

`architecture-rebuild`

This is the completed Sprint 10 Slice 7K checkpoint.

Implementation must not begin until this freeze is:

- reviewed;
- committed;
- pushed;
- Git/GitHub reconciled;
- independently reconciled to a READY non-Production Vercel Preview.

### 2. Discovery basis

Read-only discovery established the current canonical booking-team authority.

`public.booking_team_assignments` remains the single canonical booking-scoped staffing lifecycle table.

Its current canonical shape is exactly 11 columns:

- `id`;
- `organization_id`;
- `booking_id`;
- `assignment_role`;
- `assigned_member_id`;
- `assigned_external_creative_id`;
- `assigned_at`;
- `assigned_by`;
- `ended_at`;
- `ended_by`;
- `end_reason`.

Assignment subject identity is exactly one of:

- internal organization member;
- external creative.

Current canonical assignment-role vocabulary is exactly:

- `lead_photographer`;
- `assistant`;
- `stylist`;
- `lead_videographer`;
- `supporting_videographer`.

Current cardinality rules remain database-owned:

- at most one current Lead Photographer;
- at most one current Lead Videographer;
- multiple Assistants permitted;
- multiple Stylists permitted;
- multiple Supporting Videographers permitted subject to canonical uniqueness rules.

### 3. Read-boundary finding

`booking_team_assignments` already exposes authenticated canonical SELECT evidence through its forced-RLS booking-derived access boundary.

Authenticated direct:

- INSERT;
- UPDATE;
- DELETE

remain denied.

However, direct application reading of the assignment table alone is insufficient for a human-readable operational surface.

Internal subject display identity resides in canonical organization-member evidence.

External subject display identity resides in:

`public.external_creatives`

Direct authenticated access to `external_creatives` is intentionally denied.

The existing:

`team_access_directory(uuid)`

belongs to the narrower canonical `team.read` domain and must not be used as a substitute for the booking-scoped staffing read boundary.

Actors may legitimately hold `booking.read` without `team.read`.

Slice 7L therefore must not:

- require `team.read` merely to understand staffing on an otherwise-readable booking;
- broaden direct `organization_members` access;
- broaden direct `external_creatives` access;
- expose the general Team directory;
- expose freelancer CRM/contact information;
- use service-role access from the application.

### 4. Architectural decision

Slice 7L introduces one deliberately narrow canonical booking-team read projection.

The read model exists only to present human-readable booking-assignment evidence to actors who already have canonical authority to read the booking.

The new database function is:

`get_booking_team_assignment_history(uuid)`

Conceptual input:

- booking UUID.

It returns booking-scoped immutable assignment evidence only.

At minimum its projection must contain:

- assignment UUID;
- booking UUID;
- assignment role;
- subject type;
- subject UUID;
- subject display name;
- assigned timestamp;
- ended timestamp;
- end reason;
- current-state boolean.

Subject type must distinguish exactly:

- `internal_member`;
- `external_creative`.

No parallel assignment truth is created.

The source of assignment lifecycle truth remains:

`public.booking_team_assignments`

The source of internal display identity remains:

`public.organization_members`

The source of external display identity remains:

`public.external_creatives`.

### 5. Safe identity projection

The read model may expose only the minimum human-readable identity needed to understand a booking assignment.

Permitted subject identity output:

- stable canonical subject UUID;
- subject type;
- display name.

It must not expose from organization-member or external-creative identity sources:

- email;
- phone;
- authentication user ID;
- role-grant history;
- branch-grant history;
- invitation state;
- payroll/employment data;
- private notes;
- contact CRM data.

External creative identity remains a minimal operational identity registry, not a freelancer directory.

### 6. Database authorization contract

`get_booking_team_assignment_history(uuid)` must be:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- executable by `authenticated`;
- denied to `anon`.

The function must independently require:

- authenticated `auth.uid()`;
- an existing canonical booking;
- current active organization membership;
- canonical `booking.read`;
- booking-derived branch scope where applicable.

It must not require:

- `team.read`;
- `booking.team.assign`;
- `booking.write`;
- `booking.stage.advance`;
- `prep.read`;
- `prep.write`;
- `safety.read`;
- `safety.write`;
- `safety.signoff`;
- `shoot.schedule`.

The function must not trust:

- client-supplied organization IDs;
- user-editable metadata;
- application role labels;
- client-computed branch authority.

The booking row resolves organization and branch authority.

### 7. Read-only database behavior

The Slice 7L read model performs no mutation.

It must not:

- insert assignment rows;
- update assignment rows;
- close assignments;
- create external creatives;
- create audit events;
- alter journey state;
- alter preparation state;
- alter safety state;
- alter shoot schedule state.

Read invocation is side-effect free.

No new database permission key or role grant is introduced.

### 8. Assignment history semantics

The read model must preserve complete visible canonical assignment history.

A current assignment is exactly:

`ended_at IS NULL`

A historical assignment is exactly:

`ended_at IS NOT NULL`

Historical rows must not be collapsed into the current subject.

The read result must preserve:

- assignment identity;
- assignment role;
- subject identity;
- original assignment timestamp;
- ending timestamp;
- canonical end reason.

The function may calculate the presentation boolean:

`is_current = ended_at IS NULL`

That boolean is derived presentation state only; lifecycle truth remains the canonical row.

Results must use deterministic ordering.

### 9. All five canonical roles remain visible

Slice 7L must not regress the extended creative foundation to the original three-role model.

The read surface must correctly represent:

- Lead Photographer;
- Assistant;
- Stylist;
- Lead Videographer;
- Supporting Videographer.

It must correctly represent both valid assignment subject forms.

An external assignment must not be mislabeled as an internal member.

An internal assignment must not be mislabeled as a freelancer.

### 10. No readiness inference

Slice 7L displays staffing evidence.

It does not determine whether a booking is ready for Stage 10.

The application must not infer:

- required staffing composition;
- package-specific staffing sufficiency;
- Lead Videographer commercial requirement;
- preparation completeness;
- safety readiness;
- formal safety sign-off completeness;
- Stage 9 -> 10 eligibility.

Those rules remain canonical inside the dedicated database gate.

The UI must not show labels such as:

- Team ready;
- Staffing complete;
- Ready for Shoot Scheduled;
- Stage 10 requirements satisfied

merely from visible assignment rows.

### 11. Booking workspace server integration

`listBookingWorkspace()` may consume the new booking-scoped read projection for bookings already visible through the canonical Bookings workspace.

It must continue to:

- use `requireSupabaseAuth`;
- use server-owned organization configuration;
- obtain bookings through the existing canonical read path;
- preserve existing schedule, payment, preparation and journey behavior.

The application must not query `external_creatives` directly.

The application must not query `organization_members` directly to bypass canonical Team access controls.

The safe booking-team projection is the only new identity-resolution boundary.

### 12. Booking workspace UI

The existing `/bookings` workspace may add a section titled:

`Canonical booking team`

The section is read-only.

It may show:

- assignment role;
- subject display name;
- internal/external subject indicator;
- current/historical state;
- assigned timestamp;
- ended timestamp when present;
- canonical end reason when present.

Current and historical evidence must be visually distinguishable.

If no assignment evidence exists, the UI must render an explicit canonical empty state.

The empty state must not claim that staffing is incomplete or that Stage 10 is blocked.

### 13. No Slice 7L mutation controls

Slice 7L must expose no controls for:

- assigning an internal team member;
- replacing an internal team member;
- unassigning an internal team member;
- creating an external creative;
- assigning an external creative;
- replacing an external creative;
- unassigning an external creative.

Specifically, Slice 7L application code must not invoke:

- `assign_booking_team_member`;
- `create_external_creative`;
- `assign_booking_external_creative`.

Those mutation RPCs remain separately governed.

### 14. Journey containment

Slice 7L introduces no journey mutation.

It must not invoke:

- `mark_booking_shoot_scheduled`;
- generic journey advancement;
- any Stage 10 -> 11 operation.

The current journey surface remains unchanged except that staffing evidence may now be read alongside it.

### 15. Safety and preparation containment

Slice 7L must not widen restricted safety evidence.

It must not query or render new:

- safety readiness details;
- safety sign-off details;
- comfort evidence.

Existing preparation behavior remains unchanged.

Staffing evidence must not be presented as a substitute for preparation or safety evidence.

### 16. Exact implementation boundary

Slice 7L implementation may change exactly:

- `supabase/migrations/20260819150000_sprint10_booking_team_assignment_read_model.sql`;
- `supabase/tests/sprint10_booking_team_assignment_read_model_test.sql`;
- `src/integrations/supabase/types.ts`;
- `src/lib/booking.functions.ts`;
- `src/routes/_authenticated/bookings.tsx`.

No other authored file is part of the Slice 7L implementation commit.

`src/routeTree.gen.ts` may be regenerated transiently by normal TanStack tooling but must be restored before implementation commit.

The generated Supabase type file is permitted only because Slice 7L adds the governed public read RPC.

### 17. Database test contract

The dedicated Slice 7L pgTAP suite must cover at minimum:

- function existence and exact signature;
- exact return projection;
- `SECURITY DEFINER`;
- empty search path;
- authenticated execution;
- anonymous denial;
- active-membership enforcement;
- `booking.read` enforcement;
- branch isolation;
- organization isolation;
- internal subject display-name resolution;
- external subject display-name resolution;
- actor with `booking.read` but without `team.read`;
- all five canonical assignment roles;
- current assignment state;
- historical assignment state;
- deterministic history ordering;
- canonical end-reason preservation;
- direct `external_creatives` authenticated access remains denied;
- direct booking-team INSERT/UPDATE/DELETE remain denied;
- read invocation produces no audit or business mutation.

Existing regression suites must remain green, including:

- `sprint10_booking_team_assignments_test.sql`;
- `sprint10_extended_creative_assignments_test.sql`;
- `sprint10_canonical_team_access_test.sql`;
- `sprint10_stage9_10_gate_test.sql`.

The complete local pgTAP total must be recorded from the actual validation run rather than predicted in this freeze.

### 18. Application validation

Before implementation commit:

- targeted Prettier;
- targeted ESLint;
- `npm run build`;
- `npx tsc --noEmit`;
- `git diff --check`;
- exact five-file implementation containment.

If the known checked-in TanStack route-tree TypeScript baseline defect reproduces unchanged, it must again be separately attributed by comparing generated-tree and frozen-tree TypeScript results.

No Slice 7L-authored diagnostic is acceptable.

### 19. Runtime acceptance

Controlled authenticated local fixtures must cover at minimum:

#### Case A — canonical internal staffing read

A readable booking with current internal assignments shows correct role, subject identity and current status.

#### Case B — assignment history

A replaced or ended assignment remains visible as historical evidence while the current assignment remains distinct.

#### Case C — external creative read

A canonical external creative assignment displays the safe external display name without granting direct authenticated access to `external_creatives`.

#### Case D — booking.read without team.read

An actor with canonical `booking.read` but no `team.read` can read booking-scoped assignment evidence without receiving the Team directory.

#### Case E — no booking.read

An authenticated actor without `booking.read` cannot obtain assignment history through the read RPC.

#### Case F — branch isolation

A branch-scoped booking reader cannot read assignment evidence for a booking outside canonical branch authority.

#### Case G — empty state

A readable booking with zero assignment rows displays an explicit neutral empty state.

#### Case H — mutation containment

The Slice 7L application exposes no team-assignment, external-creative or journey mutation control and introduces no mutation RPC reference.

### 20. Runtime cleanup

All Slice 7L acceptance fixtures must be local only.

After runtime acceptance evidence is captured:

`npx supabase db reset --local`

must remove all Slice 7L fixture residue.

The canonical organization must return to the migration-defined baseline.

### 21. Commit discipline

Slice 7L follows the governed three-commit sequence:

1. technical-design freeze documentation commit;
2. exact implementation commit;
3. implementation checkpoint documentation commit.

Expected freeze commit subject:

`docs: freeze sprint 10 slice 7l booking team read model`

Expected implementation subject:

`feat: add canonical booking team read surface`

Expected checkpoint subject:

`docs: checkpoint sprint 10 slice 7l`

### 22. Production containment

Still HOLD:

- Git `main` merge;
- Supabase branch merge;
- Production database mutation;
- Production application release/redeployment;
- Stage 9 -> 10 application release;
- booking-team mutation UI release;
- Sprint 10 production release.

Sprint 10 remains:

**IMPLEMENTATION IN PROGRESS / NOT RELEASED**
