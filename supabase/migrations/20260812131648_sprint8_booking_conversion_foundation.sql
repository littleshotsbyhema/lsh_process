-- =====================================================================
-- Sprint 8 — Packages, Quotations & Booking Conversion Foundation
-- Slice 3: booking conversion + canonical journey state
-- =====================================================================

-- SLICE_3_START

-- =====================================================================
-- Section A
-- Booking conversion shell + canonical journey state/history schema
-- =====================================================================

-- ---------------------------------------------------------------------
-- Preconditions
-- ---------------------------------------------------------------------

DO $s8b_preflight$
BEGIN
  IF to_regclass('public.quotations') IS NULL
     OR to_regclass('public.quotation_line_items') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking precondition failed: quotation foundation missing';
  END IF;

  IF to_regclass('public.booking_journey_stages') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking precondition failed: canonical journey catalogue missing';
  END IF;

  IF to_regclass('public.families') IS NULL
     OR to_regclass('public.leads') IS NULL
     OR to_regclass('public.branches') IS NULL
     OR to_regclass('public.organization_members') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking precondition failed: tenancy/CRM foundation missing';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure('public.lsh_set_updated_at()') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking precondition failed: access-control helpers missing';
  END IF;

  IF to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking precondition failed: audit append RPC missing';
  END IF;

  IF to_regclass('public.bookings') IS NOT NULL
     OR to_regclass('public.booking_journey_states') IS NOT NULL
     OR to_regclass('public.booking_stage_transitions') IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking precondition failed: booking conversion tables already exist';
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
      'Sprint 8 booking precondition failed: Advance Pending stage 7 missing';
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
      'Sprint 8 booking precondition failed: Booking Confirmed stage 8 missing';
  END IF;
END
$s8b_preflight$;

-- ---------------------------------------------------------------------
-- Tenant-safe journey-stage FK anchor.
--
-- The stage UUID is globally unique already, but downstream operational
-- records also carry organization_id. The composite key ensures those
-- relationships can never cross an organization boundary.
-- ---------------------------------------------------------------------

ALTER TABLE public.booking_journey_stages
  ADD CONSTRAINT booking_journey_stages_organization_id_id_key
  UNIQUE (organization_id, id);

-- =====================================================================
-- Booking conversion shell
--
-- A booking row is created only from an accepted quotation by the
-- controlled accept_quotation() RPC added later in this slice.
--
-- There is intentionally:
--   * no payment ledger;
--   * no paid / balance / receipt / refund fields;
--   * no session date reservation;
--   * no duplicate booking-status state machine.
--
-- Canonical operational state lives in booking_journey_states.
-- =====================================================================

