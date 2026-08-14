-- =====================================================================
-- Sprint 10 — Slice 3
-- Preparation Checklist Foundation
--
-- Section A only:
--   * canonical booking_preparation_items table
--   * tenant-safe foreign keys
--   * taxonomy / satisfaction integrity constraints
--
-- RLS, mutation guards, taxonomy instantiation, RPC changes and pgTAP
-- coverage are added in later bounded sections of this same migration.
-- =====================================================================

-- =====================================================================
-- Section A1 — Canonical preparation-item evidence
-- =====================================================================

CREATE TABLE public.booking_preparation_items (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL,
  preparation_id   uuid NOT NULL,

  service_category text NOT NULL,
  taxonomy_version smallint NOT NULL,
  item_key          text NOT NULL,
  item_label        text NOT NULL,
  is_required       boolean NOT NULL,
  sort_order        integer NOT NULL,

  is_satisfied      boolean NOT NULL DEFAULT false,
  satisfied_at      timestamptz,
  satisfied_by      uuid,

  created_at        timestamptz NOT NULL DEFAULT now(),
  created_by        uuid NOT NULL,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  updated_by        uuid NOT NULL,

  CONSTRAINT booking_preparation_items_preparation_fkey
    FOREIGN KEY (
      organization_id,
      preparation_id
    )
    REFERENCES public.booking_preparations (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_preparation_items_satisfied_by_fkey
    FOREIGN KEY (
      satisfied_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_preparation_items_created_by_fkey
    FOREIGN KEY (
      created_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_preparation_items_updated_by_fkey
    FOREIGN KEY (
      updated_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_preparation_items_organization_id_id_key
    UNIQUE (
      organization_id,
      id
    ),

  CONSTRAINT booking_preparation_items_preparation_item_key_key
    UNIQUE (
      organization_id,
      preparation_id,
      item_key
    ),

  CONSTRAINT booking_preparation_items_service_category_format_chk
    CHECK (
      service_category ~ '^[a-z][a-z0-9_]*$'
    ),

  CONSTRAINT booking_preparation_items_taxonomy_version_chk
    CHECK (
      taxonomy_version > 0
    ),

  CONSTRAINT booking_preparation_items_item_key_format_chk
    CHECK (
      item_key ~ '^[a-z][a-z0-9_]*$'
    ),

  CONSTRAINT booking_preparation_items_item_label_chk
    CHECK (
      btrim(item_label) <> ''
      AND char_length(item_label) <= 240
    ),

  CONSTRAINT booking_preparation_items_sort_order_chk
    CHECK (
      sort_order > 0
    ),

  CONSTRAINT booking_preparation_items_satisfaction_state_chk
    CHECK (
      (
        is_satisfied
        AND satisfied_at IS NOT NULL
        AND satisfied_by IS NOT NULL
      )
      OR
      (
        NOT is_satisfied
        AND satisfied_at IS NULL
        AND satisfied_by IS NULL
      )
    )
);

CREATE INDEX booking_preparation_items_preparation_sort_idx
ON public.booking_preparation_items (
  organization_id,
  preparation_id,
  sort_order
);

-- =====================================================================
-- Section B — Preparation-item mutation guard and security boundary
-- =====================================================================

-- =====================================================================
-- Section B1 — Immutable taxonomy / identity guard
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_booking_preparation_item_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking preparation items cannot be deleted';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.preparation_id IS DISTINCT FROM OLD.preparation_id
       OR NEW.service_category IS DISTINCT FROM OLD.service_category
       OR NEW.taxonomy_version IS DISTINCT FROM OLD.taxonomy_version
       OR NEW.item_key IS DISTINCT FROM OLD.item_key
       OR NEW.item_label IS DISTINCT FROM OLD.item_label
       OR NEW.is_required IS DISTINCT FROM OLD.is_required
       OR NEW.sort_order IS DISTINCT FROM OLD.sort_order
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
      RAISE EXCEPTION
        'booking preparation item taxonomy and identity evidence is immutable';
    END IF;
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL THEN
      RAISE EXCEPTION
        'booking preparation item requires an active organization member';
    END IF;

    IF TG_OP = 'INSERT' THEN
      IF NEW.created_by IS DISTINCT FROM v_actor
         OR NEW.updated_by IS DISTINCT FROM v_actor THEN
        RAISE EXCEPTION
          'booking preparation item actor attribution must match the current active organization member';
      END IF;

      IF NEW.is_satisfied
         OR NEW.satisfied_at IS NOT NULL
         OR NEW.satisfied_by IS NOT NULL THEN
        RAISE EXCEPTION
          'booking preparation items must begin unsatisfied';
      END IF;
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.updated_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking preparation item update actor must match the current active organization member';
    END IF;

    IF TG_OP = 'UPDATE'
       AND OLD.is_satisfied IS DISTINCT FROM NEW.is_satisfied
       AND NEW.is_satisfied
       AND NEW.satisfied_by IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION
        'booking preparation item satisfaction actor must match the current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER booking_preparation_items_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_preparation_items
FOR EACH ROW
EXECUTE FUNCTION public.lsh_booking_preparation_item_guard();

REVOKE ALL
ON FUNCTION public.lsh_booking_preparation_item_guard()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.lsh_booking_preparation_item_guard()
TO service_role;

-- =====================================================================
-- Section B2 — Forced RLS and SELECT-only authenticated boundary
-- =====================================================================

ALTER TABLE public.booking_preparation_items
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_preparation_items
FORCE ROW LEVEL SECURITY;

CREATE POLICY booking_preparation_items_authenticated_select
ON public.booking_preparation_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.booking_preparations preparation
    JOIN public.bookings booking
      ON booking.organization_id =
         preparation.organization_id
     AND booking.id =
         preparation.booking_id
    WHERE preparation.organization_id =
          booking_preparation_items.organization_id
      AND preparation.id =
          booking_preparation_items.preparation_id
      AND public.has_permission(
            booking.organization_id,
            'prep.read',
            booking.branch_id
          )
      AND (
        booking.branch_id IS NULL
        OR public.has_branch_scope(
             booking.organization_id,
             booking.branch_id
           )
      )
  )
);

REVOKE ALL PRIVILEGES
ON TABLE public.booking_preparation_items
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_preparation_items
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE public.booking_preparation_items
TO service_role;

-- =====================================================================
-- Section C1 — Internal taxonomy-version-1 source of truth
-- =====================================================================

CREATE OR REPLACE FUNCTION public.lsh_preparation_taxonomy_v1(
  p_service_category text
)
RETURNS TABLE (
  item_key text,
  item_label text,
  is_required boolean,
  sort_order integer
)
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  WITH common_items (
    item_key,
    item_label,
    is_required,
    sort_order
  ) AS (
    VALUES
      (
        'session_brief_reviewed',
        'Session brief reviewed',
        true,
        10
      ),
      (
        'preparation_guidance_shared',
        'Client preparation guidance shared',
        true,
        20
      ),
      (
        'participant_plan_confirmed',
        'Participant plan confirmed',
        true,
        30
      ),
      (
        'wardrobe_styling_plan_confirmed',
        'Wardrobe and styling plan confirmed',
        true,
        40
      ),
      (
        'set_prop_plan_confirmed',
        'Set / prop plan confirmed',
        true,
        50
      ),
      (
        'location_arrival_plan_confirmed',
        'Location and arrival plan confirmed',
        true,
        60
      ),
      (
        'inspiration_references_reviewed',
        'Inspiration / reference preferences reviewed',
        false,
        70
      ),
      (
        'special_requests_reviewed',
        'Non-safety special requests reviewed',
        false,
        80
      )
  ),
  category_items (
    service_category,
    item_key,
    item_label,
    is_required,
    sort_order
  ) AS (
    VALUES
      (
        'maternity',
        'maternity_wardrobe_selection_confirmed',
        'Maternity wardrobe selection confirmed',
        true,
        110
      ),
      (
        'maternity',
        'maternity_session_style_confirmed',
        'Maternity session style / mood confirmed',
        true,
        120
      ),
      (
        'maternity',
        'maternity_partner_family_plan_reviewed',
        'Partner / family participation plan reviewed',
        false,
        130
      ),
      (
        'newborn',
        'newborn_styling_palette_confirmed',
        'Newborn styling / colour palette confirmed',
        true,
        110
      ),
      (
        'newborn',
        'newborn_family_inclusion_plan_confirmed',
        'Parent / sibling inclusion plan confirmed',
        true,
        120
      ),
      (
        'newborn',
        'newborn_keepsake_prop_requests_reviewed',
        'Keepsake / personal prop requests reviewed',
        false,
        130
      ),
      (
        'sitter',
        'sitter_outfit_plan_confirmed',
        'Sitter outfit plan confirmed',
        true,
        110
      ),
      (
        'sitter',
        'sitter_set_style_confirmed',
        'Sitter set / styling direction confirmed',
        true,
        120
      ),
      (
        'sitter',
        'sitter_theme_palette_reviewed',
        'Theme / colour palette reviewed',
        false,
        130
      ),
      (
        'sitter',
        'sitter_cake_smash_plan_reviewed',
        'Cake-smash plan reviewed, when relevant',
        false,
        140
      )
  )
  SELECT
    common_items.item_key,
    common_items.item_label,
    common_items.is_required,
    common_items.sort_order
  FROM common_items
  WHERE p_service_category IN (
    'maternity',
    'newborn',
    'sitter'
  )

  UNION ALL

  SELECT
    category_items.item_key,
    category_items.item_label,
    category_items.is_required,
    category_items.sort_order
  FROM category_items
  WHERE category_items.service_category =
        p_service_category

  ORDER BY sort_order, item_key
$$;

REVOKE ALL
ON FUNCTION public.lsh_preparation_taxonomy_v1(text)
FROM PUBLIC, anon, authenticated, service_role;

-- =====================================================================
-- Section C2 — Fail-fast taxonomy assertions
-- =====================================================================

DO $s10_slice3_taxonomy_assertions$
DECLARE
  v_category text;
  v_expected_count integer;
  v_actual_count integer;
  v_required_count integer;
BEGIN
  FOREACH v_category
  IN ARRAY ARRAY[
    'maternity',
    'newborn',
    'sitter'
  ]::text[]
  LOOP
    v_expected_count :=
      CASE v_category
        WHEN 'maternity' THEN 11
        WHEN 'newborn' THEN 11
        WHEN 'sitter' THEN 12
      END;

    SELECT
      count(*)::integer,
      count(*) FILTER (
        WHERE t.is_required
      )::integer
    INTO
      v_actual_count,
      v_required_count
    FROM public.lsh_preparation_taxonomy_v1(
      v_category
    ) t;

    IF v_actual_count <> v_expected_count THEN
      RAISE EXCEPTION
        'Sprint 10 Slice 3 taxonomy gate failed: category % expected % items, found %',
        v_category,
        v_expected_count,
        v_actual_count;
    END IF;

    IF v_required_count <> 8 THEN
      RAISE EXCEPTION
        'Sprint 10 Slice 3 taxonomy gate failed: category % expected 8 required items, found %',
        v_category,
        v_required_count;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.lsh_preparation_taxonomy_v1(
        v_category
      ) t
      GROUP BY t.item_key
      HAVING count(*) <> 1
    ) THEN
      RAISE EXCEPTION
        'Sprint 10 Slice 3 taxonomy gate failed: category % has duplicate item keys',
        v_category;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.lsh_preparation_taxonomy_v1(
        v_category
      ) t
      GROUP BY t.sort_order
      HAVING count(*) <> 1
    ) THEN
      RAISE EXCEPTION
        'Sprint 10 Slice 3 taxonomy gate failed: category % has duplicate sort order',
        v_category;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM public.lsh_preparation_taxonomy_v1(
      'unsupported'
    )
  ) THEN
    RAISE EXCEPTION
      'Sprint 10 Slice 3 taxonomy gate failed: unsupported category returned preparation items';
  END IF;
