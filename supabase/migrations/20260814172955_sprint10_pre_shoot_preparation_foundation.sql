-- =====================================================================
-- Sprint 10 — Slice 2
-- Pre-Shoot Preparation Instance + Controlled Stage 8 -> 9 Gate
--
-- This migration establishes:
--   * prep.read / prep.write permissions
--   * canonical immutable booking_preparations evidence
--   * forced RLS / SELECT-only authenticated access
--   * controlled start_pre_shoot_preparation(uuid)
--   * exact Booking Confirmed -> Pre-Shoot Preparation transition
--
-- Preparation items, team assignment, safety readiness/signoff and
-- Stage 9 -> 10 progression remain outside this Slice 2 migration.
-- =====================================================================

-- =====================================================================
-- Section A — Narrow preparation permissions
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES
(
  'prep.read',
  'bookings',
  'View pre-shoot preparation',
  'Read canonical pre-shoot preparation evidence within the permitted booking scope.',
  true
),
(
  'prep.write',
  'bookings',
  'Manage pre-shoot preparation',
  'Create and later update canonical pre-shoot preparation through controlled operations.',
  true
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM (
  VALUES
    ('founder', 'prep.read'),
    ('founder', 'prep.write'),
    ('studio_manager', 'prep.read'),
    ('studio_manager', 'prep.write'),
    ('client_coordinator', 'prep.read'),
    ('client_coordinator', 'prep.write')
) AS approved(role_key, permission_key)
JOIN public.roles r
  ON r.key = approved.role_key
JOIN public.permissions p
  ON p.key = approved.permission_key;

DO $s10_slice2_permission_assertions$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.permissions p
  WHERE p.key IN (
    'prep.read',
    'prep.write'
  );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 2 permission gate failed: expected exactly 2 preparation permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  JOIN public.roles r
    ON r.id = rp.role_id
  WHERE p.key IN (
      'prep.read',
      'prep.write'
    )
    AND r.key IN (
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_count <> 6 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 2 permission gate failed: expected exactly 6 approved preparation role grants, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  JOIN public.roles r
    ON r.id = rp.role_id
  WHERE p.key IN (
      'prep.read',
      'prep.write'
    )
    AND r.key NOT IN (
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 2 permission gate failed: unexpected preparation role grants found';
  END IF;
END
$s10_slice2_permission_assertions$;

-- =====================================================================
-- Section B1 — Canonical pre-shoot preparation evidence
-- =====================================================================

CREATE TABLE public.booking_preparations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  booking_id      uuid NOT NULL,

  started_at      timestamptz NOT NULL DEFAULT now(),
  started_by      uuid NOT NULL,

  CONSTRAINT booking_preparations_booking_fkey
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

  CONSTRAINT booking_preparations_started_by_fkey
    FOREIGN KEY (
      started_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_preparations_organization_id_id_key
    UNIQUE (
      organization_id,
      id
    ),

  CONSTRAINT booking_preparations_organization_booking_key
    UNIQUE (
      organization_id,
      booking_id
    )
);

-- =====================================================================
-- Section B2 — Immutable preparation-instance guard
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_booking_preparation_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking preparation evidence is append-only and immutable';
  END IF;

  IF auth.uid() IS NOT NULL
     AND public.current_organization_member(
           NEW.organization_id
         ) IS DISTINCT FROM NEW.started_by THEN
    RAISE EXCEPTION
      'booking preparation actor must be the current active organization member';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_preparations_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_preparations
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_preparation_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_preparation_guard()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.lsh_booking_preparation_guard()
TO service_role;

-- =====================================================================
-- Section B3 — Row-level security and direct-write denial
-- =====================================================================

ALTER TABLE public.booking_preparations
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_preparations
FORCE ROW LEVEL SECURITY;

CREATE POLICY booking_preparations_authenticated_select
ON public.booking_preparations
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          booking_preparations.organization_id
      AND b.id =
          booking_preparations.booking_id
      AND public.has_permission(
            b.organization_id,
            'prep.read',
            b.branch_id
          )
      AND (
        b.branch_id IS NULL
        OR public.has_branch_scope(
             b.organization_id,
             b.branch_id
           )
      )
  )
);

REVOKE ALL PRIVILEGES
ON TABLE public.booking_preparations
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_preparations
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE public.booking_preparations
TO service_role;

-- =====================================================================
-- Section C1 — Start canonical pre-shoot preparation
-- =====================================================================

CREATE OR REPLACE FUNCTION public.start_pre_shoot_preparation(
  p_booking_id uuid
)
RETURNS public.booking_preparations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_existing public.booking_preparations;
  v_preparation public.booking_preparations;
  v_schedule public.booking_shoot_schedules;

  v_actor uuid;
  v_preparation_stage_id uuid;

  v_state_count integer;
  v_has_existing boolean := false;

  v_transitioned_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input and authentication boundary.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Serialize operational mutations for this booking.
  -- ---------------------------------------------------------------

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Both frozen permissions are independently required.
  -- ---------------------------------------------------------------

  IF NOT public.has_permission(
           v_booking.organization_id,
           'prep.write',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: prep.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Exactly one canonical current journey state must exist.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states js
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT js.*
  INTO v_state
  FROM public.booking_journey_states js
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id
  FOR UPDATE;

  SELECT s.*
  INTO v_stage
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.id =
        v_state.current_stage_id
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve the single canonical preparation instance, if present.
  -- ---------------------------------------------------------------

  SELECT p.*
  INTO v_existing
  FROM public.booking_preparations p
  WHERE p.organization_id =
        v_booking.organization_id
    AND p.booking_id =
        v_booking.id;

  v_has_existing := FOUND;

  -- ---------------------------------------------------------------
  -- Exact Stage 9 replay is idempotent.
  --
  -- It returns the existing authoritative preparation without
  -- appending preparation, transition or audit evidence.
  -- ---------------------------------------------------------------

  IF v_stage.stage_key = 'pre_shoot_preparation'
     AND v_stage.stage_order = 9 THEN
    IF NOT v_has_existing THEN
      RAISE EXCEPTION
        'start_pre_shoot_preparation: Stage 9 requires an authoritative preparation instance'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing;
  END IF;

  -- ---------------------------------------------------------------
  -- First execution is legal only from canonical Stage 8.
  -- ---------------------------------------------------------------

  IF v_stage.stage_key <> 'booking_confirmed'
     OR v_stage.stage_order <> 8 THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking must be exactly Booking Confirmed or an exact Pre-Shoot Preparation replay'
      USING ERRCODE = '22023';
  END IF;

  -- Stage 8 with preparation evidence already present represents an
  -- impossible partial prior execution and must not be treated as
  -- successful replay.
  IF v_has_existing THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: Stage 8 cannot already contain a preparation instance'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Latest schedule version must be authoritative and reserved.
  -- ---------------------------------------------------------------

  SELECT s.*
  INTO v_schedule
  FROM public.booking_shoot_schedules s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.booking_id =
        v_booking.id
  ORDER BY s.schedule_version DESC
  LIMIT 1;

  IF NOT FOUND
     OR v_schedule.schedule_state <> 'reserved' THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: current authoritative reserved schedule required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve canonical Stage 9.
  -- ---------------------------------------------------------------

  SELECT s.id
  INTO v_preparation_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.stage_key =
        'pre_shoot_preparation'
    AND s.stage_order = 9
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: canonical Pre-Shoot Preparation stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Create the one authoritative preparation instance.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_preparations (
    organization_id,
    booking_id,
    started_at,
    started_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_transitioned_at,
    v_actor
  )
  RETURNING *
  INTO v_preparation;

  -- ---------------------------------------------------------------
  -- Append dedicated Stage 8 -> 9 historical evidence.
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
    v_preparation_stage_id,
    'pre_shoot_preparation_started',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Advance current journey state exactly once.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states js
  SET
    current_stage_id =
      v_preparation_stage_id,
    stage_entered_at =
      v_transitioned_at,
    version =
      js.version + 1,
    updated_at =
      v_transitioned_at,
    updated_by =
      v_actor
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id
    AND js.current_stage_id =
        v_state.current_stage_id
    AND js.version =
        v_state.version;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: journey state changed during preparation start'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- Append non-sensitive audit evidence.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.pre_shoot_preparation_started',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage',
        'booking_confirmed',
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'pre_shoot_preparation',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'preparation_id',
        v_preparation.id,
      'reserved_schedule_id',
        v_schedule.id,
      'reserved_schedule_version',
        v_schedule.schedule_version,
      'transition_key',
        'pre_shoot_preparation_started'
    ),
    'application',
    NULL
  );

  RETURN v_preparation;
END
$$;

-- =====================================================================
-- Section C2 — Start-preparation RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.start_pre_shoot_preparation(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.start_pre_shoot_preparation(uuid)
TO authenticated;
