import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `device_change_requests` table. Holds no state of
/// its own — DeviceRequestController owns app-facing state.
class DeviceRequestService {
  DeviceRequestService._();
  static final _client = Supabase.instance.client;

  static Future<void> submit(String reason) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    await _client.from('device_change_requests').insert({'user_id': uid, 'reason': reason});
  }

  /// The employee's own most recent requests (pending, cancelled, or
  /// decided) — used to derive both "do they already have one pending"
  /// and "are they in the post-cancel cooldown window" in one round trip.
  static Future<List<Map<String, dynamic>>> fetchMyRecent({int limit = 5}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('device_change_requests')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// HR — every request, joined with the requester's name. Explicitly
  /// disambiguated to the user_id FK — this table also has a decided_by FK
  /// to profiles, so a plain 'profiles(name)' embed is ambiguous to
  /// PostgREST (same issue leave_applications had).
  static Future<List<Map<String, dynamic>>> fetchAllForHr() async {
    final rows = await _client
        .from('device_change_requests')
        .select('*, profiles!device_change_requests_user_id_fkey(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> decide({required int requestId, required bool approve}) async {
    await _client.from('device_change_requests').update({
      'status': approve ? 'approved' : 'rejected',
      'decided_by': _client.auth.currentUser?.id,
      'decided_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  /// FR6.7 — the employee who submitted it, or HR, withdrawing a request
  /// before it's been approved/rejected. Distinct from decide()'s
  /// approve/reject: cancelling isn't HR passing judgement on the request,
  /// it's the request being pulled before that ever happens.
  static Future<void> cancel(int requestId) async {
    await _client.from('device_change_requests').update({
      'status': 'cancelled',
      'decided_by': _client.auth.currentUser?.id,
      'decided_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }
}
