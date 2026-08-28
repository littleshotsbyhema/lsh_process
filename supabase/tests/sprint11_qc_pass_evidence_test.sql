CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(42);

-- =====================================================================
-- Sprint 11 Slice 16
-- QC Pass Evidence Foundation
-- =====================================================================


-- =====================================================================
-- Part 1 - Structural / ACL / authority contract
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT
      (SELECT count(*) FROM public.permissions)::text
      || ':'
      || (SELECT count(*) FROM public.role_permissions)::text
  ),
  '69:243'::text,
  'canonical permission and role-mapping totals remain 69:243'
);

-- 2
SELECT ok(
  to_regclass(
    'public.booking_qc_passes'
  ) IS NOT NULL
  AND (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_qc_passes'
  ) = 6,
  'booking_qc_passes exists with exactly six columns'
);

-- 3
SELECT is(
  (
    SELECT array_agg(
      column_name::text
      ORDER BY ordinal_position
    )
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_qc_passes'
  ),
  ARRAY[
    'id',
    'organization_id',
    'booking_id',
    'source_qc_pending_transition_id',
    'passed_at',
    'passed_by'
  ]::text[],
  'QC-pass column order and names are exact'
);

-- 4
SELECT ok(
  (
    SELECT
      relation.relrowsecurity
      AND relation.relforcerowsecurity
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
      'public.booking_qc_passes'::regclass
  ),
  'booking_qc_passes enables and forces RLS'
);

-- 5
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_qc_passes'::regclass
      AND constraint_row.conname =
          'bpass_org_booking_key'
      AND constraint_row.contype = 'u'
  )
  AND EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_qc_passes'::regclass
      AND constraint_row.conname =
          'bpass_org_source_transition_key'
      AND constraint_row.contype = 'u'
  ),
  'QC-pass uniqueness constraints are exact'
);

-- 6
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.booking_qc_passes'::regclass
      AND trigger_row.tgname =
          'booking_qc_passes_guard'
      AND NOT trigger_row.tgisinternal
  ),
  'immutable QC-pass guard exists'
);

-- 7
SELECT ok(
  to_regprocedure(
    'public.record_booking_qc_pass(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(
      procedure.oid
    )
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_qc_pass(uuid)'::regprocedure
  ) = 'booking_qc_passes',
  'record_booking_qc_pass(uuid) exists and returns booking_qc_passes'
);

-- 8
SELECT ok(
  (
    SELECT count(*)
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.pronamespace =
          'public'::regnamespace
      AND procedure.proname =
          'record_booking_qc_pass'
  ) = 1
  AND (
    SELECT procedure.prosecdef
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_qc_pass(uuid)'::regprocedure
  )
  AND (
    SELECT procedure.proconfig
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_qc_pass(uuid)'::regprocedure
  ) = ARRAY['search_path=""']::text[],
  'QC-pass recorder has one SECURITY DEFINER signature with empty search_path'
);

-- 9
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_qc_pass(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.record_booking_qc_pass(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.record_booking_qc_pass(uuid)',
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
      'public.record_booking_qc_pass(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'QC-pass RPC execution ACL is authenticated-only'
);

-- 10
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_qc_passes',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_qc_passes',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_qc_passes',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_qc_passes',
    'DELETE'
  ),
  'authenticated receives SELECT only and no direct QC pass mutation'
);

-- 11
SELECT ok(
  (
    SELECT
      lower(COALESCE(policy.qual, ''))
        LIKE '%editing.read%'
      AND lower(COALESCE(policy.qual, ''))
        LIKE '%has_branch_scope%'
    FROM pg_catalog.pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename =
          'booking_qc_passes'
      AND policy.policyname =
          'booking_qc_passes_authenticated_select'
  ),
  'QC pass read policy uses editing.read and branch scope'
);

-- 12
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
          'editing.write'
  ),
  ARRAY[
    'editor',
    'founder',
    'studio_manager'
  ]::text[],
  'editing.write topology remains exact'
);

