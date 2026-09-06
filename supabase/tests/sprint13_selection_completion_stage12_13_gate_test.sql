CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(98);

-- =====================================================================
-- Sprint 13 — Editing Pending
-- Canonical finalized-selection evidence + Stage 12 -> 13 gate
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
  ARRAY['client_coordinator','founder','studio_manager']::text[],
  'selection.confirm role boundary is exact'
);

-- 4
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  261::bigint,
  'canonical role-permission compatibility count is 261'
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
  has_table_privilege('authenticated','public.booking_selection_completions','SELECT')
  AND has_table_privilege('authenticated','public.booking_selected_images','SELECT')
  AND NOT has_table_privilege('authenticated','public.booking_selection_completions','INSERT')
  AND NOT has_table_privilege('authenticated','public.booking_selection_completions','UPDATE')
  AND NOT has_table_privilege('authenticated','public.booking_selection_completions','DELETE')
  AND NOT has_table_privilege('authenticated','public.booking_selected_images','INSERT')
  AND NOT has_table_privilege('authenticated','public.booking_selected_images','UPDATE')
  AND NOT has_table_privilege('authenticated','public.booking_selected_images','DELETE'),
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
-- Canonical fixture identities
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
('8e000000-0000-0000-0000-000000000701','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','Sprint 13 Branch A','s13-a','active'),
('8e000000-0000-0000-0000-000000000702','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','Sprint 13 Branch B','s13-b','active');

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  suspended_at
)
VALUES
('8e000000-0000-0000-0000-000000000101','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','8e000000-0000-0000-0000-000000000001','active','S13 Founder',NULL),
('8e000000-0000-0000-0000-000000000102','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','8e000000-0000-0000-0000-000000000002','active','S13 Studio Manager',NULL),
('8e000000-0000-0000-0000-000000000103','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','8e000000-0000-0000-0000-000000000003','active','S13 Client Coordinator',NULL),
('8e000000-0000-0000-0000-000000000104','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','8e000000-0000-0000-0000-000000000004','active','S13 Photographer',NULL),
('8e000000-0000-0000-0000-000000000105','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','8e000000-0000-0000-0000-000000000005','suspended','S13 Suspended Founder',now()),
('8e000000-0000-0000-0000-000000000106','590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','8e000000-0000-0000-0000-000000000006','active','S13 Branch Coordinator',NULL);

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
    ('8e000000-0000-0000-0000-000000000101'::uuid,'founder'::text,NULL::uuid),
    ('8e000000-0000-0000-0000-000000000102'::uuid,'studio_manager'::text,'8e000000-0000-0000-0000-000000000701'::uuid),
    ('8e000000-0000-0000-0000-000000000103'::uuid,'client_coordinator'::text,'8e000000-0000-0000-0000-000000000701'::uuid),
    ('8e000000-0000-0000-0000-000000000104'::uuid,'photographer'::text,'8e000000-0000-0000-0000-000000000701'::uuid),
    ('8e000000-0000-0000-0000-000000000105'::uuid,'founder'::text,NULL::uuid),
    ('8e000000-0000-0000-0000-000000000106'::uuid,'client_coordinator'::text,'8e000000-0000-0000-0000-000000000701'::uuid)
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
  PERFORM set_config('request.jwt.claim.sub',COALESCE(p_user_id::text,''),true);
  PERFORM set_config(
    'request.jwt.claims',
    CASE
      WHEN p_user_id IS NULL THEN '{}'
      ELSE jsonb_build_object('sub',p_user_id,'role','authenticated')::text
    END,
    true
  );
END;
$$;

SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000001');

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

