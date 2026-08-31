CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(42);

-- =====================================================================
-- Part 1 — Candidate-directory structural / security contract
-- =====================================================================

-- 1
SELECT ok(
  to_regprocedure(
    'public.get_booking_team_assignment_candidates(uuid)'
  ) IS NOT NULL
  AND to_regprocedure(
    'public.assign_booking_team_member(uuid,text,uuid,boolean,text)'
  ) IS NOT NULL
  AND to_regprocedure(
    'public.assign_booking_external_creative(uuid,text,uuid,boolean,text)'
  ) IS NOT NULL
  AND to_regprocedure(
    'public.create_external_creative(uuid,text)'
  ) IS NOT NULL,
  'candidate directory RPC exists alongside unchanged canonical mutation RPC signatures'
);

-- 2
SELECT is(
  (
    SELECT format_type(
             procedure_row.proargtypes[0],
             NULL
           )
    FROM pg_proc procedure_row
    WHERE procedure_row.oid =
          'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
  ),
  'uuid'::text,
  'candidate RPC exposes exactly the frozen logical signature'
);

-- 3
SELECT is(
  (
    SELECT array_agg(
             procedure_row.proargnames[position]
             ORDER BY position
           )
    FROM pg_proc procedure_row
    CROSS JOIN LATERAL
      generate_subscripts(
        procedure_row.proallargtypes,
        1
      ) AS argument(position)
    WHERE procedure_row.oid =
          'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
      AND procedure_row.proargmodes[position]
          IN ('o', 't')
  ),
  ARRAY[
    'subject_type',
    'subject_id',
    'subject_display_name',
    'eligible_assignment_roles',
    'roles_requiring_change_reason'
  ]::text[],
  'candidate RPC exposes exactly the amended five-column return projection'
);

-- 4
SELECT is(
  (
    SELECT array_agg(
             format_type(
               procedure_row.proallargtypes[position],
               NULL
             )
             ORDER BY position
           )
    FROM pg_proc procedure_row
    CROSS JOIN LATERAL
      generate_subscripts(
        procedure_row.proallargtypes,
        1
      ) AS argument(position)
    WHERE procedure_row.oid =
          'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
      AND procedure_row.proargmodes[position]
          IN ('o', 't')
  ),
  ARRAY[
    'text',
    'uuid',
    'text',
    'text[]',
    'text[]'
  ]::text[],
  'candidate RPC exposes exactly the frozen return-column types'
);

-- 5
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc procedure_row
    WHERE procedure_row.oid =
          'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
      AND procedure_row.prosecdef
  ),
  'candidate RPC is SECURITY DEFINER'
);

-- 6
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc procedure_row
    WHERE procedure_row.oid =
          'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
      AND procedure_row.provolatile = 's'
  ),
  'candidate RPC is STABLE'
);

-- 7
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc procedure_row
    WHERE procedure_row.oid =
          'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
      AND 'search_path=""' =
          ANY(
            COALESCE(
              procedure_row.proconfig,
              ARRAY[]::text[]
            )
          )
  ),
  'candidate RPC uses empty search_path'
);

-- 8
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.get_booking_team_assignment_candidates(uuid)',
    'EXECUTE'
  ),
  'candidate RPC is executable by authenticated'
);

-- 9
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.get_booking_team_assignment_candidates(uuid)',
    'EXECUTE'
  ),
  'candidate RPC remains unavailable to anon'
);

