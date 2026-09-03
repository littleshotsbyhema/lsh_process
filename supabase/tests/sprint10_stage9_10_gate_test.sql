CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(92);

-- =====================================================================
-- Sprint 10 Slice 6 — Stage 9 -> 10 Journey Advancement Gate
--
-- Tranche A:
--   * RPC structural/security contract;
--   * canonical Maternity no-video happy path;
--   * Assistant explicitly absent and non-blocking;
--   * Videographer explicitly absent and non-blocking;
--   * exact Stage 10 replay.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Part 1 — RPC structural / execution contract
-- ---------------------------------------------------------------------

-- 1
SELECT ok(
  to_regprocedure(
    'public.mark_booking_shoot_scheduled(uuid)'
  ) IS NOT NULL,
  'mark_booking_shoot_scheduled(uuid) exists'
);

-- 2
SELECT is(
  (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_proc procedure
    JOIN pg_namespace namespace
      ON namespace.oid =
         procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.oid =
          'public.mark_booking_shoot_scheduled(uuid)'::regprocedure
  ),
  'bookings'::text,
  'mark_booking_shoot_scheduled returns bookings'
);

-- 3
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.mark_booking_shoot_scheduled(uuid)'::regprocedure
  ),
  'mark_booking_shoot_scheduled is SECURITY DEFINER'
);

-- 4
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.mark_booking_shoot_scheduled(uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'mark_booking_shoot_scheduled uses an empty search_path'
);

-- 5
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_shoot_scheduled(uuid)',
    'EXECUTE'
  ),
  'authenticated may execute mark_booking_shoot_scheduled'
);

-- 6
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.mark_booking_shoot_scheduled(uuid)',
    'EXECUTE'
  ),
  'anon may not execute mark_booking_shoot_scheduled'
);

-- 7
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.mark_booking_shoot_scheduled(uuid)',
    'EXECUTE'
  ),
  'service_role is not granted public Slice 6 RPC execution'
);

-- ---------------------------------------------------------------------
-- Part 2 — Canonical authenticated Founder fixture
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES
  ('8a000000-0000-0000-0000-000000000001'::uuid),
  ('8a000000-0000-0000-0000-000000000002'::uuid),
  ('8a000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '8a000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000001',
  'active',
  'S10 Slice 6 Founder'
),
(
  '8a000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000002',
  'active',
  'S10 Slice 6 Photographer'
),
(
  '8a000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000003',
  'active',
  'S10 Slice 6 Stylist'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role.id,
  fixture.branch_id
FROM (
  VALUES
    (
      '8a000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8a000000-0000-0000-0000-000000000102'::uuid,
      'photographer'::text,
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '8a000000-0000-0000-0000-000000000103'::uuid,
      'stylist'::text,
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

UPDATE public.organizations
SET status =
    'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.families (
  id,
  organization_id,
  branch_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES (
  '8a000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  'LSH-23456A',
  'S10 Slice 6 Maternity Family',
  'Slice 6 Maternity Family',
  'active',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
);

CREATE TEMP TABLE s10g_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000201',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10g_quote),
  (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'maternity_gold'
      AND version.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10g_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10g_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10g_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10g_quote)
);

CREATE TEMP TABLE s10g_schedule_proposed AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10g_booking),
  '2030-06-01 10:00:00+05:30'::timestamptz,
  '2030-06-01 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'S10 Slice 6 Maternity fixture'
);

-- Reserve the canonical proposal without exercising the financial
-- confirmation flow, which is outside this dedicated Stage 9 -> 10 test.
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
SELECT
  organization_id,
  booking_id,
  schedule_version + 1,
  id,
  'reserved',
  scheduled_start_at,
  scheduled_end_at,
  timezone,
  location_type,
  location_details,
  NULL,
  '8a000000-0000-0000-0000-000000000101'::uuid
FROM s10g_schedule_proposed;

-- Move the booking fixture from canonical Stage 7 to Stage 8.
INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_slice6_fixture_booking_confirmed',
  now(),
  '8a000000-0000-0000-0000-000000000101'::uuid
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10g_booking);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_at =
    now(),
  updated_by =
    '8a000000-0000-0000-0000-000000000101'::uuid
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10g_booking)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

CREATE TEMP TABLE s10g_preparation AS
SELECT *
FROM public.start_pre_shoot_preparation(
  (SELECT id FROM s10g_booking)
);

DO $s10g_complete_required$
DECLARE
  v_item_id uuid;
BEGIN
  FOR v_item_id IN
    SELECT item.id
    FROM public.booking_preparation_items item
    WHERE item.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND item.preparation_id =
          (SELECT id FROM s10g_preparation)
      AND item.is_required
    ORDER BY
      item.sort_order,
      item.item_key
  LOOP
    PERFORM public.update_pre_shoot_preparation_item(
      v_item_id,
      true
    );
  END LOOP;
END
$s10g_complete_required$;

CREATE TEMP TABLE s10g_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10g_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000102',
  true,
  NULL
);

CREATE TEMP TABLE s10g_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10g_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

CREATE TEMP TABLE s10g_readiness AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10g_booking),
  'not_applicable',
  'ready'
);

-- 8
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10g_booking)
  ),
  'pre_shoot_preparation'::text,
  'happy-path fixture begins exactly at Stage 9'
);

-- 9
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10g_booking)
      AND assignment.assignment_role =
          'assistant'
      AND assignment.ended_at IS NULL
  ),
  0::bigint,
  'Maternity happy path contains no Assistant assignment'
);

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10g_booking)
      AND assignment.assignment_role IN (
        'lead_videographer',
        'supporting_videographer'
      )
      AND assignment.ended_at IS NULL
  ),
  0::bigint,
  'non-video Maternity happy path contains no Videographer assignment'
);

CREATE TEMP TABLE s10g_before AS
SELECT
  state.version AS journey_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
  ) AS transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          state.booking_id
  ) AS shoot_scheduled_audit_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules schedule
    WHERE schedule.booking_id =
          state.booking_id
  ) AS schedule_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10g_preparation)
  ) AS preparation_item_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          state.booking_id
  ) AS team_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          state.booking_id
  ) AS readiness_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10g_booking);

-- 11
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10g_booking)
  )
  $$,
  'complete Maternity evidence advances Stage 9 -> 10 without Assistant or Videographer'
);

-- 12
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10g_booking)
  ),
  'shoot_scheduled'::text,
  'successful gate advances exactly to Shoot Scheduled'
);

-- 13
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
          (SELECT id FROM s10g_booking)
  ),
  (
    SELECT journey_version + 1
    FROM s10g_before
  ),
  'successful gate increments journey version exactly once'
);

-- 14
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10g_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ),
  1::bigint,
  'successful gate appends exactly one shoot_scheduled transition'
);

-- 15
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10g_booking)
  ),
  1::bigint,
  'successful gate appends exactly one booking.shoot_scheduled audit event'
);

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules schedule
    WHERE schedule.booking_id =
          (SELECT id FROM s10g_booking)
  ),
  (
    SELECT schedule_count
    FROM s10g_before
  ),
  'successful gate does not mutate or append schedule evidence'
);

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10g_preparation)
  ),
  (
    SELECT preparation_item_count
    FROM s10g_before
  ),
  'successful gate does not mutate preparation-item cardinality'
);

-- 18
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10g_booking)
  ),
  (
    SELECT team_count
    FROM s10g_before
  ),
  'successful gate does not mutate team-assignment cardinality'
);

-- 19
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10g_booking)
  ),
  (
    SELECT readiness_count
    FROM s10g_before
  ),
  'successful gate does not mutate readiness cardinality'
);

