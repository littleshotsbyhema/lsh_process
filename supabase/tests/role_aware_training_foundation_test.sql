CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(78);

-- =====================================================================
-- Little Moments OS
-- T1 Role-Aware Training Foundation
-- Dedicated adversarial pgTAP
--
-- All fixtures and training activity are transaction-local.
-- ROLLBACK removes every test mutation.
-- =====================================================================


-- =====================================================================
-- Helper: execute a statement and prove that it is denied.
-- =====================================================================

CREATE FUNCTION pg_temp.t1_denied(
  p_sql text,
  p_expected_fragment text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $function$
BEGIN
  EXECUTE p_sql;

  RETURN false;

EXCEPTION
  WHEN OTHERS THEN
    RETURN
      p_expected_fragment IS NULL
      OR position(
        lower(p_expected_fragment)
        IN lower(SQLERRM)
      ) > 0;
END
$function$;


-- =====================================================================
-- Part 1 — Structural foundation
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'organization_training_settings',
        'training_modules',
        'training_module_steps',
        'member_training_profiles',
        'training_scenario_instances',
        'training_step_events'
      )
      AND c.relkind = 'r'
  ),
  6::bigint,
  'all six T1 training tables exist'
);

-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_type t
    JOIN pg_catalog.pg_namespace n
      ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname IN (
        'training_gate_mode',
        'training_profile_status',
        'training_scenario_status',
        'training_step_type',
        'training_step_event_type',
        'training_step_event_result'
      )
  ),
  6::bigint,
  'all six T1 training enum types exist'
);

-- 3
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'organization_training_settings',
        'training_modules',
        'training_module_steps',
        'member_training_profiles',
        'training_scenario_instances',
        'training_step_events'
      )
      AND c.relrowsecurity
      AND c.relforcerowsecurity
  ),
  6::bigint,
  'all training tables have ENABLE RLS and FORCE RLS'
);

-- 4
SELECT ok(
  (
    SELECT
      ots.gate_mode = 'off'::public.training_gate_mode
      AND ots.first_job_assist_count = 3
    FROM public.organization_training_settings ots
    WHERE ots.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  'LSH training gate defaults OFF with three first-job assists'
);

-- 5
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_modules tm
    WHERE tm.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key = 'common-orientation'
      AND tm.version = 1
      AND tm.role_id IS NULL
      AND tm.required
      AND tm.active
      AND tm.minimum_score = 100
  ),
  1::bigint,
  'common orientation v1 exists exactly once'
);

-- 6
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_module_steps tms
    JOIN public.training_modules tm
      ON tm.id = tms.training_module_id
    WHERE tm.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key = 'common-orientation'
      AND tm.version = 1
      AND tms.required
  ),
  7::bigint,
  'common orientation has exactly seven required steps'
);

-- 7
SELECT ok(
  (
    SELECT p.requires_server_enforcement
    FROM public.permissions p
    WHERE p.key = 'training.read'
  ),
  'training.read exists and requires server enforcement'
);

-- 8
SELECT is(
  (
    SELECT string_agg(r.key, ',' ORDER BY r.key)
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE p.key = 'training.read'
  ),
  'founder',
  'training.read belongs only to Founder'
);

-- 9
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid =
      to_regclass('public.training_step_events')
      AND t.tgname =
        'training_step_events_immutable'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'immutable training evidence trigger exists exactly once'
);

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_constraint c
    WHERE c.conrelid =
      to_regclass('public.training_scenario_instances')
      AND c.contype = 'f'
      AND c.confrelid IN (
        to_regclass('public.leads'),
        to_regclass('public.families'),
        to_regclass('public.quotations'),
        to_regclass('public.bookings'),
        to_regclass('public.booking_payment_requirements'),
        to_regclass('public.booking_payments'),
        to_regclass('public.booking_journey_states'),
        to_regclass('public.booking_selected_images')
      )
  ),
  0::bigint,
  'training scenarios have no foreign keys into real client/domain state'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM (
      VALUES
        ('organization_training_settings'),
        ('training_modules'),
        ('training_module_steps'),
        ('member_training_profiles'),
        ('training_scenario_instances'),
        ('training_step_events')
    ) AS x(table_name)
    WHERE
      has_table_privilege(
        'authenticated',
        format('public.%I', x.table_name),
        'SELECT'
      )
      OR
      has_table_privilege(
        'authenticated',
        format('public.%I', x.table_name),
        'INSERT'
      )
      OR
      has_table_privilege(
        'authenticated',
        format('public.%I', x.table_name),
        'UPDATE'
      )
      OR
      has_table_privilege(
        'authenticated',
        format('public.%I', x.table_name),
        'DELETE'
      )
  ),
  0::bigint,
  'authenticated has no direct training-table privileges'
);

-- 12
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.my_training_context(uuid)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.start_my_training_module(uuid,text,integer)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.record_my_training_step(uuid,text,integer,text,public.training_step_event_type,public.training_step_event_result,jsonb)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.complete_my_training_module(uuid,text,integer)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.training_directory(uuid)',
    'EXECUTE'
  ),
  'authenticated has only the controlled T1 RPC execution surface'
);

