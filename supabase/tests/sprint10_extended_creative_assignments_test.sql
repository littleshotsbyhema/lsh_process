CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(85);

-- =====================================================================
-- Part 1 — External creative identity contract
-- =====================================================================

-- 1
SELECT ok(
  to_regclass('public.external_creatives') IS NOT NULL,
  'external_creatives exists'
);

-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.external_creatives'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  ),
  5::bigint,
  'external_creatives has exactly 5 canonical columns'
);

-- 3
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.external_creatives'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
      AND attribute.attname = ANY (
        ARRAY[
          'id',
          'organization_id',
          'display_name',
          'created_at',
          'created_by'
        ]::name[]
      )
  ),
  5::bigint,
  'external_creatives exposes exactly the frozen identity surface'
);

-- 4
SELECT ok(
  (
    SELECT
      table_row.relrowsecurity
      AND table_row.relforcerowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          'public.external_creatives'::regclass
  ),
  'external_creatives uses RLS and FORCE RLS'
);

-- 5
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename = 'external_creatives'
  ),
  0::bigint,
  'external_creatives exposes no direct authenticated read policy'
);

-- 6
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.external_creatives',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.external_creatives',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.external_creatives',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.external_creatives',
    'DELETE'
  ),
  'authenticated receives no direct external-creative table access'
);

-- 7
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.external_creatives'::regclass
      AND trigger_row.tgname =
          'external_creatives_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'external creative immutable guard trigger exists once'
);

-- 8
SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'public.lsh_external_creative_guard()',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.lsh_external_creative_guard()',
    'EXECUTE'
  )
  AND has_function_privilege(
    'service_role',
    'public.lsh_external_creative_guard()',
    'EXECUTE'
  ),
  'external creative guard remains internal'
);

-- =====================================================================
-- Part 2 — External creative RPC security
-- =====================================================================

-- 9
SELECT ok(
  to_regprocedure(
    'public.create_external_creative(uuid,text)'
  ) IS NOT NULL,
  'create_external_creative exists'
);

-- 10
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.create_external_creative(uuid,text)'::regprocedure
      AND procedure.prosecdef
      AND 'search_path=""' =
          ANY(
            COALESCE(
              procedure.proconfig,
              ARRAY[]::text[]
            )
          )
  ),
  'create_external_creative is SECURITY DEFINER with empty search_path'
);

-- 11
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.create_external_creative(uuid,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.create_external_creative(uuid,text)',
    'EXECUTE'
  ),
  'create_external_creative is authenticated-only'
);

-- 12
SELECT is(
  pg_get_function_result(
    'public.create_external_creative(uuid,text)'::regprocedure
  ),
  'external_creatives',
  'create_external_creative returns canonical external identity'
);

-- 13
SELECT ok(
  to_regprocedure(
    'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'
  ) IS NOT NULL,
  'assign_booking_external_creative exists'
);

-- 14
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'::regprocedure
      AND procedure.prosecdef
      AND 'search_path=""' =
          ANY(
            COALESCE(
              procedure.proconfig,
              ARRAY[]::text[]
            )
          )
  ),
  'external assignment RPC is SECURITY DEFINER with empty search_path'
);

-- 15
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)',
    'EXECUTE'
  ),
  'external assignment RPC is authenticated-only'
);

-- 16
SELECT is(
  pg_get_function_result(
    'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'::regprocedure
  ),
  'booking_team_assignments',
  'external assignment RPC returns canonical booking-team evidence'
);

-- =====================================================================
-- Part 3 — Videographer role contract
-- =====================================================================

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.roles role
    WHERE role.key = 'videographer'
  ),
  1::bigint,
  'videographer role exists exactly once'
);

-- 18
SELECT is(
  (
    SELECT array_agg(
             permission.key
             ORDER BY permission.key
           )
    FROM public.role_permissions mapping
    JOIN public.roles role
      ON role.id = mapping.role_id
    JOIN public.permissions permission
      ON permission.id = mapping.permission_id
    WHERE role.key = 'videographer'
  ),
  ARRAY[
    'booking.read',
    'org.read'
  ]::text[],
  'videographer receives exactly booking.read and org.read'
);

-- 19
SELECT is(
  (SELECT count(*)::bigint FROM public.roles),
  13::bigint,
  'Slice 6A canonical role count is 13'
);