CREATE FUNCTION pg_temp.s13_create_booking(p_branch_id uuid DEFAULT NULL)
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

  PERFORM public.add_quotation_package_line(v_quote.id,v_package_version_id,NULL);
  PERFORM public.transition_quotation(v_quote.id,'ready'::public.quotation_status);
  PERFORM public.transition_quotation(v_quote.id,'sent'::public.quotation_status);

  SELECT * INTO v_booking
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
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.* INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
    AND stage.is_active;

  INSERT INTO public.booking_stage_transitions (
    organization_id,booking_id,from_stage_id,to_stage_id,
    transition_key,transitioned_at,transitioned_by
  )
  VALUES (
    v_state.organization_id,v_state.booking_id,v_state.current_stage_id,v_target.id,
    COALESCE(p_transition_key,'s13_fixture_' || p_stage_key),now(),
    '8e000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET current_stage_id = v_target.id,
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
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.* INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
    AND stage.is_active;

  UPDATE public.booking_journey_states state
  SET current_stage_id = v_target.id,
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
  PERFORM pg_temp.s13_move_to_stage(p_booking_id,10,'shoot_scheduled');

  INSERT INTO public.booking_shoot_completions (
    organization_id,booking_id,completed_at,recorded_by
  )
  SELECT booking.organization_id,booking.id,now() - interval '1 hour',
         '8e000000-0000-0000-0000-000000000101'
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;

  PERFORM pg_temp.s13_move_to_stage(p_booking_id,11,'shoot_completed','shoot_completed');
  PERFORM pg_temp.s13_move_to_stage(p_booking_id,12,'selection_pending','selection_pending');
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
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000702'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701'),
  pg_temp.s13_create_booking('8e000000-0000-0000-0000-000000000701')
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
SELECT pg_temp.s13_move_to_stage((SELECT wrong_stage_booking_id FROM s13_ids),11,'shoot_completed','shoot_completed');

-- 13
SELECT pg_temp.s13_set_actor(NULL);
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT happy_booking_id FROM s13_ids),ARRAY['IMG-001'],'manual',NULL) $$,
  '42501','record_booking_selection_completion: authenticated actor required',
  'selection completion rejects unauthenticated callers'
);

SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000001');

-- 14
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT happy_booking_id FROM s13_ids),ARRAY[]::text[],'manual',NULL) $$,
  '22023','record_booking_selection_completion: at least one selected image key is required',
  'selection completion requires a non-empty manifest'
);

-- 15
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT happy_booking_id FROM s13_ids),ARRAY['IMG-001',' IMG-001 '],'manual',NULL) $$,
  '22023','record_booking_selection_completion: duplicate selected image keys are not allowed',
  'selection completion rejects duplicate normalized image keys'
);

-- 16
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT wrong_stage_booking_id FROM s13_ids),ARRAY['IMG-001'],'manual',NULL) $$,
  '22023','record_booking_selection_completion: booking must be exactly Selection Pending',
  'selection completion is contained to exact Stage 12'
);

-- 17
SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000004');
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT photographer_booking_id FROM s13_ids),ARRAY['IMG-001'],'manual',NULL) $$,
  '42501','record_booking_selection_completion: selection.confirm permission required',
  'Photographer cannot record finalized selection by default'
);

-- 18
SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000005');
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT suspended_booking_id FROM s13_ids),ARRAY['IMG-001'],'manual',NULL) $$,
  '42501','record_booking_selection_completion: active organization membership required',
  'suspended member cannot record finalized selection'
);

-- 19
SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000006');
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT branch_b_booking_id FROM s13_ids),ARRAY['IMG-001'],'manual',NULL) $$,
  '42501','record_booking_selection_completion: selection.confirm permission required',
  'branch-scoped coordinator cannot finalize selection for another branch'
);

SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000001');

-- 20
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_happy_completion AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY[' IMG-003 ','IMG-001','IMG-002'],
    ' manual ',
    ' PX-123 '
  )
  $$,
  'Founder can record canonical finalized selection at Stage 12'
);

-- 21
SELECT ok(
  (
    SELECT completion.source_type = 'manual'
      AND completion.external_reference = 'PX-123'
      AND completion.recorded_by = '8e000000-0000-0000-0000-000000000101'::uuid
      AND completion.created_by = '8e000000-0000-0000-0000-000000000101'::uuid
    FROM public.booking_selection_completions completion
    WHERE completion.id = (SELECT id FROM s13_happy_completion)
  )
  AND
  (
    SELECT array_agg(selected.image_key || ':' || selected.ordinal::text ORDER BY selected.ordinal)
    FROM public.booking_selected_images selected
    WHERE selected.selection_completion_id = (SELECT id FROM s13_happy_completion)
  ) = ARRAY['IMG-003:1','IMG-001:2','IMG-002:3']::text[],
  'selection completion stores normalized provenance and immutable manifest order'
);

