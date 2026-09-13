-- =====================================================================
-- Delivery Pipeline 4 of 4 - Delivered
-- Gallery record + delivery confirmation + Stage 16 -> 17 gate
--
-- Boundary:
--   * narrow delivery.confirm and delivery.balance_override permissions;
--   * append-only booking_galleries evidence, keyed by round;
--   * one booking_delivery_confirmations row per booking;
--   * controlled record_booking_gallery(...) RPC;
--   * controlled record_booking_delivery_confirmation(...) RPC;
--   * controlled mark_booking_delivered(uuid) RPC;
--   * exact Stage 16 -> 17 advancement only;
--   * strict replay/idempotency;
--   * no album, frame, review or milestone implementation.
--
-- Balance authority:
--   Delivery is blocked while the accepted quotation total is not fully
--   collected. Outstanding balance is computed from canonical payment
--   evidence - the sum of booking_payments that carry no reversal - and
--   compared against booking_payment_requirements.accepted_quotation_total_inr.
--   Delivery with an outstanding balance requires BOTH a written reason AND
--   the delivery.balance_override permission, which is granted to founder
--   only. The outstanding amount at the moment of delivery is stored on the
--   confirmation row, so the decision stays reconstructable even after the
--   balance is later settled.
--
--   Gallery credentials are deliberately NOT stored. The record carries
--   whether a gallery is password protected, never the password itself.
-- =====================================================================

