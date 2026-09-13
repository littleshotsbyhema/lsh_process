-- =====================================================================
-- Delivery Pipeline 3 of 4 - Quality Control
-- QC review evidence + Stage 15 -> 16 approval and Stage 15 -> 14 rework
--
-- Boundary:
--   * one narrow qc.review permission;
--   * append-only booking_qc_reviews evidence, keyed by round;
--   * controlled record_booking_qc_review(...) RPC;
--   * controlled mark_booking_gallery_ready(uuid) RPC;
--   * controlled mark_booking_editing_rework(uuid) RPC;
--   * exact Stage 15 -> 16 and Stage 15 -> 14 advancement only;
--   * strict replay/idempotency;
--   * no gallery or delivery implementation.
--
-- Deviation from the Sprint 9-13 gate pattern, deliberate:
--   mark_booking_editing_rework performs the first BACKWARD journey transition in the
--   system (Stage 15 -> Stage 14). Rework is a real studio outcome and the
--   booking must visibly return to the editor's queue. The transition is
--   append-only like every other: the forward history is never rewritten,
--   a distinct 'editing_rework' transition row is added, and the round
--   counters make the number of passes auditable.
-- =====================================================================

-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $dp3_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_qc_reviews') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 precondition failed: QC review relation already exists';
  END IF;

  IF to_regprocedure('public.record_booking_qc_review(uuid,text,text)') IS NOT NULL
     OR to_regprocedure('public.mark_booking_gallery_ready(uuid)') IS NOT NULL
     OR to_regprocedure('public.mark_booking_editing_rework(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 precondition failed: mutation RPC already exists';
  END IF;

  IF EXISTS (SELECT 1 FROM public.permissions WHERE key = 'qc.review') THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 precondition failed: qc.review permission already exists';
  END IF;

  IF to_regclass('public.booking_editing_completions') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 precondition failed: editing completion foundation unavailable';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL
     OR to_regprocedure('public.mark_booking_qc_pending(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (14, 15, 16)
    AND stage_key IN ('editing_in_progress', 'qc_pending', 'pixieset_gallery_ready')
    AND is_active;

  IF v_count < 3 THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 precondition failed: canonical QC stages unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 266 THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 precondition failed: expected canonical role-permission count 266, found %',
      v_count;
  END IF;
END
$dp3_preconditions$;

-- =====================================================================
-- Section B - Permission
-- =====================================================================

INSERT INTO public.permissions (
  key, domain, label, description, requires_server_enforcement
)
VALUES (
  'qc.review',
  'bookings',
  'Review edited work',
  'Approve an edited booking round for client delivery, or return it to the editor for rework.',
  true
);

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN ('founder', 'studio_manager')
  AND permission.key = 'qc.review';

-- =====================================================================
-- Section C - QC review evidence
-- =====================================================================

CREATE TABLE public.booking_qc_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  round integer NOT NULL,
  outcome text NOT NULL,
  review_note text,

  reviewed_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_qc_reviews_round_chk
    CHECK (round >= 1 AND round <= 50),

  CONSTRAINT booking_qc_reviews_outcome_chk
    CHECK (outcome IN ('approved', 'rework')),

  CONSTRAINT booking_qc_reviews_rework_note_chk
    CHECK (outcome <> 'rework' OR review_note IS NOT NULL),

  CONSTRAINT booking_qc_reviews_review_note_chk
    CHECK (
      review_note IS NULL
      OR (
      review_note = btrim(review_note)
      AND review_note <> ''
      AND btrim(
        review_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND review_note = btrim(review_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(review_note) <= 1000
      AND review_note !~ '[[:cntrl:]]'
      AND review_note !~* '^(bearer|basic)[[:space:]]+'
      AND review_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND review_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_qc_reviews_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_qc_reviews_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_qc_reviews_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_qc_reviews_org_booking_round_key
    UNIQUE (organization_id, booking_id, round),

  CONSTRAINT booking_qc_reviews_id_booking_key
    UNIQUE (id, booking_id)
);

CREATE INDEX booking_qc_reviews_org_reviewed_idx
ON public.booking_qc_reviews (organization_id, reviewed_at DESC);

CREATE INDEX booking_qc_reviews_booking_round_idx
ON public.booking_qc_reviews (booking_id, round DESC);

CREATE FUNCTION public.lsh_booking_qc_review_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking qc reviews evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking qc reviews evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking qc reviews recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking qc reviews actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_qc_reviews_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_qc_reviews
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_qc_review_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_qc_review_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_qc_review_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_qc_review_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_qc_review_guard() FROM service_role;

ALTER TABLE public.booking_qc_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_qc_reviews FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_qc_reviews FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_qc_reviews FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_qc_reviews FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_qc_reviews FROM service_role;

GRANT SELECT ON TABLE public.booking_qc_reviews TO authenticated;

CREATE POLICY booking_qc_reviews_authenticated_select
ON public.booking_qc_reviews
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_qc_reviews.organization_id
      AND booking.id = booking_qc_reviews.booking_id
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
-- Section D - QC review RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_qc_review(
  p_booking_id uuid,
  p_outcome text,
  p_note text DEFAULT NULL
)
RETURNS public.booking_qc_reviews
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_qc_review$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_outcome text;
  v_note text;
  v_round integer;
  v_review_count integer;
  v_completion_count integer;
  v_result public.booking_qc_reviews;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_qc_review: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_qc_review: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_qc_review: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_qc_review: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'qc.review', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_qc_review: qc.review permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_qc_review: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_outcome IS NULL THEN
    RAISE EXCEPTION 'record_booking_qc_review: outcome is required' USING ERRCODE = '22023';
  END IF;

  v_outcome := btrim(p_outcome);

  IF v_outcome = ''
     OR btrim(v_outcome, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_outcome <> btrim(v_outcome, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_outcome) > 16
     OR v_outcome ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_qc_review: outcome is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_outcome NOT IN ('approved', 'rework') THEN
    RAISE EXCEPTION 'record_booking_qc_review: outcome must be approved or rework'
      USING ERRCODE = '22023';
  END IF;

  v_note := NULLIF(btrim(COALESCE(p_note, '')), '');

  IF v_note IS NOT NULL
     AND (
       btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_note <> btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_note) > 1000
       OR v_note ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_note := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_qc_review: review note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_qc_review: review note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  IF v_outcome = 'rework' AND v_note IS NULL THEN
    RAISE EXCEPTION 'record_booking_qc_review: rework requires a review note'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_qc_review: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_qc_review: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (v_stage.stage_order = 15 AND v_stage.stage_key = 'qc_pending') THEN
    RAISE EXCEPTION
      'record_booking_qc_review: booking must be exactly QC Pending'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_completion_count
  FROM public.booking_editing_completions completion
  WHERE completion.organization_id = v_booking.organization_id
    AND completion.booking_id = v_booking.id;

  SELECT count(*) INTO v_review_count
  FROM public.booking_qc_reviews review
  WHERE review.organization_id = v_booking.organization_id
    AND review.booking_id = v_booking.id;

  IF v_review_count >= v_completion_count THEN
    RAISE EXCEPTION
      'record_booking_qc_review: this editing round has already been reviewed'
      USING ERRCODE = '22023';
  END IF;

  v_round := v_review_count + 1;

  INSERT INTO public.booking_qc_reviews (
    organization_id, booking_id, round, outcome,
    review_note, reviewed_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_round, v_outcome,
    v_note, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.qc_reviewed',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object('qc_round_reviewed', false),
    jsonb_build_object(
      'qc_round_reviewed', true,
      'qc_round', v_round,
      'outcome', v_outcome
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'qc_review_id', v_result.id,
      'qc_round', v_round,
      'outcome', v_outcome,
      'note_present', (v_note IS NOT NULL)
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$record_qc_review$;

REVOKE ALL ON FUNCTION public.record_booking_qc_review(uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_qc_review(uuid,text,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_qc_review(uuid,text,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_qc_review(uuid,text,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_qc_review(uuid,text,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_qc_review(uuid,text,text) IS
  'Records an immutable QC outcome (approved or rework) for the editing round awaiting review. Rework requires a note. Does not advance the booking journey stage.';

-- =====================================================================
-- Section E - Stage 15 -> 16 approval gate
-- =====================================================================

CREATE FUNCTION public.mark_booking_gallery_ready(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $gate_gallery_ready$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_latest_outcome text;
  v_latest_round integer;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: canonical journey state is invalid'
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
    RAISE EXCEPTION 'mark_booking_gallery_ready: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 15 AND v_stage.stage_key = 'qc_pending')
    OR
    (v_stage.stage_order = 16 AND v_stage.stage_key = 'pixieset_gallery_ready')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_gallery_ready: booking must be exactly QC Pending or Gallery Ready replay'
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
    AND transition_row.transition_key = 'qc_pending'
    AND source_stage.stage_order = 14
    AND source_stage.stage_key = 'editing_in_progress'
    AND destination_stage.stage_order = 15
    AND destination_stage.stage_key = 'qc_pending';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: canonical QC Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 16 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'pixieset_gallery_ready'
      AND destination_stage.stage_order = 16
      AND destination_stage.stage_key = 'pixieset_gallery_ready';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_gallery_ready: canonical Gallery Ready transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  SELECT review.outcome, review.round INTO v_latest_outcome, v_latest_round
  FROM public.booking_qc_reviews review
  WHERE review.organization_id = v_booking.organization_id
    AND review.booking_id = v_booking.id
  ORDER BY review.round DESC
  LIMIT 1;

  IF v_latest_outcome IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_gallery_ready: booking requires a recorded QC review'
      USING ERRCODE = '22023';
  END IF;

  IF v_latest_outcome <> 'approved' THEN
    RAISE EXCEPTION
      'mark_booking_gallery_ready: latest QC review must be an approval'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 16
    AND stage.stage_key = 'pixieset_gallery_ready'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_gallery_ready: canonical destination stage is unavailable'
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
    'pixieset_gallery_ready', v_transitioned_at, v_actor
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
    RAISE EXCEPTION 'mark_booking_gallery_ready: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.gallery_ready',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage', v_stage.stage_key,
      'journey_version', v_state.version
    ),
    jsonb_build_object(
      'journey_stage', 'pixieset_gallery_ready',
      'journey_version', v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'pixieset_gallery_ready',
      'qc_round', v_latest_round,
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$gate_gallery_ready$;

REVOKE ALL ON FUNCTION public.mark_booking_gallery_ready(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_gallery_ready(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_gallery_ready(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_gallery_ready(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_gallery_ready(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_gallery_ready(uuid) IS
  'Advances a booking from QC Pending (15) to Gallery Ready (16). Requires the latest QC review to be an approval. Idempotent on replay.';

-- =====================================================================
-- Section F - Stage 15 -> 14 rework return
-- =====================================================================

CREATE FUNCTION public.mark_booking_editing_rework(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $gate_editing_rework$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_latest_outcome text;
  v_latest_round integer;
  v_rework_review_count integer;
  v_rework_transition_count integer;
  v_inbound_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: canonical journey state is invalid'
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
    RAISE EXCEPTION 'mark_booking_editing_rework: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 15 AND v_stage.stage_key = 'qc_pending')
    OR
    (v_stage.stage_order = 14 AND v_stage.stage_key = 'editing_in_progress')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_rework: booking must be exactly QC Pending or Editing in Progress replay'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_rework_review_count
  FROM public.booking_qc_reviews review
  WHERE review.organization_id = v_booking.organization_id
    AND review.booking_id = v_booking.id
    AND review.outcome = 'rework';

  SELECT count(*) INTO v_rework_transition_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND transition_row.transition_key = 'editing_rework'
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key = 'editing_in_progress';

  -- Replay: every recorded rework outcome already has its return transition.
  IF v_stage.stage_order = 14 THEN
    IF v_rework_transition_count < 1
       OR v_rework_transition_count <> v_rework_review_count THEN
      RAISE EXCEPTION
        'mark_booking_editing_rework: canonical rework transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
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
    AND transition_row.transition_key = 'qc_pending'
    AND source_stage.stage_order = 14
    AND source_stage.stage_key = 'editing_in_progress'
    AND destination_stage.stage_order = 15
    AND destination_stage.stage_key = 'qc_pending';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: canonical QC Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT review.outcome, review.round INTO v_latest_outcome, v_latest_round
  FROM public.booking_qc_reviews review
  WHERE review.organization_id = v_booking.organization_id
    AND review.booking_id = v_booking.id
  ORDER BY review.round DESC
  LIMIT 1;

  IF v_latest_outcome IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_editing_rework: booking requires a recorded QC review'
      USING ERRCODE = '22023';
  END IF;

  IF v_latest_outcome <> 'rework' THEN
    RAISE EXCEPTION
      'mark_booking_editing_rework: latest QC review must request rework'
      USING ERRCODE = '22023';
  END IF;

  IF v_rework_transition_count >= v_rework_review_count THEN
    RAISE EXCEPTION
      'mark_booking_editing_rework: this rework request has already been returned to editing'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 14
    AND stage.stage_key = 'editing_in_progress'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_editing_rework: canonical destination stage is unavailable'
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
    'editing_rework', v_transitioned_at, v_actor
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
    RAISE EXCEPTION 'mark_booking_editing_rework: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_rework',
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
      'transition_key', 'editing_rework',
      'qc_round', v_latest_round,
      'rework_return_count', v_rework_transition_count + 1,
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$gate_editing_rework$;

REVOKE ALL ON FUNCTION public.mark_booking_editing_rework(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_editing_rework(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_editing_rework(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_editing_rework(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_editing_rework(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_editing_rework(uuid) IS
  'Returns a booking from QC Pending (15) to Editing in Progress (14) after a rework outcome. The only backward journey transition in the system; forward history is preserved and a distinct editing_rework transition is appended.';

-- =====================================================================
-- Section G - Postconditions
-- =====================================================================

DO $dp3_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_qc_reviews') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 postcondition failed: QC review relation missing';
  END IF;

  IF to_regprocedure('public.record_booking_qc_review(uuid,text,text)') IS NULL
     OR to_regprocedure('public.mark_booking_gallery_ready(uuid)') IS NULL
     OR to_regprocedure('public.mark_booking_editing_rework(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 postcondition failed: required mutation RPC missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission ON permission.id = role_permission.permission_id
  WHERE permission.key = 'qc.review';

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 postcondition failed: qc.review role boundary invalid';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 268 THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 postcondition failed: expected role-permission count 268, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname = 'booking_qc_reviews'
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 postcondition failed: row level security not forced';
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_gallery_ready(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_gallery_ready(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.mark_booking_editing_rework(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_editing_rework(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.record_booking_qc_review(uuid,text,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.record_booking_qc_review(uuid,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 postcondition failed: privileged execute must be denied';
  END IF;

  IF has_table_privilege('authenticated', 'public.booking_qc_reviews', 'INSERT')
     OR has_table_privilege('authenticated', 'public.booking_qc_reviews', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.booking_qc_reviews', 'DELETE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 3 postcondition failed: evidence table must be read-only to authenticated';
  END IF;
END
$dp3_postconditions$;
