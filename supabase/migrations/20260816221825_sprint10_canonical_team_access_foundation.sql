-- =====================================================================
-- Little Shots by Hema OS
-- Sprint 10 Slice 7B — Canonical Team Access Mutation Foundation
--
-- Purpose:
--   - Replace the legacy team/invite mutation contract with canonical
--     organization membership and role-grant primitives.
--   - Keep organization_members and member_role_grants closed to direct
--     authenticated writes.
--   - Store invitation credentials only as SHA-256 hashes.
--   - Permit token preview without exposing the token hash.
--   - Create membership and pre-authorized role grants atomically when
--     an authenticated invitee accepts an invitation.
--   - Provide explicit audited role grant/revoke RPCs.
--   - Provide Team projections that include canonical member IDs.
--
-- Explicitly out of scope:
--   - Team UI/runtime cutover.
--   - Legacy studio_invites/user_roles deletion.
--   - Production deployment/write.
--   - Member suspension/reinstatement.
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
  v_role_count integer;
  v_permission_count integer;
BEGIN
  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.branches') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.member_role_grants') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.audit_events') IS NULL THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: canonical access-control/audit substrate is missing';
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
       'public.lsh_set_updated_at()'
     ) IS NULL
     OR to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: canonical helper/RPC contract is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_extension e
    JOIN pg_namespace n
      ON n.oid = e.extnamespace
    WHERE e.extname = 'pgcrypto'
      AND n.nspname = 'extensions'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: pgcrypto must exist in extensions schema';
  END IF;

  IF to_regprocedure(
       'extensions.digest(text,text)'
     ) IS NULL
     OR to_regprocedure(
       'extensions.gen_random_bytes(integer)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: required pgcrypto functions are unavailable';
  END IF;

  SELECT count(*)
  INTO v_role_count
  FROM public.roles;

  IF v_role_count <> 12 THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: expected 12 canonical roles, found %',
      v_role_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles
    WHERE key = 'videographer'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: canonical videographer role is missing';
  END IF;

  SELECT count(*)
  INTO v_permission_count
  FROM public.permissions
  WHERE key IN (
    'team.read',
    'team.invite',
    'team.role.assign',
    'team.suspend'
  );

  IF v_permission_count <> 4 THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: canonical Team permission set is incomplete';
  END IF;

  IF to_regclass(
       'public.organization_invitations'
     ) IS NOT NULL
     OR to_regclass(
       'public.organization_invitation_roles'
     ) IS NOT NULL
     OR to_regtype(
       'public.organization_invitation_status'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Slice 7B precondition failed: invitation foundation already exists';
  END IF;
END
$preconditions$;


-- =====================================================================
-- 2. Invitation lifecycle
-- =====================================================================

CREATE TYPE public.organization_invitation_status AS ENUM (
  'pending',
  'accepted',
  'revoked'
);


-- =====================================================================
-- 3. Canonical organization invitations
-- =====================================================================

CREATE TABLE public.organization_invitations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   uuid NOT NULL,

  email             text NOT NULL,
  full_name         text,

  -- Raw invitation tokens are NEVER stored.
  -- SHA-256 = 32 bytes.
  token_hash        bytea NOT NULL,

  status            public.organization_invitation_status
                    NOT NULL
                    DEFAULT 'pending',

  expires_at        timestamptz NOT NULL,

  invited_by        uuid NOT NULL,

  accepted_at       timestamptz,
  accepted_by       uuid,

  revoked_at        timestamptz,
  revoked_by        uuid,
  revocation_reason text,

  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT organization_invitations_organization_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_invitations_invited_by_fkey
    FOREIGN KEY (invited_by, organization_id)
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_invitations_accepted_by_fkey
    FOREIGN KEY (accepted_by, organization_id)
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_invitations_revoked_by_fkey
    FOREIGN KEY (revoked_by, organization_id)
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_invitations_id_org_key
    UNIQUE (id, organization_id),

  CONSTRAINT organization_invitations_token_hash_key
    UNIQUE (token_hash),

  CONSTRAINT organization_invitations_email_normalized_chk
    CHECK (
      email = lower(btrim(email))
      AND email ~*
        '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    ),

  CONSTRAINT organization_invitations_full_name_chk
    CHECK (
      full_name IS NULL
      OR (
        btrim(full_name) <> ''
        AND char_length(btrim(full_name))
            BETWEEN 1 AND 160
      )
    ),

  CONSTRAINT organization_invitations_token_hash_length_chk
    CHECK (octet_length(token_hash) = 32),

  CONSTRAINT organization_invitations_expiry_chk
    CHECK (expires_at > created_at),

  CONSTRAINT organization_invitations_revocation_reason_chk
    CHECK (
      revocation_reason IS NULL
      OR (
        btrim(revocation_reason) <> ''
        AND char_length(btrim(revocation_reason))
            <= 500
      )
    ),

  CONSTRAINT organization_invitations_state_chk
    CHECK (
      (
        status = 'pending'
        AND accepted_at IS NULL
        AND accepted_by IS NULL
        AND revoked_at IS NULL
        AND revoked_by IS NULL
        AND revocation_reason IS NULL
      )
      OR
      (
        status = 'accepted'
        AND accepted_at IS NOT NULL
        AND accepted_by IS NOT NULL
        AND revoked_at IS NULL
        AND revoked_by IS NULL
        AND revocation_reason IS NULL
      )
      OR
      (
        status = 'revoked'
        AND accepted_at IS NULL
        AND accepted_by IS NULL
        AND revoked_at IS NOT NULL
        AND revoked_by IS NOT NULL
        AND revocation_reason IS NOT NULL
      )
    )
);

CREATE UNIQUE INDEX organization_invitations_pending_email_uidx
ON public.organization_invitations (
  organization_id,
  lower(email)
)
WHERE status = 'pending';

CREATE INDEX organization_invitations_org_created_idx
ON public.organization_invitations (
  organization_id,
  created_at DESC
);

CREATE INDEX organization_invitations_org_status_idx
ON public.organization_invitations (
  organization_id,
  status,
  expires_at
);

COMMENT ON COLUMN public.organization_invitations.token_hash IS
  'SHA-256 hash of the invitation credential. Raw invitation tokens are never persisted.';


-- =====================================================================
-- 4. Invitation role assignments
-- =====================================================================

CREATE TABLE public.organization_invitation_roles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  invitation_id   uuid NOT NULL,
  role_id         uuid NOT NULL,
  branch_id       uuid,

  assigned_at     timestamptz NOT NULL DEFAULT now(),
  assigned_by     uuid NOT NULL,

  CONSTRAINT organization_invitation_roles_invitation_fkey
    FOREIGN KEY (invitation_id, organization_id)
    REFERENCES public.organization_invitations (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_invitation_roles_role_fkey
    FOREIGN KEY (role_id)
    REFERENCES public.roles (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_invitation_roles_branch_fkey
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_invitation_roles_assigned_by_fkey
    FOREIGN KEY (assigned_by, organization_id)
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

CREATE UNIQUE INDEX organization_invitation_roles_orgwide_uidx
ON public.organization_invitation_roles (
  invitation_id,
  role_id
)
WHERE branch_id IS NULL;

CREATE UNIQUE INDEX organization_invitation_roles_branch_uidx
ON public.organization_invitation_roles (
  invitation_id,
  role_id,
  branch_id
)
WHERE branch_id IS NOT NULL;

CREATE INDEX organization_invitation_roles_invitation_idx
ON public.organization_invitation_roles (
  organization_id,
  invitation_id
);


-- =====================================================================
-- 5. Lifecycle guards
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_organization_invitations_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'organization invitation deletion is not permitted'
      USING ERRCODE = '42501';
  END IF;

  IF OLD.status <> 'pending'::public.organization_invitation_status
     AND NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION
      'accepted or revoked invitations are immutable'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.email IS DISTINCT FROM OLD.email
     OR NEW.full_name IS DISTINCT FROM OLD.full_name
     OR NEW.token_hash IS DISTINCT FROM OLD.token_hash
     OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
     OR NEW.invited_by IS DISTINCT FROM OLD.invited_by
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION
      'organization invitation identity fields are immutable'
      USING ERRCODE = '42501';
  END IF;

  IF OLD.status = 'pending'::public.organization_invitation_status
     AND NEW.status NOT IN (
       'pending'::public.organization_invitation_status,
       'accepted'::public.organization_invitation_status,
       'revoked'::public.organization_invitation_status
     ) THEN
    RAISE EXCEPTION
      'invalid organization invitation lifecycle transition'
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END
$function$;

CREATE TRIGGER organization_invitations_20_guard
BEFORE UPDATE OR DELETE
ON public.organization_invitations
FOR EACH ROW
EXECUTE FUNCTION public.lsh_organization_invitations_guard();

CREATE TRIGGER organization_invitations_90_updated_at
BEFORE UPDATE
ON public.organization_invitations
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();


CREATE OR REPLACE FUNCTION public.lsh_organization_invitation_roles_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_role_key text;
  v_invitation_status public.organization_invitation_status;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION
      'organization invitation role assignments are immutable'
      USING ERRCODE = '42501';
  END IF;

  SELECT i.status
  INTO v_invitation_status
  FROM public.organization_invitations i
  WHERE i.id = NEW.invitation_id
    AND i.organization_id = NEW.organization_id;

  IF v_invitation_status IS NULL
     OR v_invitation_status <>
        'pending'::public.organization_invitation_status THEN
    RAISE EXCEPTION
      'roles may only be assigned to pending invitations'
      USING ERRCODE = '22023';
  END IF;

  SELECT r.key
  INTO v_role_key
  FROM public.roles r
  WHERE r.id = NEW.role_id;

  IF v_role_key IS NULL THEN
    RAISE EXCEPTION
      'invitation role does not exist'
      USING ERRCODE = '22023';
  END IF;

  IF v_role_key = 'founder'
     AND NEW.branch_id IS NOT NULL THEN
    RAISE EXCEPTION
      'Founder invitation roles must be organization-wide'
      USING ERRCODE = '22023';
  END IF;

  IF NEW.branch_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.branches b
       WHERE b.id = NEW.branch_id
         AND b.organization_id = NEW.organization_id
         AND b.status = 'active'
         AND b.deleted_at IS NULL
     ) THEN
    RAISE EXCEPTION
      'invitation branch scope must reference an active branch'
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END
$function$;

CREATE TRIGGER organization_invitation_roles_20_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.organization_invitation_roles
FOR EACH ROW
EXECUTE FUNCTION public.lsh_organization_invitation_roles_guard();


-- =====================================================================
-- 6. RLS and table privileges
-- =====================================================================

ALTER TABLE public.organization_invitations
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invitations
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.organization_invitation_roles
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invitation_roles
  FORCE ROW LEVEL SECURITY;

CREATE POLICY organization_invitations_deny_all_authenticated
ON public.organization_invitations
FOR ALL
TO authenticated
USING (false)
WITH CHECK (false);

CREATE POLICY organization_invitation_roles_deny_all_authenticated
ON public.organization_invitation_roles
FOR ALL
TO authenticated
USING (false)
WITH CHECK (false);

REVOKE ALL
ON TABLE public.organization_invitations
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON TABLE public.organization_invitation_roles
FROM PUBLIC, anon, authenticated;

GRANT ALL
ON TABLE public.organization_invitations
TO service_role;

GRANT ALL
ON TABLE public.organization_invitation_roles
TO service_role;


-- =====================================================================
-- 7. Canonical Team directory with member IDs
-- =====================================================================

CREATE OR REPLACE FUNCTION public.team_access_directory(
  p_organization_id uuid
)
RETURNS TABLE (
  member_id             uuid,
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
AS $function$
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
        WHERE g.organization_id = m.organization_id
          AND g.organization_member_id = m.id
          AND g.revoked_at IS NULL
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
        WHERE g.organization_id = m.organization_id
          AND g.organization_member_id = m.id
          AND g.revoked_at IS NULL
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
         AND b.organization_id = g.organization_id
        WHERE g.organization_id = m.organization_id
          AND g.organization_member_id = m.id
          AND g.revoked_at IS NULL
          AND b.deleted_at IS NULL
          AND b.status = 'active'
      ),
      ARRAY[]::text[]
    ),

    EXISTS (
      SELECT 1
      FROM public.member_role_grants g
      WHERE g.organization_id = m.organization_id
        AND g.organization_member_id = m.id
        AND g.revoked_at IS NULL
        AND g.branch_id IS NULL
    )

  FROM public.organization_members m
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
  ORDER BY
    m.display_name NULLS LAST,
    m.id;
$function$;


-- =====================================================================
-- 8. Invitation directory
-- =====================================================================

CREATE OR REPLACE FUNCTION public.team_invitation_directory(
  p_organization_id uuid
)
RETURNS TABLE (
  invitation_id    uuid,
  email            text,
  full_name        text,
  invitation_status text,
  expires_at       timestamptz,
  created_at       timestamptz,
  role_keys        text[],
  role_labels      text[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
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
        WHERE ir.organization_id = i.organization_id
          AND ir.invitation_id = i.id
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
        WHERE ir.organization_id = i.organization_id
          AND ir.invitation_id = i.id
      ),
      ARRAY[]::text[]
    )

  FROM public.organization_invitations i
  WHERE i.organization_id = p_organization_id
    AND public.has_permission(
      p_organization_id,
      'team.invite',
      NULL
    )
  ORDER BY i.created_at DESC;
$function$;


-- =====================================================================
-- 9. Create invitation
--
-- team.invite:
--   required to create/revoke invitations.
--
-- team.role.assign:
--   additionally required when pre-authorizing roles.
--
-- A studio manager may therefore create an invitation without role
-- assignments, while role assignment remains separately governed.
-- =====================================================================

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

  IF NOT public.has_permission(
    p_organization_id,
    'team.invite',
    NULL
  ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: team.invite permission required'
      USING ERRCODE = '42501';
  END IF;

  v_email :=
    lower(NULLIF(btrim(p_email), ''));

  v_full_name :=
    NULLIF(btrim(p_full_name), '');

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
    ) AS supplied(role_key)
    WHERE supplied.role_key IS NULL
       OR btrim(supplied.role_key) = ''
  ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: role keys cannot be null or blank'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(
    array_agg(
      DISTINCT lower(btrim(supplied.role_key))
      ORDER BY lower(btrim(supplied.role_key))
    ),
    ARRAY[]::text[]
  )
  INTO v_role_keys
  FROM unnest(
    COALESCE(
      p_role_keys,
      ARRAY[]::text[]
    )
  ) AS supplied(role_key);

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
    FROM unnest(v_role_keys) AS supplied(role_key)
    LEFT JOIN public.roles r
      ON r.key = supplied.role_key
    WHERE r.id IS NULL
  ) THEN
    RAISE EXCEPTION
      'create_organization_invitation: one or more role keys are invalid'
      USING ERRCODE = '22023';
  END IF;

  -- Reissuing an invite invalidates previous pending credentials
  -- for the same organization/email.
  FOR v_superseded_id IN
    UPDATE public.organization_invitations i
    SET
      status =
        'revoked'::public.organization_invitation_status,
      revoked_at = now(),
      revoked_by = v_actor,
      revocation_reason =
        'Superseded by a newer invitation'
    WHERE i.organization_id = p_organization_id
      AND i.email = v_email
      AND i.status =
          'pending'::public.organization_invitation_status
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
        hours => p_expires_in_hours
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
  WHERE r.key = ANY(v_role_keys);

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


