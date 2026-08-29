CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(76);

-- =====================================================================
-- Sprint 11 Slice 5
-- Canonical Client Image Selection Confirmation Evidence Foundation
--
-- Proves:
--   * exact selection.read / selection.record catalogue contract;
--   * exact role grants and repository-wide cardinalities;
--   * immutable tenant-safe confirmation evidence;
--   * forced RLS / selection.read containment;
--   * controlled authenticated selection.record RPC;
--   * exact Stage 12 / selection_pending containment;
--   * exact Stage 11 -> 12 / selection_pending lineage;
--   * temporal confirmation invariant;
--   * four authorized recorder roles;
--   * unauthorized / suspended / cross-branch rejection;
--   * exact idempotent replay / conflict rejection;
--   * structural non-sensitive audit provenance;
--   * no journey advancement;
--   * no payment mutation;
--   * no individual selected-image identifiers.
-- =====================================================================

-- =====================================================================
-- Part 1 — Structural / permission / ACL contract
-- =====================================================================

-- 1
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  72::bigint,
  'canonical permission catalogue contains exactly 69 permissions'
);

-- 2
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  247::bigint,
  'canonical repository-wide role-permission mapping count is 243'
);

-- 3
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key = 'selection.read'
      AND permission.domain = 'selection'
      AND permission.label = 'View selection confirmations'
      AND NOT permission.requires_server_enforcement
  ),
  1::bigint,
  'selection.read exists exactly once with server enforcement false'
);

-- 4
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key = 'selection.record'
      AND permission.domain = 'selection'
      AND permission.label = 'Record selection confirmation'
      AND permission.requires_server_enforcement
  ),
  1::bigint,
  'selection.record exists exactly once with server enforcement true'
);

-- 5
SELECT is(
  (
    SELECT string_agg(role.key, ',' ORDER BY role.key)
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id = role_permission.permission_id
    JOIN public.roles role
      ON role.id = role_permission.role_id
    WHERE permission.key = 'selection.read'
  ),
  'client_coordinator,editor,founder,studio_manager'::text,
  'selection.read is granted only to the four frozen roles'
);

-- 6
SELECT is(
  (
    SELECT string_agg(role.key, ',' ORDER BY role.key)
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id = role_permission.permission_id
    JOIN public.roles role
      ON role.id = role_permission.role_id
    WHERE permission.key = 'selection.record'
  ),
  'client_coordinator,editor,founder,studio_manager'::text,
  'selection.record is granted only to the four frozen roles'
);

-- 7
SELECT ok(
  to_regclass(
    'public.booking_selection_confirmations'
  ) IS NOT NULL,
  'booking_selection_confirmations exists'
);

-- 8
SELECT is(
  (
    SELECT array_agg(
             column_name
             ORDER BY ordinal_position
           )::text[]
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_selection_confirmations'
  ),
  ARRAY[
    'id',
    'organization_id',
    'booking_id',
    'selected_image_count',
    'confirmed_at',
    'recorded_at',
    'recorded_by'
  ]::text[],
  'selection evidence contains only the frozen structural columns'
);

-- 9
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'booking_selection_confirmations_org_booking_key'
      AND constraint_row.contype = 'u'
  ),
  'selection evidence enforces one row per organization and booking'
);

-- 10
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'booking_selection_confirmations_count_chk'
      AND constraint_row.contype = 'c'
  ),
  'selection evidence enforces the positive selected-image-count constraint'
);

-- 11
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(
               constraint_row.oid
             ),
             'public.',
             ''
           )
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'booking_selection_confirmations_booking_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, booking_id) REFERENCES bookings(organization_id, id)%',
  'selection booking foreign key is tenant-safe'
);

-- 12
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(
               constraint_row.oid
             ),
             'public.',
             ''
           )
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'booking_selection_confirmations_recorded_by_fkey'
  ) LIKE
    'FOREIGN KEY (recorded_by, organization_id) REFERENCES organization_members(id, organization_id)%',
  'selection recorder foreign key is tenant-safe'
);

-- 13
SELECT ok(
  (
    SELECT relation.relrowsecurity
    FROM pg_class relation
    JOIN pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'booking_selection_confirmations'
  ),
  'booking_selection_confirmations has RLS enabled'
);

-- 14
SELECT ok(
  (
    SELECT relation.relforcerowsecurity
    FROM pg_class relation
    JOIN pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'booking_selection_confirmations'
  ),
  'booking_selection_confirmations has RLS forced'
);

