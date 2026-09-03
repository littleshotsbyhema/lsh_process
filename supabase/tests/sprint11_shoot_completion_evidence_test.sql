CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(54);

-- =====================================================================
-- Sprint 11 Slice 1
-- Canonical Shoot Completion Evidence Foundation
--
-- Proves:
--   * narrow permission + exact role grants;
--   * immutable tenant-safe completion evidence;
--   * forced RLS / authenticated SELECT-only access;
--   * controlled authenticated recording RPC;
--   * exact Stage 10 + reserved-schedule gate;
--   * idempotent replay / conflicting replay rejection;
--   * audit provenance;
--   * no Stage 10 -> 11 mutation;
--   * tenant/read containment.
-- =====================================================================

-- =====================================================================
-- Part 1 — Structural / ACL contract
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key = 'shoot.complete'
      AND permission.domain = 'bookings'
      AND permission.label = 'Record shoot completion'
      AND permission.requires_server_enforcement
  ),
  1::bigint,
  'shoot.complete exists exactly once with the frozen catalogue contract'
);

-- 2
SELECT is(
  (
    SELECT string_agg(role.key, ',' ORDER BY role.key)
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    JOIN public.roles role
      ON role.id =
         role_permission.role_id
    WHERE permission.key = 'shoot.complete'
  ),
  'founder,photographer,studio_manager'::text,
  'shoot.complete is granted only to Founder, Photographer and Studio Manager'
);

-- 3
SELECT ok(
  to_regclass(
    'public.booking_shoot_completions'
  ) IS NOT NULL,
  'booking_shoot_completions exists'
);

-- 4
SELECT is(
  (
    SELECT array_agg(
             column_name
             ORDER BY ordinal_position
           )::text[]
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_shoot_completions'
  ),
  ARRAY[
    'id',
    'organization_id',
    'booking_id',
    'completed_at',
    'recorded_at',
    'recorded_by'
  ]::text[],
  'completion evidence contains only the frozen structural columns'
);

-- 5
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'booking_shoot_completions_org_booking_key'
      AND constraint_row.contype = 'u'
  ),
  'completion evidence enforces one row per organization and booking'
);

-- 6
SELECT ok(
  (
    SELECT
      replace(
        pg_get_constraintdef(
          constraint_row.oid
        ),
        'public.',
        ''
      )
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'booking_shoot_completions_booking_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, booking_id) REFERENCES bookings(organization_id, id)%',
  'booking foreign key is tenant-safe'
);

-- 7
SELECT ok(
  (
    SELECT
      replace(
        pg_get_constraintdef(
          constraint_row.oid
        ),
        'public.',
        ''
      )
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'booking_shoot_completions_recorded_by_fkey'
  ) LIKE
    'FOREIGN KEY (recorded_by, organization_id) REFERENCES organization_members(id, organization_id)%',
  'recorder foreign key is tenant-safe'
);

-- 8
SELECT ok(
  (
    SELECT relation.relrowsecurity
    FROM pg_class relation
    JOIN pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'booking_shoot_completions'
  ),
  'booking_shoot_completions has RLS enabled'
);

-- 9
SELECT ok(
  (
    SELECT relation.relforcerowsecurity
    FROM pg_class relation
    JOIN pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'booking_shoot_completions'
  ),
  'booking_shoot_completions has RLS forced'
);

-- 10
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_shoot_completions',
    'SELECT'
  ),
  'authenticated has SELECT on completion evidence'
);

-- 11
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_shoot_completions',
    'INSERT'
  ),
  'authenticated has no direct INSERT privilege'
);

-- 12
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_shoot_completions',
    'UPDATE'
  ),
  'authenticated has no direct UPDATE privilege'
);

-- 13
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_shoot_completions',
    'DELETE'
  ),
  'authenticated has no direct DELETE privilege'
);

-- 14
SELECT ok(
  to_regprocedure(
    'public.record_booking_shoot_completion(uuid,timestamp with time zone)'
  ) IS NOT NULL,
  'record_booking_shoot_completion(uuid,timestamptz) exists'
);

-- 15
SELECT is(
  (
    SELECT pg_get_function_result(
             procedure.oid
           )
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.record_booking_shoot_completion(uuid,timestamptz)'::regprocedure
  ),
  'booking_shoot_completions'::text,
  'completion RPC returns booking_shoot_completions'
);

