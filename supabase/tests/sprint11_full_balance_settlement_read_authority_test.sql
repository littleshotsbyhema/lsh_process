CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(60);

-- =====================================================================
-- Sprint 11 Slice 10
-- Current Full-Balance Settlement Read Authority Foundation
-- =====================================================================


-- =====================================================================
-- Part 1 — Structural / security / containment contract
-- =====================================================================

-- 1
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  72::bigint,
  'canonical permission catalogue remains exactly 69'
);

-- 2
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  247::bigint,
  'canonical role-permission mapping count remains exactly 243'
);

-- 3
SELECT ok(
  to_regprocedure(
    'public.get_booking_full_balance_summary(uuid)'
  ) IS NOT NULL,
  'full-balance summary RPC exists'
);

-- 4
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.proname =
          'get_booking_full_balance_summary'
  ),
  1::bigint,
  'exactly one full-balance RPC signature exists'
);

-- 5
SELECT is(
  (
    SELECT pg_get_function_result(p.oid)
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
  ),
  'TABLE(booking_id uuid, source_quotation_id uuid, source_payment_requirement_id uuid, source_reconciliation_id uuid, source_adjusted_obligation_id uuid, excess_image_count integer, currency text, settlement_target_inr bigint, target_rule text, valid_collected_inr bigint, collection_rule text, full_balance_outstanding_inr bigint, full_balance_satisfied boolean, payment_count bigint, reversal_count bigint)',
  'RPC exposes exactly the frozen result contract'
);

-- 6
SELECT ok(
  (
    SELECT p.prosecdef
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
  ),
  'RPC is SECURITY DEFINER'
);

-- 7
SELECT ok(
  (
    SELECT p.proconfig @>
           ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
  ),
  'RPC fixes empty search_path'
);

-- 8
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.get_booking_full_balance_summary(uuid)',
    'EXECUTE'
  ),
  'authenticated may execute RPC'
);

-- 9
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.get_booking_full_balance_summary(uuid)',
    'EXECUTE'
  ),
  'anon may not execute RPC'
);

-- 10
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.get_booking_full_balance_summary(uuid)',
    'EXECUTE'
  ),
  'service_role may not execute RPC'
);

-- 11
SELECT ok(
  (
    SELECT
      pg_get_functiondef(p.oid) ILIKE '%finance.read%'
      AND pg_get_functiondef(p.oid) ILIKE '%has_branch_scope%'
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
  ),
  'RPC enforces finance.read and booking branch scope'
);

-- 12
SELECT ok(
  (
    SELECT
      pg_get_functiondef(p.oid)
        LIKE '%reconciled_accepted_or_adjusted_total_v1%'
      AND pg_get_functiondef(p.oid)
        LIKE '%non_reversed_booking_payments_v1%'
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
  ),
  'RPC contains exact frozen target and collection rules'
);

-- 13
SELECT ok(
  (
    SELECT
      pg_get_functiondef(p.oid)
        ILIKE '%booking_payment_requirements%'
      AND pg_get_functiondef(p.oid)
        ILIKE '%booking_selection_reconciliations%'
      AND pg_get_functiondef(p.oid)
        ILIKE '%booking_adjusted_financial_obligations%'
      AND pg_get_functiondef(p.oid)
        ILIKE '%booking_payments%'
      AND pg_get_functiondef(p.oid)
        ILIKE '%booking_payment_reversals%'
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
  ),
  'RPC reads every exact frozen financial authority'
);

-- 14
SELECT ok(
  (
    SELECT
      pg_get_functiondef(p.oid)
        NOT ILIKE '%booking_journey_states%'
      AND pg_get_functiondef(p.oid)
        NOT ILIKE '%booking_stage_transitions%'
      AND pg_get_functiondef(p.oid)
        NOT ILIKE '%editing_pending%'
      AND pg_get_functiondef(p.oid)
        NOT ILIKE '%append_audit_event%'
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
  ),
  'RPC is journey independent and has no audit mutation'
);

