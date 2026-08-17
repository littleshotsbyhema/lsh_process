CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(21);

-- =====================================================================
-- Little Shots by Hema OS
-- Sprint 10 Slice 7D
-- Canonical Role Administration Read Model — behavioral contract
--
-- All fixture data is transaction-local and rolls back.
-- =====================================================================


-- =====================================================================
-- 1. Fixture identities
-- =====================================================================

INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at
)
VALUES
(
  '7d000000-0000-0000-0000-000000000001',
  'slice7d-founder@example.com',
  now()
),
(
  '7d000000-0000-0000-0000-000000000002',
  'slice7d-manager@example.com',
  now()
),
(
  '7d000000-0000-0000-0000-000000000003',
  'slice7d-coordinator@example.com',
  now()
),
(
  '7d000000-0000-0000-0000-000000000004',
  'slice7d-target@example.com',
  now()
),
(
  '7d000000-0000-0000-0000-000000000005',
  'slice7d-other-member@example.com',
  now()
),
(
  '7d000000-0000-0000-0000-000000000008',
  'slice7d-other-founder@example.com',
  now()
),
(
  '7d000000-0000-0000-0000-000000000009',
  'slice7d-other-target@example.com',
  now()
);


INSERT INTO public.organizations (
  id,
  display_name,
  slug
)
VALUES
(
  '7d100000-0000-0000-0000-000000000001',
  'Slice 7D Test Studio',
  'slice-7d-test-studio'
),
(
  '7d100000-0000-0000-0000-000000000002',
  'Slice 7D Isolation Studio',
  'slice-7d-isolation-studio'
);


INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  deleted_at
)
VALUES
(
  '7d400000-0000-0000-0000-000000000001',
  '7d100000-0000-0000-0000-000000000001',
  'Slice 7D Active Branch',
  'slice7d-active',
  'active',
  NULL
),
(
  '7d400000-0000-0000-0000-000000000002',
  '7d100000-0000-0000-0000-000000000001',
  'Slice 7D Inactive Branch',
  'slice7d-inactive',
  'inactive',
  NULL
),
(
  '7d400000-0000-0000-0000-000000000003',
  '7d100000-0000-0000-0000-000000000001',
  'Slice 7D Deleted Branch',
  'slice7d-deleted',
  'active',
  now()
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
  '7d200000-0000-0000-0000-000000000001',
  '7d100000-0000-0000-0000-000000000001',
  '7d000000-0000-0000-0000-000000000001',
  'active',
  'Slice 7D Founder',
  'slice7d-founder@example.com',
  now()
),
(
  '7d200000-0000-0000-0000-000000000002',
  '7d100000-0000-0000-0000-000000000001',
  '7d000000-0000-0000-0000-000000000002',
  'active',
  'Slice 7D Studio Manager',
  'slice7d-manager@example.com',
  now()
),
(
  '7d200000-0000-0000-0000-000000000003',
  '7d100000-0000-0000-0000-000000000001',
  '7d000000-0000-0000-0000-000000000003',
  'active',
  'Slice 7D Client Coordinator',
  'slice7d-coordinator@example.com',
  now()
),
(
  '7d200000-0000-0000-0000-000000000004',
  '7d100000-0000-0000-0000-000000000001',
  '7d000000-0000-0000-0000-000000000004',
  'active',
  'Slice 7D Target Member',
  'slice7d-target@example.com',
  now()
),
(
  '7d200000-0000-0000-0000-000000000005',
  '7d100000-0000-0000-0000-000000000001',
  '7d000000-0000-0000-0000-000000000005',
  'active',
  'Slice 7D Other Member',
  'slice7d-other-member@example.com',
  now()
),
(
  '7d200000-0000-0000-0000-000000000008',
  '7d100000-0000-0000-0000-000000000002',
  '7d000000-0000-0000-0000-000000000008',
  'active',
  'Slice 7D Other Founder',
  'slice7d-other-founder@example.com',
  now()
),
(
  '7d200000-0000-0000-0000-000000000009',
  '7d100000-0000-0000-0000-000000000002',
  '7d000000-0000-0000-0000-000000000009',
  'active',
  'Slice 7D Other Target',
  'slice7d-other-target@example.com',
  now()
);


