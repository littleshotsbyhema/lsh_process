BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';

-- ============================================================
-- 1. Make the safety-category read model total for valid
--    non-Safety package categories.
--
-- Authorization, booking existence, branch scope, and missing
-- authoritative package evidence remain hard failures.
--
-- A valid package whose service category is outside the current
-- Safety Readiness taxonomy is not an authorization/integrity
-- failure. It is represented to the workspace as NULL so one
-- unrelated booking cannot make the entire Bookings page fail.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_booking_safety_service_category(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_booking          public.bookings;
  v_actor            uuid;
  v_service_category text;
BEGIN
  -- ----------------------------------------------------------
  -- Input and authentication boundary.
  -- ----------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'get_booking_safety_service_category: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'get_booking_safety_service_category: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ----------------------------------------------------------
  -- Resolve canonical booking-owned organization / branch.
  -- SECURITY DEFINER bypasses booking RLS, so authority is
  -- reconstructed explicitly before privileged package access.
  -- ----------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'get_booking_safety_service_category: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_booking_safety_service_category: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.read',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'get_booking_safety_service_category: booking.read permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'safety.read',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'get_booking_safety_service_category: safety.read permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'get_booking_safety_service_category: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ----------------------------------------------------------
  -- Resolve the same accepted-package authority used by the
  -- canonical Safety Readiness mutation.
  -- ----------------------------------------------------------

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
      'get_booking_safety_service_category: authoritative booking package category unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ----------------------------------------------------------
  -- Unsupported categories are valid booking categories but are
  -- outside the current Safety Readiness taxonomy. They must not
  -- make the entire booking workspace fail.
  -- ----------------------------------------------------------

  IF v_service_category NOT IN (
       'newborn',
       'maternity',
       'sitter',
       'baby',
       'child'
     ) THEN
    RETURN NULL;
  END IF;

  RETURN v_service_category;
END
$function$;

COMMENT ON FUNCTION public.get_booking_safety_service_category(uuid)
IS
  'Returns the authoritative supported Safety Readiness service category for an authorized booking; returns NULL when the authoritative package category is valid but outside the current Safety Readiness taxonomy.';


-- ============================================================
-- 2. Add a narrow read model for canonical Newborn sign-off
--    authority.
--
-- This deliberately mirrors the authority precedence enforced by
-- signoff_booking_safety_readiness:
--
--   Founder
--     -> Studio Manager
--       -> current internal Lead Photographer
--
-- Permission alone is insufficient for a Photographer.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_booking_safety_signoff_authority(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_booking            public.bookings;
  v_actor              uuid;
  v_has_founder        boolean;
  v_has_studio_manager boolean;
  v_has_photographer   boolean;
  v_is_current_lead    boolean;
BEGIN
  -- ----------------------------------------------------------
  -- Input and authentication boundary.
  -- ----------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ----------------------------------------------------------
  -- Resolve canonical booking authority.
  -- ----------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.read',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: booking.read permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'safety.read',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: safety.read permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'safety.signoff',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: safety.signoff permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'get_booking_safety_signoff_authority: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ----------------------------------------------------------
  -- Mirror canonical deterministic signer precedence.
  -- ----------------------------------------------------------

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
    RETURN 'founder';
  END IF;

  IF v_has_studio_manager THEN
    RETURN 'studio_manager';
  END IF;

  IF NOT v_has_photographer THEN
    RETURN NULL;
  END IF;

  -- ----------------------------------------------------------
  -- Photographer authority exists only when the authenticated
  -- actor is the current INTERNAL Lead Photographer.
  --
  -- An external Lead Photographer cannot be the authenticated
  -- organization-member signer represented by this authority.
  -- ----------------------------------------------------------

  SELECT EXISTS (
    SELECT 1
    FROM public.booking_team_assignments assignment
    WHERE assignment.organization_id =
          v_booking.organization_id
      AND assignment.booking_id =
          v_booking.id
      AND assignment.assignment_role =
          'lead_photographer'
      AND assignment.ended_at IS NULL
      AND assignment.assigned_member_id =
          v_actor
  )
  INTO v_is_current_lead;

  IF v_is_current_lead THEN
    RETURN 'lead_photographer';
  END IF;

  RETURN NULL;
END
$function$;

COMMENT ON FUNCTION public.get_booking_safety_signoff_authority(uuid)
IS
  'Returns the authenticated actor''s canonical booking-specific Newborn Safety sign-off authority: founder, studio_manager, lead_photographer, or NULL when permission exists but the actor has no qualifying signer authority.';


-- ============================================================
-- 3. Explicit function execution boundary.
--
-- Both functions intentionally cross RLS only after reconstructing
-- booking-owned authentication, permission, and branch authority.
-- ============================================================

REVOKE ALL
  ON FUNCTION public.get_booking_safety_service_category(uuid)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
  ON FUNCTION public.get_booking_safety_service_category(uuid)
  TO authenticated;

REVOKE ALL
  ON FUNCTION public.get_booking_safety_signoff_authority(uuid)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
  ON FUNCTION public.get_booking_safety_signoff_authority(uuid)
  TO authenticated;


-- ============================================================
-- 4. Structural validation gates.
-- ============================================================

DO $validation$
DECLARE
  v_security_definer  boolean;
  v_function_config   text[];
  v_authenticated_exec boolean;
  v_anon_exec          boolean;
  v_service_role_exec  boolean;
  v_public_exec        boolean;
BEGIN
  -- ----------------------------------------------------------
  -- Safety service-category read model.
  -- ----------------------------------------------------------

  SELECT
    p.prosecdef,
    p.proconfig
  INTO
    v_security_definer,
    v_function_config
  FROM pg_catalog.pg_proc p
  WHERE p.oid =
        'public.get_booking_safety_service_category(uuid)'::regprocedure;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_service_category(uuid) missing';
  END IF;

  IF NOT v_security_definer THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_service_category(uuid) must remain SECURITY DEFINER';
  END IF;

  IF NOT (
    COALESCE(v_function_config, ARRAY[]::text[])
      @> ARRAY['search_path=""']::text[]
  ) THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_service_category(uuid) must use empty search_path';
  END IF;

  SELECT
    has_function_privilege(
      'authenticated',
      'public.get_booking_safety_service_category(uuid)',
      'EXECUTE'
    ),
    has_function_privilege(
      'anon',
      'public.get_booking_safety_service_category(uuid)',
      'EXECUTE'
    ),
    has_function_privilege(
      'service_role',
      'public.get_booking_safety_service_category(uuid)',
      'EXECUTE'
    )
  INTO
    v_authenticated_exec,
    v_anon_exec,
    v_service_role_exec;

  IF NOT v_authenticated_exec
     OR v_anon_exec
     OR v_service_role_exec THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_service_category(uuid) ACL mismatch';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    CROSS JOIN LATERAL
      pg_catalog.aclexplode(
        COALESCE(
          p.proacl,
          pg_catalog.acldefault('f', p.proowner)
        )
      ) acl
    WHERE p.oid =
          'public.get_booking_safety_service_category(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  )
  INTO v_public_exec;

  IF v_public_exec THEN
    RAISE EXCEPTION
      'Validation failed: PUBLIC must not execute get_booking_safety_service_category(uuid)';
  END IF;

  -- ----------------------------------------------------------
  -- Sign-off authority read model.
  -- ----------------------------------------------------------

  SELECT
    p.prosecdef,
    p.proconfig
  INTO
    v_security_definer,
    v_function_config
  FROM pg_catalog.pg_proc p
  WHERE p.oid =
        'public.get_booking_safety_signoff_authority(uuid)'::regprocedure;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_signoff_authority(uuid) missing';
  END IF;

  IF NOT v_security_definer THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_signoff_authority(uuid) must be SECURITY DEFINER';
  END IF;

  IF NOT (
    COALESCE(v_function_config, ARRAY[]::text[])
      @> ARRAY['search_path=""']::text[]
  ) THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_signoff_authority(uuid) must use empty search_path';
  END IF;

  SELECT
    has_function_privilege(
      'authenticated',
      'public.get_booking_safety_signoff_authority(uuid)',
      'EXECUTE'
    ),
    has_function_privilege(
      'anon',
      'public.get_booking_safety_signoff_authority(uuid)',
      'EXECUTE'
    ),
    has_function_privilege(
      'service_role',
      'public.get_booking_safety_signoff_authority(uuid)',
      'EXECUTE'
    )
  INTO
    v_authenticated_exec,
    v_anon_exec,
    v_service_role_exec;

  IF NOT v_authenticated_exec
     OR v_anon_exec
     OR v_service_role_exec THEN
    RAISE EXCEPTION
      'Validation failed: get_booking_safety_signoff_authority(uuid) ACL mismatch';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    CROSS JOIN LATERAL
      pg_catalog.aclexplode(
        COALESCE(
          p.proacl,
          pg_catalog.acldefault('f', p.proowner)
        )
      ) acl
    WHERE p.oid =
          'public.get_booking_safety_signoff_authority(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  )
  INTO v_public_exec;

  IF v_public_exec THEN
    RAISE EXCEPTION
      'Validation failed: PUBLIC must not execute get_booking_safety_signoff_authority(uuid)';
  END IF;
END
$validation$;

COMMIT;
