-- =====================================================================
-- Heirloom Pipeline 1 of 4 - Album / Frame Production
-- Production evidence + Stage 17 -> 18 gate
--
-- Boundary:
--   * one narrow production.manage permission;
--   * append-only production item list, proof rounds, proof responses and
--     production milestones;
--   * controlled record RPCs for each;
--   * controlled mark_booking_album_frame_production(uuid) RPC;
--   * exact Stage 17 -> 18 advancement only;
--   * no Stage 18 -> 19 implementation;
--   * no review, milestone follow-up or completion.
--
-- Studio process this encodes (confirmed by the studio owner):
--   Every package includes at least one printed frame, so production applies
--   to every booking. Album layouts are ALWAYS proofed to the family before
--   printing. Production is a mix of external vendors and in-house work, so
--   vendor_name is optional and NULL means in-house. Finished items are
--   collected by the family from the studio.
--
-- Ordering enforced by the RPCs:
--   items -> proof sent -> family response -> (repeat while changes are
--   requested) -> dispatched -> received -> handed over.
-- =====================================================================

-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $hp1_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_production_items') IS NOT NULL
     OR to_regclass('public.booking_production_proofs') IS NOT NULL
     OR to_regclass('public.booking_production_proof_responses') IS NOT NULL
     OR to_regclass('public.booking_production_milestones') IS NOT NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 precondition failed: production relation already exists';
  END IF;

  IF EXISTS (SELECT 1 FROM public.permissions WHERE key = 'production.manage') THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 precondition failed: production.manage permission already exists';
  END IF;

  IF to_regclass('public.booking_delivery_confirmations') IS NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 precondition failed: delivery foundation unavailable';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure(
          'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
        ) IS NULL
     OR to_regprocedure('public.mark_booking_delivered(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.booking_journey_stages
  WHERE stage_order IN (17, 18)
    AND stage_key IN ('delivered', 'album_frame_production')
    AND is_active;

  IF v_count < 2 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 precondition failed: canonical production stages unavailable';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.roles
  WHERE key IN ('founder', 'studio_manager', 'album_coordinator');

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 precondition failed: canonical roles unavailable';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 272 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 precondition failed: expected canonical role-permission count 272, found %',
      v_count;
  END IF;
END
$hp1_preconditions$;

-- =====================================================================
-- Section B - Permission
-- =====================================================================

INSERT INTO public.permissions (
  key, domain, label, description, requires_server_enforcement
)
VALUES (
  'production.manage',
  'bookings',
  'Manage album and frame production',
  'Record production items, client proof rounds, vendor dispatch, receipt and studio handover for a booking.',
  true
);

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN ('founder', 'studio_manager', 'album_coordinator')
  AND permission.key = 'production.manage';

-- =====================================================================
-- Section C - Production items
-- =====================================================================

CREATE TABLE public.booking_production_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  item_ordinal integer NOT NULL,
  item_type text NOT NULL,
  description text NOT NULL,
  quantity integer NOT NULL,
  vendor_name text,

  recorded_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_production_items_ordinal_chk
    CHECK (item_ordinal >= 1 AND item_ordinal <= 100),

  CONSTRAINT booking_production_items_item_type_chk
    CHECK (item_type IN ('album', 'frame', 'other')),

  CONSTRAINT booking_production_items_quantity_chk
    CHECK (quantity >= 1 AND quantity <= 100),

  CONSTRAINT booking_production_items_description_chk
    CHECK (
      description = btrim(description)
      AND description <> ''
      AND btrim(
        description,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND description = btrim(description, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(description) <= 300
      AND description !~ '[[:cntrl:]]'
      AND description !~* '^(bearer|basic)[[:space:]]+'
      AND description !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND description !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
    ),

  CONSTRAINT booking_production_items_vendor_name_chk
    CHECK (
      vendor_name IS NULL
      OR (
      vendor_name = btrim(vendor_name)
      AND vendor_name <> ''
      AND btrim(
        vendor_name,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND vendor_name = btrim(vendor_name, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(vendor_name) <= 160
      AND vendor_name !~ '[[:cntrl:]]'
      AND vendor_name !~* '^(bearer|basic)[[:space:]]+'
      AND vendor_name !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND vendor_name !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_production_items_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_items_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_items_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_items_org_booking_ordinal_key
    UNIQUE (organization_id, booking_id, item_ordinal)
);

CREATE INDEX booking_production_items_booking_idx
ON public.booking_production_items (booking_id, item_ordinal);

CREATE FUNCTION public.lsh_booking_production_item_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking production items evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking production items evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking production items recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking production items actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_production_items_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_production_items
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_production_item_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_production_item_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_production_item_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_production_item_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_production_item_guard() FROM service_role;

ALTER TABLE public.booking_production_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_production_items FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_production_items FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_items FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_items FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_items FROM service_role;

GRANT SELECT ON TABLE public.booking_production_items TO authenticated;

CREATE POLICY booking_production_items_authenticated_select
ON public.booking_production_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_production_items.organization_id
      AND booking.id = booking_production_items.booking_id
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
-- Section D - Client proof rounds
-- =====================================================================

CREATE TABLE public.booking_production_proofs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  round integer NOT NULL,
  proof_reference text NOT NULL,
  proof_note text,

  sent_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_production_proofs_round_chk
    CHECK (round >= 1 AND round <= 50),

  CONSTRAINT booking_production_proofs_proof_reference_chk
    CHECK (
      proof_reference = btrim(proof_reference)
      AND proof_reference <> ''
      AND btrim(
        proof_reference,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND proof_reference = btrim(proof_reference, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(proof_reference) <= 500
      AND proof_reference !~ '[[:cntrl:]]'
      AND proof_reference !~* '^(bearer|basic)[[:space:]]+'
      AND proof_reference !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND proof_reference !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
    ),

  CONSTRAINT booking_production_proofs_proof_note_chk
    CHECK (
      proof_note IS NULL
      OR (
      proof_note = btrim(proof_note)
      AND proof_note <> ''
      AND btrim(
        proof_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND proof_note = btrim(proof_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(proof_note) <= 500
      AND proof_note !~ '[[:cntrl:]]'
      AND proof_note !~* '^(bearer|basic)[[:space:]]+'
      AND proof_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND proof_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_production_proofs_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_proofs_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_proofs_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_proofs_org_booking_round_key
    UNIQUE (organization_id, booking_id, round),

  CONSTRAINT booking_production_proofs_id_booking_key
    UNIQUE (id, booking_id)
);

CREATE INDEX booking_production_proofs_booking_round_idx
ON public.booking_production_proofs (booking_id, round DESC);

CREATE FUNCTION public.lsh_booking_production_proof_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking production proofs evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking production proofs evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking production proofs recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking production proofs actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_production_proofs_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_production_proofs
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_production_proof_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_guard() FROM service_role;

ALTER TABLE public.booking_production_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_production_proofs FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proofs FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proofs FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proofs FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proofs FROM service_role;

GRANT SELECT ON TABLE public.booking_production_proofs TO authenticated;

CREATE POLICY booking_production_proofs_authenticated_select
ON public.booking_production_proofs
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_production_proofs.organization_id
      AND booking.id = booking_production_proofs.booking_id
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
-- Section E - Client proof responses
-- =====================================================================

CREATE TABLE public.booking_production_proof_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  proof_id uuid NOT NULL,

  round integer NOT NULL,
  outcome text NOT NULL,
  response_note text,

  responded_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_production_proof_responses_round_chk
    CHECK (round >= 1 AND round <= 50),

  CONSTRAINT booking_production_proof_responses_outcome_chk
    CHECK (outcome IN ('approved', 'changes_requested')),

  CONSTRAINT booking_production_proof_responses_changes_note_chk
    CHECK (outcome <> 'changes_requested' OR response_note IS NOT NULL),

  CONSTRAINT booking_production_proof_responses_response_note_chk
    CHECK (
      response_note IS NULL
      OR (
      response_note = btrim(response_note)
      AND response_note <> ''
      AND btrim(
        response_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND response_note = btrim(response_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(response_note) <= 1000
      AND response_note !~ '[[:cntrl:]]'
      AND response_note !~* '^(bearer|basic)[[:space:]]+'
      AND response_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND response_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_production_proof_responses_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_proof_responses_proof_fkey
    FOREIGN KEY (proof_id, booking_id)
    REFERENCES public.booking_production_proofs (id, booking_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_proof_responses_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_proof_responses_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_proof_responses_proof_key
    UNIQUE (proof_id)
);

CREATE INDEX booking_production_proof_responses_booking_round_idx
ON public.booking_production_proof_responses (booking_id, round DESC);

CREATE FUNCTION public.lsh_booking_production_proof_response_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking production proof responses evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking production proof responses evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking production proof responses recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking production proof responses actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_production_proof_responses_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_production_proof_responses
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_production_proof_response_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_response_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_response_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_response_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_production_proof_response_guard() FROM service_role;

ALTER TABLE public.booking_production_proof_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_production_proof_responses FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proof_responses FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proof_responses FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proof_responses FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_proof_responses FROM service_role;

GRANT SELECT ON TABLE public.booking_production_proof_responses TO authenticated;

CREATE POLICY booking_production_proof_responses_authenticated_select
ON public.booking_production_proof_responses
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_production_proof_responses.organization_id
      AND booking.id = booking_production_proof_responses.booking_id
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
-- Section F - Production milestones
-- =====================================================================

CREATE TABLE public.booking_production_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  milestone_type text NOT NULL,
  vendor_name text,
  expected_at timestamptz,
  detail_note text,
  collected_by_name text,

  occurred_at timestamptz NOT NULL,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_production_milestones_type_chk
    CHECK (milestone_type IN ('dispatched', 'received', 'handed_over')),

  CONSTRAINT booking_production_milestones_vendor_scope_chk
    CHECK (milestone_type = 'dispatched' OR vendor_name IS NULL),

  CONSTRAINT booking_production_milestones_expected_scope_chk
    CHECK (milestone_type = 'dispatched' OR expected_at IS NULL),

  CONSTRAINT booking_production_milestones_collected_scope_chk
    CHECK (
      (milestone_type = 'handed_over' AND collected_by_name IS NOT NULL)
      OR
      (milestone_type <> 'handed_over' AND collected_by_name IS NULL)
    ),

  CONSTRAINT booking_production_milestones_vendor_name_chk
    CHECK (
      vendor_name IS NULL
      OR (
      vendor_name = btrim(vendor_name)
      AND vendor_name <> ''
      AND btrim(
        vendor_name,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND vendor_name = btrim(vendor_name, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(vendor_name) <= 160
      AND vendor_name !~ '[[:cntrl:]]'
      AND vendor_name !~* '^(bearer|basic)[[:space:]]+'
      AND vendor_name !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND vendor_name !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_production_milestones_detail_note_chk
    CHECK (
      detail_note IS NULL
      OR (
      detail_note = btrim(detail_note)
      AND detail_note <> ''
      AND btrim(
        detail_note,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND detail_note = btrim(detail_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(detail_note) <= 500
      AND detail_note !~ '[[:cntrl:]]'
      AND detail_note !~* '^(bearer|basic)[[:space:]]+'
      AND detail_note !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND detail_note !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_production_milestones_collected_by_name_chk
    CHECK (
      collected_by_name IS NULL
      OR (
      collected_by_name = btrim(collected_by_name)
      AND collected_by_name <> ''
      AND btrim(
        collected_by_name,
        U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000'
      ) <> ''
      AND collected_by_name = btrim(collected_by_name, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
      AND char_length(collected_by_name) <= 160
      AND collected_by_name !~ '[[:cntrl:]]'
      AND collected_by_name !~* '^(bearer|basic)[[:space:]]+'
      AND collected_by_name !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND collected_by_name !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_production_milestones_booking_fkey
    FOREIGN KEY (organization_id, booking_id)
    REFERENCES public.bookings (organization_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_milestones_recorded_by_fkey
    FOREIGN KEY (recorded_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_milestones_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT booking_production_milestones_org_booking_type_key
    UNIQUE (organization_id, booking_id, milestone_type)
);

CREATE INDEX booking_production_milestones_booking_occurred_idx
ON public.booking_production_milestones (booking_id, occurred_at DESC);

CREATE FUNCTION public.lsh_booking_production_milestone_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $guard$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking production milestones evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking production milestones evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking production milestones recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor := public.current_organization_member(NEW.organization_id);

    IF v_actor IS NULL OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking production milestones actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

CREATE TRIGGER booking_production_milestones_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_production_milestones
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_production_milestone_guard();

REVOKE ALL ON FUNCTION public.lsh_booking_production_milestone_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lsh_booking_production_milestone_guard() FROM anon;
REVOKE ALL ON FUNCTION public.lsh_booking_production_milestone_guard() FROM authenticated;
REVOKE ALL ON FUNCTION public.lsh_booking_production_milestone_guard() FROM service_role;

ALTER TABLE public.booking_production_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_production_milestones FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.booking_production_milestones FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_milestones FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_milestones FROM authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.booking_production_milestones FROM service_role;

GRANT SELECT ON TABLE public.booking_production_milestones TO authenticated;

CREATE POLICY booking_production_milestones_authenticated_select
ON public.booking_production_milestones
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id = booking_production_milestones.organization_id
      AND booking.id = booking_production_milestones.booking_id
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
-- Section G - Production item RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_production_item(
  p_booking_id uuid,
  p_item_type text,
  p_description text,
  p_quantity integer DEFAULT 1,
  p_vendor_name text DEFAULT NULL
)
RETURNS public.booking_production_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_production_item$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_item_type text;
  v_description text;
  v_vendor text;
  v_ordinal integer;
  v_result public.booking_production_items;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_production_item: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'production.manage', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_production_item: production.manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_production_item: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_item_type IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: item type is required' USING ERRCODE = '22023';
  END IF;

  v_item_type := btrim(p_item_type);

  IF v_item_type = ''
     OR btrim(v_item_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_item_type <> btrim(v_item_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_item_type) > 16
     OR v_item_type ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_production_item: item type is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_item_type NOT IN ('album', 'frame', 'other') THEN
    RAISE EXCEPTION 'record_booking_production_item: item type must be album, frame or other'
      USING ERRCODE = '22023';
  END IF;

  IF p_description IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: description is required' USING ERRCODE = '22023';
  END IF;

  v_description := btrim(p_description);

  IF v_description = ''
     OR btrim(v_description, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_description <> btrim(v_description, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_description) > 300
     OR v_description ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_production_item: description is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_description IS NOT NULL
     AND (
       v_description ~* '^(bearer|basic)[[:space:]]+'
       OR v_description ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_description ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_item: description must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  v_vendor := NULLIF(btrim(COALESCE(p_vendor_name, '')), '');

  IF v_vendor IS NOT NULL
     AND (
       btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_vendor <> btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_vendor) > 160
       OR v_vendor ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_vendor := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_item: vendor name is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_vendor IS NOT NULL
     AND (
       v_vendor ~* '^(bearer|basic)[[:space:]]+'
       OR v_vendor ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_vendor ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_item: vendor name must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 100 THEN
    RAISE EXCEPTION 'record_booking_production_item: quantity is out of range'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_production_item: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_production_item: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_item: booking must be exactly Album / Frame Production'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.booking_production_milestones milestone
    WHERE milestone.organization_id = v_booking.organization_id
      AND milestone.booking_id = v_booking.id
      AND milestone.milestone_type = 'dispatched'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_item: production has already been dispatched for this booking'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(max(item.item_ordinal), 0) + 1 INTO v_ordinal
  FROM public.booking_production_items item
  WHERE item.organization_id = v_booking.organization_id
    AND item.booking_id = v_booking.id;

  IF v_ordinal > 100 THEN
    RAISE EXCEPTION 'record_booking_production_item: production item limit reached'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_production_items (
    organization_id, booking_id, item_ordinal, item_type, description,
    quantity, vendor_name, recorded_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_ordinal, v_item_type, v_description,
    p_quantity, v_vendor, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.production_item_recorded', 'booking', v_booking.id, false,
    NULL,
    jsonb_build_object('item_ordinal', v_ordinal, 'item_type', v_item_type),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'production_item_id', v_result.id,
      'item_ordinal', v_ordinal,
      'item_type', v_item_type,
      'quantity', p_quantity,
      'in_house', (v_vendor IS NULL)
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_production_item$;

REVOKE ALL ON FUNCTION public.record_booking_production_item(uuid,text,text,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_production_item(uuid,text,text,integer,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_production_item(uuid,text,text,integer,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_production_item(uuid,text,text,integer,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_production_item(uuid,text,text,integer,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_production_item(uuid,text,text,integer,text) IS
  'Records one album, frame or other item to be produced for a booking. NULL vendor_name means the item is produced in-house. Cannot be called once production has been dispatched.';

-- =====================================================================
-- Section H - Client proof RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_production_proof(
  p_booking_id uuid,
  p_proof_reference text,
  p_note text DEFAULT NULL
)
RETURNS public.booking_production_proofs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_production_proof$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_reference text;
  v_note text;
  v_item_count integer;
  v_proof_count integer;
  v_response_count integer;
  v_round integer;
  v_result public.booking_production_proofs;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_proof: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_proof: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_production_proof: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_proof: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'production.manage', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_production_proof: production.manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_production_proof: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_proof_reference IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_proof: proof reference is required' USING ERRCODE = '22023';
  END IF;

  v_reference := btrim(p_proof_reference);

  IF v_reference = ''
     OR btrim(v_reference, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_reference <> btrim(v_reference, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_reference) > 500
     OR v_reference ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_production_proof: proof reference is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_reference IS NOT NULL
     AND (
       v_reference ~* '^(bearer|basic)[[:space:]]+'
       OR v_reference ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_reference ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_proof: proof reference must not contain credential material'
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
      RAISE EXCEPTION 'record_booking_production_proof: proof note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_proof: proof note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_production_proof: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_production_proof: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_proof: booking must be exactly Album / Frame Production'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_item_count
  FROM public.booking_production_items item
  WHERE item.organization_id = v_booking.organization_id
    AND item.booking_id = v_booking.id;

  IF v_item_count < 1 THEN
    RAISE EXCEPTION
      'record_booking_production_proof: record the production items before sending a proof'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_proof_count
  FROM public.booking_production_proofs proof
  WHERE proof.organization_id = v_booking.organization_id
    AND proof.booking_id = v_booking.id;

  SELECT count(*) INTO v_response_count
  FROM public.booking_production_proof_responses response
  WHERE response.organization_id = v_booking.organization_id
    AND response.booking_id = v_booking.id;

  IF v_proof_count > v_response_count THEN
    RAISE EXCEPTION
      'record_booking_production_proof: the previous proof is still awaiting a client response'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.booking_production_proof_responses response
    WHERE response.organization_id = v_booking.organization_id
      AND response.booking_id = v_booking.id
      AND response.outcome = 'approved'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_proof: this booking already has an approved proof'
      USING ERRCODE = '22023';
  END IF;

  v_round := v_proof_count + 1;

  IF v_round > 50 THEN
    RAISE EXCEPTION 'record_booking_production_proof: proof round limit reached'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_production_proofs (
    organization_id, booking_id, round, proof_reference, proof_note,
    sent_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_round, v_reference, v_note,
    now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.production_proof_sent', 'booking', v_booking.id, false,
    NULL,
    jsonb_build_object('proof_round', v_round),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'production_proof_id', v_result.id,
      'proof_round', v_round,
      'production_item_count', v_item_count
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_production_proof$;

REVOKE ALL ON FUNCTION public.record_booking_production_proof(uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_production_proof(uuid,text,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_production_proof(uuid,text,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_production_proof(uuid,text,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_production_proof(uuid,text,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_production_proof(uuid,text,text) IS
  'Records that an album or frame layout proof was sent to the family. Requires at least one production item and no proof still awaiting a response.';

-- =====================================================================
-- Section I - Client proof response RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_proof_response(
  p_booking_id uuid,
  p_outcome text,
  p_note text DEFAULT NULL
)
RETURNS public.booking_production_proof_responses
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_proof_response$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_outcome text;
  v_note text;
  v_proof public.booking_production_proofs;
  v_result public.booking_production_proof_responses;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_proof_response: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_proof_response: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_proof_response: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_proof_response: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'production.manage', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_proof_response: production.manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_proof_response: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_outcome IS NULL THEN
    RAISE EXCEPTION 'record_booking_proof_response: outcome is required' USING ERRCODE = '22023';
  END IF;

  v_outcome := btrim(p_outcome);

  IF v_outcome = ''
     OR btrim(v_outcome, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_outcome <> btrim(v_outcome, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_outcome) > 24
     OR v_outcome ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_proof_response: outcome is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_outcome NOT IN ('approved', 'changes_requested') THEN
    RAISE EXCEPTION
      'record_booking_proof_response: outcome must be approved or changes_requested'
      USING ERRCODE = '22023';
  END IF;

  v_note := NULLIF(btrim(COALESCE(p_note, '')), '');

  IF v_note IS NOT NULL
     AND (
       btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_note <> btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_note) > 1000
       OR v_note ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_note, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_note := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_proof_response: response note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_note IS NOT NULL
     AND (
       v_note ~* '^(bearer|basic)[[:space:]]+'
       OR v_note ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_note ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_proof_response: response note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  IF v_outcome = 'changes_requested' AND v_note IS NULL THEN
    RAISE EXCEPTION
      'record_booking_proof_response: requested changes must be described in a note'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_proof_response: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_proof_response: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production'
  ) THEN
    RAISE EXCEPTION
      'record_booking_proof_response: booking must be exactly Album / Frame Production'
      USING ERRCODE = '22023';
  END IF;

  -- The open proof is the highest round with no recorded response.
  SELECT proof.* INTO v_proof
  FROM public.booking_production_proofs proof
  WHERE proof.organization_id = v_booking.organization_id
    AND proof.booking_id = v_booking.id
    AND NOT EXISTS (
      SELECT 1 FROM public.booking_production_proof_responses response
      WHERE response.proof_id = proof.id
    )
  ORDER BY proof.round DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_proof_response: there is no proof awaiting a client response'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_production_proof_responses (
    organization_id, booking_id, proof_id, round, outcome,
    response_note, responded_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_proof.id, v_proof.round, v_outcome,
    v_note, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.production_proof_answered', 'booking', v_booking.id, false,
    jsonb_build_object('proof_round', v_proof.round, 'answered', false),
    jsonb_build_object('proof_round', v_proof.round, 'answered', true, 'outcome', v_outcome),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'production_proof_id', v_proof.id,
      'proof_response_id', v_result.id,
      'proof_round', v_proof.round,
      'outcome', v_outcome,
      'note_present', (v_note IS NOT NULL)
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_proof_response$;

REVOKE ALL ON FUNCTION public.record_booking_proof_response(uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_proof_response(uuid,text,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_proof_response(uuid,text,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_proof_response(uuid,text,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_proof_response(uuid,text,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_proof_response(uuid,text,text) IS
  'Records the family response to the open proof round. changes_requested requires a note and permits a further proof round; approved closes proofing and permits dispatch.';

-- =====================================================================
-- Section J - Production milestone RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_production_milestone(
  p_booking_id uuid,
  p_milestone_type text,
  p_vendor_name text DEFAULT NULL,
  p_expected_at timestamptz DEFAULT NULL,
  p_detail_note text DEFAULT NULL,
  p_collected_by_name text DEFAULT NULL
)
RETURNS public.booking_production_milestones
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_production_milestone$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_type text;
  v_vendor text;
  v_detail text;
  v_collected_by text;
  v_approved_count integer;
  v_open_proof_count integer;
  v_item_count integer;
  v_result public.booking_production_milestones;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_production_milestone: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'production.manage', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: production.manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_milestone_type IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: milestone type is required' USING ERRCODE = '22023';
  END IF;

  v_type := btrim(p_milestone_type);

  IF v_type = ''
     OR btrim(v_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_type <> btrim(v_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_type) > 24
     OR v_type ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_production_milestone: milestone type is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_type NOT IN ('dispatched', 'received', 'handed_over') THEN
    RAISE EXCEPTION
      'record_booking_production_milestone: milestone type must be dispatched, received or handed_over'
      USING ERRCODE = '22023';
  END IF;

  v_vendor := NULLIF(btrim(COALESCE(p_vendor_name, '')), '');

  IF v_vendor IS NOT NULL
     AND (
       btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_vendor <> btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_vendor) > 160
       OR v_vendor ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_vendor := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_milestone: vendor name is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_vendor IS NOT NULL
     AND (
       v_vendor ~* '^(bearer|basic)[[:space:]]+'
       OR v_vendor ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_vendor ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: vendor name must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  v_detail := NULLIF(btrim(COALESCE(p_detail_note, '')), '');

  IF v_detail IS NOT NULL
     AND (
       btrim(v_detail, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_detail <> btrim(v_detail, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_detail) > 500
       OR v_detail ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_detail, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_detail := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_milestone: detail note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_detail IS NOT NULL
     AND (
       v_detail ~* '^(bearer|basic)[[:space:]]+'
       OR v_detail ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_detail ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: detail note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  v_collected_by := NULLIF(btrim(COALESCE(p_collected_by_name, '')), '');

  IF v_collected_by IS NOT NULL
     AND (
       btrim(v_collected_by, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_collected_by <> btrim(v_collected_by, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_collected_by) > 160
       OR v_collected_by ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_collected_by, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_collected_by := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_milestone: collected by name is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_collected_by IS NOT NULL
     AND (
       v_collected_by ~* '^(bearer|basic)[[:space:]]+'
       OR v_collected_by ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_collected_by ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: collected by name must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_production_milestone: canonical journey state is invalid'
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
    RAISE EXCEPTION 'record_booking_production_milestone: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_milestone: booking must be exactly Album / Frame Production'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.booking_production_milestones milestone
    WHERE milestone.organization_id = v_booking.organization_id
      AND milestone.booking_id = v_booking.id
      AND milestone.milestone_type = v_type
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_milestone: this production milestone is already recorded'
      USING ERRCODE = '22023';
  END IF;

  IF v_type = 'dispatched' THEN
    IF v_collected_by IS NOT NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: collected_by_name applies only to handed_over'
        USING ERRCODE = '22023';
    END IF;

    SELECT count(*) INTO v_item_count
    FROM public.booking_production_items item
    WHERE item.organization_id = v_booking.organization_id
      AND item.booking_id = v_booking.id;

    IF v_item_count < 1 THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: record the production items before dispatching'
        USING ERRCODE = '22023';
    END IF;

    SELECT count(*) INTO v_open_proof_count
    FROM public.booking_production_proofs proof
    WHERE proof.organization_id = v_booking.organization_id
      AND proof.booking_id = v_booking.id
      AND NOT EXISTS (
        SELECT 1 FROM public.booking_production_proof_responses response WHERE response.proof_id = proof.id
      );

    IF v_open_proof_count > 0 THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: a proof is still awaiting a client response'
        USING ERRCODE = '22023';
    END IF;

    SELECT count(*) INTO v_approved_count
    FROM public.booking_production_proof_responses response
    WHERE response.organization_id = v_booking.organization_id
      AND response.booking_id = v_booking.id
      AND response.outcome = 'approved';

    IF v_approved_count < 1 THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: the family must approve a proof before production is dispatched'
        USING ERRCODE = '22023';
    END IF;

    IF p_expected_at IS NOT NULL AND p_expected_at <= now() THEN
      RAISE EXCEPTION 'record_booking_production_milestone: expected date must be in the future'
        USING ERRCODE = '22023';
    END IF;

  ELSIF v_type = 'received' THEN
    IF v_vendor IS NOT NULL OR p_expected_at IS NOT NULL OR v_collected_by IS NOT NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: vendor, expected date and collected_by_name do not apply to received'
        USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.booking_production_milestones milestone
      WHERE milestone.organization_id = v_booking.organization_id
        AND milestone.booking_id = v_booking.id
        AND milestone.milestone_type = 'dispatched'
    ) THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: production must be dispatched before it can be received'
        USING ERRCODE = '22023';
    END IF;

  ELSE
    IF v_vendor IS NOT NULL OR p_expected_at IS NOT NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: vendor and expected date do not apply to handed_over'
        USING ERRCODE = '22023';
    END IF;

    IF v_collected_by IS NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: record who collected the items from the studio'
        USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.booking_production_milestones milestone
      WHERE milestone.organization_id = v_booking.organization_id
        AND milestone.booking_id = v_booking.id
        AND milestone.milestone_type = 'received'
    ) THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: production must be received before studio handover'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  INSERT INTO public.booking_production_milestones (
    organization_id, booking_id, milestone_type, vendor_name, expected_at,
    detail_note, collected_by_name, occurred_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_type, v_vendor, p_expected_at,
    v_detail, v_collected_by, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.production_' || v_type, 'booking', v_booking.id, false,
    NULL,
    jsonb_build_object('milestone_type', v_type),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'production_milestone_id', v_result.id,
      'milestone_type', v_type,
      'in_house', (v_type = 'dispatched' AND v_vendor IS NULL),
      'expected_at_present', (p_expected_at IS NOT NULL)
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_production_milestone$;

REVOKE ALL ON FUNCTION public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text) FROM anon;
REVOKE ALL ON FUNCTION public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text) TO authenticated;

COMMENT ON FUNCTION public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text) IS
  'Records one production milestone. dispatched requires items and an approved client proof, and takes an optional vendor (NULL means in-house). received requires dispatched. handed_over requires received and the name of whoever collected from the studio.';

-- =====================================================================
-- Section K - Stage 17 -> 18 gate
-- =====================================================================

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
REVOKE ALL ON FUNCTION public.mark_booking_album_frame_production(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mark_booking_album_frame_production(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.mark_booking_album_frame_production(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.mark_booking_album_frame_production(uuid) TO authenticated;

COMMENT ON FUNCTION public.mark_booking_album_frame_production(uuid) IS
  'Advances a booking from Delivered (17) to Album / Frame Production (18). Every package includes at least a printed frame, so this applies to every booking. Idempotent on replay.';

-- =====================================================================
-- Section L - Postconditions
-- =====================================================================

DO $hp1_postconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.booking_production_items') IS NULL
     OR to_regclass('public.booking_production_proofs') IS NULL
     OR to_regclass('public.booking_production_proof_responses') IS NULL
     OR to_regclass('public.booking_production_milestones') IS NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 postcondition failed: production relation missing';
  END IF;

  IF to_regprocedure('public.record_booking_production_item(uuid,text,text,integer,text)') IS NULL
     OR to_regprocedure('public.record_booking_production_proof(uuid,text,text)') IS NULL
     OR to_regprocedure('public.record_booking_proof_response(uuid,text,text)') IS NULL
     OR to_regprocedure('public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text)') IS NULL
     OR to_regprocedure('public.mark_booking_album_frame_production(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 postcondition failed: required mutation RPC missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission ON permission.id = role_permission.permission_id
  WHERE permission.key = 'production.manage';

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 postcondition failed: production.manage role boundary invalid';
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;

  IF v_count <> 275 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 postcondition failed: expected role-permission count 275, found %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname IN ('booking_production_items', 'booking_production_proofs', 'booking_production_proof_responses', 'booking_production_milestones')
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 postcondition failed: row level security not forced';
  END IF;

  IF has_function_privilege('anon', 'public.mark_booking_album_frame_production(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.mark_booking_album_frame_production(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.record_booking_production_milestone(uuid,text,text,timestamptz,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 postcondition failed: privileged execute must be denied';
  END IF;

  IF has_table_privilege('authenticated', 'public.booking_production_items', 'INSERT')
     OR has_table_privilege('authenticated', 'public.booking_production_milestones', 'INSERT')
     OR has_table_privilege('authenticated', 'public.booking_production_proof_responses', 'UPDATE') THEN
    RAISE EXCEPTION
      'Heirloom pipeline 1 postcondition failed: evidence tables must be read-only to authenticated';
  END IF;
END
$hp1_postconditions$;