-- 20
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  260::bigint,
  'current canonical role-permission mapping count is 260'
);

-- =====================================================================
-- Part 4 — Extended booking-team structural contract
-- =====================================================================

-- 21
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.booking_team_assignments'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  ),
  11::bigint,
  'booking_team_assignments has 11 current canonical columns'
);

-- 22
SELECT ok(
  EXISTS (
    SELECT 1
    FROM information_schema.columns column_row
    WHERE column_row.table_schema = 'public'
      AND column_row.table_name =
          'booking_team_assignments'
      AND column_row.column_name =
          'assigned_member_id'
      AND column_row.is_nullable = 'YES'
  ),
  'assigned_member_id is nullable for internal-or-external subject XOR'
);

-- 23
SELECT ok(
  EXISTS (
    SELECT 1
    FROM information_schema.columns column_row
    WHERE column_row.table_schema = 'public'
      AND column_row.table_name =
          'booking_team_assignments'
      AND column_row.column_name =
          'assigned_external_creative_id'
      AND column_row.data_type = 'uuid'
      AND column_row.is_nullable = 'YES'
  ),
  'assigned_external_creative_id exists as nullable uuid'
);

-- 24
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_assigned_external_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (assigned_external_creative_id, organization_id) REFERENCES external_creatives(id, organization_id)%'
  ),
  'external creative assignment FK is tenant-safe'
);

-- 25
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_subject_xor_chk'
  ),
  'booking assignment subject XOR constraint exists'
);

-- 26
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_role_chk'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%lead_photographer%'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%assistant%'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%stylist%'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%lead_videographer%'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%supporting_videographer%'
  ),
  'booking assignment taxonomy contains all five frozen roles'
);

-- 27
SELECT ok(
  to_regclass(
    'public.booking_team_assignments_current_lead_videographer_uidx'
  ) IS NOT NULL,
  'singular current Lead Videographer index exists'
);

-- 28
SELECT ok(
  to_regclass(
    'public.booking_team_assignments_current_external_role_uidx'
  ) IS NOT NULL,
  'duplicate current external subject-role index exists'
);

-- =====================================================================
-- Part 5 — Structured commercial operational requirements
-- =====================================================================

-- 29
SELECT ok(
  to_regclass(
    'public.commercial_operational_requirements'
  ) IS NOT NULL,
  'commercial_operational_requirements exists'
);

-- 30
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.commercial_operational_requirements'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  ),
  6::bigint,
  'commercial operational requirements has exactly 6 columns'
);

-- 31
SELECT ok(
  (
    SELECT
      table_row.relrowsecurity
      AND table_row.relforcerowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          'public.commercial_operational_requirements'::regclass
  ),
  'commercial operational requirements uses RLS and FORCE RLS'
);

-- 32
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.commercial_operational_requirements',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.commercial_operational_requirements',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.commercial_operational_requirements',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.commercial_operational_requirements',
    'DELETE'
  ),
  'commercial requirements are authenticated SELECT-only'
);

-- 33
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.commercial_operational_requirements'::regclass
      AND constraint_row.conname =
          'commercial_operational_requirements_source_xor_chk'
  ),
  'commercial requirement source XOR constraint exists'
);

-- 34
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.commercial_operational_requirements'::regclass
      AND constraint_row.conname =
          'commercial_operational_requirements_key_chk'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%lead_videographer%'
  ),
  'commercial requirement key is controlled to lead_videographer'
);

-- 35
SELECT ok(
  to_regclass(
    'public.commercial_operational_requirements_package_uidx'
  ) IS NOT NULL,
  'package-version operational requirement uniqueness exists'
);

-- 36
SELECT ok(
  to_regclass(
    'public.commercial_operational_requirements_addon_uidx'
  ) IS NOT NULL,
  'add-on-version operational requirement uniqueness exists'
);

-- 37
SELECT ok(
  (
    SELECT count(*) = 1
    FROM pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.commercial_operational_requirements'::regclass
      AND trigger_row.tgname =
          'commercial_operational_requirements_guard'
      AND NOT trigger_row.tgisinternal
  )
  AND NOT has_function_privilege(
    'authenticated',
    'public.lsh_commercial_operational_requirement_guard()',
    'EXECUTE'
  )
  AND has_function_privilege(
    'service_role',
    'public.lsh_commercial_operational_requirement_guard()',
    'EXECUTE'
  ),
  'commercial requirement immutable guard is present and internal'
);

