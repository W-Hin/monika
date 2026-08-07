import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `leave_applications` and `leave_balances` tables.
/// Holds no state of its own — LeaveController owns app-facing state.
class LeaveService {
  LeaveService._();
  static final _client = Supabase.instance.client;

  static int get _currentYear => DateTime.now().year;

  static Future<Map<String, dynamic>?> fetchMyBalance() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return await _client
        .from('leave_balances')
        .select()
        .eq('user_id', uid)
        .eq('year', _currentYear)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> fetchMyApplications() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('leave_applications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> submitApplication({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required int days,
    required String reason,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    final refCode = 'LV-${DateTime.now().millisecondsSinceEpoch % 100000}';
    await _client.from('leave_applications').insert({
      'reference_code': refCode,
      'user_id': uid,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'days': days,
      'reason': reason,
    });
  }

  /// HR — every application, joined with the applicant's name.
  static Future<List<Map<String, dynamic>>> fetchAllApplications() async {
    final rows = await _client
        .from('leave_applications')
        .select('*, profiles(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> decide({
    required int applicationId,
    required bool approve,
  }) async {
    await _client.from('leave_applications').update({
      'status': approve ? 'approved' : 'rejected',
      'decided_by': _client.auth.currentUser?.id,
      'decided_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId);
  }

  /// Only called after an approval — unpaid leave has no balance pool to
  /// deduct from. Fetch-then-update since a plain REST update can't
  /// express an atomic "increment by" without an RPC function.
  static Future<void> incrementUsedDays({
    required String userUuid,
    required String leaveType,
    required int days,
  }) async {
    if (leaveType == 'unpaid') return;
    final column = switch (leaveType) {
      'annual' => 'annual_used',
      'medical' => 'medical_used',
      _ => 'emergency_used',
    };
    final row = await _client
        .from('leave_balances')
        .select(column)
        .eq('user_id', userUuid)
        .eq('year', _currentYear)
        .maybeSingle();
    final current = (row?[column] as int?) ?? 0;
    await _client
        .from('leave_balances')
        .update({column: current + days})
        .eq('user_id', userUuid)
        .eq('year', _currentYear);
  }

  /// HR — every employee's current-year balance, joined with their name.
  static Future<List<Map<String, dynamic>>> fetchAllBalances() async {
    final rows = await _client
        .from('leave_balances')
        .select('*, profiles(name)')
        .eq('year', _currentYear);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> updateEntitlement({
    required String userUuid,
    required int annualTotal,
    required int medicalTotal,
    required int emergencyTotal,
  }) async {
    await _client.from('leave_balances').update({
      'annual_total': annualTotal,
      'medical_total': medicalTotal,
      'emergency_total': emergencyTotal,
    }).eq('user_id', userUuid).eq('year', _currentYear);
  }
}
