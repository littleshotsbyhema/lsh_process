CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(53);

-- =====================================================================
-- Sprint 11 Slice 13
-- Controlled Stage 13 -> 14 / Editing In Progress Advancement Gate
-- =====================================================================


-- =====================================================================
-- Part 1 - Structural / ACL / authority contract
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions
  ),
  68::bigint,
  'canonical permission catalogue remains exactly 68'
);

-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions
  ),
  241::bigint,
  'canonical role-permission mapping count remains exactly 241'
);

-- 3
SELECT ok(
  to_regprocedure(
    'public.mark_booking_editing_in_progress(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(
      procedure.oid
    )
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_in_progress(uuid)'::regprocedure
  ) = 'bookings',
  'mark_booking_editing_in_progress(uuid) exists and returns bookings'
);

-- 4
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.pronamespace =
          'public'::regnamespace
      AND procedure.proname =
          'mark_booking_editing_in_progress'
  ),
  1::bigint,
  'exactly one Editing In Progress advancement signature exists'
);

-- 5
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_in_progress(uuid)'::regprocedure
  ),
  'Editing In Progress gate is SECURITY DEFINER'
);

-- 6
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_in_progress(uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'Editing In Progress gate fixes empty search_path'
);

-- 7
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_editing_in_progress(uuid)',
    'EXECUTE'
  ),
  'authenticated has Editing In Progress RPC EXECUTE'
);

-- 8
SELECT ok(
  NOT EXISTS (
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
      'public.mark_booking_editing_in_progress(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type =
          'EXECUTE'
  ),
  'PUBLIC has no Editing In Progress RPC EXECUTE'
);

-- 9
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.mark_booking_editing_in_progress(uuid)',
    'EXECUTE'
  ),
  'anon has no Editing In Progress RPC EXECUTE'
);

-- 10
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.mark_booking_editing_in_progress(uuid)',
    'EXECUTE'
  ),
  'service_role has no application Editing In Progress RPC EXECUTE'
);

-- 11
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
          'booking.stage.advance'
  ),
  ARRAY[
    'client_coordinator',
    'founder',
    'studio_manager'
  ]::text[],
  'booking.stage.advance topology remains exact'
);

-- 12
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
  'Editor does not gain journey-advance authority'
);

-- 13
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%booking.stage.advance%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%has_branch_scope%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_editing_starts%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_stage_transitions%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%editing_pending%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%editing_in_progress%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%FOR UPDATE%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%append_audit_event%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_in_progress(uuid)'::regprocedure
  ),
  'gate contains exact stage-advance, branch, Editing Start, transition, locking and audit authorities'
);

-- 14
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
        NOT ILIKE '%booking_selection_confirmations%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_selection_reconciliations%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_payment_requirements%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_payments%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_payment_reversals%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking_adjusted_financial_obligations%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%get_booking_full_balance_summary%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%started_by%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_in_progress(uuid)'::regprocedure
  ),
  'gate imports no editing-write, finance, payment, selection, assignment or historical-starter authority'
);

-- 15
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
      AND relation.relname <>
          'booking_editing_starts'
  ),
  0::bigint,
  'Slice 13 creates no new editing persistence relation'
);

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_proc procedure
    JOIN pg_catalog.pg_namespace namespace
      ON namespace.oid =
         procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.prokind = 'f'
      AND pg_get_functiondef(
            procedure.oid
          ) ILIKE '%editing_in_progress%'
  ),
  1::bigint,
  'mark_booking_editing_in_progress is the only Stage-14 function'
);


