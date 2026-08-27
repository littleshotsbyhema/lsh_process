CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(63);

-- =====================================================================
-- Sprint 11 Slice 12
-- Editing Start Evidence Foundation
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
  to_regclass(
    'public.booking_editing_starts'
  ) IS NOT NULL,
  'booking_editing_starts exists'
);

-- 4
SELECT is(
  (
    SELECT count(*)::bigint
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_editing_starts'
  ),
  6::bigint,
  'booking_editing_starts has exactly six frozen columns'
);

-- 5
SELECT is(
  (
    SELECT (array_agg(
      column_name
      ORDER BY ordinal_position
    ))::text[]
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_editing_starts'
  ),
  ARRAY[
    'id',
    'organization_id',
    'booking_id',
    'source_editing_pending_transition_id',
    'started_at',
    'started_by'
  ]::text[],
  'editing-start column order and names are exact'
);

-- 6
SELECT ok(
  (
    SELECT
      relation.relrowsecurity
      AND relation.relforcerowsecurity
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
      'public.booking_editing_starts'::regclass
  ),
  'booking_editing_starts enables and forces RLS'
);

-- 7
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_editing_starts'::regclass
      AND constraint_row.conname =
          'booking_editing_starts_org_booking_key'
      AND constraint_row.contype = 'u'
  ),
  'exactly-one editing start per organization and booking is constrained'
);

-- 8
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_editing_starts'::regclass
      AND constraint_row.conname =
          'booking_editing_starts_org_source_transition_key'
      AND constraint_row.contype = 'u'
  ),
  'source Editing Pending transition cannot be consumed twice'
);

-- 9
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.booking_editing_starts'::regclass
      AND trigger_row.tgname =
          'booking_editing_starts_guard'
      AND NOT trigger_row.tgisinternal
  ),
  'immutable editing-start guard exists'
);

-- 10
SELECT ok(
  to_regprocedure(
    'public.record_booking_editing_start(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(
      procedure.oid
    )
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_editing_start(uuid)'::regprocedure
  ) = 'booking_editing_starts',
  'record_booking_editing_start(uuid) exists and returns booking_editing_starts'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.pronamespace =
          'public'::regnamespace
      AND procedure.proname =
          'record_booking_editing_start'
  ),
  1::bigint,
  'exactly one editing-start recorder signature exists'
);

-- 12
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_editing_start(uuid)'::regprocedure
  ),
  'editing-start recorder is SECURITY DEFINER'
);

-- 13
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_editing_start(uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'editing-start recorder fixes empty search_path'
);

-- 14
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_editing_start(uuid)',
    'EXECUTE'
  ),
  'authenticated has editing-start RPC EXECUTE'
);

-- 15
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
      'public.record_booking_editing_start(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type =
          'EXECUTE'
  ),
  'PUBLIC has no editing-start RPC EXECUTE'
);

-- 16
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.record_booking_editing_start(uuid)',
    'EXECUTE'
  ),
  'anon has no editing-start RPC EXECUTE'
);

-- 17
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.record_booking_editing_start(uuid)',
    'EXECUTE'
  ),
  'service_role has no application editing-start RPC EXECUTE'
);

-- 18
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_editing_starts',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_editing_starts',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_editing_starts',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_editing_starts',
    'DELETE'
  ),
  'authenticated receives SELECT only and no direct editing-start mutation'
);

-- 19
SELECT ok(
  (
    SELECT
      lower(COALESCE(policy.qual, ''))
        LIKE '%editing.read%'
      AND
      lower(COALESCE(policy.qual, ''))
        LIKE '%has_branch_scope%'
    FROM pg_catalog.pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename =
          'booking_editing_starts'
      AND policy.policyname =
          'booking_editing_starts_authenticated_select'
  ),
  'editing-start read policy uses editing.read and branch scope'
);

-- 20
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
  'editing.write role topology remains exact'
);

-- 21
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
  'editing.read role topology remains exact'
);

