-- Fix: allow authenticated admins to create/update/delete store products.
-- Run once in Supabase SQL Editor.

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS products_admin_all ON public.products;
CREATE POLICY products_admin_all
ON public.products
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
      AND COALESCE(p.is_active, true) = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
      AND COALESCE(p.is_active, true) = true
  )
);

-- Keep public shop able to see active products.
DROP POLICY IF EXISTS products_public_active_read ON public.products;
CREATE POLICY products_public_active_read
ON public.products
FOR SELECT
TO anon, authenticated
USING (is_active = true);
