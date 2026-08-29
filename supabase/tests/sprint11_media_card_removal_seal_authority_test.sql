CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(60);

-- =====================================================================
-- Phase 2 Studio Operations
-- Corrective Slice B2 - Media Card Removal / Shot Accounting / Seal
--
-- Proves:
--   * exact media.card.remove corrective authority topology;
--   * exact immutable nine-column removal / seal evidence relation;
--   * tenant-safe assignment and member lineage;
--   * organization-unique seal identity;
--   * one removal per B1 assignment;
--   * forced RLS / narrow read authority;
--   * authenticated-only controlled removal RPC;
--   * current pinned B1 custodian authority;
--   * atomic CUS-502 + CUS-503 evidence and assignment closure;
--   * strict replay behavior;
--   * Stage 10 first-success authority;
--   * active-card blocking of first Stage 10 -> 11 advancement;
--   * no B3 transfer / ingestion / checksum / backup / release authority.
-- =====================================================================


-- =====================================================================
-- Part 1A - Catalogue / relation contract
-- =====================================================================

-- 1
SELECT is(
  (
    SELECT
      (SELECT count(*) FROM public.permissions)::text
      || ':'
      || (SELECT count(*) FROM public.role_permissions)::text
  ),
  '72:247'::text,
  'canonical permission and role-mapping totals are exactly 72:247'
);


-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key =
          'media.card.remove'
      AND permission.domain =
          'media'
      AND permission.label =
          'Remove and seal media cards'
      AND permission.description =
          'Remove active media cards from capture devices, record expected file counts, and seal them while held by the current custodian.'
      AND permission.requires_server_enforcement
  ),
  1::bigint,
  'media.card.remove exists exactly once with the frozen corrective contract'
);


-- 3
SELECT is(
  (
    SELECT array_agg(
      role.key
      ORDER BY role.key
    )
    FROM public.role_permissions mapping
    JOIN public.permissions permission
      ON permission.id =
         mapping.permission_id
    JOIN public.roles role
      ON role.id =
         mapping.role_id
    WHERE permission.key =
          'media.card.remove'
  ),
  ARRAY[
    'photographer'
  ]::text[],
  'media.card.remove is granted only to Photographer'
);


-- 4
SELECT is(
  (
    SELECT array_agg(
      column_name || ':' || udt_name
      ORDER BY ordinal_position
    )
    FROM information_schema.columns
    WHERE table_schema =
          'public'
      AND table_name =
          'media_card_removals'
  ),
  ARRAY[
    'id:uuid',
    'organization_id:uuid',
    'booking_id:uuid',
    'media_card_assignment_id:uuid',
    'expected_file_count:int8',
    'seal_id:text',
    'seal_condition:text',
    'removed_at:timestamptz',
    'removed_by:uuid'
  ]::text[],
  'media_card_removals contains exactly the frozen nine-column typed contract'
);


-- 5
SELECT ok(
  (
    SELECT replace(
      pg_catalog.pg_get_constraintdef(
        constraint_row.oid
      ),
      'public.',
      ''
    )
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.media_card_removals'::regclass
      AND constraint_row.conname =
          'media_card_removals_assignment_fkey'
  ) LIKE
    'FOREIGN KEY (media_card_assignment_id, organization_id, booking_id) REFERENCES media_card_assignments(id, organization_id, booking_id)%',
  'removal evidence references the exact B1 assignment through tenant-safe booking lineage'
);


-- 6
SELECT ok(
  (
    SELECT replace(
      pg_catalog.pg_get_constraintdef(
        constraint_row.oid
      ),
      'public.',
      ''
    )
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.media_card_removals'::regclass
      AND constraint_row.conname =
          'media_card_removals_removed_by_fkey'
  ) LIKE
    'FOREIGN KEY (removed_by, organization_id) REFERENCES organization_members(id, organization_id)%',
  'removal actor lineage is organization-safe'
);


-- 7
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.media_card_removals'::regclass
      AND constraint_row.conname IN (
        'media_card_removals_assignment_key',
        'media_card_removals_org_seal_key',
        'media_card_removals_id_org_booking_key'
      )
      AND constraint_row.contype =
          'u'
  ),
  3::bigint,
  'removal evidence has assignment, organization-seal and future tenant-safe identity uniqueness'
);


-- 8
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.media_card_removals'::regclass
      AND constraint_row.conname IN (
        'media_card_removals_expected_file_count_chk',
        'media_card_removals_seal_id_chk',
        'media_card_removals_seal_condition_chk'
      )
      AND constraint_row.contype =
          'c'
  ),
  3::bigint,
  'expected-count and canonical non-empty seal evidence checks exist'
);


-- 9
SELECT ok(
  (
    SELECT
      relation.relrowsecurity
      AND relation.relforcerowsecurity
    FROM pg_catalog.pg_class relation
    JOIN pg_catalog.pg_namespace namespace
      ON namespace.oid =
         relation.relnamespace
    WHERE namespace.nspname =
          'public'
      AND relation.relname =
          'media_card_removals'
  ),
  'media_card_removals has enabled and forced RLS'
);


