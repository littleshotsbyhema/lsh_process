BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(68);

-- =====================================================================
-- Sprint 9 — Slice 3
-- Founder KPI / Read Model Foundation
-- =====================================================================

-- =====================================================================
-- Identities / deterministic reporting clock
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('85000000-0000-0000-0000-000000000001'::uuid),
  ('85000000-0000-0000-0000-000000000002'::uuid),
  ('85000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '85000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '85000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 9 KPI Founder'
),
(
  '85000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '85000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 9 KPI Photographer'
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
      '85000000-0000-0000-0000-000000000011'::uuid,
      'founder'
    ),
    (
      '85000000-0000-0000-0000-000000000012'::uuid,
      'photographer'
    )
) fixture(member_id, role_key)
JOIN public.roles r
  ON r.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE TEMP TABLE s9k_clock AS
SELECT
  now() AS t0,
  now() - interval '1 hour' AS period_start,
  now() + interval '1 hour' AS period_end,
  now() - interval '4 hours' AS empty_start,
  now() - interval '3 hours' AS empty_end;

SELECT set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"85000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- =====================================================================
-- Structure / permission / hardening
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions
    WHERE key = 'kpi.read'
  ),
  1::bigint,
  'kpi.read permission exists exactly once'
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
      AND p.key = 'kpi.read'
  ),
  1::bigint,
  'Founder receives kpi.read'
);

-- 3
SELECT ok(
  to_regprocedure(
    'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
  ) IS NOT NULL,
  'Founder KPI summary RPC exists'
);

-- 4
SELECT ok(
  to_regprocedure(
    'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
  ) IS NOT NULL,
  'Founder booking-stage KPI RPC exists'
);

-- 5
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_proc p
    WHERE p.oid IN (
      to_regprocedure(
        'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
      )::oid,
      to_regprocedure(
        'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
      )::oid
    )
      AND p.prosecdef
  ),
  2::bigint,
  'both KPI RPCs are SECURITY DEFINER'
);

-- 6
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_proc p
    WHERE p.oid IN (
      to_regprocedure(
        'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
      )::oid,
      to_regprocedure(
        'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
      )::oid
    )
      AND p.provolatile = 's'
  ),
  2::bigint,
  'both KPI RPCs are STABLE read models'
);

-- 7
SELECT ok(
  has_function_privilege(
    'authenticated',
    to_regprocedure(
      'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
    )::oid,
    'EXECUTE'
  )
  AND
  has_function_privilege(
    'authenticated',
    to_regprocedure(
      'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
    )::oid,
    'EXECUTE'
  ),
  'authenticated role may execute both controlled KPI RPCs'
);

-- 8
SELECT ok(
  NOT has_function_privilege(
    'anon',
    to_regprocedure(
      'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
    )::oid,
    'EXECUTE'
  )
  AND
  NOT has_function_privilege(
    'anon',
    to_regprocedure(
      'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
    )::oid,
    'EXECUTE'
  ),
  'anon cannot execute either KPI RPC'
);

-- 9
SELECT ok(
  position(
    'revenue'
    IN lower(
      pg_get_function_result(
        to_regprocedure(
          'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
        )::oid
      )
    )
  ) = 0
  AND
  position(
    'revenue'
    IN lower(
      pg_get_function_result(
        to_regprocedure(
          'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
        )::oid
      )
    )
  ) = 0,
  'KPI public contracts expose no revenue field'
);

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND (
        c.relname LIKE 'founder_kpi%'
        OR c.relname LIKE 'kpi_%'
      )
      AND c.relkind IN ('r', 'v', 'm')
  ),
  0::bigint,
  'no raw KPI table, view, or materialized-view truth is introduced'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_journey_stages
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND is_active
  ),
  21::bigint,
  'canonical journey remains exactly 21 active stages'
);

-- 12
SELECT ok(
  position(
    'public.has_branch_scope'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
      )::oid
    )
  ) > 0
  AND
  position(
    'public.has_branch_scope'
    IN pg_get_functiondef(
      to_regprocedure(
        'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
      )::oid
    )
  ) > 0,
  'both KPI RPCs contain explicit branch-scope enforcement'
);

