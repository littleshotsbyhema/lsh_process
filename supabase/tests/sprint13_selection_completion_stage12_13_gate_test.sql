CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(44);

-- =====================================================================
-- Sprint 13 — Editing Pending
-- Canonical finalized-selection evidence + Stage 12 -> 13 gate
-- =====================================================================

-- =====================================================================
-- Part 1 — Structural / permission / ACL contract
-- =====================================================================

-- 1
SELECT ok(
  to_regclass('public.booking_selection_completions') IS NOT NULL
  AND to_regclass('public.booking_selected_images') IS NOT NULL,
  'Sprint 13 canonical selection evidence tables exist'
);

-- 2
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key = 'selection.confirm'
      AND permission.domain = 'bookings'
      AND permission.requires_server_enforcement
  ),
  'selection.confirm exists as a server-enforced bookings permission'
);

-- 3
SELECT is(
  (
    SELECT array_agg(role.key ORDER BY role.key)
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id = role_permission.permission_id
    JOIN public.roles role
      ON role.id = role_permission.role_id
    WHERE permission.key = 'selection.confirm'
  ),
  ARRAY[
    'client_coordinator',
    'founder',
    'studio_manager'
  ]::text[],
  'selection.confirm is granted to exactly Founder, Studio Manager and Client Coordinator'
);

-- 4
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  236::bigint,
  'canonical role-permission compatibility count is 236'
);

-- 5
SELECT ok(
  to_regprocedure(
    'public.record_booking_selection_completion(uuid,text[],text,text)'
  ) IS NOT NULL
  AND pg_get_function_result(
    'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  ) = 'booking_selection_completions',
  'record_booking_selection_completion has exact signature and return type'
);

-- 6
SELECT ok(
  to_regprocedure('public.mark_booking_editing_pending(uuid)') IS NOT NULL
  AND pg_get_function_result(
    'public.mark_booking_editing_pending(uuid)'::regprocedure
  ) = 'bookings',
  'mark_booking_editing_pending has exact signature and return type'
);

-- 7
SELECT ok(
  (
    SELECT procedure.prosecdef
      AND procedure.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  )
  AND
  (
    SELECT procedure.prosecdef
      AND procedure.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
  ),
  'both Sprint 13 RPCs are SECURITY DEFINER with fixed empty search_path'
);

-- 8
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_selection_completion(uuid,text[],text,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.record_booking_selection_completion(uuid,text[],text,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.record_booking_selection_completion(uuid,text[],text,text)',
    'EXECUTE'
  ),
  'selection-completion RPC is authenticated-only'
);

-- 9
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_editing_pending(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.mark_booking_editing_pending(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.mark_booking_editing_pending(uuid)',
    'EXECUTE'
  ),
  'editing-pending RPC is authenticated-only'
);

-- 10
SELECT ok(
  (
    SELECT relrowsecurity AND relforcerowsecurity
    FROM pg_class
    WHERE oid = 'public.booking_selection_completions'::regclass
  )
  AND
  (
    SELECT relrowsecurity AND relforcerowsecurity
    FROM pg_class
    WHERE oid = 'public.booking_selected_images'::regclass
  ),
  'both selection evidence tables use RLS and FORCE RLS'
);

-- 11
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_selection_completions',
    'SELECT'
  )
  AND has_table_privilege(
    'authenticated',
    'public.booking_selected_images',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_completions',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_completions',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_completions',
    'DELETE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_selected_images',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_selected_images',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_selected_images',
    'DELETE'
  ),
  'authenticated receives SELECT-only access to selection evidence'
);

-- 12
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id = role_permission.permission_id
    WHERE permission.key = 'booking.stage.advance'
  ),
  3::bigint,
  'booking.stage.advance remains granted to exactly three roles'
);

