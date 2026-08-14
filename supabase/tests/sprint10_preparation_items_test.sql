CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(83);

-- 1
SELECT ok(
  to_regclass('public.booking_preparation_items') IS NOT NULL,
  'booking_preparation_items exists'
);

-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute a
    WHERE a.attrelid =
          to_regclass('public.booking_preparation_items')
      AND a.attnum > 0
      AND NOT a.attisdropped
  ),
  16::bigint,
  'booking_preparation_items has exactly 16 columns'
);

-- 3
SELECT ok(
  COALESCE(
    (
      SELECT c.relrowsecurity
      FROM pg_class c
      WHERE c.oid =
            to_regclass('public.booking_preparation_items')
    ),
    false
  ),
  'booking_preparation_items has RLS enabled'
);

-- 4
SELECT ok(
  COALESCE(
    (
      SELECT c.relforcerowsecurity
      FROM pg_class c
      WHERE c.oid =
            to_regclass('public.booking_preparation_items')
    ),
    false
  ),
  'booking_preparation_items has FORCE RLS enabled'
);

-- 5
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.tablename = 'booking_preparation_items'
  ),
  1::bigint,
  'booking_preparation_items exposes exactly one RLS policy'
);

-- 6
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_preparation_items',
    'SELECT'
  ),
  'authenticated receives preparation-item SELECT'
);

-- 7
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_preparation_items',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_preparation_items',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_preparation_items',
    'DELETE'
  ),
  'authenticated receives no direct preparation-item writes'
);

-- 8
SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.booking_preparation_items',
    'SELECT'
  ),
  'anon receives no preparation-item access'
);

-- 9
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger t
    WHERE t.tgrelid =
          to_regclass('public.booking_preparation_items')
      AND t.tgname =
          'booking_preparation_items_guard'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'preparation-item guard trigger exists exactly once'
);

-- 10
SELECT ok(
  to_regprocedure(
    'public.lsh_preparation_taxonomy_v1(text)'
  ) IS NOT NULL,
  'taxonomy-v1 helper exists'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('maternity')
  ),
  11::bigint,
  'Maternity has exactly 11 checklist items'
);

-- 12
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('newborn')
  ),
  11::bigint,
  'Newborn has exactly 11 checklist items'
);

-- 13
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('sitter')
  ),
  12::bigint,
  'Sitter has exactly 12 checklist items'
);

-- 14
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('maternity') t
    WHERE t.is_required
  ),
  8::bigint,
  'Maternity has exactly 8 required items'
);

-- 15
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('newborn') t
    WHERE t.is_required
  ),
  8::bigint,
  'Newborn has exactly 8 required items'
);

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('sitter') t
    WHERE t.is_required
  ),
  8::bigint,
  'Sitter has exactly 8 required items'
);

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('unsupported')
  ),
  0::bigint,
  'unsupported category has no taxonomy'
);

-- 18
SELECT ok(
  to_regprocedure(
    'public.start_pre_shoot_preparation(uuid)'
  ) IS NOT NULL,
  'start_pre_shoot_preparation exists'
);

-- 19
SELECT ok(
  to_regprocedure(
    'public.update_pre_shoot_preparation_item(uuid,boolean)'
  ) IS NOT NULL,
  'update_pre_shoot_preparation_item exists'
);

-- 20
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.update_pre_shoot_preparation_item(uuid,boolean)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.update_pre_shoot_preparation_item(uuid,boolean)',
    'EXECUTE'
  ),
  'preparation-item update RPC is authenticated-only'
);


-- =====================================================================
-- Fixture A — Maternity preparation checklist + exact Stage 9 replay
-- =====================================================================

INSERT INTO auth.users (id)
VALUES (
  '88000000-0000-0000-0000-000000000001'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '88000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '88000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 10 Checklist Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '88000000-0000-0000-0000-000000000011'::uuid,
  r.id
FROM public.roles r
WHERE r.key = 'founder';

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"88000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '88000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-45678A',
  'Sprint 10 Checklist Maternity Family',
  'Checklist Maternity Family',
  'active',
  '88000000-0000-0000-0000-000000000011',
  '88000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10i_quote_maternity AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '88000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10i_quote_maternity),
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
  (SELECT id FROM s10i_quote_maternity),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10i_quote_maternity),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10i_booking_maternity AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10i_quote_maternity)
);

CREATE TEMP TABLE s10i_schedule_maternity_v1 AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10i_booking_maternity),
  '2030-05-01 10:00:00+05:30'::timestamptz,
  '2030-05-01 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 10 checklist Maternity fixture'
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
  '88000000-0000-0000-0000-000000000011'::uuid
FROM s10i_schedule_maternity_v1;

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
  's10_slice3_test_booking_confirmed',
  now(),
  '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_maternity);

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
    '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_maternity)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

-- 21
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  ),
  'booking_confirmed',
  'Maternity fixture begins at canonical Booking Confirmed'
);

-- 22
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10i_started_maternity AS
  SELECT *
  FROM public.start_pre_shoot_preparation(
    (SELECT id FROM s10i_booking_maternity)
  )
  $$,
  'Maternity booking starts canonical pre-shoot preparation'
);

