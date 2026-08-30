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

The repository-history canonicalization anchor is:

`d829ca66014f6e0f802425ff3af8368eea8d324b`

That commit reconciled the former `main` ancestry onto the approved production
lineage without changing the approved production tree.

Canonical deployment relationship:

`main` -> Vercel Production -> `memory-keeper-os.vercel.app`

The approved Sales CRM booking-confirmation release is contained in canonical
`main`.

## Branch Model

Permanent source-of-truth branch:

- `main`

All normal development work must begin from current `main` on a short-lived branch.

Approved branch purposes include:

- `feature/...`
- `fix/...`
- `chore/...`
- `release/...`
- `hotfix/...`

Do not create another long-lived development branch that competes with `main`
as repository authority.

Do not perform normal implementation work directly on `main`.

## Main and Production

The Vercel project treats `main` as its production Git branch.

Therefore an update to `main` may trigger a Vercel Production deployment even
when the repository change is documentation-only.

Advancing `main` is consequently a production-affecting action and requires an
explicit human approval at that gate.

Feature-branch pushes are expected to produce Preview deployments, not Production.

## Frozen Legacy Architecture Branch

`architecture-rebuild` is a frozen legacy reference branch.

Frozen head:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new commits to `architecture-rebuild`.

Do not merge `architecture-rebuild` wholesale into `main`.

The legacy branch contains validated but not universally production-approved
Studio Operations work. Its history must therefore be treated as source material,
not as an automatic release train.

Approved legacy functionality must be migrated selectively onto fresh
short-lived branches created from current `main`.

Each migrated domain must be reconciled against the current production application
and database contracts before integration.

## Generated Artifact Rule

Do not blindly copy generated artifacts from the frozen legacy branch.

In particular:

- `src/integrations/supabase/types.ts` must be regenerated from the applicable
  validated database schema when a migrated slice changes the schema contract.
- `src/routeTree.gen.ts` must be regenerated through the normal TanStack
  application tooling when required.

Generated artifacts are outputs of the validated source state, not migration
authority by themselves.

## Current Migration Programme

The active programme is controlled extraction of valuable unreleased work from
the frozen `architecture-rebuild` branch into the canonical `main` workflow.

Planned migration domains are:

1. repository governance;
2. remaining pre-shoot operations;
3. shoot completion and post-session handoff;
4. selection and financial authority;
5. editing, QC, and gallery progression;
6. media custody and capture-device authority.

Each domain must be migrated, reconciled, validated, reviewed, and integrated
independently.

Do not cherry-pick the complete legacy history.

Do not assume that a legacy implementation remains compatible with current
production contracts merely because it previously passed validation on
`architecture-rebuild`.

## Current Active Branch

`chore/repository-governance`

Purpose:

Establish canonical repository governance on top of `main` before migrating
additional Studio Operations functionality.

Current authorized scope is governance documentation only.

No application implementation change is authorized by this milestone.

No database migration is authorized by this milestone.

## Supabase Trust Boundary

Local Supabase and remote Supabase are separate trust boundaries.

Authorization to inspect, reset, test, lint, or mutate the local development
database does not authorize remote Supabase activity.

Do not perform any of the following without explicit authorization for that
exact action:

- linked or remote migration deployment;
- remote database mutation;
- production data mutation;
- Supabase branch merge;
- production schema mutation.

The repository-governance migration makes no Supabase production change.

## Public Website Boundary

The Little Shots public website and Memory Keeper OS are separate operational
and deployment boundaries.

Target architecture:

- Little Shots public website -> dedicated repository/project -> its own `main`;
- Memory Keeper OS -> `memory-keeper-os` -> `main`.

Memory Keeper OS repository work must not alter the public website repository,
deployment, or domain unless that work is separately authorized.

## Current Exit Criteria

Repository-governance migration is complete only when:

- the stable governance documents are present on the governance branch;
- this canonical milestone reflects the `main`-based operating model;
- repository execution guidance reflects the new branch and production gates;
- obsolete legacy milestone assumptions do not govern canonical development;
- no application code or database migration has changed unintentionally;
- the exact file boundary is reviewed;
- applicable documentation validation passes;
- the governance branch is pushed and reviewed;
- integration into `main` receives explicit approval because it may trigger
  Vercel Production.