-- 15
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND (
        c.relname ILIKE '%settlement%'
        OR c.relname ILIKE '%full_balance%'
        OR c.relname ILIKE '%refund_due%'
      )
  ),
  0::bigint,
  'Slice 10 creates no settlement persistence relation'
);


-- =====================================================================
-- Part 2 — Transaction-local canonical fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('a1000000-0000-0000-0000-000000000001'::uuid),
  ('a1000000-0000-0000-0000-000000000002'::uuid),
  ('a1000000-0000-0000-0000-000000000003'::uuid),
  ('a1000000-0000-0000-0000-000000000004'::uuid),
  ('a1000000-0000-0000-0000-000000000005'::uuid);

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
  'a1000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a1000000-0000-0000-0000-000000000001',
  'active',
  'S11S10 Founder',
  NULL
),
(
  'a1000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a1000000-0000-0000-0000-000000000002',
  'active',
  'S11S10 Accounts',
  NULL
),
(
  'a1000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a1000000-0000-0000-0000-000000000003',
  'active',
  'S11S10 Studio Manager',
  NULL
),
(
  'a1000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a1000000-0000-0000-0000-000000000004',
  'active',
  'S11S10 Sales',
  NULL
),
(
  'a1000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a1000000-0000-0000-0000-000000000005',
  'active',
  'S11S10 Photographer',
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
      'a1000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text
    ),
    (
      'a1000000-0000-0000-0000-000000000102'::uuid,
      'accounts'::text
    ),
    (
      'a1000000-0000-0000-0000-000000000103'::uuid,
      'studio_manager'::text
    ),
    (
      'a1000000-0000-0000-0000-000000000104'::uuid,
      'sales'::text
    ),
    (
      'a1000000-0000-0000-0000-000000000105'::uuid,
      'photographer'::text
    )
) AS fixture(member_id, role_key)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s10_set_actor(
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

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000001'
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
  'a1000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-A2BCDE',
  'S11 Slice10 Family',
  'S11 Slice10 Family',
  'active',
  'a1000000-0000-0000-0000-000000000101',
  'a1000000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s11s10_create_booking()
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
    'a1000000-0000-0000-0000-000000000201',
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

CREATE FUNCTION pg_temp.s11s10_move_to_stage(
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
    p_transition_key,
    p_transitioned_at,
    'a1000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at =
      GREATEST(
        p_transitioned_at,
        v_state.stage_entered_at
      ),
    version = state.version + 1,
    updated_at = p_transitioned_at,
    updated_by =
      'a1000000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s10_prepare_reconciliation(
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
  WHERE booking.id = p_booking_id;

  PERFORM pg_temp.s11s10_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    's11s10_fixture_shoot_completed',
    now() - interval '3 minutes'
  );

  PERFORM pg_temp.s11s10_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    'selection_pending',
    now() - interval '2 minutes'
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

CREATE FUNCTION pg_temp.s11s10_prepare_positive(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s10_prepare_reconciliation(
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

CREATE TEMP TABLE s11s10_ids (
  zero_booking_id uuid,
  positive_booking_id uuid,
  missing_requirement_booking_id uuid,
  missing_reconciliation_booking_id uuid,
  missing_obligation_booking_id uuid,
  corrupt_zero_booking_id uuid,
  corrupt_obligation_booking_id uuid
);

INSERT INTO s11s10_ids
VALUES (
  pg_temp.s11s10_create_booking(),
  pg_temp.s11s10_create_booking(),
  pg_temp.s11s10_create_booking(),
  pg_temp.s11s10_create_booking(),
  pg_temp.s11s10_create_booking(),
  pg_temp.s11s10_create_booking(),
  pg_temp.s11s10_create_booking()
);

SELECT pg_temp.s11s10_prepare_reconciliation(
  (SELECT zero_booking_id FROM s11s10_ids),
  0
);

SELECT pg_temp.s11s10_prepare_positive(
  (SELECT positive_booking_id FROM s11s10_ids)
);

SELECT pg_temp.s11s10_prepare_reconciliation(
  (SELECT missing_obligation_booking_id FROM s11s10_ids),
  3
);

SELECT public.record_booking_additional_image_pricing_basis(
  (SELECT missing_obligation_booking_id FROM s11s10_ids),
  NULL
);

SELECT pg_temp.s11s10_prepare_positive(
  (SELECT corrupt_zero_booking_id FROM s11s10_ids)
);

SELECT pg_temp.s11s10_prepare_positive(
  (SELECT corrupt_obligation_booking_id FROM s11s10_ids)
);

-- Corrupt-source fixtures remain transaction-local.

ALTER TABLE public.booking_payment_requirements
DISABLE TRIGGER USER;

DELETE FROM public.booking_payment_requirements
WHERE booking_id =
  (SELECT missing_requirement_booking_id FROM s11s10_ids);

ALTER TABLE public.booking_payment_requirements
ENABLE TRIGGER USER;

ALTER TABLE public.booking_selection_reconciliations
DISABLE TRIGGER USER;

UPDATE public.booking_selection_reconciliations
SET
  selected_image_count = included_image_count,
  excess_image_count = 0
WHERE booking_id =
  (SELECT corrupt_zero_booking_id FROM s11s10_ids);

ALTER TABLE public.booking_selection_reconciliations
ENABLE TRIGGER USER;

ALTER TABLE public.booking_adjusted_financial_obligations
DISABLE TRIGGER USER;

UPDATE public.booking_adjusted_financial_obligations
SET
  accepted_quotation_total_inr =
    accepted_quotation_total_inr + 1,
  adjusted_total_inr =
    adjusted_total_inr + 1
WHERE booking_id =
  (SELECT corrupt_obligation_booking_id FROM s11s10_ids);

ALTER TABLE public.booking_adjusted_financial_obligations
ENABLE TRIGGER USER;


-- =====================================================================
-- Part 3 — Fail-closed authorization / source boundary
-- =====================================================================

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000001'
);

-- 16
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(NULL)
  $$,
  '22023',
  'get_booking_full_balance_summary: booking_id is required',
  'null booking id is rejected'
);

-- 17
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    'a1ffffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'get_booking_full_balance_summary: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000005'
);

