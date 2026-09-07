-- T1-F corrective migration
-- Non-completion evidence must never advance the training progress cursor.

CREATE OR REPLACE FUNCTION public.record_my_training_step(p_organization_id uuid, p_module_key text, p_version integer, p_step_key text, p_event_type training_step_event_type, p_result training_step_event_result, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_member_id uuid;
  v_module_id uuid;
  v_profile_id uuid;
  v_step_type public.training_step_type;
  v_event_id uuid;
  v_metadata jsonb;
BEGIN
  v_member_id :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_member_id IS NULL THEN
    RAISE EXCEPTION
      'Active organization membership is required';
  END IF;

  v_metadata :=
    COALESCE(
      p_metadata,
      '{}'::jsonb
    );

  IF jsonb_typeof(v_metadata) <> 'object' THEN
    RAISE EXCEPTION
      'Training metadata must be a JSON object';
  END IF;

  IF octet_length(v_metadata::text) > 4096 THEN
    RAISE EXCEPTION
      'Training metadata exceeds the allowed size';
  END IF;

  IF p_event_type NOT IN (
    'step_viewed'::public.training_step_event_type,
    'step_completed'::public.training_step_event_type,
    'action_attempted'::public.training_step_event_type,
    'action_failed'::public.training_step_event_type,
    'hint_opened'::public.training_step_event_type,
    'training_step_broken'::public.training_step_event_type
  ) THEN
    RAISE EXCEPTION
      'This training event requires a dedicated server validator';
  END IF;

  SELECT
    tm.id
  INTO
    v_module_id
  FROM public.training_modules tm
  WHERE tm.organization_id =
        p_organization_id
    AND tm.module_key =
        p_module_key
    AND tm.version =
        p_version
    AND tm.active = true
    AND (
      tm.role_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.member_role_grants g
        LEFT JOIN public.branches b
          ON b.id = g.branch_id
         AND b.organization_id = g.organization_id
         AND b.status = 'active'::public.branch_status
         AND b.deleted_at IS NULL
        WHERE g.organization_id =
              p_organization_id
          AND g.organization_member_id =
              v_member_id
          AND g.role_id =
              tm.role_id
          AND g.revoked_at IS NULL
          AND (
            g.branch_id IS NULL
            OR b.id IS NOT NULL
          )
      )
    )
    AND EXISTS (
      SELECT 1
      FROM public.member_role_grants g
      LEFT JOIN public.branches b
        ON b.id = g.branch_id
       AND b.organization_id = g.organization_id
       AND b.status = 'active'::public.branch_status
       AND b.deleted_at IS NULL
      WHERE g.organization_id =
            p_organization_id
        AND g.organization_member_id =
            v_member_id
        AND g.revoked_at IS NULL
        AND (
          g.branch_id IS NULL
          OR b.id IS NOT NULL
        )
    );

  IF v_module_id IS NULL THEN
    RAISE EXCEPTION
      'Training module is not available for this member';
  END IF;

  SELECT
    mtp.id
  INTO
    v_profile_id
  FROM public.member_training_profiles mtp
  WHERE mtp.organization_id =
        p_organization_id
    AND mtp.organization_member_id =
        v_member_id
    AND mtp.training_module_id =
        v_module_id;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION
      'Training module must be started before recording progress';
  END IF;

  SELECT
    tms.step_type
  INTO
    v_step_type
  FROM public.training_module_steps tms
  WHERE tms.training_module_id =
        v_module_id
    AND tms.step_key =
        p_step_key;

  IF v_step_type IS NULL THEN
    RAISE EXCEPTION
      'Unknown training step';
  END IF;

  IF v_step_type IN (
       'practice'::public.training_step_type,
       'knowledge_check'::public.training_step_type
     )
     AND (
       p_result = 'pass'::public.training_step_event_result
       OR p_event_type =
          'step_completed'::public.training_step_event_type
     ) THEN
    RAISE EXCEPTION
      'Protected practice or knowledge-check completion requires a dedicated server validator';
  END IF;

  IF p_event_type =
       'step_completed'::public.training_step_event_type
     AND p_result <>
         'pass'::public.training_step_event_result THEN
    RAISE EXCEPTION
      'A completed training step must have a PASS result';
  END IF;

  INSERT INTO public.training_step_events (
    organization_id,
    organization_member_id,
    member_training_profile_id,
    step_key,
    event_type,
    result,
    metadata
  )
  VALUES (
    p_organization_id,
    v_member_id,
    v_profile_id,
    p_step_key,
    p_event_type,
    p_result,
    v_metadata
  )
  RETURNING id
  INTO v_event_id;

  UPDATE public.member_training_profiles mtp
  SET
    current_step_key =
      CASE
        WHEN EXISTS (
          SELECT 1
          FROM public.training_module_steps tms_completion
          WHERE tms_completion.training_module_id =
                v_module_id
            AND tms_completion.step_key =
                p_step_key
            AND tms_completion.completion_event_type =
                p_event_type
            AND tms_completion.completion_result
                IS NOT DISTINCT FROM p_result
        )
        THEN (
          SELECT tms_cursor.step_key
          FROM public.training_module_steps tms_cursor
          WHERE tms_cursor.training_module_id =
                v_module_id
            AND (
              tms_cursor.step_key =
                p_step_key
              OR tms_cursor.step_key =
                mtp.current_step_key
            )
          ORDER BY
            tms_cursor.step_order DESC
          LIMIT 1
        )
        ELSE mtp.current_step_key
      END,

    status =
      CASE
        WHEN mtp.status =
             'complete'::public.training_profile_status
          THEN mtp.status
        ELSE
          'in_progress'::public.training_profile_status
      END

  WHERE mtp.id =
        v_profile_id;

  RETURN v_event_id;
END;
$function$;