-- 22
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
      AND concat_ws(' ',audit.old_values::text,audit.new_values::text,audit.metadata::text) ILIKE '%IMG-00%'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
      AND audit.metadata ? 'source_type'
  ),
  'selection-completed audit is single and excludes image identifiers and source type'
);

-- 23
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_happy_completion_replay AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT happy_booking_id FROM s13_ids),
    ARRAY['IMG-002','IMG-003','IMG-001'],
    'manual',
    'PX-123'
  )
  $$,
  'exact normalized selection-set replay succeeds'
);

-- 24
SELECT ok(
  (SELECT id FROM s13_happy_completion_replay) = (SELECT id FROM s13_happy_completion)
  AND (
    SELECT count(*) FROM public.booking_selected_images selected
    WHERE selected.selection_completion_id = (SELECT id FROM s13_happy_completion)
  ) = 3
  AND (
    SELECT count(*) FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
  ) = 1,
  'selection replay is mutation-free'
);

-- 25
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion((SELECT happy_booking_id FROM s13_ids),ARRAY['IMG-001','IMG-999'],'manual','PX-123') $$,
  '23505','record_booking_selection_completion: conflicting finalized-selection replay',
  'conflicting finalized selection cannot overwrite history'
);

-- 26
SELECT throws_ok(
  $$ UPDATE public.booking_selection_completions SET source_type = 'changed' WHERE id = (SELECT id FROM s13_happy_completion) $$,
  'P0001','booking selection completion evidence is immutable',
  'selection-completion header is immutable'
);

-- 27
SELECT throws_ok(
  $$ DELETE FROM public.booking_selected_images WHERE selection_completion_id = (SELECT id FROM s13_happy_completion) $$,
  'P0001','booking selected-image evidence is immutable',
  'selected-image manifest is immutable'
);

CREATE TEMP TABLE s13_branch_a_completion AS
SELECT * FROM public.record_booking_selection_completion((SELECT branch_a_booking_id FROM s13_ids),ARRAY['BA-001'],'manual',NULL);
CREATE TEMP TABLE s13_branch_b_completion AS
SELECT * FROM public.record_booking_selection_completion((SELECT branch_b_booking_id FROM s13_ids),ARRAY['BB-001'],'manual',NULL);

-- 28
SELECT pg_temp.s13_set_actor(NULL);
SELECT throws_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT happy_booking_id FROM s13_ids)) $$,
  '42501','mark_booking_editing_pending: authenticated actor required',
  'editing-pending advancement rejects unauthenticated callers'
);

SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000001');

-- 29
SELECT throws_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT no_selection_booking_id FROM s13_ids)) $$,
  '22023','mark_booking_editing_pending: exactly one canonical selection completion row required',
  'editing-pending advancement requires canonical selection completion'
);

-- 30
SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000006');
SELECT throws_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT branch_b_booking_id FROM s13_ids)) $$,
  '42501','mark_booking_editing_pending: booking.stage.advance permission required',
  'branch-scoped coordinator cannot advance another branch'
);

SELECT pg_temp.s13_set_actor('8e000000-0000-0000-0000-000000000001');
CREATE TEMP TABLE s13_before_state AS
SELECT state.* FROM public.booking_journey_states state
WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids);

-- 31
SELECT lives_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT happy_booking_id FROM s13_ids)) $$,
  'valid Stage 12 booking advances to Editing Pending'
);

-- 32
SELECT ok(
  (
    SELECT stage.stage_order = 13
      AND stage.stage_key = 'editing_pending'
      AND state.version = (SELECT version + 1 FROM s13_before_state)
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids)
  ),
  'journey advances exactly to Stage 13 with one version increment'
);

-- 33
SELECT ok(
  (
    SELECT count(*) = 1
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
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.editing_pending'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
      AND audit.metadata->>'selected_image_count' = '3'
  ),
  'first Stage 12 -> 13 success creates one transition and one structural audit'
);

CREATE TEMP TABLE s13_after_first_advance AS
SELECT state.* FROM public.booking_journey_states state
WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids);

-- 34
SELECT lives_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT happy_booking_id FROM s13_ids)) $$,
  'exact Stage 13 replay succeeds'
);

