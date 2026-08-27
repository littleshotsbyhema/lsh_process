CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(59);

-- =====================================================================
-- Sprint 11 Slice 11
-- Controlled Stage 12 -> 13 / Editing Pending Advancement Gate
-- =====================================================================


-- =====================================================================
-- Part 1 - Structural / ACL / authorization contract
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
    'public.mark_booking_editing_pending(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
  ) = 'bookings',
  'mark_booking_editing_pending(uuid) exists and returns bookings'
);

-- 4
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.pronamespace =
          'public'::regnamespace
      AND procedure.proname =
          'mark_booking_editing_pending'
  ),
  1::bigint,
  'exactly one Stage 12 -> 13 RPC signature exists'
);

-- 5
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
  ),
  'RPC is SECURITY DEFINER'
);

-- 6
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'RPC fixes empty search_path'
);

-- 7
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_editing_pending(uuid)',
    'EXECUTE'
  ),
  'authenticated has EXECUTE'
);

-- 8
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault('f', procedure.proowner)
      )
    ) acl
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no EXECUTE'
);

-- 9
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.mark_booking_editing_pending(uuid)',
    'EXECUTE'
  ),
  'anon has no EXECUTE'
);

-- 10
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.mark_booking_editing_pending(uuid)',
    'EXECUTE'
  ),
  'service_role has no application EXECUTE'
);

-- 11
SELECT is(
  (
    SELECT array_agg(role.key ORDER BY role.key)
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    JOIN public.roles role
      ON role.id =
         role_permission.role_id
    WHERE permission.key =
          'booking.stage.advance'
  ),
  ARRAY[
    'client_coordinator',
    'founder',
    'studio_manager'
  ]::text[],
  'booking.stage.advance role identities remain exact'
);

-- 12
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    JOIN public.roles role
      ON role.id =
         role_permission.role_id
    WHERE role.key = 'editor'
      AND permission.key = 'editing.write'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    JOIN public.roles role
      ON role.id =
         role_permission.role_id
    WHERE role.key = 'editor'
      AND permission.key = 'booking.stage.advance'
  ),
  'Editor has editing.write but not booking.stage.advance'
);

-- 13
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    JOIN public.roles role
      ON role.id =
         role_permission.role_id
    WHERE role.key = 'client_coordinator'
      AND permission.key = 'booking.stage.advance'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    JOIN public.roles role
      ON role.id =
         role_permission.role_id
    WHERE role.key = 'client_coordinator'
      AND permission.key IN (
        'editing.write',
        'finance.read'
      )
  ),
  'Client Coordinator has stage authority without editing.write or finance.read'
);

-- 14
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%booking.stage.advance%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%has_branch_scope%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
  ),
  'RPC enforces booking.stage.advance plus branch containment'
);

-- 15
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        NOT ILIKE '%editing.write%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%finance.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%get_booking_full_balance_summary%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
  ),
  'RPC imports neither editing/finance read authority nor public balance-summary authorization'
);

-- 16
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%booking_selection_confirmations%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_selection_reconciliations%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_payment_requirements%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_adjusted_financial_obligations%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_payments%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking_payment_reversals%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_editing_pending(uuid)'::regprocedure
  ),
  'RPC consumes every frozen selection and financial authority'
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
  'Slice 11 creates no editing-job persistence relation'
);

-- 18
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class relation
    JOIN pg_catalog.pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND (
        relation.relname ILIKE '%settlement%'
        OR relation.relname ILIKE '%full_balance%'
        OR relation.relname ILIKE '%refund_due%'
      )
  ),
  0::bigint,
  'Slice 11 creates no settlement or refund persistence relation'
);

-- 19
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key IN (
      'editing.pending',
      'booking.editing.pending',
      'booking.editing.advance'
    )
  ),
  0::bigint,
  'Slice 11 introduces no stage-specific editing permission'
);


