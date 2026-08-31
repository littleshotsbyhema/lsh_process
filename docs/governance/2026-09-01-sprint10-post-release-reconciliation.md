# Sprint 10 Post-Release Reconciliation

Date: 2026-09-01 (Asia/Kolkata)
Status: READY FOR PRODUCTION AUTHORIZATION / SPRINT 11 HOLD

## Authority

Sprint 10 runtime release remains closed through exact Stage 10 `shoot_scheduled`.
This reconciliation does not authorize Stage 11 functionality.
Production mutation for the Team reconciliation remains separately approval-gated.

## Confirmed documentation drift

`docs/CURRENT_MILESTONE.md` still describes the pre-release feature branch and states that remote Supabase mutation / Production deployment are unauthorized. That is stale after the approved Sprint 10 Production release recorded in `docs/releases/2026-09-01-sprint-10-production-release.md`.

## Confirmed migration-chain drift

The active repository migration directory contains two migrations that are not recorded in the Production migration ledger and whose schema objects are absent from Production:

- `20260816221825_sprint10_canonical_team_access_foundation.sql`
- `20260817042405_sprint10_team_role_admin_read_model.sql`

They must not be marked applied through migration repair while their schema objects are absent.

The four authorized Sprint 10 Production migrations remain recorded canonically:

- `20260819150000`
- `20260819170000`
- `20260831045642`
- `20260831080256`

## Confirmed application / database contract mismatch

The current application contains an authenticated `/team` route and server functions that depend on database objects supplied by the two unapplied migrations.

Current application dependencies include:

- `team_access_directory(uuid)`
- `team_invitation_directory(uuid)`
- `create_organization_invitation(...)`
- `revoke_organization_invitation(...)`
- `preview_organization_invitation(text)`
- `accept_organization_invitation(text)`
- `grant_organization_member_role(...)`
- `revoke_organization_member_role(...)`
- `team_role_grant_directory(uuid,uuid)`
- `team_role_scope_catalogue(uuid)`

Production verification on 2026-09-01 confirmed these objects are absent.

The Production Founder role currently has:

- `team.read`
- `team.invite`
- `team.role.assign`
- `team.suspend`

Therefore the current Founder `/team` page is eligible to invoke database RPCs that do not exist in Production. This is a real Production contract mismatch, separate from the released Sprint 10 booking/pre-shoot runtime.

## Path 1 verification result

Path 1, **Complete the Team contract**, has completed local verification on the reconciliation branch.

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

Founder Team permissions verified locally:

- `team.read`
- `team.invite`
- `team.role.assign`
- `team.suspend`

## ACL and security verification

The ten Team RPCs were independently inspected locally.

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

Local ACL/security gate: APPROVED.

## Frozen Production reconciliation manifest

The exact Production database reconciliation manifest is frozen to these two migrations only, in canonical migration order:

1. `20260816221825_sprint10_canonical_team_access_foundation.sql`
2. `20260817042405_sprint10_team_role_admin_read_model.sql`

No other migration is authorized by this manifest.

Specifically excluded unless separately approved:

- generic `supabase db push` across any wider migration set
- migration-ledger repair used as a substitute for deploying missing schema
- Stage 11 or later schema/functionality
- unrelated permission, role, booking, journey, safety or production workflow changes
- deletion or archival of the two Team migrations

## Production deployment gate

Technical verification is complete and the two-migration manifest is approved to freeze.

Production deployment remains **HOLD** until a separate explicit authorization is given for this exact two-migration manifest.

After authorization, deployment must be followed by independent Production verification of:

- both canonical migration ledger versions
- presence and signatures of all Team RPCs
- exact RPC ACLs
- invitation-table RLS / forced-RLS state
- direct table privilege boundaries
- Production Founder `/team` contract behavior
- absence of unintended migration or schema changes

## Sprint boundary

Sprint 11 remains HOLD until the Team reconciliation is deployed to Production, independently verified, and formally closed.
