-- Adds public.tasks.remind_me to mirror PlootTask.remindMe on iOS.
--
-- The Swift TaskDTO has shipped a `remind_me` property since reminders
-- landed; without this column every task upsert was rejected by PostgREST
-- with "column does not exist", and the SyncService.upsertTask catch
-- block swallowed the error. Result: zero task rows ever reached the
-- server even though projects synced fine.
--
-- Nullable so existing rows (none today, but be safe) are valid; the
-- iOS DTO sends Bool? and treats nil as "unset".

alter table public.tasks
  add column if not exists remind_me boolean;
