-- Demo personas for presentations — NOT a schema migration.
--
-- Creates one HR account and five employees, each with a different story,
-- so every screen has something meaningful to show:
--
--   hannah@gmail.com  / hannah123   HR Executive — log in as HR for the demo
--   johnny@gmail.com  / johnny123   Senior Engineer, 5 yrs, excellent record,
--                                   strong technical review, weaker leadership
--                                   -> model suggests Leadership
--   sarah@gmail.com   / sarah123    Sales Executive, often late, a few
--                                   violations (Medium risk), low behavioural
--                                   review -> rule, review and model all point
--                                   to Behavioural training
--   kevin@gmail.com   / kevin123    Backend Engineer, 14 months, weak
--                                   technical review, failed a quiz twice
--                                   before passing (attempt history)
--   meiling@gmail.com / meiling123  Design Intern, joined last month, no
--                                   review yet (model fills the gaps)
--   daniel@gmail.com  / daniel123   Operations Manager, 7 yrs, strong across
--                                   the board, several certificates
--
-- Everything is dated relative to today, so it looks current whenever it
-- is run. Violations go through the real risk-scoring trigger, certificates
-- are issued by the real certificate trigger, and the real daily
-- recommendation sweep (rules + ML model, if one is uploaded) runs at the
-- end — nothing is faked after the fact.
--
-- Run order: the training catalogue (seed_training_catalog.sql) first, and
-- ideally ml/output/model_upload.sql too. Then paste this whole file into
-- the Supabase SQL Editor and Run. Running it again does nothing if the
-- demo accounts already exist; seed_demo_personas_cleanup.sql removes them.
--
-- Note: these are real-looking Gmail addresses. Editing a demo employee's
-- job title, department or salary in the app emails that address, so
-- avoid doing that during a demo.

create schema if not exists demo_seed;

-- n-th weekday before today (1 = the most recent one).
create or replace function demo_seed.wd(n int)
returns date language plpgsql as $$
declare
    d date := current_date;
    k int := 0;
begin
    while k < n loop
        d := d - 1;
        if extract(isodow from d) < 6 then k := k + 1; end if;
    end loop;
    return d;
end;
$$;

-- Repeatable 0..1 "random" number, so re-seeding gives the same data.
create or replace function demo_seed.rnd(p_user uuid, p_day date, p_salt text)
returns float8 language sql immutable as $$
    select (hashtext(p_user::text || p_day::text || p_salt) & 2147483647)::float8 / 2147483647;
$$;

create or replace function demo_seed.account(
    p_id uuid, p_email text, p_password text, p_name text, p_code text, p_role text,
    p_title text, p_dept text, p_initials text, p_hire date, p_salary numeric)
returns void language plpgsql as $$
begin
    insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change,
        email_change_token_current, reauthentication_token)
    values (
        '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email,
        extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
        '{"provider": "email", "providers": ["email"]}'::jsonb, '{}'::jsonb, now(), now(),
        '', '', '', '', '', '');

    insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (p_id::text, p_id,
            jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true, 'phone_verified', false),
            'email', now(), now(), now());

    insert into public.profiles (
        id, employee_code, name, email, user_role, job_title, department_id, avatar_initials,
        hire_date, base_salary, is_intern, must_change_password)
    values (
        p_id, p_code, p_name, p_email, p_role, p_title,
        (select id from public.departments where name = p_dept), p_initials,
        p_hire, p_salary, p_title = 'Intern', false);

    perform public.ensure_leave_balance_row(p_id, extract(year from current_date)::smallint);
end;
$$;

-- Weekday attendance from hire date (or 90 days back) to yesterday,
-- skipping public holidays and approved leave. Times are Malaysia time.
create or replace function demo_seed.attendance(p_user uuid, p_absent_rate float8, p_late_rate float8)
returns void language plpgsql as $$
declare
    v_hire date;
    d date;
    v_in timestamptz;
    v_status text;
