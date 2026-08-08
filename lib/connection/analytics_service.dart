import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only aggregation queries across attendance/anomaly/leave/payroll/PE
/// data for the HR Analytics screen and dashboard summary cards. No table
/// of its own — this is a reporting layer over other modules' tables.
class AnalyticsService {
  AnalyticsService._();
  static final _client = Supabase.instance.client;

  static String dateKey(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;

  static Future<List<Map<String, dynamic>>> fetchAttendanceRecords({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final rows = await _client
        .from('attendance_records')
        .select('user_id, work_date, status')
        .gte('work_date', dateKey(start))
        .lt('work_date', dateKey(endExclusive));
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Late records only, joined with employee name + department, for the
  /// "Late Arrival Frequency" leaderboard.
  static Future<List<Map<String, dynamic>>> fetchLateRecordsWithNames({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final rows = await _client
        .from('attendance_records')
        .select('user_id, profiles(name, departments(name))')
        .eq('status', 'late')
        .gte('work_date', dateKey(start))
        .lt('work_date', dateKey(endExclusive));
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<int> fetchAnomalyCount({required DateTime start, required DateTime endExclusive}) async {
    final rows = await _client
        .from('anomaly_events')
        .select('id')
        .gte('event_date', dateKey(start))
        .lt('event_date', dateKey(endExclusive));
    return List.from(rows).length;
  }

  static Future<int> fetchHighSeverityAnomalyCount({required DateTime start, required DateTime endExclusive}) async {
    final rows = await _client
        .from('anomaly_events')
        .select('id')
        .eq('severity', 'high')
        .gte('event_date', dateKey(start))
        .lt('event_date', dateKey(endExclusive));
    return List.from(rows).length;
  }

  static Future<int> fetchActiveEmployeeCount() async {
    final rows = await _client.from('profiles').select('id').eq('is_active', true);
    return List.from(rows).length;
  }

  static Future<int> fetchOnLeaveTodayCount() async {
    final today = dateKey(DateTime.now());
    final rows = await _client
        .from('leave_applications')
        .select('id')
        .eq('status', 'approved')
        .lte('start_date', today)
        .gte('end_date', today);
    return List.from(rows).length;
  }

  /// Excludes the current HR admin's own pending applications — the
  /// self-decision-lock trigger means HR can never decide on their own
  /// leave anyway, and hr_approvals.dart's reviewable list already
  /// excludes them, so counting them here just left the Dashboard badge
  /// showing "1 pending" for a request that never actually appeared in
  /// the Approvals list.
  static Future<int> fetchPendingLeaveCount() async {
    final myUid = _client.auth.currentUser?.id;
    var query = _client.from('leave_applications').select('id').eq('status', 'pending');
    final rows = myUid != null ? await query.neq('user_id', myUid) : await query;
    return List.from(rows).length;
  }

  static Future<({double total, int employeeCount})> fetchPayrollDeductionsThisMonth() async {
    final monthKey = dateKey(DateTime(DateTime.now().year, DateTime.now().month, 1));
    final rows = await _client.from('payroll_summaries').select('deductions').eq('pay_month', monthKey);
    final list = List<Map<String, dynamic>>.from(rows);
    final total = list.fold<double>(0, (sum, r) => sum + (r['deductions'] as num).toDouble());
    return (total: total, employeeCount: list.length);
  }

  static Future<double?> fetchAveragePeScoreThisYear() async {
    final rows = await _client.from('performance_evaluations').select('weighted_total').eq('year', DateTime.now().year);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return null;
    final total = list.fold<double>(0, (sum, r) => sum + (r['weighted_total'] as num).toDouble());
    return total / list.length;
  }
}
