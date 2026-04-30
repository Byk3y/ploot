-- handle_new_user() is only meant to run as the auth.users insert trigger.
-- It does not need direct RPC execution by anon or authenticated clients.

revoke execute on function public.handle_new_user() from public, anon, authenticated;

