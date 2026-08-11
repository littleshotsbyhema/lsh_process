-- =====================================================================
-- Little Shots by Hema OS
-- Leads / CRM Inquiry Foundation
--
-- Purpose:
--   - Replace legacy/mock Leads storage with a real multi-tenant CRM model.
--   - Preserve inquiry context from first contact through family conversion.
--   - Reuse existing lead.read / lead.write / lead.convert permissions.
--   - Keep direct browser writes disabled.
--   - Keep website/public ingestion server-side for a later integration step.
--
-- Security model:
--   authenticated -> SELECT only on public.leads
--   writes        -> controlled SECURITY DEFINER RPCs
--   anon          -> no table access and no RPC execution
--   service_role  -> ALL
--
-- Existing authorities reused:
--   public.current_organization_member(uuid)
--   public.has_permission(uuid,text,uuid)
--   public.has_branch_scope(uuid,uuid)
--   public.lsh_set_updated_at()
--   public.append_audit_event(...)
--   public.create_family(...)
-- =====================================================================

BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';

-- =====================================================================
-- 1. PRECONDITIONS
-- =====================================================================

DO $preconditions$
BEGIN
  IF to_regclass('public.leads') IS NOT NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: public.leads already exists';
  END IF;

  IF to_regtype('public.lead_status') IS NOT NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: public.lead_status already exists';
  END IF;

  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.branches') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.families') IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: required organization/family tables are missing';
  END IF;

  IF to_regtype('public.privacy_preference_type') IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: public.privacy_preference_type is missing';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: current_organization_member(uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: has_permission(uuid,text,uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.has_branch_scope(uuid,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: has_branch_scope(uuid,uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.lsh_set_updated_at()'
     ) IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: lsh_set_updated_at() missing';
  END IF;

  IF to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: append_audit_event(...) missing';
  END IF;

  IF to_regprocedure(
       'public.create_family(uuid,text,text,uuid,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation precondition failed: create_family(...) missing';
  END IF;
END
$preconditions$;

-- =====================================================================
-- 2. LEAD LIFECYCLE ENUM
-- =====================================================================

CREATE TYPE public.lead_status AS ENUM (
  'new_inquiry',
  'contacted',
  'qualified',
  'consultation_scheduled',
  'quote_ready',
  'quote_sent',
  'follow_up_needed',
  'converted',
  'lost',
  'archived'
);

COMMENT ON TYPE public.lead_status IS
  'Controlled CRM lifecycle for inquiries. Conversion into a family is performed only through convert_lead_to_family().';

-- =====================================================================
-- 3. LEADS TABLE
-- =====================================================================

CREATE TABLE public.leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,
  branch_id uuid,

  lead_reference text NOT NULL,

  source text NOT NULL,
  parent_name text NOT NULL,

  phone text,
  email text,
  city text,

  session_type text,
  baby_age_or_pregnancy text,
  preferred_date date,
  location_preference text,

  package_interest text,
  budget_comfort text,

  memory_goal text,

  privacy_preference public.privacy_preference_type,

  status public.lead_status NOT NULL
    DEFAULT 'new_inquiry'::public.lead_status,

  follow_up_at timestamptz,

  assigned_owner_member_id uuid,

  converted_family_id uuid,
  converted_at timestamptz,
  converted_by uuid,

  lost_reason text,

  internal_notes text,

  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,

  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,

  archived_at timestamptz,
  archived_by uuid,

  CONSTRAINT leads_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations(id)
    ON DELETE RESTRICT,

  CONSTRAINT leads_branch_fkey
    FOREIGN KEY (organization_id, branch_id)
    REFERENCES public.branches(organization_id, id)
    ON DELETE RESTRICT,

  CONSTRAINT leads_assigned_owner_fkey
    FOREIGN KEY (
      organization_id,
      assigned_owner_member_id
    )
    REFERENCES public.organization_members(
      organization_id,
      id
    )
    ON DELETE RESTRICT,

  CONSTRAINT leads_created_by_fkey
    FOREIGN KEY (
      organization_id,
      created_by
    )
    REFERENCES public.organization_members(
      organization_id,
      id
    )
    ON DELETE RESTRICT,

  CONSTRAINT leads_updated_by_fkey
    FOREIGN KEY (
      organization_id,
      updated_by
    )
    REFERENCES public.organization_members(
      organization_id,
      id
    )
    ON DELETE RESTRICT,

  CONSTRAINT leads_converted_by_fkey
    FOREIGN KEY (
      organization_id,
      converted_by
    )
    REFERENCES public.organization_members(
      organization_id,
      id
    )
    ON DELETE RESTRICT,

  CONSTRAINT leads_archived_by_fkey
    FOREIGN KEY (
      organization_id,
      archived_by
    )
    REFERENCES public.organization_members(
      organization_id,
      id
    )
    ON DELETE RESTRICT,

  CONSTRAINT leads_converted_family_fkey
    FOREIGN KEY (
      organization_id,
      converted_family_id
    )
    REFERENCES public.families(
      organization_id,
      id
    )
    ON DELETE RESTRICT,

  CONSTRAINT leads_parent_name_not_blank
    CHECK (btrim(parent_name) <> ''),

  CONSTRAINT leads_source_not_blank
    CHECK (btrim(source) <> ''),

  CONSTRAINT leads_reference_format
    CHECK (
      lead_reference ~ '^LSH-LD-[A-F0-9]{8}$'
    ),

  CONSTRAINT leads_phone_format
    CHECK (
      phone IS NULL
      OR phone ~ '^\+[0-9]{8,15}$'
    ),

  CONSTRAINT leads_email_format
    CHECK (
      email IS NULL
      OR email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),

  CONSTRAINT leads_contact_method_required
    CHECK (
      phone IS NOT NULL
      OR email IS NOT NULL
    ),

  CONSTRAINT leads_converted_state_consistency
    CHECK (
      (
        status = 'converted'::public.lead_status
        AND converted_family_id IS NOT NULL
        AND converted_at IS NOT NULL
        AND converted_by IS NOT NULL
      )
      OR
      (
        status <> 'converted'::public.lead_status
        AND converted_family_id IS NULL
        AND converted_at IS NULL
        AND converted_by IS NULL
      )
    ),

  CONSTRAINT leads_lost_reason_consistency
    CHECK (
      status <> 'lost'::public.lead_status
      OR (
        lost_reason IS NOT NULL
        AND btrim(lost_reason) <> ''
      )
    ),

  CONSTRAINT leads_archive_state_consistency
    CHECK (
      (
        status = 'archived'::public.lead_status
        AND archived_at IS NOT NULL
        AND archived_by IS NOT NULL
      )
      OR
      (
        status <> 'archived'::public.lead_status
        AND archived_at IS NULL
        AND archived_by IS NULL
      )
    )
);

