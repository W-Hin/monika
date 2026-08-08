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
    final candidates = await _client.from('training_programs').select('id').eq('category', category).order('id').limit(1);
    final list = List<Map<String, dynamic>>.from(candidates);
    if (list.isEmpty) return;
    final programId = list.first['id'] as int;
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
      'progress': 0.1,
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
      if (completed) 'completed_at': DateTime.now().toIso8601String(),
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
  }) async {
    await _client.from('training_programs').insert({
      'title': title,
      'category': category,
      'description': description,
      'is_mandatory': isMandatory,
      'duration': duration,
      'department_id': departmentId,
    });
  }

  static Future<void> updateProgram({
    required int id,
    required String title,
    required String category,
    required String description,
    required bool isMandatory,
    required String duration,
  }) async {
    await _client.from('training_programs').update({
      'title': title,
      'category': category,
      'description': description,
      'is_mandatory': isMandatory,
      'duration': duration,
    }).eq('id', id);
  }

  static Future<void> assignDepartment({required int programId, required int? departmentId}) async {
    await _client.from('training_programs').update({'department_id': departmentId}).eq('id', programId);
  }

  static Future<void> setPerformanceScore({required int enrollmentId, required double score}) async {
    await _client.from('training_enrollments').update({'performance_score': score}).eq('id', enrollmentId);
  }
}