-- 13
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.my_training_context(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.start_my_training_module(uuid,text,integer)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.record_my_training_step(uuid,text,integer,text,public.training_step_event_type,public.training_step_event_result,jsonb)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.complete_my_training_module(uuid,text,integer)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.training_directory(uuid)',
    'EXECUTE'
  ),
  'anon cannot execute any T1 training RPC'
);

-- 14
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.my_training_context(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.start_my_training_module(uuid,text,integer)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.record_my_training_step(uuid,text,integer,text,public.training_step_event_type,public.training_step_event_result,jsonb)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.complete_my_training_module(uuid,text,integer)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.training_directory(uuid)',
    'EXECUTE'
  ),
  'service_role has no user-facing T1 training RPC execution grant'
);


-- =====================================================================
-- Part 2 — Canonical Founder fixture
-- =====================================================================

INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at
)
VALUES (
  'b1000000-0000-4000-8000-000000000001'::uuid,
  't1-founder@lsh.test',
  now()
);

SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

SELECT *
FROM public.lsh_bootstrap_canonical_founder(
  'b1000000-0000-4000-8000-000000000001'::uuid,
  't1-founder@lsh.test'
);

RESET ROLE;

-- 15
SELECT ok(
  (
    SELECT o.status = 'active'::public.organization_status
    FROM public.organizations o
    WHERE o.id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    WHERE g.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND r.key = 'founder'
      AND g.branch_id IS NULL
      AND g.revoked_at IS NULL
  ) = 1::bigint,
  'canonical bootstrap activates LSH and establishes Founder authority'
);

SELECT set_config(
  't1.jp_id',
  (
    SELECT id::text
    FROM public.branches
    WHERE organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND code = 'bengaluru-jp-nagar'
  ),
  true
);

SELECT set_config(
  't1.erode_id',
  (
    SELECT id::text
    FROM public.branches
    WHERE organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND code = 'erode'
  ),
  true
);


-- Founder authenticated context.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  1::bigint,
  'Founder receives the common-orientation training context'
);

-- 17
SELECT ok(
  (
    SELECT
      assigned_role_keys @> ARRAY['founder']::text[]
      AND organization_wide
      AND gate_mode = 'off'::public.training_gate_mode
      AND module_key = 'common-orientation'
      AND training_status =
          'not_started'::public.training_profile_status
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'Founder context derives real role authority and safe gate state'
);

-- 18
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  1::bigint,
  'Founder can read the training directory'
);

RESET ROLE;


-- =====================================================================
-- Part 3 — Branch-scoped Photographer fixture
-- =====================================================================

INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at
)
VALUES (
  'b1000000-0000-4000-8000-000000000002'::uuid,
  't1-photographer@lsh.test',
  now()
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  email
)
VALUES (
  'b1000000-0000-4000-8000-000000000012'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-4000-8000-000000000002'::uuid,
  'active'::public.member_status,
  'T1 Photographer',
  't1-photographer@lsh.test'
);

-- Founder grants exact JP Nagar Photographer authority.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

SELECT public.grant_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-4000-8000-000000000012'::uuid,
  'photographer',
  current_setting('t1.jp_id')::uuid
);

RESET ROLE;

-- 19
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id = g.organization_id
    WHERE g.organization_member_id =
      'b1000000-0000-4000-8000-000000000012'::uuid
      AND r.key = 'photographer'
      AND b.code = 'bengaluru-jp-nagar'
      AND g.revoked_at IS NULL
  ),
  'Photographer fixture has exactly one JP Nagar role grant'
);


-- Snapshot real authorization and domain state after fixture creation.
CREATE TEMP TABLE t1_snapshot (
  key text PRIMARY KEY,
  value text NOT NULL
) ON COMMIT DROP;

INSERT INTO t1_snapshot (key, value)
VALUES
(
  'member_role_grants',
  (
    SELECT count(*)::text
    FROM public.member_role_grants
  )
),
(
  'domain_signature',
  (
    SELECT
      (SELECT count(*) FROM public.leads)::text
      || ':' ||
      (SELECT count(*) FROM public.families)::text
      || ':' ||
      (SELECT count(*) FROM public.quotations)::text
      || ':' ||
      (SELECT count(*) FROM public.bookings)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_payment_requirements)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_payments)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_journey_states)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_selected_images)::text
  )
);


-- Photographer authenticated context.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 20
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  1::bigint,
  'branch-scoped Photographer receives one common training module'
);

