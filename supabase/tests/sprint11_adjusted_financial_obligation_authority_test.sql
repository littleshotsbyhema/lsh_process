CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(76);

-- =====================================================================
-- Sprint 11 Slice 9
-- Booking Adjusted Financial Obligation Authority Foundation
--
-- Proves:
--   * exact immutable financial-obligation schema;
--   * tenant-safe source provenance;
--   * finance.write mutation authority;
--   * finance.read runtime read containment;
--   * exact Stage 12 containment;
--   * positive-excess-only recording;
--   * principal from immutable payment requirement;
--   * quantity from Slice 7 reconciliation;
--   * price from Slice 8 pricing basis;
--   * bigint deterministic charge / adjusted-total calculation;
--   * missing / inconsistent sources fail closed;
--   * exact replay idempotence;
--   * immutable rows;
--   * no payment, reversal, quotation, requirement, or journey mutation;
--   * no settlement semantics;
--   * no Stage 12 -> 13 advancement;
--   * permission catalogue remains 69 / 243.
-- =====================================================================


-- =====================================================================
-- Part 1 — Structural / ACL / RLS contract
-- =====================================================================

-- 1
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  71::bigint,
  'canonical permission catalogue remains exactly 69'
);

-- 2
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  246::bigint,
  'canonical role-permission mapping count remains exactly 243'
);

-- 3
SELECT ok(
  to_regclass(
    'public.booking_adjusted_financial_obligations'
  ) IS NOT NULL,
  'booking_adjusted_financial_obligations exists'
);

-- 4
SELECT is(
  (
    SELECT array_agg(
             column_name
             ORDER BY ordinal_position
           )::text[]
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_adjusted_financial_obligations'
  ),
  ARRAY[
    'id',
    'organization_id',
    'booking_id',
    'source_payment_requirement_id',
    'source_quotation_id',
    'source_reconciliation_id',
    'source_pricing_basis_id',
    'accepted_quotation_total_inr',
    'excess_image_count',
    'applied_unit_price_inr',
    'excess_image_charge_inr',
    'adjusted_total_inr',
    'currency',
    'calculation_rule',
    'recorded_at',
    'recorded_by'
  ]::text[],
  'adjusted obligation has exactly the frozen 16 columns'
);

-- 5
SELECT is(
  (
    SELECT data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_adjusted_financial_obligations'
      AND column_name =
          'excess_image_charge_inr'
  ),
  'bigint',
  'excess image charge uses bigint'
);

-- 6
SELECT is(
  (
    SELECT data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_adjusted_financial_obligations'
      AND column_name =
          'adjusted_total_inr'
  ),
  'bigint',
  'adjusted total uses bigint'
);

-- 7
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_adjusted_financial_obligations'::regclass
      AND conname =
          'booking_adjusted_financial_obligations_org_booking_key'
      AND contype = 'u'
  ),
  'one adjusted obligation per organization and booking is enforced'
);

-- 8
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename =
          'booking_payment_requirements'
      AND indexname =
          'booking_payment_requirements_org_booking_id_uidx'
      AND indexdef ILIKE
          '%UNIQUE INDEX%organization_id, booking_id, id%'
  ),
  'payment requirement has tenant-safe provenance identity'
);

-- 9
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename =
          'booking_additional_image_pricing_bases'
      AND indexname =
          'booking_additional_image_pricing_bases_org_booking_id_uidx'
      AND indexdef ILIKE
          '%UNIQUE INDEX%organization_id, booking_id, id%'
  ),
  'pricing basis has tenant-safe provenance identity'
);

-- 10
SELECT ok(
  (
    SELECT relrowsecurity
    FROM pg_class
    WHERE oid =
      'public.booking_adjusted_financial_obligations'::regclass
  ),
  'adjusted obligation has RLS enabled'
);

-- 11
SELECT ok(
  (
    SELECT relforcerowsecurity
    FROM pg_class
    WHERE oid =
      'public.booking_adjusted_financial_obligations'::regclass
  ),
  'adjusted obligation has forced RLS'
);

-- 12
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_adjusted_financial_obligations',
    'SELECT'
  ),
  'authenticated has adjusted-obligation SELECT'
);

-- 13
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_adjusted_financial_obligations',
    'INSERT'
  ),
  'authenticated has no direct adjusted-obligation INSERT'
);

