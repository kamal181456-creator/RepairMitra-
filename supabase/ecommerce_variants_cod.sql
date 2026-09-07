-- RepairMitra: COD checkout + footwear size variants
-- Run this file in Supabase SQL Editor after ecommerce_schema.sql.

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  variant_name text not null,
  variant_value text not null,
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id, variant_name, variant_value)
);

create index if not exists product_variants_product_idx on public.product_variants(product_id);

alter table public.order_items add column if not exists variant_id uuid references public.product_variants(id) on delete set null;

alter table public.orders add column if not exists payment_method text default 'Cash on Delivery';
alter table public.orders add column if not exists payment_status text default 'pending';

alter table public.product_variants enable row level security;

drop policy if exists "variants public read" on public.product_variants;
create policy "variants public read" on public.product_variants for select using (true);

drop policy if exists "variants admin write" on public.product_variants;
create policy "variants admin write" on public.product_variants for all using (public.is_admin()) with check (public.is_admin());

-- Replace checkout with an atomic function supporting size variants and COD only.
create or replace function public.place_store_order(
  p_customer_name text,
  p_phone text,
  p_address text,
  p_city text,
  p_pincode text,
  p_items jsonb
) returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  v_user uuid := auth.uid();
  v_order uuid;
  v_item jsonb;
  v_product uuid;
  v_variant uuid;
  v_qty integer;
  v_price numeric;
  v_total numeric := 0;
  v_stock integer;
  v_active boolean;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if coalesce(jsonb_array_length(p_items),0)=0 then raise exception 'Cart is empty'; end if;

  insert into orders(customer_id,customer_name,phone,address,city,pincode,payment_method,payment_status,status,total_amount)
  values(v_user,p_customer_name,p_phone,p_address,p_city,p_pincode,'Cash on Delivery','pending','Pending',0)
  returning id into v_order;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_product := (v_item->>'product_id')::uuid;
    v_variant := nullif(v_item->>'variant_id','')::uuid;
    v_qty := greatest(1,(v_item->>'quantity')::integer);

    select price, stock_quantity, is_active into v_price,v_stock,v_active
    from products where id=v_product for update;
    if not found or not v_active then raise exception 'Product unavailable'; end if;

    if v_variant is not null then
      select stock_quantity into v_stock from product_variants where id=v_variant and product_id=v_product for update;
      if not found then raise exception 'Selected size unavailable'; end if;
    end if;
    if v_stock < v_qty then raise exception 'Insufficient stock'; end if;

    insert into order_items(order_id,product_id,variant_id,quantity,unit_price,total_price)
    values(v_order,v_product,v_variant,v_qty,v_price,v_qty*v_price);
    v_total := v_total + v_qty*v_price;

    if v_variant is not null then
      update product_variants set stock_quantity=stock_quantity-v_qty,updated_at=now() where id=v_variant;
    else
      update products set stock_quantity=stock_quantity-v_qty,updated_at=now() where id=v_product;
    end if;
  end loop;

  update orders set total_amount=v_total where id=v_order;
  return v_order;
exception when others then
  raise;
end;
$$;

revoke all on function public.place_store_order(text,text,text,text,text,jsonb) from public;
grant execute on function public.place_store_order(text,text,text,text,text,jsonb) to authenticated;

-- Admin cancellation restores the exact reserved stock once.
create or replace function public.cancel_store_order(p_order_id uuid) returns boolean
language plpgsql security definer set search_path=public
as $$
declare r record; s text;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  select status into s from orders where id=p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if s in ('Cancelled','Delivered') then return false; end if;
  for r in select product_id,variant_id,quantity from order_items where order_id=p_order_id loop
    if r.variant_id is not null then
      update product_variants set stock_quantity=stock_quantity+r.quantity,updated_at=now() where id=r.variant_id;
    else
      update products set stock_quantity=stock_quantity+r.quantity,updated_at=now() where id=r.product_id;
    end if;
  end loop;
  update orders set status='Cancelled',payment_status='cancelled' where id=p_order_id;
  return true;
end;
$$;
revoke all on function public.cancel_store_order(uuid) from public;
grant execute on function public.cancel_store_order(uuid) to authenticated;