-- Composite key for future tenant-safe child relationships.
ALTER TABLE public.leads
  ADD CONSTRAINT leads_organization_id_id_key
  UNIQUE (organization_id, id);

ALTER TABLE public.leads
  ADD CONSTRAINT leads_organization_id_reference_key
  UNIQUE (organization_id, lead_reference);

CREATE INDEX leads_org_status_idx
  ON public.leads (
    organization_id,
    status
  );

CREATE INDEX leads_org_branch_idx
  ON public.leads (
    organization_id,
    branch_id
  );

CREATE INDEX leads_org_owner_idx
  ON public.leads (
    organization_id,
    assigned_owner_member_id
  );

CREATE INDEX leads_org_follow_up_idx
  ON public.leads (
    organization_id,
    follow_up_at
  )
  WHERE follow_up_at IS NOT NULL;

CREATE INDEX leads_org_created_idx
  ON public.leads (
    organization_id,
    created_at DESC
  );

CREATE INDEX leads_phone_idx
  ON public.leads (
    organization_id,
    phone
  )
  WHERE phone IS NOT NULL;

CREATE INDEX leads_email_lower_idx
  ON public.leads (
    organization_id,
    lower(email)
  )
  WHERE email IS NOT NULL;

COMMENT ON TABLE public.leads IS
  'Structured CRM inquiry record. Source of truth for lead context before conversion into a family record.';

