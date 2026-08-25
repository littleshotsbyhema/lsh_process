-- =====================================================================
-- Sprint 11 — Shoot Completion & Post-Session Handoff
-- Slice 5 — Canonical Client Image Selection Confirmation Evidence
--             Foundation
--
-- Boundary:
--   * selection.read + selection.record capabilities;
--   * immutable booking_selection_confirmations evidence;
--   * one controlled
--       record_booking_selection_confirmation(uuid,integer,timestamptz)
--     mutation RPC;
--   * authenticated selection.read containment;
--   * exact Stage 12 / selection_pending operation only;
--   * exact Stage 11 -> 12 / selection_pending lineage;
--   * no individual selected-image identifiers;
--   * no package-entitlement interpretation;
--   * no additional-image billing;
--   * no payment-settlement calculation;
--   * no Stage 12 -> 13 journey advancement;
--   * no privacy / consent mutation;
--   * no application UI.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11_slice5_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass(
       'public.booking_selection_confirmations'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: booking_selection_confirmations already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_selection_confirmation(uuid,integer,timestamp with time zone)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: selection confirmation RPC already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key IN (
      'selection.read',
      'selection.record'
    )
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: selection capabilities already exist';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.roles') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: required canonical relation missing';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_branch_scope(uuid,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.mark_booking_selection_pending(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 66 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: expected 66 canonical permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 233 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: expected 233 canonical role-permission mappings, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles role
  WHERE role.key IN (
    'founder',
    'studio_manager',
    'client_coordinator',
    'editor'
  );

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: required selection roles unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.stage_order = 12
    AND stage.stage_key = 'selection_pending'
    AND stage.is_active;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 precondition failed: canonical Stage 12 selection_pending unavailable';
  END IF;
END
$s11_slice5_preconditions$;

-- =====================================================================
-- Section B — Selection capabilities
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES
(
  'selection.read',
  'selection',
  'View selection confirmations',
  'Read canonical client image-selection confirmation evidence.',
  false
),
(
  'selection.record',
  'selection',
  'Record selection confirmation',
  'Record immutable canonical evidence that a client finalized an image selection.',
  true
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  role.id,
  permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.key IN (
    'founder',
    'studio_manager',
    'client_coordinator',
    'editor'
  )
  AND permission.key IN (
    'selection.read',
    'selection.record'
  );

-- =====================================================================
-- Section C1 — Canonical immutable selection confirmation evidence
-- =====================================================================

CREATE TABLE public.booking_selection_confirmations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  selected_image_count integer NOT NULL,
  confirmed_at timestamptz NOT NULL,

  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid NOT NULL,

  CONSTRAINT booking_selection_confirmations_count_chk
    CHECK (
      selected_image_count > 0
    ),

  CONSTRAINT booking_selection_confirmations_confirmed_at_chk
    CHECK (
      confirmed_at <= recorded_at
    ),

  CONSTRAINT booking_selection_confirmations_booking_fkey
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

  CONSTRAINT booking_selection_confirmations_recorded_by_fkey
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

  CONSTRAINT booking_selection_confirmations_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    )
);

CREATE INDEX booking_selection_confirmations_org_recorded_idx
ON public.booking_selection_confirmations (
  organization_id,
  recorded_at DESC
);

-- =====================================================================
-- Section C2 — Immutable lifecycle / attribution guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_selection_confirmation_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking selection confirmation evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.recorded_at IS NULL
     OR NEW.confirmed_at IS NULL
     OR NEW.selected_image_count IS NULL THEN
    RAISE EXCEPTION
      'booking selection confirmation evidence requires complete immutable attribution';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking selection confirmation recorded_by must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_selection_confirmations_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_selection_confirmations
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_selection_confirmation_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_selection_confirmation_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.lsh_booking_selection_confirmation_guard()
FROM anon;

REVOKE ALL
ON FUNCTION public.lsh_booking_selection_confirmation_guard()
FROM authenticated;

REVOKE ALL
ON FUNCTION public.lsh_booking_selection_confirmation_guard()
FROM service_role;

-- =====================================================================
-- Section C3 — Forced RLS / authenticated SELECT-only boundary
-- =====================================================================

ALTER TABLE public.booking_selection_confirmations
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_selection_confirmations
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_confirmations
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_confirmations
FROM anon;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_confirmations
FROM authenticated;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_confirmations
FROM service_role;

GRANT SELECT
ON TABLE public.booking_selection_confirmations
TO authenticated;

