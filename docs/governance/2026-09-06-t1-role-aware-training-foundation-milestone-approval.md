# T1 Role-Aware Training Foundation - Milestone Approval and Technical Boundary Freeze

## Status

APPROVED MILESTONE / FUNCTIONAL SCOPE FROZEN / TECHNICAL BOUNDARY FROZEN

## Human authorization

Explicit human approval was given on 2026-09-06 to advance the programme execution pointer to:

**T1 - Role-Aware Training Foundation**

This approval authorizes the T1 milestone boundary described in this document.

It does not by itself authorize:

- merge of PR #25 into `main`;
- deployment of T1 application functionality to Production;
- Production Supabase mutation;
- Work Ready or Founder sign-off implementation;
- later operational journey stages;
- unrelated roadmap expansion.

Those remain separately controlled gates.

## Highest authority

This milestone remains subordinate to:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`
- `AGENTS.md`

The operating philosophy remains:

**Emotion is the heart. Care is the method. Trust is the standard. Memory is the outcome.**

Training must strengthen, not weaken, the existing authorization, privacy,
safety, audit, evidence and branch-containment model.

## Canonical baseline

Canonical `main` at milestone approval:

`de93945bd5d5f99152646bc8226cf1c2fee67fcd`

This commit merged:

`PR #24 - chore(release): close Initial Production Go-Live RC`

The previous Initial Production Go-Live Release Candidate remains a historical
approved Stage 13 boundary.

Its validated repository evidence, including canonical role-permission count
`260`, remains valid for that frozen release-candidate baseline.

T1 is a later approved milestone and must not retroactively rewrite that
historical evidence.

## Roadmap relationship

`docs/IMPLEMENTATION_ROADMAP.md` remains durable programme taxonomy.

Its Scope Rule permits work that removes a current dependency or satisfies an
approved milestone.

This T1 record is the explicit approved milestone authority for the narrow
training foundation below.

The roadmap itself is not reclassified or silently expanded by this approval.

## Milestone intent

T1 establishes safe, role-aware onboarding inside Little Moments OS so a team
member can understand the operating system, their live role and branch scope,
evidence expectations, privacy boundaries, escalation paths and help surfaces
before deeper role-specific training is introduced.

Training remains subordinate to real authorization.

Training completion must never create business authority.

## Authorized functional scope

T1 may implement and integrate:

1. the role-aware training data foundation;
2. organization training rollout settings;
3. versioned training modules and database-authoritative module steps;
4. persistent member training profiles;
5. immutable training-step evidence;
6. the common orientation module and its seven required steps;
7. authenticated RPCs for training context, start, progress and completion;
8. Founder-only organization training oversight through `training.read`;
9. training gate modes `off`, `soft` and `required`;
10. gating based on reachable canonical training completion;
11. a guided interface tour and Help & Training application surface;
12. strict separation of training state from role, branch and Work Ready state;
13. protection of an in-use module version from in-place catalogue mutation;
14. required database tests, generated types, TypeScript, lint and build
    reconciliation necessary for this exact boundary.

## Frozen technical boundary

T1 training truth remains database-authoritative.

The authority chain remains:

`Auth -> Org Membership -> Role -> Permission -> RLS -> Approved RPC -> Validation -> Transaction -> Audit`

Required T1 properties:

- direct authenticated training-table mutation remains denied;
- user-facing training operations use controlled authenticated RPCs;
- common orientation is versioned;
- required-step completion evidence is database-defined;
- training evidence is immutable;
- a module version becomes immutable once member training state exists;
- catalogue evolution occurs through a new module version;
- training completion is a reachable state independent of Work Ready;
- gate `soft` or `required` may clear on canonical required-training completion;
- gate failure must not become a replacement authorization system;
- rollout defaults to gate mode `off`;
- `training.read` is Founder-only in T1;
- training completion grants no role;
- training completion grants no branch scope;
- training completion grants no Founder sign-off;
- training completion grants no Work Ready state.

## Work Ready boundary

Work Ready remains explicitly outside T1.

T1 may store reserved Work Ready/sign-off fields for future governed use, but
the T1 completion path must not populate:

- `signed_off_by`;
- `signed_off_at`;
- `work_ready_at`.