-- 20
SELECT ok(
  (
    SELECT
      NOT (
        audit.metadata ?| ARRAY[
          'safety_state',
          'comfort_state',
          'external_creative_name',
          'external_creative_display_name',
          'assigned_member_id',
          'assigned_external_creative_id',
          'lead_assignment_id',
          'readiness_id',
          'signed_by'
        ]
      )
      AND
      NOT (
        audit.old_values ?| ARRAY[
          'safety_state',
          'comfort_state',
          'external_creative_name',
          'assigned_member_id',
          'readiness_id',
          'signed_by'
        ]
      )
      AND
      NOT (
        audit.new_values ?| ARRAY[
          'safety_state',
          'comfort_state',
          'external_creative_name',
          'assigned_member_id',
          'readiness_id',
          'signed_by'
        ]
      )
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10g_booking)
  ),
  'shoot-scheduled audit excludes restricted safety and creative identity detail'
);

CREATE TEMP TABLE s10g_after_first AS
SELECT
  state.version AS journey_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) AS transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          state.booking_id
  ) AS audit_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10g_booking);

-- 21
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10g_booking)
  )
  $$,
  'exact canonical Shoot Scheduled replay is idempotent'
);

-- 22
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
          (SELECT id FROM s10g_booking)
  ),
  (
    SELECT journey_version
    FROM s10g_after_first
  ),
  'Stage 10 replay does not increment journey version'
);

-- 23
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10g_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ),
  (
    SELECT transition_count
    FROM s10g_after_first
  ),
  'Stage 10 replay appends no duplicate transition'
);

-- 24
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10g_booking)
  ),
  (
    SELECT audit_count
    FROM s10g_after_first
  ),
  'Stage 10 replay appends no duplicate audit'
);

-- 25
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10g_booking)
      AND assignment.assignment_role =
          'assistant'
      AND assignment.ended_at IS NULL
  ),
  0::bigint,
  'successful advancement never manufactures an Assistant assignment'
);

-- 26
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10g_booking)
      AND assignment.assignment_role IN (
        'lead_videographer',
        'supporting_videographer'
      )
      AND assignment.ended_at IS NULL
  ),
  0::bigint,
  'non-video advancement never manufactures Videographer staffing'
);


-- =====================================================================
-- Tranche B — Blocking conditions + failure atomicity
--
-- Proves:
--   * only Stage 9 may advance;
--   * required preparation completion is blocking;
--   * current Lead Photographer is blocking;
--   * current safety readiness is blocking;
--   * current Stylist is blocking;
--   * failed attempts never mutate journey state, transition history
--     or shoot-scheduled audit history.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Part 3 — Wrong-stage rejection
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10b_wrong_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000201',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10b_wrong_quote),
  (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'maternity_gold'
      AND version.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10b_wrong_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10b_wrong_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10b_wrong_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10b_wrong_quote)
);

-- 27
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10b_wrong_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: booking must be exactly Pre-Shoot Preparation',
  'gate rejects a booking that is not at Stage 9'
);

-- 28
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10b_wrong_booking)
  ),
  'advance_pending'::text,
  'wrong-stage failure leaves the booking at Advance Pending'
);

-- 29
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10b_wrong_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ),
  0::bigint,
  'wrong-stage failure creates no shoot_scheduled transition'
);

-- ---------------------------------------------------------------------
-- Part 4 — Progressive Stage 9 blocking gates
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10b_gate_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000201',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10b_gate_quote),
  (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'maternity_gold'
      AND version.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10b_gate_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10b_gate_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10b_gate_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10b_gate_quote)
);

CREATE TEMP TABLE s10b_gate_schedule_proposed AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10b_gate_booking),
  '2030-06-02 10:00:00+05:30'::timestamptz,
  '2030-06-02 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'S10 Slice 6 blocking fixture'
);

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
SELECT
  organization_id,
  booking_id,
  schedule_version + 1,
  id,
  'reserved',
  scheduled_start_at,
  scheduled_end_at,
  timezone,
  location_type,
  location_details,
  NULL,
  '8a000000-0000-0000-0000-000000000101'::uuid
FROM s10b_gate_schedule_proposed;

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_slice6_fixture_booking_confirmed',
  now(),
  '8a000000-0000-0000-0000-000000000101'::uuid
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10b_gate_booking);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_at =
    now(),
  updated_by =
    '8a000000-0000-0000-0000-000000000101'::uuid
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10b_gate_booking)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

CREATE TEMP TABLE s10b_gate_preparation AS
SELECT *
FROM public.start_pre_shoot_preparation(
  (SELECT id FROM s10b_gate_booking)
);

CREATE TEMP TABLE s10b_gate_baseline AS
SELECT
  state.version AS journey_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) AS shoot_transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          state.booking_id
  ) AS shoot_audit_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10b_gate_booking);

-- 30
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10b_gate_booking)
  ),
  'pre_shoot_preparation'::text,
  'blocking fixture begins exactly at Stage 9'
);

-- 31
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10b_gate_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: all required preparation items must be satisfied',
  'unsatisfied required preparation blocks Stage 9 -> 10'
);

DO $s10b_complete_required$
DECLARE
  v_item_id uuid;
BEGIN
  FOR v_item_id IN
    SELECT item.id
    FROM public.booking_preparation_items item
    WHERE item.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND item.preparation_id =
          (SELECT id FROM s10b_gate_preparation)
      AND item.is_required
    ORDER BY
      item.sort_order,
      item.item_key
  LOOP
    PERFORM public.update_pre_shoot_preparation_item(
      v_item_id,
      true
    );
  END LOOP;
END
$s10b_complete_required$;

-- 32
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10b_gate_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: current Lead Photographer assignment required',
  'missing current Lead Photographer blocks Stage 9 -> 10'
);

CREATE TEMP TABLE s10b_gate_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10b_gate_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000102',
  true,
  NULL
);

-- 33
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10b_gate_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: current safety readiness evidence required',
  'missing current safety readiness blocks Stage 9 -> 10'
);

CREATE TEMP TABLE s10b_gate_readiness AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10b_gate_booking),
  'not_applicable',
  'ready'
);

-- 34
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10b_gate_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: current Stylist assignment required and must be operationally eligible',
  'missing current Stylist blocks Stage 9 -> 10'
);

-- 35
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10b_gate_booking)
  ),
  'pre_shoot_preparation'::text,
  'all rejected gate attempts leave the fixture at Stage 9'
);

-- 36
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
          (SELECT id FROM s10b_gate_booking)
  ),
  (
    SELECT journey_version
    FROM s10b_gate_baseline
  ),
  'failed Stage 9 -> 10 attempts never change journey version'
);

-- 37
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10b_gate_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ),
  (
    SELECT shoot_transition_count
    FROM s10b_gate_baseline
  ),
  'failed Stage 9 -> 10 attempts append no shoot_scheduled transition'
);

-- 38
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10b_gate_booking)
  ),
  (
    SELECT shoot_audit_count
    FROM s10b_gate_baseline
  ),
  'failed Stage 9 -> 10 attempts append no shoot-scheduled audit event'
);


-- =====================================================================
-- Tranche C — Structured Video/Reels + external creative staffing
--
-- Proves:
--   * Videographer staffing alone never creates a client Video/Reels
--     requirement;
--   * package-version operational evidence creates the requirement;
--   * add-on-version operational evidence creates the requirement;
--   * external Lead Photographer, Stylist and Lead Videographer may
--     satisfy the frozen staffing gate;
--   * internal Videographer may satisfy a structured add-on requirement;
--   * Supporting Videographer remains optional/non-substitutive.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Shared Tranche C fixture helper.
--
-- Produces a fully prepared Stage 9 booking with:
--   * accepted quotation;
--   * reserved schedule;
--   * canonical preparation snapshot;
--   * all required preparation items satisfied;
--   * current safety readiness.
--
-- Staffing is deliberately left to each test case.
-- ---------------------------------------------------------------------

