ALTER TABLE public.branches DROP CONSTRAINT IF EXISTS branches_org_code_key;
REVOKE ALL ON TABLE public.branches FROM anon, authenticated;