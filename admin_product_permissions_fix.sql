-- RepairMitra: robust Product Management RLS fix
-- This avoids profiles-table RLS recursion by using a SECURITY DEFINER helper.

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.repairmitra_is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'admin'
      AND COALESCE(is_active, true) = true
  );
$$;

REVOKE ALL ON FUNCTION public.repairmitra_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.repairmitra_is_admin() TO authenticated;

DROP POLICY IF EXISTS products_admin_all ON public.products;
CREATE POLICY products_admin_all
ON public.products
FOR ALL
TO authenticated
USING (public.repairmitra_is_admin())
WITH CHECK (public.repairmitra_is_admin());

DROP POLICY IF EXISTS products_public_active_read ON public.products;
CREATE POLICY products_public_active_read
ON public.products
FOR SELECT
TO anon, authenticated
USING (is_active = true);

-- Ensure normal authenticated admins can read/write the table through RLS.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.products TO authenticated;
GRANT SELECT ON public.products TO anon;