-- =====================================================================
-- Part 2 - Transaction-local identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('b1300000-0000-0000-0000-000000000001'::uuid),
  ('b1300000-0000-0000-0000-000000000002'::uuid),
  ('b1300000-0000-0000-0000-000000000003'::uuid),
  ('b1300000-0000-0000-0000-000000000004'::uuid),
  ('b1300000-0000-0000-0000-000000000005'::uuid),
  ('b1300000-0000-0000-0000-000000000006'::uuid),
  ('b1300000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  'b1300000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice13 Branch A',
  's11s13-a',
  'active'
),
(
  'b1300000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice13 Branch B',
  's11s13-b',
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
  'b1300000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1300000-0000-0000-0000-000000000001',
  'active',
  'S11S13 Founder',
  NULL
),
(
  'b1300000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1300000-0000-0000-0000-000000000002',
  'active',
  'S11S13 Studio Manager',
  NULL
),
(
  'b1300000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1300000-0000-0000-0000-000000000003',
  'active',
  'S11S13 Client Coordinator',
  NULL
),
(
  'b1300000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1300000-0000-0000-0000-000000000004',
  'active',
  'S11S13 Editor',
  NULL
),
(
  'b1300000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1300000-0000-0000-0000-000000000005',
  'suspended',
  'S11S13 Suspended Founder',
  now()
),
(
  'b1300000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1300000-0000-0000-0000-000000000006',
  'active',
  'S11S13 Branch Coordinator',
  NULL
),
(
  'b1300000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1300000-0000-0000-0000-000000000007',
  'active',
  'S11S13 Historical Editor',
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
      'b1300000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1300000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      'b1300000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      'b1300000-0000-0000-0000-000000000104'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      'b1300000-0000-0000-0000-000000000105'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1300000-0000-0000-0000-000000000106'::uuid,
      'client_coordinator'::text,
      'b1300000-0000-0000-0000-000000000701'::uuid
    ),
    (
      'b1300000-0000-0000-0000-000000000107'::uuid,
      'editor'::text,
      NULL::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;


CREATE FUNCTION pg_temp.s11s13_set_actor(
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


SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000001'
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
  'b1300000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-C3DEFG',
  'S11 Slice13 Family',
  'S11 Slice13 Family',
  'active',
  'b1300000-0000-0000-0000-000000000101',
  'b1300000-0000-0000-0000-000000000101'
);


-- =====================================================================
-- Part 3 - Canonical booking + transaction-local journey helpers
-- =====================================================================

CREATE FUNCTION pg_temp.s11s13_create_booking(
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
    'b1300000-0000-0000-0000-000000000201',
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


CREATE FUNCTION pg_temp.s11s13_set_stage_without_transition(
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
      'S11S13 fixture target stage unavailable: % %',
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
      'b1300000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s13_prepare_stage13(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_stage12 public.booking_journey_stages;
  v_stage13 public.booking_journey_stages;
BEGIN
  PERFORM pg_temp.s11s13_set_stage_without_transition(
    p_booking_id,
    12,
    'selection_pending'
  );

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.*
  INTO v_stage12
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order = 12
    AND stage.stage_key =
        'selection_pending'
    AND stage.is_active;

  SELECT stage.*
  INTO v_stage13
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order = 13
    AND stage.stage_key =
        'editing_pending'
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
    v_stage12.id,
    v_stage13.id,
    'editing_pending',
    now(),
    'b1300000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_stage13.id,
    stage_entered_at =
      now(),
    version =
      state.version + 1,
    updated_at =
      now(),
    updated_by =
      'b1300000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s13_insert_stage14_history(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_stage13 public.booking_journey_stages;
  v_stage14 public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.*
  INTO v_stage13
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order = 13
    AND stage.stage_key =
        'editing_pending'
    AND stage.is_active;

  SELECT stage.*
  INTO v_stage14
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order = 14
    AND stage.stage_key =
        'editing_in_progress'
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
    v_stage13.id,
    v_stage14.id,
    'editing_in_progress',
    now(),
    'b1300000-0000-0000-0000-000000000101'
  );
END;
$$;


CREATE FUNCTION pg_temp.s11s13_capture_gate_error(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.mark_booking_editing_in_progress(
    p_booking_id
  );

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


-- =====================================================================
-- Part 4 - Build dedicated Slice-13 fixtures
-- =====================================================================

CREATE TEMP TABLE s11s13_ids (
  client_booking_id uuid,
  founder_booking_id uuid,
  studio_booking_id uuid,
  editor_booking_id uuid,
  branch_booking_id uuid,
  stage12_booking_id uuid,
  stage15_booking_id uuid,
  missing_evidence_booking_id uuid,
  missing_lineage_booking_id uuid,
  duplicate_lineage_booking_id uuid,
  malformed_booking_id uuid,
  donor_booking_id uuid,
  preexisting_history_booking_id uuid,
  historical_booking_id uuid
);

INSERT INTO s11s13_ids
VALUES (
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(
    'b1300000-0000-0000-0000-000000000702'
  ),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking(),
  pg_temp.s11s13_create_booking()
);


SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000001'
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT client_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT founder_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT studio_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT editor_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT branch_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT stage15_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT missing_evidence_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT duplicate_lineage_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT malformed_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT donor_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT preexisting_history_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_prepare_stage13(
  (SELECT historical_booking_id FROM s11s13_ids)
);

SELECT pg_temp.s11s13_set_stage_without_transition(
  (SELECT stage12_booking_id FROM s11s13_ids),
  12,
  'selection_pending'
);

SELECT pg_temp.s11s13_set_stage_without_transition(
  (SELECT missing_lineage_booking_id FROM s11s13_ids),
  13,
  'editing_pending'
);


-- Create canonical Editing Start evidence under editing.write.
SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000004'
);

SELECT public.record_booking_editing_start(
  (SELECT client_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT founder_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT studio_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT editor_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT branch_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT stage15_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT duplicate_lineage_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT malformed_booking_id FROM s11s13_ids)
);

SELECT public.record_booking_editing_start(
  (SELECT preexisting_history_booking_id FROM s11s13_ids)
);


-- Historical Editor independently creates valid evidence.
SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000007'
);

SELECT public.record_booking_editing_start(
  (SELECT historical_booking_id FROM s11s13_ids)
);


-- Founder performs transaction-local corruption setup.
SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000001'
);


