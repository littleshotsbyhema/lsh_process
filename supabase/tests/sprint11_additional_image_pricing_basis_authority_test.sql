CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(103);

-- =====================================================================
-- Sprint 11 Slice 8
-- Client-Favorable Additional-Image Pricing Basis Authority Foundation
--
-- Proves:
--   * exact package-version -> additional_image commercial authority;
--   * exact 12 current INR 500 protected package terms;
--   * immutable booking-level pricing-basis evidence;
--   * client_favorable_quote_or_selection_v1;
--   * A-only protected basis;
--   * lower B wins;
--   * equal B resolves to A;
--   * higher B cannot increase A;
--   * payment.record mutation authority;
--   * commercial.price.override required for B;
--   * exact Stage 12 containment;
--   * positive-excess-only basis recording;
--   * invalid B versions fail closed;
--   * exact replay idempotence;
--   * conflicting replay rejection;
--   * payment.read / branch-aware read containment;
--   * no quotation/payment/journey mutation;
--   * no adjusted obligation or settlement behavior.
-- =====================================================================


-- =====================================================================
-- Part 1 — Structural / ACL / RLS contract
-- =====================================================================

-- 1
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  69::bigint,
  'canonical permission catalogue remains exactly 69'
);

-- 2
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  243::bigint,
  'canonical role-permission mapping count remains exactly 243'
);

-- 3
SELECT ok(
  to_regclass(
    'public.commercial_package_additional_image_terms'
  ) IS NOT NULL,
  'commercial_package_additional_image_terms exists'
);

-- 4
SELECT is(
  (
    SELECT array_agg(
             column_name
             ORDER BY ordinal_position
           )::text[]
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'commercial_package_additional_image_terms'
  ),
  ARRAY[
    'id',
    'organization_id',
    'package_version_id',
    'additional_image_addon_version_id',
    'currency',
    'unit_price_inr',
    'binding_rule',
    'created_at'
  ]::text[],
  'package additional-image term authority has exactly the frozen columns'
);

-- 5
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
      'public.commercial_package_additional_image_terms'::regclass
      AND conname =
          'commercial_package_additional_image_terms_org_package_key'
      AND contype = 'u'
  ),
  'exactly one package term per organization and package version is enforced'
);

-- 6
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
      'public.commercial_package_additional_image_terms'::regclass
      AND conname =
          'commercial_package_additional_image_terms_org_id_key'
      AND contype = 'u'
  ),
  'package-term tenant-safe organization plus id identity exists'
);

-- 7
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.commercial_package_additional_image_terms'::regclass
      AND conname =
          'commercial_package_additional_image_terms_package_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, package_version_id) REFERENCES commercial_package_versions(organization_id, id)%',
  'package-term package-version FK is tenant-safe'
);

-- 8
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.commercial_package_additional_image_terms'::regclass
      AND conname =
          'commercial_package_additional_image_terms_addon_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, additional_image_addon_version_id) REFERENCES commercial_addon_versions(organization_id, id)%',
  'package-term add-on-version FK is tenant-safe'
);

-- 9
SELECT ok(
  (
    SELECT relrowsecurity
    FROM pg_class
    WHERE oid =
      'public.commercial_package_additional_image_terms'::regclass
  ),
  'package-term authority has RLS enabled'
);

-- 10
SELECT ok(
  (
    SELECT relforcerowsecurity
    FROM pg_class
    WHERE oid =
      'public.commercial_package_additional_image_terms'::regclass
  ),
  'package-term authority has forced RLS'
);

-- 11
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.commercial_package_additional_image_terms',
    'SELECT'
  ),
  'authenticated has package-term SELECT'
);

-- 12
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.commercial_package_additional_image_terms',
    'INSERT'
  ),
  'authenticated has no direct package-term INSERT'
);

-- 13
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.commercial_package_additional_image_terms',
    'UPDATE'
  ),
  'authenticated has no direct package-term UPDATE'
);

-- 14
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.commercial_package_additional_image_terms',
    'DELETE'
  ),
  'authenticated has no direct package-term DELETE'
);

-- 15
SELECT ok(
  (
    SELECT qual LIKE '%payment.read%'
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename =
          'commercial_package_additional_image_terms'
      AND policyname =
          'commercial_package_additional_image_terms_authenticated_select'
  ),
  'package-term read policy uses payment.read'
);

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger
    WHERE tgrelid =
      'public.commercial_package_additional_image_terms'::regclass
      AND tgname =
          'commercial_package_additional_image_terms_guard'
      AND NOT tgisinternal
  ),
  1::bigint,
  'exactly one package-term immutable guard exists'
);

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_package_additional_image_terms
  ),
  12::bigint,
  'exactly 12 current package-term authorities exist'
);

-- 18
SELECT is(
  (
    SELECT array_agg(
             package.package_key
             ORDER BY package.package_key
           )
    FROM public.commercial_package_additional_image_terms term
    JOIN public.commercial_package_versions version
      ON version.organization_id =
         term.organization_id
     AND version.id =
         term.package_version_id
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
  ),
  ARRAY[
    'maternity_bronze',
    'maternity_diamond',
    'maternity_emerald',
    'maternity_gold',
    'newborn_bronze',
    'newborn_diamond',
    'newborn_emerald',
    'newborn_gold',
    'sitter_bronze',
    'sitter_diamond',
    'sitter_emerald',
    'sitter_gold'
  ]::text[],
  'package terms bind exactly the frozen twelve package identities'
);

