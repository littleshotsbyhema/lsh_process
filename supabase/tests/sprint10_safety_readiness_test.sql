CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(149);

-- =====================================================================
-- Part 1 — Exact table surfaces
-- =====================================================================

-- 1
SELECT ok(
  to_regclass(
    'public.booking_safety_readiness'
  ) IS NOT NULL,
  'booking_safety_readiness exists'
);

-- 2
SELECT ok(
  to_regclass(
    'public.booking_safety_signoffs'
  ) IS NOT NULL,
  'booking_safety_signoffs exists'
);

-- 3
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.booking_safety_readiness'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  ),
  11::bigint,
  'booking_safety_readiness has exactly 11 columns'
);

-- 4
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.booking_safety_signoffs'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
  ),
  8::bigint,
  'booking_safety_signoffs has exactly 8 columns'
);

-- 5
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.booking_safety_readiness'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
      AND attribute.attname = ANY (
        ARRAY[
          'id',
          'organization_id',
          'booking_id',
          'service_category',
          'revision_number',
          'safety_state',
          'comfort_state',
          'recorded_at',
          'recorded_by',
          'superseded_at',
          'superseded_by'
        ]::name[]
      )
  ),
  11::bigint,
  'readiness exposes exactly the frozen column names'
);

-- 6
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_attribute attribute
    WHERE attribute.attrelid =
          'public.booking_safety_signoffs'::regclass
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
      AND attribute.attname = ANY (
        ARRAY[
          'id',
          'organization_id',
          'booking_id',
          'readiness_id',
          'signed_at',
          'signed_by',
          'signoff_authority',
          'lead_assignment_id'
        ]::name[]
      )
  ),
  8::bigint,
  'sign-offs expose exactly the frozen column names'
);

-- =====================================================================
-- Part 2 — RLS / ACL contract
-- =====================================================================

-- 7
SELECT ok(
  (
    SELECT table_row.relrowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          'public.booking_safety_readiness'::regclass
  ),
  'readiness has RLS enabled'
);

-- 8
SELECT ok(
  (
    SELECT table_row.relforcerowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          'public.booking_safety_readiness'::regclass
  ),
  'readiness has FORCE RLS enabled'
);

-- 9
SELECT ok(
  (
    SELECT table_row.relrowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          'public.booking_safety_signoffs'::regclass
  ),
  'sign-offs have RLS enabled'
);

-- 10
SELECT ok(
  (
    SELECT table_row.relforcerowsecurity
    FROM pg_class table_row
    WHERE table_row.oid =
          'public.booking_safety_signoffs'::regclass
  ),
  'sign-offs have FORCE RLS enabled'
);

-- 11
SELECT ok(
  (
    SELECT count(*) = 1
    FROM pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename =
          'booking_safety_readiness'
      AND policy.policyname =
          'booking_safety_readiness_authenticated_select'
      AND policy.cmd = 'SELECT'
      AND policy.roles =
          ARRAY['authenticated']::name[]
      AND policy.qual LIKE
          '%safety.read%'
  ),
  'readiness exposes exactly the restricted authenticated SELECT policy'
);

-- 12
SELECT ok(
  (
    SELECT count(*) = 1
    FROM pg_policies policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename =
          'booking_safety_signoffs'
      AND policy.policyname =
          'booking_safety_signoffs_authenticated_select'
      AND policy.cmd = 'SELECT'
      AND policy.roles =
          ARRAY['authenticated']::name[]
      AND policy.qual LIKE
          '%safety.read%'
  ),
  'sign-offs expose exactly the restricted authenticated SELECT policy'
);

-- 13
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_safety_readiness',
    'SELECT'
  ),
  'authenticated receives readiness SELECT'
);

-- 14
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_safety_readiness',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_safety_readiness',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_safety_readiness',
    'DELETE'
  ),
  'authenticated receives no direct readiness writes'
);

-- 15
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.booking_safety_signoffs',
    'SELECT'
  ),
  'authenticated receives sign-off SELECT'
);

-- 16
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_safety_signoffs',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_safety_signoffs',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_safety_signoffs',
    'DELETE'
  ),
  'authenticated receives no direct sign-off writes'
);

-- 17
SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.booking_safety_readiness',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_safety_readiness',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_safety_readiness',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_safety_readiness',
    'DELETE'
  ),
  'anon receives no readiness table access'
);

-- 18
SELECT ok(
  NOT has_table_privilege(
    'anon',
    'public.booking_safety_signoffs',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_safety_signoffs',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_safety_signoffs',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.booking_safety_signoffs',
    'DELETE'
  ),
  'anon receives no sign-off table access'
);

-- 19
SELECT ok(
  has_table_privilege(
    'service_role',
    'public.booking_safety_readiness',
    'SELECT'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_safety_readiness',
    'INSERT'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_safety_readiness',
    'UPDATE'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_safety_readiness',
    'DELETE'
  ),
  'service_role retains trusted readiness table privileges'
);

-- 20
SELECT ok(
  has_table_privilege(
    'service_role',
    'public.booking_safety_signoffs',
    'SELECT'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_safety_signoffs',
    'INSERT'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_safety_signoffs',
    'UPDATE'
  )
  AND has_table_privilege(
    'service_role',
    'public.booking_safety_signoffs',
    'DELETE'
  ),
  'service_role retains trusted sign-off table privileges'
);

-- =====================================================================
-- Part 3 — Guards / constraints / indexes
-- =====================================================================

-- 21
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.booking_safety_readiness'::regclass
      AND trigger_row.tgname =
          'booking_safety_readiness_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'readiness lifecycle guard trigger exists exactly once'
);

-- 22
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.booking_safety_signoffs'::regclass
      AND trigger_row.tgname =
          'booking_safety_signoffs_guard'
      AND NOT trigger_row.tgisinternal
  ),
  1::bigint,
  'sign-off lifecycle guard trigger exists exactly once'
);

-- 23
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_service_category_chk'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%newborn%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%maternity%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%sitter%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%baby%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%child%'
  ),
  'readiness category CHECK contains exactly the frozen supported taxonomy'
);

-- 24
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_safety_state_chk'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%pending%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%ready%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%not_ready%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%not_applicable%'
  ),
  'safety-state CHECK contains the frozen controlled states'
);

-- 25
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_comfort_state_chk'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%pending%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%ready%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%not_ready%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%not_applicable%'
  ),
  'comfort-state CHECK contains the frozen controlled states'
);

-- 26
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_category_applicability_chk'
  ),
  'category applicability CHECK exists'
);

-- 27
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_lifecycle_chk'
  ),
  'readiness lifecycle CHECK exists'
);

-- 28
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_revision_positive_chk'
  ),
  'readiness revision numbers must be positive'
);

-- 29
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_superseded_time_chk'
  ),
  'readiness supersession cannot predate recording'
);

-- 30
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_booking_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (organization_id, booking_id) REFERENCES bookings(organization_id, id)%'
  ),
  'readiness booking FK is tenant-safe'
);

-- 31
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_recorded_by_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (recorded_by, organization_id) REFERENCES organization_members(id, organization_id)%'
  ),
  'readiness recorder FK is tenant-safe'
);

-- 32
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_superseded_by_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (superseded_by, organization_id) REFERENCES organization_members(id, organization_id)%'
  ),
  'readiness superseding actor FK is tenant-safe'
);

-- 33
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_org_booking_revision_key'
      AND constraint_row.contype = 'u'
  ),
  'readiness revision identity is unique per booking'
);

-- 34
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_readiness'::regclass
      AND constraint_row.conname =
          'booking_safety_readiness_id_org_booking_key'
      AND constraint_row.contype = 'u'
  ),
  'readiness exposes tenant-safe composite identity'
);

-- 35
SELECT ok(
  to_regclass(
    'public.booking_safety_readiness_current_uidx'
  ) IS NOT NULL,
  'exactly-one-current-readiness partial index exists'
);

-- 36
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_signoffs'::regclass
      AND constraint_row.conname =
          'booking_safety_signoffs_authority_chk'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%founder%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%studio_manager%'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE '%lead_photographer%'
  ),
  'sign-off authority CHECK contains the frozen authority taxonomy'
);

-- 37
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_signoffs'::regclass
      AND constraint_row.conname =
          'booking_safety_signoffs_authority_shape_chk'
  ),
  'sign-off authority/Lead-assignment shape CHECK exists'
);

-- 38
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_signoffs'::regclass
      AND constraint_row.conname =
          'booking_safety_signoffs_booking_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (organization_id, booking_id) REFERENCES bookings(organization_id, id)%'
  ),
  'sign-off booking FK is tenant-safe'
);

-- 39
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_signoffs'::regclass
      AND constraint_row.conname =
          'booking_safety_signoffs_readiness_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (readiness_id, organization_id, booking_id) REFERENCES booking_safety_readiness(id, organization_id, booking_id)%'
  ),
  'sign-off binds to an exact tenant-safe readiness revision'
);

-- 40
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_signoffs'::regclass
      AND constraint_row.conname =
          'booking_safety_signoffs_signed_by_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (signed_by, organization_id) REFERENCES organization_members(id, organization_id)%'
  ),
  'sign-off signer FK is tenant-safe'
);