-- =====================================================================
-- 2. Exact canonical grants
-- =====================================================================

INSERT INTO public.member_role_grants (
  id,
  organization_id,
  organization_member_id,
  role_id,
  branch_id,
  granted_at,
  granted_by,
  revoked_at,
  revoked_by,
  revocation_reason
)
SELECT
  fixture.grant_id,
  fixture.organization_id,
  fixture.member_id,
  role_row.id,
  fixture.branch_id,
  fixture.granted_at,
  fixture.granted_by,
  fixture.revoked_at,
  fixture.revoked_by,
  fixture.revocation_reason
FROM (
  VALUES
    (
      '7d300000-0000-0000-0000-000000000001'::uuid,
      '7d100000-0000-0000-0000-000000000001'::uuid,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      'founder'::text,
      NULL::uuid,
      '2026-08-17 00:00:01+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      NULL::timestamptz,
      NULL::uuid,
      NULL::text
    ),
    (
      '7d300000-0000-0000-0000-000000000002'::uuid,
      '7d100000-0000-0000-0000-000000000001'::uuid,
      '7d200000-0000-0000-0000-000000000002'::uuid,
      'studio_manager'::text,
      NULL::uuid,
      '2026-08-17 00:00:02+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      NULL::timestamptz,
      NULL::uuid,
      NULL::text
    ),
    (
      '7d300000-0000-0000-0000-000000000003'::uuid,
      '7d100000-0000-0000-0000-000000000001'::uuid,
      '7d200000-0000-0000-0000-000000000003'::uuid,
      'client_coordinator'::text,
      NULL::uuid,
      '2026-08-17 00:00:03+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      NULL::timestamptz,
      NULL::uuid,
      NULL::text
    ),
    (
      '7d300000-0000-0000-0000-000000000004'::uuid,
      '7d100000-0000-0000-0000-000000000001'::uuid,
      '7d200000-0000-0000-0000-000000000004'::uuid,
      'editor'::text,
      NULL::uuid,
      '2026-08-17 00:00:04+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      NULL::timestamptz,
      NULL::uuid,
      NULL::text
    ),
    (
      '7d300000-0000-0000-0000-000000000005'::uuid,
      '7d100000-0000-0000-0000-000000000001'::uuid,
      '7d200000-0000-0000-0000-000000000004'::uuid,
      'editor'::text,
      '7d400000-0000-0000-0000-000000000001'::uuid,
      '2026-08-17 00:00:05+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      NULL::timestamptz,
      NULL::uuid,
      NULL::text
    ),
    (
      '7d300000-0000-0000-0000-000000000006'::uuid,
      '7d100000-0000-0000-0000-000000000001'::uuid,
      '7d200000-0000-0000-0000-000000000004'::uuid,
      'assistant'::text,
      NULL::uuid,
      '2026-08-17 00:00:06+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      '2026-08-17 00:10:06+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      'Slice 7D revoked fixture'::text
    ),
    (
      '7d300000-0000-0000-0000-000000000007'::uuid,
      '7d100000-0000-0000-0000-000000000001'::uuid,
      '7d200000-0000-0000-0000-000000000005'::uuid,
      'photographer'::text,
      '7d400000-0000-0000-0000-000000000001'::uuid,
      '2026-08-17 00:00:07+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000001'::uuid,
      NULL::timestamptz,
      NULL::uuid,
      NULL::text
    ),
    (
      '7d300000-0000-0000-0000-000000000008'::uuid,
      '7d100000-0000-0000-0000-000000000002'::uuid,
      '7d200000-0000-0000-0000-000000000008'::uuid,
      'founder'::text,
      NULL::uuid,
      '2026-08-17 00:00:08+00'::timestamptz,
      '7d200000-0000-0000-0000-000000000008'::uuid,
      NULL::timestamptz,
      NULL::uuid,
      NULL::text
    )
) AS fixture(
  grant_id,
  organization_id,
  member_id,
  role_key,
  branch_id,
  granted_at,
  granted_by,
  revoked_at,
  revoked_by,
  revocation_reason
)
JOIN public.roles role_row
  ON role_row.key = fixture.role_key;


