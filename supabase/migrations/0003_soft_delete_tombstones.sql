-- Add deleted_at tombstones to every synced table so cross-device delete
-- propagation works. Local clients filter out rows with deleted_at != null
-- from @Query results but still push + pull them so other devices eventually
-- reflect the deletion. Future: a GC job purges rows that have been
-- tombstoned for 30+ days.

ALTER TABLE public.tasks    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.subtasks ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Indexes so the sync layer's "give me everything updated since X" pulls
-- stay fast as users accumulate history. owner_id + updated_at covers the
-- delta-pull pattern; owner_id + deleted_at is for filtered live queries.
CREATE INDEX IF NOT EXISTS tasks_owner_updated_idx
    ON public.tasks (owner_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS tasks_owner_deleted_idx
    ON public.tasks (owner_id, deleted_at);

CREATE INDEX IF NOT EXISTS subtasks_owner_updated_idx
    ON public.subtasks (owner_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS subtasks_owner_deleted_idx
    ON public.subtasks (owner_id, deleted_at);

CREATE INDEX IF NOT EXISTS projects_owner_updated_idx
    ON public.projects (owner_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS projects_owner_deleted_idx
    ON public.projects (owner_id, deleted_at);