COMMENT ON COLUMN public.leads.memory_goal IS
  'What the family currently hopes to preserve. This is inquiry context, not a replacement for the formal family/child memory profile after conversion.';

COMMENT ON COLUMN public.leads.privacy_preference IS
  'Early privacy preference captured during inquiry. NULL means no preference has yet been recorded and never implies consent.';

COMMENT ON COLUMN public.leads.converted_family_id IS
  'Family record created when the inquiry is converted through convert_lead_to_family().';

-- =====================================================================
-- 4. TABLE LIFECYCLE GUARD
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_leads_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'leads delete rejected: physical deletion is not permitted'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.lead_reference IS DISTINCT FROM OLD.lead_reference
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION
      'leads update rejected: immutable identity fields cannot be changed'
      USING ERRCODE = '42501';
  END IF;

  -- Converted and archived records are historical/terminal.
  IF OLD.status IN (
       'converted'::public.lead_status,
       'archived'::public.lead_status
     )
     AND NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION
      'leads update rejected: converted or archived inquiries are terminal historical records'
      USING ERRCODE = '42501';
  END IF;

  -- Once a conversion link exists it can never be redirected.
  IF OLD.converted_family_id IS NOT NULL
     AND (
       NEW.converted_family_id IS DISTINCT FROM OLD.converted_family_id
       OR NEW.converted_at IS DISTINCT FROM OLD.converted_at
       OR NEW.converted_by IS DISTINCT FROM OLD.converted_by
     ) THEN
    RAISE EXCEPTION
      'leads update rejected: conversion linkage is immutable'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END
$function$;

REVOKE ALL
ON FUNCTION public.lsh_leads_guard()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER leads_20_guard
BEFORE UPDATE OR DELETE
ON public.leads
FOR EACH ROW
EXECUTE FUNCTION public.lsh_leads_guard();

CREATE TRIGGER leads_90_set_updated_at
BEFORE UPDATE
ON public.leads
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