-- 13
SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'kpi.read',
    NULL
  ),
  'Founder has organization-wide kpi.read'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"85000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 14
SELECT ok(
  NOT public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'kpi.read',
    NULL
  ),
  'Photographer does not receive kpi.read'
);

-- Restore Founder.
SELECT set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"85000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- =====================================================================
-- Input validation / authorization
-- =====================================================================

-- 15
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_kpi_summary(
    NULL,
    (SELECT period_start FROM s9k_clock),
    (SELECT period_end FROM s9k_clock),
    NULL
  )
  $$,
  '22023',
  'get_founder_kpi_summary: organization_id is required',
  'summary rejects null organization'
);

-- 16
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_kpi_summary(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    NULL,
    (SELECT period_end FROM s9k_clock),
    NULL
  )
  $$,
  '22023',
  'get_founder_kpi_summary: period_start is required',
  'summary rejects null period start'
);

-- 17
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_kpi_summary(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    (SELECT period_start FROM s9k_clock),
    NULL,
    NULL
  )
  $$,
  '22023',
  'get_founder_kpi_summary: period_end is required',
  'summary rejects null period end'
);

-- 18
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_kpi_summary(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    (SELECT period_end FROM s9k_clock),
    (SELECT period_start FROM s9k_clock),
    NULL
  )
  $$,
  '22023',
  'get_founder_kpi_summary: period_start must be earlier than period_end',
  'summary rejects inverted period'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"85000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

-- 19
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_kpi_summary(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    (SELECT period_start FROM s9k_clock),
    (SELECT period_end FROM s9k_clock),
    NULL
  )
  $$,
  '42501',
  'get_founder_kpi_summary: active organization membership required',
  'summary requires active organization membership'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"85000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

-- 20
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_kpi_summary(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    (SELECT period_start FROM s9k_clock),
    (SELECT period_end FROM s9k_clock),
    NULL
  )
  $$,
  '42501',
  'get_founder_kpi_summary: organization-wide kpi.read permission required',
  'summary requires organization-wide kpi.read'
);

-- 21
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_booking_stage_kpis(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    NULL,
    NULL
  )
  $$,
  '22023',
  'get_founder_booking_stage_kpis: as_of is required',
  'stage KPI rejects null as-of timestamp'
);

-- 22
SELECT throws_ok(
  $$
  SELECT *
  FROM public.get_founder_booking_stage_kpis(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    (SELECT period_end FROM s9k_clock),
    NULL
  )
  $$,
  '42501',
  'get_founder_booking_stage_kpis: organization-wide kpi.read permission required',
  'stage KPI requires organization-wide kpi.read'
);

-- Restore Founder for canonical fixtures.
SELECT set_config(
  'request.jwt.claim.sub',
  '85000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"85000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- =====================================================================
-- Four inquiry cohort members
--   A: accepted + booked + confirmed, overpaid as-of cutoff
--   B: accepted + booked + confirmed, then payment reversed
--   C: accepted + booked, remains Advance Pending
--   D: quote sent only
-- =====================================================================

INSERT INTO public.leads (
  id,
  organization_id,
  branch_id,
  lead_reference,
  source,
  parent_name,
  email,
  created_by,
  updated_by
)
VALUES
(
  '85000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-LD-85000101',
  'sprint9_kpi_test',
  'KPI Parent A',
  'kpi-a@example.com',
  '85000000-0000-0000-0000-000000000011',
  '85000000-0000-0000-0000-000000000011'
),
(
  '85000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-LD-85000102',
  'sprint9_kpi_test',
  'KPI Parent B',
  'kpi-b@example.com',
  '85000000-0000-0000-0000-000000000011',
  '85000000-0000-0000-0000-000000000011'
),
(
  '85000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-LD-85000103',
  'sprint9_kpi_test',
  'KPI Parent C',
  'kpi-c@example.com',
  '85000000-0000-0000-0000-000000000011',
  '85000000-0000-0000-0000-000000000011'
),
(
  '85000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-LD-85000104',
  'sprint9_kpi_test',
  'KPI Parent D',
  'kpi-d@example.com',
  '85000000-0000-0000-0000-000000000011',
  '85000000-0000-0000-0000-000000000011'
);

-- ---------------------------------------------------------------------
-- Quote A — Maternity Gold ₹30,000
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s9k_quote_a AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  '85000000-0000-0000-0000-000000000101',
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9k_quote_a),
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
  (SELECT id FROM s9k_quote_a),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9k_quote_a),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s9k_booking_a AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s9k_quote_a)
);