-- 21
SELECT ok(
  (
    SELECT
      assigned_role_keys =
        ARRAY['photographer']::text[]
      AND assigned_branch_codes =
        ARRAY['bengaluru-jp-nagar']::text[]
      AND NOT organization_wide
      AND module_key = 'common-orientation'
      AND training_status =
          'not_started'::public.training_profile_status
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'training context derives exact Photographer branch scope'
);

SELECT set_config(
  't1.worker_profile_id',
  public.start_my_training_module(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'common-orientation',
    1
  )::text,
  true
);

-- 22
SELECT ok(
  current_setting(
    't1.worker_profile_id'
  )::uuid IS NOT NULL,
  'starting training creates a member training profile'
);

-- 23
SELECT is(
  public.start_my_training_module(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'common-orientation',
    1
  )::text,
  current_setting('t1.worker_profile_id'),
  'starting the same module again resumes the same profile'
);

-- 24
SELECT ok(
  (
    SELECT
      training_status =
        'in_progress'::public.training_profile_status
      AND started_at IS NOT NULL
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'started module is persistently in progress'
);

-- 25
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT public.complete_my_training_module(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
        'common-orientation',
        1
      )
    $sql$,
    'required step'
  ),
  'module completion is rejected before required evidence exists'
);

-- 26
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT public.start_my_training_module(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
        'not-a-real-module',
        1
      )
    $sql$,
    'not available'
  ),
  'unknown training module is rejected'
);

-- 27
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT public.record_my_training_step(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
        'common-orientation',
        1,
        'not-a-real-step',
        'step_completed'::public.training_step_event_type,
        'pass'::public.training_step_event_result,
        '{}'::jsonb
      )
    $sql$,
    'unknown training step'
  ),
  'unknown training step is rejected'
);

-- 28
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT public.record_my_training_step(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
        'common-orientation',
        1,
        'welcome',
        'scenario_completed'::public.training_step_event_type,
        'pass'::public.training_step_event_result,
        '{}'::jsonb
      )
    $sql$,
    'dedicated server validator'
  ),
  'generic T1 RPC cannot forge protected scenario completion'
);

-- 29
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      INSERT INTO public.member_training_profiles (
        organization_id,
        organization_member_id,
        training_module_id
      )
      VALUES (
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
        'b1000000-0000-4000-8000-000000000012'::uuid,
        gen_random_uuid()
      )
    $sql$,
    'permission denied'
  ),
  'authenticated user cannot directly insert training state'
);

-- 30
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT *
      FROM public.training_directory(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      )
    $sql$,
    'training.read'
  ),
  'Photographer cannot inspect organization training directory'
);


-- =====================================================================
-- Part 3A — Training progress cursor completion-only regression
-- =====================================================================

SELECT set_config(
  't1.cursor_before_noncompletion',
  COALESCE(
    (
      SELECT current_step_key
      FROM public.my_training_context(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      )
      WHERE module_key = 'common-orientation'
        AND module_version = 1
    ),
    '__NULL__'
  ),
  true
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'navigation',
  'training_step_broken'::public.training_step_event_type,
  'fail'::public.training_step_event_result,
  '{"source":"pgtap-cursor-regression"}'::jsonb
);

-- 31
SELECT is(
  COALESCE(
    (
      SELECT current_step_key
      FROM public.my_training_context(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      )
      WHERE module_key = 'common-orientation'
        AND module_version = 1
    ),
    '__NULL__'
  ),
  current_setting('t1.cursor_before_noncompletion'),
  'training_step_broken evidence does not advance the training progress cursor'
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'navigation',
  'step_viewed'::public.training_step_event_type,
  'info'::public.training_step_event_result,
  '{"source":"pgtap-cursor-regression"}'::jsonb
);

-- 32
SELECT is(
  COALESCE(
    (
      SELECT current_step_key
      FROM public.my_training_context(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      )
      WHERE module_key = 'common-orientation'
        AND module_version = 1
    ),
    '__NULL__'
  ),
  current_setting('t1.cursor_before_noncompletion'),
  'step_viewed evidence does not advance the training progress cursor'
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'navigation',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{"source":"pgtap-cursor-regression"}'::jsonb
);

-- 33
SELECT is(
  (
    SELECT current_step_key
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
    WHERE module_key = 'common-orientation'
      AND module_version = 1
  ),
  'navigation',
  'configured completion event and result advance the training progress cursor'
);


-- =====================================================================
-- Part 4 — Valid common-orientation completion
-- =====================================================================

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'welcome',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'role-scope',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'evidence-before-status',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'privacy',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'escalation',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  1,
  'help',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{}'::jsonb
);

RESET ROLE;

-- 34
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_step_events tse
    WHERE tse.member_training_profile_id =
      current_setting('t1.worker_profile_id')::uuid
      AND tse.event_type =
        'step_completed'::public.training_step_event_type
      AND tse.result =
        'pass'::public.training_step_event_result
  ),
  7::bigint,
  'all seven required common-orientation PASS events are recorded'
);


