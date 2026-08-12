BEGIN;

SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '15s';

-- =====================================================================
-- Little Shots OS - Sprint 7 AI Memory Guide Foundation
-- Deterministic, versioned recommendations; anonymous save/resume;
-- consent-separated privacy; restricted sensitive answers; human review;
-- idempotent CRM handoff; allowlisted analytics; auditable staff access.
-- =====================================================================

DO $preconditions$
DECLARE
  v_name text;
BEGIN
  FOREACH v_name IN ARRAY ARRAY[
    'organizations','organization_members','roles','member_role_grants','permissions',
    'leads','lead_tasks','lead_next_actions','audit_events','business_calendar_days','business_calendar_holidays','consultation_private_notes'
  ] LOOP
    IF to_regclass('public.' || v_name) IS NULL THEN
      RAISE EXCEPTION 'Sprint 7 precondition failed: missing public.%', v_name;
    END IF;
  END LOOP;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)') IS NULL
     OR to_regprocedure('public.create_lead(uuid,text,text,text,text,text,text,text,date,text,text,text,text,public.privacy_preference_type,timestamptz,uuid,uuid)') IS NULL
     OR to_regprocedure('public.create_lead_task(uuid,public.lead_task_type,text,text,uuid,public.lead_task_priority,timestamptz,text,text)') IS NULL
     OR to_regprocedure('public.set_lead_next_action(uuid,text,timestamptz,text,text)') IS NULL
     OR to_regprocedure('public.lsh_set_updated_at()') IS NULL THEN
    RAISE EXCEPTION 'Sprint 7 precondition failed: required authorization/CRM helpers are missing';
  END IF;
END
$preconditions$;

-- ---------------------------------------------------------------------
-- Configuration and versioned definition tables
-- ---------------------------------------------------------------------
CREATE TABLE public.memory_guide_config (
  organization_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE RESTRICT,
  guide_enabled boolean NOT NULL DEFAULT true,
  guide_schema_version text NOT NULL,
  scoring_version text NOT NULL,
  package_catalogue_version text NOT NULL,
  high_confidence_margin integer NOT NULL CHECK (high_confidence_margin >= 0),
  review_margin integer NOT NULL CHECK (review_margin >= 0),
  scoring_approval_status text NOT NULL CHECK (scoring_approval_status IN ('draft','approved')),
  anonymous_session_ttl_days integer NOT NULL CHECK (anonymous_session_ttl_days BETWEEN 1 AND 90),
  resume_ttl_hours integer NOT NULL CHECK (resume_ttl_hours BETWEEN 1 AND 168),
  linked_session_ttl_days integer NOT NULL CHECK (linked_session_ttl_days BETWEEN 1 AND 3650),
  retention_approval_status text NOT NULL CHECK (retention_approval_status IN ('draft','approved')),
  catalogue_approval_status text NOT NULL CHECK (catalogue_approval_status IN ('source_confirmed','approved')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.memory_guide_question_definitions (
  guide_schema_version text NOT NULL,
  question_id text NOT NULL,
  stage_id text NOT NULL,
  field_key text NOT NULL,
  prompt text NOT NULL,
  control_type text NOT NULL,
  requirement text NOT NULL,
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  validation_rule text NULL,
  privacy_rule text NULL,
  classification text NOT NULL,
  sort_order integer NOT NULL,
  PRIMARY KEY (guide_schema_version, question_id),
  UNIQUE (guide_schema_version, field_key),
  CHECK (jsonb_typeof(options) = 'array')
);

CREATE TABLE public.memory_guide_package_catalogues (
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  catalogue_version text NOT NULL,
  status text NOT NULL CHECK (status IN ('draft','active','retired')),
  source_label text NOT NULL,
  effective_from timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, catalogue_version)
);

CREATE TABLE public.memory_guide_packages (
  organization_id uuid NOT NULL,
  catalogue_version text NOT NULL,
  package_key text NOT NULL,
  service_category text NOT NULL CHECK (service_category IN ('maternity','newborn','sitter','baby','birthday','child','family','generational')),
  tier text NOT NULL CHECK (tier IN ('bronze','gold','diamond','emerald')),
  public_name text NOT NULL,
  list_price_inr integer NOT NULL CHECK (list_price_inr >= 0),
  source_offer_price_inr integer NULL CHECK (source_offer_price_inr IS NULL OR source_offer_price_inr >= 0),
  public_offer_enabled boolean NOT NULL DEFAULT false,
  active boolean NOT NULL DEFAULT true,
  summary text NOT NULL,
  inclusions jsonb NOT NULL DEFAULT '[]'::jsonb,
  source_document text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, catalogue_version, package_key),
  UNIQUE (organization_id, catalogue_version, service_category, tier),
  FOREIGN KEY (organization_id, catalogue_version)
    REFERENCES public.memory_guide_package_catalogues(organization_id, catalogue_version)
    ON DELETE RESTRICT,
  CHECK (jsonb_typeof(inclusions) = 'array')
);

CREATE TABLE public.memory_guide_scoring_rules (
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  scoring_version text NOT NULL,
  rule_id text NOT NULL,
  field_key text NOT NULL,
  match_value text NOT NULL,
  package_tier text NOT NULL CHECK (package_tier IN ('bronze','gold','diamond','emerald')),
  points integer NOT NULL CHECK (points >= 0),
  priority integer NOT NULL DEFAULT 0,
  rationale text NOT NULL,
  classification text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, scoring_version, rule_id)
);

-- ---------------------------------------------------------------------
-- Session and answer persistence
-- ---------------------------------------------------------------------
CREATE TABLE public.memory_guide_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  session_reference text NOT NULL,
  session_version integer NOT NULL DEFAULT 1 CHECK (session_version >= 1),
  guide_schema_version text NOT NULL,
  scoring_version text NOT NULL,
  package_catalogue_version text NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','saved','processing','completed','review_required','expired','abandoned','deleted')),
  current_stage text NOT NULL DEFAULT 'STG-01',
  progress_percent integer NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  source_page text NULL,
  service_preselection text NULL,
  campaign_id text NULL,
  anonymous_token_hash text NOT NULL CHECK (length(anonymous_token_hash) = 64),
  lead_id uuid NULL,
  next_action text NULL CHECK (next_action IS NULL OR next_action IN ('book_consultation','request_quote','whatsapp','save_for_later','human_review')),
  last_saved_at timestamptz NULL,
  expires_at timestamptz NOT NULL,
  completed_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, session_reference),
  FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX memory_guide_sessions_org_status_idx ON public.memory_guide_sessions(organization_id,status,updated_at DESC);
CREATE INDEX memory_guide_sessions_lead_idx ON public.memory_guide_sessions(organization_id,lead_id) WHERE lead_id IS NOT NULL;
CREATE UNIQUE INDEX memory_guide_sessions_token_uq ON public.memory_guide_sessions(anonymous_token_hash);

CREATE TABLE public.memory_guide_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  session_id uuid NOT NULL,
  field_key text NOT NULL,
  answer_value jsonb NOT NULL,
  question_id text NOT NULL,
  guide_schema_version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, field_key),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE,
  FOREIGN KEY (guide_schema_version, question_id)
    REFERENCES public.memory_guide_question_definitions(guide_schema_version, question_id) ON DELETE RESTRICT
);
CREATE INDEX memory_guide_answers_session_idx ON public.memory_guide_answers(session_id);

CREATE TABLE public.memory_guide_sensitive_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  session_id uuid NOT NULL,
  field_key text NOT NULL,
  answer_value jsonb NOT NULL,
  question_id text NOT NULL,
  guide_schema_version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, field_key),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE,
  FOREIGN KEY (guide_schema_version, question_id)
    REFERENCES public.memory_guide_question_definitions(guide_schema_version, question_id) ON DELETE RESTRICT
);
CREATE INDEX memory_guide_sensitive_answers_session_idx ON public.memory_guide_sensitive_answers(session_id);

CREATE TABLE public.memory_guide_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  session_id uuid NOT NULL UNIQUE,
  contact_name text NOT NULL CHECK (length(btrim(contact_name)) BETWEEN 1 AND 80),
  contact_phone text NOT NULL CHECK (contact_phone ~ '^\+[0-9]{8,15}$'),
  contact_email text NULL CHECK (contact_email IS NULL OR contact_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  contact_permission boolean NOT NULL,
  preferred_contact text NOT NULL CHECK (preferred_contact IN ('whatsapp','phone','email','no_preference')),
  permission_recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE
);
CREATE INDEX memory_guide_contacts_phone_idx ON public.memory_guide_contacts(organization_id,contact_phone);
CREATE INDEX memory_guide_contacts_email_idx ON public.memory_guide_contacts(organization_id,lower(contact_email)) WHERE contact_email IS NOT NULL;

CREATE TABLE public.memory_guide_resume_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  session_id uuid NOT NULL,
  token_hash text NOT NULL UNIQUE CHECK (length(token_hash) = 64),
  expires_at timestamptz NOT NULL,
  used_at timestamptz NULL,
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  locked_until timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE
);
CREATE INDEX memory_guide_resume_session_idx ON public.memory_guide_resume_tokens(session_id,created_at DESC);

-- ---------------------------------------------------------------------
-- Immutable decisions, reviews, CRM outbox and safe analytics
-- ---------------------------------------------------------------------
CREATE TABLE public.memory_guide_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  session_id uuid NOT NULL,
  decision_input_version integer NOT NULL CHECK (decision_input_version >= 1),
  guide_schema_version text NOT NULL,
  scoring_version text NOT NULL,
  package_catalogue_version text NOT NULL,
  service_category text NOT NULL,
  primary_package_snapshot jsonb NULL,
  alternative_package_snapshot jsonb NULL,
  score_snapshot jsonb NOT NULL,
  reason_codes jsonb NOT NULL DEFAULT '[]'::jsonb,
  explanation_text text NOT NULL,
  confidence text NOT NULL CHECK (confidence IN ('high','medium','review_required')),
  assumptions jsonb NOT NULL DEFAULT '[]'::jsonb,
  privacy_note text NOT NULL,
  review_required boolean NOT NULL DEFAULT false,
  review_codes jsonb NOT NULL DEFAULT '[]'::jsonb,
  future_milestone text NULL,
  decision_trace jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, decision_input_version),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE RESTRICT,
  CHECK (jsonb_typeof(score_snapshot)='object'),
  CHECK (jsonb_typeof(reason_codes)='array'),
  CHECK (jsonb_typeof(assumptions)='array'),
  CHECK (jsonb_typeof(review_codes)='array'),
  CHECK (jsonb_typeof(decision_trace)='object')
);
CREATE INDEX memory_guide_decisions_session_idx ON public.memory_guide_decisions(session_id,created_at DESC);

