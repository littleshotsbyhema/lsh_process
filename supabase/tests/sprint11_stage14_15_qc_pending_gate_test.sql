CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(38);

-- =====================================================================
-- Sprint 11 Slice 15
-- Controlled Stage 14 -> 15 / QC Pending Advancement Gate
-- =====================================================================


-- =====================================================================
-- Part 1 - Structural / ACL / authority contract
-- =====================================================================

-- 1
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  68::bigint,
  'canonical permission catalogue remains exactly 68'
);

-- 2
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  241::bigint,
  'canonical role-permission mapping count remains exactly 241'
);

-- 3
SELECT ok(
  to_regprocedure(
    'public.mark_booking_qc_pending(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_qc_pending(uuid)'::regprocedure
  ) = 'bookings',
  'mark_booking_qc_pending(uuid) exists and returns bookings'
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
      'public.mark_booking_qc_pending(uuid)'::regprocedure
  ),
  'QC Pending gate is SECURITY DEFINER with empty search_path'
);

-- 5
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_qc_pending(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.mark_booking_qc_pending(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.mark_booking_qc_pending(uuid)',
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
      'public.mark_booking_qc_pending(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'QC Pending RPC execution boundary is authenticated-only'
);

-- 6
SELECT is(
  (
    SELECT array_agg(role.key ORDER BY role.key)
    FROM public.role_permissions mapping
    JOIN public.permissions permission
      ON permission.id = mapping.permission_id
    JOIN public.roles role
      ON role.id = mapping.role_id
    WHERE permission.key = 'booking.stage.advance'
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
      ON permission.id = mapping.permission_id
    JOIN public.roles role
      ON role.id = mapping.role_id
    WHERE permission.key = 'booking.stage.advance'
      AND role.key = 'editor'
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
        ILIKE '%booking_editing_completions%'
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
      'public.mark_booking_qc_pending(uuid)'::regprocedure
  ),
  'gate contains frozen journey and Editing Completion authorities'
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
        NOT ILIKE '%finance.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%payment.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking.team.assign%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%record_booking_editing_completion%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%completed_by%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_editing_starts%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%pixieset_gallery_ready%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%delivered%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_qc_pending(uuid)'::regprocedure
  ),
  'gate imports no historical actor, editing, finance, gallery or delivery authority'
);

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class relation
    JOIN pg_catalog.pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname <> 'booking_qc_passes'
      AND (
        relation.relname ILIKE '%qc%'
        OR relation.relname ILIKE '%pixieset%'
        OR relation.relname ILIKE '%delivery%'
      )
  ),
  0::bigint,
  'Slice 15 creates no QC, gallery or delivery persistence'
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
          stage.stage_order = 14
          AND stage.stage_key = 'editing_in_progress'
        )
        OR
        (
          stage.stage_order = 15
          AND stage.stage_key = 'qc_pending'
        )
      )
  ),
  2::bigint,
  'canonical Stage 14 and Stage 15 catalogue remains exact'
);