-- 14
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_adjusted_financial_obligations',
    'UPDATE'
  ),
  'authenticated has no direct adjusted-obligation UPDATE'
);

-- 15
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_adjusted_financial_obligations',
    'DELETE'
  ),
  'authenticated has no direct adjusted-obligation DELETE'
);

-- 16
SELECT ok(
  NOT has_table_privilege(
    'service_role',
    'public.booking_adjusted_financial_obligations',
    'SELECT'
  ),
  'service_role has no adjusted-obligation table access'
);

-- 17
SELECT ok(
  to_regprocedure(
    'public.record_booking_adjusted_financial_obligation(uuid)'
  ) IS NOT NULL,
  'controlled adjusted-obligation RPC exists'
);

-- 18
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_proc
    WHERE pronamespace = 'public'::regnamespace
      AND proname =
          'record_booking_adjusted_financial_obligation'
  ),
  1::bigint,
  'exactly one adjusted-obligation RPC signature exists'
);

-- 19
SELECT ok(
  (
    SELECT prosecdef
    FROM pg_proc
    WHERE oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
  ),
  'adjusted-obligation RPC is SECURITY DEFINER'
);

-- 20
SELECT ok(
  (
    SELECT proconfig @>
           ARRAY['search_path=""']::text[]
    FROM pg_proc
    WHERE oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
  ),
  'adjusted-obligation RPC fixes empty search_path'
);

-- 21
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_adjusted_financial_obligation(uuid)',
    'EXECUTE'
  ),
  'authenticated may execute adjusted-obligation RPC'
);

-- 22
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.record_booking_adjusted_financial_obligation(uuid)',
    'EXECUTE'
  ),
  'anon may not execute adjusted-obligation RPC'
);

-- 23
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.record_booking_adjusted_financial_obligation(uuid)',
    'EXECUTE'
  ),
  'service_role may not execute adjusted-obligation RPC'
);

-- 24
SELECT ok(
  (
    SELECT qual LIKE '%finance.read%'
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename =
          'booking_adjusted_financial_obligations'
      AND policyname =
          'booking_adjusted_financial_obligations_authenticated_select'
  ),
  'adjusted-obligation RLS uses finance.read'
);

-- 25
SELECT ok(
  (
    SELECT pg_get_functiondef(oid)
           LIKE '%finance.write%'
    FROM pg_proc
    WHERE oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
  ),
  'adjusted-obligation RPC enforces finance.write'
);

-- 26
SELECT ok(
  (
    SELECT pg_get_functiondef(oid)
           NOT LIKE '%booking_payments%'
    FROM pg_proc
    WHERE oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
  ),
  'obligation calculation does not inspect booking payments'
);

-- 27
SELECT ok(
  (
    SELECT pg_get_functiondef(oid)
           NOT LIKE '%booking_payment_reversals%'
    FROM pg_proc
    WHERE oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
  ),
  'obligation calculation does not inspect payment reversals'
);

-- 28
SELECT ok(
  (
    SELECT
      pg_get_functiondef(oid) NOT ILIKE '%settlement_status%'
      AND pg_get_functiondef(oid) NOT ILIKE '%paid_in_full%'
      AND pg_get_functiondef(oid) NOT ILIKE '%balance_due%'
      AND pg_get_functiondef(oid) NOT ILIKE '%amount_due%'
    FROM pg_proc
    WHERE oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
  ),
  'RPC contains no settlement or balance semantics'
);

-- 29
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
  ),
  0::bigint,
  'migration backfills no adjusted obligations'
);

-- 30
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_journey_stages
    WHERE stage_order = 12
      AND stage_key = 'selection_pending'
      AND is_active
  ),
  1::bigint,
  'exact active Stage 12 selection_pending authority exists'
);


