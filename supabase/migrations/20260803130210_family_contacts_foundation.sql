BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '180s';

CREATE TEMP TABLE migration_permission_snapshot ON COMMIT DROP AS
SELECT
  (SELECT count(*) FROM public.permissions) AS permission_count,
  (SELECT count(*) FROM public.role_permissions) AS role_permission_count;

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

  IF to_regprocedure('public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.append_audit_event(...) is missing';
  END IF;

  IF to_regprocedure('extensions.gen_random_bytes(integer)') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: pgcrypto gen_random_bytes is missing';
  END IF;

  IF to_regtype('public.family_status') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.family_status is missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'contact_channel_type'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.contact_channel_type already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'contactability_status'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.contactability_status already exists';
  END IF;

  IF to_regclass('public.family_contacts') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.family_contacts already exists';
  END IF;

  IF to_regclass('public.family_contact_channels') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.family_contact_channels already exists';
  END IF;

  IF to_regclass('public.family_communication_controls') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.family_communication_controls already exists';
  END IF;

  IF to_regprocedure('public.create_family_contact(uuid,text,text,boolean)') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.create_family_contact already exists';
  END IF;

  IF to_regprocedure('public.add_family_contact_channel(uuid,public.contact_channel_type,text,boolean)') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.add_family_contact_channel already exists';
  END IF;

  IF to_regprocedure('public.update_family_communication_controls(uuid,public.contactability_status,boolean,text,public.contact_channel_type,time,time)') IS NOT NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.update_family_communication_controls already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.branches'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (id, organization_id)'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.branches UNIQUE (id, organization_id) is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.organization_members'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (id, organization_id)'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.organization_members UNIQUE (id, organization_id) is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.families'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (id, organization_id)'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.families UNIQUE (id, organization_id) is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname IN ('authenticated', 'anon', 'service_role')
  ) THEN
    RAISE EXCEPTION 'Precondition failed: required roles are missing';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.permissions
  WHERE key IN ('family.contact.read', 'family.contact.write', 'family.communication.write');

  IF v_count <> 3 THEN
    RAISE EXCEPTION 'Precondition failed: required family permissions are missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'family_status'
      AND e.enumlabel IN ('active', 'inactive', 'archived', 'merged')
  ) THEN
    RAISE EXCEPTION 'Precondition failed: family_status values are missing';
  END IF;
END
$pre$;

CREATE TYPE public.contact_channel_type AS ENUM (
  'phone',
  'email',
  'whatsapp',
  'other'
);

CREATE TYPE public.contactability_status AS ENUM (
  'contactable',
  'limited',
  'do_not_contact'
);

