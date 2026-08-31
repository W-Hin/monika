import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `profiles` / `departments` tables for HR's
/// Employee Management screens. Creating a brand new employee is NOT here —
/// that needs the service_role key and lives in a Supabase Edge Function
/// instead (see supabase/functions/create-employee).
class EmployeeService {
  EmployeeService._();
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('profiles').select('*, departments(name)').order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Every attendance record's user_id + status, company-wide, all-time.
  /// Used to compute each employee's real attendance rate (fraction of
  /// logged clock-ins that were on_time or late, i.e. not flagged) -
  /// previously approximated from risk_score as a stand-in until this
  /// existed. Same "not a true presence/absence rate" caveat as
  /// Analytics/Payroll - there's no working-days calendar to know what
  /// the denominator of expected attendance days should be.
  static Future<List<Map<String, dynamic>>> fetchAllAttendanceStatuses() async {
    final rows = await _client.from('attendance_records').select('user_id, status');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<String>> fetchDepartmentNames() async {
    final rows = await _client.from('departments').select('name').order('name');
    return List<Map<String, dynamic>>.from(rows).map((r) => r['name'] as String).toList();
  }

  static Future<void> updateEmployment({
    required String uuid,
    required String jobTitle,
    required String departmentName,
    double? baseSalary,
  }) async {
    final dept = await _client.from('departments').select('id').eq('name', departmentName).single();
    await _client.from('profiles').update({
      'job_title': jobTitle,
      'department_id': dept['id'],
      'base_salary': baseSalary,
    }).eq('id', uuid);
  }

  static Future<Map<String, dynamic>?> fetchOne(String uuid) {
    return _client.from('profiles').select('*, departments(name)').eq('id', uuid).maybeSingle();
  }

  static Future<void> setActive({required String uuid, required bool isActive}) async {
    await _client.from('profiles').update({'is_active': isActive}).eq('id', uuid);
  }

  static Future<void> resetDeviceBinding(String uuid) async {
    await _client.from('profiles').update({
      'device_token': null,
      'registered_device_name': null,
      'device_bound_at': null,
    }).eq('id', uuid);
  }

  /// A clean slate after an employee has addressed whatever drove their
  /// score down is a deliberate HR action available any time, independent
  /// of the automatic reset apply_risk_deduction()/reset_stale_risk_scores()
  /// already apply every policy_settings.risk_reset_period_months
  /// (migration 0032). Resets risk_period_start too, restarting that
  /// automatic-reset clock from now — otherwise a manual reset right
  /// before the automatic one was due would immediately look "overdue"
  /// again to the proactive cron job.
  static Future<void> resetRiskScore(String uuid) async {
    await _client.from('profiles').update({
      'risk_score': 100,
      'risk_level': 'low',
      'risk_period_start': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uuid);
  }
}
