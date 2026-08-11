BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '180s';

-- ============================================================
-- Children + Memory Profiles Foundation
-- Little Shots by Hema
--
-- Principles:
-- - minimal child identity data
-- - family-scoped tenancy
-- - branch-aware RBAC
-- - authenticated reads through RLS
-- - authenticated writes only through controlled RPCs
-- - no hard deletion
-- - audit all controlled mutations
-- ============================================================

CREATE TEMP TABLE migration_permission_snapshot ON COMMIT DROP AS
SELECT
  (SELECT count(*) FROM public.permissions) AS permission_count,
  (SELECT count(*) FROM public.role_permissions) AS role_permission_count;

-- ============================================================
-- 1. Preconditions
-- ============================================================

DO $pre$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.organizations') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.organizations is missing';
  END IF;

  IF to_regclass('public.branches') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.branches is missing';
  END IF;

  IF to_regclass('public.organization_members') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.organization_members is missing';
  END IF;

  IF to_regclass('public.families') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.families is missing';
  END IF;

  IF to_regclass('public.audit_events') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.audit_events is missing';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.current_organization_member(uuid) is missing';
  END IF;

  IF to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.has_permission(uuid,text,uuid) is missing';
  END IF;

  IF to_regprocedure('public.lsh_set_updated_at()') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.lsh_set_updated_at() is missing';
  END IF;

  IF to_regprocedure(
    'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
  ) IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.append_audit_event(...) is missing';
  END IF;

  IF to_regtype('public.family_status') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.family_status is missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions
  WHERE key IN ('memory.read', 'memory.write');

  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Precondition failed: memory.read and memory.write permissions are required';
  END IF;

  IF to_regtype('public.child_stage') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.child_stage already exists';
  END IF;

  IF to_regtype('public.child_status') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.child_status already exists';
  END IF;

  IF to_regtype('public.privacy_preference_type') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.privacy_preference_type already exists';
  END IF;

  IF to_regclass('public.children') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.children already exists';
  END IF;

  IF to_regclass('public.memory_profiles') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.memory_profiles already exists';
  END IF;

  IF to_regprocedure(
    'public.create_child(uuid,text,date,date,public.child_stage,public.privacy_preference_type)'
  ) IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.create_child already exists';
  END IF;

  IF to_regprocedure(
    'public.update_child(uuid,text,date,date,public.child_stage,public.privacy_preference_type,public.child_status)'
  ) IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.update_child already exists';
  END IF;

  IF to_regprocedure(
    'public.upsert_memory_profile(uuid,uuid,text,text,text[],text,text)'
  ) IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.upsert_memory_profile already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.families'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (id, organization_id)'
  ) THEN
    RAISE EXCEPTION
      'Precondition failed: public.families UNIQUE (id, organization_id) is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.organization_members'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (id, organization_id)'
  ) THEN
    RAISE EXCEPTION
      'Precondition failed: public.organization_members UNIQUE (id, organization_id) is missing';
  END IF;
END
$pre$;

-- ============================================================
-- 2. Canonical enums
-- ============================================================

CREATE TYPE public.child_stage AS ENUM (
  'expected',
  'newborn',
  'baby',
  'sitter',
  'toddler',
  'child'
);

CREATE TYPE public.child_status AS ENUM (
  'active',
  'archived'
);

-- Canonical Phase 1 privacy-preference vocabulary.
--
-- NULL on a child means there is no child-specific override yet.
-- It must never be interpreted as granted consent.
CREATE TYPE public.privacy_preference_type AS ENUM (
  'full_privacy',
  'selective_sharing',
  'anonymous_sharing',
  'portfolio_release',
  'decide_later'
);

-- ============================================================
-- 3. Children
-- ============================================================

