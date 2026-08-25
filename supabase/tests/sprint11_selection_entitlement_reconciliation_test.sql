CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(82);

-- =====================================================================
-- Sprint 11 Slice 7
-- Booking-Level Selection Entitlement Reconciliation Evidence Foundation
--
-- Proves:
--   * exact immutable reconciliation relation;
--   * tenant-safe booking / quotation / confirmation / actor provenance;
--   * accepted_quote_version_entitlement_v1;
--   * explicit zero-overage evidence;
--   * exact positive overage calculation;
--   * accepted additional_image quantity contributes entitlement;
--   * unrelated add-ons contribute zero;
--   * custom lines contribute zero;
--   * selection.record mutation authority;
--   * selection.read read containment;
--   * exact Stage 12 containment;
--   * deterministic replay;
--   * structural conflict rejection;
--   * missing package entitlement fails closed;
--   * immutable structural audit;
--   * no quotation/payment/journey mutation;
--   * no pricing lookup;
--   * no runtime label parsing;
--   * no Stage 12 -> 13 advancement.
-- =====================================================================

-- =====================================================================
-- Part 1 — Structural / ACL / RLS contract
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
  to_regclass(
    'public.booking_selection_reconciliations'
  ) IS NOT NULL,
  'booking_selection_reconciliations exists'
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
          'booking_selection_reconciliations'
  ),
  ARRAY[
    'id',
    'organization_id',
    'booking_id',
    'source_quotation_id',
    'source_selection_confirmation_id',
    'selected_image_count',
    'included_image_count',
    'excess_image_count',
    'calculation_rule',
    'recorded_at',
    'recorded_by'
  ]::text[],
  'reconciliation evidence contains exactly the frozen 11 columns'
);

-- 5
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND constraint_row.conname =
          'booking_selection_reconciliations_org_booking_key'
      AND constraint_row.contype = 'u'
  ),
  'one reconciliation row per organization and booking is enforced'
);

-- 6
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_booking_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, booking_id) REFERENCES bookings(organization_id, id)%',
  'booking reconciliation FK is tenant-safe'
);

-- 7
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_quote_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, source_quotation_id) REFERENCES quotations(organization_id, id)%',
  'source quotation FK is tenant-safe'
);

-- 8
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_confirmation_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, booking_id, source_selection_confirmation_id) REFERENCES booking_selection_confirmations(organization_id, booking_id, id)%',
  'selection-confirmation provenance FK binds tenant + booking + confirmation'
);

-- 9
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_recorded_by_fkey'
  ) LIKE
    'FOREIGN KEY (recorded_by, organization_id) REFERENCES organization_members(id, organization_id)%',
  'recorded-by FK is tenant-safe'
);

-- 10
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_selected_count_chk'
  ),
  'positive selected-image count constraint exists'
);

-- 11
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_included_count_chk'
  ),
  'positive included-image count constraint exists'
);

-- 12
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_excess_count_chk'
  ),
  'non-negative excess-image count constraint exists'
);

-- 13
SELECT is(
  (
    SELECT regexp_replace(
             pg_get_constraintdef(oid),
             '[[:space:]()]',
             '',
             'g'
           )
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_formula_chk'
  ),
  'CHECKexcess_image_count=GREATESTselected_image_count-included_image_count,0',
  'database constraint freezes exact excess formula'
);

-- 14
SELECT ok(
  (
    SELECT pg_get_constraintdef(oid)
    FROM pg_constraint
    WHERE conrelid =
          'public.booking_selection_reconciliations'::regclass
      AND conname =
          'booking_selection_reconciliations_rule_chk'
  ) LIKE
    '%accepted_quote_version_entitlement_v1%',
  'database constraint freezes exact calculation rule'
);

-- 15
SELECT ok(
  (
    SELECT relation.relrowsecurity
    FROM pg_class relation
    WHERE relation.oid =
      'public.booking_selection_reconciliations'::regclass
  ),
  'reconciliation relation has RLS enabled'
);

-- 16
SELECT ok(
  (
    SELECT relation.relforcerowsecurity
    FROM pg_class relation
    WHERE relation.oid =
      'public.booking_selection_reconciliations'::regclass
  ),
  'reconciliation relation has forced RLS'
);