-- =====================================================================
-- Part 2 — Transaction-local canonical fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('9e000000-0000-0000-0000-000000000001'::uuid),
  ('9e000000-0000-0000-0000-000000000002'::uuid),
  ('9e000000-0000-0000-0000-000000000003'::uuid),
  ('9e000000-0000-0000-0000-000000000004'::uuid),
  ('9e000000-0000-0000-0000-000000000005'::uuid);

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
  '9e000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '9e000000-0000-0000-0000-000000000001',
  'active',
  'S11S9 Founder',
  NULL
),
(
  '9e000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '9e000000-0000-0000-0000-000000000002',
  'active',
  'S11S9 Accounts',
  NULL
),
(
  '9e000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '9e000000-0000-0000-0000-000000000003',
  'active',
  'S11S9 Studio Manager',
  NULL
),
(
  '9e000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '9e000000-0000-0000-0000-000000000004',
  'active',
  'S11S9 Sales',
  NULL
),
(
  '9e000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '9e000000-0000-0000-0000-000000000005',
  'active',
  'S11S9 Photographer',
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
  NULL::uuid
FROM (
  VALUES
    (
      '9e000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text
    ),
    (
      '9e000000-0000-0000-0000-000000000102'::uuid,
      'accounts'::text
    ),
    (
      '9e000000-0000-0000-0000-000000000103'::uuid,
      'studio_manager'::text
    ),
    (
      '9e000000-0000-0000-0000-000000000104'::uuid,
      'sales'::text
    ),
    (
      '9e000000-0000-0000-0000-000000000105'::uuid,
      'photographer'::text
    )
) AS fixture(member_id, role_key)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s9_set_actor(
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

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000001'
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
  '9e000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-9ABCDE',
  'S11 Slice9 Family',
  'S11 Slice9 Family',
  'active',
  '9e000000-0000-0000-0000-000000000101',
  '9e000000-0000-0000-0000-000000000101'
);


CREATE FUNCTION pg_temp.s11s9_create_booking()
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
    '9e000000-0000-0000-0000-000000000201',
    NULL,
    NULL,
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


CREATE FUNCTION pg_temp.s11s9_move_to_stage(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_transition_key text,
  p_transitioned_at timestamptz
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
    p_transitioned_at,
    '9e000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_target.id,
    stage_entered_at =
      GREATEST(
        p_transitioned_at,
        v_state.stage_entered_at
      ),
    version =
      state.version + 1,
    updated_at =
      p_transitioned_at,
    updated_by =
      '9e000000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s9_prepare_stage12(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s9_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    's11s9_fixture_shoot_completed',
    now() - interval '3 minutes'
  );

  PERFORM pg_temp.s11s9_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    'selection_pending',
    now() - interval '2 minutes'
  );
END;
$$;


CREATE FUNCTION pg_temp.s11s9_prepare_reconciliation(
  p_booking_id uuid,
  p_excess integer
)
RETURNS void
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

  PERFORM pg_temp.s11s9_prepare_stage12(
    p_booking_id
  );

  PERFORM public.record_booking_selection_confirmation(
    p_booking_id,
    v_included + p_excess,
    now() - interval '1 second'
  );

  PERFORM public.record_booking_selection_reconciliation(
    p_booking_id
  );
END;
$$;


