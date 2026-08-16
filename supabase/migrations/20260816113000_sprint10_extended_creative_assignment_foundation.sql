-- =====================================================================
-- Sprint 10 Slice 6A — Extended Creative Assignment Foundation
--
-- Scope:
--   * stable external/freelance creative identity;
--   * Videographer organization role;
--   * Lead/Supporting Videographer booking assignments;
--   * internal-or-external booking assignment subjects;
--   * structured commercial Lead Videographer requirement evidence.
--
-- Explicitly out of scope:
--   * Stage 9 -> 10 journey advancement;
--   * Stage 10 -> 11;
--   * UI/runtime;
--   * freelancer application access;
--   * free-text Video/Reels inference.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s10_6a_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_team_assignments') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.member_role_grants') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.commercial_packages') IS NULL
     OR to_regclass('public.commercial_package_versions') IS NULL
     OR to_regclass('public.commercial_addons') IS NULL
     OR to_regclass('public.commercial_addon_versions') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: prerequisite foundation missing';
  END IF;

  IF to_regprocedure(
       'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'
     ) IS NULL
     OR to_regprocedure(
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
      'Sprint 10 Slice 6A precondition failed: prerequisite helper/RPC missing';
  END IF;

  IF to_regclass('public.external_creatives') IS NOT NULL
     OR to_regclass(
          'public.commercial_operational_requirements'
        ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: new Slice 6A table already exists';
  END IF;

  IF to_regprocedure(
       'public.create_external_creative(uuid,text)'
     ) IS NOT NULL
     OR to_regprocedure(
       'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: new Slice 6A RPC already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'booking_team_assignments'
      AND column_name =
          'assigned_external_creative_id'
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: booking-team external subject column already exists';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles;

  IF v_count <> 11 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: expected 11 roles, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 228 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: expected 228 role-permission mappings, found %',
      v_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.roles
    WHERE key = 'videographer'
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: videographer role already exists';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions
  WHERE key IN (
    'org.read',
    'booking.read'
  );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A precondition failed: org.read / booking.read permissions unavailable';
  END IF;
END
$s10_6a_preconditions$;

-- =====================================================================
-- Section B — Stable external creative identity
-- =====================================================================

CREATE TABLE public.external_creatives (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  display_name    text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid NOT NULL,

  CONSTRAINT external_creatives_organization_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT external_creatives_created_by_fkey
    FOREIGN KEY (
      created_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT external_creatives_display_name_chk
    CHECK (
      btrim(display_name) <> ''
      AND char_length(btrim(display_name))
          BETWEEN 1 AND 160
    ),

  CONSTRAINT external_creatives_id_organization_key
    UNIQUE (
      id,
      organization_id
    )
);

CREATE INDEX external_creatives_organization_idx
ON public.external_creatives (
  organization_id,
  created_at DESC
);

CREATE OR REPLACE FUNCTION public.lsh_external_creative_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'external creative identity cannot be deleted';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'external creative identity is immutable';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.created_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'external creative created_by must be the current active organization member';
    END IF;
  END IF;

  NEW.display_name :=
    btrim(NEW.display_name);

  RETURN NEW;
END
$$;

CREATE TRIGGER external_creatives_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.external_creatives
FOR EACH ROW
EXECUTE FUNCTION public.lsh_external_creative_guard();

ALTER TABLE public.external_creatives
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.external_creatives
FORCE ROW LEVEL SECURITY;

REVOKE ALL
ON TABLE public.external_creatives
FROM PUBLIC, anon, authenticated, service_role;

GRANT ALL
ON TABLE public.external_creatives
TO service_role;

REVOKE ALL
ON FUNCTION public.lsh_external_creative_guard()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.lsh_external_creative_guard()
TO service_role;

-- =====================================================================
-- Section C — Videographer organization role
-- =====================================================================

INSERT INTO public.roles (
  key,
  label,
  description,
  sort_order,
  is_system_role
)
VALUES (
  'videographer',
  'Videographer',
  'Captures client Video/Reels and approved studio video coverage.',
  75,
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
WHERE role.key =
      'videographer'
  AND permission.key IN (
    'org.read',
    'booking.read'
  );

-- =====================================================================
-- Section D — Extend canonical booking-team assignment subjects/roles
-- =====================================================================

ALTER TABLE public.booking_team_assignments
ADD COLUMN assigned_external_creative_id uuid;

ALTER TABLE public.booking_team_assignments
ALTER COLUMN assigned_member_id DROP NOT NULL;

ALTER TABLE public.booking_team_assignments
ADD CONSTRAINT booking_team_assignments_assigned_external_fkey
FOREIGN KEY (
  assigned_external_creative_id,
  organization_id
)
REFERENCES public.external_creatives (
  id,
  organization_id
)
ON UPDATE RESTRICT
ON DELETE RESTRICT;

ALTER TABLE public.booking_team_assignments
ADD CONSTRAINT booking_team_assignments_subject_xor_chk
CHECK (
  (
    assigned_member_id IS NOT NULL
    AND assigned_external_creative_id IS NULL
  )
  OR
  (
    assigned_member_id IS NULL
    AND assigned_external_creative_id IS NOT NULL
  )
);

ALTER TABLE public.booking_team_assignments
DROP CONSTRAINT booking_team_assignments_role_chk;

ALTER TABLE public.booking_team_assignments
ADD CONSTRAINT booking_team_assignments_role_chk
CHECK (
  assignment_role IN (
    'lead_photographer',
    'assistant',
    'stylist',
    'lead_videographer',
    'supporting_videographer'
  )
);

CREATE UNIQUE INDEX booking_team_assignments_current_lead_videographer_uidx
ON public.booking_team_assignments (
  organization_id,
  booking_id
)
WHERE assignment_role =
      'lead_videographer'
  AND ended_at IS NULL;

CREATE UNIQUE INDEX booking_team_assignments_current_external_role_uidx
ON public.booking_team_assignments (
  organization_id,
  booking_id,
  assignment_role,
  assigned_external_creative_id
)
WHERE ended_at IS NULL
  AND assigned_external_creative_id IS NOT NULL;

-- =====================================================================
-- Section E — Evolve assignment lifecycle guard
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
     OR OLD.assigned_external_creative_id
          IS DISTINCT FROM
        NEW.assigned_external_creative_id
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

-- =====================================================================
-- Section F — Evolve internal-member assignment RPC
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
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_assignment_role IS NULL
     OR p_assignment_role NOT IN (
       'lead_photographer',
       'assistant',
       'stylist',
       'lead_videographer',
       'supporting_videographer'
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
      WHEN 'lead_videographer'
        THEN 'videographer'
      WHEN 'supporting_videographer'
        THEN 'videographer'
    END;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_team_member: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

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

  IF p_is_assigned THEN
    IF p_assignment_role IN (
         'lead_photographer',
         'lead_videographer'
       ) THEN
      SELECT assignment.*
      INTO v_current
      FROM public.booking_team_assignments assignment
      WHERE assignment.organization_id =
            v_booking.organization_id
        AND assignment.booking_id =
            v_booking.id
        AND assignment.assignment_role =
            p_assignment_role
        AND assignment.ended_at IS NULL
      LIMIT 1
      FOR UPDATE;

      v_has_current := FOUND;

      IF v_has_current
         AND v_current.assigned_member_id =
             p_member_id
         AND v_current.assigned_external_creative_id
             IS NULL THEN
        RETURN v_current;
      END IF;

      IF v_has_current
         AND v_reason IS NULL THEN
        IF p_assignment_role =
             'lead_photographer' THEN
          RAISE EXCEPTION
            'assign_booking_team_member: Lead Photographer replacement requires a change reason'
            USING ERRCODE = '22023';
        ELSE
          RAISE EXCEPTION
            'assign_booking_team_member: Lead Videographer replacement requires a change reason'
            USING ERRCODE = '22023';
        END IF;
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
        AND assignment.assigned_external_creative_id
            IS NULL
        AND assignment.ended_at IS NULL
      LIMIT 1
      FOR UPDATE;

      v_has_current := FOUND;

      IF v_has_current THEN
        RETURN v_current;
      END IF;
    END IF;

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

    IF p_assignment_role IN (
         'lead_photographer',
         'lead_videographer'
       )
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
        IF p_assignment_role =
             'lead_photographer' THEN
          RAISE EXCEPTION
            'assign_booking_team_member: current Lead Photographer changed during replacement'
            USING ERRCODE = '40001';
        ELSE
          RAISE EXCEPTION
            'assign_booking_team_member: current Lead Videographer changed during replacement'
            USING ERRCODE = '40001';
        END IF;
      END IF;

      INSERT INTO public.booking_team_assignments (
        organization_id,
        booking_id,
        assignment_role,
        assigned_member_id,
        assigned_external_creative_id,
        assigned_at,
        assigned_by
      )
      VALUES (
        v_booking.organization_id,
        v_booking.id,
        p_assignment_role,
        p_member_id,
        NULL,
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
          'subject_type',
            CASE
              WHEN v_closed.assigned_member_id IS NOT NULL
                THEN 'member'
              ELSE 'external'
            END,
          'assigned_member_id',
            v_closed.assigned_member_id,
          'assigned_external_creative_id',
            v_closed.assigned_external_creative_id,
          'is_current',
            false
        ),
        jsonb_build_object(
          'assignment_id',
            v_result.id,
          'assignment_role',
            v_result.assignment_role,
          'subject_type',
            'member',
          'assigned_member_id',
            v_result.assigned_member_id,
          'assigned_external_creative_id',
            NULL,
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

    INSERT INTO public.booking_team_assignments (
      organization_id,
      booking_id,
      assignment_role,
      assigned_member_id,
      assigned_external_creative_id,
      assigned_at,
      assigned_by
    )
    VALUES (
      v_booking.organization_id,
      v_booking.id,
      p_assignment_role,
      p_member_id,
      NULL,
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
        'subject_type',
          'member',
        'assigned_member_id',
          v_result.assigned_member_id,
        'assigned_external_creative_id',
          NULL,
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
    AND assignment.assigned_external_creative_id
        IS NULL
    AND assignment.ended_at IS NULL
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
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
      AND assignment.assigned_external_creative_id
          IS NULL
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
      'subject_type',
        'member',
      'assigned_member_id',
        v_result.assigned_member_id,
      'assigned_external_creative_id',
        NULL,
      'is_current',
        true
    ),
    jsonb_build_object(
      'assignment_id',
        v_result.id,
      'assignment_role',
        v_result.assignment_role,
      'subject_type',
        'member',
      'assigned_member_id',
        v_result.assigned_member_id,
      'assigned_external_creative_id',
        NULL,
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
-- Section G — External creative creation RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.create_external_creative(
  p_booking_id uuid,
  p_display_name text
)
RETURNS public.external_creatives
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_display_name text;
  v_result public.external_creatives;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'create_external_creative: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  v_display_name :=
    NULLIF(
      btrim(p_display_name),
      ''
    );

  IF v_display_name IS NULL THEN
    RAISE EXCEPTION
      'create_external_creative: display_name is required'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(v_display_name) > 160 THEN
    RAISE EXCEPTION
      'create_external_creative: display_name is too long'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'create_external_creative: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'create_external_creative: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'create_external_creative: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.team.assign',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'create_external_creative: booking.team.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'create_external_creative: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.external_creatives (
    organization_id,
    display_name,
    created_by
  )
  VALUES (
    v_booking.organization_id,
    v_display_name,
    v_actor
  )
  RETURNING *
  INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.external_creative_registered',
    'external_creative',
    v_result.id,
    false,
    NULL,
    jsonb_build_object(
      'external_creative_id',
        v_result.id
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
-- Section H — External/freelance booking assignment RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.assign_booking_external_creative(
  p_booking_id uuid,
  p_assignment_role text,
  p_external_creative_id uuid,
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

  v_actor uuid;
  v_reason text;
  v_changed_at timestamptz;

  v_state_count integer;
  v_has_current boolean := false;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_assignment_role IS NULL
     OR p_assignment_role NOT IN (
       'lead_photographer',
       'assistant',
       'stylist',
       'lead_videographer',
       'supporting_videographer'
     ) THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: unsupported assignment role'
      USING ERRCODE = '22023';
  END IF;

  IF p_external_creative_id IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: external_creative_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_is_assigned IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: assigned state is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_change_reason IS NOT NULL
     AND btrim(p_change_reason) = '' THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: change_reason must be nonblank when provided'
      USING ERRCODE = '22023';
  END IF;

  v_reason :=
    NULLIF(
      btrim(p_change_reason),
      ''
    );

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.team.assign',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: booking.team.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: booking must have exactly one current journey state'
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
      'assign_booking_external_creative: active current journey stage unavailable'
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
      'assign_booking_external_creative: booking must be within Booking Confirmed through Shoot Scheduled'
      USING ERRCODE = '22023';
  END IF;

  PERFORM external.id
  FROM public.external_creatives external
  WHERE external.organization_id =
        v_booking.organization_id
    AND external.id =
        p_external_creative_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: external creative unavailable for booking organization'
      USING ERRCODE = '22023';
  END IF;

  IF p_is_assigned THEN
    IF p_assignment_role IN (
         'lead_photographer',
         'lead_videographer'
       ) THEN
      SELECT assignment.*
      INTO v_current
      FROM public.booking_team_assignments assignment
      WHERE assignment.organization_id =
            v_booking.organization_id
        AND assignment.booking_id =
            v_booking.id
        AND assignment.assignment_role =
            p_assignment_role
        AND assignment.ended_at IS NULL
      LIMIT 1
      FOR UPDATE;

      v_has_current := FOUND;

      IF v_has_current
         AND v_current.assigned_member_id IS NULL
         AND v_current.assigned_external_creative_id =
             p_external_creative_id THEN
        RETURN v_current;
      END IF;

      IF v_has_current
         AND v_reason IS NULL THEN
        IF p_assignment_role =
             'lead_photographer' THEN
          RAISE EXCEPTION
            'assign_booking_external_creative: Lead Photographer replacement requires a change reason'
            USING ERRCODE = '22023';
        ELSE
          RAISE EXCEPTION
            'assign_booking_external_creative: Lead Videographer replacement requires a change reason'
            USING ERRCODE = '22023';
        END IF;
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
        AND assignment.assigned_member_id IS NULL
        AND assignment.assigned_external_creative_id =
            p_external_creative_id
        AND assignment.ended_at IS NULL
      LIMIT 1
      FOR UPDATE;

      v_has_current := FOUND;

      IF v_has_current THEN
        RETURN v_current;
      END IF;
    END IF;

    v_changed_at := now();

    IF p_assignment_role IN (
         'lead_photographer',
         'lead_videographer'
       )
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
        IF p_assignment_role =
             'lead_photographer' THEN
          RAISE EXCEPTION
            'assign_booking_external_creative: current Lead Photographer changed during replacement'
            USING ERRCODE = '40001';
        ELSE
          RAISE EXCEPTION
            'assign_booking_external_creative: current Lead Videographer changed during replacement'
            USING ERRCODE = '40001';
        END IF;
      END IF;

      INSERT INTO public.booking_team_assignments (
        organization_id,
        booking_id,
        assignment_role,
        assigned_member_id,
        assigned_external_creative_id,
        assigned_at,
        assigned_by
      )
      VALUES (
        v_booking.organization_id,
        v_booking.id,
        p_assignment_role,
        NULL,
        p_external_creative_id,
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
          'subject_type',
            CASE
              WHEN v_closed.assigned_member_id IS NOT NULL
                THEN 'member'
              ELSE 'external'
            END,
          'assigned_member_id',
            v_closed.assigned_member_id,
          'assigned_external_creative_id',
            v_closed.assigned_external_creative_id,
          'is_current',
            false
        ),
        jsonb_build_object(
          'assignment_id',
            v_result.id,
          'assignment_role',
            v_result.assignment_role,
          'subject_type',
            'external',
          'assigned_member_id',
            NULL,
          'assigned_external_creative_id',
            v_result.assigned_external_creative_id,
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

    INSERT INTO public.booking_team_assignments (
      organization_id,
      booking_id,
      assignment_role,
      assigned_member_id,
      assigned_external_creative_id,
      assigned_at,
      assigned_by
    )
    VALUES (
      v_booking.organization_id,
      v_booking.id,
      p_assignment_role,
      NULL,
      p_external_creative_id,
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
        'subject_type',
          'external',
        'assigned_member_id',
          NULL,
        'assigned_external_creative_id',
          v_result.assigned_external_creative_id,
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

  IF v_reason IS NULL THEN
    RAISE EXCEPTION
      'assign_booking_external_creative: unassignment requires a change reason'
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
    AND assignment.assigned_member_id IS NULL
    AND assignment.assigned_external_creative_id =
        p_external_creative_id
    AND assignment.ended_at IS NULL
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    SELECT assignment.*
    INTO v_result
    FROM public.booking_team_assignments assignment
    WHERE assignment.organization_id =
          v_booking.organization_id
      AND assignment.booking_id =
          v_booking.id
      AND assignment.assignment_role =
          p_assignment_role
      AND assignment.assigned_member_id IS NULL
      AND assignment.assigned_external_creative_id =
          p_external_creative_id
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
      'assign_booking_external_creative: external creative has never held this booking assignment role'
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
      'assign_booking_external_creative: current assignment changed during unassignment'
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
      'subject_type',
        'external',
      'assigned_member_id',
        NULL,
      'assigned_external_creative_id',
        v_result.assigned_external_creative_id,
      'is_current',
        true
    ),
    jsonb_build_object(
      'assignment_id',
        v_result.id,
      'assignment_role',
        v_result.assignment_role,
      'subject_type',
        'external',
      'assigned_member_id',
        NULL,
      'assigned_external_creative_id',
        v_result.assigned_external_creative_id,
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
-- Section I — Assignment RPC / guard execution boundary
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
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.create_external_creative(
  uuid,
  text
)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.create_external_creative(
  uuid,
  text
)
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.assign_booking_external_creative(
  uuid,
  text,
  uuid,
  boolean,
  text
)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.assign_booking_external_creative(
  uuid,
  text,
  uuid,
  boolean,
  text
)
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_booking_team_assignment_guard()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.lsh_booking_team_assignment_guard()
TO service_role;

-- =====================================================================
-- Section J — Structured commercial operational requirements
-- =====================================================================

CREATE TABLE public.commercial_operational_requirements (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    uuid NOT NULL,
  package_version_id uuid,
  addon_version_id   uuid,
  requirement_key    text NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT commercial_operational_requirements_organization_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_operational_requirements_package_fkey
    FOREIGN KEY (
      organization_id,
      package_version_id
    )
    REFERENCES public.commercial_package_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_operational_requirements_addon_fkey
    FOREIGN KEY (
      organization_id,
      addon_version_id
    )
    REFERENCES public.commercial_addon_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_operational_requirements_source_xor_chk
    CHECK (
      (
        package_version_id IS NOT NULL
        AND addon_version_id IS NULL
      )
      OR
      (
        package_version_id IS NULL
        AND addon_version_id IS NOT NULL
      )
    ),

  CONSTRAINT commercial_operational_requirements_key_chk
    CHECK (
      requirement_key IN (
        'lead_videographer'
      )
    )
);

CREATE UNIQUE INDEX commercial_operational_requirements_package_uidx
ON public.commercial_operational_requirements (
  organization_id,
  package_version_id,
  requirement_key
)
WHERE package_version_id IS NOT NULL;

CREATE UNIQUE INDEX commercial_operational_requirements_addon_uidx
ON public.commercial_operational_requirements (
  organization_id,
  addon_version_id,
  requirement_key
)
WHERE addon_version_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.lsh_commercial_operational_requirement_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'commercial operational requirement evidence is append-only and immutable';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER commercial_operational_requirements_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.commercial_operational_requirements
FOR EACH ROW
EXECUTE FUNCTION public.lsh_commercial_operational_requirement_guard();

ALTER TABLE public.commercial_operational_requirements
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.commercial_operational_requirements
FORCE ROW LEVEL SECURITY;

CREATE POLICY commercial_operational_requirements_staff_read
ON public.commercial_operational_requirements
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

REVOKE ALL
ON TABLE public.commercial_operational_requirements
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.commercial_operational_requirements
TO authenticated;

GRANT ALL
ON TABLE public.commercial_operational_requirements
TO service_role;

REVOKE ALL
ON FUNCTION public.lsh_commercial_operational_requirement_guard()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.lsh_commercial_operational_requirement_guard()
TO service_role;

-- =====================================================================
-- Section K — Initial Lead Videographer requirement seeds
-- =====================================================================

INSERT INTO public.commercial_operational_requirements (
  organization_id,
  package_version_id,
  addon_version_id,
  requirement_key
)
SELECT
  package.organization_id,
  version.id,
  NULL,
  'lead_videographer'
FROM public.commercial_packages package
JOIN public.commercial_package_versions version
  ON version.organization_id =
     package.organization_id
 AND version.package_id =
     package.id
WHERE package.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND package.package_key IN (
    'maternity_diamond',
    'maternity_emerald',
    'newborn_emerald',
    'sitter_diamond',
    'sitter_emerald'
  )
  AND version.version_number = 1;

INSERT INTO public.commercial_operational_requirements (
  organization_id,
  package_version_id,
  addon_version_id,
  requirement_key
)
SELECT
  addon.organization_id,
  NULL,
  version.id,
  'lead_videographer'
FROM public.commercial_addons addon
JOIN public.commercial_addon_versions version
  ON version.organization_id =
     addon.organization_id
 AND version.addon_id =
     addon.id
WHERE addon.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND addon.addon_key =
      'cinematic_reel'
  AND version.version_number = 1;

-- =====================================================================
-- Section L — Final validation gates
-- =====================================================================

DO $s10_6a_assertions$
DECLARE
  v_count integer;
  v_permissions text[];
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.roles;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: expected 12 roles, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 230 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: expected 230 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT array_agg(
           permission.key
           ORDER BY permission.key
         )
  INTO v_permissions
  FROM public.role_permissions mapping
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  WHERE role.key =
        'videographer';

  IF v_permissions IS DISTINCT FROM
       ARRAY[
         'booking.read',
         'org.read'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: videographer permissions are %',
      v_permissions;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'external_creatives';

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: external_creatives expected 5 columns, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'booking_team_assignments';

  IF v_count <> 11 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: booking_team_assignments expected 11 columns, found %',
      v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_team_assignments'
      AND column_name =
          'assigned_member_id'
      AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: assigned_member_id must be nullable';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_team_assignments'::regclass
      AND constraint_row.conname =
          'booking_team_assignments_subject_xor_chk'
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: assignment subject XOR missing';
  END IF;

  IF to_regclass(
       'public.booking_team_assignments_current_lead_videographer_uidx'
     ) IS NULL
     OR to_regclass(
          'public.booking_team_assignments_current_external_role_uidx'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: new assignment uniqueness indexes missing';
  END IF;

  IF to_regprocedure(
       'public.create_external_creative(uuid,text)'
     ) IS NULL
     OR to_regprocedure(
          'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: external creative RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_operational_requirements
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND requirement_key =
        'lead_videographer';

  IF v_count <> 6 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: expected 6 Lead Videographer requirement rows, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_operational_requirements
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND requirement_key =
        'lead_videographer'
    AND package_version_id IS NOT NULL;

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: expected 5 package Lead Videographer requirements, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_operational_requirements
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND requirement_key =
        'lead_videographer'
    AND addon_version_id IS NOT NULL;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: expected 1 add-on Lead Videographer requirement, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_class table_row
  JOIN pg_namespace namespace
    ON namespace.oid =
       table_row.relnamespace
  WHERE namespace.nspname =
        'public'
    AND table_row.relname IN (
      'external_creatives',
      'commercial_operational_requirements'
    )
    AND table_row.relrowsecurity
    AND table_row.relforcerowsecurity;

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: new tables must use FORCE RLS';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.external_creatives',
       'SELECT'
     )
     OR has_table_privilege(
          'authenticated',
          'public.external_creatives',
          'INSERT'
        )
     OR has_table_privilege(
          'authenticated',
          'public.external_creatives',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.external_creatives',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: external_creatives direct authenticated access is too broad';
  END IF;

  IF NOT has_table_privilege(
       'authenticated',
       'public.commercial_operational_requirements',
       'SELECT'
     )
     OR has_table_privilege(
          'authenticated',
          'public.commercial_operational_requirements',
          'INSERT'
        )
     OR has_table_privilege(
          'authenticated',
          'public.commercial_operational_requirements',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.commercial_operational_requirements',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6A validation failed: commercial requirement ACL mismatch';
  END IF;
END
$s10_6a_assertions$;

-- =====================================================================
-- Slice 6A containment
--
-- No journey transition is created or modified here.
-- No Stage 9 -> 10 RPC is introduced.
-- No freelancer receives auth, membership, role grants or app permissions.
-- No runtime free-text Video/Reels inference exists.
-- =====================================================================
