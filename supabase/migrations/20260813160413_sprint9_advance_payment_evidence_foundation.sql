-- =====================================================================
-- Sprint 9 — Advance Payment, Booking Confirmation & KPI Foundation
-- Slice 1 — Advance Payment Evidence Foundation
--
-- Status:
--   Implementation in progress.
--
-- Frozen commercial rule:
--   required advance = 50% of final accepted quotation value
--   whole INR only
--   half-rupee rounds upward
--
-- Exact integer rule:
--   required_advance_inr = (accepted_quotation_total_inr + 1) / 2
--
-- Slice 1 authority:
--   * immutable booking payment requirement snapshot
--   * immutable payment receipt evidence
--   * immutable reversal evidence
--   * payment.read / payment.record / payment.reverse permissions
--   * Founder-only initial grants
--   * permission-scoped reads
--   * RPC-only writes
--   * authoritative derived payment summary
--
-- Frozen payment methods:
--   cash
--   upi
--   bank_transfer
--   card
--   other
--
-- Explicitly NOT in this slice:
--   * Booking Confirmed transition
--   * generic booking-stage advancement
--   * KPI dashboard
--   * revenue recognition
--   * GST/accounting invoicing
--   * refunds
--   * payment gateway integration
--
-- Payment correction rule:
--   original payment -> immutable reversal -> new payment
--
-- Historical rule:
--   a later reversal must never rewrite a valid historical booking
--   journey transition.
-- =====================================================================


-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s9_payment_preconditions$
BEGIN
  IF to_regclass('public.bookings') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 precondition failed: public.bookings missing';
  END IF;

  IF to_regclass('public.quotations') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 precondition failed: public.quotations missing';
  END IF;

  IF to_regclass('public.organization_members') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 precondition failed: public.organization_members missing';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 precondition failed: current_organization_member(uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 precondition failed: has_permission(uuid,text,uuid) missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles
    WHERE key = 'founder'
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 precondition failed: founder role missing';
  END IF;
END
$s9_payment_preconditions$;

-- =====================================================================
-- Section B — Canonical payment vocabulary + permissions
-- =====================================================================