begin
    select hire_date into v_hire from public.profiles where id = p_user;
    d := greatest(v_hire, current_date - 90);
    while d < current_date loop
        if extract(isodow from d) < 6
           and not exists (select 1 from public.company_events ce
                           where ce.event_type = 'public_holiday'
                             and (ce.event_date at time zone 'Asia/Kuala_Lumpur')::date = d)
           and not exists (select 1 from public.leave_applications la
                           where la.user_id = p_user and la.status = 'approved'
                             and d between la.start_date and la.end_date)
           and demo_seed.rnd(p_user, d, 'absent') >= p_absent_rate then
            if demo_seed.rnd(p_user, d, 'late') < p_late_rate then
                v_status := 'late';
                v_in := (d + time '09:12' + demo_seed.rnd(p_user, d, 'min') * interval '40 minutes') at time zone 'Asia/Kuala_Lumpur';
            else
                v_status := 'on_time';
                v_in := (d + time '08:38' + demo_seed.rnd(p_user, d, 'min') * interval '20 minutes') at time zone 'Asia/Kuala_Lumpur';
            end if;
            insert into public.attendance_records
                (user_id, work_date, clock_in_at, clock_out_at, status, flag_reason, gps_passed, wifi_passed, device_passed)
            values (p_user, d, v_in, v_in + interval '9 hours' + demo_seed.rnd(p_user, d, 'out') * interval '25 minutes',
                    v_status, case when v_status = 'late' then 'Clocked in after grace period' end, true, true, true)
            on conflict (user_id, work_date) do nothing;
        end if;
        d := d + 1;
    end loop;
end;
$$;

-- A violation on a given day, recorded the way the app records it, and
-- passed through the real risk-scoring trigger. Like the app, a late
-- arrival only becomes a violation from the 3rd one within 14 days.
create or replace function demo_seed.incident(p_user uuid, p_day date, p_type text)
returns void language plpgsql as $$
declare
    v_rec bigint;
    v_late int;
    v_in timestamptz := (p_day + time '09:31') at time zone 'Asia/Kuala_Lumpur';
begin
    if p_type = 'unexplained_absence' then
        delete from public.attendance_records where user_id = p_user and work_date = p_day;
        insert into public.anomaly_events (user_id, type, event_date, details, severity)
        values (p_user, p_type, p_day, 'No attendance record and no approved leave for ' || to_char(p_day, 'DD Mon YYYY'), 'medium');
        return;
    end if;

    insert into public.attendance_records
        (user_id, work_date, clock_in_at, clock_out_at, status, gps_passed, wifi_passed, device_passed)
    values (p_user, p_day, v_in, v_in + interval '9 hours', 'on_time', true, true, true)
    on conflict (user_id, work_date) do nothing;

    if p_type = 'late' then
        update public.attendance_records
        set status = 'late', flag_reason = 'Clocked in after grace period', clock_in_at = v_in, clock_out_at = v_in + interval '9 hours'
        where user_id = p_user and work_date = p_day
        returning id into v_rec;
        select count(*) into v_late from public.attendance_records
        where user_id = p_user and status = 'late' and work_date between p_day - 13 and p_day;
        if v_late < 3 then return; end if;
        insert into public.anomaly_events (user_id, attendance_record_id, type, event_date, details, severity)
        values (p_user, v_rec, 'late', p_day,
                v_late || case when v_late % 100 between 11 and 13 then 'th'
                               when v_late % 10 = 1 then 'st' when v_late % 10 = 2 then 'nd'
                               when v_late % 10 = 3 then 'rd' else 'th' end
                       || ' late arrival in the past 14 days', 'medium');
    elsif p_type = 'wifi_mismatch' then
        update public.attendance_records
        set status = 'flagged', flag_reason = 'Not connected to the office WiFi', wifi_passed = false, wifi_ssid = 'Starbucks_Guest'
        where user_id = p_user and work_date = p_day
        returning id into v_rec;
        insert into public.anomaly_events (user_id, attendance_record_id, type, event_date, details, severity)
        values (p_user, v_rec, p_type, p_day, 'Connected to "Starbucks_Guest" instead of the registered office network', 'low');
    elsif p_type = 'out_of_zone' then
        update public.attendance_records
        set status = 'flagged', flag_reason = 'GPS outside geofence radius', gps_passed = false
        where user_id = p_user and work_date = p_day
        returning id into v_rec;
        insert into public.anomaly_events (user_id, attendance_record_id, type, event_date, details, severity)
        values (p_user, v_rec, p_type, p_day, 'GPS coordinates outside the configured geofence radius', 'medium');
    end if;
end;
$$;

create or replace function demo_seed.leave(
    p_user uuid, p_code text, p_type text, p_start date, p_end date, p_reason text, p_status text, p_hr uuid)