CREATE FUNCTION pg_temp.s10c_make_stage9_booking(
  p_package_key text,
  p_scheduled_start_at timestamptz,
  p_safety_state text,
  p_comfort_state text,
  p_add_cinematic_reel boolean
)
RETURNS uuid
LANGUAGE plpgsql
AS $s10c$
DECLARE
  v_quote public.quotations;
  v_booking public.bookings;
  v_proposal public.booking_shoot_schedules;
  v_preparation public.booking_preparations;

  v_package_version_id uuid;
  v_addon_version_id uuid;
  v_item_id uuid;
BEGIN
  SELECT version.id
  INTO v_package_version_id
  FROM public.commercial_package_versions version
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE package.package_key =
        p_package_key
    AND version.version_number = 1;

  IF v_package_version_id IS NULL THEN
    RAISE EXCEPTION
      's10c fixture: package version unavailable';
  END IF;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8a000000-0000-0000-0000-000000000201',
    NULL,
    NULL,
    NULL,
    NULL
  );

  PERFORM public.add_quotation_package_line(
    v_quote.id,
    v_package_version_id,
    NULL
  );

  IF p_add_cinematic_reel THEN
    SELECT version.id
    INTO v_addon_version_id
    FROM public.commercial_addon_versions version
    JOIN public.commercial_addons addon
      ON addon.organization_id =
         version.organization_id
     AND addon.id =
         version.addon_id
    WHERE addon.addon_key =
          'cinematic_reel'
      AND version.version_number = 1;

    IF v_addon_version_id IS NULL THEN
      RAISE EXCEPTION
        's10c fixture: cinematic_reel version unavailable';
    END IF;

    PERFORM public.add_quotation_addon_line(
      v_quote.id,
      v_addon_version_id,
      1,
      NULL
    );
  END IF;

  PERFORM public.transition_quotation(
    v_quote.id,
    'ready'::public.quotation_status
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'sent'::public.quotation_status
  );

  SELECT *
  INTO v_booking
  FROM public.accept_quotation(
    v_quote.id
  );

  SELECT *
  INTO v_proposal
  FROM public.propose_booking_shoot_schedule(
    v_booking.id,
    p_scheduled_start_at,
    p_scheduled_start_at + interval '2 hours',
    'Asia/Kolkata',
    'studio',
    'S10 Slice 6 Tranche C fixture'
  );

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
    v_proposal.organization_id,
    v_proposal.booking_id,
    v_proposal.schedule_version + 1,
    v_proposal.id,
    'reserved',
    v_proposal.scheduled_start_at,
    v_proposal.scheduled_end_at,
    v_proposal.timezone,
    v_proposal.location_type,
    v_proposal.location_details,
    NULL,
    '8a000000-0000-0000-0000-000000000101'::uuid
  );

  INSERT INTO public.booking_stage_transitions (
    organization_id,
    booking_id,
    from_stage_id,
    to_stage_id,
    transition_key,
    transitioned_at,
    transitioned_by
  )
  SELECT
    state.organization_id,
    state.booking_id,
    state.current_stage_id,
    target.id,
    's10_slice6_tranche_c_booking_confirmed',
    now(),
    '8a000000-0000-0000-0000-000000000101'::uuid
  FROM public.booking_journey_states state
  JOIN public.booking_journey_stages target
    ON target.organization_id =
       state.organization_id
   AND target.stage_key =
       'booking_confirmed'
   AND target.stage_order = 8
   AND target.is_active
  WHERE state.booking_id =
        v_booking.id;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      target.id,
    stage_entered_at =
      now(),
    version =
      state.version + 1,
    updated_at =
      now(),
    updated_by =
      '8a000000-0000-0000-0000-000000000101'::uuid
  FROM public.booking_journey_stages target
  WHERE state.booking_id =
        v_booking.id
    AND target.organization_id =
        state.organization_id
    AND target.stage_key =
        'booking_confirmed'
    AND target.stage_order = 8
    AND target.is_active;

  SELECT *
  INTO v_preparation
  FROM public.start_pre_shoot_preparation(
    v_booking.id
  );

  FOR v_item_id IN
    SELECT item.id
    FROM public.booking_preparation_items item
    WHERE item.organization_id =
          v_booking.organization_id
      AND item.preparation_id =
          v_preparation.id
      AND item.is_required
    ORDER BY
      item.sort_order,
      item.item_key
  LOOP
    PERFORM public.update_pre_shoot_preparation_item(
      v_item_id,
      true
    );
  END LOOP;

  PERFORM public.record_booking_safety_readiness(
    v_booking.id,
    p_safety_state,
    p_comfort_state
  );

  RETURN v_booking.id;
END
$s10c$;

-- ---------------------------------------------------------------------
-- Part 5 — Promotional/BTS Supporting Videographer does not create a
-- client Video/Reels requirement.
--
-- Reuse the complete Tranche B Stage 9 fixture. Its only missing
-- mandatory staffing evidence was Stylist.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10c_promo_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10b_gate_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

CREATE TEMP TABLE s10c_promo_external AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10b_gate_booking),
  'S10C Promo BTS Creative'
);

CREATE TEMP TABLE s10c_promo_support AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10b_gate_booking),
  'supporting_videographer',
  (SELECT id FROM s10c_promo_external),
  true,
  NULL
);

-- 39
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10b_gate_booking)
      AND assignment.assignment_role =
          'supporting_videographer'
      AND assignment.ended_at IS NULL
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10b_gate_booking)
      AND assignment.assignment_role =
          'lead_videographer'
      AND assignment.ended_at IS NULL
  ) = 0
  AND
  NOT EXISTS (
    SELECT 1
    FROM public.bookings booking
    JOIN public.quotation_line_items line
      ON line.organization_id =
         booking.organization_id
     AND line.quotation_id =
         booking.source_quotation_id
    JOIN public.commercial_operational_requirements requirement
      ON requirement.organization_id =
         line.organization_id
     AND requirement.requirement_key =
         'lead_videographer'
     AND (
       requirement.package_version_id =
         line.source_package_version_id
       OR requirement.addon_version_id =
         line.source_addon_version_id
     )
    WHERE booking.id =
          (SELECT id FROM s10b_gate_booking)
  ),
  'promotional Supporting Videographer does not create a structured client Video/Reels requirement'
);

-- 40
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10b_gate_booking)
  )
  $$,
  'non-video booking advances with Supporting Videographer and no Lead Videographer'
);

-- 41
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10b_gate_booking)
  ),
  'shoot_scheduled'::text,
  'promotional/BTS staffing leaves client Video requirement optional and booking reaches Stage 10'
);

-- ---------------------------------------------------------------------
-- Part 6 — Package-version requirement + fully external required team.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10c_package_booking AS
SELECT pg_temp.s10c_make_stage9_booking(
  'maternity_diamond',
  '2030-06-03 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  false
) AS id;

CREATE TEMP TABLE s10c_package_external_photo AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10c_package_booking),
  'S10C External Lead Photographer'
);

CREATE TEMP TABLE s10c_package_external_stylist AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10c_package_booking),
  'S10C External Stylist'
);

CREATE TEMP TABLE s10c_package_external_video AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10c_package_booking),
  'S10C External Lead Videographer'
);

CREATE TEMP TABLE s10c_package_lead_photo AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10c_package_booking),
  'lead_photographer',
  (SELECT id FROM s10c_package_external_photo),
  true,
  NULL
);

