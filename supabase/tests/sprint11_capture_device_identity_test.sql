CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(34);

-- =====================================================================
-- Phase 2 Studio Operations
-- Corrective Slice B0 - Capture Device Identity Foundation
--
-- Proves:
--   * exact media.device.register authority topology;
--   * exact immutable five-column inventory relation;
--   * tenant-safe organization/member containment;
--   * organization-scoped case-insensitive capture-device identity;
--   * forced RLS / authenticated-only governed read access;
--   * controlled authenticated registration RPC;
--   * active organization-wide authority only;
--   * normalized idempotent replay;
--   * one first-success audit event;
--   * no booking or journey mutation.
-- =====================================================================


-- =====================================================================
-- Part 1A - Catalogue / schema contract
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT
      (SELECT count(*) FROM public.permissions)::text
      || ':'
      || (SELECT count(*) FROM public.role_permissions)::text
  ),
  '70:245'::text,
  'canonical permission and role-mapping totals are exactly 70:245'
);


-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key =
          'media.device.register'
      AND permission.domain =
          'media'
      AND permission.label =
          'Register capture devices'
      AND permission.requires_server_enforcement
  ),
  1::bigint,
  'media.device.register exists exactly once with frozen media-domain contract'
);


-- 3
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
          'media.device.register'
  ),
  ARRAY[
    'founder',
    'studio_manager'
  ]::text[],
  'media.device.register is granted only to Founder and Studio Manager'
);


-- 4
SELECT is(
  (
    SELECT array_agg(
      column_name || ':' || udt_name
      ORDER BY ordinal_position
    )
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'capture_devices'
  ),
  ARRAY[
    'id:uuid',
    'organization_id:uuid',
    'device_code:text',
    'registered_at:timestamptz',
    'registered_by:uuid'
  ]::text[],
  'capture_devices contains exactly the frozen five-column typed contract'
);


-- 5
SELECT ok(
  (
    SELECT replace(
      pg_catalog.pg_get_constraintdef(
        constraint_row.oid
      ),
      'public.',
      ''
    )
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.capture_devices'::regclass
      AND constraint_row.conname =
          'capture_devices_organization_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id) REFERENCES organizations(id)%',
  'capture_devices organization foreign key is canonical'
);


-- 6
SELECT ok(
  (
    SELECT replace(
      pg_catalog.pg_get_constraintdef(
        constraint_row.oid
      ),
      'public.',
      ''
    )
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.capture_devices'::regclass
      AND constraint_row.conname =
          'capture_devices_registered_by_fkey'
  ) LIKE
    'FOREIGN KEY (registered_by, organization_id) REFERENCES organization_members(id, organization_id)%',
  'capture-device registering member foreign key is tenant-safe'
);


-- 7
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_indexes index_row
    WHERE index_row.schemaname =
          'public'
      AND index_row.tablename =
          'capture_devices'
      AND index_row.indexname =
          'capture_devices_org_device_code_ci_key'
      AND index_row.indexdef ILIKE
          '%UNIQUE INDEX%'
      AND index_row.indexdef ILIKE
          '%organization_id%'
      AND index_row.indexdef ILIKE
          '%lower(device_code)%'
  ),
  'capture-device identity is case-insensitively unique inside one organization'
);


-- 8
SELECT ok(
  (
    SELECT
      relation.relrowsecurity
      AND relation.relforcerowsecurity
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.capture_devices'::regclass
  ),
  'capture_devices enables and forces RLS'
);


-- =====================================================================
-- Part 1B - ACL / policy / RPC contract
-- =====================================================================

-- 9
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.capture_devices',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.capture_devices',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.capture_devices',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.capture_devices',
    'DELETE'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.capture_devices',
    'SELECT'
  ),
  'capture_devices grants authenticated SELECT only and exposes no anon access'
);


-- 10
SELECT ok(
  (
    SELECT
      lower(COALESCE(policy.qual, ''))
        LIKE '%media.device.register%'
      AND lower(COALESCE(policy.qual, ''))
        LIKE '%current_organization_member%'
      AND lower(COALESCE(policy.qual, ''))
        LIKE '%has_permission%'
    FROM pg_catalog.pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename =
          'capture_devices'
      AND policy.policyname =
          'capture_devices_authenticated_select'
      AND policy.cmd =
          'SELECT'
  ),
  'capture-device read policy requires active membership and media.device.register'
);


