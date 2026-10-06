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
    if (_rpcFixtures.containsKey(table)) {
      return http.Response(jsonEncode(_rpcFixtures[table]), 200,
          headers: {'content-type': 'application/json'}, request: request);
    }
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

/// PostgREST table paths look like `/rest/v1/<table>`; RPC calls are
/// `/rest/v1/rpc/<fn>` and come back as `rpc/<fn>`. Only the RPCs listed in
/// [_rpcFixtures] answer with data — every other one gets an empty array,
/// which its caller's best-effort try/catch handles like any other
/// unhandled endpoint.
String _tableFromPath(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final i = parts.indexOf('v1');
  if (i < 0 || i + 1 >= parts.length) return '';
  if (parts[i + 1] == 'rpc' && i + 2 < parts.length) return 'rpc/${parts[i + 2]}';
  return parts[i + 1];
}

/// Raw JSON bodies for RPCs that return a single jsonb value.
final _rpcFixtures = <String, Object>{
  // Shape returned by ml_predict_training_category() (migration 0040).
  'rpc/ml_predict_training_category': {
    'category': 'behavioural',
    'confidence': 0.82,
    'probabilities': {'technical': 0.10, 'behavioural': 0.82, 'leadership': 0.08},
    'top_factors': [
      {'feature': 'attendance_rate', 'value': 81.5, 'z': -3.4, 'contribution': 1.9},
      {'feature': 'pe_behavioural', 'value': 55, 'z': -1.7, 'contribution': 1.2},
    ],
    'model_version': 'lr-20261006-test',
    'model_accuracy': 0.78,
    'min_confidence': 0.65,
  },
  'rpc/training_quiz_info': [
    {'question_count': 5, 'pass_mark': 70},
  ],
};

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
      'late_weight': 10,
      'out_of_zone_weight': 20,
      'shared_device_weight': 35,
      'wifi_mismatch_weight': 12,
      'early_clockout_weight': 8,
      'unexplained_absence_weight': 15,
      'risk_reset_period_months': 2,
      'risk_penalty_percent': 5.0,
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
  // One flagged clock-in (it has an attendance_record_id), so the anomaly
  // feed renders a card with the Revert action.
  'anomaly_events': [
    {
      'id': 1,
      'user_id': 'test-user-id',
      'attendance_record_id': 1,
      'type': 'out_of_zone',
      'event_date': '2026-09-01',
      'details': 'Clocked in 450 m outside the office geofence',
      'severity': 'medium',
      'reviewed': false,
      'reverted_at': null,
      'profiles': {'name': 'Test Employee'},
    },
    // Already reverted after a dispute: shows "Reverted", no Revert button.
    {
      'id': 2,
      'user_id': 'test-user-id',
      'attendance_record_id': 2,
      'type': 'wifi_mismatch',
      'event_date': '2026-08-20',
      'details': 'Connected to "Cafe_Guest" instead of the registered office network',
      'severity': 'low',
      'reviewed': true,
      'reverted_at': '2026-08-21T03:00:00Z',
      'profiles': {'name': 'Test Employee'},
    },
    // An unexplained absence the employee appealed within 7 days, still open.
    {
      'id': 3,
      'user_id': 'test-user-id',
      'attendance_record_id': null,
      'type': 'unexplained_absence',
      'event_date': '2026-09-25',
      'details': 'No attendance record and no approved leave for 25 Sep 2026',
      'severity': 'medium',
      'reviewed': false,
      'reverted_at': null,
      'appeal_reason': 'Working at the client site all day',
      'appealed_at': '2026-09-27T02:00:00Z',
      'appeal_status': 'pending',
      'profiles': {'name': 'Test Employee'},
    },
  ],
  // One mandatory programme for everyone, so HR sees its Exemptions action.
  'training_programs': [
    {
      'id': 7,
      'title': 'Workplace Ethics',
      'category': 'behavioural',
      'description': 'Professional conduct at work.',
      'is_mandatory': true,
      'duration': '2 hours',
      'department_id': null,
      'departments': null,
      'access': 'open',
      'min_tenure_months': 0,
      'trigger_risk_level': null,
      'trigger_attendance_below': null,
      'pass_mark': 70,
    },
  ],
  // A failed first try then a pass, newest first (as the app orders them).
  'training_attempts': [
    {'id': 2, 'enrollment_id': 3, 'user_id': 'test-user-id', 'score': 80.0, 'passed': true, 'created_at': '2026-09-12T06:30:00Z'},
    {'id': 1, 'enrollment_id': 3, 'user_id': 'test-user-id', 'score': 40.0, 'passed': false, 'created_at': '2026-09-10T02:15:00Z'},
  ],
  'training_certificates': [
    {
      'id': 2,
      'certificate_no': 'MON-2026-00002',
      'enrollment_id': 3,
      'user_id': 'test-user-id',
      'program_id': 7,
      'employee_name': 'Test Employee',
      'program_title': 'Workplace Ethics',
      'category': 'behavioural',
      'score': 80.0,
      'issued_at': '2026-09-12T06:30:05Z',
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