CREATE TEMP TABLE s10c_package_stylist AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10c_package_booking),
  'stylist',
  (SELECT id FROM s10c_package_external_stylist),
  true,
  NULL
);

-- 42
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.bookings booking
    JOIN public.quotation_line_items line
      ON line.organization_id =
         booking.organization_id
     AND line.quotation_id =
         booking.source_quotation_id
    JOIN public.commercial_operational_requirements requirement
      ON requirement.organization_id =
         line.organization_id
     AND requirement.package_version_id =
         line.source_package_version_id
     AND requirement.requirement_key =
         'lead_videographer'
    WHERE booking.id =
          (SELECT id FROM s10c_package_booking)
  ),
  1::bigint,
  'Maternity Diamond accepted package version structurally requires Lead Videographer'
);

-- 43
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10c_package_booking)
      AND assignment.assignment_role IN (
        'lead_photographer',
        'stylist'
      )
      AND assignment.ended_at IS NULL
      AND assignment.assigned_member_id IS NULL
      AND assignment.assigned_external_creative_id IS NOT NULL
  ),
  2::bigint,
  'external Lead Photographer and external Stylist satisfy current staffing subject shape'
);

-- 44
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10c_package_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: client Video/Reels requires a current operationally eligible Lead Videographer',
  'package-version Video requirement blocks without current Lead Videographer'
);

CREATE TEMP TABLE s10c_package_lead_video AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10c_package_booking),
  'lead_videographer',
  (SELECT id FROM s10c_package_external_video),
  true,
  NULL
);

-- 45
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10c_package_booking)
      AND assignment.assignment_role =
          'lead_videographer'
      AND assignment.ended_at IS NULL
      AND assignment.assigned_member_id IS NULL
      AND assignment.assigned_external_creative_id =
          (SELECT id FROM s10c_package_external_video)
  ),
  1::bigint,
  'external creative is current Lead Videographer for the package-required booking'
);

-- 46
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10c_package_booking)
      AND assignment.assignment_role IN (
        'lead_photographer',
        'stylist',
        'lead_videographer'
      )
      AND assignment.ended_at IS NULL
      AND assignment.assigned_member_id IS NULL
      AND assignment.assigned_external_creative_id IS NOT NULL
  ),
  3::bigint,
  'all three mandatory creative roles may be satisfied by current external identities'
);

-- 47
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10c_package_booking)
  )
  $$,
  'package-required Video booking advances with external Lead Photographer, Stylist and Lead Videographer'
);

-- 48
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10c_package_booking)
  ),
  'shoot_scheduled'::text,
  'package-version Video requirement with fully external team reaches Stage 10'
);

-- ---------------------------------------------------------------------
-- Part 7 — Add-on-version requirement.
--
-- sitter_gold itself has no Lead Videographer requirement.
-- cinematic_reel v1 does.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES (
  '8a000000-0000-0000-0000-000000000004'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '8a000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000004',
  'active',
  'S10 Slice 6 Internal Videographer'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '8a000000-0000-0000-0000-000000000104'::uuid,
  role.id,
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
FROM public.roles role
WHERE role.key =
      'videographer';

CREATE TEMP TABLE s10c_addon_booking AS
SELECT pg_temp.s10c_make_stage9_booking(
  'sitter_gold',
  '2030-06-04 10:00:00+05:30'::timestamptz,
  'ready',
  'ready',
  true
) AS id;

CREATE TEMP TABLE s10c_addon_lead_photo AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10c_addon_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000102',
  true,
  NULL
);

CREATE TEMP TABLE s10c_addon_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10c_addon_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

-- 49
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.bookings booking
    JOIN public.quotation_line_items line
      ON line.organization_id =
         booking.organization_id
     AND line.quotation_id =
         booking.source_quotation_id
    JOIN public.commercial_operational_requirements requirement
      ON requirement.organization_id =
         line.organization_id
     AND requirement.package_version_id =
         line.source_package_version_id
     AND requirement.requirement_key =
         'lead_videographer'
    WHERE booking.id =
          (SELECT id FROM s10c_addon_booking)
  )
  AND
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    JOIN public.quotation_line_items line
      ON line.organization_id =
         booking.organization_id
     AND line.quotation_id =
         booking.source_quotation_id
    JOIN public.commercial_operational_requirements requirement
      ON requirement.organization_id =
         line.organization_id
     AND requirement.addon_version_id =
         line.source_addon_version_id
     AND requirement.requirement_key =
         'lead_videographer'
    WHERE booking.id =
          (SELECT id FROM s10c_addon_booking)
  ),
  'Sitter Gold is non-video while accepted cinematic_reel add-on structurally creates Lead Videographer requirement'
);

-- 50
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10c_addon_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: client Video/Reels requires a current operationally eligible Lead Videographer',
  'cinematic_reel add-on requirement blocks without Lead Videographer'
);

CREATE TEMP TABLE s10c_addon_lead_video AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10c_addon_booking),
  'lead_videographer',
  '8a000000-0000-0000-0000-000000000104',
  true,
  NULL
);

-- 51
SELECT ok(
  (
    SELECT
      assignment.assigned_member_id =
        '8a000000-0000-0000-0000-000000000104'::uuid
      AND assignment.assigned_external_creative_id IS NULL
      AND assignment.ended_at IS NULL
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10c_addon_booking)
      AND assignment.assignment_role =
          'lead_videographer'
      AND assignment.ended_at IS NULL
  ),
  'internal member with live Videographer role is current Lead Videographer'
);

-- 52
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10c_addon_booking)
  )
  $$,
  'cinematic_reel add-on requirement advances after qualifying internal Lead Videographer assignment'
);

-- 53
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10c_addon_booking)
  ),
  'shoot_scheduled'::text,
  'add-on-version Video requirement reaches Stage 10 after qualifying staffing'
);


-- =====================================================================
-- Tranche D — Newborn formal sign-off revalidation
--
-- Proves:
--   * complete Newborn readiness alone is insufficient;
--   * ordinary Photographer sign-off binds to the exact current
--     internal Lead Photographer assignment;
--   * replacing the Lead invalidates the old Photographer sign-off
--     for Stage 9 -> 10 without rewriting historical evidence;
--   * the replacement current Lead can independently sign the same
--     readiness revision;
--   * sign-off on a superseded readiness revision never qualifies
--     the new current readiness revision;
--   * external Lead Photographer satisfies staffing but cannot itself
--     satisfy Photographer-authority sign-off;
--   * Studio Manager administrative sign-off stores no Lead dependency
--     and remains qualifying for the same readiness revision even if
--     that administrative signer is later suspended.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Additional canonical identities.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES
  ('8a000000-0000-0000-0000-000000000005'::uuid),
  ('8a000000-0000-0000-0000-000000000006'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '8a000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000005',
  'active',
  'S10 Slice 6 Replacement Photographer'
),
(
  '8a000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000006',
  'active',
  'S10 Slice 6 Studio Manager'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role.id,
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
FROM (
  VALUES
    (
      '8a000000-0000-0000-0000-000000000105'::uuid,
      'photographer'::text
    ),
    (
      '8a000000-0000-0000-0000-000000000106'::uuid,
      'studio_manager'::text
    )
) AS fixture(member_id, role_key)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

-- Restore Founder as the fixture-construction actor.
SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Part 8 — Photographer sign-off is bound to the exact current Lead
-- assignment interval.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10d_lead_booking AS
SELECT pg_temp.s10c_make_stage9_booking(
  'newborn_gold',
  '2030-06-05 10:00:00+05:30'::timestamptz,
  'ready',
  'ready',
  false
) AS id;

CREATE TEMP TABLE s10d_lead_one AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10d_lead_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000102',
  true,
  NULL
);