-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_policies policy
    WHERE policy.schemaname =
          'public'
      AND policy.tablename =
          'media_card_removals'
      AND policy.policyname =
          'media_card_removals_authenticated_select'
      AND policy.cmd =
          'SELECT'
  ),
  1::bigint,
  'media_card_removals exposes exactly the frozen authenticated SELECT policy'
);

-- =====================================================================
-- Part 1B - Guard / ACL / RPC / Stage 10 -> 11 contract
-- =====================================================================

-- 11
SELECT ok(
  to_regprocedure(
    'public.lsh_media_card_removal_guard()'
  ) IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.media_card_removals'::regclass
      AND trigger_row.tgname =
          'media_card_removals_guard'
      AND NOT trigger_row.tgisinternal
  ),
  'immutable media-card removal guard and trigger exist'
);


-- 12
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%media card removal evidence cannot be deleted%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%media card removal evidence is immutable%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.lsh_media_card_removal_guard()'::regprocedure
  ),
  'removal evidence guard rejects UPDATE and DELETE'
);


-- 13
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%public.media_card_removals%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%OLD.ended_at IS NULL%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%NEW.ended_at IS NOT NULL%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%controlled removal closure%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%media card assignment evidence cannot be deleted%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.lsh_media_card_assignment_guard()'::regprocedure
  ),
  'B1 assignment guard permits only evidence-backed one-way B2 closure'
);


-- 14
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.media_card_removals',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.media_card_removals',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.media_card_removals',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.media_card_removals',
    'DELETE'
  ),
  'authenticated may read removal evidence but has no direct mutation privilege'
);


-- 15
SELECT ok(
  to_regprocedure(
    'public.remove_and_seal_media_card(uuid,bigint,text,text)'
  ) IS NOT NULL
  AND (
    SELECT
      pg_get_function_result(procedure.oid) =
        'media_card_removals'
      AND procedure.prosecdef
      AND procedure.proconfig =
        ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.remove_and_seal_media_card(uuid,bigint,text,text)'::regprocedure
  ),
  'remove_and_seal_media_card has the frozen return and SECURITY DEFINER contract'
);


-- 16
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.remove_and_seal_media_card(uuid,bigint,text,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.remove_and_seal_media_card(uuid,bigint,text,text)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.remove_and_seal_media_card(uuid,bigint,text,text)',
    'EXECUTE'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc procedure
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        procedure.proacl,
        acldefault(
          'f',
          procedure.proowner
        )
      )
    ) acl
    WHERE procedure.oid =
      'public.remove_and_seal_media_card(uuid,bigint,text,text)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type =
          'EXECUTE'
  ),
  'removal/seal RPC execution ACL is authenticated-only'
);


-- 17
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%current_organization_member%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%media.card.remove%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%custodian_member_id%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%stage_order <> 10%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%shoot_scheduled%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%media.card_removed_and_sealed%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%INSERT INTO public.booking_stage_transitions%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%UPDATE public.booking_journey_states%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%media.custody.transfer%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%checksum%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%backup%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.remove_and_seal_media_card(uuid,bigint,text,text)'::regprocedure
  ),
  'removal RPC contains frozen B2 authority and imports no B3 or later workflow'
);


-- 18
SELECT ok(
  (
    SELECT
      policy.qual ILIKE
        '%current_organization_member%'
      AND policy.qual ILIKE
        '%media.card.remove%'
      AND policy.qual ILIKE
        '%has_branch_scope%'
    FROM pg_catalog.pg_policies policy
    WHERE policy.schemaname =
          'public'
      AND policy.tablename =
          'media_card_removals'
      AND policy.policyname =
          'media_card_removals_authenticated_select'
  ),
  'removal evidence SELECT policy requires active membership, narrow permission and branch scope'
);


-- 19
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%public.media_card_assignments%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%assignment.ended_at IS NULL%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%all media card assignments must be removed and sealed%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%Shoot Completed replay%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%booking.shoot_completed%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
  ),
  'Stage 10 -> 11 RPC contains the frozen active-card gate while preserving strict replay and audit authority'
);


-- 20
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.mark_booking_shoot_completed(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.mark_booking_shoot_completed(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.mark_booking_shoot_completed(uuid)',
    'EXECUTE'
  )
  AND (
    SELECT
      procedure.prosecdef
      AND procedure.proconfig =
        ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.mark_booking_shoot_completed(uuid)'::regprocedure
  ),
  'Stage 10 -> 11 RPC retains its authenticated SECURITY DEFINER execution boundary'
);

