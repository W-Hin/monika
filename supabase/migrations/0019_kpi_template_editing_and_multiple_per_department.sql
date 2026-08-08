-- Reverting the one-template-per-department rule from migration 0016: in
-- practice a single department can have multiple roles that need different
-- KPI templates (e.g. an Engineering IC vs an Engineering Lead), so forcing
-- exactly one template per department was too rigid. HR now picks the
-- right template explicitly when more than one exists for a department —
-- the app no longer silently guesses when it's ambiguous (see hr_pe.dart).
drop index if exists public.kpi_templates_department_unique;
