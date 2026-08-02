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

## Email sending (Gmail SMTP)

`create-employee` and `notify-employee-change` (in `supabase/functions/`)
send real email — the temporary password on account creation, and a
change-notification when HR edits someone's job title, department, or
salary. Both send through **your own Gmail account's SMTP server** over
port 465 (implicit TLS), using a raw SMTP client written against Deno's
`Deno.connectTls` (no external email API/service — nothing to sign up
for beyond the Gmail account itself).

Setup, one-time:

1. On the Google account you want emails to come **from**, turn on
   **2-Step Verification** (Google Account → Security).
2. Generate an **App Password**: Google Account → Security → 2-Step
   Verification → App passwords. Name it anything (e.g. "MONIKA"), copy
   the 16-character password shown.
3. In the Supabase Dashboard → **Edge Functions** → **Manage secrets**,
   add:
   - `GMAIL_SENDER_EMAIL` — the Gmail address itself
   - `GMAIL_APP_PASSWORD` — the 16-character App Password from step 2
     (not your regular Google password)
4. Deploy both `create-employee` and `notify-employee-change` by copying
   each function's `index.ts` **from the local file on disk**, not from
   chat — pasting from a chat message has previously introduced invisible
   formatting that broke the Dashboard's parser. Each file is
   self-contained (no shared imports), since the Dashboard editor doesn't
   reliably support cross-function-folder imports.
5. Test by creating a test employee or editing an existing one's role —
   check the `emailSent`/`emailError` fields in the response, and check
   the destination inbox (including spam).

**Status: experimental, not yet verified against a live deployment.**
Supabase Edge Functions only document outbound ports 25 and 587 as
blocked — port 465 (what Gmail SMTP needs) is not documented as blocked,
but that's inference, not a confirmed test. If it turns out 465 is
blocked in practice, or Gmail's SMTP flags the sends as suspicious
(new sending pattern from an Edge Function's IP), the fallback is a
transactional-email provider with single-sender verification (Brevo or
SendGrid's free tiers both support this) instead of a full domain — same
Edge Function structure, just swap `sendViaGmail(...)` for an HTTPS POST
to the provider's API.

## Forgot Password (email OTP code)

Forgot Password uses Supabase Auth's own built-in email delivery
(`resetPasswordForEmail` / `verifyOTP`) — a completely separate system
from the Gmail SMTP Edge Functions above, and it needs no secrets of its
own.

**One manual Dashboard step required:** by default, Supabase's "Reset
Password" email template only renders a clickable link
(`{{ .ConfirmationURL }}`), not a code. This app's flow needs an actual
6-digit code in the email instead. To fix:

1. Supabase Dashboard → Authentication → Email Templates → **Reset
   Password**.
2. Add `{{ .Token }}` somewhere in the template body (e.g. "Your reset
   code is: `{{ .Token }}`").
3. Save.

Without this, `resetPasswordForEmail` will still succeed and an email
will still arrive, but it won't contain a code the app's "Enter Code"
screen can use.

## Free-tier note

A Supabase free-tier project pauses after about a week with no API
activity. Nothing is lost — click "Restore" in the dashboard and it's back
within a minute or two. Just don't let it go quiet right before a demo or
viva without checking first.