-- =====================================================================
-- Part 2 - Canonical transaction-local identities and helpers
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('b1100000-0000-0000-0000-000000000001'::uuid),
  ('b1100000-0000-0000-0000-000000000002'::uuid),
  ('b1100000-0000-0000-0000-000000000003'::uuid),
  ('b1100000-0000-0000-0000-000000000004'::uuid),
  ('b1100000-0000-0000-0000-000000000005'::uuid),
  ('b1100000-0000-0000-0000-000000000006'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  'b1100000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice11 Branch A',
  's11s11-a',
  'active'
),
(
  'b1100000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice11 Branch B',
  's11s11-b',
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
  'b1100000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000001',
  'active',
  'S11S11 Founder',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000002',
  'active',
  'S11S11 Studio Manager',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000003',
  'active',
  'S11S11 Client Coordinator',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000004',
  'active',
  'S11S11 Editor',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000005',
  'suspended',
  'S11S11 Suspended Founder',
  now()
),
(
  'b1100000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000006',
  'active',
  'S11S11 Branch Coordinator',
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
      'b1100000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1100000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      'b1100000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      'b1100000-0000-0000-0000-000000000104'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      'b1100000-0000-0000-0000-000000000105'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1100000-0000-0000-0000-000000000106'::uuid,
      'client_coordinator'::text,
      'b1100000-0000-0000-0000-000000000701'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s11_set_actor(
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

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000001'
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
  'b1100000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-B3CDEF',
  'S11 Slice11 Family',
  'S11 Slice11 Family',
  'active',
  'b1100000-0000-0000-0000-000000000101',
  'b1100000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s11s11_create_booking(
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
    'b1100000-0000-0000-0000-000000000201',
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

CREATE FUNCTION pg_temp.s11s11_move_to_stage(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_transition_key text
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
    p_transition_key,
    now(),
    'b1100000-0000-0000-0000-000000000101'
  );

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
      'b1100000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s11_set_stage_without_transition(
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
      'b1100000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s11_prepare_stage12(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s11_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    's11s11_fixture_shoot_completed'
  );

  PERFORM pg_temp.s11s11_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    'selection_pending'
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s11_included_count(
  p_booking_id uuid
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_included integer;
BEGIN
  SELECT entitlement.retouched_image_count_per_unit
  INTO v_included
  FROM public.bookings booking
  JOIN public.quotation_line_items line_item
    ON line_item.organization_id =
       booking.organization_id
   AND line_item.quotation_id =
       booking.source_quotation_id
   AND line_item.line_type =
       'package'::public.quotation_line_type
  JOIN public.commercial_image_entitlements entitlement
    ON entitlement.organization_id =
       line_item.organization_id
   AND entitlement.package_version_id =
       line_item.source_package_version_id
  WHERE booking.id =
        p_booking_id;

  RETURN v_included;
END;
$$;

CREATE FUNCTION pg_temp.s11s11_record_confirmation_only(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_included integer;
BEGIN
  PERFORM pg_temp.s11s11_prepare_stage12(
    p_booking_id
  );

  v_included :=
    pg_temp.s11s11_included_count(
      p_booking_id
    );

  PERFORM public.record_booking_selection_confirmation(
    p_booking_id,
    v_included,
    now()
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s11_prepare_reconciliation(
  p_booking_id uuid,
  p_excess integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_included integer;
BEGIN
  PERFORM pg_temp.s11s11_prepare_stage12(
    p_booking_id
  );

  v_included :=
    pg_temp.s11s11_included_count(
      p_booking_id
    );

  PERFORM public.record_booking_selection_confirmation(
    p_booking_id,
    v_included + p_excess,
    now()
  );

  PERFORM public.record_booking_selection_reconciliation(
    p_booking_id
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s11_prepare_positive(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s11_prepare_reconciliation(
    p_booking_id,
    3
  );

  PERFORM public.record_booking_additional_image_pricing_basis(
    p_booking_id,
    NULL
  );

  PERFORM public.record_booking_adjusted_financial_obligation(
    p_booking_id
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s11_pay_target(
  p_booking_id uuid,
  p_delta integer DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_excess integer;
  v_target bigint;
  v_payment_id uuid;
BEGIN
  SELECT reconciliation.excess_image_count
  INTO v_excess
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.booking_id =
        p_booking_id;

  IF v_excess = 0 THEN
    SELECT requirement.accepted_quotation_total_inr::bigint
    INTO v_target
    FROM public.booking_payment_requirements requirement
    WHERE requirement.booking_id =
          p_booking_id;
  ELSE
    SELECT obligation.adjusted_total_inr
    INTO v_target
    FROM public.booking_adjusted_financial_obligations obligation
    WHERE obligation.booking_id =
          p_booking_id;
  END IF;

  IF v_target + p_delta <= 0 THEN
    RAISE EXCEPTION
      'S11S11 payment fixture target must remain positive';
  END IF;

  SELECT (
    public.record_booking_payment(
      p_booking_id,
      (v_target + p_delta)::integer,
      'upi'::public.booking_payment_method,
      now(),
      'S11S11-' ||
        left(
          replace(
            p_booking_id::text,
            '-',
            ''
          ),
          12
        ),
      'Sprint 11 Slice 11 fixture payment'
    )
  ).id
  INTO v_payment_id;

  RETURN v_payment_id;
END;
$$;


-- =====================================================================
-- Part 3 - Build canonical fixtures
-- =====================================================================

CREATE TEMP TABLE s11s11_ids (
  client_booking_id uuid,
  client_payment_id uuid,
  founder_positive_booking_id uuid,
  studio_over_booking_id uuid,
  under_booking_id uuid,
  missing_confirmation_booking_id uuid,
  missing_reconciliation_booking_id uuid,
  missing_requirement_booking_id uuid,
  missing_obligation_booking_id uuid,
  zero_conflict_booking_id uuid,
  corrupt_obligation_booking_id uuid,
  wrong_stage_booking_id uuid,
  missing_lineage_booking_id uuid,
  invalid_replay_booking_id uuid,
  branch_b_booking_id uuid
);

INSERT INTO s11s11_ids
VALUES (
  pg_temp.s11s11_create_booking(),
  NULL,
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(),
  pg_temp.s11s11_create_booking(
    'b1100000-0000-0000-0000-000000000702'
  )
);

SELECT pg_temp.s11s11_prepare_reconciliation(
  (SELECT client_booking_id FROM s11s11_ids),
  0
);

UPDATE s11s11_ids
SET client_payment_id =
  pg_temp.s11s11_pay_target(
    client_booking_id,
    0
  );

SELECT pg_temp.s11s11_prepare_positive(
  (SELECT founder_positive_booking_id FROM s11s11_ids)
);

SELECT pg_temp.s11s11_pay_target(
  (SELECT founder_positive_booking_id FROM s11s11_ids),
  0
);

SELECT pg_temp.s11s11_prepare_reconciliation(
  (SELECT studio_over_booking_id FROM s11s11_ids),
  0
);

SELECT pg_temp.s11s11_pay_target(
  (SELECT studio_over_booking_id FROM s11s11_ids),
  250
);

SELECT pg_temp.s11s11_prepare_reconciliation(
  (SELECT under_booking_id FROM s11s11_ids),
  0
);

SELECT pg_temp.s11s11_pay_target(
  (SELECT under_booking_id FROM s11s11_ids),
  -100
);

SELECT pg_temp.s11s11_prepare_stage12(
  (SELECT missing_confirmation_booking_id FROM s11s11_ids)
);

SELECT pg_temp.s11s11_record_confirmation_only(
  (SELECT missing_reconciliation_booking_id FROM s11s11_ids)
);

SELECT pg_temp.s11s11_prepare_reconciliation(
  (SELECT missing_requirement_booking_id FROM s11s11_ids),
  0
);

SELECT pg_temp.s11s11_prepare_reconciliation(
  (SELECT missing_obligation_booking_id FROM s11s11_ids),
  3
);

SELECT public.record_booking_additional_image_pricing_basis(
  (SELECT missing_obligation_booking_id FROM s11s11_ids),
  NULL
);

SELECT pg_temp.s11s11_prepare_positive(
  (SELECT zero_conflict_booking_id FROM s11s11_ids)
);

SELECT pg_temp.s11s11_prepare_positive(
  (SELECT corrupt_obligation_booking_id FROM s11s11_ids)
);

SELECT pg_temp.s11s11_set_stage_without_transition(
  (SELECT missing_lineage_booking_id FROM s11s11_ids),
  12,
  'selection_pending'
);

SELECT pg_temp.s11s11_set_stage_without_transition(
  (SELECT invalid_replay_booking_id FROM s11s11_ids),
  13,
  'editing_pending'
);

SELECT pg_temp.s11s11_prepare_reconciliation(
  (SELECT branch_b_booking_id FROM s11s11_ids),
  0
);

SELECT pg_temp.s11s11_pay_target(
  (SELECT branch_b_booking_id FROM s11s11_ids),
  0
);

-- Transaction-local corruption fixture: remove payment requirement.

ALTER TABLE public.booking_payment_requirements
DISABLE TRIGGER USER;

DELETE FROM public.booking_payment_requirements
WHERE booking_id =
  (SELECT missing_requirement_booking_id FROM s11s11_ids);

ALTER TABLE public.booking_payment_requirements
ENABLE TRIGGER USER;

-- Transaction-local corruption fixture:
-- turn a valid positive reconciliation into zero excess while retaining
-- the existing adjusted obligation and preserving confirmation lineage.

ALTER TABLE public.booking_selection_confirmations
DISABLE TRIGGER USER;

UPDATE public.booking_selection_confirmations confirmation
SET selected_image_count =
    reconciliation.included_image_count
FROM public.booking_selection_reconciliations reconciliation
WHERE confirmation.booking_id =
      (SELECT zero_conflict_booking_id FROM s11s11_ids)
  AND reconciliation.booking_id =
      confirmation.booking_id;

ALTER TABLE public.booking_selection_confirmations
ENABLE TRIGGER USER;

ALTER TABLE public.booking_selection_reconciliations
DISABLE TRIGGER USER;

UPDATE public.booking_selection_reconciliations
SET
  selected_image_count =
    included_image_count,
  excess_image_count = 0
WHERE booking_id =
  (SELECT zero_conflict_booking_id FROM s11s11_ids);

ALTER TABLE public.booking_selection_reconciliations
ENABLE TRIGGER USER;

-- Transaction-local adjusted-obligation lineage corruption.

ALTER TABLE public.booking_adjusted_financial_obligations
DISABLE TRIGGER USER;

UPDATE public.booking_adjusted_financial_obligations
SET
  accepted_quotation_total_inr =
    accepted_quotation_total_inr + 1,
  adjusted_total_inr =
    adjusted_total_inr + 1
WHERE booking_id =
  (SELECT corrupt_obligation_booking_id FROM s11s11_ids);

ALTER TABLE public.booking_adjusted_financial_obligations
ENABLE TRIGGER USER;

CREATE TEMP TABLE s11s11_client_baseline AS
SELECT
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ) AS state_version,
  (
    SELECT count(*)
    FROM public.booking_payments
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ) AS payment_count,
  (
    SELECT count(*)
    FROM public.booking_payment_reversals
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ) AS reversal_count,
  (
    SELECT count(*)
    FROM public.booking_selection_confirmations
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ) AS confirmation_count,
  (
    SELECT count(*)
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ) AS reconciliation_count,
  (
    SELECT count(*)
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ) AS obligation_count;


-- =====================================================================
-- Part 4 - Fail-closed authorization and evidence boundary
-- =====================================================================

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

-- 20
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(NULL)
  $$,
  '22023',
  'mark_booking_editing_pending: booking_id is required',
  'null booking id is rejected'
);

-- 21
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    'b11fffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'mark_booking_editing_pending: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s11_set_actor(NULL);

-- 22
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT client_booking_id FROM s11s11_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_pending: authenticated actor required',
  'unauthenticated actor is rejected'
);

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000005'
);

-- 23
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT client_booking_id FROM s11s11_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_pending: active organization membership required',
  'suspended member is rejected'
);

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000004'
);

-- 24
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT client_booking_id FROM s11s11_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_pending: booking.stage.advance permission required',
  'Editor cannot advance through editing.write'
);

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000006'
);

-- 25
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT branch_b_booking_id FROM s11s11_ids)
  )
  $$,
  '42501',
  'mark_booking_editing_pending: booking.stage.advance permission required',
  'branch-scoped Coordinator cannot advance another branch'
);

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