CREATE TYPE public.booking_payment_method AS ENUM (
  'cash',
  'upi',
  'bank_transfer',
  'card',
  'other'
);

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES
(
  'payment.read',
  'finance',
  'View booking payments',
  'Read authoritative booking payment requirements, receipts, reversals and derived payment state.',
  true
),
(
  'payment.record',
  'finance',
  'Record booking payments',
  'Append authoritative whole-INR payment evidence to a canonical booking.',
  true
),
(
  'payment.reverse',
  'finance',
  'Reverse booking payments',
  'Append an immutable reversal against an incorrectly recorded booking payment.',
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
  AND p.key IN (
    'payment.read',
    'payment.record',
    'payment.reverse'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- =====================================================================
-- Section C — Immutable advance requirement snapshot
-- =====================================================================

CREATE TABLE public.booking_payment_requirements (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id               uuid NOT NULL,
  booking_id                    uuid NOT NULL,
  source_quotation_id           uuid NOT NULL,
  currency                      text NOT NULL DEFAULT 'INR',
  accepted_quotation_total_inr  integer NOT NULL,
  advance_percentage            integer NOT NULL DEFAULT 50,
  calculation_rule              text NOT NULL
                                DEFAULT 'accepted_quote_50_percent_round_half_up',
  required_advance_inr          integer NOT NULL,
  created_at                    timestamptz NOT NULL DEFAULT now(),
  created_by                    uuid NOT NULL,

  CONSTRAINT booking_payment_requirements_org_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_requirements_booking_fkey
    FOREIGN KEY (
      organization_id,
      booking_id
    )
    REFERENCES public.bookings (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_requirements_quote_fkey
    FOREIGN KEY (
      organization_id,
      source_quotation_id
    )
    REFERENCES public.quotations (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_requirements_created_by_fkey
    FOREIGN KEY (
      created_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_requirements_currency_chk
    CHECK (currency = 'INR'),

  CONSTRAINT booking_payment_requirements_quote_total_chk
    CHECK (accepted_quotation_total_inr > 0),

  CONSTRAINT booking_payment_requirements_percentage_chk
    CHECK (advance_percentage = 50),

  CONSTRAINT booking_payment_requirements_rule_chk
    CHECK (
      calculation_rule =
        'accepted_quote_50_percent_round_half_up'
    ),

  CONSTRAINT booking_payment_requirements_amount_chk
    CHECK (
      required_advance_inr =
        ((accepted_quotation_total_inr + 1) / 2)
      AND required_advance_inr > 0
    ),

  CONSTRAINT booking_payment_requirements_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    ),

  CONSTRAINT booking_payment_requirements_org_id_key
    UNIQUE (
      organization_id,
      id
    )
);

CREATE INDEX booking_payment_requirements_org_quote_idx
  ON public.booking_payment_requirements (
    organization_id,
    source_quotation_id
  );

-- =====================================================================
-- Section D — Immutable payment receipt evidence
-- =====================================================================

CREATE TABLE public.booking_payments (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id     uuid NOT NULL,
  booking_id          uuid NOT NULL,
  branch_id           uuid,
  payment_reference   text NOT NULL,
  currency            text NOT NULL DEFAULT 'INR',
  amount_inr          integer NOT NULL,
  received_at         timestamptz NOT NULL,
  payment_method      public.booking_payment_method NOT NULL,
  external_reference  text,
  note                text,
  recorded_at         timestamptz NOT NULL DEFAULT now(),
  recorded_by         uuid NOT NULL,

  CONSTRAINT booking_payments_org_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payments_booking_fkey
    FOREIGN KEY (
      organization_id,
      booking_id
    )
    REFERENCES public.bookings (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payments_branch_fkey
    FOREIGN KEY (
      branch_id,
      organization_id
    )
    REFERENCES public.branches (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payments_recorded_by_fkey
    FOREIGN KEY (
      recorded_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payments_currency_chk
    CHECK (currency = 'INR'),

  CONSTRAINT booking_payments_amount_chk
    CHECK (amount_inr > 0),

  CONSTRAINT booking_payments_reference_format_chk
    CHECK (
      payment_reference ~ '^LSH-PAY-[A-F0-9]{8}$'
    ),

  CONSTRAINT booking_payments_external_reference_chk
    CHECK (
      external_reference IS NULL
      OR char_length(btrim(external_reference))
           BETWEEN 1 AND 160
    ),

  CONSTRAINT booking_payments_note_chk
    CHECK (
      note IS NULL
      OR char_length(btrim(note))
           BETWEEN 1 AND 1000
    ),

  CONSTRAINT booking_payments_org_reference_key
    UNIQUE (
      organization_id,
      payment_reference
    ),

  CONSTRAINT booking_payments_org_id_key
    UNIQUE (
      organization_id,
      id
    ),

  CONSTRAINT booking_payments_org_booking_id_key
    UNIQUE (
      organization_id,
      booking_id,
      id
    )
);

CREATE INDEX booking_payments_org_booking_received_idx
  ON public.booking_payments (
    organization_id,
    booking_id,
    received_at
  );

CREATE INDEX booking_payments_org_branch_received_idx
  ON public.booking_payments (
    organization_id,
    branch_id,
    received_at
  );

-- =====================================================================
-- Section E — Immutable payment reversal evidence
-- =====================================================================

CREATE TABLE public.booking_payment_reversals (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL,
  booking_id       uuid NOT NULL,
  payment_id       uuid NOT NULL,
  reason           text NOT NULL,
  reversed_at      timestamptz NOT NULL DEFAULT now(),
  reversed_by      uuid NOT NULL,

  CONSTRAINT booking_payment_reversals_org_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_reversals_booking_fkey
    FOREIGN KEY (
      organization_id,
      booking_id
    )
    REFERENCES public.bookings (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_reversals_payment_fkey
    FOREIGN KEY (
      organization_id,
      booking_id,
      payment_id
    )
    REFERENCES public.booking_payments (
      organization_id,
      booking_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_reversals_reversed_by_fkey
    FOREIGN KEY (
      reversed_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_payment_reversals_reason_chk
    CHECK (
      char_length(btrim(reason))
        BETWEEN 1 AND 1000
    ),

  CONSTRAINT booking_payment_reversals_org_payment_key
    UNIQUE (
      organization_id,
      payment_id
    ),

  CONSTRAINT booking_payment_reversals_org_id_key
    UNIQUE (
      organization_id,
      id
    )
);

CREATE INDEX booking_payment_reversals_org_booking_idx
  ON public.booking_payment_reversals (
    organization_id,
    booking_id,
    reversed_at
  );

-- =====================================================================
-- Section F — Invariant guards
-- =====================================================================

CREATE OR REPLACE FUNCTION
public.lsh_booking_payment_requirement_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_quote public.quotations;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    RAISE EXCEPTION
      'booking payment requirements are immutable';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.organization_id = NEW.organization_id
    AND b.id = NEW.booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking payment requirement requires canonical booking';
  END IF;

  IF v_booking.source_quotation_id
       IS DISTINCT FROM NEW.source_quotation_id THEN
    RAISE EXCEPTION
      'booking payment requirement quotation does not match booking';
  END IF;

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.organization_id = NEW.organization_id
    AND q.id = NEW.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <> 'accepted' THEN
    RAISE EXCEPTION
      'booking payment requirement requires accepted quotation';
  END IF;

  IF NEW.currency IS DISTINCT FROM v_quote.currency
     OR NEW.currency <> 'INR' THEN
    RAISE EXCEPTION
      'booking payment requirement currency must match accepted INR quotation';
  END IF;

  IF NEW.accepted_quotation_total_inr
       IS DISTINCT FROM v_quote.quoted_total_inr THEN
    RAISE EXCEPTION
      'booking payment requirement total must snapshot accepted quotation';
  END IF;

  IF NEW.required_advance_inr
       IS DISTINCT FROM
         ((v_quote.quoted_total_inr + 1) / 2) THEN
    RAISE EXCEPTION
      'booking payment requirement advance must equal frozen 50 percent rule';
  END IF;

  IF NEW.created_by
       IS DISTINCT FROM v_booking.created_by THEN
    RAISE EXCEPTION
      'booking payment requirement actor must match booking creator';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_payment_requirements_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_payment_requirements
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_payment_requirement_guard();

CREATE OR REPLACE FUNCTION
public.lsh_booking_payment_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    RAISE EXCEPTION
      'booking payments are append-only and immutable';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.organization_id = NEW.organization_id
    AND b.id = NEW.booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking payment requires canonical booking';
  END IF;

  IF NEW.branch_id
       IS DISTINCT FROM v_booking.branch_id THEN
    RAISE EXCEPTION
      'booking payment branch must match booking branch';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking payment actor must be current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_payments_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_payments
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_payment_guard();

CREATE OR REPLACE FUNCTION
public.lsh_booking_payment_reversal_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_payment public.booking_payments;
  v_actor uuid;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    RAISE EXCEPTION
      'booking payment reversals are append-only and immutable';
  END IF;

  SELECT p.*
  INTO v_payment
  FROM public.booking_payments p
  WHERE p.organization_id = NEW.organization_id
    AND p.booking_id = NEW.booking_id
    AND p.id = NEW.payment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking payment reversal requires matching payment evidence';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.reversed_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking payment reversal actor must be current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_payment_reversals_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_payment_reversals
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_payment_reversal_guard();

-- =====================================================================
-- Section G — Existing booking backfill
-- =====================================================================

INSERT INTO public.booking_payment_requirements (
  organization_id,
  booking_id,
  source_quotation_id,
  currency,
  accepted_quotation_total_inr,
  advance_percentage,
  calculation_rule,
  required_advance_inr,
  created_by
)
SELECT
  b.organization_id,
  b.id,
  b.source_quotation_id,
  q.currency,
  q.quoted_total_inr,
  50,
  'accepted_quote_50_percent_round_half_up',
  ((q.quoted_total_inr + 1) / 2),
  b.created_by
FROM public.bookings b
JOIN public.quotations q
  ON q.organization_id = b.organization_id
 AND q.id = b.source_quotation_id
WHERE q.status = 'accepted'
ON CONFLICT (
  organization_id,
  booking_id
) DO NOTHING;

-- Every existing canonical booking must now have exactly one requirement.
DO $s9_payment_backfill_gate$
DECLARE
  v_missing integer;
BEGIN
  SELECT count(*)
  INTO v_missing
  FROM public.bookings b
  LEFT JOIN public.booking_payment_requirements r
    ON r.organization_id = b.organization_id
   AND r.booking_id = b.id
  WHERE r.id IS NULL;

  IF v_missing <> 0 THEN
    RAISE EXCEPTION
      'Sprint 9 payment backfill failed: % canonical bookings lack advance requirement',
      v_missing;
  END IF;
END
$s9_payment_backfill_gate$;

-- =====================================================================
-- Section H — Atomic requirement creation for future bookings
-- =====================================================================

CREATE OR REPLACE FUNCTION
public.lsh_initialize_booking_payment_requirement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
BEGIN
  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.organization_id = NEW.organization_id
    AND q.id = NEW.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <> 'accepted' THEN
    RAISE EXCEPTION
      'booking payment initialization requires accepted quotation';
  END IF;

  IF v_quote.currency <> 'INR'
     OR v_quote.quoted_total_inr <= 0 THEN
    RAISE EXCEPTION
      'booking payment initialization requires positive INR quotation';
  END IF;

  INSERT INTO public.booking_payment_requirements (
    organization_id,
    booking_id,
    source_quotation_id,
    currency,
    accepted_quotation_total_inr,
    advance_percentage,
    calculation_rule,
    required_advance_inr,
    created_by
  )
  VALUES (
    NEW.organization_id,
    NEW.id,
    NEW.source_quotation_id,
    v_quote.currency,
    v_quote.quoted_total_inr,
    50,
    'accepted_quote_50_percent_round_half_up',
    ((v_quote.quoted_total_inr + 1) / 2),
    NEW.created_by
  );

  RETURN NEW;
END
$$;

CREATE TRIGGER bookings_initialize_payment_requirement
AFTER INSERT
ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_initialize_booking_payment_requirement();

-- =====================================================================
-- Section I — RLS and least privilege
-- =====================================================================

ALTER TABLE public.booking_payment_requirements
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_payment_requirements
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.booking_payments
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_payments
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.booking_payment_reversals
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_payment_reversals
  FORCE ROW LEVEL SECURITY;

CREATE POLICY booking_payment_requirements_staff_read
ON public.booking_payment_requirements
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          booking_payment_requirements.organization_id
      AND b.id =
          booking_payment_requirements.booking_id
      AND public.has_permission(
        b.organization_id,
        'payment.read',
        b.branch_id
      )
  )
);

CREATE POLICY booking_payments_staff_read
ON public.booking_payments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          booking_payments.organization_id
      AND b.id =
          booking_payments.booking_id
      AND public.has_permission(
        b.organization_id,
        'payment.read',
        b.branch_id
      )
  )
);

CREATE POLICY booking_payment_reversals_staff_read
ON public.booking_payment_reversals
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          booking_payment_reversals.organization_id
      AND b.id =
          booking_payment_reversals.booking_id
      AND public.has_permission(
        b.organization_id,
        'payment.read',
        b.branch_id
      )
  )
);

REVOKE ALL PRIVILEGES
ON TABLE
  public.booking_payment_requirements,
  public.booking_payments,
  public.booking_payment_reversals
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE
  public.booking_payment_requirements,
  public.booking_payments,
  public.booking_payment_reversals
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE
  public.booking_payment_requirements,
  public.booking_payments,
  public.booking_payment_reversals
TO service_role;

-- Internal invariant/trigger helpers are never browser-callable.

REVOKE ALL
ON FUNCTION public.lsh_booking_payment_requirement_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_booking_payment_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_booking_payment_reversal_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_initialize_booking_payment_requirement()
FROM PUBLIC, anon, authenticated;

-- =====================================================================
-- Section J — Slice 1A migration gates
-- =====================================================================

DO $s9_payment_slice1a_assertions$
DECLARE
  v_count integer;
BEGIN
  -- Three new permissions.
  SELECT count(*)
  INTO v_count
  FROM public.permissions
  WHERE key IN (
    'payment.read',
    'payment.record',
    'payment.reverse'
  );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: expected 3 payment permissions, found %',
      v_count;
  END IF;

  -- Founder receives all three.
  SELECT count(*)
  INTO v_count
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
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: founder payment grants incomplete';
  END IF;

  -- Three authoritative payment tables.
  IF to_regclass(
       'public.booking_payment_requirements'
     ) IS NULL
     OR to_regclass(
       'public.booking_payments'
     ) IS NULL
     OR to_regclass(
       'public.booking_payment_reversals'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: payment tables missing';
  END IF;

  -- RLS + FORCE RLS on all three.
  SELECT count(*)
  INTO v_count
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
    AND c.relforcerowsecurity;

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: payment RLS hardening incomplete';
  END IF;

  -- Every booking has exactly one requirement.
  SELECT count(*)
  INTO v_count
  FROM public.bookings b
  WHERE (
    SELECT count(*)
    FROM public.booking_payment_requirements r
    WHERE r.organization_id = b.organization_id
      AND r.booking_id = b.id
  ) <> 1;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: booking requirement cardinality invalid';
  END IF;

  -- Requirement rows exactly match immutable accepted quote snapshots.
  SELECT count(*)
  INTO v_count
  FROM public.booking_payment_requirements r
  JOIN public.bookings b
    ON b.organization_id = r.organization_id
   AND b.id = r.booking_id
  JOIN public.quotations q
    ON q.organization_id = r.organization_id
   AND q.id = r.source_quotation_id
  WHERE b.source_quotation_id
          IS DISTINCT FROM r.source_quotation_id
     OR q.status <> 'accepted'
     OR r.currency <> 'INR'
     OR r.currency IS DISTINCT FROM q.currency
     OR r.accepted_quotation_total_inr
          IS DISTINCT FROM q.quoted_total_inr
     OR r.required_advance_inr
          IS DISTINCT FROM
            ((q.quoted_total_inr + 1) / 2);

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: requirement snapshot mismatch';
  END IF;

  -- The frozen round-half-up examples must remain exact.
  IF ((15000 + 1) / 2) <> 7500
     OR ((15001 + 1) / 2) <> 7501 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: whole-INR 50 percent calculation invalid';
  END IF;

  -- Authenticated staff get SELECT only; mutation stays RPC-only.
  IF NOT has_table_privilege(
       'authenticated',
       'public.booking_payment_requirements',
       'SELECT'
     )
     OR NOT has_table_privilege(
       'authenticated',
       'public.booking_payments',
       'SELECT'
     )
     OR NOT has_table_privilege(
       'authenticated',
       'public.booking_payment_reversals',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: authenticated payment SELECT missing';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.booking_payment_requirements',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payment_requirements',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payment_requirements',
       'DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payments',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payments',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payments',
       'DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payment_reversals',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payment_reversals',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_payment_reversals',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: authenticated direct payment write detected';
  END IF;

  -- Anonymous users receive no payment visibility.
  IF has_table_privilege(
       'anon',
       'public.booking_payment_requirements',
       'SELECT'
     )
     OR has_table_privilege(
       'anon',
       'public.booking_payments',
       'SELECT'
     )
     OR has_table_privilege(
       'anon',
       'public.booking_payment_reversals',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: anonymous payment access detected';
  END IF;

  -- No legacy mutable payment truth is added to bookings.
  SELECT count(*)
  INTO v_count
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
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: mutable financial truth detected on bookings';
  END IF;

  -- Future booking initialization trigger exists.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    WHERE t.tgrelid =
          'public.bookings'::regclass
      AND t.tgname =
          'bookings_initialize_payment_requirement'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1A failed: booking requirement initializer missing';
  END IF;
END
$s9_payment_slice1a_assertions$;

-- SPRINT_9_SLICE_1A_END

-- =====================================================================
-- Section K — Record authoritative payment evidence
-- =====================================================================

CREATE OR REPLACE FUNCTION public.record_booking_payment(
  p_booking_id uuid,
  p_amount_inr integer,
  p_payment_method public.booking_payment_method,
  p_received_at timestamptz DEFAULT now(),
  p_external_reference text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS public.booking_payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_requirement public.booking_payment_requirements;
  v_actor uuid;
  v_payment public.booking_payments;
  v_payment_id uuid;
  v_payment_reference text;
  v_attempt integer := 0;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_payment: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_amount_inr IS NULL OR p_amount_inr <= 0 THEN
    RAISE EXCEPTION
      'record_booking_payment: amount_inr must be greater than zero'
      USING ERRCODE = '22023';
  END IF;

  IF p_payment_method IS NULL THEN
    RAISE EXCEPTION
      'record_booking_payment: payment_method is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_received_at IS NULL THEN
    RAISE EXCEPTION
      'record_booking_payment: received_at is required'
      USING ERRCODE = '22023';
  END IF;

  -- One serialization boundary per booking.
  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_payment: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_payment: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'payment.record',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'record_booking_payment: payment.record permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_booking.organization_id,
       v_booking.branch_id
     ) THEN
    RAISE EXCEPTION
      'record_booking_payment: no access to booking branch'
      USING ERRCODE = '42501';
  END IF;

  SELECT r.*
  INTO v_requirement
  FROM public.booking_payment_requirements r
  WHERE r.organization_id =
        v_booking.organization_id
    AND r.booking_id =
        v_booking.id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_payment: booking payment requirement missing'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_requirement.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id THEN
    RAISE EXCEPTION
      'record_booking_payment: payment requirement quotation mismatch'
      USING ERRCODE = 'P0001';
  END IF;

  LOOP
    v_attempt := v_attempt + 1;
    v_payment_id := gen_random_uuid();

    v_payment_reference :=
      'LSH-PAY-' ||
      upper(
        substr(
          replace(v_payment_id::text, '-', ''),
          1,
          8
        )
      );

    BEGIN
      INSERT INTO public.booking_payments (
        id,
        organization_id,
        booking_id,
        branch_id,
        payment_reference,
        currency,
        amount_inr,
        received_at,
        payment_method,
        external_reference,
        note,
        recorded_by
      )
      VALUES (
        v_payment_id,
        v_booking.organization_id,
        v_booking.id,
        v_booking.branch_id,
        v_payment_reference,
        'INR',
        p_amount_inr,
        p_received_at,
        p_payment_method,
        NULLIF(
          btrim(p_external_reference),
          ''
        ),
        NULLIF(
          btrim(p_note),
          ''
        ),
        v_actor
      )
      RETURNING *
      INTO v_payment;

      EXIT;

    EXCEPTION
      WHEN unique_violation THEN
        IF v_attempt >= 5 THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'payment.recorded',
    'booking_payment',
    v_payment.id,
    true,
    NULL,
    jsonb_build_object(
      'amount_inr',
        v_payment.amount_inr,
      'currency',
        v_payment.currency,
      'payment_method',
        v_payment.payment_method::text,
      'received_at',
        v_payment.received_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'payment_reference',
        v_payment.payment_reference
    ),
    'finance',
    NULL
  );

  RETURN v_payment;
END
$$;

-- =====================================================================
-- Section L — Append immutable payment reversal evidence
-- =====================================================================

CREATE OR REPLACE FUNCTION public.reverse_booking_payment(
  p_payment_id uuid,
  p_reason text
)
RETURNS public.booking_payment_reversals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_payment public.booking_payments;
  v_booking public.bookings;
  v_actor uuid;
  v_reversal public.booking_payment_reversals;
BEGIN
  IF p_payment_id IS NULL THEN
    RAISE EXCEPTION
      'reverse_booking_payment: payment_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_reason IS NULL
     OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION
      'reverse_booking_payment: reason is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT p.*
  INTO v_payment
  FROM public.booking_payments p
  WHERE p.id = p_payment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'reverse_booking_payment: payment not found'
      USING ERRCODE = '22023';
  END IF;

  -- Serialize every financial mutation for this booking.
  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.organization_id =
        v_payment.organization_id
    AND b.id =
        v_payment.booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'reverse_booking_payment: canonical booking missing'
      USING ERRCODE = 'P0001';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'reverse_booking_payment: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'payment.reverse',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'reverse_booking_payment: payment.reverse permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_booking.organization_id,
       v_booking.branch_id
     ) THEN
    RAISE EXCEPTION
      'reverse_booking_payment: no access to booking branch'
      USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.booking_payment_reversals r
    WHERE r.organization_id =
          v_payment.organization_id
      AND r.payment_id =
          v_payment.id
  ) THEN
    RAISE EXCEPTION
      'reverse_booking_payment: payment is already reversed'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_payment_reversals (
    organization_id,
    booking_id,
    payment_id,
    reason,
    reversed_by
  )
  VALUES (
    v_payment.organization_id,
    v_payment.booking_id,
    v_payment.id,
    btrim(p_reason),
    v_actor
  )
  RETURNING *
  INTO v_reversal;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'payment.reversed',
    'booking_payment_reversal',
    v_reversal.id,
    true,
    NULL,
    jsonb_build_object(
      'payment_id',
        v_payment.id,
      'amount_inr',
        v_payment.amount_inr,
      'reversed_at',
        v_reversal.reversed_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'payment_reference',
        v_payment.payment_reference
    ),
    'finance',
    NULL
  );

  RETURN v_reversal;
END
$$;

-- =====================================================================
-- Section M — Authoritative derived payment summary
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_booking_payment_summary(
  p_booking_id uuid
)
RETURNS TABLE (
  booking_id uuid,
  source_quotation_id uuid,
  accepted_quotation_total_inr integer,
  required_advance_inr integer,
  valid_collected_inr bigint,
  advance_outstanding_inr bigint,
  advance_satisfied boolean,
  payment_count bigint,
  reversal_count bigint,
  confirmed_with_advance_shortfall boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_requirement public.booking_payment_requirements;
  v_actor uuid;
  v_valid_collected bigint;
  v_payment_count bigint;
  v_reversal_count bigint;
  v_was_confirmed boolean;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'get_booking_payment_summary: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'get_booking_payment_summary: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_booking_payment_summary: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'payment.read',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'get_booking_payment_summary: payment.read permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_booking.organization_id,
       v_booking.branch_id
     ) THEN
    RAISE EXCEPTION
      'get_booking_payment_summary: no access to booking branch'
      USING ERRCODE = '42501';
  END IF;

  SELECT r.*
  INTO v_requirement
  FROM public.booking_payment_requirements r
  WHERE r.organization_id =
        v_booking.organization_id
    AND r.booking_id =
        v_booking.id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'get_booking_payment_summary: booking payment requirement missing'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT
    COALESCE(
      sum(p.amount_inr)
        FILTER (
          WHERE rv.id IS NULL
        ),
      0
    )::bigint,
    count(p.id)::bigint,
    count(rv.id)::bigint
  INTO
    v_valid_collected,
    v_payment_count,
    v_reversal_count
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

  -- Historical confirmation remains historical truth even if a later
  -- reversal creates a current financial shortfall.
  SELECT EXISTS (
    SELECT 1
    FROM public.booking_stage_transitions t
    JOIN public.booking_journey_stages from_stage
      ON from_stage.organization_id =
         t.organization_id
     AND from_stage.id =
         t.from_stage_id
    JOIN public.booking_journey_stages to_stage
      ON to_stage.organization_id =
         t.organization_id
     AND to_stage.id =
         t.to_stage_id
    WHERE t.organization_id =
          v_booking.organization_id
      AND t.booking_id =
          v_booking.id
      AND from_stage.stage_key =
          'advance_pending'
      AND to_stage.stage_key =
          'booking_confirmed'
      AND t.transition_key =
          'advance_satisfied'
  )
  INTO v_was_confirmed;

  RETURN QUERY
  SELECT
    v_booking.id,
    v_booking.source_quotation_id,
    v_requirement.accepted_quotation_total_inr,
    v_requirement.required_advance_inr,
    v_valid_collected,
    GREATEST(
      v_requirement.required_advance_inr::bigint -
        v_valid_collected,
      0::bigint
    ),
    (
      v_valid_collected >=
        v_requirement.required_advance_inr
    ),
    v_payment_count,
    v_reversal_count,
    (
      v_was_confirmed
      AND v_valid_collected <
          v_requirement.required_advance_inr
    );
END
$$;

-- =====================================================================
-- Section N — RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.record_booking_payment(
  uuid,
  integer,
  public.booking_payment_method,
  timestamptz,
  text,
  text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.record_booking_payment(
  uuid,
  integer,
  public.booking_payment_method,
  timestamptz,
  text,
  text
)
TO authenticated;

REVOKE ALL
ON FUNCTION public.reverse_booking_payment(
  uuid,
  text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.reverse_booking_payment(
  uuid,
  text
)
TO authenticated;

REVOKE ALL
ON FUNCTION public.get_booking_payment_summary(
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.get_booking_payment_summary(
  uuid
)
TO authenticated;

-- =====================================================================
-- Section O — Slice 1B migration gates
-- =====================================================================

DO $s9_payment_slice1b_assertions$
DECLARE
  v_fn regprocedure;
BEGIN
  v_fn :=
    to_regprocedure(
      'public.record_booking_payment(uuid,integer,public.booking_payment_method,timestamp with time zone,text,text)'
    );

  IF v_fn IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: record_booking_payment() missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid = v_fn::oid
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: record_booking_payment() must be SECURITY DEFINER';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: authenticated payment record EXECUTE missing';
  END IF;

  IF has_function_privilege(
       'anon',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: anon payment record EXECUTE detected';
  END IF;

  v_fn :=
    to_regprocedure(
      'public.reverse_booking_payment(uuid,text)'
    );

  IF v_fn IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: reverse_booking_payment() missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid = v_fn::oid
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: reverse_booking_payment() must be SECURITY DEFINER';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: authenticated payment reversal EXECUTE missing';
  END IF;

  IF has_function_privilege(
       'anon',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: anon payment reversal EXECUTE detected';
  END IF;

  v_fn :=
    to_regprocedure(
      'public.get_booking_payment_summary(uuid)'
    );

  IF v_fn IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: get_booking_payment_summary() missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid = v_fn::oid
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: payment summary must be SECURITY DEFINER';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: authenticated payment summary EXECUTE missing';
  END IF;

  IF has_function_privilege(
       'anon',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 1B failed: anon payment summary EXECUTE detected';
  END IF;
END
$s9_payment_slice1b_assertions$;

-- SPRINT_9_SLICE_1B_END