-- 19
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_package_additional_image_terms
    WHERE currency = 'INR'
      AND unit_price_inr = 500
  ),
  12::bigint,
  'all protected current package terms snapshot INR 500'
);

-- 20
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_package_additional_image_terms
    WHERE binding_rule =
      'explicit_package_additional_image_term_v1'
  ),
  12::bigint,
  'all package terms use the exact frozen binding rule'
);

-- 21
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_package_additional_image_terms term
    JOIN public.commercial_addon_versions version
      ON version.organization_id =
         term.organization_id
     AND version.id =
         term.additional_image_addon_version_id
    JOIN public.commercial_addons addon
      ON addon.organization_id =
         version.organization_id
     AND addon.id =
         version.addon_id
    WHERE addon.addon_key = 'additional_image'
      AND version.version_number = 1
      AND version.approval_status =
          'approved'::public.commercial_version_approval_status
  ),
  12::bigint,
  'all current package terms bind exact approved additional_image v1'
);

-- 22
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_package_additional_image_terms term
    JOIN public.commercial_image_entitlements entitlement
      ON entitlement.organization_id =
         term.organization_id
     AND entitlement.addon_version_id =
         term.additional_image_addon_version_id
    WHERE entitlement.retouched_image_count_per_unit = 1
  ),
  12::bigint,
  'all protected add-on versions carry exact one-image entitlement'
);

-- 23
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename =
          'booking_selection_reconciliations'
      AND indexname =
          'booking_selection_reconciliations_org_booking_id_uidx'
      AND indexdef ILIKE
          '%UNIQUE INDEX%organization_id, booking_id, id%'
  ),
  'tenant-safe reconciliation provenance support index exists'
);

-- 24
SELECT ok(
  to_regclass(
    'public.booking_additional_image_pricing_bases'
  ) IS NOT NULL,
  'booking_additional_image_pricing_bases exists'
);

-- 25
SELECT is(
  (
    SELECT array_agg(
             column_name
             ORDER BY ordinal_position
           )::text[]
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'booking_additional_image_pricing_bases'
  ),
  ARRAY[
    'id',
    'organization_id',
    'booking_id',
    'source_reconciliation_id',
    'source_quotation_id',
    'source_selection_confirmation_id',
    'source_package_version_id',
    'source_package_additional_image_term_id',
    'quote_acceptance_addon_version_id',
    'quote_acceptance_unit_price_inr',
    'selection_addon_version_id',
    'selection_unit_price_inr',
    'applied_addon_version_id',
    'applied_unit_price_inr',
    'currency',
    'pricing_rule',
    'recorded_at',
    'recorded_by'
  ]::text[],
  'booking pricing-basis evidence has exactly the frozen 18 columns'
);

-- 26
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_org_booking_key'
      AND contype = 'u'
  ),
  'exactly one pricing basis per organization and booking is enforced'
);

-- 27
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_reconciliation_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, booking_id, source_reconciliation_id) REFERENCES booking_selection_reconciliations(organization_id, booking_id, id)%',
  'pricing basis binds exact tenant plus booking plus reconciliation'
);

-- 28
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_quote_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, source_quotation_id) REFERENCES quotations(organization_id, id)%',
  'pricing-basis quotation FK is tenant-safe'
);

-- 29
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_confirmation_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, booking_id, source_selection_confirmation_id) REFERENCES booking_selection_confirmations(organization_id, booking_id, id)%',
  'pricing basis binds exact tenant plus booking plus confirmation'
);

-- 30
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_package_version_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, source_package_version_id) REFERENCES commercial_package_versions(organization_id, id)%',
  'pricing-basis package-version FK is tenant-safe'
);

-- 31
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_package_term_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, source_package_additional_image_term_id) REFERENCES commercial_package_additional_image_terms(organization_id, id)%',
  'pricing-basis package-term FK is tenant-safe'
);

-- 32
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_quote_addon_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, quote_acceptance_addon_version_id) REFERENCES commercial_addon_versions(organization_id, id)%',
  'A-side add-on-version FK is tenant-safe'
);

-- 33
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_selection_addon_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, selection_addon_version_id) REFERENCES commercial_addon_versions(organization_id, id)%',
  'B-side add-on-version FK is tenant-safe'
);

-- 34
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_applied_addon_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, applied_addon_version_id) REFERENCES commercial_addon_versions(organization_id, id)%',
  'applied add-on-version FK is tenant-safe'
);

-- 35
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(oid),
             'public.',
             ''
           )
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_recorded_by_fkey'
  ) LIKE
    'FOREIGN KEY (recorded_by, organization_id) REFERENCES organization_members(id, organization_id)%',
  'pricing-basis recorded-by FK is tenant-safe'
);

-- 36
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_selection_shape_chk'
  ),
  'B-side nullable version/price shape constraint exists'
);

-- 37
SELECT ok(
  (
    SELECT pg_get_constraintdef(oid)
    FROM pg_constraint
    WHERE conrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND conname =
          'booking_additional_image_pricing_bases_rule_chk'
  ) LIKE
    '%client_favorable_quote_or_selection_v1%',
  'pricing-basis database constraint freezes exact pricing rule'
);

-- 38
SELECT ok(
  (
    SELECT relrowsecurity
    FROM pg_class
    WHERE oid =
      'public.booking_additional_image_pricing_bases'::regclass
  ),
  'booking pricing-basis relation has RLS enabled'
);

