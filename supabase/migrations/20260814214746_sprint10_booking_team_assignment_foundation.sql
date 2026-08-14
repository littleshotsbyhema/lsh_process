-- =====================================================================
-- Sprint 10 — Slice 4
-- Booking Team Assignment Foundation
--
-- Introduces:
--   * booking.team.assign
--   * canonical booking_team_assignments lifecycle evidence
--   * forced RLS / authenticated SELECT-only table access
--   * controlled assign_booking_team_member(...) mutation RPC
--
-- Explicitly excluded:
--   * safety readiness / sign-off
--   * safety.signoff permission changes
--   * Stage 9 -> 10 advancement
--   * Stage 10 -> 11 advancement
--   * capacity / overlap / availability rules
--   * application UI
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s10_slice4_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass(
       'public.booking_team_assignments'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 precondition failed: booking_team_assignments already exists';
  END IF;

  IF to_regprocedure(
       'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 precondition failed: assign_booking_team_member already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions p
    WHERE p.key = 'booking.team.assign'
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 precondition failed: booking.team.assign already exists';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles r
  WHERE r.key IN (
    'photographer',
    'assistant',
    'stylist'
  );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 precondition failed: required operational roles are unavailable';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.member_role_grants') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 precondition failed: required booking / membership foundation is unavailable';
  END IF;
END
$s10_slice4_preconditions$;

-- =====================================================================
-- Section B — Dedicated booking staffing permission
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'booking.team.assign',
  'bookings',
  'Assign booking team',
  'Create, replace and remove canonical operational team assignments for an eligible booking.',
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
    ('founder', 'booking.team.assign'),
    ('studio_manager', 'booking.team.assign'),
    ('client_coordinator', 'booking.team.assign')
) AS approved(role_key, permission_key)
JOIN public.roles r
  ON r.key = approved.role_key
JOIN public.permissions p
  ON p.key = approved.permission_key;

DO $s10_slice4_permission_assertions$
DECLARE
  v_total integer;
  v_expected integer;
