BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';

-- ============================================================
-- 1. Permission and role catalogues
-- ============================================================

CREATE TABLE public.permissions (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key                         text NOT NULL UNIQUE,
  domain                      text NOT NULL,
  label                       text NOT NULL,
  description                 text,
  requires_server_enforcement boolean NOT NULL DEFAULT false,
  created_at                  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT permissions_key_format_chk
    CHECK (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),

  CONSTRAINT permissions_domain_format_chk
    CHECK (domain ~ '^[a-z][a-z0-9_]*$'),

  CONSTRAINT permissions_label_length_chk
    CHECK (char_length(label) BETWEEN 1 AND 120)
);

CREATE TABLE public.roles (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key            text NOT NULL UNIQUE,
  label          text NOT NULL,
  description    text,
  sort_order     integer NOT NULL DEFAULT 0,
  is_system_role boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT roles_key_format_chk
    CHECK (key ~ '^[a-z][a-z0-9_]*$'),

  CONSTRAINT roles_label_length_chk
    CHECK (char_length(label) BETWEEN 1 AND 120)
);

CREATE TABLE public.role_permissions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id       uuid NOT NULL,
  permission_id uuid NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT role_permissions_role_id_fkey
    FOREIGN KEY (role_id)
    REFERENCES public.roles (id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT role_permissions_permission_id_fkey
    FOREIGN KEY (permission_id)
    REFERENCES public.permissions (id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT role_permissions_role_permission_key
    UNIQUE (role_id, permission_id)
);

CREATE INDEX role_permissions_role_id_idx
  ON public.role_permissions (role_id);

CREATE INDEX role_permissions_permission_id_idx
  ON public.role_permissions (permission_id);

ALTER TABLE public.permissions
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.roles
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.role_permissions
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions
  FORCE ROW LEVEL SECURITY;

CREATE POLICY permissions_deny_all_authenticated
  ON public.permissions
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY roles_deny_all_authenticated
  ON public.roles
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY role_permissions_deny_all_authenticated
  ON public.role_permissions
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

-- ============================================================
-- 2. Canonical permission catalogue: 38 permissions
-- ============================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
) VALUES
  ('org.read','organization','Read organization profile','View the studio profile and branding.',false),
  ('org.settings.write','organization','Change organization settings','Edit studio settings, retention and link-expiry policy.',true),
  ('team.read','team','View studio members','See who works in the studio and their roles.',false),
  ('team.invite','team','Invite studio members','Create and revoke studio invitations.',true),
  ('team.role.assign','team','Assign roles to members','Grant or remove studio roles.',true),
  ('team.suspend','team','Suspend or reinstate members','Disable or restore studio access.',true),
  ('lead.read','leads','View inquiries','Read inquiry records and activity.',false),
  ('lead.write','leads','Create and edit inquiries','Add and update inquiry records.',false),
  ('lead.convert','leads','Convert an inquiry to a client','Promote an inquiry into a family record.',false),
  ('client.read','clients','View family records','Read family and contact records.',false),
  ('client.write','clients','Create and edit family records','Add and update family records.',false),
  ('memory.read','memory','View memory profiles','Read family memory goals and story notes.',false),
  ('memory.write','memory','Write memory profiles','Create and update memory profiles.',false),
  ('booking.read','bookings','View bookings','Read booking and session records.',false),
  ('booking.write','bookings','Create and edit bookings','Add and update bookings and sessions.',false),
  ('booking.stage.advance','bookings','Advance journey stage','Move a family through the 21-stage journey.',false),
  ('finance.read','finance','View financial records','Read invoices, payments and refunds.',false),
  ('finance.write','finance','Create and change financial records','Record payments, refunds and adjustments within approved thresholds.',true),
  ('quote.write','finance','Author commercial proposals and quotes','Create and amend quotes and proposals.',false),
  ('safety.read','safety','View safety and comfort records','Read safety and comfort checklists.',false),
  ('safety.write','safety','Complete safety and comfort checklists','Fill in safety and comfort records.',false),
  ('safety.signoff','safety','Sign off safety readiness','Attest that a session is safe to proceed.',true),
  ('privacy.read','privacy','View consent records','Read the consent ledger and current permissions.',false),
  ('privacy.record','privacy','Record consent','Append new consent, correction or withdrawal records.',false),
  ('privacy.widen_public_usage','privacy','Widen public usage of imagery','Broaden the permitted public use of family imagery.',true),
  ('editing.read','editing','View editing jobs','Read editing and retouching job status.',false),
  ('editing.write','editing','Manage editing jobs','Create and advance editing jobs.',false),
  ('delivery.read','delivery','View delivery records','Read gallery and delivery status.',false),
  ('delivery.write','delivery','Manage delivery records','Create and advance delivery records.',false),
  ('heirloom.read','heirloom','View heirloom production','Read album, frame and print production status.',false),
  ('heirloom.write','heirloom','Manage heirloom production','Create and advance heirloom production jobs.',false),
  ('marketing.read','marketing','View marketing queue','Read the marketing approval queue.',false),
  ('marketing.approve','marketing','Approve imagery for marketing','Approve imagery for public use, subject to consent validation.',true),
  ('review.read','reviews','View reviews and aftercare','Read review requests, testimonials and aftercare logs.',false),
  ('review.write','reviews','Request reviews and log aftercare','Send review requests and record aftercare.',false),
  ('governance.read','governance','View governance and alignment','Read philosophy alignment and governance runs.',false),
  ('audit.read','governance','Read audit logs','Read standard audit history.',true),
  ('audit.sensitive.read','governance','Read sensitive audit logs','Read consent, finance and role-change audit history.',true);