-- =====================================================================
-- Part 2 - Transaction-local actors / booking fixture helpers
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('b2000000-0000-0000-0000-000000000001'::uuid),
  ('b2000000-0000-0000-0000-000000000002'::uuid),
  ('b2000000-0000-0000-0000-000000000003'::uuid),
  ('b2000000-0000-0000-0000-000000000004'::uuid),
  ('b2000000-0000-0000-0000-000000000005'::uuid),
  ('b2000000-0000-0000-0000-000000000006'::uuid);


INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  'b2000000-0000-0000-0000-000000000701'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2 Media Removal Branch A',
  'b2-media-a',
  'active'::public.branch_status
),
(
  'b2000000-0000-0000-0000-000000000702'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2 Media Removal Branch B',
  'b2-media-b',
  'active'::public.branch_status
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
  'b2000000-0000-0000-0000-000000000101'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b2000000-0000-0000-0000-000000000001'::uuid,
  'active'::public.member_status,
  'B2 Founder',
  NULL
),
(
  'b2000000-0000-0000-0000-000000000102'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b2000000-0000-0000-0000-000000000002'::uuid,
  'active'::public.member_status,
  'B2 Lead Photographer',
  NULL
),
(
  'b2000000-0000-0000-0000-000000000103'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b2000000-0000-0000-0000-000000000003'::uuid,
  'active'::public.member_status,
  'B2 Other Photographer',
  NULL
),
(
  'b2000000-0000-0000-0000-000000000104'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b2000000-0000-0000-0000-000000000004'::uuid,
  'active'::public.member_status,
  'B2 Branch A Photographer',
  NULL
),
(
  'b2000000-0000-0000-0000-000000000105'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b2000000-0000-0000-0000-000000000005'::uuid,
  'suspended'::public.member_status,
  'B2 Suspended Photographer',
  now()
),
(
  'b2000000-0000-0000-0000-000000000106'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b2000000-0000-0000-0000-000000000006'::uuid,
  'active'::public.member_status,
  'B2 Studio Manager',
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
      'b2000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b2000000-0000-0000-0000-000000000102'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      'b2000000-0000-0000-0000-000000000103'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      'b2000000-0000-0000-0000-000000000104'::uuid,
      'photographer'::text,
      'b2000000-0000-0000-0000-000000000701'::uuid
    ),
    (
      'b2000000-0000-0000-0000-000000000105'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      'b2000000-0000-0000-0000-000000000106'::uuid,
      'studio_manager'::text,
      NULL::uuid
    )
) AS fixture(
  member_id,
  role_key,
  branch_id
)
JOIN public.roles role
  ON role.key =
     fixture.role_key;


UPDATE public.organizations
SET status =
    'active'::public.organization_status
WHERE id =
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid;


