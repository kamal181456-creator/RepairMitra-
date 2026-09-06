-- RepairMitra STEP 1
-- Marketplace repair flow:
-- Customer creates complaint -> approved vendors see it -> each vendor sends own quote
-- -> customer compares quotes -> chooses vendor -> chat/repair order -> review.
-- This script is intentionally additive: it does NOT drop existing tables or data.

begin;

-- ============================================================
-- 1) Common helper: admin check
-- ============================================================
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Existing profiles table is used by the current RepairMitra code.
-- Add only missing profile fields; do not replace the table.
alter table if exists public.profiles
  add column if not exists full_name text,
  add column if not exists phone text,
  add column if not exists is_active boolean not null default true;

-- ============================================================
-- 2) Vendor shop profile + map location
-- ============================================================
create table if not exists public.vendor_shops (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null unique references public.profiles(id) on delete cascade,
  shop_name text not null,
  owner_name text,
  phone text,
  address_line text not null,
  area text,
  city text,
  state text,
  pincode text,
  latitude double precision,
  longitude double precision,
  google_maps_url text,
  shop_photo_url text,
  services text[] not null default '{}',
  opening_hours jsonb not null default '{}'::jsonb,
  is_approved boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vendor_shops_location
  on public.vendor_shops(latitude, longitude);
create index if not exists idx_vendor_shops_active
  on public.vendor_shops(is_approved, is_active);

-- ============================================================
-- 3) Vendor quotations
-- complaint_id is text intentionally so this migration is safe
-- even if the existing complaints.id is integer/bigint/uuid.
-- ============================================================
create table if not exists public.repair_quotes (
  id uuid primary key default gen_random_uuid(),
  complaint_id text not null,
  vendor_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(12,2) not null check (amount >= 0),
  parts_amount numeric(12,2) not null default 0 check (parts_amount >= 0),
  labour_amount numeric(12,2) not null default 0 check (labour_amount >= 0),
  estimated_time text,
  note text,
  status text not null default 'sent'
    check (status in ('sent','updated','withdrawn','accepted','rejected','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (complaint_id, vendor_id)
);

create index if not exists idx_repair_quotes_complaint
  on public.repair_quotes(complaint_id);
create index if not exists idx_repair_quotes_vendor
  on public.repair_quotes(vendor_id);

-- ============================================================
-- 4) Customer's selected vendor / repair order
-- ============================================================
create table if not exists public.repair_orders (
  id uuid primary key default gen_random_uuid(),
  complaint_id text not null unique,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  vendor_id uuid not null references public.profiles(id) on delete cascade,
  quote_id uuid references public.repair_quotes(id) on delete set null,
  status text not null default 'vendor_selected'
    check (status in ('vendor_selected','contacted','repair_started','repairing','ready','completed','cancelled','disputed')),
  selected_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  final_amount numeric(12,2) check (final_amount is null or final_amount >= 0),
  customer_note text,
  vendor_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_repair_orders_customer on public.repair_orders(customer_id);
create index if not exists idx_repair_orders_vendor on public.repair_orders(vendor_id);

-- ============================================================
-- 5) Customer <-> Vendor chat
-- ============================================================
create table if not exists public.repair_messages (
  id uuid primary key default gen_random_uuid(),
  complaint_id text not null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  message text not null check (length(trim(message)) > 0),
  attachment_url text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_repair_messages_complaint on public.repair_messages(complaint_id, created_at);

-- ============================================================
-- 6) Ratings / reviews
-- ============================================================
create table if not exists public.vendor_reviews (
  id uuid primary key default gen_random_uuid(),
  complaint_id text not null,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  vendor_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  review text,
  created_at timestamptz not null default now(),
  unique (complaint_id, customer_id)
);

create index if not exists idx_vendor_reviews_vendor on public.vendor_reviews(vendor_id);

-- ============================================================
-- 7) Subscription plans
-- ============================================================
create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  price numeric(12,2) not null default 0 check (price >= 0),
  duration_days integer not null default 30 check (duration_days > 0),
  is_active boolean not null default true,
  features jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Each vendor can have one current subscription record.
