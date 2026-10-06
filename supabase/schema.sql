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
    email                   text,
    base_salary             numeric(10, 2), -- monthly basic salary (RM); payroll starts from this
    is_intern               boolean not null default false, -- set from job_title = 'Intern' when the account is created/edited
    -- New accounts get a temporary password and must set their own on
    -- first login (the create-employee Edge Function sets this to true).
    must_change_password    boolean not null default true,

    -- Device binding — display name (AppUser.registeredDevice) + real binding
    -- token (not yet captured by the UI; clock_in.dart's 3-step check is
    -- still simulated — wire this up for real in Phase 3).
    registered_device_name  text,
    device_token            text,
    device_bound_at         timestamptz,

    -- Running risk score: starts at 100, deducted per offence type (weights
    -- configurable via policy_settings). risk_level is a cached band derived
    -- from risk_score so list screens (hr_employees, hr_home) don't need to
    -- recompute it per row. risk_period_start marks when the current period
    -- began — used by apply_risk_deduction()/reset_stale_risk_scores() to
    -- reset the score to 100 automatically every policy_settings
    -- .risk_reset_period_months, independent of HR's own manual reset.
    risk_score              integer not null default 100,
    risk_level              text not null default 'low' check (risk_level in ('low', 'medium', 'high')),
    risk_period_start       timestamptz not null default now(),

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
    status        text not null check (status in ('on_time', 'late', 'flagged')),
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
    type                  text not null check (type in ('out_of_zone', 'shared_device', 'late', 'wifi_mismatch', 'early_clockout', 'unexplained_absence')),
    event_date            date not null,
    details               text not null,
    severity              text not null check (severity in ('low', 'medium', 'high')),
    reviewed              boolean not null default false,
    reviewed_by           uuid references public.profiles(id) on delete set null,
    reviewed_at           timestamptz,
    reverted_at           timestamptz, -- HR found it invalid after a dispute; its risk points were given back
    -- An employee's appeal against an unexplained absence (within 7 days of it)
    appeal_reason         text,
    appealed_at           timestamptz,
    appeal_status         text check (appeal_status is null or appeal_status in ('pending', 'accepted', 'rejected')),
    appeal_response       text, -- HR's note when rejecting
    appeal_decided_at     timestamptz,
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
    status          text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
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

-- One row per risk-score-zero event, queued for PayrollService to pick up
-- (and re-pick-up on regeneration) at that month's payroll run — see
-- apply_risk_deduction() below for what inserts into this.
create table public.risk_score_penalties (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references public.profiles(id) on delete cascade,
    pay_month   date not null, -- 1st of the month this penalty applies to
    percent     numeric(4, 2) not null,
    created_at  timestamptz not null default now()
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
    weightage    numeric(5, 2) not null, -- percent; all items for one template must sum to 100, enforced in application logic
    category     text not null default 'Technical' check (category in ('Technical', 'Behavioural', 'Leadership')),
    -- 'manual' = HR scores it; the rest are computed from this system's own data (PeMetricsService)
    metric_source text not null default 'manual' check (metric_source in ('manual', 'attendance', 'punctuality', 'conduct', 'training'))
);

create table public.performance_evaluations (
    id              bigint generated always as identity primary key,
    user_id         uuid not null references public.profiles(id) on delete cascade,
    template_id     bigint references public.kpi_templates(id) on delete set null, -- kept nullable — template may be edited/retired after this was scored
    year            smallint not null,
    comments        text,
    weighted_total  numeric(5, 2) not null, -- cached sum(score * weightage / 100); recomputed on save
    created_at      timestamptz not null default now(),
    -- Set while HR is still scoring — excluded from the employee's own PE
    -- view/history and from triggering training recommendations until
    -- HR finishes and submits for real (is_draft = false).
    is_draft        boolean not null default false,

    unique (user_id, year)
);

-- A submitted (non-draft) evaluation is final — once is_draft is false the
-- row can't be updated, which also stops the app's submit path (it upserts
-- this row before touching scores). Drafts can still be edited and promoted.
create or replace function public.prevent_completed_pe_edit()
returns trigger
language plpgsql
as $$
begin
    if old.is_draft = false then
        raise exception 'This performance evaluation has already been submitted and can no longer be changed.';
    end if;
    return new;
end;
$$;

create trigger trg_prevent_completed_pe_edit
    before update on public.performance_evaluations
    for each row
    execute function public.prevent_completed_pe_edit();

create table public.performance_evaluation_scores (
    id             bigint generated always as identity primary key,
    evaluation_id  bigint not null references public.performance_evaluations(id) on delete cascade,
    kpi_name       text not null,
    weightage      numeric(5, 2) not null, -- snapshot of the weightage used at scoring time, independent of later template edits
    score          numeric(5, 2) not null, -- 0-100
    category       text not null default 'Technical' check (category in ('Technical', 'Behavioural', 'Leadership')), -- snapshot, like weightage
    metric_source  text not null default 'manual' -- snapshot of how this score was produced
);

create table public.training_programs (
    id            bigint generated always as identity primary key,
    title         text not null,
    category      text not null check (category in ('technical', 'behavioural', 'leadership')),
    description   text not null,
    is_mandatory  boolean not null default false,
    duration      text not null, -- display string, e.g. "4 weeks · Self-paced"
    department_id bigint references public.departments(id) on delete set null, -- NULL = all departments
    -- Quiz: percent of questions that must be answered correctly to pass.
    pass_mark     integer not null default 70 check (pass_mark between 1 and 100),
    -- 'recommended_only' programmes are hidden from the catalogue and only
    -- reach an employee as a recommendation (see refresh_training_recommendations_for).
    access        text not null default 'open' check (access in ('open', 'recommended_only')),
    -- Eligibility lock: months of service before an employee can enrol.
    min_tenure_months integer not null default 0 check (min_tenure_months >= 0),
    -- Behaviour rules that auto-recommend a remedial programme.
    trigger_risk_level text check (trigger_risk_level is null or trigger_risk_level in ('medium', 'high')),
    trigger_attendance_below numeric(5, 2),
    created_at    timestamptz not null default now()
);

