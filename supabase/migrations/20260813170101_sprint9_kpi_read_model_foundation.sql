-- =====================================================================
-- Sprint 9 — Advance Payment, Booking Confirmation & KPI Foundation
-- Slice 3 — Founder KPI / Read Model Foundation
--
-- PURPOSE
--
-- Establish authoritative, permission-aware SQL KPI read models.
-- Browser React code must not calculate canonical business truth from
-- raw operational rows.
--
-- CANONICAL SOURCES ONLY
--
--   public.leads
--   public.quotations
--   public.bookings
--   public.booking_journey_states
--   public.booking_stage_transitions
--   public.booking_journey_stages
--   public.booking_payment_requirements
--   public.booking_payments
--   public.booking_payment_reversals
--
-- No legacy mock/dashboard state is authoritative.
--
-- FINANCIAL LANGUAGE
--
--   Accepted Value      != revenue
--   Payments Collected  != revenue
--
-- Revenue recognition is explicitly outside Sprint 9.
-- No KPI/read-model field may be named or represented as revenue.
--
-- =====================================================================
-- SECURITY CONTRACT
-- =====================================================================
--
-- Permission:
--
--   kpi.read
--
-- Initial role grant:
--
--   founder
--
-- Public read boundary:
--
--   authenticated bearer
--     ->
--   SECURITY DEFINER read RPC
--     ->
--   active organization membership
--     ->
--   kpi.read
--     ->
--   branch-scope enforcement
--     ->
--   aggregate-only result
--
-- No raw KPI tables/views are granted to browser roles.
-- No service-role browser path.
--
-- If p_branch_id IS NULL:
--   caller must possess organization-wide kpi.read.
--
-- If p_branch_id IS NOT NULL:
--   branch must belong to the organization and caller must have
--   kpi.read for that branch.
--
-- =====================================================================
-- RPC 1 — get_founder_kpi_summary
-- =====================================================================
--
-- Frozen signature:
--
-- public.get_founder_kpi_summary(
--   p_organization_id uuid,
--   p_period_start timestamptz,
--   p_period_end timestamptz,
--   p_branch_id uuid DEFAULT NULL
-- )
--
-- Period semantics:
--
--   [p_period_start, p_period_end)
--
-- Both bounds are required.
-- p_period_start must be strictly earlier than p_period_end.
--
-- Exact return contract:
--
--   organization_id uuid
--   branch_id uuid
--   period_start timestamptz
--   period_end timestamptz
--
--   new_inquiries_count bigint
--
--   quotations_sent_count bigint
--   quoted_value_inr bigint
--
--   quotations_accepted_count bigint
--   accepted_value_inr bigint
--
--   bookings_created_count bigint
--   bookings_confirmed_count bigint
--
--   payments_collected_inr bigint
--
--   sent_quote_cohort_accepted_count bigint
--   sent_quote_acceptance_rate_pct numeric(7,2)
--
--   inquiry_cohort_accepted_count bigint
--   inquiry_to_accepted_quote_rate_pct numeric(7,2)
--
--   accepted_quote_cohort_booked_count bigint
--   accepted_quote_to_booking_rate_pct numeric(7,2)
--
--   booking_cohort_confirmed_count bigint
--   booking_to_confirmed_rate_pct numeric(7,2)
--
--   required_advance_as_of_end_inr bigint
--   valid_collected_as_of_end_inr bigint
--   advance_outstanding_as_of_end_inr bigint
--
--   advance_satisfied_bookings_as_of_end_count bigint
--   advance_pending_stage_as_of_end_count bigint
--   booking_confirmed_stage_as_of_end_count bigint
--   confirmed_with_advance_shortfall_as_of_end_count bigint
--
-- ---------------------------------------------------------------------
-- Period-event definitions
-- ---------------------------------------------------------------------
--
-- new_inquiries_count
--   leads.created_at inside [start,end)
--   A later lead status change does not rewrite the inquiry event.
--
-- quotations_sent_count
--   quotations.sent_at inside [start,end)
--
-- quoted_value_inr
--   SUM(quoted_total_inr) for quotations sent inside [start,end)
--
-- quotations_accepted_count
--   quotations.accepted_at inside [start,end)
--
-- accepted_value_inr
--   SUM(quoted_total_inr) for quotations accepted inside [start,end)
--
-- bookings_created_count
--   bookings.created_at inside [start,end)
--
-- bookings_confirmed_count
--   advance_satisfied booking-stage transitions whose transitioned_at
--   is inside [start,end)
--
-- payments_collected_inr
--   SUM(payment.amount_inr) for payments with received_at inside
--   [start,end) that had NOT been reversed before p_period_end.
--
-- A reversal after p_period_end must not rewrite the historical report.
--
-- ---------------------------------------------------------------------
-- Cohort conversion definitions
-- ---------------------------------------------------------------------
--
-- sent_quote_acceptance:
--   denominator = quotations sent inside [start,end)
--   numerator   = those same quotations accepted before p_period_end
--
-- inquiry_to_accepted_quote:
--   denominator = leads created inside [start,end)
--   numerator   = distinct cohort leads with at least one quotation
--                 linked through quotations.lead_id and accepted before
--                 p_period_end
--
-- accepted_quote_to_booking:
--   denominator = quotations accepted inside [start,end)
--   numerator   = those same quotations having a canonical booking
--                 created before p_period_end
--
-- booking_to_confirmed:
--   denominator = bookings created inside [start,end)
--   numerator   = those same bookings having an advance_satisfied
--                 transition before p_period_end
--
-- Every conversion rate:
--
--   ROUND(100 * numerator / denominator, 2)
--
-- If denominator = 0:
--
--   return NULL
--
-- Never manufacture 0% for an undefined cohort conversion.
--
-- ---------------------------------------------------------------------
-- Finance-as-of-period-end definitions
-- ---------------------------------------------------------------------
--
-- Eligible booking population:
--
--   canonical bookings created before p_period_end and inside the
--   requested organization/branch scope.
--
-- required_advance_as_of_end_inr
--   SUM(immutable required_advance_inr) for eligible bookings.
--
-- valid_collected_as_of_end_inr
--   payment received_at < p_period_end
--   AND no reversal with reversed_at < p_period_end.
--
-- advance_outstanding_as_of_end_inr
--   per booking:
--
--     GREATEST(
--       required_advance_inr - valid_collected_as_of_end,
--       0
--     )
--
--   then SUM across eligible bookings.
--
-- advance_satisfied_bookings_as_of_end_count
--   eligible bookings whose valid collected amount as of end is
--   >= immutable required advance.
--
-- confirmed_with_advance_shortfall_as_of_end_count
--   booking has historical advance_satisfied transition before end
--   AND valid collected as of end < immutable required advance.
--
-- ---------------------------------------------------------------------
-- Stage-7 / Stage-8 snapshot definitions
-- ---------------------------------------------------------------------
--
-- Journey stage as of p_period_end must be reconstructed from immutable
-- booking_stage_transitions at or before p_period_end.
--
-- advance_pending_stage_as_of_end_count
--   bookings whose reconstructed current stage at period end is
--   stage_key = 'advance_pending'.
--
-- booking_confirmed_stage_as_of_end_count
--   bookings whose reconstructed current stage at period end is
--   stage_key = 'booking_confirmed'.
--
-- This is a stage-position metric, NOT the historical count of all
-- bookings that ever achieved confirmation.
--
-- =====================================================================
-- RPC 2 — get_founder_booking_stage_kpis
-- =====================================================================
--
-- Frozen signature:
--
-- public.get_founder_booking_stage_kpis(
--   p_organization_id uuid,
--   p_as_of timestamptz,
--   p_branch_id uuid DEFAULT NULL
-- )
--
-- Exact return contract:
--
--   stage_order smallint
--   stage_key text
--   booking_count bigint
--   average_stage_age_seconds numeric(18,2)
--   oldest_stage_age_seconds bigint
--
-- Population:
--
--   canonical bookings created at or before p_as_of in requested
--   organization/branch scope.
--
-- Stage reconstruction:
--
--   use immutable booking_stage_transitions at or before p_as_of.
--   The latest applicable transition determines stage position.
--
-- Stage age:
--
--   p_as_of - transitioned_at of the transition that entered the
--   reconstructed current stage.
--
-- Return every active canonical journey stage, including zero-count
-- stages, so the Founder read model keeps the complete 21-stage shape.
--
-- Zero-count stage aging:
--
--   average_stage_age_seconds = NULL
--   oldest_stage_age_seconds = NULL
--
-- =====================================================================
-- EXPLICITLY OUT OF SCOPE
-- =====================================================================
--
--   revenue
--   recognized revenue
--   GST/tax reporting
--   invoices
--   expenses
--   P&L
--   payroll
--   bank reconciliation
--   refund workflow
--   safety metrics
--   prep metrics
--   editing metrics
--   delivery metrics
--   review metrics
--   heirloom metrics
--   marketing metrics
--   arbitrary browser-side aggregation as source of truth
--
-- SPRINT_9_SLICE_3_CONTRACT_FROZEN
-- =====================================================================

