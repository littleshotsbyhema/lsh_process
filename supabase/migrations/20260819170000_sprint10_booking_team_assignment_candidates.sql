-- =====================================================================
-- Sprint 10 Slice 7M
-- Controlled Booking Team Assignment Mutations and Candidate Directory
--
-- Introduces only:
--   * get_booking_team_assignment_candidates(uuid)
--
-- Explicitly does not alter:
--   * booking_team_assignments
--   * external_creatives
--   * existing assignment mutation RPCs
--   * role / permission grants
--   * booking journey transition logic
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s10_7m_preconditions$
BEGIN
  IF to_regprocedure(
       'public.get_booking_team_assignment_candidates(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M precondition failed: candidate directory RPC already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.member_role_grants') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.external_creatives') IS NULL
     OR to_regclass('public.booking_team_assignments') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M precondition failed: canonical booking/team foundation unavailable';
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
       'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'
     ) IS NULL
     OR to_regprocedure(
       'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'
     ) IS NULL
     OR to_regprocedure(
       'public.create_external_creative(uuid,text)'
     ) IS NULL
     OR to_regprocedure(
       'public.get_booking_team_assignment_history(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M precondition failed: prerequisite canonical RPC unavailable';
  END IF;
END
$s10_7m_preconditions$;

-- =====================================================================
-- Section B — Narrow booking-scoped assignment candidate directory
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_booking_team_assignment_candidates(
  p_booking_id uuid
)
RETURNS TABLE (
  subject_type text,
  subject_id uuid,
  subject_display_name text,
  eligible_assignment_roles text[],
  roles_requiring_change_reason text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_actor uuid;
  v_state_count integer;
BEGIN
  -- ---------------------------------------------------------------
  -- Input and authentication boundary.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_candidates: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_candidates: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical booking and independent assignment authority.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_candidates: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_candidates: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.team.assign',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_candidates: booking.team.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_candidates: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Exactly one canonical journey state is required.
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
      'get_booking_team_assignment_candidates: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

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
      'get_booking_team_assignment_candidates: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- Candidate discovery is available only where canonical assignment
  -- mutations are already permitted: exact Stages 8, 9 and 10.
  --
  -- NOTE: this tri-clause stage-window gate is intentionally duplicated
  -- from assign_booking_team_member and assign_booking_external_creative
  -- (see 20260814214746_..._foundation.sql and
  -- 20260816113000_..._foundation.sql). Those migrations are already
  -- applied and immutable from this file. A true fix requires a new,
  -- additive migration introducing a shared stage-window helper
  -- function and then retrofitting all three call sites via
  -- CREATE OR REPLACE — deliberately deferred as a separate follow-up
  -- since it touches already-applied migrations beyond this file's scope.
  IF NOT (
       (
         v_stage.stage_order = 8
         AND v_stage.stage_key = 'booking_confirmed'
       )
       OR
       (
         v_stage.stage_order = 9
         AND v_stage.stage_key = 'pre_shoot_preparation'
       )
       OR
       (
         v_stage.stage_order = 10
         AND v_stage.stage_key = 'shoot_scheduled'
       )
     ) THEN
    RAISE EXCEPTION
      'get_booking_team_assignment_candidates: booking must be within Booking Confirmed through Shoot Scheduled'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Safe candidate projection.
  --
  -- Internal eligibility mirrors the canonical assignment mutation:
  --   * active member
  --   * unrevoked operational role
  --   * organization-wide / booking-branch grant eligibility
  --
  -- External identities remain organization-scoped stable identities.
  -- No contact, membership, permission or branch-grant metadata leaves
  -- this boundary.
  --
  -- roles_requiring_change_reason lists which of lead_photographer /
  -- lead_videographer currently have an active holder (ended_at IS
  -- NULL) for this booking. Callers must supply a non-null
  -- p_change_reason to assign_booking_team_member /
  -- assign_booking_external_creative for any role in this list, or the
  -- mutation raises ERRCODE 22023. This is a booking-level fact, not a
  -- per-candidate one: every candidate eligible for a flagged role
  -- carries the same flag, since the reason requirement depends on
  -- whether a current holder exists, not on who the new candidate is.
  -- Empty array means no reason is required for any role.
  -- ---------------------------------------------------------------

  RETURN QUERY
  WITH assignment_role_mapping (
    organization_role_key,
    assignment_role,
    role_sort
  ) AS (
    VALUES
      ('photographer'::text, 'lead_photographer'::text, 10),
      ('assistant'::text, 'assistant'::text, 20),
      ('stylist'::text, 'stylist'::text, 30),
      ('videographer'::text, 'lead_videographer'::text, 40),
      ('videographer'::text, 'supporting_videographer'::text, 50)
  ),
  all_assignment_roles_agg AS (
    -- Single source of the full assignment-role set within this file,
    -- derived from assignment_role_mapping rather than a second
    -- hardcoded literal, so external candidates and internal candidates
    -- can never drift apart on which roles exist.
    SELECT
      array_agg(
        mapping.assignment_role
        ORDER BY
          mapping.role_sort,
          mapping.assignment_role
      )::text[] AS all_assignment_roles
    FROM assignment_role_mapping mapping
  ),
  -- Mirrors the current-holder lookup in assign_booking_team_member /
  -- assign_booking_external_creative (lead_photographer /
  -- lead_videographer only, ended_at IS NULL) so callers can
  -- pre-determine whether p_change_reason will be required before
  -- invoking the mutation.
  current_lead_holders AS (
    SELECT DISTINCT
      assignment.assignment_role AS held_role
    FROM public.booking_team_assignments assignment
    WHERE assignment.organization_id =
          v_booking.organization_id
      AND assignment.booking_id =
          v_booking.id
      AND assignment.assignment_role IN
          ('lead_photographer', 'lead_videographer')
      AND assignment.ended_at IS NULL
  ),
  roles_requiring_change_reason_agg AS (
    SELECT
      COALESCE(
        array_agg(holder.held_role ORDER BY holder.held_role),
        ARRAY[]::text[]
      ) AS roles_requiring_change_reason
    FROM current_lead_holders holder
  ),
  internal_role_rows AS (
    SELECT DISTINCT
      member.id AS candidate_subject_id,
      member.display_name AS candidate_display_name,
      mapping.assignment_role AS candidate_assignment_role,
      mapping.role_sort AS candidate_role_sort
    FROM public.organization_members member
    JOIN public.member_role_grants grant_row
      ON grant_row.organization_id =
         member.organization_id
     AND grant_row.organization_member_id =
         member.id
     AND grant_row.revoked_at IS NULL
    JOIN public.roles role
      ON role.id =
         grant_row.role_id
    JOIN assignment_role_mapping mapping
      ON mapping.organization_role_key =
         role.key
    WHERE member.organization_id =
          v_booking.organization_id
      AND member.status =
          'active'::public.member_status
      AND (
        (
          v_booking.branch_id IS NULL
          AND grant_row.branch_id IS NULL
        )
        OR
        (
          v_booking.branch_id IS NOT NULL
          AND (
            grant_row.branch_id IS NULL
            OR grant_row.branch_id =
               v_booking.branch_id
          )
        )
      )
  ),
  internal_candidates AS (
    SELECT
      'internal_member'::text AS candidate_subject_type,
      row_data.candidate_subject_id,
      row_data.candidate_display_name,
      array_agg(
        row_data.candidate_assignment_role
        ORDER BY
          row_data.candidate_role_sort,
          row_data.candidate_assignment_role
      )::text[] AS candidate_eligible_roles
    FROM internal_role_rows row_data
    GROUP BY
      row_data.candidate_subject_id,
      row_data.candidate_display_name
  ),
  external_candidates AS (
    SELECT
      'external_creative'::text AS candidate_subject_type,
      external.id AS candidate_subject_id,
      external.display_name AS candidate_display_name,
      agg.all_assignment_roles AS candidate_eligible_roles
    FROM public.external_creatives external
    CROSS JOIN all_assignment_roles_agg agg
    WHERE external.organization_id =
          v_booking.organization_id
  ),
  all_candidates AS (
    SELECT
      internal.candidate_subject_type,
      internal.candidate_subject_id,
      internal.candidate_display_name,
      internal.candidate_eligible_roles,
      reason_agg.roles_requiring_change_reason
    FROM internal_candidates internal
    CROSS JOIN roles_requiring_change_reason_agg reason_agg

    UNION ALL

    SELECT
      external.candidate_subject_type,
      external.candidate_subject_id,
      external.candidate_display_name,
      external.candidate_eligible_roles,
      reason_agg.roles_requiring_change_reason
    FROM external_candidates external
    CROSS JOIN roles_requiring_change_reason_agg reason_agg
  )
  SELECT
    candidate.candidate_subject_type,
    candidate.candidate_subject_id,
    candidate.candidate_display_name,
    candidate.candidate_eligible_roles,
    candidate.roles_requiring_change_reason
  FROM all_candidates candidate
  ORDER BY
    candidate.candidate_subject_type,
    lower(candidate.candidate_display_name) NULLS LAST,
    candidate.candidate_subject_id;
END
$$;

-- =====================================================================
-- Section C — ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.get_booking_team_assignment_candidates(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.get_booking_team_assignment_candidates(uuid)
TO authenticated, service_role;

-- =====================================================================
-- Section D — Migration-time contract assertions
-- =====================================================================

DO $s10_7m_assertions$
DECLARE
  v_function regprocedure;
  v_security_definer boolean;
  v_volatility "char";
  v_config text[];
BEGIN
  v_function :=
    to_regprocedure(
      'public.get_booking_team_assignment_candidates(uuid)'
    );

  IF v_function IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M assertion failed: candidate RPC missing';
  END IF;

  SELECT
    procedure.prosecdef,
    procedure.provolatile,
    procedure.proconfig
  INTO
    v_security_definer,
    v_volatility,
    v_config
  FROM pg_proc procedure
  WHERE procedure.oid =
        v_function;

  IF NOT v_security_definer THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M assertion failed: candidate RPC must be SECURITY DEFINER';
  END IF;

  IF v_volatility <> 's' THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M assertion failed: candidate RPC must be STABLE';
  END IF;

  IF NOT (
    'search_path=""' =
      ANY(COALESCE(v_config, ARRAY[]::text[]))
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M assertion failed: candidate RPC must use empty search_path';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           v_function,
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M assertion failed: authenticated EXECUTE missing';
  END IF;

  IF has_function_privilege(
       'anon',
       v_function,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M assertion failed: anon EXECUTE must remain denied';
  END IF;

  IF to_regprocedure(
       'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'
     ) IS NULL
     OR to_regprocedure(
       'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'
     ) IS NULL
     OR to_regprocedure(
       'public.create_external_creative(uuid,text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 7M assertion failed: canonical mutation RPC signature changed';
  END IF;
END
$s10_7m_assertions$;
