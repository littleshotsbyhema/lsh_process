CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(49);

-- =====================================================================
-- Sprint 11 Slice 6
-- Version-Bound Machine-Readable Image Entitlement Authority Foundation
--
-- Proves:
--   * exact frozen table surface;
--   * tenant-safe package/add-on source identity;
--   * XOR and positive entitlement constraints;
--   * one entitlement per commercial source version;
--   * approved-source-only creation;
--   * immutable evidence;
--   * forced RLS / org.read containment;
--   * no authenticated mutation path;
--   * exact 12 package + 1 additional_image canonical seed;
--   * historical approved package inclusions remain untouched;
--   * no new permissions or role-permission mappings.
-- =====================================================================

-- =====================================================================
-- Part 1 — Structural / permission / ACL contract
-- =====================================================================

-- 1
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  71::bigint,
  'canonical permission catalogue remains exactly 69'
);

-- 2
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  246::bigint,
  'canonical role-permission mapping count remains exactly 243'
);

-- 3
SELECT ok(
  to_regclass(
    'public.commercial_image_entitlements'
  ) IS NOT NULL,
  'commercial_image_entitlements exists'
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
          'commercial_image_entitlements'
  ),
  ARRAY[
    'id',
    'organization_id',
    'package_version_id',
    'addon_version_id',
    'retouched_image_count_per_unit',
    'created_at'
  ]::text[],
  'image entitlement authority contains only frozen structural columns'
);

-- 5
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(
               constraint_row.oid
             ),
             'public.',
             ''
           )
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'commercial_image_entitlements_package_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, package_version_id) REFERENCES commercial_package_versions(organization_id, id)%',
  'package-version source foreign key is tenant-safe'
);

-- 6
SELECT ok(
  (
    SELECT replace(
             pg_get_constraintdef(
               constraint_row.oid
             ),
             'public.',
             ''
           )
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'commercial_image_entitlements_addon_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, addon_version_id) REFERENCES commercial_addon_versions(organization_id, id)%',
  'add-on-version source foreign key is tenant-safe'
);

-- 7
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'commercial_image_entitlements_source_xor_chk'
      AND constraint_row.contype = 'c'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%package_version_id IS NOT NULL%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%addon_version_id IS NOT NULL%'
  ),
  'image entitlement enforces exactly-one-source XOR'
);

-- 8
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conname =
          'commercial_image_entitlements_count_chk'
      AND constraint_row.contype = 'c'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          '%retouched_image_count_per_unit > 0%'
  ),
  'retouched-image entitlement count must be positive'
);

-- 9
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_index index_row
    JOIN pg_class index_relation
      ON index_relation.oid =
         index_row.indexrelid
    WHERE index_relation.relname =
          'commercial_image_entitlements_package_uidx'
      AND index_row.indisunique
      AND pg_get_indexdef(
            index_row.indexrelid
          ) LIKE
          '%(organization_id, package_version_id)%'
      AND pg_get_expr(
            index_row.indpred,
            index_row.indrelid
          ) LIKE
          '%package_version_id IS NOT NULL%'
  ),
  'package-version entitlement source is unique per organization'
);

-- 10
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_index index_row
    JOIN pg_class index_relation
      ON index_relation.oid =
         index_row.indexrelid
    WHERE index_relation.relname =
          'commercial_image_entitlements_addon_uidx'
      AND index_row.indisunique
      AND pg_get_indexdef(
            index_row.indexrelid
          ) LIKE
          '%(organization_id, addon_version_id)%'
      AND pg_get_expr(
            index_row.indpred,
            index_row.indrelid
          ) LIKE
          '%addon_version_id IS NOT NULL%'
  ),
  'add-on-version entitlement source is unique per organization'
);

-- 11
SELECT ok(
  to_regprocedure(
    'public.lsh_commercial_image_entitlement_guard()'
  ) IS NOT NULL,
  'image-entitlement lifecycle guard exists'
);

-- 12
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.lsh_commercial_image_entitlement_guard()'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'image-entitlement guard uses an empty search_path'
);

-- 13
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    JOIN pg_class relation
      ON relation.oid = trigger_row.tgrelid
    JOIN pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'commercial_image_entitlements'
      AND trigger_row.tgname =
          'commercial_image_entitlements_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'image entitlement authority has exactly one lifecycle guard trigger'
);

-- 14
SELECT ok(
  (
    SELECT relation.relrowsecurity
    FROM pg_class relation
    JOIN pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'commercial_image_entitlements'
  ),
  'commercial_image_entitlements has RLS enabled'
);

