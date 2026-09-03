BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(71);

-- =====================================================================
-- Sprint 10 — Slice 2
-- Pre-Shoot Preparation Instance + Controlled Stage 8 -> 9 Gate
--
-- Structural foundation contract only.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Canonical preparation evidence surface
-- ---------------------------------------------------------------------

-- 1
SELECT ok(
  to_regclass(
    'public.booking_preparations'
  ) IS NOT NULL,
  'booking_preparations exists'
);

-- 2
SELECT is(
  (
    SELECT string_agg(
      c.column_name,
      ','
      ORDER BY c.ordinal_position
    )
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'booking_preparations'
  ),
  'id,organization_id,booking_id,started_at,started_by',
  'booking_preparations contains only the frozen Slice 2 preparation-instance columns'
);

-- 3
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          to_regclass(
            'public.booking_preparations'
          )
      AND c.conname =
          'booking_preparations_booking_fkey'
      AND c.contype = 'f'
  ),
  'booking_preparations has tenant-safe booking foreign key'
);

-- 4
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          to_regclass(
            'public.booking_preparations'
          )
      AND c.conname =
          'booking_preparations_started_by_fkey'
      AND c.contype = 'f'
  ),
  'booking_preparations has tenant-safe actor foreign key'
);

-- 5
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          to_regclass(
            'public.booking_preparations'
          )
      AND c.conname =
          'booking_preparations_organization_id_id_key'
      AND c.contype = 'u'
  ),
  'booking_preparations exposes tenant-safe organization and preparation identity'
);

-- 6
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          to_regclass(
            'public.booking_preparations'
          )
      AND c.conname =
          'booking_preparations_organization_booking_key'
      AND c.contype = 'u'
  ),
  'booking_preparations permits exactly one authoritative preparation per booking'
);

-- 7
SELECT ok(
  to_regprocedure(
    'public.lsh_booking_preparation_guard()'
  ) IS NOT NULL,
  'booking preparation immutable guard exists'
);

-- 8
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_trigger t
    WHERE NOT t.tgisinternal
      AND t.tgrelid =
          to_regclass(
            'public.booking_preparations'
          )
      AND t.tgname =
          'booking_preparations_guard'
  ),
  'booking preparation immutable guard trigger exists'
);

-- ---------------------------------------------------------------------
-- Preparation permission catalogue and exact least-privilege grants
-- ---------------------------------------------------------------------

-- 9
SELECT is(
  (
    SELECT count(*)
    FROM public.permissions p
    WHERE p.key = 'prep.read'
  ),
  1::bigint,
  'prep.read exists exactly once'
);

-- 10
SELECT is(
  (
    SELECT count(*)
    FROM public.permissions p
    WHERE p.key = 'prep.write'
  ),
  1::bigint,
  'prep.write exists exactly once'
);

-- 11
SELECT ok(
  COALESCE(
    (
      SELECT p.requires_server_enforcement
      FROM public.permissions p
      WHERE p.key = 'prep.read'
    ),
    false
  ),
  'prep.read requires server enforcement'
);

-- 12
SELECT ok(
  COALESCE(
    (
      SELECT p.requires_server_enforcement
      FROM public.permissions p
      WHERE p.key = 'prep.write'
    ),
    false
  ),
  'prep.write requires server enforcement'
);

-- 13
SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE p.key = 'prep.read'
      AND r.key IN (
        'founder',
        'studio_manager',
        'client_coordinator'
      )
  ),
  3::bigint,
  'Founder, Studio Manager and Client Coordinator receive prep.read'
);

-- 14
SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE p.key = 'prep.read'
      AND r.key NOT IN (
        'founder',
        'studio_manager',
        'client_coordinator'
      )
  ),
  0::bigint,
  'no other role receives prep.read'
);

-- 15
SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE p.key = 'prep.write'
      AND r.key IN (
        'founder',
        'studio_manager',
        'client_coordinator'
      )
  ),
  3::bigint,
  'Founder, Studio Manager and Client Coordinator receive prep.write'
);

