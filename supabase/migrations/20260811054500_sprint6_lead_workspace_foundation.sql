BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';

-- =====================================================================
-- Little Shots OS - Sprint 6 Lead Workspace Foundation
-- Lead detail, next actions, tasks, safe communications, consultations,
-- reminder outbox, structured outcomes, restricted notes and SLA controls.
-- Existing lead permissions are reused; no new permission vocabulary.
-- =====================================================================

DO $pre$
DECLARE
  v_name text;
BEGIN
  FOREACH v_name IN ARRAY ARRAY[
    'organizations','branches','organization_members','permissions','roles',
    'role_permissions','leads','audit_events'
  ] LOOP
    IF to_regclass('public.' || v_name) IS NULL THEN
      RAISE EXCEPTION 'Sprint 6 precondition failed: missing public.%', v_name;
    END IF;
  END LOOP;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure('public.lsh_set_updated_at()') IS NULL
     OR to_regprocedure('public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Sprint 6 precondition failed: required authorization/audit helper missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'lead.read')
     OR NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'lead.write')
     OR NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'privacy.read')
     OR NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'safety.read')
     OR NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'audit.sensitive.read') THEN
    RAISE EXCEPTION 'Sprint 6 precondition failed: required frozen permissions missing';
  END IF;

  FOREACH v_name IN ARRAY ARRAY[
    'lead_next_actions','lead_activity_events','lead_tasks','lead_communications',
    'consultation_availability_windows','consultation_blackouts','consultations',
    'consultation_schedule_history','consultation_private_notes','notification_outbox',
    'business_calendar_days','business_calendar_holidays','lead_sla_rules','lead_sla_overrides'
  ] LOOP
    IF to_regclass('public.' || v_name) IS NOT NULL THEN
      RAISE EXCEPTION 'Sprint 6 precondition failed: public.% already exists', v_name;
    END IF;
  END LOOP;
END
$pre$;

-- Composite identities used by tenant-safe foreign keys.
CREATE UNIQUE INDEX IF NOT EXISTS leads_id_organization_id_sprint6_uq
  ON public.leads (id, organization_id);

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
CREATE TYPE public.lead_task_status AS ENUM (
  'open','in_progress','snoozed','completed','cancelled'
);
CREATE TYPE public.lead_task_priority AS ENUM (
  'low','normal','high','urgent'
);
CREATE TYPE public.lead_task_type AS ENUM (
  'first_response','follow_up','consultation','quote','privacy_review','safety_review',
  'stale_lead','reminder_recovery','assignment','document','internal_review','other'
);
CREATE TYPE public.communication_channel AS ENUM (
  'whatsapp','email','sms','phone','portal','in_person','manual'
);
CREATE TYPE public.communication_direction AS ENUM (
  'inbound','outbound','internal'
);
CREATE TYPE public.communication_status AS ENUM (
  'queued','accepted','delivered','read','failed','unknown','manual_confirmed'
);
CREATE TYPE public.consultation_status AS ENUM (
  'pending_confirmation','tentative','scheduled','completed','missed','cancelled','rescheduled'
);
CREATE TYPE public.consultation_outcome AS ENUM (
  'quote_ready','needs_follow_up','future_milestone','not_a_fit','no_response',
  'privacy_review','safety_review','reschedule_requested'
);
CREATE TYPE public.notification_kind AS ENUM (
  'confirmation','reminder_24h','reminder_2h','reschedule','cancellation',
  'missed_follow_up','internal_upcoming'
);
CREATE TYPE public.notification_status AS ENUM (
  'queued','processing','sent','failed','superseded','manual_action_required'
);

-- ---------------------------------------------------------------------
-- Current next action: one operational row per lead.
-- History is preserved in lead_activity_events and central audit.
-- ---------------------------------------------------------------------
CREATE TABLE public.lead_next_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  branch_id uuid NULL,
  lead_id uuid NOT NULL,
  action_text text NULL CHECK (action_text IS NULL OR (btrim(action_text) <> '' AND length(action_text) <= 500)),
  due_at timestamptz NULL,
  exception_reason text NULL CHECK (exception_reason IS NULL OR (btrim(exception_reason) <> '' AND length(exception_reason) <= 500)),
  source text NOT NULL DEFAULT 'manual' CHECK (btrim(source) <> '' AND length(source) <= 80),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,
  CONSTRAINT lead_next_actions_lead_fk
    FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_next_actions_branch_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_next_actions_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_next_actions_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_next_actions_one_per_lead UNIQUE (lead_id),
  CONSTRAINT lead_next_actions_value_chk CHECK (
    action_text IS NOT NULL OR exception_reason IS NOT NULL
  )
);
CREATE INDEX lead_next_actions_org_due_idx
  ON public.lead_next_actions (organization_id, due_at);

