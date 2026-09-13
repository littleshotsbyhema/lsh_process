-- =====================================================================
-- Balance gate relocation
-- =====================================================================
--
-- Revises the studio's money policy on the delivery half of the journey.
--
-- Previously: the gallery could not be delivered at all while the client
-- owed a balance, unless the Founder recorded a written override reason.
-- In practice that blocked the coordinator from doing the ordinary thing
-- (send the link) and forced the Founder into every single delivery.
--
-- Now:
--   * the gallery link may always be sent, at any balance;
--   * downloads may only be enabled when the balance is zero;
--   * a later gallery round re-issues the link with downloads enabled
--     once payment lands, which is why record_booking_gallery now also
--     admits at stage 17;
--   * album and frame production is blocked while a balance is
--     outstanding, with delivery.balance_override as the escape hatch.
--
-- The delivery confirmation still records quotation_total_inr,
-- collected_inr and outstanding_inr, so the financial history of every
-- delivery is unchanged and auditable.
--
-- Idempotent, transactional, and asserted at both ends.
-- =====================================================================

DO $precondition$
BEGIN
  IF to_regprocedure('public.record_booking_gallery(uuid, text, boolean, boolean, timestamptz, text)') IS NULL THEN
    RAISE EXCEPTION 'precondition: record_booking_gallery is missing';
  END IF;

  IF to_regprocedure('public.record_booking_delivery_confirmation(uuid, text)') IS NULL THEN
    RAISE EXCEPTION 'precondition: record_booking_delivery_confirmation is missing';
  END IF;

  IF to_regprocedure('public.mark_booking_album_frame_production(uuid)') IS NULL THEN
    RAISE EXCEPTION 'precondition: mark_booking_album_frame_production is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'booking_delivery_confirmations_override_chk'
  ) THEN
    RAISE EXCEPTION 'precondition: balance override check constraint is missing';
  END IF;
END;
$precondition$;

-- =====================================================================
-- Section A - Shared outstanding balance helper
-- =====================================================================
--
-- Canonical financial truth in one place: the accepted quotation total
-- from the booking payment requirement, less every payment that has not
-- been reversed. Never negative.

CREATE OR REPLACE FUNCTION public.booking_outstanding_inr(
  p_organization_id uuid,
  p_booking_id uuid
)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $outstanding$
DECLARE
  v_total integer;
  v_collected integer;
BEGIN
  IF p_organization_id IS NULL OR p_booking_id IS NULL THEN
    RAISE EXCEPTION 'booking_outstanding_inr: organization and booking are required'
      USING ERRCODE = '22023';
  END IF;

  SELECT requirement.accepted_quotation_total_inr INTO v_total
  FROM public.booking_payment_requirements requirement
  WHERE requirement.organization_id = p_organization_id
    AND requirement.booking_id = p_booking_id;

  IF v_total IS NULL THEN
    RAISE EXCEPTION 'booking_outstanding_inr: canonical booking payment requirement is unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(sum(payment.amount_inr), 0)::integer INTO v_collected
  FROM public.booking_payments payment
  WHERE payment.organization_id = p_organization_id
    AND payment.booking_id = p_booking_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.booking_payment_reversals reversal
      WHERE reversal.organization_id = payment.organization_id
        AND reversal.payment_id = payment.id
    );

  RETURN GREATEST(v_total - v_collected, 0);
END;
$outstanding$;

