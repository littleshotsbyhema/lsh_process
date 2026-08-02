CREATE OR REPLACE FUNCTION public.has_any_role(_user_id uuid, _roles app_role[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = ANY(_roles));
$$;

CREATE TABLE public.studio_meta (
  key text PRIMARY KEY,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.studio_meta TO authenticated;
GRANT ALL ON public.studio_meta TO service_role;

ALTER TABLE public.studio_meta ENABLE ROW LEVEL SECURITY;

CREATE POLICY "staff read studio_meta" ON public.studio_meta
  FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "staff write studio_meta" ON public.studio_meta
  FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "staff update studio_meta" ON public.studio_meta
  FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "founder delete studio_meta" ON public.studio_meta
  FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'founder'));

CREATE TRIGGER studio_meta_touch BEFORE UPDATE ON public.studio_meta
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Privacy & consent: writes limited to founder / coordinator / marketing
DROP POLICY IF EXISTS "staff write privacy_records" ON public.privacy_records;
DROP POLICY IF EXISTS "staff update privacy_records" ON public.privacy_records;
DROP POLICY IF EXISTS "staff delete privacy_records" ON public.privacy_records;
CREATE POLICY "privacy writers insert" ON public.privacy_records
  FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','marketing']::app_role[]));
CREATE POLICY "privacy writers update" ON public.privacy_records
  FOR UPDATE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','marketing']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','marketing']::app_role[]));
CREATE POLICY "privacy writers delete" ON public.privacy_records
  FOR DELETE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','marketing']::app_role[]));

-- Bookings: writes limited to founder / coordinator / sales / accounts
DROP POLICY IF EXISTS "staff write bookings" ON public.bookings;
DROP POLICY IF EXISTS "staff update bookings" ON public.bookings;
DROP POLICY IF EXISTS "staff delete bookings" ON public.bookings;
CREATE POLICY "booking writers insert" ON public.bookings
  FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','sales','accounts']::app_role[]));
CREATE POLICY "booking writers update" ON public.bookings
  FOR UPDATE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','sales','accounts']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','sales','accounts']::app_role[]));
CREATE POLICY "booking writers delete" ON public.bookings
  FOR DELETE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator','sales','accounts']::app_role[]));

-- Governance runs: writes limited to founder / coordinator
DROP POLICY IF EXISTS "staff write governance_runs" ON public.governance_runs;
DROP POLICY IF EXISTS "staff update governance_runs" ON public.governance_runs;
DROP POLICY IF EXISTS "staff delete governance_runs" ON public.governance_runs;
CREATE POLICY "governance writers insert" ON public.governance_runs
  FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]));
CREATE POLICY "governance writers update" ON public.governance_runs
  FOR UPDATE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]));
CREATE POLICY "governance writers delete" ON public.governance_runs
  FOR DELETE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]));

-- Alignment scores: writes limited to founder / coordinator
DROP POLICY IF EXISTS "staff write alignment_scores" ON public.alignment_scores;
DROP POLICY IF EXISTS "staff update alignment_scores" ON public.alignment_scores;
DROP POLICY IF EXISTS "staff delete alignment_scores" ON public.alignment_scores;
CREATE POLICY "alignment writers insert" ON public.alignment_scores
  FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]));
CREATE POLICY "alignment writers update" ON public.alignment_scores
  FOR UPDATE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]));
CREATE POLICY "alignment writers delete" ON public.alignment_scores
  FOR DELETE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['founder','coordinator']::app_role[]));