-- =====================================================================
-- Sprint 11 Slice 12 — Editing Start Evidence Foundation
--
-- Scope:
--   * immutable canonical editing-start evidence;
--   * existing editing.write mutation authority;
--   * existing editing.read read authority;
--   * exact Stage 13 editing_pending containment;
--   * exact Stage 12 -> 13 source-transition lineage;
--   * no journey advancement.
--
-- Explicitly out of scope:
--   * Stage 13 -> 14;
--   * editor assignment;
--   * mutable editing workflow;
--   * editing SLA / deadline;
--   * QC;
--   * Pixieset / delivery;
--   * UI/runtime.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11_slice12_preconditions$
DECLARE
  v_count integer;
  v_roles text[];
BEGIN
  IF to_regclass(
       'public.booking_editing_starts'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: booking_editing_starts already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_editing_start(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: record_booking_editing_start already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass(
          'public.booking_journey_states'
        ) IS NULL
     OR to_regclass(
          'public.booking_journey_stages'
        ) IS NULL
     OR to_regclass(
          'public.booking_stage_transitions'
        ) IS NULL
     OR to_regclass(
          'public.organization_members'
        ) IS NULL
     OR to_regclass(
          'public.permissions'
        ) IS NULL
     OR to_regclass(
          'public.roles'
        ) IS NULL
     OR to_regclass(
          'public.role_permissions'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: prerequisite relation missing';
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
          'public.mark_booking_editing_pending(uuid)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: prerequisite helper/RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'editing.write';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'editor',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: editing.write topology is %',
      v_roles;
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'editing.read';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'client_coordinator',
         'editor',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: editing.read topology is %',
      v_roles;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.stage_order = 13
    AND stage.stage_key =
        'editing_pending'
    AND stage.is_active;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 precondition failed: canonical Stage 13 editing_pending unavailable';
  END IF;
END
$s11_slice12_preconditions$;

-- =====================================================================
-- Section B — Immutable editing-start evidence
-- =====================================================================

CREATE TABLE public.booking_editing_starts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  source_editing_pending_transition_id uuid NOT NULL,

  started_at timestamptz NOT NULL,
  started_by uuid NOT NULL,

  CONSTRAINT booking_editing_starts_booking_fkey
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

  CONSTRAINT booking_editing_starts_source_transition_fkey
    FOREIGN KEY (
      organization_id,
      source_editing_pending_transition_id
    )
    REFERENCES public.booking_stage_transitions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_editing_starts_started_by_fkey
    FOREIGN KEY (
      started_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_editing_starts_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    ),

  CONSTRAINT booking_editing_starts_org_source_transition_key
    UNIQUE (
      organization_id,
      source_editing_pending_transition_id
    )
);

CREATE INDEX booking_editing_starts_org_started_idx
ON public.booking_editing_starts (
  organization_id,
  started_at DESC,
  id
);

-- =====================================================================
-- Section C — Immutable lifecycle and lineage guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_editing_start_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_transitioned_at timestamptz;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking editing start evidence is immutable';
  END IF;

  IF NEW.organization_id IS NULL
     OR NEW.booking_id IS NULL
     OR NEW.source_editing_pending_transition_id IS NULL
     OR NEW.started_at IS NULL
     OR NEW.started_by IS NULL THEN
    RAISE EXCEPTION
      'booking editing start evidence requires complete immutable attribution';
  END IF;

  SELECT transition_row.transitioned_at
  INTO v_transitioned_at
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
        NEW.organization_id
    AND transition_row.id =
        NEW.source_editing_pending_transition_id
    AND transition_row.booking_id =
        NEW.booking_id
    AND transition_row.transition_key =
        'editing_pending'
    AND source_stage.stage_order = 12
    AND source_stage.stage_key =
        'selection_pending'
    AND destination_stage.stage_order = 13
    AND destination_stage.stage_key =
        'editing_pending'
    AND destination_stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking editing start source transition must be the canonical Stage 12 to 13 editing_pending transition';
  END IF;

  IF NEW.started_at <
       v_transitioned_at THEN
    RAISE EXCEPTION
      'booking editing start cannot precede canonical Editing Pending entry';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.started_by IS DISTINCT FROM
          v_actor THEN
      RAISE EXCEPTION
        'booking editing start started_by must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_editing_starts_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_editing_starts
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_editing_start_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_editing_start_guard()
FROM PUBLIC, anon, authenticated, service_role;

-- =====================================================================
-- Section D — Forced RLS and editing.read
-- =====================================================================

ALTER TABLE public.booking_editing_starts
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_editing_starts
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_editing_starts
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_editing_starts
TO authenticated;

GRANT ALL
ON TABLE public.booking_editing_starts
TO service_role;

CREATE POLICY booking_editing_starts_authenticated_select
ON public.booking_editing_starts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_editing_starts.organization_id
      AND booking.id =
          booking_editing_starts.booking_id
      AND public.has_permission(
            booking.organization_id,
            'editing.read',
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
-- Section E — Controlled editing-start recorder
-- =====================================================================

CREATE FUNCTION public.record_booking_editing_start(
  p_booking_id uuid
)
RETURNS public.booking_editing_starts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_transition public.booking_stage_transitions;

  v_existing public.booking_editing_starts;
  v_result public.booking_editing_starts;

  v_actor uuid;
  v_started_at timestamptz;

  v_state_count integer := 0;
  v_transition_count integer := 0;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_editing_start: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_editing_start: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_editing_start: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_editing_start: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'editing.write',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_editing_start: editing.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_editing_start: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_editing_start: booking must have exactly one current journey state'
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
      'record_booking_editing_start: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 13
     OR v_stage.stage_key <>
        'editing_pending' THEN
    RAISE EXCEPTION
      'record_booking_editing_start: booking must be exactly Editing Pending'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*)
  INTO v_transition_count
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
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 12
    AND source_stage.stage_key =
        'selection_pending'
    AND destination_stage.stage_order = 13
    AND destination_stage.stage_key =
        'editing_pending';

  IF v_transition_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_editing_start: canonical Editing Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT transition_row.*
  INTO v_transition
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
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 12
    AND source_stage.stage_key =
        'selection_pending'
    AND destination_stage.stage_order = 13
    AND destination_stage.stage_key =
        'editing_pending';

  v_started_at := now();

  IF v_started_at <
       v_transition.transitioned_at THEN
    RAISE EXCEPTION
      'record_booking_editing_start: editing start cannot precede Editing Pending entry'
      USING ERRCODE = '22023';
  END IF;

  SELECT editing_start.*
  INTO v_existing
  FROM public.booking_editing_starts editing_start
  WHERE editing_start.organization_id =
        v_booking.organization_id
    AND editing_start.booking_id =
        v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.source_editing_pending_transition_id
         IS DISTINCT FROM
       v_transition.id
       OR v_existing.started_at <
          v_transition.transitioned_at THEN
      RAISE EXCEPTION
        'record_booking_editing_start: existing editing-start evidence is inconsistent'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing;
  END IF;

  INSERT INTO public.booking_editing_starts (
    organization_id,
    booking_id,
    source_editing_pending_transition_id,
    started_at,
    started_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_transition.id,
    v_started_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_started',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'editing_start_id',
        v_result.id,
      'source_editing_pending_transition_id',
        v_result.source_editing_pending_transition_id,
      'started_at',
        v_result.started_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'editing_start_id',
        v_result.id,
      'source_editing_pending_transition_id',
        v_result.source_editing_pending_transition_id,
      'started_at',
        v_result.started_at
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$$;

COMMENT ON TABLE public.booking_editing_starts IS
  'Immutable canonical evidence that editing work started for a booking already at canonical Stage 13 Editing Pending. Does not advance the booking journey.';

COMMENT ON FUNCTION public.record_booking_editing_start(uuid) IS
  'Record immutable editing-start evidence for an authorized booking at exact canonical Stage 13 Editing Pending. Uses editing.write and does not advance the journey.';

-- =====================================================================
-- Section F — RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.record_booking_editing_start(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.record_booking_editing_start(uuid)
TO authenticated;

-- =====================================================================
-- Section G — Final frozen-contract assertions
-- =====================================================================

DO $s11_slice12_assertions$
DECLARE
  v_count integer;
  v_roles text[];
  v_definition text;
BEGIN
  IF to_regclass(
       'public.booking_editing_starts'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: booking_editing_starts missing';
  END IF;

  IF to_regprocedure(
       'public.record_booking_editing_start(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: recorder RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'booking_editing_starts';

  IF v_count <> 6 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: booking_editing_starts expected 6 columns, found %',
      v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.booking_editing_starts'::regclass
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: RLS must be enabled and forced';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: role-permission count changed';
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'editing.write';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'editor',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: editing.write topology changed';
  END IF;

  SELECT pg_get_functiondef(
           'public.record_booking_editing_start(uuid)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%editing.write%'
     OR v_definition NOT ILIKE
       '%has_branch_scope%'
     OR v_definition NOT ILIKE
       '%booking_stage_transitions%'
     OR v_definition NOT ILIKE
       '%editing_pending%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: recorder source lacks frozen authority markers';
  END IF;

  IF v_definition ILIKE
       '%booking.stage.advance%'
     OR v_definition ILIKE
       '%finance.read%'
     OR v_definition ILIKE
       '%payment.read%'
     OR v_definition ILIKE
       '%booking_selection_confirmations%'
     OR v_definition ILIKE
       '%booking_selection_reconciliations%'
     OR v_definition ILIKE
       '%booking_payment_requirements%'
     OR v_definition ILIKE
       '%booking_payments%'
     OR v_definition ILIKE
       '%booking_payment_reversals%'
     OR v_definition ILIKE
       '%booking_adjusted_financial_obligations%'
     OR v_definition ILIKE
       '%editing_in_progress%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: recorder imports forbidden downstream/upstream authority';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.record_booking_editing_start(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: service_role must not have recorder EXECUTE';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.record_booking_editing_start(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: anon must not have recorder EXECUTE';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       'public.record_booking_editing_start(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 12 validation failed: authenticated must have recorder EXECUTE';
  END IF;
END
$s11_slice12_assertions$;
