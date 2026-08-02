// Copy this file to supabase_config.dart and fill in real values.
// supabase_config.dart is gitignored — this file documents the expected
// shape and is safe to commit.
//
// Get these from: Supabase Dashboard → Project Settings → API.
// The anon key is safe to ship in a client app (it's designed for that —
// access control is enforced by Row Level Security policies, not by
// keeping this key secret). Never put the service_role key in this file
// or anywhere in the Flutter app — that key bypasses RLS entirely and must
// only ever be used server-side (a Supabase Edge Function).

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://your-project-ref.supabase.co';
  static const String anonKey = 'your-anon-key';
}