CREATE TABLE public.bookings (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL,
  branch_id             uuid,

  booking_reference     text NOT NULL,

  source_quotation_id   uuid NOT NULL,

  family_id             uuid,
  lead_id               uuid,

  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid NOT NULL,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid NOT NULL,

  CONSTRAINT bookings_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT bookings_branch_fkey
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

  CONSTRAINT bookings_source_quotation_fkey
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

  CONSTRAINT bookings_family_fkey
    FOREIGN KEY (
      family_id,
      organization_id
    )
    REFERENCES public.families (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT bookings_lead_fkey
    FOREIGN KEY (
      organization_id,
      lead_id
    )
    REFERENCES public.leads (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT bookings_created_by_fkey
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

  CONSTRAINT bookings_updated_by_fkey
    FOREIGN KEY (
      updated_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT bookings_reference_format_chk
    CHECK (
      booking_reference ~ '^LSH-BK-[A-F0-9]{8}$'
    ),

  CONSTRAINT bookings_subject_required_chk
    CHECK (
      family_id IS NOT NULL
      OR lead_id IS NOT NULL
    ),

  CONSTRAINT bookings_organization_reference_key
    UNIQUE (
      organization_id,
      booking_reference
    ),

  CONSTRAINT bookings_organization_source_quotation_key
    UNIQUE (
      organization_id,
      source_quotation_id
    ),

  CONSTRAINT bookings_organization_id_id_key
    UNIQUE (
      organization_id,
      id
    )
);

CREATE INDEX bookings_organization_family_idx
ON public.bookings (
  organization_id,
  family_id,
  created_at DESC
)
WHERE family_id IS NOT NULL;

CREATE INDEX bookings_organization_lead_idx
ON public.bookings (
  organization_id,
  lead_id,
  created_at DESC
)
WHERE lead_id IS NOT NULL;

CREATE INDEX bookings_organization_branch_idx
ON public.bookings (
  organization_id,
  branch_id,
  created_at DESC
)
WHERE branch_id IS NOT NULL;

-- =====================================================================
-- Exactly one current canonical journey state per booking.
-- =====================================================================

CREATE TABLE public.booking_journey_states (
  booking_id            uuid PRIMARY KEY,
  organization_id       uuid NOT NULL,

  current_stage_id      uuid NOT NULL,
  stage_entered_at      timestamptz NOT NULL DEFAULT now(),

  version               bigint NOT NULL DEFAULT 1,

  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid NOT NULL,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            uuid NOT NULL,

  CONSTRAINT booking_journey_states_booking_fkey
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

  CONSTRAINT booking_journey_states_stage_fkey
    FOREIGN KEY (
      organization_id,
      current_stage_id
    )
    REFERENCES public.booking_journey_stages (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_journey_states_created_by_fkey
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

  CONSTRAINT booking_journey_states_updated_by_fkey
    FOREIGN KEY (
      updated_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_journey_states_version_chk
    CHECK (version >= 1),

  CONSTRAINT booking_journey_states_organization_booking_key
    UNIQUE (
      organization_id,
      booking_id
    )
);

CREATE INDEX booking_journey_states_organization_stage_idx
ON public.booking_journey_states (
  organization_id,
  current_stage_id,
  stage_entered_at
);

-- =====================================================================
-- Append-only stage transition history.
--
-- Initial quotation acceptance records:
--   from_stage_id = NULL
--   to_stage_id   = Advance Pending
--   transition_key = quotation_acceptance
--
-- Subsequent journey changes append rows rather than rewriting history.
-- =====================================================================

CREATE TABLE public.booking_stage_transitions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL,
  booking_id            uuid NOT NULL,

  from_stage_id         uuid,
  to_stage_id           uuid NOT NULL,

  transition_key        text NOT NULL,

  transitioned_at       timestamptz NOT NULL DEFAULT now(),
  transitioned_by       uuid NOT NULL,

  CONSTRAINT booking_stage_transitions_booking_fkey
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

  CONSTRAINT booking_stage_transitions_from_stage_fkey
    FOREIGN KEY (
      organization_id,
      from_stage_id
    )
    REFERENCES public.booking_journey_stages (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_stage_transitions_to_stage_fkey
    FOREIGN KEY (
      organization_id,
      to_stage_id
    )
    REFERENCES public.booking_journey_stages (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_stage_transitions_actor_fkey
    FOREIGN KEY (
      transitioned_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_stage_transitions_key_format_chk
    CHECK (
      transition_key ~ '^[a-z][a-z0-9_]*$'
    ),

  CONSTRAINT booking_stage_transitions_stage_change_chk
    CHECK (
      from_stage_id IS NULL
      OR from_stage_id <> to_stage_id
    ),

  CONSTRAINT booking_stage_transitions_organization_id_id_key
    UNIQUE (
      organization_id,
      id
    )
);

-- A booking can have only one initialization transition.
CREATE UNIQUE INDEX booking_stage_transitions_one_initial_idx
ON public.booking_stage_transitions (
  organization_id,
  booking_id
)
WHERE from_stage_id IS NULL;

CREATE INDEX booking_stage_transitions_booking_history_idx
ON public.booking_stage_transitions (
  organization_id,
  booking_id,
  transitioned_at,
  id
);

CREATE INDEX booking_stage_transitions_stage_idx
ON public.booking_stage_transitions (
  organization_id,
  to_stage_id,
  transitioned_at
);

-- ---------------------------------------------------------------------
-- Standard updated-at maintenance.
-- Transition history deliberately has no update trigger because it will
-- become append-only in the next section.
-- ---------------------------------------------------------------------

CREATE TRIGGER bookings_set_updated_at
BEFORE UPDATE
ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER booking_journey_states_set_updated_at
BEFORE UPDATE
ON public.booking_journey_states
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

-- ---------------------------------------------------------------------
-- Section A structural assertions
-- ---------------------------------------------------------------------

DO $s8b_section_a_assertions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section A failed: booking conversion tables missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          'public.booking_journey_stages'::regclass
      AND c.conname =
          'booking_journey_stages_organization_id_id_key'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section A failed: tenant-safe journey-stage key missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          'public.bookings'::regclass
      AND c.conname =
          'bookings_organization_source_quotation_key'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section A failed: one-booking-per-quotation constraint missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND (
      (
        t.tgrelid = 'public.bookings'::regclass
        AND t.tgname = 'bookings_set_updated_at'
      )
      OR
      (
        t.tgrelid =
          'public.booking_journey_states'::regclass
        AND t.tgname =
          'booking_journey_states_set_updated_at'
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section A failed: expected 2 updated-at triggers, found %',
      v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'booking_stage_transitions'
      AND indexname =
          'booking_stage_transitions_one_initial_idx'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section A failed: unique initial-transition guard missing';
  END IF;
END
$s8b_section_a_assertions$;

-- SLICE_3_SECTION_A_END

-- =====================================================================
-- Section B1
-- Conversion invariants + immutable operational evidence
-- =====================================================================

-- ---------------------------------------------------------------------
-- Accepted quotations are terminal immutable commercial evidence.
--
-- accept_quotation() may perform sent -> accepted because OLD.status is
-- still sent. Once accepted, no later UPDATE or DELETE is permitted.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_accepted_quotation_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.status = 'accepted' THEN
    RAISE EXCEPTION
      'accepted quotations are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER quotations_accepted_immutable
BEFORE UPDATE OR DELETE
ON public.quotations
FOR EACH ROW
EXECUTE FUNCTION public.lsh_accepted_quotation_immutable_guard();

-- ---------------------------------------------------------------------
-- Booking conversion shell guard.
--
-- The source quotation, subject, branch and reference are historical
-- conversion identity. They cannot be rewritten or deleted in place.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_booking_shell_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
  v_current_actor uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT q.*
    INTO v_quote
    FROM public.quotations q
    WHERE q.organization_id = NEW.organization_id
      AND q.id = NEW.source_quotation_id;

    IF NOT FOUND
       OR v_quote.status <> 'accepted' THEN
      RAISE EXCEPTION
        'booking conversion requires an accepted source quotation';
    END IF;

    IF NEW.branch_id IS DISTINCT FROM v_quote.branch_id
       OR NEW.family_id IS DISTINCT FROM v_quote.family_id
       OR NEW.lead_id IS DISTINCT FROM v_quote.lead_id THEN
      RAISE EXCEPTION
        'booking conversion subject must match the accepted quotation';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      v_current_actor :=
        public.current_organization_member(
          NEW.organization_id
        );

      IF v_current_actor IS NULL
         OR NEW.created_by <> v_current_actor
         OR NEW.updated_by <> v_current_actor THEN
        RAISE EXCEPTION
          'booking conversion actor must be the current active organization member';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking conversion shells cannot be deleted';
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.branch_id IS DISTINCT FROM OLD.branch_id
     OR NEW.booking_reference IS DISTINCT FROM OLD.booking_reference
     OR NEW.source_quotation_id IS DISTINCT FROM OLD.source_quotation_id
     OR NEW.family_id IS DISTINCT FROM OLD.family_id
     OR NEW.lead_id IS DISTINCT FROM OLD.lead_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION
      'booking conversion identity is immutable';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER bookings_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_shell_guard();

-- ---------------------------------------------------------------------
-- Current journey-state guard.
--
-- Every booking begins at Advance Pending, version 1.
-- Future controlled stage movement must:
--   * change the stage;
--   * increment version by exactly one;
--   * preserve booking identity and creation evidence.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_booking_journey_state_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_stage_key text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking journey state cannot be deleted';
  END IF;

  SELECT s.stage_key
  INTO v_stage_key
  FROM public.booking_journey_stages s
  WHERE s.organization_id = NEW.organization_id
    AND s.id = NEW.current_stage_id
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking journey state requires an active canonical stage';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF v_stage_key <> 'advance_pending' THEN
      RAISE EXCEPTION
        'new bookings must initialize at Advance Pending';
    END IF;

    IF NEW.version <> 1 THEN
      RAISE EXCEPTION
        'new booking journey state must start at version 1';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      IF public.current_organization_member(
           NEW.organization_id
         ) IS DISTINCT FROM NEW.created_by
         OR NEW.updated_by IS DISTINCT FROM NEW.created_by THEN
        RAISE EXCEPTION
          'booking journey state actor must be the current active organization member';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  IF NEW.booking_id IS DISTINCT FROM OLD.booking_id
     OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION
      'booking journey state identity is immutable';
  END IF;

  IF NEW.current_stage_id IS NOT DISTINCT FROM OLD.current_stage_id THEN
    RAISE EXCEPTION
      'booking journey update must change the current stage';
  END IF;

  IF NEW.version <> OLD.version + 1 THEN
    RAISE EXCEPTION
      'booking journey version must increment by exactly one';
  END IF;

  IF NEW.stage_entered_at < OLD.stage_entered_at THEN
    RAISE EXCEPTION
      'booking journey stage_entered_at cannot move backwards';
  END IF;

  IF auth.uid() IS NOT NULL
     AND public.current_organization_member(
           NEW.organization_id
         ) IS DISTINCT FROM NEW.updated_by THEN
    RAISE EXCEPTION
      'booking journey update actor must be the current active organization member';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_journey_states_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_journey_states
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_journey_state_guard();

-- ---------------------------------------------------------------------
-- Stage transition history is append-only.
--
-- The only valid initialization transition is:
--   NULL -> Advance Pending
--   transition_key = quotation_acceptance
--
-- Subsequent non-initial transitions are permitted structurally here;
-- later controlled stage RPCs remain responsible for authorization and
-- legal transition semantics.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_booking_stage_transition_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_to_stage_key text;
  v_current_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking stage transition history is append-only';
  END IF;

  SELECT s.stage_key
  INTO v_to_stage_key
  FROM public.booking_journey_stages s
  WHERE s.organization_id = NEW.organization_id
    AND s.id = NEW.to_stage_id
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking transition requires an active destination stage';
  END IF;

  IF NEW.from_stage_id IS NULL THEN
    IF v_to_stage_key <> 'advance_pending'
       OR NEW.transition_key <> 'quotation_acceptance' THEN
      RAISE EXCEPTION
        'initial booking transition must be quotation_acceptance to Advance Pending';
    END IF;
  END IF;

  -- When an authenticated actor exists, transition evidence must name
  -- that same active organization member.
  IF auth.uid() IS NOT NULL THEN
    v_current_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_current_actor IS NULL
       OR NEW.transitioned_by <> v_current_actor THEN
      RAISE EXCEPTION
        'booking transition actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_stage_transitions_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_stage_transitions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_stage_transition_guard();

-- ---------------------------------------------------------------------
-- Section B1 assertions
-- ---------------------------------------------------------------------

DO $s8b_section_b1_assertions$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND (
      (
        t.tgrelid = 'public.quotations'::regclass
        AND t.tgname =
            'quotations_accepted_immutable'
      )
      OR
      (
        t.tgrelid = 'public.bookings'::regclass
        AND t.tgname =
            'bookings_guard'
      )
      OR
      (
        t.tgrelid =
          'public.booking_journey_states'::regclass
        AND t.tgname =
            'booking_journey_states_guard'
      )
      OR
      (
        t.tgrelid =
          'public.booking_stage_transitions'::regclass
        AND t.tgname =
            'booking_stage_transitions_guard'
      )
    );

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section B1 failed: expected 4 invariant guards, found %',
      v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    WHERE t.tgrelid =
          'public.quotations'::regclass
      AND t.tgname =
          'quotations_accepted_immutable'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section B1 failed: accepted quotation immutability missing';
  END IF;
END
$s8b_section_b1_assertions$;

-- SLICE_3_SECTION_B1_END

-- =====================================================================
-- Section B2
-- Atomic + idempotent quotation acceptance
-- =====================================================================

CREATE OR REPLACE FUNCTION public.accept_quotation(
  p_quotation_id uuid
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
  v_existing_booking public.bookings;
  v_booking public.bookings;

  v_actor uuid;
  v_advance_stage_id uuid;

  v_booking_id uuid;
  v_booking_reference text;
  v_attempt integer := 0;

  v_state_count integer;
  v_initial_transition_count integer;
BEGIN
  IF p_quotation_id IS NULL THEN
    RAISE EXCEPTION
      'accept_quotation: quotation_id is required'
      USING ERRCODE = '22023';
  END IF;

  -- Serialize every acceptance attempt for the same quotation.
  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.id = p_quotation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'accept_quotation: quotation not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_quote.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'accept_quotation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  -- Conversion belongs to the quote-authoring capability.
  -- It does not grant generic booking.write or booking.stage.advance.
  IF NOT public.has_permission(
    v_quote.organization_id,
    'quote.write',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'accept_quotation: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_quote.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_quote.organization_id,
       v_quote.branch_id
     ) THEN
    RAISE EXCEPTION
      'accept_quotation: no access to quotation branch'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Idempotent replay.
  --
  -- An accepted quotation must already have exactly one fully
  -- initialized booking. We never create a second booking and never
  -- rewrite the accepted quotation.
  -- ---------------------------------------------------------------

  IF v_quote.status = 'accepted' THEN
    SELECT b.*
    INTO v_existing_booking
    FROM public.bookings b
    WHERE b.organization_id =
          v_quote.organization_id
      AND b.source_quotation_id =
          v_quote.id;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'accept_quotation: accepted quotation is missing its booking conversion'
        USING ERRCODE = 'P0001';
    END IF;

    -- The booking subject must still match the accepted quotation.
    IF v_existing_booking.branch_id IS DISTINCT FROM v_quote.branch_id
       OR v_existing_booking.family_id IS DISTINCT FROM v_quote.family_id
       OR v_existing_booking.lead_id IS DISTINCT FROM v_quote.lead_id THEN
      RAISE EXCEPTION
        'accept_quotation: accepted booking subject does not match quotation'
        USING ERRCODE = 'P0001';
    END IF;

    -- Current journey state may legitimately have advanced beyond
    -- Advance Pending. Idempotent acceptance therefore verifies only
    -- that the booking still has exactly one current-state row.
    SELECT count(*)
    INTO v_state_count
    FROM public.booking_journey_states js
    WHERE js.organization_id =
          v_existing_booking.organization_id
      AND js.booking_id =
          v_existing_booking.id;

    IF v_state_count <> 1 THEN
      RAISE EXCEPTION
        'accept_quotation: accepted booking is missing its current journey state'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*)
    INTO v_initial_transition_count
    FROM public.booking_stage_transitions t
    JOIN public.booking_journey_stages s
      ON s.organization_id = t.organization_id
     AND s.id = t.to_stage_id
    WHERE t.organization_id =
          v_existing_booking.organization_id
      AND t.booking_id =
          v_existing_booking.id
      AND t.from_stage_id IS NULL
      AND t.transition_key =
          'quotation_acceptance'
      AND s.stage_key =
          'advance_pending';

    IF v_initial_transition_count <> 1 THEN
      RAISE EXCEPTION
        'accept_quotation: accepted booking has invalid initial transition evidence'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing_booking;
  END IF;

  IF v_quote.status <> 'sent' THEN
    RAISE EXCEPTION
      'accept_quotation: only sent quotations can be accepted'
      USING ERRCODE = '22023';
  END IF;

  -- A quote that has reached its explicit expiry time cannot be
  -- accepted merely because nobody has yet run the expired transition.
  IF v_quote.expires_at IS NOT NULL
     AND v_quote.expires_at <= now() THEN
    RAISE EXCEPTION
      'accept_quotation: quotation has expired'
      USING ERRCODE = '22023';
  END IF;

  -- Conversion requires a meaningful frozen commercial snapshot.
  IF v_quote.quoted_total_inr <= 0 THEN
    RAISE EXCEPTION
      'accept_quotation: quotation total must be greater than zero'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.quotation_line_items li
    WHERE li.organization_id =
          v_quote.organization_id
      AND li.quotation_id =
          v_quote.id
      AND li.line_type =
          'package'
  ) THEN
    RAISE EXCEPTION
      'accept_quotation: quotation requires a package line'
      USING ERRCODE = '22023';
  END IF;

  SELECT s.id
  INTO v_advance_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_quote.organization_id
    AND s.stage_key =
        'advance_pending'
    AND s.stage_order = 7
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'accept_quotation: active Advance Pending stage 7 is unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- Defensive consistency check. Under the serialized quotation lock,
  -- a valid sent quotation must not already have a booking.
  IF EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          v_quote.organization_id
      AND b.source_quotation_id =
          v_quote.id
  ) THEN
    RAISE EXCEPTION
      'accept_quotation: sent quotation already has a booking conversion'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- 1. Freeze quotation as accepted.
  --
  -- The booking INSERT guard requires the source quotation to be
  -- accepted, so acceptance is deliberately performed first inside
  -- this same transaction.
  -- ---------------------------------------------------------------

  UPDATE public.quotations q
  SET
    status = 'accepted',
    accepted_at = now(),
    updated_by = v_actor
  WHERE q.organization_id =
        v_quote.organization_id
    AND q.id =
        v_quote.id
  RETURNING *
  INTO v_quote;

  -- ---------------------------------------------------------------
  -- 2. Create exactly one booking shell.
  -- ---------------------------------------------------------------

  LOOP
    v_attempt := v_attempt + 1;

    v_booking_id := gen_random_uuid();

    v_booking_reference :=
      'LSH-BK-' ||
      upper(
        substr(
          replace(v_booking_id::text, '-', ''),
          1,
          8
        )
      );

    BEGIN
      INSERT INTO public.bookings (
        id,
        organization_id,
        branch_id,
        booking_reference,
        source_quotation_id,
        family_id,
        lead_id,
        created_by,
        updated_by
      )
      VALUES (
        v_booking_id,
        v_quote.organization_id,
        v_quote.branch_id,
        v_booking_reference,
        v_quote.id,
        v_quote.family_id,
        v_quote.lead_id,
        v_actor,
        v_actor
      )
      RETURNING *
      INTO v_booking;

      EXIT;

    EXCEPTION
      WHEN unique_violation THEN
        -- Only the randomized booking-reference collision is retryable.
        -- A source-quotation collision is an integrity failure.
        IF EXISTS (
          SELECT 1
          FROM public.bookings b
          WHERE b.organization_id =
                v_quote.organization_id
            AND b.source_quotation_id =
                v_quote.id
        ) THEN
          RAISE EXCEPTION
            'accept_quotation: quotation already has a booking conversion'
            USING ERRCODE = 'P0001';
        END IF;

        IF v_attempt >= 5 THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  -- ---------------------------------------------------------------
  -- 3. Initialize the one current journey state at Advance Pending.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_journey_states (
    booking_id,
    organization_id,
    current_stage_id,
    stage_entered_at,
    version,
    created_by,
    updated_by
  )
  VALUES (
    v_booking.id,
    v_booking.organization_id,
    v_advance_stage_id,
    now(),
    1,
    v_actor,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- 4. Append initial journey-transition evidence.
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
    NULL,
    v_advance_stage_id,
    'quotation_acceptance',
    now(),
    v_actor
  );

  -- ---------------------------------------------------------------
  -- 5. Audit commercial acceptance and booking conversion.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.status_changed',
    'quotation',
    v_quote.id,
    true,
    jsonb_build_object(
      'status',
        'sent'
    ),
    jsonb_build_object(
      'status',
        'accepted'
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'booking_reference',
        v_booking.booking_reference,
      'journey_stage',
        'advance_pending'
    ),
    'commercial',
    NULL
  );

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.created_from_quotation',
    'booking',
    v_booking.id,
    true,
    NULL,
    jsonb_build_object(
      'booking_reference',
        v_booking.booking_reference,
      'source_quotation_id',
        v_booking.source_quotation_id,
      'journey_stage',
        'advance_pending'
    ),
    jsonb_build_object(
      'conversion_source',
        'quotation_acceptance'
    ),
    'commercial',
    NULL
  );

  RETURN v_booking;
END
$$;

-- ---------------------------------------------------------------------
-- Section B2 assertions
-- ---------------------------------------------------------------------

DO $s8b_section_b2_assertions$
BEGIN
  IF to_regprocedure(
       'public.accept_quotation(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section B2 failed: accept_quotation() missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'accept_quotation'
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section B2 failed: accept_quotation() must be SECURITY DEFINER';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          'public.bookings'::regclass
      AND c.conname =
          'bookings_organization_source_quotation_key'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking Section B2 failed: booking idempotency constraint missing';
  END IF;
END
$s8b_section_b2_assertions$;

-- SLICE_3_SECTION_B2_END

-- =====================================================================
-- Section C
-- RLS + least privilege + RPC ACL + final booking-conversion gates
-- =====================================================================

ALTER TABLE public.bookings
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.booking_journey_states
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_journey_states
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.booking_stage_transitions
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_stage_transitions
  FORCE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- Authenticated reads
--
-- booking.read is the canonical visibility capability.
-- Branch-scoped grants remain enforced through has_permission().
-- Mutation is RPC-only.
-- ---------------------------------------------------------------------

CREATE POLICY bookings_staff_read
ON public.bookings
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'booking.read',
    branch_id
  )
);

CREATE POLICY booking_journey_states_staff_read
ON public.booking_journey_states
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          booking_journey_states.organization_id
      AND b.id =
          booking_journey_states.booking_id
      AND public.has_permission(
        b.organization_id,
        'booking.read',
        b.branch_id
      )
  )
);

CREATE POLICY booking_stage_transitions_staff_read
ON public.booking_stage_transitions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.organization_id =
          booking_stage_transitions.organization_id
      AND b.id =
          booking_stage_transitions.booking_id
      AND public.has_permission(
        b.organization_id,
        'booking.read',
        b.branch_id
      )
  )
);