-- Restore Photographer.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 35
SELECT is(
  (
    SELECT current_step_key
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'help',
  'training context resumes at the latest completed common step'
);

-- 36
SELECT is(
  public.complete_my_training_module(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'common-orientation',
    1
  )::text,
  current_setting('t1.worker_profile_id'),
  'module completes only after all required evidence exists'
);

-- 37
SELECT ok(
  (
    SELECT
      training_status =
        'complete'::public.training_profile_status
      AND completed_at IS NOT NULL
      AND work_ready_at IS NULL
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'training completion does not make the member Work Ready'
);

RESET ROLE;

-- 38
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_step_events tse
    WHERE tse.member_training_profile_id =
      current_setting('t1.worker_profile_id')::uuid
      AND tse.step_key = '__module__'
      AND tse.event_type =
        'module_completed'::public.training_step_event_type
      AND tse.result =
        'pass'::public.training_step_event_result
  ),
  1::bigint,
  'module completion emits exactly one immutable module evidence event'
);

-- 39
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events ae
    WHERE ae.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND ae.actor_user_id =
        'b1000000-0000-4000-8000-000000000002'::uuid
      AND ae.action_key =
        'training.module.completed'
      AND ae.entity_type =
        'member_training_profile'
      AND ae.entity_id =
        current_setting('t1.worker_profile_id')::uuid
  ),
  1::bigint,
  'training completion is recorded in the canonical audit stream'
);

-- 40
SELECT ok(
  pg_temp.t1_denied(
    format(
      $sql$
        UPDATE public.training_step_events
        SET metadata = '{"tampered":true}'::jsonb
        WHERE member_training_profile_id = %L::uuid
      $sql$,
      current_setting('t1.worker_profile_id')
    ),
    'immutable'
  ),
  'training evidence cannot be updated'
);

-- 41
SELECT ok(
  pg_temp.t1_denied(
    format(
      $sql$
        DELETE FROM public.training_step_events
        WHERE member_training_profile_id = %L::uuid
      $sql$,
      current_setting('t1.worker_profile_id')
    ),
    'immutable'
  ),
  'training evidence cannot be deleted'
);

-- 42
SELECT is(
  (
    SELECT count(*)::text
    FROM public.member_role_grants
  ),
  (
    SELECT value
    FROM pg_temp.t1_snapshot
    WHERE key = 'member_role_grants'
  ),
  'training activity does not create, revoke, or widen role grants'
);

-- 43
SELECT is(
  (
    SELECT
      (SELECT count(*) FROM public.leads)::text
      || ':' ||
      (SELECT count(*) FROM public.families)::text
      || ':' ||
      (SELECT count(*) FROM public.quotations)::text
      || ':' ||
      (SELECT count(*) FROM public.bookings)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_payment_requirements)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_payments)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_journey_states)::text
      || ':' ||
      (SELECT count(*) FROM public.booking_selected_images)::text
  ),
  (
    SELECT value
    FROM pg_temp.t1_snapshot
    WHERE key = 'domain_signature'
  ),
  'training activity has zero real client/domain side effects'
);


-- =====================================================================
-- Part 5 — Permission and tenant isolation
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 44
SELECT is(
  public.has_permission_in_any_live_scope(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'training.read'
  ),
  false,
  'Photographer does not acquire training.read through training'
);

-- 45
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.my_training_context(
      'c1000000-0000-4000-8000-000000000099'::uuid
    )
  ),
  0::bigint,
  'member cannot retrieve training context from another organization ID'
);

-- 46
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT public.start_my_training_module(
        'c1000000-0000-4000-8000-000000000099'::uuid,
        'common-orientation',
        1
      )
    $sql$,
    'active organization membership'
  ),
  'member cannot start training against another organization ID'
);

RESET ROLE;


-- =====================================================================
-- Part 6 — Second member proves self-isolated progress
-- =====================================================================

INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at
)
VALUES (
  'b1000000-0000-4000-8000-000000000003'::uuid,
  't1-photographer-2@lsh.test',
  now()
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  email
)
VALUES (
  'b1000000-0000-4000-8000-000000000013'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-4000-8000-000000000003'::uuid,
  'active'::public.member_status,
  'T1 Photographer Two',
  't1-photographer-2@lsh.test'
);

-- Founder grants exact Erode Photographer authority.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

SELECT public.grant_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-4000-8000-000000000013'::uuid,
  'photographer',
  current_setting('t1.erode_id')::uuid
);

RESET ROLE;

-- 47
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id = g.organization_id
    WHERE g.organization_member_id =
      'b1000000-0000-4000-8000-000000000013'::uuid
      AND r.key = 'photographer'
      AND b.code = 'erode'
      AND g.revoked_at IS NULL
  ),
  1::bigint,
  'second Photographer receives only the intended Erode grant'
);


SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 48
SELECT ok(
  (
    SELECT
      assigned_role_keys =
        ARRAY['photographer']::text[]
      AND assigned_branch_codes =
        ARRAY['erode']::text[]
      AND training_status =
        'not_started'::public.training_profile_status
      AND completed_at IS NULL
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'second member sees only their own branch and does not inherit another member training progress'
);

RESET ROLE;


-- =====================================================================
-- Part 7 — Founder oversight and Work Ready boundary
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 49
SELECT ok(
  (
    SELECT count(*) = 3
    FROM public.training_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.training_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
    WHERE training_status =
      'complete'::public.training_profile_status
  ),
  'Founder directory sees all three active members and exactly one completed module'
);

RESET ROLE;

-- 50
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.member_training_profiles mtp
    WHERE mtp.work_ready_at IS NOT NULL
       OR mtp.signed_off_at IS NOT NULL
       OR mtp.signed_off_by IS NOT NULL
  ),
  0::bigint,
  'T1 completion cannot create Founder sign-off or Work Ready state'
);


-- =====================================================================
-- Part 8 — Versioned catalogue immutability
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

-- 51
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      UPDATE public.training_modules
      SET title = title
      WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
        AND module_key = 'common-orientation'
        AND version = 1
    $sql$,
    'immutable once member training state exists'
  ),
  'service role cannot mutate a module version after member training state exists'
);

-- 52
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      DELETE FROM public.training_modules
      WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
        AND module_key = 'common-orientation'
        AND version = 1
    $sql$,
    'immutable once member training state exists'
  ),
  'service role cannot delete a module version after member training state exists'
);

-- 53
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      INSERT INTO public.training_module_steps (
        organization_id,
        training_module_id,
        step_key,
        step_order,
        step_type,
        required,
        completion_event_type,
        completion_result
      )
      SELECT
        tm.organization_id,
        tm.id,
        'late-added-step',
        99,
        'orientation'::public.training_step_type,
        true,
        'step_completed'::public.training_step_event_type,
        'pass'::public.training_step_event_result
      FROM public.training_modules tm
      WHERE tm.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
        AND tm.module_key = 'common-orientation'
        AND tm.version = 1
    $sql$,
    'immutable once member training state exists'
  ),
  'service role cannot add a step to a module version after member training state exists'
);

-- 54
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      UPDATE public.training_module_steps tms
      SET required = NOT tms.required
      FROM public.training_modules tm
      WHERE tm.id = tms.training_module_id
        AND tm.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
        AND tm.module_key = 'common-orientation'
        AND tm.version = 1
        AND tms.step_key = 'welcome'
    $sql$,
    'immutable once member training state exists'
  ),
  'service role cannot edit a step contract after member training state exists'
);

-- 55
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      DELETE FROM public.training_module_steps tms
      USING public.training_modules tm
      WHERE tm.id = tms.training_module_id
        AND tm.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
        AND tm.module_key = 'common-orientation'
        AND tm.version = 1
        AND tms.step_key = 'welcome'
    $sql$,
    'immutable once member training state exists'
  ),
  'service role cannot delete a step contract after member training state exists'
);

-- New versions remain the supported evolution path.
INSERT INTO public.training_modules (
  organization_id,
  role_id,
  module_key,
  version,
  title,
  required,
  active,
  minimum_score
)
SELECT
  tm.organization_id,
  tm.role_id,
  tm.module_key,
  2,
  'Little Moments OS - Common Orientation v2 test',
  tm.required,
  false,
  tm.minimum_score
FROM public.training_modules tm
WHERE tm.organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND tm.module_key = 'common-orientation'
  AND tm.version = 1;

-- 56
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_modules tm
    WHERE tm.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key = 'common-orientation'
      AND tm.version = 2
      AND tm.active = false
  ),
  1::bigint,
  'new module versions remain available as the safe catalogue evolution path'
);

-- Give v2 the same valid completion contract before later activation.
INSERT INTO public.training_module_steps (
  organization_id,
  training_module_id,
  step_key,
  step_order,
  step_type,
  required,
  completion_event_type,
  completion_result
)
SELECT
  v2.organization_id,
  v2.id,
  v1s.step_key,
  v1s.step_order,
  v1s.step_type,
  v1s.required,
  v1s.completion_event_type,
  v1s.completion_result
FROM public.training_modules v1
JOIN public.training_module_steps v1s
  ON v1s.training_module_id =
     v1.id
JOIN public.training_modules v2
  ON v2.organization_id =
     v1.organization_id
 AND v2.module_key =
     v1.module_key
 AND v2.version = 2
WHERE v1.organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND v1.module_key = 'common-orientation'
  AND v1.version = 1;

RESET ROLE;


-- =====================================================================
-- Part 9 — Completion retry idempotency and module supersession
-- =====================================================================

-- Retry the already-completed v1 module as the original Photographer.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 57
SELECT is(
  public.complete_my_training_module(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'common-orientation',
    1
  )::text,
  current_setting('t1.worker_profile_id'),
  'retrying an already-completed module returns the existing profile'
);

RESET ROLE;

