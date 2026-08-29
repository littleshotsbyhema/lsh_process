CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(48);

-- =====================================================================
-- Phase 2 Studio Operations
-- Corrective Slice B1 - Media Card Assignment Authority
--
-- Proves:
--   * exact media.card.assign authority topology;
--   * exact eleven-column tenant-safe assignment relation;
--   * one-active-assignment-per-card and multi-card-per-device semantics;
--   * immutable B1 assignment evidence;
--   * forced RLS / narrow authenticated read authority;
--   * controlled authenticated assignment RPC;
--   * exact Stage 10 and current internal Lead Photographer authority;
--   * external Lead Photographer rejection;
--   * strict active replay and collision behavior;
--   * one first-success structural audit event;
--   * no later custody workflow authority.
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
  '71:246'::text,
  'canonical permission and role-mapping totals are exactly 71:246'
);


-- 2
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.permissions permission
    WHERE permission.key =
          'media.card.assign'
      AND permission.domain =
          'media'
      AND permission.label =
          'Assign media cards'
      AND permission.description =
          'Assign registered media cards to registered capture devices for the current booking Lead Photographer.'
      AND permission.requires_server_enforcement
  ),
  1::bigint,
  'media.card.assign exists exactly once with frozen media-domain contract'
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
          'media.card.assign'
  ),
  ARRAY[
    'photographer'
  ]::text[],
  'media.card.assign is granted only to Photographer'
);


-- 4
SELECT is(
  (
    SELECT array_agg(
      column_name || ':' || udt_name
      ORDER BY ordinal_position
    )
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name =
          'media_card_assignments'
  ),
  ARRAY[
    'id:uuid',
    'organization_id:uuid',
    'booking_id:uuid',
    'media_card_id:uuid',
    'capture_device_id:uuid',
    'lead_photographer_assignment_id:uuid',
    'custodian_member_id:uuid',
    'assigned_at:timestamptz',
    'assigned_by:uuid',
    'ended_at:timestamptz',
    'ended_by:uuid'
  ]::text[],
  'media_card_assignments contains exactly the frozen eleven-column typed contract'
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
          'public.media_card_assignments'::regclass
      AND constraint_row.conname =
          'media_card_assignments_booking_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, booking_id) REFERENCES bookings(organization_id, id)%',
  'assignment booking foreign key is tenant-safe'
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
          'public.media_card_assignments'::regclass
      AND constraint_row.conname =
          'media_card_assignments_media_card_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, media_card_id) REFERENCES media_cards(organization_id, id)%',
  'assignment media-card foreign key is tenant-safe'
);


-- 7
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
          'public.media_card_assignments'::regclass
      AND constraint_row.conname =
          'media_card_assignments_capture_device_fkey'
  ) LIKE
    'FOREIGN KEY (organization_id, capture_device_id) REFERENCES capture_devices(organization_id, id)%',
  'assignment capture-device foreign key is tenant-safe'
);


-- 8
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
          'public.media_card_assignments'::regclass
      AND constraint_row.conname =
          'media_card_assignments_lead_assignment_fkey'
  ) LIKE
    'FOREIGN KEY (lead_photographer_assignment_id, organization_id, booking_id) REFERENCES booking_team_assignments(id, organization_id, booking_id)%',
  'Lead Photographer assignment lineage is booking- and tenant-safe'
);


-- 9
SELECT ok(
  (
    SELECT count(*)
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.media_card_assignments'::regclass
      AND constraint_row.conname IN (
        'media_card_assignments_custodian_fkey',
        'media_card_assignments_assigned_by_fkey',
        'media_card_assignments_ended_by_fkey'
      )
      AND replace(
            pg_catalog.pg_get_constraintdef(
              constraint_row.oid
            ),
            'public.',
            ''
          ) LIKE
          '%REFERENCES organization_members(id, organization_id)%'
  ) = 3,
  'custodian, assigning actor and future ending actor all use tenant-safe member lineage'
);


-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_constraint constraint_row
    WHERE constraint_row.conrelid =
          'public.media_card_assignments'::regclass
      AND constraint_row.conname IN (
        'media_card_assignments_lifecycle_chk',
        'media_card_assignments_end_time_chk',
        'media_card_assignments_initial_custodian_chk',
        'media_card_assignments_id_org_booking_key'
      )
  ),
  4::bigint,
  'assignment lifecycle, initial custodian and future tenant-safe lineage constraints exist'
);