-- 17
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_selection_reconciliations',
    'SELECT'
  ),
  'authenticated has reconciliation SELECT'
);

-- 18
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_reconciliations',
    'INSERT'
  ),
  'authenticated has no direct reconciliation INSERT'
);

-- 19
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_reconciliations',
    'UPDATE'
  ),
  'authenticated has no direct reconciliation UPDATE'
);

-- 20
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_selection_reconciliations',
    'DELETE'
  ),
  'authenticated has no direct reconciliation DELETE'
);

-- 21
SELECT ok(
  to_regprocedure(
    'public.record_booking_selection_reconciliation(uuid)'
  ) IS NOT NULL,
  'record_booking_selection_reconciliation(uuid) exists'
);

-- 22
SELECT is(
  (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_selection_reconciliation(uuid)'::regprocedure
  ),
  'booking_selection_reconciliations'::text,
  'reconciliation RPC returns booking_selection_reconciliations'
);

-- 23
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_selection_reconciliation(uuid)'::regprocedure
  ),
  'reconciliation RPC is SECURITY DEFINER'
);

-- 24
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_selection_reconciliation(uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'reconciliation RPC uses empty search_path'
);

-- 25
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_selection_reconciliation(uuid)',
    'EXECUTE'
  ),
  'authenticated may execute reconciliation RPC'
);

-- 26
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.record_booking_selection_reconciliation(uuid)',
    'EXECUTE'
  ),
  'anon may not execute reconciliation RPC'
);

-- 27
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.record_booking_selection_reconciliation(uuid)',
    'EXECUTE'
  ),
  'service_role is not granted reconciliation RPC'
);

-- 28
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault('f', procedure.proowner)
      )
    ) acl_entry
    WHERE procedure.oid =
      'public.record_booking_selection_reconciliation(uuid)'::regprocedure
      AND acl_entry.grantee = 0
      AND acl_entry.privilege_type = 'EXECUTE'
  ),
  'PUBLIC may not execute reconciliation RPC'
);

-- 29
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.booking_selection_reconciliations'::regclass
      AND trigger_row.tgname =
          'booking_selection_reconciliations_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'exactly one reconciliation immutable guard trigger exists'
);

-- 30
SELECT ok(
  (
    SELECT
      qual LIKE '%selection.read%'
      AND qual LIKE '%has_branch_scope%'
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename =
          'booking_selection_reconciliations'
      AND policyname =
          'booking_selection_reconciliations_authenticated_select'
  ),
  'authenticated SELECT policy uses selection.read and branch containment'
);

-- 31
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename =
          'booking_selection_confirmations'
      AND indexname =
          'booking_selection_confirmations_org_booking_id_uidx'
      AND indexdef ILIKE
          '%UNIQUE INDEX%organization_id, booking_id, id%'
  ),
  'tenant-safe selection-confirmation provenance support index exists'
);

