-- MONIKA — migration 0004: anomaly_events schema gaps
-- schema.sql's anomaly_events.type CHECK only allowed 3 of the 4 real
-- anomaly types (dummy_data.dart's anomalyFeed had a 4th: WiFi SSID
-- mismatch) — oversight from the original schema. Also, RLS was HR-only
-- for every operation including insert, which would reject an employee's
-- own client trying to write an anomaly_event about their own flagged
-- clock-in (the only way this app can create these events, since there's
-- no server-side function/trigger doing it).
--
-- Paste into Supabase SQL Editor and Run.

alter table public.anomaly_events
    drop constraint anomaly_events_type_check;

alter table public.anomaly_events
    add constraint anomaly_events_type_check
    check (type in ('out_of_zone', 'shared_device', 'late', 'wifi_mismatch'));

create policy "anomaly_insert_own" on public.anomaly_events
    for insert with check (user_id = auth.uid());
