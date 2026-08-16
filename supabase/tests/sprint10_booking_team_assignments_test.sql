CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(75);

-- =====================================================================
-- Part 1 — Static schema / permission / security contract
-- =====================================================================

-- 1
SELECT ok(
  to_regclass(
    'public.booking_team_assignments'
  ) IS NOT NULL,
  'booking_team_assignments exists'
);

-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          to_regclass(
            'public.booking_team_assignments'
          )
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  ),
  11::bigint,
  'booking_team_assignments has exactly 11 current canonical columns'
);

-- 3
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          to_regclass(
            'public.booking_team_assignments'
          )
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
      AND attribute.attname = ANY (
        ARRAY[
          'id',
          'organization_id',
          'booking_id',
          'assignment_role',
          'assigned_member_id',
          'assigned_external_creative_id',
          'assigned_at',
          'assigned_by',
          'ended_at',
          'ended_by',
          'end_reason'
        ]::name[]
      )
  ),
  11::bigint,
  'booking_team_assignments exposes exactly the current canonical column names'
);

-- 4
SELECT ok(
  (
    SELECT table_row.relrowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          to_regclass(
            'public.booking_team_assignments'
          )
  ),
  'booking_team_assignments has RLS enabled'
);

-- 5
SELECT ok(
  (
    SELECT table_row.relforcerowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          to_regclass(
            'public.booking_team_assignments'
          )
  ),
  'booking_team_assignments has FORCE RLS enabled'
);

-- 6
SELECT ok(
  (
    SELECT count(*) = 1
    FROM pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename =
          'booking_team_assignments'
      AND policy.policyname =
          'booking_team_assignments_authenticated_select'
      AND policy.cmd = 'SELECT'
      AND policy.roles =
          ARRAY['authenticated']::name[]
  ),
  'booking-team evidence exposes exactly the authenticated SELECT policy'
);

-- 7
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_team_assignments',
    'SELECT'
  ),
  'authenticated receives booking-team SELECT'
);

-- 8
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_team_assignments',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_team_assignments',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_team_assignments',
    'DELETE'
  ),
  'authenticated receives no direct booking-team writes'
);

-- 9
SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.booking_team_assignments',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_team_assignments',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_team_assignments',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_team_assignments',
    'DELETE'
  ),
  'anon receives no booking-team table access'
);

-- 10
SELECT ok(
  has_table_privilege(
    'service_role',
    'public.booking_team_assignments',
    'SELECT'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_team_assignments',
    'INSERT'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_team_assignments',
    'UPDATE'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_team_assignments',
    'DELETE'
  ),
  'service_role retains trusted administrative table privileges'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          to_regclass(
            'public.booking_team_assignments'
          )
      AND trigger_row.tgname =
          'booking_team_assignments_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'booking-team lifecycle guard trigger exists exactly once'
);

-- 12
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_role_chk'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%lead_photographer%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%assistant%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%stylist%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%lead_videographer%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%supporting_videographer%'
  ),
  'assignment-role check contains the current five-role operational taxonomy'
);

-- 13
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_lifecycle_chk'
  ),
  'assignment lifecycle all-or-nothing check exists'
);

-- 14
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_end_time_chk'
  ),
  'assignment ending timestamp cannot precede assignment'
);

-- 15
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_booking_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (organization_id, booking_id) REFERENCES bookings(organization_id, id)%'
  ),
  'booking FK is tenant-safe'
);

-- 16
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_assigned_member_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (assigned_member_id, organization_id) REFERENCES organization_members(id, organization_id)%'
  ),
  'assigned-member FK is tenant-safe'
);

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname IN (
        'booking_team_assignments_assigned_by_fkey',
        'booking_team_assignments_ended_by_fkey'
      )
  ),
  2::bigint,
  'both assignment actor FKs exist'
);

-- 18
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_id_org_booking_key'
      AND constraint_row.contype = 'u'
  ),
  'assignment exposes tenant-and-booking-safe composite identity'
);