CREATE FUNCTION pg_temp.b2_set_actor(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claim.sub',
    COALESCE(
      p_user_id::text,
      ''
    ),
    true
  );

  PERFORM set_config(
    'request.jwt.claims',
    CASE
      WHEN p_user_id IS NULL THEN
        '{}'
      ELSE
        jsonb_build_object(
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


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
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
  'b2000000-0000-0000-0000-000000000201'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'LSH-56789E',
  'B2 Media Removal Family',
  'B2 Media Removal Family',
  'active',
  'b2000000-0000-0000-0000-000000000101'::uuid,
  'b2000000-0000-0000-0000-000000000101'::uuid
);


CREATE FUNCTION pg_temp.b2_create_booking(
  p_branch_id uuid
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
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE package.package_key =
        'maternity_gold'
    AND version.version_number =
        1;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'b2000000-0000-0000-0000-000000000201'::uuid,
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
  FROM public.accept_quotation(
    v_quote.id
  );

  RETURN v_booking.id;
END;
$$;


CREATE FUNCTION pg_temp.b2_move_to_stage(
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
  WHERE state.booking_id =
        p_booking_id;

  SELECT stage.*
  INTO v_target
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_state.organization_id
    AND stage.stage_order =
        p_stage_order
    AND stage.stage_key =
        p_stage_key
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
    'b2_fixture_' || p_stage_key,
    now(),
    'b2000000-0000-0000-0000-000000000101'::uuid
  );

  UPDATE public.booking_journey_states state
  SET
    current_stage_id =
      v_target.id,
    stage_entered_at =
      now(),
    version =
      state.version + 1,
    updated_at =
      now(),
    updated_by =
      'b2000000-0000-0000-0000-000000000101'::uuid
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;

-- =====================================================================
-- Part 2B - Canonical booking / custody fixtures
-- =====================================================================

CREATE TEMP TABLE b2_booking_ids (
  happy_booking_id uuid,
  stage9_booking_id uuid,
  cross_branch_booking_id uuid,
  gate_booking_id uuid,
  custody_booking_id uuid,
  no_card_booking_id uuid
);


INSERT INTO b2_booking_ids
VALUES (
  pg_temp.b2_create_booking(
    'b2000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b2_create_booking(
    'b2000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b2_create_booking(
    'b2000000-0000-0000-0000-000000000702'::uuid
  ),
  pg_temp.b2_create_booking(
    'b2000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b2_create_booking(
    'b2000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b2_create_booking(
    'b2000000-0000-0000-0000-000000000701'::uuid
  )
);


-- Enter the canonical Stage 8 staffing window first.
SELECT pg_temp.b2_move_to_stage(
  happy_booking_id,
  8,
  'booking_confirmed'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  stage9_booking_id,
  8,
  'booking_confirmed'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  cross_branch_booking_id,
  8,
  'booking_confirmed'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  gate_booking_id,
  8,
  'booking_confirmed'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  custody_booking_id,
  8,
  'booking_confirmed'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  no_card_booking_id,
  8,
  'booking_confirmed'
)
FROM b2_booking_ids;


-- Pin the canonical internal Lead Photographer before Stage 10.
SELECT public.assign_booking_team_member(
  happy_booking_id,
  'lead_photographer',
  'b2000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b2_booking_ids;

SELECT public.assign_booking_team_member(
  stage9_booking_id,
  'lead_photographer',
  'b2000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b2_booking_ids;

SELECT public.assign_booking_team_member(
  cross_branch_booking_id,
  'lead_photographer',
  'b2000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b2_booking_ids;

SELECT public.assign_booking_team_member(
  gate_booking_id,
  'lead_photographer',
  'b2000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b2_booking_ids;

SELECT public.assign_booking_team_member(
  custody_booking_id,
  'lead_photographer',
  'b2000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b2_booking_ids;

SELECT public.assign_booking_team_member(
  no_card_booking_id,
  'lead_photographer',
  'b2000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b2_booking_ids;


-- Exact B1 assignment source stage.
SELECT pg_temp.b2_move_to_stage(
  happy_booking_id,
  10,
  'shoot_scheduled'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  stage9_booking_id,
  10,
  'shoot_scheduled'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  cross_branch_booking_id,
  10,
  'shoot_scheduled'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  gate_booking_id,
  10,
  'shoot_scheduled'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  custody_booking_id,
  10,
  'shoot_scheduled'
)
FROM b2_booking_ids;

SELECT pg_temp.b2_move_to_stage(
  no_card_booking_id,
  10,
  'shoot_scheduled'
)
FROM b2_booking_ids;


-- Canonical registered inventory.
CREATE TEMP TABLE b2_inventory (
  label text PRIMARY KEY,
  media_card_id uuid,
  capture_device_id uuid
);


INSERT INTO b2_inventory (
  label,
  media_card_id
)
SELECT
  'card_1',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CARD-001'
) card;

INSERT INTO b2_inventory (
  label,
  media_card_id
)
SELECT
  'card_2',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CARD-002'
) card;

INSERT INTO b2_inventory (
  label,
  media_card_id
)
SELECT
  'card_3',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CARD-003'
) card;

INSERT INTO b2_inventory (
  label,
  media_card_id
)
SELECT
  'card_4',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CARD-004'
) card;

INSERT INTO b2_inventory (
  label,
  media_card_id
)
SELECT
  'card_5',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CARD-005'
) card;

INSERT INTO b2_inventory (
  label,
  media_card_id
)
SELECT
  'card_6',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CARD-006'
) card;


INSERT INTO b2_inventory (
  label,
  capture_device_id
)
SELECT
  'device_1',
  device.id
FROM public.register_capture_device(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CAM-001'
) device;

INSERT INTO b2_inventory (
  label,
  capture_device_id
)
SELECT
  'device_2',
  device.id
FROM public.register_capture_device(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B2-CAM-002'
) device;


-- B1 assignment authority is exercised by the pinned Lead Photographer.
SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


CREATE TEMP TABLE b2_assignments (
  label text PRIMARY KEY,
  media_card_assignment_id uuid
);


INSERT INTO b2_assignments
SELECT
  'happy',
  assignment.id
FROM public.assign_media_card(
  (SELECT happy_booking_id FROM b2_booking_ids),
  (SELECT media_card_id FROM b2_inventory WHERE label = 'card_1'),
  (SELECT capture_device_id FROM b2_inventory WHERE label = 'device_1')
) assignment;


INSERT INTO b2_assignments
SELECT
  'stage9',
  assignment.id
FROM public.assign_media_card(
  (SELECT stage9_booking_id FROM b2_booking_ids),
  (SELECT media_card_id FROM b2_inventory WHERE label = 'card_2'),
  (SELECT capture_device_id FROM b2_inventory WHERE label = 'device_1')
) assignment;


INSERT INTO b2_assignments
SELECT
  'cross_branch',
  assignment.id
FROM public.assign_media_card(
  (SELECT cross_branch_booking_id FROM b2_booking_ids),
  (SELECT media_card_id FROM b2_inventory WHERE label = 'card_3'),
  (SELECT capture_device_id FROM b2_inventory WHERE label = 'device_1')
) assignment;


INSERT INTO b2_assignments
SELECT
  'gate_a',
  assignment.id
FROM public.assign_media_card(
  (SELECT gate_booking_id FROM b2_booking_ids),
  (SELECT media_card_id FROM b2_inventory WHERE label = 'card_4'),
  (SELECT capture_device_id FROM b2_inventory WHERE label = 'device_1')
) assignment;


INSERT INTO b2_assignments
SELECT
  'gate_b',
  assignment.id
FROM public.assign_media_card(
  (SELECT gate_booking_id FROM b2_booking_ids),
  (SELECT media_card_id FROM b2_inventory WHERE label = 'card_5'),
  (SELECT capture_device_id FROM b2_inventory WHERE label = 'device_2')
) assignment;


INSERT INTO b2_assignments
SELECT
  'custody',
  assignment.id
FROM public.assign_media_card(
  (SELECT custody_booking_id FROM b2_booking_ids),
  (SELECT media_card_id FROM b2_inventory WHERE label = 'card_6'),
  (SELECT capture_device_id FROM b2_inventory WHERE label = 'device_1')
) assignment;

SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);
-- Force one already-assigned fixture away from Stage 10 so B2 can prove
-- that first removal success is still exact-stage constrained.
SELECT pg_temp.b2_move_to_stage(
  stage9_booking_id,
  9,
  'pre_shoot_preparation'
)
FROM b2_booking_ids;

-- =====================================================================
-- Part 3 - Input / authentication / exact-stage authority
-- =====================================================================

SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


-- 21
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    NULL,
    120,
    'B2-SEAL-021',
    'sealed intact'
  )
  $$,
  '22023',
  'remove_and_seal_media_card: media_card_assignment_id is required',
  'null media-card assignment id is rejected'
);


