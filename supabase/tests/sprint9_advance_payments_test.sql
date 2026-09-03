BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(79);

-- =====================================================================
-- Sprint 9 — Advance Payment Evidence Foundation
-- Executable pgTAP coverage
-- =====================================================================

-- =====================================================================
-- Test identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('83000000-0000-0000-0000-000000000001'::uuid),
  ('83000000-0000-0000-0000-000000000002'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '83000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '83000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 9 Payment Founder'
),
(
  '83000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '83000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 9 Payment Photographer'
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
  CASE
    WHEN fixture.role_key = 'founder' THEN NULL::uuid
    ELSE 'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
  END
FROM (
  VALUES
    (
      '83000000-0000-0000-0000-000000000011'::uuid,
      'founder'
    ),
    (
      '83000000-0000-0000-0000-000000000012'::uuid,
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
  '83000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"83000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '83000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  'QT-345678',
  'Sprint 9 Payment Family',
  'Payment Family',
  'active',
  '83000000-0000-0000-0000-000000000011',
  '83000000-0000-0000-0000-000000000011'
);

-- =====================================================================
-- Structure / permissions / ACL
-- =====================================================================

SELECT has_table(
  'public',
  'booking_payment_requirements',
  'booking_payment_requirements exists'
);

SELECT has_table(
  'public',
  'booking_payments',
  'booking_payments exists'
);

SELECT has_table(
  'public',
  'booking_payment_reversals',
  'booking_payment_reversals exists'
);

SELECT has_type(
  'public',
  'booking_payment_method',
  'booking_payment_method exists'
);

SELECT is(
  (
    SELECT string_agg(
      e.enumlabel,
      ','
      ORDER BY e.enumsortorder
    )
    FROM pg_type t
    JOIN pg_namespace n
      ON n.oid = t.typnamespace
    JOIN pg_enum e
      ON e.enumtypid = t.oid
    WHERE n.nspname = 'public'
      AND t.typname = 'booking_payment_method'
  ),
  'cash,upi,bank_transfer,card,other',
  'payment-method vocabulary is frozen'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions
    WHERE key IN (
      'payment.read',
      'payment.record',
      'payment.reverse'
    )
  ),
  3::bigint,
  'three Sprint 9 payment permissions exist'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE r.key = 'founder'
      AND p.key IN (
        'payment.read',
        'payment.record',
        'payment.reverse'
      )
  ),
  3::bigint,
  'Founder receives all three Sprint 9 payment permissions'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'booking_payment_requirements',
        'booking_payments',
        'booking_payment_reversals'
      )
      AND c.relrowsecurity
      AND c.relforcerowsecurity
  ),
  3::bigint,
  'all payment tables have RLS and FORCE RLS'
);

SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_payment_requirements',
    'SELECT'
  ),
  'authenticated can SELECT payment requirements subject to RLS'
);

SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_payments',
    'SELECT'
  ),
  'authenticated can SELECT payments subject to RLS'
);

SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_payment_reversals',
    'SELECT'
  ),
  'authenticated can SELECT reversals subject to RLS'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_payment_requirements',
    'INSERT'
  ),
  'authenticated cannot directly INSERT payment requirements'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_payments',
    'INSERT'
  ),
  'authenticated cannot directly INSERT payments'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_payment_reversals',
    'INSERT'
  ),
  'authenticated cannot directly INSERT reversals'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_payments',
    'UPDATE'
  ),
  'authenticated cannot directly UPDATE payments'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_payments',
    'DELETE'
  ),
  'authenticated cannot directly DELETE payments'
);

SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.booking_payments',
    'SELECT'
  ),
  'anon cannot SELECT payments'
);

SELECT ok(
  to_regprocedure(
    'public.record_booking_payment(uuid,integer,public.booking_payment_method,timestamp with time zone,text,text)'
  ) IS NOT NULL,
  'record_booking_payment exists'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    to_regprocedure(
      'public.record_booking_payment(uuid,integer,public.booking_payment_method,timestamp with time zone,text,text)'
    )::oid,
    'EXECUTE'
  ),
  'authenticated can execute record_booking_payment'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    to_regprocedure(
      'public.record_booking_payment(uuid,integer,public.booking_payment_method,timestamp with time zone,text,text)'
    )::oid,
    'EXECUTE'
  ),
  'anon cannot execute record_booking_payment'
);

