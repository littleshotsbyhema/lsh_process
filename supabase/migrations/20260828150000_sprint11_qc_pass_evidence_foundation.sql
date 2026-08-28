-- =====================================================================
-- Sprint 11 - Shoot Completion & Post-Session Handoff
-- Slice 16 - QC Pass Evidence Foundation
--
-- Frozen authority:
--   * one immutable booking_qc_passes relation;
--   * exactly six columns;
--   * one record_booking_qc_pass(uuid) application RPC;
--   * existing editing.write mutation authority only;
--   * existing editing.read read authority only;
--   * exact Stage 15 qc_pending containment;
--   * exact Stage 14 -> 15 qc_pending source-transition lineage;
--   * strict Stage-15-only idempotent replay;
--   * one booking.qc_passed first-success audit;
--   * no journey advancement;
--   * no new permission;
--   * no journey, gallery or delivery authority.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $s11s16_preconditions$
DECLARE
  v_count integer;
  v_roles text[];
BEGIN
  IF to_regclass(
       'public.booking_qc_passes'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: booking_qc_passes already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_qc_pass(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: record_booking_qc_pass already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass(
          'public.booking_journey_states'
        ) IS NULL
     OR to_regclass(
          'public.booking_journey_stages'
        ) IS NULL
     OR to_regclass(
          'public.booking_stage_transitions'
        ) IS NULL
     OR to_regclass(
          'public.booking_editing_completions'
        ) IS NULL
     OR to_regclass(
          'public.organization_members'
        ) IS NULL
     OR to_regclass(
          'public.permissions'
        ) IS NULL
     OR to_regclass(
          'public.role_permissions'
        ) IS NULL
     OR to_regclass(
          'public.roles'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: prerequisite relation missing';
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
          'public.mark_booking_qc_pending(uuid)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: prerequisite helper/RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'editing.write';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'editor',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: editing.write topology is %',
      v_roles;
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'editing.read';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'client_coordinator',
         'editor',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: editing.read topology is %',
      v_roles;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.stage_order = 15
    AND stage.stage_key =
        'qc_pending'
    AND stage.is_active;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 precondition failed: canonical Stage 15 qc_pending unavailable';
  END IF;
END
$s11s16_preconditions$;


-- =====================================================================
-- Section B - Immutable QC Pass evidence
-- =====================================================================

CREATE TABLE public.booking_qc_passes (
  id uuid CONSTRAINT bpass_pkey PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  source_qc_pending_transition_id uuid NOT NULL,

  passed_at timestamptz NOT NULL,
  passed_by uuid NOT NULL,

  CONSTRAINT bpass_booking_fkey
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

  CONSTRAINT bpass_source_transition_fkey
    FOREIGN KEY (
      organization_id,
      source_qc_pending_transition_id
    )
    REFERENCES public.booking_stage_transitions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT bpass_passed_by_fkey
    FOREIGN KEY (
      passed_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT bpass_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    ),

  CONSTRAINT bpass_org_source_transition_key
    UNIQUE (
      organization_id,
      source_qc_pending_transition_id
    )
);

CREATE INDEX bpass_org_passed_idx
ON public.booking_qc_passes (
  organization_id,
  passed_at DESC,
  id
);


-- =====================================================================
-- Section C - Immutable lifecycle and source-transition guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_qc_pass_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_transitioned_at timestamptz;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking QC pass evidence is immutable';
  END IF;

  IF NEW.organization_id IS NULL
     OR NEW.booking_id IS NULL
     OR NEW.source_qc_pending_transition_id IS NULL
     OR NEW.passed_at IS NULL
     OR NEW.passed_by IS NULL THEN
    RAISE EXCEPTION
      'booking QC pass evidence requires complete immutable attribution';
  END IF;

  SELECT transition_row.transitioned_at
  INTO v_transitioned_at
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
        NEW.organization_id
    AND transition_row.id =
        NEW.source_qc_pending_transition_id
    AND transition_row.booking_id =
        NEW.booking_id
    AND transition_row.transition_key =
        'qc_pending'
    AND source_stage.stage_order = 14
    AND source_stage.stage_key =
        'editing_in_progress'
    AND destination_stage.stage_order = 15
    AND destination_stage.stage_key =
        'qc_pending'
    AND destination_stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking QC pass source transition must be the canonical Stage 14 to 15 qc_pending transition';
  END IF;

  IF NEW.passed_at <
       v_transitioned_at THEN
    RAISE EXCEPTION
      'booking QC pass cannot precede canonical QC Pending entry';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.passed_by IS DISTINCT FROM
          v_actor THEN
      RAISE EXCEPTION
        'booking QC pass passed_by must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_qc_passes_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_qc_passes
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_qc_pass_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_qc_pass_guard()
FROM PUBLIC, anon, authenticated, service_role;


-- =====================================================================
-- Section D - Forced RLS and existing editing.read authority
-- =====================================================================

ALTER TABLE public.booking_qc_passes
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_qc_passes
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_qc_passes
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_qc_passes
TO authenticated;

GRANT ALL
ON TABLE public.booking_qc_passes
TO service_role;

CREATE POLICY booking_qc_passes_authenticated_select
ON public.booking_qc_passes
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_qc_passes.organization_id
      AND booking.id =
          booking_qc_passes.booking_id
      AND public.has_permission(
            booking.organization_id,
            'editing.read',
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
-- Section E - Controlled QC Pass recorder
-- =====================================================================

CREATE FUNCTION public.record_booking_qc_pass(
  p_booking_id uuid
)
RETURNS public.booking_qc_passes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_transition public.booking_stage_transitions;

  v_existing public.booking_qc_passes;
  v_result public.booking_qc_passes;

  v_actor uuid;
  v_passed_at timestamptz;

  v_state_count integer := 0;
  v_transition_count integer := 0;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- Booking is the canonical synchronization root.

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'editing.write',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: editing.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- Exactly one current canonical journey state.

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: booking must have exactly one current journey state'
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
      'record_booking_qc_pass: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 15
     OR v_stage.stage_key <>
        'qc_pending' THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: booking must be exactly QC Pending'
      USING ERRCODE = '22023';
  END IF;

  -- Exact canonical Stage 14 -> 15 source-transition lineage.

  SELECT count(*)
  INTO v_transition_count
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
        'qc_pending'
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 14
    AND source_stage.stage_key =
        'editing_in_progress'
    AND destination_stage.stage_order = 15
    AND destination_stage.stage_key =
        'qc_pending';

  IF v_transition_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: canonical QC Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT transition_row.*
  INTO v_transition
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
        'qc_pending'
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 14
    AND source_stage.stage_key =
        'editing_in_progress'
    AND destination_stage.stage_order = 15
    AND destination_stage.stage_key =
        'qc_pending';

  v_passed_at := now();

  IF v_passed_at <
       v_transition.transitioned_at THEN
    RAISE EXCEPTION
      'record_booking_qc_pass: QC pass cannot precede QC Pending entry'
      USING ERRCODE = '22023';
  END IF;

  -- Strict Stage-15-only idempotency.

  SELECT qc_pass.*
  INTO v_existing
  FROM public.booking_qc_passes qc_pass
  WHERE qc_pass.organization_id =
        v_booking.organization_id
    AND qc_pass.booking_id =
        v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.source_qc_pending_transition_id
         IS DISTINCT FROM
       v_transition.id
       OR v_existing.passed_at <
          v_transition.transitioned_at THEN
      RAISE EXCEPTION
        'record_booking_qc_pass: existing QC-pass evidence is inconsistent'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing;
  END IF;

  INSERT INTO public.booking_qc_passes (
    organization_id,
    booking_id,
    source_qc_pending_transition_id,
    passed_at,
    passed_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_transition.id,
    v_passed_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.qc_passed',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'qc_pass_id',
        v_result.id,
      'source_qc_pending_transition_id',
        v_result.source_qc_pending_transition_id,
      'qc_pending_stage_id',
        v_state.current_stage_id,
      'passed_at',
        v_result.passed_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'qc_pass_id',
        v_result.id,
      'source_qc_pending_transition_id',
        v_result.source_qc_pending_transition_id,
      'qc_pending_stage_id',
        v_state.current_stage_id,
      'passed_at',
        v_result.passed_at
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$$;

COMMENT ON TABLE public.booking_qc_passes IS
  'Immutable canonical evidence that QC passed for a booking at exact canonical Stage 15 QC Pending. Does not advance the booking journey or create gallery/delivery authority.';

COMMENT ON FUNCTION public.record_booking_qc_pass(uuid) IS
  'Record immutable QC-pass evidence for an authorized booking at exact canonical Stage 15 QC Pending. Uses editing.write and does not advance the journey or create gallery/delivery authority.';


-- =====================================================================
-- Section F - RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.record_booking_qc_pass(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.record_booking_qc_pass(uuid)
TO authenticated;


-- =====================================================================
-- Section G - Final frozen-contract assertions
-- =====================================================================

DO $s11s16_assertions$
DECLARE
  v_count integer;
  v_roles text[];
  v_definition text;
BEGIN
  IF to_regclass(
       'public.booking_qc_passes'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: booking_qc_passes missing';
  END IF;

  IF to_regprocedure(
       'public.record_booking_qc_pass(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: recorder RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'booking_qc_passes';

  IF v_count <> 6 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: booking_qc_passes expected 6 columns, found %',
      v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.booking_qc_passes'::regclass
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: RLS must be enabled and forced';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: role-permission count changed';
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'editing.write';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'editor',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: editing.write topology changed';
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'editing.read';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'client_coordinator',
         'editor',
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: editing.read topology changed';
  END IF;

  SELECT pg_get_functiondef(
           'public.record_booking_qc_pass(uuid)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%editing.write%'
     OR v_definition NOT ILIKE
       '%has_branch_scope%'
     OR v_definition NOT ILIKE
       '%booking_stage_transitions%'
     OR v_definition NOT ILIKE
       '%qc_pending%'
     OR v_definition NOT ILIKE
       '%FOR UPDATE%'
     OR v_definition NOT ILIKE
       '%append_audit_event%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: recorder source lacks frozen authority markers';
  END IF;

  IF v_definition ILIKE
       '%booking.stage.advance%'
     OR v_definition ILIKE
       '%editing.read%'
     OR v_definition ILIKE
       '%delivery.read%'
     OR v_definition ILIKE
       '%delivery.write%'
     OR v_definition ILIKE
       '%review.read%'
     OR v_definition ILIKE
       '%review.write%'
     OR v_definition ILIKE
       '%finance.read%'
     OR v_definition ILIKE
       '%payment.read%'
     OR v_definition ILIKE
       '%booking.team.assign%'
     OR v_definition ILIKE
       '%booking_editing_completions%'
     OR v_definition ILIKE
       '%record_booking_editing_completion%'
     OR v_definition ILIKE
       '%booking_editing_starts%'
     OR v_definition ILIKE
       '%pixieset_gallery_ready%'
     OR v_definition ILIKE
       '%delivered%'
     OR v_definition ILIKE
       '%INSERT INTO public.booking_stage_transitions%'
     OR v_definition ILIKE
       '%UPDATE public.booking_journey_states%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: recorder imports excluded authority';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_class relation
  JOIN pg_catalog.pg_namespace namespace
    ON namespace.oid =
       relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relkind IN (
      'r',
      'p',
      'v',
      'm',
      'f'
    )
    AND relation.relname ILIKE '%editing%'
    AND relation.relname NOT IN (
      'booking_editing_starts',
      'booking_editing_completions'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: unauthorized editing persistence exists';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_class relation
  JOIN pg_catalog.pg_namespace namespace
    ON namespace.oid =
       relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname <> 'booking_qc_passes'
    AND (
      relation.relname ILIKE '%qc%'
      OR relation.relname ILIKE '%pixieset%'
      OR relation.relname ILIKE '%delivery%'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 16 validation failed: unauthorized additional QC/gallery/delivery persistence exists';
  END IF;
END
$s11s16_assertions$;