A later milestone must define the permission, evidence, audit and human
authority required for final Work Ready sign-off.

## Approved implementation candidate

The existing implementation candidate is:

Branch:

`feature/t1-role-aware-training-foundation`

PR:

`#25 - feat: add role-aware training foundation`

Current reviewed head at milestone approval:

`01f79c928cf2208ab7d2c55fc51fc2ebc7908882`

That candidate contains the implementation subject to this frozen boundary.

This milestone approval does not automatically approve PR #25 for merge.

PR #25 must still satisfy its current review, CI and explicit merge gates.

## T1 database contract

The T1 repository migration sequence is:

1. `20260905191755_role_aware_training_foundation.sql`
2. `20260906041409_t1_training_progress_cursor_completion_only.sql`

After a pristine local replay including T1, the canonical repository-wide
role-permission count is:

`261`

The change from `260` to `261` is exactly the T1 Founder `training.read`
mapping.

The Stage 13 release-candidate count `260` remains historical evidence for the
pre-T1 baseline and is not a T1 acceptance target.

## Production migration relationship

The last verified Production database state inherited from the Initial
Production Go-Live Release Candidate was:

- migration tip:
  `20260901180856_sprint12_stage11_12_selection_pending_gate_foundation.sql`;
- role-permission count: `233`.

Before T1, the repository already had two later migrations awaiting a separately
authorized Production release:

1. `20260902033921_sprint13_selection_completion_stage12_13_editing_pending_foundation.sql`
2. `20260903084543_lsh_four_branch_role_scope_brand_owner_foundation.sql`

If PR #25 is later merged, the two T1 migrations follow those migrations in
repository chronology.

No Production migration may be applied merely because this milestone is
approved or because PR #25 is later merged.

Production state must be re-read immediately before any future Production
database authorization.

## Explicit non-scope

T1 does not authorize:

- Work Ready sign-off;
- Founder training sign-off workflow;
- role creation or assignment through training;
- branch grant creation or widening through training;
- role-specific certification beyond the approved T1 common foundation;
- live client records as synthetic training material;
- Stage 13 -> Stage 14 journey advancement;
- editing execution;
- editor assignment;
- retouching or QC progression;
- gallery delivery;
- heirloom production;
- AI-generated high-impact authorization decisions;
- unrelated framework migration;
- unrelated technical-debt cleanup;
- Production database mutation.

## Validation evidence for the current candidate

The reviewed T1 candidate has established:

- pristine local migration replay: PASS;
- canonical local role-permission count: `261`;
- catalogue immutability triggers: present;
- dedicated T1 pgTAP: `56/56` PASS;
- Supabase local DB lint: PASS;
- generated Supabase type semantic reconciliation: PASS;
- TypeScript: PASS;
- targeted ESLint: PASS;
- Production build: PASS;
- `git diff --check`: PASS;
- exact-head Vercel Preview deployment: SUCCESS.

These results are candidate evidence, not Production deployment authorization.

## Integration order

The controlled integration order is:

1. merge this governance milestone record and updated execution pointer into
   canonical `main`;
2. verify `main` contains this T1 authority;
3. re-evaluate PR #25 against the new `main` governance boundary;
4. close the milestone-authority review finding only if the PR remains within
   this frozen T1 scope;
5. verify exact PR #25 head, CI, review threads and mergeability;
6. obtain separate explicit authorization before merging PR #25;
7. keep Production Supabase mutation behind a later separate human gate.

## Exit criteria

T1 may be considered integrated only when:

- this governance boundary is present on canonical `main`;
- PR #25 remains within the frozen scope;
- no unresolved material P1/P2 review finding remains;
- exact-head validation remains green;
- PR #25 is explicitly authorized and merged;
- post-merge application deployment is verified.

Production database rollout is not an exit criterion for repository integration
and remains independently gated.

## Current decision

T1 milestone:

**APPROVED**

T1 functional scope:

**FROZEN**

T1 technical boundary:

**FROZEN**

PR #25 merge:

**NOT YET AUTHORIZED**

Production Supabase mutation:

**HOLD / SEPARATE HUMAN GATE**

Work Ready implementation:

**NOT AUTHORIZED BY T1**