CREATE TABLE public.family_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  family_id uuid NOT NULL,
  full_name text NOT NULL,
  relationship_label text NOT NULL,
  is_primary boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,
  deactivated_at timestamptz,
  deactivated_by uuid,

  CONSTRAINT family_contacts_full_name_not_blank_chk
    CHECK (btrim(full_name) <> '' AND full_name = btrim(full_name)),
  CONSTRAINT family_contacts_relationship_label_not_blank_chk
    CHECK (btrim(relationship_label) <> '' AND relationship_label = lower(btrim(relationship_label))),
  CONSTRAINT family_contacts_active_state_chk
    CHECK (
      (is_active = false AND deactivated_at IS NOT NULL AND deactivated_by IS NOT NULL)
      OR
      (is_active = true AND deactivated_at IS NULL AND deactivated_by IS NULL)
    ),
  CONSTRAINT family_contacts_id_organization_id_key UNIQUE (id, organization_id),
  CONSTRAINT family_contacts_family_fk
    FOREIGN KEY (family_id, organization_id)
    REFERENCES public.families (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_contacts_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_contacts_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_contacts_deactivated_by_fk
    FOREIGN KEY (deactivated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

CREATE TABLE public.family_contact_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  family_contact_id uuid NOT NULL,
  channel_type public.contact_channel_type NOT NULL,
  channel_value text NOT NULL,
  normalized_value text NOT NULL,
  is_preferred boolean NOT NULL DEFAULT false,
  is_verified boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,
  deactivated_at timestamptz,
  deactivated_by uuid,

  CONSTRAINT family_contact_channels_channel_value_not_blank_chk
    CHECK (btrim(channel_value) <> '' AND channel_value = btrim(channel_value)),
  CONSTRAINT family_contact_channels_normalized_value_not_blank_chk
    CHECK (btrim(normalized_value) <> '' AND normalized_value = btrim(normalized_value)),
  CONSTRAINT family_contact_channels_email_normalized_chk
    CHECK (
      (channel_type <> 'email'::public.contact_channel_type)
      OR (normalized_value = lower(normalized_value))
    ),
  CONSTRAINT family_contact_channels_phone_normalized_chk
    CHECK (
      (channel_type NOT IN ('phone'::public.contact_channel_type, 'whatsapp'::public.contact_channel_type))
      OR normalized_value ~ '^\+[0-9]+$'
    ),
  CONSTRAINT family_contact_channels_active_state_chk
    CHECK (
      (is_active = false AND deactivated_at IS NOT NULL AND deactivated_by IS NOT NULL)
      OR
      (is_active = true AND deactivated_at IS NULL AND deactivated_by IS NULL)
    ),
  CONSTRAINT family_contact_channels_id_organization_id_key UNIQUE (id, organization_id),
  CONSTRAINT family_contact_channels_family_contact_fk
    FOREIGN KEY (family_contact_id, organization_id)
    REFERENCES public.family_contacts (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_contact_channels_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_contact_channels_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_contact_channels_deactivated_by_fk
    FOREIGN KEY (deactivated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

CREATE TABLE public.family_communication_controls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  family_id uuid NOT NULL,
  contactability_status public.contactability_status NOT NULL DEFAULT 'contactable',
  preferred_channel_type public.contact_channel_type,
  do_not_contact boolean NOT NULL DEFAULT false,
  do_not_contact_reason text,
  quiet_hours_start time,
  quiet_hours_end time,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,

  CONSTRAINT family_communication_controls_do_not_contact_chk
    CHECK (
      (do_not_contact = false AND do_not_contact_reason IS NULL)
      OR
      (do_not_contact = true AND do_not_contact_reason IS NOT NULL AND btrim(do_not_contact_reason) <> '')
    ),
  CONSTRAINT family_communication_controls_contactability_chk
    CHECK (
      (contactability_status = 'do_not_contact'::public.contactability_status AND do_not_contact = true)
      OR
      (contactability_status <> 'do_not_contact'::public.contactability_status AND do_not_contact = false)
    ),
  CONSTRAINT family_communication_controls_quiet_hours_chk
    CHECK (
      (quiet_hours_start IS NULL AND quiet_hours_end IS NULL)
      OR
      (quiet_hours_start IS NOT NULL AND quiet_hours_end IS NOT NULL)
    ),
  CONSTRAINT family_communication_controls_timezone_chk
    CHECK (btrim(timezone) <> '' AND timezone = btrim(timezone)),
  CONSTRAINT family_communication_controls_id_organization_id_key UNIQUE (id, organization_id),
  CONSTRAINT family_communication_controls_organization_family_key UNIQUE (organization_id, family_id),
  CONSTRAINT family_communication_controls_family_fk
    FOREIGN KEY (family_id, organization_id)
    REFERENCES public.families (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_communication_controls_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  CONSTRAINT family_communication_controls_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

CREATE UNIQUE INDEX family_contacts_active_primary_idx
  ON public.family_contacts (family_id, organization_id)
  WHERE is_primary = true AND is_active = true;

CREATE UNIQUE INDEX family_contact_channels_active_preferred_idx
  ON public.family_contact_channels (family_contact_id, organization_id)
  WHERE is_preferred = true AND is_active = true;

CREATE OR REPLACE FUNCTION public.lsh_family_contacts_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_family_status public.family_status;
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION 'direct writes to family_contacts are not permitted';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'direct deletes from family_contacts are not permitted';
  END IF;

  IF NEW.organization_id IS NULL OR NEW.family_id IS NULL THEN
    RAISE EXCEPTION 'organization_id and family_id are required';
  END IF;

  IF NEW.created_by IS NULL OR NEW.updated_by IS NULL THEN
    RAISE EXCEPTION 'actor ids are required';
  END IF;

  v_actor := public.current_organization_member(NEW.organization_id);
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NEW.created_by IS DISTINCT FROM v_actor OR NEW.updated_by IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'created_by and updated_by must reference the current active member';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.family_id IS DISTINCT FROM OLD.family_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
      RAISE EXCEPTION 'family contact identity and creation metadata are immutable';
    END IF;
  END IF;

  SELECT status
  INTO v_family_status
  FROM public.families
  WHERE id = NEW.family_id
    AND organization_id = NEW.organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family is missing for the provided organization';
  END IF;

  IF v_family_status IN ('archived'::public.family_status, 'merged'::public.family_status)
     AND NEW.is_active = true THEN
    RAISE EXCEPTION 'active family contacts cannot be created for archived or merged families';
  END IF;

  IF NEW.is_active = false AND (NEW.deactivated_at IS NULL OR NEW.deactivated_by IS NULL) THEN
    RAISE EXCEPTION 'inactive contacts require deactivation metadata';
  END IF;

  IF NEW.is_active = true AND (NEW.deactivated_at IS NOT NULL OR NEW.deactivated_by IS NOT NULL) THEN
    RAISE EXCEPTION 'active contacts must not carry deactivation metadata';
  END IF;

  IF NEW.is_primary = true AND v_family_status IN ('archived'::public.family_status, 'merged'::public.family_status) THEN
    RAISE EXCEPTION 'active primary contacts cannot be assigned for archived or merged families';
  END IF;

  RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION public.lsh_family_contact_channels_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_contact public.family_contacts;
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION 'direct writes to family_contact_channels are not permitted';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'direct deletes from family_contact_channels are not permitted';
  END IF;

  IF NEW.organization_id IS NULL OR NEW.family_contact_id IS NULL THEN
    RAISE EXCEPTION 'organization_id and family_contact_id are required';
  END IF;

  IF NEW.created_by IS NULL OR NEW.updated_by IS NULL THEN
    RAISE EXCEPTION 'actor ids are required';
  END IF;

  v_actor := public.current_organization_member(NEW.organization_id);
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NEW.created_by IS DISTINCT FROM v_actor OR NEW.updated_by IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'created_by and updated_by must reference the current active member';
  END IF;

  SELECT *
  INTO v_contact
  FROM public.family_contacts
  WHERE id = NEW.family_contact_id
    AND organization_id = NEW.organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family contact is missing for the provided organization';
  END IF;

  IF v_contact.is_active = false AND NEW.is_active = true THEN
    RAISE EXCEPTION 'an active channel cannot belong to an inactive contact';
  END IF;

  IF NEW.is_active = false AND (NEW.deactivated_at IS NULL OR NEW.deactivated_by IS NULL) THEN
    RAISE EXCEPTION 'inactive channels require deactivation metadata';
  END IF;

  IF NEW.is_active = true AND (NEW.deactivated_at IS NOT NULL OR NEW.deactivated_by IS NOT NULL) THEN
    RAISE EXCEPTION 'active channels must not carry deactivation metadata';
  END IF;

  RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION public.lsh_family_communication_controls_lifecycle_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_family public.families;
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION 'direct writes to family_communication_controls are not permitted';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'direct deletes from family_communication_controls are not permitted';
  END IF;

  IF NEW.organization_id IS NULL OR NEW.family_id IS NULL THEN
    RAISE EXCEPTION 'organization_id and family_id are required';
  END IF;

  IF NEW.created_by IS NULL OR NEW.updated_by IS NULL THEN
    RAISE EXCEPTION 'actor ids are required';
  END IF;

  v_actor := public.current_organization_member(NEW.organization_id);
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NEW.created_by IS DISTINCT FROM v_actor OR NEW.updated_by IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'created_by and updated_by must reference the current active member';
  END IF;

  SELECT *
  INTO v_family
  FROM public.families
  WHERE id = NEW.family_id
    AND organization_id = NEW.organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family is missing for the provided organization';
  END IF;

  IF v_family.status IN ('archived'::public.family_status, 'merged'::public.family_status) THEN
    RAISE EXCEPTION 'communication controls cannot be maintained for archived or merged families';
  END IF;

  IF NEW.do_not_contact = true AND NEW.contactability_status <> 'do_not_contact'::public.contactability_status THEN
    RAISE EXCEPTION 'do_not_contact requires contactability_status = do_not_contact';
  END IF;

  IF NEW.contactability_status = 'do_not_contact'::public.contactability_status AND NEW.do_not_contact = false THEN
    RAISE EXCEPTION 'do_not_contact_status requires do_not_contact=true';
  END IF;

  IF NEW.do_not_contact = true AND (NEW.do_not_contact_reason IS NULL OR btrim(NEW.do_not_contact_reason) = '') THEN
    RAISE EXCEPTION 'do_not_contact_reason is required when do_not_contact=true';
  END IF;

  IF NEW.do_not_contact = false AND NEW.do_not_contact_reason IS NOT NULL THEN
    RAISE EXCEPTION 'do_not_contact_reason must be null when do_not_contact=false';
  END IF;

  IF (NEW.quiet_hours_start IS NULL) IS DISTINCT FROM (NEW.quiet_hours_end IS NULL) THEN
    RAISE EXCEPTION 'quiet hours must be both null or both non-null';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER family_contacts_set_updated_at
BEFORE INSERT OR UPDATE ON public.family_contacts
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER family_contacts_lifecycle_guard
BEFORE INSERT OR UPDATE ON public.family_contacts
FOR EACH ROW
EXECUTE FUNCTION public.lsh_family_contacts_lifecycle_guard();

CREATE TRIGGER family_contacts_delete_guard
BEFORE DELETE ON public.family_contacts
FOR EACH ROW
EXECUTE FUNCTION public.lsh_family_contacts_lifecycle_guard();

CREATE TRIGGER family_contact_channels_set_updated_at
BEFORE INSERT OR UPDATE ON public.family_contact_channels
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER family_contact_channels_lifecycle_guard
BEFORE INSERT OR UPDATE ON public.family_contact_channels
FOR EACH ROW
EXECUTE FUNCTION public.lsh_family_contact_channels_lifecycle_guard();

CREATE TRIGGER family_contact_channels_delete_guard
BEFORE DELETE ON public.family_contact_channels
FOR EACH ROW
EXECUTE FUNCTION public.lsh_family_contact_channels_lifecycle_guard();

CREATE TRIGGER family_communication_controls_set_updated_at
BEFORE INSERT OR UPDATE ON public.family_communication_controls
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER family_communication_controls_lifecycle_guard
BEFORE INSERT OR UPDATE ON public.family_communication_controls
FOR EACH ROW
EXECUTE FUNCTION public.lsh_family_communication_controls_lifecycle_guard();

CREATE TRIGGER family_communication_controls_delete_guard
BEFORE DELETE ON public.family_communication_controls
FOR EACH ROW
EXECUTE FUNCTION public.lsh_family_communication_controls_lifecycle_guard();

CREATE OR REPLACE FUNCTION public.create_family_contact(
  p_family_id uuid,
  p_full_name text,
  p_relationship_label text,
  p_is_primary boolean DEFAULT false
)
RETURNS public.family_contacts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_family public.families;
  v_actor_member_id uuid;
  v_organization_id uuid;
  v_branch_id uuid;
  v_contact public.family_contacts;
  v_normalized_relationship_label text;
  v_primary boolean;
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

  IF v_family.status IN ('archived'::public.family_status, 'merged'::public.family_status) THEN
    RAISE EXCEPTION 'cannot create contacts for archived or merged families';
  END IF;

  v_organization_id := v_family.organization_id;
  v_branch_id := v_family.branch_id;

  v_actor_member_id := public.current_organization_member(v_organization_id);
  IF v_actor_member_id IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NOT public.has_permission(v_organization_id, 'family.contact.write', v_branch_id) THEN
    RAISE EXCEPTION 'family.contact.write permission is required';
  END IF;

  v_normalized_relationship_label := lower(btrim(p_relationship_label));
  IF btrim(p_full_name) = '' OR btrim(p_full_name) <> p_full_name THEN
    RAISE EXCEPTION 'full_name must be trimmed and non-blank';
  END IF;

  IF v_normalized_relationship_label = '' THEN
    RAISE EXCEPTION 'relationship_label must be a non-blank normalized value';
  END IF;

  v_primary := COALESCE(p_is_primary, false);

  INSERT INTO public.family_contacts (
    organization_id,
    family_id,
    full_name,
    relationship_label,
    is_primary,
    is_active,
    created_by,
    updated_by
  )
  VALUES (
    v_organization_id,
    p_family_id,
    btrim(p_full_name),
    v_normalized_relationship_label,
    v_primary,
    true,
    v_actor_member_id,
    v_actor_member_id
  )
  RETURNING *
  INTO v_contact;

  IF v_primary = true THEN
    UPDATE public.family_contacts
    SET is_primary = false,
        updated_at = now(),
        updated_by = v_actor_member_id
    WHERE family_id = p_family_id
      AND organization_id = v_organization_id
      AND id <> v_contact.id
      AND is_active = true
      AND is_primary = true;
  END IF;

  PERFORM public.append_audit_event(
    v_organization_id,
    v_branch_id,
    'family.contact.created',
    'family_contact',
    v_contact.id,
    false,
    NULL,
    jsonb_build_object(
      'family_id', p_family_id,
      'is_primary', v_primary,
      'is_active', true,
      'organization_id', v_organization_id
    ),
    jsonb_build_object(
      'family_id', p_family_id,
      'is_primary', v_primary,
      'is_active', true,
      'organization_id', v_organization_id
    ),
    'application',
    gen_random_uuid()
  );

  RETURN v_contact;
END
$$;

CREATE OR REPLACE FUNCTION public.add_family_contact_channel(
  p_family_contact_id uuid,
  p_channel_type public.contact_channel_type,
  p_channel_value text,
  p_is_preferred boolean DEFAULT false
)
RETURNS public.family_contact_channels
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_contact public.family_contacts;
  v_actor_member_id uuid;
  v_organization_id uuid;
  v_branch_id uuid;
  v_channel public.family_contact_channels;
  v_normalized_value text;
  v_preferred boolean;
BEGIN
  IF p_family_contact_id IS NULL THEN
    RAISE EXCEPTION 'family_contact_id is required';
  END IF;

  SELECT *
  INTO v_contact
  FROM public.family_contacts
  WHERE id = p_family_contact_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family contact does not exist';
  END IF;

  IF v_contact.is_active = false THEN
    RAISE EXCEPTION 'inactive contacts cannot receive new channels';
  END IF;

  v_organization_id := v_contact.organization_id;
  SELECT branch_id
  INTO v_branch_id
  FROM public.families
  WHERE id = v_contact.family_id
    AND organization_id = v_organization_id;

  v_actor_member_id := public.current_organization_member(v_organization_id);
  IF v_actor_member_id IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NOT public.has_permission(v_organization_id, 'family.contact.write', v_branch_id) THEN
    RAISE EXCEPTION 'family.contact.write permission is required';
  END IF;

  v_preferred := COALESCE(p_is_preferred, false);

  v_normalized_value := btrim(p_channel_value);
  IF v_normalized_value = '' THEN
    RAISE EXCEPTION 'channel_value must be non-blank';
  END IF;

  IF p_channel_type = 'email'::public.contact_channel_type THEN
    v_normalized_value := lower(v_normalized_value);
  ELSIF p_channel_type IN ('phone'::public.contact_channel_type, 'whatsapp'::public.contact_channel_type) THEN
    IF v_normalized_value !~ '^\+[0-9]+$' THEN
      RAISE EXCEPTION 'phone and whatsapp channels must use a leading + followed by digits';
    END IF;
  END IF;

  INSERT INTO public.family_contact_channels (
    organization_id,
    family_contact_id,
    channel_type,
    channel_value,
    normalized_value,
    is_preferred,
    is_verified,
    is_active,
    created_by,
    updated_by
  )
  VALUES (
    v_organization_id,
    p_family_contact_id,
    p_channel_type,
    btrim(p_channel_value),
    v_normalized_value,
    v_preferred,
    false,
    true,
    v_actor_member_id,
    v_actor_member_id
  )
  RETURNING *
  INTO v_channel;

  IF v_preferred = true THEN
    UPDATE public.family_contact_channels
    SET is_preferred = false,
        updated_at = now(),
        updated_by = v_actor_member_id
    WHERE family_contact_id = p_family_contact_id
      AND organization_id = v_organization_id
      AND id <> v_channel.id
      AND is_active = true
      AND is_preferred = true;
  END IF;

  PERFORM public.append_audit_event(
    v_organization_id,
    v_branch_id,
    'family.contact_channel.created',
    'family_contact_channel',
    v_channel.id,
    false,
    NULL,
    jsonb_build_object(
      'family_contact_id', p_family_contact_id,
      'channel_type', p_channel_type::text,
      'is_preferred', v_preferred,
      'is_active', true,
      'is_verified', false
    ),
    jsonb_build_object(
      'family_contact_id', p_family_contact_id,
      'channel_type', p_channel_type::text,
      'is_preferred', v_preferred,
      'is_active', true,
      'is_verified', false
    ),
    'application',
    gen_random_uuid()
  );

  RETURN v_channel;
END
$$;

CREATE OR REPLACE FUNCTION public.update_family_communication_controls(
  p_family_id uuid,
  p_contactability_status public.contactability_status,
  p_do_not_contact boolean,
  p_do_not_contact_reason text,
  p_preferred_channel_type public.contact_channel_type,
  p_quiet_hours_start time,
  p_quiet_hours_end time
)
RETURNS public.family_communication_controls
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_family public.families;
  v_actor_member_id uuid;
  v_organization_id uuid;
  v_branch_id uuid;
  v_controls public.family_communication_controls;
  v_do_not_contact boolean;
  v_reason text;
  v_contactability_status public.contactability_status;
  v_preferred_channel_type public.contact_channel_type;
  v_quiet_hours_start time;
  v_quiet_hours_end time;
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

  IF v_family.status IN ('archived'::public.family_status, 'merged'::public.family_status) THEN
    RAISE EXCEPTION 'communication controls cannot be updated for archived or merged families';
  END IF;

  v_organization_id := v_family.organization_id;
  v_branch_id := v_family.branch_id;

  v_actor_member_id := public.current_organization_member(v_organization_id);
  IF v_actor_member_id IS NULL THEN
    RAISE EXCEPTION 'active organization member is required';
  END IF;

  IF NOT public.has_permission(v_organization_id, 'family.communication.write', v_branch_id) THEN
    RAISE EXCEPTION 'family.communication.write permission is required';
  END IF;

  v_do_not_contact := COALESCE(p_do_not_contact, false);
  v_contactability_status := COALESCE(p_contactability_status, 'contactable'::public.contactability_status);
  v_reason := NULLIF(btrim(COALESCE(p_do_not_contact_reason, '')), '');
  v_preferred_channel_type := p_preferred_channel_type;
  v_quiet_hours_start := p_quiet_hours_start;
  v_quiet_hours_end := p_quiet_hours_end;

  IF v_do_not_contact = true AND v_contactability_status <> 'do_not_contact'::public.contactability_status THEN
    v_contactability_status := 'do_not_contact'::public.contactability_status;
  END IF;

  IF v_contactability_status = 'do_not_contact'::public.contactability_status AND v_do_not_contact = false THEN
    v_do_not_contact := true;
  END IF;

  IF v_do_not_contact = true AND v_reason IS NULL THEN
    RAISE EXCEPTION 'do_not_contact_reason is required when do_not_contact=true';
  END IF;

  IF v_do_not_contact = false THEN
    v_reason := NULL;
  END IF;

  IF (v_quiet_hours_start IS NULL) IS DISTINCT FROM (v_quiet_hours_end IS NULL) THEN
    RAISE EXCEPTION 'quiet hours must be both null or both non-null';
  END IF;

  INSERT INTO public.family_communication_controls (
    organization_id,
    family_id,
    contactability_status,
    preferred_channel_type,
    do_not_contact,
    do_not_contact_reason,
    quiet_hours_start,
    quiet_hours_end,
    timezone,
    created_by,
    updated_by
  )
  VALUES (
    v_organization_id,
    p_family_id,
    v_contactability_status,
    v_preferred_channel_type,
    v_do_not_contact,
    v_reason,
    v_quiet_hours_start,
    v_quiet_hours_end,
    'Asia/Kolkata',
    v_actor_member_id,
    v_actor_member_id
  )
  ON CONFLICT (organization_id, family_id)
  DO UPDATE SET
    contactability_status = EXCLUDED.contactability_status,
    preferred_channel_type = EXCLUDED.preferred_channel_type,
    do_not_contact = EXCLUDED.do_not_contact,
    do_not_contact_reason = EXCLUDED.do_not_contact_reason,
    quiet_hours_start = EXCLUDED.quiet_hours_start,
    quiet_hours_end = EXCLUDED.quiet_hours_end,
    updated_at = now(),
    updated_by = v_actor_member_id
  RETURNING *
  INTO v_controls;

  PERFORM public.append_audit_event(
    v_organization_id,
    v_branch_id,
    'family.communication_controls.updated',
    'family_communication_controls',
    v_controls.id,
    false,
    NULL,
    jsonb_build_object(
      'contactability_status', v_contactability_status::text,
      'do_not_contact', v_do_not_contact,
      'preferred_channel_type', v_preferred_channel_type::text
    ),
    jsonb_build_object(
      'contactability_status', v_contactability_status::text,
      'do_not_contact', v_do_not_contact,
      'preferred_channel_type', v_preferred_channel_type::text
    ),
    'application',
    gen_random_uuid()
  );

  RETURN v_controls;
END
$$;

ALTER TABLE public.family_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_contacts FORCE ROW LEVEL SECURITY;

ALTER TABLE public.family_contact_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_contact_channels FORCE ROW LEVEL SECURITY;

ALTER TABLE public.family_communication_controls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_communication_controls FORCE ROW LEVEL SECURITY;

CREATE POLICY family_contacts_select_scoped
ON public.family_contacts
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    public.family_contacts.organization_id,
    'family.contact.read',
    (
      SELECT f.branch_id
      FROM public.families AS f
      WHERE f.id = public.family_contacts.family_id
        AND f.organization_id = public.family_contacts.organization_id
    )
  )
);

CREATE POLICY family_contact_channels_select_scoped
ON public.family_contact_channels
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    public.family_contact_channels.organization_id,
    'family.contact.read',
    (
      SELECT f.branch_id
      FROM public.families AS f
      JOIN public.family_contacts AS fc
        ON fc.id = public.family_contact_channels.family_contact_id
       AND fc.organization_id = public.family_contact_channels.organization_id
      WHERE f.id = fc.family_id
        AND f.organization_id = fc.organization_id
    )
  )
);

CREATE POLICY family_communication_controls_select_scoped
ON public.family_communication_controls
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    public.family_communication_controls.organization_id,
    'family.contact.read',
    (
      SELECT f.branch_id
      FROM public.families AS f
      WHERE f.id = public.family_communication_controls.family_id
        AND f.organization_id = public.family_communication_controls.organization_id
    )
  )
);