-- =====================================================================
-- Part 2 — Transaction-local identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('8b000000-0000-0000-0000-000000000001'),
  ('8b000000-0000-0000-0000-000000000002'),
  ('8b000000-0000-0000-0000-000000000003'),
  ('8b000000-0000-0000-0000-000000000004'),
  ('8b000000-0000-0000-0000-000000000005'),
  ('8b000000-0000-0000-0000-000000000006'),
  ('8b000000-0000-0000-0000-000000000007'),
  ('8b000000-0000-0000-0000-000000000008'),
  ('8b000000-0000-0000-0000-000000000009'),
  ('8b000000-0000-0000-0000-000000000010'),
  ('8b000000-0000-0000-0000-000000000011'),
  ('8b000000-0000-0000-0000-000000000012'),
  ('8b000000-0000-0000-0000-000000000013');

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '8b100000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000001',
  'active',
  'S10 7M Founder'
),
(
  '8b100000-0000-0000-0000-000000000002',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000002',
  'active',
  'S10 7M Photographer'
),
(
  '8b100000-0000-0000-0000-000000000003',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000003',
  'active',
  'S10 7M Assistant'
),
(
  '8b100000-0000-0000-0000-000000000004',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000004',
  'active',
  'S10 7M Stylist'
),
(
  '8b100000-0000-0000-0000-000000000005',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000005',
  'active',
  'S10 7M Videographer'
),
(
  '8b100000-0000-0000-0000-000000000006',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000006',
  'active',
  'S10 7M Multi Role Member'
),
(
  '8b100000-0000-0000-0000-000000000007',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000007',
  'active',
  'S10 7M Inactive Member'
),
(
  '8b100000-0000-0000-0000-000000000008',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000008',
  'active',
  'S10 7M No Permission Actor'
),
(
  '8b100000-0000-0000-0000-000000000009',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000009',
  'active',
  'S10 7M Branch A Member'
),
(
  '8b100000-0000-0000-0000-000000000010',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000010',
  'active',
  'S10 7M Branch B Member'
);

UPDATE public.organization_members
SET
  status =
    'suspended'::public.member_status,
  suspended_at =
    now(),
  suspended_by =
    '8b100000-0000-0000-0000-000000000001'
WHERE id =
      '8b100000-0000-0000-0000-000000000007';

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  fixture.member_id,
  role_row.id,
  NULL
FROM (
  VALUES
    ('8b100000-0000-0000-0000-000000000001'::uuid, 'founder'::text),
    ('8b100000-0000-0000-0000-000000000002'::uuid, 'photographer'),
    ('8b100000-0000-0000-0000-000000000003'::uuid, 'assistant'),
    ('8b100000-0000-0000-0000-000000000004'::uuid, 'stylist'),
    ('8b100000-0000-0000-0000-000000000005'::uuid, 'videographer'),
    ('8b100000-0000-0000-0000-000000000006'::uuid, 'photographer'),
    ('8b100000-0000-0000-0000-000000000006'::uuid, 'videographer'),
    ('8b100000-0000-0000-0000-000000000007'::uuid, 'photographer'),
    ('8b100000-0000-0000-0000-000000000008'::uuid, 'photographer')
) AS fixture(member_id, role_key)
JOIN public.roles role_row
  ON role_row.key =
     fixture.role_key;

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc';

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