-- Duplicate canonical Stage 12 -> 13 history after valid evidence exists.
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
  'b1300000-0000-0000-0000-000000000101'::uuid
FROM public.booking_stage_transitions transition_row
WHERE transition_row.booking_id =
      (
        SELECT duplicate_lineage_booking_id
        FROM s11s13_ids
      )
  AND transition_row.transition_key =
      'editing_pending'
ORDER BY transition_row.transitioned_at
LIMIT 1;


-- Stage 15 is outside Slice-13 replay.
SELECT pg_temp.s11s13_set_stage_without_transition(
  (SELECT stage15_booking_id FROM s11s13_ids),
  15,
  'qc_pending'
);


-- Corrupt one otherwise-valid immutable Editing Start row to point at
-- another booking's Stage 12 -> 13 transition.
ALTER TABLE public.booking_editing_starts
DISABLE TRIGGER USER;

UPDATE public.booking_editing_starts editing_start
SET source_editing_pending_transition_id =
    (
      SELECT transition_row.id
      FROM public.booking_stage_transitions transition_row
      WHERE transition_row.booking_id =
            (
              SELECT donor_booking_id
              FROM s11s13_ids
            )
        AND transition_row.transition_key =
            'editing_pending'
      ORDER BY transition_row.transitioned_at
      LIMIT 1
    )
WHERE editing_start.booking_id =
      (
        SELECT malformed_booking_id
        FROM s11s13_ids
      );

ALTER TABLE public.booking_editing_starts
ENABLE TRIGGER USER;


-- Stage 13 current state may not coexist with pre-existing Stage 13 -> 14
-- history.
SELECT pg_temp.s11s13_insert_stage14_history(
  (SELECT preexisting_history_booking_id FROM s11s13_ids)
);


