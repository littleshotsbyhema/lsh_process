-- =====================================================================
-- Parallel video editing track
-- =====================================================================
--
-- Photo editing and video editing run side by side rather than in
-- sequence: the same booking can have its stills finished while the film
-- is still being cut. The journey stage continues to follow the photo
-- work, and video is tracked alongside it.
--
-- Design notes:
--   * append-only, one row per state change, keyed by round - the full
--     history of the video track is preserved and immutable;
--   * three states: not_applicable, in_progress, complete;
--   * a booking with NO video row is photo-only and is never asked about
--     video, so the track adds no friction to the common case;
--   * QC admission (14 -> 15) blocks only while the latest video state is
--     in_progress. Video is a gate on QC, never on anything earlier.
--
-- Permission: editing.complete, the same one an editor already holds to
-- submit finished photo work.
-- =====================================================================

DO $precondition$
BEGIN
  IF to_regclass('public.bookings') IS NULL THEN
    RAISE EXCEPTION 'precondition: bookings is missing';
  END IF;

  IF to_regprocedure('public.mark_booking_qc_pending(uuid)') IS NULL THEN
    RAISE EXCEPTION 'precondition: mark_booking_qc_pending is missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'editing.complete') THEN
    RAISE EXCEPTION 'precondition: editing.complete permission is missing';
  END IF;
END;
$precondition$;

-- =====================================================================
-- Section A - Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.booking_video_work (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL
    REFERENCES public.organizations (id) ON DELETE CASCADE,
  booking_id uuid NOT NULL
    REFERENCES public.bookings (id) ON DELETE CASCADE,
  round integer NOT NULL,
  state text NOT NULL,
  video_note text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_video_work_round_key UNIQUE (organization_id, booking_id, round),

  CONSTRAINT booking_video_work_round_chk
    CHECK (round >= 1 AND round <= 50),

  CONSTRAINT booking_video_work_state_chk
    CHECK (state IN ('not_applicable', 'in_progress', 'complete')),

  CONSTRAINT booking_video_work_note_chk
    CHECK (
      video_note IS NULL
      OR (
        video_note = btrim(video_note)
        AND video_note <> ''
        AND char_length(video_note) <= 500
        AND video_note !~ '[[:cntrl:]]'
      )
    )
);

CREATE INDEX IF NOT EXISTS booking_video_work_booking_idx
  ON public.booking_video_work (organization_id, booking_id, round DESC);

-- =====================================================================
-- Section B - Immutability guard
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_booking_video_work_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking video work evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION 'booking video work evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION 'booking video work recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking video work actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS lsh_booking_video_work_guard ON public.booking_video_work;

CREATE TRIGGER lsh_booking_video_work_guard
  BEFORE INSERT OR UPDATE OR DELETE ON public.booking_video_work
  FOR EACH ROW EXECUTE FUNCTION public.lsh_booking_video_work_guard();

-- =====================================================================
-- Section C - RLS
-- =====================================================================

ALTER TABLE public.booking_video_work ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_video_work FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS booking_video_work_authenticated_select ON public.booking_video_work;

CREATE POLICY booking_video_work_authenticated_select
  ON public.booking_video_work
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.bookings booking
      WHERE booking.organization_id = booking_video_work.organization_id
        AND booking.id = booking_video_work.booking_id
        AND public.has_permission(booking.organization_id, 'booking.read', booking.branch_id)
        AND (booking.branch_id IS NULL OR public.has_branch_scope(booking.organization_id, booking.branch_id))
    )
  );

REVOKE ALL ON TABLE public.booking_video_work FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.booking_video_work TO authenticated;

