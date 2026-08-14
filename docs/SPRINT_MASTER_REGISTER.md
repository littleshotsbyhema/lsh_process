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

| Sprint   | Normalized title                                       | Current status    | Production status |
| -------- | ------------------------------------------------------ | ----------------- | ----------------- |
| Sprint 1 | Core Platform, Organization & Security                 | Complete          | Released          |
| Sprint 2 | Families Foundation & Audit                            | Complete          | Released          |
| Sprint 3 | Family Contacts & Communication Controls               | Complete          | Released          |
| Sprint 4 | Children & Memory Profiles                             | Complete          | Released          |
| Sprint 5 | Leads & CRM Foundation                                 | Complete          | Released          |
| Sprint 6 | Lead Workspace & Sales Operations                      | Complete          | Released          |
| Sprint 7 | AI Memory Guide Core Flow & Recommendation Engine      | Complete          | Released          |
| Sprint 8 | Packages, Quotations & Booking Conversion Foundation   | Complete          | Released          |
| Sprint 9 | Advance Payment, Booking Confirmation & KPI Foundation | Release candidate | Not released      |

Current position: **Sprint 8 remains the latest closed Production sprint. Sprint 9 implementation is complete locally, its release-candidate technical gate has passed, and Production rollout has not started.**

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

**IMPLEMENTATION COMPLETE / LOCAL RELEASE CANDIDATE / NOT RELEASED**

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

### Production state

**NOT RELEASED**

As of 2026-08-14:

- no Sprint 9 migration has been applied to the linked Production database;
- no Sprint 9 application commit has been pushed as the Production release;
- Sprint 8 remains the latest closed Production sprint;
- the latest Production database migration remains `20260812131648_sprint8_booking_conversion_foundation.sql`;
- Production rollout must be separately validated and recorded before Sprint 9 can be marked Complete / Released.

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

The following items are known but are **not Sprint 8 release-candidate blockers**:

- legacy mock/Zustand booking-dependent implementations remain in later-sprint domains, but their affected routes are temporarily contained and are not authoritative Sprint 8 booking truth;
- repository-wide TypeScript errors existed before Sprint 7; the Sprint 8 authoritative post-build `npx tsc --noEmit` gate is clean, while TanStack route generation must precede that final typecheck;
- repository-wide ESLint baseline debt existed before Sprint 7 and requires a separate cleanup initiative;
- older `.inputValidator()` usages are deprecated and should be modernized in a bounded refactor;
- Lead-to-Family conversion does not yet transfer every family-contact / memory-goal field automatically;
- Supabase Security Advisor continues to warn about intentional authenticated/public `SECURITY DEFINER` RPC patterns; these must remain individually audited rather than dismissed wholesale.

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

As of 2026-08-14:

- **Latest closed Production sprint:** Sprint 8 — Packages, Quotations & Booking Conversion Foundation
- **Sprint 8 Production application release commit:** `73d12bf070a3148f624598b1c124f1b33f700da4`
- **Latest Production DB migration:** `20260812131648_sprint8_booking_conversion_foundation.sql`
- **Sprint 8 Production state:** Released / Closed
- **Current sprint:** Sprint 9 — Advance Payment, Booking Confirmation & KPI Foundation
- **Sprint 9 state:** Implementation complete / local release candidate validated
- **Sprint 9 local implementation head before RC documentation:** `89956ae`
- **Sprint 9 advance rule:** 50% of final accepted quotation value, whole-INR, half-rupee rounded upward
- **Sprint 9 local regression:** 361/361 pgTAP PASS; DB lint PASS; schema drift none; build/typecheck/targeted lint/format PASS
- **Sprint 9 Production state:** Not released
- **Next action:** commit the Sprint 9 release-candidate register update, then perform a separate Production rollout preflight before any linked database write or application push.