-- 19
SELECT ok(
  to_regclass(
    'public.booking_team_assignments_current_lead_uidx'
  ) IS NOT NULL,
  'partial singular-current-Lead index exists'
);

-- 20
SELECT ok(
  to_regclass(
    'public.booking_team_assignments_current_member_role_uidx'
  ) IS NOT NULL,
  'partial duplicate-current-member-role index exists'
);

-- 21
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key =
          'booking.team.assign'
      AND permission.domain =
          'bookings'
      AND permission.requires_server_enforcement
  ),
  'booking.team.assign exists with server enforcement'
);

-- 22
SELECT is(
  (
    SELECT array_agg(
             role.key
             ORDER BY role.key
           )
    FROM public.role_permissions mapping
    JOIN public.permissions permission
      ON permission.id =
         mapping.permission_id
    JOIN public.roles role
      ON role.id =
         mapping.role_id
    WHERE permission.key =
          'booking.team.assign'
  ),
  ARRAY[
    'client_coordinator',
    'founder',
    'studio_manager'
  ]::text[],
  'booking.team.assign is granted exactly to Founder, Studio Manager and Client Coordinator'
);

-- 23
SELECT ok(
  to_regprocedure(
    'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'
  ) IS NOT NULL,
  'assign_booking_team_member RPC exists'
);

-- 24
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc procedure
    JOIN pg_namespace namespace
      ON namespace.oid =
         procedure.pronamespace
    WHERE procedure.oid =
          'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'::regprocedure
      AND namespace.nspname =
          'public'
      AND procedure.prosecdef
      AND 'search_path=""' =
          ANY(
            COALESCE(
              procedure.proconfig,
              ARRAY[]::text[]
            )
          )
  ),
  'assignment RPC is SECURITY DEFINER with empty search_path'
);

-- 25
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.assign_booking_team_member(uuid,text,uuid,boolean,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.assign_booking_team_member(uuid,text,uuid,boolean,text)',
    'EXECUTE'
  ),
  'assignment RPC is authenticated-only'
);

-- 26
SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'public.lsh_booking_team_assignment_guard()',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.lsh_booking_team_assignment_guard()',
    'EXECUTE'
  )
  AND has_function_privilege(
    'service_role',
    'public.lsh_booking_team_assignment_guard()',
    'EXECUTE'
  ),
  'assignment guard is internal rather than a client RPC'
);

-- 27
SELECT is(
  pg_get_function_result(
    'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'::regprocedure
  ),
  'booking_team_assignments',
  'assignment RPC returns canonical booking-team evidence'
);