returns void language plpgsql as $$
declare
    v_days int;
begin
    select count(*) into v_days from generate_series(p_start, p_end, interval '1 day') d where extract(isodow from d) < 6;
    insert into public.leave_applications
        (reference_code, user_id, leave_type, start_date, end_date, days, reason, status, decided_by, decided_at, created_at)
    values (p_code, p_user, p_type, p_start, p_end, v_days, p_reason, p_status,
            case when p_status <> 'pending' then p_hr end,
            case when p_status <> 'pending' then (p_start - 5)::timestamptz end,
            (p_start - 7)::timestamptz);
    if p_status = 'approved' and extract(year from p_start) = extract(year from current_date) then
        execute format('update public.leave_balances set %I = %I + $1 where user_id = $2 and year = $3',
                       p_type || '_used', p_type || '_used')
        using v_days, p_user, extract(year from current_date)::smallint;
    end if;
end;
$$;

create or replace function demo_seed.template(p_name text, p_dept text, p_items jsonb)
returns void language plpgsql as $$
declare
    v_id bigint;
    i jsonb;
begin
    if exists (select 1 from public.kpi_templates where name = p_name) then return; end if;
    insert into public.kpi_templates (name, department_id)
    values (p_name, (select id from public.departments where name = p_dept))
    returning id into v_id;
    for i in select * from jsonb_array_elements(p_items) loop
        insert into public.kpi_template_items (template_id, name, weightage, category, metric_source)
        values (v_id, i ->> 0, (i ->> 1)::numeric, i ->> 2, i ->> 3);
    end loop;
end;
$$;

-- A submitted review: p_scores follow the template's items in order.
create or replace function demo_seed.review(p_user uuid, p_year int, p_template text, p_scores numeric[], p_comments text)
returns void language plpgsql as $$
declare
    v_tid bigint;
    v_eid bigint;
    v_total numeric := 0;
    k int := 0;
    it record;
begin
    select id into v_tid from public.kpi_templates where name = p_template;
    for it in select * from public.kpi_template_items where template_id = v_tid order by id loop
        k := k + 1;
        v_total := v_total + p_scores[k] * it.weightage / 100;
    end loop;
    insert into public.performance_evaluations (user_id, template_id, year, comments, weighted_total, is_draft, created_at)
    values (p_user, v_tid, p_year, p_comments, round(v_total, 2), false, make_date(p_year, 12, 18)::timestamptz)
    returning id into v_eid;
    k := 0;
    for it in select * from public.kpi_template_items where template_id = v_tid order by id loop
        k := k + 1;
        insert into public.performance_evaluation_scores (evaluation_id, kpi_name, weightage, score, category, metric_source)
        values (v_eid, it.name, it.weightage, p_scores[k], it.category, it.metric_source);
    end loop;
end;
$$;

-- Enrols in a catalogue programme and plays out its history: p_read
-- lessons read, then one quiz attempt per score in p_attempts. A pass
-- completes it (and the certificate trigger issues the certificate).
create or replace function demo_seed.training(
    p_user uuid, p_title text, p_days_ago int, p_read int, p_attempts numeric[],
    p_by text default null, p_reason text default null)
returns void language plpgsql as $$
declare
    v_prog record;
    v_eid bigint;
    v_lessons int;
    v_has_quiz boolean;
    v_passed boolean := false;
    v_best numeric;
    v_at timestamptz := now() - p_days_ago * interval '1 day';
    v_done timestamptz;
    l record;
    k int := 0;
    s numeric;
