-- MONIKA — migration 0005: add profiles.email
-- profiles deliberately doesn't store email (auth.users is the source of
-- truth) — but the HR employee list needs to display *other* employees'
-- emails, and there's no way to read auth.users for other users without
-- the service_role key. Denormalizing a copy into profiles solves this:
-- the app self-syncs each user's own row to their real auth email on every
-- login (see auth_controller.dart), so this column stays accurate without
-- needing an Edge Function just to read it.
--
-- Paste into Supabase SQL Editor and Run.

alter table public.profiles add column email text;

-- Backfill the two existing seed accounts so the employee list isn't
-- blank until their next login.
update public.profiles set email = 'monika.employee@gmail.com' where employee_code = 'EMP-1042';
update public.profiles set email = 'monika.hr@gmail.com' where employee_code = 'HR-0007';