-- ---------------------------------------------------------------------
-- Safe append-only operational timeline.
-- Never stores communication bodies, private notes or sensitive evidence.
-- ---------------------------------------------------------------------
CREATE TABLE public.lead_activity_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  branch_id uuid NULL,
  lead_id uuid NOT NULL,
  event_type text NOT NULL CHECK (btrim(event_type) <> '' AND length(event_type) <= 120),
  entity_type text NOT NULL CHECK (btrim(entity_type) <> '' AND length(entity_type) <= 80),
  entity_id uuid NULL,
  summary text NOT NULL CHECK (btrim(summary) <> '' AND length(summary) <= 500),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_member_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lead_activity_events_lead_fk
    FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_activity_events_branch_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_activity_events_actor_fk
    FOREIGN KEY (actor_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX lead_activity_events_lead_created_idx
  ON public.lead_activity_events (lead_id, created_at DESC);
CREATE INDEX lead_activity_events_org_created_idx
  ON public.lead_activity_events (organization_id, created_at DESC);

-- ---------------------------------------------------------------------
-- Lead tasks
-- ---------------------------------------------------------------------
CREATE TABLE public.lead_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  branch_id uuid NULL,
  lead_id uuid NOT NULL,
  task_type public.lead_task_type NOT NULL,
  title text NOT NULL CHECK (btrim(title) <> '' AND length(title) <= 200),
  safe_summary text NULL CHECK (safe_summary IS NULL OR length(safe_summary) <= 1000),
  owner_member_id uuid NULL,
  status public.lead_task_status NOT NULL DEFAULT 'open',
  priority public.lead_task_priority NOT NULL DEFAULT 'normal',
  due_at timestamptz NULL,
  snoozed_until timestamptz NULL,
  source text NOT NULL DEFAULT 'manual' CHECK (btrim(source) <> '' AND length(source) <= 80),
  idempotency_key text NULL CHECK (idempotency_key IS NULL OR length(idempotency_key) <= 200),
  escalated_at timestamptz NULL,
  completed_at timestamptz NULL,
  completed_by uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,
  CONSTRAINT lead_tasks_lead_fk
    FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_tasks_branch_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_tasks_owner_fk
    FOREIGN KEY (owner_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_tasks_completed_by_fk
    FOREIGN KEY (completed_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_tasks_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_tasks_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_tasks_snooze_state_chk CHECK (
    (status = 'snoozed' AND snoozed_until IS NOT NULL) OR status <> 'snoozed'
  ),
  CONSTRAINT lead_tasks_completion_state_chk CHECK (
    (status = 'completed' AND completed_at IS NOT NULL AND completed_by IS NOT NULL)
    OR status <> 'completed'
  )
);
CREATE UNIQUE INDEX lead_tasks_idempotency_uq
  ON public.lead_tasks (organization_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
CREATE INDEX lead_tasks_lead_status_due_idx
  ON public.lead_tasks (lead_id, status, due_at);
CREATE INDEX lead_tasks_owner_status_due_idx
  ON public.lead_tasks (organization_id, owner_member_id, status, due_at);

-- ---------------------------------------------------------------------
-- Communication metadata only. Deliberately no message-body column.
-- ---------------------------------------------------------------------
CREATE TABLE public.lead_communications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  branch_id uuid NULL,
  lead_id uuid NOT NULL,
  consultation_id uuid NULL,
  channel public.communication_channel NOT NULL,
  direction public.communication_direction NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  owner_member_id uuid NULL,
  business_purpose text NOT NULL CHECK (btrim(business_purpose) <> '' AND length(business_purpose) <= 160),
  provider_identifier text NULL CHECK (provider_identifier IS NULL OR length(provider_identifier) <= 255),
  status public.communication_status NOT NULL DEFAULT 'unknown',
  template_key text NULL CHECK (template_key IS NULL OR length(template_key) <= 120),
  template_version text NULL CHECK (template_version IS NULL OR length(template_version) <= 80),
  safe_summary text NOT NULL CHECK (btrim(safe_summary) <> '' AND length(safe_summary) <= 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  CONSTRAINT lead_communications_lead_fk
    FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_communications_branch_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_communications_owner_fk
    FOREIGN KEY (owner_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_communications_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX lead_communications_lead_time_idx
  ON public.lead_communications (lead_id, occurred_at DESC);
CREATE INDEX lead_communications_consultation_idx
  ON public.lead_communications (consultation_id)
  WHERE consultation_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- Consultation availability
-- ---------------------------------------------------------------------
CREATE TABLE public.consultation_availability_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  owner_member_id uuid NOT NULL,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  local_start time NOT NULL,
  local_end time NOT NULL,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata' CHECK (btrim(timezone) <> ''),
  duration_minutes integer NOT NULL DEFAULT 30 CHECK (duration_minutes BETWEEN 10 AND 240),
  buffer_before_minutes integer NOT NULL DEFAULT 10 CHECK (buffer_before_minutes BETWEEN 0 AND 120),
  buffer_after_minutes integer NOT NULL DEFAULT 10 CHECK (buffer_after_minutes BETWEEN 0 AND 120),
  capacity integer NOT NULL DEFAULT 1 CHECK (capacity BETWEEN 1 AND 20),
  minimum_notice_minutes integer NOT NULL DEFAULT 120 CHECK (minimum_notice_minutes BETWEEN 0 AND 43200),
  booking_horizon_days integer NOT NULL DEFAULT 90 CHECK (booking_horizon_days BETWEEN 1 AND 730),
  is_bookable boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,
  CONSTRAINT consultation_availability_owner_fk
    FOREIGN KEY (owner_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultation_availability_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultation_availability_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultation_availability_time_chk CHECK (local_end > local_start),
  CONSTRAINT consultation_availability_unique_window
    UNIQUE (organization_id, owner_member_id, weekday, local_start, local_end)
);
CREATE INDEX consultation_availability_owner_weekday_idx
  ON public.consultation_availability_windows (organization_id, owner_member_id, weekday)
  WHERE is_bookable;

CREATE TABLE public.consultation_blackouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  owner_member_id uuid NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  safe_reason text NOT NULL CHECK (btrim(safe_reason) <> '' AND length(safe_reason) <= 300),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  CONSTRAINT consultation_blackouts_owner_fk
    FOREIGN KEY (owner_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultation_blackouts_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultation_blackouts_time_chk CHECK (ends_at > starts_at)
);
CREATE INDEX consultation_blackouts_org_owner_time_idx
  ON public.consultation_blackouts (organization_id, owner_member_id, starts_at, ends_at);

-- ---------------------------------------------------------------------
-- Consultations and structured notes
-- ---------------------------------------------------------------------
CREATE TABLE public.consultations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  branch_id uuid NULL,
  lead_id uuid NOT NULL,
  owner_member_id uuid NOT NULL,
  status public.consultation_status NOT NULL DEFAULT 'scheduled',
  scheduled_start_at timestamptz NOT NULL,
  scheduled_end_at timestamptz NOT NULL,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata' CHECK (btrim(timezone) <> ''),
  duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 10 AND 240),
  buffer_before_minutes integer NOT NULL DEFAULT 10 CHECK (buffer_before_minutes BETWEEN 0 AND 120),
  buffer_after_minutes integer NOT NULL DEFAULT 10 CHECK (buffer_after_minutes BETWEEN 0 AND 120),
  schedule_version integer NOT NULL DEFAULT 1 CHECK (schedule_version > 0),
  rescheduled_from_id uuid NULL,
  cancellation_reason text NULL CHECK (cancellation_reason IS NULL OR length(cancellation_reason) <= 500),
  outcome public.consultation_outcome NULL,
  business_summary text NULL CHECK (business_summary IS NULL OR length(business_summary) <= 2000),
  confirmed_emotional_goal text NULL CHECK (confirmed_emotional_goal IS NULL OR length(confirmed_emotional_goal) <= 1200),
  timing_fit text NULL CHECK (timing_fit IS NULL OR length(timing_fit) <= 800),
  package_fit text NULL CHECK (package_fit IS NULL OR length(package_fit) <= 800),
  objections text NULL CHECK (objections IS NULL OR length(objections) <= 1200),
  next_step text NULL CHECK (next_step IS NULL OR length(next_step) <= 800),
  privacy_clarification text NULL CHECK (privacy_clarification IS NULL OR length(privacy_clarification) <= 800),
  safety_review text NULL CHECK (safety_review IS NULL OR length(safety_review) <= 800),
  client_shareable_recap text NULL CHECK (client_shareable_recap IS NULL OR length(client_shareable_recap) <= 1600),
  completed_at timestamptz NULL,
  cancelled_at timestamptz NULL,
  missed_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,
  CONSTRAINT consultations_id_org_key UNIQUE (id, organization_id),
  CONSTRAINT consultations_lead_fk
    FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultations_branch_fk
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultations_owner_fk
    FOREIGN KEY (owner_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultations_rescheduled_from_fk
    FOREIGN KEY (rescheduled_from_id, organization_id)
    REFERENCES public.consultations(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultations_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultations_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultations_time_chk CHECK (scheduled_end_at > scheduled_start_at),
  CONSTRAINT consultations_completed_state_chk CHECK (
    (status = 'completed' AND completed_at IS NOT NULL AND outcome IS NOT NULL AND next_step IS NOT NULL)
    OR status <> 'completed'
  ),
  CONSTRAINT consultations_cancelled_state_chk CHECK (
    (status = 'cancelled' AND cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL)
    OR status <> 'cancelled'
  ),
  CONSTRAINT consultations_missed_state_chk CHECK (
    (status = 'missed' AND missed_at IS NOT NULL) OR status <> 'missed'
  )
);
CREATE INDEX consultations_owner_time_idx
  ON public.consultations (organization_id, owner_member_id, scheduled_start_at, scheduled_end_at);
CREATE INDEX consultations_lead_time_idx
  ON public.consultations (lead_id, scheduled_start_at DESC);
CREATE INDEX consultations_status_time_idx
  ON public.consultations (organization_id, status, scheduled_start_at);

ALTER TABLE public.lead_communications
  ADD CONSTRAINT lead_communications_consultation_fk
  FOREIGN KEY (consultation_id, organization_id)
  REFERENCES public.consultations(id, organization_id) ON DELETE RESTRICT;

CREATE TABLE public.consultation_schedule_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  consultation_id uuid NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('scheduled','rescheduled','cancelled','missed','completed')),
  previous_start_at timestamptz NULL,
  previous_end_at timestamptz NULL,
  new_start_at timestamptz NULL,
  new_end_at timestamptz NULL,
  reason_recorded boolean NOT NULL DEFAULT false,
  notification_effect text NULL CHECK (notification_effect IS NULL OR length(notification_effect) <= 300),
  actor_member_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT consultation_schedule_history_consultation_fk
    FOREIGN KEY (consultation_id, organization_id)
    REFERENCES public.consultations(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultation_schedule_history_actor_fk
    FOREIGN KEY (actor_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX consultation_schedule_history_consultation_idx
  ON public.consultation_schedule_history (consultation_id, created_at DESC);

-- Restricted text is physically separated and has no authenticated table grant.
CREATE TABLE public.consultation_private_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  consultation_id uuid NOT NULL,
  note_text text NOT NULL CHECK (btrim(note_text) <> '' AND length(note_text) <= 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  CONSTRAINT consultation_private_notes_consultation_fk
    FOREIGN KEY (consultation_id, organization_id)
    REFERENCES public.consultations(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT consultation_private_notes_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX consultation_private_notes_consultation_idx
  ON public.consultation_private_notes (consultation_id, created_at DESC);

-- ---------------------------------------------------------------------
-- Durable reminder / notification outbox.
-- Sprint 6 does not fake provider delivery; channel defaults to manual.
-- ---------------------------------------------------------------------
CREATE TABLE public.notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  lead_id uuid NOT NULL,
  consultation_id uuid NOT NULL,
  kind public.notification_kind NOT NULL,
  channel public.communication_channel NOT NULL DEFAULT 'manual',
  message_key text NOT NULL CHECK (btrim(message_key) <> '' AND length(message_key) <= 240),
  scheduled_for timestamptz NOT NULL,
  status public.notification_status NOT NULL DEFAULT 'queued',
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts integer NOT NULL DEFAULT 3 CHECK (max_attempts BETWEEN 1 AND 10),
  last_attempt_at timestamptz NULL,
  last_error_code text NULL CHECK (last_error_code IS NULL OR length(last_error_code) <= 120),
  provider_identifier text NULL CHECK (provider_identifier IS NULL OR length(provider_identifier) <= 255),
  superseded_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL,
  CONSTRAINT notification_outbox_lead_fk
    FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT notification_outbox_consultation_fk
    FOREIGN KEY (consultation_id, organization_id)
    REFERENCES public.consultations(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT notification_outbox_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT notification_outbox_updated_by_fk
    FOREIGN KEY (updated_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT notification_outbox_message_key_uq UNIQUE (organization_id, message_key),
  CONSTRAINT notification_outbox_superseded_chk CHECK (
    (status = 'superseded' AND superseded_at IS NOT NULL) OR status <> 'superseded'
  )
);
CREATE INDEX notification_outbox_due_idx
  ON public.notification_outbox (organization_id, status, scheduled_for);
CREATE INDEX notification_outbox_consultation_idx
  ON public.notification_outbox (consultation_id, status);

-- ---------------------------------------------------------------------
-- Business calendar and SLA configuration
-- ---------------------------------------------------------------------
CREATE TABLE public.business_calendar_days (
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  is_business_day boolean NOT NULL,
  local_start time NULL,
  local_end time NULL,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata' CHECK (btrim(timezone) <> ''),
  CONSTRAINT business_calendar_days_pkey PRIMARY KEY (organization_id, weekday),
  CONSTRAINT business_calendar_days_hours_chk CHECK (
    (is_business_day AND local_start IS NOT NULL AND local_end IS NOT NULL AND local_end > local_start)
    OR (NOT is_business_day AND local_start IS NULL AND local_end IS NULL)
  )
);

CREATE TABLE public.business_calendar_holidays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  holiday_date date NOT NULL,
  label text NOT NULL CHECK (btrim(label) <> '' AND length(label) <= 160),
  CONSTRAINT business_calendar_holidays_uq UNIQUE (organization_id, holiday_date)
);

CREATE TABLE public.lead_sla_rules (
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  sla_key text NOT NULL CHECK (sla_key IN (
    'first_response','unassigned_lead','missing_next_action','overdue_task',
    'consultation_confirmation','reminder_recovery','post_consultation_follow_up',
    'privacy_review','safety_review','stale_lead'
  )),
  threshold_business_minutes integer NOT NULL CHECK (threshold_business_minutes > 0),
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT lead_sla_rules_pkey PRIMARY KEY (organization_id, sla_key)
);

CREATE TABLE public.lead_sla_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  lead_id uuid NOT NULL,
  sla_key text NOT NULL,
  reason text NOT NULL CHECK (btrim(reason) <> '' AND length(reason) <= 1000),
  expires_at timestamptz NULL,
  review_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  CONSTRAINT lead_sla_overrides_lead_fk
    FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_sla_overrides_created_by_fk
    FOREIGN KEY (created_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  CONSTRAINT lead_sla_overrides_review_chk CHECK (expires_at IS NOT NULL OR review_at IS NOT NULL)
);
CREATE INDEX lead_sla_overrides_lead_idx
  ON public.lead_sla_overrides (lead_id, sla_key, created_at DESC);

-- ---------------------------------------------------------------------
-- Seed default business calendar and the 10 Sprint 6 SLA rules.
-- ---------------------------------------------------------------------
INSERT INTO public.business_calendar_days
  (organization_id, weekday, is_business_day, local_start, local_end, timezone)
SELECT o.id, d.weekday,
       d.is_business_day,
       d.local_start,
       d.local_end,
       COALESCE(NULLIF(o.timezone, ''), 'Asia/Kolkata')
FROM public.organizations o
CROSS JOIN (VALUES
  (0::smallint, false, NULL::time, NULL::time),
  (1::smallint, true,  '09:00'::time, '18:00'::time),
  (2::smallint, true,  '09:00'::time, '18:00'::time),
  (3::smallint, true,  '09:00'::time, '18:00'::time),
  (4::smallint, true,  '09:00'::time, '18:00'::time),
  (5::smallint, true,  '09:00'::time, '18:00'::time),
  (6::smallint, true,  '09:00'::time, '14:00'::time)
) AS d(weekday, is_business_day, local_start, local_end)
WHERE o.deleted_at IS NULL;

INSERT INTO public.lead_sla_rules
  (organization_id, sla_key, threshold_business_minutes)
SELECT o.id, r.sla_key, r.minutes
FROM public.organizations o
CROSS JOIN (VALUES
  ('first_response',120),
  ('unassigned_lead',120),
  ('missing_next_action',120),
  ('overdue_task',1),
  ('consultation_confirmation',60),
  ('reminder_recovery',1),
  ('post_consultation_follow_up',240),
  ('privacy_review',240),
  ('safety_review',120),
  ('stale_lead',2880)
) AS r(sla_key, minutes)
WHERE o.deleted_at IS NULL;

-- Default consultation availability for every active member who currently
-- receives lead.write from at least one live role grant. This removes a
-- launch-time dead end while remaining editable through the approved RPC.
INSERT INTO public.consultation_availability_windows (
  organization_id, owner_member_id, weekday, local_start, local_end, timezone,
  duration_minutes, buffer_before_minutes, buffer_after_minutes, capacity,
  minimum_notice_minutes, booking_horizon_days, created_by, updated_by
)
SELECT DISTINCT m.organization_id, m.id, d.weekday, d.local_start, d.local_end,
       COALESCE(NULLIF(o.timezone, ''), 'Asia/Kolkata'),
       30, 10, 10, 1, 120, 90, m.id, m.id
FROM public.organization_members m
JOIN public.organizations o ON o.id = m.organization_id
JOIN public.member_role_grants g
  ON g.organization_member_id = m.id
 AND g.organization_id = m.organization_id
 AND g.revoked_at IS NULL
JOIN public.role_permissions rp ON rp.role_id = g.role_id
JOIN public.permissions p ON p.id = rp.permission_id AND p.key = 'lead.write'
CROSS JOIN (VALUES
  (1::smallint, '09:00'::time, '18:00'::time),
  (2::smallint, '09:00'::time, '18:00'::time),
  (3::smallint, '09:00'::time, '18:00'::time),
  (4::smallint, '09:00'::time, '18:00'::time),
  (5::smallint, '09:00'::time, '18:00'::time),
  (6::smallint, '09:00'::time, '14:00'::time)
) AS d(weekday, local_start, local_end)
WHERE m.status = 'active'::public.member_status
  AND m.exited_at IS NULL
  AND o.status = 'active'::public.organization_status
  AND o.deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- Add Sprint 6 audit catalogue rows when this deployment uses the
-- additive catalogue. The append emitter itself remains the canonical sink.
-- ---------------------------------------------------------------------
DO $audit_catalogue$
DECLARE
  v_has_requires_reason boolean;
BEGIN
  IF to_regclass('public.audit_action_catalogue') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema='public' AND table_name='audit_action_catalogue'
        AND column_name='action_key'
    ) THEN
      RAISE EXCEPTION 'Sprint 6 audit catalogue exists with an unsupported shape';
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='audit_action_catalogue'
        AND column_name='requires_reason'
    ) INTO v_has_requires_reason;

    IF v_has_requires_reason THEN
      INSERT INTO public.audit_action_catalogue
        (action_key, domain, label, description, is_sensitive,
         requires_reason, expects_target, allows_branch_context)
      VALUES
        ('lead.next_action.updated','lead','Lead next action updated','The operational next action or approved exception for a lead changed.',false,false,true,false),
        ('lead.task.created','lead','Lead task created','A lead follow-up task was created.',false,false,true,false),
        ('lead.task.updated','lead','Lead task updated','A lead follow-up task state or ownership changed.',false,false,true,false),
        ('lead.communication.recorded','lead','Lead communication recorded','Safe communication metadata was recorded without storing the message body.',false,false,true,false),
        ('lead.consultation.scheduled','lead','Consultation scheduled','A consultation was scheduled for a lead.',false,false,true,false),
        ('lead.consultation.rescheduled','lead','Consultation rescheduled','A consultation schedule changed and stale reminder jobs were superseded.',false,true,true,false),
        ('lead.consultation.cancelled','lead','Consultation cancelled','A consultation was cancelled and pending reminder jobs were superseded.',false,true,true,false),
        ('lead.consultation.missed','lead','Consultation missed','A scheduled consultation was marked missed and follow-up recovery was created.',false,false,true,false),
        ('lead.consultation.completed','lead','Consultation completed','A consultation was completed with a structured outcome and next action.',false,false,true,false),
        ('lead.consultation.private_note_read','lead','Private consultation note read','A restricted consultation note was read by an authorised user.',true,false,true,false),
        ('lead.availability.updated','lead','Consultation availability updated','A consultation working window was created or updated.',false,false,true,false),
        ('lead.blackout.created','lead','Consultation blackout created','A consultation blackout period was added.',false,false,true,false),
        ('lead.notification.recovery_requested','lead','Notification recovery requested','A failed or manual notification job was placed back into the recovery flow.',false,false,true,false),
        ('lead.sla.override_created','lead','Lead SLA override created','An authorised SLA override with an expiry or review date was created.',true,true,true,false)
      ON CONFLICT (action_key) DO NOTHING;
    ELSE
      INSERT INTO public.audit_action_catalogue
        (action_key, domain, label, description, is_sensitive,
         expects_target, allows_branch_context)
      VALUES
        ('lead.next_action.updated','lead','Lead next action updated','The operational next action or approved exception for a lead changed.',false,true,false),
        ('lead.task.created','lead','Lead task created','A lead follow-up task was created.',false,true,false),
        ('lead.task.updated','lead','Lead task updated','A lead follow-up task state or ownership changed.',false,true,false),
        ('lead.communication.recorded','lead','Lead communication recorded','Safe communication metadata was recorded without storing the message body.',false,true,false),
        ('lead.consultation.scheduled','lead','Consultation scheduled','A consultation was scheduled for a lead.',false,true,false),
        ('lead.consultation.rescheduled','lead','Consultation rescheduled','A consultation schedule changed and stale reminder jobs were superseded.',false,true,false),
        ('lead.consultation.cancelled','lead','Consultation cancelled','A consultation was cancelled and pending reminder jobs were superseded.',false,true,false),
        ('lead.consultation.missed','lead','Consultation missed','A scheduled consultation was marked missed and follow-up recovery was created.',false,true,false),
        ('lead.consultation.completed','lead','Consultation completed','A consultation was completed with a structured outcome and next action.',false,true,false),
        ('lead.consultation.private_note_read','lead','Private consultation note read','A restricted consultation note was read by an authorised user.',true,true,false),
        ('lead.availability.updated','lead','Consultation availability updated','A consultation working window was created or updated.',false,true,false),
        ('lead.blackout.created','lead','Consultation blackout created','A consultation blackout period was added.',false,true,false),
        ('lead.notification.recovery_requested','lead','Notification recovery requested','A failed or manual notification job was placed back into the recovery flow.',false,true,false),
        ('lead.sla.override_created','lead','Lead SLA override created','An authorised SLA override with an expiry or review date was created.',true,true,false)
      ON CONFLICT (action_key) DO NOTHING;
    END IF;
  END IF;
END
$audit_catalogue$;

-- ---------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lsh_sprint6_actor(
  p_organization_id uuid,
  p_permission_key text,
  p_branch_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sprint 6 operation requires authentication' USING ERRCODE='42501';
  END IF;

  v_actor := public.current_organization_member(p_organization_id);
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'No active organization membership' USING ERRCODE='42501';
  END IF;

  IF NOT public.has_permission(p_organization_id, p_permission_key, p_branch_id) THEN
    RAISE EXCEPTION 'Permission required: %', p_permission_key USING ERRCODE='42501';
  END IF;

  RETURN v_actor;
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_sprint6_activity(
  p_organization_id uuid,
  p_branch_id uuid,
  p_lead_id uuid,
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_summary text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  v_actor := public.current_organization_member(p_organization_id);

  INSERT INTO public.lead_activity_events (
    organization_id, branch_id, lead_id, event_type, entity_type,
    entity_id, summary, metadata, actor_member_id
  ) VALUES (
    p_organization_id, p_branch_id, p_lead_id,
    lower(btrim(p_event_type)), lower(btrim(p_entity_type)), p_entity_id,
    left(btrim(p_summary), 500), COALESCE(p_metadata, '{}'::jsonb), v_actor
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_sprint6_audit(
  p_organization_id uuid,
  p_branch_id uuid,
  p_action_key text,
  p_entity_type text,
  p_entity_id uuid,
  p_is_sensitive boolean,
  p_old_values jsonb DEFAULT NULL,
  p_new_values jsonb DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.append_audit_event(
    p_organization_id,
    p_branch_id,
    p_action_key,
    p_entity_type,
    p_entity_id,
    COALESCE(p_is_sensitive, false),
    p_old_values,
    p_new_values,
    COALESCE(p_metadata, '{}'::jsonb),
    'application',
    gen_random_uuid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_sprint6_immutable_event_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME USING ERRCODE='42501';
END;
$$;

CREATE TRIGGER lead_activity_events_immutable
  BEFORE UPDATE OR DELETE ON public.lead_activity_events
  FOR EACH ROW EXECUTE FUNCTION public.lsh_sprint6_immutable_event_guard();
CREATE TRIGGER lead_communications_immutable
  BEFORE UPDATE OR DELETE ON public.lead_communications
  FOR EACH ROW EXECUTE FUNCTION public.lsh_sprint6_immutable_event_guard();
CREATE TRIGGER consultation_schedule_history_immutable
  BEFORE UPDATE OR DELETE ON public.consultation_schedule_history
  FOR EACH ROW EXECUTE FUNCTION public.lsh_sprint6_immutable_event_guard();
CREATE TRIGGER consultation_private_notes_immutable
  BEFORE UPDATE OR DELETE ON public.consultation_private_notes
  FOR EACH ROW EXECUTE FUNCTION public.lsh_sprint6_immutable_event_guard();
CREATE TRIGGER lead_sla_overrides_immutable
  BEFORE UPDATE OR DELETE ON public.lead_sla_overrides
  FOR EACH ROW EXECUTE FUNCTION public.lsh_sprint6_immutable_event_guard();

CREATE TRIGGER lead_next_actions_set_updated_at
  BEFORE UPDATE ON public.lead_next_actions
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER lead_tasks_set_updated_at
  BEFORE UPDATE ON public.lead_tasks
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER consultation_availability_set_updated_at
  BEFORE UPDATE ON public.consultation_availability_windows
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER consultations_set_updated_at
  BEFORE UPDATE ON public.consultations
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER notification_outbox_set_updated_at
  BEFORE UPDATE ON public.notification_outbox
  FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();

-- ---------------------------------------------------------------------
-- Next action RPC
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_lead_next_action(
  p_lead_id uuid,
  p_action_text text,
  p_due_at timestamptz,
  p_exception_reason text DEFAULT NULL,
  p_source text DEFAULT 'manual'
)
RETURNS public.lead_next_actions
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_lead public.leads%ROWTYPE;
  v_actor uuid;
  v_old public.lead_next_actions%ROWTYPE;
  v_row public.lead_next_actions%ROWTYPE;
BEGIN
  SELECT * INTO v_lead FROM public.leads WHERE id = p_lead_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lead not found'; END IF;

  v_actor := public.lsh_sprint6_actor(v_lead.organization_id, 'lead.write', v_lead.branch_id);

  IF v_lead.status IN ('converted'::public.lead_status, 'archived'::public.lead_status) THEN
    RAISE EXCEPTION 'Terminal leads cannot receive a new next action';
  END IF;

  IF NULLIF(btrim(COALESCE(p_action_text,'')), '') IS NULL
     AND NULLIF(btrim(COALESCE(p_exception_reason,'')), '') IS NULL THEN
    RAISE EXCEPTION 'A next action or approved exception reason is required';
  END IF;

  SELECT * INTO v_old FROM public.lead_next_actions WHERE lead_id = p_lead_id;

  INSERT INTO public.lead_next_actions (
    organization_id, branch_id, lead_id, action_text, due_at, exception_reason,
    source, created_by, updated_by
  ) VALUES (
    v_lead.organization_id, v_lead.branch_id, v_lead.id,
    NULLIF(btrim(p_action_text), ''), p_due_at,
    NULLIF(btrim(p_exception_reason), ''),
    COALESCE(NULLIF(btrim(p_source), ''), 'manual'), v_actor, v_actor
  )
  ON CONFLICT (lead_id) DO UPDATE SET
    branch_id = EXCLUDED.branch_id,
    action_text = EXCLUDED.action_text,
    due_at = EXCLUDED.due_at,
    exception_reason = EXCLUDED.exception_reason,
    source = EXCLUDED.source,
    updated_by = v_actor
  RETURNING * INTO v_row;

  PERFORM public.lsh_sprint6_activity(
    v_lead.organization_id, v_lead.branch_id, v_lead.id,
    'next_action.updated','lead_next_action',v_row.id,
    CASE WHEN v_row.action_text IS NOT NULL
      THEN 'Next action updated.' ELSE 'Next-action exception recorded.' END,
    jsonb_build_object('has_due_at', v_row.due_at IS NOT NULL, 'source', v_row.source)
  );

  PERFORM public.lsh_sprint6_audit(
    v_lead.organization_id, v_lead.branch_id, 'lead.next_action.updated',
    'lead_next_action', v_row.id, false,
    CASE WHEN v_old.id IS NULL THEN NULL ELSE jsonb_build_object(
      'had_action', v_old.action_text IS NOT NULL,
      'had_due_at', v_old.due_at IS NOT NULL,
      'had_exception', v_old.exception_reason IS NOT NULL
    ) END,
    jsonb_build_object(
      'has_action', v_row.action_text IS NOT NULL,
      'has_due_at', v_row.due_at IS NOT NULL,
      'has_exception', v_row.exception_reason IS NOT NULL
    ),
    jsonb_build_object('lead_id', v_lead.id)
  );

  RETURN v_row;
END;
$$;

-- ---------------------------------------------------------------------
-- Task RPCs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_lead_task(
  p_lead_id uuid,
  p_task_type public.lead_task_type,
  p_title text,
  p_safe_summary text DEFAULT NULL,
  p_owner_member_id uuid DEFAULT NULL,
  p_priority public.lead_task_priority DEFAULT 'normal',
  p_due_at timestamptz DEFAULT NULL,
  p_source text DEFAULT 'manual',
  p_idempotency_key text DEFAULT NULL
)
RETURNS public.lead_tasks
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_lead public.leads%ROWTYPE;
  v_actor uuid;
  v_owner uuid;
  v_row public.lead_tasks%ROWTYPE;
BEGIN
  SELECT * INTO v_lead FROM public.leads WHERE id = p_lead_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lead not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_lead.organization_id, 'lead.write', v_lead.branch_id);
  v_owner := COALESCE(p_owner_member_id, v_actor);

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members m
    WHERE m.id = v_owner AND m.organization_id = v_lead.organization_id
      AND m.status = 'active'::public.member_status AND m.exited_at IS NULL
  ) THEN RAISE EXCEPTION 'Task owner must be an active member of the same organization'; END IF;

  IF NULLIF(btrim(COALESCE(p_title,'')), '') IS NULL THEN
    RAISE EXCEPTION 'Task title is required';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_row FROM public.lead_tasks
    WHERE organization_id = v_lead.organization_id
      AND idempotency_key = p_idempotency_key;
    IF FOUND THEN RETURN v_row; END IF;
  END IF;

  INSERT INTO public.lead_tasks (
    organization_id, branch_id, lead_id, task_type, title, safe_summary,
    owner_member_id, priority, due_at, source, idempotency_key,
    created_by, updated_by
  ) VALUES (
    v_lead.organization_id, v_lead.branch_id, v_lead.id, p_task_type,
    btrim(p_title), NULLIF(btrim(COALESCE(p_safe_summary,'')), ''),
    v_owner, COALESCE(p_priority, 'normal'::public.lead_task_priority), p_due_at,
    COALESCE(NULLIF(btrim(COALESCE(p_source,'')), ''), 'manual'),
    NULLIF(btrim(COALESCE(p_idempotency_key,'')), ''), v_actor, v_actor
  ) RETURNING * INTO v_row;

  PERFORM public.lsh_sprint6_activity(
    v_lead.organization_id, v_lead.branch_id, v_lead.id,
    'task.created','lead_task',v_row.id,'Follow-up task created.',
    jsonb_build_object('task_type',v_row.task_type,'priority',v_row.priority,'has_due_at',v_row.due_at IS NOT NULL)
  );
  PERFORM public.lsh_sprint6_audit(
    v_lead.organization_id, v_lead.branch_id, 'lead.task.created',
    'lead_task', v_row.id, false, NULL,
    jsonb_build_object('task_type',v_row.task_type,'priority',v_row.priority,'status',v_row.status),
    jsonb_build_object('lead_id',v_lead.id)
  );
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_lead_task(
  p_task_id uuid,
  p_status public.lead_task_status,
  p_priority public.lead_task_priority,
  p_due_at timestamptz,
  p_snoozed_until timestamptz DEFAULT NULL,
  p_owner_member_id uuid DEFAULT NULL,
  p_escalate boolean DEFAULT false
)
RETURNS public.lead_tasks
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old public.lead_tasks%ROWTYPE;
  v_row public.lead_tasks%ROWTYPE;
  v_actor uuid;
  v_owner uuid;
BEGIN
  SELECT * INTO v_old FROM public.lead_tasks WHERE id = p_task_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Task not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_old.organization_id, 'lead.write', v_old.branch_id);
  v_owner := COALESCE(p_owner_member_id, v_old.owner_member_id, v_actor);

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members m
    WHERE m.id=v_owner AND m.organization_id=v_old.organization_id
      AND m.status='active'::public.member_status AND m.exited_at IS NULL
  ) THEN RAISE EXCEPTION 'Task owner must be an active member of the same organization'; END IF;

  IF p_status = 'snoozed'::public.lead_task_status AND p_snoozed_until IS NULL THEN
    RAISE EXCEPTION 'Snoozed tasks require snoozed_until';
  END IF;

  UPDATE public.lead_tasks SET
    status = p_status,
    priority = p_priority,
    due_at = p_due_at,
    snoozed_until = CASE WHEN p_status='snoozed'::public.lead_task_status THEN p_snoozed_until ELSE NULL END,
    owner_member_id = v_owner,
    escalated_at = CASE WHEN p_escalate THEN COALESCE(escalated_at, now()) ELSE escalated_at END,
    completed_at = CASE WHEN p_status='completed'::public.lead_task_status THEN COALESCE(completed_at, now()) ELSE NULL END,
    completed_by = CASE WHEN p_status='completed'::public.lead_task_status THEN v_actor ELSE NULL END,
    updated_by = v_actor
  WHERE id = p_task_id
  RETURNING * INTO v_row;

  PERFORM public.lsh_sprint6_activity(
    v_row.organization_id, v_row.branch_id, v_row.lead_id,
    'task.updated','lead_task',v_row.id,'Follow-up task updated.',
    jsonb_build_object('status',v_row.status,'priority',v_row.priority,'escalated',v_row.escalated_at IS NOT NULL)
  );
  PERFORM public.lsh_sprint6_audit(
    v_row.organization_id, v_row.branch_id, 'lead.task.updated',
    'lead_task', v_row.id, false,
    jsonb_build_object('status',v_old.status,'priority',v_old.priority,'had_due_at',v_old.due_at IS NOT NULL),
    jsonb_build_object('status',v_row.status,'priority',v_row.priority,'has_due_at',v_row.due_at IS NOT NULL),
    jsonb_build_object('lead_id',v_row.lead_id)
  );
  RETURN v_row;
END;
$$;

-- ---------------------------------------------------------------------
-- Communication RPC. It cannot accept or store message bodies.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_lead_communication(
  p_lead_id uuid,
  p_channel public.communication_channel,
  p_direction public.communication_direction,
  p_business_purpose text,
  p_status public.communication_status,
  p_safe_summary text,
  p_occurred_at timestamptz DEFAULT now(),
  p_provider_identifier text DEFAULT NULL,
  p_template_key text DEFAULT NULL,
  p_template_version text DEFAULT NULL,
  p_consultation_id uuid DEFAULT NULL
)
RETURNS public.lead_communications
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_lead public.leads%ROWTYPE;
  v_actor uuid;
  v_row public.lead_communications%ROWTYPE;
BEGIN
  SELECT * INTO v_lead FROM public.leads WHERE id = p_lead_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lead not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_lead.organization_id, 'lead.write', v_lead.branch_id);

  IF NULLIF(btrim(COALESCE(p_business_purpose,'')), '') IS NULL
     OR NULLIF(btrim(COALESCE(p_safe_summary,'')), '') IS NULL THEN
    RAISE EXCEPTION 'Business purpose and safe summary are required';
  END IF;

  IF p_consultation_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.consultations c
    WHERE c.id=p_consultation_id AND c.organization_id=v_lead.organization_id AND c.lead_id=v_lead.id
  ) THEN RAISE EXCEPTION 'Consultation does not belong to this lead'; END IF;

  INSERT INTO public.lead_communications (
    organization_id, branch_id, lead_id, consultation_id, channel, direction,
    occurred_at, owner_member_id, business_purpose, provider_identifier,
    status, template_key, template_version, safe_summary, created_by
  ) VALUES (
    v_lead.organization_id, v_lead.branch_id, v_lead.id, p_consultation_id,
    p_channel, p_direction, COALESCE(p_occurred_at,now()), v_actor,
    btrim(p_business_purpose), NULLIF(btrim(COALESCE(p_provider_identifier,'')), ''),
    p_status, NULLIF(btrim(COALESCE(p_template_key,'')), ''),
    NULLIF(btrim(COALESCE(p_template_version,'')), ''),
    left(btrim(p_safe_summary),500), v_actor
  ) RETURNING * INTO v_row;

  PERFORM public.lsh_sprint6_activity(
    v_lead.organization_id, v_lead.branch_id, v_lead.id,
    'communication.recorded','lead_communication',v_row.id,'Communication metadata recorded.',
    jsonb_build_object('channel',v_row.channel,'direction',v_row.direction,'status',v_row.status,'business_purpose',v_row.business_purpose)
  );
  PERFORM public.lsh_sprint6_audit(
    v_lead.organization_id, v_lead.branch_id, 'lead.communication.recorded',
    'lead_communication', v_row.id, false, NULL,
    jsonb_build_object('channel',v_row.channel,'direction',v_row.direction,'status',v_row.status),
    jsonb_build_object('lead_id',v_lead.id,'consultation_id',p_consultation_id)
  );
  RETURN v_row;
END;
$$;

-- ---------------------------------------------------------------------
-- Availability / blackout RPCs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_consultation_availability(
  p_weekday smallint,
  p_local_start time,
  p_local_end time,
  p_timezone text DEFAULT 'Asia/Kolkata',
  p_duration_minutes integer DEFAULT 30,
  p_buffer_before_minutes integer DEFAULT 10,
  p_buffer_after_minutes integer DEFAULT 10,
  p_capacity integer DEFAULT 1,
  p_minimum_notice_minutes integer DEFAULT 120,
  p_booking_horizon_days integer DEFAULT 90,
  p_is_bookable boolean DEFAULT true
)
RETURNS public.consultation_availability_windows
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_org uuid;
  v_actor uuid;
  v_row public.consultation_availability_windows%ROWTYPE;
BEGIN
  BEGIN
    SELECT o.organization_id INTO STRICT v_org
    FROM public.current_user_organization_ids() o(organization_id)
    WHERE public.has_permission(o.organization_id,'lead.write',NULL::uuid);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'Organization-wide lead.write permission is required' USING ERRCODE='42501';
    WHEN TOO_MANY_ROWS THEN
      RAISE EXCEPTION 'Organization context is ambiguous; choose one organization before changing availability' USING ERRCODE='42501';
  END;
  v_actor := public.lsh_sprint6_actor(v_org,'lead.write',NULL::uuid);

  INSERT INTO public.consultation_availability_windows (
    organization_id, owner_member_id, weekday, local_start, local_end, timezone,
    duration_minutes, buffer_before_minutes, buffer_after_minutes, capacity,
    minimum_notice_minutes, booking_horizon_days, is_bookable, created_by, updated_by
  ) VALUES (
    v_org, v_actor, p_weekday, p_local_start, p_local_end,
    COALESCE(NULLIF(btrim(p_timezone),''),'Asia/Kolkata'),
    p_duration_minutes,p_buffer_before_minutes,p_buffer_after_minutes,p_capacity,
    p_minimum_notice_minutes,p_booking_horizon_days,p_is_bookable,v_actor,v_actor
  )
  ON CONFLICT (organization_id, owner_member_id, weekday, local_start, local_end)
  DO UPDATE SET
    timezone=EXCLUDED.timezone,
    duration_minutes=EXCLUDED.duration_minutes,
    buffer_before_minutes=EXCLUDED.buffer_before_minutes,
    buffer_after_minutes=EXCLUDED.buffer_after_minutes,
    capacity=EXCLUDED.capacity,
    minimum_notice_minutes=EXCLUDED.minimum_notice_minutes,
    booking_horizon_days=EXCLUDED.booking_horizon_days,
    is_bookable=EXCLUDED.is_bookable,
    updated_by=v_actor
  RETURNING * INTO v_row;

  PERFORM public.lsh_sprint6_audit(
    v_org,NULL,'lead.availability.updated','consultation_availability',v_row.id,false,
    NULL,
    jsonb_build_object('weekday',v_row.weekday,'is_bookable',v_row.is_bookable,'capacity',v_row.capacity),
    '{}'::jsonb
  );
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_consultation_blackout(
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_safe_reason text
)
RETURNS public.consultation_blackouts
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_org uuid;
  v_actor uuid;
  v_row public.consultation_blackouts%ROWTYPE;
BEGIN
  BEGIN
    SELECT o.organization_id INTO STRICT v_org
    FROM public.current_user_organization_ids() o(organization_id)
    WHERE public.has_permission(o.organization_id,'lead.write',NULL::uuid);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'Organization-wide lead.write permission is required' USING ERRCODE='42501';
    WHEN TOO_MANY_ROWS THEN
      RAISE EXCEPTION 'Organization context is ambiguous; choose one organization before changing availability' USING ERRCODE='42501';
  END;
  v_actor := public.lsh_sprint6_actor(v_org,'lead.write',NULL::uuid);
  IF p_ends_at <= p_starts_at THEN RAISE EXCEPTION 'Blackout end must be after start'; END IF;

  INSERT INTO public.consultation_blackouts (
    organization_id, owner_member_id, starts_at, ends_at, safe_reason, created_by
  ) VALUES (v_org,v_actor,p_starts_at,p_ends_at,left(btrim(p_safe_reason),300),v_actor)
  RETURNING * INTO v_row;

  PERFORM public.lsh_sprint6_audit(
    v_org,NULL,'lead.blackout.created','consultation_blackout',v_row.id,false,
    NULL,jsonb_build_object('has_reason',true),'{}'::jsonb
  );
  RETURN v_row;
END;
$$;

-- ---------------------------------------------------------------------
-- Slot availability helper with working-window, notice, horizon,
-- blackout, buffer and capacity enforcement.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lsh_consultation_slot_is_available(
  p_organization_id uuid,
  p_owner_member_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_exclude_consultation_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_timezone text := 'Asia/Kolkata';
  v_local_start timestamp;
  v_local_end timestamp;
  v_weekday smallint;
  v_capacity integer;
  v_buffer_before integer;
  v_buffer_after integer;
  v_min_notice integer;
  v_horizon integer;
  v_overlap_count integer;
BEGIN
  IF p_starts_at IS NULL OR p_ends_at IS NULL OR p_ends_at <= p_starts_at THEN RETURN false; END IF;

  SELECT w.timezone, w.capacity, w.buffer_before_minutes, w.buffer_after_minutes,
         w.minimum_notice_minutes, w.booking_horizon_days
    INTO v_timezone, v_capacity, v_buffer_before, v_buffer_after, v_min_notice, v_horizon
  FROM public.consultation_availability_windows w
  WHERE w.organization_id=p_organization_id
    AND w.owner_member_id=p_owner_member_id
    AND w.is_bookable
    AND w.weekday = EXTRACT(DOW FROM (p_starts_at AT TIME ZONE w.timezone))::smallint
    AND (p_starts_at AT TIME ZONE w.timezone)::time >= w.local_start
    AND (p_ends_at AT TIME ZONE w.timezone)::time <= w.local_end
  ORDER BY w.local_start
  LIMIT 1;

  IF NOT FOUND THEN RETURN false; END IF;

  v_local_start := p_starts_at AT TIME ZONE v_timezone;
  v_local_end := p_ends_at AT TIME ZONE v_timezone;
  v_weekday := EXTRACT(DOW FROM v_local_start)::smallint;

  IF EXTRACT(DOW FROM v_local_end)::smallint <> v_weekday THEN RETURN false; END IF;
  IF p_starts_at < now() + make_interval(mins => v_min_notice) THEN RETURN false; END IF;
  IF p_starts_at > now() + make_interval(days => v_horizon) THEN RETURN false; END IF;

  IF EXISTS (
    SELECT 1 FROM public.consultation_blackouts b
    WHERE b.organization_id=p_organization_id
      AND (b.owner_member_id IS NULL OR b.owner_member_id=p_owner_member_id)
      AND tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(p_starts_at,p_ends_at,'[)')
  ) THEN RETURN false; END IF;

  SELECT count(*) INTO v_overlap_count
  FROM public.consultations c
  WHERE c.organization_id=p_organization_id
    AND c.owner_member_id=p_owner_member_id
    AND c.status IN (
      'pending_confirmation'::public.consultation_status,
      'tentative'::public.consultation_status,
      'scheduled'::public.consultation_status
    )
    AND (p_exclude_consultation_id IS NULL OR c.id<>p_exclude_consultation_id)
    AND tstzrange(
      c.scheduled_start_at - make_interval(mins=>c.buffer_before_minutes),
      c.scheduled_end_at + make_interval(mins=>c.buffer_after_minutes), '[)'
    ) && tstzrange(
      p_starts_at - make_interval(mins=>v_buffer_before),
      p_ends_at + make_interval(mins=>v_buffer_after), '[)'
    );

  RETURN v_overlap_count < v_capacity;
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_queue_consultation_notifications(
  p_consultation_id uuid,
  p_actor uuid
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_c public.consultations%ROWTYPE;
  v_item record;
BEGIN
  SELECT * INTO v_c FROM public.consultations WHERE id=p_consultation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Consultation not found'; END IF;

  FOR v_item IN
    SELECT * FROM (VALUES
      ('confirmation'::public.notification_kind, now()),
      ('reminder_24h'::public.notification_kind, v_c.scheduled_start_at - interval '24 hours'),
      ('reminder_2h'::public.notification_kind, v_c.scheduled_start_at - interval '2 hours'),
      ('internal_upcoming'::public.notification_kind, v_c.scheduled_start_at - interval '30 minutes')
    ) AS q(kind, scheduled_for)
  LOOP
    IF v_item.scheduled_for > now() - interval '5 minutes' THEN
      INSERT INTO public.notification_outbox (
        organization_id,lead_id,consultation_id,kind,channel,message_key,scheduled_for,
        status,created_by,updated_by
      ) VALUES (
        v_c.organization_id,v_c.lead_id,v_c.id,v_item.kind,'manual',
        v_c.id::text || ':' || v_item.kind::text || ':v' || v_c.schedule_version::text,
        GREATEST(v_item.scheduled_for,now()),'queued',p_actor,p_actor
      ) ON CONFLICT (organization_id,message_key) DO NOTHING;
    END IF;
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------
-- Consultation lifecycle RPCs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.schedule_consultation(
  p_lead_id uuid,
  p_starts_at timestamptz,
  p_duration_minutes integer DEFAULT 30,
  p_timezone text DEFAULT 'Asia/Kolkata',
  p_owner_member_id uuid DEFAULT NULL
)
RETURNS public.consultations
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_lead public.leads%ROWTYPE;
  v_actor uuid;
  v_owner uuid;
  v_end timestamptz;
  v_before integer := 10;
  v_after integer := 10;
  v_row public.consultations%ROWTYPE;
BEGIN
  SELECT * INTO v_lead FROM public.leads WHERE id=p_lead_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lead not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_lead.organization_id,'lead.write',v_lead.branch_id);
  v_owner := COALESCE(p_owner_member_id,v_actor);

  IF v_lead.status IN ('converted'::public.lead_status,'archived'::public.lead_status) THEN
    RAISE EXCEPTION 'Terminal leads cannot be scheduled';
  END IF;
  IF p_duration_minutes NOT BETWEEN 10 AND 240 THEN RAISE EXCEPTION 'Invalid consultation duration'; END IF;
  v_end := p_starts_at + make_interval(mins=>p_duration_minutes);

  SELECT w.buffer_before_minutes,w.buffer_after_minutes
  INTO v_before,v_after
  FROM public.consultation_availability_windows w
  WHERE w.organization_id=v_lead.organization_id AND w.owner_member_id=v_owner AND w.is_bookable
    AND w.weekday=EXTRACT(DOW FROM (p_starts_at AT TIME ZONE w.timezone))::smallint
    AND (p_starts_at AT TIME ZONE w.timezone)::time >= w.local_start
    AND (v_end AT TIME ZONE w.timezone)::time <= w.local_end
  ORDER BY w.local_start LIMIT 1;

  IF NOT public.lsh_consultation_slot_is_available(
    v_lead.organization_id,v_owner,p_starts_at,v_end,NULL
  ) THEN RAISE EXCEPTION 'Consultation slot is unavailable'; END IF;

  INSERT INTO public.consultations (
    organization_id,branch_id,lead_id,owner_member_id,status,
    scheduled_start_at,scheduled_end_at,timezone,duration_minutes,
    buffer_before_minutes,buffer_after_minutes,created_by,updated_by
  ) VALUES (
    v_lead.organization_id,v_lead.branch_id,v_lead.id,v_owner,'scheduled',
    p_starts_at,v_end,COALESCE(NULLIF(btrim(p_timezone),''),'Asia/Kolkata'),
    p_duration_minutes,COALESCE(v_before,10),COALESCE(v_after,10),v_actor,v_actor
  ) RETURNING * INTO v_row;

  INSERT INTO public.consultation_schedule_history (
    organization_id,consultation_id,event_type,new_start_at,new_end_at,
    reason_recorded,notification_effect,actor_member_id
  ) VALUES (
    v_row.organization_id,v_row.id,'scheduled',v_row.scheduled_start_at,v_row.scheduled_end_at,
    false,'Confirmation and reminder jobs queued.',v_actor
  );

  PERFORM public.lsh_queue_consultation_notifications(v_row.id,v_actor);
  PERFORM public.set_lead_next_action(
    v_lead.id,'Prepare for consultation',v_row.scheduled_start_at - interval '15 minutes',NULL,'consultation'
  );

  PERFORM public.lsh_sprint6_activity(
    v_row.organization_id,v_row.branch_id,v_row.lead_id,
    'consultation.scheduled','consultation',v_row.id,'Consultation scheduled.',
    jsonb_build_object('duration_minutes',v_row.duration_minutes,'timezone',v_row.timezone)
  );
  PERFORM public.lsh_sprint6_audit(
    v_row.organization_id,v_row.branch_id,'lead.consultation.scheduled','consultation',v_row.id,false,
    NULL,jsonb_build_object('status',v_row.status,'duration_minutes',v_row.duration_minutes),
    jsonb_build_object('lead_id',v_row.lead_id)
  );
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.reschedule_consultation(
  p_consultation_id uuid,
  p_new_starts_at timestamptz,
  p_reason text,
  p_duration_minutes integer DEFAULT NULL
)
RETURNS public.consultations
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old public.consultations%ROWTYPE;
  v_actor uuid;
  v_duration integer;
  v_new_end timestamptz;
  v_new public.consultations%ROWTYPE;
BEGIN
  SELECT * INTO v_old FROM public.consultations WHERE id=p_consultation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Consultation not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_old.organization_id,'lead.write',v_old.branch_id);
  IF v_old.status NOT IN ('pending_confirmation','tentative','scheduled') THEN
    RAISE EXCEPTION 'Only an active consultation can be rescheduled';
  END IF;
  IF NULLIF(btrim(COALESCE(p_reason,'')), '') IS NULL THEN RAISE EXCEPTION 'Reschedule reason is required'; END IF;

  v_duration := COALESCE(p_duration_minutes,v_old.duration_minutes);
  v_new_end := p_new_starts_at + make_interval(mins=>v_duration);
  IF NOT public.lsh_consultation_slot_is_available(
    v_old.organization_id,v_old.owner_member_id,p_new_starts_at,v_new_end,v_old.id
  ) THEN RAISE EXCEPTION 'New consultation slot is unavailable'; END IF;

  UPDATE public.consultations SET status='rescheduled',updated_by=v_actor
  WHERE id=v_old.id;

  UPDATE public.notification_outbox SET
    status='superseded',superseded_at=now(),updated_by=v_actor
  WHERE consultation_id=v_old.id AND status IN ('queued','processing','failed','manual_action_required');

  INSERT INTO public.consultations (
    organization_id,branch_id,lead_id,owner_member_id,status,
    scheduled_start_at,scheduled_end_at,timezone,duration_minutes,
    buffer_before_minutes,buffer_after_minutes,schedule_version,rescheduled_from_id,
    created_by,updated_by
  ) VALUES (
    v_old.organization_id,v_old.branch_id,v_old.lead_id,v_old.owner_member_id,'scheduled',
    p_new_starts_at,v_new_end,v_old.timezone,v_duration,
    v_old.buffer_before_minutes,v_old.buffer_after_minutes,v_old.schedule_version+1,v_old.id,
    v_actor,v_actor
  ) RETURNING * INTO v_new;

  INSERT INTO public.consultation_schedule_history (
    organization_id,consultation_id,event_type,previous_start_at,previous_end_at,
    new_start_at,new_end_at,reason_recorded,notification_effect,actor_member_id
  ) VALUES (
    v_old.organization_id,v_old.id,'rescheduled',v_old.scheduled_start_at,v_old.scheduled_end_at,
    v_new.scheduled_start_at,v_new.scheduled_end_at,true,'Old jobs superseded; new jobs queued.',v_actor
  );

  PERFORM public.lsh_queue_consultation_notifications(v_new.id,v_actor);
  INSERT INTO public.notification_outbox (
    organization_id,lead_id,consultation_id,kind,channel,message_key,scheduled_for,status,created_by,updated_by
  ) VALUES (
    v_new.organization_id,v_new.lead_id,v_new.id,'reschedule','manual',
    v_new.id::text||':reschedule:v'||v_new.schedule_version::text,now(),'queued',v_actor,v_actor
  ) ON CONFLICT (organization_id,message_key) DO NOTHING;

  PERFORM public.set_lead_next_action(
    v_new.lead_id,'Prepare for rescheduled consultation',v_new.scheduled_start_at - interval '15 minutes',NULL,'consultation'
  );
  PERFORM public.lsh_sprint6_activity(
    v_new.organization_id,v_new.branch_id,v_new.lead_id,
    'consultation.rescheduled','consultation',v_new.id,'Consultation rescheduled; stale reminder jobs superseded.',
    jsonb_build_object('previous_consultation_id',v_old.id,'reason_recorded',true)
  );
  PERFORM public.lsh_sprint6_audit(
    v_new.organization_id,v_new.branch_id,'lead.consultation.rescheduled','consultation',v_new.id,false,
    jsonb_build_object('old_consultation_id',v_old.id),
    jsonb_build_object('new_consultation_id',v_new.id,'schedule_version',v_new.schedule_version),
    jsonb_build_object('lead_id',v_new.lead_id,'reason_recorded',true)
  );
  RETURN v_new;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_consultation(
  p_consultation_id uuid,
  p_reason text
)
RETURNS public.consultations
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old public.consultations%ROWTYPE;
  v_row public.consultations%ROWTYPE;
  v_actor uuid;
BEGIN
  SELECT * INTO v_old FROM public.consultations WHERE id=p_consultation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Consultation not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_old.organization_id,'lead.write',v_old.branch_id);
  IF v_old.status NOT IN ('pending_confirmation','tentative','scheduled') THEN
    RAISE EXCEPTION 'Only an active consultation can be cancelled';
  END IF;
  IF NULLIF(btrim(COALESCE(p_reason,'')), '') IS NULL THEN RAISE EXCEPTION 'Cancellation reason is required'; END IF;

  UPDATE public.consultations SET
    status='cancelled',cancellation_reason=left(btrim(p_reason),500),cancelled_at=now(),updated_by=v_actor
  WHERE id=v_old.id RETURNING * INTO v_row;

  UPDATE public.notification_outbox SET
    status='superseded',superseded_at=now(),updated_by=v_actor
  WHERE consultation_id=v_row.id AND status IN ('queued','processing','failed','manual_action_required');

  INSERT INTO public.notification_outbox (
    organization_id,lead_id,consultation_id,kind,channel,message_key,scheduled_for,status,created_by,updated_by
  ) VALUES (
    v_row.organization_id,v_row.lead_id,v_row.id,'cancellation','manual',
    v_row.id::text||':cancellation:v'||v_row.schedule_version::text,now(),'queued',v_actor,v_actor
  ) ON CONFLICT (organization_id,message_key) DO NOTHING;

  INSERT INTO public.consultation_schedule_history (
    organization_id,consultation_id,event_type,previous_start_at,previous_end_at,
    reason_recorded,notification_effect,actor_member_id
  ) VALUES (
    v_row.organization_id,v_row.id,'cancelled',v_row.scheduled_start_at,v_row.scheduled_end_at,
    true,'Pending jobs superseded; cancellation action queued.',v_actor
  );
  PERFORM public.set_lead_next_action(
    v_row.lead_id,'Review cancellation and decide the gentle next step',now()+interval '1 day',NULL,'consultation'
  );
  PERFORM public.lsh_sprint6_activity(
    v_row.organization_id,v_row.branch_id,v_row.lead_id,
    'consultation.cancelled','consultation',v_row.id,'Consultation cancelled; pending reminder jobs superseded.',
    jsonb_build_object('reason_recorded',true)
  );
  PERFORM public.lsh_sprint6_audit(
    v_row.organization_id,v_row.branch_id,'lead.consultation.cancelled','consultation',v_row.id,false,
    jsonb_build_object('status',v_old.status),jsonb_build_object('status',v_row.status),
    jsonb_build_object('lead_id',v_row.lead_id,'reason_recorded',true)
  );
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_consultation_missed(
  p_consultation_id uuid
)
RETURNS public.consultations
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old public.consultations%ROWTYPE;
  v_row public.consultations%ROWTYPE;
  v_actor uuid;
BEGIN
  SELECT * INTO v_old FROM public.consultations WHERE id=p_consultation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Consultation not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_old.organization_id,'lead.write',v_old.branch_id);
  IF v_old.status NOT IN ('pending_confirmation','tentative','scheduled') THEN
    RAISE EXCEPTION 'Only an active consultation can be marked missed';
  END IF;

  UPDATE public.consultations SET status='missed',missed_at=now(),updated_by=v_actor
  WHERE id=v_old.id RETURNING * INTO v_row;

  UPDATE public.notification_outbox SET
    status='superseded',superseded_at=now(),updated_by=v_actor
  WHERE consultation_id=v_row.id AND status IN ('queued','processing','failed','manual_action_required');

  INSERT INTO public.notification_outbox (
    organization_id,lead_id,consultation_id,kind,channel,message_key,scheduled_for,status,created_by,updated_by
  ) VALUES (
    v_row.organization_id,v_row.lead_id,v_row.id,'missed_follow_up','manual',
    v_row.id::text||':missed_follow_up:v'||v_row.schedule_version::text,now(),'queued',v_actor,v_actor
  ) ON CONFLICT (organization_id,message_key) DO NOTHING;

  INSERT INTO public.consultation_schedule_history (
    organization_id,consultation_id,event_type,previous_start_at,previous_end_at,
    reason_recorded,notification_effect,actor_member_id
  ) VALUES (
    v_row.organization_id,v_row.id,'missed',v_row.scheduled_start_at,v_row.scheduled_end_at,
    false,'Missed follow-up action queued.',v_actor
  );

  PERFORM public.create_lead_task(
    v_row.lead_id,'follow_up','Follow up after missed consultation',
    'Reconnect gently and confirm whether the family would like to reschedule.',
    v_actor,'high',now()+interval '4 hours','consultation',
    'missed-consultation:'||v_row.id::text
  );
  PERFORM public.set_lead_next_action(
    v_row.lead_id,'Reconnect after missed consultation',now()+interval '4 hours',NULL,'consultation'
  );
  PERFORM public.lsh_sprint6_activity(
    v_row.organization_id,v_row.branch_id,v_row.lead_id,
    'consultation.missed','consultation',v_row.id,'Consultation marked missed; follow-up recovery created.',
    '{}'::jsonb
  );
  PERFORM public.lsh_sprint6_audit(
    v_row.organization_id,v_row.branch_id,'lead.consultation.missed','consultation',v_row.id,false,
    jsonb_build_object('status',v_old.status),jsonb_build_object('status',v_row.status),
    jsonb_build_object('lead_id',v_row.lead_id)
  );
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_consultation(
  p_consultation_id uuid,
  p_outcome public.consultation_outcome,
  p_business_summary text,
  p_confirmed_emotional_goal text,
  p_timing_fit text,
  p_package_fit text,
  p_objections text,
  p_next_step text,
  p_privacy_clarification text,
  p_safety_review text,
  p_client_shareable_recap text,
  p_next_action text,
  p_next_action_due_at timestamptz,
  p_private_note text DEFAULT NULL
)
RETURNS public.consultations
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old public.consultations%ROWTYPE;
  v_row public.consultations%ROWTYPE;
  v_actor uuid;
  v_task_type public.lead_task_type;
BEGIN
  SELECT * INTO v_old FROM public.consultations WHERE id=p_consultation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Consultation not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_old.organization_id,'lead.write',v_old.branch_id);
  IF v_old.status NOT IN ('pending_confirmation','tentative','scheduled') THEN
    RAISE EXCEPTION 'Only an active consultation can be completed';
  END IF;
  IF p_outcome IS NULL THEN RAISE EXCEPTION 'Consultation outcome is required'; END IF;
  IF NULLIF(btrim(COALESCE(p_next_step,'')), '') IS NULL
     OR NULLIF(btrim(COALESCE(p_next_action,'')), '') IS NULL
     OR p_next_action_due_at IS NULL THEN
    RAISE EXCEPTION 'Completion requires a structured next step, next action and due time';
  END IF;

  UPDATE public.consultations SET
    status='completed',outcome=p_outcome,
    business_summary=NULLIF(btrim(COALESCE(p_business_summary,'')),''),
    confirmed_emotional_goal=NULLIF(btrim(COALESCE(p_confirmed_emotional_goal,'')),''),
    timing_fit=NULLIF(btrim(COALESCE(p_timing_fit,'')),''),
    package_fit=NULLIF(btrim(COALESCE(p_package_fit,'')),''),
    objections=NULLIF(btrim(COALESCE(p_objections,'')),''),
    next_step=btrim(p_next_step),
    privacy_clarification=NULLIF(btrim(COALESCE(p_privacy_clarification,'')),''),
    safety_review=NULLIF(btrim(COALESCE(p_safety_review,'')),''),
    client_shareable_recap=NULLIF(btrim(COALESCE(p_client_shareable_recap,'')),''),
    completed_at=now(),updated_by=v_actor
  WHERE id=v_old.id RETURNING * INTO v_row;

  IF NULLIF(btrim(COALESCE(p_privacy_clarification,'')), '') IS NOT NULL
     AND NOT public.has_permission(v_old.organization_id,'privacy.read',v_old.branch_id) THEN
    RAISE EXCEPTION 'privacy.read is required to record privacy clarification' USING ERRCODE='42501';
  END IF;

  IF NULLIF(btrim(COALESCE(p_safety_review,'')), '') IS NOT NULL
     AND NOT public.has_permission(v_old.organization_id,'safety.read',v_old.branch_id) THEN
    RAISE EXCEPTION 'safety.read is required to record safety review' USING ERRCODE='42501';
  END IF;

  IF NULLIF(btrim(COALESCE(p_private_note,'')), '') IS NOT NULL THEN
    IF NOT public.has_permission(v_old.organization_id,'audit.sensitive.read',v_old.branch_id) THEN
      RAISE EXCEPTION 'audit.sensitive.read is required to record a private consultation note' USING ERRCODE='42501';
    END IF;
    INSERT INTO public.consultation_private_notes (
      organization_id,consultation_id,note_text,created_by
    ) VALUES (v_row.organization_id,v_row.id,btrim(p_private_note),v_actor);
  END IF;

  UPDATE public.notification_outbox SET
    status='superseded',superseded_at=now(),updated_by=v_actor
  WHERE consultation_id=v_row.id AND status IN ('queued','processing','failed','manual_action_required');

  INSERT INTO public.consultation_schedule_history (
    organization_id,consultation_id,event_type,previous_start_at,previous_end_at,
    reason_recorded,notification_effect,actor_member_id
  ) VALUES (
    v_row.organization_id,v_row.id,'completed',v_row.scheduled_start_at,v_row.scheduled_end_at,
    false,'Future reminder jobs superseded.',v_actor
  );

  PERFORM public.set_lead_next_action(
    v_row.lead_id,btrim(p_next_action),p_next_action_due_at,NULL,'consultation_outcome'
  );

  v_task_type := CASE p_outcome
    WHEN 'quote_ready'::public.consultation_outcome THEN 'quote'::public.lead_task_type
    WHEN 'privacy_review'::public.consultation_outcome THEN 'privacy_review'::public.lead_task_type
    WHEN 'safety_review'::public.consultation_outcome THEN 'safety_review'::public.lead_task_type
    WHEN 'reschedule_requested'::public.consultation_outcome THEN 'consultation'::public.lead_task_type
    ELSE 'follow_up'::public.lead_task_type
  END;

  PERFORM public.create_lead_task(
    v_row.lead_id,v_task_type,btrim(p_next_action),
    'Created from consultation outcome: '||replace(p_outcome::text,'_',' ')||'.',
    v_actor,
    CASE WHEN p_outcome IN ('privacy_review'::public.consultation_outcome,'safety_review'::public.consultation_outcome)
      THEN 'high'::public.lead_task_priority ELSE 'normal'::public.lead_task_priority END,
    p_next_action_due_at,'consultation_outcome',
    'consultation-outcome:'||v_row.id::text
  );

  PERFORM public.lsh_sprint6_activity(
    v_row.organization_id,v_row.branch_id,v_row.lead_id,
    'consultation.completed','consultation',v_row.id,'Consultation completed with structured outcome.',
    jsonb_build_object('outcome',v_row.outcome,'has_private_note',NULLIF(btrim(COALESCE(p_private_note,'')),'') IS NOT NULL)
  );
  PERFORM public.lsh_sprint6_audit(
    v_row.organization_id,v_row.branch_id,'lead.consultation.completed','consultation',v_row.id,false,
    jsonb_build_object('status',v_old.status),
    jsonb_build_object('status',v_row.status,'outcome',v_row.outcome),
    jsonb_build_object('lead_id',v_row.lead_id,'private_note_recorded',NULLIF(btrim(COALESCE(p_private_note,'')),'') IS NOT NULL)
  );
  RETURN v_row;
END;
$$;

-- Restricted read path. Central audit records access, but never note text.
CREATE OR REPLACE FUNCTION public.get_consultation_private_notes(
  p_consultation_id uuid
)
RETURNS TABLE (
  id uuid,
  consultation_id uuid,
  note_text text,
  created_at timestamptz,
  created_by uuid
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_c public.consultations%ROWTYPE;
BEGIN
  SELECT * INTO v_c FROM public.consultations WHERE consultations.id=p_consultation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Consultation not found'; END IF;
  PERFORM public.lsh_sprint6_actor(v_c.organization_id,'audit.sensitive.read',v_c.branch_id);
  IF NOT public.has_permission(v_c.organization_id,'lead.read',v_c.branch_id) THEN
    RAISE EXCEPTION 'lead.read is required to access private consultation notes' USING ERRCODE='42501';
  END IF;

  PERFORM public.lsh_sprint6_audit(
    v_c.organization_id,v_c.branch_id,'lead.consultation.private_note_read',
    'consultation',v_c.id,true,NULL,NULL,
    jsonb_build_object('lead_id',v_c.lead_id,'private_note_accessed',true)
  );

  RETURN QUERY
  SELECT n.id,n.consultation_id,n.note_text,n.created_at,n.created_by
  FROM public.consultation_private_notes n
  WHERE n.organization_id=v_c.organization_id AND n.consultation_id=v_c.id
  ORDER BY n.created_at DESC;
END;
$$;

-- Notification recovery does not claim delivery. It merely requeues or
-- requires a manual continuity task.
CREATE OR REPLACE FUNCTION public.retry_notification(
  p_notification_id uuid
)
RETURNS public.notification_outbox
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old public.notification_outbox%ROWTYPE;
  v_row public.notification_outbox%ROWTYPE;
  v_lead public.leads%ROWTYPE;
  v_actor uuid;
BEGIN
  SELECT * INTO v_old FROM public.notification_outbox WHERE id=p_notification_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Notification job not found'; END IF;
  SELECT * INTO v_lead FROM public.leads WHERE id=v_old.lead_id;
  v_actor := public.lsh_sprint6_actor(v_old.organization_id,'lead.write',v_lead.branch_id);

  IF v_old.status='superseded'::public.notification_status THEN
    RAISE EXCEPTION 'Superseded jobs cannot be retried';
  END IF;

  UPDATE public.notification_outbox SET
    status=CASE WHEN attempt_count < max_attempts THEN 'queued'::public.notification_status
                ELSE 'manual_action_required'::public.notification_status END,
    scheduled_for=now(),
    attempt_count=CASE WHEN attempt_count < max_attempts THEN attempt_count ELSE attempt_count END,
    last_error_code=NULL,
    updated_by=v_actor
  WHERE id=v_old.id RETURNING * INTO v_row;

  IF v_row.status='manual_action_required'::public.notification_status THEN
    PERFORM public.create_lead_task(
      v_row.lead_id,'reminder_recovery','Manual reminder recovery required',
      'Provider delivery is not confirmed. Continue the reminder manually and record the outcome.',
      v_actor,'high',now()+interval '1 hour','notification_recovery',
      'notification-recovery:'||v_row.id::text
    );
  END IF;

  PERFORM public.lsh_sprint6_activity(
    v_row.organization_id,v_lead.branch_id,v_row.lead_id,
    'notification.recovery_requested','notification_outbox',v_row.id,
    'Notification recovery requested without claiming provider delivery.',
    jsonb_build_object('status',v_row.status)
  );
  PERFORM public.lsh_sprint6_audit(
    v_row.organization_id,v_lead.branch_id,'lead.notification.recovery_requested',
    'notification_outbox',v_row.id,false,
    jsonb_build_object('status',v_old.status),jsonb_build_object('status',v_row.status),
    jsonb_build_object('lead_id',v_row.lead_id)
  );
  RETURN v_row;
END;
$$;

-- ---------------------------------------------------------------------
-- Business-minutes calculator. Used by SLA snapshots; no writes.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lsh_business_minutes_between(
  p_organization_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_date date;
  v_last date;
  v_day public.business_calendar_days%ROWTYPE;
  v_open timestamptz;
  v_close timestamptz;
  v_from timestamptz;
  v_to timestamptz;
  v_total numeric := 0;
  v_tz text := 'Asia/Kolkata';
BEGIN
  IF p_start IS NULL OR p_end IS NULL OR p_end <= p_start THEN RETURN 0; END IF;

  SELECT COALESCE(max(timezone),'Asia/Kolkata') INTO v_tz
  FROM public.business_calendar_days WHERE organization_id=p_organization_id;

  v_date := (p_start AT TIME ZONE v_tz)::date;
  v_last := (p_end AT TIME ZONE v_tz)::date;

  WHILE v_date <= v_last LOOP
    SELECT * INTO v_day
    FROM public.business_calendar_days d
    WHERE d.organization_id=p_organization_id
      AND d.weekday=EXTRACT(DOW FROM v_date)::smallint;

    IF FOUND AND v_day.is_business_day
       AND NOT EXISTS (
         SELECT 1 FROM public.business_calendar_holidays h
         WHERE h.organization_id=p_organization_id AND h.holiday_date=v_date
       ) THEN
      v_open := (v_date::timestamp + v_day.local_start) AT TIME ZONE v_day.timezone;
      v_close := (v_date::timestamp + v_day.local_end) AT TIME ZONE v_day.timezone;
      v_from := GREATEST(p_start,v_open);
      v_to := LEAST(p_end,v_close);
      IF v_to > v_from THEN
        v_total := v_total + EXTRACT(EPOCH FROM (v_to-v_from))/60.0;
      END IF;
    END IF;
    v_date := v_date + 1;
  END LOOP;

  RETURN floor(v_total)::integer;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_lead_sla_override(
  p_lead_id uuid,
  p_sla_key text,
  p_reason text,
  p_expires_at timestamptz DEFAULT NULL,
  p_review_at timestamptz DEFAULT NULL
)
RETURNS public.lead_sla_overrides
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_lead public.leads%ROWTYPE;
  v_actor uuid;
  v_row public.lead_sla_overrides%ROWTYPE;
BEGIN
  SELECT * INTO v_lead FROM public.leads WHERE id=p_lead_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lead not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_lead.organization_id,'audit.sensitive.read',v_lead.branch_id);
  IF NOT public.has_permission(v_lead.organization_id,'lead.write',v_lead.branch_id) THEN
    RAISE EXCEPTION 'lead.write is required to create an SLA override' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.lead_sla_rules r
    WHERE r.organization_id=v_lead.organization_id AND r.sla_key=p_sla_key
  ) THEN RAISE EXCEPTION 'Unknown SLA key'; END IF;
  IF NULLIF(btrim(COALESCE(p_reason,'')), '') IS NULL THEN RAISE EXCEPTION 'Override reason is required'; END IF;
  IF p_expires_at IS NULL AND p_review_at IS NULL THEN RAISE EXCEPTION 'Override needs an expiry or review date'; END IF;

  INSERT INTO public.lead_sla_overrides (
    organization_id,lead_id,sla_key,reason,expires_at,review_at,created_by
  ) VALUES (
    v_lead.organization_id,v_lead.id,p_sla_key,left(btrim(p_reason),1000),p_expires_at,p_review_at,v_actor
  ) RETURNING * INTO v_row;

  PERFORM public.lsh_sprint6_audit(
    v_lead.organization_id,v_lead.branch_id,'lead.sla.override_created','lead_sla_override',v_row.id,true,
    NULL,
    jsonb_build_object('sla_key',v_row.sla_key,'has_expiry',v_row.expires_at IS NOT NULL,'has_review',v_row.review_at IS NOT NULL),
    jsonb_build_object('lead_id',v_lead.id,'reason_recorded',true)
  );
  RETURN v_row;
END;
$$;

-- Returns all 10 Sprint 6 SLA checks for one lead.
CREATE OR REPLACE FUNCTION public.lead_sla_snapshot(
  p_lead_id uuid
)
RETURNS TABLE (
  sla_key text,
  status text,
  elapsed_business_minutes integer,
  threshold_business_minutes integer,
  detail text,
  override_until timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_lead public.leads%ROWTYPE;
  v_actor uuid;
  v_first_outbound timestamptz;
  v_latest_activity timestamptz;
  v_next public.lead_next_actions%ROWTYPE;
  v_open_task_due timestamptz;
  v_confirmation_anchor timestamptz;
  v_failed_notification timestamptz;
  v_completed_consultation timestamptz;
  v_privacy_due timestamptz;
  v_safety_due timestamptz;
  v_key text;
  v_threshold integer;
  v_elapsed integer;
  v_status text;
  v_detail text;
  v_override timestamptz;
BEGIN
  SELECT * INTO v_lead FROM public.leads WHERE id=p_lead_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lead not found'; END IF;
  v_actor := public.lsh_sprint6_actor(v_lead.organization_id,'lead.read',v_lead.branch_id);
  PERFORM v_actor;

  SELECT min(c.occurred_at) INTO v_first_outbound
  FROM public.lead_communications c
  WHERE c.lead_id=v_lead.id AND c.direction='outbound'::public.communication_direction;

  SELECT * INTO v_next FROM public.lead_next_actions n WHERE n.lead_id=v_lead.id;

  SELECT min(t.due_at) INTO v_open_task_due
  FROM public.lead_tasks t
  WHERE t.lead_id=v_lead.id
    AND t.status IN ('open','in_progress','snoozed')
    AND t.due_at IS NOT NULL;

  SELECT min(c.created_at) INTO v_confirmation_anchor
  FROM public.consultations c
  WHERE c.lead_id=v_lead.id
    AND c.status IN ('pending_confirmation','tentative','scheduled')
    AND NOT EXISTS (
      SELECT 1 FROM public.lead_communications lc
      WHERE lc.consultation_id=c.id
        AND lc.direction='outbound'::public.communication_direction
        AND lc.business_purpose='consultation_confirmation'
    );

  SELECT min(n.created_at) INTO v_failed_notification
  FROM public.notification_outbox n
  WHERE n.lead_id=v_lead.id AND n.status IN ('failed','manual_action_required');

  SELECT max(c.completed_at) INTO v_completed_consultation
  FROM public.consultations c
  WHERE c.lead_id=v_lead.id AND c.status='completed' AND c.completed_at IS NOT NULL;

  SELECT min(t.due_at) INTO v_privacy_due
  FROM public.lead_tasks t
  WHERE t.lead_id=v_lead.id AND t.task_type='privacy_review'
    AND t.status IN ('open','in_progress','snoozed') AND t.due_at IS NOT NULL;

  SELECT min(t.due_at) INTO v_safety_due
  FROM public.lead_tasks t
  WHERE t.lead_id=v_lead.id AND t.task_type='safety_review'
    AND t.status IN ('open','in_progress','snoozed') AND t.due_at IS NOT NULL;

  SELECT greatest(v_lead.updated_at,COALESCE(max(a.created_at),v_lead.updated_at)) INTO v_latest_activity
  FROM public.lead_activity_events a WHERE a.lead_id=v_lead.id;

  FOR v_key,v_threshold IN
    SELECT r.sla_key,r.threshold_business_minutes
    FROM public.lead_sla_rules r
    WHERE r.organization_id=v_lead.organization_id AND r.is_active
    ORDER BY r.sla_key
  LOOP
    SELECT max(COALESCE(o.expires_at,o.review_at)) INTO v_override
    FROM public.lead_sla_overrides o
    WHERE o.lead_id=v_lead.id AND o.sla_key=v_key
      AND (o.expires_at IS NULL OR o.expires_at>now())
      AND (o.review_at IS NULL OR o.review_at>now());

    v_elapsed := 0;
    v_status := 'ok';
    v_detail := 'Within operating expectation.';

    IF v_key='first_response' THEN
      IF v_first_outbound IS NOT NULL THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_lead.created_at,v_first_outbound);
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'ok' END;
        v_detail := 'First outbound response recorded.';
      ELSE
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_lead.created_at,now());
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'due' END;
        v_detail := 'No outbound response is recorded.';
      END IF;

    ELSIF v_key='unassigned_lead' THEN
      IF v_lead.assigned_owner_member_id IS NULL THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_lead.created_at,now());
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'due' END;
        v_detail := 'Lead has no assigned owner.';
      ELSE v_status:='ok'; v_detail:='Lead has an assigned owner.'; END IF;

    ELSIF v_key='missing_next_action' THEN
      IF v_next.id IS NULL OR (v_next.action_text IS NULL AND v_next.exception_reason IS NULL) THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_lead.updated_at,now());
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'due' END;
        v_detail := 'Lead has no next action or approved exception.';
      ELSE v_status:='ok'; v_detail:='Next action discipline is present.'; END IF;

    ELSIF v_key='overdue_task' THEN
      IF v_open_task_due IS NOT NULL AND v_open_task_due<now() THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_open_task_due,now());
        v_status := 'breached'; v_detail := 'At least one active task is overdue.';
      ELSE v_status:='ok'; v_detail:='No active task is overdue.'; END IF;

    ELSIF v_key='consultation_confirmation' THEN
      IF v_confirmation_anchor IS NOT NULL THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_confirmation_anchor,now());
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'due' END;
        v_detail := 'Scheduled consultation has no recorded outbound confirmation.';
      ELSE v_status:='ok'; v_detail:='No confirmation gap is detected.'; END IF;

    ELSIF v_key='reminder_recovery' THEN
      IF v_failed_notification IS NOT NULL THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_failed_notification,now());
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'due' END;
        v_detail := 'A reminder job requires recovery or manual continuity.';
      ELSE v_status:='ok'; v_detail:='No reminder recovery is pending.'; END IF;

    ELSIF v_key='post_consultation_follow_up' THEN
      IF v_completed_consultation IS NOT NULL
         AND (v_next.id IS NULL OR v_next.updated_at < v_completed_consultation) THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_completed_consultation,now());
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'due' END;
        v_detail := 'Completed consultation needs a current follow-up action.';
      ELSE v_status:='ok'; v_detail:='Post-consultation next action is present or not applicable.'; END IF;

    ELSIF v_key='privacy_review' THEN
      IF v_privacy_due IS NOT NULL AND v_privacy_due<now() THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_privacy_due,now());
        v_status := 'breached'; v_detail := 'Privacy review task is overdue.';
      ELSE v_status:='ok'; v_detail:='No overdue privacy review task.'; END IF;

    ELSIF v_key='safety_review' THEN
      IF v_safety_due IS NOT NULL AND v_safety_due<now() THEN
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_safety_due,now());
        v_status := 'breached'; v_detail := 'Safety review task is overdue.';
      ELSE v_status:='ok'; v_detail:='No overdue safety review task.'; END IF;

    ELSIF v_key='stale_lead' THEN
      IF v_lead.status IN ('converted'::public.lead_status,'archived'::public.lead_status) THEN
        v_status:='not_applicable'; v_detail:='Terminal lead.';
      ELSE
        v_elapsed := public.lsh_business_minutes_between(v_lead.organization_id,v_latest_activity,now());
        v_status := CASE WHEN v_elapsed>v_threshold THEN 'breached' ELSE 'ok' END;
        v_detail := CASE WHEN v_status='breached' THEN 'Lead has become operationally stale.' ELSE 'Recent activity is within the stale-lead threshold.' END;
      END IF;
    END IF;

    IF v_override IS NOT NULL THEN
      v_status := 'overridden';
      v_detail := 'Authorised SLA override is active.';
    END IF;

    sla_key := v_key;
    status := v_status;
    elapsed_business_minutes := v_elapsed;
    threshold_business_minutes := v_threshold;
    detail := v_detail;
    override_until := v_override;
    RETURN NEXT;
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------
-- RLS and grants
-- ---------------------------------------------------------------------
ALTER TABLE public.lead_next_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_next_actions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lead_activity_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_activity_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lead_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_tasks FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lead_communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_communications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_availability_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_availability_windows FORCE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_blackouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_blackouts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_schedule_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_schedule_history FORCE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_private_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_private_notes FORCE ROW LEVEL SECURITY;
ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_outbox FORCE ROW LEVEL SECURITY;
ALTER TABLE public.business_calendar_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_calendar_days FORCE ROW LEVEL SECURITY;
ALTER TABLE public.business_calendar_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_calendar_holidays FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lead_sla_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_sla_rules FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lead_sla_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_sla_overrides FORCE ROW LEVEL SECURITY;