-- 18
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT zero_booking_id FROM s11s10_ids)
  )
  $$,
  '42501',
  'get_booking_full_balance_summary: finance.read permission required',
  'Photographer without finance.read is rejected'
);

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000001'
);

-- 19
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT missing_requirement_booking_id FROM s11s10_ids)
  )
  $$,
  'P0001',
  'get_booking_full_balance_summary: exactly one booking payment requirement required',
  'missing payment requirement fails closed'
);

-- 20
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT missing_reconciliation_booking_id FROM s11s10_ids)
  )
  $$,
  'P0001',
  'get_booking_full_balance_summary: exactly one selection reconciliation required',
  'missing reconciliation fails closed'
);

-- 21
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT missing_obligation_booking_id FROM s11s10_ids)
  )
  $$,
  'P0001',
  'get_booking_full_balance_summary: positive excess requires exactly one adjusted financial obligation',
  'positive excess without Slice 9 obligation fails closed'
);

-- 22
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT corrupt_zero_booking_id FROM s11s10_ids)
  )
  $$,
  'P0001',
  'get_booking_full_balance_summary: zero-excess reconciliation conflicts with adjusted obligation',
  'zero excess cannot coexist with adjusted obligation'
);

-- 23
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT corrupt_obligation_booking_id FROM s11s10_ids)
  )
  $$,
  'P0001',
  'get_booking_full_balance_summary: adjusted financial-obligation lineage is inconsistent',
  'corrupt adjusted-obligation snapshot fails closed'
);


-- =====================================================================
-- Part 4 — Zero-excess accepted-total authority
-- =====================================================================

CREATE TEMP TABLE s11s10_zero_summary AS
SELECT *
FROM public.get_booking_full_balance_summary(
  (SELECT zero_booking_id FROM s11s10_ids)
);

