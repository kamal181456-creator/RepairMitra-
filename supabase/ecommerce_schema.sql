-- RepairMitra real e-commerce schema
-- Run once in Supabase SQL Editor before using Shop/Store Admin.
begin;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand text,
  model text,
  sku text unique,
  category text not null,
  description text,
  image_url text,
  price numeric(12,2) not null check(price>=0),
  purchase_price numeric(12,2) not null default 0 check(purchase_price>=0),
  stock_quantity integer not null default 0 check(stock_quantity>=0),
  low_stock_limit integer not null default 5 check(low_stock_limit>=0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.products add column if not exists brand text;
alter table public.products add column if not exists model text;
alter table public.products add column if not exists sku text;
alter table public.products add column if not exists description text;
alter table public.products add column if not exists image_url text;
alter table public.products add column if not exists price numeric(12,2) default 0;
alter table public.products add column if not exists purchase_price numeric(12,2) default 0;
alter table public.products add column if not exists stock_quantity integer default 0;
alter table public.products add column if not exists low_stock_limit integer default 5;
alter table public.products add column if not exists is_active boolean default true;
alter table public.products add column if not exists created_at timestamptz default now();
alter table public.products add column if not exists updated_at timestamptz default now();
create unique index if not exists products_sku_unique on public.products(sku) where sku is not null;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete restrict,
  customer_name text not null,
  phone text not null,
  address text not null,
  city text not null,
  pincode text not null,
  payment_method text not null default 'Cash on Delivery',
  payment_status text not null default 'pending',
  status text not null default 'Pending',
  total_amount numeric(12,2) not null check(total_amount>=0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null,
  quantity integer not null check(quantity>0),
  unit_price numeric(12,2) not null check(unit_price>=0),
  total_price numeric(12,2) not null check(total_price>=0)
);
create index if not exists idx_orders_customer on public.orders(customer_id,created_at desc);
create index if not exists idx_orders_status on public.orders(status);
create index if not exists idx_order_items_order on public.order_items(order_id);

-- Storage bucket for product images. Public read is intentional; writes remain admin-only through RLS.
insert into storage.buckets(id,name,public) values('product-images','product-images',true) on conflict(id) do update set public=true;

-- Atomic checkout: verifies stock, creates order + items and decrements stock in one transaction.
create or replace function public.place_store_order(
  p_customer_id uuid,
  p_customer_name text,
  p_phone text,
  p_address text,
  p_city text,
  p_pincode text,
  p_payment_method text,
  p_items jsonb
) returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  v_order uuid;
  v_total numeric(12,2):=0;
  x jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_price numeric(12,2);
begin
  if auth.uid() is null or auth.uid()<>p_customer_id then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
  insert into public.orders(customer_id,customer_name,phone,address,city,pincode,payment_method,status,total_amount)
  values(p_customer_id,p_customer_name,p_phone,p_address,p_city,p_pincode,p_payment_method,'Pending',0)
  returning id into v_order;
  for x in select * from jsonb_array_elements(p_items) loop
    v_qty := greatest(1,(x->>'quantity')::integer);
    select * into v_product from public.products where id=(x->>'product_id')::uuid and is_active=true for update;
    if not found then raise exception 'Product not found'; end if;
    if v_product.stock_quantity < v_qty then raise exception 'Insufficient stock for %',v_product.name; end if;
    v_price:=v_product.price;
    insert into public.order_items(order_id,product_id,product_name,quantity,unit_price,total_price)
    values(v_order,v_product.id,v_product.name,v_qty,v_price,v_price*v_qty);
    update public.products set stock_quantity=stock_quantity-v_qty,updated_at=now() where id=v_product.id;
    v_total:=v_total+v_price*v_qty;
  end loop;
  update public.orders set total_amount=v_total,updated_at=now() where id=v_order;
  return v_order;
end; $$;
revoke all on function public.place_store_order(uuid,text,text,text,text,text,text,jsonb) from public;
grant execute on function public.place_store_order(uuid,text,text,text,text,text,text,jsonb) to authenticated;

alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select to anon,authenticated using(is_active=true or public.is_admin());
drop policy if exists products_admin_insert on public.products;
create policy products_admin_insert on public.products for insert to authenticated with check(public.is_admin());
drop policy if exists products_admin_update on public.products;
create policy products_admin_update on public.products for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists products_admin_delete on public.products;
create policy products_admin_delete on public.products for delete to authenticated using(public.is_admin());

drop policy if exists orders_customer_read on public.orders;
create policy orders_customer_read on public.orders for select to authenticated using(customer_id=auth.uid() or public.is_admin());
drop policy if exists orders_admin_update on public.orders;
create policy orders_admin_update on public.orders for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists order_items_customer_read on public.order_items;
create policy order_items_customer_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_items.order_id and (o.customer_id=auth.uid() or public.is_admin())));

drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read on storage.objects for select to public using(bucket_id='product-images');
drop policy if exists product_images_admin_insert on storage.objects;
create policy product_images_admin_insert on storage.objects for insert to authenticated with check(bucket_id='product-images' and public.is_admin());
drop policy if exists product_images_admin_update on storage.objects;
create policy product_images_admin_update on storage.objects for update to authenticated using(bucket_id='product-images' and public.is_admin()) with check(bucket_id='product-images' and public.is_admin());
drop policy if exists product_images_admin_delete on storage.objects;
create policy product_images_admin_delete on storage.objects for delete to authenticated using(bucket_id='product-images' and public.is_admin());

commit;