-- =====================================================================
-- Part 2 - Transaction-local identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('b1500000-0000-0000-0000-000000000001'),
  ('b1500000-0000-0000-0000-000000000002'),
  ('b1500000-0000-0000-0000-000000000003'),
  ('b1500000-0000-0000-0000-000000000004'),
  ('b1500000-0000-0000-0000-000000000005'),
  ('b1500000-0000-0000-0000-000000000006'),
  ('b1500000-0000-0000-0000-000000000007');

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  'b1500000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice15 Branch A',
  's11s15-a',
  'active'
),
(
  'b1500000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice15 Branch B',
  's11s15-b',
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
  'b1500000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1500000-0000-0000-0000-000000000001',
  'active',
  'S11S15 Founder',
  NULL
),
(
  'b1500000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1500000-0000-0000-0000-000000000002',
  'active',
  'S11S15 Studio Manager',
  NULL
),
(
  'b1500000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1500000-0000-0000-0000-000000000003',
  'active',
  'S11S15 Client Coordinator',
  NULL
),
(
  'b1500000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1500000-0000-0000-0000-000000000004',
  'active',
  'S11S15 Editor',
  NULL
),
(
  'b1500000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1500000-0000-0000-0000-000000000005',
  'suspended',
  'S11S15 Suspended Founder',
  now()
),
(
  'b1500000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1500000-0000-0000-0000-000000000006',
  'active',
  'S11S15 Branch Coordinator',
  NULL
),
(
  'b1500000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1500000-0000-0000-0000-000000000007',
  'active',
  'S11S15 Historical Editor',
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
      'b1500000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1500000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      'b1500000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      'b1500000-0000-0000-0000-000000000104'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      'b1500000-0000-0000-0000-000000000105'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1500000-0000-0000-0000-000000000106'::uuid,
      'client_coordinator'::text,
      'b1500000-0000-0000-0000-000000000701'::uuid
    ),
    (
      'b1500000-0000-0000-0000-000000000107'::uuid,
      'editor'::text,
      NULL::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;


CREATE FUNCTION pg_temp.s11s15_set_actor(
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


SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000001'
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
  'b1500000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-E5FGHJ',
  'S11 Slice15 Family',
  'S11 Slice15 Family',
  'active',
  'b1500000-0000-0000-0000-000000000101',
  'b1500000-0000-0000-0000-000000000101'
);


-- =====================================================================
-- Part 3 - Canonical booking / journey helpers
-- =====================================================================

CREATE FUNCTION pg_temp.s11s15_create_booking(
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
  WHERE package.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND package.package_key = 'maternity_gold'
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'b1500000-0000-0000-0000-000000000201',
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


CREATE FUNCTION pg_temp.s11s15_set_stage_without_transition(
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

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'S11S15 fixture target stage unavailable: % %',
      p_stage_order,
      p_stage_key;
  END IF;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = now(),
    version = state.version + 1,
    updated_at = now(),
    updated_by =
      'b1500000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s15_prepare_stage14(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_stage13 public.booking_journey_stages;
  v_stage14 public.booking_journey_stages;
  v_transitioned_at timestamptz;
BEGIN
  PERFORM pg_temp.s11s15_set_stage_without_transition(
    p_booking_id,
    13,
    'editing_pending'
  );

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_stage13
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = 13
    AND stage.stage_key = 'editing_pending'
    AND stage.is_active;

  SELECT stage.*
  INTO v_stage14
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = 14
    AND stage.stage_key = 'editing_in_progress'
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
    v_stage13.id,
    v_stage14.id,
    'editing_in_progress',
    v_transitioned_at,
    'b1500000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_stage14.id,
    stage_entered_at = v_transitioned_at,
    version = state.version + 1,
    updated_at = v_transitioned_at,
    updated_by =
      'b1500000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s15_insert_qc_history(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_stage14 public.booking_journey_stages;
  v_stage15 public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_stage14
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = 14
    AND stage.stage_key = 'editing_in_progress'
    AND stage.is_active;

  SELECT stage.*
  INTO v_stage15
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = 15
    AND stage.stage_key = 'qc_pending'
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
    v_stage14.id,
    v_stage15.id,
    'qc_pending',
    now(),
    'b1500000-0000-0000-0000-000000000101'
  );
END;
$$;


CREATE FUNCTION pg_temp.s11s15_capture_gate_error(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.mark_booking_qc_pending(p_booking_id);
  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


-- =====================================================================
-- Part 4 - Dedicated fixtures
-- =====================================================================

CREATE TEMP TABLE s11s15_ids (
  client_booking_id uuid,
  founder_booking_id uuid,
  studio_booking_id uuid,
  editor_booking_id uuid,
  branch_booking_id uuid,
  stage13_booking_id uuid,
  stage16_booking_id uuid,
  missing_lineage_booking_id uuid,
  missing_completion_booking_id uuid,
  duplicate_lineage_booking_id uuid,
  malformed_booking_id uuid,
  donor_booking_id uuid,
  preexisting_history_booking_id uuid,
  historical_booking_id uuid,
  invalid_replay_booking_id uuid
);

INSERT INTO s11s15_ids
VALUES (
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(
    'b1500000-0000-0000-0000-000000000702'
  ),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking(),
  pg_temp.s11s15_create_booking()
);

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000001'
);

SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT client_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT founder_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT studio_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT editor_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT branch_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT missing_completion_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT duplicate_lineage_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT malformed_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT donor_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT preexisting_history_booking_id FROM s11s15_ids)
);
SELECT pg_temp.s11s15_prepare_stage14(
  (SELECT historical_booking_id FROM s11s15_ids)
);

