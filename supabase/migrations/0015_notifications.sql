-- In-app real-time notifications, delivered over Supabase Realtime (no
-- external push service / Firebase project required — this is in-app
-- real-time, not OS-level push notifications, which would need separate
-- FCM/APNs setup outside this stack).
--
-- Rows are written only by SECURITY DEFINER trigger functions below, fired
-- by the same actions that already happen in the app (leave decisions,
-- new training programmes, payroll generation, attendance anomalies, PE
-- evaluations) — never inserted directly by the client.
create table public.notifications (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references public.profiles(id) on delete cascade,
    title       text not null,
    body        text not null,
    type        text not null, -- 'leave_decision' | 'training' | 'payroll' | 'anomaly' | 'pe'
    is_read     boolean not null default false,
    created_at  timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "notifications_select_own" on public.notifications
    for select using (user_id = auth.uid());
create policy "notifications_update_own" on public.notifications
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Adds the table to Supabase's default Realtime publication so clients can
-- subscribe to INSERT events on it.
alter publication supabase_realtime add table public.notifications;

-- ─────────────────────────────────────────────────────────────────────────
-- Leave application approved / rejected
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.notify_leave_decision() returns trigger
language plpgsql security definer as $$
begin
  if new.status is distinct from old.status and new.status in ('approved', 'rejected') then
    insert into public.notifications (user_id, title, body, type)
    values (
      new.user_id,
      case when new.status = 'approved' then 'Leave Application Approved' else 'Leave Application Rejected' end,
      format('Your %s leave application (%s to %s) has been %s.', new.leave_type, new.start_date, new.end_date, new.status),
      'leave_decision'
    );
  end if;
  return new;
end;
$$;

create trigger trg_notify_leave_decision
  after update on public.leave_applications
  for each row execute function public.notify_leave_decision();

-- ─────────────────────────────────────────────────────────────────────────
-- New training programme published (scoped to its target department, or
-- everyone if it's for all departments)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.notify_new_training() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  select p.id, 'New Training Published', format('A new training programme is available: %s', new.title), 'training'
  from public.profiles p
  where new.department_id is null or p.department_id = new.department_id;
  return new;
end;
$$;

create trigger trg_notify_new_training
  after insert on public.training_programs
  for each row execute function public.notify_new_training();

-- ─────────────────────────────────────────────────────────────────────────
-- Payroll summary generated
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.notify_payroll_ready() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (
    new.user_id,
    'Payroll Summary Available',
    format('Your %s payroll summary is now available. Net pay: RM %s.', to_char(new.pay_month, 'FMMonth YYYY'), to_char(new.net_pay, 'FM999,999,990.00')),
    'payroll'
  );
  return new;
end;
$$;

create trigger trg_notify_payroll_ready
  after insert on public.payroll_summaries
  for each row execute function public.notify_payroll_ready();

-- ─────────────────────────────────────────────────────────────────────────
-- Attendance anomaly flagged
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.notify_anomaly() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (new.user_id, 'Attendance Flag', format('An attendance anomaly was flagged on your account: %s', new.details), 'anomaly');
  return new;
end;
$$;

create trigger trg_notify_anomaly
  after insert on public.anomaly_events
  for each row execute function public.notify_anomaly();

-- ─────────────────────────────────────────────────────────────────────────
-- Performance evaluation submitted/updated by HR
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.notify_pe_evaluated() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (new.user_id, 'Performance Evaluation Updated', format('Your %s Performance Evaluation results are now available.', new.year), 'pe');
  return new;
end;
$$;

create trigger trg_notify_pe_evaluated
  after insert or update on public.performance_evaluations
  for each row execute function public.notify_pe_evaluated();
