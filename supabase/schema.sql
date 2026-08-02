-- MONIKA — Intelligent Mobile HR Management System
-- Postgres schema for Supabase, Phase 2
--
-- Translated from the earlier backend/database/schema.sql (MySQL) design.
-- Biggest change: Supabase Auth (auth.users) now owns credentials and
-- password reset entirely — the old `users` table's password_hash and
-- password_reset_tokens have no equivalent here. App-specific user data
-- lives in public.profiles, one row per auth.users row (id shared, uuid).
--
-- How to apply: Supabase Dashboard → SQL Editor → New query → paste this
-- whole file → Run. No DB password needed for this step, just dashboard
-- access. Re-running is not idempotent (no `if not exists` guards) — this
-- is meant to run once against a fresh project.

-- ─────────────────────────────────────────────────────────────────────────
-- Identity & Access
-- ─────────────────────────────────────────────────────────────────────────

create table public.departments (
    id   bigint generated always as identity primary key,
    name text not null unique
);

-- One row per auth.users row. Not auto-created by a trigger: account
-- provisioning (HR "Create new employee account") needs to create both the
-- auth.users row AND this profile row atomically, which requires the
-- service_role key — that has to happen server-side (a Supabase Edge
-- Function), never from the anon-key client. That's Phase 3 scope; see
-- supabase/README.md. For now, seed rows are inserted manually alongside
-- Dashboard-created auth users.
create table public.profiles (
    id                      uuid primary key references auth.users(id) on delete cascade,
    employee_code           text not null unique, -- display id, e.g. EMP-1042 / HR-0007 — matches AppUser.id in Flutter
    name                    text not null,
    user_role               text not null check (user_role in ('employee', 'hr_admin')),
    job_title               text not null,
    department_id           bigint not null references public.departments(id),
    avatar_initials         text not null,
    hire_date               date not null, -- source of truth; AppUser.employmentDuration is a formatted display of this

    -- Device binding — display name (AppUser.registeredDevice) + real binding
    -- token (not yet captured by the UI; clock_in.dart's 3-step check is
    -- still simulated — wire this up for real in Phase 3).
    registered_device_name  text,
    device_token            text,
    device_bound_at         timestamptz,

    -- Running risk score: starts at 100, deducted per offence type (weights
    -- configurable via policy_settings). risk_level is a cached band derived
    -- from risk_score so list screens (hr_employees, hr_home) don't need to
    -- recompute it per row.
    risk_score              integer not null default 100,
    risk_level              text not null default 'low' check (risk_level in ('low', 'medium', 'high')),

    is_active               boolean not null default true,
    created_at              timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Attendance & Security (IoT triple-layer validation + risk/anomaly)
-- ─────────────────────────────────────────────────────────────────────────

create table public.attendance_records (
    id            bigint generated always as identity primary key,
    user_id       uuid not null references public.profiles(id) on delete cascade,
    work_date     date not null,
    clock_in_at   timestamptz not null,
    clock_out_at  timestamptz,
    status        text not null check (status in ('on_time', 'late', 'flagged', 'leave')),
    flag_reason   text,

    -- IoT triple-layer validation results (all 3 must pass, per scope doc)
    gps_lat       numeric(10, 7),
    gps_lng       numeric(10, 7),
    gps_passed    boolean not null default false,
    wifi_ssid     text,
    wifi_passed   boolean not null default false,
    device_passed boolean not null default false,

    created_at    timestamptz not null default now(),

    unique (user_id, work_date)
);

create table public.anomaly_events (
    id                    bigint generated always as identity primary key,
    user_id               uuid not null references public.profiles(id) on delete cascade,
    attendance_record_id  bigint references public.attendance_records(id) on delete set null, -- set when the anomaly came from a specific clock-in attempt
    type                  text not null check (type in ('out_of_zone', 'shared_device', 'late')),
    event_date            date not null,
    details               text not null,
    severity              text not null check (severity in ('low', 'medium', 'high')),
    reviewed              boolean not null default false,
    reviewed_by           uuid references public.profiles(id) on delete set null,
    reviewed_at           timestamptz,
    created_at            timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Leave & Payroll
-- ─────────────────────────────────────────────────────────────────────────

create table public.leave_applications (
    id              bigint generated always as identity primary key,
    reference_code  text not null unique, -- display id, e.g. LV-2201
    user_id         uuid not null references public.profiles(id) on delete cascade,
    leave_type      text not null check (leave_type in ('annual', 'medical', 'emergency', 'unpaid')),
    start_date      date not null,
    end_date        date not null,
    days            integer not null,
    reason          text not null,
    status          text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    decided_by      uuid references public.profiles(id) on delete set null,
    decided_at      timestamptz,
    created_at      timestamptz not null default now()
);

create table public.leave_balances (
    id               bigint generated always as identity primary key,
    user_id          uuid not null references public.profiles(id) on delete cascade,
    year             smallint not null,
    annual_total     integer not null default 0,
    annual_used      integer not null default 0,
    medical_total    integer not null default 0,
    medical_used     integer not null default 0,
    emergency_total  integer not null default 0,
    emergency_used   integer not null default 0,

    unique (user_id, year)
);

create table public.payroll_summaries (
    id            bigint generated always as identity primary key,
    user_id       uuid not null references public.profiles(id) on delete cascade,
    pay_month     date not null, -- stored as the 1st of the month, e.g. 2026-07-01
    base_salary   numeric(10, 2) not null,
    deductions    numeric(10, 2) not null default 0,
    net_pay       numeric(10, 2) not null,
    generated_at  timestamptz not null default now(),

    unique (user_id, pay_month)
);

create table public.payroll_deduction_items (
    id          bigint generated always as identity primary key,
    payroll_id  bigint not null references public.payroll_summaries(id) on delete cascade,
    label       text not null,
    amount      numeric(10, 2) not null
);

-- ─────────────────────────────────────────────────────────────────────────
-- Evaluation & Training
-- ─────────────────────────────────────────────────────────────────────────

create table public.kpi_templates (
    id             bigint generated always as identity primary key,
    name           text not null,
    department_id  bigint references public.departments(id) on delete set null, -- NULL = all departments
    created_at     timestamptz not null default now()
);

create table public.kpi_template_items (
    id           bigint generated always as identity primary key,
    template_id  bigint not null references public.kpi_templates(id) on delete cascade,
    name         text not null,
    weightage    numeric(5, 2) not null -- percent; all items for one template must sum to 100, enforced in application logic
);

create table public.performance_evaluations (
    id              bigint generated always as identity primary key,
    user_id         uuid not null references public.profiles(id) on delete cascade,
    template_id     bigint references public.kpi_templates(id) on delete set null, -- kept nullable — template may be edited/retired after this was scored
    year            smallint not null,
    comments        text,
    weighted_total  numeric(5, 2) not null, -- cached sum(score * weightage / 100); recomputed on save
    created_at      timestamptz not null default now(),

    unique (user_id, year)
);

create table public.performance_evaluation_scores (
    id             bigint generated always as identity primary key,
    evaluation_id  bigint not null references public.performance_evaluations(id) on delete cascade,
    kpi_name       text not null,
    weightage      numeric(5, 2) not null, -- snapshot of the weightage used at scoring time, independent of later template edits
    score          numeric(5, 2) not null  -- 0-100
);

create table public.training_programs (
    id            bigint generated always as identity primary key,
    title         text not null,
    category      text not null check (category in ('technical', 'behavioural', 'leadership')),
    description   text not null,
    is_mandatory  boolean not null default false,
    duration      text not null, -- display string, e.g. "4 weeks · Self-paced"
    department_id bigint references public.departments(id) on delete set null, -- NULL = all departments
    created_at    timestamptz not null default now()
);

create table public.training_enrollments (
    id                     bigint generated always as identity primary key,
    program_id             bigint not null references public.training_programs(id) on delete cascade,
    user_id                uuid not null references public.profiles(id) on delete cascade,
    is_recommended         boolean not null default false, -- set by the ML/rule recommendation engine, Phase 5
    recommendation_reason  text,
    progress               numeric(3, 2) not null default 0, -- 0.00-1.00
    is_completed           boolean not null default false,
    performance_score      numeric(5, 2), -- 0-100, set once completed
    enrolled_at            timestamptz not null default now(),
    completed_at           timestamptz,

    unique (program_id, user_id)
);

-- ─────────────────────────────────────────────────────────────────────────
-- Config & Analytics
-- ─────────────────────────────────────────────────────────────────────────

-- Single-row table (id is always 1) holding every HR-configurable value from
-- policy_config.dart. A key-value table was considered but rejected — this
-- is a small, fixed set of fields the app already treats as a flat settings
-- form, so named columns keep it directly queryable/typed without an unpack
-- step.
create table public.policy_settings (
    id                     integer primary key default 1,

    -- Risk score weights: points deducted per violation type
    late_weight            numeric(4, 1) not null default 1,
    out_of_zone_weight     numeric(4, 1) not null default 2,
    shared_device_weight   numeric(4, 1) not null default 3,

    -- Payroll deduction amounts (RM), applied at payroll computation time
    late_deduction         numeric(10, 2) not null default 25.00,
    absent_deduction       numeric(10, 2) not null default 120.00,

    -- Training trigger thresholds: PE category score below this recommends training
    leadership_threshold   numeric(5, 2) not null default 60,
    technical_threshold    numeric(5, 2) not null default 65,
    behavioural_threshold  numeric(5, 2) not null default 60,

    -- Minimum employment duration (months) before an employee is eligible
    -- for training recommendations — matches policy_config.dart's
    -- "Minimum employment duration before eligibility" slider.
    min_tenure_months      integer not null default 6,

    updated_at             timestamptz not null default now(),

    constraint single_row check (id = 1)
);

insert into public.policy_settings (id) values (1);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger policy_settings_set_updated_at
    before update on public.policy_settings
    for each row execute function public.set_updated_at();

-- Note: TeamMemberSummary.attendanceRate is deliberately NOT a stored column
-- anywhere — it's a derived aggregate (on-time attendance_records / total
-- attendance_records for a user) and should be computed by query in the
-- Analytics/Reporting endpoints, not cached, to avoid it drifting out of
-- sync with the underlying attendance_records rows.

-- ─────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────────────────────

-- SECURITY DEFINER so this bypasses RLS on profiles when called from inside
-- another table's policy (otherwise checking "is this caller HR?" from
-- within e.g. an attendance_records policy would recurse into profiles'
-- own RLS and could deadlock/return wrong results).
create or replace function public.is_hr_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1 from public.profiles
        where id = auth.uid() and user_role = 'hr_admin'
    );
