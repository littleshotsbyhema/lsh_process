# Sprint 10 Post-Release Reconciliation

Date: 2026-09-01 (Asia/Kolkata)
Status: CLOSED / PRODUCTION RECONCILED / SPRINT 11 HOLD RELEASED

## Authority

Sprint 10 runtime release remains closed through exact Stage 10 `shoot_scheduled`.
This reconciliation does not authorize Stage 11 functionality by itself; it only removes the Team contract blocker that was holding Sprint 11.

## Original reconciliation issue

The active repository migration directory contained two migrations that were absent from the Production migration ledger and whose schema objects were absent from Production:

- `20260816221825_sprint10_canonical_team_access_foundation.sql`
- `20260817042405_sprint10_team_role_admin_read_model.sql`

The shipped authenticated `/team` application surface depended on the RPCs supplied by those migrations, while the Production Founder role already held `team.read`, `team.invite`, `team.role.assign`, and `team.suspend`.

This created a real application/database contract mismatch separate from the already healthy Sprint 10 booking/pre-shoot runtime.

## Local verification completed before Production authorization

Path 1, **Complete the Team contract**, completed the full local verification gate on the reconciliation branch.

Verified gates:

- full local migration replay: PASS
- dedicated Team Access pgTAP: 42/42 PASS
- dedicated Team Role Admin pgTAP: 21/21 PASS
- full `sprint10_*.sql` suite: 801/801 PASS
- local database lint: PASS
- local database advisors: PASS
- Founder local authorization chain: PASS
- Founder `/team` read-model rendering: PASS
- role administration rendering: PASS
- invitation creation: PASS
- one-time invitation link generation: PASS
- pending invitation rendering: PASS
- invitation revocation: PASS
- revoked-state rendering: PASS

The local verification initially exposed a suspended canonical organization after `db reset`. This was confirmed to be intentional bootstrap behavior, not a Team migration defect. Once the local canonical Founder bootstrap state was completed and the organization activated, `current_organization_member(...)` and `effective_permissions(...)` resolved correctly.

## ACL and security verification

The ten Team RPCs were independently inspected locally and again in Production after deployment.

Confirmed controls:

- all ten functions are `SECURITY DEFINER`
- all ten functions use an empty `search_path`
- `PUBLIC` execute is denied for all ten functions
- `anon` execute is denied for all Team RPCs except `preview_organization_invitation(text)`
- `preview_organization_invitation(text)` intentionally permits anonymous execution for token-gated invitation preview
- authenticated execution is granted to the application-facing Team RPCs
- service-role execution is available as designed
- `organization_invitations` has RLS enabled and forced
- `organization_invitation_roles` has RLS enabled and forced
- `anon` has no direct SELECT/INSERT/UPDATE/DELETE privilege on either invitation table
- `authenticated` has no direct SELECT/INSERT/UPDATE/DELETE privilege on either invitation table
- `service_role` retains direct table access

The Supabase security advisor reports its generic warning for exposed `SECURITY DEFINER` RPCs, including the intentionally anonymous token-gated invitation preview and authenticated Team RPCs. The exact ACL verification above confirms no unintended `PUBLIC` execution and no direct authenticated table DML. Existing unrelated advisor notices remain outside this reconciliation scope.

## Frozen and deployed Production reconciliation manifest

The exact Production database reconciliation manifest was frozen and explicitly authorized as these two migrations only, in canonical migration order:

1. `20260816221825_sprint10_canonical_team_access_foundation.sql`
2. `20260817042405_sprint10_team_role_admin_read_model.sql`

The linked Supabase CLI dry run listed exactly those two migrations and no others.

The authorized Production deployment then applied exactly those two migrations successfully.

## Independent Production verification

Post-deployment verification confirmed:

- `20260816221825 | sprint10_canonical_team_access_foundation` is present in the Production migration ledger
- `20260817042405 | sprint10_team_role_admin_read_model` is present in the Production migration ledger
- all ten expected Team RPCs are present with the verified signatures and ACL contract
- both invitation tables are present with RLS enabled and forced
- `anon` and `authenticated` have no direct DML on the invitation tables
- service role retains intended direct access
- Founder role maps to exactly the four Team permissions: `team.invite`, `team.read`, `team.role.assign`, `team.suspend`
- the canonical organization is active and not deleted
- exactly one active organization-wide Founder grant remains
- the new invitation tables contain zero rows immediately after deployment, confirming no synthetic Production invite data was introduced

No Stage 11 schema or functionality was deployed by this reconciliation.

## Closure decision

Team reconciliation: **CLOSED**.

Production Team application/database contract: **RECONCILED**.

Sprint 10 booking/pre-shoot release remains healthy and closed.

The reconciliation-specific Sprint 11 HOLD is now released. Any Sprint 11 implementation still requires its own scope freeze, dependency review, verification plan, and explicit Production authorization gates.

## Remaining documentation drift

`docs/CURRENT_MILESTONE.md` still contains stale pre-release Sprint 10 wording and should be reconciled separately before Sprint 11 execution begins.
