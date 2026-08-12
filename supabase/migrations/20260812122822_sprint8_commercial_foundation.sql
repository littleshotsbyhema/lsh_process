-- =====================================================================
-- Sprint 8 — Packages, Quotations & Booking Conversion Foundation
-- Slice 1: commercial catalogue + add-ons + canonical journey catalogue
-- =====================================================================

-- ---------------------------------------------------------------------
-- Preconditions
-- ---------------------------------------------------------------------
DO $preflight$
BEGIN
  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 precondition failed: current_organization_member(uuid) missing';
  END IF;

  IF to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 precondition failed: has_permission(uuid,text,uuid) missing';
  END IF;

  IF to_regprocedure('public.lsh_set_updated_at()') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 precondition failed: lsh_set_updated_at() missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organizations
    WHERE id = '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 precondition failed: canonical organization missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles
    WHERE key = 'founder'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 precondition failed: founder role missing';
  END IF;
END
$preflight$;

-- ---------------------------------------------------------------------
-- Commercial types
-- ---------------------------------------------------------------------
CREATE TYPE public.commercial_package_tier AS ENUM (
  'bronze',
  'gold',
  'diamond',
  'emerald'
);

CREATE TYPE public.commercial_package_status AS ENUM (
  'active',
  'inactive',
  'retired'
);

CREATE TYPE public.commercial_version_approval_status AS ENUM (
  'draft',
  'approved',
  'retired'
);

CREATE TYPE public.commercial_pricing_type AS ENUM (
  'fixed_amount',
  'percentage',
  'variable'
);

-- ---------------------------------------------------------------------
-- New capabilities
-- ---------------------------------------------------------------------
INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
) VALUES
(
  'package.catalogue.manage',
  'packages',
  'Manage commercial package catalogue',
  'Create and version approved commercial packages, inclusions and add-ons.',
  true
),
(
  'commercial.price.override',
  'finance',
  'Override catalogue pricing',
  'Authorize non-catalogue or discounted quotation pricing independently of privacy or image-use consent.',
  true
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.key = 'founder'
  AND p.key IN (
    'package.catalogue.manage',
    'commercial.price.override'
  );

-- =====================================================================
-- Commercial package catalogue
-- =====================================================================

CREATE TABLE public.commercial_packages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL,
  package_key      text NOT NULL,
  service_category text NOT NULL,
  tier             public.commercial_package_tier NOT NULL,
  public_name      text NOT NULL,
  status           public.commercial_package_status NOT NULL DEFAULT 'active',
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       uuid,
  updated_at       timestamptz NOT NULL DEFAULT now(),
  updated_by       uuid,

  CONSTRAINT commercial_packages_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_packages_package_key_format_chk
    CHECK (package_key ~ '^[a-z][a-z0-9_]*$'),

  CONSTRAINT commercial_packages_service_category_format_chk
    CHECK (service_category ~ '^[a-z][a-z0-9_]*$'),

  CONSTRAINT commercial_packages_public_name_length_chk
    CHECK (char_length(public_name) BETWEEN 1 AND 160),

  CONSTRAINT commercial_packages_org_package_key_key
    UNIQUE (organization_id, package_key),

  CONSTRAINT commercial_packages_org_id_id_key
    UNIQUE (organization_id, id)
);

CREATE INDEX commercial_packages_org_category_idx
  ON public.commercial_packages (organization_id, service_category);

CREATE INDEX commercial_packages_org_status_idx
  ON public.commercial_packages (organization_id, status);


