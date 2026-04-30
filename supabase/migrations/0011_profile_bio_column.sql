-- 0011_profile_bio_column
-- Adds a free-text bio column to public.profiles.
-- Used by the AI breakdown edge function to personalize task generation.
-- Nullable so existing rows aren't rejected.

alter table public.profiles
  add column bio text;
