-- =====================================================================
-- Sprint 9 — Advance Payment, Booking Confirmation & KPI Foundation
-- Slice 2 — Advance-Satisfied Booking Confirmation
--
-- Authority:
--   * booking.confirm permission
--   * controlled confirm_booking_after_advance(uuid)
--   * exact Stage 7 Advance Pending -> Stage 8 Booking Confirmed
--   * authoritative payment threshold required
--   * append-only transition evidence
--   * idempotent replay
--   * audit evidence
--
-- Frozen confirmation condition:
--
--   valid non-reversed collected INR
--     >=
--   immutable required advance INR
--
-- Frozen journey transition:
--
--   advance_pending
--     ->
--   booking_confirmed
--
--   transition_key = advance_satisfied
--
-- Historical rule:
--   a later payment reversal does not rewind the journey.
--   Current payment summary exposes the resulting shortfall.
--
-- Explicitly NOT in this slice:
--   * generic booking stage advancement
--   * scheduling/date reservation
--   * full-payment enforcement
--   * editing workflow
--   * KPI dashboard
-- =====================================================================


-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s9_confirmation_preconditions$
BEGIN
  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.booking_payment_requirements') IS NULL
     OR to_regclass('public.booking_payments') IS NULL
     OR to_regclass('public.booking_payment_reversals') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 confirmation precondition failed: canonical booking/payment tables missing';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 confirmation precondition failed: current_organization_member(uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 confirmation precondition failed: has_permission(uuid,text,uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 confirmation precondition failed: append_audit_event(...) missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.booking_journey_stages s
    WHERE s.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND s.stage_key = 'advance_pending'
      AND s.stage_order = 7
      AND s.is_active
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 confirmation precondition failed: Advance Pending stage 7 missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.booking_journey_stages s
    WHERE s.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND s.stage_key = 'booking_confirmed'
      AND s.stage_order = 8
      AND s.is_active
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 confirmation precondition failed: Booking Confirmed stage 8 missing';
  END IF;
END
$s9_confirmation_preconditions$;

-- =====================================================================
-- Section B — Narrow booking-confirmation permission
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'booking.confirm',
  'bookings',
  'Confirm booking after advance',
  'Authorize controlled Advance Pending to Booking Confirmed transition only after authoritative advance-payment evidence satisfies the frozen requirement.',
  true
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
WHERE r.key = 'founder'
  AND p.key = 'booking.confirm'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- =====================================================================
-- Section C — Exactly one authoritative confirmation transition
-- =====================================================================

CREATE UNIQUE INDEX
booking_stage_transitions_one_advance_confirmation_idx
ON public.booking_stage_transitions (
  organization_id,
  booking_id
)
WHERE transition_key = 'advance_satisfied';

-- =====================================================================
-- Section D — Controlled advance-satisfied booking confirmation
-- =====================================================================

