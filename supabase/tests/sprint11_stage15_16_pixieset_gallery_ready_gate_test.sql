CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(38);

-- =====================================================================
-- Sprint 11 Slice 17
-- Controlled Stage 15 -> 16 / Pixieset Gallery Ready Advancement Gate
-- =====================================================================


-- =====================================================================
-- Part 1 - Structural / ACL / authority contract
-- =====================================================================

-- 1
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  69::bigint,
  'canonical permission catalogue remains exactly 69'
);

-- 2
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  243::bigint,
  'canonical role-permission mapping count remains exactly 243'
);

-- 3
SELECT ok(
  to_regprocedure(
    'public.mark_booking_pixieset_gallery_ready(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_pixieset_gallery_ready(uuid)'::regprocedure
  ) = 'bookings',
  'mark_booking_pixieset_gallery_ready(uuid) exists and returns bookings'
);

-- 4
SELECT ok(
  (
    SELECT
      procedure.prosecdef
      AND procedure.proconfig =
          ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_pixieset_gallery_ready(uuid)'::regprocedure
  ),
  'Pixieset Gallery Ready gate is SECURITY DEFINER with empty search_path'
);

-- 5
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_pixieset_gallery_ready(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.mark_booking_pixieset_gallery_ready(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.mark_booking_pixieset_gallery_ready(uuid)',
    'EXECUTE'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault('f', procedure.proowner)
      )
    ) acl
    WHERE procedure.oid =
      'public.mark_booking_pixieset_gallery_ready(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'Pixieset Gallery Ready RPC execution boundary is authenticated-only'
);

-- 6
SELECT is(
  (
    SELECT array_agg(role.key ORDER BY role.key)
    FROM public.role_permissions mapping
    JOIN public.permissions permission
      ON permission.id =
         mapping.permission_id
    JOIN public.roles role
      ON role.id =
         mapping.role_id
    WHERE permission.key =
          'booking.stage.advance'
  ),
  ARRAY[
    'client_coordinator',
    'founder',
    'studio_manager'
  ]::text[],
  'booking.stage.advance topology remains exact'
);

-- 7
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions mapping
    JOIN public.permissions permission
      ON permission.id =
         mapping.permission_id
    JOIN public.roles role
      ON role.id =
         mapping.role_id
    WHERE permission.key =
          'booking.stage.advance'
      AND role.key =
          'editor'
  ),
  0::bigint,
  'Editor does not gain journey advancement'
);

-- 8
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%booking.stage.advance%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%has_branch_scope%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_qc_passes%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%source_qc_pending_transition_id%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_stage_transitions%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%qc_pending%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%pixieset_gallery_ready%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%FOR UPDATE%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%append_audit_event%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_pixieset_gallery_ready(uuid)'::regprocedure
  ),
  'gate contains frozen journey and immutable QC Pass authorities'
);

-- 9
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        NOT ILIKE '%editing.write%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%editing.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%delivery.write%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%delivery.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%review.write%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%review.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%finance.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%payment.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking.team.assign%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%record_booking_qc_pass%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%record_booking_editing_completion%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%record_booking_editing_start%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%mark_booking_qc_pending%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%mark_booking_editing_in_progress%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_editing_completions%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_editing_starts%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%delivered%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_pixieset_gallery_ready(uuid)'::regprocedure
  ),
  'gate imports no domain-write, upstream-editing, delivery, finance or Stage-17 authority'
);

-- 10
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
      AND (
        relation.relname ILIKE '%gallery%'
        OR relation.relname ILIKE '%pixieset%'
        OR relation.relname ILIKE '%delivery%'
      )
  ),
  0::bigint,
  'Slice 17 creates no gallery, Pixieset or delivery persistence'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_journey_stages stage
    WHERE stage.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND stage.is_active
      AND (
        (
          stage.stage_order = 15
          AND stage.stage_key =
              'qc_pending'
        )
        OR
        (
          stage.stage_order = 16
          AND stage.stage_key =
              'pixieset_gallery_ready'
        )
      )
  ),
  2::bigint,
  'canonical Stage 15 and Stage 16 catalogue remains exact'
);

-- 12
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
  'immutable Slice 16 QC Pass evidence remains exact'
);