-- 22
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    NULL,
    'B2-SEAL-022',
    'sealed intact'
  )
  $$,
  '22023',
  'remove_and_seal_media_card: expected_file_count is required',
  'null expected file count is rejected'
);


-- 23
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    -1,
    'B2-SEAL-023',
    'sealed intact'
  )
  $$,
  '22023',
  'remove_and_seal_media_card: expected_file_count must be non-negative',
  'negative expected file count is rejected'
);


-- 24
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    NULL,
    'sealed intact'
  )
  $$,
  '22023',
  'remove_and_seal_media_card: seal_id is required',
  'null seal id is rejected'
);


-- 25
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    '   ',
    'sealed intact'
  )
  $$,
  '22023',
  'remove_and_seal_media_card: seal_id must be non-empty',
  'blank seal id is rejected after canonical trimming'
);


-- 26
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    'B2-SEAL-026',
    NULL
  )
  $$,
  '22023',
  'remove_and_seal_media_card: seal_condition is required',
  'null seal condition is rejected'
);


-- 27
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    'B2-SEAL-027',
    '   '
  )
  $$,
  '22023',
  'remove_and_seal_media_card: seal_condition must be non-empty',
  'blank seal condition is rejected after canonical trimming'
);


SELECT pg_temp.b2_set_actor(NULL);


-- 28
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    'B2-SEAL-028',
    'sealed intact'
  )
  $$,
  '42501',
  'remove_and_seal_media_card: authenticated actor required',
  'unauthenticated removal is rejected'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


-- 29
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    'b2ffffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    120,
    'B2-SEAL-029',
    'sealed intact'
  )
  $$,
  '22023',
  'remove_and_seal_media_card: media card assignment not found',
  'unknown media-card assignment is rejected'
);


-- 30
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'stage9'),
    120,
    'B2-SEAL-030',
    'sealed intact'
  )
  $$,
  '22023',
  'remove_and_seal_media_card: booking must be at active Stage 10 shoot_scheduled',
  'first removal success is rejected outside exact Stage 10 shoot_scheduled'
);

-- =====================================================================
-- Part 4 - Authorization / atomic removal / replay
-- =====================================================================

SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000005'::uuid
);


-- 31
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    'B2-SEAL-031',
    'sealed intact'
  )
  $$,
  '42501',
  'remove_and_seal_media_card: active organization membership required',
  'suspended photographer cannot remove or seal media cards'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);


-- 32
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    'B2-SEAL-032',
    'sealed intact'
  )
  $$,
  '42501',
  'remove_and_seal_media_card: media.card.remove permission required',
  'Founder receives no corrective media.card.remove authority'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000006'::uuid
);


-- 33
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    'B2-SEAL-033',
    'sealed intact'
  )
  $$,
  '42501',
  'remove_and_seal_media_card: media.card.remove permission required',
  'Studio Manager receives no corrective media.card.remove authority'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000004'::uuid
);


-- 34
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'cross_branch'),
    120,
    'B2-SEAL-034',
    'sealed intact'
  )
  $$,
  '42501',
  'remove_and_seal_media_card: media.card.remove permission required',
  'branch-A Photographer cannot exercise removal authority on branch-B booking'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000003'::uuid
);