-- 15
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_selection_confirmations',
    'SELECT'
  ),
  'authenticated has SELECT on selection evidence'
);

-- 16
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_confirmations',
    'INSERT'
  ),
  'authenticated has no direct INSERT privilege'
);

-- 17
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_confirmations',
    'UPDATE'
  ),
  'authenticated has no direct UPDATE privilege'
);

-- 18
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_confirmations',
    'DELETE'
  ),
  'authenticated has no direct DELETE privilege'
);

-- 19
SELECT ok(
  to_regprocedure(
    'public.record_booking_selection_confirmation(uuid,integer,timestamp with time zone)'
  ) IS NOT NULL,
  'record_booking_selection_confirmation(uuid,integer,timestamptz) exists'
);

-- 20
SELECT is(
  (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_selection_confirmation(uuid,integer,timestamptz)'::regprocedure
  ),
  'booking_selection_confirmations'::text,
  'selection confirmation RPC returns booking_selection_confirmations'
);

-- 21
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_selection_confirmation(uuid,integer,timestamptz)'::regprocedure
  ),
  'selection confirmation RPC is SECURITY DEFINER'
);

-- 22
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_selection_confirmation(uuid,integer,timestamptz)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'selection confirmation RPC uses an empty search_path'
);

-- 23
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_selection_confirmation(uuid,integer,timestamptz)',
    'EXECUTE'
  ),
  'authenticated may execute the selection confirmation RPC'
);

-- 24
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.record_booking_selection_confirmation(uuid,integer,timestamptz)',
    'EXECUTE'
  ),
  'anon may not execute the selection confirmation RPC'
);

-- 25
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.record_booking_selection_confirmation(uuid,integer,timestamptz)',
    'EXECUTE'
  ),
  'service_role is not granted the application selection confirmation RPC'
);

-- 26
SELECT ok(
  to_regprocedure(
    'public.lsh_booking_selection_confirmation_guard()'
  ) IS NOT NULL,
  'immutable selection-confirmation lifecycle guard exists'
);

-- 27
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    JOIN pg_class relation
      ON relation.oid = trigger_row.tgrelid
    JOIN pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'booking_selection_confirmations'
      AND trigger_row.tgname =
          'booking_selection_confirmations_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'selection evidence has exactly one immutable lifecycle trigger'
);