begin
    perform set_config('app.training_rpc', '1', true);
    select * into v_prog from public.training_programs where title = p_title;
    if not found then
        raise notice 'Skipped "%": run seed_training_catalog.sql first.', p_title;
        return;
    end if;

    insert into public.training_enrollments
        (program_id, user_id, is_recommended, recommendation_reason, recommended_by, progress, enrolled_at)
    values (v_prog.id, p_user, p_by is not null, p_reason, p_by, 0, v_at)
    returning id into v_eid;

    for l in select id from public.training_lessons where program_id = v_prog.id order by sort_order, id limit p_read loop
        k := k + 1;
        insert into public.training_lesson_completions (enrollment_id, lesson_id, completed_at)
        values (v_eid, l.id, v_at + k * interval '1 day');
    end loop;

    k := 0;
    foreach s in array coalesce(p_attempts, '{}') loop
        k := k + 1;
        v_done := v_at + (p_read + k) * interval '1 day' + interval '3 hours';
        insert into public.training_attempts (enrollment_id, user_id, score, passed, created_at)
        values (v_eid, p_user, s, s >= v_prog.pass_mark, v_done);
        v_passed := v_passed or s >= v_prog.pass_mark;
        v_best := greatest(coalesce(v_best, 0), s);
    end loop;

    select count(*) into v_lessons from public.training_lessons where program_id = v_prog.id;
    select exists (select 1 from public.training_questions where program_id = v_prog.id) into v_has_quiz;

    update public.training_enrollments
    set performance_score = v_best,
        progress = case when v_lessons + v_has_quiz::int = 0 then 0
                        else least((least(p_read, v_lessons) + (v_has_quiz and v_passed)::int)::numeric
                                   / (v_lessons + v_has_quiz::int), 1) end,
        is_completed = v_passed and p_read >= v_lessons,
        completed_at = case when v_passed and p_read >= v_lessons then v_done end
    where id = v_eid;
end;
$$;

do $$
declare
    hr      uuid := 'de000000-0000-4000-8000-000000000001';
    johnny  uuid := 'de000000-0000-4000-8000-000000000002';
    sarah   uuid := 'de000000-0000-4000-8000-000000000003';
    kevin   uuid := 'de000000-0000-4000-8000-000000000004';
    meiling uuid := 'de000000-0000-4000-8000-000000000005';
    daniel  uuid := 'de000000-0000-4000-8000-000000000006';
    y       int := extract(year from current_date)::int;
    u       uuid;
