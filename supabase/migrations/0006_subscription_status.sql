-- 0006_subscription_status
-- Server-side cache of each user's current subscription state. The iOS
-- client treats StoreKit's currentEntitlements as source of truth; this
-- table exists so future phases can (a) query across devices without a
-- StoreKit roundtrip, and (b) receive RevenueCat / Apple Server
-- Notifications v2 webhooks when we add server-side receipt validation.
--
-- Client never writes to this table — it's populated by a trusted
-- webhook (edge function, later phase). The RLS policy allows users to
-- read their own row only.

create table public.subscription_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  product_id text not null,
  status text not null
    check (status in ('trialing','active','expired','cancelled','grace','on_hold')),
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  rc_app_user_id text,
  updated_at timestamptz not null default now()
);

alter table public.subscription_status enable row level security;

create policy "subscription_status_select_own"
  on public.subscription_status
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- No insert / update / delete policies: only the service_role (used by
-- the webhook edge function) can write, which bypasses RLS entirely.

create index subscription_status_updated_at_idx
  on public.subscription_status(updated_at desc);