SELECT pg_temp.s11s15_set_stage_without_transition(
  (SELECT stage13_booking_id FROM s11s15_ids),
  13,
  'editing_pending'
);

SELECT pg_temp.s11s15_set_stage_without_transition(
  (SELECT stage16_booking_id FROM s11s15_ids),
  16,
  'pixieset_gallery_ready'
);

SELECT pg_temp.s11s15_set_stage_without_transition(
  (SELECT missing_lineage_booking_id FROM s11s15_ids),
  14,
  'editing_in_progress'
);

SELECT pg_temp.s11s15_set_stage_without_transition(
  (SELECT invalid_replay_booking_id FROM s11s15_ids),
  15,
  'qc_pending'
);


-- Canonical completion evidence is created under domain authority.
SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000004'
);

SELECT public.record_booking_editing_completion(
  (SELECT client_booking_id FROM s11s15_ids)
);
SELECT public.record_booking_editing_completion(
  (SELECT founder_booking_id FROM s11s15_ids)
);
SELECT public.record_booking_editing_completion(
  (SELECT studio_booking_id FROM s11s15_ids)
);
SELECT public.record_booking_editing_completion(
  (SELECT editor_booking_id FROM s11s15_ids)
);
SELECT public.record_booking_editing_completion(
  (SELECT branch_booking_id FROM s11s15_ids)
);
SELECT public.record_booking_editing_completion(
  (SELECT duplicate_lineage_booking_id FROM s11s15_ids)
);
SELECT public.record_booking_editing_completion(
  (SELECT malformed_booking_id FROM s11s15_ids)
);
SELECT public.record_booking_editing_completion(
  (SELECT preexisting_history_booking_id FROM s11s15_ids)
);


-- Historical Editor creates independently valid completion evidence.
SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000007'
);

SELECT public.record_booking_editing_completion(
  (SELECT historical_booking_id FROM s11s15_ids)
);


-- Founder performs transaction-local corruption setup.
SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000001'
);


-- Duplicate canonical Stage 13 -> 14 transition after evidence exists.
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
  'b1500000-0000-0000-0000-000000000101'::uuid
FROM public.booking_stage_transitions transition_row
WHERE transition_row.booking_id =
      (SELECT duplicate_lineage_booking_id FROM s11s15_ids)
  AND transition_row.transition_key = 'editing_in_progress'
ORDER BY transition_row.transitioned_at
LIMIT 1;


-- Corrupt one completion row to point at another booking's
-- otherwise-canonical Stage 13 -> 14 transition.
ALTER TABLE public.booking_editing_completions
DISABLE TRIGGER USER;

UPDATE public.booking_editing_completions completion
SET source_editing_in_progress_transition_id =
    (
      SELECT transition_row.id
      FROM public.booking_stage_transitions transition_row
      WHERE transition_row.booking_id =
            (SELECT donor_booking_id FROM s11s15_ids)
        AND transition_row.transition_key =
            'editing_in_progress'
      ORDER BY transition_row.transitioned_at
      LIMIT 1
    )
WHERE completion.booking_id =
      (SELECT malformed_booking_id FROM s11s15_ids);

ALTER TABLE public.booking_editing_completions
ENABLE TRIGGER USER;


-- Current Stage 14 may not coexist with pre-existing Stage 14 -> 15 history.
SELECT pg_temp.s11s15_insert_qc_history(
  (SELECT preexisting_history_booking_id FROM s11s15_ids)
);


-- Historical completion authority survives later actor suspension.
UPDATE public.organization_members
SET
  status = 'suspended',
  suspended_at = now()
WHERE id =
  'b1500000-0000-0000-0000-000000000107'::uuid;


CREATE TEMP TABLE s11s15_client_baseline AS
SELECT
  state.version AS state_version,
  (
    SELECT md5(to_jsonb(completion)::text)
    FROM public.booking_editing_completions completion
    WHERE completion.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
  ) AS completion_hash,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s15_ids)
      AND audit.action_key = 'booking.editing_completed'
  ) AS completion_audit_count
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT client_booking_id FROM s11s15_ids);


-- =====================================================================
-- Part 5 - Fail-closed authorization / stage / evidence
-- =====================================================================

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000001'
);

-- 12
SELECT throws_ok(
  $$ SELECT public.mark_booking_qc_pending(NULL) $$,
  '22023',
  'mark_booking_qc_pending: booking_id is required',
  'null booking id is rejected'
);