-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s9_kpi_preconditions$
DECLARE
  v_missing text;
BEGIN
  FOREACH v_missing IN ARRAY ARRAY[
    'leads',
    'quotations',
    'bookings',
    'booking_journey_states',
    'booking_stage_transitions',
    'booking_journey_stages',
    'booking_payment_requirements',
    'booking_payments',
    'booking_payment_reversals',
    'permissions',
    'roles',
    'role_permissions'
  ]
  LOOP
    IF to_regclass('public.' || v_missing) IS NULL THEN
      RAISE EXCEPTION
        'Sprint 9 KPI precondition failed: public.% missing',
        v_missing;
    END IF;
  END LOOP;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 KPI precondition failed: current_organization_member(uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 KPI precondition failed: has_permission(uuid,text,uuid) missing';
  END IF;

  IF to_regprocedure(
       'public.has_branch_scope(uuid,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 KPI precondition failed: has_branch_scope(uuid,uuid) missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.permissions p
    WHERE p.key = 'kpi.read'
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 KPI precondition failed: kpi.read already exists';
  END IF;

  IF to_regprocedure(
       'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
     ) IS NOT NULL
     OR to_regprocedure(
       'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 9 KPI precondition failed: KPI RPC already exists';
  END IF;

  IF (
    SELECT count(*)
    FROM public.booking_journey_stages s
    WHERE s.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND s.is_active
  ) <> 21 THEN
    RAISE EXCEPTION
      'Sprint 9 KPI precondition failed: canonical active 21-stage journey unavailable';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes i
    WHERE i.schemaname = 'public'
      AND i.tablename = 'booking_stage_transitions'
      AND i.indexname =
          'booking_stage_transitions_booking_history_idx'
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 KPI precondition failed: deterministic booking history index missing';
  END IF;
END
$s9_kpi_preconditions$;

-- =====================================================================
-- Section B — KPI read permission
-- =====================================================================

INSERT INTO public.permissions (
  key,
  domain,
  label,
  description,
  requires_server_enforcement
)
VALUES (
  'kpi.read',
  'kpi',
  'Read founder KPIs',
  'Read authoritative aggregate studio KPIs and historical booking-stage snapshots through controlled server-enforced read models.',
  true
);

INSERT INTO public.role_permissions (
  role_id,
  permission_id
)
SELECT
  r.id,
  p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.key = 'founder'
  AND p.key = 'kpi.read'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- =====================================================================
-- Section C — Founder KPI summary
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_founder_kpi_summary(
  p_organization_id uuid,
  p_period_start timestamptz,
  p_period_end timestamptz,
  p_branch_id uuid DEFAULT NULL
)
RETURNS TABLE (
  organization_id uuid,
  branch_id uuid,
  period_start timestamptz,
  period_end timestamptz,

  new_inquiries_count bigint,

  quotations_sent_count bigint,
  quoted_value_inr bigint,

  quotations_accepted_count bigint,
  accepted_value_inr bigint,

  bookings_created_count bigint,
  bookings_confirmed_count bigint,

  payments_collected_inr bigint,

  sent_quote_cohort_accepted_count bigint,
  sent_quote_acceptance_rate_pct numeric(7,2),

  inquiry_cohort_accepted_count bigint,
  inquiry_to_accepted_quote_rate_pct numeric(7,2),

  accepted_quote_cohort_booked_count bigint,
  accepted_quote_to_booking_rate_pct numeric(7,2),

  booking_cohort_confirmed_count bigint,
  booking_to_confirmed_rate_pct numeric(7,2),

  required_advance_as_of_end_inr bigint,
  valid_collected_as_of_end_inr bigint,
  advance_outstanding_as_of_end_inr bigint,

  advance_satisfied_bookings_as_of_end_count bigint,
  advance_pending_stage_as_of_end_count bigint,
  booking_confirmed_stage_as_of_end_count bigint,
  confirmed_with_advance_shortfall_as_of_end_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION
      'get_founder_kpi_summary: organization_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_period_start IS NULL THEN
    RAISE EXCEPTION
      'get_founder_kpi_summary: period_start is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_period_end IS NULL THEN
    RAISE EXCEPTION
      'get_founder_kpi_summary: period_end is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_period_start >= p_period_end THEN
    RAISE EXCEPTION
      'get_founder_kpi_summary: period_start must be earlier than period_end'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_founder_kpi_summary: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF p_branch_id IS NULL THEN
    IF NOT public.has_permission(
      p_organization_id,
      'kpi.read',
      NULL
    ) THEN
      RAISE EXCEPTION
        'get_founder_kpi_summary: organization-wide kpi.read permission required'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    IF NOT public.has_branch_scope(
      p_organization_id,
      p_branch_id
    ) THEN
      RAISE EXCEPTION
        'get_founder_kpi_summary: no access to requested branch'
        USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission(
      p_organization_id,
      'kpi.read',
      p_branch_id
    ) THEN
      RAISE EXCEPTION
        'get_founder_kpi_summary: kpi.read permission required for requested branch'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN QUERY
  WITH
  lead_period AS (
    SELECT
      l.id
    FROM public.leads l
    WHERE l.organization_id = p_organization_id
      AND (
        p_branch_id IS NULL
        OR l.branch_id = p_branch_id
      )
      AND l.created_at >= p_period_start
      AND l.created_at < p_period_end
  ),

  sent_quote_period AS (
    SELECT
      q.id,
      q.lead_id,
      q.quoted_total_inr,
      q.accepted_at
    FROM public.quotations q
    WHERE q.organization_id = p_organization_id
      AND (
        p_branch_id IS NULL
        OR q.branch_id = p_branch_id
      )
      AND q.sent_at >= p_period_start
      AND q.sent_at < p_period_end
  ),

  accepted_quote_period AS (
    SELECT
      q.id,
      q.quoted_total_inr
    FROM public.quotations q
    WHERE q.organization_id = p_organization_id
      AND (
        p_branch_id IS NULL
        OR q.branch_id = p_branch_id
      )
      AND q.accepted_at >= p_period_start
      AND q.accepted_at < p_period_end
  ),

  booking_period AS (
    SELECT
      b.id,
      b.source_quotation_id
    FROM public.bookings b
    WHERE b.organization_id = p_organization_id
      AND (
        p_branch_id IS NULL
        OR b.branch_id = p_branch_id
      )
      AND b.created_at >= p_period_start
      AND b.created_at < p_period_end
  ),

  confirmation_period AS (
    SELECT
      t.booking_id
    FROM public.booking_stage_transitions t
    JOIN public.bookings b
      ON b.organization_id = t.organization_id
     AND b.id = t.booking_id
    WHERE t.organization_id = p_organization_id
      AND (
        p_branch_id IS NULL
        OR b.branch_id = p_branch_id
      )
      AND t.transition_key = 'advance_satisfied'
      AND t.transitioned_at >= p_period_start
      AND t.transitioned_at < p_period_end
  ),

  payment_period AS (
    SELECT
      p.id,
      p.amount_inr
    FROM public.booking_payments p
    JOIN public.bookings b
      ON b.organization_id = p.organization_id
     AND b.id = p.booking_id
    WHERE p.organization_id = p_organization_id
      AND (
        p_branch_id IS NULL
        OR b.branch_id = p_branch_id
      )
      AND p.received_at >= p_period_start
      AND p.received_at < p_period_end
      AND NOT EXISTS (
        SELECT 1
        FROM public.booking_payment_reversals rv
        WHERE rv.organization_id =
              p.organization_id
          AND rv.payment_id =
              p.id
          AND rv.reversed_at <
              p_period_end
      )
  ),

  sent_cohort_stats AS (
    SELECT
      count(*)::bigint
        AS denominator,
      count(*) FILTER (
        WHERE sq.accepted_at IS NOT NULL
          AND sq.accepted_at < p_period_end
      )::bigint
        AS numerator
    FROM sent_quote_period sq
  ),

  inquiry_cohort_stats AS (
    SELECT
      count(*)::bigint
        AS denominator,
      count(*) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.quotations q
          WHERE q.organization_id =
                p_organization_id
            AND q.lead_id = lp.id
            AND (
              p_branch_id IS NULL
              OR q.branch_id = p_branch_id
            )
            AND q.accepted_at IS NOT NULL
            AND q.accepted_at < p_period_end
        )
      )::bigint
        AS numerator
    FROM lead_period lp
  ),

  accepted_quote_cohort_stats AS (
    SELECT
      count(*)::bigint
        AS denominator,
      count(*) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.bookings b
          WHERE b.organization_id =
                p_organization_id
            AND b.source_quotation_id = aq.id
            AND (
              p_branch_id IS NULL
              OR b.branch_id = p_branch_id
            )
            AND b.created_at < p_period_end
        )
      )::bigint
        AS numerator
    FROM accepted_quote_period aq
  ),

  booking_cohort_stats AS (
    SELECT
      count(*)::bigint
        AS denominator,
      count(*) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.booking_stage_transitions t
          WHERE t.organization_id =
                p_organization_id
            AND t.booking_id = bp.id
            AND t.transition_key =
                'advance_satisfied'
            AND t.transitioned_at <
                p_period_end
        )
      )::bigint
        AS numerator
    FROM booking_period bp
  ),

  finance_bookings AS (
    SELECT
      b.id AS booking_id,
      r.required_advance_inr
    FROM public.bookings b
    JOIN public.booking_payment_requirements r
      ON r.organization_id = b.organization_id
     AND r.booking_id = b.id
    WHERE b.organization_id = p_organization_id
      AND (
        p_branch_id IS NULL
        OR b.branch_id = p_branch_id
      )
      AND b.created_at < p_period_end
  ),

  finance_payment_totals AS (
    SELECT
      p.booking_id,
      COALESCE(
        sum(p.amount_inr)
          FILTER (
            WHERE rv.id IS NULL
          ),
        0
      )::bigint AS valid_collected_inr
    FROM public.booking_payments p
    JOIN finance_bookings fb
      ON fb.booking_id = p.booking_id
    LEFT JOIN public.booking_payment_reversals rv
      ON rv.organization_id =
         p.organization_id
     AND rv.payment_id =
         p.id
     AND rv.reversed_at <
         p_period_end
    WHERE p.organization_id =
          p_organization_id
      AND p.received_at <
          p_period_end
    GROUP BY p.booking_id
  ),

  finance_snapshot AS (
    SELECT
      fb.booking_id,
      fb.required_advance_inr::bigint
        AS required_advance_inr,
      COALESCE(
        fpt.valid_collected_inr,
        0::bigint
      ) AS valid_collected_inr,
      GREATEST(
        fb.required_advance_inr::bigint -
          COALESCE(
            fpt.valid_collected_inr,
            0::bigint
          ),
        0::bigint
      ) AS advance_outstanding_inr,
      EXISTS (
        SELECT 1
        FROM public.booking_stage_transitions t
        WHERE t.organization_id =
              p_organization_id
          AND t.booking_id =
              fb.booking_id
          AND t.transition_key =
              'advance_satisfied'
          AND t.transitioned_at <
              p_period_end
      ) AS historically_confirmed
    FROM finance_bookings fb
    LEFT JOIN finance_payment_totals fpt
      ON fpt.booking_id =
         fb.booking_id
  ),

  finance_totals AS (
    SELECT
      COALESCE(
        sum(fs.required_advance_inr),
        0
      )::bigint
        AS required_advance_inr,

      COALESCE(
        sum(fs.valid_collected_inr),
        0
      )::bigint
        AS valid_collected_inr,

      COALESCE(
        sum(fs.advance_outstanding_inr),
        0
      )::bigint
        AS advance_outstanding_inr,

      count(*) FILTER (
        WHERE fs.valid_collected_inr >=
              fs.required_advance_inr
      )::bigint
        AS advance_satisfied_count,

      count(*) FILTER (
        WHERE fs.historically_confirmed
          AND fs.valid_collected_inr <
              fs.required_advance_inr
      )::bigint
        AS confirmed_shortfall_count
    FROM finance_snapshot fs
  ),

  stage_eligible_bookings AS (
    SELECT
      b.id AS booking_id
    FROM public.bookings b
    WHERE b.organization_id =
          p_organization_id
      AND (
        p_branch_id IS NULL
        OR b.branch_id = p_branch_id
      )
      AND b.created_at <
          p_period_end
  ),

  stage_snapshot AS (
    SELECT
      eb.booking_id,
      latest_transition.to_stage_id
    FROM stage_eligible_bookings eb
    LEFT JOIN LATERAL (
      SELECT
        t.to_stage_id
      FROM public.booking_stage_transitions t
      JOIN public.booking_journey_stages target_stage
        ON target_stage.organization_id =
           t.organization_id
       AND target_stage.id =
           t.to_stage_id
      WHERE t.organization_id =
            p_organization_id
        AND t.booking_id =
            eb.booking_id
        AND t.transitioned_at <=
            p_period_end
      ORDER BY
        t.transitioned_at DESC,
        target_stage.stage_order DESC,
        t.id DESC
      LIMIT 1
    ) latest_transition
      ON true
  ),

  stage_counts AS (
    SELECT
      count(*) FILTER (
        WHERE s.stage_key =
              'advance_pending'
      )::bigint
        AS advance_pending_count,

      count(*) FILTER (
        WHERE s.stage_key =
              'booking_confirmed'
      )::bigint
        AS booking_confirmed_count
    FROM stage_snapshot ss
    LEFT JOIN public.booking_journey_stages s
      ON s.organization_id =
         p_organization_id
     AND s.id =
         ss.to_stage_id
  )

  SELECT
    p_organization_id,
    p_branch_id,
    p_period_start,
    p_period_end,

    (
      SELECT count(*)::bigint
      FROM lead_period
    ),

    (
      SELECT count(*)::bigint
      FROM sent_quote_period
    ),

    COALESCE(
      (
        SELECT sum(sq.quoted_total_inr)
        FROM sent_quote_period sq
      ),
      0
    )::bigint,

    (
      SELECT count(*)::bigint
      FROM accepted_quote_period
    ),

    COALESCE(
      (
        SELECT sum(aq.quoted_total_inr)
        FROM accepted_quote_period aq
      ),
      0
    )::bigint,

    (
      SELECT count(*)::bigint
      FROM booking_period
    ),

    (
      SELECT count(*)::bigint
      FROM confirmation_period
    ),

    COALESCE(
      (
        SELECT sum(pp.amount_inr)
        FROM payment_period pp
      ),
      0
    )::bigint,

    sc.numerator,

    CASE
      WHEN sc.denominator = 0
        THEN NULL::numeric(7,2)
      ELSE
        round(
          100::numeric *
          sc.numerator::numeric /
          sc.denominator::numeric,
          2
        )::numeric(7,2)
    END,

    ic.numerator,

    CASE
      WHEN ic.denominator = 0
        THEN NULL::numeric(7,2)
      ELSE
        round(
          100::numeric *
          ic.numerator::numeric /
          ic.denominator::numeric,
          2
        )::numeric(7,2)
    END,

    ac.numerator,

    CASE
      WHEN ac.denominator = 0
        THEN NULL::numeric(7,2)
      ELSE
        round(
          100::numeric *
          ac.numerator::numeric /
          ac.denominator::numeric,
          2
        )::numeric(7,2)
    END,

    bc.numerator,

    CASE
      WHEN bc.denominator = 0
        THEN NULL::numeric(7,2)
      ELSE
        round(
          100::numeric *
          bc.numerator::numeric /
          bc.denominator::numeric,
          2
        )::numeric(7,2)
    END,

    ft.required_advance_inr,
    ft.valid_collected_inr,
    ft.advance_outstanding_inr,

    ft.advance_satisfied_count,
    st.advance_pending_count,
    st.booking_confirmed_count,
    ft.confirmed_shortfall_count

  FROM sent_cohort_stats sc
  CROSS JOIN inquiry_cohort_stats ic
  CROSS JOIN accepted_quote_cohort_stats ac
  CROSS JOIN booking_cohort_stats bc
  CROSS JOIN finance_totals ft
  CROSS JOIN stage_counts st;