-- Historical Editing Start authority must survive later starter suspension.
UPDATE public.organization_members
SET
  status = 'suspended',
  suspended_at = now()
WHERE id =
  'b1300000-0000-0000-0000-000000000107'::uuid;


-- Snapshot exact first-success baseline.
CREATE TEMP TABLE s11s13_client_baseline AS
SELECT
  state.version AS state_version,
  state.current_stage_id,
  state.updated_by,
  (
    SELECT md5(
      to_jsonb(editing_start)::text
    )
    FROM public.booking_editing_starts editing_start
    WHERE editing_start.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS editing_start_hash,
  (
    SELECT count(*)
    FROM public.booking_selection_confirmations
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS confirmation_count,
  (
    SELECT count(*)
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS reconciliation_count,
  (
    SELECT count(*)
    FROM public.booking_payment_requirements
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS payment_requirement_count,
  (
    SELECT count(*)
    FROM public.booking_payments
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS payment_count,
  (
    SELECT count(*)
    FROM public.booking_payment_reversals
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS reversal_count,
  (
    SELECT count(*)
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS adjusted_obligation_count,
  (
    SELECT count(*)
    FROM public.booking_team_assignments
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS assignment_count
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT client_booking_id FROM s11s13_ids);


-- =====================================================================
-- Part 5 - Fail-closed authorization / stage / evidence boundaries
-- =====================================================================

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000001'
);

-- 17
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(NULL)
  $$,
  '22023',
  'mark_booking_editing_in_progress: booking_id is required',
  'null booking id is rejected'
);

-- 18
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    'b13fffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'mark_booking_editing_in_progress: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s13_set_actor(NULL);

-- 19
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT editor_booking_id FROM s11s13_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_in_progress: authenticated actor required',
  'unauthenticated actor is rejected'
);

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000005'
);

-- 20
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT editor_booking_id FROM s11s13_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_in_progress: active organization membership required',
  'suspended organization member is rejected'
);

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000004'
);

-- 21
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT editor_booking_id FROM s11s13_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_in_progress: booking.stage.advance permission required',
  'Editor is rejected despite editing.write authority'
);

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000006'
);

-- 22
SELECT ok(
  pg_temp.s11s13_capture_gate_error(
    (SELECT branch_booking_id FROM s11s13_ids)
  ) LIKE '42501:%',
  'branch-scoped Client Coordinator is rejected for another branch'
);

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000001'
);

-- 23
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT stage12_booking_id FROM s11s13_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_in_progress: booking must be exactly Editing Pending or Editing In Progress replay',
  'Stage 12 is rejected'
);

-- 24
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT stage15_booking_id FROM s11s13_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_in_progress: booking must be exactly Editing Pending or Editing In Progress replay',
  'Stage 15 is rejected and is not accepted as replay'
);

-- 25
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT missing_evidence_booking_id FROM s11s13_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_in_progress: exactly one canonical Editing Start evidence row required',
  'Stage 13 without Editing Start evidence is rejected'
);

-- 26
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT missing_lineage_booking_id FROM s11s13_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_in_progress: canonical Editing Pending transition history is invalid',
  'Stage 13 without canonical Stage 12 to 13 lineage is rejected'
);

-- 27
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT duplicate_lineage_booking_id FROM s11s13_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_in_progress: canonical Editing Pending transition history is invalid',
  'duplicate canonical Stage 12 to 13 lineage fails closed'
);

-- 28
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT malformed_booking_id FROM s11s13_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_in_progress: Editing Start lineage is inconsistent',
  'malformed pre-existing Editing Start lineage fails closed'
);

-- 29
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT preexisting_history_booking_id FROM s11s13_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_in_progress: unexpected pre-existing Editing In Progress transition history',
  'Stage 13 state with pre-existing Stage 13 to 14 history fails closed'
);


