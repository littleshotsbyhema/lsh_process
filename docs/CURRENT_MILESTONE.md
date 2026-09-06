# Current Milestone

## Authority

This file is the mutable execution pointer for canonical Memory Keeper OS
development.

Durable product and engineering authority lives in:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`
- `AGENTS.md`

Current milestone authority:

- `docs/governance/2026-09-06-t1-role-aware-training-foundation-milestone-approval.md`

Historical Initial Production Go-Live Release Candidate authority:

- `docs/governance/2026-09-04-initial-production-go-live-release-candidate-closeout.md`

## Canonical repository state

`main` remains the single canonical source-of-truth branch and the Vercel
Production Git branch.

Canonical `main` baseline at T1 milestone approval:

`de93945bd5d5f99152646bc8226cf1c2fee67fcd`

This commit merged PR #24:

`chore(release): close Initial Production Go-Live RC`

The previous Stage 13 release-candidate boundary is historical and remains
valid for its frozen evidence.

`architecture-rebuild` remains frozen legacy reference history.

Do not add new work to `architecture-rebuild` or merge it wholesale into
`main`.

## Current programme milestone

Current milestone:

**T1 - Role-Aware Training Foundation**

Status:

**APPROVED / FUNCTIONAL SCOPE FROZEN / TECHNICAL BOUNDARY FROZEN**

Explicit human approval to advance to T1 was provided on 2026-09-06.

## Current execution

Milestone-governance integration branch used for this record:

`chore/t1-training-milestone-approval`

Implementation candidate branch:

`feature/t1-role-aware-training-foundation`

Implementation candidate PR:

`#25 - feat: add role-aware training foundation`

Reviewed candidate head at milestone approval:

`01f79c928cf2208ab7d2c55fc51fc2ebc7908882`

PR #25 may clear its milestone-authority review finding only after this
governance record and execution pointer are present on canonical `main`.

## T1 functional boundary

T1 establishes:

- role-aware training context derived from real role and branch authority;
- organization rollout settings;
- versioned training modules;
- database-authoritative required steps;
- persistent member training profiles;
- immutable training evidence;
- common orientation;
- Founder-only training oversight through `training.read`;
- off / soft / required training gates;
- guided Help & Training application surfaces;
- immutable in-use module versions.

Training remains separate from authorization.

Training completion grants no role, no branch authority, no Founder sign-off
and no Work Ready state.

## Gate boundary

T1 gating uses canonical required-training completion as its reachable
completion state.

Work Ready is not a T1 gate requirement.

Training errors remain fail-open relative to existing authentication and
authorization so training cannot become a replacement access-control system.

Default organization gate mode remains:

`off`

## Work Ready boundary

Work Ready implementation is:

**NOT AUTHORIZED BY T1**

Reserved sign-off fields may exist, but T1 completion must not populate:

- `signed_off_by`;
- `signed_off_at`;
- `work_ready_at`.

A later separately approved milestone must define Work Ready authority.

## T1 repository database target

T1 migrations:

1. `20260905191755_role_aware_training_foundation.sql`
2. `20260906041409_t1_training_progress_cursor_completion_only.sql`

Canonical pristine local replay target after T1:

`261` role-permission mappings.

The additional mapping is the Founder-only:

`training.read`

The prior `260` count remains historical evidence for the approved pre-T1
Stage 13 release-candidate baseline.

## Current candidate validation

Current reviewed T1 candidate evidence:

- pristine local database replay: PASS;
- T1 dedicated pgTAP: `56/56` PASS;
- Supabase local DB lint: PASS;
- generated Supabase type semantic reconciliation: PASS;
- TypeScript: PASS;
- targeted ESLint: PASS;
- Production build: PASS;
- `git diff --check`: PASS;
- Vercel exact-head Preview: SUCCESS.

## Production relationship

T1 milestone approval does not authorize Production database mutation.

The last verified Production database baseline from release-candidate
governance remains a reference only and must be re-read before any future
Production database action.

Production Supabase mutation:

**HOLD / NOT AUTHORIZED**

Do not run linked `supabase db push`, manual Production migration SQL,
migration repair, linked reset, Production reset or direct Production schema
mutation without a separate exact human authorization.

Because `main` is the Vercel Production Git branch, merging PR #25 is also a
production-affecting application action and requires a separate explicit merge
authorization.

## Explicit non-scope

Do not expand T1 into:

- Work Ready sign-off;
- role or branch assignment through training;
- role-specific certification beyond the frozen common foundation;
- real client data as synthetic training data;
- Stage 13 -> Stage 14 advancement;
- editing execution;
- retouching or QC progression;
- gallery delivery;
- heirloom production;
- unrelated framework work;
- unrelated technical-debt cleanup.

## Current status

Initial Production Go-Live Release Candidate repository closeout:

**COMPLETE / HISTORICAL BASELINE**

T1 milestone approval:

**APPROVED**

T1 governance integration criterion:

**THIS EXECUTION POINTER AND APPROVAL RECORD PRESENT ON CANONICAL `main`**

PR #25 technical P2 findings:

**RESOLVED**

PR #25 milestone-authority P1 resolution condition:

**RE-EVALUATE AFTER T1 GOVERNANCE AUTHORITY IS PRESENT ON CANONICAL `main`**

PR #25 merge:

**NOT YET AUTHORIZED**

Production Supabase mutation:

**HOLD / NOT AUTHORIZED**

## Current next action

After this governance authority is present on canonical `main`:

1. verify canonical `main` contains the T1 milestone authority;
2. re-evaluate PR #25 against the frozen T1 boundary;
3. resolve PR #25's milestone-authority P1 only if the candidate remains within
   that boundary;
4. re-check PR #25 exact head, CI, reviews and mergeability;
5. obtain a separate explicit authorization before merging PR #25;
6. keep Production Supabase execution behind its own later human gate.
