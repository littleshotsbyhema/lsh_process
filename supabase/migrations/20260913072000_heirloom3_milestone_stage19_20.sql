-- =====================================================================
-- Heirloom Pipeline 3 of 4 - Milestone Follow-Up
--
-- Boundary:
--   * one narrow milestone.plan permission;
--   * one booking_milestone_plans row per booking;
--   * controlled record_booking_milestone_plan(...) RPC;
--   * controlled mark_booking_milestone_follow_up(uuid) RPC;
--   * exact Stage 19 -> 20 advancement only;
--   * no completion implementation.
--
-- This is the memory-business hinge. A newborn session leads to a sitter
-- session leads to a first birthday. The plan records WHEN the family should
-- next be approached and WHAT to offer, so the relationship resurfaces on
-- purpose rather than by memory.
--
-- The plan is an intention, not a booking. It creates no lead, no quotation
-- and no commitment, and it never contacts the family by itself.
-- =====================================================================

DO $hp3_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_milestone_plans') IS NOT NULL THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 precondition failed: relation already exists';
  END IF;

  IF to_regprocedure('public.record_booking_milestone_plan(uuid,text,date,text)') IS NOT NULL
     OR to_regprocedure('public.mark_booking_milestone_follow_up(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 precondition failed: mutation RPC already exists';
  END IF;

  IF EXISTS (SELECT 1 FROM public.permissions WHERE key = 'milestone.plan') THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 precondition failed: permission already exists';
  END IF;

  IF to_regprocedure('public.mark_booking_review_requested(uuid)') IS NULL
     OR to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 3 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (19, 20)
    AND stage_key IN ('review_requested', 'milestone_follow_up')
    AND is_active;
  IF v_count < 2 THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 precondition failed: canonical stages unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 278 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 3 precondition failed: expected canonical role-permission count 278, found %',
      v_count;
  END IF;
END
$hp3_preconditions$;

INSERT INTO public.permissions (key, domain, label, description, requires_server_enforcement)
VALUES (
  'milestone.plan', 'bookings', 'Plan the next memory milestone',
  'Record when a family should next be approached and what session to offer.', true
);

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN ('founder', 'studio_manager', 'client_coordinator')
  AND permission.key = 'milestone.plan';

CREATE TABLE public.booking_milestone_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  next_session_category text NOT NULL,
  due_on date NOT NULL,
  offer_note text,
  planned_at timestamptz NOT NULL,
  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_milestone_plans_category_chk
    CHECK (next_session_category IN
      ('maternity', 'newborn', 'sitter', 'birthday', 'family', 'other')),

  CONSTRAINT booking_milestone_plans_offer_note_chk
    CHECK (
      offer_note IS NULL
      OR (
      offer_note = btrim(offer_note)
      AND offer_note <> ''
      AND btrim(
        offer_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND offer_note = btrim(offer_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(offer_note) <= 500
      AND offer_note !~ '[[:cntrl:]]'
      AND offer_note !~* '^(bearer|basic)[[:space:]]+'
      AND offer_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND offer_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_milestone_plans_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT booking_milestone_plans_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT booking_milestone_plans_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT booking_milestone_plans_org_booking_key UNIQUE (organization_id, booking_id)
);

CREATE INDEX booking_milestone_plans_org_due_idx ON public.booking_milestone_plans (organization_id, due_on);
CREATE INDEX booking_milestone_plans_category_due_idx ON public.booking_milestone_plans (organization_id, next_session_category, due_on);

CREATE FUNCTION public.lsh_booking_milestone_plan_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking milestone plans evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking milestone plans evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking milestone plans recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking milestone plans actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_milestone_plans_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_milestone_plans
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_milestone_plan_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_milestone_plan_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_milestone_plan_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_milestone_plan_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_milestone_plan_guard() FROM service_role;

ALTER TABLE public.booking_milestone_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_milestone_plans FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_milestone_plans FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_milestone_plans FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_milestone_plans FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_milestone_plans FROM service_role;

GRANT SELECT ON TABLE public.booking_milestone_plans TO authenticated;

CREATE POLICY booking_milestone_plans_authenticated_select
ON public.booking_milestone_plans
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_milestone_plans.organization_id
      AND booking.id = booking_milestone_plans.booking_id
      AND public.has_permission(
            booking.organization_id, 'booking.read', booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(booking.organization_id, booking.branch_id)
      )
  )
);

CREATE FUNCTION public.record_booking_milestone_plan(
  p_booking_id uuid,
  p_next_session_category text,
  p_due_on date,
  p_offer_note text DEFAULT NULL
)
RETURNS public.booking_milestone_plans
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $record_milestone_plan$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_category text;
  v_note text;
  v_existing public.booking_milestone_plans;
  v_result public.booking_milestone_plans;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'milestone.plan', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: milestone.plan permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_next_session_category IS NULL THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: next session category is required' USING ERRCODE = '22023';
  END IF;

  v_category := btrim(p_next_session_category);

  IF v_category = ''
     OR btrim(v_category, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_category <> btrim(v_category, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_category) > 24
     OR v_category ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: next session category is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_category NOT IN ('maternity', 'newborn', 'sitter', 'birthday', 'family', 'other') THEN
    RAISE EXCEPTION
      'record_booking_milestone_plan: next session category must be maternity, newborn, sitter, birthday, family or other'
      USING ERRCODE = '22023';
  END IF;

  IF p_due_on IS NULL THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: due date is required' USING ERRCODE = '22023';
  END IF;

  IF p_due_on <= current_date THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: due date must be in the future' USING ERRCODE = '22023';
  END IF;

  IF p_due_on > current_date + 3650 THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: due date is too far in the future' USING ERRCODE = '22023';
  END IF;

  v_note := NULLIF(btrim(COALESCE(p_offer_note, '')), '');

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
      RAISE EXCEPTION 'record_booking_milestone_plan: offer note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: offer note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_milestone_plan: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (v_stage.stage_order = 20 AND v_stage.stage_key = 'milestone_follow_up') THEN
    RAISE EXCEPTION 'record_booking_milestone_plan: booking must be exactly Milestone Follow-Up'
      USING ERRCODE = '22023';
  END IF;

  SELECT plan.* INTO v_existing
  FROM public.booking_milestone_plans plan
  WHERE plan.organization_id = v_booking.organization_id
    AND plan.booking_id = v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.next_session_category IS DISTINCT FROM v_category
       OR v_existing.due_on IS DISTINCT FROM p_due_on
       OR v_existing.offer_note IS DISTINCT FROM v_note THEN
      RAISE EXCEPTION 'record_booking_milestone_plan: conflicting milestone plan replay'
        USING ERRCODE = '23505';
    END IF;

    RETURN v_existing;
  END IF;

  INSERT INTO public.booking_milestone_plans (
    organization_id, booking_id, next_session_category, due_on, offer_note,
    planned_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_category, p_due_on, v_note,
    now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.milestone_planned', 'booking', v_booking.id, false,
    NULL,
    jsonb_build_object('next_session_category', v_category, 'due_on', p_due_on),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'milestone_plan_id', v_result.id,
      'next_session_category', v_category,
      'due_on', p_due_on,
      'offer_note_present', (v_note IS NOT NULL)
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_milestone_plan$;

REVOKE ALL ON FUNCTION public.record_booking_milestone_plan(uuid,text,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_milestone_plan(uuid,text,date,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_milestone_plan(uuid,text,date,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_milestone_plan(uuid,text,date,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_milestone_plan(uuid,text,date,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_milestone_plan(uuid,text,date,text) IS
  'Records when a family should next be approached and what session to offer. An intention only: creates no lead, no quotation and no commitment, and contacts nobody.';

CREATE FUNCTION public.mark_booking_milestone_follow_up(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $gate_milestone_follow_up$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_request_count integer;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: canonical journey state is invalid'
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
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 19 AND v_stage.stage_key = 'review_requested')
    OR
    (v_stage.stage_order = 20 AND v_stage.stage_key = 'milestone_follow_up')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_milestone_follow_up: booking must be exactly Review Requested or Milestone Follow-Up replay'
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
    AND transition_row.transition_key = 'review_requested'
    AND source_stage.stage_order = 18
    AND source_stage.stage_key = 'album_frame_production'
    AND destination_stage.stage_order = 19
    AND destination_stage.stage_key = 'review_requested';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: canonical Review Requested transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 20 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'milestone_follow_up'
      AND destination_stage.stage_order = 20
      AND destination_stage.stage_key = 'milestone_follow_up';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_milestone_follow_up: canonical Milestone Follow-Up transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  SELECT count(*) INTO v_request_count
  FROM public.booking_review_requests request
  WHERE request.organization_id = v_booking.organization_id
    AND request.booking_id = v_booking.id;

  IF v_request_count < 1 THEN
    RAISE EXCEPTION
      'mark_booking_milestone_follow_up: booking requires a recorded review request'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 20
    AND stage.stage_key = 'milestone_follow_up'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: canonical destination stage is unavailable'
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
    'milestone_follow_up', v_transitioned_at, v_actor
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
    RAISE EXCEPTION 'mark_booking_milestone_follow_up: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.milestone_follow_up', 'booking', v_booking.id, false,
    jsonb_build_object('journey_stage', v_stage.stage_key, 'journey_version', v_state.version),
    jsonb_build_object('journey_stage', 'milestone_follow_up', 'journey_version', v_state.version + 1),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'milestone_follow_up',
      'review_request_count', v_request_count,
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application', NULL
  );

  RETURN v_booking;
END;
$gate_milestone_follow_up$;

REVOKE ALL ON FUNCTION public.mark_booking_milestone_follow_up(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_milestone_follow_up(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_milestone_follow_up(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_milestone_follow_up(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_milestone_follow_up(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_milestone_follow_up(uuid) IS
  'Advances a booking from Review Requested (19) to Milestone Follow-Up (20). Requires a recorded review request. Idempotent on replay.';

DO $hp3_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_milestone_plans') IS NULL
     OR to_regprocedure('public.record_booking_milestone_plan(uuid,text,date,text)') IS NULL
     OR to_regprocedure('public.mark_booking_milestone_follow_up(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 postcondition failed: artifact missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions rp
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE p.key = 'milestone.plan';
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 postcondition failed: milestone.plan role boundary invalid';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 281 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 3 postcondition failed: expected role-permission count 281, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname='public' AND c.relname='booking_milestone_plans' AND c.relrowsecurity AND c.relforcerowsecurity;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 postcondition failed: row level security not forced';
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_milestone_follow_up(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.record_booking_milestone_plan(uuid,text,date,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 postcondition failed: privileged execute must be denied';
  END IF;

  IF has_table_privilege('authenticated', 'public.booking_milestone_plans', 'INSERT') THEN
    RAISE EXCEPTION 'Heirloom pipeline 3 postcondition failed: evidence table must be read-only';
  END IF;
END
$hp3_postconditions$;