-- 39
SELECT ok(
  (
    SELECT relforcerowsecurity
    FROM pg_class
    WHERE oid =
      'public.booking_additional_image_pricing_bases'::regclass
  ),
  'booking pricing-basis relation has forced RLS'
);

-- 40
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_additional_image_pricing_bases',
    'SELECT'
  ),
  'authenticated has pricing-basis SELECT'
);

-- 41
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_additional_image_pricing_bases',
    'INSERT'
  ),
  'authenticated has no direct pricing-basis INSERT'
);

-- 42
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_additional_image_pricing_bases',
    'UPDATE'
  ),
  'authenticated has no direct pricing-basis UPDATE'
);

-- 43
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_additional_image_pricing_bases',
    'DELETE'
  ),
  'authenticated has no direct pricing-basis DELETE'
);

-- 44
SELECT ok(
  (
    SELECT
      qual LIKE '%payment.read%'
      AND qual LIKE '%has_branch_scope%'
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename =
          'booking_additional_image_pricing_bases'
      AND policyname =
          'booking_additional_image_pricing_bases_authenticated_select'
  ),
  'booking pricing-basis read policy uses payment.read and branch containment'
);

-- 45
SELECT ok(
  to_regprocedure(
    'public.record_booking_additional_image_pricing_basis(uuid,uuid)'
  ) IS NOT NULL,
  'record_booking_additional_image_pricing_basis(uuid,uuid) exists'
);

-- 46
SELECT is(
  (
    SELECT pg_get_function_result(oid)
    FROM pg_proc
    WHERE oid =
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
  ),
  'booking_additional_image_pricing_bases'::text,
  'pricing-basis RPC returns booking_additional_image_pricing_bases'
);

-- 47
SELECT ok(
  (
    SELECT prosecdef
    FROM pg_proc
    WHERE oid =
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
  ),
  'pricing-basis RPC is SECURITY DEFINER'
);

-- 48
SELECT is(
  (
    SELECT proconfig
    FROM pg_proc
    WHERE oid =
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'pricing-basis RPC uses empty search_path'
);

-- 49
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_additional_image_pricing_basis(uuid,uuid)',
    'EXECUTE'
  ),
  'authenticated may execute pricing-basis RPC'
);

-- 50
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.record_booking_additional_image_pricing_basis(uuid,uuid)',
    'EXECUTE'
  ),
  'anon may not execute pricing-basis RPC'
);

-- 51
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.record_booking_additional_image_pricing_basis(uuid,uuid)',
    'EXECUTE'
  ),
  'service_role is not granted pricing-basis RPC'
);

-- 52
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault('f', procedure.proowner)
      )
    ) acl_entry
    WHERE procedure.oid =
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
      AND acl_entry.grantee = 0
      AND acl_entry.privilege_type = 'EXECUTE'
  ),
  'PUBLIC may not execute pricing-basis RPC'
);

-- 53
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger
    WHERE tgrelid =
      'public.booking_additional_image_pricing_bases'::regclass
      AND tgname =
          'booking_additional_image_pricing_bases_guard'
      AND NOT tgisinternal
  ),
  1::bigint,
  'exactly one pricing-basis immutable guard exists'
);

-- 54
SELECT ok(
  position(
    'source_revision'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
      )
    )
  ) = 0
  AND
  position(
    'max(version_number)'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
      )
    )
  ) = 0
  AND
  position(
    'version_number desc'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
      )
    )
  ) = 0
  AND
  position(
    'excess_image_count *'
    IN lower(
      pg_get_functiondef(
        'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
      )
    )
  ) = 0,
  'RPC has no source-revision/latest-version resolver or excess-charge multiplication'
);

-- 55
SELECT ok(
  position(
    'payment.record'
    IN pg_get_functiondef(
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
    )
  ) > 0
  AND
  position(
    'commercial.price.override'
    IN pg_get_functiondef(
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
    )
  ) > 0
  AND
  position(
    'has_branch_scope'
    IN pg_get_functiondef(
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
    )
  ) > 0
  AND
  position(
    'selection_pending'
    IN pg_get_functiondef(
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
    )
  ) > 0,
  'RPC freezes payment.record, commercial override, branch and Stage 12 authority'
);

-- 56
SELECT is(
  (
    SELECT format(
      '%s,%s',
      count(*) FILTER (
        WHERE role.key = 'founder'
      ),
      count(*)
    )
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    JOIN public.roles role
      ON role.id =
         role_permission.role_id
    WHERE permission.key IN (
      'payment.read',
      'payment.record',
      'commercial.price.override'
    )
  ),
  '3,3',
  'all three frozen finance authorities are Founder-only'
);


