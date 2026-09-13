-- =====================================================================
-- Delivery Pipeline 2 of 4 - QC Pending
-- Editing completion evidence + Stage 14 -> 15 gate
--
-- Boundary:
--   * one narrow editing.complete permission;
--   * append-only booking_editing_completions evidence, keyed by round;
--   * controlled record_booking_editing_completion(...) RPC;
--   * controlled mark_booking_qc_pending(uuid) RPC;
--   * exact Stage 14 -> 15 advancement only;
--   * strict replay/idempotency;
--   * no QC review, gallery or delivery implementation.
--
-- Deviations from the Sprint 9-13 gate pattern, deliberate:
--   1. evidence keyed (organization_id, booking_id, round), because the QC
--      rework loop returns a booking to editing more than once. Round is
--      derived server-side and never supplied by the caller.
--   2. mark_booking_qc_pending authorizes on editing.complete rather than
--      booking.stage.advance, so a studio editor can move their own finished
--      work to QC without holding the generic journey-advance permission.
--      founder and studio_manager hold editing.complete as well, so no
--      journey authority is lost.
--
-- One completion may be recorded per entry into Stage 14. Entries are counted
-- from canonical stage transitions, so the initial pass and every rework pass
-- each admit exactly one completion.
-- =====================================================================

-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $dp2_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_editing_completions') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 precondition failed: editing completion relation already exists';
  END IF;

  IF to_regprocedure('public.record_booking_editing_completion(uuid,integer,text)') IS NOT NULL
     OR to_regprocedure('public.mark_booking_qc_pending(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 precondition failed: mutation RPC already exists';
  END IF;

  IF EXISTS (SELECT 1 FROM public.permissions WHERE key = 'editing.complete') THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 precondition failed: editing.complete permission already exists';
  END IF;

  IF to_regclass('public.booking_editing_assignments') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 precondition failed: editing assignment foundation unavailable';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL
     OR to_regprocedure('public.mark_booking_editing_in_progress(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (14, 15)
    AND stage_key IN ('editing_in_progress', 'qc_pending')
    AND is_active;

  IF v_count < 2 THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 precondition failed: canonical QC stages unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 263 THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 precondition failed: expected canonical role-permission count 263, found %',
      v_count;
  END IF;
END
$dp2_preconditions$;

-- =====================================================================
-- Section B - Permission
-- =====================================================================

INSERT INTO public.permissions (
  key, domain, label, description, requires_server_enforcement
)
VALUES (
  'editing.complete',
  'bookings',
  'Complete editing round',
  'Record immutable evidence that a booking editing round is finished and move it to quality control.',
  true
);

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN ('founder', 'studio_manager', 'editor')
  AND permission.key = 'editing.complete';

-- =====================================================================
-- Section C - Editing completion evidence
-- =====================================================================

CREATE TABLE public.booking_editing_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  round integer NOT NULL,
  edited_image_count integer NOT NULL,
  completion_note text,

  completed_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_editing_completions_round_chk
    CHECK (round >= 1 AND round <= 50),

  CONSTRAINT booking_editing_completions_edited_image_count_chk
    CHECK (edited_image_count >= 1 AND edited_image_count <= 100000),

  CONSTRAINT booking_editing_completions_completion_note_chk
    CHECK (
      completion_note IS NULL
      OR (
      completion_note = btrim(completion_note)
      AND completion_note <> ''
      AND btrim(
        completion_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND completion_note = btrim(completion_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(completion_note) <= 500
      AND completion_note !~ '[[:cntrl:]]'
      AND completion_note !~* '^(bearer|basic)[[:space:]]+'
      AND completion_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND completion_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_editing_completions_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_editing_completions_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_editing_completions_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_editing_completions_org_booking_round_key
    UNIQUE (organization_id, booking_id, round),

  CONSTRAINT booking_editing_completions_id_booking_key
    UNIQUE (id, booking_id)
);

CREATE INDEX booking_editing_completions_org_completed_idx
ON public.booking_editing_completions (organization_id, completed_at DESC);

CREATE INDEX booking_editing_completions_booking_round_idx
ON public.booking_editing_completions (booking_id, round DESC);

CREATE FUNCTION public.lsh_booking_editing_completion_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking editing completions evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking editing completions evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking editing completions recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking editing completions actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_editing_completions_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_editing_completions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_editing_completion_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_editing_completion_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_editing_completion_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_editing_completion_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_editing_completion_guard() FROM service_role;

ALTER TABLE public.booking_editing_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_editing_completions FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_completions FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_completions FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_completions FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_editing_completions FROM service_role;

GRANT SELECT ON TABLE public.booking_editing_completions TO authenticated;

CREATE POLICY booking_editing_completions_authenticated_select
ON public.booking_editing_completions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_editing_completions.organization_id
      AND booking.id = booking_editing_completions.booking_id
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
-- Section D - Editing completion RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_editing_completion(
  p_booking_id uuid,
  p_edited_image_count integer,
  p_note text DEFAULT NULL
)
RETURNS public.booking_editing_completions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_editing_completion$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_note text;
  v_round integer;
  v_completion_count integer;
  v_entry_count integer;
  v_result public.booking_editing_completions;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_editing_completion: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_editing_completion: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_editing_completion: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_editing_completion: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'editing.complete', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_editing_completion: editing.complete permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_editing_completion: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_edited_image_count IS NULL THEN
    RAISE EXCEPTION 'record_booking_editing_completion: edited_image_count is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_edited_image_count < 1 OR p_edited_image_count > 100000 THEN
    RAISE EXCEPTION 'record_booking_editing_completion: edited_image_count is out of range'
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
      RAISE EXCEPTION 'record_booking_editing_completion: completion note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_editing_completion: completion note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_editing_completion: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_editing_completion: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (v_stage.stage_order = 14 AND v_stage.stage_key = 'editing_in_progress') THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: booking must be exactly Editing in Progress'
      USING ERRCODE = '22023';
  END IF;

  -- One completion is admitted per entry into Stage 14. Entries are the
  -- initial advancement plus every recorded rework return.
  SELECT count(*) INTO v_entry_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key = 'editing_in_progress';

  IF v_entry_count < 1 THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: canonical Editing in Progress transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_completion_count
  FROM public.booking_editing_completions completion
  WHERE completion.organization_id = v_booking.organization_id
    AND completion.booking_id = v_booking.id;

  IF v_completion_count >= v_entry_count THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: this editing round is already recorded as complete'
      USING ERRCODE = '22023';
  END IF;

  v_round := v_completion_count + 1;

  INSERT INTO public.booking_editing_completions (
    organization_id, booking_id, round, edited_image_count,
    completion_note, completed_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_round, p_edited_image_count,
    v_note, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_completed',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object('editing_round_complete', false),
    jsonb_build_object(
      'editing_round_complete', true,
      'editing_round', v_round,
      'edited_image_count', p_edited_image_count
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'editing_completion_id', v_result.id,
      'editing_round', v_round,
      'edited_image_count', p_edited_image_count,
      'note_present', (v_note IS NOT NULL)
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$record_editing_completion$;

REVOKE ALL ON FUNCTION public.record_booking_editing_completion(uuid,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_editing_completion(uuid,integer,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_editing_completion(uuid,integer,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_editing_completion(uuid,integer,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_editing_completion(uuid,integer,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_editing_completion(uuid,integer,text) IS
  'Records immutable evidence that one editing round is finished. One completion is admitted per entry into Stage 14. Does not advance the booking journey stage.';

-- =====================================================================
-- Section E - Stage 14 -> 15 gate
-- =====================================================================

CREATE FUNCTION public.mark_booking_qc_pending(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $gate_qc_pending$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_completion_count integer;
  v_entry_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'editing.complete', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: editing.complete permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: canonical journey state is invalid'
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
    RAISE EXCEPTION 'mark_booking_qc_pending: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 14 AND v_stage.stage_key = 'editing_in_progress')
    OR
    (v_stage.stage_order = 15 AND v_stage.stage_key = 'qc_pending')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking must be exactly Editing in Progress or QC Pending replay'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_entry_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key = 'editing_in_progress';

  SELECT count(*) INTO v_completion_count
  FROM public.booking_editing_completions completion
  WHERE completion.organization_id = v_booking.organization_id
    AND completion.booking_id = v_booking.id;

  IF v_stage.stage_order = 15 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'qc_pending'
      AND destination_stage.stage_order = 15
      AND destination_stage.stage_key = 'qc_pending';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_qc_pending: canonical QC Pending transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  IF v_completion_count < v_entry_count THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: booking requires a recorded editing completion for this round'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 15
    AND stage.stage_key = 'qc_pending'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_qc_pending: canonical destination stage is unavailable'
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
    'qc_pending', v_transitioned_at, v_actor
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
    RAISE EXCEPTION 'mark_booking_qc_pending: journey state changed during advancement'
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
      'journey_stage', v_stage.stage_key,
      'journey_version', v_state.version
    ),
    jsonb_build_object(
      'journey_stage', 'qc_pending',
      'journey_version', v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'qc_pending',
      'editing_round', v_completion_count,
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$gate_qc_pending$;

REVOKE ALL ON FUNCTION public.mark_booking_qc_pending(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_qc_pending(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_qc_pending(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_qc_pending(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_qc_pending(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_qc_pending(uuid) IS
  'Advances a booking from Editing in Progress (14) to QC Pending (15). Requires a recorded editing completion for the current round. Authorized on editing.complete so an editor can submit their own work. Idempotent on replay.';

-- =====================================================================
-- Section F - Postconditions
-- =====================================================================

DO $dp2_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_editing_completions') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 postcondition failed: editing completion relation missing';
  END IF;

  IF to_regprocedure('public.record_booking_editing_completion(uuid,integer,text)') IS NULL
     OR to_regprocedure('public.mark_booking_qc_pending(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 postcondition failed: required mutation RPC missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission ON permission.id = role_permission.permission_id
  WHERE permission.key = 'editing.complete';

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 postcondition failed: editing.complete role boundary invalid';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 266 THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 postcondition failed: expected role-permission count 266, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname = 'booking_editing_completions'
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 postcondition failed: row level security not forced';
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_qc_pending(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_qc_pending(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.record_booking_editing_completion(uuid,integer,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.record_booking_editing_completion(uuid,integer,text)', 'EXECUTE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 postcondition failed: privileged execute must be denied';
  END IF;

  IF has_table_privilege('authenticated', 'public.booking_editing_completions', 'INSERT')
     OR has_table_privilege('authenticated', 'public.booking_editing_completions', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.booking_editing_completions', 'DELETE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 2 postcondition failed: evidence table must be read-only to authenticated';
  END IF;
END
$dp2_postconditions$;