-- 35
SELECT ok(
  (
    SELECT state.version FROM public.booking_journey_states state
    WHERE state.booking_id = (SELECT happy_booking_id FROM s13_ids)
  ) = (SELECT version FROM s13_after_first_advance)
  AND (
    SELECT count(*) FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id = (SELECT happy_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ) = 1
  AND (
    SELECT count(*) FROM public.audit_events audit
    WHERE audit.action_key = 'booking.editing_pending'
      AND audit.entity_id = (SELECT happy_booking_id FROM s13_ids)
  ) = 1,
  'Stage 13 replay is mutation-free'
);

-- 36
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

CREATE TEMP TABLE s13_malformed_replay_completion AS
SELECT * FROM public.record_booking_selection_completion((SELECT malformed_replay_booking_id FROM s13_ids),ARRAY['MR-001'],'manual',NULL);
SELECT pg_temp.s13_set_stage_without_transition((SELECT malformed_replay_booking_id FROM s13_ids),13,'editing_pending');

-- 37
SELECT throws_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT malformed_replay_booking_id FROM s13_ids)) $$,
  'P0001','mark_booking_editing_pending: Editing Pending replay history is invalid',
  'Stage 13 replay rejects incomplete transition lineage'
);

CREATE TEMP TABLE s13_missing_manifest_completion AS
SELECT * FROM public.record_booking_selection_completion((SELECT missing_manifest_booking_id FROM s13_ids),ARRAY['MM-001'],'manual',NULL);
ALTER TABLE public.booking_selected_images DISABLE TRIGGER USER;
DELETE FROM public.booking_selected_images
WHERE selection_completion_id = (SELECT id FROM s13_missing_manifest_completion);
ALTER TABLE public.booking_selected_images ENABLE TRIGGER USER;

-- 38
SELECT throws_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT missing_manifest_booking_id FROM s13_ids)) $$,
  'P0001','mark_booking_editing_pending: canonical selected-image manifest is invalid',
  'Stage 12 -> 13 advancement rejects missing canonical manifest'
);

CREATE TEMP TABLE s13_stage14_completion AS
SELECT * FROM public.record_booking_selection_completion((SELECT stage14_booking_id FROM s13_ids),ARRAY['S14-001'],'manual',NULL);
SELECT pg_temp.s13_move_to_stage((SELECT stage14_booking_id FROM s13_ids),13,'editing_pending','editing_pending');
SELECT pg_temp.s13_move_to_stage((SELECT stage14_booking_id FROM s13_ids),14,'editing_in_progress','s13_fixture_editing_in_progress');

-- 39
SELECT throws_ok(
  $$ SELECT public.mark_booking_editing_pending((SELECT stage14_booking_id FROM s13_ids)) $$,
  '22023','mark_booking_editing_pending: booking must be exactly Selection Pending or Editing Pending replay',
  'Sprint 13 advancement rejects Stage 14 or later callers'
);

-- 40
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY['https://gallery.example/image/1?token=signed-value'],
       'manual',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects URL-shaped image keys'
);

-- 41
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY['sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'],
       'manual',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects credential-shaped image keys'
);

-- 42
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY[repeat('A',256)],
       'manual',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image key exceeds maximum length of 255',
  'selection completion rejects oversized image keys'
);

-- 43
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY(
         SELECT 'IMG-' || lpad(value::text,3,'0')
         FROM generate_series(1,501) AS value
       ),
       'manual',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image manifest exceeds maximum of 500',
  'selection completion rejects oversized manifests before normalization'
);

-- 44
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'invalid finalized-selection input creates no evidence, audit, or journey mutation'
);

-- 45
SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000004'
);
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY(
         SELECT 'IMG-' || lpad(value::text,3,'0')
         FROM generate_series(1,501) AS value
       ),
       'manual',
       NULL
     ) $$,
  '42501',
  'record_booking_selection_completion: selection.confirm permission required',
  'authorization precedes caller-controlled manifest cardinality processing'
);
SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 46
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY['ER-001'],
       'manual',
       'https://gallery.example/client?token=signed-value'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference',
  'selection completion rejects URL-shaped external references'
);

-- 47
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY['ER-001'],
       'manual',
       'PX-123?token=secret-value'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference',
  'selection completion rejects query-shaped external references'
);

