CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(43);

-- =====================================================================
-- Sprint 11 Slice 4
-- Controlled Stage 11 -> 12 / selection_pending Advancement Gate
--
-- Phase 1:
--   * structural / ACL contract;
--   * canonical actor fixtures;
--   * exact Stage 11 source containment;
--   * completion + Stage 10 -> 11 lineage enforcement;
--   * authorized / unauthorized role behavior;
--   * exact successful mutation;
--   * non-sensitive audit;
--   * no payment prerequisite;
--   * valid Stage 12 replay.
-- =====================================================================

-- =====================================================================
-- Part 1 — Structural / permission / ACL contract
-- =====================================================================

-- A
SELECT ok(
  to_regprocedure(
    'public.mark_booking_selection_pending(uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_get_function_result(procedure.oid)
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_selection_pending(uuid)'::regprocedure
  ) = 'bookings',
  'A: mark_booking_selection_pending(uuid) exists and returns bookings'
);

-- B
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key IN (
      'selection.pending',
      'selection.advance',
      'booking.selection.pending'
    )
  ),
  0::bigint,
  'B: Slice 4 introduces no stage-specific selection permission'
);

-- C
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id = role_permission.permission_id
    WHERE permission.key = 'booking.stage.advance'
  ),
  3::bigint,
  'C: booking.stage.advance remains granted to exactly three roles'
);

-- D
SELECT is(
  (
    SELECT array_agg(role.key ORDER BY role.key)
    FROM public.role_permissions role_permission
    JOIN public.permissions permission
      ON permission.id = role_permission.permission_id
    JOIN public.roles role
      ON role.id = role_permission.role_id
    WHERE permission.key = 'booking.stage.advance'
  ),
  ARRAY[
    'client_coordinator',
    'founder',
    'studio_manager'
  ]::text[],
  'D: booking.stage.advance role identities remain exact'
);

-- E
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_selection_pending(uuid)',
    'EXECUTE'
  ),
  'E: authenticated has EXECUTE'
);

-- F
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault('f', procedure.proowner)
      )
    ) acl
    WHERE procedure.oid =
      'public.mark_booking_selection_pending(uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ),
  'F: PUBLIC has no EXECUTE'
);

-- G
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.mark_booking_selection_pending(uuid)',
    'EXECUTE'
  ),
  'G: anon has no EXECUTE'
);

-- H
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.mark_booking_selection_pending(uuid)',
    'EXECUTE'
  ),
  'H: service_role has no application EXECUTE'
);

-- I
SELECT ok(
  (
    SELECT procedure.prosecdef
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_selection_pending(uuid)'::regprocedure
  ),
  'I: RPC is SECURITY DEFINER'
);

-- J
SELECT is(
  (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_selection_pending(uuid)'::regprocedure
  ),
  ARRAY['search_path=""']::text[],
  'J: RPC has empty search_path'
);