-- ---------------------------------------------------------------------
-- Quote B — Newborn Bronze ₹15,000
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s9k_quote_b AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  '85000000-0000-0000-0000-000000000102',
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9k_quote_b),
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
  (SELECT id FROM s9k_quote_b),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9k_quote_b),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s9k_booking_b AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s9k_quote_b)
);

-- ---------------------------------------------------------------------
-- Quote C — Newborn Bronze ₹15,000, remains Advance Pending
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s9k_quote_c AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  '85000000-0000-0000-0000-000000000103',
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9k_quote_c),
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
  (SELECT id FROM s9k_quote_c),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9k_quote_c),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s9k_booking_c AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s9k_quote_c)
);

-- ---------------------------------------------------------------------
-- Quote D — Newborn Bronze ₹15,000, sent but not accepted
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s9k_quote_d AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  '85000000-0000-0000-0000-000000000104',
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s9k_quote_d),
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
  (SELECT id FROM s9k_quote_d),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s9k_quote_d),
  'sent'::public.quotation_status
);

-- =====================================================================
-- Payment / confirmation evidence
-- =====================================================================

-- Booking A:
--   ₹5,000 reversed before report end
--   ₹15,000 valid
--   ₹1,000 reversed only AFTER report end
-- Historical valid collection at cutoff = ₹16,000.

CREATE TEMP TABLE s9k_a_payment_reversed AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9k_booking_a),
  5000,
  'cash'::public.booking_payment_method,
  (SELECT t0 FROM s9k_clock),
  NULL,
  'KPI reversal-before-end fixture'
);

SELECT public.reverse_booking_payment(
  (SELECT id FROM s9k_a_payment_reversed),
  'KPI reversal before period end'
);

CREATE TEMP TABLE s9k_a_payment_valid AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9k_booking_a),
  15000,
  'upi'::public.booking_payment_method,
  (SELECT t0 FROM s9k_clock),
  'S9-KPI-A-VALID',
  'KPI valid confirmation payment'
);

CREATE TEMP TABLE s9k_a_payment_future_reversal AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9k_booking_a),
  1000,
  'bank_transfer'::public.booking_payment_method,
  (SELECT t0 FROM s9k_clock),
  'S9-KPI-A-FUTURE',
  'Reversal occurs after historical report cutoff'
);

-- Sprint 10 regression adaptation — Booking A shoot proposal
-- First-time confirmation now requires current Stage 7 schedule evidence.
CREATE TEMP TABLE s9k_a_schedule_proposal AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s9k_booking_a),
  '2030-03-01 10:00:00+05:30'::timestamptz,
  '2030-03-01 12:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 9 KPI regression studio A'
);

SELECT public.confirm_booking_after_advance(
  (SELECT id FROM s9k_booking_a)
);

-- Booking B:
-- Confirm exactly, then reverse before period end.
-- Historical journey stays confirmed, financial snapshot is short.

CREATE TEMP TABLE s9k_b_payment AS
SELECT *
FROM public.record_booking_payment(
  (SELECT id FROM s9k_booking_b),
  7500,
  'card'::public.booking_payment_method,
  (SELECT t0 FROM s9k_clock),
  'S9-KPI-B',
  'KPI confirmed-shortfall fixture'
);

-- Sprint 10 regression adaptation — Booking B shoot proposal
-- Keep the historical KPI journey semantics unchanged while satisfying
-- the new first-time confirmation schedule gate.
CREATE TEMP TABLE s9k_b_schedule_proposal AS
SELECT *
FROM public.propose_booking_shoot_schedule(
  (SELECT id FROM s9k_booking_b),
  '2030-03-02 09:00:00+05:30'::timestamptz,
  '2030-03-02 11:00:00+05:30'::timestamptz,
  'Asia/Kolkata',
  'studio',
  'Sprint 9 KPI regression studio B'
);