-- 23
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  ),
  1::bigint,
  'Maternity start creates exactly one authoritative preparation'
);

-- 24
SELECT is(
  (
    SELECT preparation.started_by
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  ),
  '88000000-0000-0000-0000-000000000011'::uuid,
  'Maternity preparation records the authenticated Founder'
);

-- 25
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_maternity)
  ),
  11::bigint,
  'Maternity preparation instantiates exactly 11 checklist items'
);

-- 26
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_maternity)
      AND item.is_required
  ),
  8::bigint,
  'Maternity preparation instantiates exactly 8 required items'
);

-- 27
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_maternity)
      AND item.service_category = 'maternity'
      AND item.taxonomy_version = 1
  ),
  11::bigint,
  'all Maternity checklist rows snapshot category and taxonomy version 1'
);

-- 28
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_maternity)
      AND NOT item.is_satisfied
      AND item.satisfied_at IS NULL
      AND item.satisfied_by IS NULL
  ),
  11::bigint,
  'all Maternity checklist rows begin unsatisfied without satisfaction attribution'
);

-- 29
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1(
      'maternity'
    ) expected
    FULL OUTER JOIN (
      SELECT
        item.item_key,
        item.item_label,
        item.is_required,
        item.sort_order
      FROM public.booking_preparation_items item
      WHERE item.preparation_id =
            (SELECT id FROM s10i_started_maternity)
    ) actual
      ON actual.item_key =
         expected.item_key
    WHERE expected.item_key IS NULL
       OR actual.item_key IS NULL
       OR actual.item_label
            IS DISTINCT FROM
          expected.item_label
       OR actual.is_required
            IS DISTINCT FROM
          expected.is_required
       OR actual.sort_order
            IS DISTINCT FROM
          expected.sort_order
  ),
  0::bigint,
  'Maternity preparation snapshot exactly matches approved taxonomy v1'
);

-- 30
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  ),
  'pre_shoot_preparation',
  'Maternity preparation start advances journey exactly to Stage 9'
);

-- 31
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          (SELECT id FROM s10i_booking_maternity)
      AND transition.transition_key =
          'pre_shoot_preparation_started'
  ),
  1::bigint,
  'Maternity preparation start appends exactly one dedicated transition'
);

-- 32
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
          (SELECT id FROM s10i_booking_maternity)
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
  ),
  1::bigint,
  'Maternity preparation start appends exactly one start audit event'
);

-- 33
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.entity_id =
          (SELECT id FROM s10i_booking_maternity)
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
      AND audit.metadata ->> 'service_category' =
          'maternity'
      AND audit.metadata ->> 'taxonomy_version' =
          '1'
      AND audit.metadata ->> 'preparation_item_count' =
          '11'
  ),
  'Maternity preparation-start audit records category, taxonomy version and item count'
);

CREATE TEMP TABLE s10i_maternity_version_before_replay AS
SELECT js.version
FROM public.booking_journey_states js
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_maternity);

-- 34
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10i_replay_maternity AS
  SELECT *
  FROM public.start_pre_shoot_preparation(
    (SELECT id FROM s10i_booking_maternity)
  )
  $$,
  'exact Maternity Stage 9 replay is idempotent'
);

-- 35
SELECT is(
  (SELECT id FROM s10i_replay_maternity),
  (SELECT id FROM s10i_started_maternity),
  'exact replay returns the same authoritative Maternity preparation'
);

-- 36
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  )
  AND
  (
    SELECT count(*) = 11
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_maternity)
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          (SELECT id FROM s10i_booking_maternity)
      AND transition.transition_key =
          'pre_shoot_preparation_started'
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.entity_id =
          (SELECT id FROM s10i_booking_maternity)
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
  )
  AND
  (
    SELECT js.version =
           (
             SELECT version
             FROM s10i_maternity_version_before_replay
           )
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  ),
  'exact replay creates no preparation, checklist, transition, audit or journey-version duplication'
);



-- =====================================================================
-- Fixture B — Newborn preparation checklist
-- =====================================================================

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
  '88000000-0000-0000-0000-000000000030',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-45678B',
  'Sprint 10 Checklist Newborn Family',
  'Checklist Newborn Family',
  'active',
  '88000000-0000-0000-0000-000000000011',
  '88000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10i_quote_newborn AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '88000000-0000-0000-0000-000000000030',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10i_quote_newborn),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages package
      ON package.organization_id =
         pv.organization_id
     AND package.id =
         pv.package_id
    WHERE package.service_category = 'newborn'
    ORDER BY package.package_key, pv.version_number DESC
    LIMIT 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10i_quote_newborn),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10i_quote_newborn),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10i_booking_newborn AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10i_quote_newborn)
);

CREATE TEMP TABLE s10i_schedule_newborn_v1 AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10i_booking_newborn),
  '2030-05-02 10:00:00+05:30'::timestamptz,
  '2030-05-02 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 10 checklist Newborn fixture'
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
  '88000000-0000-0000-0000-000000000011'::uuid