-- =====================================================================
-- Part 2 — Transaction-local identities and operational fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('89000000-0000-0000-0000-000000000001'),
  ('89000000-0000-0000-0000-000000000002'),
  ('89000000-0000-0000-0000-000000000003'),
  ('89000000-0000-0000-0000-000000000004'),
  ('89000000-0000-0000-0000-000000000005'),
  ('89000000-0000-0000-0000-000000000006'),
  ('89000000-0000-0000-0000-000000000007'),
  ('89000000-0000-0000-0000-000000000008'),
  ('89000000-0000-0000-0000-000000000009'),
  ('89000000-0000-0000-0000-000000000010'),
  ('89000000-0000-0000-0000-000000000011'),
  ('89000000-0000-0000-0000-000000000012'),
  ('89000000-0000-0000-0000-000000000013'),
  ('89000000-0000-0000-0000-000000000014'),
  ('89000000-0000-0000-0000-000000000015'),
  ('89000000-0000-0000-0000-000000000016'),
  ('89000000-0000-0000-0000-000000000017');

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '89000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000001',
  'active',
  'S10 Team Founder'
),
(
  '89000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000002',
  'active',
  'S10 Team Studio Manager'
),
(
  '89000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000003',
  'active',
  'S10 Team Client Coordinator'
),
(
  '89000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000004',
  'active',
  'S10 Photographer One'
),
(
  '89000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000005',
  'active',
  'S10 Photographer Two'
),
(
  '89000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000006',
  'active',
  'S10 Assistant One'
),
(
  '89000000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000007',
  'active',
  'S10 Assistant Two'
),
(
  '89000000-0000-0000-0000-000000000108',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000008',
  'active',
  'S10 Stylist One'
),
(
  '89000000-0000-0000-0000-000000000109',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000009',
  'active',
  'S10 Assistant Three'
),
(
  '89000000-0000-0000-0000-000000000110',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000010',
  'active',
  'S10 Stylist Two'
),
(
  '89000000-0000-0000-0000-000000000111',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000011',
  'active',
  'S10 Suspended Photographer'
),
(
  '89000000-0000-0000-0000-000000000112',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000012',
  'active',
  'S10 Revoked Photographer'
),
(
  '89000000-0000-0000-0000-000000000113',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000013',
  'active',
  'S10 Branch A Photographer'
),
(
  '89000000-0000-0000-0000-000000000114',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000014',
  'active',
  'S10 Branch B Photographer'
),
(
  '89000000-0000-0000-0000-000000000115',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000015',
  'active',
  'S10 Orgwide Branch Photographer'
),
(
  '89000000-0000-0000-0000-000000000116',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000016',
  'active',
  'S10 Branch Coordinator'
);

UPDATE public.organization_members
SET
  status =
    'suspended'::public.member_status,
  suspended_at =
    now(),
  suspended_by =
    '89000000-0000-0000-0000-000000000101'
WHERE id =
      '89000000-0000-0000-0000-000000000111';

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role.id,
  fixture.branch_id
FROM (
  VALUES
    ('89000000-0000-0000-0000-000000000101'::uuid, 'founder'::text, NULL::uuid),
    ('89000000-0000-0000-0000-000000000102'::uuid, 'studio_manager', NULL::uuid),
    ('89000000-0000-0000-0000-000000000103'::uuid, 'client_coordinator', NULL::uuid),
    ('89000000-0000-0000-0000-000000000104'::uuid, 'photographer', NULL::uuid),
    ('89000000-0000-0000-0000-000000000105'::uuid, 'photographer', NULL::uuid),
    ('89000000-0000-0000-0000-000000000106'::uuid, 'assistant', NULL::uuid),
    ('89000000-0000-0000-0000-000000000107'::uuid, 'assistant', NULL::uuid),
    ('89000000-0000-0000-0000-000000000108'::uuid, 'stylist', NULL::uuid),
    ('89000000-0000-0000-0000-000000000109'::uuid, 'assistant', NULL::uuid),
    ('89000000-0000-0000-0000-000000000110'::uuid, 'stylist', NULL::uuid),
    ('89000000-0000-0000-0000-000000000111'::uuid, 'photographer', NULL::uuid),
    ('89000000-0000-0000-0000-000000000112'::uuid, 'photographer', NULL::uuid)
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

UPDATE public.member_role_grants grant_row
SET
  revoked_at = now(),
  revoked_by =
    '89000000-0000-0000-0000-000000000101',
  revocation_reason =
    'Sprint 10 revoked-role eligibility fixture'
FROM public.roles role
WHERE grant_row.role_id =
      role.id
  AND grant_row.organization_member_id =
      '89000000-0000-0000-0000-000000000112'
  AND role.key =
      'photographer';

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc';

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  country_code,
  created_by,
  updated_by
)
VALUES
(
  '89000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 Team Branch A',
  's10a',
  'active',
  'IN',
  '89000000-0000-0000-0000-000000000101',
  '89000000-0000-0000-0000-000000000101'
),
(
  '89000000-0000-0000-0000-000000000202',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 Team Branch B',
  's10b',
  'active',
  'IN',
  '89000000-0000-0000-0000-000000000101',
  '89000000-0000-0000-0000-000000000101'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role.id,
  fixture.branch_id
FROM (
  VALUES
    (
      '89000000-0000-0000-0000-000000000113'::uuid,
      'photographer'::text,
      '89000000-0000-0000-0000-000000000201'::uuid
    ),
    (
      '89000000-0000-0000-0000-000000000114'::uuid,
      'photographer',
      '89000000-0000-0000-0000-000000000202'::uuid
    ),
    (
      '89000000-0000-0000-0000-000000000115'::uuid,
      'photographer',
      NULL::uuid
    ),
    (
      '89000000-0000-0000-0000-000000000116'::uuid,
      'client_coordinator',
      '89000000-0000-0000-0000-000000000201'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

INSERT INTO public.families (
  id,
  organization_id,
  branch_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES
(
  '89000000-0000-0000-0000-000000000401',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-45678A',
  'S10 Team Base Family',
  'Team Base Family',
  'active',
  '89000000-0000-0000-0000-000000000101',
  '89000000-0000-0000-0000-000000000101'
),
(
  '89000000-0000-0000-0000-000000000402',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000201',
  'QT-45678B',
  'S10 Team Branch Family',
  'Team Branch Family',
  'active',
  '89000000-0000-0000-0000-000000000101',
  '89000000-0000-0000-0000-000000000101'
);

CREATE TEMP TABLE s10t_quote_base AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000401',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10t_quote_base),
  (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'maternity_gold'
      AND version.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10t_quote_base),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10t_quote_base),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10t_booking_base AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10t_quote_base)
);

CREATE TEMP TABLE s10t_quote_branch AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '89000000-0000-0000-0000-000000000402',
  NULL,
  '89000000-0000-0000-0000-000000000201',
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10t_quote_branch),
  (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'maternity_gold'
      AND version.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10t_quote_branch),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10t_quote_branch),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10t_booking_branch AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10t_quote_branch)
);

