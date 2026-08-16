CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(42);

-- =====================================================================
-- Sprint 10 Slice 7B
-- Canonical Team Access Mutation Foundation — behavioral contract
--
-- Everything in this file is transaction-local and rolls back.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Fixture identities
--
-- Organization A
--   ...001 founder
--   ...002 studio manager
--   ...003 client coordinator
--   ...004 invited user
--   ...005 wrong-email user
--   ...006 unconfirmed-email user
--
-- Organization B
--   ...008 sole founder
-- ---------------------------------------------------------------------

INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at
)
VALUES
(
  '9b000000-0000-0000-0000-000000000001',
  'slice7b-founder@example.com',
  now()
),
(
  '9b000000-0000-0000-0000-000000000002',
  'slice7b-manager@example.com',
  now()
),
(
  '9b000000-0000-0000-0000-000000000003',
  'slice7b-coordinator@example.com',
  now()
),
(
  '9b000000-0000-0000-0000-000000000004',
  'slice7b-invitee@example.com',
  now()
),
(
  '9b000000-0000-0000-0000-000000000005',
  'slice7b-wrong@example.com',
  now()
),
(
  '9b000000-0000-0000-0000-000000000006',
  'slice7b-unconfirmed@example.com',
  NULL
),
(
  '9b000000-0000-0000-0000-000000000008',
  'slice7b-other-founder@example.com',
  now()
);

INSERT INTO public.organizations (
  id,
  display_name,
  slug
)
VALUES
(
  '9b100000-0000-0000-0000-000000000001',
  'Slice 7B Test Studio',
  'slice-7b-test-studio'
),
(
  '9b100000-0000-0000-0000-000000000002',
  'Slice 7B Isolation Studio',
  'slice-7b-isolation-studio'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  email,
  joined_at
)
VALUES
(
  '9b200000-0000-0000-0000-000000000001',
  '9b100000-0000-0000-0000-000000000001',
  '9b000000-0000-0000-0000-000000000001',
  'active',
  'Slice 7B Founder',
  'slice7b-founder@example.com',
  now()
),
(
  '9b200000-0000-0000-0000-000000000002',
  '9b100000-0000-0000-0000-000000000001',
  '9b000000-0000-0000-0000-000000000002',
  'active',
  'Slice 7B Studio Manager',
  'slice7b-manager@example.com',
  now()
),
(
  '9b200000-0000-0000-0000-000000000003',
  '9b100000-0000-0000-0000-000000000001',
  '9b000000-0000-0000-0000-000000000003',
  'active',
  'Slice 7B Client Coordinator',
  'slice7b-coordinator@example.com',
  now()
),
(
  '9b200000-0000-0000-0000-000000000008',
  '9b100000-0000-0000-0000-000000000002',
  '9b000000-0000-0000-0000-000000000008',
  'active',
  'Slice 7B Sole Founder',
  'slice7b-other-founder@example.com',
  now()
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id,
  granted_by
)
SELECT
  fixture.organization_id,
  fixture.member_id,
  role_row.id,
  NULL,
  fixture.granted_by
FROM (
  VALUES
    (
      '9b100000-0000-0000-0000-000000000001'::uuid,
      '9b200000-0000-0000-0000-000000000001'::uuid,
      'founder'::text,
      '9b200000-0000-0000-0000-000000000001'::uuid
    ),
    (
      '9b100000-0000-0000-0000-000000000001'::uuid,
      '9b200000-0000-0000-0000-000000000002'::uuid,
      'studio_manager'::text,
      '9b200000-0000-0000-0000-000000000001'::uuid
    ),
    (
      '9b100000-0000-0000-0000-000000000001'::uuid,
      '9b200000-0000-0000-0000-000000000003'::uuid,
      'client_coordinator'::text,
      '9b200000-0000-0000-0000-000000000001'::uuid
    ),
    (
      '9b100000-0000-0000-0000-000000000002'::uuid,
      '9b200000-0000-0000-0000-000000000008'::uuid,
      'founder'::text,
      '9b200000-0000-0000-0000-000000000008'::uuid
    )
) AS fixture(
  organization_id,
  member_id,
  role_key,
  granted_by
)
JOIN public.roles role_row
  ON role_row.key = fixture.role_key;

