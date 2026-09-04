-- =====================================================================
-- Sprint 13 — Editing Pending
-- Canonical finalized-selection evidence + Stage 12 -> 13 gate
--
-- Boundary:
--   * one narrow selection.confirm permission;
--   * immutable booking_selection_completions evidence;
--   * immutable booking_selected_images manifest;
--   * controlled record_booking_selection_completion(...) RPC;
--   * controlled mark_booking_editing_pending(uuid) RPC;
--   * authenticated read containment through canonical booking access;
--   * exact Stage 12 -> 13 advancement only;
--   * strict replay/idempotency;
--   * no Stage 13 -> 14 implementation;
--   * no editing, QC, delivery or provider integration.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s13_preconditions$
DECLARE
  v_count integer;
  v_expected_role_permission_count integer;
BEGIN
  IF to_regclass('public.booking_selection_completions') IS NOT NULL
     OR to_regclass('public.booking_selected_images') IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 13 precondition failed: selection evidence relation already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_selection_completion(uuid,text[],text,text)'
     ) IS NOT NULL
     OR to_regprocedure(
       'public.mark_booking_editing_pending(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 13 precondition failed: Sprint 13 mutation RPC already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key = 'selection.confirm'
  ) THEN
    RAISE EXCEPTION
      'Sprint 13 precondition failed: selection.confirm already exists';
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
      'Sprint 13 precondition failed: required canonical relation missing';
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
      'Sprint 13 precondition failed: required canonical helper unavailable';
  END IF;

  -- Chronology compatibility:
  --
  -- Clean repository replay reaches Sprint 13 before Migration A:
  --   233 -> Sprint 13 -> 236.
  --
  -- An environment where Migration A is already recorded reaches
  -- Sprint 13 after Migration A:
  --   257 -> Sprint 13 -> 260.
  --
  -- The two Migration A constitutional relations are transactionally
  -- created together. A one-sided presence is treated as schema drift.
  IF to_regclass('public.role_scope_policies') IS NULL
     AND to_regclass('public.organization_brand_owners') IS NULL THEN

    v_expected_role_permission_count := 233;

  ELSIF to_regclass('public.role_scope_policies') IS NOT NULL
        AND to_regclass('public.organization_brand_owners') IS NOT NULL THEN

    v_expected_role_permission_count := 257;

  ELSE
    RAISE EXCEPTION
      'Sprint 13 precondition failed: Migration A constitutional foundation is partially present';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> v_expected_role_permission_count THEN
    RAISE EXCEPTION
      'Sprint 13 precondition failed: expected canonical role-permission count %, found %',
      v_expected_role_permission_count,
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles role
  WHERE role.key IN (
    'founder',
    'studio_manager',
    'client_coordinator'
  );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 13 precondition failed: required selection-confirmation roles unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id = role_permission.permission_id
  JOIN public.roles role
    ON role.id = role_permission.role_id
  WHERE permission.key = 'booking.stage.advance'
    AND role.key IN (
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 13 precondition failed: canonical booking.stage.advance role boundary unavailable';
  END IF;
END
$s13_preconditions$;

-- =====================================================================
-- Section B — Narrow finalized-selection permission
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'selection.confirm',
  'bookings',
  'Confirm final selection',
  'Record immutable canonical evidence that a booking client image selection is finalized.',
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
    'client_coordinator'
  )
  AND permission.key = 'selection.confirm';

-- =====================================================================
-- Section C1 — Canonical immutable selection-completion evidence
-- =====================================================================