-- 41
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_signoffs'::regclass
      AND constraint_row.conname =
          'booking_safety_signoffs_lead_assignment_fkey'
      AND pg_get_constraintdef(
            constraint_row.oid
          ) LIKE
          'FOREIGN KEY (lead_assignment_id, organization_id, booking_id) REFERENCES booking_team_assignments(id, organization_id, booking_id)%'
  ),
  'Lead-based sign-off snapshots the tenant-safe assignment interval'
);

-- 42
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.booking_safety_signoffs'::regclass
      AND constraint_row.conname =
          'booking_safety_signoffs_signer_revision_key'
      AND constraint_row.contype = 'u'
  ),
  'one signer may sign a readiness revision at most once'
);

-- =====================================================================
-- Part 4 — Permission / function security contract
-- =====================================================================

-- 43
SELECT is(
  (
    SELECT array_agg(
             role.key
             ORDER BY role.key
           )
    FROM public.role_permissions mapping
    JOIN public.permissions permission
      ON permission.id =
         mapping.permission_id
    JOIN public.roles role
      ON role.id =
         mapping.role_id
    WHERE permission.key =
          'safety.signoff'
  ),
  ARRAY[
    'founder',
    'photographer',
    'studio_manager'
  ]::text[],
  'safety.signoff is granted exactly to Founder, Photographer and Studio Manager'
);

-- 44
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.permissions permission
    WHERE permission.key =
          'safety.signoff'
      AND permission.domain =
          'safety'
      AND permission.requires_server_enforcement
  ),
  'safety.signoff remains server-enforced'
);

-- 45
SELECT ok(
  to_regprocedure(
    'public.record_booking_safety_readiness(uuid,text,text)'
  ) IS NOT NULL,
  'record_booking_safety_readiness RPC exists'
);

-- 46
SELECT ok(
  to_regprocedure(
    'public.signoff_booking_safety_readiness(uuid)'
  ) IS NOT NULL,
  'signoff_booking_safety_readiness RPC exists'
);

-- 47
SELECT ok(
  (
    SELECT procedure.prosecdef
           AND 'search_path=""' =
               ANY(
                 COALESCE(
                   procedure.proconfig,
                   ARRAY[]::text[]
                 )
               )
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.record_booking_safety_readiness(uuid,text,text)'::regprocedure
  ),
  'readiness RPC is SECURITY DEFINER with empty search_path'
);

-- 48
SELECT ok(
  (
    SELECT procedure.prosecdef
           AND 'search_path=""' =
               ANY(
                 COALESCE(
                   procedure.proconfig,
                   ARRAY[]::text[]
                 )
               )
    FROM pg_proc procedure
    WHERE procedure.oid =
          'public.signoff_booking_safety_readiness(uuid)'::regprocedure
  ),
  'sign-off RPC is SECURITY DEFINER with empty search_path'
);

-- 49
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.record_booking_safety_readiness(uuid,text,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.record_booking_safety_readiness(uuid,text,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.record_booking_safety_readiness(uuid,text,text)',
    'EXECUTE'
  )
  AND has_function_privilege(
    'authenticated',
    'public.signoff_booking_safety_readiness(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.signoff_booking_safety_readiness(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.signoff_booking_safety_readiness(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'authenticated',
    'public.lsh_booking_safety_readiness_guard()',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.lsh_booking_safety_readiness_guard()',
    'EXECUTE'
  )
  AND has_function_privilege(
    'service_role',
    'public.lsh_booking_safety_readiness_guard()',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'authenticated',
    'public.lsh_booking_safety_signoff_guard()',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.lsh_booking_safety_signoff_guard()',
    'EXECUTE'
  )
  AND has_function_privilege(
    'service_role',
    'public.lsh_booking_safety_signoff_guard()',
    'EXECUTE'
  ),
  'RPC and lifecycle-guard EXECUTE ACLs match the frozen boundary'
);

-- 50
SELECT ok(
  pg_get_function_result(
    'public.record_booking_safety_readiness(uuid,text,text)'::regprocedure
  ) =
    'booking_safety_readiness'
  AND
  pg_get_function_result(
    'public.signoff_booking_safety_readiness(uuid)'::regprocedure
  ) =
    'booking_safety_signoffs',
  'public RPCs return canonical readiness and sign-off evidence'
);


-- =====================================================================
-- Part 5 — Runtime readiness revision semantics
-- =====================================================================
--
-- Test-only canonical Newborn booking fixture.
--
-- This fixture exercises the Slice 5 evidence boundary only. Journey
-- progression into Stage 9 follows the same controlled test-fixture
-- convention already used by prior Sprint 10 pgTAP suites.
-- =====================================================================

INSERT INTO auth.users (id)
VALUES (
  '90000000-0000-0000-0000-000000000001'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '90000000-0000-0000-0000-000000000011',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000001',
  'active',
  'Sprint 10 Safety Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000011'::uuid,
  role.id
FROM public.roles role
WHERE role.key = 'founder';

-- Migration A reconciliation:
-- active organization requires exactly one canonical Brand Owner
-- backed by the organization-wide Founder grant.
INSERT INTO public.organization_brand_owners (
  organization_id,
  organization_member_id,
  established_by
)
VALUES (
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc';

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '90000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-Z9X8W7',
  'Sprint 10 Safety Newborn Family',
  'Safety Newborn Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10s_quote_newborn AS
SELECT *
FROM public.create_quotation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000020',
  NULL,
  NULL,
  NULL,
  NULL
);

SELECT public.add_quotation_package_line(
  (SELECT id FROM s10s_quote_newborn),
  (
    SELECT version.id
    FROM public.commercial_package_versions version
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE package.package_key =
          'newborn_gold'
      AND version.version_number = 1
  ),
  NULL
);

SELECT public.transition_quotation(
  (SELECT id FROM s10s_quote_newborn),
  'ready'::public.quotation_status
);

SELECT public.transition_quotation(
  (SELECT id FROM s10s_quote_newborn),
  'sent'::public.quotation_status
);

CREATE TEMP TABLE s10s_booking_newborn AS
SELECT *
FROM public.accept_quotation(
  (SELECT id FROM s10s_quote_newborn)
);

-- ---------------------------------------------------------------------
-- Wrong-stage boundary: accepted booking begins before Stage 9.
-- ---------------------------------------------------------------------

-- 51
SELECT throws_ok(
  $$
  SELECT public.record_booking_safety_readiness(
    (SELECT id FROM s10s_booking_newborn),
    'pending',
    'pending'
  )
  $$,
  '22023',
  'record_booking_safety_readiness: booking must be exactly Pre-Shoot Preparation',
  'readiness mutation is denied outside exact Stage 9'
);

-- 52
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ),
  0::bigint,
  'wrong-stage denial creates no readiness evidence'
);

-- ---------------------------------------------------------------------
-- Test-only legitimate sequential progression: Stage 7 -> 8 -> 9.
-- ---------------------------------------------------------------------

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_safety_test_booking_confirmed',
  now(),
  '90000000-0000-0000-0000-000000000011'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_newborn);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '90000000-0000-0000-0000-000000000011'
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_newborn)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10_safety_test_preparation',
  now(),
  '90000000-0000-0000-0000-000000000011'
FROM public.booking_journey_states state
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key =
     'pre_shoot_preparation'
 AND target.stage_order = 9
 AND target.is_active
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_newborn);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '90000000-0000-0000-0000-000000000011'
FROM public.booking_journey_stages target
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_newborn)
  AND target.organization_id =
      state.organization_id
  AND target.stage_key =
      'pre_shoot_preparation'
  AND target.stage_order = 9
  AND target.is_active;

-- 53
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ),
  'pre_shoot_preparation',
  'runtime fixture reaches exact canonical Stage 9'
);

-- Slice 5 explicitly does not require any team assignment merely to record
-- safety/comfort readiness.

-- 54
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment
    WHERE assignment.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ),
  0::bigint,
  'readiness fixture has no booking-team assignment'
);

CREATE TEMP TABLE s10s_journey_before_readiness AS
SELECT
  state.current_stage_id,
  state.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
  ) AS transition_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_newborn);

-- ---------------------------------------------------------------------
-- First explicit readiness record -> revision 1.
-- ---------------------------------------------------------------------

-- 55
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_readiness_v1 AS
  SELECT *
  FROM public.record_booking_safety_readiness(
    (SELECT id FROM s10s_booking_newborn),
    'pending',
    'pending'
  )
  $$,
  'Founder records first explicit Newborn readiness at Stage 9'
);

-- 56
SELECT ok(
  (
    SELECT
      readiness.service_category =
        'newborn'
      AND readiness.revision_number = 1
      AND readiness.safety_state =
          'pending'
      AND readiness.comfort_state =
          'pending'
      AND readiness.recorded_by =
          '90000000-0000-0000-0000-000000000011'
      AND readiness.superseded_at IS NULL
      AND readiness.superseded_by IS NULL
    FROM public.booking_safety_readiness readiness
    WHERE readiness.id =
          (SELECT id FROM s10s_readiness_v1)
  ),
  'first readiness row records canonical Newborn revision 1 evidence'
);

-- 57
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_recorded'
      AND audit.entity_type =
          'booking_safety_readiness'
      AND audit.metadata ->> 'booking_id' =
          (SELECT id::text FROM s10s_booking_newborn)
  ),
  1::bigint,
  'first readiness record appends exactly one recorded audit event'
);

