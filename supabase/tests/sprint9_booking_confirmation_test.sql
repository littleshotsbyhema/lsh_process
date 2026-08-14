BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(65);

-- =====================================================================
-- Sprint 9 — Slice 2
-- Advance-Satisfied Booking Confirmation
-- =====================================================================

-- =====================================================================
-- Test identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('84000000-0000-0000-0000-000000000001'::uuid),
  ('84000000-0000-0000-0000-000000000002'::uuid),
  ('84000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '84000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '84000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 9 Confirmation Founder'
),
(
  '84000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '84000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 9 Confirmation Photographer'
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
      '84000000-0000-0000-0000-000000000011'::uuid,
      'founder'
    ),
    (
      '84000000-0000-0000-0000-000000000012'::uuid,
      'photographer'
    )
) fixture(member_id, role_key)
JOIN public.roles r
  ON r.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '84000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '84000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-456789',
  'Sprint 9 Confirmation Family',
  'Confirmation Family',
  'active',
  '84000000-0000-0000-0000-000000000011',
  '84000000-0000-0000-0000-000000000011'
);

-- =====================================================================
-- Structure / permission / containment
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions
    WHERE key = 'booking.confirm'
  ),
  1::bigint,
  'booking.confirm permission exists exactly once'
);

-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE r.key = 'founder'
      AND p.key = 'booking.confirm'
  ),
  1::bigint,
  'Founder receives booking.confirm'
);

-- 3
SELECT ok(
  to_regprocedure(
    'public.confirm_booking_after_advance(uuid)'
  ) IS NOT NULL,
  'confirm_booking_after_advance(uuid) exists'
);

-- 4
SELECT ok(
  has_function_privilege(
    'authenticated',
    to_regprocedure(
      'public.confirm_booking_after_advance(uuid)'
    )::oid,
    'EXECUTE'
  ),
  'authenticated can execute controlled confirmation RPC'
);

-- 5
SELECT ok(
  NOT has_function_privilege(
    'anon',
    to_regprocedure(
      'public.confirm_booking_after_advance(uuid)'
    )::oid,
    'EXECUTE'
  ),
  'anon cannot execute confirmation RPC'
);

-- 6
SELECT ok(
  (
    SELECT p.prosecdef
    FROM pg_proc p
    WHERE p.oid =
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid
  ),
  'confirmation RPC is SECURITY DEFINER'
);

-- 7
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_indexes i
    WHERE i.schemaname = 'public'
      AND i.tablename = 'booking_stage_transitions'
      AND i.indexname =
        'booking_stage_transitions_one_advance_confirmation_idx'
  ),
  'one-authoritative-confirmation uniqueness index exists'
);

-- 8
SELECT ok(
  position(
    'public.has_branch_scope'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid
    )
  ) > 0,
  'confirmation RPC contains explicit branch-scope enforcement'
);

-- 9
SELECT ok(
  position(
    'booking requires accepted quotation'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid
    )
  ) > 0,
  'confirmation RPC contains accepted-quotation gate'
);

-- 10
SELECT ok(
  position(
    'booking payment requirement missing'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid
    )
  ) > 0,
  'confirmation RPC requires canonical payment requirement'
);

-- 11
SELECT ok(
  position(
    'payment requirement does not match accepted quotation snapshot'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid
    )
  ) > 0,
  'confirmation RPC validates immutable quotation snapshot'
);

-- 12
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'advance_booking_stage',
        'transition_booking_stage',
        'set_booking_stage',
        'update_booking_stage'
      )
  ),
  0::bigint,
  'Slice 2 introduces no generic booking-stage mutation RPC'
);

-- =====================================================================
-- Build canonical ₹30,000 accepted quotation / booking
-- =====================================================================

CREATE TEMP TABLE s9c_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '84000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9c_quote),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages p
      ON p.organization_id = pv.organization_id
     AND p.id = pv.package_id
    WHERE p.package_key = 'maternity_gold'
      AND pv.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s9c_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9c_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s9c_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s9c_quote)
);