-- =====================================================================
-- Part 2 — Canonical identities and fixture helpers
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8d000000-0000-0000-0000-000000000001'::uuid),
  ('8d000000-0000-0000-0000-000000000002'::uuid),
  ('8d000000-0000-0000-0000-000000000003'::uuid),
  ('8d000000-0000-0000-0000-000000000004'::uuid),
  ('8d000000-0000-0000-0000-000000000005'::uuid),
  ('8d000000-0000-0000-0000-000000000006'::uuid),
  ('8d000000-0000-0000-0000-000000000007'::uuid);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  '8d000000-0000-0000-0000-000000000701',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice4 Branch A',
  's11s4-a',
  'active'
),
(
  '8d000000-0000-0000-0000-000000000702',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S11 Slice4 Branch B',
  's11s4-b',
  'active'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name,
  suspended_at
)
VALUES
(
  '8d000000-0000-0000-0000-000000000101',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8d000000-0000-0000-0000-000000000001',
  'active',
  'S11S4 Founder',
  NULL
),
(
  '8d000000-0000-0000-0000-000000000102',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8d000000-0000-0000-0000-000000000002',
  'active',
  'S11S4 Studio Manager',
  NULL
),
(
  '8d000000-0000-0000-0000-000000000103',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8d000000-0000-0000-0000-000000000003',
  'active',
  'S11S4 Client Coordinator',
  NULL
),
(
  '8d000000-0000-0000-0000-000000000104',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8d000000-0000-0000-0000-000000000004',
  'active',
  'S11S4 Photographer',
  NULL
),
(
  '8d000000-0000-0000-0000-000000000105',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8d000000-0000-0000-0000-000000000005',
  'active',
  'S11S4 Editor',
  NULL
),
(
  '8d000000-0000-0000-0000-000000000106',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8d000000-0000-0000-0000-000000000006',
  'suspended',
  'S11S4 Suspended Founder',
  now()
),
(
  '8d000000-0000-0000-0000-000000000107',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8d000000-0000-0000-0000-000000000007',
  'active',
  'S11S4 Branch Coordinator',
  NULL
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role.id,
  fixture.branch_id
FROM (
  VALUES
    (
      '8d000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8d000000-0000-0000-0000-000000000102'::uuid,
      'studio_manager'::text,
      NULL::uuid
    ),
    (
      '8d000000-0000-0000-0000-000000000103'::uuid,
      'client_coordinator'::text,
      NULL::uuid
    ),
    (
      '8d000000-0000-0000-0000-000000000104'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      '8d000000-0000-0000-0000-000000000105'::uuid,
      'editor'::text,
      NULL::uuid
    ),
    (
      '8d000000-0000-0000-0000-000000000106'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '8d000000-0000-0000-0000-000000000107'::uuid,
      'client_coordinator'::text,
      '8d000000-0000-0000-0000-000000000701'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
JOIN public.roles role
  ON role.key = fixture.role_key;

UPDATE public.organizations
SET status = 'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;

CREATE FUNCTION pg_temp.s11s4_set_actor(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claim.sub',
    COALESCE(p_user_id::text, ''),
    true
  );

  PERFORM set_config(
    'request.jwt.claims',
    CASE
      WHEN p_user_id IS NULL THEN '{}'
      ELSE jsonb_build_object(
        'sub',
        p_user_id,
        'role',
        'authenticated'
      )::text
    END,
    true
  );
END;
$$;

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000001'
);

INSERT INTO public.families (
  id,
  organization_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES (
  '8d000000-0000-0000-0000-000000000201',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'LSH-45678D',
  'S11 Slice4 Family',
  'S11 Slice4 Family',
  'active',
  '8d000000-0000-0000-0000-000000000101',
  '8d000000-0000-0000-0000-000000000101'
);

CREATE FUNCTION pg_temp.s11s4_create_booking(
  p_branch_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote public.quotations;
  v_booking public.bookings;
  v_package_version_id uuid;
BEGIN
  SELECT version.id
  INTO v_package_version_id
  FROM public.commercial_package_versions version
  JOIN public.commercial_packages package
    ON package.organization_id = version.organization_id
   AND package.id = version.package_id
  WHERE package.package_key = 'maternity_gold'
    AND version.version_number = 1;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    '8d000000-0000-0000-0000-000000000201',
    NULL,
    p_branch_id,
    NULL,
    NULL
  );

  PERFORM public.add_quotation_package_line(
    v_quote.id,
    v_package_version_id,
    NULL
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'ready'::public.quotation_status
  );

  PERFORM public.transition_quotation(
    v_quote.id,
    'sent'::public.quotation_status
  );

  SELECT *
  INTO v_booking
  FROM public.accept_quotation(v_quote.id);

  RETURN v_booking.id;
END;
$$;

CREATE FUNCTION pg_temp.s11s4_move_to_stage(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text,
  p_transition_key text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
    AND stage.is_active;

  INSERT INTO public.booking_stage_transitions (
    organization_id,
    booking_id,
    from_stage_id,
    to_stage_id,
    transition_key,
    transitioned_at,
    transitioned_by
  )
  VALUES (
    v_state.organization_id,
    v_state.booking_id,
    v_state.current_stage_id,
    v_target.id,
    COALESCE(
      p_transition_key,
      's11s4_fixture_' || p_stage_key
    ),
    now(),
    '8d000000-0000-0000-0000-000000000101'
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = now(),
    version = state.version + 1,
    updated_at = now(),
    updated_by =
      '8d000000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s4_set_stage_without_transition(
  p_booking_id uuid,
  p_stage_order integer,
  p_stage_key text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_state public.booking_journey_states;
  v_target public.booking_journey_stages;
BEGIN
  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.booking_id = p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_state.organization_id
    AND stage.stage_order = p_stage_order
    AND stage.stage_key = p_stage_key
    AND stage.is_active;

  UPDATE public.booking_journey_states state
  SET
    current_stage_id = v_target.id,
    stage_entered_at = now(),
    version = state.version + 1,
    updated_at = now(),
    updated_by =
      '8d000000-0000-0000-0000-000000000101'
  WHERE state.organization_id = v_state.organization_id
    AND state.booking_id = v_state.booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s4_fixture_completion(
  p_booking_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.booking_shoot_completions (
    organization_id,
    booking_id,
    completed_at,
    recorded_by
  )
  SELECT
    booking.organization_id,
    booking.id,
    now() - interval '1 hour',
    '8d000000-0000-0000-0000-000000000101'
  FROM public.bookings booking
  WHERE booking.id = p_booking_id;
END;
$$;

CREATE FUNCTION pg_temp.s11s4_prepare_stage11(
  p_booking_id uuid,
  p_shoot_transition_key text DEFAULT 'shoot_completed'
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_temp.s11s4_move_to_stage(
    p_booking_id,
    10,
    'shoot_scheduled'
  );

  PERFORM pg_temp.s11s4_fixture_completion(
    p_booking_id
  );

  PERFORM pg_temp.s11s4_move_to_stage(
    p_booking_id,
    11,
    'shoot_completed',
    p_shoot_transition_key
  );
END;
$$;

CREATE TEMP TABLE s11s4_ids (
  happy_booking_id uuid,
  founder_booking_id uuid,
  manager_booking_id uuid,
  no_completion_booking_id uuid,
  missing_lineage_booking_id uuid,
  malformed_lineage_booking_id uuid,
  stage10_booking_id uuid,
  stage13_booking_id uuid,
  zero_state_booking_id uuid,
  cross_branch_booking_id uuid,
  replay_missing_selection_transition_id uuid,
  replay_malformed_selection_transition_id uuid,
  replay_missing_shoot_transition_id uuid,
  replay_missing_completion_id uuid
);

INSERT INTO s11s4_ids
VALUES (
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(
    '8d000000-0000-0000-0000-000000000702'
  ),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL),
  pg_temp.s11s4_create_booking(NULL)
);

SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT happy_booking_id FROM s11s4_ids)
);

SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT founder_booking_id FROM s11s4_ids)
);

SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT manager_booking_id FROM s11s4_ids)
);

