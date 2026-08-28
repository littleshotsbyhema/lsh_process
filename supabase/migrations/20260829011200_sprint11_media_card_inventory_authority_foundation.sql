-- =====================================================================
-- Phase 2 Studio Operations
-- Corrective Slice A - Media Card Inventory Authority Foundation
--
-- Frozen boundary:
--   * one media.inventory.register permission;
--   * founder + studio_manager grant topology only;
--   * one canonical public.media_cards relation;
--   * organization-scoped, case-insensitive card identity;
--   * no custody, ingestion, backup, handover, booking, or journey state.
-- =====================================================================


-- =====================================================================
-- Section A - Preconditions
-- =====================================================================

DO $media_card_inventory_preconditions$
DECLARE
  v_count integer;
  v_roles text[];
BEGIN
  IF to_regclass(
       'public.media_cards'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice A precondition failed: public.media_cards already exists';
  END IF;

  IF to_regprocedure(
       'public.register_media_card(uuid,text)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Corrective Slice A precondition failed: register_media_card(uuid,text) already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key =
          'media.inventory.register'
  ) THEN
    RAISE EXCEPTION
      'Corrective Slice A precondition failed: media.inventory.register already exists';
  END IF;

  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.role_permissions') IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice A precondition failed: required canonical relation missing';
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
      'Corrective Slice A precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Corrective Slice A precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Corrective Slice A precondition failed: expected 241 role-permission mappings, found %',
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
      'Corrective Slice A precondition failed: required role topology is %',
      v_roles;
  END IF;
END
$media_card_inventory_preconditions$;


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
  'media.inventory.register',
  'media',
  'Register media cards',
  'Register approved physical media cards into the canonical studio inventory.',
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
      'media.inventory.register';


-- =====================================================================
-- Section C - Canonical media-card inventory
-- =====================================================================

CREATE TABLE public.media_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  card_code text NOT NULL,

  registered_at timestamptz NOT NULL DEFAULT now(),
  registered_by uuid NOT NULL,

  CONSTRAINT media_cards_card_code_trimmed_chk
    CHECK (
      card_code = btrim(card_code)
    ),

  CONSTRAINT media_cards_card_code_length_chk
    CHECK (
      char_length(card_code)
      BETWEEN 1 AND 120
    ),

  CONSTRAINT media_cards_organization_fkey
    FOREIGN KEY (
      organization_id
    )
    REFERENCES public.organizations (
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT media_cards_registered_by_fkey
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

  CONSTRAINT media_cards_org_id_key
    UNIQUE (
      organization_id,
      id
    )
);

CREATE UNIQUE INDEX media_cards_org_card_code_ci_key
ON public.media_cards (
  organization_id,
  lower(card_code)
);

CREATE INDEX media_cards_org_registered_idx
ON public.media_cards (
  organization_id,
  registered_at DESC
);


-- =====================================================================
-- Section D - Immutable registered identity
-- =====================================================================

CREATE FUNCTION public.lsh_media_card_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'media card inventory identity is immutable';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER media_cards_immutable_guard
BEFORE UPDATE OR DELETE
ON public.media_cards
FOR EACH ROW
EXECUTE FUNCTION public.lsh_media_card_immutable_guard();

REVOKE ALL
ON FUNCTION public.lsh_media_card_immutable_guard()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.lsh_media_card_immutable_guard()
FROM anon;

REVOKE ALL
ON FUNCTION public.lsh_media_card_immutable_guard()
FROM authenticated;

REVOKE ALL
ON FUNCTION public.lsh_media_card_immutable_guard()
FROM service_role;


-- =====================================================================
-- Section E - Forced RLS / authenticated read boundary
-- =====================================================================

ALTER TABLE public.media_cards
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.media_cards
FORCE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES
ON TABLE public.media_cards
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON TABLE public.media_cards
FROM anon;

REVOKE ALL PRIVILEGES
ON TABLE public.media_cards
FROM authenticated;

REVOKE ALL PRIVILEGES
ON TABLE public.media_cards
FROM service_role;

GRANT SELECT
ON TABLE public.media_cards
TO authenticated;

CREATE POLICY media_cards_authenticated_select
ON public.media_cards
FOR SELECT
TO authenticated
USING (
  public.current_organization_member(
    media_cards.organization_id
  ) IS NOT NULL
  AND public.has_permission(
        media_cards.organization_id,
        'media.inventory.register',
        NULL
      )
);


-- =====================================================================
-- Section F - Controlled media-card registration RPC
-- =====================================================================

CREATE FUNCTION public.register_media_card(
  p_organization_id uuid,
  p_card_code text
)
RETURNS public.media_cards
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_card_code text;

  v_result public.media_cards;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication.
  -- ---------------------------------------------------------------

  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION
      'register_media_card: organization_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_card_code IS NULL THEN
    RAISE EXCEPTION
      'register_media_card: card_code is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'register_media_card: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  v_card_code := btrim(p_card_code);

  IF v_card_code = '' THEN
    RAISE EXCEPTION
      'register_media_card: card_code must not be empty'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(v_card_code) > 120 THEN
    RAISE EXCEPTION
      'register_media_card: card_code must not exceed 120 characters'
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
      'register_media_card: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           p_organization_id,
           'media.inventory.register',
           NULL
         ) THEN
    RAISE EXCEPTION
      'register_media_card: media.inventory.register permission required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Canonical insert / concurrency-safe replay.
  --
  -- The unique expression index on:
  --   (organization_id, lower(card_code))
  -- serializes competing registrations of the same logical card.
  --
  -- DO NOTHING preserves the original stored casing, registered_at,
  -- and registered_by values.
  -- ---------------------------------------------------------------

  INSERT INTO public.media_cards (
    organization_id,
    card_code,
    registered_by
  )
  VALUES (
    p_organization_id,
    v_card_code,
    v_actor
  )
  ON CONFLICT (
    organization_id,
    (lower(card_code))
  )
  DO NOTHING
  RETURNING *
  INTO v_result;

  -- ---------------------------------------------------------------
  -- Existing logical card = strict replay.
  --
  -- No mutation and no duplicate audit event.
  -- ---------------------------------------------------------------

  IF v_result.id IS NULL THEN
    SELECT card.*
    INTO v_result
    FROM public.media_cards card
    WHERE card.organization_id =
          p_organization_id
      AND lower(card.card_code) =
          lower(v_card_code);

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'register_media_card: canonical replay row unavailable'
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
    'media.card_registered',
    'media_card',
    v_result.id,
    false,
    NULL,
    NULL,
    jsonb_build_object(
      'organization_id',
        p_organization_id,
      'media_card_id',
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
ON FUNCTION public.register_media_card(uuid,text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.register_media_card(uuid,text)
FROM anon;

REVOKE ALL
ON FUNCTION public.register_media_card(uuid,text)
FROM authenticated;

REVOKE ALL
ON FUNCTION public.register_media_card(uuid,text)
FROM service_role;

GRANT EXECUTE
ON FUNCTION public.register_media_card(uuid,text)
TO authenticated;

COMMENT ON FUNCTION public.register_media_card(uuid,text) IS
  'Register or replay one immutable organization-scoped canonical media-card inventory identity under media.inventory.register authority.';


-- =====================================================================
-- Section H - Migration assertions
-- =====================================================================

DO $media_card_inventory_assertions$
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
       'public.media_cards'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: public.media_cards missing';
  END IF;

  IF to_regprocedure(
       'public.register_media_card(uuid,text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: register_media_card(uuid,text) missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Permission contract.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.key =
        'media.inventory.register'
    AND permission.domain =
        'media'
    AND permission.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: media.inventory.register contract invalid';
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
        'media.inventory.register';

  IF v_roles IS DISTINCT FROM
       ARRAY[
         'founder',
         'studio_manager'
       ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: media.inventory.register role topology is %',
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
        'media_cards';

  IF v_columns IS DISTINCT FROM
       ARRAY[
         'id:uuid',
         'organization_id:uuid',
         'card_code:text',
         'registered_at:timestamptz',
         'registered_by:uuid'
       ]::text[] THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: media_cards column contract is %',
      v_columns;
  END IF;

  -- ---------------------------------------------------------------
  -- Required constraints.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_constraint constraint_row
  WHERE constraint_row.conrelid =
        'public.media_cards'::regclass
    AND constraint_row.conname IN (
      'media_cards_card_code_trimmed_chk',
      'media_cards_card_code_length_chk',
      'media_cards_organization_fkey',
      'media_cards_registered_by_fkey',
      'media_cards_org_id_key'
    );

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: required media_cards constraints missing';
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
        'media_cards'
    AND index_row.indexname =
        'media_cards_org_card_code_ci_key'
    AND index_row.indexdef ILIKE
        '%UNIQUE INDEX%'
    AND index_row.indexdef ILIKE
        '%organization_id%'
    AND index_row.indexdef ILIKE
        '%lower(card_code)%';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: case-insensitive organization-scoped card identity index invalid';
  END IF;

  -- ---------------------------------------------------------------
  -- Immutability trigger.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_trigger trigger_row
  WHERE trigger_row.tgrelid =
        'public.media_cards'::regclass
    AND trigger_row.tgname =
        'media_cards_immutable_guard'
    AND NOT trigger_row.tgisinternal;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: media-card immutability trigger missing';
  END IF;

  -- ---------------------------------------------------------------
  -- RLS must be enabled and forced.
  -- ---------------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.media_cards'::regclass
      AND relation.relrowsecurity
      AND relation.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: media_cards RLS must be enabled and forced';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_catalog.pg_policies policy
  WHERE policy.schemaname =
        'public'
    AND policy.tablename =
        'media_cards'
    AND policy.policyname =
        'media_cards_authenticated_select'
    AND policy.cmd =
        'SELECT';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: authenticated media-card read policy missing';
  END IF;

  -- ---------------------------------------------------------------
  -- Table ACL.
  -- ---------------------------------------------------------------

  IF NOT has_table_privilege(
           'authenticated',
           'public.media_cards',
           'SELECT'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: authenticated SELECT grant missing';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.media_cards',
       'INSERT'
     )
     OR has_table_privilege(
          'authenticated',
          'public.media_cards',
          'UPDATE'
        )
     OR has_table_privilege(
          'authenticated',
          'public.media_cards',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: authenticated direct mutation privilege leaked';
  END IF;

  IF has_table_privilege(
       'anon',
       'public.media_cards',
       'SELECT'
     )
     OR has_table_privilege(
          'anon',
          'public.media_cards',
          'INSERT'
        )
     OR has_table_privilege(
          'anon',
          'public.media_cards',
          'UPDATE'
        )
     OR has_table_privilege(
          'anon',
          'public.media_cards',
          'DELETE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: anon media_cards privilege leaked';
  END IF;

  -- ---------------------------------------------------------------
  -- RPC security / ACL.
  -- ---------------------------------------------------------------

  SELECT pg_get_functiondef(
           'public.register_media_card(uuid,text)'::regprocedure
         )
  INTO v_definition;

  IF v_definition NOT ILIKE
       '%SECURITY DEFINER%'
     OR v_definition NOT ILIKE
       '%SET search_path TO ''''%'
     OR v_definition NOT ILIKE
       '%media.inventory.register%'
     OR v_definition NOT ILIKE
       '%media.card_registered%' THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: registration RPC security or authority contract invalid';
  END IF;

  IF NOT has_function_privilege(
           'authenticated',
           'public.register_media_card(uuid,text)',
           'EXECUTE'
         ) THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: authenticated RPC execute grant missing';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.register_media_card(uuid,text)',
       'EXECUTE'
     )
     OR has_function_privilege(
          'service_role',
          'public.register_media_card(uuid,text)',
          'EXECUTE'
        ) THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: unauthorized RPC execute privilege leaked';
  END IF;

  -- ---------------------------------------------------------------
  -- Final canonical authority totals.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 69 THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: expected 69 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 243 THEN
    RAISE EXCEPTION
      'Corrective Slice A validation failed: expected 243 role-permission mappings, found %',
      v_count;
  END IF;
END
$media_card_inventory_assertions$;
