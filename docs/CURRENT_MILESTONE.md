# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is the active programme and is implemented through Slice 7R.

## Current Verified Checkpoint

Sprint 10 Slice 7R — Controlled Stage 9 -> 10 Shoot Scheduled Advancement is the current verified checkpoint. Technical Design Freeze commit `3f9b430`; implementation commit `2543d13` (`feat: expose shoot scheduled advancement`). The implementation has been pushed and is confirmed present on `origin/architecture-rebuild`. Slice 7R exposes the existing canonical `mark_booking_shoot_scheduled(uuid)` database operation through the authenticated `/bookings` workspace using an authenticated server-function wrapper and a dedicated exact-Stage-9 `Mark shoot scheduled` control. The browser does not reproduce the database readiness gate and does not introduce a generic stage transition. No migration, schema, RPC, RLS, permission, role-grant, generated-type, legacy-route, route-tree, Stage 10 -> 11, or Production change was made. Targeted formatting, targeted ESLint, TypeScript, production build, full local pgTAP regression, local database lint, exact-boundary and containment checks, browser acceptance A–J, server-side permission enforcement, final staged review, commit, push, and local fixture cleanup all passed. Acceptance F is recorded as structural PASS / runtime N/A because the current canonical role taxonomy contains no role with `booking.stage.advance` while lacking `safety.read`; the implemented UI contract nevertheless depends only on exact Stage 9 plus `canAdvanceBookingStage`. Full evidence is recorded in the Slice 7R Implementation Checkpoint section of `docs/SPRINT_MASTER_REGISTER.md`.

Production remains HOLD for this and all Sprint 10 work unless separately authorized.

## Immediate Product Sequence

Lead Photographer (Slice 7N), Stylist (Slice 7O), Lead Videographer (Slice 7P), controlled Safety Readiness / Newborn formal sign-off (Slice 7Q), and controlled Stage 9 -> 10 Shoot Scheduled advancement (Slice 7R) are now implemented in the canonical booking workspace. The application exposes the existing server-authoritative `mark_booking_shoot_scheduled(uuid)` gate without duplicating its preparation, staffing, commercial Video/Reels, Safety Readiness, or Newborn sign-off eligibility logic in the browser.

Slice 7R ends at exact Stage 10 / `shoot_scheduled`. No Stage 10 -> 11 behavior, Shoot Completed workflow, generic journey transition, `/safety` runtime release, `/prep` runtime release, legacy-store reconciliation, Production migration, deployment, or Production mutation is authorized by this checkpoint.

The next checkpoint requires separate repository discovery and a separate Technical Design Freeze before any Stage 10 -> 11 / Shoot Completed workflow or other post-Shoot-Scheduled behavior is implemented.

Production remains HOLD.

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