-- =====================================================================
-- Part 2 - Transaction-local identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('b1700000-0000-0000-0000-000000000001'::uuid),
  ('b1700000-0000-0000-0000-000000000002'::uuid),
  ('b1700000-0000-0000-0000-000000000003'::uuid),
  ('b1700000-0000-0000-0000-000000000004'::uuid),
  ('b1700000-0000-0000-0000-000000000005'::uuid),
  ('b1700000-0000-0000-0000-000000000006'::uuid),
  ('b1700000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  'b1700000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice17 Branch A',
  's11s17-a',
  'active'
),
(
  'b1700000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice17 Branch B',
  's11s17-b',
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
  'b1700000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1700000-0000-0000-0000-000000000001',
  'active',
  'S11S17 Founder',
  NULL
),
(
  'b1700000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1700000-0000-0000-0000-000000000002',
  'active',
  'S11S17 Studio Manager',
  NULL
),
(
  'b1700000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1700000-0000-0000-0000-000000000003',
  'active',
  'S11S17 Client Coordinator',
  NULL
),
(
  'b1700000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1700000-0000-0000-0000-000000000004',
  'active',
  'S11S17 Editor',
  NULL
),
(
  'b1700000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1700000-0000-0000-0000-000000000005',
  'suspended',
  'S11S17 Suspended Founder',
  now()
),
(
  'b1700000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1700000-0000-0000-0000-000000000006',
  'active',
  'S11S17 Branch Coordinator',
  NULL
),
(
  'b1700000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1700000-0000-0000-0000-000000000007',
  'active',
  'S11S17 Historical Editor',
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
      'b1700000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1700000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      'b1700000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      'b1700000-0000-0000-0000-000000000104'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      'b1700000-0000-0000-0000-000000000105'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1700000-0000-0000-0000-000000000106'::uuid,
      'client_coordinator'::text,
      'b1700000-0000-0000-0000-000000000701'::uuid
    ),
    (
      'b1700000-0000-0000-0000-000000000107'::uuid,
      'editor'::text,
      NULL::uuid
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


CREATE FUNCTION pg_temp.s11s17_set_actor(
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


SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000001'
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
  'b1700000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-G7HJKM',
  'S11 Slice17 Family',
  'S11 Slice17 Family',
  'active',
  'b1700000-0000-0000-0000-000000000101',
  'b1700000-0000-0000-0000-000000000101'
);


-- =====================================================================
-- Part 3 - Canonical booking / journey helpers
-- =====================================================================

CREATE FUNCTION pg_temp.s11s17_create_booking(
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
    'b1700000-0000-0000-0000-000000000201',
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


CREATE FUNCTION pg_temp.s11s17_set_stage_without_transition(
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
      'S11S17 fixture target stage unavailable: % %',
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
      'b1700000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s17_prepare_stage15(
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
  PERFORM pg_temp.s11s17_set_stage_without_transition(
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
    'b1700000-0000-0000-0000-000000000101'
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
      'b1700000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s17_insert_gallery_history(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_stage16 public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.*
  INTO v_stage16
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order = 16
    AND stage.stage_key =
        'pixieset_gallery_ready'
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
    v_stage16.id,
    'pixieset_gallery_ready',
    now(),
    'b1700000-0000-0000-0000-000000000101'
  );
END;
$$;


CREATE FUNCTION pg_temp.s11s17_capture_gate_error(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.mark_booking_pixieset_gallery_ready(
    p_booking_id
  );

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


-- =====================================================================
-- Part 4 - Dedicated fixtures
-- =====================================================================

CREATE TEMP TABLE s11s17_ids (
  client_booking_id uuid,
  founder_booking_id uuid,
  studio_booking_id uuid,
  editor_booking_id uuid,
  branch_booking_id uuid,
  stage14_booking_id uuid,
  stage17_booking_id uuid,
  missing_qc_pass_booking_id uuid,
  malformed_booking_id uuid,
  donor_booking_id uuid,
  early_qc_booking_id uuid,
  preexisting_history_booking_id uuid,
  historical_booking_id uuid,
  invalid_replay_booking_id uuid
);

INSERT INTO s11s17_ids
VALUES (
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(
    'b1700000-0000-0000-0000-000000000702'
  ),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking(),
  pg_temp.s11s17_create_booking()
);


SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000001'
);

SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT client_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT founder_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT studio_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT editor_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT branch_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT missing_qc_pass_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT malformed_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT donor_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT early_qc_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT preexisting_history_booking_id FROM s11s17_ids)
);
SELECT pg_temp.s11s17_prepare_stage15(
  (SELECT historical_booking_id FROM s11s17_ids)
);

SELECT pg_temp.s11s17_set_stage_without_transition(
  (SELECT stage14_booking_id FROM s11s17_ids),
  14,
  'editing_in_progress'
);

SELECT pg_temp.s11s17_set_stage_without_transition(
  (SELECT stage17_booking_id FROM s11s17_ids),
  17,
  'delivered'
);

SELECT pg_temp.s11s17_set_stage_without_transition(
  (SELECT invalid_replay_booking_id FROM s11s17_ids),
  16,
  'pixieset_gallery_ready'
);


-- Canonical QC Pass evidence is created under Slice 16 domain authority.
SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000004'
);