-- 38
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_operational_requirements requirement
    WHERE requirement.requirement_key =
          'lead_videographer'
  ),
  6::bigint,
  'exactly six initial Lead Videographer requirements exist'
);

-- 39
SELECT is(
  (
    SELECT array_agg(
             package.package_key
             ORDER BY package.package_key
           )
    FROM public.commercial_operational_requirements requirement
    JOIN public.commercial_package_versions version
      ON version.organization_id =
         requirement.organization_id
     AND version.id =
         requirement.package_version_id
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE requirement.requirement_key =
          'lead_videographer'
      AND requirement.package_version_id IS NOT NULL
  ),
  ARRAY[
    'maternity_diamond',
    'maternity_emerald',
    'newborn_emerald',
    'sitter_diamond',
    'sitter_emerald'
  ]::text[],
  'exact five version-1 packages require Lead Videographer'
);

-- 40
SELECT is(
  (
    SELECT addon.addon_key
    FROM public.commercial_operational_requirements requirement
    JOIN public.commercial_addon_versions version
      ON version.organization_id =
         requirement.organization_id
     AND version.id =
         requirement.addon_version_id
    JOIN public.commercial_addons addon
      ON addon.organization_id =
         version.organization_id
     AND addon.id =
         version.addon_id
    WHERE requirement.requirement_key =
          'lead_videographer'
      AND requirement.addon_version_id IS NOT NULL
  ),
  'cinematic_reel'::text,
  'cinematic_reel version 1 carries the Lead Videographer requirement'
);


-- =====================================================================
-- Part 6 — Core Slice 6A runtime fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8a000000-0000-0000-0000-000000000001'::uuid),
  ('8a000000-0000-0000-0000-000000000002'::uuid),
  ('8a000000-0000-0000-0000-000000000003'::uuid),
  ('8a000000-0000-0000-0000-000000000004'::uuid),
  ('8a000000-0000-0000-0000-000000000005'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '8a000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000001',
  'active',
  'S10 Slice 6A Founder'
),
(
  '8a000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000002',
  'active',
  'S10 Slice 6A Videographer One'
),
(
  '8a000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000003',
  'active',
  'S10 Slice 6A Videographer Two'
),
(
  '8a000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000004',
  'active',
  'S10 Slice 6A Photographer'
),
(
  '8a000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000005',
  'active',
  'S10 Slice 6A Non Videographer'
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
      '8a000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8a000000-0000-0000-0000-000000000102'::uuid,
      'videographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '8a000000-0000-0000-0000-000000000103'::uuid,
      'videographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '8a000000-0000-0000-0000-000000000104'::uuid,
      'photographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '8a000000-0000-0000-0000-000000000105'::uuid,
      'photographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

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
VALUES (
  '8a000000-0000-0000-0000-000000000401',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  'QZ-6789AB',
  'S10 Slice 6A Runtime Family',
  'Slice 6A Runtime Family',
  'active',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
);

CREATE TEMP TABLE s10_6a_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000401',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10_6a_quote),
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
  (SELECT id FROM s10_6a_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10_6a_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10_6a_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10_6a_quote)
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
  's10_slice6a_booking_confirmed',
  now(),
  '8a000000-0000-0000-0000-000000000101'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10_6a_booking);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '8a000000-0000-0000-0000-000000000101'
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10_6a_booking)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

CREATE TEMP TABLE s10_6a_stage_before AS
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
      (SELECT id FROM s10_6a_booking);

CREATE TEMP TABLE s10_6a_member_count_before AS
SELECT count(*)::bigint AS member_count
FROM public.organization_members
WHERE organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc';

CREATE TEMP TABLE s10_6a_external_one AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10_6a_booking),
  '  Alex Creative  '
);

CREATE TEMP TABLE s10_6a_external_two AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10_6a_booking),
  'Alex Creative'
);

-- 41
SELECT is(
  (SELECT display_name FROM s10_6a_external_one),
  'Alex Creative'::text,
  'external creative creation canonicalizes surrounding display-name whitespace'
);