create table if not exists public.vendor_subscriptions (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null unique references public.profiles(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  status text not null default 'active'
    check (status in ('active','expired','cancelled','pending')),
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  assigned_by uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Default FREE plan. Safe if it already exists.
insert into public.subscription_plans (name, description, price, duration_days, features)
values ('Free', 'Free RepairMitra vendor plan', 0, 36500, '{"type":"free"}'::jsonb)
on conflict (name) do nothing;

-- ============================================================
-- 8) Notifications
-- ============================================================
create table if not exists public.repair_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  complaint_id text,
  type text not null,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_repair_notifications_user on public.repair_notifications(user_id, created_at desc);

-- ============================================================
-- 9) Optional marketplace fields on existing complaints table
--    Do not delete/rename the existing vendor_id column because
--    the current website still uses it.
-- ============================================================
alter table if exists public.complaints
  add column if not exists marketplace_status text default 'open_for_quotes',
  add column if not exists selected_vendor_id uuid references public.profiles(id) on delete set null,
  add column if not exists selected_quote_id uuid references public.repair_quotes(id) on delete set null;

create index if not exists idx_complaints_marketplace_status
  on public.complaints(marketplace_status);
create index if not exists idx_complaints_selected_vendor
  on public.complaints(selected_vendor_id);

-- ============================================================
-- 10) RLS
-- ============================================================
alter table public.vendor_shops enable row level security;
alter table public.repair_quotes enable row level security;
alter table public.repair_orders enable row level security;
alter table public.repair_messages enable row level security;
alter table public.vendor_reviews enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.vendor_subscriptions enable row level security;
alter table public.repair_notifications enable row level security;

-- Vendor shops: approved/active shops are visible to logged-in users.
drop policy if exists vendor_shops_public_select on public.vendor_shops;
create policy vendor_shops_public_select
on public.vendor_shops for select
to authenticated
using (is_approved = true and is_active = true or vendor_id = auth.uid() or public.is_admin());

drop policy if exists vendor_shops_owner_insert on public.vendor_shops;
create policy vendor_shops_owner_insert
on public.vendor_shops for insert
to authenticated
with check (vendor_id = auth.uid() or public.is_admin());

drop policy if exists vendor_shops_owner_update on public.vendor_shops;
create policy vendor_shops_owner_update
on public.vendor_shops for update
to authenticated
using (vendor_id = auth.uid() or public.is_admin())
with check (vendor_id = auth.uid() or public.is_admin());

-- Quotes: vendors can see/manage only their own quote. Customers see
-- quotes only for complaints they own. Admin sees everything.
drop policy if exists repair_quotes_vendor_insert on public.repair_quotes;
create policy repair_quotes_vendor_insert
on public.repair_quotes for insert
to authenticated
with check (vendor_id = auth.uid() or public.is_admin());

drop policy if exists repair_quotes_select on public.repair_quotes;
create policy repair_quotes_select
on public.repair_quotes for select
to authenticated
using (
  vendor_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1 from public.complaints c
    where c.id::text = repair_quotes.complaint_id
      and (c.user_id = auth.uid() or c.customer_id = auth.uid())
  )
);

drop policy if exists repair_quotes_vendor_update on public.repair_quotes;
create policy repair_quotes_vendor_update
on public.repair_quotes for update
to authenticated
using (vendor_id = auth.uid() or public.is_admin())
with check (vendor_id = auth.uid() or public.is_admin());

drop policy if exists repair_quotes_vendor_delete on public.repair_quotes;
create policy repair_quotes_vendor_delete
on public.repair_quotes for delete
to authenticated
using (vendor_id = auth.uid() or public.is_admin());

-- Repair orders
drop policy if exists repair_orders_select on public.repair_orders;
create policy repair_orders_select
on public.repair_orders for select
to authenticated
using (customer_id = auth.uid() or vendor_id = auth.uid() or public.is_admin());

drop policy if exists repair_orders_insert on public.repair_orders;
create policy repair_orders_insert
on public.repair_orders for insert
to authenticated
with check (customer_id = auth.uid() or public.is_admin());

