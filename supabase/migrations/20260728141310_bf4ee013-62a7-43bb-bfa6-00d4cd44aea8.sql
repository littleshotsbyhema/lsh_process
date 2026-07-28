-- Wave 1A, Migration A (correction): remove default-ACL grants so access is
-- explicit-only. Membership-scoped grants arrive in Migration C.
REVOKE ALL ON public.organizations FROM anon, authenticated;
REVOKE ALL ON public.organization_settings FROM anon, authenticated;
REVOKE ALL ON public.branches FROM anon, authenticated;

GRANT ALL ON public.organizations TO service_role;
GRANT ALL ON public.organization_settings TO service_role;
GRANT ALL ON public.branches TO service_role;