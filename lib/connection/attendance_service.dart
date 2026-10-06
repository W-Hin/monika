import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `attendance_records` / `policy_settings` tables.
/// Holds no state of its own — AttendanceController owns app-facing state.
class AttendanceService {
  AttendanceService._();
  static final _client = Supabase.instance.client;

  static String get _todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static Future<Map<String, dynamic>?> fetchTodayRecord() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return _client
        .from('attendance_records')
        .select()
        .eq('user_id', uid)
        .eq('work_date', _todayDate)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> fetchHistory({int limit = 30}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('attendance_records')
        .select()
        .eq('user_id', uid)
        .order('work_date', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Every record within one specific calendar month, uncapped — used by
  /// the Attendance History screen's month filter. fetchHistory's cap of
  /// the most recent 30 rows would silently drop older months once an
  /// account has accumulated more than 30 records total.
  static Future<List<Map<String, dynamic>>> fetchForMonth(DateTime month) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final start = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month, 1));
    final endExclusive = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month + 1, 1));
    final rows = await _client
        .from('attendance_records')
        .select()
        .eq('user_id', uid)
        .gte('work_date', start)
        .lt('work_date', endExclusive)
        .order('work_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Every attendance record's status, uncapped — used for the Home
  /// dashboard's all-time Attendance Rate stat, which needs the true
  /// total rather than fetchHistory's "most recent N rows" cap.
  static Future<List<Map<String, dynamic>>> fetchAllStatuses() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client.from('attendance_records').select('status').eq('user_id', uid);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Every record in the last [days] days, uncapped — used for the Risk
  /// Classification summary, which needs the true count over a fixed
  /// window rather than fetchHistory's "most recent N rows" cap.
  static Future<List<Map<String, dynamic>>> fetchWindow({int days = 90}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final since = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: days)));
    final rows = await _client
        .from('attendance_records')
        .select()
        .eq('user_id', uid)
        .gte('work_date', since)
        .order('work_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> clockIn({
    double? gpsLat,
    double? gpsLng,
    required bool gpsPassed,
    String? wifiSsid,
    required bool wifiPassed,
    required bool devicePassed,
    required String status,
    String? flagReason,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final now = DateTime.now();
    return _client
        .from('attendance_records')
        .insert({
          'user_id': uid,
          'work_date': _todayDate,
          // toIso8601String() on a local DateTime omits any timezone
          // suffix, so Postgres would otherwise cast it as if it were
          // already UTC — .toUtc() first makes the stored instant correct.
          'clock_in_at': now.toUtc().toIso8601String(),
          'status': status,
          'flag_reason': flagReason,
          'gps_lat': gpsLat,
          'gps_lng': gpsLng,
          'gps_passed': gpsPassed,
          'wifi_ssid': wifiSsid,
          'wifi_passed': wifiPassed,
          'device_passed': devicePassed,
        })
        .select()
        .single();
  }

  static Future<Map<String, dynamic>> clockOut(int recordId, {bool early = false}) async {
    final update = <String, dynamic>{'clock_out_at': DateTime.now().toUtc().toIso8601String()};
    if (early) {
      update['status'] = 'flagged';
      update['flag_reason'] = 'Clocked out earlier than the scheduled end time';
    }
    return _client
        .from('attendance_records')
        .update(update)
        .eq('id', recordId)
        .select()
        .single();
  }

  /// The signed-in employee's recent unexplained absences with their
  /// appeal status (my_absence_flags, migration 0044).
  static Future<List<Map<String, dynamic>>> fetchMyAbsenceFlags() async {
    final rows = await _client.rpc('my_absence_flags');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Appeal an unexplained absence within 7 days, giving a reason HR will see.
  static Future<void> appealAbsence({required int anomalyId, required String reason}) async {
    await _client.rpc('appeal_absence', params: {'p_anomaly_id': anomalyId, 'p_reason': reason});
  }

  static Future<Map<String, dynamic>?> fetchPolicySettings() {
    return _client.from('policy_settings').select().eq('id', 1).maybeSingle();
  }

  /// Counts 'late'-status records in the last [days] days, including today's
  /// just-inserted one — used to detect a repeated-late pattern worth
  /// flagging to HR rather than raising an anomaly on every single late day.
  static Future<int> countRecentLate({int days = 14}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _client
        .from('attendance_records')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'late')
        .gte('work_date', DateFormat('yyyy-MM-dd').format(since));
    return rows.length;
  }

  /// Checked before the first-use auto-bind below — RLS hides every other
  /// employee's `device_token` from a plain client-side SELECT, so this
  /// calls a SECURITY DEFINER RPC (migration 0024) that can see across all
  /// profiles just far enough to answer "does someone else already have
  /// this device".
  static Future<bool> isDeviceBoundToOther(String deviceToken) async {
    final uid = _client.auth.currentUser!.id;
    final result = await _client.rpc('device_token_bound_to_other', params: {
      'p_device_token': deviceToken,
      'p_calling_user_id': uid,
    });
    return result as bool;
  }

  /// Called on first successful clock-in when the profile has no device
  /// bound yet. Subsequent clock-ins compare against this instead.
  static Future<void> bindDevice({required String deviceToken, required String deviceName}) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('profiles').update({
      'device_token': deviceToken,
      'registered_device_name': deviceName,
      'device_bound_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }
}