-- =====================================================================
-- Part 2 — Canonical fixture identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8e000000-0000-0000-0000-000000000001'::uuid),
  ('8e000000-0000-0000-0000-000000000002'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  suspended_at
)
VALUES
(
  '8e000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000001',
  'active',
  'S11S8 Founder',
  NULL
),
(
  '8e000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000002',
  'active',
  'S11S8 Photographer',
  NULL
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role.id,
  NULL::uuid
FROM (
  VALUES
    (
      '8e000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text
    ),
    (
      '8e000000-0000-0000-0000-000000000102'::uuid,
      'photographer'::text
    )
) AS fixture(member_id, role_key)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s8_set_actor(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claim.sub',
    COALESCE(p_user_id::text, ''),
    true
  );

  PERFORM set_config(
    'request.jwt.claims',
    CASE
      WHEN p_user_id IS NULL THEN '{}'
      ELSE jsonb_build_object(
        'sub',
        p_user_id,
        'role',
        'authenticated'
      )::text
    END,
    true
  );
END;
$$;

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

INSERT INTO public.families (
  id,
  organization_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES (
  '8e000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-89ABCD',
  'S11 Slice8 Family',
  'S11 Slice8 Family',
  'active',
  '8e000000-0000-0000-0000-000000000101',
  '8e000000-0000-0000-0000-000000000101'
);


-- ---------------------------------------------------------------------
-- Exact test-only commercial versions for B behavior.
--
-- Direct catalogue fixture insertion is transaction-local and is used
-- only because the production schema intentionally exposes no
-- application writer for commercial_addon_versions.
-- ---------------------------------------------------------------------

INSERT INTO public.commercial_addon_versions (
  id,
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
  fixture.id,
  addon.organization_id,
  addon.id,
  fixture.version_number,
  fixture.approval_status::public.commercial_version_approval_status,
  fixture.pricing_type::public.commercial_pricing_type,
  fixture.currency,
  fixture.amount_inr,
  fixture.percentage_value,
  'S11S8 pgTAP fixture',
  's11s8-test-only',
  fixture.approved_at
FROM public.commercial_addons addon
CROSS JOIN (
  VALUES
    (
      '8e000000-0000-0000-0000-000000000302'::uuid,
      2,
      'approved',
      'fixed_amount',
      'INR',
      400,
      NULL::numeric,
      now() - interval '1 day'
    ),
    (
      '8e000000-0000-0000-0000-000000000303'::uuid,
      3,
      'approved',
      'fixed_amount',
      'INR',
      500,
      NULL::numeric,
      now() - interval '1 day'
    ),
    (
      '8e000000-0000-0000-0000-000000000304'::uuid,
      4,
      'approved',
      'fixed_amount',
      'INR',
      600,
      NULL::numeric,
      now() - interval '1 day'
    ),
    (
      '8e000000-0000-0000-0000-000000000305'::uuid,
      5,
      'approved',
      'fixed_amount',
      'INR',
      300,
      NULL::numeric,
      now() + interval '1 day'
    ),
    (
      '8e000000-0000-0000-0000-000000000306'::uuid,
      6,
      'draft',
      'fixed_amount',
      'INR',
      300,
      NULL::numeric,
      NULL::timestamptz
    ),
    (
      '8e000000-0000-0000-0000-000000000307'::uuid,
      7,
      'approved',
      'percentage',
      'INR',
      NULL::integer,
      10::numeric,
      now() - interval '1 day'
    ),
    (
      '8e000000-0000-0000-0000-000000000308'::uuid,
      8,
      'approved',
      'fixed_amount',
      'USD',
      350,
      NULL::numeric,
      now() - interval '1 day'
    ),
    (
      '8e000000-0000-0000-0000-000000000309'::uuid,
      9,
      'approved',
      'fixed_amount',
      'INR',
      350,
      NULL::numeric,
      now() - interval '1 day'
    )
) AS fixture(
  id,
  version_number,
  approval_status,
  pricing_type,
  currency,
  amount_inr,
  percentage_value,
  approved_at
)
WHERE addon.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND addon.addon_key =
      'additional_image';

INSERT INTO public.commercial_image_entitlements (
  organization_id,
  addon_version_id,
  retouched_image_count_per_unit
)
VALUES
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000302',
  1
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000303',
  1
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000304',
  1
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000305',
  1
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000307',
  1
),
(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8e000000-0000-0000-0000-000000000308',
  1
);

CREATE TEMP TABLE s11s8_versions AS
SELECT
  (
    SELECT version.id
    FROM public.commercial_addon_versions version
    JOIN public.commercial_addons addon
      ON addon.organization_id =
         version.organization_id
     AND addon.id =
         version.addon_id
    WHERE addon.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND addon.addon_key =
          'additional_image'
      AND version.version_number = 1
  ) AS protected_v1,
  '8e000000-0000-0000-0000-000000000302'::uuid AS lower_v2,
  '8e000000-0000-0000-0000-000000000303'::uuid AS equal_v3,
  '8e000000-0000-0000-0000-000000000304'::uuid AS higher_v4,
  '8e000000-0000-0000-0000-000000000305'::uuid AS future_v5,
  '8e000000-0000-0000-0000-000000000306'::uuid AS draft_v6,
  '8e000000-0000-0000-0000-000000000307'::uuid AS percentage_v7,
  '8e000000-0000-0000-0000-000000000308'::uuid AS non_inr_v8,
  '8e000000-0000-0000-0000-000000000309'::uuid AS no_entitlement_v9,
  (
    SELECT version.id
    FROM public.commercial_addon_versions version
    JOIN public.commercial_addons addon
      ON addon.organization_id =
         version.organization_id
     AND addon.id =
         version.addon_id
    WHERE addon.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND addon.addon_key =
          'extra_frame_8x12'
      AND version.version_number = 1
  ) AS wrong_addon_v1;


-- ---------------------------------------------------------------------
-- Canonical quotation -> accepted booking fixture.
-- ---------------------------------------------------------------------

CREATE FUNCTION pg_temp.s11s8_create_booking(
  p_package_key text DEFAULT 'maternity_gold'
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote public.quotations;
  v_booking public.bookings;
  v_package_version_id uuid;
BEGIN
  SELECT version.id
  INTO v_package_version_id
  FROM public.commercial_package_versions version
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE package.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND package.package_key =
        p_package_key
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8e000000-0000-0000-0000-000000000201',
    NULL,
    NULL,
    NULL,
    NULL
  );

  PERFORM public.add_quotation_package_line(
    v_quote.id,
    v_package_version_id,
    NULL
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'ready'::public.quotation_status
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'sent'::public.quotation_status
  );

  SELECT *
  INTO v_booking
  FROM public.accept_quotation(v_quote.id);

  RETURN v_booking.id;
END;
$$;


-- ---------------------------------------------------------------------
-- Transaction-local journey fixture helper, following existing
-- Sprint 11 pgTAP convention.
-- ---------------------------------------------------------------------

CREATE FUNCTION pg_temp.s11s8_move_to_stage(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_transition_key text,
  p_transitioned_at timestamptz
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order =
        p_stage_order
    AND stage.stage_key =
        p_stage_key
    AND stage.is_active;

  INSERT INTO public.booking_stage_transitions (
    organization_id,
    booking_id,
    from_stage_id,
    to_stage_id,
    transition_key,
    transitioned_at,
    transitioned_by
  )
  VALUES (
    v_state.organization_id,
    v_state.booking_id,
    v_state.current_stage_id,
    v_target.id,
    p_transition_key,
    p_transitioned_at,
    '8e000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_target.id,
    stage_entered_at =
      GREATEST(
        p_transitioned_at,
        v_state.stage_entered_at
      ),
    version =
      state.version + 1,
    updated_at =
      p_transitioned_at,
    updated_by =
      '8e000000-0000-0000-0000-000000000101'
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE FUNCTION pg_temp.s11s8_prepare_stage12(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s8_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    's11s8_fixture_shoot_completed',
    now() - interval '3 minutes'
  );

  PERFORM pg_temp.s11s8_move_to_stage(
    p_booking_id,
    12,
    'selection_pending',
    'selection_pending',
    now() - interval '2 minutes'
  );
END;
$$;


CREATE FUNCTION pg_temp.s11s8_prepare_reconciliation(
  p_booking_id uuid,
  p_excess integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_included integer;
BEGIN
  SELECT entitlement.retouched_image_count_per_unit
  INTO v_included
  FROM public.bookings booking
  JOIN public.quotation_line_items line_item
    ON line_item.organization_id =
       booking.organization_id
   AND line_item.quotation_id =
       booking.source_quotation_id
   AND line_item.line_type =
       'package'::public.quotation_line_type
  JOIN public.commercial_image_entitlements entitlement
    ON entitlement.organization_id =
       line_item.organization_id
   AND entitlement.package_version_id =
       line_item.source_package_version_id
  WHERE booking.id =
        p_booking_id;

  PERFORM pg_temp.s11s8_prepare_stage12(
    p_booking_id
  );

  PERFORM public.record_booking_selection_confirmation(
    p_booking_id,
    v_included + p_excess,
    now() - interval '1 second'
  );

  PERFORM public.record_booking_selection_reconciliation(
    p_booking_id
  );
END;
$$;


CREATE TEMP TABLE s11s8_ids (
  a_only_booking_id uuid,
  lower_booking_id uuid,
  equal_booking_id uuid,
  higher_booking_id uuid,
  zero_booking_id uuid,
  stage11_booking_id uuid,
  no_payment_booking_id uuid,
  override_booking_id uuid,
  wrong_addon_booking_id uuid,
  future_booking_id uuid,
  draft_booking_id uuid,
  percentage_booking_id uuid,
  non_inr_booking_id uuid,
  no_entitlement_booking_id uuid,
  conflict_booking_id uuid,
  missing_a_booking_id uuid
);

INSERT INTO s11s8_ids
VALUES (
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking(),
  pg_temp.s11s8_create_booking('maternity_bronze')
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT a_only_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT lower_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT equal_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT higher_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT zero_booking_id FROM s11s8_ids),
  0
);

SELECT pg_temp.s11s8_move_to_stage(
  (SELECT stage11_booking_id FROM s11s8_ids),
  11,
  'shoot_completed',
  's11s8_fixture_shoot_completed',
  now() - interval '2 minutes'
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT no_payment_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT override_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT wrong_addon_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT future_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT draft_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT percentage_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT non_inr_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT no_entitlement_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT conflict_booking_id FROM s11s8_ids),
  3
);

SELECT pg_temp.s11s8_prepare_reconciliation(
  (SELECT missing_a_booking_id FROM s11s8_ids),
  3
);

CREATE TEMP TABLE s11s8_a_baseline AS
SELECT
  state.current_stage_id,
  state.version AS state_version,
  (
    SELECT count(*)
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.organization_id =
          booking.organization_id
      AND transition_row.booking_id =
          booking.id
  ) AS transition_count,
  quotation.quoted_total_inr,
  requirement.required_advance_inr,
  (
    SELECT count(*)
    FROM public.booking_payments payment
    WHERE payment.organization_id =
          booking.organization_id
      AND payment.booking_id =
          booking.id
  ) AS payment_count
FROM public.bookings booking
JOIN public.booking_journey_states state
  ON state.organization_id =
     booking.organization_id
 AND state.booking_id =
     booking.id
JOIN public.quotations quotation
  ON quotation.organization_id =
     booking.organization_id
 AND quotation.id =
     booking.source_quotation_id
JOIN public.booking_payment_requirements requirement
  ON requirement.organization_id =
     booking.organization_id
 AND requirement.booking_id =
     booking.id
WHERE booking.id =
  (SELECT a_only_booking_id FROM s11s8_ids);


-- =====================================================================
-- Part 3 — RPC rejection boundary
-- =====================================================================

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 57
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    NULL,
    NULL
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: booking_id is required',
  'null booking id is rejected'
);

-- 58
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    '8effffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    NULL
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: booking not found',
  'missing booking is rejected'
);

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000002'
);

