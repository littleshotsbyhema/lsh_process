-- =====================================================================
-- Little Shots by Hema — Memory Keeper OS
-- Wave 1A — Core Organization Baseline
--
-- Creates only:
--   - organization_status
--   - branch_status
--   - organizations
--   - organization_settings
--   - branches
--   - lsh_set_updated_at()
--   - constraints, indexes, triggers, RLS, policies and grants
--
-- Explicitly excludes:
--   - permissions and roles
--   - organization members
--   - role grants
--   - families
--   - audit catalogues
--   - legacy application tables
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Preconditions
-- ---------------------------------------------------------------------

DO $$
BEGIN
  IF to_regtype('public.organization_status') IS NOT NULL THEN
    RAISE EXCEPTION
      'Wave 1A refused: public.organization_status already exists';
  END IF;

  IF to_regtype('public.branch_status') IS NOT NULL THEN
    RAISE EXCEPTION
      'Wave 1A refused: public.branch_status already exists';
  END IF;

  IF to_regclass('public.organizations') IS NOT NULL THEN
    RAISE EXCEPTION
      'Wave 1A refused: public.organizations already exists';
  END IF;

  IF to_regclass('public.organization_settings') IS NOT NULL THEN
    RAISE EXCEPTION
      'Wave 1A refused: public.organization_settings already exists';
  END IF;

  IF to_regclass('public.branches') IS NOT NULL THEN
    RAISE EXCEPTION
      'Wave 1A refused: public.branches already exists';
  END IF;

  IF to_regprocedure('public.lsh_set_updated_at()') IS NOT NULL THEN
    RAISE EXCEPTION
      'Wave 1A refused: public.lsh_set_updated_at() already exists';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- 2. Enumerations
-- ---------------------------------------------------------------------

CREATE TYPE public.organization_status AS ENUM (
  'active',
  'suspended',
  'archived'
);

CREATE TYPE public.branch_status AS ENUM (
  'active',
  'inactive',
  'archived'
);

-- ---------------------------------------------------------------------
-- 3. Shared updated_at trigger function
-- ---------------------------------------------------------------------

CREATE FUNCTION public.lsh_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = pg_catalog.now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.lsh_set_updated_at()
FROM PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. Organizations
-- ---------------------------------------------------------------------

CREATE TABLE public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  display_name text NOT NULL,
  slug text NOT NULL,
  legal_name text,

  status public.organization_status NOT NULL DEFAULT 'active',

  currency_code text NOT NULL DEFAULT 'INR',
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  brand_prefix text,

  deleted_at timestamptz,

  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,

  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid,

  CONSTRAINT organizations_display_name_not_blank_chk
    CHECK (btrim(display_name) <> ''),

  CONSTRAINT organizations_slug_format_chk
    CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),

  CONSTRAINT organizations_slug_length_chk
    CHECK (char_length(slug) BETWEEN 3 AND 63),

  CONSTRAINT organizations_legal_name_not_blank_chk
    CHECK (legal_name IS NULL OR btrim(legal_name) <> ''),

  CONSTRAINT organizations_currency_code_format_chk
    CHECK (currency_code ~ '^[A-Z]{3}$'),

  CONSTRAINT organizations_timezone_not_blank_chk
    CHECK (btrim(timezone) <> ''),

  CONSTRAINT organizations_brand_prefix_format_chk
    CHECK (
      brand_prefix IS NULL
      OR brand_prefix ~ '^[A-Z0-9]{2,8}$'
    )
);

CREATE UNIQUE INDEX organizations_slug_live_uidx
  ON public.organizations (slug)
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX organizations_brand_prefix_live_uidx
  ON public.organizations (brand_prefix)
  WHERE deleted_at IS NULL
    AND brand_prefix IS NOT NULL;

CREATE INDEX organizations_status_idx
  ON public.organizations (status);

CREATE INDEX organizations_deleted_at_idx
  ON public.organizations (deleted_at)
  WHERE deleted_at IS NOT NULL;

CREATE TRIGGER organizations_set_updated_at
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_set_updated_at();

-- ---------------------------------------------------------------------
-- 5. Organization settings
-- ---------------------------------------------------------------------