create table public.training_enrollments (
    id                     bigint generated always as identity primary key,
    program_id             bigint not null references public.training_programs(id) on delete cascade,
    user_id                uuid not null references public.profiles(id) on delete cascade,
    is_recommended         boolean not null default false, -- set by the ML/rule recommendation engine, Phase 5
    recommendation_reason  text,
    recommended_by         text check (recommended_by is null or recommended_by in ('rule', 'pe', 'ml')), -- null = self-enrolled
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

    -- Working hours and the office the clock-in checks are measured against
    work_start_time        time not null default '09:00',
    work_end_time          time not null default '18:00',
    grace_period_minutes   integer not null default 10,
    geofence_radius_meters integer not null default 100,
    office_wifi_ssid       text not null default 'MONIKA-OFFICE-5G',
    office_lat             numeric(10, 7) not null default 3.1390,
    office_lng             numeric(10, 7) not null default 101.6869,

    -- Risk score weights: points deducted per violation type. Deliberately
    -- punitive rather than a slow trickle — a single shared-device attempt
    -- burns roughly a third of a clean score. Relative severity order:
    -- early_clockout < late < wifi_mismatch < unexplained_absence <
    -- out_of_zone < shared_device.
    late_weight                 numeric(4, 1) not null default 10,
    out_of_zone_weight          numeric(4, 1) not null default 20,
    shared_device_weight        numeric(4, 1) not null default 35,
    wifi_mismatch_weight        numeric(4, 1) not null default 12,
    early_clockout_weight       numeric(4, 1) not null default 8,
    unexplained_absence_weight  numeric(4, 1) not null default 15,

    -- How often (months) an employee's risk score resets to 100 on its
    -- own, independent of HR's manual reset — see apply_risk_deduction()
    -- and reset_stale_risk_scores() below.
    risk_reset_period_months    integer not null default 2,
    -- Percentage of that month's base_salary deducted the moment a risk
    -- score hits 0 — queued in risk_score_penalties, applied by
    -- PayrollService at the next payroll run for that employee.
    risk_penalty_percent        numeric(4, 2) not null default 5.00,

    -- Payroll deduction amounts (RM), applied at payroll computation time
    late_deduction         numeric(10, 2) not null default 25.00,
    absent_deduction       numeric(10, 2) not null default 120.00,
    unpaid_leave_daily_rate numeric(10, 2) not null default 120.00,

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

-- Deducts the matching policy_settings weight from the offending employee's
-- risk_score on every anomaly_events insert, resetting the score (and the
-- period timer) either when a full risk_reset_period_months has quietly
-- elapsed since the last reset, or immediately when the deduction would
-- take the score to 0 — the latter also queues a one-off salary penalty in
-- risk_score_penalties for PayrollService to apply. SECURITY DEFINER
-- because the inserting client (employee or HR) has no direct RLS grant to
-- update another profile's risk_score.
create or replace function public.apply_risk_deduction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    policy       record;
    weight       numeric(4,1);
    profile_row  record;
    base_score   integer;
    new_score    integer;
    period_reset boolean := false;
begin
    select * into policy from public.policy_settings where id = 1;

    weight := case new.type
        when 'late'                then policy.late_weight
        when 'out_of_zone'         then policy.out_of_zone_weight
        when 'shared_device'       then policy.shared_device_weight
        when 'wifi_mismatch'       then policy.wifi_mismatch_weight
        when 'early_clockout'      then policy.early_clockout_weight
        when 'unexplained_absence' then policy.unexplained_absence_weight
        else 0
    end;

    select * into profile_row from public.profiles where id = new.user_id for update;

    if profile_row.risk_period_start <= now() - (policy.risk_reset_period_months || ' months')::interval then
        base_score := 100;
        period_reset := true;
    else
        base_score := profile_row.risk_score;
    end if;

    new_score := greatest(base_score - weight, 0);

    if new_score <= 0 then
        insert into public.risk_score_penalties (user_id, pay_month, percent)
        values (new.user_id, date_trunc('month', now())::date, policy.risk_penalty_percent);
        new_score := 100;
        period_reset := true;
    end if;

    update public.profiles
        set risk_score = new_score,
            risk_level = case when new_score >= 80 then 'low' when new_score >= 50 then 'medium' else 'high' end,
            risk_period_start = case when period_reset then now() else risk_period_start end
        where id = new.user_id;

    return new;
end;
$$;

create trigger trg_apply_risk_deduction
    after insert on public.anomaly_events
    for each row execute function public.apply_risk_deduction();

-- Proactive reset for employees who go quiet — the trigger above only
-- resets lazily when a NEW violation arrives after the period elapses,
-- which would leave a genuinely reformed employee stuck at a stale low
-- score forever if they have no further violations to trigger a reset.
-- Scheduled daily via pg_cron below.
create or replace function public.reset_stale_risk_scores()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.profiles p
    set risk_score = 100,
        risk_level = 'low',
        risk_period_start = now()
    from public.policy_settings s
    where s.id = 1
      and p.risk_period_start <= now() - (s.risk_reset_period_months || ' months')::interval
      and p.risk_score < 100;
end;
$$;

-- Absence is "the absence of an event", so unlike every other violation
-- type it can't be raised inline from a clock-in attempt. Scans
-- "yesterday" once daily, reusing the exact same exclusion rules
-- PayrollService.generateForMonth() applies (weekday, not a public
-- holiday, on/after hire date, no attendance record, not covered by
-- approved leave) so the two absence definitions can never disagree.
-- Raising it as a normal anomaly_events row means it flows through
-- apply_risk_deduction() above for free.
create or replace function public.detect_unexplained_absences()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    check_date date := ((now() at time zone 'Asia/Kuala_Lumpur') - interval '1 day')::date;
begin
    if extract(isodow from check_date) in (6, 7) then
        return;
    end if;

    insert into public.anomaly_events (user_id, type, event_date, details, severity)
    select p.id, 'unexplained_absence', check_date,
           'No attendance record and no approved leave for ' || to_char(check_date, 'DD Mon YYYY'),
           'medium'
    from public.profiles p
    where p.is_active
      and p.hire_date <= check_date
      and not exists (
          select 1 from public.company_events ce
          where ce.event_type = 'public_holiday'
            and (ce.event_date at time zone 'Asia/Kuala_Lumpur')::date = check_date
      )
      and not exists (
          select 1 from public.attendance_records ar
          where ar.user_id = p.id and ar.work_date = check_date
      )
      and not exists (
          select 1 from public.leave_applications la
          where la.user_id = p.id and la.status = 'approved'
            and check_date between la.start_date and la.end_date
      )
      and not exists (
          select 1 from public.anomaly_events ae
          where ae.user_id = p.id and ae.type = 'unexplained_absence' and ae.event_date = check_date
      );
end;
$$;

-- Requires the pg_cron extension — a standard Postgres extension,
-- enableable from the Supabase SQL Editor or Dashboard → Database →
-- Extensions. Everything above works without it; these two jobs just add
-- the *proactive* half of the reset/absence-detection behaviour.
create extension if not exists pg_cron;
-- pg_cron runs in UTC; these are 00:30 and 01:00 Malaysia time.
select cron.schedule('detect-unexplained-absences', '30 16 * * *', $$select public.detect_unexplained_absences();$$);
select cron.schedule('reset-stale-risk-scores', '0 17 * * *', $$select public.reset_stale_risk_scores();$$);

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
alter table public.risk_score_penalties enable row level security;

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
-- Requires the profile to still be active — a deactivated employee's
-- Supabase Auth session stays valid, so this is what actually stops
-- them from clocking in once HR deactivates their account.
create policy "attendance_insert_own" on public.attendance_records
    for insert with check (
        user_id = auth.uid()
        and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active)
    );
create policy "attendance_update_own_or_hr" on public.attendance_records
    for update using (user_id = auth.uid() or public.is_hr_admin())
    with check (user_id = auth.uid() or public.is_hr_admin());

-- anomaly_events — HR reads all (employees see their own flags via
-- attendance_records.flag_reason instead); the app raises an employee's own
-- anomalies from their clock-in, so they may insert rows for themselves.
create policy "anomaly_select_hr" on public.anomaly_events
    for select using (public.is_hr_admin());
create policy "anomaly_write_hr" on public.anomaly_events
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());
create policy "anomaly_insert_own" on public.anomaly_events
    for insert with check (user_id = auth.uid());

-- leave_applications — employees submit/read their own; HR reads/decides all
create policy "leave_select_own_or_hr" on public.leave_applications
    for select using (user_id = auth.uid() or public.is_hr_admin());
-- Same active-profile requirement as attendance_insert_own above.
create policy "leave_insert_own" on public.leave_applications
    for insert with check (
        user_id = auth.uid()
        and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active)
    );
create policy "leave_update_hr_only" on public.leave_applications
    for update using (public.is_hr_admin()) with check (public.is_hr_admin());
-- The applicant may withdraw their own application while it's Pending.
create policy "leave_cancel_own" on public.leave_applications
    for update
    using (user_id = auth.uid() and status = 'pending')
    with check (user_id = auth.uid() and status = 'cancelled');

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

-- risk_score_penalties — an employee can see their own queued penalties; HR sees all
create policy "risk_score_penalties_select_own_or_hr" on public.risk_score_penalties
    for select using (user_id = auth.uid() or public.is_hr_admin());
-- Inserts happen only via apply_risk_deduction() (SECURITY DEFINER) — no
-- client-side insert/update policy needed, same pattern as profiles'
-- own risk_score column.