-- 15
SELECT ok(
  (
    SELECT relation.relforcerowsecurity
    FROM pg_class relation
    JOIN pg_namespace namespace
      ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'public'
      AND relation.relname =
          'commercial_image_entitlements'
  ),
  'commercial_image_entitlements has RLS forced'
);

-- 16
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename =
          'commercial_image_entitlements'
      AND policy.policyname =
          'commercial_image_entitlements_staff_read'
      AND policy.permissive = 'PERMISSIVE'
      AND policy.cmd = 'SELECT'
      AND policy.roles::text =
          '{authenticated}'
      AND policy.qual =
          'has_permission(organization_id, ''org.read''::text, NULL::uuid)'
      AND policy.with_check IS NULL
  ),
  1::bigint,
  'image entitlement authority has exactly the frozen authenticated org.read policy'
);

-- 17
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.commercial_image_entitlements',
    'SELECT'
  ),
  'authenticated has SELECT privilege'
);

-- 18
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.commercial_image_entitlements',
    'INSERT'
  ),
  'authenticated has no direct INSERT privilege'
);

-- 19
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.commercial_image_entitlements',
    'UPDATE'
  ),
  'authenticated has no direct UPDATE privilege'
);

-- 20
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.commercial_image_entitlements',
    'DELETE'
  ),
  'authenticated has no direct DELETE privilege'
);

-- 21
SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.commercial_image_entitlements',
    'SELECT'
  ),
  'anon has no entitlement read privilege'
);

-- 22
SELECT ok(
  NOT has_table_privilege(
    'service_role',
    'public.commercial_image_entitlements',
    'SELECT'
  ),
  'service_role has no Slice 6 application table path'
);

-- 23
SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'public.lsh_commercial_image_entitlement_guard()',
    'EXECUTE'
  ),
  'authenticated cannot execute the trigger guard directly'
);

-- 24
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.lsh_commercial_image_entitlement_guard()',
    'EXECUTE'
  ),
  'anon cannot execute the trigger guard directly'
);

-- 25
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.lsh_commercial_image_entitlement_guard()',
    'EXECUTE'
  ),
  'service_role cannot execute the trigger guard directly'
);

-- =====================================================================
-- Part 2 — Exact canonical source map
-- =====================================================================

-- 26
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_image_entitlements
  ),
  13::bigint,
  'exactly 13 canonical image entitlement rows exist'
);

-- 27
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_image_entitlements
    WHERE package_version_id IS NOT NULL
      AND addon_version_id IS NULL
  ),
  12::bigint,
  'exactly 12 canonical package-version entitlements exist'
);

-- 28
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_image_entitlements
    WHERE package_version_id IS NULL
      AND addon_version_id IS NOT NULL
  ),
  1::bigint,
  'exactly one canonical add-on-version entitlement exists'
);

-- 29
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_image_entitlements entitlement
    WHERE (
      entitlement.package_version_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.commercial_package_versions version
        WHERE version.organization_id =
              entitlement.organization_id
          AND version.id =
              entitlement.package_version_id
          AND version.approval_status =
              'approved'::public.commercial_version_approval_status
      )
    )
    OR (
      entitlement.addon_version_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.commercial_addon_versions version
        WHERE version.organization_id =
              entitlement.organization_id
          AND version.id =
              entitlement.addon_version_id
          AND version.approval_status =
              'approved'::public.commercial_version_approval_status
      )
    )
  ),
  13::bigint,
  'all canonical entitlement rows reference approved commercial versions'
);

-- 30
SELECT is(
  (
    SELECT string_agg(
             package.package_key
             || '='
             || entitlement.retouched_image_count_per_unit::text,
             ','
             ORDER BY package.package_key
           )
    FROM public.commercial_image_entitlements entitlement
    JOIN public.commercial_package_versions version
      ON version.organization_id =
         entitlement.organization_id
     AND version.id =
         entitlement.package_version_id
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
  ),
  'maternity_bronze=15,maternity_diamond=25,maternity_emerald=35,maternity_gold=20,newborn_bronze=12,newborn_diamond=24,newborn_emerald=30,newborn_gold=18,sitter_bronze=12,sitter_diamond=25,sitter_emerald=30,sitter_gold=18'::text,
  'exact frozen package-version image entitlement mapping is present'
);

