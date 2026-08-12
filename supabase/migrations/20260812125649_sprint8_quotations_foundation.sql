-- =====================================================================
-- Sprint 8 — Packages, Quotations & Booking Conversion Foundation
-- Slice 2: quotations + immutable commercial snapshots
-- =====================================================================

-- SLICE_2_START

-- =====================================================================
-- Section A
-- Preconditions + immutable catalogue evidence + quotation schema
-- =====================================================================

DO $s8q_preflight$
BEGIN
  IF to_regclass('public.commercial_packages') IS NULL
     OR to_regclass('public.commercial_package_versions') IS NULL
     OR to_regclass('public.commercial_package_inclusions') IS NULL
     OR to_regclass('public.commercial_addons') IS NULL
     OR to_regclass('public.commercial_addon_versions') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation precondition failed: commercial catalogue foundation missing';
  END IF;

  IF to_regclass('public.families') IS NULL
     OR to_regclass('public.leads') IS NULL
     OR to_regclass('public.organization_members') IS NULL
     OR to_regclass('public.branches') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation precondition failed: tenant/CRM foundation missing';
  END IF;

  IF to_regprocedure('public.current_organization_member(uuid)') IS NULL
     OR to_regprocedure('public.has_permission(uuid,text,uuid)') IS NULL
     OR to_regprocedure('public.has_branch_scope(uuid,uuid)') IS NULL
     OR to_regprocedure('public.lsh_set_updated_at()') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation precondition failed: access-control helpers missing';
  END IF;

  IF to_regprocedure(
       'public.append_audit_event(uuid,uuid,text,text,uuid,boolean,jsonb,jsonb,jsonb,text,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation precondition failed: audit append RPC missing';
  END IF;

  IF to_regclass('public.quotations') IS NOT NULL
     OR to_regclass('public.quotation_line_items') IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation precondition failed: quotation tables already exist';
  END IF;

  IF to_regtype('public.quotation_status') IS NOT NULL
     OR to_regtype('public.quotation_line_type') IS NOT NULL
     OR to_regtype('public.quotation_pricing_source') IS NOT NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation precondition failed: quotation types already exist';
  END IF;
END
$s8q_preflight$;

-- ---------------------------------------------------------------------
-- Approved catalogue evidence is immutable.
--
-- New commercial definitions must use a new version rather than rewriting
-- an approved version in place.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_commercial_package_version_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.approval_status = 'approved' THEN
    RAISE EXCEPTION
      'approved commercial package versions are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER commercial_package_versions_immutable
BEFORE UPDATE OR DELETE
ON public.commercial_package_versions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_commercial_package_version_immutable_guard();


CREATE OR REPLACE FUNCTION public.lsh_commercial_package_inclusion_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_organization_id uuid;
  v_package_version_id uuid;
  v_status public.commercial_version_approval_status;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_organization_id := NEW.organization_id;
    v_package_version_id := NEW.package_version_id;
  ELSE
    v_organization_id := OLD.organization_id;
    v_package_version_id := OLD.package_version_id;
  END IF;

  SELECT v.approval_status
  INTO v_status
  FROM public.commercial_package_versions v
  WHERE v.organization_id = v_organization_id
    AND v.id = v_package_version_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION
      'commercial package inclusion references a missing package version';
  END IF;

  IF v_status = 'approved' THEN
    RAISE EXCEPTION
      'approved commercial package inclusions are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER commercial_package_inclusions_immutable
BEFORE INSERT OR UPDATE OR DELETE
ON public.commercial_package_inclusions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_commercial_package_inclusion_immutable_guard();


CREATE OR REPLACE FUNCTION public.lsh_commercial_addon_version_immutable_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.approval_status = 'approved' THEN
    RAISE EXCEPTION
      'approved commercial add-on versions are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER commercial_addon_versions_immutable
BEFORE UPDATE OR DELETE
ON public.commercial_addon_versions
FOR EACH ROW
EXECUTE FUNCTION public.lsh_commercial_addon_version_immutable_guard();

-- ---------------------------------------------------------------------
-- Quotation vocabulary
-- ---------------------------------------------------------------------

CREATE TYPE public.quotation_status AS ENUM (
  'draft',
  'ready',
  'sent',
  'accepted',
  'declined',
  'expired',
  'superseded'
);

CREATE TYPE public.quotation_line_type AS ENUM (
  'package',
  'addon',
  'custom'
);

CREATE TYPE public.quotation_pricing_source AS ENUM (
  'catalogue',
  'approved_offer',
  'authorized_override'
);

-- ---------------------------------------------------------------------
-- Quotation aggregate
--
-- expires_at is deliberately nullable. Sprint 8 does not invent a
-- default quote-validity period.
--
-- accepted status exists in the canonical lifecycle, but the only valid
-- acceptance path will be accept_quotation() in the booking slice.
-- ---------------------------------------------------------------------

CREATE TABLE public.quotations (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id         uuid NOT NULL,
  branch_id               uuid,

  quotation_reference     text NOT NULL,

  family_id               uuid,
  lead_id                 uuid,

  status                  public.quotation_status
                          NOT NULL DEFAULT 'draft',

  currency                text NOT NULL DEFAULT 'INR',
  expires_at              timestamptz,

  subtotal_inr            integer NOT NULL DEFAULT 0,
  discount_inr            integer NOT NULL DEFAULT 0,
  quoted_total_inr        integer NOT NULL DEFAULT 0,

  supersedes_quotation_id uuid,

  ready_at                timestamptz,
  sent_at                 timestamptz,
  accepted_at             timestamptz,
  declined_at             timestamptz,
  expired_at              timestamptz,
  superseded_at           timestamptz,

  created_at              timestamptz NOT NULL DEFAULT now(),
  created_by              uuid NOT NULL,
  updated_at              timestamptz NOT NULL DEFAULT now(),
  updated_by              uuid NOT NULL,

  CONSTRAINT quotations_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES public.organizations (id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotations_branch_fkey
    FOREIGN KEY (branch_id, organization_id)
    REFERENCES public.branches (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotations_family_fkey
    FOREIGN KEY (family_id, organization_id)
    REFERENCES public.families (id, organization_id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotations_lead_fkey
    FOREIGN KEY (organization_id, lead_id)
    REFERENCES public.leads (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotations_created_by_fkey
    FOREIGN KEY (organization_id, created_by)
    REFERENCES public.organization_members (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotations_updated_by_fkey
    FOREIGN KEY (organization_id, updated_by)
    REFERENCES public.organization_members (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotations_subject_required_chk
    CHECK (
      family_id IS NOT NULL
      OR lead_id IS NOT NULL
    ),

  CONSTRAINT quotations_reference_format_chk
    CHECK (
      quotation_reference ~ '^LSH-QT-[A-F0-9]{8}$'
    ),

  CONSTRAINT quotations_currency_chk
    CHECK (currency = 'INR'),

  CONSTRAINT quotations_subtotal_chk
    CHECK (subtotal_inr >= 0),

  CONSTRAINT quotations_discount_chk
    CHECK (
      discount_inr >= 0
      AND discount_inr <= subtotal_inr
    ),

  CONSTRAINT quotations_total_chk
    CHECK (
      quoted_total_inr =
        subtotal_inr - discount_inr
      AND quoted_total_inr >= 0
    ),

  CONSTRAINT quotations_supersedes_not_self_chk
    CHECK (
      supersedes_quotation_id IS NULL
      OR supersedes_quotation_id <> id
    ),

  CONSTRAINT quotations_lifecycle_metadata_chk
    CHECK (
      (
        status = 'draft'
        AND ready_at IS NULL
        AND sent_at IS NULL
        AND accepted_at IS NULL
        AND declined_at IS NULL
        AND expired_at IS NULL
        AND superseded_at IS NULL
      )
      OR
      (
        status = 'ready'
        AND ready_at IS NOT NULL
        AND sent_at IS NULL
        AND accepted_at IS NULL
        AND declined_at IS NULL
        AND expired_at IS NULL
        AND superseded_at IS NULL
      )
      OR
      (
        status = 'sent'
        AND ready_at IS NOT NULL
        AND sent_at IS NOT NULL
        AND accepted_at IS NULL
        AND declined_at IS NULL
        AND expired_at IS NULL
        AND superseded_at IS NULL
      )
      OR
      (
        status = 'accepted'
        AND ready_at IS NOT NULL
        AND sent_at IS NOT NULL
        AND accepted_at IS NOT NULL
        AND declined_at IS NULL
        AND expired_at IS NULL
        AND superseded_at IS NULL
      )
      OR
      (
        status = 'declined'
        AND ready_at IS NOT NULL
        AND sent_at IS NOT NULL
        AND accepted_at IS NULL
        AND declined_at IS NOT NULL
        AND expired_at IS NULL
        AND superseded_at IS NULL
      )
      OR
      (
        status = 'expired'
        AND ready_at IS NOT NULL
        AND sent_at IS NOT NULL
        AND accepted_at IS NULL
        AND declined_at IS NULL
        AND expired_at IS NOT NULL
        AND superseded_at IS NULL
      )
      OR
      (
        status = 'superseded'
        AND ready_at IS NOT NULL
        AND sent_at IS NOT NULL
        AND accepted_at IS NULL
        AND declined_at IS NULL
        AND expired_at IS NULL
        AND superseded_at IS NOT NULL
      )
    ),

  CONSTRAINT quotations_organization_reference_key
    UNIQUE (organization_id, quotation_reference),

  CONSTRAINT quotations_organization_id_id_key
    UNIQUE (organization_id, id)
);

ALTER TABLE public.quotations
ADD CONSTRAINT quotations_supersedes_quotation_fkey
FOREIGN KEY (
  organization_id,
  supersedes_quotation_id
)
REFERENCES public.quotations (
  organization_id,
  id
)
ON UPDATE RESTRICT
ON DELETE RESTRICT;

CREATE INDEX quotations_organization_status_idx
ON public.quotations (
  organization_id,
  status,
  created_at DESC
);

CREATE INDEX quotations_organization_family_idx
ON public.quotations (
  organization_id,
  family_id,
  created_at DESC
)
WHERE family_id IS NOT NULL;

CREATE INDEX quotations_organization_lead_idx
ON public.quotations (
  organization_id,
  lead_id,
  created_at DESC
)
WHERE lead_id IS NOT NULL;

CREATE INDEX quotations_organization_supersedes_idx
ON public.quotations (
  organization_id,
  supersedes_quotation_id
)
WHERE supersedes_quotation_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- Quotation line-item commercial snapshots
--
-- catalogue_unit_price_inr stores source catalogue evidence.
-- quoted_unit_price_inr stores the actual authorized amount used.
-- Nothing here derives pricing from privacy/image-use consent.
-- ---------------------------------------------------------------------

CREATE TABLE public.quotation_line_items (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id           uuid NOT NULL,
  quotation_id              uuid NOT NULL,

  line_type                 public.quotation_line_type NOT NULL,

  source_package_version_id uuid,
  source_addon_version_id   uuid,

  item_key                  text NOT NULL,
  item_name                 text NOT NULL,
  description               text,

  quantity                  integer NOT NULL DEFAULT 1,
  currency                  text NOT NULL DEFAULT 'INR',

  catalogue_unit_price_inr  integer,
  quoted_unit_price_inr     integer NOT NULL,
  line_total_inr            integer NOT NULL,

  pricing_source            public.quotation_pricing_source NOT NULL,

  sort_order                integer NOT NULL DEFAULT 0,

  created_at                timestamptz NOT NULL DEFAULT now(),
  created_by                uuid NOT NULL,

  CONSTRAINT quotation_line_items_quotation_fkey
    FOREIGN KEY (organization_id, quotation_id)
    REFERENCES public.quotations (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotation_line_items_package_version_fkey
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

  CONSTRAINT quotation_line_items_addon_version_fkey
    FOREIGN KEY (
      organization_id,
      source_addon_version_id
    )
    REFERENCES public.commercial_addon_versions (
      organization_id,
      id
    )
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotation_line_items_created_by_fkey
    FOREIGN KEY (organization_id, created_by)
    REFERENCES public.organization_members (organization_id, id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,

  CONSTRAINT quotation_line_items_key_format_chk
    CHECK (
      item_key ~ '^[a-z][a-z0-9_]*$'
    ),

  CONSTRAINT quotation_line_items_name_length_chk
    CHECK (
      char_length(item_name) BETWEEN 1 AND 240
    ),

  CONSTRAINT quotation_line_items_quantity_chk
    CHECK (quantity > 0),

  CONSTRAINT quotation_line_items_currency_chk
    CHECK (currency = 'INR'),

  CONSTRAINT quotation_line_items_catalogue_price_chk
    CHECK (
      catalogue_unit_price_inr IS NULL
      OR catalogue_unit_price_inr > 0
    ),

  CONSTRAINT quotation_line_items_quoted_price_chk
    CHECK (quoted_unit_price_inr > 0),

  CONSTRAINT quotation_line_items_total_chk
    CHECK (
      line_total_inr =
        quantity * quoted_unit_price_inr
      AND line_total_inr > 0
    ),

  CONSTRAINT quotation_line_items_source_shape_chk
    CHECK (
      (
        line_type = 'package'
        AND source_package_version_id IS NOT NULL
        AND source_addon_version_id IS NULL
        AND quantity = 1
        AND catalogue_unit_price_inr IS NOT NULL
      )
      OR
      (
        line_type = 'addon'
        AND source_package_version_id IS NULL
        AND source_addon_version_id IS NOT NULL
      )
      OR
      (
        line_type = 'custom'
        AND source_package_version_id IS NULL
        AND source_addon_version_id IS NULL
        AND catalogue_unit_price_inr IS NULL
        AND pricing_source = 'authorized_override'
      )
    ),

  CONSTRAINT quotation_line_items_catalogue_pricing_chk
    CHECK (
      pricing_source <> 'catalogue'
      OR (
        catalogue_unit_price_inr IS NOT NULL
        AND catalogue_unit_price_inr =
            quoted_unit_price_inr
      )
    ),

  CONSTRAINT quotation_line_items_approved_offer_not_executable_chk
    CHECK (
      pricing_source <> 'approved_offer'
    )
);

CREATE UNIQUE INDEX quotation_line_items_one_package_idx
ON public.quotation_line_items (
  organization_id,
  quotation_id
)
WHERE line_type = 'package';

CREATE INDEX quotation_line_items_quotation_idx
ON public.quotation_line_items (
  organization_id,
  quotation_id,
  sort_order,
  created_at
);

-- ---------------------------------------------------------------------
-- Section A local migration assertions
-- ---------------------------------------------------------------------

DO $s8q_section_a_assertions$
DECLARE
  v_count integer;
BEGIN
  IF to_regclass('public.quotations') IS NULL
     OR to_regclass('public.quotation_line_items') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section A failed: quotation tables missing';
  END IF;

  IF to_regtype('public.quotation_status') IS NULL
     OR to_regtype('public.quotation_line_type') IS NULL
     OR to_regtype('public.quotation_pricing_source') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section A failed: quotation types missing';
  END IF;

  SELECT count(*)
  INTO v_count
  FROM pg_trigger t
  JOIN pg_class c
    ON c.oid = t.tgrelid
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND NOT t.tgisinternal
    AND (
      (
        c.relname = 'commercial_package_versions'
        AND t.tgname =
            'commercial_package_versions_immutable'
      )
      OR
      (
        c.relname = 'commercial_package_inclusions'
        AND t.tgname =
            'commercial_package_inclusions_immutable'
      )
      OR
      (
        c.relname = 'commercial_addon_versions'
        AND t.tgname =
            'commercial_addon_versions_immutable'
      )
    );

  IF v_count <> 3 THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section A failed: expected 3 commercial immutability triggers, found %',
      v_count;
  END IF;
END
$s8q_section_a_assertions$;

-- SLICE_2_SECTION_A_END

-- =====================================================================
-- Section B1
-- Quotation guards + total recalculation + create_quotation()
-- =====================================================================

-- ---------------------------------------------------------------------
-- Quotation lifecycle / snapshot guard
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_quotation_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_package_count integer;
BEGIN
  -- Stable identity and lineage never change in place.
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
     OR NEW.quotation_reference IS DISTINCT FROM OLD.quotation_reference
     OR NEW.supersedes_quotation_id IS DISTINCT FROM OLD.supersedes_quotation_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION
      'quotation identity and lineage fields are immutable';
  END IF;

  -- Commercial fields must be finalized before a lifecycle transition.
  IF NEW.status IS DISTINCT FROM OLD.status
     AND (
       NEW.branch_id IS DISTINCT FROM OLD.branch_id
       OR NEW.family_id IS DISTINCT FROM OLD.family_id
       OR NEW.lead_id IS DISTINCT FROM OLD.lead_id
       OR NEW.currency IS DISTINCT FROM OLD.currency
       OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
       OR NEW.subtotal_inr IS DISTINCT FROM OLD.subtotal_inr
       OR NEW.discount_inr IS DISTINCT FROM OLD.discount_inr
       OR NEW.quoted_total_inr IS DISTINCT FROM OLD.quoted_total_inr
     ) THEN
    RAISE EXCEPTION
      'quotation commercial fields cannot change during a lifecycle transition';
  END IF;

  -- Once a quote leaves draft, its commercial snapshot cannot be rewritten.
  IF OLD.status <> 'draft'
     AND (
       NEW.branch_id IS DISTINCT FROM OLD.branch_id
       OR NEW.family_id IS DISTINCT FROM OLD.family_id
       OR NEW.lead_id IS DISTINCT FROM OLD.lead_id
       OR NEW.currency IS DISTINCT FROM OLD.currency
       OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
       OR NEW.subtotal_inr IS DISTINCT FROM OLD.subtotal_inr
       OR NEW.discount_inr IS DISTINCT FROM OLD.discount_inr
       OR NEW.quoted_total_inr IS DISTINCT FROM OLD.quoted_total_inr
     ) THEN
    RAISE EXCEPTION
      'quotation commercial snapshot is immutable after draft';
  END IF;

  -- Lifecycle timestamps cannot be rewritten without changing status.
  IF NEW.status = OLD.status
     AND (
       NEW.ready_at IS DISTINCT FROM OLD.ready_at
       OR NEW.sent_at IS DISTINCT FROM OLD.sent_at
       OR NEW.accepted_at IS DISTINCT FROM OLD.accepted_at
       OR NEW.declined_at IS DISTINCT FROM OLD.declined_at
       OR NEW.expired_at IS DISTINCT FROM OLD.expired_at
       OR NEW.superseded_at IS DISTINCT FROM OLD.superseded_at
     ) THEN
    RAISE EXCEPTION
      'quotation lifecycle timestamps may change only with status';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status = 'draft'
       AND NEW.status = 'ready' THEN

      SELECT count(*)
      INTO v_package_count
      FROM public.quotation_line_items li
      WHERE li.organization_id = OLD.organization_id
        AND li.quotation_id = OLD.id
        AND li.line_type = 'package';

      IF v_package_count <> 1 THEN
        RAISE EXCEPTION
          'quotation requires exactly one package line before ready';
      END IF;

      IF OLD.quoted_total_inr <= 0 THEN
        RAISE EXCEPTION
          'quotation total must be greater than zero before ready';
      END IF;

      IF NEW.ready_at IS NULL THEN
        RAISE EXCEPTION
          'ready quotation requires ready_at';
      END IF;

    ELSIF OLD.status = 'ready'
          AND NEW.status = 'draft' THEN

      IF NEW.ready_at IS NOT NULL THEN
        RAISE EXCEPTION
          'returning quotation to draft must clear ready_at';
      END IF;

    ELSIF OLD.status = 'ready'
          AND NEW.status = 'sent' THEN

      IF NEW.sent_at IS NULL THEN
        RAISE EXCEPTION
          'sent quotation requires sent_at';
      END IF;

    ELSIF OLD.status = 'sent'
          AND NEW.status = 'accepted' THEN

      IF NEW.accepted_at IS NULL THEN
        RAISE EXCEPTION
          'accepted quotation requires accepted_at';
      END IF;

    ELSIF OLD.status = 'sent'
          AND NEW.status = 'declined' THEN

      IF NEW.declined_at IS NULL THEN
        RAISE EXCEPTION
          'declined quotation requires declined_at';
      END IF;

    ELSIF OLD.status = 'sent'
          AND NEW.status = 'expired' THEN

      IF NEW.expired_at IS NULL THEN
        RAISE EXCEPTION
          'expired quotation requires expired_at';
      END IF;

    ELSIF OLD.status = 'sent'
          AND NEW.status = 'superseded' THEN

      IF NEW.superseded_at IS NULL THEN
        RAISE EXCEPTION
          'superseded quotation requires superseded_at';
      END IF;

    ELSE
      RAISE EXCEPTION
        'invalid quotation lifecycle transition from % to %',
        OLD.status,
        NEW.status;
    END IF;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER quotations_guard
BEFORE UPDATE
ON public.quotations
FOR EACH ROW
EXECUTE FUNCTION public.lsh_quotation_guard();

CREATE TRIGGER quotations_set_updated_at
BEFORE UPDATE
ON public.quotations
FOR EACH ROW
EXECUTE FUNCTION public.lsh_set_updated_at();

-- ---------------------------------------------------------------------
-- Draft-line mutation guard
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_quotation_line_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_organization_id uuid;
  v_quotation_id uuid;
  v_status public.quotation_status;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_organization_id := OLD.organization_id;
    v_quotation_id := OLD.quotation_id;
  ELSE
    v_organization_id := NEW.organization_id;
    v_quotation_id := NEW.quotation_id;
  END IF;

  SELECT q.status
  INTO v_status
  FROM public.quotations q
  WHERE q.organization_id = v_organization_id
    AND q.id = v_quotation_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION
      'quotation line references a missing quotation';
  END IF;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION
      'quotation line items are immutable after draft';
  END IF;

  IF TG_OP = 'UPDATE'
     AND (
       NEW.id IS DISTINCT FROM OLD.id
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.quotation_id IS DISTINCT FROM OLD.quotation_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
     ) THEN
    RAISE EXCEPTION
      'quotation line identity fields are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER quotation_line_items_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.quotation_line_items
FOR EACH ROW
EXECUTE FUNCTION public.lsh_quotation_line_guard();

-- ---------------------------------------------------------------------
-- Canonical quotation totals
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lsh_refresh_quotation_totals(
  p_organization_id uuid,
  p_quotation_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_subtotal integer;
  v_actor uuid;
BEGIN
  SELECT COALESCE(sum(li.line_total_inr), 0)::integer
  INTO v_subtotal
  FROM public.quotation_line_items li
  WHERE li.organization_id = p_organization_id
    AND li.quotation_id = p_quotation_id;

  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  UPDATE public.quotations q
  SET
    subtotal_inr = v_subtotal,
    quoted_total_inr =
      v_subtotal - q.discount_inr,
    updated_by =
      COALESCE(v_actor, q.updated_by)
  WHERE q.organization_id = p_organization_id
    AND q.id = p_quotation_id;
END
$$;


CREATE OR REPLACE FUNCTION public.lsh_quotation_line_totals_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.lsh_refresh_quotation_totals(
      OLD.organization_id,
      OLD.quotation_id
    );

    RETURN OLD;
  END IF;

  PERFORM public.lsh_refresh_quotation_totals(
    NEW.organization_id,
    NEW.quotation_id
  );

  IF TG_OP = 'UPDATE'
     AND (
       OLD.organization_id IS DISTINCT FROM NEW.organization_id
       OR OLD.quotation_id IS DISTINCT FROM NEW.quotation_id
     ) THEN
    PERFORM public.lsh_refresh_quotation_totals(
      OLD.organization_id,
      OLD.quotation_id
    );
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER quotation_line_items_refresh_totals
AFTER INSERT OR UPDATE OR DELETE
ON public.quotation_line_items
FOR EACH ROW
EXECUTE FUNCTION public.lsh_quotation_line_totals_trigger();

-- ---------------------------------------------------------------------
-- create_quotation()
--
-- Reference pattern follows Leads: random UUID-derived immutable reference.
-- Branch is resolved from the explicit request or the related lead/family.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_quotation(
  p_organization_id uuid,
  p_family_id uuid DEFAULT NULL,
  p_lead_id uuid DEFAULT NULL,
  p_branch_id uuid DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_supersedes_quotation_id uuid DEFAULT NULL
)
RETURNS public.quotations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;

  v_family_branch_id uuid;
  v_lead_branch_id uuid;
  v_lead_converted_family_id uuid;
  v_branch_id uuid;

  v_id uuid;
  v_reference text;
  v_attempt integer := 0;

  v_quote public.quotations;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION
      'create_quotation: organization_id is required'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      p_organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'create_quotation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF p_family_id IS NULL
     AND p_lead_id IS NULL THEN
    RAISE EXCEPTION
      'create_quotation: family_id or lead_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_expires_at IS NOT NULL
     AND p_expires_at <= now() THEN
    RAISE EXCEPTION
      'create_quotation: expires_at must be in the future'
      USING ERRCODE = '22023';
  END IF;

  IF p_family_id IS NOT NULL THEN
    SELECT f.branch_id
    INTO v_family_branch_id
    FROM public.families f
    WHERE f.organization_id = p_organization_id
      AND f.id = p_family_id
      AND f.status = 'active';

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'create_quotation: family must be active in this organization'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_lead_id IS NOT NULL THEN
    SELECT
      l.branch_id,
      l.converted_family_id
    INTO
      v_lead_branch_id,
      v_lead_converted_family_id
    FROM public.leads l
    WHERE l.organization_id = p_organization_id
      AND l.id = p_lead_id
      AND l.archived_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'create_quotation: lead must belong to this organization'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_family_id IS NOT NULL
     AND p_lead_id IS NOT NULL
     AND v_lead_converted_family_id IS NOT NULL
     AND v_lead_converted_family_id <> p_family_id THEN
    RAISE EXCEPTION
      'create_quotation: lead and family relationship is inconsistent'
      USING ERRCODE = '22023';
  END IF;

  IF v_family_branch_id IS NOT NULL
     AND v_lead_branch_id IS NOT NULL
     AND v_family_branch_id <> v_lead_branch_id THEN
    RAISE EXCEPTION
      'create_quotation: lead and family belong to different branches'
      USING ERRCODE = '22023';
  END IF;

  v_branch_id :=
    COALESCE(
      p_branch_id,
      v_family_branch_id,
      v_lead_branch_id
    );

  IF p_branch_id IS NOT NULL
     AND v_family_branch_id IS NOT NULL
     AND p_branch_id <> v_family_branch_id THEN
    RAISE EXCEPTION
      'create_quotation: requested branch does not match family branch'
      USING ERRCODE = '22023';
  END IF;

  IF p_branch_id IS NOT NULL
     AND v_lead_branch_id IS NOT NULL
     AND p_branch_id <> v_lead_branch_id THEN
    RAISE EXCEPTION
      'create_quotation: requested branch does not match lead branch'
      USING ERRCODE = '22023';
  END IF;

  IF NOT public.has_permission(
    p_organization_id,
    'quote.write',
    v_branch_id
  ) THEN
    RAISE EXCEPTION
      'create_quotation: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_branch_id IS NOT NULL
     AND NOT public.has_branch_scope(
       p_organization_id,
       v_branch_id
     ) THEN
    RAISE EXCEPTION
      'create_quotation: no access to requested branch'
      USING ERRCODE = '42501';
  END IF;

  IF p_supersedes_quotation_id IS NOT NULL THEN
    PERFORM 1
    FROM public.quotations q
    WHERE q.organization_id = p_organization_id
      AND q.id = p_supersedes_quotation_id
      AND q.family_id IS NOT DISTINCT FROM p_family_id
      AND q.lead_id IS NOT DISTINCT FROM p_lead_id
      AND q.branch_id IS NOT DISTINCT FROM v_branch_id
      AND q.status IN (
        'sent',
        'declined',
        'expired',
        'superseded'
      );

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'create_quotation: superseded quotation must be a prior sent or terminal non-accepted quotation for the same subject'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  LOOP
    v_attempt := v_attempt + 1;

    v_id := gen_random_uuid();

    v_reference :=
      'LSH-QT-' ||
      upper(
        substr(
          replace(v_id::text, '-', ''),
          1,
          8
        )
      );

    BEGIN
      INSERT INTO public.quotations (
        id,
        organization_id,
        branch_id,
        quotation_reference,
        family_id,
        lead_id,
        status,
        currency,
        expires_at,
        supersedes_quotation_id,
        created_by,
        updated_by
      )
      VALUES (
        v_id,
        p_organization_id,
        v_branch_id,
        v_reference,
        p_family_id,
        p_lead_id,
        'draft',
        'INR',
        p_expires_at,
        p_supersedes_quotation_id,
        v_actor,
        v_actor
      )
      RETURNING *
      INTO v_quote;

      EXIT;

    EXCEPTION
      WHEN unique_violation THEN
        IF v_attempt >= 5 THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.created',
    'quotation',
    v_quote.id,
    true,
    NULL,
    jsonb_build_object(
      'quotation_reference',
        v_quote.quotation_reference,
      'status',
        v_quote.status,
      'currency',
        v_quote.currency
    ),
    jsonb_build_object(
      'has_family',
        v_quote.family_id IS NOT NULL,
      'has_lead',
        v_quote.lead_id IS NOT NULL,
      'has_expiry',
        v_quote.expires_at IS NOT NULL,
      'supersedes_prior_quote',
        v_quote.supersedes_quotation_id IS NOT NULL
    ),
    'commercial',
    NULL
  );

  RETURN v_quote;
END
$$;

-- ---------------------------------------------------------------------
-- Section B1 assertions
-- ---------------------------------------------------------------------

DO $s8q_section_b1_assertions$
BEGIN
  IF to_regprocedure(
       'public.create_quotation(uuid,uuid,uuid,uuid,timestamptz,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B1 failed: create_quotation() missing';
  END IF;

  IF to_regprocedure(
       'public.lsh_refresh_quotation_totals(uuid,uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B1 failed: totals helper missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    WHERE t.tgrelid = 'public.quotations'::regclass
      AND t.tgname = 'quotations_guard'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B1 failed: quotation guard missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    WHERE t.tgrelid =
          'public.quotation_line_items'::regclass
      AND t.tgname =
          'quotation_line_items_refresh_totals'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B1 failed: totals trigger missing';
  END IF;
END
$s8q_section_b1_assertions$;

-- SLICE_2_SECTION_B1_END

-- =====================================================================
-- Section B2
-- Controlled quotation line-item mutation RPCs
-- =====================================================================

-- ---------------------------------------------------------------------
-- Add canonical package line
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.add_quotation_package_line(
  p_quotation_id uuid,
  p_package_version_id uuid,
  p_override_unit_price_inr integer DEFAULT NULL
)
RETURNS public.quotation_line_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
  v_actor uuid;

  v_package_version_id uuid;
  v_package_key text;
  v_package_name text;
  v_catalogue_price integer;
  v_currency text;

  v_quoted_price integer;
  v_pricing_source public.quotation_pricing_source;

  v_line public.quotation_line_items;
BEGIN
  IF p_quotation_id IS NULL
     OR p_package_version_id IS NULL THEN
    RAISE EXCEPTION
      'add_quotation_package_line: quotation_id and package_version_id are required'
      USING ERRCODE = '22023';
  END IF;

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.id = p_quotation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'add_quotation_package_line: quotation not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_quote.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'add_quotation_package_line: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_quote.organization_id,
    'quote.write',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'add_quotation_package_line: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_quote.status <> 'draft' THEN
    RAISE EXCEPTION
      'add_quotation_package_line: quotation must be draft'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.quotation_line_items li
    WHERE li.organization_id =
          v_quote.organization_id
      AND li.quotation_id = v_quote.id
      AND li.line_type = 'package'
  ) THEN
    RAISE EXCEPTION
      'add_quotation_package_line: quotation already has a package line'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    pv.id,
    p.package_key,
    p.public_name,
    pv.list_price_inr,
    pv.currency
  INTO
    v_package_version_id,
    v_package_key,
    v_package_name,
    v_catalogue_price,
    v_currency
  FROM public.commercial_package_versions pv
  JOIN public.commercial_packages p
    ON p.organization_id = pv.organization_id
   AND p.id = pv.package_id
  WHERE pv.organization_id =
        v_quote.organization_id
    AND pv.id = p_package_version_id
    AND pv.approval_status = 'approved'
    AND p.status = 'active'
    AND (
      pv.effective_from IS NULL
      OR pv.effective_from <= current_date
    )
    AND (
      pv.effective_until IS NULL
      OR pv.effective_until >= current_date
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'add_quotation_package_line: approved active package version required'
      USING ERRCODE = '22023';
  END IF;

  IF v_currency <> v_quote.currency THEN
    RAISE EXCEPTION
      'add_quotation_package_line: package currency does not match quotation'
      USING ERRCODE = '22023';
  END IF;

  IF p_override_unit_price_inr IS NULL
     OR p_override_unit_price_inr =
        v_catalogue_price THEN

    v_quoted_price := v_catalogue_price;
    v_pricing_source := 'catalogue';

  ELSE
    IF p_override_unit_price_inr <= 0 THEN
      RAISE EXCEPTION
        'add_quotation_package_line: override price must be positive'
        USING ERRCODE = '22023';
    END IF;

    IF NOT public.has_permission(
      v_quote.organization_id,
      'commercial.price.override',
      v_quote.branch_id
    ) THEN
      RAISE EXCEPTION
        'add_quotation_package_line: commercial.price.override permission required'
        USING ERRCODE = '42501';
    END IF;

    v_quoted_price := p_override_unit_price_inr;
    v_pricing_source := 'authorized_override';
  END IF;

  INSERT INTO public.quotation_line_items (
    organization_id,
    quotation_id,
    line_type,
    source_package_version_id,
    source_addon_version_id,
    item_key,
    item_name,
    description,
    quantity,
    currency,
    catalogue_unit_price_inr,
    quoted_unit_price_inr,
    line_total_inr,
    pricing_source,
    sort_order,
    created_by
  )
  VALUES (
    v_quote.organization_id,
    v_quote.id,
    'package',
    v_package_version_id,
    NULL,
    v_package_key,
    v_package_name,
    NULL,
    1,
    v_quote.currency,
    v_catalogue_price,
    v_quoted_price,
    v_quoted_price,
    v_pricing_source,
    10,
    v_actor
  )
  RETURNING *
  INTO v_line;

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.line_added',
    'quotation',
    v_quote.id,
    true,
    NULL,
    jsonb_build_object(
      'line_type',
        'package',
      'item_key',
        v_line.item_key,
      'catalogue_unit_price_inr',
        v_line.catalogue_unit_price_inr,
      'quoted_unit_price_inr',
        v_line.quoted_unit_price_inr,
      'pricing_source',
        v_line.pricing_source
    ),
    jsonb_build_object(
      'line_item_id',
        v_line.id
    ),
    'commercial',
    NULL
  );

  RETURN v_line;
END
$$;

-- ---------------------------------------------------------------------
-- Add structured catalogue add-on line
--
-- Fixed-amount add-ons use their approved fixed price.
-- Percentage add-ons derive their amount from the actual quoted package
-- price. Example: the sourced twins +20% rule.
-- Variable add-ons have no invented catalogue amount and therefore
-- require an explicit authorized price.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.add_quotation_addon_line(
  p_quotation_id uuid,
  p_addon_version_id uuid,
  p_quantity integer DEFAULT 1,
  p_override_unit_price_inr integer DEFAULT NULL
)
RETURNS public.quotation_line_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
  v_actor uuid;

  v_package_key text;
  v_package_category text;
  v_package_quoted_price integer;

  v_addon_version_id uuid;
  v_addon_key text;
  v_addon_name text;
  v_addon_description text;
  v_pricing_type public.commercial_pricing_type;
  v_fixed_amount integer;
  v_percentage numeric(7,4);
  v_categories text[];
  v_package_keys text[];
  v_currency text;

  v_catalogue_price integer;
  v_quoted_price integer;
  v_pricing_source public.quotation_pricing_source;

  v_line public.quotation_line_items;
BEGIN
  IF p_quotation_id IS NULL
     OR p_addon_version_id IS NULL THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: quotation_id and addon_version_id are required'
      USING ERRCODE = '22023';
  END IF;

  IF p_quantity IS NULL
     OR p_quantity <= 0 THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: quantity must be positive'
      USING ERRCODE = '22023';
  END IF;

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.id = p_quotation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: quotation not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_quote.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_quote.organization_id,
    'quote.write',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_quote.status <> 'draft' THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: quotation must be draft'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    p.package_key,
    p.service_category,
    li.quoted_unit_price_inr
  INTO
    v_package_key,
    v_package_category,
    v_package_quoted_price
  FROM public.quotation_line_items li
  JOIN public.commercial_package_versions pv
    ON pv.organization_id = li.organization_id
   AND pv.id = li.source_package_version_id
  JOIN public.commercial_packages p
    ON p.organization_id = pv.organization_id
   AND p.id = pv.package_id
  WHERE li.organization_id =
        v_quote.organization_id
    AND li.quotation_id = v_quote.id
    AND li.line_type = 'package';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: package line required before add-ons'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    av.id,
    a.addon_key,
    a.public_name,
    a.description,
    av.pricing_type,
    av.amount_inr,
    av.percentage_value,
    a.applicable_service_categories,
    a.applicable_package_keys,
    av.currency
  INTO
    v_addon_version_id,
    v_addon_key,
    v_addon_name,
    v_addon_description,
    v_pricing_type,
    v_fixed_amount,
    v_percentage,
    v_categories,
    v_package_keys,
    v_currency
  FROM public.commercial_addon_versions av
  JOIN public.commercial_addons a
    ON a.organization_id = av.organization_id
   AND a.id = av.addon_id
  WHERE av.organization_id =
        v_quote.organization_id
    AND av.id = p_addon_version_id
    AND av.approval_status = 'approved'
    AND a.status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: approved active add-on version required'
      USING ERRCODE = '22023';
  END IF;

  IF v_currency <> v_quote.currency THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: add-on currency does not match quotation'
      USING ERRCODE = '22023';
  END IF;

  IF NOT (
    v_package_category = ANY(v_categories)
  ) THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: add-on is not valid for selected service category'
      USING ERRCODE = '22023';
  END IF;

  IF cardinality(v_package_keys) > 0
     AND NOT (
       v_package_key = ANY(v_package_keys)
     ) THEN
    RAISE EXCEPTION
      'add_quotation_addon_line: add-on is not valid for selected package'
      USING ERRCODE = '22023';
  END IF;

  IF v_pricing_type = 'fixed_amount' THEN
    v_catalogue_price := v_fixed_amount;

  ELSIF v_pricing_type = 'percentage' THEN
    IF p_quantity <> 1 THEN
      RAISE EXCEPTION
        'add_quotation_addon_line: percentage add-ons require quantity 1'
        USING ERRCODE = '22023';
    END IF;

    v_catalogue_price :=
      round(
        v_package_quoted_price::numeric
        * v_percentage
        / 100
      )::integer;

    IF v_catalogue_price <= 0 THEN
      RAISE EXCEPTION
        'add_quotation_addon_line: derived percentage price must be positive'
        USING ERRCODE = '22023';
    END IF;

  ELSIF v_pricing_type = 'variable' THEN
    v_catalogue_price := NULL;

  ELSE
    RAISE EXCEPTION
      'add_quotation_addon_line: unsupported add-on pricing type'
      USING ERRCODE = '22023';
  END IF;

  IF v_pricing_type = 'variable' THEN
    IF p_override_unit_price_inr IS NULL
       OR p_override_unit_price_inr <= 0 THEN
      RAISE EXCEPTION
        'add_quotation_addon_line: variable add-on requires an authorized explicit price'
        USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission(
      v_quote.organization_id,
      'commercial.price.override',
      v_quote.branch_id
    ) THEN
      RAISE EXCEPTION
        'add_quotation_addon_line: commercial.price.override permission required'
        USING ERRCODE = '42501';
    END IF;

    v_quoted_price :=
      p_override_unit_price_inr;

    v_pricing_source :=
      'authorized_override';

  ELSIF p_override_unit_price_inr IS NULL
        OR p_override_unit_price_inr =
           v_catalogue_price THEN

    v_quoted_price :=
      v_catalogue_price;

    v_pricing_source :=
      'catalogue';

  ELSE
    IF p_override_unit_price_inr <= 0 THEN
      RAISE EXCEPTION
        'add_quotation_addon_line: override price must be positive'
        USING ERRCODE = '22023';
    END IF;

    IF NOT public.has_permission(
      v_quote.organization_id,
      'commercial.price.override',
      v_quote.branch_id
    ) THEN
      RAISE EXCEPTION
        'add_quotation_addon_line: commercial.price.override permission required'
        USING ERRCODE = '42501';
    END IF;

    v_quoted_price :=
      p_override_unit_price_inr;

    v_pricing_source :=
      'authorized_override';
  END IF;

  INSERT INTO public.quotation_line_items (
    organization_id,
    quotation_id,
    line_type,
    source_package_version_id,
    source_addon_version_id,
    item_key,
    item_name,
    description,
    quantity,
    currency,
    catalogue_unit_price_inr,
    quoted_unit_price_inr,
    line_total_inr,
    pricing_source,
    sort_order,
    created_by
  )
  VALUES (
    v_quote.organization_id,
    v_quote.id,
    'addon',
    NULL,
    v_addon_version_id,
    v_addon_key,
    v_addon_name,
    v_addon_description,
    p_quantity,
    v_quote.currency,
    v_catalogue_price,
    v_quoted_price,
    p_quantity * v_quoted_price,
    v_pricing_source,
    100,
    v_actor
  )
  RETURNING *
  INTO v_line;

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.line_added',
    'quotation',
    v_quote.id,
    true,
    NULL,
    jsonb_build_object(
      'line_type',
        'addon',
      'item_key',
        v_line.item_key,
      'quantity',
        v_line.quantity,
      'catalogue_unit_price_inr',
        v_line.catalogue_unit_price_inr,
      'quoted_unit_price_inr',
        v_line.quoted_unit_price_inr,
      'pricing_source',
        v_line.pricing_source
    ),
    jsonb_build_object(
      'line_item_id',
        v_line.id
    ),
    'commercial',
    NULL
  );

  RETURN v_line;
END
$$;

-- ---------------------------------------------------------------------
-- Founder-authorized non-catalogue line
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.add_quotation_custom_line(
  p_quotation_id uuid,
  p_item_name text,
  p_description text,
  p_quantity integer,
  p_unit_price_inr integer
)
RETURNS public.quotation_line_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
  v_actor uuid;

  v_name text;
  v_line_id uuid;
  v_line public.quotation_line_items;
BEGIN
  IF p_quotation_id IS NULL THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: quotation_id is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.id = p_quotation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: quotation not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_quote.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_quote.organization_id,
    'quote.write',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_quote.organization_id,
    'commercial.price.override',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: commercial.price.override permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_quote.status <> 'draft' THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: quotation must be draft'
      USING ERRCODE = '22023';
  END IF;

  v_name :=
    NULLIF(
      btrim(p_item_name),
      ''
    );

  IF v_name IS NULL THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: item name is required'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(v_name) > 240 THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: item name is too long'
      USING ERRCODE = '22023';
  END IF;

  IF p_quantity IS NULL
     OR p_quantity <= 0 THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: quantity must be positive'
      USING ERRCODE = '22023';
  END IF;

  IF p_unit_price_inr IS NULL
     OR p_unit_price_inr <= 0 THEN
    RAISE EXCEPTION
      'add_quotation_custom_line: unit price must be positive'
      USING ERRCODE = '22023';
  END IF;

  v_line_id := gen_random_uuid();

  INSERT INTO public.quotation_line_items (
    id,
    organization_id,
    quotation_id,
    line_type,
    source_package_version_id,
    source_addon_version_id,
    item_key,
    item_name,
    description,
    quantity,
    currency,
    catalogue_unit_price_inr,
    quoted_unit_price_inr,
    line_total_inr,
    pricing_source,
    sort_order,
    created_by
  )
  VALUES (
    v_line_id,
    v_quote.organization_id,
    v_quote.id,
    'custom',
    NULL,
    NULL,
    'custom_' ||
      substr(
        replace(v_line_id::text, '-', ''),
        1,
        8
      ),
    v_name,
    NULLIF(
      btrim(p_description),
      ''
    ),
    p_quantity,
    v_quote.currency,
    NULL,
    p_unit_price_inr,
    p_quantity * p_unit_price_inr,
    'authorized_override',
    200,
    v_actor
  )
  RETURNING *
  INTO v_line;

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.line_added',
    'quotation',
    v_quote.id,
    true,
    NULL,
    jsonb_build_object(
      'line_type',
        'custom',
      'item_key',
        v_line.item_key,
      'quantity',
        v_line.quantity,
      'quoted_unit_price_inr',
        v_line.quoted_unit_price_inr,
      'pricing_source',
        v_line.pricing_source
    ),
    jsonb_build_object(
      'line_item_id',
        v_line.id
    ),
    'commercial',
    NULL
  );

  RETURN v_line;
END
$$;

-- ---------------------------------------------------------------------
-- Remove a draft quotation line.
--
-- A package cannot be removed while dependent add-ons remain because
-- doing so could leave package/category-specific add-ons attached to a
-- replacement package for which they are invalid.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.remove_quotation_line(
  p_line_item_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_line public.quotation_line_items;
  v_quote public.quotations;
  v_actor uuid;

  v_remaining_subtotal integer;
BEGIN
  IF p_line_item_id IS NULL THEN
    RAISE EXCEPTION
      'remove_quotation_line: line_item_id is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT li.*
  INTO v_line
  FROM public.quotation_line_items li
  WHERE li.id = p_line_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'remove_quotation_line: line item not found'
      USING ERRCODE = '22023';
  END IF;

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.organization_id =
        v_line.organization_id
    AND q.id =
        v_line.quotation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'remove_quotation_line: quotation not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_quote.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'remove_quotation_line: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_quote.organization_id,
    'quote.write',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'remove_quotation_line: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_quote.status <> 'draft' THEN
    RAISE EXCEPTION
      'remove_quotation_line: quotation must be draft'
      USING ERRCODE = '22023';
  END IF;

  IF v_line.line_type = 'package'
     AND EXISTS (
       SELECT 1
       FROM public.quotation_line_items li
       WHERE li.organization_id =
             v_quote.organization_id
         AND li.quotation_id =
             v_quote.id
         AND li.line_type = 'addon'
     ) THEN
    RAISE EXCEPTION
      'remove_quotation_line: remove add-ons before removing the package line'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    COALESCE(
      sum(li.line_total_inr),
      0
    )::integer
  INTO v_remaining_subtotal
  FROM public.quotation_line_items li
  WHERE li.organization_id =
        v_quote.organization_id
    AND li.quotation_id =
        v_quote.id
    AND li.id <> v_line.id;

  IF v_quote.discount_inr >
     v_remaining_subtotal THEN
    RAISE EXCEPTION
      'remove_quotation_line: reduce quotation discount before removing this line'
      USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.quotation_line_items
  WHERE organization_id =
        v_line.organization_id
    AND id =
        v_line.id;

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.line_removed',
    'quotation',
    v_quote.id,
    true,
    jsonb_build_object(
      'line_item_id',
        v_line.id,
      'line_type',
        v_line.line_type,
      'item_key',
        v_line.item_key,
      'quantity',
        v_line.quantity,
      'quoted_unit_price_inr',
        v_line.quoted_unit_price_inr,
      'line_total_inr',
        v_line.line_total_inr,
      'pricing_source',
        v_line.pricing_source
    ),
    NULL,
    '{}'::jsonb,
    'commercial',
    NULL
  );
END
$$;

-- ---------------------------------------------------------------------
-- Section B2 assertions
-- ---------------------------------------------------------------------

DO $s8q_section_b2_assertions$
BEGIN
  IF to_regprocedure(
       'public.add_quotation_package_line(uuid,uuid,integer)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B2 failed: package-line RPC missing';
  END IF;

  IF to_regprocedure(
       'public.add_quotation_addon_line(uuid,uuid,integer,integer)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B2 failed: add-on-line RPC missing';
  END IF;

  IF to_regprocedure(
       'public.add_quotation_custom_line(uuid,text,text,integer,integer)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B2 failed: custom-line RPC missing';
  END IF;

  IF to_regprocedure(
       'public.remove_quotation_line(uuid)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section B2 failed: remove-line RPC missing';
  END IF;
END
$s8q_section_b2_assertions$;

-- SLICE_2_SECTION_B2_END

-- =====================================================================
-- Section C1
-- Quote-level discount + controlled lifecycle transitions
-- =====================================================================

-- ---------------------------------------------------------------------
-- Quote-level discount
--
-- A zero discount is ordinary quote maintenance.
-- Any positive discount requires the separately elevated
-- commercial.price.override capability.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_quotation_discount(
  p_quotation_id uuid,
  p_discount_inr integer
)
RETURNS public.quotations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
  v_actor uuid;
  v_old_discount integer;
BEGIN
  IF p_quotation_id IS NULL THEN
    RAISE EXCEPTION
      'set_quotation_discount: quotation_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_discount_inr IS NULL
     OR p_discount_inr < 0 THEN
    RAISE EXCEPTION
      'set_quotation_discount: discount must be zero or greater'
      USING ERRCODE = '22023';
  END IF;

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.id = p_quotation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'set_quotation_discount: quotation not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_quote.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'set_quotation_discount: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_quote.organization_id,
    'quote.write',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'set_quotation_discount: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF v_quote.status <> 'draft' THEN
    RAISE EXCEPTION
      'set_quotation_discount: quotation must be draft'
      USING ERRCODE = '22023';
  END IF;

  IF p_discount_inr > v_quote.subtotal_inr THEN
    RAISE EXCEPTION
      'set_quotation_discount: discount must be between zero and subtotal'
      USING ERRCODE = '22023';
  END IF;

  IF p_discount_inr > 0
     AND NOT public.has_permission(
       v_quote.organization_id,
       'commercial.price.override',
       v_quote.branch_id
     ) THEN
    RAISE EXCEPTION
      'set_quotation_discount: commercial.price.override permission required'
      USING ERRCODE = '42501';
  END IF;

  v_old_discount := v_quote.discount_inr;

  UPDATE public.quotations
  SET
    discount_inr = p_discount_inr,
    quoted_total_inr =
      subtotal_inr - p_discount_inr,
    updated_by = v_actor
  WHERE organization_id =
        v_quote.organization_id
    AND id =
        v_quote.id
  RETURNING *
  INTO v_quote;

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.discount_changed',
    'quotation',
    v_quote.id,
    true,
    jsonb_build_object(
      'discount_inr',
        v_old_discount
    ),
    jsonb_build_object(
      'discount_inr',
        v_quote.discount_inr,
      'quoted_total_inr',
        v_quote.quoted_total_inr
    ),
    '{}'::jsonb,
    'commercial',
    NULL
  );

  RETURN v_quote;
END
$$;

-- ---------------------------------------------------------------------
-- Controlled lifecycle
--
-- accepted is deliberately NOT available here.
-- Slice 3 accept_quotation() must atomically create the booking shell
-- and Advance Pending journey state.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.transition_quotation(
  p_quotation_id uuid,
  p_target_status public.quotation_status
)
RETURNS public.quotations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_quote public.quotations;
  v_actor uuid;
  v_old_status public.quotation_status;

  v_prior_quote public.quotations;
  v_prior_was_superseded boolean := false;
BEGIN
  IF p_quotation_id IS NULL
     OR p_target_status IS NULL THEN
    RAISE EXCEPTION
      'transition_quotation: quotation_id and target_status are required'
      USING ERRCODE = '22023';
  END IF;

  SELECT q.*
  INTO v_quote
  FROM public.quotations q
  WHERE q.id = p_quotation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'transition_quotation: quotation not found'
      USING ERRCODE = '22023';
  END IF;

  v_actor :=
    public.current_organization_member(
      v_quote.organization_id
    );

  IF v_actor IS NULL THEN
    RAISE EXCEPTION
      'transition_quotation: active organization membership required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.has_permission(
    v_quote.organization_id,
    'quote.write',
    v_quote.branch_id
  ) THEN
    RAISE EXCEPTION
      'transition_quotation: quote.write permission required'
      USING ERRCODE = '42501';
  END IF;

  IF p_target_status = 'accepted' THEN
    RAISE EXCEPTION
      'transition_quotation: accepted status must use accept_quotation'
      USING ERRCODE = '22023';
  END IF;

  v_old_status := v_quote.status;

  -- ---------------------------------------------------------------
  -- draft -> ready
  -- ---------------------------------------------------------------
  IF v_quote.status = 'draft'
     AND p_target_status = 'ready' THEN

    UPDATE public.quotations
    SET
      status = 'ready',
      ready_at = now(),
      updated_by = v_actor
    WHERE organization_id =
          v_quote.organization_id
      AND id =
          v_quote.id
    RETURNING *
    INTO v_quote;

  -- ---------------------------------------------------------------
  -- ready -> draft
  -- ---------------------------------------------------------------
  ELSIF v_quote.status = 'ready'
        AND p_target_status = 'draft' THEN

    UPDATE public.quotations
    SET
      status = 'draft',
      ready_at = NULL,
      updated_by = v_actor
    WHERE organization_id =
          v_quote.organization_id
      AND id =
          v_quote.id
    RETURNING *
    INTO v_quote;

  -- ---------------------------------------------------------------
  -- ready -> sent
  --
  -- If this is a revision of a still-sent quotation, the prior quote
  -- is superseded atomically when the replacement is actually sent.
  -- Merely creating a draft revision does not invalidate the old quote.
  -- ---------------------------------------------------------------
  ELSIF v_quote.status = 'ready'
        AND p_target_status = 'sent' THEN

    IF v_quote.expires_at IS NOT NULL
       AND v_quote.expires_at <= now() THEN
      RAISE EXCEPTION
        'transition_quotation: cannot send a quotation that has already expired'
        USING ERRCODE = '22023';
    END IF;

    IF v_quote.supersedes_quotation_id IS NOT NULL THEN
      SELECT q.*
      INTO v_prior_quote
      FROM public.quotations q
      WHERE q.organization_id =
            v_quote.organization_id
        AND q.id =
            v_quote.supersedes_quotation_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION
          'transition_quotation: superseded quotation lineage is missing'
          USING ERRCODE = '22023';
      END IF;

      IF v_prior_quote.status = 'sent' THEN
        UPDATE public.quotations
        SET
          status = 'superseded',
          superseded_at = now(),
          updated_by = v_actor
        WHERE organization_id =
              v_prior_quote.organization_id
          AND id =
              v_prior_quote.id
        RETURNING *
        INTO v_prior_quote;

        v_prior_was_superseded := true;

      ELSIF v_prior_quote.status NOT IN (
        'declined',
        'expired',
        'superseded'
      ) THEN
        RAISE EXCEPTION
          'transition_quotation: prior quotation is not eligible to be superseded'
          USING ERRCODE = '22023';
      END IF;
    END IF;

    UPDATE public.quotations
    SET
      status = 'sent',
      sent_at = now(),
      updated_by = v_actor
    WHERE organization_id =
          v_quote.organization_id
      AND id =
          v_quote.id
    RETURNING *
    INTO v_quote;

  -- ---------------------------------------------------------------
  -- sent -> declined
  -- ---------------------------------------------------------------
  ELSIF v_quote.status = 'sent'
        AND p_target_status = 'declined' THEN

    UPDATE public.quotations
    SET
      status = 'declined',
      declined_at = now(),
      updated_by = v_actor
    WHERE organization_id =
          v_quote.organization_id
      AND id =
          v_quote.id
    RETURNING *
    INTO v_quote;

  -- ---------------------------------------------------------------
  -- sent -> expired
  -- ---------------------------------------------------------------
  ELSIF v_quote.status = 'sent'
        AND p_target_status = 'expired' THEN

    IF v_quote.expires_at IS NULL
       OR v_quote.expires_at > now() THEN
      RAISE EXCEPTION
        'transition_quotation: quotation has not reached its expiry time'
        USING ERRCODE = '22023';
    END IF;

    UPDATE public.quotations
    SET
      status = 'expired',
      expired_at = now(),
      updated_by = v_actor
    WHERE organization_id =
          v_quote.organization_id
      AND id =
          v_quote.id
    RETURNING *
    INTO v_quote;

  -- ---------------------------------------------------------------
  -- sent -> superseded
  -- ---------------------------------------------------------------
  ELSIF v_quote.status = 'sent'
        AND p_target_status = 'superseded' THEN

    UPDATE public.quotations
    SET
      status = 'superseded',
      superseded_at = now(),
      updated_by = v_actor
    WHERE organization_id =
          v_quote.organization_id
      AND id =
          v_quote.id
    RETURNING *
    INTO v_quote;

  ELSE
    RAISE EXCEPTION
      'transition_quotation: invalid transition from % to %',
      v_quote.status,
      p_target_status
      USING ERRCODE = '22023';
  END IF;

  -- Audit the prior quotation if sending this revision invalidated it.
  IF v_prior_was_superseded THEN
    PERFORM public.append_audit_event(
      v_prior_quote.organization_id,
      v_prior_quote.branch_id,
      'quote.status_changed',
      'quotation',
      v_prior_quote.id,
      true,
      jsonb_build_object(
        'status',
          'sent'
      ),
      jsonb_build_object(
        'status',
          'superseded'
      ),
      jsonb_build_object(
        'superseded_by_quotation_id',
          v_quote.id
      ),
      'commercial',
      NULL
    );
  END IF;

  PERFORM public.append_audit_event(
    v_quote.organization_id,
    v_quote.branch_id,
    'quote.status_changed',
    'quotation',
    v_quote.id,
    true,
    jsonb_build_object(
      'status',
        v_old_status
    ),
    jsonb_build_object(
      'status',
        v_quote.status
    ),
    jsonb_build_object(
      'supersedes_prior_quote',
        v_quote.supersedes_quotation_id IS NOT NULL
    ),
    'commercial',
    NULL
  );

  RETURN v_quote;
END
$$;

-- ---------------------------------------------------------------------
-- Section C1 assertions
-- ---------------------------------------------------------------------

DO $s8q_section_c1_assertions$
BEGIN
  IF to_regprocedure(
       'public.set_quotation_discount(uuid,integer)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section C1 failed: discount RPC missing';
  END IF;

  IF to_regprocedure(
       'public.transition_quotation(uuid,public.quotation_status)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation Section C1 failed: lifecycle RPC missing';
  END IF;
END
$s8q_section_c1_assertions$;

-- SLICE_2_SECTION_C1_END

-- =====================================================================
-- Section C2
-- RLS + least privilege + function ACL + final quotation gates
-- =====================================================================

ALTER TABLE public.quotations
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotations
  FORCE ROW LEVEL SECURITY;

ALTER TABLE public.quotation_line_items
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotation_line_items
  FORCE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- Authenticated quotation read access
--
-- finance.read can inspect commercial records.
-- quote.write can author and therefore inspect quotations.
-- Mutation remains RPC-only.
-- ---------------------------------------------------------------------

CREATE POLICY quotations_staff_read
ON public.quotations
FOR SELECT
TO authenticated
USING (
  public.has_permission(
    organization_id,
    'finance.read',
    branch_id
  )
  OR
  public.has_permission(
    organization_id,
    'quote.write',
    branch_id
  )
);

CREATE POLICY quotation_line_items_staff_read
ON public.quotation_line_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.quotations q
    WHERE q.organization_id =
          quotation_line_items.organization_id
      AND q.id =
          quotation_line_items.quotation_id
      AND (
        public.has_permission(
          q.organization_id,
          'finance.read',
          q.branch_id
        )
        OR
        public.has_permission(
          q.organization_id,
          'quote.write',
          q.branch_id
        )
      )
  )
);

-- ---------------------------------------------------------------------
-- Table privileges
-- ---------------------------------------------------------------------

REVOKE ALL PRIVILEGES
ON TABLE
  public.quotations,
  public.quotation_line_items
FROM PUBLIC, anon, authenticated, service_role;

GRANT SELECT
ON TABLE
  public.quotations,
  public.quotation_line_items
TO authenticated;

GRANT ALL PRIVILEGES
ON TABLE
  public.quotations,
  public.quotation_line_items
TO service_role;

-- ---------------------------------------------------------------------
-- Public commercial RPC ACL
--
-- Normal application path:
-- authenticated bearer -> SECURITY DEFINER RPC -> permission check -> RLS
--
-- No quotation mutation RPC is exposed to anon.
-- ---------------------------------------------------------------------

REVOKE ALL
ON FUNCTION public.create_quotation(
  uuid,
  uuid,
  uuid,
  uuid,
  timestamptz,
  uuid
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.add_quotation_package_line(
  uuid,
  uuid,
  integer
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.add_quotation_addon_line(
  uuid,
  uuid,
  integer,
  integer
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.add_quotation_custom_line(
  uuid,
  text,
  text,
  integer,
  integer
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.remove_quotation_line(uuid)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.set_quotation_discount(
  uuid,
  integer
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.transition_quotation(
  uuid,
  public.quotation_status
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.create_quotation(
  uuid,
  uuid,
  uuid,
  uuid,
  timestamptz,
  uuid
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.add_quotation_package_line(
  uuid,
  uuid,
  integer
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.add_quotation_addon_line(
  uuid,
  uuid,
  integer,
  integer
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.add_quotation_custom_line(
  uuid,
  text,
  text,
  integer,
  integer
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.remove_quotation_line(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.set_quotation_discount(
  uuid,
  integer
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.transition_quotation(
  uuid,
  public.quotation_status
)
TO authenticated;

-- ---------------------------------------------------------------------
-- Internal helper hardening
-- ---------------------------------------------------------------------

REVOKE ALL
ON FUNCTION public.lsh_commercial_package_version_immutable_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_commercial_package_inclusion_immutable_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_commercial_addon_version_immutable_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_quotation_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_quotation_line_guard()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_refresh_quotation_totals(
  uuid,
  uuid
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.lsh_quotation_line_totals_trigger()
FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- Final Slice 2 migration gates
-- ---------------------------------------------------------------------

DO $s8q_final_assertions$
DECLARE
  v_count integer;
  v_fn regprocedure;
BEGIN
  -- Tables.
  IF to_regclass('public.quotations') IS NULL
     OR to_regclass('public.quotation_line_items') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: quotation tables missing';
  END IF;

  -- Canonical types.
  IF to_regtype('public.quotation_status') IS NULL
     OR to_regtype('public.quotation_line_type') IS NULL
     OR to_regtype('public.quotation_pricing_source') IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: quotation types missing';
  END IF;

  -- RLS + FORCE RLS.
  SELECT count(*)
  INTO v_count
  FROM pg_class c
  JOIN pg_namespace n
    ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'quotations',
      'quotation_line_items'
    )
    AND c.relrowsecurity
    AND c.relforcerowsecurity;

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: quotation RLS hardening incomplete';
  END IF;

  -- Exactly the two intended authenticated SELECT policies.
  SELECT count(*)
  INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND (
      (
        tablename = 'quotations'
        AND policyname = 'quotations_staff_read'
      )
      OR
      (
        tablename = 'quotation_line_items'
        AND policyname =
            'quotation_line_items_staff_read'
      )
    );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: expected 2 quotation read policies, found %',
      v_count;
  END IF;

  -- Authenticated users may read but may never mutate the tables directly.
  IF NOT has_table_privilege(
       'authenticated',
       'public.quotations',
       'SELECT'
     )
     OR NOT has_table_privilege(
       'authenticated',
       'public.quotation_line_items',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: authenticated SELECT privilege missing';
  END IF;

  IF has_table_privilege(
       'authenticated',
       'public.quotations',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.quotations',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.quotations',
       'DELETE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.quotation_line_items',
       'INSERT'
     )
     OR has_table_privilege(
       'authenticated',
       'public.quotation_line_items',
       'UPDATE'
     )
     OR has_table_privilege(
       'authenticated',
       'public.quotation_line_items',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: authenticated direct-write privilege detected';
  END IF;

  IF has_table_privilege(
       'anon',
       'public.quotations',
       'SELECT'
     )
     OR has_table_privilege(
       'anon',
       'public.quotation_line_items',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: anon quotation access detected';
  END IF;

  -- Required RPCs.
  IF to_regprocedure(
       'public.create_quotation(uuid,uuid,uuid,uuid,timestamptz,uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.add_quotation_package_line(uuid,uuid,integer)'
     ) IS NULL
     OR to_regprocedure(
       'public.add_quotation_addon_line(uuid,uuid,integer,integer)'
     ) IS NULL
     OR to_regprocedure(
       'public.add_quotation_custom_line(uuid,text,text,integer,integer)'
     ) IS NULL
     OR to_regprocedure(
       'public.remove_quotation_line(uuid)'
     ) IS NULL
     OR to_regprocedure(
       'public.set_quotation_discount(uuid,integer)'
     ) IS NULL
     OR to_regprocedure(
       'public.transition_quotation(uuid,public.quotation_status)'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: one or more quotation RPCs missing';
  END IF;

  -- Authenticated can execute controlled RPCs.
  v_fn :=
    to_regprocedure(
      'public.create_quotation(uuid,uuid,uuid,uuid,timestamptz,uuid)'
    );

  IF NOT has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: authenticated create_quotation EXECUTE missing';
  END IF;

  -- Anonymous access must remain closed.
  IF has_function_privilege(
       'anon',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: anon create_quotation EXECUTE detected';
  END IF;

  -- Internal totals helper must not be callable by the browser role.
  v_fn :=
    to_regprocedure(
      'public.lsh_refresh_quotation_totals(uuid,uuid)'
    );

  IF has_function_privilege(
       'authenticated',
       v_fn::oid,
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: internal totals helper exposed';
  END IF;

  -- Approved source-document offer pricing remains non-executable.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid =
          'public.quotation_line_items'::regclass
      AND c.conname =
          'quotation_line_items_approved_offer_not_executable_chk'
  ) THEN
    RAISE EXCEPTION
      'Sprint 8 quotation final gate failed: approved-offer execution guard missing';
  END IF;
END
$s8q_final_assertions$;

-- SLICE_2_SECTION_C2_END





-- SLICE_2_END