CREATE POLICY lead_next_actions_select_scoped ON public.lead_next_actions
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',branch_id));
CREATE POLICY lead_activity_events_select_scoped ON public.lead_activity_events
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',branch_id));
CREATE POLICY lead_tasks_select_scoped ON public.lead_tasks
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',branch_id));
CREATE POLICY lead_communications_select_scoped ON public.lead_communications
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',branch_id));
CREATE POLICY consultations_select_scoped ON public.consultations
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',branch_id));
CREATE POLICY consultation_schedule_history_select_scoped ON public.consultation_schedule_history
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.consultations c
    WHERE c.id=public.consultation_schedule_history.consultation_id
      AND c.organization_id=public.consultation_schedule_history.organization_id
      AND public.has_permission(c.organization_id,'lead.read',c.branch_id)
  )
);
CREATE POLICY notification_outbox_select_scoped ON public.notification_outbox
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.leads l
    WHERE l.id=public.notification_outbox.lead_id
      AND l.organization_id=public.notification_outbox.organization_id
      AND public.has_permission(l.organization_id,'lead.read',l.branch_id)
  )
);
CREATE POLICY consultation_availability_select_scoped ON public.consultation_availability_windows
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY consultation_blackouts_select_scoped ON public.consultation_blackouts
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY business_calendar_days_select_scoped ON public.business_calendar_days
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY business_calendar_holidays_select_scoped ON public.business_calendar_holidays
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY lead_sla_rules_select_scoped ON public.lead_sla_rules
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY lead_sla_overrides_select_sensitive ON public.lead_sla_overrides
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.leads l
    WHERE l.id=public.lead_sla_overrides.lead_id
      AND l.organization_id=public.lead_sla_overrides.organization_id
      AND public.has_permission(l.organization_id,'audit.sensitive.read',l.branch_id)
  )
);
-- consultation_private_notes deliberately has no SELECT policy.

