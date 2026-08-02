-- =====================================================================
-- Little Shots OS — Wave 1A, Migration A
-- Tenancy foundation: organizations, organization_settings, branches
-- Deny-by-default RLS until Migration C introduces membership.
-- =====================================================================

-- 1. Enums -----------------------------------------------------------
CREATE TYPE public.organization_status AS ENUM ('active', 'suspended', 'archived');
CREATE TYPE public.branch_status AS ENUM ('active', 'inactive', 'archived');

-- 2. Shared updated_at trigger function (namespaced, does not touch legacy touch_updated_at)
CREATE OR REPLACE FUNCTION public.lsh_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 3. organizations ---------------------------------------------------
CREATE TABLE public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL,
  legal_name text,
  status public.organization_status NOT NULL DEFAULT 'active',
  currency_code text NOT NULL DEFAULT 'INR',
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT organizations_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT organizations_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  CONSTRAINT organizations_slug_length CHECK (char_length(slug) BETWEEN 3 AND 63),
  CONSTRAINT organizations_currency_code_format CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT organizations_timezone_not_blank CHECK (btrim(timezone) <> '')
);

CREATE UNIQUE INDEX organizations_slug_key ON public.organizations (slug);
CREATE INDEX organizations_status_idx ON public.organizations (status);

GRANT ALL ON public.organizations TO service_role;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations FORCE ROW LEVEL SECURITY;
CREATE POLICY "organizations deny all (temporary, Wave 1A)"
  ON public.organizations FOR ALL TO authenticated
  USING (false) WITH CHECK (false);

CREATE TRIGGER organizations_set_updated_at
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();

-- 4. organization_settings -------------------------------------------
CREATE TABLE public.organization_settings (
  organization_id uuid PRIMARY KEY
    REFERENCES public.organizations (id) ON DELETE CASCADE,
  locale text NOT NULL DEFAULT 'en-IN',
  date_format text NOT NULL DEFAULT 'dd MMM yyyy',
  week_starts_on smallint NOT NULL DEFAULT 1,
  brand_primary_color text,
  brand_logo_url text,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT organization_settings_week_starts_on_range CHECK (week_starts_on BETWEEN 0 AND 6),
  CONSTRAINT organization_settings_locale_not_blank CHECK (btrim(locale) <> ''),
  CONSTRAINT organization_settings_brand_primary_color_format
    CHECK (brand_primary_color IS NULL OR brand_primary_color ~ '^#[0-9a-fA-F]{6}$')
);

GRANT ALL ON public.organization_settings TO service_role;
ALTER TABLE public.organization_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_settings FORCE ROW LEVEL SECURITY;
CREATE POLICY "organization_settings deny all (temporary, Wave 1A)"
  ON public.organization_settings FOR ALL TO authenticated
  USING (false) WITH CHECK (false);

CREATE TRIGGER organization_settings_set_updated_at
  BEFORE UPDATE ON public.organization_settings
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();

-- 5. branches ---------------------------------------------------------
CREATE TABLE public.branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL
    REFERENCES public.organizations (id) ON DELETE RESTRICT,
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
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT branches_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT branches_code_format CHECK (code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  CONSTRAINT branches_code_length CHECK (char_length(code) BETWEEN 2 AND 32),
  CONSTRAINT branches_country_code_format CHECK (country_code ~ '^[A-Z]{2}$')
);

CREATE UNIQUE INDEX branches_org_code_key ON public.branches (organization_id, code);
CREATE INDEX branches_organization_id_idx ON public.branches (organization_id);
CREATE INDEX branches_status_idx ON public.branches (status);

GRANT ALL ON public.branches TO service_role;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches FORCE ROW LEVEL SECURITY;
CREATE POLICY "branches deny all (temporary, Wave 1A)"
  ON public.branches FOR ALL TO authenticated
  USING (false) WITH CHECK (false);

CREATE TRIGGER branches_set_updated_at
  BEFORE UPDATE ON public.branches
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();