CREATE TABLE public.booking_selection_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  completed_at timestamptz NOT NULL,
  source_type text NOT NULL,
  external_reference text,

  recorded_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  CONSTRAINT booking_selection_completions_source_type_chk
    CHECK (
      source_type = btrim(source_type)
      AND source_type <> ''
      AND char_length(source_type) <= 64
      AND source_type !~ '[[:cntrl:]]'
    ),

  CONSTRAINT booking_selection_completions_external_reference_chk
    CHECK (
      external_reference IS NULL
      OR (
        external_reference = btrim(external_reference)
        AND external_reference <> ''
        AND char_length(external_reference) <= 255
        AND external_reference !~ '[[:cntrl:]]'
        AND external_reference !~ '://'
        AND external_reference !~* '^(https?|ftp):'
        AND external_reference !~* 'www\.'
        AND external_reference !~ '[?#]'
        AND external_reference !~* '^(bearer|basic)[[:space:]]+'
        AND external_reference !~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
        AND external_reference !~* '^(token|secret|password|passwd|api[_-]?key|access[_-]?token|signature|sig)[[:space:]_:/=-]'
        AND external_reference !~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig|x-amz-[a-z0-9_-]+)[[:space:]]*[:=]'
      )
    ),

  CONSTRAINT booking_selection_completions_booking_fkey
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

  CONSTRAINT booking_selection_completions_recorded_by_fkey
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

  CONSTRAINT booking_selection_completions_created_by_fkey
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

  CONSTRAINT booking_selection_completions_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    ),

  CONSTRAINT booking_selection_completions_id_booking_key
    UNIQUE (
      id,
      booking_id
    )
);

CREATE INDEX booking_selection_completions_org_completed_idx
ON public.booking_selection_completions (
  organization_id,
  completed_at DESC
);

-- =====================================================================
-- Section C2 — Immutable selected-image manifest
-- =====================================================================

