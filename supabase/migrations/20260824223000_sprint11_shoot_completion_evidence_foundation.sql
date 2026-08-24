-- =====================================================================
-- Sprint 11 — Shoot Completion & Post-Session Handoff
-- Slice 1 — Canonical Shoot Completion Evidence Foundation
--
-- Boundary:
--   * one narrow shoot.complete permission;
--   * immutable booking_shoot_completions evidence;
--   * one controlled record_booking_shoot_completion(uuid,timestamptz)
--     mutation RPC;
--   * authenticated read containment through canonical booking access;
--   * no Stage 10 -> 11 journey advancement;
--   * no shoot-day Safety evidence;
--   * no application UI.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11_slice1_preconditions$
DECLARE
  v_role_count integer;
BEGIN
  IF to_regclass(
       'public.booking_shoot_completions'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 precondition failed: booking_shoot_completions already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_shoot_completion(uuid,timestamp with time zone)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 precondition failed: record_booking_shoot_completion already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key = 'shoot.complete'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 precondition failed: shoot.complete already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.booking_shoot_schedules') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.roles') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 precondition failed: required canonical relation missing';
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
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_role_count
  FROM public.roles role
  WHERE role.key IN (
    'founder',
    'studio_manager',
    'photographer'
  );

  IF v_role_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 precondition failed: required completion-recorder roles unavailable';
  END IF;
END
$s11_slice1_preconditions$;

-- =====================================================================
-- Section B — Narrow Shoot Completion permission
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'shoot.complete',
  'bookings',
  'Record shoot completion',
  'Record immutable canonical evidence that a scheduled booking shoot has been completed.',
  true
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  role.id,
  permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN (
    'founder',
    'studio_manager',
    'photographer'
  )
  AND permission.key = 'shoot.complete';

-- =====================================================================
-- Section C1 — Canonical immutable completion evidence
-- =====================================================================

CREATE TABLE public.booking_shoot_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  completed_at timestamptz NOT NULL,

  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid NOT NULL,

  CONSTRAINT booking_shoot_completions_completed_at_chk
    CHECK (
      completed_at <= recorded_at
    ),

  CONSTRAINT booking_shoot_completions_booking_fkey
    FOREIGN KEY (
      organization_id,
      booking_id
    )
    REFERENCES public.bookings (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_shoot_completions_recorded_by_fkey
    FOREIGN KEY (
      recorded_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_shoot_completions_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    )
);

CREATE INDEX booking_shoot_completions_org_recorded_idx
ON public.booking_shoot_completions (
  organization_id,
  recorded_at DESC
);

-- =====================================================================
-- Section C2 — Immutable lifecycle / attribution guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_shoot_completion_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking shoot completion evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.recorded_at IS NULL
     OR NEW.completed_at IS NULL THEN
    RAISE EXCEPTION
      'booking shoot completion evidence requires complete immutable attribution';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking shoot completion recorded_by must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_shoot_completions_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_shoot_completions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_shoot_completion_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_shoot_completion_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.lsh_booking_shoot_completion_guard()
FROM anon;

REVOKE ALL
ON FUNCTION public.lsh_booking_shoot_completion_guard()
FROM authenticated;

REVOKE ALL
ON FUNCTION public.lsh_booking_shoot_completion_guard()
FROM service_role;

-- =====================================================================
-- Section C3 — Forced RLS / authenticated SELECT-only boundary
-- =====================================================================

ALTER TABLE public.booking_shoot_completions
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_shoot_completions
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_shoot_completions
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_shoot_completions
FROM anon;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_shoot_completions
FROM authenticated;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_shoot_completions
FROM service_role;

GRANT SELECT
ON TABLE public.booking_shoot_completions
TO authenticated;

CREATE POLICY booking_shoot_completions_authenticated_select
ON public.booking_shoot_completions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_shoot_completions.organization_id
      AND booking.id =
          booking_shoot_completions.booking_id
      AND public.has_permission(
            booking.organization_id,
            'booking.read',
            booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(
             booking.organization_id,
             booking.branch_id
           )
      )
  )
);