-- 16
SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE p.key = 'prep.write'
      AND r.key NOT IN (
        'founder',
        'studio_manager',
        'client_coordinator'
      )
  ),
  0::bigint,
  'no other role receives prep.write'
);

-- ---------------------------------------------------------------------
-- RLS and direct-write denial
-- ---------------------------------------------------------------------

-- 17
SELECT ok(
  COALESCE(
    (
      SELECT c.relrowsecurity
      FROM pg_class c
      WHERE c.oid =
            to_regclass(
              'public.booking_preparations'
            )
    ),
    false
  ),
  'booking_preparations has RLS enabled'
);

-- 18
SELECT ok(
  COALESCE(
    (
      SELECT c.relforcerowsecurity
      FROM pg_class c
      WHERE c.oid =
            to_regclass(
              'public.booking_preparations'
            )
    ),
    false
  ),
  'booking_preparations has FORCE RLS enabled'
);

-- 19
SELECT is(
  (
    SELECT count(*)
    FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.tablename = 'booking_preparations'
      AND p.policyname =
          'booking_preparations_authenticated_select'
      AND p.cmd = 'SELECT'
  ),
  1::bigint,
  'booking_preparations exposes exactly one authenticated SELECT policy'
);

-- 20
SELECT ok(
  COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_preparations'
      ),
      'SELECT'
    ),
    false
  ),
  'authenticated may select booking preparations subject to RLS'
);

-- 21
SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_preparations'
      ),
      'INSERT'
    ),
    false
  ),
  'authenticated cannot directly insert booking preparations'
);

-- 22
SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_preparations'
      ),
      'UPDATE'
    ),
    false
  ),
  'authenticated cannot directly update booking preparations'
);

-- 23
SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_preparations'
      ),
      'DELETE'
    ),
    false
  ),
  'authenticated cannot directly delete booking preparations'
);

-- 24
SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'anon',
      to_regclass(
        'public.booking_preparations'
      ),
      'SELECT'
    ),
    false
  ),
  'anon cannot select booking preparations'
);

-- ---------------------------------------------------------------------
-- Guard function is trigger-only for normal application roles
-- ---------------------------------------------------------------------