CREATE FUNCTION pg_temp.s11s9_prepare_pricing_basis(
  p_booking_id uuid,
  p_excess integer DEFAULT 3
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s9_prepare_reconciliation(
    p_booking_id,
    p_excess
  );

  PERFORM public.record_booking_additional_image_pricing_basis(
    p_booking_id,
    NULL
  );
END;
$$;


CREATE TEMP TABLE s11s9_ids (
  main_booking_id uuid,
  accounts_booking_id uuid,
  studio_booking_id uuid,
  sales_denied_booking_id uuid,
  photographer_denied_booking_id uuid,
  stage11_booking_id uuid,
  no_reconciliation_booking_id uuid,
  zero_excess_booking_id uuid,
  missing_pricing_booking_id uuid,
  missing_requirement_booking_id uuid,
  mismatch_pricing_booking_id uuid
);

INSERT INTO s11s9_ids
VALUES (
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking(),
  pg_temp.s11s9_create_booking()
);

SELECT pg_temp.s11s9_prepare_pricing_basis(
  (SELECT main_booking_id FROM s11s9_ids)
);

SELECT pg_temp.s11s9_prepare_pricing_basis(
  (SELECT accounts_booking_id FROM s11s9_ids)
);

SELECT pg_temp.s11s9_prepare_pricing_basis(
  (SELECT studio_booking_id FROM s11s9_ids)
);

SELECT pg_temp.s11s9_prepare_pricing_basis(
  (SELECT sales_denied_booking_id FROM s11s9_ids)
);

SELECT pg_temp.s11s9_prepare_pricing_basis(
  (SELECT photographer_denied_booking_id FROM s11s9_ids)
);

SELECT pg_temp.s11s9_move_to_stage(
  (SELECT stage11_booking_id FROM s11s9_ids),
  11,
  'shoot_completed',
  's11s9_fixture_shoot_completed',
  now() - interval '2 minutes'
);

SELECT pg_temp.s11s9_prepare_stage12(
  (SELECT no_reconciliation_booking_id FROM s11s9_ids)
);

SELECT pg_temp.s11s9_prepare_reconciliation(
  (SELECT zero_excess_booking_id FROM s11s9_ids),
  0
);

SELECT pg_temp.s11s9_prepare_reconciliation(
  (SELECT missing_pricing_booking_id FROM s11s9_ids),
  3
);

SELECT pg_temp.s11s9_prepare_pricing_basis(
  (SELECT missing_requirement_booking_id FROM s11s9_ids)
);

SELECT pg_temp.s11s9_prepare_pricing_basis(
  (SELECT mismatch_pricing_booking_id FROM s11s9_ids)
);


CREATE TEMP TABLE s11s9_main_baseline AS
SELECT
  state.current_stage_id,
  state.version AS state_version,
  (
    SELECT count(*)
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.organization_id =
          booking.organization_id
      AND transition_row.booking_id =
          booking.id
  ) AS transition_count,
  quotation.quoted_total_inr,
  requirement.required_advance_inr,
  (
    SELECT count(*)
    FROM public.booking_payments payment
    WHERE payment.organization_id =
          booking.organization_id
      AND payment.booking_id =
          booking.id
  ) AS payment_count,
  (
    SELECT count(*)
    FROM public.booking_payment_reversals reversal
    WHERE reversal.organization_id =
          booking.organization_id
      AND reversal.booking_id =
          booking.id
  ) AS reversal_count
FROM public.bookings booking
JOIN public.booking_journey_states state
  ON state.organization_id =
     booking.organization_id
 AND state.booking_id =
     booking.id
JOIN public.quotations quotation
  ON quotation.organization_id =
     booking.organization_id
 AND quotation.id =
     booking.source_quotation_id
JOIN public.booking_payment_requirements requirement
  ON requirement.organization_id =
     booking.organization_id
 AND requirement.booking_id =
     booking.id
WHERE booking.id =
  (SELECT main_booking_id FROM s11s9_ids);


-- =====================================================================
-- Part 3 — RPC rejection boundary
-- =====================================================================

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000001'
);

-- 31
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    NULL
  )
  $$,
  '22023',
  'record_booking_adjusted_financial_obligation: booking_id is required',
  'null booking id is rejected'
);

-- 32
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    '9effffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'record_booking_adjusted_financial_obligation: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000004'
);

-- 33
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT sales_denied_booking_id FROM s11s9_ids)
  )
  $$,
  '42501',
  'record_booking_adjusted_financial_obligation: finance.write permission required',
  'Sales with finance.read but without finance.write cannot record obligation'
);

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000005'
);

-- 34
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT photographer_denied_booking_id FROM s11s9_ids)
  )
  $$,
  '42501',
  'record_booking_adjusted_financial_obligation: finance.write permission required',
  'Photographer without finance.write cannot record obligation'
);

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000001'
);

-- 35
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT stage11_booking_id FROM s11s9_ids)
  )
  $$,
  '22023',
  'record_booking_adjusted_financial_obligation: booking must be at active Stage 12 selection_pending',
  'obligation cannot be recorded from Stage 11'
);

-- 36
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT no_reconciliation_booking_id FROM s11s9_ids)
  )
  $$,
  'P0001',
  'record_booking_adjusted_financial_obligation: exactly one selection reconciliation required',
  'missing Slice 7 reconciliation fails closed'
);

-- 37
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT zero_excess_booking_id FROM s11s9_ids)
  )
  $$,
  '22023',
  'record_booking_adjusted_financial_obligation: positive reconciled excess is required',
  'zero excess does not create adjusted obligation'
);

-- 38
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT missing_pricing_booking_id FROM s11s9_ids)
  )
  $$,
  'P0001',
  'record_booking_adjusted_financial_obligation: exactly one additional-image pricing basis required',
  'missing Slice 8 pricing basis fails closed'
);


