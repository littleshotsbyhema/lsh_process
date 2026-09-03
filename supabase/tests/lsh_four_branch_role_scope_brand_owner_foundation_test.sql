CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(76);

-- =====================================================================
-- LSH FOUR-BRANCH ROLE AND SALES HIERARCHY
-- Migration A dedicated pgTAP
--
-- Migration:
-- 20260903084543_lsh_four_branch_role_scope_brand_owner_foundation.sql
--
-- All fixture mutations are transaction-local and disappear on ROLLBACK.
-- =====================================================================


-- =====================================================================
-- Part 1 — Canonical branch / role / permission foundation
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.branches
    WHERE code IN (
      'coimbatore',
      'erode',
      'bengaluru-mahadevapura',
      'bengaluru-jp-nagar'
    )
  ),
  4::bigint,
  'exactly four canonical LSH branches exist'
);

-- 2
SELECT is(
  (
    SELECT string_agg(code, ',' ORDER BY code)
    FROM public.branches
    WHERE code IN (
      'coimbatore',
      'erode',
      'bengaluru-mahadevapura',
      'bengaluru-jp-nagar'
    )
  ),
  'bengaluru-jp-nagar,bengaluru-mahadevapura,coimbatore,erode',
  'canonical branch codes match the approved four-branch model'
);

-- 3
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.branches
    WHERE code IN (
      'coimbatore',
      'erode',
      'bengaluru-mahadevapura',
      'bengaluru-jp-nagar'
    )
      AND status = 'active'::public.branch_status
      AND deleted_at IS NULL
  ),
  4::bigint,
  'all four canonical branches are live'
);

-- 4
SELECT is(
  (
    SELECT label
    FROM public.roles
    WHERE key = 'founder'
  ),
  'Founder / Brand Owner / Studio Head',
  'Founder role uses the approved authority label'
);

-- 5
SELECT is(
  (
    SELECT label
    FROM public.roles
    WHERE key = 'sales_head'
  ),
  'Brand Sales Head',
  'sales_head is labelled Brand Sales Head'
);

-- 6
SELECT is(
  (
    SELECT label
    FROM public.roles
    WHERE key = 'sales'
  ),
  'Sales Team Member',
  'sales database key is labelled Sales Team Member'
);

-- 7
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions
    WHERE key IN (
      'lead.assign',
      'lead.branch.reassign',
      'sales.team.read',
      'sales.team.invite',
      'sales.team.scope.assign'
    )
  ),
  5::bigint,
  'all five Sales hierarchy authority permissions exist'
);

-- 8
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE r.key = 'founder'
      AND p.key IN (
        'lead.assign',
        'lead.branch.reassign',
        'sales.team.read',
        'sales.team.invite',
        'sales.team.scope.assign'
      )
  ),
  5::bigint,
  'Founder receives all five Sales hierarchy authority permissions'
);

-- 9
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE r.key = 'sales_head'
      AND p.key IN (
        'lead.assign',
        'lead.branch.reassign',
        'sales.team.read',
        'sales.team.invite',
        'sales.team.scope.assign'
      )
  ),
  5::bigint,
  'Brand Sales Head receives all five Sales management permissions'
);

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE r.key = 'sales'
      AND p.key IN (
        'lead.assign',
        'lead.branch.reassign',
        'sales.team.read',
        'sales.team.invite',
        'sales.team.scope.assign'
      )
  ),
  0::bigint,
  'Sales Team Member receives none of the five management permissions'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions rp
    JOIN public.roles r
      ON r.id = rp.role_id
    WHERE r.key = 'founder'
  ),
  (
    SELECT count(*)::bigint
    FROM public.permissions
  ),
  'Founder role maps every current permission'
);


-- =====================================================================
-- Part 2 — Role scope policy constitution
-- =====================================================================

-- 12
SELECT ok(
  to_regclass('public.role_scope_policies') IS NOT NULL,
  'role_scope_policies exists'
);

-- 13
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_scope_policies
  ),
  (
    SELECT count(*)::bigint
    FROM public.roles
  ),
  'every role has an explicit scope policy'
);

-- 14
SELECT ok(
  (
    SELECT
      rsp.organization_wide_allowed
      AND NOT rsp.branch_scoped_allowed
    FROM public.role_scope_policies rsp
    JOIN public.roles r
      ON r.id = rsp.role_id
    WHERE r.key = 'founder'
  ),
  'Founder is organization-wide only'
);

-- 15
SELECT ok(
  (
    SELECT
      rsp.organization_wide_allowed
      AND rsp.branch_scoped_allowed
    FROM public.role_scope_policies rsp
    JOIN public.roles r
      ON r.id = rsp.role_id
    WHERE r.key = 'sales_head'
  ),
  'Brand Sales Head allows organization-wide or branch scope'
);

-- 16
SELECT ok(
  (
    SELECT
      NOT rsp.organization_wide_allowed
      AND rsp.branch_scoped_allowed
    FROM public.role_scope_policies rsp
    JOIN public.roles r
      ON r.id = rsp.role_id
    WHERE r.key = 'sales'
  ),
  'Sales Team Member is branch-scoped only'
);

-- 17
SELECT ok(
  to_regclass('public.organization_brand_owners') IS NOT NULL,
  'organization_brand_owners exists'
);

-- 18
SELECT ok(
  (
    SELECT
      c.relrowsecurity
      AND c.relforcerowsecurity
    FROM pg_class c
    WHERE c.oid =
      to_regclass('public.role_scope_policies')
  ),
  'role_scope_policies has RLS and FORCE RLS'
);

-- 19
SELECT ok(
  (
    SELECT
      c.relrowsecurity
      AND c.relforcerowsecurity
    FROM pg_class c
    WHERE c.oid =
      to_regclass('public.organization_brand_owners')
  ),
  'organization_brand_owners has RLS and FORCE RLS'
);


