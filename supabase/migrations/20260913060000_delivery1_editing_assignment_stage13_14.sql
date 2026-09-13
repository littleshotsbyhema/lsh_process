-- =====================================================================
-- Delivery Pipeline 1 of 4 - Editing in Progress
-- Editing assignment evidence + Stage 13 -> 14 gate
--
-- Boundary:
--   * one narrow editing.assign permission;
--   * append-only booking_editing_assignments evidence, keyed by round;
--   * controlled assign_booking_editing(...) RPC;
--   * controlled mark_booking_editing_in_progress(uuid) RPC;
--   * authenticated read containment through canonical booking access;
--   * exact Stage 13 -> 14 advancement only;
--   * strict replay/idempotency;
--   * no Stage 14 -> 15 implementation;
--   * no editing completion, QC, gallery or delivery.
--
-- Deviation from the Sprint 9-13 evidence pattern, deliberate:
--   evidence is keyed (organization_id, booking_id, round) rather than
--   (organization_id, booking_id), because the QC rework loop returns a
--   booking to editing more than once. Round is always derived server-side;
--   it is never supplied by the caller.
-- =====================================================================

-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $dp1_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_editing_assignments') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: editing assignment relation already exists';
  END IF;

  IF to_regprocedure('public.assign_booking_editing(uuid,uuid,text)') IS NOT NULL
     OR to_regprocedure('public.mark_booking_editing_in_progress(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: mutation RPC already exists';
  END IF;

  IF EXISTS (SELECT 1 FROM public.permissions WHERE key = 'editing.assign') THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: editing.assign permission already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.roles') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: canonical relation unavailable';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL
     OR to_regprocedure('public.mark_booking_editing_pending(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (13, 14)
    AND stage_key IN ('editing_pending', 'editing_in_progress')
    AND is_active;

  IF v_count < 2 THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: canonical editing stages unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.roles
  WHERE key IN ('founder', 'studio_manager', 'editor');

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: canonical roles unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 261 THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 precondition failed: expected canonical role-permission count 261, found %',
      v_count;
  END IF;
END
$dp1_preconditions$;

-- =====================================================================
-- Section B - Permission
-- =====================================================================

INSERT INTO public.permissions (
  key, domain, label, description, requires_server_enforcement
)
VALUES (
  'editing.assign',
  'bookings',
  'Assign editing work',
  'Assign a booking editing round to a studio editor and open editing execution.',
  true
);

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN ('founder', 'studio_manager')
  AND permission.key = 'editing.assign';

-- =====================================================================
-- Section C - Editing assignment evidence
-- =====================================================================

CREATE TABLE public.booking_editing_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  round integer NOT NULL,
  editor_member_id uuid NOT NULL,
  assignment_note text,

  assigned_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_editing_assignments_round_chk
    CHECK (round >= 1 AND round <= 50),

  CONSTRAINT booking_editing_assignments_assignment_note_chk
    CHECK (
      assignment_note IS NULL
      OR (
      assignment_note = btrim(assignment_note)
      AND assignment_note <> ''
      AND btrim(
        assignment_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND assignment_note = btrim(assignment_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(assignment_note) <= 500
      AND assignment_note !~ '[[:cntrl:]]'
      AND assignment_note !~* '^(bearer|basic)[[:space:]]+'
      AND assignment_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND assignment_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_editing_assignments_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_editing_assignments_editor_fkey
    FOREIGN KEY (editor_member_id, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_editing_assignments_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_editing_assignments_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_editing_assignments_org_booking_round_key
    UNIQUE (organization_id, booking_id, round),

  CONSTRAINT booking_editing_assignments_id_booking_key
    UNIQUE (id, booking_id)
);

CREATE INDEX booking_editing_assignments_org_assigned_idx
ON public.booking_editing_assignments (organization_id, assigned_at DESC);

CREATE INDEX booking_editing_assignments_booking_round_idx
ON public.booking_editing_assignments (booking_id, round DESC);

CREATE INDEX booking_editing_assignments_editor_idx
ON public.booking_editing_assignments (organization_id, editor_member_id, assigned_at DESC);

CREATE FUNCTION public.lsh_booking_editing_assignment_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking editing assignments evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking editing assignments evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking editing assignments recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking editing assignments actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_editing_assignments_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_editing_assignments
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_editing_assignment_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_editing_assignment_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_editing_assignment_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_editing_assignment_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_editing_assignment_guard() FROM service_role;

ALTER TABLE public.booking_editing_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_editing_assignments FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_assignments FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_assignments FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_assignments FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_assignments FROM service_role;

GRANT SELECT ON TABLE public.booking_editing_assignments TO authenticated;

CREATE POLICY booking_editing_assignments_authenticated_select
ON public.booking_editing_assignments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_editing_assignments.organization_id
      AND booking.id = booking_editing_assignments.booking_id
      AND public.has_permission(
            booking.organization_id, 'booking.read', booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(booking.organization_id, booking.branch_id)
      )
  )
);

-- =====================================================================
-- Section D - Assignment RPC
-- =====================================================================

CREATE FUNCTION public.assign_booking_editing(
  p_booking_id uuid,
  p_editor_member_id uuid,
  p_note text DEFAULT NULL
)
RETURNS public.booking_editing_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assign_editing$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_note text;
  v_round integer;
  v_editor_status public.member_status;
  v_result public.booking_editing_assignments;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'assign_booking_editing: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'assign_booking_editing: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assign_booking_editing: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'assign_booking_editing: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'editing.assign', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'assign_booking_editing: editing.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'assign_booking_editing: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_editor_member_id IS NULL THEN
    RAISE EXCEPTION 'assign_booking_editing: editor_member_id is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT member.status INTO v_editor_status
  FROM public.organization_members member
  WHERE member.id = p_editor_member_id
    AND member.organization_id = v_booking.organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assign_booking_editing: editor must be a member of this organization'
      USING ERRCODE = '22023';
  END IF;

  IF v_editor_status <> 'active'::public.member_status THEN
    RAISE EXCEPTION 'assign_booking_editing: editor must be an active organization member'
      USING ERRCODE = '22023';
  END IF;

  v_note := NULLIF(btrim(COALESCE(p_note, '')), '');

  IF v_note IS NOT NULL
     AND (
       btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_note <> btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_note) > 500
       OR v_note ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_note := NULL;
    ELSE
      RAISE EXCEPTION 'assign_booking_editing: assignment note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'assign_booking_editing: assignment note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'assign_booking_editing: canonical journey state is invalid'
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
    RAISE EXCEPTION 'assign_booking_editing: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 13 AND v_stage.stage_key = 'editing_pending')
    OR
    (v_stage.stage_order = 14 AND v_stage.stage_key = 'editing_in_progress')
  ) THEN
    RAISE EXCEPTION
      'assign_booking_editing: booking must be exactly Editing Pending or Editing in Progress'
      USING ERRCODE = '22023';
  END IF;

  -- Round is derived, never supplied. Concurrent assignment attempts collide
  -- on the (organization_id, booking_id, round) unique constraint.
  SELECT COALESCE(max(assignment.round), 0) + 1 INTO v_round
  FROM public.booking_editing_assignments assignment
  WHERE assignment.organization_id = v_booking.organization_id
    AND assignment.booking_id = v_booking.id;

  IF v_round > 50 THEN
    RAISE EXCEPTION 'assign_booking_editing: editing round limit reached'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_editing_assignments (
    organization_id, booking_id, round, editor_member_id,
    assignment_note, assigned_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_round, p_editor_member_id,
    v_note, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_assigned',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'editing_round', v_round,
      'editor_member_id', p_editor_member_id
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'editing_assignment_id', v_result.id,
      'editing_round', v_round,
      'editor_member_id', p_editor_member_id,
      'journey_stage', v_stage.stage_key,
      'note_present', (v_note IS NOT NULL)
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$assign_editing$;

REVOKE ALL ON FUNCTION public.assign_booking_editing(uuid,uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_booking_editing(uuid,uuid,text) FROM anon;
REVOKE ALL ON FUNCTION public.assign_booking_editing(uuid,uuid,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.assign_booking_editing(uuid,uuid,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.assign_booking_editing(uuid,uuid,text) TO authenticated;

COMMENT ON FUNCTION public.assign_booking_editing(uuid,uuid,text) IS
  'Assigns a booking editing round to an active organization member. Round is derived server-side. Does not advance the booking journey stage.';

-- =====================================================================
-- Section E - Stage 13 -> 14 gate
-- =====================================================================

CREATE FUNCTION public.mark_booking_editing_in_progress(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $gate_editing_in_progress$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_assignment_count integer;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: canonical journey state is invalid'
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
    RAISE EXCEPTION 'mark_booking_editing_in_progress: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 13 AND v_stage.stage_key = 'editing_pending')
    OR
    (v_stage.stage_order = 14 AND v_stage.stage_key = 'editing_in_progress')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_in_progress: booking must be exactly Editing Pending or Editing in Progress replay'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_assignment_count
  FROM public.booking_editing_assignments assignment
  WHERE assignment.organization_id = v_booking.organization_id
    AND assignment.booking_id = v_booking.id;

  IF v_assignment_count < 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_in_progress: booking requires a recorded editing assignment'
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
    AND transition_row.transition_key = 'editing_pending'
    AND source_stage.stage_order = 12
    AND source_stage.stage_key = 'selection_pending'
    AND destination_stage.stage_order = 13
    AND destination_stage.stage_key = 'editing_pending';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: canonical Editing Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 14 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'editing_in_progress'
      AND destination_stage.stage_order = 14
      AND destination_stage.stage_key = 'editing_in_progress';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_editing_in_progress: canonical Editing in Progress transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 14
    AND stage.stage_key = 'editing_in_progress'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_in_progress: canonical destination stage is unavailable'
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
    'editing_in_progress', v_transitioned_at, v_actor
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
    RAISE EXCEPTION 'mark_booking_editing_in_progress: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_in_progress',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage', v_stage.stage_key,
      'journey_version', v_state.version
    ),
    jsonb_build_object(
      'journey_stage', 'editing_in_progress',
      'journey_version', v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'editing_in_progress',
      'editing_assignment_count', v_assignment_count,
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$gate_editing_in_progress$;

REVOKE ALL ON FUNCTION public.mark_booking_editing_in_progress(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_editing_in_progress(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_editing_in_progress(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_editing_in_progress(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_editing_in_progress(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_editing_in_progress(uuid) IS
  'Advances a booking from Editing Pending (13) to Editing in Progress (14). Requires at least one recorded editing assignment. Idempotent on replay.';

-- =====================================================================
-- Section F - Postconditions
-- =====================================================================

DO $dp1_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_editing_assignments') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: editing assignment relation missing';
  END IF;

  IF to_regprocedure('public.assign_booking_editing(uuid,uuid,text)') IS NULL
     OR to_regprocedure('public.mark_booking_editing_in_progress(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: required mutation RPC missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.permissions permission
  WHERE permission.key = 'editing.assign'
    AND permission.domain = 'bookings'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: editing.assign permission invalid';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission ON permission.id = role_permission.permission_id
  WHERE permission.key = 'editing.assign';

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: editing.assign role boundary invalid';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 263 THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: expected role-permission count 263, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname = 'booking_editing_assignments'
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: row level security not forced';
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_editing_in_progress(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_editing_in_progress(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.assign_booking_editing(uuid,uuid,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.assign_booking_editing(uuid,uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: privileged execute must be denied';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.mark_booking_editing_in_progress(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.assign_booking_editing(uuid,uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: authenticated execute missing';
  END IF;

  IF has_table_privilege('authenticated', 'public.booking_editing_assignments', 'INSERT')
     OR has_table_privilege('authenticated', 'public.booking_editing_assignments', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.booking_editing_assignments', 'DELETE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 1 postcondition failed: evidence table must be read-only to authenticated';
  END IF;
END
$dp1_postconditions$;
