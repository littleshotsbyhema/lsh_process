-- =====================================================================
-- Sprint 11 Slice 6
-- Version-Bound Machine-Readable Image Entitlement Authority Foundation
--
-- Scope:
--   * immutable machine-readable retouched-image entitlement authority;
--   * exact package-version / add-on-version source identity;
--   * exact 12 package + 1 additional-image entitlement seed;
--   * forced RLS using existing org.read;
--   * no new permissions or role grants.
--
-- Explicitly out of scope:
--   * approved commercial catalogue mutation/backfill;
--   * runtime label parsing;
--   * booking-level entitlement reconciliation;
--   * additional-image excess/charge calculation;
--   * post-booking commercial adjustment/invoice;
--   * settlement/payment changes;
--   * Stage 12 -> 13 / editing_pending;
--   * application runtime/UI;
--   * privacy/consent.
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions + exact sourced entitlement evidence
-- =====================================================================

DO $s11s6_preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.commercial_packages') IS NULL
     OR to_regclass('public.commercial_package_versions') IS NULL
     OR to_regclass('public.commercial_package_inclusions') IS NULL
     OR to_regclass('public.commercial_addons') IS NULL
     OR to_regclass('public.commercial_addon_versions') IS NULL
     OR to_regclass(
          'public.commercial_operational_requirements'
        ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: prerequisite commercial authority missing';
  END IF;

  IF to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: has_permission(uuid,text,uuid) missing';
  END IF;

  IF to_regclass(
       'public.commercial_image_entitlements'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: commercial_image_entitlements already exists';
  END IF;

  IF to_regprocedure(
       'public.lsh_commercial_image_entitlement_guard()'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: image-entitlement guard already exists';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  -- ---------------------------------------------------------------
  -- Validate the exact 12 approved package-version source mappings.
  --
  -- The numeric entitlement is declared explicitly below. The label
  -- is validated as source evidence only; no numeric text parsing is
  -- performed.
  -- ---------------------------------------------------------------

  WITH expected (
    package_key,
    service_category,
    expected_label,
    expected_count,
    source_document
  ) AS (
    VALUES
      (
        'maternity_bronze',
        'maternity',
        '15 Premium Retouched Images',
        15,
        'Maternity Packages_LSH.pdf'
      ),
      (
        'maternity_gold',
        'maternity',
        '20 Premium Retouched Images',
        20,
        'Maternity Packages_LSH.pdf'
      ),
      (
        'maternity_diamond',
        'maternity',
        '25 Premium Retouched Images',
        25,
        'Maternity Packages_LSH.pdf'
      ),
      (
        'maternity_emerald',
        'maternity',
        '35 Premium Retouched Images',
        35,
        'Maternity Packages_LSH.pdf'
      ),
      (
        'newborn_bronze',
        'newborn',
        '12 Premium Retouched Images',
        12,
        'Newborn Packages_LSH.pdf'
      ),
      (
        'newborn_gold',
        'newborn',
        '18 Premium Retouched Images',
        18,
        'Newborn Packages_LSH.pdf'
      ),
      (
        'newborn_diamond',
        'newborn',
        '24 Premium Retouched Images',
        24,
        'Newborn Packages_LSH.pdf'
      ),
      (
        'newborn_emerald',
        'newborn',
        '30 Premium Retouched Images',
        30,
        'Newborn Packages_LSH.pdf'
      ),
      (
        'sitter_bronze',
        'sitter',
        '12 Premium Retouched Images',
        12,
        'Sitter Packages_LSH.pdf'
      ),
      (
        'sitter_gold',
        'sitter',
        '18 Premium Retouched Images',
        18,
        'Sitter Packages_LSH.pdf'
      ),
      (
        'sitter_diamond',
        'sitter',
        '25 Premium Retouched Images',
        25,
        'Sitter Packages_LSH.pdf'
      ),
      (
        'sitter_emerald',
        'sitter',
        '30 Premium Retouched Images',
        30,
        'Sitter Packages_LSH.pdf'
      )
  )
  SELECT count(*)
  INTO v_count
  FROM expected
  JOIN public.commercial_packages package
    ON package.organization_id =
       '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
   AND package.package_key =
       expected.package_key
   AND package.service_category =
       expected.service_category
   AND package.status =
       'active'::public.commercial_package_status
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       package.organization_id
   AND version.package_id =
       package.id
   AND version.version_number = 1
   AND version.approval_status =
       'approved'::public.commercial_version_approval_status
   AND version.source_document =
       expected.source_document
   AND version.source_revision =
       '2026-06-client-pdfs'
  JOIN public.commercial_package_inclusions inclusion
    ON inclusion.organization_id =
       version.organization_id
   AND inclusion.package_version_id =
       version.id
   AND inclusion.label =
       expected.expected_label
   AND inclusion.quantity IS NULL
   AND inclusion.unit IS NULL;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: expected exactly 12 approved sourced package image-entitlement mappings, found %',
      v_count;
  END IF;

  -- ---------------------------------------------------------------
  -- Validate the exact approved additional_image v1 source evidence.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.commercial_addons addon
  JOIN public.commercial_addon_versions version
    ON version.organization_id =
       addon.organization_id
   AND version.addon_id =
       addon.id
  WHERE addon.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND addon.addon_key =
        'additional_image'
    AND addon.public_name =
        'Additional Retouched Image'
    AND addon.description =
        'Additional selected image beyond package inclusions.'
    AND addon.status =
        'active'::public.commercial_package_status
    AND cardinality(
          addon.applicable_service_categories
        ) = 3
    AND addon.applicable_service_categories @>
        ARRAY[
          'maternity',
          'newborn',
          'sitter'
        ]::text[]
    AND cardinality(
          addon.applicable_package_keys
        ) = 0
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND version.pricing_type =
        'fixed_amount'::public.commercial_pricing_type
    AND version.currency = 'INR'
    AND version.amount_inr = 500
    AND version.percentage_value IS NULL
    AND version.source_document =
        'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'
    AND version.source_revision =
        '2026-06-client-pdfs';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 precondition failed: exact approved additional_image v1 evidence unavailable';
  END IF;
END
$s11s6_preconditions$;

-- =====================================================================
-- Section B — Canonical version-bound image entitlement authority
-- =====================================================================

CREATE TABLE public.commercial_image_entitlements (
  id                              uuid
                                  PRIMARY KEY
                                  DEFAULT gen_random_uuid(),

  organization_id                 uuid NOT NULL,

  package_version_id              uuid,
  addon_version_id                uuid,

  retouched_image_count_per_unit  integer NOT NULL,

  created_at                      timestamptz
                                  NOT NULL
                                  DEFAULT now(),

  CONSTRAINT commercial_image_entitlements_organization_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_image_entitlements_package_fkey
    FOREIGN KEY (
      organization_id,
      package_version_id
    )
    REFERENCES public.commercial_package_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_image_entitlements_addon_fkey
    FOREIGN KEY (
      organization_id,
      addon_version_id
    )
    REFERENCES public.commercial_addon_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_image_entitlements_source_xor_chk
    CHECK (
      (
        package_version_id IS NOT NULL
        AND addon_version_id IS NULL
      )
      OR
      (
        package_version_id IS NULL
        AND addon_version_id IS NOT NULL
      )
    ),

  CONSTRAINT commercial_image_entitlements_count_chk
    CHECK (
      retouched_image_count_per_unit > 0
    )
);

CREATE UNIQUE INDEX commercial_image_entitlements_package_uidx
ON public.commercial_image_entitlements (
  organization_id,
  package_version_id
)
WHERE package_version_id IS NOT NULL;

CREATE UNIQUE INDEX commercial_image_entitlements_addon_uidx
ON public.commercial_image_entitlements (
  organization_id,
  addon_version_id
)
WHERE addon_version_id IS NOT NULL;

-- =====================================================================
-- Section C — Approved-source creation + immutable evidence guard
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_commercial_image_entitlement_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_status public.commercial_version_approval_status;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'commercial image entitlement evidence is immutable';
  END IF;

  IF (
       NEW.package_version_id IS NULL
     ) = (
       NEW.addon_version_id IS NULL
     ) THEN
    RAISE EXCEPTION
      'commercial image entitlement requires exactly one commercial source';
  END IF;

  IF NEW.package_version_id IS NOT NULL THEN
    SELECT version.approval_status
    INTO v_status
    FROM public.commercial_package_versions version
    WHERE version.organization_id =
          NEW.organization_id
      AND version.id =
          NEW.package_version_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'commercial image entitlement package version unavailable';
    END IF;

    IF v_status <>
       'approved'::public.commercial_version_approval_status THEN
      RAISE EXCEPTION
        'commercial image entitlement requires approved package version';
    END IF;

  ELSE
    SELECT version.approval_status
    INTO v_status
    FROM public.commercial_addon_versions version
    WHERE version.organization_id =
          NEW.organization_id
      AND version.id =
          NEW.addon_version_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'commercial image entitlement add-on version unavailable';
    END IF;

    IF v_status <>
       'approved'::public.commercial_version_approval_status THEN
      RAISE EXCEPTION
        'commercial image entitlement requires approved add-on version';
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER commercial_image_entitlements_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.commercial_image_entitlements
FOR EACH ROW
EXECUTE FUNCTION public.lsh_commercial_image_entitlement_guard();

-- Trigger-only function: no application execution path.
REVOKE ALL
ON FUNCTION public.lsh_commercial_image_entitlement_guard()
FROM PUBLIC, anon, authenticated, service_role;

-- =====================================================================
-- Section D — Forced-RLS read containment
-- =====================================================================

ALTER TABLE public.commercial_image_entitlements
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.commercial_image_entitlements
FORCE ROW LEVEL SECURITY;

CREATE POLICY commercial_image_entitlements_staff_read
ON public.commercial_image_entitlements
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'org.read',
    NULL::uuid
  )
);

REVOKE ALL
ON TABLE public.commercial_image_entitlements
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.commercial_image_entitlements
TO authenticated;

-- =====================================================================
-- Section E — Exact authoritative package-version entitlement seed
--
-- Important:
--   * expected_count values below are explicit source-controlled values;
--   * the human-readable label is only matched as source evidence;
--   * no substring, regex, split, cast or other numeric label parsing
--     participates in entitlement construction.
-- =====================================================================

WITH expected (
  package_key,
  service_category,
  expected_label,
  expected_count,
  source_document
) AS (
  VALUES
    (
      'maternity_bronze',
      'maternity',
      '15 Premium Retouched Images',
      15,
      'Maternity Packages_LSH.pdf'
    ),
    (
      'maternity_gold',
      'maternity',
      '20 Premium Retouched Images',
      20,
      'Maternity Packages_LSH.pdf'
    ),
    (
      'maternity_diamond',
      'maternity',
      '25 Premium Retouched Images',
      25,
      'Maternity Packages_LSH.pdf'
    ),
    (
      'maternity_emerald',
      'maternity',
      '35 Premium Retouched Images',
      35,
      'Maternity Packages_LSH.pdf'
    ),
    (
      'newborn_bronze',
      'newborn',
      '12 Premium Retouched Images',
      12,
      'Newborn Packages_LSH.pdf'
    ),
    (
      'newborn_gold',
      'newborn',
      '18 Premium Retouched Images',
      18,
      'Newborn Packages_LSH.pdf'
    ),
    (
      'newborn_diamond',
      'newborn',
      '24 Premium Retouched Images',
      24,
      'Newborn Packages_LSH.pdf'
    ),
    (
      'newborn_emerald',
      'newborn',
      '30 Premium Retouched Images',
      30,
      'Newborn Packages_LSH.pdf'
    ),
    (
      'sitter_bronze',
      'sitter',
      '12 Premium Retouched Images',
      12,
      'Sitter Packages_LSH.pdf'
    ),
    (
      'sitter_gold',
      'sitter',
      '18 Premium Retouched Images',
      18,
      'Sitter Packages_LSH.pdf'
    ),
    (
      'sitter_diamond',
      'sitter',
      '25 Premium Retouched Images',
      25,
      'Sitter Packages_LSH.pdf'
    ),
    (
      'sitter_emerald',
      'sitter',
      '30 Premium Retouched Images',
      30,
      'Sitter Packages_LSH.pdf'
    )
)
INSERT INTO public.commercial_image_entitlements (
  organization_id,
  package_version_id,
  addon_version_id,
  retouched_image_count_per_unit
)
SELECT
  version.organization_id,
  version.id,
  NULL,
  expected.expected_count
FROM expected
JOIN public.commercial_packages package
  ON package.organization_id =
     '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
 AND package.package_key =
     expected.package_key
 AND package.service_category =
     expected.service_category
 AND package.status =
     'active'::public.commercial_package_status
JOIN public.commercial_package_versions version
  ON version.organization_id =
     package.organization_id
 AND version.package_id =
     package.id
 AND version.version_number = 1
 AND version.approval_status =
     'approved'::public.commercial_version_approval_status
 AND version.source_document =
     expected.source_document
 AND version.source_revision =
     '2026-06-client-pdfs'
JOIN public.commercial_package_inclusions inclusion
  ON inclusion.organization_id =
     version.organization_id
 AND inclusion.package_version_id =
     version.id
 AND inclusion.label =
     expected.expected_label
 AND inclusion.quantity IS NULL
 AND inclusion.unit IS NULL
ORDER BY expected.package_key;

-- =====================================================================
-- Section F — Exact additional_image v1 entitlement seed
-- =====================================================================

INSERT INTO public.commercial_image_entitlements (
  organization_id,
  package_version_id,
  addon_version_id,
  retouched_image_count_per_unit
)
SELECT
  version.organization_id,
  NULL,
  version.id,
  1
FROM public.commercial_addons addon
JOIN public.commercial_addon_versions version
  ON version.organization_id =
     addon.organization_id
 AND version.addon_id =
     addon.id
WHERE addon.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND addon.addon_key =
      'additional_image'
  AND addon.public_name =
      'Additional Retouched Image'
  AND addon.description =
      'Additional selected image beyond package inclusions.'
  AND addon.status =
      'active'::public.commercial_package_status
  AND cardinality(
        addon.applicable_service_categories
      ) = 3
  AND addon.applicable_service_categories @>
      ARRAY[
        'maternity',
        'newborn',
        'sitter'
      ]::text[]
  AND cardinality(
        addon.applicable_package_keys
      ) = 0
  AND version.version_number = 1
  AND version.approval_status =
      'approved'::public.commercial_version_approval_status
  AND version.pricing_type =
      'fixed_amount'::public.commercial_pricing_type
  AND version.currency = 'INR'
  AND version.amount_inr = 500
  AND version.percentage_value IS NULL
  AND version.source_document =
      'Maternity Packages_LSH.pdf; Newborn Packages_LSH.pdf; Sitter Packages_LSH.pdf'
  AND version.source_revision =
      '2026-06-client-pdfs';

-- =====================================================================
-- Section G — Post-migration assertions
-- =====================================================================

DO $s11s6_validation$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.commercial_image_entitlements;

  IF v_count <> 13 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: expected 13 image entitlements, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_image_entitlements
  WHERE package_version_id IS NOT NULL
    AND addon_version_id IS NULL;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: expected 12 package entitlements, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_image_entitlements
  WHERE package_version_id IS NULL
    AND addon_version_id IS NOT NULL;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: expected 1 add-on entitlement, found %',
      v_count;
  END IF;

  -- Exact package-key -> entitlement mapping.
  WITH expected (
    package_key,
    expected_count
  ) AS (
    VALUES
      ('maternity_bronze', 15),
      ('maternity_gold', 20),
      ('maternity_diamond', 25),
      ('maternity_emerald', 35),
      ('newborn_bronze', 12),
      ('newborn_gold', 18),
      ('newborn_diamond', 24),
      ('newborn_emerald', 30),
      ('sitter_bronze', 12),
      ('sitter_gold', 18),
      ('sitter_diamond', 25),
      ('sitter_emerald', 30)
  )
  SELECT count(*)
  INTO v_count
  FROM expected
  JOIN public.commercial_packages package
    ON package.organization_id =
       '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
   AND package.package_key =
       expected.package_key
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       package.organization_id
   AND version.package_id =
       package.id
   AND version.version_number = 1
   AND version.approval_status =
       'approved'::public.commercial_version_approval_status
  JOIN public.commercial_image_entitlements entitlement
    ON entitlement.organization_id =
       version.organization_id
   AND entitlement.package_version_id =
       version.id
   AND entitlement.addon_version_id IS NULL
   AND entitlement.retouched_image_count_per_unit =
       expected.expected_count;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: exact package entitlement map mismatch';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_image_entitlements entitlement
  JOIN public.commercial_addon_versions version
    ON version.organization_id =
       entitlement.organization_id
   AND version.id =
       entitlement.addon_version_id
  JOIN public.commercial_addons addon
    ON addon.organization_id =
       version.organization_id
   AND addon.id =
       version.addon_id
  WHERE addon.addon_key =
        'additional_image'
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND version.pricing_type =
        'fixed_amount'::public.commercial_pricing_type
    AND version.amount_inr = 500
    AND entitlement.package_version_id IS NULL
    AND entitlement.retouched_image_count_per_unit = 1;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: additional_image entitlement mismatch';
  END IF;

  -- Historical approved inclusion rows remain untouched.
  SELECT count(*)
  INTO v_count
  FROM public.commercial_package_inclusions inclusion
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       inclusion.organization_id
   AND version.id =
       inclusion.package_version_id
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE package.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND package.package_key IN (
      'maternity_bronze',
      'maternity_gold',
      'maternity_diamond',
      'maternity_emerald',
      'newborn_bronze',
      'newborn_gold',
      'newborn_diamond',
      'newborn_emerald',
      'sitter_bronze',
      'sitter_gold',
      'sitter_diamond',
      'sitter_emerald'
    )
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND inclusion.label ILIKE
        '%Premium Retouched Images'
    AND inclusion.quantity IS NULL
    AND inclusion.unit IS NULL;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: historical approved image inclusion evidence changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: permission catalogue changed to %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 6 validation failed: role-permission mappings changed to %',
      v_count;
  END IF;
END
$s11s6_validation$;

COMMENT ON TABLE public.commercial_image_entitlements IS
  'Immutable version-bound machine-readable retouched-image entitlement authority. Does not perform booking reconciliation, billing, settlement, privacy/consent mutation, or journey advancement.';

COMMENT ON COLUMN
  public.commercial_image_entitlements.retouched_image_count_per_unit
IS
  'Number of retouched images entitled by one unit of the referenced approved commercial package/add-on version.';
