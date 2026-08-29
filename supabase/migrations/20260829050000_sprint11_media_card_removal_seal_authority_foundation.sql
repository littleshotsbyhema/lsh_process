-- =====================================================================
-- Phase 2 Studio Operations
-- Corrective Slice B2 - Media Card Removal / Shot Accounting / Seal
--
-- Frozen boundary:
--   * CUS-502 removal + CUS-503 write-protect/seal are atomic;
--   * one media.card.remove permission;
--   * photographer grant topology only;
--   * one canonical public.media_card_removals relation;
--   * current pinned B1 custodian only;
--   * first mutation at exact Stage 10 shoot_scheduled;
--   * strict authorized replay may survive later journey advancement;
--   * controlled B1 assignment closure through ended_at / ended_by;
--   * active assignments block first Stage 10 -> 11 advancement;
--   * no custody transfer, ingestion, checksum, backup, or release.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $media_card_removal_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass(
       'public.media_card_removals'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: public.media_card_removals already exists';
  END IF;

  IF to_regprocedure(
       'public.remove_and_seal_media_card(uuid,bigint,text,text)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: remove_and_seal_media_card(uuid,bigint,text,text) already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key =
          'media.card.remove'
  ) THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: media.card.remove already exists';
  END IF;

  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.bookings') IS NULL
     OR to_regclass('public.media_cards') IS NULL
     OR to_regclass('public.capture_devices') IS NULL
     OR to_regclass('public.media_card_assignments') IS NULL
     OR to_regclass('public.booking_journey_states') IS NULL
     OR to_regclass('public.booking_journey_stages') IS NULL
     OR to_regclass('public.booking_shoot_completions') IS NULL
     OR to_regclass('public.booking_shoot_schedules') IS NULL
     OR to_regclass('public.booking_stage_transitions') IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: required canonical relation missing';
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
          'public.assign_media_card(uuid,uuid,uuid)'
        ) IS NULL
     OR to_regprocedure(
          'public.mark_booking_shoot_completed(uuid)'
        ) IS NULL
     OR to_regprocedure(
          'public.lsh_media_card_assignment_guard()'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: required canonical function unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 71 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: expected 71 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 246 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: expected 246 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles role
  WHERE role.key =
        'photographer';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: expected exactly one photographer role, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'media_card_assignments';

  IF v_count <> 11 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: media_card_assignments must contain exactly eleven columns';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'media_card_assignments'
    AND column_name IN (
      'id',
      'organization_id',
      'booking_id',
      'media_card_id',
      'capture_device_id',
      'lead_photographer_assignment_id',
      'custodian_member_id',
      'assigned_at',
      'assigned_by',
      'ended_at',
      'ended_by'
    );

  IF v_count <> 11 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 precondition failed: canonical B1 media-card assignment contract unavailable';
  END IF;
END
$media_card_removal_preconditions$;

-- =====================================================================
-- Section B - Narrow removal / seal authority
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'media.card.remove',
  'media',
  'Remove and seal media cards',
  'Remove active media cards from capture devices, record expected file counts, and seal them while held by the current custodian.',
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
      'media.card.remove';


DO $media_card_removal_permission_assertions$
DECLARE
  v_permission_count integer;
  v_grant_count integer;
  v_photographer_grant_count integer;
BEGIN
  SELECT count(*)
  INTO v_permission_count
  FROM public.permissions permission
  WHERE permission.key =
        'media.card.remove'
    AND permission.domain =
        'media'
    AND permission.label =
        'Remove and seal media cards'
    AND permission.description =
        'Remove active media cards from capture devices, record expected file counts, and seal them while held by the current custodian.'
    AND permission.requires_server_enforcement;

  IF v_permission_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 permission assertion failed: media.card.remove contract mismatch';
  END IF;

  SELECT count(*)
  INTO v_grant_count
  FROM public.role_permissions grant_row
  JOIN public.permissions permission
    ON permission.id =
       grant_row.permission_id
  WHERE permission.key =
        'media.card.remove';

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
        'media.card.remove'
    AND role.key =
        'photographer';

  IF v_grant_count <> 1
     OR v_photographer_grant_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 permission assertion failed: media.card.remove must have exactly the photographer grant';
  END IF;
END
$media_card_removal_permission_assertions$;


-- =====================================================================
-- Section C - Canonical atomic removal / seal evidence
-- =====================================================================

CREATE TABLE public.media_card_removals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  media_card_assignment_id uuid NOT NULL,

  expected_file_count bigint NOT NULL,
  seal_id text NOT NULL,
  seal_condition text NOT NULL,

  removed_at timestamptz NOT NULL DEFAULT now(),
  removed_by uuid NOT NULL,

  CONSTRAINT media_card_removals_expected_file_count_chk
    CHECK (
      expected_file_count >= 0
    ),

  CONSTRAINT media_card_removals_seal_id_chk
    CHECK (
      seal_id = btrim(seal_id)
      AND seal_id <> ''
    ),

  CONSTRAINT media_card_removals_seal_condition_chk
    CHECK (
      seal_condition = btrim(seal_condition)
      AND seal_condition <> ''
    ),

  CONSTRAINT media_card_removals_assignment_fkey
    FOREIGN KEY (
      media_card_assignment_id,
      organization_id,
      booking_id
    )
    REFERENCES public.media_card_assignments (
      id,
      organization_id,
      booking_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_removals_removed_by_fkey
    FOREIGN KEY (
      removed_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_card_removals_assignment_key
    UNIQUE (
      media_card_assignment_id
    ),

  CONSTRAINT media_card_removals_org_seal_key
    UNIQUE (
      organization_id,
      seal_id
    ),

  CONSTRAINT media_card_removals_id_org_booking_key
    UNIQUE (
      id,
      organization_id,
      booking_id
    )
);

CREATE INDEX media_card_removals_org_booking_history_idx
ON public.media_card_removals (
  organization_id,
  booking_id,
  removed_at DESC
);

-- =====================================================================
-- Section D - Immutable B2 removal / seal evidence
-- =====================================================================

CREATE FUNCTION public.lsh_media_card_removal_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'media card removal evidence cannot be deleted';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'media card removal evidence is immutable';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER media_card_removals_guard
BEFORE UPDATE OR DELETE
ON public.media_card_removals
FOR EACH ROW
EXECUTE FUNCTION public.lsh_media_card_removal_guard();

REVOKE ALL
ON FUNCTION public.lsh_media_card_removal_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.lsh_media_card_removal_guard()
FROM anon;

REVOKE ALL
ON FUNCTION public.lsh_media_card_removal_guard()
FROM authenticated;

REVOKE ALL
ON FUNCTION public.lsh_media_card_removal_guard()
FROM service_role;


-- =====================================================================
-- Section E - Evolve B1 assignment guard for controlled closure only
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_media_card_assignment_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'media card assignment evidence cannot be deleted';
  END IF;

  IF TG_OP = 'INSERT' THEN
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
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.ended_at IS NULL
       AND OLD.ended_by IS NULL
       AND NEW.ended_at IS NOT NULL
       AND NEW.ended_by IS NOT NULL

       AND NEW.id IS NOT DISTINCT FROM OLD.id
       AND NEW.organization_id IS NOT DISTINCT FROM OLD.organization_id
       AND NEW.booking_id IS NOT DISTINCT FROM OLD.booking_id
       AND NEW.media_card_id IS NOT DISTINCT FROM OLD.media_card_id
       AND NEW.capture_device_id IS NOT DISTINCT FROM OLD.capture_device_id
       AND NEW.lead_photographer_assignment_id
             IS NOT DISTINCT FROM
           OLD.lead_photographer_assignment_id
       AND NEW.custodian_member_id
             IS NOT DISTINCT FROM
           OLD.custodian_member_id
       AND NEW.assigned_at IS NOT DISTINCT FROM OLD.assigned_at
       AND NEW.assigned_by IS NOT DISTINCT FROM OLD.assigned_by

       AND EXISTS (
         SELECT 1
         FROM public.media_card_removals removal
         WHERE removal.media_card_assignment_id =
               NEW.id
           AND removal.organization_id =
               NEW.organization_id
           AND removal.booking_id =
               NEW.booking_id
           AND removal.removed_at =
               NEW.ended_at
           AND removal.removed_by =
               NEW.ended_by
       ) THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION
      'media card assignment evidence is immutable except controlled removal closure';
  END IF;

  RETURN NEW;
END;
$$;

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
-- Section F - Forced RLS / authenticated read boundary
-- =====================================================================

ALTER TABLE public.media_card_removals
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.media_card_removals
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_removals
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_removals
FROM anon;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_removals
FROM authenticated;

REVOKE ALL PRIVILEGES
ON TABLE public.media_card_removals
FROM service_role;

GRANT SELECT
ON TABLE public.media_card_removals
TO authenticated;

CREATE POLICY media_card_removals_authenticated_select
ON public.media_card_removals
FOR SELECT
TO authenticated
USING (
  public.current_organization_member(
    media_card_removals.organization_id
  ) IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          media_card_removals.organization_id
      AND booking.id =
          media_card_removals.booking_id
      AND public.has_permission(
            booking.organization_id,
            'media.card.remove',
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
-- Section G - Controlled atomic removal / seal RPC
-- =====================================================================

CREATE FUNCTION public.remove_and_seal_media_card(
  p_media_card_assignment_id uuid,
  p_expected_file_count bigint,
  p_seal_id text,
  p_seal_condition text
)
RETURNS public.media_card_removals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_locator_organization_id uuid;
  v_locator_booking_id uuid;

  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_assignment public.media_card_assignments;
  v_existing public.media_card_removals;
  v_result public.media_card_removals;

  v_actor uuid;
  v_state_count integer;

  v_normalized_seal_id text;
  v_normalized_seal_condition text;

  v_removed_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication boundary.
  -- ---------------------------------------------------------------

  IF p_media_card_assignment_id IS NULL THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: media_card_assignment_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_expected_file_count IS NULL THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: expected_file_count is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_expected_file_count < 0 THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: expected_file_count must be non-negative'
      USING ERRCODE = '22023';
  END IF;

  IF p_seal_id IS NULL THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: seal_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_seal_condition IS NULL THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: seal_condition is required'
      USING ERRCODE = '22023';
  END IF;

  v_normalized_seal_id :=
    btrim(p_seal_id);

  v_normalized_seal_condition :=
    btrim(p_seal_condition);

  IF v_normalized_seal_id = '' THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: seal_id must be non-empty'
      USING ERRCODE = '22023';
  END IF;

  IF v_normalized_seal_condition = '' THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: seal_condition must be non-empty'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Locator read only.
  --
  -- This non-locking read exists only to derive the authoritative
  -- organization / booking synchronization root. The assignment is
  -- locked and revalidated after the booking and journey-state locks.
  -- ---------------------------------------------------------------

  SELECT
    assignment.organization_id,
    assignment.booking_id
  INTO
    v_locator_organization_id,
    v_locator_booking_id
  FROM public.media_card_assignments assignment
  WHERE assignment.id =
        p_media_card_assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: media card assignment not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: authoritative booking.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.organization_id =
        v_locator_organization_id
    AND booking.id =
        v_locator_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: assignment booking unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Active organization membership + narrow branch authority.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'media.card.remove',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: media.card.remove permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: booking branch scope required'
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
      'remove_and_seal_media_card: booking must have exactly one current journey state'
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
      'remove_and_seal_media_card: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: exact B1 assignment.
  -- ---------------------------------------------------------------

  SELECT assignment.*
  INTO v_assignment
  FROM public.media_card_assignments assignment
  WHERE assignment.id =
        p_media_card_assignment_id
    AND assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: media card assignment changed during removal'
      USING ERRCODE = '40001';
  END IF;

  IF v_assignment.custodian_member_id
       IS DISTINCT FROM
     v_actor THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: current media card custodian required'
      USING ERRCODE = '42501';
  END IF;

    -- ---------------------------------------------------------------
  -- Authorization-first exact replay.
  -- ---------------------------------------------------------------

  SELECT removal.*
  INTO v_existing
  FROM public.media_card_removals removal
  WHERE removal.media_card_assignment_id =
        v_assignment.id;

  IF FOUND THEN
    IF v_existing.organization_id =
         v_assignment.organization_id
       AND v_existing.booking_id =
         v_assignment.booking_id
       AND v_existing.expected_file_count =
         p_expected_file_count
       AND v_existing.seal_id =
         v_normalized_seal_id
       AND v_existing.seal_condition =
         v_normalized_seal_condition
       AND v_existing.removed_by =
         v_actor
       AND v_assignment.ended_at =
         v_existing.removed_at
       AND v_assignment.ended_by =
         v_existing.removed_by THEN
      RETURN v_existing;
    END IF;

    RAISE EXCEPTION
      'remove_and_seal_media_card: existing removal evidence does not match replay'
      USING ERRCODE = '23505';
  END IF;

  -- ---------------------------------------------------------------
  -- First success must occur at exact active Stage 10.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order <> 10
     OR v_stage.stage_key <>
          'shoot_scheduled' THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: booking must be at active Stage 10 shoot_scheduled'
      USING ERRCODE = '22023';
  END IF;

  IF v_assignment.ended_at IS NOT NULL
     OR v_assignment.ended_by IS NOT NULL THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: media card assignment is already closed'
      USING ERRCODE = '23505';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.media_card_removals removal
    WHERE removal.organization_id =
          v_assignment.organization_id
      AND removal.seal_id =
          v_normalized_seal_id
  ) THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: seal_id already used in organization'
      USING ERRCODE = '23505';
  END IF;

  -- ---------------------------------------------------------------
  -- Atomic removal evidence + B1 lifecycle closure.
  -- ---------------------------------------------------------------

  v_removed_at := now();

  INSERT INTO public.media_card_removals (
    organization_id,
    booking_id,
    media_card_assignment_id,
    expected_file_count,
    seal_id,
    seal_condition,
    removed_at,
    removed_by
  )
  VALUES (
    v_assignment.organization_id,
    v_assignment.booking_id,
    v_assignment.id,
    p_expected_file_count,
    v_normalized_seal_id,
    v_normalized_seal_condition,
    v_removed_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  UPDATE public.media_card_assignments assignment
  SET
    ended_at =
      v_removed_at,
    ended_by =
      v_actor
  WHERE assignment.id =
        v_assignment.id
    AND assignment.organization_id =
        v_assignment.organization_id
    AND assignment.booking_id =
        v_assignment.booking_id
    AND assignment.ended_at IS NULL
    AND assignment.ended_by IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'remove_and_seal_media_card: media card assignment closure failed'
      USING ERRCODE = '40001';
  END IF;

    -- ---------------------------------------------------------------
  -- One structural non-sensitive audit event.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'media.card_removed_and_sealed',
    'media_card_removal',
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
        v_assignment.id,
      'media_card_removal_id',
        v_result.id,
      'media_card_id',
        v_assignment.media_card_id,
      'capture_device_id',
        v_assignment.capture_device_id,
      'custodian_member_id',
        v_assignment.custodian_member_id,
      'removed_by',
        v_actor
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$$;

REVOKE ALL
ON FUNCTION public.remove_and_seal_media_card(uuid,bigint,text,text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.remove_and_seal_media_card(uuid,bigint,text,text)
FROM anon;

REVOKE ALL
ON FUNCTION public.remove_and_seal_media_card(uuid,bigint,text,text)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.remove_and_seal_media_card(uuid,bigint,text,text)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.remove_and_seal_media_card(uuid,bigint,text,text)
TO authenticated;

COMMENT ON FUNCTION public.remove_and_seal_media_card(uuid,bigint,text,text) IS
  'Atomically record CUS-502 media-card removal and CUS-503 write-protect/seal evidence for the current pinned B1 custodian at Stage 10.';

  -- =====================================================================
-- Section H - Harden Stage 10 -> 11 against active media-card custody
-- =====================================================================

CREATE OR REPLACE FUNCTION public.mark_booking_shoot_completed(
  p_booking_id uuid
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_completion public.booking_shoot_completions;
  v_schedule public.booking_shoot_schedules;

  v_actor uuid;

  v_state_count integer := 0;
  v_completion_count integer := 0;
  v_replay_transition_count integer := 0;
  v_updated_count integer := 0;



  v_completed_stage_id uuid;
  v_transitioned_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: booking synchronization root.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active member + canonical journey-advancement capability.
  -- shoot.complete is deliberately not required here.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking branch scope required'
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
      'mark_booking_shoot_completed: booking must have exactly one current journey state'
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
      'mark_booking_shoot_completed: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Strict canonical Stage 11 replay.
  --
  -- Replay consumes immutable completion evidence and exact transition
  -- history only. It does not introduce a custody mutation.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order = 11
     AND v_stage.stage_key = 'shoot_completed' THEN

    SELECT count(*)
    INTO v_completion_count
    FROM public.booking_shoot_completions completion
    WHERE completion.organization_id =
          v_booking.organization_id
      AND completion.booking_id =
          v_booking.id;

    IF v_completion_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_shoot_completed: Shoot Completed replay requires exactly one canonical completion row'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT completion.*
    INTO v_completion
    FROM public.booking_shoot_completions completion
    WHERE completion.organization_id =
          v_booking.organization_id
      AND completion.booking_id =
          v_booking.id
    FOR UPDATE;

    SELECT count(*)
    INTO v_replay_transition_count
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
          'shoot_completed'
      AND source_stage.stage_order = 10
      AND source_stage.stage_key =
          'shoot_scheduled'
      AND destination_stage.stage_order = 11
      AND destination_stage.stage_key =
          'shoot_completed';

    IF v_replay_transition_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_shoot_completed: Shoot Completed replay history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  -- ---------------------------------------------------------------
  -- First advancement must start at exact canonical Stage 10.
  -- ---------------------------------------------------------------

  IF v_stage.stage_order <> 10
     OR v_stage.stage_key <>
          'shoot_scheduled' THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: booking must be exactly Shoot Scheduled'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: active media-card custody must be fully closed.
  -- ---------------------------------------------------------------

  PERFORM 1
  FROM public.media_card_assignments assignment
  WHERE assignment.organization_id =
        v_booking.organization_id
    AND assignment.booking_id =
        v_booking.id
    AND assignment.ended_at IS NULL
  ORDER BY
    assignment.assigned_at,
    assignment.id
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: all media card assignments must be removed and sealed'
      USING ERRCODE = '22023';
  END IF;

    -- ---------------------------------------------------------------
  -- Lock order 4: exactly one immutable Slice 1 completion row.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_completion_count
  FROM public.booking_shoot_completions completion
  WHERE completion.organization_id =
        v_booking.organization_id
    AND completion.booking_id =
        v_booking.id;

  IF v_completion_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: exactly one canonical shoot completion row required'
      USING ERRCODE = '22023';
  END IF;

  SELECT completion.*
  INTO v_completion
  FROM public.booking_shoot_completions completion
  WHERE completion.organization_id =
        v_booking.organization_id
    AND completion.booking_id =
        v_booking.id
  FOR UPDATE;

  -- ---------------------------------------------------------------
  -- Lock order 5: stable authoritative schedule tip.
  -- ---------------------------------------------------------------

  SELECT schedule.*
  INTO v_schedule
  FROM public.booking_shoot_schedules schedule
  WHERE schedule.organization_id =
        v_booking.organization_id
    AND schedule.booking_id =
        v_booking.id
  ORDER BY
    schedule.schedule_version DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND
     OR v_schedule.schedule_state <>
          'reserved' THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: current authoritative reserved shoot schedule required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve explicit canonical Stage 11 destination.
  -- ---------------------------------------------------------------

  SELECT stage.id
  INTO v_completed_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.stage_order = 11
    AND stage.stage_key =
        'shoot_completed'
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: canonical Shoot Completed stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Append canonical transition before current-state mutation.
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
    v_state.current_stage_id,
    v_completed_stage_id,
    'shoot_completed',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Optimistic exact-state/version advancement.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_completed_stage_id,
    stage_entered_at =
      v_transitioned_at,
    version =
      state.version + 1,
    updated_at =
      v_transitioned_at,
    updated_by =
      v_actor
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id
    AND state.current_stage_id =
        v_state.current_stage_id
    AND state.version =
        v_state.version;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  IF v_updated_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_shoot_completed: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- Existing structural non-sensitive audit event.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.shoot_completed',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage',
        v_stage.stage_key,
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'shoot_completed',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'completion_id',
        v_completion.id,
      'completed_at',
        v_completion.completed_at,
      'transition_key',
        'shoot_completed',
      'prior_journey_version',
        v_state.version,
      'resulting_journey_version',
        v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$$;


-- =====================================================================
-- Stage 10 -> 11 RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM anon;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.mark_booking_shoot_completed(uuid)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.mark_booking_shoot_completed(uuid)
TO authenticated;

COMMENT ON FUNCTION public.mark_booking_shoot_completed(uuid) IS
  'Advance one authorized booking from canonical Stage 10 Shoot Scheduled to Stage 11 Shoot Completed only after immutable canonical shoot-completion evidence exists and all active media-card assignments are removed and sealed.';

  -- =====================================================================
-- Section I - Migration assertions
-- =====================================================================

DO $media_card_removal_final_assertions$
DECLARE
  v_count integer;
  v_definition text;
  v_columns text[];
BEGIN
  -- ---------------------------------------------------------------
  -- Canonical authority totals.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 72 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: expected 72 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 247 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: expected 247 role-permission mappings, found %',
      v_count;
  END IF;

  -- ---------------------------------------------------------------
  -- Exact nine-column evidence contract.
  -- ---------------------------------------------------------------

  SELECT array_agg(
           column_name
           ORDER BY ordinal_position
         )
  INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'media_card_removals';

  IF v_columns IS DISTINCT FROM ARRAY[
       'id',
       'organization_id',
       'booking_id',
       'media_card_assignment_id',
       'expected_file_count',
       'seal_id',
       'seal_condition',
       'removed_at',
       'removed_by'
     ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: media_card_removals exact nine-column contract invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Removal / seal RPC security and identity contract.
  -- ---------------------------------------------------------------

  IF to_regprocedure(
       'public.remove_and_seal_media_card(uuid,bigint,text,text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: removal/seal RPC unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc procedure
  JOIN pg_namespace namespace
    ON namespace.oid =
       procedure.pronamespace
  WHERE namespace.nspname =
        'public'
    AND procedure.proname =
        'remove_and_seal_media_card'
    AND pg_get_function_identity_arguments(
          procedure.oid
        ) =
        'p_media_card_assignment_id uuid, p_expected_file_count bigint, p_seal_id text, p_seal_condition text'
    AND pg_get_function_result(
          procedure.oid
        ) =
        'media_card_removals'
    AND procedure.prosecdef
    AND procedure.proconfig =
        ARRAY['search_path=""']::text[];

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: removal/seal RPC signature/security contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.remove_and_seal_media_card(uuid,bigint,text,text)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: authenticated removal/seal EXECUTE unavailable';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.remove_and_seal_media_card(uuid,bigint,text,text)',
       'EXECUTE'
     )
     OR has_function_privilege(
          'service_role',
          'public.remove_and_seal_media_card(uuid,bigint,text,text)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: non-authenticated removal/seal EXECUTE must be denied';
  END IF;

  -- ---------------------------------------------------------------
  -- Direct table mutation must remain unavailable.
  -- ---------------------------------------------------------------

  IF NOT has_table_privilege(
           'authenticated',
           'public.media_card_removals',
           'SELECT'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: authenticated removal evidence SELECT unavailable';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.media_card_removals',
       'INSERT'
     )
     OR has_table_privilege(
          'authenticated',
          'public.media_card_removals',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.media_card_removals',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: authenticated direct removal mutation must be denied';
  END IF;

  -- ---------------------------------------------------------------
  -- Forced-RLS contract.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_class relation
  JOIN pg_namespace namespace
    ON namespace.oid =
       relation.relnamespace
  WHERE namespace.nspname =
        'public'
    AND relation.relname =
        'media_card_removals'
    AND relation.relrowsecurity
    AND relation.relforcerowsecurity;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: media_card_removals RLS contract invalid';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_policies policy
  WHERE policy.schemaname =
        'public'
    AND policy.tablename =
        'media_card_removals'
    AND policy.policyname =
        'media_card_removals_authenticated_select'
    AND policy.cmd =
        'SELECT';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: authenticated removal evidence SELECT policy invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Immutable evidence guard.
  -- ---------------------------------------------------------------

  IF to_regprocedure(
       'public.lsh_media_card_removal_guard()'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: removal evidence guard unavailable';
  END IF;

  SELECT pg_get_functiondef(
           'public.lsh_media_card_removal_guard()'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%media card removal evidence cannot be deleted%'
     OR v_definition NOT ILIKE
       '%media card removal evidence is immutable%' THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: removal evidence immutability guard invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Controlled B1 closure seam.
  -- ---------------------------------------------------------------

  SELECT pg_get_functiondef(
           'public.lsh_media_card_assignment_guard()'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%public.media_card_removals%'
     OR v_definition NOT ILIKE
       '%controlled removal closure%'
     OR v_definition NOT ILIKE
       '%media card assignment evidence cannot be deleted%' THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: evolved assignment closure guard unavailable';
  END IF;

  -- ---------------------------------------------------------------
  -- Hardened Stage 10 -> 11 custody gate.
  -- ---------------------------------------------------------------

  SELECT pg_get_functiondef(
           'public.mark_booking_shoot_completed(uuid)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%public.media_card_assignments%'
     OR v_definition NOT ILIKE
       '%all media card assignments must be removed and sealed%'
     OR v_definition NOT ILIKE
       '%shoot_completed%' THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: Stage 10 -> 11 media-card closure gate unavailable';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact corrective permission topology.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions grant_row
  JOIN public.permissions permission
    ON permission.id =
       grant_row.permission_id
  JOIN public.roles role
    ON role.id =
       grant_row.role_id
  WHERE permission.key =
        'media.card.remove'
    AND role.key =
        'photographer';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: photographer media.card.remove grant unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions grant_row
  JOIN public.permissions permission
    ON permission.id =
       grant_row.permission_id
  JOIN public.roles role
    ON role.id =
       grant_row.role_id
  WHERE permission.key =
        'media.card.remove'
    AND role.key <>
        'photographer';

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Corrective Slice B2 validation failed: media.card.remove granted outside photographer role';
  END IF;
END
$media_card_removal_final_assertions$;