-- =====================================================================
-- 5. CREATE LEAD RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.create_lead(
  p_organization_id uuid,
  p_parent_name text,
  p_source text,
  p_phone text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_session_type text DEFAULT NULL,
  p_baby_age_or_pregnancy text DEFAULT NULL,
  p_preferred_date date DEFAULT NULL,
  p_location_preference text DEFAULT NULL,
  p_package_interest text DEFAULT NULL,
  p_budget_comfort text DEFAULT NULL,
  p_memory_goal text DEFAULT NULL,
  p_privacy_preference public.privacy_preference_type DEFAULT NULL,
  p_follow_up_at timestamptz DEFAULT NULL,
  p_branch_id uuid DEFAULT NULL,
  p_assigned_owner_member_id uuid DEFAULT NULL
)
RETURNS public.leads
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_id uuid;
  v_reference text;
  v_row public.leads;
  v_attempt integer := 0;

  v_parent_name text;
  v_source text;
  v_phone text;
  v_email text;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'create_lead: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    p_organization_id,
    'lead.write',
    p_branch_id
  ) THEN
    RAISE EXCEPTION
      'create_lead: lead.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF p_branch_id IS NOT NULL THEN
    IF NOT public.has_branch_scope(
      p_organization_id,
      p_branch_id
    ) THEN
      RAISE EXCEPTION
        'create_lead: no access to requested branch'
        USING ERRCODE = '42501';
    END IF;

    PERFORM 1
    FROM public.branches b
    WHERE b.organization_id = p_organization_id
      AND b.id = p_branch_id
      AND b.status = 'active'
      AND b.deleted_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'create_lead: branch must be active'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_assigned_owner_member_id IS NOT NULL THEN
    PERFORM 1
    FROM public.organization_members m
    WHERE m.organization_id =
          p_organization_id
      AND m.id =
          p_assigned_owner_member_id
      AND m.status = 'active'
      AND m.exited_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'create_lead: assigned owner must be an active member of this organization'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  v_parent_name :=
    NULLIF(btrim(p_parent_name), '');

  v_source :=
    lower(NULLIF(btrim(p_source), ''));

  v_phone :=
    NULLIF(btrim(p_phone), '');

  v_email :=
    lower(NULLIF(btrim(p_email), ''));

  IF v_parent_name IS NULL THEN
    RAISE EXCEPTION
      'create_lead: parent name is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_source IS NULL THEN
    RAISE EXCEPTION
      'create_lead: source is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_phone IS NULL
     AND v_email IS NULL THEN
    RAISE EXCEPTION
      'create_lead: phone or email is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_phone IS NOT NULL
     AND v_phone !~ '^\+[0-9]{8,15}$' THEN
    RAISE EXCEPTION
      'create_lead: phone must use international format, for example +919876543210'
      USING ERRCODE = '22023';
  END IF;

  LOOP
    v_attempt := v_attempt + 1;

    v_id := gen_random_uuid();

    v_reference :=
      'LSH-LD-' ||
      upper(
        substr(
          replace(v_id::text, '-', ''),
          1,
          8
        )
      );

    BEGIN
      INSERT INTO public.leads (
        id,
        organization_id,
        branch_id,
        lead_reference,
        source,
        parent_name,
        phone,
        email,
        city,
        session_type,
        baby_age_or_pregnancy,
        preferred_date,
        location_preference,
        package_interest,
        budget_comfort,
        memory_goal,
        privacy_preference,
        status,
        follow_up_at,
        assigned_owner_member_id,
        created_by,
        updated_by
      )
      VALUES (
        v_id,
        p_organization_id,
        p_branch_id,
        v_reference,
        v_source,
        v_parent_name,
        v_phone,
        v_email,
        NULLIF(btrim(p_city), ''),
        NULLIF(btrim(p_session_type), ''),
        NULLIF(
          btrim(p_baby_age_or_pregnancy),
          ''
        ),
        p_preferred_date,
        NULLIF(
          btrim(p_location_preference),
          ''
        ),
        NULLIF(
          btrim(p_package_interest),
          ''
        ),
        NULLIF(
          btrim(p_budget_comfort),
          ''
        ),
        NULLIF(
          btrim(p_memory_goal),
          ''
        ),
        p_privacy_preference,
        'new_inquiry'::public.lead_status,
        p_follow_up_at,
        p_assigned_owner_member_id,
        v_actor,
        v_actor
      )
      RETURNING *
      INTO v_row;

      EXIT;

    EXCEPTION
      WHEN unique_violation THEN
        IF v_attempt >= 5 THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  PERFORM public.append_audit_event(
    v_row.organization_id,
    v_row.branch_id,
    'lead.created',
    'lead',
    v_row.id,
    false,
    NULL,
    jsonb_build_object(
      'lead_reference',
        v_row.lead_reference,
      'status',
        v_row.status,
      'source',
        v_row.source
    ),
    jsonb_build_object(
      'has_phone',
        v_row.phone IS NOT NULL,
      'has_email',
        v_row.email IS NOT NULL,
      'has_memory_goal',
        v_row.memory_goal IS NOT NULL,
      'has_privacy_preference',
        v_row.privacy_preference IS NOT NULL
    ),
    'crm',
    NULL
  );

  RETURN v_row;
END
$function$;

-- =====================================================================
-- 6. UPDATE LEAD RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.update_lead(
  p_lead_id uuid,
  p_parent_name text,
  p_source text,
  p_phone text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_session_type text DEFAULT NULL,
  p_baby_age_or_pregnancy text DEFAULT NULL,
  p_preferred_date date DEFAULT NULL,
  p_location_preference text DEFAULT NULL,
  p_package_interest text DEFAULT NULL,
  p_budget_comfort text DEFAULT NULL,
  p_memory_goal text DEFAULT NULL,
  p_privacy_preference public.privacy_preference_type DEFAULT NULL,
  p_follow_up_at timestamptz DEFAULT NULL,
  p_status public.lead_status DEFAULT 'new_inquiry',
  p_lost_reason text DEFAULT NULL,
  p_branch_id uuid DEFAULT NULL,
  p_assigned_owner_member_id uuid DEFAULT NULL
)
RETURNS public.leads
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_old public.leads;
  v_row public.leads;

  v_parent_name text;
  v_source text;
  v_phone text;
  v_email text;
  v_lost_reason text;

  v_archived_at timestamptz;
  v_archived_by uuid;
