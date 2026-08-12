BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(46);

-- ---------------------------------------------------------------------
-- Test identities
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES
  ('81000000-0000-0000-0000-000000000001'::uuid),
  ('81000000-0000-0000-0000-000000000002'::uuid),
  ('81000000-0000-0000-0000-000000000003'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '81000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '81000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 8 Founder'
),
(
  '81000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '81000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 8 Sales'
),
(
  '81000000-0000-0000-0000-000000000013',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '81000000-0000-0000-0000-000000000003',
  'active',
  'Sprint 8 Photographer'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  fixture.member_id,
  r.id
FROM (
  VALUES
    ('81000000-0000-0000-0000-000000000011'::uuid,'founder'),
    ('81000000-0000-0000-0000-000000000012'::uuid,'sales'),
    ('81000000-0000-0000-0000-000000000013'::uuid,'photographer')
) fixture(member_id, role_key)
JOIN public.roles r
  ON r.key = fixture.role_key;

-- Clean local migration replay intentionally leaves the canonical
-- organization suspended until Founder coverage exists.
UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

-- Family fixtures must be created through the same actor invariant as
-- production records. Establish the test Founder as the current user.
SELECT set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
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
  '81000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'QT-234567',
  'Sprint 8 Quotation Family',
  'Quotation Family',
  'active',
  '81000000-0000-0000-0000-000000000011',
  '81000000-0000-0000-0000-000000000011'
);

-- ---------------------------------------------------------------------
-- Structure / hardening
-- ---------------------------------------------------------------------

SELECT has_table(
  'public',
  'quotations',
  'quotations exists'
);

SELECT has_table(
  'public',
  'quotation_line_items',
  'quotation_line_items exists'
);

SELECT has_type(
  'public',
  'quotation_status',
  'quotation_status exists'
);

SELECT has_type(
  'public',
  'quotation_line_type',
  'quotation_line_type exists'
);

SELECT has_type(
  'public',
  'quotation_pricing_source',
  'quotation_pricing_source exists'
);

SELECT ok(
  to_regprocedure(
    'public.create_quotation(uuid,uuid,uuid,uuid,timestamptz,uuid)'
  ) IS NOT NULL,
  'create_quotation exists'
);

SELECT ok(
  to_regprocedure(
    'public.add_quotation_package_line(uuid,uuid,integer)'
  ) IS NOT NULL,
  'add_quotation_package_line exists'
);

SELECT ok(
  to_regprocedure(
    'public.add_quotation_addon_line(uuid,uuid,integer,integer)'
  ) IS NOT NULL,
  'add_quotation_addon_line exists'
);

SELECT ok(
  to_regprocedure(
    'public.add_quotation_custom_line(uuid,text,text,integer,integer)'
  ) IS NOT NULL,
  'add_quotation_custom_line exists'
);

SELECT ok(
  to_regprocedure(
    'public.set_quotation_discount(uuid,integer)'
  ) IS NOT NULL,
  'set_quotation_discount exists'
);

SELECT ok(
  to_regprocedure(
    'public.transition_quotation(uuid,public.quotation_status)'
  ) IS NOT NULL,
  'transition_quotation exists'
);

SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.quotations',
    'SELECT'
  ),
  'authenticated has quotation SELECT privilege subject to RLS'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.quotations',
    'INSERT'
  ),
  'authenticated cannot INSERT quotations directly'
);

SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.quotations',
    'UPDATE'
  ),
  'authenticated cannot UPDATE quotations directly'
);

SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.quotations',
    'SELECT'
  ),
  'anon cannot SELECT quotations'
);

SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.create_quotation(uuid,uuid,uuid,uuid,timestamptz,uuid)',
    'EXECUTE'
  ),
  'authenticated can execute controlled create_quotation RPC'
);

SELECT ok(
  (
    SELECT
      count(*) = 2
      AND bool_and(c.relrowsecurity)
      AND bool_and(c.relforcerowsecurity)
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'quotations',
        'quotation_line_items'
      )
  ),
  'quotation tables have RLS and FORCE RLS'
);

SELECT throws_ok(
  $$
  UPDATE public.commercial_package_versions
  SET list_price_inr = list_price_inr + 1
  WHERE organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
    AND version_number = 1
  $$,
  'P0001',
  'approved commercial package versions are immutable',
  'approved package version prices cannot be rewritten'
);

SELECT throws_ok(
  $$
  DELETE FROM public.commercial_package_inclusions
  WHERE id = (
    SELECT i.id
    FROM public.commercial_package_inclusions i
    LIMIT 1
  )
  $$,
  'P0001',
  'approved commercial package inclusions are immutable',
  'approved package inclusions cannot be rewritten'
);