-- 26
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT wrong_stage_booking_id FROM s11s11_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_pending: booking must be exactly Selection Pending or Editing Pending replay',
  'first execution from a non-Stage-12 booking is rejected'
);

-- 27
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT missing_lineage_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: canonical Selection Pending transition history is invalid',
  'Stage 12 without exact Stage 11 -> 12 lineage fails closed'
);

-- 28
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT invalid_replay_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: Editing Pending replay history is invalid',
  'Stage 13 without exact historical transition is not valid replay'
);

-- 29
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT missing_confirmation_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: exactly one selection confirmation required',
  'missing selection confirmation fails closed'
);

-- 30
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT missing_reconciliation_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: exactly one selection reconciliation required',
  'missing selection reconciliation fails closed'
);

-- 31
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT missing_requirement_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: exactly one booking payment requirement required',
  'missing payment requirement fails closed'
);

-- 32
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT missing_obligation_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: positive excess requires exactly one adjusted financial obligation',
  'positive excess without adjusted obligation fails closed'
);

-- 33
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT zero_conflict_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: zero-excess reconciliation conflicts with adjusted obligation',
  'zero excess cannot coexist with adjusted obligation'
);

-- 34
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT corrupt_obligation_booking_id FROM s11s11_ids)
  )
  $$,
  'P0001',
  'mark_booking_editing_pending: adjusted financial-obligation lineage is inconsistent',
  'corrupt adjusted-obligation lineage fails closed'
);

