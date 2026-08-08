-- Demo data only — NOT a schema migration. Run this manually in the
-- Supabase SQL Editor whenever you want visibly different Week / Month /
-- Quarter numbers on the Analytics dashboard. Safe to re-run: it only
-- inserts a record for a (user, work_date) pair that doesn't already
-- exist, so it never overwrites anything from real on-device testing.
--
-- Populates the past ~90 days of weekday attendance for every existing
-- employee profile with a randomized but realistic mix of on_time / late /
-- flagged, so the period filter on Analytics has real variation to show.
do $$
declare
  emp record;
  d date;
  days_back int;
  roll numeric;
  rec_status text;
  rec_flag text;
  clock_in timestamptz;
  clock_out timestamptz;
begin
  for emp in select id from public.profiles loop
    for days_back in 1..90 loop
      d := current_date - days_back;

      -- Weekdays only (Mon=1 .. Fri=5)
      if extract(isodow from d) between 1 and 5 then
        roll := random();

        if roll < 0.80 then
          rec_status := 'on_time';
          rec_flag := null;
          clock_in := d + time '08:45:00' + (random() * interval '20 minutes');
        elsif roll < 0.92 then
          rec_status := 'late';
          rec_flag := 'Clocked in after grace period';
          clock_in := d + time '09:15:00' + (random() * interval '45 minutes');
        else
          rec_status := 'flagged';
          rec_flag := 'GPS outside geofence radius';
          clock_in := d + time '08:50:00' + (random() * interval '30 minutes');
        end if;

        clock_out := clock_in + interval '8 hours' + (random() * interval '30 minutes');

        insert into public.attendance_records
          (user_id, work_date, clock_in_at, clock_out_at, status, flag_reason, gps_passed, wifi_passed, device_passed)
        values
          (emp.id, d, clock_in, clock_out, rec_status, rec_flag, rec_status <> 'flagged', true, true)
        on conflict (user_id, work_date) do nothing;
      end if;
    end loop;
  end loop;
end $$;
