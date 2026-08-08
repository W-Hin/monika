-- Demo data only — NOT a schema migration. Run manually in the Supabase
-- SQL Editor whenever you want multi-year PE History to test with.
-- Backfills a 2024 and 2025 Performance Evaluation for every existing
-- profile. Safe to re-run: upserts on (user_id, year), so it never
-- duplicates rows.
--
-- Notification triggers are disabled for the duration of this script —
-- these are historical backfill rows, not "just happened" events, so
-- everyone getting a flood of 2024/2025 PE notifications at once would
-- just be confusing test noise.
alter table public.performance_evaluations disable trigger trg_notify_pe_evaluated;

do $$
declare
  emp record;
  yr int;
  t1 numeric;
  t2 numeric;
  t3 numeric;
  total numeric;
  eval_id bigint;
begin
  for emp in select id from public.profiles loop
    foreach yr in array array[2024, 2025] loop
      -- Randomized but plausible scores per category, weighted 40/30/30.
      t1 := 60 + floor(random() * 35); -- Technical 60-94
      t2 := 55 + floor(random() * 40); -- Behavioural 55-94
      t3 := 55 + floor(random() * 40); -- Leadership 55-94
      total := round((t1 * 0.4 + t2 * 0.3 + t3 * 0.3)::numeric, 2);

      insert into public.performance_evaluations (user_id, template_id, year, comments, weighted_total)
      values (emp.id, null, yr, 'Auto-generated historical record for testing PE history.', total)
      on conflict (user_id, year) do update set weighted_total = excluded.weighted_total, comments = excluded.comments
      returning id into eval_id;

      delete from public.performance_evaluation_scores where evaluation_id = eval_id;
      insert into public.performance_evaluation_scores (evaluation_id, kpi_name, weightage, score, category)
      values
        (eval_id, 'Job Knowledge & Technical Skill', 40, t1, 'Technical'),
        (eval_id, 'Teamwork & Communication', 30, t2, 'Behavioural'),
        (eval_id, 'Leadership & Initiative', 30, t3, 'Leadership');
    end loop;
  end loop;
end $$;

alter table public.performance_evaluations enable trigger trg_notify_pe_evaluated;
