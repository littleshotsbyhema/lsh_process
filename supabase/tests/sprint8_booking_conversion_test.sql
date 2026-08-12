BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(37);

-- =====================================================================
-- Test identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('82000000-0000-0000-0000-000000000001'::uuid),
  ('82000000-0000-0000-0000-000000000002'::uuid),
  ('82000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '82000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '82000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 8 Booking Founder'
),
(
  '82000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '82000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 8 Booking Sales'
),
(
  '82000000-0000-0000-0000-000000000013',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '82000000-0000-0000-0000-000000000003',
  'active',
  'Sprint 8 Booking Photographer'
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
      '82000000-0000-0000-0000-000000000011'::uuid,
      'founder'
    ),
    (
      '82000000-0000-0000-0000-000000000012'::uuid,
      'sales'
    ),
    (
      '82000000-0000-0000-0000-000000000013'::uuid,
      'photographer'
    )
) fixture(member_id, role_key)
JOIN public.roles r
  ON r.key = fixture.role_key;

-- Clean replay leaves the canonical organization suspended until
-- Founder coverage exists.
UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

-- Family fixture must obey the production actor invariant.
SELECT set_config(
  'request.jwt.claim.sub',
  '82000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '82000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-234567',
  'Sprint 8 Booking Family',
  'Booking Family',
  'active',
  '82000000-0000-0000-0000-000000000011',
  '82000000-0000-0000-0000-000000000011'
);

-- =====================================================================
-- Structure / RLS / ACL
-- =====================================================================

SELECT has_table(
  'public',
  'bookings',
  'bookings exists'
);

SELECT has_table(
  'public',
  'booking_journey_states',
  'booking_journey_states exists'
);

SELECT has_table(
  'public',
  'booking_stage_transitions',
  'booking_stage_transitions exists'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'bookings',
        'booking_journey_states',
        'booking_stage_transitions'
      )
      AND c.relrowsecurity
      AND c.relforcerowsecurity
  ),
  3::bigint,
  'all booking operational tables have RLS and FORCE RLS'
);

SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.bookings',
    'SELECT'
  ),
  'authenticated can SELECT bookings subject to RLS'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.bookings',
    'INSERT'
  ),
  'authenticated cannot directly INSERT bookings'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.bookings',
    'UPDATE'
  ),
  'authenticated cannot directly UPDATE bookings'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.bookings',
    'DELETE'
  ),
  'authenticated cannot directly DELETE bookings'
);

SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.bookings',
    'SELECT'
  ),
  'anon cannot SELECT bookings'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    to_regprocedure(
      'public.accept_quotation(uuid)'
    )::oid,
    'EXECUTE'
  ),
  'authenticated can execute controlled accept_quotation RPC'
);

SELECT ok(
  NOT has_function_privilege(
    'anon',
    to_regprocedure(
      'public.accept_quotation(uuid)'
    )::oid,
    'EXECUTE'
  ),
  'anon cannot execute accept_quotation'
);

-- =====================================================================
-- Sales conversion capability
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '82000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'quote.write',
    NULL
  ),
  'Sales has quote.write conversion capability'
);

SELECT ok(
  NOT public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'booking.write',
    NULL
  ),
  'Sales does not receive generic booking.write'
);

SELECT ok(
  NOT public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'booking.stage.advance',
    NULL
  ),
  'Sales does not receive booking.stage.advance'
);

-- ---------------------------------------------------------------------
-- Build a valid sent quotation.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s8b_sales_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '82000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s8b_sales_quote),
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
  (SELECT id FROM s8b_sales_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s8b_sales_quote),
  'sent'::public.quotation_status
);

SELECT is(
  (
    SELECT status::text
    FROM public.quotations
    WHERE id =
          (SELECT id FROM s8b_sales_quote)
  ),
  'sent',
  'conversion fixture reaches sent quotation status'
);