BEGIN
  SELECT *
  INTO v_old
  FROM public.leads
  WHERE id = p_lead_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_lead: inquiry not found'
      USING ERRCODE = 'P0002';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_old.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'update_lead: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF v_old.status IN (
       'converted'::public.lead_status,
       'archived'::public.lead_status
     ) THEN
    RAISE EXCEPTION
      'update_lead: converted or archived inquiries are terminal'
      USING ERRCODE = '42501';
  END IF;

  IF p_status =
     'converted'::public.lead_status THEN
    RAISE EXCEPTION
      'update_lead: converted status may only be set by convert_lead_to_family()'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_old.organization_id,
    'lead.write',
    v_old.branch_id
  ) THEN
    RAISE EXCEPTION
      'update_lead: lead.write permission required in the current scope'
      USING ERRCODE = '42501';
  END IF;

  IF v_old.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_old.organization_id,
       v_old.branch_id
     ) THEN
    RAISE EXCEPTION
      'update_lead: no access to current branch'
      USING ERRCODE = '42501';
  END IF;

  -- Branch reassignment requires authority over both scopes.
  IF p_branch_id IS DISTINCT FROM
     v_old.branch_id THEN

    IF NOT public.has_permission(
      v_old.organization_id,
      'lead.write',
      p_branch_id
    ) THEN
      RAISE EXCEPTION
        'update_lead: lead.write permission required in target scope'
        USING ERRCODE = '42501';
    END IF;

    IF p_branch_id IS NOT NULL THEN
      IF NOT public.has_branch_scope(
        v_old.organization_id,
        p_branch_id
      ) THEN
        RAISE EXCEPTION
          'update_lead: no access to target branch'
          USING ERRCODE = '42501';
      END IF;

      PERFORM 1
      FROM public.branches b
      WHERE b.organization_id =
            v_old.organization_id
        AND b.id = p_branch_id
        AND b.status = 'active'
        AND b.deleted_at IS NULL;

      IF NOT FOUND THEN
        RAISE EXCEPTION
          'update_lead: target branch must be active'
          USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  IF p_assigned_owner_member_id IS NOT NULL THEN
    PERFORM 1
    FROM public.organization_members m
    WHERE m.organization_id =
          v_old.organization_id
      AND m.id =
          p_assigned_owner_member_id
      AND m.status = 'active'
      AND m.exited_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'update_lead: assigned owner must be an active member of this organization'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  v_parent_name :=
    NULLIF(btrim(p_parent_name), '');

  v_source :=
    lower(NULLIF(btrim(p_source), ''));

  v_phone :=
    NULLIF(btrim(p_phone), '');

  v_email :=
    lower(NULLIF(btrim(p_email), ''));

  IF v_parent_name IS NULL THEN
    RAISE EXCEPTION
      'update_lead: parent name is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_source IS NULL THEN
    RAISE EXCEPTION
      'update_lead: source is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_phone IS NULL
     AND v_email IS NULL THEN
    RAISE EXCEPTION
      'update_lead: phone or email is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_phone IS NOT NULL
     AND v_phone !~ '^\+[0-9]{8,15}$' THEN
    RAISE EXCEPTION
      'update_lead: phone must use international format, for example +919876543210'
      USING ERRCODE = '22023';
  END IF;

  IF p_status =
     'lost'::public.lead_status THEN
    v_lost_reason :=
      NULLIF(btrim(p_lost_reason), '');

    IF v_lost_reason IS NULL THEN
      RAISE EXCEPTION
        'update_lead: lost inquiries require a reason'
        USING ERRCODE = '22023';
    END IF;
  ELSE
    v_lost_reason := NULL;
  END IF;

  IF p_status =
     'archived'::public.lead_status THEN
    v_archived_at := now();
    v_archived_by := v_actor;
  ELSE
    v_archived_at := NULL;
    v_archived_by := NULL;
  END IF;

  UPDATE public.leads
  SET
    branch_id =
      p_branch_id,

    parent_name =
      v_parent_name,

    source =
      v_source,

    phone =
      v_phone,

    email =
      v_email,

    city =
      NULLIF(btrim(p_city), ''),

    session_type =
      NULLIF(btrim(p_session_type), ''),

    baby_age_or_pregnancy =
      NULLIF(
        btrim(p_baby_age_or_pregnancy),
        ''
      ),

    preferred_date =
      p_preferred_date,

    location_preference =
      NULLIF(
        btrim(p_location_preference),
        ''
      ),

    package_interest =
      NULLIF(
        btrim(p_package_interest),
        ''
      ),

    budget_comfort =
      NULLIF(
        btrim(p_budget_comfort),
        ''
      ),

    memory_goal =
      NULLIF(
        btrim(p_memory_goal),
        ''
      ),

    privacy_preference =
      p_privacy_preference,

    status =
      p_status,

    follow_up_at =
      p_follow_up_at,

    assigned_owner_member_id =
      p_assigned_owner_member_id,

    lost_reason =
      v_lost_reason,

    archived_at =
      v_archived_at,

    archived_by =
      v_archived_by,

    updated_by =
      v_actor

  WHERE id = p_lead_id

  RETURNING *
  INTO v_row;

  PERFORM public.append_audit_event(
    v_row.organization_id,
    v_row.branch_id,
    'lead.updated',
    'lead',
    v_row.id,
    false,
    jsonb_build_object(
      'status',
        v_old.status,
      'branch_id',
        v_old.branch_id,
      'assigned_owner_member_id',
        v_old.assigned_owner_member_id,
      'follow_up_at',
        v_old.follow_up_at
    ),
    jsonb_build_object(
      'status',
        v_row.status,
      'branch_id',
        v_row.branch_id,
      'assigned_owner_member_id',
        v_row.assigned_owner_member_id,
      'follow_up_at',
        v_row.follow_up_at
    ),
    jsonb_build_object(
      'contact_details_changed',
        (
          v_old.phone IS DISTINCT FROM
          v_row.phone
          OR
          v_old.email IS DISTINCT FROM
          v_row.email
        ),
      'memory_goal_changed',
        v_old.memory_goal IS DISTINCT FROM
        v_row.memory_goal,
      'privacy_preference_changed',
        v_old.privacy_preference IS DISTINCT FROM
        v_row.privacy_preference
    ),
    'crm',
    NULL
  );

  RETURN v_row;