-- 11
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.capture_devices'::regclass
      AND trigger_row.tgname =
          'capture_devices_immutable_guard'
      AND NOT trigger_row.tgisinternal
  )
  AND to_regprocedure(
        'public.lsh_capture_device_immutable_guard()'
      ) IS NOT NULL,
  'capture-device immutable identity guard exists'
);


-- 12
SELECT ok(
  to_regprocedure(
    'public.register_capture_device(uuid,text)'
  ) IS NOT NULL
  AND (
    SELECT pg_catalog.pg_get_function_result(
      procedure.oid
    )
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.register_capture_device(uuid,text)'::regprocedure
  ) = 'capture_devices',
  'register_capture_device(uuid,text) exists and returns capture_devices'
);


-- 13
SELECT ok(
  (
    SELECT count(*)
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.pronamespace =
          'public'::regnamespace
      AND procedure.proname =
          'register_capture_device'
  ) = 1
  AND (
    SELECT procedure.prosecdef
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.register_capture_device(uuid,text)'::regprocedure
  )
  AND (
    SELECT procedure.proconfig
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.register_capture_device(uuid,text)'::regprocedure
  ) = ARRAY['search_path=""']::text[],
  'registration RPC has one SECURITY DEFINER signature with empty search_path'
);


-- 14
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.register_capture_device(uuid,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.register_capture_device(uuid,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.register_capture_device(uuid,text)',
    'EXECUTE'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault(
          'f',
          procedure.proowner
        )
      )
    ) acl
    WHERE procedure.oid =
      'public.register_capture_device(uuid,text)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'registration RPC execution ACL is authenticated-only'
);


-- 15
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%media.device.register%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%current_organization_member%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%append_audit_event%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%media.capture_device_registered%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking.stage.advance%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_stage_transitions%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_journey_states%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%checksum%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%backup%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%handover%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%custody%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.register_capture_device(uuid,text)'::regprocedure
  ),
  'registration RPC contains only frozen inventory authority and imports no later workflow authority'
);


-- =====================================================================
-- Part 2 - Transaction-local identities and authority fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('ca100000-0000-0000-0000-000000000001'::uuid),
  ('ca100000-0000-0000-0000-000000000002'::uuid),
  ('ca100000-0000-0000-0000-000000000003'::uuid),
  ('ca100000-0000-0000-0000-000000000004'::uuid),
  ('ca100000-0000-0000-0000-000000000005'::uuid),
  ('ca100000-0000-0000-0000-000000000006'::uuid);


INSERT INTO public.organizations (
  id,
  display_name,
  slug,
  status
)
VALUES (
  'ca100000-0000-0000-0000-000000000901'::uuid,
  'S11 Capture Device Identity Organization B',
  's11-media-inventory-b',
  'active'::public.organization_status
);


INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES (
  'ca100000-0000-0000-0000-000000000701'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'S11 Capture Device Identity Branch',
  's11-media-inventory',
  'active'::public.branch_status
);


INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  suspended_at
)
VALUES
(
  'ca100000-0000-0000-0000-000000000101'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'ca100000-0000-0000-0000-000000000001'::uuid,
  'active'::public.member_status,
  'Capture Device Identity Founder',
  NULL
),
(
  'ca100000-0000-0000-0000-000000000102'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'ca100000-0000-0000-0000-000000000002'::uuid,
  'active'::public.member_status,
  'Capture Device Identity Studio Manager',
  NULL
),
(
  'ca100000-0000-0000-0000-000000000103'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'ca100000-0000-0000-0000-000000000003'::uuid,
  'active'::public.member_status,
  'Capture Device Identity Photographer',
  NULL
),
(
  'ca100000-0000-0000-0000-000000000104'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'ca100000-0000-0000-0000-000000000004'::uuid,
  'suspended'::public.member_status,
  'Suspended Capture Device Identity Founder',
  now()
),
(
  'ca100000-0000-0000-0000-000000000105'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'ca100000-0000-0000-0000-000000000005'::uuid,
  'active'::public.member_status,
  'Branch Scoped Capture Device Identity Manager',
  NULL
),
(
  'ca100000-0000-0000-0000-000000000106'::uuid,
  'ca100000-0000-0000-0000-000000000901'::uuid,
  'ca100000-0000-0000-0000-000000000006'::uuid,
  'active'::public.member_status,
  'Organization B Capture Device Identity Founder',
  NULL
);


INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  fixture.organization_id,
  fixture.member_id,
  role.id,
  fixture.branch_id
FROM (
  VALUES
    (
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'ca100000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'ca100000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'ca100000-0000-0000-0000-000000000103'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'ca100000-0000-0000-0000-000000000104'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'ca100000-0000-0000-0000-000000000105'::uuid,
      'studio_manager'::text,
      'ca100000-0000-0000-0000-000000000701'::uuid
    ),
    (
      'ca100000-0000-0000-0000-000000000901'::uuid,
      'ca100000-0000-0000-0000-000000000106'::uuid,
      'founder'::text,
      NULL::uuid
    )
) AS fixture(
  organization_id,
  member_id,
  role_key,
  branch_id
)
JOIN public.roles role
  ON role.key =
     fixture.role_key;


CREATE FUNCTION pg_temp.capture_device_identity_set_actor(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claim.sub',
    COALESCE(p_user_id::text, ''),
    true
  );

  PERFORM set_config(
    'request.jwt.claims',
    CASE
      WHEN p_user_id IS NULL THEN '{}'
      ELSE jsonb_build_object(
        'sub',
        p_user_id,
        'role',
        'authenticated'
      )::text
    END,
    true
  );
END;
$$;


UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;


CREATE TEMP TABLE capture_device_identity_baseline AS
SELECT
  (SELECT count(*)::bigint FROM public.bookings)
    AS booking_count,
  (SELECT count(*)::bigint FROM public.booking_journey_states)
    AS journey_state_count,
  (SELECT count(*)::bigint FROM public.booking_stage_transitions)
    AS journey_transition_count,
  (SELECT count(*)::bigint FROM public.media_cards)
    AS media_card_count;


-- =====================================================================
-- Part 3 - Fail-closed input and authorization contract
-- =====================================================================

SELECT pg_temp.capture_device_identity_set_actor(
  'ca100000-0000-0000-0000-000000000001'::uuid
);


-- 16
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    NULL,
    'CAM-001'
  )
  $$,
  '22023',
  'register_capture_device: organization_id is required',
  'null organization id is rejected'
);


-- 17
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    NULL
  )
  $$,
  '22023',
  'register_capture_device: device_code is required',
  'null device code is rejected'
);


-- 18
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    '   '
  )
  $$,
  '22023',
  'register_capture_device: device_code must not be empty',
  'blank normalized device code is rejected'
);


-- 19
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    repeat('X', 121)
  )
  $$,
  '22023',
  'register_capture_device: device_code must not exceed 120 characters',
  'device code longer than 120 characters is rejected'
);


SELECT pg_temp.capture_device_identity_set_actor(NULL);


-- 20
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'CAM-ANON'
  )
  $$,
  '42501',
  'register_capture_device: authenticated actor required',
  'unauthenticated registration is rejected'
);


SELECT pg_temp.capture_device_identity_set_actor(
  'ca100000-0000-0000-0000-000000000004'::uuid
);


-- 21
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'CAM-SUSPENDED'
  )
  $$,
  '42501',
  'register_capture_device: active organization membership required',
  'suspended Founder cannot register capture devices'
);


SELECT pg_temp.capture_device_identity_set_actor(
  'ca100000-0000-0000-0000-000000000003'::uuid
);


-- 22
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'CAM-PHOTOGRAPHER'
  )
  $$,
  '42501',
  'register_capture_device: media.device.register permission required',
  'Photographer has no capture-device registration authority'
);


SELECT pg_temp.capture_device_identity_set_actor(
  'ca100000-0000-0000-0000-000000000005'::uuid
);


-- 23
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'CAM-BRANCH-MANAGER'
  )
  $$,
  '42501',
  'register_capture_device: media.device.register permission required',
  'branch-scoped Studio Manager does not receive organization-wide capture-device identity authority'
);


-- =====================================================================
-- Part 4 - Successful registration / replay / tenant identity
-- =====================================================================

CREATE TEMP TABLE capture_device_identity_results (
  label text PRIMARY KEY,
  capture_device_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  device_code text NOT NULL,
  registered_at timestamptz NOT NULL,
  registered_by uuid NOT NULL
);


-- Existing Founder from Organization A is not a member of Organization B.
SELECT pg_temp.capture_device_identity_set_actor(
  'ca100000-0000-0000-0000-000000000001'::uuid
);