END
$$;

-- =====================================================================
-- Section D — 21-stage Founder KPI read model
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_founder_booking_stage_kpis(
  p_organization_id uuid,
  p_as_of timestamptz,
  p_branch_id uuid DEFAULT NULL
)
RETURNS TABLE (
  stage_order smallint,
  stage_key text,
  booking_count bigint,
  average_stage_age_seconds numeric(18,2),
  oldest_stage_age_seconds bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION
      'get_founder_booking_stage_kpis: organization_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_as_of IS NULL THEN
    RAISE EXCEPTION
      'get_founder_booking_stage_kpis: as_of is required'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'get_founder_booking_stage_kpis: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF p_branch_id IS NULL THEN
    IF NOT public.has_permission(
      p_organization_id,
      'kpi.read',
      NULL
    ) THEN
      RAISE EXCEPTION
        'get_founder_booking_stage_kpis: organization-wide kpi.read permission required'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    IF NOT public.has_branch_scope(
      p_organization_id,
      p_branch_id
    ) THEN
      RAISE EXCEPTION
        'get_founder_booking_stage_kpis: no access to requested branch'
        USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission(
      p_organization_id,
      'kpi.read',
      p_branch_id
    ) THEN
      RAISE EXCEPTION
        'get_founder_booking_stage_kpis: kpi.read permission required for requested branch'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN QUERY
  WITH
  eligible_bookings AS (
    SELECT
      b.id AS booking_id
    FROM public.bookings b
    WHERE b.organization_id =
          p_organization_id
      AND (
        p_branch_id IS NULL
        OR b.branch_id = p_branch_id
      )
      AND b.created_at <= p_as_of
  ),

  stage_snapshot AS (
    SELECT
      eb.booking_id,
      latest_transition.to_stage_id,
      latest_transition.transitioned_at
        AS stage_entered_at
    FROM eligible_bookings eb
    LEFT JOIN LATERAL (
      SELECT
        t.to_stage_id,
        t.transitioned_at
      FROM public.booking_stage_transitions t
      JOIN public.booking_journey_stages target_stage
        ON target_stage.organization_id =
           t.organization_id
       AND target_stage.id =
           t.to_stage_id
      WHERE t.organization_id =
            p_organization_id
        AND t.booking_id =
            eb.booking_id
        AND t.transitioned_at <=
            p_as_of
      ORDER BY
        t.transitioned_at DESC,
        target_stage.stage_order DESC,
        t.id DESC
      LIMIT 1
    ) latest_transition
      ON true
  )

  SELECT
    s.stage_order,
    s.stage_key,
    count(ss.booking_id)::bigint,

    round(
      avg(
        extract(
          epoch FROM (
            p_as_of -
            ss.stage_entered_at
          )
        )
      )::numeric,
      2
    )::numeric(18,2),

    max(
      floor(
        extract(
          epoch FROM (
            p_as_of -
            ss.stage_entered_at
          )
        )
      )
    )::bigint

  FROM public.booking_journey_stages s
  LEFT JOIN stage_snapshot ss
    ON ss.to_stage_id = s.id
  WHERE s.organization_id =
        p_organization_id
    AND s.is_active
  GROUP BY
    s.id,
    s.stage_order,
    s.stage_key
  ORDER BY
    s.stage_order;
END
$$;

-- =====================================================================
-- Section E — Least-privilege RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION public.get_founder_kpi_summary(
  uuid,
  timestamptz,
  timestamptz,
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.get_founder_kpi_summary(
  uuid,
  timestamptz,
  timestamptz,
  uuid
)
TO authenticated;

REVOKE ALL
ON FUNCTION public.get_founder_booking_stage_kpis(
  uuid,
  timestamptz,
  uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.get_founder_booking_stage_kpis(
  uuid,
  timestamptz,
  uuid
)
TO authenticated;

-- =====================================================================
-- Section F — Migration hard gates
-- =====================================================================

DO $s9_kpi_assertions$
DECLARE
  v_count integer;
  v_summary_fn regprocedure;
  v_stage_fn regprocedure;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.permissions p
  WHERE p.key = 'kpi.read'
    AND p.domain = 'kpi'
    AND p.requires_server_enforcement;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: hardened kpi.read permission missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions rp
  JOIN public.roles r
    ON r.id = rp.role_id
  JOIN public.permissions p
    ON p.id = rp.permission_id
  WHERE r.key = 'founder'
    AND p.key = 'kpi.read';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: Founder kpi.read grant missing';
  END IF;

  v_summary_fn :=
    to_regprocedure(
      'public.get_founder_kpi_summary(uuid,timestamp with time zone,timestamp with time zone,uuid)'
    );

  v_stage_fn :=
    to_regprocedure(
      'public.get_founder_booking_stage_kpis(uuid,timestamp with time zone,uuid)'
    );

  IF v_summary_fn IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: founder KPI summary RPC missing';
  END IF;

  IF v_stage_fn IS NULL THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: booking-stage KPI RPC missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid = v_summary_fn::oid
      AND p.prosecdef
      AND p.provolatile = 's'
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: summary RPC must be STABLE SECURITY DEFINER';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid = v_stage_fn::oid
      AND p.prosecdef
      AND p.provolatile = 's'
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: stage KPI RPC must be STABLE SECURITY DEFINER';
  END IF;

  IF NOT has_function_privilege(
       'authenticated',
       v_summary_fn::oid,
       'EXECUTE'
     )
     OR NOT has_function_privilege(
       'authenticated',
       v_stage_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: authenticated KPI EXECUTE grant missing';
  END IF;

  IF has_function_privilege(
       'anon',
       v_summary_fn::oid,
       'EXECUTE'
     )
     OR has_function_privilege(
       'anon',
       v_stage_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: anon KPI EXECUTE detected';
  END IF;

  IF position(
       'revenue'
       IN lower(
         pg_get_function_result(
           v_summary_fn::oid
         )
       )
     ) > 0
     OR position(
       'revenue'
       IN lower(
         pg_get_function_result(
           v_stage_fn::oid
         )
       )
     ) > 0 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: forbidden revenue output detected';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND (
        c.relname LIKE 'founder_kpi%'
        OR c.relname LIKE 'kpi_%'
      )
      AND c.relkind IN (
        'r',
        'v',
        'm'
      )
  ) THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: raw KPI table/view truth introduced';
  END IF;

  IF (
    SELECT count(*)
    FROM public.booking_journey_stages s
    WHERE s.organization_id =
          '590a40ab-a5dc-4ebb-a4aa-8b0c68b2f4bc'::uuid
      AND s.is_active
  ) <> 21 THEN
    RAISE EXCEPTION
      'Sprint 9 Slice 3 failed: active journey catalogue is not 21 stages';
  END IF;
END
$s9_kpi_assertions$;

-- SPRINT_9_SLICE_3_IMPLEMENTATION_END