-- 16
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.record_booking_shoot_completion(uuid,timestamptz)'::regprocedure
  ),
  'completion RPC is SECURITY DEFINER'
);

-- 17
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.record_booking_shoot_completion(uuid,timestamptz)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'completion RPC uses an empty search_path'
);

-- 18
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_shoot_completion(uuid,timestamptz)',
    'EXECUTE'
  ),
  'authenticated may execute the completion RPC'
);

-- 19
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.record_booking_shoot_completion(uuid,timestamptz)',
    'EXECUTE'
  ),
  'anon may not execute the completion RPC'
);

-- 20
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.record_booking_shoot_completion(uuid,timestamptz)',
    'EXECUTE'
  ),
  'service_role is not granted the application completion RPC'
);

-- 21
SELECT ok(
  to_regprocedure(
    'public.lsh_booking_shoot_completion_guard()'
  ) IS NOT NULL,
  'immutable completion lifecycle guard exists'
);

-- 22
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    JOIN pg_class relation
      ON relation.oid =
         trigger_row.tgrelid
    JOIN pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'booking_shoot_completions'
      AND trigger_row.tgname =
          'booking_shoot_completions_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'completion evidence has exactly one immutable lifecycle trigger'
);

-- =====================================================================
-- Part 2 — Canonical fixture identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8b000000-0000-0000-0000-000000000001'::uuid),
  ('8b000000-0000-0000-0000-000000000002'::uuid),
  ('8b000000-0000-0000-0000-000000000003'::uuid),
  ('8b000000-0000-0000-0000-000000000004'::uuid),
  ('8b000000-0000-0000-0000-000000000005'::uuid),
  ('8b000000-0000-0000-0000-000000000006'::uuid),
  ('8b000000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  '8b000000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Branch A',
  's11-branch-a',
  'active'
),
(
  '8b000000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Branch B',
  's11-branch-b',
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
  '8b000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000001',
  'active',
  'S11 Founder',
  NULL
),
(
  '8b000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000002',
  'active',
  'S11 Photographer',
  NULL
),
(
  '8b000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000003',
  'active',
  'S11 Stylist',
  NULL
),
(
  '8b000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000004',
  'active',
  'S11 Coordinator',
  NULL
),
(
  '8b000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000005',
  'suspended',
  'S11 Suspended Photographer',
  now()
),
(
  '8b000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000006',
  'active',
  'S11 Branch Photographer',
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
      '8b000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8b000000-0000-0000-0000-000000000102'::uuid,
      'photographer'::text,
      '8b000000-0000-0000-0000-000000000701'::uuid
    ),
    (
      '8b000000-0000-0000-0000-000000000103'::uuid,
      'stylist'::text,
      '8b000000-0000-0000-0000-000000000701'::uuid
    ),
    (
      '8b000000-0000-0000-0000-000000000104'::uuid,
      'client_coordinator'::text,
      '8b000000-0000-0000-0000-000000000701'::uuid
    ),
    (
      '8b000000-0000-0000-0000-000000000105'::uuid,
      'photographer'::text,
      '8b000000-0000-0000-0000-000000000701'::uuid
    ),
    (
      '8b000000-0000-0000-0000-000000000106'::uuid,
      'photographer'::text,
      '8b000000-0000-0000-0000-000000000701'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

-- Family creation is actor-guarded. Establish the canonical Founder
-- identity before constructing the family fixture.
SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
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
  '8b000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-23456B',
  'S11 Completion Family',
  'S11 Completion Family',
  'active',
  '8b000000-0000-0000-0000-000000000101',
  '8b000000-0000-0000-0000-000000000101'
);

-- Helper: switch auth.uid() without exposing credentials.
CREATE FUNCTION pg_temp.s11_set_actor(
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

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000001'
);

