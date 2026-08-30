# Little Shots OS — Repository Execution Constitution

## Highest Product Authority

Little Shots OS is a philosophy-governed Memory Preservation Operating System
for Little Shots by Hema.

Highest brand truth:

**Because these little moments become everything.**

Operating principle:

**Emotion is the heart. Care is the method. Trust is the standard. Memory is the outcome.**

Every implementation decision must protect:

1. emotion-led memory preservation;
2. gentle care and safety;
3. consent-first trust;
4. timeless artistic quality;
5. heirloom keepsake value;
6. clarity and premium guidance.

Do not implement a technically convenient solution that weakens trust, privacy,
safety, clarity, historical integrity, or long-term product architecture.

## Required Context

Before material implementation work, read:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/CURRENT_MILESTONE.md`
- `docs/DEFINITION_OF_DONE.md`

`docs/CURRENT_MILESTONE.md` is the mutable execution pointer.

If the requested task conflicts with the current milestone or durable governance,
stop the conflicting portion and report the discrepancy.

## Product Model

Treat Little Shots OS as one application composed of six product domains:

- Studio OS
- Family OS
- Memory OS
- Business OS
- AI OS
- Founder OS

Do not reduce the system to a generic CRM.

## Canonical Repository Authority

`main` is the single canonical source-of-truth branch for Memory Keeper OS.

Normal implementation work must not be performed directly on `main`.

All normal work begins from current `main` on a short-lived branch such as:

- `feature/...`
- `fix/...`
- `chore/...`
- `release/...`
- `hotfix/...`

Do not create another long-lived development branch that competes with `main`.

## Production Relationship

The Memory Keeper OS Vercel project uses `main` as its production Git branch.

Therefore updating `main` is a production-affecting action and may trigger a
Vercel Production deployment.

A successful feature build, Preview deployment, pull request, or previous
approval does not by itself authorize advancing `main`.

Advancing or merging into `main` requires an explicit human-controlled gate.

## Frozen Legacy Branch

`architecture-rebuild` is frozen legacy reference history.

Frozen head:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not:

- create new development commits on `architecture-rebuild`;
- merge `architecture-rebuild` wholesale into `main`;
- treat its full history as automatically production-approved;
- copy generated artifacts from it as implementation authority.

Legacy functionality must be migrated selectively onto fresh branches created
from current `main`.

Each migrated domain must be reconciled against the current application,
database contract, permissions model, and production lineage.

## Current Architecture Authority

The current organization isolation, authentication, RBAC/RLS, audit foundation,
and released application architecture are authoritative unless the active
milestone explicitly approves a change.

Required foundations include:

- organization isolation;
- role-based access control;
- PostgreSQL RLS;
- controlled server/RPC mutations;
- immutable or append-only audit history where appropriate;
- lifecycle state instead of destructive deletion for historical business data;
- server-side secrets only;
- no service-role credential in browser code.

The database and server layer enforce business truth.

The browser must not be trusted to enforce authorization, financial truth,
consent truth, or lifecycle transitions.

## Engineering Rules

1. Inspect existing code, migrations, tests, and authority paths before changing
   architecture.
2. Prefer extending established patterns over introducing parallel patterns.
3. Database invariants belong in PostgreSQL constraints, RLS, functions/RPCs,
   or approved server-side domain services.
4. UI state must never be the only enforcement of a business rule.
5. Critical lifecycle transitions must be server-controlled.
6. Every cross-organization query and write must remain tenant-safe.
7. Every sensitive mutation must be permission-checked and auditable.
8. Financial, booking, consent, privacy, safety, and audit history must remain
   reconstructable.
9. AI may propose; deterministic rules and authorized humans decide high-impact
   actions.
10. Do not invent pricing, packages, consent, availability, medical guidance,
    or business policy.
11. Do not opportunistically migrate frameworks or introduce unrelated
    infrastructure changes.
12. Preserve backward compatibility unless the approved milestone explicitly
    authorizes a breaking change.

## Generated Artifact Rules

Generated files are outputs of validated source state, not independent authority.

Do not blindly copy generated files from a legacy branch.

### Supabase types

When a validated schema change requires regenerated application types:

- generate `src/integrations/supabase/types.ts` from the applicable validated
  schema;
- inspect its semantic delta;
- do not substitute stale legacy generated types merely because they compile.

### TanStack route tree

`src/routeTree.gen.ts` must be produced through the normal TanStack tooling.

If build or route generation modifies it during validation, classify that change
deliberately before committing it.

Do not manually use a stale route tree to satisfy type checking.

## Execution Modes and Human Gates

Every substantial task must explicitly operate as one of:

- `MODE: Plan`
- `MODE: Auto`
- `MODE: Manual`

The selected mode never silently expands scope.

### MODE: Plan

Use Plan for:

- repository discovery;
- architecture investigation;
- reconciliation;
- dependency analysis;
- migration planning;
- technical-design exploration;
- scope analysis before implementation approval.

Plan means:

- inspect;
- reason;
- report evidence;
- do not edit files;
- do not mutate databases;
- do not stage;
- do not commit;
- do not push;
- do not merge;
- do not deploy.

A Plan task should normally end with:

- conclusions;
- evidence;
- unresolved questions;
- proposed next boundary;
- files changed: none.

### MODE: Auto

Use Auto for tightly bounded local work such as:

- read-only repository inspection;
- explicitly authorized file edits;
- implementation after an approved technical boundary exists;
- formatting;
- type checking;
- build;
- lint;
- automated tests;
- other local verification commands inside the authorized scope.

Auto authorizes only the exact files and actions stated in the task.

Auto does not authorize:

- expanding the file boundary;
- opportunistic refactors;
- unrelated technical-debt cleanup;
- inventing migrations;
- architecture changes outside the approved boundary;
- staging;
- committing;
- pushing;
- merging;
- advancing `main`;
- deployment;
- promotion;
- remote Supabase mutation;
- production mutation;
- exposing secrets.

If a required change falls outside the authorized boundary, stop and report it.

### MODE: Manual

Use Manual for explicit human-controlled gates including:

- git staging for a governed commit;
- git commit;
- git push;
- destructive/reset commands when separately gated;
- material local database mutation when approval is required;
- migration creation or migration application when separately authorized;
- remote Supabase operations;
- Supabase branch merge;
- updating or merging into `main`;
- production database mutation;
- Vercel deployment or promotion;
- production release.

A previous Plan or Auto authorization never authorizes a Manual action.

## One-Time Approval Discipline

When Manual approval is required, use the narrowest exact one-time authorization.

Never interpret phrases such as:

- continue;
- go ahead;
- looks good;
- previous implementation approval;
- previous Auto mode;
- previous successful verification;

as implicit permission to:

- stage;
- commit;
- push;
- merge;
- advance `main`;
- deploy;
- mutate remote infrastructure;
- mutate production.

Each production-affecting boundary requires explicit approval at that gate.

## Governed Feature Sequence

The normal governed sequence is:

Discovery
-> Reconciliation when required
-> Technical Design Freeze
-> Implementation
-> Automated Verification
-> Manual/E2E Verification when applicable
-> Implementation Commit
-> Checkpoint Documentation
-> Final Baseline Verification
-> Push Feature Branch
-> Preview / Remote Verification
-> Review
-> Explicit Main Integration Approval
-> Main Integration
-> Production Verification

Not every change requires every stage, but skipping an applicable trust gate
requires explicit justification.

Freeze, implementation, and checkpoint documentation may remain separate commits
when milestone governance requires that structure.

Do not mix unrelated cleanup into a governed implementation commit.

## Git Discipline

Before mutation:

- confirm current branch;
- confirm expected base SHA;
- confirm clean or understood worktree;
- inspect exact file boundary.

Before commit:

- inspect `git status`;
- inspect staged file names;
- inspect staged diff/stat;
- run applicable verification;
- ensure generated files are intentional.

Before push:

- verify exact local commit SHA;
- verify intended remote branch;
- do not push required-verification failures.

Before updating `main`:

- verify the candidate is based on current `main` or has been explicitly
  reconciled;
- verify expected ancestry;
- verify the exact candidate SHA;
- verify applicable checks and Preview state;
- obtain explicit human approval.

Do not force-push `main` unless a separately approved repository-recovery plan
explicitly requires it.

## Supabase Trust Boundaries

Local Supabase and remote Supabase are separate trust boundaries.

Permission to use local Supabase never implies permission to:

- use `--linked`;
- deploy remote migrations;
- mutate a remote Supabase project;
- merge a Supabase branch;
- mutate production data;
- alter production schema.

Local E2E or fixture data must never be described as production data.

Remote Supabase mutation requires explicit authorization for the exact operation.

## Migration Discipline

Before introducing a database migration:

1. inspect current migrations;
2. inspect current remote-production contract when relevant;
3. determine whether the capability already exists;
4. define forward-only compatibility requirements;
5. verify permissions, RLS, audit, lifecycle, and rollback/recovery implications;
6. add dedicated database tests;
7. validate against relevant historical compatibility tests.

Do not weaken a newer production database contract merely to make older
application code work.

Adapt application code to the authoritative production contract unless an
explicit database change has been approved.

## Secret Handling

Never deliberately print or expose secret values including:

- Supabase service-role keys;
- private API keys;
- access tokens;
- passwords;
- secret environment-variable values;
- private signing material.

Prefer commands and tooling that pass required secrets without echoing them.

Public/local URLs, non-secret identifiers, commit SHAs, project references, and
safe debugging metadata may be shown when appropriate.

## Verification-Failure Classification

Do not push while a required verification is failing.

Classify failures using evidence as one of:

- implementation regression;
- dirty local runtime/test fixture contamination;
- pre-existing technical debt;
- non-fatal tooling warning;
- environmental/tooling failure.

Do not call a warning a failure merely because it appears in output.

Do not call verification clean when a required command exits nonzero.

Known warnings must remain distinguishable from newly introduced failures.

## Change-Control Rules

Do not silently change:

- tenant model;
- organization isolation;
- role/permission semantics;
- package semantics;
- quotation semantics;
- booking state machine;
- privacy/consent semantics;
- audit model;
- financial authority;
- safety authority;
- naming conventions;
- public API/RPC contracts.

If a required change conflicts with approved architecture:

1. stop the conflicting portion;
2. document the conflict;
3. propose the smallest safe change;
4. continue only with non-conflicting authorized work.

## Historical Data Rules

Prefer lifecycle and supersession semantics such as:

- active/inactive;
- `archived_at`;
- `cancelled_at`;
- `exited_at`;
- `superseded_by`;
- versioning;

over destructive deletion for business history.

Hard deletion is allowed only for explicitly disposable data and when repository
rules permit it.

## AI Rules

AI capabilities must follow:

User/context
-> policy/permission
-> deterministic eligibility/business rules
-> model
-> validated tool/action
-> audit

AI must not directly mutate critical state without a validated server action.

AI must not infer consent.

AI must not invent prices, discounts, packages, or availability.

AI must escalate uncertainty on privacy, safety, payment, booking readiness,
legal matters, or other high-impact decisions.

## Public Website Boundary

The Little Shots public website is operationally separate from Memory Keeper OS.

Do not alter the public website repository, Vercel project, production domain,
or release path while performing Memory Keeper OS work unless that scope is
explicitly authorized.

## Definition of Complete

A module is complete only when all applicable requirements in
`docs/DEFINITION_OF_DONE.md` are satisfied.

A rendered UI is not sufficient evidence of completion.

## Reporting Requirements

At meaningful checkpoints report:

- current branch;
- base commit;
- files changed;
- migrations added or modified;
- tests run;
- build/type/lint status;
- database validation status when applicable;
- known warnings;
- unresolved risks;
- remote mutations performed, if any;
- production mutations performed, if any;
- next dependency or gate.

Reports must distinguish local evidence from remote or production evidence.

## Working Style

- Make the smallest coherent change that completes the current approved milestone.
- Do not jump ahead to later migration domains.
- Do not add speculative abstractions without a current requirement.
- Prefer explicit names over clever abstractions.
- Preserve historical and audit integrity.
- Keep implementation notes concise and evidence-based.
- Stop at trust boundaries instead of silently crossing them.