SELECT public.confirm_booking_after_advance(
  (SELECT id FROM s9k_booking_b)
);

SELECT public.reverse_booking_payment(
  (SELECT id FROM s9k_b_payment),
  'KPI confirmed-shortfall reversal'
);

-- Deliberate future reversal fixture:
-- canonical immutable evidence timestamped after the report cutoff.
-- This proves a later reversal does not rewrite a prior report.

INSERT INTO public.booking_payment_reversals (
  id,
  organization_id,
  booking_id,
  payment_id,
  reason,
  reversed_at,
  reversed_by
)
VALUES (
  '85000000-0000-0000-0000-000000000901',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  (SELECT id FROM s9k_booking_a),
  (SELECT id FROM s9k_a_payment_future_reversal),
  'KPI reversal after historical cutoff',
  (SELECT period_end + interval '1 hour' FROM s9k_clock),
  '85000000-0000-0000-0000-000000000011'
);

-- =====================================================================
-- Authoritative summary
-- =====================================================================

CREATE TEMP TABLE s9k_summary AS
SELECT *
FROM public.get_founder_kpi_summary(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  (SELECT period_start FROM s9k_clock),
  (SELECT period_end FROM s9k_clock),
  NULL
);

-- 23
SELECT is(
  (SELECT new_inquiries_count FROM s9k_summary),
  4::bigint,
  'period counts four new inquiry events'
);

-- 24
SELECT is(
  (SELECT quotations_sent_count FROM s9k_summary),
  4::bigint,
  'period counts four quotations sent'
);

-- 25
SELECT is(
  (SELECT quoted_value_inr FROM s9k_summary),
  75000::bigint,
  'quoted value is ₹75,000 without calling it revenue'
);

-- 26
SELECT is(
  (SELECT quotations_accepted_count FROM s9k_summary),
  3::bigint,
  'period counts three accepted quotations'
);

-- 27
SELECT is(
  (SELECT accepted_value_inr FROM s9k_summary),
  60000::bigint,
  'accepted value is ₹60,000'
);

-- 28
SELECT is(
  (SELECT bookings_created_count FROM s9k_summary),
  3::bigint,
  'three canonical bookings were created'
);

-- 29
SELECT is(
  (SELECT bookings_confirmed_count FROM s9k_summary),
  2::bigint,
  'two bookings reached advance-satisfied confirmation'
);

-- 30
SELECT is(
  (SELECT payments_collected_inr FROM s9k_summary),
  16000::bigint,
  'payments collected as of cutoff exclude pre-cutoff reversals but retain later-reversed payment'
);

-- 31
SELECT is(
  (SELECT sent_quote_cohort_accepted_count FROM s9k_summary),
  3::bigint,
  'three of four sent-quote cohort members accepted before cutoff'
);

-- 32
SELECT is(
  (SELECT sent_quote_acceptance_rate_pct FROM s9k_summary),
  75.00::numeric,
  'sent quotation acceptance rate is 75.00%'
);

-- 33
SELECT is(
  (SELECT inquiry_cohort_accepted_count FROM s9k_summary),
  3::bigint,
  'three distinct inquiry cohort members have an accepted quotation'
);

-- 34
SELECT is(
  (SELECT inquiry_to_accepted_quote_rate_pct FROM s9k_summary),
  75.00::numeric,
  'inquiry to accepted quotation conversion is 75.00%'
);

-- 35
SELECT is(
  (SELECT accepted_quote_cohort_booked_count FROM s9k_summary),
  3::bigint,
  'all accepted quotation cohort members have canonical bookings'
);

-- 36
SELECT is(
  (SELECT accepted_quote_to_booking_rate_pct FROM s9k_summary),
  100.00::numeric,
  'accepted quotation to booking conversion is 100.00%'
);

-- 37
SELECT is(
  (SELECT booking_cohort_confirmed_count FROM s9k_summary),
  2::bigint,
  'two of three booking cohort members were confirmed'
);