begin
    if exists (select 1 from auth.users where id in (hr, johnny, sarah, kevin, meiling, daniel)
                                       or email in ('hannah@gmail.com', 'johnny@gmail.com', 'sarah@gmail.com',
                                                    'kevin@gmail.com', 'meiling@gmail.com', 'daniel@gmail.com')) then
        raise notice 'Demo accounts already exist - nothing to do. Run seed_demo_personas_cleanup.sql first to start over.';
        return;
    end if;
    perform set_config('app.training_rpc', '1', true);

    -- ── Accounts ─────────────────────────────────────────────────────────
    perform demo_seed.account(hr, 'hannah@gmail.com', 'hannah123', 'Hannah Lee', 'HR-9001', 'hr_admin',
        'HR Executive', 'Human Resources', 'HL', (current_date - interval '4 years 6 months')::date, 5200);
    perform demo_seed.account(johnny, 'johnny@gmail.com', 'johnny123', 'Johnny Tan', 'EMP-9001', 'employee',
        'Senior Engineer', 'Engineering', 'JT', (current_date - interval '5 years 3 months')::date, 8500);
    perform demo_seed.account(sarah, 'sarah@gmail.com', 'sarah123', 'Sarah Lim', 'EMP-9002', 'employee',
        'Sales Executive', 'Sales', 'SL', (current_date - interval '2 years 2 months')::date, 4200);
    perform demo_seed.account(kevin, 'kevin@gmail.com', 'kevin123', 'Kevin Raj', 'EMP-9003', 'employee',
        'Backend Engineer', 'Engineering', 'KR', (current_date - interval '14 months')::date, 4800);
    perform demo_seed.account(meiling, 'meiling@gmail.com', 'meiling123', 'Ong Mei Ling', 'EMP-9004', 'employee',
        'Intern', 'Design', 'OM', current_date - 26, 1500);
    perform demo_seed.account(daniel, 'daniel@gmail.com', 'daniel123', 'Daniel Wong', 'EMP-9005', 'employee',
        'Manager', 'Operations', 'DW', (current_date - interval '7 years 1 month')::date, 9800);

    -- ── Leave (before attendance, so leave days aren't marked absent) ─────
    perform demo_seed.leave(johnny, 'LV-9001', 'annual', demo_seed.wd(41), demo_seed.wd(40), 'Family trip to Penang', 'approved', hr);
    perform demo_seed.leave(daniel, 'LV-9002', 'annual', demo_seed.wd(62), demo_seed.wd(60), 'Hari Raya balik kampung', 'approved', hr);
    perform demo_seed.leave(sarah, 'LV-9003', 'medical', demo_seed.wd(18), demo_seed.wd(18), 'Fever, MC from clinic attached', 'approved', hr);
    perform demo_seed.leave(sarah, 'LV-9004', 'annual', current_date + 9, current_date + 9, 'Personal matters', 'pending', hr);
    perform demo_seed.leave(kevin, 'LV-9005', 'emergency', demo_seed.wd(30), demo_seed.wd(30), 'Car broke down on the highway', 'rejected', hr);

    -- ── Attendance: (absent rate, late rate) ─────────────────────────────
    perform demo_seed.attendance(hr, 0.01, 0.03);
    perform demo_seed.attendance(johnny, 0.01, 0.03);
    perform demo_seed.attendance(sarah, 0.16, 0.10);
    perform demo_seed.attendance(kevin, 0.03, 0.08);
    perform demo_seed.attendance(meiling, 0.0, 0.05);
    perform demo_seed.attendance(daniel, 0.02, 0.04);

    -- ── Violations, oldest first (each one deducts through the trigger) ──
    perform demo_seed.incident(kevin, demo_seed.wd(19), 'wifi_mismatch');
    -- Sarah: two late streaks (a violation on the 3rd late day of each),
    -- one day absent without leave, one clock-in off the office WiFi.
    -- 100 - 10 - 15 - 12 - 10 = 53 -> Medium risk.
    update public.attendance_records set status = 'on_time'
    where user_id = sarah and status = 'late' and work_date >= demo_seed.wd(36);
    perform demo_seed.incident(sarah, demo_seed.wd(24), 'late');
    perform demo_seed.incident(sarah, demo_seed.wd(23), 'late');
    perform demo_seed.incident(sarah, demo_seed.wd(22), 'late');
    perform demo_seed.incident(sarah, demo_seed.wd(15), 'unexplained_absence');
    perform demo_seed.incident(sarah, demo_seed.wd(9), 'wifi_mismatch');
    perform demo_seed.incident(sarah, demo_seed.wd(6), 'late');
    perform demo_seed.incident(sarah, demo_seed.wd(5), 'late');
    perform demo_seed.incident(sarah, demo_seed.wd(4), 'late');

    -- ── KPI templates (2-3 automatically measured items each) ────────────
    perform demo_seed.template('Engineering - Individual Contributor', 'Engineering', '[
        ["Code Quality", 25, "Technical", "manual"],
        ["Delivery & Reliability", 20, "Technical", "manual"],
        ["Learning & Development", 10, "Technical", "training"],
        ["Attendance", 10, "Behavioural", "attendance"],
        ["Punctuality", 10, "Behavioural", "punctuality"],
        ["Professional Conduct", 10, "Behavioural", "conduct"],
        ["Team Collaboration", 10, "Behavioural", "manual"],
        ["Initiative & Ownership", 5, "Leadership", "manual"]]');
    perform demo_seed.template('Sales - Executive', 'Sales', '[
        ["Sales Target Achievement", 25, "Technical", "manual"],
        ["Product Knowledge", 15, "Technical", "manual"],
        ["Learning & Development", 10, "Technical", "training"],
        ["Attendance", 10, "Behavioural", "attendance"],
        ["Punctuality", 10, "Behavioural", "punctuality"],
        ["Professional Conduct", 10, "Behavioural", "conduct"],
        ["Customer Relationship", 15, "Behavioural", "manual"],
        ["Initiative & Ownership", 5, "Leadership", "manual"]]');
    perform demo_seed.template('Operations - Manager', 'Operations', '[
        ["Process Efficiency", 20, "Technical", "manual"],
        ["Learning & Development", 10, "Technical", "training"],
        ["Attendance", 5, "Behavioural", "attendance"],
        ["Punctuality", 5, "Behavioural", "punctuality"],
        ["Professional Conduct", 10, "Behavioural", "conduct"],
        ["Stakeholder Communication", 15, "Behavioural", "manual"],
        ["Team Leadership", 20, "Leadership", "manual"],
        ["Planning & Decision Making", 15, "Leadership", "manual"]]');

    -- ── Last year's submitted reviews ────────────────────────────────────
    perform demo_seed.review(johnny, y - 2, 'Engineering - Individual Contributor', '{86,84,80,97,95,100,78,60}',
        'Reliable and technically strong. Encouraged to take on more ownership beyond his own tasks.');
    perform demo_seed.review(johnny, y - 1, 'Engineering - Individual Contributor', '{92,90,94,98,96,100,80,64}',
        'Excellent technical year and the go-to person for code reviews. Next step is leading others: mentoring juniors and driving decisions.');
    perform demo_seed.review(kevin, y - 1, 'Engineering - Individual Contributor', '{55,58,50,95,90,88,72,62}',
        'Good attitude and attendance. Code quality and delivery need to improve; pair more with seniors and strengthen testing habits.');
    perform demo_seed.review(sarah, y - 1, 'Sales - Executive', '{70,66,72,78,48,45,58,62}',
        'Meets most sales targets, but frequent late arrivals and conduct issues are affecting the team. Punctuality must improve.');
    perform demo_seed.review(daniel, y - 2, 'Operations - Manager', '{78,85,96,94,100,80,84,80}',
        'Steady leadership of the operations team.');
    perform demo_seed.review(daniel, y - 1, 'Operations - Manager', '{80,90,97,95,100,84,86,82}',
        'Strong all-round year. Led the warehouse process overhaul and develops his team well.');

    -- ── Training history: (title, days ago, lessons read, quiz scores) ───
    perform demo_seed.training(johnny, 'Cybersecurity Essentials', 300, 3, '{100}');
    perform demo_seed.training(johnny, 'Data Privacy & PDPA Basics', 280, 3, '{80}');
    perform demo_seed.training(johnny, 'Git & Version Control Basics', 210, 3, '{100}');
    perform demo_seed.training(johnny, 'Introduction to Cloud Computing', 120, 3, '{80, 100}');
    perform demo_seed.training(johnny, 'Project Management Basics', 45, 3, '{80}');

    perform demo_seed.training(sarah, 'Cybersecurity Essentials', 200, 3, '{60, 80}');
    perform demo_seed.training(sarah, 'Customer Service Excellence', 150, 3, '{80}');
    perform demo_seed.training(sarah, 'Time Management Essentials', 40, 3, '{40}');
    perform demo_seed.training(sarah, 'Stress & Resilience at Work', 20, 1, null, 'pe',
        'Recommended after scoring 45/100 on "Professional Conduct" (Behavioural) in this year''s Performance Evaluation.');

    perform demo_seed.training(kevin, 'Cybersecurity Essentials', 380, 3, '{80}');
    perform demo_seed.training(kevin, 'Git & Version Control Basics', 60, 3, '{40, 60, 100}');
    perform demo_seed.training(kevin, 'Software Testing & Quality Basics', 25, 3, '{40, 60}', 'pe',
        'Recommended after scoring 55/100 on "Code Quality" (Technical) in this year''s Performance Evaluation.');

    perform demo_seed.training(meiling, 'Cybersecurity Essentials', 20, 1, null);

    perform demo_seed.training(daniel, 'Cybersecurity Essentials', 600, 3, '{80}');
    perform demo_seed.training(daniel, 'Introduction to Leadership', 500, 3, '{100}');
    perform demo_seed.training(daniel, 'Running Effective Meetings', 400, 3, '{80}');
    perform demo_seed.training(daniel, 'Coaching & Mentoring Juniors', 300, 3, '{100}');
    perform demo_seed.training(daniel, 'Excel for Everyday Work', 150, 3, '{60, 80}');

    -- ── The real daily sweep: behaviour rules, then the ML model ─────────
    foreach u in array array[johnny, sarah, kevin, meiling, daniel] loop
        perform public.refresh_training_recommendations_for(u);
    end loop;

    raise notice 'Demo personas created. HR login: hannah@gmail.com / hannah123';
end;
$$;

drop schema demo_seed cascade;

-- What was created, per person:
select p.name, p.employee_code, p.risk_score, p.risk_level,
       (select count(*) from public.attendance_records a where a.user_id = p.id) as attendance_days,
       (select count(*) from public.training_certificates c where c.user_id = p.id) as certificates,
       (select string_agg(tp.title || ' [' || e.recommended_by || ']', ', ')
          from public.training_enrollments e join public.training_programs tp on tp.id = e.program_id
         where e.user_id = p.id and e.recommended_by in ('rule', 'ml')) as recommended_by_sweep
from public.profiles p
where p.id::text like 'de000000-%'
order by p.employee_code;