GRANT SELECT
ON s10t_booking_base,
   s10t_booking_branch
TO authenticated, service_role;

-- =====================================================================
-- Part 3 — Wrong-stage denial, then Stage 8 behavior
-- =====================================================================

-- 28
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000104',
    true,
    NULL
  )
  $$,
  '22023',
  'assign_booking_team_member: booking must be within Booking Confirmed through Shoot Scheduled',
  'assignment is denied before Stage 8'
);

-- 29
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
  ),
  0::bigint,
  'wrong-stage denial creates no assignment evidence'
);

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_team_test_booking_confirmed',
  now(),
  '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

CREATE TEMP TABLE s10t_stage8_before AS
SELECT
  state.current_stage_id,
  state.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
  ) AS transition_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base);

-- 30
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_lead_first AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000104',
    true,
    NULL
  )
  $$,
  'Founder can assign the first Lead Photographer at Stage 8'
);

-- 31
SELECT ok(
  (
    SELECT
      assignment.assignment_role =
        'lead_photographer'
      AND assignment.assigned_member_id =
          '89000000-0000-0000-0000-000000000104'
      AND assignment.assigned_by =
          '89000000-0000-0000-0000-000000000101'
      AND assignment.ended_at IS NULL
      AND assignment.ended_by IS NULL
      AND assignment.end_reason IS NULL
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10t_lead_first)
  ),
  'first Lead assignment records exact active canonical evidence'
);

-- 32
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'lead_photographer'
      AND assignment.ended_at IS NULL
  ),
  1::bigint,
  'exactly one current Lead Photographer exists'
);

-- 33
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_assigned'
      AND audit.entity_id =
          (SELECT id FROM s10t_lead_first)
  ),
  1::bigint,
  'first Lead assignment creates exactly one assignment audit event'
);

-- 34
SELECT ok(
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
          before.version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
              state.booking_id
      ) =
      before.transition_count
    FROM public.booking_journey_states state
    CROSS JOIN s10t_stage8_before before
    WHERE state.booking_id =
          (SELECT id FROM s10t_booking_base)
  ),
  'team assignment does not move the booking journey'
);