CREATE TABLE public.booking_selected_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  selection_completion_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  image_key text NOT NULL,
  ordinal integer,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT booking_selected_images_image_key_chk
    CHECK (
      image_key = btrim(image_key)
      AND image_key <> ''
      AND char_length(image_key) <= 255
      AND image_key !~ '[[:cntrl:]]'
      AND image_key !~ '://'
      AND image_key !~* '^(https?://|www\.)'
      AND image_key !~ '[?&=]'
      AND image_key !~* '^(bearer[[:space:]]+|sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
      AND image_key !~* '^(token|secret|password|passwd|api[_-]?key|access[_-]?token)[[:space:]_:/-]'
    ),

  CONSTRAINT booking_selected_images_ordinal_chk
    CHECK (
      ordinal IS NULL
      OR ordinal >= 1
    ),

  CONSTRAINT booking_selected_images_booking_fkey
    FOREIGN KEY (booking_id)
    REFERENCES public.bookings (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_selected_images_completion_booking_fkey
    FOREIGN KEY (
      selection_completion_id,
      booking_id
    )
    REFERENCES public.booking_selection_completions (
      id,
      booking_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_selected_images_completion_image_key
    UNIQUE (
      selection_completion_id,
      image_key
    )
);

CREATE INDEX booking_selected_images_booking_ordinal_idx
ON public.booking_selected_images (
  booking_id,
  ordinal,
  id
);

-- =====================================================================
-- Section C3 — Immutable evidence guards
-- =====================================================================

CREATE FUNCTION public.lsh_booking_selection_completion_guard()
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
      'booking selection completion evidence is immutable';
  END IF;

  IF NEW.recorded_by IS NULL
     OR NEW.created_by IS NULL
     OR NEW.completed_at IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking selection completion evidence requires complete immutable attribution';
  END IF;

  IF NEW.recorded_by IS DISTINCT FROM NEW.created_by THEN
    RAISE EXCEPTION
      'booking selection completion recorded_by and created_by must match';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking selection completion actor must be the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_selection_completions_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_selection_completions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_selection_completion_guard();

CREATE FUNCTION public.lsh_booking_selected_image_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking selected-image evidence is immutable';
  END IF;

  IF NEW.selection_completion_id IS NULL
     OR NEW.booking_id IS NULL
     OR NEW.image_key IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'booking selected-image evidence requires complete immutable attribution';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_selected_images_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_selected_images
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_selected_image_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_selection_completion_guard()
FROM PUBLIC;
REVOKE ALL
ON FUNCTION public.lsh_booking_selection_completion_guard()
FROM anon;
REVOKE ALL
ON FUNCTION public.lsh_booking_selection_completion_guard()
FROM authenticated;
REVOKE ALL
ON FUNCTION public.lsh_booking_selection_completion_guard()
FROM service_role;

REVOKE ALL
ON FUNCTION public.lsh_booking_selected_image_guard()
FROM PUBLIC;
REVOKE ALL
ON FUNCTION public.lsh_booking_selected_image_guard()
FROM anon;
REVOKE ALL
ON FUNCTION public.lsh_booking_selected_image_guard()
FROM authenticated;
REVOKE ALL
ON FUNCTION public.lsh_booking_selected_image_guard()
FROM service_role;

-- =====================================================================
-- Section C4 — Forced RLS / authenticated SELECT-only boundary
-- =====================================================================

ALTER TABLE public.booking_selection_completions
ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_selection_completions
FORCE ROW LEVEL SECURITY;

ALTER TABLE public.booking_selected_images
ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_selected_images
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_completions
FROM PUBLIC;
REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_completions
FROM anon;
REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_completions
FROM authenticated;
REVOKE ALL PRIVILEGES
ON TABLE public.booking_selection_completions
FROM service_role;

REVOKE ALL PRIVILEGES
ON TABLE public.booking_selected_images
FROM PUBLIC;
REVOKE ALL PRIVILEGES
ON TABLE public.booking_selected_images
FROM anon;
REVOKE ALL PRIVILEGES
ON TABLE public.booking_selected_images
FROM authenticated;
REVOKE ALL PRIVILEGES
ON TABLE public.booking_selected_images
FROM service_role;

GRANT SELECT
ON TABLE public.booking_selection_completions
TO authenticated;

GRANT SELECT
ON TABLE public.booking_selected_images
TO authenticated;

CREATE POLICY booking_selection_completions_authenticated_select
ON public.booking_selection_completions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_selection_completions.organization_id
      AND booking.id =
          booking_selection_completions.booking_id
      AND public.has_permission(
            booking.organization_id,
            'booking.read',
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

CREATE POLICY booking_selected_images_authenticated_select
ON public.booking_selected_images
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.id =
          booking_selected_images.booking_id
      AND public.has_permission(
            booking.organization_id,
            'booking.read',
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
-- Section D — Controlled finalized-selection recording RPC
-- =====================================================================

CREATE FUNCTION public.record_booking_selection_completion(
  p_booking_id uuid,
  p_selected_image_keys text[],
  p_source_type text,
  p_external_reference text DEFAULT NULL
)
RETURNS public.booking_selection_completions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_existing public.booking_selection_completions;
  v_result public.booking_selection_completions;

  v_actor uuid;
  v_completed_at timestamptz;
  v_source_type text;
  v_external_reference text;

  v_state_count integer := 0;
  v_selection_pending_transition_count integer := 0;
  v_existing_count integer := 0;
  v_manifest_count integer := 0;

  v_normalized_keys text[];
  v_existing_keys text[];
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'selection.confirm',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: selection.confirm permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  IF p_selected_image_keys IS NULL
     OR cardinality(p_selected_image_keys) < 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: at least one selected image key is required'
      USING ERRCODE = '22023';
  END IF;

  IF cardinality(p_selected_image_keys) > 500 THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: selected image manifest exceeds maximum of 500'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_selected_image_keys) AS image_key(value)
    WHERE value IS NULL
       OR btrim(value) = ''
  ) THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: selected image keys must be non-empty'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_selected_image_keys) AS image_key(value)
    WHERE char_length(btrim(value)) > 255
  ) THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: selected image key exceeds maximum length of 255'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_selected_image_keys) AS image_key(value)
    WHERE btrim(value) ~ '[[:cntrl:]]'
       OR btrim(value) ~ '://'
       OR btrim(value) ~* '^(https?://|www\.)'
       OR btrim(value) ~ '[?&=]'
       OR btrim(value) ~* '^(bearer[[:space:]]+|sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR btrim(value) ~* '^(token|secret|password|passwd|api[_-]?key|access[_-]?token)[[:space:]_:/-]'
  ) THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: selected image keys must be opaque operational identifiers'
      USING ERRCODE = '22023';
  END IF;

  SELECT array_agg(normalized_key ORDER BY normalized_key)
  INTO v_normalized_keys
  FROM (
    SELECT btrim(value) AS normalized_key
    FROM unnest(p_selected_image_keys) AS image_key(value)
  ) normalized;

  SELECT count(DISTINCT btrim(value))
  INTO v_manifest_count
  FROM unnest(p_selected_image_keys) AS image_key(value);

  IF v_manifest_count <> cardinality(p_selected_image_keys) THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: duplicate selected image keys are not allowed'
      USING ERRCODE = '22023';
  END IF;

  v_source_type := btrim(p_source_type);

  IF v_source_type IS NULL
     OR v_source_type = '' THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: source_type is required'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(v_source_type) > 64 THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: source_type exceeds maximum length of 64'
      USING ERRCODE = '22023';
  END IF;

  IF v_source_type ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: source_type contains control characters'
      USING ERRCODE = '22023';
  END IF;

  v_external_reference :=
    NULLIF(btrim(p_external_reference), '');

  IF v_external_reference IS NOT NULL
     AND char_length(v_external_reference) > 255 THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: external_reference exceeds maximum length of 255'
      USING ERRCODE = '22023';
  END IF;

  IF v_external_reference IS NOT NULL
     AND (
       v_external_reference ~ '[[:cntrl:]]'
       OR v_external_reference ~ '://'
       OR v_external_reference ~* '^(https?|ftp):'
       OR v_external_reference ~* 'www\.'
       OR v_external_reference ~ '[?#]'
       OR v_external_reference ~* '^(bearer|basic)[[:space:]]+'
       OR v_external_reference ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_external_reference ~* '^(token|secret|password|passwd|api[_-]?key|access[_-]?token|signature|sig)[[:space:]_:/=-]'
       OR v_external_reference ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig|x-amz-[a-z0-9_-]+)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: external_reference must be a non-secret opaque operational reference'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.*
  INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND
     OR v_stage.stage_order <> 12
     OR v_stage.stage_key <> 'selection_pending' THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: booking must be exactly Selection Pending'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*)
  INTO v_selection_pending_transition_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id = transition_row.organization_id
   AND source_stage.id = transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND transition_row.transition_key = 'selection_pending'
    AND source_stage.stage_order = 11
    AND source_stage.stage_key = 'shoot_completed'
    AND destination_stage.stage_order = 12
    AND destination_stage.stage_key = 'selection_pending';

  IF v_selection_pending_transition_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: canonical Selection Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)
  INTO v_existing_count
  FROM public.booking_selection_completions completion
  WHERE completion.organization_id = v_booking.organization_id
    AND completion.booking_id = v_booking.id;

  IF v_existing_count > 1 THEN
    RAISE EXCEPTION
      'record_booking_selection_completion: canonical selection completion cardinality is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_existing_count = 1 THEN
    SELECT completion.*
    INTO v_existing
    FROM public.booking_selection_completions completion
    WHERE completion.organization_id = v_booking.organization_id
      AND completion.booking_id = v_booking.id
    FOR UPDATE;

    SELECT array_agg(selected.image_key ORDER BY selected.image_key)
    INTO v_existing_keys
    FROM public.booking_selected_images selected
    WHERE selected.selection_completion_id = v_existing.id
      AND selected.booking_id = v_booking.id;

    IF v_existing.source_type IS DISTINCT FROM v_source_type
       OR v_existing.external_reference IS DISTINCT FROM v_external_reference
       OR v_existing_keys IS DISTINCT FROM v_normalized_keys THEN
      RAISE EXCEPTION
        'record_booking_selection_completion: conflicting finalized-selection replay'
        USING ERRCODE = '23505';
    END IF;

    RETURN v_existing;
  END IF;

  v_completed_at := now();

  INSERT INTO public.booking_selection_completions (
    organization_id,
    booking_id,
    completed_at,
    source_type,
    external_reference,
    recorded_by,
    created_at,
    created_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_completed_at,
    v_source_type,
    v_external_reference,
    v_actor,
    v_completed_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  INSERT INTO public.booking_selected_images (
    selection_completion_id,
    booking_id,
    image_key,
    ordinal,
    created_at
  )
  SELECT
    v_result.id,
    v_booking.id,
    btrim(image_key.value),
    image_key.ordinality::integer,
    v_completed_at
  FROM unnest(p_selected_image_keys)
       WITH ORDINALITY AS image_key(value, ordinality)
  ORDER BY image_key.ordinality;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.selection_completed',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'selection_completed', false
    ),
    jsonb_build_object(
      'selection_completed', true,
      'selected_image_count', cardinality(v_normalized_keys)
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'selection_completion_id', v_result.id,
      'selected_image_count', cardinality(v_normalized_keys),
      'completed_at', v_completed_at
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$$;

REVOKE ALL
ON FUNCTION public.record_booking_selection_completion(uuid,text[],text,text)
FROM PUBLIC;
REVOKE ALL
ON FUNCTION public.record_booking_selection_completion(uuid,text[],text,text)
FROM anon;
REVOKE ALL
ON FUNCTION public.record_booking_selection_completion(uuid,text[],text,text)
FROM service_role;
GRANT EXECUTE
ON FUNCTION public.record_booking_selection_completion(uuid,text[],text,text)
TO authenticated;

-- =====================================================================
-- Section E — Controlled Stage 12 -> 13 / editing_pending gate
-- =====================================================================

CREATE FUNCTION public.mark_booking_editing_pending(
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
  v_completion public.booking_selection_completions;

  v_actor uuid;

  v_state_count integer := 0;
  v_completion_count integer := 0;
  v_manifest_count integer := 0;
  v_manifest_distinct_count integer := 0;
  v_selection_pending_transition_count integer := 0;
  v_editing_pending_transition_count integer := 0;
  v_updated_count integer := 0;

  v_editing_pending_stage_id uuid;
  v_transitioned_at timestamptz;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.*
  INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (
      v_stage.stage_order = 12
      AND v_stage.stage_key = 'selection_pending'
    )
    OR
    (
      v_stage.stage_order = 13
      AND v_stage.stage_key = 'editing_pending'
    )
  ) THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking must be exactly Selection Pending or Editing Pending replay'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*)
  INTO v_completion_count
  FROM public.booking_selection_completions completion
  WHERE completion.organization_id = v_booking.organization_id
    AND completion.booking_id = v_booking.id;

  IF v_completion_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: exactly one canonical selection completion row required'
      USING ERRCODE = '22023';
  END IF;

  SELECT completion.*
  INTO v_completion
  FROM public.booking_selection_completions completion
  WHERE completion.organization_id = v_booking.organization_id
    AND completion.booking_id = v_booking.id
  FOR UPDATE;

  SELECT
    count(*),
    count(DISTINCT selected.image_key)
  INTO
    v_manifest_count,
    v_manifest_distinct_count
  FROM public.booking_selected_images selected
  WHERE selected.selection_completion_id = v_completion.id
    AND selected.booking_id = v_booking.id;

  IF v_manifest_count < 1
     OR v_manifest_distinct_count <> v_manifest_count THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: canonical selected-image manifest is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)
  INTO v_selection_pending_transition_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id = transition_row.organization_id
   AND source_stage.id = transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND transition_row.transition_key = 'selection_pending'
    AND source_stage.stage_order = 11
    AND source_stage.stage_key = 'shoot_completed'
    AND destination_stage.stage_order = 12
    AND destination_stage.stage_key = 'selection_pending';

  IF v_selection_pending_transition_count <> 1 THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: canonical Selection Pending transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 13
     AND v_stage.stage_key = 'editing_pending' THEN
    SELECT count(*)
    INTO v_editing_pending_transition_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id = transition_row.organization_id
     AND source_stage.id = transition_row.from_stage_id
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'editing_pending'
      AND source_stage.stage_order = 12
      AND source_stage.stage_key = 'selection_pending'
      AND destination_stage.stage_order = 13
      AND destination_stage.stage_key = 'editing_pending';

    IF v_editing_pending_transition_count <> 1 THEN
      RAISE EXCEPTION
        'mark_booking_editing_pending: Editing Pending replay history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  IF v_stage.stage_order <> 12
     OR v_stage.stage_key <> 'selection_pending' THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: booking must be exactly Selection Pending'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id
  INTO v_editing_pending_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 13
    AND stage.stage_key = 'editing_pending'
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'mark_booking_editing_pending: canonical Editing Pending stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

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
    v_editing_pending_stage_id,
    'editing_pending',
    v_transitioned_at,
    v_actor
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_editing_pending_stage_id,
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
    RAISE EXCEPTION
      'mark_booking_editing_pending: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.editing_pending',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage', v_stage.stage_key,
      'journey_version', v_state.version
    ),
    jsonb_build_object(
      'journey_stage', 'editing_pending',
      'journey_version', v_state.version + 1
    ),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'selection_completion_id', v_completion.id,
      'selected_image_count', v_manifest_count,
      'transition_key', 'editing_pending',
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application',
    NULL
  );

  RETURN v_booking;