-- =====================================================================
-- Part 1B - Index / guard / RLS / ACL / RPC contract
-- =====================================================================

-- 11
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_indexes index_row
    WHERE index_row.schemaname =
          'public'
      AND index_row.tablename =
          'media_card_assignments'
      AND index_row.indexname =
          'media_card_assignments_active_card_uidx'
      AND index_row.indexdef ILIKE
          '%UNIQUE INDEX%'
      AND index_row.indexdef ILIKE
          '%organization_id%'
      AND index_row.indexdef ILIKE
          '%media_card_id%'
      AND index_row.indexdef ILIKE
          '%ended_at IS NULL%'
  ),
  'one active assignment per media card is enforced'
);


-- 12
SELECT is(
  (
    SELECT count(*)::bigint
    FROM pg_catalog.pg_indexes index_row
    WHERE index_row.schemaname =
          'public'
      AND index_row.tablename =
          'media_card_assignments'
      AND index_row.indexdef ILIKE
          '%UNIQUE INDEX%'
      AND index_row.indexdef ILIKE
          '%capture_device_id%'
  ),
  0::bigint,
  'capture devices are intentionally non-exclusive across active media cards'
);


-- 13
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger trigger_row
    WHERE trigger_row.tgrelid =
          'public.media_card_assignments'::regclass
      AND trigger_row.tgname =
          'media_card_assignments_guard'
      AND NOT trigger_row.tgisinternal
  )
  AND to_regprocedure(
        'public.lsh_media_card_assignment_guard()'
      ) IS NOT NULL,
  'B1 immutable assignment guard exists'
);


-- 14
SELECT ok(
  (
    SELECT
      relation.relrowsecurity
      AND relation.relforcerowsecurity
    FROM pg_catalog.pg_class relation
    WHERE relation.oid =
          'public.media_card_assignments'::regclass
  ),
  'media_card_assignments enables and forces RLS'
);


-- 15
SELECT ok(
  has_table_privilege(
    'authenticated',
    'public.media_card_assignments',
    'SELECT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.media_card_assignments',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.media_card_assignments',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.media_card_assignments',
    'DELETE'
  )
  AND NOT has_table_privilege(
    'anon',
    'public.media_card_assignments',
    'SELECT'
  ),
  'assignment relation grants authenticated SELECT only and exposes no anon access'
);


-- 16
SELECT ok(
  (
    SELECT
      lower(COALESCE(policy.qual, ''))
        LIKE '%media.card.assign%'
      AND lower(COALESCE(policy.qual, ''))
        LIKE '%current_organization_member%'
      AND lower(COALESCE(policy.qual, ''))
        LIKE '%has_permission%'
      AND lower(COALESCE(policy.qual, ''))
        LIKE '%has_branch_scope%'
      AND lower(COALESCE(policy.qual, ''))
        NOT LIKE '%booking.read%'
    FROM pg_catalog.pg_policies policy
    WHERE policy.schemaname =
          'public'
      AND policy.tablename =
          'media_card_assignments'
      AND policy.policyname =
          'media_card_assignments_authenticated_select'
      AND policy.cmd =
          'SELECT'
  ),
  'assignment read policy requires active membership and media.card.assign rather than booking.read'
);


-- 17
SELECT ok(
  to_regprocedure(
    'public.assign_media_card(uuid,uuid,uuid)'
  ) IS NOT NULL
  AND (
    SELECT pg_catalog.pg_get_function_result(
      procedure.oid
    )
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.assign_media_card(uuid,uuid,uuid)'::regprocedure
  ) = 'media_card_assignments',
  'assign_media_card(uuid,uuid,uuid) exists and returns media_card_assignments'
);


-- 18
SELECT ok(
  (
    SELECT count(*)
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.pronamespace =
          'public'::regnamespace
      AND procedure.proname =
          'assign_media_card'
  ) = 1
  AND (
    SELECT procedure.prosecdef
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.assign_media_card(uuid,uuid,uuid)'::regprocedure
  )
  AND (
    SELECT procedure.proconfig
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.assign_media_card(uuid,uuid,uuid)'::regprocedure
  ) = ARRAY['search_path=""']::text[],
  'assignment RPC has one SECURITY DEFINER signature with empty search_path'
);


