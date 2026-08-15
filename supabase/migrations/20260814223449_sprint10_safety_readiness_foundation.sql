-- Sprint 10 Slice 5
-- Restricted Safety/Comfort Readiness + Newborn Formal Sign-off Foundation
--
-- Frozen boundary:
--   * revisioned restricted booking safety/comfort readiness evidence
--   * immutable Newborn formal sign-off evidence
--   * Photographer receives safety.signoff, with server-side Lead enforcement
--     implemented by the later RPC section
--   * exact Stage 9 mutation boundary implemented by the later RPC section
--
-- Explicitly not included:
--   * Stage 9 -> 10
--   * Stage 10 -> 11
--   * /safety or /prep runtime/UI release
--   * shoot-day safety evidence
--   * medical / unrestricted sensitive free text
--   * Production backfill

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $precheck$
DECLARE
  v_current_signoff_roles text[];
BEGIN
  IF to_regclass(
       'public.booking_safety_readiness'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: booking_safety_readiness already exists';
  END IF;

  IF to_regclass(
       'public.booking_safety_signoffs'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: booking_safety_signoffs already exists';
  END IF;

  IF to_regprocedure(
       'public.record_booking_safety_readiness(uuid,text,text)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: record_booking_safety_readiness already exists';
  END IF;

  IF to_regprocedure(
       'public.signoff_booking_safety_readiness(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: signoff_booking_safety_readiness already exists';
  END IF;

  IF to_regprocedure(
       'public.lsh_booking_safety_readiness_guard()'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: readiness guard already exists';
  END IF;

  IF to_regprocedure(
       'public.lsh_booking_safety_signoff_guard()'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: signoff guard already exists';
  END IF;

  IF to_regclass(
       'public.booking_team_assignments'
     ) IS NULL THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: canonical booking-team evidence is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key =
          'safety.signoff'
      AND permission.domain =
          'safety'
      AND permission.requires_server_enforcement
  ) THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: canonical safety.signoff permission unavailable';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles role
    WHERE role.key =
          'photographer'
  ) THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: photographer role unavailable';
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_current_signoff_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'safety.signoff';

  IF v_current_signoff_roles
       IS DISTINCT FROM
       ARRAY[
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'sprint10 safety readiness precondition failed: existing safety.signoff grants are not exactly Founder and Studio Manager';
  END IF;
END
$precheck$;

-- =====================================================================
-- Section B — Canonical readiness evidence
-- =====================================================================

CREATE TABLE public.booking_safety_readiness (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  service_category text NOT NULL,
  revision_number integer NOT NULL,

  safety_state text NOT NULL,
  comfort_state text NOT NULL,

  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid NOT NULL,

  superseded_at timestamptz,
  superseded_by uuid,

  CONSTRAINT booking_safety_readiness_booking_fkey
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

  CONSTRAINT booking_safety_readiness_recorded_by_fkey
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

  CONSTRAINT booking_safety_readiness_superseded_by_fkey
    FOREIGN KEY (
      superseded_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_safety_readiness_org_booking_revision_key
    UNIQUE (
      organization_id,
      booking_id,
      revision_number
    ),

  CONSTRAINT booking_safety_readiness_id_org_booking_key
    UNIQUE (
      id,
      organization_id,
      booking_id
    ),

  CONSTRAINT booking_safety_readiness_revision_positive_chk
    CHECK (
      revision_number > 0
    ),

  CONSTRAINT booking_safety_readiness_service_category_chk
    CHECK (
      service_category = ANY (
        ARRAY[
          'newborn',
          'maternity',
          'sitter',
          'baby',
          'child'
        ]::text[]
      )
    ),

  CONSTRAINT booking_safety_readiness_safety_state_chk
    CHECK (
      safety_state = ANY (
        ARRAY[
          'pending',
          'ready',
          'not_ready',
          'not_applicable'
        ]::text[]
      )
    ),

  CONSTRAINT booking_safety_readiness_comfort_state_chk
    CHECK (
      comfort_state = ANY (
        ARRAY[
          'pending',
          'ready',
          'not_ready',
          'not_applicable'
        ]::text[]
      )
    ),

  CONSTRAINT booking_safety_readiness_category_applicability_chk
    CHECK (
      (
        service_category = 'newborn'
        AND safety_state <> 'not_applicable'
        AND comfort_state <> 'not_applicable'
      )
      OR
      (
        service_category = 'maternity'
        AND safety_state = 'not_applicable'
        AND comfort_state <> 'not_applicable'
      )
      OR
      (
        service_category = ANY (
          ARRAY[
            'sitter',
            'baby',
            'child'
          ]::text[]
        )
        AND safety_state <> 'not_applicable'
        AND comfort_state <> 'not_applicable'
      )
    ),

  CONSTRAINT booking_safety_readiness_lifecycle_chk
    CHECK (
      (
        superseded_at IS NULL
        AND superseded_by IS NULL
      )
      OR
      (
        superseded_at IS NOT NULL
        AND superseded_by IS NOT NULL
      )
    ),

  CONSTRAINT booking_safety_readiness_superseded_time_chk
    CHECK (
      superseded_at IS NULL
      OR superseded_at >= recorded_at
    )
);

CREATE UNIQUE INDEX booking_safety_readiness_current_uidx
  ON public.booking_safety_readiness (
    organization_id,
    booking_id
  )
  WHERE superseded_at IS NULL;

-- =====================================================================
-- Section C — Immutable formal Newborn sign-off evidence
-- =====================================================================

CREATE TABLE public.booking_safety_signoffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,

  readiness_id uuid NOT NULL,

  signed_at timestamptz NOT NULL DEFAULT now(),
  signed_by uuid NOT NULL,

  signoff_authority text NOT NULL,
  lead_assignment_id uuid,

  CONSTRAINT booking_safety_signoffs_booking_fkey
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

  CONSTRAINT booking_safety_signoffs_readiness_fkey
    FOREIGN KEY (
      readiness_id,
      organization_id,
      booking_id
    )
    REFERENCES public.booking_safety_readiness (
      id,
      organization_id,
      booking_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_safety_signoffs_signed_by_fkey
    FOREIGN KEY (
      signed_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_safety_signoffs_lead_assignment_fkey
    FOREIGN KEY (
      lead_assignment_id,
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

  CONSTRAINT booking_safety_signoffs_authority_chk
    CHECK (
      signoff_authority = ANY (
        ARRAY[
          'founder',
          'studio_manager',
          'lead_photographer'
        ]::text[]
      )
    ),

  CONSTRAINT booking_safety_signoffs_authority_shape_chk
    CHECK (
      (
        signoff_authority = ANY (
          ARRAY[
            'founder',
            'studio_manager'
          ]::text[]
        )
        AND lead_assignment_id IS NULL
      )
      OR
      (
        signoff_authority = 'lead_photographer'
        AND lead_assignment_id IS NOT NULL
      )
    ),

  CONSTRAINT booking_safety_signoffs_signer_revision_key
    UNIQUE (
      organization_id,
      readiness_id,
      signed_by
    )
);

-- =====================================================================
-- Section D — Readiness lifecycle guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_safety_readiness_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking_safety_readiness: deletion is not permitted'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.superseded_at IS NOT NULL
       OR NEW.superseded_by IS NOT NULL THEN
      RAISE EXCEPTION
        'booking_safety_readiness: new revisions must be current'
        USING ERRCODE = '42501';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      v_actor :=
        public.current_organization_member(
          NEW.organization_id
        );

      IF v_actor IS NULL
         OR NEW.recorded_by IS DISTINCT FROM v_actor THEN
        RAISE EXCEPTION
          'booking_safety_readiness: recorded_by must match the active organization actor'
          USING ERRCODE = '42501';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.superseded_at IS NOT NULL
       OR OLD.superseded_by IS NOT NULL THEN
      RAISE EXCEPTION
        'booking_safety_readiness: historical revisions are immutable'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.booking_id IS DISTINCT FROM OLD.booking_id
       OR NEW.service_category IS DISTINCT FROM OLD.service_category
       OR NEW.revision_number IS DISTINCT FROM OLD.revision_number
       OR NEW.safety_state IS DISTINCT FROM OLD.safety_state
       OR NEW.comfort_state IS DISTINCT FROM OLD.comfort_state
       OR NEW.recorded_at IS DISTINCT FROM OLD.recorded_at
       OR NEW.recorded_by IS DISTINCT FROM OLD.recorded_by THEN
      RAISE EXCEPTION
        'booking_safety_readiness: revision identity and readiness state are immutable'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.superseded_at IS NULL
       OR NEW.superseded_by IS NULL THEN
      RAISE EXCEPTION
        'booking_safety_readiness: update may only supersede the current revision'
        USING ERRCODE = '42501';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      v_actor :=
        public.current_organization_member(
          NEW.organization_id
        );

      IF v_actor IS NULL
         OR NEW.superseded_by IS DISTINCT FROM v_actor THEN
        RAISE EXCEPTION
          'booking_safety_readiness: superseded_by must match the active organization actor'
          USING ERRCODE = '42501';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'booking_safety_readiness: unsupported trigger operation'
    USING ERRCODE = '42501';
END
$$;

REVOKE ALL
ON FUNCTION public.lsh_booking_safety_readiness_guard()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.lsh_booking_safety_readiness_guard()
TO service_role;

CREATE TRIGGER booking_safety_readiness_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_safety_readiness
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_safety_readiness_guard();

-- =====================================================================
-- Section E — Sign-off immutable lifecycle guard
-- =====================================================================

CREATE FUNCTION public.lsh_booking_safety_signoff_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'booking_safety_signoffs: sign-offs are immutable'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking_safety_signoffs: deletion is not permitted'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF (
         NEW.signoff_authority = ANY (
           ARRAY[
             'founder',
             'studio_manager'
           ]::text[]
         )
         AND NEW.lead_assignment_id IS NOT NULL
       )
       OR
       (
         NEW.signoff_authority = 'lead_photographer'
         AND NEW.lead_assignment_id IS NULL
       ) THEN
      RAISE EXCEPTION
        'booking_safety_signoffs: invalid authority and Lead-assignment shape'
        USING ERRCODE = '42501';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      v_actor :=
        public.current_organization_member(
          NEW.organization_id
        );

      IF v_actor IS NULL
         OR NEW.signed_by IS DISTINCT FROM v_actor THEN
        RAISE EXCEPTION
          'booking_safety_signoffs: signed_by must match the active organization actor'
          USING ERRCODE = '42501';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'booking_safety_signoffs: unsupported trigger operation'
    USING ERRCODE = '42501';
END
$$;

REVOKE ALL
ON FUNCTION public.lsh_booking_safety_signoff_guard()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.lsh_booking_safety_signoff_guard()
TO service_role;

CREATE TRIGGER booking_safety_signoffs_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_safety_signoffs
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_safety_signoff_guard();

-- =====================================================================
-- Section F — Restricted RLS
-- =====================================================================

ALTER TABLE public.booking_safety_readiness
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_safety_readiness
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.booking_safety_signoffs
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_safety_signoffs
  FORCE ROW LEVEL SECURITY;

CREATE POLICY booking_safety_readiness_authenticated_select
ON public.booking_safety_readiness
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_safety_readiness.organization_id
      AND booking.id =
          booking_safety_readiness.booking_id
      AND public.has_permission(
            booking.organization_id,
            'safety.read',
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

CREATE POLICY booking_safety_signoffs_authenticated_select
ON public.booking_safety_signoffs
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_safety_signoffs.organization_id
      AND booking.id =
          booking_safety_signoffs.booking_id
      AND public.has_permission(
            booking.organization_id,
            'safety.read',
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
-- Section G — Table ACL boundary
-- =====================================================================

REVOKE ALL
ON TABLE public.booking_safety_readiness
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON TABLE public.booking_safety_signoffs
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON TABLE public.booking_safety_readiness
TO authenticated;

GRANT SELECT
ON TABLE public.booking_safety_signoffs
TO authenticated;

GRANT ALL
ON TABLE public.booking_safety_readiness
TO service_role;

GRANT ALL
ON TABLE public.booking_safety_signoffs
TO service_role;

-- =====================================================================
-- Section H — Approved safety.signoff Photographer grant
-- =====================================================================

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
      'safety.signoff'
ON CONFLICT (
  role_id,
  permission_id
)
DO NOTHING;

DO $grant_gate$
DECLARE
  v_signoff_roles text[];
BEGIN
  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_signoff_roles
  FROM public.role_permissions mapping
  JOIN public.permissions permission
    ON permission.id =
       mapping.permission_id
  JOIN public.roles role
    ON role.id =
       mapping.role_id
  WHERE permission.key =
        'safety.signoff';

  IF v_signoff_roles
       IS DISTINCT FROM
       ARRAY[
         'founder',
         'photographer',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'sprint10 safety readiness grant gate failed: safety.signoff must be exactly Founder, Photographer and Studio Manager';
  END IF;
END
$grant_gate$;

-- =====================================================================
-- Public mutation RPCs intentionally follow in the next reviewed section.
-- =====================================================================

-- =====================================================================
-- Section I — Controlled readiness mutation
-- =====================================================================

CREATE FUNCTION public.record_booking_safety_readiness(
  p_booking_id uuid,
  p_safety_state text,
  p_comfort_state text
)
RETURNS public.booking_safety_readiness
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_current public.booking_safety_readiness;
  v_result public.booking_safety_readiness;

  v_actor uuid;
  v_state_count integer;
  v_service_category text;
  v_changed_at timestamptz;
  v_next_revision integer;
  v_has_current boolean := false;
BEGIN
  -- ---------------------------------------------------------------
  -- Input and authentication boundary.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_safety_state IS NULL
     OR p_comfort_state IS NULL THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: safety and comfort states are required'
      USING ERRCODE = '22023';
  END IF;

  IF p_safety_state NOT IN (
       'pending',
       'ready',
       'not_ready',
       'not_applicable'
     ) THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: unsupported safety state'
      USING ERRCODE = '22023';
  END IF;

  IF p_comfort_state NOT IN (
       'pending',
       'ready',
       'not_ready',
       'not_applicable'
     ) THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: unsupported comfort state'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: authenticated actor required'
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
      'record_booking_safety_readiness: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'safety.write',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: safety.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: booking branch scope required'
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
      'record_booking_safety_readiness: booking must have exactly one current journey state'
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
      'record_booking_safety_readiness: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 9
     OR v_stage.stage_key <> 'pre_shoot_preparation' THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: booking must be exactly Pre-Shoot Preparation'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve the authoritative accepted-quotation package category.
  -- ---------------------------------------------------------------

  SELECT package.service_category
  INTO v_service_category
  FROM public.quotation_line_items line
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       line.organization_id
   AND version.id =
       line.source_package_version_id
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE line.organization_id =
        v_booking.organization_id
    AND line.quotation_id =
        v_booking.source_quotation_id
    AND line.line_type =
        'package';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: authoritative booking package category unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_service_category NOT IN (
       'newborn',
       'maternity',
       'sitter',
       'baby',
       'child'
     ) THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: unsupported safety-readiness service category'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Category-specific applicability is server-enforced.
  -- ---------------------------------------------------------------

  IF v_service_category = 'maternity' THEN
    IF p_safety_state <> 'not_applicable'
       OR p_comfort_state = 'not_applicable' THEN
      RAISE EXCEPTION
        'record_booking_safety_readiness: invalid Maternity readiness applicability'
        USING ERRCODE = '22023';
    END IF;
  ELSE
    IF p_safety_state = 'not_applicable'
       OR p_comfort_state = 'not_applicable' THEN
      RAISE EXCEPTION
        'record_booking_safety_readiness: safety and comfort are applicable for this service category'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: current readiness revision.
  -- ---------------------------------------------------------------

  SELECT readiness.*
  INTO v_current
  FROM public.booking_safety_readiness readiness
  WHERE readiness.organization_id =
        v_booking.organization_id
    AND readiness.booking_id =
        v_booking.id
    AND readiness.superseded_at IS NULL
  FOR UPDATE;

  v_has_current := FOUND;

  -- ---------------------------------------------------------------
  -- Exact replay is authorization-first and a true no-op.
  -- ---------------------------------------------------------------

  IF v_has_current
     AND v_current.service_category =
         v_service_category
     AND v_current.safety_state =
         p_safety_state
     AND v_current.comfort_state =
         p_comfort_state THEN
    RETURN v_current;
  END IF;

  v_changed_at := now();

  -- ---------------------------------------------------------------
  -- First readiness revision.
  -- ---------------------------------------------------------------

  IF NOT v_has_current THEN
    INSERT INTO public.booking_safety_readiness (
      organization_id,
      booking_id,
      service_category,
      revision_number,
      safety_state,
      comfort_state,
      recorded_at,
      recorded_by
    )
    VALUES (
      v_booking.organization_id,
      v_booking.id,
      v_service_category,
      1,
      p_safety_state,
      p_comfort_state,
      v_changed_at,
      v_actor
    )
    RETURNING *
    INTO v_result;

    PERFORM public.append_audit_event(
      v_booking.organization_id,
      v_booking.branch_id,
      'booking.safety_readiness_recorded',
      'booking_safety_readiness',
      v_result.id,
      true,
      NULL,
      jsonb_build_object(
        'readiness_id',
          v_result.id,
        'revision_number',
          v_result.revision_number,
        'service_category',
          v_result.service_category,
        'safety_state',
          v_result.safety_state,
        'comfort_state',
          v_result.comfort_state
      ),
      jsonb_build_object(
        'booking_id',
          v_booking.id
      ),
      'application',
      NULL
    );

    RETURN v_result;
  END IF;

  -- ---------------------------------------------------------------
  -- Real state change: close N and create N + 1 atomically.
  -- ---------------------------------------------------------------

  v_next_revision :=
    v_current.revision_number + 1;

  UPDATE public.booking_safety_readiness readiness
  SET
    superseded_at =
      v_changed_at,
    superseded_by =
      v_actor
  WHERE readiness.organization_id =
        v_current.organization_id
    AND readiness.id =
        v_current.id
    AND readiness.superseded_at IS NULL
  RETURNING *
  INTO v_current;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_safety_readiness: current readiness changed during revision'
      USING ERRCODE = '40001';
  END IF;

  INSERT INTO public.booking_safety_readiness (
    organization_id,
    booking_id,
    service_category,
    revision_number,
    safety_state,
    comfort_state,
    recorded_at,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_service_category,
    v_next_revision,
    p_safety_state,
    p_comfort_state,
    v_changed_at,
    v_actor
  )
  RETURNING *
  INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.safety_readiness_revised',
    'booking_safety_readiness',
    v_result.id,
    true,
    jsonb_build_object(
      'readiness_id',
        v_current.id,
      'revision_number',
        v_current.revision_number,
      'service_category',
        v_current.service_category,
      'safety_state',
        v_current.safety_state,
      'comfort_state',
        v_current.comfort_state
    ),
    jsonb_build_object(
      'readiness_id',
        v_result.id,
      'revision_number',
        v_result.revision_number,
      'service_category',
        v_result.service_category,
      'safety_state',
        v_result.safety_state,
      'comfort_state',
        v_result.comfort_state
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id
    ),
    'application',
    NULL
  );

  RETURN v_result;
END
$$;

REVOKE ALL
ON FUNCTION public.record_booking_safety_readiness(
  uuid,
  text,
  text
)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE
ON FUNCTION public.record_booking_safety_readiness(
  uuid,
  text,
  text
)
TO authenticated;

-- =====================================================================
-- Section J — Immutable formal Newborn readiness sign-off
-- =====================================================================

CREATE FUNCTION public.signoff_booking_safety_readiness(
  p_booking_id uuid
)
RETURNS public.booking_safety_signoffs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_readiness public.booking_safety_readiness;
  v_existing public.booking_safety_signoffs;
  v_result public.booking_safety_signoffs;

  v_lead_assignment public.booking_team_assignments;
  v_signer public.organization_members;

  v_actor uuid;
  v_state_count integer;
  v_service_category text;

  v_authority text;
  v_required_role text;
  v_lead_assignment_id uuid;

  v_has_founder boolean := false;
  v_has_studio_manager boolean := false;
  v_has_photographer boolean := false;

  v_signed_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input and authentication boundary.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 1: booking.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'safety.signoff',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: safety.signoff permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 2: exactly one current journey state.
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
      'signoff_booking_safety_readiness: booking must have exactly one current journey state'
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
      'signoff_booking_safety_readiness: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order <> 9
     OR v_stage.stage_key <> 'pre_shoot_preparation' THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: booking must be exactly Pre-Shoot Preparation'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Newborn-only authoritative category gate.
  -- ---------------------------------------------------------------

  SELECT package.service_category
  INTO v_service_category
  FROM public.quotation_line_items line
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       line.organization_id
   AND version.id =
       line.source_package_version_id
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE line.organization_id =
        v_booking.organization_id
    AND line.quotation_id =
        v_booking.source_quotation_id
    AND line.line_type =
        'package';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: authoritative booking package category unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_service_category <> 'newborn' THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: formal sign-off is Newborn-only'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 3: exact current readiness revision.
  -- ---------------------------------------------------------------

  SELECT readiness.*
  INTO v_readiness
  FROM public.booking_safety_readiness readiness
  WHERE readiness.organization_id =
        v_booking.organization_id
    AND readiness.booking_id =
        v_booking.id
    AND readiness.superseded_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: current readiness evidence required'
      USING ERRCODE = '22023';
  END IF;

  IF v_readiness.service_category
       IS DISTINCT FROM
       v_service_category THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: current readiness category does not match booking category'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_readiness.safety_state <> 'ready'
     OR v_readiness.comfort_state <> 'ready' THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: current Newborn readiness must be complete and ready'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve deterministic signer authority:
  -- Founder -> Studio Manager -> qualifying Lead Photographer.
  --
  -- These discovery reads do not take role-grant locks; the selected
  -- qualifying grant is revalidated and locked below.
  -- ---------------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.member_role_grants grant_row
    JOIN public.roles role
      ON role.id =
         grant_row.role_id
    WHERE grant_row.organization_id =
          v_booking.organization_id
      AND grant_row.organization_member_id =
          v_actor
      AND grant_row.revoked_at IS NULL
      AND role.key =
          'founder'
      AND (
        (
          v_booking.branch_id IS NULL
          AND grant_row.branch_id IS NULL
        )
        OR
        (
          v_booking.branch_id IS NOT NULL
          AND (
            grant_row.branch_id IS NULL
            OR grant_row.branch_id =
               v_booking.branch_id
          )
        )
      )
  )
  INTO v_has_founder;

  SELECT EXISTS (
    SELECT 1
    FROM public.member_role_grants grant_row
    JOIN public.roles role
      ON role.id =
         grant_row.role_id
    WHERE grant_row.organization_id =
          v_booking.organization_id
      AND grant_row.organization_member_id =
          v_actor
      AND grant_row.revoked_at IS NULL
      AND role.key =
          'studio_manager'
      AND (
        (
          v_booking.branch_id IS NULL
          AND grant_row.branch_id IS NULL
        )
        OR
        (
          v_booking.branch_id IS NOT NULL
          AND (
            grant_row.branch_id IS NULL
            OR grant_row.branch_id =
               v_booking.branch_id
          )
        )
      )
  )
  INTO v_has_studio_manager;

  SELECT EXISTS (
    SELECT 1
    FROM public.member_role_grants grant_row
    JOIN public.roles role
      ON role.id =
         grant_row.role_id
    WHERE grant_row.organization_id =
          v_booking.organization_id
      AND grant_row.organization_member_id =
          v_actor
      AND grant_row.revoked_at IS NULL
      AND role.key =
          'photographer'
      AND (
        (
          v_booking.branch_id IS NULL
          AND grant_row.branch_id IS NULL
        )
        OR
        (
          v_booking.branch_id IS NOT NULL
          AND (
            grant_row.branch_id IS NULL
            OR grant_row.branch_id =
               v_booking.branch_id
          )
        )
      )
  )
  INTO v_has_photographer;

  IF v_has_founder THEN
    v_authority :=
      'founder';
    v_required_role :=
      'founder';

  ELSIF v_has_studio_manager THEN
    v_authority :=
      'studio_manager';
    v_required_role :=
      'studio_manager';

  ELSIF v_has_photographer THEN
    v_authority :=
      'lead_photographer';
    v_required_role :=
      'photographer';

  ELSE
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: qualifying sign-off role required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 4 when required: exact current Lead assignment.
  -- ---------------------------------------------------------------

  IF v_authority = 'lead_photographer' THEN
    SELECT assignment.*
    INTO v_lead_assignment
    FROM public.booking_team_assignments assignment
    WHERE assignment.organization_id =
          v_booking.organization_id
      AND assignment.booking_id =
          v_booking.id
      AND assignment.assignment_role =
          'lead_photographer'
      AND assignment.ended_at IS NULL
    FOR UPDATE;

    IF NOT FOUND
       OR v_lead_assignment.assigned_member_id
            IS DISTINCT FROM
          v_actor THEN
      RAISE EXCEPTION
        'signoff_booking_safety_readiness: Photographer must be the current Lead Photographer'
        USING ERRCODE = '42501';
    END IF;

    v_lead_assignment_id :=
      v_lead_assignment.id;
  ELSE
    v_lead_assignment_id :=
      NULL;
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 5: signer organization member.
  -- ---------------------------------------------------------------

  SELECT member.*
  INTO v_signer
  FROM public.organization_members member
  WHERE member.organization_id =
        v_booking.organization_id
    AND member.id =
        v_actor
  FOR UPDATE;

  IF NOT FOUND
     OR v_signer.status <>
          'active'::public.member_status THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: signer must remain an active organization member'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock order 6: qualifying live role grant.
  -- ---------------------------------------------------------------

  PERFORM grant_row.id
  FROM public.member_role_grants grant_row
  JOIN public.roles role
    ON role.id =
       grant_row.role_id
  WHERE grant_row.organization_id =
        v_booking.organization_id
    AND grant_row.organization_member_id =
        v_actor
    AND grant_row.revoked_at IS NULL
    AND role.key =
        v_required_role
    AND (
      (
        v_booking.branch_id IS NULL
        AND grant_row.branch_id IS NULL
      )
      OR
      (
        v_booking.branch_id IS NOT NULL
        AND (
          grant_row.branch_id IS NULL
          OR grant_row.branch_id =
             v_booking.branch_id
        )
      )
    )
  ORDER BY
    CASE
      WHEN grant_row.branch_id IS NULL
        THEN 0
      ELSE 1
    END,
    grant_row.id
  LIMIT 1
  FOR UPDATE OF grant_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'signoff_booking_safety_readiness: qualifying live sign-off role required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Same-signer replay occurs only after current authorization and
  -- readiness have been revalidated.
  -- ---------------------------------------------------------------

  SELECT signoff.*
  INTO v_existing
  FROM public.booking_safety_signoffs signoff
  WHERE signoff.organization_id =
        v_booking.organization_id
    AND signoff.readiness_id =
        v_readiness.id
    AND signoff.signed_by =
        v_actor;

  IF FOUND THEN
    RETURN v_existing;
  END IF;

  v_signed_at := now();

  INSERT INTO public.booking_safety_signoffs (
    organization_id,
    booking_id,
    readiness_id,
    signed_at,
    signed_by,
    signoff_authority,
    lead_assignment_id
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_readiness.id,
    v_signed_at,
    v_actor,
    v_authority,
    v_lead_assignment_id
  )
  RETURNING *
  INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.safety_readiness_signed_off',
    'booking_safety_signoff',
    v_result.id,
    true,
    NULL,
    jsonb_build_object(
      'signoff_id',
        v_result.id,
      'readiness_id',
        v_readiness.id,
      'revision_number',
        v_readiness.revision_number,
      'signed_by',
        v_result.signed_by,
      'signoff_authority',
        v_result.signoff_authority,
      'lead_assignment_id',
        v_result.lead_assignment_id
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id
    ),
    'application',
    NULL
  );

  RETURN v_result;
END
$$;

REVOKE ALL
ON FUNCTION public.signoff_booking_safety_readiness(
  uuid
)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE
ON FUNCTION public.signoff_booking_safety_readiness(
  uuid
)
TO authenticated;

-- =====================================================================
-- Slice 5 database foundation implementation boundary ends here.
-- No Stage 9 -> 10 journey mutation is introduced by this migration.
-- =====================================================================