-- =====================================================================
-- Part 3 — Guard and helper surfaces
-- =====================================================================

-- 20
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger t
    WHERE t.tgrelid =
      to_regclass('public.member_role_grants')
      AND t.tgname =
        'member_role_grants_15_role_scope_guard'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'live member-role scope guard exists exactly once'
);

-- 21
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger t
    WHERE t.tgrelid =
      to_regclass('public.organization_members')
      AND t.tgname =
        'organization_members_10_brand_owner_guard'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'Brand Owner membership guard exists exactly once'
);

-- 22
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger t
    WHERE t.tgrelid =
      to_regclass('public.member_role_grants')
      AND t.tgname =
        'member_role_grants_10_brand_owner_guard'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'Brand Owner Founder-grant guard exists exactly once'
);

-- 23
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger t
    WHERE t.tgrelid =
      to_regclass('public.organization_brand_owners')
      AND t.tgname =
        'organization_brand_owners_10_immutable_guard'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'Brand Owner identity immutability guard exists exactly once'
);

-- 24
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger t
    WHERE t.tgrelid =
      to_regclass('public.member_role_grants')
      AND t.tgname =
        'member_role_grants_reject_branch_founder'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'branch-scoped Founder rejection guard exists exactly once'
);

-- 25
SELECT ok(
  to_regprocedure(
    'public.lsh_bootstrap_canonical_founder(uuid,text)'
  ) IS NOT NULL
  AND
  to_regprocedure(
    'public.organization_shell_identity(uuid)'
  ) IS NOT NULL
  AND
  to_regprocedure(
    'public.accessible_branch_catalogue(uuid)'
  ) IS NOT NULL,
  'Founder bootstrap and organization shell helper signatures exist'
);

-- 26
SELECT ok(
  has_function_privilege(
    'service_role',
    'public.lsh_bootstrap_canonical_founder(uuid,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'authenticated',
    'public.lsh_bootstrap_canonical_founder(uuid,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.lsh_bootstrap_canonical_founder(uuid,text)',
    'EXECUTE'
  ),
  'canonical Founder bootstrap is service-role-only'
);

-- 27
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.organization_shell_identity(uuid)',
    'EXECUTE'
  )
  AND
  has_function_privilege(
    'authenticated',
    'public.accessible_branch_catalogue(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.organization_shell_identity(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.accessible_branch_catalogue(uuid)',
    'EXECUTE'
  ),
  'shell identity and branch catalogue are authenticated-only'
);


-- =====================================================================
-- Part 4 — Canonical Founder bootstrap
-- =====================================================================

INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at
)
VALUES (
  'a9000000-0000-4000-8000-000000000001'::uuid,
  'littleshotsbyhema@gmail.com',
  now()
);

SELECT set_config(
  'request.jwt.claim.role',
  'service_role',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

SET LOCAL ROLE service_role;

SELECT *
FROM public.lsh_bootstrap_canonical_founder(
  'a9000000-0000-4000-8000-000000000001'::uuid,
  'littleshotsbyhema@gmail.com'
);

RESET ROLE;

-- 28
SELECT ok(
  (
    SELECT status = 'active'::public.organization_status
    FROM public.organizations
    WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.organization_brand_owners
    WHERE organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ) = 1::bigint
  AND
  (
    SELECT count(*)::bigint
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    JOIN public.organization_brand_owners bo
      ON bo.organization_id =
         g.organization_id
     AND bo.organization_member_id =
         g.organization_member_id
    WHERE bo.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND r.key = 'founder'
      AND g.branch_id IS NULL
      AND g.revoked_at IS NULL
  ) = 1::bigint,
  'bootstrap activates organization and establishes canonical organization-wide Founder'
);

CREATE TEMP TABLE lsha_ctx ON COMMIT DROP AS
SELECT
  bo.organization_id,
  bo.organization_member_id AS founder_member_id,
  founder_member.user_id AS founder_user_id,
  founder_grant.id AS founder_grant_id,
  founder_role.id AS founder_role_id,
  sales_head_role.id AS sales_head_role_id,
  sales_role.id AS sales_role_id,
  coimbatore.id AS coimbatore_id,
  erode.id AS erode_id,
  jp.id AS jp_id,
  mahadevapura.id AS mahadevapura_id
FROM public.organization_brand_owners bo
JOIN public.organization_members founder_member
  ON founder_member.id =
     bo.organization_member_id
 AND founder_member.organization_id =
     bo.organization_id
JOIN public.roles founder_role
  ON founder_role.key = 'founder'
JOIN public.roles sales_head_role
  ON sales_head_role.key = 'sales_head'
JOIN public.roles sales_role
  ON sales_role.key = 'sales'
JOIN public.member_role_grants founder_grant
  ON founder_grant.organization_id =
     bo.organization_id
 AND founder_grant.organization_member_id =
     bo.organization_member_id
 AND founder_grant.role_id =
     founder_role.id
 AND founder_grant.branch_id IS NULL
 AND founder_grant.revoked_at IS NULL
JOIN public.branches coimbatore
  ON coimbatore.organization_id =
     bo.organization_id
 AND coimbatore.code = 'coimbatore'
JOIN public.branches erode
  ON erode.organization_id =
     bo.organization_id
 AND erode.code = 'erode'
JOIN public.branches jp
  ON jp.organization_id =
     bo.organization_id
 AND jp.code = 'bengaluru-jp-nagar'
JOIN public.branches mahadevapura
  ON mahadevapura.organization_id =
     bo.organization_id
 AND mahadevapura.code =
     'bengaluru-mahadevapura';


SELECT set_config(
  'lsha.coimbatore_id',
  (SELECT coimbatore_id::text FROM pg_temp.lsha_ctx),
  true
);

SELECT set_config(
  'lsha.erode_id',
  (SELECT erode_id::text FROM pg_temp.lsha_ctx),
  true
);

SELECT set_config(
  'lsha.jp_id',
  (SELECT jp_id::text FROM pg_temp.lsha_ctx),
  true
);

SELECT set_config(
  'lsha.mahadevapura_id',
  (SELECT mahadevapura_id::text FROM pg_temp.lsha_ctx),
  true
);

SELECT set_config(
  'lsha.expected_permission_count',
  (
    SELECT count(*)::text
    FROM public.permissions
  ),
  true
);

SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 29
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.effective_permissions(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      NULL
    )
  ),
  current_setting(
    'lsha.expected_permission_count'
  )::bigint,
  'canonical Founder receives every effective permission organization-wide'
);