-- 59
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT no_payment_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  '42501',
  'record_booking_additional_image_pricing_basis: payment.record permission required',
  'Photographer without payment.record cannot record A-only pricing basis'
);

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

-- 60
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT stage11_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: booking must be at active Stage 12 selection_pending',
  'pricing basis cannot be recorded from Stage 11'
);

-- 61
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT zero_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: positive reconciled excess is required',
  'zero-excess reconciliation cannot create pricing-basis evidence'
);


-- ---------------------------------------------------------------------
-- Temporarily remove only Founder commercial.price.override so the
-- existing Founder retains payment.record but cannot supply B.
-- The exact mapping is restored immediately after this assertion.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s11s8_override_grant AS
SELECT
  role_permission.role_id,
  role_permission.permission_id
FROM public.role_permissions role_permission
JOIN public.roles role
  ON role.id =
     role_permission.role_id
JOIN public.permissions permission
  ON permission.id =
     role_permission.permission_id
WHERE role.key = 'founder'
  AND permission.key =
      'commercial.price.override';

DELETE FROM public.role_permissions role_permission
USING public.roles role,
      public.permissions permission
WHERE role_permission.role_id =
      role.id
  AND role_permission.permission_id =
      permission.id
  AND role.key = 'founder'
  AND permission.key =
      'commercial.price.override';

