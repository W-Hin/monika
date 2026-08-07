-- policy_config.dart has always had a "WiFi SSID Mismatch" risk weight
-- slider and an "Unpaid Leave Daily Rate" field, but policy_settings never
-- had matching columns for them - the screen was pure local widget state
-- with a fake save delay, so this went unnoticed until it was wired to
-- real persistence.
alter table public.policy_settings
  add column wifi_mismatch_weight numeric(4, 1) not null default 1,
  add column unpaid_leave_daily_rate numeric(10, 2) not null default 120.00;