-- 24
SELECT throws_ok(
  $$
  SELECT public.register_capture_device(
    'ca100000-0000-0000-0000-000000000901'::uuid,
    'CAM-NONMEMBER'
  )
  $$,
  '42501',
  'register_capture_device: active organization membership required',
  'active actor without target-organization membership is rejected'
);


-- Founder first success with surrounding whitespace.
INSERT INTO capture_device_identity_results (
  label,
  capture_device_id,
  organization_id,
  device_code,
  registered_at,
  registered_by
)
SELECT
  'founder_first',
  device.id,
  device.organization_id,
  device.device_code,
  device.registered_at,
  device.registered_by
FROM public.register_capture_device(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '  CAM-001  '
) device;


-- 25
SELECT ok(
  (
    SELECT
      result.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND result.device_code =
        'CAM-001'
      AND result.registered_by =
        'ca100000-0000-0000-0000-000000000101'::uuid
      AND result.registered_at IS NOT NULL
    FROM capture_device_identity_results result
    WHERE result.label =
          'founder_first'
  )
  AND (
    SELECT count(*) = 1
    FROM public.capture_devices device
    WHERE device.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND device.device_code =
          'CAM-001'
  ),
  'Founder registration trims device code and records canonical attribution'
);


-- Studio Manager first success.
SELECT pg_temp.capture_device_identity_set_actor(
  'ca100000-0000-0000-0000-000000000002'::uuid
);

INSERT INTO capture_device_identity_results (
  label,
  capture_device_id,
  organization_id,
  device_code,
  registered_at,
  registered_by
)
SELECT
  'studio_first',
  device.id,
  device.organization_id,
  device.device_code,
  device.registered_at,
  device.registered_by
FROM public.register_capture_device(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'CAM-002'
) device;


-- 26
SELECT ok(
  (
    SELECT
      result.device_code =
        'CAM-002'
      AND result.registered_by =
        'ca100000-0000-0000-0000-000000000102'::uuid
    FROM capture_device_identity_results result
    WHERE result.label =
          'studio_first'
  ),
  'organization-wide Studio Manager may register a canonical capture device'
);


-- Replay CAM-001 under another authorized actor using different case.
INSERT INTO capture_device_identity_results (
  label,
  capture_device_id,
  organization_id,
  device_code,
  registered_at,
  registered_by
)
SELECT
  'founder_replay',
  device.id,
  device.organization_id,
  device.device_code,
  device.registered_at,
  device.registered_by
FROM public.register_capture_device(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  ' cam-001 '
) device;


-- 27
SELECT ok(
  (
    SELECT
      replay.capture_device_id =
        original.capture_device_id
      AND replay.organization_id =
        original.organization_id
      AND replay.device_code =
        original.device_code
      AND replay.registered_at =
        original.registered_at
      AND replay.registered_by =
        original.registered_by
    FROM capture_device_identity_results replay
    CROSS JOIN capture_device_identity_results original
    WHERE replay.label =
          'founder_replay'
      AND original.label =
          'founder_first'
  )
  AND (
    SELECT count(*) = 1
    FROM public.capture_devices device
    WHERE device.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND lower(device.device_code) =
          'cam-001'
  ),
  'case-insensitive replay returns the exact immutable original identity'
);


-- 28
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(NOT audit.is_sensitive)
      AND bool_and(audit.old_values IS NULL)
      AND bool_and(audit.new_values IS NULL)
      AND bool_and(
        audit.metadata =
        jsonb_build_object(
          'organization_id',
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
          'capture_device_id',
          result.capture_device_id,
          'registered_by',
          'ca100000-0000-0000-0000-000000000101'::uuid
        )
      )
      AND bool_and(
        NOT audit.metadata ? 'device_code'
      )
    FROM public.audit_events audit
    CROSS JOIN capture_device_identity_results result
    WHERE result.label =
          'founder_first'
      AND audit.organization_id =
          result.organization_id
      AND audit.entity_id =
          result.capture_device_id
      AND audit.entity_type =
          'capture_device'
      AND audit.action_key =
          'media.capture_device_registered'
  ),
  'first success emits exactly one structural non-sensitive audit and replay emits none'
);


-- Same textual identity is independently valid in Organization B.
SELECT pg_temp.capture_device_identity_set_actor(
  'ca100000-0000-0000-0000-000000000006'::uuid
);