-- 38
SELECT is(
  (SELECT booking_to_confirmed_rate_pct FROM s9k_summary),
  66.67::numeric,
  'booking to confirmation conversion rounds to 66.67%'
);

-- 39
SELECT is(
  (SELECT required_advance_as_of_end_inr FROM s9k_summary),
  30000::bigint,
  'aggregate required advance as of cutoff is ₹30,000'
);

-- 40
SELECT is(
  (SELECT valid_collected_as_of_end_inr FROM s9k_summary),
  16000::bigint,
  'valid collected amount as of cutoff is ₹16,000'
);

-- 41
SELECT is(
  (SELECT advance_outstanding_as_of_end_inr FROM s9k_summary),
  15000::bigint,
  'advance outstanding as of cutoff is ₹15,000 and never negative'
);

-- 42
SELECT is(
  (SELECT advance_satisfied_bookings_as_of_end_count FROM s9k_summary),
  1::bigint,
  'exactly one booking is financially advance-satisfied at cutoff'
);

-- 43
SELECT is(
  (SELECT advance_pending_stage_as_of_end_count FROM s9k_summary),
  1::bigint,
  'one booking is positioned at Advance Pending at cutoff'
);

-- 44
SELECT is(
  (SELECT booking_confirmed_stage_as_of_end_count FROM s9k_summary),
  2::bigint,
  'two bookings are positioned at Booking Confirmed at cutoff'
);

-- 45
SELECT is(
  (
    SELECT confirmed_with_advance_shortfall_as_of_end_count
    FROM s9k_summary
  ),
  1::bigint,
  'one historically confirmed booking has a current cutoff shortfall'
);

-- 46
SELECT is(
  (
    SELECT COALESCE(sum(amount_inr), 0)::bigint
    FROM public.booking_payments
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
      AND received_at >=
          (SELECT period_start FROM s9k_clock)
      AND received_at <
          (SELECT period_end FROM s9k_clock)
  ),
  28500::bigint,
  'raw immutable receipts total ₹28,500 before reversal semantics are applied'
);

-- 47
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.booking_payment_reversals
    WHERE payment_id =
          (SELECT id FROM s9k_a_payment_future_reversal)
      AND reversed_at >
          (SELECT period_end FROM s9k_clock)
  ),
  'fixture contains a reversal after the reporting cutoff'
);

-- 48
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payment_reversals
    WHERE reversed_at <
          (SELECT period_end FROM s9k_clock)
  ),
  2::bigint,
  'two reversals exist before the reporting cutoff'
);

-- =====================================================================
-- Undefined cohort conversions return NULL
-- =====================================================================

CREATE TEMP TABLE s9k_empty_summary AS
SELECT *
FROM public.get_founder_kpi_summary(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  (SELECT empty_start FROM s9k_clock),
  (SELECT empty_end FROM s9k_clock),
  NULL
);

-- 49
SELECT is(
  (SELECT sent_quote_acceptance_rate_pct FROM s9k_empty_summary),
  NULL::numeric,
  'zero sent-quote denominator returns NULL conversion rate'
);

-- 50
SELECT is(
  (
    SELECT inquiry_to_accepted_quote_rate_pct
    FROM s9k_empty_summary
  ),
  NULL::numeric,
  'zero inquiry denominator returns NULL conversion rate'
);

-- 51
SELECT is(
  (
    SELECT accepted_quote_to_booking_rate_pct
    FROM s9k_empty_summary
  ),
  NULL::numeric,
  'zero accepted-quote denominator returns NULL conversion rate'
);

-- 52
SELECT is(
  (SELECT booking_to_confirmed_rate_pct FROM s9k_empty_summary),
  NULL::numeric,
  'zero booking denominator returns NULL conversion rate'
);

-- =====================================================================
-- 21-stage historical read model
-- =====================================================================

CREATE TEMP TABLE s9k_stage_summary AS
SELECT *
FROM public.get_founder_booking_stage_kpis(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  (SELECT period_end FROM s9k_clock),
  NULL
);

-- 53
SELECT is(
  (SELECT count(*)::bigint FROM s9k_stage_summary),
  21::bigint,
  'stage read model always returns complete 21-stage shape'
);