-- 42
SELECT isnt(
  (SELECT id FROM s10_6a_external_one),
  (SELECT id FROM s10_6a_external_two),
  'duplicate external display names remain distinct stable UUID identities'
);

-- 43
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.organization_members
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
  ),
  (SELECT member_count FROM s10_6a_member_count_before),
  'external creative creation creates no organization membership'
);

-- 44
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.external_creative_registered'
      AND audit.entity_id IN (
        (SELECT id FROM s10_6a_external_one),
        (SELECT id FROM s10_6a_external_two)
      )
  ) = 2
  AND NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.external_creative_registered'
      AND audit.entity_id IN (
        (SELECT id FROM s10_6a_external_one),
        (SELECT id FROM s10_6a_external_two)
      )
      AND concat_ws(
            ' ',
            audit.old_values::text,
            audit.new_values::text,
            audit.metadata::text
          ) ILIKE '%Alex Creative%'
  ),
  'external registration audit is structural and does not copy display names'
);

-- =====================================================================
-- Part 7 — Internal Videographer assignment behavior
-- =====================================================================

-- 45
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_internal_lead_video AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10_6a_booking),
    'lead_videographer',
    '8a000000-0000-0000-0000-000000000102',
    true,
    NULL
  )
  $$,
  'internal member with Videographer role may become Lead Videographer'
);

-- 46
SELECT ok(
  (
    SELECT
      assignment.assignment_role =
        'lead_videographer'
      AND assignment.assigned_member_id =
          '8a000000-0000-0000-0000-000000000102'
      AND assignment.assigned_external_creative_id IS NULL
      AND assignment.ended_at IS NULL
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10_6a_internal_lead_video)
  ),
  'internal Lead Videographer records canonical member-subject evidence'
);

CREATE TEMP TABLE s10_6a_internal_lead_video_replay AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10_6a_booking),
  'lead_videographer',
  '8a000000-0000-0000-0000-000000000102',
  true,
  NULL
);

-- 47
SELECT is(
  (SELECT id FROM s10_6a_internal_lead_video_replay),
  (SELECT id FROM s10_6a_internal_lead_video),
  'exact internal Lead Videographer replay returns the same evidence'
);

-- 48
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10_6a_booking)
      AND assignment.assignment_role =
          'lead_videographer'
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_assigned'
      AND audit.entity_id =
          (SELECT id FROM s10_6a_internal_lead_video)
  ) = 1,
  'internal Lead Videographer replay creates no duplicate assignment or audit evidence'
);

-- 49
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_internal_support_video_one AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    '8a000000-0000-0000-0000-000000000102',
    true,
    NULL
  )
  $$,
  'Videographer may also hold Supporting Videographer assignment'
);

-- 50
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_internal_support_video_two AS
  SELECT *
  FROM public.assign_booking_team_member(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    '8a000000-0000-0000-0000-000000000103',
    true,
    NULL
  )
  $$,
  'multiple distinct internal Supporting Videographers are permitted'
);

-- 51
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10_6a_booking),
    'lead_videographer',
    '8a000000-0000-0000-0000-000000000105',
    true,
    'Non-videographer eligibility probe'
  )
  $$,
  '22023',
  'assign_booking_team_member: target member lacks qualifying operational role for booking scope',
  'internal Photographer without Videographer role cannot satisfy Videographer assignment'
);

-- =====================================================================
-- Part 8 — Cross-subject Lead Videographer replacement
-- =====================================================================

-- 52
SELECT throws_ok(
  $$
  SELECT public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'lead_videographer',
    (SELECT id FROM s10_6a_external_one),
    true,
    NULL
  )
  $$,
  '22023',
  'assign_booking_external_creative: Lead Videographer replacement requires a change reason',
  'cross-subject Lead Videographer replacement requires a reason'
);

-- 53
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_external_lead_video AS
  SELECT *
  FROM public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'lead_videographer',
    (SELECT id FROM s10_6a_external_one),
    true,
    'Client video crew changed'
  )
  $$,
  'external creative may replace an internal Lead Videographer atomically'
);

