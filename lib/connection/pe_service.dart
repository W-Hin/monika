import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over `kpi_templates`, `kpi_template_items`,
/// `performance_evaluations`, and `performance_evaluation_scores`. Holds
/// no state of its own — PeController owns app-facing state.
class PeService {
  PeService._();
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchTemplates() async {
    final rows = await _client
        .from('kpi_templates')
        .select('*, kpi_template_items(*), departments(name)')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>?> fetchMyCurrentYear() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return await _client
        .from('performance_evaluations')
        .select('*, performance_evaluation_scores(*)')
        .eq('user_id', uid)
        .eq('year', DateTime.now().year)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> fetchMyHistory() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('performance_evaluations')
        .select('*, performance_evaluation_scores(*)')
        .eq('user_id', uid)
        .order('year', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// HR — a specific employee's evaluation history (most recent first).
  static Future<List<Map<String, dynamic>>> fetchHistoryForEmployee(String userUuid) async {
    final rows = await _client
        .from('performance_evaluations')
        .select('*, performance_evaluation_scores(*)')
        .eq('user_id', userUuid)
        .order('year', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Upserts the evaluation (unique on user_id+year, so re-submitting the
  /// same year cleanly replaces it) and replaces its scores.
  static Future<void> submitEvaluation({
    required String userUuid,
    required int? templateId,
    required int year,
    required String comments,
    required double weightedTotal,
    required List<Map<String, dynamic>> scores,
  }) async {
    final upserted = await _client
        .from('performance_evaluations')
        .upsert({
          'user_id': userUuid,
          'template_id': templateId,
          'year': year,
          'comments': comments,
          'weighted_total': weightedTotal,
        }, onConflict: 'user_id,year')
        .select()
        .single();

    final evalId = upserted['id'] as int;
    await _client.from('performance_evaluation_scores').delete().eq('evaluation_id', evalId);
    if (scores.isNotEmpty) {
      await _client.from('performance_evaluation_scores').insert(
            scores.map((s) => {...s, 'evaluation_id': evalId}).toList(),
          );
    }
  }
}