CREATE TABLE public.commercial_package_versions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    uuid NOT NULL,
  package_id         uuid NOT NULL,
  version_number     integer NOT NULL,
  currency           text NOT NULL DEFAULT 'INR',
  list_price_inr     integer NOT NULL,
  effective_from     date,
  effective_until    date,
  approval_status    public.commercial_version_approval_status
                     NOT NULL DEFAULT 'draft',
  source_document    text,
  source_revision    text,
  approved_at        timestamptz,
  approved_by        uuid,
  created_at         timestamptz NOT NULL DEFAULT now(),
  created_by         uuid,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  updated_by         uuid,

  CONSTRAINT commercial_package_versions_package_fkey
    FOREIGN KEY (organization_id, package_id)
    REFERENCES public.commercial_packages (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_package_versions_version_positive_chk
    CHECK (version_number > 0),

  CONSTRAINT commercial_package_versions_currency_chk
    CHECK (currency ~ '^[A-Z]{3}$'),

  CONSTRAINT commercial_package_versions_list_price_chk
    CHECK (list_price_inr > 0),

  CONSTRAINT commercial_package_versions_effective_dates_chk
    CHECK (
      effective_until IS NULL
      OR effective_from IS NULL
      OR effective_until >= effective_from
    ),

  CONSTRAINT commercial_package_versions_approval_metadata_chk
    CHECK (
      approval_status <> 'approved'
      OR approved_at IS NOT NULL
    ),

  CONSTRAINT commercial_package_versions_org_package_version_key
    UNIQUE (organization_id, package_id, version_number),

  CONSTRAINT commercial_package_versions_org_id_id_key
    UNIQUE (organization_id, id)
);

CREATE INDEX commercial_package_versions_package_idx
  ON public.commercial_package_versions (
    organization_id,
    package_id,
    version_number DESC
  );

CREATE INDEX commercial_package_versions_approval_idx
  ON public.commercial_package_versions (
    organization_id,
    approval_status
  );


CREATE TABLE public.commercial_package_inclusions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    uuid NOT NULL,
  package_version_id uuid NOT NULL,
  inclusion_key      text NOT NULL,
  label              text NOT NULL,
  description        text,
  quantity           numeric(12,2),
  unit               text,
  sort_order         integer NOT NULL DEFAULT 0,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  created_by         uuid,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  updated_by         uuid,

  CONSTRAINT commercial_package_inclusions_version_fkey
    FOREIGN KEY (organization_id, package_version_id)
    REFERENCES public.commercial_package_versions (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT commercial_package_inclusions_key_format_chk
    CHECK (inclusion_key ~ '^[a-z][a-z0-9_]*$'),

  CONSTRAINT commercial_package_inclusions_label_length_chk
    CHECK (char_length(label) BETWEEN 1 AND 240),

  CONSTRAINT commercial_package_inclusions_quantity_chk
    CHECK (quantity IS NULL OR quantity > 0),

  CONSTRAINT commercial_package_inclusions_metadata_object_chk
    CHECK (jsonb_typeof(metadata) = 'object'),

  CONSTRAINT commercial_package_inclusions_org_version_key_key
    UNIQUE (organization_id, package_version_id, inclusion_key)
);

CREATE INDEX commercial_package_inclusions_version_idx
  ON public.commercial_package_inclusions (
    organization_id,
    package_version_id,
    sort_order
  );

-- =====================================================================
-- Commercial add-ons
-- =====================================================================

CREATE TABLE public.commercial_addons (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id               uuid NOT NULL,
  addon_key                     text NOT NULL,
  public_name                   text NOT NULL,
  applicable_service_categories text[] NOT NULL,
  description                   text,
  status                        public.commercial_package_status
                                NOT NULL DEFAULT 'active',
  created_at                    timestamptz NOT NULL DEFAULT now(),
  created_by                    uuid,
  updated_at                    timestamptz NOT NULL DEFAULT now(),
  updated_by                    uuid,

  CONSTRAINT commercial_addons_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_addons_key_format_chk
    CHECK (addon_key ~ '^[a-z][a-z0-9_]*$'),

  CONSTRAINT commercial_addons_public_name_length_chk
    CHECK (char_length(public_name) BETWEEN 1 AND 180),

  CONSTRAINT commercial_addons_categories_chk
    CHECK (cardinality(applicable_service_categories) > 0),

  CONSTRAINT commercial_addons_org_addon_key_key
    UNIQUE (organization_id, addon_key),

  CONSTRAINT commercial_addons_org_id_id_key
    UNIQUE (organization_id, id)
);

CREATE INDEX commercial_addons_org_status_idx
  ON public.commercial_addons (organization_id, status);