FROM s10i_schedule_newborn_v1;

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
  's10_slice3_test_booking_confirmed',
  now(),
  '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_newborn);

UPDATE public.booking_journey_states js
SET
  current_stage_id = target.id,
  stage_entered_at = now(),
  version = js.version + 1,
  updated_at = now(),
  updated_by =
    '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_newborn)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

-- 37
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10i_started_newborn AS
  SELECT *
  FROM public.start_pre_shoot_preparation(
    (SELECT id FROM s10i_booking_newborn)
  )
  $$,
  'Newborn booking starts canonical preparation'
);

-- 38
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_newborn)
  ),
  11::bigint,
  'Newborn preparation instantiates exactly 11 checklist items'
);

-- 39
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_newborn)
      AND item.service_category = 'newborn'
      AND item.taxonomy_version = 1
  ),
  11::bigint,
  'all Newborn checklist rows snapshot Newborn taxonomy v1'
);

-- 40
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('newborn') expected
    FULL OUTER JOIN (
      SELECT
        item.item_key,
        item.item_label,
        item.is_required,
        item.sort_order
      FROM public.booking_preparation_items item
      WHERE item.preparation_id =
            (SELECT id FROM s10i_started_newborn)
    ) actual
      ON actual.item_key = expected.item_key
    WHERE expected.item_key IS NULL
       OR actual.item_key IS NULL
       OR actual.item_label
            IS DISTINCT FROM expected.item_label
       OR actual.is_required
            IS DISTINCT FROM expected.is_required
       OR actual.sort_order
            IS DISTINCT FROM expected.sort_order
  ),
  0::bigint,
  'Newborn preparation snapshot exactly matches approved taxonomy v1'
);

-- 41
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_newborn)
  ),
  'pre_shoot_preparation',
  'Newborn preparation advances exactly to Stage 9'
);

-- =====================================================================
-- Fixture C — Sitter preparation checklist
-- =====================================================================

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
  '88000000-0000-0000-0000-000000000040',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-45678C',
  'Sprint 10 Checklist Sitter Family',
  'Checklist Sitter Family',
  'active',
  '88000000-0000-0000-0000-000000000011',
  '88000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10i_quote_sitter AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '88000000-0000-0000-0000-000000000040',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10i_quote_sitter),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages package
      ON package.organization_id =
         pv.organization_id
     AND package.id =
         pv.package_id
    WHERE package.service_category = 'sitter'
    ORDER BY package.package_key, pv.version_number DESC
    LIMIT 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10i_quote_sitter),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10i_quote_sitter),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10i_booking_sitter AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10i_quote_sitter)
);

CREATE TEMP TABLE s10i_schedule_sitter_v1 AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10i_booking_sitter),
  '2030-05-03 10:00:00+05:30'::timestamptz,
  '2030-05-03 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 10 checklist Sitter fixture'
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
  '88000000-0000-0000-0000-000000000011'::uuid
FROM s10i_schedule_sitter_v1;

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
  's10_slice3_test_booking_confirmed',
  now(),
  '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_sitter);

UPDATE public.booking_journey_states js
SET
  current_stage_id = target.id,
  stage_entered_at = now(),
  version = js.version + 1,
  updated_at = now(),
  updated_by =
    '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_sitter)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

-- 42
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10i_started_sitter AS
  SELECT *
  FROM public.start_pre_shoot_preparation(
    (SELECT id FROM s10i_booking_sitter)
  )
  $$,
  'Sitter booking starts canonical preparation'
);

-- 43
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_sitter)
  ),
  12::bigint,
  'Sitter preparation instantiates exactly 12 checklist items'
);

-- 44
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_sitter)
      AND item.service_category = 'sitter'
      AND item.taxonomy_version = 1
  ),
  12::bigint,
  'all Sitter checklist rows snapshot Sitter taxonomy v1'
);

-- 45
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.lsh_preparation_taxonomy_v1('sitter') expected
    FULL OUTER JOIN (
      SELECT
        item.item_key,
        item.item_label,
        item.is_required,
        item.sort_order
      FROM public.booking_preparation_items item
      WHERE item.preparation_id =
            (SELECT id FROM s10i_started_sitter)
    ) actual
      ON actual.item_key = expected.item_key
    WHERE expected.item_key IS NULL
       OR actual.item_key IS NULL
       OR actual.item_label
            IS DISTINCT FROM expected.item_label
       OR actual.is_required
            IS DISTINCT FROM expected.is_required
       OR actual.sort_order
            IS DISTINCT FROM expected.sort_order
  ),
  0::bigint,
  'Sitter preparation snapshot exactly matches approved taxonomy v1'
);

-- 46
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_sitter)
  ),
  'pre_shoot_preparation',
  'Sitter preparation advances exactly to Stage 9'
);



-- =====================================================================
-- Part 3A — Preparation item mutation + same-state idempotency
-- =====================================================================

CREATE TEMP TABLE s10i_mutation_target AS
SELECT
  item.id,
  item.preparation_id,
  item.item_key
FROM public.booking_preparation_items item
WHERE item.preparation_id =
      (SELECT id FROM s10i_started_maternity)
  AND item.item_key =
      'session_brief_reviewed';