-- Prove the isolated fixtures satisfy existing deferred Founder coverage
-- before behavioral testing begins.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;


-- =====================================================================
-- Part 1 — Client Coordinator: Team read only
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_access_directory(
      '9b100000-0000-0000-0000-000000000001'
    )
  ),
  3::bigint,
  'client coordinator can read the canonical Team directory'
);

-- 2
SELECT throws_ok(
  $$
    SELECT *
    FROM public.create_organization_invitation(
      '9b100000-0000-0000-0000-000000000001',
      'slice7b-coordinator-denied@example.com',
      NULL,
      ARRAY[]::text[],
      336
    )
  $$,
  '42501',
  'create_organization_invitation: team.invite permission required',
  'client coordinator cannot create invitations'
);

-- 3
SELECT throws_ok(
  $$
    SELECT public.grant_organization_member_role(
      '9b100000-0000-0000-0000-000000000001',
      '9b200000-0000-0000-0000-000000000002',
      'editor',
      NULL
    )
  $$,
  '42501',
  'grant_organization_member_role: team.role.assign permission required',
  'client coordinator cannot assign roles'
);


-- =====================================================================
-- Part 2 — Studio Manager: invite yes, role assignment no
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10ca_manager_invite AS
SELECT *
FROM public.create_organization_invitation(
  '9b100000-0000-0000-0000-000000000001',
  'slice7b-manager-invite@example.com',
  'Manager Invite',
  ARRAY[]::text[],
  336
);

-- 4
SELECT is(
  (SELECT count(*)::bigint FROM s10ca_manager_invite),
  1::bigint,
  'studio manager can create an invitation without role assignments'
);

-- 5
SELECT is(
  (
    SELECT cardinality(role_keys)
    FROM s10ca_manager_invite
  ),
  0,
  'studio-manager invitation contains no role assignments'
);

-- 6
SELECT ok(
  (
    SELECT invite_token ~ '^[0-9a-f]{64}$'
    FROM s10ca_manager_invite
  ),
  'created invitation returns a 256-bit hexadecimal bearer token'
);

-- 7
SELECT ok(
  (
    SELECT
      invitation.token_hash =
        extensions.digest(
          created.invite_token,
          'sha256'
        )
      AND encode(
            invitation.token_hash,
            'hex'
          ) <> created.invite_token
    FROM s10ca_manager_invite created
    JOIN public.organization_invitations invitation
      ON invitation.id = created.invitation_id
  ),
  'database persists only the SHA-256 invitation token hash'
);

-- 8
SELECT throws_ok(
  $$
    SELECT *
    FROM public.create_organization_invitation(
      '9b100000-0000-0000-0000-000000000001',
      'slice7b-manager-role-denied@example.com',
      NULL,
      ARRAY['photographer']::text[],
      336
    )
  $$,
  '42501',
  'create_organization_invitation: team.role.assign permission required to pre-authorize roles',
  'studio manager cannot pre-authorize invitation roles'
);

-- 9
SELECT is(
  public.revoke_organization_invitation(
    '9b100000-0000-0000-0000-000000000001',
    (
      SELECT invitation_id
      FROM s10ca_manager_invite
    ),
    'Manager cancelled invitation'
  ),
  true,
  'studio manager can revoke an invitation'
);

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.preview_organization_invitation(
      (
        SELECT invite_token
        FROM s10ca_manager_invite
      )
    )
  ),
  0::bigint,
  'revoked invitation token cannot be previewed'
);

-- 11
SELECT is(
  public.revoke_organization_invitation(
    '9b100000-0000-0000-0000-000000000001',
    (
      SELECT invitation_id
      FROM s10ca_manager_invite
    ),
    'Repeated revocation'
  ),
  false,
  'revoking an already revoked invitation is idempotent'
);


