# Sprint 10 Post-Release Reconciliation

Date: 2026-09-01 (Asia/Kolkata)
Status: INVESTIGATION / SPRINT 11 HOLD

## Authority

Sprint 10 runtime release remains closed through exact Stage 10 `shoot_scheduled`.
This reconciliation does not authorize Stage 11 functionality or any Production mutation.

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

## Control decision required

Do not archive/delete the two migration files yet. The application currently depends on their contracts.

Do not run a generic `supabase db push` while the migration-chain decision remains unresolved.

Do not mark either migration applied with `supabase migration repair` unless the corresponding schema has actually been deployed.

Before Sprint 11 begins, choose and verify one canonical reconciliation path:

1. **Complete the Team contract** — review, validate and separately authorize deployment of the two Team migrations to Production; or
2. **Withdraw the Team contract** — remove/disable the application surfaces and generated contracts that depend on the unapplied schema, then archive/restructure the migrations through an explicit repository-governance change.

Current recommendation: evaluate Path 1 first because the shipped application and generated Supabase types already express the Team contract. Production mutation still requires a separate explicit approval gate after verification.

## Sprint boundary

Sprint 11 remains HOLD until this reconciliation is closed.