-- ---------------------------------------------------------------------
-- Table ACL
--
-- Authenticated staff may SELECT according to RLS.
-- They may not directly INSERT / UPDATE / DELETE operational booking
-- state. Controlled SECURITY DEFINER RPCs own those mutations.
-- ---------------------------------------------------------------------

REVOKE ALL PRIVILEGES
ON TABLE
  public.bookings,
  public.booking_journey_states,
  public.booking_stage_transitions
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE
  public.bookings,
  public.booking_journey_states,
  public.booking_stage_transitions
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE
  public.bookings,
  public.booking_journey_states,
  public.booking_stage_transitions
TO service_role;

-- ---------------------------------------------------------------------
-- accept_quotation() ACL
--
-- Authentication exposes the narrow conversion capability.
-- Authorization still occurs inside the RPC through quote.write.
-- Anonymous callers receive no execution privilege.
-- ---------------------------------------------------------------------

REVOKE ALL
ON FUNCTION public.accept_quotation(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.accept_quotation(uuid)
TO authenticated;

-- ---------------------------------------------------------------------
-- Internal guard/helper hardening
-- ---------------------------------------------------------------------

REVOKE ALL
ON FUNCTION public.lsh_accepted_quotation_immutable_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_booking_shell_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_booking_journey_state_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_booking_stage_transition_guard()
FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- Final Slice 3 migration gates
-- ---------------------------------------------------------------------

DO $s8b_final_assertions$
DECLARE
  v_count integer;
  v_fn regprocedure;
BEGIN
  -- ---------------------------------------------------------------
  -- Tables
  -- ---------------------------------------------------------------

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: booking conversion tables missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical stage invariants
  -- ---------------------------------------------------------------

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
      'Sprint 8 booking final gate failed: Advance Pending stage 7 unavailable';
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
      'Sprint 8 booking final gate failed: Booking Confirmed stage 8 unavailable';
  END IF;

  -- ---------------------------------------------------------------
  -- RLS + FORCE RLS
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
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
    AND c.relforcerowsecurity;

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: booking RLS hardening incomplete';
  END IF;

  -- Exactly the three intended read policies.
  SELECT count(*)
  INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND (
      (
        tablename = 'bookings'
        AND policyname = 'bookings_staff_read'
      )
      OR
      (
        tablename = 'booking_journey_states'
        AND policyname =
            'booking_journey_states_staff_read'
      )
      OR
      (
        tablename = 'booking_stage_transitions'
        AND policyname =
            'booking_stage_transitions_staff_read'
      )
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: expected 3 booking read policies, found %',
      v_count;
  END IF;

  -- ---------------------------------------------------------------
  -- Authenticated direct-write denial
  -- ---------------------------------------------------------------

  IF NOT has_table_privilege(
       'authenticated',
       'public.bookings',
       'SELECT'
     )
     OR NOT has_table_privilege(
       'authenticated',
       'public.booking_journey_states',
       'SELECT'
     )
     OR NOT has_table_privilege(
       'authenticated',
       'public.booking_stage_transitions',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: authenticated booking SELECT privilege missing';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.bookings',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.bookings',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.bookings',
       'DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_journey_states',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_journey_states',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_journey_states',
       'DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_stage_transitions',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_stage_transitions',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_stage_transitions',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: authenticated direct booking write privilege detected';
  END IF;

  -- Anonymous users may not inspect booking operations.
  IF has_table_privilege(
       'anon',
       'public.bookings',
       'SELECT'
     )
     OR has_table_privilege(
       'anon',
       'public.booking_journey_states',
       'SELECT'
     )
     OR has_table_privilege(
       'anon',
       'public.booking_stage_transitions',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: anon booking access detected';
  END IF;

  -- ---------------------------------------------------------------
  -- Acceptance RPC
  -- ---------------------------------------------------------------

  v_fn :=
    to_regprocedure(
      'public.accept_quotation(uuid)'
    );

  IF v_fn IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: accept_quotation() missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid = v_fn::oid
      AND p.prosecdef
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: accept_quotation() is not SECURITY DEFINER';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: authenticated accept_quotation EXECUTE missing';
  END IF;

  IF has_function_privilege(
       'anon',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: anon accept_quotation EXECUTE detected';
  END IF;

  -- ---------------------------------------------------------------
  -- Idempotency / immutable history structural evidence
  -- ---------------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          'public.bookings'::regclass
      AND c.conname =
          'bookings_organization_source_quotation_key'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: one-booking-per-quotation constraint missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes i
    WHERE i.schemaname = 'public'
      AND i.tablename =
          'booking_stage_transitions'
      AND i.indexname =
          'booking_stage_transitions_one_initial_idx'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: one-initial-transition constraint missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND (
      (
        t.tgrelid = 'public.quotations'::regclass
        AND t.tgname =
            'quotations_accepted_immutable'
      )
      OR
      (
        t.tgrelid = 'public.bookings'::regclass
        AND t.tgname =
            'bookings_guard'
      )
      OR
      (
        t.tgrelid =
          'public.booking_journey_states'::regclass
        AND t.tgname =
            'booking_journey_states_guard'
      )
      OR
      (
        t.tgrelid =
          'public.booking_stage_transitions'::regclass
        AND t.tgname =
            'booking_stage_transitions_guard'
      )
    );

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: invariant trigger set incomplete';
  END IF;

  -- Internal booking guard functions must not be browser-callable.
  v_fn :=
    to_regprocedure(
      'public.lsh_booking_shell_guard()'
    );

  IF has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 booking final gate failed: internal booking guard exposed';
  END IF;
END
$s8b_final_assertions$;

-- SLICE_3_SECTION_C_END




-- SLICE_3_END