CREATE POLICY booking_selection_confirmations_authenticated_select
ON public.booking_selection_confirmations
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_selection_confirmations.organization_id
      AND booking.id =
          booking_selection_confirmations.booking_id
      AND public.has_permission(
            booking.organization_id,
            'selection.read',
            booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(
             booking.organization_id,
             booking.branch_id
           )
      )
  )
);

-- =====================================================================
-- Section D — Controlled selection-confirmation RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_selection_confirmation(
  p_booking_id uuid,
  p_selected_image_count integer,
  p_confirmed_at timestamptz
)
RETURNS public.booking_selection_confirmations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_existing public.booking_selection_confirmations;
  v_result public.booking_selection_confirmations;

  v_actor uuid;

  v_state_count integer := 0;
  v_selection_transition_count integer := 0;

  v_recorded_at timestamptz;
  v_stage12_transitioned_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_selected_image_count IS NULL
     OR p_selected_image_count <= 0 THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: selected_image_count must be a positive integer'
      USING ERRCODE = '22023';
  END IF;

  IF p_confirmed_at IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: confirmed_at is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  v_recorded_at := now();

  IF p_confirmed_at > v_recorded_at THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: confirmed_at cannot be in the future'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: booking synchronization root.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active member + dedicated selection authority + branch scope.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'selection.record',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: selection.record permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exactly one current canonical journey state.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id
  FOR UPDATE;

  SELECT stage.*
  INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.id =
        v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 12
     OR v_stage.stage_key <> 'selection_pending' THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: booking must be exactly Selection Pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact canonical Stage 11 -> 12 lineage.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_selection_transition_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id =
       transition_row.organization_id
   AND source_stage.id =
       transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id =
       transition_row.organization_id
   AND destination_stage.id =
       transition_row.to_stage_id
  WHERE transition_row.organization_id =
        v_booking.organization_id
    AND transition_row.booking_id =
        v_booking.id
    AND transition_row.transition_key =
        'selection_pending'
    AND source_stage.stage_order = 11
    AND source_stage.stage_key =
        'shoot_completed'
    AND destination_stage.stage_order = 12
    AND destination_stage.stage_key =
        'selection_pending';

  IF v_selection_transition_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: canonical Selection Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT transition_row.transitioned_at
  INTO v_stage12_transitioned_at
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id =
       transition_row.organization_id
   AND source_stage.id =
       transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id =
       transition_row.organization_id
   AND destination_stage.id =
       transition_row.to_stage_id
  WHERE transition_row.organization_id =
        v_booking.organization_id
    AND transition_row.booking_id =
        v_booking.id
    AND transition_row.transition_key =
        'selection_pending'
    AND source_stage.stage_order = 11
    AND source_stage.stage_key =
        'shoot_completed'
    AND destination_stage.stage_order = 12
    AND destination_stage.stage_key =
        'selection_pending';

  IF p_confirmed_at < v_stage12_transitioned_at THEN
    RAISE EXCEPTION
      'record_booking_selection_confirmation: confirmed_at cannot precede Selection Pending entry'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: immutable selection evidence / exact replay.
  --
  -- The booking lock serializes competing recording attempts for the
  -- same booking.
  -- ---------------------------------------------------------------

  SELECT confirmation.*
  INTO v_existing
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        v_booking.organization_id
    AND confirmation.booking_id =
        v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.selected_image_count
         IS DISTINCT FROM
       p_selected_image_count
       OR v_existing.confirmed_at
            IS DISTINCT FROM
          p_confirmed_at THEN
      RAISE EXCEPTION
        'record_booking_selection_confirmation: selection confirmation already exists with different evidence'
        USING ERRCODE = '22023';
    END IF;

    RETURN v_existing;
  END IF;

  -- ---------------------------------------------------------------
  -- Append immutable canonical confirmation evidence.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_selection_confirmations (
    organization_id,
    booking_id,
    selected_image_count,
    confirmed_at,
    recorded_at,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    p_selected_image_count,
    p_confirmed_at,
    v_recorded_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  -- ---------------------------------------------------------------
  -- One structural, non-sensitive audit event.
  --
  -- No image identifiers, gallery/proof content, free text,
  -- commercial interpretation, payment state or consent content.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.selection_confirmed',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'selected_image_count',
        v_result.selected_image_count,
      'confirmed_at',
        v_result.confirmed_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'selection_confirmation_id',
        v_result.id,
      'selected_image_count',
        v_result.selected_image_count,
      'confirmed_at',
        v_result.confirmed_at,
      'recorded_by',
        v_actor
    ),
    'application',
    NULL
  );

  -- Journey intentionally remains exact Stage 12.
  -- No booking_journey_states or booking_stage_transitions mutation.

  RETURN v_result;