-- 58
SELECT ok(
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
          before.version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
              state.booking_id
      ) =
      before.transition_count
    FROM public.booking_journey_states state
    CROSS JOIN s10s_journey_before_readiness before
    WHERE state.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ),
  'first readiness record does not move the booking journey'
);

-- ---------------------------------------------------------------------
-- Exact replay -> same current row, no revision and no audit.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10s_readiness_replay AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_newborn),
  'pending',
  'pending'
);

-- 59
SELECT is(
  (SELECT id FROM s10s_readiness_replay),
  (SELECT id FROM s10s_readiness_v1),
  'exact readiness replay returns the same current evidence'
);

-- 60
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_recorded'
      AND audit.metadata ->> 'booking_id' =
          (SELECT id::text FROM s10s_booking_newborn)
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_revised'
      AND audit.metadata ->> 'booking_id' =
          (SELECT id::text FROM s10s_booking_newborn)
  ) = 0,
  'exact readiness replay creates no revision and no audit event'
);

-- ---------------------------------------------------------------------
-- Real change -> close revision 1 and create revision 2 atomically.
-- ---------------------------------------------------------------------

-- 61
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_readiness_v2 AS
  SELECT *
  FROM public.record_booking_safety_readiness(
    (SELECT id FROM s10s_booking_newborn),
    'ready',
    'ready'
  )
  $$,
  'real readiness state change creates a new revision'
);

-- 62
SELECT ok(
  (
    SELECT
      readiness.revision_number = 2
      AND readiness.service_category =
          'newborn'
      AND readiness.safety_state =
          'ready'
      AND readiness.comfort_state =
          'ready'
      AND readiness.superseded_at IS NULL
      AND readiness.superseded_by IS NULL
    FROM public.booking_safety_readiness readiness
    WHERE readiness.id =
          (SELECT id FROM s10s_readiness_v2)
  ),
  'new current readiness is canonical ready revision 2'
);

-- 63
SELECT ok(
  (
    SELECT
      readiness.revision_number = 1
      AND readiness.superseded_at IS NOT NULL
      AND readiness.superseded_by =
          '90000000-0000-0000-0000-000000000011'
    FROM public.booking_safety_readiness readiness
    WHERE readiness.id =
          (SELECT id FROM s10s_readiness_v1)
  )
  AND
  (
    SELECT
      readiness.superseded_at IS NULL
      AND readiness.superseded_by IS NULL
    FROM public.booking_safety_readiness readiness
    WHERE readiness.id =
          (SELECT id FROM s10s_readiness_v2)
  ),
  'revision 1 becomes immutable history while revision 2 is current'
);

-- 64
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ) = 2
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
      AND readiness.superseded_at IS NULL
  ) = 1,
  'real change leaves exactly two revisions and one current readiness'
);

-- 65
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_recorded'
      AND audit.metadata ->> 'booking_id' =
          (SELECT id::text FROM s10s_booking_newborn)
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_revised'
      AND audit.entity_type =
          'booking_safety_readiness'
      AND audit.metadata ->> 'booking_id' =
          (SELECT id::text FROM s10s_booking_newborn)
  ) = 1,
  'real revision creates exactly one revised audit without duplicating recorded audit'
);

-- 66
SELECT ok(
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
          before.version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
              state.booking_id
      ) =
      before.transition_count
    FROM public.booking_journey_states state
    CROSS JOIN s10s_journey_before_readiness before
    WHERE state.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ),
  'readiness revisioning never moves the booking journey'
);


-- =====================================================================
-- Part 6 — Runtime category, authorization and rollback semantics
-- =====================================================================

-- Restore the canonical Founder test identity before creating fixtures.

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Additional authenticated identities.
--
-- ...002 is deliberately an active member with no role grant.
-- ...003 receives Assistant only in Branch B.
-- ...004 becomes Founder of a separate organization below.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES
  ('90000000-0000-0000-0000-000000000002'::uuid),
  ('90000000-0000-0000-0000-000000000003'::uuid),
  ('90000000-0000-0000-0000-000000000004'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '90000000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000002',
  'active',
  'Sprint 10 Safety No Permission Member'
),
(
  '90000000-0000-0000-0000-000000000013',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000003',
  'active',
  'Sprint 10 Safety Branch B Assistant'
);

-- ---------------------------------------------------------------------
-- Branch-scope fixtures.
-- ---------------------------------------------------------------------

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  country_code,
  created_by,
  updated_by
)
VALUES
(
  '90000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'Sprint 10 Safety Branch A',
  's10sa',
  'active',
  'IN',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000202',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'Sprint 10 Safety Branch B',
  's10sb',
  'active',
  'IN',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000013'::uuid,
  role.id,
  '90000000-0000-0000-0000-000000000202'::uuid
FROM public.roles role
WHERE role.key = 'assistant';

-- ---------------------------------------------------------------------
-- Families for the category matrix.
-- ---------------------------------------------------------------------

INSERT INTO public.families (
  id,
  organization_id,
  branch_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES
(
  '90000000-0000-0000-0000-000000000021',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-M2N3P4',
  'Sprint 10 Safety Maternity Family',
  'Safety Maternity Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000022',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-S2T3V4',
  'Sprint 10 Safety Sitter Family',
  'Safety Sitter Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000023',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-B2C3D4',
  'Sprint 10 Safety Baby Family',
  'Safety Baby Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000024',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-C2D3E4',
  'Sprint 10 Safety Child Family',
  'Safety Child Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000025',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-X2Y3Z4',
  'Sprint 10 Safety Unsupported Family',
  'Safety Unsupported Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000026',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000201',
  'LSH-R2S3T4',
  'Sprint 10 Safety Branch Family',
  'Safety Branch Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

-- ---------------------------------------------------------------------
-- Baby / Child do not currently have production catalogue packages.
-- Add transaction-local approved catalogue fixtures so the frozen
-- readiness category matrix itself can be exercised.
--
-- "family" is deliberately unsupported by Slice 5 and exists only to
-- prove fail-closed behavior.
-- ---------------------------------------------------------------------

INSERT INTO public.commercial_packages (
  id,
  organization_id,
  package_key,
  service_category,
  tier,
  public_name,
  status,
  created_by,
  updated_by
)
VALUES
(
  '90000000-0000-0000-0000-000000000401',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  's10_test_baby_bronze',
  'baby',
  'bronze',
  'Sprint 10 Test Baby',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000402',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  's10_test_child_bronze',
  'child',
  'bronze',
  'Sprint 10 Test Child',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000403',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  's10_test_family_bronze',
  'family',
  'bronze',
  'Sprint 10 Test Unsupported Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

INSERT INTO public.commercial_package_versions (
  id,
  organization_id,
  package_id,
  version_number,
  currency,
  list_price_inr,
  effective_from,
  approval_status,
  source_document,
  source_revision,
  approved_at,
  approved_by,
  created_by,
  updated_by
)
VALUES
(
  '90000000-0000-0000-0000-000000000411',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000401',
  1,
  'INR',
  10000,
  current_date - 1,
  'approved',
  'Sprint 10 Slice 5 pgTAP fixture',
  'runtime-tranche-2',
  now(),
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000412',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000402',
  1,
  'INR',
  10000,
  current_date - 1,
  'approved',
  'Sprint 10 Slice 5 pgTAP fixture',
  'runtime-tranche-2',
  now(),
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000413',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000403',
  1,
  'INR',
  10000,
  current_date - 1,
  'approved',
  'Sprint 10 Slice 5 pgTAP fixture',
  'runtime-tranche-2',
  now(),
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

-- ---------------------------------------------------------------------
-- Test-only helpers for quote -> booking creation and deterministic
-- progression to exact Stage 9.
-- ---------------------------------------------------------------------

CREATE FUNCTION pg_temp.s10s_make_booking(
  p_family_id uuid,
  p_branch_id uuid,
  p_package_key text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_quote_id uuid;
  v_package_version_id uuid;
  v_booking_id uuid;
BEGIN
  SELECT quotation.id
  INTO v_quote_id
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    p_family_id,
    NULL,
    p_branch_id,
    NULL,
    NULL
  ) quotation;

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
    AND version.version_number = 1;

  PERFORM public.add_quotation_package_line(
    v_quote_id,
    v_package_version_id,
    NULL
  );

  PERFORM public.transition_quotation(
    v_quote_id,
    'ready'::public.quotation_status
  );

  PERFORM public.transition_quotation(
    v_quote_id,
    'sent'::public.quotation_status
  );

  SELECT booking.id
  INTO v_booking_id
  FROM public.accept_quotation(
    v_quote_id
  ) booking;

  RETURN v_booking_id;
END
$$;

CREATE FUNCTION pg_temp.s10s_enter_stage9(
  p_booking_id uuid,
  p_actor uuid
)
RETURNS void
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_organization_id uuid;
  v_current_stage_id uuid;
  v_stage8_id uuid;
  v_stage9_id uuid;
BEGIN
  SELECT
    state.organization_id,
    state.current_stage_id
  INTO
    v_organization_id,
    v_current_stage_id
  FROM public.booking_journey_states state
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.id
  INTO v_stage8_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_organization_id
    AND stage.stage_key =
        'booking_confirmed'
    AND stage.stage_order = 8
    AND stage.is_active;

  SELECT stage.id
  INTO v_stage9_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_organization_id
    AND stage.stage_key =
        'pre_shoot_preparation'
    AND stage.stage_order = 9
    AND stage.is_active;

  IF v_current_stage_id IS DISTINCT FROM v_stage8_id
     AND
     v_current_stage_id IS DISTINCT FROM v_stage9_id THEN

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
      v_organization_id,
      p_booking_id,
      v_current_stage_id,
      v_stage8_id,
      's10_safety_test_booking_confirmed',
      now(),
      p_actor
    );

    UPDATE public.booking_journey_states
    SET
      current_stage_id =
        v_stage8_id,
      stage_entered_at =
        now(),
      version =
        version + 1,
      updated_by =
        p_actor
    WHERE organization_id =
          v_organization_id
      AND booking_id =
          p_booking_id
      AND current_stage_id =
          v_current_stage_id;

    v_current_stage_id :=
      v_stage8_id;
  END IF;

  IF v_current_stage_id = v_stage8_id THEN

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
      v_organization_id,
      p_booking_id,
      v_stage8_id,
      v_stage9_id,
      's10_safety_test_preparation',
      now(),
      p_actor
    );

    UPDATE public.booking_journey_states
    SET
      current_stage_id =
        v_stage9_id,
      stage_entered_at =
        now(),
      version =
        version + 1,
      updated_by =
        p_actor
    WHERE organization_id =
          v_organization_id
      AND booking_id =
          p_booking_id
      AND current_stage_id =
          v_stage8_id;
  END IF;
END
$$;

CREATE TEMP TABLE s10s_booking_maternity AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000021',
  NULL,
  'maternity_gold'
) AS id;

CREATE TEMP TABLE s10s_booking_sitter AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000022',
  NULL,
  'sitter_bronze'
) AS id;

CREATE TEMP TABLE s10s_booking_baby AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000023',
  NULL,
  's10_test_baby_bronze'
) AS id;