REVOKE ALL ON TABLE public.lead_next_actions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.lead_activity_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.lead_tasks FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.lead_communications FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.consultation_availability_windows FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.consultation_blackouts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.consultations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.consultation_schedule_history FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.consultation_private_notes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.notification_outbox FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.business_calendar_days FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.business_calendar_holidays FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.lead_sla_rules FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.lead_sla_overrides FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE public.lead_next_actions TO authenticated;
GRANT SELECT ON TABLE public.lead_activity_events TO authenticated;
GRANT SELECT ON TABLE public.lead_tasks TO authenticated;
GRANT SELECT ON TABLE public.lead_communications TO authenticated;
GRANT SELECT ON TABLE public.consultation_availability_windows TO authenticated;
GRANT SELECT ON TABLE public.consultation_blackouts TO authenticated;
GRANT SELECT ON TABLE public.consultations TO authenticated;
GRANT SELECT ON TABLE public.consultation_schedule_history TO authenticated;
GRANT SELECT ON TABLE public.notification_outbox TO authenticated;
GRANT SELECT ON TABLE public.business_calendar_days TO authenticated;
GRANT SELECT ON TABLE public.business_calendar_holidays TO authenticated;
GRANT SELECT ON TABLE public.lead_sla_rules TO authenticated;
GRANT SELECT ON TABLE public.lead_sla_overrides TO authenticated;