$$;

alter table public.departments enable row level security;
alter table public.profiles enable row level security;
alter table public.attendance_records enable row level security;
alter table public.anomaly_events enable row level security;
alter table public.leave_applications enable row level security;
alter table public.leave_balances enable row level security;
alter table public.payroll_summaries enable row level security;
alter table public.payroll_deduction_items enable row level security;
alter table public.kpi_templates enable row level security;
alter table public.kpi_template_items enable row level security;
alter table public.performance_evaluations enable row level security;
alter table public.performance_evaluation_scores enable row level security;
alter table public.training_programs enable row level security;
alter table public.training_enrollments enable row level security;
alter table public.policy_settings enable row level security;

-- departments — read-only reference data for every signed-in user, HR-only writes
create policy "departments_select_authenticated" on public.departments
    for select using (auth.role() = 'authenticated');
create policy "departments_write_hr" on public.departments
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- profiles — everyone can read/update their own row; HR can read/update everyone's
create policy "profiles_select_own_or_hr" on public.profiles
    for select using (id = auth.uid() or public.is_hr_admin());
create policy "profiles_update_own_or_hr" on public.profiles
    for update using (id = auth.uid() or public.is_hr_admin())
    with check (id = auth.uid() or public.is_hr_admin());
-- Inserts happen only via the service-role Edge Function during account
-- creation (see supabase/README.md) — no client-side insert policy needed.

