-- =====================================================================
-- Little Shots by Hema — Little Moments OS
-- Role-Aware Interactive Training Foundation
--
-- T1 — Training Foundation
--
-- Governing principles:
--   * training observes authorization; it never grants authorization;
--   * real client/domain records are never used as training state;
--   * authenticated users cannot directly mutate training tables;
--   * training completion is server-authoritative;
--   * rollout gate defaults OFF;
--   * no member, role, branch, booking, payment, quote, shoot, or
--     selection authority is changed by this migration.
-- =====================================================================

BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '180s';


-- =====================================================================
-- 1. Preconditions and mutation-delta snapshot
-- =====================================================================

DO $preconditions$
BEGIN
  IF to_regclass('public.organizations') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.member_role_grants') IS NULL
     OR to_regclass('public.roles') IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL
     OR to_regclass('public.branches') IS NULL
     OR to_regclass('public.audit_events') IS NULL THEN
    RAISE EXCEPTION
      'T1 precondition failed: canonical organization/access/audit substrate is incomplete';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_permission_in_any_live_scope(uuid,text)'
     ) IS NULL
     OR to_regprocedure(
       'public.lsh_set_updated_at()'
     ) IS NULL THEN
    RAISE EXCEPTION
      'T1 precondition failed: canonical authorization/update helpers are incomplete';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.roles
    WHERE key = 'founder'
  ) THEN
    RAISE EXCEPTION
      'T1 precondition failed: Founder role is missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions
    WHERE key = 'training.read'
  ) THEN
    RAISE EXCEPTION
      'T1 precondition failed: training.read already exists';
  END IF;

  IF to_regclass('public.organization_training_settings') IS NOT NULL
     OR to_regclass('public.training_modules') IS NOT NULL
     OR to_regclass('public.training_module_steps') IS NOT NULL
     OR to_regclass('public.member_training_profiles') IS NOT NULL
     OR to_regclass('public.training_scenario_instances') IS NOT NULL
     OR to_regclass('public.training_step_events') IS NOT NULL THEN
    RAISE EXCEPTION
      'T1 precondition failed: one or more training foundation tables already exist';
  END IF;

  IF to_regtype('public.training_gate_mode') IS NOT NULL
     OR to_regtype('public.training_profile_status') IS NOT NULL
     OR to_regtype('public.training_scenario_status') IS NOT NULL
     OR to_regtype('public.training_step_type') IS NOT NULL
     OR to_regtype('public.training_step_event_type') IS NOT NULL
     OR to_regtype('public.training_step_event_result') IS NOT NULL THEN
    RAISE EXCEPTION
      'T1 precondition failed: one or more training foundation enum types already exist';
  END IF;
END
$preconditions$;


CREATE TEMP TABLE t1_training_pre_counts (
  key text PRIMARY KEY,
  value bigint NOT NULL
) ON COMMIT DROP;

INSERT INTO t1_training_pre_counts (key, value)
VALUES
(
  'permissions',
  (SELECT count(*) FROM public.permissions)
),
(
  'role_permissions',
  (SELECT count(*) FROM public.role_permissions)
),
(
  'member_role_grants',
  (SELECT count(*) FROM public.member_role_grants)
);


-- =====================================================================
-- 2. Training enums
-- =====================================================================

CREATE TYPE public.training_gate_mode AS ENUM (
  'off',
  'soft',
  'required'
);

CREATE TYPE public.training_profile_status AS ENUM (
  'not_started',
  'in_progress',
  'practice_pending',
  'knowledge_check_pending',
  'complete',
  'retraining_required'
);

CREATE TYPE public.training_scenario_status AS ENUM (
  'not_started',
  'in_progress',
  'complete'
);

CREATE TYPE public.training_step_type AS ENUM (
  'orientation',
  'navigation',
  'privacy',
  'evidence',
  'escalation',
  'help',
  'practice',
  'knowledge_check'
);

CREATE TYPE public.training_step_event_type AS ENUM (
  'step_viewed',
  'step_completed',
  'action_attempted',
  'action_passed',
  'action_failed',
  'hint_opened',
  'scenario_started',
  'scenario_reset',
  'scenario_completed',
  'knowledge_check_answered',
  'training_step_broken',
  'module_completed'
);

CREATE TYPE public.training_step_event_result AS ENUM (
  'pass',
  'fail',
  'info'
);


-- =====================================================================
-- 3. Organization-level rollout settings
-- =====================================================================

CREATE TABLE public.organization_training_settings (
  organization_id uuid PRIMARY KEY,

  gate_mode public.training_gate_mode
    NOT NULL DEFAULT 'off',

  first_job_assist_count smallint
    NOT NULL DEFAULT 3,

  created_at timestamptz
    NOT NULL DEFAULT now(),

  updated_at timestamptz
    NOT NULL DEFAULT now(),

  updated_by uuid NULL,

  CONSTRAINT organization_training_settings_organization_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT organization_training_settings_updated_by_fkey
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT organization_training_settings_first_job_assist_count_chk
    CHECK (
      first_job_assist_count >= 0
      AND first_job_assist_count <= 20
    )
);


-- =====================================================================
-- 4. Training module catalogue
-- =====================================================================

CREATE TABLE public.training_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  role_id uuid NULL,

  module_key text NOT NULL,

  version integer NOT NULL,

  title text NOT NULL,

  required boolean NOT NULL DEFAULT true,

  active boolean NOT NULL DEFAULT true,

  minimum_score smallint NOT NULL DEFAULT 100,

  created_at timestamptz NOT NULL DEFAULT now(),

  updated_at timestamptz NOT NULL DEFAULT now(),

  updated_by uuid NULL,

  CONSTRAINT training_modules_organization_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT training_modules_role_fkey
    FOREIGN KEY (role_id)
    REFERENCES public.roles (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT training_modules_updated_by_fkey
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT training_modules_id_organization_key
    UNIQUE (id, organization_id),

  CONSTRAINT training_modules_org_key_version_key
    UNIQUE (organization_id, module_key, version),

  CONSTRAINT training_modules_module_key_chk
    CHECK (
      module_key ~ '^[a-z][a-z0-9_-]*$'
    ),

  CONSTRAINT training_modules_version_chk
    CHECK (version > 0),

  CONSTRAINT training_modules_title_chk
    CHECK (
      char_length(btrim(title)) >= 1
      AND char_length(title) <= 160
    ),

  CONSTRAINT training_modules_minimum_score_chk
    CHECK (
      minimum_score >= 0
      AND minimum_score <= 100
    )
);


-- =====================================================================
-- 5. Training module completion contract
-- =====================================================================

CREATE TABLE public.training_module_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  training_module_id uuid NOT NULL,

  step_key text NOT NULL,

  step_order integer NOT NULL,

  step_type public.training_step_type NOT NULL,

  required boolean NOT NULL DEFAULT true,

  completion_event_type public.training_step_event_type
    NOT NULL DEFAULT 'step_completed',

  completion_result public.training_step_event_result
    NOT NULL DEFAULT 'pass',

  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT training_module_steps_module_fkey
    FOREIGN KEY (training_module_id, organization_id)
    REFERENCES public.training_modules (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE CASCADE,

  CONSTRAINT training_module_steps_module_step_key
    UNIQUE (training_module_id, step_key),

  CONSTRAINT training_module_steps_module_order_key
    UNIQUE (training_module_id, step_order),

  CONSTRAINT training_module_steps_step_key_chk
    CHECK (
      step_key ~ '^[a-z][a-z0-9_-]*$'
    ),

  CONSTRAINT training_module_steps_step_order_chk
    CHECK (step_order > 0)
);


-- =====================================================================
-- 6. Member training state
-- =====================================================================