-- =====================================================================
-- Part 3 — Founder invitation creation and token preview
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10ca_founder_invite AS
SELECT *
FROM public.create_organization_invitation(
  '9b100000-0000-0000-0000-000000000001',
  'slice7b-invitee@example.com',
  'Slice 7B Invitee',
  ARRAY[
    'photographer',
    'assistant',
    'assistant'
  ]::text[],
  336
);

SELECT set_config(
  'test.slice7b.founder_token',
  (
    SELECT invite_token
    FROM s10ca_founder_invite
  ),
  true
);

-- 12
SELECT is(
  (SELECT count(*)::bigint FROM s10ca_founder_invite),
  1::bigint,
  'Founder can create a role-bearing invitation'
);

-- 13
SELECT is(
  (
    SELECT role_keys
    FROM s10ca_founder_invite
  ),
  ARRAY[
    'assistant',
    'photographer'
  ]::text[],
  'invitation role keys are canonicalized and de-duplicated'
);

-- 14
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_invitation_directory(
      '9b100000-0000-0000-0000-000000000001'
    ) directory
    WHERE directory.invitation_id = (
      SELECT invitation_id
      FROM s10ca_founder_invite
    )
      AND directory.invitation_status = 'pending'
  ),
  1::bigint,
  'Founder invitation appears in the canonical pending invitation directory'
);

-- 15
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.preview_organization_invitation(
      current_setting(
        'test.slice7b.founder_token'
      )
    )
  ),
  1::bigint,
  'valid pending invitation token can be previewed'
);

-- 16
SELECT ok(
  (
    SELECT
      preview.organization_name =
        'Slice 7B Test Studio'
      AND preview.email =
        'slice7b-invitee@example.com'
      AND preview.full_name =
        'Slice 7B Invitee'
      AND preview.role_keys =
        ARRAY[
          'photographer',
          'assistant'
        ]::text[]
    FROM public.preview_organization_invitation(
      current_setting(
        'test.slice7b.founder_token'
      )
    ) preview
  ),
  'token preview exposes only the intended invitation projection'
);

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.preview_organization_invitation(
      repeat('0', 64)
    )
  ),
  0::bigint,
  'unknown bearer token reveals no invitation'
);


-- =====================================================================
-- Part 4 — Reissuing an invitation invalidates the old credential
-- =====================================================================

CREATE TEMP TABLE s10ca_reissue_1 AS
SELECT *
FROM public.create_organization_invitation(
  '9b100000-0000-0000-0000-000000000001',
  'slice7b-reissue@example.com',
  'Reissue Test',
  ARRAY[]::text[],
  336
);

CREATE TEMP TABLE s10ca_reissue_2 AS
SELECT *
FROM public.create_organization_invitation(
  '9b100000-0000-0000-0000-000000000001',
  'slice7b-reissue@example.com',
  'Reissue Test',
  ARRAY[]::text[],
  336
);

-- 18
SELECT is(
  (
    SELECT status::text
    FROM public.organization_invitations
    WHERE id = (
      SELECT invitation_id
      FROM s10ca_reissue_1
    )
  ),
  'revoked',
  'reissuing an invitation revokes the earlier pending invitation'
);

-- 19
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.preview_organization_invitation(
      (
        SELECT invite_token
        FROM s10ca_reissue_1
      )
    )
  ),
  0::bigint,
  'superseded invitation token is immediately unusable'
);

-- 20
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.preview_organization_invitation(
      (
        SELECT invite_token
        FROM s10ca_reissue_2
      )
    )
  ),
  1::bigint,
  'replacement invitation token is usable'
);

-- 21
SELECT ok(
  (
    SELECT
      first_invite.invite_token <>
      second_invite.invite_token
    FROM s10ca_reissue_1 first_invite
    CROSS JOIN s10ca_reissue_2 second_invite
  ),
  'reissued invitation receives a new bearer credential'
);


-- =====================================================================
-- Part 5 — Acceptance identity and confirmation rules
-- =====================================================================

