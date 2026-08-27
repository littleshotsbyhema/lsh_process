-- =====================================================================
-- Sprint 11 - Shoot Completion & Post-Session Handoff
-- Slice 11 - Controlled Stage 12 -> 13 / Editing Pending Advancement Gate
--
-- Frozen boundary:
--   * one controlled mark_booking_editing_pending(uuid) RPC;
--   * exact Stage 12 selection_pending -> Stage 13 editing_pending;
--   * strict Stage 13 replay;
--   * existing booking.stage.advance authorization only;
--   * no editing.write or finance.read requirement;
--   * exact immutable selection/reconciliation lineage;
--   * exact Slice 10 full-balance semantics evaluated internally;
--   * booking-row synchronization root;
--   * later payment reversal never rewinds historical advancement;
--   * no editing-job persistence;
--   * no settlement persistence;
--   * no new permission or role grant;
--   * no Stage 13 -> 14 implementation;
--   * no application UI.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $s11s11_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_editing_pending(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 precondition failed: mark_booking_editing_pending already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.booking_payment_requirements') IS NULL
     OR to_regclass('public.booking_selection_confirmations') IS NULL
     OR to_regclass('public.booking_selection_reconciliations') IS NULL
     OR to_regclass('public.booking_adjusted_financial_obligations') IS NULL
     OR to_regclass('public.booking_payments') IS NULL
     OR to_regclass('public.booking_payment_reversals') IS NULL
     OR to_regclass('public.quotations') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.roles') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 precondition failed: required canonical relation missing';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_branch_scope(uuid,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.mark_booking_selection_pending(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.get_booking_full_balance_summary(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 precondition failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key =
        'booking.stage.advance'
    AND role.key IN (
      'client_coordinator',
      'founder',
      'studio_manager'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 precondition failed: canonical booking.stage.advance topology unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.is_active
    AND (
      (
        stage.stage_order = 12
        AND stage.stage_key =
            'selection_pending'
      )
      OR
      (
        stage.stage_order = 13
        AND stage.stage_key =
            'editing_pending'
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 precondition failed: canonical Stage 12 / Stage 13 catalogue unavailable';
  END IF;
END
$s11s11_preconditions$;


-- =====================================================================
-- Section B - Controlled Stage 12 -> 13 operation
-- =====================================================================

CREATE FUNCTION public.mark_booking_editing_pending(
  p_booking_id uuid
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_confirmation public.booking_selection_confirmations;
  v_reconciliation public.booking_selection_reconciliations;
  v_requirement public.booking_payment_requirements;
  v_obligation public.booking_adjusted_financial_obligations;
  v_quote public.quotations;

  v_actor uuid;

  v_state_count integer := 0;
  v_confirmation_count bigint := 0;
  v_reconciliation_count bigint := 0;
  v_requirement_count bigint := 0;
  v_obligation_count bigint := 0;

  v_selection_pending_transition_count integer := 0;
  v_editing_pending_transition_count integer := 0;

  v_target bigint := 0;
  v_valid_collected bigint := 0;

  v_editing_pending_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer := 0;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: booking synchronization root.
  --
  -- Selection, obligation, payment and reversal mutations already
  -- serialize through this same canonical booking row.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active membership + journey-transition authority.
  --
  -- Editing-domain and finance-read permissions deliberately do not apply.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exact current canonical journey state.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id
  FOR UPDATE;

  SELECT stage.*
  INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.id =
        v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact operation-stage containment.
  --
  -- First execution: exact Stage 12.
  -- Replay: exact Stage 13 only.
  -- ---------------------------------------------------------------

  IF NOT (
    (
      v_stage.stage_order = 12
      AND v_stage.stage_key =
          'selection_pending'
    )
    OR
    (
      v_stage.stage_order = 13
      AND v_stage.stage_key =
          'editing_pending'
    )
  ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking must be exactly Selection Pending or Editing Pending replay'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Strict Stage 13 replay.
  --
  -- Replay proves only the exact historical transition. It does not
  -- re-evaluate current payments or current full-balance satisfaction.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order = 13
     AND v_stage.stage_key =
         'editing_pending' THEN

    SELECT count(*)
    INTO v_editing_pending_transition_count
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
    WHERE transition_row.organization_id =
          v_booking.organization_id
      AND transition_row.booking_id =
          v_booking.id
      AND transition_row.transition_key =
          'editing_pending'
      AND source_stage.stage_order = 12
      AND source_stage.stage_key =
          'selection_pending'
      AND destination_stage.stage_order = 13
      AND destination_stage.stage_key =
          'editing_pending';

    IF v_editing_pending_transition_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_editing_pending: Editing Pending replay history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  -- ---------------------------------------------------------------
  -- First execution must be exact Stage 12.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order <> 12
     OR v_stage.stage_key <>
          'selection_pending' THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking must be exactly Selection Pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact Stage 11 -> 12 lineage.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_selection_pending_transition_count
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
  WHERE transition_row.organization_id =
        v_booking.organization_id
    AND transition_row.booking_id =
        v_booking.id
    AND transition_row.transition_key =
        'selection_pending'
    AND source_stage.stage_order = 11
    AND source_stage.stage_key =
        'shoot_completed'
    AND destination_stage.stage_order = 12
    AND destination_stage.stage_key =
        'selection_pending';

  IF v_selection_pending_transition_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: canonical Selection Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- First execution may not coexist with pre-existing Stage 12 -> 13
  -- history while current state still reports Stage 12.

  SELECT count(*)
  INTO v_editing_pending_transition_count
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
  WHERE transition_row.organization_id =
        v_booking.organization_id
    AND transition_row.booking_id =
        v_booking.id
    AND transition_row.transition_key =
        'editing_pending'
    AND source_stage.stage_order = 12
    AND source_stage.stage_key =
        'selection_pending'
    AND destination_stage.stage_order = 13
    AND destination_stage.stage_key =
        'editing_pending';

  IF v_editing_pending_transition_count <> 0 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: unexpected pre-existing Editing Pending transition history'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact immutable selection-confirmation evidence.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_confirmation_count
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        v_booking.organization_id
    AND confirmation.booking_id =
        v_booking.id;

  IF v_confirmation_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: exactly one selection confirmation required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT confirmation.*
  INTO v_confirmation
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        v_booking.organization_id
    AND confirmation.booking_id =
        v_booking.id;

  -- ---------------------------------------------------------------
  -- Exact immutable selection-reconciliation evidence.
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
      'mark_booking_editing_pending: exactly one selection reconciliation required'
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
     OR v_reconciliation.source_selection_confirmation_id
       IS DISTINCT FROM
         v_confirmation.id
     OR v_reconciliation.selected_image_count
       IS DISTINCT FROM
         v_confirmation.selected_image_count
     OR v_reconciliation.calculation_rule
       IS DISTINCT FROM
         'accepted_quote_version_entitlement_v1'
     OR v_reconciliation.excess_image_count < 0 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: selection-reconciliation lineage is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact immutable accepted-booking principal authority.
  -- This deliberately mirrors Slice 10 settlement semantics.
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
      'mark_booking_editing_pending: exactly one booking payment requirement required'
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
     OR v_requirement.currency
       IS DISTINCT FROM
         'INR'
     OR v_requirement.accepted_quotation_total_inr <= 0 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: payment-requirement principal lineage is inconsistent'
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
      'mark_booking_editing_pending: accepted source quotation required'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Determine exact adjusted-obligation cardinality.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_obligation_count
  FROM public.booking_adjusted_financial_obligations obligation
  WHERE obligation.organization_id =
        v_booking.organization_id
    AND obligation.booking_id =
        v_booking.id;

  -- ---------------------------------------------------------------
  -- Zero-excess branch.
  -- ---------------------------------------------------------------

  IF v_reconciliation.excess_image_count = 0 THEN
    IF v_obligation_count <> 0 THEN
      RAISE EXCEPTION
        'mark_booking_editing_pending: zero-excess reconciliation conflicts with adjusted obligation'
        USING ERRCODE = 'P0001';
    END IF;

    v_target :=
      v_requirement.accepted_quotation_total_inr::bigint;

  -- ---------------------------------------------------------------
  -- Positive-excess branch.
  -- ---------------------------------------------------------------

  ELSIF v_reconciliation.excess_image_count > 0 THEN
    IF v_obligation_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_editing_pending: positive excess requires exactly one adjusted financial obligation'
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
        'mark_booking_editing_pending: adjusted financial-obligation lineage is inconsistent'
        USING ERRCODE = 'P0001';
    END IF;

    v_target :=
      v_obligation.adjusted_total_inr;

  ELSE
    RAISE EXCEPTION
      'mark_booking_editing_pending: invalid reconciled excess image count'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical current collection authority.
  --
  -- Rule: non_reversed_booking_payments_v1
  -- ---------------------------------------------------------------

  SELECT COALESCE(
           sum(payment.amount_inr)
             FILTER (
               WHERE reversal.id IS NULL
             ),
           0
         )::bigint
  INTO v_valid_collected
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

  -- Coverage settlement:
  -- reconciled_accepted_or_adjusted_total_v1
  --
  -- Overcollection satisfies the gate but creates no refund semantics.

  IF v_valid_collected < v_target THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: full balance has not been satisfied'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve exact Stage 13 destination.
  -- ---------------------------------------------------------------

  SELECT stage.id
  INTO v_editing_pending_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.stage_order = 13
    AND stage.stage_key =
        'editing_pending'
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: canonical Editing Pending stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Append exact canonical transition.
  -- ---------------------------------------------------------------

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
    v_booking.organization_id,
    v_booking.id,
    v_state.current_stage_id,
    v_editing_pending_stage_id,
    'editing_pending',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Optimistic exact-state/version advancement.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_editing_pending_stage_id,
    stage_entered_at =
      v_transitioned_at,
    version =
      state.version + 1,
    updated_at =
      v_transitioned_at,
    updated_by =
      v_actor
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id
    AND state.current_stage_id =
        v_state.current_stage_id
    AND state.version =
        v_state.version;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  IF v_updated_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- One structural non-sensitive audit event.
  --
  -- Financial amounts and raw payment data are deliberately omitted.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_pending',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage',
        'selection_pending',
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'editing_pending',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'selection_confirmation_id',
        v_confirmation.id,
      'selection_reconciliation_id',
        v_reconciliation.id,
      'transition_key',
        'editing_pending',
      'prior_journey_version',
        v_state.version,
      'resulting_journey_version',
        v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$$;


COMMENT ON FUNCTION public.mark_booking_editing_pending(uuid) IS
  'Advance one authorized booking from canonical Stage 12 Selection Pending to Stage 13 Editing Pending only when immutable selection evidence exists and current non-reversed collections satisfy the exact reconciled accepted-or-adjusted settlement target. Uses booking.stage.advance, not editing.write or finance.read. Replay at exact Stage 13 does not re-evaluate later financial state.';


-- =====================================================================
-- Section C - RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.mark_booking_editing_pending(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.mark_booking_editing_pending(uuid)
TO authenticated;


-- =====================================================================
-- Section D - Migration assertions
-- =====================================================================

DO $s11s11_assertions$
DECLARE
  v_count integer;
  v_definition text;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_editing_pending(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: Stage 12 -> 13 RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_proc procedure
  JOIN pg_catalog.pg_namespace namespace
    ON namespace.oid =
       procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname =
        'mark_booking_editing_pending'
    AND pg_get_function_identity_arguments(
          procedure.oid
        ) = 'p_booking_id uuid'
    AND pg_get_function_result(
          procedure.oid
        ) = 'bookings'
    AND procedure.prosecdef
    AND procedure.proconfig =
        ARRAY['search_path=""']::text[];

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.mark_booking_editing_pending(uuid)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: authenticated EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.mark_booking_editing_pending(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: anon EXECUTE must be denied';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.mark_booking_editing_pending(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: service_role EXECUTE must remain unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: role-permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key =
        'booking.stage.advance'
    AND role.key IN (
      'client_coordinator',
      'founder',
      'studio_manager'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: booking.stage.advance topology changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key =
        'booking.stage.advance'
    AND role.key =
        'editor';

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: Editor unexpectedly has booking.stage.advance';
  END IF;

  SELECT pg_get_functiondef(
           'public.mark_booking_editing_pending(uuid)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE '%booking.stage.advance%'
     OR v_definition ILIKE '%editing.write%'
     OR v_definition ILIKE '%finance.read%'
     OR v_definition ILIKE '%get_booking_full_balance_summary%'
     OR v_definition NOT ILIKE '%booking_selection_confirmations%'
     OR v_definition NOT ILIKE '%booking_selection_reconciliations%'
     OR v_definition NOT ILIKE '%booking_payment_requirements%'
     OR v_definition NOT ILIKE '%booking_adjusted_financial_obligations%'
     OR v_definition NOT ILIKE '%booking_payments%'
     OR v_definition NOT ILIKE '%booking_payment_reversals%'
     OR v_definition NOT ILIKE '%selection_pending%'
     OR v_definition NOT ILIKE '%editing_pending%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 11 validation failed: RPC containment markers invalid';
  END IF;
END
$s11s11_assertions$;
