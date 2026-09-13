-- =====================================================================
-- Optional album and frame production
-- =====================================================================
--
-- Most newborn sessions sell no album and no frame. The journey still has
-- to pass through the production stage, so before this migration every
-- photo-only booking had to be walked through a stage that did not apply
-- to it, and the balance gate on entering that stage could strand it.
--
-- Two changes:
--
-- 1. The money gate moves from ENTERING production to ORDERING an item.
--    Committing to produce something is the moment the studio spends
--    money, so that is the honest place for it. Entering the stage is now
--    free, which is what lets a photo-only booking pass straight through.
--
-- 2. A fourth milestone type, not_applicable, records "this booking sells
--    no album or frame". It is refused once any item or other milestone
--    exists, so it can never be used to paper over real production. The
--    review gate then accepts either a studio handover or that record.
--
-- The result: one button in Delivery marks a booking as having no
-- physical product and moves it on, with real evidence behind it rather
-- than a skipped stage.
-- =====================================================================

DO $precondition$
BEGIN
  IF to_regprocedure('public.mark_booking_album_frame_production(uuid)') IS NULL THEN
    RAISE EXCEPTION 'precondition: mark_booking_album_frame_production is missing';
  END IF;

  IF to_regprocedure('public.booking_outstanding_inr(uuid, uuid)') IS NULL THEN
    RAISE EXCEPTION 'precondition: booking_outstanding_inr is missing';
  END IF;

  IF (SELECT prosrc FROM pg_proc
      WHERE oid = to_regprocedure('public.mark_booking_album_frame_production(uuid)'))
     NOT LIKE '%album and frame production is blocked until it is settled%' THEN
    RAISE EXCEPTION 'precondition: expected the balance gate on the production entry gate';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'booking_production_milestones_type_chk'
  ) THEN
    RAISE EXCEPTION 'precondition: milestone type check constraint is missing';
  END IF;
END;
$precondition$;

-- =====================================================================
-- Section A - Milestone type widened
-- =====================================================================

ALTER TABLE public.booking_production_milestones
  DROP CONSTRAINT booking_production_milestones_type_chk;

ALTER TABLE public.booking_production_milestones
  ADD CONSTRAINT booking_production_milestones_type_chk
  CHECK (milestone_type IN ('dispatched', 'received', 'handed_over', 'not_applicable'));

-- =====================================================================
-- Section B - Production entry gate: balance gate removed
-- =====================================================================

DROP FUNCTION IF EXISTS public.mark_booking_album_frame_production(uuid);

CREATE FUNCTION public.mark_booking_album_frame_production(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $gate_album_frame_production$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 17 AND v_stage.stage_key = 'delivered')
    OR
    (v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_album_frame_production: booking must be exactly Delivered or Album / Frame Production replay'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_inbound_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id = transition_row.organization_id
   AND source_stage.id = transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND transition_row.transition_key = 'delivered'
    AND source_stage.stage_order = 16
    AND source_stage.stage_key = 'pixieset_gallery_ready'
    AND destination_stage.stage_order = 17
    AND destination_stage.stage_key = 'delivered';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical Delivered transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 18 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'album_frame_production'
      AND destination_stage.stage_order = 18
      AND destination_stage.stage_key = 'album_frame_production';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_album_frame_production: canonical Album / Frame Production transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 18
    AND stage.stage_key = 'album_frame_production'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: canonical destination stage is unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  INSERT INTO public.booking_stage_transitions (
    organization_id, booking_id, from_stage_id, to_stage_id,
    transition_key, transitioned_at, transitioned_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id,
    v_state.current_stage_id, v_destination_stage_id,
    'album_frame_production', v_transitioned_at, v_actor
  );

  UPDATE public.booking_journey_states state
  SET current_stage_id = v_destination_stage_id,
      stage_entered_at = v_transitioned_at,
      version = state.version + 1,
      updated_at = v_transitioned_at,
      updated_by = v_actor
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
    AND state.current_stage_id = v_state.current_stage_id
    AND state.version = v_state.version;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  IF v_updated_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_album_frame_production: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.album_frame_production', 'booking', v_booking.id, false,
    jsonb_build_object('journey_stage', v_stage.stage_key, 'journey_version', v_state.version),
    jsonb_build_object('journey_stage', 'album_frame_production', 'journey_version', v_state.version + 1),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'album_frame_production',
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application', NULL
  );

  RETURN v_booking;
