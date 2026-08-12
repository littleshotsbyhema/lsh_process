BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;

SELECT plan(38);


-- Test-only review owner fixture. Rolled back with this pgTAP transaction.
-- Human-review routing intentionally fails closed when no eligible owner exists;
-- clean local resets have no auth member, so the test must provision one.
INSERT INTO auth.users (id)
VALUES ('70000000-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '70000000-0000-0000-0000-000000000002'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '70000000-0000-0000-0000-000000000001'::uuid,
  'active'::public.member_status,
  'Sprint 7 pgTAP Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '70000000-0000-0000-0000-000000000002'::uuid,
  r.id
FROM public.roles r
WHERE r.key = 'founder';

SELECT ok(to_regclass('public.memory_guide_sessions') IS NOT NULL, 'memory_guide_sessions exists');
SELECT ok(to_regclass('public.memory_guide_sensitive_answers') IS NOT NULL, 'restricted answer table exists');
SELECT is((SELECT count(*)::bigint FROM public.memory_guide_question_definitions WHERE guide_schema_version='v1'),30::bigint,'v1 has exactly 30 questions');
SELECT is((SELECT count(*)::bigint FROM public.memory_guide_scoring_rules WHERE organization_id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc' AND scoring_version='v1'),32::bigint,'v1 has exactly 32 scoring rules');
SELECT is((SELECT count(*)::bigint FROM public.memory_guide_packages WHERE organization_id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc' AND active),12::bigint,'only the 12 sourced Maternity/Newborn/Sitter packages are active');
SELECT ok(NOT has_table_privilege('anon','public.memory_guide_sessions','SELECT'),'anon cannot select sessions directly');
SELECT ok(NOT has_table_privilege('anon','public.memory_guide_sensitive_answers','SELECT'),'anon cannot select restricted answers directly');
SELECT ok(NOT has_table_privilege('authenticated','public.memory_guide_sensitive_answers','SELECT'),'authenticated cannot select restricted answers directly');
SELECT ok(CASE WHEN to_regprocedure('public.rls_auto_enable()') IS NULL THEN true ELSE NOT has_function_privilege('anon',to_regprocedure('public.rls_auto_enable()')::oid,'EXECUTE') END,'anon cannot execute rls_auto_enable when helper exists');
SELECT ok(CASE WHEN to_regprocedure('public.rls_auto_enable()') IS NULL THEN true ELSE NOT has_function_privilege('authenticated',to_regprocedure('public.rls_auto_enable()')::oid,'EXECUTE') END,'authenticated cannot execute rls_auto_enable when helper exists');
SELECT is((SELECT scoring_approval_status FROM public.memory_guide_config WHERE organization_id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'),'approved','scoring thresholds are founder-approved');
SELECT is((SELECT retention_approval_status FROM public.memory_guide_config WHERE organization_id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'),'approved','retention values are founder-approved');

-- Organization lifecycle regression: suspended/deleted businesses must not expose the public guide.
UPDATE public.organizations
SET status='suspended'::public.organization_status
WHERE id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

SELECT throws_ok(
  $$SELECT * FROM public.start_memory_guide('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','/memory-guide',NULL,NULL)$$,
  'P0001',
  'Memory Guide is unavailable',
  'suspended organization cannot start a public Memory Guide session'
);

UPDATE public.organizations
SET status='active'::public.organization_status
WHERE id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE TEMP TABLE s7_org_lifecycle_start AS
SELECT * FROM public.start_memory_guide(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '/memory-guide',
  NULL,
  NULL
);

UPDATE public.organizations
SET status='suspended'::public.organization_status
WHERE id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

SELECT throws_ok(
  $$SELECT public.get_memory_guide_state((SELECT access_token FROM s7_org_lifecycle_start))$$,
  'P0001',
  'Memory Guide is unavailable',
  'suspending an organization blocks an existing anonymous Memory Guide session'
);

UPDATE public.organizations
SET status='active'::public.organization_status
WHERE id='590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE TEMP TABLE s7_maternity_start AS
SELECT * FROM public.start_memory_guide('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','/memory-guide',NULL,NULL);

SELECT ok((SELECT access_token IS NOT NULL AND length(access_token)>=64 FROM s7_maternity_start),'public start returns an opaque access token');
SELECT is((SELECT session_version FROM s7_maternity_start),1,'new session starts at version 1');

CREATE TEMP TABLE s7_maternity_save AS
SELECT * FROM public.save_memory_guide_answers(
  (SELECT access_token FROM s7_maternity_start),1,'STG-14',
  '{
    "service_category":"maternity",
    "maternity_timing":"later",
    "emotional_goal":["connection"],
    "participants":["mother"],
    "experience_depth":"essential",
    "moment_variety":"simple",
    "keepsakes":["digital"],
    "setup_preference":"one_refined_setup",
    "privacy_choice":"full_privacy",
    "location_preference":"studio"
  }'::jsonb
);
SELECT is((SELECT session_version FROM s7_maternity_save),2,'one answer batch increments optimistic version once');

CREATE TEMP TABLE s7_maternity_decision AS
SELECT public.process_memory_guide_decision(
  (SELECT access_token FROM s7_maternity_start),
  (SELECT session_version FROM s7_maternity_save)
) AS decision;

SELECT is((SELECT decision->'primary_package'->>'tier' FROM s7_maternity_decision),'bronze','deterministic focused maternity fixture selects Bronze');
SELECT is((SELECT decision->>'confidence' FROM s7_maternity_decision),'high','clear Bronze fixture is high confidence under draft threshold');
SELECT ok(NOT (SELECT (decision->>'review_required')::boolean FROM s7_maternity_decision),'full privacy does not force recommendation review');
SELECT ok(NOT (SELECT decision->'primary_package' ? 'source_offer_price_inr' FROM s7_maternity_decision),'public decision hides source offer price');
SELECT is(
  (SELECT public.process_memory_guide_decision((SELECT access_token FROM s7_maternity_start),(SELECT session_version FROM s7_maternity_save))->>'id'),
  (SELECT decision->>'id' FROM s7_maternity_decision),
  'reprocessing the same session version is idempotent'
);

CREATE TEMP TABLE s7_sensitive_start AS
SELECT * FROM public.start_memory_guide('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','/memory-guide',NULL,NULL);
SELECT * FROM public.save_memory_guide_answers(
  (SELECT access_token FROM s7_sensitive_start),1,'STG-04',
  '{"story_note":"A private family note","budget_band":"prefer_guidance","safety_note":"Discuss privately"}'::jsonb
);
SELECT is((SELECT count(*)::bigint FROM public.memory_guide_sensitive_answers WHERE session_id=(SELECT session_id FROM s7_sensitive_start)),3::bigint,'restricted/sensitive answers are separated into the restricted table');
SELECT is((SELECT count(*)::bigint FROM public.memory_guide_answers WHERE session_id=(SELECT session_id FROM s7_sensitive_start) AND field_key IN ('story_note','budget_band','safety_note')),0::bigint,'restricted fields do not leak into the standard answer table');

CREATE TEMP TABLE s7_resume_start AS
SELECT * FROM public.start_memory_guide('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','/memory-guide',NULL,NULL);
CREATE TEMP TABLE s7_resume_token AS
SELECT * FROM public.create_memory_guide_resume((SELECT access_token FROM s7_resume_start));
CREATE TEMP TABLE s7_resume_once AS
SELECT * FROM public.resume_memory_guide_session((SELECT resume_token FROM s7_resume_token));
SELECT ok((SELECT ok FROM s7_resume_once),'valid resume token works once');
SELECT ok(NOT (SELECT ok FROM public.resume_memory_guide_session((SELECT resume_token FROM s7_resume_token)) LIMIT 1),'resume token replay is rejected');

SELECT ok(NOT EXISTS(
  SELECT 1 FROM public.memory_guide_analytics_events e,
    LATERAL jsonb_object_keys(e.properties) k
  WHERE k NOT IN ('source_page','service_preselection','stage_id','confidence','review_required','has_primary','next_action')
),'analytics rows contain allowlisted property keys only');

-- Conditional branch changes must remove stale answers that could alter the result.
CREATE TEMP TABLE s7_branch_start AS
SELECT * FROM public.start_memory_guide('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','/memory-guide',NULL,NULL);
CREATE TEMP TABLE s7_branch_save1 AS
SELECT * FROM public.save_memory_guide_answers(
  (SELECT access_token FROM s7_branch_start),1,'STG-08',
  '{"service_category":"maternity","maternity_timing":"later","participants":["siblings"],"participant_count":"8_plus","keepsakes":["album"],"album_interest":"essential","location_preference":"home","travel_area":"Chennai"}'::jsonb
);
CREATE TEMP TABLE s7_branch_save2 AS
SELECT * FROM public.save_memory_guide_answers(
  (SELECT access_token FROM s7_branch_start),(SELECT session_version FROM s7_branch_save1),'STG-08',
  '{"service_category":"newborn","participants":["parents"],"keepsakes":["digital"],"location_preference":"studio"}'::jsonb
);
SELECT ok(NOT EXISTS(SELECT 1 FROM public.memory_guide_answers WHERE session_id=(SELECT session_id FROM s7_branch_start) AND field_key IN ('maternity_timing','participant_count','album_interest')),'changing a parent answer removes stale standard conditional answers');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.memory_guide_sensitive_answers WHERE session_id=(SELECT session_id FROM s7_branch_start) AND field_key='travel_area'),'changing location to studio removes stale restricted travel area');
SELECT is((SELECT public.lsh_guide_answer_text((SELECT session_id FROM s7_branch_start),'service_category')),'newborn','changed service category remains the canonical branch value');

-- Unsupported service categories must never receive invented package pricing.
CREATE TEMP TABLE s7_family_start AS
SELECT * FROM public.start_memory_guide('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','/memory-guide','family',NULL);
CREATE TEMP TABLE s7_family_save AS
SELECT * FROM public.save_memory_guide_answers(
  (SELECT access_token FROM s7_family_start),1,'STG-14',
  '{"emotional_goal":["connection"],"participants":["parents"],"experience_depth":"essential","moment_variety":"simple","keepsakes":["digital"],"setup_preference":"one_refined_setup","privacy_choice":"decide_later","location_preference":"studio"}'::jsonb
);
CREATE TEMP TABLE s7_family_decision AS
SELECT public.process_memory_guide_decision((SELECT access_token FROM s7_family_start),(SELECT session_version FROM s7_family_save)) AS decision;
SELECT is((SELECT decision->'primary_package' FROM s7_family_decision),'null'::jsonb,'unsupported family category has no invented primary package');
SELECT ok((SELECT (decision->>'review_required')::boolean FROM s7_family_decision),'unsupported family category requires human guidance');
SELECT ok((SELECT decision->'review_codes' ? 'custom_combination' FROM s7_family_decision),'unsupported family category records the custom-combination review code');

-- Sitter not-yet suppresses package publication but must not erase an independent safety review.
CREATE TEMP TABLE s7_sitter_start AS
SELECT * FROM public.start_memory_guide('590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc','/memory-guide','sitter',NULL);
CREATE TEMP TABLE s7_sitter_save AS
SELECT * FROM public.save_memory_guide_answers(
  (SELECT access_token FROM s7_sitter_start),1,'STG-14',
  '{"sitter_readiness":"not_yet","emotional_goal":["personality"],"participants":["parents"],"experience_depth":"essential","moment_variety":"simple","keepsakes":["digital"],"setup_preference":"one_refined_setup","privacy_choice":"full_privacy","location_preference":"studio","safety_note":"Discuss privately"}'::jsonb
);
CREATE TEMP TABLE s7_sitter_decision AS
SELECT public.process_memory_guide_decision((SELECT access_token FROM s7_sitter_start),(SELECT session_version FROM s7_sitter_save)) AS decision;
SELECT is((SELECT decision->'primary_package' FROM s7_sitter_decision),'null'::jsonb,'not-yet sitter readiness suppresses package publication');
SELECT ok((SELECT (decision->>'review_required')::boolean FROM s7_sitter_decision),'an independent safety disclosure still requires human review');
SELECT ok(EXISTS(SELECT 1 FROM public.memory_guide_review_requests WHERE session_id=(SELECT session_id FROM s7_sitter_start) AND review_type='Safety or Comfort'),'safety review remains owned even when sitter recommendation is deferred');

UPDATE public.memory_guide_review_requests SET status='resolved',resolved_at=now()
WHERE session_id=(SELECT session_id FROM s7_sitter_start) AND review_type='Safety or Comfort';
CREATE TEMP TABLE s7_sitter_resave AS
SELECT * FROM public.save_memory_guide_answers(
  (SELECT access_token FROM s7_sitter_start),(SELECT session_version FROM s7_sitter_save),'STG-14',
  '{"privacy_choice":"full_privacy"}'::jsonb
);
SELECT public.process_memory_guide_decision((SELECT access_token FROM s7_sitter_start),(SELECT session_version FROM s7_sitter_resave));
SELECT is((SELECT status FROM public.memory_guide_review_requests WHERE session_id=(SELECT session_id FROM s7_sitter_start) AND review_type='Safety or Comfort'),'open','a later decision that still triggers review reopens the owned review instead of reusing a resolved item');

SELECT ok(EXISTS(
  SELECT 1 FROM pg_trigger
  WHERE tgrelid='public.memory_guide_decisions'::regclass AND tgname='memory_guide_decisions_immutable' AND NOT tgisinternal
),'decision evidence has an immutable update/delete guard');

SELECT * FROM finish();
ROLLBACK;