BEGIN
  SELECT count(*)
  INTO v_total
  FROM public.permissions p
  WHERE p.key = 'booking.team.assign'
    AND p.domain = 'bookings'
    AND p.requires_server_enforcement;

  IF v_total <> 1 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 permission gate failed: booking.team.assign catalogue row is invalid';
  END IF;

  SELECT count(*)
  INTO v_total
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  WHERE p.key = 'booking.team.assign';

  SELECT count(*)
  INTO v_expected
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  JOIN public.roles r
    ON r.id = rp.role_id
  WHERE p.key = 'booking.team.assign'
    AND r.key IN (
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_total <> 3
     OR v_expected <> 3 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 permission gate failed: booking.team.assign must have exactly the three approved role grants';
  END IF;
END
$s10_slice4_permission_assertions$;

-- =====================================================================
-- Section C1 — Canonical booking-team assignment lifecycle evidence
-- =====================================================================

CREATE TABLE public.booking_team_assignments (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    uuid NOT NULL,
  booking_id         uuid NOT NULL,
  assignment_role    text NOT NULL,
  assigned_member_id uuid NOT NULL,
  assigned_at        timestamptz NOT NULL DEFAULT now(),
  assigned_by        uuid NOT NULL,
  ended_at           timestamptz,
  ended_by           uuid,
  end_reason         text,

  CONSTRAINT booking_team_assignments_role_chk
    CHECK (
      assignment_role IN (
        'lead_photographer',
        'assistant',
        'stylist'
      )
    ),

  CONSTRAINT booking_team_assignments_end_reason_not_blank_chk
    CHECK (
      end_reason IS NULL
      OR btrim(end_reason) <> ''
    ),

  CONSTRAINT booking_team_assignments_lifecycle_chk
    CHECK (
      (
        ended_at IS NULL
        AND ended_by IS NULL
        AND end_reason IS NULL
      )
      OR
      (
        ended_at IS NOT NULL
        AND ended_by IS NOT NULL
        AND end_reason IS NOT NULL
      )
    ),

  CONSTRAINT booking_team_assignments_end_time_chk
    CHECK (
      ended_at IS NULL
      OR ended_at >= assigned_at
    ),

  CONSTRAINT booking_team_assignments_booking_fkey
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

  CONSTRAINT booking_team_assignments_assigned_member_fkey
    FOREIGN KEY (
      assigned_member_id,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_team_assignments_assigned_by_fkey
    FOREIGN KEY (
      assigned_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_team_assignments_ended_by_fkey
    FOREIGN KEY (
      ended_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_team_assignments_id_org_booking_key
    UNIQUE (
      id,
      organization_id,
      booking_id
    )
);

CREATE UNIQUE INDEX booking_team_assignments_current_lead_uidx
ON public.booking_team_assignments (
  organization_id,
  booking_id
)
WHERE assignment_role = 'lead_photographer'
  AND ended_at IS NULL;

CREATE UNIQUE INDEX booking_team_assignments_current_member_role_uidx
ON public.booking_team_assignments (
  organization_id,
  booking_id,
  assignment_role,
  assigned_member_id
)
WHERE ended_at IS NULL;

CREATE INDEX booking_team_assignments_org_booking_history_idx
ON public.booking_team_assignments (
  organization_id,
  booking_id,
  assigned_at DESC
);

CREATE INDEX booking_team_assignments_current_role_idx
ON public.booking_team_assignments (
  organization_id,
  booking_id,
  assignment_role
)
WHERE ended_at IS NULL;

-- =====================================================================
-- Section C2 — Lifecycle / attribution guard
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_booking_team_assignment_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking team assignment evidence cannot be deleted';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.ended_at IS NOT NULL
       OR NEW.ended_by IS NOT NULL
       OR NEW.end_reason IS NOT NULL THEN
      RAISE EXCEPTION
        'booking team assignment must be inserted as active';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      v_actor :=
        public.current_organization_member(
          NEW.organization_id
        );

      IF v_actor IS NULL
         OR NEW.assigned_by IS DISTINCT FROM v_actor THEN
        RAISE EXCEPTION
          'booking team assignment assigned_by must be the current active organization member';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  IF OLD.id IS DISTINCT FROM NEW.id
     OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
     OR OLD.booking_id IS DISTINCT FROM NEW.booking_id
     OR OLD.assignment_role IS DISTINCT FROM NEW.assignment_role
     OR OLD.assigned_member_id IS DISTINCT FROM NEW.assigned_member_id
     OR OLD.assigned_at IS DISTINCT FROM NEW.assigned_at
     OR OLD.assigned_by IS DISTINCT FROM NEW.assigned_by THEN
    RAISE EXCEPTION
      'booking team assignment identity and original assignment evidence are immutable';
  END IF;

  IF OLD.ended_at IS NOT NULL
     OR OLD.ended_by IS NOT NULL
     OR OLD.end_reason IS NOT NULL THEN
    RAISE EXCEPTION
      'closed booking team assignment evidence is immutable';
  END IF;

  IF NEW.ended_at IS NULL
     OR NEW.ended_by IS NULL
     OR NEW.end_reason IS NULL
     OR btrim(NEW.end_reason) = '' THEN
    RAISE EXCEPTION
      'booking team assignment update may only close an active assignment with complete ending evidence';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.ended_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking team assignment ended_by must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_team_assignments_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_team_assignments
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_team_assignment_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_team_assignment_guard()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.lsh_booking_team_assignment_guard()
TO service_role;

-- =====================================================================
-- Section C3 — Forced RLS / authenticated SELECT-only boundary
-- =====================================================================

ALTER TABLE public.booking_team_assignments
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_team_assignments
FORCE ROW LEVEL SECURITY;

CREATE POLICY booking_team_assignments_authenticated_select
ON public.booking_team_assignments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_team_assignments.organization_id
      AND booking.id =
          booking_team_assignments.booking_id
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

REVOKE ALL PRIVILEGES
ON TABLE public.booking_team_assignments
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_team_assignments
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE public.booking_team_assignments
TO service_role;

-- =====================================================================
-- Section D1 — Controlled assignment / replacement / removal RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.assign_booking_team_member(
  p_booking_id uuid,
  p_assignment_role text,
  p_member_id uuid,
  p_is_assigned boolean,
  p_change_reason text DEFAULT NULL
)
RETURNS public.booking_team_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_current public.booking_team_assignments;
  v_closed public.booking_team_assignments;
  v_result public.booking_team_assignments;

  v_target_member public.organization_members;

  v_actor uuid;
  v_required_role_key text;
  v_reason text;
  v_changed_at timestamptz;

  v_state_count integer;
  v_has_current boolean := false;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication boundary.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_assignment_role IS NULL
     OR p_assignment_role NOT IN (
       'lead_photographer',
       'assistant',
       'stylist'
     ) THEN
    RAISE EXCEPTION
      'assign_booking_team_member: unsupported assignment role'
      USING ERRCODE = '22023';
  END IF;

  IF p_member_id IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: member_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_is_assigned IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: assigned state is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_change_reason IS NOT NULL
     AND btrim(p_change_reason) = '' THEN
    RAISE EXCEPTION
      'assign_booking_team_member: change_reason must be nonblank when provided'
      USING ERRCODE = '22023';
  END IF;

  v_reason :=
    NULLIF(
      btrim(p_change_reason),
      ''
    );

  v_required_role_key :=
    CASE p_assignment_role
      WHEN 'lead_photographer'
        THEN 'photographer'
      WHEN 'assistant'
        THEN 'assistant'
      WHEN 'stylist'
        THEN 'stylist'
    END;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: authoritative booking.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_booking_team_member: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.team.assign',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'assign_booking_team_member: booking.team.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'assign_booking_team_member: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exactly one canonical journey state.
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
      'assign_booking_team_member: booking must have exactly one current journey state'
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
      'assign_booking_team_member: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

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
      'assign_booking_team_member: booking must be within Booking Confirmed through Shoot Scheduled'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Assignment path.
  -- ---------------------------------------------------------------

  IF p_is_assigned THEN
    -- Lock order 3: relevant current assignment evidence.

    IF p_assignment_role = 'lead_photographer' THEN
      SELECT assignment.*
      INTO v_current
      FROM public.booking_team_assignments assignment
      WHERE assignment.organization_id =
            v_booking.organization_id
        AND assignment.booking_id =
            v_booking.id
        AND assignment.assignment_role =
            'lead_photographer'
        AND assignment.ended_at IS NULL
      LIMIT 1
      FOR UPDATE;

      v_has_current := FOUND;

      -- Exact assignment replay is authorization-first and a true no-op.
      IF v_has_current
         AND v_current.assigned_member_id =
             p_member_id THEN
        RETURN v_current;
      END IF;

      IF v_has_current
         AND v_reason IS NULL THEN
        RAISE EXCEPTION
          'assign_booking_team_member: Lead Photographer replacement requires a change reason'
          USING ERRCODE = '22023';
      END IF;
    ELSE
      SELECT assignment.*
      INTO v_current
      FROM public.booking_team_assignments assignment
      WHERE assignment.organization_id =
            v_booking.organization_id
        AND assignment.booking_id =
            v_booking.id
        AND assignment.assignment_role =
            p_assignment_role
        AND assignment.assigned_member_id =
            p_member_id
        AND assignment.ended_at IS NULL
      LIMIT 1
      FOR UPDATE;

      v_has_current := FOUND;

      IF v_has_current THEN
        RETURN v_current;
      END IF;
    END IF;

    -- -------------------------------------------------------------
    -- Eligibility lock: target member.
    -- -------------------------------------------------------------

    SELECT member.*
    INTO v_target_member
    FROM public.organization_members member
    WHERE member.organization_id =
          v_booking.organization_id
      AND member.id =
          p_member_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'assign_booking_team_member: target organization member unavailable'
        USING ERRCODE = '22023';
    END IF;

    IF v_target_member.status <>
         'active'::public.member_status THEN
      RAISE EXCEPTION
        'assign_booking_team_member: target organization member must be active'
        USING ERRCODE = '22023';
    END IF;

    -- -------------------------------------------------------------
    -- Eligibility lock: qualifying unrevoked operational role grant.
    --
    -- Branch booking:
    --   organization-wide OR same-branch role grant.
    --
    -- Branchless booking:
    --   organization-wide role grant only.
    -- -------------------------------------------------------------

    PERFORM grant_row.id
    FROM public.member_role_grants grant_row
    JOIN public.roles role
      ON role.id =
         grant_row.role_id
    WHERE grant_row.organization_id =
          v_booking.organization_id
      AND grant_row.organization_member_id =
          p_member_id
      AND grant_row.revoked_at IS NULL
      AND role.key =
          v_required_role_key
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
    ORDER BY
      CASE
        WHEN grant_row.branch_id IS NULL
          THEN 0
        ELSE 1
      END,
      grant_row.id
    LIMIT 1
    FOR UPDATE OF grant_row;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'assign_booking_team_member: target member lacks qualifying operational role for booking scope'
        USING ERRCODE = '22023';
    END IF;

    v_changed_at := now();

    -- -------------------------------------------------------------
    -- Singular Lead Photographer replacement.
    -- -------------------------------------------------------------

    IF p_assignment_role = 'lead_photographer'
       AND v_has_current THEN

      UPDATE public.booking_team_assignments assignment
      SET
        ended_at =
          v_changed_at,
        ended_by =
          v_actor,
        end_reason =
          v_reason
      WHERE assignment.organization_id =
            v_current.organization_id
        AND assignment.id =
            v_current.id
        AND assignment.ended_at IS NULL
      RETURNING *
      INTO v_closed;

      IF NOT FOUND THEN
        RAISE EXCEPTION
          'assign_booking_team_member: current Lead Photographer changed during replacement'
          USING ERRCODE = '40001';
      END IF;

      INSERT INTO public.booking_team_assignments (
        organization_id,
        booking_id,
        assignment_role,
        assigned_member_id,
        assigned_at,
        assigned_by
      )
      VALUES (
        v_booking.organization_id,
        v_booking.id,
        p_assignment_role,
        p_member_id,
        v_changed_at,
        v_actor
      )
      RETURNING *
      INTO v_result;

      PERFORM public.append_audit_event(
        v_booking.organization_id,
        v_booking.branch_id,
        'booking.team_member_replaced',
        'booking_team_assignment',
        v_result.id,
        false,
        jsonb_build_object(
          'assignment_id',
            v_closed.id,
          'assignment_role',
            v_closed.assignment_role,
          'assigned_member_id',
            v_closed.assigned_member_id,
          'is_current',
            false
        ),
        jsonb_build_object(
          'assignment_id',
            v_result.id,
          'assignment_role',
            v_result.assignment_role,
          'assigned_member_id',
            v_result.assigned_member_id,
          'is_current',
            true
        ),
        jsonb_build_object(
          'booking_id',
            v_booking.id
        ),
        'application',
        NULL
      );

      RETURN v_result;
    END IF;

    -- -------------------------------------------------------------
    -- First Lead Photographer / additional Assistant or Stylist.
    -- -------------------------------------------------------------

    INSERT INTO public.booking_team_assignments (
      organization_id,
      booking_id,
      assignment_role,
      assigned_member_id,
      assigned_at,
      assigned_by
    )
    VALUES (
      v_booking.organization_id,
      v_booking.id,
      p_assignment_role,
      p_member_id,
      v_changed_at,
      v_actor
    )
    RETURNING *
    INTO v_result;

    PERFORM public.append_audit_event(
      v_booking.organization_id,
      v_booking.branch_id,
      'booking.team_member_assigned',
      'booking_team_assignment',
      v_result.id,
      false,
      NULL,
      jsonb_build_object(
        'assignment_id',
          v_result.id,
        'assignment_role',
          v_result.assignment_role,
        'assigned_member_id',
          v_result.assigned_member_id,
        'is_current',
          true
      ),
      jsonb_build_object(
        'booking_id',
          v_booking.id
      ),
      'application',
      NULL
    );

    RETURN v_result;
  END IF;

  -- ---------------------------------------------------------------
  -- Unassignment path.
  --
  -- Deliberately does not re-check present-day operational eligibility:
  -- an assignment must remain removable after suspension or role loss.
  -- ---------------------------------------------------------------

  IF v_reason IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: unassignment requires a change reason'
      USING ERRCODE = '22023';
  END IF;

  SELECT assignment.*
  INTO v_current
  FROM public.booking_team_assignments assignment
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.assignment_role =
        p_assignment_role
    AND assignment.assigned_member_id =
        p_member_id
    AND assignment.ended_at IS NULL
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Successful historical removal replay is a no-op.
    SELECT assignment.*
    INTO v_result
    FROM public.booking_team_assignments assignment
    WHERE assignment.organization_id =
          v_booking.organization_id
      AND assignment.booking_id =
          v_booking.id
      AND assignment.assignment_role =
          p_assignment_role
      AND assignment.assigned_member_id =
          p_member_id
      AND assignment.ended_at IS NOT NULL
    ORDER BY
      assignment.ended_at DESC,
      assignment.assigned_at DESC,
      assignment.id
    LIMIT 1;

    IF FOUND THEN
      RETURN v_result;
    END IF;

    RAISE EXCEPTION
      'assign_booking_team_member: member has never held this booking assignment role'
      USING ERRCODE = '22023';
  END IF;

  v_changed_at := now();

  UPDATE public.booking_team_assignments assignment
  SET
    ended_at =
      v_changed_at,
    ended_by =
      v_actor,
    end_reason =
      v_reason
  WHERE assignment.organization_id =
        v_current.organization_id
    AND assignment.id =
        v_current.id
    AND assignment.ended_at IS NULL
  RETURNING *
  INTO v_result;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_booking_team_member: current assignment changed during unassignment'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.team_member_unassigned',
    'booking_team_assignment',
    v_result.id,
    false,
    jsonb_build_object(
      'assignment_id',
        v_result.id,
      'assignment_role',
        v_result.assignment_role,
      'assigned_member_id',
        v_result.assigned_member_id,
      'is_current',
        true
    ),
    jsonb_build_object(
      'assignment_id',
        v_result.id,
      'assignment_role',
        v_result.assignment_role,
      'assigned_member_id',
        v_result.assigned_member_id,
      'is_current',
        false,
      'ended_at',
        v_result.ended_at,
      'ended_by',
        v_result.ended_by
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id
    ),
    'application',
    NULL
  );

  RETURN v_result;
END
$$;

-- =====================================================================
-- Section D2 — RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.assign_booking_team_member(
  uuid,
  text,
  uuid,
  boolean,
  text
)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.assign_booking_team_member(
  uuid,
  text,
  uuid,
  boolean,
  text
)
TO authenticated;

-- =====================================================================
-- Section E — Final static invariants
-- =====================================================================

DO $s10_slice4_final_assertions$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM pg_attribute attribute
  WHERE attribute.attrelid =
        'public.booking_team_assignments'::regclass
    AND attribute.attnum > 0
    AND NOT attribute.attisdropped;

  IF v_count <> 10 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 final gate failed: booking_team_assignments must have exactly 10 columns';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_class table_row
    WHERE table_row.oid =
          'public.booking_team_assignments'::regclass
      AND table_row.relrowsecurity
      AND table_row.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 final gate failed: booking_team_assignments must enable and force RLS';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_policies policy
  WHERE policy.schemaname = 'public'
    AND policy.tablename =
        'booking_team_assignments';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 final gate failed: expected exactly one booking-team RLS policy';
  END IF;

  IF NOT has_table_privilege(
           'authenticated',
           'public.booking_team_assignments',
           'SELECT'
         )
     OR has_table_privilege(
          'authenticated',
          'public.booking_team_assignments',
          'INSERT'
        )
     OR has_table_privilege(
          'authenticated',
          'public.booking_team_assignments',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.booking_team_assignments',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 final gate failed: authenticated booking-team ACL is invalid';
  END IF;

  IF has_table_privilege(
       'anon',
       'public.booking_team_assignments',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 final gate failed: anon booking-team access is forbidden';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc procedure
    JOIN pg_namespace namespace
      ON namespace.oid =
         procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.oid =
          'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'::regprocedure
      AND procedure.prosecdef
      AND 'search_path=""' =
          ANY(
            COALESCE(
              procedure.proconfig,
              ARRAY[]::text[]
            )
          )
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 final gate failed: assignment RPC security contract is invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.assign_booking_team_member(uuid,text,uuid,boolean,text)',
           'EXECUTE'
         )
     OR has_function_privilege(
          'anon',
          'public.assign_booking_team_member(uuid,text,uuid,boolean,text)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 4 final gate failed: assignment RPC ACL is invalid';
  END IF;
END
$s10_slice4_final_assertions$;