-- 19
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.assign_media_card(uuid,uuid,uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.assign_media_card(uuid,uuid,uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'service_role',
    'public.assign_media_card(uuid,uuid,uuid)',
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
      'public.assign_media_card(uuid,uuid,uuid)'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type =
          'EXECUTE'
  ),
  'assignment RPC execution ACL is authenticated-only'
);


-- 20
SELECT ok(
  (
    SELECT
      pg_get_functiondef(procedure.oid)
        ILIKE '%current_organization_member%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%media.card.assign%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%stage_order <> 10%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%shoot_scheduled%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%lead_photographer%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%assigned_external_creative_id%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%append_audit_event%'
      AND pg_get_functiondef(procedure.oid)
        ILIKE '%media.card_assigned%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%INSERT INTO public.booking_stage_transitions%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%UPDATE public.booking_journey_states%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%seal_id%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%checksum%'
      AND pg_get_functiondef(procedure.oid)
        NOT ILIKE '%backup%'
    FROM pg_catalog.pg_proc procedure
    WHERE procedure.oid =
      'public.assign_media_card(uuid,uuid,uuid)'::regprocedure
  ),
  'assignment RPC contains frozen CUS-501 authority and imports no later custody workflow'
);


-- =====================================================================
-- Part 2 - Transaction-local actors / booking / inventory fixtures
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('b1000000-0000-0000-0000-000000000001'::uuid),
  ('b1000000-0000-0000-0000-000000000002'::uuid),
  ('b1000000-0000-0000-0000-000000000003'::uuid),
  ('b1000000-0000-0000-0000-000000000004'::uuid),
  ('b1000000-0000-0000-0000-000000000005'::uuid);


INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status
)
VALUES
(
  'b1000000-0000-0000-0000-000000000701'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B1 Media Assignment Branch A',
  'b1-media-a',
  'active'::public.branch_status
),
(
  'b1000000-0000-0000-0000-000000000702'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B1 Media Assignment Branch B',
  'b1-media-b',
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
  'b1000000-0000-0000-0000-000000000101'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-0000-0000-000000000001'::uuid,
  'active'::public.member_status,
  'B1 Founder',
  NULL
),
(
  'b1000000-0000-0000-0000-000000000102'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-0000-0000-000000000002'::uuid,
  'active'::public.member_status,
  'B1 Lead Photographer',
  NULL
),
(
  'b1000000-0000-0000-0000-000000000103'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-0000-0000-000000000003'::uuid,
  'active'::public.member_status,
  'B1 Other Photographer',
  NULL
),
(
  'b1000000-0000-0000-0000-000000000104'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-0000-0000-000000000004'::uuid,
  'suspended'::public.member_status,
  'B1 Suspended Photographer',
  now()
),
(
  'b1000000-0000-0000-0000-000000000105'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'b1000000-0000-0000-0000-000000000005'::uuid,
  'active'::public.member_status,
  'B1 Branch A Photographer',
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
      'b1000000-0000-0000-0000-000000000101'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      'b1000000-0000-0000-0000-000000000102'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      'b1000000-0000-0000-0000-000000000103'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      'b1000000-0000-0000-0000-000000000104'::uuid,
      'photographer'::text,
      NULL::uuid
    ),
    (
      'b1000000-0000-0000-0000-000000000105'::uuid,
      'photographer'::text,
      'b1000000-0000-0000-0000-000000000701'::uuid
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


CREATE FUNCTION pg_temp.b1_set_actor(
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


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000001'::uuid
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
  'b1000000-0000-0000-0000-000000000201'::uuid,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'LSH-45678D',
  'B1 Media Assignment Family',
  'B1 Media Assignment Family',
  'active',
  'b1000000-0000-0000-0000-000000000101'::uuid,
  'b1000000-0000-0000-0000-000000000101'::uuid
);


CREATE FUNCTION pg_temp.b1_create_booking(
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
    AND version.version_number = 1;

  SELECT *
  INTO v_quote
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
    'b1000000-0000-0000-0000-000000000201'::uuid,
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


CREATE FUNCTION pg_temp.b1_move_to_stage(
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
    'b1_fixture_' || p_stage_key,
    now(),
    'b1000000-0000-0000-0000-000000000101'::uuid
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
      'b1000000-0000-0000-0000-000000000101'::uuid
  WHERE state.organization_id =
        v_state.organization_id
    AND state.booking_id =
        v_state.booking_id;
END;
$$;


CREATE TEMP TABLE b1_booking_ids (
  happy_booking_id uuid,
  stage9_booking_id uuid,
  external_booking_id uuid,
  collision_booking_id uuid,
  cross_branch_booking_id uuid
);


INSERT INTO b1_booking_ids
VALUES (
  pg_temp.b1_create_booking(
    'b1000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b1_create_booking(
    'b1000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b1_create_booking(
    'b1000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b1_create_booking(
    'b1000000-0000-0000-0000-000000000701'::uuid
  ),
  pg_temp.b1_create_booking(
    'b1000000-0000-0000-0000-000000000702'::uuid
  )
);


-- Enter the canonical staffing window before creating team assignments.
SELECT pg_temp.b1_move_to_stage(
  happy_booking_id,
  8,
  'booking_confirmed'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  stage9_booking_id,
  8,
  'booking_confirmed'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  external_booking_id,
  8,
  'booking_confirmed'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  collision_booking_id,
  8,
  'booking_confirmed'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  cross_branch_booking_id,
  8,
  'booking_confirmed'
)
FROM b1_booking_ids;


-- Canonical internal Lead Photographer assignments while bookings are
-- still inside the existing Stage 8-10 staffing window.
SELECT public.assign_booking_team_member(
  happy_booking_id,
  'lead_photographer',
  'b1000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b1_booking_ids;

SELECT public.assign_booking_team_member(
  stage9_booking_id,
  'lead_photographer',
  'b1000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b1_booking_ids;

SELECT public.assign_booking_team_member(
  collision_booking_id,
  'lead_photographer',
  'b1000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b1_booking_ids;

SELECT public.assign_booking_team_member(
  cross_branch_booking_id,
  'lead_photographer',
  'b1000000-0000-0000-0000-000000000102'::uuid,
  true,
  NULL
)
FROM b1_booking_ids;


-- Canonical external creative + external Lead Photographer assignment.
CREATE TEMP TABLE b1_external_creative AS
SELECT
  external.id AS external_creative_id
FROM public.create_external_creative(
  (SELECT external_booking_id FROM b1_booking_ids),
  'B1 External Lead Photographer'
) external;


SELECT public.assign_booking_external_creative(
  booking.external_booking_id,
  'lead_photographer',
  external.external_creative_id,
  true,
  NULL
)
FROM b1_booking_ids booking
CROSS JOIN b1_external_creative external;


-- Exact source-stage fixtures.
SELECT pg_temp.b1_move_to_stage(
  happy_booking_id,
  10,
  'shoot_scheduled'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  stage9_booking_id,
  9,
  'pre_shoot_preparation'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  external_booking_id,
  10,
  'shoot_scheduled'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  collision_booking_id,
  10,
  'shoot_scheduled'
)
FROM b1_booking_ids;

SELECT pg_temp.b1_move_to_stage(
  cross_branch_booking_id,
  10,
  'shoot_scheduled'
)
FROM b1_booking_ids;


-- Canonical registered inventory identities.
CREATE TEMP TABLE b1_inventory (
  label text PRIMARY KEY,
  media_card_id uuid,
  capture_device_id uuid
);


INSERT INTO b1_inventory (
  label,
  media_card_id
)
SELECT
  'card_1',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B1-CARD-001'
) card;


INSERT INTO b1_inventory (
  label,
  media_card_id
)
SELECT
  'card_2',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B1-CARD-002'
) card;


INSERT INTO b1_inventory (
  label,
  media_card_id
)
SELECT
  'card_3',
  card.id
FROM public.register_media_card(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B1-CARD-003'
) card;


INSERT INTO b1_inventory (
  label,
  capture_device_id
)
SELECT
  'device_1',
  device.id
FROM public.register_capture_device(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B1-CAM-001'
) device;


INSERT INTO b1_inventory (
  label,
  capture_device_id
)
SELECT
  'device_2',
  device.id
FROM public.register_capture_device(
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  'B1-CAM-002'
) device;


-- =====================================================================
-- Part 3 - Input / actor / stage / lead authorization
-- =====================================================================

SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000002'::uuid
);


-- 21
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    NULL,
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '22023',
  'assign_media_card: booking_id is required',
  'null booking id is rejected'
);


-- 22
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    NULL,
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '22023',
  'assign_media_card: media_card_id is required',
  'null media-card id is rejected'
);


-- 23
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    NULL
  )
  $$,
  '22023',
  'assign_media_card: capture_device_id is required',
  'null capture-device id is rejected'
);


