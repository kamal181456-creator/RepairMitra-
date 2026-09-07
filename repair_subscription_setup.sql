-- RepairMitra: Repair Management + Vendor Subscription setup
-- Run this entire file once in Supabase SQL Editor.

create extension if not exists pgcrypto;

-- ==============================
-- SUBSCRIPTION PLANS
-- ==============================
create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  price numeric(10,2) not null default 0 check (price >= 0),
  duration_days integer not null default 30 check (duration_days > 0),
  features jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.subscription_plans (name, price, duration_days, features)
values
  ('Free', 0, 30, '["Receive repair leads","Basic vendor profile"]'::jsonb),
  ('Basic', 299, 30, '["More repair leads","Priority listing","Vendor dashboard"]'::jsonb),
  ('Pro', 599, 30, '["Unlimited repair leads","Top listing","Priority support","Advanced analytics"]'::jsonb)
on conflict (name) do nothing;

-- ==============================
-- VENDOR SUBSCRIPTIONS
-- ==============================
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null,
  plan_id uuid not null references public.subscription_plans(id),
  status text not null default 'active' check (status in ('pending','active','expired','cancelled','paused')),
  start_date timestamptz not null default now(),
  end_date timestamptz,
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded')),
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists subscriptions_vendor_id_idx on public.subscriptions(vendor_id);
create index if not exists subscriptions_status_idx on public.subscriptions(status);
create index if not exists subscriptions_end_date_idx on public.subscriptions(end_date);

create table if not exists public.subscription_payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  amount numeric(10,2) not null default 0 check (amount >= 0),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded')),
  transaction_id text,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists subscription_payments_subscription_id_idx on public.subscription_payments(subscription_id);

-- ==============================
-- REPAIR MANAGEMENT SAFETY FIELDS
-- These ALTER statements are intentionally additive.
-- ==============================
alter table if exists public.complaints
  add column if not exists status text default 'new',
  add column if not exists assigned_vendor_id uuid,
  add column if not exists quote_amount numeric(10,2),
  add column if not exists updated_at timestamptz default now();

create index if not exists complaints_status_idx on public.complaints(status);
create index if not exists complaints_assigned_vendor_idx on public.complaints(assigned_vendor_id);

-- A simple repair-order table is created only when the project does not already have one.
create table if not exists public.repair_orders (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid,
  customer_id uuid,
  vendor_id uuid,
  status text not null default 'pending' check (status in ('pending','accepted','in_progress','ready','completed','cancelled')),
  quoted_amount numeric(10,2),
  final_amount numeric(10,2),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists repair_orders_status_idx on public.repair_orders(status);
create index if not exists repair_orders_vendor_idx on public.repair_orders(vendor_id);
create index if not exists repair_orders_customer_idx on public.repair_orders(customer_id);

-- ==============================
-- AUTO updated_at TRIGGER
-- ==============================
create or replace function public.repairmitra_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_subscription_plans_updated_at on public.subscription_plans;
create trigger trg_subscription_plans_updated_at
before update on public.subscription_plans
for each row execute function public.repairmitra_set_updated_at();

drop trigger if exists trg_subscriptions_updated_at on public.subscriptions;
create trigger trg_subscriptions_updated_at
before update on public.subscriptions
for each row execute function public.repairmitra_set_updated_at();

drop trigger if exists trg_complaints_updated_at on public.complaints;
create trigger trg_complaints_updated_at
before update on public.complaints
for each row execute function public.repairmitra_set_updated_at();

drop trigger if exists trg_repair_orders_updated_at on public.repair_orders;
create trigger trg_repair_orders_updated_at
before update on public.repair_orders
for each row execute function public.repairmitra_set_updated_at();

-- ==============================
-- RLS
-- ==============================
alter table public.subscription_plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_payments enable row level security;
alter table public.repair_orders enable row level security;

-- Public users can see active plans only.
drop policy if exists subscription_plans_public_read on public.subscription_plans;
create policy subscription_plans_public_read
on public.subscription_plans for select
using (is_active = true);

-- Vendor can read its own subscriptions. Admin can read/manage all rows when the
-- existing project has an is_admin() helper.
drop policy if exists subscriptions_vendor_read on public.subscriptions;
create policy subscriptions_vendor_read
on public.subscriptions for select
using (
  vendor_id = auth.uid()
  or (to_regprocedure('public.is_admin()') is not null and public.is_admin())
);

drop policy if exists subscription_payments_vendor_read on public.subscription_payments;
create policy subscription_payments_vendor_read
on public.subscription_payments for select
using (
  exists (
    select 1 from public.subscriptions s
    where s.id = subscription_id and s.vendor_id = auth.uid()
  )
  or (to_regprocedure('public.is_admin()') is not null and public.is_admin())
);

-- Repair orders are visible to the linked customer/vendor; admin access is supported
-- when is_admin() already exists in the project.
drop policy if exists repair_orders_participant_read on public.repair_orders;
create policy repair_orders_participant_read
on public.repair_orders for select
using (
  customer_id = auth.uid()
  or vendor_id = auth.uid()
  or (to_regprocedure('public.is_admin()') is not null and public.is_admin())
);

-- NOTE: Existing complaint/vendor RLS policies are deliberately not replaced here.
-- This keeps the current RepairMitra repair workflow intact.

-- Useful view for the admin dashboard.
create or replace view public.admin_subscription_overview as
select
  s.id,
  s.vendor_id,
  sp.name as plan_name,
  sp.price as plan_price,
  s.status,
  s.payment_status,
  s.start_date,
  s.end_date,
  s.payment_reference,
  s.created_at
from public.subscriptions s
join public.subscription_plans sp on sp.id = s.plan_id;
