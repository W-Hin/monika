-- Company Calendar had no table at all - it was a hardcoded const list of
-- 12 events with no create/edit/delete UI even for HR, purely decorative.
create table public.company_events (
    id          bigint generated always as identity primary key,
    title       text not null,
    event_date  date not null,
    end_date    date,
    event_type  text not null check (event_type in ('public_holiday', 'company_event', 'hr_event')),
    created_at  timestamptz not null default now()
);

alter table public.company_events enable row level security;

-- Readable by any signed-in user (employee or HR); only HR can manage it.
create policy "company_events_select_authenticated" on public.company_events
    for select using (auth.uid() is not null);
create policy "company_events_write_hr" on public.company_events
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

-- Seed with the same 12 events the dummy version already had, so the
-- calendar isn't empty the first time this is deployed.
insert into public.company_events (title, event_date, end_date, event_type) values
    ('Hari Raya Aidiladha', '2026-06-07', null, 'public_holiday'),
    ('Q2 Company Town Hall', '2026-06-15', null, 'company_event'),
    ('Yang Di-Pertuan Agong Birthday', '2026-07-06', null, 'public_holiday'),
    ('Mid-Year Performance Reviews', '2026-07-14', '2026-07-18', 'company_event'),
    ('National Day', '2026-08-31', null, 'public_holiday'),
    ('Annual Team Building', '2026-09-05', '2026-09-06', 'company_event'),
    ('Malaysia Day', '2026-09-16', null, 'public_holiday'),
    ('Q3 Department Reviews', '2026-09-28', null, 'company_event'),
    ('Deepavali', '2026-10-20', null, 'public_holiday'),
    ('Annual PE Cycle Begins', '2026-11-01', null, 'hr_event'),
    ('Christmas Day', '2026-12-25', null, 'public_holiday'),
    ('Q4 Annual Review Deadline', '2026-12-30', null, 'hr_event');