SELECT pg_temp.b1_set_actor(NULL);


-- 24
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '42501',
  'assign_media_card: authenticated actor required',
  'unauthenticated assignment is rejected'
);


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000002'::uuid
);


-- 25
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    'b1ffffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '22023',
  'assign_media_card: booking not found',
  'missing booking is rejected'
);


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000004'::uuid
);


-- 26
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '42501',
  'assign_media_card: active organization membership required',
  'suspended Photographer cannot create assignment evidence'
);


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000001'::uuid
);


-- 27
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '42501',
  'assign_media_card: media.card.assign permission required',
  'Founder does not inherit media.card.assign authority'
);


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000005'::uuid
);


-- 28
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT cross_branch_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '42501',
  'assign_media_card: media.card.assign permission required',
  'branch-scoped Photographer cannot assign for a different branch'
);


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000002'::uuid
);


-- 29
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT stage9_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '22023',
  'assign_media_card: booking must be at active Stage 10 shoot_scheduled',
  'Stage 9 booking is rejected'
);


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000003'::uuid
);


-- 30
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '42501',
  'assign_media_card: current internal Lead Photographer required',
  'Photographer permission alone is insufficient without current Lead Photographer identity'
);


-- =====================================================================
-- Part 4 - Successful assignment / replay / collision behavior
-- =====================================================================

-- Snapshot all authoritative surfaces B1 is forbidden to mutate.
CREATE TEMP TABLE b1_operation_baseline AS
SELECT
  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(booking)
        ORDER BY booking.id
      ),
      '[]'::jsonb
    )
    FROM public.bookings booking
  ) AS bookings_snapshot,

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(state)
        ORDER BY state.booking_id
      ),
      '[]'::jsonb
    )
    FROM public.booking_journey_states state
  ) AS journey_snapshot,

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(transition)
        ORDER BY transition.id
      ),
      '[]'::jsonb
    )
    FROM public.booking_stage_transitions transition
  ) AS transition_snapshot,

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(assignment)
        ORDER BY assignment.id
      ),
      '[]'::jsonb
    )
    FROM public.booking_team_assignments assignment
  ) AS team_snapshot,

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(card)
        ORDER BY card.id
      ),
      '[]'::jsonb
    )
    FROM public.media_cards card
  ) AS cards_snapshot,

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(device)
        ORDER BY device.id
      ),
      '[]'::jsonb
    )
    FROM public.capture_devices device
  ) AS devices_snapshot;


SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000002'::uuid
);


-- 31
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT external_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '42501',
  'assign_media_card: external Lead Photographer cannot create authenticated media-card custody evidence',
  'external Lead Photographer is rejected from authenticated B1 custody authority'
);


-- 32
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    'b1ffffff-ffff-ffff-ffff-ffffffffff01'::uuid,
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '22023',
  'assign_media_card: registered media card unavailable in booking organization',
  'unregistered media card is rejected'
);


-- 33
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    'b1ffffff-ffff-ffff-ffff-ffffffffff02'::uuid
  )
  $$,
  '22023',
  'assign_media_card: registered capture device unavailable in booking organization',
  'unregistered capture device is rejected'
);


CREATE TEMP TABLE b1_assignment_results (
  label text PRIMARY KEY,
  id uuid NOT NULL,
  organization_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  media_card_id uuid NOT NULL,
  capture_device_id uuid NOT NULL,
  lead_photographer_assignment_id uuid NOT NULL,
  custodian_member_id uuid NOT NULL,
  assigned_at timestamptz NOT NULL,
  assigned_by uuid NOT NULL,
  ended_at timestamptz,
  ended_by uuid
);


INSERT INTO b1_assignment_results
SELECT
  'first',
  assignment.*
