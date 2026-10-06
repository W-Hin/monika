import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over `training_programs` and `training_enrollments`. Holds
/// no state of its own — TrainingController owns app-facing state.
class TrainingService {
  TrainingService._();
  static final _client = Supabase.instance.client;

  static Future<int?> departmentIdForName(String? name) async {
    if (name == null) return null;
    final row = await _client.from('departments').select('id').eq('name', name).maybeSingle();
    return row?['id'] as int?;
  }

  static Future<List<Map<String, dynamic>>> fetchCatalog() async {
    final rows = await _client.from('training_programs').select('*, departments(name)').order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Rule-based recommendation (per the project's "Rule-Based ... Training
  /// Prediction" scope, not a real ML model): picks the first training
  /// programme matching [category] and enrols the employee in it as a
  /// recommendation. Best-effort — does nothing if no programme exists yet
  /// for that category, and never overwrites an existing enrollment's
  /// progress if they're already enrolled.
  static Future<void> recommendForCategory({
    required String userUuid,
    required String category,
    required String reason,
  }) async {
    final candidates = List<Map<String, dynamic>>.from(await _client
        .from('training_programs')
        .select('id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below, department_id')
        .eq('category', category)
        .order('id'));
    final enrolledIds = List<Map<String, dynamic>>.from(
      await _client.from('training_enrollments').select('program_id').eq('user_id', userUuid),
    ).map((r) => r['program_id'] as int).toSet();
    // Recommendations the employee withdrew from (FR9.5) aren't repeated.
    enrolledIds.addAll(List<Map<String, dynamic>>.from(
      await _client.from('training_dismissals').select('program_id').eq('user_id', userUuid),
    ).map((r) => r['program_id'] as int));
    final profile = await _client.from('profiles').select('hire_date, department_id').eq('id', userUuid).maybeSingle();
    final tenure = _tenureMonths(DateTime.tryParse(profile?['hire_date'] as String? ?? ''));

    final departmentId = profile?['department_id'] as int?;

    // Programmes they haven't started, are tenure-eligible for, and are
    // meant for their department (or everyone). Prefer
    // the recommendation-only ones written for a PE shortfall (no
    // behaviour trigger of their own — those fire from attendance/risk, not
    // from a KPI score), then fall back to an open programme in the same
    // category.
    final eligible = candidates
        .where((p) =>
            !enrolledIds.contains(p['id'] as int) &&
            (p['min_tenure_months'] as int) <= tenure &&
            (p['department_id'] == null || p['department_id'] == departmentId))
        .toList();
    final preferred = eligible
        .where((p) => p['access'] == 'recommended_only' && p['trigger_risk_level'] == null && p['trigger_attendance_below'] == null)
        .toList();
    final fallback = eligible.where((p) => p['access'] == 'open').toList();
    final pick = preferred.isNotEmpty ? preferred.first : (fallback.isNotEmpty ? fallback.first : null);
    if (pick == null) return;
    final programId = pick['id'] as int;
    await _client.from('training_enrollments').upsert(
      {
        'program_id': programId,
        'user_id': userUuid,
        'is_recommended': true,
        'recommendation_reason': reason,
        'recommended_by': 'pe',
      },
      onConflict: 'program_id,user_id',
      ignoreDuplicates: true,
    );
  }

  static int _tenureMonths(DateTime? hire) {
    if (hire == null) return 0;
    final now = DateTime.now();
    var months = (now.year - hire.year) * 12 + (now.month - hire.month);
    if (now.day < hire.day) months--;
    return months < 0 ? 0 : months;
  }

  /// Months of service and department of the signed-in employee.
  static Future<({int tenureMonths, int? departmentId})> fetchMyContext() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return (tenureMonths: 0, departmentId: null);
    final row = await _client.from('profiles').select('hire_date, department_id').eq('id', uid).maybeSingle();
    return (
      tenureMonths: _tenureMonths(DateTime.tryParse(row?['hire_date'] as String? ?? '')),
      departmentId: row?['department_id'] as int?,
    );
  }

  /// Programmes the signed-in employee is exempt from — personally or
  /// through their department. Filtered here as well as by RLS, because an
  /// HR admin's RLS view includes everyone's exemptions.
  static Future<Set<int>> fetchMyExemptProgramIds(int? departmentId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = List<Map<String, dynamic>>.from(
      await _client.from('training_exemptions').select('program_id, user_id, department_id'),
    );
    return rows
        .where((r) => r['user_id'] == uid || (departmentId != null && r['department_id'] == departmentId))
        .map((r) => r['program_id'] as int)
        .toSet();
  }

  /// FR9.5 — leave an optional programme before starting it. The server
  /// refuses mandatory or already-started programmes, and remembers a
  /// withdrawn recommendation so it isn't recommended again.
  static Future<void> withdraw(int programId) async {
    await _client.rpc('withdraw_from_training', params: {'p_program_id': programId});
  }

  /// HR — who is excused from a mandatory programme (FR9.6). The user_id
  /// relationship is named because created_by also points at profiles.
  static Future<List<Map<String, dynamic>>> fetchExemptions(int programId) async {
    final rows = await _client
        .from('training_exemptions')
        .select('id, user_id, department_id, profiles!training_exemptions_user_id_fkey(name), departments(name)')
        .eq('program_id', programId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> addExemption({required int programId, String? userUuid, int? departmentId}) async {
    await _client.from('training_exemptions').insert({
      'program_id': programId,
      'user_id': userUuid,
      'department_id': departmentId,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  static Future<void> removeExemption(int id) async {
    await _client.from('training_exemptions').delete().eq('id', id);
  }

  /// Enrols the signed-in employee in any programme whose attendance/risk
  /// rule currently fires for them. Best-effort and idempotent.
  static Future<void> refreshMyRecommendations() async {
    await _client.rpc('refresh_my_training_recommendations');
  }

  static Future<List<Map<String, dynamic>>> fetchMyEnrollments() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client.from('training_enrollments').select().eq('user_id', uid);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> enroll(int programId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    await _client.from('training_enrollments').insert({
      'program_id': programId,
      'user_id': uid,
      'progress': 0,
    });
  }

  static Future<void> updateProgress({
    required int enrollmentId,
    required double progress,
    required bool completed,
  }) async {
    await _client.from('training_enrollments').update({
      'progress': progress,
      'is_completed': completed,
      if (completed) 'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', enrollmentId);
  }

  /// HR — every enrollment across every employee, joined with the
  /// employee's name and the program's title (for the Completion tab).
  static Future<List<Map<String, dynamic>>> fetchAllEnrollments() async {
    final rows = await _client
        .from('training_enrollments')
        .select('*, profiles(name), training_programs(title)');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> createProgram({
    required String title,
    required String category,
    required String description,
    required bool isMandatory,
    required String duration,
    int? departmentId,
    String access = 'open',
    int minTenureMonths = 0,
    String? triggerRiskLevel,
    double? triggerAttendanceBelow,
  }) async {
    await _client.from('training_programs').insert({
      'title': title,
      'category': category,
      'description': description,
      'is_mandatory': isMandatory,
      'duration': duration,
      'department_id': departmentId,
      'access': access,
      'min_tenure_months': minTenureMonths,
      'trigger_risk_level': triggerRiskLevel,
      'trigger_attendance_below': triggerAttendanceBelow,
    });
  }

  static Future<void> updateProgram({
    required int id,
    required String title,
    required String category,
    required String description,
    required bool isMandatory,
    required String duration,
    String access = 'open',
    int minTenureMonths = 0,
    String? triggerRiskLevel,
    double? triggerAttendanceBelow,
  }) async {
    await _client.from('training_programs').update({
      'title': title,
      'category': category,
      'description': description,
      'is_mandatory': isMandatory,
      'duration': duration,
      'access': access,
      'min_tenure_months': minTenureMonths,
      'trigger_risk_level': triggerRiskLevel,
      'trigger_attendance_below': triggerAttendanceBelow,
    }).eq('id', id);
  }

  /// Removes the programme. Its lessons, quiz questions, enrolments (and
  /// with them progress, scores and quiz attempts) cascade-delete.
  static Future<void> deleteProgram(int id) async {
    await _client.from('training_programs').delete().eq('id', id);
  }

  static Future<void> assignDepartment({required int programId, required int? departmentId}) async {
    await _client.from('training_programs').update({'department_id': departmentId}).eq('id', programId);
  }

  static Future<void> setPerformanceScore({required int enrollmentId, required double score}) async {
    await _client.from('training_enrollments').update({'performance_score': score}).eq('id', enrollmentId);
  }
}
