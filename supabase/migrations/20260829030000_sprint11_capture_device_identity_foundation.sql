-- =====================================================================
-- Phase 2 Studio Operations
-- Corrective Slice B0 - Capture Device Identity Foundation
--
-- Frozen boundary:
--   * one media.device.register permission;
--   * founder + studio_manager grant topology only;
--   * one canonical public.capture_devices relation;
--   * organization-scoped, case-insensitive capture-device identity;
--   * no custody, ingestion, backup, handover, booking, or journey state.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $capture_device_identity_preconditions$
DECLARE
  v_count integer;
  v_roles text[];
BEGIN
  IF to_regclass(
       'public.capture_devices'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: public.capture_devices already exists';
  END IF;

  IF to_regprocedure(
       'public.register_capture_device(uuid,text)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: register_capture_device(uuid,text) already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key =
          'media.device.register'
  ) THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: media.device.register already exists';
  END IF;

  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.role_permissions') IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: required canonical relation missing';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 69 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: expected 69 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 243 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: expected 243 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT array_agg(
           role.key
           ORDER BY role.key
         )
  INTO v_roles
  FROM public.roles role
  WHERE role.key IN (
    'founder',
    'studio_manager'
  );

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice B0 precondition failed: required role topology is %',
      v_roles;
  END IF;
END
$capture_device_identity_preconditions$;


-- =====================================================================
-- Section B - Narrow media inventory authority
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'media.device.register',
  'media',
  'Register capture devices',
  'Register approved physical capture-device identities into the canonical studio inventory.',
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
    'studio_manager'
  )
  AND permission.key =
      'media.device.register';


-- =====================================================================
-- Section C - Canonical capture-device inventory
-- =====================================================================

