-- =====================================================================
-- Little Shots by Hema OS
-- Sprint 10 Slice 7D — Canonical Role Administration Read Model
--
-- Purpose:
--   - Expose exact live member -> role -> branch grant facts.
--   - Expose permission-aware role-assignment scope choices.
--   - Preserve direct-table denial for member_role_grants.
--   - Preserve existing role mutation and permission semantics.
--
-- Explicitly out of scope:
--   - Team role-administration UI.
--   - Role/permission matrix changes.
--   - Existing grant/revoke RPC changes.
--   - Branch creation or mutation.
--   - Production deployment.
-- =====================================================================

BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '180s';


-- =====================================================================
-- 1. Preconditions
-- =====================================================================

DO $preconditions$
DECLARE
  v_role_assign_mapping_count integer;
BEGIN
  IF to_regclass('public.member_role_grants') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.branches') IS NULL THEN
    RAISE EXCEPTION
      'Slice 7D precondition failed: canonical Team access tables are missing';
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
       'public.grant_organization_member_role(uuid,uuid,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.revoke_organization_member_role(uuid,uuid,text,uuid,text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Slice 7D precondition failed: canonical Team authorization functions are missing';
  END IF;

  IF to_regprocedure(
       'public.team_role_grant_directory(uuid,uuid)'
     ) IS NOT NULL
     OR to_regprocedure(
       'public.team_role_scope_catalogue(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Slice 7D precondition failed: role administration read-model functions already exist';
  END IF;

  SELECT count(*)
  INTO v_role_assign_mapping_count
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  JOIN public.roles r
    ON r.id = rp.role_id
  WHERE p.key = 'team.role.assign'
    AND r.key = 'founder';

  IF v_role_assign_mapping_count <> 1 THEN
    RAISE EXCEPTION
      'Slice 7D precondition failed: Founder team.role.assign mapping is missing or duplicated';
  END IF;

  SELECT count(*)
  INTO v_role_assign_mapping_count
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  WHERE p.key = 'team.role.assign';

  IF v_role_assign_mapping_count <> 1 THEN
    RAISE EXCEPTION
      'Slice 7D precondition failed: team.role.assign authority has drifted from Founder-only';
  END IF;
END
$preconditions$;


-- =====================================================================
-- 2. Exact live role-grant directory
-- =====================================================================

CREATE FUNCTION public.team_role_grant_directory(
  p_organization_id uuid,
  p_member_id uuid DEFAULT NULL
)
RETURNS TABLE (
  grant_id uuid,
  member_id uuid,
  role_key text,
  role_label text,
  branch_id uuid,
  branch_name text,
  branch_code text,
  organization_wide boolean,
  granted_at timestamptz,
  granted_by_member_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'team_role_grant_directory: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    p_organization_id,
    'team.role.assign',
    NULL
  ) THEN
    RAISE EXCEPTION
      'team_role_grant_directory: team.role.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF p_member_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.organization_members m
       WHERE m.id = p_member_id
         AND m.organization_id = p_organization_id
     ) THEN
    RAISE EXCEPTION
      'team_role_grant_directory: target member is unavailable in this organization'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    g.id,
    g.organization_member_id,
    r.key,
    r.label,
    g.branch_id,

    CASE
      WHEN g.branch_id IS NULL
        THEN NULL::text
      ELSE b.name
    END,

    CASE
      WHEN g.branch_id IS NULL
        THEN NULL::text
      ELSE b.code
    END,

    g.branch_id IS NULL,
    g.granted_at,
    g.granted_by

  FROM public.member_role_grants g

  JOIN public.roles r
    ON r.id = g.role_id

  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id

  WHERE g.organization_id = p_organization_id
    AND g.revoked_at IS NULL
    AND (
      p_member_id IS NULL
      OR g.organization_member_id = p_member_id
    )

  ORDER BY
    g.organization_member_id,
    r.sort_order,
    r.key,
    (g.branch_id IS NOT NULL),
    b.name NULLS FIRST,
    b.code NULLS FIRST,
    g.branch_id,
    g.id;