CREATE TEMP TABLE s10s_booking_child AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000024',
  NULL,
  's10_test_child_bronze'
) AS id;

CREATE TEMP TABLE s10s_booking_unsupported AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000025',
  NULL,
  's10_test_family_bronze'
) AS id;

CREATE TEMP TABLE s10s_booking_branch AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000026',
  '90000000-0000-0000-0000-000000000201',
  'newborn_gold'
) AS id;

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_maternity),
  '90000000-0000-0000-0000-000000000011'
);

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_sitter),
  '90000000-0000-0000-0000-000000000011'
);

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_baby),
  '90000000-0000-0000-0000-000000000011'
);

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_child),
  '90000000-0000-0000-0000-000000000011'
);

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_unsupported),
  '90000000-0000-0000-0000-000000000011'
);

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_branch),
  '90000000-0000-0000-0000-000000000011'
);

-- ---------------------------------------------------------------------
-- Corrective Safety read-model regressions.
-- ---------------------------------------------------------------------

-- 143
SELECT ok(
  public.get_booking_safety_service_category(
    (SELECT id FROM s10s_booking_unsupported)
  ) IS NULL,
  'unsupported valid booking category returns NULL instead of failing the workspace'
);

-- 144
SELECT ok(
  (
    SELECT
      procedure.prosecdef
      AND
      COALESCE(
        procedure.proconfig,
        ARRAY[]::text[]
      ) @> ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
          'public.get_booking_safety_signoff_authority(uuid)'::regprocedure
  ),
  'sign-off authority read model is SECURITY DEFINER with empty search_path'
);

-- 145
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.get_booking_safety_signoff_authority(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.get_booking_safety_signoff_authority(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.get_booking_safety_signoff_authority(uuid)',
    'EXECUTE'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    CROSS JOIN LATERAL
      pg_catalog.aclexplode(
        COALESCE(
          procedure.proacl,
          pg_catalog.acldefault(
            'f',
            procedure.proowner
          )
        )
      ) acl
    WHERE procedure.oid =
          'public.get_booking_safety_signoff_authority(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'sign-off authority read model is executable only by authenticated'
);

CREATE TEMP TABLE s10s_error_capture (
  test_key text PRIMARY KEY,
  sqlstate text,
  message_text text
);

-- ---------------------------------------------------------------------
-- Maternity applicability.
-- ---------------------------------------------------------------------

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.record_booking_safety_readiness(
      (SELECT id FROM s10s_booking_maternity),
      'ready',
      'ready'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'maternity_invalid',
    v_state,
    v_message
  );
END
$$;

-- 67
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'maternity_invalid'
  ),
  'record_booking_safety_readiness: invalid Maternity readiness applicability',
  'Maternity rejects applicable safety state'
);

-- 68
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_readiness_maternity AS
  SELECT *
  FROM public.record_booking_safety_readiness(
    (SELECT id FROM s10s_booking_maternity),
    'not_applicable',
    'ready'
  )
  $$,
  'Maternity accepts safety not_applicable with ready comfort'
);

-- 69
SELECT ok(
  (
    SELECT
      readiness.service_category = 'maternity'
      AND
      readiness.revision_number = 1
      AND
      readiness.safety_state = 'not_applicable'
      AND
      readiness.comfort_state = 'ready'
      AND
      readiness.superseded_at IS NULL
      AND
      readiness.superseded_by IS NULL
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_maternity)
  ),
  'Maternity readiness persists exact frozen applicability'
);

-- ---------------------------------------------------------------------
-- Sitter applicability.
-- ---------------------------------------------------------------------

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.record_booking_safety_readiness(
      (SELECT id FROM s10s_booking_sitter),
      'not_applicable',
      'ready'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'sitter_invalid',
    v_state,
    v_message
  );
END
$$;

-- 70
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'sitter_invalid'
  ),
  'record_booking_safety_readiness: safety and comfort are applicable for this service category',
  'Sitter rejects not_applicable readiness state'
);

-- 71
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_readiness_sitter AS
  SELECT *
  FROM public.record_booking_safety_readiness(
    (SELECT id FROM s10s_booking_sitter),
    'ready',
    'ready'
  )
  $$,
  'Sitter accepts complete safety and comfort readiness'
);

-- 72
SELECT ok(
  (
    SELECT
      readiness.service_category = 'sitter'
      AND
      readiness.revision_number = 1
      AND
      readiness.safety_state = 'ready'
      AND
      readiness.comfort_state = 'ready'
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_sitter)
      AND readiness.superseded_at IS NULL
  ),
  'Sitter readiness persists exact applicable states'
);

-- ---------------------------------------------------------------------
-- Baby and Child applicability using transaction-local catalogue rows.
-- ---------------------------------------------------------------------

-- 73
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_readiness_baby AS
  SELECT *
  FROM public.record_booking_safety_readiness(
    (SELECT id FROM s10s_booking_baby),
    'ready',
    'ready'
  )
  $$,
  'Baby accepts complete safety and comfort readiness'
);

-- 74
SELECT ok(
  (
    SELECT
      readiness.service_category = 'baby'
      AND
      readiness.revision_number = 1
      AND
      readiness.safety_state = 'ready'
      AND
      readiness.comfort_state = 'ready'
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_baby)
      AND readiness.superseded_at IS NULL
  ),
  'Baby readiness is server-derived from authoritative package category'
);

-- 75
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_readiness_child AS
  SELECT *
  FROM public.record_booking_safety_readiness(
    (SELECT id FROM s10s_booking_child),
    'ready',
    'ready'
  )
  $$,
  'Child accepts complete safety and comfort readiness'
);

-- 76
SELECT ok(
  (
    SELECT
      readiness.service_category = 'child'
      AND
      readiness.revision_number = 1
      AND
      readiness.safety_state = 'ready'
      AND
      readiness.comfort_state = 'ready'
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_child)
      AND readiness.superseded_at IS NULL
  ),
  'Child readiness is server-derived from authoritative package category'
);

-- ---------------------------------------------------------------------
-- Unsupported category fails closed.
-- ---------------------------------------------------------------------

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.record_booking_safety_readiness(
      (SELECT id FROM s10s_booking_unsupported),
      'ready',
      'ready'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'unsupported_category',
    v_state,
    v_message
  );
END
$$;

-- 77
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'unsupported_category'
  ),
  'record_booking_safety_readiness: unsupported safety-readiness service category',
  'unsupported authoritative service category fails closed'
);

-- 78
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_unsupported)
  ),
  0::bigint,
  'unsupported category creates no readiness evidence'
);

-- ---------------------------------------------------------------------
-- safety.write is independently required, including on replay.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.record_booking_safety_readiness(
      (SELECT id FROM s10s_booking_newborn),
      'ready',
      'ready'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'safety_write_missing',
    v_state,
    v_message
  );
END
$$;

-- 79
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'safety_write_missing'
  ),
  'record_booking_safety_readiness: safety.write permission required',
  'active member without safety.write cannot record or replay readiness'
);

-- 80
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ) = 2
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
      AND readiness.superseded_at IS NULL
      AND readiness.revision_number = 2
  ) = 1,
  'failed safety.write authorization creates no readiness mutation'
);

-- ---------------------------------------------------------------------
-- Booking-derived branch scope.
--
-- Assistant has safety.write only in Branch B. The booking belongs to A.
-- Because permission resolution itself is booking-branch scoped, failure
-- is expected at the safety.write gate before the redundant scope guard.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.record_booking_safety_readiness(
      (SELECT id FROM s10s_booking_branch),
      'ready',
      'ready'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'wrong_branch',
    v_state,
    v_message
  );
