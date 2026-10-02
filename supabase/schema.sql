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
    type                  text not null check (type in ('out_of_zone', 'shared_device', 'late', 'wifi_mismatch', 'early_clockout', 'unexplained_absence')),
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
    check_date date := (now() - interval '1 day')::date;
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
          where ce.event_type = 'public_holiday' and ce.event_date = check_date
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
select cron.schedule('reset-stale-risk-scores', '0 2 * * *', $$select public.reset_stale_risk_scores();$$);
select cron.schedule('detect-unexplained-absences', '30 1 * * *', $$select public.detect_unexplained_absences();$$);

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

-- anomaly_events — HR-only (employees see their own flags via attendance_records.flag_reason instead)
create policy "anomaly_select_hr" on public.anomaly_events
    for select using (public.is_hr_admin());
create policy "anomaly_write_hr" on public.anomaly_events
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

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

-- policy_settings — HR-only, employees never read this directly (current UI
-- only ever displays these values on HR-facing screens)
create policy "policy_settings_all_hr" on public.policy_settings
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());