-- 13
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s9c_booking)
  ),
  'advance_pending',
  'accept_quotation still initializes only Advance Pending'
);

-- 14
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
  ),
  1::bigint,
  'accepted booking starts at journey version 1'
);

-- 15
SELECT is(
  (
    SELECT accepted_quotation_total_inr
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
  ),
  30000,
  'confirmation fixture retains immutable ₹30,000 accepted value'
);

-- 16
SELECT is(
  (
    SELECT required_advance_inr
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
  ),
  15000,
  'confirmation fixture requires ₹15,000 advance'
);

-- =====================================================================
-- Eligibility / authorization
-- =====================================================================

-- No organization membership.
SELECT set_config(
  'request.jwt.claim.sub',
  '84000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

-- 17
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s9c_booking)
  )
  $$,
  '42501',
  'confirm_booking_after_advance: active organization membership required',
  'caller without active organization membership cannot confirm'
);

-- Photographer has membership but not booking.confirm.
SELECT set_config(
  'request.jwt.claim.sub',
  '84000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 18
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s9c_booking)
  )
  $$,
  '42501',
  'confirm_booking_after_advance: booking.confirm permission required',
  'role without booking.confirm cannot confirm booking'
);

-- Restore Founder.
SELECT set_config(
  'request.jwt.claim.sub',
  '84000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- 19
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    '84000000-0000-0000-0000-000000009999'::uuid
  )
  $$,
  '22023',
  'confirm_booking_after_advance: booking not found',
  'non-canonical booking cannot be confirmed'
);

-- =====================================================================
-- Financial gate — zero / partial / reversed
-- =====================================================================

-- 20
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s9c_booking)
  )
  $$,
  '22023',
  'confirm_booking_after_advance: required advance has not been satisfied',
  'zero collection cannot confirm booking'
);

CREATE TEMP TABLE s9c_partial_payment AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9c_booking),
  5000,
  'cash'::public.booking_payment_method,
  now(),
  NULL,
  'Sprint 9 confirmation partial-payment test'
);

-- 21
SELECT is(
  (SELECT amount_inr FROM s9c_partial_payment),
  5000,
  'partial payment records ₹5,000 evidence'
);

-- 22
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9c_booking)
    )
  ),
  5000::bigint,
  'payment summary derives ₹5,000 valid collection'
);

-- 23
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s9c_booking)
  )
  $$,
  '22023',
  'confirm_booking_after_advance: required advance has not been satisfied',
  'partial collection cannot confirm booking'
);

CREATE TEMP TABLE s9c_partial_reversal AS
SELECT *
FROM public.reverse_booking_payment(
  (SELECT id FROM s9c_partial_payment),
  'Reverse partial payment for confirmation gate test'
);

-- 24
SELECT is(
  (SELECT reason FROM s9c_partial_reversal),
  'Reverse partial payment for confirmation gate test',
  'partial-payment reversal preserves correction evidence'
);

-- 25
SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9c_booking)
    )
  ),
  0::bigint,
  'reversed payment contributes zero valid collected INR'
);

-- 26
SELECT throws_ok(
  $$
  SELECT public.confirm_booking_after_advance(
    (SELECT id FROM s9c_booking)
  )
  $$,
  '22023',
  'confirm_booking_after_advance: required advance has not been satisfied',
  'reversed collection cannot satisfy booking confirmation'
);

-- =====================================================================
-- Exact ₹15,000 threshold
-- =====================================================================

CREATE TEMP TABLE s9c_exact_payment AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9c_booking),
  15000,
  'upi'::public.booking_payment_method,
  now(),
  'S9-CONFIRM-EXACT',
  'Exact required advance'
);

-- 27
SELECT is(
  (SELECT amount_inr FROM s9c_exact_payment),
  15000,
  'exact required advance is recorded as ₹15,000'
);

-- 28
SELECT is(
  (
    SELECT advance_satisfied
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9c_booking)
    )
  ),
  true,
  'exact required advance satisfies payment gate'
);

