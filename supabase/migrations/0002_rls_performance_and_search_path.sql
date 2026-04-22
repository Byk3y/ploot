-- Ploot — post-advisor cleanup
--
-- Two fixes flagged by Supabase's advisor after 0001_initial_schema:
--   1. Pin the search_path on trg_touch_updated_at so role/extension
--      shenanigans can't redirect schema lookups inside the trigger.
--   2. Rewrite every RLS policy from `auth.uid() = owner_id` to
--      `(SELECT auth.uid()) = owner_id`. The subquery form lets Postgres
--      treat the auth.uid() call as an initplan constant — one lookup per
--      query instead of one per row — which is a big win on large lists.
--      See https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

-- 1. Pin search_path on the shared updated_at trigger fn.
ALTER FUNCTION public.trg_touch_updated_at() SET search_path = public, pg_temp;

-- 2. Optimized RLS policies. Drop-and-recreate across all four tables.

-- profiles
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT USING ((SELECT auth.uid()) = id);
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = id);
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING ((SELECT auth.uid()) = id) WITH CHECK ((SELECT auth.uid()) = id);

-- projects
DROP POLICY IF EXISTS "projects_select_own" ON public.projects;
CREATE POLICY "projects_select_own" ON public.projects
    FOR SELECT USING ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "projects_insert_own" ON public.projects;
CREATE POLICY "projects_insert_own" ON public.projects
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "projects_update_own" ON public.projects;
CREATE POLICY "projects_update_own" ON public.projects
    FOR UPDATE USING ((SELECT auth.uid()) = owner_id) WITH CHECK ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "projects_delete_own" ON public.projects;
CREATE POLICY "projects_delete_own" ON public.projects
    FOR DELETE USING ((SELECT auth.uid()) = owner_id);

-- tasks
DROP POLICY IF EXISTS "tasks_select_own" ON public.tasks;
CREATE POLICY "tasks_select_own" ON public.tasks
    FOR SELECT USING ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "tasks_insert_own" ON public.tasks;
CREATE POLICY "tasks_insert_own" ON public.tasks
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "tasks_update_own" ON public.tasks;
CREATE POLICY "tasks_update_own" ON public.tasks
    FOR UPDATE USING ((SELECT auth.uid()) = owner_id) WITH CHECK ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "tasks_delete_own" ON public.tasks;
CREATE POLICY "tasks_delete_own" ON public.tasks
    FOR DELETE USING ((SELECT auth.uid()) = owner_id);

-- subtasks
DROP POLICY IF EXISTS "subtasks_select_own" ON public.subtasks;
CREATE POLICY "subtasks_select_own" ON public.subtasks
    FOR SELECT USING ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "subtasks_insert_own" ON public.subtasks;
CREATE POLICY "subtasks_insert_own" ON public.subtasks
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "subtasks_update_own" ON public.subtasks;
CREATE POLICY "subtasks_update_own" ON public.subtasks
    FOR UPDATE USING ((SELECT auth.uid()) = owner_id) WITH CHECK ((SELECT auth.uid()) = owner_id);
DROP POLICY IF EXISTS "subtasks_delete_own" ON public.subtasks;
CREATE POLICY "subtasks_delete_own" ON public.subtasks
    FOR DELETE USING ((SELECT auth.uid()) = owner_id);
