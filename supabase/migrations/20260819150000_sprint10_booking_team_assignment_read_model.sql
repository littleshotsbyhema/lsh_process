-- =====================================================================
-- Sprint 10 Slice 7L
-- Canonical Booking Team Assignment Read Model
-- =====================================================================
--
-- Purpose:
--   Expose the minimum safe, booking-scoped human-readable assignment
--   history required by the authenticated Bookings workspace.
--
-- Canonical lifecycle truth remains:
--   public.booking_team_assignments
--
-- Canonical internal display identity remains:
--   public.organization_members
--
-- Canonical external display identity remains:
--   public.external_creatives
--
-- This migration introduces no assignment mutation, no permission key,
-- no role grant and no journey mutation.
-- =====================================================================


CREATE OR REPLACE FUNCTION public.get_booking_team_assignment_history(
  p_booking_id uuid
)
RETURNS TABLE (
  assignment_id        uuid,
  booking_id           uuid,
  assignment_role      text,
  subject_type         text,
  subject_id           uuid,
  subject_display_name text,
  assigned_at          timestamptz,
  ended_at             timestamptz,
  end_reason           text,
  is_current           boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_booking public.bookings;
  v_actor   uuid;
BEGIN
  -- -------------------------------------------------------------------
  -- Input / authentication boundary
  -- -------------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_history: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_history: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- -------------------------------------------------------------------
  -- Resolve canonical booking-owned organization / branch authority.
  -- -------------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_history: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_history: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.read',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_history: booking.read permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_history: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- -------------------------------------------------------------------
  -- Safe canonical projection.
  --
  -- The XOR invariant on booking_team_assignments guarantees exactly
  -- one assignment subject: internal member OR external creative.
  -- -------------------------------------------------------------------

  RETURN QUERY
  SELECT
    assignment.id AS assignment_id,
    assignment.booking_id,
    assignment.assignment_role,

    CASE
      WHEN assignment.assigned_member_id IS NOT NULL
        THEN 'internal_member'::text
      ELSE 'external_creative'::text
    END AS subject_type,

    COALESCE(
      assignment.assigned_member_id,
      assignment.assigned_external_creative_id
    ) AS subject_id,

    CASE
      WHEN assignment.assigned_member_id IS NOT NULL
        THEN member.display_name
      ELSE external_creative.display_name
    END AS subject_display_name,

    assignment.assigned_at,
    assignment.ended_at,
    assignment.end_reason,
    assignment.ended_at IS NULL AS is_current

  FROM public.booking_team_assignments assignment

  LEFT JOIN public.organization_members member
    ON member.organization_id =
       assignment.organization_id
   AND member.id =
       assignment.assigned_member_id

  LEFT JOIN public.external_creatives external_creative
    ON external_creative.organization_id =
       assignment.organization_id
   AND external_creative.id =
       assignment.assigned_external_creative_id

  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id

  ORDER BY
    assignment.assigned_at ASC,
    assignment.id ASC;
END
$function$;


-- =====================================================================
-- Least-privilege execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.get_booking_team_assignment_history(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.get_booking_team_assignment_history(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.get_booking_team_assignment_history(uuid)
TO service_role;


-- =====================================================================
-- Migration-time structural assertions
-- =====================================================================

DO $s10_slice7l_read_model_assertions$
DECLARE
  v_function oid;
BEGIN
  v_function :=
    to_regprocedure(
      'public.get_booking_team_assignment_history(uuid)'
    );

  IF v_function IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7L failed: booking-team history function missing';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       'public.get_booking_team_assignment_history(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7L failed: authenticated execute grant missing';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.get_booking_team_assignment_history(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7L failed: anon must not execute booking-team history function';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc procedure_row
    WHERE procedure_row.oid = v_function
      AND procedure_row.prosecdef
      AND procedure_row.provolatile = 's'
      AND 'search_path=""' =
          ANY(
            COALESCE(
              procedure_row.proconfig,
              ARRAY[]::text[]
            )
          )
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7L failed: read function security attributes invalid';
  END IF;
END
$s10_slice7l_read_model_assertions$;