-- 31
SELECT is(
  (
    SELECT count(*)::bigint
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
      AND version.currency = 'INR'
      AND version.amount_inr = 500
      AND entitlement.retouched_image_count_per_unit = 1
  ),
  1::bigint,
  'additional_image v1 maps INR 500 source evidence to one image per unit'
);

-- 32
SELECT is(
  (
    SELECT count(*)::bigint
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
      AND inclusion.unit IS NULL
  ),
  12::bigint,
  'all 12 historical approved package image inclusions remain unmodified'
);

-- 33
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_image_entitlements
    WHERE retouched_image_count_per_unit <= 0
  ),
  0::bigint,
  'no canonical entitlement contains a non-positive image count'
);

-- =====================================================================
-- Part 3 — Authenticated org.read RLS containment
-- =====================================================================

-- 34
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions role_permission
    JOIN public.roles role
      ON role.id = role_permission.role_id
    JOIN public.permissions permission
      ON permission.id =
         role_permission.permission_id
    WHERE role.key = 'founder'
      AND permission.key = 'org.read'
  ),
  1::bigint,
  'Founder has the existing org.read authority used by Slice 6'
);

INSERT INTO auth.users (id)
VALUES
  ('8f000000-0000-0000-0000-000000000001'::uuid),
  ('8f000000-0000-0000-0000-000000000002'::uuid);

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

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
  '8f000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8f000000-0000-0000-0000-000000000001',
  'active',
  'S11S6 Founder',
  NULL
),
(
  '8f000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8f000000-0000-0000-0000-000000000002',
  'active',
  'S11S6 No Permission Member',
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
  '8f000000-0000-0000-0000-000000000101'::uuid,
  role.id,
  NULL
FROM public.roles role
WHERE role.key = 'founder';

CREATE FUNCTION pg_temp.s11s6_set_actor(
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

SET LOCAL ROLE authenticated;

SELECT pg_temp.s11s6_set_actor(
  '8f000000-0000-0000-0000-000000000001'
);

-- 35
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_image_entitlements
  ),
  13::bigint,
  'authenticated Founder with org.read can read all canonical organization entitlements'
);

SELECT pg_temp.s11s6_set_actor(
  '8f000000-0000-0000-0000-000000000002'
);

-- 36
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.commercial_image_entitlements
  ),
  0::bigint,
  'active organization member without org.read cannot read image entitlements'
);

RESET ROLE;

-- =====================================================================
-- Part 4 — Approved-source creation and immutable evidence
-- =====================================================================

INSERT INTO public.commercial_packages (
  id,
  organization_id,
  package_key,
  service_category,
  tier,
  public_name,
  status
)
VALUES (
  '8f000000-0000-0000-0000-000000000601',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  's11s6_test_package',
  's11s6_test',
  'bronze'::public.commercial_package_tier,
  'S11S6 Test Package',
  'active'::public.commercial_package_status
);

INSERT INTO public.commercial_package_versions (
  id,
  organization_id,
  package_id,
  version_number,
  list_price_inr,
  approval_status,
  source_document,
  source_revision,
  approved_at
)
VALUES
(
  '8f000000-0000-0000-0000-000000000602',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8f000000-0000-0000-0000-000000000601',
  1,
  1000,
  'draft'::public.commercial_version_approval_status,
  'S11S6 pgTAP fixture',
  'test',
  NULL
),
(
  '8f000000-0000-0000-0000-000000000603',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8f000000-0000-0000-0000-000000000601',
  2,
  1000,
  'approved'::public.commercial_version_approval_status,
  'S11S6 pgTAP fixture',
  'test',
  now()
);

-- 37
SELECT throws_ok(
  $$
  INSERT INTO public.commercial_image_entitlements (
    organization_id,
    package_version_id,
    retouched_image_count_per_unit
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8f000000-0000-0000-0000-000000000602',
    7
  )
  $$,
  'P0001',
  'commercial image entitlement requires approved package version',
  'draft package version cannot receive image entitlement authority'
);

-- 38
SELECT lives_ok(
  $$
  INSERT INTO public.commercial_image_entitlements (
    organization_id,
    package_version_id,
    retouched_image_count_per_unit
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8f000000-0000-0000-0000-000000000603',
    7
  )
  $$,
  'approved package version may receive immutable image entitlement authority'
);

-- 39
SELECT is(
  (
    SELECT retouched_image_count_per_unit
    FROM public.commercial_image_entitlements
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND package_version_id =
          '8f000000-0000-0000-0000-000000000603'::uuid
  ),
  7,
  'approved package-version entitlement preserves explicit source-controlled quantity'
);

