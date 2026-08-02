-- New accounts (created via create-employee) must set their own password
-- before using the app instead of continuing to use the temp password HR
-- generated for them. Existing accounts already use real, intentionally
-- chosen passwords and must NOT be gated retroactively.
alter table public.profiles
  add column must_change_password boolean not null default true;

-- The ADD COLUMN above applies the "true" default to every existing row
-- too (Postgres backfills defaults on ADD COLUMN) - this UPDATE is what
-- actually protects already-existing accounts from being gated.
update public.profiles set must_change_password = false;
