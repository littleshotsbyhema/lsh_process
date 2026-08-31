# Sprint 10 Production Release

Release status: COMPLETE / PRODUCTION RELEASED / CLOSED

Release date: 2026-09-01 (Asia/Kolkata)

## Authority

Production release was explicitly approved with the instruction:

`APPROVE SPRINT 10 PRODUCTION RELEASE`

The release remained bounded to the approved Sprint 10 pre-shoot operational surface. No Stage 11 or later operation was released.

## Canonical Application Release

- Pull request: #9 `feat: add pre-shoot operations workflow`
- Approved feature head: `5e693c836c93bd63f9405b5ab8ad8e4b9eb0b8e4`
- Production merge commit: `3a65cadf35abbfd3541859adf3946c47c0924ea3`
- Canonical Production branch: `main`

## Production Database Release

Exactly these four approved Sprint 10 migrations are recorded as applied in Production:

1. `20260819150000_sprint10_booking_team_assignment_read_model.sql`
2. `20260819170000_sprint10_booking_team_assignment_candidates.sql`
3. `20260831045642_booking_safety_service_category_read_model.sql`
4. `20260831080256_booking_safety_review_resilience.sql`

The first migration was initially applied through the Supabase management connector, which generated a non-canonical migration-history timestamp. Its migration ledger entry was repaired before continuing so Production history matches the repository-authoritative version `20260819150000`.

Two older local-only legacy migrations remain intentionally unapplied to Production and were not included in this release:

- `20260816221825_sprint10_canonical_team_access_foundation.sql`
- `20260817042405_sprint10_team_role_admin_read_model.sql`

They must not be silently marked applied because their schema objects do not exist in Production. A generic future `supabase db push` must not be used until this pre-existing migration-chain drift is resolved through a separate governance decision.

## Post-Migration Verification

Production verification confirmed:

- the migration ledger ends at `20260831080256` for this release;
- `get_booking_team_assignment_history(uuid)` exists;
- `get_booking_team_assignment_candidates(uuid)` exists;
- `get_booking_safety_service_category(uuid)` exists;
- `get_booking_safety_signoff_authority(uuid)` exists;
- all four functions are `SECURITY DEFINER` with an empty `search_path`;
- anonymous execution is denied for all four functions;
- authenticated execution is granted according to the approved contract;
- service-role execution is limited according to the migration contracts;
- `bookings`, `booking_team_assignments`, `external_creatives`, `booking_safety_readiness`, and `booking_safety_signoffs` retain FORCE RLS;
- authenticated direct INSERT/UPDATE/DELETE remains denied for controlled assignment and Safety evidence tables;
- anonymous DML remains denied;
- `team.role.assign` remains Founder-only;
- Safety sign-off role topology remains Founder, Photographer, Studio Manager, with booking-specific Lead Photographer authority enforced server-side;
- no Sprint 11 migration is present in Production;
- Production contained zero booking/team/safety rows at release, so no data backfill or collision handling was required.

Supabase security advisors reported the existing project-wide generic `SECURITY DEFINER` advisory classes and existing no-policy informational notices. No new anonymous execution exposure was introduced by the four Sprint 10 RPCs.

## Vercel Production Release

- Deployment ID: `dpl_3wo1GKoeddhztpYqiQnhToJ5NSHa`
- Git commit: `3a65cadf35abbfd3541859adf3946c47c0924ea3`
- Target: Production
- Final state: READY
- Production alias: `app.littleshotsbyhema.com`
- Alias error: none

The Vercel build completed successfully. Build output contained existing TanStack `createServerFn().inputValidator()` deprecation warnings and chunk-size warnings, but no release-blocking build error.

## Production Smoke Verification

Non-mutating Production smoke verification confirmed:

- `https://app.littleshotsbyhema.com/` returned HTTP 200;
- `https://app.littleshotsbyhema.com/bookings` returned HTTP 200;
- the deployed Bookings route resolved the new bookings and booking-functions bundles;
- no Production `error` or `fatal` runtime logs were present for the new deployment during the verification window.

A synthetic Production booking was deliberately not created because Production contained no bookings and release verification must not manufacture client/test records without separate authorization. The complete Stage 8 -> Stage 10 journey had already passed the controlled local/E2E and Vercel Preview gates before Production release.

## Known Non-Blocking Technical Debt

The Bookings workspace currently performs booking-scoped read RPC fan-out for safety category, sign-off authority, and assignment history. At the 100-booking page limit this can approach roughly 300 RPC requests. This is a performance/scalability concern, not a current security, data-integrity, or lifecycle-correctness defect. It should be replaced with batched read models before meaningful Production booking volume.

Existing TanStack `inputValidator()` deprecation warnings should also be removed in a separate maintenance slice.

## Release Boundary

Sprint 10 is released through exact Stage 10 `shoot_scheduled`.

Not released:

- Stage 10 -> Stage 11 advancement;
- shoot-completion workflow;
- post-shoot handoff;
- selection workflow;
- editing/QC/gallery progression;
- media custody or dual-custody transfer.

## Final State

Sprint 10: **COMPLETE / PRODUCTION RELEASED / CLOSED**.
