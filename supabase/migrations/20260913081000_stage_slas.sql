-- =====================================================================
-- Stage SLAs
-- =====================================================================
--
-- Gives every journey stage an optional target duration, so a board can
-- show which jobs have sat too long. Deliberately minimal:
--
--   * one target, in hours, per stage per organization;
--   * no per-booking due-date column - the due time is derived at read
--     time from booking_journey_states.stage_entered_at, so changing a
--     target immediately re-scores every open booking with no backfill;
--   * no notifications, no escalation, no blocking. A breach is a fact
--     the board displays, never a gate.
--
-- Writes go through SECURITY DEFINER RPCs guarded by org.settings.write.
-- =====================================================================

DO $precondition$
BEGIN
  IF to_regclass('public.booking_journey_stages') IS NULL THEN
    RAISE EXCEPTION 'precondition: booking_journey_stages is missing';
  END IF;

  IF to_regclass('public.booking_journey_states') IS NULL THEN
    RAISE EXCEPTION 'precondition: booking_journey_states is missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'org.settings.write') THEN
    RAISE EXCEPTION 'precondition: org.settings.write permission is missing';
  END IF;

  IF to_regprocedure('public.append_audit_event(uuid, uuid, text, text, uuid, boolean, jsonb, jsonb, jsonb, text, uuid)') IS NULL THEN
    RAISE EXCEPTION 'precondition: append_audit_event signature is unavailable';
  END IF;
END;
$precondition$;

-- =====================================================================
-- Section A - Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.stage_slas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL
    REFERENCES public.organizations (id) ON DELETE CASCADE,
  stage_key text NOT NULL,
  target_hours integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,

  CONSTRAINT stage_slas_org_stage_key UNIQUE (organization_id, stage_key),

  CONSTRAINT stage_slas_target_hours_chk
    CHECK (target_hours >= 1 AND target_hours <= 8760),

  CONSTRAINT stage_slas_stage_key_chk
    CHECK (
      stage_key = btrim(stage_key)
      AND stage_key <> ''
      AND char_length(stage_key) <= 80
      AND stage_key ~ '^[a-z0-9_]+$'
    )
);

CREATE INDEX IF NOT EXISTS stage_slas_organization_idx
  ON public.stage_slas (organization_id);

-- =====================================================================
-- Section B - RLS
-- =====================================================================

ALTER TABLE public.stage_slas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stage_slas FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stage_slas_staff_read ON public.stage_slas;

CREATE POLICY stage_slas_staff_read
  ON public.stage_slas
  FOR SELECT
  TO authenticated
  USING (public.has_permission_in_any_live_scope(organization_id, 'org.read'));

REVOKE ALL ON TABLE public.stage_slas FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.stage_slas TO authenticated;