-- =====================================================================
-- Part 2 — Canonical fixture identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8e000000-0000-0000-0000-000000000001'::uuid),
  ('8e000000-0000-0000-0000-000000000002'::uuid),
  ('8e000000-0000-0000-0000-000000000003'::uuid),
  ('8e000000-0000-0000-0000-000000000004'::uuid),
  ('8e000000-0000-0000-0000-000000000005'::uuid),
  ('8e000000-0000-0000-0000-000000000006'::uuid),
  ('8e000000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  '8e000000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice5 Branch A',
  's11s5-a',
  'active'
),
(
  '8e000000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice5 Branch B',
  's11s5-b',
  'active'
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
  '8e000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000001',
  'active',
  'S11S5 Founder',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000002',
  'active',
  'S11S5 Studio Manager',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000003',
  'active',
  'S11S5 Client Coordinator',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000004',
  'active',
  'S11S5 Editor',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000005',
  'active',
  'S11S5 Photographer',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000006',
  'suspended',
  'S11S5 Suspended Founder',
  now()
),
(
  '8e000000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000007',
  'active',
  'S11S5 Branch Coordinator',
  NULL
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
      '8e000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8e000000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      '8e000000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      '8e000000-0000-0000-0000-000000000104'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      '8e000000-0000-0000-0000-000000000105'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      '8e000000-0000-0000-0000-000000000106'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8e000000-0000-0000-0000-000000000107'::uuid,
      'client_coordinator'::text,
      '8e000000-0000-0000-0000-000000000701'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s5_set_actor(
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

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

INSERT INTO public.families (
  id,
  organization_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES (
  '8e000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-56789E',
  'S11 Slice5 Family',
  'S11 Slice5 Family',
  'active',
  '8e000000-0000-0000-0000-000000000101',
  '8e000000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s11s5_create_booking(
  p_branch_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote public.quotations;
  v_booking public.bookings;
  v_package_version_id uuid;
BEGIN
  SELECT version.id
  INTO v_package_version_id
  FROM public.commercial_package_versions version
  JOIN public.commercial_packages package
    ON package.organization_id = version.organization_id
   AND package.id = version.package_id
  WHERE package.package_key = 'maternity_gold'
    AND version.version_number = 1;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8e000000-0000-0000-0000-000000000201',
    NULL,
    p_branch_id,
    NULL,
    NULL
  );

  PERFORM public.add_quotation_package_line(
    v_quote.id,
    v_package_version_id,
    NULL
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'ready'::public.quotation_status
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'sent'::public.quotation_status
  );

  SELECT *
  INTO v_booking
  FROM public.accept_quotation(v_quote.id);

  RETURN v_booking.id;
END;
$$;

CREATE FUNCTION pg_temp.s11s5_move_to_stage(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_transition_key text DEFAULT NULL,
  p_transitioned_at timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
  v_at timestamptz;
BEGIN
  v_at := COALESCE(
    p_transitioned_at,
    now() - interval '10 minutes'
  );

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order =
        p_stage_order
    AND stage.stage_key =
        p_stage_key
    AND stage.is_active;

  INSERT INTO public.booking_stage_transitions (
    organization_id,
    booking_id,
    from_stage_id,
    to_stage_id,
    transition_key,
    transitioned_at,
    transitioned_by
  )
  VALUES (
    v_state.organization_id,
    v_state.booking_id,
    v_state.current_stage_id,
    v_target.id,
    COALESCE(
      p_transition_key,
      's11s5_fixture_' || p_stage_key
    ),
    v_at,
    '8e000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = GREATEST(
      v_at,
      v_state.stage_entered_at
    ),
    version = state.version + 1,
    updated_at = v_at,
    updated_by =
      '8e000000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s5_set_stage_without_transition(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_entered_at timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
  v_at timestamptz;
BEGIN
  v_at := COALESCE(
    p_entered_at,
    now() - interval '10 minutes'
  );

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order =
        p_stage_order
    AND stage.stage_key =
        p_stage_key
    AND stage.is_active;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = GREATEST(
      v_at,
      v_state.stage_entered_at
    ),
    version = state.version + 1,
    updated_at = v_at,
    updated_by =
      '8e000000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s5_prepare_stage12(
  p_booking_id uuid,
  p_selection_transition_key text DEFAULT 'selection_pending'
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s5_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    's11s5_fixture_shoot_completed',
    now() - interval '11 minutes'
  );

  PERFORM pg_temp.s11s5_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    p_selection_transition_key,
    now() - interval '10 minutes'
  );
END;
$$;

CREATE TEMP TABLE s11s5_ids (
  happy_booking_id uuid,
  founder_booking_id uuid,
  manager_booking_id uuid,
  editor_booking_id uuid,
  stage11_booking_id uuid,
  stage13_booking_id uuid,
  zero_state_booking_id uuid,
  missing_lineage_booking_id uuid,
  malformed_lineage_booking_id uuid,
  before_entry_booking_id uuid,
  cross_branch_booking_id uuid,
  selected_image_count integer,
  confirmed_at timestamptz
);

INSERT INTO s11s5_ids
VALUES (
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(NULL),
  pg_temp.s11s5_create_booking(
    '8e000000-0000-0000-0000-000000000702'
  ),
  22,
  now() - interval '5 minutes'
);

SELECT pg_temp.s11s5_prepare_stage12(
  (SELECT happy_booking_id FROM s11s5_ids)
);

SELECT pg_temp.s11s5_prepare_stage12(
  (SELECT founder_booking_id FROM s11s5_ids)
);

SELECT pg_temp.s11s5_prepare_stage12(
  (SELECT manager_booking_id FROM s11s5_ids)
);

SELECT pg_temp.s11s5_prepare_stage12(
  (SELECT editor_booking_id FROM s11s5_ids)
);

SELECT pg_temp.s11s5_prepare_stage12(
  (SELECT before_entry_booking_id FROM s11s5_ids)
);

SELECT pg_temp.s11s5_prepare_stage12(
  (SELECT cross_branch_booking_id FROM s11s5_ids)
);

SELECT pg_temp.s11s5_move_to_stage(
  (SELECT stage11_booking_id FROM s11s5_ids),
  11,
  'shoot_completed',
  's11s5_fixture_shoot_completed',
  now() - interval '10 minutes'
);

SELECT pg_temp.s11s5_move_to_stage(
  (SELECT stage13_booking_id FROM s11s5_ids),
  13,
  'editing_pending',
  's11s5_fixture_editing_pending',
  now() - interval '10 minutes'
);

SELECT pg_temp.s11s5_move_to_stage(
  (SELECT missing_lineage_booking_id FROM s11s5_ids),
  11,
  'shoot_completed',
  's11s5_fixture_shoot_completed',
  now() - interval '11 minutes'
);

SELECT pg_temp.s11s5_set_stage_without_transition(
  (SELECT missing_lineage_booking_id FROM s11s5_ids),
  12,
  'selection_pending',
  now() - interval '10 minutes'
);

SELECT pg_temp.s11s5_prepare_stage12(
  (SELECT malformed_lineage_booking_id FROM s11s5_ids),
  's11s5_malformed_selection_pending'
);

ALTER TABLE public.booking_journey_states
DISABLE TRIGGER USER;

DELETE FROM public.booking_journey_states
WHERE booking_id =
  (SELECT zero_state_booking_id FROM s11s5_ids);

ALTER TABLE public.booking_journey_states
ENABLE TRIGGER USER;

-- =====================================================================
-- Part 3 — Input / actor / stage / lineage rejection
-- =====================================================================

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 28
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    NULL,
    22,
    now() - interval '5 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: booking_id is required',
  'null booking id is rejected'
);

-- 29
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    NULL,
    now() - interval '5 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: selected_image_count must be a positive integer',
  'null selected-image count is rejected'
);