INSERT INTO public.branches (
  id,
  organization_id,
  name,
  code,
  status,
  country_code,
  created_by,
  updated_by
)
VALUES
(
  '8b200000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 7M Branch A',
  's10m7ma',
  'active',
  'IN',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b200000-0000-0000-0000-000000000002',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 7M Branch B',
  's10m7mb',
  'active',
  'IN',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  fixture.member_id,
  role_row.id,
  fixture.branch_id
FROM (
  VALUES
    (
      '8b100000-0000-0000-0000-000000000009'::uuid,
      '8b200000-0000-0000-0000-000000000001'::uuid,
      'client_coordinator'::text
    ),
    (
      '8b100000-0000-0000-0000-000000000010'::uuid,
      '8b200000-0000-0000-0000-000000000002'::uuid,
      'photographer'
    )
) AS fixture(member_id, branch_id, role_key)
JOIN public.roles role_row
  ON role_row.key =
     fixture.role_key;

INSERT INTO public.external_creatives (
  id,
  organization_id,
  display_name,
  created_by
)
VALUES (
  '8b300000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S10 7M External Creative',
  '8b100000-0000-0000-0000-000000000001'
);

INSERT INTO public.families (
  id,
  organization_id,
  branch_id,
  family_code,
  display_name,
  sort_name,
  status,
  created_by,
  updated_by
)
VALUES
(
  '8b400000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA23',
  'S10 7M Base Family',
  'S10 7M Base Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000002',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA24',
  'S10 7M Stage9 Family',
  'S10 7M Stage9 Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000003',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA25',
  'S10 7M Stage10 Family',
  'S10 7M Stage10 Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000004',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA26',
  'S10 7M PreStage8 Family',
  'S10 7M PreStage8 Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000005',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA27',
  'S10 7M PostStage10 Family',
  'S10 7M PostStage10 Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000006',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b200000-0000-0000-0000-000000000001',
  'QT-7MSA28',
  'S10 7M Branch A Family',
  'S10 7M Branch A Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000007',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b200000-0000-0000-0000-000000000002',
  'QT-7MSA29',
  'S10 7M Branch B Family',
  'S10 7M Branch B Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000008',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA32',
  'S10 7M CurrentLeadPhoto Family',
  'S10 7M CurrentLeadPhoto Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000009',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA34',
  'S10 7M CurrentLeadVideo Family',
  'S10 7M CurrentLeadVideo Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
),
(
  '8b400000-0000-0000-0000-000000000010',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-7MSA35',
  'S10 7M EndedLead Family',
  'S10 7M EndedLead Family',
  'active',
  '8b100000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000001'
);

-- =====================================================================
-- Part 3 — Canonical booking fixtures
-- =====================================================================

CREATE FUNCTION pg_temp.s10m_create_booking(
  p_family_id uuid,
  p_branch_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = ''
AS $function$
DECLARE
  v_quote_id           uuid;
  v_booking_id         uuid;
  v_package_version_id uuid;
BEGIN
  SELECT version_row.id
  INTO v_package_version_id
  FROM public.commercial_package_versions version_row
  JOIN public.commercial_packages package_row
    ON package_row.organization_id =
       version_row.organization_id
   AND package_row.id =
       version_row.package_id
  WHERE package_row.package_key =
        'maternity_gold'
    AND version_row.version_number = 1;

  SELECT quotation_row.id
  INTO v_quote_id
  FROM public.create_quotation(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    p_family_id,
    NULL,
    p_branch_id,
    NULL,
    NULL
  ) quotation_row;

  PERFORM public.add_quotation_package_line(
    v_quote_id,
    v_package_version_id,
    NULL
  );

  PERFORM public.transition_quotation(
    v_quote_id,
    'ready'::public.quotation_status
  );

  PERFORM public.transition_quotation(
    v_quote_id,
    'sent'::public.quotation_status
  );

  SELECT booking_row.id
  INTO v_booking_id
  FROM public.accept_quotation(
    v_quote_id
  ) booking_row;

  RETURN v_booking_id;
END
$function$;

CREATE TEMP TABLE s10m_bookings (
  fixture_key text PRIMARY KEY,
  id          uuid NOT NULL
);

INSERT INTO s10m_bookings (
  fixture_key,
  id
)
VALUES
(
  'stage8',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000001',
    NULL
  )
),
(
  'stage9',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000002',
    NULL
  )
),
(
  'stage10',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000003',
    NULL
  )
),
(
  'pre_stage8',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000004',
    NULL
  )
),
(
  'post_stage10',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000005',
    NULL
  )
),
(
  'branch_a',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000006',
    '8b200000-0000-0000-0000-000000000001'
  )
),
(
  'branch_b',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000007',
    '8b200000-0000-0000-0000-000000000002'
  )
),
(
  'current_lead_photo',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000008',
    NULL
  )
),
(
  'current_lead_video',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000009',
    NULL
  )
),
(
  'ended_lead',
  pg_temp.s10m_create_booking(
    '8b400000-0000-0000-0000-000000000010',
    NULL
  )
);