CREATE TEMP TABLE s10ca_unconfirmed_invite AS
SELECT *
FROM public.create_organization_invitation(
  '9b100000-0000-0000-0000-000000000001',
  'slice7b-unconfirmed@example.com',
  'Unconfirmed Invitee',
  ARRAY[]::text[],
  336
);

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000006',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);

-- 22
SELECT throws_ok(
  $$
    SELECT *
    FROM public.accept_organization_invitation(
      (
        SELECT invite_token
        FROM s10ca_unconfirmed_invite
      )
    )
  $$,
  '42501',
  'accept_organization_invitation: email confirmation is required',
  'unconfirmed authenticated email cannot accept an invitation'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000005',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);

-- 23
SELECT throws_ok(
  $$
    SELECT *
    FROM public.accept_organization_invitation(
      current_setting(
        'test.slice7b.founder_token'
      )
    )
  $$,
  '42501',
  'accept_organization_invitation: invitation belongs to a different email address',
  'authenticated user cannot accept an invitation issued to another email'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000004',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10ca_accept_result AS
SELECT *
FROM public.accept_organization_invitation(
  current_setting(
    'test.slice7b.founder_token'
  )
);

-- 24
SELECT is(
  (
    SELECT count(*)::bigint
    FROM s10ca_accept_result
  ),
  1::bigint,
  'correct authenticated invitee can accept the invitation'
);

-- 25
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.organization_members member_row
    WHERE member_row.organization_id =
          '9b100000-0000-0000-0000-000000000001'
      AND member_row.user_id =
          '9b000000-0000-0000-0000-000000000004'
      AND member_row.status =
          'active'::public.member_status
      AND member_row.email =
          'slice7b-invitee@example.com'
      AND member_row.display_name =
          'Slice 7B Invitee'
  ),
  'acceptance creates an active canonical organization membership'
);

-- 26
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.member_role_grants grant_row
    JOIN public.roles role_row
      ON role_row.id = grant_row.role_id
    WHERE grant_row.organization_id =
          '9b100000-0000-0000-0000-000000000001'
      AND grant_row.organization_member_id = (
        SELECT member_row.id
        FROM public.organization_members member_row
        WHERE member_row.organization_id =
              '9b100000-0000-0000-0000-000000000001'
          AND member_row.user_id =
              '9b000000-0000-0000-0000-000000000004'
      )
      AND grant_row.revoked_at IS NULL
      AND role_row.key IN (
        'assistant',
        'photographer'
      )
  ),
  2::bigint,
  'acceptance materializes the two pre-authorized canonical role grants'
);

-- 27
SELECT ok(
  (
    SELECT
      invitation.status =
        'accepted'::public.organization_invitation_status
      AND invitation.accepted_at IS NOT NULL
      AND invitation.accepted_by = (
        SELECT member_row.id
        FROM public.organization_members member_row
        WHERE member_row.organization_id =
              invitation.organization_id
          AND member_row.user_id =
              '9b000000-0000-0000-0000-000000000004'
      )
    FROM public.organization_invitations invitation
    WHERE invitation.id = (
      SELECT invitation_id
      FROM s10ca_founder_invite
    )
  ),
  'accepted invitation records canonical membership linkage'
);

-- 28
SELECT throws_ok(
  $$
    SELECT *
    FROM public.accept_organization_invitation(
      current_setting(
        'test.slice7b.founder_token'
      )
    )
  $$,
  '22023',
  'accept_organization_invitation: invitation is no longer pending',
  'accepted bearer credential cannot be reused'
);


-- =====================================================================
-- Part 6 — Direct canonical role grant/revoke behavior
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10ca_editor_grant_1 AS
SELECT
  public.grant_organization_member_role(
    '9b100000-0000-0000-0000-000000000001',
    (
      SELECT member_row.id
      FROM public.organization_members member_row
      WHERE member_row.organization_id =
            '9b100000-0000-0000-0000-000000000001'
        AND member_row.user_id =
            '9b000000-0000-0000-0000-000000000004'
    ),
    'editor',
    NULL
  ) AS grant_id;