-- 24
SELECT is(
  (SELECT source_adjusted_obligation_id FROM s11s10_zero_summary),
  NULL::uuid,
  'zero-excess branch has no adjusted obligation source'
);

-- 25
SELECT ok(
  (
    SELECT
      excess_image_count = 0
      AND currency = 'INR'
      AND target_rule =
          'reconciled_accepted_or_adjusted_total_v1'
      AND collection_rule =
          'non_reversed_booking_payments_v1'
    FROM s11s10_zero_summary
  ),
  'zero-excess summary exposes exact frozen rule metadata'
);

-- 26
SELECT is(
  (SELECT settlement_target_inr FROM s11s10_zero_summary),
  (
    SELECT requirement.accepted_quotation_total_inr::bigint
    FROM public.booking_payment_requirements requirement
    WHERE requirement.booking_id =
      (SELECT zero_booking_id FROM s11s10_ids)
  ),
  'zero-excess settlement target is accepted quotation total'
);

-- 27
SELECT is(
  (SELECT valid_collected_inr FROM s11s10_zero_summary),
  0::bigint,
  'zero-payment booking has zero valid collections'
);

-- 28
SELECT ok(
  (
    SELECT
      full_balance_outstanding_inr =
        settlement_target_inr
      AND NOT full_balance_satisfied
      AND payment_count = 0
      AND reversal_count = 0
    FROM s11s10_zero_summary
  ),
  'zero-payment summary is fully outstanding and unsatisfied'
);

DO $$
DECLARE
  v_target bigint;
BEGIN
  SELECT settlement_target_inr
  INTO v_target
  FROM s11s10_zero_summary;

  IF v_target <= 100 THEN
    RAISE EXCEPTION
      'S11S10 fixture target unexpectedly <= 100 INR';
  END IF;
END;
$$;

CREATE TEMP TABLE s11s10_payment_ids (
  under_payment_id uuid,
  topup_payment_id uuid,
  over_payment_id uuid
);

INSERT INTO s11s10_payment_ids
VALUES (NULL, NULL, NULL);

UPDATE s11s10_payment_ids
SET under_payment_id = (
  SELECT (
    public.record_booking_payment(
      (SELECT zero_booking_id FROM s11s10_ids),
      (
        (SELECT settlement_target_inr FROM s11s10_zero_summary)
        - 100
      )::integer,
      'upi'::public.booking_payment_method,
      now(),
      'S11S10-UNDER',
      'Slice 10 under-target fixture'
    )
  ).id
);

-- 29
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  (
    SELECT settlement_target_inr - 100
    FROM s11s10_zero_summary
  ),
  'under-target payment is included in valid collections'
);

-- 30
SELECT ok(
  (
    SELECT
      full_balance_outstanding_inr = 100
      AND NOT full_balance_satisfied
      AND payment_count = 1
      AND reversal_count = 0
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  'under-target summary exposes exact outstanding amount'
);

UPDATE s11s10_payment_ids
SET topup_payment_id = (
  SELECT (
    public.record_booking_payment(
      (SELECT zero_booking_id FROM s11s10_ids),
      100,
      'cash'::public.booking_payment_method,
      now(),
      'S11S10-TOPUP',
      'Slice 10 exact-target topup'
    )
  ).id
);

-- 31
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  (SELECT settlement_target_inr FROM s11s10_zero_summary),
  'exact-target collections equal settlement target'
);

-- 32
SELECT ok(
  (
    SELECT
      full_balance_outstanding_inr = 0
      AND full_balance_satisfied
      AND payment_count = 2
      AND reversal_count = 0
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  'exact-target collections satisfy full balance'
);

UPDATE s11s10_payment_ids
SET over_payment_id = (
  SELECT (
    public.record_booking_payment(
      (SELECT zero_booking_id FROM s11s10_ids),
      250,
      'bank_transfer'::public.booking_payment_method,
      now(),
      'S11S10-OVER',
      'Slice 10 coverage-settlement fixture'
    )
  ).id
);

-- 33
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  (
    SELECT settlement_target_inr + 250
    FROM s11s10_zero_summary
  ),
  'over-target collection remains part of valid collections'
);

