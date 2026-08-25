CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(52);

-- =====================================================================
-- Sprint 11 Slice 2
-- Controlled Stage 10 -> 11 / shoot_completed Advancement Gate
--
-- Direct pgTAP assertions cover frozen matrix A through AX.
-- AY — complete local regression — is the separate repository-wide
-- execution gate after this dedicated suite is green.
-- =====================================================================

-- =====================================================================
-- Part 1 — Structural / permission / ACL contract
-- =====================================================================

-- A
SELECT ok(
  to_regprocedure(
    'public.mark_booking_shoot_completed(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
  ) = 'bookings',
  'A: mark_booking_shoot_completed(uuid) exists and returns bookings'
);

-- B
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key IN (
      'shoot.completed',
      'shoot.advance',
      'booking.shoot.completed'
    )
  ),
  0::bigint,
  'B: Slice 2 introduces no new stage-specific permission'
);

-- C
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  241::bigint,
  'C: canonical repository-wide role-permission mapping is 241'
);

-- D
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_shoot_completed(uuid)',
    'EXECUTE'
  ),
  'D: authenticated has EXECUTE on Stage 10 -> 11 RPC'
);

-- E
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault('f', procedure.proowner)
      )
    ) acl
    WHERE procedure.oid =
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'E: PUBLIC has no EXECUTE on Stage 10 -> 11 RPC'
);

-- F
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.mark_booking_shoot_completed(uuid)',
    'EXECUTE'
  ),
  'F: anon has no EXECUTE on Stage 10 -> 11 RPC'
);

-- G
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.mark_booking_shoot_completed(uuid)',
    'EXECUTE'
  ),
  'G: service_role has no application EXECUTE on Stage 10 -> 11 RPC'
);

-- H
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
  ),
  'H: Stage 10 -> 11 RPC is SECURITY DEFINER'
);

-- I
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'I: Stage 10 -> 11 RPC has empty search_path'
);

-- =====================================================================
-- Part 2 — Canonical fixture identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8c000000-0000-0000-0000-000000000001'::uuid),
  ('8c000000-0000-0000-0000-000000000002'::uuid),
  ('8c000000-0000-0000-0000-000000000003'::uuid),
  ('8c000000-0000-0000-0000-000000000004'::uuid),
  ('8c000000-0000-0000-0000-000000000005'::uuid),
  ('8c000000-0000-0000-0000-000000000006'::uuid),
  ('8c000000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  '8c000000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice2 Branch A',
  's11s2-a',
  'active'
),
(
  '8c000000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice2 Branch B',
  's11s2-b',
  'active'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  suspended_at
)
VALUES
(
  '8c000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8c000000-0000-0000-0000-000000000001',
  'active',
  'S11S2 Founder',
  NULL
),
(
  '8c000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8c000000-0000-0000-0000-000000000002',
  'active',
  'S11S2 Studio Manager',
  NULL
),
(
  '8c000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8c000000-0000-0000-0000-000000000003',
  'active',
  'S11S2 Photographer',
  NULL
),
(
  '8c000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8c000000-0000-0000-0000-000000000004',
  'active',
  'S11S2 Coordinator',
  NULL
),
(
  '8c000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8c000000-0000-0000-0000-000000000005',
  'suspended',
  'S11S2 Suspended Founder',
  now()
),
(
  '8c000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8c000000-0000-0000-0000-000000000006',
  'active',
  'S11S2 Branch Coordinator',
  NULL
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
      '8c000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8c000000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      '8c000000-0000-0000-0000-000000000103'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      '8c000000-0000-0000-0000-000000000104'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      '8c000000-0000-0000-0000-000000000105'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8c000000-0000-0000-0000-000000000106'::uuid,
      'client_coordinator'::text,
      '8c000000-0000-0000-0000-000000000701'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s2_set_actor(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claim.sub',
    COALESCE(p_user_id::text, ''),
    true
  );

  PERFORM set_config(
    'request.jwt.claims',
    CASE
      WHEN p_user_id IS NULL THEN '{}'
      ELSE jsonb_build_object(
        'sub',
        p_user_id,
        'role',
        'authenticated'
      )::text
    END,
    true
  );
END;
$$;

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000001'
);