REVOKE ALL ON FUNCTION public.booking_outstanding_inr(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.booking_outstanding_inr(uuid, uuid) TO authenticated;

-- =====================================================================
-- Section B - Relax the delivery confirmation balance constraint
-- =====================================================================
--
-- An outstanding balance at delivery is now an ordinary, reasonless fact.

ALTER TABLE public.booking_delivery_confirmations
  DROP CONSTRAINT IF EXISTS booking_delivery_confirmations_override_chk;

-- =====================================================================
-- Section C - Gallery RPC: downloads gated, stage admission widened
-- =====================================================================

DROP FUNCTION IF EXISTS public.record_booking_gallery(uuid, text, boolean, boolean, timestamptz, text);

CREATE FUNCTION public.record_booking_gallery(
  p_booking_id uuid,
  p_gallery_url text,
  p_password_protected boolean,
  p_downloads_enabled boolean,
  p_expires_at timestamptz DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS public.booking_galleries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_gallery$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_url text;
  v_note text;
  v_round integer;
  v_result public.booking_galleries;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_gallery: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_gallery: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_gallery: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_gallery: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'delivery.confirm', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_gallery: delivery.confirm permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_gallery: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_password_protected IS NULL OR p_downloads_enabled IS NULL THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery access flags are required'
      USING ERRCODE = '22023';
  END IF;

  IF p_gallery_url IS NULL THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery url is required' USING ERRCODE = '22023';
  END IF;

  v_url := btrim(p_gallery_url);

  IF v_url = ''
     OR btrim(v_url, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_url <> btrim(v_url, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_url) > 500
     OR v_url ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery url is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_url IS NOT NULL
     AND (
       v_url ~* '^(bearer|basic)[[:space:]]+'
       OR v_url ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_url ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery url must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  IF v_url !~* '^https://[^[:space:]]+$' THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery url must be an https address'
      USING ERRCODE = '22023';
  END IF;

  IF p_expires_at IS NOT NULL AND p_expires_at <= now() THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery expiry must be in the future'
      USING ERRCODE = '22023';
  END IF;

  v_note := NULLIF(btrim(COALESCE(p_note, '')), '');

  IF v_note IS NOT NULL
     AND (
       btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_note <> btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_note) > 500
       OR v_note ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_note := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_gallery: gallery note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_gallery: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_gallery: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 16 AND v_stage.stage_key = 'pixieset_gallery_ready')
    OR
    (v_stage.stage_order = 17 AND v_stage.stage_key = 'delivered')
  ) THEN
    RAISE EXCEPTION
      'record_booking_gallery: booking must be exactly Gallery Ready or Delivered'
      USING ERRCODE = '22023';
  END IF;

  -- Balance policy: the gallery link may always be sent, but downloads may
  -- only be enabled once the accepted quotation is fully collected. A later
  -- round re-issues the same gallery with downloads on after payment lands.
  IF p_downloads_enabled
     AND public.booking_outstanding_inr(
           v_booking.organization_id, v_booking.id
         ) > 0 THEN
    RAISE EXCEPTION
      'record_booking_gallery: downloads cannot be enabled while a balance is outstanding'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(max(gallery.round), 0) + 1 INTO v_round
  FROM public.booking_galleries gallery
  WHERE gallery.organization_id = v_booking.organization_id
    AND gallery.booking_id = v_booking.id;

  IF v_round > 50 THEN
    RAISE EXCEPTION 'record_booking_gallery: gallery revision limit reached'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_galleries (
    organization_id, booking_id, round, provider, gallery_url,
    password_protected, downloads_enabled, expires_at, gallery_note,
    recorded_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_round, 'pixieset', v_url,
    p_password_protected, p_downloads_enabled, p_expires_at, v_note,
    now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.gallery_recorded',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'gallery_round', v_round,
      'password_protected', p_password_protected,
      'downloads_enabled', p_downloads_enabled
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'gallery_id', v_result.id,
      'gallery_round', v_round,
      'expires_at_present', (p_expires_at IS NOT NULL),
      'note_present', (v_note IS NOT NULL)
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$record_gallery$;

REVOKE ALL ON FUNCTION public.record_booking_gallery(uuid, text, boolean, boolean, timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_booking_gallery(uuid, text, boolean, boolean, timestamptz, text) TO authenticated;

-- =====================================================================
-- Section D - Delivery confirmation RPC: balance gate removed
-- =====================================================================

DROP FUNCTION IF EXISTS public.record_booking_delivery_confirmation(uuid, text);

CREATE FUNCTION public.record_booking_delivery_confirmation(
  p_booking_id uuid,
  p_balance_override_reason text DEFAULT NULL
)
RETURNS public.booking_delivery_confirmations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_delivery_confirmation$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_reason text;
  v_gallery public.booking_galleries;
  v_total integer;
  v_collected integer;
  v_outstanding integer;
  v_existing public.booking_delivery_confirmations;
  v_result public.booking_delivery_confirmations;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'delivery.confirm', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: delivery.confirm permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  v_reason := NULLIF(btrim(COALESCE(p_balance_override_reason, '')), '');

  IF v_reason IS NOT NULL
     AND (
       btrim(v_reason, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_reason <> btrim(v_reason, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_reason) > 500
       OR v_reason ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_reason, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_reason := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_delivery_confirmation: balance override reason is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_reason IS NOT NULL
     AND (
       v_reason ~* '^(bearer|basic)[[:space:]]+'
       OR v_reason ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_reason ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: balance override reason must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_delivery_confirmation: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_stage.stage_order = 16 AND v_stage.stage_key = 'pixieset_gallery_ready'
  ) THEN
    RAISE EXCEPTION
      'record_booking_delivery_confirmation: booking must be exactly Gallery Ready'
      USING ERRCODE = '22023';
  END IF;

  SELECT gallery.* INTO v_gallery
  FROM public.booking_galleries gallery
  WHERE gallery.organization_id = v_booking.organization_id
    AND gallery.booking_id = v_booking.id
  ORDER BY gallery.round DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_delivery_confirmation: booking requires a recorded client gallery'
      USING ERRCODE = '22023';
  END IF;

  -- Canonical financial truth: accepted quotation total from the booking
  -- payment requirement, collected value from unreversed payment evidence.
  SELECT requirement.accepted_quotation_total_inr INTO v_total
  FROM public.booking_payment_requirements requirement
  WHERE requirement.organization_id = v_booking.organization_id
    AND requirement.booking_id = v_booking.id;

  IF v_total IS NULL THEN
    RAISE EXCEPTION
      'record_booking_delivery_confirmation: canonical booking payment requirement is unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(sum(payment.amount_inr), 0)::integer INTO v_collected
  FROM public.booking_payments payment
  WHERE payment.organization_id = v_booking.organization_id
    AND payment.booking_id = v_booking.id
    AND NOT EXISTS (
      SELECT 1
      FROM public.booking_payment_reversals reversal
      WHERE reversal.organization_id = payment.organization_id
        AND reversal.payment_id = payment.id
    );

  v_outstanding := GREATEST(v_total - v_collected, 0);

  -- Replay: an existing confirmation is returned untouched.
  SELECT confirmation.* INTO v_existing
  FROM public.booking_delivery_confirmations confirmation
  WHERE confirmation.organization_id = v_booking.organization_id
    AND confirmation.booking_id = v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    RETURN v_existing;
  END IF;

  -- Balance policy (revised): sending the gallery is no longer gated on the
  -- balance. The outstanding amount is still recorded as evidence, and the
  -- money gate now sits in front of album / frame production instead.
  v_reason := NULL;

  INSERT INTO public.booking_delivery_confirmations (
    organization_id, booking_id, gallery_id, delivered_at,
    quotation_total_inr, collected_inr, outstanding_inr,
    balance_override_reason, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_gallery.id, now(),
    v_total, v_collected, v_outstanding,
    v_reason, v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.delivery_confirmed',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object('delivery_confirmed', false),
    jsonb_build_object(
      'delivery_confirmed', true,
      'outstanding_inr', v_outstanding,
      'balance_overridden', (v_reason IS NOT NULL)
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'delivery_confirmation_id', v_result.id,
      'gallery_id', v_gallery.id,
      'quotation_total_inr', v_total,
      'collected_inr', v_collected,
      'outstanding_inr', v_outstanding,
      'balance_overridden', (v_reason IS NOT NULL)
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$record_delivery_confirmation$;

REVOKE ALL ON FUNCTION public.record_booking_delivery_confirmation(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_booking_delivery_confirmation(uuid, text) TO authenticated;

-- =====================================================================
-- Section E - Production gate RPC: balance gate added
-- =====================================================================

DROP FUNCTION IF EXISTS public.mark_booking_album_frame_production(uuid);

CREATE FUNCTION public.mark_booking_album_frame_production(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $gate_album_frame_production$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 17 AND v_stage.stage_key = 'delivered')
    OR
    (v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_album_frame_production: booking must be exactly Delivered or Album / Frame Production replay'
      USING ERRCODE = '22023';
  END IF;

  -- Balance policy (revised): physical production is where the money gate
  -- sits. Nothing goes to a vendor while the client still owes, unless the
  -- actor holds the override permission.
  IF public.booking_outstanding_inr(
       v_booking.organization_id, v_booking.id
     ) > 0
     AND NOT public.has_permission(
               v_booking.organization_id,
               'delivery.balance_override',
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_album_frame_production: booking has an outstanding balance; album and frame production is blocked until it is settled'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_inbound_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id = transition_row.organization_id
   AND source_stage.id = transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND transition_row.transition_key = 'delivered'
    AND source_stage.stage_order = 16
    AND source_stage.stage_key = 'pixieset_gallery_ready'
    AND destination_stage.stage_order = 17
    AND destination_stage.stage_key = 'delivered';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical Delivered transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 18 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'album_frame_production'
      AND destination_stage.stage_order = 18
      AND destination_stage.stage_key = 'album_frame_production';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_album_frame_production: canonical Album / Frame Production transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 18
    AND stage.stage_key = 'album_frame_production'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical destination stage is unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  INSERT INTO public.booking_stage_transitions (
    organization_id, booking_id, from_stage_id, to_stage_id,
    transition_key, transitioned_at, transitioned_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id,
    v_state.current_stage_id, v_destination_stage_id,
    'album_frame_production', v_transitioned_at, v_actor
  );

  UPDATE public.booking_journey_states state
  SET current_stage_id = v_destination_stage_id,
      stage_entered_at = v_transitioned_at,
      version = state.version + 1,
      updated_at = v_transitioned_at,
      updated_by = v_actor
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
    AND state.current_stage_id = v_state.current_stage_id
    AND state.version = v_state.version;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  IF v_updated_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.album_frame_production', 'booking', v_booking.id, false,
    jsonb_build_object('journey_stage', v_stage.stage_key, 'journey_version', v_state.version),
    jsonb_build_object('journey_stage', 'album_frame_production', 'journey_version', v_state.version + 1),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'album_frame_production',
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application', NULL
  );

  RETURN v_booking;
END;
$gate_album_frame_production$;

REVOKE ALL ON FUNCTION public.mark_booking_album_frame_production(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_booking_album_frame_production(uuid) TO authenticated;

-- =====================================================================
-- Section F - Postconditions
-- =====================================================================

DO $postcondition$
DECLARE
  v_gallery_src text;
  v_delivery_src text;
  v_production_src text;
BEGIN
  IF to_regprocedure('public.booking_outstanding_inr(uuid, uuid)') IS NULL THEN
    RAISE EXCEPTION 'postcondition: booking_outstanding_inr was not created';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'booking_delivery_confirmations_override_chk'
  ) THEN
    RAISE EXCEPTION 'postcondition: balance override check constraint still present';
  END IF;

  SELECT prosrc INTO v_gallery_src FROM pg_proc
  WHERE oid = to_regprocedure('public.record_booking_gallery(uuid, text, boolean, boolean, timestamptz, text)');

  IF v_gallery_src NOT LIKE '%downloads cannot be enabled while a balance is outstanding%' THEN
    RAISE EXCEPTION 'postcondition: gallery download gate is missing';
  END IF;

  IF v_gallery_src NOT LIKE '%stage_order = 17%' THEN
    RAISE EXCEPTION 'postcondition: gallery stage admission was not widened';
  END IF;

  SELECT prosrc INTO v_delivery_src FROM pg_proc
  WHERE oid = to_regprocedure('public.record_booking_delivery_confirmation(uuid, text)');

  IF v_delivery_src LIKE '%delivery.balance_override permission required to deliver%' THEN
    RAISE EXCEPTION 'postcondition: delivery balance gate was not removed';
  END IF;

  SELECT prosrc INTO v_production_src FROM pg_proc
  WHERE oid = to_regprocedure('public.mark_booking_album_frame_production(uuid)');

  IF v_production_src NOT LIKE '%album and frame production is blocked until it is settled%' THEN
    RAISE EXCEPTION 'postcondition: production balance gate is missing';
  END IF;
END;
$postcondition$;