-- =====================================================================
-- Part 6 - Client Coordinator first-success contract
-- =====================================================================

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000003'
);

-- 30
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT client_booking_id FROM s11s13_ids)
  )
  $$,
  'Client Coordinator may consume canonical Editing Start evidence'
);

-- 31
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
      (SELECT client_booking_id FROM s11s13_ids)
  ),
  'editing_in_progress'::text,
  'first success moves booking exactly to Stage 14 Editing In Progress'
);

-- 32
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ),
  (
    SELECT state_version + 1
    FROM s11s13_client_baseline
  ),
  'first success increments journey version exactly once'
);

-- 33
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
      (SELECT client_booking_id FROM s11s13_ids)
      AND transition_row.transition_key =
          'editing_in_progress'
      AND source_stage.stage_order = 13
      AND source_stage.stage_key =
          'editing_pending'
      AND destination_stage.stage_order = 14
      AND destination_stage.stage_key =
          'editing_in_progress'
  ),
  1::bigint,
  'first success appends exactly one canonical Stage 13 to 14 transition'
);

-- 34
SELECT is(
  (
    SELECT transition_row.transitioned_by
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND transition_row.transition_key =
          'editing_in_progress'
  ),
  'b1300000-0000-0000-0000-000000000103'::uuid,
  'Stage 13 to 14 transition attributes Client Coordinator actor'
);

-- 35
SELECT is(
  (
    SELECT state.updated_by
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ),
  'b1300000-0000-0000-0000-000000000103'::uuid,
  'journey state attribution records Client Coordinator actor'
);

-- 36
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND audit.action_key =
          'booking.editing_in_progress'
  ),
  1::bigint,
  'first success appends exactly one booking.editing_in_progress audit'
);

-- 37
SELECT ok(
  (
    SELECT NOT audit.is_sensitive
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND audit.action_key =
          'booking.editing_in_progress'
  ),
  'Editing In Progress audit is explicitly non-sensitive'
);

-- 38
SELECT ok(
  (
    SELECT lower(
      concat_ws(
        ' ',
        audit.old_values::text,
        audit.new_values::text,
        audit.metadata::text
      )
    ) !~
    '(payment|amount|inr|refund|overpayment|selection|editor|external|priority|deadline|sla|qc|gallery|delivery|assigned)'
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND audit.action_key =
          'booking.editing_in_progress'
  ),
  'Editing In Progress audit leaks no finance, selection, assignment, SLA, QC or delivery semantics'
);

-- 39
SELECT is(
  (
    SELECT md5(
      to_jsonb(editing_start)::text
    )
    FROM public.booking_editing_starts editing_start
    WHERE editing_start.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ),
  (
    SELECT editing_start_hash
    FROM s11s13_client_baseline
  ),
  'Stage 13 to 14 advancement does not mutate immutable Editing Start evidence'
);

-- 40
SELECT ok(
  (
    SELECT
      (
        SELECT count(*)
        FROM public.booking_selection_confirmations
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s13_ids)
      ) = baseline.confirmation_count
      AND
      (
        SELECT count(*)
        FROM public.booking_selection_reconciliations
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s13_ids)
      ) = baseline.reconciliation_count
      AND
      (
        SELECT count(*)
        FROM public.booking_payment_requirements
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s13_ids)
      ) = baseline.payment_requirement_count
      AND
      (
        SELECT count(*)
        FROM public.booking_payments
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s13_ids)
      ) = baseline.payment_count
      AND
      (
        SELECT count(*)
        FROM public.booking_payment_reversals
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s13_ids)
      ) = baseline.reversal_count
      AND
      (
        SELECT count(*)
        FROM public.booking_adjusted_financial_obligations
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s13_ids)
      ) = baseline.adjusted_obligation_count
    FROM s11s13_client_baseline baseline
  ),
  'Stage 14 gate neither re-evaluates nor mutates upstream selection/payment/finance evidence'
);

