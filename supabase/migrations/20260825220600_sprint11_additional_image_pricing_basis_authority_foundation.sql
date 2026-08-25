-- =====================================================================
-- Sprint 11 — Shoot Completion & Post-Session Handoff
-- Slice 8 — Client-Favorable Additional-Image Pricing Basis
--           Authority Foundation
--
-- Frozen rule:
--
--   client_favorable_quote_or_selection_v1
--
-- A — accepted-booking protected basis
--   Exact accepted package version
--     -> exact immutable package/additional-image term
--     -> protected additional-image unit-price ceiling.
--
-- B — optional selection-time favorable basis
--   Exact explicitly supplied approved additional_image version,
--   approved no later than immutable selection confirmation.
--
-- Applied unit price:
--   no B        -> A
--   B < A       -> B
--   B = A       -> A
--   B > A       -> A
--
-- Boundary:
--   * explicit package-version -> additional_image-version authority;
--   * immutable booking-level per-unit pricing-basis evidence;
--   * exact A/B commercial provenance;
--   * no latest-version inference;
--   * no source_revision runtime inference;
--   * payment.record mutation authority;
--   * commercial.price.override required only when B is supplied;
--   * payment.read authenticated read containment;
--   * no new permissions or role grants;
--   * no excess-image charge multiplication;
--   * no adjusted financial obligation;
--   * no payment mutation;
--   * no settlement semantics;
--   * no Stage 12 -> 13 journey advancement;
--   * no application UI.
-- =====================================================================


-- =====================================================================
-- Section A — Preconditions
-- =====================================================================

DO $s11s8_preconditions$
DECLARE
  v_count integer;
  v_package_keys text[];