-- 35
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT under_booking_id FROM s11s11_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_pending: full balance has not been satisfied',
  'under-target current collections cannot advance'
);


-- =====================================================================
-- Part 5 - Client Coordinator exact-target first execution
-- =====================================================================

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000003'
);

-- 36
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT client_booking_id FROM s11s11_ids)
  )
  $$,
  'Client Coordinator may perform exact-target Stage 12 -> 13 advancement'
);

-- 37
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
      (SELECT client_booking_id FROM s11s11_ids)
  ),
  'editing_pending'::text,
  'successful first execution lands exactly at editing_pending'
);

-- 38
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND transition_row.transition_key =
          'editing_pending'
  ),
  1::bigint,
  'successful first execution appends exactly one editing_pending transition'
);

-- 39
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
      (SELECT client_booking_id FROM s11s11_ids)
      AND transition_row.transition_key =
          'editing_pending'
      AND source_stage.stage_order = 12
      AND source_stage.stage_key =
          'selection_pending'
      AND destination_stage.stage_order = 13
      AND destination_stage.stage_key =
          'editing_pending'
  ),
  1::bigint,
  'transition lineage is exactly Stage 12 selection_pending -> Stage 13 editing_pending'
);

-- 40
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ),
  (
    SELECT state_version + 1
    FROM s11s11_client_baseline
  ),
  'journey version increments exactly once'
);