-- Force existing deferred Founder coverage checks now, then restore
-- deferred behavior for the remainder of the transaction.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;


-- =====================================================================
-- 3. Founder authorization and basic directories
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '7d000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7d000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      NULL
    )
  ),
  6::bigint,
  'Founder can read all exact live role grants in the authorized organization'
);

-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_scope_catalogue(
      '7d100000-0000-0000-0000-000000000001'
    )
  ),
  2::bigint,
  'Founder can read organization-wide plus active assignment scopes'
);


-- =====================================================================
-- 4. Studio Manager and Client Coordinator denial
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '7d000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7d000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 3
SELECT throws_ok(
  $$
    SELECT *
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      NULL
    )
  $$,
  '42501',
  'team_role_grant_directory: team.role.assign permission required',
  'Studio Manager cannot read exact role-grant administration detail'
);

-- 4
SELECT throws_ok(
  $$
    SELECT *
    FROM public.team_role_scope_catalogue(
      '7d100000-0000-0000-0000-000000000001'
    )
  $$,
  '42501',
  'team_role_scope_catalogue: team.role.assign permission required',
  'Studio Manager cannot read role-assignment scope choices'
);


SELECT set_config(
  'request.jwt.claim.sub',
  '7d000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7d000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

-- 5
SELECT throws_ok(
  $$
    SELECT *
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      NULL
    )
  $$,
  '42501',
  'team_role_grant_directory: team.role.assign permission required',
  'Client Coordinator cannot read exact role-grant administration detail'
);

-- 6
SELECT throws_ok(
  $$
    SELECT *
    FROM public.team_role_scope_catalogue(
      '7d100000-0000-0000-0000-000000000001'
    )
  $$,
  '42501',
  'team_role_scope_catalogue: team.role.assign permission required',
  'Client Coordinator cannot read role-assignment scope choices'
);


-- =====================================================================
-- 5. Restore Founder context for exact projection tests
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '7d000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7d000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 7
SELECT ok(
  (
    SELECT
      directory.grant_id =
        '7d300000-0000-0000-0000-000000000004'::uuid
      AND directory.member_id =
        '7d200000-0000-0000-0000-000000000004'::uuid
      AND directory.role_key = 'editor'
      AND directory.role_label = 'Editor / Retoucher'
      AND directory.branch_id IS NULL
      AND directory.branch_name IS NULL
      AND directory.branch_code IS NULL
      AND directory.organization_wide = true
      AND directory.granted_at =
        '2026-08-17 00:00:04+00'::timestamptz
      AND directory.granted_by_member_id =
        '7d200000-0000-0000-0000-000000000001'::uuid
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      '7d200000-0000-0000-0000-000000000004'
    ) directory
    WHERE directory.grant_id =
      '7d300000-0000-0000-0000-000000000004'::uuid
  ),
  'organization-wide grant projection is exact'
);

-- 8
SELECT ok(
  (
    SELECT
      directory.grant_id =
        '7d300000-0000-0000-0000-000000000005'::uuid
      AND directory.member_id =
        '7d200000-0000-0000-0000-000000000004'::uuid
      AND directory.role_key = 'editor'
      AND directory.role_label = 'Editor / Retoucher'
      AND directory.branch_id =
        '7d400000-0000-0000-0000-000000000001'::uuid
      AND directory.branch_name =
        'Slice 7D Active Branch'
      AND directory.branch_code =
        'slice7d-active'
      AND directory.organization_wide = false
      AND directory.granted_at =
        '2026-08-17 00:00:05+00'::timestamptz
      AND directory.granted_by_member_id =
        '7d200000-0000-0000-0000-000000000001'::uuid
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      '7d200000-0000-0000-0000-000000000004'
    ) directory
    WHERE directory.grant_id =
      '7d300000-0000-0000-0000-000000000005'::uuid
  ),
  'branch-scoped grant projection is exact'
);

