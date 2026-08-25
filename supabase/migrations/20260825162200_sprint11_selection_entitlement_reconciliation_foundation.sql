-- =====================================================================
-- Sprint 11 — Shoot Completion & Post-Session Handoff
-- Slice 7 — Booking-Level Selection Entitlement Reconciliation
--           Evidence Foundation
--
-- Boundary:
--   * immutable booking_selection_reconciliations evidence;
--   * exact accepted-quotation commercial-version lineage;
--   * exact immutable selection-confirmation lineage;
--   * accepted_quote_version_entitlement_v1 calculation;
--   * explicit zero-overage evidence;
--   * pre-purchased entitlement-bearing add-ons included;
--   * existing selection.record controlled mutation authority;
--   * existing selection.read authenticated read containment;
--   * no new permissions or role grants;
--   * no excess-image pricing;
--   * no adjusted financial obligation;
--   * no payment behavior changes;
--   * no Stage 12 -> 13 journey advancement;
--   * no application UI.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11s7_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass(
       'public.booking_selection_reconciliations'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: booking_selection_reconciliations already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_selection_reconciliation(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: reconciliation RPC already exists';
  END IF;

  IF to_regprocedure(
       'public.lsh_booking_selection_reconciliation_guard()'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: reconciliation guard already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.quotations') IS NULL
     OR to_regclass('public.quotation_line_items') IS NULL
     OR to_regclass(
          'public.booking_selection_confirmations'
        ) IS NULL
     OR to_regclass(
          'public.commercial_image_entitlements'
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
     OR to_regclass('public.role_permissions') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: required canonical relation missing';
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
       'public.record_booking_selection_confirmation(uuid,integer,timestamp with time zone)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE (
          permission.key = 'selection.read'
          AND permission.domain = 'selection'
          AND NOT permission.requires_server_enforcement
        )
     OR (
          permission.key = 'selection.record'
          AND permission.domain = 'selection'
          AND permission.requires_server_enforcement
        );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: frozen selection permissions unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.stage_order = 12
    AND stage.stage_key = 'selection_pending'
    AND stage.is_active;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: canonical Stage 12 selection_pending unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_image_entitlements;

  IF v_count <> 13 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: expected 13 canonical image-entitlement rows, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_image_entitlements entitlement
  WHERE entitlement.package_version_id IS NOT NULL
    AND entitlement.addon_version_id IS NULL;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: expected 12 package entitlement rows, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_image_entitlements entitlement
  JOIN public.commercial_addon_versions version
    ON version.organization_id =
       entitlement.organization_id
   AND version.id =
       entitlement.addon_version_id
  JOIN public.commercial_addons addon
    ON addon.organization_id =
       version.organization_id
   AND addon.id =
       version.addon_id
  WHERE addon.addon_key = 'additional_image'
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND version.pricing_type =
        'fixed_amount'::public.commercial_pricing_type
    AND version.currency = 'INR'
    AND version.amount_inr = 500
    AND entitlement.retouched_image_count_per_unit = 1;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 precondition failed: canonical additional_image v1 entitlement unavailable';
  END IF;
END
$s11s7_preconditions$;

-- =====================================================================
-- Section B1 — Tenant-safe selection-confirmation identity anchor
--
-- booking_selection_confirmations already has:
--   UNIQUE (organization_id, booking_id)
-- and:
--   PRIMARY KEY (id)
--
-- This additional unique index provides the exact non-partial unique
-- identity required for the reconciliation FK to bind organization,
-- booking and immutable confirmation id together without rewriting any
-- historical selection evidence.
-- =====================================================================

CREATE UNIQUE INDEX
booking_selection_confirmations_org_booking_id_uidx
ON public.booking_selection_confirmations (
  organization_id,
  booking_id,
  id
);

-- =====================================================================
-- Section B2 — Immutable reconciliation evidence
-- =====================================================================

CREATE TABLE public.booking_selection_reconciliations (
  id                               uuid
                                   PRIMARY KEY
                                   DEFAULT gen_random_uuid(),

  organization_id                  uuid NOT NULL,
  booking_id                       uuid NOT NULL,

  source_quotation_id              uuid NOT NULL,
  source_selection_confirmation_id uuid NOT NULL,

  selected_image_count             integer NOT NULL,
  included_image_count             integer NOT NULL,
  excess_image_count               integer NOT NULL,

  calculation_rule                 text NOT NULL,

  recorded_at                      timestamptz
                                   NOT NULL
                                   DEFAULT now(),
  recorded_by                      uuid NOT NULL,

  CONSTRAINT booking_selection_reconciliations_selected_count_chk
    CHECK (
      selected_image_count > 0
    ),

  CONSTRAINT booking_selection_reconciliations_included_count_chk
    CHECK (
      included_image_count > 0
    ),

  CONSTRAINT booking_selection_reconciliations_excess_count_chk
    CHECK (
      excess_image_count >= 0
    ),

  CONSTRAINT booking_selection_reconciliations_formula_chk
    CHECK (
      excess_image_count =
        GREATEST(
          selected_image_count - included_image_count,
          0
        )
    ),

  CONSTRAINT booking_selection_reconciliations_rule_chk
    CHECK (
      calculation_rule =
        'accepted_quote_version_entitlement_v1'
    ),

  CONSTRAINT booking_selection_reconciliations_booking_fkey
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

  CONSTRAINT booking_selection_reconciliations_quote_fkey
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

  CONSTRAINT booking_selection_reconciliations_confirmation_fkey
    FOREIGN KEY (
      organization_id,
      booking_id,
      source_selection_confirmation_id
    )
    REFERENCES public.booking_selection_confirmations (
      organization_id,
      booking_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_selection_reconciliations_recorded_by_fkey
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

  CONSTRAINT booking_selection_reconciliations_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    )
);

CREATE INDEX booking_selection_reconciliations_org_recorded_idx
ON public.booking_selection_reconciliations (
  organization_id,
  recorded_at DESC
);

-- =====================================================================
-- Section C — Immutable canonical-value guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_selection_reconciliation_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_quote public.quotations;
  v_confirmation public.booking_selection_confirmations;

  v_actor uuid;

  v_package_line_count bigint := 0;
  v_package_entitlement_count bigint := 0;

  v_included_image_count integer := 0;
  v_expected_excess integer := 0;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking selection reconciliation evidence is immutable';
  END IF;

  IF NEW.organization_id IS NULL
     OR NEW.booking_id IS NULL
     OR NEW.source_quotation_id IS NULL
     OR NEW.source_selection_confirmation_id IS NULL
     OR NEW.selected_image_count IS NULL
     OR NEW.included_image_count IS NULL
     OR NEW.excess_image_count IS NULL
     OR NEW.calculation_rule IS NULL
     OR NEW.recorded_at IS NULL
     OR NEW.recorded_by IS NULL THEN
    RAISE EXCEPTION
      'booking selection reconciliation requires complete immutable attribution';
  END IF;

  IF NEW.calculation_rule <>
     'accepted_quote_version_entitlement_v1' THEN
    RAISE EXCEPTION
      'booking selection reconciliation calculation rule is invalid';
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
      'booking selection reconciliation requires canonical booking';
  END IF;

  IF NEW.source_quotation_id IS DISTINCT FROM
     v_booking.source_quotation_id THEN
    RAISE EXCEPTION
      'booking selection reconciliation source quotation must match booking';
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
      'booking selection reconciliation requires accepted source quotation';
  END IF;

  SELECT confirmation.*
  INTO v_confirmation
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        NEW.organization_id
    AND confirmation.booking_id =
        NEW.booking_id
    AND confirmation.id =
        NEW.source_selection_confirmation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking selection reconciliation requires canonical selection confirmation';
  END IF;

  IF NEW.selected_image_count IS DISTINCT FROM
     v_confirmation.selected_image_count THEN
    RAISE EXCEPTION
      'booking selection reconciliation selected count must snapshot confirmation';
  END IF;

  SELECT
    count(*) FILTER (
      WHERE line_item.line_type =
            'package'::public.quotation_line_type
    ),
    count(*) FILTER (
      WHERE line_item.line_type =
            'package'::public.quotation_line_type
        AND package_entitlement.id IS NOT NULL
    ),
    COALESCE(
      sum(
        CASE
          WHEN line_item.line_type =
               'package'::public.quotation_line_type
            THEN
              line_item.quantity *
              COALESCE(
                package_entitlement.retouched_image_count_per_unit,
                0
              )

          WHEN line_item.line_type =
               'addon'::public.quotation_line_type
            THEN
              line_item.quantity *
              COALESCE(
                addon_entitlement.retouched_image_count_per_unit,
                0
              )

          ELSE 0
        END
      ),
      0
    )::integer
  INTO
    v_package_line_count,
    v_package_entitlement_count,
    v_included_image_count
  FROM public.quotation_line_items line_item
  LEFT JOIN public.commercial_image_entitlements
    package_entitlement
    ON package_entitlement.organization_id =
       line_item.organization_id
   AND package_entitlement.package_version_id =
       line_item.source_package_version_id
  LEFT JOIN public.commercial_image_entitlements
    addon_entitlement
    ON addon_entitlement.organization_id =
       line_item.organization_id
   AND addon_entitlement.addon_version_id =
       line_item.source_addon_version_id
  WHERE line_item.organization_id =
        NEW.organization_id
    AND line_item.quotation_id =
        NEW.source_quotation_id;

  IF v_package_line_count <> 1 THEN
    RAISE EXCEPTION
      'booking selection reconciliation requires exactly one accepted package line';
  END IF;

  IF v_package_entitlement_count <> 1 THEN
    RAISE EXCEPTION
      'booking selection reconciliation requires exact package entitlement authority';
  END IF;

  IF v_included_image_count <= 0 THEN
    RAISE EXCEPTION
      'booking selection reconciliation included image count must be positive';
  END IF;

  IF NEW.included_image_count IS DISTINCT FROM
     v_included_image_count THEN
    RAISE EXCEPTION
      'booking selection reconciliation included count must match accepted quotation entitlement';
  END IF;

  v_expected_excess :=
    GREATEST(
      v_confirmation.selected_image_count -
        v_included_image_count,
      0
    );

  IF NEW.excess_image_count IS DISTINCT FROM
     v_expected_excess THEN
    RAISE EXCEPTION
      'booking selection reconciliation excess count is inconsistent';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking selection reconciliation recorded_by must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_selection_reconciliations_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_selection_reconciliations
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_selection_reconciliation_guard();

REVOKE ALL
ON FUNCTION
  public.lsh_booking_selection_reconciliation_guard()
FROM PUBLIC, anon, authenticated, service_role;

-- =====================================================================
-- Section D — Forced RLS / authenticated selection.read containment
-- =====================================================================

ALTER TABLE public.booking_selection_reconciliations
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_selection_reconciliations
FORCE ROW LEVEL SECURITY;

REVOKE ALL
ON TABLE public.booking_selection_reconciliations
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_selection_reconciliations
TO authenticated;

CREATE POLICY booking_selection_reconciliations_authenticated_select
ON public.booking_selection_reconciliations
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_selection_reconciliations.organization_id
      AND booking.id =
          booking_selection_reconciliations.booking_id
      AND public.has_permission(
            booking.organization_id,
            'selection.read',
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
-- Section E — Controlled deterministic reconciliation RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_selection_reconciliation(
  p_booking_id uuid
)
RETURNS public.booking_selection_reconciliations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_quote public.quotations;
  v_confirmation public.booking_selection_confirmations;

  v_existing public.booking_selection_reconciliations;
  v_result public.booking_selection_reconciliations;

  v_actor uuid;

  v_state_count integer := 0;
  v_package_line_count bigint := 0;
  v_package_entitlement_count bigint := 0;

  v_included_image_count integer := 0;
  v_excess_image_count integer := 0;

  v_recorded_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  v_recorded_at := now();

  -- ---------------------------------------------------------------
  -- Lock order 1: booking synchronization root.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active membership + selection.record + branch scope.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'selection.record',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: selection.record permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exactly one current canonical journey state.
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
      'record_booking_selection_reconciliation: booking must have exactly one current journey state'
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
      'record_booking_selection_reconciliation: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 12
     OR v_stage.stage_key <> 'selection_pending' THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: booking must be exactly Selection Pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Immutable canonical selection evidence.
  -- ---------------------------------------------------------------

  SELECT confirmation.*
  INTO v_confirmation
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        v_booking.organization_id
    AND confirmation.booking_id =
        v_booking.id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: selection confirmation required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact immutable accepted quotation.
  -- ---------------------------------------------------------------

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
      'record_booking_selection_reconciliation: accepted source quotation required'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact version-bound image entitlement calculation.
  --
  -- Package:
  --   exact package version must have entitlement authority.
  --
  -- Add-on:
  --   exact add-on version contributes only when entitlement authority
  --   exists. Non-image add-ons therefore contribute zero.
  --
  -- Custom:
  --   always contributes zero.
  -- ---------------------------------------------------------------

  SELECT
    count(*) FILTER (
      WHERE line_item.line_type =
            'package'::public.quotation_line_type
    ),
    count(*) FILTER (
      WHERE line_item.line_type =
            'package'::public.quotation_line_type
        AND package_entitlement.id IS NOT NULL
    ),
    COALESCE(
      sum(
        CASE
          WHEN line_item.line_type =
               'package'::public.quotation_line_type
            THEN
              line_item.quantity *
              COALESCE(
                package_entitlement.retouched_image_count_per_unit,
                0
              )

          WHEN line_item.line_type =
               'addon'::public.quotation_line_type
            THEN
              line_item.quantity *
              COALESCE(
                addon_entitlement.retouched_image_count_per_unit,
                0
              )

          ELSE 0
        END
      ),
      0
    )::integer
  INTO
    v_package_line_count,
    v_package_entitlement_count,
    v_included_image_count
  FROM public.quotation_line_items line_item
  LEFT JOIN public.commercial_image_entitlements
    package_entitlement
    ON package_entitlement.organization_id =
       line_item.organization_id
   AND package_entitlement.package_version_id =
       line_item.source_package_version_id
  LEFT JOIN public.commercial_image_entitlements
    addon_entitlement
    ON addon_entitlement.organization_id =
       line_item.organization_id
   AND addon_entitlement.addon_version_id =
       line_item.source_addon_version_id
  WHERE line_item.organization_id =
        v_booking.organization_id
    AND line_item.quotation_id =
        v_booking.source_quotation_id;

  IF v_package_line_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: exactly one accepted package line required'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_package_entitlement_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: exact package entitlement authority required'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_included_image_count <= 0 THEN
    RAISE EXCEPTION
      'record_booking_selection_reconciliation: included image entitlement must be positive'
      USING ERRCODE = 'P0001';
  END IF;

  v_excess_image_count :=
    GREATEST(
      v_confirmation.selected_image_count -
        v_included_image_count,
      0
    );

  -- ---------------------------------------------------------------
  -- Lock order 3: immutable reconciliation / exact replay.
  -- ---------------------------------------------------------------

  SELECT reconciliation.*
  INTO v_existing
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        v_booking.organization_id
    AND reconciliation.booking_id =
        v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.source_quotation_id
         IS DISTINCT FROM
       v_booking.source_quotation_id
       OR v_existing.source_selection_confirmation_id
            IS DISTINCT FROM
          v_confirmation.id
       OR v_existing.selected_image_count
            IS DISTINCT FROM
          v_confirmation.selected_image_count
       OR v_existing.included_image_count
            IS DISTINCT FROM
          v_included_image_count
       OR v_existing.excess_image_count
            IS DISTINCT FROM
          v_excess_image_count
       OR v_existing.calculation_rule
            IS DISTINCT FROM
          'accepted_quote_version_entitlement_v1' THEN
      RAISE EXCEPTION
        'record_booking_selection_reconciliation: persisted reconciliation conflicts with canonical evidence'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing;
  END IF;

  -- ---------------------------------------------------------------
  -- Append immutable canonical reconciliation evidence.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_selection_reconciliations (
    organization_id,
    booking_id,
    source_quotation_id,
    source_selection_confirmation_id,
    selected_image_count,
    included_image_count,
    excess_image_count,
    calculation_rule,
    recorded_at,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_booking.source_quotation_id,
    v_confirmation.id,
    v_confirmation.selected_image_count,
    v_included_image_count,
    v_excess_image_count,
    'accepted_quote_version_entitlement_v1',
    v_recorded_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  -- ---------------------------------------------------------------
  -- Structural, non-sensitive audit evidence only.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.selection_reconciled',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'selected_image_count',
        v_result.selected_image_count,
      'included_image_count',
        v_result.included_image_count,
      'excess_image_count',
        v_result.excess_image_count,
      'calculation_rule',
        v_result.calculation_rule
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'reconciliation_id',
        v_result.id,
      'source_quotation_id',
        v_result.source_quotation_id,
      'source_selection_confirmation_id',
        v_result.source_selection_confirmation_id,
      'recorded_by',
        v_actor
    ),
    'application',
    NULL
  );

  -- Journey intentionally remains exact Stage 12.
  -- No booking_journey_states or booking_stage_transitions mutation.
  -- No quotation, payment or financial-obligation mutation.

  RETURN v_result;
END;
$$;

-- =====================================================================
-- Section F — RPC execution boundary + documentation
-- =====================================================================

REVOKE ALL
ON FUNCTION
  public.record_booking_selection_reconciliation(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION
  public.record_booking_selection_reconciliation(uuid)
TO authenticated;

COMMENT ON TABLE public.booking_selection_reconciliations IS
  'Immutable canonical evidence reconciling an accepted quotation image entitlement with a finalized Stage-12 selected-image count. This relation does not price excess images, create a financial obligation, determine settlement or advance the booking journey.';

COMMENT ON FUNCTION
  public.record_booking_selection_reconciliation(uuid)
IS
  'Record deterministic accepted-quotation version-bound image-entitlement reconciliation evidence at exact Stage 12 Selection Pending without pricing excess images, mutating payments or advancing the journey.';

-- =====================================================================
-- Section G — Migration assertions
-- =====================================================================

DO $s11s7_assertions$
DECLARE
  v_count integer;
  v_public_execute boolean;
BEGIN
  -- ---------------------------------------------------------------
  -- Canonical permission state remains unchanged.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  -- ---------------------------------------------------------------
  -- Relation + exact frozen columns.
  -- ---------------------------------------------------------------

  IF to_regclass(
       'public.booking_selection_reconciliations'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation relation unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'booking_selection_reconciliations';

  IF v_count <> 11 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: expected 11 reconciliation columns, found %',
      v_count;
  END IF;

  IF (
    SELECT array_agg(
             column_name
             ORDER BY ordinal_position
           )::text[]
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_selection_reconciliations'
  ) IS DISTINCT FROM
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
     ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation column contract mismatch';
  END IF;

  -- ---------------------------------------------------------------
  -- Tenant-safe provenance anchors.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename =
        'booking_selection_confirmations'
    AND indexname =
        'booking_selection_confirmations_org_booking_id_uidx'
    AND indexdef ILIKE
        '%UNIQUE INDEX%organization_id, booking_id, id%';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: tenant-safe confirmation identity anchor unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_constraint constraint_row
  WHERE constraint_row.conrelid =
        'public.booking_selection_reconciliations'::regclass
    AND constraint_row.contype = 'f'
    AND constraint_row.conname IN (
      'booking_selection_reconciliations_booking_fkey',
      'booking_selection_reconciliations_quote_fkey',
      'booking_selection_reconciliations_confirmation_fkey',
      'booking_selection_reconciliations_recorded_by_fkey'
    );

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: tenant-safe reconciliation foreign keys incomplete';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_constraint constraint_row
  WHERE constraint_row.conrelid =
        'public.booking_selection_reconciliations'::regclass
    AND constraint_row.conname =
        'booking_selection_reconciliations_org_booking_key'
    AND constraint_row.contype = 'u';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: one-reconciliation-per-booking contract missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Forced RLS + authenticated SELECT-only boundary.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace
    ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname =
        'booking_selection_reconciliations'
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation RLS contract invalid';
  END IF;

  IF NOT has_table_privilege(
       'authenticated',
       'public.booking_selection_reconciliations',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: authenticated reconciliation SELECT unavailable';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.booking_selection_reconciliations',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_selection_reconciliations',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_selection_reconciliations',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: authenticated direct reconciliation mutation detected';
  END IF;

  IF has_table_privilege(
       'service_role',
       'public.booking_selection_reconciliations',
       'SELECT'
     )
     OR has_table_privilege(
       'service_role',
       'public.booking_selection_reconciliations',
       'INSERT'
     )
     OR has_table_privilege(
       'service_role',
       'public.booking_selection_reconciliations',
       'UPDATE'
     )
     OR has_table_privilege(
       'service_role',
       'public.booking_selection_reconciliations',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: service_role application table privilege detected';
  END IF;

  -- ---------------------------------------------------------------
  -- Controlled RPC security contract.
  -- ---------------------------------------------------------------

  IF to_regprocedure(
       'public.record_booking_selection_reconciliation(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc procedure
  JOIN pg_namespace namespace
    ON namespace.oid = procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.oid =
        'public.record_booking_selection_reconciliation(uuid)'::regprocedure
    AND procedure.prosecdef
    AND procedure.proconfig =
        ARRAY['search_path=""']::text[];

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation RPC security configuration invalid';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault(
          'f',
          procedure.proowner
        )
      )
    ) acl_entry
    WHERE procedure.oid =
          'public.record_booking_selection_reconciliation(uuid)'::regprocedure
      AND acl_entry.grantee = 0
      AND acl_entry.privilege_type =
          'EXECUTE'
  )
  INTO v_public_execute;

  IF v_public_execute THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: PUBLIC may execute reconciliation RPC';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.record_booking_selection_reconciliation(uuid)',
       'EXECUTE'
     )
     OR NOT has_function_privilege(
       'authenticated',
       'public.record_booking_selection_reconciliation(uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'service_role',
       'public.record_booking_selection_reconciliation(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation RPC ACL contract invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Immutable guard + no implicit reconciliation backfill.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_trigger trigger_row
  WHERE trigger_row.tgrelid =
        'public.booking_selection_reconciliations'::regclass
    AND trigger_row.tgname =
        'booking_selection_reconciliations_guard'
    AND NOT trigger_row.tgisinternal;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation immutable guard missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_selection_reconciliations;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 7 validation failed: reconciliation rows must not be implicitly backfilled';
  END IF;
END
$s11s7_assertions$;

-- =====================================================================
-- End Sprint 11 Slice 7
-- =====================================================================
