-- =====================================================================
-- Sprint 10 — Pre-Shoot Preparation, Safety Readiness &
-- Shoot Scheduling Foundation
--
-- Slice 1 — Shoot Scheduling Evidence + Confirmation Reservation Gate
-- Section A — Narrow shoot-scheduling permission
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'shoot.schedule',
  'bookings',
  'Schedule booking shoot',
  'Create proposed shoot plans and authoritative booking shoot reschedule evidence through controlled server-enforced operations.',
  true
);

DO $s10_schedule_roles$
DECLARE
  v_role_count integer;
BEGIN
  SELECT count(*)
  INTO v_role_count
  FROM public.roles r
  WHERE r.key IN (
    'founder',
    'studio_manager',
    'client_coordinator'
  );

  IF v_role_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 10 scheduling precondition failed: expected Founder, Studio Manager and Client Coordinator roles';
  END IF;
END
$s10_schedule_roles$;

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.key IN (
    'founder',
    'studio_manager',
    'client_coordinator'
  )
  AND p.key = 'shoot.schedule'
ON CONFLICT (role_id, permission_id) DO NOTHING;

DO $s10_schedule_grants$
DECLARE
  v_total_grants integer;
  v_expected_grants integer;
BEGIN
  SELECT count(*)
  INTO v_total_grants
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  WHERE p.key = 'shoot.schedule';

  SELECT count(*)
  INTO v_expected_grants
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  JOIN public.roles r
    ON r.id = rp.role_id
  WHERE p.key = 'shoot.schedule'
    AND r.key IN (
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_total_grants <> 3
     OR v_expected_grants <> 3 THEN
    RAISE EXCEPTION
      'Sprint 10 scheduling permission grant invariant failed';
  END IF;
END
$s10_schedule_grants$;

-- =====================================================================
-- Section B1 — Canonical booking shoot schedule evidence
-- =====================================================================

CREATE TABLE public.booking_shoot_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  schedule_version integer NOT NULL,
  predecessor_schedule_id uuid,

  schedule_state text NOT NULL,

  scheduled_start_at timestamptz NOT NULL,
  scheduled_end_at timestamptz NOT NULL,
  timezone text NOT NULL,

  location_type text NOT NULL,
  location_details text,

  reschedule_reason text,

  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid NOT NULL,

  CONSTRAINT booking_shoot_schedules_version_positive_chk
    CHECK (schedule_version > 0),

  CONSTRAINT booking_shoot_schedules_state_chk
    CHECK (
      schedule_state IN (
        'proposed',
        'reserved'
      )
    ),

  CONSTRAINT booking_shoot_schedules_time_range_chk
    CHECK (
      scheduled_end_at > scheduled_start_at
    ),

  CONSTRAINT booking_shoot_schedules_timezone_not_blank_chk
    CHECK (
      btrim(timezone) <> ''
    ),

  CONSTRAINT booking_shoot_schedules_location_type_not_blank_chk
    CHECK (
      btrim(location_type) <> ''
    ),

  CONSTRAINT booking_shoot_schedules_location_details_not_blank_chk
    CHECK (
      location_details IS NULL
      OR btrim(location_details) <> ''
    ),

  CONSTRAINT booking_shoot_schedules_reschedule_reason_not_blank_chk
    CHECK (
      reschedule_reason IS NULL
      OR btrim(reschedule_reason) <> ''
    ),

  CONSTRAINT booking_shoot_schedules_lineage_presence_chk
    CHECK (
      (
        schedule_version = 1
        AND predecessor_schedule_id IS NULL
      )
      OR (
        schedule_version > 1
        AND predecessor_schedule_id IS NOT NULL
      )
    ),

  CONSTRAINT booking_shoot_schedules_booking_fkey
    FOREIGN KEY (
      booking_id,
      organization_id
    )
    REFERENCES public.bookings (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_shoot_schedules_recorded_by_fkey
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

  CONSTRAINT booking_shoot_schedules_id_org_booking_key
    UNIQUE (
      id,
      organization_id,
      booking_id
    ),

  CONSTRAINT booking_shoot_schedules_booking_version_key
    UNIQUE (
      organization_id,
      booking_id,
      schedule_version
    ),

  CONSTRAINT booking_shoot_schedules_predecessor_fkey
    FOREIGN KEY (
      predecessor_schedule_id,
      organization_id,
      booking_id
    )
    REFERENCES public.booking_shoot_schedules (
      id,
      organization_id,
      booking_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

CREATE INDEX booking_shoot_schedules_org_booking_recorded_idx
  ON public.booking_shoot_schedules (
    organization_id,
    booking_id,
    recorded_at DESC
  );

CREATE INDEX booking_shoot_schedules_org_booking_state_version_idx
  ON public.booking_shoot_schedules (
    organization_id,
    booking_id,
    schedule_state,
    schedule_version DESC
  );

CREATE INDEX booking_shoot_schedules_predecessor_idx
  ON public.booking_shoot_schedules (
    predecessor_schedule_id
  )
  WHERE predecessor_schedule_id IS NOT NULL;

-- =====================================================================
-- Section B2 — Immutable schedule lineage guard
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_booking_shoot_schedule_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_latest public.booking_shoot_schedules;
  v_current_actor uuid;
BEGIN
  -- Historical schedule evidence is never rewritten or deleted.
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking shoot schedule evidence is append-only and immutable';
  END IF;

  -- Authenticated evidence must identify the same active member
  -- represented by the current authenticated user.
  IF auth.uid() IS NOT NULL THEN
    v_current_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_current_actor IS NULL
       OR NEW.recorded_by <> v_current_actor THEN
      RAISE EXCEPTION
        'booking shoot schedule actor must be the current active organization member';
    END IF;
  END IF;

  -- Resolve the current immutable schedule tip for this booking.
  SELECT s.*
  INTO v_latest
  FROM public.booking_shoot_schedules s
  WHERE s.organization_id =
        NEW.organization_id
    AND s.booking_id =
        NEW.booking_id
  ORDER BY s.schedule_version DESC
  LIMIT 1;

  -- First schedule evidence must always be an unreserved proposal.
  IF NOT FOUND THEN
    IF NEW.schedule_version <> 1
       OR NEW.predecessor_schedule_id IS NOT NULL
       OR NEW.schedule_state <> 'proposed'
       OR NEW.reschedule_reason IS NOT NULL THEN
      RAISE EXCEPTION
        'initial booking shoot schedule must be proposal version 1 without predecessor or reschedule reason';
    END IF;

    RETURN NEW;
  END IF;

  -- Every later row must extend the exact current tip by one version.
  IF NEW.schedule_version <>
       v_latest.schedule_version + 1 THEN
    RAISE EXCEPTION
      'booking shoot schedule version must extend the current schedule tip by exactly one';
  END IF;

  IF NEW.predecessor_schedule_id
       IS DISTINCT FROM
         v_latest.id THEN
    RAISE EXCEPTION
      'booking shoot schedule predecessor must be the current schedule tip';
  END IF;

  IF NEW.recorded_at <
       v_latest.recorded_at THEN
    RAISE EXCEPTION
      'booking shoot schedule recorded_at cannot precede its predecessor';
  END IF;

  -- A reserved shoot can never become merely proposed again.
  IF v_latest.schedule_state = 'reserved'
     AND NEW.schedule_state <> 'reserved' THEN
    RAISE EXCEPTION
      'reserved booking shoot schedule cannot return to proposed state';
  END IF;

  -- Reschedule reasons belong only to authoritative post-confirmation
  -- reserved -> reserved replacements.
  IF v_latest.schedule_state = 'reserved'
     AND NEW.schedule_state = 'reserved' THEN
    IF NEW.reschedule_reason IS NULL THEN
      RAISE EXCEPTION
        'reserved booking shoot reschedule requires a reason';
    END IF;
  ELSE
    IF NEW.reschedule_reason IS NOT NULL THEN
      RAISE EXCEPTION
        'reschedule reason is allowed only for reserved booking shoot reschedules';
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_shoot_schedules_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_shoot_schedules
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_shoot_schedule_guard();

-- =====================================================================
-- Section B3 — Row-level security and direct-write denial
-- =====================================================================

ALTER TABLE public.booking_shoot_schedules
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_shoot_schedules
  FORCE ROW LEVEL SECURITY;

-- No anonymous access and no authenticated direct mutation path.
REVOKE ALL
ON TABLE public.booking_shoot_schedules
FROM PUBLIC;

REVOKE ALL
ON TABLE public.booking_shoot_schedules
FROM anon;

REVOKE ALL
ON TABLE public.booking_shoot_schedules
FROM authenticated;

-- Authenticated users may read schedule evidence only through the same
-- booking-read + branch-scope boundary as the authoritative booking.
GRANT SELECT
ON TABLE public.booking_shoot_schedules
TO authenticated;

CREATE POLICY booking_shoot_schedules_authenticated_select
ON public.booking_shoot_schedules
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          booking_shoot_schedules.organization_id
      AND b.id =
          booking_shoot_schedules.booking_id
      AND public.has_permission(
        b.organization_id,
        'booking.read',
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

-- The guard exists only as a trigger boundary.
REVOKE ALL
ON FUNCTION public.lsh_booking_shoot_schedule_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.lsh_booking_shoot_schedule_guard()
FROM anon;

REVOKE ALL
ON FUNCTION public.lsh_booking_shoot_schedule_guard()
FROM authenticated;

-- =====================================================================
-- Section C1 — Propose booking shoot schedule
-- =====================================================================

CREATE OR REPLACE FUNCTION public.propose_booking_shoot_schedule(
  p_booking_id uuid,
  p_scheduled_start_at timestamptz,
  p_scheduled_end_at timestamptz,
  p_timezone text,
  p_location_type text,
  p_location_details text DEFAULT NULL
)
RETURNS public.booking_shoot_schedules
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_latest public.booking_shoot_schedules;
  v_new public.booking_shoot_schedules;

  v_actor uuid;
  v_advance_stage_id uuid;

  v_state_count integer := 0;
  v_next_version integer := 1;
  v_predecessor_id uuid;
BEGIN
  -- ---------------------------------------------------------------
  -- Input validation.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_scheduled_start_at IS NULL
     OR p_scheduled_end_at IS NULL THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: scheduled start and end are required'
      USING ERRCODE = '22023';
  END IF;

  IF p_scheduled_end_at <= p_scheduled_start_at THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: scheduled end must be after scheduled start'
      USING ERRCODE = '22023';
  END IF;

  IF p_timezone IS NULL
     OR btrim(p_timezone) = '' THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: timezone is required'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_timezone_names tz
    WHERE tz.name = btrim(p_timezone)
  ) THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: timezone is not recognized'
      USING ERRCODE = '22023';
  END IF;

  IF p_location_type IS NULL
     OR btrim(p_location_type) = '' THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: location_type is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_location_details IS NOT NULL
     AND btrim(p_location_details) = '' THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: location_details cannot be blank when supplied'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Serialize all schedule and confirmation mutations for booking.
  -- ---------------------------------------------------------------

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active actor + branch-aware scheduling authorization.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'shoot.schedule',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: shoot.schedule permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_booking.organization_id,
       v_booking.branch_id
     ) THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: no access to booking branch'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical journey state must exist exactly once.
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
      'propose_booking_shoot_schedule: booking must have exactly one current journey state'
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

  SELECT s.id
  INTO v_advance_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.stage_key = 'advance_pending'
    AND s.stage_order = 7
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: active Advance Pending stage 7 unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_state.current_stage_id
       IS DISTINCT FROM v_advance_stage_id THEN
    RAISE EXCEPTION
      'propose_booking_shoot_schedule: booking must be at Advance Pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve current immutable schedule tip.
  --
  -- Re-proposals at Stage 7 append a new proposed version. They do
  -- not reserve the date.
  -- ---------------------------------------------------------------

  SELECT s.*
  INTO v_latest
  FROM public.booking_shoot_schedules s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.booking_id =
        v_booking.id
  ORDER BY s.schedule_version DESC
  LIMIT 1;

  IF FOUND THEN
    IF v_latest.schedule_state <> 'proposed' THEN
      RAISE EXCEPTION
        'propose_booking_shoot_schedule: current schedule tip must be proposed'
        USING ERRCODE = 'P0001';
    END IF;

    -- Exact replay of the current proposal is idempotent.
    IF v_latest.scheduled_start_at
         IS NOT DISTINCT FROM p_scheduled_start_at
       AND v_latest.scheduled_end_at
         IS NOT DISTINCT FROM p_scheduled_end_at
       AND v_latest.timezone =
         btrim(p_timezone)
       AND v_latest.location_type =
         btrim(p_location_type)
       AND v_latest.location_details
         IS NOT DISTINCT FROM
           (
             CASE
               WHEN p_location_details IS NULL THEN NULL
               ELSE btrim(p_location_details)
             END
           ) THEN
      RETURN v_latest;
    END IF;

    v_next_version :=
      v_latest.schedule_version + 1;

    v_predecessor_id :=
      v_latest.id;
  ELSE
    v_next_version := 1;
    v_predecessor_id := NULL;
  END IF;

  -- ---------------------------------------------------------------
  -- Append proposal evidence.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_shoot_schedules (
    organization_id,
    booking_id,
    schedule_version,
    predecessor_schedule_id,
    schedule_state,
    scheduled_start_at,
    scheduled_end_at,
    timezone,
    location_type,
    location_details,
    reschedule_reason,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_next_version,
    v_predecessor_id,
    'proposed',
    p_scheduled_start_at,
    p_scheduled_end_at,
    btrim(p_timezone),
    btrim(p_location_type),
    CASE
      WHEN p_location_details IS NULL THEN NULL
      ELSE btrim(p_location_details)
    END,
    NULL,
    v_actor
  )
  RETURNING *
  INTO v_new;

  -- ---------------------------------------------------------------
  -- Append audit evidence.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.shoot_schedule.proposed',
    'booking_shoot_schedule',
    v_new.id,
    false,
    CASE
      WHEN v_latest.id IS NULL THEN NULL
      ELSE jsonb_build_object(
        'schedule_id',
          v_latest.id,
        'schedule_version',
          v_latest.schedule_version,
        'schedule_state',
          v_latest.schedule_state,
        'scheduled_start_at',
          v_latest.scheduled_start_at,
        'scheduled_end_at',
          v_latest.scheduled_end_at
      )
    END,
    jsonb_build_object(
      'schedule_id',
        v_new.id,
      'schedule_version',
        v_new.schedule_version,
      'schedule_state',
        v_new.schedule_state,
      'scheduled_start_at',
        v_new.scheduled_start_at,
      'scheduled_end_at',
        v_new.scheduled_end_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'predecessor_schedule_id',
        v_new.predecessor_schedule_id,
      'timezone',
        v_new.timezone,
      'location_type',
        v_new.location_type,
      'journey_stage',
        'advance_pending'
    ),
    'application',
    NULL
  );

  RETURN v_new;
END
$$;

-- =====================================================================
-- Section C2 — Proposal RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.propose_booking_shoot_schedule(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.propose_booking_shoot_schedule(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text
)
FROM anon;

REVOKE ALL
ON FUNCTION public.propose_booking_shoot_schedule(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text
)
FROM authenticated;

GRANT EXECUTE
ON FUNCTION public.propose_booking_shoot_schedule(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text
)
TO authenticated;

COMMENT ON FUNCTION public.propose_booking_shoot_schedule(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text
)
IS
  'Append a non-reserving Stage 7 shoot proposal through the branch-aware shoot.schedule authorization boundary.';

-- =====================================================================
-- Section D1 — Reschedule authoritative booking shoot
-- =====================================================================

CREATE OR REPLACE FUNCTION public.reschedule_booking_shoot(
  p_booking_id uuid,
  p_scheduled_start_at timestamptz,
  p_scheduled_end_at timestamptz,
  p_timezone text,
  p_location_type text,
  p_reschedule_reason text,
  p_location_details text DEFAULT NULL
)
RETURNS public.booking_shoot_schedules
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_latest public.booking_shoot_schedules;
  v_new public.booking_shoot_schedules;

  v_actor uuid;
  v_state_count integer := 0;
BEGIN
  -- ---------------------------------------------------------------
  -- Input validation.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_scheduled_start_at IS NULL
     OR p_scheduled_end_at IS NULL THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: scheduled start and end are required'
      USING ERRCODE = '22023';
  END IF;

  IF p_scheduled_end_at <= p_scheduled_start_at THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: scheduled end must be after scheduled start'
      USING ERRCODE = '22023';
  END IF;

  IF p_timezone IS NULL
     OR btrim(p_timezone) = '' THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: timezone is required'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_timezone_names tz
    WHERE tz.name = btrim(p_timezone)
  ) THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: timezone is not recognized'
      USING ERRCODE = '22023';
  END IF;

  IF p_location_type IS NULL
     OR btrim(p_location_type) = '' THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: location_type is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_location_details IS NOT NULL
     AND btrim(p_location_details) = '' THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: location_details cannot be blank when supplied'
      USING ERRCODE = '22023';
  END IF;

  IF p_reschedule_reason IS NULL
     OR btrim(p_reschedule_reason) = '' THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: reschedule reason is required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Serialize all schedule mutations for this booking.
  -- ---------------------------------------------------------------

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active actor + branch-aware scheduling authorization.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'shoot.schedule',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: shoot.schedule permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_booking.organization_id,
       v_booking.branch_id
     ) THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: no access to booking branch'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical journey state must exist exactly once.
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
      'reschedule_booking_shoot: booking must have exactly one current journey state'
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
      'reschedule_booking_shoot: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order NOT BETWEEN 8 AND 10
     OR v_stage.stage_key NOT IN (
       'booking_confirmed',
       'pre_shoot_preparation',
       'shoot_scheduled'
     ) THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: booking must be within Booking Confirmed through Shoot Scheduled'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- An authoritative reserved schedule must already exist.
  -- ---------------------------------------------------------------

  SELECT s.*
  INTO v_latest
  FROM public.booking_shoot_schedules s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.booking_id =
        v_booking.id
  ORDER BY s.schedule_version DESC
  LIMIT 1;

  IF NOT FOUND
     OR v_latest.schedule_state <> 'reserved' THEN
    RAISE EXCEPTION
      'reschedule_booking_shoot: current authoritative reserved schedule required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact replay of the latest reschedule is idempotent.
  -- ---------------------------------------------------------------

  IF v_latest.scheduled_start_at
       IS NOT DISTINCT FROM p_scheduled_start_at
     AND v_latest.scheduled_end_at
       IS NOT DISTINCT FROM p_scheduled_end_at
     AND v_latest.timezone =
       btrim(p_timezone)
     AND v_latest.location_type =
       btrim(p_location_type)
     AND v_latest.location_details
       IS NOT DISTINCT FROM
         (
           CASE
             WHEN p_location_details IS NULL THEN NULL
             ELSE btrim(p_location_details)
           END
         )
     AND v_latest.reschedule_reason
       IS NOT DISTINCT FROM
         btrim(p_reschedule_reason) THEN
    RETURN v_latest;
  END IF;

  -- ---------------------------------------------------------------
  -- Append immutable reserved replacement evidence.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_shoot_schedules (
    organization_id,
    booking_id,
    schedule_version,
    predecessor_schedule_id,
    schedule_state,
    scheduled_start_at,
    scheduled_end_at,
    timezone,
    location_type,
    location_details,
    reschedule_reason,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_latest.schedule_version + 1,
    v_latest.id,
    'reserved',
    p_scheduled_start_at,
    p_scheduled_end_at,
    btrim(p_timezone),
    btrim(p_location_type),
    CASE
      WHEN p_location_details IS NULL THEN NULL
      ELSE btrim(p_location_details)
    END,
    btrim(p_reschedule_reason),
    v_actor
  )
  RETURNING *
  INTO v_new;

  -- ---------------------------------------------------------------
  -- Append audit evidence.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.shoot_schedule.rescheduled',
    'booking_shoot_schedule',
    v_new.id,
    false,
    jsonb_build_object(
      'schedule_id',
        v_latest.id,
      'schedule_version',
        v_latest.schedule_version,
      'schedule_state',
        v_latest.schedule_state,
      'scheduled_start_at',
        v_latest.scheduled_start_at,
      'scheduled_end_at',
        v_latest.scheduled_end_at
    ),
    jsonb_build_object(
      'schedule_id',
        v_new.id,
      'schedule_version',
        v_new.schedule_version,
      'schedule_state',
        v_new.schedule_state,
      'scheduled_start_at',
        v_new.scheduled_start_at,
      'scheduled_end_at',
        v_new.scheduled_end_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'predecessor_schedule_id',
        v_new.predecessor_schedule_id,
      'timezone',
        v_new.timezone,
      'location_type',
        v_new.location_type,
      'reschedule_reason',
        v_new.reschedule_reason,
      'journey_stage',
        v_stage.stage_key,
      'journey_version',
        v_state.version
    ),
    'application',
    NULL
  );

  RETURN v_new;