-- 29
SELECT ok(
  (
    SELECT grant_id IS NOT NULL
    FROM s10ca_editor_grant_1
  ),
  'Founder can grant an organization-wide canonical role'
);

CREATE TEMP TABLE s10ca_editor_grant_2 AS
SELECT
  public.grant_organization_member_role(
    '9b100000-0000-0000-0000-000000000001',
    (
      SELECT member_row.id
      FROM public.organization_members member_row
      WHERE member_row.organization_id =
            '9b100000-0000-0000-0000-000000000001'
        AND member_row.user_id =
            '9b000000-0000-0000-0000-000000000004'
    ),
    'editor',
    NULL
  ) AS grant_id;

-- 30
SELECT is(
  (
    SELECT grant_id
    FROM s10ca_editor_grant_2
  ),
  (
    SELECT grant_id
    FROM s10ca_editor_grant_1
  ),
  'granting the same live role twice is idempotent'
);

-- 31
SELECT is(
  public.revoke_organization_member_role(
    '9b100000-0000-0000-0000-000000000001',
    (
      SELECT member_row.id
      FROM public.organization_members member_row
      WHERE member_row.organization_id =
            '9b100000-0000-0000-0000-000000000001'
        AND member_row.user_id =
            '9b000000-0000-0000-0000-000000000004'
    ),
    'editor',
    NULL,
    'Slice 7B behavioral revocation'
  ),
  true,
  'Founder can revoke a live canonical role grant'
);

-- 32
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.member_role_grants grant_row
    WHERE grant_row.id = (
      SELECT grant_id
      FROM s10ca_editor_grant_1
    )
      AND grant_row.revoked_at IS NOT NULL
      AND grant_row.revoked_by =
          '9b200000-0000-0000-0000-000000000001'
      AND grant_row.revocation_reason =
          'Slice 7B behavioral revocation'
  ),
  'role revocation preserves the historical grant row'
);

-- 33
SELECT is(
  public.revoke_organization_member_role(
    '9b100000-0000-0000-0000-000000000001',
    (
      SELECT member_row.id
      FROM public.organization_members member_row
      WHERE member_row.organization_id =
            '9b100000-0000-0000-0000-000000000001'
        AND member_row.user_id =
            '9b000000-0000-0000-0000-000000000004'
    ),
    'editor',
    NULL,
    'Repeated revocation'
  ),
  false,
  'revoking a role with no live grant is idempotent'
);

CREATE TEMP TABLE s10ca_editor_grant_3 AS
SELECT
  public.grant_organization_member_role(
    '9b100000-0000-0000-0000-000000000001',
    (
      SELECT member_row.id
      FROM public.organization_members member_row
      WHERE member_row.organization_id =
            '9b100000-0000-0000-0000-000000000001'
        AND member_row.user_id =
            '9b000000-0000-0000-0000-000000000004'
    ),
    'editor',
    NULL
  ) AS grant_id;

-- 34
SELECT isnt(
  (
    SELECT grant_id
    FROM s10ca_editor_grant_3
  ),
  (
    SELECT grant_id
    FROM s10ca_editor_grant_1
  ),
  'granting a previously revoked role creates new historical evidence'
);

-- 35
SELECT ok(
  (
    SELECT
      count(*) = 2
      AND count(*) FILTER (
        WHERE grant_row.revoked_at IS NULL
      ) = 1
    FROM public.member_role_grants grant_row
    JOIN public.roles role_row
      ON role_row.id = grant_row.role_id
    WHERE grant_row.organization_id =
          '9b100000-0000-0000-0000-000000000001'
      AND grant_row.organization_member_id = (
        SELECT member_row.id
        FROM public.organization_members member_row
        WHERE member_row.organization_id =
              '9b100000-0000-0000-0000-000000000001'
          AND member_row.user_id =
              '9b000000-0000-0000-0000-000000000004'
      )
      AND role_row.key = 'editor'
  ),
  'role history contains one revoked grant and one current live grant'
);