-- Sprint 10 regression adaptation:
-- first-time confirmation now requires a current Stage 7 shoot proposal.
-- This is fixture evidence only; the existing Sprint 9 assertions remain
-- unchanged.
CREATE TEMP TABLE s9c_schedule_proposal AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s9c_booking),
  '2030-02-01 10:00:00+05:30'::timestamptz,
  '2030-02-01 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 9 regression studio'
);

-- 29
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s9c_confirm_once AS
  SELECT *
  FROM public.confirm_booking_after_advance(
    (SELECT id FROM s9c_booking)
  )
  $$,
  'exact required advance permits controlled booking confirmation'
);

-- =====================================================================
-- Authoritative Stage 7 -> Stage 8 transition
-- =====================================================================

-- 30
SELECT is(
  (SELECT id FROM s9c_confirm_once),
  (SELECT id FROM s9c_booking),
  'confirmation returns the same canonical booking'
);

-- 31
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s9c_booking)
  ),
  'booking_confirmed',
  'booking advances exactly to Booking Confirmed'
);

-- 32
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
  ),
  2::bigint,
  'confirmation increments journey version exactly once'
);

-- 33
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
      AND transition_key = 'advance_satisfied'
  ),
  1::bigint,
  'exactly one advance-satisfied confirmation transition exists'
);

-- 34
SELECT is(
  (
    SELECT transition_key
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
      AND transition_key = 'advance_satisfied'
  ),
  'advance_satisfied',
  'confirmation transition uses canonical advance_satisfied key'
);

-- 35
SELECT is(
  (
    SELECT source_stage.stage_key
    FROM public.booking_stage_transitions t
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id = t.organization_id
     AND source_stage.id = t.from_stage_id
    WHERE t.booking_id =
          (SELECT id FROM s9c_booking)
      AND t.transition_key = 'advance_satisfied'
  ),
  'advance_pending',
  'confirmation transition starts at Advance Pending'
);

-- 36
SELECT is(
  (
    SELECT target_stage.stage_key
    FROM public.booking_stage_transitions t
    JOIN public.booking_journey_stages target_stage
      ON target_stage.organization_id = t.organization_id
     AND target_stage.id = t.to_stage_id
    WHERE t.booking_id =
          (SELECT id FROM s9c_booking)
      AND t.transition_key = 'advance_satisfied'
  ),
  'booking_confirmed',
  'confirmation transition ends at Booking Confirmed'
);

-- 37
SELECT is(
  (
    SELECT js.stage_entered_at
    FROM public.booking_journey_states js
    WHERE js.booking_id =
          (SELECT id FROM s9c_booking)
  ),
  (
    SELECT t.transitioned_at
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s9c_booking)
      AND t.transition_key = 'advance_satisfied'
  ),
  'current-state timestamp matches authoritative confirmation transition'
);

-- 38
SELECT is(
  (
    SELECT updated_by
    FROM public.booking_journey_states
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
  ),
  '84000000-0000-0000-0000-000000000011'::uuid,
  'journey current state preserves confirming actor'
);

-- 39
SELECT is(
  (
    SELECT transitioned_by
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
      AND transition_key = 'advance_satisfied'
  ),
  '84000000-0000-0000-0000-000000000011'::uuid,
  'historical confirmation transition preserves confirming actor'
);

-- =====================================================================
-- Audit evidence
-- =====================================================================

-- 40
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events e
    WHERE e.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
      AND e.entity_type = 'booking'
      AND e.entity_id =
          (SELECT id FROM s9c_booking)
      AND e.action_key =
          'booking.confirmed_after_advance'
      AND e.is_sensitive
  ),
  'booking confirmation appends sensitive audit evidence'
);

