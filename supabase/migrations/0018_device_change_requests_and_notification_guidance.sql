-- Employee "Request Device Change" was pure UI theatre — it only showed a
-- SnackBar and never wrote anything anywhere, so HR had no way to ever see
-- or act on a request. This adds real persistence plus an HR decision flow
-- that reuses the existing device-binding reset (same fields
-- employee_detail.dart's "Reset device binding" action already clears).
create table public.device_change_requests (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references public.profiles(id) on delete cascade,
    reason      text not null,
    status      text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
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

alter publication supabase_realtime add table public.device_change_requests;

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

-- Every notification type from migration 0015 gets the same "what do I do
-- now" guidance appended to its body, per feedback that approvals/updates
-- without next steps left the user unsure what to actually do next.
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

create or replace function public.notify_anomaly() returns trigger
language plpgsql security definer as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (
    new.user_id,
    'Attendance Flag',
    format('An attendance anomaly was flagged on your account: %s', new.details) ||
    E'\n\nNext steps:\n1. Go to Attendance\n2. Review the flagged record — contact HR if this wasn\'t you',
    'anomaly'
  );
  return new;
end;
$$;

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