CREATE TABLE public.commercial_addon_versions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL,
  addon_id         uuid NOT NULL,
  version_number   integer NOT NULL,
  approval_status  public.commercial_version_approval_status
                   NOT NULL DEFAULT 'draft',
  pricing_type     public.commercial_pricing_type NOT NULL,
  currency         text NOT NULL DEFAULT 'INR',
  amount_inr       integer,
  percentage_value numeric(7,4),
  source_document  text,
  source_revision  text,
  approved_at      timestamptz,
  approved_by      uuid,
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       uuid,
  updated_at       timestamptz NOT NULL DEFAULT now(),
  updated_by       uuid,

  CONSTRAINT commercial_addon_versions_addon_fkey
    FOREIGN KEY (organization_id, addon_id)
    REFERENCES public.commercial_addons (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_addon_versions_version_positive_chk
    CHECK (version_number > 0),

  CONSTRAINT commercial_addon_versions_currency_chk
    CHECK (currency ~ '^[A-Z]{3}$'),

  CONSTRAINT commercial_addon_versions_price_shape_chk
    CHECK (
      (
        pricing_type = 'fixed_amount'
        AND amount_inr IS NOT NULL
        AND amount_inr > 0
        AND percentage_value IS NULL
      )
      OR
      (
        pricing_type = 'percentage'
        AND amount_inr IS NULL
        AND percentage_value IS NOT NULL
        AND percentage_value > 0
        AND percentage_value <= 100
      )
      OR
      (
        pricing_type = 'variable'
        AND amount_inr IS NULL
        AND percentage_value IS NULL
      )
    ),

  CONSTRAINT commercial_addon_versions_approval_metadata_chk
    CHECK (
      approval_status <> 'approved'
      OR approved_at IS NOT NULL
    ),

  CONSTRAINT commercial_addon_versions_org_addon_version_key
    UNIQUE (organization_id, addon_id, version_number),

  CONSTRAINT commercial_addon_versions_org_id_id_key
    UNIQUE (organization_id, id)
);

CREATE INDEX commercial_addon_versions_addon_idx
  ON public.commercial_addon_versions (
    organization_id,
    addon_id,
    version_number DESC
  );

-- =====================================================================
-- Canonical 21-stage journey catalogue
-- =====================================================================

CREATE TABLE public.booking_journey_stages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  stage_key       text NOT NULL,
  stage_order     smallint NOT NULL,
  label           text NOT NULL,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,

  CONSTRAINT booking_journey_stages_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_journey_stages_key_format_chk
    CHECK (stage_key ~ '^[a-z][a-z0-9_]*$'),

  CONSTRAINT booking_journey_stages_order_chk
    CHECK (stage_order BETWEEN 1 AND 21),

  CONSTRAINT booking_journey_stages_label_length_chk
    CHECK (char_length(label) BETWEEN 1 AND 160),

  CONSTRAINT booking_journey_stages_org_stage_key_key
    UNIQUE (organization_id, stage_key),

  CONSTRAINT booking_journey_stages_org_stage_order_key
    UNIQUE (organization_id, stage_order)
);

CREATE INDEX booking_journey_stages_org_active_idx
  ON public.booking_journey_stages (
    organization_id,
    is_active,
    stage_order
  );

-- ---------------------------------------------------------------------
-- Updated-at triggers
-- ---------------------------------------------------------------------
CREATE TRIGGER commercial_packages_set_updated_at
BEFORE UPDATE ON public.commercial_packages
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER commercial_package_versions_set_updated_at
BEFORE UPDATE ON public.commercial_package_versions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER commercial_package_inclusions_set_updated_at
BEFORE UPDATE ON public.commercial_package_inclusions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER commercial_addons_set_updated_at
BEFORE UPDATE ON public.commercial_addons
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER commercial_addon_versions_set_updated_at
BEFORE UPDATE ON public.commercial_addon_versions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER booking_journey_stages_set_updated_at
BEFORE UPDATE ON public.booking_journey_stages
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

-- =====================================================================
-- Founder-approved package catalogue seed
-- Standard/list prices only.
-- Consent-conditioned source "offer prices" are intentionally NOT
-- executable commercial catalogue prices.
-- =====================================================================

