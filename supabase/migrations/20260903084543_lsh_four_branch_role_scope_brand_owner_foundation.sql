-- =====================================================================
-- Little Shots by Hema — Memory Keeper OS
-- Four-Branch Role Scope & Brand Owner Foundation
--
-- Migration A
--
-- Governing authority:
--   Founder / Brand Owner / Studio Head
--       -> Brand Sales Head
--           -> Sales Team Member
--
-- Scope:
--   * establish four canonical LSH branches;
--   * preserve `sales` role key and relabel it Sales Team Member;
--   * add `sales_head` as Brand Sales Head;
--   * establish Founder / Brand Owner / Studio Head as ultimate authority;
--   * add bounded Sales-management permissions;
--   * create database-authoritative role-scope policy;
--   * prevent new invalid organization-wide operational grants;
--   * establish immutable Brand Owner identity by member ID;
--   * preserve/extend Founder bootstrap and Founder coverage;
--   * expose safe organization/branch shell read models.
--
-- Explicitly out of scope:
--   * scoped invitation contract;
--   * lead assignment/reassignment RPCs;
--   * Sales-team administration RPCs;
--   * Production staff reconciliation;
--   * revoking existing legacy grants;
--   * application/UI changes.
-- =====================================================================

BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '180s';


-- =====================================================================
-- 1. Preconditions
-- =====================================================================

DO $preconditions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.organization_settings') IS NULL
     OR to_regclass('public.branches') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.member_role_grants') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL THEN
    RAISE EXCEPTION
      'Migration A precondition failed: canonical organization/access-control substrate is incomplete';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_branch_scope(uuid,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.lsh_assert_founder_coverage(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.lsh_bootstrap_canonical_founder(uuid,text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Migration A precondition failed: canonical authorization/bootstrap functions are incomplete';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organizations o
    WHERE o.id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND o.slug = 'little-shots-by-hema'
      AND o.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION
      'Migration A precondition failed: canonical Little Shots by Hema organization is missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles r
  WHERE r.key IN ('founder', 'sales');

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Migration A precondition failed: Founder/Sales role foundation is incomplete';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.roles r
    WHERE r.key = 'sales_head'
  ) THEN
    RAISE EXCEPTION
      'Migration A precondition failed: sales_head already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions p
    WHERE p.key IN (
      'lead.assign',
      'lead.branch.reassign',
      'sales.team.read',
      'sales.team.invite',
      'sales.team.scope.assign'
    )
  ) THEN
    RAISE EXCEPTION
      'Migration A precondition failed: one or more new Sales hierarchy permissions already exist';
  END IF;

  IF to_regclass('public.role_scope_policies') IS NOT NULL
     OR to_regclass('public.organization_brand_owners') IS NOT NULL THEN
    RAISE EXCEPTION
      'Migration A precondition failed: new scope/ownership foundation already exists';
  END IF;

  IF to_regprocedure(
       'public.organization_shell_identity(uuid)'
     ) IS NOT NULL
     OR to_regprocedure(
       'public.accessible_branch_catalogue(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Migration A precondition failed: shell read models already exist';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.branches b
    WHERE b.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND b.deleted_at IS NULL
      AND b.code IN (
        'coimbatore',
        'erode',
        'bengaluru-mahadevapura',
        'bengaluru-jp-nagar'
      )
  ) THEN
    RAISE EXCEPTION
      'Migration A precondition failed: one or more canonical branch codes already exist';
  END IF;
END
$preconditions$;


-- =====================================================================
-- 2. Four canonical LSH branches
-- =====================================================================

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  city,
  state_region,
  country_code,
  timezone
)
VALUES
(
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'Coimbatore',
  'coimbatore',
  'active'::public.branch_status,
  'Coimbatore',
  'Tamil Nadu',
  'IN',
  'Asia/Kolkata'
),
(
  'c5bf4f0a-d9c2-4a54-9dd6-5c0f3200e2ce'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'Erode',
  'erode',
  'active'::public.branch_status,
  'Erode',
  'Tamil Nadu',
  'IN',
  'Asia/Kolkata'
),
(
  '8c15f39c-bfa5-4c34-9768-48f7ef5fe5fa'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'Bengaluru — Mahadevapura',
  'bengaluru-mahadevapura',
  'active'::public.branch_status,
  'Bengaluru',
  'Karnataka',
  'IN',
  'Asia/Kolkata'
),
(
  '7c7f28bb-e308-47f1-86f3-87d963cd63e8'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'Bengaluru — JP Nagar',
  'bengaluru-jp-nagar',
  'active'::public.branch_status,
  'Bengaluru',
  'Karnataka',
  'IN',
  'Asia/Kolkata'
);


-- =====================================================================
-- 3. Role catalogue evolution
-- =====================================================================

UPDATE public.roles
SET
  label = 'Founder / Brand Owner / Studio Head',
  description =
    'Brand Owner and ultimate authority across the Little Shots by Hema organization.'
WHERE key = 'founder';

UPDATE public.roles
SET
  label = 'Sales Team Member',
  description =
    'Executes inquiry, proposal and conversion work within explicitly assigned branch scopes.'
WHERE key = 'sales';

INSERT INTO public.roles (
  key,
  label,
  description,
  sort_order,
  is_system_role
)
VALUES (
  'sales_head',
  'Brand Sales Head',
  'Leads Sales operations and Sales Team authority within organization-wide or explicitly assigned branch scopes.',
  35,
  true
);


-- =====================================================================
-- 4. Sales hierarchy permissions
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES
(
  'lead.assign',
  'leads',
  'Assign Sales lead ownership',
  'Assign or reassign a lead to an eligible Sales Team Member or Brand Sales Head.',
  true
),
(
  'lead.branch.reassign',
  'leads',
  'Reassign lead branch',
  'Move an inquiry between authorized LSH branches.',
  true
),
(
  'sales.team.read',
  'sales',
  'View Sales team',
  'Read Sales-team membership, scope and workload within authorized Sales scope.',
  false
),
(
  'sales.team.invite',
  'sales',
  'Invite Sales Team Members',
  'Create Sales Team Member invitations within the Brand Sales Head authorized scope.',
  true
),
(
  'sales.team.scope.assign',
  'sales',
  'Manage Sales Team branch scope',
  'Grant or revoke Sales Team Member branch access within the actor authorized Sales scope.',
  true
);


-- Founder is constitutionally entitled to every currently-defined
-- application permission. This also repairs any historical omission.
INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  founder.id,
  permission.id
FROM public.roles founder
CROSS JOIN public.permissions permission
WHERE founder.key = 'founder'
ON CONFLICT (role_id, permission_id) DO NOTHING;


-- Brand Sales Head inherits the current operational Sales capability
-- set, then receives the bounded Sales-management permissions.
INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  sales_head.id,
  sales_mapping.permission_id
FROM public.roles sales_head
JOIN public.roles sales
  ON sales.key = 'sales'
JOIN public.role_permissions sales_mapping
  ON sales_mapping.role_id = sales.id
WHERE sales_head.key = 'sales_head'
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  sales_head.id,
  permission.id