-- 13
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
          'editing.read'
  ),
  ARRAY[
    'client_coordinator',
    'editor',
    'founder',
    'studio_manager'
  ]::text[],
  'editing.read topology remains exact'
);

-- 14
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%editing.write%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%has_branch_scope%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_stage_transitions%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%editing_in_progress%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%qc_pending%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%FOR UPDATE%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%append_audit_event%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_qc_pass(uuid)'::regprocedure
  ),
  'QC-pass recorder contains editing-write, branch, Stage-14-to-15 lineage, locking and audit authorities'
);

-- 15
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking.stage.advance%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%editing.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%delivery.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%delivery.write%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%review.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%review.write%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%finance.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%payment.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking.team.assign%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_editing_completions%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%record_booking_editing_completion%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_editing_starts%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%record_booking_editing_start%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%mark_booking_editing_in_progress%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%mark_booking_qc_pending%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%pixieset_gallery_ready%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%delivered%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%INSERT INTO public.booking_stage_transitions%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%UPDATE public.booking_journey_states%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_qc_pass(uuid)'::regprocedure
  ),
  'QC-pass recorder imports no journey, upstream-editing, review, finance, gallery or delivery authority'
);

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class relation
    JOIN pg_catalog.pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relkind IN (
        'r',
        'p',
        'v',
        'm',
        'f'
      )
      AND relation.relname ILIKE '%editing%'
      AND relation.relname NOT IN (
        'booking_editing_starts',
        'booking_editing_completions'
      )
  ),
  0::bigint,
  'Slice 16 creates no other editing persistence relation'
);

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class relation
    JOIN pg_catalog.pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname <> 'booking_qc_passes'
      AND (
        relation.relname ILIKE '%qc%'
        OR relation.relname ILIKE '%pixieset%'
        OR relation.relname ILIKE '%delivery%'
      )
  ),
  0::bigint,
  'Slice 16 creates no additional QC, gallery or delivery persistence beyond booking_qc_passes'
);

-- 18
SELECT ok(
  (
    SELECT count(*)
    FROM public.booking_journey_stages stage
    WHERE stage.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND stage.stage_order = 15
      AND stage.stage_key =
          'qc_pending'
      AND stage.is_active
  ) = 1,
  'canonical Stage 15 QC Pending remains exact'
);