CREATE TEMP TABLE s10i_mutation_journey_before AS
SELECT
  js.current_stage_id,
  js.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          js.booking_id
  ) AS transition_count
FROM public.booking_journey_states js
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_maternity);

-- 47
SELECT ok(
  (
    SELECT count(*) = 1
    FROM s10i_mutation_target
  )
  AND
  (
    SELECT NOT item.is_satisfied
           AND item.satisfied_at IS NULL
           AND item.satisfied_by IS NULL
    FROM public.booking_preparation_items item
    WHERE item.id =
          (SELECT id FROM s10i_mutation_target)
  ),
  'mutation target exists exactly once and begins unsatisfied'
);

-- 48
SELECT lives_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_mutation_target),
    true
  )
  $$,
  'false to true preparation-item mutation succeeds at exact Stage 9'
);

-- 49
SELECT ok(
  (
    SELECT
      item.is_satisfied
      AND item.satisfied_at IS NOT NULL
      AND item.satisfied_by =
          '88000000-0000-0000-0000-000000000011'::uuid
      AND item.updated_by =
          '88000000-0000-0000-0000-000000000011'::uuid
    FROM public.booking_preparation_items item
    WHERE item.id =
          (SELECT id FROM s10i_mutation_target)
  ),
  'false to true records satisfaction timestamp and authenticated member attribution'
);

-- 50
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_type =
          'booking_preparation_item'
      AND audit.entity_id =
          (SELECT id FROM s10i_mutation_target)
  ),
  1::bigint,
  'first real satisfaction change appends exactly one item audit event'
);

-- 51
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          (SELECT id FROM s10i_mutation_target)
      AND audit.is_sensitive = false
      AND audit.old_values ->> 'is_satisfied' =
          'false'
      AND audit.new_values ->> 'is_satisfied' =
          'true'
      AND audit.metadata ->> 'booking_id' =
          (SELECT id::text FROM s10i_booking_maternity)
      AND audit.metadata ->> 'preparation_id' =
          (SELECT preparation_id::text FROM s10i_mutation_target)
      AND audit.metadata ->> 'item_key' =
          'session_brief_reviewed'
      AND audit.metadata ->> 'service_category' =
          'maternity'
      AND audit.metadata ->> 'taxonomy_version' =
          '1'
      AND audit.metadata ->> 'is_required' =
          'true'
  ),
  'first item audit records old/new state and frozen identification metadata'
);

-- 52
SELECT ok(
  (
    SELECT js.current_stage_id =
           before.current_stage_id
       AND js.version =
           before.version
    FROM public.booking_journey_states js
    CROSS JOIN s10i_mutation_journey_before before
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  ),
  'false to true checklist mutation does not move or version the journey'
);

CREATE TEMP TABLE s10i_before_same_state_replay AS
SELECT
  item.ctid::text AS tuple_id,
  item.updated_at,
  item.updated_by,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          item.id
  ) AS audit_count
FROM public.booking_preparation_items item
WHERE item.id =
      (SELECT id FROM s10i_mutation_target);

-- 53
SELECT lives_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_mutation_target),
    true
  )
  $$,
  'authorized true to true retry succeeds as an idempotent replay'
);

-- 54
SELECT ok(
  (
    SELECT
      item.ctid::text =
        before.tuple_id
      AND item.updated_at =
        before.updated_at
      AND item.updated_by =
        before.updated_by
    FROM public.booking_preparation_items item
    CROSS JOIN s10i_before_same_state_replay before
    WHERE item.id =
          (SELECT id FROM s10i_mutation_target)
  ),
  'same-state retry performs no row UPDATE or attribution churn'
);

-- 55
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          (SELECT id FROM s10i_mutation_target)
  ),
  (
    SELECT audit_count
    FROM s10i_before_same_state_replay
  ),
  'same-state retry appends no duplicate audit event'
);

-- 56
SELECT lives_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_mutation_target),
    false
  )
  $$,
  'true to false preparation-item mutation succeeds at exact Stage 9'
);

-- 57
SELECT ok(
  (
    SELECT
      NOT item.is_satisfied
      AND item.satisfied_at IS NULL
      AND item.satisfied_by IS NULL
      AND item.updated_by =
          '88000000-0000-0000-0000-000000000011'::uuid
    FROM public.booking_preparation_items item
    WHERE item.id =
          (SELECT id FROM s10i_mutation_target)
  )
  AND
  (
    SELECT count(*) = 2
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          (SELECT id FROM s10i_mutation_target)
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          (SELECT id FROM s10i_mutation_target)
      AND audit.old_values ->> 'is_satisfied' =
          'true'
      AND audit.new_values ->> 'is_satisfied' =
          'false'
  ),
  'true to false clears satisfaction attribution and appends exactly one real-change audit'
);

-- 58
SELECT ok(
  (
    SELECT
      js.current_stage_id =
        before.current_stage_id
      AND js.version =
        before.version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition
        WHERE transition.booking_id =
              js.booking_id
      ) =
        before.transition_count
    FROM public.booking_journey_states js
    CROSS JOIN s10i_mutation_journey_before before
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  ),
  'all checklist mutations leave journey stage, version and transition history unchanged'
);



