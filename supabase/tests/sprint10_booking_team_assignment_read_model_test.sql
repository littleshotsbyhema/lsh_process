CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SELECT plan(30);

-- =====================================================================
-- Part 1 — Read-model structural / security contract
-- =====================================================================

-- 1
SELECT ok(
  to_regprocedure(
    'public.get_booking_team_assignment_history(uuid)'
  ) IS NOT NULL,
  'booking-team assignment history RPC exists'
);

-- 2
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
          'public.get_booking_team_assignment_history(uuid)'::regprocedure
      AND procedure_row.proargmodes[position]
          IN ('o', 't')
  ),
  ARRAY[
    'assignment_id',
    'booking_id',
    'assignment_role',
    'subject_type',
    'subject_id',
    'subject_display_name',
    'assigned_at',
    'ended_at',
    'end_reason',
    'is_current'
  ]::text[],
  'read RPC exposes exactly the frozen return-column names'
);

-- 3
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
          'public.get_booking_team_assignment_history(uuid)'::regprocedure
      AND procedure_row.proargmodes[position]
          IN ('o', 't')
  ),
  ARRAY[
    'uuid',
    'uuid',
    'text',
    'text',
    'uuid',
    'text',
    'timestamp with time zone',
    'timestamp with time zone',
    'text',
    'boolean'
  ]::text[],
  'read RPC exposes exactly the frozen return-column types'
);

-- 4
SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc procedure_row
    WHERE procedure_row.oid =
          'public.get_booking_team_assignment_history(uuid)'::regprocedure
      AND procedure_row.prosecdef
      AND procedure_row.provolatile = 's'
      AND 'search_path=""' =
          ANY(
            COALESCE(
              procedure_row.proconfig,
              ARRAY[]::text[]
            )
          )
  ),
  'read RPC is stable SECURITY DEFINER with empty search_path'
);

-- 5
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.get_booking_team_assignment_history(uuid)',
    'EXECUTE'
  )
  AND NOT has_function_privilege(
    'anon',
    'public.get_booking_team_assignment_history(uuid)',
    'EXECUTE'
  ),
  'read RPC is authenticated-only'
);

-- 6
SELECT ok(
  NOT has_table_privilege(
    'authenticated',
    'public.external_creatives',
    'SELECT'
  ),
  'external_creatives remains unavailable to direct authenticated reads'
);

-- 7
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
-- Part 2 — Transaction-local identities
-- =====================================================================

