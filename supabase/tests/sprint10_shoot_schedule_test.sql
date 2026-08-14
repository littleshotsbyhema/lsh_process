BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(111);

-- =====================================================================
-- Sprint 10 — Slice 1
-- Shoot Scheduling Evidence + Confirmation Reservation Gate
--
-- Section A — Structural / permission / security contract
-- =====================================================================

-- ---------------------------------------------------------------------
-- Canonical schedule evidence surface
-- ---------------------------------------------------------------------

SELECT ok(
  to_regclass(
    'public.booking_shoot_schedules'
  ) IS NOT NULL,
  'booking_shoot_schedules exists'
);

SELECT ok(
  to_regprocedure(
    'public.lsh_booking_shoot_schedule_guard()'
  ) IS NOT NULL,
  'booking shoot schedule immutable guard exists'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_trigger t
    WHERE NOT t.tgisinternal
      AND t.tgrelid =
          to_regclass(
            'public.booking_shoot_schedules'
          )
      AND t.tgname =
          'booking_shoot_schedules_guard'
  ),
  'booking_shoot_schedules immutable guard trigger exists'
);

-- ---------------------------------------------------------------------
-- shoot.schedule permission catalogue and least-privilege grants
-- ---------------------------------------------------------------------

SELECT is(
  (
    SELECT count(*)
    FROM public.permissions p
    WHERE p.key = 'shoot.schedule'
  ),
  1::bigint,
  'shoot.schedule exists exactly once'
);

SELECT ok(
  COALESCE(
    (
      SELECT p.requires_server_enforcement
      FROM public.permissions p
      WHERE p.key = 'shoot.schedule'
    ),
    false
  ),
  'shoot.schedule requires server enforcement'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE p.key = 'shoot.schedule'
      AND r.key IN (
        'founder',
        'studio_manager',
        'client_coordinator'
      )
  ),
  3::bigint,
  'Founder, Studio Manager and Client Coordinator receive shoot.schedule'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE p.key = 'shoot.schedule'
      AND r.key NOT IN (
        'founder',
        'studio_manager',
        'client_coordinator'
      )
  ),
  0::bigint,
  'no other role receives shoot.schedule'
);

-- ---------------------------------------------------------------------
-- RLS and direct-write denial
-- ---------------------------------------------------------------------

SELECT ok(
  COALESCE(
    (
      SELECT c.relrowsecurity
      FROM pg_class c
      WHERE c.oid =
            to_regclass(
              'public.booking_shoot_schedules'
            )
    ),
    false
  ),
  'booking_shoot_schedules has RLS enabled'
);

SELECT ok(
  COALESCE(
    (
      SELECT c.relforcerowsecurity
      FROM pg_class c
      WHERE c.oid =
            to_regclass(
              'public.booking_shoot_schedules'
            )
    ),
    false
  ),
  'booking_shoot_schedules has FORCE RLS enabled'
);

SELECT ok(
  COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_shoot_schedules'
      ),
      'SELECT'
    ),
    false
  ),
  'authenticated may select booking shoot schedules subject to RLS'
);

SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_shoot_schedules'
      ),
      'INSERT'
    ),
    false
  ),
  'authenticated cannot directly insert booking shoot schedules'
);

SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_shoot_schedules'
      ),
      'UPDATE'
    ),
    false
  ),
  'authenticated cannot directly update booking shoot schedules'
);

SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'authenticated',
      to_regclass(
        'public.booking_shoot_schedules'
      ),
      'DELETE'
    ),
    false
  ),
  'authenticated cannot directly delete booking shoot schedules'
);

SELECT ok(
  NOT COALESCE(
    has_table_privilege(
      'anon',
      to_regclass(
        'public.booking_shoot_schedules'
      ),
      'SELECT'
    ),
    false
  ),
  'anon cannot select booking shoot schedules'
);

-- ---------------------------------------------------------------------
-- Public mutation RPC catalogue
-- ---------------------------------------------------------------------

