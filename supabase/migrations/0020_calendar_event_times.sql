-- Company events only carried a date, no time-of-day, so HR couldn't say
-- "Team Building 2pm-4pm" — every event looked all-day. Widening to
-- timestamptz keeps existing data intact (a bare date casts to midnight)
-- while letting new/edited events carry a real start/end time.
alter table public.company_events
    alter column event_date type timestamptz using event_date::timestamptz,
    alter column end_date type timestamptz using end_date::timestamptz;