-- 41
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND audit.action_key =
          'booking.editing_pending'
  ),
  1::bigint,
  'first execution appends exactly one editing_pending audit event'
);

-- 42
SELECT ok(
  (
    SELECT NOT audit.is_sensitive
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND audit.action_key =
          'booking.editing_pending'
  ),
  'editing_pending audit is explicitly non-sensitive'
);

-- 43
SELECT ok(
  (
    SELECT lower(
      concat_ws(
        ' ',
        audit.old_values::text,
        audit.new_values::text,
        audit.metadata::text
      )
    ) !~ '(settlement|payment|amount|inr|refund|overpayment)'
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND audit.action_key =
          'booking.editing_pending'
  ),
  'transition audit leaks no financial amount/payment/refund semantics'
);

-- 44
SELECT ok(
  (
    SELECT
      (
        SELECT count(*)
        FROM public.booking_payments
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s11_ids)
      ) = baseline.payment_count
      AND
      (
        SELECT count(*)
        FROM public.booking_payment_reversals
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s11_ids)
      ) = baseline.reversal_count
    FROM s11s11_client_baseline baseline
  ),
  'gate mutates neither payment nor reversal evidence'
);

-- 45
SELECT ok(
  (
    SELECT
      (
        SELECT count(*)
        FROM public.booking_selection_confirmations
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s11_ids)
      ) = baseline.confirmation_count
      AND
      (
        SELECT count(*)
        FROM public.booking_selection_reconciliations
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s11_ids)
      ) = baseline.reconciliation_count
      AND
      (
        SELECT count(*)
        FROM public.booking_adjusted_financial_obligations
        WHERE booking_id =
          (SELECT client_booking_id FROM s11s11_ids)
      ) = baseline.obligation_count
    FROM s11s11_client_baseline baseline
  ),
  'gate mutates no selection/reconciliation/obligation authority'
);

-- 46
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
      (SELECT client_booking_id FROM s11s11_ids)
      AND source_stage.stage_order = 13
      AND destination_stage.stage_order = 14
  ),
  0::bigint,
  'Slice 11 creates no Stage 13 -> 14 transition'
);


-- =====================================================================
-- Part 6 - Strict Stage 13 replay
-- =====================================================================