-- 30
SELECT is(
  (
    SELECT string_agg(branch_code, ',' ORDER BY branch_code)
    FROM public.accessible_branch_catalogue(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'bengaluru-jp-nagar,bengaluru-mahadevapura,coimbatore,erode',
  'Founder sees all four canonical branches'
);

-- 31
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.organization_shell_identity(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  1::bigint,
  'organization_shell_identity works for active Founder'
);

RESET ROLE;


-- =====================================================================
-- Part 5 — Brand Owner protection probes
-- =====================================================================

CREATE FUNCTION pg_temp.lsha_founder_downgrade_denied()
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE
  v_ctx record;
BEGIN
  SELECT *
  INTO v_ctx
  FROM pg_temp.lsha_ctx;

  UPDATE public.member_role_grants
  SET role_id = v_ctx.sales_head_role_id
  WHERE id = v_ctx.founder_grant_id;

  RETURN false;
EXCEPTION
  WHEN OTHERS THEN
    RETURN position(
      'Brand Owner Founder authority cannot be revoked, downgraded, moved or branch-scoped'
      IN SQLERRM
    ) > 0;
END
$function$;

CREATE FUNCTION pg_temp.lsha_founder_branch_scope_denied()
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE
  v_ctx record;
BEGIN
  SELECT *
  INTO v_ctx
  FROM pg_temp.lsha_ctx;

  UPDATE public.member_role_grants
  SET branch_id = v_ctx.coimbatore_id
  WHERE id = v_ctx.founder_grant_id;

  RETURN false;
EXCEPTION
  WHEN OTHERS THEN
    RETURN position(
      'Brand Owner Founder authority cannot be revoked, downgraded, moved or branch-scoped'
      IN SQLERRM
    ) > 0;
END
$function$;

CREATE FUNCTION pg_temp.lsha_founder_suspension_denied()
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE
  v_ctx record;
BEGIN
  SELECT *
  INTO v_ctx
  FROM pg_temp.lsha_ctx;

  UPDATE public.organization_members
  SET
    status = 'suspended'::public.member_status,
    suspended_at = now(),
    suspended_by = v_ctx.founder_member_id,
    suspension_reason =
      'Migration A pgTAP negative probe'
  WHERE id = v_ctx.founder_member_id
    AND organization_id = v_ctx.organization_id;

  RETURN false;
EXCEPTION
  WHEN OTHERS THEN
    RETURN position(
      'Brand Owner membership cannot be suspended'
      IN SQLERRM
    ) > 0;
END
$function$;

CREATE FUNCTION pg_temp.lsha_founder_revocation_denied()
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE
  v_ctx record;
BEGIN
  SELECT *
  INTO v_ctx
  FROM pg_temp.lsha_ctx;

  UPDATE public.member_role_grants
  SET
    revoked_at = now(),
    revoked_by = v_ctx.founder_member_id,
    revocation_reason =
      'Migration A pgTAP negative probe'
  WHERE id = v_ctx.founder_grant_id;

  RETURN false;
EXCEPTION
  WHEN OTHERS THEN
    RETURN position(
      'Brand Owner Founder authority cannot be revoked, downgraded, moved or branch-scoped'
      IN SQLERRM
    ) > 0;
END
$function$;

-- 32
SELECT ok(
  pg_temp.lsha_founder_downgrade_denied(),
  'canonical Brand Owner cannot be downgraded from Founder'
);

-- 33
SELECT ok(
  pg_temp.lsha_founder_branch_scope_denied(),
  'canonical Brand Owner cannot become branch-scoped'
);

-- 34
SELECT ok(
  pg_temp.lsha_founder_suspension_denied(),
  'canonical Brand Owner membership cannot be suspended'
);

-- 35
SELECT ok(
  pg_temp.lsha_founder_revocation_denied(),
  'canonical Brand Owner Founder grant cannot be revoked'
);


-- =====================================================================
-- Part 6 — Sales Team Member and Brand Sales Head fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  (
    'a9000000-0000-4000-8000-000000000002'::uuid
  ),
  (
    'a9000000-0000-4000-8000-000000000003'::uuid
  );

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
  (
    'a9000000-0000-4000-8000-000000000012'::uuid,
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'a9000000-0000-4000-8000-000000000002'::uuid,
    'active'::public.member_status,
    'Migration A pgTAP Brand Sales Head'
  ),
  (
    'a9000000-0000-4000-8000-000000000013'::uuid,
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'a9000000-0000-4000-8000-000000000003'::uuid,
    'active'::public.member_status,
    'Migration A pgTAP Sales Team Member'
  );


CREATE FUNCTION pg_temp.lsha_grant_denied(
  p_organization_id uuid,
  p_member_id uuid,
  p_role_key text,
  p_branch_id uuid,
  p_expected_state text DEFAULT NULL,
  p_expected_fragment text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM public.grant_organization_member_role(
    p_organization_id,
    p_member_id,
    p_role_key,
    p_branch_id
  );

  RETURN false;

EXCEPTION
  WHEN OTHERS THEN
    RETURN
      (
        p_expected_state IS NULL
        OR SQLSTATE = p_expected_state
      )
      AND
      (
        p_expected_fragment IS NULL
        OR position(
          lower(p_expected_fragment)
          IN lower(SQLERRM)
        ) > 0
      );
END
$function$;


-- Restore authenticated Founder.
SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

SELECT set_config(
  'lsha.sales_orgwide_denied',
  pg_temp.lsha_grant_denied(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'a9000000-0000-4000-8000-000000000013'::uuid,
    'sales',
    NULL,
    NULL,
    NULL
  )::text,
  true
);

RESET ROLE;

-- 36
SELECT ok(
  current_setting(
    'lsha.sales_orgwide_denied'
  )::boolean
  AND NOT EXISTS (
    SELECT 1
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    WHERE g.organization_member_id =
      'a9000000-0000-4000-8000-000000000013'::uuid
      AND r.key = 'sales'
      AND g.branch_id IS NULL
      AND g.revoked_at IS NULL
  ),
  'Sales Team Member organization-wide grant is denied'
);

SET LOCAL ROLE authenticated;

SELECT public.grant_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'a9000000-0000-4000-8000-000000000013'::uuid,
  'sales',
  current_setting(
    'lsha.coimbatore_id'
  )::uuid
);

SELECT public.grant_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'a9000000-0000-4000-8000-000000000013'::uuid,
  'sales',
  current_setting(
    'lsha.erode_id'
  )::uuid
);

RESET ROLE;

-- 37
SELECT is(
  (
    SELECT string_agg(b.code, ',' ORDER BY b.code)
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id =
         g.organization_id
    WHERE g.organization_member_id =
      'a9000000-0000-4000-8000-000000000013'::uuid
      AND r.key = 'sales'
      AND g.revoked_at IS NULL
  ),
  'coimbatore,erode',
  'Sales Team Member supports simultaneous multi-branch grants'
);


SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 38
SELECT is(
  (
    SELECT string_agg(branch_code, ',' ORDER BY branch_code)
    FROM public.accessible_branch_catalogue(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'coimbatore,erode',
  'Sales Team Member branch catalogue returns only authorized branch union'
);

-- 39
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.organization_shell_identity(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  1::bigint,
  'organization_shell_identity works for active Sales Team Member'
);

RESET ROLE;


-- =====================================================================
-- Part 7 — Brand Sales Head organization-wide and multi-branch modes
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

SELECT public.grant_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'a9000000-0000-4000-8000-000000000012'::uuid,
  'sales_head',
  NULL
);

RESET ROLE;

-- 40
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    WHERE g.organization_member_id =
      'a9000000-0000-4000-8000-000000000012'::uuid
      AND r.key = 'sales_head'
      AND g.branch_id IS NULL
      AND g.revoked_at IS NULL
  ),
  1::bigint,
  'Brand Sales Head organization-wide grant works'
);


