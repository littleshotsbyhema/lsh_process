-- =====================================================================
-- Sprint 12 — Selection Pending
-- Slice 4 — Controlled Stage 11 -> 12 / selection_pending Advancement Gate
--
-- Boundary:
--   * one controlled mark_booking_selection_pending(uuid) RPC;
--   * consume canonical shoot-completion evidence without rewriting it;
--   * validate canonical Stage 10 -> 11 completion lineage;
--   * exact Stage 11 -> 12 advancement only;
--   * strict Stage 12 replay;
--   * no new permission or role grant;
--   * no selection evidence schema;
--   * no editing / delivery implementation;
--   * no Stage 12 -> 13 implementation;
--   * no application UI.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11_slice4_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_selection_pending(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 12 precondition failed: mark_booking_selection_pending already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.booking_shoot_completions') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.roles') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 12 precondition failed: required canonical relation missing';
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
       'public.mark_booking_shoot_completed(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 12 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key =
        'booking.stage.advance'
    AND permission.domain =
        'bookings';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 12 precondition failed: canonical booking.stage.advance permission unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  WHERE permission.key =
        'booking.stage.advance';

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 12 precondition failed: canonical booking.stage.advance grant cardinality changed';
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
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 12 precondition failed: canonical booking.stage.advance role boundary unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.is_active
    AND (
      (
        stage.stage_order = 11
        AND stage.stage_key =
            'shoot_completed'
      )
      OR
      (
        stage.stage_order = 12
        AND stage.stage_key =
            'selection_pending'
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 12 precondition failed: canonical Stage 11 / Stage 12 catalogue unavailable';
  END IF;
END
$s11_slice4_preconditions$;

-- =====================================================================
-- Section B — Controlled Stage 11 -> 12 operation
-- =====================================================================

CREATE FUNCTION public.mark_booking_selection_pending(
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
  v_completion public.booking_shoot_completions;

  v_actor uuid;

  v_state_count integer := 0;
  v_completion_count integer := 0;
  v_shoot_completed_transition_count integer := 0;
  v_selection_pending_transition_count integer := 0;
  v_updated_count integer := 0;

  v_selection_pending_stage_id uuid;
  v_transitioned_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: booking synchronization root.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active member + canonical journey-advancement authority.
  -- Editing / delivery permissions deliberately do not apply here.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: booking branch scope required'
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
      'mark_booking_selection_pending: booking must have exactly one current journey state'
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
      'mark_booking_selection_pending: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact operation-stage containment.
  --
  -- First execution is allowed only from canonical Stage 11.
  -- Replay is allowed only from canonical Stage 12.
  -- No other journey stage may consume post-shoot lineage checks.
  -- ---------------------------------------------------------------

  IF NOT (
    (
      v_stage.stage_order = 11
      AND v_stage.stage_key =
          'shoot_completed'
    )
    OR
    (
      v_stage.stage_order = 12
      AND v_stage.stage_key =
          'selection_pending'
    )
  ) THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: booking must be exactly Shoot Completed or Selection Pending replay'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: exactly one immutable completion evidence row.
  --
  -- Stage 11 -> 12 consumes the established completion lineage.
  -- It does not re-run preparation, Safety or shoot-schedule gates.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_completion_count
  FROM public.booking_shoot_completions completion
  WHERE completion.organization_id =
        v_booking.organization_id
    AND completion.booking_id =
        v_booking.id;

  IF v_completion_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: exactly one canonical shoot completion row required'
      USING ERRCODE = '22023';
  END IF;

  SELECT completion.*
  INTO v_completion
  FROM public.booking_shoot_completions completion
  WHERE completion.organization_id =
        v_booking.organization_id
    AND completion.booking_id =
        v_booking.id
  FOR UPDATE;

  -- ---------------------------------------------------------------
  -- Canonical Stage 10 -> 11 lineage must exist exactly once.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_shoot_completed_transition_count
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
        'shoot_completed'
    AND source_stage.stage_order = 10
    AND source_stage.stage_key =
        'shoot_scheduled'
    AND destination_stage.stage_order = 11
    AND destination_stage.stage_key =
        'shoot_completed';

  IF v_shoot_completed_transition_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: canonical Shoot Completed transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Strict canonical Stage 12 replay.
  --
  -- Replay proves both prior completion lineage and the exact
  -- Stage 11 -> 12 transition. It performs no mutation or audit.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order = 12
     AND v_stage.stage_key =
         'selection_pending' THEN

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
        'mark_booking_selection_pending: Selection Pending replay history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  -- ---------------------------------------------------------------
  -- First advancement must start at exact canonical Stage 11.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order <> 11
     OR v_stage.stage_key <>
          'shoot_completed' THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: booking must be exactly Shoot Completed'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve explicit canonical Stage 12 destination.
  -- ---------------------------------------------------------------

  SELECT stage.id
  INTO v_selection_pending_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.stage_order = 12
    AND stage.stage_key =
        'selection_pending'
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_selection_pending: canonical Selection Pending stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Append canonical transition before current-state mutation.
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
    v_selection_pending_stage_id,
    'selection_pending',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Optimistic exact-state/version advancement.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_selection_pending_stage_id,
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
      'mark_booking_selection_pending: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- One structural non-sensitive audit event.
  --
  -- No selected-image, selection-count, gallery or proofing content
  -- exists at this boundary.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.selection_pending',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage',
        v_stage.stage_key,
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'selection_pending',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'completion_id',
        v_completion.id,
      'completed_at',
        v_completion.completed_at,
      'transition_key',
        'selection_pending',
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

-- =====================================================================
-- Section C — RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.mark_booking_selection_pending(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.mark_booking_selection_pending(uuid)
FROM anon;

REVOKE ALL
ON FUNCTION public.mark_booking_selection_pending(uuid)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.mark_booking_selection_pending(uuid)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.mark_booking_selection_pending(uuid)
TO authenticated;

COMMENT ON FUNCTION public.mark_booking_selection_pending(uuid) IS
  'Advance one authorized booking from canonical Stage 11 Shoot Completed to Stage 12 Selection Pending after validating canonical shoot-completion evidence and transition lineage.';

-- =====================================================================
-- Section D — Migration assertions
-- =====================================================================

DO $s11_slice4_assertions$
DECLARE
  v_count integer;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_selection_pending(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 12 validation failed: Stage 11 -> 12 RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc procedure
  JOIN pg_namespace namespace
    ON namespace.oid =
       procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname =
        'mark_booking_selection_pending'
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
      'Sprint 12 validation failed: Stage 11 -> 12 RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.mark_booking_selection_pending(uuid)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 12 validation failed: authenticated EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.mark_booking_selection_pending(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 12 validation failed: anon EXECUTE must be denied';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.mark_booking_selection_pending(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 12 validation failed: service_role EXECUTE must remain unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  WHERE permission.key =
        'booking.stage.advance';

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 12 validation failed: booking.stage.advance grant cardinality changed unexpectedly';
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
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 12 validation failed: booking.stage.advance role boundary changed unexpectedly';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key IN (
    'selection.pending',
    'selection.advance',
    'booking.selection.pending'
  );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 12 validation failed: unexpected stage-specific selection permission exists';
  END IF;
END
$s11_slice4_assertions$;