-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $dp4_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_galleries') IS NOT NULL
     OR to_regclass('public.booking_delivery_confirmations') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 precondition failed: delivery relation already exists';
  END IF;

  IF to_regprocedure('public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text)') IS NOT NULL
     OR to_regprocedure('public.record_booking_delivery_confirmation(uuid,text)') IS NOT NULL
     OR to_regprocedure('public.mark_booking_delivered(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 precondition failed: mutation RPC already exists';
  END IF;

  IF EXISTS (
        SELECT 1 FROM public.permissions
        WHERE key IN ('delivery.confirm', 'delivery.balance_override')
      ) THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 precondition failed: delivery permission already exists';
  END IF;

  IF to_regclass('public.booking_qc_reviews') IS NULL
     OR to_regclass('public.booking_payments') IS NULL
     OR to_regclass('public.booking_payment_reversals') IS NULL
     OR to_regclass('public.booking_payment_requirements') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 precondition failed: required foundation unavailable';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL
     OR to_regprocedure('public.mark_booking_gallery_ready(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (16, 17)
    AND stage_key IN ('pixieset_gallery_ready', 'delivered')
    AND is_active;

  IF v_count < 2 THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 precondition failed: canonical delivery stages unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 268 THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 precondition failed: expected canonical role-permission count 268, found %',
      v_count;
  END IF;
END
$dp4_preconditions$;

-- =====================================================================
-- Section B - Permissions
-- =====================================================================

INSERT INTO public.permissions (
  key, domain, label, description, requires_server_enforcement
)
VALUES
  (
    'delivery.confirm',
    'bookings',
    'Deliver gallery',
    'Record the client gallery for a booking and confirm delivery to the family.',
    true
  ),
  (
    'delivery.balance_override',
    'bookings',
    'Deliver with outstanding balance',
    'Confirm delivery while an accepted quotation balance remains outstanding, with a recorded reason.',
    true
  );

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN ('founder', 'studio_manager', 'client_coordinator')
  AND permission.key = 'delivery.confirm';

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key = 'founder'
  AND permission.key = 'delivery.balance_override';

-- =====================================================================
-- Section C - Gallery evidence
-- =====================================================================

CREATE TABLE public.booking_galleries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  round integer NOT NULL,
  provider text NOT NULL,
  gallery_url text NOT NULL,
  password_protected boolean NOT NULL,
  downloads_enabled boolean NOT NULL,
  expires_at timestamptz,
  gallery_note text,

  recorded_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_galleries_round_chk
    CHECK (round >= 1 AND round <= 50),

  CONSTRAINT booking_galleries_provider_chk
    CHECK (provider IN ('pixieset', 'other')),

  CONSTRAINT booking_galleries_gallery_url_scheme_chk
    CHECK (gallery_url ~* '^https://[^[:space:]]+$'),

  CONSTRAINT booking_galleries_gallery_url_chk
    CHECK (
      gallery_url = btrim(gallery_url)
      AND gallery_url <> ''
      AND btrim(
        gallery_url,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND gallery_url = btrim(gallery_url, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(gallery_url) <= 500
      AND gallery_url !~ '[[:cntrl:]]'
      AND gallery_url !~* '^(bearer|basic)[[:space:]]+'
      AND gallery_url !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND gallery_url !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
    ),

  CONSTRAINT booking_galleries_gallery_note_chk
    CHECK (
      gallery_note IS NULL
      OR (
      gallery_note = btrim(gallery_note)
      AND gallery_note <> ''
      AND btrim(
        gallery_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND gallery_note = btrim(gallery_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(gallery_note) <= 500
      AND gallery_note !~ '[[:cntrl:]]'
      AND gallery_note !~* '^(bearer|basic)[[:space:]]+'
      AND gallery_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND gallery_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_galleries_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_galleries_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_galleries_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_galleries_org_booking_round_key
    UNIQUE (organization_id, booking_id, round),

  CONSTRAINT booking_galleries_id_booking_key
    UNIQUE (id, booking_id)
);

CREATE INDEX booking_galleries_org_recorded_idx
ON public.booking_galleries (organization_id, recorded_at DESC);

CREATE INDEX booking_galleries_booking_round_idx
ON public.booking_galleries (booking_id, round DESC);

CREATE FUNCTION public.lsh_booking_gallery_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking galleries evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking galleries evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking galleries recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking galleries actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_galleries_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_galleries
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_gallery_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_gallery_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_gallery_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_gallery_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_gallery_guard() FROM service_role;

ALTER TABLE public.booking_galleries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_galleries FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_galleries FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_galleries FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_galleries FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_galleries FROM service_role;

GRANT SELECT ON TABLE public.booking_galleries TO authenticated;

CREATE POLICY booking_galleries_authenticated_select
ON public.booking_galleries
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_galleries.organization_id
      AND booking.id = booking_galleries.booking_id
      AND public.has_permission(
            booking.organization_id, 'booking.read', booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(booking.organization_id, booking.branch_id)
      )
  )
);

-- =====================================================================
-- Section D - Delivery confirmation evidence
-- =====================================================================

CREATE TABLE public.booking_delivery_confirmations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  gallery_id uuid NOT NULL,

  delivered_at timestamptz NOT NULL,

  quotation_total_inr integer NOT NULL,
  collected_inr integer NOT NULL,
  outstanding_inr integer NOT NULL,
  balance_override_reason text,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_delivery_confirmations_amount_chk
    CHECK (
      quotation_total_inr >= 0
      AND collected_inr >= 0
      AND outstanding_inr >= 0
      AND outstanding_inr = GREATEST(quotation_total_inr - collected_inr, 0)
    ),

  CONSTRAINT booking_delivery_confirmations_override_chk
    CHECK (
      (outstanding_inr = 0 AND balance_override_reason IS NULL)
      OR
      (outstanding_inr > 0 AND balance_override_reason IS NOT NULL)
    ),

  CONSTRAINT booking_delivery_confirmations_balance_override_reason_chk
    CHECK (
      balance_override_reason IS NULL
      OR (
      balance_override_reason = btrim(balance_override_reason)
      AND balance_override_reason <> ''
      AND btrim(
        balance_override_reason,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND balance_override_reason = btrim(balance_override_reason, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(balance_override_reason) <= 500
      AND balance_override_reason !~ '[[:cntrl:]]'
      AND balance_override_reason !~* '^(bearer|basic)[[:space:]]+'
      AND balance_override_reason !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND balance_override_reason !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_delivery_confirmations_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_delivery_confirmations_gallery_fkey
    FOREIGN KEY (gallery_id, booking_id)
    REFERENCES public.booking_galleries (id, booking_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_delivery_confirmations_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_delivery_confirmations_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_delivery_confirmations_org_booking_key
    UNIQUE (organization_id, booking_id)
);

CREATE INDEX booking_delivery_confirmations_org_delivered_idx
ON public.booking_delivery_confirmations (organization_id, delivered_at DESC);

CREATE FUNCTION public.lsh_booking_delivery_confirmation_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking delivery confirmations evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking delivery confirmations evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking delivery confirmations recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking delivery confirmations actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_delivery_confirmations_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_delivery_confirmations
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_delivery_confirmation_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_delivery_confirmation_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_delivery_confirmation_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_delivery_confirmation_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_delivery_confirmation_guard() FROM service_role;

ALTER TABLE public.booking_delivery_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_delivery_confirmations FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_delivery_confirmations FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_delivery_confirmations FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_delivery_confirmations FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_delivery_confirmations FROM service_role;

GRANT SELECT ON TABLE public.booking_delivery_confirmations TO authenticated;

CREATE POLICY booking_delivery_confirmations_authenticated_select
ON public.booking_delivery_confirmations
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_delivery_confirmations.organization_id
      AND booking.id = booking_delivery_confirmations.booking_id
      AND public.has_permission(
            booking.organization_id, 'booking.read', booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(booking.organization_id, booking.branch_id)
      )
  )
);

-- =====================================================================
-- Section E - Gallery RPC
-- =====================================================================

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
    v_stage.stage_order = 16 AND v_stage.stage_key = 'pixieset_gallery_ready'
  ) THEN
    RAISE EXCEPTION
      'record_booking_gallery: booking must be exactly Gallery Ready'
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

REVOKE ALL ON FUNCTION public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text) IS
  'Records a client gallery for a booking at Gallery Ready (16). Stores the https gallery address and access flags. Never stores gallery credentials. Does not advance the booking journey stage.';

-- =====================================================================
-- Section F - Delivery confirmation RPC
-- =====================================================================

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

  IF v_outstanding > 0 THEN
    IF v_reason IS NULL THEN
      RAISE EXCEPTION
        'record_booking_delivery_confirmation: booking has an outstanding balance and requires a written override reason'
        USING ERRCODE = '22023';
    END IF;

    IF NOT public.has_permission(
             v_booking.organization_id,
             'delivery.balance_override',
             v_booking.branch_id
           ) THEN
      RAISE EXCEPTION
        'record_booking_delivery_confirmation: delivery.balance_override permission required to deliver with an outstanding balance'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    v_reason := NULL;
  END IF;

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

REVOKE ALL ON FUNCTION public.record_booking_delivery_confirmation(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_delivery_confirmation(uuid,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_delivery_confirmation(uuid,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_delivery_confirmation(uuid,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_delivery_confirmation(uuid,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_delivery_confirmation(uuid,text) IS
  'Confirms gallery delivery for a booking at Gallery Ready (16). Blocks while the accepted quotation balance is outstanding unless a written reason is supplied by a holder of delivery.balance_override. Stores the outstanding amount at the moment of delivery. Does not advance the booking journey stage.';

-- =====================================================================
-- Section G - Stage 16 -> 17 gate
-- =====================================================================

CREATE FUNCTION public.mark_booking_delivered(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $gate_delivered$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_confirmation public.booking_delivery_confirmations;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_delivered: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_delivered: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_delivered: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_delivered: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_delivered: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_delivered: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_delivered: canonical journey state is invalid'
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
    RAISE EXCEPTION 'mark_booking_delivered: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 16 AND v_stage.stage_key = 'pixieset_gallery_ready')
    OR
    (v_stage.stage_order = 17 AND v_stage.stage_key = 'delivered')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_delivered: booking must be exactly Gallery Ready or Delivered replay'
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
    AND transition_row.transition_key = 'pixieset_gallery_ready'
    AND source_stage.stage_order = 15
    AND source_stage.stage_key = 'qc_pending'
    AND destination_stage.stage_order = 16
    AND destination_stage.stage_key = 'pixieset_gallery_ready';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_delivered: canonical Gallery Ready transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 17 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'delivered'
      AND destination_stage.stage_order = 17
      AND destination_stage.stage_key = 'delivered';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_delivered: canonical Delivered transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  SELECT confirmation.* INTO v_confirmation
  FROM public.booking_delivery_confirmations confirmation
  WHERE confirmation.organization_id = v_booking.organization_id
    AND confirmation.booking_id = v_booking.id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_delivered: booking requires a recorded delivery confirmation'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 17
    AND stage.stage_key = 'delivered'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_delivered: canonical destination stage is unavailable'
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
    'delivered', v_transitioned_at, v_actor
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
    RAISE EXCEPTION 'mark_booking_delivered: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.delivered',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage', v_stage.stage_key,
      'journey_version', v_state.version
    ),
    jsonb_build_object(
      'journey_stage', 'delivered',
      'journey_version', v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'delivered',
      'delivery_confirmation_id', v_confirmation.id,
      'outstanding_inr', v_confirmation.outstanding_inr,
      'balance_overridden', (v_confirmation.balance_override_reason IS NOT NULL),
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$gate_delivered$;

REVOKE ALL ON FUNCTION public.mark_booking_delivered(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_booking_delivered(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_delivered(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_delivered(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_delivered(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_delivered(uuid) IS
  'Advances a booking from Gallery Ready (16) to Delivered (17). Requires a recorded delivery confirmation. Idempotent on replay.';

-- =====================================================================
-- Section H - Postconditions
-- =====================================================================

DO $dp4_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_galleries') IS NULL OR to_regclass('public.booking_delivery_confirmations') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: delivery relation missing';
  END IF;

  IF to_regprocedure('public.record_booking_gallery(uuid,text,boolean,boolean,timestamptz,text)') IS NULL
     OR to_regprocedure('public.record_booking_delivery_confirmation(uuid,text)') IS NULL
     OR to_regprocedure('public.mark_booking_delivered(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: required mutation RPC missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission ON permission.id = role_permission.permission_id
  WHERE permission.key = 'delivery.confirm';

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: delivery.confirm role boundary invalid';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission ON permission.id = role_permission.permission_id
  JOIN public.roles role ON role.id = role_permission.role_id
  WHERE permission.key = 'delivery.balance_override';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: delivery.balance_override must be founder only';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 272 THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: expected role-permission count 272, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname IN ('booking_galleries', 'booking_delivery_confirmations')
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: row level security not forced';
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_delivered(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_delivered(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.record_booking_delivery_confirmation(uuid,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.record_booking_delivery_confirmation(uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: privileged execute must be denied';
  END IF;

  IF has_table_privilege('authenticated', 'public.booking_galleries', 'INSERT')
     OR has_table_privilege('authenticated', 'public.booking_delivery_confirmations', 'INSERT')
     OR has_table_privilege('authenticated', 'public.booking_delivery_confirmations', 'UPDATE') THEN
    RAISE EXCEPTION
      'Delivery pipeline 4 postcondition failed: evidence tables must be read-only to authenticated';
  END IF;
END
$dp4_postconditions$;