END;
$$;

REVOKE ALL
ON FUNCTION public.mark_booking_editing_pending(uuid)
FROM PUBLIC;
REVOKE ALL
ON FUNCTION public.mark_booking_editing_pending(uuid)
FROM anon;
REVOKE ALL
ON FUNCTION public.mark_booking_editing_pending(uuid)
FROM service_role;
GRANT EXECUTE
ON FUNCTION public.mark_booking_editing_pending(uuid)
TO authenticated;

-- =====================================================================
-- Section F — Migration postconditions
-- =====================================================================

DO $s13_postconditions$
DECLARE
  v_count integer;
  v_expected_role_permission_count integer;
BEGIN
  IF to_regclass('public.booking_selection_completions') IS NULL
     OR to_regclass('public.booking_selected_images') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 13 postcondition failed: selection evidence relation missing';
  END IF;

  IF to_regprocedure(
       'public.record_booking_selection_completion(uuid,text[],text,text)'
     ) IS NULL
     OR to_regprocedure(
       'public.mark_booking_editing_pending(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 13 postcondition failed: required mutation RPC missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key = 'selection.confirm'
    AND permission.domain = 'bookings'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 13 postcondition failed: selection.confirm permission invalid';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id = role_permission.permission_id
  JOIN public.roles role
    ON role.id = role_permission.role_id
  WHERE permission.key = 'selection.confirm'
    AND role.key IN (
      'founder',
      'studio_manager',
      'client_coordinator'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 13 postcondition failed: selection.confirm role boundary invalid';
  END IF;

  -- Preserve the same chronology contract used by the precondition.
  --
  -- Pre-Migration A clean replay finishes Sprint 13 at 236.
  -- Post-Migration A catch-up finishes Sprint 13 at 260.
  IF to_regclass('public.role_scope_policies') IS NULL
     AND to_regclass('public.organization_brand_owners') IS NULL THEN

    v_expected_role_permission_count := 236;

  ELSIF to_regclass('public.role_scope_policies') IS NOT NULL
        AND to_regclass('public.organization_brand_owners') IS NOT NULL THEN

    v_expected_role_permission_count := 260;

  ELSE
    RAISE EXCEPTION
      'Sprint 13 postcondition failed: Migration A constitutional foundation is partially present';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> v_expected_role_permission_count THEN
    RAISE EXCEPTION
      'Sprint 13 postcondition failed: expected canonical role-permission count %, found %',
      v_expected_role_permission_count,
      v_count;
  END IF;
END
$s13_postconditions$;