SELECT is(
  (
    SELECT quoted_total_inr
    FROM public.quotations
    WHERE id =
          (SELECT id FROM s8b_sales_quote)
  ),
  30000,
  'sent conversion fixture preserves sourced Maternity Gold list price'
);

-- =====================================================================
-- Atomic acceptance
-- =====================================================================

CREATE TEMP TABLE s8b_accept_once AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s8b_sales_quote)
);

SELECT is(
  (
    SELECT status::text
    FROM public.quotations
    WHERE id =
          (SELECT id FROM s8b_sales_quote)
  ),
  'accepted',
  'accept_quotation atomically marks the sent quotation accepted'
);

SELECT ok(
  (
    SELECT booking_reference ~
           '^LSH-BK-[A-F0-9]{8}$'
    FROM s8b_accept_once
  ),
  'accepted quotation receives a canonical booking reference'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.bookings b
    WHERE b.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
      AND b.source_quotation_id =
          (SELECT id FROM s8b_sales_quote)
  ),
  1::bigint,
  'acceptance creates exactly one booking for the quotation'
);

SELECT is(
  (
    SELECT family_id
    FROM s8b_accept_once
  ),
  '82000000-0000-0000-0000-000000000020'::uuid,
  'booking preserves the quotation family subject'
);

SELECT is(
  (
    SELECT s.stage_key
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s8b_accept_once)
  ),
  'advance_pending',
  'quotation acceptance initializes booking at Advance Pending'
);

SELECT is(
  (
    SELECT version
    FROM public.booking_journey_states
    WHERE booking_id =
          (SELECT id FROM s8b_accept_once)
  ),
  1::bigint,
  'initial booking journey state starts at version 1'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions t
    WHERE t.booking_id =
          (SELECT id FROM s8b_accept_once)
      AND t.from_stage_id IS NULL
  ),
  1::bigint,
  'booking has exactly one initial transition'
);

SELECT is(
  (
    SELECT transition_key
    FROM public.booking_stage_transitions
    WHERE booking_id =
          (SELECT id FROM s8b_accept_once)
      AND from_stage_id IS NULL
  ),
  'quotation_acceptance',
  'initial transition records quotation acceptance evidence'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.booking_journey_states js
    JOIN public.booking_journey_stages s
      ON s.organization_id = js.organization_id
     AND s.id = js.current_stage_id
    WHERE js.booking_id =
          (SELECT id FROM s8b_accept_once)
      AND s.stage_key = 'booking_confirmed'
  ),
  'quotation acceptance does not mark the booking confirmed'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events e
    WHERE e.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
      AND e.entity_type = 'booking'
      AND e.entity_id =
          (SELECT id FROM s8b_accept_once)
      AND e.action_key =
          'booking.created_from_quotation'
      AND e.is_sensitive
  ),
  'booking conversion emits sensitive booking audit evidence'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events e
    WHERE e.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
      AND e.entity_type = 'quotation'
      AND e.entity_id =
          (SELECT id FROM s8b_sales_quote)
      AND e.action_key =
          'quote.status_changed'
      AND e.new_values->>'status' =
          'accepted'
  ),
  'quotation acceptance emits accepted lifecycle audit evidence'
);

-- =====================================================================
-- Idempotency
-- =====================================================================

CREATE TEMP TABLE s8b_accept_replay AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s8b_sales_quote)
);

SELECT is(
  (
    SELECT id
    FROM s8b_accept_replay
  ),
  (
    SELECT id
    FROM s8b_accept_once
  ),
  'replaying acceptance returns the same booking'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.bookings
    WHERE source_quotation_id =
          (SELECT id FROM s8b_sales_quote)
  ),
  1::bigint,
  'replaying acceptance never creates a duplicate booking'
);

-- =====================================================================
-- Immutable conversion evidence
-- =====================================================================

SELECT throws_ok(
  $$
  UPDATE public.quotations
  SET accepted_at = accepted_at + interval '1 second'
  WHERE id = (
    SELECT id
    FROM s8b_sales_quote
  )
  $$,
  'P0001',
  'accepted quotations are immutable',
  'accepted quotation evidence cannot be rewritten'
);