-- =====================================================================
-- Part 2 — Canonical fixture identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8f000000-0000-0000-0000-000000000001'::uuid),
  ('8f000000-0000-0000-0000-000000000002'::uuid),
  ('8f000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  '8f000000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice7 Branch A',
  's11s7-a',
  'active'
),
(
  '8f000000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice7 Branch B',
  's11s7-b',
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
  '8f000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8f000000-0000-0000-0000-000000000001',
  'active',
  'S11S7 Founder',
  NULL
),
(
  '8f000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8f000000-0000-0000-0000-000000000002',
  'active',
  'S11S7 Photographer',
  NULL
),
(
  '8f000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8f000000-0000-0000-0000-000000000003',
  'active',
  'S11S7 Branch Coordinator',
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
      '8f000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8f000000-0000-0000-0000-000000000102'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      '8f000000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      '8f000000-0000-0000-0000-000000000701'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s7_set_actor(
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

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000001'
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
  '8f000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-6789AF',
  'S11 Slice7 Family',
  'S11 Slice7 Family',
  'active',
  '8f000000-0000-0000-0000-000000000101',
  '8f000000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s11s7_create_booking(
  p_branch_id uuid DEFAULT NULL,
  p_additional_image_quantity integer DEFAULT 0,
  p_unrelated_addon_quantity integer DEFAULT 0,
  p_custom_line boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote public.quotations;
  v_booking public.bookings;

  v_package_version_id uuid;
  v_additional_image_version_id uuid;
  v_unrelated_version_id uuid;
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
    '8f000000-0000-0000-0000-000000000201',
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

  IF p_additional_image_quantity > 0 THEN
    SELECT version.id
    INTO v_additional_image_version_id
    FROM public.commercial_addon_versions version
    JOIN public.commercial_addons addon
      ON addon.organization_id =
         version.organization_id
     AND addon.id =
         version.addon_id
    WHERE addon.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND addon.addon_key =
          'additional_image'
      AND version.version_number = 1
      AND version.approval_status =
          'approved'::public.commercial_version_approval_status;

    PERFORM public.add_quotation_addon_line(
      v_quote.id,
      v_additional_image_version_id,
      p_additional_image_quantity,
      NULL
    );
  END IF;

  IF p_unrelated_addon_quantity > 0 THEN
    SELECT version.id
    INTO v_unrelated_version_id
    FROM public.commercial_addon_versions version
    JOIN public.commercial_addons addon
      ON addon.organization_id =
         version.organization_id
     AND addon.id =
         version.addon_id
    WHERE addon.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND addon.addon_key =
          'extra_frame_8x12'
      AND version.version_number = 1
      AND version.approval_status =
          'approved'::public.commercial_version_approval_status;

    PERFORM public.add_quotation_addon_line(
      v_quote.id,
      v_unrelated_version_id,
      p_unrelated_addon_quantity,
      NULL
    );
  END IF;

  IF p_custom_line THEN
    PERFORM public.add_quotation_custom_line(
      v_quote.id,
      'S11S7 Custom Commercial Line',
      'Fixture line with no image entitlement authority.',
      2,
      1000
    );
  END IF;

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

CREATE FUNCTION pg_temp.s11s7_move_to_stage(
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
    '8f000000-0000-0000-0000-000000000101'
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
      '8f000000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s7_prepare_stage12(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s7_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    's11s7_fixture_shoot_completed',
    now() - interval '11 minutes'
  );

  PERFORM pg_temp.s11s7_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    'selection_pending',
    now() - interval '10 minutes'
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s7_prepare_selection(
  p_booking_id uuid,
  p_selected_image_count integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s7_prepare_stage12(
    p_booking_id
  );

  PERFORM public.record_booking_selection_confirmation(
    p_booking_id,
    p_selected_image_count,
    now() - interval '5 minutes'
  );
END;
$$;

CREATE TEMP TABLE s11s7_ids (
  below_booking_id uuid,
  exact_booking_id uuid,
  over_booking_id uuid,
  addon_booking_id uuid,
  unrelated_booking_id uuid,
  custom_booking_id uuid,
  stage11_booking_id uuid,
  zero_state_booking_id uuid,
  missing_selection_booking_id uuid,
  branch_b_booking_id uuid,
  conflict_booking_id uuid,
  missing_entitlement_booking_id uuid
);

INSERT INTO s11s7_ids
VALUES (
  pg_temp.s11s7_create_booking(NULL, 0, 0, false),
  pg_temp.s11s7_create_booking(NULL, 0, 0, false),
  pg_temp.s11s7_create_booking(NULL, 0, 0, false),
  pg_temp.s11s7_create_booking(NULL, 3, 0, false),
  pg_temp.s11s7_create_booking(NULL, 0, 2, false),
  pg_temp.s11s7_create_booking(NULL, 0, 0, true),
  pg_temp.s11s7_create_booking(NULL, 0, 0, false),
  pg_temp.s11s7_create_booking(NULL, 0, 0, false),
  pg_temp.s11s7_create_booking(NULL, 0, 0, false),
  pg_temp.s11s7_create_booking(
    '8f000000-0000-0000-0000-000000000702',
    0,
    0,
    false
  ),
  pg_temp.s11s7_create_booking(NULL, 0, 0, false),
  pg_temp.s11s7_create_booking(NULL, 0, 0, false)
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT below_booking_id FROM s11s7_ids),
  18
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT exact_booking_id FROM s11s7_ids),
  20
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT over_booking_id FROM s11s7_ids),
  23
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT addon_booking_id FROM s11s7_ids),
  25
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT unrelated_booking_id FROM s11s7_ids),
  22
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT custom_booking_id FROM s11s7_ids),
  22
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT branch_b_booking_id FROM s11s7_ids),
  22
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT conflict_booking_id FROM s11s7_ids),
  22
);

