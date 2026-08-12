BEGIN;

SELECT plan(28);

SELECT has_table(
  'public',
  'commercial_packages',
  'commercial_packages exists'
);

SELECT has_table(
  'public',
  'commercial_package_versions',
  'commercial_package_versions exists'
);

SELECT has_table(
  'public',
  'commercial_package_inclusions',
  'commercial_package_inclusions exists'
);

SELECT has_table(
  'public',
  'commercial_addons',
  'commercial_addons exists'
);

SELECT has_table(
  'public',
  'commercial_addon_versions',
  'commercial_addon_versions exists'
);

SELECT has_table(
  'public',
  'booking_journey_stages',
  'booking_journey_stages exists'
);

SELECT has_type(
  'public',
  'commercial_package_tier',
  'commercial_package_tier exists'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.permissions
    WHERE key IN (
      'package.catalogue.manage',
      'commercial.price.override'
    )
  ),
  2::bigint,
  'two Sprint 8 commercial permissions exist'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE r.key = 'founder'
      AND p.key IN (
        'package.catalogue.manage',
        'commercial.price.override'
      )
  ),
  2::bigint,
  'founder receives both Sprint 8 elevated permissions'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE r.key <> 'founder'
      AND p.key IN (
        'package.catalogue.manage',
        'commercial.price.override'
      )
  ),
  0::bigint,
  'no non-founder role receives Sprint 8 elevated permissions'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.commercial_packages
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  12::bigint,
  'exactly 12 commercial packages are seeded'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.commercial_packages
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND service_category NOT IN (
        'maternity',
        'newborn',
        'sitter'
      )
  ),
  0::bigint,
  'no unsupported commercial package category is seeded'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.commercial_packages p
    JOIN public.commercial_package_versions v
      ON v.organization_id = p.organization_id
     AND v.package_id = p.id
    JOIN (
      VALUES
        ('maternity_bronze',18000),
        ('maternity_gold',30000),
        ('maternity_diamond',42000),
        ('maternity_emerald',60000),
        ('newborn_bronze',15000),
        ('newborn_gold',25000),
        ('newborn_diamond',36000),
        ('newborn_emerald',55000),
        ('sitter_bronze',15000),
        ('sitter_gold',25000),
        ('sitter_diamond',36000),
        ('sitter_emerald',55000)
    ) expected(package_key, list_price_inr)
      ON expected.package_key = p.package_key
     AND expected.list_price_inr = v.list_price_inr
    WHERE p.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND v.version_number = 1
      AND v.approval_status = 'approved'
  ),
  12::bigint,
  'all 12 founder-approved standard package prices match'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.commercial_addons
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  16::bigint,
  '16 structured commercial add-ons are seeded'
);

SELECT is(
  (
    SELECT v.percentage_value
    FROM public.commercial_addons a
    JOIN public.commercial_addon_versions v
      ON v.organization_id = a.organization_id
     AND v.addon_id = a.id
    WHERE a.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND a.addon_key = 'twin_handling'
      AND v.version_number = 1
  ),
  20.0000::numeric,
  'twin handling is structured as a 20 percent charge'
);

SELECT is(
  (
    SELECT v.pricing_type::text
    FROM public.commercial_addons a
    JOIN public.commercial_addon_versions v
      ON v.organization_id = a.organization_id
     AND v.addon_id = a.id
    WHERE a.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND a.addon_key = 'outdoor_session_upgrade'
      AND v.version_number = 1
  ),
  'variable'::text,
  'outdoor maternity upgrade remains variable rather than invented pricing'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.booking_journey_stages
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  21::bigint,
  'exactly 21 canonical journey stages are seeded'
);

SELECT is(
  (
    SELECT label
    FROM public.booking_journey_stages
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND stage_order = 7
  ),
  'Advance Pending'::text,
  'Advance Pending is canonical stage 7'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.booking_journey_stages actual
    JOIN (
      VALUES
        (1,'New Inquiry'),
        (2,'Details Collected'),
        (3,'Memory Goal Captured'),
        (4,'Package Recommended'),
        (5,'Quote Sent'),
        (6,'Follow-Up Pending'),
        (7,'Advance Pending'),
        (8,'Booking Confirmed'),
        (9,'Pre-Shoot Preparation'),
        (10,'Shoot Scheduled'),
        (11,'Shoot Completed'),
        (12,'Selection Pending'),
        (13,'Editing Pending'),
        (14,'Editing in Progress'),
        (15,'QC Pending'),
        (16,'Pixieset Gallery Ready'),
        (17,'Delivered'),
        (18,'Album / Frame Production'),
        (19,'Review Requested'),
        (20,'Milestone Follow-Up'),
        (21,'Completed / Relationship Active')
    ) expected(stage_order, label)
      ON expected.stage_order = actual.stage_order
     AND expected.label = actual.label
    WHERE actual.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  21::bigint,
  'all 21 journey stages match the founder-approved order and wording'
);

SELECT ok(
  (
    SELECT
      count(*) = 6
      AND bool_and(c.relrowsecurity)
      AND bool_and(c.relforcerowsecurity)
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'commercial_packages',
        'commercial_package_versions',
        'commercial_package_inclusions',
        'commercial_addons',
        'commercial_addon_versions',
        'booking_journey_stages'
      )
  ),
  'all Sprint 8 slice-1 tables have RLS and FORCE RLS enabled'
);

SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.commercial_packages',
    'SELECT'
  ),
  'authenticated receives commercial package SELECT privilege'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.commercial_packages',
    'INSERT'
  ),
  'authenticated has no direct commercial package INSERT privilege'
);

SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.commercial_packages',
    'SELECT'
  ),
  'anon has no direct commercial package SELECT privilege'
);

SELECT ok(
  has_table_privilege(
    'service_role',
    'public.commercial_packages',
    'INSERT'
  ),
  'service_role retains trusted administrative table access'
);


SELECT is(
  (
    SELECT count(*)
    FROM public.commercial_package_inclusions
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  95::bigint,
  'exactly 95 structured package inclusion rows are seeded'
);

SELECT is(
  (
    SELECT count(*)
    FROM public.commercial_package_versions v
    WHERE v.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND v.version_number = 1
      AND NOT EXISTS (
        SELECT 1
        FROM public.commercial_package_inclusions i
        WHERE i.organization_id = v.organization_id
          AND i.package_version_id = v.id
      )
  ),
  0::bigint,
  'every seeded package version has structured inclusions'
);

SELECT is(
  (
    SELECT applicable_package_keys
    FROM public.commercial_addons
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND addon_key = 'maternity_wardrobe_gown_upgrade'
  ),
  ARRAY['maternity_bronze']::text[],
  'maternity wardrobe gown upgrade is restricted to Bronze'
);

SELECT is(
  (
    SELECT applicable_package_keys
    FROM public.commercial_addons
    WHERE organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND addon_key = 'maternity_extra_look_saree_draping'
  ),
  ARRAY['maternity_gold']::text[],
  'maternity saree-draping additional look is restricted to Gold'
);

SELECT * FROM finish();

ROLLBACK;