-- Exact Stage 11, but no completion.
SELECT pg_temp.s11s4_move_to_stage(
  (SELECT no_completion_booking_id FROM s11s4_ids),
  11,
  'shoot_completed',
  'shoot_completed'
);

-- Exact Stage 11 with completion, but missing canonical Stage 10 -> 11 lineage.
SELECT pg_temp.s11s4_move_to_stage(
  (SELECT missing_lineage_booking_id FROM s11s4_ids),
  10,
  'shoot_scheduled'
);
SELECT pg_temp.s11s4_fixture_completion(
  (SELECT missing_lineage_booking_id FROM s11s4_ids)
);
SELECT pg_temp.s11s4_set_stage_without_transition(
  (SELECT missing_lineage_booking_id FROM s11s4_ids),
  11,
  'shoot_completed'
);

-- Exact Stage 11 with completion, but malformed Stage 10 -> 11 key.
SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT malformed_lineage_booking_id FROM s11s4_ids),
  's11s4_malformed_shoot_completed'
);

-- Wrong current-stage fixtures.
SELECT pg_temp.s11s4_move_to_stage(
  (SELECT stage10_booking_id FROM s11s4_ids),
  10,
  'shoot_scheduled'
);

SELECT pg_temp.s11s4_move_to_stage(
  (SELECT stage13_booking_id FROM s11s4_ids),
  13,
  'editing_pending'
);

SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT cross_branch_booking_id FROM s11s4_ids)
);

-- ---------------------------------------------------------------------
-- Strict Stage-12 replay corruption fixtures.
-- ---------------------------------------------------------------------

-- Current Stage 12 with valid completion + Stage 10 -> 11 lineage,
-- but no Stage 11 -> 12 transition exists.
SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT replay_missing_selection_transition_id FROM s11s4_ids)
);

SELECT pg_temp.s11s4_set_stage_without_transition(
  (SELECT replay_missing_selection_transition_id FROM s11s4_ids),
  12,
  'selection_pending'
);

-- Current Stage 12 with valid prior lineage, but malformed
-- Stage 11 -> 12 transition key.
SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT replay_malformed_selection_transition_id FROM s11s4_ids)
);

SELECT pg_temp.s11s4_move_to_stage(
  (SELECT replay_malformed_selection_transition_id FROM s11s4_ids),
  12,
  'selection_pending',
  's11s4_malformed_selection_pending'
);

