BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '180s';

-- ============================================================
-- Wave 1D / D.1A - Families Foundation
-- Current-baseline adaptation for the canonical organization.
-- ============================================================

-- 1. Preconditions
DO $pre$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.families') IS NOT NULL THEN
    RAISE EXCEPTION 'Families foundation aborted: public.families already exists';
  END IF;

  IF to_regtype('public.family_status') IS NOT NULL THEN
    RAISE EXCEPTION 'Families foundation aborted: public.family_status already exists';
  END IF;

  SELECT count(*) INTO v_count FROM public.permissions;
  IF v_count <> 38 THEN
    RAISE EXCEPTION 'Families foundation aborted: permissions count % does not equal 38', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM public.roles;
  IF v_count <> 11 THEN
    RAISE EXCEPTION 'Families foundation aborted: roles count % does not equal 11', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 139 THEN
    RAISE EXCEPTION 'Families foundation aborted: role_permissions count % does not equal 139', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.permissions
  WHERE key LIKE 'family.%';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Families foundation aborted: found % pre-existing family permissions', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.permissions
  WHERE key IN ('client.read', 'client.write');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Families foundation aborted: client.read/client.write baseline is incomplete';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.roles
  WHERE key IN (
    'founder', 'studio_manager', 'client_coordinator', 'sales',
    'photographer', 'assistant', 'stylist', 'editor',
    'album_coordinator', 'marketing', 'accounts'
  );
  IF v_count <> 11 THEN
    RAISE EXCEPTION 'Families foundation aborted: frozen role catalogue is incomplete';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure('public.lsh_set_updated_at()') IS NULL
     OR to_regprocedure('extensions.gen_random_bytes(integer)') IS NULL THEN
    RAISE EXCEPTION 'Families foundation aborted: required authorization or CSPRNG helper is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.branches'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (id, organization_id)'
  ) THEN
    RAISE EXCEPTION 'Families foundation aborted: branches UNIQUE (id, organization_id) is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.organization_members'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (id, organization_id)'
  ) THEN
    RAISE EXCEPTION 'Families foundation aborted: organization_members UNIQUE (id, organization_id) is missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.organizations o
  WHERE o.id = '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
    AND o.display_name = 'Little Shots by Hema'
    AND o.slug = 'little-shots-by-hema'
    AND o.legal_name = 'Little Shots by Hema'
    AND o.status IN ('suspended'::public.organization_status, 'active'::public.organization_status)
    AND o.currency_code = 'INR'
    AND o.timezone = 'Asia/Kolkata'
    AND o.brand_prefix = 'LSH'
    AND o.deleted_at IS NULL;

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Families foundation aborted: canonical organization identity does not match the approved baseline';
  END IF;
END
$pre$;

-- 2. Lifecycle enum
CREATE TYPE public.family_status AS ENUM (
  'active',
  'inactive',
  'archived',
  'merged'
);

