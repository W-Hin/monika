-- MONIKA — migration 0002: attendance/geofence policy fields
-- schema.sql's policy_settings table was missing the fields clock-in
-- validation actually needs (office location, WiFi SSID, work hours,
-- grace period) — this was an oversight when the table was first written
-- (only risk weights / payroll / training thresholds were carried over).
--
-- Paste into Supabase SQL Editor and Run once.

alter table public.policy_settings
    add column work_start_time     time not null default '09:00',
    add column work_end_time       time not null default '18:00',
    add column grace_period_minutes integer not null default 10,
    add column geofence_radius_meters integer not null default 100,
    add column office_wifi_ssid    text not null default 'MONIKA-OFFICE-5G',
    add column office_lat          numeric(10, 7) not null default 3.1390,
    add column office_lng          numeric(10, 7) not null default 101.6869;

-- Employees need read access to these to validate their own clock-in
-- client-side (existing policy_settings_all_hr policy already covers HR
-- read/write; this adds read-only for everyone else).
create policy "policy_settings_select_authenticated" on public.policy_settings
    for select using (auth.role() = 'authenticated');