FROM public.roles sales_head
CROSS JOIN public.permissions permission
WHERE sales_head.key = 'sales_head'
  AND permission.key IN (
    'lead.assign',
    'lead.branch.reassign',
    'sales.team.read',
    'sales.team.invite',
    'sales.team.scope.assign'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;


-- =====================================================================
-- 5. Database-authoritative role-scope constitution
-- =====================================================================

CREATE TABLE public.role_scope_policies (
  role_id                    uuid PRIMARY KEY,
  organization_wide_allowed boolean NOT NULL,
  branch_scoped_allowed     boolean NOT NULL,
  created_at                 timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT role_scope_policies_role_fkey
    FOREIGN KEY (role_id)
    REFERENCES public.roles (id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT role_scope_policies_at_least_one_scope_chk
    CHECK (
      organization_wide_allowed
      OR branch_scoped_allowed
    )
);

INSERT INTO public.role_scope_policies (
  role_id,
  organization_wide_allowed,
  branch_scoped_allowed
)
SELECT
  r.id,

  CASE
    WHEN r.key IN ('founder', 'sales_head')
      THEN true
    ELSE false
  END,

  CASE
    WHEN r.key = 'founder'
      THEN false
    ELSE true
  END

FROM public.roles r;


ALTER TABLE public.role_scope_policies
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.role_scope_policies
  FORCE ROW LEVEL SECURITY;

CREATE POLICY role_scope_policies_deny_all_authenticated
ON public.role_scope_policies
FOR ALL
TO authenticated
USING (false)
WITH CHECK (false);

REVOKE ALL
ON TABLE public.role_scope_policies
FROM PUBLIC, anon, authenticated;

GRANT ALL
ON TABLE public.role_scope_policies
TO service_role;


COMMENT ON TABLE public.role_scope_policies IS
  'Database-authoritative scope constitution. Founder is organization-wide only; Brand Sales Head may be organization-wide or branch-scoped; operational roles are branch-scoped by default.';


-- =====================================================================
-- 6. Central live role-scope guard
--
-- Legacy invalid live grants are not rewritten by Migration A.
-- The guard applies to new/resurrected live grants.
-- Revocation of a legacy invalid grant remains allowed.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_member_role_scope_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_role_key text;
  v_orgwide_allowed boolean;
  v_branch_allowed boolean;
BEGIN
  -- Always permit a transition into revoked history.
  -- Reconciliation must be able to revoke legacy invalid grants.
  IF NEW.revoked_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Serialize live role-scope mutations for the same organization
  -- member. This closes the cross-transaction race where concurrent
  -- organization-wide and branch-scoped sales_head grants could both
  -- observe no conflicting committed row.
  --
  -- The organization member row is the stable lock identity shared by
  -- all role grants for that member. The row lock is transaction-scoped.
  PERFORM 1
  FROM public.organization_members member_lock
  WHERE member_lock.id =
        NEW.organization_member_id
    AND member_lock.organization_id =
        NEW.organization_id
  FOR UPDATE;

  SELECT
    r.key,
    policy.organization_wide_allowed,
    policy.branch_scoped_allowed
  INTO
    v_role_key,
    v_orgwide_allowed,
    v_branch_allowed
  FROM public.roles r
  JOIN public.role_scope_policies policy
    ON policy.role_id = r.id
  WHERE r.id = NEW.role_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'member role scope rejected: role has no canonical scope policy'
      USING ERRCODE = '22023';
  END IF;

  IF NEW.branch_id IS NULL
     AND NOT v_orgwide_allowed THEN
    RAISE EXCEPTION
      'member role scope rejected: role % does not permit organization-wide access',
      v_role_key
      USING ERRCODE = '42501';
  END IF;

  IF NEW.branch_id IS NOT NULL
     AND NOT v_branch_allowed THEN
    RAISE EXCEPTION
      'member role scope rejected: role % does not permit branch-scoped access',
      v_role_key
      USING ERRCODE = '42501';
  END IF;

  IF NEW.branch_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.branches b
       WHERE b.id = NEW.branch_id
         AND b.organization_id = NEW.organization_id
         AND b.status = 'active'::public.branch_status
         AND b.deleted_at IS NULL
     ) THEN
    RAISE EXCEPTION
      'member role scope rejected: branch must be active'
      USING ERRCODE = '22023';
  END IF;

  -- Brand Sales Head is organization-wide XOR selected branches.
  -- A live organization-wide sales_head grant and live branch-scoped
  -- sales_head grants may never coexist for the same member.
  IF v_role_key = 'sales_head' THEN

    IF NEW.branch_id IS NULL THEN
      IF EXISTS (
        SELECT 1
        FROM public.member_role_grants g
        WHERE g.organization_id = NEW.organization_id
          AND g.organization_member_id =
              NEW.organization_member_id
          AND g.role_id = NEW.role_id
          AND g.revoked_at IS NULL
          AND g.branch_id IS NOT NULL
          AND g.id <> NEW.id
      ) THEN
        RAISE EXCEPTION
          'member role scope rejected: Brand Sales Head cannot hold organization-wide and branch-scoped grants simultaneously'
          USING ERRCODE = '42501';
      END IF;

    ELSE
      IF EXISTS (
        SELECT 1
        FROM public.member_role_grants g
        WHERE g.organization_id = NEW.organization_id
          AND g.organization_member_id =
              NEW.organization_member_id
          AND g.role_id = NEW.role_id
          AND g.revoked_at IS NULL
          AND g.branch_id IS NULL
          AND g.id <> NEW.id
      ) THEN
        RAISE EXCEPTION
          'member role scope rejected: Brand Sales Head cannot hold branch-scoped and organization-wide grants simultaneously'
          USING ERRCODE = '42501';
      END IF;
    END IF;

  END IF;

  RETURN NEW;
END
$function$;

CREATE TRIGGER member_role_grants_15_role_scope_guard
BEFORE INSERT OR UPDATE
ON public.member_role_grants
FOR EACH ROW
EXECUTE FUNCTION public.lsh_member_role_scope_guard();

REVOKE ALL
ON FUNCTION public.lsh_member_role_scope_guard()
FROM PUBLIC, anon, authenticated;


-- =====================================================================
-- 6A. Invitation role-scope constitution
--
-- organization_invitation_roles is the authoritative pre-acceptance
-- representation of role scope. It must obey the same role-scope
-- constitution as live member_role_grants.
--
-- The existing create_organization_invitation(...) API is intentionally
-- unscoped: it writes branch_id = NULL. Therefore it may only
-- pre-authorize roles whose canonical policy permits organization-wide
-- access. Branch-scoped operational roles require an explicitly scoped
-- invitation path or a post-acceptance branch-scoped grant.
--
-- The trigger remains the authoritative invariant so future scoped
-- invitation APIs cannot bypass the constitution.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_organization_invitation_roles_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_role_key text;
  v_invitation_status public.organization_invitation_status;
  v_orgwide_allowed boolean;
  v_branch_allowed boolean;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION
      'organization invitation role assignments are immutable'
      USING ERRCODE = '42501';
  END IF;

  -- Lock the parent invitation so concurrent role-scope inserts for
  -- the same invitation serialize before evaluating the Sales Head
  -- organization-wide XOR branch-scoped invariant.
  SELECT i.status
  INTO v_invitation_status
  FROM public.organization_invitations i
  WHERE i.id = NEW.invitation_id
    AND i.organization_id = NEW.organization_id
  FOR UPDATE;

  IF v_invitation_status IS NULL
     OR v_invitation_status <>
        'pending'::public.organization_invitation_status THEN
    RAISE EXCEPTION
      'roles may only be assigned to pending invitations'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    r.key,
    policy.organization_wide_allowed,
    policy.branch_scoped_allowed
  INTO
    v_role_key,
    v_orgwide_allowed,
    v_branch_allowed
  FROM public.roles r
  JOIN public.role_scope_policies policy
    ON policy.role_id = r.id
  WHERE r.id = NEW.role_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'invitation role scope rejected: role has no canonical scope policy'
      USING ERRCODE = '22023';
  END IF;

  -- Preserve the pre-existing explicit Founder invariant and error.
  IF v_role_key = 'founder'
     AND NEW.branch_id IS NOT NULL THEN
    RAISE EXCEPTION
      'Founder invitation roles must be organization-wide'
      USING ERRCODE = '22023';
  END IF;

  IF NEW.branch_id IS NULL
     AND NOT v_orgwide_allowed THEN
    RAISE EXCEPTION
      'invitation role scope rejected: role % does not permit organization-wide access',
      v_role_key
      USING ERRCODE = '42501';
  END IF;

  IF NEW.branch_id IS NOT NULL
     AND NOT v_branch_allowed THEN
    RAISE EXCEPTION
      'invitation role scope rejected: role % does not permit branch-scoped access',
      v_role_key
      USING ERRCODE = '42501';
  END IF;

  IF NEW.branch_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.branches b
       WHERE b.id = NEW.branch_id
         AND b.organization_id = NEW.organization_id
         AND b.status = 'active'::public.branch_status
         AND b.deleted_at IS NULL
     ) THEN
    RAISE EXCEPTION
      'invitation branch scope must reference an active branch'
      USING ERRCODE = '22023';
  END IF;

  -- Brand Sales Head follows the same organization-wide XOR selected
  -- branches constitution before membership acceptance.
  IF v_role_key = 'sales_head' THEN

    IF NEW.branch_id IS NULL THEN

      IF EXISTS (
        SELECT 1
        FROM public.organization_invitation_roles existing
        WHERE existing.organization_id =
              NEW.organization_id
          AND existing.invitation_id =
              NEW.invitation_id
          AND existing.role_id =
              NEW.role_id
          AND existing.branch_id IS NOT NULL
      ) THEN
        RAISE EXCEPTION
          'invitation role scope rejected: Brand Sales Head cannot hold organization-wide and branch-scoped invitation roles simultaneously'
          USING ERRCODE = '42501';
      END IF;

    ELSE

      IF EXISTS (
        SELECT 1
        FROM public.organization_invitation_roles existing
        WHERE existing.organization_id =
              NEW.organization_id
          AND existing.invitation_id =
              NEW.invitation_id
          AND existing.role_id =
              NEW.role_id
          AND existing.branch_id IS NULL
      ) THEN
        RAISE EXCEPTION
          'invitation role scope rejected: Brand Sales Head cannot hold branch-scoped and organization-wide invitation roles simultaneously'
          USING ERRCODE = '42501';
      END IF;

    END IF;

  END IF;

  RETURN NEW;
END
$function$;

REVOKE ALL
ON FUNCTION public.lsh_organization_invitation_roles_guard()
FROM PUBLIC, anon, authenticated, service_role;


COMMENT ON FUNCTION public.lsh_organization_invitation_roles_guard() IS
  'Enforces immutable pending-invitation role assignments, canonical role-scope policy, active branch scope, Founder organization-wide scope, and Brand Sales Head organization-wide XOR branch-scoped invitation scope.';


-- =====================================================================
-- 7. Canonical Brand Owner identity
--
-- Authorization is anchored to immutable member identity, not email.
-- Exactly one Brand Owner row exists per organization.
-- =====================================================================

