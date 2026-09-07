-- RepairMitra Store: Orders + Order Items + atomic stock deduction + product image storage
-- Run this file ONCE in Supabase SQL Editor for project rqnmshqrwntxilwnhqwa.

create extension if not exists pgcrypto;

alter table public.products add column if not exists is_active boolean default true;
alter table public.products add column if not exists stock_quantity integer default 0;
alter table public.products add column if not exists low_stock_limit integer default 5;
alter table public.products add column if not exists image_url text;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  phone text not null,
  address text not null,
  city text not null,
  pincode text not null,
  total_amount numeric(12,2) not null default 0,
  status text not null default 'Pending',
  payment_method text not null default 'COD',
  payment_status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.orders add column if not exists customer_name text;
alter table public.orders add column if not exists phone text;
alter table public.orders add column if not exists address text;
alter table public.orders add column if not exists city text;
alter table public.orders add column if not exists pincode text;
alter table public.orders add column if not exists total_amount numeric(12,2) default 0;
alter table public.orders add column if not exists status text default 'Pending';
alter table public.orders add column if not exists payment_method text default 'COD';
alter table public.orders add column if not exists payment_status text default 'pending';

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid null,
  product_name text,
  unit_price numeric(12,2) not null default 0,
  quantity integer not null check (quantity > 0),
  total_price numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists orders_customer_id_idx on public.orders(customer_id);
create index if not exists order_items_order_id_idx on public.order_items(order_id);

-- Public product reading; customers only see active products.
alter table public.products enable row level security;
drop policy if exists products_public_read_active on public.products;
create policy products_public_read_active on public.products for select using (coalesce(is_active,true)=true);

-- Customer can read only their own store orders/items.
alter table public.orders enable row level security;
drop policy if exists orders_customer_select on public.orders;
create policy orders_customer_select on public.orders for select using (auth.uid()=customer_id);

alter table public.order_items enable row level security;
drop policy if exists order_items_customer_select on public.order_items;
create policy order_items_customer_select on public.order_items for select using (exists(select 1 from public.orders o where o.id=order_items.order_id and o.customer_id=auth.uid()));

-- Product image bucket. If the bucket already exists, this is harmless.
insert into storage.buckets (id,name,public) values ('product-images','product-images',true) on conflict (id) do update set public=true;

drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read on storage.objects for select using (bucket_id='product-images');

-- Authenticated users may upload images; database/admin RLS remains the security boundary for product records.
drop policy if exists product_images_authenticated_insert on storage.objects;
create policy product_images_authenticated_insert on storage.objects for insert to authenticated with check (bucket_id='product-images');

drop policy if exists product_images_authenticated_update on storage.objects;
create policy product_images_authenticated_update on storage.objects for update to authenticated using (bucket_id='product-images') with check (bucket_id='product-images');

-- Atomic checkout: locks product rows, verifies stock, creates order/items and deducts stock in one transaction.
create or replace function public.place_store_order(
  p_customer_name text,
  p_phone text,
  p_address text,
  p_city text,
  p_pincode text,
  p_items jsonb
) returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user uuid := auth.uid();
  v_order uuid;
  v_total numeric(12,2) := 0;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_price numeric(12,2);
  v_variant uuid;
begin
  if v_user is null then raise exception 'Please sign in before placing an order.'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'Your cart is empty.'; end if;

  insert into public.orders(customer_id,customer_name,phone,address,city,pincode,total_amount,status,payment_method,payment_status)
  values(v_user,trim(p_customer_name),trim(p_phone),trim(p_address),trim(p_city),trim(p_pincode),0,'Pending','COD','pending')
  returning id into v_order;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := greatest(1,(v_item->>'quantity')::integer);
    v_variant := nullif(v_item->>'variant_id','')::uuid;

    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and coalesce(is_active,true)=true for update;
    if not found then raise exception 'A product in your cart is no longer available.'; end if;
    if coalesce(v_product.stock_quantity,0) < v_qty then raise exception 'Not enough stock for: %',v_product.name; end if;

    v_price := coalesce(v_product.price,0);
    v_total := v_total + (v_price*v_qty);
    insert into public.order_items(order_id,product_id,variant_id,product_name,unit_price,quantity,total_price)
    values(v_order,v_product.id,v_variant,v_product.name,v_price,v_qty,v_price*v_qty);

    update public.products set stock_quantity=coalesce(stock_quantity,0)-v_qty where id=v_product.id;
  end loop;

  update public.orders set total_amount=v_total where id=v_order;
  return v_order;
exception when others then
  raise;
end;
$$;

revoke all on function public.place_store_order(text,text,text,text,text,jsonb) from public;
grant execute on function public.place_store_order(text,text,text,text,text,jsonb) to authenticated;