END
$$;

-- 81
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'wrong_branch'
  ),
  'record_booking_safety_readiness: safety.write permission required',
  'different-branch safety.write grant cannot authorize this booking'
);

-- 82
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_branch)
  ),
  0::bigint,
  'wrong-branch authorization creates no readiness evidence'
);

-- ---------------------------------------------------------------------
-- Cross-organization isolation.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.organizations (
  id,
  display_name,
  slug,
  status,
  currency_code,
  timezone,
  brand_prefix
)
VALUES (
  '90000000-0000-0000-0000-000000000301',
  'Sprint 10 Safety Foreign Studio',
  'sprint-10-safety-foreign-studio',
  'suspended',
  'INR',
  'Asia/Kolkata',
  'S10Y'
);

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '90000000-0000-0000-0000-000000000301'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '90000000-0000-0000-0000-000000000014',
  '90000000-0000-0000-0000-000000000301',
  '90000000-0000-0000-0000-000000000004',
  'active',
  'Sprint 10 Safety Foreign Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '90000000-0000-0000-0000-000000000301'::uuid,
  '90000000-0000-0000-0000-000000000014'::uuid,
  role.id,
  NULL
FROM public.roles role
WHERE role.key = 'founder';

-- Migration A reconciliation:
-- foreign fixture organization is independently constitutional.
INSERT INTO public.organization_brand_owners (
  organization_id,
  organization_member_id,
  established_by
)
VALUES (
  '90000000-0000-0000-0000-000000000301',
  '90000000-0000-0000-0000-000000000014',
  '90000000-0000-0000-0000-000000000014'
);

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '90000000-0000-0000-0000-000000000301'::uuid;

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000004',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.record_booking_safety_readiness(
      (SELECT id FROM s10s_booking_newborn),
      'ready',
      'ready'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'foreign_organization',
    v_state,
    v_message
  );
END
$$;

-- 83
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'foreign_organization'
  ),
  'record_booking_safety_readiness: active organization membership required',
  'foreign-organization Founder cannot mutate canonical organization readiness'
);

SET LOCAL ROLE authenticated;

-- 84
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  0::bigint,
  'foreign-organization Founder cannot read canonical organization safety evidence'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Failed revision replacement must roll back closure of revision 2.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10s_revision_rollback_before AS
SELECT
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ) AS readiness_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_revised'
  ) AS revised_audit_count;

CREATE FUNCTION pg_temp.s10s_force_readiness_insert_failure()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION
    's10s forced readiness revision insert failure'
    USING ERRCODE = 'P0001';
END
$$;

CREATE TRIGGER s10s_force_readiness_insert_failure
BEFORE INSERT
ON public.booking_safety_readiness
FOR EACH ROW
EXECUTE FUNCTION pg_temp.s10s_force_readiness_insert_failure();

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.record_booking_safety_readiness(
      (SELECT id FROM s10s_booking_newborn),
      'not_ready',
      'ready'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'forced_revision_failure',
    v_state,
    v_message
  );
END
$$;

DROP TRIGGER s10s_force_readiness_insert_failure
ON public.booking_safety_readiness;

-- 85
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'forced_revision_failure'
  ),
  's10s forced readiness revision insert failure',
  'forced replacement insert failure reaches the atomic rollback seam'
);

-- 86
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ) =
  (
    SELECT readiness_count
    FROM s10s_revision_rollback_before
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
      AND readiness.revision_number = 2
      AND readiness.superseded_at IS NULL
      AND readiness.superseded_by IS NULL
  ) = 1
  AND
  (
    SELECT max(readiness.revision_number)
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ) = 2,
  'failed revision insertion rolls back closure and preserves revision 2 as current'
);

-- 87
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_revised'
  ) =
  (
    SELECT revised_audit_count
    FROM s10s_revision_rollback_before
  )
  AND
  NOT EXISTS (
    SELECT 1
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_newborn)
      AND readiness.revision_number = 3
  ),
  'failed revision creates neither revision 3 nor a revised audit event'
);


-- =====================================================================
-- Part 7 — Formal Newborn sign-off core authority semantics
-- =====================================================================

-- Restore canonical Founder identity.

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Sign-off-specific identities.
--
-- Studio Manager also receives Photographer so authority priority can be
-- proved while that member is the current Lead Photographer.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES
  ('90000000-0000-0000-0000-000000000005'::uuid),
  ('90000000-0000-0000-0000-000000000006'::uuid),
  ('90000000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '90000000-0000-0000-0000-000000000015',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000005',
  'active',
  'Sprint 10 Safety Studio Manager Lead'
),
(
  '90000000-0000-0000-0000-000000000016',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000006',
  'active',
  'Sprint 10 Safety Photographer One'
),
(
  '90000000-0000-0000-0000-000000000017',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000007',
  'active',
  'Sprint 10 Safety Photographer Two'
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
  '90000000-0000-0000-0000-000000000201'::uuid
FROM (
  VALUES
    (
      '90000000-0000-0000-0000-000000000015'::uuid,
      'studio_manager'::text
    ),
    (
      '90000000-0000-0000-0000-000000000015'::uuid,
      'photographer'
    ),
    (
      '90000000-0000-0000-0000-000000000016'::uuid,
      'photographer'
    ),
    (
      '90000000-0000-0000-0000-000000000017'::uuid,
      'photographer'
    )
) AS fixture(member_id, role_key)
JOIN public.roles role
  ON role.key =
     fixture.role_key;

-- ---------------------------------------------------------------------
-- Additional Newborn bookings for missing/incomplete/Photographer cases.
-- ---------------------------------------------------------------------

INSERT INTO public.families (
  id,
  organization_id,
  branch_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES
(
  '90000000-0000-0000-0000-000000000027',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000201',
  'LSH-N2B3R4',
  'Sprint 10 Safety No Readiness Family',
  'Safety No Readiness Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000028',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'LSH-P2Q3R4',
  'Sprint 10 Safety Incomplete Family',
  'Safety Incomplete Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
),
(
  '90000000-0000-0000-0000-000000000029',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000201',
  'LSH-T2V3W4',
  'Sprint 10 Safety Photographer Family',
  'Safety Photographer Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10s_booking_no_readiness AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000027',
  '90000000-0000-0000-0000-000000000201'::uuid,
  'newborn_gold'
) AS id;

CREATE TEMP TABLE s10s_booking_incomplete AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000028',
  NULL,
  'newborn_gold'
) AS id;

CREATE TEMP TABLE s10s_booking_photographer AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000029',
  '90000000-0000-0000-0000-000000000201'::uuid,
  'newborn_gold'
) AS id;

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_no_readiness),
  '90000000-0000-0000-0000-000000000011'
);

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_incomplete),
  '90000000-0000-0000-0000-000000000011'
);

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_photographer),
  '90000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10s_incomplete_readiness AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_incomplete),
  'pending',
  'ready'
);

CREATE TEMP TABLE s10s_photographer_readiness AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_photographer),
  'ready',
  'ready'
);

-- ---------------------------------------------------------------------
-- Newborn-only and current-readiness gates.
-- ---------------------------------------------------------------------

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_maternity)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'signoff_maternity',
    v_state,
    v_message
  );
END
$$;

-- 88
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'signoff_maternity'
  ),
  'signoff_booking_safety_readiness: formal sign-off is Newborn-only',
  'formal sign-off fails closed for Maternity'
);

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_no_readiness)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'signoff_missing_readiness',
    v_state,
    v_message
  );
END
$$;

-- 89
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'signoff_missing_readiness'
  ),
  'signoff_booking_safety_readiness: current readiness evidence required',
  'Newborn sign-off requires current readiness evidence'
);

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_incomplete)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'signoff_incomplete_readiness',
    v_state,
    v_message
  );
END
$$;

-- 90
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'signoff_incomplete_readiness'
  ),
  'signoff_booking_safety_readiness: current Newborn readiness must be complete and ready',
  'Newborn sign-off rejects incomplete current readiness'
);

-- ---------------------------------------------------------------------
-- Founder administrative sign-off.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10s_main_journey_before_signoff AS
SELECT
  state.current_stage_id,
  state.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
  ) AS transition_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_newborn);

-- 146
SELECT is(
  public.get_booking_safety_signoff_authority(
    (SELECT id FROM s10s_booking_newborn)
  ),
  'founder'::text,
  'sign-off authority read model resolves Founder precedence'
);

-- 91
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_founder_signoff AS
  SELECT *
  FROM public.signoff_booking_safety_readiness(
    (SELECT id FROM s10s_booking_newborn)
  )
  $$,
  'Founder may formally sign complete current Newborn readiness'
);

-- 92
SELECT ok(
  (
    SELECT
      signoff.booking_id =
        (SELECT id FROM s10s_booking_newborn)
      AND signoff.readiness_id =
        (SELECT id FROM s10s_readiness_v2)
      AND signoff.signed_by =
        '90000000-0000-0000-0000-000000000011'
      AND signoff.signoff_authority =
        'founder'
      AND signoff.lead_assignment_id IS NULL
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10s_founder_signoff)
  ),
  'Founder sign-off snapshots administrative authority against exact current readiness'
);

-- 93
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_signed_off'
      AND audit.entity_type =
          'booking_safety_signoff'
      AND audit.entity_id =
          (SELECT id FROM s10s_founder_signoff)
  ),
  1::bigint,
  'Founder sign-off emits exactly one formal sign-off audit event'
);