drop policy if exists repair_orders_update on public.repair_orders;
create policy repair_orders_update
on public.repair_orders for update
to authenticated
using (customer_id = auth.uid() or vendor_id = auth.uid() or public.is_admin())
with check (customer_id = auth.uid() or vendor_id = auth.uid() or public.is_admin());

-- Messages only between customer and selected/related vendor.
drop policy if exists repair_messages_select on public.repair_messages;
create policy repair_messages_select
on public.repair_messages for select
to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid() or public.is_admin());

drop policy if exists repair_messages_insert on public.repair_messages;
create policy repair_messages_insert
on public.repair_messages for insert
to authenticated
with check (sender_id = auth.uid());

drop policy if exists repair_messages_update on public.repair_messages;
create policy repair_messages_update
on public.repair_messages for update
to authenticated
using (receiver_id = auth.uid() or sender_id = auth.uid() or public.is_admin())
with check (receiver_id = auth.uid() or sender_id = auth.uid() or public.is_admin());

-- Reviews: customer creates their own review; everyone logged in can read reviews.
drop policy if exists vendor_reviews_select on public.vendor_reviews;
create policy vendor_reviews_select
on public.vendor_reviews for select
to authenticated
using (true);

drop policy if exists vendor_reviews_insert on public.vendor_reviews;
create policy vendor_reviews_insert
on public.vendor_reviews for insert
to authenticated
with check (customer_id = auth.uid() or public.is_admin());

drop policy if exists vendor_reviews_update on public.vendor_reviews;
create policy vendor_reviews_update
on public.vendor_reviews for update
to authenticated
using (customer_id = auth.uid() or public.is_admin())
with check (customer_id = auth.uid() or public.is_admin());

-- Subscription plans are readable by authenticated users; only admin manages them.
drop policy if exists subscription_plans_select on public.subscription_plans;
create policy subscription_plans_select
on public.subscription_plans for select
to authenticated
using (is_active = true or public.is_admin());

drop policy if exists subscription_plans_admin_insert on public.subscription_plans;
create policy subscription_plans_admin_insert
on public.subscription_plans for insert
to authenticated
with check (public.is_admin());

drop policy if exists subscription_plans_admin_update on public.subscription_plans;
create policy subscription_plans_admin_update
on public.subscription_plans for update
to authenticated
using (public.is_admin()) with check (public.is_admin());

drop policy if exists subscription_plans_admin_delete on public.subscription_plans;
create policy subscription_plans_admin_delete
on public.subscription_plans for delete
to authenticated
using (public.is_admin());

-- Vendor subscriptions: vendor can see own; admin has full control.
drop policy if exists vendor_subscriptions_select on public.vendor_subscriptions;
create policy vendor_subscriptions_select
on public.vendor_subscriptions for select
to authenticated
using (vendor_id = auth.uid() or public.is_admin());

drop policy if exists vendor_subscriptions_admin_insert on public.vendor_subscriptions;
create policy vendor_subscriptions_admin_insert
on public.vendor_subscriptions for insert
to authenticated
with check (public.is_admin());

drop policy if exists vendor_subscriptions_admin_update on public.vendor_subscriptions;
create policy vendor_subscriptions_admin_update
on public.vendor_subscriptions for update
to authenticated
using (public.is_admin()) with check (public.is_admin());

drop policy if exists vendor_subscriptions_admin_delete on public.vendor_subscriptions;
create policy vendor_subscriptions_admin_delete
on public.vendor_subscriptions for delete
to authenticated
using (public.is_admin());

-- Notifications: user sees their own; admin sees all.
drop policy if exists repair_notifications_select on public.repair_notifications;
create policy repair_notifications_select
on public.repair_notifications for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists repair_notifications_update on public.repair_notifications;
create policy repair_notifications_update
on public.repair_notifications for update
to authenticated
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists repair_notifications_admin_insert on public.repair_notifications;
create policy repair_notifications_admin_insert
on public.repair_notifications for insert
to authenticated
with check (public.is_admin());

commit;

-- IMPORTANT:
-- This migration creates the marketplace foundation but intentionally does not
-- change the existing complaints vendor assignment logic yet. The next step
-- will update the customer/vendor UI to use repair_quotes + vendor_shops and
-- then we will safely retire direct vendor assignment.