-- Helper: construct a canonical accepted booking shell.
CREATE FUNCTION pg_temp.s11_create_booking(
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
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE package.package_key =
        'maternity_gold'
    AND version.version_number = 1;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8b000000-0000-0000-0000-000000000201',
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
  FROM public.accept_quotation(
    v_quote.id
  );

  -- Branch identity is canonical quotation/conversion evidence.
  -- Never rewrite booking.branch_id after accept_quotation().

  RETURN v_booking.id;
END;
$$;

-- Helper: append a reserved schedule tip.
CREATE FUNCTION pg_temp.s11_reserve_schedule(
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
    '2030-07-01 10:00:00+05:30'::timestamptz
    + make_interval(days => p_day_offset);

  SELECT *
  INTO v_proposed
  FROM public.propose_booking_shoot_schedule(
    p_booking_id,
    v_start,
    v_start + interval '2 hours',
    'Asia/Kolkata',
    'studio',
    'Sprint 11 Slice 1 fixture'
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
    '8b000000-0000-0000-0000-000000000101'
  );
END;
$$;

-- Helper: fixture-only journey movement.
-- This does not represent a production mutation path.
CREATE FUNCTION pg_temp.s11_move_to_stage(
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
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order =
        p_stage_order
    AND stage.stage_key =
        p_stage_key
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
    's11_fixture_' || p_stage_key,
    now(),
    '8b000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_target.id,
    stage_entered_at =
      now(),
    version =
      state.version + 1,
    updated_at =
      now(),
    updated_by =
      '8b000000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

-- =====================================================================
-- Part 3 — Happy Stage-10 fixture through the existing canonical gate
-- =====================================================================

CREATE TEMP TABLE s11_ids (
  happy_booking_id uuid,
  wrong_stage_booking_id uuid,
  missing_schedule_booking_id uuid,
  cross_branch_booking_id uuid,
  completed_at timestamptz
);

INSERT INTO s11_ids (
  happy_booking_id,
  wrong_stage_booking_id,
  missing_schedule_booking_id,
  cross_branch_booking_id,
  completed_at
)
VALUES (
  pg_temp.s11_create_booking('8b000000-0000-0000-0000-000000000701'::uuid),
  pg_temp.s11_create_booking('8b000000-0000-0000-0000-000000000701'::uuid),
  pg_temp.s11_create_booking('8b000000-0000-0000-0000-000000000701'::uuid),
  pg_temp.s11_create_booking(
    '8b000000-0000-0000-0000-000000000702'
  ),
  now() - interval '30 minutes'
);

GRANT SELECT
ON s11_ids
TO authenticated;

SELECT pg_temp.s11_reserve_schedule(
  (SELECT happy_booking_id FROM s11_ids),
  1
);

SELECT pg_temp.s11_move_to_stage(
  (SELECT happy_booking_id FROM s11_ids),
  8,
  'booking_confirmed'
);

CREATE TEMP TABLE s11_happy_preparation AS
SELECT *
FROM public.start_pre_shoot_preparation(
  (SELECT happy_booking_id FROM s11_ids)
);

DO $s11_complete_required_items$
DECLARE
  v_item_id uuid;
BEGIN
  FOR v_item_id IN
    SELECT item.id
    FROM public.booking_preparation_items item
    WHERE item.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND item.preparation_id =
          (SELECT id FROM s11_happy_preparation)
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
$s11_complete_required_items$;

SELECT public.assign_booking_team_member(
  (SELECT happy_booking_id FROM s11_ids),
  'lead_photographer',
  '8b000000-0000-0000-0000-000000000102',
  true,
  NULL
);

SELECT public.assign_booking_team_member(
  (SELECT happy_booking_id FROM s11_ids),
  'stylist',
  '8b000000-0000-0000-0000-000000000103',
  true,
  NULL
);

SELECT public.record_booking_safety_readiness(
  (SELECT happy_booking_id FROM s11_ids),
  'not_applicable',
  'ready'
);

SELECT public.mark_booking_shoot_scheduled(
  (SELECT happy_booking_id FROM s11_ids)
);

-- Cross-branch fixture: valid Stage 10 + reserved schedule,
-- but the later invoking Photographer is scoped to Branch A only.
SELECT pg_temp.s11_reserve_schedule(
  (SELECT cross_branch_booking_id FROM s11_ids),
  2
);

SELECT pg_temp.s11_move_to_stage(
  (SELECT cross_branch_booking_id FROM s11_ids),
  10,
  'shoot_scheduled'
);

-- Missing-schedule fixture: exact Stage 10 but deliberately no schedule.
SELECT pg_temp.s11_move_to_stage(
  (SELECT missing_schedule_booking_id FROM s11_ids),
  10,
  'shoot_scheduled'
);

-- =====================================================================
-- Part 4 — Authentication / permission / stage rejection
-- =====================================================================

SELECT pg_temp.s11_set_actor(NULL);

-- 23
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    now() - interval '30 minutes'
  )
  $$,
  '42501',
  'record_booking_shoot_completion: authenticated actor required',
  'unauthenticated invocation is rejected'
);

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000007'
);