-- attendance_records — employees manage their own (clock in/out); HR reads all
create policy "attendance_select_own_or_hr" on public.attendance_records
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "attendance_insert_own" on public.attendance_records
    for insert with check (user_id = auth.uid());
create policy "attendance_update_own_or_hr" on public.attendance_records
    for update using (user_id = auth.uid() or public.is_hr_admin())
    with check (user_id = auth.uid() or public.is_hr_admin());

-- anomaly_events — HR-only (employees see their own flags via attendance_records.flag_reason instead)
create policy "anomaly_select_hr" on public.anomaly_events
    for select using (public.is_hr_admin());
create policy "anomaly_write_hr" on public.anomaly_events
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- leave_applications — employees submit/read their own; HR reads/decides all
create policy "leave_select_own_or_hr" on public.leave_applications
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "leave_insert_own" on public.leave_applications
    for insert with check (user_id = auth.uid());
create policy "leave_update_hr_only" on public.leave_applications
    for update using (public.is_hr_admin()) with check (public.is_hr_admin());

-- leave_balances — employees read-only their own; HR manages all
create policy "leave_balances_select_own_or_hr" on public.leave_balances
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "leave_balances_write_hr" on public.leave_balances
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- payroll — employees read-only their own; HR generates/manages all
create policy "payroll_select_own_or_hr" on public.payroll_summaries
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "payroll_write_hr" on public.payroll_summaries
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

