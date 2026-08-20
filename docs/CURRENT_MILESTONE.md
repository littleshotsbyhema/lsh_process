# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is the active programme and is implemented through Slice 7M.

## Current Verified Checkpoint

Sprint 10 Slice 7M is closed as **"Booking Team Assignment Candidate Discovery"**, implemented and committed as `df44464`. The scope amendment closing Slice 7M to its actual shipped (read-only) scope, and formally deferring mutation-submission UX, is documented in `docs/SPRINT_MASTER_REGISTER.md`.

Slice 7N is **not implementation-authorized**. Its scope is not yet defined in this file; do not infer or plan it here.

## Immediate Product Sequence

No new feature work may begin until both of the following are complete:

1. This reconciliation checkpoint (`docs/CURRENT_MILESTONE.md` and `docs/SPRINT_MASTER_REGISTER.md` accurately reflecting repository reality) is committed.
2. The known stale `src/routeTree.gen.ts` is regenerated and committed as its own isolated mechanical checkpoint.

Only after both are complete may Slice 7N (or any other new checkpoint) be scoped and authorized.

## Current Hard Rule

Do not begin implementation of Slice 7N, or any other new feature work, until the reconciliation checkpoint and route-tree repair above are both committed.

## Known Debt Outside This Checkpoint's Boundary

Repository-wide ESLint/Prettier formatting debt exists in pre-Sprint-10 files (concentrated in `src/lib/leads.functions.ts`, `src/lib/lead-workspace.functions.ts`, and several `src/routes/_authenticated/*.tsx` files). This debt is acknowledged and tracked but is explicitly not part of this reconciliation checkpoint or the route-tree repair checkpoint. It must not be expanded into a repository-wide cleanup without a separately authorized checkpoint.

Production remains on HOLD for all Sprint 10 work unless separately authorized.

## Completion Report Required

For each checkpoint report:
- what existed before
- what changed
- database migrations/functions/policies changed
- routes/components changed
- tests run and results
- manual verification performed
- security/tenant isolation checks
- unresolved issues
- recommended next checkpoint