END
$$;

-- =====================================================================
-- Section D2 — Reschedule RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.reschedule_booking_shoot(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.reschedule_booking_shoot(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text
)
FROM anon;

REVOKE ALL
ON FUNCTION public.reschedule_booking_shoot(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text
)
FROM authenticated;

GRANT EXECUTE
ON FUNCTION public.reschedule_booking_shoot(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text
)
TO authenticated;

COMMENT ON FUNCTION public.reschedule_booking_shoot(
  uuid,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text
)
IS
  'Append an immutable reserved shoot reschedule for a booking in canonical stages 8 through 10 through the branch-aware shoot.schedule authorization boundary.';


-- =====================================================================
-- Section E1 — Reserve proposed shoot plan during booking confirmation
-- =====================================================================

CREATE OR REPLACE FUNCTION public.confirm_booking_after_advance(
  p_booking_id uuid
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_quote public.quotations;
  v_requirement public.booking_payment_requirements;
  v_state public.booking_journey_states;
  v_schedule public.booking_shoot_schedules;
  v_reserved_schedule public.booking_shoot_schedules;

  v_actor uuid;

  v_advance_stage_id uuid;
  v_confirmed_stage_id uuid;

  v_valid_collected bigint := 0;
  v_confirmation_count integer := 0;
  v_state_count integer := 0;

  v_transitioned_at timestamptz;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Serialize every confirmation attempt for this booking.
  -- ---------------------------------------------------------------

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'booking.confirm',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking.confirm permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_booking.organization_id,
       v_booking.branch_id
     ) THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: no access to booking branch'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical journey state must exist exactly once.
  -- Lock it together with the booking serialization boundary.
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
      'confirm_booking_after_advance: booking must have exactly one current journey state'
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

  SELECT s.id
  INTO v_advance_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.stage_key = 'advance_pending'
    AND s.stage_order = 7
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: active Advance Pending stage 7 unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT s.id
  INTO v_confirmed_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.stage_key = 'booking_confirmed'
    AND s.stage_order = 8
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: active Booking Confirmed stage 8 unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Idempotent replay.
  --
  -- Once this exact historical transition exists, confirmation has
  -- already happened legitimately. Replays return the same booking
  -- even if the journey later progresses or a later payment reversal
  -- creates a current financial shortfall.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_confirmation_count
  FROM public.booking_stage_transitions t
  WHERE t.organization_id =
        v_booking.organization_id
    AND t.booking_id =
        v_booking.id
    AND t.from_stage_id =
        v_advance_stage_id
    AND t.to_stage_id =
        v_confirmed_stage_id
    AND t.transition_key =
        'advance_satisfied';

  IF v_confirmation_count > 1 THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: duplicate historical confirmation evidence detected'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_confirmation_count = 1 THEN
    RETURN v_booking;
  END IF;

  -- ---------------------------------------------------------------
  -- First-time confirmation must start exactly at Stage 7.
  -- ---------------------------------------------------------------

  IF v_state.current_stage_id
       IS DISTINCT FROM v_advance_stage_id THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking must be at Advance Pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- First-time confirmation now also creates authoritative schedule
  -- evidence. Exact historical replay above remains mutation-free.
  -- ---------------------------------------------------------------

  -- ---------------------------------------------------------------
  -- Accepted quotation linkage remains authoritative.
  -- ---------------------------------------------------------------

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.organization_id =
        v_booking.organization_id
    AND q.id =
        v_booking.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <> 'accepted' THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking requires accepted quotation'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_quote.currency <> 'INR'
     OR v_quote.quoted_total_inr <= 0 THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: accepted quotation must be positive INR'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Frozen advance requirement must exactly match the accepted quote.
  -- ---------------------------------------------------------------

  SELECT r.*
  INTO v_requirement
  FROM public.booking_payment_requirements r
  WHERE r.organization_id =
        v_booking.organization_id
    AND r.booking_id =
        v_booking.id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking payment requirement missing'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_requirement.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id
     OR v_requirement.source_quotation_id
       IS DISTINCT FROM
         v_quote.id
     OR v_requirement.currency <> 'INR'
     OR v_requirement.currency
       IS DISTINCT FROM
         v_quote.currency
     OR v_requirement.accepted_quotation_total_inr
       IS DISTINCT FROM
         v_quote.quoted_total_inr
     OR v_requirement.advance_percentage <> 50
     OR v_requirement.calculation_rule <>
          'accepted_quote_50_percent_round_half_up'
     OR v_requirement.required_advance_inr
       IS DISTINCT FROM
         ((v_quote.quoted_total_inr + 1) / 2) THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: payment requirement does not match accepted quotation snapshot'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Financial gate:
  -- only non-reversed payment evidence counts.
  -- ---------------------------------------------------------------

  SELECT COALESCE(
    sum(p.amount_inr)
      FILTER (
        WHERE rv.id IS NULL
      ),
    0
  )::bigint
  INTO v_valid_collected
  FROM public.booking_payments p
  LEFT JOIN public.booking_payment_reversals rv
    ON rv.organization_id =
       p.organization_id
   AND rv.payment_id =
       p.id
  WHERE p.organization_id =
        v_booking.organization_id
    AND p.booking_id =
        v_booking.id;

  IF v_valid_collected <
       v_requirement.required_advance_inr THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: required advance has not been satisfied'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Shoot-plan gate.
  --
  -- Advance satisfaction alone no longer confirms a booking. The
  -- current immutable schedule tip must be a valid Stage 7 proposal.
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
     OR v_schedule.schedule_state <> 'proposed' THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: current proposed shoot plan required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Convert the proposal into authoritative reserved evidence.
  --
  -- This is append-only. The proposal remains immutable history and
  -- the reserved snapshot copies its approved schedule facts.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_shoot_schedules (
    organization_id,
    booking_id,
    schedule_version,
    predecessor_schedule_id,
    schedule_state,
    scheduled_start_at,
    scheduled_end_at,
    timezone,
    location_type,
    location_details,
    reschedule_reason,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_schedule.schedule_version + 1,
    v_schedule.id,
    'reserved',
    v_schedule.scheduled_start_at,
    v_schedule.scheduled_end_at,
    v_schedule.timezone,
    v_schedule.location_type,
    v_schedule.location_details,
    NULL,
    v_actor
  )
  RETURNING *
  INTO v_reserved_schedule;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Append historical transition evidence first.
  --
  -- The existing Sprint 8 transition guard validates the current
  -- Stage 7 state before the current-state row is advanced.
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
    v_advance_stage_id,
    v_confirmed_stage_id,
    'advance_satisfied',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Advance the one authoritative current state exactly once.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states js
  SET
    current_stage_id =
      v_confirmed_stage_id,
    stage_entered_at =
      v_transitioned_at,
    version =
      js.version + 1,
    updated_by =
      v_actor
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id
    AND js.current_stage_id =
        v_advance_stage_id
    AND js.version =
        v_state.version;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: journey state changed during confirmation'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- Append audit evidence.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.confirmed_after_advance',
    'booking',
    v_booking.id,
    true,
    jsonb_build_object(
      'journey_stage',
        'advance_pending',
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'booking_confirmed',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'required_advance_inr',
        v_requirement.required_advance_inr,
      'valid_collected_inr',
        v_valid_collected,
      'transition_key',
        'advance_satisfied',
      'source_quotation_id',
        v_booking.source_quotation_id,
      'proposal_schedule_id',
        v_schedule.id,
      'proposal_schedule_version',
        v_schedule.schedule_version,
      'reserved_schedule_id',
        v_reserved_schedule.id,
      'reserved_schedule_version',
        v_reserved_schedule.schedule_version
    ),
    'finance',
    NULL
  );

  RETURN v_booking;
END
$$;

-- =====================================================================
-- Section E2 — Confirmation RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.confirm_booking_after_advance(
  uuid
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.confirm_booking_after_advance(
  uuid
)
FROM anon;

REVOKE ALL
ON FUNCTION public.confirm_booking_after_advance(
  uuid
)
FROM authenticated;

GRANT EXECUTE
ON FUNCTION public.confirm_booking_after_advance(
  uuid
)
TO authenticated;

COMMENT ON FUNCTION public.confirm_booking_after_advance(
  uuid
)
IS
  'Confirm an Advance Pending booking only after authoritative advance evidence and a current proposed shoot plan are satisfied; atomically reserve that plan and advance the booking to Booking Confirmed.';
