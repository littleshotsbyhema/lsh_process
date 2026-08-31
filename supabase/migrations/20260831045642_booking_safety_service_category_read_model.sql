-- Sprint 10 P2 correction
-- Safety service-category read model for actors who may read Safety
-- without quotation-line or preparation access.
--
-- This RPC intentionally crosses quotation_line_items RLS only to expose
-- the authoritative accepted-package service_category scalar.
--
-- It does not expose quotation lines, prices, package-version details,
-- or other finance/commercial evidence.

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $precheck$
BEGIN
  IF to_regprocedure(
       'public.get_booking_safety_service_category(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'booking safety service-category read-model precondition failed: RPC already exists';
  END IF;
END
$precheck$;

-- =====================================================================
-- Section B — Restricted authoritative safety-category read
-- =====================================================================

CREATE FUNCTION public.get_booking_safety_service_category(
  p_booking_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_service_category text;
BEGIN
  -- ---------------------------------------------------------------
  -- Input and authentication boundary.
  -- ---------------------------------------------------------------

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

  -- ---------------------------------------------------------------
  -- Resolve booking authority.
  --
  -- SECURITY DEFINER bypasses booking RLS, so all authorization is
  -- deliberately reconstructed below before privileged data access.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id;

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

  -- ---------------------------------------------------------------
  -- Resolve the same accepted-package authority used by
  -- record_booking_safety_readiness.
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
      'get_booking_safety_service_category: authoritative booking package category unavailable'
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
      'get_booking_safety_service_category: unsupported safety-readiness service category'
      USING ERRCODE = '22023';
  END IF;

  RETURN v_service_category;
END
$function$;

-- =====================================================================
-- Section C — Execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.get_booking_safety_service_category(
  uuid
)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.get_booking_safety_service_category(
  uuid
)
TO authenticated;

-- =====================================================================
-- Section D — Structural validation
-- =====================================================================

DO $validate$
DECLARE
  v_security_definer boolean;
BEGIN
  IF to_regprocedure(
       'public.get_booking_safety_service_category(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'booking safety service-category read-model validation failed: RPC missing';
  END IF;

  SELECT p.prosecdef
  INTO v_security_definer
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname =
        'get_booking_safety_service_category'
    AND pg_catalog.pg_get_function_identity_arguments(p.oid) =
        'p_booking_id uuid';

  IF v_security_definer IS DISTINCT FROM true THEN
    RAISE EXCEPTION
      'booking safety service-category read-model validation failed: RPC must be SECURITY DEFINER';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.get_booking_safety_service_category(uuid)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'booking safety service-category read-model validation failed: authenticated EXECUTE missing';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.get_booking_safety_service_category(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'booking safety service-category read-model validation failed: anon must not execute RPC';
  END IF;

  IF has_function_privilege(
       'service_role',
       'public.get_booking_safety_service_category(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'booking safety service-category read-model validation failed: service_role must not execute RPC';
  END IF;
END
$validate$;
