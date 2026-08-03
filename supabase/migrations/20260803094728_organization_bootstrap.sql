BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';

-- ============================================================
-- Wave 1C — Canonical organization bootstrap
--
-- This migration:
--   1. Creates the canonical Little Shots by Hema organization
--      in a suspended bootstrap state.
--   2. Creates its organization settings.
--   3. Creates a service-role-only Founder bootstrap function.
--
-- The Founder is not attached during migration replay because
-- local Supabase does not contain the remote auth.users record.
-- After remote deployment, the bootstrap function must be called
-- with the confirmed remote Founder auth user ID.
-- ============================================================


-- ============================================================
-- 1. Preconditions
-- ============================================================

DO $$
DECLARE
  v_permissions      integer;
  v_roles            integer;
  v_role_permissions integer;
  v_founder_roles    integer;
  v_organizations    integer;
  v_settings         integer;
  v_members          integer;
  v_grants           integer;
BEGIN
  SELECT count(*)
  INTO v_permissions
  FROM public.permissions;

  IF v_permissions <> 38 THEN
    RAISE EXCEPTION
      'Organization bootstrap aborted: permissions count % does not equal 38',
      v_permissions;
  END IF;

  SELECT count(*)
  INTO v_roles
  FROM public.roles;

  IF v_roles <> 11 THEN
    RAISE EXCEPTION
      'Organization bootstrap aborted: roles count % does not equal 11',
      v_roles;
  END IF;

  SELECT count(*)
  INTO v_role_permissions
  FROM public.role_permissions;

  IF v_role_permissions <> 139 THEN
    RAISE EXCEPTION
      'Organization bootstrap aborted: role_permissions count % does not equal 139',
      v_role_permissions;
  END IF;

  SELECT count(*)
  INTO v_founder_roles
  FROM public.roles AS r
  WHERE r.key = 'founder'
    AND r.is_system_role = true;

  IF v_founder_roles <> 1 THEN
    RAISE EXCEPTION
      'Organization bootstrap aborted: expected exactly one system Founder role, found %',
      v_founder_roles;
  END IF;

  SELECT count(*)
  INTO v_organizations
  FROM public.organizations;

  SELECT count(*)
  INTO v_settings
  FROM public.organization_settings;

  SELECT count(*)
  INTO v_members
  FROM public.organization_members;

  SELECT count(*)
  INTO v_grants
  FROM public.member_role_grants;

  IF v_organizations <> 0
     OR v_settings <> 0
     OR v_members <> 0
     OR v_grants <> 0 THEN
    RAISE EXCEPTION
      'Organization bootstrap requires an empty organization substrate; organizations/settings/members/grants = %/%/%/%',
      v_organizations,
      v_settings,
      v_members,
      v_grants;
  END IF;
END
$$;


-- ============================================================
-- 2. Canonical organization
--
-- The organization starts suspended because no Founder membership
-- can be created during local migration replay.
-- ============================================================

INSERT INTO public.organizations (
  id,
  display_name,
  slug,
  legal_name,
  status,
  currency_code,
  timezone,
  brand_prefix
)
VALUES (
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'Little Shots by Hema',
  'little-shots-by-hema',
  'Little Shots by Hema',
  'suspended'::public.organization_status,
  'INR',
  'Asia/Kolkata',
  'LSH'
);


-- ============================================================
-- 3. Canonical organization settings
--
-- Remaining values intentionally use the approved Wave 1A
-- defaults until their brand and governance values are separately
-- approved.
-- ============================================================

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
);


-- ============================================================
-- 4. Controlled one-time Founder bootstrap
--
-- This function:
--   - accepts a confirmed auth.users ID and expected email;
--   - validates the canonical organization and Founder role;
--   - creates one active organization membership;
--   - creates one live organization-wide Founder grant;
--   - records the Founder member as the organization audit actor;
--   - activates the organization;
--   - enforces Founder coverage before returning.
--
-- It is executable only by service_role.
-- ============================================================

