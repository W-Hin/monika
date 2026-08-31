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

  /// Excludes drafts — an evaluation HR hasn't finished scoring yet
  /// shouldn't appear to the employee it's about as if it were final.
  static Future<Map<String, dynamic>?> fetchMyCurrentYear() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return await _client
        .from('performance_evaluations')
        .select('*, performance_evaluation_scores(*)')
        .eq('user_id', uid)
        .eq('year', DateTime.now().year)
        .eq('is_draft', false)
        .maybeSingle();
  }

  /// Excludes drafts — see fetchMyCurrentYear's doc comment.
  static Future<List<Map<String, dynamic>>> fetchMyHistory() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('performance_evaluations')
        .select('*, performance_evaluation_scores(*)')
        .eq('user_id', uid)
        .eq('is_draft', false)
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

  static Future<int?> departmentIdForName(String? name) async {
    if (name == null) return null;
    final row = await _client.from('departments').select('id').eq('name', name).maybeSingle();
    return row?['id'] as int?;
  }

  /// HR — creates a new KPI template with its scoring items. `departmentName`
  /// is null (or 'All Departments') for a template that applies everywhere.
  static Future<void> createTemplate({
    required String name,
    required String? departmentName,
    required List<Map<String, dynamic>> items,
  }) async {
    final departmentId = await departmentIdForName(departmentName == 'All Departments' ? null : departmentName);
    final inserted = await _client
        .from('kpi_templates')
        .insert({'name': name, 'department_id': departmentId})
        .select()
        .single();
    final templateId = inserted['id'] as int;
    if (items.isNotEmpty) {
      await _client.from('kpi_template_items').insert(
            items.map((i) => {...i, 'template_id': templateId}).toList(),
          );
    }
  }

  /// HR — replaces a template's name/department/items in place. Existing
  /// performance_evaluations keep referencing the same template_id (their
  /// scores are already snapshotted onto performance_evaluation_scores at
  /// submit time, so an edit here doesn't retroactively change past
  /// evaluations, only what's suggested/picked going forward).
  static Future<void> updateTemplate({
    required int id,
    required String name,
    required String? departmentName,
    required List<Map<String, dynamic>> items,
  }) async {
    final departmentId = await departmentIdForName(departmentName == 'All Departments' ? null : departmentName);
    await _client.from('kpi_templates').update({'name': name, 'department_id': departmentId}).eq('id', id);
    await _client.from('kpi_template_items').delete().eq('template_id', id);
    if (items.isNotEmpty) {
      await _client.from('kpi_template_items').insert(
            items.map((i) => {...i, 'template_id': id}).toList(),
          );
    }
  }

  /// HR — deletes a KPI template. Its items cascade-delete; any
  /// performance_evaluations referencing it fall back to a null
  /// template_id (existing FK is ON DELETE SET NULL) rather than being
  /// deleted themselves.
  static Future<void> deleteTemplate(int id) async {
    await _client.from('kpi_templates').delete().eq('id', id);
  }

  /// Upserts the evaluation (unique on user_id+year, so re-submitting the
  /// same year cleanly replaces it) and replaces its scores. [isDraft] true
  /// saves progress without it counting as final — see PeController.submit
  /// vs PeController.saveDraft for what differs downstream (training
  /// recommendations only fire on a real, non-draft submit).
  static Future<void> submitEvaluation({
    required String userUuid,
    required int? templateId,
    required int year,
    required String comments,
    required double weightedTotal,
    required List<Map<String, dynamic>> scores,
    bool isDraft = false,
  }) async {
    final upserted = await _client
        .from('performance_evaluations')
        .upsert({
          'user_id': userUuid,
          'template_id': templateId,
          'year': year,
          'comments': comments,
          'weighted_total': weightedTotal,
          'is_draft': isDraft,
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

  /// Discards a draft outright — its scores cascade-delete with it. Not
  /// used for a real submitted evaluation (there's no UI path to call this
  /// on anything but a draft; deleting a finalised PE record isn't a
  /// feature this app offers).
  static Future<void> deleteEvaluation(int evaluationId) async {
    await _client.from('performance_evaluations').delete().eq('id', evaluationId);
  }
}