INSERT INTO auth.users (id)
VALUES
  ('7a000000-0000-0000-0000-000000000001'),
  ('7a000000-0000-0000-0000-000000000002'),
  ('7a000000-0000-0000-0000-000000000003'),
  ('7a000000-0000-0000-0000-000000000004'),
  ('7a000000-0000-0000-0000-000000000005'),
  ('7a000000-0000-0000-0000-000000000006'),
  ('7a000000-0000-0000-0000-000000000007'),
  ('7a000000-0000-0000-0000-000000000008'),
  ('7a000000-0000-0000-0000-000000000009'),
  ('7a000000-0000-0000-0000-000000000010'),
  ('7a000000-0000-0000-0000-000000000011');

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES
(
  '7b000000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000001',
  'active',
  'S7L Founder'
),
(
  '7b000000-0000-0000-0000-000000000002',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000002',
  'active',
  'S7L Booking Reader'
),
(
  '7b000000-0000-0000-0000-000000000003',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000003',
  'active',
  'S7L No Permission Actor'
),
(
  '7b000000-0000-0000-0000-000000000004',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000004',
  'active',
  'S7L Suspended Reader'
),
(
  '7b000000-0000-0000-0000-000000000005',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000005',
  'active',
  'S7L Branch A Reader'
),
(
  '7b000000-0000-0000-0000-000000000006',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000006',
  'active',
  'S7L Historical Lead'
),
(
  '7b000000-0000-0000-0000-000000000007',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000007',
  'active',
  'S7L Current Lead'
),
(
  '7b000000-0000-0000-0000-000000000008',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000008',
  'active',
  'S7L Assistant'
),
(
  '7b000000-0000-0000-0000-000000000009',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000009',
  'active',
  'S7L Stylist'
),
(
  '7b000000-0000-0000-0000-000000000010',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7a000000-0000-0000-0000-000000000010',
  'active',
  'S7L Lead Videographer'
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
  role_row.id,
  fixture.branch_id
FROM (
  VALUES
    (
      '7b000000-0000-0000-0000-000000000001'::uuid,
      'founder'::text,
      NULL::uuid
    ),
    (
      '7b000000-0000-0000-0000-000000000002'::uuid,
      'videographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '7b000000-0000-0000-0000-000000000004'::uuid,
      'videographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '7b000000-0000-0000-0000-000000000006'::uuid,
      'photographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '7b000000-0000-0000-0000-000000000007'::uuid,
      'photographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '7b000000-0000-0000-0000-000000000008'::uuid,
      'assistant',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '7b000000-0000-0000-0000-000000000009'::uuid,
      'stylist',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    ),
    (
      '7b000000-0000-0000-0000-000000000010'::uuid,
      'videographer',
      'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
    )
) AS fixture(member_id, role_key, branch_id)
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
  '7a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7a000000-0000-0000-0000-000000000001","role":"authenticated"}',
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
  '7c000000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S7L Branch A',
  's7la',
  'active',
  'IN',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000001'
),
(
  '7c000000-0000-0000-0000-000000000002',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S7L Branch B',
  's7lb',
  'active',
  'IN',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000001'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7b000000-0000-0000-0000-000000000005',
  role_row.id,
  '7c000000-0000-0000-0000-000000000001'
FROM public.roles role_row
WHERE role_row.key =
      'videographer';

-- S7L Photographer cross-branch role scopes.
-- Member ...007 is staffing evidence on the base, Branch A and Branch B
-- bookings, so its operational role must cover all three booking scopes.
INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid,
  '7b000000-0000-0000-0000-000000000007'::uuid,
  role_row.id,
  fixture.branch_id
FROM (
  VALUES
    ('7c000000-0000-0000-0000-000000000001'::uuid),
    ('7c000000-0000-0000-0000-000000000002'::uuid)
) AS fixture(branch_id)
JOIN public.roles role_row
  ON role_row.key = 'photographer';


UPDATE public.organization_members
SET
  status =
    'suspended'::public.member_status,
  suspended_at =
    now(),
  suspended_by =
    '7b000000-0000-0000-0000-000000000001'
WHERE id =
      '7b000000-0000-0000-0000-000000000004';

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
  '7d000000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid,
  'QT-45723A',
  'S7L Base Family',
  'S7L Base Family',
  'active',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000001'
),
(
  '7d000000-0000-0000-0000-000000000002',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7c000000-0000-0000-0000-000000000001',
  'QT-45723B',
  'S7L Branch A Family',
  'S7L Branch A Family',
  'active',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000001'
),
(
  '7d000000-0000-0000-0000-000000000003',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  '7c000000-0000-0000-0000-000000000002',
  'QT-45723C',
  'S7L Branch B Family',
  'S7L Branch B Family',
  'active',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000001'
),
(
  '7d000000-0000-0000-0000-000000000004',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  NULL,
  'QT-45723D',
  'S7L Empty Team Family',
  'S7L Empty Team Family',
  'active',
  '7b000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000001'
);

-- =====================================================================
-- Part 3 — Canonical booking fixtures
-- =====================================================================

