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
        .select('id, access, min_tenure_months, trigger_risk_level, trigger_attendance_below')
        .eq('category', category)
        .order('id'));
    final enrolledIds = List<Map<String, dynamic>>.from(
      await _client.from('training_enrollments').select('program_id').eq('user_id', userUuid),
    ).map((r) => r['program_id'] as int).toSet();
    final profile = await _client.from('profiles').select('hire_date').eq('id', userUuid).maybeSingle();
    final tenure = _tenureMonths(DateTime.tryParse(profile?['hire_date'] as String? ?? ''));

    // Programmes they haven't started and are tenure-eligible for. Prefer
    // the recommendation-only ones written for a PE shortfall (no
    // behaviour trigger of their own — those fire from attendance/risk, not
    // from a KPI score), then fall back to an open programme in the same
    // category.
    final eligible = candidates.where((p) => !enrolledIds.contains(p['id'] as int) && (p['min_tenure_months'] as int) <= tenure).toList();
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

  /// Months of service for the signed-in employee (0 if unknown).
  static Future<int> fetchMyTenureMonths() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final row = await _client.from('profiles').select('hire_date').eq('id', uid).maybeSingle();
    return _tenureMonths(DateTime.tryParse(row?['hire_date'] as String? ?? ''));
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