-- Current Stage 12 with a valid Stage 11 -> 12 transition, but
-- malformed Stage 10 -> 11 completion-transition history.
SELECT pg_temp.s11s4_move_to_stage(
  (SELECT replay_missing_shoot_transition_id FROM s11s4_ids),
  10,
  'shoot_scheduled'
);

SELECT pg_temp.s11s4_fixture_completion(
  (SELECT replay_missing_shoot_transition_id FROM s11s4_ids)
);

SELECT pg_temp.s11s4_move_to_stage(
  (SELECT replay_missing_shoot_transition_id FROM s11s4_ids),
  11,
  'shoot_completed',
  's11s4_malformed_shoot_completed'
);

SELECT pg_temp.s11s4_move_to_stage(
  (SELECT replay_missing_shoot_transition_id FROM s11s4_ids),
  12,
  'selection_pending',
  'selection_pending'
);

-- Current Stage 12 with both canonical transition rows, but missing
-- immutable shoot-completion evidence.
SELECT pg_temp.s11s4_prepare_stage11(
  (SELECT replay_missing_completion_id FROM s11s4_ids)
);

SELECT pg_temp.s11s4_move_to_stage(
  (SELECT replay_missing_completion_id FROM s11s4_ids),
  12,
  'selection_pending',
  'selection_pending'
);

ALTER TABLE public.booking_shoot_completions
DISABLE TRIGGER USER;

DELETE FROM public.booking_shoot_completions
WHERE booking_id =
  (SELECT replay_missing_completion_id FROM s11s4_ids);

ALTER TABLE public.booking_shoot_completions
ENABLE TRIGGER USER;

ALTER TABLE public.booking_journey_states
DISABLE TRIGGER USER;

DELETE FROM public.booking_journey_states
WHERE booking_id =
  (SELECT zero_state_booking_id FROM s11s4_ids);

ALTER TABLE public.booking_journey_states
ENABLE TRIGGER USER;

-- =====================================================================
-- Part 3 — Input / actor / stage / lineage rejection
-- =====================================================================

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000001'
);

-- K
SELECT throws_ok(
  $$ SELECT public.mark_booking_selection_pending(NULL) $$,
  '22023',
  'mark_booking_selection_pending: booking_id is required',
  'K: null booking id is rejected'
);

SELECT pg_temp.s11s4_set_actor(NULL);

-- L
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT happy_booking_id FROM s11s4_ids)
  )
  $$,
  '42501',
  'mark_booking_selection_pending: authenticated actor required',
  'L: unauthenticated invocation is rejected'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000001'
);

-- M
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    '8dffffff-ffff-ffff-ffff-ffffffffffff'::uuid
  )
  $$,
  '22023',
  'mark_booking_selection_pending: booking not found',
  'M: missing booking is rejected'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000006'
);

-- N
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT happy_booking_id FROM s11s4_ids)
  )
  $$,
  '42501',
  'mark_booking_selection_pending: active organization membership required',
  'N: suspended member is rejected'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000004'
);

-- O
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT happy_booking_id FROM s11s4_ids)
  )
  $$,
  '42501',
  'mark_booking_selection_pending: booking.stage.advance permission required',
  'O: Photographer cannot advance'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000005'
);

-- P
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT happy_booking_id FROM s11s4_ids)
  )
  $$,
  '42501',
  'mark_booking_selection_pending: booking.stage.advance permission required',
  'P: Editor cannot advance through editing.write'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000007'
);

-- Q
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT cross_branch_booking_id FROM s11s4_ids)
  )
  $$,
  '42501',
  'mark_booking_selection_pending: booking.stage.advance permission required',
  'Q: branch-scoped Coordinator cannot advance another branch'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000001'
);

-- R
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT zero_state_booking_id FROM s11s4_ids)
  )
  $$,
  'P0001',
  'mark_booking_selection_pending: booking must have exactly one current journey state',
  'R: zero journey-state rows are rejected'
);

-- S
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT stage10_booking_id FROM s11s4_ids)
  )
  $$,
  '22023',
  'mark_booking_selection_pending: booking must be exactly Shoot Completed or Selection Pending replay',
  'S: Stage 10 is rejected before post-shoot lineage checks'
);

-- T
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT stage13_booking_id FROM s11s4_ids)
  )
  $$,
  '22023',
  'mark_booking_selection_pending: booking must be exactly Shoot Completed or Selection Pending replay',
  'T: Stage 13 is rejected before post-shoot lineage checks'
);