-- 54
SELECT ok(
  (
    SELECT assignment.ended_at IS NOT NULL
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10_6a_internal_lead_video)
  )
  AND
  (
    SELECT
      assignment.assigned_member_id IS NULL
      AND assignment.assigned_external_creative_id =
          (SELECT id FROM s10_6a_external_one)
      AND assignment.ended_at IS NULL
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10_6a_external_lead_video)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10_6a_booking)
      AND assignment.assignment_role =
          'lead_videographer'
      AND assignment.ended_at IS NULL
  ) = 1,
  'cross-subject Lead replacement preserves history and one current Lead'
);

-- 55
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_replaced'
      AND audit.entity_id =
          (SELECT id FROM s10_6a_external_lead_video)
      AND audit.old_values->>'subject_type' =
          'member'
      AND audit.new_values->>'subject_type' =
          'external'
      AND audit.new_values->>'assigned_external_creative_id' =
          (SELECT id::text FROM s10_6a_external_one)
      AND concat_ws(
            ' ',
            audit.old_values::text,
            audit.new_values::text,
            audit.metadata::text
          ) NOT ILIKE '%Alex Creative%'
  ),
  'cross-subject replacement audit records structural identity without freelancer display name'
);

CREATE TEMP TABLE s10_6a_external_lead_video_replay AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10_6a_booking),
  'lead_videographer',
  (SELECT id FROM s10_6a_external_one),
  true,
  NULL
);

-- 56
SELECT is(
  (SELECT id FROM s10_6a_external_lead_video_replay),
  (SELECT id FROM s10_6a_external_lead_video),
  'exact external Lead Videographer replay returns existing evidence'
);

-- =====================================================================
-- Part 9 — External Supporting Videographer lifecycle
-- =====================================================================

-- 57
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_external_support_one AS
  SELECT *
  FROM public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    (SELECT id FROM s10_6a_external_one),
    true,
    NULL
  )
  $$,
  'external Supporting Videographer assignment succeeds'
);

CREATE TEMP TABLE s10_6a_external_support_one_replay AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10_6a_booking),
  'supporting_videographer',
  (SELECT id FROM s10_6a_external_one),
  true,
  NULL
);

-- 58
SELECT is(
  (SELECT id FROM s10_6a_external_support_one_replay),
  (SELECT id FROM s10_6a_external_support_one),
  'external Supporting Videographer exact replay is idempotent'
);

-- 59
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_external_support_two AS
  SELECT *
  FROM public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    (SELECT id FROM s10_6a_external_two),
    true,
    NULL
  )
  $$,
  'same-name distinct external UUID may receive its own Supporting assignment'
);

-- 60
SELECT throws_ok(
  $$
  SELECT public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    (SELECT id FROM s10_6a_external_one),
    false,
    NULL
  )
  $$,
  '22023',
  'assign_booking_external_creative: unassignment requires a change reason',
  'external assignment removal requires a nonblank reason'
);

-- 61
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_external_support_removed AS
  SELECT *
  FROM public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    (SELECT id FROM s10_6a_external_one),
    false,
    'Supporting video coverage no longer required'
  )
  $$,
  'external Supporting Videographer can be unassigned with lifecycle evidence'
);

CREATE TEMP TABLE s10_6a_external_support_remove_replay AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10_6a_booking),
  'supporting_videographer',
  (SELECT id FROM s10_6a_external_one),
  false,
  'Supporting video coverage no longer required'
);

-- 62
SELECT ok(
  (SELECT id FROM s10_6a_external_support_remove_replay) =
    (SELECT id FROM s10_6a_external_support_removed)
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_unassigned'
      AND audit.entity_id =
          (SELECT id FROM s10_6a_external_support_removed)
  ) = 1,
  'external unassignment replay returns closed evidence without duplicate audit'
);

-- =====================================================================
-- Part 10 — External Lead Photographer + journey containment
-- =====================================================================

-- 63
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_external_lead_photo AS
  SELECT *
  FROM public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'lead_photographer',
    (SELECT id FROM s10_6a_external_two),
    true,
    NULL
  )
  $$,
  'approved external creative may satisfy Lead Photographer assignment evidence'
);

-- 64
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
    CROSS JOIN s10_6a_stage_before before
    WHERE state.booking_id =
          (SELECT id FROM s10_6a_booking)
  ),
  'Slice 6A external/internal creative operations never move the booking journey'
);


-- =====================================================================
-- Part 11 — Authorization and guard defense in depth
-- =====================================================================

