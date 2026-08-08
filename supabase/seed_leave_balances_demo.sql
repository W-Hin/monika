-- Demo data only — NOT a schema migration. Randomizes annual/medical/
-- emergency leave USED (not total entitlement) for roughly 70% of
-- employees' current-year balance, so Leave Balances doesn't show
-- everyone sitting at a suspiciously perfect 100% remaining this deep
-- into the year. Safe to re-run — recomputes each time it's run.
update public.leave_balances lb
set
  annual_used = least(lb.annual_total, floor(random() * (lb.annual_total * 0.6 + 1))::int),
  medical_used = least(lb.medical_total, floor(random() * (lb.medical_total * 0.4 + 1))::int),
  emergency_used = least(lb.emergency_total, floor(random() * (lb.emergency_total * 0.6 + 1))::int)
from public.profiles p
where lb.user_id = p.id
  and lb.year = extract(year from now())::smallint
  and random() < 0.7; -- leave ~30% of employees untouched (still full) for contrast