SELECT throws_ok(
  $$
  DELETE FROM public.bookings
  WHERE id = (
    SELECT id
    FROM s8b_accept_once
  )
  $$,
  'P0001',
  'booking conversion shells cannot be deleted',
  'booking conversion shell cannot be deleted'
);

SELECT throws_ok(
  $$
  UPDATE public.booking_stage_transitions
  SET transition_key = 'tampered'
  WHERE booking_id = (
    SELECT id
    FROM s8b_accept_once
  )
    AND from_stage_id IS NULL
  $$,
  'P0001',
  'booking stage transition history is append-only',
  'booking transition evidence is append-only'
);

-- =====================================================================
-- Only eligible sent quotations can convert
-- =====================================================================

CREATE TEMP TABLE s8b_draft_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '82000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT throws_ok(
  $$
  SELECT public.accept_quotation(
    (SELECT id FROM s8b_draft_quote)
  )
  $$,
  '22023',
  'accept_quotation: only sent quotations can be accepted',
  'draft quotation cannot be accepted'
);

-- Build another sent quote while Sales is active, then test a role
-- that has booking.read but not quote.write.

CREATE TEMP TABLE s8b_photographer_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '82000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s8b_photographer_quote),
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
  (SELECT id FROM s8b_photographer_quote),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s8b_photographer_quote),
  'sent'::public.quotation_status
);

SELECT set_config(
  'request.jwt.claim.sub',
  '82000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
  SELECT public.accept_quotation(
    (SELECT id FROM s8b_photographer_quote)
  )
  $$,
  '42501',
  'accept_quotation: quote.write permission required',
  'Photographer cannot convert a quotation'
);

-- =====================================================================
-- No fake payment ledger / reservation state
-- =====================================================================

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'bookings'
      AND lower(c.column_name) IN (
        'amount_paid',
        'paid_amount',
        'balance',
        'balance_inr',
        'receipt',
        'receipt_id',
        'refund',
        'refund_inr',
        'transaction_id',
        'advance_paid',
        'payment_status'
      )
  ),
  'booking conversion creates no fake payment ledger fields'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'bookings'
      AND lower(c.column_name) IN (
        'session_date',
        'reserved_at',
        'reservation_status',
        'slot_reserved_at'
      )
  ),
  'quotation acceptance creates no session-date reservation fields'
);

-- =====================================================================
-- Long-term acceptance idempotency
--
-- Simulate a later legitimate journey advance. This is fixture setup,
-- not an application mutation path. The replay must still return the
-- original booking because initial transition evidence remains intact.
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '82000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
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
  js.organization_id,
  js.booking_id,
  js.current_stage_id,
  target.id,
  'booking_confirmed_test',
  now(),
  '82000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_states js
JOIN public.booking_journey_stages target
  ON target.organization_id = js.organization_id
 AND target.stage_key = 'booking_confirmed'
WHERE js.booking_id =
      (SELECT id FROM s8b_accept_once);

UPDATE public.booking_journey_states js
SET
  current_stage_id = target.id,
  stage_entered_at = now(),
  version = js.version + 1,
  updated_by =
    '82000000-0000-0000-0000-000000000011'::uuid
FROM public.booking_journey_stages target
WHERE js.booking_id =
      (SELECT id FROM s8b_accept_once)
  AND target.organization_id =
      js.organization_id
  AND target.stage_key =
      'booking_confirmed';

SELECT set_config(
  'request.jwt.claim.sub',
  '82000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"82000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s8b_accept_after_progress AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s8b_sales_quote)
);

SELECT is(
  (
    SELECT id
    FROM s8b_accept_after_progress
  ),
  (
    SELECT id
    FROM s8b_accept_once
  ),
  'acceptance replay remains idempotent after later journey progression'
);

SELECT * FROM finish();

ROLLBACK;
