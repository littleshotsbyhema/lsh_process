# Current Milestone

## Authority

This file is the mutable execution pointer for canonical Memory Keeper OS development.

Update it when an approved checkpoint changes the active programme, repository
operating model, or release state.

Durable product and engineering authority lives in:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`

## Canonical Repository State

`main` is the single canonical source-of-truth branch for Memory Keeper OS.

Current pre-shoot migration base:

`75a25b0822d62e6a06894b4733aa4a6a4daf3aa8`

Repository-history canonicalization anchor:

`d829ca66014f6e0f802425ff3af8368eea8d324b`

The approved Sales CRM booking-confirmation release and canonical repository
governance are contained in `main`.

## Branch Model

Permanent source-of-truth branch:

- `main`

All normal development work must begin from current `main` on a short-lived branch.

Normal implementation work must not be performed directly on `main`.

## Main and Production

The Memory Keeper OS Vercel project treats `main` as its Production Git branch.

Advancing `main` is therefore production-affecting and requires a separate
explicit approval gate.

Feature-branch implementation and Preview validation do not authorize Production.

## Frozen Legacy Architecture Branch

`architecture-rebuild` is frozen legacy reference history.

Frozen head:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new commits to it.

Do not merge it wholesale into `main`.

Legacy functionality must be migrated selectively onto short-lived branches
created from current `main`.

## Current Active Branch

`feature/pre-shoot-operations`

Base:

`75a25b0822d62e6a06894b4733aa4a6a4daf3aa8`

Purpose:

Migrate the remaining approved Sprint 10 pre-shoot operational surface onto the
current canonical application without replaying the legacy branch history.

## Current Checkpoint Status

Design-freeze commit:

`2bcab08d2fabfaa1b9931a75b18a2dff322685b6`

Pre-shoot implementation commit:

`4da45678c0e0ba84423a96add761aea0a49ec8c2`

Latest committed reconciliation checkpoint before the final corrective
remediation:

`74f018e759c1374a43e6f29d5fb4f564ab6ec683`

Final-review corrective remediation is locally verified in this checkpoint.

With this corrective remediation, the intended PR scope contains exactly eleven
changed paths:

- `docs/CURRENT_MILESTONE.md`
- `src/integrations/supabase/types.ts`
- `src/lib/booking.functions.ts`
- `src/routes/_authenticated/bookings.tsx`
- `supabase/migrations/20260819150000_sprint10_booking_team_assignment_read_model.sql`
- `supabase/migrations/20260819170000_sprint10_booking_team_assignment_candidates.sql`
- `supabase/migrations/20260831045642_booking_safety_service_category_read_model.sql`
- `supabase/migrations/20260831080256_booking_safety_review_resilience.sql`
- `supabase/tests/sprint10_booking_team_assignment_mutation_surface_test.sql`
- `supabase/tests/sprint10_booking_team_assignment_read_model_test.sql`
- `supabase/tests/sprint10_safety_readiness_test.sql`

Automated local verification is complete:

- all four authorized migrations applied successfully through the canonical local migration chain;
- the imported read-model suite passes 30/30 assertions;
- the mutation-surface suite passes 42/42 assertions after a narrow
  transaction-local candidate-isolation correction to assertions 10-12;
- the Safety Readiness suite passes 149/149 assertions;
- all 11 `sprint10_*.sql` suites pass 801/801 assertions;
- `supabase db lint --local` reports no schema errors;
- `supabase db advisors --local` reports no issues;
- normalized local type generation proved the corrective generated-type delta is
  exactly +4/-0 for `get_booking_safety_signoff_authority(uuid)`;
- application production build passes;
- TypeScript verification passes against the freshly generated route tree;
- Prettier verification passes;
- `git diff --check` passes;
- `src/routeTree.gen.ts` was regenerated only by tooling during verification and
  restored afterward;
- the intended post-remediation PR boundary is exactly eleven paths;
- both imported team read-model migrations and the imported read-model pgTAP
  suite remain unchanged from their approved frozen legacy blobs;
- the imported mutation-surface suite differs only in assertions 10-12 so its
  seven transaction-local candidate identities are counted deterministically
  without assuming an otherwise empty canonical organization;
- the original safety-category read model passed privileged runtime
  authorization proof for the E2E Photographer while direct quotation-line
  visibility remained unavailable;
- unsupported authoritative service categories now return `NULL` from the
  Safety category read model instead of failing the entire Bookings workspace;
- `get_booking_safety_signoff_authority(uuid)` now exposes narrow,
  booking-specific canonical sign-off authority for authenticated actors with
  the required booking and Safety permissions;
- regression coverage proves Founder -> `founder`, Studio Manager ->
  `studio_manager`, non-Lead Photographer -> `NULL`, and current internal Lead
  Photographer -> `lead_photographer`;
- no Stage 10 -> Stage 11 or shoot-completion implementation was introduced;
- no lead-role replacement/change-reason workflow was introduced;
- existing Sales CRM payment, scheduling, and booking-confirmation controls were
  retained.

Manual local/E2E checkpoint is complete:

- authenticated local Founder access was exercised through the rendered
  Bookings UI;
- a controlled local Newborn booking began at exact Stage 8
  `booking_confirmed` with the required advance satisfied and a reserved shoot
  schedule;
- `start_pre_shoot_preparation` created the canonical preparation instance,
  instantiated 11 checklist items, and performed the exact Stage 8 -> Stage 9
  transition;
- required preparation items were satisfied through the controlled rendered UI
  operations;
- initial Lead Photographer, Lead Videographer, and Stylist assignments were
  performed successfully through the canonical assignment operations;
- an eligible external creative was successfully assigned as Lead Photographer
  through the canonical external-creative assignment path;
- after Lead Photographer and Lead Videographer assignment, the rendered
  candidate directory exposed the required change-reason condition and
  suppressed the normal lead-replacement action;
- an attempted Stage 9 -> Stage 10 transition before preparation completion was
  rejected by canonical server authority with the expected required-preparation
  gate;
- Safety and Comfort readiness were recorded as `Ready`;
- an authenticated E2E Photographer with Safety access but without preparation
  read access rendered the authoritative `maternity` service category and
  recorded the initial canonical readiness revision as Safety `not_applicable`
  and Comfort `ready`;
- Newborn formal Safety Readiness sign-off was successfully recorded by the
  authenticated Founder;
- after all readiness gates were satisfied,
  `mark_booking_shoot_scheduled` performed the exact Stage 9 -> Stage 10
  transition;
- rendered journey history records both
  `Booking Confirmed -> Pre-Shoot Preparation` and
  `Pre-Shoot Preparation -> Shoot Scheduled`;
- at Stage 10 the preparation evidence is historical/read-only, current team
  assignment evidence remains visible, and no Stage 11 or later operational
  advancement was performed.

The controlled local/E2E journey therefore stops at exact Stage 10
`shoot_scheduled`, matching this milestone's approved boundary.

Feature-branch push and Preview validation were complete for the preceding
`74f018e` checkpoint. Fresh push, Preview validation, and final review for this
corrective remediation are separate gates from local verification and commit.

No `main` integration, Production deployment, remote Supabase mutation, or
Production schema mutation has been authorized by this checkpoint.

## Technical Design Freeze

The frozen legacy pre-shoot functional endpoint is:

`2543d1383641e2af85045e7a458b543993136e19`

That commit is reference material for pre-shoot application semantics only.

Do not restore its complete application files over current `main`.

Current production application behavior remains authoritative for all existing
Sales CRM, scheduling, payment, and booking-confirmation behavior.

## Existing Canonical Database Authority

The following required authorities already exist in canonical `main` and must
not be recreated by this milestone:

- `start_pre_shoot_preparation`
- `update_pre_shoot_preparation_item`
- `assign_booking_team_member`
- `assign_booking_external_creative`
- `record_booking_safety_readiness`
- `signoff_booking_safety_readiness`
- `mark_booking_shoot_scheduled`
- `booking_preparations`
- `booking_preparation_items`
- `booking_team_assignments`
- `booking_safety_readiness`
- `booking_safety_signoffs`

The current database contract remains authoritative.

## Authorized Database Additions

Exactly four additive/corrective read-model migrations are authorized for
this PR:

- `supabase/migrations/20260819150000_sprint10_booking_team_assignment_read_model.sql`
- `supabase/migrations/20260819170000_sprint10_booking_team_assignment_candidates.sql`
- `supabase/migrations/20260831045642_booking_safety_service_category_read_model.sql`
- `supabase/migrations/20260831080256_booking_safety_review_resilience.sql`

They introduce or correct:

- `get_booking_team_assignment_history(uuid)`
- `get_booking_team_assignment_candidates(uuid)`
- `get_booking_safety_service_category(uuid)`
- `get_booking_safety_signoff_authority(uuid)`

The first two team read-model migrations are stable frozen legacy blobs.

The first safety read-model migration introduced the restricted authoritative
service-category lookup. The final corrective migration preserves genuine
authorization/integrity failures, returns `NULL` for authoritative categories
outside the Safety taxonomy, and adds the narrow booking-specific sign-off
authority read model.

These migrations do not authorize:

- new permission keys;
- new role grants;
- assignment mutation redesign;
- booking journey redesign;
- destructive schema change.

## Authorized Database Tests

The two legacy dedicated team read-model suites were imported with the two
legacy team read-model migrations:

- `supabase/tests/sprint10_booking_team_assignment_read_model_test.sql`
- `supabase/tests/sprint10_booking_team_assignment_mutation_surface_test.sql`

The read-model suite remains unchanged. The mutation-surface suite contains only
a narrow candidate-fixture isolation correction in assertions 10-12: it now
counts its seven transaction-local candidate identities instead of assuming the
canonical organization contains no other legitimate candidates. The production
candidate RPC is unchanged by that correction.

The existing canonical Safety Readiness suite is also part of the corrective
verification surface:

- `supabase/tests/sprint10_safety_readiness_test.sql`

It now includes regression assertions for unsupported-category resilience,
SECURITY DEFINER/search-path/ACL structure, Founder authority, Studio Manager
authority, non-Lead Photographer denial, and current internal Lead Photographer
authority.

Do not copy the frozen legacy modification to:

- `supabase/tests/sprint10_extended_creative_assignments_test.sql`

That later change reflects repository-wide permission-count drift outside this
pre-shoot slice and contains inconsistent expected-value/message text.

The canonical `main` version remains authoritative unless this branch itself
legitimately changes that tested contract.

## Authorized Application Migration

The current Bookings workspace may be extended with:

1. canonical pre-shoot preparation read evidence;
2. controlled preparation start;
3. controlled preparation-item satisfaction mutation;
4. canonical booking-team assignment history;
5. booking-team candidate discovery;
6. initial Lead Photographer assignment;
7. Stylist assignment;
8. initial Lead Videographer assignment;
9. Safety & Comfort Readiness recording;
10. qualifying Newborn Safety Readiness sign-off;
11. controlled Stage 9 -> Stage 10 `mark_booking_shoot_scheduled` action.

All critical mutations must delegate to existing canonical database RPCs.

Client-side eligibility is presentation guidance only; database authority must
continue to revalidate permissions, branch scope, lifecycle state, safety,
staffing, preparation, and journey gates.

## Lead Replacement Boundary

This milestone does not introduce a lead-role replacement workflow.

If a current Lead Photographer or Lead Videographer already exists, the UI must
not silently replace that assignment without the canonical required
`change_reason`.

Candidate discovery may report that a change reason is required.

A complete replacement/change-reason UX is outside the current authorized scope
unless separately frozen.

## Generated Artifact Rule

Do not copy `src/integrations/supabase/types.ts` from `architecture-rebuild`.

After all four authorized migrations are applied and validated locally,
regenerate Supabase types from the canonical branch schema and inspect the
semantic delta.

Do not copy `src/routeTree.gen.ts` from the legacy branch.

If normal application tooling regenerates the route tree, classify and verify
that output before commit.

## Implementation Order

Use this dependency order:

1. import the two stable team read-model migrations;
2. import their two dedicated pgTAP suites;
3. add the approved safety-category read-model migration;
4. add the final Safety review-resilience/sign-off-authority corrective migration;
5. reset/apply and validate the canonical local migration chain;
6. run dedicated and relevant Sprint 10 regression tests;
7. run database lint and advisors;
8. regenerate Supabase application types from the validated local schema;
9. reconcile and port pre-shoot application functions onto current
   `src/lib/booking.functions.ts`;
10. reconcile and port the pre-shoot Bookings UI onto current
   `src/routes/_authenticated/bookings.tsx`;
11. run TypeScript and application build verification;
12. perform controlled local/E2E pre-shoot journey validation;
13. reconcile review-remediation regression coverage and documentation;
14. review exact branch delta before any commit or push.

## Explicitly Out of Scope

This milestone does not authorize:

- wholesale cherry-picking of legacy commits;
- wholesale restoration of legacy application files;
- legacy generated Supabase types;
- legacy generated route tree;
- stale legacy milestone/register content;
- Stage 10 -> Stage 11 advancement;
- shoot-completion workflow;
- post-shoot handoff;
- selection or financial-authority migration;
- editing, QC, or gallery progression;
- media custody;
- B3 dual-custody transfer;
- remote Supabase mutation;
- Production schema mutation;
- Production deployment;
- public website changes.

## Supabase Trust Boundary

Local Supabase and remote Supabase are separate trust boundaries.

Local reset, migration application, lint, pgTAP verification, fixtures, and type
generation do not authorize any remote operation.

Do not use linked/remote migration deployment or mutate production without
separate explicit authorization.

## Public Website Boundary

The Little Shots public website remains outside Memory Keeper OS migration scope.

Do not alter its repository, Vercel project, deployment, or domain.

## Exit Criteria

The pre-shoot migration is ready for review only when:

- both imported legacy team read-model migrations apply cleanly from a fresh
  local reset;
- both Safety read-model migrations apply cleanly through the canonical local
  migration chain;
- both dedicated imported pgTAP suites pass;
- relevant existing Sprint 10 regression suites pass;
- database lint has no new implementation errors;
- generated Supabase types reflect the validated branch schema;
- no legacy generated type file was copied;
- existing CRM scheduling/payment/booking-confirmation behavior remains intact;
- preparation controls operate through canonical RPC authority;
- team history and candidate discovery enforce organization, permission, branch,
  and lifecycle boundaries;
- Lead Photographer, Stylist, and Lead Videographer controls use canonical
  assignment RPCs;
- existing lead roles are not silently replaced;
- Safety Readiness remains permission- and lifecycle-gated;
- Newborn sign-off presentation is additionally gated by canonical
  booking-specific sign-off authority so an ordinary Photographer is eligible
  only while they are the current internal Lead Photographer;
- Stage 9 -> Stage 10 remains database-controlled;
- no Stage 10 -> Stage 11 behavior is introduced;
- TypeScript verification passes;
- application build passes;
- required local/E2E verification passes;
- exact file boundary is reviewed before commit;
- remote Supabase and Production remain untouched until separately approved.