INSERT INTO public.commercial_packages (
  organization_id,
  package_key,
  service_category,
  tier,
  public_name
) VALUES
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','maternity_bronze','maternity','bronze','Motherhood Glow'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','maternity_gold','maternity','gold','Radiant Motherhood'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','maternity_diamond','maternity','diamond','Eternal Glow'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','maternity_emerald','maternity','emerald','Grand Keepsake'),

('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','newborn_bronze','newborn','bronze','Tiny Beginnings'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','newborn_gold','newborn','gold','Precious Beginnings'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','newborn_diamond','newborn','diamond','Timeless Memories'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','newborn_emerald','newborn','emerald','Grand Keepsake'),

('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','sitter_bronze','sitter','bronze','Little Moments'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','sitter_gold','sitter','gold','Growing Smiles'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','sitter_diamond','sitter','diamond','Timeless Memories'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','sitter_emerald','sitter','emerald','Grand Keepsake');

INSERT INTO public.commercial_package_versions (
  organization_id,
  package_id,
  version_number,
  currency,
  list_price_inr,
  approval_status,
  source_document,
  source_revision,
  approved_at
)
SELECT
  p.organization_id,
  p.id,
  1,
  'INR',
  seed.list_price_inr,
  'approved',
  seed.source_document,
  '2026-06-client-pdfs',
  now()
FROM (
  VALUES
    ('maternity_bronze', 18000, 'Maternity Packages_LSH.pdf'),
    ('maternity_gold', 30000, 'Maternity Packages_LSH.pdf'),
    ('maternity_diamond', 42000, 'Maternity Packages_LSH.pdf'),
    ('maternity_emerald', 60000, 'Maternity Packages_LSH.pdf'),

    ('newborn_bronze', 15000, 'Newborn Packages_LSH.pdf'),
    ('newborn_gold', 25000, 'Newborn Packages_LSH.pdf'),
    ('newborn_diamond', 36000, 'Newborn Packages_LSH.pdf'),
    ('newborn_emerald', 55000, 'Newborn Packages_LSH.pdf'),

    ('sitter_bronze', 15000, 'Sitter Packages_LSH.pdf'),
    ('sitter_gold', 25000, 'Sitter Packages_LSH.pdf'),
    ('sitter_diamond', 36000, 'Sitter Packages_LSH.pdf'),
    ('sitter_emerald', 55000, 'Sitter Packages_LSH.pdf')
) AS seed(package_key, list_price_inr, source_document)
JOIN public.commercial_packages p
  ON p.organization_id =
     '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
 AND p.package_key = seed.package_key;


-- =====================================================================
-- Founder-approved structured package inclusions
-- Exact package contents are snapshotted from the approved client PDFs.
-- =====================================================================

WITH inclusion_seed(package_key, inclusions) AS (
  VALUES
  (
    'maternity_bronze',
    '[
      "2 Outfits / Looks (1 Gown provided from our wardrobe + 1 outfit from client)",
      "Couple Session Included",
      "15 Premium Retouched Images",
      "Preview Gallery for Selection (Watermarked)",
      "1 Premium 8x12 Printed Frame"
    ]'::jsonb
  ),
  (
    'maternity_gold',
    '[
      "2 Outfits / Looks (Gowns can be selected from our wardrobe)",
      "Lifestyle Session Included",
      "1 Makeup Look Included",
      "Couple Session Included",
      "Basic Gender Reveal Photos / Lying Down Pose / Backlit Setup Included",
      "20 Premium Retouched Images",
      "All Soft Copies (Unedited Moments Included)",
      "1 Premium 9x11 Album (10 Sheets / 20 Pages)",
      "1 Premium 12x18 Frame"
    ]'::jsonb
  ),
  (
    'maternity_diamond',
    '[
      "3 Outfits / Looks (Gowns can be selected from our wardrobe)",
      "Lifestyle / Standard / Saree-Based Setup Included",
      "2 Makeup Looks Included",
      "Couple Session Included",
      "Artistic Gender Reveal Photos / Lying Down Pose / Backlit Shots Included",
      "15-20 Sec Gender Reveal Video",
      "25 Premium Retouched Images",
      "All Soft Copies (Unedited Moments Included)",
      "1 Premium 9x11 Album (Up to 15 Sheets / 30 Pages)",
      "1 Premium 12x18 Frame"
    ]'::jsonb
  ),
  (
    'maternity_emerald',
    '[
      "4 Outfits / Looks (Gowns can be selected from our wardrobe)",
      "1 Signature Setup with Fresh Flowers Included",
      "3 Makeup Looks Included",
      "Artistic Gender Reveal Photos",
      "15-20 Sec Gender Reveal Video",
      "45-60 Sec Cinematic Reel",
      "35 Premium Retouched Images",
      "All Soft Copies (Unedited Moments Included)",
      "9x11 Premium Album (Up to 20 Sheets / 40 Pages)",
      "1 Signature 16x24 Frame",
      "Priority Editing (Faster Delivery)",
      "Includes all setups and poses from the Diamond package"
    ]'::jsonb
  ),
  (
    'newborn_bronze',
    '[
      "2 Creative Setups (Minimum 1 Wrap-Based Setup)",
      "1 Beanbag / Flokati Setup",
      "12 Premium Retouched Images",
      "Preview Gallery for Selection (Watermarked)",
      "1 Premium 8x12 Printed Frame"
    ]'::jsonb
  ),
  (
    'newborn_gold',
    '[
      "2 Creative Setups (Minimum 1 Wrap-Based Setup)",
      "1 Beanbag / Flokati Setup",
      "One Family Session OR Extra Creative Setup (Based on Preference)",
      "18 Premium Retouched Images",
      "All Soft Copies (Unedited Moments Included)",
      "1 Premium 12x18 Frame"
    ]'::jsonb
  ),
  (
    'newborn_diamond',
    '[
      "3 Creative Setups (Minimum 1 Wrap-Based Setup)",
      "1 Beanbag / Flokati Setup",
      "Macro Shots",
      "One Family Session OR Extra Creative Setup (Based on Preference)",
      "Mom Styling Gown Included",
      "24 Premium Retouched Images",
      "All Soft Copies (Unedited Moments Included)",
      "10x10 Premium Album (10 Sheets / 20 Pages)",
      "1 Premium 12x18 Frame"
    ]'::jsonb
  ),
  (
    'newborn_emerald',
    '[
      "4 Creative Setups (Minimum 1 Wrap-Based Setup)",
      "1 Beanbag / Flokati Setup",
      "Macro Shots",
      "One Family Session OR Extra Creative Setup (Based on Preference)",
      "Mom Styling Gown Included",
      "30 Premium Retouched Images",
      "45-60 Sec Cinematic Reel",
      "All Soft Copies (Unedited Moments Included)",
      "10x10 Premium Album (15 Sheets / 30 Pages)",
      "1 Signature 16x24 Frame",
      "Priority Editing (Faster Delivery)"
    ]'::jsonb
  ),
  (
    'sitter_bronze',
    '[
      "2 Creative Setups",
      "1 Standard Setup",
      "12 Premium Retouched Images",
      "Preview Gallery for Selection (Watermarked)",
      "1 Premium 8x12 Printed Frame"
    ]'::jsonb
  ),
  (
    'sitter_gold',
    '[
      "2 Creative Setups",
      "1 Standard Setup",
      "One Family Session OR Extra Creative Setup (Based on Preference)",
      "18 Premium Retouched Images",
      "All Soft Copies (Unedited Moments Included)",
      "1 Premium 12x18 Frame"
    ]'::jsonb
  ),
  (
    'sitter_diamond',
    '[
      "3 Creative Setups",
      "One Family Session OR Extra Creative Setup (Based on Preference)",
      "Mom Styling Gown Included",
      "25 Premium Retouched Images",
      "20-30 Sec Cinematic Reel (1 Setup)",
      "All Soft Copies (Unedited Moments Included)",
      "10x10 Premium Album (10 Sheets / 20 Pages)",
      "1 Premium 12x18 Frame"
    ]'::jsonb
  ),
  (
    'sitter_emerald',
    '[
      "4 Creative Setups",
      "One Family Session OR Extra Creative Setup (Based on Preference)",
      "Mom Styling Gown Included",
      "30 Premium Retouched Images",
      "45-60 Sec Cinematic Reel (Includes Family & 2 Setups)",
      "All Soft Copies (Unedited Moments Included)",
      "10x10 Premium Album (15 Sheets / 30 Pages)",
      "1 Signature 16x24 Frame",
      "Priority Editing (Faster Delivery)"
    ]'::jsonb
  )
)
INSERT INTO public.commercial_package_inclusions (
  organization_id,
  package_version_id,
  inclusion_key,
  label,
  sort_order
)
SELECT
  p.organization_id,
  v.id,
  'item_' || lpad(i.ordinality::text, 2, '0'),
  i.label,
  i.ordinality::integer