-- =====================================================================
-- 10. Revoke invitation
-- =====================================================================

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

  IF NOT public.has_permission(
    p_organization_id,
    'team.invite',
    NULL
  ) THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: team.invite permission required'
      USING ERRCODE = '42501';
  END IF;

  v_reason :=
    NULLIF(btrim(p_reason), '');

  IF v_reason IS NULL
     OR char_length(v_reason) > 500 THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: a reason up to 500 characters is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT i.*
  INTO v_invitation
  FROM public.organization_invitations i
  WHERE i.id = p_invitation_id
    AND i.organization_id = p_organization_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'revoke_organization_invitation: invitation not found'
      USING ERRCODE = '22023';
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
    revoked_at = now(),
    revoked_by = v_actor,
    revocation_reason = v_reason
  WHERE id = p_invitation_id
    AND organization_id = p_organization_id;

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


-- =====================================================================
-- 11. Token-gated public invitation preview
--
-- Does not reveal:
--   - token_hash
--   - invitation ID
--   - inviter member ID
--   - internal audit data
-- =====================================================================

CREATE OR REPLACE FUNCTION public.preview_organization_invitation(
  p_token text
)
RETURNS TABLE (
  organization_name text,
  email text,
  full_name text,
  role_keys text[],
  role_labels text[],
  expires_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH supplied_token AS (
    SELECT
      extensions.digest(
        lower(btrim(p_token)),
        'sha256'
      ) AS token_hash
    WHERE p_token IS NOT NULL
      AND lower(btrim(p_token))
          ~ '^[0-9a-f]{64}$'
  )
  SELECT
    o.display_name,
    i.email,
    i.full_name,

    COALESCE(
      (
        SELECT array_agg(
          r.key
          ORDER BY r.sort_order, r.key
        )
        FROM public.organization_invitation_roles ir
        JOIN public.roles r
          ON r.id = ir.role_id
        WHERE ir.organization_id = i.organization_id
          AND ir.invitation_id = i.id
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
        WHERE ir.organization_id = i.organization_id
          AND ir.invitation_id = i.id
      ),
      ARRAY[]::text[]
    ),

    i.expires_at

  FROM supplied_token t
  JOIN public.organization_invitations i
    ON i.token_hash = t.token_hash
  JOIN public.organizations o
    ON o.id = i.organization_id
  WHERE i.status =
        'pending'::public.organization_invitation_status
    AND i.expires_at > now()
    AND o.status = 'active'
    AND o.deleted_at IS NULL;
$function$;


-- =====================================================================
-- 12. Accept invitation
-- =====================================================================

CREATE OR REPLACE FUNCTION public.accept_organization_invitation(
  p_token text
)
RETURNS TABLE (
  member_id uuid,
  assigned_role_keys text[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid;
  v_auth_email text;
  v_email_confirmed_at timestamptz;
  v_token_hash bytea;

  v_invitation public.organization_invitations%ROWTYPE;

  v_member_id uuid;
  v_member_status public.member_status;

  v_role_keys text[];

  v_new_grant record;
  v_role_key text;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION
      'accept_organization_invitation: authentication required'
      USING ERRCODE = '42501';
  END IF;

  IF p_token IS NULL
     OR lower(btrim(p_token))
        !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION
      'accept_organization_invitation: invitation is invalid or unavailable'
      USING ERRCODE = '22023';
  END IF;

  v_token_hash :=
    extensions.digest(
      lower(btrim(p_token)),
      'sha256'
    );

  SELECT i.*
  INTO v_invitation
  FROM public.organization_invitations i
  JOIN public.organizations o
    ON o.id = i.organization_id
  WHERE i.token_hash = v_token_hash
    AND o.status = 'active'
    AND o.deleted_at IS NULL
  FOR UPDATE OF i;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'accept_organization_invitation: invitation is invalid or unavailable'
      USING ERRCODE = '22023';
  END IF;

  IF v_invitation.status <>
     'pending'::public.organization_invitation_status THEN
    RAISE EXCEPTION
      'accept_organization_invitation: invitation is no longer pending'
      USING ERRCODE = '22023';
  END IF;

  IF v_invitation.expires_at <= now() THEN
    RAISE EXCEPTION
      'accept_organization_invitation: invitation has expired'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    u.email,
    u.email_confirmed_at
  INTO
    v_auth_email,
    v_email_confirmed_at
  FROM auth.users u
  WHERE u.id = v_user_id;

  IF NOT FOUND
     OR v_auth_email IS NULL THEN
    RAISE EXCEPTION
      'accept_organization_invitation: authenticated user record is unavailable'
      USING ERRCODE = '42501';
  END IF;

  IF v_email_confirmed_at IS NULL THEN
    RAISE EXCEPTION
      'accept_organization_invitation: email confirmation is required'
      USING ERRCODE = '42501';
  END IF;

  IF lower(v_auth_email) <>
     lower(v_invitation.email) THEN
    RAISE EXCEPTION
      'accept_organization_invitation: invitation belongs to a different email address'
      USING ERRCODE = '42501';
  END IF;

  SELECT
    m.id,
    m.status
  INTO
    v_member_id,
    v_member_status
  FROM public.organization_members m
  WHERE m.organization_id =
        v_invitation.organization_id
    AND m.user_id = v_user_id
  FOR UPDATE;

  IF v_member_id IS NULL THEN
    INSERT INTO public.organization_members (
      organization_id,
      user_id,
      status,
      display_name,
      email,
      joined_at,
      created_by,
      updated_by
    )
    VALUES (
      v_invitation.organization_id,
      v_user_id,
      'active'::public.member_status,
      v_invitation.full_name,
      lower(v_auth_email),
      now(),
      v_invitation.invited_by,
      v_invitation.invited_by
    )
    RETURNING id
    INTO v_member_id;
  ELSE
    IF v_member_status <>
       'active'::public.member_status THEN
      RAISE EXCEPTION
        'accept_organization_invitation: existing membership is not active and requires administrative review'
        USING ERRCODE = '42501';
    END IF;

    UPDATE public.organization_members
    SET
      email = lower(v_auth_email),
      display_name =
        COALESCE(
          display_name,
          v_invitation.full_name
        ),
      updated_by = v_member_id
    WHERE id = v_member_id
      AND organization_id =
          v_invitation.organization_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.organization_invitation_roles ir
    LEFT JOIN public.branches b
      ON b.id = ir.branch_id
     AND b.organization_id = ir.organization_id
    WHERE ir.organization_id =
          v_invitation.organization_id
      AND ir.invitation_id =
          v_invitation.id
      AND ir.branch_id IS NOT NULL
      AND (
        b.id IS NULL
        OR b.deleted_at IS NOT NULL
        OR b.status <> 'active'
      )
  ) THEN
    RAISE EXCEPTION
      'accept_organization_invitation: one or more assigned branch scopes are no longer active'
      USING ERRCODE = '22023';
  END IF;

  FOR v_new_grant IN
    INSERT INTO public.member_role_grants (
      organization_id,
      organization_member_id,
      role_id,
      branch_id,
      granted_by
    )
    SELECT
      ir.organization_id,
      v_member_id,
      ir.role_id,
      ir.branch_id,
      ir.assigned_by
    FROM public.organization_invitation_roles ir
    WHERE ir.organization_id =
          v_invitation.organization_id
      AND ir.invitation_id =
          v_invitation.id
      AND NOT EXISTS (
        SELECT 1
        FROM public.member_role_grants g
        WHERE g.organization_id =
              ir.organization_id
          AND g.organization_member_id =
              v_member_id
          AND g.role_id =
              ir.role_id
          AND g.branch_id
              IS NOT DISTINCT FROM
              ir.branch_id
          AND g.revoked_at IS NULL
      )
    RETURNING
      id,
      role_id,
      branch_id,
      granted_by
  LOOP
    SELECT r.key
    INTO v_role_key
    FROM public.roles r
    WHERE r.id = v_new_grant.role_id;

    PERFORM public.append_audit_event(
      v_invitation.organization_id,
      v_new_grant.branch_id,
      'team.role.granted',
      'member_role_grant',
      v_new_grant.id,
      true,
      NULL,
      NULL,
      jsonb_build_object(
        'role_key',
        v_role_key,
        'source_invitation_id',
        v_invitation.id,
        'authorized_by_member_id',
        v_new_grant.granted_by
      ),
      'team_access',
      NULL
    );
  END LOOP;

  SELECT COALESCE(
    array_agg(
      r.key
      ORDER BY r.sort_order, r.key
    ),
    ARRAY[]::text[]
  )
  INTO v_role_keys
  FROM public.organization_invitation_roles ir
  JOIN public.roles r
    ON r.id = ir.role_id
  WHERE ir.organization_id =
        v_invitation.organization_id
    AND ir.invitation_id =
        v_invitation.id;

  UPDATE public.organization_invitations
  SET
    status =
      'accepted'::public.organization_invitation_status,
    accepted_at = now(),
    accepted_by = v_member_id
  WHERE id = v_invitation.id
    AND organization_id =
        v_invitation.organization_id;

  PERFORM public.append_audit_event(
    v_invitation.organization_id,
    NULL,
    'team.invitation.accepted',
    'organization_invitation',
    v_invitation.id,
    true,
    NULL,
    NULL,
    jsonb_build_object(
      'role_keys',
      to_jsonb(v_role_keys)
    ),
    'team_access',
    NULL
  );

  RETURN QUERY
  SELECT
    v_member_id,
    v_role_keys;
END
$function$;


-- =====================================================================
-- 13. Direct canonical role grant
-- =====================================================================

CREATE OR REPLACE FUNCTION public.grant_organization_member_role(
  p_organization_id uuid,
  p_member_id uuid,
  p_role_key text,
  p_branch_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_role_id uuid;
  v_role_key text;
  v_grant_id uuid;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'grant_organization_member_role: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    p_organization_id,
    'team.role.assign',
    p_branch_id
  ) THEN
    RAISE EXCEPTION
      'grant_organization_member_role: team.role.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_members m
    WHERE m.id = p_member_id
      AND m.organization_id = p_organization_id
      AND m.status = 'active'
      AND m.exited_at IS NULL
  ) THEN
    RAISE EXCEPTION
      'grant_organization_member_role: target must be an active member of this organization'
      USING ERRCODE = '22023';
  END IF;

  v_role_key :=
    lower(NULLIF(btrim(p_role_key), ''));

  SELECT r.id
  INTO v_role_id
  FROM public.roles r
  WHERE r.key = v_role_key;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION
      'grant_organization_member_role: role does not exist'
      USING ERRCODE = '22023';
  END IF;

  IF v_role_key = 'founder'
     AND p_branch_id IS NOT NULL THEN
    RAISE EXCEPTION
      'grant_organization_member_role: Founder must be organization-wide'
      USING ERRCODE = '22023';
  END IF;

  IF p_branch_id IS NOT NULL THEN
    IF NOT public.has_branch_scope(
      p_organization_id,
      p_branch_id
    ) THEN
      RAISE EXCEPTION
        'grant_organization_member_role: no access to requested branch'
        USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.branches b
      WHERE b.id = p_branch_id
        AND b.organization_id = p_organization_id
        AND b.status = 'active'
        AND b.deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION
        'grant_organization_member_role: branch must be active'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT g.id
  INTO v_grant_id
  FROM public.member_role_grants g
  WHERE g.organization_id = p_organization_id
    AND g.organization_member_id = p_member_id
    AND g.role_id = v_role_id
    AND g.branch_id
        IS NOT DISTINCT FROM
        p_branch_id
    AND g.revoked_at IS NULL;

  IF v_grant_id IS NOT NULL THEN
    RETURN v_grant_id;
  END IF;

  INSERT INTO public.member_role_grants (
    organization_id,
    organization_member_id,
    role_id,
    branch_id,
    granted_by
  )
  VALUES (
    p_organization_id,
    p_member_id,
    v_role_id,
    p_branch_id,
    v_actor
  )
  RETURNING id
  INTO v_grant_id;

  PERFORM public.append_audit_event(
    p_organization_id,
    p_branch_id,
    'team.role.granted',
    'member_role_grant',
    v_grant_id,
    true,
    NULL,
    NULL,
    jsonb_build_object(
      'role_key',
      v_role_key,
      'target_member_id',
      p_member_id
    ),
    'team_access',
    NULL
  );

  RETURN v_grant_id;
END
$function$;


-- =====================================================================
-- 14. Direct canonical role revocation
-- =====================================================================

CREATE OR REPLACE FUNCTION public.revoke_organization_member_role(
  p_organization_id uuid,
  p_member_id uuid,
  p_role_key text,
  p_branch_id uuid DEFAULT NULL,
  p_reason text DEFAULT 'Role removed'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_role_id uuid;
  v_role_key text;
  v_reason text;
  v_grant_id uuid;
BEGIN
  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'revoke_organization_member_role: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    p_organization_id,
    'team.role.assign',
    p_branch_id
  ) THEN
    RAISE EXCEPTION
      'revoke_organization_member_role: team.role.assign permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_members m
    WHERE m.id = p_member_id
      AND m.organization_id = p_organization_id
  ) THEN
    RAISE EXCEPTION
      'revoke_organization_member_role: target member does not belong to this organization'
      USING ERRCODE = '22023';
  END IF;

  v_role_key :=
    lower(NULLIF(btrim(p_role_key), ''));

  SELECT r.id
  INTO v_role_id
  FROM public.roles r
  WHERE r.key = v_role_key;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION
      'revoke_organization_member_role: role does not exist'
      USING ERRCODE = '22023';
  END IF;

  v_reason :=
    NULLIF(btrim(p_reason), '');

  IF v_reason IS NULL
     OR char_length(v_reason) > 500 THEN
    RAISE EXCEPTION
      'revoke_organization_member_role: a reason up to 500 characters is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT g.id
  INTO v_grant_id
  FROM public.member_role_grants g
  WHERE g.organization_id = p_organization_id
    AND g.organization_member_id = p_member_id
    AND g.role_id = v_role_id
    AND g.branch_id
        IS NOT DISTINCT FROM
        p_branch_id
    AND g.revoked_at IS NULL
  FOR UPDATE;

  IF v_grant_id IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.member_role_grants
  SET
    revoked_at = now(),
    revoked_by = v_actor,
    revocation_reason = v_reason
  WHERE id = v_grant_id;

  PERFORM public.append_audit_event(
    p_organization_id,
    p_branch_id,
    'team.role.revoked',
    'member_role_grant',
    v_grant_id,
    true,
    NULL,
    NULL,
    jsonb_build_object(
      'role_key',
      v_role_key,
      'target_member_id',
      p_member_id,
      'reason',
      v_reason
    ),
    'team_access',
    NULL
  );

  -- Existing deferred Founder-coverage trigger remains the final
  -- database-level authority. Revoking the final active Founder
  -- will therefore roll the entire RPC transaction back.

  RETURN true;
