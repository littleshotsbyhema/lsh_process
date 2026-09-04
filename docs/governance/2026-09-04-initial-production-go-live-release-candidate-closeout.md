# Initial Production Go-Live Release Candidate Closeout

## Status

APPROVED GOVERNANCE BOUNDARY / RELEASE CANDIDATE READY

## Purpose

This document reconciles the actual repository, application deployment and Production database state after Sprint 13 was merged, and establishes the controlled Initial Production Go-Live Release Candidate boundary.

It does not authorize Production database mutation, Sprint 14 implementation, commit, push, merge or deployment.

## Highest authority

All release decisions remain subordinate to:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`
- `AGENTS.md`

The operating philosophy remains:

**Emotion is the heart. Care is the method. Trust is the standard. Memory is the outcome.**

Release speed must not weaken privacy, safety, consent, historical integrity, authorization or reconstructability.

## Canonical repository baseline

Canonical `main` merge commit:

`71630cb426590e1bbc97aa2a8bdb7fa657933c21`

Merged PR:

`#23 — feat(sprint13): selection completion and editing-pending foundation`

Final Sprint 13 implementation head:

`275efc6d403315de381fda0cb1783d3e90051d86`

Release-candidate branch:

`chore/phase1-release-candidate-closeout`

The release-candidate branch was created from the exact canonical merged `main` commit.

## Sprint 13 operational boundary

Exact transition:

`Stage 12 selection_pending -> Stage 13 editing_pending`

Stage 13 functional truth:

`Selection completed + canonical selected-image set locked + editing handoff accepted`

Sprint 13 introduces no new Stage 14 implementation and no Stage 13 -> Stage 14 transition.

Stage 14 `editing_in_progress` already exists in the journey-stage catalogue from earlier foundation work and is not a Sprint 13 release boundary.

## Sprint 13 canonical database contract

Migration:

`20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`

Immutable canonical evidence:

- `public.booking_selection_completions`
- `public.booking_selected_images`

Authoritative RPCs:

- `public.record_booking_selection_completion(uuid,text[],text,text)`
- `public.mark_booking_editing_pending(uuid)`

Selection permission:

`selection.confirm`

Canonical grants:

- Founder
- Studio Manager
- Client Coordinator

Journey advancement authority remains:

`booking.stage.advance`

## Sprint 13 security closure

The final Sprint 13 implementation preserves:

- RLS enabled and forced on immutable evidence relations;
- controlled authenticated `SECURITY DEFINER` RPC execution;
- fixed empty function search paths;
- explicit active-organization membership checks;
- permission checks using booking branch context;
- branch-scope enforcement;
- authorization before caller-controlled manifest normalization;
- bounded manifest cardinality;
- bounded immutable textual evidence;
- rejection of URI, query, credential, known-secret, data-URI, control-character and Unicode-whitespace abuse patterns;
- immutable evidence and mutation-free exact replay;
- audit metadata that excludes selected image keys and sensitive family information.

## Final pre-merge validation evidence

Sprint 13 final exact-head validation completed with:

- pristine local database reset/replay: PASS
- dedicated Sprint 13 pgTAP: `98/98` PASS
- full database suite: `23 files / 1,487 tests` PASS
- Supabase DB lint: PASS
- Supabase DB advisors: PASS
- canonical final role-permission count: `260`
- generated Supabase types fresh-regeneration byte-equivalence: PASS
- Amendment 13 Unicode semantic proof: PASS
- deterministic selected-image pagination validation at 37, 1,000 and 1,205 rows: PASS
- immutable completion-ID concurrency containment: PASS
- governance Prettier: PASS
- TypeScript: PASS
- production build: PASS
- `git diff --check`: PASS
- exact-head Vercel deployment: SUCCESS
- final Codex exact-head review: COMPLETED with no new material P1/P2 finding

## Application Production reconciliation

PR #23 merged successfully into `main` at:

`71630cb426590e1bbc97aa2a8bdb7fa657933c21`

The Vercel Production deployment for that exact merge commit completed successfully.

Therefore the deployed application code is derived from the Sprint 13 merged repository state.

This is not evidence that Production database migrations have been applied.

## Production database preflight reconciliation

Production read-only preflight established:

Current migration tip:

`20260901180856`

Current role-permission count:

`233`

Sprint 13 objects are absent:

- `public.booking_selection_completions`
- `public.booking_selected_images`
- `public.record_booking_selection_completion(uuid,text[],text,text)`
- `public.mark_booking_editing_pending(uuid)`

Journey catalogue contains:

- Stage 12 `selection_pending`
- Stage 13 `editing_pending`
- Stage 14 `editing_in_progress`

The database is therefore on the supported clean pre-Sprint-13 baseline.

## Pending Production migrations

Exactly two canonical migrations follow the verified Production tip in repository order:

