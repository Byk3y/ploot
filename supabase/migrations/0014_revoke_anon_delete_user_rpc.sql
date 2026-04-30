-- Account deletion is intentionally callable by signed-in app users only.
-- Anonymous callers fail inside the function, but they do not need EXECUTE.

revoke execute on function public.delete_user() from anon;