SELECT public.record_booking_qc_pass(
  (SELECT client_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT founder_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT studio_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT editor_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT branch_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT malformed_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT donor_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT early_qc_booking_id FROM s11s17_ids)
);
SELECT public.record_booking_qc_pass(
  (SELECT preexisting_history_booking_id FROM s11s17_ids)
);


-- Historical Editor creates independently valid QC Pass evidence.
SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000007'
);

SELECT public.record_booking_qc_pass(
  (SELECT historical_booking_id FROM s11s17_ids)
);


-- Founder performs transaction-local corruption setup.
SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000001'
);


-- Corrupt one QC Pass to point to another booking's otherwise-valid
-- qc_pending source transition.
ALTER TABLE public.booking_qc_passes
DISABLE TRIGGER USER;

UPDATE public.booking_qc_passes qc_pass
SET source_qc_pending_transition_id =
    (
      SELECT transition_row.id
      FROM public.booking_stage_transitions transition_row
      WHERE transition_row.booking_id =
            (SELECT missing_qc_pass_booking_id FROM s11s17_ids)
        AND transition_row.transition_key =
            'qc_pending'
      ORDER BY transition_row.transitioned_at
      LIMIT 1
    )
WHERE qc_pass.booking_id =
      (SELECT malformed_booking_id FROM s11s17_ids);


-- Corrupt another otherwise-valid QC Pass timestamp.
UPDATE public.booking_qc_passes qc_pass
SET passed_at =
    (
      SELECT
        transition_row.transitioned_at -
        interval '1 second'
      FROM public.booking_stage_transitions transition_row
      WHERE transition_row.id =
            qc_pass.source_qc_pending_transition_id
    )
WHERE qc_pass.booking_id =
      (SELECT early_qc_booking_id FROM s11s17_ids);

ALTER TABLE public.booking_qc_passes
ENABLE TRIGGER USER;


-- Current Stage 15 may not coexist with pre-existing Stage 15 -> 16 history.
SELECT pg_temp.s11s17_insert_gallery_history(
  (SELECT preexisting_history_booking_id FROM s11s17_ids)
);


-- Historical QC Pass authority survives later actor suspension.
UPDATE public.organization_members
SET
  status = 'suspended',
  suspended_at = now()
WHERE id =
  'b1700000-0000-0000-0000-000000000107'::uuid;


CREATE TEMP TABLE s11s17_client_baseline AS
SELECT
  state.version AS state_version,
  (
    SELECT md5(to_jsonb(qc_pass)::text)
    FROM public.booking_qc_passes qc_pass
    WHERE qc_pass.booking_id =
      (SELECT client_booking_id FROM s11s17_ids)
  ) AS qc_pass_hash,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s17_ids)
      AND audit.action_key =
          'booking.qc_passed'
  ) AS qc_pass_audit_count
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT client_booking_id FROM s11s17_ids);


-- =====================================================================
-- Part 5 - Fail-closed authorization / stage / evidence
-- =====================================================================

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000001'
);

-- 13
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(NULL)
  $$,
  '22023',
  'mark_booking_pixieset_gallery_ready: booking_id is required',
  'null booking id is rejected'
);

-- 14
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    'b17fffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'mark_booking_pixieset_gallery_ready: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s17_set_actor(NULL);

-- 15
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT client_booking_id FROM s11s17_ids)
  )
  $$,
  '42501',
  'mark_booking_pixieset_gallery_ready: authenticated actor required',
  'unauthenticated actor is rejected'
);

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000005'
);

