import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `anomaly_events` table.
/// Holds no state of its own — AnomalyController owns app-facing state.
class AnomalyService {
  AnomalyService._();
  static final _client = Supabase.instance.client;

  /// Called by an employee's own client when their clock-in fails a check
  /// or trips the repeated-late threshold. RLS only allows inserting a row
  /// for yourself (`anomaly_insert_own`) — HR can read/update everything,
  /// but creation is always attributed to whoever triggered it.
  static Future<void> createEvent({
    required String type,
    required String details,
    required String severity,
    int? attendanceRecordId,
  }) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('anomaly_events').insert({
      'user_id': uid,
      'attendance_record_id': attendanceRecordId,
      'type': type,
      'event_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'details': details,
      'severity': severity,
    });
  }

  static Future<List<Map<String, dynamic>>> fetchFeed({int limit = 50}) async {
    final rows = await _client
        .from('anomaly_events')
        .select('*, profiles(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// A dispute investigation found the flag invalid (FR3.6). Done in one
  /// server-side step (revert_violation, migration 0043): the attendance
  /// record goes back to On Time, the risk points the violation cost are
  /// given back if it still counts towards the current period, the anomaly
  /// is marked reviewed and reverted, and the employee is notified.
  /// Returns how many points were given back.
  static Future<int> revert(int anomalyId) async {
    final restored = await _client.rpc('revert_violation', params: {'p_anomaly_id': anomalyId});
    return (restored as num?)?.toInt() ?? 0;
  }

  /// HR turns down an employee's appeal against an unexplained absence,
  /// optionally with a note the employee will see.
  static Future<void> rejectAppeal(int anomalyId, String response) async {
    await _client.rpc('reject_absence_appeal', params: {'p_anomaly_id': anomalyId, 'p_response': response});
  }

  static Future<void> markReviewed(int id) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('anomaly_events').update({
      'reviewed': true,
      'reviewed_by': uid,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