-- =====================================================================
-- Section C - Write RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.set_stage_sla(
  p_organization_id uuid,
  p_stage_key text,
  p_target_hours integer
)
RETURNS public.stage_slas
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $set_stage_sla$
DECLARE
  v_actor uuid;
  v_key text;
  v_prior integer;
  v_result public.stage_slas;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'set_stage_sla: organization_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'set_stage_sla: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  v_actor := public.current_organization_member(p_organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'set_stage_sla: active organization membership required' USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission_in_any_live_scope(p_organization_id, 'org.settings.write') THEN
    RAISE EXCEPTION 'set_stage_sla: org.settings.write permission required' USING ERRCODE = '42501';
  END IF;

  v_key := btrim(COALESCE(p_stage_key, ''));

  IF v_key = '' OR v_key !~ '^[a-z0-9_]+$' OR char_length(v_key) > 80 THEN
    RAISE EXCEPTION 'set_stage_sla: stage key is invalid' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.booking_journey_stages stage
    WHERE stage.organization_id = p_organization_id
      AND stage.stage_key = v_key
      AND stage.is_active
  ) THEN
    RAISE EXCEPTION 'set_stage_sla: stage key does not name an active journey stage'
      USING ERRCODE = '22023';
  END IF;

  IF p_target_hours IS NULL OR p_target_hours < 1 OR p_target_hours > 8760 THEN
    RAISE EXCEPTION 'set_stage_sla: target hours must be between 1 and 8760'
      USING ERRCODE = '22023';
  END IF;

  SELECT sla.target_hours INTO v_prior
  FROM public.stage_slas sla
  WHERE sla.organization_id = p_organization_id
    AND sla.stage_key = v_key
  FOR UPDATE;

  INSERT INTO public.stage_slas (
    organization_id, stage_key, target_hours,
    created_at, created_by, updated_at, updated_by
  )
  VALUES (
    p_organization_id, v_key, p_target_hours,
    now(), v_actor, now(), v_actor
  )
  ON CONFLICT (organization_id, stage_key) DO UPDATE
    SET target_hours = EXCLUDED.target_hours,
        updated_at = now(),
        updated_by = EXCLUDED.updated_by
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    p_organization_id,
    NULL,
    'stage_sla.set',
    'stage_sla',
    v_result.id,
    false,
    jsonb_build_object('stage_key', v_key, 'target_hours', v_prior),
    jsonb_build_object('stage_key', v_key, 'target_hours', p_target_hours),
    jsonb_build_object(
      'stage_key', v_key,
      'prior_target_hours', v_prior,
      'target_hours', p_target_hours
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$set_stage_sla$;

REVOKE ALL ON FUNCTION public.set_stage_sla(uuid, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_stage_sla(uuid, text, integer) TO authenticated;

-- =====================================================================
-- Section D - Clear RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.clear_stage_sla(
  p_organization_id uuid,
  p_stage_key text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $clear_stage_sla$
DECLARE
  v_actor uuid;
  v_key text;
  v_existing public.stage_slas;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'clear_stage_sla: organization_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'clear_stage_sla: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  v_actor := public.current_organization_member(p_organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'clear_stage_sla: active organization membership required' USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission_in_any_live_scope(p_organization_id, 'org.settings.write') THEN
    RAISE EXCEPTION 'clear_stage_sla: org.settings.write permission required' USING ERRCODE = '42501';
  END IF;

  v_key := btrim(COALESCE(p_stage_key, ''));

  SELECT sla.* INTO v_existing
  FROM public.stage_slas sla
  WHERE sla.organization_id = p_organization_id
    AND sla.stage_key = v_key
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  DELETE FROM public.stage_slas sla
  WHERE sla.id = v_existing.id;

  PERFORM public.append_audit_event(
    p_organization_id,
    NULL,
    'stage_sla.cleared',
    'stage_sla',
    v_existing.id,
    false,
    jsonb_build_object('stage_key', v_key, 'target_hours', v_existing.target_hours),
    jsonb_build_object('stage_key', v_key, 'target_hours', NULL),
    jsonb_build_object('stage_key', v_key, 'prior_target_hours', v_existing.target_hours),
    'application',
    NULL
  );

  RETURN true;
END;
$clear_stage_sla$;

REVOKE ALL ON FUNCTION public.clear_stage_sla(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.clear_stage_sla(uuid, text) TO authenticated;

-- =====================================================================
-- Section E - Read view
-- =====================================================================
--
-- One row per open booking with its stage, how long it has been there,
-- its target, and whether it has breached. security_invoker keeps the
-- caller's RLS in force.

CREATE OR REPLACE VIEW public.booking_stage_sla_status
WITH (security_invoker = true) AS
SELECT
  state.organization_id,
  state.booking_id,
  stage.stage_key,
  stage.stage_order,
  state.stage_entered_at,
  sla.target_hours,
  ROUND(EXTRACT(EPOCH FROM (now() - state.stage_entered_at)) / 3600.0, 1)::numeric
    AS hours_in_stage,
  CASE
    WHEN sla.target_hours IS NULL THEN NULL
    ELSE state.stage_entered_at + make_interval(hours => sla.target_hours)
  END AS due_at,
  CASE
    WHEN sla.target_hours IS NULL THEN false
    ELSE now() > state.stage_entered_at + make_interval(hours => sla.target_hours)
  END AS is_breached
FROM public.booking_journey_states state
JOIN public.booking_journey_stages stage
  ON stage.organization_id = state.organization_id
 AND stage.id = state.current_stage_id
LEFT JOIN public.stage_slas sla
  ON sla.organization_id = state.organization_id
 AND sla.stage_key = stage.stage_key;

REVOKE ALL ON public.booking_stage_sla_status FROM PUBLIC;
GRANT SELECT ON public.booking_stage_sla_status TO authenticated;

-- =====================================================================
-- Section F - Postconditions
-- =====================================================================

DO $postcondition$
DECLARE
  v_rls boolean;
  v_force boolean;
BEGIN
  IF to_regclass('public.stage_slas') IS NULL THEN
    RAISE EXCEPTION 'postcondition: stage_slas was not created';
  END IF;

  SELECT relrowsecurity, relforcerowsecurity INTO v_rls, v_force
  FROM pg_class WHERE oid = 'public.stage_slas'::regclass;

  IF NOT v_rls OR NOT v_force THEN
    RAISE EXCEPTION 'postcondition: stage_slas row level security is not forced';
  END IF;

  IF to_regprocedure('public.set_stage_sla(uuid, text, integer)') IS NULL THEN
    RAISE EXCEPTION 'postcondition: set_stage_sla was not created';
  END IF;

  IF to_regprocedure('public.clear_stage_sla(uuid, text)') IS NULL THEN
    RAISE EXCEPTION 'postcondition: clear_stage_sla was not created';
  END IF;

  IF to_regclass('public.booking_stage_sla_status') IS NULL THEN
    RAISE EXCEPTION 'postcondition: booking_stage_sla_status view was not created';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
    WHERE table_schema = 'public'
      AND table_name = 'stage_slas'
      AND grantee = 'authenticated'
      AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
  ) THEN
    RAISE EXCEPTION 'postcondition: stage_slas must not grant direct writes';
  END IF;
END;
$postcondition$;