-- 9
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      '7d200000-0000-0000-0000-000000000004'
    ) directory
    WHERE directory.role_key = 'editor'
  ),
  2::bigint,
  'organization-wide and branch-scoped grants for the same role remain independent rows'
);

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      '7d200000-0000-0000-0000-000000000004'
    ) directory
    WHERE directory.grant_id =
      '7d300000-0000-0000-0000-000000000006'::uuid
  ),
  0::bigint,
  'revoked grants are omitted from the operational role-grant directory'
);

-- 11
SELECT ok(
  (
    SELECT
      count(*) = 2
      AND count(DISTINCT directory.member_id) = 1
      AND bool_and(
        directory.member_id =
          '7d200000-0000-0000-0000-000000000004'::uuid
      )
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      '7d200000-0000-0000-0000-000000000004'
    ) directory
  ),
  'member filtering returns only the requested same-organization member'
);

-- 12
SELECT throws_ok(
  $$
    SELECT *
    FROM public.team_role_grant_directory(
      '7d100000-0000-0000-0000-000000000001',
      '7d200000-0000-0000-0000-000000000009'
    )
  $$,
  '22023',
  'team_role_grant_directory: target member is unavailable in this organization',
  'cross-organization member filtering does not leak role-grant data'
);


-- =====================================================================
-- 6. Exact assignment-scope catalogue
-- =====================================================================

-- 13
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_scope_catalogue(
      '7d100000-0000-0000-0000-000000000001'
    ) scope
    WHERE scope.branch_id =
      '7d400000-0000-0000-0000-000000000001'::uuid
      AND scope.branch_name = 'Slice 7D Active Branch'
      AND scope.branch_code = 'slice7d-active'
      AND scope.organization_wide = false
  ),
  1::bigint,
  'active branch is available as an exact role-assignment scope'
);

-- 14
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_scope_catalogue(
      '7d100000-0000-0000-0000-000000000001'
    ) scope
    WHERE scope.branch_id =
      '7d400000-0000-0000-0000-000000000002'::uuid
  ),
  0::bigint,
  'inactive branch is absent from role-assignment scope choices'
);

-- 15
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_scope_catalogue(
      '7d100000-0000-0000-0000-000000000001'
    ) scope
    WHERE scope.branch_id =
      '7d400000-0000-0000-0000-000000000003'::uuid
  ),
  0::bigint,
  'deleted branch is absent from role-assignment scope choices'
);

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_role_scope_catalogue(
      '7d100000-0000-0000-0000-000000000001'
    ) scope
    WHERE scope.branch_id IS NULL
      AND scope.branch_name = 'Organization-wide'
      AND scope.branch_code IS NULL
      AND scope.organization_wide = true
  ),
  1::bigint,
  'authorized actor always receives one exact organization-wide synthetic scope'
);


-- =====================================================================
-- 7. Security and function privilege invariants
-- =====================================================================

-- 17
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.member_role_grants',
    'SELECT'
  )
  AND (
    SELECT
      c.relrowsecurity
      AND c.relforcerowsecurity
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'member_role_grants'
  ),
  'authenticated direct role-grant reads remain unavailable and RLS remains forced'
);

-- 18
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.team_role_grant_directory(uuid,uuid)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.team_role_grant_directory(uuid,uuid)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'service_role',
    'public.team_role_grant_directory(uuid,uuid)',
    'EXECUTE'
  ),
  'team_role_grant_directory execution privileges match the frozen contract'
);

-- 19
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.team_role_scope_catalogue(uuid)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.team_role_scope_catalogue(uuid)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'service_role',
    'public.team_role_scope_catalogue(uuid)',
    'EXECUTE'
  ),
  'team_role_scope_catalogue execution privileges match the frozen contract'
);

-- 20
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'team_role_grant_directory',
        'team_role_scope_catalogue'
      )
      AND p.prosecdef = true
      AND p.provolatile = 's'
  ),
  2::bigint,
  'both Slice 7D read RPCs remain STABLE SECURITY DEFINER functions'
);

-- 21
SELECT is(
  (
    SELECT array_agg(
      r.key
      ORDER BY r.sort_order, r.key
    )
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE p.key = 'team.role.assign'
  ),
  ARRAY['founder']::text[],
  'team.role.assign permission mapping remains Founder-only'
);


SELECT * FROM finish();

ROLLBACK;