-- U
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT no_completion_booking_id FROM s11s4_ids)
  )
  $$,
  '22023',
  'mark_booking_selection_pending: exactly one canonical shoot completion row required',
  'U: exact Stage 11 without completion evidence is rejected'
);

-- V
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT missing_lineage_booking_id FROM s11s4_ids)
  )
  $$,
  'P0001',
  'mark_booking_selection_pending: canonical Shoot Completed transition history is invalid',
  'V: Stage 11 without canonical Stage 10 -> 11 lineage is rejected'
);

-- W
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT malformed_lineage_booking_id FROM s11s4_ids)
  )
  $$,
  'P0001',
  'mark_booking_selection_pending: canonical Shoot Completed transition history is invalid',
  'W: malformed Stage 10 -> 11 lineage is rejected'
);

-- =====================================================================
-- Part 4 — Authorized advancement
-- =====================================================================

CREATE TEMP TABLE s11s4_happy_before AS
SELECT
  state.version AS journey_version,
  to_jsonb(completion) AS completion_row,
  (
    SELECT count(*)::bigint
    FROM public.booking_payments payment
    WHERE payment.booking_id = state.booking_id
  ) AS payment_rows
FROM public.booking_journey_states state
JOIN public.booking_shoot_completions completion
  ON completion.organization_id = state.organization_id
 AND completion.booking_id = state.booking_id
WHERE state.booking_id =
  (SELECT happy_booking_id FROM s11s4_ids);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000003'
);

-- X
SELECT lives_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT happy_booking_id FROM s11s4_ids)
  )
  $$,
  'X: Client Coordinator advances valid Stage 11 lineage'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000001'
);

-- Y
SELECT lives_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT founder_booking_id FROM s11s4_ids)
  )
  $$,
  'Y: Founder advances valid Stage 11 lineage'
);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000002'
);

-- Z
SELECT lives_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT manager_booking_id FROM s11s4_ids)
  )
  $$,
  'Z: Studio Manager advances valid Stage 11 lineage'
);

-- =====================================================================
-- Part 5 — Exact successful mutation contract
-- =====================================================================

-- AA
SELECT is(
  (
    SELECT stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id = state.organization_id
     AND stage.id = state.current_stage_id
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
  ),
  'selection_pending'::text,
  'AA: success resolves exact Stage 12 selection_pending'
);

-- AB
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
      AND transition_row.transition_key =
        'selection_pending'
  ),
  1::bigint,
  'AB: success appends exactly one selection_pending transition'
);

-- AC
SELECT ok(
  (
    SELECT
      source_stage.stage_key = 'shoot_completed'
      AND source_stage.stage_order = 11
      AND destination_stage.stage_key = 'selection_pending'
      AND destination_stage.stage_order = 12
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages source_stage
      ON source_stage.organization_id =
         transition_row.organization_id
     AND source_stage.id =
         transition_row.from_stage_id
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id =
         transition_row.organization_id
     AND destination_stage.id =
         transition_row.to_stage_id
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
      AND transition_row.transition_key =
        'selection_pending'
  ),
  'AC: transition is exact Stage 11 -> 12'
);

-- AD
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
  ),
  (
    SELECT journey_version + 1
    FROM s11s4_happy_before
  ),
  'AD: journey version increments exactly once'
);

-- AE
SELECT ok(
  (
    SELECT
      transition_row.transitioned_by =
        '8d000000-0000-0000-0000-000000000103'::uuid
      AND state.updated_by =
        '8d000000-0000-0000-0000-000000000103'::uuid
      AND state.stage_entered_at =
        transition_row.transitioned_at
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_states state
      ON state.organization_id =
         transition_row.organization_id
     AND state.booking_id =
         transition_row.booking_id
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
      AND transition_row.transition_key =
        'selection_pending'
  ),
  'AE: state and transition use the canonical advancing actor/timestamp'
);

-- AF
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.action_key =
      'booking.selection_pending'
      AND audit.entity_id =
        (SELECT happy_booking_id FROM s11s4_ids)
  ),
  1::bigint,
  'AF: success appends exactly one booking.selection_pending audit'
);