-- 58
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.training_step_events tse
    WHERE tse.member_training_profile_id =
      current_setting('t1.worker_profile_id')::uuid
      AND tse.step_key = '__module__'
      AND tse.event_type =
        'module_completed'::public.training_step_event_type
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.audit_events ae
    WHERE ae.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND ae.actor_user_id =
        'b1000000-0000-4000-8000-000000000002'::uuid
      AND ae.action_key =
        'training.module.completed'
      AND ae.entity_type =
        'member_training_profile'
      AND ae.entity_id =
        current_setting('t1.worker_profile_id')::uuid
  ),
  'completion retry emits neither duplicate module evidence nor duplicate completion audit'
);


SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

-- 59
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      UPDATE public.training_modules
      SET active = true
      WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
        AND module_key = 'common-orientation'
        AND version = 2
    $sql$,
    'duplicate key value'
  ),
  'a replacement version cannot become active while the prior version is still active'
);

UPDATE public.training_modules
SET active = false
WHERE organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND module_key = 'common-orientation'
  AND version = 1;

-- 60
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_modules tm
    WHERE tm.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key = 'common-orientation'
      AND tm.version = 1
      AND tm.active = false
  ),
  1::bigint,
  'a frozen version can be retired after all profiles for that version are complete'
);

UPDATE public.training_modules
SET active = true
WHERE organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND module_key = 'common-orientation'
  AND version = 2;

-- 61
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.training_modules tm
    WHERE tm.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key = 'common-orientation'
      AND tm.active = true
  )
  AND
  (
    SELECT version = 2
    FROM public.training_modules tm
    WHERE tm.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key = 'common-orientation'
      AND tm.active = true
  ),
  'supersession leaves exactly one active common-orientation version and it is v2'
);

RESET ROLE;


-- Second Photographer must now receive only the active replacement version.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 62
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
    WHERE module_key = 'common-orientation'
  )
  AND
  (
    SELECT module_version = 2
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
    WHERE module_key = 'common-orientation'
  ),
  'new member receives only the active replacement module version'
);

SELECT public.start_my_training_module(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2
);

RESET ROLE;


SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

-- 63
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      UPDATE public.training_modules
      SET active = false
      WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
        AND module_key = 'common-orientation'
        AND version = 2
    $sql$,
    'cannot be deactivated while member training is incomplete'
  ),
  'an active version cannot be retired while an existing profile is incomplete'
);

RESET ROLE;


-- =====================================================================
-- Part 10 — Required-step integrity and live-role applicability
-- =====================================================================

-- Create a deliberately invalid required role-specific version with
-- no required steps. This simulates malformed catalogue tooling.
SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

INSERT INTO public.training_modules (
  organization_id,
  role_id,
  module_key,
  version,
  title,
  required,
  active,
  minimum_score
)
SELECT
  g.organization_id,
  g.role_id,
  'p2-zero-step-required',
  1,
  'P2 zero-step required module',
  true,
  false,
  100
FROM public.member_role_grants g
JOIN public.roles r
  ON r.id =
     g.role_id
WHERE g.organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND g.organization_member_id =
    'b1000000-0000-4000-8000-000000000013'::uuid
  AND r.key = 'photographer'
  AND g.revoked_at IS NULL
LIMIT 1;

RESET ROLE;

-- Tests 64-68 intentionally exercise defense-in-depth against a
-- malformed active required module that could predate this publication
-- guard. Bypass only the T1 client publication trigger inside this
-- rollback-only pgTAP transaction; production catalogue tooling cannot
-- use this path.
ALTER TABLE public.training_modules
  DISABLE TRIGGER
  training_modules_common_orientation_client_contract;

UPDATE public.training_modules
SET active = true
WHERE organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND module_key =
    'p2-zero-step-required'
  AND version = 1;

ALTER TABLE public.training_modules
  ENABLE TRIGGER
  training_modules_common_orientation_client_contract;


-- Second Photographer is still eligible at this point.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 64
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT public.start_my_training_module(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
        'p2-zero-step-required',
        1
      )
    $sql$,
    'at least one required step'
  ),
  'required module with zero required steps cannot be started'
);

RESET ROLE;

-- 65
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.member_training_profiles mtp
    JOIN public.training_modules tm
      ON tm.id =
         mtp.training_module_id
    WHERE mtp.organization_member_id =
      'b1000000-0000-4000-8000-000000000013'::uuid
      AND tm.module_key =
        'p2-zero-step-required'
      AND tm.version = 1
  ),
  0::bigint,
  'rejected zero-step start creates no member training state'
);


-- Synthetic pre-existing/admin-created state proves completion itself
-- remains fail-closed even if invalid state somehow already exists.
INSERT INTO public.member_training_profiles (
  id,
  organization_id,
  organization_member_id,
  training_module_id,
  status,
  required_at,
  started_at
)
SELECT
  'b2000000-0000-4000-8000-000000000001'::uuid,
  tm.organization_id,
  'b1000000-0000-4000-8000-000000000013'::uuid,
  tm.id,
  'in_progress'::public.training_profile_status,
  now(),
  now()
FROM public.training_modules tm
WHERE tm.organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND tm.module_key =
    'p2-zero-step-required'
  AND tm.version = 1;


SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 66
SELECT ok(
  pg_temp.t1_denied(
    $sql$
      SELECT public.complete_my_training_module(
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
        'p2-zero-step-required',
        1
      )
    $sql$,
    'at least one required step'
  ),
  'required module with zero required steps cannot be completed'
);

RESET ROLE;

-- 67
SELECT ok(
  (
    SELECT
      mtp.status =
        'in_progress'::public.training_profile_status
      AND mtp.completed_at IS NULL
    FROM public.member_training_profiles mtp
    WHERE mtp.id =
      'b2000000-0000-4000-8000-000000000001'::uuid
  )
  AND
  (
    SELECT count(*) = 0
    FROM public.training_step_events tse
    WHERE tse.member_training_profile_id =
      'b2000000-0000-4000-8000-000000000001'::uuid
      AND tse.event_type =
        'module_completed'::public.training_step_event_type
  ),
  'zero-step completion denial leaves profile and evidence unchanged'
);


-- Revoke the member's only live Photographer role while preserving
-- the incomplete training profile as immutable history.
UPDATE public.member_role_grants g
SET revoked_at = now()
FROM public.roles r
WHERE r.id =
      g.role_id
  AND g.organization_id =
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND g.organization_member_id =
    'b1000000-0000-4000-8000-000000000013'::uuid
  AND r.key = 'photographer'
  AND g.revoked_at IS NULL;


SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

-- This must now succeed: preserved history from an ineligible member
-- cannot permanently prevent catalogue supersession.
UPDATE public.training_modules
SET active = false
WHERE organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND module_key =
    'p2-zero-step-required'
  AND version = 1;

RESET ROLE;

-- 68
SELECT ok(
  (
    SELECT tm.active = false
    FROM public.training_modules tm
    WHERE tm.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key =
        'p2-zero-step-required'
      AND tm.version = 1
  )
  AND
  (
    SELECT
      mtp.status =
        'in_progress'::public.training_profile_status
      AND mtp.completed_at IS NULL
    FROM public.member_training_profiles mtp
    WHERE mtp.id =
      'b2000000-0000-4000-8000-000000000001'::uuid
  ),
  'revoked-role incomplete history is preserved but no longer blocks version retirement'
);


-- Roleless member context must expose no applicable module rows.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 69
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  0::bigint,
  'member with no live role scope receives no training context rows'
);

RESET ROLE;


-- Founder oversight must agree with member applicability.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 70
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.training_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
    WHERE organization_member_id =
      'b1000000-0000-4000-8000-000000000013'::uuid
  ),
  0::bigint,
  'Founder directory excludes active members with no live role scope'
);

RESET ROLE;


-- =====================================================================
-- Part 11 — Training progress cursor monotonicity
-- =====================================================================
--
-- Founder has a live organization-wide role and the active v2 common
-- orientation is available. A later completed step is recorded first,
-- then a stale earlier completion is submitted as if from another tab.
-- Both evidence events remain valid, but the profile cursor must never
-- move backward.
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

SELECT public.start_my_training_module(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2,
  'privacy',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{"source":"pgtap-monotonic-cursor-later-tab"}'::jsonb
);

-- 71
SELECT is(
  (
    SELECT current_step_key
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
    WHERE module_key = 'common-orientation'
      AND module_version = 2
  ),
  'privacy',
  'later valid completion advances the training progress cursor'
);

SELECT set_config(
  't1.stale_cursor_event_id',
  public.record_my_training_step(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'common-orientation',
    2,
    'welcome',
    'step_completed'::public.training_step_event_type,
    'pass'::public.training_step_event_result,
    '{"source":"pgtap-monotonic-cursor-stale-tab"}'::jsonb
  )::text,
  true
);