-- =====================================================================
-- Part 7 — Tenant isolation
-- =====================================================================

-- Still authenticated as Organization A Founder.

-- 36
SELECT throws_ok(
  $$
    SELECT public.grant_organization_member_role(
      '9b100000-0000-0000-0000-000000000002',
      '9b200000-0000-0000-0000-000000000008',
      'editor',
      NULL
    )
  $$,
  '42501',
  'grant_organization_member_role: active organization membership required',
  'Founder cannot mutate membership in an organization they do not belong to'
);


-- =====================================================================
-- Part 8 — Sensitive audit evidence and token secrecy
-- =====================================================================

-- 37
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit_row
    WHERE audit_row.organization_id =
          '9b100000-0000-0000-0000-000000000001'
      AND audit_row.action_key LIKE 'team.%'
      AND audit_row.is_sensitive IS DISTINCT FROM true
  ),
  'all Slice 7B Team mutation audit events are sensitive'
);

-- 38
SELECT is(
  (
    SELECT count(DISTINCT audit_row.action_key)::bigint
    FROM public.audit_events audit_row
    WHERE audit_row.organization_id =
          '9b100000-0000-0000-0000-000000000001'
      AND audit_row.action_key IN (
        'team.invitation.created',
        'team.invitation.revoked',
        'team.invitation.accepted',
        'team.role.granted',
        'team.role.revoked'
      )
  ),
  5::bigint,
  'audit trail contains all five canonical Slice 7B mutation action classes'
);

-- 39
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit_row
    CROSS JOIN s10ca_founder_invite created
    WHERE audit_row.organization_id =
          '9b100000-0000-0000-0000-000000000001'
      AND position(
            created.invite_token
            IN
            (
              COALESCE(
                audit_row.old_values::text,
                ''
              )
              ||
              COALESCE(
                audit_row.new_values::text,
                ''
              )
              ||
              COALESCE(
                audit_row.metadata::text,
                ''
              )
            )
          ) > 0
  ),
  'raw invitation bearer token never appears in audit payloads'
);


-- =====================================================================
-- Part 9 — Existing deferred final-Founder protection
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '9b000000-0000-0000-0000-000000000008',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"9b000000-0000-0000-0000-000000000008","role":"authenticated"}',
  true
);

-- Make the existing deferred coverage guards fire at statement end so
-- the attempted final-Founder revocation can be caught inside a local
-- PL/pgSQL subtransaction.
SET CONSTRAINTS ALL IMMEDIATE;

CREATE OR REPLACE FUNCTION pg_temp.s10ca_final_founder_revoke_blocked()
RETURNS boolean
LANGUAGE plpgsql
AS $function$
BEGIN
  BEGIN
    PERFORM public.revoke_organization_member_role(
      '9b100000-0000-0000-0000-000000000002',
      '9b200000-0000-0000-0000-000000000008',
      'founder',
      NULL,
      'Attempted final Founder revocation'
    );

    RETURN false;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN true;
  END;
END
$function$;

-- 40
SELECT ok(
  pg_temp.s10ca_final_founder_revoke_blocked(),
  'existing database guard blocks revocation of the final active Founder'
);

-- 41
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.member_role_grants grant_row
    JOIN public.roles role_row
      ON role_row.id = grant_row.role_id
    WHERE grant_row.organization_id =
          '9b100000-0000-0000-0000-000000000002'
      AND grant_row.organization_member_id =
          '9b200000-0000-0000-0000-000000000008'
      AND role_row.key = 'founder'
      AND grant_row.branch_id IS NULL
      AND grant_row.revoked_at IS NULL
  ),
  1::bigint,
  'failed final-Founder revocation leaves the Founder grant live'
);

-- 42
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit_row
    WHERE audit_row.organization_id =
          '9b100000-0000-0000-0000-000000000002'
      AND audit_row.action_key =
          'team.role.revoked'
  ),
  0::bigint,
  'failed final-Founder revocation rolls back its audit event atomically'
);


SELECT * FROM finish();

ROLLBACK;