-- 13
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    'b15fffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'mark_booking_qc_pending: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s15_set_actor(NULL);

-- 14
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT client_booking_id FROM s11s15_ids)
  )
  $$,
  '42501',
  'mark_booking_qc_pending: authenticated actor required',
  'unauthenticated actor is rejected'
);

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000005'
);

-- 15
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT client_booking_id FROM s11s15_ids)
  )
  $$,
  '42501',
  'mark_booking_qc_pending: active organization membership required',
  'suspended organization member is rejected'
);

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000004'
);

-- 16
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT editor_booking_id FROM s11s15_ids)
  )
  $$,
  '42501',
  'mark_booking_qc_pending: booking.stage.advance permission required',
  'Editor cannot perform journey advancement'
);

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000006'
);

-- 17
SELECT ok(
  pg_temp.s11s15_capture_gate_error(
    (SELECT branch_booking_id FROM s11s15_ids)
  ) LIKE '42501:%',
  'branch-scoped Client Coordinator cannot advance another branch'
);

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000001'
);

-- 18
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT stage13_booking_id FROM s11s15_ids)
  )
  $$,
  '22023',
  'mark_booking_qc_pending: booking must be exactly Editing In Progress or QC Pending replay',
  'Stage 13 is rejected'
);

-- 19
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT stage16_booking_id FROM s11s15_ids)
  )
  $$,
  '22023',
  'mark_booking_qc_pending: booking must be exactly Editing In Progress or QC Pending replay',
  'Stage 16 is rejected'
);

-- 20
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT missing_lineage_booking_id FROM s11s15_ids)
  )
  $$,
  'P0001',
  'mark_booking_qc_pending: canonical Editing In Progress transition history is invalid',
  'Stage 14 without canonical Stage 13 to 14 lineage fails closed'
);

-- 21
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT missing_completion_booking_id FROM s11s15_ids)
  )
  $$,
  'P0001',
  'mark_booking_qc_pending: exactly one canonical Editing Completion evidence row required',
  'Stage 14 without Editing Completion evidence fails closed'
);

-- 22
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT duplicate_lineage_booking_id FROM s11s15_ids)
  )
  $$,
  'P0001',
  'mark_booking_qc_pending: canonical Editing In Progress transition history is invalid',
  'duplicate canonical Stage 13 to 14 lineage fails closed'
);

-- 23
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT malformed_booking_id FROM s11s15_ids)
  )
  $$,
  'P0001',
  'mark_booking_qc_pending: Editing Completion lineage is inconsistent',
  'malformed Editing Completion lineage fails closed'
);

-- 24
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT preexisting_history_booking_id FROM s11s15_ids)
  )
  $$,
  'P0001',
  'mark_booking_qc_pending: unexpected pre-existing QC Pending transition history',
  'Stage 14 with pre-existing Stage 14 to 15 history fails closed'
);


-- =====================================================================
-- Part 6 - Client Coordinator first-success contract
-- =====================================================================

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000003'
);

-- 25
SELECT lives_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT client_booking_id FROM s11s15_ids)
  )
  $$,
  'Client Coordinator may consume immutable Editing Completion evidence'
);

-- 26
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
  ),
  'qc_pending'::text,
  'first success moves booking exactly to Stage 15 QC Pending'
);

-- 27
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
  ),
  (
    SELECT state_version + 1
    FROM s11s15_client_baseline
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
        'b1500000-0000-0000-0000-000000000103'::uuid
      )
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id = transition_row.organization_id
     AND source_stage.id = transition_row.from_stage_id
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
      AND transition_row.transition_key = 'qc_pending'
      AND source_stage.stage_order = 14
      AND source_stage.stage_key = 'editing_in_progress'
      AND destination_stage.stage_order = 15
      AND destination_stage.stage_key = 'qc_pending'
  ),
  'first success creates exactly one actor-attributed Stage 14 to 15 transition'
);

-- 29
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(NOT audit.is_sensitive)
      AND bool_and(
        ARRAY(
          SELECT jsonb_object_keys(audit.metadata)
          ORDER BY 1
        ) = ARRAY[
          'booking_id',
          'editing_completed_at',
          'editing_completion_id',
          'prior_journey_version',
          'resulting_journey_version',
          'source_editing_in_progress_transition_id',
          'transition_key'
        ]::text[]
      )
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s15_ids)
      AND audit.action_key = 'booking.qc_pending'
  ),
  'first success creates one non-sensitive structural booking.qc_pending audit'
);

