-- MONIKA — migration 0003: set real office/test location
-- Overwrites the KL placeholder from 0002 with the user's actual test
-- location. Paste into Supabase SQL Editor and Run.

update public.policy_settings
set office_lat = 5.3419115,
    office_lng = 100.2728459
where id = 1;