-- =====================================================================
-- Part 2 - Transaction-local identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('b1600000-0000-0000-0000-000000000001'::uuid),
  ('b1600000-0000-0000-0000-000000000002'::uuid),
  ('b1600000-0000-0000-0000-000000000003'::uuid),
  ('b1600000-0000-0000-0000-000000000004'::uuid),
  ('b1600000-0000-0000-0000-000000000005'::uuid),
  ('b1600000-0000-0000-0000-000000000006'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  'b1600000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice16 Branch A',
  's11s16-a',
  'active'
),
(
  'b1600000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice16 Branch B',
  's11s16-b',
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
  'b1600000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1600000-0000-0000-0000-000000000001',
  'active',
  'S11S16 Founder',
  NULL
),
(
  'b1600000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1600000-0000-0000-0000-000000000002',
  'active',
  'S11S16 Studio Manager',
  NULL
),
(
  'b1600000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1600000-0000-0000-0000-000000000003',
  'active',
  'S11S16 Client Coordinator',
  NULL
),
(
  'b1600000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1600000-0000-0000-0000-000000000004',
  'active',
  'S11S16 Editor',
  NULL
),
(
  'b1600000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1600000-0000-0000-0000-000000000005',
  'suspended',
  'S11S16 Suspended Editor',
  now()
),
(
  'b1600000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1600000-0000-0000-0000-000000000006',
  'active',
  'S11S16 Branch Editor',
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
      'b1600000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1600000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      'b1600000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      'b1600000-0000-0000-0000-000000000104'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      'b1600000-0000-0000-0000-000000000105'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      'b1600000-0000-0000-0000-000000000106'::uuid,
      'editor'::text,
      'b1600000-0000-0000-0000-000000000701'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;


CREATE FUNCTION pg_temp.s11s16_set_actor(
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


SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000001'
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
  'b1600000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-F6GHJK',
  'S11 Slice16 Family',
  'S11 Slice16 Family',
  'active',
  'b1600000-0000-0000-0000-000000000101',
  'b1600000-0000-0000-0000-000000000101'
);


-- =====================================================================
-- Part 3 - Booking / journey fixture helpers
-- =====================================================================

CREATE FUNCTION pg_temp.s11s16_create_booking(
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
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE package.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND package.package_key =
        'maternity_gold'
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'b1600000-0000-0000-0000-000000000201',
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
  FROM public.accept_quotation(
    v_quote.id
  );

  RETURN v_booking.id;
END;
$$;


CREATE FUNCTION pg_temp.s11s16_set_stage_without_transition(
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
  WHERE state.booking_id =
        p_booking_id;

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

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'S11S16 fixture target stage unavailable: % %',
      p_stage_order,
      p_stage_key;
  END IF;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_target.id,
    stage_entered_at =
      now(),
    version =
      state.version + 1,
    updated_at =
      now(),
    updated_by =
      'b1600000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s16_prepare_stage15(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_stage14 public.booking_journey_stages;
  v_stage15 public.booking_journey_stages;
  v_transitioned_at timestamptz;
BEGIN
  PERFORM pg_temp.s11s16_set_stage_without_transition(
    p_booking_id,
    14,
    'editing_in_progress'
  );

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.*
  INTO v_stage14
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order = 14
    AND stage.stage_key =
        'editing_in_progress'
    AND stage.is_active;

  SELECT stage.*
  INTO v_stage15
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order = 15
    AND stage.stage_key =
        'qc_pending'
    AND stage.is_active;

  v_transitioned_at := now();

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
    v_stage14.id,
    v_stage15.id,
    'qc_pending',
    v_transitioned_at,
    'b1600000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_stage15.id,
    stage_entered_at =
      v_transitioned_at,
    version =
      state.version + 1,
    updated_at =
      v_transitioned_at,
    updated_by =
      'b1600000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s16_capture_qc_pass_error(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.record_booking_qc_pass(
    p_booking_id
  );

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


CREATE TEMP TABLE s11s16_ids (
  editor_booking_id uuid,
  founder_booking_id uuid,
  studio_booking_id uuid,
  client_booking_id uuid,
  branch_booking_id uuid,
  stage14_booking_id uuid,
  stage16_booking_id uuid,
  missing_lineage_booking_id uuid,
  duplicate_lineage_booking_id uuid,
  malformed_booking_id uuid,
  donor_booking_id uuid,
  early_booking_id uuid,
  mismatch_booking_id uuid,
  stage16_replay_booking_id uuid
);

INSERT INTO s11s16_ids
VALUES (
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(
    'b1600000-0000-0000-0000-000000000702'
  ),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking(),
  pg_temp.s11s16_create_booking()
);


SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT editor_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT founder_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT studio_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT client_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT branch_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT stage16_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT duplicate_lineage_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT malformed_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT donor_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT early_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT mismatch_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_prepare_stage15(
  (SELECT stage16_replay_booking_id FROM s11s16_ids)
);

SELECT pg_temp.s11s16_set_stage_without_transition(
  (SELECT stage14_booking_id FROM s11s16_ids),
  14,
  'editing_in_progress'
);

SELECT pg_temp.s11s16_set_stage_without_transition(
  (SELECT missing_lineage_booking_id FROM s11s16_ids),
  15,
  'qc_pending'
);

SELECT pg_temp.s11s16_set_stage_without_transition(
  (SELECT stage16_booking_id FROM s11s16_ids),
  16,
  'pixieset_gallery_ready'
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
  transition_row.organization_id,
  transition_row.booking_id,
  transition_row.from_stage_id,
  transition_row.to_stage_id,
  transition_row.transition_key,
  now(),
  'b1600000-0000-0000-0000-000000000101'::uuid
FROM public.booking_stage_transitions transition_row
WHERE transition_row.booking_id =
      (
        SELECT duplicate_lineage_booking_id
        FROM s11s16_ids
      )
  AND transition_row.transition_key =
      'qc_pending'
ORDER BY transition_row.transitioned_at
LIMIT 1;


CREATE TEMP TABLE s11s16_editor_baseline AS
SELECT
  state.version AS state_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT editor_booking_id FROM s11s16_ids)
  ) AS transition_count
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT editor_booking_id FROM s11s16_ids);


