-- =====================================================================
-- Heirloom Pipeline 2 of 4 - Review Requested
--
-- Boundary:
--   * one narrow review.request permission;
--   * append-only booking_review_requests evidence, keyed by round;
--   * controlled record_booking_review_request(...) RPC;
--   * controlled mark_booking_review_requested(uuid) RPC;
--   * exact Stage 18 -> 19 advancement only;
--   * no milestone follow-up or completion.

--
-- The gate requires studio handover to be recorded, so a family is never
-- asked for a review before they have their album or frame in hand.
-- =====================================================================

DO $hp2_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_review_requests') IS NOT NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 2 precondition failed: relation already exists';
  END IF;

  IF to_regprocedure('public.record_booking_review_request(uuid,text,text)') IS NOT NULL OR to_regprocedure('public.mark_booking_review_requested(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 2 precondition failed: mutation RPC already exists';
  END IF;

  IF EXISTS (SELECT 1 FROM public.permissions WHERE key IN ('review.request')) THEN
    RAISE EXCEPTION
      'Heirloom pipeline 2 precondition failed: permission already exists';
  END IF;

  IF to_regprocedure('public.mark_booking_album_frame_production(uuid)') IS NULL
     OR to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 2 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (18, 19)
    AND stage_key IN ('album_frame_production', 'review_requested')
    AND is_active;

  IF v_count < 2 THEN
    RAISE EXCEPTION 'Heirloom pipeline 2 precondition failed: canonical stages unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.roles WHERE key IN ('founder', 'studio_manager', 'client_coordinator');
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'Heirloom pipeline 2 precondition failed: canonical roles unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 275 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 2 precondition failed: expected canonical role-permission count 275, found %',
      v_count;
  END IF;
END
$hp2_preconditions$;

INSERT INTO public.permissions (key, domain, label, description, requires_server_enforcement)
VALUES (
  'review.request', 'bookings', 'Request a client review',
  'Record that a family was asked for a review after their heirloom handover.', true
);

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN ('founder', 'studio_manager', 'client_coordinator')
  AND permission.key = 'review.request';

CREATE TABLE public.booking_review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  round integer NOT NULL,
  channel text NOT NULL,
  request_note text,
  requested_at timestamptz NOT NULL,
  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_review_requests_round_chk CHECK (round >= 1 AND round <= 20),
  CONSTRAINT booking_review_requests_channel_chk
    CHECK (channel IN ('google', 'instagram', 'whatsapp', 'in_person', 'other')),

  CONSTRAINT booking_review_requests_request_note_chk
    CHECK (
      request_note IS NULL
      OR (
      request_note = btrim(request_note)
      AND request_note <> ''
      AND btrim(
        request_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND request_note = btrim(request_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(request_note) <= 500
      AND request_note !~ '[[:cntrl:]]'
      AND request_note !~* '^(bearer|basic)[[:space:]]+'
      AND request_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND request_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_review_requests_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT booking_review_requests_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT booking_review_requests_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT booking_review_requests_org_booking_round_key UNIQUE (organization_id, booking_id, round)
);

CREATE INDEX booking_review_requests_booking_round_idx ON public.booking_review_requests (booking_id, round DESC);
CREATE INDEX booking_review_requests_org_requested_idx ON public.booking_review_requests (organization_id, requested_at DESC);

CREATE FUNCTION public.lsh_booking_review_request_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking review requests evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking review requests evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking review requests recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking review requests actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_review_requests_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_review_requests
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_review_request_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_review_request_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_review_request_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_review_request_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_review_request_guard() FROM service_role;

ALTER TABLE public.booking_review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_review_requests FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_review_requests FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_review_requests FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_review_requests FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_review_requests FROM service_role;

GRANT SELECT ON TABLE public.booking_review_requests TO authenticated;

CREATE POLICY booking_review_requests_authenticated_select
ON public.booking_review_requests
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_review_requests.organization_id
      AND booking.id = booking_review_requests.booking_id
      AND public.has_permission(
            booking.organization_id, 'booking.read', booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(booking.organization_id, booking.branch_id)
      )
  )
);

CREATE FUNCTION public.record_booking_review_request(
  p_booking_id uuid,
  p_channel text,
  p_note text DEFAULT NULL
)
RETURNS public.booking_review_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $record_review_request$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_channel text;
  v_note text;
  v_round integer;
  v_result public.booking_review_requests;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_review_request: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_review_request: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_review_request: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_review_request: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'review.request', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_review_request: review.request permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_review_request: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_channel IS NULL THEN
    RAISE EXCEPTION 'record_booking_review_request: channel is required' USING ERRCODE = '22023';
  END IF;

  v_channel := btrim(p_channel);

  IF v_channel = ''
     OR btrim(v_channel, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_channel <> btrim(v_channel, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_channel) > 24
     OR v_channel ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_review_request: channel is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_channel NOT IN ('google', 'instagram', 'whatsapp', 'in_person', 'other') THEN
    RAISE EXCEPTION
      'record_booking_review_request: channel must be google, instagram, whatsapp, in_person or other'
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
      RAISE EXCEPTION 'record_booking_review_request: request note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_review_request: request note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_review_request: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_review_request: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (v_stage.stage_order = 19 AND v_stage.stage_key = 'review_requested') THEN
    RAISE EXCEPTION 'record_booking_review_request: booking must be exactly Review Requested'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(max(request.round), 0) + 1 INTO v_round
  FROM public.booking_review_requests request
  WHERE request.organization_id = v_booking.organization_id
    AND request.booking_id = v_booking.id;

  IF v_round > 20 THEN
    RAISE EXCEPTION 'record_booking_review_request: review request limit reached' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_review_requests (
    organization_id, booking_id, round, channel, request_note,
    requested_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_round, v_channel, v_note,
    now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.review_requested', 'booking', v_booking.id, false,
    NULL,
    jsonb_build_object('review_request_round', v_round, 'channel', v_channel),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'review_request_id', v_result.id,
      'review_request_round', v_round,
      'channel', v_channel
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_review_request$;

REVOKE ALL ON FUNCTION public.record_booking_review_request(uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_review_request(uuid,text,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_review_request(uuid,text,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_review_request(uuid,text,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_review_request(uuid,text,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_review_request(uuid,text,text) IS
  'Records that a family was asked for a review, and through which channel. Repeatable as numbered rounds so a polite follow-up is distinguishable from the first ask.';

CREATE FUNCTION public.mark_booking_review_requested(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $gate_review_requested$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_review_requested: canonical journey state is invalid'
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
    RAISE EXCEPTION 'mark_booking_review_requested: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production')
    OR
    (v_stage.stage_order = 19 AND v_stage.stage_key = 'review_requested')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_review_requested: booking must be exactly Album / Frame Production or Review Requested replay'
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
    AND transition_row.transition_key = 'album_frame_production'
    AND source_stage.stage_order = 17
    AND source_stage.stage_key = 'delivered'
    AND destination_stage.stage_order = 18
    AND destination_stage.stage_key = 'album_frame_production';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_review_requested: canonical Album / Frame Production transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 19 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'review_requested'
      AND destination_stage.stage_order = 19
      AND destination_stage.stage_key = 'review_requested';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_review_requested: canonical Review Requested transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.booking_production_milestones milestone
    WHERE milestone.organization_id = v_booking.organization_id
      AND milestone.booking_id = v_booking.id
      AND milestone.milestone_type = 'handed_over'
  ) THEN
    RAISE EXCEPTION
      'mark_booking_review_requested: booking requires a recorded studio handover'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 19
    AND stage.stage_key = 'review_requested'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: canonical destination stage is unavailable'
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
    'review_requested', v_transitioned_at, v_actor
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
    RAISE EXCEPTION 'mark_booking_review_requested: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.review_stage', 'booking', v_booking.id, false,
    jsonb_build_object('journey_stage', v_stage.stage_key, 'journey_version', v_state.version),
    jsonb_build_object('journey_stage', 'review_requested', 'journey_version', v_state.version + 1),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'review_requested',
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application', NULL
  );

  RETURN v_booking;
END;
$gate_review_requested$;

REVOKE ALL ON FUNCTION public.mark_booking_review_requested(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_review_requested(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_review_requested(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_review_requested(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_review_requested(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_review_requested(uuid) IS
  'Advances a booking from Album / Frame Production (18) to Review Requested (19). Requires a recorded studio handover. Idempotent on replay.';

DO $hp2_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_review_requests') IS NULL
     OR to_regprocedure('public.record_booking_review_request(uuid,text,text)') IS NULL
     OR to_regprocedure('public.mark_booking_review_requested(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Heirloom pipeline 2 postcondition failed: artifact missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions rp
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE p.key = 'review.request';
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'Heirloom pipeline 2 postcondition failed: review.request role boundary invalid';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 278 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 2 postcondition failed: expected role-permission count 278, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname='public' AND c.relname='booking_review_requests' AND c.relrowsecurity AND c.relforcerowsecurity;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Heirloom pipeline 2 postcondition failed: row level security not forced';
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_review_requested(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_review_requested(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Heirloom pipeline 2 postcondition failed: privileged execute must be denied';
  END IF;

  IF has_table_privilege('authenticated', 'public.booking_review_requests', 'INSERT') THEN
    RAISE EXCEPTION 'Heirloom pipeline 2 postcondition failed: evidence table must be read-only';
  END IF;
END
$hp2_postconditions$;