CREATE TEMP TABLE s10d_lead_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10d_lead_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

-- 54
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10d_lead_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: qualifying current Newborn formal sign-off required',
  'complete Newborn readiness still blocks without formal sign-off'
);

-- Current internal Lead Photographer signs.
SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10d_lead_one_signoff AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10d_lead_booking)
);

-- 55
SELECT ok(
  (
    SELECT
      signoff.signoff_authority =
        'lead_photographer'
      AND signoff.signed_by =
        '8a000000-0000-0000-0000-000000000102'::uuid
      AND signoff.lead_assignment_id =
        (SELECT id FROM s10d_lead_one)
      AND signoff.readiness_id =
        (
          SELECT readiness.id
          FROM public.booking_safety_readiness readiness
          WHERE readiness.booking_id =
                (SELECT id FROM s10d_lead_booking)
            AND readiness.superseded_at IS NULL
        )
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10d_lead_one_signoff)
  ),
  'Photographer sign-off snapshots exact current internal Lead assignment and readiness'
);

-- Restore Founder and replace the Lead.
SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10d_lead_two AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10d_lead_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000105',
  true,
  'Lead replacement for Stage 9 to 10 revalidation test'
);

-- 56
SELECT ok(
  (
    SELECT ended_at IS NOT NULL
    FROM public.booking_team_assignments
    WHERE id =
          (SELECT id FROM s10d_lead_one)
  )
  AND
  (
    SELECT
      ended_at IS NULL
      AND assigned_member_id =
        '8a000000-0000-0000-0000-000000000105'::uuid
    FROM public.booking_team_assignments
    WHERE id =
          (SELECT id FROM s10d_lead_two)
  ),
  'Lead replacement closes old assignment interval and establishes one new current Lead'
);

-- 57
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10d_lead_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: qualifying current Newborn formal sign-off required',
  'old Photographer sign-off no longer qualifies after Lead replacement'
);

-- Historical evidence must remain intact.
-- The replacement current Lead signs the same readiness revision.
SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000005',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10d_lead_two_signoff AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10d_lead_booking)
);

-- 58
SELECT ok(
  (
    SELECT
      signoff.signoff_authority =
        'lead_photographer'
      AND signoff.signed_by =
        '8a000000-0000-0000-0000-000000000105'::uuid
      AND signoff.lead_assignment_id =
        (SELECT id FROM s10d_lead_two)
      AND signoff.readiness_id =
        (SELECT readiness_id FROM s10d_lead_one_signoff)
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10d_lead_two_signoff)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.readiness_id =
          (SELECT readiness_id FROM s10d_lead_one_signoff)
  ) = 2,
  'replacement Lead signs same readiness independently while old immutable sign-off is preserved'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 59
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10d_lead_booking)
  )
  $$,
  'replacement current Lead Photographer sign-off qualifies Stage 9 -> 10'
);

-- 60
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10d_lead_booking)
  ),
  'shoot_scheduled'::text,
  'Newborn booking reaches Stage 10 only after sign-off matches replacement Lead'
);

-- ---------------------------------------------------------------------
-- Part 9 — Superseded readiness sign-off cannot qualify the current
-- readiness revision.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10d_revision_booking AS
SELECT pg_temp.s10c_make_stage9_booking(
  'newborn_gold',
  '2030-06-06 10:00:00+05:30'::timestamptz,
  'ready',
  'ready',
  false
) AS id;

CREATE TEMP TABLE s10d_revision_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10d_revision_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000102',
  true,
  NULL
);

CREATE TEMP TABLE s10d_revision_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10d_revision_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10d_revision_signoff_v1 AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10d_revision_booking)
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10d_revision_not_ready AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10d_revision_booking),
  'not_ready',
  'ready'
);

CREATE TEMP TABLE s10d_revision_ready_current AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10d_revision_booking),
  'ready',
  'ready'
);

-- 61
SELECT ok(
  (SELECT readiness_id FROM s10d_revision_signoff_v1) <>
    (SELECT id FROM s10d_revision_ready_current)
  AND
  (
    SELECT superseded_at IS NOT NULL
    FROM public.booking_safety_readiness
    WHERE id =
          (SELECT readiness_id FROM s10d_revision_signoff_v1)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs
    WHERE readiness_id =
          (SELECT id FROM s10d_revision_ready_current)
  ) = 0,
  'old sign-off remains on superseded readiness and does not migrate to current revision'
);

-- 62
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10d_revision_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: qualifying current Newborn formal sign-off required',
  'sign-off on superseded readiness cannot qualify current Newborn readiness'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10d_revision_signoff_current AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10d_revision_booking)
);

-- 63
SELECT ok(
  (SELECT readiness_id FROM s10d_revision_signoff_current) =
    (SELECT id FROM s10d_revision_ready_current)
  AND
  (SELECT readiness_id FROM s10d_revision_signoff_current) <>
    (SELECT readiness_id FROM s10d_revision_signoff_v1)
  AND
  (SELECT lead_assignment_id FROM s10d_revision_signoff_current) =
    (SELECT id FROM s10d_revision_lead),
  'current readiness receives distinct sign-off tied to same still-current Lead assignment'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 64
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10d_revision_booking)
  )
  $$,
  'current-readiness Photographer sign-off qualifies after readiness revision'
);

-- ---------------------------------------------------------------------
-- Part 10 — External Lead Photographer + administrative sign-off.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10d_external_booking AS
SELECT pg_temp.s10c_make_stage9_booking(
  'newborn_gold',
  '2030-06-07 10:00:00+05:30'::timestamptz,
  'ready',
  'ready',
  false
) AS id;

CREATE TEMP TABLE s10d_external_lead_identity AS
SELECT *
FROM public.create_external_creative(
  (SELECT id FROM s10d_external_booking),
  'S10D External Newborn Lead Photographer'
);

CREATE TEMP TABLE s10d_external_lead AS
SELECT *
FROM public.assign_booking_external_creative(
  (SELECT id FROM s10d_external_booking),
  'lead_photographer',
  (SELECT id FROM s10d_external_lead_identity),
  true,
  NULL
);

CREATE TEMP TABLE s10d_external_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10d_external_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

-- 65
SELECT ok(
  (
    SELECT
      assigned_member_id IS NULL
      AND assigned_external_creative_id =
        (SELECT id FROM s10d_external_lead_identity)
      AND ended_at IS NULL
    FROM public.booking_team_assignments
    WHERE id =
          (SELECT id FROM s10d_external_lead)
  ),
  'external creative may be the current Newborn Lead Photographer staffing subject'
);

-- 66
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10d_external_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: qualifying current Newborn formal sign-off required',
  'external Lead staffing cannot itself satisfy database Photographer formal sign-off'
);

-- Studio Manager signs administratively.
SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000006',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10d_manager_signoff AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10d_external_booking)
);

-- 67
SELECT ok(
  (
    SELECT
      signoff.signoff_authority =
        'studio_manager'
      AND signoff.signed_by =
        '8a000000-0000-0000-0000-000000000106'::uuid
      AND signoff.lead_assignment_id IS NULL
      AND signoff.readiness_id =
        (
          SELECT readiness.id
          FROM public.booking_safety_readiness readiness
          WHERE readiness.booking_id =
                (SELECT id FROM s10d_external_booking)
            AND readiness.superseded_at IS NULL
        )
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10d_manager_signoff)
  ),
  'Studio Manager administrative sign-off stores no Lead Photographer dependency'
);

-- Restore Founder before changing member lifecycle.
SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

UPDATE public.organization_members
SET
  status =
    'suspended'::public.member_status,
  suspended_at =
    now(),
  suspended_by =
    '8a000000-0000-0000-0000-000000000101'::uuid