-- =====================================================================
-- Part 4 - Fail-closed authorization / stage / lineage
-- =====================================================================

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000001'
);

-- 19
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(NULL)
  $$,
  '22023',
  'record_booking_qc_pass: booking_id is required',
  'null booking id is rejected'
);

-- 20
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    'b16fffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'record_booking_qc_pass: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s16_set_actor(NULL);

-- 21
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT editor_booking_id FROM s11s16_ids)
  )
  $$,
  '42501',
  'record_booking_qc_pass: authenticated actor required',
  'unauthenticated actor is rejected'
);

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000005'
);

-- 22
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT editor_booking_id FROM s11s16_ids)
  )
  $$,
  '42501',
  'record_booking_qc_pass: active organization membership required',
  'suspended editor is rejected'
);

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000003'
);

-- 23
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT client_booking_id FROM s11s16_ids)
  )
  $$,
  '42501',
  'record_booking_qc_pass: editing.write permission required',
  'Client Coordinator cannot record QC Pass'
);

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000006'
);

-- 24
SELECT ok(
  pg_temp.s11s16_capture_qc_pass_error(
    (SELECT branch_booking_id FROM s11s16_ids)
  ) LIKE '42501:%',
  'branch-scoped Editor is rejected for another branch'
);

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000001'
);

-- 25
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT stage14_booking_id FROM s11s16_ids)
  )
  $$,
  '22023',
  'record_booking_qc_pass: booking must be exactly QC Pending',
  'Stage 14 is rejected'
);

-- 26
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT stage16_booking_id FROM s11s16_ids)
  )
  $$,
  '22023',
  'record_booking_qc_pass: booking must be exactly QC Pending',
  'Stage 16 is rejected and is not accepted as replay'
);

-- 27
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT missing_lineage_booking_id FROM s11s16_ids)
  )
  $$,
  'P0001',
  'record_booking_qc_pass: canonical QC Pending transition history is invalid',
  'Stage 15 without canonical Stage 14 to 15 lineage fails closed'
);

-- 28
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT duplicate_lineage_booking_id FROM s11s16_ids)
  )
  $$,
  'P0001',
  'record_booking_qc_pass: canonical QC Pending transition history is invalid',
  'duplicate canonical Stage 14 to 15 lineage fails closed'
);


-- =====================================================================
-- Part 5 - Editor first-success and replay contract
-- =====================================================================

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000004'
);

-- 29
SELECT lives_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT editor_booking_id FROM s11s16_ids)
  )
  $$,
  'Editor may record canonical QC Pass evidence'
);

-- 30
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(
        qc_pass.passed_by =
        'b1600000-0000-0000-0000-000000000104'::uuid
      )
      AND bool_and(
        qc_pass.source_qc_pending_transition_id =
        transition_row.id
      )
      AND bool_and(
        qc_pass.passed_at >=
        transition_row.transitioned_at
      )
    FROM public.booking_qc_passes qc_pass
    JOIN public.booking_stage_transitions transition_row
      ON transition_row.organization_id =
         qc_pass.organization_id
     AND transition_row.id =
         qc_pass.source_qc_pending_transition_id
    WHERE qc_pass.booking_id =
      (SELECT editor_booking_id FROM s11s16_ids)
      AND transition_row.transition_key =
          'qc_pending'
  ),
  'first success creates exactly one correctly attributed canonical QC pass row'
);

