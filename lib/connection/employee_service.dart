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
}