CREATE TABLE public.capture_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  device_code text NOT NULL,

  registered_at timestamptz NOT NULL DEFAULT now(),
  registered_by uuid NOT NULL,

  CONSTRAINT capture_devices_device_code_trimmed_chk
    CHECK (
      device_code = btrim(device_code)
    ),

  CONSTRAINT capture_devices_device_code_length_chk
    CHECK (
      char_length(device_code)
      BETWEEN 1 AND 120
    ),

  CONSTRAINT capture_devices_organization_fkey
    FOREIGN KEY (
      organization_id
    )
    REFERENCES public.organizations (
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT capture_devices_registered_by_fkey
    FOREIGN KEY (
      registered_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT capture_devices_org_id_key
    UNIQUE (
      organization_id,
      id
    )
);

CREATE UNIQUE INDEX capture_devices_org_device_code_ci_key
ON public.capture_devices (
  organization_id,
  lower(device_code)
);

CREATE INDEX capture_devices_org_registered_idx
ON public.capture_devices (
  organization_id,
  registered_at DESC
);


-- =====================================================================
-- Section D - Immutable registered identity
-- =====================================================================

CREATE FUNCTION public.lsh_capture_device_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'capture device inventory identity is immutable';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER capture_devices_immutable_guard
BEFORE UPDATE OR DELETE
ON public.capture_devices
FOR EACH ROW
EXECUTE FUNCTION public.lsh_capture_device_immutable_guard();

REVOKE ALL
ON FUNCTION public.lsh_capture_device_immutable_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.lsh_capture_device_immutable_guard()
FROM anon;

REVOKE ALL
ON FUNCTION public.lsh_capture_device_immutable_guard()
FROM authenticated;

REVOKE ALL
ON FUNCTION public.lsh_capture_device_immutable_guard()
FROM service_role;


-- =====================================================================
-- Section E - Forced RLS / authenticated read boundary
-- =====================================================================

ALTER TABLE public.capture_devices
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.capture_devices
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.capture_devices
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON TABLE public.capture_devices
FROM anon;

REVOKE ALL PRIVILEGES
ON TABLE public.capture_devices
FROM authenticated;

REVOKE ALL PRIVILEGES
ON TABLE public.capture_devices
FROM service_role;

GRANT SELECT
ON TABLE public.capture_devices
TO authenticated;

CREATE POLICY capture_devices_authenticated_select
ON public.capture_devices
FOR SELECT
TO authenticated
USING (
  public.current_organization_member(
    capture_devices.organization_id
  ) IS NOT NULL
  AND public.has_permission(
        capture_devices.organization_id,
        'media.device.register',
        NULL
      )
);


-- =====================================================================
-- Section F - Controlled capture-device registration RPC
-- =====================================================================

CREATE FUNCTION public.register_capture_device(
  p_organization_id uuid,
  p_device_code text
)
RETURNS public.capture_devices
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_device_code text;

  v_result public.capture_devices;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION
      'register_capture_device: organization_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_device_code IS NULL THEN
    RAISE EXCEPTION
      'register_capture_device: device_code is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'register_capture_device: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  v_device_code := btrim(p_device_code);

  IF v_device_code = '' THEN
    RAISE EXCEPTION
      'register_capture_device: device_code must not be empty'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(v_device_code) > 120 THEN
    RAISE EXCEPTION
      'register_capture_device: device_code must not exceed 120 characters'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Active membership + narrow authority.
  -- ---------------------------------------------------------------

  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'register_capture_device: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           p_organization_id,
           'media.device.register',
           NULL
         ) THEN
    RAISE EXCEPTION
      'register_capture_device: media.device.register permission required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical insert / concurrency-safe replay.
  --
  -- The unique expression index on:
  --   (organization_id, lower(device_code))
  -- serializes competing registrations of the same logical capture device.
  --
  -- DO NOTHING preserves the original stored casing, registered_at,
  -- and registered_by values.
  -- ---------------------------------------------------------------

  INSERT INTO public.capture_devices (
    organization_id,
    device_code,
    registered_by
  )
  VALUES (
    p_organization_id,
    v_device_code,
    v_actor
  )
  ON CONFLICT (
    organization_id,
    (lower(device_code))
  )
  DO NOTHING
  RETURNING *
  INTO v_result;

  -- ---------------------------------------------------------------
  -- Existing logical capture device = strict replay.
  --
  -- No mutation and no duplicate audit event.
  -- ---------------------------------------------------------------

  IF v_result.id IS NULL THEN
    SELECT device.*
    INTO v_result
    FROM public.capture_devices device
    WHERE device.organization_id =
          p_organization_id
      AND lower(device.device_code) =
          lower(v_device_code);

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'register_capture_device: canonical replay row unavailable'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_result;
  END IF;

  -- ---------------------------------------------------------------
  -- First-success structural audit event only.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    p_organization_id,
    NULL,
    'media.capture_device_registered',
    'capture_device',
    v_result.id,
    false,
    NULL,
    NULL,
    jsonb_build_object(
      'organization_id',
        p_organization_id,
      'capture_device_id',
        v_result.id,
      'registered_by',
        v_actor
    ),
    'application',
    NULL
  );

  RETURN v_result;
END;
$$;