-- ============================================================
-- 3. Canonical role catalogue: 11 roles
-- ============================================================

INSERT INTO public.roles (
  key,
  label,
  description,
  sort_order,
  is_system_role
) VALUES
  ('founder','Founder / Studio Head','Full authority across the studio.',10,true),
  ('studio_manager','Studio Manager','Runs day-to-day operations; no organization settings, role assignment, consent widening or sensitive audit.',20,true),
  ('client_coordinator','Client Coordinator','Owns the family journey from inquiry to completion.',30,true),
  ('sales','Sales Lead','Owns inquiries, proposals and conversion.',40,true),
  ('photographer','Photographer','Shoots sessions and completes safety and comfort records.',50,true),
  ('assistant','Assistant / Baby Care Support','Supports sessions and safety and comfort records.',60,true),
  ('stylist','Stylist / Makeup Artist','Prepares families for sessions.',70,true),
  ('editor','Editor / Retoucher','Runs editing and delivery for assigned work.',80,true),
  ('album_coordinator','Album / Print Coordinator','Runs heirloom production and print delivery.',90,true),
  ('marketing','Marketing Team','Runs marketing approvals and reputation, within consent limits.',100,true),
  ('accounts','Accounts','Processes approved invoices, payments and refunds.',110,true);

-- ============================================================
-- 4. Canonical role-permission map: 139 mappings
-- ============================================================

CREATE TEMP TABLE lsh_seed_role_permission_map (
  role_key       text NOT NULL,
  permission_key text NOT NULL
) ON COMMIT DROP;

