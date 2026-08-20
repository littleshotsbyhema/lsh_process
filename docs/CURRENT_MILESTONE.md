# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is the active programme and is implemented through Slice 7N.

## Current Verified Checkpoint

Sprint 10 Slice 7N — Controlled Lead Photographer Assignment is the current verified checkpoint. Technical design freeze commit `7b00c6a`; implementation commit `ca18132`. Automated verification (Prettier, ESLint, typecheck, build, full local pgTAP suite, database lint) and local browser E2E acceptance both passed. Full evidence is recorded in the Slice 7N Implementation Checkpoint section of `docs/SPRINT_MASTER_REGISTER.md`.

Production remains HOLD for this and all Sprint 10 work unless separately authorized.

## Immediate Product Sequence

The smallest dependency-correct next candidate is **controlled Stylist assignment**, because the canonical Stage 9 -> 10 gate (`mark_booking_shoot_scheduled`) still requires a current Stylist assignment in addition to the Lead Photographer assignment Slice 7N closed.

That next candidate is **not implementation-authorized**. Its exact cardinality, mutation semantics, file boundary, and acceptance contract must be established by a separate Technical Design Freeze before implementation. Do not assume Stylist cardinality, exclusivity, or replacement semantics, and do not copy the Lead Photographer design mechanically — Stylist's real semantics (e.g. whether it is single-holder like Lead Photographer or additive/non-exclusive) have not yet been established against the frozen Sprint 10 design and must be verified before any freeze is written.

## Known Debt Outside This Checkpoint's Boundary

Repository-wide ESLint/Prettier formatting debt exists in pre-Sprint-10 files (concentrated in `src/lib/leads.functions.ts`, `src/lib/lead-workspace.functions.ts`, and several `src/routes/_authenticated/*.tsx` files). This debt is acknowledged and tracked but remains outside every Sprint 10 slice's acceptance boundary. It must not be expanded into a repository-wide cleanup without a separately authorized checkpoint.

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
