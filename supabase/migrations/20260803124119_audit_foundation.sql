BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '180s';

-- ============================================================
-- Audit Foundation
-- Append-only, tenant-scoped application audit history.
-- ============================================================

-- 1. Preconditions
DO $pre$
BEGIN
  IF to_regclass('public.organizations') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.organizations is missing';
  END IF;

  IF to_regclass('public.organization_members') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.organization_members is missing';
  END IF;

  IF to_regclass('public.branches') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: public.branches is missing';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: current_organization_member(uuid) is missing';
  END IF;

  IF to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Precondition failed: has_permission(uuid,text,uuid) is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.permissions
    WHERE key = 'audit.read'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: audit.read permission is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.permissions
    WHERE key = 'audit.sensitive.read'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: audit.sensitive.read permission is missing';
  END IF;
END
$pre$;

-- 2. Audit table
CREATE TABLE public.audit_events (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       uuid NOT NULL,
  branch_id             uuid,
  actor_member_id       uuid,
  actor_user_id         uuid,
  action_key            text NOT NULL,
  entity_type           text NOT NULL,
  entity_id             uuid,
  is_sensitive          boolean NOT NULL DEFAULT false,
  old_values            jsonb,
  new_values            jsonb,
  metadata              jsonb NOT NULL DEFAULT '{}'::jsonb,
  source                text NOT NULL DEFAULT 'application',
  request_id            uuid,
  occurred_at           timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT audit_events_action_key_chk
    CHECK (
      length(action_key) BETWEEN 3 AND 120
      AND action_key ~ '^[a-z0-9]+([._:-][a-z0-9]+)*$'
    ),

  CONSTRAINT audit_events_entity_type_chk
    CHECK (
      length(entity_type) BETWEEN 2 AND 80
      AND entity_type ~ '^[a-z][a-z0-9_]*$'
    ),

  CONSTRAINT audit_events_source_chk
    CHECK (
      length(source) BETWEEN 2 AND 80
      AND source ~ '^[a-z][a-z0-9_.:-]*$'
    ),

  CONSTRAINT audit_events_old_values_object_chk
    CHECK (
      old_values IS NULL
      OR jsonb_typeof(old_values) = 'object'
    ),

  CONSTRAINT audit_events_new_values_object_chk
    CHECK (
      new_values IS NULL
      OR jsonb_typeof(new_values) = 'object'
    ),

  CONSTRAINT audit_events_metadata_object_chk
    CHECK (jsonb_typeof(metadata) = 'object'),

  CONSTRAINT audit_events_change_payload_chk
    CHECK (
      old_values IS NOT NULL
      OR new_values IS NOT NULL
      OR metadata <> '{}'::jsonb
    ),

  CONSTRAINT audit_events_branch_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT audit_events_actor_member_fk
    FOREIGN KEY (actor_member_id, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT audit_events_organization_fk
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT
);

COMMENT ON TABLE public.audit_events IS
  'Append-only application audit history. Payloads must be pre-redacted by the caller.';

COMMENT ON COLUMN public.audit_events.old_values IS
  'Redacted prior values only. Must not contain passwords, tokens, secrets, or unrestricted PII.';

COMMENT ON COLUMN public.audit_events.new_values IS
  'Redacted new values only. Must not contain passwords, tokens, secrets, or unrestricted PII.';

COMMENT ON COLUMN public.audit_events.metadata IS
  'Structured non-secret context such as field names, reason codes, or integration identifiers.';

-- 3. Indexes
CREATE INDEX audit_events_organization_occurred_idx
  ON public.audit_events (organization_id, occurred_at DESC);

CREATE INDEX audit_events_branch_occurred_idx
  ON public.audit_events (organization_id, branch_id, occurred_at DESC)
  WHERE branch_id IS NOT NULL;

CREATE INDEX audit_events_entity_idx
  ON public.audit_events (organization_id, entity_type, entity_id, occurred_at DESC);

CREATE INDEX audit_events_actor_member_idx
  ON public.audit_events (organization_id, actor_member_id, occurred_at DESC)
  WHERE actor_member_id IS NOT NULL;

CREATE INDEX audit_events_sensitive_idx
  ON public.audit_events (organization_id, occurred_at DESC)
  WHERE is_sensitive = true;

CREATE INDEX audit_events_action_idx
  ON public.audit_events (organization_id, action_key, occurred_at DESC);

CREATE INDEX audit_events_request_idx
  ON public.audit_events (request_id)
  WHERE request_id IS NOT NULL;

-- 4. Payload redaction guard
CREATE OR REPLACE FUNCTION public.lsh_assert_audit_payload_safe(
  p_payload jsonb,
  p_label text
)
RETURNS void
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_forbidden_key text;
BEGIN
  IF p_payload IS NULL THEN
    RETURN;
  END IF;

  IF jsonb_typeof(p_payload) <> 'object' THEN
    RAISE EXCEPTION '% must be a JSON object', p_label;
  END IF;

  SELECT key
  INTO v_forbidden_key
  FROM jsonb_object_keys(p_payload) AS key
  WHERE lower(key) IN (
    'password',
    'password_hash',
    'access_token',
    'refresh_token',
    'token',
    'secret',
    'api_key',
    'service_role_key',
    'private_key',
    'authorization',
    'cookie',
    'session'
  )
  LIMIT 1;

  IF v_forbidden_key IS NOT NULL THEN
    RAISE EXCEPTION
      '% contains forbidden sensitive key: %',
      p_label,
      v_forbidden_key;
  END IF;
END
$$;

-- 5. Append-only mutation guard
CREATE OR REPLACE FUNCTION public.lsh_audit_events_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION
    'audit_events is append-only; UPDATE and DELETE are not permitted';
END
$$;

CREATE TRIGGER audit_events_immutable_update
BEFORE UPDATE ON public.audit_events
FOR EACH ROW
EXECUTE FUNCTION public.lsh_audit_events_immutable_guard();

CREATE TRIGGER audit_events_immutable_delete
BEFORE DELETE ON public.audit_events
FOR EACH ROW
EXECUTE FUNCTION public.lsh_audit_events_immutable_guard();

-- 6. Controlled append RPC
CREATE OR REPLACE FUNCTION public.append_audit_event(
  p_organization_id uuid,
  p_branch_id uuid,
  p_action_key text,
  p_entity_type text,
  p_entity_id uuid,
  p_is_sensitive boolean,
  p_old_values jsonb,
  p_new_values jsonb,
  p_metadata jsonb,
  p_source text,
  p_request_id uuid
)
RETURNS public.audit_events
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_member_id uuid;
  v_actor_user_id uuid;
  v_event public.audit_events;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'organization_id is required';
  END IF;

  IF p_action_key IS NULL OR btrim(p_action_key) = '' THEN
    RAISE EXCEPTION 'action_key is required';
  END IF;

  IF p_entity_type IS NULL OR btrim(p_entity_type) = '' THEN
    RAISE EXCEPTION 'entity_type is required';
  END IF;

  IF p_metadata IS NULL THEN
    p_metadata := '{}'::jsonb;
  END IF;

  IF p_source IS NULL OR btrim(p_source) = '' THEN
    p_source := 'application';
  END IF;

  PERFORM public.lsh_assert_audit_payload_safe(p_old_values, 'old_values');
  PERFORM public.lsh_assert_audit_payload_safe(p_new_values, 'new_values');
  PERFORM public.lsh_assert_audit_payload_safe(p_metadata, 'metadata');

  v_actor_user_id := auth.uid();

  IF v_actor_user_id IS NOT NULL THEN
    v_actor_member_id :=
      public.current_organization_member(p_organization_id);

    IF v_actor_member_id IS NULL THEN
      RAISE EXCEPTION
        'Authenticated user is not an active member of organization %',
        p_organization_id;
    END IF;
  END IF;

  INSERT INTO public.audit_events (
    organization_id,
    branch_id,
    actor_member_id,
    actor_user_id,
    action_key,
    entity_type,
    entity_id,
    is_sensitive,
    old_values,
    new_values,
    metadata,
    source,
    request_id
  )
  VALUES (
    p_organization_id,
    p_branch_id,
    v_actor_member_id,
    v_actor_user_id,
    lower(btrim(p_action_key)),
    lower(btrim(p_entity_type)),
    p_entity_id,
    COALESCE(p_is_sensitive, false),
    p_old_values,
    p_new_values,
    p_metadata,
    lower(btrim(p_source)),
    p_request_id
  )
  RETURNING *
  INTO v_event;

  RETURN v_event;
END
$$;

-- 7. RLS
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events FORCE ROW LEVEL SECURITY;

CREATE POLICY audit_events_select_scoped
ON public.audit_events
FOR SELECT
TO authenticated
USING (
  CASE
    WHEN is_sensitive THEN
      public.has_permission(
        organization_id,
        'audit.sensitive.read',
        branch_id
      )
    ELSE
      public.has_permission(
        organization_id,
        'audit.read',
        branch_id
      )
  END
);

-- 8. Privileges
REVOKE ALL PRIVILEGES
ON TABLE public.audit_events
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.audit_events
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE public.audit_events
TO service_role;

REVOKE ALL
ON FUNCTION public.append_audit_event(
  uuid,
  uuid,
  text,
  text,
  uuid,
  boolean,
  jsonb,
  jsonb,
  jsonb,
  text,
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.append_audit_event(
  uuid,
  uuid,
  text,
  text,
  uuid,
  boolean,
  jsonb,
  jsonb,
  jsonb,
  text,
  uuid
)
TO service_role;

REVOKE ALL
ON FUNCTION public.lsh_assert_audit_payload_safe(jsonb,text)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_audit_events_immutable_guard()
FROM PUBLIC, anon, authenticated;

-- 9. Validation gates
DO $validation$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'audit_events';

  IF v_count <> 15 THEN
    RAISE EXCEPTION
      'Validation failed: audit_events must have exactly 15 columns, found %',
      v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'audit_events'
      AND c.relrowsecurity = true
      AND c.relforcerowsecurity = true
  ) THEN
    RAISE EXCEPTION
      'Validation failed: audit_events must have RLS and FORCE RLS enabled';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'audit_events';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Validation failed: audit_events must have exactly one policy, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM information_schema.triggers
  WHERE trigger_schema = 'public'
    AND event_object_table = 'audit_events';

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Validation failed: audit_events must have exactly two triggers, found %',
      v_count;
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.audit_events',
    'INSERT'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: authenticated must not have direct INSERT on audit_events';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.audit_events',
    'UPDATE'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: authenticated must not have UPDATE on audit_events';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.audit_events',
    'DELETE'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: authenticated must not have DELETE on audit_events';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.audit_events',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: authenticated must have SELECT on audit_events';
  END IF;

  IF has_function_privilege(
    'authenticated',
    'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: authenticated must not execute append_audit_event';
  END IF;

  IF NOT has_function_privilege(
    'service_role',
    'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Validation failed: service_role must execute append_audit_event';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions
    WHERE key IN ('audit.read', 'audit.sensitive.read')
    GROUP BY key
    HAVING count(*) <> 1
  ) THEN
    RAISE EXCEPTION
      'Validation failed: audit permissions are not unique';
  END IF;
END
$validation$;

COMMIT;