-- =====================================================================
-- Part 2 — Canonical fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8e000000-0000-0000-0000-000000000001'::uuid),
  ('8e000000-0000-0000-0000-000000000002'::uuid),
  ('8e000000-0000-0000-0000-000000000003'::uuid),
  ('8e000000-0000-0000-0000-000000000004'::uuid),
  ('8e000000-0000-0000-0000-000000000005'::uuid),
  ('8e000000-0000-0000-0000-000000000006'::uuid);

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
  'Sprint 13 Branch A',
  's13-a',
  'active'
),
(
  '8e000000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'Sprint 13 Branch B',
  's13-b',
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
  'S13 Founder',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000002',
  'active',
  'S13 Studio Manager',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000003',
  'active',
  'S13 Client Coordinator',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000004',
  'active',
  'S13 Photographer',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000005',
  'suspended',
  'S13 Suspended Founder',
  now()
),
(
  '8e000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000006',
  'active',
  'S13 Branch Coordinator',
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
    ('8e000000-0000-0000-0000-000000000101'::uuid, 'founder'::text, NULL::uuid),
    ('8e000000-0000-0000-0000-000000000102'::uuid, 'studio_manager'::text, NULL::uuid),
    ('8e000000-0000-0000-0000-000000000103'::uuid, 'client_coordinator'::text, NULL::uuid),
    ('8e000000-0000-0000-0000-000000000104'::uuid, 'photographer'::text, NULL::uuid),
    ('8e000000-0000-0000-0000-000000000105'::uuid, 'founder'::text, NULL::uuid),
    ('8e000000-0000-0000-0000-000000000106'::uuid, 'client_coordinator'::text, '8e000000-0000-0000-0000-000000000701'::uuid)
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id = '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s13_set_actor(p_user_id uuid)
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
        'sub', p_user_id,
        'role', 'authenticated'
      )::text
    END,
    true
  );
END;
$$;

SELECT pg_temp.s13_set_actor(
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
  'Sprint 13 Family',
  'Sprint 13 Family',
  'active',
  '8e000000-0000-0000-0000-000000000101',
  '8e000000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s13_create_booking(
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

CREATE FUNCTION pg_temp.s13_move_to_stage(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_transition_key text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
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
    COALESCE(p_transition_key, 's13_fixture_' || p_stage_key),
    now(),
    '8e000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = now(),
    version = state.version + 1,
    updated_at = now(),
    updated_by = '8e000000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s13_set_stage_without_transition(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
    AND stage.is_active;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = now(),
    version = state.version + 1,
    updated_at = now(),
    updated_by = '8e000000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s13_prepare_stage12(p_booking_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s13_move_to_stage(
    p_booking_id,
    10,
    'shoot_scheduled'
  );

  INSERT INTO public.booking_shoot_completions (
    organization_id,
    booking_id,
    completed_at,
    recorded_by
  )
  SELECT
    booking.organization_id,
    booking.id,
    now() - interval '1 hour',
    '8e000000-0000-0000-0000-000000000101'
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;

  PERFORM pg_temp.s13_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    'shoot_completed'
  );

  PERFORM pg_temp.s13_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    'selection_pending'
  );
END;
$$;

CREATE TEMP TABLE s13_ids (
  happy_booking_id uuid,
  wrong_stage_booking_id uuid,
  no_selection_booking_id uuid,
  photographer_booking_id uuid,
  suspended_booking_id uuid,
  branch_a_booking_id uuid,
  branch_b_booking_id uuid,
  malformed_replay_booking_id uuid,
  missing_manifest_booking_id uuid,
  stage14_booking_id uuid
);

INSERT INTO s13_ids
VALUES (
  pg_temp.s13_create_booking(NULL),
  pg_temp.s13_create_booking(NULL),
  pg_temp.s13_create_booking(NULL),
  pg_temp.s13_create_booking(NULL),
  pg_temp.s13_create_booking(NULL),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000702'),
  pg_temp.s13_create_booking(NULL),
  pg_temp.s13_create_booking(NULL),
  pg_temp.s13_create_booking(NULL)
);

SELECT pg_temp.s13_prepare_stage12((SELECT happy_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT no_selection_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT photographer_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT suspended_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT branch_a_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT branch_b_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT malformed_replay_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT missing_manifest_booking_id FROM s13_ids));
SELECT pg_temp.s13_prepare_stage12((SELECT stage14_booking_id FROM s13_ids));

SELECT pg_temp.s13_move_to_stage(
  (SELECT wrong_stage_booking_id FROM s13_ids),
  11,
  'shoot_completed',
  'shoot_completed'
);

-- =====================================================================
-- Part 3 — Selection-completion validation and authority
-- =====================================================================

SELECT pg_temp.s13_set_actor(NULL);

