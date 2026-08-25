-- =====================================================================
-- Sprint 11 — Shoot Completion & Post-Session Handoff
-- Slice 9 — Booking Adjusted Financial Obligation Authority Foundation
--
-- Frozen rule:
--
--   accepted_quote_plus_excess_image_charge_v1
--
-- Immutable source authorities:
--
--   principal
--     booking_payment_requirements.accepted_quotation_total_inr
--
--   quantity
--     booking_selection_reconciliations.excess_image_count
--
--   unit price
--     booking_additional_image_pricing_bases.applied_unit_price_inr
--
-- Calculation:
--
--   excess_image_charge_inr =
--     excess_image_count * applied_unit_price_inr
--
--   adjusted_total_inr =
--     accepted_quotation_total_inr + excess_image_charge_inr
--
-- Boundary:
--   * positive excess only;
--   * one immutable obligation per organization + booking;
--   * exact tenant-safe source provenance;
--   * finance.write controlled recording;
--   * finance.read authenticated read containment;
--   * bigint charge / adjusted-total arithmetic;
--   * no caller-supplied money;
--   * no quotation mutation;
--   * no payment-requirement mutation;
--   * no booking-payment or reversal mutation;
--   * no settlement semantics;
--   * no amount-due / balance-due authority;
--   * no Stage 12 -> 13 transition;
--   * no application UI.
-- =====================================================================


-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11s9_preconditions$
DECLARE
  v_count integer;
  v_roles text[];
