-- 0005_profile_onboarding_columns
-- Adds columns to public.profiles that capture the answers collected
-- during the first-run onboarding quiz. All nullable so existing rows
-- (pre-onboarding users) aren't rejected by the migration.

alter table public.profiles
  add column chronotype text
    check (chronotype in ('early','morning','afternoon','night')),
  add column daily_goal int
    check (daily_goal is null or (daily_goal between 1 and 20)),
  add column checkin_time time,
  add column reminder_style text
    check (reminder_style in ('gentle','firm','none')),
  add column primary_role text,
  add column planning_time text
    check (planning_time in ('nightBefore','morningOf','winging')),
  add column current_system text
    check (current_system in ('appleReminders','notion','postIts','nothing','multiple')),
  add column tasks_per_day int
    check (tasks_per_day is null or (tasks_per_day between 1 and 20)),
  add column uses_projects boolean,
  add column recurrence_heavy boolean,
  add column track_streak boolean default true,
  add column onboarded_at timestamptz,
  -- Catch-all for schema-light answer buckets (whatBringsYou, gettingInTheWay).
  -- Keeps us iteration-friendly without a migration per new quiz screen.
  add column onboarding_answers jsonb;