-- 94
SELECT ok(
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
        before.version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
              state.booking_id
      ) =
      before.transition_count
    FROM public.booking_journey_states state
    CROSS JOIN s10s_main_journey_before_signoff before
    WHERE state.booking_id =
          (SELECT id FROM s10s_booking_newborn)
  ),
  'Founder formal sign-off does not move the booking journey'
);

-- ---------------------------------------------------------------------
-- Studio Manager priority while also Photographer + current Lead.
--
-- Migration A reconciliation:
-- Studio Manager is branch-only, so use the Branch A booking that
-- already proved the missing-readiness gate above. Establish complete
-- readiness now and let Founder sign first so the original
-- multi-authorized-signer contract remains intact.
-- ---------------------------------------------------------------------

CREATE TEMP TABLE s10s_manager_readiness AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_no_readiness),
  'ready',
  'ready'
);

CREATE TEMP TABLE s10s_manager_founder_signoff AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10s_booking_no_readiness)
);

CREATE TEMP TABLE s10s_manager_lead_assignment AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10s_booking_no_readiness),
  'lead_photographer',
  '90000000-0000-0000-0000-000000000015',
  true,
  NULL
);

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000005',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);

-- 147
SELECT is(
  public.get_booking_safety_signoff_authority(
    (SELECT id FROM s10s_booking_no_readiness)
  ),
  'studio_manager'::text,
  'sign-off authority read model resolves Studio Manager before Photographer Lead authority'
);

-- 95
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_manager_signoff AS
  SELECT *
  FROM public.signoff_booking_safety_readiness(
    (SELECT id FROM s10s_booking_no_readiness)
  )
  $$,
  'Studio Manager may formally sign complete Newborn readiness'
);

-- 96
SELECT ok(
  (
    SELECT
      signoff.signed_by =
        '90000000-0000-0000-0000-000000000015'
      AND signoff.signoff_authority =
        'studio_manager'
      AND signoff.lead_assignment_id IS NULL
      AND signoff.readiness_id =
        (SELECT id FROM s10s_manager_readiness)
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10s_manager_signoff)
  ),
  'Studio Manager authority outranks Photographer/Lead authority and stores no Lead dependency'
);

-- 97
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.readiness_id =
          (SELECT id FROM s10s_manager_readiness)
  ),
  2::bigint,
  'different authorized administrative signers may sign the same readiness revision'
);

-- ---------------------------------------------------------------------
-- Ordinary Photographer must be the current canonical Lead.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000006',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);

-- 148
SELECT ok(
  public.get_booking_safety_signoff_authority(
    (SELECT id FROM s10s_booking_no_readiness)
  ) IS NULL,
  'ordinary Photographer with safety.signoff but without current Lead assignment receives no sign-off authority'
);

DO $$
DECLARE
  v_state text;
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_no_readiness)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_state = RETURNED_SQLSTATE,
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    sqlstate,
    message_text
  )
  VALUES (
    'signoff_nonlead_photographer',
    v_state,
    v_message
  );
END
$$;

-- 98
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'signoff_nonlead_photographer'
  ),
  'signoff_booking_safety_readiness: Photographer must be the current Lead Photographer',
  'ordinary non-Lead Photographer cannot formally sign'
);

-- 99
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          (SELECT id FROM s10s_booking_no_readiness)
      AND signoff.signed_by =
          '90000000-0000-0000-0000-000000000016'
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.readiness_id =
          (SELECT id FROM s10s_manager_readiness)
  ) = 2,
  'non-Lead Photographer denial creates no sign-off evidence'
);

-- ---------------------------------------------------------------------
-- Ordinary current Lead Photographer succeeds and snapshots exact
-- assignment evidence.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10s_photographer_lead_assignment AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10s_booking_photographer),
  'lead_photographer',
  '90000000-0000-0000-0000-000000000016',
  true,
  NULL
);

CREATE TEMP TABLE s10s_photographer_journey_before_signoff AS
SELECT
  state.current_stage_id,
  state.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
  ) AS transition_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_photographer);

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000006',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);

-- 149
SELECT is(
  public.get_booking_safety_signoff_authority(
    (SELECT id FROM s10s_booking_photographer)
  ),
  'lead_photographer'::text,
  'current internal Lead Photographer receives Lead Photographer sign-off authority'
);

-- 100
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_photographer_signoff AS
  SELECT *
  FROM public.signoff_booking_safety_readiness(
    (SELECT id FROM s10s_booking_photographer)
  )
  $$,
  'current canonical Lead Photographer may formally sign Newborn readiness'
);

-- 101
SELECT ok(
  (
    SELECT
      signoff.signed_by =
        '90000000-0000-0000-0000-000000000016'
      AND signoff.signoff_authority =
        'lead_photographer'
      AND signoff.lead_assignment_id =
        (SELECT id FROM s10s_photographer_lead_assignment)
      AND signoff.readiness_id =
        (SELECT id FROM s10s_photographer_readiness)
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10s_photographer_signoff)
  ),
  'Lead Photographer sign-off persists the exact current Lead assignment snapshot'
);

-- 102
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_signed_off'
      AND audit.entity_type =
          'booking_safety_signoff'
      AND audit.entity_id =
          (SELECT id FROM s10s_photographer_signoff)
  ),
  1::bigint,
  'Lead Photographer sign-off emits exactly one formal sign-off audit event'
);

CREATE TEMP TABLE s10s_photographer_signoff_replay AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10s_booking_photographer)
);

-- 103
SELECT is(
  (SELECT id FROM s10s_photographer_signoff_replay),
  (SELECT id FROM s10s_photographer_signoff),
  'same signer and current readiness replay returns the existing sign-off'
);

-- 104
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          (SELECT id FROM s10s_booking_photographer)
      AND signoff.readiness_id =
          (SELECT id FROM s10s_photographer_readiness)
      AND signoff.signed_by =
          '90000000-0000-0000-0000-000000000016'
  ) = 1
  AND
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_signed_off'
      AND audit.entity_id =
          (SELECT id FROM s10s_photographer_signoff)
  ) = 1,
  'same-signer replay creates no duplicate sign-off or audit event'
);

-- 105
SELECT ok(
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
        before.version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
              state.booking_id
      ) =
      before.transition_count
    FROM public.booking_journey_states state
    CROSS JOIN s10s_photographer_journey_before_signoff before
    WHERE state.booking_id =
          (SELECT id FROM s10s_booking_photographer)
  ),
  'Lead Photographer sign-off and replay do not move the booking journey'
);


-- =====================================================================
-- Part 8 — Formal sign-off defense, history and isolation semantics
-- =====================================================================

-- Restore canonical Founder identity.

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- ---------------------------------------------------------------------
-- Remaining non-Newborn categories must also fail closed.
-- ---------------------------------------------------------------------

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_sitter)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_sitter',
    v_message
  );
END
$$;

-- 106
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_sitter'
  ),
  'signoff_booking_safety_readiness: formal sign-off is Newborn-only',
  'formal sign-off fails closed for Sitter'
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_baby)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_baby',
    v_message
  );
END
$$;

-- 107
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_baby'
  ),
  'signoff_booking_safety_readiness: formal sign-off is Newborn-only',
  'formal sign-off fails closed for Baby'
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_child)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_child',
    v_message
  );
END
$$;

-- 108
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_child'
  ),
  'signoff_booking_safety_readiness: formal sign-off is Newborn-only',
  'formal sign-off fails closed for Child'
);

-- ---------------------------------------------------------------------
-- Excluded operational role cannot sign.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES (
  '90000000-0000-0000-0000-000000000010'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '90000000-0000-0000-0000-000000000020',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000010',
  'active',
  'Sprint 10 Safety Assistant Signoff Probe'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000020'::uuid,
  role.id,
  '90000000-0000-0000-0000-000000000201'::uuid
FROM public.roles role
WHERE role.key = 'assistant';

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000010',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000010","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_newborn)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_assistant',
    v_message
  );
END
$$;

-- 109
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_assistant'
  ),
  'signoff_booking_safety_readiness: safety.signoff permission required',
  'Assistant remains excluded from formal sign-off'
);

-- ---------------------------------------------------------------------
-- Foreign-organization authority cannot cross tenant boundary.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000004',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_newborn)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_foreign_founder',
    v_message
  );
END
$$;

-- 110
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_foreign_founder'
  ),
  'signoff_booking_safety_readiness: active organization membership required',
  'foreign-organization Founder cannot sign canonical organization readiness'
);

-- ---------------------------------------------------------------------
-- Lead replacement proves authorization occurs before replay resolution.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10s_photographer_journey_before_3b AS
SELECT
  state.current_stage_id,
  state.version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
          state.booking_id
  ) AS transition_count
FROM public.booking_journey_states state
WHERE state.booking_id =
      (SELECT id FROM s10s_booking_photographer);

CREATE TEMP TABLE s10s_photographer_lead_replacement AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10s_booking_photographer),
  'lead_photographer',
  '90000000-0000-0000-0000-000000000017',
  true,
  'Lead changed for sign-off history test'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000006',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_photographer)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_ended_lead_replay',
    v_message
  );
END
$$;

