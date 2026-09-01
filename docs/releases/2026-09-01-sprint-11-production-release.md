# Sprint 11 Production Release

## Status

COMPLETE / RELEASED / VERIFIED

## Release scope

Sprint 11 releases the exact journey boundary:

`Stage 10 shoot_scheduled -> Stage 11 shoot_completed`

No Stage 11 -> Stage 12 functionality is included in this release.

## Canonical repository release

Sprint 11 implementation was merged through PR #11.

Implementation head:

`7b1e8fffc8e12e72484a1ca87e6098aaeb40de3c`

Production merge commit on `main`:

`8ca0b8ff64ece7a579540e9bae0ef708c77bc8d5`

## Production application deployment

Vercel Production deployment:

`dpl_G3PGcySexqXS1W7mAG3GX4md87HT`

Verified state:

- target: Production;
- source branch: `main`;
- Git commit: `8ca0b8ff64ece7a579540e9bae0ef708c77bc8d5`;
- deployment state: `READY`;
- production alias includes `app.littleshotsbyhema.com`.

## Production database deployment

The following canonical Sprint 11 migrations are applied and recorded in the Production migration ledger:

- `20260901160123_sprint11_shoot_completion_evidence_foundation.sql`
- `20260901160125_sprint11_stage10_11_gate_foundation.sql`

Migration-history reconciliation was completed after deployment so Production now tracks the exact repository-frozen versions above.

## Verified Production contract

Post-deployment verification confirmed:

- `booking_shoot_completions` exists;
- `record_booking_shoot_completion(uuid,timestamptz)` exists;
- `mark_booking_shoot_completed(uuid)` exists;
- `shoot.complete` exists and requires server enforcement;
- `shoot.complete` is granted exactly to Founder, Studio Manager and Photographer;
- canonical role-permission count is `233`;
- completion evidence has RLS enabled and forced;
- authenticated read access is contained by `booking.read` plus branch scope;
- authenticated direct INSERT, UPDATE and DELETE on completion evidence are denied;
- both Sprint 11 RPCs are `SECURITY DEFINER` with fixed empty `search_path`;
- anon and service-role RPC execution is denied;
- authenticated execution is allowed only through the controlled RPC surfaces;
- the completion-recording RPC enforces authentication, `shoot.complete` and branch scope;
- the Stage 10 -> 11 RPC enforces authentication, `booking.stage.advance` and branch scope;
- completion evidence terminalizes future shoot-schedule insertion without rewriting schedule history;
- Stage 11 replay remains strict;
- no Stage 12 advancement is released.

## Validation evidence

Before release, local verification passed:

- dedicated Sprint 11 pgTAP: 106 / 106;
- full database regression: 1268 tests;
- database lint: no schema errors;
- local database advisors: no Sprint 11 blocker;
- application build: pass;
- exact eight-path implementation boundary: pass;
- local end-to-end Stage 10 -> 11 workflow: pass.

## Advisory follow-up

Supabase Production advisors report an INFO-level performance item for the `booking_shoot_completions_recorded_by_fkey` foreign key lacking a dedicated covering index. This does not invalidate the released security or functional contract and is deferred to a separately governed performance-hardening change.

Existing repository-wide advisor notices remain outside this release boundary unless separately authorized.

## Release conclusion

Sprint 11 is complete in Production through exact Stage 11 `shoot_completed`.

Stage 12 `selection_pending` remains unreleased and requires a new frozen milestone, technical design and explicit implementation authorization.