-- 62
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT override_booking_id FROM s11s8_ids),
    (SELECT lower_v2 FROM s11s8_versions)
  )
  $$,
  '42501',
  'record_booking_additional_image_pricing_basis: commercial.price.override permission required for selection-time basis',
  'B-side selection requires commercial.price.override independently of payment.record'
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  role_id,
  permission_id
FROM s11s8_override_grant
ON CONFLICT (role_id, permission_id)
DO NOTHING;


-- =====================================================================
-- Part 4 — Deterministic client-favorable pricing behavior
-- =====================================================================

-- 63
SELECT lives_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT a_only_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  'A-only pricing basis records successfully'
);

-- 64
SELECT ok(
  (
    SELECT
      basis.quote_acceptance_unit_price_inr = 500
      AND basis.selection_addon_version_id IS NULL
      AND basis.selection_unit_price_inr IS NULL
      AND basis.applied_unit_price_inr = 500
      AND basis.applied_addon_version_id =
          basis.quote_acceptance_addon_version_id
      AND basis.currency = 'INR'
      AND basis.pricing_rule =
          'client_favorable_quote_or_selection_v1'
    FROM public.booking_additional_image_pricing_bases basis
    WHERE basis.booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  'A-only basis snapshots protected INR 500 and applies A'
);

-- 65
SELECT lives_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT lower_booking_id FROM s11s8_ids),
    (SELECT lower_v2 FROM s11s8_versions)
  )
  $$,
  'lower B commercial version records successfully'
);

-- 66
SELECT ok(
  (
    SELECT
      basis.quote_acceptance_unit_price_inr = 500
      AND basis.selection_addon_version_id =
          (SELECT lower_v2 FROM s11s8_versions)
      AND basis.selection_unit_price_inr = 400
      AND basis.applied_addon_version_id =
          basis.selection_addon_version_id
      AND basis.applied_unit_price_inr = 400
    FROM public.booking_additional_image_pricing_bases basis
    WHERE basis.booking_id =
      (SELECT lower_booking_id FROM s11s8_ids)
  ),
  'B lower than A wins at exact INR 400'
);

-- 67
SELECT lives_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT equal_booking_id FROM s11s8_ids),
    (SELECT equal_v3 FROM s11s8_versions)
  )
  $$,
  'equal-price B commercial version records successfully'
);

-- 68
SELECT ok(
  (
    SELECT
      basis.selection_addon_version_id =
          (SELECT equal_v3 FROM s11s8_versions)
      AND basis.selection_addon_version_id <>
          basis.quote_acceptance_addon_version_id
      AND basis.selection_unit_price_inr = 500
      AND basis.applied_unit_price_inr = 500
      AND basis.applied_addon_version_id =
          basis.quote_acceptance_addon_version_id
    FROM public.booking_additional_image_pricing_bases basis
    WHERE basis.booking_id =
      (SELECT equal_booking_id FROM s11s8_ids)
  ),
  'equal-price B resolves deterministically to A provenance'
);

-- 69
SELECT lives_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT higher_booking_id FROM s11s8_ids),
    (SELECT higher_v4 FROM s11s8_versions)
  )
  $$,
  'higher B commercial version records without increasing client price'
);

