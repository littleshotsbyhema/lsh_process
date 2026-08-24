# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is the active programme and is implemented through Slice 7P.

## Current Verified Checkpoint

Sprint 10 Slice 7P — Controlled Lead Videographer Assignment is the current verified checkpoint. Technical Design Freeze commit `11d9cc4`; implementation commit `566fcbe` (`feat: add lead videographer booking assignment`). The implementation has been pushed and is confirmed present on `origin/architecture-rebuild`. Implementation, local validation, local SQL fixture cleanup, local auth fixture cleanup, final diff review, commit, and push all passed. Lead Videographer supports both an eligible internal organization member and an already-registered external creative, assigned through the canonical `assign_booking_team_member` / `assign_booking_external_creative` RPC paths, with **SINGULAR CURRENT HOLDER** cardinality (unlike Stylist's additive/multiple-current model). Full evidence is recorded in the Slice 7P Implementation Checkpoint section of `docs/SPRINT_MASTER_REGISTER.md`.

Production remains HOLD for this and all Sprint 10 work unless separately authorized.

## Immediate Product Sequence

Lead Photographer (Slice 7N), Stylist (Slice 7O), and Lead Videographer (Slice 7P) are now implemented. Lead Videographer was the one staffing role among the canonical Stage 9 -> 10 gate's (`mark_booking_shoot_scheduled`) preconditions that remained; unlike Lead Photographer and Stylist, it is conditional on structured commercial evidence tied to the booking's accepted package/add-on version, so it does not apply to every booking.

Next checkpoint requires repository discovery against the remaining canonical Stage 9 -> 10 prerequisites. No slice beyond 7P is implementation-authorized or labeled here.

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