INSERT INTO public.families (
  id,
  organization_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES (
  '8c000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-34567C',
  'S11 Slice2 Family',
  'S11 Slice2 Family',
  'active',
  '8c000000-0000-0000-0000-000000000101',
  '8c000000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s11s2_create_booking(
  p_branch_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote public.quotations;
  v_booking public.bookings;
  v_package_version_id uuid;
BEGIN
  SELECT version.id
  INTO v_package_version_id
  FROM public.commercial_package_versions version
  JOIN public.commercial_packages package
    ON package.organization_id = version.organization_id
   AND package.id = version.package_id
  WHERE package.package_key = 'maternity_gold'
    AND version.version_number = 1;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8c000000-0000-0000-0000-000000000201',
    NULL,
    p_branch_id,
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
  FROM public.accept_quotation(v_quote.id);

  RETURN v_booking.id;
END;
$$;

CREATE FUNCTION pg_temp.s11s2_reserve_schedule(
  p_booking_id uuid,
  p_day_offset integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_proposed public.booking_shoot_schedules;
  v_start timestamptz;
BEGIN
  v_start :=
    '2030-08-01 10:00:00+05:30'::timestamptz
    + make_interval(days => p_day_offset);

  SELECT *
  INTO v_proposed
  FROM public.propose_booking_shoot_schedule(
    p_booking_id,
    v_start,
    v_start + interval '2 hours',
    'Asia/Kolkata',
    'studio',
    'Sprint 11 Slice 2 fixture'
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
    v_proposed.organization_id,
    v_proposed.booking_id,
    v_proposed.schedule_version + 1,
    v_proposed.id,
    'reserved',
    v_proposed.scheduled_start_at,
    v_proposed.scheduled_end_at,
    v_proposed.timezone,
    v_proposed.location_type,
    v_proposed.location_details,
    NULL,
    '8c000000-0000-0000-0000-000000000101'
  );
END;
$$;

CREATE FUNCTION pg_temp.s11s2_move_to_stage(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_transition_key text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
    AND stage.is_active;

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
    v_state.organization_id,
    v_state.booking_id,
    v_state.current_stage_id,
    v_target.id,
    COALESCE(
      p_transition_key,
      's11s2_fixture_' || p_stage_key
    ),
    now(),
    '8c000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = now(),
    version = state.version + 1,
    updated_at = now(),
    updated_by =
      '8c000000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s2_set_stage_without_transition(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
    AND stage.is_active;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = now(),
    version = state.version + 1,
    updated_at = now(),
    updated_by =
      '8c000000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s2_fixture_completion(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.booking_shoot_completions (
    organization_id,
    booking_id,
    completed_at,
    recorded_by
  )
  SELECT
    booking.organization_id,
    booking.id,
    now() - interval '1 hour',
    '8c000000-0000-0000-0000-000000000101'
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;
END;
$$;

CREATE TEMP TABLE s11s2_ids (
  happy_booking_id uuid,
  founder_booking_id uuid,
  manager_booking_id uuid,
  terminal_booking_id uuid,
  no_completion_booking_id uuid,
  missing_schedule_booking_id uuid,
  stage9_booking_id uuid,
  stage12_booking_id uuid,
  zero_state_booking_id uuid,
  cross_branch_booking_id uuid,
  replay_missing_transition_id uuid,
  replay_malformed_transition_id uuid,
  replay_missing_completion_id uuid
);

INSERT INTO s11s2_ids
VALUES (
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(
    '8c000000-0000-0000-0000-000000000702'
  ),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL),
  pg_temp.s11s2_create_booking(NULL)
);

-- Reserve all schedules that are expected to have authoritative evidence.
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT happy_booking_id FROM s11s2_ids), 1
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT founder_booking_id FROM s11s2_ids), 2
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT manager_booking_id FROM s11s2_ids), 3
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT terminal_booking_id FROM s11s2_ids), 4
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT no_completion_booking_id FROM s11s2_ids), 5
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT cross_branch_booking_id FROM s11s2_ids), 6
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT replay_missing_transition_id FROM s11s2_ids), 7
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT replay_malformed_transition_id FROM s11s2_ids), 8
);
SELECT pg_temp.s11s2_reserve_schedule(
  (SELECT replay_missing_completion_id FROM s11s2_ids), 9
);

-- Exact source-stage fixtures.
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT happy_booking_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT founder_booking_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT manager_booking_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT terminal_booking_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT no_completion_booking_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT missing_schedule_booking_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT stage9_booking_id FROM s11s2_ids),
  9,
  'pre_shoot_preparation'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT stage12_booking_id FROM s11s2_ids),
  12,
  'selection_pending'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT cross_branch_booking_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);

-- Completion exists but schedule does not.
SELECT pg_temp.s11s2_fixture_completion(
  (SELECT missing_schedule_booking_id FROM s11s2_ids)
);