-- 48
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY['ER-001'],
       'manual',
       'Bearer ABCDEFGHIJKLMNOPQRSTUVWXYZ'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference',
  'selection completion rejects credential-shaped external references'
);

-- 49
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY['ER-001'],
       'manual',
       E'PX-123\nsecret'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference',
  'selection completion rejects control-character external references'
);

-- 50
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT no_selection_booking_id FROM s13_ids),
       ARRAY['ER-001'],
       'manual',
       repeat('R',256)
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference exceeds maximum length of 255',
  'selection completion rejects oversized external references'
);

-- 51
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT no_selection_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'invalid external references create no evidence, audit, or journey mutation'
);

-- 52
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_null_external_completion AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT no_selection_booking_id FROM s13_ids),
    ARRAY['NULL-ER-001'],
    'manual',
    '   '
  )
  $$,
  'empty external reference remains allowed'
);

-- 53
SELECT ok(
  (
    SELECT completion.external_reference IS NULL
    FROM public.booking_selection_completions completion
    WHERE completion.id =
          (SELECT id FROM s13_null_external_completion)
  ),
  'empty external reference normalizes to NULL'
);

-- 54
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_valid_external_completion AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT photographer_booking_id FROM s13_ids),
    ARRAY['VALID-ER-001'],
    'manual',
    ' EXT-REF-123 '
  )
  $$,
  'bounded provider-neutral opaque external reference succeeds'
);

-- 55
SELECT ok(
  (
    SELECT completion.external_reference = 'EXT-REF-123'
    FROM public.booking_selection_completions completion
    WHERE completion.id =
          (SELECT id FROM s13_valid_external_completion)
  ),
  'valid external reference is trimmed and stored canonically'
);

-- 56
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['s3://bucket/family.jpg'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects non-HTTP URI-shaped image keys'
);

-- 57
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['VALID-ER-001'],
       'manual',
       'github_pat_11AA22BB33CC44DD55EE66FF77GG88HH99'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference',
  'selection completion rejects fine-grained GitHub token external references'
);

-- 58
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selected_images'::regclass
      AND constraint_row.conname =
          'booking_selected_images_image_key_chk'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%image_key !~ ''://''::text%'
  )
  AND EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_completions'::regclass
      AND constraint_row.conname =
          'booking_selection_completions_external_reference_chk'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%github_pat_%'
  ),
  'immutable evidence constraints mirror Amendment 5 URI and credential protections'
);

-- 59
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['github_pat_11AA22BB33CC44DD55EE66FF77GG88HH99'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects fine-grained GitHub token image keys'
);

-- 60
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'invalid fine-grained GitHub token image key creates no evidence, audit, or journey mutation'
);

-- 61
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selected_images'::regclass
      AND constraint_row.conname =
          'booking_selected_images_image_key_chk'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE '%github_pat_%'
  )
  AND position(
    'github_pat_' IN pg_get_functiondef(
      'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
    )
  ) > 0,
  'selected-image constraint and authoritative RPC mirror Amendment 6 credential protection'
);

-- 62
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['VALID-ER-001'],
       repeat('S',65),
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: source_type exceeds maximum length of 64',
  'selection completion rejects oversized source_type'
);

-- 63
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['VALID-ER-001'],
       E'manual\nimport',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: source_type contains control characters',
  'selection completion rejects control-character source_type'
);

-- 64
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_completions'::regclass
      AND constraint_row.conname =
          'booking_selection_completions_source_type_chk'
      AND position(
        'char_length(source_type) <= 64'
        IN pg_get_constraintdef(constraint_row.oid)
      ) > 0
      AND position(
        '[[:cntrl:]]'
        IN pg_get_constraintdef(constraint_row.oid)
      ) > 0
  )
  AND position(
    'source_type exceeds maximum length of 64'
    IN pg_get_functiondef(
      'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
    )
  ) > 0
  AND position(
    'source_type contains control characters'
    IN pg_get_functiondef(
      'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
    )
  ) > 0,
  'source_type table constraint and authoritative RPC mirror Amendment 7 structural bounds'
);

-- 65
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'invalid source_type attempts create no evidence, audit, or journey mutation'
);

-- 66
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['sk_live_1234567890ABCDEF1234567890ABCDEF'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects sk_live_ secret-shaped image keys'
);