WHERE id =
      '8a000000-0000-0000-0000-000000000106'::uuid;

-- 68
SELECT ok(
  (
    SELECT status =
           'suspended'::public.member_status
    FROM public.organization_members
    WHERE id =
          '8a000000-0000-0000-0000-000000000106'::uuid
  )
  AND
  EXISTS (
    SELECT 1
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10d_manager_signoff)
      AND signoff.signoff_authority =
          'studio_manager'
      AND signoff.lead_assignment_id IS NULL
  ),
  'administrative sign-off remains immutable after Studio Manager suspension'
);

-- 69
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10d_external_booking)
  )
  $$,
  'same-readiness Studio Manager sign-off remains qualifying after signer suspension'
);

-- 70
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10d_external_booking)
  ),
  'shoot_scheduled'::text,
  'external Lead Newborn booking reaches Stage 10 using persistent administrative sign-off'
);


-- =====================================================================
-- Tranche E — Authorization, isolation and integrity
--
-- Proves:
--   * malformed argument rejection remains fail-closed;
--   * latest non-reserved schedule blocks Stage 9 -> 10;
--   * corrupt Stage-10 replay history fails closed without repair;
--   * booking.stage.advance is mandatory;
--   * branch-scoped advancement is confined to the granted branch;
--   * foreign-organization authority never crosses tenancy;
--   * direct authenticated writes to transition/state/audit tables fail;
--   * required internal creative roles are revalidated live;
--   * authorization occurs before Stage-10 replay;
--   * optimistic journey-version / 40001 defense remains in function
--     source while runtime concurrency is validated separately.
-- =====================================================================

CREATE FUNCTION pg_temp.s10e_make_stage9_booking(
  p_family_id uuid,
  p_package_key text,
  p_scheduled_start_at timestamptz,
  p_safety_state text,
  p_comfort_state text,
  p_reserve boolean
)
RETURNS uuid
LANGUAGE plpgsql
AS $s10e$
DECLARE
  v_quote public.quotations;
  v_booking public.bookings;
  v_proposal public.booking_shoot_schedules;
  v_preparation public.booking_preparations;

  v_package_version_id uuid;
  v_branch_id uuid;
  v_item_id uuid;
BEGIN
  SELECT family.branch_id
  INTO v_branch_id
  FROM public.families family
  WHERE family.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND family.id =
        p_family_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      's10e fixture: family unavailable';
  END IF;

  SELECT version.id
  INTO v_package_version_id
  FROM public.commercial_package_versions version
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE package.package_key =
        p_package_key
    AND version.version_number = 1;

  IF v_package_version_id IS NULL THEN
    RAISE EXCEPTION
      's10e fixture: package version unavailable';
  END IF;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    p_family_id,
    NULL,
    v_branch_id,
    NULL,
    NULL
  );

  PERFORM public.add_quotation_package_line(
    v_quote.id,
    v_package_version_id,
    NULL
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'ready'::public.quotation_status
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'sent'::public.quotation_status
  );

  SELECT *
  INTO v_booking
  FROM public.accept_quotation(
    v_quote.id
  );

  SELECT *
  INTO v_proposal
  FROM public.propose_booking_shoot_schedule(
    v_booking.id,
    p_scheduled_start_at,
    p_scheduled_start_at + interval '2 hours',
    'Asia/Kolkata',
    'studio',
    'S10 Slice 6 Tranche E fixture'
  );

  IF p_reserve THEN
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
      v_proposal.organization_id,
      v_proposal.booking_id,
      v_proposal.schedule_version + 1,
      v_proposal.id,
      'reserved',
      v_proposal.scheduled_start_at,
      v_proposal.scheduled_end_at,
      v_proposal.timezone,
      v_proposal.location_type,
      v_proposal.location_details,
      NULL,
      '8a000000-0000-0000-0000-000000000101'::uuid
    );
  END IF;

  INSERT INTO public.booking_stage_transitions (
    organization_id,
    booking_id,
    from_stage_id,
    to_stage_id,
    transition_key,
    transitioned_at,
    transitioned_by
  )
  SELECT
    state.organization_id,
    state.booking_id,
    state.current_stage_id,
    target.id,
    's10_slice6_tranche_e_booking_confirmed',
    now(),
    '8a000000-0000-0000-0000-000000000101'::uuid
  FROM public.booking_journey_states state
  JOIN public.booking_journey_stages target
    ON target.organization_id =
       state.organization_id
   AND target.stage_key =
       'booking_confirmed'
   AND target.stage_order = 8
   AND target.is_active
  WHERE state.booking_id =
        v_booking.id;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      target.id,
    stage_entered_at =
      now(),
    version =
      state.version + 1,
    updated_at =
      now(),
    updated_by =
      '8a000000-0000-0000-0000-000000000101'::uuid
  FROM public.booking_journey_stages target
  WHERE state.booking_id =
        v_booking.id
    AND target.organization_id =
        state.organization_id
    AND target.stage_key =
        'booking_confirmed'
    AND target.stage_order = 8
    AND target.is_active;

  SELECT *
  INTO v_preparation
  FROM public.start_pre_shoot_preparation(
    v_booking.id
  );

  FOR v_item_id IN
    SELECT item.id
    FROM public.booking_preparation_items item
    WHERE item.organization_id =
          v_booking.organization_id
      AND item.preparation_id =
          v_preparation.id
      AND item.is_required
    ORDER BY
      item.sort_order,
      item.item_key
  LOOP
    PERFORM public.update_pre_shoot_preparation_item(
      v_item_id,
      true
    );
  END LOOP;

  PERFORM public.record_booking_safety_readiness(
    v_booking.id,
    p_safety_state,
    p_comfort_state
  );

  RETURN v_booking.id;
END
$s10e$;

-- ---------------------------------------------------------------------
-- Part 11 — Argument + authoritative schedule integrity.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 71
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(NULL)
  $$,
  '22023',
  'mark_booking_shoot_scheduled: booking_id is required',
  'NULL booking identifier is rejected before mutation'
);

CREATE TEMP TABLE s10e_schedule_booking AS
SELECT pg_temp.s10e_make_stage9_booking(
  '8a000000-0000-0000-0000-000000000201'::uuid,
  'maternity_gold',
  '2030-06-08 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  true
) AS id;

-- A real Stage 9 booking necessarily reached preparation with reserved
-- schedule evidence. The canonical schedule lifecycle then forbids a
-- reserved tip from returning to proposed.
--
-- To prove the Stage 9 -> 10 RPC independently fails closed against a
-- malformed latest non-reserved tip, inject that corruption only under
-- the pgTAP owner after legitimate Stage 9 construction. The lifecycle
-- guard is immediately restored before the public RPC is exercised.
ALTER TABLE public.booking_shoot_schedules
DISABLE TRIGGER USER;

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
SELECT
  schedule.organization_id,
  schedule.booking_id,
  schedule.schedule_version + 1,
  schedule.id,
  'proposed',
  schedule.scheduled_start_at,
  schedule.scheduled_end_at,
  schedule.timezone,
  schedule.location_type,
  schedule.location_details,
  NULL,
  '8a000000-0000-0000-0000-000000000101'::uuid
FROM public.booking_shoot_schedules schedule
WHERE schedule.booking_id =
      (SELECT id FROM s10e_schedule_booking)
ORDER BY schedule.schedule_version DESC
LIMIT 1;

ALTER TABLE public.booking_shoot_schedules
ENABLE TRIGGER USER;

CREATE TEMP TABLE s10e_schedule_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_schedule_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000105',
  true,
  NULL
);

CREATE TEMP TABLE s10e_schedule_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_schedule_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