CREATE TEMP TABLE s10t_lead_replay AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10t_booking_base),
  'lead_photographer',
  '89000000-0000-0000-0000-000000000104',
  true,
  NULL
);

-- 35
SELECT is(
  (SELECT id FROM s10t_lead_replay),
  (SELECT id FROM s10t_lead_first),
  'exact Lead assignment replay returns the same evidence'
);

-- 36
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'lead_photographer'
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_assigned'
      AND audit.entity_id =
          (SELECT id FROM s10t_lead_first)
  ) = 1,
  'exact Lead replay creates no duplicate assignment or audit evidence'
);

-- 37
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000105',
    true,
    NULL
  )
  $$,
  '22023',
  'assign_booking_team_member: Lead Photographer replacement requires a change reason',
  'Lead Photographer replacement requires a nonblank reason'
);

-- 38
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_lead_second AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000105',
    true,
    'Primary photographer changed'
  )
  $$,
  'Founder can replace the Lead Photographer with a reason'
);

-- 39
SELECT ok(
  (
    SELECT
      old_assignment.ended_at IS NOT NULL
      AND old_assignment.ended_by =
          '89000000-0000-0000-0000-000000000101'
      AND old_assignment.end_reason =
          'Primary photographer changed'
    FROM public.booking_team_assignments old_assignment
    WHERE old_assignment.id =
          (SELECT id FROM s10t_lead_first)
  )
  AND
  (
    SELECT
      new_assignment.ended_at IS NULL
      AND new_assignment.assigned_member_id =
          '89000000-0000-0000-0000-000000000105'
    FROM public.booking_team_assignments new_assignment
    WHERE new_assignment.id =
          (SELECT id FROM s10t_lead_second)
  ),
  'Lead replacement closes old evidence and creates the new active Lead atomically'
);

-- 40
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'lead_photographer'
  ) = 2
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'lead_photographer'
      AND assignment.ended_at IS NULL
  ) = 1,
  'Lead history is preserved while current Lead remains singular'
);

-- 41
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_replaced'
      AND audit.entity_id =
          (SELECT id FROM s10t_lead_second)
  ),
  1::bigint,
  'Lead replacement emits exactly one replacement audit event'
);

CREATE FUNCTION public.s10t_fail_team_replacement_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.assigned_member_id =
       '89000000-0000-0000-0000-000000000104'::uuid THEN
    RAISE EXCEPTION
      's10 forced Lead replacement insertion failure';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER zz_s10t_fail_team_replacement_insert
BEFORE INSERT
ON public.booking_team_assignments
FOR EACH ROW
EXECUTE FUNCTION public.s10t_fail_team_replacement_insert();

-- 42
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000104',
    true,
    'Forced rollback probe'
  )
  $$,
  'P0001',
  's10 forced Lead replacement insertion failure',
  'failed replacement insertion aborts the replacement statement'
);

DROP TRIGGER zz_s10t_fail_team_replacement_insert
ON public.booking_team_assignments;

DROP FUNCTION public.s10t_fail_team_replacement_insert();

-- 43
SELECT ok(
  (
    SELECT
      assignment.assigned_member_id =
        '89000000-0000-0000-0000-000000000105'
      AND assignment.ended_at IS NULL
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'lead_photographer'
      AND assignment.ended_at IS NULL
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'lead_photographer'
  ) = 2
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_replaced'
      AND audit.metadata->>'booking_id' =
          (SELECT id::text FROM s10t_booking_base)
  ) = 1,
  'failed Lead replacement rolls back closure, insertion and audit atomically'
);

-- 44
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000111',
    true,
    'Suspended member probe'
  )
  $$,
  '22023',
  'assign_booking_team_member: target organization member must be active',
  'suspended member cannot receive a booking assignment'
);