-- AG
SELECT ok(
  (
    SELECT
      NOT audit.is_sensitive
      AND NOT (
        COALESCE(audit.metadata, '{}'::jsonb)
        ?| ARRAY[
          'selected_image_ids',
          'selected_image_count',
          'selection_confirmed_at',
          'gallery_url',
          'proofing_url',
          'editing_notes'
        ]
      )
      AND NOT (
        COALESCE(audit.old_values, '{}'::jsonb)
        ?| ARRAY[
          'selected_image_ids',
          'selected_image_count',
          'selection_confirmed_at',
          'gallery_url',
          'proofing_url',
          'editing_notes'
        ]
      )
      AND NOT (
        COALESCE(audit.new_values, '{}'::jsonb)
        ?| ARRAY[
          'selected_image_ids',
          'selected_image_count',
          'selection_confirmed_at',
          'gallery_url',
          'proofing_url',
          'editing_notes'
        ]
      )
    FROM public.audit_events audit
    WHERE audit.action_key =
      'booking.selection_pending'
      AND audit.entity_id =
        (SELECT happy_booking_id FROM s11s4_ids)
  ),
  'AG: audit is structural, non-sensitive and contains no selection evidence'
);

-- AH
SELECT is(
  (
    SELECT to_jsonb(completion)
    FROM public.booking_shoot_completions completion
    WHERE completion.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
  ),
  (
    SELECT completion_row
    FROM s11s4_happy_before
  ),
  'AH: shoot-completion evidence remains unchanged'
);

-- AI
SELECT is(
  (
    SELECT payment_rows
    FROM s11s4_happy_before
  ),
  0::bigint,
  'AI: successful Stage 11 -> 12 fixture requires no new payment evidence'
);

-- =====================================================================
-- Part 6 — Valid exact Stage 12 replay
-- =====================================================================

CREATE TEMP TABLE s11s4_replay_before AS
SELECT
  state.version AS journey_version,
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id = state.booking_id
      AND transition_row.transition_key =
        'selection_pending'
  ) AS transition_count,
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id = state.booking_id
      AND audit.action_key =
        'booking.selection_pending'
  ) AS audit_count
FROM public.booking_journey_states state
WHERE state.booking_id =
  (SELECT happy_booking_id FROM s11s4_ids);

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000003'
);

-- AJ
SELECT lives_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT happy_booking_id FROM s11s4_ids)
  )
  $$,
  'AJ: valid exact Stage 12 replay succeeds'
);

-- AK
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.booking_stage_transitions transition_row
    WHERE transition_row.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
      AND transition_row.transition_key =
        'selection_pending'
  ),
  (
    SELECT transition_count
    FROM s11s4_replay_before
  ),
  'AK: replay adds no transition'
);

-- AL
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit
    WHERE audit.entity_id =
      (SELECT happy_booking_id FROM s11s4_ids)
      AND audit.action_key =
        'booking.selection_pending'
  ),
  (
    SELECT audit_count
    FROM s11s4_replay_before
  ),
  'AL: replay adds no audit'
);

-- AM
SELECT is(
  (
    SELECT state.version
    FROM public.booking_journey_states state
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM s11s4_ids)
  ),
  (
    SELECT journey_version
    FROM s11s4_replay_before
  ),
  'AM: replay does not increment journey version'
);

-- =====================================================================
-- Part 7 — Strict malformed Stage 12 replay rejection
-- =====================================================================

SELECT pg_temp.s11s4_set_actor(
  '8d000000-0000-0000-0000-000000000003'
);

-- AN
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT replay_missing_selection_transition_id FROM s11s4_ids)
  )
  $$,
  'P0001',
  'mark_booking_selection_pending: Selection Pending replay history is invalid',
  'AN: Stage 12 replay without Stage 11 -> 12 transition is rejected'
);

-- AO
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT replay_malformed_selection_transition_id FROM s11s4_ids)
  )
  $$,
  'P0001',
  'mark_booking_selection_pending: Selection Pending replay history is invalid',
  'AO: Stage 12 replay with malformed Stage 11 -> 12 history is rejected'
);

-- AP
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT replay_missing_shoot_transition_id FROM s11s4_ids)
  )
  $$,
  'P0001',
  'mark_booking_selection_pending: canonical Shoot Completed transition history is invalid',
  'AP: Stage 12 replay without canonical Stage 10 -> 11 lineage is rejected'
);

-- AQ
SELECT throws_ok(
  $$
  SELECT public.mark_booking_selection_pending(
    (SELECT replay_missing_completion_id FROM s11s4_ids)
  )
  $$,
  '22023',
  'mark_booking_selection_pending: exactly one canonical shoot completion row required',
  'AQ: Stage 12 replay without completion evidence is rejected'
);

SELECT * FROM finish();

ROLLBACK;
