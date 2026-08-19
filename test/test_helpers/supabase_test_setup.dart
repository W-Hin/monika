import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Widget tests never talk to a real backend — every screen this suite
/// builds calls a `*Service` in `initState`, and every one of those reads
/// `Supabase.instance.client`, which throws
/// "You must initialize the supabase instance before calling
/// Supabase.instance" unless `Supabase.initialize()` has run first. This is
/// the single fix for that, called once for the whole test binary from
/// flutter_test_config.dart rather than repeated in 19+ individual files.
///
/// The mock HTTP client returns fixture data for a handful of reference
/// tables that gate a lot of screens (profiles/departments/policy_settings/
/// kpi_templates — see [_fixtures]) and an empty array for everything else.
/// This is not a faithful stand-in for a real backend — no auth session
/// exists, so any query scoped to the current user (attendance history,
/// leave/payroll/PE for "me") legitimately returns nothing, same as it
/// would for a real signed-out state. Every controller method these
/// `initState` calls trigger is already wrapped in a best-effort try/catch
/// (this app's established pattern), so anything not covered here is
/// swallowed the same way a real network failure would be.
Future<void> initializeTestSupabase() async {
  SharedPreferences.setMockInitialValues({});

  final mockClient = MockClient((request) async {
    final table = _tableFromPath(request.url.path);
    final wantsSingleObject = (request.headers['accept'] ?? '').contains('vnd.pgrst.object');
    final rows = _fixtures[table] ?? const [];

    // postgrest-dart null-checks `response.request` while parsing — a bare
    // `http.Response(...)` leaves it null unless passed explicitly here.
    if (wantsSingleObject) {
      // PostgREST's single-object Accept header expects a raw JSON object
      // at the HTTP level, not a one-item array — unlike .maybeSingle(),
      // which unwraps a normal array client-side and tolerates [].
      if (rows.isEmpty) {
        return http.Response(
          jsonEncode({'message': 'no rows', 'code': 'PGRST116'}),
          406,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response(
        jsonEncode(rows.first),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    return http.Response(jsonEncode(rows), 200, headers: {'content-type': 'application/json'}, request: request);
  });

  await Supabase.initialize(
    url: 'https://test.supabase.co',
    publishableKey: 'test-publishable-key',
    httpClient: mockClient,
    debug: false,
  );
}

/// PostgREST table paths look like `/rest/v1/<table>` (RPC calls are
/// `/rest/v1/rpc/<fn>`, deliberately not fixtured — best-effort try/catch
/// covers those callers same as any other unhandled endpoint).
String _tableFromPath(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final i = parts.indexOf('v1');
  return i >= 0 && i + 1 < parts.length ? parts[i + 1] : '';
}

final _fixtures = <String, List<Map<String, dynamic>>>{
  'departments': [
    {'id': 1, 'name': 'Engineering'},
  ],
  'profiles': [
    {
      'id': 'test-user-id',
      'employee_code': 'EMP-1001',
      'name': 'Test Employee',
      'email': 'test.employee@example.com',
      'user_role': 'employee',
      'job_title': 'Software Engineer',
      'department_id': 1,
      'departments': {'name': 'Engineering'},
      'risk_level': 'low',
      'avatar_initials': 'TE',
      'registered_device_name': 'Test Device',
      'is_active': true,
      'base_salary': 4500.0,
      'hire_date': '2024-01-15',
      'must_change_password': false,
      'device_token': 'test-device-token',
    },
  ],
  'policy_settings': [
    {
      'id': 1,
      'work_start_time': '09:00:00',
      'work_end_time': '18:00:00',
      'grace_period_minutes': 10,
      'geofence_radius_meters': 100,
      'office_wifi_ssid': 'MONIKA-OFFICE-5G',
      'office_lat': 3.1390,
      'office_lng': 101.6869,
      'late_weight': 1,
      'out_of_zone_weight': 2,
      'shared_device_weight': 3,
      'wifi_mismatch_weight': 1,
      'early_clockout_weight': 0.5,
      'late_deduction': 25.0,
      'absent_deduction': 120.0,
      'unpaid_leave_daily_rate': 120.0,
      'leadership_threshold': 60,
      'technical_threshold': 65,
      'behavioural_threshold': 60,
      'min_tenure_months': 6,
    },
  ],
  'leave_balances': [
    {
      'id': 1,
      'user_id': 'test-user-id',
      'year': DateTime.now().year,
      'annual_total': 8,
      'annual_used': 2,
      'medical_total': 14,
      'medical_used': 0,
      'emergency_total': 3,
      'emergency_used': 0,
      'profiles': {
        'name': 'Test Employee',
        'departments': {'name': 'Engineering'},
      },
    },
  ],
  'payroll_summaries': [
    {
      'id': 1,
      'user_id': 'test-user-id',
      'pay_month': '2026-08-01',
      'base_salary': 4500.0,
      'deductions': 245.0,
      'net_pay': 4255.0,
      'profiles': {'name': 'Test Employee'},
      'payroll_deduction_items': [
        {'id': 1, 'label': 'Late arrival (5 occurrences)', 'amount': 125.0},
        {'id': 2, 'label': 'Unexplained absence (1 day)', 'amount': 120.0},
      ],
    },
  ],
  'kpi_templates': [
    {
      'id': 1,
      'name': 'Engineering IC',
      'department_id': 1,
      'departments': {'name': 'Engineering'},
      'kpi_template_items': [
        {'id': 1, 'name': 'Code Quality', 'weightage': 50.0, 'category': 'technical'},
        {'id': 2, 'name': 'Team Communication', 'weightage': 50.0, 'category': 'behavioural'},
      ],
    },
  ],
};