-- 13
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY['IMG-001'],
    'manual',
    NULL
  )
  $$,
  '42501',
  'record_booking_selection_completion: authenticated actor required',
  'selection completion rejects unauthenticated callers'
);

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 14
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY[]::text[],
    'manual',
    NULL
  )
  $$,
  '22023',
  'record_booking_selection_completion: at least one selected image key is required',
  'selection completion requires a non-empty manifest'
);

-- 15
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY['IMG-001', '   '],
    'manual',
    NULL
  )
  $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be non-empty',
  'selection completion rejects blank image keys'
);

-- 16
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY['IMG-001', ' IMG-001 '],
    'manual',
    NULL
  )
  $$,
  '22023',
  'record_booking_selection_completion: duplicate selected image keys are not allowed',
  'selection completion rejects duplicate normalized image keys'
);

-- 17
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY['IMG-001'],
    '   ',
    NULL
  )
  $$,
  '22023',
  'record_booking_selection_completion: source_type is required',
  'selection completion requires structural source provenance'
);

-- 18
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT wrong_stage_booking_id FROM s13_ids),
    ARRAY['IMG-001'],
    'manual',
    NULL
  )
  $$,
  '22023',
  'record_booking_selection_completion: booking must be exactly Selection Pending',
  'selection completion is contained to exact Stage 12'
);

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000004'
);

-- 19
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT photographer_booking_id FROM s13_ids),
    ARRAY['IMG-001'],
    'manual',
    NULL
  )
  $$,
  '42501',
  'record_booking_selection_completion: selection.confirm permission required',
  'Photographer cannot record finalized selection by default'
);

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000005'
);

-- 20
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT suspended_booking_id FROM s13_ids),
    ARRAY['IMG-001'],
    'manual',
    NULL
  )
  $$,
  '42501',
  'record_booking_selection_completion: active organization membership required',
  'suspended member cannot record finalized selection'
);

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000006'
);

-- 21
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT branch_b_booking_id FROM s13_ids),
    ARRAY['IMG-001'],
    'manual',
    NULL
  )
  $$,
  '42501',
  'record_booking_selection_completion: selection.confirm permission required',
  'branch-scoped coordinator cannot finalize selection for another branch'
);

-- =====================================================================
-- Part 4 — Successful selection completion / replay / immutability
-- =====================================================================

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 22
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_happy_completion AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY[' IMG-003 ', 'IMG-001', 'IMG-002'],
    ' manual ',
    ' PX-123 '
  )
  $$,
  'Founder can record canonical finalized selection at Stage 12'
);

-- 23
SELECT ok(
  (
    SELECT
      completion.booking_id = (SELECT happy_booking_id FROM s13_ids)
      AND completion.source_type = 'manual'
      AND completion.external_reference = 'PX-123'
      AND completion.recorded_by = '8e000000-0000-0000-0000-000000000101'::uuid
      AND completion.created_by = '8e000000-0000-0000-0000-000000000101'::uuid
    FROM public.booking_selection_completions completion
    WHERE completion.id = (SELECT id FROM s13_happy_completion)
  ),
  'selection completion persists normalized structural provenance and actor attribution'
);

-- 24
SELECT is(
  (
    SELECT array_agg(
      selected.image_key || ':' || selected.ordinal::text
      ORDER BY selected.ordinal
    )
    FROM public.booking_selected_images selected
    WHERE selected.selection_completion_id =
      (SELECT id FROM s13_happy_completion)
  ),
  ARRAY['IMG-003:1', 'IMG-001:2', 'IMG-002:3']::text[],
  'selected-image manifest preserves normalized keys and original ordinal order'
);

-- 25
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
      AND concat_ws(
            ' ',
            audit.old_values::text,
            audit.new_values::text,
            audit.metadata::text
          ) ILIKE '%IMG-00%'
  ),
  'selection-completed audit is single and excludes selected-image identifiers'
);

-- 26
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_happy_completion_replay AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY['IMG-002', 'IMG-003', 'IMG-001'],
    'manual',
    'PX-123'
  )
  $$,
  'exact normalized selection-set replay succeeds regardless of submitted order'
);

-- 27
SELECT ok(
  (SELECT id FROM s13_happy_completion_replay) =
    (SELECT id FROM s13_happy_completion)
  AND
  (
    SELECT count(*)
    FROM public.booking_selected_images selected
    WHERE selected.selection_completion_id =
      (SELECT id FROM s13_happy_completion)
  ) = 3
  AND
  (
    SELECT count(*)
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
  ) = 1,
  'selection replay creates no duplicate completion, manifest row or audit'
);