-- 35
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    120,
    'B2-SEAL-035',
    'sealed intact'
  )
  $$,
  '42501',
  'remove_and_seal_media_card: current media card custodian required',
  'another authorized Photographer cannot remove a card held by the pinned B1 custodian'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


CREATE TEMP TABLE b2_happy_removal AS
SELECT *
FROM public.remove_and_seal_media_card(
  (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
  120,
  '  B2-SEAL-HAPPY  ',
  '  sealed intact  '
);


-- 36
SELECT is(
  (
    SELECT
      removal.expected_file_count::text
      || ':'
      || removal.seal_id
      || ':'
      || removal.seal_condition
      || ':'
      || removal.removed_by::text
    FROM b2_happy_removal removal
  ),
  '120:B2-SEAL-HAPPY:sealed intact:b2000000-0000-0000-0000-000000000102'::text,
  'first success records expected count, trimmed seal evidence and the pinned custodian actor'
);


-- 37
SELECT ok(
  (
    SELECT
      assignment.ended_at =
        removal.removed_at
      AND assignment.ended_by =
        removal.removed_by
      AND assignment.ended_at IS NOT NULL
      AND assignment.ended_by =
        'b2000000-0000-0000-0000-000000000102'::uuid
    FROM public.media_card_assignments assignment
    JOIN b2_happy_removal removal
      ON removal.media_card_assignment_id =
         assignment.id
  ),
  'atomic B2 success closes the B1 assignment with the exact removal timestamp and actor'
);


-- 38
SELECT is(
  (
    SELECT
      stage.stage_order::text
      || ':'
      || stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM b2_booking_ids)
  ),
  '10:shoot_scheduled'::text,
  'media-card removal records custody evidence without advancing the booking journey'
);


-- 39
SELECT is(
  (
    SELECT replay.id
    FROM public.remove_and_seal_media_card(
      (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
      120,
      'B2-SEAL-HAPPY',
      'sealed intact'
    ) replay
  ),
  (
    SELECT removal.id
    FROM b2_happy_removal removal
  ),
  'exact authorized replay returns the original immutable removal evidence'
);


-- 40
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
    121,
    'B2-SEAL-HAPPY',
    'sealed intact'
  )
  $$,
  '23505',
  'remove_and_seal_media_card: existing removal evidence does not match replay',
  'conflicting replay is rejected without replacing immutable removal evidence'
);

-- =====================================================================
-- Part 5 - Audit / immutability / seal collision / multi-card gate
-- =====================================================================

-- 41
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.audit_events event
    JOIN b2_happy_removal removal
      ON event.entity_id =
         removal.id
    WHERE event.organization_id =
          removal.organization_id
      AND event.action_key =
          'media.card_removed_and_sealed'
      AND event.entity_type =
          'media_card_removal'
      AND event.actor_member_id =
          'b2000000-0000-0000-0000-000000000102'::uuid
      AND NOT event.is_sensitive
      AND event.old_values IS NULL
      AND event.new_values IS NULL
      AND event.source =
          'application'
      AND event.request_id IS NULL
  ),
  1::bigint,
  'first successful removal emits exactly one frozen structural audit event'
);


-- 42
SELECT is(
  (
    SELECT array_agg(
      metadata_key
      ORDER BY metadata_key
    )
    FROM public.audit_events event
    CROSS JOIN LATERAL jsonb_object_keys(
      event.metadata
    ) metadata_key
    JOIN b2_happy_removal removal
      ON event.entity_id =
         removal.id
    WHERE event.action_key =
          'media.card_removed_and_sealed'
      AND event.entity_type =
          'media_card_removal'
  ),
  ARRAY[
    'booking_id',
    'capture_device_id',
    'custodian_member_id',
    'media_card_assignment_id',
    'media_card_id',
    'media_card_removal_id',
    'organization_id',
    'removed_by'
  ]::text[],
  'removal audit metadata contains only the frozen IDs-only provenance surface'
);


-- 43
SELECT throws_ok(
  $$
  UPDATE public.media_card_removals
  SET expected_file_count =
      expected_file_count + 1
  WHERE id =
    (SELECT id FROM b2_happy_removal)
  $$,
  'P0001',
  'media card removal evidence is immutable',
  'privileged UPDATE cannot rewrite immutable removal evidence'
);


-- 44
SELECT throws_ok(
  $$
  DELETE FROM public.media_card_removals
  WHERE id =
    (SELECT id FROM b2_happy_removal)
  $$,
  'P0001',
  'media card removal evidence cannot be deleted',
  'privileged DELETE cannot erase immutable removal evidence'
);


-- 45
SELECT throws_ok(
  $$
  UPDATE public.media_card_assignments
  SET
    ended_at = NULL,
    ended_by = NULL
  WHERE id =
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy')
  $$,
  'P0001',
  'media card assignment evidence is immutable except controlled removal closure',
  'closed B1 assignment cannot be reopened after B2 removal'
);


