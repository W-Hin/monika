-- Lets HR target a company event (e.g. "Intern Team Building") at specific
-- employees instead of the whole company. An event with no assignment rows
-- stays visible to everyone (today's behaviour, unchanged); an event WITH
-- assignment rows is only visible to HR and the assigned employees.
create table public.company_event_assignments (
    id        bigint generated always as identity primary key,
    event_id  bigint not null references public.company_events(id) on delete cascade,
    user_id   uuid not null references public.profiles(id) on delete cascade,
    unique (event_id, user_id)
);

alter table public.company_event_assignments enable row level security;

-- An employee needs to read their own assignment rows so the company_events
-- policy below can check "is this event assigned to me"; HR manages all.
create policy "company_event_assignments_select_own_or_hr" on public.company_event_assignments
    for select using (user_id = auth.uid() or public.is_hr_admin());
create policy "company_event_assignments_write_hr" on public.company_event_assignments
    for all using (public.is_hr_admin()) with check (public.is_hr_admin());

drop policy "company_events_select_authenticated" on public.company_events;
create policy "company_events_select_scoped" on public.company_events
    for select using (
        public.is_hr_admin()
        or not exists (select 1 from public.company_event_assignments a where a.event_id = id)
        or exists (select 1 from public.company_event_assignments a where a.event_id = id and a.user_id = auth.uid())
    );