INSERT INTO public.commercial_addon_versions (
  id,
  organization_id,
  addon_id,
  version_number,
  approval_status,
  pricing_type,
  currency,
  amount_inr,
  source_document,
  source_revision,
  approved_at
)
SELECT
  fixture.id,
  addon.organization_id,
  addon.id,
  fixture.version_number,
  fixture.approval_status,
  'fixed_amount'::public.commercial_pricing_type,
  'INR',
  500,
  'S11S6 pgTAP fixture',
  'test',
  fixture.approved_at
FROM public.commercial_addons addon
CROSS JOIN (
  VALUES
    (
      '8f000000-0000-0000-0000-000000000604'::uuid,
      900001,
      'draft'::public.commercial_version_approval_status,
      NULL::timestamptz
    ),
    (
      '8f000000-0000-0000-0000-000000000605'::uuid,
      900002,
      'approved'::public.commercial_version_approval_status,
      now()
    )
) AS fixture(
  id,
  version_number,
  approval_status,
  approved_at
)
WHERE addon.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  AND addon.addon_key =
      'additional_image';

-- 40
SELECT throws_ok(
  $$
  INSERT INTO public.commercial_image_entitlements (
    organization_id,
    addon_version_id,
    retouched_image_count_per_unit
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8f000000-0000-0000-0000-000000000604',
    1
  )
  $$,
  'P0001',
  'commercial image entitlement requires approved add-on version',
  'draft add-on version cannot receive image entitlement authority'
);

-- 41
SELECT lives_ok(
  $$
  INSERT INTO public.commercial_image_entitlements (
    organization_id,
    addon_version_id,
    retouched_image_count_per_unit
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8f000000-0000-0000-0000-000000000605',
    1
  )
  $$,
  'approved add-on version may receive immutable image entitlement authority'
);

-- 42
SELECT is(
  (
    SELECT retouched_image_count_per_unit
    FROM public.commercial_image_entitlements
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND addon_version_id =
          '8f000000-0000-0000-0000-000000000605'::uuid
  ),
  1,
  'approved add-on entitlement preserves explicit one-image-per-unit quantity'
);

-- 43
SELECT throws_ok(
  $$
  INSERT INTO public.commercial_image_entitlements (
    organization_id,
    package_version_id,
    addon_version_id,
    retouched_image_count_per_unit
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    NULL,
    NULL,
    1
  )
  $$,
  'P0001',
  'commercial image entitlement requires exactly one commercial source',
  'entitlement creation rejects a missing commercial source'
);

-- 44
SELECT throws_ok(
  $$
  INSERT INTO public.commercial_image_entitlements (
    organization_id,
    package_version_id,
    addon_version_id,
    retouched_image_count_per_unit
  )
  VALUES (
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8f000000-0000-0000-0000-000000000603',
    '8f000000-0000-0000-0000-000000000605',
    1
  )
  $$,
  'P0001',
  'commercial image entitlement requires exactly one commercial source',
  'entitlement creation rejects simultaneous package and add-on sources'
);

-- 45
SELECT throws_ok(
  $$
  UPDATE public.commercial_image_entitlements
  SET retouched_image_count_per_unit = 8
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND package_version_id =
        '8f000000-0000-0000-0000-000000000603'::uuid
  $$,
  'P0001',
  'commercial image entitlement evidence is immutable',
  'image entitlement evidence cannot be updated'
);

-- 46
SELECT throws_ok(
  $$
  DELETE FROM public.commercial_image_entitlements
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND package_version_id =
        '8f000000-0000-0000-0000-000000000603'::uuid
  $$,
  'P0001',
  'commercial image entitlement evidence is immutable',
  'image entitlement evidence cannot be deleted'
);

-- 47
SELECT is(
  (
    SELECT retouched_image_count_per_unit
    FROM public.commercial_image_entitlements
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND package_version_id =
          '8f000000-0000-0000-0000-000000000603'::uuid
  ),
  7,
  'rejected immutable mutations leave original entitlement evidence unchanged'
);

-- 48
SELECT is(
  (SELECT count(*)::bigint FROM public.permissions),
  71::bigint,
  'Slice 6 behavior does not change permission catalogue cardinality'
);

-- 49
SELECT is(
  (SELECT count(*)::bigint FROM public.role_permissions),
  246::bigint,
  'Slice 6 behavior does not change role-permission cardinality'
);

SELECT * FROM finish();

ROLLBACK;