CREATE TABLE public.member_training_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  organization_member_id uuid NOT NULL,

  training_module_id uuid NOT NULL,

  status public.training_profile_status
    NOT NULL DEFAULT 'not_started',

  current_step_key text NULL,

  required_at timestamptz NULL,

  started_at timestamptz NULL,

  completed_at timestamptz NULL,

  signed_off_by uuid NULL,

  signed_off_at timestamptz NULL,

  work_ready_at timestamptz NULL,

  retraining_reason text NULL,

  created_at timestamptz NOT NULL DEFAULT now(),

  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT member_training_profiles_member_fkey
    FOREIGN KEY (organization_member_id, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_training_profiles_module_fkey
    FOREIGN KEY (training_module_id, organization_id)
    REFERENCES public.training_modules (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_training_profiles_signed_off_by_fkey
    FOREIGN KEY (signed_off_by, organization_id)
    REFERENCES public.organization_members (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_training_profiles_current_step_fkey
    FOREIGN KEY (training_module_id, current_step_key)
    REFERENCES public.training_module_steps (
      training_module_id,
      step_key
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT member_training_profiles_member_module_key
    UNIQUE (
      organization_member_id,
      training_module_id
    ),

  CONSTRAINT member_training_profiles_id_org_member_key
    UNIQUE (
      id,
      organization_id,
      organization_member_id
    ),

  CONSTRAINT member_training_profiles_started_state_chk
    CHECK (
      status = 'not_started'
      OR started_at IS NOT NULL
    ),

  CONSTRAINT member_training_profiles_complete_state_chk
    CHECK (
      status <> 'complete'
      OR completed_at IS NOT NULL
    ),

  CONSTRAINT member_training_profiles_signoff_state_chk
    CHECK (
      (
        signed_off_by IS NULL
        AND signed_off_at IS NULL
      )
      OR
      (
        signed_off_by IS NOT NULL
        AND signed_off_at IS NOT NULL
      )
    ),

  CONSTRAINT member_training_profiles_work_ready_chk
    CHECK (
      work_ready_at IS NULL
      OR (
        completed_at IS NOT NULL
        AND signed_off_at IS NOT NULL
      )
    ),

  CONSTRAINT member_training_profiles_retraining_reason_chk
    CHECK (
      retraining_reason IS NULL
      OR btrim(retraining_reason) <> ''
    )
);


-- =====================================================================
-- 7. Isolated synthetic scenario state
-- =====================================================================

CREATE TABLE public.training_scenario_instances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  organization_member_id uuid NOT NULL,

  member_training_profile_id uuid NOT NULL,

  scenario_key text NOT NULL,

  scenario_version integer NOT NULL,

  scenario_state jsonb NOT NULL DEFAULT '{}'::jsonb,

  status public.training_scenario_status
    NOT NULL DEFAULT 'not_started',

  started_at timestamptz NULL,

  completed_at timestamptz NULL,

  reset_count integer NOT NULL DEFAULT 0,

  created_at timestamptz NOT NULL DEFAULT now(),

  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT training_scenario_instances_profile_fkey
    FOREIGN KEY (
      member_training_profile_id,
      organization_id,
      organization_member_id
    )
    REFERENCES public.member_training_profiles (
      id,
      organization_id,
      organization_member_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT training_scenario_instances_member_fkey
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

  CONSTRAINT training_scenario_instances_identity_key
    UNIQUE (
      organization_member_id,
      scenario_key,
      scenario_version
    ),

  CONSTRAINT training_scenario_instances_composite_key
    UNIQUE (
      id,
      organization_id,
      organization_member_id,
      member_training_profile_id
    ),

  CONSTRAINT training_scenario_instances_scenario_key_chk
    CHECK (
      scenario_key ~ '^[a-z][a-z0-9_-]*$'
    ),

  CONSTRAINT training_scenario_instances_version_chk
    CHECK (scenario_version > 0),

  CONSTRAINT training_scenario_instances_state_object_chk
    CHECK (
      jsonb_typeof(scenario_state) = 'object'
    ),

  CONSTRAINT training_scenario_instances_state_size_chk
    CHECK (
      octet_length(scenario_state::text) <= 65536
    ),

  CONSTRAINT training_scenario_instances_reset_count_chk
    CHECK (reset_count >= 0),

  CONSTRAINT training_scenario_instances_started_state_chk
    CHECK (
      status = 'not_started'
      OR started_at IS NOT NULL
    ),

  CONSTRAINT training_scenario_instances_complete_state_chk
    CHECK (
      status <> 'complete'
      OR completed_at IS NOT NULL
    )
);


-- =====================================================================
-- 8. Immutable training evidence
-- =====================================================================

CREATE TABLE public.training_step_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id uuid NOT NULL,

  organization_member_id uuid NOT NULL,

  member_training_profile_id uuid NOT NULL,

  training_scenario_instance_id uuid NULL,

  step_key text NOT NULL,

  event_type public.training_step_event_type NOT NULL,

  result public.training_step_event_result NULL,

  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,

  occurred_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT training_step_events_profile_fkey
    FOREIGN KEY (
      member_training_profile_id,
      organization_id,
      organization_member_id
    )
    REFERENCES public.member_training_profiles (
      id,
      organization_id,
      organization_member_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT training_step_events_scenario_fkey
    FOREIGN KEY (
      training_scenario_instance_id,
      organization_id,
      organization_member_id,
      member_training_profile_id
    )
    REFERENCES public.training_scenario_instances (
      id,
      organization_id,
      organization_member_id,
      member_training_profile_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT training_step_events_step_key_chk
    CHECK (
      char_length(btrim(step_key)) >= 1
      AND char_length(step_key) <= 120
    ),

  CONSTRAINT training_step_events_metadata_object_chk
    CHECK (
      jsonb_typeof(metadata) = 'object'
    ),

  CONSTRAINT training_step_events_metadata_size_chk
    CHECK (
      octet_length(metadata::text) <= 4096
    )
);


-- =====================================================================
-- 9. Indexes
-- =====================================================================

CREATE INDEX training_modules_org_role_active_idx
ON public.training_modules (
  organization_id,
  role_id,
  active
);

CREATE UNIQUE INDEX training_modules_one_active_common_version_idx
ON public.training_modules (
  organization_id,
  module_key
)
WHERE active = true
  AND role_id IS NULL;

CREATE UNIQUE INDEX training_modules_one_active_role_version_idx
ON public.training_modules (
  organization_id,
  module_key,
  role_id
)
WHERE active = true
  AND role_id IS NOT NULL;

CREATE INDEX training_module_steps_module_order_idx
ON public.training_module_steps (
  training_module_id,
  step_order
);

CREATE INDEX member_training_profiles_member_status_idx
ON public.member_training_profiles (
  organization_member_id,
  status
);

CREATE INDEX member_training_profiles_org_status_idx
ON public.member_training_profiles (
  organization_id,
  status
);

CREATE INDEX training_scenario_instances_member_status_idx
ON public.training_scenario_instances (
  organization_member_id,
  status
);

CREATE INDEX training_step_events_profile_occurred_idx
ON public.training_step_events (
  member_training_profile_id,
  occurred_at
);

CREATE INDEX training_step_events_member_occurred_idx
ON public.training_step_events (
  organization_member_id,
  occurred_at
);


-- =====================================================================
-- 10. updated_at triggers
-- =====================================================================

CREATE TRIGGER organization_training_settings_set_updated_at
BEFORE UPDATE
ON public.organization_training_settings
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER training_modules_set_updated_at
BEFORE UPDATE
ON public.training_modules
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER member_training_profiles_set_updated_at
BEFORE UPDATE
ON public.member_training_profiles
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

CREATE TRIGGER training_scenario_instances_set_updated_at
BEFORE UPDATE
ON public.training_scenario_instances
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();


-- =====================================================================
-- 10A. Audited training-gate configuration changes
-- =====================================================================
--
-- gate_mode can materially redirect incomplete members away from
-- operational routes. Every real transition therefore requires an
-- attributable active member with org.settings.write and appends an
-- immutable canonical audit event.
--
-- Authenticated execution derives the actor from auth.uid(). Privileged
-- service tooling must explicitly provide updated_by; the trigger then
-- verifies that member is active and holds org.settings.write.
-- =====================================================================

CREATE FUNCTION public.lsh_audit_training_gate_mode_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor_member_id uuid;
  v_actor_user_id uuid;
  v_executor_role text;
  v_attribution text;
BEGIN
  IF OLD.gate_mode IS NOT DISTINCT FROM NEW.gate_mode THEN
    RETURN NEW;
  END IF;

  v_executor_role :=
    NULLIF(
      current_setting(
        'request.jwt.claim.role',
        true
      ),
      ''
    );

  IF v_executor_role = 'authenticated' THEN
    v_actor_user_id := auth.uid();

    IF v_actor_user_id IS NULL THEN
      RAISE EXCEPTION
        'Authenticated training gate change requires a user identity';
    END IF;

    v_actor_member_id :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor_member_id IS NULL THEN
      RAISE EXCEPTION
        'Training gate change requires active organization membership';
    END IF;

    IF NEW.updated_by IS NOT NULL
       AND NEW.updated_by <> v_actor_member_id THEN
      RAISE EXCEPTION
        'updated_by must match the authenticated organization member';
    END IF;

    NEW.updated_by := v_actor_member_id;
    v_attribution := 'authenticated_member';

  ELSE
    v_actor_member_id := NEW.updated_by;

    IF v_actor_member_id IS NULL THEN
      RAISE EXCEPTION
        'updated_by is required when changing training gate mode';
    END IF;

    SELECT m.user_id
    INTO v_actor_user_id
    FROM public.organization_members m
    WHERE m.id =
          v_actor_member_id
      AND m.organization_id =
          NEW.organization_id
      AND m.status =
          'active'::public.member_status;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'updated_by must identify an active organization member';
    END IF;

    v_attribution := 'explicit_updated_by';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_members m
    JOIN public.member_role_grants g
      ON g.organization_id =
         m.organization_id
     AND g.organization_member_id =
         m.id
     AND g.revoked_at IS NULL
    JOIN public.role_permissions rp
      ON rp.role_id =
         g.role_id
    JOIN public.permissions p
      ON p.id =
         rp.permission_id
     AND p.key =
         'org.settings.write'
    LEFT JOIN public.branches b
      ON b.id =
         g.branch_id
     AND b.organization_id =
         g.organization_id
     AND b.status =
         'active'::public.branch_status
     AND b.deleted_at IS NULL
    WHERE m.id =
          v_actor_member_id
      AND m.organization_id =
          NEW.organization_id
      AND m.status =
          'active'::public.member_status
      AND (
        g.branch_id IS NULL
        OR b.id IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION
      'Training gate mode changes require org.settings.write';
  END IF;

  INSERT INTO public.audit_events (
    organization_id,
    actor_member_id,
    actor_user_id,
    action_key,
    entity_type,
    entity_id,
    is_sensitive,
    old_values,
    new_values,
    metadata,
    source
  )
  VALUES (
    NEW.organization_id,
    v_actor_member_id,
    v_actor_user_id,
    'training.gate_mode.changed',
    'organization_training_settings',
    NEW.organization_id,
    false,
    jsonb_build_object(
      'gate_mode',
      OLD.gate_mode::text
    ),
    jsonb_build_object(
      'gate_mode',
      NEW.gate_mode::text
    ),
    jsonb_build_object(
      'executor_role',
      COALESCE(
        v_executor_role,
        current_user
      ),
      'attribution',
      v_attribution
    ),
    'training-gate-trigger'
  );

  RETURN NEW;
END;
$function$;


CREATE TRIGGER organization_training_settings_gate_mode_audit
BEFORE UPDATE OF gate_mode
ON public.organization_training_settings
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_audit_training_gate_mode_change();


-- audit_events already rejects row-level UPDATE/DELETE. TRUNCATE does
-- not fire those row triggers, so service_role must not retain that
-- bypass if training-gate history is to remain immutable.
REVOKE TRUNCATE
ON TABLE public.audit_events
FROM service_role;


-- =====================================================================
-- 11. Immutable training-event guard
-- =====================================================================

CREATE FUNCTION public.lsh_reject_training_step_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION
    'training_step_events are immutable; append a new event instead';
END;
$function$;

CREATE TRIGGER training_step_events_immutable
BEFORE UPDATE OR DELETE
ON public.training_step_events
FOR EACH ROW
EXECUTE FUNCTION public.lsh_reject_training_step_event_mutation();


-- =====================================================================
-- 11A. Freeze versioned training catalogue after member state exists
-- =====================================================================

CREATE FUNCTION public.lsh_guard_training_catalogue_version_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
DECLARE
  v_old_module_id uuid;
  v_new_module_id uuid;
  v_has_member_state boolean := false;
BEGIN
  IF TG_TABLE_NAME = 'training_modules' THEN
    IF TG_OP <> 'INSERT' THEN
      v_old_module_id := OLD.id;
    END IF;

    IF TG_OP <> 'DELETE' THEN
      v_new_module_id := NEW.id;
    END IF;

    IF v_old_module_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.member_training_profiles mtp
        WHERE mtp.training_module_id =
              v_old_module_id
      )
      INTO v_has_member_state;
    END IF;

    IF TG_OP = 'UPDATE'
       AND v_has_member_state THEN
      IF OLD.active = true
         AND NEW.active = false
         AND NEW.id = OLD.id
         AND NEW.organization_id = OLD.organization_id
         AND NEW.role_id IS NOT DISTINCT FROM OLD.role_id
         AND NEW.module_key = OLD.module_key
         AND NEW.version = OLD.version
         AND NEW.title = OLD.title
         AND NEW.required = OLD.required
         AND NEW.minimum_score = OLD.minimum_score
         AND NEW.created_at = OLD.created_at THEN

        IF EXISTS (
          SELECT 1
          FROM public.member_training_profiles mtp
          JOIN public.organization_members m
            ON m.id =
               mtp.organization_member_id
           AND m.organization_id =
               mtp.organization_id
           AND m.status =
               'active'::public.member_status
          WHERE mtp.training_module_id =
                OLD.id
            AND mtp.status <>
                'complete'::public.training_profile_status
            AND EXISTS (
              SELECT 1
              FROM public.member_role_grants g
              LEFT JOIN public.branches b
                ON b.id =
                   g.branch_id
               AND b.organization_id =
                   g.organization_id
               AND b.status =
                   'active'::public.branch_status
               AND b.deleted_at IS NULL
              WHERE g.organization_id =
                    OLD.organization_id
                AND g.organization_member_id =
                    mtp.organization_member_id
                AND g.revoked_at IS NULL
                AND (
                  OLD.role_id IS NULL
                  OR g.role_id =
                     OLD.role_id
                )
                AND (
                  g.branch_id IS NULL
                  OR b.id IS NOT NULL
                )
            )
        ) THEN
          RAISE EXCEPTION
            'Training module version cannot be deactivated while member training is incomplete';
        END IF;

        RETURN NEW;
      END IF;

      RAISE EXCEPTION
        'Training module version is immutable once member training state exists; create a new version';
    END IF;

  ELSE
    IF TG_OP <> 'INSERT' THEN
      v_old_module_id := OLD.training_module_id;
    END IF;

    IF TG_OP <> 'DELETE' THEN
      v_new_module_id := NEW.training_module_id;
    END IF;
  END IF;

  IF v_old_module_id IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.member_training_profiles mtp
       WHERE mtp.training_module_id =
             v_old_module_id
     ) THEN
    RAISE EXCEPTION
      'Training module version is immutable once member training state exists; create a new version';
  END IF;

  IF v_new_module_id IS NOT NULL
     AND v_new_module_id IS DISTINCT FROM v_old_module_id
     AND EXISTS (
       SELECT 1
       FROM public.member_training_profiles mtp
       WHERE mtp.training_module_id =
             v_new_module_id
     ) THEN
    RAISE EXCEPTION
      'Training module version is immutable once member training state exists; create a new version';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER training_modules_version_immutable_after_state
BEFORE UPDATE OR DELETE
ON public.training_modules
FOR EACH ROW
EXECUTE FUNCTION public.lsh_guard_training_catalogue_version_mutation();

CREATE TRIGGER training_module_steps_version_immutable_after_state
BEFORE INSERT OR UPDATE OR DELETE
ON public.training_module_steps
FOR EACH ROW
EXECUTE FUNCTION public.lsh_guard_training_catalogue_version_mutation();


-- =====================================================================
-- 12. RLS: database/server remains the authority
-- =====================================================================

ALTER TABLE public.organization_training_settings
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_training_settings
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.training_modules
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_modules
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.training_module_steps
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_module_steps
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.member_training_profiles
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_training_profiles
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.training_scenario_instances
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_scenario_instances
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.training_step_events
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_step_events
  FORCE ROW LEVEL SECURITY;


CREATE POLICY organization_training_settings_deny_authenticated
ON public.organization_training_settings
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

CREATE POLICY training_modules_deny_authenticated
ON public.training_modules
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

CREATE POLICY training_module_steps_deny_authenticated
ON public.training_module_steps
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

CREATE POLICY member_training_profiles_deny_authenticated
ON public.member_training_profiles
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

CREATE POLICY training_scenario_instances_deny_authenticated
ON public.training_scenario_instances
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

CREATE POLICY training_step_events_deny_authenticated
ON public.training_step_events
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);


REVOKE ALL ON TABLE
  public.organization_training_settings,
  public.training_modules,
  public.training_module_steps,
  public.member_training_profiles,
  public.training_scenario_instances,
  public.training_step_events
FROM PUBLIC, anon, authenticated;

GRANT ALL ON TABLE
  public.organization_training_settings,
  public.training_modules,
  public.training_module_steps,
  public.member_training_profiles,
  public.training_scenario_instances,
  public.training_step_events
TO service_role;

-- training_step_events is append-only evidence. Row-level UPDATE/DELETE
-- mutations are already rejected by trigger; TRUNCATE does not fire
-- row-level triggers, so service_role must never receive that privilege.
REVOKE TRUNCATE
ON TABLE public.training_step_events
FROM service_role;

-- organization_training_settings is the persistent rollout authority.
-- Removing the row would implicitly change soft/required back to the
-- application fallback of off without traversing the audited gate-mode
-- UPDATE boundary. TRUNCATE has the same effect and bypasses row-level
-- triggers entirely. Controlled tooling may INSERT/UPDATE this singleton
-- configuration, but it must not DELETE or TRUNCATE it.
REVOKE DELETE, TRUNCATE
ON TABLE public.organization_training_settings
FROM service_role;


-- =====================================================================
-- 13. Training oversight permission
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'training.read',
  'training',
  'View training progress',
  'View role-aware onboarding and training progress for organization members.',
  true
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM public.roles r
JOIN public.permissions p
  ON p.key = 'training.read'
WHERE r.key = 'founder'
ON CONFLICT (role_id, permission_id) DO NOTHING;


-- =====================================================================
-- 14. Safe rollout defaults
-- =====================================================================

INSERT INTO public.organization_training_settings (
  organization_id,
  gate_mode,
  first_job_assist_count
)
SELECT
  o.id,
  'off'::public.training_gate_mode,
  3
FROM public.organizations o
WHERE o.deleted_at IS NULL
ON CONFLICT (organization_id) DO NOTHING;


-- =====================================================================
-- 15. T1 common orientation module
-- =====================================================================

INSERT INTO public.training_modules (
  organization_id,
  role_id,
  module_key,
  version,
  title,
  required,
  active,
  minimum_score
)
SELECT
  o.id,
  NULL,
  'common-orientation',
  1,
  'Little Moments OS — Common Orientation',
  true,
  true,
  100
FROM public.organizations o
WHERE o.deleted_at IS NULL;


INSERT INTO public.training_module_steps (
  organization_id,
  training_module_id,
  step_key,
  step_order,
  step_type,
  required,
  completion_event_type,
  completion_result
)
SELECT
  tm.organization_id,
  tm.id,
  v.step_key,
  v.step_order,
  v.step_type,
  true,
  'step_completed'::public.training_step_event_type,
  'pass'::public.training_step_event_result
FROM public.training_modules tm
CROSS JOIN (
  VALUES
    (
      'welcome',
      1,
      'orientation'::public.training_step_type
    ),
    (
      'role-scope',
      2,
      'orientation'::public.training_step_type
    ),
    (
      'navigation',
      3,
      'navigation'::public.training_step_type
    ),
    (
      'evidence-before-status',
      4,
      'evidence'::public.training_step_type
    ),
    (
      'privacy',
      5,
      'privacy'::public.training_step_type
    ),
    (
      'escalation',
      6,
      'escalation'::public.training_step_type
    ),
    (
      'help',
      7,
      'help'::public.training_step_type
    )
) AS v(step_key, step_order, step_type)
WHERE tm.module_key = 'common-orientation'
  AND tm.version = 1;


-- =====================================================================
-- 15A. Common-orientation client contract compatibility guard
-- =====================================================================
--
-- T1 intentionally renders common orientation from a frozen client-side
-- presentation contract. Versioned catalogue rows may be authored while
-- inactive, but an active common-orientation version must use the exact
-- step keys/order/completion contract that this client can render.
--
-- This keeps the database authoritative over publication while avoiding
-- silent activation of a version that the current UI cannot complete.
-- =====================================================================

CREATE FUNCTION public.lsh_guard_common_orientation_client_contract()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_module_id uuid;
  v_active boolean;
  v_module_key text;
  v_role_id uuid;
  v_required boolean;
  v_actual_contract jsonb;

  v_supported_contract CONSTANT jsonb :=
    '[
      ["welcome",1,"orientation",true,"step_completed","pass"],
      ["role-scope",2,"orientation",true,"step_completed","pass"],
      ["navigation",3,"navigation",true,"step_completed","pass"],
      ["evidence-before-status",4,"evidence",true,"step_completed","pass"],
      ["privacy",5,"privacy",true,"step_completed","pass"],
      ["escalation",6,"escalation",true,"step_completed","pass"],
      ["help",7,"help",true,"step_completed","pass"]
    ]'::jsonb;
BEGIN
  -- Serialize catalogue step mutations with module publication.
  -- UPDATE of training_modules already takes a conflicting row lock;
  -- step-trigger executions take FOR SHARE on the same module row.
  -- Whichever transaction arrives second therefore re-validates only
  -- after the first transaction commits or rolls back.
  IF TG_TABLE_NAME = 'training_modules' THEN
    IF TG_OP = 'DELETE' THEN
      v_module_id := OLD.id;
    ELSE
      v_module_id := NEW.id;
    END IF;
  ELSE
    IF TG_OP = 'DELETE' THEN
      v_module_id := OLD.training_module_id;
    ELSE
      v_module_id := NEW.training_module_id;
    END IF;
  END IF;

  SELECT
    tm.active,
    tm.module_key,
    tm.role_id,
    tm.required
  INTO
    v_active,
    v_module_key,
    v_role_id,
    v_required
  FROM public.training_modules tm
  WHERE tm.id =
        v_module_id
  FOR SHARE OF tm;

  IF NOT FOUND
     OR NOT v_active THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;

    RETURN NEW;
  END IF;

  -- T1 currently renders only the global common-orientation module.
  -- Other module identities may be authored while inactive, and may
  -- remain active only when optional. A required unsupported module
  -- must never enter the training gate because the T1 client cannot
  -- start or complete it.
  IF v_required
     AND (
       v_module_key <> 'common-orientation'
       OR v_role_id IS NOT NULL
     ) THEN
    RAISE EXCEPTION
      'Active required training module is not supported by the T1 client'
      USING HINT =
        'Keep unsupported required modules inactive until the client can render them.';
  END IF;

  -- Optional unsupported modules do not participate in the required
  -- gate and remain available for future role-training slices.
  IF v_module_key <> 'common-orientation'
     OR v_role_id IS NOT NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;

    RETURN NEW;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_array(
        tms.step_key,
        tms.step_order,
        tms.step_type::text,
        tms.required,
        tms.completion_event_type::text,
        tms.completion_result::text
      )
      ORDER BY
        tms.step_order,
        tms.step_key
    ),
    '[]'::jsonb
  )
  INTO v_actual_contract
  FROM public.training_module_steps tms
  WHERE tms.training_module_id =
        v_module_id;

  IF v_actual_contract IS DISTINCT FROM
     v_supported_contract THEN
    RAISE EXCEPTION
      'Active common-orientation contract is not supported by the T1 client'
      USING HINT =
        'Create the version inactive and publish it only with the supported seven-step T1 contract.';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$function$;