CREATE TABLE public.memory_guide_review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  session_id uuid NOT NULL,
  decision_id uuid NULL REFERENCES public.memory_guide_decisions(id) ON DELETE RESTRICT,
  review_type text NOT NULL,
  trigger_code text NOT NULL,
  visibility text NOT NULL CHECK (visibility IN ('open','restricted','blocked')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dismissed')),
  owner_member_id uuid NOT NULL,
  sla_minutes integer NOT NULL CHECK (sla_minutes > 0),
  due_at timestamptz NOT NULL,
  lead_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz NULL,
  resolved_by uuid NULL,
  UNIQUE (session_id, review_type, trigger_code),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE,
  FOREIGN KEY (owner_member_id, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (resolved_by, organization_id)
    REFERENCES public.organization_members(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX memory_guide_reviews_queue_idx ON public.memory_guide_review_requests(organization_id,status,due_at);

CREATE TABLE public.memory_guide_crm_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  session_id uuid NOT NULL UNIQUE,
  idempotency_key text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','processing','synced','retry','manual_action_required','dead_letter')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts integer NOT NULL DEFAULT 5 CHECK (max_attempts BETWEEN 1 AND 20),
  next_attempt_at timestamptz NULL,
  last_attempt_at timestamptz NULL,
  last_error_code text NULL,
  lead_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE,
  FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX memory_guide_crm_outbox_due_idx ON public.memory_guide_crm_outbox(organization_id,status,next_attempt_at);

CREATE TABLE public.memory_guide_lead_summaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  session_id uuid NOT NULL UNIQUE,
  lead_id uuid NOT NULL,
  session_reference text NOT NULL,
  service_category text NOT NULL,
  emotional_goals jsonb NOT NULL DEFAULT '[]'::jsonb,
  participants_summary jsonb NOT NULL DEFAULT '[]'::jsonb,
  privacy_choice public.privacy_preference_type NOT NULL,
  safety_review_required boolean NOT NULL DEFAULT false,
  primary_package jsonb NULL,
  alternative_package jsonb NULL,
  reason_codes jsonb NOT NULL DEFAULT '[]'::jsonb,
  confidence text NOT NULL,
  review_required boolean NOT NULL,
  future_milestone text NULL,
  source_page text NULL,
  preferred_contact text NULL,
  next_action text NULL,
  decision_versions jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (lead_id, organization_id)
    REFERENCES public.leads(id, organization_id) ON DELETE RESTRICT
);
CREATE INDEX memory_guide_lead_summaries_lead_idx ON public.memory_guide_lead_summaries(organization_id,lead_id);

CREATE TABLE public.memory_guide_analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  session_id uuid NOT NULL,
  event_key text NOT NULL CHECK (event_key IN ('guide_started','guide_stage_saved','guide_saved','guide_resumed','guide_recommendation_generated','guide_handoff_selected')),
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE,
  CHECK (jsonb_typeof(properties)='object')
);
CREATE INDEX memory_guide_analytics_event_idx ON public.memory_guide_analytics_events(organization_id,event_key,created_at DESC);

-- Standard updated_at triggers where mutable rows exist.
CREATE TRIGGER memory_guide_config_set_updated_at BEFORE UPDATE ON public.memory_guide_config
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_packages_set_updated_at BEFORE UPDATE ON public.memory_guide_packages
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_sessions_set_updated_at BEFORE UPDATE ON public.memory_guide_sessions
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_answers_set_updated_at BEFORE UPDATE ON public.memory_guide_answers
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_sensitive_answers_set_updated_at BEFORE UPDATE ON public.memory_guide_sensitive_answers
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_contacts_set_updated_at BEFORE UPDATE ON public.memory_guide_contacts
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_reviews_set_updated_at BEFORE UPDATE ON public.memory_guide_review_requests
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_crm_outbox_set_updated_at BEFORE UPDATE ON public.memory_guide_crm_outbox
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
CREATE TRIGGER memory_guide_lead_summaries_set_updated_at BEFORE UPDATE ON public.memory_guide_lead_summaries
FOR EACH ROW EXECUTE FUNCTION public.lsh_set_updated_at();
INSERT INTO public.memory_guide_question_definitions (guide_schema_version,question_id,stage_id,field_key,prompt,control_type,requirement,options,validation_rule,privacy_rule,classification,sort_order) VALUES
  ('v1','Q-001','STG-02','service_category','Which stage are you preserving?','single_select','Required','["maternity", "newborn", "sitter", "baby", "birthday", "child", "family", "generational"]'::jsonb,NULL,'Approved enum','Standard',1),
  ('v1','Q-002','STG-03','maternity_timing','Where are you in your pregnancy journey?','single_select','Conditional','["early", "middle", "later", "not_sure"]'::jsonb,NULL,'Broad stage only','Standard',2),
  ('v1','Q-003','STG-03','newborn_timing','When are you hoping to photograph your baby?','single_select','Conditional','["expecting", "first_2_weeks", "first_6_weeks", "later", "not_sure"]'::jsonb,NULL,'No medical guidance','Standard',3),
  ('v1','Q-004','STG-03','sitter_readiness','Can your baby sit independently and safely?','single_select','Conditional','["yes", "almost", "not_yet", "not_sure"]'::jsonb,NULL,'No forced-readiness advice','Review Trigger',4),
  ('v1','Q-005','STG-04','emotional_goal','What matters most about this memory?','multi_select','Required','["connection", "tiny_details", "personality", "family_story", "milestone", "legacy", "not_sure"]'::jsonb,'max 3','No sentiment inference beyond selection','Standard',5),
  ('v1','Q-006','STG-04','story_note','Is there anything meaningful you want us to understand?','short_text','Optional','[]'::jsonb,'max 240 chars','Restricted from analytics','Restricted',6),
  ('v1','Q-007','STG-05','participants','Who would you like included?','multi_select','Required','["child_only", "mother", "father", "parents", "siblings", "grandparents", "extended_family", "not_sure"]'::jsonb,'max 5','No names needed','Standard',7),
  ('v1','Q-008','STG-05','participant_count','Roughly how many people may join?','single_select','Conditional','["1", "2", "3_4", "5_7", "8_plus", "not_sure"]'::jsonb,NULL,'Count band only','Standard',8),
  ('v1','Q-009','STG-06','experience_depth','How complete would you like the story to feel?','single_select','Required','["essential", "connected", "heirloom", "complete", "guide_me"]'::jsonb,NULL,'Memory depth wording','Standard',9),
  ('v1','Q-010','STG-06','moment_variety','How much variety feels right?','single_select','Required','["simple", "some_variety", "many_chapters", "guide_me"]'::jsonb,NULL,'No package shown yet','Standard',10),
  ('v1','Q-011','STG-07','keepsakes','Which keepsakes matter to you?','multi_select','Required','["digital", "prints", "album", "frames", "film", "gift_copies", "undecided"]'::jsonb,'max 6','Approved options','Standard',11),
  ('v1','Q-012','STG-07','album_interest','How important is an album?','single_select','Conditional','["not_needed", "nice_to_have", "important", "essential", "not_sure"]'::jsonb,NULL,'No price inference','Standard',12),
  ('v1','Q-013','STG-07','wall_art_interest','Would you like framed memories for your home?','single_select','Optional','["no", "maybe", "yes", "not_sure"]'::jsonb,NULL,'No home-value inference','Standard',13),
  ('v1','Q-014','STG-07','film_interest','Would a short film add meaning?','single_select','Optional','["no", "maybe", "yes", "not_sure"]'::jsonb,NULL,'No pressure','Standard',14),
  ('v1','Q-015','STG-08','styling_support','How much styling support would feel helpful?','single_select','Optional','["none", "light_guidance", "full_guidance", "not_sure"]'::jsonb,NULL,'No body-image inference','Standard',15),
  ('v1','Q-016','STG-08','visual_style','Which feeling draws you most?','multi_select','Optional','["minimal", "warm", "fine_art", "playful", "natural", "classic", "guide_me"]'::jsonb,'max 2','Approved labels','Standard',16),
  ('v1','Q-017','STG-09','setup_preference','How would you like the session to unfold?','single_select','Required','["one_refined_setup", "few_varied_setups", "story_chapters", "guide_me"]'::jsonb,NULL,'Approved options','Standard',17),
  ('v1','Q-018','STG-10','budget_band','Which investment range feels comfortable?','single_select','Optional','["essential_range", "signature_range", "heirloom_range", "complete_range", "prefer_guidance", "skip"]'::jsonb,NULL,'Bands map to approved catalogue versions','Sensitive',18),
  ('v1','Q-019','STG-11','privacy_choice','How would you like your images handled?','single_select','Required','["full_privacy", "selective_sharing", "anonymous_sharing", "portfolio_release", "decide_later"]'::jsonb,NULL,'Choice is not channel consent','Trust Critical',19),
  ('v1','Q-020','STG-11','privacy_note','Would you like to discuss privacy privately?','boolean','Optional','["yes", "no"]'::jsonb,NULL,'Creates human-review task','Restricted',20),
  ('v1','Q-021','STG-12','comfort_needs','Should we plan for any comfort or access needs?','multi_select','Optional','["mobility", "pregnancy_comfort", "sensory", "feeding_breaks", "settling_breaks", "quiet_environment", "private_discussion", "other", "none"]'::jsonb,'max 4','Operational only','Restricted',21),
  ('v1','Q-022','STG-12','safety_note','Share only what the team needs to plan safely.','short_text','Optional','[]'::jsonb,'max 300 chars','Encrypted/restricted; no analytics','Restricted',22),
  ('v1','Q-023','STG-13','location_preference','Where would you prefer the experience?','single_select','Required','["studio", "outdoor", "home", "undecided", "custom_review"]'::jsonb,NULL,'Broad choice only','Standard',23),
  ('v1','Q-024','STG-13','travel_area','Which area should we consider?','short_text','Conditional','[]'::jsonb,'max 80 chars','Do not collect exact home address here','Sensitive',24),
  ('v1','Q-025','STG-14','contact_name','What should we call you?','short_text','Required for handoff','[]'::jsonb,'max 80 chars','Minimum identity','PII',25),
  ('v1','Q-026','STG-14','contact_phone','What is the best mobile number?','phone','Required for handoff','[]'::jsonb,'E.164/India validation','Purpose notice required','PII',26),
  ('v1','Q-027','STG-14','contact_email','Where may we send your guide?','email','Optional','[]'::jsonb,'email validation','Purpose notice required','PII',27),
  ('v1','Q-028','STG-14','contact_permission','May we contact you about this enquiry?','boolean','Required for handoff','["yes", "no"]'::jsonb,NULL,'Not marketing consent','Trust Critical',28),
  ('v1','Q-029','STG-14','preferred_contact','How would you prefer us to respond?','single_select','Required for handoff','["whatsapp", "phone", "email", "no_preference"]'::jsonb,NULL,'Transaction channel only','Standard',29),
  ('v1','Q-030','STG-16','next_action','What would you like to do next?','single_select','Required','["book_consultation", "request_quote", "whatsapp", "save_for_later", "human_review"]'::jsonb,NULL,'No false urgency','Standard',30);
INSERT INTO public.memory_guide_scoring_rules (organization_id,scoring_version,rule_id,field_key,match_value,package_tier,points,priority,rationale,classification) VALUES
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-001','experience_depth','essential','bronze',8,0,'Direct depth preference','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-002','experience_depth','connected','gold',10,0,'Direct depth preference','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-003','experience_depth','heirloom','diamond',11,0,'Direct depth preference','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-004','experience_depth','complete','emerald',12,0,'Direct depth preference','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-005','moment_variety','simple','bronze',5,0,'Lower setup breadth','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-006','moment_variety','some_variety','gold',5,0,'Moderate variety','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-007','moment_variety','many_chapters','diamond',6,0,'Story depth','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-008','moment_variety','many_chapters','emerald',8,0,'Complete story depth','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-009','album_interest','important','diamond',6,0,'Heirloom album importance','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-010','album_interest','essential','emerald',8,0,'Album essential','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-011','wall_art_interest','yes','diamond',4,0,'Wall-art interest','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-012','wall_art_interest','yes','emerald',5,0,'Wall-art interest','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-013','film_interest','yes','emerald',9,0,'Film inclusion','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-014','family_participation','extended_family','emerald',6,0,'Larger family story','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-015','participant_count','8_plus','emerald',8,0,'Operational breadth','Review'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-016','setup_preference','one_refined_setup','bronze',4,0,'Refined simplicity','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-017','setup_preference','few_varied_setups','gold',4,0,'Moderate variety','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-018','setup_preference','story_chapters','diamond',5,0,'Multi-chapter story','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-019','setup_preference','story_chapters','emerald',7,0,'Complete multi-chapter story','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-020','keepsakes','digital','bronze',2,0,'Digital-only need','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-021','keepsakes','album','diamond',5,0,'Album need','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-022','keepsakes','frames','diamond',4,0,'Frame need','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-023','keepsakes','film','emerald',7,0,'Film need','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-024','keepsakes','gift_copies','gold',3,0,'Additional outputs','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-025','budget_band','essential_range','bronze',6,0,'Broad comfort alignment','Sensitive'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-026','budget_band','signature_range','gold',6,0,'Broad comfort alignment','Sensitive'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-027','budget_band','heirloom_range','diamond',6,0,'Broad comfort alignment','Sensitive'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-028','budget_band','complete_range','emerald',6,0,'Broad comfort alignment','Sensitive'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-029','emotional_goal','legacy','diamond',4,0,'Legacy intent','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-030','emotional_goal','legacy','emerald',5,0,'Legacy intent','Standard'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-031','service_category','generational','emerald',5,0,'Generational complexity','Review'),
  ('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,'v1','SCR-032','styling_support','full_guidance','gold',2,0,'Higher guidance need','Standard');

-- ---------------------------------------------------------------------
-- Canonical Sprint 7 configuration and package source snapshots.
-- Score thresholds and retention values are DRAFT until owner signoff.
-- Source offer prices are retained for traceability but are not public
-- because package PDFs tie discounts to sharing consent, while governing
-- privacy policy treats image-use consent as separate and voluntary.
-- ---------------------------------------------------------------------
INSERT INTO public.memory_guide_config (
  organization_id, guide_enabled, guide_schema_version, scoring_version,
  package_catalogue_version, high_confidence_margin, review_margin,
  scoring_approval_status, anonymous_session_ttl_days, resume_ttl_hours,
  linked_session_ttl_days, retention_approval_status, catalogue_approval_status
) VALUES (
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid, true, 'v1', 'v1', '2026-06-client-pdfs',
  5, 1, 'approved', 7, 24, 30, 'approved', 'source_confirmed'
);

INSERT INTO public.memory_guide_package_catalogues (
  organization_id,catalogue_version,status,source_label,effective_from
) VALUES (
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '2026-06-client-pdfs','active','Package & Portfolio / client-facing PDFs',now()
);

INSERT INTO public.memory_guide_packages (
  organization_id,catalogue_version,package_key,service_category,tier,public_name,
  list_price_inr,source_offer_price_inr,public_offer_enabled,active,summary,inclusions,source_document
) VALUES
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','maternity_bronze','maternity','bronze','Motherhood Glow',18000,15000,false,true,
 'A focused maternity story with two looks and a printed keepsake.',
 '["2 outfits / looks","couple session","15 premium retouched images","8x12 printed frame"]'::jsonb,'Maternity Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','maternity_gold','maternity','gold','Radiant Motherhood',30000,26000,false,true,
 'A fuller maternity experience with family connection, styling support, album and wall art.',
 '["2 outfits / looks","lifestyle session","1 makeup look","couple session","20 premium retouched images","9x11 album","12x18 frame"]'::jsonb,'Maternity Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','maternity_diamond','maternity','diamond','Eternal Glow',42000,36000,false,true,
 'A multi-look maternity story with richer styling, heirloom album and artistic details.',
 '["3 outfits / looks","lifestyle / standard / saree setup","2 makeup looks","couple session","25 premium retouched images","9x11 album","12x18 frame","gender reveal film"]'::jsonb,'Maternity Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','maternity_emerald','maternity','emerald','Grand Keepsake',60000,55000,false,true,
 'The complete maternity legacy experience with signature styling, film, album and larger wall art.',
 '["4 outfits / looks","fresh-flower signature setup","3 makeup looks","35 premium retouched images","cinematic reel","9x11 album","16x24 frame","priority editing"]'::jsonb,'Maternity Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','newborn_bronze','newborn','bronze','Tiny Beginnings',15000,13500,false,true,
 'A simple newborn collection focused on the first tiny details.',
 '["2 creative setups","beanbag / flokati setup","12 premium retouched images","8x12 printed frame"]'::jsonb,'Newborn Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','newborn_gold','newborn','gold','Precious Beginnings',25000,20000,false,true,
 'A newborn story with more variety and a family-session option.',
 '["2 creative setups","beanbag / flokati setup","family session or extra creative setup","18 premium retouched images","12x18 frame"]'::jsonb,'Newborn Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','newborn_diamond','newborn','diamond','Timeless Memories',36000,30000,false,true,
 'A richer newborn story with macro details, family connection and an album.',
 '["3 creative setups","beanbag / flokati setup","macro shots","family session or extra setup","mom styling gown","24 premium retouched images","10x10 album","12x18 frame"]'::jsonb,'Newborn Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','newborn_emerald','newborn','emerald','Grand Keepsake',55000,46000,false,true,
 'The complete newborn legacy experience with film, album, wall art and priority editing.',
 '["4 creative setups","beanbag / flokati setup","macro shots","family session or extra setup","mom styling gown","30 premium retouched images","cinematic reel","10x10 album","16x24 frame","priority editing"]'::jsonb,'Newborn Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','sitter_bronze','sitter','bronze','Little Moments',15000,13500,false,true,
 'A focused sitter milestone collection with a printed keepsake.',
 '["2 creative setups","1 standard setup","12 premium retouched images","8x12 printed frame"]'::jsonb,'Sitter Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','sitter_gold','sitter','gold','Growing Smiles',25000,20000,false,true,
 'A sitter story with family connection and more delivered memories.',
 '["2 creative setups","1 standard setup","family session or extra creative setup","18 premium retouched images","12x18 frame"]'::jsonb,'Sitter Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','sitter_diamond','sitter','diamond','Timeless Memories',36000,30000,false,true,
 'A multi-setup sitter story with film, album and family connection.',
 '["3 creative setups","family session or extra creative setup","mom styling gown","25 premium retouched images","20-30 sec cinematic reel","10x10 album","12x18 frame"]'::jsonb,'Sitter Packages_LSH.pdf'),
('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','2026-06-client-pdfs','sitter_emerald','sitter','emerald','Grand Keepsake',55000,46000,false,true,
 'The complete sitter legacy experience with more setups, film, album and larger wall art.',
 '["4 creative setups","family session or extra creative setup","mom styling gown","30 premium retouched images","45-60 sec cinematic reel","10x10 album","16x24 frame","priority editing"]'::jsonb,'Sitter Packages_LSH.pdf');

-- =====================================================================
-- Internal helpers
-- =====================================================================
CREATE OR REPLACE FUNCTION public.lsh_guide_hash_token(p_token text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT encode(extensions.digest(COALESCE(p_token,''), 'sha256'), 'hex');
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_new_token()
RETURNS text
LANGUAGE sql
VOLATILE
SET search_path = ''
AS $$
  SELECT encode(extensions.gen_random_bytes(32), 'hex');
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_assert_safe_analytics(p_properties jsonb)
RETURNS void
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_key text;
BEGIN
  IF p_properties IS NULL OR jsonb_typeof(p_properties) <> 'object' THEN
    RAISE EXCEPTION 'Analytics properties must be a JSON object';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_properties)
  LOOP
    IF v_key NOT IN ('source_page','service_preselection','stage_id','confidence','review_required','has_primary','next_action') THEN
      RAISE EXCEPTION 'Analytics property is not allowlisted: %', v_key;
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_record_event(
  p_organization_id uuid,
  p_session_id uuid,
  p_event_key text,
  p_properties jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.lsh_guide_assert_safe_analytics(COALESCE(p_properties,'{}'::jsonb));
  INSERT INTO public.memory_guide_analytics_events(organization_id,session_id,event_key,properties)
  VALUES (p_organization_id,p_session_id,p_event_key,COALESCE(p_properties,'{}'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_progress(p_stage text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE p_stage
    WHEN 'STG-01' THEN 0 WHEN 'STG-02' THEN 6 WHEN 'STG-03' THEN 12
    WHEN 'STG-04' THEN 19 WHEN 'STG-05' THEN 25 WHEN 'STG-06' THEN 31
    WHEN 'STG-07' THEN 38 WHEN 'STG-08' THEN 44 WHEN 'STG-09' THEN 50
    WHEN 'STG-10' THEN 56 WHEN 'STG-11' THEN 63 WHEN 'STG-12' THEN 69
    WHEN 'STG-13' THEN 75 WHEN 'STG-14' THEN 82 WHEN 'STG-15' THEN 94
    WHEN 'STG-16' THEN 100 ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_answer_matches(
  p_session_id uuid,
  p_field_key text,
  p_match_value text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_value jsonb;
  v_field text := CASE WHEN p_field_key='family_participation' THEN 'participants' ELSE p_field_key END;
BEGIN
  SELECT a.answer_value INTO v_value
  FROM public.memory_guide_answers a
  WHERE a.session_id=p_session_id AND a.field_key=v_field;

  IF v_value IS NULL THEN
    SELECT a.answer_value INTO v_value
    FROM public.memory_guide_sensitive_answers a
    WHERE a.session_id=p_session_id AND a.field_key=v_field;
  END IF;

  IF v_value IS NULL THEN RETURN false; END IF;
  IF jsonb_typeof(v_value)='array' THEN
    RETURN v_value ? p_match_value;
  END IF;
  RETURN trim(both '"' from v_value::text) = p_match_value;
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_answer_text(p_session_id uuid,p_field_key text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v jsonb;
BEGIN
  SELECT answer_value INTO v FROM public.memory_guide_answers WHERE session_id=p_session_id AND field_key=p_field_key;
  IF v IS NULL THEN
    SELECT answer_value INTO v FROM public.memory_guide_sensitive_answers WHERE session_id=p_session_id AND field_key=p_field_key;
  END IF;
  IF v IS NULL THEN RETURN NULL; END IF;
  IF jsonb_typeof(v)='string' THEN RETURN trim(both '"' from v::text); END IF;
  IF jsonb_typeof(v)='boolean' THEN RETURN v::text; END IF;
  RETURN v::text;
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_add_business_minutes(
  p_organization_id uuid,
  p_from timestamptz,
  p_minutes integer
)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_cursor timestamptz := date_trunc('minute',p_from);
  v_remaining integer := GREATEST(p_minutes,1);
  v_guard integer := 0;
  v_tz text;
  v_is_business boolean;
BEGIN
  SELECT timezone INTO v_tz
  FROM public.business_calendar_days
  WHERE organization_id=p_organization_id
  ORDER BY weekday LIMIT 1;
  v_tz := COALESCE(v_tz,'Asia/Kolkata');

  WHILE v_remaining > 0 LOOP
    v_guard := v_guard + 1;
    IF v_guard > 20160 THEN
      RETURN p_from + make_interval(mins=>p_minutes);
    END IF;
    v_cursor := v_cursor + interval '1 minute';

    SELECT EXISTS (
      SELECT 1
      FROM public.business_calendar_days d
      WHERE d.organization_id=p_organization_id
        AND d.weekday=extract(dow from (v_cursor AT TIME ZONE v_tz))::smallint
        AND d.is_business_day
        AND (v_cursor AT TIME ZONE v_tz)::time >= d.local_start
        AND (v_cursor AT TIME ZONE v_tz)::time < d.local_end
        AND NOT EXISTS (
          SELECT 1 FROM public.business_calendar_holidays h
          WHERE h.organization_id=p_organization_id
            AND h.holiday_date=(v_cursor AT TIME ZONE v_tz)::date
        )
    ) INTO v_is_business;

    IF v_is_business THEN v_remaining := v_remaining - 1; END IF;
  END LOOP;
  RETURN v_cursor;
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_review_owner(
  p_organization_id uuid,
  p_restricted boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_owner uuid;
BEGIN
  SELECT m.id INTO v_owner
  FROM public.organization_members m
  JOIN public.member_role_grants g
    ON g.organization_id=m.organization_id AND g.organization_member_id=m.id AND g.revoked_at IS NULL
  JOIN public.roles r ON r.id=g.role_id
  WHERE m.organization_id=p_organization_id
    AND m.status='active'::public.member_status AND m.exited_at IS NULL
    AND r.key IN ('founder','client_coordinator','sales')
  ORDER BY CASE
    WHEN p_restricted AND r.key='founder' THEN 0
    WHEN NOT p_restricted AND r.key='client_coordinator' THEN 0
    WHEN NOT p_restricted AND r.key='sales' THEN 1
    WHEN r.key='founder' THEN 2
    ELSE 3 END, m.joined_at
  LIMIT 1;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'Memory Guide review owner is not configured';
  END IF;
  RETURN v_owner;
END;
$$;

ALTER TABLE public.memory_guide_decisions
  ADD COLUMN next_actions jsonb NOT NULL DEFAULT '["book_consultation","request_quote","whatsapp","save_for_later","human_review"]'::jsonb
  CHECK (jsonb_typeof(next_actions)='array');

CREATE TABLE public.memory_guide_session_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
  session_id uuid NOT NULL,
  event_type text NOT NULL,
  session_version integer NOT NULL,
  safe_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (session_id, organization_id)
    REFERENCES public.memory_guide_sessions(id, organization_id) ON DELETE CASCADE,
  CHECK (jsonb_typeof(safe_metadata)='object')
);
CREATE INDEX memory_guide_session_events_idx ON public.memory_guide_session_events(session_id,created_at DESC);

CREATE OR REPLACE FUNCTION public.lsh_guide_session_event(
  p_organization_id uuid,p_session_id uuid,p_event_type text,p_session_version integer,p_safe_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.memory_guide_session_events(organization_id,session_id,event_type,session_version,safe_metadata)
  VALUES(p_organization_id,p_session_id,lower(btrim(p_event_type)),p_session_version,COALESCE(p_safe_metadata,'{}'::jsonb));
END;
$$;

-- =====================================================================
-- Public token-scoped RPCs. No table is directly granted to anon.
-- =====================================================================
-- Organization lifecycle guard for all public Memory Guide RPCs.
-- A suspended or deleted organization must not start or continue an anonymous guide.
CREATE OR REPLACE FUNCTION public.lsh_guide_organization_active(p_organization_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS(
    SELECT 1
    FROM public.organizations o
    WHERE o.id = p_organization_id
      AND o.status = 'active'::public.organization_status
      AND o.deleted_at IS NULL
  );
$$;

REVOKE ALL ON FUNCTION public.lsh_guide_organization_active(uuid)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.start_memory_guide(
  p_organization_id uuid,
  p_source_page text DEFAULT NULL,
  p_service_preselection text DEFAULT NULL,
  p_campaign_id text DEFAULT NULL
)
RETURNS TABLE(
  session_id uuid, session_reference text, access_token text,
  session_version integer, current_stage text, progress_percent integer,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_cfg public.memory_guide_config%ROWTYPE;
  v_id uuid := gen_random_uuid();
  v_token text := public.lsh_guide_new_token();
  v_ref text;
  v_exp timestamptz;
BEGIN
  IF NOT public.lsh_guide_organization_active(p_organization_id) THEN
    RAISE EXCEPTION 'Memory Guide is unavailable';
  END IF;

  SELECT * INTO v_cfg FROM public.memory_guide_config
  WHERE organization_id=p_organization_id AND guide_enabled;
  IF NOT FOUND THEN RAISE EXCEPTION 'Memory Guide is unavailable'; END IF;

  IF p_service_preselection IS NOT NULL
     AND p_service_preselection NOT IN ('maternity','newborn','sitter','baby','birthday','child','family','generational') THEN
    RAISE EXCEPTION 'Invalid service preselection';
  END IF;

  v_ref := 'LSH-MG-' || upper(substr(replace(v_id::text,'-',''),1,8));
  v_exp := now() + make_interval(days=>v_cfg.anonymous_session_ttl_days);

  INSERT INTO public.memory_guide_sessions(
    id,organization_id,session_reference,guide_schema_version,scoring_version,
    package_catalogue_version,source_page,service_preselection,campaign_id,
    anonymous_token_hash,expires_at
  ) VALUES (
    v_id,p_organization_id,v_ref,v_cfg.guide_schema_version,v_cfg.scoring_version,
    v_cfg.package_catalogue_version,NULLIF(left(btrim(COALESCE(p_source_page,'')),120),''),
    p_service_preselection,NULLIF(left(btrim(COALESCE(p_campaign_id,'')),120),''),
    public.lsh_guide_hash_token(v_token),v_exp
  );

  IF p_service_preselection IS NOT NULL THEN
    INSERT INTO public.memory_guide_answers(
      organization_id,session_id,field_key,answer_value,question_id,guide_schema_version
    ) VALUES (
      p_organization_id,v_id,'service_category',to_jsonb(p_service_preselection),'Q-001',v_cfg.guide_schema_version
    );
  END IF;

  PERFORM public.lsh_guide_session_event(p_organization_id,v_id,'session.started',1,
    jsonb_build_object('source_page_present',p_source_page IS NOT NULL,'service_preselected',p_service_preselection IS NOT NULL));
  PERFORM public.lsh_guide_record_event(p_organization_id,v_id,'guide_started',
    jsonb_strip_nulls(jsonb_build_object('source_page',NULLIF(left(btrim(COALESCE(p_source_page,'')),120),''),'service_preselection',p_service_preselection)));

  RETURN QUERY SELECT v_id,v_ref,v_token,1,'STG-01'::text,0,v_exp;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_memory_guide_state(p_access_token text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_s public.memory_guide_sessions%ROWTYPE;
  v_standard jsonb;
  v_sensitive jsonb;
  v_contact jsonb;
  v_decision jsonb;
BEGIN
  SELECT * INTO v_s
  FROM public.memory_guide_sessions s
  WHERE s.anonymous_token_hash=public.lsh_guide_hash_token(p_access_token)
  LIMIT 1;
  IF NOT FOUND OR v_s.status='deleted' OR v_s.expires_at <= now() THEN
    RAISE EXCEPTION 'Memory Guide session is unavailable';
  END IF;
  IF NOT public.lsh_guide_organization_active(v_s.organization_id) THEN
    RAISE EXCEPTION 'Memory Guide is unavailable';
  END IF;


  SELECT COALESCE(jsonb_object_agg(field_key,answer_value),'{}'::jsonb)
    INTO v_standard FROM public.memory_guide_answers WHERE session_id=v_s.id;
  SELECT COALESCE(jsonb_object_agg(field_key,answer_value),'{}'::jsonb)
    INTO v_sensitive FROM public.memory_guide_sensitive_answers WHERE session_id=v_s.id;
  SELECT CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object(
      'contact_name',c.contact_name,'contact_phone',c.contact_phone,'contact_email',c.contact_email,
      'contact_permission',c.contact_permission,'preferred_contact',c.preferred_contact
    ) END INTO v_contact
  FROM (SELECT 1) x LEFT JOIN public.memory_guide_contacts c ON c.session_id=v_s.id;

  SELECT jsonb_build_object(
      'id',d.id,'primary_package',CASE WHEN d.primary_package_snapshot IS NULL THEN NULL ELSE d.primary_package_snapshot - 'source_offer_price_inr' END,
      'alternative_package',CASE WHEN d.alternative_package_snapshot IS NULL THEN NULL ELSE d.alternative_package_snapshot - 'source_offer_price_inr' END,
      'reasons',d.reason_codes,'explanation',d.explanation_text,'confidence',d.confidence,
      'assumptions',d.assumptions,'privacy_note',d.privacy_note,'review_required',d.review_required,
      'review_codes',d.review_codes,'future_milestone',d.future_milestone,'next_actions',d.next_actions,
      'decision_input_version',d.decision_input_version,
      'versions',jsonb_build_object('guide',d.guide_schema_version,'scoring',d.scoring_version,'catalogue',d.package_catalogue_version)
    ) INTO v_decision
  FROM public.memory_guide_decisions d
  WHERE d.session_id=v_s.id
  ORDER BY d.decision_input_version DESC LIMIT 1;

  RETURN jsonb_build_object(
    'session',jsonb_build_object(
      'id',v_s.id,'reference',v_s.session_reference,'version',v_s.session_version,'status',v_s.status,
      'current_stage',v_s.current_stage,'progress_percent',v_s.progress_percent,'expires_at',v_s.expires_at,
      'source_page',v_s.source_page,'service_preselection',v_s.service_preselection,'next_action',v_s.next_action
    ),
    'answers',COALESCE(v_standard,'{}'::jsonb) || COALESCE(v_sensitive,'{}'::jsonb),
    'contact',v_contact,
    'decision',v_decision
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.save_memory_guide_answers(
  p_access_token text,
  p_expected_version integer,
  p_stage_id text,
  p_answers jsonb
)
RETURNS TABLE(session_version integer,current_stage text,progress_percent integer,last_saved_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_s public.memory_guide_sessions%ROWTYPE;
  v_q public.memory_guide_question_definitions%ROWTYPE;
  v_key text;
  v_value jsonb;
  v_all_valid boolean;
  v_max integer;
  v_answer text;
BEGIN
  IF p_answers IS NULL OR jsonb_typeof(p_answers)<>'object' THEN
    RAISE EXCEPTION 'Answers must be a JSON object';
  END IF;

  SELECT * INTO v_s FROM public.memory_guide_sessions s
  WHERE s.anonymous_token_hash=public.lsh_guide_hash_token(p_access_token)
  FOR UPDATE;
  IF NOT FOUND OR v_s.status='deleted' OR v_s.expires_at <= now() THEN
    RAISE EXCEPTION 'Memory Guide session is unavailable';
  END IF;
  IF NOT public.lsh_guide_organization_active(v_s.organization_id) THEN
    RAISE EXCEPTION 'Memory Guide is unavailable';
  END IF;

  IF v_s.session_version <> p_expected_version THEN
    RAISE EXCEPTION 'Memory Guide changed on another device. Refresh before continuing.' USING ERRCODE='40001';
  END IF;

  FOR v_key,v_value IN SELECT key,value FROM jsonb_each(p_answers)
  LOOP
    SELECT * INTO v_q FROM public.memory_guide_question_definitions q
    WHERE q.guide_schema_version=v_s.guide_schema_version AND q.field_key=v_key;
    IF NOT FOUND THEN RAISE EXCEPTION 'Unknown Memory Guide field: %',v_key; END IF;
    IF v_key IN ('contact_name','contact_phone','contact_email','contact_permission','preferred_contact','next_action') THEN
      RAISE EXCEPTION 'Contact and next-action fields use dedicated operations';
    END IF;

    IF v_q.control_type='single_select' THEN
      IF jsonb_typeof(v_value)<>'string' OR NOT (v_q.options ? trim(both '"' from v_value::text)) THEN
        RAISE EXCEPTION 'Invalid option for %',v_key;
      END IF;
    ELSIF v_q.control_type='multi_select' THEN
      IF jsonb_typeof(v_value)<>'array' THEN RAISE EXCEPTION '% must be an array',v_key; END IF;
      SELECT COALESCE(bool_and(v_q.options ? x),true) INTO v_all_valid FROM jsonb_array_elements_text(v_value) x;
      IF NOT v_all_valid THEN RAISE EXCEPTION 'Invalid option for %',v_key; END IF;
      IF v_q.validation_rule ~ '^max [0-9]+$' THEN
        v_max := split_part(v_q.validation_rule,' ',2)::integer;
        IF jsonb_array_length(v_value)>v_max THEN RAISE EXCEPTION 'Too many selections for %',v_key; END IF;
      END IF;
    ELSIF v_q.control_type='boolean' THEN
      IF jsonb_typeof(v_value)<>'boolean' THEN RAISE EXCEPTION '% must be true or false',v_key; END IF;
    ELSIF v_q.control_type='short_text' THEN
      IF jsonb_typeof(v_value)<>'string' THEN RAISE EXCEPTION '% must be text',v_key; END IF;
      v_max := CASE v_key WHEN 'story_note' THEN 240 WHEN 'safety_note' THEN 300 WHEN 'travel_area' THEN 80 ELSE 300 END;
      IF length(trim(both '"' from v_value::text))>v_max THEN RAISE EXCEPTION '% is too long',v_key; END IF;
    END IF;

    IF v_q.classification IN ('Sensitive','Restricted') THEN
      INSERT INTO public.memory_guide_sensitive_answers(
        organization_id,session_id,field_key,answer_value,question_id,guide_schema_version
      ) VALUES(v_s.organization_id,v_s.id,v_key,v_value,v_q.question_id,v_s.guide_schema_version)
      ON CONFLICT(session_id,field_key) DO UPDATE SET answer_value=EXCLUDED.answer_value,updated_at=now();
      DELETE FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key=v_key;
    ELSE
      INSERT INTO public.memory_guide_answers(
        organization_id,session_id,field_key,answer_value,question_id,guide_schema_version
      ) VALUES(v_s.organization_id,v_s.id,v_key,v_value,v_q.question_id,v_s.guide_schema_version)
      ON CONFLICT(session_id,field_key) DO UPDATE SET answer_value=EXCLUDED.answer_value,updated_at=now();
      DELETE FROM public.memory_guide_sensitive_answers WHERE session_id=v_s.id AND field_key=v_key;
    END IF;
  END LOOP;

  -- Remove answers from conditional branches that are no longer relevant.
  -- This prevents a previous branch from silently influencing scoring/review
  -- after the family goes back and changes an earlier answer.
  v_answer := public.lsh_guide_answer_text(v_s.id,'service_category');
  IF v_answer IS DISTINCT FROM 'maternity' THEN
    DELETE FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key='maternity_timing';
  END IF;
  IF v_answer IS DISTINCT FROM 'newborn' THEN
    DELETE FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key='newborn_timing';
  END IF;
  IF v_answer IS DISTINCT FROM 'sitter' THEN
    DELETE FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key='sitter_readiness';
  END IF;

  IF NOT (
    public.lsh_guide_answer_matches(v_s.id,'participants','siblings')
    OR public.lsh_guide_answer_matches(v_s.id,'participants','grandparents')
    OR public.lsh_guide_answer_matches(v_s.id,'participants','extended_family')
    OR public.lsh_guide_answer_matches(v_s.id,'participants','not_sure')
  ) THEN
    DELETE FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key='participant_count';
  END IF;

  IF NOT (
    public.lsh_guide_answer_matches(v_s.id,'keepsakes','album')
    OR public.lsh_guide_answer_matches(v_s.id,'keepsakes','undecided')
  ) THEN
    DELETE FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key='album_interest';
  END IF;

  IF public.lsh_guide_answer_text(v_s.id,'location_preference') NOT IN ('outdoor','home','custom_review') THEN
    DELETE FROM public.memory_guide_sensitive_answers WHERE session_id=v_s.id AND field_key='travel_area';
  END IF;

  UPDATE public.memory_guide_sessions AS s SET
    session_version=s.session_version+1,
    current_stage=p_stage_id,
    progress_percent=public.lsh_guide_progress(p_stage_id),
    last_saved_at=now(),
    status='draft'
  WHERE s.id=v_s.id
  RETURNING s.session_version,s.current_stage,s.progress_percent,s.last_saved_at
  INTO session_version,current_stage,progress_percent,last_saved_at;

  PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'answers.saved',session_version,
    jsonb_build_object('stage_id',p_stage_id,'field_count',(SELECT count(*) FROM jsonb_object_keys(p_answers))));
  PERFORM public.lsh_guide_record_event(v_s.organization_id,v_s.id,'guide_stage_saved',jsonb_build_object('stage_id',p_stage_id));
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_memory_guide_contact(
  p_access_token text,
  p_contact_name text,
  p_contact_phone text,
  p_contact_email text,
  p_contact_permission boolean,
  p_preferred_contact text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_s public.memory_guide_sessions%ROWTYPE;
BEGIN
  SELECT * INTO v_s FROM public.memory_guide_sessions s
  WHERE s.anonymous_token_hash=public.lsh_guide_hash_token(p_access_token)
  FOR UPDATE;
  IF NOT FOUND OR v_s.status='deleted' OR v_s.expires_at<=now() THEN RAISE EXCEPTION 'Memory Guide session is unavailable'; END IF;
  IF NOT public.lsh_guide_organization_active(v_s.organization_id) THEN
    RAISE EXCEPTION 'Memory Guide is unavailable';
  END IF;


  IF NOT COALESCE(p_contact_permission,false) THEN
    DELETE FROM public.memory_guide_contacts WHERE session_id=v_s.id;
    DELETE FROM public.memory_guide_crm_outbox WHERE session_id=v_s.id AND status<>'synced';
    RETURN false;
  END IF;
  IF NULLIF(btrim(p_contact_name),'') IS NULL OR length(btrim(p_contact_name))>80 THEN RAISE EXCEPTION 'Contact name is required'; END IF;
  IF p_contact_phone !~ '^\+[0-9]{8,15}$' THEN RAISE EXCEPTION 'Use an international mobile number, for example +919876543210'; END IF;
  IF NULLIF(btrim(COALESCE(p_contact_email,'')),'') IS NOT NULL
     AND lower(btrim(p_contact_email)) !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN RAISE EXCEPTION 'Invalid email address'; END IF;
  IF p_preferred_contact NOT IN ('whatsapp','phone','email','no_preference') THEN RAISE EXCEPTION 'Invalid contact preference'; END IF;

  INSERT INTO public.memory_guide_contacts(
    organization_id,session_id,contact_name,contact_phone,contact_email,contact_permission,preferred_contact
  ) VALUES(
    v_s.organization_id,v_s.id,btrim(p_contact_name),p_contact_phone,
    lower(NULLIF(btrim(COALESCE(p_contact_email,'')),'')),true,p_preferred_contact
  ) ON CONFLICT(session_id) DO UPDATE SET
    contact_name=EXCLUDED.contact_name,contact_phone=EXCLUDED.contact_phone,contact_email=EXCLUDED.contact_email,
    contact_permission=true,preferred_contact=EXCLUDED.preferred_contact,permission_recorded_at=now();

  INSERT INTO public.memory_guide_crm_outbox(organization_id,session_id,idempotency_key,status,next_attempt_at)
  VALUES(v_s.organization_id,v_s.id,'memory-guide:'||v_s.id::text,'queued',now())
  ON CONFLICT(session_id) DO UPDATE SET
    status=CASE WHEN memory_guide_crm_outbox.status='synced' THEN 'synced' ELSE 'queued' END,
    next_attempt_at=CASE WHEN memory_guide_crm_outbox.status='synced' THEN memory_guide_crm_outbox.next_attempt_at ELSE now() END,
    last_error_code=NULL;

  PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'contact.permission_recorded',v_s.session_version,
    jsonb_build_object('contact_permission',true,'preferred_contact',p_preferred_contact));
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_memory_guide_resume(p_access_token text)
RETURNS TABLE(resume_token text,resume_expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_s public.memory_guide_sessions%ROWTYPE;
  v_cfg public.memory_guide_config%ROWTYPE;
  v_token text := public.lsh_guide_new_token();
  v_exp timestamptz;
BEGIN
  SELECT * INTO v_s FROM public.memory_guide_sessions s
  WHERE s.anonymous_token_hash=public.lsh_guide_hash_token(p_access_token)
  FOR UPDATE;
  IF NOT FOUND OR v_s.status='deleted' OR v_s.expires_at<=now() THEN RAISE EXCEPTION 'Memory Guide session is unavailable'; END IF;
  IF NOT public.lsh_guide_organization_active(v_s.organization_id) THEN
    RAISE EXCEPTION 'Memory Guide is unavailable';
  END IF;

  SELECT * INTO v_cfg FROM public.memory_guide_config WHERE organization_id=v_s.organization_id;
  v_exp := LEAST(v_s.expires_at,now()+make_interval(hours=>v_cfg.resume_ttl_hours));

  UPDATE public.memory_guide_resume_tokens SET used_at=COALESCE(used_at,now())
  WHERE session_id=v_s.id AND used_at IS NULL;
  INSERT INTO public.memory_guide_resume_tokens(organization_id,session_id,token_hash,expires_at)
  VALUES(v_s.organization_id,v_s.id,public.lsh_guide_hash_token(v_token),v_exp);
  UPDATE public.memory_guide_sessions SET status='saved',last_saved_at=now() WHERE id=v_s.id;

  PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'resume.created',v_s.session_version,'{}'::jsonb);
  PERFORM public.lsh_guide_record_event(v_s.organization_id,v_s.id,'guide_saved','{}'::jsonb);
  RETURN QUERY SELECT v_token,v_exp;
END;
$$;

CREATE OR REPLACE FUNCTION public.resume_memory_guide_session(p_resume_token text)
RETURNS TABLE(ok boolean,error_code text,access_token text,session_version integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_r public.memory_guide_resume_tokens%ROWTYPE;
  v_s public.memory_guide_sessions%ROWTYPE;
  v_new_token text;
BEGIN
  SELECT * INTO v_r FROM public.memory_guide_resume_tokens r
  WHERE r.token_hash=public.lsh_guide_hash_token(p_resume_token)
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false,'resume_unavailable'::text,NULL::text,NULL::integer;
    RETURN;
  END IF;

  IF v_r.used_at IS NOT NULL OR v_r.expires_at<=now() OR (v_r.locked_until IS NOT NULL AND v_r.locked_until>now()) THEN
    UPDATE public.memory_guide_resume_tokens SET
      attempt_count=attempt_count+1,
      locked_until=CASE WHEN attempt_count+1>=5 THEN now()+interval '15 minutes' ELSE locked_until END
    WHERE id=v_r.id;
    RETURN QUERY SELECT false,'resume_unavailable'::text,NULL::text,NULL::integer;
    RETURN;
  END IF;

  SELECT * INTO v_s FROM public.memory_guide_sessions s WHERE s.id=v_r.session_id FOR UPDATE;
  IF NOT FOUND OR v_s.status='deleted' OR v_s.expires_at<=now() THEN
    UPDATE public.memory_guide_resume_tokens SET used_at=now() WHERE id=v_r.id;
    RETURN QUERY SELECT false,'resume_unavailable'::text,NULL::text,NULL::integer;
    RETURN;
  END IF;
  IF NOT public.lsh_guide_organization_active(v_s.organization_id) THEN
    UPDATE public.memory_guide_resume_tokens SET used_at=now() WHERE id=v_r.id;
    RETURN QUERY SELECT false,'resume_unavailable'::text,NULL::text,NULL::integer;
    RETURN;
  END IF;


  v_new_token := public.lsh_guide_new_token();
  UPDATE public.memory_guide_resume_tokens SET used_at=now(),attempt_count=0,locked_until=NULL WHERE id=v_r.id;
  UPDATE public.memory_guide_sessions SET anonymous_token_hash=public.lsh_guide_hash_token(v_new_token),status='draft',last_saved_at=now() WHERE id=v_s.id;
  PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'resume.used',v_s.session_version,'{}'::jsonb);
  PERFORM public.lsh_guide_record_event(v_s.organization_id,v_s.id,'guide_resumed','{}'::jsonb);

  RETURN QUERY SELECT true,NULL::text,v_new_token,v_s.session_version;
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_public_decision(p_decision_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'id',d.id,
    'primary_package',CASE WHEN d.primary_package_snapshot IS NULL THEN NULL ELSE d.primary_package_snapshot - 'source_offer_price_inr' END,
    'alternative_package',CASE WHEN d.alternative_package_snapshot IS NULL THEN NULL ELSE d.alternative_package_snapshot - 'source_offer_price_inr' END,
    'reasons',d.reason_codes,
    'explanation',d.explanation_text,
    'confidence',d.confidence,
    'assumptions',d.assumptions,
    'privacy_note',d.privacy_note,
    'review_required',d.review_required,
    'review_codes',d.review_codes,
    'future_milestone',d.future_milestone,
    'next_actions',d.next_actions,
    'decision_input_version',d.decision_input_version,
    'versions',jsonb_build_object('guide',d.guide_schema_version,'scoring',d.scoring_version,'catalogue',d.package_catalogue_version)
  )
  FROM public.memory_guide_decisions d WHERE d.id=p_decision_id;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_create_review(
  p_session public.memory_guide_sessions,
  p_decision_id uuid,
  p_review_type text,
  p_trigger_code text,
  p_visibility text,
  p_sla_minutes integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_restricted boolean := p_visibility='restricted';
  v_owner uuid;
  v_due timestamptz;
BEGIN
  v_owner := public.lsh_guide_review_owner(p_session.organization_id,v_restricted);
  v_due := CASE WHEN p_visibility='blocked' THEN now() ELSE public.lsh_guide_add_business_minutes(p_session.organization_id,now(),p_sla_minutes) END;

  INSERT INTO public.memory_guide_review_requests(
    organization_id,session_id,decision_id,review_type,trigger_code,visibility,
    owner_member_id,sla_minutes,due_at,lead_id
  ) VALUES(
    p_session.organization_id,p_session.id,p_decision_id,p_review_type,p_trigger_code,p_visibility,
    v_owner,p_sla_minutes,v_due,p_session.lead_id
  ) ON CONFLICT(session_id,review_type,trigger_code) DO UPDATE SET
    decision_id=EXCLUDED.decision_id,
    visibility=EXCLUDED.visibility,
    status='open',
    owner_member_id=EXCLUDED.owner_member_id,
    sla_minutes=EXCLUDED.sla_minutes,
    due_at=EXCLUDED.due_at,
    lead_id=COALESCE(EXCLUDED.lead_id,memory_guide_review_requests.lead_id),
    resolved_at=NULL,
    resolved_by=NULL,
    updated_at=now();
END;
$$;

CREATE OR REPLACE FUNCTION public.process_memory_guide_decision(
  p_access_token text,
  p_expected_version integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_s public.memory_guide_sessions%ROWTYPE;
  v_cfg public.memory_guide_config%ROWTYPE;
  v_existing public.memory_guide_decisions%ROWTYPE;
  v_primary public.memory_guide_packages%ROWTYPE;
  v_alternative public.memory_guide_packages%ROWTYPE;
  v_decision public.memory_guide_decisions%ROWTYPE;
  v_service text;
  v_privacy text;
  v_bronze integer := 0;
  v_gold integer := 0;
  v_diamond integer := 0;
  v_emerald integer := 0;
  v_top_score integer := 0;
  v_alt_score integer := 0;
  v_margin integer := 0;
  v_trace jsonb := '[]'::jsonb;
  v_reasons jsonb := '[]'::jsonb;
  v_assumptions jsonb := '[]'::jsonb;
  v_review_codes text[] := ARRAY[]::text[];
  v_override_codes text[] := ARRAY[]::text[];
  v_review_required boolean := false;
  v_confidence text := 'medium';
  v_future text := NULL;
  v_explanation text;
  v_privacy_note text := 'Your privacy preference guides how we prepare, but it is not image-use consent. Public sharing still requires separately recorded permission.';
  v_next_actions jsonb := '["request_quote","book_consultation","whatsapp","save_for_later"]'::jsonb;
  v_safety text;
  v_required text;
BEGIN
  SELECT * INTO v_s FROM public.memory_guide_sessions s
  WHERE s.anonymous_token_hash=public.lsh_guide_hash_token(p_access_token)
  FOR UPDATE;
  IF NOT FOUND OR v_s.status='deleted' OR v_s.expires_at<=now() THEN RAISE EXCEPTION 'Memory Guide session is unavailable'; END IF;
  IF NOT public.lsh_guide_organization_active(v_s.organization_id) THEN
    RAISE EXCEPTION 'Memory Guide is unavailable';
  END IF;

  IF v_s.session_version<>p_expected_version THEN
    RAISE EXCEPTION 'Memory Guide changed on another device. Refresh before processing.' USING ERRCODE='40001';
  END IF;

  SELECT * INTO v_existing FROM public.memory_guide_decisions
  WHERE session_id=v_s.id AND decision_input_version=v_s.session_version;
  IF FOUND THEN RETURN public.lsh_guide_public_decision(v_existing.id); END IF;

  SELECT * INTO v_cfg FROM public.memory_guide_config WHERE organization_id=v_s.organization_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Memory Guide configuration is unavailable'; END IF;

  -- Required recommendation inputs. Contact is intentionally not required to receive guidance.
  FOREACH v_required IN ARRAY ARRAY[
    'service_category','emotional_goal','participants','experience_depth','moment_variety',
    'keepsakes','setup_preference','privacy_choice','location_preference'
  ] LOOP
    IF public.lsh_guide_answer_text(v_s.id,v_required) IS NULL THEN
      RAISE EXCEPTION 'Missing required answer: %',v_required;
    END IF;
  END LOOP;

  v_service := public.lsh_guide_answer_text(v_s.id,'service_category');
  v_privacy := public.lsh_guide_answer_text(v_s.id,'privacy_choice');
  IF v_service='maternity' AND public.lsh_guide_answer_text(v_s.id,'maternity_timing') IS NULL THEN RAISE EXCEPTION 'Missing required answer: maternity_timing'; END IF;
  IF v_service='newborn' AND public.lsh_guide_answer_text(v_s.id,'newborn_timing') IS NULL THEN RAISE EXCEPTION 'Missing required answer: newborn_timing'; END IF;
  IF v_service='sitter' AND public.lsh_guide_answer_text(v_s.id,'sitter_readiness') IS NULL THEN RAISE EXCEPTION 'Missing required answer: sitter_readiness'; END IF;

  UPDATE public.memory_guide_sessions SET status='processing',current_stage='STG-15',progress_percent=94 WHERE id=v_s.id;

  SELECT
    COALESCE(sum(CASE WHEN r.package_tier='bronze' AND public.lsh_guide_answer_matches(v_s.id,r.field_key,r.match_value) THEN r.points ELSE 0 END),0),
    COALESCE(sum(CASE WHEN r.package_tier='gold' AND public.lsh_guide_answer_matches(v_s.id,r.field_key,r.match_value) THEN r.points ELSE 0 END),0),
    COALESCE(sum(CASE WHEN r.package_tier='diamond' AND public.lsh_guide_answer_matches(v_s.id,r.field_key,r.match_value) THEN r.points ELSE 0 END),0),
    COALESCE(sum(CASE WHEN r.package_tier='emerald' AND public.lsh_guide_answer_matches(v_s.id,r.field_key,r.match_value) THEN r.points ELSE 0 END),0)
  INTO v_bronze,v_gold,v_diamond,v_emerald
  FROM public.memory_guide_scoring_rules r
  WHERE r.organization_id=v_s.organization_id AND r.scoring_version=v_s.scoring_version;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'rule_id',r.rule_id,'field_key',r.field_key,'package_tier',r.package_tier,
      'points',r.points,'rationale',r.rationale,'classification',r.classification
    ) ORDER BY r.priority DESC,r.points DESC,r.rule_id),'[]'::jsonb)
  INTO v_trace
  FROM public.memory_guide_scoring_rules r
  WHERE r.organization_id=v_s.organization_id AND r.scoring_version=v_s.scoring_version
    AND public.lsh_guide_answer_matches(v_s.id,r.field_key,r.match_value);

  -- Hard eligibility and safety/privacy overrides occur before package publication.
  IF v_privacy='full_privacy' THEN v_override_codes:=array_append(v_override_codes,'privacy_locked'); END IF;
  IF v_privacy='decide_later' THEN v_override_codes:=array_append(v_override_codes,'privacy_pending'); END IF;
  IF public.lsh_guide_answer_matches(v_s.id,'privacy_note','true') THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'privacy_discussion');
  END IF;
  IF public.lsh_guide_answer_matches(v_s.id,'comfort_needs','private_discussion') THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'private_comfort_discussion');
  END IF;
  IF public.lsh_guide_answer_matches(v_s.id,'comfort_needs','mobility') THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'mobility_review');
  END IF;
  v_safety:=NULLIF(btrim(COALESCE(public.lsh_guide_answer_text(v_s.id,'safety_note'),'')),'');
  IF v_safety IS NOT NULL THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'safety_review');
  END IF;
  IF public.lsh_guide_answer_matches(v_s.id,'participant_count','8_plus') THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'large_group');
  END IF;
  IF public.lsh_guide_answer_matches(v_s.id,'location_preference','home') THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'home_location_review');
  END IF;
  IF public.lsh_guide_answer_matches(v_s.id,'location_preference','custom_review') THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'custom_location_review');
  END IF;

  IF v_service='sitter' AND public.lsh_guide_answer_matches(v_s.id,'sitter_readiness','not_yet') THEN
    v_future:='Sitter milestone — revisit when your baby can sit independently and safely.';
    v_override_codes:=array_append(v_override_codes,'future_milestone');
    -- Sitter readiness alone does not require review, but never erase a review
    -- already triggered by privacy, safety, comfort, location, or group size.
    v_next_actions:='["save_for_later","human_review","whatsapp"]'::jsonb;
  ELSIF v_service='sitter' AND (
      public.lsh_guide_answer_matches(v_s.id,'sitter_readiness','not_sure')
      OR public.lsh_guide_answer_matches(v_s.id,'sitter_readiness','almost')
    ) THEN
    v_review_required:=true; v_review_codes:=array_append(v_review_codes,'sitter_readiness_uncertain');
  END IF;

  IF v_future IS NULL AND v_service IN ('maternity','newborn','sitter') THEN
    SELECT p.* INTO v_primary
    FROM public.memory_guide_packages p
    WHERE p.organization_id=v_s.organization_id AND p.catalogue_version=v_s.package_catalogue_version
      AND p.service_category=v_service AND p.active
    ORDER BY CASE p.tier WHEN 'bronze' THEN v_bronze WHEN 'gold' THEN v_gold WHEN 'diamond' THEN v_diamond ELSE v_emerald END DESC,
      CASE p.tier WHEN 'bronze' THEN 1 WHEN 'gold' THEN 2 WHEN 'diamond' THEN 3 ELSE 4 END ASC
    LIMIT 1;

    SELECT p.* INTO v_alternative
    FROM public.memory_guide_packages p
    WHERE p.organization_id=v_s.organization_id AND p.catalogue_version=v_s.package_catalogue_version
      AND p.service_category=v_service AND p.active
    ORDER BY CASE p.tier WHEN 'bronze' THEN v_bronze WHEN 'gold' THEN v_gold WHEN 'diamond' THEN v_diamond ELSE v_emerald END DESC,
      CASE p.tier WHEN 'bronze' THEN 1 WHEN 'gold' THEN 2 WHEN 'diamond' THEN 3 ELSE 4 END ASC
    OFFSET 1 LIMIT 1;

    IF v_primary.package_key IS NULL THEN
      v_review_required:=true; v_review_codes:=array_append(v_review_codes,'catalogue_conflict');
      v_override_codes:=array_append(v_override_codes,'catalogue_error');
      v_next_actions:='["human_review","whatsapp"]'::jsonb;
    ELSE
      v_top_score:=CASE v_primary.tier WHEN 'bronze' THEN v_bronze WHEN 'gold' THEN v_gold WHEN 'diamond' THEN v_diamond ELSE v_emerald END;
      v_alt_score:=CASE v_alternative.tier WHEN 'bronze' THEN v_bronze WHEN 'gold' THEN v_gold WHEN 'diamond' THEN v_diamond WHEN 'emerald' THEN v_emerald ELSE 0 END;
      v_margin:=v_top_score-v_alt_score;
      IF v_margin<=v_cfg.review_margin THEN
        v_review_required:=true; v_review_codes:=array_append(v_review_codes,'low_confidence');
      END IF;
    END IF;
  ELSIF v_future IS NULL THEN
    -- No approved package catalogue exists for these categories. Never invent one.
    v_review_required:=true;
    v_review_codes:=array_append(v_review_codes,'custom_combination');
    v_override_codes:=array_append(v_override_codes,'no_approved_service_catalogue');
    v_next_actions:='["human_review","whatsapp","book_consultation"]'::jsonb;
  END IF;

  IF v_review_required THEN
    v_confidence:='review_required';
  ELSIF v_primary.package_key IS NOT NULL AND v_margin>=v_cfg.high_confidence_margin THEN
    v_confidence:='high';
  ELSE
    v_confidence:='medium';
  END IF;

  IF v_primary.package_key IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(x.rationale),'[]'::jsonb) INTO v_reasons
    FROM (
      SELECT r.rationale,r.points,r.rule_id
      FROM public.memory_guide_scoring_rules r
      WHERE r.organization_id=v_s.organization_id AND r.scoring_version=v_s.scoring_version
        AND r.package_tier=v_primary.tier AND r.classification<>'Sensitive'
        AND public.lsh_guide_answer_matches(v_s.id,r.field_key,r.match_value)
      ORDER BY r.points DESC,r.rule_id LIMIT 4
    ) x;
  END IF;

  SELECT COALESCE(jsonb_agg(DISTINCT x.field_key),'[]'::jsonb) INTO v_assumptions
  FROM (
    SELECT field_key FROM public.memory_guide_answers
    WHERE session_id=v_s.id AND (
      (jsonb_typeof(answer_value)='string' AND trim(both '"' from answer_value::text) IN ('not_sure','guide_me','undecided','prefer_guidance','skip'))
      OR (jsonb_typeof(answer_value)='array' AND (answer_value ? 'not_sure' OR answer_value ? 'undecided'))
    )
    UNION ALL
    SELECT field_key FROM public.memory_guide_sensitive_answers
    WHERE session_id=v_s.id AND jsonb_typeof(answer_value)='string'
      AND trim(both '"' from answer_value::text) IN ('not_sure','prefer_guidance','skip')
  ) x;

  IF v_future IS NOT NULL THEN
    v_explanation:='This milestone is still ahead. We will not force a sitter-package recommendation before readiness is clear. You can save this guide or ask our team for gentle guidance.';
  ELSIF v_primary.package_key IS NULL THEN
    v_explanation:='Your combination deserves a person, not an invented package. Our team can review what you selected and guide the next step without pressure.';
  ELSIF v_review_required THEN
    v_explanation:='Based on your structured choices, '||v_primary.public_name||' is a close fit, but a team review is needed before we present it as final.';
  ELSE
    v_explanation:='Based on what you shared, '||v_primary.public_name||' may fit the depth, variety and keepsakes you selected. We can also compare the nearby alternative with you.';
  END IF;

  INSERT INTO public.memory_guide_decisions(
    organization_id,session_id,decision_input_version,guide_schema_version,scoring_version,package_catalogue_version,
    service_category,primary_package_snapshot,alternative_package_snapshot,score_snapshot,reason_codes,explanation_text,
    confidence,assumptions,privacy_note,review_required,review_codes,future_milestone,decision_trace,next_actions
  ) VALUES(
    v_s.organization_id,v_s.id,v_s.session_version,v_s.guide_schema_version,v_s.scoring_version,v_s.package_catalogue_version,
    v_service,
    CASE WHEN v_primary.package_key IS NULL THEN NULL ELSE jsonb_build_object(
      'package_key',v_primary.package_key,'tier',v_primary.tier,'public_name',v_primary.public_name,
      'list_price_inr',v_primary.list_price_inr,'source_offer_price_inr',v_primary.source_offer_price_inr,
      'public_offer_enabled',v_primary.public_offer_enabled,'summary',v_primary.summary,'inclusions',v_primary.inclusions
    ) END,
    CASE WHEN v_alternative.package_key IS NULL THEN NULL ELSE jsonb_build_object(
      'package_key',v_alternative.package_key,'tier',v_alternative.tier,'public_name',v_alternative.public_name,
      'list_price_inr',v_alternative.list_price_inr,'source_offer_price_inr',v_alternative.source_offer_price_inr,
      'public_offer_enabled',v_alternative.public_offer_enabled,'summary',v_alternative.summary,'inclusions',v_alternative.inclusions
    ) END,
    jsonb_build_object('bronze',v_bronze,'gold',v_gold,'diamond',v_diamond,'emerald',v_emerald,'margin',v_margin),
    v_reasons,v_explanation,v_confidence,v_assumptions,v_privacy_note,v_review_required,to_jsonb(v_review_codes),v_future,
    jsonb_build_object(
      'matched_rules',v_trace,'override_codes',to_jsonb(v_override_codes),
      'tie_policy','equal scores select the lower tier deterministically and require review',
      'threshold_status',v_cfg.scoring_approval_status,
      'retention_status',v_cfg.retention_approval_status
    ),v_next_actions
  ) RETURNING * INTO v_decision;

  IF 'low_confidence'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Low Confidence','low_confidence','open',240);
  END IF;
  IF 'privacy_discussion'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Privacy Discussion','privacy_discussion','restricted',240);
  END IF;
  IF 'private_comfort_discussion'=ANY(v_review_codes) OR 'mobility_review'=ANY(v_review_codes) OR 'safety_review'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Safety or Comfort','restricted_operational_need','restricted',240);
  END IF;
  IF 'large_group'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Large Group','eight_plus','open',480);
  END IF;
  IF 'home_location_review'=ANY(v_review_codes) OR 'custom_location_review'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Home or Custom Location','location_review','open',480);
  END IF;
  IF 'sitter_readiness_uncertain'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Sitter Readiness Uncertain','sitter_readiness_uncertain','open',480);
  END IF;
  IF 'custom_combination'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Custom Combination','no_approved_service_catalogue','open',480);
  END IF;
  IF 'catalogue_conflict'=ANY(v_review_codes) THEN
    PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Catalogue Conflict','catalogue_conflict','blocked',1);
  END IF;

  UPDATE public.memory_guide_sessions SET
    status=CASE WHEN v_review_required THEN 'review_required' ELSE 'completed' END,
    current_stage='STG-16',progress_percent=100,completed_at=now(),last_saved_at=now()
  WHERE id=v_s.id;

  PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'decision.published',v_s.session_version,
    jsonb_build_object('confidence',v_confidence,'review_required',v_review_required,'has_primary',v_primary.package_key IS NOT NULL));
  PERFORM public.lsh_guide_record_event(v_s.organization_id,v_s.id,'guide_recommendation_generated',
    jsonb_build_object('confidence',v_confidence,'review_required',v_review_required,'has_primary',v_primary.package_key IS NOT NULL));

  RETURN public.lsh_guide_public_decision(v_decision.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_memory_guide_next_action(
  p_access_token text,
  p_next_action text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_s public.memory_guide_sessions%ROWTYPE;
BEGIN
  IF p_next_action NOT IN ('book_consultation','request_quote','whatsapp','save_for_later','human_review') THEN RAISE EXCEPTION 'Invalid next action'; END IF;
  SELECT * INTO v_s FROM public.memory_guide_sessions s
  WHERE s.anonymous_token_hash=public.lsh_guide_hash_token(p_access_token)
  FOR UPDATE;
  IF NOT FOUND OR v_s.status='deleted' OR v_s.expires_at<=now() THEN RAISE EXCEPTION 'Memory Guide session is unavailable'; END IF;
  IF NOT public.lsh_guide_organization_active(v_s.organization_id) THEN
    RAISE EXCEPTION 'Memory Guide is unavailable';
  END IF;

  UPDATE public.memory_guide_sessions SET next_action=p_next_action,last_saved_at=now() WHERE id=v_s.id;
  PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'next_action.selected',v_s.session_version,jsonb_build_object('next_action',p_next_action));
  PERFORM public.lsh_guide_record_event(v_s.organization_id,v_s.id,'guide_handoff_selected',jsonb_build_object('next_action',p_next_action));
  RETURN true;
END;
$$;

-- ---------------------------------------------------------------------
-- Staff-side review and CRM synchronization
-- ---------------------------------------------------------------------
ALTER TABLE public.memory_guide_session_events ADD COLUMN actor_member_id uuid NULL;
ALTER TABLE public.memory_guide_session_events ADD CONSTRAINT memory_guide_session_events_actor_fk
  FOREIGN KEY (actor_member_id,organization_id)
  REFERENCES public.organization_members(id,organization_id) ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION public.lsh_guide_session_event(
  p_organization_id uuid,p_session_id uuid,p_event_type text,p_session_version integer,p_safe_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_actor uuid;
BEGIN
  IF auth.uid() IS NOT NULL THEN v_actor:=public.current_organization_member(p_organization_id); END IF;
  INSERT INTO public.memory_guide_session_events(
    organization_id,session_id,event_type,session_version,safe_metadata,actor_member_id
  ) VALUES(
    p_organization_id,p_session_id,lower(btrim(p_event_type)),p_session_version,COALESCE(p_safe_metadata,'{}'::jsonb),v_actor
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.lsh_guide_immutable_event_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'Memory Guide session events are append-only' USING ERRCODE='42501';
END;
$$;
CREATE TRIGGER memory_guide_session_events_immutable
BEFORE UPDATE OR DELETE ON public.memory_guide_session_events
FOR EACH ROW EXECUTE FUNCTION public.lsh_guide_immutable_event_guard();

CREATE OR REPLACE FUNCTION public.list_memory_guide_review_center(p_organization_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_actor uuid; v_rows jsonb;
BEGIN
  v_actor:=public.current_organization_member(p_organization_id);
  IF v_actor IS NULL OR NOT public.has_permission(p_organization_id,'lead.read',NULL::uuid) THEN
    RAISE EXCEPTION 'lead.read permission required' USING ERRCODE='42501';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'review_id',r.id,'session_id',s.id,'session_reference',s.session_reference,'session_status',s.status,
    'review_type',r.review_type,'trigger_code',r.trigger_code,'visibility',r.visibility,'review_status',r.status,
    'owner_member_id',r.owner_member_id,'due_at',r.due_at,'created_at',r.created_at,
    'service_category',public.lsh_guide_answer_text(s.id,'service_category'),
    'confidence',d.confidence,
    'primary_package',CASE WHEN d.primary_package_snapshot IS NULL THEN NULL ELSE d.primary_package_snapshot - 'source_offer_price_inr' END,
    'contact',CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object(
      'name',c.contact_name,'phone',c.contact_phone,'email',c.contact_email,'preferred_contact',c.preferred_contact,'permission',c.contact_permission
    ) END,
    'lead_id',s.lead_id,
    'crm_status',o.status,
    'next_action',s.next_action
  ) ORDER BY CASE r.status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 ELSE 2 END,r.due_at,r.created_at),'[]'::jsonb)
  INTO v_rows
  FROM public.memory_guide_review_requests r
  JOIN public.memory_guide_sessions s ON s.id=r.session_id AND s.organization_id=r.organization_id
  LEFT JOIN public.memory_guide_decisions d ON d.id=r.decision_id
  LEFT JOIN public.memory_guide_contacts c ON c.session_id=s.id
  LEFT JOIN public.memory_guide_crm_outbox o ON o.session_id=s.id
  WHERE r.organization_id=p_organization_id;
  RETURN v_rows;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_memory_guide_sensitive_answers(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_s public.memory_guide_sessions%ROWTYPE; v_actor uuid; v_rows jsonb;
BEGIN
  SELECT * INTO v_s FROM public.memory_guide_sessions WHERE id=p_session_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Memory Guide session not found'; END IF;
  v_actor:=public.current_organization_member(v_s.organization_id);
  IF v_actor IS NULL OR NOT public.has_permission(v_s.organization_id,'audit.sensitive.read',NULL::uuid) THEN
    RAISE EXCEPTION 'audit.sensitive.read permission required' USING ERRCODE='42501';
  END IF;

  SELECT COALESCE(jsonb_object_agg(field_key,answer_value),'{}'::jsonb) INTO v_rows
  FROM public.memory_guide_sensitive_answers WHERE session_id=v_s.id;
  PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'sensitive_answers.read',v_s.session_version,
    jsonb_build_object('field_count',(SELECT count(*) FROM public.memory_guide_sensitive_answers WHERE session_id=v_s.id)));
  PERFORM public.append_audit_event(
    v_s.organization_id,NULL,'memory_guide.sensitive_answers.read','memory_guide_session',v_s.id,true,
    NULL,NULL,
    jsonb_build_object('field_count',(SELECT count(*) FROM public.memory_guide_sensitive_answers WHERE session_id=v_s.id)),
    'memory_guide',NULL
  );
  RETURN v_rows;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_memory_guide_review(
  p_review_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_r public.memory_guide_review_requests%ROWTYPE; v_actor uuid; v_old_status text;
BEGIN
  SELECT * INTO v_r FROM public.memory_guide_review_requests WHERE id=p_review_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Review not found'; END IF;
  v_old_status:=v_r.status;
  v_actor:=public.current_organization_member(v_r.organization_id);
  IF v_actor IS NULL OR NOT public.has_permission(v_r.organization_id,'lead.write',NULL::uuid) THEN
    RAISE EXCEPTION 'lead.write permission required' USING ERRCODE='42501';
  END IF;
  IF p_status NOT IN ('open','in_progress','resolved','dismissed') THEN RAISE EXCEPTION 'Invalid review status'; END IF;

  UPDATE public.memory_guide_review_requests SET
    status=p_status,
    resolved_at=CASE WHEN p_status IN ('resolved','dismissed') THEN now() ELSE NULL END,
    resolved_by=CASE WHEN p_status IN ('resolved','dismissed') THEN v_actor ELSE NULL END
  WHERE id=p_review_id RETURNING * INTO v_r;
  PERFORM public.lsh_guide_session_event(v_r.organization_id,v_r.session_id,'review.status_changed',
    (SELECT session_version FROM public.memory_guide_sessions WHERE id=v_r.session_id),jsonb_build_object('review_status',p_status,'review_type',v_r.review_type));
  PERFORM public.append_audit_event(
    v_r.organization_id,NULL,'memory_guide.review.status_changed','memory_guide_review',v_r.id,
    v_r.visibility='restricted',jsonb_build_object('status',v_old_status),jsonb_build_object('status',p_status),
    jsonb_build_object('session_id',v_r.session_id,'review_type',v_r.review_type),'memory_guide',NULL
  );
  RETURN jsonb_build_object('review_id',v_r.id,'status',v_r.status);
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_memory_guide_to_crm(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_s public.memory_guide_sessions%ROWTYPE;
  v_contact public.memory_guide_contacts%ROWTYPE;
  v_decision public.memory_guide_decisions%ROWTYPE;
  v_outbox public.memory_guide_crm_outbox%ROWTYPE;
  v_actor uuid;
  v_lead public.leads%ROWTYPE;
  v_match_count integer:=0;
  v_match_id uuid;
  v_match_status public.lead_status;
  v_service text;
  v_privacy text;
  v_location text;
  v_goals jsonb:='[]'::jsonb;
  v_participants jsonb:='[]'::jsonb;
  v_goal_text text;
  v_review public.memory_guide_review_requests%ROWTYPE;
  v_action_text text;
  v_due timestamptz;
  v_err text;
  v_next_attempt timestamptz;
BEGIN
  SELECT * INTO v_s FROM public.memory_guide_sessions WHERE id=p_session_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Memory Guide session not found'; END IF;
  v_actor:=public.current_organization_member(v_s.organization_id);
  IF v_actor IS NULL OR NOT public.has_permission(v_s.organization_id,'lead.write',NULL::uuid) THEN
    RAISE EXCEPTION 'lead.write permission required' USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_outbox FROM public.memory_guide_crm_outbox WHERE session_id=v_s.id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','not_queued','lead_id',v_s.lead_id); END IF;
  IF v_outbox.status='synced' AND v_outbox.lead_id IS NOT NULL THEN
    RETURN jsonb_build_object('status','synced','lead_id',v_outbox.lead_id,'idempotent',true);
  END IF;

  SELECT * INTO v_contact FROM public.memory_guide_contacts WHERE session_id=v_s.id;
  IF NOT FOUND OR NOT v_contact.contact_permission THEN
    UPDATE public.memory_guide_crm_outbox SET status='manual_action_required',last_error_code='contact_permission_required' WHERE id=v_outbox.id;
    RETURN jsonb_build_object('status','manual_action_required','reason','contact_permission_required');
  END IF;

  SELECT * INTO v_decision FROM public.memory_guide_decisions WHERE session_id=v_s.id ORDER BY decision_input_version DESC LIMIT 1;
  IF NOT FOUND THEN
    UPDATE public.memory_guide_crm_outbox SET status='manual_action_required',last_error_code='decision_required' WHERE id=v_outbox.id;
    RETURN jsonb_build_object('status','manual_action_required','reason','decision_required');
  END IF;

  UPDATE public.memory_guide_crm_outbox SET status='processing',attempt_count=attempt_count+1,last_attempt_at=now(),last_error_code=NULL WHERE id=v_outbox.id
  RETURNING * INTO v_outbox;

  BEGIN
    SELECT public.lsh_guide_answer_text(v_s.id,'service_category'),public.lsh_guide_answer_text(v_s.id,'privacy_choice'),
      public.lsh_guide_answer_text(v_s.id,'location_preference')
      INTO v_service,v_privacy,v_location;
    SELECT answer_value INTO v_goals FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key='emotional_goal';
    SELECT answer_value INTO v_participants FROM public.memory_guide_answers WHERE session_id=v_s.id AND field_key='participants';
    SELECT string_agg(x,', ' ORDER BY x) INTO v_goal_text FROM jsonb_array_elements_text(COALESCE(v_goals,'[]'::jsonb)) x;

    SELECT count(*) INTO v_match_count
    FROM public.leads l
    WHERE l.organization_id=v_s.organization_id
      AND ((l.phone IS NOT NULL AND l.phone=v_contact.contact_phone)
        OR (v_contact.contact_email IS NOT NULL AND l.email IS NOT NULL AND lower(l.email)=lower(v_contact.contact_email)));

    IF v_match_count>1 THEN
      PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Duplicate Contact','multiple_lead_matches','open',240);
      UPDATE public.memory_guide_crm_outbox SET status='manual_action_required',last_error_code='duplicate_contact' WHERE id=v_outbox.id;
      RETURN jsonb_build_object('status','manual_action_required','reason','duplicate_contact');
    ELSIF v_match_count=1 THEN
      SELECT l.id,l.status INTO v_match_id,v_match_status
      FROM public.leads l
      WHERE l.organization_id=v_s.organization_id
        AND ((l.phone IS NOT NULL AND l.phone=v_contact.contact_phone)
          OR (v_contact.contact_email IS NOT NULL AND l.email IS NOT NULL AND lower(l.email)=lower(v_contact.contact_email)))
      ORDER BY l.id
      LIMIT 1;
      IF v_match_status IN ('converted'::public.lead_status,'archived'::public.lead_status) THEN
        PERFORM public.lsh_guide_create_review(v_s,v_decision.id,'Duplicate Contact','terminal_lead_match','open',240);
        UPDATE public.memory_guide_crm_outbox SET status='manual_action_required',last_error_code='terminal_lead_match' WHERE id=v_outbox.id;
        RETURN jsonb_build_object('status','manual_action_required','reason','terminal_lead_match');
      END IF;
      SELECT * INTO v_lead FROM public.leads WHERE id=v_match_id;
    ELSE
      SELECT * INTO v_lead FROM public.create_lead(
        p_organization_id=>v_s.organization_id,
        p_parent_name=>v_contact.contact_name,
        p_source=>'memory_guide',
        p_phone=>v_contact.contact_phone,
        p_email=>v_contact.contact_email,
        p_city=>NULL,
        p_session_type=>v_service,
        p_baby_age_or_pregnancy=>NULL,
        p_preferred_date=>NULL,
        p_location_preference=>v_location,
        p_package_interest=>CASE WHEN v_decision.primary_package_snapshot IS NULL THEN NULL ELSE v_decision.primary_package_snapshot->>'public_name' END,
        p_budget_comfort=>NULL,
        p_memory_goal=>NULLIF(v_goal_text,''),
        p_privacy_preference=>v_privacy::public.privacy_preference_type,
        p_follow_up_at=>NULL,
        p_branch_id=>NULL,
        p_assigned_owner_member_id=>NULL
      );
    END IF;

    UPDATE public.memory_guide_sessions SET
      lead_id=v_lead.id,
      expires_at=GREATEST(expires_at,now()+make_interval(days=>(SELECT linked_session_ttl_days FROM public.memory_guide_config WHERE organization_id=v_s.organization_id)))
    WHERE id=v_s.id;
    UPDATE public.memory_guide_review_requests SET lead_id=v_lead.id WHERE session_id=v_s.id;

    INSERT INTO public.memory_guide_lead_summaries(
      organization_id,session_id,lead_id,session_reference,service_category,emotional_goals,participants_summary,
      privacy_choice,safety_review_required,primary_package,alternative_package,reason_codes,confidence,review_required,
      future_milestone,source_page,preferred_contact,next_action,decision_versions
    ) VALUES(
      v_s.organization_id,v_s.id,v_lead.id,v_s.session_reference,v_service,COALESCE(v_goals,'[]'::jsonb),COALESCE(v_participants,'[]'::jsonb),
      v_privacy::public.privacy_preference_type,
      EXISTS(SELECT 1 FROM public.memory_guide_review_requests WHERE session_id=v_s.id AND review_type='Safety or Comfort'),
      v_decision.primary_package_snapshot - 'source_offer_price_inr',v_decision.alternative_package_snapshot - 'source_offer_price_inr',
      v_decision.reason_codes,v_decision.confidence,v_decision.review_required,v_decision.future_milestone,v_s.source_page,
      v_contact.preferred_contact,v_s.next_action,
      jsonb_build_object('guide',v_decision.guide_schema_version,'scoring',v_decision.scoring_version,'catalogue',v_decision.package_catalogue_version,'input_version',v_decision.decision_input_version)
    ) ON CONFLICT(session_id) DO UPDATE SET
      lead_id=EXCLUDED.lead_id,service_category=EXCLUDED.service_category,emotional_goals=EXCLUDED.emotional_goals,
      participants_summary=EXCLUDED.participants_summary,privacy_choice=EXCLUDED.privacy_choice,
      safety_review_required=EXCLUDED.safety_review_required,primary_package=EXCLUDED.primary_package,
      alternative_package=EXCLUDED.alternative_package,reason_codes=EXCLUDED.reason_codes,confidence=EXCLUDED.confidence,
      review_required=EXCLUDED.review_required,future_milestone=EXCLUDED.future_milestone,preferred_contact=EXCLUDED.preferred_contact,
      next_action=EXCLUDED.next_action,decision_versions=EXCLUDED.decision_versions,updated_at=now();

    FOR v_review IN SELECT * FROM public.memory_guide_review_requests WHERE session_id=v_s.id AND status IN ('open','in_progress')
    LOOP
      PERFORM public.create_lead_task(
        v_lead.id,'internal_review'::public.lead_task_type,
        CASE v_review.review_type
          WHEN 'Privacy Discussion' THEN 'Memory Guide privacy review'
          WHEN 'Safety or Comfort' THEN 'Memory Guide restricted care review'
          WHEN 'Low Confidence' THEN 'Review Memory Guide recommendation'
          ELSE 'Memory Guide: '||left(v_review.review_type,70) END,
        CASE WHEN v_review.visibility='restricted' THEN 'Restricted Memory Guide review — open the review centre for details.'
          ELSE 'Memory Guide review required before the next client step.' END,
        v_review.owner_member_id,
        CASE WHEN v_review.visibility IN ('restricted','blocked') THEN 'high'::public.lead_task_priority ELSE 'normal'::public.lead_task_priority END,
        v_review.due_at,'memory_guide','memory-guide-review:'||v_review.id::text
      );
    END LOOP;

    IF v_s.next_action IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.lead_next_actions WHERE lead_id=v_lead.id) THEN
      v_action_text:=CASE v_s.next_action
        WHEN 'request_quote' THEN 'Prepare a clear package comparison or quote.'
        WHEN 'book_consultation' THEN 'Arrange a consultation at a comfortable time.'
        WHEN 'whatsapp' THEN 'Reply on the family’s preferred enquiry channel.'
        WHEN 'human_review' THEN 'Review the Memory Guide and respond personally.'
        ELSE 'Follow up gently when the family is ready.' END;
      v_due:=public.lsh_guide_add_business_minutes(v_s.organization_id,now(),480);
      PERFORM public.set_lead_next_action(v_lead.id,v_action_text,v_due,NULL,'memory_guide');
    END IF;

    UPDATE public.memory_guide_crm_outbox SET status='synced',lead_id=v_lead.id,next_attempt_at=NULL,last_error_code=NULL WHERE id=v_outbox.id;
    PERFORM public.lsh_guide_session_event(v_s.organization_id,v_s.id,'crm.synced',v_s.session_version,jsonb_build_object('lead_linked',true));
    PERFORM public.append_audit_event(
      v_s.organization_id,NULL,'memory_guide.crm.synced','memory_guide_session',v_s.id,false,
      NULL,jsonb_build_object('lead_id',v_lead.id),jsonb_build_object('idempotent_existing_lead',v_match_count=1),'memory_guide',NULL
    );
    RETURN jsonb_build_object('status','synced','lead_id',v_lead.id,'idempotent',v_match_count=1);
  EXCEPTION WHEN OTHERS THEN
    v_err:=SQLSTATE;
    v_next_attempt:=now()+make_interval(mins=>LEAST(60,5*GREATEST(v_outbox.attempt_count,1)));
    UPDATE public.memory_guide_crm_outbox SET
      status=CASE WHEN attempt_count>=max_attempts THEN 'dead_letter' ELSE 'retry' END,
      next_attempt_at=CASE WHEN attempt_count>=max_attempts THEN NULL ELSE v_next_attempt END,
      last_error_code=v_err
    WHERE id=v_outbox.id;
    RETURN jsonb_build_object('status',CASE WHEN v_outbox.attempt_count>=v_outbox.max_attempts THEN 'dead_letter' ELSE 'retry' END,'error_code',v_err);
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.cleanup_expired_memory_guide_sessions(p_limit integer DEFAULT 100)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_id uuid; v_count integer:=0;
BEGIN
  FOR v_id IN
    SELECT id FROM public.memory_guide_sessions
    WHERE expires_at<=now() AND status NOT IN ('deleted','expired')
    ORDER BY expires_at LIMIT LEAST(GREATEST(p_limit,1),1000)
    FOR UPDATE SKIP LOCKED
  LOOP
    DELETE FROM public.memory_guide_contacts WHERE session_id=v_id;
    DELETE FROM public.memory_guide_sensitive_answers WHERE session_id=v_id;
    DELETE FROM public.memory_guide_answers WHERE session_id=v_id;
    DELETE FROM public.memory_guide_resume_tokens WHERE session_id=v_id;
    UPDATE public.memory_guide_sessions SET status='expired',anonymous_token_hash=public.lsh_guide_hash_token(public.lsh_guide_new_token()),next_action=NULL WHERE id=v_id;
    v_count:=v_count+1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- ---------------------------------------------------------------------
-- Immutable published decision evidence
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lsh_guide_immutable_decision_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'Memory Guide decisions are immutable' USING ERRCODE='42501';
END;
$$;
CREATE TRIGGER memory_guide_decisions_immutable
BEFORE UPDATE OR DELETE ON public.memory_guide_decisions
FOR EACH ROW EXECUTE FUNCTION public.lsh_guide_immutable_decision_guard();

-- =====================================================================
-- RLS, least privilege, function ACL and baseline hardening
-- =====================================================================
ALTER TABLE public.memory_guide_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_config FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_question_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_question_definitions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_package_catalogues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_package_catalogues FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_packages FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_scoring_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_scoring_rules FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_answers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_sensitive_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_sensitive_answers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_contacts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_resume_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_resume_tokens FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_decisions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_review_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_crm_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_crm_outbox FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_lead_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_lead_summaries FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_analytics_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_session_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_guide_session_events FORCE ROW LEVEL SECURITY;

CREATE POLICY memory_guide_config_staff_read ON public.memory_guide_config
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_catalogues_staff_read ON public.memory_guide_package_catalogues
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_packages_staff_read ON public.memory_guide_packages
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_scoring_staff_read ON public.memory_guide_scoring_rules
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_sessions_staff_read ON public.memory_guide_sessions
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_answers_staff_read ON public.memory_guide_answers
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_contacts_staff_read ON public.memory_guide_contacts
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_decisions_staff_read ON public.memory_guide_decisions
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_reviews_staff_read ON public.memory_guide_review_requests
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_crm_outbox_staff_read ON public.memory_guide_crm_outbox
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_summaries_staff_read ON public.memory_guide_lead_summaries
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
CREATE POLICY memory_guide_events_staff_read ON public.memory_guide_session_events
FOR SELECT TO authenticated USING (public.has_permission(organization_id,'lead.read',NULL::uuid));
-- Question definitions are non-client-secret but remain available only to authenticated staff directly.
CREATE POLICY memory_guide_questions_staff_read ON public.memory_guide_question_definitions
FOR SELECT TO authenticated USING (EXISTS(
  SELECT 1 FROM public.memory_guide_config c
  WHERE c.guide_schema_version=memory_guide_question_definitions.guide_schema_version
    AND public.has_permission(c.organization_id,'lead.read',NULL::uuid)
));
-- Sensitive answers, resume hashes and analytics intentionally have no direct authenticated SELECT policy.

-- Make the pre-existing consultation private-note deny intent explicit so the
-- database security advisor no longer has to infer a policy-less RLS design.
DO $private_note_policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='consultation_private_notes'
      AND policyname='consultation_private_notes_explicit_deny'
  ) THEN
    EXECUTE 'CREATE POLICY consultation_private_notes_explicit_deny ON public.consultation_private_notes FOR ALL TO anon, authenticated USING (false) WITH CHECK (false)';
  END IF;
END
$private_note_policy$;

REVOKE ALL ON TABLE public.memory_guide_config FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_question_definitions FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_package_catalogues FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_packages FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_scoring_rules FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_sessions FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_answers FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_sensitive_answers FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_contacts FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_resume_tokens FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_decisions FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_review_requests FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_crm_outbox FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_lead_summaries FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_analytics_events FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.memory_guide_session_events FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE public.memory_guide_config TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_question_definitions TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_package_catalogues TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_packages TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_scoring_rules TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_sessions TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_answers TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_contacts TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_decisions TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_review_requests TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_crm_outbox TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_lead_summaries TO authenticated;
GRANT SELECT ON TABLE public.memory_guide_session_events TO authenticated;

GRANT ALL ON TABLE
  public.memory_guide_config,public.memory_guide_question_definitions,public.memory_guide_package_catalogues,
  public.memory_guide_packages,public.memory_guide_scoring_rules,public.memory_guide_sessions,public.memory_guide_answers,
  public.memory_guide_sensitive_answers,public.memory_guide_contacts,public.memory_guide_resume_tokens,
  public.memory_guide_decisions,public.memory_guide_review_requests,public.memory_guide_crm_outbox,
  public.memory_guide_lead_summaries,public.memory_guide_analytics_events,public.memory_guide_session_events
TO service_role;

-- Event-trigger helper is a production hardening target, not a Sprint 7 dependency.
-- Some clean local baselines do not contain it, so harden it only when present.
DO $rls_helper_acl$
DECLARE
  v_fn regprocedure;
BEGIN
  v_fn := to_regprocedure('public.rls_auto_enable()');
  IF v_fn IS NOT NULL THEN
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon,authenticated', v_fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', v_fn);
  END IF;
END
$rls_helper_acl$;

DO $guide_function_acl$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN (
      'lsh_guide_hash_token','lsh_guide_new_token','lsh_guide_assert_safe_analytics','lsh_guide_record_event',
      'lsh_guide_progress','lsh_guide_answer_matches','lsh_guide_answer_text','lsh_guide_add_business_minutes',
      'lsh_guide_review_owner','lsh_guide_session_event','lsh_guide_public_decision','lsh_guide_create_review',
      'lsh_guide_immutable_event_guard','lsh_guide_immutable_decision_guard','start_memory_guide','get_memory_guide_state','save_memory_guide_answers',
      'save_memory_guide_contact','create_memory_guide_resume','resume_memory_guide_session','process_memory_guide_decision',
      'record_memory_guide_next_action','list_memory_guide_review_center','get_memory_guide_sensitive_answers',
      'update_memory_guide_review','sync_memory_guide_to_crm','cleanup_expired_memory_guide_sessions'
    )
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
  END LOOP;
END
$guide_function_acl$;

-- Public browser flow can only use opaque-token RPCs; it never receives table privileges.
GRANT EXECUTE ON FUNCTION public.start_memory_guide(uuid,text,text,text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_memory_guide_state(text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_memory_guide_answers(text,integer,text,jsonb) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_memory_guide_contact(text,text,text,text,boolean,text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.create_memory_guide_resume(text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.resume_memory_guide_session(text) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.process_memory_guide_decision(text,integer) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_memory_guide_next_action(text,text) TO anon,authenticated;

-- Staff operations stay behind canonical lead/audit permissions inside the RPCs.
GRANT EXECUTE ON FUNCTION public.list_memory_guide_review_center(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_memory_guide_sensitive_answers(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_memory_guide_review(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_memory_guide_to_crm(uuid) TO authenticated;
-- cleanup_expired_memory_guide_sessions is service_role only until retention is approved/scheduled.

-- Review centre also surfaces contact-permission CRM handoffs that do not
-- otherwise need a human recommendation review.
CREATE OR REPLACE FUNCTION public.list_memory_guide_review_center(p_organization_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_actor uuid; v_rows jsonb;
BEGIN
  v_actor:=public.current_organization_member(p_organization_id);
  IF v_actor IS NULL OR NOT public.has_permission(p_organization_id,'lead.read',NULL::uuid) THEN
    RAISE EXCEPTION 'lead.read permission required' USING ERRCODE='42501';
  END IF;

  WITH items AS (
    SELECT jsonb_build_object(
      'review_id',r.id,'session_id',s.id,'session_reference',s.session_reference,'session_status',s.status,
      'review_type',r.review_type,'trigger_code',r.trigger_code,'visibility',r.visibility,'review_status',r.status,
      'owner_member_id',r.owner_member_id,'due_at',r.due_at,'created_at',r.created_at,
      'service_category',public.lsh_guide_answer_text(s.id,'service_category'),'confidence',d.confidence,
      'primary_package',CASE WHEN d.primary_package_snapshot IS NULL THEN NULL ELSE d.primary_package_snapshot - 'source_offer_price_inr' END,
      'contact',CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object('name',c.contact_name,'phone',c.contact_phone,'email',c.contact_email,'preferred_contact',c.preferred_contact,'permission',c.contact_permission) END,
      'lead_id',s.lead_id,'crm_status',o.status,'next_action',s.next_action
    ) AS item,r.due_at AS sort_due,r.created_at AS sort_created
    FROM public.memory_guide_review_requests r
    JOIN public.memory_guide_sessions s ON s.id=r.session_id AND s.organization_id=r.organization_id
    LEFT JOIN public.memory_guide_decisions d ON d.id=r.decision_id
    LEFT JOIN public.memory_guide_contacts c ON c.session_id=s.id
    LEFT JOIN public.memory_guide_crm_outbox o ON o.session_id=s.id
    WHERE r.organization_id=p_organization_id

    UNION ALL

    SELECT jsonb_build_object(
      'review_id',NULL,'session_id',s.id,'session_reference',s.session_reference,'session_status',s.status,
      'review_type','CRM Handoff','trigger_code','contact_permission','visibility','open','review_status','open',
      'owner_member_id',public.lsh_guide_review_owner(s.organization_id,false),
      'due_at',public.lsh_guide_add_business_minutes(s.organization_id,o.created_at,240),'created_at',o.created_at,
      'service_category',public.lsh_guide_answer_text(s.id,'service_category'),'confidence',d.confidence,
      'primary_package',CASE WHEN d.primary_package_snapshot IS NULL THEN NULL ELSE d.primary_package_snapshot - 'source_offer_price_inr' END,
      'contact',jsonb_build_object('name',c.contact_name,'phone',c.contact_phone,'email',c.contact_email,'preferred_contact',c.preferred_contact,'permission',c.contact_permission),
      'lead_id',s.lead_id,'crm_status',o.status,'next_action',s.next_action
    ) AS item,public.lsh_guide_add_business_minutes(s.organization_id,o.created_at,240) AS sort_due,o.created_at AS sort_created
    FROM public.memory_guide_crm_outbox o
    JOIN public.memory_guide_sessions s ON s.id=o.session_id AND s.organization_id=o.organization_id
    JOIN public.memory_guide_contacts c ON c.session_id=s.id AND c.contact_permission
    LEFT JOIN public.memory_guide_decisions d ON d.session_id=s.id
      AND d.decision_input_version=(SELECT max(d2.decision_input_version) FROM public.memory_guide_decisions d2 WHERE d2.session_id=s.id)
    WHERE o.organization_id=p_organization_id AND o.status<>'synced'
      AND NOT EXISTS (SELECT 1 FROM public.memory_guide_review_requests r WHERE r.session_id=s.id)
  )
  SELECT COALESCE(jsonb_agg(item ORDER BY sort_due,sort_created),'[]'::jsonb) INTO v_rows FROM items;
  RETURN v_rows;
END;
$$;

-- ---------------------------------------------------------------------
-- Final structural gates
-- ---------------------------------------------------------------------
DO $final_gate$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.memory_guide_question_definitions WHERE guide_schema_version='v1';
  IF v_count<>30 THEN RAISE EXCEPTION 'Sprint 7 gate failed: expected 30 questions, found %',v_count; END IF;
  SELECT count(*) INTO v_count FROM public.memory_guide_scoring_rules
    WHERE organization_id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc' AND scoring_version='v1';
  IF v_count<>32 THEN RAISE EXCEPTION 'Sprint 7 gate failed: expected 32 scoring rules, found %',v_count; END IF;
  SELECT count(*) INTO v_count FROM public.memory_guide_packages
    WHERE organization_id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc' AND catalogue_version='2026-06-client-pdfs' AND active;
  IF v_count<>12 THEN RAISE EXCEPTION 'Sprint 7 gate failed: expected 12 active sourced packages, found %',v_count; END IF;
  IF has_table_privilege('anon','public.memory_guide_sensitive_answers','SELECT')
     OR has_table_privilege('authenticated','public.memory_guide_sensitive_answers','SELECT') THEN
    RAISE EXCEPTION 'Sprint 7 gate failed: sensitive answer table has direct app SELECT privilege';
  END IF;
  IF to_regprocedure('public.rls_auto_enable()') IS NOT NULL THEN
    IF has_function_privilege('anon',to_regprocedure('public.rls_auto_enable()'),'EXECUTE')
       OR has_function_privilege('authenticated',to_regprocedure('public.rls_auto_enable()'),'EXECUTE') THEN
      RAISE EXCEPTION 'Sprint 7 gate failed: rls_auto_enable remains app-executable';
    END IF;
  END IF;
END
$final_gate$;

COMMIT;