END
$s10_slice3_taxonomy_assertions$;

-- =====================================================================
-- Section C3 — Extend canonical preparation start with checklist v1
-- =====================================================================

CREATE OR REPLACE FUNCTION public.start_pre_shoot_preparation(
  p_booking_id uuid
)
RETURNS public.booking_preparations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_existing public.booking_preparations;
  v_preparation public.booking_preparations;
  v_schedule public.booking_shoot_schedules;

  v_actor uuid;
  v_preparation_stage_id uuid;

  v_state_count integer;
  v_has_existing boolean := false;

  v_service_category text;
  v_expected_item_count integer;
  v_actual_item_count integer;

  v_transitioned_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input and authentication boundary.
  -- ---------------------------------------------------------------

  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Serialize operational mutations for this booking.
  -- ---------------------------------------------------------------

  SELECT b.*
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Both frozen permissions remain independently required.
  -- ---------------------------------------------------------------

  IF NOT public.has_permission(
           v_booking.organization_id,
           'prep.write',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: prep.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'booking.stage.advance',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Exactly one canonical current journey state must exist.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states js
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT js.*
  INTO v_state
  FROM public.booking_journey_states js
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id
  FOR UPDATE;

  SELECT s.*
  INTO v_stage
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.id =
        v_state.current_stage_id
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve the single authoritative preparation instance, if any.
  -- ---------------------------------------------------------------

  SELECT p.*
  INTO v_existing
  FROM public.booking_preparations p
  WHERE p.organization_id =
        v_booking.organization_id
    AND p.booking_id =
        v_booking.id;

  v_has_existing := FOUND;

  -- ---------------------------------------------------------------
  -- Exact Stage 9 replay remains authorization-first and idempotent.
  --
  -- Slice 3 additionally requires the existing checklist to be the
  -- exact taxonomy-v1 structural snapshot for the authoritative
  -- booking-derived service category. Satisfaction state is ignored
  -- by this structural replay check.
  -- ---------------------------------------------------------------

  IF v_stage.stage_key = 'pre_shoot_preparation'
     AND v_stage.stage_order = 9 THEN

    IF NOT v_has_existing THEN
      RAISE EXCEPTION
        'start_pre_shoot_preparation: Stage 9 requires an authoritative preparation instance'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT package.service_category
    INTO v_service_category
    FROM public.quotation_line_items line
    JOIN public.commercial_package_versions version
      ON version.organization_id =
         line.organization_id
     AND version.id =
         line.source_package_version_id
    JOIN public.commercial_packages package
      ON package.organization_id =
         version.organization_id
     AND package.id =
         version.package_id
    WHERE line.organization_id =
          v_booking.organization_id
      AND line.quotation_id =
          v_booking.source_quotation_id
      AND line.line_type =
          'package';

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'start_pre_shoot_preparation: authoritative booking package category unavailable'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*)::integer
    INTO v_expected_item_count
    FROM public.lsh_preparation_taxonomy_v1(
      v_service_category
    );

    IF v_expected_item_count = 0 THEN
      RAISE EXCEPTION
        'start_pre_shoot_preparation: unsupported preparation service category'
        USING ERRCODE = '22023';
    END IF;

    SELECT count(*)::integer
    INTO v_actual_item_count
    FROM public.booking_preparation_items item
    WHERE item.organization_id =
          v_booking.organization_id
      AND item.preparation_id =
          v_existing.id;

    IF v_actual_item_count <> v_expected_item_count THEN
      RAISE EXCEPTION
        'start_pre_shoot_preparation: Stage 9 preparation checklist structure is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.lsh_preparation_taxonomy_v1(
        v_service_category
      ) expected
      FULL OUTER JOIN (
        SELECT item.*
        FROM public.booking_preparation_items item
        WHERE item.organization_id =
              v_booking.organization_id
          AND item.preparation_id =
              v_existing.id
      ) actual
        ON actual.item_key =
           expected.item_key
      WHERE expected.item_key IS NULL
         OR actual.id IS NULL
         OR actual.service_category
              IS DISTINCT FROM
            v_service_category
         OR actual.taxonomy_version
              IS DISTINCT FROM
            1::smallint
         OR actual.item_label
              IS DISTINCT FROM
            expected.item_label
         OR actual.is_required
              IS DISTINCT FROM
            expected.is_required
         OR actual.sort_order
              IS DISTINCT FROM
            expected.sort_order
    ) THEN
      RAISE EXCEPTION
        'start_pre_shoot_preparation: Stage 9 preparation checklist structure is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_existing;
  END IF;

  -- ---------------------------------------------------------------
  -- First execution remains legal only from canonical Stage 8.
  -- ---------------------------------------------------------------

  IF v_stage.stage_key <> 'booking_confirmed'
     OR v_stage.stage_order <> 8 THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: booking must be exactly Booking Confirmed or an exact Pre-Shoot Preparation replay'
      USING ERRCODE = '22023';
  END IF;

  IF v_has_existing THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: Stage 8 cannot already contain a preparation instance'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Latest schedule version must still be authoritative + reserved.
  -- ---------------------------------------------------------------

  SELECT s.*
  INTO v_schedule
  FROM public.booking_shoot_schedules s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.booking_id =
        v_booking.id
  ORDER BY s.schedule_version DESC
  LIMIT 1;

  IF NOT FOUND
     OR v_schedule.schedule_state <> 'reserved' THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: current authoritative reserved schedule required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Derive authoritative service category only after existing
  -- Stage-8 / reserved-schedule gates have passed.
  -- ---------------------------------------------------------------

  SELECT package.service_category
  INTO v_service_category
  FROM public.quotation_line_items line
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       line.organization_id
   AND version.id =
       line.source_package_version_id
  JOIN public.commercial_packages package
    ON package.organization_id =
       version.organization_id
   AND package.id =
       version.package_id
  WHERE line.organization_id =
        v_booking.organization_id
    AND line.quotation_id =
        v_booking.source_quotation_id
    AND line.line_type =
        'package';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: authoritative booking package category unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)::integer
  INTO v_expected_item_count
  FROM public.lsh_preparation_taxonomy_v1(
    v_service_category
  );

  IF v_expected_item_count = 0 THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: unsupported preparation service category'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve canonical Stage 9.
  -- ---------------------------------------------------------------

  SELECT s.id
  INTO v_preparation_stage_id
  FROM public.booking_journey_stages s
  WHERE s.organization_id =
        v_booking.organization_id
    AND s.stage_key =
        'pre_shoot_preparation'
    AND s.stage_order = 9
    AND s.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: canonical Pre-Shoot Preparation stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  -- ---------------------------------------------------------------
  -- Create authoritative preparation instance.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_preparations (
    organization_id,
    booking_id,
    started_at,
    started_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_transitioned_at,
    v_actor
  )
  RETURNING *
  INTO v_preparation;

  -- ---------------------------------------------------------------
  -- Snapshot the exact approved taxonomy-v1 checklist atomically.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_preparation_items (
    organization_id,
    preparation_id,
    service_category,
    taxonomy_version,
    item_key,
    item_label,
    is_required,
    sort_order,
    is_satisfied,
    satisfied_at,
    satisfied_by,
    created_at,
    created_by,
    updated_at,
    updated_by
  )
  SELECT
    v_booking.organization_id,
    v_preparation.id,
    v_service_category,
    1::smallint,
    taxonomy.item_key,
    taxonomy.item_label,
    taxonomy.is_required,
    taxonomy.sort_order,
    false,
    NULL,
    NULL,
    v_transitioned_at,
    v_actor,
    v_transitioned_at,
    v_actor
  FROM public.lsh_preparation_taxonomy_v1(
    v_service_category
  ) taxonomy;

  GET DIAGNOSTICS
    v_actual_item_count = ROW_COUNT;

  IF v_actual_item_count <> v_expected_item_count THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: preparation checklist instantiation failed'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Append dedicated Stage 8 -> 9 historical evidence.
  -- ---------------------------------------------------------------

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
    v_booking.organization_id,
    v_booking.id,
    v_state.current_stage_id,
    v_preparation_stage_id,
    'pre_shoot_preparation_started',
    v_transitioned_at,
    v_actor
  );

  -- ---------------------------------------------------------------
  -- Advance current journey state exactly once.
  -- ---------------------------------------------------------------

  UPDATE public.booking_journey_states js
  SET
    current_stage_id =
      v_preparation_stage_id,
    stage_entered_at =
      v_transitioned_at,
    version =
      js.version + 1,
    updated_at =
      v_transitioned_at,
    updated_by =
      v_actor
  WHERE js.organization_id =
        v_booking.organization_id
    AND js.booking_id =
        v_booking.id
    AND js.current_stage_id =
        v_state.current_stage_id
    AND js.version =
        v_state.version;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'start_pre_shoot_preparation: journey state changed during preparation start'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- Append one non-sensitive preparation-start audit event.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.pre_shoot_preparation_started',
    'booking',
    v_booking.id,
    false,
    jsonb_build_object(
      'journey_stage',
        'booking_confirmed',
      'journey_version',
        v_state.version
    ),
    jsonb_build_object(
      'journey_stage',
        'pre_shoot_preparation',
      'journey_version',
        v_state.version + 1
    ),
    jsonb_build_object(
      'preparation_id',
        v_preparation.id,
      'reserved_schedule_id',
        v_schedule.id,
      'reserved_schedule_version',
        v_schedule.schedule_version,
      'transition_key',
        'pre_shoot_preparation_started',
      'service_category',
        v_service_category,
      'taxonomy_version',
        1,
      'preparation_item_count',
        v_actual_item_count
    ),
    'application',
    NULL
  );

  RETURN v_preparation;