GRANT SELECT
ON s10m_bookings
TO authenticated, anon, service_role;

-- Advance every fixture booking except 'pre_stage8' to Stage 8 (Booking
-- Confirmed), then advance 'stage9'/'stage10' further, and 'post_stage10'
-- all the way past Stage 10, mirroring the manual stage-transition
-- pattern used by sprint10_booking_team_assignments_test.sql.

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10m_stage8',
  now(),
  '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_states state
JOIN s10m_bookings booking_fixture
  ON booking_fixture.id =
     state.booking_id
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key = 'booking_confirmed'
 AND target.stage_order = 8
 AND target.is_active
WHERE booking_fixture.fixture_key IN (
  'stage8', 'stage9', 'stage10', 'post_stage10',
  'branch_a', 'branch_b',
  'current_lead_photo', 'current_lead_video', 'ended_lead'
);

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_stages target
WHERE state.booking_id IN (
    SELECT id
    FROM s10m_bookings
    WHERE fixture_key IN (
      'stage8', 'stage9', 'stage10', 'post_stage10',
      'branch_a', 'branch_b',
      'current_lead_photo', 'current_lead_video', 'ended_lead'
    )
  )
  AND target.organization_id =
      state.organization_id
  AND target.stage_key = 'booking_confirmed'
  AND target.stage_order = 8
  AND target.is_active;

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10m_stage9',
  now(),
  '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_states state
JOIN s10m_bookings booking_fixture
  ON booking_fixture.id =
     state.booking_id
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key = 'pre_shoot_preparation'
 AND target.stage_order = 9
 AND target.is_active
WHERE booking_fixture.fixture_key IN ('stage9', 'stage10', 'post_stage10');

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_stages target
WHERE state.booking_id IN (
    SELECT id
    FROM s10m_bookings
    WHERE fixture_key IN ('stage9', 'stage10', 'post_stage10')
  )
  AND target.organization_id =
      state.organization_id
  AND target.stage_key = 'pre_shoot_preparation'
  AND target.stage_order = 9
  AND target.is_active;

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10m_stage10',
  now(),
  '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_states state
JOIN s10m_bookings booking_fixture
  ON booking_fixture.id =
     state.booking_id
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key = 'shoot_scheduled'
 AND target.stage_order = 10
 AND target.is_active
WHERE booking_fixture.fixture_key IN ('stage10', 'post_stage10');

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_stages target
WHERE state.booking_id IN (
    SELECT id
    FROM s10m_bookings
    WHERE fixture_key IN ('stage10', 'post_stage10')
  )
  AND target.organization_id =
      state.organization_id
  AND target.stage_key = 'shoot_scheduled'
  AND target.stage_order = 10
  AND target.is_active;

INSERT INTO public.booking_stage_transitions (
  organization_id,
  booking_id,
  from_stage_id,
  to_stage_id,
  transition_key,
  transitioned_at,
  transitioned_by
)
SELECT
  state.organization_id,
  state.booking_id,
  state.current_stage_id,
  target.id,
  's10m_stage11',
  now(),
  '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_states state
JOIN s10m_bookings booking_fixture
  ON booking_fixture.id =
     state.booking_id
JOIN public.booking_journey_stages target
  ON target.organization_id =
     state.organization_id
 AND target.stage_key = 'shoot_completed'
 AND target.stage_order = 11
 AND target.is_active
WHERE booking_fixture.fixture_key = 'post_stage10';

UPDATE public.booking_journey_states state
SET
  current_stage_id =
    target.id,
  stage_entered_at =
    now(),
  version =
    state.version + 1,
  updated_by =
    '8b100000-0000-0000-0000-000000000001'
FROM public.booking_journey_stages target
WHERE state.booking_id IN (
    SELECT id
    FROM s10m_bookings
    WHERE fixture_key = 'post_stage10'
  )
  AND target.organization_id =
      state.organization_id
  AND target.stage_key = 'shoot_completed'
  AND target.stage_order = 11
  AND target.is_active;