GRANT SELECT
ON
  s10_6a_booking,
  s10_6a_external_one,
  s10_6a_external_two,
  s10_6a_external_lead_video
TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- Unauthorized application actor
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000005',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);

-- 65
SELECT throws_ok(
  $$
  SELECT public.create_external_creative(
    (SELECT id FROM s10_6a_booking),
    'Unauthorized External Creative'
  )
  $$,
  '42501',
  'create_external_creative: booking.team.assign permission required',
  'ordinary Photographer cannot register an external creative without booking.team.assign'
);

-- 66
SELECT throws_ok(
  $$
  SELECT public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    (SELECT id FROM s10_6a_external_two),
    true,
    NULL
  )
  $$,
  '42501',
  'assign_booking_external_creative: booking.team.assign permission required',
  'ordinary Photographer cannot assign an external creative without booking.team.assign'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 67
SELECT throws_ok(
  $$
  SELECT public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    '8affffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    true,
    NULL
  )
  $$,
  '22023',
  'assign_booking_external_creative: external creative unavailable for booking organization',
  'unknown external creative identity cannot be assigned'
);

-- ---------------------------------------------------------------------
-- Direct authenticated access remains denied
-- ---------------------------------------------------------------------

SET LOCAL ROLE authenticated;

-- 68
SELECT throws_ok(
  $$
  INSERT INTO public.external_creatives (
    organization_id,
    display_name,
    created_by
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'Direct Insert Probe',
    '8a000000-0000-0000-0000-000000000101'
  )
  $$,
  '42501',
  'permission denied for table external_creatives',
  'authenticated direct external-creative INSERT is denied'
);

-- 69
SELECT throws_ok(
  $$
  UPDATE public.external_creatives
  SET display_name =
      'Direct Update Probe'
  WHERE false
  $$,
  '42501',
  'permission denied for table external_creatives',
  'authenticated direct external-creative UPDATE is denied'
);

-- 70
SELECT throws_ok(
  $$
  DELETE FROM public.external_creatives
  WHERE false
  $$,
  '42501',
  'permission denied for table external_creatives',
  'authenticated direct external-creative DELETE is denied'
);

