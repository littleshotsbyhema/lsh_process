# Little Shots OS — Claude Code Project Constitution

## Highest Product Authority

Little Shots OS is a philosophy-governed Memory Preservation Operating System for Little Shots by Hema.

Highest brand truth:
**Because these little moments become everything.**

Operating principle:
**Emotion is the heart. Care is the method. Trust is the standard. Memory is the outcome.**

Every implementation decision must protect:
1. Emotion-led memory preservation
2. Gentle care and safety
3. Consent-first trust
4. Timeless artistic quality
5. Heirloom keepsake value
6. Clarity and premium guidance

Do not implement a technically convenient solution that weakens trust, privacy, safety, clarity, historical integrity, or long-term product architecture.

## Required Context

Before material implementation work, read:
@docs/PRODUCT_CONSTITUTION.md
@docs/ARCHITECTURE.md
@docs/DOMAIN_RULES.md
@docs/IMPLEMENTATION_ROADMAP.md
@docs/CURRENT_MILESTONE.md
@docs/DEFINITION_OF_DONE.md

## Product Model

Treat Little Shots OS as one application composed of six domains:
- Studio OS
- Family OS
- Memory OS
- Business OS
- AI OS
- Founder OS

Do not reduce the system to a generic CRM.

## Current Architecture Authority

The current stronger architecture supersedes older single-tenant assumptions.

Required foundations:
- organization isolation
- RBAC
- PostgreSQL RLS
- controlled server/RPC mutations
- immutable or append-only audit history where appropriate
- lifecycle state over destructive deletion for historical business objects
- server-side secrets only
- no service-role credential in browser code

The existing application architecture is authoritative unless CURRENT_MILESTONE explicitly approves a migration.
Do not initiate framework migrations opportunistically.

## Engineering Rules

1. Inspect existing code and migrations before changing architecture.
2. Prefer extending established patterns over introducing parallel patterns.
3. Database invariants belong in PostgreSQL constraints, RLS, functions/RPCs, or server-side domain services as appropriate.
4. UI state must never be the only enforcement of a business rule.
5. Critical state transitions must be server-controlled.
6. Every cross-organization query/write must be tenant-safe.
7. Every sensitive mutation must be permission-checked and auditable.
8. Financial, booking, consent, privacy, safety, and audit history must remain reconstructable.
9. AI may propose; deterministic rules and authorized humans decide high-impact actions.
10. Do not invent pricing, packages, consent, availability, medical guidance, or business policy.

## Implementation Protocol

For each module:
1. Read governing docs and existing implementation.
2. State current behavior and gap.
3. Define lifecycle/state machine.
4. Define data model and invariants.
5. Define RBAC/RLS requirements.
6. Define audit requirements.
7. Implement database changes first when required.
8. Run database reset/lint/tests applicable to the repo.
9. Implement server/domain behavior.
10. Implement UI read path.
11. Implement controlled writes.
12. Add loading, empty, error, and validation states.
13. Add automated tests.
14. Run typecheck/lint/tests/build.
15. Perform E2E/manual verification when possible.
16. Report files changed, migrations added, tests run, unresolved risks, and next dependency.

Never mark a module complete only because the UI renders.

## Change-Control Rules

Do not silently change:
- tenant model
- role/permission semantics
- package semantics
- booking state machine
- privacy/consent semantics
- audit model
- naming conventions
- public API contracts

If a required change conflicts with approved architecture:
- stop implementation of that conflicting portion
- document the conflict
- propose the smallest safe change
- continue only with non-conflicting work

## Historical Data Rules

Prefer:
- active/inactive
- archived_at
- cancelled_at
- exited_at
- superseded_by
- versioning

over destructive DELETE for business history.

Hard deletion is allowed only for explicitly disposable data and only when repository rules permit it.

## AI Rules

AI capabilities must follow this chain:
User/context -> policy/permission -> deterministic eligibility/business rules -> model -> validated tool/action -> audit.

AI must not directly mutate critical state without a validated server action.
AI must not infer consent.
AI must not invent prices or discounts.
AI must escalate uncertainty on privacy, safety, payment, booking readiness, or legal matters.

## Definition of Complete

A module requires all applicable items in @docs/DEFINITION_OF_DONE.md.

## Working Style

- Make the smallest coherent change that completes the current milestone.
- Do not jump ahead to later phases.
- Do not add speculative abstractions with no current requirement.
- Preserve backward compatibility unless the milestone explicitly authorizes a breaking change.
- Prefer explicit names over clever abstractions.
- Keep implementation notes concise and evidence-based.