-- 111
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_ended_lead_replay'
  ),
  'signoff_booking_safety_readiness: Photographer must be the current Lead Photographer',
  'ended former Lead cannot replay an existing historical sign-off'
);

-- 112
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          (SELECT id FROM s10s_booking_photographer)
      AND signoff.readiness_id =
          (SELECT id FROM s10s_photographer_readiness)
      AND signoff.signed_by =
          '90000000-0000-0000-0000-000000000016'
  ),
  1::bigint,
  'authorization-before-replay denial creates no duplicate former-Lead sign-off'
);

-- ---------------------------------------------------------------------
-- Replacement current Lead can sign the same readiness revision.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

-- 113
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_replacement_lead_signoff_v1 AS
  SELECT *
  FROM public.signoff_booking_safety_readiness(
    (SELECT id FROM s10s_booking_photographer)
  )
  $$,
  'replacement current Lead Photographer may sign the current readiness revision'
);

-- 114
SELECT ok(
  (
    SELECT
      signoff.signoff_authority =
        'lead_photographer'
      AND signoff.signed_by =
        '90000000-0000-0000-0000-000000000017'
      AND signoff.lead_assignment_id =
        (SELECT id FROM s10s_photographer_lead_replacement)
      AND signoff.readiness_id =
        (SELECT id FROM s10s_photographer_readiness)
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10s_replacement_lead_signoff_v1)
  ),
  'replacement Lead sign-off snapshots the replacement assignment interval'
);

-- 115
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.readiness_id =
          (SELECT id FROM s10s_photographer_readiness)
  ),
  2::bigint,
  'two different qualifying Lead signers may preserve history on one readiness revision'
);

-- ---------------------------------------------------------------------
-- Readiness revision does not rewrite historical sign-offs.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10s_photographer_readiness_v2 AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_photographer),
  'not_ready',
  'ready'
);

CREATE TEMP TABLE s10s_photographer_readiness_v3 AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_photographer),
  'ready',
  'ready'
);

-- 116
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_photographer)
  ) = 3
  AND
  (
    SELECT revision_number
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          (SELECT id FROM s10s_booking_photographer)
      AND readiness.superseded_at IS NULL
  ) = 3,
  'readiness changes create historical revisions and a new current ready revision'
);

-- 117
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.readiness_id =
          (SELECT id FROM s10s_photographer_readiness)
  ) = 2
  AND
  EXISTS (
    SELECT 1
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10s_photographer_signoff)
      AND signoff.lead_assignment_id =
          (SELECT id FROM s10s_photographer_lead_assignment)
  )
  AND
  EXISTS (
    SELECT 1
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10s_replacement_lead_signoff_v1)
      AND signoff.lead_assignment_id =
          (SELECT id FROM s10s_photographer_lead_replacement)
  ),
  'historical sign-offs remain immutable and bound to their exact old readiness and Lead snapshots'
);

-- 118
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.readiness_id =
          (SELECT id FROM s10s_photographer_readiness_v3)
  ),
  0::bigint,
  'old sign-offs do not sign the new current readiness revision'
);

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

-- 119
SELECT lives_ok(
  $$
  CREATE TEMP TABLE s10s_replacement_lead_signoff_v3 AS
  SELECT *
  FROM public.signoff_booking_safety_readiness(
    (SELECT id FROM s10s_booking_photographer)
  )
  $$,
  'current Lead signs the new current readiness revision independently'
);

-- 120
SELECT ok(
  (
    SELECT
      signoff.readiness_id =
        (SELECT id FROM s10s_photographer_readiness_v3)
      AND signoff.lead_assignment_id =
        (SELECT id FROM s10s_photographer_lead_replacement)
      AND signoff.id <>
        (SELECT id FROM s10s_replacement_lead_signoff_v1)
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.id =
          (SELECT id FROM s10s_replacement_lead_signoff_v3)
  ),
  'new revision receives a distinct immutable sign-off using the current Lead snapshot'
);

-- ---------------------------------------------------------------------
-- Suspension after signing invalidates current authorization before replay.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

UPDATE public.organization_members
SET
  status =
    'suspended'::public.member_status,
  suspended_at =
    now(),
  suspended_by =
    '90000000-0000-0000-0000-000000000011'
WHERE id =
      '90000000-0000-0000-0000-000000000017';

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_photographer)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_suspended_replay',
    v_message
  );
END
$$;

-- 121
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_suspended_replay'
  ),
  'signoff_booking_safety_readiness: active organization membership required',
  'suspended current Lead cannot replay an existing sign-off'
);

-- 122
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.readiness_id =
          (SELECT id FROM s10s_photographer_readiness_v3)
      AND signoff.signed_by =
          '90000000-0000-0000-0000-000000000017'
  ),
  1::bigint,
  'suspension denial preserves existing historical sign-off without duplication'
);

-- ---------------------------------------------------------------------
-- Revoked Photographer role denial.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO auth.users (id)
VALUES (
  '90000000-0000-0000-0000-000000000008'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '90000000-0000-0000-0000-000000000018',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000008',
  'active',
  'Sprint 10 Safety Revoked Photographer'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000018'::uuid,
  role.id,
  '90000000-0000-0000-0000-000000000201'::uuid
FROM public.roles role
WHERE role.key = 'photographer';

INSERT INTO public.families (
  id,
  organization_id,
  branch_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES (
  '90000000-0000-0000-0000-000000000030',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000201',
  'LSH-V2W3X4',
  'Sprint 10 Safety Revoked Lead Family',
  'Safety Revoked Lead Family',
  'active',
  '90000000-0000-0000-0000-000000000011',
  '90000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10s_booking_revoked_photographer AS
SELECT pg_temp.s10s_make_booking(
  '90000000-0000-0000-0000-000000000030',
  '90000000-0000-0000-0000-000000000201'::uuid,
  'newborn_gold'
) AS id;

SELECT pg_temp.s10s_enter_stage9(
  (SELECT id FROM s10s_booking_revoked_photographer),
  '90000000-0000-0000-0000-000000000011'
);

CREATE TEMP TABLE s10s_revoked_readiness AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_revoked_photographer),
  'ready',
  'ready'
);

CREATE TEMP TABLE s10s_revoked_lead_assignment AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10s_booking_revoked_photographer),
  'lead_photographer',
  '90000000-0000-0000-0000-000000000018',
  true,
  NULL
);

UPDATE public.member_role_grants grant_row
SET
  revoked_at =
    now(),
  revoked_by =
    '90000000-0000-0000-0000-000000000011',
  revocation_reason =
    'Sprint 10 sign-off revoked Photographer test'
FROM public.roles role
WHERE grant_row.role_id =
      role.id
  AND grant_row.organization_member_id =
      '90000000-0000-0000-0000-000000000018'
  AND grant_row.revoked_at IS NULL
  AND role.key = 'photographer';

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000008',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000008","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_revoked_photographer)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_revoked_photographer',
    v_message
  );
END
$$;

-- 123
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key = 'signoff_revoked_photographer'
  ),
  'signoff_booking_safety_readiness: safety.signoff permission required',
  'revoked Photographer role cannot authorize formal sign-off'
);

-- 124
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          (SELECT id FROM s10s_booking_revoked_photographer)
  ),
  0::bigint,
  'revoked Photographer denial creates no sign-off evidence'
);

-- ---------------------------------------------------------------------
-- Wrong-branch Photographer denial after historical Lead assignment.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO auth.users (id)
VALUES (
  '90000000-0000-0000-0000-000000000009'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '90000000-0000-0000-0000-000000000019',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000009',
  'active',
  'Sprint 10 Safety Wrong Branch Photographer'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000019'::uuid,
  role.id,
  '90000000-0000-0000-0000-000000000201'::uuid
FROM public.roles role
WHERE role.key = 'photographer';

CREATE TEMP TABLE s10s_branch_readiness AS
SELECT *
FROM public.record_booking_safety_readiness(
  (SELECT id FROM s10s_booking_branch),
  'ready',
  'ready'
);

CREATE TEMP TABLE s10s_wrong_branch_lead_assignment AS
SELECT *
FROM public.assign_booking_team_member(
  (SELECT id FROM s10s_booking_branch),
  'lead_photographer',
  '90000000-0000-0000-0000-000000000019',
  true,
  NULL
);

UPDATE public.member_role_grants grant_row
SET
  revoked_at =
    now(),
  revoked_by =
    '90000000-0000-0000-0000-000000000011',
  revocation_reason =
    'Replace Branch A role with wrong-branch role'
FROM public.roles role
WHERE grant_row.role_id =
      role.id
  AND grant_row.organization_member_id =
      '90000000-0000-0000-0000-000000000019'
  AND grant_row.branch_id =
      '90000000-0000-0000-0000-000000000201'::uuid
  AND grant_row.revoked_at IS NULL
  AND role.key = 'photographer';

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000019'::uuid,
  role.id,
  '90000000-0000-0000-0000-000000000202'::uuid
FROM public.roles role
WHERE role.key = 'photographer';

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000009',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000009","role":"authenticated"}',
  true
);

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM public.signoff_booking_safety_readiness(
      (SELECT id FROM s10s_booking_branch)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_message = MESSAGE_TEXT;
  END;

  INSERT INTO s10s_error_capture (
    test_key,
    message_text
  )
  VALUES (
    'signoff_wrong_branch_photographer',
    v_message
  );
END
$$;

-- 125
SELECT is(
  (
    SELECT message_text
    FROM s10s_error_capture
    WHERE test_key =
          'signoff_wrong_branch_photographer'
  ),
  'signoff_booking_safety_readiness: safety.signoff permission required',
  'wrong-branch Photographer role cannot authorize branch booking sign-off'
);

-- 126
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          (SELECT id FROM s10s_booking_branch)
  ),
  0::bigint,
  'wrong-branch Photographer denial creates no sign-off evidence'
);