FROM public.assign_media_card(
  (SELECT happy_booking_id FROM b1_booking_ids),
  (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
  (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
) assignment;


-- 34
SELECT ok(
  (
    SELECT
      result.organization_id =
        '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND result.booking_id =
        booking.happy_booking_id
      AND result.media_card_id =
        card.media_card_id
      AND result.capture_device_id =
        device.capture_device_id
      AND result.custodian_member_id =
        'b1000000-0000-0000-0000-000000000102'::uuid
      AND result.assigned_by =
        'b1000000-0000-0000-0000-000000000102'::uuid
      AND result.assigned_at IS NOT NULL
      AND result.ended_at IS NULL
      AND result.ended_by IS NULL
    FROM b1_assignment_results result
    CROSS JOIN b1_booking_ids booking
    CROSS JOIN b1_inventory card
    CROSS JOIN b1_inventory device
    WHERE result.label = 'first'
      AND card.label = 'card_1'
      AND device.label = 'device_1'
  ),
  'first success creates exact active assignment and initial custody attribution'
);


-- 35
SELECT ok(
  (
    SELECT
      result.lead_photographer_assignment_id =
        lead.id
    FROM b1_assignment_results result
    JOIN public.booking_team_assignments lead
      ON lead.organization_id =
         result.organization_id
     AND lead.booking_id =
         result.booking_id
     AND lead.assignment_role =
         'lead_photographer'
     AND lead.assigned_member_id =
         'b1000000-0000-0000-0000-000000000102'::uuid
     AND lead.assigned_external_creative_id
         IS NULL
     AND lead.ended_at IS NULL
    WHERE result.label =
          'first'
  )
  AND (
    SELECT count(*) = 1
    FROM public.media_card_assignments assignment
    JOIN b1_assignment_results result
      ON result.id =
         assignment.id
    WHERE result.label =
          'first'
  ),
  'first success pins the exact current internal Lead Photographer assignment'
);


-- Strict replay under the same still-authorized current Lead Photographer.
INSERT INTO b1_assignment_results
SELECT
  'replay',
  assignment.*
FROM public.assign_media_card(
  (SELECT happy_booking_id FROM b1_booking_ids),
  (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
  (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
) assignment;


-- 36
SELECT ok(
  (
    SELECT
      replay.id =
        original.id
      AND replay.organization_id =
        original.organization_id
      AND replay.booking_id =
        original.booking_id
      AND replay.media_card_id =
        original.media_card_id
      AND replay.capture_device_id =
        original.capture_device_id
      AND replay.lead_photographer_assignment_id =
        original.lead_photographer_assignment_id
      AND replay.custodian_member_id =
        original.custodian_member_id
      AND replay.assigned_at =
        original.assigned_at
      AND replay.assigned_by =
        original.assigned_by
      AND replay.ended_at IS NOT DISTINCT FROM
          original.ended_at
      AND replay.ended_by IS NOT DISTINCT FROM
          original.ended_by
    FROM b1_assignment_results replay
    CROSS JOIN b1_assignment_results original
    WHERE replay.label =
          'replay'
      AND original.label =
          'first'
  )
  AND (
    SELECT count(*) = 1
    FROM public.media_card_assignments assignment
    WHERE assignment.media_card_id = (
      SELECT media_card_id
      FROM b1_inventory
      WHERE label =
            'card_1'
    )
      AND assignment.ended_at IS NULL
  ),
  'strict replay returns the original assignment without creating another row'
);


-- 37
SELECT ok(
  (
    SELECT
      count(*) = 1
      AND bool_and(
        audit.organization_id =
          result.organization_id
      )
      AND bool_and(
        audit.branch_id =
          'b1000000-0000-0000-0000-000000000701'::uuid
      )
      AND bool_and(
        audit.actor_member_id =
          'b1000000-0000-0000-0000-000000000102'::uuid
      )
      AND bool_and(
        audit.actor_user_id =
          'b1000000-0000-0000-0000-000000000002'::uuid
      )
      AND bool_and(
        NOT audit.is_sensitive
      )
      AND bool_and(
        audit.old_values IS NULL
      )
      AND bool_and(
        audit.new_values IS NULL
      )
      AND bool_and(
        audit.source =
          'application'
      )
      AND bool_and(
        audit.request_id IS NULL
      )
      AND bool_and(
        audit.metadata =
        jsonb_build_object(
          'organization_id',
            result.organization_id,
          'booking_id',
            result.booking_id,
          'media_card_assignment_id',
            result.id,
          'media_card_id',
            result.media_card_id,
          'capture_device_id',
            result.capture_device_id,
          'lead_photographer_assignment_id',
            result.lead_photographer_assignment_id,
          'custodian_member_id',
            result.custodian_member_id,
          'assigned_by',
            result.assigned_by
        )
      )
      AND bool_and(
        NOT audit.metadata ? 'card_code'
      )
      AND bool_and(
        NOT audit.metadata ? 'device_code'
      )
    FROM public.audit_events audit
    CROSS JOIN b1_assignment_results result
    WHERE result.label =
          'first'
      AND audit.entity_id =
          result.id
      AND audit.entity_type =
          'media_card_assignment'
      AND audit.action_key =
          'media.card_assigned'
  ),
  'first success emits exactly one structural audit and strict replay emits no duplicate audit'
);


-- 38
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_2')
  )
  $$,
  '23505',
  'assign_media_card: media card already has a different active assignment',
  'same card cannot be rebound to a different capture device while active'
);


-- 39
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT collision_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '23505',
  'assign_media_card: media card already has a different active assignment',
  'same active card cannot be claimed by a different booking'
);


INSERT INTO b1_assignment_results
SELECT
  'second_card_same_device',
  assignment.*
FROM public.assign_media_card(
  (SELECT happy_booking_id FROM b1_booking_ids),
  (SELECT media_card_id FROM b1_inventory WHERE label = 'card_2'),
  (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
) assignment;


-- 40
SELECT ok(
  (
    SELECT
      result.booking_id =
        booking.happy_booking_id
      AND result.media_card_id =
        card.media_card_id
      AND result.capture_device_id =
        device.capture_device_id
      AND result.assigned_by =
        'b1000000-0000-0000-0000-000000000102'::uuid
      AND result.ended_at IS NULL
      AND result.ended_by IS NULL
    FROM b1_assignment_results result
    CROSS JOIN b1_booking_ids booking
    CROSS JOIN b1_inventory card
    CROSS JOIN b1_inventory device
    WHERE result.label =
          'second_card_same_device'
      AND card.label =
          'card_2'
      AND device.label =
          'device_1'
  ),
  'second registered card may be assigned to the same capture device'
);


-- 41
SELECT ok(
  (
    SELECT
      count(*) = 2
      AND count(DISTINCT assignment.media_card_id) = 2
      AND count(DISTINCT assignment.capture_device_id) = 1
    FROM public.media_card_assignments assignment
    WHERE assignment.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND assignment.booking_id = (
        SELECT happy_booking_id
        FROM b1_booking_ids
      )
      AND assignment.capture_device_id = (
        SELECT capture_device_id
        FROM b1_inventory
        WHERE label =
              'device_1'
      )
      AND assignment.ended_at IS NULL
  ),
  'one capture device may hold multiple simultaneously active media cards'
);


-- =====================================================================
-- Part 5 - Authorization-first replay / RLS / mutation guards
-- =====================================================================

-- Authorization is re-evaluated before active-assignment replay.
SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000003'::uuid
);


-- 42
SELECT throws_ok(
  $$
  SELECT public.assign_media_card(
    (SELECT happy_booking_id FROM b1_booking_ids),
    (SELECT media_card_id FROM b1_inventory WHERE label = 'card_1'),
    (SELECT capture_device_id FROM b1_inventory WHERE label = 'device_1')
  )
  $$,
  '42501',
  'assign_media_card: current internal Lead Photographer required',
  'strict replay is authorization-first and rejects a different Photographer'
);


-- Runtime RLS: branch-scoped Photographer with media.card.assign may read
-- assignment evidence for the matching branch.
SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000005'::uuid
);