-- 71
SELECT throws_ok(
  $$
  UPDATE public.commercial_operational_requirements
  SET requirement_key =
      requirement_key
  WHERE false
  $$,
  '42501',
  'permission denied for table commercial_operational_requirements',
  'authenticated cannot directly mutate commercial operational requirements'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Trusted-role guard defense remains structural
-- ---------------------------------------------------------------------

SET LOCAL ROLE service_role;

-- 72
SELECT throws_ok(
  $$
  UPDATE public.external_creatives
  SET display_name =
      display_name || ' changed'
  WHERE id =
        (SELECT id FROM s10_6a_external_one)
  $$,
  'P0001',
  'external creative identity is immutable',
  'service_role cannot rewrite stable external creative identity'
);

-- 73
SELECT throws_ok(
  $$
  DELETE FROM public.external_creatives
  WHERE id =
        (SELECT id FROM s10_6a_external_one)
  $$,
  'P0001',
  'external creative identity cannot be deleted',
  'service_role cannot delete stable external creative identity'
);

-- 74
SELECT throws_ok(
  $$
  UPDATE public.commercial_operational_requirements
  SET requirement_key =
      requirement_key
  WHERE requirement_key =
        'lead_videographer'
  $$,
  'P0001',
  'commercial operational requirement evidence is append-only and immutable',
  'service_role cannot rewrite commercial operational requirement evidence'
);

-- 75
SELECT throws_ok(
  $$
  UPDATE public.booking_team_assignments
  SET assigned_external_creative_id =
      (SELECT id FROM s10_6a_external_two)
  WHERE id =
        (SELECT id FROM s10_6a_external_lead_video)
  $$,
  'P0001',
  'booking team assignment identity and original assignment evidence are immutable',
  'service_role cannot rewrite the external subject identity on assignment history'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Cross-subject Lead replacement rollback atomicity
-- ---------------------------------------------------------------------

CREATE FUNCTION public.s10_6a_fail_internal_lead_video_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.assignment_role =
       'lead_videographer'
     AND NEW.assigned_member_id =
         '8a000000-0000-0000-0000-000000000103'::uuid THEN
    RAISE EXCEPTION
      's10 slice6a forced cross-subject Lead insertion failure';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER zz_s10_6a_fail_internal_lead_video_insert
BEFORE INSERT
ON public.booking_team_assignments
FOR EACH ROW
EXECUTE FUNCTION public.s10_6a_fail_internal_lead_video_insert();

-- 76
SELECT throws_ok(
  $$
  SELECT public.assign_booking_team_member(
    (SELECT id FROM s10_6a_booking),
    'lead_videographer',
    '8a000000-0000-0000-0000-000000000103',
    true,
    'Forced cross-subject rollback probe'
  )
  $$,
  'P0001',
  's10 slice6a forced cross-subject Lead insertion failure',
  'failed external-to-internal Lead replacement aborts the replacement statement'
);

DROP TRIGGER zz_s10_6a_fail_internal_lead_video_insert
ON public.booking_team_assignments;

DROP FUNCTION public.s10_6a_fail_internal_lead_video_insert();

-- 77
SELECT ok(
  (
    SELECT
      assignment.assigned_member_id IS NULL
      AND assignment.assigned_external_creative_id =
          (SELECT id FROM s10_6a_external_one)
      AND assignment.ended_at IS NULL
    FROM public.booking_team_assignments assignment
    WHERE assignment.id =
          (SELECT id FROM s10_6a_external_lead_video)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10_6a_booking)
      AND assignment.assignment_role =
          'lead_videographer'
      AND assignment.ended_at IS NULL
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.team_member_replaced'
      AND audit.metadata->>'booking_id' =
          (SELECT id::text FROM s10_6a_booking)
  ) = 1,
  'failed cross-subject Lead replacement rolls back closure, insertion and audit atomically'
);


-- =====================================================================
-- Part 12 — Branch-derived external creative isolation
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8a000000-0000-0000-0000-000000000006'::uuid),
  ('8a000000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '8a000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000006',
  'active',
  'S10 Slice 6A Branch Coordinator'
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
  '8a000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 Slice 6A Branch A',
  's6aa',
  'active',
  'IN',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
),
(
  '8a000000-0000-0000-0000-000000000202',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 Slice 6A Branch B',
  's6ab',
  'active',
  'IN',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000106',
  role.id,
  '8a000000-0000-0000-0000-000000000201'
FROM public.roles role
WHERE role.key =
      'client_coordinator';

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
  '8a000000-0000-0000-0000-000000000402',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000201',
  'QZ-6789AC',
  'S10 Slice 6A Branch A Family',
  'Slice 6A Branch A Family',
  'active',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
),
(
  '8a000000-0000-0000-0000-000000000403',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000202',
  'QZ-6789AD',
  'S10 Slice 6A Branch B Family',
  'Slice 6A Branch B Family',
  'active',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
);

CREATE TEMP TABLE s10_6a_quote_branch_a AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000402',
  NULL,
  '8a000000-0000-0000-0000-000000000201',
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10_6a_quote_branch_a),
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
  (SELECT id FROM s10_6a_quote_branch_a),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10_6a_quote_branch_a),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10_6a_booking_branch_a AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10_6a_quote_branch_a)
);

CREATE TEMP TABLE s10_6a_quote_branch_b AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000403',
  NULL,
  '8a000000-0000-0000-0000-000000000202',
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10_6a_quote_branch_b),
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
  (SELECT id FROM s10_6a_quote_branch_b),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10_6a_quote_branch_b),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10_6a_booking_branch_b AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10_6a_quote_branch_b)
);

GRANT SELECT
ON
  s10_6a_booking_branch_a,
  s10_6a_booking_branch_b
TO authenticated, service_role;

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
  's10_slice6a_branch_booking_confirmed',
  now(),
  '8a000000-0000-0000-0000-000000000101'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE state.booking_id IN (
  (SELECT id FROM s10_6a_booking_branch_a),
  (SELECT id FROM s10_6a_booking_branch_b)
);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '8a000000-0000-0000-0000-000000000101'
FROM public.booking_journey_stages target
WHERE state.booking_id IN (
        (SELECT id FROM s10_6a_booking_branch_a),
        (SELECT id FROM s10_6a_booking_branch_b)
      )
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

CREATE TEMP TABLE s10_6a_branch_b_external AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10_6a_booking_branch_b),
  'S10 Branch B External Creative'
);