-- 31
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(NOT audit.is_sensitive)
      AND bool_and(
        (audit.metadata ->> 'qc_pending_stage_id')::uuid =
        (
          SELECT state.current_stage_id
          FROM public.booking_journey_states state
          WHERE state.booking_id =
            (SELECT editor_booking_id FROM s11s16_ids)
        )
      )
      AND bool_and(
        lower(
          concat_ws(
            ' ',
            audit.old_values::text,
            audit.new_values::text,
            audit.metadata::text
          )
        ) !~
        '(payment|amount|inr|refund|selection|editor|external|priority|deadline|sla|retouch|fail|failure|score|reviewer|comment|pixieset|gallery|delivery|note)'
      )
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT editor_booking_id FROM s11s16_ids)
      AND audit.action_key =
          'booking.qc_passed'
  ),
  'first success creates one non-sensitive audit without excluded semantics'
);

-- 32
SELECT ok(
  (
    SELECT
      stage.stage_key =
        'qc_pending'
      AND state.version =
        baseline.state_version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
          (SELECT editor_booking_id FROM s11s16_ids)
      ) =
        baseline.transition_count
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    CROSS JOIN s11s16_editor_baseline baseline
    WHERE state.booking_id =
      (SELECT editor_booking_id FROM s11s16_ids)
  ),
  'QC Pass does not advance or mutate the booking journey'
);

CREATE TEMP TABLE s11s16_editor_after_first AS
SELECT
  qc_pass.id AS qc_pass_id,
  md5(to_jsonb(qc_pass)::text) AS qc_pass_hash
FROM public.booking_qc_passes qc_pass
WHERE qc_pass.booking_id =
  (SELECT editor_booking_id FROM s11s16_ids);

-- 33
SELECT lives_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT editor_booking_id FROM s11s16_ids)
  )
  $$,
  'exact Stage 15 replay succeeds idempotently'
);

-- 34
SELECT ok(
  (
    SELECT
      (
        SELECT count(*)
        FROM public.booking_qc_passes qc_pass
        WHERE qc_pass.booking_id =
          (SELECT editor_booking_id FROM s11s16_ids)
      ) = 1
      AND
      (
        SELECT count(*)
        FROM public.audit_events audit
        WHERE audit.entity_id =
          (SELECT editor_booking_id FROM s11s16_ids)
          AND audit.action_key =
              'booking.qc_passed'
      ) = 1
      AND
      (
        SELECT state.version
        FROM public.booking_journey_states state
        WHERE state.booking_id =
          (SELECT editor_booking_id FROM s11s16_ids)
      ) = baseline.state_version
      AND
      (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
          (SELECT editor_booking_id FROM s11s16_ids)
      ) = baseline.transition_count
      AND
      (
        SELECT md5(to_jsonb(qc_pass)::text)
        FROM public.booking_qc_passes qc_pass
        WHERE qc_pass.booking_id =
          (SELECT editor_booking_id FROM s11s16_ids)
      ) = after_first.qc_pass_hash
    FROM s11s16_editor_baseline baseline
    CROSS JOIN s11s16_editor_after_first after_first
  ),
  'replay creates no second evidence/audit and leaves journey/evidence unchanged'
);


-- =====================================================================
-- Part 6 - Founder / Studio Manager QC-pass authority
-- =====================================================================

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000001'
);

-- 35
SELECT lives_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT founder_booking_id FROM s11s16_ids)
  )
  $$,
  'Founder may record QC Pass'
);

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000002'
);

-- 36
SELECT lives_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT studio_booking_id FROM s11s16_ids)
  )
  $$,
  'Studio Manager may record QC Pass'
);


-- =====================================================================
-- Part 7 - Immutable guard
-- =====================================================================

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000004'
);

-- 37
SELECT throws_ok(
  $$
  UPDATE public.booking_qc_passes
  SET passed_at =
      passed_at + interval '1 second'
  WHERE booking_id =
    (SELECT editor_booking_id FROM s11s16_ids)
  $$,
  'P0001',
  'booking QC pass evidence is immutable',
  'QC pass evidence cannot be updated'
);

-- 38
SELECT throws_ok(
  $$
  DELETE FROM public.booking_qc_passes
  WHERE booking_id =
    (SELECT editor_booking_id FROM s11s16_ids)
  $$,
  'P0001',
  'booking QC pass evidence is immutable',
  'QC pass evidence cannot be deleted'
);