INSERT INTO lsh_seed_role_permission_map (role_key, permission_key) VALUES
  ('founder','org.read'),
  ('founder','org.settings.write'),
  ('founder','team.read'),
  ('founder','team.invite'),
  ('founder','team.role.assign'),
  ('founder','team.suspend'),
  ('founder','lead.read'),
  ('founder','lead.write'),
  ('founder','lead.convert'),
  ('founder','client.read'),
  ('founder','client.write'),
  ('founder','memory.read'),
  ('founder','memory.write'),
  ('founder','booking.read'),
  ('founder','booking.write'),
  ('founder','booking.stage.advance'),
  ('founder','finance.read'),
  ('founder','finance.write'),
  ('founder','quote.write'),
  ('founder','safety.read'),
  ('founder','safety.write'),
  ('founder','safety.signoff'),
  ('founder','privacy.read'),
  ('founder','privacy.record'),
  ('founder','privacy.widen_public_usage'),
  ('founder','editing.read'),
  ('founder','editing.write'),
  ('founder','delivery.read'),
  ('founder','delivery.write'),
  ('founder','heirloom.read'),
  ('founder','heirloom.write'),
  ('founder','marketing.read'),
  ('founder','marketing.approve'),
  ('founder','review.read'),
  ('founder','review.write'),
  ('founder','governance.read'),
  ('founder','audit.read'),
  ('founder','audit.sensitive.read'),
  ('studio_manager','org.read'),
  ('studio_manager','team.read'),
  ('studio_manager','team.invite'),
  ('studio_manager','team.suspend'),
  ('studio_manager','lead.read'),
  ('studio_manager','lead.write'),
  ('studio_manager','lead.convert'),
  ('studio_manager','client.read'),
  ('studio_manager','client.write'),
  ('studio_manager','memory.read'),
  ('studio_manager','memory.write'),
  ('studio_manager','booking.read'),
  ('studio_manager','booking.write'),
  ('studio_manager','booking.stage.advance'),
  ('studio_manager','finance.read'),
  ('studio_manager','finance.write'),
  ('studio_manager','quote.write'),
  ('studio_manager','safety.read'),
  ('studio_manager','safety.write'),
  ('studio_manager','safety.signoff'),
  ('studio_manager','privacy.read'),
  ('studio_manager','privacy.record'),
  ('studio_manager','editing.read'),
  ('studio_manager','editing.write'),
  ('studio_manager','delivery.read'),
  ('studio_manager','delivery.write'),
  ('studio_manager','heirloom.read'),
  ('studio_manager','heirloom.write'),
  ('studio_manager','marketing.read'),
  ('studio_manager','marketing.approve'),
  ('studio_manager','review.read'),
  ('studio_manager','review.write'),
  ('studio_manager','governance.read'),
  ('studio_manager','audit.read'),
  ('client_coordinator','org.read'),
  ('client_coordinator','team.read'),
  ('client_coordinator','lead.read'),
  ('client_coordinator','lead.write'),
  ('client_coordinator','lead.convert'),
  ('client_coordinator','client.read'),
  ('client_coordinator','client.write'),
  ('client_coordinator','memory.read'),
  ('client_coordinator','memory.write'),
  ('client_coordinator','booking.read'),
  ('client_coordinator','booking.write'),
  ('client_coordinator','booking.stage.advance'),
  ('client_coordinator','safety.read'),
  ('client_coordinator','safety.write'),
  ('client_coordinator','privacy.read'),
  ('client_coordinator','privacy.record'),
  ('client_coordinator','editing.read'),
  ('client_coordinator','delivery.read'),
  ('client_coordinator','heirloom.read'),
  ('client_coordinator','review.read'),
  ('sales','org.read'),
  ('sales','lead.read'),
  ('sales','lead.write'),
  ('sales','lead.convert'),
  ('sales','client.read'),
  ('sales','client.write'),
  ('sales','booking.read'),
  ('sales','finance.read'),
  ('sales','quote.write'),
  ('photographer','org.read'),
  ('photographer','memory.read'),
  ('photographer','booking.read'),
  ('photographer','safety.read'),
  ('photographer','safety.write'),
  ('photographer','delivery.read'),
  ('assistant','org.read'),
  ('assistant','memory.read'),
  ('assistant','booking.read'),
  ('assistant','safety.read'),
  ('assistant','safety.write'),
  ('stylist','org.read'),
  ('stylist','memory.read'),
  ('stylist','booking.read'),
  ('stylist','safety.read'),
  ('stylist','safety.write'),
  ('editor','org.read'),
  ('editor','memory.read'),
  ('editor','booking.read'),
  ('editor','editing.read'),
  ('editor','editing.write'),
  ('editor','delivery.read'),
  ('editor','delivery.write'),
  ('album_coordinator','org.read'),
  ('album_coordinator','booking.read'),
  ('album_coordinator','delivery.read'),
  ('album_coordinator','heirloom.read'),
  ('album_coordinator','heirloom.write'),
  ('marketing','org.read'),
  ('marketing','privacy.read'),
  ('marketing','marketing.read'),
  ('marketing','marketing.approve'),
  ('marketing','review.read'),
  ('marketing','review.write'),
  ('accounts','org.read'),
  ('accounts','booking.read'),
  ('accounts','finance.read'),
  ('accounts','finance.write');

DO $$
DECLARE
  v_duplicate_count integer;
  v_unknown_roles   integer;
  v_unknown_perms   integer;
  v_mapping_count   integer;