-- 30
SELECT ok(
  (
    SELECT
      (
        SELECT md5(to_jsonb(completion)::text)
        FROM public.booking_editing_completions completion
        WHERE completion.booking_id =
          (SELECT client_booking_id FROM s11s15_ids)
      ) = baseline.completion_hash
      AND
      (
        SELECT count(*)::bigint
        FROM public.audit_events audit
        WHERE audit.entity_id =
          (SELECT client_booking_id FROM s11s15_ids)
          AND audit.action_key = 'booking.editing_completed'
      ) = baseline.completion_audit_count
    FROM s11s15_client_baseline baseline
  ),
  'journey advancement neither mutates nor recreates Editing Completion evidence'
);

-- 31
SELECT is(
  (
    SELECT state.updated_by
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
  ),
  'b1500000-0000-0000-0000-000000000103'::uuid,
  'journey state update attributes the Client Coordinator'
);


CREATE TEMP TABLE s11s15_client_after_first AS
SELECT
  state.version AS state_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
      AND transition_row.transition_key = 'qc_pending'
  ) AS qc_transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s15_ids)
      AND audit.action_key = 'booking.qc_pending'
  ) AS qc_audit_count,
  (
    SELECT md5(to_jsonb(completion)::text)
    FROM public.booking_editing_completions completion
    WHERE completion.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
  ) AS completion_hash
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT client_booking_id FROM s11s15_ids);


-- =====================================================================
-- Part 7 - Strict Stage 15 replay
-- =====================================================================

-- 32
SELECT lives_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT client_booking_id FROM s11s15_ids)
  )
  $$,
  'exact Stage 15 replay succeeds'
);

-- 33
SELECT ok(
  (
    SELECT
      (
        SELECT state.version
        FROM public.booking_journey_states state
        WHERE state.booking_id =
          (SELECT client_booking_id FROM s11s15_ids)
      ) = after_first.state_version
      AND
      (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
          (SELECT client_booking_id FROM s11s15_ids)
          AND transition_row.transition_key = 'qc_pending'
      ) = after_first.qc_transition_count
      AND
      (
        SELECT count(*)::bigint
        FROM public.audit_events audit
        WHERE audit.entity_id =
          (SELECT client_booking_id FROM s11s15_ids)
          AND audit.action_key = 'booking.qc_pending'
      ) = after_first.qc_audit_count
    FROM s11s15_client_after_first after_first
  ),
  'Stage 15 replay creates no transition, audit or version change'
);

-- 34
SELECT is(
  (
    SELECT md5(to_jsonb(completion)::text)
    FROM public.booking_editing_completions completion
    WHERE completion.booking_id =
      (SELECT client_booking_id FROM s11s15_ids)
  ),
  (
    SELECT completion_hash
    FROM s11s15_client_after_first
  ),
  'Stage 15 replay leaves immutable Editing Completion evidence unchanged'
);


-- =====================================================================
-- Part 8 - Other journey actors / historical authority / bad replay
-- =====================================================================

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000001'
);

-- 35
SELECT lives_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT founder_booking_id FROM s11s15_ids)
  )
  $$,
  'Founder may advance canonical Editing Completion to QC Pending'
);

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000002'
);

-- 36
SELECT lives_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT studio_booking_id FROM s11s15_ids)
  )
  $$,
  'Studio Manager may advance canonical Editing Completion to QC Pending'
);

SELECT pg_temp.s11s15_set_actor(
  'b1500000-0000-0000-0000-000000000003'
);

-- 37
SELECT lives_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT historical_booking_id FROM s11s15_ids)
  )
  $$,
  'historical Editing Completion remains valid after completion actor suspension'
);

-- 38
SELECT throws_ok(
  $$
  SELECT public.mark_booking_qc_pending(
    (SELECT invalid_replay_booking_id FROM s11s15_ids)
  )
  $$,
  'P0001',
  'mark_booking_qc_pending: QC Pending replay history is invalid',
  'Stage 15 without canonical Stage 14 to 15 history fails closed'
);


SELECT * FROM finish();

ROLLBACK;