-- 67
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['SK_TEST_1234567890ABCDEF1234567890ABCDEF'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects case-insensitive sk_test_ secret-shaped image keys'
);

-- 68
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['VALID-ER-001'],
       'manual',
       'SK_LIVE_1234567890ABCDEF1234567890ABCDEF'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference',
  'selection completion rejects case-insensitive sk_live_ secret-shaped external references'
);

-- 69
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['VALID-ER-001'],
       'manual',
       'sk_test_1234567890ABCDEF1234567890ABCDEF'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference',
  'selection completion rejects sk_test_ secret-shaped external references'
);

-- 70
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selected_images'::regclass
      AND constraint_row.conname =
          'booking_selected_images_image_key_chk'
      AND position(
        'sk_(live|test)_'
        IN pg_get_constraintdef(constraint_row.oid)
      ) > 0
  )
  AND EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_completions'::regclass
      AND constraint_row.conname =
          'booking_selection_completions_external_reference_chk'
      AND position(
        'sk_(live|test)_'
        IN pg_get_constraintdef(constraint_row.oid)
      ) > 0
  )
  AND position(
    'sk_(live|test)_'
    IN pg_get_functiondef(
      'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
    )
  ) > 0,
  'immutable evidence constraints and authoritative RPC mirror Amendment 9 underscore-form secret protection'
);

-- 71
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'underscore-form secret attempts create no evidence, audit, or journey mutation'
);

-- 72
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['Basic dXNlcjpwYXNz'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects Basic authentication selected-image keys'
);

-- 73
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['bAsIc dXNlcjpwYXNz'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects Basic authentication selected-image keys case-insensitively'
);

-- 74
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selected_images'::regclass
      AND constraint_row.conname =
          'booking_selected_images_image_key_chk'
      AND position(
        '(bearer|basic)[[:space:]]+'
        IN pg_get_constraintdef(constraint_row.oid)
      ) > 0
  )
  AND position(
    '(bearer|basic)[[:space:]]+'
    IN pg_get_functiondef(
      'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
    )
  ) > 0,
  'selected-image constraint and authoritative RPC mirror Amendment 10 Basic credential protection'
);

-- 75
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'invalid Basic selected-image credential attempts create no evidence, audit, or journey mutation'
);

-- 76
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['data:image/png;base64,iVBORw0KGgo'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects lowercase data URI selected-image keys'
);

-- 77
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['DATA:text/plain;base64,SGVsbG8'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be opaque operational identifiers',
  'selection completion rejects data URI selected-image keys case-insensitively'
);

-- 78
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY[U&'\00A0'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be non-empty',
  'selection completion rejects NBSP-only selected-image keys'
);

-- 79
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY[U&'\00A0\3000'],
       'manual',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys must be non-empty',
  'selection completion rejects mixed Unicode-whitespace-only selected-image keys'
);

-- 80
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selected_images'::regclass
      AND constraint_row.conname =
          'booking_selected_images_image_key_chk'
      AND position(
        'data:'
        IN pg_get_constraintdef(constraint_row.oid)
      ) > 0
  )
  AND position(
    'data:'
    IN pg_get_functiondef(
      'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
    )
  ) > 0,
  'selected-image constraint and authoritative RPC mirror Amendment 11 data URI protection'
);

-- 81
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selected_images'::regclass
      AND constraint_row.conname =
          'booking_selected_images_image_key_chk'
      AND pg_get_constraintdef(constraint_row.oid) ~
          'btrim\([[:space:]]*image_key[[:space:]]*,'
  )
  AND pg_get_functiondef(
    'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  ) ~
      'btrim\([[:space:]]*value[[:space:]]*,',
  'selected-image constraint and authoritative RPC mirror Amendment 11 explicit Unicode-whitespace protection'
);

-- 82
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'Amendment 11 invalid selected-image attempts create no evidence, audit, or journey mutation'
);


-- =====================================================================
-- Amendment 12 — Sprint 13 closure: Unicode provenance hardening
-- =====================================================================

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 83
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['A12-SRC-001'],
       U&'\00A0',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: source_type is required',
  'selection completion rejects NBSP-only source_type'
);

