BEGIN;

CREATE TABLE public.permissions (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key                         text NOT NULL UNIQUE,
  domain                      text NOT NULL,
  label                       text NOT NULL,
  description                 text,
  requires_server_enforcement boolean NOT NULL DEFAULT false,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT permissions_key_format   CHECK (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  CONSTRAINT permissions_domain_format CHECK (domain ~ '^[a-z][a-z0-9_]*$'),
  CONSTRAINT permissions_label_len    CHECK (char_length(label) BETWEEN 1 AND 120)
);
REVOKE ALL ON TABLE public.permissions FROM anon, authenticated;

CREATE TABLE public.roles (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key            text NOT NULL UNIQUE,
  label          text NOT NULL,
  description    text,
  sort_order     integer NOT NULL DEFAULT 0,
  is_system_role boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT roles_key_format CHECK (key ~ '^[a-z][a-z0-9_]*$'),
  CONSTRAINT roles_label_len  CHECK (char_length(label) BETWEEN 1 AND 120)
);
REVOKE ALL ON TABLE public.roles FROM anon, authenticated;

CREATE TABLE public.role_permissions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id       uuid NOT NULL REFERENCES public.roles(id)       ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT role_permissions_unique UNIQUE (role_id, permission_id)
);
REVOKE ALL ON TABLE public.role_permissions FROM anon, authenticated;

CREATE INDEX role_permissions_role_id_idx       ON public.role_permissions (role_id);
CREATE INDEX role_permissions_permission_id_idx ON public.role_permissions (permission_id);

ALTER TABLE public.permissions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions      FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.roles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles            FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions FORCE  ROW LEVEL SECURITY;

CREATE POLICY permissions_deny_all_authenticated
  ON public.permissions      FOR ALL TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY roles_deny_all_authenticated
  ON public.roles            FOR ALL TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY role_permissions_deny_all_authenticated
  ON public.role_permissions FOR ALL TO authenticated USING (false) WITH CHECK (false);

INSERT INTO public.permissions (key, domain, label, description, requires_server_enforcement) VALUES
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
  ('audit.sensitive.read','governance','Read sensitive audit logs','Read consent, finance and role-change audit history.',true)
ON CONFLICT (key) DO UPDATE
  SET domain = EXCLUDED.domain,
      label = EXCLUDED.label,
      description = EXCLUDED.description,
      requires_server_enforcement = EXCLUDED.requires_server_enforcement;

INSERT INTO public.roles (key, label, description, sort_order, is_system_role) VALUES
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
  ('accounts','Accounts','Processes approved invoices, payments and refunds.',110,true)
ON CONFLICT (key) DO UPDATE
  SET label = EXCLUDED.label,
      description = EXCLUDED.description,
      sort_order = EXCLUDED.sort_order,
      is_system_role = EXCLUDED.is_system_role;

CREATE TEMP TABLE lsh_seed_role_permission_map (role_key text NOT NULL, permission_key text NOT NULL) ON COMMIT DROP;

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
DECLARE v_dupes int; v_bad_role int; v_bad_perm int; v_expected int;
BEGIN
  SELECT count(*) INTO v_dupes FROM (
    SELECT role_key, permission_key FROM lsh_seed_role_permission_map
    GROUP BY 1,2 HAVING count(*) > 1
  ) d;
  IF v_dupes > 0 THEN RAISE EXCEPTION 'Migration B aborted: % duplicate mapping rows in canonical source', v_dupes; END IF;

  SELECT count(DISTINCT m.role_key) INTO v_bad_role
  FROM lsh_seed_role_permission_map m
  LEFT JOIN public.roles r ON r.key = m.role_key WHERE r.id IS NULL;
  IF v_bad_role > 0 THEN RAISE EXCEPTION 'Migration B aborted: % unknown role key(s) in canonical source', v_bad_role; END IF;

  SELECT count(DISTINCT m.permission_key) INTO v_bad_perm
  FROM lsh_seed_role_permission_map m
  LEFT JOIN public.permissions p ON p.key = m.permission_key WHERE p.id IS NULL;
  IF v_bad_perm > 0 THEN RAISE EXCEPTION 'Migration B aborted: % unknown permission key(s) in canonical source', v_bad_perm; END IF;

  SELECT count(*) INTO v_expected FROM lsh_seed_role_permission_map;
  IF v_expected <> 139 THEN RAISE EXCEPTION 'Migration B aborted: canonical mapping count % <> approved 139', v_expected; END IF;
END $$;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM lsh_seed_role_permission_map m
JOIN public.roles r       ON r.key = m.role_key
JOIN public.permissions p ON p.key = m.permission_key
ON CONFLICT (role_id, permission_id) DO NOTHING;

DO $$
DECLARE v_missing int; v_unexpected int; v_total int; v_perms int; v_roles int;
BEGIN
  SELECT count(*) INTO v_perms FROM public.permissions;
  IF v_perms <> 38 THEN RAISE EXCEPTION 'Migration B aborted: permissions count % <> 38', v_perms; END IF;

  SELECT count(*) INTO v_roles FROM public.roles;
  IF v_roles <> 11 THEN RAISE EXCEPTION 'Migration B aborted: roles count % <> 11', v_roles; END IF;

  SELECT count(*) INTO v_missing
  FROM lsh_seed_role_permission_map m
  JOIN public.roles r       ON r.key = m.role_key
  JOIN public.permissions p ON p.key = m.permission_key
  LEFT JOIN public.role_permissions rp ON rp.role_id = r.id AND rp.permission_id = p.id
  WHERE rp.id IS NULL;
  IF v_missing > 0 THEN RAISE EXCEPTION 'Migration B aborted: % approved mapping(s) missing after seed', v_missing; END IF;

  SELECT count(*) INTO v_unexpected
  FROM public.role_permissions rp
  JOIN public.roles r       ON r.id = rp.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  LEFT JOIN lsh_seed_role_permission_map m
    ON m.role_key = r.key AND m.permission_key = p.key
  WHERE m.role_key IS NULL;
  IF v_unexpected > 0 THEN
    RAISE EXCEPTION 'Migration B aborted: % unexpected mapping(s) present; removals require explicit Founder approval', v_unexpected;
  END IF;

  SELECT count(*) INTO v_total FROM public.role_permissions;
  IF v_total <> 139 THEN RAISE EXCEPTION 'Migration B aborted: seeded mapping count % <> canonical 139', v_total; END IF;
END $$;

REVOKE ALL ON TABLE public.permissions      FROM anon, authenticated;
REVOKE ALL ON TABLE public.roles            FROM anon, authenticated;
REVOKE ALL ON TABLE public.role_permissions FROM anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.permissions      TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.roles            TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.role_permissions TO service_role;

COMMIT;