-- 3. Families table - exactly 17 columns
CREATE TABLE public.families (
  id                       uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id          uuid NOT NULL,
  branch_id                uuid,
  family_code              text NOT NULL,
  display_name             text NOT NULL,
  sort_name                text NOT NULL,
  status                   public.family_status NOT NULL DEFAULT 'active',
  assigned_owner_member_id uuid,
  merged_into_family_id    uuid,
  merged_at                timestamptz,
  merged_by                uuid,
  archived_at              timestamptz,
  archived_by              uuid,
  created_at               timestamptz NOT NULL DEFAULT now(),
  created_by               uuid NOT NULL,
  updated_at               timestamptz NOT NULL DEFAULT now(),
  updated_by               uuid NOT NULL,

  CONSTRAINT families_pkey PRIMARY KEY (id),
  CONSTRAINT families_id_organization_id_key UNIQUE (id, organization_id),
  CONSTRAINT families_organization_id_family_code_key UNIQUE (organization_id, family_code),

  CONSTRAINT families_display_name_not_blank_chk
    CHECK (btrim(display_name) <> '' AND char_length(display_name) <= 160),
  CONSTRAINT families_sort_name_not_blank_chk
    CHECK (btrim(sort_name) <> '' AND char_length(sort_name) <= 160),
  CONSTRAINT families_family_code_format_chk
    CHECK (family_code ~ '^[A-Z0-9]{2,8}-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{6}$'),
  CONSTRAINT families_archive_metadata_paired_chk
    CHECK ((archived_at IS NULL) = (archived_by IS NULL)),
  CONSTRAINT families_merge_metadata_paired_chk
    CHECK (
      (merged_at IS NULL AND merged_by IS NULL AND merged_into_family_id IS NULL)
      OR
      (merged_at IS NOT NULL AND merged_by IS NOT NULL AND merged_into_family_id IS NOT NULL)
    ),
  CONSTRAINT families_archived_requires_metadata_chk
    CHECK (status <> 'archived'::public.family_status OR archived_at IS NOT NULL),
  CONSTRAINT families_merged_requires_metadata_chk
    CHECK (status <> 'merged'::public.family_status OR merged_at IS NOT NULL),
  CONSTRAINT families_non_merged_has_no_target_chk
    CHECK (status = 'merged'::public.family_status OR merged_into_family_id IS NULL),
  CONSTRAINT families_merge_target_not_self_chk
    CHECK (merged_into_family_id IS NULL OR merged_into_family_id <> id),

  CONSTRAINT families_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT families_branch_fkey
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT families_assigned_owner_fkey
    FOREIGN KEY (assigned_owner_member_id, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT families_merged_into_fkey
    FOREIGN KEY (merged_into_family_id, organization_id)
    REFERENCES public.families (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT families_merged_by_fkey
    FOREIGN KEY (merged_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT families_archived_by_fkey
    FOREIGN KEY (archived_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT families_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT families_updated_by_fkey
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE INDEX families_organization_status_idx
  ON public.families (organization_id, status);
CREATE INDEX families_branch_status_idx
  ON public.families (organization_id, branch_id, status);
CREATE INDEX families_assigned_owner_idx
  ON public.families (organization_id, assigned_owner_member_id)
  WHERE assigned_owner_member_id IS NOT NULL;
CREATE INDEX families_merge_target_idx
  ON public.families (organization_id, merged_into_family_id)
  WHERE merged_into_family_id IS NOT NULL;
CREATE INDEX families_sort_name_idx
  ON public.families (organization_id, sort_name);

-- 4. Cryptographically secure six-symbol suffix
CREATE OR REPLACE FUNCTION public.lsh_family_code_suffix()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SET search_path = ''
AS $$
DECLARE
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_result text := '';
  v_byte integer;
BEGIN
  WHILE char_length(v_result) < 6 LOOP
    v_byte := get_byte(extensions.gen_random_bytes(1), 0);
    IF v_byte < 240 THEN
      v_result := v_result || substr(v_alphabet, (v_byte % 30) + 1, 1);
    END IF;
  END LOOP;
  RETURN v_result;
END
$$;

-- 5. INSERT guard: only the controlled initial state is accepted
CREATE OR REPLACE FUNCTION public.lsh_families_insert_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  v_actor := public.current_organization_member(NEW.organization_id);

  IF v_actor IS NULL OR NEW.created_by <> v_actor OR NEW.updated_by <> v_actor THEN
    RAISE EXCEPTION 'Family creation requires the current active organization membership as actor';
  END IF;

  IF NEW.status <> 'active'::public.family_status
     OR NEW.merged_into_family_id IS NOT NULL
     OR NEW.merged_at IS NOT NULL
     OR NEW.merged_by IS NOT NULL
     OR NEW.archived_at IS NOT NULL
     OR NEW.archived_by IS NOT NULL THEN
    RAISE EXCEPTION 'A new family must begin active with no archive or merge metadata';
  END IF;

  IF NEW.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(NEW.organization_id, NEW.branch_id) THEN
    RAISE EXCEPTION 'Caller does not have scope for branch %', NEW.branch_id;
  END IF;

  IF NEW.assigned_owner_member_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.organization_members m
       WHERE m.id = NEW.assigned_owner_member_id
         AND m.organization_id = NEW.organization_id
         AND m.status = 'active'::public.member_status
     ) THEN
    RAISE EXCEPTION 'Assigned owner must be an active member of the same organization';
  END IF;

  RETURN NEW;
END
$$;

-- 6. UPDATE guard: immutable fields and frozen lifecycle transitions
CREATE OR REPLACE FUNCTION public.lsh_families_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  v_actor := public.current_organization_member(OLD.organization_id);
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Family update requires an active organization membership';
  END IF;

  IF NEW.id <> OLD.id
     OR NEW.organization_id <> OLD.organization_id
     OR NEW.family_code <> OLD.family_code
     OR NEW.created_at <> OLD.created_at
     OR NEW.created_by <> OLD.created_by THEN
    RAISE EXCEPTION 'Family identity, code and creation audit fields are immutable';
  END IF;

  IF OLD.status = 'merged'::public.family_status THEN
    RAISE EXCEPTION 'Merged families are terminal and cannot be updated';
  END IF;

  IF NEW.assigned_owner_member_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.organization_members m
       WHERE m.id = NEW.assigned_owner_member_id
         AND m.organization_id = NEW.organization_id
         AND m.status = 'active'::public.member_status
     ) THEN
    RAISE EXCEPTION 'Assigned owner must be an active member of the same organization';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF (OLD.status, NEW.status) IN (
      ('active'::public.family_status, 'inactive'::public.family_status),
      ('inactive'::public.family_status, 'active'::public.family_status)
    ) THEN
      IF NOT public.has_permission(OLD.organization_id, 'family.update', OLD.branch_id) THEN
        RAISE EXCEPTION 'family.update permission is required for active/inactive transitions';
      END IF;
      NEW.archived_at := NULL;
      NEW.archived_by := NULL;
      NEW.merged_into_family_id := NULL;
      NEW.merged_at := NULL;
      NEW.merged_by := NULL;

    ELSIF NEW.status = 'archived'::public.family_status
          AND OLD.status IN ('active'::public.family_status, 'inactive'::public.family_status) THEN
      IF NOT public.has_permission(OLD.organization_id, 'family.archive', OLD.branch_id) THEN
        RAISE EXCEPTION 'family.archive permission is required to archive a family';
      END IF;
      NEW.archived_at := COALESCE(NEW.archived_at, now());
      NEW.archived_by := v_actor;
      NEW.merged_into_family_id := NULL;
      NEW.merged_at := NULL;
      NEW.merged_by := NULL;

    ELSIF OLD.status = 'archived'::public.family_status
          AND NEW.status = 'active'::public.family_status THEN
      IF NOT public.has_permission(OLD.organization_id, 'family.archive', OLD.branch_id) THEN
        RAISE EXCEPTION 'family.archive permission is required to reactivate an archived family';
      END IF;
      NEW.archived_at := NULL;
      NEW.archived_by := NULL;
      NEW.merged_into_family_id := NULL;
      NEW.merged_at := NULL;
      NEW.merged_by := NULL;

    ELSIF NEW.status = 'merged'::public.family_status
          AND OLD.status IN (
            'active'::public.family_status,
            'inactive'::public.family_status,
            'archived'::public.family_status
          ) THEN
      IF NOT public.has_permission(OLD.organization_id, 'family.merge', OLD.branch_id) THEN
        RAISE EXCEPTION 'family.merge permission is required to merge a family';
      END IF;
      IF NEW.merged_into_family_id IS NULL THEN
        RAISE EXCEPTION 'Merged family requires a surviving family target';
      END IF;
      IF NOT EXISTS (
        SELECT 1
        FROM public.families target
        WHERE target.id = NEW.merged_into_family_id
          AND target.organization_id = OLD.organization_id
          AND target.id <> OLD.id
          AND target.status <> 'merged'::public.family_status
      ) THEN
        RAISE EXCEPTION 'Merge target must be a non-merged family in the same organization';
      END IF;
      NEW.merged_at := COALESCE(NEW.merged_at, now());
      NEW.merged_by := v_actor;
      -- Archive metadata is intentionally preserved when archived -> merged.

    ELSE
      RAISE EXCEPTION 'Disallowed family status transition: % -> %', OLD.status, NEW.status;
    END IF;
  ELSE
    IF NOT public.has_permission(OLD.organization_id, 'family.update', OLD.branch_id) THEN
      RAISE EXCEPTION 'family.update permission is required to edit family identity or assignment';
    END IF;

    IF NEW.merged_into_family_id IS DISTINCT FROM OLD.merged_into_family_id
       OR NEW.merged_at IS DISTINCT FROM OLD.merged_at
       OR NEW.merged_by IS DISTINCT FROM OLD.merged_by
       OR NEW.archived_at IS DISTINCT FROM OLD.archived_at
       OR NEW.archived_by IS DISTINCT FROM OLD.archived_by THEN
      RAISE EXCEPTION 'Lifecycle metadata may change only through an authorized status transition';
    END IF;
  END IF;

  NEW.updated_by := v_actor;
  RETURN NEW;
END
$$;

CREATE TRIGGER families_insert_guard
  BEFORE INSERT ON public.families
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_families_insert_guard();

CREATE TRIGGER families_lifecycle_guard
  BEFORE UPDATE ON public.families
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_families_lifecycle_guard();

CREATE TRIGGER families_set_updated_at
  BEFORE UPDATE ON public.families
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_set_updated_at();

-- 7. Controlled family creation RPC
CREATE OR REPLACE FUNCTION public.create_family(
  p_organization_id uuid,
  p_display_name text,
  p_sort_name text,
  p_branch_id uuid DEFAULT NULL,
  p_assigned_owner_member_id uuid DEFAULT NULL
)
RETURNS public.families
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_prefix text;
  v_code text;
  v_family public.families;
  v_attempt integer := 0;
  v_constraint text;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID is required';
  END IF;
  IF p_display_name IS NULL OR btrim(p_display_name) = '' THEN
    RAISE EXCEPTION 'Family display name is required';
  END IF;
  IF p_sort_name IS NULL OR btrim(p_sort_name) = '' THEN
    RAISE EXCEPTION 'Family sort name is required';
  END IF;

  v_actor := public.current_organization_member(p_organization_id);
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Caller is not an active member of organization %', p_organization_id;
  END IF;

  IF NOT public.has_permission(p_organization_id, 'family.create', p_branch_id) THEN
    RAISE EXCEPTION 'Caller lacks family.create permission in the requested scope';
  END IF;

  IF p_branch_id IS NOT NULL
     AND NOT public.has_branch_scope(p_organization_id, p_branch_id) THEN
    RAISE EXCEPTION 'Caller lacks scope for branch %', p_branch_id;
  END IF;

  IF p_assigned_owner_member_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.organization_members m
       WHERE m.id = p_assigned_owner_member_id
         AND m.organization_id = p_organization_id
         AND m.status = 'active'::public.member_status
     ) THEN
    RAISE EXCEPTION 'Assigned owner must be an active member of the same organization';
  END IF;

  SELECT o.brand_prefix
  INTO v_prefix
  FROM public.organizations o
  WHERE o.id = p_organization_id
    AND o.status = 'active'::public.organization_status
    AND o.deleted_at IS NULL;

  IF v_prefix IS NULL OR v_prefix !~ '^[A-Z0-9]{2,8}$' THEN
    RAISE EXCEPTION 'Organization brand prefix is missing or invalid';
  END IF;

  LOOP
    v_attempt := v_attempt + 1;
    v_code := v_prefix || '-' || public.lsh_family_code_suffix();

    BEGIN
      INSERT INTO public.families (
        organization_id,
        branch_id,
        family_code,
        display_name,
        sort_name,
        status,
        assigned_owner_member_id,
        created_by,
        updated_by
      )
      VALUES (
        p_organization_id,
        p_branch_id,
        v_code,
        btrim(p_display_name),
        btrim(p_sort_name),
        'active'::public.family_status,
        p_assigned_owner_member_id,
        v_actor,
        v_actor
      )
      RETURNING * INTO v_family;

      RETURN v_family;
    EXCEPTION WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      IF v_constraint <> 'families_organization_id_family_code_key' THEN
        RAISE;
      END IF;
      IF v_attempt >= 5 THEN
        RAISE EXCEPTION 'Unable to allocate a unique family code after five attempts';
      END IF;
    END;
  END LOOP;
    RAISE EXCEPTION
    'create_family terminated unexpectedly without creating a family';
END
$$;

-- 8. Exact additive permission catalogue
INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES
  ('family.read',                 'families', 'View families',                    'View family records within granted scope.', true),
  ('family.create',               'families', 'Create families',                  'Create a new family household record.', true),
  ('family.update',               'families', 'Update families',                  'Edit family identity fields and move a family between active and inactive.', true),
  ('family.archive',              'families', 'Archive families',                 'Archive a family and reactivate an archived family.', true),
  ('family.merge',                'families', 'Merge families',                   'Merge one family household into another; terminal and irreversible.', true),
  ('family.contact.read',         'families', 'View family contacts',             'View contact people and contact details attached to a family.', true),
  ('family.contact.write',        'families', 'Manage family contacts',           'Add, edit and deactivate contact people attached to a family.', true),
  ('family.communication.write',  'families', 'Manage communication controls',    'Set household communication controls and contactability.', true),
  ('family.privacy.read',         'families', 'View family privacy posture',      'View the household privacy posture and usage restrictions.', true),
  ('family.privacy.write',        'families', 'Manage family privacy posture',    'Change the household privacy posture and usage restrictions.', true),
  ('family.notes.read',           'families', 'View family notes',                'Read normal-visibility family notes.', true),
  ('family.notes.write',          'families', 'Write family notes',               'Append family notes and issue superseding corrections.', true),
  ('family.sensitive_notes.read', 'families', 'View restricted family notes',     'Read restricted-visibility family notes.', true),
  ('family.founder_notes.read',   'families', 'View founder-only family notes',   'Read founder-only family notes.', true),
  ('family.experience.read',      'families', 'View family experience profile',   'View the family experience and care profile.', true),
  ('family.experience.write',     'families', 'Manage family experience profile', 'Record and update the family experience and care profile.', true);

-- 9. Exact 69 role-permission mappings
WITH frozen(role_key, permission_key) AS (
  VALUES
    ('founder','family.read'),
    ('founder','family.create'),
    ('founder','family.update'),
    ('founder','family.archive'),
    ('founder','family.merge'),
    ('founder','family.contact.read'),
    ('founder','family.contact.write'),
    ('founder','family.communication.write'),
    ('founder','family.privacy.read'),
    ('founder','family.privacy.write'),
    ('founder','family.notes.read'),
    ('founder','family.notes.write'),
    ('founder','family.sensitive_notes.read'),
    ('founder','family.founder_notes.read'),
    ('founder','family.experience.read'),
    ('founder','family.experience.write'),

    ('studio_manager','family.read'),
    ('studio_manager','family.create'),
    ('studio_manager','family.update'),
    ('studio_manager','family.archive'),
    ('studio_manager','family.contact.read'),
    ('studio_manager','family.contact.write'),
    ('studio_manager','family.communication.write'),
    ('studio_manager','family.privacy.read'),
    ('studio_manager','family.privacy.write'),
    ('studio_manager','family.notes.read'),
    ('studio_manager','family.notes.write'),
    ('studio_manager','family.sensitive_notes.read'),
    ('studio_manager','family.experience.read'),
    ('studio_manager','family.experience.write'),

    ('client_coordinator','family.read'),
    ('client_coordinator','family.create'),
    ('client_coordinator','family.update'),
    ('client_coordinator','family.archive'),
    ('client_coordinator','family.contact.read'),
    ('client_coordinator','family.contact.write'),
    ('client_coordinator','family.communication.write'),
    ('client_coordinator','family.privacy.read'),
    ('client_coordinator','family.privacy.write'),
    ('client_coordinator','family.notes.read'),
    ('client_coordinator','family.notes.write'),
    ('client_coordinator','family.sensitive_notes.read'),
    ('client_coordinator','family.experience.read'),
    ('client_coordinator','family.experience.write'),

    ('sales','family.read'),
    ('sales','family.create'),
    ('sales','family.contact.read'),
    ('sales','family.contact.write'),
    ('sales','family.notes.read'),

    ('photographer','family.read'),
    ('photographer','family.notes.read'),
    ('photographer','family.notes.write'),
    ('photographer','family.experience.read'),
    ('photographer','family.experience.write'),

    ('assistant','family.read'),
    ('assistant','family.notes.read'),
    ('assistant','family.experience.read'),

    ('stylist','family.read'),
    ('stylist','family.notes.read'),
    ('stylist','family.experience.read'),

    ('editor','family.read'),
    ('editor','family.privacy.read'),
    ('editor','family.notes.read'),

    ('album_coordinator','family.read'),
    ('album_coordinator','family.contact.read'),
    ('album_coordinator','family.privacy.read'),
    ('album_coordinator','family.notes.read'),

    ('accounts','family.read'),
    ('accounts','family.contact.read')
)
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM frozen f
JOIN public.roles r ON r.key = f.role_key
JOIN public.permissions p ON p.key = f.permission_key;

-- 10. RLS and privileges
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families FORCE ROW LEVEL SECURITY;

CREATE POLICY families_select_scoped
  ON public.families
  FOR SELECT
  TO authenticated
  USING (
    public.has_permission(
      organization_id,
      'family.read',
      branch_id
    )
  );

CREATE POLICY families_update_scoped
  ON public.families
  FOR UPDATE
  TO authenticated
  USING (
    public.has_permission(organization_id, 'family.update', branch_id)
    OR public.has_permission(organization_id, 'family.archive', branch_id)
    OR public.has_permission(organization_id, 'family.merge', branch_id)
  )
  WITH CHECK (
    public.has_permission(organization_id, 'family.update', branch_id)
    OR public.has_permission(organization_id, 'family.archive', branch_id)
    OR public.has_permission(organization_id, 'family.merge', branch_id)
  );

REVOKE ALL PRIVILEGES
ON TABLE public.families
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT, UPDATE
ON TABLE public.families
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE public.families
TO service_role;

REVOKE ALL ON FUNCTION public.create_family(uuid,text,text,uuid,uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_family(uuid,text,text,uuid,uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.lsh_family_code_suffix() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lsh_families_insert_guard() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lsh_families_lifecycle_guard() FROM PUBLIC, anon, authenticated;

-- 11. Validation gates
DO $gate$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'families';
  IF v_count <> 17 THEN
    RAISE EXCEPTION 'Families validation failed: column count % does not equal 17', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_enum e
  JOIN pg_type t ON t.oid = e.enumtypid
  JOIN pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'public' AND t.typname = 'family_status';
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'Families validation failed: family_status label count % does not equal 4', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM public.permissions WHERE key LIKE 'family.%';
  IF v_count <> 16 THEN
    RAISE EXCEPTION 'Families validation failed: family permission count % does not equal 16', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM public.permissions;
  IF v_count <> 54 THEN
    RAISE EXCEPTION 'Families validation failed: total permission count % does not equal 54', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions rp
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE p.key LIKE 'family.%';
  IF v_count <> 69 THEN
    RAISE EXCEPTION 'Families validation failed: family mapping count % does not equal 69', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM public.role_permissions;
  IF v_count <> 208 THEN
    RAISE EXCEPTION 'Families validation failed: total role-permission count % does not equal 208', v_count;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.permissions
    WHERE key IN (
      'family.write', 'family.restore',
      'family.contacts.read', 'family.contacts.write'
    )
  ) THEN
    RAISE EXCEPTION 'Families validation failed: forbidden family permission key exists';
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_trigger
  WHERE tgrelid = 'public.families'::regclass
    AND NOT tgisinternal;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'Families validation failed: trigger count % does not equal 3', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'families';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Families validation failed: policy count % does not equal 2', v_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'families'
      AND cmd IN ('INSERT', 'DELETE')
  ) THEN
    RAISE EXCEPTION 'Families validation failed: INSERT or DELETE policy exists';
  END IF;

  IF has_table_privilege('anon', 'public.families', 'SELECT')
     OR has_table_privilege('anon', 'public.families', 'INSERT')
     OR has_table_privilege('anon', 'public.families', 'UPDATE')
     OR has_table_privilege('anon', 'public.families', 'DELETE') THEN
    RAISE EXCEPTION 'Families validation failed: anon has table privileges';
  END IF;

  IF has_table_privilege('authenticated', 'public.families', 'INSERT')
     OR has_table_privilege('authenticated', 'public.families', 'DELETE') THEN
    RAISE EXCEPTION 'Families validation failed: authenticated has INSERT or DELETE privilege';
  END IF;

  IF NOT has_table_privilege('authenticated', 'public.families', 'SELECT')
     OR NOT has_table_privilege('authenticated', 'public.families', 'UPDATE') THEN
    RAISE EXCEPTION 'Families validation failed: authenticated lacks SELECT or UPDATE';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.create_family(uuid,text,text,uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Families validation failed: authenticated cannot execute create_family';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.create_family(uuid,text,text,uuid,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Families validation failed: anon can execute create_family';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.role_permissions rp
    JOIN public.permissions p ON p.id = rp.permission_id
    JOIN public.roles r ON r.id = rp.role_id
    WHERE p.key IN ('family.merge', 'family.founder_notes.read')
      AND r.key <> 'founder'
  ) THEN
    RAISE EXCEPTION 'Families validation failed: Founder-only permission mapped to another role';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.role_permissions rp
    JOIN public.permissions p ON p.id = rp.permission_id
    JOIN public.roles r ON r.id = rp.role_id
    WHERE p.key = 'family.update' AND r.key = 'sales'
  ) THEN
    RAISE EXCEPTION 'Families validation failed: Sales holds family.update';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.role_permissions rp
    JOIN public.permissions p ON p.id = rp.permission_id
    JOIN public.roles r ON r.id = rp.role_id
    WHERE p.key LIKE 'family.%' AND r.key = 'marketing'
  ) THEN
    RAISE EXCEPTION 'Families validation failed: Marketing holds a family permission';
  END IF;

  IF EXISTS (SELECT 1 FROM public.families) THEN
    RAISE EXCEPTION 'Families validation failed: migration seeded family rows';
  END IF;

  IF to_regclass('public.family_contacts') IS NOT NULL
     OR to_regclass('public.family_contact_channels') IS NOT NULL
     OR to_regclass('public.family_communication_controls') IS NOT NULL
     OR to_regclass('public.family_privacy_defaults') IS NOT NULL
     OR to_regclass('public.family_experience_profile') IS NOT NULL
     OR to_regclass('public.family_notes') IS NOT NULL
     OR to_regclass('public.family_merge_records') IS NOT NULL THEN
    RAISE EXCEPTION 'Families validation failed: later-wave family table exists';
  END IF;
END
$gate$;

COMMIT;