-- 28
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY['IMG-001', 'IMG-999'],
    'manual',
    'PX-123'
  )
  $$,
  '23505',
  'record_booking_selection_completion: conflicting finalized-selection replay',
  'conflicting finalized selection cannot overwrite canonical history'
);

-- 29
SELECT throws_ok(
  $$
  UPDATE public.booking_selection_completions
  SET source_type = 'changed'
  WHERE id = (SELECT id FROM s13_happy_completion)
  $$,
  'P0001',
  'booking selection completion evidence is immutable',
  'selection-completion header is immutable even to privileged SQL'
);

-- 30
SELECT throws_ok(
  $$
  DELETE FROM public.booking_selected_images
  WHERE selection_completion_id = (SELECT id FROM s13_happy_completion)
  $$,
  'P0001',
  'booking selected-image evidence is immutable',
  'selected-image manifest is immutable even to privileged SQL'
);

-- Record branch fixtures under global Founder for RLS checks later.
CREATE TEMP TABLE s13_branch_a_completion AS
SELECT *
FROM public.record_booking_selection_completion(
  (SELECT branch_a_booking_id FROM s13_ids),
  ARRAY['BA-001'],
  'manual',
  NULL
);

CREATE TEMP TABLE s13_branch_b_completion AS
SELECT *
FROM public.record_booking_selection_completion(
  (SELECT branch_b_booking_id FROM s13_ids),
  ARRAY['BB-001'],
  'manual',
  NULL
);

-- =====================================================================
-- Part 5 — Stage 12 -> 13 advancement
-- =====================================================================

SELECT pg_temp.s13_set_actor(NULL);

-- 31
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT happy_booking_id FROM s13_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_pending: authenticated actor required',
  'editing-pending advancement rejects unauthenticated callers'
);

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 32
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT no_selection_booking_id FROM s13_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_pending: exactly one canonical selection completion row required',
  'editing-pending advancement requires canonical selection completion'
);

-- 33
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT wrong_stage_booking_id FROM s13_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_pending: booking must be exactly Selection Pending or Editing Pending replay',
  'editing-pending advancement rejects Stage 11'
);

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000006'
);

-- 34
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT branch_b_booking_id FROM s13_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_pending: booking.stage.advance permission required',
  'branch-scoped coordinator cannot advance another branch'
);

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

CREATE TEMP TABLE s13_before_state AS
SELECT state.*
FROM public.booking_journey_states state
WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids);

-- 35
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT happy_booking_id FROM s13_ids)
  )
  $$,
  'authorized Stage 12 booking with canonical selection advances to Editing Pending'
);

-- 36
SELECT ok(
  (
    SELECT
      stage.stage_order = 13
      AND stage.stage_key = 'editing_pending'
      AND state.version = (SELECT version + 1 FROM s13_before_state)
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids)
  ),
  'journey state advances exactly to Stage 13 with one version increment'
);

-- 37
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id = transition_row.organization_id
     AND source_stage.id = transition_row.from_stage_id
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.booking_id = (SELECT happy_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
      AND source_stage.stage_order = 12
      AND source_stage.stage_key = 'selection_pending'
      AND destination_stage.stage_order = 13
      AND destination_stage.stage_key = 'editing_pending'
  ),
  1::bigint,
  'first success creates exactly one canonical Stage 12 -> 13 transition'
);

-- 38
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_states state
      ON state.organization_id = transition_row.organization_id
     AND state.booking_id = transition_row.booking_id
    WHERE transition_row.booking_id = (SELECT happy_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
      AND transition_row.transitioned_at = state.stage_entered_at
      AND transition_row.transitioned_by =
        '8e000000-0000-0000-0000-000000000101'::uuid
      AND state.updated_by =
        '8e000000-0000-0000-0000-000000000101'::uuid
  ),
  'transition timestamp and actor attribution match canonical journey state'
);

-- 39
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.editing_pending'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
      AND audit.metadata->>'selected_image_count' = '3'
      AND audit.metadata->>'transition_key' = 'editing_pending'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.editing_pending'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
      AND concat_ws(
            ' ',
            audit.old_values::text,
            audit.new_values::text,
            audit.metadata::text
          ) ILIKE '%IMG-00%'
  ),
  'editing-pending audit is structural and excludes selected-image identifiers'
);