CREATE OR REPLACE FUNCTION public.confirm_booking_after_advance(
  p_booking_id uuid
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_quote public.quotations;
  v_requirement public.booking_payment_requirements;
  v_state public.booking_journey_states;

  v_actor uuid;

  v_advance_stage_id uuid;
  v_confirmed_stage_id uuid;

  v_valid_collected bigint := 0;
  v_confirmation_count integer := 0;
  v_state_count integer := 0;

  v_transitioned_at timestamptz;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Serialize every confirmation attempt for this booking.
  -- ---------------------------------------------------------------

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'booking.confirm',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking.confirm permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_booking.organization_id,
       v_booking.branch_id
     ) THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: no access to booking branch'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical journey state must exist exactly once.
  -- Lock it together with the booking serialization boundary.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states js
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT js.*
  INTO v_state
  FROM public.booking_journey_states js
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id
  FOR UPDATE;

  SELECT s.id
  INTO v_advance_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.stage_key = 'advance_pending'
    AND s.stage_order = 7
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: active Advance Pending stage 7 unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT s.id
  INTO v_confirmed_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.stage_key = 'booking_confirmed'
    AND s.stage_order = 8
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: active Booking Confirmed stage 8 unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Idempotent replay.
  --
  -- Once this exact historical transition exists, confirmation has
  -- already happened legitimately. Replays return the same booking
  -- even if the journey later progresses or a later payment reversal
  -- creates a current financial shortfall.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_confirmation_count
  FROM public.booking_stage_transitions t
  WHERE t.organization_id =
        v_booking.organization_id
    AND t.booking_id =
        v_booking.id
    AND t.from_stage_id =
        v_advance_stage_id
    AND t.to_stage_id =
        v_confirmed_stage_id
    AND t.transition_key =
        'advance_satisfied';

  IF v_confirmation_count > 1 THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: duplicate historical confirmation evidence detected'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_confirmation_count = 1 THEN
    RETURN v_booking;
  END IF;

  -- ---------------------------------------------------------------
  -- First-time confirmation must start exactly at Stage 7.
  -- ---------------------------------------------------------------

  IF v_state.current_stage_id
       IS DISTINCT FROM v_advance_stage_id THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking must be at Advance Pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Accepted quotation linkage remains authoritative.
  -- ---------------------------------------------------------------

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.organization_id =
        v_booking.organization_id
    AND q.id =
        v_booking.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <> 'accepted' THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking requires accepted quotation'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_quote.currency <> 'INR'
     OR v_quote.quoted_total_inr <= 0 THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: accepted quotation must be positive INR'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Frozen advance requirement must exactly match the accepted quote.
  -- ---------------------------------------------------------------

  SELECT r.*
  INTO v_requirement
  FROM public.booking_payment_requirements r
  WHERE r.organization_id =
        v_booking.organization_id
    AND r.booking_id =
        v_booking.id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: booking payment requirement missing'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_requirement.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id
     OR v_requirement.source_quotation_id
       IS DISTINCT FROM
         v_quote.id
     OR v_requirement.currency <> 'INR'
     OR v_requirement.currency
       IS DISTINCT FROM
         v_quote.currency
     OR v_requirement.accepted_quotation_total_inr
       IS DISTINCT FROM
         v_quote.quoted_total_inr
     OR v_requirement.advance_percentage <> 50
     OR v_requirement.calculation_rule <>
          'accepted_quote_50_percent_round_half_up'
     OR v_requirement.required_advance_inr
       IS DISTINCT FROM
         ((v_quote.quoted_total_inr + 1) / 2) THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: payment requirement does not match accepted quotation snapshot'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Financial gate:
  -- only non-reversed payment evidence counts.
  -- ---------------------------------------------------------------

  SELECT COALESCE(
    sum(p.amount_inr)
      FILTER (
        WHERE rv.id IS NULL
      ),
    0
  )::bigint
  INTO v_valid_collected
  FROM public.booking_payments p
  LEFT JOIN public.booking_payment_reversals rv
    ON rv.organization_id =
       p.organization_id
   AND rv.payment_id =
       p.id
  WHERE p.organization_id =
        v_booking.organization_id
    AND p.booking_id =
        v_booking.id;

  IF v_valid_collected <
       v_requirement.required_advance_inr THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: required advance has not been satisfied'
      USING ERRCODE = '22023';
  END IF;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Append historical transition evidence first.
  --
  -- The existing Sprint 8 transition guard validates the current
  -- Stage 7 state before the current-state row is advanced.
  -- ---------------------------------------------------------------

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
    v_booking.organization_id,
    v_booking.id,
    v_advance_stage_id,
    v_confirmed_stage_id,
    'advance_satisfied',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Advance the one authoritative current state exactly once.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states js
  SET
    current_stage_id =
      v_confirmed_stage_id,
    stage_entered_at =
      v_transitioned_at,
    version =
      js.version + 1,
    updated_by =
      v_actor
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id
    AND js.current_stage_id =
        v_advance_stage_id
    AND js.version =
        v_state.version;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'confirm_booking_after_advance: journey state changed during confirmation'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- Append audit evidence.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.confirmed_after_advance',
    'booking',
    v_booking.id,
    true,
    jsonb_build_object(
      'journey_stage',
        'advance_pending',
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'booking_confirmed',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'required_advance_inr',
        v_requirement.required_advance_inr,
      'valid_collected_inr',
        v_valid_collected,
      'transition_key',
        'advance_satisfied',
      'source_quotation_id',
        v_booking.source_quotation_id
    ),
    'finance',
    NULL
  );

  RETURN v_booking;
END
$$;

-- =====================================================================
-- Section E — RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.confirm_booking_after_advance(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.confirm_booking_after_advance(uuid)
TO authenticated;

-- =====================================================================
-- Section F — Migration assertions
-- =====================================================================

DO $s9_confirmation_assertions$
DECLARE
  v_count integer;
  v_fn regprocedure;
BEGIN
  -- booking.confirm exists exactly once.
  SELECT count(*)
  INTO v_count
  FROM public.permissions
  WHERE key = 'booking.confirm';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: booking.confirm permission missing';
  END IF;

  -- Founder receives booking.confirm.
  SELECT count(*)
  INTO v_count
  FROM public.role_permissions rp
  JOIN public.roles r
    ON r.id = rp.role_id
  JOIN public.permissions p
    ON p.id = rp.permission_id
  WHERE r.key = 'founder'
    AND p.key = 'booking.confirm';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: founder booking.confirm grant missing';
  END IF;

  -- Controlled RPC exists and is SECURITY DEFINER.
  v_fn :=
    to_regprocedure(
      'public.confirm_booking_after_advance(uuid)'
    );

  IF v_fn IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: confirm_booking_after_advance(uuid) missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid = v_fn::oid
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: confirmation RPC must be SECURITY DEFINER';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: authenticated confirmation EXECUTE missing';
  END IF;

  IF has_function_privilege(
       'anon',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: anon confirmation EXECUTE detected';
  END IF;

  -- Exactly one structural uniqueness guard for authoritative
  -- advance-satisfied confirmation evidence.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes i
    WHERE i.schemaname = 'public'
      AND i.tablename =
          'booking_stage_transitions'
      AND i.indexname =
          'booking_stage_transitions_one_advance_confirmation_idx'
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: confirmation uniqueness index missing';
  END IF;

  -- Canonical stage definitions remain exact.
  IF NOT EXISTS (
    SELECT 1
    FROM public.booking_journey_stages s
    WHERE s.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND s.stage_key = 'advance_pending'
      AND s.stage_order = 7
      AND s.is_active
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: Advance Pending stage 7 invalid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.booking_journey_stages s
    WHERE s.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND s.stage_key = 'booking_confirmed'
      AND s.stage_order = 8
      AND s.is_active
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: Booking Confirmed stage 8 invalid';
  END IF;

  -- No generic unrestricted booking-stage RPC is introduced by Slice 2.
  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'advance_booking_stage',
      'transition_booking_stage',
      'set_booking_stage',
      'update_booking_stage'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 2 failed: generic booking-stage mutation RPC detected';
  END IF;
END
$s9_confirmation_assertions$;

-- SPRINT_9_SLICE_2_IMPLEMENTATION_END