SET LOCAL ROLE authenticated;

SELECT set_config(
  'lsha.sales_head_mixed_denied',
  pg_temp.lsha_grant_denied(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'a9000000-0000-4000-8000-000000000012'::uuid,
    'sales_head',
    current_setting(
      'lsha.jp_id'
    )::uuid,
    NULL,
    NULL
  )::text,
  true
);

RESET ROLE;

-- 41
SELECT ok(
  current_setting(
    'lsha.sales_head_mixed_denied'
  )::boolean
  AND
  (
    SELECT count(*)::bigint
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    WHERE g.organization_member_id =
      'a9000000-0000-4000-8000-000000000012'::uuid
      AND r.key = 'sales_head'
      AND g.revoked_at IS NULL
  ) = 1::bigint,
  'Brand Sales Head organization-wide plus branch coexistence is denied'
);

SET LOCAL ROLE authenticated;

SELECT public.revoke_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'a9000000-0000-4000-8000-000000000012'::uuid,
  'sales_head',
  NULL,
  'Migration A pgTAP switch to multi-branch mode'
);

SELECT public.grant_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'a9000000-0000-4000-8000-000000000012'::uuid,
  'sales_head',
  current_setting(
    'lsha.jp_id'
  )::uuid
);

SELECT public.grant_organization_member_role(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'a9000000-0000-4000-8000-000000000012'::uuid,
  'sales_head',
  current_setting(
    'lsha.mahadevapura_id'
  )::uuid
);

RESET ROLE;

-- 42
SELECT is(
  (
    SELECT string_agg(b.code, ',' ORDER BY b.code)
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id =
         g.organization_id
    WHERE g.organization_member_id =
      'a9000000-0000-4000-8000-000000000012'::uuid
      AND r.key = 'sales_head'
      AND g.revoked_at IS NULL
  ),
  'bengaluru-jp-nagar,bengaluru-mahadevapura',
  'Brand Sales Head multi-branch mode supports multiple live branch grants'
);


SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 43
SELECT is(
  (
    SELECT string_agg(branch_code, ',' ORDER BY branch_code)
    FROM public.accessible_branch_catalogue(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'bengaluru-jp-nagar,bengaluru-mahadevapura',
  'multi-branch Brand Sales Head sees exactly its authorized branch union'
);

RESET ROLE;


-- =====================================================================
-- Part 8 — Wrong / foreign / inactive branch rejection
-- =====================================================================

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
  'a9000000-0000-4000-8000-000000000201'::uuid,
  'Migration A Foreign Organization',
  'migration-a-foreign-organization',
  'suspended'::public.organization_status,
  'INR',
  'Asia/Kolkata',
  'TST'
);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  country_code
)
VALUES (
  'a9000000-0000-4000-8000-000000000202'::uuid,
  'a9000000-0000-4000-8000-000000000201'::uuid,
  'Migration A Foreign Branch',
  'migration-a-foreign',
  'active'::public.branch_status,
  'IN'
);


SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 44
SELECT ok(
  pg_temp.lsha_grant_denied(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'a9000000-0000-4000-8000-000000000013'::uuid,
    'sales',
    'a9000000-0000-4000-8000-000000000299'::uuid,
    '42501',
    'no access to requested branch'
  ),
  'non-existent branch grant is denied'
);

-- 45
SELECT ok(
  pg_temp.lsha_grant_denied(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'a9000000-0000-4000-8000-000000000013'::uuid,
    'sales',
    'a9000000-0000-4000-8000-000000000202'::uuid,
    '42501',
    'no access to requested branch'
  ),
  'foreign-organization branch grant is denied'
);

RESET ROLE;


UPDATE public.branches
SET status = 'inactive'::public.branch_status
WHERE id = (
  SELECT jp_id
  FROM pg_temp.lsha_ctx
);


SET LOCAL ROLE authenticated;

-- 46
SELECT ok(
  pg_temp.lsha_grant_denied(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'a9000000-0000-4000-8000-000000000013'::uuid,
    'sales',
    current_setting(
      'lsha.jp_id'
    )::uuid,
    '42501',
    'no access to requested branch'
  ),
  'inactive branch grant is denied'
);

RESET ROLE;

UPDATE public.branches
SET status = 'active'::public.branch_status
WHERE id = (
  SELECT jp_id
  FROM pg_temp.lsha_ctx
);


-- =====================================================================
-- Part 9 — Invitation role-scope integration contract
--
-- Migration A makes role_scope_policies authoritative for both live
-- member grants and pre-acceptance invitation role assignments.
--
-- The existing create_organization_invitation(...) API is intentionally
-- unscoped and therefore may only pre-authorize organization-wide-
-- capable roles. Explicit branch-scoped invitation rows remain valid
-- at the underlying invariant boundary.
-- =====================================================================


-- 47
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_trigger t
    WHERE t.tgrelid =
          to_regclass(
            'public.organization_invitation_roles'
          )
      AND t.tgname =
          'organization_invitation_roles_20_guard'
      AND NOT t.tgisinternal
  ),
  1::bigint,
  'invitation-role constitutional guard exists exactly once'
);


-- 48
SELECT ok(
  NOT has_function_privilege(
    'authenticated',
    'public.lsh_organization_invitation_roles_guard()',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.lsh_organization_invitation_roles_guard()',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.lsh_organization_invitation_roles_guard()',
    'EXECUTE'
  ),
  'invitation-role constitutional guard is not directly callable by client or service roles'
);


SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);


-- Establish a valid role-less invitation first. The next assertion
-- attempts to supersede it using an impossible organization-wide
-- Photographer scope. The entire failed reissue statement must roll
-- back, including its attempted revocation of this original invitation.
SET LOCAL ROLE authenticated;

CREATE TEMP TABLE lsha_invite_atomic_baseline
ON COMMIT DROP
AS
SELECT *
FROM public.create_organization_invitation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'migration-a-invitation-atomicity@example.com',
  'Migration A Atomicity Invitee',
  ARRAY[]::text[],
  336
);


-- 49
SELECT throws_ok(
  $$
    SELECT *
    FROM public.create_organization_invitation(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'migration-a-invitation-atomicity@example.com',
      'Migration A Atomicity Invitee',
      ARRAY['photographer']::text[],
      336
    )
  $$,
  '42501',
  'invitation role scope rejected: role photographer does not permit organization-wide access',
  'unscoped Photographer invitation is rejected by the canonical role-scope constitution'
);

RESET ROLE;


-- 50
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.organization_invitations invitation
    WHERE invitation.id = (
      SELECT invitation_id
      FROM lsha_invite_atomic_baseline
    )
      AND invitation.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND invitation.email =
          'migration-a-invitation-atomicity@example.com'
      AND invitation.status =
          'pending'::public.organization_invitation_status
      AND invitation.revoked_at IS NULL
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.organization_invitations invitation
    WHERE invitation.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND invitation.email =
          'migration-a-invitation-atomicity@example.com'
      AND invitation.status =
          'pending'::public.organization_invitation_status
  ) = 1::bigint
  AND NOT EXISTS (
    SELECT 1
    FROM public.organization_invitation_roles invitation_role
    WHERE invitation_role.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND invitation_role.invitation_id = (
        SELECT invitation_id
        FROM lsha_invite_atomic_baseline
      )
  ),
  'failed role-bearing reissue rolls back atomically and preserves the original role-less pending invitation'
);


-- The current public invitation API writes branch_id = NULL. A role
-- that constitutionally permits organization-wide scope must therefore
-- remain usable through this backward-compatible API.
SET LOCAL ROLE authenticated;

CREATE TEMP TABLE lsha_sales_head_invite
ON COMMIT DROP
AS
SELECT *
FROM public.create_organization_invitation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'migration-a-sales-head-invite@example.com',
  'Migration A Brand Sales Head Invitee',
  ARRAY['sales_head']::text[],
  336
);

RESET ROLE;