-- =====================================================================
-- Section D — Controlled completion-recording RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_shoot_completion(
  p_booking_id uuid,
  p_completed_at timestamptz
)
RETURNS public.booking_shoot_completions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_schedule public.booking_shoot_schedules;

  v_existing public.booking_shoot_completions;
  v_result public.booking_shoot_completions;

  v_actor uuid;

  v_state_count integer := 0;

  v_recorded_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_completed_at IS NULL THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: completed_at is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  v_recorded_at := now();

  IF p_completed_at > v_recorded_at THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: completed_at cannot be in the future'
      USING ERRCODE = '22023';
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
      'record_booking_shoot_completion: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active member + narrow permission + branch scope.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'shoot.complete',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: shoot.complete permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exactly one canonical current journey state.
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
      'record_booking_shoot_completion: booking must have exactly one current journey state'
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
      'record_booking_shoot_completion: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 10
     OR v_stage.stage_key <>
          'shoot_scheduled' THEN
    RAISE EXCEPTION
      'record_booking_shoot_completion: booking must be exactly Shoot Scheduled'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: current authoritative schedule tip.
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
      'record_booking_shoot_completion: current authoritative reserved shoot schedule required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 4: immutable completion evidence / replay.
  --
  -- Booking lock serializes competing completion attempts for the
  -- same booking.
  -- ---------------------------------------------------------------

  SELECT completion.*
  INTO v_existing
  FROM public.booking_shoot_completions completion
  WHERE completion.organization_id =
        v_booking.organization_id
    AND completion.booking_id =
        v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.completed_at
         IS DISTINCT FROM
       p_completed_at THEN
      RAISE EXCEPTION
        'record_booking_shoot_completion: completion evidence already exists with a different completed_at'
        USING ERRCODE = '22023';
    END IF;

    RETURN v_existing;
  END IF;

  -- ---------------------------------------------------------------
  -- Append immutable completion evidence.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_shoot_completions (
    organization_id,
    booking_id,
    completed_at,
    recorded_at,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    p_completed_at,
    v_recorded_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  -- ---------------------------------------------------------------
  -- One structural non-sensitive audit event.
  --
  -- No Safety state, restricted readiness evidence, family notes or
  -- arbitrary user-supplied text is included.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.shoot_completion_recorded',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'completed_at',
        v_result.completed_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'completion_id',
        v_result.id,
      'completed_at',
        v_result.completed_at,
      'recorded_by',
        v_actor
    ),
    'application',
    NULL
  );

  -- ---------------------------------------------------------------
  -- Journey intentionally remains Stage 10.
  -- No booking_journey_states or booking_stage_transitions mutation.
  -- ---------------------------------------------------------------

  RETURN v_result;
END;
$$;

-- =====================================================================
-- Section E — RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.record_booking_shoot_completion(uuid,timestamptz)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.record_booking_shoot_completion(uuid,timestamptz)
FROM anon;

REVOKE ALL
ON FUNCTION public.record_booking_shoot_completion(uuid,timestamptz)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.record_booking_shoot_completion(uuid,timestamptz)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.record_booking_shoot_completion(uuid,timestamptz)
TO authenticated;

COMMENT ON FUNCTION public.record_booking_shoot_completion(uuid,timestamptz) IS
  'Record immutable canonical Shoot Completion evidence for an authorized booking at exact Stage 10 Shoot Scheduled without advancing the journey.';

-- =====================================================================
-- Section F — Migration assertions
-- =====================================================================

DO $s11_slice1_assertions$
DECLARE
  v_count integer;
  v_expected integer;
BEGIN
  -- Permission catalogue contract.
  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key = 'shoot.complete'
    AND permission.domain = 'bookings'
    AND permission.label = 'Record shoot completion'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: shoot.complete permission contract invalid';
  END IF;

  -- Exact role-grant contract.
  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  WHERE permission.key = 'shoot.complete';

  SELECT count(*)
  INTO v_expected
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key = 'shoot.complete'
    AND role.key IN (
      'founder',
      'studio_manager',
      'photographer'
    );

  IF v_count <> 3
     OR v_expected <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: shoot.complete role grants invalid';
  END IF;

  -- Evidence relation contract.
  IF to_regclass(
       'public.booking_shoot_completions'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: completion relation unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace
    ON namespace.oid =
       relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname =
        'booking_shoot_completions'
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: completion RLS contract invalid';
  END IF;

  -- Authenticated table mutation remains unavailable.
  IF has_table_privilege(
       'authenticated',
       'public.booking_shoot_completions',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_shoot_completions',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_shoot_completions',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: authenticated direct mutation must be denied';
  END IF;

  IF NOT has_table_privilege(
           'authenticated',
           'public.booking_shoot_completions',
           'SELECT'
         ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: authenticated SELECT unavailable';
  END IF;

  -- Controlled RPC signature/security contract.
  IF to_regprocedure(
       'public.record_booking_shoot_completion(uuid,timestamp with time zone)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: completion RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc procedure
  JOIN pg_namespace namespace
    ON namespace.oid =
       procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname =
        'record_booking_shoot_completion'
    AND pg_get_function_identity_arguments(
          procedure.oid
        ) =
        'p_booking_id uuid, p_completed_at timestamp with time zone'
    AND pg_get_function_result(
          procedure.oid
        ) =
        'booking_shoot_completions'
    AND procedure.prosecdef
    AND procedure.proconfig =
        ARRAY['search_path=""']::text[];

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: completion RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.record_booking_shoot_completion(uuid,timestamptz)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: authenticated RPC EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.record_booking_shoot_completion(uuid,timestamptz)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: anon RPC EXECUTE must be denied';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.record_booking_shoot_completion(uuid,timestamptz)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 1 validation failed: service_role RPC EXECUTE must remain unavailable';
  END IF;
END
$s11_slice1_assertions$;