-- 72
SELECT ok(
  (
    SELECT current_step_key = 'privacy'
    FROM public.my_training_context(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
    WHERE module_key = 'common-orientation'
      AND module_version = 2
  )
  AND
  current_setting(
    't1.stale_cursor_event_id'
  )::uuid IS NOT NULL,
  'stale earlier completion remains recorded evidence but cannot regress the progress cursor'
);

RESET ROLE;


-- =====================================================================
-- Part 12 — Client-renderable common-orientation publication guard
-- =====================================================================
--
-- The current T1 client renders the frozen seven-step common orientation.
-- Catalogue tooling may create successor versions while inactive, but a
-- changed/reordered contract cannot become active until the client itself
-- supports that contract.
-- =====================================================================

-- Complete the Founder's active v2 profile so the version may retire.
SELECT set_config(
  'request.jwt.claim.sub',
  'b1000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claim.role',
  'authenticated',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2,
  'role-scope',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{"source":"pgtap-client-contract-guard"}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2,
  'navigation',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{"source":"pgtap-client-contract-guard"}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2,
  'evidence-before-status',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{"source":"pgtap-client-contract-guard"}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2,
  'escalation',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{"source":"pgtap-client-contract-guard"}'::jsonb
);

SELECT public.record_my_training_step(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2,
  'help',
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result,
  '{"source":"pgtap-client-contract-guard"}'::jsonb
);

SELECT public.complete_my_training_module(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'common-orientation',
  2
);

RESET ROLE;


SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

UPDATE public.training_modules
SET active = false
WHERE organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND module_key = 'common-orientation'
  AND version = 2;

WITH inserted AS (
  INSERT INTO public.training_modules (
    organization_id,
    role_id,
    module_key,
    version,
    title,
    required,
    active,
    minimum_score
  )
  SELECT
    tm.organization_id,
    tm.role_id,
    tm.module_key,
    3,
    'Common Orientation v3 incompatible fixture',
    tm.required,
    false,
    tm.minimum_score
  FROM public.training_modules tm
  WHERE tm.organization_id =
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND tm.module_key = 'common-orientation'
    AND tm.version = 2
  RETURNING id
)
SELECT set_config(
  't1.incompatible_common_v3_id',
  id::text,
  true
)
FROM inserted;

INSERT INTO public.training_module_steps (
  organization_id,
  training_module_id,
  step_key,
  step_order,
  step_type,
  required,
  completion_event_type,
  completion_result
)
SELECT
  tms.organization_id,
  current_setting(
    't1.incompatible_common_v3_id'
  )::uuid,
  tms.step_key,
  tms.step_order,
  tms.step_type,
  tms.required,
  tms.completion_event_type,
  tms.completion_result
FROM public.training_module_steps tms
JOIN public.training_modules tm
  ON tm.id =
     tms.training_module_id
WHERE tm.organization_id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND tm.module_key = 'common-orientation'
  AND tm.version = 2;

UPDATE public.training_module_steps
SET step_order = 8
WHERE training_module_id =
  current_setting(
    't1.incompatible_common_v3_id'
  )::uuid
  AND step_key = 'welcome';

-- 73
SELECT throws_ok(
  $sql$
    UPDATE public.training_modules
    SET active = true
    WHERE id =
      current_setting(
        't1.incompatible_common_v3_id'
      )::uuid
  $sql$,
  'P0001',
  'Active common-orientation contract is not supported by the T1 client',
  'an unsupported successor common-orientation contract cannot be activated'
);

-- 74
SELECT ok(
  (
    SELECT active = false
    FROM public.training_modules
    WHERE id =
      current_setting(
        't1.incompatible_common_v3_id'
      )::uuid
  ),
  'failed incompatible publication leaves the successor version inactive'
);

RESET ROLE;


-- =====================================================================
-- Part 13 — Immutable evidence cannot be truncated
-- =====================================================================

-- 75
SELECT ok(
  NOT has_table_privilege(
    'service_role',
    'public.training_step_events',
    'TRUNCATE'
  ),
  'service_role has no TRUNCATE privilege on immutable training evidence'
);

SET LOCAL ROLE service_role;

-- 76
SELECT ok(
  pg_temp.t1_denied(
    'TRUNCATE TABLE public.training_step_events',
    'permission denied'
  ),
  'service_role cannot execute TRUNCATE against immutable training evidence'
);

RESET ROLE;


-- =====================================================================
-- Part 14 — Required modules must be renderable before publication
-- =====================================================================
-- A valid role-specific module may be assembled while inactive, but T1
-- cannot publish it as required because the current client renders only
-- global common orientation.
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

WITH inserted AS (
  INSERT INTO public.training_modules (
    organization_id,
    role_id,
    module_key,
    version,
    title,
    required,
    active,
    minimum_score
  )
  SELECT
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    r.id,
    'photographer-foundation',
    1,
    'Photographer Foundation',
    true,
    false,
    100
  FROM public.roles r
  WHERE r.key = 'photographer'
  RETURNING id
)
SELECT set_config(
  't1.unsupported_required_role_module_id',
  id::text,
  true
)
FROM inserted;

INSERT INTO public.training_module_steps (
  organization_id,
  training_module_id,
  step_key,
  step_order,
  step_type,
  required,
  completion_event_type,
  completion_result
)
VALUES (
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  current_setting(
    't1.unsupported_required_role_module_id'
  )::uuid,
  'role-foundation',
  1,
  'orientation'::public.training_step_type,
  true,
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result
);

-- 77
SELECT throws_ok(
  $sql$
    UPDATE public.training_modules
    SET active = true
    WHERE id =
      current_setting(
        't1.unsupported_required_role_module_id'
      )::uuid
  $sql$,
  'P0001',
  'Active required training module is not supported by the T1 client',
  'a required role-specific module cannot be published before T1 can render it'
);

-- 78
SELECT ok(
  (
    SELECT active = false
    FROM public.training_modules
    WHERE id =
      current_setting(
        't1.unsupported_required_role_module_id'
      )::uuid
  ),
  'failed unsupported required-module publication leaves the module inactive'
);

RESET ROLE;


SELECT * FROM finish();

ROLLBACK;