END;
$$;

-- =====================================================================
-- Section E — RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION
  public.record_booking_selection_confirmation(uuid,integer,timestamptz)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION
  public.record_booking_selection_confirmation(uuid,integer,timestamptz)
FROM anon;

REVOKE ALL
ON FUNCTION
  public.record_booking_selection_confirmation(uuid,integer,timestamptz)
FROM authenticated;

REVOKE ALL
ON FUNCTION
  public.record_booking_selection_confirmation(uuid,integer,timestamptz)
FROM service_role;

GRANT EXECUTE
ON FUNCTION
  public.record_booking_selection_confirmation(uuid,integer,timestamptz)
TO authenticated;

COMMENT ON TABLE public.booking_selection_confirmations IS
  'Immutable canonical evidence that a client finalized an image selection. This relation does not represent image-use consent or commercial settlement.';

COMMENT ON FUNCTION
  public.record_booking_selection_confirmation(uuid,integer,timestamptz)
IS
  'Record immutable canonical client image-selection confirmation evidence at exact Stage 12 Selection Pending without advancing the journey or calculating commercial consequences.';

-- =====================================================================
-- Section F — Migration assertions
-- =====================================================================

DO $s11_slice5_assertions$
DECLARE
  v_count integer;
  v_expected integer;
BEGIN
  -- Exact repository totals after the frozen capability additions.
  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: expected 68 canonical permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: expected 241 canonical role-permission mappings, found %',
      v_count;
  END IF;

  -- Exact permission semantics.
  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key = 'selection.read'
    AND permission.domain = 'selection'
    AND permission.label = 'View selection confirmations'
    AND NOT permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: selection.read permission contract invalid';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key = 'selection.record'
    AND permission.domain = 'selection'
    AND permission.label = 'Record selection confirmation'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: selection.record permission contract invalid';
  END IF;

  -- Exact role-grant contract for both capabilities.
  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id = role_permission.permission_id
  WHERE permission.key IN (
    'selection.read',
    'selection.record'
  );

  SELECT count(*)
  INTO v_expected
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id = role_permission.permission_id
  JOIN public.roles role
    ON role.id = role_permission.role_id
  WHERE permission.key IN (
      'selection.read',
      'selection.record'
    )
    AND role.key IN (
      'founder',
      'studio_manager',
      'client_coordinator',
      'editor'
    );

  IF v_count <> 8
     OR v_expected <> 8 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: selection role grants invalid';
  END IF;

  -- Evidence relation + forced RLS.
  IF to_regclass(
       'public.booking_selection_confirmations'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: selection confirmation relation unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace
    ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname =
        'booking_selection_confirmations'
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: selection confirmation RLS contract invalid';
  END IF;

  -- Authenticated table mutation unavailable; SELECT available.
  IF has_table_privilege(
       'authenticated',
       'public.booking_selection_confirmations',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_selection_confirmations',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_selection_confirmations',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: authenticated direct mutation must be denied';
  END IF;

  IF NOT has_table_privilege(
           'authenticated',
           'public.booking_selection_confirmations',
           'SELECT'
         ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: authenticated SELECT unavailable';
  END IF;

  -- Controlled RPC signature / security contract.
  IF to_regprocedure(
       'public.record_booking_selection_confirmation(uuid,integer,timestamp with time zone)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: selection confirmation RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc procedure
  JOIN pg_namespace namespace
    ON namespace.oid = procedure.pronamespace
  WHERE namespace.nspname = 'public'
    AND procedure.proname =
        'record_booking_selection_confirmation'
    AND pg_get_function_identity_arguments(
          procedure.oid
        ) =
        'p_booking_id uuid, p_selected_image_count integer, p_confirmed_at timestamp with time zone'
    AND pg_get_function_result(
          procedure.oid
        ) =
        'booking_selection_confirmations'
    AND procedure.prosecdef
    AND procedure.proconfig =
        ARRAY['search_path=""']::text[];

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: selection confirmation RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.record_booking_selection_confirmation(uuid,integer,timestamptz)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: authenticated RPC EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.record_booking_selection_confirmation(uuid,integer,timestamptz)',
       'EXECUTE'
     )
     OR has_function_privilege(
          'service_role',
          'public.record_booking_selection_confirmation(uuid,integer,timestamptz)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 5 validation failed: forbidden RPC EXECUTE detected';
  END IF;
END
$s11_slice5_assertions$;

-- =====================================================================
-- End Slice 5
-- =====================================================================
