-- MONIKA — migration 0006: profiles.base_salary
-- add_employee.dart has always collected a "Basic Monthly Salary" field
-- that had nowhere to go — payroll_summaries stores a snapshot per
-- pay-month, not a static current salary per employee. This adds that
-- missing static value, which also lets HR's role/department change
-- notification email correctly describe a raise/demotion.
--
-- Paste into Supabase SQL Editor and Run.

alter table public.profiles add column base_salary numeric(10, 2);