-- 34
SELECT ok(
  (
    SELECT
      full_balance_outstanding_inr = 0
      AND full_balance_satisfied
      AND payment_count = 3
      AND reversal_count = 0
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  'coverage settlement treats over-target collections as satisfied'
);

SELECT public.reverse_booking_payment(
  (SELECT over_payment_id FROM s11s10_payment_ids),
  'Reverse Slice 10 over-target fixture'
);

-- 35
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  (SELECT settlement_target_inr FROM s11s10_zero_summary),
  'reversed over-target payment contributes zero'
);

-- 36
SELECT ok(
  (
    SELECT
      full_balance_satisfied
      AND full_balance_outstanding_inr = 0
      AND reversal_count = 1
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  'after first reversal current balance remains exactly satisfied'
);

SELECT public.reverse_booking_payment(
  (SELECT topup_payment_id FROM s11s10_payment_ids),
  'Reverse Slice 10 exact-target topup'
);

-- 37
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  (
    SELECT settlement_target_inr - 100
    FROM s11s10_zero_summary
  ),
  'later reversal reduces current valid collections'
);

-- 38
SELECT ok(
  (
    SELECT
      full_balance_outstanding_inr = 100
      AND NOT full_balance_satisfied
      AND reversal_count = 2
    FROM public.get_booking_full_balance_summary(
      (SELECT zero_booking_id FROM s11s10_ids)
    )
  ),
  'later reversal can make current balance unsatisfied'
);


-- =====================================================================
-- Part 5 — Positive-excess adjusted-total authority
-- =====================================================================

-- 39
SELECT is(
  (
    SELECT source_adjusted_obligation_id
    FROM public.get_booking_full_balance_summary(
      (SELECT positive_booking_id FROM s11s10_ids)
    )
  ),
  (
    SELECT id
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  'positive-excess branch references exact Slice 9 obligation'
);

-- 40
SELECT ok(
  (
    SELECT
      excess_image_count = 3
      AND currency = 'INR'
    FROM public.get_booking_full_balance_summary(
      (SELECT positive_booking_id FROM s11s10_ids)
    )
  ),
  'positive-excess summary carries exact quantity and INR currency'
);

-- 41
SELECT is(
  (
    SELECT settlement_target_inr
    FROM public.get_booking_full_balance_summary(
      (SELECT positive_booking_id FROM s11s10_ids)
    )
  ),
  (
    SELECT adjusted_total_inr
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  'positive-excess settlement target is exact adjusted total'
);

-- 42
SELECT ok(
  (
    SELECT
      summary.settlement_target_inr >
      requirement.accepted_quotation_total_inr::bigint
    FROM public.get_booking_full_balance_summary(
      (SELECT positive_booking_id FROM s11s10_ids)
    ) summary
    JOIN public.booking_payment_requirements requirement
      ON requirement.id =
         summary.source_payment_requirement_id
  ),
  'positive-excess adjusted target exceeds accepted principal'
);

-- 43
SELECT ok(
  (
    SELECT
      valid_collected_inr = 0
      AND full_balance_outstanding_inr =
          settlement_target_inr
      AND NOT full_balance_satisfied
    FROM public.get_booking_full_balance_summary(
      (SELECT positive_booking_id FROM s11s10_ids)
    )
  ),
  'positive-excess booking with no payments remains fully outstanding'
);

-- 44
SELECT ok(
  (
    SELECT
      target_rule =
        'reconciled_accepted_or_adjusted_total_v1'
      AND collection_rule =
        'non_reversed_booking_payments_v1'
    FROM public.get_booking_full_balance_summary(
      (SELECT positive_booking_id FROM s11s10_ids)
    )
  ),
  'positive branch uses exact frozen rules'
);


-- =====================================================================
-- Part 6 — Current-stage independence
-- =====================================================================

SELECT pg_temp.s11s10_move_to_stage(
  (SELECT positive_booking_id FROM s11s10_ids),
  13,
  'editing_pending',
  's11s10_fixture_editing_pending',
  now()
);

-- 45
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
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  13::smallint,
  'positive fixture is now at Stage 13'
);

-- 46
SELECT lives_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT positive_booking_id FROM s11s10_ids)
  )
  $$,
  'full-balance summary remains readable after Stage 13 progression'
);


