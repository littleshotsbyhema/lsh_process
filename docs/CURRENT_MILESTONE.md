# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, and all Sprint 1-9 modules (organizations, families, contacts, children, memory profiles, leads/CRM, lead workspace, AI Memory Guide, packages/quotations/booking conversion, advance payments, booking confirmation, KPI) as authoritative and Complete/Released. Do not rebuild them. See `docs/SPRINT_MASTER_REGISTER.md` for the full sprint-by-sprint delivered scope and acceptance state.

Sprint 10 (Pre-Shoot Preparation, Safety Readiness & Shoot Scheduling Foundation) is implemented through Slice 7R and remains not released. Sprint 11 (Shoot Completion & Post-Session Handoff) is now the active design programme. Sprint 11 Slice 1 is Technical Design Frozen only; no Sprint 11 implementation is yet authorized.

## Current Verified Checkpoint

Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation is the current design checkpoint. Repository discovery was performed from baseline `fbe53afb64bb314c91c6430204b717183b815582` after Sprint 10 Slice 7R was fully closed. Discovery confirmed that canonical Stage 11 already exists as `shoot_completed`, but there is no canonical shoot-completion evidence relation, no shoot-completion mutation RPC, no generated completion API surface, no dedicated Stage 10 -> 11 gate, and no dedicated Stage 10 -> 11 pgTAP test. Sprint 10 explicitly excluded Shoot Completed and shoot-completion evidence. Slice 1 therefore freezes only the canonical evidence foundation: one narrow `shoot.complete` permission, immutable booking-level shoot-completion evidence, a controlled authenticated recording RPC, forced-RLS/read containment, audit provenance, generated Supabase type synchronization, and a dedicated pgTAP test. Slice 1 performs no journey advancement and exposes no application UI. Implementation is not yet authorized. Full Technical Design Freeze is recorded in `docs/SPRINT_MASTER_REGISTER.md`.

Production remains HOLD for all unreleased Sprint 10 and Sprint 11 work unless separately authorized.

## Immediate Product Sequence

Sprint 10 Slice 7R ends at exact Stage 10 / `shoot_scheduled`. Fresh repository discovery has now established the next dependency boundary.

Sprint 11 Slice 1 — Canonical Shoot Completion Evidence Foundation is Technical Design Frozen. It introduces completion evidence only. It does not move a booking from Stage 10 to Stage 11 and it does not expose a browser control.

The intended sequence is:

1. Sprint 11 Slice 1 — canonical immutable Shoot Completion evidence;
2. Sprint 11 Slice 2 — separately frozen controlled Stage 10 -> 11 / `shoot_completed` gate consuming that evidence;
3. Sprint 11 Slice 3 — separately frozen authenticated `/bookings` integration.

Shoot-day Safety incidents, post-session restricted Safety notes, Stage 11 -> 12, selection, editing, QC, delivery, `/safety` release, `/prep` release, legacy-store reconciliation, Production migration and deployment remain outside Slice 1.

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
