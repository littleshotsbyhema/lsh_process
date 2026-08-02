SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';

DO $$
DECLARE
  v_org        public.organizations%ROWTYPE;
  v_settings   integer;
  v_branches   integer;
  v_perms      integer;
  v_roles      integer;
  v_roleperms  integer;
  v_founders   integer;
BEGIN
  SELECT * INTO v_org
  FROM public.organizations
  WHERE id = 'e1e8ec74-6b1f-444b-b8eb-e4d545480198'::uuid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'C.1 precondition failed: canonical organization not found';
  END IF;
  IF v_org.slug <> 'little-shots-by-hema' THEN
    RAISE EXCEPTION 'C.1 precondition failed: slug is %', v_org.slug;
  END IF;
  IF v_org.display_name <> 'Little Shots by Hema' THEN
    RAISE EXCEPTION 'C.1 precondition failed: display_name is %', v_org.display_name;
  END IF;
  IF v_org.legal_name IS NOT NULL THEN
    RAISE EXCEPTION 'C.1 precondition failed: legal_name must be NULL';
  END IF;
  IF v_org.status <> 'active'::public.organization_status THEN
    RAISE EXCEPTION 'C.1 precondition failed: status is %', v_org.status;
  END IF;
  IF v_org.currency_code <> 'INR' THEN
    RAISE EXCEPTION 'C.1 precondition failed: currency_code is %', v_org.currency_code;
  END IF;
  IF v_org.timezone <> 'Asia/Kolkata' THEN
    RAISE EXCEPTION 'C.1 precondition failed: timezone is %', v_org.timezone;
  END IF;
  IF v_org.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'C.1 precondition failed: organization is soft-deleted';
  END IF;

  SELECT count(*) INTO v_settings FROM public.organization_settings;
  IF v_settings <> 1 THEN
    RAISE EXCEPTION 'C.1 precondition failed: organization_settings rows = %', v_settings;
  END IF;

  SELECT count(*) INTO v_branches FROM public.branches;
  IF v_branches <> 0 THEN
    RAISE EXCEPTION 'C.1 precondition failed: branches rows = %', v_branches;
  END IF;

  SELECT count(*) INTO v_perms     FROM public.permissions;
  SELECT count(*) INTO v_roles     FROM public.roles;
  SELECT count(*) INTO v_roleperms FROM public.role_permissions;
  IF v_perms <> 38 OR v_roles <> 11 OR v_roleperms <> 139 THEN
    RAISE EXCEPTION 'C.1 precondition failed: reference counts %/%/% (expected 38/11/139)',
      v_perms, v_roles, v_roleperms;
  END IF;

  SELECT count(*) INTO v_founders
  FROM public.user_roles
  WHERE role = 'founder'::public.app_role;
  IF v_founders <> 1 THEN
    RAISE EXCEPTION 'C.1 precondition failed: legacy founder count = % (expected 1)', v_founders;
  END IF;
END
$$;

CREATE TYPE public.member_status AS ENUM ('active', 'suspended', 'left', 'revoked');

ALTER TABLE public.branches
  ADD CONSTRAINT branches_id_organization_id_key UNIQUE (id, organization_id);