-- 51
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.organization_invitation_roles invitation_role
    JOIN public.roles role
      ON role.id =
         invitation_role.role_id
    WHERE invitation_role.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND invitation_role.invitation_id = (
        SELECT invitation_id
        FROM lsha_sales_head_invite
      )
      AND role.key =
          'sales_head'
      AND invitation_role.branch_id IS NULL
  ) = 1::bigint
  AND EXISTS (
    SELECT 1
    FROM public.organization_invitations invitation
    WHERE invitation.id = (
      SELECT invitation_id
      FROM lsha_sales_head_invite
    )
      AND invitation.status =
          'pending'::public.organization_invitation_status
  ),
  'unscoped invitation accepts organization-wide Brand Sales Head scope'
);


-- Create another valid role-less invitation through the public API.
-- The owner-context insertion below deliberately exercises the table
-- invariant itself, not an exposed client mutation surface.
SET LOCAL ROLE authenticated;

CREATE TEMP TABLE lsha_branch_role_invite
ON COMMIT DROP
AS
SELECT *
FROM public.create_organization_invitation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'migration-a-branch-role-invite@example.com',
  'Migration A Branch Role Invitee',
  ARRAY[]::text[],
  336
);

RESET ROLE;


INSERT INTO public.organization_invitation_roles (
  organization_id,
  invitation_id,
  role_id,
  branch_id,
  assigned_by
)
SELECT
  ctx.organization_id,
  invite.invitation_id,
  role.id,
  ctx.coimbatore_id,
  ctx.founder_member_id
FROM lsha_branch_role_invite invite
CROSS JOIN pg_temp.lsha_ctx ctx
CROSS JOIN public.roles role
WHERE role.key =
      'photographer';


-- 52
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.organization_invitation_roles invitation_role
    JOIN public.roles role
      ON role.id =
         invitation_role.role_id
    CROSS JOIN pg_temp.lsha_ctx ctx
    WHERE invitation_role.organization_id =
          ctx.organization_id
      AND invitation_role.invitation_id = (
        SELECT invitation_id
        FROM lsha_branch_role_invite
      )
      AND role.key =
          'photographer'
      AND invitation_role.branch_id =
          ctx.coimbatore_id
  ),
  1::bigint,
  'explicit active Coimbatore scope is valid for a Photographer invitation role'
);


-- 53
SELECT throws_ok(
  $$
    INSERT INTO public.organization_invitation_roles (
      organization_id,
      invitation_id,
      role_id,
      branch_id,
      assigned_by
    )
    SELECT
      ctx.organization_id,
      invite.invitation_id,
      role.id,
      ctx.coimbatore_id,
      ctx.founder_member_id
    FROM lsha_branch_role_invite invite
    CROSS JOIN pg_temp.lsha_ctx ctx
    CROSS JOIN public.roles role
    WHERE role.key =
          'founder'
  $$,
  '22023',
  'Founder invitation roles must be organization-wide',
  'Founder cannot be pre-authorized with branch-scoped invitation authority'
);


-- The sales_head invitation already contains an organization-wide
-- role row. Adding a branch-scoped row for the same invitation/role
-- must fail the same XOR constitution used by live member grants.
-- 54
SELECT throws_ok(
  $$
    INSERT INTO public.organization_invitation_roles (
      organization_id,
      invitation_id,
      role_id,
      branch_id,
      assigned_by
    )
    SELECT
      ctx.organization_id,
      invite.invitation_id,
      role.id,
      ctx.coimbatore_id,
      ctx.founder_member_id
    FROM lsha_sales_head_invite invite
    CROSS JOIN pg_temp.lsha_ctx ctx
    CROSS JOIN public.roles role
    WHERE role.key =
          'sales_head'
  $$,
  '42501',
  'invitation role scope rejected: Brand Sales Head cannot hold branch-scoped and organization-wide invitation roles simultaneously',
  'Brand Sales Head invitation cannot mix organization-wide and branch-scoped authority'
);


-- =====================================================================
-- Part 10 — Final constitutional integrity
-- =====================================================================

-- 55
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.organization_brand_owners bo
    JOIN public.organization_members m
      ON m.id = bo.organization_member_id
     AND m.organization_id =
         bo.organization_id
    JOIN public.member_role_grants g
      ON g.organization_id =
         bo.organization_id
     AND g.organization_member_id =
         bo.organization_member_id
    JOIN public.roles r
      ON r.id = g.role_id
    WHERE bo.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND m.status = 'active'::public.member_status
      AND r.key = 'founder'
      AND g.branch_id IS NULL
      AND g.revoked_at IS NULL
  ) = 1::bigint,
  'negative probes leave canonical Brand Owner constitution intact'
);


SELECT set_config(
  'request.jwt.claim.sub',
  'a9000000-0000-4000-8000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 56
SELECT is(
  (
    SELECT string_agg(branch_code, ',' ORDER BY branch_code)
    FROM public.accessible_branch_catalogue(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    )
  ),
  'bengaluru-jp-nagar,bengaluru-mahadevapura,coimbatore,erode',
  'Founder still sees all four canonical branches after all behavioral probes'
);

RESET ROLE;




-- =====================================================================
-- Part 11 — Amendment 13A branch-scope compatibility contract
--
-- Amendment 13A deliberately distinguishes:
--
--   * organization-wide authority:
--       has_permission(..., NULL)
--
--   * a permission held through at least one live authorized scope:
--       has_permission_in_any_live_scope(...)
--
-- The compatibility layer restores only deliberately shared resources
-- and constrained Team operations. It must not convert a branch grant
-- into general organization-wide authority.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 11.1 Branch-scoped Team fixtures
--
-- Studio Manager:
--   Coimbatore only
--
-- Mixed operational member:
--   Assistant     -> Coimbatore
--   Photographer  -> Erode
--
-- Erode-only operational member:
--   Assistant     -> Erode
-- ---------------------------------------------------------------------

INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at
)
VALUES
(
  'a9200000-0000-4000-8000-000000000021',
  'migration-a-13a-manager@example.com',
  now()
),
(
  'a9200000-0000-4000-8000-000000000022',
  'migration-a-13a-mixed@example.com',
  now()
),
(
  'a9200000-0000-4000-8000-000000000023',
  'migration-a-13a-erode-only@example.com',
  now()
);


INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  email,
  joined_at
)
VALUES
(
  'a9300000-0000-4000-8000-000000000021',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a9200000-0000-4000-8000-000000000021',
  'active',
  'Migration A Branch Studio Manager',
  'migration-a-13a-manager@example.com',
  now()
),
(
  'a9300000-0000-4000-8000-000000000022',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a9200000-0000-4000-8000-000000000022',
  'active',
  'Migration A Mixed Branch Member',
  'migration-a-13a-mixed@example.com',
  now()
),
(
  'a9300000-0000-4000-8000-000000000023',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'a9200000-0000-4000-8000-000000000023',
  'active',
  'Migration A Erode Only Member',
  'migration-a-13a-erode-only@example.com',
  now()
);


INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id,
  granted_by
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role_row.id,
  branch_row.id,
  ctx.founder_member_id

FROM (
  VALUES
    (
      'a9300000-0000-4000-8000-000000000021'::uuid,
      'studio_manager'::text,
      'coimbatore'::text
    ),
    (
      'a9300000-0000-4000-8000-000000000022'::uuid,
      'assistant'::text,
      'coimbatore'::text
    ),
    (
      'a9300000-0000-4000-8000-000000000022'::uuid,
      'photographer'::text,
      'erode'::text
    ),
    (
      'a9300000-0000-4000-8000-000000000023'::uuid,
      'assistant'::text,
      'erode'::text
    )
) AS fixture(
  member_id,
  role_key,
  branch_code
)

JOIN public.roles role_row
  ON role_row.key =
     fixture.role_key

JOIN public.branches branch_row
  ON branch_row.organization_id =
     '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
 AND branch_row.code =
     fixture.branch_code

CROSS JOIN pg_temp.lsha_ctx ctx;


SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;


-- ---------------------------------------------------------------------
-- 11.2 Founder control invitation
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  (
    SELECT founder_user_id::text
    FROM pg_temp.lsha_ctx
  ),
  true
);

SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub',
    (
      SELECT founder_user_id::text
      FROM pg_temp.lsha_ctx
    ),
    'role',
    'authenticated'
  )::text,
  true
);

SET LOCAL ROLE authenticated;

CREATE TEMP TABLE lsha_13a_founder_invite
ON COMMIT DROP
AS
SELECT *
FROM public.create_organization_invitation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'migration-a-13a-founder-control@example.com',
  'Migration A Founder Control Invite',
  ARRAY[]::text[],
  336
);

RESET ROLE;


-- ---------------------------------------------------------------------
-- 11.3 Branch-scoped Studio Manager context
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  'a9200000-0000-4000-8000-000000000021',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"a9200000-0000-4000-8000-000000000021","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;


-- 57
SELECT ok(
  public.has_permission_in_any_live_scope(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'org.read'
  )
  AND NOT public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'org.read',
    NULL
  ),
  'branch-scoped Studio Manager has org.read in a live branch without acquiring organization-wide authority'
);


-- 58
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.organizations organization_row
    WHERE organization_row.id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
  ),
  1::bigint,
  'branch-scoped org.read can consume deliberately organization-shared organization identity'
);


-- 59
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_access_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory
    WHERE directory.email =
          'littleshotsbyhema@gmail.com'
      AND directory.organization_wide = true
      AND directory.assigned_role_keys @>
          ARRAY['founder']::text[]
  ),
  1::bigint,
  'branch-scoped Team reader can see the organization-wide Founder'
);


-- 60
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_access_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory
    WHERE directory.member_id =
      'a9300000-0000-4000-8000-000000000022'::uuid
  ),
  1::bigint,
  'branch-scoped Team reader can see a member intersecting the authorized branch'
);


-- 61
SELECT ok(
  (
    SELECT
      directory.assigned_role_keys =
        ARRAY['assistant']::text[]
      AND directory.assigned_branch_names =
        ARRAY['Coimbatore']::text[]
      AND directory.organization_wide = false

    FROM public.team_access_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory

    WHERE directory.member_id =
      'a9300000-0000-4000-8000-000000000022'::uuid
  ),
  'branch-scoped Team projection does not leak the same member Erode role or Erode branch assignment'
);


-- 62
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_access_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory
    WHERE directory.member_id =
      'a9300000-0000-4000-8000-000000000023'::uuid
  ),
  0::bigint,
  'branch-scoped Team reader cannot see a member scoped only to another branch'
);


CREATE TEMP TABLE lsha_13a_manager_invite
ON COMMIT DROP
AS
SELECT *
FROM public.create_organization_invitation(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'migration-a-13a-manager-invite@example.com',
  'Migration A Manager Invite',
  ARRAY[]::text[],
  336
);


-- 63
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(
        cardinality(role_keys) = 0
      )
    FROM lsha_13a_manager_invite
  ),
  'branch-scoped Studio Manager can create a role-less invitation'
);


-- 64
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_invitation_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory
    WHERE directory.invitation_id = (
      SELECT invitation_id
      FROM lsha_13a_manager_invite
    )
  ),
  1::bigint,
  'branch-scoped Studio Manager invitation directory contains its own invitation'
);


-- 65
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_invitation_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory
    WHERE directory.invitation_id = (
      SELECT invitation_id
      FROM lsha_13a_founder_invite
    )
  ),
  0::bigint,
  'branch-scoped Studio Manager invitation directory hides invitations created by another actor'
);


