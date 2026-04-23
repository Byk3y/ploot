-- 0004_enable_realtime
-- Let the iOS client subscribe to live row changes on its own rows.
--
-- 1. Add the three tables to the realtime publication so WAL events for
--    them get broadcast to connected channels.
-- 2. Set REPLICA IDENTITY FULL so UPDATE and DELETE payloads carry the
--    complete row. The SDK default (REPLICA IDENTITY DEFAULT) only
--    includes primary keys on updates, which would force an extra roundtrip
--    per event. Our merge logic is last-write-wins on updated_at and
--    needs the whole row.

alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.subtasks;
alter publication supabase_realtime add table public.projects;

alter table public.tasks replica identity full;
alter table public.subtasks replica identity full;
alter table public.projects replica identity full;