-- =====================================================================
-- Part 3B — Mutation denial boundaries
-- =====================================================================

-- ---------------------------------------------------------------------
-- Active organization member without prep.write.
-- Photographer is intentionally outside the frozen prep-write grant set.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES (
  '88000000-0000-0000-0000-000000000002'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '88000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '88000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 10 Checklist Photographer'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '88000000-0000-0000-0000-000000000012'::uuid,
  role.id
FROM public.roles role
WHERE role.key = 'photographer';

CREATE TEMP TABLE s10i_denial_maternity_before AS
SELECT
  item.is_satisfied,
  item.satisfied_at,
  item.satisfied_by,
  item.updated_at,
  item.updated_by,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          item.id
  ) AS audit_count
FROM public.booking_preparation_items item
WHERE item.id =
      (SELECT id FROM s10i_mutation_target);

SELECT set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"88000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 59
SELECT throws_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_mutation_target),
    true
  )
  $$,
  '42501',
  'update_pre_shoot_preparation_item: prep.write permission required',
  'active member without prep.write cannot mutate a preparation item'
);

-- 60
SELECT ok(
  (
    SELECT
      item.is_satisfied =
        before.is_satisfied
      AND item.satisfied_at
            IS NOT DISTINCT FROM
          before.satisfied_at
      AND item.satisfied_by
            IS NOT DISTINCT FROM
          before.satisfied_by
      AND item.updated_at =
          before.updated_at
      AND item.updated_by =
          before.updated_by
    FROM public.booking_preparation_items item
    CROSS JOIN s10i_denial_maternity_before before
    WHERE item.id =
          (SELECT id FROM s10i_mutation_target)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          (SELECT id FROM s10i_mutation_target)
  ) =
  (
    SELECT before.audit_count
    FROM s10i_denial_maternity_before before
  ),
  'missing prep.write failure leaves preparation-item evidence and audit cardinality unchanged'
);

-- Restore Founder identity.
SELECT set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"88000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Exact Stage 9 gate.
-- Move the already-proven Newborn fixture to Stage 8 using test-owner
-- setup, then prove the public item RPC refuses to mutate it.
-- ---------------------------------------------------------------------

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
    '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_newborn)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

CREATE TEMP TABLE s10i_newborn_denial_target AS
SELECT item.id
FROM public.booking_preparation_items item
WHERE item.preparation_id =
      (SELECT id FROM s10i_started_newborn)
  AND item.item_key =
      'session_brief_reviewed';

CREATE TEMP TABLE s10i_newborn_denial_before AS
SELECT
  item.is_satisfied,
  item.satisfied_at,
  item.satisfied_by,
  item.updated_at,
  item.updated_by,
  js.current_stage_id,
  js.version,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          item.id
  ) AS audit_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          js.booking_id
  ) AS transition_count
FROM public.booking_preparation_items item
JOIN public.booking_preparations preparation
  ON preparation.organization_id =
     item.organization_id
 AND preparation.id =
     item.preparation_id
JOIN public.booking_journey_states js
  ON js.organization_id =
     preparation.organization_id
 AND js.booking_id =
     preparation.booking_id
WHERE item.id =
      (SELECT id FROM s10i_newborn_denial_target);

-- 61
SELECT throws_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_newborn_denial_target),
    true
  )
  $$,
  '22023',
  'update_pre_shoot_preparation_item: booking must be exactly Pre-Shoot Preparation',
  'preparation item cannot be mutated outside exact Stage 9'
);

-- 62
SELECT ok(
  (
    SELECT
      item.is_satisfied =
        before.is_satisfied
      AND item.satisfied_at
            IS NOT DISTINCT FROM
          before.satisfied_at
      AND item.satisfied_by
            IS NOT DISTINCT FROM
          before.satisfied_by
      AND item.updated_at =
          before.updated_at
      AND item.updated_by =
          before.updated_by
      AND js.current_stage_id =
          before.current_stage_id
      AND js.version =
          before.version
      AND (
        SELECT count(*)::bigint
        FROM public.audit_events audit
        WHERE audit.action_key =
              'booking.preparation_item_updated'
          AND audit.entity_id =
              item.id
      ) =
          before.audit_count
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition
        WHERE transition.booking_id =
              js.booking_id
      ) =
          before.transition_count
    FROM public.booking_preparation_items item
    JOIN public.booking_preparations preparation
      ON preparation.organization_id =
         item.organization_id
     AND preparation.id =
         item.preparation_id
    JOIN public.booking_journey_states js
      ON js.organization_id =
         preparation.organization_id
     AND js.booking_id =
         preparation.booking_id
    CROSS JOIN s10i_newborn_denial_before before
    WHERE item.id =
          (SELECT id FROM s10i_newborn_denial_target)
  ),
  'wrong-stage failure leaves item, audit and journey evidence unchanged'
);

-- ---------------------------------------------------------------------
-- Runtime authenticated direct-write denial.
-- These prove the ACL boundary, rather than only inspecting privileges.
-- ---------------------------------------------------------------------