CREATE FUNCTION pg_temp.s7l_create_booking(
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

CREATE TEMP TABLE s7l_bookings (
  fixture_key text PRIMARY KEY,
  id          uuid NOT NULL
);

INSERT INTO s7l_bookings (
  fixture_key,
  id
)
VALUES
(
  'base',
  pg_temp.s7l_create_booking(
    '7d000000-0000-0000-0000-000000000001',
    NULL
  )
),
(
  'branch_a',
  pg_temp.s7l_create_booking(
    '7d000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000001'
  )
),
(
  'branch_b',
  pg_temp.s7l_create_booking(
    '7d000000-0000-0000-0000-000000000003',
    '7c000000-0000-0000-0000-000000000002'
  )
),
(
  'empty',
  pg_temp.s7l_create_booking(
    '7d000000-0000-0000-0000-000000000004',
    NULL
  )
);

GRANT SELECT
ON s7l_bookings
TO authenticated, anon, service_role;

INSERT INTO public.external_creatives (
  id,
  organization_id,
  display_name,
  created_by
)
VALUES (
  '7a100000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  'S7L External Film Partner',
  '7b000000-0000-0000-0000-000000000001'
);

-- Historical Lead must first be inserted active.
INSERT INTO public.booking_team_assignments (
  id,
  organization_id,
  booking_id,
  assignment_role,
  assigned_member_id,
  assigned_at,
  assigned_by
)
SELECT
  '7f000000-0000-0000-0000-000000000001',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  booking_fixture.id,
  'lead_photographer',
  '7b000000-0000-0000-0000-000000000006',
  '2026-08-19 09:00:00+00'::timestamptz,
  '7b000000-0000-0000-0000-000000000001'
FROM s7l_bookings booking_fixture
WHERE booking_fixture.fixture_key =
      'base';

UPDATE public.booking_team_assignments
SET
  ended_at =
    '2026-08-19 09:10:00+00'::timestamptz,
  ended_by =
    '7b000000-0000-0000-0000-000000000001',
  end_reason =
    'Replaced for Slice 7L history'
WHERE id =
      '7f000000-0000-0000-0000-000000000001';

INSERT INTO public.booking_team_assignments (
  id,
  organization_id,
  booking_id,
  assignment_role,
  assigned_member_id,
  assigned_at,
  assigned_by
)
SELECT
  fixture.assignment_id,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  booking_fixture.id,
  fixture.assignment_role,
  fixture.member_id,
  fixture.assigned_at,
  '7b000000-0000-0000-0000-000000000001'
FROM s7l_bookings booking_fixture
CROSS JOIN (
  VALUES
  (
    '7f000000-0000-0000-0000-000000000002'::uuid,
    'lead_photographer'::text,
    '7b000000-0000-0000-0000-000000000007'::uuid,
    '2026-08-19 09:20:00+00'::timestamptz
  ),
  (
    '7f000000-0000-0000-0000-000000000003'::uuid,
    'assistant',
    '7b000000-0000-0000-0000-000000000008'::uuid,
    '2026-08-19 09:30:00+00'::timestamptz
  ),
  (
    '7f000000-0000-0000-0000-000000000004'::uuid,
    'stylist',
    '7b000000-0000-0000-0000-000000000009'::uuid,
    '2026-08-19 09:40:00+00'::timestamptz
  ),
  (
    '7f000000-0000-0000-0000-000000000005'::uuid,
    'lead_videographer',
    '7b000000-0000-0000-0000-000000000010'::uuid,
    '2026-08-19 09:50:00+00'::timestamptz
  )
) AS fixture(
  assignment_id,
  assignment_role,
  member_id,
  assigned_at
)
WHERE booking_fixture.fixture_key =
      'base';

INSERT INTO public.booking_team_assignments (
  id,
  organization_id,
  booking_id,
  assignment_role,
  assigned_external_creative_id,
  assigned_at,
  assigned_by
)
SELECT
  '7f000000-0000-0000-0000-000000000006',
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  booking_fixture.id,
  'supporting_videographer',
  '7a100000-0000-0000-0000-000000000001',
  '2026-08-19 10:00:00+00'::timestamptz,
  '7b000000-0000-0000-0000-000000000001'
FROM s7l_bookings booking_fixture
WHERE booking_fixture.fixture_key =
      'base';

INSERT INTO public.booking_team_assignments (
  id,
  organization_id,
  booking_id,
  assignment_role,
  assigned_member_id,
  assigned_at,
  assigned_by
)
SELECT
  fixture.assignment_id,
  '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
  booking_fixture.id,
  'lead_photographer',
  '7b000000-0000-0000-0000-000000000007',
  fixture.assigned_at,
  '7b000000-0000-0000-0000-000000000001'
FROM s7l_bookings booking_fixture
JOIN (
  VALUES
    (
      'branch_a'::text,
      '7f000000-0000-0000-0000-000000000007'::uuid,
      '2026-08-19 10:10:00+00'::timestamptz
    ),
    (
      'branch_b',
      '7f000000-0000-0000-0000-000000000008'::uuid,
      '2026-08-19 10:20:00+00'::timestamptz
    )
) AS fixture(
  fixture_key,
  assignment_id,
  assigned_at
)
  ON fixture.fixture_key =
     booking_fixture.fixture_key;

CREATE TEMP TABLE s7l_read_baseline AS
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
          (
            SELECT id
            FROM s7l_bookings
            WHERE fixture_key = 'base'
          )
  ) AS assignment_count,
  journey_row.current_stage_id,
  journey_row.version AS journey_version