-- 41
SELECT is(
  (
    SELECT e.actor_member_id
    FROM public.audit_events e
    WHERE e.entity_type = 'booking'
      AND e.entity_id =
          (SELECT id FROM s9c_booking)
      AND e.action_key =
          'booking.confirmed_after_advance'
    LIMIT 1
  ),
  '84000000-0000-0000-0000-000000000011'::uuid,
  'booking confirmation audit preserves Founder actor provenance'
);

-- 42
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events e
    WHERE e.entity_type = 'booking'
      AND e.entity_id =
          (SELECT id FROM s9c_booking)
      AND e.action_key =
          'booking.confirmed_after_advance'
      AND e.old_values->>'journey_stage' =
          'advance_pending'
      AND e.new_values->>'journey_stage' =
          'booking_confirmed'
  ),
  'confirmation audit preserves Stage 7 to Stage 8 lifecycle evidence'
);

-- 43
SELECT ok(
  position(
    'required_advance_inr'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid
    )
  ) > 0
  AND
  position(
    'valid_collected_inr'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.confirm_booking_after_advance(uuid)'
      )::oid
    )
  ) > 0,
  'confirmation audit path contains safe threshold evidence fields'
);

-- =====================================================================
-- Immediate idempotent replay
-- =====================================================================

CREATE TEMP TABLE s9c_confirm_replay AS
SELECT *
FROM public.confirm_booking_after_advance(
  (SELECT id FROM s9c_booking)
);

-- 44
SELECT is(
  (SELECT id FROM s9c_confirm_replay),
  (SELECT id FROM s9c_booking),
  'immediate confirmation replay returns same booking'
);

-- 45
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
  ),
  2::bigint,
  'immediate replay does not increment journey version'
);

-- 46
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
      AND transition_key = 'advance_satisfied'
  ),
  1::bigint,
  'immediate replay does not append duplicate confirmation evidence'
);

-- =====================================================================
-- Reversal after valid historical confirmation
-- =====================================================================

-- 47
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s9c_post_confirm_reversal AS
  SELECT *
  FROM public.reverse_booking_payment(
    (SELECT id FROM s9c_exact_payment),
    'Post-confirmation payment correction test'
  )
  $$,
  'payment may be reversed after historical booking confirmation'
);

-- 48
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s9c_booking)
  ),
  'booking_confirmed',
  'post-confirmation reversal does not rewind booking journey'
);

-- 49
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
      AND transition_key = 'advance_satisfied'
  ),
  1::bigint,
  'historical confirmation transition survives later reversal'
);

-- 50
SELECT is(
  (
    SELECT advance_satisfied
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9c_booking)
    )
  ),
  false,
  'payment summary reports current advance no longer satisfied'
);

-- 51
SELECT is(
  (
    SELECT confirmed_with_advance_shortfall
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9c_booking)
    )
  ),
  true,
  'confirmed booking with later payment reversal exposes advance shortfall'
);

-- 52
SELECT is(
  (
    SELECT advance_outstanding_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9c_booking)
    )
  ),
  15000::bigint,
  'post-confirmation reversal exposes full ₹15,000 current shortfall'
);

CREATE TEMP TABLE s9c_replay_after_reversal AS
SELECT *
FROM public.confirm_booking_after_advance(
  (SELECT id FROM s9c_booking)
);

-- 53
SELECT is(
  (SELECT id FROM s9c_replay_after_reversal),
  (SELECT id FROM s9c_booking),
  'historical confirmation remains idempotent despite later shortfall'
);

-- 54
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
          (SELECT id FROM s9c_booking)
  ),
  2::bigint,
  'shortfall replay does not mutate confirmed journey version'
);

-- =====================================================================
-- Overpayment can satisfy confirmation
-- =====================================================================

CREATE TEMP TABLE s9c_over_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '84000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9c_over_quote),
  (
    SELECT pv.id
    FROM public.commercial_package_versions pv
    JOIN public.commercial_packages p
      ON p.organization_id = pv.organization_id
     AND p.id = pv.package_id
    WHERE p.package_key = 'newborn_bronze'
      AND pv.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s9c_over_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9c_over_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s9c_over_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s9c_over_quote)
);