BEGIN
  IF to_regclass(
       'public.booking_adjusted_financial_obligations'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: booking_adjusted_financial_obligations already exists';
  END IF;

  IF to_regprocedure(
       'public.lsh_booking_adjusted_financial_obligation_guard()'
     ) IS NOT NULL
     OR to_regprocedure(
          'public.record_booking_adjusted_financial_obligation(uuid)'
        ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: Slice 9 function already exists';
  END IF;

  IF to_regclass(
       'public.booking_payment_requirements_org_booking_id_uidx'
     ) IS NOT NULL
     OR to_regclass(
          'public.booking_additional_image_pricing_bases_org_booking_id_uidx'
        ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: Slice 9 provenance support index already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.quotations') IS NULL
     OR to_regclass(
          'public.booking_payment_requirements'
        ) IS NULL
     OR to_regclass(
          'public.booking_selection_reconciliations'
        ) IS NULL
     OR to_regclass(
          'public.booking_additional_image_pricing_bases'
        ) IS NULL
     OR to_regclass(
          'public.booking_journey_states'
        ) IS NULL
     OR to_regclass(
          'public.booking_journey_stages'
        ) IS NULL
     OR to_regclass(
          'public.organization_members'
        ) IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.roles') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: required canonical relation missing';
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
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key = 'finance.write'
    AND permission.domain = 'finance'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: canonical finance.write authority unavailable';
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key = 'finance.write';

  IF v_roles IS DISTINCT FROM
     ARRAY[
       'accounts',
       'founder',
       'studio_manager'
     ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: finance.write role topology changed';
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key = 'finance.read';

  IF v_roles IS DISTINCT FROM
     ARRAY[
       'accounts',
       'founder',
       'sales',
       'studio_manager'
     ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: finance.read role topology changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.stage_order = 12
    AND stage.stage_key = 'selection_pending'
    AND stage.is_active;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: exact active Stage 12 selection_pending authority unavailable';
  END IF;

  IF to_regclass(
       'public.booking_selection_reconciliations_org_booking_id_uidx'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 precondition failed: Slice 7 reconciliation provenance identity missing';
  END IF;
END
$s11s9_preconditions$;


-- =====================================================================
-- Section B — Tenant-safe provenance identities
-- =====================================================================

CREATE UNIQUE INDEX
booking_payment_requirements_org_booking_id_uidx
ON public.booking_payment_requirements (
  organization_id,
  booking_id,
  id
);

CREATE UNIQUE INDEX
booking_additional_image_pricing_bases_org_booking_id_uidx
ON public.booking_additional_image_pricing_bases (
  organization_id,
  booking_id,
  id
);


-- =====================================================================
-- Section C — Immutable adjusted financial-obligation authority
-- =====================================================================

CREATE TABLE public.booking_adjusted_financial_obligations (
  id                              uuid
                                  PRIMARY KEY
                                  DEFAULT gen_random_uuid(),

  organization_id                 uuid NOT NULL,
  booking_id                      uuid NOT NULL,

  source_payment_requirement_id   uuid NOT NULL,
  source_quotation_id             uuid NOT NULL,
  source_reconciliation_id        uuid NOT NULL,
  source_pricing_basis_id         uuid NOT NULL,

  accepted_quotation_total_inr    integer NOT NULL,
  excess_image_count              integer NOT NULL,
  applied_unit_price_inr          integer NOT NULL,

  excess_image_charge_inr         bigint NOT NULL,
  adjusted_total_inr              bigint NOT NULL,

  currency                        text NOT NULL,
  calculation_rule                text NOT NULL,

  recorded_at                     timestamptz
                                  NOT NULL
                                  DEFAULT now(),
  recorded_by                     uuid NOT NULL,

  CONSTRAINT booking_adjusted_financial_obligations_principal_chk
    CHECK (
      accepted_quotation_total_inr > 0
    ),

  CONSTRAINT booking_adjusted_financial_obligations_excess_chk
    CHECK (
      excess_image_count > 0
    ),

  CONSTRAINT booking_adjusted_financial_obligations_unit_price_chk
    CHECK (
      applied_unit_price_inr > 0
    ),

  CONSTRAINT booking_adjusted_financial_obligations_charge_chk
    CHECK (
      excess_image_charge_inr > 0
    ),

  CONSTRAINT booking_adjusted_financial_obligations_total_chk
    CHECK (
      adjusted_total_inr >
        accepted_quotation_total_inr::bigint
    ),

  CONSTRAINT booking_adjusted_financial_obligations_charge_formula_chk
    CHECK (
      excess_image_charge_inr =
        excess_image_count::bigint *
        applied_unit_price_inr::bigint
    ),

  CONSTRAINT booking_adjusted_financial_obligations_total_formula_chk
    CHECK (
      adjusted_total_inr =
        accepted_quotation_total_inr::bigint +
        excess_image_charge_inr
    ),

  CONSTRAINT booking_adjusted_financial_obligations_currency_chk
    CHECK (
      currency = 'INR'
    ),

  CONSTRAINT booking_adjusted_financial_obligations_rule_chk
    CHECK (
      calculation_rule =
        'accepted_quote_plus_excess_image_charge_v1'
    ),

  CONSTRAINT booking_adjusted_financial_obligations_booking_fkey
    FOREIGN KEY (
      organization_id,
      booking_id
    )
    REFERENCES public.bookings (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_adjusted_financial_obligations_payment_req_fkey
    FOREIGN KEY (
      organization_id,
      booking_id,
      source_payment_requirement_id
    )
    REFERENCES public.booking_payment_requirements (
      organization_id,
      booking_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_adjusted_financial_obligations_quote_fkey
    FOREIGN KEY (
      organization_id,
      source_quotation_id
    )
    REFERENCES public.quotations (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_adjusted_financial_obligations_reconciliation_fkey
    FOREIGN KEY (
      organization_id,
      booking_id,
      source_reconciliation_id
    )
    REFERENCES public.booking_selection_reconciliations (
      organization_id,
      booking_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_adjusted_financial_obligations_pricing_basis_fkey
    FOREIGN KEY (
      organization_id,
      booking_id,
      source_pricing_basis_id
    )
    REFERENCES public.booking_additional_image_pricing_bases (
      organization_id,
      booking_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_adjusted_financial_obligations_recorded_by_fkey
    FOREIGN KEY (
      recorded_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_adjusted_financial_obligations_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    )
);

CREATE INDEX booking_adjusted_financial_obligations_org_recorded_idx
ON public.booking_adjusted_financial_obligations (
  organization_id,
  recorded_at DESC
);


-- =====================================================================
-- Section D — Immutable canonical-value guard
-- =====================================================================

CREATE FUNCTION
public.lsh_booking_adjusted_financial_obligation_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_quote public.quotations;

  v_requirement public.booking_payment_requirements;
  v_reconciliation public.booking_selection_reconciliations;
  v_pricing_basis public.booking_additional_image_pricing_bases;

  v_stage_count bigint := 0;

  v_expected_charge bigint;
  v_expected_total bigint;

  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking adjusted financial-obligation evidence is immutable';
  END IF;

  IF NEW.organization_id IS NULL
     OR NEW.booking_id IS NULL
     OR NEW.source_payment_requirement_id IS NULL
     OR NEW.source_quotation_id IS NULL
     OR NEW.source_reconciliation_id IS NULL
     OR NEW.source_pricing_basis_id IS NULL
     OR NEW.accepted_quotation_total_inr IS NULL
     OR NEW.excess_image_count IS NULL
     OR NEW.applied_unit_price_inr IS NULL
     OR NEW.excess_image_charge_inr IS NULL
     OR NEW.adjusted_total_inr IS NULL
     OR NEW.currency IS NULL
     OR NEW.calculation_rule IS NULL
     OR NEW.recorded_at IS NULL
     OR NEW.recorded_by IS NULL THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires complete immutable attribution';
  END IF;

  IF NEW.calculation_rule <>
     'accepted_quote_plus_excess_image_charge_v1' THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation calculation rule is invalid';
  END IF;

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.organization_id =
        NEW.organization_id
    AND booking.id =
        NEW.booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires canonical booking';
  END IF;

  IF NEW.source_quotation_id IS DISTINCT FROM
     v_booking.source_quotation_id THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation source quotation must match booking';
  END IF;

  SELECT count(*)
  INTO v_stage_count
  FROM public.booking_journey_states state
  JOIN public.booking_journey_stages stage
    ON stage.organization_id =
       state.organization_id
   AND stage.id =
       state.current_stage_id
  WHERE state.organization_id =
        NEW.organization_id
    AND state.booking_id =
        NEW.booking_id
    AND stage.stage_order = 12
    AND stage.stage_key = 'selection_pending'
    AND stage.is_active;

  IF v_stage_count <> 1 THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires exact active Stage 12 selection_pending state';
  END IF;

  SELECT quotation.*
  INTO v_quote
  FROM public.quotations quotation
  WHERE quotation.organization_id =
        NEW.organization_id
    AND quotation.id =
        NEW.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <>
        'accepted'::public.quotation_status THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires accepted source quotation';
  END IF;

  SELECT requirement.*
  INTO v_requirement
  FROM public.booking_payment_requirements requirement
  WHERE requirement.organization_id =
        NEW.organization_id
    AND requirement.booking_id =
        NEW.booking_id
    AND requirement.id =
        NEW.source_payment_requirement_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires exact booking payment requirement';
  END IF;

  IF v_requirement.source_quotation_id
       IS DISTINCT FROM NEW.source_quotation_id
     OR v_requirement.currency
       IS DISTINCT FROM NEW.currency
     OR v_requirement.accepted_quotation_total_inr
       IS DISTINCT FROM
          NEW.accepted_quotation_total_inr THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation principal lineage is inconsistent';
  END IF;

  SELECT reconciliation.*
  INTO v_reconciliation
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        NEW.organization_id
    AND reconciliation.booking_id =
        NEW.booking_id
    AND reconciliation.id =
        NEW.source_reconciliation_id;

  IF NOT FOUND
     OR v_reconciliation.excess_image_count <= 0 THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires positive canonical excess reconciliation';
  END IF;

  IF v_reconciliation.source_quotation_id
       IS DISTINCT FROM NEW.source_quotation_id
     OR v_reconciliation.excess_image_count
       IS DISTINCT FROM NEW.excess_image_count THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation reconciliation lineage is inconsistent';
  END IF;

  SELECT pricing_basis.*
  INTO v_pricing_basis
  FROM public.booking_additional_image_pricing_bases pricing_basis
  WHERE pricing_basis.organization_id =
        NEW.organization_id
    AND pricing_basis.booking_id =
        NEW.booking_id
    AND pricing_basis.id =
        NEW.source_pricing_basis_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires exact pricing basis';
  END IF;

  IF v_pricing_basis.source_reconciliation_id
       IS DISTINCT FROM NEW.source_reconciliation_id
     OR v_pricing_basis.source_quotation_id
       IS DISTINCT FROM NEW.source_quotation_id
     OR v_pricing_basis.currency
       IS DISTINCT FROM NEW.currency
     OR v_pricing_basis.applied_unit_price_inr
       IS DISTINCT FROM NEW.applied_unit_price_inr THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation pricing-basis lineage is inconsistent';
  END IF;

  IF NEW.currency <> 'INR'
     OR v_requirement.currency <> 'INR'
     OR v_pricing_basis.currency <> 'INR' THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation requires INR authorities';
  END IF;

  v_expected_charge :=
    NEW.excess_image_count::bigint *
    NEW.applied_unit_price_inr::bigint;

  v_expected_total :=
    NEW.accepted_quotation_total_inr::bigint +
    v_expected_charge;

  IF NEW.excess_image_charge_inr
       IS DISTINCT FROM v_expected_charge
     OR NEW.adjusted_total_inr
       IS DISTINCT FROM v_expected_total THEN
    RAISE EXCEPTION
      'booking adjusted financial obligation calculation is inconsistent';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.recorded_by IS DISTINCT FROM
          v_actor THEN
      RAISE EXCEPTION
        'booking adjusted financial obligation recorded_by must be current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_adjusted_financial_obligations_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_adjusted_financial_obligations
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_adjusted_financial_obligation_guard();

REVOKE ALL
ON FUNCTION
  public.lsh_booking_adjusted_financial_obligation_guard()
FROM PUBLIC, anon, authenticated, service_role;


-- =====================================================================
-- Section E — Forced RLS / finance.read containment
-- =====================================================================

ALTER TABLE public.booking_adjusted_financial_obligations
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_adjusted_financial_obligations
FORCE ROW LEVEL SECURITY;

REVOKE ALL
ON TABLE public.booking_adjusted_financial_obligations
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_adjusted_financial_obligations
TO authenticated;

CREATE POLICY
booking_adjusted_financial_obligations_authenticated_select
ON public.booking_adjusted_financial_obligations
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_adjusted_financial_obligations.organization_id
      AND booking.id =
          booking_adjusted_financial_obligations.booking_id
      AND public.current_organization_member(
            booking.organization_id
          ) IS NOT NULL
      AND public.has_permission(
            booking.organization_id,
            'finance.read',
            booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(
             booking.organization_id,
             booking.branch_id
           )
      )
  )
);


-- =====================================================================
-- Section F — Controlled deterministic recording RPC
-- =====================================================================

CREATE FUNCTION
public.record_booking_adjusted_financial_obligation(
  p_booking_id uuid
)
RETURNS public.booking_adjusted_financial_obligations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_actor uuid;

  v_state_count bigint := 0;
  v_requirement_count bigint := 0;
  v_reconciliation_count bigint := 0;
  v_pricing_basis_count bigint := 0;

  v_requirement public.booking_payment_requirements;
  v_reconciliation public.booking_selection_reconciliations;
  v_pricing_basis public.booking_additional_image_pricing_bases;
  v_quote public.quotations;

  v_charge bigint;
  v_adjusted_total bigint;

  v_existing public.booking_adjusted_financial_obligations;
  v_result public.booking_adjusted_financial_obligations;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Booking is the synchronization root.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'finance.write',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: finance.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact current Stage 12 authority.
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
      'record_booking_adjusted_financial_obligation: booking must have exactly one current journey state'
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
        v_state.current_stage_id;

  IF NOT FOUND
     OR NOT v_stage.is_active
     OR v_stage.stage_order <> 12
     OR v_stage.stage_key <>
        'selection_pending' THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: booking must be at active Stage 12 selection_pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact immutable accepted-booking principal authority.
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
      'record_booking_adjusted_financial_obligation: exactly one booking payment requirement required'
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
     OR v_requirement.currency <> 'INR'
     OR v_requirement.accepted_quotation_total_inr <= 0 THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: payment-requirement principal lineage is inconsistent'
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
      'record_booking_adjusted_financial_obligation: accepted source quotation required'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact positive Slice 7 quantity authority.
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
      'record_booking_adjusted_financial_obligation: exactly one selection reconciliation required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT reconciliation.*
  INTO v_reconciliation
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        v_booking.organization_id
    AND reconciliation.booking_id =
        v_booking.id;

  IF v_reconciliation.excess_image_count <= 0 THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: positive reconciled excess is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_reconciliation.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: reconciliation quotation lineage is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact Slice 8 applied-price authority.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_pricing_basis_count
  FROM public.booking_additional_image_pricing_bases pricing_basis
  WHERE pricing_basis.organization_id =
        v_booking.organization_id
    AND pricing_basis.booking_id =
        v_booking.id;

  IF v_pricing_basis_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: exactly one additional-image pricing basis required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT pricing_basis.*
  INTO v_pricing_basis
  FROM public.booking_additional_image_pricing_bases pricing_basis
  WHERE pricing_basis.organization_id =
        v_booking.organization_id
    AND pricing_basis.booking_id =
        v_booking.id;

  IF v_pricing_basis.source_reconciliation_id
       IS DISTINCT FROM
         v_reconciliation.id
     OR v_pricing_basis.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id
     OR v_pricing_basis.currency <> 'INR'
     OR v_pricing_basis.applied_unit_price_inr <= 0 THEN
    RAISE EXCEPTION
      'record_booking_adjusted_financial_obligation: pricing-basis lineage is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Deterministic bigint financial calculation.
  -- ---------------------------------------------------------------

  v_charge :=
    v_reconciliation.excess_image_count::bigint *
    v_pricing_basis.applied_unit_price_inr::bigint;

  v_adjusted_total :=
    v_requirement.accepted_quotation_total_inr::bigint +
    v_charge;

  -- ---------------------------------------------------------------
  -- Immutable exact replay.
  -- ---------------------------------------------------------------

  SELECT obligation.*
  INTO v_existing
  FROM public.booking_adjusted_financial_obligations obligation
  WHERE obligation.organization_id =
        v_booking.organization_id
    AND obligation.booking_id =
        v_booking.id;

  IF FOUND THEN
    IF v_existing.source_payment_requirement_id
         IS DISTINCT FROM v_requirement.id
       OR v_existing.source_quotation_id
         IS DISTINCT FROM v_booking.source_quotation_id
       OR v_existing.source_reconciliation_id
         IS DISTINCT FROM v_reconciliation.id
       OR v_existing.source_pricing_basis_id
         IS DISTINCT FROM v_pricing_basis.id
       OR v_existing.accepted_quotation_total_inr
         IS DISTINCT FROM
            v_requirement.accepted_quotation_total_inr
       OR v_existing.excess_image_count
         IS DISTINCT FROM
            v_reconciliation.excess_image_count
       OR v_existing.applied_unit_price_inr
         IS DISTINCT FROM
            v_pricing_basis.applied_unit_price_inr
       OR v_existing.excess_image_charge_inr
         IS DISTINCT FROM v_charge
       OR v_existing.adjusted_total_inr
         IS DISTINCT FROM v_adjusted_total
       OR v_existing.currency IS DISTINCT FROM 'INR'
       OR v_existing.calculation_rule
         IS DISTINCT FROM
            'accepted_quote_plus_excess_image_charge_v1' THEN
      RAISE EXCEPTION
        'record_booking_adjusted_financial_obligation: conflicting immutable financial-obligation evidence'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing;
  END IF;

  INSERT INTO public.booking_adjusted_financial_obligations (
    organization_id,
    booking_id,
    source_payment_requirement_id,
    source_quotation_id,
    source_reconciliation_id,
    source_pricing_basis_id,
    accepted_quotation_total_inr,
    excess_image_count,
    applied_unit_price_inr,
    excess_image_charge_inr,
    adjusted_total_inr,
    currency,
    calculation_rule,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_requirement.id,
    v_booking.source_quotation_id,
    v_reconciliation.id,
    v_pricing_basis.id,
    v_requirement.accepted_quotation_total_inr,
    v_reconciliation.excess_image_count,
    v_pricing_basis.applied_unit_price_inr,
    v_charge,
    v_adjusted_total,
    'INR',
    'accepted_quote_plus_excess_image_charge_v1',
    v_actor
  )
  RETURNING *
  INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.adjusted_financial_obligation_recorded',
    'booking_adjusted_financial_obligation',
    v_result.id,
    false,
    NULL,
    jsonb_build_object(
      'accepted_quotation_total_inr',
        v_result.accepted_quotation_total_inr,
      'excess_image_count',
        v_result.excess_image_count,
      'applied_unit_price_inr',
        v_result.applied_unit_price_inr,
      'excess_image_charge_inr',
        v_result.excess_image_charge_inr,
      'adjusted_total_inr',
        v_result.adjusted_total_inr,
      'currency',
        v_result.currency,
      'calculation_rule',
        v_result.calculation_rule
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'source_payment_requirement_id',
        v_result.source_payment_requirement_id,
      'source_quotation_id',
        v_result.source_quotation_id,
      'source_reconciliation_id',
        v_result.source_reconciliation_id,
      'source_pricing_basis_id',
        v_result.source_pricing_basis_id
    ),
    'finance',
    NULL
  );

  RETURN v_result;
END;
$$;

REVOKE ALL
ON FUNCTION
  public.record_booking_adjusted_financial_obligation(uuid)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE
ON FUNCTION
  public.record_booking_adjusted_financial_obligation(uuid)
TO authenticated;


-- =====================================================================
-- Section G — Migration assertions
-- =====================================================================

DO $s11s9_assertions$
DECLARE
  v_count integer;
  v_columns text[];
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: role-permission count changed';
  END IF;

  SELECT array_agg(
           column_name
           ORDER BY ordinal_position
         )
  INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'booking_adjusted_financial_obligations';

  IF v_columns IS DISTINCT FROM ARRAY[
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
  ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: obligation column contract changed';
  END IF;

  IF to_regclass(
       'public.booking_payment_requirements_org_booking_id_uidx'
     ) IS NULL
     OR to_regclass(
          'public.booking_additional_image_pricing_bases_org_booking_id_uidx'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: provenance support index missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_adjusted_financial_obligations;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: migration must not backfill obligation rows';
  END IF;

  IF NOT (
    SELECT relrowsecurity
    FROM pg_catalog.pg_class
    WHERE oid =
      'public.booking_adjusted_financial_obligations'::regclass
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: RLS is not enabled';
  END IF;

  IF NOT (
    SELECT relforcerowsecurity
    FROM pg_catalog.pg_class
    WHERE oid =
      'public.booking_adjusted_financial_obligations'::regclass
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: RLS is not forced';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.booking_adjusted_financial_obligations',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: authenticated SELECT missing';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.booking_adjusted_financial_obligations',
       'INSERT'
     )
     OR has_table_privilege(
          'authenticated',
          'public.booking_adjusted_financial_obligations',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.booking_adjusted_financial_obligations',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: authenticated direct mutation privilege exists';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.record_booking_adjusted_financial_obligation(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: authenticated RPC execute missing';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.record_booking_adjusted_financial_obligation(uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
          'service_role',
          'public.record_booking_adjusted_financial_obligation(uuid)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: forbidden RPC execute privilege exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
      AND procedure.prosecdef
      AND procedure.proconfig @>
          ARRAY['search_path=""']::text[]
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: RPC security-definer/search-path contract missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policies
    WHERE schemaname = 'public'
      AND tablename =
          'booking_adjusted_financial_obligations'
      AND policyname =
          'booking_adjusted_financial_obligations_authenticated_select'
      AND qual LIKE '%finance.read%'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: finance.read policy missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_adjusted_financial_obligation(uuid)'::regprocedure
      AND pg_get_functiondef(procedure.oid)
          LIKE '%finance.write%'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 9 assertion failed: finance.write RPC enforcement missing';
  END IF;
END
$s11s9_assertions$;
