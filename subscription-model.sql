-- RepairMitra Subscription Model
-- Run this once in Supabase SQL Editor.

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  price numeric(10,2) not null default 0,
  duration_days integer not null default 30,
  max_repairs_per_month integer,
  max_quotes_per_month integer,
  priority_support boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.subscription_plans (name,description,price,duration_days,max_repairs_per_month,max_quotes_per_month,priority_support)
values
 ('Free','Basic vendor access',0,30,5,5,false),
 ('Basic','For small repair shops',299,30,50,50,false),
 ('Pro','For growing repair businesses',599,30,200,200,true),
 ('Premium','For high-volume repair shops',999,30,null,null,true)
on conflict (name) do update set
 description=excluded.description,
 price=excluded.price,
 duration_days=excluded.duration_days,
 max_repairs_per_month=excluded.max_repairs_per_month,
 max_quotes_per_month=excluded.max_quotes_per_month,
 priority_support=excluded.priority_support;

create table if not exists public.vendor_subscriptions (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null,
  plan_id uuid references public.subscription_plans(id) on delete restrict,
  status text not null default 'active' check (status in ('active','expired','cancelled','pending')),
  started_at timestamptz not null default now(),
  ends_at timestamptz,
  auto_renew boolean not null default false,
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.vendor_subscriptions add column if not exists auto_renew boolean not null default false;
alter table public.vendor_subscriptions add column if not exists payment_reference text;
alter table public.vendor_subscriptions add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_vendor_subscriptions_vendor on public.vendor_subscriptions(vendor_id);
create index if not exists idx_vendor_subscriptions_status on public.vendor_subscriptions(status);
create index if not exists idx_vendor_subscriptions_ends_at on public.vendor_subscriptions(ends_at);

-- Enable RLS. Admin/service policies can be added according to your existing security setup.
alter table public.subscription_plans enable row level security;
alter table public.vendor_subscriptions enable row level security;

-- Public plan catalog: active plans can be read by logged-in users.
drop policy if exists "active plans readable" on public.subscription_plans;
create policy "active plans readable" on public.subscription_plans
for select to authenticated using (is_active = true);

-- Vendors can read their own subscriptions.
drop policy if exists "vendor reads own subscriptions" on public.vendor_subscriptions;
create policy "vendor reads own subscriptions" on public.vendor_subscriptions
for select to authenticated using (vendor_id = auth.uid());