SET LOCAL ROLE authenticated;

-- 63
SELECT throws_ok(
  $$
  INSERT INTO public.booking_preparation_items
  DEFAULT VALUES
  $$,
  '42501',
  'permission denied for table booking_preparation_items',
  'authenticated direct INSERT into preparation items is denied'
);

-- 64
SELECT throws_ok(
  $$
  UPDATE public.booking_preparation_items
  SET updated_at = now()
  WHERE false
  $$,
  '42501',
  'permission denied for table booking_preparation_items',
  'authenticated direct UPDATE of preparation items is denied'
);

-- 65
SELECT throws_ok(
  $$
  DELETE FROM public.booking_preparation_items
  WHERE false
  $$,
  '42501',
  'permission denied for table booking_preparation_items',
  'authenticated direct DELETE of preparation items is denied'
);

RESET ROLE;

-- 66
SELECT ok(
  (
    SELECT stage.stage_key =
           'pre_shoot_preparation'
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_maternity)
  )
  AND
  (
    SELECT stage.stage_key =
           'booking_confirmed'
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_newborn)
  ),
  'all denied mutation attempts leave authoritative journey stages unchanged'
);



-- =====================================================================
-- Part 4A — Stage 9 replay structural integrity
-- =====================================================================

CREATE TEMP TABLE s10i_sitter_replay_item AS
SELECT item.id
FROM public.booking_preparation_items item
WHERE item.preparation_id =
      (SELECT id FROM s10i_started_sitter)
  AND item.item_key =
      'special_requests_reviewed';

-- 67
SELECT lives_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_sitter_replay_item),
    true
  )
  $$,
  'Sitter checklist satisfaction may legitimately differ before Stage 9 replay'
);

-- 68
SELECT lives_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10i_booking_sitter)
  )
  $$,
  'Stage 9 replay ignores mutable satisfaction state when structure remains exact'
);

-- 69
SELECT ok(
  (
    SELECT item.is_satisfied
    FROM public.booking_preparation_items item
    WHERE item.id =
          (SELECT id FROM s10i_sitter_replay_item)
  )
  AND
  (
    SELECT count(*) = 12
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_sitter)
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_sitter)
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          (SELECT id FROM s10i_booking_sitter)
      AND transition.transition_key =
          'pre_shoot_preparation_started'
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.audit_events audit
    WHERE audit.entity_id =
          (SELECT id FROM s10i_booking_sitter)
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
  ),
  'valid replay preserves satisfaction while creating no preparation, item, transition or start-audit duplication'
);

CREATE TEMP TABLE s10i_sitter_before_corrupt_replay AS
SELECT
  js.current_stage_id,
  js.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          js.booking_id
  ) AS preparation_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          js.booking_id
      AND transition.transition_key =
          'pre_shoot_preparation_started'
  ) AS transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
          js.booking_id
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
  ) AS start_audit_count
FROM public.booking_journey_states js
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_sitter);

-- Test-owner corruption only: bypass the immutable guard to simulate
-- a damaged historical checklist snapshot.
ALTER TABLE public.booking_preparation_items
  DISABLE TRIGGER booking_preparation_items_guard;

DELETE FROM public.booking_preparation_items item
WHERE item.preparation_id =
      (SELECT id FROM s10i_started_sitter)
  AND item.item_key =
      'sitter_theme_palette_reviewed';

ALTER TABLE public.booking_preparation_items
  ENABLE TRIGGER booking_preparation_items_guard;

-- 70
SELECT ok(
  (
    SELECT count(*) = 11
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_sitter)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_sitter)
      AND item.item_key =
          'sitter_theme_palette_reviewed'
  ),
  'test-owner corruption removes exactly one structural taxonomy row'
);

-- 71
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10i_booking_sitter)
  )
  $$,
  'P0001',
  'start_pre_shoot_preparation: Stage 9 preparation checklist structure is invalid',
  'Stage 9 replay fails closed when the authoritative checklist structure is incomplete'
);

-- 72
SELECT ok(
  (
    SELECT count(*) = 11
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_sitter)
  )
  AND
  (
    SELECT
      js.current_stage_id =
        before.current_stage_id
      AND js.version =
        before.version
    FROM public.booking_journey_states js
    CROSS JOIN s10i_sitter_before_corrupt_replay before
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_sitter)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_sitter)
  ) =
  (
    SELECT preparation_count
    FROM s10i_sitter_before_corrupt_replay
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          (SELECT id FROM s10i_booking_sitter)
      AND transition.transition_key =
          'pre_shoot_preparation_started'
  ) =
  (
    SELECT transition_count
    FROM s10i_sitter_before_corrupt_replay
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
          (SELECT id FROM s10i_booking_sitter)
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
  ) =
  (
    SELECT start_audit_count
    FROM s10i_sitter_before_corrupt_replay
  ),
  'failed structural replay performs no repair, journey movement, preparation duplication, transition or audit'
);



-- =====================================================================
-- Part 4B — Atomic checklist-instantiation failure
-- =====================================================================