-- 45
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000112',
    true,
    'Revoked role probe'
  )
  $$,
  '22023',
  'assign_booking_team_member: target member lacks qualifying operational role for booking scope',
  'revoked operational role cannot satisfy assignment eligibility'
);

-- 46
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000113',
    true,
    'Branch-only member on branchless booking'
  )
  $$,
  '22023',
  'assign_booking_team_member: target member lacks qualifying operational role for booking scope',
  'branchless booking requires an organization-wide qualifying role'
);

-- 47
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_assistant_one AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'assistant',
    '89000000-0000-0000-0000-000000000106',
    true,
    NULL
  )
  $$,
  'first Assistant may be assigned'
);

-- 48
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_assistant_two AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'assistant',
    '89000000-0000-0000-0000-000000000107',
    true,
    NULL
  )
  $$,
  'second distinct Assistant may be assigned'
);

-- 49
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'assistant'
      AND assignment.ended_at IS NULL
  ),
  2::bigint,
  'multiple distinct current Assistants are permitted'
);

-- 50
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_stylist_one AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'stylist',
    '89000000-0000-0000-0000-000000000108',
    true,
    NULL
  )
  $$,
  'Stylist eligibility mapping succeeds'
);

-- 51
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'stylist'
      AND assignment.ended_at IS NULL
  ),
  1::bigint,
  'current Stylist evidence is canonical'
);

-- 52
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'assistant',
    '89000000-0000-0000-0000-000000000106',
    false,
    NULL
  )
  $$,
  '22023',
  'assign_booking_team_member: unassignment requires a change reason',
  'unassignment requires a nonblank reason'
);

-- Revoke Assistant One's operational role after assignment.
UPDATE public.member_role_grants grant_row
SET
  revoked_at = now(),
  revoked_by =
    '89000000-0000-0000-0000-000000000101',
  revocation_reason =
    'Role lost after booking assignment'
FROM public.roles role
WHERE grant_row.role_id =
      role.id
  AND grant_row.organization_member_id =
      '89000000-0000-0000-0000-000000000106'
  AND grant_row.revoked_at IS NULL
  AND role.key =
      'assistant';

-- 53
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_assistant_one_removed AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'assistant',
    '89000000-0000-0000-0000-000000000106',
    false,
    'Assistant no longer required'
  )
  $$,
  'previous assignment remains removable after operational role revocation'
);

-- 54
SELECT ok(
  (
    SELECT
      assignment.ended_at IS NOT NULL
      AND assignment.end_reason =
          'Assistant no longer required'
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10t_assistant_one)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'assistant'
      AND assignment.ended_at IS NULL
  ) = 1,
  'unassignment closes exact historical evidence without deleting other Assistants'
);

CREATE TEMP TABLE s10t_assistant_one_remove_replay AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10t_booking_base),
  'assistant',
  '89000000-0000-0000-0000-000000000106',
  false,
  'Assistant no longer required'
);

-- 55
SELECT is(
  (SELECT id FROM s10t_assistant_one_remove_replay),
  (SELECT id FROM s10t_assistant_one_removed),
  'successful unassignment replay returns the latest closed matching evidence'
);

-- 56
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'assistant'
      AND assignment.assigned_member_id =
          '89000000-0000-0000-0000-000000000106'
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_unassigned'
      AND audit.entity_id =
          (SELECT id FROM s10t_assistant_one_removed)
  ) = 1,
  'unassignment replay creates no duplicate history or audit event'
);

UPDATE public.organization_members
SET
  status =
    'suspended'::public.member_status,
  suspended_at =
    now(),
  suspended_by =
    '89000000-0000-0000-0000-000000000101'
WHERE id =
      '89000000-0000-0000-0000-000000000107';

-- 57
SELECT lives_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'assistant',
    '89000000-0000-0000-0000-000000000107',
    false,
    'Suspended assistant removed'
  )
  $$,
  'previous assignment remains removable after member suspension'
);

