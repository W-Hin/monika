-- Removes everything seed_demo_personas.sql created. Deleting the login
-- accounts cascades to their profiles and from there to their attendance,
-- violations, leave, reviews, trainings, certificates and notifications.
delete from auth.users where id::text like 'de000000-%';

delete from public.kpi_templates
where name in ('Engineering - Individual Contributor', 'Sales - Executive', 'Operations - Manager')
  and not exists (select 1 from public.performance_evaluations pe where pe.template_id = kpi_templates.id);