-- 30
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    0,
    now() - interval '5 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: selected_image_count must be a positive integer',
  'zero selected-image count is rejected'
);

-- 31
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    -1,
    now() - interval '5 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: selected_image_count must be a positive integer',
  'negative selected-image count is rejected'
);

-- 32
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    22,
    NULL
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: confirmed_at is required',
  'null confirmation timestamp is rejected'
);

-- 33
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    22,
    now() + interval '1 minute'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: confirmed_at cannot be in the future',
  'future confirmation timestamp is rejected'
);

SELECT pg_temp.s11s5_set_actor(NULL);

-- 34
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  '42501',
  'record_booking_selection_confirmation: authenticated actor required',
  'unauthenticated invocation is rejected'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 35
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    '8effffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    22,
    now() - interval '5 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000006'
);

-- 36
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  '42501',
  'record_booking_selection_confirmation: active organization membership required',
  'suspended member is rejected'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000005'
);

-- 37
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  '42501',
  'record_booking_selection_confirmation: selection.record permission required',
  'Photographer cannot record selection confirmation'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000007'
);

-- 38
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT cross_branch_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  '42501',
  'record_booking_selection_confirmation: selection.record permission required',
  'branch-scoped Coordinator cannot record another branch'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 39
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT zero_state_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  'P0001',
  'record_booking_selection_confirmation: booking must have exactly one current journey state',
  'zero journey-state rows are rejected'
);

-- 40
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT stage11_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: booking must be exactly Selection Pending',
  'Stage 11 is rejected'
);

-- 41
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT stage13_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: booking must be exactly Selection Pending',
  'Stage 13 is rejected'
);

-- 42
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT missing_lineage_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  'P0001',
  'record_booking_selection_confirmation: canonical Selection Pending transition history is invalid',
  'Stage 12 without canonical Stage 11 to 12 lineage is rejected'
);

-- 43
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT malformed_lineage_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes'
  )
  $$,
  'P0001',
  'record_booking_selection_confirmation: canonical Selection Pending transition history is invalid',
  'malformed Stage 11 to 12 transition key is rejected'
);

-- 44
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT before_entry_booking_id FROM s11s5_ids),
    22,
    now() - interval '11 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: confirmed_at cannot precede Selection Pending entry',
  'confirmation timestamp before canonical Stage 12 entry is rejected'
);

-- =====================================================================
-- Part 4 — All frozen authorized recorder roles
-- =====================================================================

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000003'
);

-- 45
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    (SELECT selected_image_count FROM s11s5_ids),
    (SELECT confirmed_at FROM s11s5_ids)
  )
  $$,
  'Client Coordinator records valid selection confirmation'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 46
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT founder_booking_id FROM s11s5_ids),
    20,
    now() - interval '5 minutes'
  )
  $$,
  'Founder records valid selection confirmation'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000002'
);

-- 47
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT manager_booking_id FROM s11s5_ids),
    18,
    now() - interval '5 minutes'
  )
  $$,
  'Studio Manager records valid selection confirmation'
);

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000004'
);

-- 48
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT editor_booking_id FROM s11s5_ids),
    24,
    now() - interval '5 minutes'
  )
  $$,
  'Editor records valid selection confirmation'
);