SELECT pg_temp.s11s7_prepare_selection(
  (SELECT missing_entitlement_booking_id FROM s11s7_ids),
  22
);

SELECT pg_temp.s11s7_move_to_stage(
  (SELECT stage11_booking_id FROM s11s7_ids),
  11,
  'shoot_completed',
  's11s7_fixture_shoot_completed',
  now() - interval '10 minutes'
);

SELECT pg_temp.s11s7_prepare_stage12(
  (SELECT missing_selection_booking_id FROM s11s7_ids)
);

ALTER TABLE public.booking_journey_states
DISABLE TRIGGER USER;

DELETE FROM public.booking_journey_states
WHERE booking_id =
  (SELECT zero_state_booking_id FROM s11s7_ids);

ALTER TABLE public.booking_journey_states
ENABLE TRIGGER USER;

CREATE TEMP TABLE s11s7_over_baseline AS
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
  ) AS payment_count
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
  (SELECT over_booking_id FROM s11s7_ids);

-- =====================================================================
-- Part 3 — RPC rejection boundary
-- =====================================================================

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000001'
);

-- 32
SELECT throws_ok(
  $$ SELECT public.record_booking_selection_reconciliation(NULL) $$,
  '22023',
  'record_booking_selection_reconciliation: booking_id is required',
  'null booking id is rejected'
);

SELECT pg_temp.s11s7_set_actor(NULL);

-- 33
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT below_booking_id FROM s11s7_ids)
  )
  $$,
  '42501',
  'record_booking_selection_reconciliation: authenticated actor required',
  'unauthenticated reconciliation is rejected'
);

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000001'
);

-- 34
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    '8fffffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'record_booking_selection_reconciliation: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000002'
);

-- 35
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT below_booking_id FROM s11s7_ids)
  )
  $$,
  '42501',
  'record_booking_selection_reconciliation: selection.record permission required',
  'Photographer without selection.record is rejected'
);

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000003'
);

-- 36
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT branch_b_booking_id FROM s11s7_ids)
  )
  $$,
  '42501',
  'record_booking_selection_reconciliation: selection.record permission required',
  'branch-scoped Coordinator cannot reconcile another branch'
);

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000001'
);

-- 37
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT stage11_booking_id FROM s11s7_ids)
  )
  $$,
  '22023',
  'record_booking_selection_reconciliation: booking must be exactly Selection Pending',
  'Stage 11 reconciliation is rejected'
);

-- 38
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT zero_state_booking_id FROM s11s7_ids)
  )
  $$,
  'P0001',
  'record_booking_selection_reconciliation: booking must have exactly one current journey state',
  'missing journey state fails closed'
);

-- 39
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT missing_selection_booking_id FROM s11s7_ids)
  )
  $$,
  '22023',
  'record_booking_selection_reconciliation: selection confirmation required',
  'Stage 12 booking without canonical selection confirmation fails closed'
);

-- =====================================================================
-- Part 4 — Deterministic reconciliation
-- =====================================================================

-- 40
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT below_booking_id FROM s11s7_ids)
  )
  $$,
  'below-entitlement selection reconciles'
);