-- 58
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
      AND assignment.assignment_role =
          'assistant'
      AND assignment.ended_at IS NULL
  ),
  0::bigint,
  'both ended Assistant assignments remain historical and no Assistant is current'
);

-- 59
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'assistant',
    '89000000-0000-0000-0000-000000000104',
    false,
    'Never held role probe'
  )
  $$,
  '22023',
  'assign_booking_team_member: member has never held this booking assignment role',
  'unassigning a member who never held the role fails closed'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000004',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

-- 60
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000104',
    true,
    'Self-assignment probe'
  )
  $$,
  '42501',
  'assign_booking_team_member: booking.team.assign permission required',
  'Photographer cannot self-assign without booking.team.assign'
);

-- =====================================================================
-- Part 4 — Stage 9 Studio Manager and Stage 10 Client Coordinator
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_team_test_preparation',
  now(),
  '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'pre_shoot_preparation'
 AND target.stage_order = 9
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'pre_shoot_preparation'
  AND target.stage_order = 9
  AND target.is_active;

CREATE TEMP TABLE s10t_stage9_before AS
SELECT
  state.current_stage_id,
  state.version
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base);

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 61
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_stage9_manager_assignment AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'assistant',
    '89000000-0000-0000-0000-000000000109',
    true,
    NULL
  )
  $$,
  'Studio Manager may assign an eligible team member at Stage 9'
);

-- 62
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10t_stage9_manager_assignment)
      AND assignment.assigned_by =
          '89000000-0000-0000-0000-000000000102'
      AND assignment.ended_at IS NULL
  )
  AND
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
          before.version
    FROM public.booking_journey_states state
    CROSS JOIN s10t_stage9_before before
    WHERE state.booking_id =
          (SELECT id FROM s10t_booking_base)
  ),
  'Stage 9 Studio Manager assignment records actor and leaves journey unchanged'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_team_test_shoot_scheduled',
  now(),
  '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'shoot_scheduled'
 AND target.stage_order = 10
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'shoot_scheduled'
  AND target.stage_order = 10
  AND target.is_active;

CREATE TEMP TABLE s10t_stage10_before AS
SELECT
  state.current_stage_id,
  state.version
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_base);

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

-- 63
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_stage10_coordinator_assignment AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'stylist',
    '89000000-0000-0000-0000-000000000110',
    true,
    NULL
  )
  $$,
  'Client Coordinator may assign an eligible team member at Stage 10'
);

-- 64
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10t_stage10_coordinator_assignment)
      AND assignment.assigned_by =
          '89000000-0000-0000-0000-000000000103'
      AND assignment.ended_at IS NULL
  )
  AND
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
          before.version
    FROM public.booking_journey_states state
    CROSS JOIN s10t_stage10_before before
    WHERE state.booking_id =
          (SELECT id FROM s10t_booking_base)
  ),
  'Stage 10 Client Coordinator assignment records actor and leaves journey unchanged'
);

-- =====================================================================
-- Part 5 — Branch eligibility and branch-derived RLS
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_team_test_branch_booking_confirmed',
  now(),
  '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_branch);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '89000000-0000-0000-0000-000000000101'
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10t_booking_branch)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

-- 65
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_branch_orgwide_lead AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_branch),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000115',
    true,
    NULL
  )
  $$,
  'organization-wide Photographer qualifies for a branch-scoped booking'
);

-- 66
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10t_branch_local_lead AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_branch),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000113',
    true,
    'Assign branch-local Lead'
  )
  $$,
  'same-branch Photographer qualifies for a branch-scoped booking'
);

-- 67
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_branch),
    'lead_photographer',
    '89000000-0000-0000-0000-000000000114',
    true,
    'Wrong branch probe'
  )
  $$,
  '22023',
  'assign_booking_team_member: target member lacks qualifying operational role for booking scope',
  'different-branch Photographer cannot satisfy branch booking eligibility'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000016',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000016","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 68
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_base)
  ) = 0
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10t_booking_branch)
  ) > 0,
  'branch-scoped Coordinator sees branch staffing but not NULL-branch staffing'
);