-- Replay: completion exists, but no Stage 10 -> 11 transition exists.
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT replay_missing_transition_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_fixture_completion(
  (SELECT replay_missing_transition_id FROM s11s2_ids)
);
SELECT pg_temp.s11s2_set_stage_without_transition(
  (SELECT replay_missing_transition_id FROM s11s2_ids),
  11,
  'shoot_completed'
);

-- Replay: completion exists, but transition history is malformed.
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT replay_malformed_transition_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_fixture_completion(
  (SELECT replay_malformed_transition_id FROM s11s2_ids)
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT replay_malformed_transition_id FROM s11s2_ids),
  11,
  'shoot_completed',
  's11s2_malformed_completed_history'
);

-- Replay: exact Stage 10 -> 11 transition exists but completion is absent.
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT replay_missing_completion_id FROM s11s2_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s2_move_to_stage(
  (SELECT replay_missing_completion_id FROM s11s2_ids),
  11,
  'shoot_completed',
  'shoot_completed'
);

-- Corrupt one fixture to zero journey states.
ALTER TABLE public.booking_journey_states
DISABLE TRIGGER USER;

DELETE FROM public.booking_journey_states
WHERE booking_id =
  (SELECT zero_state_booking_id FROM s11s2_ids);

ALTER TABLE public.booking_journey_states
ENABLE TRIGGER USER;

-- =====================================================================
-- Part 3 — Input / actor / stage rejection
-- =====================================================================

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000001'
);

-- J
SELECT throws_ok(
  $$ SELECT public.mark_booking_shoot_completed(NULL) $$,
  '22023',
  'mark_booking_shoot_completed: booking_id is required',
  'J: null booking id is rejected'
);

SELECT pg_temp.s11s2_set_actor(NULL);

-- K
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT happy_booking_id FROM s11s2_ids)
  )
  $$,
  '42501',
  'mark_booking_shoot_completed: authenticated actor required',
  'K: unauthenticated invocation is rejected'
);

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000001'
);

-- L
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    '8cffffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'mark_booking_shoot_completed: booking not found',
  'L: missing booking is rejected'
);

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000005'
);

-- M
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT happy_booking_id FROM s11s2_ids)
  )
  $$,
  '42501',
  'mark_booking_shoot_completed: active organization membership required',
  'M: inactive member is rejected'
);

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000003'
);

-- N
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT happy_booking_id FROM s11s2_ids)
  )
  $$,
  '42501',
  'mark_booking_shoot_completed: booking.stage.advance permission required',
  'N: Photographer cannot advance solely from shoot.complete'
);

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000006'
);

-- O
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT cross_branch_booking_id FROM s11s2_ids)
  )
  $$,
  '42501',
  'mark_booking_shoot_completed: booking.stage.advance permission required',
  'O: branch-scoped Coordinator cannot advance a different branch'
);

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000001'
);

-- P
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT zero_state_booking_id FROM s11s2_ids)
  )
  $$,
  'P0001',
  'mark_booking_shoot_completed: booking must have exactly one current journey state',
  'P: zero current journey states is rejected'
);

-- Q
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
      'public.booking_journey_states'::regclass
      AND constraint_row.contype = 'p'
      AND pg_get_constraintdef(constraint_row.oid)
          LIKE 'PRIMARY KEY (booking_id)%'
  ),
  'Q: journey-state schema structurally prevents multiple rows per booking'
);

-- R
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT stage9_booking_id FROM s11s2_ids)
  )
  $$,
  '22023',
  'mark_booking_shoot_completed: booking must be exactly Shoot Scheduled',
  'R: Stage 9 first-call source is rejected'
);

-- S
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT stage12_booking_id FROM s11s2_ids)
  )
  $$,
  '22023',
  'mark_booking_shoot_completed: booking must be exactly Shoot Scheduled',
  'S: Stage 12 first-call source is rejected'
);

-- T
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT no_completion_booking_id FROM s11s2_ids)
  )
  $$,
  '22023',
  'mark_booking_shoot_completed: exactly one canonical shoot completion row required',
  'T: exact Stage 10 without completion evidence is rejected'
);

-- U
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT missing_schedule_booking_id FROM s11s2_ids)
  )
  $$,
  '22023',
  'mark_booking_shoot_completed: current authoritative reserved shoot schedule required',
  'U: completion evidence without authoritative reserved schedule is rejected'
);