-- ---------------------------------------------------------------------
-- Authenticated table mutation remains denied.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 127
SELECT throws_ok(
  $$
  UPDATE public.booking_safety_signoffs
  SET signed_at = signed_at
  WHERE id =
        (SELECT id FROM s10s_founder_signoff)
  $$,
  '42501',
  'permission denied for table booking_safety_signoffs',
  'authenticated direct sign-off UPDATE is denied'
);

-- 128
SELECT throws_ok(
  $$
  DELETE FROM public.booking_safety_signoffs
  WHERE id =
        (SELECT id FROM s10s_founder_signoff)
  $$,
  '42501',
  'permission denied for table booking_safety_signoffs',
  'authenticated direct sign-off DELETE is denied'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Trusted service_role remains subject to lifecycle guard.
-- ---------------------------------------------------------------------

SET LOCAL ROLE service_role;

-- 129
SELECT throws_ok(
  $$
  UPDATE public.booking_safety_signoffs
  SET signed_at = signed_at
  WHERE signed_by =
        '90000000-0000-0000-0000-000000000011'::uuid
    AND signoff_authority =
        'founder'
  $$,
  '42501',
  'booking_safety_signoffs: sign-offs are immutable',
  'trusted direct UPDATE cannot rewrite immutable sign-off evidence'
);

-- 130
SELECT throws_ok(
  $$
  DELETE FROM public.booking_safety_signoffs
  WHERE signed_by =
        '90000000-0000-0000-0000-000000000011'::uuid
    AND signoff_authority =
        'founder'
  $$,
  '42501',
  'booking_safety_signoffs: deletion is not permitted',
  'trusted direct DELETE cannot remove sign-off evidence'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Audit cardinality and restricted structural payload.
-- ---------------------------------------------------------------------

-- 131
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_signed_off'
      AND audit.entity_type =
          'booking_safety_signoff'
  ) =
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs
  )
  AND
  NOT EXISTS (
    SELECT 1
    FROM public.booking_safety_signoffs signoff
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.audit_events audit
      WHERE audit.action_key =
            'booking.safety_readiness_signed_off'
        AND audit.entity_type =
            'booking_safety_signoff'
        AND audit.entity_id =
            signoff.id
    )
  ),
  'every real sign-off has exactly one corresponding formal sign-off audit'
);

-- 132
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.audit_events audit
    WHERE audit.action_key =
          'booking.safety_readiness_signed_off'
      AND (
        audit.metadata::text ~*
          'medical'
        OR audit.metadata::text ~*
          'diagnos'
        OR audit.metadata::text ~*
          'allerg'
        OR audit.metadata::text ~*
          'sensitivity'
        OR audit.metadata::text ~*
          'free.?text'
        OR audit.metadata::text ~*
          '"notes?"'
      )
  ),
  'formal sign-off audit payload contains no sensitive or unrestricted free-text fields'
);

-- ---------------------------------------------------------------------
-- Entire replacement/revision/sign-off sequence remains evidence-only.
-- ---------------------------------------------------------------------

-- 133
SELECT ok(
  (
    SELECT
      state.current_stage_id =
        before.current_stage_id
      AND state.version =
        before.version
      AND (
        SELECT count(*)::bigint
        FROM public.booking_stage_transitions transition_row
        WHERE transition_row.booking_id =
              state.booking_id
      ) =
      before.transition_count
    FROM public.booking_journey_states state
    CROSS JOIN s10s_photographer_journey_before_3b before
    WHERE state.booking_id =
          (SELECT id FROM s10s_booking_photographer)
  ),
  'Lead replacement, readiness revisions and formal sign-offs never move the booking journey'
);


-- =====================================================================
-- Part 9 — Restricted runtime read / RLS boundary
-- =====================================================================

-- Restore the organization-wide Founder and create one formal sign-off
-- on the branch-scoped Newborn booking so both restricted tables contain
-- branch-scoped evidence for the RLS probes.

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

CREATE TEMP TABLE s10s_branch_founder_signoff AS
SELECT *
FROM public.signoff_booking_safety_readiness(
  (SELECT id FROM s10s_booking_branch)
);

-- Save generated booking IDs in transaction-local settings so restricted
-- ROLE authenticated queries do not need SELECT access to temp tables.

SELECT set_config(
  's10s.rls.main_booking_id',
  (SELECT id::text FROM s10s_booking_newborn),
  true
);

SELECT set_config(
  's10s.rls.branch_booking_id',
  (SELECT id::text FROM s10s_booking_branch),
  true
);

-- ---------------------------------------------------------------------
-- Same-branch safety reader.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES (
  '90000000-0000-0000-0000-000000000011'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '90000000-0000-0000-0000-000000000031',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000011',
  'active',
  'Sprint 10 Safety Branch A Reader'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000031'::uuid,
  role.id,
  '90000000-0000-0000-0000-000000000201'::uuid
FROM public.roles role
WHERE role.key = 'assistant';

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000011',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000011","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 134
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          current_setting(
            's10s.rls.branch_booking_id'
          )::uuid
  ),
  1::bigint,
  'same-branch safety.read member can read branch readiness evidence'
);

-- 135
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          current_setting(
            's10s.rls.branch_booking_id'
          )::uuid
  ),
  1::bigint,
  'same-branch safety.read member can read branch sign-off evidence'
);

-- 136
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          current_setting(
            's10s.rls.main_booking_id'
          )::uuid
  ) = 0
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          current_setting(
            's10s.rls.main_booking_id'
          )::uuid
  ) = 0,
  'branch-scoped safety reader cannot read branchless safety evidence'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Existing Branch B Assistant has safety.read, but not Branch A scope.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 137
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id =
          current_setting(
            's10s.rls.branch_booking_id'
          )::uuid
  ) = 0
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id =
          current_setting(
            's10s.rls.branch_booking_id'
          )::uuid
  ) = 0,
  'wrong-branch safety.read member cannot read Branch A safety evidence'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Ordinary booking.read without safety.read must not expose restricted
-- safety evidence.
-- ---------------------------------------------------------------------

INSERT INTO auth.users (id)
VALUES (
  '90000000-0000-0000-0000-000000000012'::uuid
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '90000000-0000-0000-0000-000000000032',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '90000000-0000-0000-0000-000000000012',
  'active',
  'Sprint 10 Safety Sales Reader'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '90000000-0000-0000-0000-000000000032'::uuid,
  role.id,
  '90000000-0000-0000-0000-000000000201'::uuid
FROM public.roles role
WHERE role.key = 'sales';

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000012',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000012","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 138
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.bookings booking
    WHERE booking.id IN (
      current_setting(
        's10s.rls.main_booking_id'
      )::uuid,
      current_setting(
        's10s.rls.branch_booking_id'
      )::uuid
    )
  ),
  1::bigint,
  'Branch A Sales booking.read role can read only the in-scope ordinary booking record'
);

-- 139
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id IN (
      current_setting(
        's10s.rls.main_booking_id'
      )::uuid,
      current_setting(
        's10s.rls.branch_booking_id'
      )::uuid
    )
  ),
  0::bigint,
  'booking.read without safety.read exposes no readiness evidence'
);

-- 140
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id IN (
      current_setting(
        's10s.rls.main_booking_id'
      )::uuid,
      current_setting(
        's10s.rls.branch_booking_id'
      )::uuid
    )
  ),
  0::bigint,
  'booking.read without safety.read exposes no sign-off evidence'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Foreign-organization Founder cannot read canonical organization
-- restricted safety evidence.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000004',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 141
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id IN (
      current_setting(
        's10s.rls.main_booking_id'
      )::uuid,
      current_setting(
        's10s.rls.branch_booking_id'
      )::uuid
    )
  ) = 0
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id IN (
      current_setting(
        's10s.rls.main_booking_id'
      )::uuid,
      current_setting(
        's10s.rls.branch_booking_id'
      )::uuid
    )
  ) = 0,
  'foreign-organization Founder cannot read canonical safety evidence'
);

RESET ROLE;

-- ---------------------------------------------------------------------
-- Organization-wide Founder remains the positive control.
--
-- Main booking:
--   2 readiness revisions + 2 sign-offs.
--
-- Branch booking:
--   1 readiness revision + 1 Founder sign-off.
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 142
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_readiness readiness
    WHERE readiness.booking_id IN (
      current_setting(
        's10s.rls.main_booking_id'
      )::uuid,
      current_setting(
        's10s.rls.branch_booking_id'
      )::uuid
    )
  ) = 3
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_safety_signoffs signoff
    WHERE signoff.booking_id IN (
      current_setting(
        's10s.rls.main_booking_id'
      )::uuid,
      current_setting(
        's10s.rls.branch_booking_id'
      )::uuid
    )
  ) = 2,
  'organization-wide Founder can read authorized safety evidence across branchless and branch bookings'
);

RESET ROLE;

SELECT * FROM finish();

ROLLBACK;