SELECT ok(
  to_regprocedure(
    'public.propose_booking_shoot_schedule(uuid,timestamp with time zone,timestamp with time zone,text,text,text)'
  ) IS NOT NULL,
  'propose_booking_shoot_schedule exists'
);

SELECT ok(
  to_regprocedure(
    'public.reschedule_booking_shoot(uuid,timestamp with time zone,timestamp with time zone,text,text,text,text)'
  ) IS NOT NULL,
  'reschedule_booking_shoot exists'
);

SELECT ok(
  to_regprocedure(
    'public.confirm_booking_after_advance(uuid)'
  ) IS NOT NULL,
  'confirm_booking_after_advance remains available'
);

-- ---------------------------------------------------------------------
-- SECURITY DEFINER contract
-- ---------------------------------------------------------------------

SELECT ok(
  COALESCE(
    (
      SELECT p.prosecdef
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.propose_booking_shoot_schedule(uuid,timestamp with time zone,timestamp with time zone,text,text,text)'
            )::oid
    ),
    false
  ),
  'propose_booking_shoot_schedule is SECURITY DEFINER'
);

SELECT ok(
  COALESCE(
    (
      SELECT p.prosecdef
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.reschedule_booking_shoot(uuid,timestamp with time zone,timestamp with time zone,text,text,text,text)'
            )::oid
    ),
    false
  ),
  'reschedule_booking_shoot is SECURITY DEFINER'
);

SELECT ok(
  COALESCE(
    (
      SELECT p.prosecdef
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.confirm_booking_after_advance(uuid)'
            )::oid
    ),
    false
  ),
  'confirm_booking_after_advance is SECURITY DEFINER'
);

-- ---------------------------------------------------------------------
-- Safe search_path contract
-- ---------------------------------------------------------------------

SELECT ok(
  COALESCE(
    (
      SELECT
        pg_get_functiondef(p.oid)
          LIKE '%SET search_path TO ''''%'
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.propose_booking_shoot_schedule(uuid,timestamp with time zone,timestamp with time zone,text,text,text)'
            )::oid
    ),
    false
  ),
  'propose_booking_shoot_schedule uses empty search_path'
);

SELECT ok(
  COALESCE(
    (
      SELECT
        pg_get_functiondef(p.oid)
          LIKE '%SET search_path TO ''''%'
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.reschedule_booking_shoot(uuid,timestamp with time zone,timestamp with time zone,text,text,text,text)'
            )::oid
    ),
    false
  ),
  'reschedule_booking_shoot uses empty search_path'
);