-- 22
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
        ILIKE '%editing_pending%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%FOR UPDATE%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%append_audit_event%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_editing_start(uuid)'::regprocedure
  ),
  'recorder contains exact editing-write, branch, Stage-13 lineage, locking and audit authorities'
);

-- 23
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        NOT ILIKE '%booking.stage.advance%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%finance.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%payment.read%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%get_booking_full_balance_summary%'
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
        NOT ILIKE '%editing_in_progress%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_editing_start(uuid)'::regprocedure
  ),
  'recorder imports no stage-advance, finance, selection, payment or Stage-14 authority'
);

-- 24
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class relation
    JOIN pg_catalog.pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname IN (
        'editing_jobs',
        'editing_assignments',
        'editing_qc',
        'delivery_records',
        'pixieset_galleries'
      )
  ),
  0::bigint,
  'Slice 12 introduces no mutable editing, QC, gallery or delivery persistence'
);

-- 25
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
  0::bigint,
  'Slice 12 introduces no Stage 14 function'
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
  'S11 Slice12 Branch A',
  's11s12-a',
  'active'
),
(
  'b1100000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice12 Branch B',
  's11s12-b',
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
  'S11S12 Founder',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000002',
  'active',
  'S11S12 Studio Manager',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000003',
  'active',
  'S11S12 Client Coordinator',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000004',
  'active',
  'S11S12 Editor',
  NULL
),
(
  'b1100000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000005',
  'suspended',
  'S11S12 Suspended Founder',
  now()
),
(
  'b1100000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1100000-0000-0000-0000-000000000006',
  'active',
  'S11S12 Branch Coordinator',
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

CREATE FUNCTION pg_temp.s11s12_set_actor(
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

SELECT pg_temp.s11s12_set_actor(
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
  'S11 Slice12 Family',
  'S11 Slice12 Family',
  'active',
  'b1100000-0000-0000-0000-000000000101',
  'b1100000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s11s12_create_booking(
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

CREATE FUNCTION pg_temp.s11s12_move_to_stage(
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

CREATE FUNCTION pg_temp.s11s12_set_stage_without_transition(
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

CREATE FUNCTION pg_temp.s11s12_prepare_stage12(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s12_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    's11s12_fixture_shoot_completed'
  );

  PERFORM pg_temp.s11s12_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    'selection_pending'
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s12_included_count(
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

CREATE FUNCTION pg_temp.s11s12_record_confirmation_only(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_included integer;
BEGIN
  PERFORM pg_temp.s11s12_prepare_stage12(
    p_booking_id
  );

  v_included :=
    pg_temp.s11s12_included_count(
      p_booking_id
    );

  PERFORM public.record_booking_selection_confirmation(
    p_booking_id,
    v_included,
    now()
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s12_prepare_reconciliation(
  p_booking_id uuid,
  p_excess integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_included integer;
BEGIN
  PERFORM pg_temp.s11s12_prepare_stage12(
    p_booking_id
  );

  v_included :=
    pg_temp.s11s12_included_count(
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

CREATE FUNCTION pg_temp.s11s12_prepare_positive(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s12_prepare_reconciliation(
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

CREATE FUNCTION pg_temp.s11s12_pay_target(
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
      'S11S12 payment fixture target must remain positive';
  END IF;

  SELECT (
    public.record_booking_payment(
      p_booking_id,
      (v_target + p_delta)::integer,
      'upi'::public.booking_payment_method,
      now(),
      'S11S12-' ||
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
-- Part 3 - Slice 12 fixture helpers
-- =====================================================================

CREATE FUNCTION pg_temp.s11s12_prepare_stage13(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s12_prepare_reconciliation(
    p_booking_id,
    0
  );

  PERFORM pg_temp.s11s12_pay_target(
    p_booking_id,
    0
  );

  PERFORM public.mark_booking_editing_pending(
    p_booking_id
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s12_capture_error(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.record_booking_editing_start(
    p_booking_id
  );

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;

-- Branch-scoped Editor used only for branch-denial proof.

INSERT INTO auth.users (id)
VALUES (
  'b1200000-0000-0000-0000-000000000007'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  suspended_at
)
VALUES (
  'b1200000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'b1200000-0000-0000-0000-000000000007',
  'active',
  'S11S12 Branch Editor',
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
  'b1200000-0000-0000-0000-000000000107'::uuid,
  role.id,
  'b1100000-0000-0000-0000-000000000701'::uuid
FROM public.roles role
WHERE role.key = 'editor';


-- =====================================================================
-- Part 4 - Build canonical Stage-13 fixtures
-- =====================================================================

CREATE TEMP TABLE s11s12_ids (
  editor_booking_id uuid,
  founder_booking_id uuid,
  studio_booking_id uuid,
  client_booking_id uuid,
  branch_booking_id uuid,
  stage12_booking_id uuid,
  missing_lineage_booking_id uuid,
  duplicate_lineage_booking_id uuid,
  stage14_booking_id uuid,
  early_insert_booking_id uuid,
  wrong_source_target_booking_id uuid,
  source_donor_booking_id uuid,
  corrupt_existing_booking_id uuid
);

INSERT INTO s11s12_ids
VALUES (
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(
    'b1100000-0000-0000-0000-000000000702'
  ),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking(),
  pg_temp.s11s12_create_booking()
);

-- Founder prepares all canonical Stage-13 fixtures.
SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT editor_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT founder_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT studio_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT client_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT branch_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage12(
  (SELECT stage12_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_set_stage_without_transition(
  (SELECT missing_lineage_booking_id FROM s11s12_ids),
  13,
  'editing_pending'
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT duplicate_lineage_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT stage14_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT early_insert_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT wrong_source_target_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT source_donor_booking_id FROM s11s12_ids)
);

SELECT pg_temp.s11s12_prepare_stage13(
  (SELECT corrupt_existing_booking_id FROM s11s12_ids)
);

-- Create a second otherwise-canonical Stage 12 -> 13 history row for the
-- duplicate-lineage corruption fixture.

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
  'b1100000-0000-0000-0000-000000000101'::uuid
FROM public.booking_stage_transitions transition_row
WHERE transition_row.booking_id =
      (
        SELECT duplicate_lineage_booking_id
        FROM s11s12_ids
      )
  AND transition_row.transition_key =
      'editing_pending'
ORDER BY transition_row.transitioned_at
LIMIT 1;

-- Move one canonical Stage-13 fixture to Stage 14 without adding history.
-- This is transaction-local corruption solely for boundary rejection.

SELECT pg_temp.s11s12_set_stage_without_transition(
  (SELECT stage14_booking_id FROM s11s12_ids),
  14,
  'editing_in_progress'
);

CREATE TEMP TABLE s11s12_editor_baseline AS
SELECT
  state.version AS state_version,
  state.current_stage_id,
  (
    SELECT count(*)
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ) AS transition_count,
  (
    SELECT transition_row.id
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
      AND transition_row.transition_key =
          'editing_pending'
  ) AS source_transition_id,
  (
    SELECT transition_row.transitioned_at
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
      AND transition_row.transition_key =
          'editing_pending'
  ) AS source_transitioned_at,
  (
    SELECT count(*)
    FROM public.booking_selection_confirmations
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ) AS confirmation_count,
  (
    SELECT count(*)
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ) AS reconciliation_count,
  (
    SELECT count(*)
    FROM public.booking_payments
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ) AS payment_count,
  (
    SELECT count(*)
    FROM public.booking_payment_reversals
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ) AS reversal_count,
  (
    SELECT count(*)
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ) AS obligation_count,
  (
    SELECT count(*)
    FROM public.booking_team_assignments
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ) AS assignment_count
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT editor_booking_id FROM s11s12_ids);


-- =====================================================================
-- Part 5 - Fail-closed authorization and stage boundary
-- =====================================================================

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

-- 26
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(NULL)
  $$,
  '22023',
  'record_booking_editing_start: booking_id is required',
  'null booking id is rejected'
);

-- 27
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    'b12fffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'record_booking_editing_start: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s12_set_actor(NULL);

-- 28
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT editor_booking_id FROM s11s12_ids)
  )
  $$,
  '42501',
  'record_booking_editing_start: authenticated actor required',
  'unauthenticated actor is rejected'
);

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000005'
);

-- 29
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT editor_booking_id FROM s11s12_ids)
  )
  $$,
  '42501',
  'record_booking_editing_start: active organization membership required',
  'suspended organization member is rejected'
);

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000003'
);

-- 30
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT client_booking_id FROM s11s12_ids)
  )
  $$,
  '42501',
  'record_booking_editing_start: editing.write permission required',
  'Client Coordinator cannot manufacture editing-start evidence'
);

SELECT pg_temp.s11s12_set_actor(
  'b1200000-0000-0000-0000-000000000007'
);

-- 31
SELECT ok(
  pg_temp.s11s12_capture_error(
    (SELECT branch_booking_id FROM s11s12_ids)
  ) LIKE '42501:%',
  'branch-scoped Editor is rejected for booking in another branch'
);

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000004'
);

-- 32
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT stage12_booking_id FROM s11s12_ids)
  )
  $$,
  '22023',
  'record_booking_editing_start: booking must be exactly Editing Pending',
  'Stage 12 booking is rejected'
);

-- 33
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT missing_lineage_booking_id FROM s11s12_ids)
  )
  $$,
  'P0001',
  'record_booking_editing_start: canonical Editing Pending transition history is invalid',
  'Stage 13 state without canonical Stage 12 to 13 lineage is rejected'
);

