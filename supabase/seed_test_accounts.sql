-- Paste this whole file into Supabase SQL Editor and Run once.
-- Safe to re-run: department inserts are idempotent (on conflict do nothing).

insert into public.departments (name) values
    ('Engineering'),
    ('Sales'),
    ('Operations'),
    ('Marketing'),
    ('Design'),
    ('Human Resources'),
    ('Finance')
on conflict (name) do nothing;

insert into public.profiles
    (id, employee_code, name, user_role, job_title, department_id, avatar_initials, hire_date, risk_score, risk_level)
values
    ('a78fe420-d593-4f99-a42e-376d7986bb37', 'EMP-1042', 'Hin Chen Wei', 'employee', 'Mobile Developer',
        (select id from public.departments where name = 'Engineering'), 'HC', '2024-11-01', 100, 'low'),
    ('dfa7f0ea-3692-4f09-933a-03be48ea98bc', 'HR-0007', 'Aisyah Rahman', 'hr_admin', 'HR Administrator',
        (select id from public.departments where name = 'Human Resources'), 'AR', '2023-05-01', 100, 'low');
