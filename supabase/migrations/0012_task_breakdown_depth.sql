-- Track how many times a project task has been split with "Make smaller".
-- Existing rows are null and treated as depth 0 by the iOS client.
-- Children created from a focused breakdown get parent depth + 1.

alter table public.tasks
  add column if not exists breakdown_depth int
    check (breakdown_depth is null or breakdown_depth >= 0);

