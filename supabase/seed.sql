-- MONIKA — seed data
-- Run this in the SQL Editor AFTER schema.sql. Departments have no
-- dependency on auth users, so this part is safe to run immediately.
--
-- Profiles CANNOT be seeded here alone — profiles.id is a foreign key to
-- auth.users(id), and auth.users rows can only be created via the
-- Dashboard (Authentication > Add user) or Auth API, not plain SQL, since
-- Supabase manages password hashing internally. See the bottom of this
-- file for the exact steps + a fill-in-the-blanks INSERT once you have
-- your test users' UUIDs.

insert into public.departments (name) values
    ('Engineering'),
    ('Sales'),
    ('Operations'),
    ('Marketing'),
    ('Design'),
    ('Human Resources'),
    ('Finance');

-- ─────────────────────────────────────────────────────────────────────────
-- Creating your first test users (do this once, manually)
-- ─────────────────────────────────────────────────────────────────────────
--
-- 1. Supabase Dashboard → Authentication → Users → Add user
--    Create two users, e.g.:
--      test.employee@monika-demo.com   (pick any password)
--      test.hr@monika-demo.com         (pick any password)
--    Tick "Auto Confirm User" for both so you don't need to click an email
--    confirmation link.
--
-- 2. Copy each user's UUID from the Users table (click into the user, or
--    it's shown in the list).
--
-- 3. Come back here and run this, replacing the two UUID placeholders:
--
-- insert into public.profiles
--     (id, employee_code, name, user_role, job_title, department_id, avatar_initials, hire_date, risk_score, risk_level)
-- values
--     ('PASTE-EMPLOYEE-UUID-HERE', 'EMP-1042', 'Hin Chen Wei', 'employee', 'Mobile Developer',
--         (select id from public.departments where name = 'Engineering'), 'HC', '2024-11-01', 100, 'low'),
--     ('PASTE-HR-UUID-HERE', 'HR-0007', 'Aisyah Rahman', 'hr_admin', 'HR Administrator',
--         (select id from public.departments where name = 'Human Resources'), 'AR', '2023-05-01', 100, 'low');
--
-- After that, both accounts can log in through the app's real login screen
-- once auth is wired up (see project memory / next steps).