END
$function$;

COMMENT ON FUNCTION public.team_role_grant_directory(
  uuid,
  uuid
) IS
  'Permission-aware exact live role-grant projection for canonical Team administration.';


-- =====================================================================
-- 3. Canonical role-assignment scope catalogue
-- =====================================================================

CREATE FUNCTION public.team_role_scope_catalogue(
  p_organization_id uuid
)
RETURNS TABLE (
  branch_id uuid,
  branch_name text,
  branch_code text,
  organization_wide boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'team_role_scope_catalogue: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    p_organization_id,
    'team.role.assign',
    NULL
  ) THEN
    RAISE EXCEPTION
      'team_role_scope_catalogue: team.role.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    scope.branch_id,
    scope.branch_name,
    scope.branch_code,
    scope.organization_wide

  FROM (
    SELECT
      NULL::uuid AS branch_id,
      'Organization-wide'::text AS branch_name,
      NULL::text AS branch_code,
      true AS organization_wide

    UNION ALL

    SELECT
      b.id,
      b.name,
      b.code,
      false

    FROM public.branches b

    WHERE b.organization_id = p_organization_id
      AND b.status = 'active'
      AND b.deleted_at IS NULL
      AND public.has_branch_scope(
        p_organization_id,
        b.id
      )
  ) AS scope

  ORDER BY
    scope.organization_wide DESC,
    scope.branch_name,
    scope.branch_code,
    scope.branch_id;
END
$function$;

COMMENT ON FUNCTION public.team_role_scope_catalogue(
  uuid
) IS
  'Permission-aware assignment-scope catalogue for canonical Team role administration.';


-- =====================================================================
-- 4. Explicit function privileges
-- =====================================================================

REVOKE ALL
ON FUNCTION public.team_role_grant_directory(
  uuid,
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.team_role_grant_directory(
  uuid,
  uuid
)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.team_role_scope_catalogue(
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.team_role_scope_catalogue(
  uuid
)
TO authenticated, service_role;


-- =====================================================================
-- 5. Migration validation gates
-- =====================================================================

DO $validation$
DECLARE
  v_count integer;
  v_member_grants_rls boolean;
  v_member_grants_force_rls boolean;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'team_role_grant_directory',
      'team_role_scope_catalogue'
    )
    AND p.prosecdef = true
    AND p.provolatile = 's';

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: expected two STABLE SECURITY DEFINER read-model functions';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.team_role_grant_directory(uuid,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: anon may execute team_role_grant_directory';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.team_role_scope_catalogue(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: anon may execute team_role_scope_catalogue';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       'public.team_role_grant_directory(uuid,uuid)',
       'EXECUTE'
     )
     OR NOT has_function_privilege(
       'authenticated',
       'public.team_role_scope_catalogue(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: authenticated execute privileges are incomplete';
  END IF;

  IF NOT has_function_privilege(
       'service_role',
       'public.team_role_grant_directory(uuid,uuid)',
       'EXECUTE'
     )
     OR NOT has_function_privilege(
       'service_role',
       'public.team_role_scope_catalogue(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: service_role execute privileges are incomplete';
  END IF;

  SELECT
    c.relrowsecurity,
    c.relforcerowsecurity
  INTO
    v_member_grants_rls,
    v_member_grants_force_rls
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'member_role_grants';

  IF NOT COALESCE(v_member_grants_rls, false)
     OR NOT COALESCE(v_member_grants_force_rls, false) THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: member_role_grants RLS boundary changed';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.member_role_grants',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: authenticated direct member_role_grants SELECT is available';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  JOIN public.roles r
    ON r.id = rp.role_id
  WHERE p.key = 'team.role.assign'
    AND r.key = 'founder';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: Founder team.role.assign mapping changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions rp
  JOIN public.permissions p
    ON p.id = rp.permission_id
  WHERE p.key = 'team.role.assign';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Slice 7D validation failed: team.role.assign permission matrix changed';
  END IF;
END
$validation$;

COMMIT;