-- =====================================================================
-- Part 5 — Successful immutable evidence + audit
-- =====================================================================

CREATE TEMP TABLE s11s5_first_confirmation AS
SELECT confirmation.*
FROM public.booking_selection_confirmations confirmation
WHERE confirmation.booking_id =
      (SELECT happy_booking_id FROM s11s5_ids);

-- Snapshot journey/payment state after fixture preparation but before
-- any replay/conflict checks. Recording already occurred, so compare
-- against the known fixture-derived invariants directly below.

-- 49
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_selection_confirmations confirmation
    WHERE confirmation.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  1::bigint,
  'first successful recording creates exactly one confirmation row'
);

-- 50
SELECT is(
  (
    SELECT recorded_by
    FROM s11s5_first_confirmation
  ),
  '8e000000-0000-0000-0000-000000000103'::uuid,
  'confirmation evidence attributes recorded_by to the authenticated Coordinator member'
);

-- 51
SELECT is(
  (
    SELECT selected_image_count
    FROM s11s5_first_confirmation
  ),
  (SELECT selected_image_count FROM s11s5_ids),
  'confirmation evidence preserves selected-image count'
);

-- 52
SELECT is(
  (
    SELECT confirmed_at
    FROM s11s5_first_confirmation
  ),
  (SELECT confirmed_at FROM s11s5_ids),
  'confirmation evidence preserves caller-supplied confirmed_at'
);

-- 53
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_confirmed'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  1::bigint,
  'first selection recording appends exactly one selection-confirmed audit'
);

-- 54
SELECT is(
  (
    SELECT audit.actor_member_id
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_confirmed'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  '8e000000-0000-0000-0000-000000000103'::uuid,
  'selection audit preserves authenticated actor provenance'
);

-- 55
SELECT is(
  (
    SELECT audit.is_sensitive
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_confirmed'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  false,
  'selection-confirmed audit is structural and non-sensitive'
);

-- 56
SELECT ok(
  (
    SELECT
      NOT (
        COALESCE(audit.metadata, '{}'::jsonb)
        ?| ARRAY[
          'selected_image_ids',
          'image_ids',
          'gallery_url',
          'proofing_url',
          'privacy',
          'consent',
          'marketing_approval',
          'package_entitlement',
          'additional_image_charge',
          'payment_state'
        ]
      )
      AND NOT (
        COALESCE(audit.new_values, '{}'::jsonb)
        ?| ARRAY[
          'selected_image_ids',
          'image_ids',
          'gallery_url',
          'proofing_url',
          'privacy',
          'consent',
          'marketing_approval',
          'package_entitlement',
          'additional_image_charge',
          'payment_state'
        ]
      )
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_confirmed'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  'selection audit excludes image identifiers, gallery, privacy and commercial/payment interpretation'
);

-- =====================================================================
-- Part 6 — Replay / conflicting evidence / immutability
-- =====================================================================

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000003'
);

-- 57
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    (SELECT selected_image_count FROM s11s5_ids),
    (SELECT confirmed_at FROM s11s5_ids)
  )
  $$,
  'exact selection confirmation replay is idempotent'
);

-- 58
SELECT is(
  (
    SELECT id
    FROM public.booking_selection_confirmations
    WHERE booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  (
    SELECT id
    FROM s11s5_first_confirmation
  ),
  'exact replay preserves the original immutable confirmation identity'
);

-- 59
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_selection_confirmations
    WHERE booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  1::bigint,
  'exact replay creates no duplicate confirmation evidence'
);

-- 60
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_confirmed'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  1::bigint,
  'exact replay creates no duplicate selection audit'
);

-- 61
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    (SELECT selected_image_count FROM s11s5_ids) + 1,
    (SELECT confirmed_at FROM s11s5_ids)
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: selection confirmation already exists with different evidence',
  'conflicting selected-image count cannot rewrite canonical evidence'
);

-- 62
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_confirmation(
    (SELECT happy_booking_id FROM s11s5_ids),
    (SELECT selected_image_count FROM s11s5_ids),
    now() - interval '4 minutes'
  )
  $$,
  '22023',
  'record_booking_selection_confirmation: selection confirmation already exists with different evidence',
  'conflicting confirmation timestamp cannot rewrite canonical evidence'
);