-- current_lead_photo / current_lead_video: establish a genuine current
-- lead via the real mutation RPC (first assignment accepts a NULL
-- change_reason). Not pgTAP-wrapped since these are fixture setup, not
-- numbered assertions.

SELECT public.assign_booking_team_member(
  (SELECT id FROM s10m_bookings WHERE fixture_key = 'current_lead_photo'),
  'lead_photographer',
  '8b100000-0000-0000-0000-000000000002',
  true,
  NULL
);

SELECT public.assign_booking_team_member(
  (SELECT id FROM s10m_bookings WHERE fixture_key = 'current_lead_video'),
  'lead_videographer',
  '8b100000-0000-0000-0000-000000000005',
  true,
  NULL
);

-- ended_lead: establish then end a Lead Photographer assignment.

SELECT public.assign_booking_team_member(
  (SELECT id FROM s10m_bookings WHERE fixture_key = 'ended_lead'),
  'lead_photographer',
  '8b100000-0000-0000-0000-000000000002',
  true,
  NULL
);

SELECT public.assign_booking_team_member(
  (SELECT id FROM s10m_bookings WHERE fixture_key = 'ended_lead'),
  'lead_photographer',
  '8b100000-0000-0000-0000-000000000002',
  false,
  'S10 7M ending the lead for fixture setup'
);

CREATE TEMP TABLE s10m_read_baseline AS
SELECT
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit_row
    WHERE audit_row.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
  ) AS audit_count,
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment_row
    WHERE assignment_row.booking_id =
          (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
  ) AS assignment_count,
  journey_row.current_stage_id,
  journey_row.version AS journey_version
FROM public.booking_journey_states journey_row
WHERE journey_row.booking_id =
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8');

GRANT SELECT
ON s10m_read_baseline
TO authenticated, anon, service_role;

-- =====================================================================
-- Part 4 — Stage-gated positive access
-- =====================================================================

SET LOCAL ROLE authenticated;

-- 10
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id = ANY (
      ARRAY[
        '8b100000-0000-0000-0000-000000000002',
        '8b100000-0000-0000-0000-000000000003',
        '8b100000-0000-0000-0000-000000000004',
        '8b100000-0000-0000-0000-000000000005',
        '8b100000-0000-0000-0000-000000000006',
        '8b100000-0000-0000-0000-000000000008',
        '8b300000-0000-0000-0000-000000000001'
      ]::uuid[]
    )
  ),
  7::bigint,
  'Stage 8 candidate directory returns all seven transaction-local qualifying candidates'
);

-- 11
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage9')
    ) candidate
    WHERE candidate.subject_id = ANY (
      ARRAY[
        '8b100000-0000-0000-0000-000000000002',
        '8b100000-0000-0000-0000-000000000003',
        '8b100000-0000-0000-0000-000000000004',
        '8b100000-0000-0000-0000-000000000005',
        '8b100000-0000-0000-0000-000000000006',
        '8b100000-0000-0000-0000-000000000008',
        '8b300000-0000-0000-0000-000000000001'
      ]::uuid[]
    )
  ),
  7::bigint,
  'Stage 9 candidate directory returns all seven transaction-local qualifying candidates'
);

-- 12
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage10')
    ) candidate
    WHERE candidate.subject_id = ANY (
      ARRAY[
        '8b100000-0000-0000-0000-000000000002',
        '8b100000-0000-0000-0000-000000000003',
        '8b100000-0000-0000-0000-000000000004',
        '8b100000-0000-0000-0000-000000000005',
        '8b100000-0000-0000-0000-000000000006',
        '8b100000-0000-0000-0000-000000000008',
        '8b300000-0000-0000-0000-000000000001'
      ]::uuid[]
    )
  ),
  7::bigint,
  'Stage 10 candidate directory returns all seven transaction-local qualifying candidates'
);