SELECT ok(
  COALESCE(
    (
      SELECT
        pg_get_functiondef(p.oid)
          LIKE '%SET search_path TO ''''%'
      FROM pg_proc p
      WHERE p.oid =
            to_regprocedure(
              'public.confirm_booking_after_advance(uuid)'
            )::oid
    ),
    false
  ),
  'confirm_booking_after_advance uses empty search_path'
);

-- ---------------------------------------------------------------------
-- RPC execution boundary
-- ---------------------------------------------------------------------

SELECT ok(
  COALESCE(
    has_function_privilege(
      'authenticated',
      to_regprocedure(
        'public.propose_booking_shoot_schedule(uuid,timestamp with time zone,timestamp with time zone,text,text,text)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'authenticated may execute propose_booking_shoot_schedule'
);

SELECT ok(
  NOT COALESCE(
    has_function_privilege(
      'anon',
      to_regprocedure(
        'public.propose_booking_shoot_schedule(uuid,timestamp with time zone,timestamp with time zone,text,text,text)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'anon cannot execute propose_booking_shoot_schedule'
);

SELECT ok(
  COALESCE(
    has_function_privilege(
      'authenticated',
      to_regprocedure(
        'public.reschedule_booking_shoot(uuid,timestamp with time zone,timestamp with time zone,text,text,text,text)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'authenticated may execute reschedule_booking_shoot'
);

SELECT ok(
  NOT COALESCE(
    has_function_privilege(
      'anon',
      to_regprocedure(
        'public.reschedule_booking_shoot(uuid,timestamp with time zone,timestamp with time zone,text,text,text,text)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'anon cannot execute reschedule_booking_shoot'
);

SELECT ok(
  COALESCE(
    has_function_privilege(
      'authenticated',
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'authenticated may execute confirm_booking_after_advance'
);

SELECT ok(
  NOT COALESCE(
    has_function_privilege(
      'anon',
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid,
      'EXECUTE'
    ),
    false
  ),
  'anon cannot execute confirm_booking_after_advance'
);


-- =====================================================================
-- Section F1 — Canonical Stage 7 booking and first shoot proposal
-- =====================================================================

-- ---------------------------------------------------------------------
-- Test identities.
--
-- Keep these transaction-local and distinct from prior sprint suites.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES
  ('86000000-0000-0000-0000-000000000001'::uuid),
  ('86000000-0000-0000-0000-000000000002'::uuid),
  ('86000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '86000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '86000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 10 Scheduling Founder'
),
(
  '86000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '86000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 10 Scheduling Photographer'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  r.id
FROM (
  VALUES
    (
      '86000000-0000-0000-0000-000000000011'::uuid,
      'founder'
    ),
    (
      '86000000-0000-0000-0000-000000000012'::uuid,
      'photographer'
    )
) fixture(member_id, role_key)
JOIN public.roles r
  ON r.key = fixture.role_key;

-- Clean migration replay intentionally requires Founder coverage before
-- the canonical organization is activated for operational fixtures.
UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

-- Establish the Sprint 10 Founder as the authenticated actor.
SELECT set_config(
  'request.jwt.claim.sub',
  '86000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"86000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Canonical family -> quotation -> booking fixture.
-- ---------------------------------------------------------------------

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
  '86000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-234567',
  'Sprint 10 Scheduling Family',
  'Scheduling Family',
  'active',
  '86000000-0000-0000-0000-000000000011',
  '86000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '86000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10_quote),
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
  (SELECT id FROM s10_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10_quote)
);

-- 30
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
          (SELECT id FROM s10_booking)
  ),
  'advance_pending',
  'Sprint 10 fixture starts at canonical Advance Pending'
);

-- 31
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  1::bigint,
  'Sprint 10 fixture starts at journey version 1'
);

-- 32
SELECT is(
  (
    SELECT r.required_advance_inr
    FROM public.booking_payment_requirements r
    WHERE r.booking_id =
          (SELECT id FROM s10_booking)
  ),
  15000,
  'Sprint 10 fixture preserves the ₹15,000 required advance'
);

-- ---------------------------------------------------------------------
-- First non-reserving shoot proposal.
-- ---------------------------------------------------------------------

-- 33
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_proposal_v1 AS
  SELECT *
  FROM public.propose_booking_shoot_schedule(
    (SELECT id FROM s10_booking),
    '2030-01-15 10:00:00+05:30'::timestamptz,
    '2030-01-15 12:00:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    'Little Shots Studio'
  )
  $$,
  'Founder may append the first Stage 7 shoot proposal'
);

-- 34
SELECT is(
  (SELECT schedule_version FROM s10_proposal_v1),
  1,
  'first shoot proposal is schedule version 1'
);

-- 35
SELECT is(
  (SELECT schedule_state FROM s10_proposal_v1),
  'proposed',
  'first shoot schedule remains proposed and unreserved'
);

-- 36
SELECT ok(
  (
    SELECT predecessor_schedule_id IS NULL
    FROM s10_proposal_v1
  ),
  'first shoot proposal has no predecessor'
);

-- 37
SELECT ok(
  (
    SELECT reschedule_reason IS NULL
    FROM s10_proposal_v1
  ),
  'first proposal has no reschedule reason'
);

-- 38
SELECT is(
  (SELECT recorded_by FROM s10_proposal_v1),
  '86000000-0000-0000-0000-000000000011'::uuid,
  'first proposal records the authenticated Founder member'
);

-- Proposal creation must not move the journey.

-- 39
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
          (SELECT id FROM s10_booking)
  ),
  'advance_pending',
  'creating a shoot proposal does not leave Advance Pending'
);

-- 40
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  1::bigint,
  'creating a shoot proposal does not increment journey version'
);


-- =====================================================================
-- Section F2 — Proposal replay, lineage and immutable history
-- =====================================================================

-- ---------------------------------------------------------------------
-- Exact replay returns the existing immutable proposal.
-- ---------------------------------------------------------------------

-- 41
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_proposal_v1_replay AS
  SELECT *
  FROM public.propose_booking_shoot_schedule(
    (SELECT id FROM s10_booking),
    '2030-01-15 10:00:00+05:30'::timestamptz,
    '2030-01-15 12:00:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    'Little Shots Studio'
  )
  $$,
  'exact proposal replay succeeds idempotently'
);

-- 42
SELECT is(
  (SELECT id FROM s10_proposal_v1_replay),
  (SELECT id FROM s10_proposal_v1),
  'exact proposal replay returns the original schedule evidence row'
);

-- 43
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
  ),
  1::bigint,
  'exact proposal replay does not append another schedule version'
);

-- ---------------------------------------------------------------------
-- Changed proposal facts append the next immutable version.
-- ---------------------------------------------------------------------

-- 44
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_proposal_v2 AS
  SELECT *
  FROM public.propose_booking_shoot_schedule(
    (SELECT id FROM s10_booking),
    '2030-01-16 13:00:00+05:30'::timestamptz,
    '2030-01-16 15:30:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'client_home',
    'Client residence'
  )
  $$,
  'changed Stage 7 shoot proposal appends a new immutable version'
);

-- 45
SELECT is(
  (SELECT schedule_version FROM s10_proposal_v2),
  2,
  'changed proposal becomes schedule version 2'
);

-- 46
SELECT is(
  (SELECT predecessor_schedule_id FROM s10_proposal_v2),
  (SELECT id FROM s10_proposal_v1),
  'proposal version 2 points exactly to proposal version 1'
);

-- 47
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
  ),
  2::bigint,
  'changed proposal creates exactly one additional schedule evidence row'
);

-- ---------------------------------------------------------------------
-- Earlier schedule evidence remains unchanged and cannot be rewritten.
-- ---------------------------------------------------------------------

-- 48
SELECT is(
  (
    SELECT s.scheduled_start_at
    FROM public.booking_shoot_schedules s
    WHERE s.id =
          (SELECT id FROM s10_proposal_v1)
  ),
  '2030-01-15 10:00:00+05:30'::timestamptz,
  'proposal version 1 retains its original scheduled start'
);

-- 49
SELECT throws_ok(
  $$
  UPDATE public.booking_shoot_schedules
  SET scheduled_start_at =
      scheduled_start_at + interval '1 hour'
  WHERE id =
        (SELECT id FROM s10_proposal_v1)
  $$,
  'P0001',
  'booking shoot schedule evidence is append-only and immutable',
  'historical proposal evidence cannot be updated'
);

-- 50
SELECT throws_ok(
  $$
  DELETE FROM public.booking_shoot_schedules
  WHERE id =
        (SELECT id FROM s10_proposal_v1)
  $$,
  'P0001',
  'booking shoot schedule evidence is append-only and immutable',
  'historical proposal evidence cannot be deleted'
);


-- =====================================================================
-- Section F3 — Financial gate and atomic confirmation reservation
-- =====================================================================

-- ---------------------------------------------------------------------
-- Existing Sprint 9 financial failures remain authoritative even when
-- a valid current Stage 7 shoot proposal already exists.
-- ---------------------------------------------------------------------

-- 51
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s10_booking)
  )
  $$,
  '22023',
  'confirm_booking_after_advance: required advance has not been satisfied',
  'valid shoot proposal does not bypass zero-payment advance gate'
);

CREATE TEMP TABLE s10_partial_payment AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s10_booking),
  5000,
  'cash'::public.booking_payment_method,
  now(),
  'S10-PARTIAL',
  'Sprint 10 partial advance gate'
);

-- 52
SELECT is(
  (SELECT amount_inr FROM s10_partial_payment),
  5000,
  'partial advance records ₹5,000 payment evidence'
);

-- 53
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s10_booking)
    )
  ),
  5000::bigint,
  'partial advance derives ₹5,000 valid collection'
);

-- 54
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s10_booking)
  )
  $$,
  '22023',
  'confirm_booking_after_advance: required advance has not been satisfied',
  'valid shoot proposal does not bypass partial-payment advance gate'
);

CREATE TEMP TABLE s10_partial_reversal AS
SELECT *
FROM public.reverse_booking_payment(
  (SELECT id FROM s10_partial_payment),
  'Reverse Sprint 10 partial payment'
);

-- 55
SELECT is(
  (SELECT reason FROM s10_partial_reversal),
  'Reverse Sprint 10 partial payment',
  'partial-payment reversal preserves immutable correction reason'
);

-- 56
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s10_booking)
    )
  ),
  0::bigint,
  'reversed partial payment contributes zero valid collection'
);

-- 57
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s10_booking)
  )
  $$,
  '22023',
  'confirm_booking_after_advance: required advance has not been satisfied',
  'reversed collection still cannot confirm despite valid shoot proposal'
);

-- ---------------------------------------------------------------------
-- Exact required advance satisfies the existing financial invariant.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10_exact_payment AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s10_booking),
  15000,
  'upi'::public.booking_payment_method,
  now(),
  'S10-CONFIRM-EXACT',
  'Exact Sprint 10 required advance'
);

-- 58
SELECT is(
  (SELECT amount_inr FROM s10_exact_payment),
  15000,
  'exact required advance records ₹15,000 evidence'
);

-- 59
SELECT is(
  (
    SELECT advance_satisfied
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s10_booking)
    )
  ),
  true,
  'exact required advance satisfies the existing Sprint 9 payment gate'
);

-- ---------------------------------------------------------------------
-- Confirmation atomically copies proposal v2 into reserved v3 and
-- performs the existing Stage 7 -> Stage 8 transition.
-- ---------------------------------------------------------------------

-- 60
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_confirm_once AS
  SELECT *
  FROM public.confirm_booking_after_advance(
    (SELECT id FROM s10_booking)
  )
  $$,
  'advance plus current shoot proposal permits booking confirmation'
);

-- 61
SELECT is(
  (SELECT id FROM s10_confirm_once),
  (SELECT id FROM s10_booking),
  'confirmation returns the same canonical booking'
);

-- 62
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
          (SELECT id FROM s10_booking)
  ),
  'booking_confirmed',
  'confirmation advances exactly to Booking Confirmed'
);

-- 63
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  2::bigint,
  'confirmation increments journey version exactly once'
);

-- 64
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10_booking)
      AND t.transition_key =
          'advance_satisfied'
  ),
  1::bigint,
  'confirmation appends exactly one advance_satisfied transition'
);

-- 65
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
  ),
  3::bigint,
  'confirmation appends exactly one reserved schedule after proposals v1 and v2'
);

-- 66
SELECT is(
  (
    SELECT s.schedule_version
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
    ORDER BY s.schedule_version DESC
    LIMIT 1
  ),
  3,
  'confirmation reservation becomes schedule version 3'
);

-- 67
SELECT is(
  (
    SELECT s.schedule_state
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
    ORDER BY s.schedule_version DESC
    LIMIT 1
  ),
  'reserved',
  'confirmation creates authoritative reserved schedule evidence'
);

-- 68
SELECT is(
  (
    SELECT s.predecessor_schedule_id
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
    ORDER BY s.schedule_version DESC
    LIMIT 1
  ),
  (SELECT id FROM s10_proposal_v2),
  'reserved version 3 points exactly to proposal version 2'
);

-- 69
SELECT is(
  (
    SELECT jsonb_build_object(
      'scheduled_start_at', s.scheduled_start_at,
      'scheduled_end_at', s.scheduled_end_at,
      'timezone', s.timezone,
      'location_type', s.location_type,
      'location_details', s.location_details
    )
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
    ORDER BY s.schedule_version DESC
    LIMIT 1
  ),
  (
    SELECT jsonb_build_object(
      'scheduled_start_at', p.scheduled_start_at,
      'scheduled_end_at', p.scheduled_end_at,
      'timezone', p.timezone,
      'location_type', p.location_type,
      'location_details', p.location_details
    )
    FROM s10_proposal_v2 p
  ),
  'reserved version 3 is an exact immutable copy of proposal version 2 schedule facts'
);

-- 70
SELECT ok(
  (
    SELECT s.reschedule_reason IS NULL
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
    ORDER BY s.schedule_version DESC
    LIMIT 1
  ),
  'initial confirmation reservation has no reschedule reason'
);

-- 71
SELECT is(
  (
    SELECT s.recorded_by
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
    ORDER BY s.schedule_version DESC
    LIMIT 1
  ),
  '86000000-0000-0000-0000-000000000011'::uuid,
  'reservation records the authenticated confirming Founder'
);

-- ---------------------------------------------------------------------
-- Immediate confirmation replay remains idempotent.
-- ---------------------------------------------------------------------

-- 72
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_confirm_replay AS
  SELECT *
  FROM public.confirm_booking_after_advance(
    (SELECT id FROM s10_booking)
  )
  $$,
  'immediate booking confirmation replay succeeds idempotently'
);

-- 73
SELECT is(
  (SELECT id FROM s10_confirm_replay),
  (SELECT id FROM s10_booking),
  'confirmation replay returns the same canonical booking'
);

-- 74
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
  ),
  3::bigint,
  'confirmation replay does not append another reserved schedule'
);

-- 75
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  2::bigint,
  'confirmation replay does not increment journey version'
);

-- 76
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10_booking)
      AND t.transition_key =
          'advance_satisfied'
  ),
  1::bigint,
  'confirmation replay retains exactly one advance_satisfied transition'
);


-- =====================================================================
-- Section F4 — Stage 8 authoritative rescheduling and replay
-- =====================================================================

-- ---------------------------------------------------------------------
-- Booking is now confirmed at Stage 8 with reserved schedule v3.
-- A legitimate reschedule must append reserved v4 without touching the
-- authoritative booking journey.
-- ---------------------------------------------------------------------

-- 77
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_reschedule_v4 AS
  SELECT *
  FROM public.reschedule_booking_shoot(
    (SELECT id FROM s10_booking),
    '2030-01-18 09:30:00+05:30'::timestamptz,
    '2030-01-18 12:30:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    'Family requested a later shoot date',
    'Little Shots Studio'
  )
  $$,
  'Founder may reschedule the authoritative Stage 8 shoot'
);

-- 78
SELECT is(
  (SELECT schedule_version FROM s10_reschedule_v4),
  4,
  'first authoritative reschedule becomes schedule version 4'
);

-- 79
SELECT is(
  (SELECT schedule_state FROM s10_reschedule_v4),
  'reserved',
  'rescheduled shoot remains authoritative reserved evidence'
);

-- 80
SELECT is(
  (SELECT predecessor_schedule_id FROM s10_reschedule_v4),
  (
    SELECT id
    FROM public.booking_shoot_schedules
    WHERE booking_id =
          (SELECT id FROM s10_booking)
      AND schedule_version = 3
  ),
  'reschedule version 4 points exactly to reserved version 3'
);

-- 81
SELECT is(
  (SELECT reschedule_reason FROM s10_reschedule_v4),
  'Family requested a later shoot date',
  'reschedule preserves the required nonblank reason'
);

-- 82
SELECT is(
  (SELECT scheduled_start_at FROM s10_reschedule_v4),
  '2030-01-18 09:30:00+05:30'::timestamptz,
  'reschedule records the new authoritative start time'
);

-- 83
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules
    WHERE booking_id =
          (SELECT id FROM s10_booking)
  ),
  4::bigint,
  'reschedule appends exactly one new schedule evidence row'
);

-- ---------------------------------------------------------------------
-- Rescheduling never moves the booking journey backward or forward.
-- ---------------------------------------------------------------------

-- 84
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
          (SELECT id FROM s10_booking)
  ),
  'booking_confirmed',
  'Stage 8 reschedule leaves booking at Booking Confirmed'
);

-- 85
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  2::bigint,
  'Stage 8 reschedule does not increment journey version'
);

-- ---------------------------------------------------------------------
-- Exact replay of the latest reschedule is idempotent.
-- ---------------------------------------------------------------------

-- 86
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_reschedule_v4_replay AS
  SELECT *
  FROM public.reschedule_booking_shoot(
    (SELECT id FROM s10_booking),
    '2030-01-18 09:30:00+05:30'::timestamptz,
    '2030-01-18 12:30:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    'Family requested a later shoot date',
    'Little Shots Studio'
  )
  $$,
  'exact authoritative reschedule replay succeeds idempotently'
);

-- 87
SELECT is(
  (SELECT id FROM s10_reschedule_v4_replay),
  (SELECT id FROM s10_reschedule_v4),
  'exact reschedule replay returns existing reserved version 4'
);

-- 88
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules
    WHERE booking_id =
          (SELECT id FROM s10_booking)
  ),
  4::bigint,
  'exact reschedule replay does not append version 5'
);

-- 89
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  2::bigint,
  'reschedule replay still does not change journey version'
);

-- 90
SELECT is(
  (SELECT recorded_by FROM s10_reschedule_v4),
  '86000000-0000-0000-0000-000000000011'::uuid,
  'authoritative reschedule records the authenticated Founder member'
);

-- 91
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s10_booking)
      AND transition_key =
          'advance_satisfied'
  ),
  1::bigint,
  'rescheduling preserves the single historical confirmation transition'
);


-- =====================================================================
-- Section F5 — Authorization and Stage 9/10 reschedule boundaries
-- =====================================================================

-- ---------------------------------------------------------------------
-- Photographer is an active member but does not receive shoot.schedule.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '86000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"86000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 92
SELECT throws_ok(
  $$
  SELECT public.reschedule_booking_shoot(
    (SELECT id FROM s10_booking),
    '2030-01-19 10:00:00+05:30'::timestamptz,
    '2030-01-19 13:00:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    'Unauthorized photographer attempt',
    'Little Shots Studio'
  )
  $$,
  '42501',
  'reschedule_booking_shoot: shoot.schedule permission required',
  'Photographer without shoot.schedule cannot reschedule booking'
);

-- Restore Founder.
SELECT set_config(
  'request.jwt.claim.sub',
  '86000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"86000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Required reschedule reason fails closed.
-- ---------------------------------------------------------------------

-- 93
SELECT throws_ok(
  $$
  SELECT public.reschedule_booking_shoot(
    (SELECT id FROM s10_booking),
    '2030-01-19 10:00:00+05:30'::timestamptz,
    '2030-01-19 13:00:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    '   ',
    'Little Shots Studio'
  )
  $$,
  '22023',
  'reschedule_booking_shoot: reschedule reason is required',
  'blank authoritative reschedule reason is rejected'
);

-- ---------------------------------------------------------------------
-- Proposal creation is Stage-7-only.
-- ---------------------------------------------------------------------

-- 94
SELECT throws_ok(
  $$
  SELECT public.propose_booking_shoot_schedule(
    (SELECT id FROM s10_booking),
    '2030-01-20 10:00:00+05:30'::timestamptz,
    '2030-01-20 12:00:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    'Invalid post-confirmation proposal'
  )
  $$,
  '22023',
  'propose_booking_shoot_schedule: booking must be at Advance Pending',
  'new proposed schedule cannot be created after booking confirmation'
);

-- ---------------------------------------------------------------------
-- Test-only legitimate progression: Stage 8 -> Stage 9.
--
-- This exists only to exercise the frozen reschedule boundary at Stage 9.
-- No Sprint 10 production operation is introduced here.
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
  's10_test_enter_preparation',
  now(),
  '86000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'pre_shoot_preparation'
 AND target.stage_order = 9
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10_booking);

UPDATE public.booking_journey_states js
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    js.version + 1,
  updated_by =
    '86000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10_booking)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'pre_shoot_preparation'
  AND target.stage_order = 9
  AND target.is_active;

-- 95
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
          (SELECT id FROM s10_booking)
  ),
  'pre_shoot_preparation',
  'test fixture progresses legitimately to Pre-Shoot Preparation'
);

-- 96
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  3::bigint,
  'test-only Stage 9 progression increments journey version to 3'
);

-- 97
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_reschedule_v5 AS
  SELECT *
  FROM public.reschedule_booking_shoot(
    (SELECT id FROM s10_booking),
    '2030-01-21 11:00:00+05:30'::timestamptz,
    '2030-01-21 14:00:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'client_home',
    'Family requested home session during preparation',
    'Client residence'
  )
  $$,
  'authoritative shoot may be rescheduled during Stage 9 preparation'
);

-- 98
SELECT is(
  (SELECT schedule_version FROM s10_reschedule_v5),
  5,
  'Stage 9 reschedule becomes schedule version 5'
);

-- 99
SELECT is(
  (SELECT predecessor_schedule_id FROM s10_reschedule_v5),
  (SELECT id FROM s10_reschedule_v4),
  'Stage 9 reschedule version 5 points exactly to reserved version 4'
);

-- 100
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
          (SELECT id FROM s10_booking)
  ),
  'pre_shoot_preparation',
  'Stage 9 reschedule does not move the booking journey'
);

-- 101
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  3::bigint,
  'Stage 9 reschedule does not increment journey version'
);

-- ---------------------------------------------------------------------
-- Test-only legitimate progression: Stage 9 -> Stage 10.
--
-- Stage 10 is the final journey state owned by Sprint 10.
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
  's10_test_mark_shoot_scheduled',
  now(),
  '86000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id =
     js.organization_id
 AND target.stage_key =
     'shoot_scheduled'
 AND target.stage_order = 10
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s10_booking);

UPDATE public.booking_journey_states js
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    js.version + 1,
  updated_by =
    '86000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s10_booking)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'shoot_scheduled'
  AND target.stage_order = 10
  AND target.is_active;

-- 102
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
          (SELECT id FROM s10_booking)
  ),
  'shoot_scheduled',
  'test fixture progresses legitimately to Shoot Scheduled'
);

-- 103
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  4::bigint,
  'test-only Stage 10 progression increments journey version to 4'
);

-- 104
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10_reschedule_v6 AS
  SELECT *
  FROM public.reschedule_booking_shoot(
    (SELECT id FROM s10_booking),
    '2030-01-22 08:00:00+05:30'::timestamptz,
    '2030-01-22 11:00:00+05:30'::timestamptz,
    'Asia/Kolkata',
    'studio',
    'Final timing adjustment after scheduling',
    'Little Shots Studio'
  )
  $$,
  'authoritative shoot may still be rescheduled at Stage 10'
);

-- 105
SELECT is(
  (SELECT schedule_version FROM s10_reschedule_v6),
  6,
  'Stage 10 reschedule becomes schedule version 6'
);

-- 106
SELECT is(
  (SELECT predecessor_schedule_id FROM s10_reschedule_v6),
  (SELECT id FROM s10_reschedule_v5),
  'Stage 10 reschedule version 6 points exactly to reserved version 5'
);

-- 107
SELECT is(
  (SELECT schedule_state FROM s10_reschedule_v6),
  'reserved',
  'Stage 10 reschedule remains reserved evidence'
);

-- 108
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
          (SELECT id FROM s10_booking)
  ),
  'shoot_scheduled',
  'Stage 10 reschedule does not advance booking beyond Shoot Scheduled'
);

-- 109
SELECT is(
  (
    SELECT js.version
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s10_booking)
  ),
  4::bigint,
  'Stage 10 reschedule does not increment journey version'
);

-- 110
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_shoot_schedules s
    WHERE s.booking_id =
          (SELECT id FROM s10_booking)
  ),
  6::bigint,
  'schedule history contains proposals v1-v2 and reserved evidence v3-v6'
);

-- 111
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s10_booking)
      AND t.transition_key =
          'advance_satisfied'
  ),
  1::bigint,
  'Stage 9 and Stage 10 rescheduling preserve one confirmation transition'
);

SELECT * FROM finish();

ROLLBACK;