-- Trusted service operations retain administrative recovery access.
GRANT ALL ON TABLE public.lead_next_actions,public.lead_activity_events,public.lead_tasks,
  public.lead_communications,public.consultation_availability_windows,public.consultation_blackouts,
  public.consultations,public.consultation_schedule_history,public.consultation_private_notes,
  public.notification_outbox,public.business_calendar_days,public.business_calendar_holidays,
  public.lead_sla_rules,public.lead_sla_overrides TO service_role;

DO $function_acl$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS signature, p.proname
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN (
      'lsh_sprint6_actor','lsh_sprint6_activity','lsh_sprint6_audit',
      'lsh_sprint6_immutable_event_guard','lsh_consultation_slot_is_available',
      'lsh_queue_consultation_notifications','lsh_business_minutes_between',
      'set_lead_next_action','create_lead_task','update_lead_task','record_lead_communication',
      'upsert_consultation_availability','create_consultation_blackout','schedule_consultation',
      'reschedule_consultation','cancel_consultation','mark_consultation_missed',
      'complete_consultation','get_consultation_private_notes','retry_notification',
      'create_lead_sla_override','lead_sla_snapshot'
    )
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',r.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
  END LOOP;
END
$function_acl$;

GRANT EXECUTE ON FUNCTION public.set_lead_next_action(uuid,text,timestamptz,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_lead_task(uuid,public.lead_task_type,text,text,uuid,public.lead_task_priority,timestamptz,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_lead_task(uuid,public.lead_task_status,public.lead_task_priority,timestamptz,timestamptz,uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_lead_communication(uuid,public.communication_channel,public.communication_direction,text,public.communication_status,text,timestamptz,text,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_consultation_availability(smallint,time,time,text,integer,integer,integer,integer,integer,integer,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_consultation_blackout(timestamptz,timestamptz,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_consultation(uuid,timestamptz,integer,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reschedule_consultation(uuid,timestamptz,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_consultation(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_consultation_missed(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_consultation(uuid,public.consultation_outcome,text,text,text,text,text,text,text,text,text,text,timestamptz,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_consultation_private_notes(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retry_notification(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_lead_sla_override(uuid,text,text,timestamptz,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lead_sla_snapshot(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- Final structural gates
-- ---------------------------------------------------------------------
DO $gate$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname IN (
    'lead_next_actions','lead_activity_events','lead_tasks','lead_communications',
    'consultation_availability_windows','consultation_blackouts','consultations',
    'consultation_schedule_history','consultation_private_notes','notification_outbox',
    'business_calendar_days','business_calendar_holidays','lead_sla_rules','lead_sla_overrides'
  ) AND c.relrowsecurity AND c.relforcerowsecurity;
  IF v_count <> 14 THEN RAISE EXCEPTION 'Sprint 6 gate failed: RLS/FORCE RLS count %',v_count; END IF;

  IF has_table_privilege('authenticated','public.consultation_private_notes','SELECT') THEN
    RAISE EXCEPTION 'Sprint 6 gate failed: private notes table is directly readable';
  END IF;

  IF has_table_privilege('authenticated','public.lead_tasks','INSERT')
     OR has_table_privilege('authenticated','public.lead_tasks','UPDATE')
     OR has_table_privilege('authenticated','public.lead_communications','INSERT')
     OR has_table_privilege('authenticated','public.consultations','INSERT') THEN
    RAISE EXCEPTION 'Sprint 6 gate failed: direct authenticated write privilege exists';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='lead_communications'
      AND column_name IN ('body','message_body','raw_body','content','message_text')
  ) THEN RAISE EXCEPTION 'Sprint 6 gate failed: communication body column exists'; END IF;

  IF (SELECT count(*) FROM public.lead_sla_rules r
      JOIN public.organizations o ON o.id=r.organization_id
      WHERE o.deleted_at IS NULL) <
     (SELECT count(*)*10 FROM public.organizations WHERE deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Sprint 6 gate failed: SLA rule seed incomplete';
  END IF;
END
$gate$;

COMMIT;
