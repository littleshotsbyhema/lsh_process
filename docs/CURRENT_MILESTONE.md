# Current Milestone

## Authority

This file is the mutable execution pointer for canonical Memory Keeper OS development.

Durable product and engineering authority lives in:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`

Current release and governance evidence includes:

- `docs/releases/2026-09-01-sprint-10-production-release.md`
- `docs/governance/2026-09-01-sprint10-post-release-reconciliation.md`
- `docs/governance/2026-09-01-sprint11-scope-freeze.md`
- `docs/governance/2026-09-01-sprint11-technical-design-freeze.md`
- `docs/releases/2026-09-01-sprint-11-production-release.md`
- `docs/governance/2026-09-01-sprint11-post-release-reconciliation.md`
- `docs/governance/2026-09-01-sprint12-scope-freeze.md`
- `docs/governance/2026-09-01-sprint12-technical-design-freeze.md`
- `docs/governance/2026-09-02-sprint12-post-release-reconciliation.md`
- `docs/governance/2026-09-02-sprint13-scope-freeze.md`
- `docs/governance/2026-09-02-sprint13-technical-design-freeze.md`

## Canonical repository state

`main` is the single canonical source-of-truth branch and the Vercel Production Git branch.

Current canonical `main` head before this Sprint 13 technical-design governance branch:

`bf7e06ec362dc748f4c8869f406ca1552298dad2`

This commit merged PR #16 and froze the Sprint 13 functional scope on `main`.

The released Sprint 12 application SHA remains:

`ec05bba81d19fed31cdf0d8ff9e42ac8a713099e`

`architecture-rebuild` remains frozen legacy reference history at:

`5ae04a5b971dfe0c4ae9657483d0386d649ce34f`

Do not add new work to `architecture-rebuild` and do not merge it wholesale into `main`.

## Current governance branch

Current branch:

`chore/sprint13-technical-design-freeze`

Purpose:

- freeze the exact Sprint 13 evidence model and authority boundary;
- define the controlled finalized-selection recording contract;
- define the exact Stage 12 -> Stage 13 advancement contract;
- lock the logical migration name and implementation path boundary;
- keep migration creation, implementation and Production mutation on HOLD until separately authorized.

This branch is governance-only.

## Production release state

Sprint 12 is COMPLETE, RELEASED, VERIFIED and CLOSED through exact Stage 12:

`selection_pending`

Released journey boundary:

`Stage 11 shoot_completed -> Stage 12 selection_pending`

Production application SHA:

`ec05bba81d19fed31cdf0d8ff9e42ac8a713099e`

Canonical Sprint 12 Production migration:

- `20260901180856_sprint12_stage11_12_selection_pending_gate_foundation.sql`

Production migration history is aligned with this exact repository version.

## Canonical journey boundary

The canonical journey-stage catalogue includes:

- Stage 11: `shoot_completed` — Shoot Completed
- Stage 12: `selection_pending` — Selection Pending
- Stage 13: `editing_pending` — Editing Pending
- Stage 14: `editing_in_progress` — Editing In Progress

Production is released through Stage 12 only.

Stage 12 means the completed session has been formally handed into the selection phase and is waiting for selection activity. It does not mean selections are complete or editing has started.

## Current programme

The current programme milestone is:

**Sprint 13 — Editing Pending**

Frozen functional boundary:

`Stage 12 selection_pending -> Stage 13 editing_pending`

Functional scope:

`docs/governance/2026-09-02-sprint13-scope-freeze.md`

Technical design:

`docs/governance/2026-09-02-sprint13-technical-design-freeze.md`

Stage 13 means the authoritative client selection is complete, the canonical selected-image set is locked, and the booking has been accepted into the editing queue. It does not mean editing has started.

Functional truth:

`Selection completed + canonical selected-image set locked + editing handoff accepted`

## Sprint 13 frozen evidence model

The technical design freezes two new canonical evidence relations:

- `public.booking_selection_completions` — exactly one immutable finalized-selection completion per booking;
- `public.booking_selected_images` — immutable non-empty selected-image manifest rows for the canonical completion.

The selected-image `image_key` is an opaque booking-scoped operational identifier. It is not a signed URL, gallery credential, media binary, EXIF payload or DAM contract.

Sprint 13 does not implement draft selection, autosave, client favourites, progress tracking or gallery-interaction history.

A finalized selection must contain at least one unique non-empty image key.

## Sprint 13 frozen authority model

Selection evidence recording introduces exactly one narrow permission:

`selection.confirm`

Expected grants:

- Founder
- Studio Manager
- Client Coordinator

Journey advancement continues to use:

`booking.stage.advance`

Selection recording and journey advancement remain separate authorities.

Expected canonical role-permission compatibility count after Sprint 13 migration:

`236`

Any other count requires STOP/governance review.

## Sprint 13 frozen RPC contracts

Selection-completion recording RPC:

`public.record_booking_selection_completion(uuid,text[],text,text)`

Journey advancement RPC:

`public.mark_booking_editing_pending(uuid)`

Both must use controlled authenticated `SECURITY DEFINER` execution with fixed empty `search_path`, explicit active membership, permission and branch-scope validation, explicit ACL containment, deterministic transaction behavior and structural audit evidence.

Selection completion is immutable and exact replay is mutation-free. A conflicting manifest must reject rather than overwrite canonical history.

Stage 12 -> 13 advancement requires one canonical finalized selection with a non-empty valid manifest and exact canonical Stage 11 -> 12 lineage.

Stage 13 replay is mutation-free when canonical lineage remains intact.

## Sprint 13 audit contracts

First finalized-selection success:

`booking.selection_completed`

First Stage 12 -> 13 advancement:

`booking.editing_pending`

Structural audit metadata may include IDs, counts, timestamps and journey versions, but must not contain selected image keys, image content, gallery credentials, private family notes, child-sensitive data or Safety/medical details.

## Sprint 13 RLS and external-provider boundary

Both new selection evidence relations must have RLS enabled and forced.

Authenticated reads must remain contained by booking-read authority, organization membership and branch scope.

Authenticated direct INSERT/UPDATE/DELETE is denied. Controlled RPCs are the only Sprint 13 mutation path.

Sprint 13 remains provider-neutral. Pixieset or another provider may be recorded only as non-authoritative provenance if implementation uses an optional external reference. No provider API integration, webhook ingestion, gallery publication, provider credentials, image download or provider-specific schema is authorized.

External/client/browser state never becomes journey authority by itself.

Canonical authority chain:

`Auth -> Org Membership -> Role -> Permission -> RLS -> Approved RPC -> Validation -> Transaction -> Audit`

## Sprint 13 application boundary

After migration filename lock, the frozen implementation boundary is exactly six paths:

1. the locked Sprint 13 migration;
2. `supabase/tests/sprint13_selection_completion_stage12_13_gate_test.sql`;
3. `src/integrations/supabase/types.ts`;
4. `supabase/tests/sprint10_extended_creative_assignments_test.sql` only for the compatibility-count update `233 -> 236`;
5. `src/lib/booking.functions.ts`;
6. `src/routes/_authenticated/bookings.tsx`.

Any seventh implementation path requires an explicit governance amendment.

`src/routeTree.gen.ts` is not an authorized Sprint 13 implementation path.

## Sprint 13 migration state

Logical migration name is frozen as:

`sprint13_selection_completion_stage12_13_editing_pending_foundation`

Exact timestamped migration filename: **NOT YET LOCKED**.

The exact filename must be generated using the installed Supabase CLI from the canonical Sprint 13 implementation branch only after this technical-design governance change is merged and the filename-lock checkpoint is separately authorized.

No migration SQL may be written before that filename is locked.

## Sprint 13 status

Functional scope: **FROZEN**.

Technical design: **FINAL FROZEN ON THIS GOVERNANCE BRANCH**.

Migration logical name: **FROZEN**.

Exact timestamped migration filename: **PENDING FILENAME-LOCK CHECKPOINT**.

Implementation: **HOLD**.

Production deployment: **NOT AUTHORIZED**.

Sprint 13 must stop at exact Stage 13. No Stage 13 -> Stage 14 work is authorized.

## Explicitly out of scope

The current milestone does not authorize:

- Stage 13 -> Stage 14 `editing_in_progress` or later advancement;
- actual editing or retouching workflow;
- editor assignment/task allocation unless separately governed;
- AI culling, AI editing or automated creative judgment;
- QC progression;
- gallery publication or final delivery;
- additional-image pricing or entitlement authority;
- album/frame production;
- review or milestone-follow-up workflow;
- media custody/DAM redesign;
- broad Pixieset integration;
- unrelated Team/RBAC redesign;
- unrelated CRM, quotation, payment, package or public-website changes;
- wholesale legacy-branch migration;
- Production mutation without separate explicit approval.

## Deferred non-blocking technical debt

Repository-wide authenticated `SECURITY DEFINER` advisor warnings remain separately governed architecture/security hardening work.

Previously recorded route-tree typing issues and database performance-hardening candidates remain separately governed technical debt.

## Current next action

Review and merge the Sprint 13 technical-design freeze governance change.

After merge, create the Sprint 13 implementation branch from the exact resulting `main` SHA, generate the migration with the installed Supabase CLI, record the exact filename in a filename-lock checkpoint, and request separate Sprint 13 implementation authorization.

Do not write Sprint 13 migration SQL, modify implementation code, or mutate Production before those gates are satisfied.
