DROP INDEX IF EXISTS public.branches_org_code_key;
REVOKE ALL ON TABLE public.branches FROM anon, authenticated;