END
$function$;


-- =====================================================================
-- 15. Function privileges
-- =====================================================================

REVOKE ALL
ON FUNCTION public.team_access_directory(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.team_access_directory(uuid)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.team_invitation_directory(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.team_invitation_directory(uuid)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.create_organization_invitation(
  uuid,
  text,
  text,
  text[],
  integer
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.create_organization_invitation(
  uuid,
  text,
  text,
  text[],
  integer
)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.revoke_organization_invitation(
  uuid,
  uuid,
  text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.revoke_organization_invitation(
  uuid,
  uuid,
  text
)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.preview_organization_invitation(text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.preview_organization_invitation(text)
TO anon, authenticated, service_role;


REVOKE ALL
ON FUNCTION public.accept_organization_invitation(text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.accept_organization_invitation(text)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.grant_organization_member_role(
  uuid,
  uuid,
  text,
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.grant_organization_member_role(
  uuid,
  uuid,
  text,
  uuid
)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.revoke_organization_member_role(
  uuid,
  uuid,
  text,
  uuid,
  text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.revoke_organization_member_role(
  uuid,
  uuid,
  text,
  uuid,
  text
)
TO authenticated, service_role;


REVOKE ALL
ON FUNCTION public.lsh_organization_invitations_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_organization_invitation_roles_guard()
FROM PUBLIC, anon, authenticated;


-- =====================================================================
-- 16. Validation gates
-- =====================================================================

DO $validation$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'organization_invitations',
      'organization_invitation_roles'
    )
    AND c.relkind = 'r'
    AND c.relrowsecurity = true
    AND c.relforcerowsecurity = true;

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: both invitation tables must use FORCE RLS';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.organization_invitations',
       'SELECT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organization_invitations',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organization_invitations',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organization_invitations',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: authenticated must have no direct organization_invitations privileges';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.organization_invitation_roles',
       'SELECT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organization_invitation_roles',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organization_invitation_roles',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.organization_invitation_roles',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: authenticated must have no direct organization_invitation_roles privileges';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'organization_invitations'
      AND column_name = 'token'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: raw invitation token column must not exist';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'organization_invitations'
      AND column_name = 'token_hash'
      AND data_type = 'bytea'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: bytea token_hash column is required';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.team_access_directory(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: authenticated must execute team_access_directory';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.team_invitation_directory(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: authenticated must execute team_invitation_directory';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.create_organization_invitation(uuid,text,text,text[],integer)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: authenticated must execute create_organization_invitation';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.accept_organization_invitation(text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: authenticated must execute accept_organization_invitation';
  END IF;

  IF NOT has_function_privilege(
    'anon',
    'public.preview_organization_invitation(text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: anon must execute token-gated invitation preview';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.create_organization_invitation(uuid,text,text,text[],integer)',
    'EXECUTE'
  )
     OR has_function_privilege(
       'anon',
       'public.accept_organization_invitation(text)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'anon',
       'public.grant_organization_member_role(uuid,uuid,text,uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'anon',
       'public.revoke_organization_member_role(uuid,uuid,text,uuid,text)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Slice 7B validation failed: anon must not execute Team mutation RPCs';
  END IF;
END
$validation$;


COMMIT;