-- ---------------------------------------------------------------------
-- Remove only the immutable payment requirement for one transaction-local
-- fixture to prove missing principal authority fails closed.
-- ---------------------------------------------------------------------

ALTER TABLE public.booking_payment_requirements
DISABLE TRIGGER USER;

DELETE FROM public.booking_payment_requirements
WHERE booking_id =
  (SELECT missing_requirement_booking_id FROM s11s9_ids);

ALTER TABLE public.booking_payment_requirements
ENABLE TRIGGER USER;

-- 39
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT missing_requirement_booking_id FROM s11s9_ids)
  )
  $$,
  'P0001',
  'record_booking_adjusted_financial_obligation: exactly one booking payment requirement required',
  'missing accepted-booking principal authority fails closed'
);


-- =====================================================================
-- Part 4 — Deterministic obligation behavior
-- =====================================================================

-- 40
SELECT lives_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT main_booking_id FROM s11s9_ids)
  )
  $$,
  'Founder records adjusted obligation successfully'
);

-- 41
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  1::bigint,
  'exactly one adjusted obligation is recorded'
);

-- 42
SELECT ok(
  (
    SELECT
      obligation.source_payment_requirement_id =
        requirement.id
      AND obligation.source_quotation_id =
        booking.source_quotation_id
      AND obligation.source_reconciliation_id =
        reconciliation.id
      AND obligation.source_pricing_basis_id =
        basis.id
    FROM public.booking_adjusted_financial_obligations obligation
    JOIN public.bookings booking
      ON booking.organization_id =
         obligation.organization_id
     AND booking.id =
         obligation.booking_id
    JOIN public.booking_payment_requirements requirement
      ON requirement.organization_id =
         obligation.organization_id
     AND requirement.booking_id =
         obligation.booking_id
    JOIN public.booking_selection_reconciliations reconciliation
      ON reconciliation.organization_id =
         obligation.organization_id
     AND reconciliation.booking_id =
         obligation.booking_id
    JOIN public.booking_additional_image_pricing_bases basis
      ON basis.organization_id =
         obligation.organization_id
     AND basis.booking_id =
         obligation.booking_id
    WHERE obligation.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  'obligation snapshots exact canonical source identities'
);

-- 43
SELECT ok(
  (
    SELECT
      obligation.excess_image_count = 3
      AND obligation.applied_unit_price_inr = 500
      AND obligation.accepted_quotation_total_inr =
          requirement.accepted_quotation_total_inr
    FROM public.booking_adjusted_financial_obligations obligation
    JOIN public.booking_payment_requirements requirement
      ON requirement.organization_id =
         obligation.organization_id
     AND requirement.booking_id =
         obligation.booking_id
    WHERE obligation.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  'principal, quantity, and applied unit price come from frozen authorities'
);

-- 44
SELECT is(
  (
    SELECT excess_image_charge_inr
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  1500::bigint,
  'three excess images at INR 500 produce exact INR 1500 charge'
);

-- 45
SELECT ok(
  (
    SELECT
      obligation.adjusted_total_inr =
        obligation.accepted_quotation_total_inr::bigint +
        1500::bigint
    FROM public.booking_adjusted_financial_obligations obligation
    WHERE obligation.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  'adjusted total is accepted principal plus exact excess charge'
);

-- 46
SELECT ok(
  (
    SELECT
      currency = 'INR'
      AND calculation_rule =
          'accepted_quote_plus_excess_image_charge_v1'
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  'obligation uses exact INR calculation rule'
);

-- 47
SELECT is(
  (
    SELECT recorded_by
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  '9e000000-0000-0000-0000-000000000101'::uuid,
  'Founder organization member is recorded as actor'
);

-- 48
SELECT lives_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT main_booking_id FROM s11s9_ids)
  )
  $$,
  'exact replay succeeds idempotently'
);

-- 49
SELECT ok(
  (
    SELECT
      (
        public.record_booking_adjusted_financial_obligation(
          (SELECT main_booking_id FROM s11s9_ids)
        )
      ).id =
      obligation.id
    FROM public.booking_adjusted_financial_obligations obligation
    WHERE obligation.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  'exact replay returns the same immutable obligation id'
);

-- 50
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  1::bigint,
  'replay does not create a second obligation'
);

-- 51
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    JOIN public.booking_adjusted_financial_obligations obligation
      ON obligation.id =
         audit.entity_id
    WHERE audit.action_key =
          'booking.adjusted_financial_obligation_recorded'
      AND obligation.booking_id =
          (SELECT main_booking_id FROM s11s9_ids)
  ),
  1::bigint,
  'exact replay does not duplicate audit evidence'
);

-- 52
SELECT ok(
  (
    SELECT
      audit.new_values ->>
        'excess_image_charge_inr' = '1500'
      AND audit.new_values ->>
        'calculation_rule' =
          'accepted_quote_plus_excess_image_charge_v1'
      AND audit.metadata ->>
        'booking_id' =
          (SELECT main_booking_id::text FROM s11s9_ids)
      AND NOT audit.is_sensitive
    FROM public.audit_events audit
    JOIN public.booking_adjusted_financial_obligations obligation
      ON obligation.id =
         audit.entity_id
    WHERE audit.action_key =
          'booking.adjusted_financial_obligation_recorded'
      AND obligation.booking_id =
          (SELECT main_booking_id FROM s11s9_ids)
  ),
  'audit records only structural obligation provenance and values'
);

-- 53
SELECT ok(
  (
    SELECT NOT (
      COALESCE(audit.new_values, '{}'::jsonb)
        ?| ARRAY[
          'amount_paid',
          'amount_due',
          'balance_due',
          'outstanding',
          'overpayment',
          'refund_due',
          'settlement_status',
          'paid_in_full'
        ]
      OR
      COALESCE(audit.metadata, '{}'::jsonb)
        ?| ARRAY[
          'amount_paid',
          'amount_due',
          'balance_due',
          'outstanding',
          'overpayment',
          'refund_due',
          'settlement_status',
          'paid_in_full'
        ]
    )
    FROM public.audit_events audit
    JOIN public.booking_adjusted_financial_obligations obligation
      ON obligation.id =
         audit.entity_id
    WHERE audit.action_key =
          'booking.adjusted_financial_obligation_recorded'
      AND obligation.booking_id =
          (SELECT main_booking_id FROM s11s9_ids)
  ),
  'audit contains no settlement or amount-due semantics'
);


-- =====================================================================
-- Part 5 — Financial / journey containment
-- =====================================================================

-- 54
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  (
    SELECT state_version
    FROM s11s9_main_baseline
  ),
  'obligation recording does not change journey-state version'
);