-- 41
SELECT is(
  (
    SELECT selected_image_count
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  18,
  'selected count snapshots canonical confirmation'
);

-- 42
SELECT is(
  (
    SELECT included_image_count
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  20,
  'maternity_gold exact version entitlement is 20'
);

-- 43
SELECT is(
  (
    SELECT excess_image_count
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  0,
  'below-entitlement reconciliation persists explicit zero excess'
);

-- 44
SELECT is(
  (
    SELECT calculation_rule
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  'accepted_quote_version_entitlement_v1',
  'canonical calculation rule is persisted exactly'
);

-- 45
SELECT ok(
  (
    SELECT
      reconciliation.source_quotation_id =
      booking.source_quotation_id
    FROM public.booking_selection_reconciliations reconciliation
    JOIN public.bookings booking
      ON booking.organization_id =
         reconciliation.organization_id
     AND booking.id =
         reconciliation.booking_id
    WHERE reconciliation.booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  'reconciliation snapshots exact booking source quotation'
);

-- 46
SELECT ok(
  (
    SELECT
      reconciliation.source_selection_confirmation_id =
      confirmation.id
    FROM public.booking_selection_reconciliations reconciliation
    JOIN public.booking_selection_confirmations confirmation
      ON confirmation.organization_id =
         reconciliation.organization_id
     AND confirmation.booking_id =
         reconciliation.booking_id
    WHERE reconciliation.booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  'reconciliation snapshots exact canonical selection confirmation'
);

-- 47
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT exact_booking_id FROM s11s7_ids)
  )
  $$,
  'exact-entitlement selection reconciles'
);

-- 48
SELECT is(
  (
    SELECT included_image_count
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT exact_booking_id FROM s11s7_ids)
  ),
  20,
  'exact-entitlement booking retains package inclusion 20'
);

-- 49
SELECT is(
  (
    SELECT excess_image_count
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT exact_booking_id FROM s11s7_ids)
  ),
  0,
  'exact entitlement persists explicit zero excess'
);

-- 50
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT over_booking_id FROM s11s7_ids)
  )
  $$,
  'positive-overage selection reconciles'
);

-- 51
SELECT is(
  (
    SELECT format(
      '%s,%s,%s,%s',
      selected_image_count,
      included_image_count,
      excess_image_count,
      calculation_rule
    )
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  '23,20,3,accepted_quote_version_entitlement_v1',
  'positive overage is calculated exactly from immutable counts'
);

CREATE TEMP TABLE s11s7_over_reconciliation AS
SELECT id
FROM public.booking_selection_reconciliations
WHERE booking_id =
  (SELECT over_booking_id FROM s11s7_ids);

-- 52
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT over_booking_id FROM s11s7_ids)
  )
  $$,
  'exact reconciliation replay is idempotent'
);

-- 53
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_reconciled'
      AND audit.entity_id =
          (SELECT over_booking_id FROM s11s7_ids)
  ),
  1::bigint,
  'exact replay does not append a second reconciliation audit event'
);

-- 54
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT addon_booking_id FROM s11s7_ids)
  )
  $$,
  'accepted pre-purchased additional images reconcile'
);

-- 55
SELECT is(
  (
    SELECT format(
      '%s,%s,%s',
      selected_image_count,
      included_image_count,
      excess_image_count
    )
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT addon_booking_id FROM s11s7_ids)
  ),
  '25,23,2',
  'three accepted additional_image units increase inclusion from 20 to 23'
);

-- 56
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT unrelated_booking_id FROM s11s7_ids)
  )
  $$,
  'accepted unrelated add-on booking reconciles'
);

-- 57
SELECT is(
  (
    SELECT format(
      '%s,%s,%s',
      selected_image_count,
      included_image_count,
      excess_image_count
    )
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT unrelated_booking_id FROM s11s7_ids)
  ),
  '22,20,2',
  'non-entitlement extra-frame add-on contributes zero images'
);

-- 58
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT custom_booking_id FROM s11s7_ids)
  )
  $$,
  'booking with custom quotation line reconciles'
);

-- 59
SELECT is(
  (
    SELECT format(
      '%s,%s,%s',
      selected_image_count,
      included_image_count,
      excess_image_count
    )
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT custom_booking_id FROM s11s7_ids)
  ),
  '22,20,2',
  'custom quotation line contributes zero image entitlement'
);

-- =====================================================================
-- Part 5 — No journey / quotation / payment mutation
-- =====================================================================

-- 60
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  (
    SELECT state_version
    FROM s11s7_over_baseline
  ),
  'reconciliation does not change journey-state version'
);

-- 61
SELECT is(
  (
    SELECT state.current_stage_id
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  (
    SELECT current_stage_id
    FROM s11s7_over_baseline
  ),
  'reconciliation does not change current journey stage'
);

-- 62
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  (
    SELECT transition_count::bigint
    FROM s11s7_over_baseline
  ),
  'reconciliation creates no booking-stage transition'
);

-- 63
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
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  (
    SELECT quoted_total_inr
    FROM s11s7_over_baseline
  ),
  'accepted quotation total remains unchanged'
);