-- =====================================================================
-- Part 4 — Scheduling terminality
-- =====================================================================

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000004'
);

CREATE TEMP TABLE s11s2_terminal_initial AS
SELECT schedule.*
FROM public.booking_shoot_schedules schedule
WHERE schedule.booking_id =
  (SELECT terminal_booking_id FROM s11s2_ids)
ORDER BY schedule.schedule_version DESC
LIMIT 1;

-- AT
SELECT lives_ok(
  $$
  SELECT public.reschedule_booking_shoot(
    (SELECT terminal_booking_id FROM s11s2_ids),
    (SELECT scheduled_start_at + interval '1 day'
     FROM s11s2_terminal_initial),
    (SELECT scheduled_end_at + interval '1 day'
     FROM s11s2_terminal_initial),
    'Asia/Kolkata',
    'studio',
    'Sprint 11 Slice 2 terminality fixture',
    'pre-completion adjustment'
  )
  $$,
  'AT: Stage 10 rescheduling remains available before completion exists'
);

CREATE TEMP TABLE s11s2_terminal_latest AS
SELECT schedule.*
FROM public.booking_shoot_schedules schedule
WHERE schedule.booking_id =
  (SELECT terminal_booking_id FROM s11s2_ids)
ORDER BY schedule.schedule_version DESC
LIMIT 1;

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000003'
);

-- V
SELECT lives_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT terminal_booking_id FROM s11s2_ids),
    now() - interval '30 minutes'
  )
  $$,
  'V: Photographer can record canonical completion evidence'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_completions completion
    WHERE completion.booking_id =
      (SELECT terminal_booking_id FROM s11s2_ids)
  ),
  1::bigint,
  'V: Photographer recording creates exactly one canonical completion row'
);

CREATE TEMP TABLE s11s2_terminal_schedule_snapshot AS
SELECT
  count(*)::bigint AS schedule_count,
  jsonb_agg(
    to_jsonb(schedule)
    ORDER BY schedule.schedule_version
  ) AS schedule_history
FROM public.booking_shoot_schedules schedule
WHERE schedule.booking_id =
  (SELECT terminal_booking_id FROM s11s2_ids);

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000004'
);

-- AR
SELECT throws_ok(
  $$
  SELECT public.reschedule_booking_shoot(
    (SELECT terminal_booking_id FROM s11s2_ids),
    (SELECT scheduled_start_at + interval '1 day'
     FROM s11s2_terminal_latest),
    (SELECT scheduled_end_at + interval '1 day'
     FROM s11s2_terminal_latest),
    'Asia/Kolkata',
    'studio',
    'Sprint 11 Slice 2 terminality fixture',
    'post-completion change must fail'
  )
  $$,
  '22023',
  'booking shoot schedule cannot change after canonical shoot completion evidence exists',
  'AR: no new schedule row may be appended after completion evidence'
);

-- AS
SELECT is(
  (
    SELECT jsonb_agg(
      to_jsonb(schedule)
      ORDER BY schedule.schedule_version
    )
    FROM public.booking_shoot_schedules schedule
    WHERE schedule.booking_id =
      (SELECT terminal_booking_id FROM s11s2_ids)
  ),
  (
    SELECT schedule_history
    FROM s11s2_terminal_schedule_snapshot
  ),
  'AS: terminalization does not rewrite historical schedule evidence'
);

-- AU
SELECT lives_ok(
  $$
  SELECT public.reschedule_booking_shoot(
    (SELECT terminal_booking_id FROM s11s2_ids),
    (SELECT scheduled_start_at FROM s11s2_terminal_latest),
    (SELECT scheduled_end_at FROM s11s2_terminal_latest),
    (SELECT timezone FROM s11s2_terminal_latest),
    (SELECT location_type FROM s11s2_terminal_latest),
    (SELECT reschedule_reason FROM s11s2_terminal_latest),
    (SELECT location_details FROM s11s2_terminal_latest)
  )
  $$,
  'AU: exact existing schedule replay remains valid after completion'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules schedule
    WHERE schedule.booking_id =
      (SELECT terminal_booking_id FROM s11s2_ids)
  ),
  (
    SELECT schedule_count
    FROM s11s2_terminal_schedule_snapshot
  ),
  'AU: exact schedule replay creates no post-completion schedule row'
);

-- =====================================================================
-- Part 5 — Separation of duties + successful advancement
-- =====================================================================

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000003'
);

SELECT public.record_booking_shoot_completion(
  (SELECT happy_booking_id FROM s11s2_ids),
  now() - interval '45 minutes'
);