-- 47
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT client_booking_id FROM s11s11_ids)
  )
  $$,
  'exact Stage 13 historical replay succeeds'
);

-- 48
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
  ),
  (
    SELECT state_version + 1
    FROM s11s11_client_baseline
  ),
  'Stage 13 replay does not increment journey version'
);

-- 49
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND transition_key =
          'editing_pending'
  ),
  1::bigint,
  'Stage 13 replay appends no duplicate transition'
);

-- 50
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events
    WHERE entity_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND action_key =
          'booking.editing_pending'
  ),
  1::bigint,
  'Stage 13 replay appends no duplicate audit'
);


-- =====================================================================
-- Part 7 - Later reversal changes current finance, not history
-- =====================================================================

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

SELECT public.reverse_booking_payment(
  (SELECT client_payment_id FROM s11s11_ids),
  'S11S11 historical-transition reversal fixture'
);

-- 51
SELECT ok(
  NOT (
    SELECT summary.full_balance_satisfied
    FROM public.get_booking_full_balance_summary(
      (SELECT client_booking_id FROM s11s11_ids)
    ) summary
  ),
  'later reversal makes current full-balance summary unsatisfied'
);

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000003'
);

-- 52
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT client_booking_id FROM s11s11_ids)
  )
  $$,
  'historical Stage 13 replay does not re-evaluate later financial shortfall'
);

-- 53
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND transition_key =
          'editing_pending'
  ),
  1::bigint,
  'later reversal never removes or duplicates historical transition'
);

-- 54
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events
    WHERE entity_id =
      (SELECT client_booking_id FROM s11s11_ids)
      AND action_key =
          'booking.editing_pending'
  ),
  1::bigint,
  'later reversal plus replay leaves historical audit cardinality exact'
);


-- =====================================================================
-- Part 8 - Positive-excess and overcollection coverage
-- =====================================================================

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

-- 55
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT founder_positive_booking_id FROM s11s11_ids)
  )
  $$,
  'Founder may advance positive-excess booking at exact adjusted target'
);

-- 56
SELECT ok(
  (
    SELECT
      stage.stage_key = 'editing_pending'
      AND (
        SELECT count(*)
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
          state.booking_id
          AND transition_row.transition_key =
              'editing_pending'
      ) = 1
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT founder_positive_booking_id FROM s11s11_ids)
  ),
  'positive-excess exact-target advancement lands once at Stage 13'
);

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000002'
);

-- 57
SELECT lives_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT studio_over_booking_id FROM s11s11_ids)
  )
  $$,
  'Studio Manager may advance when current collections exceed target'
);

-- 58
SELECT ok(
  (
    SELECT
      stage.stage_key = 'editing_pending'
      AND (
        SELECT COALESCE(sum(payment.amount_inr), 0)::bigint
        FROM public.booking_payments payment
        LEFT JOIN public.booking_payment_reversals reversal
          ON reversal.organization_id =
             payment.organization_id
         AND reversal.booking_id =
             payment.booking_id
         AND reversal.payment_id =
             payment.id
        WHERE payment.booking_id =
          state.booking_id
          AND reversal.id IS NULL
      ) >
      (
        SELECT requirement.accepted_quotation_total_inr::bigint
        FROM public.booking_payment_requirements requirement
        WHERE requirement.booking_id =
          state.booking_id
      )
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT studio_over_booking_id FROM s11s11_ids)
  ),
  'overcollection satisfies coverage gate without preventing Stage 13'
);


-- =====================================================================
-- Part 9 - Later journey progression is not Slice 11 replay
-- =====================================================================

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

SELECT pg_temp.s11s11_move_to_stage(
  (SELECT studio_over_booking_id FROM s11s11_ids),
  14,
  'editing_in_progress',
  's11s11_fixture_editing_in_progress'
);

SELECT pg_temp.s11s11_set_actor(
  'b1100000-0000-0000-0000-000000000002'
);

-- 59
SELECT throws_ok(
  $$
  SELECT public.mark_booking_editing_pending(
    (SELECT studio_over_booking_id FROM s11s11_ids)
  )
  $$,
  '22023',
  'mark_booking_editing_pending: booking must be exactly Selection Pending or Editing Pending replay',
  'later Stage 14 progression is not accepted as Slice 11 replay'
);

SELECT * FROM finish();

ROLLBACK;