FROM public.booking_journey_states journey_row
WHERE journey_row.booking_id =
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      );

-- =====================================================================
-- Part 4 — Founder canonical read behavior
-- =====================================================================

SET LOCAL ROLE authenticated;

-- 8
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    )
  ),
  6::bigint,
  'Founder reads complete current and historical assignment evidence'
);

-- 9
SELECT is(
  (
    SELECT array_agg(
             DISTINCT assignment_role
             ORDER BY assignment_role
           )
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    )
  ),
  ARRAY[
    'assistant',
    'lead_photographer',
    'lead_videographer',
    'stylist',
    'supporting_videographer'
  ]::text[],
  'read model preserves all five canonical assignment roles'
);

-- 10
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    ) history_row
    WHERE history_row.assignment_id =
          '7f000000-0000-0000-0000-000000000002'
      AND history_row.subject_type =
          'internal_member'
      AND history_row.subject_id =
          '7b000000-0000-0000-0000-000000000007'
      AND history_row.subject_display_name =
          'S7L Current Lead'
      AND history_row.is_current
      AND history_row.ended_at IS NULL
  ),
  'internal current assignment resolves only safe member display identity'
);

-- 11
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    ) history_row
    WHERE history_row.assignment_id =
          '7f000000-0000-0000-0000-000000000006'
      AND history_row.assignment_role =
          'supporting_videographer'
      AND history_row.subject_type =
          'external_creative'
      AND history_row.subject_id =
          '7a100000-0000-0000-0000-000000000001'
      AND history_row.subject_display_name =
          'S7L External Film Partner'
      AND history_row.is_current
  ),
  'external assignment resolves safe display identity without direct table access'
);

-- 12
SELECT ok(
  EXISTS (
    SELECT 1
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    ) history_row
    WHERE history_row.assignment_id =
          '7f000000-0000-0000-0000-000000000001'
      AND history_row.subject_display_name =
          'S7L Historical Lead'
      AND NOT history_row.is_current
      AND history_row.ended_at =
          '2026-08-19 09:10:00+00'::timestamptz
      AND history_row.end_reason =
          'Replaced for Slice 7L history'
  ),
  'historical assignment preserves ending timestamp and canonical reason'
);

-- 13
SELECT is(
  (
    SELECT array_agg(history_row.assignment_id)
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    ) history_row
  ),
  ARRAY[
    '7f000000-0000-0000-0000-000000000001',
    '7f000000-0000-0000-0000-000000000002',
    '7f000000-0000-0000-0000-000000000003',
    '7f000000-0000-0000-0000-000000000004',
    '7f000000-0000-0000-0000-000000000005',
    '7f000000-0000-0000-0000-000000000006'
  ]::uuid[],
  'history result ordering is deterministic by assigned_at then assignment id'
);