-- 46
SELECT throws_ok(
  $$
  UPDATE public.media_card_assignments
  SET ended_at =
      ended_at + interval '1 second'
  WHERE id =
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy')
  $$,
  'P0001',
  'media card assignment evidence is immutable except controlled removal closure',
  'closed B1 assignment cannot be reclosed with a different timestamp'
);


-- 47
SELECT throws_ok(
  $$
  DELETE FROM public.media_card_assignments
  WHERE id =
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy')
  $$,
  'P0001',
  'media card assignment evidence cannot be deleted',
  'privileged DELETE cannot erase B1 assignment history'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


-- 48
SELECT throws_ok(
  $$
  SELECT public.remove_and_seal_media_card(
    (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'custody'),
    90,
    'B2-SEAL-HAPPY',
    'sealed intact'
  )
  $$,
  '23505',
  'remove_and_seal_media_card: seal_id already used in organization',
  'organization-unique seal identity prevents reuse on another assignment'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);


-- 49
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT gate_booking_id FROM b2_booking_ids)
  )
  $$,
  '22023',
  'mark_booking_shoot_completed: all media card assignments must be removed and sealed',
  'Stage 10 -> 11 is blocked while the booking has active media-card custody'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


CREATE TEMP TABLE b2_gate_a_removal AS
SELECT *
FROM public.remove_and_seal_media_card(
  (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'gate_a'),
  150,
  'B2-SEAL-GATE-A',
  'sealed intact'
);


-- 50
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.media_card_assignments assignment
    WHERE assignment.booking_id =
      (SELECT gate_booking_id FROM b2_booking_ids)
      AND assignment.ended_at IS NULL
  ),
  1::bigint,
  'removing one of two assigned cards leaves exactly one active custody assignment'
);

-- =====================================================================
-- Part 6 - Full custody closure / Stage 10 -> 11 / runtime RLS / replay
-- =====================================================================

SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);


-- 51
SELECT throws_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT gate_booking_id FROM b2_booking_ids)
  )
  $$,
  '22023',
  'mark_booking_shoot_completed: all media card assignments must be removed and sealed',
  'one remaining active card continues to block Stage 10 -> 11'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


CREATE TEMP TABLE b2_gate_b_removal AS
SELECT *
FROM public.remove_and_seal_media_card(
  (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'gate_b'),
  148,
  'B2-SEAL-GATE-B',
  'sealed intact'
);


-- 52
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.media_card_assignments assignment
    WHERE assignment.booking_id =
      (SELECT gate_booking_id FROM b2_booking_ids)
      AND assignment.ended_at IS NULL
  ),
  0::bigint,
  'removing the second card closes all active custody for the gate booking'
);


-- ---------------------------------------------------------------------
-- Privileged fixture helper for canonical immutable schedule evidence.
--
-- The scheduling relation requires version 1 proposed evidence followed
-- by version 2 reserved evidence. These fixture rows are established
-- before canonical shoot-completion evidence is recorded.
-- ---------------------------------------------------------------------

CREATE FUNCTION pg_temp.b2_fixture_reserved_schedule(
  p_booking_id uuid,
  p_day_offset integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_proposed public.booking_shoot_schedules;
  v_start timestamptz;
BEGIN
  v_start :=
    '2031-09-01 10:00:00+05:30'::timestamptz
    + make_interval(days => p_day_offset);

  INSERT INTO public.booking_shoot_schedules (
    organization_id,
    booking_id,
    schedule_version,
    predecessor_schedule_id,
    schedule_state,
    scheduled_start_at,
    scheduled_end_at,
    timezone,
    location_type,
    location_details,
    reschedule_reason,
    recorded_by
  )
  SELECT
    booking.organization_id,
    booking.id,
    1,
    NULL,
    'proposed',
    v_start,
    v_start + interval '2 hours',
    'Asia/Kolkata',
    'studio',
    'B2 media-card removal fixture',
    NULL,
    'b2000000-0000-0000-0000-000000000101'::uuid
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  RETURNING *
  INTO v_proposed;

  INSERT INTO public.booking_shoot_schedules (
    organization_id,
    booking_id,
    schedule_version,
    predecessor_schedule_id,
    schedule_state,
    scheduled_start_at,
    scheduled_end_at,
    timezone,
    location_type,
    location_details,
    reschedule_reason,
    recorded_by
  )
  VALUES (
    v_proposed.organization_id,
    v_proposed.booking_id,
    2,
    v_proposed.id,
    'reserved',
    v_proposed.scheduled_start_at,
    v_proposed.scheduled_end_at,
    v_proposed.timezone,
    v_proposed.location_type,
    v_proposed.location_details,
    NULL,
    'b2000000-0000-0000-0000-000000000101'::uuid
  );
END;
$$;


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);


SELECT pg_temp.b2_fixture_reserved_schedule(
  (SELECT gate_booking_id FROM b2_booking_ids),
  1
);

SELECT pg_temp.b2_fixture_reserved_schedule(
  (SELECT no_card_booking_id FROM b2_booking_ids),
  2
);