CREATE OR REPLACE FUNCTION public.lsh_bootstrap_canonical_founder(
  p_user_id        uuid,
  p_expected_email text
)
RETURNS TABLE (
  organization_id uuid,
  member_id       uuid,
  grant_id        uuid,
  user_id         uuid,
  member_created  boolean,
  grant_created   boolean,
  activated       boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_organization_id constant uuid :=
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  v_auth_email       text;
  v_email_confirmed  timestamptz;
  v_org_status       public.organization_status;
  v_org_deleted_at   timestamptz;
  v_member_id        uuid;
  v_member_status    public.member_status;
  v_role_id          uuid;
  v_grant_id         uuid;
  v_member_created   boolean := false;
  v_grant_created    boolean := false;
  v_activated        boolean := false;
  v_existing_members integer;
  v_live_founders    integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap requires a non-null auth user ID';
  END IF;

  IF p_expected_email IS NULL
     OR btrim(p_expected_email) = '' THEN
    RAISE EXCEPTION
      'Founder bootstrap requires a non-blank expected email';
  END IF;

  SELECT
    u.email,
    u.email_confirmed_at
  INTO
    v_auth_email,
    v_email_confirmed
  FROM auth.users AS u
  WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: auth user % does not exist',
      p_user_id;
  END IF;

  IF v_auth_email IS NULL
     OR lower(v_auth_email) <> lower(btrim(p_expected_email)) THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: auth user email % does not match expected email %',
      v_auth_email,
      p_expected_email;
  END IF;

  IF v_email_confirmed IS NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: auth user % has not confirmed their email',
      p_user_id;
  END IF;

  SELECT
    o.status,
    o.deleted_at
  INTO
    v_org_status,
    v_org_deleted_at
  FROM public.organizations AS o
  WHERE o.id = v_organization_id
    AND o.slug = 'little-shots-by-hema'
    AND o.display_name = 'Little Shots by Hema'
    AND o.legal_name = 'Little Shots by Hema'
    AND o.currency_code = 'INR'
    AND o.timezone = 'Asia/Kolkata'
    AND o.brand_prefix = 'LSH';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: canonical Little Shots by Hema organization is missing or does not match its approved identity';
  END IF;

  IF v_org_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: canonical organization is soft-deleted';
  END IF;

  IF v_org_status NOT IN (
    'suspended'::public.organization_status,
    'active'::public.organization_status
  ) THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: organization status % cannot be bootstrapped',
      v_org_status;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_settings AS s
    WHERE s.organization_id = v_organization_id
  ) THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: canonical organization settings row is missing';
  END IF;

  SELECT r.id
  INTO v_role_id
  FROM public.roles AS r
  WHERE r.key = 'founder'
    AND r.is_system_role = true;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: system Founder role is missing';
  END IF;

  SELECT
    m.id,
    m.status
  INTO
    v_member_id,
    v_member_status
  FROM public.organization_members AS m
  WHERE m.organization_id = v_organization_id
    AND m.user_id = p_user_id;

  IF v_member_id IS NULL THEN
    SELECT count(*)
    INTO v_existing_members
    FROM public.organization_members AS m
    WHERE m.organization_id = v_organization_id;

    IF v_existing_members <> 0 THEN
      RAISE EXCEPTION
        'Founder bootstrap failed: canonical organization already contains % member row(s)',
        v_existing_members;
    END IF;

    INSERT INTO public.organization_members (
      organization_id,
      user_id,
      status,
      email
    )
    VALUES (
      v_organization_id,
      p_user_id,
      'active'::public.member_status,
      lower(btrim(v_auth_email))
    )
    RETURNING id
    INTO v_member_id;

    v_member_created := true;

    UPDATE public.organization_members AS m
    SET
      created_by = v_member_id,
      updated_by = v_member_id
    WHERE m.id = v_member_id
      AND m.organization_id = v_organization_id;
  ELSE
    IF v_member_status <> 'active'::public.member_status THEN
      RAISE EXCEPTION
        'Founder bootstrap failed: existing membership % has status %',
        v_member_id,
        v_member_status;
    END IF;

    UPDATE public.organization_members AS m
    SET
      email = lower(btrim(v_auth_email)),
      updated_by = v_member_id
    WHERE m.id = v_member_id
      AND m.organization_id = v_organization_id;
  END IF;

  SELECT g.id
  INTO v_grant_id
  FROM public.member_role_grants AS g
  WHERE g.organization_id = v_organization_id
    AND g.organization_member_id = v_member_id
    AND g.role_id = v_role_id
    AND g.branch_id IS NULL
    AND g.revoked_at IS NULL;

  IF v_grant_id IS NULL THEN
    SELECT count(*)
    INTO v_live_founders
    FROM public.member_role_grants AS g
    JOIN public.organization_members AS m
      ON m.id = g.organization_member_id
     AND m.organization_id = g.organization_id
    JOIN public.roles AS r
      ON r.id = g.role_id
    WHERE g.organization_id = v_organization_id
      AND g.revoked_at IS NULL
      AND g.branch_id IS NULL
      AND r.key = 'founder'
      AND m.status = 'active'::public.member_status;

    IF v_live_founders <> 0 THEN
      RAISE EXCEPTION
        'Founder bootstrap failed: canonical organization already has % active organization-wide Founder grant(s)',
        v_live_founders;
    END IF;

    INSERT INTO public.member_role_grants (
      organization_id,
      organization_member_id,
      role_id,
      branch_id,
      granted_by
    )
    VALUES (
      v_organization_id,
      v_member_id,
      v_role_id,
      NULL,
      v_member_id
    )
    RETURNING id
    INTO v_grant_id;

    v_grant_created := true;
  END IF;

  UPDATE public.organizations AS o
  SET
    status = 'active'::public.organization_status,
    created_by = COALESCE(o.created_by, v_member_id),
    updated_by = v_member_id
  WHERE o.id = v_organization_id
    AND (
      o.status IS DISTINCT FROM 'active'::public.organization_status
      OR o.created_by IS NULL
      OR o.updated_by IS DISTINCT FROM v_member_id
    );

  v_activated := FOUND;

  UPDATE public.organization_settings AS s
  SET updated_by = v_member_id
  WHERE s.organization_id = v_organization_id
    AND s.updated_by IS DISTINCT FROM v_member_id;

  PERFORM public.lsh_assert_founder_coverage(v_organization_id);

  RETURN QUERY
  SELECT
    v_organization_id,
    v_member_id,
    v_grant_id,
    p_user_id,
    v_member_created,
    v_grant_created,
    v_activated;