-- 14
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'empty'
      )
    )
  ),
  0::bigint,
  'readable booking with no staffing evidence returns canonical empty history'
);

RESET ROLE;

-- 15
SELECT ok(
  (
    SELECT count(*)::bigint
    FROM public.audit_events audit_row
    WHERE audit_row.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
  ) =
  (
    SELECT audit_count
    FROM s7l_read_baseline
  )
  AND
  (
    SELECT count(*)::bigint
    FROM public.booking_team_assignments assignment_row
    WHERE assignment_row.booking_id =
          (
            SELECT id
            FROM s7l_bookings
            WHERE fixture_key = 'base'
          )
  ) =
  (
    SELECT assignment_count
    FROM s7l_read_baseline
  )
  AND
  EXISTS (
    SELECT 1
    FROM public.booking_journey_states journey_row
    CROSS JOIN s7l_read_baseline baseline
    WHERE journey_row.booking_id =
          (
            SELECT id
            FROM s7l_bookings
            WHERE fixture_key = 'base'
          )
      AND journey_row.current_stage_id =
          baseline.current_stage_id
      AND journey_row.version =
          baseline.journey_version
  ),
  'read invocation creates no audit, assignment, or journey mutation'
);

-- =====================================================================
-- Part 5 — booking.read without team.read
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '7a000000-0000-0000-0000-000000000002',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7a000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 16
SELECT ok(
  public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'booking.read',
    'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
  )
  AND NOT public.has_permission(
    '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
    'team.read',
    'bcf1cb6a-6e85-4f59-a10a-28a1aeb1c5b1'::uuid
  ),
  'Videographer fixture has booking.read without team.read'
);

-- 17
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    )
  ),
  6::bigint,
  'booking.read actor without team.read can read booking-scoped staffing history'
);

-- 18
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.team_access_directory(
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'
    )
  ),
  0::bigint,
  'booking read does not leak the general Team directory'
);

RESET ROLE;

-- =====================================================================
-- Part 6 — Authorization denial
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '7a000000-0000-0000-0000-000000000003',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7a000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 19
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    )
  $$,
  '42501',
  'get_booking_team_assignment_history: booking.read permission required',
  'active member without booking.read cannot obtain staffing history'
);

RESET ROLE;

SELECT set_config(
  'request.jwt.claim.sub',
  '7a000000-0000-0000-0000-000000000004',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7a000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 20
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    )
  $$,
  '42501',
  'get_booking_team_assignment_history: active organization membership required',
  'suspended organization member cannot obtain staffing history'
);

RESET ROLE;

-- =====================================================================
-- Part 7 — Branch isolation
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '7a000000-0000-0000-0000-000000000005',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7a000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 21
SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'branch_a'
      )
    )
  ),
  1::bigint,
  'branch-scoped booking reader can read staffing within canonical branch scope'
);

-- 22
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'branch_b'
      )
    )
  $$,
  '42501',
  'get_booking_team_assignment_history: booking.read permission required',
  'branch-scoped booking reader cannot read staffing outside canonical branch authority'
);

RESET ROLE;

-- =====================================================================
-- Part 8 — Cross-organization isolation
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
  '7e000000-0000-0000-0000-000000000001',
  'S7L Foreign Studio',
  's7l-foreign-studio',
  'suspended',
  'INR',
  'Asia/Kolkata',
  'S7LF'
);

INSERT INTO public.organization_settings (
  organization_id
)
VALUES (
  '7e000000-0000-0000-0000-000000000001'
);

INSERT INTO public.organization_members (
  id,
  organization_id,
  user_id,
  status,
  display_name
)
VALUES (
  '7b000000-0000-0000-0000-000000000011',
  '7e000000-0000-0000-0000-000000000001',
  '7a000000-0000-0000-0000-000000000011',
  'active',
  'S7L Foreign Founder'
);

