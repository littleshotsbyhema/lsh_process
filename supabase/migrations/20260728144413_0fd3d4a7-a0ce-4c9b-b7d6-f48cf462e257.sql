-- Migration A.1: reconcile tenant foundation with canonical architecture

-- ORGANIZATIONS
ALTER TABLE public.organizations RENAME COLUMN name TO display_name;
ALTER TABLE public.organizations
  ADD COLUMN brand_prefix text,
  ADD COLUMN deleted_at timestamptz,
  ADD COLUMN created_by uuid,
  ADD COLUMN updated_by uuid;
ALTER TABLE public.organizations
  ADD CONSTRAINT organizations_brand_prefix_format_chk
  CHECK (brand_prefix IS NULL OR brand_prefix ~ '^[A-Z0-9]{2,8}$');

DROP INDEX IF EXISTS public.organizations_slug_key;
ALTER TABLE public.organizations DROP CONSTRAINT IF EXISTS organizations_slug_key;
CREATE UNIQUE INDEX organizations_slug_live_uidx
  ON public.organizations (slug) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX organizations_brand_prefix_live_uidx
  ON public.organizations (brand_prefix) WHERE deleted_at IS NULL AND brand_prefix IS NOT NULL;

-- ORGANIZATION_SETTINGS
ALTER TABLE public.organization_settings
  ADD COLUMN philosophy_statement text,
  ADD COLUMN broad_consent_reconfirmation_months integer NOT NULL DEFAULT 36,
  ADD COLUMN proposal_link_expiry_days integer NOT NULL DEFAULT 14,
  ADD COLUMN consent_link_expiry_days integer NOT NULL DEFAULT 30,
  ADD COLUMN delivery_link_expiry_days integer NOT NULL DEFAULT 90,
  ADD COLUMN updated_by uuid;
ALTER TABLE public.organization_settings
  ADD CONSTRAINT org_settings_reconfirm_months_chk CHECK (broad_consent_reconfirmation_months BETWEEN 1 AND 120),
  ADD CONSTRAINT org_settings_proposal_expiry_chk CHECK (proposal_link_expiry_days BETWEEN 1 AND 365),
  ADD CONSTRAINT org_settings_consent_expiry_chk CHECK (consent_link_expiry_days BETWEEN 1 AND 365),
  ADD CONSTRAINT org_settings_delivery_expiry_chk CHECK (delivery_link_expiry_days BETWEEN 1 AND 730);
ALTER TABLE public.organization_settings DROP COLUMN settings;

-- BRANCHES
ALTER TABLE public.branches
  ADD COLUMN phone text,
  ADD COLUMN deleted_at timestamptz,
  ADD COLUMN created_by uuid,
  ADD COLUMN updated_by uuid;
ALTER TABLE public.branches
  ADD CONSTRAINT branches_phone_format_chk
  CHECK (phone IS NULL OR (length(phone) <= 32 AND phone ~ '^[0-9 +()-]+$'));

DROP INDEX IF EXISTS public.branches_organization_id_code_key;
ALTER TABLE public.branches DROP CONSTRAINT IF EXISTS branches_organization_id_code_key;
CREATE UNIQUE INDEX branches_org_code_live_uidx
  ON public.branches (organization_id, code) WHERE deleted_at IS NULL;

-- SECURITY RE-ASSERTION
REVOKE ALL ON TABLE public.organizations FROM anon, authenticated;
REVOKE ALL ON TABLE public.organization_settings FROM anon, authenticated;
REVOKE ALL ON TABLE public.branches FROM anon, authenticated;
GRANT ALL ON TABLE public.organizations TO service_role;
GRANT ALL ON TABLE public.organization_settings TO service_role;
GRANT ALL ON TABLE public.branches TO service_role;