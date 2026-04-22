-- Ploot — initial schema (Phase 4a)
-- Mirrors the SwiftData @Model layer: PlootProject, PlootTask, Subtask.
-- Adds a profiles row per auth user for app-scoped metadata.
--
-- Run this in the Supabase dashboard SQL editor. Safe to re-run: each
-- CREATE uses IF NOT EXISTS where possible; the DROP statements at the
-- top handle idempotency for the rest.
--
-- Notes on design decisions:
--   * Projects use composite PK (owner_id, id) so the "work"/"home"
--     slug semantics from SwiftData can repeat across users without
--     namespace collision.
--   * Tasks use UUID PK (gen_random_uuid()) to match SwiftData's UUID id.
--   * subtasks.owner_id is denormalized from the parent task so RLS
--     policies don't need a join every read.
--   * updated_at is bumped by a BEFORE UPDATE trigger, not by the
--     client, so last-write-wins conflict resolution works regardless
--     of whether the client sends the column.

-- ============================================================
-- 1. Shared helpers
-- ============================================================

-- Shared trigger fn: bump updated_at to now() on every UPDATE.
CREATE OR REPLACE FUNCTION public.trg_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 2. profiles
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    avatar_initials TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS profiles_touch_updated_at ON public.profiles;
CREATE TRIGGER profiles_touch_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.trg_touch_updated_at();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Auto-create a profile row when a new auth user signs up.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'display_name', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- 3. projects
-- ============================================================
-- id is the human slug ("work", "home", ...) — kept as TEXT to match
-- SwiftData. PK composite so the same slug can exist under different
-- owners without clashing.

CREATE TABLE IF NOT EXISTS public.projects (
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    tile_color TEXT NOT NULL
        CHECK (tile_color IN ('sky','forest','plum','butter','primary','inbox')),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_id, id)
);

CREATE INDEX IF NOT EXISTS projects_owner_sort_idx
    ON public.projects (owner_id, sort_order);

DROP TRIGGER IF EXISTS projects_touch_updated_at ON public.projects;
CREATE TRIGGER projects_touch_updated_at
    BEFORE UPDATE ON public.projects
    FOR EACH ROW EXECUTE FUNCTION public.trg_touch_updated_at();

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "projects_select_own" ON public.projects;
CREATE POLICY "projects_select_own" ON public.projects
    FOR SELECT USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "projects_insert_own" ON public.projects;
CREATE POLICY "projects_insert_own" ON public.projects
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "projects_update_own" ON public.projects;
CREATE POLICY "projects_update_own" ON public.projects
    FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "projects_delete_own" ON public.projects;
CREATE POLICY "projects_delete_own" ON public.projects
    FOR DELETE USING (auth.uid() = owner_id);


-- ============================================================
-- 4. tasks
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    note TEXT,
    -- Legacy free-form label; phased out once dueDate is universal client-side.
    due TEXT,
    due_date TIMESTAMPTZ,
    duration TEXT,
    project_id TEXT,
    priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('normal','medium','high','urgent')),
    tags TEXT[] NOT NULL DEFAULT '{}',
    done BOOLEAN NOT NULL DEFAULT false,
    section TEXT NOT NULL DEFAULT 'today'
        CHECK (section IN ('overdue','today','later','done')),
    overdue BOOLEAN NOT NULL DEFAULT false,
    repeats TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- If the referenced project is deleted, null out the task's project_id
    -- rather than deleting the task. Composite FK aligns with the project PK.
    FOREIGN KEY (owner_id, project_id)
        REFERENCES public.projects(owner_id, id)
        ON DELETE SET NULL
        DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX IF NOT EXISTS tasks_owner_idx           ON public.tasks (owner_id);
CREATE INDEX IF NOT EXISTS tasks_owner_section_idx   ON public.tasks (owner_id, section);
CREATE INDEX IF NOT EXISTS tasks_owner_done_idx      ON public.tasks (owner_id, done);
CREATE INDEX IF NOT EXISTS tasks_owner_due_date_idx  ON public.tasks (owner_id, due_date);
CREATE INDEX IF NOT EXISTS tasks_owner_project_idx   ON public.tasks (owner_id, project_id);
CREATE INDEX IF NOT EXISTS tasks_owner_completed_idx ON public.tasks (owner_id, completed_at DESC);

DROP TRIGGER IF EXISTS tasks_touch_updated_at ON public.tasks;
CREATE TRIGGER tasks_touch_updated_at
    BEFORE UPDATE ON public.tasks
    FOR EACH ROW EXECUTE FUNCTION public.trg_touch_updated_at();

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tasks_select_own" ON public.tasks;
CREATE POLICY "tasks_select_own" ON public.tasks
    FOR SELECT USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "tasks_insert_own" ON public.tasks;
CREATE POLICY "tasks_insert_own" ON public.tasks
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "tasks_update_own" ON public.tasks;
CREATE POLICY "tasks_update_own" ON public.tasks
    FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "tasks_delete_own" ON public.tasks;
CREATE POLICY "tasks_delete_own" ON public.tasks
    FOR DELETE USING (auth.uid() = owner_id);


-- ============================================================
-- 5. subtasks
-- ============================================================
-- owner_id is denormalized from the parent task so RLS can filter
-- without a join on every read.

CREATE TABLE IF NOT EXISTS public.subtasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    done BOOLEAN NOT NULL DEFAULT false,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS subtasks_task_idx  ON public.subtasks (task_id, sort_order);
CREATE INDEX IF NOT EXISTS subtasks_owner_idx ON public.subtasks (owner_id);

DROP TRIGGER IF EXISTS subtasks_touch_updated_at ON public.subtasks;
CREATE TRIGGER subtasks_touch_updated_at
    BEFORE UPDATE ON public.subtasks
    FOR EACH ROW EXECUTE FUNCTION public.trg_touch_updated_at();

ALTER TABLE public.subtasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subtasks_select_own" ON public.subtasks;
CREATE POLICY "subtasks_select_own" ON public.subtasks
    FOR SELECT USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "subtasks_insert_own" ON public.subtasks;
CREATE POLICY "subtasks_insert_own" ON public.subtasks
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "subtasks_update_own" ON public.subtasks;
CREATE POLICY "subtasks_update_own" ON public.subtasks
    FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "subtasks_delete_own" ON public.subtasks;
CREATE POLICY "subtasks_delete_own" ON public.subtasks
    FOR DELETE USING (auth.uid() = owner_id);


-- ============================================================
-- 6. Done
-- ============================================================
-- Sanity check: SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public' ORDER BY table_name;
-- Expected: profiles, projects, subtasks, tasks