CREATE TABLE public.organization_members (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id     uuid NOT NULL,
  user_id             uuid NOT NULL,
  status              public.member_status NOT NULL DEFAULT 'active',
  display_name        text,
  email               text,
  phone               text,
  joined_at           timestamptz NOT NULL DEFAULT now(),
  suspended_at        timestamptz,
  suspended_by        uuid,
  suspension_reason   text,
  exited_at           timestamptz,
  exited_by           uuid,
  exit_reason         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid,
  updated_by          uuid,

  CONSTRAINT organization_members_organization_id_fkey
    FOREIGN KEY (organization_id) REFERENCES public.organizations (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT organization_members_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT organization_members_organization_id_user_id_key
    UNIQUE (organization_id, user_id),

  CONSTRAINT organization_members_id_organization_id_key
    UNIQUE (id, organization_id),

  CONSTRAINT organization_members_suspension_chk CHECK (
    (status = 'suspended' AND suspended_at IS NOT NULL)
    OR (status <> 'suspended')
  ),
  CONSTRAINT organization_members_exit_chk CHECK (
    (status IN ('left', 'revoked') AND exited_at IS NOT NULL)
    OR (status NOT IN ('left', 'revoked'))
  )
);

ALTER TABLE public.organization_members
  ADD CONSTRAINT organization_members_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT organization_members_updated_by_fkey
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT organization_members_suspended_by_fkey
    FOREIGN KEY (suspended_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ADD CONSTRAINT organization_members_exited_by_fkey
    FOREIGN KEY (exited_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT;

CREATE INDEX organization_members_organization_id_idx
  ON public.organization_members (organization_id);
CREATE INDEX organization_members_user_id_idx
  ON public.organization_members (user_id);
CREATE INDEX organization_members_organization_id_status_idx
  ON public.organization_members (organization_id, status);

CREATE TRIGGER organization_members_set_updated_at
  BEFORE UPDATE ON public.organization_members
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TABLE public.member_role_grants (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id         uuid NOT NULL,
  organization_member_id  uuid NOT NULL,
  role_id                 uuid NOT NULL,
  branch_id               uuid,
  granted_at              timestamptz NOT NULL DEFAULT now(),
  granted_by              uuid,
  revoked_at              timestamptz,
  revoked_by              uuid,
  revocation_reason       text,
  created_at              timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT member_role_grants_organization_id_fkey
    FOREIGN KEY (organization_id) REFERENCES public.organizations (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_member_fkey
    FOREIGN KEY (organization_member_id, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_role_id_fkey
    FOREIGN KEY (role_id) REFERENCES public.roles (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_branch_fkey
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_granted_by_fkey
    FOREIGN KEY (granted_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_revoked_by_fkey
    FOREIGN KEY (revoked_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_revocation_chk CHECK (
    (revoked_at IS NULL AND revoked_by IS NULL AND revocation_reason IS NULL)
    OR (revoked_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX member_role_grants_live_orgwide_key
  ON public.member_role_grants (organization_member_id, role_id)
  WHERE revoked_at IS NULL AND branch_id IS NULL;

CREATE UNIQUE INDEX member_role_grants_live_branch_key
  ON public.member_role_grants (organization_member_id, role_id, branch_id)
  WHERE revoked_at IS NULL AND branch_id IS NOT NULL;

CREATE INDEX member_role_grants_organization_id_idx
  ON public.member_role_grants (organization_id);
CREATE INDEX member_role_grants_member_idx
  ON public.member_role_grants (organization_member_id);
CREATE INDEX member_role_grants_live_idx
  ON public.member_role_grants (organization_id, organization_member_id)
  WHERE revoked_at IS NULL;

CREATE OR REPLACE FUNCTION public.lsh_reject_branch_scoped_founder()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role_key text;
BEGIN
  IF NEW.branch_id IS NULL THEN
    RETURN NEW;
  END IF;
  SELECT r.key INTO v_role_key FROM public.roles r WHERE r.id = NEW.role_id;
  IF v_role_key = 'founder' THEN
    RAISE EXCEPTION 'Founder grants must be organization-wide (branch_id IS NULL)';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER member_role_grants_reject_branch_founder
  BEFORE INSERT OR UPDATE ON public.member_role_grants
  FOR EACH ROW EXECUTE FUNCTION public.lsh_reject_branch_scoped_founder();

CREATE OR REPLACE FUNCTION public.lsh_assert_founder_coverage(p_organization_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_status public.organization_status;
  v_deleted timestamptz;
  v_count integer;
BEGIN
  SELECT o.status, o.deleted_at INTO v_status, v_deleted
  FROM public.organizations o WHERE o.id = p_organization_id;

  IF NOT FOUND OR v_status <> 'active'::public.organization_status OR v_deleted IS NOT NULL THEN
    RETURN;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.member_role_grants g
  JOIN public.organization_members m
    ON m.id = g.organization_member_id
   AND m.organization_id = g.organization_id
  JOIN public.roles r ON r.id = g.role_id
  WHERE g.organization_id = p_organization_id
    AND g.revoked_at IS NULL
    AND g.branch_id IS NULL
    AND r.key = 'founder'
    AND m.status = 'active'::public.member_status;

  IF v_count < 1 THEN
    RAISE EXCEPTION
      'Organization % would be left with zero active organization-wide Founders',
      p_organization_id;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.lsh_last_founder_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP IN ('DELETE', 'UPDATE') AND OLD.organization_id IS NOT NULL THEN
    PERFORM public.lsh_assert_founder_coverage(OLD.organization_id);
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.organization_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.organization_id IS DISTINCT FROM OLD.organization_id) THEN
    PERFORM public.lsh_assert_founder_coverage(NEW.organization_id);
  END IF;
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER member_role_grants_last_founder_guard
  AFTER INSERT OR UPDATE OR DELETE ON public.member_role_grants
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.lsh_last_founder_guard();

CREATE CONSTRAINT TRIGGER organization_members_last_founder_guard
  AFTER UPDATE OR DELETE ON public.organization_members
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.lsh_last_founder_guard();

CREATE OR REPLACE FUNCTION public.lsh_organization_activation_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status = 'active'::public.organization_status AND NEW.deleted_at IS NULL THEN
    PERFORM public.lsh_assert_founder_coverage(NEW.id);
  END IF;
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER organizations_activation_guard
  AFTER INSERT OR UPDATE ON public.organizations
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.lsh_organization_activation_guard();

CREATE OR REPLACE FUNCTION public.lsh_organizations_slug_immutable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.slug IS DISTINCT FROM OLD.slug THEN
    RAISE EXCEPTION 'organizations.slug is immutable (attempted % -> %)', OLD.slug, NEW.slug;
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER organizations_slug_immutable
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.lsh_organizations_slug_immutable();

CREATE OR REPLACE FUNCTION public.current_user_organization_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT DISTINCT m.organization_id
  FROM public.organization_members m
  JOIN public.organizations o ON o.id = m.organization_id
  JOIN public.member_role_grants g
    ON g.organization_member_id = m.id
   AND g.organization_id = m.organization_id
  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id
  WHERE m.user_id = auth.uid()
    AND m.status = 'active'::public.member_status
    AND o.status = 'active'::public.organization_status
    AND o.deleted_at IS NULL
    AND g.revoked_at IS NULL
    AND (
      g.branch_id IS NULL
      OR (b.id IS NOT NULL
          AND b.deleted_at IS NULL
          AND b.status = 'active'::public.branch_status)
    );
$$;

CREATE OR REPLACE FUNCTION public.current_organization_member(p_organization_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT m.id
  FROM public.organization_members m
  JOIN public.organizations o ON o.id = m.organization_id
  WHERE m.user_id = auth.uid()
    AND m.organization_id = p_organization_id
    AND m.status = 'active'::public.member_status
    AND o.status = 'active'::public.organization_status
    AND o.deleted_at IS NULL
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.has_permission(
  p_organization_id uuid,
  p_permission_key  text,
  p_branch_id       uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.member_role_grants g
    JOIN public.role_permissions rp ON rp.role_id = g.role_id
    JOIN public.permissions p       ON p.id = rp.permission_id
    LEFT JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id = g.organization_id
    WHERE g.organization_id = p_organization_id
      AND g.organization_member_id = public.current_organization_member(p_organization_id)
      AND g.revoked_at IS NULL
      AND p.key = p_permission_key
      AND (
        g.branch_id IS NULL
        OR (p_branch_id IS NOT NULL
            AND g.branch_id = p_branch_id
            AND b.id IS NOT NULL
            AND b.deleted_at IS NULL
            AND b.status = 'active'::public.branch_status)
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.has_branch_scope(
  p_organization_id uuid,
  p_branch_id       uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.member_role_grants g
    LEFT JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id = g.organization_id
    WHERE g.organization_id = p_organization_id
      AND g.organization_member_id = public.current_organization_member(p_organization_id)
      AND g.revoked_at IS NULL
      AND (
        g.branch_id IS NULL
        OR (g.branch_id = p_branch_id
            AND b.id IS NOT NULL
            AND b.deleted_at IS NULL
            AND b.status = 'active'::public.branch_status)
      )
  )
  AND EXISTS (
    SELECT 1 FROM public.branches b2
    WHERE b2.id = p_branch_id
      AND b2.organization_id = p_organization_id
      AND b2.deleted_at IS NULL
      AND b2.status = 'active'::public.branch_status
  );
$$;

CREATE OR REPLACE FUNCTION public.effective_permissions(
  p_organization_id uuid,
  p_branch_id       uuid DEFAULT NULL
)
RETURNS SETOF text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT DISTINCT p.key
  FROM public.member_role_grants g
  JOIN public.role_permissions rp ON rp.role_id = g.role_id
  JOIN public.permissions p       ON p.id = rp.permission_id
  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id
  WHERE g.organization_id = p_organization_id
    AND g.organization_member_id = public.current_organization_member(p_organization_id)
    AND g.revoked_at IS NULL
    AND (
      g.branch_id IS NULL
      OR (p_branch_id IS NOT NULL
          AND g.branch_id = p_branch_id
          AND b.id IS NOT NULL
          AND b.deleted_at IS NULL
          AND b.status = 'active'::public.branch_status)
    )
  ORDER BY 1;
$$;

CREATE OR REPLACE FUNCTION public.my_membership(p_organization_id uuid)
RETURNS TABLE (
  organization_id     uuid,
  organization_name   text,
  member_status       public.member_status,
  display_name        text,
  email               text,
  phone               text,
  joined_at           timestamptz,
  assigned_role_keys  text[],
  assigned_role_labels text[],
  branch_names        text[],
  organization_wide   boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    m.organization_id,
    o.display_name,
    m.status,
    m.display_name,
    m.email,
    m.phone,
    m.joined_at,
    COALESCE(array_agg(DISTINCT r.key)   FILTER (WHERE r.key IS NOT NULL), '{}'),
    COALESCE(array_agg(DISTINCT r.label) FILTER (WHERE r.label IS NOT NULL), '{}'),
    COALESCE(array_agg(DISTINCT b.name)  FILTER (WHERE b.name IS NOT NULL), '{}'),
    bool_or(g.branch_id IS NULL)
  FROM public.organization_members m
  JOIN public.organizations o ON o.id = m.organization_id
  LEFT JOIN public.member_role_grants g
    ON g.organization_member_id = m.id
   AND g.organization_id = m.organization_id
   AND g.revoked_at IS NULL
  LEFT JOIN public.roles r ON r.id = g.role_id
  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id
   AND b.deleted_at IS NULL
   AND b.status = 'active'::public.branch_status
  WHERE m.organization_id = p_organization_id
    AND m.user_id = auth.uid()
  GROUP BY m.organization_id, o.display_name, m.status, m.display_name,
           m.email, m.phone, m.joined_at;
$$;

CREATE OR REPLACE FUNCTION public.team_directory(p_organization_id uuid)
RETURNS TABLE (
  member_status        public.member_status,
  display_name         text,
  email                text,
  phone                text,
  joined_at            timestamptz,
  assigned_role_keys   text[],
  assigned_role_labels text[],
  assigned_branch_names text[],
  organization_wide    boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    m.status,
    m.display_name,
    m.email,
    m.phone,
    m.joined_at,
    COALESCE(array_agg(DISTINCT r.key)   FILTER (WHERE r.key IS NOT NULL), '{}'),
    COALESCE(array_agg(DISTINCT r.label) FILTER (WHERE r.label IS NOT NULL), '{}'),
    COALESCE(array_agg(DISTINCT b.name)  FILTER (WHERE b.name IS NOT NULL), '{}'),
    bool_or(g.branch_id IS NULL)
  FROM public.organization_members m
  LEFT JOIN public.member_role_grants g
    ON g.organization_member_id = m.id
   AND g.organization_id = m.organization_id
   AND g.revoked_at IS NULL
  LEFT JOIN public.roles r ON r.id = g.role_id
  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id
   AND b.deleted_at IS NULL
   AND b.status = 'active'::public.branch_status
  WHERE m.organization_id = p_organization_id
    AND public.has_permission(p_organization_id, 'team.read', NULL)
    AND m.status IN ('active'::public.member_status, 'suspended'::public.member_status)
  GROUP BY m.status, m.display_name, m.email, m.phone, m.joined_at
  ORDER BY m.display_name NULLS LAST;
$$;

CREATE OR REPLACE FUNCTION public.role_catalogue()
RETURNS TABLE (
  key         text,
  label       text,
  description text,
  sort_order  integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT r.key, r.label, r.description, r.sort_order
  FROM public.roles r
  ORDER BY r.sort_order, r.key;
$$;

DROP POLICY IF EXISTS organizations_deny_all          ON public.organizations;
DROP POLICY IF EXISTS organization_settings_deny_all  ON public.organization_settings;
DROP POLICY IF EXISTS branches_deny_all               ON public.branches;

CREATE POLICY organizations_read ON public.organizations
  FOR SELECT TO authenticated
  USING (public.has_permission(id, 'org.read', NULL));

CREATE POLICY organization_settings_read ON public.organization_settings
  FOR SELECT TO authenticated
  USING (public.has_permission(organization_id, 'org.read', NULL));

CREATE POLICY branches_read ON public.branches
  FOR SELECT TO authenticated
  USING (public.has_branch_scope(organization_id, id));

ALTER TABLE public.organization_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members  FORCE ROW LEVEL SECURITY;
ALTER TABLE public.member_role_grants    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_role_grants    FORCE ROW LEVEL SECURITY;

CREATE POLICY organization_members_deny_all ON public.organization_members
  FOR ALL TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY member_role_grants_deny_all ON public.member_role_grants
  FOR ALL TO authenticated USING (false) WITH CHECK (false);

REVOKE ALL ON public.organization_members FROM PUBLIC;
REVOKE ALL ON public.organization_members FROM anon, authenticated;
REVOKE ALL ON public.member_role_grants   FROM anon, authenticated;
GRANT ALL ON public.organization_members TO service_role;
GRANT ALL ON public.member_role_grants   TO service_role;

REVOKE ALL ON public.organizations, public.organization_settings, public.branches
  FROM anon, authenticated;
GRANT SELECT ON public.organizations, public.organization_settings, public.branches
  TO authenticated;

REVOKE ALL ON FUNCTION public.current_user_organization_ids()                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_organization_member(uuid)                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_permission(uuid, text, uuid)                    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_branch_scope(uuid, uuid)                        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.effective_permissions(uuid, uuid)                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.my_membership(uuid)                                 FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.team_directory(uuid)                                FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.role_catalogue()                                    FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.current_user_organization_ids()   TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_organization_member(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_permission(uuid, text, uuid)  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_branch_scope(uuid, uuid)      TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.effective_permissions(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.my_membership(uuid)               TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.team_directory(uuid)              TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.role_catalogue()                  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.lsh_bootstrap_founder()
RETURNS TABLE (
  organization_id        uuid,
  member_id              uuid,
  grant_id               uuid,
  legacy_founder_user_id uuid,
  member_created         boolean,
  grant_created          boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_org        uuid := 'e1e8ec74-6b1f-444b-b8eb-e4d545480198'::uuid;
  v_user       uuid;
  v_email      text;
  v_name       text;
  v_member     uuid;
  v_status     public.member_status;
  v_role       uuid;
  v_grant      uuid;
  v_m_created  boolean := false;
  v_g_created  boolean := false;
  v_n          integer;
BEGIN
  SELECT count(*) INTO v_n
  FROM public.user_roles WHERE role = 'founder'::public.app_role;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Bootstrap requires exactly one legacy Founder, found %', v_n;
  END IF;

  SELECT ur.user_id INTO v_user
  FROM public.user_roles ur WHERE ur.role = 'founder'::public.app_role;

  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = v_user) THEN
    RAISE EXCEPTION 'Legacy Founder % has no auth.users row', v_user;
  END IF;

  SELECT p.email, p.full_name INTO v_email, v_name
  FROM public.profiles p WHERE p.id = v_user;

  SELECT r.id INTO v_role FROM public.roles r WHERE r.key = 'founder';
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Reference role "founder" is missing';
  END IF;

  SELECT m.id, m.status INTO v_member, v_status
  FROM public.organization_members m
  WHERE m.organization_id = v_org AND m.user_id = v_user;

  IF v_member IS NULL THEN
    INSERT INTO public.organization_members
      (organization_id, user_id, status, display_name, email)
    VALUES (v_org, v_user, 'active'::public.member_status, v_name, v_email)
    RETURNING id INTO v_member;
    v_m_created := true;
  ELSE
    IF v_status = 'active'::public.member_status THEN
      NULL;
    ELSIF v_status = 'suspended'::public.member_status THEN
      RAISE EXCEPTION
        'Canonical Founder membership % is suspended; resolve suspension before bootstrap', v_member;
    ELSIF v_status = 'left'::public.member_status THEN
      RAISE EXCEPTION
        'Canonical Founder membership % has status "left"; explicit re-admission required', v_member;
    ELSIF v_status = 'revoked'::public.member_status THEN
      RAISE EXCEPTION
        'Canonical Founder membership % is revoked; bootstrap must not reactivate it', v_member;
    END IF;
  END IF;

  SELECT g.id INTO v_grant
  FROM public.member_role_grants g
  WHERE g.organization_id = v_org
    AND g.organization_member_id = v_member
    AND g.role_id = v_role
    AND g.branch_id IS NULL
    AND g.revoked_at IS NULL;

  IF v_grant IS NULL THEN
    INSERT INTO public.member_role_grants
      (organization_id, organization_member_id, role_id, branch_id)
    VALUES (v_org, v_member, v_role, NULL)
    RETURNING id INTO v_grant;
    v_g_created := true;
  END IF;

  RETURN QUERY SELECT v_org, v_member, v_grant, v_user, v_m_created, v_g_created;
END
$$;

REVOKE ALL ON FUNCTION public.lsh_bootstrap_founder() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lsh_bootstrap_founder() TO service_role;

SELECT * FROM public.lsh_bootstrap_founder();

DO $$
DECLARE
  v integer; v_txt text[];
BEGIN
  SELECT array_agg(e.enumlabel::text ORDER BY e.enumsortorder) INTO v_txt
  FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
  WHERE t.typname = 'member_status';
  IF v_txt <> ARRAY['active','suspended','left','revoked'] THEN
    RAISE EXCEPTION 'Gate 1 failed: member_status = %', v_txt;
  END IF;

  SELECT count(*) INTO v FROM public.organization_members;
  IF v <> 1 THEN RAISE EXCEPTION 'Gate 2 failed: members = %', v; END IF;

  SELECT count(*) INTO v FROM public.member_role_grants
   WHERE revoked_at IS NULL AND branch_id IS NULL;
  IF v <> 1 THEN RAISE EXCEPTION 'Gate 3 failed: live org-wide grants = %', v; END IF;

  SELECT count(*) INTO v
  FROM public.role_permissions rp
  JOIN public.roles r ON r.id = rp.role_id
  WHERE r.key = 'founder';
  IF v <> 38 THEN RAISE EXCEPTION 'Gate 4 failed: founder permissions = %', v; END IF;

  PERFORM public.lsh_assert_founder_coverage('e1e8ec74-6b1f-444b-b8eb-e4d545480198'::uuid);

  SELECT count(*) INTO v FROM public.branches;
  IF v <> 0 THEN RAISE EXCEPTION 'Gate 6 failed: branches = %', v; END IF;

  SELECT count(*) INTO v FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prosecdef
    AND p.proname IN ('current_user_organization_ids','current_organization_member',
                      'has_permission','has_branch_scope','effective_permissions',
                      'my_membership','team_directory','role_catalogue',
                      'lsh_bootstrap_founder','lsh_assert_founder_coverage',
                      'lsh_last_founder_guard','lsh_organization_activation_guard',
                      'lsh_organizations_slug_immutable','lsh_reject_branch_scoped_founder')
    AND NOT ('search_path=""' = ANY(COALESCE(p.proconfig, ARRAY[]::text[])));
  IF v <> 0 THEN RAISE EXCEPTION 'Gate 7 failed: % SECURITY DEFINER functions lack SET search_path = ''''', v; END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
    WHERE table_schema='public'
      AND table_name IN ('organization_members','member_role_grants')
      AND grantee IN ('anon','authenticated')
  ) THEN
    RAISE EXCEPTION 'Gate 8 failed: client privileges exist on C.1 tables';
  END IF;
END
$$;