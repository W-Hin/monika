-- Clock-out never checked against work_end_time — an employee could clock
-- out at any time with no flag. Adds 'early_clockout' as a recognised
-- anomaly type so the Flutter side can raise one the same way it already
-- does for out_of_zone/shared_device/wifi_mismatch/late.
alter table public.anomaly_events
    drop constraint anomaly_events_type_check;

alter table public.anomaly_events
    add constraint anomaly_events_type_check
    check (type in ('out_of_zone', 'shared_device', 'late', 'wifi_mismatch', 'early_clockout'));
