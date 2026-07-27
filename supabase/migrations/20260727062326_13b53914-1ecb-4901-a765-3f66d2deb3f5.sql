CREATE TABLE public.studio_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  full_name text,
  roles public.app_role[] NOT NULL DEFAULT '{}',
  token text NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(24), 'hex'),
  status text NOT NULL DEFAULT 'pending',
  invited_by uuid,
  accepted_at timestamptz,
  accepted_by uuid,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX studio_invites_pending_email_idx
  ON public.studio_invites (lower(email)) WHERE status = 'pending';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.studio_invites TO authenticated;
GRANT ALL ON public.studio_invites TO service_role;

ALTER TABLE public.studio_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Founders manage studio invites"
  ON public.studio_invites FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'founder'))
  WITH CHECK (public.has_role(auth.uid(), 'founder'));

CREATE TRIGGER studio_invites_touch_updated_at
  BEFORE UPDATE ON public.studio_invites
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();