-- 34
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT duplicate_lineage_booking_id FROM s11s12_ids)
  )
  $$,
  'P0001',
  'record_booking_editing_start: canonical Editing Pending transition history is invalid',
  'duplicate canonical Stage 12 to 13 lineage fails closed'
);


-- =====================================================================
-- Part 6 - Editor first-success contract
-- =====================================================================

-- 35
SELECT lives_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT editor_booking_id FROM s11s12_ids)
  )
  $$,
  'Editor may record editing start at exact canonical Stage 13'
);

-- 36
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  1::bigint,
  'first success creates exactly one editing-start row'
);

-- 37
SELECT is(
  (
    SELECT started_by
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  'b1100000-0000-0000-0000-000000000104'::uuid,
  'editing start attributes started_by to the Editor actor'
);

-- 38
SELECT is(
  (
    SELECT source_editing_pending_transition_id
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  (
    SELECT source_transition_id
    FROM s11s12_editor_baseline
  ),
  'editing start snapshots the exact canonical Editing Pending transition'
);

-- 39
SELECT ok(
  (
    SELECT
      editing_start.started_at >=
      baseline.source_transitioned_at
    FROM public.booking_editing_starts editing_start
    CROSS JOIN s11s12_editor_baseline baseline
    WHERE editing_start.booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  'server-authoritative editing start cannot precede Stage 13 entry'
);

-- 40
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  (
    SELECT state_version
    FROM s11s12_editor_baseline
  ),
  'editing-start recording does not increment journey version'
);

-- 41
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
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  'editing_pending'::text,
  'editing-start recording leaves booking exactly at Stage 13'
);

-- 42
SELECT is(
  (
    SELECT count(*)
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  (
    SELECT transition_count
    FROM s11s12_editor_baseline
  ),
  'editing-start recording appends no journey transition'
);

-- 43
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT editor_booking_id FROM s11s12_ids)
      AND audit.action_key =
          'booking.editing_started'
  ),
  1::bigint,
  'first success appends exactly one booking.editing_started audit'
);

