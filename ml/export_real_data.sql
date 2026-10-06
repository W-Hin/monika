-- Exports real MONIKA data in the same shape as data/synthetic_employees.csv,
-- for re-training once the system has been in use for a while.
--
-- Run in the Supabase SQL Editor (needs migration 0040), download the result
-- as CSV into ml/data/, then:
--     python train.py --data data/synthetic_employees.csv --data data/real_employees.csv
--
-- Label: the area of the most recent recommended programme the employee
-- went on to pass — i.e. a recommendation that turned out to be useful.
-- Caveats: features are the employee's values today, not at the time of
-- that recommendation, and labels only exist for employees who have
-- already completed a recommended programme, so mix with the synthetic
-- set until there are a few hundred real rows.
select
    f ->> 'tenure_months'       as tenure_months,
    f ->> 'attendance_rate'     as attendance_rate,
    f ->> 'punctuality_rate'    as punctuality_rate,
    f ->> 'risk_score'          as risk_score,
    f ->> 'pe_technical'        as pe_technical,
    f ->> 'pe_behavioural'      as pe_behavioural,
    f ->> 'pe_leadership'       as pe_leadership,
    f ->> 'trainings_completed' as trainings_completed,
    f ->> 'avg_training_score'  as avg_training_score,
    lbl.category                as label
from (
    select distinct on (e.user_id) e.user_id, p.category
    from public.training_enrollments e
    join public.training_programs p on p.id = e.program_id
    where e.is_recommended
      and e.is_completed
      and e.performance_score >= p.pass_mark
    order by e.user_id, e.completed_at desc nulls last
) lbl
cross join lateral (select public.ml_employee_features(lbl.user_id) as f) x
where f is not null;
