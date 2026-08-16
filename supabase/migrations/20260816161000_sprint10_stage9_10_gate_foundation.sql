-- =====================================================================
-- Sprint 10 Slice 6
-- Stage 9 -> 10 Journey Advancement Gate
--
-- Boundary:
--   * one controlled mark_booking_shoot_scheduled(uuid) RPC;
--   * no new canonical evidence tables;
--   * no Stage 10 -> 11 implementation;
--   * no evidence repair/backfill;
--   * no permission or role-grant expansion.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s10_slice6_preconditions$
BEGIN
  IF to_regprocedure(
       'public.mark_booking_shoot_scheduled(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 precondition failed: mark_booking_shoot_scheduled already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.booking_shoot_schedules') IS NULL
     OR to_regclass('public.booking_preparations') IS NULL
     OR to_regclass('public.booking_preparation_items') IS NULL
     OR to_regclass('public.booking_team_assignments') IS NULL
     OR to_regclass('public.external_creatives') IS NULL
     OR to_regclass('public.booking_safety_readiness') IS NULL
     OR to_regclass('public.booking_safety_signoffs') IS NULL
     OR to_regclass('public.quotation_line_items') IS NULL
     OR to_regclass('public.commercial_operational_requirements') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 precondition failed: required canonical evidence relation missing';
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
     ) IS NULL
     OR to_regprocedure(
       'public.lsh_preparation_taxonomy_v1(text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 precondition failed: required canonical helper unavailable';
  END IF;
END
$s10_slice6_preconditions$;

-- =====================================================================
-- Section B — Controlled Stage 9 -> 10 operation
-- =====================================================================

CREATE FUNCTION public.mark_booking_shoot_scheduled(
  p_booking_id uuid
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_schedule public.booking_shoot_schedules;
  v_preparation public.booking_preparations;
  v_readiness public.booking_safety_readiness;
  v_current_lead public.booking_team_assignments;

  v_actor uuid;

  v_state_count integer := 0;
  v_replay_transition_count integer := 0;

  v_package_line_count integer := 0;
  v_service_category text;

  v_expected_item_count integer := 0;
  v_actual_item_count integer := 0;
  v_unsatisfied_required_count integer := 0;

  v_video_required boolean := false;

  v_lead_ok boolean := false;
  v_stylist_ok boolean := false;
  v_video_ok boolean := false;
  v_signoff_ok boolean := true;

  v_scheduled_stage_id uuid;

  v_transitioned_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: authenticated actor required'
      USING ERRCODE = '42501';
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
      'mark_booking_shoot_scheduled: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exactly one current journey state.
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
      'mark_booking_shoot_scheduled: booking must have exactly one current journey state'
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
      'mark_booking_shoot_scheduled: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical Stage 10 replay.
  --
  -- Replay proves this exact Stage 9 -> 10 transition already exists.
  -- Mutable Stage 9 evidence is deliberately not re-evaluated.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order = 10
     AND v_stage.stage_key = 'shoot_scheduled' THEN

    SELECT count(*)
    INTO v_replay_transition_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id =
         transition_row.organization_id
     AND source_stage.id =
         transition_row.from_stage_id
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id =
         transition_row.organization_id
     AND destination_stage.id =
         transition_row.to_stage_id
    WHERE transition_row.organization_id =
          v_booking.organization_id
      AND transition_row.booking_id =
          v_booking.id
      AND transition_row.transition_key =
          'shoot_scheduled'
      AND source_stage.stage_order = 9
      AND source_stage.stage_key =
          'pre_shoot_preparation'
      AND destination_stage.stage_order = 10
      AND destination_stage.stage_key =
          'shoot_scheduled';

    IF v_replay_transition_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_shoot_scheduled: Shoot Scheduled replay history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  IF v_stage.stage_order <> 9
     OR v_stage.stage_key <>
          'pre_shoot_preparation' THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: booking must be exactly Pre-Shoot Preparation'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve one authoritative package category.
  -- Accepted quotation structure is immutable booking truth.
  -- ---------------------------------------------------------------

  SELECT
    count(*),
    min(package.service_category)
  INTO
    v_package_line_count,
    v_service_category
  FROM public.quotation_line_items line
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       line.organization_id
   AND version.id =
       line.source_package_version_id
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE line.organization_id =
        v_booking.organization_id
    AND line.quotation_id =
        v_booking.source_quotation_id
    AND line.line_type =
        'package';

  IF v_package_line_count <> 1
     OR v_service_category IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: authoritative booking package category is structurally ambiguous'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)
  INTO v_expected_item_count
  FROM public.lsh_preparation_taxonomy_v1(
    v_service_category
  );

  IF v_expected_item_count = 0 THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: unsupported preparation service category'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: authoritative schedule tip.
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
      'mark_booking_shoot_scheduled: current authoritative reserved shoot schedule required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 4: one preparation + immutable checklist snapshot.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_actual_item_count
  FROM public.booking_preparations preparation
  WHERE preparation.organization_id =
        v_booking.organization_id
    AND preparation.booking_id =
        v_booking.id;

  IF v_actual_item_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: booking must have exactly one canonical preparation instance'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT preparation.*
  INTO v_preparation
  FROM public.booking_preparations preparation
  WHERE preparation.organization_id =
        v_booking.organization_id
    AND preparation.booking_id =
        v_booking.id
  FOR UPDATE;

  PERFORM item.id
  FROM public.booking_preparation_items item
  WHERE item.organization_id =
        v_booking.organization_id
    AND item.preparation_id =
        v_preparation.id
  ORDER BY
    item.sort_order,
    item.item_key,
    item.id
  FOR UPDATE;

  SELECT count(*)
  INTO v_actual_item_count
  FROM public.booking_preparation_items item
  WHERE item.organization_id =
        v_booking.organization_id
    AND item.preparation_id =
        v_preparation.id;

  IF v_actual_item_count <>
       v_expected_item_count THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: preparation checklist structure is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.lsh_preparation_taxonomy_v1(
      v_service_category
    ) expected
    FULL OUTER JOIN (
      SELECT item.*
      FROM public.booking_preparation_items item
      WHERE item.organization_id =
            v_booking.organization_id
        AND item.preparation_id =
            v_preparation.id
    ) actual
      ON actual.item_key =
         expected.item_key
    WHERE expected.item_key IS NULL
       OR actual.id IS NULL
       OR actual.service_category
            IS DISTINCT FROM
          v_service_category
       OR actual.taxonomy_version <>
            1::smallint
       OR actual.item_label
            IS DISTINCT FROM
          expected.item_label
       OR actual.is_required
            IS DISTINCT FROM
          expected.is_required
       OR actual.sort_order
            IS DISTINCT FROM
          expected.sort_order
  ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: preparation checklist structure is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)
  INTO v_unsatisfied_required_count
  FROM public.booking_preparation_items item
  WHERE item.organization_id =
        v_booking.organization_id
    AND item.preparation_id =
        v_preparation.id
    AND item.is_required
    AND NOT item.is_satisfied;

  IF v_unsatisfied_required_count <> 0 THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: all required preparation items must be satisfied'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Structured client Video/Reels requirement.
  --
  -- Presence of a Videographer assignment never creates the
  -- requirement. Only version-bound commercial evidence does.
  -- ---------------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.quotation_line_items line
    JOIN public.commercial_operational_requirements requirement
      ON requirement.organization_id =
         line.organization_id
     AND requirement.requirement_key =
         'lead_videographer'
     AND (
       (
         line.source_package_version_id IS NOT NULL
         AND requirement.package_version_id =
             line.source_package_version_id
       )
       OR
       (
         line.source_addon_version_id IS NOT NULL
         AND requirement.addon_version_id =
             line.source_addon_version_id
       )
     )
    WHERE line.organization_id =
          v_booking.organization_id
      AND line.quotation_id =
          v_booking.source_quotation_id
  )
  INTO v_video_required;

  -- ---------------------------------------------------------------
  -- Lock order 5: current booking-team assignment rows.
  -- ---------------------------------------------------------------

  PERFORM assignment.id
  FROM public.booking_team_assignments assignment
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.ended_at IS NULL
  ORDER BY
    assignment.assignment_role,
    assignment.id
  FOR UPDATE;

  SELECT assignment.*
  INTO v_current_lead
  FROM public.booking_team_assignments assignment
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.assignment_role =
        'lead_photographer'
    AND assignment.ended_at IS NULL
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: current Lead Photographer assignment required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 6: exact current readiness revision.
  -- ---------------------------------------------------------------

  SELECT readiness.*
  INTO v_readiness
  FROM public.booking_safety_readiness readiness
  WHERE readiness.organization_id =
        v_booking.organization_id
    AND readiness.booking_id =
        v_booking.id
    AND readiness.superseded_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: current safety readiness evidence required'
      USING ERRCODE = '22023';
  END IF;

  IF v_readiness.service_category
       IS DISTINCT FROM
       v_service_category THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: current readiness category does not match booking category'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 7: required internal members / grants and external IDs.
  --
  -- Booking lock already serializes all canonical assignment mutation.
  -- These locks make current eligibility itself transactionally stable.
  -- ---------------------------------------------------------------

  PERFORM member.id
  FROM public.organization_members member
  JOIN public.booking_team_assignments assignment
    ON assignment.organization_id =
       member.organization_id
   AND assignment.assigned_member_id =
       member.id
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.ended_at IS NULL
    AND assignment.assigned_member_id IS NOT NULL
    AND (
      assignment.assignment_role IN (
        'lead_photographer',
        'stylist'
      )
      OR (
        v_video_required
        AND assignment.assignment_role =
            'lead_videographer'
      )
    )
  ORDER BY member.id
  FOR UPDATE OF member;

  PERFORM grant_row.id
  FROM public.member_role_grants grant_row
  JOIN public.roles role
    ON role.id =
       grant_row.role_id
  JOIN public.booking_team_assignments assignment
    ON assignment.organization_id =
       grant_row.organization_id
   AND assignment.assigned_member_id =
       grant_row.organization_member_id
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.ended_at IS NULL
    AND assignment.assigned_member_id IS NOT NULL
    AND grant_row.revoked_at IS NULL
    AND role.key =
        CASE assignment.assignment_role
          WHEN 'lead_photographer'
            THEN 'photographer'
          WHEN 'stylist'
            THEN 'stylist'
          WHEN 'lead_videographer'
            THEN 'videographer'
          ELSE NULL
        END
    AND (
      assignment.assignment_role IN (
        'lead_photographer',
        'stylist'
      )
      OR (
        v_video_required
        AND assignment.assignment_role =
            'lead_videographer'
      )
    )
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
  ORDER BY grant_row.id
  FOR UPDATE OF grant_row;

  PERFORM external.id
  FROM public.external_creatives external
  JOIN public.booking_team_assignments assignment
    ON assignment.organization_id =
       external.organization_id
   AND assignment.assigned_external_creative_id =
       external.id
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.ended_at IS NULL
    AND assignment.assigned_external_creative_id IS NOT NULL
    AND (
      assignment.assignment_role IN (
        'lead_photographer',
        'stylist'
      )
      OR (
        v_video_required
        AND assignment.assignment_role =
            'lead_videographer'
      )
    )
  ORDER BY external.id
  FOR UPDATE OF external;

  -- ---------------------------------------------------------------
  -- Mandatory Lead Photographer qualification.
  -- Internal and external subjects are both valid.
  -- ---------------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.booking_team_assignments assignment
    LEFT JOIN public.organization_members member
      ON member.organization_id =
         assignment.organization_id
     AND member.id =
         assignment.assigned_member_id
    LEFT JOIN public.external_creatives external
      ON external.organization_id =
         assignment.organization_id
     AND external.id =
         assignment.assigned_external_creative_id
    WHERE assignment.organization_id =
          v_booking.organization_id
      AND assignment.booking_id =
          v_booking.id
      AND assignment.assignment_role =
          'lead_photographer'
      AND assignment.ended_at IS NULL
      AND (
        (
          assignment.assigned_member_id IS NOT NULL
          AND assignment.assigned_external_creative_id IS NULL
          AND member.status =
              'active'::public.member_status
          AND EXISTS (
            SELECT 1
            FROM public.member_role_grants grant_row
            JOIN public.roles role
              ON role.id =
                 grant_row.role_id
            WHERE grant_row.organization_id =
                  assignment.organization_id
              AND grant_row.organization_member_id =
                  assignment.assigned_member_id
              AND grant_row.revoked_at IS NULL
              AND role.key =
                  'photographer'
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
          )
        )
        OR
        (
          assignment.assigned_member_id IS NULL
          AND assignment.assigned_external_creative_id IS NOT NULL
          AND external.id IS NOT NULL
        )
      )
  )
  INTO v_lead_ok;

  IF NOT v_lead_ok THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: current Lead Photographer is not operationally eligible'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Mandatory Stylist qualification.
  -- At least one currently qualifying internal/external Stylist.
  -- ---------------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.booking_team_assignments assignment
    LEFT JOIN public.organization_members member
      ON member.organization_id =
         assignment.organization_id
     AND member.id =
         assignment.assigned_member_id
    LEFT JOIN public.external_creatives external
      ON external.organization_id =
         assignment.organization_id
     AND external.id =
         assignment.assigned_external_creative_id
    WHERE assignment.organization_id =
          v_booking.organization_id
      AND assignment.booking_id =
          v_booking.id
      AND assignment.assignment_role =
          'stylist'
      AND assignment.ended_at IS NULL
      AND (
        (
          assignment.assigned_member_id IS NOT NULL
          AND assignment.assigned_external_creative_id IS NULL
          AND member.status =
              'active'::public.member_status
          AND EXISTS (
            SELECT 1
            FROM public.member_role_grants grant_row
            JOIN public.roles role
              ON role.id =
                 grant_row.role_id
            WHERE grant_row.organization_id =
                  assignment.organization_id
              AND grant_row.organization_member_id =
                  assignment.assigned_member_id
              AND grant_row.revoked_at IS NULL
              AND role.key =
                  'stylist'
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
          )
        )
        OR
        (
          assignment.assigned_member_id IS NULL
          AND assignment.assigned_external_creative_id IS NOT NULL
          AND external.id IS NOT NULL
        )
      )
  )
  INTO v_stylist_ok;

  IF NOT v_stylist_ok THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: current Stylist assignment required and must be operationally eligible'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Conditional Lead Videographer qualification.
  -- Supporting Videographer remains optional.
  -- ---------------------------------------------------------------

  IF v_video_required THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.booking_team_assignments assignment
      LEFT JOIN public.organization_members member
        ON member.organization_id =
           assignment.organization_id
       AND member.id =
           assignment.assigned_member_id
      LEFT JOIN public.external_creatives external
        ON external.organization_id =
           assignment.organization_id
       AND external.id =
           assignment.assigned_external_creative_id
      WHERE assignment.organization_id =
            v_booking.organization_id
        AND assignment.booking_id =
            v_booking.id
        AND assignment.assignment_role =
            'lead_videographer'
        AND assignment.ended_at IS NULL
        AND (
          (
            assignment.assigned_member_id IS NOT NULL
            AND assignment.assigned_external_creative_id IS NULL
            AND member.status =
                'active'::public.member_status
            AND EXISTS (
              SELECT 1
              FROM public.member_role_grants grant_row
              JOIN public.roles role
                ON role.id =
                   grant_row.role_id
              WHERE grant_row.organization_id =
                    assignment.organization_id
                AND grant_row.organization_member_id =
                    assignment.assigned_member_id
                AND grant_row.revoked_at IS NULL
                AND role.key =
                    'videographer'
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
            )
          )
          OR
          (
            assignment.assigned_member_id IS NULL
            AND assignment.assigned_external_creative_id IS NOT NULL
            AND external.id IS NOT NULL
          )
        )
    )
    INTO v_video_ok;

    IF NOT v_video_ok THEN
      RAISE EXCEPTION
        'mark_booking_shoot_scheduled: client Video/Reels requires a current operationally eligible Lead Videographer'
        USING ERRCODE = '22023';
    END IF;
  ELSE
    v_video_ok := true;
  END IF;

  -- ---------------------------------------------------------------
  -- Exact safety/comfort applicability.
  -- ---------------------------------------------------------------

  IF (
       v_service_category = 'newborn'
       AND (
         v_readiness.safety_state <> 'ready'
         OR v_readiness.comfort_state <> 'ready'
       )
     )
     OR (
       v_service_category = 'maternity'
       AND (
         v_readiness.safety_state <>
           'not_applicable'
         OR v_readiness.comfort_state <>
           'ready'
       )
     )
     OR (
       v_service_category = 'sitter'
       AND (
         v_readiness.safety_state <> 'ready'
         OR v_readiness.comfort_state <> 'ready'
       )
     ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: applicable safety and comfort readiness must be complete'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Newborn formal sign-off qualification.
  --
  -- Administrative sign-offs remain valid for the same readiness
  -- revision. Photographer sign-offs are revalidated against the
  -- current internal Lead assignment and live Photographer role.
  -- ---------------------------------------------------------------

  IF v_service_category = 'newborn' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.booking_safety_signoffs signoff
      WHERE signoff.organization_id =
            v_booking.organization_id
        AND signoff.booking_id =
            v_booking.id
        AND signoff.readiness_id =
            v_readiness.id
        AND (
          signoff.signoff_authority IN (
            'founder',
            'studio_manager'
          )
          OR
          (
            signoff.signoff_authority =
              'lead_photographer'
            AND v_current_lead.id IS NOT NULL
            AND v_current_lead.assigned_member_id
                  IS NOT NULL
            AND v_current_lead.assigned_external_creative_id
                  IS NULL
            AND signoff.lead_assignment_id =
                v_current_lead.id
            AND signoff.signed_by =
                v_current_lead.assigned_member_id
            AND EXISTS (
              SELECT 1
              FROM public.organization_members member
              WHERE member.organization_id =
                    v_booking.organization_id
                AND member.id =
                    signoff.signed_by
                AND member.status =
                    'active'::public.member_status
            )
            AND EXISTS (
              SELECT 1
              FROM public.member_role_grants grant_row
              JOIN public.roles role
                ON role.id =
                   grant_row.role_id
              WHERE grant_row.organization_id =
                    v_booking.organization_id
                AND grant_row.organization_member_id =
                    signoff.signed_by
                AND grant_row.revoked_at IS NULL
                AND role.key =
                    'photographer'
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
            )
          )
        )
    )
    INTO v_signoff_ok;

    IF NOT v_signoff_ok THEN
      RAISE EXCEPTION
        'mark_booking_shoot_scheduled: qualifying current Newborn formal sign-off required'
        USING ERRCODE = '22023';
    END IF;
  ELSE
    v_signoff_ok := true;
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve canonical Stage 10.
  -- ---------------------------------------------------------------

  SELECT stage.id
  INTO v_scheduled_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.stage_order = 10
    AND stage.stage_key =
        'shoot_scheduled'
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: canonical Shoot Scheduled stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Append transition before changing current state.
  -- Existing append-only guard validates actor and destination stage.
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
    v_scheduled_stage_id,
    'shoot_scheduled',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Optimistic journey-version advance.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_scheduled_stage_id,
    stage_entered_at =
      v_transitioned_at,
    version =
      state.version + 1,
    updated_at =
      v_transitioned_at,
    updated_by =
      v_actor
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id
    AND state.version =
        v_state.version;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_scheduled: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- One structural non-sensitive audit event.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.shoot_scheduled',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage',
        v_stage.stage_key,
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'shoot_scheduled',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'transition_key',
        'shoot_scheduled',
      'source_quotation_id',
        v_booking.source_quotation_id,
      'service_category',
        v_service_category,
      'reserved_schedule_version',
        v_schedule.schedule_version,
      'schedule_ok',
        true,
      'preparation_ok',
        true,
      'team_ok',
        true,
      'readiness_ok',
        true,
      'signoff_ok',
        v_signoff_ok,
      'lead_videographer_required',
        v_video_required
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$$;

