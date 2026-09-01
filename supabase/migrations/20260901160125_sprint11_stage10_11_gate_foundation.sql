-- =====================================================================
-- Sprint 11 — Shoot Completion
-- Slice 2 — Controlled Stage 10 -> 11 / shoot_completed Advancement Gate
--
-- Boundary:
--   * terminalize shoot-schedule inserts after canonical completion;
--   * one controlled mark_booking_shoot_completed(uuid) RPC;
--   * consume Slice 1 completion evidence without rewriting it;
--   * exact Stage 10 -> 11 advancement only;
--   * strict Stage 11 replay;
--   * no new permission or role grant;
--   * no Stage 11 -> 12 implementation;
--   * no application UI.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11_slice2_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_shoot_completed(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 precondition failed: mark_booking_shoot_completed already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.booking_shoot_schedules') IS NULL
     OR to_regclass('public.booking_shoot_completions') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 precondition failed: required canonical relation missing';
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
       'public.lsh_booking_shoot_schedule_guard()'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key = 'shoot.complete'
    AND permission.domain = 'bookings'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 precondition failed: canonical shoot.complete permission unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.is_active
    AND (
      (
        stage.stage_order = 10
        AND stage.stage_key = 'shoot_scheduled'
      )
      OR
      (
        stage.stage_order = 11
        AND stage.stage_key = 'shoot_completed'
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 precondition failed: canonical Stage 10 / Stage 11 catalogue unavailable';
  END IF;
END
$s11_slice2_preconditions$;

-- =====================================================================
-- Section B — Completion terminalizes future schedule evidence
--
-- Existing immutable schedule history remains untouched.
-- Exact reschedule replay remains valid because the existing RPC returns
-- before attempting an INSERT.
--
-- Booking locking here also preserves the booking as the synchronization
-- root for direct trigger-enforced schedule insertion.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_booking_shoot_schedule_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_latest public.booking_shoot_schedules;
  v_current_actor uuid;
BEGIN
  -- Historical schedule evidence is never rewritten or deleted.
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking shoot schedule evidence is append-only and immutable';
  END IF;

  -- Authenticated evidence must identify the same active member
  -- represented by the current authenticated user.
  IF auth.uid() IS NOT NULL THEN
    v_current_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_current_actor IS NULL
       OR NEW.recorded_by <> v_current_actor THEN
      RAISE EXCEPTION
        'booking shoot schedule actor must be the current active organization member';
    END IF;
  END IF;

  -- Serialize schedule insertion against canonical completion recording.
  PERFORM booking.id
  FROM public.bookings booking
  WHERE booking.organization_id =
        NEW.organization_id
    AND booking.id =
        NEW.booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking shoot schedule requires an existing booking';
  END IF;

  -- Canonical completion evidence terminalizes scheduling.
  --
  -- This does not modify historical schedule evidence and does not
  -- manufacture a completion-to-schedule binding.
  IF EXISTS (
    SELECT 1
    FROM public.booking_shoot_completions completion
    WHERE completion.organization_id =
          NEW.organization_id
      AND completion.booking_id =
          NEW.booking_id
  ) THEN
    RAISE EXCEPTION
      'booking shoot schedule cannot change after canonical shoot completion evidence exists'
      USING ERRCODE = '22023';
  END IF;

  -- Resolve the current immutable schedule tip for this booking.
  SELECT schedule.*
  INTO v_latest
  FROM public.booking_shoot_schedules schedule
  WHERE schedule.organization_id =
        NEW.organization_id
    AND schedule.booking_id =
        NEW.booking_id
  ORDER BY
    schedule.schedule_version DESC
  LIMIT 1;

  -- First schedule evidence must always be an unreserved proposal.
  IF NOT FOUND THEN
    IF NEW.schedule_version <> 1
       OR NEW.predecessor_schedule_id IS NOT NULL
       OR NEW.schedule_state <> 'proposed'
       OR NEW.reschedule_reason IS NOT NULL THEN
      RAISE EXCEPTION
        'initial booking shoot schedule must be proposal version 1 without predecessor or reschedule reason';
    END IF;

    RETURN NEW;
  END IF;

  -- Every later row must extend the exact current tip by one version.
  IF NEW.schedule_version <>
       v_latest.schedule_version + 1 THEN
    RAISE EXCEPTION
      'booking shoot schedule version must extend the current schedule tip by exactly one';
  END IF;

  IF NEW.predecessor_schedule_id
       IS DISTINCT FROM
         v_latest.id THEN
    RAISE EXCEPTION
      'booking shoot schedule predecessor must be the current schedule tip';
  END IF;

  IF NEW.recorded_at <
       v_latest.recorded_at THEN
    RAISE EXCEPTION
      'booking shoot schedule recorded_at cannot precede its predecessor';
  END IF;

  -- A reserved shoot can never become merely proposed again.
  IF v_latest.schedule_state = 'reserved'
     AND NEW.schedule_state <> 'reserved' THEN
    RAISE EXCEPTION
      'reserved booking shoot schedule cannot return to proposed state';
  END IF;

  -- Reschedule reasons belong only to authoritative post-confirmation
  -- reserved -> reserved replacements.
  IF v_latest.schedule_state = 'reserved'
     AND NEW.schedule_state = 'reserved' THEN
    IF NEW.reschedule_reason IS NULL THEN
      RAISE EXCEPTION
        'reserved booking shoot reschedule requires a reason';
    END IF;
  ELSE
    IF NEW.reschedule_reason IS NOT NULL THEN
      RAISE EXCEPTION
        'reschedule reason is allowed only for reserved booking shoot reschedules';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- =====================================================================
-- Section C — Controlled Stage 10 -> 11 operation
-- =====================================================================

CREATE FUNCTION public.mark_booking_shoot_completed(
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
  v_schedule public.booking_shoot_schedules;

  v_actor uuid;

  v_state_count integer := 0;
  v_completion_count integer := 0;
  v_replay_transition_count integer := 0;
  v_updated_count integer := 0;

  v_completed_stage_id uuid;
  v_transitioned_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: authenticated actor required'
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
      'mark_booking_shoot_completed: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active member + canonical journey-advancement capability.
  -- shoot.complete is deliberately not required here.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking branch scope required'
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
      'mark_booking_shoot_completed: booking must have exactly one current journey state'
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
      'mark_booking_shoot_completed: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Strict canonical Stage 11 replay.
  --
  -- Replay consumes immutable completion evidence and exact transition
  -- history only. It does not re-evaluate mutable Stage 9 readiness.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order = 11
     AND v_stage.stage_key = 'shoot_completed' THEN

    SELECT count(*)
    INTO v_completion_count
    FROM public.booking_shoot_completions completion
    WHERE completion.organization_id =
          v_booking.organization_id
      AND completion.booking_id =
          v_booking.id;

    IF v_completion_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_shoot_completed: Shoot Completed replay requires exactly one canonical completion row'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT completion.*
    INTO v_completion
    FROM public.booking_shoot_completions completion
    WHERE completion.organization_id =
          v_booking.organization_id
      AND completion.booking_id =
          v_booking.id
    FOR UPDATE;

    SELECT count(*)
    INTO v_replay_transition_count
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

    IF v_replay_transition_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_shoot_completed: Shoot Completed replay history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  -- ---------------------------------------------------------------
  -- First advancement must start at exact canonical Stage 10.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order <> 10
     OR v_stage.stage_key <>
          'shoot_scheduled' THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking must be exactly Shoot Scheduled'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: exactly one immutable Slice 1 completion row.
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
      'mark_booking_shoot_completed: exactly one canonical shoot completion row required'
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
  -- Lock order 4: stable authoritative schedule tip.
  -- ---------------------------------------------------------------

  SELECT schedule.*
  INTO v_schedule
  FROM public.booking_shoot_schedules schedule
  WHERE schedule.organization_id =
        v_booking.organization_id
    AND schedule.booking_id =
        v_booking.id
  ORDER BY
    schedule.schedule_version DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND
     OR v_schedule.schedule_state <>
          'reserved' THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: current authoritative reserved shoot schedule required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve explicit canonical Stage 11 destination.
  -- ---------------------------------------------------------------

  SELECT stage.id
  INTO v_completed_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.stage_order = 11
    AND stage.stage_key =
        'shoot_completed'
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: canonical Shoot Completed stage unavailable'
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
    v_completed_stage_id,
    'shoot_completed',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Optimistic exact-state/version advancement.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_completed_stage_id,
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
      'mark_booking_shoot_completed: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- One structural non-sensitive audit event.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.shoot_completed',
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
        'shoot_completed',
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
        'shoot_completed',
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
-- Section D — RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM anon;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.mark_booking_shoot_completed(uuid)
TO authenticated;

COMMENT ON FUNCTION public.mark_booking_shoot_completed(uuid) IS
  'Advance one authorized booking from canonical Stage 10 Shoot Scheduled to Stage 11 Shoot Completed only after immutable canonical shoot-completion evidence exists.';

-- =====================================================================
-- Section E — Migration assertions
-- =====================================================================

DO $s11_slice2_assertions$
DECLARE
  v_count integer;
  v_guard_definition text;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_shoot_completed(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 validation failed: Stage 10 -> 11 RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc procedure
  JOIN pg_namespace namespace
    ON namespace.oid =
       procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname =
        'mark_booking_shoot_completed'
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
      'Sprint 11 Slice 2 validation failed: Stage 10 -> 11 RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.mark_booking_shoot_completed(uuid)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 validation failed: authenticated EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.mark_booking_shoot_completed(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 validation failed: anon EXECUTE must be denied';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.mark_booking_shoot_completed(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 validation failed: service_role EXECUTE must remain unavailable';
  END IF;

  SELECT pg_get_functiondef(
           'public.lsh_booking_shoot_schedule_guard()'::regprocedure
         )
  INTO v_guard_definition;

  IF position(
       'booking_shoot_completions'
       IN v_guard_definition
     ) = 0
     OR position(
       'cannot change after canonical shoot completion evidence exists'
       IN v_guard_definition
     ) = 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 validation failed: completion-terminal schedule guard unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  WHERE permission.key =
        'shoot.complete';

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 2 validation failed: shoot.complete grant boundary changed unexpectedly';
  END IF;
END
$s11_slice2_assertions$;