CREATE TEMP TABLE s11s2_happy_before_advance AS
SELECT
  state.version AS journey_version,
  to_jsonb(completion) AS completion_row,
  (
    SELECT jsonb_agg(
      to_jsonb(schedule)
      ORDER BY schedule.schedule_version
    )
    FROM public.booking_shoot_schedules schedule
    WHERE schedule.booking_id = state.booking_id
  ) AS schedule_history
FROM public.booking_journey_states state
JOIN public.booking_shoot_completions completion
  ON completion.organization_id = state.organization_id
 AND completion.booking_id = state.booking_id
WHERE state.booking_id =
  (SELECT happy_booking_id FROM s11s2_ids);

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000004'
);

-- W
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT happy_booking_id FROM s11s2_ids)
  )
  $$,
  'W: Client Coordinator advances valid completion without shoot.complete'
);

-- Founder fixture.
SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000001'
);

SELECT public.record_booking_shoot_completion(
  (SELECT founder_booking_id FROM s11s2_ids),
  now() - interval '40 minutes'
);

-- X
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT founder_booking_id FROM s11s2_ids)
  )
  $$,
  'X: Founder valid Stage 10 -> 11 advancement succeeds'
);

-- Studio Manager fixture.
SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000002'
);

SELECT public.record_booking_shoot_completion(
  (SELECT manager_booking_id FROM s11s2_ids),
  now() - interval '35 minutes'
);

-- Y
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT manager_booking_id FROM s11s2_ids)
  )
  $$,
  'Y: Studio Manager valid Stage 10 -> 11 advancement succeeds'
);

-- =====================================================================
-- Part 6 — Exact successful mutation contract
-- =====================================================================

-- Z
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
  ),
  'shoot_completed'::text,
  'Z: successful advancement resolves exact Stage 11 shoot_completed'
);

-- AA
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND transition_row.transition_key =
        'shoot_completed'
  ),
  1::bigint,
  'AA: success appends exactly one shoot_completed transition'
);

-- AB
SELECT is(
  (
    SELECT source_stage.stage_key
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id =
         transition_row.organization_id
     AND source_stage.id =
         transition_row.from_stage_id
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND transition_row.transition_key =
        'shoot_completed'
  ),
  'shoot_scheduled'::text,
  'AB: transition source is exact Stage 10 shoot_scheduled'
);

-- AC
SELECT is(
  (
    SELECT destination_stage.stage_key
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id =
         transition_row.organization_id
     AND destination_stage.id =
         transition_row.to_stage_id
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND transition_row.transition_key =
        'shoot_completed'
  ),
  'shoot_completed'::text,
  'AC: transition destination is exact Stage 11 shoot_completed'
);

-- AD
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
  ),
  (
    SELECT journey_version + 1
    FROM s11s2_happy_before_advance
  ),
  'AD: journey version increments exactly once'
);

-- AE
SELECT is(
  (
    SELECT state.stage_entered_at
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
  ),
  (
    SELECT transition_row.transitioned_at
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND transition_row.transition_key =
        'shoot_completed'
  ),
  'AE: stage_entered_at equals transition timestamp'
);

-- AF
SELECT ok(
  (
    SELECT
      transition_row.transitioned_by =
        '8c000000-0000-0000-0000-000000000104'::uuid
      AND state.updated_by =
        '8c000000-0000-0000-0000-000000000104'::uuid
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_states state
      ON state.organization_id =
         transition_row.organization_id
     AND state.booking_id =
         transition_row.booking_id
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND transition_row.transition_key =
        'shoot_completed'
  ),
  'AF: transition and journey update use canonical advancing actor'
);

-- AG
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
      'booking.shoot_completed'
      AND audit.entity_id =
        (SELECT happy_booking_id FROM s11s2_ids)
  ),
  1::bigint,
  'AG: first success appends exactly one booking.shoot_completed audit'
);

-- AH
SELECT ok(
  (
    SELECT
      NOT (
        COALESCE(audit.metadata, '{}'::jsonb)
        ?| ARRAY[
          'safety_state',
          'comfort_state',
          'readiness_id',
          'medical_note',
          'family_note',
          'incident_note',
          'selection',
          'editing'
        ]
      )
      AND NOT (
        COALESCE(audit.old_values, '{}'::jsonb)
        ?| ARRAY[
          'safety_state',
          'comfort_state',
          'readiness_id',
          'medical_note',
          'family_note',
          'incident_note'
        ]
      )
      AND NOT (
        COALESCE(audit.new_values, '{}'::jsonb)
        ?| ARRAY[
          'safety_state',
          'comfort_state',
          'readiness_id',
          'medical_note',
          'family_note',
          'incident_note'
        ]
      )
    FROM public.audit_events audit
    WHERE audit.action_key =
      'booking.shoot_completed'
      AND audit.entity_id =
        (SELECT happy_booking_id FROM s11s2_ids)
  ),
  'AH: shoot-completed audit remains structural and non-sensitive'
);