END
$$;

-- =====================================================================
-- Section C4 — Preserve start-preparation execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.start_pre_shoot_preparation(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.start_pre_shoot_preparation(uuid)
TO authenticated;

-- =====================================================================
-- Section D — Controlled preparation-item satisfaction mutation
-- =====================================================================

CREATE OR REPLACE FUNCTION public.update_pre_shoot_preparation_item(
  p_preparation_item_id uuid,
  p_satisfied boolean
)
RETURNS public.booking_preparation_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_organization_id uuid;
  v_booking_id uuid;

  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;
  v_old public.booking_preparation_items;
  v_row public.booking_preparation_items;

  v_actor uuid;
  v_state_count integer;
  v_changed_at timestamptz;
BEGIN
  -- ---------------------------------------------------------------
  -- Input / authentication boundary.
  -- ---------------------------------------------------------------

  IF p_preparation_item_id IS NULL THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: preparation_item_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_satisfied IS NULL THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: satisfied state is required'
      USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: authenticated actor required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Resolve immutable ownership without taking the item lock yet.
  --
  -- The canonical mutation lock order is:
  --   booking -> journey state -> preparation item.
  -- ---------------------------------------------------------------

  SELECT
    item.organization_id,
    preparation.booking_id
  INTO
    v_organization_id,
    v_booking_id
  FROM public.booking_preparation_items item
  JOIN public.booking_preparations preparation
    ON preparation.organization_id =
       item.organization_id
   AND preparation.id =
       item.preparation_id
  WHERE item.id =
        p_preparation_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: preparation item not found'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock authoritative booking first.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.organization_id =
        v_organization_id
    AND booking.id =
        v_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: authoritative booking unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id,
           'prep.write',
           v_booking.branch_id
         ) THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: prep.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock exactly one canonical journey state second.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: booking must have exactly one current journey state'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT state.*
  INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id =
        v_booking.organization_id
    AND state.booking_id =
        v_booking.id
  FOR UPDATE;

  SELECT stage.*
  INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id =
        v_booking.organization_id
    AND stage.id =
        v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: active current journey stage unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_key <> 'pre_shoot_preparation'
     OR v_stage.stage_order <> 9 THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: booking must be exactly Pre-Shoot Preparation'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Lock the authoritative item third.
  -- ---------------------------------------------------------------

  SELECT item.*
  INTO v_old
  FROM public.booking_preparation_items item
  JOIN public.booking_preparations preparation
    ON preparation.organization_id =
       item.organization_id
   AND preparation.id =
       item.preparation_id
  WHERE item.id =
        p_preparation_item_id
    AND item.organization_id =
        v_booking.organization_id
    AND preparation.booking_id =
        v_booking.id
  FOR UPDATE OF item;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: preparation item ownership changed'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Same-state retry is a true no-op.
  -- ---------------------------------------------------------------

  IF v_old.is_satisfied = p_satisfied THEN
    RETURN v_old;
  END IF;

  v_changed_at := now();

  -- ---------------------------------------------------------------
  -- Apply the one permitted mutable state transition.
  -- ---------------------------------------------------------------

  UPDATE public.booking_preparation_items item
  SET
    is_satisfied =
      p_satisfied,
    satisfied_at =
      CASE
        WHEN p_satisfied
          THEN v_changed_at
        ELSE NULL
      END,
    satisfied_by =
      CASE
        WHEN p_satisfied
          THEN v_actor
        ELSE NULL
      END,
    updated_at =
      v_changed_at,
    updated_by =
      v_actor
  WHERE item.organization_id =
        v_old.organization_id
    AND item.id =
        v_old.id
  RETURNING *
  INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_pre_shoot_preparation_item: preparation item changed during update'
      USING ERRCODE = '40001';
  END IF;

  -- ---------------------------------------------------------------
  -- One non-sensitive audit event per real state change.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.preparation_item_updated',
    'booking_preparation_item',
    v_row.id,
    false,
    jsonb_build_object(
      'is_satisfied',
        v_old.is_satisfied,
      'satisfied_at',
        v_old.satisfied_at,
      'satisfied_by',
        v_old.satisfied_by
    ),
    jsonb_build_object(
      'is_satisfied',
        v_row.is_satisfied,
      'satisfied_at',
        v_row.satisfied_at,
      'satisfied_by',
        v_row.satisfied_by
    ),
    jsonb_build_object(
      'booking_id',
        v_booking.id,
      'preparation_id',
        v_row.preparation_id,
      'item_key',
        v_row.item_key,
      'service_category',
        v_row.service_category,
      'taxonomy_version',
        v_row.taxonomy_version,
      'is_required',
        v_row.is_required
    ),
    'application',
    NULL
  );

  RETURN v_row;
END
$$;

-- =====================================================================
-- Section D2 — Public execution boundary
-- =====================================================================

REVOKE ALL
ON FUNCTION public.update_pre_shoot_preparation_item(
  uuid,
  boolean
)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.update_pre_shoot_preparation_item(
  uuid,
  boolean
)
TO authenticated;
