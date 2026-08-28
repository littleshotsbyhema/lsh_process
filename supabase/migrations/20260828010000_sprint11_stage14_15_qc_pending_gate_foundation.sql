-- =====================================================================
-- Sprint 11 - Shoot Completion & Post-Session Handoff
-- Slice 15 - Controlled Stage 14 -> 15 / QC Pending Advancement Gate
--
-- Frozen authority:
--   * one mark_booking_qc_pending(uuid) RPC;
--   * exact Stage 14 editing_in_progress -> Stage 15 qc_pending;
--   * existing booking.stage.advance only;
--   * immutable booking_editing_completions prerequisite;
--   * exact Stage 13 -> 14 editing_in_progress source-transition lineage;
--   * strict Stage 15 replay;
--   * one booking.qc_pending first-success audit;
--   * no new persistence;
--   * no new permission;
--   * no QC result, gallery or delivery authority.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $s11s15_preconditions$
DECLARE
  v_count integer;
  v_roles text[];
BEGIN
  IF to_regprocedure(
       'public.mark_booking_qc_pending(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 precondition failed: mark_booking_qc_pending already exists';
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
          'public.booking_editing_completions'
        ) IS NULL
     OR to_regclass(
          'public.organization_members'
        ) IS NULL
     OR to_regclass(
          'public.permissions'
        ) IS NULL
     OR to_regclass(
          'public.role_permissions'
        ) IS NULL
     OR to_regclass(
          'public.roles'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 precondition failed: prerequisite relation missing';
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
          'public.mark_booking_editing_in_progress(uuid)'
        ) IS NULL
     OR to_regprocedure(
          'public.record_booking_editing_completion(uuid)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 precondition failed: prerequisite helper/RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 precondition failed: expected 241 role-permission mappings, found %',
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
        'booking.stage.advance';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'client_coordinator',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 precondition failed: booking.stage.advance topology is %',
      v_roles;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.is_active
    AND (
      (
        stage.stage_order = 14
        AND stage.stage_key =
            'editing_in_progress'
      )
      OR
      (
        stage.stage_order = 15
        AND stage.stage_key =
            'qc_pending'
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 precondition failed: canonical Stage 14 / Stage 15 catalogue unavailable';
  END IF;
END
$s11s15_preconditions$;


-- =====================================================================
-- Section B - Controlled Stage 14 -> 15 advancement
-- =====================================================================

CREATE FUNCTION public.mark_booking_qc_pending(
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

  v_source_transition public.booking_stage_transitions;
  v_editing_completion public.booking_editing_completions;

  v_actor uuid;

  v_state_count integer := 0;
  v_source_transition_count integer := 0;
  v_completion_count integer := 0;
  v_destination_transition_count integer := 0;
  v_destination_stage_count integer := 0;

  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer := 0;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- Booking is the canonical synchronization root.

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- Exactly one current canonical journey state.

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking must have exactly one current journey state'
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
      'mark_booking_qc_pending: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (
      v_stage.stage_order = 14
      AND v_stage.stage_key =
          'editing_in_progress'
    )
    OR
    (
      v_stage.stage_order = 15
      AND v_stage.stage_key =
          'qc_pending'
    )
  ) THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking must be exactly Editing In Progress or QC Pending replay'
      USING ERRCODE = '22023';
  END IF;

  -- Strict Stage 15 replay proves historical journey advancement only.

  IF v_stage.stage_order = 15
     AND v_stage.stage_key =
         'qc_pending' THEN

    SELECT count(*)
    INTO v_destination_transition_count
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
          'qc_pending'
      AND transition_row.to_stage_id =
          v_state.current_stage_id
      AND source_stage.stage_order = 14
      AND source_stage.stage_key =
          'editing_in_progress'
      AND destination_stage.stage_order = 15
      AND destination_stage.stage_key =
          'qc_pending';

    IF v_destination_transition_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_qc_pending: QC Pending replay history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  -- First execution must be exact Stage 14.

  IF v_stage.stage_order <> 14
     OR v_stage.stage_key <>
        'editing_in_progress' THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking must be exactly Editing In Progress'
      USING ERRCODE = '22023';
  END IF;

  -- Exact Stage 13 -> 14 lineage.

  SELECT count(*)
  INTO v_source_transition_count
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
        'editing_in_progress'
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 13
    AND source_stage.stage_key =
        'editing_pending'
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key =
        'editing_in_progress';

  IF v_source_transition_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: canonical Editing In Progress transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT transition_row.*
  INTO v_source_transition
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
        'editing_in_progress'
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 13
    AND source_stage.stage_key =
        'editing_pending'
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key =
        'editing_in_progress';

  -- Exact immutable Editing Completion evidence.

  SELECT count(*)
  INTO v_completion_count
  FROM public.booking_editing_completions completion
  WHERE completion.organization_id =
        v_booking.organization_id
    AND completion.booking_id =
        v_booking.id;

  IF v_completion_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: exactly one canonical Editing Completion evidence row required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT completion.*
  INTO v_editing_completion
  FROM public.booking_editing_completions completion
  WHERE completion.organization_id =
        v_booking.organization_id
    AND completion.booking_id =
        v_booking.id;

  IF v_editing_completion.source_editing_in_progress_transition_id
       IS DISTINCT FROM
         v_source_transition.id
     OR v_editing_completion.completed_at <
        v_source_transition.transitioned_at THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: Editing Completion lineage is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  -- Current Stage 14 must not coexist with an existing Stage 14 -> 15
  -- canonical transition.

  SELECT count(*)
  INTO v_destination_transition_count
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
        'qc_pending'
    AND source_stage.stage_order = 14
    AND source_stage.stage_key =
        'editing_in_progress'
    AND destination_stage.stage_order = 15
    AND destination_stage.stage_key =
        'qc_pending';

  IF v_destination_transition_count <> 0 THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: unexpected pre-existing QC Pending transition history'
      USING ERRCODE = 'P0001';
  END IF;

  -- Resolve exact Stage 15 destination.

  SELECT count(*)
  INTO v_destination_stage_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.stage_order = 15
    AND stage.stage_key =
        'qc_pending'
    AND stage.is_active;

  IF v_destination_stage_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: exactly one canonical QC Pending stage required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT stage.id
  INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.stage_order = 15
    AND stage.stage_key =
        'qc_pending'
    AND stage.is_active;

  v_transitioned_at := now();

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
    v_destination_stage_id,
    'qc_pending',
    v_transitioned_at,
    v_actor
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_destination_stage_id,
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
      'mark_booking_qc_pending: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.qc_pending',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage',
        'editing_in_progress',
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'qc_pending',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'editing_completion_id',
        v_editing_completion.id,
      'source_editing_in_progress_transition_id',
        v_source_transition.id,
      'editing_completed_at',
        v_editing_completion.completed_at,
      'transition_key',
        'qc_pending',
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


COMMENT ON FUNCTION public.mark_booking_qc_pending(uuid) IS
  'Advance one authorized booking from exact Stage 14 Editing In Progress to exact Stage 15 QC Pending only after immutable canonical Editing Completion evidence exists. Uses booking.stage.advance and strict Stage 15 replay without re-evaluating historical editing, selection, finance or payment authority.';


-- =====================================================================
-- Section C - RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.mark_booking_qc_pending(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.mark_booking_qc_pending(uuid)
TO authenticated;


-- =====================================================================
-- Section D - Frozen-contract assertions
-- =====================================================================

DO $s11s15_assertions$
DECLARE
  v_count integer;
  v_roles text[];
  v_definition text;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_qc_pending(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: QC Pending RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_proc procedure
  JOIN pg_catalog.pg_namespace namespace
    ON namespace.oid =
       procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname =
        'mark_booking_qc_pending'
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
      'Sprint 11 Slice 15 validation failed: RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.mark_booking_qc_pending(uuid)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: authenticated EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.mark_booking_qc_pending(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: anon EXECUTE must be denied';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.mark_booking_qc_pending(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: service_role EXECUTE must be denied';
  END IF;

  IF EXISTS (
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
          'public.mark_booking_qc_pending(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type =
          'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: PUBLIC EXECUTE must be denied';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: role-permission count changed';
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
        'booking.stage.advance';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'client_coordinator',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: booking.stage.advance topology changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'booking.stage.advance'
    AND role.key =
        'editor';

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: Editor unexpectedly has journey-advance authority';
  END IF;

  SELECT pg_get_functiondef(
           'public.mark_booking_qc_pending(uuid)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%booking.stage.advance%'
     OR v_definition NOT ILIKE
       '%has_branch_scope%'
     OR v_definition NOT ILIKE
       '%booking_editing_completions%'
     OR v_definition NOT ILIKE
       '%booking_stage_transitions%'
     OR v_definition NOT ILIKE
       '%editing_in_progress%'
     OR v_definition NOT ILIKE
       '%qc_pending%'
     OR v_definition NOT ILIKE
       '%FOR UPDATE%'
     OR v_definition NOT ILIKE
       '%append_audit_event%'
     OR v_definition NOT ILIKE
       '%INSERT INTO public.booking_stage_transitions%'
     OR v_definition NOT ILIKE
       '%UPDATE public.booking_journey_states%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: required journey/evidence authority missing';
  END IF;

  IF v_definition ILIKE
       '%editing.write%'
     OR v_definition ILIKE
       '%editing.read%'
     OR v_definition ILIKE
       '%delivery.write%'
     OR v_definition ILIKE
       '%finance.read%'
     OR v_definition ILIKE
       '%payment.read%'
     OR v_definition ILIKE
       '%booking.team.assign%'
     OR v_definition ILIKE
       '%record_booking_editing_completion%'
     OR v_definition ILIKE
       '%INSERT INTO public.booking_editing_completions%'
     OR v_definition ILIKE
       '%UPDATE public.booking_editing_completions%'
     OR v_definition ILIKE
       '%DELETE FROM public.booking_editing_completions%'
     OR v_definition ILIKE
       '%pixieset_gallery_ready%'
     OR v_definition ILIKE
       '%delivered%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: forbidden upstream/downstream authority imported';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.is_active
    AND (
      (
        stage.stage_order = 14
        AND stage.stage_key =
            'editing_in_progress'
      )
      OR
      (
        stage.stage_order = 15
        AND stage.stage_key =
            'qc_pending'
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: canonical Stage 14 / 15 catalogue changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_class relation
  JOIN pg_catalog.pg_namespace namespace
    ON namespace.oid =
       relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND (
      relation.relname ILIKE '%qc%'
      OR relation.relname ILIKE '%pixieset%'
      OR relation.relname ILIKE '%delivery%'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 15 validation failed: QC/gallery/delivery persistence is unauthorized';
  END IF;
END
$s11s15_assertions$;