-- 72
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_schedule_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: current authoritative reserved shoot schedule required',
  'latest proposed-only schedule blocks Stage 9 -> 10'
);

-- 73
SELECT ok(
  (
    SELECT stage.stage_key =
           'pre_shoot_preparation'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10e_schedule_booking)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10e_schedule_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) = 0
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10e_schedule_booking)
  ) = 0,
  'schedule failure leaves journey, transition and audit evidence unchanged'
);

-- ---------------------------------------------------------------------
-- Part 12 — Stage-10 replay requires exact historical provenance.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10e_corrupt_booking AS
SELECT pg_temp.s10e_make_stage9_booking(
  '8a000000-0000-0000-0000-000000000201'::uuid,
  'maternity_gold',
  '2030-06-09 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  true
) AS id;

CREATE TEMP TABLE s10e_corrupt_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_corrupt_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000105',
  true,
  NULL
);

CREATE TEMP TABLE s10e_corrupt_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_corrupt_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10e_corrupt_stage10',
  now(),
  '8a000000-0000-0000-0000-000000000101'::uuid
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'shoot_scheduled'
 AND target.stage_order = 10
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10e_corrupt_booking);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_at =
    now(),
  updated_by =
    '8a000000-0000-0000-0000-000000000101'::uuid
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10e_corrupt_booking)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'shoot_scheduled'
  AND target.stage_order = 10
  AND target.is_active;

CREATE TEMP TABLE s10e_corrupt_before AS
SELECT
  state.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) AS shoot_transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          state.booking_id
  ) AS shoot_audit_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10e_corrupt_booking);

-- 74
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_corrupt_booking)
  )
  $$,
  'P0001',
  'mark_booking_shoot_scheduled: Shoot Scheduled replay history is invalid',
  'Stage-10 state without exact shoot_scheduled provenance fails integrity replay'
);

-- 75
SELECT ok(
  (
    SELECT state.version =
           before.version
    FROM public.booking_journey_states state
    CROSS JOIN s10e_corrupt_before before
    WHERE state.booking_id =
          (SELECT id FROM s10e_corrupt_booking)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10e_corrupt_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) =
  (
    SELECT shoot_transition_count
    FROM s10e_corrupt_before
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10e_corrupt_booking)
  ) =
  (
    SELECT shoot_audit_count
    FROM s10e_corrupt_before
  ),
  'invalid replay fails closed without repairing or appending evidence'
);

-- ---------------------------------------------------------------------
-- Part 13 — Authorization / branch / tenant isolation.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES
  ('8a000000-0000-0000-0000-000000000007'::uuid),
  ('8a000000-0000-0000-0000-000000000008'::uuid),
  ('8a000000-0000-0000-0000-000000000009'::uuid),
  ('8a000000-0000-0000-0000-000000000010'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '8a000000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000007',
  'active',
  'S10 Slice 6 Branch Coordinator'
),
(
  '8a000000-0000-0000-0000-000000000108',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000008',
  'active',
  'S10 Slice 6 Branch Photographer'
),
(
  '8a000000-0000-0000-0000-000000000109',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000009',
  'active',
  'S10 Slice 6 Branch Stylist'
);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  country_code,
  created_by,
  updated_by
)
VALUES (
  '8a000000-0000-0000-0000-000000000301',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 Slice 6 Branch A',
  's10e',
  'active',
  'IN',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role.id,
  '8a000000-0000-0000-0000-000000000301'::uuid
FROM (
  VALUES
    (
      '8a000000-0000-0000-0000-000000000107'::uuid,
      'client_coordinator'::text
    ),
    (
      '8a000000-0000-0000-0000-000000000108'::uuid,
      'photographer'
    ),
    (
      '8a000000-0000-0000-0000-000000000109'::uuid,
      'stylist'
    )
) AS fixture(member_id, role_key)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

INSERT INTO public.families (
  id,
  organization_id,
  branch_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES (
  '8a000000-0000-0000-0000-000000000202',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8a000000-0000-0000-0000-000000000301',
  'LSH-23456B',
  'S10 Slice 6 Branch Family',
  'Slice 6 Branch Family',
  'active',
  '8a000000-0000-0000-0000-000000000101',
  '8a000000-0000-0000-0000-000000000101'
);

CREATE TEMP TABLE s10e_auth_booking AS
SELECT pg_temp.s10e_make_stage9_booking(
  '8a000000-0000-0000-0000-000000000201'::uuid,
  'maternity_gold',
  '2030-06-10 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  true
) AS id;

CREATE TEMP TABLE s10e_auth_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_auth_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000105',
  true,
  NULL
);

CREATE TEMP TABLE s10e_auth_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_auth_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

CREATE TEMP TABLE s10e_auth_before AS
SELECT
  state.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) AS shoot_transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          state.booking_id
  ) AS shoot_audit_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10e_auth_booking);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 76
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_auth_booking)
  )
  $$,
  '42501',
  'mark_booking_shoot_scheduled: booking.stage.advance permission required',
  'Photographer cannot substitute booking.read or safety permissions for booking.stage.advance'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

-- 77
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_auth_booking)
  )
  $$,
  '42501',
  'mark_booking_shoot_scheduled: booking.stage.advance permission required',
  'Branch-301 Coordinator cannot advance a Coimbatore booking outside its granted scope'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.organizations (
  id,
  display_name,
  slug,
  status,
  currency_code,
  timezone,
  brand_prefix
)
VALUES (
  '8a000000-0000-0000-0000-000000000401',
  'S10 Slice 6 Foreign Studio',
  's10-slice6-foreign-studio',
  'suspended',
  'INR',
  'Asia/Kolkata',
  'S10E'
);

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '8a000000-0000-0000-0000-000000000401'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '8a000000-0000-0000-0000-000000000110',
  '8a000000-0000-0000-0000-000000000401',
  '8a000000-0000-0000-0000-000000000010',
  'active',
  'S10 Slice 6 Foreign Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '8a000000-0000-0000-0000-000000000401'::uuid,
  '8a000000-0000-0000-0000-000000000110'::uuid,
  role.id,
  NULL::uuid
FROM public.roles role
WHERE role.key =
      'founder';

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '8a000000-0000-0000-0000-000000000401'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000010',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000010","role":"authenticated"}',
  true
);

-- 78
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_auth_booking)
  )
  $$,
  '42501',
  'mark_booking_shoot_scheduled: active organization membership required',
  'foreign-organization Founder cannot advance canonical organization booking'
);

-- 79
SELECT ok(
  (
    SELECT state.version =
           before.version
    FROM public.booking_journey_states state
    CROSS JOIN s10e_auth_before before
    WHERE state.booking_id =
          (SELECT id FROM s10e_auth_booking)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10e_auth_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) =
  (
    SELECT shoot_transition_count
    FROM s10e_auth_before
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10e_auth_booking)
  ) =
  (
    SELECT shoot_audit_count
    FROM s10e_auth_before
  ),
  'permission, branch and foreign-tenant denials leave all advancement evidence unchanged'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10e_branch_booking AS
SELECT pg_temp.s10e_make_stage9_booking(
  '8a000000-0000-0000-0000-000000000202'::uuid,
  'maternity_gold',
  '2030-06-11 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  true
) AS id;

CREATE TEMP TABLE s10e_branch_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_branch_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000108',
  true,
  NULL
);

CREATE TEMP TABLE s10e_branch_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_branch_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000109',
  true,
  NULL
);

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

-- 80
SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'booking.stage.advance',
    '8a000000-0000-0000-0000-000000000301'
  )
  AND
  public.has_branch_scope(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8a000000-0000-0000-0000-000000000301'
  )
  AND NOT
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'booking.stage.advance',
    NULL
  ),
  'branch Coordinator has Stage-advance authority only inside the granted active branch'
);