-- 54
SELECT is(
  (
    SELECT booking_count
    FROM s9k_stage_summary
    WHERE stage_order = 7
  ),
  1::bigint,
  'Stage 7 contains one Advance Pending booking'
);

-- 55
SELECT is(
  (
    SELECT booking_count
    FROM s9k_stage_summary
    WHERE stage_order = 8
  ),
  2::bigint,
  'Stage 8 contains two Booking Confirmed bookings'
);

-- 56
SELECT is(
  (
    SELECT booking_count
    FROM s9k_stage_summary
    WHERE stage_order = 1
  ),
  0::bigint,
  'zero-count canonical stages are retained'
);

-- 57
SELECT is(
  (
    SELECT average_stage_age_seconds
    FROM s9k_stage_summary
    WHERE stage_order = 1
  ),
  NULL::numeric,
  'zero-count stage average age is NULL'
);

-- 58
SELECT is(
  (
    SELECT oldest_stage_age_seconds
    FROM s9k_stage_summary
    WHERE stage_order = 1
  ),
  NULL::bigint,
  'zero-count stage oldest age is NULL'
);

-- 59
SELECT is(
  (
    SELECT average_stage_age_seconds
    FROM s9k_stage_summary
    WHERE stage_order = 7
  ),
  3600.00::numeric,
  'Advance Pending stage age is reconstructed from immutable transition entry time'
);

-- 60
SELECT is(
  (
    SELECT oldest_stage_age_seconds
    FROM s9k_stage_summary
    WHERE stage_order = 8
  ),
  3600::bigint,
  'Booking Confirmed oldest stage age is reconstructed exactly'
);

-- 61
SELECT is(
  (
    SELECT stage_key
    FROM s9k_stage_summary
    WHERE stage_order = 7
  ),
  'advance_pending',
  'stage order 7 preserves canonical Advance Pending key'
);

-- 62
SELECT is(
  (
    SELECT stage_key
    FROM s9k_stage_summary
    WHERE stage_order = 8
  ),
  'booking_confirmed',
  'stage order 8 preserves canonical Booking Confirmed key'
);

-- =====================================================================
-- Regression / immutable evidence
-- =====================================================================

-- 63
SELECT throws_ok(
  $$
  UPDATE public.quotations
  SET accepted_at = accepted_at + interval '1 second'
  WHERE id = (
    SELECT id FROM s9k_quote_a
  )
  $$,
  'P0001',
  'accepted quotations are immutable',
  'KPI read model does not weaken accepted quotation immutability'
);

-- 64
SELECT throws_ok(
  $$
  UPDATE public.booking_payment_requirements
  SET required_advance_inr = required_advance_inr + 1
  WHERE booking_id = (
    SELECT id FROM s9k_booking_a
  )
  $$,
  'P0001',
  'booking payment requirements are immutable',
  'KPI read model does not weaken advance requirement immutability'
);

-- 65
SELECT throws_ok(
  $$
  UPDATE public.booking_payment_reversals
  SET reason = 'tampered'
  WHERE payment_id = (
    SELECT id FROM s9k_b_payment
  )
  $$,
  'P0001',
  'booking payment reversals are append-only and immutable',
  'KPI read model preserves reversal evidence immutability'
);

-- 66
SELECT throws_ok(
  $$
  UPDATE public.booking_stage_transitions
  SET transition_key = 'tampered'
  WHERE booking_id = (
    SELECT id FROM s9k_booking_b
  )
    AND transition_key = 'advance_satisfied'
  $$,
  'P0001',
  'booking stage transition history is append-only',
  'KPI read model preserves confirmation-history immutability'
);

-- 67
SELECT is(
  (
    SELECT confirmed_with_advance_shortfall
    FROM public.get_booking_payment_summary(
      (SELECT id FROM s9k_booking_b)
    )
  ),
  true,
  'current payment summary still reports confirmed booking shortfall'
);

-- 68
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s9k_booking_b)
      AND transition_key =
          'advance_satisfied'
  ),
  1::bigint,
  'historical confirmation remains exactly once after financial reversal'
);

SELECT * FROM finish();

ROLLBACK;