CREATE TABLE public.organization_brand_owners (
  organization_id        uuid PRIMARY KEY,
  organization_member_id uuid NOT NULL UNIQUE,
  established_at         timestamptz NOT NULL DEFAULT now(),
  established_by         uuid NOT NULL,

  CONSTRAINT organization_brand_owners_organization_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_brand_owners_member_fkey
    FOREIGN KEY (
      organization_member_id,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_brand_owners_established_by_fkey
    FOREIGN KEY (
      established_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

ALTER TABLE public.organization_brand_owners
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.organization_brand_owners
  FORCE ROW LEVEL SECURITY;

CREATE POLICY organization_brand_owners_deny_all_authenticated
ON public.organization_brand_owners
FOR ALL
TO authenticated
USING (false)
WITH CHECK (false);

REVOKE ALL
ON TABLE public.organization_brand_owners
FROM PUBLIC, anon, authenticated;

GRANT ALL
ON TABLE public.organization_brand_owners
TO service_role;


COMMENT ON TABLE public.organization_brand_owners IS
  'Canonical constitutional Brand Owner identity. Runtime authorization is anchored to organization_member_id, never to email text.';


-- Brand ownership is immutable through ordinary database operations.
CREATE OR REPLACE FUNCTION public.lsh_brand_owner_identity_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION
    'Brand Owner identity is immutable through ordinary operations'
    USING ERRCODE = '42501';
END
$function$;

CREATE TRIGGER organization_brand_owners_10_immutable_guard
BEFORE UPDATE OR DELETE
ON public.organization_brand_owners
FOR EACH ROW
EXECUTE FUNCTION public.lsh_brand_owner_identity_immutable_guard();

REVOKE ALL
ON FUNCTION public.lsh_brand_owner_identity_immutable_guard()
FROM PUBLIC, anon, authenticated;


-- Backfill every non-deleted organization from its single active,
-- organization-wide Founder candidate.
--
-- Active organizations must be constitutionally complete when Migration A
-- finishes. If an active organization has zero or multiple eligible Founder
-- candidates, ownership cannot be guessed safely, so migration aborts.
--
-- Suspended organizations with exactly one eligible Founder are also
-- backfilled. Suspended organizations without exactly one candidate remain
-- eligible for their controlled bootstrap/activation path later.
DO $brand_owner_backfill$
DECLARE
  v_org record;
  v_candidate_count integer;
  v_owner_member_id uuid;
BEGIN
  FOR v_org IN
    SELECT
      o.id,
      o.status
    FROM public.organizations o
    WHERE o.deleted_at IS NULL
    ORDER BY o.id
  LOOP

    SELECT count(*)
    INTO v_candidate_count
    FROM public.member_role_grants g

    JOIN public.organization_members m
      ON m.id = g.organization_member_id
     AND m.organization_id = g.organization_id

    JOIN public.roles r
      ON r.id = g.role_id

    WHERE g.organization_id = v_org.id
      AND g.revoked_at IS NULL
      AND g.branch_id IS NULL
      AND r.key = 'founder'
      AND m.status = 'active'::public.member_status
      AND m.exited_at IS NULL;


    IF v_org.status = 'active'::public.organization_status
       AND v_candidate_count <> 1 THEN
      RAISE EXCEPTION
        'Brand Owner backfill failed: active organization % requires exactly one active organization-wide Founder candidate, found %',
        v_org.id,
        v_candidate_count;
    END IF;


    IF v_candidate_count = 1 THEN

      SELECT m.id
      INTO v_owner_member_id
      FROM public.member_role_grants g

      JOIN public.organization_members m
        ON m.id = g.organization_member_id
       AND m.organization_id = g.organization_id

      JOIN public.roles r
        ON r.id = g.role_id

      WHERE g.organization_id = v_org.id
        AND g.revoked_at IS NULL
        AND g.branch_id IS NULL
        AND r.key = 'founder'
        AND m.status = 'active'::public.member_status
        AND m.exited_at IS NULL;


      INSERT INTO public.organization_brand_owners (
        organization_id,
        organization_member_id,
        established_by
      )
      VALUES (
        v_org.id,
        v_owner_member_id,
        v_owner_member_id
      );

    END IF;

  END LOOP;


  -- Migration-time constitutional assertion:
  -- every active, non-deleted organization must now have exactly one
  -- canonical Brand Owner row.
  IF EXISTS (
    SELECT 1
    FROM public.organizations o

    LEFT JOIN public.organization_brand_owners owner
      ON owner.organization_id = o.id

    WHERE o.status = 'active'::public.organization_status
      AND o.deleted_at IS NULL

    GROUP BY o.id
    HAVING count(owner.organization_id) <> 1
  ) THEN
    RAISE EXCEPTION
      'Brand Owner backfill failed: one or more active organizations lack exactly one canonical Brand Owner';
  END IF;
END
$brand_owner_backfill$;

-- =====================================================================
-- 8. Protect Brand Owner membership
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_brand_owner_member_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF EXISTS (
      SELECT 1
      FROM public.organization_brand_owners owner
      WHERE owner.organization_id = OLD.organization_id
        AND owner.organization_member_id = OLD.id
    ) THEN
      RAISE EXCEPTION
        'Brand Owner membership cannot be deleted'
        USING ERRCODE = '42501';
    END IF;

    RETURN OLD;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.organization_brand_owners owner
    WHERE owner.organization_id = OLD.organization_id
      AND owner.organization_member_id = OLD.id
  ) THEN

    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.status IS DISTINCT FROM
          'active'::public.member_status
       OR NEW.suspended_at IS NOT NULL
       OR NEW.suspended_by IS NOT NULL
       OR NEW.suspension_reason IS NOT NULL
       OR NEW.exited_at IS NOT NULL
       OR NEW.exited_by IS NOT NULL
       OR NEW.exit_reason IS NOT NULL THEN
      RAISE EXCEPTION
        'Brand Owner membership cannot be suspended, exited, revoked, moved or reassigned'
        USING ERRCODE = '42501';
    END IF;

  END IF;

  RETURN NEW;
END
$function$;

CREATE TRIGGER organization_members_10_brand_owner_guard
BEFORE UPDATE OR DELETE
ON public.organization_members
FOR EACH ROW
EXECUTE FUNCTION public.lsh_brand_owner_member_guard();

REVOKE ALL
ON FUNCTION public.lsh_brand_owner_member_guard()
FROM PUBLIC, anon, authenticated;


-- =====================================================================
-- 9. Protect Brand Owner Founder grant
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_brand_owner_founder_grant_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_founder_role_id uuid;
BEGIN
  SELECT r.id
  INTO v_founder_role_id
  FROM public.roles r
  WHERE r.key = 'founder';

  IF TG_OP = 'DELETE' THEN

    IF OLD.role_id = v_founder_role_id
       AND OLD.revoked_at IS NULL
       AND EXISTS (
         SELECT 1
         FROM public.organization_brand_owners owner
         WHERE owner.organization_id = OLD.organization_id
           AND owner.organization_member_id =
               OLD.organization_member_id
       ) THEN
      RAISE EXCEPTION
        'Brand Owner Founder authority cannot be deleted'
        USING ERRCODE = '42501';
    END IF;

    RETURN OLD;
  END IF;

  IF OLD.role_id = v_founder_role_id
     AND OLD.revoked_at IS NULL
     AND EXISTS (
       SELECT 1
       FROM public.organization_brand_owners owner
       WHERE owner.organization_id = OLD.organization_id
         AND owner.organization_member_id =
             OLD.organization_member_id
     ) THEN

    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.organization_member_id IS DISTINCT FROM
          OLD.organization_member_id
       OR NEW.role_id IS DISTINCT FROM OLD.role_id
       OR NEW.branch_id IS DISTINCT FROM OLD.branch_id
       OR NEW.revoked_at IS NOT NULL THEN
      RAISE EXCEPTION
        'Brand Owner Founder authority cannot be revoked, downgraded, moved or branch-scoped'
        USING ERRCODE = '42501';
    END IF;

  END IF;

  RETURN NEW;
END
$function$;

CREATE TRIGGER member_role_grants_10_brand_owner_guard
BEFORE UPDATE OR DELETE
ON public.member_role_grants
FOR EACH ROW
EXECUTE FUNCTION public.lsh_brand_owner_founder_grant_guard();

REVOKE ALL
ON FUNCTION public.lsh_brand_owner_founder_grant_guard()
FROM PUBLIC, anon, authenticated;


-- =====================================================================
-- 10. Strengthen Founder coverage:
--     active organization => active organization-wide Founder
--     + active Brand Owner holding organization-wide Founder authority
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_assert_founder_coverage(
  p_organization_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_status public.organization_status;
  v_deleted_at timestamptz;
  v_founder_count integer;
  v_brand_owner_coverage integer;
BEGIN
  SELECT
    o.status,
    o.deleted_at
  INTO
    v_status,
    v_deleted_at
  FROM public.organizations o
  WHERE o.id = p_organization_id;

  IF NOT FOUND
     OR v_status <> 'active'::public.organization_status
     OR v_deleted_at IS NOT NULL THEN
    RETURN;
  END IF;

  SELECT count(*)
  INTO v_founder_count
  FROM public.member_role_grants g
  JOIN public.organization_members m
    ON m.id = g.organization_member_id
   AND m.organization_id = g.organization_id
  JOIN public.roles r
    ON r.id = g.role_id
  WHERE g.organization_id = p_organization_id
    AND g.revoked_at IS NULL
    AND g.branch_id IS NULL
    AND r.key = 'founder'
    AND m.status = 'active'::public.member_status
    AND m.exited_at IS NULL;

  IF v_founder_count < 1 THEN
    RAISE EXCEPTION
      'Organization % would be left with zero active organization-wide Founders',
      p_organization_id;
  END IF;

  SELECT count(*)
  INTO v_brand_owner_coverage
  FROM public.organization_brand_owners owner
  JOIN public.organization_members m
    ON m.id = owner.organization_member_id
   AND m.organization_id = owner.organization_id
  JOIN public.member_role_grants g
    ON g.organization_id = owner.organization_id
   AND g.organization_member_id =
       owner.organization_member_id
   AND g.revoked_at IS NULL
   AND g.branch_id IS NULL
  JOIN public.roles r
    ON r.id = g.role_id
   AND r.key = 'founder'
  WHERE owner.organization_id = p_organization_id
    AND m.status = 'active'::public.member_status
    AND m.exited_at IS NULL;

  IF v_brand_owner_coverage <> 1 THEN
    RAISE EXCEPTION
      'Organization % must retain exactly one active Brand Owner with organization-wide Founder authority',
      p_organization_id;
  END IF;
END
$function$;

REVOKE ALL
ON FUNCTION public.lsh_assert_founder_coverage(uuid)
FROM PUBLIC, anon, authenticated;


-- =====================================================================
-- 11. Extend canonical Founder bootstrap to establish Brand Ownership
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_bootstrap_canonical_founder(
  p_user_id        uuid,
  p_expected_email text
)
RETURNS TABLE (
  organization_id uuid,
  member_id       uuid,
  grant_id        uuid,
  user_id         uuid,
  member_created  boolean,
  grant_created   boolean,
  activated       boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_organization_id constant uuid :=
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  v_auth_email       text;
  v_email_confirmed  timestamptz;
  v_org_status       public.organization_status;
  v_org_deleted_at   timestamptz;
  v_member_id        uuid;
  v_member_status    public.member_status;
  v_role_id          uuid;
  v_grant_id         uuid;
  v_member_created   boolean := false;
  v_grant_created    boolean := false;
  v_activated        boolean := false;
  v_existing_members integer;
  v_live_founders    integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap requires a non-null auth user ID';
  END IF;

  IF p_expected_email IS NULL
     OR btrim(p_expected_email) = '' THEN
    RAISE EXCEPTION
      'Founder bootstrap requires a non-blank expected email';
  END IF;

  SELECT
    u.email,
    u.email_confirmed_at
  INTO
    v_auth_email,
    v_email_confirmed
  FROM auth.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: auth user % does not exist',
      p_user_id;
  END IF;

  IF v_auth_email IS NULL
     OR lower(v_auth_email) <>
        lower(btrim(p_expected_email)) THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: authenticated email does not match expected Founder email';
  END IF;

  IF v_email_confirmed IS NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: Founder email confirmation is required';
  END IF;

  SELECT
    o.status,
    o.deleted_at
  INTO
    v_org_status,
    v_org_deleted_at
  FROM public.organizations o
  WHERE o.id = v_organization_id
    AND o.slug = 'little-shots-by-hema'
    AND o.display_name = 'Little Shots by Hema'
    AND o.legal_name = 'Little Shots by Hema'
    AND o.currency_code = 'INR'
    AND o.timezone = 'Asia/Kolkata'
    AND o.brand_prefix = 'LSH';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: canonical Little Shots by Hema organization is missing or invalid';
  END IF;

  IF v_org_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: canonical organization is soft-deleted';
  END IF;

  IF v_org_status NOT IN (
    'suspended'::public.organization_status,
    'active'::public.organization_status
  ) THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: organization status % cannot be bootstrapped',
      v_org_status;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_settings s
    WHERE s.organization_id = v_organization_id
  ) THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: canonical organization settings are missing';
  END IF;

  SELECT r.id
  INTO v_role_id
  FROM public.roles r
  WHERE r.key = 'founder'
    AND r.is_system_role = true;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: system Founder role is missing';
  END IF;

  SELECT
    m.id,
    m.status
  INTO
    v_member_id,
    v_member_status
  FROM public.organization_members m
  WHERE m.organization_id = v_organization_id
    AND m.user_id = p_user_id;

  IF v_member_id IS NULL THEN

    SELECT count(*)
    INTO v_existing_members
    FROM public.organization_members m
    WHERE m.organization_id = v_organization_id;

    IF v_existing_members <> 0 THEN
      RAISE EXCEPTION
        'Founder bootstrap failed: canonical organization already contains % member row(s)',
        v_existing_members;
    END IF;

    INSERT INTO public.organization_members (
      organization_id,
      user_id,
      status,
      email
    )
    VALUES (
      v_organization_id,
      p_user_id,
      'active'::public.member_status,
      lower(btrim(v_auth_email))
    )
    RETURNING id
    INTO v_member_id;

    v_member_created := true;

    UPDATE public.organization_members m
    SET
      created_by = v_member_id,
      updated_by = v_member_id
    WHERE m.id = v_member_id
      AND m.organization_id = v_organization_id;

  ELSE

    IF v_member_status <>
       'active'::public.member_status THEN
      RAISE EXCEPTION
        'Founder bootstrap failed: existing membership % has status %',
        v_member_id,
        v_member_status;
    END IF;

    UPDATE public.organization_members m
    SET
      email = lower(btrim(v_auth_email)),
      updated_by = v_member_id
    WHERE m.id = v_member_id
      AND m.organization_id = v_organization_id;

  END IF;

  SELECT g.id
  INTO v_grant_id
  FROM public.member_role_grants g
  WHERE g.organization_id = v_organization_id
    AND g.organization_member_id = v_member_id
    AND g.role_id = v_role_id
    AND g.branch_id IS NULL
    AND g.revoked_at IS NULL;

  IF v_grant_id IS NULL THEN

    SELECT count(*)
    INTO v_live_founders
    FROM public.member_role_grants g
    JOIN public.organization_members m
      ON m.id = g.organization_member_id
     AND m.organization_id = g.organization_id
    JOIN public.roles r
      ON r.id = g.role_id
    WHERE g.organization_id = v_organization_id
      AND g.revoked_at IS NULL
      AND g.branch_id IS NULL
      AND r.key = 'founder'
      AND m.status = 'active'::public.member_status;

    IF v_live_founders <> 0 THEN
      RAISE EXCEPTION
        'Founder bootstrap failed: canonical organization already has % active organization-wide Founder grant(s)',
        v_live_founders;
    END IF;

    INSERT INTO public.member_role_grants (
      organization_id,
      organization_member_id,
      role_id,
      branch_id,
      granted_by
    )
    VALUES (
      v_organization_id,
      v_member_id,
      v_role_id,
      NULL,
      v_member_id
    )
    RETURNING id
    INTO v_grant_id;

    v_grant_created := true;
  END IF;

  INSERT INTO public.organization_brand_owners (
    organization_id,
    organization_member_id,
    established_by
  )
  VALUES (
    v_organization_id,
    v_member_id,
    v_member_id
  )
  ON CONFLICT ON CONSTRAINT organization_brand_owners_pkey DO NOTHING;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_brand_owners owner
    WHERE owner.organization_id = v_organization_id
      AND owner.organization_member_id = v_member_id
  ) THEN
    RAISE EXCEPTION
      'Founder bootstrap failed: canonical Brand Owner belongs to another member';
  END IF;

  UPDATE public.organizations o
  SET
    status = 'active'::public.organization_status,
    created_by = COALESCE(o.created_by, v_member_id),
    updated_by = v_member_id
  WHERE o.id = v_organization_id
    AND (
      o.status IS DISTINCT FROM
        'active'::public.organization_status
      OR o.created_by IS NULL
      OR o.updated_by IS DISTINCT FROM v_member_id
    );

  v_activated := FOUND;

  UPDATE public.organization_settings s
  SET updated_by = v_member_id
  WHERE s.organization_id = v_organization_id
    AND s.updated_by IS DISTINCT FROM v_member_id;

  PERFORM public.lsh_assert_founder_coverage(
    v_organization_id
  );

  RETURN QUERY
  SELECT
    v_organization_id,
    v_member_id,
    v_grant_id,
    p_user_id,
    v_member_created,
    v_grant_created,
    v_activated;
END
$function$;

REVOKE ALL
ON FUNCTION public.lsh_bootstrap_canonical_founder(
  uuid,
  text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.lsh_bootstrap_canonical_founder(
  uuid,
  text
)
TO service_role;


-- =====================================================================
-- 12. Safe organization identity read model
--
-- Branch-only staff should not require a fake organization-wide role
-- grant merely to render trusted studio identity / application shell.
-- =====================================================================

CREATE FUNCTION public.organization_shell_identity(
  p_organization_id uuid
)
RETURNS TABLE (
  organization_id     uuid,
  display_name        text,
  slug                text,
  legal_name          text,
  currency_code       text,
  timezone            text,
  brand_prefix        text,
  locale              text,
  date_format         text,
  brand_primary_color text,
  brand_logo_url      text,
  philosophy_statement text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'organization_shell_identity: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    o.id,
    o.display_name,
    o.slug,
    o.legal_name,
    o.currency_code,
    o.timezone,
    o.brand_prefix,
    settings.locale,
    settings.date_format,
    settings.brand_primary_color,
    settings.brand_logo_url,
    settings.philosophy_statement
  FROM public.organizations o
  JOIN public.organization_settings settings
    ON settings.organization_id = o.id
  WHERE o.id = p_organization_id
    AND o.status = 'active'::public.organization_status
    AND o.deleted_at IS NULL;
END
$function$;

REVOKE ALL
ON FUNCTION public.organization_shell_identity(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.organization_shell_identity(uuid)
TO authenticated, service_role;


-- =====================================================================
-- 13. Safe accessible-branch read model
-- =====================================================================

CREATE FUNCTION public.accessible_branch_catalogue(
  p_organization_id uuid
)
RETURNS TABLE (
  branch_id          uuid,
  branch_name        text,
  branch_code        text,
  city               text,
  state_region       text,
  country_code       text,
  branch_timezone    text,
  phone              text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'accessible_branch_catalogue: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.name,
    b.code,
    b.city,
    b.state_region,
    b.country_code,
    COALESCE(b.timezone, o.timezone),
    b.phone
  FROM public.branches b
  JOIN public.organizations o
    ON o.id = b.organization_id
  WHERE b.organization_id = p_organization_id
    AND b.status = 'active'::public.branch_status
    AND b.deleted_at IS NULL
    AND public.has_branch_scope(
      p_organization_id,
      b.id
    )
  ORDER BY
    b.name,
    b.code,
    b.id;
END
$function$;

REVOKE ALL
ON FUNCTION public.accessible_branch_catalogue(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.accessible_branch_catalogue(uuid)
TO authenticated, service_role;



-- =====================================================================
-- 13A. Branch-scope compatibility for shared reads and Team access
--
-- Migration A makes operational roles branch-scoped by default.
-- Legacy organization-level surfaces must therefore distinguish:
--
--   * true organization-wide authority:
--       has_permission(..., NULL)
--
--   * permission held in at least one currently live authorized scope:
--       has_permission_in_any_live_scope(...)
--
-- The second concept is deliberately narrow. It MUST NOT replace
-- has_permission(..., NULL) for branch-owned customer or workflow data.
--
-- This section restores only:
--
--   1. genuinely organization-shared org.read resources;
--   2. branch-filtered Team directory visibility;
--   3. Studio Manager role-less invitation lifecycle constrained to
--      invitations created by that same branch-scoped actor.
--
-- Founder organization-wide behavior remains backward-compatible.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 13A.1 Permission exists in any currently live authorized scope
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.has_permission_in_any_live_scope(
  p_organization_id uuid,
  p_permission_key text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.member_role_grants g

    JOIN public.role_permissions rp
      ON rp.role_id = g.role_id

    JOIN public.permissions p
      ON p.id = rp.permission_id

    LEFT JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id = g.organization_id

    WHERE g.organization_id =
          p_organization_id

      AND g.organization_member_id =
          public.current_organization_member(
            p_organization_id
          )

      AND g.revoked_at IS NULL

      AND p.key =
          p_permission_key

      AND (
        g.branch_id IS NULL

        OR (
          b.id IS NOT NULL
          AND b.deleted_at IS NULL
          AND b.status =
              'active'::public.branch_status
        )
      )
  );
$function$;


REVOKE ALL
ON FUNCTION public.has_permission_in_any_live_scope(
  uuid,
  text
)
FROM PUBLIC, anon, authenticated;


GRANT EXECUTE
ON FUNCTION public.has_permission_in_any_live_scope(
  uuid,
  text
)
TO authenticated, service_role;


COMMENT ON FUNCTION public.has_permission_in_any_live_scope(
  uuid,
  text
) IS
  'Returns true when the current active organization member holds the requested permission through an organization-wide grant or at least one active non-deleted branch grant. This helper is only for deliberately organization-shared or actor-owned compatibility surfaces and must not replace branch-specific has_permission checks.';


-- ---------------------------------------------------------------------
-- 13A.2 Genuinely organization-shared org.read resources
--
-- These records have no branch ownership. A branch-scoped operational
-- actor with org.read may consume the common organization catalogue,
-- organization shell configuration, and canonical journey definitions
-- without acquiring organization-wide mutation authority.
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS
  organizations_read_authenticated
ON public.organizations;

CREATE POLICY
  organizations_read_authenticated
ON public.organizations
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  organization_settings_read_authenticated
ON public.organization_settings;

CREATE POLICY
  organization_settings_read_authenticated
ON public.organization_settings
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  booking_journey_stages_staff_read
ON public.booking_journey_stages;

CREATE POLICY
  booking_journey_stages_staff_read
ON public.booking_journey_stages
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  commercial_packages_staff_read
ON public.commercial_packages;

CREATE POLICY
  commercial_packages_staff_read
ON public.commercial_packages
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  commercial_package_versions_staff_read
ON public.commercial_package_versions;

CREATE POLICY
  commercial_package_versions_staff_read
ON public.commercial_package_versions
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  commercial_package_inclusions_staff_read
ON public.commercial_package_inclusions;

CREATE POLICY
  commercial_package_inclusions_staff_read
ON public.commercial_package_inclusions
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  commercial_addons_staff_read
ON public.commercial_addons;

CREATE POLICY
  commercial_addons_staff_read
ON public.commercial_addons
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  commercial_addon_versions_staff_read
ON public.commercial_addon_versions;

CREATE POLICY
  commercial_addon_versions_staff_read
ON public.commercial_addon_versions
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


DROP POLICY IF EXISTS
  commercial_operational_requirements_staff_read
ON public.commercial_operational_requirements;

CREATE POLICY
  commercial_operational_requirements_staff_read
ON public.commercial_operational_requirements
FOR SELECT
TO authenticated
USING (
  public.has_permission_in_any_live_scope(
    organization_id,
    'org.read'
  )
);


-- ---------------------------------------------------------------------
-- 13A.3 Branch-filtered canonical Team directory
--
-- Organization-wide team.read:
--   sees the complete canonical Team directory.
--
-- Branch-scoped team.read:
--   sees:
--     * members with an organization-wide live grant; and
--     * members sharing at least one branch on which the actor has
--       team.read.
--
-- Role and branch aggregates are filtered through the same visibility
-- boundary so inaccessible branch assignments are not leaked.
--
-- Members with no role scope are intentionally not exposed to a
-- branch-scoped reader because they have no branch intersection yet.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.team_access_directory(
  p_organization_id uuid
)
RETURNS TABLE (
  member_id uuid,
  member_status public.member_status,
  display_name text,
  email text,
  phone text,
  joined_at timestamptz,
  assigned_role_keys text[],
  assigned_role_labels text[],
  assigned_branch_names text[],
  organization_wide boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH actor AS (
    SELECT
      public.current_organization_member(
        p_organization_id
      ) AS member_id,

      public.has_permission(
        p_organization_id,
        'team.read',
        NULL
      ) AS organization_wide_read,

      public.has_permission_in_any_live_scope(
        p_organization_id,
        'team.read'
      ) AS any_live_scope_read
  )

  SELECT
    m.id,
    m.status,
    m.display_name,
    m.email,
    m.phone,
    m.joined_at,

    COALESCE(
      (
        SELECT array_agg(
          r.key
          ORDER BY r.sort_order, r.key
        )

        FROM public.member_role_grants g

        JOIN public.roles r
          ON r.id = g.role_id

        WHERE g.organization_id =
              m.organization_id

          AND g.organization_member_id =
              m.id

          AND g.revoked_at IS NULL

          AND (
            a.organization_wide_read

            OR g.branch_id IS NULL

            OR public.has_permission(
                 p_organization_id,
                 'team.read',
                 g.branch_id
               )
          )
      ),
      ARRAY[]::text[]
    ),

    COALESCE(
      (
        SELECT array_agg(
          r.label
          ORDER BY r.sort_order, r.key
        )

        FROM public.member_role_grants g

        JOIN public.roles r
          ON r.id = g.role_id

        WHERE g.organization_id =
              m.organization_id

          AND g.organization_member_id =
              m.id

          AND g.revoked_at IS NULL

          AND (
            a.organization_wide_read

            OR g.branch_id IS NULL

            OR public.has_permission(
                 p_organization_id,
                 'team.read',
                 g.branch_id
               )
          )
      ),
      ARRAY[]::text[]
    ),

    COALESCE(
      (
        SELECT array_agg(
          DISTINCT b.name
          ORDER BY b.name
        )

        FROM public.member_role_grants g

        JOIN public.branches b
          ON b.id = g.branch_id
         AND b.organization_id =
             g.organization_id
         AND b.deleted_at IS NULL
         AND b.status =
             'active'::public.branch_status

        WHERE g.organization_id =
              m.organization_id

          AND g.organization_member_id =
              m.id

          AND g.revoked_at IS NULL

          AND (
            a.organization_wide_read

            OR public.has_permission(
                 p_organization_id,
                 'team.read',
                 g.branch_id
               )
          )
      ),
      ARRAY[]::text[]
    ),

    EXISTS (
      SELECT 1
      FROM public.member_role_grants g

      WHERE g.organization_id =
            m.organization_id

        AND g.organization_member_id =
            m.id

        AND g.revoked_at IS NULL

        AND g.branch_id IS NULL
    )

  FROM public.organization_members m

  CROSS JOIN actor a

  WHERE m.organization_id =
        p_organization_id

    AND a.member_id IS NOT NULL

    AND a.any_live_scope_read

    AND m.status IN (
      'active'::public.member_status,
      'suspended'::public.member_status
    )

    AND (
      a.organization_wide_read

      OR EXISTS (
        SELECT 1
        FROM public.member_role_grants target_scope

        WHERE target_scope.organization_id =
              m.organization_id

          AND target_scope.organization_member_id =
              m.id

          AND target_scope.revoked_at IS NULL

          AND (
            target_scope.branch_id IS NULL

            OR public.has_permission(
                 p_organization_id,
                 'team.read',
                 target_scope.branch_id
               )
          )
      )
    )

  ORDER BY
    m.display_name NULLS LAST,
    m.id;
$function$;


COMMENT ON FUNCTION public.team_access_directory(
  uuid
) IS
  'Canonical Team directory. Organization-wide team.read sees all members. Branch-scoped team.read sees organization-wide members plus members intersecting an authorized branch, with role and branch aggregates filtered to the same visibility boundary.';


CREATE OR REPLACE FUNCTION public.team_directory(
  p_organization_id uuid
)
RETURNS TABLE (
  member_status public.member_status,
  display_name text,
  email text,
  phone text,
  joined_at timestamptz,
  assigned_role_keys text[],
  assigned_role_labels text[],
  assigned_branch_names text[],
  organization_wide boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    directory.member_status,
    directory.display_name,
    directory.email,
    directory.phone,
    directory.joined_at,
    directory.assigned_role_keys,
    directory.assigned_role_labels,
    directory.assigned_branch_names,
    directory.organization_wide

  FROM public.team_access_directory(
    p_organization_id
  ) directory;
$function$;


COMMENT ON FUNCTION public.team_directory(
  uuid
) IS
  'Backward-compatible Team directory projection using the canonical branch-aware team_access_directory authorization boundary.';


-- ---------------------------------------------------------------------
-- 13A.4 Role-less invitation compatibility for branch-scoped
-- Studio Manager
--
-- Branch-scoped team.invite may:
--   * create a role-less invitation;
--   * reissue only that same actor's invitation;
--   * list only invitations created by that actor;
--   * revoke only invitations created by that actor.
--
-- It may NOT:
--   * pre-authorize roles;
--   * supersede another actor's pending invitation;
--   * revoke another actor's invitation.
--
-- Organization-wide team.invite retains the historical organization-
-- wide lifecycle.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_organization_invitation(
  p_organization_id uuid,
  p_email text,
  p_full_name text DEFAULT NULL,
  p_role_keys text[] DEFAULT ARRAY[]::text[],
  p_expires_in_hours integer DEFAULT 336
)
RETURNS TABLE (
  invitation_id uuid,
  email text,
  full_name text,
  role_keys text[],
  expires_at timestamptz,
  invite_token text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_email text;
  v_full_name text;
  v_role_keys text[];
  v_token text;
  v_token_hash bytea;
  v_invitation_id uuid;
  v_expires_at timestamptz;
  v_superseded_id uuid;
  v_organization_wide_invite boolean;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'create_organization_invitation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;


  v_organization_wide_invite :=
    public.has_permission(
      p_organization_id,
      'team.invite',
      NULL
    );


  IF NOT public.has_permission_in_any_live_scope(
    p_organization_id,
    'team.invite'
  ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: team.invite permission required'
      USING ERRCODE = '42501';
  END IF;


  v_email :=
    lower(
      NULLIF(
        btrim(p_email),
        ''
      )
    );

  v_full_name :=
    NULLIF(
      btrim(p_full_name),
      ''
    );


  IF v_email IS NULL
     OR v_email !~*
        '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION
      'create_organization_invitation: valid email is required'
      USING ERRCODE = '22023';
  END IF;


  IF v_full_name IS NOT NULL
     AND char_length(v_full_name) > 160 THEN
    RAISE EXCEPTION
      'create_organization_invitation: full name is too long'
      USING ERRCODE = '22023';
  END IF;


  IF p_expires_in_hours IS NULL
     OR p_expires_in_hours < 1
     OR p_expires_in_hours > 720 THEN
    RAISE EXCEPTION
      'create_organization_invitation: expiry must be between 1 and 720 hours'
      USING ERRCODE = '22023';
  END IF;


  IF EXISTS (
    SELECT 1
    FROM unnest(
      COALESCE(
        p_role_keys,
        ARRAY[]::text[]
      )
    ) supplied(role_key)

    WHERE supplied.role_key IS NULL
       OR btrim(supplied.role_key) = ''
  ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: role keys cannot be null or blank'
      USING ERRCODE = '22023';
  END IF;


  SELECT COALESCE(
    array_agg(
      DISTINCT lower(
        btrim(supplied.role_key)
      )
      ORDER BY lower(
        btrim(supplied.role_key)
      )
    ),
    ARRAY[]::text[]
  )
  INTO v_role_keys

  FROM unnest(
    COALESCE(
      p_role_keys,
      ARRAY[]::text[]
    )
  ) supplied(role_key);


  IF cardinality(v_role_keys) > 0
     AND NOT public.has_permission(
       p_organization_id,
       'team.role.assign',
       NULL
     ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: team.role.assign permission required to pre-authorize roles'
      USING ERRCODE = '42501';
  END IF;


  IF EXISTS (
    SELECT 1

    FROM unnest(
      v_role_keys
    ) supplied(role_key)

    LEFT JOIN public.roles r
      ON r.key =
         supplied.role_key

    WHERE r.id IS NULL
  ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: one or more role keys are invalid'
      USING ERRCODE = '22023';
  END IF;


  IF NOT v_organization_wide_invite
     AND EXISTS (
       SELECT 1
       FROM public.organization_invitations i

       WHERE i.organization_id =
             p_organization_id

         AND i.email =
             v_email

         AND i.status =
             'pending'::public.organization_invitation_status

         -- Expired pending invitations are stale credentials, not live
         -- ownership claims. A branch-scoped inviter may replace them.
         AND i.expires_at > now()

         AND i.invited_by <>
             v_actor
     ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: branch-scoped actors cannot supersede invitations created by another actor'
      USING ERRCODE = '42501';
  END IF;


  FOR v_superseded_id IN
    UPDATE public.organization_invitations i

    SET
      status =
        'revoked'::public.organization_invitation_status,

      revoked_at =
        now(),

      revoked_by =
        v_actor,

      revocation_reason =
        'Superseded by a newer invitation'

    WHERE i.organization_id =
          p_organization_id

      AND i.email =
          v_email

      AND i.status =
          'pending'::public.organization_invitation_status

      AND (
        v_organization_wide_invite

        OR i.invited_by =
           v_actor

        -- Any expired pending invitation is stale and may be revoked as
        -- part of safe reissue, regardless of the original inviter.
        OR i.expires_at <= now()
      )

    RETURNING i.id

  LOOP
    PERFORM public.append_audit_event(
      p_organization_id,
      NULL,
      'team.invitation.revoked',
      'organization_invitation',
      v_superseded_id,
      true,
      NULL,
      NULL,
      jsonb_build_object(
        'reason',
        'superseded_by_new_invitation'
      ),
      'team_access',
      NULL
    );
  END LOOP;


  v_token :=
    encode(
      extensions.gen_random_bytes(32),
      'hex'
    );


  v_token_hash :=
    extensions.digest(
      v_token,
      'sha256'
    );


  v_expires_at :=
    now()
    + make_interval(
        hours =>
          p_expires_in_hours
      );


  INSERT INTO public.organization_invitations (
    organization_id,
    email,
    full_name,
    token_hash,
    status,
    expires_at,
    invited_by
  )
  VALUES (
    p_organization_id,
    v_email,
    v_full_name,
    v_token_hash,
    'pending'::public.organization_invitation_status,
    v_expires_at,
    v_actor
  )
  RETURNING id
  INTO v_invitation_id;


  INSERT INTO public.organization_invitation_roles (
    organization_id,
    invitation_id,
    role_id,
    branch_id,
    assigned_by
  )
  SELECT
    p_organization_id,
    v_invitation_id,
    r.id,
    NULL,
    v_actor

  FROM public.roles r

  WHERE r.key =
        ANY(v_role_keys);


  PERFORM public.append_audit_event(
    p_organization_id,
    NULL,
    'team.invitation.created',
    'organization_invitation',
    v_invitation_id,
    true,
    NULL,
    NULL,
    jsonb_build_object(
      'role_keys',
      to_jsonb(v_role_keys),
      'expires_at',
      v_expires_at
    ),
    'team_access',
    NULL
  );


  RETURN QUERY
  SELECT
    v_invitation_id,
    v_email,
    v_full_name,
    v_role_keys,
    v_expires_at,
    v_token;
END
$function$;


CREATE OR REPLACE FUNCTION public.revoke_organization_invitation(
  p_organization_id uuid,
  p_invitation_id uuid,
  p_reason text DEFAULT 'Invitation revoked'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_reason text;
  v_invitation public.organization_invitations%ROWTYPE;
  v_organization_wide_invite boolean;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );


  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;


  v_organization_wide_invite :=
    public.has_permission(
      p_organization_id,
      'team.invite',
      NULL
    );


  IF NOT public.has_permission_in_any_live_scope(
    p_organization_id,
    'team.invite'
  ) THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: team.invite permission required'
      USING ERRCODE = '42501';
  END IF;


  v_reason :=
    NULLIF(
      btrim(p_reason),
      ''
    );


  IF v_reason IS NULL
     OR char_length(v_reason) > 500 THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: a reason up to 500 characters is required'
      USING ERRCODE = '22023';
  END IF;


  SELECT i.*
  INTO v_invitation

  FROM public.organization_invitations i

  WHERE i.id =
        p_invitation_id

    AND i.organization_id =
        p_organization_id

  FOR UPDATE;


  IF NOT FOUND THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: invitation not found'
      USING ERRCODE = '22023';
  END IF;


  IF NOT v_organization_wide_invite
     AND v_invitation.invited_by <>
         v_actor THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: branch-scoped actors may revoke only invitations they created'
      USING ERRCODE = '42501';
  END IF;


  IF v_invitation.status =
     'accepted'::public.organization_invitation_status THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: accepted invitations cannot be revoked'
      USING ERRCODE = '22023';
  END IF;


  IF v_invitation.status =
     'revoked'::public.organization_invitation_status THEN
    RETURN false;
  END IF;


  UPDATE public.organization_invitations

  SET
    status =
      'revoked'::public.organization_invitation_status,

    revoked_at =
      now(),

    revoked_by =
      v_actor,

    revocation_reason =
      v_reason

  WHERE id =
        p_invitation_id

    AND organization_id =
        p_organization_id;


  PERFORM public.append_audit_event(
    p_organization_id,
    NULL,
    'team.invitation.revoked',
    'organization_invitation',
    p_invitation_id,
    true,
    NULL,
    NULL,
    jsonb_build_object(
      'reason',
      v_reason
    ),
    'team_access',
    NULL
  );


  RETURN true;
END
$function$;


CREATE OR REPLACE FUNCTION public.team_invitation_directory(
  p_organization_id uuid
)
RETURNS TABLE (
  invitation_id uuid,
  email text,
  full_name text,
  invitation_status text,
  expires_at timestamptz,
  created_at timestamptz,
  role_keys text[],
  role_labels text[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH actor AS (
    SELECT
      public.current_organization_member(
        p_organization_id
      ) AS member_id,

      public.has_permission(
        p_organization_id,
        'team.invite',
        NULL
      ) AS organization_wide_invite,

      public.has_permission_in_any_live_scope(
        p_organization_id,
        'team.invite'
      ) AS any_live_scope_invite
  )

  SELECT
    i.id,
    i.email,
    i.full_name,

    CASE
      WHEN i.status =
           'pending'::public.organization_invitation_status
       AND i.expires_at <= now()
        THEN 'expired'
      ELSE i.status::text
    END,

    i.expires_at,
    i.created_at,

    COALESCE(
      (
        SELECT array_agg(
          r.key
          ORDER BY r.sort_order, r.key
        )

        FROM public.organization_invitation_roles ir

        JOIN public.roles r
          ON r.id = ir.role_id

        WHERE ir.organization_id =
              i.organization_id

          AND ir.invitation_id =
              i.id
      ),
      ARRAY[]::text[]
    ),

    COALESCE(
      (
        SELECT array_agg(
          r.label
          ORDER BY r.sort_order, r.key
        )

        FROM public.organization_invitation_roles ir

        JOIN public.roles r
          ON r.id = ir.role_id

        WHERE ir.organization_id =
              i.organization_id

          AND ir.invitation_id =
              i.id
      ),
      ARRAY[]::text[]
    )

  FROM public.organization_invitations i

  CROSS JOIN actor a

  WHERE i.organization_id =
        p_organization_id

    AND a.member_id IS NOT NULL

    AND a.any_live_scope_invite

    AND (
      a.organization_wide_invite

      OR i.invited_by =
         a.member_id
    )

  ORDER BY
    i.created_at DESC;
$function$;


COMMENT ON FUNCTION public.create_organization_invitation(
  uuid,
  text,
  text,
  text[],
  integer
) IS
  'Creates a canonical Team invitation. Organization-wide team.invite retains organization-wide lifecycle authority. Branch-scoped team.invite may create and reissue only its own role-less invitations; role pre-authorization still requires organization-wide team.role.assign.';


COMMENT ON FUNCTION public.revoke_organization_invitation(
  uuid,
  uuid,
  text
) IS
  'Revokes a canonical Team invitation. Organization-wide team.invite may revoke any invitation in the organization; branch-scoped team.invite may revoke only invitations created by that same actor.';


COMMENT ON FUNCTION public.team_invitation_directory(
  uuid
) IS
  'Canonical invitation directory. Organization-wide team.invite sees all invitations; branch-scoped team.invite sees only invitations created by the current actor.';


-- Explicitly preserve the existing callable Team API boundary.
REVOKE ALL
ON FUNCTION public.team_access_directory(uuid)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.team_directory(uuid)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.create_organization_invitation(
  uuid,
  text,
  text,
  text[],
  integer
)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.revoke_organization_invitation(
  uuid,
  uuid,
  text
)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.team_invitation_directory(uuid)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.team_access_directory(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.team_directory(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.create_organization_invitation(
  uuid,
  text,
  text,
  text[],
  integer
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.revoke_organization_invitation(
  uuid,
  uuid,
  text
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.team_invitation_directory(uuid)
TO authenticated, service_role;


-- =====================================================================
-- 14. Migration validation gates
-- =====================================================================

DO $validation$
DECLARE
  v_count integer;
  v_missing integer;
  v_org_status public.organization_status;
BEGIN

  -- ----------------------------------------------------------
  -- 14.1 Exactly four canonical live branches
  -- ----------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.branches b
  WHERE b.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND b.deleted_at IS NULL;

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Migration A validation failed: canonical organization has % live branches, expected 4',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.branches b
  WHERE (
    b.id,
    b.code,
    b.name,
    b.status
  ) IN (
    (
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
      'coimbatore',
      'Coimbatore',
      'active'::public.branch_status
    ),
    (
      'c5bf4f0a-d9c2-4a54-9dd6-5c0f3200e2ce'::uuid,
      'erode',
      'Erode',
      'active'::public.branch_status
    ),
    (
      '8c15f39c-bfa5-4c34-9768-48f7ef5fe5fa'::uuid,
      'bengaluru-mahadevapura',
      'Bengaluru — Mahadevapura',
      'active'::public.branch_status
    ),
    (
      '7c7f28bb-e308-47f1-86f3-87d963cd63e8'::uuid,
      'bengaluru-jp-nagar',
      'Bengaluru — JP Nagar',
      'active'::public.branch_status
    )
  );

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Migration A validation failed: canonical branch identity mismatch';
  END IF;


  -- ----------------------------------------------------------
  -- 14.2 Role catalogue
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles r
    WHERE r.key = 'founder'
      AND r.label =
          'Founder / Brand Owner / Studio Head'
      AND r.sort_order = 10
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Founder label/identity mismatch';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles r
    WHERE r.key = 'sales_head'
      AND r.label = 'Brand Sales Head'
      AND r.sort_order = 35
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Brand Sales Head role mismatch';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles r
    WHERE r.key = 'sales'
      AND r.label = 'Sales Team Member'
      AND r.sort_order = 40
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Sales Team Member role mismatch';
  END IF;


  -- ----------------------------------------------------------
  -- 14.3 New permission inventory
  -- ----------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.permissions p
  WHERE p.key IN (
    'lead.assign',
    'lead.branch.reassign',
    'sales.team.read',
    'sales.team.invite',
    'sales.team.scope.assign'
  );

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Migration A validation failed: expected 5 Sales hierarchy permissions, found %',
      v_count;
  END IF;


  -- Founder must hold every currently defined permission.
  SELECT count(*)
  INTO v_missing
  FROM public.permissions permission
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.roles founder
    JOIN public.role_permissions mapping
      ON mapping.role_id = founder.id
    WHERE founder.key = 'founder'
      AND mapping.permission_id = permission.id
  );

  IF v_missing <> 0 THEN
    RAISE EXCEPTION
      'Migration A validation failed: Founder is missing % permission mapping(s)',
      v_missing;
  END IF;


  -- Brand Sales Head must include every Sales Team Member
  -- operational permission.
  SELECT count(*)
  INTO v_missing
  FROM public.roles sales
  JOIN public.role_permissions sales_mapping
    ON sales_mapping.role_id = sales.id
  WHERE sales.key = 'sales'
    AND NOT EXISTS (
      SELECT 1
      FROM public.roles sales_head
      JOIN public.role_permissions head_mapping
        ON head_mapping.role_id = sales_head.id
      WHERE sales_head.key = 'sales_head'
        AND head_mapping.permission_id =
            sales_mapping.permission_id
    );

  IF v_missing <> 0 THEN
    RAISE EXCEPTION
      'Migration A validation failed: Brand Sales Head is missing % inherited Sales permission(s)',
      v_missing;
  END IF;


  SELECT count(*)
  INTO v_count
  FROM public.roles r
  JOIN public.role_permissions mapping
    ON mapping.role_id = r.id
  JOIN public.permissions p
    ON p.id = mapping.permission_id
  WHERE r.key = 'sales_head'
    AND p.key IN (
      'lead.assign',
      'lead.branch.reassign',
      'sales.team.read',
      'sales.team.invite',
      'sales.team.scope.assign'
    );

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Migration A validation failed: Brand Sales Head management permission count is %, expected 5',
      v_count;
  END IF;


  SELECT count(*)
  INTO v_count
  FROM public.roles r
  JOIN public.role_permissions mapping
    ON mapping.role_id = r.id
  JOIN public.permissions p
    ON p.id = mapping.permission_id
  WHERE r.key = 'sales'
    AND p.key IN (
      'lead.assign',
      'lead.branch.reassign',
      'sales.team.read',
      'sales.team.invite',
      'sales.team.scope.assign'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Migration A validation failed: Sales Team Member unexpectedly received Sales-management authority';
  END IF;


  IF EXISTS (
    SELECT 1
    FROM public.roles r
    JOIN public.role_permissions mapping
      ON mapping.role_id = r.id
    JOIN public.permissions p
      ON p.id = mapping.permission_id
    WHERE r.key = 'sales_head'
      AND p.key = 'team.role.assign'
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Brand Sales Head must not receive generic team.role.assign';
  END IF;


  -- ----------------------------------------------------------
  -- 14.4 Role-scope constitution
  -- ----------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.role_scope_policies;

  IF v_count <> (
    SELECT count(*)
    FROM public.roles
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: every role must have exactly one scope policy';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles r
    JOIN public.role_scope_policies policy
      ON policy.role_id = r.id
    WHERE r.key = 'founder'
      AND policy.organization_wide_allowed = true
      AND policy.branch_scoped_allowed = false
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Founder scope constitution mismatch';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles r
    JOIN public.role_scope_policies policy
      ON policy.role_id = r.id
    WHERE r.key = 'sales_head'
      AND policy.organization_wide_allowed = true
      AND policy.branch_scoped_allowed = true
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Brand Sales Head scope constitution mismatch';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles r
    JOIN public.role_scope_policies policy
      ON policy.role_id = r.id
    WHERE r.key = 'sales'
      AND policy.organization_wide_allowed = false
      AND policy.branch_scoped_allowed = true
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Sales Team Member scope constitution mismatch';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.roles r
    JOIN public.role_scope_policies policy
      ON policy.role_id = r.id
    WHERE r.key NOT IN (
      'founder',
      'sales_head'
    )
      AND (
        policy.organization_wide_allowed <> false
        OR policy.branch_scoped_allowed <> true
      )
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: one or more operational roles violate branch-scoped default';
  END IF;


  -- ----------------------------------------------------------
  -- 14.5 RLS / table privilege boundary
  -- ----------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'role_scope_policies',
      'organization_brand_owners'
    )
    AND c.relrowsecurity = true
    AND c.relforcerowsecurity = true;

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Migration A validation failed: new authorization tables must have enabled + forced RLS';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.role_table_grants grants
  WHERE grants.grantee IN (
    'anon',
    'authenticated'
  )
    AND grants.table_schema = 'public'
    AND grants.table_name IN (
      'role_scope_policies',
      'organization_brand_owners'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Migration A validation failed: client roles have direct privileges on internal authorization tables';
  END IF;


  -- ----------------------------------------------------------
  -- 14.6 Required triggers
  -- ----------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_trigger t
  JOIN pg_class c
    ON c.oid = t.tgrelid
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND NOT t.tgisinternal
    AND t.tgname IN (
      'member_role_grants_15_role_scope_guard',
      'organization_brand_owners_10_immutable_guard',
      'organization_members_10_brand_owner_guard',
      'member_role_grants_10_brand_owner_guard'
    );

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Migration A validation failed: authorization protection trigger count is %, expected 4',
      v_count;
  END IF;


  -- ----------------------------------------------------------
  -- 14.7 Brand Owner coverage for an already-active environment
  -- ----------------------------------------------------------

  SELECT o.status
  INTO v_org_status
  FROM public.organizations o
  WHERE o.id =
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

  IF v_org_status =
     'active'::public.organization_status THEN

    SELECT count(*)
    INTO v_count
    FROM public.organization_brand_owners owner
    JOIN public.organization_members m
      ON m.id = owner.organization_member_id
     AND m.organization_id = owner.organization_id
    JOIN public.member_role_grants g
      ON g.organization_id = owner.organization_id
     AND g.organization_member_id =
         owner.organization_member_id
     AND g.revoked_at IS NULL
     AND g.branch_id IS NULL
    JOIN public.roles r
      ON r.id = g.role_id
     AND r.key = 'founder'
    WHERE owner.organization_id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND m.status = 'active'::public.member_status
      AND m.exited_at IS NULL;

    IF v_count <> 1 THEN
      RAISE EXCEPTION
        'Migration A validation failed: active canonical organization lacks protected Brand Owner Founder coverage';
    END IF;

  END IF;


  -- ----------------------------------------------------------
  -- 14.8 Safe read-model functions
  -- ----------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'organization_shell_identity',
      'accessible_branch_catalogue'
    )
    AND p.prosecdef = true
    AND 'search_path=""' = ANY(
      COALESCE(
        p.proconfig,
        ARRAY[]::text[]
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Migration A validation failed: safe shell read-model function configuration mismatch';
  END IF;

  IF has_function_privilege(
       'anon',
       'public.organization_shell_identity(uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'anon',
       'public.accessible_branch_catalogue(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: anon may execute authenticated shell read models';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       'public.organization_shell_identity(uuid)',
       'EXECUTE'
     )
     OR NOT has_function_privilege(
       'authenticated',
       'public.accessible_branch_catalogue(uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: authenticated shell read-model execute grants are incomplete';
  END IF;


  -- ----------------------------------------------------------
  -- 14.9 Founder bootstrap remains service-role-only
  -- ----------------------------------------------------------

  IF has_function_privilege(
       'anon',
       'public.lsh_bootstrap_canonical_founder(uuid,text)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'authenticated',
       'public.lsh_bootstrap_canonical_founder(uuid,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: Founder bootstrap leaked to client roles';
  END IF;

  IF NOT has_function_privilege(
       'service_role',
       'public.lsh_bootstrap_canonical_founder(uuid,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: service_role cannot execute Founder bootstrap';
  END IF;


  -- ----------------------------------------------------------
  -- 14.10 Branch-scope compatibility layer
  -- ----------------------------------------------------------

  IF to_regprocedure(
       'public.has_permission_in_any_live_scope(uuid,text)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Migration A validation failed: any-live-scope permission helper is missing';
  END IF;


  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.oid =
        'public.has_permission_in_any_live_scope(uuid,text)'::regprocedure
    AND p.prosecdef = true
    AND p.provolatile = 's'
    AND 'search_path=""' = ANY(
      COALESCE(
        p.proconfig,
        ARRAY[]::text[]
      )
    );

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Migration A validation failed: any-live-scope permission helper configuration mismatch';
  END IF;


  IF has_function_privilege(
       'anon',
       'public.has_permission_in_any_live_scope(uuid,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: anon may execute any-live-scope permission helper';
  END IF;


  IF NOT has_function_privilege(
       'authenticated',
       'public.has_permission_in_any_live_scope(uuid,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: authenticated cannot execute any-live-scope permission helper';
  END IF;


  SELECT count(*)
  INTO v_count
  FROM pg_policies policy
  WHERE policy.schemaname = 'public'

    AND policy.tablename IN (
      'organizations',
      'organization_settings',
      'booking_journey_stages',
      'commercial_packages',
      'commercial_package_versions',
      'commercial_package_inclusions',
      'commercial_addons',
      'commercial_addon_versions',
      'commercial_operational_requirements'
    )

    AND (
      COALESCE(
        policy.qual,
        ''
      ) ILIKE
      '%has_permission_in_any_live_scope%'
    );

  IF v_count <> 9 THEN
    RAISE EXCEPTION
      'Migration A validation failed: organization-shared org.read compatibility policy count is %, expected 9',
      v_count;
  END IF;


  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'

    AND p.proname IN (
      'team_access_directory',
      'team_directory',
      'create_organization_invitation',
      'revoke_organization_invitation',
      'team_invitation_directory'
    )

    AND p.prosecdef = true

    AND 'search_path=""' = ANY(
      COALESCE(
        p.proconfig,
        ARRAY[]::text[]
      )
    );

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Migration A validation failed: Team compatibility function configuration count is %, expected 5',
      v_count;
  END IF;


  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'

    AND p.proname IN (
      'team_access_directory',
      'create_organization_invitation',
      'revoke_organization_invitation',
      'team_invitation_directory'
    )

    AND p.prosrc ILIKE
        '%has_permission_in_any_live_scope%';

  IF v_count <> 4 THEN
    RAISE EXCEPTION
      'Migration A validation failed: Team any-live-scope integration count is %, expected 4',
      v_count;
  END IF;


  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'public'

      AND p.proname IN (
        'team_access_directory',
        'team_directory',
        'create_organization_invitation',
        'revoke_organization_invitation',
        'team_invitation_directory'
      )

      AND has_function_privilege(
            'anon',
            p.oid,
            'EXECUTE'
          )
  ) THEN
    RAISE EXCEPTION
      'Migration A validation failed: anon may execute one or more Team compatibility functions';
  END IF;


  IF (
    SELECT count(*)
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'public'

      AND p.proname IN (
        'team_access_directory',
        'team_directory',
        'create_organization_invitation',
        'revoke_organization_invitation',
        'team_invitation_directory'
      )

      AND has_function_privilege(
            'authenticated',
            p.oid,
            'EXECUTE'
          )
  ) <> 5 THEN
    RAISE EXCEPTION
      'Migration A validation failed: authenticated Team compatibility execute grants are incomplete';
  END IF;


END
$validation$;

COMMIT;