-- ---------------------------------------------------------------------
-- Sales user
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"81000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
  CREATE TEMP TABLE s8_sales_quote AS
  SELECT *
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '81000000-0000-0000-0000-000000000020',
    NULL,
    NULL,
    NULL,
    NULL
  )
  $$,
  'Sales with quote.write can create a draft quotation'
);

SELECT matches(
  (
    SELECT quotation_reference
    FROM s8_sales_quote
  ),
  '^LSH-QT-[A-F0-9]{8}$',
  'quotation receives immutable randomized LSH-QT reference'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events a
    WHERE a.entity_id =
          (SELECT id FROM s8_sales_quote)
      AND a.action_key = 'quote.created'
      AND a.is_sensitive
  ),
  'quotation creation writes sensitive commercial audit event'
);

SELECT lives_ok(
  $$
  SELECT public.add_quotation_package_line(
    (SELECT id FROM s8_sales_quote),
    (
      SELECT v.id
      FROM public.commercial_package_versions v
      JOIN public.commercial_packages p
        ON p.organization_id = v.organization_id
       AND p.id = v.package_id
      WHERE p.package_key = 'maternity_gold'
        AND v.version_number = 1
    ),
    NULL
  )
  $$,
  'Sales can add catalogue package pricing'
);

SELECT ok(
  (
    SELECT
      subtotal_inr = 30000
      AND quoted_total_inr = 30000
      AND discount_inr = 0
    FROM public.quotations
    WHERE id = (SELECT id FROM s8_sales_quote)
  ),
  'catalogue package line recalculates quotation totals'
);

CREATE TEMP TABLE s8_sales_override_quote AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '81000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT throws_ok(
  $$
  SELECT public.add_quotation_package_line(
    (SELECT id FROM s8_sales_override_quote),
    (
      SELECT v.id
      FROM public.commercial_package_versions v
      JOIN public.commercial_packages p
        ON p.organization_id = v.organization_id
       AND p.id = v.package_id
      WHERE p.package_key = 'maternity_bronze'
        AND v.version_number = 1
    ),
    15000
  )
  $$,
  '42501',
  'add_quotation_package_line: commercial.price.override permission required',
  'Sales cannot override package pricing'
);

SELECT throws_ok(
  $$
  SELECT public.set_quotation_discount(
    (SELECT id FROM s8_sales_quote),
    1000
  )
  $$,
  '42501',
  'set_quotation_discount: commercial.price.override permission required',
  'Sales cannot apply an unauthorized quote-level discount'
);

SELECT throws_ok(
  $$
  SELECT public.add_quotation_custom_line(
    (SELECT id FROM s8_sales_quote),
    'Custom commercial item',
    NULL,
    1,
    1000
  )
  $$,
  '42501',
  'add_quotation_custom_line: commercial.price.override permission required',
  'Sales cannot create non-catalogue custom pricing'
);

SELECT lives_ok(
  $$
  SELECT public.add_quotation_addon_line(
    (SELECT id FROM s8_sales_quote),
    (
      SELECT av.id
      FROM public.commercial_addon_versions av
      JOIN public.commercial_addons a
        ON a.organization_id = av.organization_id
       AND a.id = av.addon_id
      WHERE a.addon_key = 'extra_frame_12x18'
        AND av.version_number = 1
    ),
    1,
    NULL
  )
  $$,
  'Sales can add an applicable fixed catalogue add-on'
);

SELECT is(
  (
    SELECT quoted_total_inr
    FROM public.quotations
    WHERE id = (SELECT id FROM s8_sales_quote)
  ),
  31500,
  'fixed catalogue add-on is included in quotation total'
);

SELECT throws_ok(
  $$
  SELECT public.add_quotation_addon_line(
    (SELECT id FROM s8_sales_quote),
    (
      SELECT av.id
      FROM public.commercial_addon_versions av
      JOIN public.commercial_addons a
        ON a.organization_id = av.organization_id
       AND a.id = av.addon_id
      WHERE a.addon_key = 'outdoor_session_upgrade'
        AND av.version_number = 1
    ),
    1,
    NULL
  )
  $$,
  '42501',
  'add_quotation_addon_line: variable add-on requires an authorized explicit price',
  'variable catalogue item cannot invent a price'
);

SELECT lives_ok(
  $$
  SELECT public.transition_quotation(
    (SELECT id FROM s8_sales_quote),
    'ready'
  )
  $$,
  'complete draft quotation can become ready'
);

SELECT throws_ok(
  $$
  SELECT public.remove_quotation_line(
    (
      SELECT id
      FROM public.quotation_line_items
      WHERE quotation_id =
            (SELECT id FROM s8_sales_quote)
      ORDER BY sort_order
      LIMIT 1
    )
  )
  $$,
  '22023',
  'remove_quotation_line: quotation must be draft',
  'ready quotation commercial lines are frozen'
);

