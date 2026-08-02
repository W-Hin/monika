# MONIKA — Supabase backend

Phase 2 backend, replacing the earlier `backend/` PHP+MySQL scaffold. See
`.claude` project memory / commit history for why (short version: no
real-world deployment needed, free-tier MySQL hosting is weak, Supabase's
free Postgres tier is solid, and the FYP isn't locked to PHP specifically).

## Applying the schema

No CLI, no DB password needed for this step:

1. Open your project at [supabase.com](https://supabase.com) → **SQL Editor** → **New query**.
2. Paste the entire contents of `schema.sql`.
3. Click **Run**.

That creates all 15 tables, the `is_hr_admin()` helper function, and every
Row Level Security policy in one pass. It's written to run once against a
fresh project (no `if not exists` guards) — if you need to re-run it,
drop the tables first or start a new project.

## Flutter side

Already wired:
- `pubspec.yaml` — `supabase_flutter` dependency
- `lib/main.dart` — `Supabase.initialize(...)` before `runApp`
- `lib/core/config/supabase_config.dart` — your project URL + anon key (gitignored — see `supabase_config.example.dart` for the template)

Still to do (Phase 3 — not part of today's setup):
- Wire the empty `lib/connection/*.dart` service files to real
  `Supabase.instance.client` calls, replacing `dummy_data.dart` reads.
- Seed test data: create a couple of test users manually (Dashboard →
  Authentication → Add user) and insert matching `profiles` rows (SQL
  Editor) with `user_role = 'hr_admin'` / `'employee'` so you have
  something to log in as.

## Why there's no "HR creates employee account" flow yet

The anon key (used by the Flutter app) intentionally **cannot** create
other users' accounts — only the `service_role` key can, and that key must
never appear in the Flutter app (it bypasses every RLS policy). Real
"HR creates new employee" functionality needs a **Supabase Edge Function**:
a small server-side script that holds the `service_role` key, creates the
`auth.users` row and the matching `profiles` row together, and is called
by the app over HTTPS. That's Phase 3 scope, not this initial setup.

## Free-tier note

A Supabase free-tier project pauses after about a week with no API
activity. Nothing is lost — click "Restore" in the dashboard and it's back
within a minute or two. Just don't let it go quiet right before a demo or
viva without checking first.