-- 84
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['A12-SRC-002'],
       U&'\00A0\3000',
       'EXT-REF-123'
     ) $$,
  '22023',
  'record_booking_selection_completion: source_type is required',
  'selection completion rejects mixed Unicode-whitespace-only source_type'
);

CREATE TEMP TABLE s13_a12_ids AS
SELECT pg_temp.s13_create_booking(
  '8e000000-0000-0000-0000-000000000701'::uuid
) AS external_booking_id;

SELECT pg_temp.s13_prepare_stage12(
  (SELECT external_booking_id FROM s13_a12_ids)
);

-- 85
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_a12_external_null AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT external_booking_id FROM s13_a12_ids),
    ARRAY['A12-EXT-001'],
    'manual',
    U&'\00A0'
  )
  $$,
  'NBSP-only external_reference normalizes to NULL'
);

-- 86
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_a12_external_null_replay AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT external_booking_id FROM s13_a12_ids),
    ARRAY['A12-EXT-001'],
    'manual',
    U&'\00A0\3000'
  )
  $$,
  'mixed Unicode-whitespace-only external_reference normalizes to NULL on exact replay'
);

-- 87
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_completions'::regclass
      AND constraint_row.conname =
          'booking_selection_completions_source_type_chk'
      AND pg_get_constraintdef(constraint_row.oid) ~
          'btrim\([[:space:]]*source_type[[:space:]]*,'
  )
  AND EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_completions'::regclass
      AND constraint_row.conname =
          'booking_selection_completions_external_reference_chk'
      AND pg_get_constraintdef(constraint_row.oid) ~
          'btrim\([[:space:]]*external_reference[[:space:]]*,'
  )
  AND pg_get_functiondef(
    'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  ) ~
      'btrim\([[:space:]]*v_source_type[[:space:]]*,'
  AND pg_get_functiondef(
    'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  ) ~
      'btrim\([[:space:]]*v_external_reference[[:space:]]*,',
  'source_type and external_reference table/RPC boundaries mirror Amendment 12 Unicode-whitespace protection'
);

-- 88
SELECT ok(
  (
    SELECT id
    FROM s13_a12_external_null
  ) = (
    SELECT id
    FROM s13_a12_external_null_replay
  )
  AND (
    SELECT external_reference IS NULL
    FROM s13_a12_external_null
  )
  AND (
    SELECT external_reference IS NULL
    FROM s13_a12_external_null_replay
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT external_booking_id FROM s13_a12_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT external_booking_id FROM s13_a12_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT external_booking_id FROM s13_a12_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT external_booking_id FROM s13_a12_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT external_booking_id FROM s13_a12_ids)
      AND transition_row.transition_key = 'editing_pending'
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'Amendment 12 normalization/rejection is replay-safe and invalid source_type attempts remain mutation-free'
);


-- =====================================================================
-- Amendment 13 — Unicode edge-whitespace canonical boundary closure
-- =====================================================================

SELECT pg_temp.s13_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 89
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY[U&'\00A0github_pat_A13TOKEN'],
       'manual',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys contain Unicode edge whitespace',
  'selected-image key rejects NBSP-prefixed credential-shaped evidence'
);

-- 90
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY[U&'A13-EDGE-IMAGE\3000'],
       'manual',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: selected image keys contain Unicode edge whitespace',
  'selected-image key rejects trailing Unicode edge whitespace'
);

-- 91
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['A13-EXT-EDGE-001'],
       'manual',
       U&'\00A0github_pat_A13TOKEN'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference contains Unicode edge whitespace',
  'external_reference rejects NBSP-prefixed credential-shaped evidence'
);

-- 92
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['A13-EXT-EDGE-002'],
       'manual',
       U&'EXT-A13-EDGE\3000'
     ) $$,
  '22023',
  'record_booking_selection_completion: external_reference contains Unicode edge whitespace',
  'external_reference rejects trailing Unicode edge whitespace'
);

-- 93
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['A13-SRC-EDGE-001'],
       U&'\00A0manual',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: source_type contains Unicode edge whitespace',
  'source_type rejects leading residual Unicode edge whitespace'
);

-- 94
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_completion(
       (SELECT photographer_booking_id FROM s13_ids),
       ARRAY['A13-SRC-EDGE-002'],
       U&'manual\3000',
       NULL
     ) $$,
  '22023',
  'record_booking_selection_completion: source_type contains Unicode edge whitespace',
  'source_type rejects trailing residual Unicode edge whitespace'
);

