-- 0007_ai_breakdown_usage
-- Per-user, per-UTC-day counter for the AI breakdown edge function.
-- Incremented atomically on each successful call so we can enforce a
-- daily cap (free vs subscribed tiers) without adding a Redis vendor.

create table if not exists public.ai_breakdown_usage (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  day        date        not null default (now() at time zone 'utc')::date,
  count      int         not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

comment on table public.ai_breakdown_usage is
  'Per-user daily call counter for the breakdown edge function. One row per (user, UTC day). Incremented via INSERT ... ON CONFLICT DO UPDATE ... RETURNING count for race-safe atomic increment.';

create index if not exists ai_breakdown_usage_user_day_desc_idx
  on public.ai_breakdown_usage (user_id, day desc);

alter table public.ai_breakdown_usage enable row level security;

-- User can read their own usage row (e.g. to display "7 of 10 used today").
-- Writes go through the edge function using the service role key and
-- therefore bypass RLS; no user-facing INSERT/UPDATE/DELETE policies.
create policy ai_breakdown_usage_select_own
  on public.ai_breakdown_usage
  for select
  using ((select auth.uid()) = user_id);

-- Atomic per-user daily increment. Returns the new count so the caller can
-- decide whether the user is over quota. Race-safe via ON CONFLICT.
-- SECURITY DEFINER so the edge function can call it without a direct table
-- grant; search_path is pinned to avoid the classic hijack via schema
-- shadowing.
create or replace function public.increment_breakdown_usage(p_user_id uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count int;
begin
  insert into public.ai_breakdown_usage (user_id, day, count)
  values (p_user_id, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, day)
  do update set
    count = public.ai_breakdown_usage.count + 1,
    updated_at = now()
  returning count into v_count;
  return v_count;
end;
$$;

revoke all on function public.increment_breakdown_usage(uuid) from public, anon, authenticated;
grant execute on function public.increment_breakdown_usage(uuid) to service_role;