-- 44
SELECT ok(
  (
    SELECT NOT audit.is_sensitive
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT editor_booking_id FROM s11s12_ids)
      AND audit.action_key =
          'booking.editing_started'
  ),
  'editing-start audit is explicitly non-sensitive'
);

-- 45
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
      (SELECT editor_booking_id FROM s11s12_ids)
      AND audit.action_key =
          'booking.editing_started'
  ),
  'editing-start audit leaks no forbidden finance, selection, assignment, SLA, QC or delivery semantics'
);

-- 46
SELECT ok(
  (
    SELECT
      (
        SELECT count(*)
        FROM public.booking_selection_confirmations
        WHERE booking_id =
          (SELECT editor_booking_id FROM s11s12_ids)
      ) = baseline.confirmation_count
      AND
      (
        SELECT count(*)
        FROM public.booking_selection_reconciliations
        WHERE booking_id =
          (SELECT editor_booking_id FROM s11s12_ids)
      ) = baseline.reconciliation_count
      AND
      (
        SELECT count(*)
        FROM public.booking_payments
        WHERE booking_id =
          (SELECT editor_booking_id FROM s11s12_ids)
      ) = baseline.payment_count
      AND
      (
        SELECT count(*)
        FROM public.booking_payment_reversals
        WHERE booking_id =
          (SELECT editor_booking_id FROM s11s12_ids)
      ) = baseline.reversal_count
      AND
      (
        SELECT count(*)
        FROM public.booking_adjusted_financial_obligations
        WHERE booking_id =
          (SELECT editor_booking_id FROM s11s12_ids)
      ) = baseline.obligation_count
    FROM s11s12_editor_baseline baseline
  ),
  'editing-start recorder mutates no selection or financial evidence'
);