CREATE TABLE public.organization_settings (
  organization_id uuid PRIMARY KEY,

  locale text NOT NULL DEFAULT 'en-IN',
  date_format text NOT NULL DEFAULT 'dd MMM yyyy',
  week_starts_on smallint NOT NULL DEFAULT 1,

  brand_primary_color text,
  brand_logo_url text,
  philosophy_statement text,

  broad_consent_reconfirmation_months integer NOT NULL DEFAULT 36,
  proposal_link_expiry_days integer NOT NULL DEFAULT 14,
  consent_link_expiry_days integer NOT NULL DEFAULT 30,
  delivery_link_expiry_days integer NOT NULL DEFAULT 90,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid,

  CONSTRAINT organization_settings_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT organization_settings_locale_not_blank_chk
    CHECK (btrim(locale) <> ''),

  CONSTRAINT organization_settings_date_format_not_blank_chk
    CHECK (btrim(date_format) <> ''),

  CONSTRAINT organization_settings_week_starts_on_range_chk
    CHECK (week_starts_on BETWEEN 0 AND 6),

  CONSTRAINT organization_settings_brand_primary_color_format_chk
    CHECK (
      brand_primary_color IS NULL
      OR brand_primary_color ~ '^#[0-9a-fA-F]{6}$'
    ),

  CONSTRAINT organization_settings_brand_logo_url_not_blank_chk
    CHECK (
      brand_logo_url IS NULL
      OR btrim(brand_logo_url) <> ''
    ),

  CONSTRAINT organization_settings_philosophy_statement_not_blank_chk
    CHECK (
      philosophy_statement IS NULL
      OR btrim(philosophy_statement) <> ''
    ),

  CONSTRAINT organization_settings_reconfirmation_months_chk
    CHECK (
      broad_consent_reconfirmation_months
      BETWEEN 1 AND 120
    ),

  CONSTRAINT organization_settings_proposal_expiry_days_chk
    CHECK (proposal_link_expiry_days BETWEEN 1 AND 365),

  CONSTRAINT organization_settings_consent_expiry_days_chk
    CHECK (consent_link_expiry_days BETWEEN 1 AND 365),

  CONSTRAINT organization_settings_delivery_expiry_days_chk
    CHECK (delivery_link_expiry_days BETWEEN 1 AND 730)
);

CREATE TRIGGER organization_settings_set_updated_at
  BEFORE UPDATE ON public.organization_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_set_updated_at();

-- ---------------------------------------------------------------------
-- 6. Branches
-- ---------------------------------------------------------------------

CREATE TABLE public.branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  name text NOT NULL,
  code text NOT NULL,
  status public.branch_status NOT NULL DEFAULT 'active',

  address_line1 text,
  address_line2 text,
  city text,
  state_region text,
  postal_code text,
  country_code text NOT NULL DEFAULT 'IN',
  timezone text,
  phone text,

  deleted_at timestamptz,

  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,

  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid,

  CONSTRAINT branches_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT branches_name_not_blank_chk
    CHECK (btrim(name) <> ''),

  CONSTRAINT branches_code_format_chk
    CHECK (code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),

  CONSTRAINT branches_code_length_chk
    CHECK (char_length(code) BETWEEN 2 AND 32),

  CONSTRAINT branches_country_code_format_chk
    CHECK (country_code ~ '^[A-Z]{2}$'),

  CONSTRAINT branches_timezone_not_blank_chk
    CHECK (timezone IS NULL OR btrim(timezone) <> ''),

  CONSTRAINT branches_address_line1_not_blank_chk
    CHECK (address_line1 IS NULL OR btrim(address_line1) <> ''),

  CONSTRAINT branches_address_line2_not_blank_chk
    CHECK (address_line2 IS NULL OR btrim(address_line2) <> ''),

  CONSTRAINT branches_city_not_blank_chk
    CHECK (city IS NULL OR btrim(city) <> ''),

  CONSTRAINT branches_state_region_not_blank_chk
    CHECK (state_region IS NULL OR btrim(state_region) <> ''),

  CONSTRAINT branches_postal_code_not_blank_chk
    CHECK (postal_code IS NULL OR btrim(postal_code) <> ''),

  CONSTRAINT branches_phone_format_chk
    CHECK (
      phone IS NULL
      OR (
        char_length(phone) <= 32
        AND phone ~ '^[0-9 +()-]+$'
      )
    )
);

CREATE UNIQUE INDEX branches_org_code_live_uidx
  ON public.branches (organization_id, code)
  WHERE deleted_at IS NULL;

CREATE INDEX branches_organization_id_idx
  ON public.branches (organization_id);

CREATE INDEX branches_status_idx
  ON public.branches (status);

CREATE INDEX branches_deleted_at_idx
  ON public.branches (deleted_at)
  WHERE deleted_at IS NOT NULL;

CREATE TRIGGER branches_set_updated_at
  BEFORE UPDATE ON public.branches
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_set_updated_at();

-- ---------------------------------------------------------------------
-- 7. Row-level security
-- ---------------------------------------------------------------------

