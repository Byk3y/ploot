-- 0008_atomic_rate_limit
-- Replaces the read-then-increment pattern on ai_breakdown_usage with a
-- single race-safe RPC. Under concurrent requests the old pattern let two
-- callers both read "count = 9", both call increment_breakdown_usage, and
-- both pass the limit check client-side — net over-count of 1.
--
-- The new check_and_increment_usage(user_id, limit) function does the
-- check and the write in one ON CONFLICT DO UPDATE WHERE clause. If the
-- row is at or over the limit, the WHERE filters the update out (no row
-- returned), and we detect the no-op by checking whether the CTE returned
-- anything. Returns (new_count, allowed) so the caller knows both the
-- current usage and whether this request was accepted.
--
-- The legacy increment_breakdown_usage RPC stays in place for backward
-- compat during the edge-function redeploy window; drop in a later
-- migration once both functions are on the new RPC.

create or replace function public.check_and_increment_usage(
  p_user_id uuid,
  p_limit int
)
returns table(new_count int, allowed boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count int;
  v_allowed boolean := false;
begin
  with upsert as (
    insert into public.ai_breakdown_usage as t (user_id, day, count)
    values (p_user_id, (now() at time zone 'utc')::date, 1)
    on conflict (user_id, day) do update
      set count = t.count + 1,
          updated_at = now()
      where t.count < p_limit
    returning count
  )
  select count into v_count from upsert;

  if v_count is not null then
    -- Insert or update fired — request is within limit.
    v_allowed := true;
  else
    -- Update WHERE filtered out (current count >= limit). Fetch the
    -- standing count so the caller can render an accurate message.
    select count into v_count from public.ai_breakdown_usage
    where user_id = p_user_id
      and day = (now() at time zone 'utc')::date;
    v_count := coalesce(v_count, 0);
    v_allowed := false;
  end if;

  return query select v_count, v_allowed;
end;
$$;

revoke all on function public.check_and_increment_usage(uuid, int) from public, anon, authenticated;
grant execute on function public.check_and_increment_usage(uuid, int) to service_role;