INSERT INTO capture_device_identity_results (
  label,
  capture_device_id,
  organization_id,
  device_code,
  registered_at,
  registered_by
)
SELECT
  'organization_b_same_code',
  device.id,
  device.organization_id,
  device.device_code,
  device.registered_at,
  device.registered_by
FROM public.register_capture_device(
  'ca100000-0000-0000-0000-000000000901'::uuid,
  ' CAM-001 '
) device;


-- 29
SELECT ok(
  (
    SELECT
      organization_b.capture_device_id <>
        organization_a.capture_device_id
      AND organization_b.organization_id =
        'ca100000-0000-0000-0000-000000000901'::uuid
      AND organization_b.device_code =
        'CAM-001'
      AND organization_b.registered_by =
        'ca100000-0000-0000-0000-000000000106'::uuid
    FROM capture_device_identity_results organization_b
    CROSS JOIN capture_device_identity_results organization_a
    WHERE organization_b.label =
          'organization_b_same_code'
      AND organization_a.label =
          'founder_first'
  ),
  'same textual device code is an independent canonical identity in another organization'
);


-- =====================================================================
-- Part 5 - Direct mutation denial / immutability / containment
-- =====================================================================

CREATE FUNCTION pg_temp.capture_device_identity_capture_owner_update(
  p_capture_device_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.capture_devices
  SET device_code =
      device_code || '-MUTATED'
  WHERE id =
        p_capture_device_id;

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


CREATE FUNCTION pg_temp.capture_device_identity_capture_owner_delete(
  p_capture_device_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM public.capture_devices
  WHERE id =
        p_capture_device_id;

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


SET LOCAL ROLE authenticated;


-- 30
SELECT throws_ok(
  $$
  INSERT INTO public.capture_devices (
    organization_id,
    device_code,
    registered_by
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'CAM-DIRECT-INSERT',
    'ca100000-0000-0000-0000-000000000101'::uuid
  )
  $$,
  '42501',
  'permission denied for table capture_devices',
  'authenticated actor cannot directly INSERT capture-device inventory'
);


-- 31
SELECT throws_ok(
  $$
  UPDATE public.capture_devices
  SET device_code =
      'CAM-DIRECT-UPDATE'
  WHERE id = (
    SELECT capture_device_id
    FROM capture_device_identity_results
    WHERE label =
          'founder_first'
  )
  $$,
  '42501',
  'permission denied for table capture_devices',
  'authenticated actor cannot directly UPDATE capture-device inventory'
);


-- 32
SELECT throws_ok(
  $$
  DELETE FROM public.capture_devices
  WHERE id = (
    SELECT capture_device_id
    FROM capture_device_identity_results
    WHERE label =
          'founder_first'
  )
  $$,
  '42501',
  'permission denied for table capture_devices',
  'authenticated actor cannot directly DELETE capture-device inventory'
);


RESET ROLE;


-- 33
SELECT ok(
  pg_temp.capture_device_identity_capture_owner_update(
    (
      SELECT capture_device_id
      FROM capture_device_identity_results
      WHERE label =
            'founder_first'
    )
  ) =
    'P0001:capture device inventory identity is immutable'
  AND
  pg_temp.capture_device_identity_capture_owner_delete(
    (
      SELECT capture_device_id
      FROM capture_device_identity_results
      WHERE label =
            'founder_first'
    )
  ) =
    'P0001:capture device inventory identity is immutable',
  'immutable guard rejects UPDATE and DELETE even through privileged direct mutation'
);


-- 34
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.bookings
  ) =
    (
      SELECT booking_count
      FROM capture_device_identity_baseline
    )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_journey_states
  ) =
    (
      SELECT journey_state_count
      FROM capture_device_identity_baseline
    )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
  ) =
    (
      SELECT journey_transition_count
      FROM capture_device_identity_baseline
    )
  AND
  (
    SELECT count(*)::bigint
    FROM public.media_cards
  ) =
    (
      SELECT media_card_count
      FROM capture_device_identity_baseline
    )
  AND
  (
    SELECT count(*)::bigint
    FROM public.capture_devices
  ) = 3::bigint,
  'capture-device registration mutates only capture-device inventory and leaves media-card, booking, and journey state untouched'
);


SELECT * FROM finish();

ROLLBACK;