-- 47
SELECT is(
  (
    SELECT count(*)
    FROM public.booking_team_assignments
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  (
    SELECT assignment_count
    FROM s11s12_editor_baseline
  ),
  'editing start creates no editor or booking-team assignment'
);


-- =====================================================================
-- Part 7 - Exact replay
-- =====================================================================

-- 48
SELECT lives_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT editor_booking_id FROM s11s12_ids)
  )
  $$,
  'exact Stage 13 replay succeeds idempotently'
);

-- 49
SELECT is(
  (
    SELECT (
      public.record_booking_editing_start(
        (SELECT editor_booking_id FROM s11s12_ids)
      )
    ).id
  ),
  (
    SELECT id
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  'replay returns the exact existing editing-start row'
);

-- 50
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT editor_booking_id FROM s11s12_ids)
  ),
  1::bigint,
  'replay does not create a second editing-start row'
);

-- 51
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT editor_booking_id FROM s11s12_ids)
      AND audit.action_key =
          'booking.editing_started'
  ),
  1::bigint,
  'replay does not append a second editing-start audit'
);


-- =====================================================================
-- Part 8 - Founder / Studio Manager authority
-- =====================================================================

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

-- 52
SELECT lives_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT founder_booking_id FROM s11s12_ids)
  )
  $$,
  'Founder may record editing start'
);

-- 53
SELECT is(
  (
    SELECT started_by
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT founder_booking_id FROM s11s12_ids)
  ),
  'b1100000-0000-0000-0000-000000000101'::uuid,
  'Founder editing start carries founder attribution'
);

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000002'
);

-- 54
SELECT lives_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT studio_booking_id FROM s11s12_ids)
  )
  $$,
  'Studio Manager may record editing start'
);

-- 55
SELECT is(
  (
    SELECT started_by
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT studio_booking_id FROM s11s12_ids)
  ),
  'b1100000-0000-0000-0000-000000000102'::uuid,
  'Studio Manager editing start carries Studio Manager attribution'
);


-- =====================================================================
-- Part 9 - Immutable row guard
-- =====================================================================

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000001'
);

-- 56
SELECT throws_ok(
  $$
  UPDATE public.booking_editing_starts
  SET started_at =
      started_at + interval '1 second'
  WHERE booking_id =
    (SELECT editor_booking_id FROM s11s12_ids)
  $$,
  'P0001',
  'booking editing start evidence is immutable',
  'editing-start evidence cannot be updated'
);

-- 57
SELECT throws_ok(
  $$
  DELETE FROM public.booking_editing_starts
  WHERE booking_id =
    (SELECT editor_booking_id FROM s11s12_ids)
  $$,
  'P0001',
  'booking editing start evidence is immutable',
  'editing-start evidence cannot be deleted'
);