BEGIN
  SELECT count(*)
  INTO v_duplicate_count
  FROM (
    SELECT role_key, permission_key
    FROM lsh_seed_role_permission_map
    GROUP BY role_key, permission_key
    HAVING count(*) > 1
  ) duplicate_rows;

  IF v_duplicate_count <> 0 THEN
    RAISE EXCEPTION
      'Access-control migration aborted: % duplicate canonical mapping rows',
      v_duplicate_count;
  END IF;

  SELECT count(*)
  INTO v_unknown_roles
  FROM (
    SELECT DISTINCT m.role_key
    FROM lsh_seed_role_permission_map m
    LEFT JOIN public.roles r ON r.key = m.role_key
    WHERE r.id IS NULL
  ) unknown_roles;

  IF v_unknown_roles <> 0 THEN
    RAISE EXCEPTION
      'Access-control migration aborted: % unknown role keys',
      v_unknown_roles;
  END IF;

  SELECT count(*)
  INTO v_unknown_perms
  FROM (
    SELECT DISTINCT m.permission_key
    FROM lsh_seed_role_permission_map m
    LEFT JOIN public.permissions p ON p.key = m.permission_key
    WHERE p.id IS NULL
  ) unknown_permissions;

  IF v_unknown_perms <> 0 THEN
    RAISE EXCEPTION
      'Access-control migration aborted: % unknown permission keys',
      v_unknown_perms;
  END IF;

  SELECT count(*)
  INTO v_mapping_count
  FROM lsh_seed_role_permission_map;

  IF v_mapping_count <> 139 THEN
    RAISE EXCEPTION
      'Access-control migration aborted: canonical mapping count % does not equal 139',
      v_mapping_count;
  END IF;
END
$$;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM lsh_seed_role_permission_map m
JOIN public.roles r ON r.key = m.role_key
JOIN public.permissions p ON p.key = m.permission_key;

-- ============================================================
-- 5. Organization membership and scoped role grants
-- ============================================================

CREATE TYPE public.member_status AS ENUM (
  'active',
  'suspended',
  'left',
  'revoked'
);

ALTER TABLE public.branches
  ADD CONSTRAINT branches_id_organization_id_key
  UNIQUE (id, organization_id);

CREATE TABLE public.organization_members (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   uuid NOT NULL,
  user_id           uuid NOT NULL,
  status            public.member_status NOT NULL DEFAULT 'active',
  display_name      text,
  email             text,
  phone             text,
  joined_at         timestamptz NOT NULL DEFAULT now(),
  suspended_at      timestamptz,
  suspended_by      uuid,
  suspension_reason text,
  exited_at         timestamptz,
  exited_by         uuid,
  exit_reason       text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  created_by        uuid,
  updated_by        uuid,

  CONSTRAINT organization_members_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_members_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_members_organization_id_user_id_key
    UNIQUE (organization_id, user_id),

  CONSTRAINT organization_members_id_organization_id_key
    UNIQUE (id, organization_id),

  CONSTRAINT organization_members_display_name_not_blank_chk
    CHECK (display_name IS NULL OR btrim(display_name) <> ''),

  CONSTRAINT organization_members_email_not_blank_chk
    CHECK (email IS NULL OR btrim(email) <> ''),

  CONSTRAINT organization_members_phone_not_blank_chk
    CHECK (phone IS NULL OR btrim(phone) <> ''),

  CONSTRAINT organization_members_suspension_state_chk
    CHECK (
      (
        status = 'suspended'::public.member_status
        AND suspended_at IS NOT NULL
      )
      OR status <> 'suspended'::public.member_status
    ),

  CONSTRAINT organization_members_exit_state_chk
    CHECK (
      (
        status IN (
          'left'::public.member_status,
          'revoked'::public.member_status
        )
        AND exited_at IS NOT NULL
      )
      OR status NOT IN (
        'left'::public.member_status,
        'revoked'::public.member_status
      )
    )
);