SELECT pg_temp.b2_fixture_reserved_schedule(
  (SELECT happy_booking_id FROM b2_booking_ids),
  3
);


-- Canonical shoot-completion evidence remains governed by the existing
-- shoot-completion authority and is recorded by the Photographer.
SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


SELECT public.record_booking_shoot_completion(
  (SELECT gate_booking_id FROM b2_booking_ids),
  now() - interval '45 minutes'
);

SELECT public.record_booking_shoot_completion(
  (SELECT no_card_booking_id FROM b2_booking_ids),
  now() - interval '40 minutes'
);

SELECT public.record_booking_shoot_completion(
  (SELECT happy_booking_id FROM b2_booking_ids),
  now() - interval '35 minutes'
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);


-- 53
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT gate_booking_id FROM b2_booking_ids)
  )
  $$,
  'Stage 10 -> 11 succeeds after every active media-card assignment is removed and sealed'
);


-- 54
SELECT is(
  (
    SELECT
      stage.stage_order::text
      || ':'
      || stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT gate_booking_id FROM b2_booking_ids)
  ),
  '11:shoot_completed'::text,
  'fully closed custody permits exact Stage 11 shoot_completed advancement'
);


-- ---------------------------------------------------------------------
-- Runtime RLS probes.
-- Branch-A Photographer has media.card.remove for Branch A.
-- Founder has booking authority but deliberately has no media.card.remove.
-- ---------------------------------------------------------------------

SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000004'::uuid
);

SET LOCAL ROLE authenticated;


-- 55
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.media_card_removals removal
    WHERE removal.seal_id =
          'B2-SEAL-HAPPY'
  ),
  1::bigint,
  'matching branch-scoped Photographer with media.card.remove may read removal evidence'
);


RESET ROLE;

SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);

SET LOCAL ROLE authenticated;


-- 56
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.media_card_removals removal
    WHERE removal.seal_id =
          'B2-SEAL-HAPPY'
  ),
  0::bigint,
  'Founder without media.card.remove cannot read removal evidence through booking authority alone'
);


RESET ROLE;


-- Zero media-card assignments remain valid. B2 introduces no rule that
-- a booking must have used a media card; it only requires all existing
-- assignments to be closed before first Stage 10 -> 11 success.

SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000001'::uuid
);


-- 57
SELECT lives_ok(
  $$
  SELECT public.mark_booking_shoot_completed(
    (SELECT no_card_booking_id FROM b2_booking_ids)
  )
  $$,
  'Stage 10 -> 11 continues to allow a booking with zero media-card assignments'
);


-- 58
SELECT is(
  (
    SELECT
      stage.stage_order::text
      || ':'
      || stage.stage_key
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT no_card_booking_id FROM b2_booking_ids)
  ),
  '11:shoot_completed'::text,
  'zero-card booking reaches exact Stage 11 without invented custody evidence'
);


-- Advance the already-removed happy booking so B2 can prove that exact
-- removal replay remains valid after the booking journey has moved on.
SELECT public.mark_booking_shoot_completed(
  (SELECT happy_booking_id FROM b2_booking_ids)
);


SELECT pg_temp.b2_set_actor(
  'b2000000-0000-0000-0000-000000000002'::uuid
);


-- 59
SELECT is(
  (
    SELECT replay.id
    FROM public.remove_and_seal_media_card(
      (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy'),
      120,
      'B2-SEAL-HAPPY',
      'sealed intact'
    ) replay
  ),
  (
    SELECT removal.id
    FROM b2_happy_removal removal
  ),
  'exact authorized removal replay returns original evidence after later journey advancement'
);


-- 60
SELECT ok(
  (
    SELECT count(*) = 1
    FROM public.media_card_removals removal
    WHERE removal.media_card_assignment_id =
      (SELECT media_card_assignment_id FROM b2_assignments WHERE label = 'happy')
  )
  AND
  (
    SELECT count(*) = 1
    FROM public.audit_events event
    WHERE event.action_key =
          'media.card_removed_and_sealed'
      AND event.entity_id =
        (SELECT id FROM b2_happy_removal)
  )
  AND
  (
    SELECT
      assignment.ended_at =
        removal.removed_at
      AND assignment.ended_by =
        removal.removed_by
    FROM public.media_card_assignments assignment
    JOIN b2_happy_removal removal
      ON removal.media_card_assignment_id =
         assignment.id
  )
  AND
  (
    SELECT stage.stage_order = 11
      AND stage.stage_key =
          'shoot_completed'
    FROM public.booking_journey_states state
    JOIN public.booking_journey_stages stage
      ON stage.organization_id =
         state.organization_id
     AND stage.id =
         state.current_stage_id
    WHERE state.booking_id =
      (SELECT happy_booking_id FROM b2_booking_ids)
  ),
  'later-stage replay creates no removal, audit, closure or journey mutation'
);


SELECT * FROM finish();

ROLLBACK;