SELECT ok(
  to_regprocedure(
    'public.reverse_booking_payment(uuid,text)'
  ) IS NOT NULL,
  'reverse_booking_payment exists'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    to_regprocedure(
      'public.reverse_booking_payment(uuid,text)'
    )::oid,
    'EXECUTE'
  ),
  'authenticated can execute reverse_booking_payment'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    to_regprocedure(
      'public.reverse_booking_payment(uuid,text)'
    )::oid,
    'EXECUTE'
  ),
  'anon cannot execute reverse_booking_payment'
);

SELECT ok(
  to_regprocedure(
    'public.get_booking_payment_summary(uuid)'
  ) IS NOT NULL,
  'get_booking_payment_summary exists'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    to_regprocedure(
      'public.get_booking_payment_summary(uuid)'
    )::oid,
    'EXECUTE'
  ),
  'authenticated can execute payment summary'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    to_regprocedure(
      'public.get_booking_payment_summary(uuid)'
    )::oid,
    'EXECUTE'
  ),
  'anon cannot execute payment summary'
);

-- =====================================================================
-- Founder payment capability
-- =====================================================================

SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'payment.read',
    NULL
  ),
  'Founder has payment.read'
);

SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'payment.record',
    NULL
  ),
  'Founder has payment.record'
);

SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'payment.reverse',
    NULL
  ),
  'Founder has payment.reverse'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '83000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"83000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

SELECT ok(
  NOT public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'payment.record',
    NULL
  ),
  'Photographer does not receive payment.record'
);

-- Restore Founder for fixture creation.
SELECT set_config(
  'request.jwt.claim.sub',
  '83000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"83000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- =====================================================================
-- Even quotation: ₹30,000 -> ₹15,000 advance
-- =====================================================================

CREATE TEMP TABLE s9_even_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '83000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9_even_quote),
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
  (SELECT id FROM s9_even_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9_even_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s9_even_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s9_even_quote)
);

SELECT is(
  (
    SELECT quoted_total_inr
    FROM public.quotations
    WHERE id = (SELECT id FROM s9_even_quote)
  ),
  30000,
  'even quotation fixture totals ₹30,000'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9_even_booking)
  ),
  1::bigint,
  'accepted quotation creates exactly one payment requirement'
);

SELECT is(
  (
    SELECT accepted_quotation_total_inr
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9_even_booking)
  ),
  30000,
  'payment requirement snapshots accepted quotation total'
);

SELECT is(
  (
    SELECT required_advance_inr
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9_even_booking)
  ),
  15000,
  '₹30,000 accepted quotation requires ₹15,000 advance'
);

SELECT is(
  (
    SELECT advance_percentage
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9_even_booking)
  ),
  50,
  'advance percentage is frozen at 50'
);

SELECT is(
  (
    SELECT calculation_rule
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9_even_booking)
  ),
  'accepted_quote_50_percent_round_half_up',
  'payment requirement preserves frozen calculation rule'
);

SELECT throws_ok(
  $$
  UPDATE public.booking_payment_requirements
  SET required_advance_inr = required_advance_inr + 1
  WHERE booking_id = (
    SELECT id FROM s9_even_booking
  )
  $$,
  'P0001',
  'booking payment requirements are immutable',
  'payment requirement cannot be updated'
);

SELECT throws_ok(
  $$
  DELETE FROM public.booking_payment_requirements
  WHERE booking_id = (
    SELECT id FROM s9_even_booking
  )
  $$,
  'P0001',
  'booking payment requirements are immutable',
  'payment requirement cannot be deleted'
);

-- =====================================================================
-- Odd quotation: ₹15,001 -> ₹7,501 advance
-- =====================================================================

CREATE TEMP TABLE s9_odd_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '83000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9_odd_quote),
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

SELECT public.add_quotation_custom_line(
  (SELECT id FROM s9_odd_quote),
  'Odd rupee adjustment test',
  'Founder-authorized test-only custom line',
  1,
  1
);

SELECT public.transition_quotation(
  (SELECT id FROM s9_odd_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9_odd_quote),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s9_odd_booking AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s9_odd_quote)
);

SELECT is(
  (
    SELECT quoted_total_inr
    FROM public.quotations
    WHERE id = (SELECT id FROM s9_odd_quote)
  ),
  15001,
  'odd quotation fixture totals ₹15,001'
);

SELECT is(
  (
    SELECT required_advance_inr
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9_odd_booking)
  ),
  7501,
  '₹15,001 rounds half-rupee upward to ₹7,501'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payment_requirements
    WHERE booking_id =
          (SELECT id FROM s9_odd_booking)
  ),
  1::bigint,
  'odd quotation booking receives exactly one requirement'
);

SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s9_odd_booking)
  ),
  'advance_pending',
  'Sprint 9 requirement initialization preserves Advance Pending booking state'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'bookings'
      AND column_name IN (
        'advance',
        'advance_paid',
        'balance',
        'balance_due',
        'paid',
        'paid_total',
        'payment',
        'payment_status',
        'receipt',
        'receipt_id',
        'refund',
        'refund_status'
      )
  ),
  'no mutable payment truth is added to bookings'
);

SELECT throws_ok(
  $$
  UPDATE public.quotations
  SET accepted_at = accepted_at + interval '1 second'
  WHERE id = (
    SELECT id FROM s9_even_quote
  )
  $$,
  'P0001',
  'accepted quotations are immutable',
  'Sprint 8 accepted quotation immutability remains intact'
);

-- =====================================================================
-- Permission enforcement
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '83000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"83000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
  SELECT public.record_booking_payment(
    (SELECT id FROM s9_even_booking),
    1000,
    'cash'::public.booking_payment_method,
    now(),
    NULL,
    NULL
  )
  $$,
  '42501',
  'record_booking_payment: payment.record permission required',
  'Photographer cannot record booking payment'
);

SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_booking_payment_summary(
    (SELECT id FROM s9_even_booking)
  )
  $$,
  '42501',
  'get_booking_payment_summary: payment.read permission required',
  'Photographer cannot read payment summary'
);

-- Restore Founder.
SELECT set_config(
  'request.jwt.claim.sub',
  '83000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"83000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- =====================================================================
-- Payment validation
-- =====================================================================

SELECT throws_ok(
  $$
  SELECT public.record_booking_payment(
    (SELECT id FROM s9_even_booking),
    0,
    'cash'::public.booking_payment_method,
    now(),
    NULL,
    NULL
  )
  $$,
  '22023',
  'record_booking_payment: amount_inr must be greater than zero',
  'zero-value payment is rejected'
);

SELECT throws_ok(
  $$
  SELECT public.record_booking_payment(
    (SELECT id FROM s9_even_booking),
    -100,
    'cash'::public.booking_payment_method,
    now(),
    NULL,
    NULL
  )
  $$,
  '22023',
  'record_booking_payment: amount_inr must be greater than zero',
  'negative payment is rejected'
);

-- =====================================================================
-- Partial payment
-- =====================================================================

CREATE TEMP TABLE s9_payment_one AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9_even_booking),
  5000,
  'cash'::public.booking_payment_method,
  now(),
  NULL,
  NULL
);

SELECT ok(
  (
    SELECT payment_reference ~
           '^LSH-PAY-[A-F0-9]{8}$'
    FROM s9_payment_one
  ),
  'payment receives canonical LSH-PAY reference'
);

SELECT is(
  (SELECT amount_inr FROM s9_payment_one),
  5000,
  'payment stores whole-INR amount'
);

SELECT is(
  (SELECT payment_method::text FROM s9_payment_one),
  'cash',
  'payment stores frozen payment method'
);

SELECT is(
  (SELECT external_reference FROM s9_payment_one),
  NULL::text,
  'cash payment may omit external reference'
);

SELECT is(
  (SELECT recorded_by FROM s9_payment_one),
  '83000000-0000-0000-0000-000000000011'::uuid,
  'payment preserves Founder actor provenance'
);

SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  5000::bigint,
  'partial payment derives ₹5,000 valid collected'
);

SELECT is(
  (
    SELECT advance_outstanding_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  10000::bigint,
  'partial payment leaves ₹10,000 advance outstanding'
);

SELECT is(
  (
    SELECT advance_satisfied
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  false,
  'partial payment does not satisfy advance'
);

-- =====================================================================
-- Multiple payments / exact threshold
-- =====================================================================

CREATE TEMP TABLE s9_payment_two AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9_even_booking),
  10000,
  'upi'::public.booking_payment_method,
  now(),
  'S9-UPI-001',
  'Exact advance threshold test'
);

SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  15000::bigint,
  'multiple payments accumulate to exact advance threshold'
);

SELECT is(
  (
    SELECT advance_satisfied
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  true,
  'exact required advance marks advance satisfied'
);

SELECT is(
  (
    SELECT payment_count
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  2::bigint,
  'payment summary counts both receipts'
);

-- =====================================================================
-- Overpayment
-- =====================================================================

CREATE TEMP TABLE s9_payment_three AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9_even_booking),
  1000,
  'bank_transfer'::public.booking_payment_method,
  now(),
  'S9-BANK-OVER',
  'Overpayment evidence test'
);

SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  16000::bigint,
  'overpayment is preserved as collected payment evidence'
);