-- 16
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT client_booking_id FROM s11s17_ids)
  )
  $$,
  '42501',
  'mark_booking_pixieset_gallery_ready: active organization membership required',
  'suspended organization member is rejected'
);

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000004'
);

-- 17
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT editor_booking_id FROM s11s17_ids)
  )
  $$,
  '42501',
  'mark_booking_pixieset_gallery_ready: booking.stage.advance permission required',
  'Editor cannot perform journey advancement'
);

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000006'
);

-- 18
SELECT ok(
  pg_temp.s11s17_capture_gate_error(
    (SELECT branch_booking_id FROM s11s17_ids)
  ) LIKE '42501:%',
  'branch-scoped Client Coordinator cannot advance another branch'
);

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000001'
);

-- 19
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT stage14_booking_id FROM s11s17_ids)
  )
  $$,
  '22023',
  'mark_booking_pixieset_gallery_ready: booking must be exactly QC Pending or Pixieset Gallery Ready replay',
  'earlier Stage 14 is rejected'
);

-- 20
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT stage17_booking_id FROM s11s17_ids)
  )
  $$,
  '22023',
  'mark_booking_pixieset_gallery_ready: booking must be exactly QC Pending or Pixieset Gallery Ready replay',
  'later Stage 17 is rejected'
);

-- 21
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT missing_qc_pass_booking_id FROM s11s17_ids)
  )
  $$,
  'P0001',
  'mark_booking_pixieset_gallery_ready: exactly one canonical QC Pass evidence row required',
  'Stage 15 without QC Pass evidence fails closed'
);

-- 22
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT malformed_booking_id FROM s11s17_ids)
  )
  $$,
  'P0001',
  'mark_booking_pixieset_gallery_ready: QC Pass source transition does not match current QC Pending state',
  'QC Pass sourced from another booking fails closed'
);

-- 23
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT early_qc_booking_id FROM s11s17_ids)
  )
  $$,
  'P0001',
  'mark_booking_pixieset_gallery_ready: QC Pass lineage timestamp is inconsistent',
  'QC Pass timestamp preceding QC Pending entry fails closed'
);

-- 24
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT preexisting_history_booking_id FROM s11s17_ids)
  )
  $$,
  'P0001',
  'mark_booking_pixieset_gallery_ready: unexpected pre-existing Pixieset Gallery Ready transition history',
  'Stage 15 with pre-existing Stage 15 to 16 history fails closed'
);


-- =====================================================================
-- Part 6 - Client Coordinator first-success contract
-- =====================================================================

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000003'
);

-- 25
SELECT lives_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT client_booking_id FROM s11s17_ids)
  )
  $$,
  'Client Coordinator may consume immutable QC Pass evidence'
);

-- 26
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s17_ids)
  ),
  'pixieset_gallery_ready'::text,
  'first success moves booking exactly to Stage 16 Pixieset Gallery Ready'
);

-- 27
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s17_ids)
  ),
  (
    SELECT state_version + 1
    FROM s11s17_client_baseline
  ),
  'first success increments journey version exactly once'
);

-- 28
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(
        transition_row.transitioned_by =
        'b1700000-0000-0000-0000-000000000103'::uuid
      )
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
      (SELECT client_booking_id FROM s11s17_ids)
      AND transition_row.transition_key =
          'pixieset_gallery_ready'
      AND source_stage.stage_order = 15
      AND source_stage.stage_key =
          'qc_pending'
      AND destination_stage.stage_order = 16
      AND destination_stage.stage_key =
          'pixieset_gallery_ready'
  ),
  'first success creates exactly one actor-attributed Stage 15 to 16 transition'
);

-- 29
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(NOT audit.is_sensitive)
      AND bool_and(
        ARRAY(
          SELECT jsonb_object_keys(
            audit.metadata
          )
          ORDER BY 1
        ) = ARRAY[
          'booking_id',
          'destination_stage_id',
          'prior_journey_version',
          'qc_pass_id',
          'qc_passed_at',
          'resulting_journey_version',
          'source_qc_pending_transition_id',
          'source_stage_id',
          'transition_key',
          'transitioned_at'
        ]::text[]
      )
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s17_ids)
      AND audit.action_key =
          'booking.pixieset_gallery_ready'
  ),
  'first success creates one non-sensitive structural booking.pixieset_gallery_ready audit'
);

