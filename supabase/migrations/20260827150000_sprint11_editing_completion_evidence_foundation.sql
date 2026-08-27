-- =====================================================================
-- Sprint 11 - Shoot Completion & Post-Session Handoff
-- Slice 14 - Editing Completion Evidence Foundation
--
-- Frozen authority:
--   * one immutable booking_editing_completions relation;
--   * exactly six columns;
--   * one record_booking_editing_completion(uuid) application RPC;
--   * existing editing.write mutation authority only;
--   * existing editing.read read authority only;
--   * exact Stage 14 editing_in_progress containment;
--   * exact Stage 13 -> 14 editing_in_progress source-transition lineage;
--   * strict Stage-14-only idempotent replay;
--   * one booking.editing_completed first-success audit;
--   * no journey advancement;
--   * no new permission;
--   * no QC, gallery or delivery authority.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $s11s14_preconditions$
DECLARE
  v_count integer;
  v_roles text[];
BEGIN
  IF to_regclass(
       'public.booking_editing_completions'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 precondition failed: booking_editing_completions already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_editing_completion(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 precondition failed: record_booking_editing_completion already exists';
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
          'public.booking_editing_starts'
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
      'Sprint 11 Slice 14 precondition failed: prerequisite relation missing';
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
          'public.record_booking_editing_start(uuid)'
        ) IS NULL
     OR to_regprocedure(
          'public.mark_booking_editing_in_progress(uuid)'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 precondition failed: prerequisite helper/RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 precondition failed: expected 241 role-permission mappings, found %',
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
      'Sprint 11 Slice 14 precondition failed: editing.write topology is %',
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
      'Sprint 11 Slice 14 precondition failed: editing.read topology is %',
      v_roles;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND stage.stage_order = 14
    AND stage.stage_key =
        'editing_in_progress'
    AND stage.is_active;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 precondition failed: canonical Stage 14 editing_in_progress unavailable';
  END IF;
END
$s11s14_preconditions$;


-- =====================================================================
-- Section B - Immutable Editing Completion evidence
-- =====================================================================

CREATE TABLE public.booking_editing_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  source_editing_in_progress_transition_id uuid NOT NULL,

  completed_at timestamptz NOT NULL,
  completed_by uuid NOT NULL,

  CONSTRAINT booking_editing_completions_booking_fkey
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

  CONSTRAINT booking_editing_completions_source_transition_fkey
    FOREIGN KEY (
      organization_id,
      source_editing_in_progress_transition_id
    )
    REFERENCES public.booking_stage_transitions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_editing_completions_completed_by_fkey
    FOREIGN KEY (
      completed_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_editing_completions_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    ),

  CONSTRAINT booking_editing_completions_org_source_transition_key
    UNIQUE (
      organization_id,
      source_editing_in_progress_transition_id
    )
);

CREATE INDEX booking_editing_completions_org_completed_idx
ON public.booking_editing_completions (
  organization_id,
  completed_at DESC,
  id
);


-- =====================================================================
-- Section C - Immutable lifecycle and source-transition guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_editing_completion_guard()
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
      'booking editing completion evidence is immutable';
  END IF;

  IF NEW.organization_id IS NULL
     OR NEW.booking_id IS NULL
     OR NEW.source_editing_in_progress_transition_id IS NULL
     OR NEW.completed_at IS NULL
     OR NEW.completed_by IS NULL THEN
    RAISE EXCEPTION
      'booking editing completion evidence requires complete immutable attribution';
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
        NEW.source_editing_in_progress_transition_id
    AND transition_row.booking_id =
        NEW.booking_id
    AND transition_row.transition_key =
        'editing_in_progress'
    AND source_stage.stage_order = 13
    AND source_stage.stage_key =
        'editing_pending'
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key =
        'editing_in_progress'
    AND destination_stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking editing completion source transition must be the canonical Stage 13 to 14 editing_in_progress transition';
  END IF;

  IF NEW.completed_at <
       v_transitioned_at THEN
    RAISE EXCEPTION
      'booking editing completion cannot precede canonical Editing In Progress entry';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.completed_by IS DISTINCT FROM
          v_actor THEN
      RAISE EXCEPTION
        'booking editing completion completed_by must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_editing_completions_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_editing_completions
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_editing_completion_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_editing_completion_guard()
FROM PUBLIC, anon, authenticated, service_role;


-- =====================================================================
-- Section D - Forced RLS and existing editing.read authority
-- =====================================================================

ALTER TABLE public.booking_editing_completions
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_editing_completions
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_editing_completions
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_editing_completions
TO authenticated;

GRANT ALL
ON TABLE public.booking_editing_completions
TO service_role;

CREATE POLICY booking_editing_completions_authenticated_select
ON public.booking_editing_completions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_editing_completions.organization_id
      AND booking.id =
          booking_editing_completions.booking_id
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
-- Section E - Controlled Editing Completion recorder
-- =====================================================================

CREATE FUNCTION public.record_booking_editing_completion(
  p_booking_id uuid
)
RETURNS public.booking_editing_completions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_transition public.booking_stage_transitions;

  v_existing public.booking_editing_completions;
  v_result public.booking_editing_completions;

  v_actor uuid;
  v_completed_at timestamptz;

  v_state_count integer := 0;
  v_transition_count integer := 0;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: authenticated actor required'
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
      'record_booking_editing_completion: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'editing.write',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: editing.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: booking branch scope required'
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
      'record_booking_editing_completion: booking must have exactly one current journey state'
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
      'record_booking_editing_completion: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 14
     OR v_stage.stage_key <>
        'editing_in_progress' THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: booking must be exactly Editing In Progress'
      USING ERRCODE = '22023';
  END IF;

  -- Exact canonical Stage 13 -> 14 source-transition lineage.

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
        'editing_in_progress'
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 13
    AND source_stage.stage_key =
        'editing_pending'
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key =
        'editing_in_progress';

  IF v_transition_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: canonical Editing In Progress transition history is invalid'
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
        'editing_in_progress'
    AND transition_row.to_stage_id =
        v_state.current_stage_id
    AND source_stage.stage_order = 13
    AND source_stage.stage_key =
        'editing_pending'
    AND destination_stage.stage_order = 14
    AND destination_stage.stage_key =
        'editing_in_progress';

  v_completed_at := now();

  IF v_completed_at <
       v_transition.transitioned_at THEN
    RAISE EXCEPTION
      'record_booking_editing_completion: editing completion cannot precede Editing In Progress entry'
      USING ERRCODE = '22023';
  END IF;

  -- Strict Stage-14-only idempotency.

  SELECT editing_completion.*
  INTO v_existing
  FROM public.booking_editing_completions editing_completion
  WHERE editing_completion.organization_id =
        v_booking.organization_id
    AND editing_completion.booking_id =
        v_booking.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.source_editing_in_progress_transition_id
         IS DISTINCT FROM
       v_transition.id
       OR v_existing.completed_at <
          v_transition.transitioned_at THEN
      RAISE EXCEPTION
        'record_booking_editing_completion: existing editing-completion evidence is inconsistent'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing;
  END IF;

  INSERT INTO public.booking_editing_completions (
    organization_id,
    booking_id,
    source_editing_in_progress_transition_id,
    completed_at,
    completed_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_transition.id,
    v_completed_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_completed',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'editing_completion_id',
        v_result.id,
      'source_editing_in_progress_transition_id',
        v_result.source_editing_in_progress_transition_id,
      'completed_at',
        v_result.completed_at
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'editing_completion_id',
        v_result.id,
      'source_editing_in_progress_transition_id',
        v_result.source_editing_in_progress_transition_id,
      'completed_at',
        v_result.completed_at
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$$;

COMMENT ON TABLE public.booking_editing_completions IS
  'Immutable canonical evidence that editing work completed for a booking at exact canonical Stage 14 Editing In Progress. Does not advance the booking journey or represent QC.';

COMMENT ON FUNCTION public.record_booking_editing_completion(uuid) IS
  'Record immutable editing-completion evidence for an authorized booking at exact canonical Stage 14 Editing In Progress. Uses editing.write and does not advance the journey or represent QC.';


-- =====================================================================
-- Section F - RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.record_booking_editing_completion(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.record_booking_editing_completion(uuid)
TO authenticated;


-- =====================================================================
-- Section G - Final frozen-contract assertions
-- =====================================================================

DO $s11s14_assertions$
DECLARE
  v_count integer;
  v_roles text[];
  v_definition text;
BEGIN
  IF to_regclass(
       'public.booking_editing_completions'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: booking_editing_completions missing';
  END IF;

  IF to_regprocedure(
       'public.record_booking_editing_completion(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: recorder RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'booking_editing_completions';

  IF v_count <> 6 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: booking_editing_completions expected 6 columns, found %',
      v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.booking_editing_completions'::regclass
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: RLS must be enabled and forced';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: permission count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: role-permission count changed';
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
      'Sprint 11 Slice 14 validation failed: editing.write topology changed';
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
      'Sprint 11 Slice 14 validation failed: editing.read topology changed';
  END IF;

  SELECT pg_get_functiondef(
           'public.record_booking_editing_completion(uuid)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%editing.write%'
     OR v_definition NOT ILIKE
       '%has_branch_scope%'
     OR v_definition NOT ILIKE
       '%booking_stage_transitions%'
     OR v_definition NOT ILIKE
       '%editing_in_progress%'
     OR v_definition NOT ILIKE
       '%FOR UPDATE%'
     OR v_definition NOT ILIKE
       '%append_audit_event%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: recorder source lacks frozen authority markers';
  END IF;

  IF v_definition ILIKE
       '%booking.stage.advance%'
     OR v_definition ILIKE
       '%finance.read%'
     OR v_definition ILIKE
       '%payment.read%'
     OR v_definition ILIKE
       '%delivery.write%'
     OR v_definition ILIKE
       '%booking.team.assign%'
     OR v_definition ILIKE
       '%booking_selection_confirmations%'
     OR v_definition ILIKE
       '%booking_selection_reconciliations%'
     OR v_definition ILIKE
       '%booking_payment_requirements%'
     OR v_definition ILIKE
       '%booking_payments%'
     OR v_definition ILIKE
       '%booking_payment_reversals%'
     OR v_definition ILIKE
       '%booking_adjusted_financial_obligations%'
     OR v_definition ILIKE
       '%get_booking_full_balance_summary%'
     OR v_definition ILIKE
       '%qc_pending%'
     OR v_definition ILIKE
       '%INSERT INTO public.booking_stage_transitions%'
     OR v_definition ILIKE
       '%UPDATE public.booking_journey_states%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: recorder imports excluded authority';
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
      'Sprint 11 Slice 14 validation failed: unauthorized editing persistence exists';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_class relation
  JOIN pg_catalog.pg_namespace namespace
    ON namespace.oid =
       relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND (
      relation.relname ILIKE '%qc%'
      OR relation.relname ILIKE '%pixieset%'
      OR relation.relname ILIKE '%delivery%'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 14 validation failed: QC/gallery/delivery persistence is unauthorized';
  END IF;
END
$s11s14_assertions$;