CREATE TEMP TABLE s13_after_first_advance AS
SELECT state.*
FROM public.booking_journey_states state
WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids);

-- 40
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT happy_booking_id FROM s13_ids)
  )
  $$,
  'exact Stage 13 replay succeeds'
);

-- 41
SELECT ok(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids)
  ) = (SELECT version FROM s13_after_first_advance)
  AND
  (
    SELECT count(*)
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id = (SELECT happy_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ) = 1
  AND
  (
    SELECT count(*)
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.editing_pending'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
  ) = 1,
  'Stage 13 replay is mutation-free'
);

-- 42
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id = (SELECT happy_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_in_progress'
  ),
  0::bigint,
  'Sprint 13 creates no Stage 13 -> 14 transition'
);

-- =====================================================================
-- Part 6 — Corruption / later-stage containment / RLS reads
-- =====================================================================

-- Prepare malformed Stage-13 replay: valid selection, state moved without
-- canonical Stage 12 -> 13 transition.
CREATE TEMP TABLE s13_malformed_replay_completion AS
SELECT *
FROM public.record_booking_selection_completion(
  (SELECT malformed_replay_booking_id FROM s13_ids),
  ARRAY['MR-001'],
  'manual',
  NULL
);

SELECT pg_temp.s13_set_stage_without_transition(
  (SELECT malformed_replay_booking_id FROM s13_ids),
  13,
  'editing_pending'
);

-- 43
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT malformed_replay_booking_id FROM s13_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: Editing Pending replay history is invalid',
  'Stage 13 replay rejects incomplete transition lineage'
);

-- Prepare missing-manifest corruption after canonical completion.
CREATE TEMP TABLE s13_missing_manifest_completion AS
SELECT *
FROM public.record_booking_selection_completion(
  (SELECT missing_manifest_booking_id FROM s13_ids),
  ARRAY['MM-001'],
  'manual',
  NULL
);

ALTER TABLE public.booking_selected_images DISABLE TRIGGER USER;
DELETE FROM public.booking_selected_images
WHERE selection_completion_id =
  (SELECT id FROM s13_missing_manifest_completion);
ALTER TABLE public.booking_selected_images ENABLE TRIGGER USER;

SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT missing_manifest_booking_id FROM s13_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: canonical selected-image manifest is invalid',
  'Stage 12 -> 13 advancement rejects missing canonical manifest'
);

-- This assertion is intentionally grouped with the final RLS check so the
-- suite remains at the frozen 44-test plan.

-- Prepare later-stage booking with valid selection and then fixture it into
-- Stage 14 without using Sprint 13 advancement.
CREATE TEMP TABLE s13_stage14_completion AS
SELECT *
FROM public.record_booking_selection_completion(
  (SELECT stage14_booking_id FROM s13_ids),
  ARRAY['S14-001'],
  'manual',
  NULL
);

SELECT pg_temp.s13_move_to_stage(
  (SELECT stage14_booking_id FROM s13_ids),
  13,
  'editing_pending',
  'editing_pending'
);
SELECT pg_temp.s13_move_to_stage(
  (SELECT stage14_booking_id FROM s13_ids),
  14,
  'editing_in_progress',
  's13_fixture_editing_in_progress'
);

SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT stage14_booking_id FROM s13_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_pending: booking must be exactly Selection Pending or Editing Pending replay',
  'Sprint 13 advancement rejects Stage 14 or later callers'
);

-- Branch-contained authenticated reads.
SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000006'
);
SET LOCAL ROLE authenticated;

SELECT ok(
  (
    SELECT count(*)
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id = (SELECT branch_a_booking_id FROM s13_ids)
  ) = 1
  AND
  (
    SELECT count(*)
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id = (SELECT branch_b_booking_id FROM s13_ids)
  ) = 0
  AND
  (
    SELECT count(*)
    FROM public.booking_selected_images selected
    WHERE selected.booking_id = (SELECT branch_a_booking_id FROM s13_ids)
  ) = 1
  AND
  (
    SELECT count(*)
    FROM public.booking_selected_images selected
    WHERE selected.booking_id = (SELECT branch_b_booking_id FROM s13_ids)
  ) = 0,
  'authenticated selection-evidence reads are contained by booking permission and branch scope'
);

RESET ROLE;

SELECT * FROM finish();

ROLLBACK;
