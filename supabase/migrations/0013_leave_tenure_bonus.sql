-- Tenure-based annual leave bonus: +1 annual leave day per full year of
-- service on top of the flat 14-day base, capped at +6 (so a 6+ year
-- veteran tops out at 20). One-time recompute for every existing
-- current-year balance based on each employee's hire_date — this app has
-- no automated year-end rollover job, so entitlements are set once at
-- balance-creation time (here, and in create-employee for new hires) and
-- adjusted manually by HR afterwards via Leave Balances if needed.
update public.leave_balances lb
set annual_total = 14 + least(
  floor(extract(year from age(now(), p.hire_date)))::int,
  6
)
from public.profiles p
where lb.user_id = p.id
  and lb.year = extract(year from now())::smallint
  and p.hire_date is not null;