ALTER TABLE public.organization_members
  ADD CONSTRAINT organization_members_created_by_fkey
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  ADD CONSTRAINT organization_members_updated_by_fkey
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  ADD CONSTRAINT organization_members_suspended_by_fkey
    FOREIGN KEY (suspended_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  ADD CONSTRAINT organization_members_exited_by_fkey
    FOREIGN KEY (exited_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

CREATE INDEX organization_members_organization_id_idx
  ON public.organization_members (organization_id);

CREATE INDEX organization_members_user_id_idx
  ON public.organization_members (user_id);

CREATE INDEX organization_members_organization_id_status_idx
  ON public.organization_members (organization_id, status);

CREATE TRIGGER organization_members_set_updated_at
  BEFORE UPDATE ON public.organization_members
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TABLE public.member_role_grants (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id        uuid NOT NULL,
  organization_member_id uuid NOT NULL,
  role_id                uuid NOT NULL,
  branch_id              uuid,
  granted_at             timestamptz NOT NULL DEFAULT now(),
  granted_by             uuid,
  revoked_at             timestamptz,
  revoked_by             uuid,
  revocation_reason      text,
  created_at             timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT member_role_grants_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_member_fkey
    FOREIGN KEY (organization_member_id, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_role_id_fkey
    FOREIGN KEY (role_id)
    REFERENCES public.roles (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_branch_fkey
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_granted_by_fkey
    FOREIGN KEY (granted_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_revoked_by_fkey
    FOREIGN KEY (revoked_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_role_grants_revocation_reason_not_blank_chk
    CHECK (revocation_reason IS NULL OR btrim(revocation_reason) <> ''),

  CONSTRAINT member_role_grants_revocation_state_chk
    CHECK (
      (
        revoked_at IS NULL
        AND revoked_by IS NULL
        AND revocation_reason IS NULL
      )
      OR revoked_at IS NOT NULL
    )
);

CREATE UNIQUE INDEX member_role_grants_live_orgwide_uidx
  ON public.member_role_grants (organization_member_id, role_id)
  WHERE revoked_at IS NULL
    AND branch_id IS NULL;

CREATE UNIQUE INDEX member_role_grants_live_branch_uidx
  ON public.member_role_grants (
    organization_member_id,
    role_id,
    branch_id
  )
  WHERE revoked_at IS NULL
    AND branch_id IS NOT NULL;

CREATE INDEX member_role_grants_organization_id_idx
  ON public.member_role_grants (organization_id);

CREATE INDEX member_role_grants_organization_member_id_idx
  ON public.member_role_grants (organization_member_id);

CREATE INDEX member_role_grants_live_member_idx
  ON public.member_role_grants (
    organization_id,
    organization_member_id
  )
  WHERE revoked_at IS NULL;

-- ============================================================
-- 6. Founder coverage and branch-scope guards
-- ============================================================

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

  SELECT r.key
  INTO v_role_key
  FROM public.roles r
  WHERE r.id = NEW.role_id;

  IF v_role_key = 'founder' THEN
    RAISE EXCEPTION
      'Founder grants must be organization-wide; branch_id must be NULL';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER member_role_grants_reject_branch_founder
  BEFORE INSERT OR UPDATE
  ON public.member_role_grants
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_reject_branch_scoped_founder();

CREATE OR REPLACE FUNCTION public.lsh_assert_founder_coverage(
  p_organization_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_status        public.organization_status;
  v_deleted_at    timestamptz;
  v_founder_count integer;
BEGIN
  SELECT o.status, o.deleted_at
  INTO v_status, v_deleted_at
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
    AND m.status = 'active'::public.member_status;

  IF v_founder_count < 1 THEN
    RAISE EXCEPTION
      'Organization % would be left with zero active organization-wide Founders',
      p_organization_id;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.lsh_member_role_grants_founder_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP IN ('DELETE', 'UPDATE') THEN
    PERFORM public.lsh_assert_founder_coverage(OLD.organization_id);
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE')
     AND (
       TG_OP = 'INSERT'
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
     ) THEN
    PERFORM public.lsh_assert_founder_coverage(NEW.organization_id);
  END IF;

  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER member_role_grants_founder_coverage_guard
  AFTER INSERT OR UPDATE OR DELETE
  ON public.member_role_grants
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_member_role_grants_founder_guard();

CREATE OR REPLACE FUNCTION public.lsh_organization_members_founder_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP IN ('DELETE', 'UPDATE') THEN
    PERFORM public.lsh_assert_founder_coverage(OLD.organization_id);
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
    PERFORM public.lsh_assert_founder_coverage(NEW.organization_id);
  END IF;

  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER organization_members_founder_coverage_guard
  AFTER UPDATE OR DELETE
  ON public.organization_members
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_organization_members_founder_guard();

CREATE OR REPLACE FUNCTION public.lsh_organization_activation_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status = 'active'::public.organization_status
     AND NEW.deleted_at IS NULL THEN
    PERFORM public.lsh_assert_founder_coverage(NEW.id);
  END IF;

  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER organizations_founder_coverage_guard
  AFTER INSERT OR UPDATE
  ON public.organizations
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.lsh_organization_activation_guard();

-- ============================================================
-- 7. Permission-resolution helpers and read RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.current_organization_member(
  p_organization_id uuid
)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT m.id
  FROM public.organization_members m
  JOIN public.organizations o
    ON o.id = m.organization_id
  WHERE m.user_id = auth.uid()
    AND m.organization_id = p_organization_id
    AND m.status = 'active'::public.member_status
    AND o.status = 'active'::public.organization_status
    AND o.deleted_at IS NULL
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_user_organization_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT DISTINCT m.organization_id
  FROM public.organization_members m
  JOIN public.organizations o
    ON o.id = m.organization_id
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
      OR (
        b.id IS NOT NULL
        AND b.deleted_at IS NULL
        AND b.status = 'active'::public.branch_status
      )
    );
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
    JOIN public.role_permissions rp
      ON rp.role_id = g.role_id
    JOIN public.permissions p
      ON p.id = rp.permission_id
    LEFT JOIN public.branches b
      ON b.id = g.branch_id
     AND b.organization_id = g.organization_id
    WHERE g.organization_id = p_organization_id
      AND g.organization_member_id =
          public.current_organization_member(p_organization_id)
      AND g.revoked_at IS NULL
      AND p.key = p_permission_key
      AND (
        g.branch_id IS NULL
        OR (
          p_branch_id IS NOT NULL
          AND g.branch_id = p_branch_id
          AND b.id IS NOT NULL
          AND b.deleted_at IS NULL
          AND b.status = 'active'::public.branch_status
        )
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
  SELECT
    EXISTS (
      SELECT 1
      FROM public.member_role_grants g
      LEFT JOIN public.branches b
        ON b.id = g.branch_id
       AND b.organization_id = g.organization_id
      WHERE g.organization_id = p_organization_id
        AND g.organization_member_id =
            public.current_organization_member(p_organization_id)
        AND g.revoked_at IS NULL
        AND (
          g.branch_id IS NULL
          OR (
            g.branch_id = p_branch_id
            AND b.id IS NOT NULL
            AND b.deleted_at IS NULL
            AND b.status = 'active'::public.branch_status
          )
        )
    )
    AND EXISTS (
      SELECT 1
      FROM public.branches b2
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
  JOIN public.role_permissions rp
    ON rp.role_id = g.role_id
  JOIN public.permissions p
    ON p.id = rp.permission_id
  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id
  WHERE g.organization_id = p_organization_id
    AND g.organization_member_id =
        public.current_organization_member(p_organization_id)
    AND g.revoked_at IS NULL
    AND (
      g.branch_id IS NULL
      OR (
        p_branch_id IS NOT NULL
        AND g.branch_id = p_branch_id
        AND b.id IS NOT NULL
        AND b.deleted_at IS NULL
        AND b.status = 'active'::public.branch_status
      )
    )
  ORDER BY p.key;
$$;

CREATE OR REPLACE FUNCTION public.my_membership(
  p_organization_id uuid
)
RETURNS TABLE (
  organization_id      uuid,
  organization_name    text,
  member_status        public.member_status,
  display_name         text,
  email                text,
  phone                text,
  joined_at            timestamptz,
  assigned_role_keys   text[],
  assigned_role_labels text[],
  branch_names         text[],
  organization_wide    boolean
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
    COALESCE(
      array_agg(DISTINCT r.key)
        FILTER (WHERE r.key IS NOT NULL),
      ARRAY[]::text[]
    ),
    COALESCE(
      array_agg(DISTINCT r.label)
        FILTER (WHERE r.label IS NOT NULL),
      ARRAY[]::text[]
    ),
    COALESCE(
      array_agg(DISTINCT b.name)
        FILTER (WHERE b.name IS NOT NULL),
      ARRAY[]::text[]
    ),
    COALESCE(bool_or(g.branch_id IS NULL), false)
  FROM public.organization_members m
  JOIN public.organizations o
    ON o.id = m.organization_id
  LEFT JOIN public.member_role_grants g
    ON g.organization_member_id = m.id
   AND g.organization_id = m.organization_id
   AND g.revoked_at IS NULL
  LEFT JOIN public.roles r
    ON r.id = g.role_id
  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id
   AND b.deleted_at IS NULL
   AND b.status = 'active'::public.branch_status
  WHERE m.organization_id = p_organization_id
    AND m.user_id = auth.uid()
  GROUP BY
    m.organization_id,
    o.display_name,
    m.status,
    m.display_name,
    m.email,
    m.phone,
    m.joined_at;
$$;

CREATE OR REPLACE FUNCTION public.team_directory(
  p_organization_id uuid
)
RETURNS TABLE (
  member_status         public.member_status,
  display_name          text,
  email                 text,
  phone                 text,
  joined_at             timestamptz,
  assigned_role_keys    text[],
  assigned_role_labels  text[],
  assigned_branch_names text[],
  organization_wide     boolean
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
    COALESCE(
      array_agg(DISTINCT r.key)
        FILTER (WHERE r.key IS NOT NULL),
      ARRAY[]::text[]
    ),
    COALESCE(
      array_agg(DISTINCT r.label)
        FILTER (WHERE r.label IS NOT NULL),
      ARRAY[]::text[]
    ),
    COALESCE(
      array_agg(DISTINCT b.name)
        FILTER (WHERE b.name IS NOT NULL),
      ARRAY[]::text[]
    ),
    COALESCE(bool_or(g.branch_id IS NULL), false)
  FROM public.organization_members m
  LEFT JOIN public.member_role_grants g
    ON g.organization_member_id = m.id
   AND g.organization_id = m.organization_id
   AND g.revoked_at IS NULL
  LEFT JOIN public.roles r
    ON r.id = g.role_id
  LEFT JOIN public.branches b
    ON b.id = g.branch_id
   AND b.organization_id = g.organization_id
   AND b.deleted_at IS NULL
   AND b.status = 'active'::public.branch_status
  WHERE m.organization_id = p_organization_id
    AND public.has_permission(
      p_organization_id,
      'team.read',
      NULL
    )
    AND m.status IN (
      'active'::public.member_status,
      'suspended'::public.member_status
    )
  GROUP BY
    m.id,
    m.status,
    m.display_name,
    m.email,
    m.phone,
    m.joined_at
  ORDER BY m.display_name NULLS LAST, m.id;
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
  SELECT
    r.key,
    r.label,
    r.description,
    r.sort_order
  FROM public.roles r
  ORDER BY r.sort_order, r.key;
$$;

-- ============================================================
-- 8. Replace Wave 1A deny-all policies with scoped reads
-- ============================================================

DROP POLICY IF EXISTS organizations_deny_all_authenticated
  ON public.organizations;

DROP POLICY IF EXISTS organization_settings_deny_all_authenticated
  ON public.organization_settings;

DROP POLICY IF EXISTS branches_deny_all_authenticated
  ON public.branches;

CREATE POLICY organizations_read_authenticated
  ON public.organizations
  FOR SELECT
  TO authenticated
  USING (
    public.has_permission(id, 'org.read', NULL)
  );

CREATE POLICY organization_settings_read_authenticated
  ON public.organization_settings
  FOR SELECT
  TO authenticated
  USING (
    public.has_permission(organization_id, 'org.read', NULL)
  );

CREATE POLICY branches_read_authenticated
  ON public.branches
  FOR SELECT
  TO authenticated
  USING (
    public.has_branch_scope(organization_id, id)
  );

ALTER TABLE public.organization_members
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.member_role_grants
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_role_grants
  FORCE ROW LEVEL SECURITY;

CREATE POLICY organization_members_deny_all_authenticated
  ON public.organization_members
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY member_role_grants_deny_all_authenticated
  ON public.member_role_grants
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

-- ============================================================
-- 9. Privileges
-- ============================================================

REVOKE ALL ON TABLE public.permissions
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.roles
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.role_permissions
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.organization_members
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.member_role_grants
  FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.permissions
  TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.roles
  TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.role_permissions
  TO service_role;
GRANT ALL
  ON TABLE public.organization_members
  TO service_role;
GRANT ALL
  ON TABLE public.member_role_grants
  TO service_role;

REVOKE ALL
  ON TABLE public.organizations,
           public.organization_settings,
           public.branches
  FROM anon, authenticated;

GRANT SELECT
  ON TABLE public.organizations,
           public.organization_settings,
           public.branches
  TO authenticated;

REVOKE ALL ON FUNCTION public.current_organization_member(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_organization_ids()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_permission(uuid, text, uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_branch_scope(uuid, uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.effective_permissions(uuid, uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.my_membership(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.team_directory(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.role_catalogue()
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.current_organization_member(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_user_organization_ids()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_permission(uuid, text, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_branch_scope(uuid, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.effective_permissions(uuid, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.my_membership(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.team_directory(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.role_catalogue()
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.lsh_reject_branch_scoped_founder()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lsh_assert_founder_coverage(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lsh_member_role_grants_founder_guard()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lsh_organization_members_founder_guard()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lsh_organization_activation_guard()
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.lsh_reject_branch_scoped_founder()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.lsh_assert_founder_coverage(uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.lsh_member_role_grants_founder_guard()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.lsh_organization_members_founder_guard()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.lsh_organization_activation_guard()
  TO service_role;

-- ============================================================
-- 10. Validation gates
-- ============================================================

DO $$
DECLARE
  v_count integer;
  v_enum_values text[];
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 38 THEN
    RAISE EXCEPTION
      'Validation failed: permissions count % does not equal 38',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.roles;

  IF v_count <> 11 THEN
    RAISE EXCEPTION
      'Validation failed: roles count % does not equal 11',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 139 THEN
    RAISE EXCEPTION
      'Validation failed: role_permissions count % does not equal 139',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions rp
  JOIN public.roles r
    ON r.id = rp.role_id
  WHERE r.key = 'founder';

  IF v_count <> 38 THEN
    RAISE EXCEPTION
      'Validation failed: Founder permission count % does not equal 38',
      v_count;
  END IF;

  SELECT array_agg(e.enumlabel::text ORDER BY e.enumsortorder)
  INTO v_enum_values
  FROM pg_enum e
  JOIN pg_type t
    ON t.oid = e.enumtypid
  JOIN pg_namespace n
    ON n.oid = t.typnamespace
  WHERE n.nspname = 'public'
    AND t.typname = 'member_status';

  IF v_enum_values IS DISTINCT FROM
     ARRAY['active','suspended','left','revoked']::text[] THEN
    RAISE EXCEPTION
      'Validation failed: member_status values are %',
      v_enum_values;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_constraint c
  WHERE c.connamespace = 'public'::regnamespace
    AND c.conrelid = 'public.branches'::regclass
    AND c.conname = 'branches_id_organization_id_key'
    AND c.contype = 'u';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Validation failed: branches composite unique constraint missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'permissions',
      'roles',
      'role_permissions',
      'organization_members',
      'member_role_grants'
    )
    AND c.relkind = 'r'
    AND c.relrowsecurity
    AND c.relforcerowsecurity;

  IF v_count <> 5 THEN
    RAISE EXCEPTION
      'Validation failed: expected five new FORCE RLS tables, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND (
      (tablename = 'organizations'
       AND policyname = 'organizations_read_authenticated')
      OR
      (tablename = 'organization_settings'
       AND policyname = 'organization_settings_read_authenticated')
      OR
      (tablename = 'branches'
       AND policyname = 'branches_read_authenticated')
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Validation failed: scoped organization read policies count is %',
      v_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN (
        'organizations_deny_all_authenticated',
        'organization_settings_deny_all_authenticated',
        'branches_deny_all_authenticated'
      )
  ) THEN
    RAISE EXCEPTION
      'Validation failed: one or more Wave 1A deny-all policies remain';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants
    WHERE table_schema = 'public'
      AND table_name IN (
        'permissions',
        'roles',
        'role_permissions',
        'organization_members',
        'member_role_grants'
      )
      AND grantee IN ('anon', 'authenticated')
  ) THEN
    RAISE EXCEPTION
      'Validation failed: direct client privileges exist on protected access-control tables';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n
    ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prosecdef
    AND p.proname IN (
      'lsh_reject_branch_scoped_founder',
      'lsh_assert_founder_coverage',
      'lsh_member_role_grants_founder_guard',
      'lsh_organization_members_founder_guard',
      'lsh_organization_activation_guard',
      'current_organization_member',
      'current_user_organization_ids',
      'has_permission',
      'has_branch_scope',
      'effective_permissions',
      'my_membership',
      'team_directory',
      'role_catalogue'
    )
    AND NOT (
      'search_path=""' = ANY(
        COALESCE(p.proconfig, ARRAY[]::text[])
      )
    );

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Validation failed: % SECURITY DEFINER functions lack empty search_path',
      v_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.member_role_grants g
    JOIN public.roles r
      ON r.id = g.role_id
    WHERE r.key = 'founder'
      AND g.branch_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION
      'Validation failed: branch-scoped Founder grant exists';
  END IF;
END
$$;

COMMIT;