-- 66
SELECT throws_ok(
  $$
    SELECT *
    FROM public.create_organization_invitation(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'migration-a-13a-founder-control@example.com',
      'Attempted Manager Supersession',
      ARRAY[]::text[],
      336
    )
  $$,
  '42501',
  'create_organization_invitation: branch-scoped actors cannot supersede invitations created by another actor',
  'branch-scoped Studio Manager cannot supersede a Founder-created pending invitation'
);


-- 67
SELECT throws_ok(
  $$
    SELECT *
    FROM public.create_organization_invitation(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      'migration-a-13a-manager-role-denied@example.com',
      'Manager Role Denied',
      ARRAY['photographer']::text[],
      336
    )
  $$,
  '42501',
  'create_organization_invitation: team.role.assign permission required to pre-authorize roles',
  'branch-scoped Studio Manager cannot pre-authorize invitation roles'
);


-- 68
SELECT throws_ok(
  $$
    SELECT public.revoke_organization_invitation(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
      (
        SELECT invitation_id
        FROM lsha_13a_founder_invite
      ),
      'Attempted cross-actor revocation'
    )
  $$,
  '42501',
  'revoke_organization_invitation: branch-scoped actors may revoke only invitations they created',
  'branch-scoped Studio Manager cannot revoke a Founder-created invitation'
);


-- 69
SELECT is(
  public.revoke_organization_invitation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    (
      SELECT invitation_id
      FROM lsha_13a_manager_invite
    ),
    'Manager cancelled own invitation'
  ),
  true,
  'branch-scoped Studio Manager can revoke its own invitation'
);


-- 70
SELECT is(
  (
    SELECT directory.invitation_status
    FROM public.team_invitation_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory
    WHERE directory.invitation_id = (
      SELECT invitation_id
      FROM lsha_13a_manager_invite
    )
  ),
  'revoked',
  'branch-scoped Studio Manager still sees its own revoked invitation lifecycle record'
);


RESET ROLE;


-- ---------------------------------------------------------------------
-- 11.4 Founder organization-wide compatibility
-- ---------------------------------------------------------------------

SELECT set_config(
  'request.jwt.claim.sub',
  (
    SELECT founder_user_id::text
    FROM pg_temp.lsha_ctx
  ),
  true
);

SELECT set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub',
    (
      SELECT founder_user_id::text
      FROM pg_temp.lsha_ctx
    ),
    'role',
    'authenticated'
  )::text,
  true
);

SET LOCAL ROLE authenticated;


-- 71
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.team_access_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory

    WHERE directory.member_id =
      'a9300000-0000-4000-8000-000000000023'::uuid

      AND directory.assigned_branch_names =
          ARRAY['Erode']::text[]
  )
  AND EXISTS (
    SELECT 1
    FROM public.team_access_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory

    WHERE directory.member_id =
      'a9300000-0000-4000-8000-000000000022'::uuid

      AND directory.assigned_role_keys @>
          ARRAY[
            'assistant',
            'photographer'
          ]::text[]

      AND ARRAY[
            'assistant',
            'photographer'
          ]::text[] @>
          directory.assigned_role_keys

      AND directory.assigned_branch_names @>
          ARRAY[
            'Coimbatore',
            'Erode'
          ]::text[]

      AND ARRAY[
            'Coimbatore',
            'Erode'
          ]::text[] @>
          directory.assigned_branch_names
  ),
  'organization-wide Founder Team directory retains complete cross-branch visibility'
);


-- 72
SELECT is(
  (
    SELECT count(*)::bigint

    FROM public.team_invitation_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    ) directory

    WHERE directory.invitation_id IN (
      SELECT invitation_id
      FROM lsha_13a_founder_invite

      UNION ALL

      SELECT invitation_id
      FROM lsha_13a_manager_invite
    )
  ),
  2::bigint,
  'organization-wide Founder invitation directory retains visibility over Founder and branch-scoped Manager invitation lifecycles'
);


RESET ROLE;



-- =====================================================================
-- Part 12 — Codex review remediation invariants
-- =====================================================================

-- 73
SELECT ok(
  pg_get_functiondef(
    'public.lsh_member_role_scope_guard()'::regprocedure
  ) ILIKE '%organization_members%'
  AND
  pg_get_functiondef(
    'public.lsh_member_role_scope_guard()'::regprocedure
  ) ILIKE '%FOR UPDATE%',
  'live role-scope guard serializes same-member mutations before Sales Head XOR evaluation'
);


-- 74
SELECT ok(
  pg_get_functiondef(
    'public.lsh_organization_invitation_roles_guard()'::regprocedure
  ) ILIKE '%organization_invitations%'
  AND
  pg_get_functiondef(
    'public.lsh_organization_invitation_roles_guard()'::regprocedure
  ) ILIKE '%FOR UPDATE%',
  'invitation role-scope guard serializes same-invitation mutations before Sales Head XOR evaluation'
);


-- 75
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.organizations o
    WHERE o.status = 'active'::public.organization_status
      AND o.deleted_at IS NULL
      AND (
        SELECT count(*)::bigint
        FROM public.organization_brand_owners owner
        WHERE owner.organization_id = o.id
      ) <> 1
  ),
  0::bigint,
  'every active non-deleted organization has exactly one canonical Brand Owner'
);


-- 76
SELECT ok(
  pg_get_functiondef(
    'public.create_organization_invitation(uuid,text,text,text[],integer)'::regprocedure
  ) ILIKE '%i.expires_at > now()%'
  AND
  pg_get_functiondef(
    'public.create_organization_invitation(uuid,text,text,text[],integer)'::regprocedure
  ) ILIKE '%i.expires_at <= now()%',

  'invitation reissue distinguishes live pending invitations from expired stale credentials'
);


SELECT * FROM finish();

ROLLBACK;