SELECT lives_ok(
  $$
  SELECT public.transition_quotation(
    (SELECT id FROM s8_sales_quote),
    'sent'
  )
  $$,
  'ready quotation can become sent'
);

SELECT throws_ok(
  $$
  SELECT public.transition_quotation(
    (SELECT id FROM s8_sales_quote),
    'accepted'
  )
  $$,
  '22023',
  'transition_quotation: accepted status must use accept_quotation',
  'generic lifecycle RPC cannot bypass accepted-quote booking conversion'
);

SELECT lives_ok(
  $$
  SELECT public.transition_quotation(
    (SELECT id FROM s8_sales_quote),
    'declined'
  )
  $$,
  'sent quotation can become declined'
);

SELECT throws_ok(
  $$
  SELECT public.transition_quotation(
    (SELECT id FROM s8_sales_quote),
    'draft'
  )
  $$,
  '22023',
  'transition_quotation: invalid transition from declined to draft',
  'terminal declined quotation cannot return to draft'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.audit_events a
    WHERE a.entity_id =
          (SELECT id FROM s8_sales_quote)
      AND a.action_key = 'quote.status_changed'
      AND a.is_sensitive
  ),
  'quotation lifecycle changes are audited'
);

-- ---------------------------------------------------------------------
-- Photographer cannot author quotations
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"81000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

SELECT throws_ok(
  $$
  SELECT public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '81000000-0000-0000-0000-000000000020',
    NULL,
    NULL,
    NULL,
    NULL
  )
  $$,
  '42501',
  'create_quotation: quote.write permission required',
  'role without quote.write cannot create quotations'
);

-- ---------------------------------------------------------------------
-- Founder elevated pricing authority
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

SELECT lives_ok(
  $$
  CREATE TEMP TABLE s8_founder_quote AS
  SELECT *
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '81000000-0000-0000-0000-000000000020',
    NULL,
    NULL,
    NULL,
    NULL
  )
  $$,
  'Founder can create quotation'
);

SELECT lives_ok(
  $$
  SELECT public.add_quotation_package_line(
    (SELECT id FROM s8_founder_quote),
    (
      SELECT v.id
      FROM public.commercial_package_versions v
      JOIN public.commercial_packages p
        ON p.organization_id = v.organization_id
       AND p.id = v.package_id
      WHERE p.package_key = 'maternity_gold'
        AND v.version_number = 1
    ),
    28000
  )
  $$,
  'Founder can explicitly authorize package price override'
);

SELECT is(
  (
    SELECT pricing_source::text
    FROM public.quotation_line_items
    WHERE quotation_id =
          (SELECT id FROM s8_founder_quote)
      AND line_type = 'package'
  ),
  'authorized_override',
  'package override is visibly snapshotted as authorized_override'
);

SELECT lives_ok(
  $$
  SELECT public.set_quotation_discount(
    (SELECT id FROM s8_founder_quote),
    1000
  )
  $$,
  'Founder can authorize quote-level discount'
);

SELECT is(
  (
    SELECT quoted_total_inr
    FROM public.quotations
    WHERE id = (SELECT id FROM s8_founder_quote)
  ),
  27000,
  'authorized quote-level discount is snapshotted in total'
);

SELECT lives_ok(
  $$
  SELECT public.add_quotation_custom_line(
    (SELECT id FROM s8_founder_quote),
    'Approved custom keepsake',
    'Founder-authorized non-catalogue item',
    1,
    2000
  )
  $$,
  'Founder can add explicitly authorized custom commercial line'
);

SELECT lives_ok(
  $$
  SELECT public.add_quotation_addon_line(
    (SELECT id FROM s8_founder_quote),
    (
      SELECT av.id
      FROM public.commercial_addon_versions av
      JOIN public.commercial_addons a
        ON a.organization_id = av.organization_id
       AND a.id = av.addon_id
      WHERE a.addon_key = 'outdoor_session_upgrade'
        AND av.version_number = 1
    ),
    1,
    3000
  )
  $$,
  'Founder can explicitly price variable outdoor charge'
);

SELECT is(
  (
    SELECT pricing_source::text
    FROM public.quotation_line_items li
    JOIN public.commercial_addon_versions av
      ON av.id = li.source_addon_version_id
    JOIN public.commercial_addons a
      ON a.id = av.addon_id
    WHERE li.quotation_id =
          (SELECT id FROM s8_founder_quote)
      AND a.addon_key = 'outdoor_session_upgrade'
  ),
  'authorized_override',
  'variable add-on is snapshotted as authorized override'
);

SELECT * FROM finish();

ROLLBACK;
