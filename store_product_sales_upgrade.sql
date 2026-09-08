-- RepairMitra Product + Sales hardening
-- Run this in Supabase SQL Editor after store_setup.sql.

-- Admin product/order permissions (requires existing public.is_admin() helper).
DO $$ BEGIN
  IF to_regprocedure('public.is_admin()') IS NOT NULL THEN
    DROP POLICY IF EXISTS products_admin_all ON public.products;
    CREATE POLICY products_admin_all ON public.products
      FOR ALL TO authenticated
      USING (public.is_admin())
      WITH CHECK (public.is_admin());

    DROP POLICY IF EXISTS product_variants_admin_all ON public.product_variants;
    CREATE POLICY product_variants_admin_all ON public.product_variants
      FOR ALL TO authenticated
      USING (public.is_admin())
      WITH CHECK (public.is_admin());

    DROP POLICY IF EXISTS orders_admin_all ON public.orders;
    CREATE POLICY orders_admin_all ON public.orders
      FOR ALL TO authenticated
      USING (public.is_admin())
      WITH CHECK (public.is_admin());

    DROP POLICY IF EXISTS order_items_admin_all ON public.order_items;
    CREATE POLICY order_items_admin_all ON public.order_items
      FOR ALL TO authenticated
      USING (public.is_admin())
      WITH CHECK (public.is_admin());
  END IF;
END $$;

-- Safe admin status update. Cancellation restores stock exactly once.
CREATE OR REPLACE FUNCTION public.admin_update_store_order_status(
  p_order_id uuid,
  p_status text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  old_status text;
  i record;
BEGIN
  IF to_regprocedure('public.is_admin()') IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  SELECT status INTO old_status FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF old_status IS NULL THEN RAISE EXCEPTION 'Order not found'; END IF;

  IF p_status='Cancelled' AND old_status<>'Cancelled' THEN
    FOR i IN SELECT product_id, quantity FROM public.order_items WHERE order_id=p_order_id LOOP
      UPDATE public.products
      SET stock_quantity=stock_quantity+i.quantity, updated_at=now()
      WHERE id=i.product_id;
    END LOOP;
  END IF;

  UPDATE public.orders SET status=p_status, updated_at=now() WHERE id=p_order_id;
  RETURN true;
END; $$;

REVOKE ALL ON FUNCTION public.admin_update_store_order_status(uuid,text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_update_store_order_status(uuid,text) TO authenticated;