RESET ROLE;

-- =====================================================================
-- Part 5 — Stage-gate denial
-- =====================================================================

SET LOCAL ROLE authenticated;

-- 13
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'pre_stage8')
    )
  $$,
  '22023',
  'get_booking_team_assignment_candidates: booking must be within Booking Confirmed through Shoot Scheduled',
  'pre-Stage-8 booking denies candidate discovery'
);

-- 14
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'post_stage10')
    )
  $$,
  '22023',
  'get_booking_team_assignment_candidates: booking must be within Booking Confirmed through Shoot Scheduled',
  'post-Stage-10 booking denies candidate discovery'
);

RESET ROLE;

-- =====================================================================
-- Part 6 — Authorization denial
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000007',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 15
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    )
  $$,
  '42501',
  'get_booking_team_assignment_candidates: active organization membership required',
  'suspended organization member cannot obtain candidates'
);

RESET ROLE;

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000008',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000008","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 16
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    )
  $$,
  '42501',
  'get_booking_team_assignment_candidates: booking.team.assign permission required',
  'active member without booking.team.assign cannot obtain candidates'
);

RESET ROLE;

-- =====================================================================
-- Part 7 — Branch isolation
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000009',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000009","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 17
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'branch_a')
    )
  ),
  'branch-scoped actor obtains candidates within canonical branch scope'
);

RESET ROLE;

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 18
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'branch_a')
    ) candidate
    WHERE candidate.subject_id =
          '8b100000-0000-0000-0000-000000000010'
  ),
  'branch-ineligible member (scoped only to the other branch) is excluded from candidates'
);

RESET ROLE;

-- =====================================================================
-- Part 8 — Organization isolation
-- =====================================================================

INSERT INTO public.organizations (
  id,
  display_name,
  slug,
  status,
  currency_code,
  timezone,
  brand_prefix
)
VALUES (
  '8b500000-0000-0000-0000-000000000001',
  'S10 7M Foreign Studio',
  's10-7m-foreign-studio',
  'suspended',
  'INR',
  'Asia/Kolkata',
  'S107MF'
);

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '8b500000-0000-0000-0000-000000000001'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '8b100000-0000-0000-0000-000000000011',
  '8b500000-0000-0000-0000-000000000001',
  '8b000000-0000-0000-0000-000000000011',
  'active',
  'S10 7M Foreign Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '8b500000-0000-0000-0000-000000000001',
  '8b100000-0000-0000-0000-000000000011',
  role_row.id,
  NULL
FROM public.roles role_row
WHERE role_row.key =
      'founder';

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '8b500000-0000-0000-0000-000000000001';

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000011',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000011","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 19
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    )
  $$,
  '42501',
  'get_booking_team_assignment_candidates: active organization membership required',
  'foreign-organization actor cannot obtain canonical-organization candidates'
);

RESET ROLE;

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- =====================================================================
-- Part 9 — Internal candidate semantics
-- =====================================================================

SET LOCAL ROLE authenticated;

-- 20
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_type = 'internal_member'
      AND candidate.subject_id =
          '8b100000-0000-0000-0000-000000000002'
  ),
  'active internal member with a qualifying role grant is included'
);

-- 21
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id =
          '8b100000-0000-0000-0000-000000000007'
  ),
  'suspended internal member is excluded from candidates'
);

-- 22
SELECT is(
  (
    SELECT candidate.eligible_assignment_roles
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id =
          '8b100000-0000-0000-0000-000000000002'
  ),
  ARRAY['lead_photographer']::text[],
  'Photographer maps only to Lead Photographer'
);

-- 23
SELECT is(
  (
    SELECT candidate.eligible_assignment_roles
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id =
          '8b100000-0000-0000-0000-000000000003'
  ),
  ARRAY['assistant']::text[],
  'Assistant maps only to Assistant'
);