-- =====================================================================
-- Section G - Registration RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.register_capture_device(uuid,text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.register_capture_device(uuid,text)
FROM anon;

REVOKE ALL
ON FUNCTION public.register_capture_device(uuid,text)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.register_capture_device(uuid,text)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.register_capture_device(uuid,text)
TO authenticated;

COMMENT ON FUNCTION public.register_capture_device(uuid,text) IS
  'Register or replay one immutable organization-scoped canonical capture-device inventory identity under media.device.register authority.';


-- =====================================================================
-- Section H - Migration assertions
-- =====================================================================

DO $capture_device_identity_assertions$
DECLARE
  v_count integer;
  v_roles text[];
  v_columns text[];
  v_definition text;
BEGIN
  -- ---------------------------------------------------------------
  -- Canonical relation and RPC exist.
  -- ---------------------------------------------------------------

  IF to_regclass(
       'public.capture_devices'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: public.capture_devices missing';
  END IF;

  IF to_regprocedure(
       'public.register_capture_device(uuid,text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: register_capture_device(uuid,text) missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Permission contract.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key =
        'media.device.register'
    AND permission.domain =
        'media'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: media.device.register contract invalid';
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
        'media.device.register';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: media.device.register role topology is %',
      v_roles;
  END IF;

  -- ---------------------------------------------------------------
  -- Exact five-column relation contract.
  -- ---------------------------------------------------------------

  SELECT array_agg(
           column_name || ':' || udt_name
           ORDER BY ordinal_position
         )
  INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name =
        'capture_devices';

  IF v_columns IS DISTINCT FROM
       ARRAY[
         'id:uuid',
         'organization_id:uuid',
         'device_code:text',
         'registered_at:timestamptz',
         'registered_by:uuid'
       ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: capture_devices column contract is %',
      v_columns;
  END IF;

  -- ---------------------------------------------------------------
  -- Required constraints.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_constraint constraint_row
  WHERE constraint_row.conrelid =
        'public.capture_devices'::regclass
    AND constraint_row.conname IN (
      'capture_devices_device_code_trimmed_chk',
      'capture_devices_device_code_length_chk',
      'capture_devices_organization_fkey',
      'capture_devices_registered_by_fkey',
      'capture_devices_org_id_key'
    );

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: required capture_devices constraints missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Case-insensitive organization-scoped identity.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_indexes index_row
  WHERE index_row.schemaname =
        'public'
    AND index_row.tablename =
        'capture_devices'
    AND index_row.indexname =
        'capture_devices_org_device_code_ci_key'
    AND index_row.indexdef ILIKE
        '%UNIQUE INDEX%'
    AND index_row.indexdef ILIKE
        '%organization_id%'
    AND index_row.indexdef ILIKE
        '%lower(device_code)%';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: case-insensitive organization-scoped capture-device identity index invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Immutability trigger.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_trigger trigger_row
  WHERE trigger_row.tgrelid =
        'public.capture_devices'::regclass
    AND trigger_row.tgname =
        'capture_devices_immutable_guard'
    AND NOT trigger_row.tgisinternal;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: capture-device immutability trigger missing';
  END IF;

  -- ---------------------------------------------------------------
  -- RLS must be enabled and forced.
  -- ---------------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.capture_devices'::regclass
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: capture_devices RLS must be enabled and forced';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_policies policy
  WHERE policy.schemaname =
        'public'
    AND policy.tablename =
        'capture_devices'
    AND policy.policyname =
        'capture_devices_authenticated_select'
    AND policy.cmd =
        'SELECT';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: authenticated capture-device read policy missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Table ACL.
  -- ---------------------------------------------------------------

  IF NOT has_table_privilege(
           'authenticated',
           'public.capture_devices',
           'SELECT'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: authenticated SELECT grant missing';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.capture_devices',
       'INSERT'
     )
     OR has_table_privilege(
          'authenticated',
          'public.capture_devices',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.capture_devices',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: authenticated direct mutation privilege leaked';
  END IF;

  IF has_table_privilege(
       'anon',
       'public.capture_devices',
       'SELECT'
     )
     OR has_table_privilege(
          'anon',
          'public.capture_devices',
          'INSERT'
        )
     OR has_table_privilege(
          'anon',
          'public.capture_devices',
          'UPDATE'
        )
     OR has_table_privilege(
          'anon',
          'public.capture_devices',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: anon capture_devices privilege leaked';
  END IF;

  -- ---------------------------------------------------------------
  -- RPC security / ACL.
  -- ---------------------------------------------------------------

  SELECT pg_get_functiondef(
           'public.register_capture_device(uuid,text)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%SECURITY DEFINER%'
     OR v_definition NOT ILIKE
       '%SET search_path TO ''''%'
     OR v_definition NOT ILIKE
       '%media.device.register%'
     OR v_definition NOT ILIKE
       '%media.capture_device_registered%' THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: registration RPC security or authority contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.register_capture_device(uuid,text)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: authenticated RPC execute grant missing';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.register_capture_device(uuid,text)',
       'EXECUTE'
     )
     OR has_function_privilege(
          'service_role',
          'public.register_capture_device(uuid,text)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: unauthorized RPC execute privilege leaked';
  END IF;

  -- ---------------------------------------------------------------
  -- Final canonical authority totals.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 70 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: expected 70 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 245 THEN
    RAISE EXCEPTION
      'Corrective Slice B0 validation failed: expected 245 role-permission mappings, found %',
      v_count;
  END IF;
END
$capture_device_identity_assertions$;