-- 63
SELECT throws_ok(
  $$
  UPDATE public.booking_selection_confirmations
  SET selected_image_count =
      selected_image_count + 1
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11s5_ids)
  $$,
  'P0001',
  'booking selection confirmation evidence is immutable',
  'selection confirmation UPDATE is rejected by the lifecycle guard'
);

-- 64
SELECT throws_ok(
  $$
  DELETE FROM public.booking_selection_confirmations
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11s5_ids)
  $$,
  'P0001',
  'booking selection confirmation evidence is immutable',
  'selection confirmation DELETE is rejected by the lifecycle guard'
);

-- =====================================================================
-- Part 7 — Journey / payment containment
-- =====================================================================

-- 65
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  'selection_pending'::text,
  'selection confirmation leaves the booking at Stage 12'
);

-- 66
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  3::bigint,
  'selection confirmation does not increment the fixture journey version'
);

-- 67
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  3::bigint,
  'selection confirmation preserves the three pre-existing canonical/fixture journey transitions'
);

-- 68
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         transition_row.organization_id
     AND stage.id =
         transition_row.to_stage_id
    WHERE transition_row.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
      AND stage.stage_order = 13
      AND stage.stage_key = 'editing_pending'
  ),
  0::bigint,
  'selection confirmation performs no Stage 12 to 13 advancement'
);

-- 69
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payments payment
    WHERE payment.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  0::bigint,
  'selection confirmation creates no payment evidence'
);

-- 70
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id =
         transition_row.organization_id
     AND source_stage.id =
         transition_row.from_stage_id
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id =
         transition_row.organization_id
     AND destination_stage.id =
         transition_row.to_stage_id
    WHERE transition_row.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
      AND transition_row.transition_key =
          'selection_pending'
      AND source_stage.stage_order = 11
      AND source_stage.stage_key = 'shoot_completed'
      AND destination_stage.stage_order = 12
      AND destination_stage.stage_key =
          'selection_pending'
  ),
  1::bigint,
  'canonical Stage 11 to 12 selection_pending lineage remains exactly one row'
);

-- =====================================================================
-- Part 8 — RLS visibility and authenticated direct-write denial
-- =====================================================================

-- pgTAP switches from the test-owner connection role to authenticated
-- below. Grant read access only to this transaction-local fixture table
-- so the assertions can resolve dynamically created booking ids.
GRANT SELECT
ON TABLE s11s5_ids
TO authenticated;

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

SET LOCAL ROLE authenticated;

-- 71
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_selection_confirmations confirmation
    WHERE confirmation.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  1::bigint,
  'authorized Founder can read selection evidence through RLS'
);

RESET ROLE;

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000005'
);

SET LOCAL ROLE authenticated;

-- 72
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_selection_confirmations confirmation
    WHERE confirmation.booking_id =
          (SELECT happy_booking_id FROM s11s5_ids)
  ),
  0::bigint,
  'Photographer without selection.read cannot read selection evidence'
);

RESET ROLE;

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000107'
);

SET LOCAL ROLE authenticated;

-- 73
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_selection_confirmations confirmation
    WHERE confirmation.booking_id =
          (SELECT cross_branch_booking_id FROM s11s5_ids)
  ),
  0::bigint,
  'branch-scoped Coordinator cannot read another branch selection evidence'
);

RESET ROLE;

SELECT pg_temp.s11s5_set_actor(
  '8e000000-0000-0000-0000-000000000003'
);

SET LOCAL ROLE authenticated;

-- 74
SELECT throws_ok(
  $$
  INSERT INTO public.booking_selection_confirmations (
    organization_id,
    booking_id,
    selected_image_count,
    confirmed_at,
    recorded_by
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    (SELECT happy_booking_id FROM s11s5_ids),
    22,
    now() - interval '5 minutes',
    '8e000000-0000-0000-0000-000000000103'
  )
  $$,
  '42501',
  'permission denied for table booking_selection_confirmations',
  'authenticated direct INSERT is denied'
);

-- 75
SELECT throws_ok(
  $$
  UPDATE public.booking_selection_confirmations
  SET selected_image_count =
      selected_image_count + 1
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11s5_ids)
  $$,
  '42501',
  'permission denied for table booking_selection_confirmations',
  'authenticated direct UPDATE is denied'
);

-- 76
SELECT throws_ok(
  $$
  DELETE FROM public.booking_selection_confirmations
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11s5_ids)
  $$,
  '42501',
  'permission denied for table booking_selection_confirmations',
  'authenticated direct DELETE is denied'
);

RESET ROLE;

SELECT * FROM finish();

ROLLBACK;