-- 55
SELECT is(
  (
    SELECT state.current_stage_id
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  (
    SELECT current_stage_id
    FROM s11s9_main_baseline
  ),
  'obligation recording does not change current journey stage'
);

-- 56
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  (
    SELECT transition_count::bigint
    FROM s11s9_main_baseline
  ),
  'obligation recording creates no journey transition'
);

-- 57
SELECT is(
  (
    SELECT quotation.quoted_total_inr
    FROM public.bookings booking
    JOIN public.quotations quotation
      ON quotation.organization_id =
         booking.organization_id
     AND quotation.id =
         booking.source_quotation_id
    WHERE booking.id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  (
    SELECT quoted_total_inr
    FROM s11s9_main_baseline
  ),
  'accepted quotation remains unchanged'
);

-- 58
SELECT is(
  (
    SELECT requirement.required_advance_inr
    FROM public.booking_payment_requirements requirement
    WHERE requirement.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  (
    SELECT required_advance_inr
    FROM s11s9_main_baseline
  ),
  'immutable advance payment requirement remains unchanged'
);

-- 59
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payments payment
    WHERE payment.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  (
    SELECT payment_count::bigint
    FROM s11s9_main_baseline
  ),
  'obligation recording creates no booking payment'
);

-- 60
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payment_reversals reversal
    WHERE reversal.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  (
    SELECT reversal_count::bigint
    FROM s11s9_main_baseline
  ),
  'obligation recording creates no payment reversal'
);

-- 61
SELECT is(
  (
    SELECT stage.stage_order
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  12::smallint,
  'obligation booking remains exact Stage 12'
);

-- 62
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
          (SELECT main_booking_id FROM s11s9_ids)
      AND stage.stage_order = 13
      AND stage.stage_key =
          'editing_pending'
  ),
  0::bigint,
  'obligation recording creates no Stage 12 to 13 transition'
);


-- =====================================================================
-- Part 6 — finance.write role topology
-- =====================================================================

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000002'
);