-- 58
SELECT throws_ok(
  $$
  INSERT INTO public.booking_editing_starts (
    organization_id,
    booking_id,
    source_editing_pending_transition_id,
    started_at,
    started_by
  )
  SELECT
    booking.organization_id,
    booking.id,
    donor_transition.id,
    now(),
    'b1100000-0000-0000-0000-000000000101'::uuid
  FROM public.bookings booking
  CROSS JOIN LATERAL (
    SELECT transition_row.id
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT source_donor_booking_id FROM s11s12_ids)
      AND transition_row.transition_key =
          'editing_pending'
  ) donor_transition
  WHERE booking.id =
    (SELECT wrong_source_target_booking_id FROM s11s12_ids)
  $$,
  'P0001',
  'booking editing start source transition must be the canonical Stage 12 to 13 editing_pending transition',
  'editing-start guard rejects a source transition from another booking'
);

-- 59
SELECT throws_ok(
  $$
  INSERT INTO public.booking_editing_starts (
    organization_id,
    booking_id,
    source_editing_pending_transition_id,
    started_at,
    started_by
  )
  SELECT
    booking.organization_id,
    booking.id,
    transition_row.id,
    transition_row.transitioned_at -
      interval '1 second',
    'b1100000-0000-0000-0000-000000000101'::uuid
  FROM public.bookings booking
  JOIN public.booking_stage_transitions transition_row
    ON transition_row.organization_id =
       booking.organization_id
   AND transition_row.booking_id =
       booking.id
   AND transition_row.transition_key =
       'editing_pending'
  WHERE booking.id =
    (SELECT early_insert_booking_id FROM s11s12_ids)
  $$,
  'P0001',
  'booking editing start cannot precede canonical Editing Pending entry',
  'editing-start guard rejects started_at before Stage 13 entry'
);


-- =====================================================================
-- Part 10 - Malformed existing evidence fails closed
-- =====================================================================

ALTER TABLE public.booking_editing_starts
DISABLE TRIGGER USER;

INSERT INTO public.booking_editing_starts (
  organization_id,
  booking_id,
  source_editing_pending_transition_id,
  started_at,
  started_by
)
SELECT
  target.organization_id,
  target.id,
  donor_transition.id,
  now(),
  'b1100000-0000-0000-0000-000000000101'::uuid
FROM public.bookings target
CROSS JOIN LATERAL (
  SELECT transition_row.id
  FROM public.booking_stage_transitions transition_row
  WHERE transition_row.booking_id =
    (SELECT source_donor_booking_id FROM s11s12_ids)
    AND transition_row.transition_key =
        'editing_pending'
) donor_transition
WHERE target.id =
  (SELECT corrupt_existing_booking_id FROM s11s12_ids);

ALTER TABLE public.booking_editing_starts
ENABLE TRIGGER USER;

-- 60
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT corrupt_existing_booking_id FROM s11s12_ids)
  )
  $$,
  'P0001',
  'record_booking_editing_start: existing editing-start evidence is inconsistent',
  'malformed pre-existing editing-start evidence fails closed'
);


-- =====================================================================
-- Part 11 - Later-stage boundary
-- =====================================================================

SELECT pg_temp.s11s12_set_actor(
  'b1100000-0000-0000-0000-000000000004'
);

-- 61
SELECT throws_ok(
  $$
  SELECT public.record_booking_editing_start(
    (SELECT stage14_booking_id FROM s11s12_ids)
  )
  $$,
  '22023',
  'record_booking_editing_start: booking must be exactly Editing Pending',
  'Stage 14 is not accepted as Slice 12 replay'
);

-- 62
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_editing_starts
    WHERE booking_id =
      (SELECT stage14_booking_id FROM s11s12_ids)
  ),
  0::bigint,
  'Stage 14 rejection creates no editing-start evidence'
);

-- 63
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_editing_starts editing_start
      ON editing_start.organization_id =
         transition_row.organization_id
     AND editing_start.booking_id =
         transition_row.booking_id
    WHERE transition_row.transition_key =
          'editing_in_progress'
  ),
  0::bigint,
  'Slice 12 editing-start evidence never creates Stage 14 transition history'
);

SELECT * FROM finish();

ROLLBACK;