FROM inclusion_seed s
JOIN public.commercial_packages p
  ON p.organization_id =
     '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
 AND p.package_key = s.package_key
JOIN public.commercial_package_versions v
  ON v.organization_id = p.organization_id
 AND v.package_id = p.id
 AND v.version_number = 1
CROSS JOIN LATERAL
  jsonb_array_elements_text(s.inclusions)
  WITH ORDINALITY AS i(label, ordinality);

-- =====================================================================
-- Founder-approved structured add-on catalogue
-- =====================================================================

INSERT INTO public.commercial_addons (
  organization_id,
  addon_key,
  public_name,
  applicable_service_categories,
  description
) VALUES
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'extra_frame_8x12',
  'Extra 8x12 Frame',
  ARRAY['maternity','newborn','sitter'],
  'Additional premium 8x12 printed frame.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'extra_frame_12x18',
  'Extra 12x18 Frame',
  ARRAY['maternity','newborn','sitter'],
  'Additional premium 12x18 printed frame.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'extra_frame_16x24',
  'Extra 16x24 Frame',
  ARRAY['maternity','newborn','sitter'],
  'Additional premium 16x24 printed frame.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'extra_frame_24x36',
  'Extra 24x36 Frame',
  ARRAY['maternity','newborn','sitter'],
  'Additional premium 24x36 printed frame.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'additional_album_sheet',
  'Additional Album Sheet',
  ARRAY['maternity','newborn','sitter'],
  'Additional album sheet beyond the selected album inclusion.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'additional_image',
  'Additional Retouched Image',
  ARRAY['maternity','newborn','sitter'],
  'Additional selected image beyond package inclusions.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'album_12x12_leather_coffee_table',
  '12x12 Leather Album + Coffee Table Album',
  ARRAY['maternity','newborn','sitter'],
  '12x12 leather-cover album with complimentary coffee table album, 15 sheets / 30 pages.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'album_10x10_15_sheet',
  '10x10 Album - 15 Sheets',
  ARRAY['newborn','sitter'],
  '10x10 album with 15 sheets / 30 pages.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'additional_creative_setup',
  'Additional Creative Setup',
  ARRAY['newborn','sitter'],
  'Additional creative setup beyond package inclusions.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'macro_shots',
  'Macro Shots',
  ARRAY['newborn','sitter'],
  'Macro-detail photography add-on.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'cinematic_reel',
  'Cinematic Reel',
  ARRAY['newborn','sitter'],
  'Cinematic reel add-on.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'additional_family_member',
  'Additional Family Member',
  ARRAY['newborn','sitter'],
  'Additional family member; source package terms include two additional edited files.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'twin_handling',
  'Twin Handling',
  ARRAY['newborn','sitter'],
  'Twin-session handling charge calculated as a percentage of the selected package.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'maternity_wardrobe_gown_upgrade',
  'Wardrobe Gown Upgrade',
  ARRAY['maternity'],
  'Use a studio wardrobe gown in place of the client-provided outfit where the package terms permit.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'maternity_extra_look_saree_draping',
  'Additional Look with Hairstyle and Saree Draping',
  ARRAY['maternity'],
  'Additional maternity look involving hairstyle change and saree draping.'
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'outdoor_session_upgrade',
  'Outdoor Session Upgrade',
  ARRAY['maternity'],
  'Variable travel and convenience charges may apply; location or park entry charges are borne by the client.'
);