CREATE TEMP TABLE s13_a13_ids AS
SELECT pg_temp.s13_create_booking(
  '8e000000-0000-0000-0000-000000000701'::uuid
) AS canonical_booking_id;

SELECT pg_temp.s13_prepare_stage12(
  (SELECT canonical_booking_id FROM s13_a13_ids)
);

-- 95
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_a13_canonical_first AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT canonical_booking_id FROM s13_a13_ids),
    ARRAY['  A13-VALID-001  '],
    '  manual  ',
    '  EXT-A13-001  '
  )
  $$,
  'ordinary ASCII edge spaces continue to canonicalize successfully'
);

-- 96
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s13_a13_canonical_replay AS
  SELECT *
  FROM public.record_booking_selection_completion(
    (SELECT canonical_booking_id FROM s13_a13_ids),
    ARRAY['A13-VALID-001'],
    'manual',
    'EXT-A13-001'
  )
  $$,
  'canonical exact replay remains successful after Unicode edge hardening'
);

-- 97
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selected_images'::regclass
      AND constraint_row.conname =
          'booking_selected_images_image_key_chk'
      AND pg_get_constraintdef(constraint_row.oid) ~
          'image_key[[:space:]]*=[[:space:]]*btrim\([[:space:]]*image_key[[:space:]]*,'
  )
  AND EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_completions'::regclass
      AND constraint_row.conname =
          'booking_selection_completions_source_type_chk'
      AND pg_get_constraintdef(constraint_row.oid) ~
          'source_type[[:space:]]*=[[:space:]]*btrim\([[:space:]]*source_type[[:space:]]*,'
  )
  AND EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_completions'::regclass
      AND constraint_row.conname =
          'booking_selection_completions_external_reference_chk'
      AND pg_get_constraintdef(constraint_row.oid) ~
          'external_reference[[:space:]]*=[[:space:]]*btrim\([[:space:]]*external_reference[[:space:]]*,'
  )
  AND pg_get_functiondef(
    'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  ) ~
      'btrim\(value\)[[:space:]]*<>[[:space:]]*btrim\([[:space:]]*btrim\(value\)[[:space:]]*,'
  AND pg_get_functiondef(
    'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  ) ~
      'v_source_type[[:space:]]*<>[[:space:]]*btrim\([[:space:]]*v_source_type[[:space:]]*,'
  AND pg_get_functiondef(
    'public.record_booking_selection_completion(uuid,text[],text,text)'::regprocedure
  ) ~
      'v_external_reference[[:space:]]*<>[[:space:]]*btrim\([[:space:]]*v_external_reference[[:space:]]*,',
  'all three immutable textual evidence boundaries mirror Amendment 13 Unicode edge protection'
);

-- 98
SELECT ok(
  (
    SELECT id
    FROM s13_a13_canonical_first
  ) = (
    SELECT id
    FROM s13_a13_canonical_replay
  )
  AND (
    SELECT source_type = 'manual'
      AND external_reference = 'EXT-A13-001'
    FROM s13_a13_canonical_first
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT canonical_booking_id FROM s13_a13_ids)
      AND selected.image_key = 'A13-VALID-001'
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT canonical_booking_id FROM s13_a13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT canonical_booking_id FROM s13_a13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT canonical_booking_id FROM s13_a13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT canonical_booking_id FROM s13_a13_ids)
      AND transition_row.transition_key = 'editing_pending'
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selection_completions completion
    WHERE completion.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.booking_selected_images selected
    WHERE selected.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key = 'booking.selection_completed'
      AND audit.entity_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND (
    SELECT stage.stage_order = 12
      AND stage.stage_key = 'selection_pending'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT photographer_booking_id FROM s13_ids)
      AND transition_row.transition_key = 'editing_pending'
  ),
  'Amendment 13 preserves canonical ASCII trimming/replay and invalid Unicode-edge attempts remain mutation-free'
);

-- Additional branch-read containment is validated by the table policies and
-- full database regression; this focused suite remains bounded to the frozen
-- mutation contract.

SELECT * FROM finish();

ROLLBACK;