-- Fresh supported-category booking used only for rollback proof.
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
  '88000000-0000-0000-0000-000000000050',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-45678D',
  'Sprint 10 Atomic Failure Family',
  'Atomic Failure Family',
  'active',
  '88000000-0000-0000-0000-000000000011',
  '88000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10i_quote_atomic_failure AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '88000000-0000-0000-0000-000000000050',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10i_quote_atomic_failure),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages package
      ON package.organization_id =
         pv.organization_id
     AND package.id =
         pv.package_id
    WHERE package.service_category = 'maternity'
    ORDER BY package.package_key, pv.version_number DESC
    LIMIT 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10i_quote_atomic_failure),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10i_quote_atomic_failure),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10i_booking_atomic_failure AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10i_quote_atomic_failure)
);

CREATE TEMP TABLE s10i_schedule_atomic_failure_v1 AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s10i_booking_atomic_failure),
  '2030-05-04 10:00:00+05:30'::timestamptz,
  '2030-05-04 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 10 atomic checklist failure fixture'
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
  '88000000-0000-0000-0000-000000000011'::uuid
FROM s10i_schedule_atomic_failure_v1;

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
  's10_slice3_test_booking_confirmed',
  now(),
  '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_atomic_failure);

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
    '88000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_atomic_failure)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

CREATE TEMP TABLE s10i_atomic_failure_before AS
SELECT
  js.current_stage_id,
  js.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          js.booking_id
  ) AS preparation_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          js.booking_id
      AND transition.transition_key =
          'pre_shoot_preparation_started'
  ) AS transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
          js.booking_id
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
  ) AS start_audit_count
FROM public.booking_journey_states js
WHERE js.booking_id =
      (SELECT id FROM s10i_booking_atomic_failure);

-- 73
SELECT ok(
  (
    SELECT stage.stage_key =
           'booking_confirmed'
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_atomic_failure)
  )
  AND
  (
    SELECT count(*) = 0
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_atomic_failure)
  ),
  'atomic-failure fixture begins at Stage 8 with no preparation evidence'
);

-- Test-only fault injector.
-- start_pre_shoot_preparation creates booking_preparations first, so this
-- exception proves the whole RPC transaction rolls that earlier INSERT back.
CREATE OR REPLACE FUNCTION public.s10i_force_checklist_instantiation_failure()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.item_key = 'session_brief_reviewed' THEN
    RAISE EXCEPTION
      's10i forced checklist instantiation failure'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER a_s10i_force_checklist_instantiation_failure
  BEFORE INSERT
  ON public.booking_preparation_items
  FOR EACH ROW
  EXECUTE FUNCTION public.s10i_force_checklist_instantiation_failure();

-- 74
SELECT throws_ok(
  $$
  SELECT public.start_pre_shoot_preparation(
    (SELECT id FROM s10i_booking_atomic_failure)
  )
  $$,
  'P0001',
  's10i forced checklist instantiation failure',
  'failure during checklist instantiation aborts preparation start'
);

DROP TRIGGER a_s10i_force_checklist_instantiation_failure
ON public.booking_preparation_items;

DROP FUNCTION public.s10i_force_checklist_instantiation_failure();

-- 75
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparations preparation
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_atomic_failure)
  ) =
  (
    SELECT preparation_count
    FROM s10i_atomic_failure_before
  )
  AND
  (
    SELECT count(*) = 0
    FROM public.booking_preparation_items item
    JOIN public.booking_preparations preparation
      ON preparation.organization_id =
         item.organization_id
     AND preparation.id =
         item.preparation_id
    WHERE preparation.booking_id =
          (SELECT id FROM s10i_booking_atomic_failure)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition
    WHERE transition.booking_id =
          (SELECT id FROM s10i_booking_atomic_failure)
      AND transition.transition_key =
          'pre_shoot_preparation_started'
  ) =
  (
    SELECT transition_count
    FROM s10i_atomic_failure_before
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
          (SELECT id FROM s10i_booking_atomic_failure)
      AND audit.action_key =
          'booking.pre_shoot_preparation_started'
  ) =
  (
    SELECT start_audit_count
    FROM s10i_atomic_failure_before
  ),
  'failed checklist instantiation leaves no preparation, items, transition or start-audit evidence'
);

-- 76
SELECT ok(
  (
    SELECT
      js.current_stage_id =
        before.current_stage_id
      AND js.version =
        before.version
    FROM public.booking_journey_states js
    CROSS JOIN s10i_atomic_failure_before before
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_atomic_failure)
  )
  AND
  (
    SELECT stage.stage_key =
           'booking_confirmed'
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         js.organization_id
     AND stage.id =
         js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s10i_booking_atomic_failure)
  ),
  'failed checklist instantiation leaves journey stage and version unchanged'
);



-- =====================================================================
-- Part 4C — Organization and branch isolation
-- =====================================================================

-- Snapshot the canonical NULL-branch Maternity item before all probes.
CREATE TEMP TABLE s10i_isolation_target_before AS
SELECT
  item.is_satisfied,
  item.satisfied_at,
  item.satisfied_by,
  item.updated_at,
  item.updated_by,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          item.id
  ) AS audit_count