-- =====================================================================
-- Section C — RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_scheduled(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_scheduled(uuid)
FROM anon;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_scheduled(uuid)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_scheduled(uuid)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.mark_booking_shoot_scheduled(uuid)
TO authenticated;

COMMENT ON FUNCTION public.mark_booking_shoot_scheduled(uuid) IS
  'Advance one authorized booking from canonical Stage 9 Pre-Shoot Preparation to Stage 10 Shoot Scheduled only after all frozen Sprint 10 operational gates pass.';

-- =====================================================================
-- Section D — Migration assertions
-- =====================================================================

DO $s10_slice6_assertions$
DECLARE
  v_count integer;
BEGIN
  IF to_regprocedure(
       'public.mark_booking_shoot_scheduled(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 validation failed: gate RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc procedure
  JOIN pg_namespace namespace
    ON namespace.oid =
       procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname =
        'mark_booking_shoot_scheduled'
    AND pg_get_function_identity_arguments(
          procedure.oid
        ) = 'p_booking_id uuid'
    AND pg_get_function_result(
          procedure.oid
        ) = 'bookings'
    AND procedure.prosecdef
    AND procedure.proconfig =
        ARRAY['search_path=""']::text[];

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 validation failed: RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.mark_booking_shoot_scheduled(uuid)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 validation failed: authenticated EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.mark_booking_shoot_scheduled(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 validation failed: anon EXECUTE must be denied';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.mark_booking_shoot_scheduled(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 6 validation failed: service_role EXECUTE must remain unavailable';
  END IF;
END
$s10_slice6_assertions$;