-- policy_settings — HR edits; every signed-in user can read it, since an
-- employee's clock-in checks need the office location, WiFi and hours.
create policy "policy_settings_all_hr" on public.policy_settings
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());
create policy "policy_settings_select_authenticated" on public.policy_settings
    for select using (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────────────
-- Self-approval guards
-- ─────────────────────────────────────────────────────────────────────────

-- HR can't change their own job title, department, salary or role.
create or replace function public.prevent_self_employment_edit()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.id then
    if new.job_title is distinct from old.job_title
       or new.department_id is distinct from old.department_id
       or new.base_salary is distinct from old.base_salary
       or new.user_role is distinct from old.user_role then
      raise exception 'You cannot change your own job title, department, salary, or role. Ask another HR admin to make this change.';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_prevent_self_employment_edit
  before update on public.profiles
  for each row
  execute function public.prevent_self_employment_edit();

-- HR can't approve or reject their own leave; the applicant can cancel it
-- while Pending, and nothing else can become Cancelled.
create or replace function public.prevent_self_leave_decision()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' and old.status <> 'pending' then
    raise exception 'Only a pending leave application can be cancelled.';
  end if;
  if auth.uid() = old.user_id
     and new.status in ('approved', 'rejected')
     and new.status is distinct from old.status then
    raise exception 'You cannot approve or reject your own leave application. Ask another HR admin to decide on it.';
  end if;
  return new;
end;
$$;

create trigger trg_prevent_self_leave_decision
  before update on public.leave_applications
  for each row
  execute function public.prevent_self_leave_decision();

-- ─────────────────────────────────────────────────────────────────────────
-- Company calendar
-- ─────────────────────────────────────────────────────────────────────────

create table public.company_events (
    id          bigint generated always as identity primary key,
    title       text not null,
    event_date  timestamptz not null, -- an all-day event is stored as local midnight (Asia/Kuala_Lumpur)
    end_date    timestamptz,
    has_time    boolean not null default true, -- false = all-day (public holidays always are)
    event_type  text not null check (event_type in ('public_holiday', 'company_event', 'hr_event')),
    created_at  timestamptz not null default now()
);

-- An event with no assignments is for everyone; otherwise only the
-- assigned employees (and HR) see it.
create table public.company_event_assignments (
    id        bigint generated always as identity primary key,
    event_id  bigint not null references public.company_events(id) on delete cascade,
    user_id   uuid not null references public.profiles(id) on delete cascade,
    unique (event_id, user_id)
);

alter table public.company_events enable row level security;
alter table public.company_event_assignments enable row level security;

create policy "company_events_select_scoped" on public.company_events
    for select using (
        public.is_hr_admin()
        or not exists (select 1 from public.company_event_assignments a where a.event_id = id)
        or exists (select 1 from public.company_event_assignments a where a.event_id = id and a.user_id = auth.uid())
    );
create policy "company_events_write_hr" on public.company_events
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

create policy "company_event_assignments_select_own_or_hr" on public.company_event_assignments
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "company_event_assignments_write_hr" on public.company_event_assignments
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- ─────────────────────────────────────────────────────────────────────────
-- In-app notifications (Supabase Realtime, no push service)
-- ─────────────────────────────────────────────────────────────────────────

-- Written only by the security-definer triggers and functions below,
-- never inserted directly by the app.
create table public.notifications (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references public.profiles(id) on delete cascade,
    title       text not null,
    body        text not null,
    type        text not null check (type in (
                    'leave_decision', 'training', 'payroll', 'anomaly', 'pe',
                    'device_change', 'announcement', 'onboarding')),
    is_read     boolean not null default false,
    created_at  timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "notifications_select_own" on public.notifications
    for select using (user_id = auth.uid());
create policy "notifications_update_own" on public.notifications
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

alter publication supabase_realtime add table public.notifications;

create or replace function public.notify_leave_decision() returns trigger
language plpgsql security definer as $$
begin
  if new.status is distinct from old.status and new.status in ('approved', 'rejected') then
    insert into public.notifications (user_id, title, body, type)
    values (
      new.user_id,
      case when new.status = 'approved' then 'Leave Application Approved' else 'Leave Application Rejected' end,
      format('Your %s leave application (%s to %s) has been %s.', new.leave_type, new.start_date, new.end_date, new.status) ||
      E'\n\nNext steps:\n1. Go to the Leave page\n2. View your leave status',
      'leave_decision'
    );
  end if;
  return new;
end;
$$;

create trigger trg_notify_leave_decision
  after update on public.leave_applications
  for each row execute function public.notify_leave_decision();

-- Scoped to the programme's department, or everyone if it's for all.
create or replace function public.notify_new_training() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  select p.id, 'New Training Published',
    format('A new training programme is available: %s', new.title) ||
    E'\n\nNext steps:\n1. Go to Training\n2. Enrol in the new programme',
    'training'
  from public.profiles p
  where new.department_id is null or p.department_id = new.department_id;
  return new;
end;
$$;

create trigger trg_notify_new_training
  after insert on public.training_programs
  for each row execute function public.notify_new_training();

create or replace function public.notify_payroll_ready() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (
    new.user_id,
    'Payroll Summary Available',
    format('Your %s payroll summary is now available. Net pay: RM %s.', to_char(new.pay_month, 'FMMonth YYYY'), to_char(new.net_pay, 'FM999,999,990.00')) ||
    E'\n\nNext steps:\n1. Go to Payroll\n2. View your payslip breakdown',
    'payroll'
  );
  return new;
end;
$$;

create trigger trg_notify_payroll_ready
  after insert on public.payroll_summaries
  for each row execute function public.notify_payroll_ready();

create or replace function public.notify_anomaly() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (
    new.user_id,
    case when new.type = 'unexplained_absence' then 'Unexplained Absence' else 'Attendance Flag' end,
    case when new.type = 'unexplained_absence'
      then format('You were marked absent on %s: no clock-in and no approved leave.', to_char(new.event_date, 'DD Mon YYYY')) ||
           format(E'\n\nIf you were working or had a valid reason, appeal by %s:\n1. Go to Attendance\n2. Tap Appeal on this absence and explain why', to_char(new.event_date + 7, 'DD Mon YYYY'))
      else format('An attendance anomaly was flagged on your account: %s', new.details) ||
           E'\n\nNext steps:\n1. Go to Attendance\n2. Review the flagged record — contact HR if this wasn\'t you'
    end,
    'anomaly'
  );
  return new;
end;
$$;

create trigger trg_notify_anomaly
  after insert on public.anomaly_events
  for each row execute function public.notify_anomaly();

create or replace function public.notify_pe_evaluated() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (
    new.user_id,
    'Performance Evaluation Updated',
    format('Your %s Performance Evaluation results are now available.', new.year) ||
    E'\n\nNext steps:\n1. Go to My Performance Evaluation\n2. Review your KPI scores and HR comments',
    'pe'
  );
  return new;
end;
$$;

create trigger trg_notify_pe_evaluated
  after insert or update on public.performance_evaluations
  for each row execute function public.notify_pe_evaluated();

-- HR announcement to everyone, or to one department. Returns how many
-- employees it reached.
create or replace function public.post_announcement(
    p_title text,
    p_body text,
    p_department_id bigint default null
) returns integer
language plpgsql
security definer
as $$
declare
  recipient_count integer;
begin
  if not public.is_hr_admin() then
    raise exception 'Only HR admins can post announcements.';
  end if;
  insert into public.notifications (user_id, title, body, type)
  select p.id, p_title, p_body, 'announcement'
  from public.profiles p
  where p_department_id is null or p.department_id = p_department_id;
  get diagnostics recipient_count = row_count;
  return recipient_count;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Device change requests
-- ─────────────────────────────────────────────────────────────────────────

create table public.device_change_requests (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references public.profiles(id) on delete cascade,
    reason      text not null,
    status      text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
    decided_by  uuid references public.profiles(id) on delete set null,
    decided_at  timestamptz,
    created_at  timestamptz not null default now()
);

alter table public.device_change_requests enable row level security;

create policy "device_change_requests_select_own_or_hr" on public.device_change_requests
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "device_change_requests_insert_own" on public.device_change_requests
    for insert with check (user_id = auth.uid());
create policy "device_change_requests_update_hr" on public.device_change_requests
    for update using (public.is_hr_admin()) with check (public.is_hr_admin());
-- An employee can withdraw their own request while it's still pending.
create policy "device_change_requests_cancel_own" on public.device_change_requests
    for update
    using (user_id = auth.uid() and status = 'pending')
    with check (status = 'cancelled');

alter publication supabase_realtime add table public.device_change_requests;

-- Nobody approves or rejects their own request (cancelling is allowed).
create or replace function public.prevent_self_device_request_decision()
returns trigger
language plpgsql
as $$
begin
    if auth.uid() = old.user_id
       and new.status in ('approved', 'rejected')
       and new.status is distinct from old.status then
        raise exception 'You cannot approve or reject your own device change request. Ask another HR admin to decide on it.';
    end if;
    return new;
end;
$$;

create trigger trg_prevent_self_device_request_decision
    before update on public.device_change_requests
    for each row
    execute function public.prevent_self_device_request_decision();

create or replace function public.notify_device_request_decision() returns trigger
language plpgsql security definer as $$
begin
  if new.status is distinct from old.status and new.status in ('approved', 'rejected') then
    insert into public.notifications (user_id, title, body, type)
    values (
      new.user_id,
      case when new.status = 'approved' then 'Device Change Approved' else 'Device Change Request Rejected' end,
      case when new.status = 'approved'
        then 'Your device change request has been approved and your old device has been unpaired.' ||
             E'\n\nNext steps to pair your new device:\n1. Log in on your new device\n2. Go to Home and tap Clock In\n3. Complete the verification steps — your new device is registered automatically on your first successful clock-in.'
        else 'Your device change request was not approved.' ||
             E'\n\nNext steps: 1. Contact HR to find out why 2. Submit a new request from Profile once resolved.'
      end,
      'device_change'
    );
  end if;
  return new;
end;
$$;

create trigger trg_notify_device_request_decision
  after update on public.device_change_requests
  for each row execute function public.notify_device_request_decision();

-- Is this device already bound to a different employee? (checked before
-- binding a device on clock-in, without exposing other profiles)
create or replace function public.device_token_bound_to_other(
    p_device_token text,
    p_calling_user_id uuid
) returns boolean
language sql
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.profiles
        where device_token = p_device_token
          and id <> p_calling_user_id
    );
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Leave entitlement
-- ─────────────────────────────────────────────────────────────────────────

-- Annual leave earned so far this year: 2 days per completed quarter of
-- service within the year (max 8), plus 1 day per full year of tenure
-- (max 4).
create or replace function public.compute_annual_leave_total(
    p_hire_date date,
    p_year smallint
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_year_start date := make_date(p_year, 1, 1);
    v_year_end date := make_date(p_year, 12, 31);
    v_accrual_start date;
    v_accrual_end date;
    v_months_accrued integer;
    v_quarters integer;
    v_full_years_tenure integer;
begin
    if p_hire_date is null or p_hire_date > v_year_end then
        return 0;
    end if;
    v_accrual_start := greatest(p_hire_date, v_year_start);
    v_accrual_end := least(current_date, v_year_end);
    if v_accrual_end < v_accrual_start then
        v_months_accrued := 0;
    else
        v_months_accrued := (extract(year from age(v_accrual_end, v_accrual_start)) * 12
            + extract(month from age(v_accrual_end, v_accrual_start)))::integer;
    end if;
    v_quarters := least(v_months_accrued / 3, 4);
    v_full_years_tenure := least(
        ((extract(year from age(current_date, p_hire_date)) * 12
            + extract(month from age(current_date, p_hire_date)))::integer) / 12,
        4
    );
    return (v_quarters * 2) + v_full_years_tenure;
end;
$$;

-- Creates the year's balance row if missing, and only ever raises
-- annual_total as more is earned — never touches the *_used counts.
-- Called by the app whenever it reads a balance.
create or replace function public.ensure_leave_balance_row(
    p_user_id uuid,
    p_year smallint
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_hire_date date;
    v_annual_total integer;
begin
    select hire_date into v_hire_date from public.profiles where id = p_user_id;
    v_annual_total := public.compute_annual_leave_total(v_hire_date, p_year);

    insert into public.leave_balances (
        user_id, year,
        annual_total, annual_used,
        medical_total, medical_used,
        emergency_total, emergency_used
    ) values (
        p_user_id, p_year,
        v_annual_total, 0,
        14, 0, 3, 0
    )
    on conflict (user_id, year) do update
        set annual_total = greatest(public.leave_balances.annual_total, excluded.annual_total);
end;
$$;

create or replace function public.ensure_leave_balances_for_year(
    p_year smallint
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_row record;
begin
    for v_row in
        select id, hire_date from public.profiles where is_active = true
    loop
        perform public.ensure_leave_balance_row(v_row.id, p_year);
    end loop;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Training content, quizzes and access rules (migrations 0038 / 0039)
-- ─────────────────────────────────────────────────────────────────────────

create table if not exists public.training_lessons (
    id          bigint generated always as identity primary key,
    program_id  bigint not null references public.training_programs(id) on delete cascade,
    sort_order  integer not null default 0,
    title       text not null,
    body        text not null default '',
    media_url   text, -- optional image / video / PDF link
    created_at  timestamptz not null default now()
);

create table if not exists public.training_questions (
    id            bigint generated always as identity primary key,
    program_id    bigint not null references public.training_programs(id) on delete cascade,
    sort_order    integer not null default 0,
    question      text not null,
    options       text[] not null,
    correct_index integer not null,
    explanation   text,
    created_at    timestamptz not null default now(),
    constraint training_questions_options_check check (array_length(options, 1) between 2 and 6),
    constraint training_questions_correct_check check (correct_index >= 0 and correct_index < array_length(options, 1))
);

create table if not exists public.training_lesson_completions (
    id            bigint generated always as identity primary key,
    enrollment_id bigint not null references public.training_enrollments(id) on delete cascade,
    lesson_id     bigint not null references public.training_lessons(id) on delete cascade,
    completed_at  timestamptz not null default now(),
    unique (enrollment_id, lesson_id)
);

create table if not exists public.training_attempts (
    id            bigint generated always as identity primary key,
    enrollment_id bigint not null references public.training_enrollments(id) on delete cascade,
    user_id       uuid not null references public.profiles(id) on delete cascade,
    score         numeric(5, 2) not null,
    passed        boolean not null,
    created_at    timestamptz not null default now()
);

alter table public.training_lessons enable row level security;
alter table public.training_questions enable row level security;
alter table public.training_lesson_completions enable row level security;
alter table public.training_attempts enable row level security;

drop policy if exists "training_lessons_select_authenticated" on public.training_lessons;
create policy "training_lessons_select_authenticated" on public.training_lessons
    for select using (auth.role() = 'authenticated');
drop policy if exists "training_lessons_write_hr" on public.training_lessons;
create policy "training_lessons_write_hr" on public.training_lessons
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- HR-only: this table holds the answers.
drop policy if exists "training_questions_all_hr" on public.training_questions;
create policy "training_questions_all_hr" on public.training_questions
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

drop policy if exists "training_completions_select_own_or_hr" on public.training_lesson_completions;
create policy "training_completions_select_own_or_hr" on public.training_lesson_completions
    for select using (
        public.is_hr_admin()
        or exists (select 1 from public.training_enrollments e where e.id = enrollment_id and e.user_id = auth.uid())
    );

drop policy if exists "training_attempts_select_own_or_hr" on public.training_attempts;
create policy "training_attempts_select_own_or_hr" on public.training_attempts
    for select using (user_id = auth.uid() or public.is_hr_admin());
-- No insert/update policies on completions or attempts: only the
-- security-definer functions below write them.

-- Recomputes an enrollment's progress from lessons read + quiz passed.
-- Internal: called only by the functions below.
create or replace function public.recompute_training_progress(p_enrollment_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_program bigint;
    v_lessons int;
    v_done int;
    v_has_quiz boolean;
    v_passed boolean;
    v_steps int;
    v_finished int;
begin
    perform set_config('app.training_rpc', '1', true);
    select program_id into v_program from public.training_enrollments where id = p_enrollment_id;
    if v_program is null then return; end if;

    select count(*) into v_lessons from public.training_lessons where program_id = v_program;
    select count(*) into v_done
        from public.training_lesson_completions c
        join public.training_lessons l on l.id = c.lesson_id
        where c.enrollment_id = p_enrollment_id and l.program_id = v_program;
    select exists (select 1 from public.training_questions where program_id = v_program) into v_has_quiz;
    select exists (select 1 from public.training_attempts where enrollment_id = p_enrollment_id and passed) into v_passed;

    v_steps := v_lessons + (case when v_has_quiz then 1 else 0 end);
    if v_steps = 0 then return; end if;
    v_finished := v_done + (case when v_has_quiz and v_passed then 1 else 0 end);

    update public.training_enrollments
    set progress = least(v_finished::numeric / v_steps, 1.0),
        is_completed = is_completed or v_finished >= v_steps,
        completed_at = coalesce(completed_at, case when v_finished >= v_steps then now() end)
    where id = p_enrollment_id;
end;
$$;
revoke all on function public.recompute_training_progress(bigint) from public, anon, authenticated;

create or replace function public.complete_training_lesson(p_lesson_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_program bigint;
    v_enrollment bigint;
begin
    perform set_config('app.training_rpc', '1', true);
    select program_id into v_program from public.training_lessons where id = p_lesson_id;
    if v_program is null then raise exception 'Lesson not found.'; end if;
    select id into v_enrollment from public.training_enrollments
        where program_id = v_program and user_id = auth.uid();
    if v_enrollment is null then raise exception 'Enrol in this programme before marking lessons as read.'; end if;

    insert into public.training_lesson_completions (enrollment_id, lesson_id)
    values (v_enrollment, p_lesson_id)
    on conflict (enrollment_id, lesson_id) do nothing;
    perform public.recompute_training_progress(v_enrollment);
end;
$$;

-- Question count + pass mark, visible to anyone (so the detail screen can say
-- "includes a 5-question quiz") without exposing the questions themselves.
create or replace function public.training_quiz_info(p_program_id bigint)
returns table (question_count int, pass_mark int)
language sql
security definer
set search_path = public
stable
as $$
    select (select count(*)::int from public.training_questions where program_id = p_program_id),
           (select pass_mark from public.training_programs where id = p_program_id);
$$;

-- The quiz as the learner sees it: no correct_index, no explanation.
create or replace function public.get_quiz_questions(p_program_id bigint)
returns table (id bigint, sort_order int, question text, options text[])
language plpgsql
security definer
set search_path = public
stable
as $$
begin
    if not public.is_hr_admin() and not exists (
        select 1 from public.training_enrollments e where e.program_id = p_program_id and e.user_id = auth.uid()
    ) then
        raise exception 'Enrol in this programme to take its quiz.';
    end if;
    return query
        select q.id, q.sort_order, q.question, q.options
        from public.training_questions q
        where q.program_id = p_program_id
        order by q.sort_order, q.id;
end;
$$;

-- Grades server-side. p_answers[i] is the 0-based option index chosen for the
-- i-th question in sort order. Returns the score plus a per-question review
-- (correct answer + explanation) — revealed only after submitting.
create or replace function public.submit_training_quiz(p_program_id bigint, p_answers int[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_enrollment bigint;
    v_pass_mark int;
    v_total int;
    v_correct int := 0;
    v_results jsonb := '[]'::jsonb;
    v_i int := 0;
    v_ans int;
    v_ok boolean;
    v_score numeric(5, 2);
    v_passed boolean;
    q record;
begin
    perform set_config('app.training_rpc', '1', true);
    select id into v_enrollment from public.training_enrollments
        where program_id = p_program_id and user_id = v_uid;
    if v_enrollment is null then raise exception 'Enrol in this programme before taking its quiz.'; end if;

    select pass_mark into v_pass_mark from public.training_programs where id = p_program_id;
    select count(*) into v_total from public.training_questions where program_id = p_program_id;
    if v_total = 0 then raise exception 'This programme has no quiz.'; end if;
    if coalesce(array_length(p_answers, 1), 0) <> v_total then
        raise exception 'Answer every question before submitting.';
    end if;

    for q in
        select * from public.training_questions where program_id = p_program_id order by sort_order, id
    loop
        v_i := v_i + 1;
        v_ans := p_answers[v_i];
        v_ok := coalesce(v_ans = q.correct_index, false);
        if v_ok then v_correct := v_correct + 1; end if;
        v_results := v_results || jsonb_build_array(jsonb_build_object(
            'question_id', q.id,
            'correct', v_ok,
            'correct_index', q.correct_index,
            'explanation', q.explanation
        ));
    end loop;

    v_score := round(v_correct * 100.0 / v_total, 2);
    v_passed := v_score >= v_pass_mark;

    insert into public.training_attempts (enrollment_id, user_id, score, passed)
    values (v_enrollment, v_uid, v_score, v_passed);

    -- Best attempt counts, so a retake can only improve the recorded score.
    update public.training_enrollments
    set performance_score = greatest(coalesce(performance_score, 0), v_score)
    where id = v_enrollment;

    perform public.recompute_training_progress(v_enrollment);

    return jsonb_build_object(
        'score', v_score,
        'passed', v_passed,
        'correct', v_correct,
        'total', v_total,
        'pass_mark', v_pass_mark,
        'results', v_results
    );
end;
$$;

-- Once a programme has lessons or a quiz, an employee can't set their own
-- progress/completion/score directly through the API — only the functions
-- above (which set app.training_rpc) or HR can. Programmes with no content
-- keep the old self-reported progress.
create or replace function public.guard_training_enrollment_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.is_hr_admin() or coalesce(current_setting('app.training_rpc', true), '') = '1' then
        return new;
    end if;
    if (new.progress is distinct from old.progress
        or new.is_completed is distinct from old.is_completed
        or new.performance_score is distinct from old.performance_score
        or new.completed_at is distinct from old.completed_at)
       and (exists (select 1 from public.training_lessons where program_id = new.program_id)
            or exists (select 1 from public.training_questions where program_id = new.program_id)) then
        raise exception 'Progress on this programme is tracked automatically through its lessons and quiz.';
    end if;
    return new;
end;
$$;

drop trigger if exists trg_guard_training_enrollment_update on public.training_enrollments;
create trigger trg_guard_training_enrollment_update
    before update on public.training_enrollments
    for each row
    execute function public.guard_training_enrollment_update();

create or replace function public.tenure_months(p_hire_date date)
returns int
language sql
immutable
as $$
    select (extract(year from age(current_date, p_hire_date)) * 12
          + extract(month from age(current_date, p_hire_date)))::int;
$$;

-- Exemptions from mandatory programmes (FR9.6), withdrawing from an optional
-- programme (FR9.5) and reverting a violation with its risk points
-- (FR3.6) — migration 0043.
create table public.training_exemptions (
    id             bigint generated always as identity primary key,
    program_id     bigint not null references public.training_programs(id) on delete cascade,
    user_id        uuid references public.profiles(id) on delete cascade,      -- one employee ...
    department_id  bigint references public.departments(id) on delete cascade, -- ... or a whole department
    created_by     uuid references public.profiles(id) on delete set null,
    created_at     timestamptz not null default now(),
    constraint training_exemptions_target_check check (num_nonnulls(user_id, department_id) = 1),
    unique (program_id, user_id),
    unique (program_id, department_id)
);

alter table public.training_exemptions enable row level security;

create policy "training_exemptions_select_own_or_hr" on public.training_exemptions
    for select using (
        public.is_hr_admin()
        or user_id = auth.uid()
        or department_id = (select p.department_id from public.profiles p where p.id = auth.uid())
    );
create policy "training_exemptions_write_hr" on public.training_exemptions
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- Is this programme mandatory for this employee right now? Mandatory,
-- meant for their department (or everyone), and not exempted.
create or replace function public.is_training_mandatory_for(p_user uuid, p_program bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.training_programs tp
        join public.profiles pr on pr.id = p_user
        where tp.id = p_program
          and tp.is_mandatory
          and (tp.department_id is null or tp.department_id = pr.department_id)
          and not exists (
              select 1 from public.training_exemptions x
              where x.program_id = tp.id
                and (x.user_id = p_user or x.department_id = pr.department_id))
    );
$$;

-- A withdrawn recommendation is remembered here so the daily sweep doesn't
-- recommend the same programme again.
create table public.training_dismissals (
    user_id       uuid not null references public.profiles(id) on delete cascade,
    program_id    bigint not null references public.training_programs(id) on delete cascade,
    dismissed_at  timestamptz not null default now(),
    primary key (user_id, program_id)
);

alter table public.training_dismissals enable row level security;

create policy "training_dismissals_select_own_or_hr" on public.training_dismissals
    for select using (user_id = auth.uid() or public.is_hr_admin());
-- Written only by withdraw_from_training() below.

create or replace function public.withdraw_from_training(p_program_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    e record;
begin
    select * into e from public.training_enrollments
    where program_id = p_program_id and user_id = v_uid;
    if not found then
        raise exception 'You are not enrolled in this programme.';
    end if;
    if public.is_training_mandatory_for(v_uid, p_program_id) then
        raise exception 'Mandatory programmes can''t be withdrawn from. Ask HR if it doesn''t apply to you.';
    end if;
    if e.is_completed or e.progress > 0
       or exists (select 1 from public.training_lesson_completions where enrollment_id = e.id)
       or exists (select 1 from public.training_attempts where enrollment_id = e.id) then
        raise exception 'You can only withdraw before you start the programme.';
    end if;

    if e.is_recommended then
        insert into public.training_dismissals (user_id, program_id)
        values (v_uid, p_program_id)
        on conflict do nothing;
    end if;
    delete from public.training_enrollments where id = e.id;
end;
$$;
grant execute on function public.withdraw_from_training(bigint) to authenticated;

-- Unexplained-absence appeals (migration 0044).
create or replace function public.malaysia_today()
returns date
language sql
stable
as $$
    select (now() at time zone 'Asia/Kuala_Lumpur')::date;
$$;

-- Can HR still excuse this absence? Within 7 days of it, or later if the
-- employee appealed inside those 7 days and the appeal is still open.
create or replace function public.absence_revert_allowed(p_event_date date, p_appeal_status text, p_appealed_at timestamptz)
returns boolean
language sql
stable
as $$
    select p_event_date >= public.malaysia_today() - 7
        or coalesce(p_appeal_status = 'pending'
                    and (p_appealed_at at time zone 'Asia/Kuala_Lumpur')::date <= p_event_date + 7, false);
$$;

-- The signed-in employee's recent absence flags (employees can't read
-- anomaly_events directly).
create or replace function public.my_absence_flags()
returns table (
    id bigint,
    event_date date,
    details text,
    appeal_reason text,
    appeal_status text,
    appeal_response text,
    excused boolean,
    appeal_deadline date,
    can_appeal boolean
)
language sql
stable
security definer
set search_path = public
as $$
    select a.id, a.event_date, a.details, a.appeal_reason, a.appeal_status, a.appeal_response,
           a.reverted_at is not null,
           a.event_date + 7,
           a.reverted_at is null and a.appeal_status is null and a.event_date >= public.malaysia_today() - 7
    from public.anomaly_events a
    where a.user_id = auth.uid()
      and a.type = 'unexplained_absence'
      and a.event_date >= public.malaysia_today() - 60
    order by a.event_date desc;
$$;
grant execute on function public.my_absence_flags() to authenticated;

create or replace function public.appeal_absence(p_anomaly_id bigint, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    a record;
    v_name text;
begin
    select * into a from public.anomaly_events where id = p_anomaly_id for update;
    if not found or a.user_id is distinct from auth.uid() or a.type <> 'unexplained_absence' then
        raise exception 'Absence not found.';
    end if;
    if a.reverted_at is not null then
        raise exception 'This absence has already been excused.';
    end if;
    if a.appeal_status is not null then
        raise exception 'You have already appealed this absence.';
    end if;
    if a.event_date < public.malaysia_today() - 7 then
        raise exception 'Appeals must be made within 7 days of the absence.';
    end if;
    if length(trim(coalesce(p_reason, ''))) < 10 then
        raise exception 'Please explain the reason in at least 10 characters.';
    end if;

    update public.anomaly_events
    set appeal_reason = trim(p_reason), appealed_at = now(), appeal_status = 'pending'
    where id = a.id;

    select name into v_name from public.profiles where id = a.user_id;
    insert into public.notifications (user_id, title, body, type)
    select p.id, 'Absence Appeal',
           format('%s appealed the unexplained absence on %s: "%s"', v_name, to_char(a.event_date, 'DD Mon YYYY'), trim(p_reason))
           || E'\n\nNext steps:\n1. Go to Analytics → Anomaly & Violation Feed\n2. Excuse the absence or reject the appeal',
           'anomaly'
    from public.profiles p
    where p.user_role = 'hr_admin' and p.is_active and p.id <> a.user_id;
end;
$$;
grant execute on function public.appeal_absence(bigint, text) to authenticated;

create or replace function public.reject_absence_appeal(p_anomaly_id bigint, p_response text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    a record;
begin
    if not public.is_hr_admin() then
        raise exception 'Only HR admins can decide on an appeal.';
    end if;
    select * into a from public.anomaly_events where id = p_anomaly_id for update;
    if not found then
        raise exception 'Violation not found.';
    end if;
    if a.user_id = auth.uid() then
        raise exception 'You cannot decide on your own appeal. Ask another HR admin to review it.';
    end if;
    if a.appeal_status is distinct from 'pending' then
        raise exception 'There is no open appeal on this absence.';
    end if;

    update public.anomaly_events
    set appeal_status = 'rejected', appeal_response = nullif(trim(coalesce(p_response, '')), ''),
        appeal_decided_at = now(), reviewed = true, reviewed_by = auth.uid(), reviewed_at = now()
    where id = a.id;

    insert into public.notifications (user_id, title, body, type)
    values (a.user_id, 'Absence Appeal Not Accepted',
            format('HR did not accept your appeal for the absence on %s.', to_char(a.event_date, 'DD Mon YYYY'))
            || coalesce(E'\n\nHR\'s note: ' || nullif(trim(coalesce(p_response, '')), ''), ''),
            'anomaly');
end;
$$;
grant execute on function public.reject_absence_appeal(bigint, text) to authenticated;

-- Returns how many risk points were given back. Points are only restored
-- if the violation still counts towards the current risk period — once
-- the score has reset, there is nothing left to give back.
create or replace function public.revert_violation(p_anomaly_id bigint)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    a record;
    prof record;
    pol record;
    v_weight numeric;
    v_restored integer := 0;
    v_score integer;
    v_absence boolean;
begin
    if not public.is_hr_admin() then
        raise exception 'Only HR admins can revert a violation.';
    end if;
    select * into a from public.anomaly_events where id = p_anomaly_id for update;
    if not found then
        raise exception 'Violation not found.';
    end if;
    if a.user_id = auth.uid() then
        raise exception 'You cannot revert your own violation. Ask another HR admin to review it.';
    end if;
    if a.reverted_at is not null then
        raise exception 'This violation has already been reverted.';
    end if;
    v_absence := a.type = 'unexplained_absence';
    if v_absence and not public.absence_revert_allowed(a.event_date, a.appeal_status, a.appealed_at) then
        raise exception 'Absences can only be excused within 7 days, unless the employee appealed within that time.';
    end if;

    if a.attendance_record_id is not null then
        update public.attendance_records
        set status = 'on_time', flag_reason = null
        where id = a.attendance_record_id;
    end if;

    select * into pol from public.policy_settings where id = 1;
    v_weight := case a.type
        when 'late'                then pol.late_weight
        when 'out_of_zone'         then pol.out_of_zone_weight
        when 'shared_device'       then pol.shared_device_weight
        when 'wifi_mismatch'       then pol.wifi_mismatch_weight
        when 'early_clockout'      then pol.early_clockout_weight
        when 'unexplained_absence' then pol.unexplained_absence_weight
        else 0
    end;

    select * into prof from public.profiles where id = a.user_id for update;
    if a.created_at >= prof.risk_period_start and prof.risk_score < 100 then
        v_score := least(100, prof.risk_score + round(v_weight)::int);
        v_restored := v_score - prof.risk_score;
        update public.profiles
        set risk_score = v_score,
            risk_level = case when v_score >= 80 then 'low' when v_score >= 50 then 'medium' else 'high' end
        where id = a.user_id;
    end if;

    update public.anomaly_events
    set reviewed = true, reviewed_by = auth.uid(), reviewed_at = now(), reverted_at = now(),
        appeal_status = case when appeal_status = 'pending' then 'accepted' else appeal_status end,
        appeal_decided_at = case when appeal_status = 'pending' then now() else appeal_decided_at end
    where id = a.id;

    insert into public.notifications (user_id, title, body, type)
    values (a.user_id,
            case when v_absence then 'Absence Excused' else 'Attendance Flag Reverted' end,
            case when v_absence
                 then format('HR excused your absence on %s. It will not be deducted from your pay. ', to_char(a.event_date, 'DD Mon YYYY'))
                 else format('HR reviewed the flag on your attendance for %s and found it invalid. ', to_char(a.event_date, 'DD Mon YYYY'))
            end
            || case when v_restored > 0 then format('%s risk points have been given back.', v_restored)
                    else 'Your risk score had already reset since then, so no points needed to be given back.' end,
            'anomaly');

    return v_restored;
end;
$$;
grant execute on function public.revert_violation(bigint) to authenticated;

-- Training certificates (migration 0041): issued by the database when an
-- enrolment is completed; name/title are snapshots so a certificate
-- outlives later renames or deletion of the programme.
create table public.training_certificates (
    id              bigint generated always as identity primary key,
    certificate_no  text not null unique,           -- e.g. MON-2026-00042
    enrollment_id   bigint unique references public.training_enrollments(id) on delete set null,
    user_id         uuid not null references public.profiles(id) on delete cascade,
    program_id      bigint references public.training_programs(id) on delete set null,
    employee_name   text not null,
    program_title   text not null,
    category        text not null,
    score           numeric(5, 2),                   -- null when the programme has no quiz and HR hasn't scored it
    issued_at       timestamptz not null default now()
);

alter table public.training_certificates enable row level security;

create policy "training_certificates_select_own_or_hr" on public.training_certificates
    for select using (user_id = auth.uid() or public.is_hr_admin());
-- No insert/update/delete policies: only the trigger below writes here.

-- Number = MON-<year issued, Malaysia time>-<id padded to 5 digits>.
create or replace function public.set_certificate_no()
returns trigger
language plpgsql
as $$
begin
    new.certificate_no := 'MON-' || to_char(new.issued_at at time zone 'Asia/Kuala_Lumpur', 'YYYY')
                       || '-' || lpad(new.id::text, 5, '0');
    return new;
end;
$$;

create trigger trg_set_certificate_no
    before insert on public.training_certificates
    for each row
    execute function public.set_certificate_no();

create or replace function public.issue_training_certificate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_no text;
    v_title text;
begin
    if new.is_completed and (tg_op = 'INSERT' or not old.is_completed) then
        insert into public.training_certificates
            (enrollment_id, user_id, program_id, employee_name, program_title, category, score, issued_at, certificate_no)
        select new.id, new.user_id, new.program_id, pr.name, p.title, p.category, new.performance_score,
               coalesce(new.completed_at, now()), ''
        from public.training_programs p
        join public.profiles pr on pr.id = new.user_id
        where p.id = new.program_id
        on conflict (enrollment_id) do nothing
        returning certificate_no, program_title into v_no, v_title;

        if v_no is not null then
            insert into public.notifications (user_id, title, body, type)
            values (new.user_id, 'Certificate Earned',
                    format('You completed "%s" and earned certificate %s. View it under Training → My Certificates.', v_title, v_no),
                    'training');
        end if;
    elsif tg_op = 'UPDATE' and new.performance_score is distinct from old.performance_score then
        update public.training_certificates
        set score = new.performance_score
        where enrollment_id = new.id;
    end if;
    return new;
end;
$$;

create trigger trg_issue_training_certificate
    after insert or update of is_completed, performance_score on public.training_enrollments
    for each row
    execute function public.issue_training_certificate();

-- ML training recommender (FR9.2). The model is trained offline (ml/train.py)
-- and uploaded into training_ml_models by ml/output/model_upload.sql; it is
-- scored here with plain arithmetic, so there is no model server.
-- ── Model storage ──────────────────────────────────────────────────────
create table public.training_ml_models (
    id              bigint generated always as identity primary key,
    version         text not null unique,
    trained_at      timestamptz not null,
    algorithm       text not null,
    features        text[] not null,      -- input order the coefficients use
    means           float8[] not null,    -- standardisation: z = (x - mean) / scale, missing -> 0
    scales          float8[] not null,
    classes         text[] not null,      -- output order: technical, behavioural, leadership
    coef            float8[] not null,    -- [class][feature]
    intercept       float8[] not null,    -- [class]
    metrics         jsonb not null default '{}'::jsonb,
    min_confidence  numeric(4, 2) not null default 0.65, -- below this the prediction is shown but not acted on
    is_active       boolean not null default false,
    uploaded_at     timestamptz not null default now()
);

create unique index training_ml_models_one_active
    on public.training_ml_models (is_active) where is_active;

alter table public.training_ml_models enable row level security;

create policy "HR can view training models"
    on public.training_ml_models for select
    to authenticated
    using (public.is_hr_admin());

-- ── Shared: 90-day attendance rate ─────────────────────────────────────
-- Same expected-day rules as payroll (weekdays, minus public holidays and
-- approved leave). Null until there are at least 10 expected days, so a
-- new hire isn't treated as absent.
create or replace function public.attendance_rate_90d(p_user uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = public
set timezone = 'Asia/Kuala_Lumpur'
as $$
declare
    v_hire date;
    v_from date;
    v_to date := current_date - 1;
    v_expected int;
    v_present int;
begin
    select hire_date into v_hire from public.profiles where id = p_user;
    if not found then return null; end if;
    v_from := greatest(v_hire, current_date - 90);

    select count(*) filter (where is_workday),
           count(*) filter (where is_workday and attended)
    into v_expected, v_present
    from (
        select
            (extract(isodow from d) < 6
                and not exists (
                    select 1 from public.company_events ce
                    where ce.event_type = 'public_holiday'
                      and (ce.event_date at time zone 'Asia/Kuala_Lumpur')::date = d::date)
                and not exists (
                    select 1 from public.leave_applications la
                    where la.user_id = p_user and la.status = 'approved'
                      and d::date between la.start_date and la.end_date)
                and not exists ( -- an absence HR excused after an appeal
                    select 1 from public.anomaly_events ae
                    where ae.user_id = p_user and ae.type = 'unexplained_absence'
                      and ae.reverted_at is not null and ae.event_date = d::date)
            ) as is_workday,
            exists (
                select 1 from public.attendance_records ar
                where ar.user_id = p_user and ar.work_date = d::date) as attended
        from generate_series(v_from, v_to, interval '1 day') as d
    ) x;

    return case when v_expected >= 10 then round(v_present * 100.0 / v_expected, 1) end;
end;
$$;
revoke all on function public.attendance_rate_90d(uuid) from public, anon, authenticated;

-- ── Model inputs (names must match ml/features.py) ─────────────────────
create or replace function public.ml_employee_features(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_profile record;
    v_on_time int;
    v_late int;
    v_eval_id bigint;
    v_pe jsonb := '{}'::jsonb;
    v_completed int;
    v_avg_score numeric;
begin
    select hire_date, risk_score into v_profile from public.profiles where id = p_user;
    if not found then return null; end if;

    select count(*) filter (where status = 'on_time'),
           count(*) filter (where status = 'late')
    into v_on_time, v_late
    from public.attendance_records
    where user_id = p_user and work_date >= current_date - 90;

    select id into v_eval_id
    from public.performance_evaluations
    where user_id = p_user and not is_draft
    order by year desc
    limit 1;

    if v_eval_id is not null then
        select coalesce(jsonb_object_agg('pe_' || cat, avg_score), '{}'::jsonb) into v_pe
        from (
            select lower(category) as cat,
                   round(sum(score * weightage) / nullif(sum(weightage), 0), 1) as avg_score
            from public.performance_evaluation_scores
            where evaluation_id = v_eval_id
            group by lower(category)
        ) s;
    end if;

    select count(*) filter (where is_completed),
           round(avg(performance_score) filter (where is_completed and performance_score is not null), 1)
    into v_completed, v_avg_score
    from public.training_enrollments
    where user_id = p_user;

    return jsonb_build_object(
        'tenure_months', public.tenure_months(v_profile.hire_date),
        'attendance_rate', public.attendance_rate_90d(p_user),
        'punctuality_rate', case when v_on_time + v_late >= 5
                                 then round(v_on_time * 100.0 / (v_on_time + v_late), 1) end,
        'risk_score', v_profile.risk_score,
        'pe_technical', v_pe -> 'pe_technical',
        'pe_behavioural', v_pe -> 'pe_behavioural',
        'pe_leadership', v_pe -> 'pe_leadership',
        'trainings_completed', v_completed,
        'avg_training_score', v_avg_score
    );
end;
$$;
revoke all on function public.ml_employee_features(uuid) from public, anon, authenticated;

-- ── Scorer: softmax(intercept + coef · z) ──────────────────────────────
-- Also returns the top factors behind the winning area: each feature's
-- pull towards that area relative to the average pull across all areas,
-- keeping only the ones that pushed it up.
create or replace function public.ml_score_features(p_model_id bigint, p_features jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    m public.training_ml_models;
    n int;
    k int;
    v float8;
    z float8[] := '{}';
    logits float8[] := '{}';
    probs float8[] := '{}';
    l float8;
    max_l float8;
    total float8 := 0;
    best int := 1;
    avg_pull float8;
    factors jsonb := '[]'::jsonb;
    probabilities jsonb := '{}'::jsonb;
begin
    select * into m from public.training_ml_models where id = p_model_id;
    if not found then return null; end if;
    n := array_length(m.features, 1);
    k := array_length(m.classes, 1);

    for j in 1..n loop
        v := (p_features ->> m.features[j])::float8;
        z[j] := case when v is null then 0 else (v - m.means[j]) / m.scales[j] end;
    end loop;

    for c in 1..k loop
        l := m.intercept[c];
        for j in 1..n loop
            l := l + m.coef[c][j] * z[j];
        end loop;
        logits[c] := l;
        if c = 1 or l > max_l then max_l := l; end if;
    end loop;

    for c in 1..k loop
        probs[c] := exp(logits[c] - max_l);
        total := total + probs[c];
    end loop;
    for c in 1..k loop
        probs[c] := probs[c] / total;
        probabilities := probabilities || jsonb_build_object(m.classes[c], probs[c]);
        if probs[c] > probs[best] then best := c; end if;
    end loop;

    select coalesce(jsonb_agg(f order by (f ->> 'contribution')::float8 desc), '[]'::jsonb) into factors
    from (
        select f
        from (
            select jsonb_build_object(
                       'feature', m.features[j],
                       'value', p_features -> m.features[j],
                       'z', z[j],
                       'contribution', m.coef[best][j] * z[j]
                           - (select avg(m.coef[c][j] * z[j]) from generate_series(1, k) as c)
                   ) as f
            from generate_series(1, n) as j
        ) x
        where (f ->> 'contribution')::float8 > 0.05
        order by (f ->> 'contribution')::float8 desc
        limit 3
    ) y;

    return jsonb_build_object(
        'category', m.classes[best],
        'confidence', probs[best],
        'probabilities', probabilities,
        'top_factors', factors,
        'model_version', m.version,
        'model_accuracy', m.metrics -> 'test_accuracy',
        'min_confidence', m.min_confidence
    );
end;
$$;
revoke all on function public.ml_score_features(bigint, jsonb) from public, anon, authenticated;

-- ── What the HR screen calls ───────────────────────────────────────────
-- HR can ask about anyone; an employee only about themselves. Returns
-- null when no model has been uploaded yet.
create or replace function public.ml_predict_training_category(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_model_id bigint;
    v_features jsonb;
begin
    if p_user is distinct from auth.uid() and not public.is_hr_admin() then
        raise exception 'You can only view your own training insight.';
    end if;

    select id into v_model_id from public.training_ml_models where is_active;
    if v_model_id is null then return null; end if;

    v_features := public.ml_employee_features(p_user);
    if v_features is null then return null; end if;

    return public.ml_score_features(v_model_id, v_features)
        || jsonb_build_object('features', v_features);
end;
$$;
grant execute on function public.ml_predict_training_category(uuid) to authenticated;

-- ── Daily sweep, now with the ML step ──────────────────────────────────
-- 1. Behaviour rules (unchanged from 0039).
-- 2. If a model is active, its confidence clears the model's threshold and
--    the employee has no unfinished ML recommendation already, enrol them
--    in one programme from the predicted area: a recommendation-only
--    programme without a behaviour trigger first, else an open one.
create or replace function public.refresh_training_recommendations_for(p_user uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
    v_profile record;
    v_tenure int;
    v_rate numeric;
    v_added int := 0;
    v_reason text;
    v_model_id bigint;
    v_pred jsonb;
    v_category text;
    v_confidence float8;
    prog record;
begin
    perform set_config('app.training_rpc', '1', true);

    select hire_date, risk_level, department_id into v_profile from public.profiles where id = p_user and is_active;
    if not found then return 0; end if;

    v_tenure := public.tenure_months(v_profile.hire_date);
    v_rate := public.attendance_rate_90d(p_user);

    for prog in
        select * from public.training_programs p
        where (p.trigger_risk_level is not null or p.trigger_attendance_below is not null)
          and p.min_tenure_months <= v_tenure
          and (p.department_id is null or p.department_id = v_profile.department_id)
          and not exists (
              select 1 from public.training_dismissals d
              where d.program_id = p.id and d.user_id = p_user)
          and not exists (
              select 1 from public.training_enrollments e
              where e.program_id = p.id and e.user_id = p_user)
    loop
        v_reason := null;
        if prog.trigger_risk_level = 'high' and v_profile.risk_level = 'high' then
            v_reason := 'Recommended because your risk classification is High.';
        elsif prog.trigger_risk_level = 'medium' and v_profile.risk_level in ('medium', 'high') then
            v_reason := 'Recommended because your risk classification is ' || initcap(v_profile.risk_level) || '.';
        elsif prog.trigger_attendance_below is not null and v_rate is not null and v_rate < prog.trigger_attendance_below then
            v_reason := 'Recommended because your attendance over the last 90 days is ' || round(v_rate)::text
                     || '%, below the ' || prog.trigger_attendance_below::int::text || '% this programme targets.';
        end if;

        if v_reason is not null then
            insert into public.training_enrollments (program_id, user_id, is_recommended, recommendation_reason, progress, recommended_by)
            values (prog.id, p_user, true, v_reason, 0, 'rule')
            on conflict (program_id, user_id) do nothing;
            v_added := v_added + 1;
        end if;
    end loop;

    select id into v_model_id from public.training_ml_models where is_active;
    if v_model_id is not null and not exists (
        select 1 from public.training_enrollments e
        where e.user_id = p_user and e.recommended_by = 'ml' and not e.is_completed
    ) then
        v_pred := public.ml_score_features(v_model_id, public.ml_employee_features(p_user));
        v_category := v_pred ->> 'category';
        v_confidence := (v_pred ->> 'confidence')::float8;

        if v_confidence >= (v_pred ->> 'min_confidence')::float8 then
            select * into prog
            from public.training_programs p
            where p.category = v_category
              and p.trigger_risk_level is null
              and p.trigger_attendance_below is null
              and p.min_tenure_months <= v_tenure
              and (p.department_id is null or p.department_id = v_profile.department_id)
              and not exists (
                  select 1 from public.training_dismissals d
                  where d.program_id = p.id and d.user_id = p_user)
              and not exists (
                  select 1 from public.training_enrollments e
                  where e.program_id = p.id and e.user_id = p_user)
            order by (p.access = 'recommended_only') desc, p.id
            limit 1;

            if found then
                insert into public.training_enrollments (program_id, user_id, is_recommended, recommendation_reason, progress, recommended_by)
                values (prog.id, p_user, true,
                        'Suggested by MONIKA''s training model: your recent records point to '
                            || v_category || ' skills as your best area to grow ('
                            || least(round((v_confidence * 100)::numeric), 99)::text || '% confidence).',
                        0, 'ml')
                on conflict (program_id, user_id) do nothing;
                v_added := v_added + 1;
            end if;
        end if;
    end if;

    return v_added;
end;
$$;
revoke all on function public.refresh_training_recommendations_for(uuid) from public, anon, authenticated;

-- What the app calls (for the signed-in employee) when they open Training.
create or replace function public.refresh_my_training_recommendations()
returns int
language sql
security definer
set search_path = public
as $$
    select public.refresh_training_recommendations_for(auth.uid());
$$;

-- Daily sweep so recommendations exist even if the employee hasn't opened
-- the Training tab (and HR's Completion view reflects who's been enrolled).
create or replace function public.refresh_all_training_recommendations()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    u uuid;
begin
    for u in select id from public.profiles where is_active loop
        perform public.refresh_training_recommendations_for(u);
    end loop;
end;
$$;
revoke all on function public.refresh_all_training_recommendations() from public, anon, authenticated;

-- 01:30 Malaysia time, after the absence and risk jobs above.
select cron.schedule('refresh-training-recommendations', '30 17 * * *', $$select public.refresh_all_training_recommendations();$$);

-- Measure "today", "yesterday" and "the last 90 days" in Malaysia time
-- whenever these run.
alter function public.tenure_months(date) set timezone = 'Asia/Kuala_Lumpur';
alter function public.ml_employee_features(uuid) set timezone = 'Asia/Kuala_Lumpur';
alter function public.ml_predict_training_category(uuid) set timezone = 'Asia/Kuala_Lumpur';
alter function public.refresh_training_recommendations_for(uuid) set timezone = 'Asia/Kuala_Lumpur';
alter function public.refresh_my_training_recommendations() set timezone = 'Asia/Kuala_Lumpur';
alter function public.refresh_all_training_recommendations() set timezone = 'Asia/Kuala_Lumpur';

-- Self-enrolment guard: employees can only enrol themselves in open
-- programmes they're tenure-eligible for. Recommendations (written by the
-- functions above, or by HR when a PE score triggers one) bypass this.
create or replace function public.guard_training_enrollment_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_access text;
    v_min int;
    v_hire date;
begin
    if public.is_hr_admin() or coalesce(current_setting('app.training_rpc', true), '') = '1' then
        return new;
    end if;
    select access, min_tenure_months into v_access, v_min
        from public.training_programs where id = new.program_id;
    if v_access = 'recommended_only' then
        raise exception 'This programme is only available when it is recommended to you.';
    end if;
    select hire_date into v_hire from public.profiles where id = new.user_id;
    if v_hire is not null and public.tenure_months(v_hire) < coalesce(v_min, 0) then
        raise exception 'This programme opens after % months of service.', v_min;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_guard_training_enrollment_insert on public.training_enrollments;
create trigger trg_guard_training_enrollment_insert
    before insert on public.training_enrollments
    for each row
    execute function public.guard_training_enrollment_insert();