SELECT is(
  (
    SELECT required_advance_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  15000,
  'overpayment does not change required advance'
);

SELECT is(
  (
    SELECT advance_outstanding_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  0::bigint,
  'advance outstanding never becomes negative'
);

-- =====================================================================
-- Reversal
-- =====================================================================

CREATE TEMP TABLE s9_reversal_one AS
SELECT *
FROM public.reverse_booking_payment(
  (SELECT id FROM s9_payment_two),
  'Incorrect UPI receipt recorded'
);

SELECT is(
  (SELECT reason FROM s9_reversal_one),
  'Incorrect UPI receipt recorded',
  'reversal preserves correction reason'
);

SELECT is(
  (SELECT reversed_by FROM s9_reversal_one),
  '83000000-0000-0000-0000-000000000011'::uuid,
  'reversal preserves Founder actor provenance'
);

SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  6000::bigint,
  'reversed payment is excluded from valid collected amount'
);

SELECT is(
  (
    SELECT reversal_count
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  1::bigint,
  'payment summary counts reversal evidence'
);

SELECT is(
  (
    SELECT advance_satisfied
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  false,
  'reversal can create a current advance shortfall'
);

SELECT throws_ok(
  $$
  SELECT public.reverse_booking_payment(
    (SELECT id FROM s9_payment_two),
    'Attempt duplicate reversal'
  )
  $$,
  '22023',
  'reverse_booking_payment: payment is already reversed',
  'one payment may be reversed only once'
);

-- =====================================================================
-- Append-only evidence
-- =====================================================================

SELECT throws_ok(
  $$
  UPDATE public.booking_payments
  SET amount_inr = amount_inr + 1
  WHERE id = (
    SELECT id FROM s9_payment_one
  )
  $$,
  'P0001',
  'booking payments are append-only and immutable',
  'payment evidence cannot be updated'
);

SELECT throws_ok(
  $$
  DELETE FROM public.booking_payments
  WHERE id = (
    SELECT id FROM s9_payment_one
  )
  $$,
  'P0001',
  'booking payments are append-only and immutable',
  'payment evidence cannot be deleted'
);

SELECT throws_ok(
  $$
  UPDATE public.booking_payment_reversals
  SET reason = 'Tampered'
  WHERE id = (
    SELECT id FROM s9_reversal_one
  )
  $$,
  'P0001',
  'booking payment reversals are append-only and immutable',
  'reversal evidence cannot be updated'
);

SELECT throws_ok(
  $$
  DELETE FROM public.booking_payment_reversals
  WHERE id = (
    SELECT id FROM s9_reversal_one
  )
  $$,
  'P0001',
  'booking payment reversals are append-only and immutable',
  'reversal evidence cannot be deleted'
);

-- =====================================================================
-- Audit evidence
-- =====================================================================

SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events e
    WHERE e.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
      AND e.entity_type = 'booking_payment'
      AND e.entity_id =
          (SELECT id FROM s9_payment_one)
      AND e.action_key = 'payment.recorded'
      AND e.actor_member_id =
          '83000000-0000-0000-0000-000000000011'::uuid
      AND e.is_sensitive
  ),
  'recorded payment appends sensitive actor-attributed audit evidence'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events e
    WHERE e.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
      AND e.entity_type =
          'booking_payment_reversal'
      AND e.entity_id =
          (SELECT id FROM s9_reversal_one)
      AND e.action_key = 'payment.reversed'
      AND e.actor_member_id =
          '83000000-0000-0000-0000-000000000011'::uuid
      AND e.is_sensitive
  ),
  'payment reversal appends sensitive actor-attributed audit evidence'
);

-- =====================================================================
-- Correction = reversal + new immutable receipt
-- =====================================================================

CREATE TEMP TABLE s9_payment_correction AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9_even_booking),
  9000,
  'card'::public.booking_payment_method,
  now(),
  'S9-CARD-CORRECTION',
  'Replacement for reversed UPI receipt'
);

SELECT is(
  (
    SELECT valid_collected_inr
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  15000::bigint,
  'replacement receipt restores valid collected amount to ₹15,000'
);

SELECT is(
  (
    SELECT payment_count
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  4::bigint,
  'correction preserves all four immutable payment receipt rows'
);

SELECT is(
  (
    SELECT reversal_count
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  1::bigint,
  'correction preserves one immutable reversal row'
);

SELECT is(
  (
    SELECT advance_satisfied
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  true,
  'replacement payment restores advance satisfaction'
);

SELECT is(
  (
    SELECT confirmed_with_advance_shortfall
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9_even_booking)
    )
  ),
  false,
  'unconfirmed booking is not falsely flagged as confirmed with shortfall'
);

SELECT * FROM finish();

ROLLBACK;