ALTER TABLE public.organizations
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.organizations
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.organization_settings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.organization_settings
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.branches
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.branches
  FORCE ROW LEVEL SECURITY;

-- Temporary deny-by-default policies.
-- Membership-scoped policies arrive in a later approved migration.

CREATE POLICY organizations_deny_all_authenticated
  ON public.organizations
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY organization_settings_deny_all_authenticated
  ON public.organization_settings
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY branches_deny_all_authenticated
  ON public.branches
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

-- ---------------------------------------------------------------------
-- 8. Explicit privileges
-- ---------------------------------------------------------------------

REVOKE ALL ON TABLE public.organizations
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.organization_settings
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.branches
FROM PUBLIC, anon, authenticated, service_role;

GRANT ALL ON TABLE public.organizations
TO service_role;

GRANT ALL ON TABLE public.organization_settings
TO service_role;

GRANT ALL ON TABLE public.branches
TO service_role;

-- ---------------------------------------------------------------------
-- 9. Transaction-level validation gates
-- ---------------------------------------------------------------------

DO $$
DECLARE
  v_count integer;
BEGIN
  -- Exact enum existence.
  IF to_regtype('public.organization_status') IS NULL THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: organization_status is missing';
  END IF;

  IF to_regtype('public.branch_status') IS NULL THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: branch_status is missing';
  END IF;

  -- Exact table existence.
  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.organization_settings') IS NULL
     OR to_regclass('public.branches') IS NULL THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: one or more required tables are missing';
  END IF;

  -- Expected column counts.
  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'organizations';

  IF v_count <> 13 THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: organizations column count is %, expected 13',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'organization_settings';

  IF v_count <> 14 THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: organization_settings column count is %, expected 14',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'branches';

  IF v_count <> 18 THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: branches column count is %, expected 18',
      v_count;
  END IF;

  -- RLS must be both enabled and forced.
  SELECT count(*)
  INTO v_count
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'organizations',
      'organization_settings',
      'branches'
    )
    AND c.relrowsecurity
    AND c.relforcerowsecurity;

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: expected all 3 tables to have enabled and forced RLS';
  END IF;

  -- Exact temporary policy count.
  SELECT count(*)
  INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN (
      'organizations',
      'organization_settings',
      'branches'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: policy count is %, expected 3',
      v_count;
  END IF;

  -- Updated-at triggers.
  SELECT count(*)
  INTO v_count
  FROM pg_trigger t
  JOIN pg_class c
    ON c.oid = t.tgrelid
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'organizations',
      'organization_settings',
      'branches'
    )
    AND t.tgname IN (
      'organizations_set_updated_at',
      'organization_settings_set_updated_at',
      'branches_set_updated_at'
    )
    AND NOT t.tgisinternal;

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: updated_at trigger count is %, expected 3',
      v_count;
  END IF;

  -- Function security configuration.
  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'lsh_set_updated_at'
    AND pg_get_function_identity_arguments(p.oid) = ''
    AND NOT p.prosecdef
    AND 'search_path=""' = ANY(
      COALESCE(p.proconfig, ARRAY[]::text[])
    );

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: lsh_set_updated_at() security configuration is invalid';
  END IF;

  -- Application roles must hold no table privileges.
  IF has_table_privilege(
       'anon',
       'public.organizations',
       'SELECT,INSERT,UPDATE,DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organizations',
       'SELECT,INSERT,UPDATE,DELETE'
     )
     OR has_table_privilege(
       'anon',
       'public.organization_settings',
       'SELECT,INSERT,UPDATE,DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organization_settings',
       'SELECT,INSERT,UPDATE,DELETE'
     )
     OR has_table_privilege(
       'anon',
       'public.branches',
       'SELECT,INSERT,UPDATE,DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.branches',
       'SELECT,INSERT,UPDATE,DELETE'
     ) THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: anon or authenticated retains table privileges';
  END IF;

  -- Service role must retain table access for controlled backend use.
  IF NOT has_table_privilege(
       'service_role',
       'public.organizations',
       'SELECT,INSERT,UPDATE,DELETE'
     )
     OR NOT has_table_privilege(
       'service_role',
       'public.organization_settings',
       'SELECT,INSERT,UPDATE,DELETE'
     )
     OR NOT has_table_privilege(
       'service_role',
       'public.branches',
       'SELECT,INSERT,UPDATE,DELETE'
     ) THEN
    RAISE EXCEPTION
      'Wave 1A gate failed: service_role table privileges are incomplete';
  END IF;
END;
$$;

COMMIT;