-- 24
SELECT is(
  (
    SELECT candidate.eligible_assignment_roles
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id =
          '8b100000-0000-0000-0000-000000000004'
  ),
  ARRAY['stylist']::text[],
  'Stylist maps only to Stylist'
);

-- 25
SELECT is(
  (
    SELECT candidate.eligible_assignment_roles
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id =
          '8b100000-0000-0000-0000-000000000005'
  ),
  ARRAY['lead_videographer', 'supporting_videographer']::text[],
  'Videographer maps to both Lead and Supporting Videographer'
);

-- 26
SELECT is(
  (
    SELECT candidate.eligible_assignment_roles
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id =
          '8b100000-0000-0000-0000-000000000006'
  ),
  ARRAY[
    'lead_photographer',
    'lead_videographer',
    'supporting_videographer'
  ]::text[],
  'multi-role member aggregates roles from every held grant without duplicates'
);

-- =====================================================================
-- Part 10 — External candidate semantics
-- =====================================================================

-- 27
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_type = 'external_creative'
      AND candidate.subject_id =
          '8b300000-0000-0000-0000-000000000001'
  ),
  'organization-scoped external creative is included'
);

-- 28
SELECT is(
  (
    SELECT candidate.eligible_assignment_roles
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
    WHERE candidate.subject_id =
          '8b300000-0000-0000-0000-000000000001'
  ),
  ARRAY[
    'lead_photographer',
    'assistant',
    'stylist',
    'lead_videographer',
    'supporting_videographer'
  ]::text[],
  'external candidates expose exactly the five canonical roles'
);

-- =====================================================================
-- Part 11 — Ordering and privacy
-- =====================================================================

-- 29
SELECT is(
  (
    SELECT array_agg(candidate.subject_id)
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
  ),
  (
    SELECT array_agg(ordered.subject_id)
    FROM (
      SELECT candidate.subject_id
      FROM public.get_booking_team_assignment_candidates(
        (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
      ) candidate
      ORDER BY
        candidate.subject_type,
        lower(candidate.subject_display_name),
        candidate.subject_id
    ) ordered
  ),
  'candidate directory ordering is deterministic by subject_type, display name, subject id'
);

-- 30
SELECT ok(
  NOT (
    'email' = ANY(
      SELECT procedure_row.proargnames[position]
      FROM pg_proc procedure_row
      CROSS JOIN LATERAL
        generate_subscripts(
          procedure_row.proallargtypes,
          1
        ) AS argument(position)
      WHERE procedure_row.oid =
            'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
        AND procedure_row.proargmodes[position]
            IN ('o', 't')
    )
  )
  AND NOT (
    'phone' = ANY(
      SELECT procedure_row.proargnames[position]
      FROM pg_proc procedure_row
      CROSS JOIN LATERAL
        generate_subscripts(
          procedure_row.proallargtypes,
          1
        ) AS argument(position)
      WHERE procedure_row.oid =
            'public.get_booking_team_assignment_candidates(uuid)'::regprocedure
        AND procedure_row.proargmodes[position]
            IN ('o', 't')
    )
  ),
  'candidate RPC projects no email or phone column'
);

-- =====================================================================
-- Part 12 — Direct-access and mutation containment
-- =====================================================================

-- 31
SELECT throws_ok(
  $$
    SELECT *
    FROM public.external_creatives
  $$,
  '42501',
  'permission denied for table external_creatives',
  'authenticated actor cannot directly read external creative identities'
);

-- 32
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.booking_team_assignments',
    'INSERT'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_team_assignments',
    'UPDATE'
  )
  AND NOT has_table_privilege(
    'authenticated',
    'public.booking_team_assignments',
    'DELETE'
  ),
  'booking-team direct authenticated writes remain denied'
);

-- =====================================================================
-- Part 13 — No side effects from a read
-- =====================================================================