INSERT INTO public.commercial_addon_versions (
  organization_id,
  addon_id,
  version_number,
  approval_status,
  pricing_type,
  currency,
  amount_inr,
  percentage_value,
  source_document,
  source_revision,
  approved_at
)
SELECT
  a.organization_id,
  a.id,
  1,
  'approved',
  seed.pricing_type,
  'INR',
  seed.amount_inr,
  seed.percentage_value,
  seed.source_document,
  '2026-06-client-pdfs',
  now()
FROM (
  VALUES
    ('extra_frame_8x12',
      'fixed_amount'::public.commercial_pricing_type,
      750,
      NULL::numeric,
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('extra_frame_12x18',
      'fixed_amount'::public.commercial_pricing_type,
      1500,
      NULL::numeric,
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('extra_frame_16x24',
      'fixed_amount'::public.commercial_pricing_type,
      2500,
      NULL::numeric,
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('extra_frame_24x36',
      'fixed_amount'::public.commercial_pricing_type,
      4000,
      NULL::numeric,
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('additional_album_sheet',
      'fixed_amount'::public.commercial_pricing_type,
      500,
      NULL::numeric,
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('additional_image',
      'fixed_amount'::public.commercial_pricing_type,
      500,
      NULL::numeric,
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('album_12x12_leather_coffee_table',
      'fixed_amount'::public.commercial_pricing_type,
      10000,
      NULL::numeric,
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('album_10x10_15_sheet',
      'fixed_amount'::public.commercial_pricing_type,
      6000,
      NULL::numeric,
      'Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('additional_creative_setup',
      'fixed_amount'::public.commercial_pricing_type,
      6500,
      NULL::numeric,
      'Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('macro_shots',
      'fixed_amount'::public.commercial_pricing_type,
      4000,
      NULL::numeric,
      'Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('cinematic_reel',
      'fixed_amount'::public.commercial_pricing_type,
      5000,
      NULL::numeric,
      'Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('additional_family_member',
      'fixed_amount'::public.commercial_pricing_type,
      1000,
      NULL::numeric,
      'Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('twin_handling',
      'percentage'::public.commercial_pricing_type,
      NULL::integer,
      20::numeric,
      'Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'),

    ('maternity_wardrobe_gown_upgrade',
      'fixed_amount'::public.commercial_pricing_type,
      2000,
      NULL::numeric,
      'Maternity Packages_LSH.pdf'),

    ('maternity_extra_look_saree_draping',
      'fixed_amount'::public.commercial_pricing_type,
      2000,
      NULL::numeric,
      'Maternity Packages_LSH.pdf'),

    ('outdoor_session_upgrade',
      'variable'::public.commercial_pricing_type,
      NULL::integer,
      NULL::numeric,
      'Maternity Packages_LSH.pdf')
) AS seed(
  addon_key,
  pricing_type,
  amount_inr,
  percentage_value,
  source_document
)
JOIN public.commercial_addons a
  ON a.organization_id =
     '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
 AND a.addon_key = seed.addon_key;


-- ---------------------------------------------------------------------
-- Package-specific add-on applicability
-- Empty array means the add-on is available to any package within its
-- applicable service categories. Non-empty arrays narrow eligibility.
-- ---------------------------------------------------------------------

ALTER TABLE public.commercial_addons
ADD COLUMN applicable_package_keys text[]
NOT NULL DEFAULT '{}'::text[];

UPDATE public.commercial_addons
SET applicable_package_keys = ARRAY['maternity_bronze']
WHERE organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND addon_key = 'maternity_wardrobe_gown_upgrade';

UPDATE public.commercial_addons
SET applicable_package_keys = ARRAY['maternity_gold']
WHERE organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND addon_key = 'maternity_extra_look_saree_draping';

COMMENT ON COLUMN public.commercial_addons.applicable_package_keys IS
  'Optional package-key restriction. Empty means any package within applicable_service_categories.';

-- =====================================================================
-- Canonical 21-stage founder-approved journey
-- =====================================================================

INSERT INTO public.booking_journey_stages (
  organization_id,
  stage_key,
  stage_order,
  label
) VALUES
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','new_inquiry',1,'New Inquiry'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','details_collected',2,'Details Collected'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','memory_goal_captured',3,'Memory Goal Captured'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','package_recommended',4,'Package Recommended'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','quote_sent',5,'Quote Sent'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','follow_up_pending',6,'Follow-Up Pending'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','advance_pending',7,'Advance Pending'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','booking_confirmed',8,'Booking Confirmed'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','pre_shoot_preparation',9,'Pre-Shoot Preparation'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','shoot_scheduled',10,'Shoot Scheduled'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','shoot_completed',11,'Shoot Completed'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','selection_pending',12,'Selection Pending'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','editing_pending',13,'Editing Pending'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','editing_in_progress',14,'Editing in Progress'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','qc_pending',15,'QC Pending'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','pixieset_gallery_ready',16,'Pixieset Gallery Ready'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','delivered',17,'Delivered'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','album_frame_production',18,'Album / Frame Production'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','review_requested',19,'Review Requested'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','milestone_follow_up',20,'Milestone Follow-Up'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','completed_relationship_active',21,'Completed / Relationship Active');

-- =====================================================================
-- RLS and least privilege
-- Catalogue writes intentionally remain RPC-only in later Sprint 8
-- slices. Authenticated staff receive read access according to org
-- membership / org.read.
-- =====================================================================

ALTER TABLE public.commercial_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commercial_packages FORCE ROW LEVEL SECURITY;

ALTER TABLE public.commercial_package_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commercial_package_versions FORCE ROW LEVEL SECURITY;

ALTER TABLE public.commercial_package_inclusions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commercial_package_inclusions FORCE ROW LEVEL SECURITY;

ALTER TABLE public.commercial_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commercial_addons FORCE ROW LEVEL SECURITY;

ALTER TABLE public.commercial_addon_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commercial_addon_versions FORCE ROW LEVEL SECURITY;

ALTER TABLE public.booking_journey_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_journey_stages FORCE ROW LEVEL SECURITY;

CREATE POLICY commercial_packages_staff_read
ON public.commercial_packages
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

CREATE POLICY commercial_package_versions_staff_read
ON public.commercial_package_versions
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

CREATE POLICY commercial_package_inclusions_staff_read
ON public.commercial_package_inclusions
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

CREATE POLICY commercial_addons_staff_read
ON public.commercial_addons
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

CREATE POLICY commercial_addon_versions_staff_read
ON public.commercial_addon_versions
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

CREATE POLICY booking_journey_stages_staff_read
ON public.booking_journey_stages
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

REVOKE ALL ON TABLE
  public.commercial_packages,
  public.commercial_package_versions,
  public.commercial_package_inclusions,
  public.commercial_addons,
  public.commercial_addon_versions,
  public.booking_journey_stages
FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE
  public.commercial_packages,
  public.commercial_package_versions,
  public.commercial_package_inclusions,
  public.commercial_addons,
  public.commercial_addon_versions,
  public.booking_journey_stages
TO authenticated;

GRANT ALL ON TABLE
  public.commercial_packages,
  public.commercial_package_versions,
  public.commercial_package_inclusions,
  public.commercial_addons,
  public.commercial_addon_versions,
  public.booking_journey_stages
TO service_role;

-- ---------------------------------------------------------------------
-- Migration assertions
-- ---------------------------------------------------------------------
DO $assertions$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.permissions
  WHERE key IN (
    'package.catalogue.manage',
    'commercial.price.override'
  );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 8 gate failed: expected 2 new commercial permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_packages
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 8 gate failed: expected 12 commercial packages, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_addons
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_count <> 16 THEN
    RAISE EXCEPTION
      'Sprint 8 gate failed: expected 16 commercial add-ons, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_count <> 21 THEN
    RAISE EXCEPTION
      'Sprint 8 gate failed: expected 21 journey stages, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_package_inclusions
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_count <> 95 THEN
    RAISE EXCEPTION
      'Sprint 8 gate failed: expected 95 package inclusion rows, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_package_versions v
  WHERE v.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND v.version_number = 1
    AND NOT EXISTS (
      SELECT 1
      FROM public.commercial_package_inclusions i
      WHERE i.organization_id = v.organization_id
        AND i.package_version_id = v.id
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 8 gate failed: % seeded package versions have no inclusions',
      v_count;
  END IF;

END
$assertions$;
