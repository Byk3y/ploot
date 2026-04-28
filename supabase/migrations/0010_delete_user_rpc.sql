-- 0010_delete_user_rpc.sql
--
-- In-app account deletion required by App Store Guideline 5.1.1(v).
-- The iOS app calls `rpc('delete_user')` from `SessionManager.deleteAccount()`.
--
-- The function runs as SECURITY DEFINER so it can drop the row in
-- `auth.users` even though the calling user only has SELECT/INSERT/etc
-- on `public.*`. Once `auth.users` is gone, every FK-cascading public
-- row (tasks, projects, profiles, breakdown_usage, subscriptions) is
-- removed transactionally.
--
-- Authentication: we read `auth.uid()` inside the function so it's
-- impossible to delete another user's account by passing a different
-- id. Anonymous callers (uid = null) get a no-op error.

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = uid;
end;
$$;

-- Lock down execution: any authenticated user can delete *their own*
-- account; anon callers can't.
revoke execute on function public.delete_user() from public;
grant execute on function public.delete_user() to authenticated;