-- 55
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s9c_over_booking)
  ),
  'advance_pending',
  'overpayment fixture also starts at Advance Pending'
);

CREATE TEMP TABLE s9c_over_payment AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9c_over_booking),
  8000,
  'bank_transfer'::public.booking_payment_method,
  now(),
  'S9-CONFIRM-OVER',
  'Overpayment confirmation test'
);

-- 56
SELECT ok(
  (
    SELECT valid_collected_inr >
           required_advance_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9c_over_booking)
    )
  ),
  'overpayment fixture exceeds immutable required advance'
);

-- Sprint 10 regression adaptation for the independent overpayment
-- fixture. First-time confirmation requires its own Stage 7 proposal.
CREATE TEMP TABLE s9c_over_schedule_proposal AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s9c_over_booking),
  '2030-02-02 09:00:00+05:30'::timestamptz,
  '2030-02-02 11:30:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 9 overpayment regression studio'
);

-- 57
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s9c_over_confirm AS
  SELECT *
  FROM public.confirm_booking_after_advance(
    (SELECT id FROM s9c_over_booking)
  )
  $$,
  'overpayment may confirm booking without changing requirement'
);

-- 58
SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s9c_over_booking)
  ),
  'booking_confirmed',
  'overpayment confirmation ends at Booking Confirmed'
);

-- =====================================================================
-- Idempotency after legitimate later journey progression
-- =====================================================================

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
  'post_confirmation_test_progression',
  now(),
  '84000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id = js.organization_id
 AND target.stage_order = 9
 AND target.is_active
WHERE js.booking_id =
      (SELECT id FROM s9c_over_booking);

UPDATE public.booking_journey_states js
SET
  current_stage_id = target.id,
  stage_entered_at = now(),
  version = js.version + 1,
  updated_by =
    '84000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s9c_over_booking)
  AND target.organization_id =
      js.organization_id
  AND target.stage_order = 9
  AND target.is_active;

-- 59
SELECT is(
  (
    SELECT s.stage_order
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s9c_over_booking)
  ),
  9::smallint,
  'fixture progresses legitimately beyond Booking Confirmed'
);

CREATE TEMP TABLE s9c_replay_after_progress AS
SELECT *
FROM public.confirm_booking_after_advance(
  (SELECT id FROM s9c_over_booking)
);

-- 60
SELECT is(
  (SELECT id FROM s9c_replay_after_progress),
  (SELECT id FROM s9c_over_booking),
  'confirmation replay remains idempotent after later journey progression'
);

-- 61
SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
          (SELECT id FROM s9c_over_booking)
  ),
  3::bigint,
  'later-stage confirmation replay does not change journey version'
);

-- 62
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s9c_over_booking)
      AND transition_key = 'advance_satisfied'
  ),
  1::bigint,
  'later-stage replay retains exactly one historical confirmation'
);

-- =====================================================================
-- Sprint 8 regression / immutable evidence
-- =====================================================================

-- 63
SELECT throws_ok(
  $$
  UPDATE public.quotations
  SET accepted_at = accepted_at + interval '1 second'
  WHERE id = (
    SELECT id FROM s9c_quote
  )
  $$,
  'P0001',
  'accepted quotations are immutable',
  'accepted quotation immutability survives Slice 2'
);

-- 64
SELECT throws_ok(
  $$
  UPDATE public.booking_stage_transitions
  SET transition_key = 'tampered'
  WHERE booking_id = (
    SELECT id FROM s9c_booking
  )
    AND transition_key = 'advance_satisfied'
  $$,
  'P0001',
  'booking stage transition history is append-only',
  'confirmation transition evidence remains append-only'
);

-- 65
SELECT is(
  (
    SELECT source_quotation_id
    FROM public.bookings
    WHERE id =
          (SELECT id FROM s9c_booking)
  ),
  (SELECT id FROM s9c_quote),
  'booking identity retains immutable accepted-quotation provenance'
);

SELECT * FROM finish();

ROLLBACK;
