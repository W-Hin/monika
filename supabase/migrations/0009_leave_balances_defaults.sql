-- Wiring the Leave module for real: every profile needs a leave_balances
-- row for the current year before the Leave screens have anything to show.
-- create-employee's Edge Function is updated (separately) to insert one
-- for every NEW account going forward - this backfills everyone who
-- already existed before that change, using the same default entitlement
-- (14 annual, 14 medical, 3 emergency) already used as the fallback in
-- dummy_data.dart's crash-fix orElse clause.
--
-- Idempotent - safe to re-run, only inserts rows that don't already exist
-- for the current year.
insert into public.leave_balances (user_id, year, annual_total, annual_used, medical_total, medical_used, emergency_total, emergency_used)
select p.id, extract(year from now())::smallint, 14, 0, 14, 0, 3, 0
from public.profiles p
where not exists (
  select 1 from public.leave_balances lb
  where lb.user_id = p.id and lb.year = extract(year from now())::smallint
);