-- The authenticated role needs read access only to this transaction-local
-- test fixture so the RLS assertions can resolve their booking id.
GRANT SELECT
ON TABLE b1_booking_ids
TO authenticated;

SET LOCAL ROLE authenticated;

-- 43
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.media_card_assignments assignment
    WHERE assignment.booking_id = (
      SELECT happy_booking_id
      FROM b1_booking_ids
    )
  ),
  2::bigint,
  'matching branch-scoped Photographer may read B1 assignment evidence'
);


RESET ROLE;

SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000001'::uuid
);

SET LOCAL ROLE authenticated;


-- 44
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.media_card_assignments assignment
    WHERE assignment.booking_id = (
      SELECT happy_booking_id
      FROM b1_booking_ids
    )
  ),
  0::bigint,
  'Founder without media.card.assign cannot read B1 assignment evidence'
);


RESET ROLE;

SELECT pg_temp.b1_set_actor(
  'b1000000-0000-0000-0000-000000000002'::uuid
);

SET LOCAL ROLE authenticated;


-- 45
SELECT throws_ok(
  $$
  INSERT INTO public.media_card_assignments
  DEFAULT VALUES
  $$,
  '42501',
  'permission denied for table media_card_assignments',
  'authenticated actor cannot directly INSERT assignment evidence'
);


