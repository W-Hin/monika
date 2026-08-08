-- Every KPI item was being force-categorised as "Technical" by a fragile
-- client-side keyword guess on the KPI's name (contains "Leadership" ->
-- Leadership, contains "Team"/"Communication"/"Customer" -> Behavioural,
-- else Technical) — for custom HR-authored templates this almost always
-- landed on Technical, so Behavioural/Leadership scores never fed the
-- (future) recommendation engine. Category is now an explicit column HR
-- sets per KPI item at template-creation time, snapshotted onto each score
-- row the same way weightage already is.
alter table public.kpi_template_items
    add column category text not null default 'Technical'
    check (category in ('Technical', 'Behavioural', 'Leadership'));

alter table public.performance_evaluation_scores
    add column category text not null default 'Technical'
    check (category in ('Technical', 'Behavioural', 'Leadership'));

-- Only one KPI template per department (including "All Departments",
-- represented as a null department_id — coalesced to -1 here since a
-- plain unique index treats every null as distinct from every other null).
-- Without this, HR could accidentally apply a Sales-authored template to a
-- Design employee simply because the picker had no scoping, and multiple
-- templates for the same department made the auto-suggested default
-- ambiguous.
create unique index kpi_templates_department_unique
    on public.kpi_templates (coalesce(department_id, -1));