-- 81
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_branch_booking)
  )
  $$,
  'branch-scoped Coordinator may advance a fully ready booking in the granted branch'
);

-- 82
SELECT ok(
  (
    SELECT stage.stage_key =
           'shoot_scheduled'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10e_branch_booking)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10e_branch_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10e_branch_booking)
  ) = 1,
  'authorized branch advancement reaches Stage 10 with exactly one transition and audit'
);

SET LOCAL ROLE authenticated;

-- 83
SELECT throws_ok(
  $$
  INSERT INTO public.booking_stage_transitions
  DEFAULT VALUES
  $$,
  '42501',
  'permission denied for table booking_stage_transitions',
  'authenticated cannot directly INSERT booking transition evidence'
);

-- 84
SELECT throws_ok(
  $$
  UPDATE public.booking_journey_states
  SET updated_at = now()
  WHERE false
  $$,
  '42501',
  'permission denied for table booking_journey_states',
  'authenticated cannot directly UPDATE journey state'
);

-- 85
SELECT throws_ok(
  $$
  INSERT INTO public.audit_events
  DEFAULT VALUES
  $$,
  '42501',
  'permission denied for table audit_events',
  'authenticated cannot directly INSERT shoot-scheduled audit evidence'
);

RESET ROLE;

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10e_lead_revalidation_booking AS
SELECT pg_temp.s10e_make_stage9_booking(
  '8a000000-0000-0000-0000-000000000201'::uuid,
  'maternity_gold',
  '2030-06-12 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  true
) AS id;

CREATE TEMP TABLE s10e_lead_revalidation_assignment AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_lead_revalidation_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000102',
  true,
  NULL
);

CREATE TEMP TABLE s10e_lead_revalidation_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_lead_revalidation_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

UPDATE public.member_role_grants grant_row
SET
  revoked_at =
    now(),
  revoked_by =
    '8a000000-0000-0000-0000-000000000101'::uuid,
  revocation_reason =
    'S10 Slice 6 Lead Photographer revalidation test'
FROM public.roles role
WHERE grant_row.role_id =
      role.id
  AND grant_row.organization_member_id =
      '8a000000-0000-0000-0000-000000000102'::uuid
  AND grant_row.revoked_at IS NULL
  AND role.key =
      'photographer';

-- 86
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_lead_revalidation_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: current Lead Photographer is not operationally eligible',
  'current Lead Photographer loses eligibility when live Photographer role is revoked'
);

CREATE TEMP TABLE s10e_video_revalidation_booking AS
SELECT pg_temp.s10e_make_stage9_booking(
  '8a000000-0000-0000-0000-000000000201'::uuid,
  'maternity_diamond',
  '2030-06-13 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  true
) AS id;

CREATE TEMP TABLE s10e_video_revalidation_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_video_revalidation_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000105',
  true,
  NULL
);

CREATE TEMP TABLE s10e_video_revalidation_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_video_revalidation_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

CREATE TEMP TABLE s10e_video_revalidation_video AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_video_revalidation_booking),
  'lead_videographer',
  '8a000000-0000-0000-0000-000000000104',
  true,
  NULL
);

UPDATE public.member_role_grants grant_row
SET
  revoked_at =
    now(),
  revoked_by =
    '8a000000-0000-0000-0000-000000000101'::uuid,
  revocation_reason =
    'S10 Slice 6 Lead Videographer revalidation test'
FROM public.roles role
WHERE grant_row.role_id =
      role.id
  AND grant_row.organization_member_id =
      '8a000000-0000-0000-0000-000000000104'::uuid
  AND grant_row.revoked_at IS NULL
  AND role.key =
      'videographer';

-- 87
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_video_revalidation_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: client Video/Reels requires a current operationally eligible Lead Videographer',
  'structured Video booking revalidates live internal Videographer role at advancement'
);

CREATE TEMP TABLE s10e_stylist_revalidation_booking AS
SELECT pg_temp.s10e_make_stage9_booking(
  '8a000000-0000-0000-0000-000000000201'::uuid,
  'maternity_gold',
  '2030-06-14 10:00:00+05:30'::timestamptz,
  'not_applicable',
  'ready',
  true
) AS id;

CREATE TEMP TABLE s10e_stylist_revalidation_lead AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_stylist_revalidation_booking),
  'lead_photographer',
  '8a000000-0000-0000-0000-000000000105',
  true,
  NULL
);

CREATE TEMP TABLE s10e_stylist_revalidation_stylist AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10e_stylist_revalidation_booking),
  'stylist',
  '8a000000-0000-0000-0000-000000000103',
  true,
  NULL
);

UPDATE public.member_role_grants grant_row
SET
  revoked_at =
    now(),
  revoked_by =
    '8a000000-0000-0000-0000-000000000101'::uuid,
  revocation_reason =
    'S10 Slice 6 Stylist revalidation test'
FROM public.roles role
WHERE grant_row.role_id =
      role.id
  AND grant_row.organization_member_id =
      '8a000000-0000-0000-0000-000000000103'::uuid
  AND grant_row.revoked_at IS NULL
  AND role.key =
      'stylist';

-- 88
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_stylist_revalidation_booking)
  )
  $$,
  '22023',
  'mark_booking_shoot_scheduled: current Stylist assignment required and must be operationally eligible',
  'current internal Stylist is revalidated against a live Stylist role'
);

-- 89
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id IN (
      (SELECT id FROM s10e_lead_revalidation_booking),
      (SELECT id FROM s10e_video_revalidation_booking),
      (SELECT id FROM s10e_stylist_revalidation_booking)
    )
      AND stage.stage_key =
          'pre_shoot_preparation'
  ),
  3::bigint,
  'all live-role revalidation failures leave their bookings exactly at Stage 9'
);

DELETE FROM public.role_permissions mapping
USING public.roles role,
      public.permissions permission
WHERE mapping.role_id =
      role.id
  AND mapping.permission_id =
      permission.id
  AND role.key =
      'client_coordinator'
  AND permission.key =
      'booking.stage.advance';

SELECT set_config(
  'request.jwt.claim.sub',
  '8a000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8a000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

-- 90
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_scheduled(
    (SELECT id FROM s10e_branch_booking)
  )
  $$,
  '42501',
  'mark_booking_shoot_scheduled: booking.stage.advance permission required',
  'revoked booking.stage.advance prevents even otherwise-idempotent Stage-10 replay'
);

-- 91
SELECT ok(
  (
    SELECT stage.stage_key =
           'shoot_scheduled'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10e_branch_booking)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT id FROM s10e_branch_booking)
      AND transition_row.transition_key =
          'shoot_scheduled'
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_scheduled'
      AND audit.entity_id =
          (SELECT id FROM s10e_branch_booking)
  ) = 1,
  'authorization-before-replay denial leaves the existing Stage-10 transition and audit singular'
);

-- 92
SELECT ok(
  pg_get_functiondef(
    'public.mark_booking_shoot_scheduled(uuid)'::regprocedure
  ) ~
    'state[.]version[[:space:]]*=[[:space:]]*v_state[.]version'
  AND
  pg_get_functiondef(
    'public.mark_booking_shoot_scheduled(uuid)'::regprocedure
  ) ~
    'ERRCODE[[:space:]]*=[[:space:]]*''40001'''
  AND
  pg_get_functiondef(
    'public.mark_booking_shoot_scheduled(uuid)'::regprocedure
  ) LIKE
    '%FOR UPDATE%',
  'Stage 9 -> 10 retains row locking, old-version predicate and explicit 40001 defense'
);

SELECT * FROM finish();

ROLLBACK;