FROM public.booking_preparation_items item
WHERE item.id =
      (SELECT id FROM s10i_mutation_target);

-- ---------------------------------------------------------------------
-- Branch isolation:
-- a branch-scoped Client Coordinator has prep.read/prep.write in its
-- granted branch but must not inherit organization-wide NULL-branch scope.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES (
  '88000000-0000-0000-0000-000000000003'::uuid
);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  country_code
)
VALUES (
  '88000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'Sprint 10 Isolation Branch',
  's10a',
  'active',
  'IN'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '88000000-0000-0000-0000-000000000013',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '88000000-0000-0000-0000-000000000003',
  'active',
  'Sprint 10 Branch Coordinator'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '88000000-0000-0000-0000-000000000013'::uuid,
  role.id,
  '88000000-0000-0000-0000-000000000101'::uuid
FROM public.roles role
WHERE role.key =
      'client_coordinator';

SELECT set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"88000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

-- 77
SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'prep.read',
    '88000000-0000-0000-0000-000000000101'
  )
  AND
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'prep.write',
    '88000000-0000-0000-0000-000000000101'
  )
  AND NOT
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'prep.read',
    NULL
  )
  AND NOT
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'prep.write',
    NULL
  ),
  'branch-scoped coordinator has preparation permissions only inside the granted branch'
);

-- Test-fixture lookup only. The authenticated SQL role must be able to
-- resolve the temporary preparation id while the public table itself
-- remains governed by its real RLS policy.
GRANT SELECT
ON s10i_started_maternity
TO authenticated;

SET LOCAL ROLE authenticated;

-- 78
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.preparation_id =
          (SELECT id FROM s10i_started_maternity)
  ),
  0::bigint,
  'branch-scoped coordinator cannot read NULL-branch Maternity preparation items'
);

RESET ROLE;

-- 79
SELECT throws_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_mutation_target),
    true
  )
  $$,
  '42501',
  'update_pre_shoot_preparation_item: prep.write permission required',
  'branch-scoped coordinator cannot mutate a NULL-branch preparation item'
);

-- ---------------------------------------------------------------------
-- Organization isolation:
-- create a real second active organization and Founder membership.
-- That Founder has prep permissions in the foreign organization only.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES (
  '88000000-0000-0000-0000-000000000004'::uuid
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
  '88000000-0000-0000-0000-000000000201',
  'Sprint 10 Foreign Isolation Studio',
  'sprint-10-foreign-isolation-studio',
  'suspended',
  'INR',
  'Asia/Kolkata',
  'S10X'
);

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '88000000-0000-0000-0000-000000000201'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '88000000-0000-0000-0000-000000000014',
  '88000000-0000-0000-0000-000000000201',
  '88000000-0000-0000-0000-000000000004',
  'active',
  'Sprint 10 Foreign Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '88000000-0000-0000-0000-000000000201'::uuid,
  '88000000-0000-0000-0000-000000000014'::uuid,
  role.id,
  NULL
FROM public.roles role
WHERE role.key = 'founder';

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '88000000-0000-0000-0000-000000000201'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000004',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"88000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

-- 80
SELECT ok(
  public.has_permission(
    '88000000-0000-0000-0000-000000000201',
    'prep.read',
    NULL
  )
  AND
  public.has_permission(
    '88000000-0000-0000-0000-000000000201',
    'prep.write',
    NULL
  )
  AND NOT
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'prep.read',
    NULL
  )
  AND NOT
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'prep.write',
    NULL
  ),
  'foreign Founder preparation permissions do not cross organization boundaries'
);

SET LOCAL ROLE authenticated;

-- 81
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_preparation_items item
    WHERE item.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
  ),
  0::bigint,
  'foreign-organization Founder cannot read canonical organization preparation items'
);

RESET ROLE;

-- 82
SELECT throws_ok(
  $$
  SELECT public.update_pre_shoot_preparation_item(
    (SELECT id FROM s10i_mutation_target),
    true
  )
  $$,
  '42501',
  'update_pre_shoot_preparation_item: active organization membership required',
  'foreign-organization Founder cannot mutate canonical organization preparation evidence'
);

-- Restore canonical Founder identity for final verification.
SELECT set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"88000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 83
SELECT ok(
  (
    SELECT
      item.is_satisfied =
        before.is_satisfied
      AND item.satisfied_at
            IS NOT DISTINCT FROM
          before.satisfied_at
      AND item.satisfied_by
            IS NOT DISTINCT FROM
          before.satisfied_by
      AND item.updated_at =
          before.updated_at
      AND item.updated_by =
          before.updated_by
    FROM public.booking_preparation_items item
    CROSS JOIN s10i_isolation_target_before before
    WHERE item.id =
          (SELECT id FROM s10i_mutation_target)
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.preparation_item_updated'
      AND audit.entity_id =
          (SELECT id FROM s10i_mutation_target)
  ) =
  (
    SELECT audit_count
    FROM s10i_isolation_target_before
  ),
  'branch and organization isolation failures leave preparation evidence and audit history unchanged'
);


SELECT * FROM finish();

ROLLBACK;