-- 41
SELECT is(
  (
    SELECT count(*)
    FROM public.booking_team_assignments
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ),
  (
    SELECT assignment_count
    FROM s11s13_client_baseline
  ),
  'Stage 14 gate creates no editor or booking-team assignment'
);


CREATE TEMP TABLE s11s13_client_after_first AS
SELECT
  state.version AS state_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND transition_row.transition_key =
          'editing_in_progress'
  ) AS destination_transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND audit.action_key =
          'booking.editing_in_progress'
  ) AS audit_count,
  (
    SELECT md5(
      to_jsonb(editing_start)::text
    )
    FROM public.booking_editing_starts editing_start
    WHERE editing_start.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ) AS editing_start_hash
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT client_booking_id FROM s11s13_ids);


-- =====================================================================
-- Part 7 - Exact Stage-14 replay
-- =====================================================================

-- 42
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT client_booking_id FROM s11s13_ids)
  )
  $$,
  'exact Stage 14 replay succeeds idempotently'
);

-- 43
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ),
  (
    SELECT state_version
    FROM s11s13_client_after_first
  ),
  'Stage 14 replay does not increment journey version'
);

-- 44
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND transition_row.transition_key =
          'editing_in_progress'
  ),
  (
    SELECT destination_transition_count
    FROM s11s13_client_after_first
  ),
  'Stage 14 replay appends no second transition'
);

-- 45
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s13_ids)
      AND audit.action_key =
          'booking.editing_in_progress'
  ),
  (
    SELECT audit_count
    FROM s11s13_client_after_first
  ),
  'Stage 14 replay appends no second audit'
);

-- 46
SELECT is(
  (
    SELECT md5(
      to_jsonb(editing_start)::text
    )
    FROM public.booking_editing_starts editing_start
    WHERE editing_start.booking_id =
      (SELECT client_booking_id FROM s11s13_ids)
  ),
  (
    SELECT editing_start_hash
    FROM s11s13_client_after_first
  ),
  'Stage 14 replay leaves Editing Start evidence untouched'
);


-- =====================================================================
-- Part 8 - Founder / Studio Manager journey authority
-- =====================================================================

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000001'
);

-- 47
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT founder_booking_id FROM s11s13_ids)
  )
  $$,
  'Founder may advance canonical Editing Start evidence to Stage 14'
);

-- 48
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
      (SELECT founder_booking_id FROM s11s13_ids)
  ),
  'editing_in_progress'::text,
  'Founder success reaches exact Stage 14'
);

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000002'
);

-- 49
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT studio_booking_id FROM s11s13_ids)
  )
  $$,
  'Studio Manager may advance canonical Editing Start evidence to Stage 14'
);

-- 50
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
      (SELECT studio_booking_id FROM s11s13_ids)
  ),
  'editing_in_progress'::text,
  'Studio Manager success reaches exact Stage 14'
);


-- =====================================================================
-- Part 9 - Historical Editing Start survives starter suspension
-- =====================================================================

SELECT pg_temp.s11s13_set_actor(
  'b1300000-0000-0000-0000-000000000003'
);

-- 51
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_in_progress(
    (SELECT historical_booking_id FROM s11s13_ids)
  )
  $$,
  'later suspension of historical Editing Start actor does not invalidate canonical evidence'
);

-- 52
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
      (SELECT historical_booking_id FROM s11s13_ids)
  ),
  'editing_in_progress'::text,
  'historical valid Editing Start evidence still permits Stage 14 advancement'
);

-- 53
SELECT is(
  (
    SELECT editing_start.started_by
    FROM public.booking_editing_starts editing_start
    WHERE editing_start.booking_id =
      (SELECT historical_booking_id FROM s11s13_ids)
  ),
  'b1300000-0000-0000-0000-000000000107'::uuid,
  'historical Editing Start attribution remains immutable after starter suspension'
);


SELECT * FROM finish();

ROLLBACK;