REVOKE ALL PRIVILEGES
ON TABLE public.family_contacts
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL PRIVILEGES
ON TABLE public.family_contact_channels
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL PRIVILEGES
ON TABLE public.family_communication_controls
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.family_contacts
TO authenticated;

GRANT SELECT
ON TABLE public.family_contact_channels
TO authenticated;

GRANT SELECT
ON TABLE public.family_communication_controls
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE public.family_contacts
TO service_role;

GRANT ALL PRIVILEGES
ON TABLE public.family_contact_channels
TO service_role;

GRANT ALL PRIVILEGES
ON TABLE public.family_communication_controls
TO service_role;

REVOKE ALL
ON FUNCTION public.create_family_contact(uuid, text, text, boolean)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.add_family_contact_channel(uuid, public.contact_channel_type, text, boolean)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.update_family_communication_controls(uuid, public.contactability_status, boolean, text, public.contact_channel_type, time, time)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.create_family_contact(uuid, text, text, boolean)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.add_family_contact_channel(uuid, public.contact_channel_type, text, boolean)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.update_family_communication_controls(uuid, public.contactability_status, boolean, text, public.contact_channel_type, time, time)
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_family_contacts_lifecycle_guard()
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_family_contact_channels_lifecycle_guard()
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_family_communication_controls_lifecycle_guard()
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_set_updated_at()
FROM PUBLIC, anon, authenticated, service_role;