BEGIN
  IF to_regclass(
       'public.commercial_package_additional_image_terms'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: commercial_package_additional_image_terms already exists';
  END IF;

  IF to_regclass(
       'public.booking_additional_image_pricing_bases'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: booking_additional_image_pricing_bases already exists';
  END IF;

  IF to_regclass(
       'public.booking_selection_reconciliations_org_booking_id_uidx'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: reconciliation provenance support index already exists';
  END IF;

  IF to_regprocedure(
       'public.lsh_commercial_package_additional_image_term_guard()'
     ) IS NOT NULL
     OR to_regprocedure(
       'public.lsh_booking_additional_image_pricing_basis_guard()'
     ) IS NOT NULL
     OR to_regprocedure(
       'public.record_booking_additional_image_pricing_basis(uuid,uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: Slice 8 function already exists';
  END IF;

  IF to_regclass('public.bookings') IS NULL
     OR to_regclass('public.quotations') IS NULL
     OR to_regclass('public.quotation_line_items') IS NULL
     OR to_regclass(
          'public.booking_selection_confirmations'
        ) IS NULL
     OR to_regclass(
          'public.booking_selection_reconciliations'
        ) IS NULL
     OR to_regclass(
          'public.booking_journey_states'
        ) IS NULL
     OR to_regclass(
          'public.booking_journey_stages'
        ) IS NULL
     OR to_regclass(
          'public.commercial_packages'
        ) IS NULL
     OR to_regclass(
          'public.commercial_package_versions'
        ) IS NULL
     OR to_regclass(
          'public.commercial_addons'
        ) IS NULL
     OR to_regclass(
          'public.commercial_addon_versions'
        ) IS NULL
     OR to_regclass(
          'public.commercial_image_entitlements'
        ) IS NULL
     OR to_regclass(
          'public.organization_members'
        ) IS NULL
     OR to_regclass('public.permissions') IS NULL
     OR to_regclass('public.role_permissions') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: required canonical relation missing';
  END IF;

  IF to_regprocedure(
       'public.current_organization_member(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_permission(uuid,text,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.has_branch_scope(uuid,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: required canonical helper unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: expected 68 permissions, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: expected 241 role-permission mappings, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.permissions permission
  WHERE permission.domain = 'finance'
    AND permission.requires_server_enforcement
    AND permission.key IN (
      'payment.read',
      'payment.record',
      'commercial.price.override'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: frozen finance permissions unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key IN (
      'payment.read',
      'payment.record',
      'commercial.price.override'
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: finance permission grant cardinality changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions role_permission
  JOIN public.permissions permission
    ON permission.id =
       role_permission.permission_id
  JOIN public.roles role
    ON role.id =
       role_permission.role_id
  WHERE permission.key IN (
      'payment.read',
      'payment.record',
      'commercial.price.override'
    )
    AND role.key = 'founder';

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: founder finance authority unavailable';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_journey_stages stage
  WHERE stage.stage_order = 12
    AND stage.stage_key = 'selection_pending'
    AND stage.is_active;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: exact active Stage 12 selection_pending authority unavailable';
  END IF;

  SELECT count(DISTINCT version.organization_id)
  INTO v_count
  FROM public.commercial_packages package
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       package.organization_id
   AND version.package_id =
       package.id
  WHERE package.service_category IN (
      'maternity',
      'newborn',
      'sitter'
    )
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: expected one canonical commercial organization';
  END IF;

  SELECT array_agg(
           package.package_key
           ORDER BY package.package_key
         )
  INTO v_package_keys
  FROM public.commercial_packages package
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       package.organization_id
   AND version.package_id =
       package.id
  WHERE package.service_category IN (
      'maternity',
      'newborn',
      'sitter'
    )
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status;

  IF v_package_keys IS DISTINCT FROM ARRAY[
    'maternity_bronze',
    'maternity_diamond',
    'maternity_emerald',
    'maternity_gold',
    'newborn_bronze',
    'newborn_diamond',
    'newborn_emerald',
    'newborn_gold',
    'sitter_bronze',
    'sitter_diamond',
    'sitter_emerald',
    'sitter_gold'
  ]::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: frozen package-v1 natural identity set changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_packages package
  JOIN public.commercial_package_versions version
    ON version.organization_id =
       package.organization_id
   AND version.package_id =
       package.id
  WHERE package.package_key = ANY(ARRAY[
      'maternity_bronze',
      'maternity_diamond',
      'maternity_emerald',
      'maternity_gold',
      'newborn_bronze',
      'newborn_diamond',
      'newborn_emerald',
      'newborn_gold',
      'sitter_bronze',
      'sitter_diamond',
      'sitter_emerald',
      'sitter_gold'
    ]::text[])
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND version.source_revision =
        '2026-06-client-pdfs';

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: expected 12 package-v1 source-revision authorities, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_addons addon
  JOIN public.commercial_addon_versions version
    ON version.organization_id =
       addon.organization_id
   AND version.addon_id =
       addon.id
  JOIN public.commercial_image_entitlements entitlement
    ON entitlement.organization_id =
       version.organization_id
   AND entitlement.addon_version_id =
       version.id
  WHERE addon.addon_key = 'additional_image'
    AND addon.status = 'active'
    AND version.version_number = 1
    AND version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND version.pricing_type =
        'fixed_amount'::public.commercial_pricing_type
    AND version.currency = 'INR'
    AND version.amount_inr = 500
    AND version.source_revision =
        '2026-06-client-pdfs'
    AND entitlement.retouched_image_count_per_unit = 1;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 precondition failed: canonical additional_image v1 INR 500 authority unavailable';
  END IF;
END
$s11s8_preconditions$;


-- =====================================================================
-- Section B — Reconciliation provenance identity anchor
--
-- booking_selection_reconciliations already has:
--
--   UNIQUE (organization_id, booking_id)
--   PRIMARY KEY (id)
--
-- The booking pricing-basis relation must bind all three identifiers
-- together as one tenant-safe immutable provenance source.
-- =====================================================================

CREATE UNIQUE INDEX
booking_selection_reconciliations_org_booking_id_uidx
ON public.booking_selection_reconciliations (
  organization_id,
  booking_id,
  id
);


-- =====================================================================
-- Section C — Explicit package-version additional-image term authority
-- =====================================================================

CREATE TABLE public.commercial_package_additional_image_terms (
  id                                uuid
                                    PRIMARY KEY
                                    DEFAULT gen_random_uuid(),

  organization_id                   uuid NOT NULL,
  package_version_id                uuid NOT NULL,
  additional_image_addon_version_id uuid NOT NULL,

  currency                          text NOT NULL,
  unit_price_inr                    integer NOT NULL,
  binding_rule                      text NOT NULL,

  created_at                        timestamptz
                                    NOT NULL
                                    DEFAULT now(),

  CONSTRAINT commercial_package_additional_image_terms_currency_chk
    CHECK (
      currency = 'INR'
    ),

  CONSTRAINT commercial_package_additional_image_terms_price_chk
    CHECK (
      unit_price_inr > 0
    ),

  CONSTRAINT commercial_package_additional_image_terms_rule_chk
    CHECK (
      binding_rule =
        'explicit_package_additional_image_term_v1'
    ),

  CONSTRAINT commercial_package_additional_image_terms_package_fkey
    FOREIGN KEY (
      organization_id,
      package_version_id
    )
    REFERENCES public.commercial_package_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_package_additional_image_terms_addon_fkey
    FOREIGN KEY (
      organization_id,
      additional_image_addon_version_id
    )
    REFERENCES public.commercial_addon_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT commercial_package_additional_image_terms_org_package_key
    UNIQUE (
      organization_id,
      package_version_id
    ),

  CONSTRAINT commercial_package_additional_image_terms_org_id_key
    UNIQUE (
      organization_id,
      id
    )
);

CREATE INDEX commercial_package_additional_image_terms_org_created_idx
ON public.commercial_package_additional_image_terms (
  organization_id,
  created_at DESC
);


-- =====================================================================
-- Section D — Package-term immutable canonical-value guard
-- =====================================================================

CREATE FUNCTION
public.lsh_commercial_package_additional_image_term_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_package_version public.commercial_package_versions;
  v_package public.commercial_packages;

  v_addon_version public.commercial_addon_versions;
  v_addon public.commercial_addons;

  v_entitlement_count bigint := 0;
  v_entitlement_per_unit integer;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'commercial package additional-image term authority is immutable';
  END IF;

  IF NEW.organization_id IS NULL
     OR NEW.package_version_id IS NULL
     OR NEW.additional_image_addon_version_id IS NULL
     OR NEW.currency IS NULL
     OR NEW.unit_price_inr IS NULL
     OR NEW.binding_rule IS NULL
     OR NEW.created_at IS NULL THEN
    RAISE EXCEPTION
      'commercial package additional-image term requires complete immutable authority';
  END IF;

  IF NEW.binding_rule <>
     'explicit_package_additional_image_term_v1' THEN
    RAISE EXCEPTION
      'commercial package additional-image term binding rule is invalid';
  END IF;

  SELECT version.*
  INTO v_package_version
  FROM public.commercial_package_versions version
  WHERE version.organization_id =
        NEW.organization_id
    AND version.id =
        NEW.package_version_id;

  IF NOT FOUND
     OR v_package_version.approval_status <>
        'approved'::public.commercial_version_approval_status THEN
    RAISE EXCEPTION
      'commercial package additional-image term requires approved package version';
  END IF;

  SELECT package.*
  INTO v_package
  FROM public.commercial_packages package
  WHERE package.organization_id =
        NEW.organization_id
    AND package.id =
        v_package_version.package_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'commercial package additional-image term requires canonical package';
  END IF;

  SELECT version.*
  INTO v_addon_version
  FROM public.commercial_addon_versions version
  WHERE version.organization_id =
        NEW.organization_id
    AND version.id =
        NEW.additional_image_addon_version_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'commercial package additional-image term requires canonical add-on version';
  END IF;

  SELECT addon.*
  INTO v_addon
  FROM public.commercial_addons addon
  WHERE addon.organization_id =
        NEW.organization_id
    AND addon.id =
        v_addon_version.addon_id;

  IF NOT FOUND
     OR v_addon.addon_key <> 'additional_image'
     OR v_addon.status <> 'active' THEN
    RAISE EXCEPTION
      'commercial package additional-image term requires active additional_image add-on';
  END IF;

  IF v_addon_version.approval_status <>
       'approved'::public.commercial_version_approval_status
     OR v_addon_version.pricing_type <>
       'fixed_amount'::public.commercial_pricing_type
     OR v_addon_version.currency <> 'INR'
     OR v_addon_version.amount_inr IS NULL
     OR v_addon_version.amount_inr <= 0 THEN
    RAISE EXCEPTION
      'commercial package additional-image term requires approved fixed INR add-on version';
  END IF;

  IF NOT (
    v_package.service_category =
      ANY(v_addon.applicable_service_categories)
  ) THEN
    RAISE EXCEPTION
      'commercial package additional-image term add-on does not support package service category';
  END IF;

  SELECT
    count(*),
    max(entitlement.retouched_image_count_per_unit)
  INTO
    v_entitlement_count,
    v_entitlement_per_unit
  FROM public.commercial_image_entitlements entitlement
  WHERE entitlement.organization_id =
        NEW.organization_id
    AND entitlement.addon_version_id =
        NEW.additional_image_addon_version_id;

  IF v_entitlement_count <> 1
     OR v_entitlement_per_unit IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION
      'commercial package additional-image term requires exact one-image entitlement authority';
  END IF;

  IF NEW.currency IS DISTINCT FROM
       v_addon_version.currency
     OR NEW.unit_price_inr IS DISTINCT FROM
       v_addon_version.amount_inr THEN
    RAISE EXCEPTION
      'commercial package additional-image term must snapshot exact add-on catalogue price';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER commercial_package_additional_image_terms_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.commercial_package_additional_image_terms
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_commercial_package_additional_image_term_guard();

REVOKE ALL
ON FUNCTION
  public.lsh_commercial_package_additional_image_term_guard()
FROM PUBLIC, anon, authenticated, service_role;


-- =====================================================================
-- Section E — Seed exact current package/additional-image authorities
--
-- Stable natural commercial identities only.
-- No reset-generated UUID is hardcoded.
--
-- source_revision has already been asserted above as migration
-- provenance. It is NOT used as the persisted runtime resolution rule.
-- =====================================================================

INSERT INTO public.commercial_package_additional_image_terms (
  organization_id,
  package_version_id,
  additional_image_addon_version_id,
  currency,
  unit_price_inr,
  binding_rule
)
SELECT
  package_version.organization_id,
  package_version.id,
  addon_version.id,
  addon_version.currency,
  addon_version.amount_inr,
  'explicit_package_additional_image_term_v1'
FROM public.commercial_packages package
JOIN public.commercial_package_versions package_version
  ON package_version.organization_id =
     package.organization_id
 AND package_version.package_id =
     package.id
JOIN public.commercial_addons addon
  ON addon.organization_id =
     package.organization_id
 AND addon.addon_key =
     'additional_image'
JOIN public.commercial_addon_versions addon_version
  ON addon_version.organization_id =
     addon.organization_id
 AND addon_version.addon_id =
     addon.id
WHERE package.package_key = ANY(ARRAY[
    'maternity_bronze',
    'maternity_diamond',
    'maternity_emerald',
    'maternity_gold',
    'newborn_bronze',
    'newborn_diamond',
    'newborn_emerald',
    'newborn_gold',
    'sitter_bronze',
    'sitter_diamond',
    'sitter_emerald',
    'sitter_gold'
  ]::text[])
  AND package_version.version_number = 1
  AND package_version.approval_status =
      'approved'::public.commercial_version_approval_status
  AND package_version.source_revision =
      '2026-06-client-pdfs'
  AND addon.status = 'active'
  AND addon_version.version_number = 1
  AND addon_version.approval_status =
      'approved'::public.commercial_version_approval_status
  AND addon_version.pricing_type =
      'fixed_amount'::public.commercial_pricing_type
  AND addon_version.currency = 'INR'
  AND addon_version.amount_inr = 500
  AND addon_version.source_revision =
      '2026-06-client-pdfs';


-- =====================================================================
-- Section F — Global term authority forced RLS / finance read
-- =====================================================================

ALTER TABLE public.commercial_package_additional_image_terms
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.commercial_package_additional_image_terms
FORCE ROW LEVEL SECURITY;

REVOKE ALL
ON TABLE public.commercial_package_additional_image_terms
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.commercial_package_additional_image_terms
TO authenticated;

CREATE POLICY commercial_package_additional_image_terms_authenticated_select
ON public.commercial_package_additional_image_terms
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'payment.read',
    NULL::uuid
  )
);


-- =====================================================================
-- Section G — Immutable booking pricing-basis evidence
-- =====================================================================

CREATE TABLE public.booking_additional_image_pricing_bases (
  id                                      uuid
                                          PRIMARY KEY
                                          DEFAULT gen_random_uuid(),

  organization_id                         uuid NOT NULL,
  booking_id                              uuid NOT NULL,

  source_reconciliation_id                uuid NOT NULL,
  source_quotation_id                     uuid NOT NULL,
  source_selection_confirmation_id        uuid NOT NULL,
  source_package_version_id               uuid NOT NULL,
  source_package_additional_image_term_id uuid NOT NULL,

  quote_acceptance_addon_version_id       uuid NOT NULL,
  quote_acceptance_unit_price_inr         integer NOT NULL,

  selection_addon_version_id              uuid,
  selection_unit_price_inr                integer,

  applied_addon_version_id                uuid NOT NULL,
  applied_unit_price_inr                  integer NOT NULL,

  currency                                text NOT NULL,
  pricing_rule                            text NOT NULL,

  recorded_at                             timestamptz
                                          NOT NULL
                                          DEFAULT now(),
  recorded_by                             uuid NOT NULL,

  CONSTRAINT booking_additional_image_pricing_bases_quote_price_chk
    CHECK (
      quote_acceptance_unit_price_inr > 0
    ),

  CONSTRAINT booking_additional_image_pricing_bases_selection_shape_chk
    CHECK (
      (
        selection_addon_version_id IS NULL
        AND selection_unit_price_inr IS NULL
      )
      OR
      (
        selection_addon_version_id IS NOT NULL
        AND selection_unit_price_inr IS NOT NULL
        AND selection_unit_price_inr > 0
      )
    ),

  CONSTRAINT booking_additional_image_pricing_bases_applied_price_chk
    CHECK (
      applied_unit_price_inr > 0
    ),

  CONSTRAINT booking_additional_image_pricing_bases_currency_chk
    CHECK (
      currency = 'INR'
    ),

  CONSTRAINT booking_additional_image_pricing_bases_rule_chk
    CHECK (
      pricing_rule =
        'client_favorable_quote_or_selection_v1'
    ),

  CONSTRAINT booking_additional_image_pricing_bases_booking_fkey
    FOREIGN KEY (
      organization_id,
      booking_id
    )
    REFERENCES public.bookings (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_reconciliation_fkey
    FOREIGN KEY (
      organization_id,
      booking_id,
      source_reconciliation_id
    )
    REFERENCES public.booking_selection_reconciliations (
      organization_id,
      booking_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_quote_fkey
    FOREIGN KEY (
      organization_id,
      source_quotation_id
    )
    REFERENCES public.quotations (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_confirmation_fkey
    FOREIGN KEY (
      organization_id,
      booking_id,
      source_selection_confirmation_id
    )
    REFERENCES public.booking_selection_confirmations (
      organization_id,
      booking_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_package_version_fkey
    FOREIGN KEY (
      organization_id,
      source_package_version_id
    )
    REFERENCES public.commercial_package_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_package_term_fkey
    FOREIGN KEY (
      organization_id,
      source_package_additional_image_term_id
    )
    REFERENCES public.commercial_package_additional_image_terms (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_quote_addon_fkey
    FOREIGN KEY (
      organization_id,
      quote_acceptance_addon_version_id
    )
    REFERENCES public.commercial_addon_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_selection_addon_fkey
    FOREIGN KEY (
      organization_id,
      selection_addon_version_id
    )
    REFERENCES public.commercial_addon_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_applied_addon_fkey
    FOREIGN KEY (
      organization_id,
      applied_addon_version_id
    )
    REFERENCES public.commercial_addon_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_recorded_by_fkey
    FOREIGN KEY (
      recorded_by,
      organization_id
    )
    REFERENCES public.organization_members (
      id,
      organization_id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT booking_additional_image_pricing_bases_org_booking_key
    UNIQUE (
      organization_id,
      booking_id
    )
);

CREATE INDEX booking_additional_image_pricing_bases_org_recorded_idx
ON public.booking_additional_image_pricing_bases (
  organization_id,
  recorded_at DESC
);


-- =====================================================================
-- Section H — Booking pricing-basis immutable canonical-value guard
-- =====================================================================

CREATE FUNCTION
public.lsh_booking_additional_image_pricing_basis_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_quote public.quotations;

  v_confirmation public.booking_selection_confirmations;
  v_reconciliation public.booking_selection_reconciliations;

  v_package_line public.quotation_line_items;
  v_package_line_count bigint := 0;

  v_package_version public.commercial_package_versions;
  v_package public.commercial_packages;

  v_term public.commercial_package_additional_image_terms;

  v_quote_addon_version public.commercial_addon_versions;
  v_quote_addon public.commercial_addons;

  v_selection_addon_version public.commercial_addon_versions;
  v_selection_addon public.commercial_addons;

  v_selection_entitlement_count bigint := 0;
  v_selection_entitlement_per_unit integer;

  v_stage_count bigint := 0;

  v_expected_applied_addon_version_id uuid;
  v_expected_applied_unit_price_inr integer;

  v_actor uuid;
BEGIN
  IF TG_OP = 'UPDATE'
     OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'booking additional-image pricing-basis evidence is immutable';
  END IF;

  IF NEW.organization_id IS NULL
     OR NEW.booking_id IS NULL
     OR NEW.source_reconciliation_id IS NULL
     OR NEW.source_quotation_id IS NULL
     OR NEW.source_selection_confirmation_id IS NULL
     OR NEW.source_package_version_id IS NULL
     OR NEW.source_package_additional_image_term_id IS NULL
     OR NEW.quote_acceptance_addon_version_id IS NULL
     OR NEW.quote_acceptance_unit_price_inr IS NULL
     OR NEW.applied_addon_version_id IS NULL
     OR NEW.applied_unit_price_inr IS NULL
     OR NEW.currency IS NULL
     OR NEW.pricing_rule IS NULL
     OR NEW.recorded_at IS NULL
     OR NEW.recorded_by IS NULL THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires complete immutable attribution';
  END IF;

  IF NEW.pricing_rule <>
     'client_favorable_quote_or_selection_v1' THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis rule is invalid';
  END IF;

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.organization_id =
        NEW.organization_id
    AND booking.id =
        NEW.booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires canonical booking';
  END IF;

  IF NEW.source_quotation_id IS DISTINCT FROM
     v_booking.source_quotation_id THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis source quotation must match booking';
  END IF;

  SELECT count(*)
  INTO v_stage_count
  FROM public.booking_journey_states state
  JOIN public.booking_journey_stages stage
    ON stage.organization_id =
       state.organization_id
   AND stage.id =
       state.current_stage_id
  WHERE state.organization_id =
        NEW.organization_id
    AND state.booking_id =
        NEW.booking_id
    AND stage.stage_order = 12
    AND stage.stage_key = 'selection_pending'
    AND stage.is_active;

  IF v_stage_count <> 1 THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires exact active Stage 12 selection_pending state';
  END IF;

  SELECT quotation.*
  INTO v_quote
  FROM public.quotations quotation
  WHERE quotation.organization_id =
        NEW.organization_id
    AND quotation.id =
        NEW.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <>
        'accepted'::public.quotation_status THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires accepted source quotation';
  END IF;

  SELECT confirmation.*
  INTO v_confirmation
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        NEW.organization_id
    AND confirmation.booking_id =
        NEW.booking_id
    AND confirmation.id =
        NEW.source_selection_confirmation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires canonical selection confirmation';
  END IF;

  SELECT reconciliation.*
  INTO v_reconciliation
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        NEW.organization_id
    AND reconciliation.booking_id =
        NEW.booking_id
    AND reconciliation.id =
        NEW.source_reconciliation_id;

  IF NOT FOUND
     OR v_reconciliation.excess_image_count <= 0 THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires positive canonical excess reconciliation';
  END IF;

  IF v_reconciliation.source_quotation_id
       IS DISTINCT FROM NEW.source_quotation_id
     OR v_reconciliation.source_selection_confirmation_id
       IS DISTINCT FROM NEW.source_selection_confirmation_id THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis reconciliation lineage is inconsistent';
  END IF;

  SELECT count(*)
  INTO v_package_line_count
  FROM public.quotation_line_items line_item
  WHERE line_item.organization_id =
        NEW.organization_id
    AND line_item.quotation_id =
        NEW.source_quotation_id
    AND line_item.line_type =
        'package'::public.quotation_line_type;

  IF v_package_line_count <> 1 THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires exactly one accepted package line';
  END IF;

  SELECT line_item.*
  INTO v_package_line
  FROM public.quotation_line_items line_item
  WHERE line_item.organization_id =
        NEW.organization_id
    AND line_item.quotation_id =
        NEW.source_quotation_id
    AND line_item.line_type =
        'package'::public.quotation_line_type;

  IF v_package_line.source_package_version_id
       IS DISTINCT FROM NEW.source_package_version_id THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis package-version lineage is inconsistent';
  END IF;

  SELECT version.*
  INTO v_package_version
  FROM public.commercial_package_versions version
  WHERE version.organization_id =
        NEW.organization_id
    AND version.id =
        NEW.source_package_version_id;

  IF NOT FOUND
     OR v_package_version.approval_status <>
        'approved'::public.commercial_version_approval_status THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires approved source package version';
  END IF;

  SELECT package.*
  INTO v_package
  FROM public.commercial_packages package
  WHERE package.organization_id =
        NEW.organization_id
    AND package.id =
        v_package_version.package_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires canonical source package';
  END IF;

  SELECT term.*
  INTO v_term
  FROM public.commercial_package_additional_image_terms term
  WHERE term.organization_id =
        NEW.organization_id
    AND term.package_version_id =
        NEW.source_package_version_id
    AND term.id =
        NEW.source_package_additional_image_term_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis requires exact package additional-image term';
  END IF;

  IF NEW.quote_acceptance_addon_version_id
       IS DISTINCT FROM
         v_term.additional_image_addon_version_id
     OR NEW.quote_acceptance_unit_price_inr
       IS DISTINCT FROM
         v_term.unit_price_inr
     OR NEW.currency
       IS DISTINCT FROM
         v_term.currency THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis A-side snapshot is inconsistent';
  END IF;

  SELECT version.*
  INTO v_quote_addon_version
  FROM public.commercial_addon_versions version
  WHERE version.organization_id =
        NEW.organization_id
    AND version.id =
        NEW.quote_acceptance_addon_version_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis A-side add-on version is missing';
  END IF;

  SELECT addon.*
  INTO v_quote_addon
  FROM public.commercial_addons addon
  WHERE addon.organization_id =
        NEW.organization_id
    AND addon.id =
        v_quote_addon_version.addon_id;

  IF NOT FOUND
     OR v_quote_addon.addon_key <> 'additional_image'
     OR v_quote_addon_version.approval_status <>
        'approved'::public.commercial_version_approval_status
     OR v_quote_addon_version.pricing_type <>
        'fixed_amount'::public.commercial_pricing_type
     OR v_quote_addon_version.currency <> 'INR'
     OR v_quote_addon_version.amount_inr
        IS DISTINCT FROM
          NEW.quote_acceptance_unit_price_inr THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis A-side commercial authority is inconsistent';
  END IF;

  IF NEW.selection_addon_version_id IS NULL THEN
    IF NEW.selection_unit_price_inr IS NOT NULL THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis B-side version and price must be both null or both present';
    END IF;
  ELSE
    IF NEW.selection_unit_price_inr IS NULL THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis B-side version and price must be both null or both present';
    END IF;

    SELECT version.*
    INTO v_selection_addon_version
    FROM public.commercial_addon_versions version
    WHERE version.organization_id =
          NEW.organization_id
      AND version.id =
          NEW.selection_addon_version_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis B-side add-on version is missing';
    END IF;

    SELECT addon.*
    INTO v_selection_addon
    FROM public.commercial_addons addon
    WHERE addon.organization_id =
          NEW.organization_id
      AND addon.id =
          v_selection_addon_version.addon_id;

    IF NOT FOUND
       OR v_selection_addon.addon_key <> 'additional_image'
       OR v_selection_addon.status <> 'active'
       OR v_selection_addon_version.approval_status <>
          'approved'::public.commercial_version_approval_status
       OR v_selection_addon_version.pricing_type <>
          'fixed_amount'::public.commercial_pricing_type
       OR v_selection_addon_version.currency <> 'INR'
       OR v_selection_addon_version.amount_inr IS NULL
       OR v_selection_addon_version.amount_inr <= 0
       OR v_selection_addon_version.approved_at IS NULL
       OR v_selection_addon_version.approved_at >
          v_confirmation.confirmed_at THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis B-side commercial version is invalid for selection time';
    END IF;

    IF NOT (
      v_package.service_category =
        ANY(v_selection_addon.applicable_service_categories)
    ) THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis B-side add-on does not support package service category';
    END IF;

    SELECT
      count(*),
      max(entitlement.retouched_image_count_per_unit)
    INTO
      v_selection_entitlement_count,
      v_selection_entitlement_per_unit
    FROM public.commercial_image_entitlements entitlement
    WHERE entitlement.organization_id =
          NEW.organization_id
      AND entitlement.addon_version_id =
          NEW.selection_addon_version_id;

    IF v_selection_entitlement_count <> 1
       OR v_selection_entitlement_per_unit
          IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis B-side requires exact one-image entitlement authority';
    END IF;

    IF NEW.selection_unit_price_inr
         IS DISTINCT FROM
           v_selection_addon_version.amount_inr THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis B-side must snapshot exact catalogue price';
    END IF;
  END IF;

  v_expected_applied_addon_version_id :=
    NEW.quote_acceptance_addon_version_id;

  v_expected_applied_unit_price_inr :=
    NEW.quote_acceptance_unit_price_inr;

  IF NEW.selection_addon_version_id IS NOT NULL
     AND NEW.selection_unit_price_inr <
         NEW.quote_acceptance_unit_price_inr THEN
    v_expected_applied_addon_version_id :=
      NEW.selection_addon_version_id;

    v_expected_applied_unit_price_inr :=
      NEW.selection_unit_price_inr;
  END IF;

  IF NEW.applied_addon_version_id
       IS DISTINCT FROM
         v_expected_applied_addon_version_id
     OR NEW.applied_unit_price_inr
       IS DISTINCT FROM
         v_expected_applied_unit_price_inr THEN
    RAISE EXCEPTION
      'booking additional-image pricing basis applied client-favorable price is inconsistent';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    v_actor :=
      public.current_organization_member(
        NEW.organization_id
      );

    IF v_actor IS NULL
       OR NEW.recorded_by IS DISTINCT FROM
          v_actor THEN
      RAISE EXCEPTION
        'booking additional-image pricing basis recorded_by must be current active organization member';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER booking_additional_image_pricing_bases_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.booking_additional_image_pricing_bases
FOR EACH ROW
EXECUTE FUNCTION
  public.lsh_booking_additional_image_pricing_basis_guard();

REVOKE ALL
ON FUNCTION
  public.lsh_booking_additional_image_pricing_basis_guard()
FROM PUBLIC, anon, authenticated, service_role;


-- =====================================================================
-- Section I — Booking pricing-basis forced RLS / finance read
-- =====================================================================

ALTER TABLE public.booking_additional_image_pricing_bases
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.booking_additional_image_pricing_bases
FORCE ROW LEVEL SECURITY;

REVOKE ALL
ON TABLE public.booking_additional_image_pricing_bases
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE public.booking_additional_image_pricing_bases
TO authenticated;

CREATE POLICY booking_additional_image_pricing_bases_authenticated_select
ON public.booking_additional_image_pricing_bases
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings booking
    WHERE booking.organization_id =
          booking_additional_image_pricing_bases.organization_id
      AND booking.id =
          booking_additional_image_pricing_bases.booking_id
      AND public.has_permission(
            booking.organization_id,
            'payment.read',
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


-- =====================================================================
-- Section J — Controlled deterministic pricing-basis RPC
-- =====================================================================

CREATE FUNCTION
public.record_booking_additional_image_pricing_basis(
  p_booking_id uuid,
  p_selection_addon_version_id uuid
)
RETURNS public.booking_additional_image_pricing_bases
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_booking public.bookings;
  v_state public.booking_journey_states;
  v_stage public.booking_journey_stages;

  v_actor uuid;

  v_state_count bigint := 0;
  v_confirmation_count bigint := 0;
  v_reconciliation_count bigint := 0;
  v_package_line_count bigint := 0;
  v_term_count bigint := 0;

  v_confirmation public.booking_selection_confirmations;
  v_reconciliation public.booking_selection_reconciliations;

  v_quote public.quotations;
  v_package_line public.quotation_line_items;

  v_package_version public.commercial_package_versions;
  v_package public.commercial_packages;

  v_term public.commercial_package_additional_image_terms;

  v_quote_addon_version public.commercial_addon_versions;
  v_quote_addon public.commercial_addons;

  v_selection_addon_version public.commercial_addon_versions;
  v_selection_addon public.commercial_addons;

  v_selection_entitlement_count bigint := 0;
  v_selection_entitlement_per_unit integer;

  v_selection_unit_price_inr integer;

  v_applied_addon_version_id uuid;
  v_applied_unit_price_inr integer;

  v_existing public.booking_additional_image_pricing_bases;
  v_result public.booking_additional_image_pricing_bases;
BEGIN
  IF p_booking_id IS NULL THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: booking_id is required'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Booking is the synchronization root.
  -- ---------------------------------------------------------------

  SELECT booking.*
  INTO v_booking
  FROM public.bookings booking
  WHERE booking.id =
        p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: booking not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_booking.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_booking.organization_id,
    'payment.record',
    v_booking.branch_id
  ) THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: payment.record permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_booking.branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
               v_booking.organization_id,
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: booking branch scope required'
      USING ERRCODE = '42501';
  END IF;

  IF p_selection_addon_version_id IS NOT NULL
     AND NOT public.has_permission(
               v_booking.organization_id,
               'commercial.price.override',
               v_booking.branch_id
             ) THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: commercial.price.override permission required for selection-time basis'
      USING ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact current Stage 12 authority.
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
      'record_booking_additional_image_pricing_basis: booking must have exactly one current journey state'
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
        v_state.current_stage_id;

  IF NOT FOUND
     OR NOT v_stage.is_active
     OR v_stage.stage_order <> 12
     OR v_stage.stage_key <>
        'selection_pending' THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: booking must be at active Stage 12 selection_pending'
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact immutable selection confirmation.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_confirmation_count
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        v_booking.organization_id
    AND confirmation.booking_id =
        v_booking.id;

  IF v_confirmation_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: exactly one selection confirmation required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT confirmation.*
  INTO v_confirmation
  FROM public.booking_selection_confirmations confirmation
  WHERE confirmation.organization_id =
        v_booking.organization_id
    AND confirmation.booking_id =
        v_booking.id;

  -- ---------------------------------------------------------------
  -- Exact positive Slice 7 reconciliation.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_reconciliation_count
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        v_booking.organization_id
    AND reconciliation.booking_id =
        v_booking.id;

  IF v_reconciliation_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: exactly one selection reconciliation required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT reconciliation.*
  INTO v_reconciliation
  FROM public.booking_selection_reconciliations reconciliation
  WHERE reconciliation.organization_id =
        v_booking.organization_id
    AND reconciliation.booking_id =
        v_booking.id;

  IF v_reconciliation.excess_image_count <= 0 THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: positive reconciled excess is required'
      USING ERRCODE = '22023';
  END IF;

  IF v_reconciliation.source_quotation_id
       IS DISTINCT FROM
         v_booking.source_quotation_id
     OR v_reconciliation.source_selection_confirmation_id
       IS DISTINCT FROM
         v_confirmation.id THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: reconciliation lineage is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Exact accepted quotation and package version.
  -- ---------------------------------------------------------------

  SELECT quotation.*
  INTO v_quote
  FROM public.quotations quotation
  WHERE quotation.organization_id =
        v_booking.organization_id
    AND quotation.id =
        v_booking.source_quotation_id;

  IF NOT FOUND
     OR v_quote.status <>
        'accepted'::public.quotation_status THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: accepted source quotation required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)
  INTO v_package_line_count
  FROM public.quotation_line_items line_item
  WHERE line_item.organization_id =
        v_booking.organization_id
    AND line_item.quotation_id =
        v_quote.id
    AND line_item.line_type =
        'package'::public.quotation_line_type;

  IF v_package_line_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: exactly one accepted package line required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT line_item.*
  INTO v_package_line
  FROM public.quotation_line_items line_item
  WHERE line_item.organization_id =
        v_booking.organization_id
    AND line_item.quotation_id =
        v_quote.id
    AND line_item.line_type =
        'package'::public.quotation_line_type;

  SELECT version.*
  INTO v_package_version
  FROM public.commercial_package_versions version
  WHERE version.organization_id =
        v_booking.organization_id
    AND version.id =
        v_package_line.source_package_version_id;

  IF NOT FOUND
     OR v_package_version.approval_status <>
        'approved'::public.commercial_version_approval_status THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: approved source package version required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT package.*
  INTO v_package
  FROM public.commercial_packages package
  WHERE package.organization_id =
        v_booking.organization_id
    AND package.id =
        v_package_version.package_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: canonical source package missing'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- A — exact protected booking-side authority.
  -- ---------------------------------------------------------------

  SELECT count(*)
  INTO v_term_count
  FROM public.commercial_package_additional_image_terms term
  WHERE term.organization_id =
        v_booking.organization_id
    AND term.package_version_id =
        v_package_version.id;

  IF v_term_count <> 1 THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: exact package additional-image term authority required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT term.*
  INTO v_term
  FROM public.commercial_package_additional_image_terms term
  WHERE term.organization_id =
        v_booking.organization_id
    AND term.package_version_id =
        v_package_version.id;

  SELECT version.*
  INTO v_quote_addon_version
  FROM public.commercial_addon_versions version
  WHERE version.organization_id =
        v_booking.organization_id
    AND version.id =
        v_term.additional_image_addon_version_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: A-side add-on version missing'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT addon.*
  INTO v_quote_addon
  FROM public.commercial_addons addon
  WHERE addon.organization_id =
        v_booking.organization_id
    AND addon.id =
        v_quote_addon_version.addon_id;

  IF NOT FOUND
     OR v_quote_addon.addon_key <> 'additional_image'
     OR v_quote_addon_version.approval_status <>
        'approved'::public.commercial_version_approval_status
     OR v_quote_addon_version.pricing_type <>
        'fixed_amount'::public.commercial_pricing_type
     OR v_quote_addon_version.currency <> 'INR'
     OR v_quote_addon_version.amount_inr
        IS DISTINCT FROM
          v_term.unit_price_inr
     OR v_term.currency <> 'INR'
     OR v_term.unit_price_inr <= 0 THEN
    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: A-side commercial authority is inconsistent'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- B — optional exact favorable selection-time authority.
  -- ---------------------------------------------------------------

  v_selection_unit_price_inr := NULL;

  IF p_selection_addon_version_id IS NOT NULL THEN
    SELECT version.*
    INTO v_selection_addon_version
    FROM public.commercial_addon_versions version
    WHERE version.organization_id =
          v_booking.organization_id
      AND version.id =
          p_selection_addon_version_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'record_booking_additional_image_pricing_basis: selection-time add-on version not found'
        USING ERRCODE = '22023';
    END IF;

    SELECT addon.*
    INTO v_selection_addon
    FROM public.commercial_addons addon
    WHERE addon.organization_id =
          v_booking.organization_id
      AND addon.id =
          v_selection_addon_version.addon_id;

    IF NOT FOUND
       OR v_selection_addon.addon_key <> 'additional_image'
       OR v_selection_addon.status <> 'active'
       OR v_selection_addon_version.approval_status <>
          'approved'::public.commercial_version_approval_status
       OR v_selection_addon_version.pricing_type <>
          'fixed_amount'::public.commercial_pricing_type
       OR v_selection_addon_version.currency <> 'INR'
       OR v_selection_addon_version.amount_inr IS NULL
       OR v_selection_addon_version.amount_inr <= 0
       OR v_selection_addon_version.approved_at IS NULL
       OR v_selection_addon_version.approved_at >
          v_confirmation.confirmed_at THEN
      RAISE EXCEPTION
        'record_booking_additional_image_pricing_basis: selection-time commercial version is invalid'
        USING ERRCODE = '22023';
    END IF;

    IF NOT (
      v_package.service_category =
        ANY(v_selection_addon.applicable_service_categories)
    ) THEN
      RAISE EXCEPTION
        'record_booking_additional_image_pricing_basis: selection-time add-on does not support package service category'
        USING ERRCODE = '22023';
    END IF;

    SELECT
      count(*),
      max(entitlement.retouched_image_count_per_unit)
    INTO
      v_selection_entitlement_count,
      v_selection_entitlement_per_unit
    FROM public.commercial_image_entitlements entitlement
    WHERE entitlement.organization_id =
          v_booking.organization_id
      AND entitlement.addon_version_id =
          p_selection_addon_version_id;

    IF v_selection_entitlement_count <> 1
       OR v_selection_entitlement_per_unit
          IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION
        'record_booking_additional_image_pricing_basis: selection-time add-on requires exact one-image entitlement'
        USING ERRCODE = '22023';
    END IF;

    v_selection_unit_price_inr :=
      v_selection_addon_version.amount_inr;
  END IF;

  -- ---------------------------------------------------------------
  -- Client-favorable deterministic rule.
  -- ---------------------------------------------------------------

  v_applied_addon_version_id :=
    v_term.additional_image_addon_version_id;

  v_applied_unit_price_inr :=
    v_term.unit_price_inr;

  IF p_selection_addon_version_id IS NOT NULL
     AND v_selection_unit_price_inr <
         v_term.unit_price_inr THEN
    v_applied_addon_version_id :=
      p_selection_addon_version_id;

    v_applied_unit_price_inr :=
      v_selection_unit_price_inr;
  END IF;

  -- ---------------------------------------------------------------
  -- Exact immutable replay.
  -- ---------------------------------------------------------------

  SELECT basis.*
  INTO v_existing
  FROM public.booking_additional_image_pricing_bases basis
  WHERE basis.organization_id =
        v_booking.organization_id
    AND basis.booking_id =
        v_booking.id;

  IF FOUND THEN
    IF v_existing.source_reconciliation_id
         IS NOT DISTINCT FROM
           v_reconciliation.id
       AND v_existing.source_quotation_id
         IS NOT DISTINCT FROM
           v_quote.id
       AND v_existing.source_selection_confirmation_id
         IS NOT DISTINCT FROM
           v_confirmation.id
       AND v_existing.source_package_version_id
         IS NOT DISTINCT FROM
           v_package_version.id
       AND v_existing.source_package_additional_image_term_id
         IS NOT DISTINCT FROM
           v_term.id
       AND v_existing.quote_acceptance_addon_version_id
         IS NOT DISTINCT FROM
           v_term.additional_image_addon_version_id
       AND v_existing.quote_acceptance_unit_price_inr
         IS NOT DISTINCT FROM
           v_term.unit_price_inr
       AND v_existing.selection_addon_version_id
         IS NOT DISTINCT FROM
           p_selection_addon_version_id
       AND v_existing.selection_unit_price_inr
         IS NOT DISTINCT FROM
           v_selection_unit_price_inr
       AND v_existing.applied_addon_version_id
         IS NOT DISTINCT FROM
           v_applied_addon_version_id
       AND v_existing.applied_unit_price_inr
         IS NOT DISTINCT FROM
           v_applied_unit_price_inr
       AND v_existing.currency = 'INR'
       AND v_existing.pricing_rule =
           'client_favorable_quote_or_selection_v1' THEN
      RETURN v_existing;
    END IF;

    RAISE EXCEPTION
      'record_booking_additional_image_pricing_basis: conflicting immutable pricing-basis evidence already exists'
      USING ERRCODE = 'P0001';
  END IF;

  -- ---------------------------------------------------------------
  -- Persist one immutable per-unit pricing-basis row.
  -- No excess multiplication and no financial obligation.
  -- ---------------------------------------------------------------

  INSERT INTO public.booking_additional_image_pricing_bases (
    organization_id,
    booking_id,
    source_reconciliation_id,
    source_quotation_id,
    source_selection_confirmation_id,
    source_package_version_id,
    source_package_additional_image_term_id,
    quote_acceptance_addon_version_id,
    quote_acceptance_unit_price_inr,
    selection_addon_version_id,
    selection_unit_price_inr,
    applied_addon_version_id,
    applied_unit_price_inr,
    currency,
    pricing_rule,
    recorded_by
  )
  VALUES (
    v_booking.organization_id,
    v_booking.id,
    v_reconciliation.id,
    v_quote.id,
    v_confirmation.id,
    v_package_version.id,
    v_term.id,
    v_term.additional_image_addon_version_id,
    v_term.unit_price_inr,
    p_selection_addon_version_id,
    v_selection_unit_price_inr,
    v_applied_addon_version_id,
    v_applied_unit_price_inr,
    'INR',
    'client_favorable_quote_or_selection_v1',
    v_actor
  )
  RETURNING *
  INTO v_result;

  -- ---------------------------------------------------------------
  -- Structural, non-sensitive audit evidence only.
  -- ---------------------------------------------------------------

  PERFORM public.append_audit_event(
    v_booking.organization_id,
    v_booking.branch_id,
    'booking.additional_image_pricing_basis_recorded',
    'booking',
    v_booking.id,
    false,
    NULL,
    jsonb_build_object(
      'pricing_basis_id',
        v_result.id,
      'pricing_rule',
        v_result.pricing_rule,
      'applied_addon_version_id',
        v_result.applied_addon_version_id,
      'applied_unit_price_inr',
        v_result.applied_unit_price_inr
    ),
    jsonb_build_object(
      'source_reconciliation_id',
        v_result.source_reconciliation_id,
      'source_quotation_id',
        v_result.source_quotation_id,
      'source_selection_confirmation_id',
        v_result.source_selection_confirmation_id,
      'source_package_version_id',
        v_result.source_package_version_id,
      'source_package_additional_image_term_id',
        v_result.source_package_additional_image_term_id,
      'quote_acceptance_addon_version_id',
        v_result.quote_acceptance_addon_version_id,
      'quote_acceptance_unit_price_inr',
        v_result.quote_acceptance_unit_price_inr,
      'selection_addon_version_id',
        v_result.selection_addon_version_id,
      'selection_unit_price_inr',
        v_result.selection_unit_price_inr,
      'recorded_by',
        v_result.recorded_by
    ),
    'finance',
    NULL
  );

  RETURN v_result;
END;
$$;


-- =====================================================================
-- Section K — RPC ACL
-- =====================================================================

REVOKE ALL
ON FUNCTION
  public.record_booking_additional_image_pricing_basis(uuid, uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE
ON FUNCTION
  public.record_booking_additional_image_pricing_basis(uuid, uuid)
TO authenticated;


-- =====================================================================
-- Section L — Migration assertions
-- =====================================================================

DO $s11s8_assertions$
DECLARE
  v_count integer;
  v_function_definition text;
BEGIN
  SELECT count(*)
  INTO v_count
  FROM public.permissions;

  IF v_count <> 68 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: permission catalogue changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.role_permissions;

  IF v_count <> 241 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: role-permission mapping count changed';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_package_additional_image_terms;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: expected 12 package additional-image terms, found %',
      v_count;
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.commercial_package_additional_image_terms term
  JOIN public.commercial_package_versions package_version
    ON package_version.organization_id =
       term.organization_id
   AND package_version.id =
       term.package_version_id
  JOIN public.commercial_packages package
    ON package.organization_id =
       package_version.organization_id
   AND package.id =
       package_version.package_id
  JOIN public.commercial_addon_versions addon_version
    ON addon_version.organization_id =
       term.organization_id
   AND addon_version.id =
       term.additional_image_addon_version_id
  JOIN public.commercial_addons addon
    ON addon.organization_id =
       addon_version.organization_id
   AND addon.id =
       addon_version.addon_id
  JOIN public.commercial_image_entitlements entitlement
    ON entitlement.organization_id =
       addon_version.organization_id
   AND entitlement.addon_version_id =
       addon_version.id
  WHERE package.package_key = ANY(ARRAY[
      'maternity_bronze',
      'maternity_diamond',
      'maternity_emerald',
      'maternity_gold',
      'newborn_bronze',
      'newborn_diamond',
      'newborn_emerald',
      'newborn_gold',
      'sitter_bronze',
      'sitter_diamond',
      'sitter_emerald',
      'sitter_gold'
    ]::text[])
    AND package_version.version_number = 1
    AND package_version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND addon.addon_key = 'additional_image'
    AND addon_version.version_number = 1
    AND addon_version.approval_status =
        'approved'::public.commercial_version_approval_status
    AND term.currency = 'INR'
    AND term.unit_price_inr = 500
    AND term.binding_rule =
        'explicit_package_additional_image_term_v1'
    AND entitlement.retouched_image_count_per_unit = 1;

  IF v_count <> 12 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: current package/additional-image term bindings are inconsistent';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM public.booking_additional_image_pricing_bases;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: booking pricing-basis relation must have zero migration backfill rows';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes index_row
    WHERE index_row.schemaname = 'public'
      AND index_row.tablename =
          'booking_selection_reconciliations'
      AND index_row.indexname =
          'booking_selection_reconciliations_org_booking_id_uidx'
      AND index_row.indexdef ILIKE
          '%UNIQUE INDEX%organization_id, booking_id, id%'
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: tenant-safe reconciliation provenance index missing';
  END IF;

  IF NOT (
    SELECT relation.relrowsecurity
           AND relation.relforcerowsecurity
    FROM pg_class relation
    WHERE relation.oid =
      'public.commercial_package_additional_image_terms'::regclass
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: package-term forced RLS unavailable';
  END IF;

  IF NOT (
    SELECT relation.relrowsecurity
           AND relation.relforcerowsecurity
    FROM pg_class relation
    WHERE relation.oid =
      'public.booking_additional_image_pricing_bases'::regclass
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: booking pricing-basis forced RLS unavailable';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.commercial_package_additional_image_terms',
    'SELECT'
  )
     OR has_table_privilege(
       'authenticated',
       'public.commercial_package_additional_image_terms',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.commercial_package_additional_image_terms',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.commercial_package_additional_image_terms',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: package-term authenticated ACL is invalid';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.booking_additional_image_pricing_bases',
    'SELECT'
  )
     OR has_table_privilege(
       'authenticated',
       'public.booking_additional_image_pricing_bases',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_additional_image_pricing_bases',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.booking_additional_image_pricing_bases',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: booking pricing-basis authenticated ACL is invalid';
  END IF;

  IF to_regprocedure(
       'public.record_booking_additional_image_pricing_basis(uuid,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: controlled pricing-basis RPC missing';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.record_booking_additional_image_pricing_basis(uuid,uuid)',
    'EXECUTE'
  )
     OR has_function_privilege(
       'anon',
       'public.record_booking_additional_image_pricing_basis(uuid,uuid)',
       'EXECUTE'
     )
     OR has_function_privilege(
       'service_role',
       'public.record_booking_additional_image_pricing_basis(uuid,uuid)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: pricing-basis RPC ACL is invalid';
  END IF;

  IF NOT (
    SELECT procedure.prosecdef
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
  ) THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: pricing-basis RPC must be SECURITY DEFINER';
  END IF;

  IF (
    SELECT procedure.proconfig
    FROM pg_proc procedure
    WHERE procedure.oid =
      'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
  ) IS DISTINCT FROM
    ARRAY['search_path=""']::text[] THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: pricing-basis RPC must use empty search_path';
  END IF;

  SELECT pg_get_functiondef(
           'public.record_booking_additional_image_pricing_basis(uuid,uuid)'::regprocedure
         )
  INTO v_function_definition;

  IF v_function_definition ILIKE '%source_revision%'
     OR v_function_definition ILIKE '%max(version_number)%'
     OR v_function_definition ILIKE '%order by%version_number%desc%'
     OR v_function_definition ILIKE '%excess_image_count *%'
     OR v_function_definition ILIKE '%excess_image_count*%' THEN
    RAISE EXCEPTION
      'Sprint 11 Slice 8 failed: forbidden runtime price-resolution or financial-obligation logic detected';
  END IF;
END
$s11s8_assertions$;
