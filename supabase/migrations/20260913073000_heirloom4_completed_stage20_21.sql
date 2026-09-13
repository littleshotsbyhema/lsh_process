-- =====================================================================
-- Heirloom Pipeline 4 of 4 - Completed / Relationship Active
--
-- Boundary:
--   * controlled mark_booking_completed(uuid) RPC;
--   * exact Stage 20 -> 21 advancement only;
--   * no new permission - completion uses booking.stage.advance;
--   * no new evidence relation;
--   * terminal stage: no onward gate is defined.
--
-- Stage 21 closes the booking without closing the relationship. The
-- milestone plan recorded at Stage 20 stays live and is what brings the
-- family back. Nothing here archives or deactivates the family record.
-- =====================================================================

DO $hp4_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regprocedure('public.mark_booking_completed(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'Heirloom pipeline 4 precondition failed: mutation RPC already exists';
  END IF;

  IF to_regprocedure('public.mark_booking_milestone_follow_up(uuid)') IS NULL
     OR to_regclass('public.booking_milestone_plans') IS NULL
     OR to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 4 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (20, 21)
    AND stage_key IN ('milestone_follow_up', 'completed_relationship_active')
    AND is_active;
  IF v_count < 2 THEN
    RAISE EXCEPTION 'Heirloom pipeline 4 precondition failed: canonical stages unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 281 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 4 precondition failed: expected canonical role-permission count 281, found %',
      v_count;
  END IF;
END
$hp4_preconditions$;

CREATE FUNCTION public.mark_booking_completed(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $gate_completed$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_plan public.booking_milestone_plans;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_completed: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_completed: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_completed: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_completed: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_completed: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_completed: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_completed: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_completed: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 20 AND v_stage.stage_key = 'milestone_follow_up')
    OR
    (v_stage.stage_order = 21 AND v_stage.stage_key = 'completed_relationship_active')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_completed: booking must be exactly Milestone Follow-Up or Completed replay'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_inbound_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id = transition_row.organization_id
   AND source_stage.id = transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND transition_row.transition_key = 'milestone_follow_up'
    AND source_stage.stage_order = 19
    AND source_stage.stage_key = 'review_requested'
    AND destination_stage.stage_order = 20
    AND destination_stage.stage_key = 'milestone_follow_up';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_completed: canonical Milestone Follow-Up transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 21 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'completed_relationship_active'
      AND destination_stage.stage_order = 21
      AND destination_stage.stage_key = 'completed_relationship_active';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_completed: canonical Completed transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  SELECT plan.* INTO v_plan
  FROM public.booking_milestone_plans plan
  WHERE plan.organization_id = v_booking.organization_id
    AND plan.booking_id = v_booking.id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_completed: booking requires a recorded milestone plan before completion'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 21
    AND stage.stage_key = 'completed_relationship_active'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_completed: canonical destination stage is unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  INSERT INTO public.booking_stage_transitions (
    organization_id, booking_id, from_stage_id, to_stage_id,
    transition_key, transitioned_at, transitioned_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id,
    v_state.current_stage_id, v_destination_stage_id,
    'completed_relationship_active', v_transitioned_at, v_actor
  );

  UPDATE public.booking_journey_states state
  SET current_stage_id = v_destination_stage_id,
      stage_entered_at = v_transitioned_at,
      version = state.version + 1,
      updated_at = v_transitioned_at,
      updated_by = v_actor
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
    AND state.current_stage_id = v_state.current_stage_id
    AND state.version = v_state.version;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  IF v_updated_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_completed: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.completed', 'booking', v_booking.id, false,
    jsonb_build_object('journey_stage', v_stage.stage_key, 'journey_version', v_state.version),
    jsonb_build_object('journey_stage', 'completed_relationship_active', 'journey_version', v_state.version + 1),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'completed_relationship_active',
      'milestone_plan_id', v_plan.id,
      'next_session_category', v_plan.next_session_category,
      'next_due_on', v_plan.due_on,
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application', NULL
  );

  RETURN v_booking;
END;
$gate_completed$;

REVOKE ALL ON FUNCTION public.mark_booking_completed(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_completed(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_completed(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_completed(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_completed(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_completed(uuid) IS
  'Advances a booking from Milestone Follow-Up (20) to Completed / Relationship Active (21), the terminal stage. Requires a recorded milestone plan. Closes the booking, not the family relationship. Idempotent on replay.';

DO $hp4_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regprocedure('public.mark_booking_completed(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Heirloom pipeline 4 postcondition failed: gate RPC missing';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 281 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 4 postcondition failed: role-permission count must be unchanged at 281, found %',
      v_count;
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_completed(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_completed(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Heirloom pipeline 4 postcondition failed: privileged execute must be denied';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.mark_booking_completed(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Heirloom pipeline 4 postcondition failed: authenticated execute missing';
  END IF;
END
$hp4_postconditions$;