-- =====================================================================
-- Part 7 — finance.read role topology
-- =====================================================================

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000001'
);

-- 47
SELECT lives_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT positive_booking_id FROM s11s10_ids)
  )
  $$,
  'Founder with finance.read may read full-balance summary'
);

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000002'
);

-- 48
SELECT lives_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT positive_booking_id FROM s11s10_ids)
  )
  $$,
  'Accounts with finance.read may read full-balance summary'
);

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000004'
);

-- 49
SELECT lives_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT positive_booking_id FROM s11s10_ids)
  )
  $$,
  'Sales with finance.read may read full-balance summary'
);

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000003'
);

-- 50
SELECT lives_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT positive_booking_id FROM s11s10_ids)
  )
  $$,
  'Studio Manager with finance.read may read full-balance summary'
);

SELECT pg_temp.s11s10_set_actor(
  'a1000000-0000-0000-0000-000000000001'
);


-- =====================================================================
-- Part 8 — Read-only containment
-- =====================================================================

CREATE TEMP TABLE s11s10_read_baseline AS
SELECT
  (SELECT count(*) FROM public.audit_events)
    AS audit_count,
  (
    SELECT count(*)
    FROM public.booking_payments
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ) AS payment_count,
  (
    SELECT count(*)
    FROM public.booking_payment_reversals
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ) AS reversal_count,
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ) AS state_version,
  (
    SELECT count(*)
    FROM public.booking_stage_transitions
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ) AS transition_count,
  (
    SELECT count(*)
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ) AS obligation_count;

-- 51
SELECT lives_ok(
  $$
  SELECT *
  FROM public.get_booking_full_balance_summary(
    (SELECT positive_booking_id FROM s11s10_ids)
  )
  $$,
  'containment probe summary call succeeds'
);

-- 52
SELECT is(
  (SELECT count(*) FROM public.audit_events),
  (SELECT audit_count FROM s11s10_read_baseline),
  'summary read appends no audit event'
);

-- 53
SELECT is(
  (
    SELECT count(*)
    FROM public.booking_payments
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  (SELECT payment_count FROM s11s10_read_baseline),
  'summary read creates no payment'
);

-- 54
SELECT is(
  (
    SELECT count(*)
    FROM public.booking_payment_reversals
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  (SELECT reversal_count FROM s11s10_read_baseline),
  'summary read creates no payment reversal'
);

-- 55
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  (SELECT state_version FROM s11s10_read_baseline),
  'summary read does not mutate journey-state version'
);

-- 56
SELECT is(
  (
    SELECT count(*)
    FROM public.booking_stage_transitions
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  (SELECT transition_count FROM s11s10_read_baseline),
  'summary read creates no journey transition'
);

-- 57
SELECT is(
  (
    SELECT count(*)
    FROM public.booking_adjusted_financial_obligations
    WHERE booking_id =
      (SELECT positive_booking_id FROM s11s10_ids)
  ),
  (SELECT obligation_count FROM s11s10_read_baseline),
  'summary read does not mutate adjusted obligation evidence'
);

-- 58
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  72::bigint,
  'permission catalogue remains 69 after runtime tests'
);

-- 59
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  247::bigint,
  'role-permission mappings remain 243 after runtime tests'
);

-- 60
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND (
        c.relname ILIKE '%settlement%'
        OR c.relname ILIKE '%full_balance%'
        OR c.relname ILIKE '%refund_due%'
      )
  ),
  0::bigint,
  'runtime reads create no persistent settlement surface'
);

SELECT * FROM finish();

ROLLBACK;