SELECT * FROM public.get_booking_team_assignment_candidates(
  (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
);

-- 33
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit_row
    WHERE audit_row.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
  ) =
  (
    SELECT audit_count
    FROM s10m_read_baseline
  ),
  'candidate read creates no audit evidence'
);

-- 34
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment_row
    WHERE assignment_row.booking_id =
          (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
  ) =
  (
    SELECT assignment_count
    FROM s10m_read_baseline
  ),
  'candidate read creates no assignment evidence'
);

-- 35
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.booking_journey_states journey_row
    CROSS JOIN s10m_read_baseline baseline
    WHERE journey_row.booking_id =
          (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
      AND journey_row.current_stage_id =
          baseline.current_stage_id
      AND journey_row.version =
          baseline.journey_version
  ),
  'candidate read creates no journey mutation'
);

RESET ROLE;

-- =====================================================================
-- Part 14 — roles_requiring_change_reason semantics
-- =====================================================================

SET LOCAL ROLE authenticated;

-- 36
SELECT is(
  (
    SELECT DISTINCT candidate.roles_requiring_change_reason
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
  ),
  ARRAY[]::text[],
  'roles_requiring_change_reason is empty when no lead role is currently held'
);

-- 37
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'current_lead_photo')
    ) candidate
    WHERE 'lead_photographer' = ANY(candidate.roles_requiring_change_reason)
  ),
  'roles_requiring_change_reason includes lead_photographer when a current holder exists'
);

-- 38
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'current_lead_video')
    ) candidate
    WHERE 'lead_videographer' = ANY(candidate.roles_requiring_change_reason)
  ),
  'roles_requiring_change_reason includes lead_videographer when a current holder exists'
);

-- 39
SELECT is(
  (
    SELECT count(DISTINCT candidate.roles_requiring_change_reason)::bigint
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'current_lead_photo')
    ) candidate
  ),
  1::bigint,
  'roles_requiring_change_reason is identical across every candidate row for one call'
);

-- 40
SELECT is(
  (
    SELECT DISTINCT candidate.roles_requiring_change_reason
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'ended_lead')
    ) candidate
  ),
  ARRAY[]::text[],
  'an ended lead assignment does not appear in roles_requiring_change_reason'
);

-- 41
SELECT is(
  (
    SELECT DISTINCT candidate.roles_requiring_change_reason
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    ) candidate
  ),
  ARRAY[]::text[],
  'roles_requiring_change_reason reflects only the calling booking''s own scope, not another booking''s current leads'
);

RESET ROLE;

-- =====================================================================
-- Part 15 — booking.team.assign without team.read (assertion 12 target)
-- =====================================================================

-- Temporarily remove only team.read from Client Coordinator, which also
-- holds booking.team.assign, to prove the candidate RPC's authorization
-- path never evaluates team.read. This transaction rolls back at the end
-- of the pgTAP file.

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '8b100000-0000-0000-0000-000000000012',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b000000-0000-0000-0000-000000000012',
  'active',
  'S10 7M Client Coordinator'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '8b100000-0000-0000-0000-000000000012',
  role_row.id,
  NULL
FROM public.roles role_row
WHERE role_row.key =
      'client_coordinator';

DELETE FROM public.role_permissions rp
USING public.roles r,
      public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.key = 'client_coordinator'
  AND p.key = 'team.read';

SELECT set_config(
  'request.jwt.claim.sub',
  '8b000000-0000-0000-0000-000000000012',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"8b000000-0000-0000-0000-000000000012","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 42
SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'booking.team.assign',
    NULL
  )
  AND NOT public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'team.read',
    NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_candidates(
      (SELECT id FROM s10m_bookings WHERE fixture_key = 'stage8')
    )
  ),
  'candidate RPC succeeds for an actor with booking.team.assign but without team.read'
);

RESET ROLE;

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.key = 'client_coordinator'
  AND p.key = 'team.read';

SELECT * FROM finish();

ROLLBACK;