-- =====================================================================
-- Part 8 - Insert-guard lineage / attribution
-- =====================================================================

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000001'
);

-- 39
SELECT throws_ok(
  $$
  INSERT INTO public.booking_qc_passes (
    organization_id,
    booking_id,
    source_qc_pending_transition_id,
    passed_at,
    passed_by
  )
  SELECT
    transition_row.organization_id,
    transition_row.booking_id,
    transition_row.id,
    transition_row.transitioned_at - interval '1 second',
    'b1600000-0000-0000-0000-000000000101'::uuid
  FROM public.booking_stage_transitions transition_row
  WHERE transition_row.booking_id =
    (SELECT early_booking_id FROM s11s16_ids)
    AND transition_row.transition_key =
        'qc_pending'
  $$,
  'P0001',
  'booking QC pass cannot precede canonical QC Pending entry',
  'QC pass timestamp cannot precede Stage 15 entry'
);

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000004'
);

-- 40
SELECT throws_ok(
  $$
  INSERT INTO public.booking_qc_passes (
    organization_id,
    booking_id,
    source_qc_pending_transition_id,
    passed_at,
    passed_by
  )
  SELECT
    transition_row.organization_id,
    transition_row.booking_id,
    transition_row.id,
    now(),
    'b1600000-0000-0000-0000-000000000101'::uuid
  FROM public.booking_stage_transitions transition_row
  WHERE transition_row.booking_id =
    (SELECT mismatch_booking_id FROM s11s16_ids)
    AND transition_row.transition_key =
        'qc_pending'
  $$,
  'P0001',
  'booking QC pass passed_by must be the current active organization member',
  'QC pass attribution must match the current authenticated member'
);


-- =====================================================================
-- Part 9 - Corrupt replay / later-stage containment
-- =====================================================================

SELECT public.record_booking_qc_pass(
  (SELECT malformed_booking_id FROM s11s16_ids)
);

ALTER TABLE public.booking_qc_passes
DISABLE TRIGGER USER;

UPDATE public.booking_qc_passes qc_pass
SET source_qc_pending_transition_id =
    (
      SELECT transition_row.id
      FROM public.booking_stage_transitions transition_row
      WHERE transition_row.booking_id =
            (
              SELECT donor_booking_id
              FROM s11s16_ids
            )
        AND transition_row.transition_key =
            'qc_pending'
      ORDER BY transition_row.transitioned_at
      LIMIT 1
    )
WHERE qc_pass.booking_id =
      (
        SELECT malformed_booking_id
        FROM s11s16_ids
      );

ALTER TABLE public.booking_qc_passes
ENABLE TRIGGER USER;

SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000001'
);

-- 41
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT malformed_booking_id FROM s11s16_ids)
  )
  $$,
  'P0001',
  'record_booking_qc_pass: existing QC-pass evidence is inconsistent',
  'malformed pre-existing QC pass evidence fails closed'
);


SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000004'
);

SELECT public.record_booking_qc_pass(
  (SELECT stage16_replay_booking_id FROM s11s16_ids)
);

-- Founder performs the transaction-local journey-fixture move.
-- The helper attributes journey mutation to Founder member ...101,
-- matching the booking journey guard's current-actor requirement.
SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000001'
);

SELECT pg_temp.s11s16_set_stage_without_transition(
  (SELECT stage16_replay_booking_id FROM s11s16_ids),
  16,
  'pixieset_gallery_ready'
);

-- Restore the Editor to prove Stage 16 is not a valid Slice 16 replay.
SELECT pg_temp.s11s16_set_actor(
  'b1600000-0000-0000-0000-000000000004'
);

-- 42
SELECT throws_ok(
  $$
  SELECT public.record_booking_qc_pass(
    (SELECT stage16_replay_booking_id FROM s11s16_ids)
  )
  $$,
  '22023',
  'record_booking_qc_pass: booking must be exactly QC Pending',
  'later Stage 16 progression is not accepted as Slice 16 replay'
);


SELECT * FROM finish();

ROLLBACK;