-- AI
SELECT is(
  (
    SELECT to_jsonb(completion)
    FROM public.booking_shoot_completions completion
    WHERE completion.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
  ),
  (
    SELECT completion_row
    FROM s11s2_happy_before_advance
  ),
  'AI: completion evidence remains logically unchanged by advancement'
);

-- AJ
SELECT is(
  (
    SELECT jsonb_agg(
      to_jsonb(schedule)
      ORDER BY schedule.schedule_version
    )
    FROM public.booking_shoot_schedules schedule
    WHERE schedule.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
  ),
  (
    SELECT schedule_history
    FROM s11s2_happy_before_advance
  ),
  'AJ: shoot schedule history remains unchanged by advancement'
);

-- AK
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id =
         transition_row.organization_id
     AND destination_stage.id =
         transition_row.to_stage_id
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND destination_stage.stage_order = 12
  ),
  0::bigint,
  'AK: Stage 11 -> 12 transition is not created'
);

-- =====================================================================
-- Part 7 — Strict Stage 11 replay
-- =====================================================================

SELECT pg_temp.s11s2_set_actor(
  '8c000000-0000-0000-0000-000000000004'
);

CREATE TEMP TABLE s11s2_replay_counts AS
SELECT
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND transition_row.transition_key =
        'shoot_completed'
  ) AS transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
      'booking.shoot_completed'
      AND audit.entity_id =
        (SELECT happy_booking_id FROM s11s2_ids)
  ) AS audit_count;

-- AL
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT happy_booking_id FROM s11s2_ids)
  )
  $$,
  'AL: valid exact Stage 11 replay succeeds'
);

-- AM
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s2_ids)
      AND transition_row.transition_key =
        'shoot_completed'
  ),
  (
    SELECT transition_count
    FROM s11s2_replay_counts
  ),
  'AM: valid replay adds no transition'
);

-- AN
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
      'booking.shoot_completed'
      AND audit.entity_id =
        (SELECT happy_booking_id FROM s11s2_ids)
  ),
  (
    SELECT audit_count
    FROM s11s2_replay_counts
  ),
  'AN: valid replay adds no audit'
);

-- AO
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT replay_missing_transition_id FROM s11s2_ids)
  )
  $$,
  'P0001',
  'mark_booking_shoot_completed: Shoot Completed replay history is invalid',
  'AO: Stage 11 replay with missing transition history is rejected'
);

-- AP
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT replay_malformed_transition_id FROM s11s2_ids)
  )
  $$,
  'P0001',
  'mark_booking_shoot_completed: Shoot Completed replay history is invalid',
  'AP: Stage 11 replay with malformed transition history is rejected'
);

-- AQ
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT replay_missing_completion_id FROM s11s2_ids)
  )
  $$,
  'P0001',
  'mark_booking_shoot_completed: Shoot Completed replay requires exactly one canonical completion row',
  'AQ: Stage 11 replay without completion evidence is rejected'
);

-- =====================================================================
-- Part 8 — No invented binding / no later-stage surface
-- =====================================================================

-- AV
SELECT ok(
  position(
    'scheduled_start_at'
    IN pg_get_functiondef(
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
    )
  ) = 0
  AND position(
    'scheduled_end_at'
    IN pg_get_functiondef(
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
    )
  ) = 0,
  'AV: Stage 10 -> 11 gate performs no timestamp-based schedule inference'
);

-- AW
SELECT is(
  (
    SELECT count(*)::bigint
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'booking_shoot_completions'
      AND column_name = 'shoot_schedule_id'
  ),
  0::bigint,
  'AW: completion evidence has no shoot_schedule_id binding'
);

-- AX
SELECT ok(
  position(
    'selection_pending'
    IN pg_get_functiondef(
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
    )
  ) = 0
  AND position(
    'stage_order = 12'
    IN pg_get_functiondef(
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
    )
  ) = 0,
  'AX: Stage 12 / selection implementation surface is absent'
);

SELECT * FROM finish();

ROLLBACK;