-- 64
SELECT is(
  (
    SELECT requirement.required_advance_inr
    FROM public.booking_payment_requirements requirement
    WHERE requirement.booking_id =
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  (
    SELECT required_advance_inr
    FROM s11s7_over_baseline
  ),
  'advance requirement remains unchanged'
);

-- 65
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payments payment
    WHERE payment.booking_id =
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  (
    SELECT payment_count::bigint
    FROM s11s7_over_baseline
  ),
  'reconciliation creates no booking payment'
);

-- 66
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
      (SELECT over_booking_id FROM s11s7_ids)
  ),
  12::smallint,
  'reconciled booking remains exact Stage 12'
);

-- 67
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
          (SELECT over_booking_id FROM s11s7_ids)
      AND stage.stage_order = 13
      AND stage.stage_key =
          'editing_pending'
  ),
  0::bigint,
  'reconciliation creates no Stage 12 to 13 editing transition'
);

-- =====================================================================
-- Part 6 — Immutable evidence / audit contract
-- =====================================================================

-- 68
SELECT throws_ok(
  $$
  UPDATE public.booking_selection_reconciliations
  SET selected_image_count =
      selected_image_count
  WHERE booking_id =
    (SELECT below_booking_id FROM s11s7_ids)
  $$,
  'P0001',
  'booking selection reconciliation evidence is immutable',
  'reconciliation evidence cannot be updated'
);

-- 69
SELECT throws_ok(
  $$
  DELETE FROM public.booking_selection_reconciliations
  WHERE booking_id =
    (SELECT below_booking_id FROM s11s7_ids)
  $$,
  'P0001',
  'booking selection reconciliation evidence is immutable',
  'reconciliation evidence cannot be deleted'
);

-- 70
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_reconciled'
      AND audit.entity_type =
          'booking'
      AND audit.entity_id =
          (SELECT below_booking_id FROM s11s7_ids)
      AND NOT audit.is_sensitive
  ),
  1::bigint,
  'reconciliation writes one non-sensitive structural booking audit event'
);

-- 71
SELECT is(
  (
    SELECT format(
      '%s,%s,%s,%s',
      audit.new_values ->> 'selected_image_count',
      audit.new_values ->> 'included_image_count',
      audit.new_values ->> 'excess_image_count',
      audit.new_values ->> 'calculation_rule'
    )
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_reconciled'
      AND audit.entity_id =
          (SELECT below_booking_id FROM s11s7_ids)
  ),
  '18,20,0,accepted_quote_version_entitlement_v1',
  'audit captures only the canonical reconciliation calculation facts'
);

-- 72
SELECT ok(
  (
    SELECT NOT (
      COALESCE(audit.new_values, '{}'::jsonb)
        ?| ARRAY[
          'unit_price_inr',
          'additional_image_price',
          'excess_charge_inr',
          'adjusted_total_inr',
          'amount_due',
          'balance_due',
          'settlement_status'
        ]
      OR
      COALESCE(audit.metadata, '{}'::jsonb)
        ?| ARRAY[
          'unit_price_inr',
          'additional_image_price',
          'excess_charge_inr',
          'adjusted_total_inr',
          'amount_due',
          'balance_due',
          'settlement_status'
        ]
    )
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.selection_reconciled'
      AND audit.entity_id =
          (SELECT below_booking_id FROM s11s7_ids)
  ),
  'audit contains no invented price, balance or settlement fields'
);

-- =====================================================================
-- Part 7 — Runtime read containment
-- =====================================================================

-- The RLS assertions deliberately SET ROLE authenticated. Permit that
-- role to resolve fixture booking ids from this transaction-local temp
-- table only; this does not change any application-schema privilege.
GRANT SELECT
ON TABLE s11s7_ids
TO authenticated;

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000001'
);

SET LOCAL ROLE authenticated;

-- 73
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  1::bigint,
  'Founder with selection.read can read reconciliation evidence'
);

RESET ROLE;

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000002'
);

SET LOCAL ROLE authenticated;

-- 74
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_selection_reconciliations
    WHERE booking_id =
      (SELECT below_booking_id FROM s11s7_ids)
  ),
  0::bigint,
  'Photographer without selection.read cannot read reconciliation evidence'
);