-- 46
SELECT throws_ok(
  $$
  UPDATE public.media_card_assignments
  SET assigned_at =
      assigned_at
  WHERE false
  $$,
  '42501',
  'permission denied for table media_card_assignments',
  'authenticated actor cannot directly UPDATE assignment evidence'
);


-- 47
SELECT throws_ok(
  $$
  DELETE FROM public.media_card_assignments
  WHERE false
  $$,
  '42501',
  'permission denied for table media_card_assignments',
  'authenticated actor cannot directly DELETE assignment evidence'
);


RESET ROLE;


-- Privileged mutation probes prove the trigger remains a backstop even
-- where table ACL/RLS is not the rejecting layer.

CREATE FUNCTION pg_temp.b1_capture_owner_update(
  p_assignment_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.media_card_assignments
  SET capture_device_id =
      capture_device_id
  WHERE id =
        p_assignment_id;

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


CREATE FUNCTION pg_temp.b1_capture_owner_delete(
  p_assignment_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM public.media_card_assignments
  WHERE id =
        p_assignment_id;

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


CREATE FUNCTION pg_temp.b1_capture_owner_closed_insert(
  p_assignment_id uuid
)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.media_card_assignments (
    organization_id,
    booking_id,
    media_card_id,
    capture_device_id,
    lead_photographer_assignment_id,
    custodian_member_id,
    assigned_at,
    assigned_by,
    ended_at,
    ended_by
  )
  SELECT
    assignment.organization_id,
    assignment.booking_id,
    assignment.media_card_id,
    assignment.capture_device_id,
    assignment.lead_photographer_assignment_id,
    assignment.custodian_member_id,
    now() - interval '1 minute',
    assignment.assigned_by,
    now(),
    assignment.assigned_by
  FROM public.media_card_assignments assignment
  WHERE assignment.id =
        p_assignment_id;

  RETURN 'NO_ERROR';
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
END;
$$;


-- 48
SELECT ok(
  pg_temp.b1_capture_owner_update(
    (
      SELECT id
      FROM b1_assignment_results
      WHERE label =
            'first'
    )
  ) =
    'P0001:media card assignment evidence is immutable during B1'

  AND

  pg_temp.b1_capture_owner_delete(
    (
      SELECT id
      FROM b1_assignment_results
      WHERE label =
            'first'
    )
  ) =
    'P0001:media card assignment evidence cannot be deleted'

  AND

  pg_temp.b1_capture_owner_closed_insert(
    (
      SELECT id
      FROM b1_assignment_results
      WHERE label =
            'first'
    )
  ) =
    'P0001:media card assignment must be inserted as active'

  AND

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(booking)
        ORDER BY booking.id
      ),
      '[]'::jsonb
    )
    FROM public.bookings booking
  ) =
  (
    SELECT bookings_snapshot
    FROM b1_operation_baseline
  )

  AND

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(state)
        ORDER BY state.booking_id
      ),
      '[]'::jsonb
    )
    FROM public.booking_journey_states state
  ) =
  (
    SELECT journey_snapshot
    FROM b1_operation_baseline
  )

  AND

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(transition)
        ORDER BY transition.id
      ),
      '[]'::jsonb
    )
    FROM public.booking_stage_transitions transition
  ) =
  (
    SELECT transition_snapshot
    FROM b1_operation_baseline
  )

  AND

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(assignment)
        ORDER BY assignment.id
      ),
      '[]'::jsonb
    )
    FROM public.booking_team_assignments assignment
  ) =
  (
    SELECT team_snapshot
    FROM b1_operation_baseline
  )

  AND

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(card)
        ORDER BY card.id
      ),
      '[]'::jsonb
    )
    FROM public.media_cards card
  ) =
  (
    SELECT cards_snapshot
    FROM b1_operation_baseline
  )

  AND

  (
    SELECT COALESCE(
      jsonb_agg(
        to_jsonb(device)
        ORDER BY device.id
      ),
      '[]'::jsonb
    )
    FROM public.capture_devices device
  ) =
  (
    SELECT devices_snapshot
    FROM b1_operation_baseline
  ),

  'privileged guard blocks forbidden mutation and B1 changes only assignment/audit evidence'
);


SELECT * FROM finish();

ROLLBACK;