-- 24
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    now() - interval '30 minutes'
  )
  $$,
  '42501',
  'record_booking_shoot_completion: active organization membership required',
  'authenticated non-member invocation is rejected'
);

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000005'
);

-- 25
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    now() - interval '30 minutes'
  )
  $$,
  '42501',
  'record_booking_shoot_completion: active organization membership required',
  'suspended member invocation is rejected'
);

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000004'
);

-- 26
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    now() - interval '30 minutes'
  )
  $$,
  '42501',
  'record_booking_shoot_completion: shoot.complete permission required',
  'actor lacking shoot.complete is rejected'
);

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000006'
);

-- 27
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT cross_branch_booking_id FROM s11_ids),
    now() - interval '30 minutes'
  )
  $$,
  '42501',
  'record_booking_shoot_completion: shoot.complete permission required',
  'branch-scoped Photographer cannot record completion for another branch'
);

-- Use the active organization-wide Photographer for the remaining
-- canonical completion-gate rejection and success cases.
SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000002'
);

-- 28
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT wrong_stage_booking_id FROM s11_ids),
    now() - interval '30 minutes'
  )
  $$,
  '22023',
  'record_booking_shoot_completion: booking must be exactly Shoot Scheduled',
  'completion recording rejects a booking outside exact Stage 10'
);

-- 29
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
          (SELECT happy_booking_id FROM s11_ids)
  ),
  'shoot_scheduled'::text,
  'happy fixture is exactly Stage 10 Shoot Scheduled'
);

-- 30
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT missing_schedule_booking_id FROM s11_ids),
    now() - interval '30 minutes'
  )
  $$,
  '22023',
  'record_booking_shoot_completion: current authoritative reserved shoot schedule required',
  'exact Stage 10 without a reserved schedule is rejected'
);

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000002'
);

-- 31
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    now() + interval '1 minute'
  )
  $$,
  '22023',
  'record_booking_shoot_completion: completed_at cannot be in the future',
  'future completion timestamp is rejected'
);

CREATE TEMP TABLE s11_before_completion AS
SELECT
  state.version AS journey_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
  ) AS transition_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT happy_booking_id FROM s11_ids);

-- =====================================================================
-- Part 5 — Successful immutable completion recording
-- =====================================================================

-- 32
SELECT lives_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    (SELECT completed_at FROM s11_ids)
  )
  $$,
  'authorized Photographer may record completion for exact Stage 10'
);

CREATE TEMP TABLE s11_first_completion AS
SELECT completion.*
FROM public.booking_shoot_completions completion
WHERE completion.booking_id =
      (SELECT happy_booking_id FROM s11_ids);

-- 33
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_completions completion
    WHERE completion.booking_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  1::bigint,
  'first successful recording creates exactly one completion row'
);

-- 34
SELECT is(
  (
    SELECT recorded_by
    FROM s11_first_completion
  ),
  '8b000000-0000-0000-0000-000000000102'::uuid,
  'completion evidence attributes recorded_by to the authenticated Photographer member'
);

-- 35
SELECT is(
  (
    SELECT completed_at
    FROM s11_first_completion
  ),
  (
    SELECT completed_at
    FROM s11_ids
  ),
  'completion evidence preserves the caller-supplied canonical completed_at'
);

-- 36
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_completion_recorded'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  1::bigint,
  'first completion recording appends exactly one completion audit event'
);

-- 37
SELECT is(
  (
    SELECT audit.actor_member_id
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_completion_recorded'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  '8b000000-0000-0000-0000-000000000102'::uuid,
  'completion audit preserves authenticated actor provenance'
);

-- 38
SELECT ok(
  (
    SELECT
      NOT (
        COALESCE(audit.metadata, '{}'::jsonb)
        ?| ARRAY[
          'safety_state',
          'comfort_state',
          'readiness_id',
          'signed_by',
          'family_note',
          'medical_note',
          'incident_note'
        ]
      )
      AND NOT (
        COALESCE(audit.new_values, '{}'::jsonb)
        ?| ARRAY[
          'safety_state',
          'comfort_state',
          'readiness_id',
          'signed_by',
          'family_note',
          'medical_note',
          'incident_note'
        ]
      )
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_completion_recorded'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  'completion audit excludes restricted Safety and arbitrary note fields'
);

-- =====================================================================
-- Part 6 — Idempotent replay and immutable conflict semantics
-- =====================================================================

-- 39
SELECT lives_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    (SELECT completed_at FROM s11_ids)
  )
  $$,
  'exact completed_at replay is idempotent'
);

