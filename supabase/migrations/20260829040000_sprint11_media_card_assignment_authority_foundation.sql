-- =====================================================================
-- Phase 2 Studio Operations
-- Corrective Slice B1 - Media Card Assignment Authority
--
-- Frozen boundary:
--   * one media.card.assign permission;
--   * photographer grant topology only;
--   * one canonical public.media_card_assignments relation;
--   * current internal booking Lead Photographer only;
--   * Stage 10 shoot_scheduled assignment only;
--   * no removal, shot accounting, sealing, transfer, ingestion, or release.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $media_card_assignment_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass(
       'public.media_card_assignments'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: public.media_card_assignments already exists';
  END IF;

  IF to_regprocedure(
       'public.assign_media_card(uuid,uuid,uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: assign_media_card(uuid,uuid,uuid) already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key =
          'media.card.assign'
  ) THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: media.card.assign already exists';
  END IF;

  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.bookings') IS NULL
     OR to_regclass('public.media_cards') IS NULL
     OR to_regclass('public.capture_devices') IS NULL
     OR to_regclass('public.booking_team_assignments') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: required canonical relation missing';
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
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 70 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: expected 70 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 245 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: expected 245 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles role
  WHERE role.key =
        'photographer';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: expected exactly one photographer role, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'booking_team_assignments'
    AND column_name IN (
      'id',
      'organization_id',
      'booking_id',
      'assignment_role',
      'assigned_member_id',
      'assigned_external_creative_id',
      'ended_at'
    );

  IF v_count <> 7 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 precondition failed: canonical booking-team assignment subject model unavailable';
  END IF;
END
$media_card_assignment_preconditions$;


-- =====================================================================
-- Section B - Narrow media-card assignment authority
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'media.card.assign',
  'media',
  'Assign media cards',
  'Assign registered media cards to registered capture devices for the current booking Lead Photographer.',
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
WHERE role.key =
      'photographer'
  AND permission.key =
      'media.card.assign';


DO $media_card_assignment_permission_assertions$
DECLARE
  v_permission_count integer;
  v_grant_count integer;
  v_photographer_grant_count integer;
BEGIN
  SELECT count(*)
  INTO v_permission_count
  FROM public.permissions permission
  WHERE permission.key =
        'media.card.assign'
    AND permission.domain =
        'media'
    AND permission.label =
        'Assign media cards'
    AND permission.description =
        'Assign registered media cards to registered capture devices for the current booking Lead Photographer.'
    AND permission.requires_server_enforcement;

  IF v_permission_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 permission assertion failed: media.card.assign contract mismatch';
  END IF;

  SELECT count(*)
  INTO v_grant_count
  FROM public.role_permissions grant_row
  JOIN public.permissions permission
    ON permission.id =
       grant_row.permission_id
  WHERE permission.key =
        'media.card.assign';

  SELECT count(*)
  INTO v_photographer_grant_count
  FROM public.role_permissions grant_row
  JOIN public.permissions permission
    ON permission.id =
       grant_row.permission_id
  JOIN public.roles role
    ON role.id =
       grant_row.role_id
  WHERE permission.key =
        'media.card.assign'
    AND role.key =
        'photographer';

  IF v_grant_count <> 1
     OR v_photographer_grant_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 permission assertion failed: media.card.assign must have exactly the photographer grant';
  END IF;
END
$media_card_assignment_permission_assertions$;


-- =====================================================================
-- Section C - Canonical media-card assignment evidence
-- =====================================================================

CREATE TABLE public.media_card_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  media_card_id uuid NOT NULL,
  capture_device_id uuid NOT NULL,

  lead_photographer_assignment_id uuid NOT NULL,
  custodian_member_id uuid NOT NULL,

  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by uuid NOT NULL,

  ended_at timestamptz,
  ended_by uuid,

  CONSTRAINT media_card_assignments_lifecycle_chk
    CHECK (
      (
        ended_at IS NULL
        AND ended_by IS NULL
      )
      OR
      (
        ended_at IS NOT NULL
        AND ended_by IS NOT NULL
      )
    ),

  CONSTRAINT media_card_assignments_end_time_chk
    CHECK (
      ended_at IS NULL
      OR ended_at >= assigned_at
    ),

  CONSTRAINT media_card_assignments_initial_custodian_chk
    CHECK (
      custodian_member_id = assigned_by
    ),

  CONSTRAINT media_card_assignments_booking_fkey
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

  CONSTRAINT media_card_assignments_media_card_fkey
    FOREIGN KEY (
      organization_id,
      media_card_id
    )
    REFERENCES public.media_cards (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_assignments_capture_device_fkey
    FOREIGN KEY (
      organization_id,
      capture_device_id
    )
    REFERENCES public.capture_devices (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_assignments_lead_assignment_fkey
    FOREIGN KEY (
      lead_photographer_assignment_id,
      organization_id,
      booking_id
    )
    REFERENCES public.booking_team_assignments (
      id,
      organization_id,
      booking_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_assignments_custodian_fkey
    FOREIGN KEY (
      custodian_member_id,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_assignments_assigned_by_fkey
    FOREIGN KEY (
      assigned_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_assignments_ended_by_fkey
    FOREIGN KEY (
      ended_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_assignments_id_org_booking_key
    UNIQUE (
      id,
      organization_id,
      booking_id
    )
);

CREATE UNIQUE INDEX media_card_assignments_active_card_uidx
ON public.media_card_assignments (
  organization_id,
  media_card_id
)
WHERE ended_at IS NULL;

CREATE INDEX media_card_assignments_org_booking_history_idx
ON public.media_card_assignments (
  organization_id,
  booking_id,
  assigned_at DESC
);

CREATE INDEX media_card_assignments_current_device_idx
ON public.media_card_assignments (
  organization_id,
  capture_device_id
)
WHERE ended_at IS NULL;


-- =====================================================================
-- Section D - Immutable B1 assignment evidence
-- =====================================================================

CREATE FUNCTION public.lsh_media_card_assignment_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'media card assignment evidence cannot be deleted';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'media card assignment evidence is immutable during B1';
  END IF;

  IF NEW.ended_at IS NOT NULL
     OR NEW.ended_by IS NOT NULL THEN
    RAISE EXCEPTION
      'media card assignment must be inserted as active';
  END IF;

  IF NEW.custodian_member_id
       IS DISTINCT FROM
     NEW.assigned_by THEN
    RAISE EXCEPTION
      'media card assignment initial custodian must equal assigning member';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER media_card_assignments_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.media_card_assignments
FOR EACH ROW
EXECUTE FUNCTION public.lsh_media_card_assignment_guard();

REVOKE ALL
ON FUNCTION public.lsh_media_card_assignment_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.lsh_media_card_assignment_guard()
FROM anon;

REVOKE ALL
ON FUNCTION public.lsh_media_card_assignment_guard()
FROM authenticated;

REVOKE ALL
ON FUNCTION public.lsh_media_card_assignment_guard()
FROM service_role;


-- =====================================================================
-- Section E - Forced RLS / authenticated read boundary
-- =====================================================================

ALTER TABLE public.media_card_assignments
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.media_card_assignments
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_assignments
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_assignments
FROM anon;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_assignments
FROM authenticated;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_assignments
FROM service_role;

GRANT SELECT
ON TABLE public.media_card_assignments
TO authenticated;

CREATE POLICY media_card_assignments_authenticated_select
ON public.media_card_assignments
FOR SELECT
TO authenticated
USING (
  public.current_organization_member(
    media_card_assignments.organization_id
  ) IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          media_card_assignments.organization_id
      AND booking.id =
          media_card_assignments.booking_id
      AND public.has_permission(
            booking.organization_id,
            'media.card.assign',
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
-- Section F - Controlled media-card assignment RPC
-- =====================================================================

CREATE FUNCTION public.assign_media_card(
  p_booking_id uuid,
  p_media_card_id uuid,
  p_capture_device_id uuid
)
RETURNS public.media_card_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_lead public.booking_team_assignments;

  v_card public.media_cards;
  v_device public.capture_devices;

  v_active public.media_card_assignments;
  v_result public.media_card_assignments;

  v_actor uuid;
  v_state_count integer;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication boundary.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'assign_media_card: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_media_card_id IS NULL THEN
    RAISE EXCEPTION
      'assign_media_card: media_card_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_capture_device_id IS NULL THEN
    RAISE EXCEPTION
      'assign_media_card: capture_device_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'assign_media_card: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: authoritative booking.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_media_card: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active organization membership + narrow booking-scoped authority.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'assign_media_card: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'media.card.assign',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'assign_media_card: media.card.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'assign_media_card: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exactly one canonical journey state.
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
      'assign_media_card: booking must have exactly one current journey state'
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

  IF NOT FOUND
     OR v_stage.stage_order <> 10
     OR v_stage.stage_key <>
        'shoot_scheduled' THEN
    RAISE EXCEPTION
      'assign_media_card: booking must be at active Stage 10 shoot_scheduled'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: current canonical Lead Photographer assignment.
  --
  -- The current-lead partial unique index guarantees at most one
  -- active lead_photographer row for this booking.
  -- ---------------------------------------------------------------

  SELECT assignment.*
  INTO v_lead
  FROM public.booking_team_assignments assignment
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.assignment_role =
        'lead_photographer'
    AND assignment.ended_at IS NULL
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_media_card: current Lead Photographer required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- B1 does not create authenticated custody identity for an
  -- external creative. External current Lead Photographer is an
  -- explicit authorization rejection.
  -- ---------------------------------------------------------------

  IF v_lead.assigned_external_creative_id IS NOT NULL
     OR v_lead.assigned_member_id IS NULL THEN
    RAISE EXCEPTION
      'assign_media_card: external Lead Photographer cannot create authenticated media-card custody evidence'
      USING ERRCODE = '42501';
  END IF;

  IF v_lead.assigned_member_id
       IS DISTINCT FROM
     v_actor THEN
    RAISE EXCEPTION
      'assign_media_card: current internal Lead Photographer required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 4: registered media-card identity.
  --
  -- The physical card row is locked to serialize concurrent claims
  -- of the same card across bookings/devices.
  -- ---------------------------------------------------------------

  SELECT card.*
  INTO v_card
  FROM public.media_cards card
  WHERE card.organization_id =
        v_booking.organization_id
    AND card.id =
        p_media_card_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_media_card: registered media card unavailable in booking organization'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Registered capture-device identity.
  --
  -- Capture devices are immutable inventory identities. No exclusive
  -- device lock or uniqueness is imposed because one device may host
  -- multiple active media cards.
  -- ---------------------------------------------------------------

  SELECT device.*
  INTO v_device
  FROM public.capture_devices device
  WHERE device.organization_id =
        v_booking.organization_id
    AND device.id =
        p_capture_device_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'assign_media_card: registered capture device unavailable in booking organization'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Authorization-first replay / active-card collision resolution.
  --
  -- The card identity lock above serializes competing B1 requests.
  -- The partial unique index remains the database-level invariant.
  -- ---------------------------------------------------------------

  SELECT assignment.*
  INTO v_active
  FROM public.media_card_assignments assignment
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.media_card_id =
        v_card.id
    AND assignment.ended_at IS NULL
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    IF v_active.booking_id =
         v_booking.id
       AND v_active.capture_device_id =
           v_device.id
       AND v_active.lead_photographer_assignment_id =
           v_lead.id
       AND v_active.custodian_member_id =
           v_actor
       AND v_active.assigned_by =
           v_actor THEN
      RETURN v_active;
    END IF;

    RAISE EXCEPTION
      'assign_media_card: media card already has a different active assignment'
      USING ERRCODE = '23505';
  END IF;

  -- ---------------------------------------------------------------
  -- First canonical CUS-501 assignment.
  -- ---------------------------------------------------------------

  INSERT INTO public.media_card_assignments (
    organization_id,
    booking_id,
    media_card_id,
    capture_device_id,
    lead_photographer_assignment_id,
    custodian_member_id,
    assigned_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_card.id,
    v_device.id,
    v_lead.id,
    v_actor,
    v_actor
  )
  RETURNING *
  INTO v_result;

  -- ---------------------------------------------------------------
  -- First-success structural audit event only.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'media.card_assigned',
    'media_card_assignment',
    v_result.id,
    false,
    NULL,
    NULL,
    jsonb_build_object(
      'organization_id',
        v_booking.organization_id,
      'booking_id',
        v_booking.id,
      'media_card_assignment_id',
        v_result.id,
      'media_card_id',
        v_result.media_card_id,
      'capture_device_id',
        v_result.capture_device_id,
      'lead_photographer_assignment_id',
        v_result.lead_photographer_assignment_id,
      'custodian_member_id',
        v_result.custodian_member_id,
      'assigned_by',
        v_result.assigned_by
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$$;


-- =====================================================================
-- Section G - Assignment RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.assign_media_card(uuid,uuid,uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.assign_media_card(uuid,uuid,uuid)
FROM anon;

REVOKE ALL
ON FUNCTION public.assign_media_card(uuid,uuid,uuid)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.assign_media_card(uuid,uuid,uuid)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.assign_media_card(uuid,uuid,uuid)
TO authenticated;

COMMENT ON FUNCTION public.assign_media_card(uuid,uuid,uuid) IS
  'Assign or strictly replay one registered media card to one registered capture device for the authenticated current internal booking Lead Photographer at Stage 10 shoot_scheduled.';


-- =====================================================================
-- Section H - Migration assertions
-- =====================================================================

DO $media_card_assignment_assertions$
DECLARE
  v_count integer;
  v_roles text[];
  v_columns text[];
  v_definition text;
BEGIN
  -- ---------------------------------------------------------------
  -- Canonical relation and RPC.
  -- ---------------------------------------------------------------

  IF to_regclass(
       'public.media_card_assignments'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: public.media_card_assignments missing';
  END IF;

  IF to_regprocedure(
       'public.assign_media_card(uuid,uuid,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: assign_media_card(uuid,uuid,uuid) missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact permission / role topology.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key =
        'media.card.assign'
    AND permission.domain =
        'media'
    AND permission.label =
        'Assign media cards'
    AND permission.description =
        'Assign registered media cards to registered capture devices for the current booking Lead Photographer.'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: media.card.assign contract invalid';
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
        'media.card.assign';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'photographer'
       ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: media.card.assign role topology is %',
      v_roles;
  END IF;

  -- ---------------------------------------------------------------
  -- Exact eleven-column relation contract.
  -- ---------------------------------------------------------------

  SELECT array_agg(
           column_name || ':' || udt_name
           ORDER BY ordinal_position
         )
  INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'media_card_assignments';

  IF v_columns IS DISTINCT FROM
       ARRAY[
         'id:uuid',
         'organization_id:uuid',
         'booking_id:uuid',
         'media_card_id:uuid',
         'capture_device_id:uuid',
         'lead_photographer_assignment_id:uuid',
         'custodian_member_id:uuid',
         'assigned_at:timestamptz',
         'assigned_by:uuid',
         'ended_at:timestamptz',
         'ended_by:uuid'
       ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: media_card_assignments column contract is %',
      v_columns;
  END IF;

  -- ---------------------------------------------------------------
  -- Required structural constraints.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_constraint constraint_row
  WHERE constraint_row.conrelid =
        'public.media_card_assignments'::regclass
    AND constraint_row.conname IN (
      'media_card_assignments_lifecycle_chk',
      'media_card_assignments_end_time_chk',
      'media_card_assignments_initial_custodian_chk',
      'media_card_assignments_booking_fkey',
      'media_card_assignments_media_card_fkey',
      'media_card_assignments_capture_device_fkey',
      'media_card_assignments_lead_assignment_fkey',
      'media_card_assignments_custodian_fkey',
      'media_card_assignments_assigned_by_fkey',
      'media_card_assignments_ended_by_fkey',
      'media_card_assignments_id_org_booking_key'
    );

  IF v_count <> 11 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: required media_card_assignments constraints missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Exactly one active assignment per media card.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_indexes index_row
  WHERE index_row.schemaname =
        'public'
    AND index_row.tablename =
        'media_card_assignments'
    AND index_row.indexname =
        'media_card_assignments_active_card_uidx'
    AND index_row.indexdef ILIKE
        '%UNIQUE INDEX%'
    AND index_row.indexdef ILIKE
        '%organization_id%'
    AND index_row.indexdef ILIKE
        '%media_card_id%'
    AND index_row.indexdef ILIKE
        '%ended_at IS NULL%';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: active media-card uniqueness index invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Capture devices are intentionally non-exclusive.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_indexes index_row
  WHERE index_row.schemaname =
        'public'
    AND index_row.tablename =
        'media_card_assignments'
    AND index_row.indexdef ILIKE
        '%UNIQUE INDEX%'
    AND index_row.indexdef ILIKE
        '%capture_device_id%';

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: capture device must not have an active uniqueness constraint';
  END IF;

  -- ---------------------------------------------------------------
  -- B1 relation mutation guard.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_trigger trigger_row
  WHERE trigger_row.tgrelid =
        'public.media_card_assignments'::regclass
    AND trigger_row.tgname =
        'media_card_assignments_guard'
    AND NOT trigger_row.tgisinternal;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: media-card assignment mutation guard missing';
  END IF;

  -- ---------------------------------------------------------------
  -- RLS enabled and forced.
  -- ---------------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.media_card_assignments'::regclass
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: media_card_assignments RLS must be enabled and forced';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_policies policy
  WHERE policy.schemaname =
        'public'
    AND policy.tablename =
        'media_card_assignments'
    AND policy.policyname =
        'media_card_assignments_authenticated_select'
    AND policy.cmd =
        'SELECT'
    AND policy.qual ILIKE
        '%media.card.assign%'
    AND policy.qual NOT ILIKE
        '%booking.read%';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: authenticated B1 read policy invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Table ACL.
  -- ---------------------------------------------------------------

  IF NOT has_table_privilege(
           'authenticated',
           'public.media_card_assignments',
           'SELECT'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: authenticated SELECT grant missing';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.media_card_assignments',
       'INSERT'
     )
     OR has_table_privilege(
          'authenticated',
          'public.media_card_assignments',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.media_card_assignments',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: authenticated direct mutation privilege leaked';
  END IF;

  IF has_table_privilege(
       'anon',
       'public.media_card_assignments',
       'SELECT'
     )
     OR has_table_privilege(
          'anon',
          'public.media_card_assignments',
          'INSERT'
        )
     OR has_table_privilege(
          'anon',
          'public.media_card_assignments',
          'UPDATE'
        )
     OR has_table_privilege(
          'anon',
          'public.media_card_assignments',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: anon media_card_assignments privilege leaked';
  END IF;

  -- ---------------------------------------------------------------
  -- RPC security / authority / audit contract.
  -- ---------------------------------------------------------------

  SELECT pg_get_functiondef(
           'public.assign_media_card(uuid,uuid,uuid)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%SECURITY DEFINER%'
     OR v_definition NOT ILIKE
       '%SET search_path TO ''''%'
     OR v_definition NOT ILIKE
       '%media.card.assign%'
     OR v_definition NOT ILIKE
       '%stage_order <> 10%'
     OR v_definition NOT ILIKE
       '%shoot_scheduled%'
     OR v_definition NOT ILIKE
       '%assigned_external_creative_id%'
     OR v_definition NOT ILIKE
       '%media.card_assigned%' THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: assignment RPC security or authority contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.assign_media_card(uuid,uuid,uuid)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: authenticated RPC execute grant missing';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.assign_media_card(uuid,uuid,uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
          'service_role',
          'public.assign_media_card(uuid,uuid,uuid)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: unauthorized RPC execute privilege leaked';
  END IF;

  -- ---------------------------------------------------------------
  -- Final canonical authority totals.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 71 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: expected 71 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 246 THEN
    RAISE EXCEPTION
      'Corrective Slice B1 validation failed: expected 246 role-permission mappings, found %',
      v_count;
  END IF;
END
$media_card_assignment_assertions$;