CREATE TRIGGER training_modules_common_orientation_client_contract
AFTER INSERT OR UPDATE
ON public.training_modules
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_guard_common_orientation_client_contract();


CREATE TRIGGER training_module_steps_common_orientation_client_contract
AFTER INSERT OR UPDATE OR DELETE
ON public.training_module_steps
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_guard_common_orientation_client_contract();


-- =====================================================================
-- 16. Authenticated member training read context
-- =====================================================================

CREATE FUNCTION public.my_training_context(
  p_organization_id uuid
)
RETURNS TABLE (
  organization_member_id uuid,
  display_name text,
  assigned_role_keys text[],
  assigned_role_labels text[],
  assigned_branch_ids uuid[],
  assigned_branch_codes text[],
  assigned_branch_names text[],
  organization_wide boolean,
  gate_mode public.training_gate_mode,
  training_module_id uuid,
  module_key text,
  module_role_key text,
  module_version integer,
  module_title text,
  module_required boolean,
  training_status public.training_profile_status,
  current_step_key text,
  started_at timestamptz,
  completed_at timestamptz,
  work_ready_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH current_member AS (
    SELECT
      m.id,
      m.display_name
    FROM public.organization_members m
    WHERE m.id =
          public.current_organization_member(
            p_organization_id
          )
      AND m.organization_id =
          p_organization_id
      AND m.status =
          'active'::public.member_status
  ),

  live_grants AS (
    SELECT
      g.organization_member_id,
      g.role_id,
      r.key AS role_key,
      r.label AS role_label,
      g.branch_id,
      b.code AS branch_code,
      b.name AS branch_name
    FROM public.member_role_grants g
    JOIN current_member cm
      ON cm.id =
         g.organization_member_id
    JOIN public.roles r
      ON r.id =
         g.role_id
    LEFT JOIN public.branches b
      ON b.id =
         g.branch_id
     AND b.organization_id =
         g.organization_id
     AND b.status =
         'active'::public.branch_status
     AND b.deleted_at IS NULL
    WHERE g.organization_id =
          p_organization_id
      AND g.revoked_at IS NULL
      AND (
        g.branch_id IS NULL
        OR b.id IS NOT NULL
      )
  ),

  role_scope AS (
    SELECT
      COALESCE(
        array_agg(x.role_id ORDER BY x.role_key),
        ARRAY[]::uuid[]
      ) AS role_ids,

      COALESCE(
        array_agg(x.role_key ORDER BY x.role_key),
        ARRAY[]::text[]
      ) AS role_keys,

      COALESCE(
        array_agg(x.role_label ORDER BY x.role_key),
        ARRAY[]::text[]
      ) AS role_labels
    FROM (
      SELECT DISTINCT
        role_id,
        role_key,
        role_label
      FROM live_grants
    ) x
  ),

  branch_scope AS (
    SELECT
      COALESCE(
        array_agg(x.branch_id ORDER BY x.branch_code),
        ARRAY[]::uuid[]
      ) AS branch_ids,

      COALESCE(
        array_agg(x.branch_code ORDER BY x.branch_code),
        ARRAY[]::text[]
      ) AS branch_codes,

      COALESCE(
        array_agg(x.branch_name ORDER BY x.branch_code),
        ARRAY[]::text[]
      ) AS branch_names
    FROM (
      SELECT DISTINCT
        branch_id,
        branch_code,
        branch_name
      FROM live_grants
      WHERE branch_id IS NOT NULL
    ) x
  )

  SELECT
    cm.id,
    cm.display_name,

    rs.role_keys,
    rs.role_labels,

    bs.branch_ids,
    bs.branch_codes,
    bs.branch_names,

    EXISTS (
      SELECT 1
      FROM live_grants lg
      WHERE lg.branch_id IS NULL
    ) AS organization_wide,

    COALESCE(
      ots.gate_mode,
      'off'::public.training_gate_mode
    ),

    tm.id,
    tm.module_key,
    mr.key,
    tm.version,
    tm.title,
    tm.required,

    COALESCE(
      mtp.status,
      'not_started'::public.training_profile_status
    ),

    mtp.current_step_key,
    mtp.started_at,
    mtp.completed_at,
    mtp.work_ready_at

  FROM current_member cm
  CROSS JOIN role_scope rs
  CROSS JOIN branch_scope bs

  JOIN public.training_modules tm
    ON tm.organization_id =
       p_organization_id
   AND tm.active = true
   AND (
     tm.role_id IS NULL
     OR tm.role_id = ANY(rs.role_ids)
   )

  LEFT JOIN public.roles mr
    ON mr.id =
       tm.role_id

  LEFT JOIN public.organization_training_settings ots
    ON ots.organization_id =
       p_organization_id

  LEFT JOIN public.member_training_profiles mtp
    ON mtp.organization_id =
       p_organization_id
   AND mtp.organization_member_id =
       cm.id
   AND mtp.training_module_id =
       tm.id

  WHERE cardinality(rs.role_ids) > 0

  ORDER BY
    tm.required DESC,
    tm.module_key,
    tm.version;
$function$;


-- =====================================================================
-- 17. Start/resume own training
-- =====================================================================

CREATE FUNCTION public.start_my_training_module(
  p_organization_id uuid,
  p_module_key text,
  p_version integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_member_id uuid;
  v_module_id uuid;
  v_required boolean;
  v_required_step_count integer;
  v_profile_id uuid;
BEGIN
  -- Lock the selected active module through profile creation.
  -- Retirement updates require a conflicting row lock, so either:
  --   1. start commits first and retirement sees the new profile, or
  --   2. retirement commits first and this SELECT re-checks active=true.
  -- This prevents a newly started incomplete profile from being attached
  -- to a version that becomes hidden in the same concurrency window.
  v_member_id :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_member_id IS NULL THEN
    RAISE EXCEPTION
      'Active organization membership is required';
  END IF;

  SELECT
    tm.id,
    tm.required
  INTO
    v_module_id,
    v_required
  FROM public.training_modules tm
  WHERE tm.organization_id =
        p_organization_id
    AND tm.module_key =
        p_module_key
    AND tm.version =
        p_version
    AND tm.active = true
    AND EXISTS (
      SELECT 1
      FROM public.member_role_grants g
      LEFT JOIN public.branches b
        ON b.id = g.branch_id
       AND b.organization_id = g.organization_id
       AND b.status = 'active'::public.branch_status
       AND b.deleted_at IS NULL
      WHERE g.organization_id =
            p_organization_id
        AND g.organization_member_id =
            v_member_id
        AND g.revoked_at IS NULL
        AND (
          g.branch_id IS NULL
          OR b.id IS NOT NULL
        )
    )
    AND (
      tm.role_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.member_role_grants g
        LEFT JOIN public.branches b
          ON b.id = g.branch_id
         AND b.organization_id = g.organization_id
         AND b.status = 'active'::public.branch_status
         AND b.deleted_at IS NULL
        WHERE g.organization_id =
              p_organization_id
          AND g.organization_member_id =
              v_member_id
          AND g.role_id =
              tm.role_id
          AND g.revoked_at IS NULL
          AND (
            g.branch_id IS NULL
            OR b.id IS NOT NULL
          )
      )
    )
  FOR SHARE OF tm;

  IF v_module_id IS NULL THEN
    RAISE EXCEPTION
      'Training module is not available for this member';
  END IF;

  IF v_required THEN
    SELECT
      count(*)
    INTO
      v_required_step_count
    FROM public.training_module_steps tms
    WHERE tms.training_module_id =
          v_module_id
      AND tms.required = true;

    IF v_required_step_count = 0 THEN
      RAISE EXCEPTION
        'Required training module must define at least one required step before it can be started or completed';
    END IF;
  END IF;

  INSERT INTO public.member_training_profiles (
    organization_id,
    organization_member_id,
    training_module_id,
    status,
    required_at,
    started_at
  )
  VALUES (
    p_organization_id,
    v_member_id,
    v_module_id,
    'in_progress'::public.training_profile_status,
    CASE WHEN v_required THEN now() ELSE NULL END,
    now()
  )
  ON CONFLICT (
    organization_member_id,
    training_module_id
  )
  DO UPDATE
  SET
    status =
      CASE
        WHEN public.member_training_profiles.status =
             'complete'::public.training_profile_status
          THEN public.member_training_profiles.status
        ELSE
          'in_progress'::public.training_profile_status
      END,

    required_at =
      COALESCE(
        public.member_training_profiles.required_at,
        EXCLUDED.required_at
      ),

    started_at =
      COALESCE(
        public.member_training_profiles.started_at,
        EXCLUDED.started_at
      )

  RETURNING id
  INTO v_profile_id;

  RETURN v_profile_id;
END;
$function$;


-- =====================================================================
-- 18. Record bounded own training events
--
-- Practice and knowledge-check PASS events are deliberately not accepted
-- through this generic T1 RPC. Later role slices must provide dedicated
-- server validators for those protected step types.
-- =====================================================================

CREATE FUNCTION public.record_my_training_step(
  p_organization_id uuid,
  p_module_key text,
  p_version integer,
  p_step_key text,
  p_event_type public.training_step_event_type,
  p_result public.training_step_event_result,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_member_id uuid;
  v_module_id uuid;
  v_profile_id uuid;
  v_step_type public.training_step_type;
  v_event_id uuid;
  v_metadata jsonb;
BEGIN
  v_member_id :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_member_id IS NULL THEN
    RAISE EXCEPTION
      'Active organization membership is required';
  END IF;

  v_metadata :=
    COALESCE(
      p_metadata,
      '{}'::jsonb
    );

  IF jsonb_typeof(v_metadata) <> 'object' THEN
    RAISE EXCEPTION
      'Training metadata must be a JSON object';
  END IF;

  IF octet_length(v_metadata::text) > 4096 THEN
    RAISE EXCEPTION
      'Training metadata exceeds the allowed size';
  END IF;

  IF p_event_type NOT IN (
    'step_viewed'::public.training_step_event_type,
    'step_completed'::public.training_step_event_type,
    'action_attempted'::public.training_step_event_type,
    'action_failed'::public.training_step_event_type,
    'hint_opened'::public.training_step_event_type,
    'training_step_broken'::public.training_step_event_type
  ) THEN
    RAISE EXCEPTION
      'This training event requires a dedicated server validator';
  END IF;

  SELECT
    tm.id
  INTO
    v_module_id
  FROM public.training_modules tm
  WHERE tm.organization_id =
        p_organization_id
    AND tm.module_key =
        p_module_key
    AND tm.version =
        p_version
    AND tm.active = true
    AND (
      tm.role_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.member_role_grants g
        LEFT JOIN public.branches b
          ON b.id = g.branch_id
         AND b.organization_id = g.organization_id
         AND b.status = 'active'::public.branch_status
         AND b.deleted_at IS NULL
        WHERE g.organization_id =
              p_organization_id
          AND g.organization_member_id =
              v_member_id
          AND g.role_id =
              tm.role_id
          AND g.revoked_at IS NULL
          AND (
            g.branch_id IS NULL
            OR b.id IS NOT NULL
          )
      )
    )
    AND EXISTS (
      SELECT 1
      FROM public.member_role_grants g
      LEFT JOIN public.branches b
        ON b.id = g.branch_id
       AND b.organization_id = g.organization_id
       AND b.status = 'active'::public.branch_status
       AND b.deleted_at IS NULL
      WHERE g.organization_id =
            p_organization_id
        AND g.organization_member_id =
            v_member_id
        AND g.revoked_at IS NULL
        AND (
          g.branch_id IS NULL
          OR b.id IS NOT NULL
        )
    );

  IF v_module_id IS NULL THEN
    RAISE EXCEPTION
      'Training module is not available for this member';
  END IF;

  SELECT
    mtp.id
  INTO
    v_profile_id
  FROM public.member_training_profiles mtp
  WHERE mtp.organization_id =
        p_organization_id
    AND mtp.organization_member_id =
        v_member_id
    AND mtp.training_module_id =
        v_module_id;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION
      'Training module must be started before recording progress';
  END IF;

  SELECT
    tms.step_type
  INTO
    v_step_type
  FROM public.training_module_steps tms
  WHERE tms.training_module_id =
        v_module_id
    AND tms.step_key =
        p_step_key;

  IF v_step_type IS NULL THEN
    RAISE EXCEPTION
      'Unknown training step';
  END IF;

  IF v_step_type IN (
       'practice'::public.training_step_type,
       'knowledge_check'::public.training_step_type
     )
     AND (
       p_result = 'pass'::public.training_step_event_result
       OR p_event_type =
          'step_completed'::public.training_step_event_type
     ) THEN
    RAISE EXCEPTION
      'Protected practice or knowledge-check completion requires a dedicated server validator';
  END IF;

  IF p_event_type =
       'step_completed'::public.training_step_event_type
     AND p_result <>
         'pass'::public.training_step_event_result THEN
    RAISE EXCEPTION
      'A completed training step must have a PASS result';
  END IF;

  INSERT INTO public.training_step_events (
    organization_id,
    organization_member_id,
    member_training_profile_id,
    step_key,
    event_type,
    result,
    metadata
  )
  VALUES (
    p_organization_id,
    v_member_id,
    v_profile_id,
    p_step_key,
    p_event_type,
    p_result,
    v_metadata
  )
  RETURNING id
  INTO v_event_id;

  UPDATE public.member_training_profiles
  SET
    current_step_key =
      p_step_key,

    status =
      CASE
        WHEN status =
             'complete'::public.training_profile_status
          THEN status
        ELSE
          'in_progress'::public.training_profile_status
      END

  WHERE id =
        v_profile_id;

  RETURN v_event_id;
END;
$function$;


-- =====================================================================
-- 19. Complete own module only after database-defined evidence exists
-- =====================================================================

CREATE FUNCTION public.complete_my_training_module(
  p_organization_id uuid,
  p_module_key text,
  p_version integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_member_id uuid;
  v_module_id uuid;
  v_required boolean;
  v_profile_id uuid;
  v_required_step_count integer;
  v_missing_count integer;
  v_completion_transitioned boolean := false;
BEGIN
  v_member_id :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_member_id IS NULL THEN
    RAISE EXCEPTION
      'Active organization membership is required';
  END IF;

  SELECT
    tm.id,
    tm.required
  INTO
    v_module_id,
    v_required
  FROM public.training_modules tm
  WHERE tm.organization_id =
        p_organization_id
    AND tm.module_key =
        p_module_key
    AND tm.version =
        p_version
    AND tm.active = true
    AND EXISTS (
      SELECT 1
      FROM public.member_role_grants g
      LEFT JOIN public.branches b
        ON b.id = g.branch_id
       AND b.organization_id = g.organization_id
       AND b.status = 'active'::public.branch_status
       AND b.deleted_at IS NULL
      WHERE g.organization_id =
            p_organization_id
        AND g.organization_member_id =
            v_member_id
        AND g.revoked_at IS NULL
        AND (
          g.branch_id IS NULL
          OR b.id IS NOT NULL
        )
    )
    AND (
      tm.role_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.member_role_grants g
        LEFT JOIN public.branches b
          ON b.id = g.branch_id
         AND b.organization_id = g.organization_id
         AND b.status = 'active'::public.branch_status
         AND b.deleted_at IS NULL
        WHERE g.organization_id =
              p_organization_id
          AND g.organization_member_id =
              v_member_id
          AND g.role_id =
              tm.role_id
          AND g.revoked_at IS NULL
          AND (
            g.branch_id IS NULL
            OR b.id IS NOT NULL
          )
      )
    );

  IF v_module_id IS NULL THEN
    RAISE EXCEPTION
      'Training module is not available for this member';
  END IF;

  SELECT
    mtp.id
  INTO
    v_profile_id
  FROM public.member_training_profiles mtp
  WHERE mtp.organization_id =
        p_organization_id
    AND mtp.organization_member_id =
        v_member_id
    AND mtp.training_module_id =
        v_module_id;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION
      'Training module must be started before completion';
  END IF;

  IF v_required THEN
    SELECT
      count(*)
    INTO
      v_required_step_count
    FROM public.training_module_steps tms
    WHERE tms.training_module_id =
          v_module_id
      AND tms.required = true;

    IF v_required_step_count = 0 THEN
      RAISE EXCEPTION
        'Required training module must define at least one required step before it can be started or completed';
    END IF;
  END IF;

  SELECT
    count(*)
  INTO
    v_missing_count
  FROM public.training_module_steps tms
  WHERE tms.training_module_id =
        v_module_id
    AND tms.required = true
    AND NOT EXISTS (
      SELECT 1
      FROM public.training_step_events tse
      WHERE tse.member_training_profile_id =
            v_profile_id
        AND tse.step_key =
            tms.step_key
        AND tse.event_type =
            tms.completion_event_type
        AND tse.result =
            tms.completion_result
    );

  IF v_missing_count > 0 THEN
    RAISE EXCEPTION
      'Training module cannot be completed: % required step(s) are incomplete',
      v_missing_count;
  END IF;

  UPDATE public.member_training_profiles
  SET
    status =
      'complete'::public.training_profile_status,

    completed_at =
      COALESCE(
        completed_at,
        now()
      )

  WHERE id =
        v_profile_id
    AND status <>
        'complete'::public.training_profile_status

  RETURNING true
  INTO v_completion_transitioned;

  IF COALESCE(
       v_completion_transitioned,
       false
     ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.training_step_events tse
      WHERE tse.member_training_profile_id =
            v_profile_id
        AND tse.step_key =
            '__module__'
        AND tse.event_type =
            'module_completed'::public.training_step_event_type
    ) THEN
      INSERT INTO public.training_step_events (
        organization_id,
        organization_member_id,
        member_training_profile_id,
        step_key,
        event_type,
        result,
        metadata
      )
      VALUES (
        p_organization_id,
        v_member_id,
        v_profile_id,
        '__module__',
        'module_completed'::public.training_step_event_type,
        'pass'::public.training_step_event_result,
        jsonb_build_object(
          'module_key',
          p_module_key,
          'version',
          p_version
        )
      );
    END IF;

    INSERT INTO public.audit_events (
      organization_id,
      actor_member_id,
      actor_user_id,
      action_key,
      entity_type,
      entity_id,
      is_sensitive,
      metadata,
      source
    )
    VALUES (
      p_organization_id,
      v_member_id,
      auth.uid(),
      'training.module.completed',
      'member_training_profile',
      v_profile_id,
      false,
      jsonb_build_object(
        'module_key',
        p_module_key,
        'version',
        p_version
      ),
      'application'
    );
  END IF;

  RETURN v_profile_id;
END;
$function$;


-- =====================================================================
-- 20. Founder-only organization training directory
--
-- T1 assigns training.read only to Founder.
-- If the permission is widened in a future slice, this read model must
-- first be amended for any desired branch-scoped supervisory semantics.
-- =====================================================================

CREATE FUNCTION public.training_directory(
  p_organization_id uuid
)
RETURNS TABLE (
  organization_member_id uuid,
  display_name text,
  email text,
  assigned_role_keys text[],
  assigned_branch_names text[],
  organization_wide boolean,
  module_key text,
  module_role_key text,
  module_version integer,
  module_title text,
  training_status public.training_profile_status,
  current_step_key text,
  completed_at timestamptz,
  work_ready_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor_member_id uuid;
BEGIN
  v_actor_member_id :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor_member_id IS NULL THEN
    RAISE EXCEPTION
      'Active organization membership is required';
  END IF;

  IF NOT public.has_permission_in_any_live_scope(
    p_organization_id,
    'training.read'
  ) THEN
    RAISE EXCEPTION
      'training.read permission is required';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.display_name,
    m.email,

    ARRAY(
      SELECT DISTINCT r.key
      FROM public.member_role_grants g
      JOIN public.roles r
        ON r.id = g.role_id
      LEFT JOIN public.branches b
        ON b.id = g.branch_id
       AND b.organization_id = g.organization_id
       AND b.status = 'active'::public.branch_status
       AND b.deleted_at IS NULL
      WHERE g.organization_id =
            m.organization_id
        AND g.organization_member_id =
            m.id
        AND g.revoked_at IS NULL
        AND (
          g.branch_id IS NULL
          OR b.id IS NOT NULL
        )
      ORDER BY r.key
    ) AS assigned_role_keys,

    ARRAY(
      SELECT DISTINCT b.name
      FROM public.member_role_grants g
      JOIN public.branches b
        ON b.id = g.branch_id
       AND b.organization_id = g.organization_id
       AND b.status = 'active'::public.branch_status
       AND b.deleted_at IS NULL
      WHERE g.organization_id =
            m.organization_id
        AND g.organization_member_id =
            m.id
        AND g.revoked_at IS NULL
      ORDER BY b.name
    ) AS assigned_branch_names,

    EXISTS (
      SELECT 1
      FROM public.member_role_grants g
      WHERE g.organization_id =
            m.organization_id
        AND g.organization_member_id =
            m.id
        AND g.revoked_at IS NULL
        AND g.branch_id IS NULL
    ) AS organization_wide,

    tm.module_key,
    mr.key,
    tm.version,
    tm.title,

    COALESCE(
      mtp.status,
      'not_started'::public.training_profile_status
    ),

    mtp.current_step_key,
    mtp.completed_at,
    mtp.work_ready_at

  FROM public.organization_members m

  JOIN public.training_modules tm
    ON tm.organization_id =
       m.organization_id
   AND tm.active = true
   AND EXISTS (
     SELECT 1
     FROM public.member_role_grants live_g
     LEFT JOIN public.branches live_b
       ON live_b.id =
          live_g.branch_id
      AND live_b.organization_id =
          live_g.organization_id
      AND live_b.status =
          'active'::public.branch_status
      AND live_b.deleted_at IS NULL
     WHERE live_g.organization_id =
           m.organization_id
       AND live_g.organization_member_id =
           m.id
       AND live_g.revoked_at IS NULL
       AND (
         live_g.branch_id IS NULL
         OR live_b.id IS NOT NULL
       )
   )
   AND (
     tm.role_id IS NULL
     OR EXISTS (
       SELECT 1
       FROM public.member_role_grants g
       LEFT JOIN public.branches b
         ON b.id = g.branch_id
        AND b.organization_id = g.organization_id
        AND b.status = 'active'::public.branch_status
        AND b.deleted_at IS NULL
       WHERE g.organization_id =
             m.organization_id
         AND g.organization_member_id =
             m.id
         AND g.role_id =
             tm.role_id
         AND g.revoked_at IS NULL
         AND (
           g.branch_id IS NULL
           OR b.id IS NOT NULL
         )
     )
   )

  LEFT JOIN public.roles mr
    ON mr.id =
       tm.role_id

  LEFT JOIN public.member_training_profiles mtp
    ON mtp.organization_id =
       m.organization_id
   AND mtp.organization_member_id =
       m.id
   AND mtp.training_module_id =
       tm.id

  WHERE m.organization_id =
        p_organization_id
    AND m.status =
        'active'::public.member_status

  ORDER BY
    COALESCE(m.display_name, m.email, m.id::text),
    tm.module_key,
    tm.version;
END;
$function$;


-- =====================================================================
-- 21. RPC execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.my_training_context(uuid)
FROM PUBLIC, anon, service_role;

REVOKE ALL
ON FUNCTION public.start_my_training_module(uuid,text,integer)
FROM PUBLIC, anon, service_role;

REVOKE ALL
ON FUNCTION public.record_my_training_step(
  uuid,
  text,
  integer,
  text,
  public.training_step_event_type,
  public.training_step_event_result,
  jsonb
)
FROM PUBLIC, anon, service_role;

REVOKE ALL
ON FUNCTION public.complete_my_training_module(uuid,text,integer)
FROM PUBLIC, anon, service_role;

REVOKE ALL
ON FUNCTION public.training_directory(uuid)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE
ON FUNCTION public.my_training_context(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.start_my_training_module(uuid,text,integer)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.record_my_training_step(
  uuid,
  text,
  integer,
  text,
  public.training_step_event_type,
  public.training_step_event_result,
  jsonb
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.complete_my_training_module(uuid,text,integer)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.training_directory(uuid)
TO authenticated;


REVOKE ALL
ON FUNCTION public.lsh_reject_training_step_event_mutation()
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL
ON FUNCTION public.lsh_audit_training_gate_mode_change()
FROM PUBLIC, anon, authenticated, service_role;


-- =====================================================================
-- 22. Documentation
-- =====================================================================

COMMENT ON TABLE public.organization_training_settings IS
  'Organization-level role-aware training rollout configuration. T1 defaults the training gate to OFF.';

COMMENT ON TABLE public.training_modules IS
  'Versioned organization training-module catalogue. role_id NULL means a common module applicable to any member with live role authority.';

COMMENT ON TABLE public.training_module_steps IS
  'Database-authoritative required-step completion contract for versioned training modules.';

COMMENT ON TABLE public.member_training_profiles IS
  'Persistent member training state, separate from authorization and membership status.';

COMMENT ON TABLE public.training_scenario_instances IS
  'Synthetic isolated training scenario state. Must never reference or mutate genuine client/domain records.';

COMMENT ON TABLE public.training_step_events IS
  'Immutable append-only training evidence.';

COMMENT ON FUNCTION public.my_training_context(uuid) IS
  'Returns the authenticated active member role/branch context and applicable training modules.';

COMMENT ON FUNCTION public.start_my_training_module(uuid,text,integer) IS
  'Starts or resumes an applicable training module for the authenticated active member.';

COMMENT ON FUNCTION public.record_my_training_step(
  uuid,
  text,
  integer,
  text,
  public.training_step_event_type,
  public.training_step_event_result,
  jsonb
) IS
  'Appends bounded common-tour training evidence for the authenticated member. Protected practice and knowledge completion require later dedicated validators.';

COMMENT ON FUNCTION public.complete_my_training_module(uuid,text,integer) IS
  'Completes an applicable module only after all database-defined required evidence exists. Does not grant role, branch, or Work Ready authority.';

COMMENT ON FUNCTION public.training_directory(uuid) IS
  'Founder-only T1 read model for organization training progress, enforced by training.read.';


-- =====================================================================
-- 23. Migration invariants
-- =====================================================================

DO $invariants$
DECLARE
  v_before bigint;
  v_after bigint;
  v_training_role_count integer;
  v_rls_failure_count integer;
BEGIN
  SELECT value
  INTO v_before
  FROM t1_training_pre_counts
  WHERE key = 'permissions';

  SELECT count(*)
  INTO v_after
  FROM public.permissions;

  IF v_after <> v_before + 1 THEN
    RAISE EXCEPTION
      'T1 invariant failed: permissions delta expected +1, before %, after %',
      v_before,
      v_after;
  END IF;

  SELECT value
  INTO v_before
  FROM t1_training_pre_counts
  WHERE key = 'role_permissions';

  SELECT count(*)
  INTO v_after
  FROM public.role_permissions;

  IF v_after <> v_before + 1 THEN
    RAISE EXCEPTION
      'T1 invariant failed: role_permissions delta expected +1, before %, after %',
      v_before,
      v_after;
  END IF;

  SELECT value
  INTO v_before
  FROM t1_training_pre_counts
  WHERE key = 'member_role_grants';

  SELECT count(*)
  INTO v_after
  FROM public.member_role_grants;

  IF v_after <> v_before THEN
    RAISE EXCEPTION
      'T1 invariant failed: existing member role grants changed, before %, after %',
      v_before,
      v_after;
  END IF;

  SELECT count(*)
  INTO v_training_role_count
  FROM public.role_permissions rp
  JOIN public.roles r
    ON r.id = rp.role_id
  JOIN public.permissions p
    ON p.id = rp.permission_id
  WHERE p.key = 'training.read';

  IF v_training_role_count <> 1
     OR NOT EXISTS (
       SELECT 1
       FROM public.role_permissions rp
       JOIN public.roles r
         ON r.id = rp.role_id
       JOIN public.permissions p
         ON p.id = rp.permission_id
       WHERE p.key = 'training.read'
         AND r.key = 'founder'
     ) THEN
    RAISE EXCEPTION
      'T1 invariant failed: training.read must belong only to Founder';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_training_settings ots
    WHERE ots.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND ots.gate_mode =
          'off'::public.training_gate_mode
  ) THEN
    RAISE EXCEPTION
      'T1 invariant failed: Little Shots training gate is not OFF';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.training_modules tm
    WHERE tm.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key =
          'common-orientation'
      AND tm.version = 1
      AND tm.active = true
      AND tm.required = true
      AND tm.role_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'T1 invariant failed: common orientation v1 was not seeded';
  END IF;

  IF (
    SELECT count(*)
    FROM public.training_module_steps tms
    JOIN public.training_modules tm
      ON tm.id = tms.training_module_id
    WHERE tm.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND tm.module_key =
          'common-orientation'
      AND tm.version = 1
  ) <> 7 THEN
    RAISE EXCEPTION
      'T1 invariant failed: common orientation must contain exactly seven steps';
  END IF;

  SELECT count(*)
  INTO v_rls_failure_count
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'organization_training_settings',
      'training_modules',
      'training_module_steps',
      'member_training_profiles',
      'training_scenario_instances',
      'training_step_events'
    )
    AND (
      c.relrowsecurity = false
      OR c.relforcerowsecurity = false
    );

  IF v_rls_failure_count <> 0 THEN
    RAISE EXCEPTION
      'T1 invariant failed: one or more training tables do not have ENABLE + FORCE RLS';
  END IF;
END
$invariants$;


COMMIT;