-- 40
SELECT is(
  (
    SELECT id
    FROM public.booking_shoot_completions
    WHERE booking_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  (
    SELECT id
    FROM s11_first_completion
  ),
  'exact replay preserves the original immutable completion identity'
);

-- 41
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_completions completion
    WHERE completion.booking_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  1::bigint,
  'exact replay creates no duplicate completion evidence'
);

-- 42
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.shoot_completion_recorded'
      AND audit.entity_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  1::bigint,
  'exact replay creates no duplicate completion audit'
);

-- 43
SELECT throws_ok(
  $$
  SELECT public.record_booking_shoot_completion(
    (SELECT happy_booking_id FROM s11_ids),
    (SELECT completed_at FROM s11_ids)
      - interval '1 minute'
  )
  $$,
  '22023',
  'record_booking_shoot_completion: completion evidence already exists with a different completed_at',
  'conflicting replay cannot rewrite completed_at'
);

-- 44
SELECT throws_ok(
  $$
  UPDATE public.booking_shoot_completions
  SET completed_at =
      completed_at - interval '1 minute'
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11_ids)
  $$,
  'P0001',
  'booking shoot completion evidence is immutable',
  'completion evidence UPDATE is rejected by the lifecycle guard'
);

-- 45
SELECT throws_ok(
  $$
  DELETE FROM public.booking_shoot_completions
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11_ids)
  $$,
  'P0001',
  'booking shoot completion evidence is immutable',
  'completion evidence DELETE is rejected by the lifecycle guard'
);

-- =====================================================================
-- Part 7 — Journey containment
-- =====================================================================

-- 46
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
          (SELECT happy_booking_id FROM s11_ids)
  ),
  'shoot_scheduled'::text,
  'successful completion recording leaves the booking at Stage 10'
);

-- 47
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  (
    SELECT journey_version
    FROM s11_before_completion
  ),
  'completion recording does not mutate journey version'
);

-- 48
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  (
    SELECT transition_count
    FROM s11_before_completion
  ),
  'completion recording appends no journey transition'
);

-- 49
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          (SELECT happy_booking_id FROM s11_ids)
      AND transition_row.transition_key =
          'shoot_completed'
  ),
  0::bigint,
  'Slice 1 creates no Stage 10 -> 11 shoot_completed transition'
);

-- =====================================================================
-- Part 8 — RLS visibility and authenticated direct-write denial
-- =====================================================================

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000002'
);

SET LOCAL ROLE authenticated;

-- 50
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_completions completion
    WHERE completion.booking_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  1::bigint,
  'authorized Photographer can read completion evidence through RLS'
);

RESET ROLE;

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000007'
);

SET LOCAL ROLE authenticated;

-- 51
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_completions completion
    WHERE completion.booking_id =
          (SELECT happy_booking_id FROM s11_ids)
  ),
  0::bigint,
  'authenticated outsider cannot read another tenant booking completion evidence'
);

RESET ROLE;

SELECT pg_temp.s11_set_actor(
  '8b000000-0000-0000-0000-000000000002'
);

SET LOCAL ROLE authenticated;

-- 52
SELECT throws_ok(
  $$
  INSERT INTO public.booking_shoot_completions (
    organization_id,
    booking_id,
    completed_at,
    recorded_by
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    (SELECT happy_booking_id FROM s11_ids),
    now() - interval '1 hour',
    '8b000000-0000-0000-0000-000000000102'
  )
  $$,
  '42501',
  'permission denied for table booking_shoot_completions',
  'authenticated direct INSERT is denied'
);

-- 53
SELECT throws_ok(
  $$
  UPDATE public.booking_shoot_completions
  SET completed_at =
      completed_at - interval '1 minute'
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11_ids)
  $$,
  '42501',
  'permission denied for table booking_shoot_completions',
  'authenticated direct UPDATE is denied'
);

-- 54
SELECT throws_ok(
  $$
  DELETE FROM public.booking_shoot_completions
  WHERE booking_id =
        (SELECT happy_booking_id FROM s11_ids)
  $$,
  '42501',
  'permission denied for table booking_shoot_completions',
  'authenticated direct DELETE is denied'
);

RESET ROLE;

SELECT * FROM finish();

ROLLBACK;