END;
$gate_album_frame_production$;

REVOKE ALL ON FUNCTION public.mark_booking_album_frame_production(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_booking_album_frame_production(uuid) TO authenticated;

-- =====================================================================
-- Section C - Production item RPC: balance gate added
-- =====================================================================

DROP FUNCTION IF EXISTS public.record_booking_production_item(uuid, text, text, integer, text);

CREATE FUNCTION public.record_booking_production_item(
  p_booking_id uuid,
  p_item_type text,
  p_description text,
  p_quantity integer DEFAULT 1,
  p_vendor_name text DEFAULT NULL
)
RETURNS public.booking_production_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_production_item$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_item_type text;
  v_description text;
  v_vendor text;
  v_ordinal integer;
  v_result public.booking_production_items;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_production_item: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'production.manage', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_production_item: production.manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_production_item: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_item_type IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: item type is required' USING ERRCODE = '22023';
  END IF;

  v_item_type := btrim(p_item_type);

  IF v_item_type = ''
     OR btrim(v_item_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_item_type <> btrim(v_item_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_item_type) > 16
     OR v_item_type ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_production_item: item type is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_item_type NOT IN ('album', 'frame', 'other') THEN
    RAISE EXCEPTION 'record_booking_production_item: item type must be album, frame or other'
      USING ERRCODE = '22023';
  END IF;

  IF p_description IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_item: description is required' USING ERRCODE = '22023';
  END IF;

  v_description := btrim(p_description);

  IF v_description = ''
     OR btrim(v_description, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_description <> btrim(v_description, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_description) > 300
     OR v_description ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_production_item: description is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_description IS NOT NULL
     AND (
       v_description ~* '^(bearer|basic)[[:space:]]+'
       OR v_description ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_description ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_item: description must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  v_vendor := NULLIF(btrim(COALESCE(p_vendor_name, '')), '');

  IF v_vendor IS NOT NULL
     AND (
       btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_vendor <> btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_vendor) > 160
       OR v_vendor ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_vendor := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_item: vendor name is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_vendor IS NOT NULL
     AND (
       v_vendor ~* '^(bearer|basic)[[:space:]]+'
       OR v_vendor ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_vendor ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_item: vendor name must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 100 THEN
    RAISE EXCEPTION 'record_booking_production_item: quantity is out of range'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_production_item: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_production_item: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_item: booking must be exactly Album / Frame Production'
      USING ERRCODE = '22023';
  END IF;

  -- Balance policy: committing to produce a physical item is the moment
  -- the studio spends money on a booking, so that is where the money gate
  -- sits. Entering the production stage is free, which is what lets a
  -- photo-only booking pass straight through.
  IF public.booking_outstanding_inr(
       v_booking.organization_id, v_booking.id
     ) > 0
     AND NOT public.has_permission(
               v_booking.organization_id,
               'delivery.balance_override',
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_production_item: booking has an outstanding balance; album and frame production is blocked until it is settled'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.booking_production_milestones milestone
    WHERE milestone.organization_id = v_booking.organization_id
      AND milestone.booking_id = v_booking.id
      AND milestone.milestone_type = 'dispatched'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_item: production has already been dispatched for this booking'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(max(item.item_ordinal), 0) + 1 INTO v_ordinal
  FROM public.booking_production_items item
  WHERE item.organization_id = v_booking.organization_id
    AND item.booking_id = v_booking.id;

  IF v_ordinal > 100 THEN
    RAISE EXCEPTION 'record_booking_production_item: production item limit reached'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.booking_production_items (
    organization_id, booking_id, item_ordinal, item_type, description,
    quantity, vendor_name, recorded_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_ordinal, v_item_type, v_description,
    p_quantity, v_vendor, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.production_item_recorded', 'booking', v_booking.id, false,
    NULL,
    jsonb_build_object('item_ordinal', v_ordinal, 'item_type', v_item_type),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'production_item_id', v_result.id,
      'item_ordinal', v_ordinal,
      'item_type', v_item_type,
      'quantity', p_quantity,
      'in_house', (v_vendor IS NULL)
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_production_item$;

REVOKE ALL ON FUNCTION public.record_booking_production_item(uuid, text, text, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_booking_production_item(uuid, text, text, integer, text) TO authenticated;

-- =====================================================================
-- Section D - Milestone RPC: not_applicable accepted
-- =====================================================================

DROP FUNCTION IF EXISTS public.record_booking_production_milestone(uuid, text, text, timestamptz, text, text);

CREATE FUNCTION public.record_booking_production_milestone(
  p_booking_id uuid,
  p_milestone_type text,
  p_vendor_name text DEFAULT NULL,
  p_expected_at timestamptz DEFAULT NULL,
  p_detail_note text DEFAULT NULL,
  p_collected_by_name text DEFAULT NULL
)
RETURNS public.booking_production_milestones
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $record_production_milestone$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_type text;
  v_vendor text;
  v_detail text;
  v_collected_by text;
  v_approved_count integer;
  v_open_proof_count integer;
  v_item_count integer;
  v_result public.booking_production_milestones;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_production_milestone: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'production.manage', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: production.manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  IF p_milestone_type IS NULL THEN
    RAISE EXCEPTION 'record_booking_production_milestone: milestone type is required' USING ERRCODE = '22023';
  END IF;

  v_type := btrim(p_milestone_type);

  IF v_type = ''
     OR btrim(v_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
     OR v_type <> btrim(v_type, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
     OR char_length(v_type) > 24
     OR v_type ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'record_booking_production_milestone: milestone type is invalid' USING ERRCODE = '22023';
  END IF;

  IF v_type NOT IN ('dispatched', 'received', 'handed_over', 'not_applicable') THEN
    RAISE EXCEPTION
      'record_booking_production_milestone: milestone type must be dispatched, received, handed_over or not_applicable'
      USING ERRCODE = '22023';
  END IF;

  v_vendor := NULLIF(btrim(COALESCE(p_vendor_name, '')), '');

  IF v_vendor IS NOT NULL
     AND (
       btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_vendor <> btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_vendor) > 160
       OR v_vendor ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_vendor, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_vendor := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_milestone: vendor name is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_vendor IS NOT NULL
     AND (
       v_vendor ~* '^(bearer|basic)[[:space:]]+'
       OR v_vendor ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_vendor ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: vendor name must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  v_detail := NULLIF(btrim(COALESCE(p_detail_note, '')), '');

  IF v_detail IS NOT NULL
     AND (
       btrim(v_detail, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_detail <> btrim(v_detail, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_detail) > 500
       OR v_detail ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_detail, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_detail := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_milestone: detail note is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_detail IS NOT NULL
     AND (
       v_detail ~* '^(bearer|basic)[[:space:]]+'
       OR v_detail ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_detail ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: detail note must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  v_collected_by := NULLIF(btrim(COALESCE(p_collected_by_name, '')), '');

  IF v_collected_by IS NOT NULL
     AND (
       btrim(v_collected_by, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = ''
       OR v_collected_by <> btrim(v_collected_by, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000')
       OR char_length(v_collected_by) > 160
       OR v_collected_by ~ '[[:cntrl:]]'
     ) THEN
    IF btrim(v_collected_by, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000') = '' THEN
      v_collected_by := NULL;
    ELSE
      RAISE EXCEPTION 'record_booking_production_milestone: collected by name is invalid' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_collected_by IS NOT NULL
     AND (
       v_collected_by ~* '^(bearer|basic)[[:space:]]+'
       OR v_collected_by ~* '^(sk-[A-Za-z0-9_-]{16,}|sk_(live|test)_|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)'
       OR v_collected_by ~* '(^|[^[:alnum:]_])(token|access[_-]?token|secret|password|passwd|api[_-]?key|signature|sig)[[:space:]]*[:=]'
     ) THEN
    RAISE EXCEPTION 'record_booking_production_milestone: collected by name must not contain credential material'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'record_booking_production_milestone: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'record_booking_production_milestone: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production'
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_milestone: booking must be exactly Album / Frame Production'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.booking_production_milestones milestone
    WHERE milestone.organization_id = v_booking.organization_id
      AND milestone.booking_id = v_booking.id
      AND milestone.milestone_type = v_type
  ) THEN
    RAISE EXCEPTION
      'record_booking_production_milestone: this production milestone is already recorded'
      USING ERRCODE = '22023';
  END IF;

  IF v_type = 'not_applicable' THEN
    -- The booking sells no album and no frame. Declaring that is only
    -- honest while nothing has been ordered, so it is refused once any
    -- production item or milestone exists.
    IF v_vendor IS NOT NULL OR p_expected_at IS NOT NULL OR v_collected_by IS NOT NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: vendor, expected date and collected_by_name do not apply to not_applicable'
        USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.booking_production_items item
      WHERE item.organization_id = v_booking.organization_id
        AND item.booking_id = v_booking.id
    ) THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: this booking already has production items, so production is applicable'
        USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.booking_production_milestones milestone
      WHERE milestone.organization_id = v_booking.organization_id
        AND milestone.booking_id = v_booking.id
        AND milestone.milestone_type <> 'not_applicable'
    ) THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: production has already begun for this booking'
        USING ERRCODE = '22023';
    END IF;

  ELSIF v_type = 'dispatched' THEN
    IF v_collected_by IS NOT NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: collected_by_name applies only to handed_over'
        USING ERRCODE = '22023';
    END IF;

    SELECT count(*) INTO v_item_count
    FROM public.booking_production_items item
    WHERE item.organization_id = v_booking.organization_id
      AND item.booking_id = v_booking.id;

    IF v_item_count < 1 THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: record the production items before dispatching'
        USING ERRCODE = '22023';
    END IF;

    SELECT count(*) INTO v_open_proof_count
    FROM public.booking_production_proofs proof
    WHERE proof.organization_id = v_booking.organization_id
      AND proof.booking_id = v_booking.id
      AND NOT EXISTS (
        SELECT 1 FROM public.booking_production_proof_responses response WHERE response.proof_id = proof.id
      );

    IF v_open_proof_count > 0 THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: a proof is still awaiting a client response'
        USING ERRCODE = '22023';
    END IF;

    SELECT count(*) INTO v_approved_count
    FROM public.booking_production_proof_responses response
    WHERE response.organization_id = v_booking.organization_id
      AND response.booking_id = v_booking.id
      AND response.outcome = 'approved';

    IF v_approved_count < 1 THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: the family must approve a proof before production is dispatched'
        USING ERRCODE = '22023';
    END IF;

    IF p_expected_at IS NOT NULL AND p_expected_at <= now() THEN
      RAISE EXCEPTION 'record_booking_production_milestone: expected date must be in the future'
        USING ERRCODE = '22023';
    END IF;

  ELSIF v_type = 'received' THEN
    IF v_vendor IS NOT NULL OR p_expected_at IS NOT NULL OR v_collected_by IS NOT NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: vendor, expected date and collected_by_name do not apply to received'
        USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.booking_production_milestones milestone
      WHERE milestone.organization_id = v_booking.organization_id
        AND milestone.booking_id = v_booking.id
        AND milestone.milestone_type = 'dispatched'
    ) THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: production must be dispatched before it can be received'
        USING ERRCODE = '22023';
    END IF;

  ELSE
    IF v_vendor IS NOT NULL OR p_expected_at IS NOT NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: vendor and expected date do not apply to handed_over'
        USING ERRCODE = '22023';
    END IF;

    IF v_collected_by IS NULL THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: record who collected the items from the studio'
        USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.booking_production_milestones milestone
      WHERE milestone.organization_id = v_booking.organization_id
        AND milestone.booking_id = v_booking.id
        AND milestone.milestone_type = 'received'
    ) THEN
      RAISE EXCEPTION
        'record_booking_production_milestone: production must be received before studio handover'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  INSERT INTO public.booking_production_milestones (
    organization_id, booking_id, milestone_type, vendor_name, expected_at,
    detail_note, collected_by_name, occurred_at, recorded_by, created_at, created_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id, v_type, v_vendor, p_expected_at,
    v_detail, v_collected_by, now(), v_actor, now(), v_actor
  )
  RETURNING * INTO v_result;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.production_' || v_type, 'booking', v_booking.id, false,
    NULL,
    jsonb_build_object('milestone_type', v_type),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'production_milestone_id', v_result.id,
      'milestone_type', v_type,
      'in_house', (v_type = 'dispatched' AND v_vendor IS NULL),
      'expected_at_present', (p_expected_at IS NOT NULL)
    ),
    'application', NULL
  );

  RETURN v_result;
END;
$record_production_milestone$;

REVOKE ALL ON FUNCTION public.record_booking_production_milestone(uuid, text, text, timestamptz, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_booking_production_milestone(uuid, text, text, timestamptz, text, text) TO authenticated;

-- =====================================================================
-- Section E - Review gate: handover or not applicable
-- =====================================================================

DROP FUNCTION IF EXISTS public.mark_booking_review_requested(uuid);

CREATE FUNCTION public.mark_booking_review_requested(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $gate_review_requested$
DECLARE
  v_booking public.bookings;
  v_actor uuid;
  v_state public.booking_journey_states;
  v_state_count integer;
  v_stage public.booking_journey_stages;
  v_inbound_count integer;
  v_replay_count integer;
  v_destination_stage_id uuid;
  v_transitioned_at timestamptz;
  v_updated_count integer;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking_id is required' USING ERRCODE = '22023';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: authenticated actor required' USING ERRCODE = '42501';
  END IF;

  -- Lock order 1: booking synchronization root.
  SELECT booking.* INTO v_booking
  FROM public.bookings booking
  WHERE booking.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking not found' USING ERRCODE = '22023';
  END IF;

  v_actor := public.current_organization_member(v_booking.organization_id);

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
           v_booking.organization_id, 'booking.stage.advance', v_booking.branch_id
         ) THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking.stage.advance permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id, v_booking.branch_id
             ) THEN
    RAISE EXCEPTION 'mark_booking_review_requested: booking branch scope required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_state_count
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id;

  IF v_state_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_review_requested: canonical journey state is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lock order 2: journey state.
  SELECT state.* INTO v_state
  FROM public.booking_journey_states state
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
  FOR UPDATE;

  SELECT stage.* INTO v_stage
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.id = v_state.current_stage_id
    AND stage.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'mark_booking_review_requested: canonical current stage is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (
    (v_stage.stage_order = 18 AND v_stage.stage_key = 'album_frame_production')
    OR
    (v_stage.stage_order = 19 AND v_stage.stage_key = 'review_requested')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_review_requested: booking must be exactly Album / Frame Production or Review Requested replay'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_inbound_count
  FROM public.booking_stage_transitions transition_row
  JOIN public.booking_journey_stages source_stage
    ON source_stage.organization_id = transition_row.organization_id
   AND source_stage.id = transition_row.from_stage_id
  JOIN public.booking_journey_stages destination_stage
    ON destination_stage.organization_id = transition_row.organization_id
   AND destination_stage.id = transition_row.to_stage_id
  WHERE transition_row.organization_id = v_booking.organization_id
    AND transition_row.booking_id = v_booking.id
    AND transition_row.transition_key = 'album_frame_production'
    AND source_stage.stage_order = 17
    AND source_stage.stage_key = 'delivered'
    AND destination_stage.stage_order = 18
    AND destination_stage.stage_key = 'album_frame_production';

  IF v_inbound_count < 1 THEN
    RAISE EXCEPTION 'mark_booking_review_requested: canonical Album / Frame Production transition history is invalid'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage.stage_order = 19 THEN
    SELECT count(*) INTO v_replay_count
    FROM public.booking_stage_transitions transition_row
    JOIN public.booking_journey_stages destination_stage
      ON destination_stage.organization_id = transition_row.organization_id
     AND destination_stage.id = transition_row.to_stage_id
    WHERE transition_row.organization_id = v_booking.organization_id
      AND transition_row.booking_id = v_booking.id
      AND transition_row.transition_key = 'review_requested'
      AND destination_stage.stage_order = 19
      AND destination_stage.stage_key = 'review_requested';

    IF v_replay_count < 1 THEN
      RAISE EXCEPTION
        'mark_booking_review_requested: canonical Review Requested transition history is invalid'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN v_booking;
  END IF;

  -- A booking leaves production either because the family collected
  -- something, or because there was nothing to collect. Both are recorded
  -- milestones, so the evidence trail stays complete either way.
  IF NOT EXISTS (
    SELECT 1 FROM public.booking_production_milestones milestone
    WHERE milestone.organization_id = v_booking.organization_id
      AND milestone.booking_id = v_booking.id
      AND milestone.milestone_type IN ('handed_over', 'not_applicable')
  ) THEN
    RAISE EXCEPTION
      'mark_booking_review_requested: booking requires a recorded studio handover, or a record that no album or frame was sold'
      USING ERRCODE = '22023';
  END IF;

  SELECT stage.id INTO v_destination_stage_id
  FROM public.booking_journey_stages stage
  WHERE stage.organization_id = v_booking.organization_id
    AND stage.stage_order = 19
    AND stage.stage_key = 'review_requested'
    AND stage.is_active;

  IF v_destination_stage_id IS NULL THEN
    RAISE EXCEPTION 'mark_booking_review_requested: canonical destination stage is unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_transitioned_at := now();

  INSERT INTO public.booking_stage_transitions (
    organization_id, booking_id, from_stage_id, to_stage_id,
    transition_key, transitioned_at, transitioned_by
  )
  VALUES (
    v_booking.organization_id, v_booking.id,
    v_state.current_stage_id, v_destination_stage_id,
    'review_requested', v_transitioned_at, v_actor
  );

  UPDATE public.booking_journey_states state
  SET current_stage_id = v_destination_stage_id,
      stage_entered_at = v_transitioned_at,
      version = state.version + 1,
      updated_at = v_transitioned_at,
      updated_by = v_actor
  WHERE state.organization_id = v_booking.organization_id
    AND state.booking_id = v_booking.id
    AND state.current_stage_id = v_state.current_stage_id
    AND state.version = v_state.version;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  IF v_updated_count <> 1 THEN
    RAISE EXCEPTION 'mark_booking_review_requested: journey state changed during advancement'
      USING ERRCODE = '40001';
  END IF;

  PERFORM public.append_audit_event(
    v_booking.organization_id, v_booking.branch_id,
    'booking.review_stage', 'booking', v_booking.id, false,
    jsonb_build_object('journey_stage', v_stage.stage_key, 'journey_version', v_state.version),
    jsonb_build_object('journey_stage', 'review_requested', 'journey_version', v_state.version + 1),
    jsonb_build_object(
      'booking_id', v_booking.id,
      'transition_key', 'review_requested',
      'prior_journey_version', v_state.version,
      'resulting_journey_version', v_state.version + 1
    ),
    'application', NULL
  );

  RETURN v_booking;
END;
$gate_review_requested$;

REVOKE ALL ON FUNCTION public.mark_booking_review_requested(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_booking_review_requested(uuid) TO authenticated;

-- =====================================================================
-- Section F - Postconditions
-- =====================================================================

DO $postcondition$
DECLARE
  v_gate_src text;
  v_item_src text;
  v_ms_src text;
  v_rev_src text;
BEGIN
  SELECT prosrc INTO v_gate_src FROM pg_proc
  WHERE oid = to_regprocedure('public.mark_booking_album_frame_production(uuid)');

  IF v_gate_src LIKE '%outstanding balance%' THEN
    RAISE EXCEPTION 'postcondition: balance gate still present on the production entry gate';
  END IF;

  SELECT prosrc INTO v_item_src FROM pg_proc
  WHERE oid = to_regprocedure('public.record_booking_production_item(uuid, text, text, integer, text)');

  IF v_item_src NOT LIKE '%album and frame production is blocked until it is settled%' THEN
    RAISE EXCEPTION 'postcondition: balance gate missing on the production item RPC';
  END IF;

  SELECT prosrc INTO v_ms_src FROM pg_proc
  WHERE oid = to_regprocedure('public.record_booking_production_milestone(uuid, text, text, timestamptz, text, text)');

  IF v_ms_src NOT LIKE '%not_applicable%' THEN
    RAISE EXCEPTION 'postcondition: milestone RPC does not accept not_applicable';
  END IF;

  SELECT prosrc INTO v_rev_src FROM pg_proc
  WHERE oid = to_regprocedure('public.mark_booking_review_requested(uuid)');

  IF v_rev_src NOT LIKE '%no album or frame was sold%' THEN
    RAISE EXCEPTION 'postcondition: review gate does not accept not_applicable';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'booking_production_milestones_type_chk'
      AND pg_get_constraintdef(oid) LIKE '%not_applicable%'
  ) THEN
    RAISE EXCEPTION 'postcondition: milestone type constraint was not widened';
  END IF;
END;
$postcondition$;