-- 25
SELECT ok(
  NOT COALESCE(
    has_function_privilege(
      'authenticated',
      to_regprocedure(
        'public.lsh_booking_preparation_guard()'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'authenticated cannot directly execute booking preparation guard'
);

-- 26
SELECT ok(
  NOT COALESCE(
    has_function_privilege(
      'anon',
      to_regprocedure(
        'public.lsh_booking_preparation_guard()'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'anon cannot directly execute booking preparation guard'
);


-- =====================================================================
-- Section C — Dedicated Stage 8 -> 9 RPC structural contract
-- =====================================================================

-- 27
SELECT ok(
  to_regprocedure(
    'public.start_pre_shoot_preparation(uuid)'
  ) IS NOT NULL,
  'start_pre_shoot_preparation exists'
);

-- 28
SELECT ok(
  COALESCE(
    (
      SELECT p.prosecdef
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.start_pre_shoot_preparation(uuid)'
            )::oid
    ),
    false
  ),
  'start_pre_shoot_preparation is SECURITY DEFINER'
);

-- 29
SELECT ok(
  COALESCE(
    (
      SELECT
        pg_get_functiondef(p.oid)
          LIKE '%SET search_path TO ''''%'
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.start_pre_shoot_preparation(uuid)'
            )::oid
    ),
    false
  ),
  'start_pre_shoot_preparation uses empty search_path'
);

-- 30
SELECT ok(
  COALESCE(
    has_function_privilege(
      'authenticated',
      to_regprocedure(
        'public.start_pre_shoot_preparation(uuid)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'authenticated may execute start_pre_shoot_preparation'
);

-- 31
SELECT ok(
  NOT COALESCE(
    has_function_privilege(
      'anon',
      to_regprocedure(
        'public.start_pre_shoot_preparation(uuid)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'anon cannot execute start_pre_shoot_preparation'
);


-- =====================================================================
-- Fixture A — successful Stage 8 -> 9 + exact Stage 9 replay
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('87000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '87000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '87000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 10 Preparation Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '87000000-0000-0000-0000-000000000011'::uuid,
  r.id
FROM public.roles r
WHERE r.key = 'founder';

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '87000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"87000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '87000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  'QT-345678',
  'Sprint 10 Preparation Family A',
  'Preparation Family A',
  'active',
  '87000000-0000-0000-0000-000000000011',
  '87000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10p_quote_a AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '87000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10p_quote_a),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages p
      ON p.organization_id =
         pv.organization_id
     AND p.id =
         pv.package_id
    WHERE p.package_key =
          'maternity_gold'
      AND pv.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10p_quote_a),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10p_quote_a),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10p_booking_a AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10p_quote_a)
);

CREATE TEMP TABLE s10p_schedule_a_v1 AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10p_booking_a),
  '2030-04-01 10:00:00+05:30'::timestamptz,
  '2030-04-01 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 10 preparation fixture A'
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
  '87000000-0000-0000-0000-000000000011'::uuid
FROM s10p_schedule_a_v1;

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
  js.organization_id,
  js.booking_id,
  js.current_stage_id,
  target.id,
  's10_slice2_test_booking_confirmed',
  now(),
  '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_a);

UPDATE public.booking_journey_states js
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    js.version + 1,
  updated_at =
    now(),
  updated_by =
    '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_a)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

-- 32
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  'booking_confirmed',
  'fixture A begins at canonical Booking Confirmed'
);

-- 33
SELECT is(
  (
    SELECT s.schedule_state
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10p_booking_a)
    ORDER BY s.schedule_version DESC
    LIMIT 1
  ),
  'reserved',
  'fixture A has an authoritative reserved schedule'
);

-- 34
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10p_started_a AS
  SELECT *
  FROM public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_a)
  )
  $$,
  'Stage 8 booking with reserved schedule starts preparation'
);

-- 35
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations p
    WHERE p.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  1::bigint,
  'first start creates exactly one authoritative preparation'
);

-- 36
SELECT is(
  (
    SELECT p.started_by
    FROM public.booking_preparations p
    WHERE p.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  '87000000-0000-0000-0000-000000000011'::uuid,
  'preparation records authenticated Founder member'
);

-- 37
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  'pre_shoot_preparation',
  'start operation advances journey exactly to Pre-Shoot Preparation'
);

-- 38
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  3::bigint,
  'start operation increments journey version exactly once'
);

-- 39
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10p_booking_a)
      AND t.transition_key =
          'pre_shoot_preparation_started'
  ),
  1::bigint,
  'start operation appends exactly one dedicated Stage 8 to 9 transition'
);

-- 40
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions t
    JOIN public.booking_journey_stages f
      ON f.organization_id =
         t.organization_id
     AND f.id =
         t.from_stage_id
    JOIN public.booking_journey_stages destination
      ON destination.organization_id =
         t.organization_id
     AND destination.id =
         t.to_stage_id
    WHERE t.booking_id =
          (SELECT id FROM s10p_booking_a)
      AND t.transition_key =
          'pre_shoot_preparation_started'
      AND f.stage_key =
          'booking_confirmed'
      AND f.stage_order = 8
      AND destination.stage_key =
          'pre_shoot_preparation'
      AND destination.stage_order = 9
  ),
  'dedicated transition records exact Stage 8 to Stage 9 movement'
);

-- 41
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events a
    WHERE a.entity_id =
          (SELECT id FROM s10p_booking_a)
      AND a.action_key =
          'booking.pre_shoot_preparation_started'
  ),
  1::bigint,
  'first start appends exactly one preparation-start audit event'
);

-- 42
SELECT throws_ok(
  $$
  UPDATE public.booking_preparations
  SET started_at =
      started_at + interval '1 minute'
  WHERE booking_id =
        (SELECT id FROM s10p_booking_a)
  $$,
  'P0001',
  'booking preparation evidence is append-only and immutable',
  'preparation evidence cannot be updated'
);

-- 43
SELECT throws_ok(
  $$
  DELETE FROM public.booking_preparations
  WHERE booking_id =
        (SELECT id FROM s10p_booking_a)
  $$,
  'P0001',
  'booking preparation evidence is append-only and immutable',
  'preparation evidence cannot be deleted'
);

-- 44
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10p_replay_a AS
  SELECT *
  FROM public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_a)
  )
  $$,
  'exact Stage 9 retry is idempotent'
);

-- 45
SELECT is(
  (SELECT id FROM s10p_replay_a),
  (SELECT id FROM s10p_started_a),
  'exact replay returns the same authoritative preparation instance'
);

-- 46
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations p
    WHERE p.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  1::bigint,
  'replay does not append another preparation'
);

-- 47
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10p_booking_a)
      AND t.transition_key =
          'pre_shoot_preparation_started'
  ),
  1::bigint,
  'replay does not append another journey transition'
);

-- 48
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events a
    WHERE a.entity_id =
          (SELECT id FROM s10p_booking_a)
      AND a.action_key =
          'booking.pre_shoot_preparation_started'
  ),
  1::bigint,
  'replay does not append another audit event'
);

-- 49
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  3::bigint,
  'replay does not increment journey version'
);


-- =====================================================================
-- Fixture B — independent preparation and stage permissions
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('87000000-0000-0000-0000-000000000002'::uuid),
  ('87000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '87000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '87000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 10 Preparation Coordinator'
),
(
  '87000000-0000-0000-0000-000000000013',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '87000000-0000-0000-0000-000000000003',
  'active',
  'Sprint 10 Preparation Photographer'
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
  r.id,
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
FROM (
  VALUES
    (
      '87000000-0000-0000-0000-000000000012'::uuid,
      'client_coordinator'
    ),
    (
      '87000000-0000-0000-0000-000000000013'::uuid,
      'photographer'
    )
) fixture(member_id, role_key)
JOIN public.roles r
  ON r.key = fixture.role_key;

-- ---------------------------------------------------------------------
-- Photographer cannot use even the otherwise-idempotent Stage 9 replay.
-- Authorization remains ahead of replay.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '87000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"87000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

-- 50
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_a)
  )
  $$,
  '42501',
  'start_pre_shoot_preparation: prep.write permission required',
  'Photographer without prep.write cannot use Stage 9 replay'
);

-- 51
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations p
    WHERE p.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  1::bigint,
  'denied Photographer replay leaves preparation evidence unchanged'
);

-- ---------------------------------------------------------------------
-- Independent Client Coordinator fixture.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '87000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"87000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '87000000-0000-0000-0000-000000000021',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  'QT-345679',
  'Sprint 10 Preparation Family B',
  'Preparation Family B',
  'active',
  '87000000-0000-0000-0000-000000000011',
  '87000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10p_quote_b AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '87000000-0000-0000-0000-000000000021',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10p_quote_b),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages p
      ON p.organization_id =
         pv.organization_id
     AND p.id =
         pv.package_id
    WHERE p.package_key =
          'maternity_gold'
      AND pv.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10p_quote_b),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10p_quote_b),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10p_booking_b AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10p_quote_b)
);

CREATE TEMP TABLE s10p_schedule_b_v1 AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10p_booking_b),
  '2030-04-02 09:00:00+05:30'::timestamptz,
  '2030-04-02 11:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 10 preparation fixture B'
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
  '87000000-0000-0000-0000-000000000011'::uuid
FROM s10p_schedule_b_v1;

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
  js.organization_id,
  js.booking_id,
  js.current_stage_id,
  target.id,
  's10_slice2_test_booking_confirmed',
  now(),
  '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_b);

UPDATE public.booking_journey_states js
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    js.version + 1,
  updated_at =
    now(),
  updated_by =
    '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_b)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

SELECT set_config(
  'request.jwt.claim.sub',
  '87000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"87000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 52
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_b)
  ),
  'booking_confirmed',
  'fixture B begins at canonical Booking Confirmed'
);

-- Temporarily remove only prep.write from Client Coordinator.
-- This transaction rolls back at the end of the pgTAP file.
DELETE FROM public.role_permissions rp
USING public.roles r,
      public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.key = 'client_coordinator'
  AND p.key = 'prep.write';

-- 53
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_b)
  )
  $$,
  '42501',
  'start_pre_shoot_preparation: prep.write permission required',
  'prep.write is independently required'
);

-- 54
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_b)
  ),
  'booking_confirmed',
  'missing prep.write leaves fixture B at Stage 8'
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.key = 'client_coordinator'
  AND p.key = 'prep.write';

-- Temporarily remove only booking.stage.advance.
DELETE FROM public.role_permissions rp
USING public.roles r,
      public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.key = 'client_coordinator'
  AND p.key = 'booking.stage.advance';

-- 55
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_b)
  )
  $$,
  '42501',
  'start_pre_shoot_preparation: booking.stage.advance permission required',
  'booking.stage.advance is independently required'
);

-- 56
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_b)
  ),
  'booking_confirmed',
  'missing booking.stage.advance leaves fixture B at Stage 8'
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.key = 'client_coordinator'
  AND p.key = 'booking.stage.advance';

-- 57
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10p_started_b AS
  SELECT *
  FROM public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_b)
  )
  $$,
  'Client Coordinator succeeds only when both permissions are present'
);

-- 58
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations p
    WHERE p.booking_id =
          (SELECT id FROM s10p_booking_b)
  ),
  1::bigint,
  'authorized Client Coordinator creates exactly one preparation'
);

-- 59
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_b)
  ),
  'pre_shoot_preparation',
  'authorized Client Coordinator advances exactly to Stage 9'
);

-- 60
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10p_booking_b)
      AND t.transition_key =
          'pre_shoot_preparation_started'
  ),
  1::bigint,
  'authorized Client Coordinator appends exactly one dedicated transition'
);


-- =====================================================================
-- Fixture C — reserved schedule and lifecycle integrity gates
-- =====================================================================

-- Restore Founder authentication for integrity fixtures.
SELECT set_config(
  'request.jwt.claim.sub',
  '87000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"87000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Independent malformed Stage 8 fixture with no schedule evidence.
-- ---------------------------------------------------------------------

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
  '87000000-0000-0000-0000-000000000022',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  'QT-34567A',
  'Sprint 10 Preparation Family C',
  'Preparation Family C',
  'active',
  '87000000-0000-0000-0000-000000000011',
  '87000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10p_quote_c AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '87000000-0000-0000-0000-000000000022',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10p_quote_c),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages p
      ON p.organization_id =
         pv.organization_id
     AND p.id =
         pv.package_id
    WHERE p.package_key =
          'maternity_gold'
      AND pv.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10p_quote_c),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10p_quote_c),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10p_booking_c AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10p_quote_c)
);

-- Test-only progression to Stage 8 without confirmation.
-- This deliberately constructs the missing-schedule integrity case.
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
  js.organization_id,
  js.booking_id,
  js.current_stage_id,
  target.id,
  's10_slice2_test_booking_confirmed',
  now(),
  '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_c);

UPDATE public.booking_journey_states js
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    js.version + 1,
  updated_at =
    now(),
  updated_by =
    '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_c)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

-- 61
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_c)
  ),
  'booking_confirmed',
  'fixture C begins at canonical Booking Confirmed'
);

-- 62
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10p_booking_c)
  ),
  0::bigint,
  'fixture C initially has no schedule evidence'
);

-- 63
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_c)
  )
  $$,
  '22023',
  'start_pre_shoot_preparation: current authoritative reserved schedule required',
  'Stage 8 cannot start preparation without a reserved schedule'
);

-- 64
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations p
    WHERE p.booking_id =
          (SELECT id FROM s10p_booking_c)
  ),
  0::bigint,
  'missing reserved schedule creates no preparation evidence'
);

-- 65
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_c)
  ),
  'booking_confirmed',
  'missing reserved schedule leaves fixture C at Stage 8'
);

-- ---------------------------------------------------------------------
-- Build valid schedule lineage, then deliberately inject preparation
-- evidence while the journey remains at Stage 8.
-- ---------------------------------------------------------------------

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
  b.organization_id,
  b.id,
  1,
  NULL,
  'proposed',
  '2030-04-03 10:00:00+05:30'::timestamptz,
  '2030-04-03 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 10 preparation fixture C',
  NULL,
  '87000000-0000-0000-0000-000000000011'::uuid
FROM public.bookings b
WHERE b.id =
      (SELECT id FROM s10p_booking_c);

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
  s.organization_id,
  s.booking_id,
  2,
  s.id,
  'reserved',
  s.scheduled_start_at,
  s.scheduled_end_at,
  s.timezone,
  s.location_type,
  s.location_details,
  NULL,
  '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_shoot_schedules s
WHERE s.booking_id =
      (SELECT id FROM s10p_booking_c)
  AND s.schedule_version = 1;

INSERT INTO public.booking_preparations (
  organization_id,
  booking_id,
  started_at,
  started_by
)
SELECT
  b.organization_id,
  b.id,
  now(),
  '87000000-0000-0000-0000-000000000011'::uuid
FROM public.bookings b
WHERE b.id =
      (SELECT id FROM s10p_booking_c);

-- 66
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_c)
  )
  $$,
  'P0001',
  'start_pre_shoot_preparation: Stage 8 cannot already contain a preparation instance',
  'Stage 8 with pre-existing preparation evidence is an integrity failure'
);

-- 67
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_c)
  ),
  'booking_confirmed',
  'Stage 8 integrity failure does not move the journey'
);

-- 68
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10p_booking_c)
      AND t.transition_key =
          'pre_shoot_preparation_started'
  ),
  0::bigint,
  'Stage 8 integrity failure appends no dedicated transition'
);

-- ---------------------------------------------------------------------
-- Stage 10 must not be treated as a preparation-start replay.
--
-- Reuse successful fixture A and move it forward test-only.
-- ---------------------------------------------------------------------

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
  js.organization_id,
  js.booking_id,
  js.current_stage_id,
  target.id,
  's10_slice2_test_shoot_scheduled',
  now(),
  '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'shoot_scheduled'
 AND target.stage_order = 10
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_a);

UPDATE public.booking_journey_states js
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    js.version + 1,
  updated_at =
    now(),
  updated_by =
    '87000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10p_booking_a)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'shoot_scheduled'
  AND target.stage_order = 10
  AND target.is_active;

-- 69
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id =
         js.organization_id
     AND s.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10p_booking_a)
  ),
  'shoot_scheduled',
  'test-only fixture advances booking A to Stage 10'
);

-- 70
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10p_booking_a)
  )
  $$,
  '22023',
  'start_pre_shoot_preparation: booking must be exactly Booking Confirmed or an exact Pre-Shoot Preparation replay',
  'Stage 10 is not treated as a preparation-start replay'
);

-- 71
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10p_booking_a)
      AND t.transition_key =
          'pre_shoot_preparation_started'
  ),
  1::bigint,
  'Stage 10 rejection preserves exactly one Stage 8 to 9 transition'
);

SELECT * FROM finish();

ROLLBACK;