-- 63
SELECT lives_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT accounts_booking_id FROM s11s9_ids)
  )
  $$,
  'Accounts with finance.write may record adjusted obligation'
);

-- 64
SELECT is(
  (
    SELECT recorded_by
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT accounts_booking_id FROM s11s9_ids)
  ),
  '9e000000-0000-0000-0000-000000000102'::uuid,
  'Accounts actor attribution is exact'
);

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000003'
);

-- 65
SELECT lives_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT studio_booking_id FROM s11s9_ids)
  )
  $$,
  'Studio Manager with finance.write may record adjusted obligation'
);

-- 66
SELECT is(
  (
    SELECT recorded_by
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT studio_booking_id FROM s11s9_ids)
  ),
  '9e000000-0000-0000-0000-000000000103'::uuid,
  'Studio Manager actor attribution is exact'
);


-- =====================================================================
-- Part 7 — Runtime finance.read containment
-- =====================================================================

GRANT SELECT
ON TABLE s11s9_ids
TO authenticated;

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000001'
);

SET LOCAL ROLE authenticated;

-- 67
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  1::bigint,
  'Founder with finance.read can read adjusted obligation'
);

RESET ROLE;

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000002'
);

SET LOCAL ROLE authenticated;

-- 68
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  1::bigint,
  'Accounts with finance.read can read adjusted obligation'
);

RESET ROLE;

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000004'
);

SET LOCAL ROLE authenticated;

-- 69
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  1::bigint,
  'Sales with finance.read can read adjusted obligation'
);

RESET ROLE;

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000003'
);

SET LOCAL ROLE authenticated;

-- 70
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  1::bigint,
  'Studio Manager with finance.read can read adjusted obligation'
);

RESET ROLE;

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000005'
);

SET LOCAL ROLE authenticated;

-- 71
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT main_booking_id FROM s11s9_ids)
  ),
  0::bigint,
  'Photographer without finance.read cannot read adjusted obligation'
);

RESET ROLE;

SELECT pg_temp.s11s9_set_actor(
  '9e000000-0000-0000-0000-000000000001'
);


-- =====================================================================
-- Part 8 — Corrupt-source rejection / immutability
-- =====================================================================

-- Transaction-local corruption only: disable the Slice 8 immutable guard
-- and point this fixture's pricing basis at another accepted quotation.
-- All FK identities remain valid, but exact booking lineage is wrong.

ALTER TABLE public.booking_additional_image_pricing_bases
DISABLE TRIGGER USER;

UPDATE public.booking_additional_image_pricing_bases basis
SET source_quotation_id = (
  SELECT booking.source_quotation_id
  FROM public.bookings booking
  WHERE booking.id =
    (SELECT sales_denied_booking_id FROM s11s9_ids)
)
WHERE basis.booking_id =
  (SELECT mismatch_pricing_booking_id FROM s11s9_ids);

ALTER TABLE public.booking_additional_image_pricing_bases
ENABLE TRIGGER USER;

-- 72
SELECT throws_ok(
  $$
  SELECT public.record_booking_adjusted_financial_obligation(
    (SELECT mismatch_pricing_booking_id FROM s11s9_ids)
  )
  $$,
  'P0001',
  'record_booking_adjusted_financial_obligation: pricing-basis lineage is inconsistent',
  'mismatched Slice 8 quotation lineage fails closed'
);

-- 73
SELECT throws_ok(
  $$
  UPDATE public.booking_adjusted_financial_obligations
  SET adjusted_total_inr =
      adjusted_total_inr + 1
  WHERE booking_id =
    (SELECT main_booking_id FROM s11s9_ids)
  $$,
  'P0001',
  'booking adjusted financial-obligation evidence is immutable',
  'adjusted obligation cannot be updated'
);

-- 74
SELECT throws_ok(
  $$
  DELETE FROM public.booking_adjusted_financial_obligations
  WHERE booking_id =
    (SELECT main_booking_id FROM s11s9_ids)
  $$,
  'P0001',
  'booking adjusted financial-obligation evidence is immutable',
  'adjusted obligation cannot be deleted'
);

-- 75
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  71::bigint,
  'Slice 9 behavior leaves permission catalogue unchanged'
);

-- 76
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  246::bigint,
  'Slice 9 behavior leaves role-permission mappings unchanged'
);

SELECT * FROM finish();

ROLLBACK;