create policy "payroll_items_select_own_or_hr" on public.payroll_deduction_items
    for select using (
        exists (
            select 1 from public.payroll_summaries p
            where p.id = payroll_id and (p.user_id = auth.uid() or public.is_hr_admin())
        )
    );
create policy "payroll_items_write_hr" on public.payroll_deduction_items
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- kpi_templates — readable by all signed-in users (employees see their assigned template alongside their PE); HR-only writes
create policy "kpi_templates_select_authenticated" on public.kpi_templates
    for select using (auth.role() = 'authenticated');
create policy "kpi_templates_write_hr" on public.kpi_templates
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

create policy "kpi_template_items_select_authenticated" on public.kpi_template_items
    for select using (auth.role() = 'authenticated');
create policy "kpi_template_items_write_hr" on public.kpi_template_items
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- performance_evaluations — employees read-only their own; HR conducts/manages all
create policy "pe_select_own_or_hr" on public.performance_evaluations
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "pe_write_hr" on public.performance_evaluations
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

create policy "pe_scores_select_own_or_hr" on public.performance_evaluation_scores
    for select using (
        exists (
            select 1 from public.performance_evaluations e
            where e.id = evaluation_id and (e.user_id = auth.uid() or public.is_hr_admin())
        )
    );
create policy "pe_scores_write_hr" on public.performance_evaluation_scores
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- training_programs — catalog readable by all signed-in users; HR-only writes
create policy "training_programs_select_authenticated" on public.training_programs
    for select using (auth.role() = 'authenticated');
create policy "training_programs_write_hr" on public.training_programs
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- training_enrollments — employees manage their own (enrol, track progress); HR reads all for completion tracking
create policy "enrollments_select_own_or_hr" on public.training_enrollments
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "enrollments_insert_own" on public.training_enrollments
    for insert with check (user_id = auth.uid());
create policy "enrollments_update_own_or_hr" on public.training_enrollments
    for update using (user_id = auth.uid() or public.is_hr_admin())
    with check (user_id = auth.uid() or public.is_hr_admin());

-- policy_settings — HR-only, employees never read this directly (current UI
-- only ever displays these values on HR-facing screens)
create policy "policy_settings_all_hr" on public.policy_settings
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());