CREATE TABLE public.children (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  family_id uuid NOT NULL,

  child_reference text NOT NULL,

  first_name text,
  birth_date date,
  expected_due_date date,
  current_stage public.child_stage,
  privacy_restriction public.privacy_preference_type,

  status public.child_status NOT NULL DEFAULT 'active',

  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,

  archived_at timestamptz,
  archived_by uuid,

  CONSTRAINT children_reference_not_blank_chk
    CHECK (
      btrim(child_reference) <> ''
      AND child_reference = upper(btrim(child_reference))
    ),

  CONSTRAINT children_first_name_chk
    CHECK (
      first_name IS NULL
      OR (
        btrim(first_name) <> ''
        AND first_name = btrim(first_name)
      )
    ),

  CONSTRAINT children_archive_state_chk
    CHECK (
      (
        status = 'active'::public.child_status
        AND archived_at IS NULL
        AND archived_by IS NULL
      )
      OR
      (
        status = 'archived'::public.child_status
        AND archived_at IS NOT NULL
        AND archived_by IS NOT NULL
      )
    ),

  CONSTRAINT children_id_organization_id_key
    UNIQUE (id, organization_id),

  CONSTRAINT children_reference_organization_key
    UNIQUE (organization_id, child_reference),

  CONSTRAINT children_family_fk
    FOREIGN KEY (family_id, organization_id)
    REFERENCES public.families (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT children_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT children_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT children_archived_by_fk
    FOREIGN KEY (archived_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

CREATE INDEX children_family_idx
  ON public.children (organization_id, family_id);

CREATE INDEX children_active_family_idx
  ON public.children (organization_id, family_id, current_stage)
  WHERE status = 'active'::public.child_status;

-- ============================================================
-- 4. Memory profiles
-- ============================================================

CREATE TABLE public.memory_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  family_id uuid NOT NULL,
  child_id uuid,

  memory_goal text,
  story_notes text,
  emotional_tags text[] NOT NULL DEFAULT '{}',
  milestone_notes text,
  future_memory_notes text,

  is_active boolean NOT NULL DEFAULT true,

  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,

  archived_at timestamptz,
  archived_by uuid,

  CONSTRAINT memory_profiles_memory_goal_chk
    CHECK (
      memory_goal IS NULL
      OR (
        btrim(memory_goal) <> ''
        AND memory_goal = btrim(memory_goal)
      )
    ),

  CONSTRAINT memory_profiles_story_notes_chk
    CHECK (
      story_notes IS NULL
      OR (
        btrim(story_notes) <> ''
        AND story_notes = btrim(story_notes)
      )
    ),

  CONSTRAINT memory_profiles_milestone_notes_chk
    CHECK (
      milestone_notes IS NULL
      OR (
        btrim(milestone_notes) <> ''
        AND milestone_notes = btrim(milestone_notes)
      )
    ),

  CONSTRAINT memory_profiles_future_memory_notes_chk
    CHECK (
      future_memory_notes IS NULL
      OR (
        btrim(future_memory_notes) <> ''
        AND future_memory_notes = btrim(future_memory_notes)
      )
    ),

  CONSTRAINT memory_profiles_emotional_tags_no_null_chk
    CHECK (array_position(emotional_tags, NULL) IS NULL),

  CONSTRAINT memory_profiles_active_state_chk
    CHECK (
      (
        is_active = true
        AND archived_at IS NULL
        AND archived_by IS NULL
      )
      OR
      (
        is_active = false
        AND archived_at IS NOT NULL
        AND archived_by IS NOT NULL
      )
    ),

  CONSTRAINT memory_profiles_id_organization_id_key
    UNIQUE (id, organization_id),

  CONSTRAINT memory_profiles_family_fk
    FOREIGN KEY (family_id, organization_id)
    REFERENCES public.families (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT memory_profiles_child_fk
    FOREIGN KEY (child_id, organization_id)
    REFERENCES public.children (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT memory_profiles_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT memory_profiles_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT memory_profiles_archived_by_fk
    FOREIGN KEY (archived_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

-- One current family-level profile.
CREATE UNIQUE INDEX memory_profiles_active_family_idx
  ON public.memory_profiles (organization_id, family_id)
  WHERE child_id IS NULL
    AND is_active = true;

-- One current profile per child.
CREATE UNIQUE INDEX memory_profiles_active_child_idx
  ON public.memory_profiles (organization_id, child_id)
  WHERE child_id IS NOT NULL
    AND is_active = true;

CREATE INDEX memory_profiles_family_lookup_idx
  ON public.memory_profiles (organization_id, family_id);

-- ============================================================
-- 5. Generic updated_at triggers
-- ============================================================

CREATE TRIGGER children_set_updated_at
BEFORE UPDATE ON public.children
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER memory_profiles_set_updated_at
BEFORE UPDATE ON public.memory_profiles
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

-- ============================================================
-- 6. Child lifecycle guard
-- ============================================================

CREATE OR REPLACE FUNCTION public.lsh_children_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_family public.families;
  v_actor_member_id uuid;
  v_branch_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'children cannot be physically deleted';
  END IF;

  SELECT *
  INTO v_family
  FROM public.families
  WHERE id = NEW.family_id
    AND organization_id = NEW.organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family does not exist';
  END IF;

  IF v_family.status IN (
    'archived'::public.family_status,
    'merged'::public.family_status
  ) THEN
    RAISE EXCEPTION 'children cannot be changed for archived or merged families';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.organization_id <> OLD.organization_id THEN
      RAISE EXCEPTION 'organization_id is immutable';
    END IF;

    IF NEW.family_id <> OLD.family_id THEN
      RAISE EXCEPTION 'family_id is immutable';
    END IF;

    IF NEW.child_reference <> OLD.child_reference THEN
      RAISE EXCEPTION 'child_reference is immutable';
    END IF;

    v_branch_id := v_family.branch_id;

    v_actor_member_id :=
      public.current_organization_member(NEW.organization_id);

    IF v_actor_member_id IS NULL THEN
      RAISE EXCEPTION 'active organization member is required';
    END IF;

    IF NOT public.has_permission(
      NEW.organization_id,
      'memory.write',
      v_branch_id
    ) THEN
      RAISE EXCEPTION 'memory.write permission is required';
    END IF;

    NEW.updated_by := v_actor_member_id;

    IF OLD.status = 'active'::public.child_status
       AND NEW.status = 'archived'::public.child_status THEN
      NEW.archived_at := now();
      NEW.archived_by := v_actor_member_id;

    ELSIF OLD.status = 'archived'::public.child_status
          AND NEW.status = 'active'::public.child_status THEN
      NEW.archived_at := NULL;
      NEW.archived_by := NULL;

    ELSIF NEW.status = OLD.status THEN
      NEW.archived_at := OLD.archived_at;
      NEW.archived_by := OLD.archived_by;
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER children_lifecycle_guard
BEFORE UPDATE ON public.children
FOR EACH ROW
EXECUTE FUNCTION public.lsh_children_lifecycle_guard();

CREATE TRIGGER children_delete_guard
BEFORE DELETE ON public.children
FOR EACH ROW
EXECUTE FUNCTION public.lsh_children_lifecycle_guard();

-- ============================================================
-- 7. Memory-profile lifecycle guard
-- ============================================================

CREATE OR REPLACE FUNCTION public.lsh_memory_profiles_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_family public.families;
  v_child public.children;
  v_actor_member_id uuid;
  v_branch_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'memory profiles cannot be physically deleted';
  END IF;

  SELECT *
  INTO v_family
  FROM public.families
  WHERE id = NEW.family_id
    AND organization_id = NEW.organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family does not exist';
  END IF;

  IF v_family.status IN (
    'archived'::public.family_status,
    'merged'::public.family_status
  ) THEN
    RAISE EXCEPTION 'memory profiles cannot be changed for archived or merged families';
  END IF;

  IF NEW.child_id IS NOT NULL THEN
    SELECT *
    INTO v_child
    FROM public.children
    WHERE id = NEW.child_id
      AND organization_id = NEW.organization_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'child does not exist';
    END IF;

    IF v_child.family_id <> NEW.family_id THEN
      RAISE EXCEPTION 'child must belong to the same family as the memory profile';
    END IF;

    IF v_child.status = 'archived'::public.child_status THEN
      RAISE EXCEPTION 'archived children cannot receive memory profile changes';
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.organization_id <> OLD.organization_id THEN
      RAISE EXCEPTION 'organization_id is immutable';
    END IF;

    IF NEW.family_id <> OLD.family_id THEN
      RAISE EXCEPTION 'family_id is immutable';
    END IF;

    IF NEW.child_id IS DISTINCT FROM OLD.child_id THEN
      RAISE EXCEPTION 'child_id is immutable';
    END IF;

    v_branch_id := v_family.branch_id;

    v_actor_member_id :=
      public.current_organization_member(NEW.organization_id);

    IF v_actor_member_id IS NULL THEN
      RAISE EXCEPTION 'active organization member is required';
    END IF;

    IF NOT public.has_permission(
      NEW.organization_id,
      'memory.write',
      v_branch_id
    ) THEN
      RAISE EXCEPTION 'memory.write permission is required';
    END IF;

    NEW.updated_by := v_actor_member_id;

    IF OLD.is_active = true AND NEW.is_active = false THEN
      NEW.archived_at := now();
      NEW.archived_by := v_actor_member_id;

    ELSIF OLD.is_active = false AND NEW.is_active = true THEN
      NEW.archived_at := NULL;
      NEW.archived_by := NULL;

    ELSIF NEW.is_active = OLD.is_active THEN
      NEW.archived_at := OLD.archived_at;
      NEW.archived_by := OLD.archived_by;
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER memory_profiles_lifecycle_guard
BEFORE UPDATE ON public.memory_profiles
FOR EACH ROW
EXECUTE FUNCTION public.lsh_memory_profiles_lifecycle_guard();

CREATE TRIGGER memory_profiles_delete_guard
BEFORE DELETE ON public.memory_profiles
FOR EACH ROW
EXECUTE FUNCTION public.lsh_memory_profiles_lifecycle_guard();

-- ============================================================
-- 8. Controlled child creation
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_child(
  p_family_id uuid,
  p_first_name text,
  p_birth_date date,
  p_expected_due_date date,
  p_current_stage public.child_stage,
  p_privacy_restriction public.privacy_preference_type
)
RETURNS public.children
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_family public.families;
  v_actor_member_id uuid;
  v_organization_id uuid;
  v_branch_id uuid;
  v_child public.children;
  v_first_name text;
  v_reference text;
BEGIN
  IF p_family_id IS NULL THEN
    RAISE EXCEPTION 'family_id is required';
  END IF;

  SELECT *
  INTO v_family
  FROM public.families
  WHERE id = p_family_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family does not exist';
  END IF;

  IF v_family.status IN (
    'archived'::public.family_status,
    'merged'::public.family_status
  ) THEN
    RAISE EXCEPTION 'cannot create children for archived or merged families';
  END IF;

  v_organization_id := v_family.organization_id;
  v_branch_id := v_family.branch_id;

  v_actor_member_id :=
    public.current_organization_member(v_organization_id);

  IF v_actor_member_id IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NOT public.has_permission(
    v_organization_id,
    'memory.write',
    v_branch_id
  ) THEN
    RAISE EXCEPTION 'memory.write permission is required';
  END IF;

  v_first_name :=
    NULLIF(btrim(COALESCE(p_first_name, '')), '');

  LOOP
    v_reference :=
      'LSH-CH-' ||
      upper(
        substr(
          replace(gen_random_uuid()::text, '-', ''),
          1,
          8
        )
      );

    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.children
      WHERE organization_id = v_organization_id
        AND child_reference = v_reference
    );
  END LOOP;

  INSERT INTO public.children (
    organization_id,
    family_id,
    child_reference,
    first_name,
    birth_date,
    expected_due_date,
    current_stage,
    privacy_restriction,
    status,
    created_by,
    updated_by
  )
  VALUES (
    v_organization_id,
    p_family_id,
    v_reference,
    v_first_name,
    p_birth_date,
    p_expected_due_date,
    p_current_stage,
    p_privacy_restriction,
    'active'::public.child_status,
    v_actor_member_id,
    v_actor_member_id
  )
  RETURNING *
  INTO v_child;

  PERFORM public.append_audit_event(
    v_organization_id,
    v_branch_id,
    'memory.child.created',
    'child',
    v_child.id,
    false,
    NULL,
    NULL,
    jsonb_build_object(
      'family_id', v_child.family_id,
      'child_reference', v_child.child_reference,
      'current_stage', v_child.current_stage::text,
      'status', v_child.status::text,
      'privacy_restriction',
        CASE
          WHEN v_child.privacy_restriction IS NULL THEN NULL
          ELSE v_child.privacy_restriction::text
        END
    ),
    'application',
    gen_random_uuid()
  );

  RETURN v_child;
END
$$;

-- ============================================================
-- 9. Controlled child update/archive/reactivation
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_child(
  p_child_id uuid,
  p_first_name text,
  p_birth_date date,
  p_expected_due_date date,
  p_current_stage public.child_stage,
  p_privacy_restriction public.privacy_preference_type,
  p_status public.child_status
)
RETURNS public.children
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_existing public.children;
  v_family public.families;
  v_actor_member_id uuid;
  v_branch_id uuid;
  v_updated public.children;
  v_first_name text;
BEGIN
  IF p_child_id IS NULL THEN
    RAISE EXCEPTION 'child_id is required';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.children
  WHERE id = p_child_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'child does not exist';
  END IF;

  SELECT *
  INTO v_family
  FROM public.families
  WHERE id = v_existing.family_id
    AND organization_id = v_existing.organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family does not exist';
  END IF;

  IF v_family.status IN (
    'archived'::public.family_status,
    'merged'::public.family_status
  ) THEN
    RAISE EXCEPTION 'children cannot be changed for archived or merged families';
  END IF;

  v_branch_id := v_family.branch_id;

  v_actor_member_id :=
    public.current_organization_member(v_existing.organization_id);

  IF v_actor_member_id IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NOT public.has_permission(
    v_existing.organization_id,
    'memory.write',
    v_branch_id
  ) THEN
    RAISE EXCEPTION 'memory.write permission is required';
  END IF;

  v_first_name :=
    NULLIF(btrim(COALESCE(p_first_name, '')), '');

  UPDATE public.children
  SET
    first_name = v_first_name,
    birth_date = p_birth_date,
    expected_due_date = p_expected_due_date,
    current_stage = p_current_stage,
    privacy_restriction = p_privacy_restriction,
    status = COALESCE(p_status, status),
    updated_by = v_actor_member_id
  WHERE id = p_child_id
    AND organization_id = v_existing.organization_id
  RETURNING *
  INTO v_updated;

  PERFORM public.append_audit_event(
    v_existing.organization_id,
    v_branch_id,
    'memory.child.updated',
    'child',
    v_updated.id,
    false,
    NULL,
    jsonb_build_object(
      'family_id', v_existing.family_id,
      'first_name', v_existing.first_name,
      'birth_date', v_existing.birth_date,
      'expected_due_date', v_existing.expected_due_date,
      'current_stage',
        CASE
          WHEN v_existing.current_stage IS NULL THEN NULL
          ELSE v_existing.current_stage::text
        END,
      'privacy_restriction',
        CASE
          WHEN v_existing.privacy_restriction IS NULL THEN NULL
          ELSE v_existing.privacy_restriction::text
        END,
      'status', v_existing.status::text
    ),
    jsonb_build_object(
      'family_id', v_updated.family_id,
      'first_name', v_updated.first_name,
      'birth_date', v_updated.birth_date,
      'expected_due_date', v_updated.expected_due_date,
      'current_stage',
        CASE
          WHEN v_updated.current_stage IS NULL THEN NULL
          ELSE v_updated.current_stage::text
        END,
      'privacy_restriction',
        CASE
          WHEN v_updated.privacy_restriction IS NULL THEN NULL
          ELSE v_updated.privacy_restriction::text
        END,
      'status', v_updated.status::text
    ),
    'application',
    gen_random_uuid()
  );

  RETURN v_updated;
END
$$;

-- ============================================================
-- 10. Controlled memory-profile upsert
-- ============================================================

CREATE OR REPLACE FUNCTION public.upsert_memory_profile(
  p_family_id uuid,
  p_child_id uuid,
  p_memory_goal text,
  p_story_notes text,
  p_emotional_tags text[],
  p_milestone_notes text,
  p_future_memory_notes text
)
RETURNS public.memory_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_family public.families;
  v_child public.children;
  v_actor_member_id uuid;
  v_organization_id uuid;
  v_branch_id uuid;
  v_existing public.memory_profiles;
  v_profile public.memory_profiles;

  v_memory_goal text;
  v_story_notes text;
  v_milestone_notes text;
  v_future_memory_notes text;
  v_emotional_tags text[];
BEGIN
  IF p_family_id IS NULL THEN
    RAISE EXCEPTION 'family_id is required';
  END IF;

  SELECT *
  INTO v_family
  FROM public.families
  WHERE id = p_family_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family does not exist';
  END IF;

  IF v_family.status IN (
    'archived'::public.family_status,
    'merged'::public.family_status
  ) THEN
    RAISE EXCEPTION 'memory profiles cannot be changed for archived or merged families';
  END IF;

  v_organization_id := v_family.organization_id;
  v_branch_id := v_family.branch_id;

  v_actor_member_id :=
    public.current_organization_member(v_organization_id);

  IF v_actor_member_id IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NOT public.has_permission(
    v_organization_id,
    'memory.write',
    v_branch_id
  ) THEN
    RAISE EXCEPTION 'memory.write permission is required';
  END IF;

  IF p_child_id IS NOT NULL THEN
    SELECT *
    INTO v_child
    FROM public.children
    WHERE id = p_child_id
      AND organization_id = v_organization_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'child does not exist';
    END IF;

    IF v_child.family_id <> p_family_id THEN
      RAISE EXCEPTION 'child must belong to the selected family';
    END IF;

    IF v_child.status = 'archived'::public.child_status THEN
      RAISE EXCEPTION 'archived children cannot receive memory profile changes';
    END IF;
  END IF;

  v_memory_goal :=
    NULLIF(btrim(COALESCE(p_memory_goal, '')), '');

  v_story_notes :=
    NULLIF(btrim(COALESCE(p_story_notes, '')), '');

  v_milestone_notes :=
    NULLIF(btrim(COALESCE(p_milestone_notes, '')), '');

  v_future_memory_notes :=
    NULLIF(btrim(COALESCE(p_future_memory_notes, '')), '');

  SELECT COALESCE(
    array_agg(tag ORDER BY tag),
    ARRAY[]::text[]
  )
  INTO v_emotional_tags
  FROM (
    SELECT DISTINCT lower(btrim(value)) AS tag
    FROM unnest(COALESCE(p_emotional_tags, ARRAY[]::text[])) AS value
    WHERE btrim(value) <> ''
  ) normalized_tags;

  IF p_child_id IS NULL THEN
    SELECT *
    INTO v_existing
    FROM public.memory_profiles
    WHERE organization_id = v_organization_id
      AND family_id = p_family_id
      AND child_id IS NULL
      AND is_active = true;
  ELSE
    SELECT *
    INTO v_existing
    FROM public.memory_profiles
    WHERE organization_id = v_organization_id
      AND child_id = p_child_id
      AND is_active = true;
  END IF;

  IF FOUND THEN
    UPDATE public.memory_profiles
    SET
      memory_goal = v_memory_goal,
      story_notes = v_story_notes,
      emotional_tags = v_emotional_tags,
      milestone_notes = v_milestone_notes,
      future_memory_notes = v_future_memory_notes,
      updated_by = v_actor_member_id
    WHERE id = v_existing.id
      AND organization_id = v_organization_id
    RETURNING *
    INTO v_profile;

    PERFORM public.append_audit_event(
      v_organization_id,
      v_branch_id,
      'memory.profile.updated',
      'memory_profile',
      v_profile.id,
      false,
      NULL,
      jsonb_build_object(
        'family_id', v_existing.family_id,
        'child_id', v_existing.child_id,
        'memory_goal', v_existing.memory_goal,
        'emotional_tags', v_existing.emotional_tags
      ),
      jsonb_build_object(
        'family_id', v_profile.family_id,
        'child_id', v_profile.child_id,
        'memory_goal', v_profile.memory_goal,
        'emotional_tags', v_profile.emotional_tags
      ),
      'application',
      gen_random_uuid()
    );

  ELSE
    INSERT INTO public.memory_profiles (
      organization_id,
      family_id,
      child_id,
      memory_goal,
      story_notes,
      emotional_tags,
      milestone_notes,
      future_memory_notes,
      is_active,
      created_by,
      updated_by
    )
    VALUES (
      v_organization_id,
      p_family_id,
      p_child_id,
      v_memory_goal,
      v_story_notes,
      v_emotional_tags,
      v_milestone_notes,
      v_future_memory_notes,
      true,
      v_actor_member_id,
      v_actor_member_id
    )
    RETURNING *
    INTO v_profile;

    PERFORM public.append_audit_event(
      v_organization_id,
      v_branch_id,
      'memory.profile.created',
      'memory_profile',
      v_profile.id,
      false,
      NULL,
      NULL,
      jsonb_build_object(
        'family_id', v_profile.family_id,
        'child_id', v_profile.child_id,
        'memory_goal', v_profile.memory_goal,
        'emotional_tags', v_profile.emotional_tags
      ),
      'application',
      gen_random_uuid()
    );
  END IF;

  RETURN v_profile;
END
$$;

-- ============================================================
-- 11. RLS
-- ============================================================

ALTER TABLE public.children ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.children FORCE ROW LEVEL SECURITY;

ALTER TABLE public.memory_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_profiles FORCE ROW LEVEL SECURITY;

CREATE POLICY children_select_scoped
ON public.children
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    public.children.organization_id,
    'memory.read',
    (
      SELECT f.branch_id
      FROM public.families AS f
      WHERE f.id = public.children.family_id
        AND f.organization_id = public.children.organization_id
    )
  )
);

CREATE POLICY memory_profiles_select_scoped
ON public.memory_profiles
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    public.memory_profiles.organization_id,
    'memory.read',
    (
      SELECT f.branch_id
      FROM public.families AS f
      WHERE f.id = public.memory_profiles.family_id
        AND f.organization_id = public.memory_profiles.organization_id
    )
  )
);

-- ============================================================
-- 12. Table privileges
-- ============================================================

REVOKE ALL PRIVILEGES
ON TABLE public.children
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL PRIVILEGES
ON TABLE public.memory_profiles
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.children
TO authenticated;

GRANT SELECT
ON TABLE public.memory_profiles
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE public.children
TO service_role;

GRANT ALL PRIVILEGES
ON TABLE public.memory_profiles
TO service_role;

-- ============================================================
-- 13. RPC privileges
-- ============================================================

REVOKE ALL
ON FUNCTION public.create_child(
  uuid,
  text,
  date,
  date,
  public.child_stage,
  public.privacy_preference_type
)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.update_child(
  uuid,
  text,
  date,
  date,
  public.child_stage,
  public.privacy_preference_type,
  public.child_status
)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.upsert_memory_profile(
  uuid,
  uuid,
  text,
  text,
  text[],
  text,
  text
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.create_child(
  uuid,
  text,
  date,
  date,
  public.child_stage,
  public.privacy_preference_type
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.update_child(
  uuid,
  text,
  date,
  date,
  public.child_stage,
  public.privacy_preference_type,
  public.child_status
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.upsert_memory_profile(
  uuid,
  uuid,
  text,
  text,
  text[],
  text,
  text
)
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_children_lifecycle_guard()
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_memory_profiles_lifecycle_guard()
FROM PUBLIC, anon, authenticated, service_role;

-- ============================================================
-- 14. Validation
-- ============================================================

DO $validate$
DECLARE
  v_enum_count integer;
  v_table_count integer;
  v_rls_enabled boolean;
  v_force_rls boolean;
  v_authenticated_select boolean;
  v_authenticated_insert boolean;
  v_authenticated_update boolean;
  v_authenticated_delete boolean;
  v_permission_count integer;
  v_role_permission_count integer;
BEGIN
  SELECT count(*)
  INTO v_enum_count
  FROM pg_type t
  JOIN pg_enum e
    ON e.enumtypid = t.oid
  WHERE t.typnamespace = 'public'::regnamespace
    AND t.typname IN (
      'child_stage',
      'child_status',
      'privacy_preference_type'
    );

  IF v_enum_count <> 13 THEN
    RAISE EXCEPTION
      'Validation failed: expected 13 enum labels, got %',
      v_enum_count;
  END IF;

  SELECT count(*)
  INTO v_table_count
  FROM pg_class
  WHERE oid IN (
    'public.children'::regclass,
    'public.memory_profiles'::regclass
  )
    AND relkind = 'r';

  IF v_table_count <> 2 THEN
    RAISE EXCEPTION 'Validation failed: expected two foundation tables';
  END IF;

  SELECT relrowsecurity, relforcerowsecurity
  INTO v_rls_enabled, v_force_rls
  FROM pg_class
  WHERE oid = 'public.children'::regclass;

  IF v_rls_enabled IS DISTINCT FROM true
     OR v_force_rls IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Validation failed: children RLS is not fully enabled';
  END IF;

  SELECT relrowsecurity, relforcerowsecurity
  INTO v_rls_enabled, v_force_rls
  FROM pg_class
  WHERE oid = 'public.memory_profiles'::regclass;

  IF v_rls_enabled IS DISTINCT FROM true
     OR v_force_rls IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Validation failed: memory_profiles RLS is not fully enabled';
  END IF;

  SELECT has_table_privilege(
    'authenticated',
    'public.children',
    'SELECT'
  )
  INTO v_authenticated_select;

  SELECT has_table_privilege(
    'authenticated',
    'public.children',
    'INSERT'
  )
  INTO v_authenticated_insert;

  SELECT has_table_privilege(
    'authenticated',
    'public.children',
    'UPDATE'
  )
  INTO v_authenticated_update;

  SELECT has_table_privilege(
    'authenticated',
    'public.children',
    'DELETE'
  )
  INTO v_authenticated_delete;

  IF v_authenticated_select IS DISTINCT FROM true
     OR v_authenticated_insert IS DISTINCT FROM false
     OR v_authenticated_update IS DISTINCT FROM false
     OR v_authenticated_delete IS DISTINCT FROM false THEN
    RAISE EXCEPTION
      'Validation failed: unexpected authenticated children privileges';
  END IF;

  SELECT count(*)
  INTO v_permission_count
  FROM public.permissions;

  SELECT count(*)
  INTO v_role_permission_count
  FROM public.role_permissions;

  IF v_permission_count <> (
    SELECT permission_count
    FROM migration_permission_snapshot
  ) THEN
    RAISE EXCEPTION
      'Validation failed: permission catalogue changed unexpectedly';
  END IF;

  IF v_role_permission_count <> (
    SELECT role_permission_count
    FROM migration_permission_snapshot
  ) THEN
    RAISE EXCEPTION
      'Validation failed: role-permission map changed unexpectedly';
  END IF;

  IF to_regprocedure(
    'public.create_child(uuid,text,date,date,public.child_stage,public.privacy_preference_type)'
  ) IS NULL THEN
    RAISE EXCEPTION 'Validation failed: create_child RPC is missing';
  END IF;

  IF to_regprocedure(
    'public.update_child(uuid,text,date,date,public.child_stage,public.privacy_preference_type,public.child_status)'
  ) IS NULL THEN
    RAISE EXCEPTION 'Validation failed: update_child RPC is missing';
  END IF;

  IF to_regprocedure(
    'public.upsert_memory_profile(uuid,uuid,text,text,text[],text,text)'
  ) IS NULL THEN
    RAISE EXCEPTION 'Validation failed: upsert_memory_profile RPC is missing';
  END IF;
END
$validate$;

COMMIT;