INSERT INTO public.member_role_grants (
  organization_id,
  organization_member_id,
  role_id,
  branch_id
)
SELECT
  '7e000000-0000-0000-0000-000000000001',
  '7b000000-0000-0000-0000-000000000011',
  role_row.id,
  NULL
FROM public.roles role_row
WHERE role_row.key =
      'founder';

UPDATE public.organizations
SET status =
      'active'::public.organization_status
WHERE id =
      '7e000000-0000-0000-0000-000000000001';

SELECT set_config(
  'request.jwt.claim.sub',
  '7a000000-0000-0000-0000-000000000011',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7a000000-0000-0000-0000-000000000011","role":"authenticated"}',
  true
);

SET LOCAL ROLE authenticated;

-- 23
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    )
  $$,
  '42501',
  'get_booking_team_assignment_history: active organization membership required',
  'foreign-organization Founder cannot obtain canonical-organization staffing history'
);

RESET ROLE;

-- =====================================================================
-- Part 9 — Anonymous and direct table containment
-- =====================================================================

SELECT set_config(
  'request.jwt.claim.sub',
  '7a000000-0000-0000-0000-000000000001',
  true
);

SELECT set_config(
  'request.jwt.claims',
  '{"sub":"7a000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

SET LOCAL ROLE anon;

-- 24
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_history(
      (
        SELECT id
        FROM s7l_bookings
        WHERE fixture_key = 'base'
      )
    )
  $$,
  '42501',
  'permission denied for function get_booking_team_assignment_history',
  'anonymous role cannot execute booking-team history RPC'
);

RESET ROLE;

SET LOCAL ROLE authenticated;

-- 25
SELECT throws_ok(
  $$
    SELECT *
    FROM public.external_creatives
  $$,
  '42501',
  'permission denied for table external_creatives',
  'authenticated actor still cannot directly read external creative identities'
);

-- 26
SELECT throws_ok(
  $$
    INSERT INTO public.booking_team_assignments (
      organization_id,
      booking_id,
      assignment_role,
      assigned_member_id,
      assigned_by
    )
    SELECT
      '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc',
      booking_fixture.id,
      'assistant',
      '7b000000-0000-0000-0000-000000000008',
      '7b000000-0000-0000-0000-000000000001'
    FROM s7l_bookings booking_fixture
    WHERE booking_fixture.fixture_key =
          'base'
  $$,
  '42501',
  'permission denied for table booking_team_assignments',
  'authenticated direct booking-team INSERT remains denied'
);

-- 27
SELECT throws_ok(
  $$
    UPDATE public.booking_team_assignments
    SET end_reason =
        'Direct update probe'
    WHERE id =
          '7f000000-0000-0000-0000-000000000002'
  $$,
  '42501',
  'permission denied for table booking_team_assignments',
  'authenticated direct booking-team UPDATE remains denied'
);

-- 28
SELECT throws_ok(
  $$
    DELETE FROM public.booking_team_assignments
    WHERE id =
          '7f000000-0000-0000-0000-000000000002'
  $$,
  '42501',
  'permission denied for table booking_team_assignments',
  'authenticated direct booking-team DELETE remains denied'
);

-- 29
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_history(
      NULL
    )
  $$,
  '22023',
  'get_booking_team_assignment_history: booking_id is required',
  'booking-team history RPC rejects a null booking id'
);

-- 30
SELECT throws_ok(
  $$
    SELECT *
    FROM public.get_booking_team_assignment_history(
      '7fffffff-ffff-ffff-ffff-ffffffffffff'
    )
  $$,
  '22023',
  'get_booking_team_assignment_history: booking not found',
  'booking-team history RPC rejects an unknown booking'
);

RESET ROLE;

SELECT * FROM finish();

ROLLBACK;