-- 70
SELECT ok(
  (
    SELECT
      basis.selection_addon_version_id =
          (SELECT higher_v4 FROM s11s8_versions)
      AND basis.selection_unit_price_inr = 600
      AND basis.applied_unit_price_inr = 500
      AND basis.applied_addon_version_id =
          basis.quote_acceptance_addon_version_id
    FROM public.booking_additional_image_pricing_bases basis
    WHERE basis.booking_id =
      (SELECT higher_booking_id FROM s11s8_ids)
  ),
  'higher B is recorded as evidence but protected A remains applied'
);


-- =====================================================================
-- Part 5 — Invalid B versions fail closed
-- =====================================================================

-- 71
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT wrong_addon_booking_id FROM s11s8_ids),
    (SELECT wrong_addon_v1 FROM s11s8_versions)
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: selection-time commercial version is invalid',
  'non-additional_image B is rejected'
);

-- 72
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT future_booking_id FROM s11s8_ids),
    (SELECT future_v5 FROM s11s8_versions)
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: selection-time commercial version is invalid',
  'B approved after immutable selection confirmation is rejected'
);

-- 73
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT draft_booking_id FROM s11s8_ids),
    (SELECT draft_v6 FROM s11s8_versions)
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: selection-time commercial version is invalid',
  'unapproved B is rejected'
);

-- 74
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT percentage_booking_id FROM s11s8_ids),
    (SELECT percentage_v7 FROM s11s8_versions)
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: selection-time commercial version is invalid',
  'non-fixed-amount B is rejected'
);

-- 75
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT non_inr_booking_id FROM s11s8_ids),
    (SELECT non_inr_v8 FROM s11s8_versions)
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: selection-time commercial version is invalid',
  'non-INR B is rejected'
);

-- 76
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT no_entitlement_booking_id FROM s11s8_ids),
    (SELECT no_entitlement_v9 FROM s11s8_versions)
  )
  $$,
  '22023',
  'record_booking_additional_image_pricing_basis: selection-time add-on requires exact one-image entitlement',
  'B without exact one-image entitlement is rejected'
);


-- =====================================================================
-- Part 6 — Replay / conflict / immutability
-- =====================================================================

-- 77
SELECT lives_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT a_only_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  'exact A-only replay is idempotent'
);

-- 78
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_additional_image_pricing_bases
    WHERE booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  1::bigint,
  'exact replay retains exactly one pricing-basis row'
);

-- 79
SELECT lives_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT conflict_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  'conflict fixture initially records canonical pricing basis'
);

ALTER TABLE public.booking_additional_image_pricing_bases
DISABLE TRIGGER USER;

UPDATE public.booking_additional_image_pricing_bases
SET applied_unit_price_inr = 499
WHERE booking_id =
  (SELECT conflict_booking_id FROM s11s8_ids);

ALTER TABLE public.booking_additional_image_pricing_bases
ENABLE TRIGGER USER;

-- 80
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT conflict_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  'P0001',
  'record_booking_additional_image_pricing_basis: conflicting immutable pricing-basis evidence already exists',
  'persisted pricing basis inconsistent with immutable sources fails closed'
);

-- 81
SELECT throws_ok(
  $$
  UPDATE public.booking_additional_image_pricing_bases
  SET applied_unit_price_inr =
      applied_unit_price_inr
  WHERE booking_id =
    (SELECT a_only_booking_id FROM s11s8_ids)
  $$,
  'P0001',
  'booking additional-image pricing-basis evidence is immutable',
  'pricing-basis evidence cannot be updated'
);

-- 82
SELECT throws_ok(
  $$
  DELETE FROM public.booking_additional_image_pricing_bases
  WHERE booking_id =
    (SELECT a_only_booking_id FROM s11s8_ids)
  $$,
  'P0001',
  'booking additional-image pricing-basis evidence is immutable',
  'pricing-basis evidence cannot be deleted'
);

-- 83
SELECT throws_ok(
  $$
  UPDATE public.commercial_package_additional_image_terms
  SET unit_price_inr =
      unit_price_inr
  WHERE package_version_id = (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'maternity_gold'
      AND version.version_number = 1
  )
  $$,
  'P0001',
  'commercial package additional-image term authority is immutable',
  'package-term authority cannot be updated'
);

-- 84
SELECT throws_ok(
  $$
  DELETE FROM public.commercial_package_additional_image_terms
  WHERE package_version_id = (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'sitter_emerald'
      AND version.version_number = 1
  )
  $$,
  'P0001',
  'commercial package additional-image term authority is immutable',
  'package-term authority cannot be deleted'
);


-- =====================================================================
-- Part 7 — Audit / financial / journey containment
-- =====================================================================

-- 85
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.additional_image_pricing_basis_recorded'
      AND audit.entity_type =
          'booking'
      AND audit.entity_id =
          (SELECT a_only_booking_id FROM s11s8_ids)
      AND NOT audit.is_sensitive
  ),
  1::bigint,
  'A-only recording writes exactly one non-sensitive structural audit event'
);