END
$function$;

-- =====================================================================
-- 7. CONVERT LEAD TO FAMILY RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.convert_lead_to_family(
  p_lead_id uuid,
  p_family_display_name text DEFAULT NULL,
  p_family_sort_name text DEFAULT NULL
)
RETURNS public.families
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_lead public.leads;
  v_family public.families;

  v_display_name text;
  v_sort_name text;
BEGIN
  SELECT *
  INTO v_lead
  FROM public.leads
  WHERE id = p_lead_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'convert_lead_to_family: inquiry not found'
      USING ERRCODE = 'P0002';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_lead.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'convert_lead_to_family: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_lead.organization_id,
    'lead.convert',
    v_lead.branch_id
  ) THEN
    RAISE EXCEPTION
      'convert_lead_to_family: lead.convert permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_lead.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       v_lead.organization_id,
       v_lead.branch_id
     ) THEN
    RAISE EXCEPTION
      'convert_lead_to_family: no access to inquiry branch'
      USING ERRCODE = '42501';
  END IF;

  -- Idempotent read of an already completed conversion.
  IF v_lead.status =
     'converted'::public.lead_status THEN
    SELECT *
    INTO v_family
    FROM public.families
    WHERE organization_id =
          v_lead.organization_id
      AND id =
          v_lead.converted_family_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'convert_lead_to_family: converted inquiry references a missing family';
    END IF;

    RETURN v_family;
  END IF;

  IF v_lead.status =
     'archived'::public.lead_status THEN
    RAISE EXCEPTION
      'convert_lead_to_family: archived inquiries cannot be converted'
      USING ERRCODE = '42501';
  END IF;

  v_display_name :=
    NULLIF(
      btrim(p_family_display_name),
      ''
    );

  IF v_display_name IS NULL THEN
    v_display_name :=
      v_lead.parent_name || ' Family';
  END IF;

  v_sort_name :=
    NULLIF(
      btrim(p_family_sort_name),
      ''
    );

  IF v_sort_name IS NULL THEN
    v_sort_name := v_display_name;
  END IF;

  -- create_family remains the sole approved creation path for families.
  --
  -- This also means conversion must satisfy the family creation
  -- authorization contract in addition to lead.convert.
  SELECT *
  INTO v_family
  FROM public.create_family(
    v_lead.organization_id,
    v_display_name,
    v_sort_name,
    v_lead.branch_id,
    v_lead.assigned_owner_member_id
  );

  UPDATE public.leads
  SET
    status =
      'converted'::public.lead_status,

    converted_family_id =
      v_family.id,

    converted_at =
      now(),

    converted_by =
      v_actor,

    lost_reason =
      NULL,

    follow_up_at =
      NULL,

    updated_by =
      v_actor

  WHERE id = v_lead.id;

  PERFORM public.append_audit_event(
    v_lead.organization_id,
    v_lead.branch_id,
    'lead.converted',
    'lead',
    v_lead.id,
    false,
    jsonb_build_object(
      'status',
        v_lead.status
    ),
    jsonb_build_object(
      'status',
        'converted',
      'converted_family_id',
        v_family.id
    ),
    jsonb_build_object(
      'lead_reference',
        v_lead.lead_reference,
      'family_code',
        v_family.family_code
    ),
    'crm',
    NULL
  );

  RETURN v_family;
