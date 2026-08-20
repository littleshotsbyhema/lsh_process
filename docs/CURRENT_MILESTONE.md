# Current Milestone

## Authority

This file is intentionally the mutable execution pointer.
Update it whenever a checkpoint is approved.
Do not rewrite the broader roadmap just to advance the active task.

## Current Architecture State

Treat the existing organization isolation, authentication, RBAC/RLS, audit foundation, families/contacts/children/memory-profile work, and current CRM rebuild as authoritative where present in the repository.

## Immediate Product Sequence

1. Reconcile and complete Leads / CRM against the approved architecture.
2. Verify lead lifecycle, ownership, permissions, RLS, audit history, and historical protection.
3. Complete conversion path from lead into family/client context without duplication or tenant leakage.
4. Complete tasks and consultations if not already production-verified.
5. Before freezing commercial schema, finalize package catalogue and add-on details.
6. Then implement package catalogue -> quotations -> bookings -> payments.
7. Then implement privacy/consent/safety/terms integration into booking readiness.

## Current Hard Rule

Do not freeze or scatter package constants throughout the application until the commercial package catalogue is explicitly approved.

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