DO $$
DECLARE
  v_enum_count integer;
  v_contact_channel_labels text[] := ARRAY['phone', 'email', 'whatsapp', 'other'];
  v_contactability_labels text[] := ARRAY['contactable', 'limited', 'do_not_contact'];
  v_column_count integer;
  v_fk_count integer;
  v_trigger_count integer;
  v_primary_index_count integer;
  v_preferred_index_count integer;
  v_rls_enabled boolean;
  v_force_rls boolean;
  v_policy_count integer;
  v_authenticated_select boolean;
  v_authenticated_insert boolean;
  v_authenticated_update boolean;
  v_authenticated_delete boolean;
  v_service_select boolean;
  v_service_insert boolean;
  v_service_update boolean;
  v_service_delete boolean;
  v_contact_count integer;
  v_channel_count integer;
  v_control_count integer;
  v_permission_count integer;
  v_role_permission_count integer;
BEGIN
  SELECT count(*) INTO v_enum_count
  FROM pg_type t
  JOIN pg_enum e ON e.enumtypid = t.oid
  WHERE t.typnamespace = 'public'::regnamespace
    AND t.typname IN ('contact_channel_type', 'contactability_status');

  IF v_enum_count <> 7 THEN
    RAISE EXCEPTION 'Validation failed: unexpected enum count %', v_enum_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'contact_channel_type'
      AND e.enumlabel = ANY (v_contact_channel_labels)
  ) THEN
    RAISE EXCEPTION 'Validation failed: contact_channel_type labels are incomplete';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'contactability_status'
      AND e.enumlabel = ANY (v_contactability_labels)
  ) THEN
    RAISE EXCEPTION 'Validation failed: contactability_status labels are incomplete';
  END IF;

  IF to_regclass('public.family_contacts') IS NULL
     OR to_regclass('public.family_contact_channels') IS NULL
     OR to_regclass('public.family_communication_controls') IS NULL THEN
    RAISE EXCEPTION 'Validation failed: expected family-contact tables are missing';
  END IF;

  SELECT count(*) INTO v_column_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'family_contacts';
  IF v_column_count <> 13 THEN
    RAISE EXCEPTION 'Validation failed: family_contacts columns %', v_column_count;
  END IF;

  SELECT count(*) INTO v_column_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'family_contact_channels';
  IF v_column_count <> 15 THEN
    RAISE EXCEPTION 'Validation failed: family_contact_channels columns %', v_column_count;
  END IF;

  SELECT count(*) INTO v_column_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'family_communication_controls';
  IF v_column_count <> 15 THEN
    RAISE EXCEPTION 'Validation failed: family_communication_controls columns %', v_column_count;
  END IF;

  SELECT count(*) INTO v_fk_count
  FROM pg_constraint
  WHERE conrelid = 'public.family_contacts'::regclass
    AND contype = 'f';
  IF v_fk_count <> 4 THEN
    RAISE EXCEPTION 'Validation failed: family_contacts foreign keys %', v_fk_count;
  END IF;

  SELECT count(*) INTO v_fk_count
  FROM pg_constraint
  WHERE conrelid = 'public.family_contact_channels'::regclass
    AND contype = 'f';
  IF v_fk_count <> 4 THEN
    RAISE EXCEPTION 'Validation failed: family_contact_channels foreign keys %', v_fk_count;
  END IF;

  SELECT count(*) INTO v_fk_count
  FROM pg_constraint
  WHERE conrelid = 'public.family_communication_controls'::regclass
    AND contype = 'f';
  IF v_fk_count <> 3 THEN
    RAISE EXCEPTION 'Validation failed: family_communication_controls foreign keys %', v_fk_count;
  END IF;

  SELECT count(*) INTO v_trigger_count
  FROM pg_trigger
  WHERE tgrelid = 'public.family_contacts'::regclass
    AND tgname IN ('family_contacts_set_updated_at', 'family_contacts_lifecycle_guard', 'family_contacts_delete_guard');
  IF v_trigger_count <> 3 THEN
    RAISE EXCEPTION 'Validation failed: family_contacts triggers %', v_trigger_count;
  END IF;

  SELECT count(*) INTO v_trigger_count
  FROM pg_trigger
  WHERE tgrelid = 'public.family_contact_channels'::regclass
    AND tgname IN ('family_contact_channels_set_updated_at', 'family_contact_channels_lifecycle_guard', 'family_contact_channels_delete_guard');
  IF v_trigger_count <> 3 THEN
    RAISE EXCEPTION 'Validation failed: family_contact_channels triggers %', v_trigger_count;
  END IF;

  SELECT count(*) INTO v_trigger_count
  FROM pg_trigger
  WHERE tgrelid = 'public.family_communication_controls'::regclass
    AND tgname IN ('family_communication_controls_set_updated_at', 'family_communication_controls_lifecycle_guard', 'family_communication_controls_delete_guard');
  IF v_trigger_count <> 3 THEN
    RAISE EXCEPTION 'Validation failed: family_communication_controls triggers %', v_trigger_count;
  END IF;

  SELECT count(*) INTO v_primary_index_count
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename = 'family_contacts'
    AND indexname = 'family_contacts_active_primary_idx';
  IF v_primary_index_count <> 1 THEN
    RAISE EXCEPTION 'Validation failed: active-primary index count %', v_primary_index_count;
  END IF;

  SELECT count(*) INTO v_preferred_index_count
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename = 'family_contact_channels'
    AND indexname = 'family_contact_channels_active_preferred_idx';
  IF v_preferred_index_count <> 1 THEN
    RAISE EXCEPTION 'Validation failed: active-preferred index count %', v_preferred_index_count;
  END IF;

  SELECT relrowsecurity, relforcerowsecurity INTO v_rls_enabled, v_force_rls
  FROM pg_class
  WHERE oid = 'public.family_contacts'::regclass;
  IF NOT v_rls_enabled OR NOT v_force_rls THEN
    RAISE EXCEPTION 'Validation failed: family_contacts RLS state is incorrect';
  END IF;

  SELECT relrowsecurity, relforcerowsecurity INTO v_rls_enabled, v_force_rls
  FROM pg_class
  WHERE oid = 'public.family_contact_channels'::regclass;
  IF NOT v_rls_enabled OR NOT v_force_rls THEN
    RAISE EXCEPTION 'Validation failed: family_contact_channels RLS state is incorrect';
  END IF;

  SELECT relrowsecurity, relforcerowsecurity INTO v_rls_enabled, v_force_rls
  FROM pg_class
  WHERE oid = 'public.family_communication_controls'::regclass;
  IF NOT v_rls_enabled OR NOT v_force_rls THEN
    RAISE EXCEPTION 'Validation failed: family_communication_controls RLS state is incorrect';
  END IF;

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'family_contacts'
    AND policyname = 'family_contacts_select_scoped';
  IF v_policy_count <> 1 THEN
    RAISE EXCEPTION 'Validation failed: family_contacts policy count %', v_policy_count;
  END IF;

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'family_contact_channels'
    AND policyname = 'family_contact_channels_select_scoped';
  IF v_policy_count <> 1 THEN
    RAISE EXCEPTION 'Validation failed: family_contact_channels policy count %', v_policy_count;
  END IF;

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'family_communication_controls'
    AND policyname = 'family_communication_controls_select_scoped';
  IF v_policy_count <> 1 THEN
    RAISE EXCEPTION 'Validation failed: family_communication_controls policy count %', v_policy_count;
  END IF;

  IF NOT has_table_privilege('authenticated', 'public.family_contacts', 'SELECT') THEN
    RAISE EXCEPTION 'Validation failed: authenticated lacks SELECT on family_contacts';
  END IF;
  IF has_table_privilege('authenticated', 'public.family_contacts', 'INSERT') THEN
    RAISE EXCEPTION 'Validation failed: authenticated unexpectedly has INSERT on family_contacts';
  END IF;
  IF has_table_privilege('authenticated', 'public.family_contacts', 'UPDATE') THEN
    RAISE EXCEPTION 'Validation failed: authenticated unexpectedly has UPDATE on family_contacts';
  END IF;
  IF has_table_privilege('authenticated', 'public.family_contacts', 'DELETE') THEN
    RAISE EXCEPTION 'Validation failed: authenticated unexpectedly has DELETE on family_contacts';
  END IF;

  IF NOT has_table_privilege('service_role', 'public.family_contacts', 'SELECT')
     OR NOT has_table_privilege('service_role', 'public.family_contacts', 'INSERT')
     OR NOT has_table_privilege('service_role', 'public.family_contacts', 'UPDATE')
     OR NOT has_table_privilege('service_role', 'public.family_contacts', 'DELETE') THEN
    RAISE EXCEPTION 'Validation failed: service_role lacks expected family_contacts privileges';
  END IF;

  IF has_function_privilege('anon', 'public.create_family_contact(uuid, text, text, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: anon unexpectedly can execute create_family_contact';
  END IF;
  IF has_function_privilege('anon', 'public.add_family_contact_channel(uuid, public.contact_channel_type, text, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: anon unexpectedly can execute add_family_contact_channel';
  END IF;
  IF has_function_privilege('anon', 'public.update_family_communication_controls(uuid, public.contactability_status, boolean, text, public.contact_channel_type, time, time)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: anon unexpectedly can execute update_family_communication_controls';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.create_family_contact(uuid, text, text, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: authenticated cannot execute create_family_contact';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.add_family_contact_channel(uuid, public.contact_channel_type, text, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: authenticated cannot execute add_family_contact_channel';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.update_family_communication_controls(uuid, public.contactability_status, boolean, text, public.contact_channel_type, time, time)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: authenticated cannot execute update_family_communication_controls';
  END IF;

  IF NOT has_function_privilege('service_role', 'public.create_family_contact(uuid, text, text, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: service_role cannot execute create_family_contact';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.add_family_contact_channel(uuid, public.contact_channel_type, text, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: service_role cannot execute add_family_contact_channel';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.update_family_communication_controls(uuid, public.contactability_status, boolean, text, public.contact_channel_type, time, time)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Validation failed: service_role cannot execute update_family_communication_controls';
  END IF;

  SELECT count(*) INTO v_contact_count FROM public.family_contacts;
  SELECT count(*) INTO v_channel_count FROM public.family_contact_channels;
  SELECT count(*) INTO v_control_count FROM public.family_communication_controls;
  IF v_contact_count <> 0 OR v_channel_count <> 0 OR v_control_count <> 0 THEN
    RAISE EXCEPTION 'Validation failed: family-contact seed data exists';
  END IF;

  SELECT permission_count, role_permission_count INTO v_permission_count, v_role_permission_count
  FROM migration_permission_snapshot;
  IF (SELECT count(*) FROM public.permissions) <> v_permission_count
     OR (SELECT count(*) FROM public.role_permissions) <> v_role_permission_count THEN
    RAISE EXCEPTION 'Validation failed: permissions or role mappings changed';
  END IF;
END
$$;

COMMIT;