-- 30
SELECT ok(
  (
    SELECT
      (
        SELECT md5(to_jsonb(qc_pass)::text)
        FROM public.booking_qc_passes qc_pass
        WHERE qc_pass.booking_id =
          (SELECT client_booking_id FROM s11s17_ids)
      ) = baseline.qc_pass_hash
      AND
      (
        SELECT count(*)::bigint
        FROM public.audit_events audit
        WHERE audit.entity_id =
          (SELECT client_booking_id FROM s11s17_ids)
          AND audit.action_key =
              'booking.qc_passed'
      ) = baseline.qc_pass_audit_count
    FROM s11s17_client_baseline baseline
  ),
  'journey advancement neither mutates nor recreates QC Pass evidence'
);

-- 31
SELECT is(
  (
    SELECT state.updated_by
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s17_ids)
  ),
  'b1700000-0000-0000-0000-000000000103'::uuid,
  'journey state update attributes the Client Coordinator'
);


CREATE TEMP TABLE s11s17_client_after_first AS
SELECT
  state.version AS state_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT client_booking_id FROM s11s17_ids)
      AND transition_row.transition_key =
          'pixieset_gallery_ready'
  ) AS gallery_transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s17_ids)
      AND audit.action_key =
          'booking.pixieset_gallery_ready'
  ) AS gallery_audit_count,
  (
    SELECT md5(to_jsonb(qc_pass)::text)
    FROM public.booking_qc_passes qc_pass
    WHERE qc_pass.booking_id =
      (SELECT client_booking_id FROM s11s17_ids)
  ) AS qc_pass_hash
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT client_booking_id FROM s11s17_ids);


-- =====================================================================
-- Part 7 - Strict Stage 16 replay
-- =====================================================================

-- 32
SELECT lives_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT client_booking_id FROM s11s17_ids)
  )
  $$,
  'exact Stage 16 replay succeeds'
);

-- 33
SELECT ok(
  (
    SELECT
      (
        SELECT state.version
        FROM public.booking_journey_states state
        WHERE state.booking_id =
          (SELECT client_booking_id FROM s11s17_ids)
      ) = after_first.state_version
      AND
      (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
          (SELECT client_booking_id FROM s11s17_ids)
          AND transition_row.transition_key =
              'pixieset_gallery_ready'
      ) = after_first.gallery_transition_count
      AND
      (
        SELECT count(*)::bigint
        FROM public.audit_events audit
        WHERE audit.entity_id =
          (SELECT client_booking_id FROM s11s17_ids)
          AND audit.action_key =
              'booking.pixieset_gallery_ready'
      ) = after_first.gallery_audit_count
    FROM s11s17_client_after_first after_first
  ),
  'Stage 16 replay creates no transition, audit or version change'
);

-- 34
SELECT is(
  (
    SELECT md5(to_jsonb(qc_pass)::text)
    FROM public.booking_qc_passes qc_pass
    WHERE qc_pass.booking_id =
      (SELECT client_booking_id FROM s11s17_ids)
  ),
  (
    SELECT qc_pass_hash
    FROM s11s17_client_after_first
  ),
  'Stage 16 replay leaves immutable QC Pass evidence unchanged'
);


-- =====================================================================
-- Part 8 - Other journey actors / historical authority / bad replay
-- =====================================================================

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000001'
);

-- 35
SELECT lives_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT founder_booking_id FROM s11s17_ids)
  )
  $$,
  'Founder may advance canonical QC Pass to Pixieset Gallery Ready'
);

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000002'
);

-- 36
SELECT lives_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT studio_booking_id FROM s11s17_ids)
  )
  $$,
  'Studio Manager may advance canonical QC Pass to Pixieset Gallery Ready'
);

SELECT pg_temp.s11s17_set_actor(
  'b1700000-0000-0000-0000-000000000003'
);

-- 37
SELECT lives_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT historical_booking_id FROM s11s17_ids)
  )
  $$,
  'historical QC Pass remains valid after QC Pass actor suspension'
);

-- 38
SELECT throws_ok(
  $$
  SELECT public.mark_booking_pixieset_gallery_ready(
    (SELECT invalid_replay_booking_id FROM s11s17_ids)
  )
  $$,
  'P0001',
  'mark_booking_pixieset_gallery_ready: Pixieset Gallery Ready replay history is invalid',
  'Stage 16 without canonical Stage 15 to 16 history fails closed'
);


SELECT * FROM finish();

ROLLBACK;
