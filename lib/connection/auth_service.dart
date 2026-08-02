import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase Auth + the `profiles` table.
/// Holds no state of its own — AuthController owns app-facing state.
class AuthService {
  AuthService._();
  static final _client = Supabase.instance.client;

  static Session? get currentSession => _client.auth.currentSession;
  static User? get currentUser => _client.auth.currentUser;

  static Future<AuthResponse> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Fetches the profile row for the currently signed-in user, joined with
  /// its department name. Returns null if there's no session or no matching
  /// profile row (e.g. an auth user was created without a profile yet).
  static Future<Map<String, dynamic>?> fetchMyProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    final row = await _client
        .from('profiles')
        .select('*, departments(name)')
        .eq('id', uid)
        .maybeSingle();

    return row;
  }

  /// Keeps profiles.email in sync with the real auth email on every login —
  /// see migration 0005 for why this denormalized copy exists.
  static Future<void> syncOwnEmail(String email) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _client.from('profiles').update({'email': email}).eq('id', uid);
  }
}