RESET ROLE;

SELECT pg_temp.s11s7_set_actor(
  '8f000000-0000-0000-0000-000000000001'
);

-- =====================================================================
-- Part 8 — Replay conflict / fail-closed authority
-- =====================================================================

-- 75
SELECT lives_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT conflict_booking_id FROM s11s7_ids)
  )
  $$,
  'conflict fixture initially reconciles canonically'
);

ALTER TABLE public.booking_selection_reconciliations
DISABLE TRIGGER USER;

UPDATE public.booking_selection_reconciliations
SET
  selected_image_count = 23,
  excess_image_count = 3
WHERE booking_id =
  (SELECT conflict_booking_id FROM s11s7_ids);

ALTER TABLE public.booking_selection_reconciliations
ENABLE TRIGGER USER;

-- 76
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT conflict_booking_id FROM s11s7_ids)
  )
  $$,
  'P0001',
  'record_booking_selection_reconciliation: persisted reconciliation conflicts with canonical evidence',
  'persisted evidence inconsistent with immutable sources fails closed'
);

ALTER TABLE public.commercial_image_entitlements
DISABLE TRIGGER USER;

DELETE FROM public.commercial_image_entitlements entitlement
USING
  public.commercial_package_versions version,
  public.commercial_packages package
WHERE entitlement.organization_id =
      version.organization_id
  AND entitlement.package_version_id =
      version.id
  AND version.organization_id =
      package.organization_id
  AND version.package_id =
      package.id
  AND package.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND package.package_key =
      'maternity_gold'
  AND version.version_number = 1;

ALTER TABLE public.commercial_image_entitlements
ENABLE TRIGGER USER;

-- 77
SELECT throws_ok(
  $$
  SELECT public.record_booking_selection_reconciliation(
    (SELECT missing_entitlement_booking_id FROM s11s7_ids)
  )
  $$,
  'P0001',
  'record_booking_selection_reconciliation: exact package entitlement authority required',
  'missing exact accepted package-version entitlement fails closed'
);

-- 78
SELECT throws_ok(
  $$
  INSERT INTO public.booking_selection_reconciliations (
    organization_id,
    booking_id,
    source_quotation_id,
    source_selection_confirmation_id,
    selected_image_count,
    included_image_count,
    excess_image_count,
    calculation_rule,
    recorded_by
  )
  SELECT
    '8fffffff-ffff-ffff-ffff-fffffffffff0'::uuid,
    booking.id,
    booking.source_quotation_id,
    confirmation.id,
    confirmation.selected_image_count,
    20,
    GREATEST(
      confirmation.selected_image_count - 20,
      0
    ),
    'accepted_quote_version_entitlement_v1',
    '8f000000-0000-0000-0000-000000000101'::uuid
  FROM public.bookings booking
  JOIN public.booking_selection_confirmations confirmation
    ON confirmation.organization_id =
       booking.organization_id
   AND confirmation.booking_id =
       booking.id
  WHERE booking.id =
    (SELECT below_booking_id FROM s11s7_ids)
  $$,
  'P0001',
  'booking selection reconciliation requires canonical booking',
  'wrong-organization reconciliation provenance is rejected'
);

-- 79
SELECT ok(
  position(
    'commercial_addon_versions'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_selection_reconciliation(uuid)'::regprocedure
      )
    )
  ) = 0
  AND
  position(
    'amount_inr'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_selection_reconciliation(uuid)'::regprocedure
      )
    )
  ) = 0,
  'reconciliation RPC performs no commercial price-version or amount lookup'
);

-- 80
SELECT ok(
  position(
    'commercial_package_inclusions'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_selection_reconciliation(uuid)'::regprocedure
      )
    )
  ) = 0
  AND
  position(
    'inclusion.label'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_selection_reconciliation(uuid)'::regprocedure
      )
    )
  ) = 0,
  'reconciliation RPC performs no runtime package-label parsing'
);

-- 81
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  68::bigint,
  'Slice 7 behavior leaves canonical permission count unchanged'
);

-- 82
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  241::bigint,
  'Slice 7 behavior leaves role-permission mapping count unchanged'
);

SELECT * FROM finish();

ROLLBACK;