END
$function$;

-- =====================================================================
-- 8. FUNCTION PRIVILEGES
-- =====================================================================

REVOKE ALL
ON FUNCTION public.create_lead(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  date,
  text,
  text,
  text,
  text,
  public.privacy_preference_type,
  timestamptz,
  uuid,
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.create_lead(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  date,
  text,
  text,
  text,
  text,
  public.privacy_preference_type,
  timestamptz,
  uuid,
  uuid
)
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.update_lead(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  date,
  text,
  text,
  text,
  text,
  public.privacy_preference_type,
  timestamptz,
  public.lead_status,
  text,
  uuid,
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.update_lead(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  date,
  text,
  text,
  text,
  text,
  public.privacy_preference_type,
  timestamptz,
  public.lead_status,
  text,
  uuid,
  uuid
)
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.convert_lead_to_family(
  uuid,
  text,
  text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.convert_lead_to_family(
  uuid,
  text,
  text
)
TO authenticated, service_role;

-- =====================================================================
-- 9. RLS
-- =====================================================================

ALTER TABLE public.leads
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.leads
  FORCE ROW LEVEL SECURITY;

CREATE POLICY leads_select_scoped
ON public.leads
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'lead.read',
    branch_id
  )
  AND (
    branch_id IS NULL
    OR public.has_branch_scope(
      organization_id,
      branch_id
    )
  )
);

-- No INSERT / UPDATE / DELETE policies.
-- All authenticated writes use controlled RPCs.

-- =====================================================================
-- 10. TABLE PRIVILEGES
-- =====================================================================

REVOKE ALL
ON TABLE public.leads
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON TABLE public.leads
TO authenticated;

GRANT ALL
ON TABLE public.leads
TO service_role;

-- =====================================================================
-- 11. VALIDATION
-- =====================================================================

DO $validation$
DECLARE
  v_count integer;
  v_enum_labels text[];
  v_bad_functions text;
BEGIN
  -- ------------------------------------------------------------
  -- 11.1 Table exists
  -- ------------------------------------------------------------

  IF to_regclass('public.leads') IS NULL THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: public.leads missing';
  END IF;

  -- ------------------------------------------------------------
  -- 11.2 Enum exact ordering
  -- ------------------------------------------------------------

  SELECT array_agg(
           e.enumlabel
           ORDER BY e.enumsortorder
         )
  INTO v_enum_labels
  FROM pg_enum e
  JOIN pg_type t
    ON t.oid = e.enumtypid
  JOIN pg_namespace n
    ON n.oid = t.typnamespace
  WHERE n.nspname = 'public'
    AND t.typname = 'lead_status';

  IF v_enum_labels IS DISTINCT FROM ARRAY[
    'new_inquiry',
    'contacted',
    'qualified',
    'consultation_scheduled',
    'quote_ready',
    'quote_sent',
    'follow_up_needed',
    'converted',
    'lost',
    'archived'
  ]::text[] THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: lead_status enum mismatch: %',
      v_enum_labels;
  END IF;

  -- ------------------------------------------------------------
  -- 11.3 RLS enabled + forced
  -- ------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'leads'
    AND c.relrowsecurity IS TRUE
    AND c.relforcerowsecurity IS TRUE;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: RLS must be enabled and forced';
  END IF;

  -- ------------------------------------------------------------
  -- 11.4 Authenticated table privilege = SELECT only
  -- ------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM information_schema.role_table_grants
  WHERE grantee = 'authenticated'
    AND table_schema = 'public'
    AND table_name = 'leads'
    AND privilege_type <> 'SELECT';

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: authenticated has non-SELECT table privileges';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.leads',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: authenticated lacks SELECT';
  END IF;

  -- ------------------------------------------------------------
  -- 11.5 Required RPC inventory
  -- ------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'create_lead',
      'update_lead',
      'convert_lead_to_family'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: expected 3 public lead RPCs, found %',
      v_count;
  END IF;

  -- ------------------------------------------------------------
  -- 11.6 Every public lead RPC is SECURITY DEFINER + empty path
  -- ------------------------------------------------------------

  SELECT string_agg(
           p.oid::regprocedure::text,
           ', '
         )
  INTO v_bad_functions
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'create_lead',
      'update_lead',
      'convert_lead_to_family'
    )
    AND (
      p.prosecdef IS NOT TRUE
      OR NOT (
        'search_path=""' =
        ANY(
          COALESCE(
            p.proconfig,
            ARRAY[]::text[]
          )
        )
      )
    );

  IF v_bad_functions IS NOT NULL THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: insecure function configuration: %',
      v_bad_functions;
  END IF;

  -- ------------------------------------------------------------
  -- 11.7 No anonymous execution
  -- ------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'create_lead',
      'update_lead',
      'convert_lead_to_family'
    )
    AND has_function_privilege(
      'anon',
      p.oid,
      'EXECUTE'
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: anon may execute % lead RPC(s)',
      v_count;
  END IF;

  -- ------------------------------------------------------------
  -- 11.8 Authenticated execution on all 3 public RPCs
  -- ------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'create_lead',
      'update_lead',
      'convert_lead_to_family'
    )
    AND has_function_privilege(
      'authenticated',
      p.oid,
      'EXECUTE'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: authenticated execute count is %, expected 3',
      v_count;
  END IF;

  -- ------------------------------------------------------------
  -- 11.9 Internal trigger function not client executable
  -- ------------------------------------------------------------

  IF has_function_privilege(
    'authenticated',
    'public.lsh_leads_guard()',
    'EXECUTE'
  )
  OR has_function_privilege(
    'anon',
    'public.lsh_leads_guard()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: lsh_leads_guard must not be client executable';
  END IF;

  -- ------------------------------------------------------------
  -- 11.10 No migration seed data
  -- ------------------------------------------------------------

  SELECT count(*)
  INTO v_count
  FROM public.leads;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'leads_foundation validation failed: migration unexpectedly created % lead row(s)',
      v_count;
  END IF;
END
$validation$;

COMMIT;
