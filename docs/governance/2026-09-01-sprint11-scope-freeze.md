# Sprint 11 Scope Freeze

Date: 2026-09-01 (Asia/Kolkata)
Status: FROZEN FOR TECHNICAL DESIGN / IMPLEMENTATION NOT YET AUTHORIZED

## Authority

This document freezes the functional boundary for the next Memory Keeper OS milestone after the completed Sprint 10 Production release and Team-contract reconciliation.

Durable authority remains:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`

The implementation roadmap places production and studio operations in Phase 2. The canonical Production journey currently contains Stage 10 `shoot_scheduled`, Stage 11 `shoot_completed`, and Stage 12 `selection_pending`.

## Sprint 11 objective

Sprint 11 is the controlled **Shoot Completion** milestone.

Its exact journey boundary is:

`Stage 10 shoot_scheduled -> Stage 11 shoot_completed`

Sprint 11 must make completion of a real photography session an explicit, server-authoritative, auditable operational event while preserving the evidence required for the next post-shoot milestone.

Sprint 11 does not authorize Stage 11 -> Stage 12 advancement.

## Frozen functional scope

Sprint 11 may introduce only the minimum canonical capability required to complete a scheduled shoot and expose that completion safely to the authenticated studio application.

Authorized functional areas are:

1. **Shoot completion evidence**
   - define the minimum canonical evidence required to record that a scheduled session actually occurred;
   - preserve who recorded completion and when;
   - preserve the booking/session relationship without overwriting historical scheduling or pre-shoot evidence;
   - keep operational completion data auditable.

2. **Controlled journey advancement**
   - provide one canonical server-side operation for exact Stage 10 -> Stage 11 advancement;
   - revalidate authentication, active organization membership, permission, branch scope and exact current lifecycle state at execution time;
   - reject premature, duplicate-invalid or structurally inconsistent advancement;
   - preserve idempotent replay semantics only where the canonical transition history proves the same Stage 10 -> Stage 11 operation already occurred.

3. **Authenticated read model**
   - expose the minimum safe completion evidence required by the Bookings workspace;
   - keep direct-table access closed where RPC authority is the established boundary;
   - do not expose sensitive or unrelated production data merely to support UI convenience.

4. **Bookings UI integration**
   - show the current Stage 10 completion action only when the server contract can legitimately accept it;
   - treat client-side eligibility as presentation guidance only;
   - after Stage 11 completion, render the completion evidence as historical/read-only state;
   - do not expose any Stage 12 advancement action in Sprint 11.

5. **Audit and journey evidence**
   - record the exact Stage 10 -> Stage 11 transition in the canonical journey history;
   - retain the actor/time/evidence necessary to reconstruct the operational event.

6. **Verification surface**
   - add dedicated pgTAP coverage for authorization, branch scope, lifecycle exactness, replay behavior, audit/journey evidence and direct-write boundaries;
   - regenerate Supabase application types from the validated local schema;
   - run relevant regression suites, database lint/advisors, TypeScript checks and Production build verification;
   - perform a controlled local E2E flow that stops at exact Stage 11.

## Technical design freeze required before implementation

This scope freeze does not itself authorize a schema shape, table name, RPC name, field list or UI component design.

Before implementation begins, a narrow technical design freeze must explicitly define:

- the authoritative shoot-completion evidence model;
- whether a new table is required or an existing canonical relation is sufficient;
- the exact controlled RPC signature and replay semantics;
- the permission and branch-scope contract;
- the exact audit event and journey transition contract;
- the safe authenticated read model;
- the exact files and migrations allowed in the implementation branch;
- the dedicated regression and E2E acceptance criteria.

No implementation is authorized until that technical design is reviewed and frozen.

## Existing authority that must remain intact

Sprint 11 must preserve all currently released controls through Stage 10, including:

- booking confirmation and advance-payment authority;
- shoot scheduling authority;
- pre-shoot preparation evidence;
- preparation checklist completion;
- team assignment evidence;
- Safety & Comfort Readiness evidence and sign-off;
- exact Stage 9 -> Stage 10 `shoot_scheduled` transition;
- Team invitation and role-administration contract reconciled to Production.

Sprint 11 must not weaken, bypass or recreate these existing authorities.

## Explicitly out of scope

Sprint 11 does not authorize:

- Stage 11 -> Stage 12 `selection_pending` advancement;
- client image-selection workflow;
- proofing/gallery selection workflow;
- editing queue creation or editing status transitions;
- retouching workflow;
- QC workflow;
- Pixieset gallery publication;
- final delivery;
- album/frame production;
- review requests;
- milestone follow-up;
- media-custody or dual-custody architecture unless separately frozen as a prerequisite;
- AI culling, AI editing or creative-intelligence features;
- public website changes;
- unrelated Team/RBAC redesign;
- unrelated CRM, quotation, payment or package changes;
- wholesale migration of legacy branch functionality;
- Production database mutation or Production deployment without a separate explicit release approval.

## Branch and repository rule

`main` remains the single canonical source-of-truth branch and the Vercel Production Git branch.

The current reconciliation branch is governance-only. Sprint 11 implementation must not begin on it.

After these governance documents are integrated into current `main`, any Sprint 11 implementation branch must be short-lived and created from the then-current `main` head.

## Exit criteria for Sprint 11 implementation

A future Sprint 11 implementation may be considered complete only when:

- the frozen technical design has been implemented without scope expansion;
- exact Stage 10 -> Stage 11 advancement is server-controlled;
- unauthorized and wrong-stage callers are rejected;
- branch scope is enforced;
- completion evidence is reconstructable and auditable;
- transition replay cannot create duplicate completion history;
- existing Stage 10 evidence remains intact;
- the authenticated Bookings UI renders the action and resulting evidence correctly;
- no Stage 12 or later operation exists in the Sprint 11 implementation surface;
- dedicated and relevant regression tests pass;
- database lint and advisors are reviewed;
- generated types are reconciled from the validated schema;
- TypeScript and Production build checks pass;
- controlled local E2E verification reaches and stops at exact Stage 11;
- Preview/review gates pass;
- Production deployment receives a separate explicit approval.

## Decision

Sprint 11 functional scope is **FROZEN** to exact Shoot Completion through Stage 11 `shoot_completed`.

Technical design: NEXT GATE.
Implementation: HOLD until technical design freeze.
Production: NOT AUTHORIZED.