-- 86
SELECT is(
  (
    SELECT format(
      '%s,%s,%s',
      audit.new_values ->> 'applied_unit_price_inr',
      audit.new_values ->> 'pricing_rule',
      audit.metadata ->> 'quote_acceptance_unit_price_inr'
    )
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.additional_image_pricing_basis_recorded'
      AND audit.entity_id =
          (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  '500,client_favorable_quote_or_selection_v1,500',
  'audit snapshots applied rule and protected unit price'
);

-- 87
SELECT ok(
  (
    SELECT NOT (
      COALESCE(audit.new_values, '{}'::jsonb)
        ?| ARRAY[
          'excess_charge_inr',
          'adjusted_total_inr',
          'amount_due',
          'balance_due',
          'settlement_status'
        ]
      OR
      COALESCE(audit.metadata, '{}'::jsonb)
        ?| ARRAY[
          'excess_charge_inr',
          'adjusted_total_inr',
          'amount_due',
          'balance_due',
          'settlement_status'
        ]
    )
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.additional_image_pricing_basis_recorded'
      AND audit.entity_id =
          (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  'pricing-basis audit contains no adjusted-obligation or settlement fields'
);

-- 88
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  (
    SELECT state_version
    FROM s11s8_a_baseline
  ),
  'pricing-basis recording does not change journey-state version'
);

-- 89
SELECT is(
  (
    SELECT state.current_stage_id
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  (
    SELECT current_stage_id
    FROM s11s8_a_baseline
  ),
  'pricing-basis recording does not change current journey stage'
);

-- 90
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  (
    SELECT transition_count::bigint
    FROM s11s8_a_baseline
  ),
  'pricing-basis recording creates no booking-stage transition'
);

-- 91
SELECT is(
  (
    SELECT quotation.quoted_total_inr
    FROM public.bookings booking
    JOIN public.quotations quotation
      ON quotation.organization_id =
         booking.organization_id
     AND quotation.id =
         booking.source_quotation_id
    WHERE booking.id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  (
    SELECT quoted_total_inr
    FROM s11s8_a_baseline
  ),
  'accepted quotation total remains unchanged'
);

-- 92
SELECT is(
  (
    SELECT requirement.required_advance_inr
    FROM public.booking_payment_requirements requirement
    WHERE requirement.booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  (
    SELECT required_advance_inr
    FROM s11s8_a_baseline
  ),
  'accepted-quotation advance requirement remains unchanged'
);

-- 93
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_payments payment
    WHERE payment.booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  (
    SELECT payment_count::bigint
    FROM s11s8_a_baseline
  ),
  'pricing-basis recording creates no booking payment'
);

-- 94
SELECT is(
  (
    SELECT stage.stage_order
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  12::smallint,
  'pricing-basis booking remains exact Stage 12'
);

-- 95
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         transition_row.organization_id
     AND stage.id =
         transition_row.to_stage_id
    WHERE transition_row.booking_id =
          (SELECT a_only_booking_id FROM s11s8_ids)
      AND stage.stage_order = 13
      AND stage.stage_key =
          'editing_pending'
  ),
  0::bigint,
  'pricing-basis recording creates no Stage 12 to 13 editing transition'
);


-- =====================================================================
-- Part 8 — Runtime read containment
-- =====================================================================

GRANT SELECT
ON TABLE s11s8_ids
TO authenticated;

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

SET LOCAL ROLE authenticated;

-- 96
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_additional_image_pricing_bases
    WHERE booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  1::bigint,
  'Founder with payment.read can read booking pricing-basis evidence'
);

RESET ROLE;

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000002'
);

SET LOCAL ROLE authenticated;

-- 97
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_additional_image_pricing_bases
    WHERE booking_id =
      (SELECT a_only_booking_id FROM s11s8_ids)
  ),
  0::bigint,
  'Photographer without payment.read cannot read pricing-basis evidence'
);

RESET ROLE;

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);

SET LOCAL ROLE authenticated;

-- 98
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_package_additional_image_terms
  ),
  12::bigint,
  'Founder with payment.read can read protected package-term authority'
);

RESET ROLE;

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000002'
);

SET LOCAL ROLE authenticated;

-- 99
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_package_additional_image_terms
  ),
  0::bigint,
  'Photographer without payment.read cannot read protected package terms'
);

RESET ROLE;

SELECT pg_temp.s11s8_set_actor(
  '8e000000-0000-0000-0000-000000000001'
);


-- =====================================================================
-- Part 9 — Missing A authority / final containment
-- =====================================================================

ALTER TABLE public.commercial_package_additional_image_terms
DISABLE TRIGGER USER;

DELETE FROM public.commercial_package_additional_image_terms term
USING
  public.commercial_package_versions version,
  public.commercial_packages package
WHERE term.organization_id =
      version.organization_id
  AND term.package_version_id =
      version.id
  AND version.organization_id =
      package.organization_id
  AND version.package_id =
      package.id
  AND package.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND package.package_key =
      'maternity_bronze'
  AND version.version_number = 1;

ALTER TABLE public.commercial_package_additional_image_terms
ENABLE TRIGGER USER;

-- 100
SELECT throws_ok(
  $$
  SELECT public.record_booking_additional_image_pricing_basis(
    (SELECT missing_a_booking_id FROM s11s8_ids),
    NULL
  )
  $$,
  'P0001',
  'record_booking_additional_image_pricing_basis: exact package additional-image term authority required',
  'missing exact A-side package commercial authority fails closed'
);

-- 101
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_additional_image_pricing_bases
    WHERE booking_id =
      (SELECT zero_booking_id FROM s11s8_ids)
  ),
  0::bigint,
  'zero-excess rejection leaves no pricing-basis evidence'
);

-- 102
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  69::bigint,
  'Slice 8 behavior leaves canonical permission count unchanged'
);

-- 103
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  243::bigint,
  'Slice 8 behavior leaves role-permission mapping count unchanged'
);

SELECT * FROM finish();

ROLLBACK;