END
$$;


-- ============================================================
-- 5. Function privileges
-- ============================================================

REVOKE ALL
  ON FUNCTION public.lsh_bootstrap_canonical_founder(uuid, text)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
  ON FUNCTION public.lsh_bootstrap_canonical_founder(uuid, text)
  TO service_role;


-- ============================================================
-- 6. Migration-state validation
--
-- At migration replay time:
--   - the canonical organization must exist;
--   - it must remain suspended;
--   - exactly one settings row must exist;
--   - no Founder membership or grant is created yet;
--   - the controlled bootstrap function must be secure.
-- ============================================================

DO $$
DECLARE
  v_count               integer;
  v_status              public.organization_status;
  v_deleted_at          timestamptz;
  v_function_is_definer boolean;
  v_function_config     text[];
BEGIN
  SELECT
    o.status,
    o.deleted_at
  INTO
    v_status,
    v_deleted_at
  FROM public.organizations AS o
  WHERE o.id = '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND o.display_name = 'Little Shots by Hema'
    AND o.slug = 'little-shots-by-hema'
    AND o.legal_name = 'Little Shots by Hema'
    AND o.currency_code = 'INR'
    AND o.timezone = 'Asia/Kolkata'
    AND o.brand_prefix = 'LSH';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Validation failed: canonical organization is missing or does not match approved values';
  END IF;

  IF v_status <> 'suspended'::public.organization_status THEN
    RAISE EXCEPTION
      'Validation failed: canonical organization status % is not suspended before Founder bootstrap',
      v_status;
  END IF;

  IF v_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION
      'Validation failed: canonical organization is soft-deleted';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.organizations;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Validation failed: organizations count % does not equal 1',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.organization_settings AS s
  WHERE s.organization_id =
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Validation failed: canonical organization settings count % does not equal 1',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.organization_members AS m
  WHERE m.organization_id =
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Validation failed: migration replay unexpectedly created % organization member row(s)',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.member_role_grants AS g
  WHERE g.organization_id =
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Validation failed: migration replay unexpectedly created % member role grant row(s)',
      v_count;
  END IF;

  SELECT
    p.prosecdef,
    p.proconfig
  INTO
    v_function_is_definer,
    v_function_config
  FROM pg_proc AS p
  JOIN pg_namespace AS n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'lsh_bootstrap_canonical_founder'
    AND pg_get_function_identity_arguments(p.oid) = 'p_user_id uuid, p_expected_email text';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Validation failed: Founder bootstrap function is missing';
  END IF;

  IF v_function_is_definer IS NOT TRUE THEN
    RAISE EXCEPTION
      'Validation failed: Founder bootstrap function is not SECURITY DEFINER';
  END IF;

  IF NOT (
    'search_path=""' = ANY(
      COALESCE(v_function_config, ARRAY[]::text[])
    )
  ) THEN
    RAISE EXCEPTION
      'Validation failed: Founder bootstrap function does not set an empty search_path';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.lsh_bootstrap_canonical_founder(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: anon can execute the Founder bootstrap function';
  END IF;

  IF has_function_privilege(
    'authenticated',
    'public.lsh_bootstrap_canonical_founder(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: authenticated can execute the Founder bootstrap function';
  END IF;

  IF NOT has_function_privilege(
    'service_role',
    'public.lsh_bootstrap_canonical_founder(uuid,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: service_role cannot execute the Founder bootstrap function';
  END IF;
END
$$;

COMMIT;