CREATE TEMP TABLE s10_6a_branch_b_support AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10_6a_booking_branch_b),
  'supporting_videographer',
  (SELECT id FROM s10_6a_branch_b_external),
  true,
  NULL
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000006',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);

-- 78
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_branch_a_external AS
  SELECT *
  FROM public.create_external_creative(
    (SELECT id FROM s10_6a_booking_branch_a),
    'S10 Branch A External Creative'
  )
  $$,
  'branch-scoped Client Coordinator can register an external creative for its own branch booking'
);

-- 79
SELECT throws_ok(
  $$
  SELECT public.create_external_creative(
    (SELECT id FROM s10_6a_booking_branch_b),
    'Wrong Branch External Probe'
  )
  $$,
  '42501',
  'create_external_creative: booking.team.assign permission required',
  'branch-scoped Client Coordinator cannot register an external creative for another branch'
);

-- 80
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_6a_branch_a_support AS
  SELECT *
  FROM public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking_branch_a),
    'supporting_videographer',
    (SELECT id FROM s10_6a_branch_a_external),
    true,
    NULL
  )
  $$,
  'branch-scoped Client Coordinator can assign an external creative inside its branch'
);

-- 81
SELECT throws_ok(
  $$
  SELECT public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking_branch_b),
    'supporting_videographer',
    (SELECT id FROM s10_6a_branch_a_external),
    true,
    NULL
  )
  $$,
  '42501',
  'assign_booking_external_creative: booking.team.assign permission required',
  'branch-scoped Client Coordinator cannot assign an external creative into another branch'
);

SET LOCAL ROLE authenticated;

-- 82
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10_6a_booking_branch_a)
  ) > 0
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10_6a_booking_branch_b)
  ) = 0
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10_6a_booking)
  ) = 0,
  'branch-scoped Client Coordinator sees branch-A staffing but not branch-B or other-branch staffing'
);

RESET ROLE;

-- =====================================================================
-- Part 13 — Cross-organization external identity isolation
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
  '8a000000-0000-0000-0000-000000000501',
  'S10 Slice 6A Foreign Studio',
  's10-slice6a-foreign-studio',
  'suspended',
  'INR',
  'Asia/Kolkata',
  'S6AF'
);

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '8a000000-0000-0000-0000-000000000501'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '8a000000-0000-0000-0000-000000000107',
  '8a000000-0000-0000-0000-000000000501',
  '8a000000-0000-0000-0000-000000000007',
  'active',
  'S10 Slice 6A Foreign Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '8a000000-0000-0000-0000-000000000501',
  '8a000000-0000-0000-0000-000000000107',
  role.id,
  NULL
FROM public.roles role
WHERE role.key =
      'founder';

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '8a000000-0000-0000-0000-000000000501';

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

SET LOCAL ROLE service_role;

INSERT INTO public.external_creatives (
  id,
  organization_id,
  display_name,
  created_by
)
VALUES (
  '8a000000-0000-0000-0000-000000000601',
  '8a000000-0000-0000-0000-000000000501',
  'S10 Slice 6A Foreign External Creative',
  '8a000000-0000-0000-0000-000000000107'
);

RESET ROLE;

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 83
SELECT throws_ok(
  $$
  SELECT public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    '8a000000-0000-0000-0000-000000000601',
    true,
    NULL
  )
  $$,
  '22023',
  'assign_booking_external_creative: external creative unavailable for booking organization',
  'canonical Founder cannot attach a foreign-organization external identity to the booking'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

-- 84
SELECT throws_ok(
  $$
  SELECT public.create_external_creative(
    (SELECT id FROM s10_6a_booking),
    'Foreign Founder Canonical Booking Probe'
  )
  $$,
  '42501',
  'create_external_creative: active organization membership required',
  'foreign-organization Founder cannot register external identity against canonical booking'
);

-- 85
SELECT throws_ok(
  $$
  SELECT public.assign_booking_external_creative(
    (SELECT id FROM s10_6a_booking),
    'supporting_videographer',
    (SELECT id FROM s10_6a_external_two),
    true,
    NULL
  )
  $$,
  '42501',
  'assign_booking_external_creative: active organization membership required',
  'foreign-organization Founder cannot mutate canonical external staffing'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

SELECT * FROM finish();

ROLLBACK;
