-- =====================================================================
-- Sprint 11 Slice 10
-- Current Full-Balance Settlement Read Authority Foundation
-- =====================================================================
--
-- Frozen scope:
--   * deterministic current-state full-balance read authority only;
--   * zero excess resolves to accepted quotation total authority;
--   * positive excess resolves to exact Slice 9 adjusted obligation;
--   * collections are canonical non-reversed booking payments;
--   * coverage settlement uses collected >= target;
--   * no settlement persistence;
--   * no overpayment/refund classification;
--   * no payment/reversal mutation;
--   * no journey dependency or Stage 12 -> 13 transition;
--   * no new permissions.
--
-- Canonical target rule:
--   reconciled_accepted_or_adjusted_total_v1
--
-- Canonical collection rule:
--   non_reversed_booking_payments_v1
-- =====================================================================


-- =====================================================================
-- Section A — Deterministic current full-balance summary
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_booking_full_balance_summary(
  p_booking_id uuid
)
RETURNS TABLE (
  booking_id uuid,
  source_quotation_id uuid,
  source_payment_requirement_id uuid,
  source_reconciliation_id uuid,
  source_adjusted_obligation_id uuid,
  excess_image_count integer,
  currency text,
  settlement_target_inr bigint,
  target_rule text,
  valid_collected_inr bigint,
  collection_rule text,
  full_balance_outstanding_inr bigint,
  full_balance_satisfied boolean,
  payment_count bigint,
  reversal_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_requirement public.booking_payment_requirements;
  v_reconciliation public.booking_selection_reconciliations;
  v_obligation public.booking_adjusted_financial_obligations;
  v_quote public.quotations;

  v_actor uuid;

  v_requirement_count bigint;
  v_reconciliation_count bigint;
  v_obligation_count bigint;

  v_target bigint;
  v_adjusted_obligation_id uuid;

  v_valid_collected bigint;
  v_payment_count bigint;
  v_reversal_count bigint;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Booking authority.
  -- This RPC is deliberately current-stage independent.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Actor / finance-read / branch containment.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'finance.read',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: finance.read permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Immutable accepted-booking principal authority.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_requirement_count
  FROM public.booking_payment_requirements requirement
  WHERE requirement.organization_id =
        v_booking.organization_id
    AND requirement.booking_id =
        v_booking.id;

  IF v_requirement_count <> 1 THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: exactly one booking payment requirement required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT requirement.*
  INTO v_requirement
  FROM public.booking_payment_requirements requirement
  WHERE requirement.organization_id =
        v_booking.organization_id
    AND requirement.booking_id =
        v_booking.id;

  IF v_requirement.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id
     OR v_requirement.currency IS DISTINCT FROM 'INR'
     OR v_requirement.accepted_quotation_total_inr <= 0 THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: payment-requirement principal lineage is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT quotation.*
  INTO v_quote
  FROM public.quotations quotation
  WHERE quotation.organization_id =
        v_booking.organization_id
    AND quotation.id =
        v_booking.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <>
        'accepted'::public.quotation_status THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: accepted source quotation required'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact canonical Slice 7 reconciliation.
  -- Absence of Slice 9 evidence alone never selects the zero branch.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_reconciliation_count
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        v_booking.organization_id
    AND reconciliation.booking_id =
        v_booking.id;

  IF v_reconciliation_count <> 1 THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: exactly one selection reconciliation required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT reconciliation.*
  INTO v_reconciliation
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        v_booking.organization_id
    AND reconciliation.booking_id =
        v_booking.id;

  IF v_reconciliation.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id
     OR v_reconciliation.calculation_rule
       IS DISTINCT FROM
         'accepted_quote_version_entitlement_v1'
     OR v_reconciliation.excess_image_count < 0 THEN
    RAISE EXCEPTION
      'get_booking_full_balance_summary: selection-reconciliation lineage is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Determine exact adjusted-obligation cardinality before branching.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_obligation_count
  FROM public.booking_adjusted_financial_obligations obligation
  WHERE obligation.organization_id =
        v_booking.organization_id
    AND obligation.booking_id =
        v_booking.id;

  -- ---------------------------------------------------------------
  -- Zero-excess branch:
  -- target remains the immutable accepted quotation principal.
  -- An adjusted obligation must not coexist with zero excess.
  -- ---------------------------------------------------------------

  IF v_reconciliation.excess_image_count = 0 THEN
    IF v_obligation_count <> 0 THEN
      RAISE EXCEPTION
        'get_booking_full_balance_summary: zero-excess reconciliation conflicts with adjusted obligation'
        USING ERRCODE = 'P0001';
    END IF;

    v_target :=
      v_requirement.accepted_quotation_total_inr::bigint;

    v_adjusted_obligation_id := NULL;

  -- ---------------------------------------------------------------
  -- Positive-excess branch:
  -- exact Slice 9 adjusted obligation is mandatory.
  -- ---------------------------------------------------------------

  ELSIF v_reconciliation.excess_image_count > 0 THEN
    IF v_obligation_count <> 1 THEN
      RAISE EXCEPTION
        'get_booking_full_balance_summary: positive excess requires exactly one adjusted financial obligation'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT obligation.*
    INTO v_obligation
    FROM public.booking_adjusted_financial_obligations obligation
    WHERE obligation.organization_id =
          v_booking.organization_id
      AND obligation.booking_id =
          v_booking.id;

    IF v_obligation.source_payment_requirement_id
         IS DISTINCT FROM
           v_requirement.id
       OR v_obligation.source_quotation_id
         IS DISTINCT FROM
           v_booking.source_quotation_id
       OR v_obligation.source_reconciliation_id
         IS DISTINCT FROM
           v_reconciliation.id
       OR v_obligation.accepted_quotation_total_inr
         IS DISTINCT FROM
           v_requirement.accepted_quotation_total_inr
       OR v_obligation.excess_image_count
         IS DISTINCT FROM
           v_reconciliation.excess_image_count
       OR v_obligation.currency
         IS DISTINCT FROM
           'INR'
       OR v_obligation.calculation_rule
         IS DISTINCT FROM
           'accepted_quote_plus_excess_image_charge_v1'
       OR v_obligation.adjusted_total_inr <= 0 THEN
      RAISE EXCEPTION
        'get_booking_full_balance_summary: adjusted financial-obligation lineage is inconsistent'
        USING ERRCODE = 'P0001';
    END IF;

    v_target :=
      v_obligation.adjusted_total_inr;

    v_adjusted_obligation_id :=
      v_obligation.id;

  ELSE
    RAISE EXCEPTION
      'get_booking_full_balance_summary: invalid reconciled excess image count'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical current collection authority.
  --
  -- Each payment may have at most one canonical reversal.
  -- A reversed payment contributes zero to valid collections.
  -- ---------------------------------------------------------------

  SELECT
    COALESCE(
      sum(payment.amount_inr)
        FILTER (
          WHERE reversal.id IS NULL
        ),
      0
    )::bigint,
    count(payment.id)::bigint,
    count(reversal.id)::bigint
  INTO
    v_valid_collected,
    v_payment_count,
    v_reversal_count
  FROM public.booking_payments payment
  LEFT JOIN public.booking_payment_reversals reversal
    ON reversal.organization_id =
       payment.organization_id
   AND reversal.booking_id =
       payment.booking_id
   AND reversal.payment_id =
       payment.id
  WHERE payment.organization_id =
        v_booking.organization_id
    AND payment.booking_id =
        v_booking.id;

  -- ---------------------------------------------------------------
  -- Current-state coverage settlement.
  --
  -- Collections above target satisfy the balance, but Slice 10
  -- intentionally creates no overpayment/refund business semantics.
  -- ---------------------------------------------------------------

  RETURN QUERY
  SELECT
    v_booking.id,
    v_booking.source_quotation_id,
    v_requirement.id,
    v_reconciliation.id,
    v_adjusted_obligation_id,
    v_reconciliation.excess_image_count,
    'INR'::text,
    v_target,
    'reconciled_accepted_or_adjusted_total_v1'::text,
    v_valid_collected,
    'non_reversed_booking_payments_v1'::text,
    GREATEST(
      v_target - v_valid_collected,
      0::bigint
    ),
    (
      v_valid_collected >=
      v_target
    ),
    v_payment_count,
    v_reversal_count;
END;
$$;


COMMENT ON FUNCTION
  public.get_booking_full_balance_summary(uuid)
IS
  'Deterministic current full-balance read authority. Resolves the settlement target from exact reconciled accepted-or-adjusted commercial authority and current non-reversed booking collections. Persists no settlement state, creates no refund semantics, and performs no journey mutation.';


-- =====================================================================
-- Section B — RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.get_booking_full_balance_summary(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.get_booking_full_balance_summary(uuid)
TO authenticated;


-- =====================================================================
-- Section C — Migration assertions
-- =====================================================================

DO $s11s10_assertions$
DECLARE
  v_count integer;
  v_definition text;
  v_result text;
BEGIN
  -- Permission topology must remain unchanged.

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: role-permission count changed';
  END IF;

  -- Exact RPC must exist.

  IF to_regprocedure(
       'public.get_booking_full_balance_summary(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: full-balance RPC missing';
  END IF;

  SELECT
    pg_get_functiondef(procedure.oid),
    pg_get_function_result(procedure.oid)
  INTO
    v_definition,
    v_result
  FROM pg_catalog.pg_proc procedure
  WHERE procedure.oid =
    'public.get_booking_full_balance_summary(uuid)'::regprocedure;

  -- Exact result contract.

  IF v_result IS DISTINCT FROM
    'TABLE(booking_id uuid, source_quotation_id uuid, source_payment_requirement_id uuid, source_reconciliation_id uuid, source_adjusted_obligation_id uuid, excess_image_count integer, currency text, settlement_target_inr bigint, target_rule text, valid_collected_inr bigint, collection_rule text, full_balance_outstanding_inr bigint, full_balance_satisfied boolean, payment_count bigint, reversal_count bigint)'
  THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: RPC result contract changed: %',
      v_result;
  END IF;

  -- Security-definer + empty search path.

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.get_booking_full_balance_summary(uuid)'::regprocedure
      AND procedure.prosecdef
      AND procedure.proconfig @>
          ARRAY['search_path=""']::text[]
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: RPC security-definer/search-path contract missing';
  END IF;

  -- Authenticated only; PUBLIC inheritance is implicitly rejected
  -- because anon must not have EXECUTE.

  IF NOT has_function_privilege(
    'authenticated',
    'public.get_booking_full_balance_summary(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: authenticated RPC execute missing';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.get_booking_full_balance_summary(uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
          'service_role',
          'public.get_booking_full_balance_summary(uuid)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: forbidden RPC execute privilege exists';
  END IF;

  -- Exact frozen semantic markers.

  IF v_definition NOT LIKE
       '%reconciled_accepted_or_adjusted_total_v1%'
     OR v_definition NOT LIKE
       '%non_reversed_booking_payments_v1%'
     OR v_definition NOT LIKE
       '%finance.read%'
     OR v_definition NOT LIKE
       '%accepted_quote_version_entitlement_v1%'
     OR v_definition NOT LIKE
       '%accepted_quote_plus_excess_image_charge_v1%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: frozen semantic marker missing';
  END IF;

  -- The read authority must remain journey independent and
  -- side-effect free.

  IF v_definition ILIKE '%booking_journey_states%'
     OR v_definition ILIKE '%booking_stage_transitions%'
     OR v_definition ILIKE '%selection_pending%'
     OR v_definition ILIKE '%editing_pending%'
     OR v_definition ILIKE '%append_audit_event%'
     OR v_definition ILIKE '%INSERT INTO public.booking_payments%'
     OR v_definition ILIKE '%INSERT INTO public.booking_payment_reversals%'
     OR v_definition ILIKE '%UPDATE public.booking_payments%'
     OR v_definition ILIKE '%DELETE FROM public.booking_payments%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: forbidden mutation/journey dependency detected';
  END IF;

  -- Slice 10 must create no persistent settlement/full-balance relation.

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_class relation
  JOIN pg_catalog.pg_namespace namespace
    ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND (
      relation.relname ILIKE '%settlement%'
      OR relation.relname ILIKE '%full_balance%'
      OR relation.relname ILIKE '%refund_due%'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 10 assertion failed: forbidden settlement persistence surface exists';
  END IF;
END
$s11s10_assertions$;