1. `20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `20260903084543_lsh_four_branch_role_scope_brand_owner_foundation.sql`

Validated clean chronology:

`233 -> Sprint 13 -> 236 -> Migration A -> 260`

Validated Migration-A-present chronology used during Sprint 13 testing:

`257 -> Sprint 13 -> 260`

Production currently matches the clean `233` chronology.

The two pending migrations must not be reordered, manually decomposed or partially recreated.

## Production database gate

Production Supabase mutation is:

**HOLD — NOT AUTHORIZED BY THIS DOCUMENT**

The following remain prohibited without separate exact human authorization:

- `supabase db push` against linked Production;
- manual execution of either pending migration;
- migration repair;
- direct schema mutation;
- manual permission-count manipulation;
- linked reset;
- Production reset;
- destructive or force operations.

## Release Candidate goal

The Initial Production Go-Live Release Candidate must establish that the merged system works coherently as one operational product, not merely as individually passing sprints.

The primary journey under verification is:

`Lead -> Family -> Memory Guide -> Quotation -> Payment evidence -> Booking -> Preparation -> Team assignment -> Shoot -> Shoot completion -> Selection -> Editing Pending`

## Release Candidate required verification

The closeout must verify, at minimum:

### Repository and schema

- release branch still descends exactly from canonical `main`;
- pristine local Supabase replay succeeds;
- all migrations apply in canonical order;
- final local role-permission count is `260`;
- Sprint 13 objects and Migration A foundations coexist correctly;
- generated TypeScript database types remain valid.

### Automated quality

- Sprint 13 dedicated pgTAP passes;
- full database pgTAP suite passes;
- Supabase DB lint passes without schema errors;
- Supabase DB advisors report no new material release blocker;
- TypeScript passes;
- production build passes;
- `git diff --check` passes.

### Authorization and isolation

- active role registry is inspected from the actual schema;
- permission grants are verified from the actual schema;
- branch scope is verified;
- negative permission paths are verified;
- cross-organization containment is verified where applicable;
- sensitive safety/private data remains restricted.

### Operational journey

The release candidate must verify the coherent handoffs required to reach Stage 13, including:

- lead and family context;
- Memory Guide context;
- quotation and commercial snapshot;
- payment evidence;
- booking conversion;
- preparation readiness;
- team assignment;
- shoot execution boundary;
- shoot completion evidence;
- Stage 11 -> 12 selection-pending handoff;
- finalized selection evidence;
- Stage 12 -> 13 editing-pending handoff.

## Release blocker policy

Under Sprint Closure Mode:

- P1 material release blockers: STOP and remediate under a governed boundary.
- P2 material release blockers: STOP and remediate under a governed boundary.
- P3 / cosmetic / nice-to-have issues: defer to post-go-live backlog unless evidence shows direct operational risk.

Do not create another amendment chain for cosmetic findings.

Prefer one consolidated release-hardening correction if a genuine blocker exists.

## Explicit non-scope

This release candidate does not authorize:

- Stage 13 -> Stage 14 advancement;
- editing execution;
- editor assignment;
- retouching workflow;
- QC progression;
- gallery publication;
- final delivery;
- heirloom production;
- new provider integration;
- AI culling or editing;
- broad framework migration;
- unrelated technical-debt cleanup;
- durable roadmap restructuring.

## Roadmap reconciliation

The durable Implementation Roadmap is not modified in this closeout.

This record distinguishes:

1. long-term programme taxonomy; and
2. the exact operational boundary already approved and implemented for Initial Production Go-Live.

No later-phase feature may be added merely to make the release more complete.

## Go-live operating material

Before live team use, the final verified system must be converted into role-based operational guidance.

Required:

- detailed Little Shots by Hema OS Role-Based Go-Live Playbook;
- one-page Quick Playbook per active production role;
- Founder / management Go-Live Control Playbook;
- tomorrow-morning launch sequence.

The manuals must be generated from the actual final production role registry, permissions, screens and workflows.

They must not assume roles or actions that do not exist in the verified system.

## Controlled launch sequence

Tomorrow-morning sequence:

`Founder check -> Team login verification -> Role access verification -> Live booking walkthrough -> First real transaction -> Monitor -> End-of-day review`

## Exit criteria

The release candidate may advance to the Production database authorization gate only when:

- repository state is clean and reconciled;
- full local schema replay succeeds;
- automated regression is green;
- active roles and permission boundaries are verified;
- the Phase 1 journey has no known material P1/P2 blocker;
- Production preflight remains compatible with the validated migration chronology.

Production go-live may advance only after:

1. separate Production database migration authorization;
2. successful application of the exact two pending migrations;
3. Production database verification;
4. Production application smoke verification;
5. final role-based operating playbooks;
6. Founder-controlled launch check.

## Current decision

Sprint 13 repository integration:

**COMPLETE**

Vercel Production application deployment:

**SUCCESS**

Initial Production Go-Live Release Candidate:

**READY FOR VERIFICATION**

Production Supabase migration execution:

**HOLD / SEPARATE HUMAN GATE**

Sprint 14:

**NOT AUTHORIZED**