RESET ROLE;

-- =====================================================================
-- Part 6 — Cross-organization isolation
-- =====================================================================

INSERT INTO public.organizations (
  id,
  display_name,
  slug,
  status,
  currency_code,
  timezone,
  brand_prefix
)
VALUES (
  '89000000-0000-0000-0000-000000000301',
  'S10 Foreign Team Studio',
  's10-foreign-team-studio',
  'suspended',
  'INR',
  'Asia/Kolkata',
  'S10F'
);

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '89000000-0000-0000-0000-000000000301'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '89000000-0000-0000-0000-000000000117',
  '89000000-0000-0000-0000-000000000301',
  '89000000-0000-0000-0000-000000000017',
  'active',
  'S10 Foreign Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '89000000-0000-0000-0000-000000000301',
  '89000000-0000-0000-0000-000000000117',
  role.id,
  NULL
FROM public.roles role
WHERE role.key =
      'founder';

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '89000000-0000-0000-0000-000000000301';

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000017',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000017","role":"authenticated"}',
  true
);

-- 69
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10t_booking_base),
    'stylist',
    '89000000-0000-0000-0000-000000000110',
    true,
    NULL
  )
  $$,
  '42501',
  'assign_booking_team_member: active organization membership required',
  'foreign-organization Founder cannot mutate canonical organization staffing'
);

SET LOCAL ROLE authenticated;

-- 70
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
  ),
  0::bigint,
  'foreign-organization Founder cannot read canonical organization staffing'
);

RESET ROLE;

-- =====================================================================
-- Part 7 — Direct DML denial and lifecycle guard defense in depth
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '89000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"89000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 71
SELECT throws_ok(
  $$
  INSERT INTO public.booking_team_assignments (
    organization_id,
    booking_id,
    assignment_role,
    assigned_member_id,
    assigned_by
  )
  SELECT
    booking.organization_id,
    booking.id,
    'assistant',
    '89000000-0000-0000-0000-000000000106',
    '89000000-0000-0000-0000-000000000101'
  FROM s10t_booking_base booking
  $$,
  '42501',
  'permission denied for table booking_team_assignments',
  'authenticated direct INSERT is denied'
);

-- 72
SELECT throws_ok(
  $$
  UPDATE public.booking_team_assignments
  SET end_reason =
      'direct update probe'
  WHERE booking_id =
        (SELECT id FROM s10t_booking_base)
  $$,
  '42501',
  'permission denied for table booking_team_assignments',
  'authenticated direct UPDATE is denied'
);

-- 73
SELECT throws_ok(
  $$
  DELETE FROM public.booking_team_assignments
  WHERE booking_id =
        (SELECT id FROM s10t_booking_base)
  $$,
  '42501',
  'permission denied for table booking_team_assignments',
  'authenticated direct DELETE is denied'
);

RESET ROLE;

SET LOCAL ROLE service_role;

-- 74
SELECT throws_ok(
  $$
  UPDATE public.booking_team_assignments
  SET assigned_member_id =
      '89000000-0000-0000-0000-000000000104'
  WHERE booking_id =
        (SELECT id FROM s10t_booking_base)
    AND assignment_role =
        'lead_photographer'
    AND ended_at IS NULL
  $$,
  'P0001',
  'booking team assignment identity and original assignment evidence are immutable',
  'trusted direct UPDATE still cannot rewrite historical assignment identity'
);

-- 75
SELECT throws_ok(
  $$
  DELETE FROM public.booking_team_assignments
  WHERE booking_id =
        (SELECT id FROM s10t_booking_base)
    AND assignment_role =
        'lead_photographer'
    AND ended_at IS NULL
  $$,
  'P0001',
  'booking team assignment evidence cannot be deleted',
  'trusted direct DELETE is blocked by lifecycle guard'
);

RESET ROLE;

SELECT * FROM finish();

ROLLBACK;