-- =====================================================================
-- Section D - Evidence RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.record_booking_video_state(
  p_booking_id uuid,
  p_state text,
  p_note text DEFAULT NULL
)
RETURNS public.booking_video_work
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_video$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state_count integer;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_value text;
  v_note text;
  v_prior text;
  v_round integer;
  v_result public.booking_video_work;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_video_state: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_video_state: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_video_state: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_video_state: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'editing.complete', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_video_state: editing.complete permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_video_state: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  v_value := btrim(COALESCE(p_state, ''));

  IF v_value NOT IN ('not_applicable', 'in_progress', 'complete') THEN
    RAISE EXCEPTION 'record_booking_video_state: state is invalid' USING ERRCODE = '22023';
  END IF;

  v_note := NULLIF(btrim(COALESCE(p_note, '')), '');

  IF v_note IS NOT NULL
     AND (
       char_length(v_note) > 500
       OR v_note ~ '[[:cntrl:]]'
     ) THEN
    RAISE EXCEPTION 'record_booking_video_state: video note is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_video_state: video note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_video_state: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_video_state: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- The video track is open across the editing half of the journey: from
  -- the moment the job is queued for editing until QC has it.
  IF NOT (v_stage.stage_order BETWEEN 13 AND 15) THEN
    RAISE EXCEPTION
      'record_booking_video_state: booking must be in the editing stages to record video progress'
      USING ERRCODE = '22023';
  END IF;

  SELECT video.state INTO v_prior
  FROM public.booking_video_work video
  WHERE video.organization_id = v_booking.organization_id
    AND video.booking_id = v_booking.id
  ORDER BY video.round DESC
  LIMIT 1;

  IF v_prior IS NOT DISTINCT FROM v_value THEN
    RAISE EXCEPTION 'record_booking_video_state: video is already in that state'
      USING ERRCODE = '23505';
  END IF;

  SELECT COALESCE(max(video.round), 0) + 1 INTO v_round
  FROM public.booking_video_work video
  WHERE video.organization_id = v_booking.organization_id
    AND video.booking_id = v_booking.id;

  IF v_round > 50 THEN
    RAISE EXCEPTION 'record_booking_video_state: video revision limit reached'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_video_work (
    organization_id, booking_id, round, state, video_note,
    recorded_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_round, v_value, v_note,
    now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.video_state_recorded',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object('video_state', v_prior),
    jsonb_build_object('video_state', v_value),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'video_work_id', v_result.id,
      'video_round', v_round,
      'prior_state', v_prior,
      'state', v_value,
      'note_present', (v_note IS NOT NULL)
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$record_video$;

REVOKE ALL ON FUNCTION public.record_booking_video_state(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_booking_video_state(uuid, text, text) TO authenticated;

-- =====================================================================
-- Section E - QC gate: wait for the video track
-- =====================================================================

DROP FUNCTION IF EXISTS public.mark_booking_qc_pending(uuid);

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

  -- Parallel video track: photo editing and video editing advance
  -- independently, and QC reviews the whole job. A booking with an open
  -- video track therefore cannot reach QC until video is finished or
  -- explicitly marked not applicable.
  --
  -- A booking with no video row at all is photo-only and passes freely -
  -- the track costs nothing until someone opens it.
  IF EXISTS (
    SELECT 1
    FROM public.booking_video_work video
    WHERE video.organization_id = v_booking.organization_id
      AND video.booking_id = v_booking.id
      AND video.round = (
        SELECT max(latest.round)
        FROM public.booking_video_work latest
        WHERE latest.organization_id = v_booking.organization_id
          AND latest.booking_id = v_booking.id
      )
      AND video.state = 'in_progress'
  ) THEN
    RAISE EXCEPTION
      'mark_booking_qc_pending: video editing is still in progress for this booking'
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
GRANT EXECUTE ON FUNCTION public.mark_booking_qc_pending(uuid) TO authenticated;

-- =====================================================================
-- Section F - Postconditions
-- =====================================================================

DO $postcondition$
DECLARE
  v_rls boolean;
  v_force boolean;
  v_qc_src text;
BEGIN
  IF to_regclass('public.booking_video_work') IS NULL THEN
    RAISE EXCEPTION 'postcondition: booking_video_work was not created';
  END IF;

  SELECT relrowsecurity, relforcerowsecurity INTO v_rls, v_force
  FROM pg_class WHERE oid = 'public.booking_video_work'::regclass;

  IF NOT v_rls OR NOT v_force THEN
    RAISE EXCEPTION 'postcondition: booking_video_work row level security is not forced';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.booking_video_work'::regclass
      AND tgname = 'lsh_booking_video_work_guard'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'postcondition: booking_video_work immutability guard is missing';
  END IF;

  IF to_regprocedure('public.record_booking_video_state(uuid, text, text)') IS NULL THEN
    RAISE EXCEPTION 'postcondition: record_booking_video_state was not created';
  END IF;

  SELECT prosrc INTO v_qc_src FROM pg_proc
  WHERE oid = to_regprocedure('public.mark_booking_qc_pending(uuid)');

  IF v_qc_src NOT LIKE '%video editing is still in progress for this booking%' THEN
    RAISE EXCEPTION 'postcondition: QC video gate is missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
    WHERE table_schema = 'public'
      AND table_name = 'booking_video_work'
      AND grantee = 'authenticated'
      AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
  ) THEN
    RAISE EXCEPTION 'postcondition: booking_video_work must not grant direct writes';
  END IF;
END;
$postcondition$;
